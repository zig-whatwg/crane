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

// Forward declaration - will be resolved when Node.zig impl adds the node_base field
// For now, we use a simpler approach that doesn't require modifying InternalState yet

/// Placeholder type for the bridge context
/// This will be populated when Node.zig InternalState is updated
pub const BridgeContext = struct {
    /// The NodeBase embedded in InternalState
    node_base: *NodeBase,
    /// Back-pointer to the runtime.Instance
    instance: *anyopaque,
};

/// Registry mapping runtime.Instance pointers to their NodeBase
/// This is a temporary solution until NodeBase is embedded in InternalState
///
/// Thread safety: This is NOT thread-safe. DOM operations should be single-threaded.
var instance_to_nodebase: std.AutoHashMap(*anyopaque, *NodeBase) = undefined;
var nodebase_to_instance: std.AutoHashMap(*NodeBase, *anyopaque) = undefined;
var initialized: bool = false;

/// Initialize the bridge registry
/// Called once at startup
pub fn init() void {
    if (initialized) return;
    instance_to_nodebase = std.AutoHashMap(*anyopaque, *NodeBase).init(std.heap.page_allocator);
    nodebase_to_instance = std.AutoHashMap(*NodeBase, *anyopaque).init(std.heap.page_allocator);
    initialized = true;
}

/// Deinitialize the bridge registry
/// Called at shutdown (optional, as page_allocator doesn't need cleanup)
pub fn deinit() void {
    if (!initialized) return;
    instance_to_nodebase.deinit();
    nodebase_to_instance.deinit();
    initialized = false;
}

/// Register a bidirectional mapping between a runtime.Instance and its NodeBase
///
/// This should be called during Node initialization when both the Instance
/// and its NodeBase are created.
///
/// Example:
/// ```zig
/// pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
///     const instance = try runtime.Instance.create(allocator, ...);
///     const internal = InternalState.init(allocator);
///     Registry.put(instance, internal);
///
///     // Register with bridge
///     try instance_bridge.register(instance, &internal.node_base);
///
///     return instance;
/// }
/// ```
pub fn register(instance: *anyopaque, node_base: *NodeBase) !void {
    if (!initialized) init();
    try instance_to_nodebase.put(instance, node_base);
    try nodebase_to_instance.put(node_base, instance);
}

/// Unregister a mapping when a Node is destroyed
///
/// This should be called during Node deinitialization.
pub fn unregister(instance: *anyopaque) void {
    if (!initialized) return;

    if (instance_to_nodebase.get(instance)) |node_base| {
        _ = nodebase_to_instance.remove(node_base);
    }
    _ = instance_to_nodebase.remove(instance);
}

/// Get the NodeBase for a runtime.Instance
///
/// Returns null if the instance is not registered or has no NodeBase.
///
/// Example:
/// ```zig
/// const node_base = bridge.getNodeBase(instance) orelse return error.InvalidStateError;
/// try dom.mutation.insert(node_base, parent_base, null, false);
/// ```
pub fn getNodeBase(instance: *anyopaque) ?*NodeBase {
    if (!initialized) return null;
    return instance_to_nodebase.get(instance);
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
    if (!initialized) return null;
    return nodebase_to_instance.get(node_base);
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

// ============================================================================
// Tests
// ============================================================================

test "instance_bridge: register and lookup" {
    init();
    defer deinit();

    // Create a mock NodeBase
    const allocator = std.testing.allocator;
    var node_base = NodeBase{
        .allocator = allocator,
        .node_type = NodeBase.ELEMENT_NODE,
        .node_name = "div",
        .parent_node = null,
        .child_nodes = undefined, // Not needed for this test
        .owner_document = null,
        .registered_observers = undefined, // Not needed for this test
    };

    // Create a mock instance (just need a unique pointer)
    var mock_instance: u8 = 0;
    const instance_ptr: *anyopaque = @ptrCast(&mock_instance);

    // Register
    try register(instance_ptr, &node_base);

    // Lookup by instance
    const found_nodebase = getNodeBase(instance_ptr);
    try std.testing.expect(found_nodebase != null);
    try std.testing.expectEqual(&node_base, found_nodebase.?);

    // Lookup by nodebase
    const found_instance = getInstance(&node_base);
    try std.testing.expect(found_instance != null);
    try std.testing.expectEqual(instance_ptr, found_instance.?);

    // isRuntimeInstance
    try std.testing.expect(isRuntimeInstance(&node_base));

    // Unregister
    unregister(instance_ptr);

    // Should no longer be found
    try std.testing.expect(getNodeBase(instance_ptr) == null);
    try std.testing.expect(getInstance(&node_base) == null);
    try std.testing.expect(!isRuntimeInstance(&node_base));
}

test "instance_bridge: typed accessors" {
    init();
    defer deinit();

    const allocator = std.testing.allocator;
    var node_base = NodeBase{
        .allocator = allocator,
        .node_type = NodeBase.TEXT_NODE,
        .node_name = "#text",
        .parent_node = null,
        .child_nodes = undefined,
        .owner_document = null,
        .registered_observers = undefined,
    };

    // Use a typed mock
    const MockInstance = struct {
        id: u32,
    };
    var mock = MockInstance{ .id = 42 };

    try register(@ptrCast(&mock), &node_base);
    defer unregister(@ptrCast(&mock));

    // Typed lookup
    const found = getInstanceTyped(MockInstance, &node_base);
    try std.testing.expect(found != null);
    try std.testing.expectEqual(@as(u32, 42), found.?.id);
}
