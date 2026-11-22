//! V8 Wrapper Identity Cache
//!
//! Per-realm cache that maintains the 1:1 mapping between Zig instances and
//! their V8 wrappers, and decides when a wrapped non-node platform object is
//! torn down: when its wrapper dies.
//!
//! ## Identity
//!
//! ```javascript
//! const p1 = url.searchParams;
//! const p2 = url.searchParams;
//! console.log(p1 === p2); // true: the one wrapper the realm's cache holds
//! ```
//!
//! ## Architecture (lane wrap1 b3; tmp/plans/object-wrap-design.md 3.4)
//!
//! - **Key**: `*runtime.Instance`. **Value**: `*Cell`, the cache's 32-byte
//!   record of the wrapper, from the cache's own pool. A node is never here:
//!   its wrapper lives in the node's own slot (node_wrappers.zig).
//! - **The wrapper** is held by a `v8::TracedReference` in the record, which
//!   the wrapper's anchor on the agent's C++ heap names (v8_wrapper.cpp
//!   PlatformAnchor, "The wrapper cache's records") - Blink's
//!   `ScriptWrappable::wrapper_` with the wrapper's `Object::Wrap` pointer
//!   back. The record's address is the handle every borrower gets (`get`):
//!   it is valid, and reads empty once the wrapper is collected, until the
//!   wrapper's finalizer frees the record at the agent's safe point.
//! - **Collection**: a young-generation collection drops an unmodified
//!   wrapper nothing reaches (`dropped`); a full collection's weak processing
//!   finds every record whose anchor was not marked (`processWeak`). Either
//!   takes the record out of the map and puts its finalizer on the agent's
//!   queue; the instance's teardown (`finalizeEntry`) runs at the agent's
//!   safe point, never inside the collector.
//! - **A wrapper V8 will not drop in a young collection** (an Event, a
//!   legacy platform object's proxy, one the binding changed) is held by a
//!   weak `v8::Global` made in the record's own word, whose parameter is the
//!   wrapper's anchor: its first pass hands the record to `dropped` as a
//!   young collection's drop does (lane wrap2: no callback record, no map
//!   node, no lock for the arm).
//! - **A wrapper with no platform anchor** - a realm's global, which has its
//!   own GlobalAnchor - is held as every wrapper was before this design: by a
//!   weak `v8::Global` with a first-pass callback and a finalizer (a `boxed`
//!   record).
//! - **Scope**: per realm. Not thread-safe: a realm is its agent's thread's.

const std = @import("std");
const builtin = @import("builtin");
const v8 = @import("ffi.zig");
const runtime = @import("runtime");
const engine = @import("engine");
const realm_finalizers = @import("realm_finalizers.zig");
const node_wrappers = @import("node_wrappers.zig");
const platform_anchor = @import("platform_anchor.zig");
const tombstones = @import("webidl").utils.tombstones;
/// Every map keyed by an instance hashes it under a seed of its own
/// (infra.address_map): this cache's end frees objects by walking `cache`,
/// and the slab issues their slots again in that order.
const address_map = @import("infra").address_map;

const log = std.log.scoped(.wrapper_cache);

/// The cache's record of one wrapper: 32 bytes of the cache's own pool
/// (`Chunk`), which the map names and - for a wrapper with a platform anchor
/// - the anchor names too (v8_wrapper.cpp CraneWrapperCell mirrors the
/// layout). It replaces what the cache kept per wrapper until lane wrap1 b3:
/// an 88-byte entry, a weak `v8::Global` in a 16-byte box with V8's 32-byte
/// global-handle node, and that handle's 48-byte callback record with its
/// node in the adapter's armed-handle map.
///
/// Three kinds, told apart by `bits.boxed` and `bits.weak_handle`:
/// - TRACED (the default: a non-node platform object's wrapper that V8 can
///   drop in a young collection): `wrapper` IS a
///   `v8::TracedReference<v8::Object>`, one word, attached by
///   v8_WrapperCell_Attach. Blink keeps a wrapper the same way -
///   `ScriptWrappable::wrapper_`, a TraceWrapperV8Reference traced by the
///   object the wrapper points at (platform/bindings/script_wrappable.h:147,
///   script_wrappable.cc:63-66; Chromium 157.0.8103.51). The collector tells
///   the cache when the wrapper died (`WrapperCache.processWeak`, `dropped`).
/// - WEAK HANDLE (a non-node platform object's wrapper that V8 will NOT drop
///   in a young collection: `heldByWeakHandle`, `WrapperCache.changed`):
///   `wrapper` IS a `v8::Global<v8::Object>`, made in place in the same one
///   word, weak. Its parameter is the wrapper's anchor, which names the
///   record as a traced one's does: V8's first pass for a dead wrapper
///   reads the record through it and tells the cache (`dropped`), with
///   nothing allocated for the arm (v8_wrapper.cpp
///   `platformAnchorFirstPass`; lane wrap2 - until then the arm was a
///   48-byte callback record and a node in the adapter's armed-handle map).
/// - BOXED (an object with no platform anchor: a realm's global, which has
///   its GlobalAnchor; a test's plain object): `wrapper` is the
///   `Global<Object>*` the binding made, weak in the same way.
///
/// The record outlives its wrapper: a collection that takes the wrapper
/// leaves the record `collected`, out of the map, its reference empty, until
/// its finalizer (`finalizeEntry`) frees it at the agent's safe point - so a
/// handle borrowed from the cache (`handle`) reads empty there, never freed
/// memory, exactly as the weak Global's box did.
pub const Cell = extern struct {
    /// Anchored: the TracedReference's one word (V8's `internal::Address*`,
    /// a TracedNode; null when empty), written by V8 (attach, detach, a
    /// young collection's Reset) and by `processWeak` alone in Zig - raw, in
    /// a full collection's atomic pause, for a TracedNode V8 frees itself
    /// there. Boxed: the `Global<Object>*`, OWNED; null once disposed.
    wrapper: ?*anyopaque,

    /// The instance the wrapper was made for. Nothing of it is read once
    /// `slotReissued` says the slot went to another object.
    instance: *runtime.Instance,

    /// Slab generation of `instance` when the record was made
    /// (`stamp.generation`): a record whose instance was freed, or freed and
    /// its slot reissued, differs here (the slot's stamp reads dead, or
    /// later). And, in the byte a generation never uses, what the record put
    /// into its agent's figure of the instances behind live wrappers
    /// (`stamp.held`).
    stamp: Stamp,

    /// When a script-called constructor made the instance, on its agent's
    /// callback clock (runtime.gc.DeferredTeardown.freshStamp, given by the
    /// constructor trampoline to `setConstructed`); 0 - the default, and the
    /// safe answer - for every other wrap: an object an operation returned,
    /// one wrapped while it was being constructed, one made outside any
    /// callback. Its finalizer may run at a binding's return into a
    /// callback's script only when this is at or after that callback's
    /// beginning (`freshStampOf`; finalizer_safe_point.zig).
    fresh: u32 = 0,

    bits: Bits = .{},

    pub const Stamp = packed struct(u64) {
        /// runtime.SlabAllocator stamps 56 bits (its `generation_bits`; the
        /// slot keeps its occupant's lifecycle flags in the byte above).
        generation: u56,
        /// What this record added to the figure of the instances behind its
        /// agent's live wrappers when its cache took the wrapper
        /// (`noteWrapped`), in units of `held_unit` bytes; 0 for a record
        /// that added nothing, and from the moment its share left the figure
        /// (`takeHeld`: its wrapper found dead, or the record freed). The
        /// record keeps the number because what it takes out must be what it
        /// put in: `heldBytes` asked again at the wrapper's death could
        /// answer something else - a state block freed or made since - or
        /// read a slot that is another object's by then (`slotReissued`),
        /// and the difference would stay in what V8 is told for the agent's
        /// life.
        held: u8 = 0,
    };

    pub const Bits = packed struct(u32) {
        /// Pending activity (`holdForPendingActivity`), COUNTED: each owner's
        /// keep is ended by its own release, and the wrapper is held while
        /// any remains - WebKit's ActiveDOMObject
        /// `m_pendingActivityInstanceCount`, `GCReachableRefMap`'s
        /// HashCountedSet (refcount design 2.3). A flag could not carry a
        /// second owner: a script element's queued task and its fetch both
        /// keep it, and the first release ended both (fix-list D15).
        /// Saturating: a count that reached the top stays there.
        pending_activity: u20 = 0,

        /// The record is issued (a free record of the pool has every bit
        /// clear).
        in_use: bool = false,

        /// `wrapper` is a `Global<Object>*`, not a traced reference (see
        /// `Cell`). Set when the record is issued and cleared by a
        /// successful attach: the collector's weak processing never takes a
        /// record that is not attached yet for a dead anchored one.
        boxed: bool = false,

        /// Held strongly now: some reason in `shouldBeStrong` holds. An
        /// anchored record's wrapper then has a strong handle beside its
        /// reference (`WrapperCache.makeStrong`); a boxed one's Global is
        /// not weak. Kept equal to `shouldBeStrong` by `syncEntry`.
        strong: bool = false,

        /// A window's document (`holdStrong`): the window aliases the
        /// wrapper. A reason only a caller can state, orthogonal to the
        /// others - Blink keeps these apart the same way: a document is
        /// reachable from its frame, while an ActiveScriptWrappable is kept
        /// by HasPendingActivity() (platform/bindings/
        /// active_script_wrappable_base.h) - so ending one never drops
        /// another.
        hold_document: bool = false,

        /// Kept by an edge from its realm's retained store instead of a
        /// strong handle, since the realm's navigable was destroyed
        /// (`WrapperCache.detach`).
        retained: bool = false,

        /// The instance was cleaned up externally (`markAsCleanedUp`): the
        /// cache's end must not tear it down again.
        instance_already_cleaned: bool = false,

        /// A collection took the wrapper and the record out of the cache's
        /// map. Its finalizer (`finalizeCollected`) runs at the agent's next
        /// safe point; until then the record waits (`WrapperCache.pending`).
        collected: bool = false,

        /// The collection found another record under this instance, or none:
        /// this one was replaced or removed before its wrapper died, and owns
        /// nothing but itself.
        stale: bool = false,

        /// Its finalizer ran while its agent's teardowns were held
        /// (engine.deferTeardowns): it waits on the agent's
        /// TeardownHolds.deferred for the last resume to tear it down.
        teardown_deferred: bool = false,

        /// `wrapper` is a `v8::Global` made in place, not a traced reference
        /// (see `Cell`; v8_wrapper.cpp kWrapperCellWeakHandle reads it).
        weak_handle: bool = false,

        /// A world cache's record of a NODE's wrapper (`WrapperCache.world`):
        /// it holds one counted reference on its node (runtime.lifetime.
        /// wrapperAcquired), which goes when the record is freed
        /// (`releaseWorldCount`) - each world's wrapper holds its node as
        /// every WebKit wrapper holds a Ref. Bit 30, which v8_wrapper.cpp
        /// reads nothing of (it was `_spare` since lane wrap2).
        world_counted: bool = false,

        /// A full collection's marking reached the record's anchor
        /// (v8_wrapper.cpp PlatformAnchor::Trace, kWrapperCellMarked): written
        /// there, read and cleared by `processWeak` in the same atomic pause.
        marked: bool = false,
    };

    /// The wrapper as the `Global<Object>*` every borrower holds, BORROWED:
    /// the box, or - anchored - the record's own address, read as a Global
    /// is (a TracedReference and a Global are both one IndirectHandleBase
    /// word, and a borrower only reads it: v8_wrapper.cpp, "Node wrappers on
    /// the agent's C++ heap"). Valid until the record's finalizer or its
    /// realm's end frees it, and empty once the wrapper is collected: take a
    /// reference of your own (a Local, a clone) before anything that can
    /// collect. Never disposed, armed or tagged by a borrower.
    pub fn handle(self: *Cell) *v8.Object {
        if (self.bits.boxed) return @ptrCast(@alignCast(self.wrapper.?));
        return @ptrCast(self);
    }

    /// The record's v8::Global - a boxed record's box, a weak-handle
    /// record's own word - or null for a traced record, and for a boxed one
    /// whose box is gone.
    fn global(self: *Cell) ?*anyopaque {
        if (self.bits.boxed) return self.wrapper;
        if (self.bits.weak_handle) return @ptrCast(self);
        return null;
    }

    /// The record as v8_wrapper.cpp takes it.
    fn raw(self: *Cell) *v8.WrapperCell {
        return @ptrCast(self);
    }

    /// The realm's cache whose pool the record is from.
    fn cache(self: *const Cell) *WrapperCache {
        return Chunk.of(self).cache;
    }
};

comptime {
    // v8_wrapper.cpp's CraneWrapperCell, field for field, and its marked bit.
    std.debug.assert(@sizeOf(Cell) == 32);
    std.debug.assert(@offsetOf(Cell, "wrapper") == 0 and @offsetOf(Cell, "instance") == 8);
    std.debug.assert(@offsetOf(Cell, "stamp") == 16 and @offsetOf(Cell, "fresh") == 24 and @offsetOf(Cell, "bits") == 28);
    // v8_wrapper.cpp kWrapperCellGenerationMask: the generation is the word's
    // low 56 bits, which is all runtime.SlabAllocator stamps.
    std.debug.assert(@bitOffsetOf(Cell.Stamp, "generation") == 0 and @bitOffsetOf(Cell.Stamp, "held") == 56);
    std.debug.assert(@bitOffsetOf(Cell.Bits, "marked") == 31 and @bitOffsetOf(Cell.Bits, "weak_handle") == 29);
    // kWrapperCellStrong.
    std.debug.assert(@bitOffsetOf(Cell.Bits, "strong") == 22);
}

/// One block of a cache's pool of records: `Chunk.bytes` at an address that
/// is a multiple of it, so a record finds its chunk - and through it its
/// cache - with one mask (`Chunk.of`) and carries no back-pointer: every
/// record of every wrapper would pay for it (the 88-byte entry kept one).
///
/// A chunk keeps its own free records and a count of the ones in use, and
/// the cache gives a chunk back to its allocator when its last record is
/// freed (`WrapperCache.freeCell`): a pool that only grew kept, for its
/// realm's life, the memory of the most wrappers the page ever held at once,
/// where each 88-byte entry had gone back to the allocator as its wrapper
/// died. The shape is the slab allocator's: blocks of equal objects, a list
/// of the blocks that still have room, and an empty block returned
/// (Bonwick, "The Slab Allocator", USENIX Summer 1994, section 3.2).
const Chunk = extern struct {
    cache: *WrapperCache,
    /// Every chunk of the cache (`WrapperCache.chunks`), newest first.
    next: ?*Chunk,
    prev: ?*Chunk,
    /// The cache's chunks that have a free record (`WrapperCache.partial`):
    /// a chunk is on that list exactly while `free` is not null.
    partial_next: ?*Chunk,
    partial_prev: ?*Chunk,
    /// This chunk's free records.
    free: ?*Cell,
    /// Its records in use.
    live: usize,
    cells: [count]Cell,

    const bytes = 1024;
    const alignment: std.mem.Alignment = .fromByteUnits(bytes);
    const count = (bytes - 7 * @sizeOf(usize)) / @sizeOf(Cell);

    fn of(cell: *const Cell) *Chunk {
        return @ptrFromInt(@intFromPtr(cell) & ~@as(usize, bytes - 1));
    }
};

comptime {
    std.debug.assert(@sizeOf(Chunk) <= Chunk.bytes);
    std.debug.assert(Chunk.count >= 16);
}

/// A free record of the pool: every bit clear, the next free record where a
/// live one keeps its instance.
const FreeCell = extern struct {
    wrapper: ?*anyopaque,
    next: ?*Cell,
    generation: u64,
    fresh: u32,
    bits: u32,
};

/// Whether `entry`'s wrapper must be held strongly: a caller's reason
/// (`hold_document`, pending activity), or the engine holding the wrapper
/// itself (a window's Location or History). The default - no reason - is
/// weak, and only then. A streams object is weak too: the pointers between
/// streams objects are traced edges and pending work holds what it touches
/// (pending activity), streams_js.zig "Lifetime of the objects the reactions
/// point at". (A node's wrapper has no entry here since the wrapper
/// redesign's P2: its agent's walk keeps it - `joinOpaqueRoot`'s comment says
/// how.)
fn shouldBeStrong(entry: *const Cell) bool {
    // A torn-down instance's wrapper is never what keeps anything.
    if (entry.bits.instance_already_cleaned) return false;
    if (entry.bits.hold_document or entry.bits.pending_activity != 0) return true;
    return engineHoldsWrapper(entry.instance);
}

/// What the wrapper reaches once the cache has let go of it (`letGo`).
const Link = enum {
    /// Nothing: the instance is freed (or already was, or its slot went to
    /// another object). Script elsewhere - another realm, which is how a
    /// removed frame's objects are usually held - can outlive this realm and
    /// keep the wrapper; the next read through it then fails the binding's
    /// unwrap with a TypeError instead of reaching an impl with a freed
    /// instance (23 impls unwrap `_internal` unchecked;
    /// crane/fl-xhr-frame-removed-mid-request.html panicked in
    /// XMLHttpRequest.getXHRState), and a holder's anchor traces nothing from
    /// here. Blink clears a wrapper's native pointer when the object it names
    /// goes (V8DOMWrapper::ClearNativeInfo).
    sever,
    /// Its instance, as before: the instance stays - another realm's cache
    /// still wraps it, or the entry was only removed.
    keep,
};

/// The cache lets go of `entry`'s wrapper, outside a collection: its
/// reference (anchored) or its Global (boxed) goes, and the wrapper - if
/// script still holds it - reaches what `link` says. Nothing for a record
/// whose wrapper a collection already took, but a boxed one's emptied Global
/// is still disposed. The record itself is the caller's to free (`freeCell`).
fn letGo(entry: *Cell, link: Link) void {
    // A wrapper the cache held strongly is held no more.
    entry.cache().dropStrongHandle(entry);
    if (!entry.bits.boxed) {
        // A record with an anchor: its cache joined its agent's caches with
        // the isolate it was handed (`register`). Its handle - the traced
        // reference, or the in-place weak Global with its arm - is Reset, and
        // the anchor stops naming it.
        v8.v8_WrapperCell_Detach(entry.cache().isolate.?, entry.raw(), link == .keep);
        // No handle and no anchor from here: the record is inert until it is
        // freed, and the collector's weak processing - a teardown the caller
        // runs next can collect - does not take it for a traced record whose
        // wrapper died.
        entry.bits.weak_handle = false;
        entry.bits.boxed = true;
        entry.wrapper = null;
        return;
    }
    const box: *v8.Object = @ptrCast(@alignCast(entry.wrapper orelse return));
    entry.wrapper = null;
    // A legacy platform object's wrapper is a proxy; its target is the bound
    // object, and the sever looks through it as the unwrap does.
    if (link == .sever and !v8.v8_Global_IsEmpty(@ptrCast(box))) platform_anchor.sever(box);
    // Its weak arm ends with it (v8_Object_Dispose releases the arm; a
    // finalizer still queued for it is cancelled).
    v8.v8_Object_Dispose(box);
}

/// An isolated world's node wrapper's record lets its counted reference go
/// (`Bits.world_counted`): released while its node is still the one it was
/// taken on and its teardown has not begun - which let it go or forgot it -
/// else forgotten, as node_wrappers' `releaseOne` does for the main world's.
/// Only counts: a tree the release leaves with no hold is queued by the
/// counts (dom.refcount_teardown). Never inside a collection: `freeCell`'s
/// callers run at the agent's safe point, a realm's end or a remove.
fn releaseWorldCount(entry: *Cell) void {
    entry.bits.world_counted = false;
    if (slotReissued(entry) or runtime.instance_lifecycle.isCleanupStarted(entry.instance)) {
        runtime.lifetime.wrapperForgotten();
        return;
    }
    const node = @import("dom").instance_bridge.getNodeBase(@ptrCast(entry.instance)) orelse {
        runtime.lifetime.wrapperForgotten();
        return;
    };
    runtime.lifetime.wrapperReleased(node);
}

/// THE RULE for which wrappers the cache holds by a weak handle, stated once:
/// A WRAPPER V8 WOULD NOT TREAT AS AN UNMODIFIED API OBJECT IS HELD BY A WEAK
/// HANDLE; every other one by a droppable traced reference.
///
/// V8 drops a traced reference's wrapper in a young-generation collection
/// only while `JSObject::IsUnmodifiedApiObject` holds (V8 15.7.112.43
/// src/objects/js-objects.cc:3152-3168): a JS API object with no elements and
/// no identity hash whose map is still its constructor's initial map. Any
/// other wrapper would wait for a full collection, which V8 runs about every
/// 100 MB of memory it is told of - 650,000 dropped Events ended at 198 MB
/// against 88 with a weak handle (v8_wrapper.cpp, "The wrappers V8 will not
/// drop"). A weak v8::Global is processed in every collection whatever the
/// object's map. The cache knows of three ways a wrapper is not unmodified:
/// - FROM BIRTH, answered here from the interface's template
///   (interface_bindings.wrapperIsBornChanged, computed from each interface's
///   metadata, never a list of names): its instance template has own
///   properties - V8 adds them after it makes the object from the initial map
///   (src/api/api-natives.cc:351-356), so `Event`, with its
///   [LegacyUnforgeable] isTrusted, and every interface that inherits from
///   one with such a member - or its wrapper is a Proxy (a legacy platform
///   object with named properties), which is no API object at all;
/// - WHEN THE BINDING CHANGES IT: `WrapperCache.changed`, called by the
///   adapter's own writes on a wrapper (a traced child's or [SameObject]
///   value's private property, a prototype, a captured stack);
/// - when script changes it (an expando, a WeakMap key): not known here. Such
///   a wrapper waits for a full collection, as in Blink and as a node's has
///   since the wrapper redesign.
/// tests/v8/wrap1_platform_anchor_test.zig asks V8 itself, template by
/// template, and pins this answer against it.
fn heldByWeakHandle(facts: WrapperFacts) bool {
    return facts.born_changed;
}

const WrapperFacts = @import("interface_bindings.zig").WrapperFacts;

/// What the binding's tables say of `instance`'s interface, read ONCE per
/// wrap (a lookup by name).
fn wrapperFactsOf(instance: *const runtime.Instance) WrapperFacts {
    return @import("interface_bindings.zig").wrapperFactsOf(instance.vtable.name);
}

/// True when the slab slot behind `entry.instance` no longer holds the
/// instance this record was made for: freed (the generation reads dead) or
/// reissued to a newcomer (a later generation) - the case in which a stale
/// callback's `Registry.remove` evicted a live document's entry (AGENTS.md,
/// "A stale weak callback's `Registry.remove` evicts the LIVE entry at a
/// recycled address").
///
/// Only the stamp is read: a slot that is no longer the record's may be
/// another thread's object by now (the slab is the Browser's, shared by its
/// window thread and its workers' threads, and its free list is LIFO), so
/// nothing else of it is read unless the stamp is still the record's.
fn slotReissued(entry: *const Cell) bool {
    return runtime.SlabAllocator.generationOf(entry.instance) != entry.stamp.generation;
}

/// The bytes of host memory `instance` holds that V8 cannot see, as far as an
/// instance says them itself: ONE function of the instance. Four parts: its
/// slab slot, its generated State block (the size its vtable carries), the
/// cache's record of its wrapper, and - when its State names one now - each
/// internal state block of its own that its impl keeps (interface_bindings
/// `stateBlocksOf`, read from the generated State's types). What it answers
/// (2026-11-15, tests/v8/wrap1_platform_anchor_test.zig prints them): 200 B
/// for an Event or a CustomEvent, 288 for a URLSearchParams, 264 for a
/// Headers, 360 for a URL, 144 for an AbortController, 160 for a
/// ReadableStream, 104 for a NamedNodeMap, 184 for a DOMTokenList, 336 for a
/// NodeList, 544 for an HTMLCollection. No per-interface table.
///
/// The internal state block is the part that decides the collector's
/// schedule. It was measured while an Event's dispatch state was 1,024 bytes
/// (lane ev1 has since made it 88): with the first three parts alone V8 was
/// told 112 bytes of the 1.2 KB an Event then held, and 650,000 dropped
/// Events ended at 99.1 MB on server1 against main's 87.5; told the block too
/// they ended at 55.2 there and at 31.1 against 87.2 on chat.local (gc_bench,
/// 2026-11-15, tmp/plans/wrap1-evidence/b3-meas8-*.out). In Blink the whole
/// object is on the C++ heap, whose growth V8 counts.
///
/// It is still a FLOOR: what a state allocates beyond its block (a list's
/// spilled storage, a body, a queue) is not known here.
pub fn instanceHeldBytes(instance: *const runtime.Instance) usize {
    return heldBytes(instance, wrapperFactsOf(instance));
}

fn heldBytes(instance: *const runtime.Instance, facts: WrapperFacts) usize {
    return runtime.SlabAllocator.slot_bytes + instance.vtable.state_size + @sizeOf(Cell) +
        @import("interface_bindings.zig").stateBlockBytes(facts.state_blocks, instance.state);
}

/// The unit of `Cell.Stamp.held`: a record keeps what it put into the figure
/// in one byte, so in steps of 8 bytes (every part of `heldBytes` is a
/// multiple of a pointer's alignment) up to 2,040. An instance that holds
/// more is counted as 2,040: the figure is a floor (`instanceHeldBytes`).
pub const held_unit = 8;

/// What a record whose instance holds `bytes` puts into the figure
/// (`Cell.Stamp.held`): `bytes` to the next `held_unit`, at most 255 units.
fn heldUnits(bytes: usize) u8 {
    return @intCast(@min((bytes + held_unit - 1) / held_unit, std.math.maxInt(u8)));
}

/// What `instanceHeldBytes` becomes in the figure: itself for every instance
/// that holds a multiple of 8 bytes up to 2,040 (tests).
pub fn countedBytes(bytes: usize) usize {
    return @as(usize, heldUnits(bytes)) * held_unit;
}

/// `entry`'s realm's cache took its wrapper: what its instance holds joins
/// its agent's figure of the instances behind LIVE non-node wrappers
/// (v8_wrapper.cpp, "What the instances behind non-node wrappers hold"), and
/// the record keeps the amount (`Cell.Stamp.held`). The one place the figure
/// grows; `takeHeld` is the one place it falls.
fn noteWrapped(isolate: *v8.Isolate, entry: *Cell, facts: WrapperFacts) void {
    std.debug.assert(entry.stamp.held == 0);
    const units = heldUnits(heldBytes(entry.instance, facts));
    entry.stamp.held = units;
    v8.v8_Isolate_NoteWrappedInstance(isolate, @as(usize, units) * held_unit);
}

/// How a record's share leaves its agent's figure (`takeHeld`).
const Gone = enum {
    /// A collection found the record's wrapper dead (`WrapperCache.died`,
    /// `WrapperCache.sweepUnmarked`). When that collection is a young one
    /// the share stays in what V8 is told until the next full collection
    /// (v8_wrapper.cpp v8_Isolate_NoteWrapperDead: the user's ruling of
    /// 2026-11-15, Blink's model).
    dead,
    /// The record is freed while its wrapper may live
    /// (`WrapperCache.freeCell`: a remove, a replacement, its realm's end).
    freed,
};

/// `entry`'s share of its agent's figure leaves it. Once: the record's
/// amount reads 0 after it. A store and a call that only adds and compares,
/// no V8 call here: inside a full collection V8 is told once for all its
/// dead (v8_wrapper.cpp `forgetDeadWrappedInstances`), outside one at the
/// agent's next safe point. Nothing of the instance is read - it may be
/// freed, or another object.
fn takeHeld(isolate: ?*v8.Isolate, entry: *Cell, how: Gone) void {
    const units = entry.stamp.held;
    if (units == 0) return;
    entry.stamp.held = 0;
    const i = isolate orelse return;
    const bytes = @as(usize, units) * held_unit;
    switch (how) {
        .dead => v8.v8_Isolate_NoteWrapperDead(i, bytes),
        .freed => v8.v8_Isolate_NoteInstanceGone(i, bytes),
    }
}

/// True while something other than V8 holds `instance`: a node with a parent
/// (its tree owns it) or a document with a default view (its browsing context
/// owns it). Read at callback time from the DOM's own parent pointer, which the
/// mutation algorithms keep current - and `slotReissued` has already
/// established that `instance` is the one this entry was made for. A stale
/// registry entry at a recycled address can only answer "owned" for something
/// that is not, which keeps an instance alive a little longer, never frees a
/// live one.
fn engineOwns(instance: *runtime.Instance) bool {
    return treeOwns(instance) or templateOwns(instance) or engineHoldsWrapper(instance);
}

/// True for a template's contents while its template is alive: the template
/// owns the fragment natively (HTML 4.12.3; WebKit's HTMLTemplateElement keeps
/// a RefPtr to it, Blink's traces content_), and only the template's teardown
/// frees it - or, when script still holds the fragment, hands it to its
/// wrapper by making it nobody's (`dom.template_contents.releaseHost`). The
/// edge between the two wrappers keeps only the content's wrapper, and goes
/// with either: owned through it, the fragment was freed under a template
/// whose wrapper had been replaced or collected (PR-M1). Like `treeOwns`, an
/// instance arm only - the content's wrapper stays weak. The default is false
/// (an ordinary fragment, a shadow root, anything not a node), pinned by
/// tests/v8/template_owns_predicate_test.zig.
pub fn templateOwns(instance: *runtime.Instance) bool {
    return @import("dom").template_contents.ownedByLiveTemplate(instance);
}

/// The part of `engineOwns` that holds the WRAPPER too, not only the
/// instance: a window's Location or History, a document with a default view.
/// (A node in a tree is the other part: its instance is its tree's, its
/// wrapper the edges' - `shouldBeStrong`.) Streams objects were held here for
/// their realm's life until lane streamslife1 (2026-11-03) made their
/// pointers traced edges: tests/v8/streams_lifetime_test.zig.
fn engineHoldsWrapper(instance: *runtime.Instance) bool {
    if (isWindowOwned(instance)) return true;
    // A Document is a node: any other type - every object a worker realm
    // wraps, on the worker's thread - asks the window thread's unlocked
    // Document table nothing (`treeOwns` says why).
    if (instance.vtable.counted == null) return false;
    return @import("dom").document_internals.hasDefaultView(instance);
}

/// A realm's Window: its realm's end frees it (protocol_realms).
fn isRealmWindow(instance: *runtime.Instance) bool {
    return std.mem.eql(u8, instance.vtable.name, "Window");
}

/// True for a node with a parent: its tree holds it - the parent's child list
/// points at it - and only the tree's teardown may free it (Node.deinit walks a
/// root's subtree). WebKit asserts the same in Node::~Node: a node is never
/// destroyed while it has a parent. Anything that is not a node, and a node
/// that is a root, answers false and is freed as before.
///
/// Whether the instance is a node at all is its TYPE's answer, read from its
/// vtable (`VTable.counted`: `&lifetime.node` for every type whose state
/// keeps a NodeBase, pinned by tests/runtime/vtable_counted_test.zig) -
/// never from a table of its Browser. A worker realm's cache asks this of
/// each of its own objects, none of them a node, on the worker's thread (its
/// end's sweep, its finalizers), and the Browser's node table is the window
/// thread's, with no lock (runtime.InstanceRegistry): looking an instance up
/// there raced the page's node teardown - ThreadSanitizer, a worker realm's
/// end beside a navigation (tests/html/page_retention_test.zig, a port
/// transferred to a worker; lanes gstate4, crashes7). Blink asks the type
/// too: a wrapper's WrapperTypeInfo carries `wrapper_class_id`, kNodeClassId
/// for a node (platform/bindings/wrapper_type_info.h), with no lookup. A
/// node's NodeBase then comes from the node bridge, which locks
/// (dom.instance_bridge), not from Node's impl.
pub fn treeOwns(instance: *runtime.Instance) bool {
    if (instance.vtable.counted == null) return false;
    const node_base = @import("dom").instance_bridge.getNodeBase(@ptrCast(instance)) orelse return false;
    return node_base.parent_node != null;
}

/// A window's Location and History: the Window holds each in its own state,
/// hands out that one instance on every `window.location` / `window.history`
/// ([SameObject]), and frees both in Window.deinit. Freeing one when its
/// wrapper was collected left the Window pointing at a freed slab slot, so
/// the next read returned whatever the slot held by then - an iframe's
/// `contentWindow.location.href` read undefined after a collection, and a
/// form submission navigating through it crashed. Blink keeps both alive
/// from the window: DOMWindow::Trace visits location_ and
/// LocalDOMWindow::Trace visits history_ (core/frame/dom_window.cc,
/// local_dom_window.cc).
///
/// Each type says which Window it belongs to through the hook it installs
/// (dom.window_globals), not through its impl.
fn isWindowOwned(instance: *runtime.Instance) bool {
    const window_globals = @import("dom").window_globals;
    const name = instance.vtable.name;
    if (std.mem.eql(u8, name, "Location")) return window_globals.locationWindow(instance) != null;
    if (std.mem.eql(u8, name, "History")) return window_globals.historyWindow(instance) != null;
    return false;
}

/// Which node wrappers V8 may collect, and when: the walk decides, in the
/// collector's atomic pause (the wrapper redesign's P5-P7, tmp/redesign/
/// wrapper-redesign-design.md 3.2 and 4.4). A node wrapper is kept while any
/// wrapper of its host-including tree is, while a node of its node
/// document's tree keeps it, while a node of its tree is kept, and while a
/// holder whose wrapper is kept holds a node of it (dom.wrapper_tracing,
/// reached from NodeAnchor::Trace, HolderAnchor::Trace and the anchors'
/// registry) - Blink's Node::Trace through its Member edges, WebKit's
/// opaque roots (JSNodeOwner::isReachableFromOpaqueRoots). So the engine's
/// `wrapper_tracing` capability is `.native` on V8 since P7, and the
/// opaque-root operations below are the `.emulated` engines' path: the host
/// calls them only `if (engine.capabilities.wrapper_tracing == .emulated)`
/// (dom.mutation, dom.node_holds), so on V8 they are never called.
///
/// Until P7 node tracing kept the rule with JS edges: every wrapped node's
/// wrapper held its parent's (or, a root, its node document's) in a private
/// property, every parent's wrapper a JS Set of its wrapped children's, and a
/// wrap wrapped every unwrapped ancestor first so the edges reached the root
/// (the upward closure). Each edge was a property the binding wrote on the
/// wrapper - a map transition - so no node wrapper was ever an unmodified API
/// object, and V8 dropped none in a scavenge (lesson
/// architecture-droppable-wrappers-need-unmodified-wrappers-a-hidden-js-edge-
/// pins-every-one.md); a query wrapped every ancestor of its results (gc_bench
/// qsa-deep: 1,119 wrappers for 1,000 results).
///
/// engine.joinOpaqueRoot: nothing on V8 - the walk finds a tree's wrappers
/// from its nodes, whatever was inserted where.
pub fn joinOpaqueRoot(member: *runtime.Instance, parent: *runtime.Instance) void {
    _ = member;
    _ = parent;
}

/// engine.leaveOpaqueRoot: nothing on V8 (see joinOpaqueRoot).
pub fn leaveOpaqueRoot(member: *runtime.Instance, old_parent: *runtime.Instance) void {
    _ = member;
    _ = old_parent;
}

/// engine.keepOpaqueRoot: on V8 a node `member` needs no edge - the holder's
/// own trace keeps it and its trees (VTable.trace_held_nodes, the redesign's
/// P6), so the slot is emptied; a member that is not a node is kept as
/// engine.traceChild keeps it. Never makes a wrapper.
pub fn keepOpaqueRoot(owner: *runtime.Instance, member: *runtime.Instance, slot: engine.TracedSlot) void {
    const tracing = @import("protocol_tracing.zig");
    if (member.vtable.counted != null) return tracing.forgetTracedChild(owner, slot);
    tracing.traceChild(owner, member, slot);
}

/// A document becomes a window's document after it may already have been
/// wrapped (an iframe's document is handed out as contentDocument before its
/// context exists). From that moment the window aliases the wrapper - WebKit's
/// `document` is a strong reference - so it must be held, not just kept: a
/// document whose wrapper was collected under the window died in
/// LookupIterator::GetRootForNonJSReceiver on the next `document` access
/// (custom-elements/connected-callbacks.html, SIGTRAP). No production caller
/// since Document.setDefaultView's edge and keep replaced it, and a node's
/// wrapper has no entry since the wrapper redesign's P2: only
/// tests/v8/engine_pending_activity_test.zig's "another reason" case calls
/// it, on a non-node instance (P9 deletes it with that case).
pub fn holdStrong(instance: *runtime.Instance) void {
    const entry = entryOf(instance) orelse return;
    entry.bits.hold_document = true;
    syncEntry(entry);
}

/// Blink's ActiveScriptWrappable: hold `instance`'s wrapper while it has
/// pending activity - a running Worker, a timeout signal whose timer is
/// pending - whatever script holds of it. COUNTED: one keep for each call,
/// each ended by one `releasePendingActivity`. The activity can begin before
/// script has seen the instance (a signal is made, and its timer armed,
/// before the binding wraps it): the keeps are then recorded against the
/// instance and taken by its wrapper when it is made.
pub fn holdForPendingActivity(instance: *runtime.Instance) void {
    // A node's keep is its agent's (node_wrappers: the keep table), as its
    // wrapper is.
    if (instance.vtable.counted != null) return node_wrappers.keep(instance);
    const cache = cacheOf(instance) orelse return;
    if (cache.cache.get(instance)) |entry| {
        entry.bits.pending_activity +|= 1;
        syncEntry(entry);
        return;
    }
    const generation = runtime.SlabAllocator.generationOf(instance);
    if (cache.walks == 0) cache.pending_guard.beforeInsert(&cache.pending_before_wrap);
    const gop = cache.pending_before_wrap.getOrPut(cache.allocator, instance) catch return;
    // A dead instance's keeps at a reissued address are not the newcomer's.
    if (!gop.found_existing or gop.value_ptr.generation != generation) gop.value_ptr.* = .{ .generation = generation, .count = 0 };
    gop.value_ptr.count +|= 1;
}

/// End one keep `holdForPendingActivity` took: when it was the last, the
/// wrapper is collectable again, unless another reason holds it. A release
/// with no keep left - one an owner never took, or took once and releases
/// twice - would end ANOTHER owner's keep under a count; it changes nothing,
/// and in Debug it is reported (an error log: fatal in unit tests, counted in
/// a sweep - decision D9) and counted on the cache (`unmatched_releases`).
pub fn releasePendingActivity(instance: *runtime.Instance) void {
    if (instance.vtable.counted != null) return node_wrappers.release(instance);
    const cache = cacheOf(instance) orelse return;
    if (cache.cache.get(instance)) |entry| {
        if (entry.bits.pending_activity == 0) return cache.unmatchedRelease(instance);
        // A count that saturated stays: its keeps can no longer be told apart.
        if (entry.bits.pending_activity != std.math.maxInt(u20)) entry.bits.pending_activity -= 1;
        if (entry.bits.pending_activity == 0) syncEntry(entry);
        return;
    }
    const waiting = cache.pending_before_wrap.getPtr(instance) orelse return cache.unmatchedRelease(instance);
    if (waiting.generation != runtime.SlabAllocator.generationOf(instance) or waiting.count == 0) {
        if (cache.pending_before_wrap.remove(instance)) cache.pending_guard.noteRemoval(&cache.pending_before_wrap);
        return cache.unmatchedRelease(instance);
    }
    waiting.count -= 1;
    if (waiting.count == 0) {
        if (cache.pending_before_wrap.remove(instance)) cache.pending_guard.noteRemoval(&cache.pending_before_wrap);
    }
}

/// `instance`'s realm's cache, or null when it has none or it is being torn
/// down.
fn cacheOf(instance: *runtime.Instance) ?*WrapperCache {
    const cache_storage = instance.ctx.getV8WrapperCacheStorage() orelse return null;
    const cache: *WrapperCache = @ptrCast(@alignCast(cache_storage));
    if (cache.is_tearing_down) return null;
    return cache;
}

/// `instance`'s entry in its realm's cache, or null when it has no wrapper
/// there or the cache is being torn down.
fn entryOf(instance: *runtime.Instance) ?*Cell {
    const cache = cacheOf(instance) orelse return null;
    return cache.cache.get(instance);
}

/// Hold or let go of `entry`'s wrapper to match `shouldBeStrong` - the one
/// path by which a wrapper's strength changes after it is made.
///
/// In a detached cache (`WrapperCache.detach`) no wrapper is strong: one that
/// should be is kept by an edge from the realm's retained store instead,
/// drawn once and never withdrawn - the realm is going, and what it kept goes
/// with it.
fn syncEntry(entry: *Cell) void {
    const cache = entry.cache();
    if (cache.detached_holder) |holder| {
        if (shouldBeStrong(entry) and !entry.bits.retained) {
            retainOnGlobal(holder, @ptrCast(entry.handle()));
            entry.bits.retained = true;
        }
        if (entry.bits.strong) cache.makeWeak(entry);
        return;
    }
    const strong = shouldBeStrong(entry);
    if (entry.bits.strong == strong) return;
    if (strong) cache.makeStrong(entry) else cache.makeWeak(entry);
}

/// The private key of the array on a detached realm's global object that
/// keeps what its cache would otherwise hold strongly.
const retained_key = "crane:retained";

/// Keep `value` by an edge from `holder`, a detached realm's retained store
/// (which its global object keeps, never its proxy). A no-op once collected.
pub fn retainOnGlobal(holder: *v8.Value, value: *v8.Value) void {
    v8.v8_Object_RetainInPrivateArray(holder, retained_key.ptr, retained_key.len, value);
}

/// The retained store of `instance`'s realm once that realm is detached
/// (`WrapperCache.detach`), BORROWED; null while it is attached, or with no
/// cache. node_wrappers keeps a detached realm's kept nodes by it.
pub fn detachedHolderOf(instance: *runtime.Instance) ?*v8.Value {
    const cache = cacheOf(instance) orelse return null;
    return cache.detached_holder;
}

/// The weak arm of `WrapperCache.detached_holder`: nothing to do when the
/// global object is collected - the handle reads empty, and every retain
/// through it is a no-op from then on.
fn detachedHolderCollected(_: ?*anyopaque, _: usize) callconv(.c) void {}

/// A deferred edge's child, made weak at a realm's detach once it is kept
/// from the global object: nothing to do when it is collected.
fn deferredChildCollected(_: ?*anyopaque, _: usize) callconv(.c) void {}

/// One agent's live WrapperCaches - one per realm: a field of its record
/// (protocol_agents.AgentRecord.caches). A node has one wrapper whatever
/// realm reads it (its bound wrapper), but any other platform object gets a
/// wrapper in each realm's cache that wraps it: a span's DOMStringMap read by
/// its frame and by the frame's parent has two. The instance must outlive all
/// of them - Blink traces it from every world's wrapper - so a cache frees an
/// instance only when no other live cache of its agent still wraps it.
/// Freeing it on the first wrapper's death left the other realm's wrapper,
/// and the element's [SameObject] cache, on freed memory. A platform object
/// is one agent's, so its wrappers are all in that agent's caches. It was a
/// `threadlocal`, every agent's caches on the thread in one list.
pub const Caches = std.ArrayListUnmanaged(*WrapperCache);

/// The current agent's live caches; null with no isolate current, or for an
/// isolate createAgent did not make.
fn currentCaches() ?*Caches {
    const isolate = v8.v8_Isolate_GetCurrent() orelse return null;
    return @import("protocol_agents.zig").cachesOf(isolate);
}

/// The wrappers every live cache of the current agent holds - every realm's -
/// for the diagnostics tier (protocol.zig diagnosticCounters,
/// `wrapper_cache_entries`). A cache left registered at its agent's end is
/// reported then (`endAgent`).
pub fn liveEntryCount() usize {
    const caches = currentCaches() orelse return 0;
    var total: usize = 0;
    for (caches.items) |cache| total += cache.size();
    return total;
}

/// The records of the current agent's caches whose wrapper a collection took
/// and whose finalizer has not run (diagnostics: `wrapper_cache_pending`).
pub fn livePendingCount() usize {
    const caches = currentCaches() orelse return 0;
    var total: usize = 0;
    for (caches.items) |cache| total += cache.pending;
    return total;
}

/// How many times a collection of the current agent took a weak-handle
/// record's share out of the figure while its wrapper lived
/// (`WrapperCache.heldAgain`), over its live caches (diagnostics:
/// `wrapped_instance_mispredictions`; expected 0).
pub fn liveMispredictionCount() usize {
    const caches = currentCaches() orelse return 0;
    var total: usize = 0;
    for (caches.items) |cache| total += cache.mispredicted;
    return total;
}

/// The bytes of the record pools of the current agent's caches (diagnostics:
/// `wrapper_cache_pool_bytes`): every chunk a cache holds, in use or not.
pub fn livePoolBytes() usize {
    const caches = currentCaches() orelse return 0;
    var total: usize = 0;
    for (caches.items) |cache| total += cache.chunk_count * Chunk.bytes;
    return total;
}

/// The edges every live cache of the current agent holds for owners script
/// has not seen yet (`WrapperCache.deferEdge`), for tests and diagnostics.
pub fn liveDeferredEdgeCount() usize {
    const caches = currentCaches() orelse return 0;
    var total: usize = 0;
    for (caches.items) |cache| total += cache.deferredEdgeCount();
    return total;
}

/// The agent's end, once its realms - and so their caches - have ended
/// (protocol_agents.removeAgent): the list's storage goes, and `isolate`'s
/// collections ask the caches nothing from here (the list they were handed
/// is the agent's record's). A cache still on it outlived its agent's
/// realms; it is taken off, so that its own end touches no freed list.
pub fn endAgent(isolate: *v8.Isolate, caches: *Caches) void {
    _ = v8.v8_Isolate_SetPlatformWrapperHooks(isolate, null, &noWeakProcessing, &nothingDropped, &nothingDropped);
    if (caches.items.len != 0) log.err("{d} wrapper cache(s) outlived their agent's realms", .{caches.items.len});
    for (caches.items) |cache| {
        cache.peers = null;
        cache.registered = false;
    }
    caches.deinit(std.heap.page_allocator);
    caches.* = .empty;
}

/// Whether a live cache other than `except`, of its agent, holds a wrapper
/// for this very instance - same slot, same generation.
fn wrappedElsewhere(instance: *runtime.Instance, except: *const WrapperCache) bool {
    const generation = runtime.SlabAllocator.generationOf(instance);
    const caches = except.peers orelse currentCaches() orelse return false;
    for (caches.items) |other| {
        if (other == except) continue;
        const entry = other.cache.get(instance) orelse continue;
        if (entry.stamp.generation == generation) return true;
    }
    return false;
}

/// Arm a record's v8::Global weak - a boxed record's box, a weak-handle
/// record's own word: the collector takes the record out of the cache in its
/// first pass and its instance is torn down after the collection.
fn armWeak(entry: *Cell) void {
    if (entry.bits.weak_handle) {
        // Its parameter is the wrapper's anchor: the first pass hands the
        // record to `dropped`, and nothing is allocated for the arm.
        v8.v8_WrapperCell_ArmWeak(entry.cache().isolate.?, entry.raw());
        return;
    }
    std.debug.assert(entry.bits.boxed);
    v8.v8_Global_SetWeakFinalizer(@ptrCast(entry.wrapper.?), @ptrCast(entry), unlinkCollected, finalizeCollected);
}

/// End the weak arm of a record's v8::Global, which stays: a boxed record's
/// box, a weak-handle record's own word. Nothing for a traced record.
fn disarm(entry: *Cell) void {
    if (entry.bits.weak_handle) return v8.v8_WrapperCell_Disarm(entry.raw());
    if (entry.bits.boxed) {
        if (entry.wrapper) |box| v8.v8_Global_ClearWeak(box);
    }
}

/// V8's FIRST pass for a BOXED record: its wrapper was collected and its
/// Global Reset. (A weak-handle record's first pass is `dropped`.) No V8 API may be called here (v8-weak-callback-info.h) -
/// other wrappers of this collection may still hold the 0xCA11 zap value - so
/// this only makes the record unreachable, as Blink's firstWeakCallback reset
/// the object's wrapper (`WrapperCache.died`). The finalizer is queued by the
/// handle's own first pass (v8_wrapper.cpp WeakCallbackWrapper).
fn unlinkCollected(data: ?*anyopaque, _: usize) callconv(.c) void {
    const entry: *Cell = @ptrCast(@alignCast(data orelse return));
    entry.cache().died(entry);
}

/// The caches' weak processing in a full collection's atomic pause, after
/// its marking (v8_wrapper.cpp NodeWrapperRegistry::ProcessWeak): `data` is
/// the collecting agent's live caches. Every live anchored record whose
/// anchor the marking did not reach is a dead wrapper's
/// (`WrapperCache.sweepUnmarked`). No V8 API but the finalizer queue's push,
/// no allocation on either collected heap, no instance freed.
fn processWeak(data: ?*anyopaque) callconv(.c) void {
    const caches: *Caches = @ptrCast(@alignCast(data orelse return));
    for (caches.items) |cache| cache.sweepUnmarked();
}

/// A collection took `raw`'s wrapper, and the record's handle is Reset and
/// its anchor severed already: a young-generation collection dropped an
/// unmodified API object nothing reached (v8_wrapper.cpp
/// NodeWrapperRootsHandler::resetPlatformRoot), or - a weak-handle record -
/// its Global's first pass ran, in a collection of either kind
/// (`platformAnchorFirstPass`). The record leaves its cache's map and its
/// finalizer joins the agent's queue, under the weak processing's rules: no
/// V8 call but the queue's push.
fn dropped(_: ?*anyopaque, raw: *v8.WrapperCell) callconv(.c) void {
    const entry: *Cell = @ptrCast(@alignCast(raw));
    entry.cache().died(entry);
    entry.cache().queueFinalizer(entry);
}

/// The binding changed the wrapper `raw` holds by a traced reference
/// (v8_wrapper.cpp notePlatformWrapperChanged: a private property, a
/// prototype, a captured stack): V8 will not drop it in a young collection
/// any more, so the record holds it by a weak handle from here
/// (`heldByWeakHandle`'s rule).
fn changed(_: ?*anyopaque, raw: *v8.WrapperCell) callconv(.c) void {
    const entry: *Cell = @ptrCast(@alignCast(raw));
    entry.cache().toWeakHandle(entry);
}

/// The hooks of an agent that ended: its caches are gone.
fn noWeakProcessing(_: ?*anyopaque) callconv(.c) void {}
fn nothingDropped(_: ?*anyopaque, _: *v8.WrapperCell) callconv(.c) void {}

/// The finalizer of a collected wrapper (`WrapperCache.died` ran), at its
/// agent's safe point - never while the engine is collecting: the collection
/// only queues it (v8_wrapper.cpp `runQueuedFinalizers`: a binding's return
/// into script, the pump, a forced collection's return) - the instance's
/// teardown runs here, and may do any engine work - a dropped Response
/// cancels its open body transfer, which reports to its page.
fn finalizeCollected(data: ?*anyopaque, _: usize) callconv(.c) void {
    const entry: *Cell = @ptrCast(@alignCast(data orelse return));
    // A walk holds the agent's teardowns (engine.deferTeardowns): this one
    // waits for the last resume, flagged and listed on the agent's holds.
    // The engine is done with it - its reference is empty and its record is
    // off the queue - so the later finalizeEntry tears it down as the cache's
    // end does for a record still waiting.
    //
    // The realm is collected and has not ended (lane tl1): the record stays
    // collected and counted (`WrapperCache.pending`), off the agent's queue
    // and on no hold, and the realm's end tears it down
    // (`WrapperCache.realm_collected`, `finalizePending`).
    if (entry.cache().realm_collected) return;
    if (entry.cache().teardownHolds()) |holds| {
        if (holds.count != 0 and holds.wait(entry)) return;
    }
    finalizeEntry(entry);
}

/// The stamp of the object a queued finalizer is for, for the agent's safe
/// point inside a callback (finalizer_safe_point.zig): the constructor's
/// (`Cell.fresh`) when a script-called constructor made it; otherwise the
/// one its slab generation earns against the callbacks on the stack
/// (DeferredTeardown.freshSerialOf, lane mem1: whatever made it - a factory
/// method, the DOM's own algorithms - an object made inside the innermost
/// callback is fresh for it). The record's own generation is asked, the
/// instance's when it was wrapped, never its slot's now: a slot freed and
/// reissued reads another object's. 0 - never fresh - for a finalizer that
/// is not a wrapper cache record's (an observable array's, an asynchronous
/// iterator's, a promise reaction's), and for a realm whose agent has no
/// queue. `data` is what the finalizer was queued with; it has not been
/// cancelled (the caller checked). The agent's isolate is entered (the
/// queue's fresh steps), as `deferredQueue` needs.
pub fn freshStampOf(finalize: v8.WeakCallbackFn, data: ?*anyopaque) u32 {
    if (finalize != &finalizeCollected) return 0;
    const entry: *const Cell = @ptrCast(@alignCast(data orelse return 0));
    if (entry.fresh != 0) return entry.fresh;
    const queue = entry.cache().deferredQueue() orelse return 0;
    return queue.freshSerialOf(runtime.SlabAllocator.ownerOf(entry.instance), entry.stamp.generation);
}

/// v8_Isolate_TakeQueuedFinalizers' two callbacks for a cache's end: the
/// queued finalizers of `context`'s own records leave the agent's queue
/// uncalled - the cache then finalizes, or drops, each record itself
/// (`WrapperCache.finalizePending`, `orphanPending`), by walking its pool.
fn belongsToCache(data: ?*anyopaque, context: ?*anyopaque) callconv(.c) bool {
    const entry: *const Cell = @ptrCast(@alignCast(data orelse return false));
    return @as(?*anyopaque, @ptrCast(entry.cache())) == context;
}
fn takenOffQueue(_: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {}

/// An agent's holds on the teardowns of its collected platform objects
/// (engine.deferTeardowns / resumeTeardowns), kept on its agent record
/// (protocol_agents.teardownHoldsOf). The collections a hold spans still run
/// and still unlink what they collect; `finalizeCollected` only flags the
/// entry and lists it here, and the resume that ends the last hold runs
/// `finalizeEntry` for each. Read and written on the agent's thread only.
pub const TeardownHolds = struct {
    /// Holds in progress, nested: teardowns wait while any remains - and,
    /// in Debug builds, the adapter refuses to run script
    /// (protocol.forbidScriptInHold).
    count: u32 = 0,
    /// The entries waiting, each still on its cache's pending list and
    /// flagged `teardown_deferred`. OWNED storage (std.heap.c_allocator);
    /// the entries are their caches'.
    deferred: std.ArrayListUnmanaged(*Cell) = .empty,

    /// List `entry` to wait, and flag it; false - tear it down now - when
    /// there is no memory to list it.
    fn wait(self: *TeardownHolds, entry: *Cell) bool {
        self.deferred.append(std.heap.c_allocator, entry) catch return false;
        entry.bits.teardown_deferred = true;
        return true;
    }

    /// `entry` is torn down or dropped some other way while it waits - its
    /// cache's end: it leaves the list.
    fn forget(self: *TeardownHolds, entry: *Cell) void {
        entry.bits.teardown_deferred = false;
        const index = std.mem.indexOfScalar(*Cell, self.deferred.items, entry) orelse return;
        _ = self.deferred.swapRemove(index);
    }

    /// Entries waiting for the last resume (tests, diagnostics).
    pub fn deferredCount(self: *const TeardownHolds) usize {
        return self.deferred.items.len;
    }

    pub fn deinit(self: *TeardownHolds) void {
        self.deferred.deinit(std.heap.c_allocator);
        self.deferred = .empty;
        self.count = 0;
    }

    /// Whether a hold is in progress: teardowns wait, and in Debug builds
    /// the adapter's script-running operations refuse (tests).
    pub fn forbidsScript(self: *const TeardownHolds) bool {
        return self.count != 0;
    }

    /// The agent's record is going (protocol_agents.forgetAgent): no cache
    /// of the agent (`caches`, its live ones) may read these holds again;
    /// one that does holds nothing from now on.
    pub fn forgetCaches(self: *TeardownHolds, caches: *const Caches) void {
        for (caches.items) |cache| {
            if (cache.holds == self) cache.holds = null;
        }
    }
};

/// The holds of `realm`'s agent, through the realm's wrapper cache, which
/// keeps the answer: null for a realm with no engine behind it, or of an
/// isolate createAgent did not make.
fn holdsOfRealm(realm: runtime.Context) ?*TeardownHolds {
    const storage = realm.getV8WrapperCacheStorage() orelse return null;
    const cache: *WrapperCache = @ptrCast(@alignCast(storage));
    const agent = realm.agent orelse return null;
    return cache.teardownHoldsOf(@ptrCast(@alignCast(agent)));
}

/// engine.deferTeardowns: one more hold on `realm`'s agent.
pub fn deferTeardowns(realm: runtime.Context) void {
    const holds = holdsOfRealm(realm) orelse return;
    holds.count += 1;
}

/// Whether `realm`'s agent holds its teardowns now: the Debug check of the
/// adapter's script-running operations (protocol.forbidScriptInHold).
pub fn teardownsHeldInRealm(realm: runtime.Context) bool {
    const holds = holdsOfRealm(realm) orelse return false;
    return holds.count != 0;
}

/// engine.resumeTeardowns: end one hold; the last runs what waited.
pub fn resumeTeardowns(realm: runtime.Context) void {
    const holds = holdsOfRealm(realm) orelse return;
    if (holds.count == 0) {
        if (builtin.mode == std.builtin.OptimizeMode.Debug) log.err("resumeTeardowns with no deferTeardowns left to end: a walk released a hold it did not take", .{});
        return;
    }
    holds.count -= 1;
    if (holds.count != 0) return;
    runDeferredTeardowns(holds);
    // And the node wrappers' releases the hold kept waiting.
    if (realm.agent) |agent| node_wrappers.drainOf(@ptrCast(@alignCast(agent)));
}

/// The last hold has ended: tear down every entry it kept waiting. One at a
/// time, taking the next from the list afresh each time and never holding a
/// slice of it or of a pending list across `finalizeEntry`: a teardown may
/// allocate, start a collection, and that collection's own teardowns -
/// unheld now - edit the pending lists at once; a teardown that walks a
/// document's live ranges takes and ends a hold of its own, whose resume
/// runs this loop too.
fn runDeferredTeardowns(holds: *TeardownHolds) void {
    while (holds.count == 0) {
        const entry = holds.deferred.pop() orelse return;
        entry.bits.teardown_deferred = false;
        finalizeEntry(entry);
    }
}

/// The teardown of a collected record: free its instance unless something
/// still owns it, then the record. Run by the finalizer, or by the cache's
/// end for one whose finalizer has not run yet. (A counted instance - a node
/// - is never here: its wrapper is its agent's, node_wrappers.zig.)
fn finalizeEntry(entry: *Cell) void {
    const cache = entry.cache();
    // Waiting for a hold's end (engine.deferTeardowns) and torn down another
    // way first - its cache's end: it leaves the agent's list.
    if (entry.bits.teardown_deferred) {
        if (cache.holds) |holds| holds.forget(entry) else entry.bits.teardown_deferred = false;
    }
    const instance = entry.instance;

    // An isolated world's wrapper of a node (`Bits.world_counted`): its
    // reference goes with the record (`freeCell`), and nothing of the node is
    // torn down here - its counts decide, as for the main world's wrapper.
    if (entry.bits.world_counted) return cache.freeCell(entry);

    // Replaced or removed before it was collected: nothing of the instance
    // is this record's.
    if (entry.bits.stale) return cache.freeCell(entry);

    // The SlabAllocator can reuse instance addresses: an instance freed
    // since (its own teardown, or the realm's end) and its slot reissued is
    // not this record's to free.
    if (slotReissued(entry)) {
        log.debug("[finalizeEntry] INSTANCE REUSED: instance={*} - generation mismatch, skipping cleanup", .{instance});
        return cache.freeCell(entry);
    }

    // Wrapped again since the collection - script reached the instance
    // through something the host holds, and a new wrapper was made: that
    // wrapper owns it now. Blink's second pass dropped only the collected
    // wrapper's reference for the same reason.
    if (cache.cache.get(instance)) |current| {
        if (current.stamp.generation == entry.stamp.generation) return cache.freeCell(entry);
    }

    // If the CleanupCoordinator is handling teardown, type-specific cleanup
    // must still happen for an instance nothing has cleaned up yet - unless
    // another realm still wraps it.
    //
    // The wrapper finalized here was the last engine object of an instance
    // no other realm wraps, so nothing in script reaches the instance any
    // more (lane pageretention1). One its owner already tore down hands its
    // storage to the teardown, which returns it after its last phase; one
    // still to be torn down is marked released, so that its teardown returns
    // its storage the same way.
    if (runtime.cleanup_coordinator.isContextTearingDown()) {
        const started = runtime.instance_lifecycle.isCleanupStarted(instance);
        const elsewhere = wrappedElsewhere(instance, cache);
        // Never a realm's Window: its realm's end frees it, whatever
        // collection took its global first - a detached frame's realm the
        // collector takes while another realm's teardown is under way
        // (lane winslot1's E10, tests/v8/window_finalized_in_teardown_test.zig).
        // Until lane wrap1 b3 nothing here said so: that test's Window
        // carried a vtable of the test's own, which the entry's vtable
        // comparison took for a reissued slot.
        if (isRealmWindow(instance)) return cache.freeCell(entry);
        if (!started and !elsewhere) {
            runtime.gc.onObjectFreed(instance);
        } else if (!elsewhere) {
            if (!started) {
                runtime.instance_lifecycle.markWrapperGone(instance);
            } else if (runtime.instance_lifecycle.isCleanedUp(instance)) {
                runtime.cleanup_coordinator.deferStorageRelease(instance, entry.stamp.generation);
            }
        }
        return cache.freeCell(entry);
    }

    // Already being cleaned up (its own teardown ran): free the storage a
    // completed cleanup left.
    if (runtime.instance_lifecycle.isCleanupStarted(instance)) {
        if (runtime.instance_lifecycle.isCleanedUp(instance)) runtime.gc.releaseStorage(instance);
        return cache.freeCell(entry);
    }

    // An instance the ENGINE still owns is not freed when JS drops its
    // wrapper: a window's Location or History is its Window's. Only the
    // wrapper goes; a later wrap makes a fresh one. A realm's Window is freed
    // by its realm's end, never by its wrapper's death.
    if (isRealmWindow(instance) or engineOwns(instance)) {
        log.debug("[finalizeEntry] ENGINE-OWNED: instance={*} - wrapper released, instance kept", .{instance});
        // [wrap_tracking]: this was the instance's last engine object - no
        // other realm's cache wraps it, and it is no realm's global - so
        // nothing in script reaches it now, and the host's teardown of it may
        // return its storage (instance_lifecycle.provablyUnwrapped; lane
        // pageretention1). WebKit: the wrapper's `Ref` to its object goes
        // with the wrapper (JSDOMWrapper::m_wrapped).
        if (!isRealmWindow(instance) and !wrappedElsewhere(instance, cache))
            runtime.instance_lifecycle.markWrapperGone(instance);
        return cache.freeCell(entry);
    }

    // Another realm's cache still wraps this instance: only this realm's
    // wrapper goes. See `Caches`.
    if (wrappedElsewhere(instance, cache)) return cache.freeCell(entry);

    // The type's deinit (e.g., Response.deinit frees headers, body, URL
    // list), which returns the Instance to the SlabAllocator - engine calls
    // allowed: it may release the values it holds. The record goes after it:
    // a teardown can collect, and the weak processing skips a record that is
    // still marked collected.
    runtime.gc.onObjectFreed(instance);
    cache.freeCell(entry);
}

const DeferredTeardown = runtime.gc.DeferredTeardown;

/// V8 Wrapper Identity Cache
///
/// Per-context cache maintaining 1:1 mapping between Zig instances and V8 wrappers.
pub const WrapperCache = struct {
    /// HashMap: *runtime.Instance → its record. Each record is the pool's,
    /// not the map's, so a `*Cell` read out of the map stays valid however
    /// the map moves its slots; only a key or value POINTER into the map
    /// (getPtr, getEntry, an iterator) is invalidated by an insert.
    cache: address_map.AddressHashMap(*runtime.Instance, *Cell),

    /// Bounds the tombstones `cache`'s removals leave
    /// (webidl.utils.tombstones). Every collected wrapper takes its entry out
    /// (`unlinkCollected`), and a node waiting on the deferred teardown queue
    /// keeps its address, so a page that makes and drops wrappers puts and
    /// removes keys it never sees again: std's map never counts a tombstone
    /// against its load, never grows, and a miss probes until a FREE slot.
    /// Without the guard gc_bench's append/remove ended with no free slot in
    /// 10 of 14 runs - each miss walked all 16,384 slots, and the realm's end
    /// asks about each of ~78,000 queued nodes twice (2.4 s; 1.2 s with one
    /// free slot left). Every removal is counted here, and `set` rehashes in
    /// place before an insert once they could take half the unused slots -
    /// WTF::HashTable's policy (HashTable.h: `shouldExpand` counts deleted
    /// buckets, `mustRehashInPlace` rebuilds at the same size).
    guard: tombstones.TombstoneGuard = .{},

    /// Walks over `cache` in progress that call out of this file
    /// (`beginWalk`), nested. A rehash moves the map's slots, so an insert
    /// made while one is reading them - a teardown a walk runs can wrap a new
    /// object - does not rehash; the guard keeps counting, and the first
    /// insert after the walk does it.
    walks: u32 = 0,

    /// Allocator for cache entries
    allocator: std.mem.Allocator,

    /// Flag indicating the cache is being torn down.
    /// When true, markAsCleanedUp becomes a no-op to prevent
    /// re-entrant access during deinit iteration.
    is_tearing_down: bool = false,

    /// V8 Context (unused currently, kept for future extensions)
    context: *v8.Context,

    /// An isolated world realm's cache (protocol_worlds.zig): it keeps NODE
    /// wrappers too - the world's, beside the node's own slot, which is the
    /// main world's (Blink's DOMDataStore of a non-main world) - each record
    /// holding a counted reference on its node (`Bits.world_counted`). Set
    /// once, when the world realm is made, before its first wrap.
    world: bool = false,

    /// Whether this cache is on its agent's live caches (`peers`).
    registered: bool = false,
    /// Its agent's live caches (`Caches`, on the agent's record), which it
    /// joined at its first `set`; null until then, and once its agent ended.
    peers: ?*Caches = null,

    /// Pending-activity holds placed before the instance was wrapped
    /// (`holdForPendingActivity`), by slab generation so a reissued address
    /// does not inherit one. `set` moves a hold onto the new wrapper's entry.
    pending_before_wrap: address_map.AddressHashMapUnmanaged(*runtime.Instance, PendingBeforeWrap) = .empty,
    /// Bounds `pending_before_wrap`'s tombstones: every object kept before
    /// script sees it is a key the map never saw, removed when its wrapper
    /// is made, so the map never grew (a 1,069-file runner sample: starved
    /// in 151 of 2,432 samples). Gated on `walks` as `guard` is; nothing
    /// iterates this map but the cache's end.
    pending_guard: tombstones.TombstoneGuard = .{},

    /// Releases of pending activity with no keep left to end
    /// (`releasePendingActivity`): an owner that released what it did not
    /// keep. Zero when every owner balances its keeps.
    unmatched_releases: usize = 0,

    /// Edges `traceChild` drew from an owner script had not seen yet
    /// (protocol_tracing.zig): each child's wrapper held strongly here until
    /// the owner's wrapper is made - `set` draws the edges on it - or this
    /// realm ends. By slab generation, so an owner freed unwrapped and its
    /// address reissued leaves nothing to a newcomer.
    edges_before_wrap: address_map.AddressHashMapUnmanaged(*runtime.Instance, DeferredEdges) = .empty,
    /// Bounds `edges_before_wrap`'s tombstones: every owner that traces a
    /// child before script sees it is a key the map never saw, removed when
    /// its wrapper is made or its edges are pruned (a 1,069-file runner
    /// sample: capacity 16,384 with 73 slots free, 1,338 of 14,167 samples
    /// starved). Gated on `walks` as `guard` is: `detach` walks this map
    /// inside one, and `pruneDeferredEdges` finishes its walk before
    /// `deferEdge` inserts. A `*DeferredEdges` is read and written only
    /// between an insert and the next.
    edges_guard: tombstones.TombstoneGuard = .{},

    /// Past `small_deferred_map` owners, `deferEdge` prunes dead owners'
    /// edges only once the map has grown to this many - then to twice what
    /// the prune left. Pruning on every call walked the whole map each time: a
    /// page whose owners stay unwrapped and alive - every testharness Test
    /// keeps an AbortController whose signal script never reads, and aborts it
    /// at cleanup, keeping the reason (traceValue) - paid O(n) per edge, and
    /// 8,000 test() calls took 1.5 s instead of 0.3 s.
    prune_watermark: usize = small_deferred_map,

    /// Its realm is detached (`detach`): the realm's retained store - which
    /// its global object keeps through its GlobalAnchor - as a WEAK handle
    /// the cache owns, empty once collected. Every wrapper that would be held strongly is
    /// kept by an edge from it instead (`syncEntry`).
    detached_holder: ?*v8.Value = null,

    /// The collector took this cache's realm - a detached realm nothing of
    /// script reached any more (protocol_realms.realmCollected) - and the
    /// realm's end, a task that queues, has not run yet. Until it has, the
    /// realm's Window and its tree are still allocated, and native code can
    /// still reach them through a weak reference (an address and a slab
    /// generation: the embedder's pointer was over one of its elements). The
    /// Window names the objects it made by plain pointers - its Performance,
    /// its Navigator, its Storage objects, each kept alive by a traced edge
    /// from the global object - and the same collection took their wrappers.
    /// So their teardown waits for the realm's end (`finalizeCollected`),
    /// which frees them after the Window, in its own order, as it does for
    /// a realm that ends without having been collected. Freed at the safe
    /// point instead, the Window named freed objects for that while: an
    /// event made in the realm read its Performance for its timestamp - a
    /// segmentation fault in 3 of 96 WPT runner processes
    /// (tests/html/tl1_collected_realm_window_test.zig). Blink has no such
    /// state: a window's Performance is traced from the window, so it lives
    /// exactly as long as the window does - LocalDOMWindow::Trace
    /// (core/frame/local_dom_window.cc) traces its supplements
    /// (Supplementable<LocalDOMWindow>::Trace), and the supplement that
    /// holds the Performance traces it (core/timing/global_performance.cc,
    /// GlobalPerformanceImpl::Trace: `visitor->Trace(performance_)`; read at
    /// chromium main, 2026-11-15).
    realm_collected: bool = false,

    /// The pool the records are issued from (`allocCell`): its chunks, newest
    /// first, and those of them that have a free record. A chunk is the
    /// cache's allocator's; it goes back when its last record is freed
    /// (`freeCell`), and whatever is left at the cache's end.
    chunks: ?*Chunk = null,
    partial: ?*Chunk = null,
    /// How many chunks the pool holds.
    chunk_count: usize = 0,
    /// Walks over `chunks` under way that free records (`finalizePending`,
    /// `orphanPending`): while one runs no chunk is given back - the walk
    /// stands on one - and the empty ones go when the last walk ends.
    pool_walks: u32 = 0,
    pool_release_owed: bool = false,
    /// Tests of a wrap that runs out of memory: the next record comes from a
    /// new chunk whatever the pool has free (`takeFreeRecordsForTest`).
    pool_grows_for_test: bool = false,

    /// Records whose wrapper a collection took and whose finalizer has not
    /// run (`died` -> `finalizeCollected`): each is out of the map, flagged
    /// `collected`, and on its agent's finalizer queue or its teardown
    /// holds. The cache's end finalizes what still waits (`finalizePending`):
    /// a finalizer its agent's safe points never reached does not run on a
    /// freed pool.
    pending: usize = 0,
    /// Every record a collection ever took, and how many of them were taken
    /// off the agent's queue the last time the cache emptied it of its own
    /// (`takePendingOffQueue`).
    deaths: usize = 0,

    /// Weak-handle records whose share a collection took out of the agent's
    /// figure while their wrapper lived (`heldAgain`): expected 0, logged at
    /// the cache's end when it is not, and read by tests and diagnostics
    /// (`liveMispredictionCount`).
    mispredicted: usize = 0,
    deaths_taken: usize = 0,

    /// The realm's isolate, from the first `set`; null before.
    isolate: ?*v8.Isolate = null,
    /// Whether this cache may hold a wrapper by an anchored record: it is on
    /// its agent's live caches and the agent's collections ask them
    /// (`register`). Otherwise every record is boxed.
    anchors: bool = false,

    /// What this realm's end finalizes that no wrapper owns: its promise
    /// reactions that have not run and its asynchronous iterators still
    /// alive (realm_finalizers.zig). The realm's end drains it before the
    /// realm's objects are torn down (context_manager.removeContextByKey);
    /// the cache's own end drains what is left.
    finalizers: realm_finalizers.List = .{},

    /// The agent's deferred teardown queue (engine.AgentOptions.
    /// deferred_teardown), looked up by the first collected node this cache
    /// queues (`deferredQueue`); null before, or when the agent has none.
    /// Every item this cache queued is drained by this realm's end.
    deferred: ?*DeferredTeardown = null,
    deferred_looked_up: bool = false,

    /// The agent's teardown holds (engine.deferTeardowns), looked up by this
    /// cache's first finalizer (`teardownHolds`); null before, or for an
    /// isolate createAgent did not make. The agent outlives its realms'
    /// caches.
    holds: ?*TeardownHolds = null,
    holds_looked_up: bool = false,

    const Self = @This();

    /// Pending activity kept on an instance script has not seen yet.
    pub const PendingBeforeWrap = struct { generation: u64, count: u32 };

    /// A release of pending activity found no keep to end.
    fn unmatchedRelease(self: *Self, instance: *runtime.Instance) void {
        self.unmatched_releases += 1;
        if (builtin.mode == std.builtin.OptimizeMode.Debug) log.err("releasePlatformObject on {s} {*} with no keepPlatformObjectAlive left to end: an owner released what it did not keep", .{ instance.vtable.name, instance });
    }

    /// The queue a collected node of this realm goes to: its agent's - the
    /// isolate collecting, entered in a weak callback.
    fn deferredQueue(self: *Self) ?*DeferredTeardown {
        if (!self.deferred_looked_up) {
            // Looked up only with the realm's isolate entered: a lookup made
            // without one answers nothing and is not remembered (the realm's
            // end asks too, refcount step 7, and a remembered null would make
            // every later finalizer take the queue-less path).
            const isolate = v8.v8_Isolate_GetCurrent() orelse return null;
            self.deferred_looked_up = true;
            self.deferred = @import("protocol_agents.zig").deferredTeardownOf(isolate);
        }
        return self.deferred;
    }

    /// The holds on this realm's agent's teardowns, from a finalizer: the
    /// isolate that collected is entered, as `deferredQueue` finds it.
    fn teardownHolds(self: *Self) ?*TeardownHolds {
        if (self.holds_looked_up) return self.holds;
        const isolate = v8.v8_Isolate_GetCurrent() orelse return null;
        return self.teardownHoldsOf(isolate);
    }

    /// The holds of `isolate`'s agent - this realm's - looked up once.
    fn teardownHoldsOf(self: *Self, isolate: *v8.Isolate) ?*TeardownHolds {
        if (!self.holds_looked_up) {
            self.holds_looked_up = true;
            self.holds = @import("protocol_agents.zig").teardownHoldsOf(isolate);
        }
        return self.holds;
    }

    /// This realm is ending: tear down every node it queued, now, before
    /// anything of the realm goes - what the finalizer would have done had
    /// the teardown not been deferred.
    pub fn drainDeferred(self: *Self) void {
        const queue = self.deferred orelse return;
        queue.drainOwner(self);
    }

    /// This cache's realm, `realm`, ends: the garbage trees the counts queued
    /// under it (dom.refcount_teardown, refcount step 7) are freed now, while
    /// everything of the realm lives - before its coordinated teardown. The
    /// isolate is entered (the realm's end runs inside it).
    pub fn drainRealmGarbage(self: *Self, realm: runtime.Context) void {
        const queue = self.deferredQueue() orelse return;
        @import("dom").refcount_teardown.drainRealm(queue, realm);
    }

    /// Nodes this realm queued and the queue has not freed yet (tests).
    pub fn deferredCount(self: *const Self) usize {
        const queue = self.deferred orelse return 0;
        var count: usize = 0;
        var at = queue.head;
        while (at) |item| : (at = item.next) {
            if (item.owner == @as(?*const anyopaque, self)) count += 1;
        }
        return count;
    }

    /// A walk over `cache` that calls out of this file begins: until the
    /// matching `endWalk`, `set` inserts without rehashing, so the slots the
    /// walk's iterator reads stay where they are. Every iteration of `cache`
    /// whose body can reach code that may wrap an object takes one.
    fn beginWalk(self: *Self) void {
        self.walks += 1;
    }

    fn endWalk(self: *Self) void {
        std.debug.assert(self.walks != 0);
        self.walks -= 1;
    }

    /// Tests: walk the entries as this cache's own walks do (`beginWalk`),
    /// calling `visit` with each instance - which may wrap new objects.
    pub fn walkEntriesForTest(self: *Self, context: anytype, comptime visit: fn (@TypeOf(context), *runtime.Instance) anyerror!void) !void {
        self.beginWalk();
        defer self.endWalk();
        var it = self.cache.keyIterator();
        while (it.next()) |key_ptr| try visit(context, key_ptr.*);
    }

    /// A new chunk for the pool, every record free, at the head of both
    /// lists.
    fn addChunk(self: *Self) error{OutOfMemory}!*Chunk {
        const memory = try self.allocator.alignedAlloc(u8, Chunk.alignment, Chunk.bytes);
        const chunk: *Chunk = @ptrCast(memory.ptr);
        chunk.cache = self;
        chunk.prev = null;
        chunk.next = self.chunks;
        if (self.chunks) |head| head.prev = chunk;
        self.chunks = chunk;
        self.chunk_count += 1;
        chunk.live = 0;
        chunk.free = null;
        // Threaded last to first, so the pool issues a chunk's records in
        // address order.
        var index: usize = Chunk.count;
        while (index > 0) {
            index -= 1;
            const free: *FreeCell = @ptrCast(&chunk.cells[index]);
            free.* = .{ .wrapper = null, .next = chunk.free, .generation = 0, .fresh = 0, .bits = 0 };
            chunk.free = &chunk.cells[index];
        }
        self.listPartial(chunk);
        return chunk;
    }

    /// `chunk` has a free record again, or for the first time: it joins the
    /// chunks records are issued from, at their head.
    fn listPartial(self: *Self, chunk: *Chunk) void {
        chunk.partial_prev = null;
        chunk.partial_next = self.partial;
        if (self.partial) |head| head.partial_prev = chunk;
        self.partial = chunk;
    }

    /// `chunk` leaves the chunks records are issued from: its last free
    /// record was issued, or it is about to be given back.
    fn unlistPartial(self: *Self, chunk: *Chunk) void {
        if (chunk.partial_prev) |prev| prev.partial_next = chunk.partial_next else self.partial = chunk.partial_next;
        if (chunk.partial_next) |next| next.partial_prev = chunk.partial_prev;
        chunk.partial_prev = null;
        chunk.partial_next = null;
    }

    /// `chunk` has no record in use: it goes back to the allocator - unless
    /// it is the only chunk with a free record, which stays, so that a
    /// wrapper made and dropped where the pool is otherwise full does not
    /// allocate a chunk each time; and not while a walk stands on the chunks
    /// (`pool_walks`: the walk's end gives the empty ones back).
    fn releaseIfSpare(self: *Self, chunk: *Chunk) void {
        std.debug.assert(chunk.live == 0);
        if (self.pool_walks != 0) {
            self.pool_release_owed = true;
            return;
        }
        if (self.partial == chunk and chunk.partial_next == null) return;
        self.unlistPartial(chunk);
        if (chunk.prev) |prev| prev.next = chunk.next else self.chunks = chunk.next;
        if (chunk.next) |next| next.prev = chunk.prev;
        self.chunk_count -= 1;
        const memory: [*]align(Chunk.bytes) u8 = @ptrCast(@alignCast(chunk));
        self.allocator.free(memory[0..Chunk.bytes]);
    }

    /// A walk over `chunks` that frees records begins (`pool_walks`).
    fn beginPoolWalk(self: *Self) void {
        self.pool_walks += 1;
    }

    /// The walk ends; the last one's end gives back the chunks the walks
    /// emptied.
    fn endPoolWalk(self: *Self) void {
        std.debug.assert(self.pool_walks != 0);
        self.pool_walks -= 1;
        if (self.pool_walks != 0 or !self.pool_release_owed) return;
        self.pool_release_owed = false;
        var at = self.chunks;
        while (at) |chunk| {
            at = chunk.next;
            if (chunk.live == 0) self.releaseIfSpare(chunk);
        }
    }

    /// A record of the pool, issued: every field but `wrapper` and the kind
    /// is the caller's to fill (`bits.in_use` and `bits.boxed` are set: a
    /// record is no anchored one until it is attached).
    fn allocCell(self: *Self, instance: *runtime.Instance, stamp: u32) error{OutOfMemory}!*Cell {
        const chunk = if (self.pool_grows_for_test) try self.addChunk() else self.partial orelse try self.addChunk();
        const cell = chunk.free.?;
        const free: *FreeCell = @ptrCast(cell);
        chunk.free = free.next;
        chunk.live += 1;
        if (chunk.free == null) self.unlistPartial(chunk);
        cell.* = .{
            .wrapper = null,
            .instance = instance,
            .stamp = .{ .generation = @intCast(runtime.SlabAllocator.generationOf(instance)) },
            .fresh = stamp,
            .bits = .{ .in_use = true, .boxed = true },
        };
        return cell;
    }

    /// `entry` goes back to the pool: nothing names it any more - not the
    /// map, not the agent's finalizer queue or holds, not its wrapper's
    /// anchor (the caller let go of a live record's wrapper first, `letGo`;
    /// a collected one's is gone). What it still owns goes with it: a boxed
    /// record's emptied Global, the strong handle of one that was held. Its
    /// chunk goes back to the allocator when this was its last record
    /// (`releaseIfSpare`): `entry` is not read after this.
    fn freeCell(self: *Self, entry: *Cell) void {
        std.debug.assert(entry.bits.in_use and entry.cache() == self);
        std.debug.assert(!entry.bits.strong);
        // A boxed record's Global, emptied by its collection; an anchored
        // record's reference is empty by now (let go of, or collected).
        letGo(entry, .keep);
        if (entry.bits.world_counted) releaseWorldCount(entry);
        if (entry.bits.collected) self.pending -= 1;
        // A record freed with its wrapper not found dead (a remove, a
        // replacement, its realm's end): its share of the figure goes with
        // it.
        takeHeld(self.isolate, entry, .freed);
        const chunk = Chunk.of(entry);
        const was_full = chunk.free == null;
        const free: *FreeCell = @ptrCast(entry);
        free.* = .{ .wrapper = null, .next = chunk.free, .generation = 0, .fresh = 0, .bits = 0 };
        chunk.free = entry;
        chunk.live -= 1;
        if (was_full) self.listPartial(chunk);
        if (chunk.live == 0) self.releaseIfSpare(chunk);
        self.shrinkMapIfSparse();
    }

    /// The map's slots follow the live wrappers down, as the pool's chunks
    /// do (`releaseIfSpare`): std's map only grows, so a page that held
    /// 200,000 streams at once - each with its reader and its controller -
    /// kept a million slots, 17.8 MB, for the realm's life once they were
    /// collected (lane wrap1 b3's reading of the perf suite's streams page;
    /// tmp/plans/lane-wrap1-handoff.md). When an eighth or less of the slots
    /// is in use, the entries move to a map with room for twice as many.
    /// WebKit's WTF::HashTable has the same policy: after a removal it
    /// shrinks a table whose keys take under a sixth of it (Source/WTF/wtf/
    /// HashTable.h `shouldShrink`, minLoad = 6, WebKit aa0d9480a516; an LGPL
    /// file - the policy was read, no code taken). Each rebuild at least
    /// halves the slots, so a free pays a constant share. Called where a
    /// record is freed: the agent's safe point or a remove, never inside the
    /// collector (`died` only takes an entry out) - and it does nothing
    /// while a walk reads the slots or the cache is torn down. With no
    /// memory for the smaller map, the map stays.
    fn shrinkMapIfSparse(self: *Self) void {
        const capacity = self.cache.capacity();
        if (capacity <= map_shrink_floor) return;
        const count = self.cache.count();
        if (count > capacity / 8) return;
        if (self.walks != 0 or self.is_tearing_down) return;
        var smaller = @TypeOf(self.cache).init(self.allocator);
        smaller.ensureTotalCapacity(@max(count * 2, map_shrink_floor / 4)) catch return;
        var entries = self.cache.iterator();
        while (entries.next()) |kv| smaller.putAssumeCapacityNoClobber(kv.key_ptr.*, kv.value_ptr.*);
        self.cache.deinit();
        self.cache = smaller;
        // A new table has no tombstones.
        self.guard.reset();
    }

    /// At or below this many slots the map is never rebuilt smaller
    /// (`shrinkMapIfSparse`): 17 bytes a slot, 1.1 MB - above what a page's
    /// wrappers between two young collections take, so a make-and-drop loop
    /// never rebuilds its map.
    pub const map_shrink_floor = 1 << 16;

    /// The pool's memory, at the cache's end: every record was freed.
    fn freeChunks(self: *Self) void {
        while (self.chunks) |chunk| {
            self.chunks = chunk.next;
            const memory: [*]align(Chunk.bytes) u8 = @ptrCast(@alignCast(chunk));
            self.allocator.free(memory[0..Chunk.bytes]);
        }
        self.chunk_count = 0;
        self.partial = null;
        self.pool_walks = 0;
        self.pool_release_owed = false;
    }

    /// Hold `entry`'s wrapper strongly: a record's v8::Global (a boxed
    /// record's, a weak-handle record's) stops being weak; a traced record's
    /// wrapper gets a strong handle beside its reference, kept by its
    /// isolate's record (v8_WrapperCell_SetStrong: a droppable reference is
    /// no root in a young collection, and a traced one none in a full one).
    /// Few wrappers are held: most are only script's.
    fn makeStrong(self: *Self, entry: *Cell) void {
        // The bit first: a weak-handle record's first pass reads it
        // (v8_wrapper.cpp kWrapperCellStrong).
        entry.bits.strong = true;
        if (entry.bits.boxed or entry.bits.weak_handle) {
            disarm(entry);
        } else v8.v8_WrapperCell_SetStrong(self.isolate.?, entry.raw(), true);
    }

    /// End `makeStrong`'s hold: the wrapper is the collector's again.
    fn makeWeak(self: *Self, entry: *Cell) void {
        if (entry.bits.boxed or entry.bits.weak_handle) {
            entry.bits.strong = false;
            if (entry.global() != null) armWeak(entry);
            return;
        }
        self.dropStrongHandle(entry);
    }

    fn dropStrongHandle(self: *Self, entry: *Cell) void {
        if (!entry.bits.strong) return;
        entry.bits.strong = false;
        if (!entry.bits.boxed and !entry.bits.weak_handle) v8.v8_WrapperCell_SetStrong(self.isolate.?, entry.raw(), false);
    }

    /// A traced record becomes a weak-handle record: its wrapper is one V8
    /// will not drop in a young collection any more (`changed`). The handle
    /// borrowers hold - the record's address - is the same handle after it.
    /// A record the cache holds strongly stays held: its Global is strong.
    fn toWeakHandle(self: *Self, entry: *Cell) void {
        if (entry.bits.boxed or entry.bits.weak_handle or entry.bits.collected or !entry.bits.in_use) return;
        // An isolated world's node wrapper stays traced (`setConstructed`):
        // the walk keeps it with its node's tree.
        if (entry.bits.world_counted) return;
        const was_strong = entry.bits.strong;
        self.dropStrongHandle(entry);
        // Armed weak in the same call, unless the cache keeps the wrapper.
        if (!v8.v8_WrapperCell_ToWeakHandle(self.isolate.?, entry.raw(), !was_strong)) {
            if (was_strong) self.makeStrong(entry);
            return;
        }
        entry.bits.weak_handle = true;
        entry.bits.marked = false;
        if (was_strong) entry.bits.strong = true;
    }

    /// A collection took `entry`'s wrapper (its reference is empty): the
    /// record leaves the map and waits for its finalizer. Inside the
    /// collector - a young collection's ResetRoot, a full one's weak
    /// processing, a boxed record's first pass - so nothing here calls V8 or
    /// inserts into the map (an insert may rehash - `set`): the record is
    /// only made unreachable. A wrap from here on makes a new wrapper; the
    /// instance's teardown is the finalizer's, after the collection.
    fn died(self: *Self, entry: *Cell) void {
        entry.bits.collected = true;
        // What its instance holds is no live wrapper's any more: it leaves
        // the figure here, where the collector decided - not at the
        // finalizer, which runs after V8 has computed its next limits.
        takeHeld(self.isolate, entry, .dead);
        self.pending += 1;
        self.deaths +%= 1;
        // Due to memory reuse (SlabAllocator/ArenaAllocator), the same
        // instance address can be used for different objects over time: take
        // out only this record; one that replaced it stays.
        if (self.cache.getEntry(entry.instance)) |found| {
            if (found.value_ptr.* == entry) {
                self.cache.removeByPtr(found.key_ptr);
                self.guard.noteRemoval(&self.cache);
                return;
            }
        }
        entry.bits.stale = true;
    }

    /// `entry`, an anchored record a collection just took (`died`), joins
    /// its agent's finalizer queue (a boxed record's handle queues its own).
    /// With no queue - an isolate with no record - it waits for the cache's
    /// end (`finalizePending`).
    fn queueFinalizer(self: *Self, entry: *Cell) void {
        const isolate = self.isolate orelse return;
        _ = v8.v8_Isolate_QueueFinalizer(isolate, &finalizeCollected, entry);
    }

    /// The weak processing of a full collection's atomic pause (`processWeak`)
    /// for this cache: every live anchor's Trace has marked its record
    /// (v8_wrapper.cpp PlatformAnchor::Trace), so an anchored record left
    /// unmarked is a dead wrapper's. Its reference is written empty - raw: V8
    /// frees the unmarked TracedNode itself in this pause
    /// (TracedHandles::ResetDeadNodes; a Reset would free it twice) - and it
    /// leaves the map for the finalizer queue. The pool is walked, not the
    /// map: a record is 32 bytes and a chunk's records are adjacent.
    ///
    /// A weak-handle record's wrapper is not judged here - its Global's
    /// first pass does that, after this pause (`dropped`) - but what its
    /// instance holds leaves the figure here when the marking did not reach
    /// its anchor.
    fn sweepUnmarked(self: *Self) void {
        var at = self.chunks;
        while (at) |chunk| : (at = chunk.next) {
            for (&chunk.cells) |*entry| {
                const bits = entry.bits;
                if (!bits.in_use or bits.boxed or bits.collected) continue;
                if (bits.weak_handle) {
                    entry.bits.marked = false;
                    // A live wrapper's anchor is always traced (the wrapper
                    // points at it), so an anchor this marking did not reach
                    // is a dead wrapper's: what its instance holds leaves the
                    // figure in this pause, with the traced records' dead -
                    // V8 computes its next limits from what it is told here
                    // (v8_wrapper.cpp `forgetDeadWrappedInstances`). The record
                    // itself waits for its Global's first pass, as before.
                    if (!bits.marked) {
                        takeHeld(self.isolate, entry, .dead);
                    } else if (entry.stamp.held == 0) self.heldAgain(entry);
                    continue;
                }
                if (bits.marked) {
                    entry.bits.marked = false;
                    continue;
                }
                entry.wrapper = null;
                self.died(entry);
                self.queueFinalizer(entry);
            }
        }
    }

    /// A weak-handle record whose share left the figure in an earlier
    /// collection's weak processing - that marking had not reached its
    /// anchor - and whose anchor THIS collection's marking reached: the
    /// wrapper lived, so what its instance holds is counted again, and the
    /// case is counted (`mispredicted`). It should not happen: a live
    /// wrapper points at its anchor, V8's marker pushes the anchor of every
    /// wrapper it marks or wraps while a cycle marks (v8_wrapper.cpp
    /// collectingRecord), and every pushed anchor is traced in the pause.
    /// The count is what says so on real pages (the bug-finding sweep reads
    /// the line `endStorage` logs), and the figure does not stay low if it
    /// ever does. An instance torn down under its live wrapper
    /// (`markAsCleanedUp`) or gone is not read.
    fn heldAgain(self: *Self, entry: *Cell) void {
        if (!self.registered or entry.bits.instance_already_cleaned or slotReissued(entry)) return;
        const isolate = self.isolate orelse return;
        self.mispredicted += 1;
        noteWrapped(isolate, entry, wrapperFactsOf(entry.instance));
    }

    /// Tests: `instance`'s live record loses its share of the figure, as in
    /// a weak processing whose marking did not reach its anchor - what
    /// `heldAgain` repairs at the next collection that does.
    pub fn forgetHeldForTest(self: *Self, instance: *runtime.Instance) bool {
        const entry = self.cache.get(instance) orelse return false;
        takeHeld(self.isolate, entry, .freed);
        return true;
    }

    /// Tests: stand in for the collection that takes `instance`'s wrapper -
    /// the record leaves the map as `died` leaves it, its wrapper severed
    /// and let go - without queueing its finalizer: the window between a
    /// collection and the agent's safe point, which `finalizePendingForTest`
    /// ends.
    pub fn collectForTest(self: *Self, instance: *runtime.Instance) bool {
        const entry = self.cache.get(instance) orelse return false;
        self.dropStrongHandle(entry);
        if (entry.bits.boxed) {
            if (entry.wrapper) |box| v8.v8_Global_ClearWeak(@ptrCast(box));
        } else letGo(entry, .sever);
        self.died(entry);
        return true;
    }

    /// Tests of the pool alone (tests/v8/wrapper_cache_pool_test.zig), with
    /// no engine behind the records: how many records a chunk holds, a
    /// record issued for `instance` and given back (never in the map, its
    /// wrapper never set), a walk that frees records, and whether the pool
    /// is down to one chunk that records are issued from.
    pub const records_per_chunk = Chunk.count;

    pub fn allocRecordForTest(self: *Self, instance: *runtime.Instance, stamp: u32) error{OutOfMemory}!*Cell {
        return self.allocCell(instance, stamp);
    }

    pub fn freeRecordForTest(self: *Self, entry: *Cell) void {
        self.freeCell(entry);
    }

    pub fn beginPoolWalkForTest(self: *Self) void {
        self.beginPoolWalk();
    }

    pub fn endPoolWalkForTest(self: *Self) void {
        self.endPoolWalk();
    }

    pub fn ownsRecordForTest(self: *const Self, entry: *const Cell) bool {
        return entry.cache() == self;
    }

    pub fn poolIsOneOpenChunkForTest(self: *const Self) bool {
        const only = self.chunks orelse return false;
        return only.next == null and self.partial == only;
    }

    /// Tests of a wrap that runs out of memory: the pool's free records are
    /// set aside - the next `set` asks the allocator for a chunk - until
    /// they are given back. What was in force before, for the give-back.
    pub fn takeFreeRecordsForTest(self: *Self) bool {
        const before = self.pool_grows_for_test;
        self.pool_grows_for_test = true;
        return before;
    }

    pub fn giveFreeRecordsForTest(self: *Self, taken: bool) void {
        self.pool_grows_for_test = taken;
    }

    /// Tests whose wrappers are mock memory with no engine behind it:
    /// `instance`'s record leaves the cache with no engine call - its box is
    /// the test's to end. Whether there was one.
    pub fn forgetMockForTest(self: *Self, instance: *runtime.Instance) bool {
        const kv = self.cache.fetchRemove(instance) orelse return false;
        self.guard.noteRemoval(&self.cache);
        std.debug.assert(kv.value.bits.boxed);
        kv.value.wrapper = null;
        self.freeCell(kv.value);
        return true;
    }

    /// Tests: run the finalizers waiting for the agent's safe point now.
    pub fn finalizePendingForTest(self: *Self) void {
        self.finalizePending();
    }

    /// Records collected and not finalized yet (tests, diagnostics).
    pub fn pendingFinalizerCount(self: *const Self) usize {
        return self.pending;
    }

    /// This cache's collected records leave the agent's finalizer queue,
    /// uncalled: the cache is about to finalize or drop each one itself, and
    /// then frees the memory a queued finalizer would be handed. Nothing to
    /// take when no record died since the last time (a record joins the
    /// queue only where it dies).
    fn takePendingOffQueue(self: *Self) void {
        if (self.deaths == self.deaths_taken) return;
        self.deaths_taken = self.deaths;
        const isolate = self.isolate orelse return;
        v8.v8_Isolate_TakeQueuedFinalizers(isolate, &finalizeCollected, &belongsToCache, &takenOffQueue, self);
    }

    /// The cache is ending: run every finalizer still waiting for its safe
    /// point now - outside any collection - each as it would have run there.
    /// The pool is walked for the records a collection took; a teardown can
    /// collect, and what that collection takes joins the wait (and the
    /// agent's queue, which is emptied of this cache's records before each
    /// one is finalized), so the walk repeats until none is left.
    fn finalizePending(self: *Self) void {
        self.beginPoolWalk();
        defer self.endPoolWalk();
        while (self.pending != 0) {
            var progressed = false;
            var at = self.chunks;
            while (at) |chunk| : (at = chunk.next) {
                for (&chunk.cells) |*entry| {
                    if (!entry.bits.in_use or !entry.bits.collected) continue;
                    self.takePendingOffQueue();
                    finalizeEntry(entry);
                    progressed = true;
                }
            }
            if (!progressed) break;
        }
    }

    /// The cache is being destroyed without running teardowns
    /// (`deinitWithoutCallbacks`): each waiting record goes now, its instance
    /// with the batch free.
    fn orphanPending(self: *Self) void {
        self.takePendingOffQueue();
        self.beginPoolWalk();
        defer self.endPoolWalk();
        var at = self.chunks;
        while (at) |chunk| : (at = chunk.next) {
            for (&chunk.cells) |*entry| {
                if (!entry.bits.in_use or !entry.bits.collected) continue;
                if (entry.bits.teardown_deferred) {
                    if (self.holds) |holds| holds.forget(entry) else entry.bits.teardown_deferred = false;
                }
                self.freeCell(entry);
            }
        }
    }

    /// The realm is detached - its navigable was destroyed, or a navigation
    /// replaced its document - and lives on only for as long as script
    /// reaches anything of it (protocol_realms, HTML "destroy a child
    /// navigable", "destroy a document"). A strong handle here would keep it
    /// forever, so each wrapper held strongly - a node in a tree, a window's
    /// Location, a streams object, pending activity - is kept from the
    /// realm's retained store instead, and so is each child waiting for its
    /// owner's wrapper (`edges_before_wrap`). `global` is that store - which
    /// the realm's global object keeps through its GlobalAnchor
    /// (realm_global.retainedStore), never the proxy a navigation hands on -
    /// BORROWED: the cache keeps a weak clone of it for the entries synced
    /// later.
    pub fn detach(self: *Self, global: *v8.Value) void {
        if (self.detached_holder != null) return;
        const holder = v8.v8_Global_Clone(global) orelse return;
        v8.v8_Global_SetWeak(@ptrCast(holder), null, detachedHolderCollected);
        self.detached_holder = holder;
        // A walk: syncEntry makes V8 calls that may allocate, and a
        // collection they start runs first passes here (removals only) and
        // queues the teardowns for the agent's safe point.
        self.beginWalk();
        defer self.endWalk();
        var iter = self.cache.valueIterator();
        while (iter.next()) |entry_ptr| syncEntry(entry_ptr.*);
        var deferred_iter = self.edges_before_wrap.valueIterator();
        while (deferred_iter.next()) |deferred| {
            for (deferred.edges.items) |edge| {
                retainOnGlobal(holder, edge.child);
                v8.v8_Global_SetWeak(@ptrCast(edge.child), null, deferredChildCollected);
            }
        }
        // The realm's kept nodes: their wrappers are their agent's, held in
        // its keep table (node_wrappers), by the same rule.
        node_wrappers.detachRealm(@ptrCast(self), holder);
    }

    /// One owner's edges waiting for its wrapper.
    pub const DeferredEdges = struct {
        generation: u64,
        edges: std.ArrayListUnmanaged(DeferredEdge) = .empty,

        fn dispose(self: *DeferredEdges, allocator: std.mem.Allocator) void {
            for (self.edges.items) |edge| edge.dispose(allocator);
            self.edges.deinit(allocator);
        }
    };

    /// A private key (owned) and the child's wrapper, a strong Global
    /// (owned): what `v8_Object_SetPrivateRef` will set on the owner.
    pub const DeferredEdge = struct {
        key: []u8,
        child: *v8.Value,

        fn dispose(self: DeferredEdge, allocator: std.mem.Allocator) void {
            v8.v8_Global_Dispose(self.child);
            allocator.free(self.key);
        }
    };

    /// Hold `child` - a Global the cache takes over, on failure too - for
    /// `owner`, whose wrapper is not made yet, under `key`; until then the
    /// hold is strong. Replaces an edge in the same key.
    pub fn deferEdge(self: *Self, owner: *runtime.Instance, key: []const u8, child: *v8.Value) error{OutOfMemory}!void {
        errdefer v8.v8_Global_Dispose(child);
        const owners = self.edges_before_wrap.count();
        if (owners < small_deferred_map or owners >= self.prune_watermark) {
            self.pruneDeferredEdges();
            self.prune_watermark = @max(small_deferred_map, 2 * self.edges_before_wrap.count());
        }
        const generation = runtime.SlabAllocator.generationOf(owner);
        if (self.walks == 0) self.edges_guard.beforeInsert(&self.edges_before_wrap);
        const gop = try self.edges_before_wrap.getOrPut(self.allocator, owner);
        if (!gop.found_existing) {
            gop.value_ptr.* = .{ .generation = generation };
        } else if (gop.value_ptr.generation != generation) {
            // A dead owner's edges at a reissued address: not the newcomer's.
            gop.value_ptr.dispose(self.allocator);
            gop.value_ptr.* = .{ .generation = generation };
        }
        for (gop.value_ptr.edges.items) |*edge| {
            if (!std.mem.eql(u8, edge.key, key)) continue;
            v8.v8_Global_Dispose(edge.child);
            edge.child = child;
            return;
        }
        const owned_key = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned_key);
        try gop.value_ptr.edges.append(self.allocator, .{ .key = owned_key, .child = child });
    }

    /// End a deferred edge (engine.forgetTracedChild on an owner script has
    /// not seen). A no-op when there is none.
    pub fn forgetDeferredEdge(self: *Self, owner: *runtime.Instance, key: []const u8) void {
        const deferred = self.edges_before_wrap.getPtr(owner) orelse return;
        for (deferred.edges.items, 0..) |edge, i| {
            if (!std.mem.eql(u8, edge.key, key)) continue;
            edge.dispose(self.allocator);
            _ = deferred.edges.swapRemove(i);
            return;
        }
    }

    /// What `owner` keeps under `key` while it waits for its wrapper - a
    /// child's wrapper or a traced value - BORROWED; null when nothing waits
    /// (or what waits is a dead owner's at a reissued address, or a value a
    /// detached realm let go weak and the collector took).
    pub fn deferredEdge(self: *Self, owner: *runtime.Instance, key: []const u8) ?*v8.Value {
        const deferred = self.edges_before_wrap.getPtr(owner) orelse return null;
        if (deferred.generation != runtime.SlabAllocator.generationOf(owner)) return null;
        for (deferred.edges.items) |edge| {
            if (!std.mem.eql(u8, edge.key, key)) continue;
            if (v8.v8_Global_IsEmpty(edge.child)) return null;
            return edge.child;
        }
        return null;
    }

    /// The owner's wrapper is made: draw the edges waiting for it, and let
    /// the strong holds go. Needs a current context, which every wrap has.
    fn drawDeferredEdges(self: *Self, instance: *runtime.Instance, generation: u64, wrapper: *v8.Object) void {
        var kv = self.edges_before_wrap.fetchRemove(instance) orelse return;
        self.edges_guard.noteRemoval(&self.edges_before_wrap);
        defer kv.value.dispose(self.allocator);
        if (kv.value.generation != generation) return;
        for (kv.value.edges.items) |edge| {
            // A child a detached realm let go weak may be gone.
            if (v8.v8_Global_IsEmpty(edge.child)) continue;
            v8.v8_Object_SetPrivateRef(wrapper, edge.key.ptr, @intCast(edge.key.len), edge.child);
        }
    }

    /// Drop the edges of owners freed unwrapped whose teardown did not end
    /// them (their slot's generation moved on): a backstop - an owner that
    /// can be freed unwrapped ends its edges in its teardown
    /// (engine.forgetTracedChild).
    fn pruneDeferredEdges(self: *Self) void {
        var iter = self.edges_before_wrap.iterator();
        while (iter.next()) |kv| {
            if (runtime.SlabAllocator.generationOf(kv.key_ptr.*) == kv.value_ptr.generation) continue;
            kv.value_ptr.dispose(self.allocator);
            // Removing during iteration: the map's own tombstone removal
            // leaves the iterator valid, and noting it never rehashes.
            self.edges_before_wrap.removeByPtr(kv.key_ptr);
            self.edges_guard.noteRemoval(&self.edges_before_wrap);
        }
    }

    /// A map of fewer owners than this is pruned on every `deferEdge` - a walk
    /// that cheap costs less than the edges it lets go; past it, pruning is
    /// amortized (`prune_watermark`).
    const small_deferred_map = 64;

    /// The edges waiting for their owners' wrappers, in this cache.
    pub fn deferredEdgeCount(self: *const Self) usize {
        var total: usize = 0;
        var iter = self.edges_before_wrap.valueIterator();
        while (iter.next()) |deferred| total += deferred.edges.items.len;
        return total;
    }

    /// Every deferred edge's hold, at the realm's end.
    /// The weak handle `detach` kept, at the cache's end.
    fn disposeDetachedHolder(self: *Self) void {
        const holder = self.detached_holder orelse return;
        self.detached_holder = null;
        v8.v8_Global_Dispose(holder);
    }

    fn disposeDeferredEdges(self: *Self) void {
        var iter = self.edges_before_wrap.valueIterator();
        while (iter.next()) |deferred| deferred.dispose(self.allocator);
        self.edges_before_wrap.deinit(self.allocator);
        self.edges_before_wrap = .empty;
        self.edges_guard = .{};
    }

    /// Initialize a new wrapper cache
    ///
    /// Creates an empty HashMap ready to cache wrappers.
    ///
    /// ## Parameters
    /// - allocator: Memory allocator for the map and the pool of records
    /// - context: V8 Context this cache belongs to
    ///
    /// ## Returns
    /// Initialized WrapperCache
    pub fn init(allocator: std.mem.Allocator, context: *v8.Context) !Self {
        return .{
            .cache = address_map.AddressHashMap(*runtime.Instance, *Cell).init(allocator),
            .allocator = allocator,
            .context = context,
        };
    }

    /// Clean up cache resources
    ///
    /// Lets go of every cached wrapper and frees the map and the pool.
    /// Should be called when the V8 Context is destroyed.
    /// This also calls gc.onObjectFreed for each instance to ensure
    /// type-specific deinit is called (the collector may never find a wrapper
    /// dead during shutdown).
    pub fn deinit(self: *Self) void {
        // The pool gives no chunk back from here: the sweeps below free
        // records while they walk the map that still names them, and
        // `endStorage` frees every chunk at the end.
        self.beginPoolWalk();

        // The nodes this realm queued for deferred teardown go first, while
        // the cache can still answer whether one was wrapped again. Its end
        // (context_manager.removeContextByKey) drained them already, unless it
        // ended some other way.
        self.drainDeferred();

        // Mark as tearing down to prevent re-entrant access during cleanup.
        // When a teardown calls markInstanceCleanedUp, it will be a no-op.
        self.is_tearing_down = true;

        // The realm's records no wrapper owns - its end drained them
        // already, unless it ended some other way.
        self.finalizers.drain();

        // PHASE 0: wrappers already collected whose finalizer has not run -
        // it would find this cache gone. Run them now.
        self.finalizePending();

        // PHASE 1: End every weak arm first - a boxed record's, a weak-handle
        // record's - so that no first pass fires for one during cleanup. (A
        // traced record a collection takes while the sweep below runs - a
        // teardown can collect - only joins the wait, and is finalized after
        // the sweep.)
        {
            var iter = self.cache.valueIterator();
            while (iter.next()) |entry_ptr| disarm(entry_ptr.*);
        }

        // PHASE 2: Now clean up all entries.
        // (No dump of the entries' instances here: an entry's slot may be
        // another thread's object by now - the slab is the Browser's - and
        // nothing of it but its stamp is read until `slotReissued` says it is
        // still the entry's.)
        log.debug("[wrapper_cache.deinit] cache={*} PHASE 2: Processing {} entries", .{ self, self.cache.count() });
        // Each entry leaves the map before anything of it is torn down, so
        // the map holds only the entries still to come - never one freed
        // below. A teardown here runs a type's own steps, and they can reach
        // this cache: a response body freed ends its fetch's body, and mark
        // resource timing makes a PerformanceResourceTiming and asks whether
        // it is wrapped (engine.hasWrapper, through `get`). Left in the map,
        // a handled entry answered for whatever object the slab gave its
        // address next - "wrapped", by a freed record's wrapper - and that
        // object was never freed (lane exitleak1: the runner's intermittent
        // groups of 5 and 6 leaked blocks at exit). `set` refuses while the
        // cache is torn down, so nothing joins the map this walks either.
        // (The entry iterator, not the value iterator: it re-reads the map's
        // size, which removal lowers.) A walk, though nothing is inserted
        // while it runs.
        self.beginWalk();
        defer self.endWalk();
        var iter = self.cache.iterator();
        var processed: usize = 0;
        var skipped_cleaned: usize = 0;
        var skipped_started: usize = 0;
        while (iter.next()) |kv| {
            const entry = kv.value_ptr.*;
            self.cache.removeByPtr(kv.key_ptr);
            self.guard.noteRemoval(&self.cache);
            processed += 1;
            const instance = entry.instance;

            // Only call deinit if not already cleaned up externally
            // Check both:
            // 1. instance_already_cleaned flag (set by markAsCleanedUp)
            // 2. isCleanupStarted flag (set at the start of the instance's teardown)
            // The second check catches cases where markAsCleanedUp couldn't set the flag
            // (e.g., if is_tearing_down was already true or entry wasn't found)
            //
            // CRITICAL: Also check if the instance has been reused (its slot's generation
            // moved). The SlabAllocator can reuse memory addresses multiple times. If the
            // instance at this address is different from what we cached, we must NOT call
            // onObjectFreed as it would deinit the wrong object.
            const is_reused = slotReissued(entry);
            const is_started = !entry.bits.world_counted and !is_reused and runtime.instance_lifecycle.isCleanupStarted(instance);
            if (entry.bits.world_counted) {
                // An isolated world's wrapper of a node, at its world realm's
                // end: the wrapper - script may still hold it - reaches the
                // node no more, and its reference goes with the record below.
                // The node is its tree's and its counts', never this sweep's.
                letGo(entry, .sever);
            } else if (entry.bits.instance_already_cleaned) {
                letGo(entry, .sever);
                skipped_cleaned += 1;
                // Its teardown began under its live wrapper (markAsCleanedUp),
                // and the finalizer that would have freed the storage it left
                // will not run. Inside the realm's coordinated teardown the
                // coordinator returns it after the teardown's LAST phase
                // (releaseDeferredStorage), not here: a teardown later in this
                // sweep can still read it, and a slot returned now could be
                // reissued under that read by an allocation the sweep makes.
                // Outside one, it stays as it did (lane unwrapped1).
                if (!is_reused and runtime.instance_lifecycle.isCleanedUp(instance) and
                    !wrappedElsewhere(instance, self))
                    runtime.cleanup_coordinator.deferStorageRelease(instance, entry.stamp.generation);
            } else if (is_reused) {
                // Its slot holds another object now, or none: the wrapper
                // must not reach it. Nothing of the instance is torn down:
                // it is not this entry's.
                letGo(entry, .sever);
                log.debug("[wrapper_cache.deinit] SKIP_REUSED instance={*}", .{instance});
            } else if (is_started) {
                skipped_started += 1;
                // Its owner tore it down and left the storage: free that, and
                // only that - deinit has run. Inside a coordinated teardown,
                // after its last phase (the coordinator), as for an entry
                // `instance_already_cleaned`: returned here, mid-sweep, the
                // slot was the next allocation of any type's (the slab's free
                // list is LIFO) while a teardown later in this sweep could
                // still read it (lane pageretention1; unwrapped1's rule).
                if (runtime.instance_lifecycle.isCleanedUp(instance)) {
                    letGo(entry, .sever);
                    if (runtime.cleanup_coordinator.isContextTearingDown()) {
                        runtime.cleanup_coordinator.deferStorageRelease(instance, entry.stamp.generation);
                    } else {
                        runtime.gc.releaseStorage(instance);
                    }
                } else letGo(entry, .keep);
            } else if (isRealmWindow(instance)) {
                // A Window entry this sweep meets is no realm's own: the
                // realm's end takes its Window's entry out before the sweep
                // (context_manager.removeContextByKey). A Window is freed by
                // its own realm's end, never by another realm's cache: only
                // the wrapper goes (lane winslot1, E3).
                letGo(entry, .sever);
            } else if (wrappedElsewhere(instance, self)) {
                // Another realm's cache still wraps it; that one frees it.
                letGo(entry, .keep);
            } else {
                // The wrapper may outlive this realm (script elsewhere holds
                // it): it must not reach the instance freed next.
                letGo(entry, .sever);
                // Call GC integration to invoke type-specific deinit
                // This is essential for cleanup since the collector may never find the wrapper dead during shutdown
                runtime.gc.onObjectFreed(instance);
            }

            // The record goes - reading nothing of an instance this pass
            // freed.
            self.freeCell(entry);
        }

        // The anchored records a collection took while the sweep ran.
        self.finalizePending();

        log.debug("[wrapper_cache.deinit] Summary: processed={}, skipped_cleaned={}, skipped_started={}", .{ processed, skipped_cleaned, skipped_started });
        // The realm's node wrappers are the agent's (node_wrappers): their
        // owed releases ran before the realm's teardown judged its trees
        // (context_manager.removeContextByKey), and no node is freed here
        // (refcount step 7b).
        self.endStorage();
    }

    /// The cache's own memory, once every record is freed (`deinit`,
    /// `deinitWithoutCallbacks`).
    fn endStorage(self: *Self) void {
        // The figure's one prediction, checked: logged when it was wrong,
        // and for every cache that saw a wrapper die when a runner asked for
        // the counts' diagnostics (CRANE_REFCOUNT_CHECK: the positive control
        // that shows the line can reach a sweep's log at all, as the dying
        // trees' line - dom.refcount_teardown).
        if (self.mispredicted != 0 or (self.deaths != 0 and @import("dom").refcount.diagnosticsOn()))
            log.warn("wrapped instances: {d} wrapper(s) found dead by this cache's collections, {d} weak-handle record(s) taken out of the figure while their wrapper lived", .{ self.deaths, self.mispredicted });
        self.unregister();
        self.cache.deinit();
        self.pending_before_wrap.deinit(self.allocator);
        self.disposeDeferredEdges();
        self.disposeDetachedHolder();
        self.freeChunks();
    }

    /// Clean up cache without calling onObjectFreed callbacks.
    /// Used during context manager teardown to avoid use-after-free
    /// when cleaning up cross-context references (e.g., iframe Windows).
    ///
    /// During normal operation, onObjectFreed is called to trigger
    /// type-specific cleanup. During teardown, all instances will be
    /// batch-freed anyway, so calling individual deinit functions
    /// can cause crashes if they reference already-freed memory.
    ///
    /// No finalizer of this cache's runs after it: the records waiting for
    /// one leave the agent's queue first (`orphanPending`), and every live
    /// record's wrapper is let go of - a boxed one's weak arm ends with its
    /// Global, an anchored one's anchor stops naming the record - before the
    /// pool goes.
    pub fn deinitWithoutCallbacks(self: *Self) void {
        // Mark as tearing down to prevent re-entrant access
        self.is_tearing_down = true;
        // No chunk goes back before `endStorage` frees them all (`deinit`).
        self.beginPoolWalk();

        // The realm's records no wrapper owns: each is disarmed and its host
        // data freed, exactly once, as at any realm end.
        self.finalizers.drain();

        // Collected records waiting for their finalizer: nothing of theirs
        // runs now either; they go.
        self.orphanPending();
        // And the nodes they queued for deferred teardown: forgotten, their
        // instances going with the batch free like every other here.
        if (self.deferred) |queue| queue.dropOwner(self);

        // Every live record: its wrapper let go of (its instance goes with
        // the batch free, after this), then the record.
        {
            var iter = self.cache.valueIterator();
            while (iter.next()) |entry_ptr| {
                const entry = entry_ptr.*;
                letGo(entry, .keep);
                self.freeCell(entry);
            }
        }
        self.endStorage();
    }

    /// Join its agent's live caches (`isolate`'s: the realm's, whose wrapper
    /// `set` is storing) - on first use, when this cache's address is final
    /// (callers copy `init`'s result into place) - and have the agent's
    /// collections ask its caches about their wrappers (`processWeak`,
    /// `dropped`: installed once per isolate, by its first cache). A cache of
    /// an isolate createAgent did not make joins none, and holds every
    /// wrapper by a weak Global (a boxed record): no collection would find
    /// an anchored record's wrapper dead.
    fn register(self: *Self, isolate: *v8.Isolate) void {
        if (self.registered) return;
        self.isolate = isolate;
        const caches = @import("protocol_agents.zig").cachesOf(isolate) orelse return;
        caches.append(std.heap.page_allocator, self) catch return;
        self.peers = caches;
        self.registered = true;
        // The anchors' registry, whose weak processing calls the caches',
        // is made with the agent's node wrapper registry.
        node_wrappers.prepareHolderTracing(isolate);
        self.anchors = v8.v8_Isolate_SetPlatformWrapperHooks(isolate, caches, &processWeak, &dropped, &changed);
    }

    fn unregister(self: *Self) void {
        self.anchors = false;
        if (!self.registered) return;
        const caches = self.peers orelse return;
        for (caches.items, 0..) |c, i| {
            if (c == self) {
                _ = caches.swapRemove(i);
                break;
            }
        }
        // The list's memory goes with its last cache (and with its agent,
        // `endAgent`).
        if (caches.items.len == 0) caches.clearAndFree(std.heap.page_allocator);
        self.registered = false;
        self.peers = null;
    }

    /// The wrapper `instance` already has, BORROWED - a node's one wrapper
    /// whatever realm made it (its alias), else this cache's live entry -
    /// or null when script has not seen it. What a constructor whose
    /// instance was wrapped while it was made returns, instead of binding
    /// the object V8 made for NewTarget (which `set` refuses).
    pub fn existingWrapper(self: *Self, instance: *runtime.Instance) ?*v8.Object {
        if (instance.vtable.counted != null and !self.world) return node_wrappers.wrapperOfInstance(instance);
        const entry = self.cache.get(instance) orelse return null;
        if (entry.bits.instance_already_cleaned or slotReissued(entry)) return null;
        return entry.handle();
    }

    /// Get cached wrapper for an instance
    ///
    /// ## Parameters
    /// - instance: The Zig instance to look up
    ///
    /// ## Returns
    /// The wrapper's handle if cached, BORROWED (`Cell.handle`), null
    /// otherwise
    pub fn get(self: *Self, instance: *runtime.Instance) ?*v8.Object {
        // A node's wrapper is in its own slot, whatever realm asks
        // (node_wrappers): never in a cache - but an isolated world's, which
        // its world realm's cache keeps (`world`).
        if (instance.vtable.counted != null and !self.world) return node_wrappers.wrapperOfInstance(instance);
        if (self.cache.get(instance)) |entry| return entry.handle();
        return null;
    }

    /// Take `wrapper` - a fresh `Global<Object>*` the binding made, OWNED by
    /// the caller until this succeeds - as `instance`'s wrapper in this
    /// realm, and answer the handle the caller holds it by from here,
    /// BORROWED (`Cell.handle`): the cache's record for a platform object's
    /// wrapper - `wrapper`'s box is gone then, disposed once the record's
    /// reference holds the object - `wrapper` itself for an object with no
    /// platform anchor (a realm's global: a boxed record), and for a NODE its
    /// slot's handle (node_wrappers.adopt and arm: the wrapper redesign's P2
    /// and P4, the node's wrapper is its agent's, a TracedReference in its
    /// own slot, never in a cache). On an error nothing was taken and
    /// `wrapper` is still the caller's.
    pub fn set(
        self: *Self,
        instance: *runtime.Instance,
        wrapper: *v8.Object,
        isolate: *v8.Isolate,
    ) !*v8.Object {
        return self.setConstructed(instance, wrapper, isolate, 0);
    }

    /// `set` for the receiver of a script-called constructor, whose
    /// `instance` that same binding call created: `stamp` is when, on its
    /// agent's callback clock (`Cell.fresh`; 0: not fresh). Only the
    /// constructor trampoline calls it, and only for an instance nothing
    /// wrapped while it was made (interface.adoptExistingWrapper returns
    /// first). A node takes no stamp: its wrapper is its slot's, and its
    /// end frees no node.
    pub fn setConstructed(
        self: *Self,
        instance: *runtime.Instance,
        wrapper: *v8.Object,
        isolate: *v8.Isolate,
        stamp: u32,
    ) !*v8.Object {
        // A cache being torn down takes no wrapper: its sweep (`deinit`)
        // walks the map, and an entry put in now would be met or not as the
        // hash order fell - a wrapper whose instance the sweep then never
        // freed. The object stays its maker's to free (releaseIfUnwrapped
        // finds it unwrapped). A node of a realm being torn down is not
        // wrapped either: the teardown under way frees it.
        if (self.is_tearing_down) return error.CacheTornDown;
        self.register(isolate);
        const counted = instance.vtable.counted != null;
        if (counted and !self.world) return self.setNode(instance, wrapper, isolate);

        // An instance has ONE wrapper in a realm. One that is live already
        // is never replaced: every edge drawn on it - a traced child, a
        // [SameObject] value - would go with it (a template's content was
        // freed this way when a constructor bound the template to
        // NewTarget's object, PR-M1). A constructor whose instance was
        // wrapped while it was made returns that wrapper instead
        // (interface.zig, `adoptExistingWrapper`). Only an entry left by a
        // dead instance at a reissued address, or by a torn-down one, gives
        // way below - and a realm's Window, whose wrapper is its realm's
        // global object, bound here when the realm is made: none of its edges
        // hang on a cached wrapper (protocol_tracing.zig holderOf hangs them
        // on the global object).
        const replaced = self.cache.get(instance);
        if (replaced) |existing| {
            if (!existing.bits.instance_already_cleaned and !slotReissued(existing) and !isRealmWindow(instance))
                return error.AlreadyWrapped;
        }

        const entry = try self.allocCell(instance, stamp);
        errdefer self.freeCell(entry);
        // An isolated world's wrapper of a node takes its own reference on
        // the node (`Bits.world_counted`), before anything can see the
        // wrapper - as node_wrappers.adopt's step 1 does for the main
        // world's. Released when the record is freed, on every path.
        if (counted) {
            _ = runtime.lifetime.wrapperAcquired(instance) orelse return error.NotANode;
            entry.bits.world_counted = true;
        }

        // Store in the map. Rehash first if the tombstones could take half
        // the unused slots - never while a walk reads the slots (`walks`).
        // The only insert into `cache`: nothing else here can move its slots
        // but growth.
        //
        // An existing entry here is a dead or torn-down instance's, or a
        // realm's Window's (a live one was refused above): it is let go of
        // as `remove` lets go of one - its wrapper severed, unless it is the
        // realm's global - before the key is taken over.
        if (replaced == null and self.walks == 0) self.guard.beforeInsert(&self.cache);
        try self.cache.put(instance, entry);
        if (replaced) |old_entry| {
            log.debug("[set] replacing existing wrapper for instance={*} old_entry={*} new_entry={*}", .{ instance, old_entry, entry });
            letGo(old_entry, if (isRealmWindow(instance)) .keep else .sever);
            self.freeCell(old_entry);
        }

        // The cache's handle. A platform object's wrapper - an object
        // platform_anchor.bind bound, behind its proxy or not - is held by
        // the record itself, and its anchor names the record: by a weak
        // Global made in the record when V8 would not drop the wrapper in a
        // young collection (`heldByWeakHandle`), by a droppable traced
        // reference otherwise. Anything else (a realm's global) is held by
        // the caller's Global.
        const facts = wrapperFactsOf(instance);
        // An isolated world's node wrapper is always held by a traced
        // reference: the walk keeps it with its node's tree
        // (`traceWorldEntry`), which a weak handle would not let it - it
        // waits for a full collection, as every main-world node wrapper does
        // since the wrapper redesign.
        if (self.anchors and !counted and heldByWeakHandle(facts)) {
            // Armed weak from here; `wrapper`, the caller's box, holds the
            // object until this function's end.
            if (v8.v8_WrapperCell_AttachWeak(isolate, wrapper, entry.raw())) {
                entry.bits.weak_handle = true;
                entry.bits.boxed = false;
            }
        } else if (self.anchors and v8.v8_WrapperCell_Attach(isolate, wrapper, entry.raw())) {
            entry.bits.boxed = false;
        }
        if (entry.bits.boxed) entry.wrapper = @ptrCast(wrapper);

        // Pending-activity keeps placed before the wrapper existed.
        if (self.pending_before_wrap.fetchRemove(instance)) |held| {
            self.pending_guard.noteRemoval(&self.pending_before_wrap);
            if (held.value.generation == entry.stamp.generation) entry.bits.pending_activity = @intCast(@min(held.value.count, std.math.maxInt(u20)));
        }
        // Edges traced from the instance before script saw it.
        self.drawDeferredEdges(instance, entry.stamp.generation, wrapper);
        // (A holder of nodes was bound to its HolderAnchor with the wrapper -
        // platform_anchor.bind - so a collection that keeps this wrapper
        // keeps the wrappers of what it holds for script: the redesign's P6,
        // design 4.4 "Holders"; Blink's holders trace their Member<Node>s.)
        // (A node never gets here: its wrapper is its agent's, in its own
        // slot - `setNode` - a constructor's included, and the walk keeps it.)
        // (A weak-handle record is armed already: where it was attached,
        // or where the edges just drawn made a traced record one -
        // `changed`.)
        if (shouldBeStrong(entry) and self.detached_holder == null) {
            self.makeStrong(entry);
        } else {
            if (entry.bits.boxed) armWeak(entry);
            if (self.detached_holder != null) syncEntry(entry);
        }

        // What the instance holds, for the collector's schedule (the one
        // call: v8_wrapper.cpp, "What the instances behind non-node wrappers
        // hold") - in an agent's realm; a cache of no agent's isolate
        // reports nothing.
        // (A node's own memory is counted by its Browser - dom_memory - not
        // here: an isolated world's node wrapper adds nothing to the figure.)
        if (self.registered and !counted) noteWrapped(isolate, entry, facts);

        if (entry.bits.boxed) return wrapper;
        // The record's reference holds the wrapper from here; until here the
        // caller's box did, across everything above that allocates.
        v8.v8_Object_Dispose(wrapper);
        return entry.handle();
    }

    /// `set` for a node: its wrapper goes into the node's own slot, its
    /// agent's, with its anchor on the agent's C++ heap (node_wrappers.adopt)
    /// - then, as for every wrapper, the edges traced from it before script
    /// saw it. Nothing else is written on the wrapper: the walk keeps a
    /// tree's wrappers (the wrapper redesign's P7 deleted node tracing's
    /// edges and the upward closure), so a wrapper nothing else changes stays
    /// an unmodified API object V8 may drop in a scavenge (design 4.11, P8)
    /// and a wrap makes exactly one wrapper.
    fn setNode(self: *Self, instance: *runtime.Instance, box: *v8.Object, isolate: *v8.Isolate) !*v8.Object {
        const generation = runtime.SlabAllocator.generationOf(instance);
        const adopted = try node_wrappers.adopt(isolate, instance, box);
        // Held strongly - by `box`, which `arm` disposes - while the deferred
        // edges are drawn: they allocate, and a collection then must not take
        // this wrapper.
        defer node_wrappers.arm(isolate, instance, adopted);
        // Edges traced from the node before script saw it.
        self.drawDeferredEdges(instance, generation, adopted.handle);
        return adopted.handle;
    }

    /// Clear the entire cache
    ///
    /// Lets go of all cached wrappers, tears their instances down and
    /// clears the map. Useful for testing or explicit cache invalidation.
    pub fn clear(self: *Self) void {
        // The sweep below frees records while it walks the map: the pool
        // gives its empty chunks back when it is done.
        self.beginPoolWalk();
        defer self.endPoolWalk();

        // Collected entries waiting for their finalizer run it now, and the
        // nodes they queued are torn down.
        self.finalizePending();
        self.drainDeferred();

        // PHASE 1: End every weak arm first, as `deinit` does.
        {
            var iter = self.cache.valueIterator();
            while (iter.next()) |entry_ptr| disarm(entry_ptr.*);
        }

        // PHASE 2: Now clean up all entries. A walk: a teardown run here can
        // wrap a new object (`set`).
        self.beginWalk();
        defer self.endWalk();
        var iter = self.cache.iterator();
        while (iter.next()) |kv| {
            const entry = kv.value_ptr.*;
            self.cache.removeByPtr(kv.key_ptr);
            self.guard.noteRemoval(&self.cache);
            const instance = entry.instance;

            // Call GC integration to invoke type-specific deinit - unless
            // another realm's cache still wraps the instance. The wrapper of
            // an instance freed here reaches it no more.
            if (entry.bits.world_counted) {
                // An isolated world's node wrapper: its reference goes with
                // the record, the node stays its counts'.
                letGo(entry, .sever);
            } else if (!wrappedElsewhere(instance, self)) {
                letGo(entry, .sever);
                runtime.gc.onObjectFreed(instance);
            } else letGo(entry, .keep);

            self.freeCell(entry);
        }
        // The anchored records a collection took while the entries were torn
        // down.
        self.finalizePending();
        self.disposeDeferredEdges();
    }

    /// Mark an entry as already cleaned (instance deinit already called)
    ///
    /// This is used when the instance is being cleaned up by other means.
    /// We mark it so that wrapper_cache.deinit() won't call onObjectFreed
    /// again (double-free).
    ///
    /// We don't let go of the wrapper here because we might still be in
    /// JavaScript execution context. That happens during
    /// wrapper_cache.deinit(), or when the wrapper is collected.
    ///
    /// ## Parameters
    /// - instance: The Zig instance that has been cleaned up
    ///
    /// ## Returns
    /// true if entry was found and marked, false if not in cache
    pub fn markAsCleanedUp(self: *Self, instance: *runtime.Instance) bool {
        // CRITICAL: Skip during teardown to avoid HashMap access corruption.
        // During wrapper_cache.deinit, we're iterating and freeing entries.
        //
        // Instead, callers should use runtime.instance_lifecycle.markCleanupStarted()
        // which uses a SEPARATE tracking data structure that's safe to access
        // during teardown. The wrapper_cache.deinit loop already checks
        // isCleanupStarted() before calling gc.onObjectFreed.
        if (self.is_tearing_down) {
            return false;
        }

        if (self.cache.get(instance)) |entry| {
            // Mark as already cleaned - deinit will skip onObjectFreed
            entry.bits.instance_already_cleaned = true;
            // The instance is gone, its wrapper not: script may still hold
            // it. Weak from here, whatever held it before - its finalizer,
            // which skips an instance whose cleanup started, frees the
            // storage the teardown left (releaseStorage). It used to be held
            // strongly until the page ended, a wrapper and an instance a
            // torn-down object, and with it everything it reaches.
            if (entry.bits.strong) self.makeWeak(entry);
            return true;
        }
        return false;
    }

    /// Remove a specific entry from the cache
    ///
    /// Removes the entry completely: the cache lets go of the wrapper, which
    /// - if script still holds it - reaches its instance as before, cached
    /// no more. Use markAsCleanedUp() instead if still in JS execution
    /// context.
    ///
    /// ## Parameters
    /// - instance: The Zig instance to remove from cache
    ///
    /// ## Returns
    /// true if entry was found and removed, false if not in cache
    pub fn remove(self: *Self, instance: *runtime.Instance) bool {
        if (self.cache.fetchRemove(instance)) |kv| {
            self.guard.noteRemoval(&self.cache);
            const entry = kv.value;
            letGo(entry, .keep);
            self.freeCell(entry);
            return true;
        }
        return false;
    }

    /// The walk named `instance`'s node (protocol_worlds.traceWorldWrappers,
    /// in a collection's atomic pause): this world cache's wrapper of it is
    /// kept - its traced reference traced through the collection's visitor,
    /// as engine.traceNodeWrapper traces a node's own slot. A record held by
    /// a weak handle (a wrapper the binding changed) is not: only script
    /// keeps it. Read-only; nothing allocated.
    pub fn traceWorldEntry(self: *const Self, instance: *runtime.Instance, visitor: *anyopaque) void {
        const entry = self.cache.get(instance) orelse return;
        const bits = entry.bits;
        if (!bits.in_use or bits.boxed or bits.weak_handle or bits.collected) return;
        if (entry.wrapper == null) return;
        // The record's first word IS the TracedReference (`Cell.wrapper`).
        v8.v8_NodeTracer_TraceSlot(visitor, @ptrCast(entry));
    }

    /// `instance`, a node, was torn down whatever its counts said (a forced
    /// realm end's coordinated teardown): this world cache's wrapper of it
    /// reaches it no more, and its reference is forgotten with the node - as
    /// node_wrappers.nodeDestroyed ends the main world's. Not while the
    /// cache is torn down: its sweep severs every record.
    pub fn worldNodeDestroyed(self: *Self, instance: *runtime.Instance) void {
        if (self.is_tearing_down or !self.world) return;
        const kv = self.cache.fetchRemove(instance) orelse return;
        self.guard.noteRemoval(&self.cache);
        const entry = kv.value;
        letGo(entry, .sever);
        if (entry.bits.world_counted) {
            entry.bits.world_counted = false;
            runtime.lifetime.wrapperForgotten();
        }
        self.freeCell(entry);
    }

    /// Get cache statistics
    ///
    /// Returns the number of cached wrappers.
    /// Useful for debugging and monitoring.
    pub fn size(self: *const Self) usize {
        return self.cache.count();
    }
};

// No test lives in this file: a test block inside src/runtime/engines/v8/ is
// never collected (build.zig, "V8 engine tests"). The pool's and the map's
// tests are tests/v8/wrapper_cache_pool_test.zig and
// wrap1_platform_anchor_test.zig; the cache with mock wrappers is
// wrapper_cache_gc_test.zig.
