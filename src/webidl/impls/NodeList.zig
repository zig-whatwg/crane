//! Implementation for NodeList interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-nodelist
//! WHATWG DOM Standard §4.2.6
//!
//! A NodeList object is a collection of nodes, usually returned by
//! properties such as Node.childNodes and methods such as
//! document.querySelectorAll().
//!
//! ## Live vs Static Collections
//!
//! Per spec (https://dom.spec.whatwg.org/#concept-collection):
//! - A collection can be either **live** or **static**
//! - If a collection is live, the attributes and methods operate on the
//!   **actual underlying data**, not a snapshot
//! - Node.childNodes returns a **live** NodeList
//! - document.querySelectorAll() returns a **static** NodeList
//!
//! ## [SameObject] Semantics
//!
//! The `childNodes` attribute has [SameObject] extended attribute, meaning
//! the same NodeList object must be returned on every access. This is
//! achieved by caching the NodeList in Node's internal state.
//!
//! ## Implementation
//!
//! Live NodeLists don't store nodes directly. Instead, they store a reference
//! to the root node and query children on-demand. This ensures the collection
//! always reflects the current DOM state without requiring invalidation.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const infra = @import("infra");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const NodeList = interfaces.NodeList;

pub const State = NodeList.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

/// Type of live collection filter
pub const LiveCollectionType = enum {
    /// Match all direct children (for Node.childNodes)
    children,
    /// Match elements by tag name (for getElementsByTagName)
    elements_by_tag,
    /// Match elements by class name (for getElementsByClassName)
    elements_by_class,
    /// Match elements by namespace and local name
    elements_by_ns,
};

/// Internal state for NodeList implementation
/// NodeList can be either live (reflecting DOM changes) or static (snapshot)
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The list of nodes (for static NodeLists only)
    /// Live NodeLists query on-demand and don't populate this
    nodes: infra.List(*runtime.Instance),

    /// Whether this is a live NodeList (reflects DOM changes) or static
    is_live: bool = false,

    /// For live NodeLists, the root node to query from
    root: ?*runtime.Instance = null,

    /// Type of live collection (determines what nodes match)
    live_type: LiveCollectionType = .children,

    /// Filter parameters for live collections
    /// For elements_by_tag: the tag name to match
    /// For elements_by_class: the class name to match
    filter_name: ?[]const u8 = null,

    /// Namespace URI for elements_by_ns filter
    filter_namespace: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .nodes = infra.List(*runtime.Instance).init(allocator),
        };
    }

    pub fn deinit(self: *InternalState) void {
        self.nodes.deinit();
        // Note: filter_name and filter_namespace are slices into
        // other owned memory, don't free them here
    }
};

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
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
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Getter for length
/// Spec: https://dom.spec.whatwg.org/#dom-nodelist-length
/// Returns the number of nodes in the collection.
/// For live collections, queries the root node on-demand.
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return 0;

    // For live collections, query on-demand
    if (internal.is_live) {
        return getLiveLength(internal);
    }

    // For static collections, use stored nodes
    return @intCast(internal.nodes.size());
}

/// Operation: item(index)
/// Spec: https://dom.spec.whatwg.org/#dom-nodelist-item
/// Returns the node at the given index, or null if out of bounds.
/// For live collections, queries the root node on-demand.
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;

    // For live collections, query on-demand
    if (internal.is_live) {
        return getLiveItem(internal, index);
    }

    // For static collections, use stored nodes
    // Return null for out of bounds per spec
    return internal.nodes.get(index);
}

/// Operation: forEach(callback)
/// Spec: https://webidl.spec.whatwg.org/#es-forEach
/// Calls callback for each node in the list
pub fn call_forEach(instance: *runtime.Instance, callback: runtime.JSValue) anyerror!void {
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

// ============================================================================
// Live Collection Support
// ============================================================================

/// Create a live NodeList for Node.childNodes
/// This is a live collection that reflects changes to the DOM tree
/// Spec: https://dom.spec.whatwg.org/#concept-collection-live
pub fn createLiveChildNodes(allocator: std.mem.Allocator, ctx: runtime.Context, root: *runtime.Instance) !*runtime.Instance {
    const instance = try init(allocator, State, &NodeList.vtable, ctx);
    errdefer deinit(instance);

    const internal = getInternal(instance) orelse return error.InvalidState;

    // Configure as a live collection
    internal.is_live = true;
    internal.root = root;
    internal.live_type = .children;

    return instance;
}

/// Get the length of a live collection by querying the root node
/// For .children type, counts direct children of root
fn getLiveLength(internal: *InternalState) u32 {
    const root = internal.root orelse return 0;

    // Import Node impl to access helper functions
    const NodeImpl = @import("Node.zig");

    switch (internal.live_type) {
        .children => {
            // Count direct children using Node's helper
            return NodeImpl.getChildCount(root);
        },
        // Other live collection types can be added here
        else => return 0,
    }
}

/// Get the nth item from a live collection by querying the root node
/// For .children type, returns the nth direct child
fn getLiveItem(internal: *InternalState, index: u32) ?*runtime.Instance {
    const root = internal.root orelse return null;

    // Import Node impl to access helper functions
    const NodeImpl = @import("Node.zig");

    switch (internal.live_type) {
        .children => {
            // Walk children to find the nth one
            var child = NodeImpl.getFirstChild(root);
            var current_index: u32 = 0;

            while (child) |c| {
                if (current_index == index) {
                    return c;
                }
                current_index += 1;
                child = NodeImpl.getNextSibling(c);
            }
            return null;
        },
        // Other live collection types can be added here
        else => return null,
    }
}
