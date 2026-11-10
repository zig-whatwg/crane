//! Instance Bridge - Bidirectional conversion between runtime.Instance and NodeBase
//!
//! This module provides the bridge layer that allows WebIDL impls (using runtime.Instance)
//! to delegate tree operations to src/dom (using NodeBase).
//!
//! - NodeBase -> Instance: a field of the node (`NodeBase.ownerInstance`, its owner word).
//! - Instance -> NodeBase: the node's own state, read through the hook Node
//!   installs (`install`, `node_base_of`): Node keeps its NodeBase in its
//!   InternalState, which lives in the instance's own generated State
//!   (runtime.OwnState). No table and no lock: lane perf2, batch 2
//!   (tmp/plans/perf2b2-design.md) retired the per-Browser map, its mutex
//!   and its direct-mapped cache, which took 1-6% of the DOM rows it served
//!   (insert per node made, lookup per call, remove per node freed). Blink
//!   and WebKit hold the tree in the node object itself; so does Crane's
//!   NodeBase, and the instance reaches it through its own state.
//!
//! Usage:
//! ```zig
//! const bridge = @import("dom").instance_bridge;
//!
//! // In Node.zig impl:
//! fn insertNode(node: *runtime.Instance, parent: *runtime.Instance, child: ?*runtime.Instance) !void {
//!     const node_base = bridge.getNodeBase(node) orelse return error.InvalidStateError;
//!     const parent_base = bridge.getNodeBase(parent) orelse return error.InvalidStateError;
//!     const child_base = if (child) |c| bridge.getNodeBase(c) else null;
//!
//!     try dom.mutation.insert(node_base, parent_base, child_base, false);
//! }
//! ```
//!
//! lint-impls: hook for Node

const std = @import("std");
const NodeBase = @import("node_base.zig").NodeBase;
const refcount_audit = @import("refcount_audit.zig");
const runtime = @import("runtime");
const Hook = @import("hook.zig").Hook;

/// Placeholder type for the bridge context
/// This will be populated when Node.zig InternalState is updated
pub const BridgeContext = struct {
    /// The NodeBase embedded in InternalState
    node_base: *NodeBase,
    /// Back-pointer to the runtime.Instance
    instance: *anyopaque,
};

/// One Browser's bridge: its counts (a side table of its runtime.BrowserScope,
/// `.node_bases`, instances B1). The Instance -> NodeBase answer is the node's
/// own (`getNodeBase`); what is left here is counted.
///
/// The counts are atomic. They were made so when the V8 wrapper cache asked
/// `getNodeBase` about every platform object, a worker's included (lane
/// tsanfix1, `dead_slot_lookups` below). Since the wrapper redesign that is
/// no longer so: every adapter call is gated on `vtable.counted` first
/// (node_wrappers.zig `targetOf`, wrapper_cache.zig), and a worker reaches
/// no node through the adapter (the deep review's appendix-wr1 F10). A
/// caller on another thread that holds a stale instance still lands in
/// `dead_slot_lookups`, so the atomics stay.
pub const Bridge = struct {
    /// How many nodes are registered: made and not yet torn down
    /// (`entryCount`).
    live: std.atomic.Value(usize) = .init(0),
    /// How many `getNodeBase` calls asked about a slot that was freed: a
    /// caller that still holds a pointer to an instance gone from the slab.
    /// The slab is the Browser's, shared by its window thread and its
    /// workers', and its free list is LIFO, so such a read races the next
    /// allocation on any thread (lane tsanfix1, F2: a worker's wrapper cache
    /// read the slot of an instance it had just freed while the window thread
    /// reissued it). Single-threaded the read answers null and is invisible,
    /// so tests count it (`deadSlotLookups`).
    dead_slot_lookups: std.atomic.Value(usize) = .init(0),

    pub fn init(allocator: std.mem.Allocator) Bridge {
        _ = allocator;
        return .{};
    }

    pub fn deinit(self: *Bridge) void {
        self.* = undefined;
    }
};

/// What Node supplies: a node's NodeBase, from its own state.
pub const Implementation = struct {
    /// `instance`'s NodeBase, or null when it is no node or its NodeBase is
    /// gone (torn down). Reads only `instance`; no lock, no allocation.
    node_base_of: *const fn (instance: *runtime.Instance) ?*NodeBase,
};

var implementation: Hook(?Implementation) = .init(null);

/// Called by Node's installHooks, once, at process start.
pub fn install(impl: Implementation) void {
    implementation.install(impl);
}

/// The slab generation of `instance`'s slot: `dead_generation` once freed.
fn generationOf(instance: *anyopaque) u64 {
    return runtime.SlabAllocator.generationOf(@ptrCast(@alignCast(instance)));
}

/// The Browser of `instance` - a runtime.Instance - read from its address.
fn scopeOf(instance: *anyopaque) *runtime.BrowserScope {
    return runtime.BrowserScope.ofInstance(@ptrCast(@alignCast(instance)));
}

/// `instance`'s Browser's bridge, if it has one.
fn bridgeOf(instance: *anyopaque) ?*Bridge {
    return scopeOf(instance).existingTable(.node_bases, Bridge);
}

/// How many times `getNodeBase` was asked about a freed slot of `scope`'s
/// Browser (`Bridge.dead_slot_lookups`), for tests: every such call is a read
/// after the free.
pub fn deadSlotLookups(scope: *runtime.BrowserScope) usize {
    const bridge = scope.existingTable(.node_bases, Bridge) orelse return 0;
    return bridge.dead_slot_lookups.load(.monotonic);
}

/// How many nodes `scope`'s Browser has registered and not torn down.
///
/// Exposed for the memory benchmarks and the agent's end
/// (refcount_teardown.agentEnded): a count that rises with created-and-
/// discarded nodes is nodes nothing tears down.
pub fn entryCount(scope: *runtime.BrowserScope) usize {
    const bridge = scope.existingTable(.node_bases, Bridge) orelse return 0;
    return bridge.live.load(.monotonic);
}

/// Call `visit` with each registered node's NodeBase of `scope`'s Browser, at
/// most `limit` of them (diagnostics: refcount_teardown.agentEnded): a walk of
/// the Browser's slab, so only where no other thread makes or frees objects
/// (SlabAllocator.forEachLive). `visit` must not make objects.
pub fn visitNodes(scope: *runtime.BrowserScope, limit: usize, context: anytype, comptime visit: fn (@TypeOf(context), *NodeBase) void) void {
    const Walk = struct {
        context: @TypeOf(context),
        limit: usize,
        seen: usize = 0,
        fn each(self: *@This(), instance: *runtime.Instance) void {
            if (self.seen == self.limit) return;
            const node_base = getNodeBaseUnaudited(instance) orelse return;
            if (node_base.ownerInstance() == null) return;
            self.seen += 1;
            visit(self.context, node_base);
        }
    };
    var walk: Walk = .{ .context = context, .limit = limit };
    scope.slab.forEachLive(&walk, Walk.each);
}

/// Register a node: its NodeBase names its instance, and the Browser counts
/// it - its node count and its DOM memory.
///
/// Called once, by Node's initOwn, when both the Instance and its NodeBase
/// exist (the NodeBase is in Node's state from then on: `getNodeBase`).
pub fn register(instance: *anyopaque, node_base: *NodeBase) !void {
    const scope = scopeOf(instance);
    const bridge = try scope.table(.node_bases, Bridge);
    // An instance registered again is already counted.
    const fresh = node_base.ownerInstance() != @as(?*anyopaque, instance);
    node_base.setOwnerInstance(instance);
    // A node holder's walk asks it for what it holds (dom.wrapper_tracing).
    node_base.traces_held = @as(*runtime.Instance, @ptrCast(@alignCast(instance))).vtable.trace_held_nodes != null;
    if (!fresh) return;
    _ = bridge.live.fetchAdd(1, .monotonic);
    // The Browser's DOM grew by the node's storage, once per node: its window
    // agent's engine is told (runtime.gc.ExternalMemory).
    scope.dom_memory.add(storageBytes(@ptrCast(@alignCast(instance))));
}

/// The native storage a registered node holds for as long as it lives, as
/// its Browser's DOM memory counts it (runtime.BrowserScope.dom_memory),
/// added here at its registration and subtracted at its teardown: its slab
/// slot and its State block as the arena holds it (the block of its type's
/// state size) - which since lane perf2 batch 5 (Z7) IS the node: every
/// level's InternalState kept by value (runtime.OwnState) and the NodeBase in
/// Node's, counted once, here. The rest is counted where it is made and
/// freed (lane perf2 batch 4): an InternalState block an InstanceRegistry
/// makes for a node, at its arena class (runtime.own_state.nodeDomMemory),
/// and the NodeBase's rare data and registered observer entries
/// (NodeBase.domMemory) - so a node's total returns to 0 at its teardown.
/// What hangs off them (attribute values, text data, lists) is not counted.
/// Exact sizes, read from the allocators and the node's type.
pub fn storageBytes(instance: *const runtime.Instance) usize {
    return runtime.SlabAllocator.slot_bytes +
        runtime.ArenaAllocator.heldBytes(instance.vtable.state_size, instance.vtable.state_align);
}

/// Unregister a node being torn down: what `register` counted goes back, and
/// its NodeBase no longer names it.
///
/// Called by Node's teardown while its state still holds the NodeBase, just
/// before the NodeBase is freed.
pub fn unregister(instance: *anyopaque) void {
    const scope = scopeOf(instance);
    const bridge = scope.existingTable(.node_bases, Bridge) orelse return;
    const node_base = getNodeBaseUnaudited(instance) orelse return;
    if (node_base.ownerInstance() != @as(?*anyopaque, instance)) return;
    // Not strictly required - the field dies with the node - but clearing it
    // keeps a freed instance from being observable through a resurrected node.
    node_base.setOwnerInstance(null);
    _ = bridge.live.fetchSub(1, .monotonic);
    scope.dom_memory.sub(storageBytes(@ptrCast(@alignCast(instance))));
}

/// Get the NodeBase for a runtime.Instance
///
/// Returns null if the instance is no node, its NodeBase is gone, or its
/// slot was freed.
pub fn getNodeBase(instance: *anyopaque) ?*NodeBase {
    const found = getNodeBaseUnaudited(instance);
    // Refcount step 6: a read of a node step 7 would have freed is reported.
    if (refcount_audit.on()) if (found) |node_base| refcount_audit.checkRead(node_base, .get_node_base, @returnAddress());
    return found;
}

/// `getNodeBase` without the zombie audit's report: the reference counting's
/// own walks (dom.refcount, dom.refcount_audit).
pub fn getNodeBaseUnaudited(instance: *anyopaque) ?*NodeBase {
    // A freed slot's first word is the slab's free-list pointer, not a
    // vtable: answer null without reading it, and count the read.
    if (generationOf(instance) == runtime.SlabAllocator.dead_generation) {
        if (bridgeOf(instance)) |bridge| _ = bridge.dead_slot_lookups.fetchAdd(1, .monotonic);
        return null;
    }
    const impl = implementation.get() orelse return null;
    return impl.node_base_of(@ptrCast(@alignCast(instance)));
}

/// Get the runtime.Instance for a NodeBase
///
/// Returns null if the NodeBase is not from a registered runtime.Instance.
/// This is useful when src/dom needs to return nodes to WebIDL callers.
///
/// Example:
/// ```zig
/// // In a callback from src/dom:
/// fn onChildInserted(node_base: *NodeBase) void {
///     const instance = bridge.getInstance(node_base) orelse return;
///     // Now can call WebIDL interface methods on instance
/// }
/// ```
pub fn getInstance(node_base: *NodeBase) ?*anyopaque {
    // No map, no global state, no initialization order to get wrong: the owning
    // instance is a field of the node. Callers are unchanged.
    return node_base.ownerInstance();
}

/// Check if a NodeBase is from a registered runtime.Instance
pub fn isRuntimeInstance(node_base: *NodeBase) bool {
    return getInstance(node_base) != null;
}

/// Get the NodeBase for a runtime.Instance, typed
///
/// This is a convenience function that casts the opaque pointer.
/// Use when you have the concrete Instance type available.
pub fn getNodeBaseTyped(comptime T: type, instance: *T) ?*NodeBase {
    return getNodeBase(@ptrCast(instance));
}

/// Get the runtime.Instance for a NodeBase, typed
///
/// This is a convenience function that casts the opaque pointer.
/// Use when you know the concrete Instance type.
pub fn getInstanceTyped(comptime T: type, node_base: *NodeBase) ?*T {
    const ptr = getInstance(node_base) orelse return null;
    return @ptrCast(@alignCast(ptr));
}

// Tests: tests/dom/instance_bridge_test.zig.
