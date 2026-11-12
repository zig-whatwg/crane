//! The V8 adapter's node wrappers (the wrapper redesign,
//! tmp/redesign/wrapper-redesign-design.md sections 3.3, 3.5, 4.5, 4.9 and
//! 7's P2).
//!
//! A node's one wrapper per agent lives in the node itself: its
//! engine.NodeWrapperSlot (8 bytes of its NodeBase, reached only through
//! runtime.lifetime.slotOf) holds a weak `v8::Global<v8::Object>`
//! CONSTRUCTED IN PLACE - pre-Oilpan Blink's `ScriptWrappable::m_wrapper`
//! (Chromium 45 bindings/core/v8/ScriptWrappable.h). The slot's word is the
//! Global's own slot pointer, so the slot's ADDRESS is the `Global<Object>*`
//! every borrower of the node's wrapper gets (`wrapperOf`). A node wrapper
//! never enters the WrapperCache: no CacheEntry, no map slot, no `new
//! Global` box, no WeakCallbackData, no entry in v8_wrapper.cpp's
//! process-wide armed map.
//!
//! Its weak parameter is the node's CELL in its agent's `Registry`: 8 bytes in
//! a chunk of 512, holding the counted object the wrapper's reference is on
//! (a NodeBase), with a free list threaded through the free cells.
//!
//! - **Wrap** (`adopt`, from WrapperCache.set): the count first
//!   (runtime.lifetime.wrapperAcquired), then the box's Global moves into the
//!   slot and is armed weak with the cell - or held strongly while the node
//!   has a pending-activity keep.
//! - **Collection**: V8's FIRST pass (`collected`) frees the cell, records the
//!   release, and answers the slot, which v8_wrapper.cpp Resets ("Handle not
//!   reset in first callback"): no other V8 call, no count change, no free.
//!   The pass also says a node wrapper died (one flag, one bit owed: no
//!   second pass is set); at the agent's safe point after the collection
//!   (v8_wrapper.cpp `runQueuedFinalizers`, never inside the collector)
//!   `drainCallback` releases the recorded references -
//!   unless a walk holds the agent's teardowns (engine.deferTeardowns), whose
//!   last resume drains instead. A release only counts: a tree it leaves
//!   with no hold is queued by the counts (dom.refcount_teardown) - A
//!   COLLECTION NEVER FREES A NODE.
//! - **A realm's end** keeps refcount step 7a's net for the realm's detached
//!   trees, as the wrapper cache's sweep made it while node wrappers were its
//!   entries, once no wrapper reaches them (`endRealm`, `endedRealmNet`):
//!   their roots are freed whatever their counts, in a slice. A tree a live
//!   wrapper reaches - script of another realm may hold it - waits for that
//!   wrapper. Refcount step 7b removes the net.
//! - **A wrap between the two passes** makes a new wrapper with its own
//!   reference; the drain releases the collected one's only (refcount design
//!   2.1, "wrapped again between the passes").
//! - **Keeps** (engine.keepPlatformObjectAlive on a node: pending activity, a
//!   window's document): the agent's keep table, counted. The slot's Global
//!   is strong while a keep remains; in a detached realm the wrapper is kept
//!   by an edge from the realm's global object instead (as
//!   WrapperCache.detach does for its entries).
//! - **The node's teardown under a live wrapper** (engine.
//!   platformObjectDestroyed: a forced realm end's coordinated teardown frees
//!   a tree whatever the counts say): the wrapper is severed and the slot
//!   Reset, the cell freed, the wrapper's reference released.
//! - **The agent's end** (engine.releaseNodeWrappers, which the host calls
//!   before its last drain, and destroyAgent): every live wrapper the same
//!   way, so the host's drain frees the trees only wrappers held (design 4.9;
//!   lane wr2's dated note there). The registry itself ends with the isolate
//!   (v8_wrapper.cpp v8_Isolate_Dispose).
//!
//! P4 makes the slot a TracedReference and the cell a cppgc anchor
//! (Blink's `TraceWrapperV8Reference`): the same 8 bytes.

const std = @import("std");
const runtime = @import("runtime");
const ffi = @import("ffi.zig");
const tombstones = @import("webidl").utils.tombstones;
const address_map = @import("infra").address_map;

const log = std.log.scoped(.node_wrappers);

/// engine.NodeWrapperSlot on V8: one `v8::Global<v8::Object>`, whose one
/// word this is.
pub const NodeWrapperSlot = extern struct {
    /// The Global's slot pointer (V8's `internal::Address*`): null for a node
    /// with no wrapper in this agent. Written by V8's Global (constructed in
    /// place, Reset in place), never by Zig.
    handle: ?*anyopaque = null,

    pub const empty: NodeWrapperSlot = .{};

    pub fn isEmpty(self: *const NodeWrapperSlot) bool {
        return self.handle == null;
    }
};

/// The slot's wrapper as a `Global<Object>*` - the slot's own address -
/// BORROWED, or null for an empty slot. Valid while the node lives and the
/// slot is not Reset: take a reference of your own (a Local, a clone) before
/// anything that can collect.
pub fn wrapperOf(slot: *NodeWrapperSlot) ?*ffi.Object {
    if (slot.isEmpty()) return null;
    return @ptrCast(slot);
}

/// The counted object (a NodeBase) behind `instance`, without a reference;
/// null for an instance that is not a node, or whose NodeBase is gone.
fn targetOf(instance: *runtime.Instance) ?*anyopaque {
    if (instance.vtable.counted == null) return null;
    const node = @import("dom").instance_bridge.getNodeBase(@ptrCast(instance)) orelse return null;
    return node;
}

/// The instance whose counted object `target` is.
fn instanceOfTarget(target: *anyopaque) ?*runtime.Instance {
    const raw = @import("dom").instance_bridge.getInstance(@ptrCast(@alignCast(target))) orelse return null;
    return @ptrCast(@alignCast(raw));
}

/// `instance`'s node slot, or null when it is no node (or its NodeBase went).
pub fn slotOfInstance(instance: *runtime.Instance) ?*NodeWrapperSlot {
    return runtime.lifetime.slotOf(targetOf(instance) orelse return null);
}

/// Whether `instance`, a node, has a wrapper now (engine.hasWrapper).
pub fn hasWrapper(instance: *runtime.Instance) bool {
    const slot = slotOfInstance(instance) orelse return false;
    return !slot.isEmpty();
}

/// `instance`'s node wrapper, BORROWED (`wrapperOf`), or null.
pub fn wrapperOfInstance(instance: *runtime.Instance) ?*ffi.Object {
    return wrapperOf(slotOfInstance(instance) orelse return null);
}

/// The isolate of `instance`'s realm's agent - or, for a realm made with
/// none (a test's own ContextData), the isolate current on this thread,
/// whose registry its wraps used - or null.
fn isolateOfInstance(instance: *runtime.Instance) ?*ffi.Isolate {
    const agent = instance.ctx.agent orelse return ffi.v8_Isolate_GetCurrent();
    return @ptrCast(@alignCast(agent));
}

const cells_per_chunk = 512;
const Chunk = [cells_per_chunk]Cell;

/// A live cell holds its wrapper's counted object (a NodeBase, 8-aligned:
/// bit 0 clear); a free one the next free cell with bit 0 set (`free_tag`
/// alone at the end of the list).
const Cell = struct { word: usize };
const free_tag: usize = 1;

fn cellIsLive(cell: *const Cell) bool {
    return cell.word != 0 and cell.word & free_tag == 0;
}

/// A collected wrapper's reference, waiting for the drain: its counted
/// object, and the instance with the slab generation it had at the first
/// pass - a forced teardown can free the node in between, and is then
/// recognised the way the wrapper cache's `releaseCounted` recognises one.
const Released = struct {
    target: *anyopaque,
    instance: *runtime.Instance,
    generation: u64,
};

/// A node's pending-activity keeps (engine.keepPlatformObjectAlive), counted.
const Keep = struct {
    /// The instance's slab generation when the keep was taken: an entry left
    /// by a freed node at a reissued address is not the newcomer's.
    generation: u64,
    count: u32 = 0,
    /// The cell of the wrapper the keep holds strongly - V8 has no weak
    /// parameter to answer it while the Global is strong - or null.
    cell: ?*Cell = null,
    /// Kept by an edge from its detached realm's global object instead.
    retained: bool = false,
};

/// One agent's node wrappers: the cells, the releases waiting for the drain,
/// the keep table. OWNED by the isolate's record (v8_wrapper.cpp
/// IsolateData::node_wrappers), made on its first node wrap or keep; used on
/// the agent's thread only.
pub const Registry = struct {
    isolate: *ffi.Isolate,
    chunks: std.ArrayListUnmanaged(*Chunk) = .empty,
    free: ?*Cell = null,
    /// Cells holding a wrapper now.
    live: usize = 0,
    released: std.ArrayListUnmanaged(Released) = .empty,
    keeps: address_map.AddressHashMapUnmanaged(*runtime.Instance, Keep) = .empty,
    /// Bounds `keeps`' tombstones: every keep ends with a removal.
    keeps_guard: tombstones.TombstoneGuard = .{},
    /// The agent's teardown holds (engine.deferTeardowns), BORROWED from its
    /// record until the agent's end; null for an isolate createAgent did not
    /// make.
    holds: ?*const @import("wrapper_cache.zig").TeardownHolds = null,
    /// The agent will run no more script (engine.releaseNodeWrappers): no
    /// node is wrapped from here on.
    ended: bool = false,
    /// Releases the first pass could not record (no memory): references
    /// kept, so those trees are freed only at the agent's end. Diagnostics.
    lost_releases: u64 = 0,

    fn allocCell(self: *Registry) error{OutOfMemory}!*Cell {
        if (self.free == null) {
            const chunk = try std.heap.c_allocator.create(Chunk);
            errdefer std.heap.c_allocator.destroy(chunk);
            try self.chunks.append(std.heap.c_allocator, chunk);
            var i: usize = cells_per_chunk;
            while (i > 0) {
                i -= 1;
                chunk[i].word = @intFromPtr(self.free) | free_tag;
                self.free = &chunk[i];
            }
        }
        const cell = self.free.?;
        self.free = @ptrFromInt(cell.word & ~free_tag);
        cell.word = 0;
        self.live += 1;
        return cell;
    }

    fn freeCell(self: *Registry, cell: *Cell) void {
        std.debug.assert(cellIsLive(cell) or cell.word == 0);
        cell.word = @intFromPtr(self.free) | free_tag;
        self.free = cell;
        self.live -= 1;
    }

    /// The live keep of `instance`, or null.
    fn liveKeep(self: *Registry, instance: *runtime.Instance) ?*Keep {
        const entry = self.keeps.getPtr(instance) orelse return null;
        if (entry.generation != runtime.SlabAllocator.generationOf(instance) or entry.count == 0) return null;
        return entry;
    }

    /// Release what the collections recorded - unless a walk holds the
    /// agent's teardowns: its last resume drains (`drainOf`).
    pub fn drain(self: *Registry) void {
        if (self.ended) return;
        if (self.holds) |holds| if (holds.count != 0) return;
        // One at a time, the next taken afresh: a release can run what wraps
        // and collects, whose first passes append here.
        while (self.released.pop()) |released| releaseOne(self, released);
    }

    /// Every node wrapper's reference goes, its slot severed and Reset - the
    /// recorded releases first. Passes until no cell is live: a release can
    /// run what wraps (unless `ended`).
    fn releaseAll(self: *Registry) void {
        while (self.released.pop()) |released| releaseOne(self, released);
        var passes: usize = 0;
        while (self.live != 0) : (passes += 1) {
            if (passes == 8) {
                log.err("{d} node wrapper(s) still live after {d} passes at the agent's end", .{ self.live, passes });
                return;
            }
            var chunk_index: usize = 0;
            while (chunk_index < self.chunks.items.len) : (chunk_index += 1) {
                const chunk = self.chunks.items[chunk_index];
                for (chunk) |*cell| {
                    if (!cellIsLive(cell)) continue;
                    const target: *anyopaque = @ptrFromInt(cell.word);
                    const slot = runtime.lifetime.slotOf(target);
                    ffi.v8_NodeWrapper_Reset(self.isolate, @ptrCast(slot), true);
                    self.freeCell(cell);
                    endReference(self, target);
                }
            }
            while (self.released.pop()) |released| releaseOne(self, released);
        }
    }

    fn deinit(self: *Registry) void {
        for (self.chunks.items) |chunk| std.heap.c_allocator.destroy(chunk);
        self.chunks.deinit(std.heap.c_allocator);
        self.released.deinit(std.heap.c_allocator);
        self.keeps.deinit(std.heap.c_allocator);
        self.* = undefined;
    }
};

/// A collected or ended wrapper's reference goes - only while its node is
/// still the one it was taken on (`released.generation`) and its teardown
/// has not begun (that teardown let it go or forgot it).
fn releaseOne(registry: *Registry, released: Released) void {
    if (runtime.SlabAllocator.generationOf(released.instance) != released.generation or
        runtime.instance_lifecycle.isCleanupStarted(released.instance))
    {
        runtime.lifetime.wrapperForgotten();
        return;
    }
    // No wrapper since ([wrap_tracking]): nothing in script reaches the node
    // now, so its teardown may return its storage.
    if (runtime.lifetime.slotOf(released.target).isEmpty()) runtime.instance_lifecycle.markWrapperGone(released.instance);
    runtime.lifetime.wrapperReleased(released.target);
    endedRealmNet(registry, released.target);
}

/// A live wrapper ended outside a collection (its slot Reset by the caller):
/// no wrapper reaches the node now, and the wrapper's reference goes.
fn endReference(registry: *Registry, target: *anyopaque) void {
    if (instanceOfTarget(target)) |instance| runtime.instance_lifecycle.markWrapperGone(instance);
    runtime.lifetime.wrapperReleased(target);
    endedRealmNet(registry, target);
}

/// Refcount step 7a's net for a tree of a realm that ENDED (its engine
/// context gone: no script of it runs again), as the wrapper cache's sweep
/// and finalizer made it while node wrappers were its entries: when the
/// last wrapper that reached such a detached tree goes and the tree is still
/// held - by its own pending work's counted reference (an <img>'s image
/// update, a dialog's close watcher) that only its realm's end would have
/// let go - the tree is freed whatever its counts, in a slice of the agent's
/// queue (never in the collection). A holder that counts it forgets it then
/// (its generation net). Refcount step 7b removes the net. A tree script of a
/// live realm still reaches through a wrapper is never the net's: the net
/// waits for that wrapper to go.
fn endedRealmNet(registry: *Registry, target: *anyopaque) void {
    const dom = @import("dom");
    var root: *dom.NodeBase = @ptrCast(@alignCast(target));
    while (root.parent_node) |parent| root = parent;
    if (root.rc_flags.hosted or root.rc_flags.garbage or root.subtree_holds == 0) return;
    if (!runtime.lifetime.slotOf(root).isEmpty()) return;
    const instance = instanceOfTarget(root) orelse return;
    if (instance.ctx.hasEngine()) return;
    if (root.node_type == dom.NodeBase.DOCUMENT_NODE) return;
    const queue = @import("protocol_agents.zig").deferredTeardownOf(registry.isolate) orelse return;
    _ = queue.push(.{
        .instance = instance,
        .generation = runtime.SlabAllocator.generationOf(instance),
        .owner = null,
        .steps = &net_root_steps,
    });
}

const net_root_steps: runtime.gc.DeferredTeardown.Steps = .{ .run = runNetRoot };

/// A slice of the ended-realm net (`endedRealmNet`): the root's own teardown
/// frees its tree - once it is still that detached root, unwrapped, of a
/// realm that ended.
fn runNetRoot(item: *runtime.gc.DeferredTeardown.Item, budget: usize) runtime.gc.DeferredTeardown.Progress {
    _ = budget;
    const done: runtime.gc.DeferredTeardown.Progress = .{ .freed = 0, .done = true };
    const instance = item.instance;
    if (runtime.SlabAllocator.generationOf(instance) != item.generation) return done;
    if (runtime.instance_lifecycle.isCleanupStarted(instance)) return done;
    const root = targetOf(instance) orelse return done;
    const node: *@import("dom").NodeBase = @ptrCast(@alignCast(root));
    if (node.parent_node != null or node.rc_flags.hosted) return done;
    if (!runtime.lifetime.slotOf(root).isEmpty()) return done;
    if (instance.ctx.hasEngine()) return done;
    runtime.gc.onObjectFreed(instance);
    return .{ .freed = 1, .done = true };
}

/// `isolate`'s registry, or null before its first node wrap or keep.
pub fn registryOf(isolate: *ffi.Isolate) ?*Registry {
    const raw = ffi.v8_Isolate_NodeWrappers(isolate) orelse return null;
    return @ptrCast(@alignCast(raw));
}

/// `isolate`'s registry, made (and handed to its record) on first use.
fn ensureRegistry(isolate: *ffi.Isolate) error{ OutOfMemory, NoIsolateRecord }!*Registry {
    if (registryOf(isolate)) |registry| return registry;
    const registry = try std.heap.c_allocator.create(Registry);
    errdefer std.heap.c_allocator.destroy(registry);
    registry.* = .{ .isolate = isolate, .holds = @import("protocol_agents.zig").teardownHoldsOf(isolate) };
    if (!ffi.v8_Isolate_SetNodeWrappers(isolate, registry, &collected, &drainCallback, &endCallback)) return error.NoIsolateRecord;
    return registry;
}

/// V8's first pass for a collected node wrapper (v8_wrapper.cpp
/// nodeWrapperFirstPass): the cell freed, the release recorded. Answers the
/// node's slot, which the caller Resets. No V8 call, no count change.
fn collected(raw_registry: ?*anyopaque, raw_cell: ?*anyopaque) callconv(.c) ?*anyopaque {
    const registry: *Registry = @ptrCast(@alignCast(raw_registry.?));
    const cell: *Cell = @ptrCast(@alignCast(raw_cell.?));
    std.debug.assert(cellIsLive(cell));
    const target: *anyopaque = @ptrFromInt(cell.word);
    const slot = runtime.lifetime.slotOf(target);
    registry.freeCell(cell);
    // The node is alive: its wrapper's reference holds it, and a teardown
    // under a live wrapper Resets the slot (and frees the cell) first.
    if (instanceOfTarget(target)) |instance| {
        // No engine object reaches the node from here ([wrap_tracking]; a
        // slab bit, no allocation): a teardown that runs before the drain
        // returns its storage itself, and a wrap meanwhile clears it.
        runtime.instance_lifecycle.markWrapperGone(instance);
        registry.released.append(std.heap.c_allocator, .{
            .target = target,
            .instance = instance,
            .generation = runtime.SlabAllocator.generationOf(instance),
        }) catch {
            registry.lost_releases += 1;
        };
    } else registry.lost_releases += 1;
    return slot;
}

/// The agent's safe point after a collection (v8_wrapper.cpp
/// `runQueuedFinalizers`): the agent's drain.
fn drainCallback(raw_registry: ?*anyopaque) callconv(.c) void {
    const registry: *Registry = @ptrCast(@alignCast(raw_registry.?));
    registry.drain();
}

/// The registry's end, at the start of v8_Isolate_Dispose (the isolate and
/// its record still alive): whatever is still wrapped ends, then its memory.
fn endCallback(raw_registry: ?*anyopaque) callconv(.c) void {
    const registry: *Registry = @ptrCast(@alignCast(raw_registry.?));
    registry.ended = true;
    registry.releaseAll();
    registry.deinit();
    std.heap.c_allocator.destroy(registry);
}

/// `isolate`'s drain, after a walk's last resume (engine.resumeTeardowns).
pub fn drainOf(isolate: *ffi.Isolate) void {
    const registry = registryOf(isolate) orelse return;
    registry.drain();
}

/// A wrap `adopt` made, held strongly until `arm`.
pub const Adopted = struct {
    /// The slot's handle (`wrapperOf`), BORROWED.
    handle: *ffi.Object,
    cell: *anyopaque,
};

/// The wrap of `instance`, a node (WrapperCache.set): `box` - a fresh,
/// unarmed `Global<Object>` the binding made - moves into the node's slot,
/// which holds the wrapper from here, and the wrapper takes its reference.
/// The wrapper is held STRONGLY until `arm`, so that what the caller does
/// between - node tracing's edges, which may wrap ancestors and collect -
/// cannot take it. `box` is gone. On an error nothing was taken and `box` is
/// still the caller's.
pub fn adopt(isolate: *ffi.Isolate, instance: *runtime.Instance, box: *ffi.Object) error{ OutOfMemory, NoIsolateRecord, AgentEnded, NotANode, AlreadyWrapped }!Adopted {
    const registry = try ensureRegistry(isolate);
    if (registry.ended) return error.AgentEnded;
    const node = targetOf(instance) orelse return error.NotANode;
    const slot = runtime.lifetime.slotOf(node);
    if (!slot.isEmpty()) return error.AlreadyWrapped;
    const cell = try registry.allocCell();
    // The wrapper's reference, before anything can see the wrapper (design
    // 4.2 step 1): a node's first wrapper adopts its creator's.
    const target = runtime.lifetime.wrapperAcquired(instance) orelse {
        registry.freeCell(cell);
        return error.NotANode;
    };
    cell.word = @intFromPtr(target);
    ffi.v8_NodeWrapper_Adopt(box, @ptrCast(slot));
    return .{ .handle = @ptrCast(slot), .cell = cell };
}

/// The end of `adopt`: the wrapper is weak - only script, node tracing's
/// edges and the keeps hold it - unless the node has a keep.
pub fn arm(isolate: *ffi.Isolate, instance: *runtime.Instance, adopted: Adopted) void {
    const slot: *NodeWrapperSlot = @ptrCast(@alignCast(adopted.handle));
    if (slot.isEmpty()) return;
    const cell: *Cell = @ptrCast(@alignCast(adopted.cell));
    if (registryOf(isolate)) |registry| if (registry.liveKeep(instance)) |entry| {
        entry.cell = cell;
        holdKept(instance, slot, entry);
        return;
    };
    ffi.v8_NodeWrapper_SetWeak(@ptrCast(slot), cell);
}

/// A kept node's wrapper (`slot`, not empty) is held: strongly, or - in a
/// detached realm, which lives on only while script reaches anything of it
/// - by an edge from the realm's global object, weak otherwise
/// (WrapperCache.detach's rule for its entries).
fn holdKept(instance: *runtime.Instance, slot: *NodeWrapperSlot, kept: *Keep) void {
    const wrapper_cache = @import("wrapper_cache.zig");
    if (wrapper_cache.detachedHolderOf(instance)) |holder| {
        if (!kept.retained) {
            wrapper_cache.retainOnGlobal(holder, @ptrCast(slot));
            kept.retained = true;
        }
        if (kept.cell) |cell| ffi.v8_NodeWrapper_SetWeak(@ptrCast(slot), cell);
        return;
    }
    if (ffi.v8_NodeWrapper_ClearWeak(@ptrCast(slot))) |param| kept.cell = @ptrCast(@alignCast(param));
}

/// engine.keepPlatformObjectAlive for a node: one more counted keep. The
/// first holds the wrapper, if the node has one, and a wrap made while a
/// keep remains (`adopt`).
pub fn keep(instance: *runtime.Instance) void {
    const isolate = isolateOfInstance(instance) orelse return;
    const registry = ensureRegistry(isolate) catch return;
    const generation = runtime.SlabAllocator.generationOf(instance);
    registry.keeps_guard.beforeInsert(&registry.keeps);
    const gop = registry.keeps.getOrPut(std.heap.c_allocator, instance) catch return;
    if (!gop.found_existing or gop.value_ptr.generation != generation) gop.value_ptr.* = .{ .generation = generation };
    gop.value_ptr.count +|= 1;
    if (gop.value_ptr.count != 1) return;
    const slot = slotOfInstance(instance) orelse return;
    if (slot.isEmpty()) return;
    holdKept(instance, slot, gop.value_ptr);
}

/// engine.releasePlatformObject for a node: one keep ends; at the last the
/// wrapper is weak again. A release with no keep - never taken, or taken once
/// and released twice - changes nothing and is reported in Debug, as the
/// wrapper cache's `unmatchedRelease` does; one whose node was freed since
/// (its slot reissued) just goes.
pub fn release(instance: *runtime.Instance) void {
    const isolate = isolateOfInstance(instance) orelse return;
    const registry = registryOf(isolate) orelse return unmatchedRelease(instance);
    const entry = registry.keeps.getPtr(instance) orelse return unmatchedRelease(instance);
    if (entry.generation != runtime.SlabAllocator.generationOf(instance)) {
        if (registry.keeps.remove(instance)) registry.keeps_guard.noteRemoval(&registry.keeps);
        return;
    }
    if (entry.count == 0) return unmatchedRelease(instance);
    entry.count -= 1;
    if (entry.count != 0) return;
    const cell = entry.cell;
    const retained = entry.retained;
    if (registry.keeps.remove(instance)) registry.keeps_guard.noteRemoval(&registry.keeps);
    if (retained) return;
    const slot = slotOfInstance(instance) orelse return;
    if (slot.isEmpty()) return;
    if (cell) |c| ffi.v8_NodeWrapper_SetWeak(@ptrCast(slot), c);
}

fn unmatchedRelease(instance: *runtime.Instance) void {
    if (@import("builtin").mode == .debug) log.err("releasePlatformObject on a {s} with no keep left: an owner released a keep it did not take", .{instance.vtable.name});
}

/// A realm is detached (WrapperCache.detach, `holder` its global object):
/// each kept, wrapped node of it is kept by an edge from that global instead
/// of a strong Global, as the cache's own entries are.
pub fn detachRealm(cache_storage: *anyopaque, holder: *ffi.Value) void {
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return;
    const registry = registryOf(isolate) orelse return;
    // Collected first, then held: a retain allocates, and nothing below
    // may meet the table changing under its iterator.
    var kept: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer kept.deinit(std.heap.c_allocator);
    var it = registry.keeps.iterator();
    while (it.next()) |kv| {
        const instance = kv.key_ptr.*;
        if (kv.value_ptr.generation != runtime.SlabAllocator.generationOf(instance) or kv.value_ptr.count == 0 or kv.value_ptr.retained) continue;
        if (instance.ctx.getV8WrapperCacheStorage() != cache_storage) continue;
        kept.append(std.heap.c_allocator, instance) catch return;
    }
    for (kept.items) |instance| {
        const entry = registry.liveKeep(instance) orelse continue;
        const slot = slotOfInstance(instance) orelse continue;
        if (slot.isEmpty() or entry.retained) continue;
        @import("wrapper_cache.zig").retainOnGlobal(holder, @ptrCast(slot));
        entry.retained = true;
        if (entry.cell) |cell| ffi.v8_NodeWrapper_SetWeak(@ptrCast(slot), cell);
    }
}

/// engine.platformObjectDestroyed for a node: its teardown began (a forced
/// realm end's, or a tree's). A wrapper still in its slot is severed and
/// Reset - nothing in script reaches the node through it from here - its cell
/// freed and its reference released, while the node is still there (the
/// wrapper cache's markAsCleanedUp did the same for an entry).
pub fn nodeDestroyed(instance: *runtime.Instance) void {
    const target = targetOf(instance) orelse return;
    const slot = runtime.lifetime.slotOf(target);
    if (slot.isEmpty()) return;
    const isolate = isolateOfInstance(instance);
    const registry = if (isolate) |i| registryOf(i) else null;
    // The cell: the weak arm's parameter, or a kept wrapper's.
    var cell: ?*Cell = if (ffi.v8_NodeWrapper_ClearWeak(@ptrCast(slot))) |param| @ptrCast(@alignCast(param)) else null;
    if (cell == null) if (registry) |r| if (r.liveKeep(instance)) |entry| {
        cell = entry.cell;
    };
    ffi.v8_NodeWrapper_Reset(isolate, @ptrCast(slot), true);
    if (registry) |r| {
        if (r.keeps.getPtr(instance)) |entry| entry.cell = null;
        if (cell) |c| r.freeCell(c) else log.err("a node wrapper ended with no cell to free", .{});
    }
    if (instanceOfTarget(target)) |node_instance| runtime.instance_lifecycle.markWrapperGone(node_instance);
    runtime.lifetime.wrapperReleased(target);
}

/// A realm's end (WrapperCache.deinit, inside its coordinated teardown):
/// refcount step 7a's net for the realm's detached trees whose wrappers are
/// already gone - collected, their release still waiting for the drain - as
/// the wrapper cache's sweep made it for its pending entries: such a root is
/// freed whatever its counts (a holder that counts a node there forgets it,
/// its generation net). A tree a live wrapper still reaches is left: script
/// of another realm may hold it; when that wrapper goes, `endedRealmNet`
/// frees what only the ended realm's own pending work still holds.
/// Refcount step 7b removes the net.
pub fn endRealm(cache_storage: *anyopaque) void {
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return;
    const registry = registryOf(isolate) orelse return;
    const Root = struct { instance: *runtime.Instance, generation: u64 };
    var roots: std.ArrayListUnmanaged(Root) = .empty;
    defer roots.deinit(std.heap.c_allocator);
    // The realm's wrappers already collected whose release waits for the
    // drain (the agent's safe point after their collection has not come):
    // released now, and a detached root among them is the net's - the sweep
    // finalized such an entry itself ("wrappers already collected whose
    // finalizer has not run"), freeing a collected root nothing in a tree
    // held, whatever its counts. No wrapper reaches it any more.
    var at: usize = 0;
    while (at < registry.released.items.len) {
        const released = registry.released.items[at];
        const live = runtime.SlabAllocator.generationOf(released.instance) == released.generation and
            !runtime.instance_lifecycle.isCleanupStarted(released.instance);
        if (!live or released.instance.ctx.getV8WrapperCacheStorage() != cache_storage) {
            at += 1;
            continue;
        }
        _ = registry.released.swapRemove(at);
        const node: *@import("dom").NodeBase = @ptrCast(@alignCast(released.target));
        const root = node.parent_node == null and !node.rc_flags.hosted;
        releaseOne(registry, released);
        if (root and runtime.SlabAllocator.generationOf(released.instance) == released.generation and
            runtime.lifetime.slotOf(released.target).isEmpty())
            roots.append(std.heap.c_allocator, .{ .instance = released.instance, .generation = released.generation }) catch return;
    }
    // A live wrapper's tree is not freed here: script of another live realm
    // may hold it (a same-origin frame's node, kept by its parent), and the
    // net waits for that wrapper to go (`endedRealmNet`).
    for (roots.items) |root| {
        if (runtime.SlabAllocator.generationOf(root.instance) != root.generation) continue;
        if (runtime.instance_lifecycle.isCleanupStarted(root.instance)) continue;
        runtime.gc.onObjectFreed(root.instance);
    }
}

/// engine.releaseNodeWrappers: `isolate`'s agent will run no more script.
/// Every node wrapper ends (`Registry.releaseAll`), the keep table goes, and
/// no node is wrapped from here on. Idempotent.
pub fn releaseNodeWrappers(isolate: *ffi.Isolate) void {
    const registry = registryOf(isolate) orelse return;
    registry.ended = true;
    registry.releaseAll();
    registry.keeps.clearAndFree(std.heap.c_allocator);
    registry.keeps_guard.reset();
    // Its agent's record goes after this; the holds with it.
    registry.holds = null;
}

/// Live node wrappers of the current isolate's agent (diagnostics:
/// `node_wrappers`).
pub fn liveCount() usize {
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return 0;
    const registry = registryOf(isolate) orelse return 0;
    return registry.live;
}
