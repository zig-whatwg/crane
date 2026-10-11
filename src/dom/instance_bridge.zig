//! Instance Bridge - Bidirectional conversion between runtime.Instance and NodeBase
//!
//! This module provides the bridge layer that allows WebIDL impls (using runtime.Instance)
//! to delegate tree operations to src/dom (using NodeBase).
//!
//! Design Decision: Option D - NodeBase embedding
//! - NodeBase is stored inside InternalState, making it the source of truth for tree structure
//! - Bidirectional conversion: Instance <-> NodeBase in O(1)
//! - Compatible with existing src/dom algorithms and XPath/selectors
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

const std = @import("std");
const NodeBase = @import("node_base.zig").NodeBase;
const runtime = @import("runtime");
const tombstones = @import("webidl").utils.tombstones;

/// Placeholder type for the bridge context
/// This will be populated when Node.zig InternalState is updated
pub const BridgeContext = struct {
    /// The NodeBase embedded in InternalState
    node_base: *NodeBase,
    /// Back-pointer to the runtime.Instance
    instance: *anyopaque,
};

/// One Browser's map from runtime.Instance pointers to their NodeBase: a side
/// table of its runtime.BrowserScope (`.node_bases`, instances B1), so a
/// Browser's nodes are its own and their entries end with it.
///
/// Nodes are a window's, but the map is READ for every platform object of
/// every thread of the Browser: the wrapper cache and the template registry
/// ask it whether an object is a node (wrapper_cache.zig,
/// template_registry.zig), and a worker's objects live on the worker's own
/// thread (docs/instances.md). So every access takes `mutex`.
pub const Bridge = struct {
    /// Protects `map` and `guard`; held for one map operation, never across
    /// a call out of this file.
    mutex: std.Io.Mutex = .init,
    map: std.AutoHashMap(*anyopaque, *NodeBase),
    /// Every node a page makes enters this map and leaves it when the page
    /// ends; the guard rehashes before an insert once the tombstones those
    /// removals leave could take half the free slots
    /// (webidl.utils.tombstones).
    guard: tombstones.TombstoneGuard = .{},

    pub fn init(allocator: std.mem.Allocator) Bridge {
        return .{ .map = std.AutoHashMap(*anyopaque, *NodeBase).init(allocator) };
    }

    pub fn deinit(self: *Bridge) void {
        self.map.deinit();
    }

    fn lock(self: *Bridge) void {
        std.Io.Threaded.mutexLock(&self.mutex);
    }

    fn unlock(self: *Bridge) void {
        std.Io.Threaded.mutexUnlock(&self.mutex);
    }
};

/// The Browser of `instance` - a runtime.Instance - read from its address.
fn scopeOf(instance: *anyopaque) *runtime.BrowserScope {
    return runtime.BrowserScope.ofInstance(@ptrCast(@alignCast(instance)));
}

/// `instance`'s Browser's bridge, if it has one.
fn bridgeOf(instance: *anyopaque) ?*Bridge {
    return scopeOf(instance).existingTable(.node_bases, Bridge);
}

/// How many (instance -> NodeBase) entries `scope`'s Browser has.
///
/// Exposed for the Phase 6 memory benchmark. This map is keyed on the instance
/// ADDRESS and the slab recycles addresses, so an entry that outlives its instance
/// is not merely a leak - it is silently inherited by the next object at that
/// address. A count that rises with created-and-discarded nodes is the symptom.
pub fn entryCount(scope: *runtime.BrowserScope) usize {
    const bridge = scope.existingTable(.node_bases, Bridge) orelse return 0;
    bridge.lock();
    defer bridge.unlock();
    return bridge.map.count();
}

/// The table's slots by state (free, live, capacity), for the churn test and
/// measurements: every node a page makes enters and leaves this map, so its
/// free slots are what keeps registering the next page's nodes cheap - see
/// webidl.utils.tombstones.
pub fn tableSlots(scope: *runtime.BrowserScope) tombstones.SlotCounts {
    const bridge = scope.existingTable(.node_bases, Bridge) orelse return .{};
    bridge.lock();
    defer bridge.unlock();
    return tombstones.slotCounts(&bridge.map);
}

/// Register a bidirectional mapping between a runtime.Instance and its NodeBase
///
/// This should be called during Node initialization when both the Instance
/// and its NodeBase are created.
pub fn register(instance: *anyopaque, node_base: *NodeBase) !void {
    const bridge = try scopeOf(instance).table(.node_bases, Bridge);
    bridge.lock();
    defer bridge.unlock();
    bridge.guard.beforeInsert(&bridge.map);
    try bridge.map.put(instance, node_base);
    // Reverse direction lives on the node itself - see NodeBase.owner_instance.
    node_base.owner_instance = instance;
}

/// Unregister a mapping when a Node is destroyed
///
/// This should be called during Node deinitialization.
pub fn unregister(instance: *anyopaque) void {
    const bridge = bridgeOf(instance) orelse return;
    bridge.lock();
    defer bridge.unlock();
    if (bridge.map.get(instance)) |node_base| {
        // Not strictly required - the field dies with the node - but clearing it
        // keeps a freed instance from being observable through a resurrected node.
        node_base.owner_instance = null;
    }
    if (bridge.map.remove(instance)) bridge.guard.noteRemoval(&bridge.map);
}

/// Get the NodeBase for a runtime.Instance
///
/// Returns null if the instance is not registered or has no NodeBase.
pub fn getNodeBase(instance: *anyopaque) ?*NodeBase {
    const bridge = bridgeOf(instance) orelse return null;
    bridge.lock();
    defer bridge.unlock();
    return bridge.map.get(instance);
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
    return node_base.owner_instance;
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

// ============================================================================
// Future: Direct Embedding Pattern
// ============================================================================
//
// Once Node.zig InternalState is updated to embed NodeBase, these functions
// can be optimized to use @fieldParentPtr instead of the hash maps:
//
// pub fn getNodeBaseDirect(instance: *runtime.Instance) ?*NodeBase {
//     const internal = NodeImpl.getInternal(instance) orelse return null;
//     return &internal.node_base;
// }
//
// pub fn getInstanceDirect(node_base: *NodeBase) ?*runtime.Instance {
//     // This requires NodeBase to be the first field, or use @fieldParentPtr
//     const internal: *NodeImpl.InternalState = @fieldParentPtr("node_base", node_base);
//     return internal.instance;
// }
//
// The registry approach is kept as a fallback for nodes that may have
// different storage patterns (e.g., XPath namespace nodes).

// Tests: tests/dom/instance_bridge_test.zig.
