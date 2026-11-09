//! The V8 adapter's node wrappers (the wrapper redesign,
//! tmp/redesign/wrapper-redesign-design.md sections 3.3, 3.5, 4.1-4.5, 4.9
//! and 7's P2 and P4).
//!
//! A node's one wrapper per agent lives in the node itself: its
//! engine.NodeWrapperSlot (8 bytes of its NodeBase, reached only through
//! runtime.lifetime.slotOf) holds a `v8::TracedReference<v8::Object>` - Blink's
//! `ScriptWrappable::wrapper_` (a TraceWrapperV8Reference). The wrapper has no
//! internal field: it points at a NodeAnchor on its agent's C++ heap through
//! `v8::Object::Wrap` (v8_wrapper.cpp, "Node wrappers on the agent's C++
//! heap"), which holds the slot. The slot's ADDRESS is still the handle every
//! borrower of the node's wrapper gets (`wrapperOf`), read as P2's in-place
//! Global was. A node wrapper never enters the WrapperCache.
//!
//! - **Wrap** (`adopt`, from WrapperCache.set): the count first
//!   (runtime.lifetime.wrapperAcquired), then the anchor, the Wrap, the slot
//!   and the anchor registry (design 4.2). The binding's `box` holds the
//!   wrapper strongly until `arm` disposes it - or, while the node has a
//!   pending-activity keep, a root on its anchor holds it from `arm` on.
//! - **Unwrap**: `Object::Unwrap` under the node anchors' tag, the anchor's
//!   slot, the node (runtime.lifetime.targetOfSlot), its instance
//!   (`instanceOfSlot`; design 4.3).
//! - **Collection**: V8's marker keeps a reachable wrapper's anchor, whose
//!   Trace keeps its slot. In the atomic pause the anchor registry's weak
//!   processing hands each dead anchor's slot here (`collected`): the slot
//!   written empty (raw: V8 frees the TracedNode in the same pause), the
//!   release recorded - no V8 call, no count change, no free. After the
//!   collection, the drain releases the recorded references (a posted task,
//!   or a requested collection's end) - unless a walk holds the agent's
//!   teardowns (engine.deferTeardowns), whose last resume drains instead. A
//!   release only counts: a tree it leaves with no hold is queued by the
//!   counts (dom.refcount_teardown) - A COLLECTION NEVER FREES A NODE.
//! - **A realm's end** keeps refcount step 7a's net for the realm's detached
//!   trees, as the wrapper cache's sweep made it while node wrappers were its
//!   entries, once no wrapper reaches them (`endRealm`, `endedRealmNet`):
//!   their roots are freed whatever their counts, in a slice. A tree a live
//!   wrapper reaches - script of another realm may hold it - waits for that
//!   wrapper. Refcount step 7b removes the net.
//! - **A wrap between the collection and the drain** makes a new wrapper with
//!   its own reference; the drain releases the collected one's only (refcount
//!   design 2.1, "wrapped again between the passes").
//! - **Keeps** (engine.keepPlatformObjectAlive on a node: pending activity, a
//!   window's document): the agent's keep table, counted. While a keep
//!   remains the wrapper's anchor is a traced root (a cppgc::Persistent: its
//!   own slot only, design 7 P4); in a detached realm the wrapper is kept by
//!   an edge from the realm's global object instead (as WrapperCache.detach
//!   does for its entries).
//! - **The node's teardown under a live wrapper** (engine.
//!   platformObjectDestroyed: a forced realm end's coordinated teardown frees
//!   a tree whatever the counts say): the anchor lets go of the slot - the
//!   wrapper reaches no node from here - and the slot is Reset, the wrapper's
//!   reference released.
//! - **The agent's end** (engine.releaseNodeWrappers, which the host calls
//!   before its last drain and its sweeps, and destroyAgent): every live
//!   wrapper the same way, so the host's drain frees the trees only wrappers
//!   held and its sweeps meet no node an anchor points at (design 4.9; lane
//!   wr2's dated note there). The registry itself ends with the isolate
//!   (v8_wrapper.cpp v8_Isolate_Dispose).

const std = @import("std");
const runtime = @import("runtime");
const ffi = @import("ffi.zig");
const tombstones = @import("webidl").utils.tombstones;
const address_map = @import("infra").address_map;

const log = std.log.scoped(.node_wrappers);

/// engine.NodeWrapperSlot on V8: one `v8::TracedReference<v8::Object>`, whose
/// one word this is.
pub const NodeWrapperSlot = extern struct {
    /// The TracedReference's slot pointer (V8's `internal::Address*`, a
    /// TracedNode): null for a node with no wrapper in this agent. Written by
    /// V8 (v8_NodeWrapper_Attach, v8_NodeWrapper_End), and by `collected`
    /// alone in Zig - raw, in a collection's atomic pause, for a TracedNode V8
    /// frees itself there.
    handle: ?*anyopaque = null,

    pub const empty: NodeWrapperSlot = .{};

    pub fn isEmpty(self: *const NodeWrapperSlot) bool {
        return self.handle == null;
    }
};

/// The slot's wrapper as the `Global<Object>*` every borrower holds - the
/// slot's own address, read as a Global is (v8_wrapper.cpp: a TracedReference
/// and a Global are both one IndirectHandleBase word, and a borrower only
/// reads it) - BORROWED, or null for an empty slot. Valid while the node
/// lives and the slot is not emptied: take a reference of your own (a Local,
/// a clone) before anything that can collect. Never disposed, armed or
/// tagged.
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

/// The instance of the node whose wrapper slot `slot` is - a node wrapper's
/// unwrap after its anchor (design 4.3; the binding's node receivers,
/// v8_FunctionCallbackInfo_ThisNodeSlot).
pub fn instanceOfSlot(slot: *anyopaque) ?*runtime.Instance {
    return instanceOfTarget(runtime.lifetime.targetOfSlot(@ptrCast(@alignCast(slot))));
}

/// `instanceOfSlot` for v8_wrapper.cpp's generic unwraps (IsolateData::
/// node_wrapper_instance).
fn instanceOfSlotC(slot: ?*anyopaque) callconv(.c) ?*anyopaque {
    return instanceOfSlot(slot orelse return null);
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

/// A collected wrapper's reference, waiting for the drain: its counted
/// object, and the instance with the slab generation it had at the
/// collection - a forced teardown can free the node in between, and is then
/// recognised the way the wrapper cache's `releaseCounted` recognises one.
const Released = struct {
    target: *anyopaque,
    instance: *runtime.Instance,
    generation: u64,
};

/// The capacity `Registry.released` keeps after a drain empties it: P2 kept
/// its high-water mark (24 B times the most wrappers one collection found)
/// for the agent's life (design 7 P4, "From P2's measurements").
const released_floor = 64;

/// A node's pending-activity keeps (engine.keepPlatformObjectAlive), counted.
const Keep = struct {
    /// The instance's slab generation when the keep was taken: an entry left
    /// by a freed node at a reissued address is not the newcomer's.
    generation: u64,
    count: u32 = 0,
    /// The traced root holding the wrapper's anchor (v8_NodeWrapper_Root),
    /// OWNED, or null - no wrapper, or one kept by its detached realm.
    root: ?*anyopaque = null,
    /// Kept by an edge from its detached realm's global object instead.
    retained: bool = false,
};

/// One agent's node wrappers: the releases waiting for the drain, the keep
/// table, the count of live wrappers. OWNED by the isolate's record
/// (v8_wrapper.cpp IsolateData::node_wrappers), made on its first node wrap
/// or keep - with its anchors' registry on the agent's C++ heap; used on the
/// agent's thread only.
pub const Registry = struct {
    isolate: *ffi.Isolate,
    /// Wrappers whose anchor holds their slot now.
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
    /// Releases a collection could not record (no memory): references kept,
    /// so those trees are freed only at the agent's end. Diagnostics.
    lost_releases: u64 = 0,

    /// Release what the collections recorded - unless a walk holds the
    /// agent's teardowns: its last resume drains (`drainOf`).
    pub fn drain(self: *Registry) void {
        if (self.ended) return;
        if (self.holds) |holds| if (holds.count != 0) return;
        // One at a time, the next taken afresh: a release can run what wraps
        // and collects, whose weak processing appends here.
        while (self.released.pop()) |released| releaseOne(self, released);
        self.shrinkReleased();
    }

    /// The list a drain emptied keeps a small capacity, not its high water.
    fn shrinkReleased(self: *Registry) void {
        if (self.released.items.len != 0 or self.released.capacity <= released_floor) return;
        self.released.clearAndFree(std.heap.c_allocator);
        self.released.ensureTotalCapacityPrecise(std.heap.c_allocator, released_floor) catch {};
    }

    /// Every node wrapper's reference goes, its anchor's slot cleared and the
    /// slot emptied - the recorded releases first, and every keep's root
    /// (design 4.9 steps 2-3). No node is wrapped again (`ended`), so one
    /// pass ends every wrapper.
    fn releaseAll(self: *Registry) void {
        while (self.released.pop()) |released| releaseOne(self, released);
        var keeps = self.keeps.valueIterator();
        while (keeps.next()) |entry| {
            if (entry.root) |root| ffi.v8_NodeWrapper_Unroot(root);
            entry.root = null;
        }
        ffi.v8_NodeWrappers_EndAll(self.isolate, self, &endedCallback);
        while (self.released.pop()) |released| releaseOne(self, released);
        if (self.live != 0) log.err("{d} node wrapper(s) still live after the agent's end", .{self.live});
    }

    fn deinit(self: *Registry) void {
        self.released.deinit(std.heap.c_allocator);
        self.keeps.deinit(std.heap.c_allocator);
        self.* = undefined;
    }

    /// The live keep of `instance`, or null.
    fn liveKeep(self: *Registry, instance: *runtime.Instance) ?*Keep {
        const entry = self.keeps.getPtr(instance) orelse return null;
        if (entry.generation != runtime.SlabAllocator.generationOf(instance) or entry.count == 0) return null;
        return entry;
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

/// A live wrapper ended outside a collection (its slot emptied by the
/// caller): no wrapper reaches the node now, and the wrapper's reference
/// goes.
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

/// `isolate`'s registry, made (and handed to its record, with its anchors'
/// registry on the agent's C++ heap) on first use.
fn ensureRegistry(isolate: *ffi.Isolate) error{ OutOfMemory, NoIsolateRecord }!*Registry {
    if (registryOf(isolate)) |registry| return registry;
    const registry = try std.heap.c_allocator.create(Registry);
    errdefer std.heap.c_allocator.destroy(registry);
    registry.* = .{ .isolate = isolate, .holds = @import("protocol_agents.zig").teardownHoldsOf(isolate) };
    if (!ffi.v8_Isolate_SetNodeWrappers(isolate, registry, &collected, &drainCallback, &endCallback, &instanceOfSlotC)) return error.NoIsolateRecord;
    return registry;
}

/// A node wrapper's anchor was found dead in a collection's atomic pause
/// (v8_wrapper.cpp NodeWrapperRegistry::ProcessWeak): its slot is written
/// empty - raw, V8 frees the unmarked TracedNode itself in the same pause
/// (TracedHandles::ResetDeadNodes; a Reset would free it twice) - and the
/// release recorded. No V8 call, no count change, no free.
fn collected(raw_registry: ?*anyopaque, raw_slot: ?*anyopaque) callconv(.c) void {
    const registry: *Registry = @ptrCast(@alignCast(raw_registry.?));
    const slot: *NodeWrapperSlot = @ptrCast(@alignCast(raw_slot.?));
    const target = runtime.lifetime.targetOfSlot(slot);
    slot.* = .empty;
    registry.live -= 1;
    // The node is alive: its wrapper's reference holds it, and a teardown
    // under a live wrapper clears the anchor's slot first.
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
}

/// The agent's end told the registry a wrapper ended (v8_NodeWrappers_EndAll:
/// its anchor let go of the slot, which is Reset): its reference goes.
fn endedCallback(raw_registry: ?*anyopaque, raw_slot: ?*anyopaque) callconv(.c) void {
    const registry: *Registry = @ptrCast(@alignCast(raw_registry.?));
    const slot: *NodeWrapperSlot = @ptrCast(@alignCast(raw_slot.?));
    registry.live -= 1;
    endReference(registry, runtime.lifetime.targetOfSlot(slot));
}

/// The drain after a collection (v8_wrapper.cpp: a posted task, or a
/// requested collection's end).
fn drainCallback(raw_registry: ?*anyopaque) callconv(.c) void {
    const registry: *Registry = @ptrCast(@alignCast(raw_registry.?));
    registry.drain();
}

/// The registry's end, at the start of v8_Isolate_Dispose (the isolate and
/// its record still alive): whatever is still wrapped ends, then its memory.
/// The record unroots the anchors' registry after this.
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

/// A wrap `adopt` made, held strongly by the binding's box until `arm`.
pub const Adopted = struct {
    /// The slot's handle (`wrapperOf`), BORROWED.
    handle: *ffi.Object,
    /// The binding's fresh Global for the wrapper: the strong hold until
    /// `arm`, which disposes it.
    box: *ffi.Object,
};

/// The wrap of `instance`, a node (WrapperCache.set), design 4.2: the
/// wrapper's reference first (step 1), then - `box`'s object being the
/// wrapper, made from the interface's template with no internal field (step
/// 2) - its anchor, the Wrap, the node's slot and the anchor registry
/// (v8_NodeWrapper_Attach, steps 3-6). `box` keeps holding the wrapper
/// strongly until `arm`, so what the caller does between - node tracing's
/// edges, which may wrap ancestors and collect - cannot take it. On an error
/// nothing was taken and `box` is the caller's as before.
pub fn adopt(isolate: *ffi.Isolate, instance: *runtime.Instance, box: *ffi.Object) error{ OutOfMemory, NoIsolateRecord, AgentEnded, NotANode, AlreadyWrapped, NotAnApiObject }!Adopted {
    const registry = try ensureRegistry(isolate);
    if (registry.ended) return error.AgentEnded;
    const node = targetOf(instance) orelse return error.NotANode;
    const slot = runtime.lifetime.slotOf(node);
    if (!slot.isEmpty()) return error.AlreadyWrapped;
    // Object::Wrap points an API object at the anchor: one made from a
    // template, as the binding's are. Asked before the count is taken.
    if (!ffi.v8_NodeWrapper_Wrappable(isolate, box)) return error.NotAnApiObject;
    // 1. The wrapper's reference, before anything can see the wrapper: a
    //    node's first wrapper adopts its creator's.
    const target = runtime.lifetime.wrapperAcquired(instance) orelse return error.NotANode;
    std.debug.assert(target == node);
    // 3-6.
    ffi.v8_NodeWrapper_Attach(isolate, box, @ptrCast(slot));
    registry.live += 1;
    return .{ .handle = @ptrCast(slot), .box = box };
}

/// The end of `adopt`: a kept node's anchor becomes a traced root, then the
/// box's strong hold goes - from here only script, node tracing's edges and
/// the keeps hold the wrapper.
pub fn arm(isolate: *ffi.Isolate, instance: *runtime.Instance, adopted: Adopted) void {
    defer ffi.v8_Object_Dispose(adopted.box);
    const slot: *NodeWrapperSlot = @ptrCast(@alignCast(adopted.handle));
    if (slot.isEmpty()) return;
    if (registryOf(isolate)) |registry| if (registry.liveKeep(instance)) |entry| holdKept(isolate, instance, slot, entry);
}

/// A kept node's wrapper (`slot`, not empty) is held: its anchor a traced
/// root, or - in a detached realm, which lives on only while script reaches
/// anything of it - by an edge from the realm's global object
/// (WrapperCache.detach's rule for its entries).
fn holdKept(isolate: *ffi.Isolate, instance: *runtime.Instance, slot: *NodeWrapperSlot, kept: *Keep) void {
    const wrapper_cache = @import("wrapper_cache.zig");
    if (wrapper_cache.detachedHolderOf(instance)) |holder| {
        if (!kept.retained) {
            wrapper_cache.retainOnGlobal(holder, @ptrCast(slot));
            kept.retained = true;
        }
        if (kept.root) |root| ffi.v8_NodeWrapper_Unroot(root);
        kept.root = null;
        return;
    }
    if (kept.root == null) kept.root = ffi.v8_NodeWrapper_Root(isolate, @ptrCast(slot));
}

/// engine.keepPlatformObjectAlive for a node: one more counted keep. The
/// first holds the wrapper, if the node has one, and a wrap made while a
/// keep remains (`arm`).
pub fn keep(instance: *runtime.Instance) void {
    const isolate = isolateOfInstance(instance) orelse return;
    const registry = ensureRegistry(isolate) catch return;
    const generation = runtime.SlabAllocator.generationOf(instance);
    registry.keeps_guard.beforeInsert(&registry.keeps);
    const gop = registry.keeps.getOrPut(std.heap.c_allocator, instance) catch return;
    if (!gop.found_existing or gop.value_ptr.generation != generation) {
        // A keep a freed node left at a reissued address: its root goes.
        if (gop.found_existing) if (gop.value_ptr.root) |root| ffi.v8_NodeWrapper_Unroot(root);
        gop.value_ptr.* = .{ .generation = generation };
    }
    gop.value_ptr.count +|= 1;
    if (gop.value_ptr.count != 1) return;
    const slot = slotOfInstance(instance) orelse return;
    if (slot.isEmpty()) return;
    holdKept(isolate, instance, slot, gop.value_ptr);
}

/// engine.releasePlatformObject for a node: one keep ends; at the last its
/// root goes. A release with no keep - never taken, or taken once and
/// released twice - changes nothing and is reported in Debug, as the
/// wrapper cache's `unmatchedRelease` does; one whose node was freed since
/// (its slot reissued) just goes.
pub fn release(instance: *runtime.Instance) void {
    const isolate = isolateOfInstance(instance) orelse return;
    const registry = registryOf(isolate) orelse return unmatchedRelease(instance);
    const entry = registry.keeps.getPtr(instance) orelse return unmatchedRelease(instance);
    if (entry.generation != runtime.SlabAllocator.generationOf(instance)) {
        if (entry.root) |root| ffi.v8_NodeWrapper_Unroot(root);
        if (registry.keeps.remove(instance)) registry.keeps_guard.noteRemoval(&registry.keeps);
        return;
    }
    if (entry.count == 0) return unmatchedRelease(instance);
    entry.count -= 1;
    if (entry.count != 0) return;
    if (entry.root) |root| ffi.v8_NodeWrapper_Unroot(root);
    if (registry.keeps.remove(instance)) registry.keeps_guard.noteRemoval(&registry.keeps);
}

fn unmatchedRelease(instance: *runtime.Instance) void {
    if (@import("builtin").mode == .debug) log.err("releasePlatformObject on a {s} with no keep left: an owner released a keep it did not take", .{instance.vtable.name});
}

/// A realm is detached (WrapperCache.detach, `holder` its global object):
/// each kept, wrapped node of it is kept by an edge from that global instead
/// of a root on its anchor, as the cache's own entries are.
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
        if (entry.root) |root| ffi.v8_NodeWrapper_Unroot(root);
        entry.root = null;
    }
}

/// engine.platformObjectDestroyed for a node: its teardown began (a forced
/// realm end's, or a tree's). A wrapper still in its slot is severed - its
/// anchor lets go of the slot, so nothing in script reaches the node through
/// it from here - and the slot emptied, its keep's root dropped and its
/// reference released, while the node is still there (the wrapper cache's
/// markAsCleanedUp did the same for an entry).
pub fn nodeDestroyed(instance: *runtime.Instance) void {
    const target = targetOf(instance) orelse return;
    const slot = runtime.lifetime.slotOf(target);
    if (slot.isEmpty()) return;
    const isolate = isolateOfInstance(instance);
    const registry = if (isolate) |i| registryOf(i) else null;
    if (registry) |r| if (r.keeps.getPtr(instance)) |entry| {
        if (entry.root) |root| ffi.v8_NodeWrapper_Unroot(root);
        entry.root = null;
    };
    if (isolate == null) log.err("a node wrapper ended with no isolate to sever it in", .{});
    ffi.v8_NodeWrapper_End(isolate, @ptrCast(slot));
    if (registry) |r| r.live -= 1 else log.err("a node wrapper ended with no registry", .{});
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
    // drain (V8's second pass is a posted task for an ordinary collection):
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
