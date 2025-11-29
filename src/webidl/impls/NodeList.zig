//! Implementation for NodeList interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-nodelist
//! WHATWG DOM Standard §4.2.6
//!
//! A NodeList object is a collection of nodes, usually returned by
//! properties such as Node.childNodes and methods such as
//! document.querySelectorAll().

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const infra = @import("infra");
const NodeList = interfaces.NodeList;

pub const State = NodeList.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

/// Internal state for NodeList implementation
/// NodeList can be either live (reflecting DOM changes) or static (snapshot)
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The list of nodes
    nodes: infra.List(*runtime.Instance),

    /// Whether this is a live NodeList (reflects DOM changes) or static
    is_live: bool = false,

    /// For live NodeLists, the root node to query from
    root: ?*runtime.Instance = null,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .nodes = infra.List(*runtime.Instance).init(allocator),
        };
    }

    pub fn deinit(self: *InternalState) void {
        self.nodes.deinit();
    }
};

/// Get the internal state from an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Initialize internal state
    const state = instance.getState(StateType);
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    state.own._internal = internal;

    // Initialize length to 0
    state.own.length = 0;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    runtime.Instance.deinit(instance);
}

/// Getter for length
/// Spec: https://dom.spec.whatwg.org/#dom-nodelist-length
/// Returns the number of nodes in the collection.
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return 0;
    return @intCast(internal.nodes.size());
}

/// Operation: item(index)
/// Spec: https://dom.spec.whatwg.org/#dom-nodelist-item
/// Returns the node at the given index, or null if out of bounds.
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidState;
    return internal.nodes.get(index) orelse return error.NotImplemented;
}

/// Operation: forEach(callback)
/// Spec: https://webidl.spec.whatwg.org/#es-forEach
/// Calls callback for each node in the list
pub fn call_forEach(instance: *runtime.Instance, callback: *const anyopaque) anyerror!void {
    const internal = getInternal(instance) orelse return;
    _ = callback;

    // forEach requires JS callback invocation which needs V8 integration
    // For now, we iterate but can't call the callback
    const nodes = internal.nodes.toSlice();
    for (nodes) |_| {
        // TODO: Invoke callback(node, index, this) via V8
    }
}

// ============================================================================
// Internal helper functions (for DOM implementation)
// ============================================================================

/// Add a node to the list
pub fn addNode(instance: *runtime.Instance, node: *runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    try internal.nodes.append(node);

    // Update length in state
    const state = instance.getState(State);
    state.own.length = @intCast(internal.nodes.size());
}

/// Clear all nodes from the list
pub fn clear(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    internal.nodes.clear();

    // Update length in state
    const state = instance.getState(State);
    state.own.length = 0;
}

/// Create a static NodeList from a slice of nodes
pub fn createFromSlice(allocator: std.mem.Allocator, ctx: runtime.Context, nodes: []const *runtime.Instance) !*runtime.Instance {
    const instance = try init(allocator, State, &NodeList.vtable, ctx);
    errdefer deinit(instance);

    const internal = getInternal(instance) orelse return error.InvalidState;
    for (nodes) |node| {
        try internal.nodes.append(node);
    }

    // Update length
    const state = instance.getState(State);
    state.own.length = @intCast(internal.nodes.size());

    return instance;
}

/// Get the nodes as a slice (for iteration)
pub fn getNodes(instance: *runtime.Instance) []const *runtime.Instance {
    const internal = getInternal(instance) orelse return &[_]*runtime.Instance{};
    return internal.nodes.toSlice();
}
