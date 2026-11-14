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
//!   release recorded - no V8 call, no count change, no free. A
//!   young-generation collection that drops an unmodified wrapper does the
//!   same from its roots handler (v8_wrapper.cpp NodeWrapperRootsHandler).
//!   After the collection, at the agent's safe point (v8_wrapper.cpp
//!   `runQueuedFinalizers`, never inside the collector: lane v8up's
//!   finalizer queue, which the releases join where the collection records
//!   them, as every other finalizer joins it in V8's first pass -
//!   `noteNodeWrappersCollected`), `drainCallback` releases
//!   the recorded references - unless a walk holds the agent's teardowns
//!   (engine.deferTeardowns), whose last resume drains instead. A release
//!   only counts: a tree it leaves with no hold is queued by the counts
//!   (dom.refcount_teardown) - A COLLECTION NEVER FREES A NODE.
//! - **A realm's end** keeps refcount step 7a's net for the realm's detached
//!   trees, as the wrapper cache's sweep made it while node wrappers were its
//!   entries, once no wrapper reaches them (`endRealm`, `endedRealmNet`):
//!   their roots are freed whatever their counts. A tree a live wrapper
//!   reaches - script of another realm may hold it - waits for that wrapper.
//!   The net looks at a tree when a wrapper of it is released, and a tree it
//!   declines then because the realm is ALIVE is remembered
//!   (`Registry.net_waiting`) and looked at again at that realm's end - so
//!   WHEN a collection's releases run no longer decides whether such a tree
//!   is ever freed (lane wr1 b11, "the 7a net's hole";
//!   tests/v8/wr11_net_hole_test.zig). Refcount step 7b removes the net.
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
//! - **The walk** (the redesign's P5, design 4.4): a reachable wrapper's
//!   anchor, in the collection's atomic pause, traces its own slot and then
//!   asks the host which wrappers its node keeps (runtime.lifetime.traceTree,
//!   dom.wrapper_tracing: its host-including tree's and its node document's)
//!   - `traceAnchor`, v8_wrapper.cpp NodeAnchor::Trace. The anchors'
//!   registry walks the kept nodes' trees the same way (`traceKeeps`). Since
//!   P7 the walk alone keeps trees: node tracing's JS edges are gone, and a
//!   wrapper no binding code changed is droppable in a scavenge (P8).
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

/// -Dv8-wrapper-trace-check: the walk's oracle runs in every major collection's
/// weak processing (`checkWalk`).
const wrapper_trace_check = @import("adapter_options").wrapper_trace_check;

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

/// The fewest declines between two sweeps of `Registry.net_waiting`.
const net_sweep_floor = 64;

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
    /// The walk's per-collection set of tree roots already walked
    /// (engine.traceVisitOnce): filled in a collection's atomic pause, emptied
    /// at the end of its marking (`markedCallback`), its capacity kept.
    visited: std.AutoHashMapUnmanaged(usize, void) = .empty,
    /// The key `visited` answered last - in front of its hash: every
    /// detached node of a document asks for that document's tree in turn
    /// (design R4c). Zero when `visited` is empty.
    last_visited: usize = 0,
    /// -Dv8-wrapper-trace-check: the slots the walk named in this collection.
    traced: std.AutoHashMapUnmanaged(usize, void) = .empty,
    /// No walk was installed for a trace this collection (a test's override
    /// removed it): the oracle has nothing to check then.
    walk_absent: bool = false,
    /// Anchors and keeps whose walk ran, cumulative (diagnostics, tests).
    walks: u64 = 0,
    /// Holder anchors whose holder's nodes were traced, cumulative
    /// (diagnostics, tests; the redesign's P6).
    holder_traces: u64 = 0,
    /// The oracle's findings, cumulative (-Dv8-wrapper-trace-check).
    trace_check_failures: u64 = 0,
    /// Debug: a walk is running (inside the collector): no wrap may start.
    in_walk: bool = false,
    /// Refcount step 7a's net, the roots it DECLINED because their realm was
    /// alive (`endedRealmNet`): root instance -> the slab generation it had.
    /// That realm's end looks at each again (`endRealm`). An entry is a
    /// reason to look, never a claim: every use checks the tree afresh, so
    /// one whose tree went by itself meanwhile (its pending work ended and
    /// the counts freed it), was inserted somewhere or is wrapped again is
    /// only stale. Stale entries are swept as the set grows (`netDeclined`):
    /// it holds at most twice the roots that still wait, plus
    /// `net_sweep_floor`.
    net_waiting: address_map.AddressHashMapUnmanaged(*runtime.Instance, u64) = .empty,
    /// Declines recorded since the last sweep of `net_waiting`.
    net_declines: usize = 0,
    /// The decline count that starts the next sweep.
    net_sweep_at: usize = net_sweep_floor,
    /// The root the net looked at last, with its generation - in front of
    /// `net_waiting`'s hash and the queue: a tree's wrappers die together and
    /// their releases reach the net one after another, each naming the same
    /// root. Null between drains.
    net_last: ?*runtime.Instance = null,
    net_last_generation: u64 = 0,

    /// Release what the collections recorded - unless a walk holds the
    /// agent's teardowns: its last resume drains (`drainOf`).
    pub fn drain(self: *Registry) void {
        if (self.ended) return;
        if (self.holds) |holds| if (holds.count != 0) return;
        // One at a time, the next taken afresh: a release can run what wraps
        // and collects, whose weak processing appends here.
        while (self.released.pop()) |released| releaseOne(self, released);
        self.net_last = null;
        self.shrinkReleased();
    }

    /// The net declined `root` because its realm is alive: that realm's end
    /// looks again. A root already noted is noted again at its generation
    /// now. Out of memory: the tree waits for the agent's end, as every such
    /// tree did before the set existed.
    fn netDeclined(self: *Registry, root: *runtime.Instance) void {
        self.net_waiting.put(std.heap.c_allocator, root, runtime.SlabAllocator.generationOf(root)) catch {
            self.lost_releases += 1;
            return;
        };
        self.net_declines += 1;
        if (self.net_declines < self.net_sweep_at) return;
        // The sweep: what still waits stays. Rebuilt, not removed from - a
        // map that only ever loses entries fills with tombstones.
        var kept: address_map.AddressHashMapUnmanaged(*runtime.Instance, u64) = .empty;
        var it = self.net_waiting.iterator();
        while (it.next()) |kv| {
            if (!netStillWaits(kv.key_ptr.*, kv.value_ptr.*)) continue;
            kept.put(std.heap.c_allocator, kv.key_ptr.*, kv.value_ptr.*) catch {
                // Keep the set as it is and look again at the next decline.
                kept.deinit(std.heap.c_allocator);
                return;
            };
        }
        self.net_waiting.deinit(std.heap.c_allocator);
        self.net_waiting = kept;
        self.net_declines = 0;
        self.net_sweep_at = @max(net_sweep_floor, kept.count());
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
        self.net_last = null;
        while (self.released.pop()) |released| releaseOne(self, released);
        var keeps = self.keeps.valueIterator();
        while (keeps.next()) |entry| {
            if (entry.root) |root| ffi.v8_NodeWrapper_Unroot(root);
            entry.root = null;
        }
        ffi.v8_NodeWrappers_EndAll(self.isolate, self, &endedCallback);
        while (self.released.pop()) |released| releaseOne(self, released);
        self.net_last = null;
        if (self.live != 0) log.err("{d} node wrapper(s) still live after the agent's end", .{self.live});
    }

    fn deinit(self: *Registry) void {
        self.released.deinit(std.heap.c_allocator);
        self.net_waiting.deinit(std.heap.c_allocator);
        self.keeps.deinit(std.heap.c_allocator);
        self.visited.deinit(std.heap.c_allocator);
        self.traced.deinit(std.heap.c_allocator);
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
///
/// Called for every wrapper released, so it answers from the root's own
/// fields first - whether a wrapper reaches a node BELOW the root is asked
/// where a tree is about to be freed (`runNetRoot`, `endRealm`: `netMayFree`),
/// once a tree, not here once a wrapper. A tree whose realm is still ALIVE
/// is declined - its pending work may end by itself, and the counts free it
/// then - and remembered, for that realm's end to look again
/// (`Registry.netDeclined`): until lane wr1 b11 nothing did, and such a tree
/// stayed to the agent's end.
fn endedRealmNet(registry: *Registry, target: *anyopaque) void {
    const dom = @import("dom");
    var root: *dom.NodeBase = @ptrCast(@alignCast(target));
    // Its HOST-INCLUDING root, the unit the counts and the walk keep
    // (dom.refcount, dom.wrapper_tracing): a wrapper released inside a shadow
    // tree or a template's contents answers for its host's tree. While a
    // wrap still wrapped every ancestor (until P7) the host's own wrapper
    // outlived it and its release asked instead.
    while (dom.refcount.hostIncludingParent(root)) |parent| root = parent;
    if (root.rc_flags.hosted or root.rc_flags.garbage or root.subtree_holds == 0) return;
    if (!runtime.lifetime.slotOf(root).isEmpty()) return;
    if (root.node_type == dom.NodeBase.DOCUMENT_NODE) return;
    const instance = instanceOfTarget(root) orelse return;
    const generation = runtime.SlabAllocator.generationOf(instance);
    if (registry.net_last == instance and registry.net_last_generation == generation) return;
    registry.net_last = instance;
    registry.net_last_generation = generation;
    if (instance.ctx.hasEngine()) return registry.netDeclined(instance);
    const queue = @import("protocol_agents.zig").deferredTeardownOf(registry.isolate) orelse return;
    _ = queue.push(.{
        .instance = instance,
        .generation = generation,
        .owner = null,
        .steps = &net_root_steps,
    });
}

/// Whether the net may free the tree of `instance`, a root it looked at
/// when it had `generation`: still that node, its teardown not begun, still
/// a detached root that is no shadow root or template contents (those are
/// their host's), and reached by NO wrapper. Since the redesign's P7 a
/// wrapped node wraps no ancestor, so the root's own empty slot does not
/// answer for its tree: dom.wrapper_tracing.holdsWrapper walks its held part
/// (script of a live realm may hold a child of a detached root, and the node
/// behind that wrapper must stay whole). Reads nothing of a node whose slab
/// generation moved.
fn netMayFree(instance: *runtime.Instance, generation: u64) bool {
    const dom = @import("dom");
    if (runtime.SlabAllocator.generationOf(instance) != generation) return false;
    if (runtime.instance_lifecycle.isCleanupStarted(instance)) return false;
    const node: *dom.NodeBase = @ptrCast(@alignCast(targetOf(instance) orelse return false));
    if (node.parent_node != null or node.rc_flags.hosted) return false;
    return !dom.wrapper_tracing.holdsWrapper(node);
}

/// Whether `instance`, a root the net declined at `generation`, still waits
/// for its realm's end: still that node, a detached root something holds,
/// not queued by the counts, of a realm whose end is still to come (its
/// wrapper cache is there: `endRealm` runs inside that cache's end, and a
/// realm the collector took has no engine context from the collection on).
/// A wrapper reaching it again is not asked here - the realm's end asks,
/// `netMayFree`.
fn netStillWaits(instance: *runtime.Instance, generation: u64) bool {
    const dom = @import("dom");
    if (runtime.SlabAllocator.generationOf(instance) != generation) return false;
    if (runtime.instance_lifecycle.isCleanupStarted(instance)) return false;
    const node: *dom.NodeBase = @ptrCast(@alignCast(targetOf(instance) orelse return false));
    if (node.parent_node != null or node.rc_flags.hosted or node.rc_flags.garbage or node.subtree_holds == 0) return false;
    return instance.ctx.getV8WrapperCacheStorage() != null;
}

const net_root_steps: runtime.gc.DeferredTeardown.Steps = .{ .run = runNetRoot };

/// A slice of the ended-realm net (`endedRealmNet`): the root's own teardown
/// frees its tree - once it is still that detached root, of a realm that
/// ended, and no wrapper reaches its tree (`netMayFree`).
fn runNetRoot(item: *runtime.gc.DeferredTeardown.Item, budget: usize) runtime.gc.DeferredTeardown.Progress {
    _ = budget;
    const done: runtime.gc.DeferredTeardown.Progress = .{ .freed = 0, .done = true };
    const instance = item.instance;
    if (!netMayFree(instance, item.generation)) return done;
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
    _ = ffi.v8_Isolate_SetNodeWrapperTracing(isolate, &traceAnchor, &traceKeeps, &markedCallback, if (wrapper_trace_check) &checkWalk else null, &traceHolder);
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

/// The agent's safe point after a collection (v8_wrapper.cpp
/// `runQueuedFinalizers` -> `drainNodeWrappers`): the agent's drain.
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
/// strongly until `arm`, so what the caller does between - the edges traced
/// from the node before script saw it, which allocate - cannot take it. On an
/// error
/// nothing was taken and `box` is the caller's as before.
pub fn adopt(isolate: *ffi.Isolate, instance: *runtime.Instance, box: *ffi.Object) error{ OutOfMemory, NoIsolateRecord, AgentEnded, NotANode, AlreadyWrapped, NotAnApiObject }!Adopted {
    const registry = try ensureRegistry(isolate);
    if (registry.ended) return error.AgentEnded;
    // The walk runs inside the collector and makes nothing (design 4.4).
    std.debug.assert(!registry.in_walk);
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
/// box's strong hold goes - from here only script, the walk and the keeps
/// hold the wrapper.
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
/// refcount step 7a's net for the realm's detached trees no wrapper reaches
/// any more, as the wrapper cache's sweep made it for its pending entries:
/// such a root is freed whatever its counts (a holder that counts a node
/// there forgets it, its generation net). Two kinds:
/// - a root whose own wrapper was collected and whose release still waited
///   for the drain: released here, and freed ("wrappers already collected
///   whose finalizer has not run");
/// - a root the net declined earlier because this realm was alive
///   (`endedRealmNet`, `Registry.net_waiting`) - the releases just run
///   among them - and that something still holds: the realm's own pending
///   work, which will never end by itself now.
/// A tree a live wrapper still reaches is left (`netMayFree`): script of
/// another realm may hold it; when that wrapper goes, `endedRealmNet` frees
/// what only the ended realm's work still holds. Refcount step 7b removes
/// the net.
pub fn endRealm(cache_storage: *anyopaque) void {
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return;
    const registry = registryOf(isolate) orelse return;
    const Root = struct { instance: *runtime.Instance, generation: u64 };
    var roots: std.ArrayListUnmanaged(Root) = .empty;
    defer roots.deinit(std.heap.c_allocator);
    // The realm's wrappers already collected whose release waits for the
    // drain: released now, and a detached root among them is the net's - the
    // sweep finalized such an entry itself, freeing a collected root
    // whatever its counts.
    registry.net_last = null;
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
    registry.net_last = null;
    // The roots the net declined while this realm lived, and this realm's
    // entries leave the set: a tree left below (a wrapper reaches it) is the
    // net's again when that wrapper's release finds its realm ended.
    var kept: address_map.AddressHashMapUnmanaged(*runtime.Instance, u64) = .empty;
    var waiting = registry.net_waiting.iterator();
    var rebuilt = true;
    while (waiting.next()) |kv| {
        const instance = kv.key_ptr.*;
        const generation = kv.value_ptr.*;
        if (!netStillWaits(instance, generation)) continue;
        if (instance.ctx.getV8WrapperCacheStorage() != cache_storage) {
            kept.put(std.heap.c_allocator, instance, generation) catch {
                rebuilt = false;
                break;
            };
            continue;
        }
        roots.append(std.heap.c_allocator, .{ .instance = instance, .generation = generation }) catch {
            rebuilt = false;
            break;
        };
    }
    if (rebuilt) {
        registry.net_waiting.deinit(std.heap.c_allocator);
        registry.net_waiting = kept;
        registry.net_declines = 0;
        registry.net_sweep_at = @max(net_sweep_floor, kept.count());
    } else {
        // No memory to rebuild: the set stays as it is - its entries of this
        // realm go stale with the realm - and what was gathered is still
        // looked at.
        kept.deinit(std.heap.c_allocator);
    }
    // A live wrapper's tree is not freed here: script of another live realm
    // may hold it (a same-origin frame's node, kept by its parent), and the
    // net waits for that wrapper to go (`endedRealmNet`).
    for (roots.items) |root| {
        if (!netMayFree(root.instance, root.generation)) continue;
        runtime.gc.onObjectFreed(root.instance);
    }
}

/// The roots the current agent's net remembers (`Registry.net_waiting`),
/// stale entries included: the adapter's `node_wrapper_net_waiting` counter.
pub fn netWaitingOfCurrent() usize {
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return 0;
    const registry = registryOf(isolate) orelse return 0;
    return registry.net_waiting.count();
}

// ============================================================================
// The walk (the wrapper redesign's P5, design 3.3 and 4.4)
// ============================================================================

/// engine.Tracer on V8: the cppgc visitor of the collection's atomic pause
/// that reached a node anchor (or the anchors' registry, for the keeps), and
/// the agent's registry, whose `visited` set dedupes the walk. Made on the
/// stack of `traceAnchor` / `traceKeeps` for one walk; never stored.
pub const Tracer = struct {
    /// The cppgc::Visitor, BORROWED for the Trace call.
    visitor: *anyopaque,
    registry: *Registry,
};

/// engine.traceNodeWrapper: the slot's wrapper is kept - its TracedReference
/// traced through the collection's visitor (v8_NodeTracer_TraceSlot), which
/// marks the TracedNode and the wrapper and, through it, its anchor.
pub fn traceNodeWrapper(tracer: *Tracer, slot: *const NodeWrapperSlot) void {
    if (slot.isEmpty()) return;
    if (wrapper_trace_check) tracer.registry.traced.put(std.heap.c_allocator, @intFromPtr(slot), {}) catch {};
    ffi.v8_NodeTracer_TraceSlot(tracer.visitor, @ptrCast(@constCast(slot)));
}

/// engine.traceVisitOnce: true the first time `key` is offered in this
/// collection. Malloc in the pause (never the V8 or C++ heap); with no
/// memory, true - the tree is walked again, which costs time, never a
/// wrapper.
pub fn traceVisitOnce(tracer: *Tracer, key: *const anyopaque) bool {
    const registry = tracer.registry;
    if (registry.last_visited == @intFromPtr(key)) return false;
    const entry = registry.visited.getOrPut(std.heap.c_allocator, @intFromPtr(key)) catch return true;
    registry.last_visited = @intFromPtr(key);
    return !entry.found_existing;
}

/// NodeAnchor::Trace's step 2 (v8_wrapper.cpp; design 4.4): the anchor of
/// the node slot `raw_slot` was reached in a collection's atomic pause, and
/// its own slot traced; every wrapper its node keeps is traced through
/// `visitor` - the walk (runtime.lifetime.traceTree). The registry is the
/// collecting isolate's: the anchor holds only its slot (16 bytes, design
/// 4.1), so the C++ side finds the record as the current isolate's, which
/// it checks is the one collecting (collectingRecord; the integrator,
/// 2026-11-09 16:45).
fn traceAnchor(raw_registry: ?*anyopaque, raw_slot: ?*anyopaque, visitor: ?*anyopaque) callconv(.c) void {
    const registry: *Registry = @ptrCast(@alignCast(raw_registry orelse return));
    const slot: *NodeWrapperSlot = @ptrCast(@alignCast(raw_slot orelse return));
    var tracer: Tracer = .{ .visitor = visitor orelse return, .registry = registry };
    walk(registry, runtime.lifetime.targetOfSlot(slot), &tracer);
}

/// One walk from `target`, the registry's diagnostics around it.
fn walk(registry: *Registry, target: *anyopaque, tracer: *Tracer) void {
    registry.in_walk = true;
    defer registry.in_walk = false;
    if (runtime.lifetime.traceTree(target, tracer)) registry.walks += 1 else registry.walk_absent = true;
}

/// HolderAnchor::Trace's work (v8_wrapper.cpp; the redesign's P6, design
/// 4.4 "Holders", rule 3.2 (d)): a holder wrapper was reached in a
/// collection's atomic pause; the nodes its instance holds for script are
/// traced through `visitor` - its type's VTable.trace_held_nodes, which
/// asks the walk for each (dom.wrapper_tracing.traceHeld). An instance
/// whose slot was freed or reissued since its anchor was made (the anchor's
/// generation) is not read: the anchor's wrapper outlived it.
fn traceHolder(raw_registry: ?*anyopaque, raw_instance: ?*anyopaque, generation: u64, visitor: ?*anyopaque) callconv(.c) void {
    const registry: *Registry = @ptrCast(@alignCast(raw_registry orelse return));
    const instance: *runtime.Instance = @ptrCast(@alignCast(raw_instance orelse return));
    if (runtime.SlabAllocator.generationOf(instance) != generation) return;
    if (runtime.instance_lifecycle.isCleanupStarted(instance)) return;
    // A test that removed the walk removed the holders' walks with it.
    if (!runtime.lifetime.walkInstalled()) return;
    const trace = instance.vtable.trace_held_nodes orelse return;
    var tracer: Tracer = .{ .visitor = visitor orelse return, .registry = registry };
    registry.in_walk = true;
    defer registry.in_walk = false;
    trace(instance, &tracer);
    registry.holder_traces += 1;
}

/// A holder's wrapper `box` was made (WrapperCache.set, for a type with
/// VTable.trace_held_nodes): its HolderAnchor, so a collection that keeps
/// the wrapper traces what the holder holds (the redesign's P6). The agent's
/// registry is made first if this is its first wrap: the anchor's Trace
/// reaches the walk's per-collection set through it.
pub fn attachHolder(isolate: *ffi.Isolate, instance: *runtime.Instance, box: *ffi.Object) void {
    _ = ensureRegistry(isolate) catch return;
    _ = ffi.v8_HolderAnchor_Attach(isolate, box, instance, runtime.SlabAllocator.generationOf(instance));
}

/// The holder's instance goes while its wrapper may live on (a realm's end
/// severing it, WrapperCache's `severWrapper`): its anchor traces nothing.
pub fn clearHolder(box: *ffi.Object) void {
    ffi.v8_HolderAnchor_Clear(box);
}

/// The kept nodes' trees (design 4.4 "Kept nodes", rule 3.2 c), from the
/// anchors' registry's Trace in the atomic pause: every node with a live
/// keep (pending activity) keeps its tree's wrappers, wrapped or not itself
/// - Blink's ActiveScriptWrappableManager traces each active
/// ScriptWrappable. A keep of a realm that is detached or ended keeps
/// nothing (Blink: ScriptWrappableIsActive answers false once its context
/// is destroyed, active_script_wrappable_manager.cc) - its wrapper, if any,
/// is held by an edge from its realm's global object (`holdKept`).
fn traceKeeps(raw_registry: ?*anyopaque, visitor: ?*anyopaque) callconv(.c) void {
    const registry: *Registry = @ptrCast(@alignCast(raw_registry orelse return));
    if (registry.ended) return;
    var tracer: Tracer = .{ .visitor = visitor orelse return, .registry = registry };
    var entries = registry.keeps.iterator();
    while (entries.next()) |kv| {
        const instance = kv.key_ptr.*;
        const kept = kv.value_ptr;
        if (kept.count == 0 or kept.retained) continue;
        if (kept.generation != runtime.SlabAllocator.generationOf(instance)) continue;
        if (runtime.instance_lifecycle.isCleanupStarted(instance)) continue;
        if (!instance.ctx.hasEngine()) continue;
        if (@import("wrapper_cache.zig").detachedHolderOf(instance) != null) continue;
        const target = targetOf(instance) orelse continue;
        walk(registry, target, &tracer);
    }
}

/// The end of a collection's marking (the anchors' registry's weak
/// processing, every major GC): the walk's sets of this collection go,
/// their capacity kept (a quarter used or less above 4,096 entries gives the
/// rest back).
fn markedCallback(raw_registry: ?*anyopaque) callconv(.c) void {
    const registry: *Registry = @ptrCast(@alignCast(raw_registry orelse return));
    endSet(&registry.visited);
    registry.last_visited = 0;
    endSet(&registry.traced);
    registry.walk_absent = false;
}

fn endSet(set: *std.AutoHashMapUnmanaged(usize, void)) void {
    if (set.capacity() > 4096 and set.count() * 4 < set.capacity()) {
        set.clearAndFree(std.heap.c_allocator);
    } else set.clearRetainingCapacity();
}

/// The walk's oracle (-Dv8-wrapper-trace-check; design 7 P5, R2-R3), in every
/// major collection's weak processing before any slot is emptied: `live`
/// are the slots of the anchors the collection kept, `dead` of those it did
/// not. It checks, logging each finding (an error log fails a unit test):
/// 1. every kept anchor's node was reached by the walk itself, not only by
///    its anchor's own slot - a pruning or a dedupe mistake shows here even
///    while the JS edges keep the wrapper (a lone root's walk names nothing:
///    its anchor's own slot is the whole of it);
/// 2. walked UNPRUNED, no tree a kept anchor's node or a live keep keeps
///    holds a wrapper the collection is dropping - what the browsers keep;
/// 3. no dropped anchor's node is in a tree the walk visited.
fn checkWalk(raw_registry: ?*anyopaque, raw_live: ?[*]const ?*anyopaque, live_len: usize, raw_dead: ?[*]const ?*anyopaque, dead_len: usize) callconv(.c) void {
    const live: []const ?*anyopaque = if (raw_live) |l| l[0..live_len] else &.{};
    const dead: []const ?*anyopaque = if (raw_dead) |d| d[0..dead_len] else &.{};
    const registry: *Registry = @ptrCast(@alignCast(raw_registry orelse return));
    // A test's override removed the walk: nothing it should have kept.
    if (registry.walk_absent or runtime.lifetime.installedHooks().trace_tree == null) return;
    const dom = @import("dom");
    const gpa = std.heap.c_allocator;
    var dropped: std.AutoHashMapUnmanaged(usize, void) = .empty;
    defer dropped.deinit(gpa);
    for (dead) |slot| if (slot) |s| dropped.put(gpa, @intFromPtr(s), {}) catch return;
    var walked: std.AutoHashMapUnmanaged(usize, void) = .empty;
    defer walked.deinit(gpa);
    const Check = struct {
        registry: *Registry,
        dropped: *const std.AutoHashMapUnmanaged(usize, void),

        fn wrapped(self: @This(), slot: *NodeWrapperSlot) void {
            if (!self.dropped.contains(@intFromPtr(slot))) return;
            self.registry.trace_check_failures += 1;
            log.err("wrapper-trace-check: a wrapper in a tree a kept wrapper keeps was collected (node type {d})", .{nodeTypeOfSlot(slot)});
        }
    };
    const check: Check = .{ .registry = registry, .dropped = &dropped };
    for (live) |maybe_slot| {
        const slot: *NodeWrapperSlot = @ptrCast(@alignCast(maybe_slot orelse continue));
        const node: *dom.NodeBase = @ptrCast(@alignCast(runtime.lifetime.targetOfSlot(slot)));
        // 1. (A lone root is not walked: its anchor's own slot is all.)
        const lone_self = dom.refcount.root(null, node) == node and dom.wrapper_tracing.isLone(node);
        if (!lone_self and !registry.traced.contains(@intFromPtr(slot))) {
            registry.trace_check_failures += 1;
            log.err("wrapper-trace-check: a kept node wrapper's node was not reached by the walk (node type {d})", .{nodeTypeOfSlot(slot)});
        }
        // 2.
        for (dom.wrapper_tracing.treeRoots(node)) |maybe_root| {
            const tree_root = maybe_root orelse continue;
            const entry = walked.getOrPut(gpa, @intFromPtr(tree_root)) catch return;
            if (entry.found_existing) continue;
            dom.wrapper_tracing.forEachWrapped(tree_root, check, Check.wrapped);
        }
    }
    var entries = registry.keeps.iterator();
    while (entries.next()) |kv| {
        const instance = kv.key_ptr.*;
        const kept = kv.value_ptr;
        if (kept.count == 0 or kept.retained or kept.generation != runtime.SlabAllocator.generationOf(instance)) continue;
        if (runtime.instance_lifecycle.isCleanupStarted(instance) or !instance.ctx.hasEngine()) continue;
        if (@import("wrapper_cache.zig").detachedHolderOf(instance) != null) continue;
        const node: *dom.NodeBase = @ptrCast(@alignCast(targetOf(instance) orelse continue));
        for (dom.wrapper_tracing.treeRoots(node)) |maybe_root| {
            const tree_root = maybe_root orelse continue;
            const entry = walked.getOrPut(gpa, @intFromPtr(tree_root)) catch return;
            if (entry.found_existing) continue;
            dom.wrapper_tracing.forEachWrapped(tree_root, check, Check.wrapped);
        }
    }
    // 3.
    for (dead) |maybe_slot| {
        const slot: *NodeWrapperSlot = @ptrCast(@alignCast(maybe_slot orelse continue));
        const node: *dom.NodeBase = @ptrCast(@alignCast(runtime.lifetime.targetOfSlot(slot)));
        const tree_root = dom.refcount.root(null, node);
        if (!registry.visited.contains(@intFromPtr(tree_root))) continue;
        registry.trace_check_failures += 1;
        log.err("wrapper-trace-check: the walk visited a tree whose wrapper the collection dropped (node type {d})", .{node.node_type});
    }
}

fn nodeTypeOfSlot(slot: *NodeWrapperSlot) u16 {
    const node: *@import("dom").NodeBase = @ptrCast(@alignCast(runtime.lifetime.targetOfSlot(slot)));
    return node.node_type;
}

/// The current isolate's walks so far (anchors and keeps), its holder
/// anchors' traces and the oracle's findings (diagnosticCounters'
/// `node_wrapper_walks`, `node_wrapper_holder_traces` and
/// `wrapper_trace_check_failures`).
pub fn walkCountsOfCurrent() struct { walks: u64, holder_traces: u64, check_failures: u64 } {
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return .{ .walks = 0, .holder_traces = 0, .check_failures = 0 };
    const registry = registryOf(isolate) orelse return .{ .walks = 0, .holder_traces = 0, .check_failures = 0 };
    return .{ .walks = registry.walks, .holder_traces = registry.holder_traces, .check_failures = registry.trace_check_failures };
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
