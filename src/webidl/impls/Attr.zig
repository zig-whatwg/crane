//! Implementation for Attr interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-attr
//! WHATWG DOM Standard §4.9
//!
//! Attr nodes represent attributes on elements.
//! Attributes have a namespace, namespace prefix, local name, value, and element.
//!
//! Migrated from: webidl/src/dom/Attr.zig

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const Attr = interfaces.Attr;

// Import related impls
const NodeImpl = @import("Node.zig");

// Import DOM algorithms
const dom = @import("dom");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;

pub const State = Attr.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

/// Internal state for Attr implementation
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The attribute's namespace (null or a non-empty string)
    namespace_uri: ?[]const u8,

    /// The attribute's namespace prefix (null or a non-empty string)
    prefix: ?[]const u8,

    /// The attribute's local name (a non-empty string)
    local_name: []const u8,

    /// The attribute's value (a string)
    value: []u8,

    /// The element this attribute belongs to (null or an element)
    owner_element: ?*runtime.Instance,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .namespace_uri = null,
            .prefix = null,
            .local_name = "",
            .value = &[_]u8{},
            .owner_element = null,
        };
    }

    pub fn deinit(self: *InternalState) void {
        if (self.namespace_uri) |ns| self.allocator.free(ns);
        if (self.prefix) |p| self.allocator.free(p);
        if (self.local_name.len > 0) self.allocator.free(self.local_name);
        if (self.value.len > 0) self.allocator.free(self.value);
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

    // Initialize Attr internal state
    const state = instance.getState(StateType);
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    state.own._internal = internal;

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

// =============================================================================
// Getters - DOM §4.9
// =============================================================================

/// Getter for namespaceURI
/// DOM §4.9 - Returns this's namespace.
pub fn get_namespaceURI(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.namespace_uri) |ns| {
        // Clone to transfer ownership to caller (interface layer will free)
        return try runtime.DOMString.initDupe(instance.ctx.allocator, ns);
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for prefix
/// DOM §4.9 - Returns this's namespace prefix.
pub fn get_prefix(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.prefix) |p| {
        // Clone to transfer ownership to caller (interface layer will free)
        return try runtime.DOMString.initDupe(instance.ctx.allocator, p);
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for localName
/// DOM §4.9 - Returns this's local name.
pub fn get_localName(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clone to transfer ownership to caller (interface layer will free)
    return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.local_name);
}

/// Getter for name
/// DOM §4.9 - Returns this's qualified name.
/// The qualified name is local name if namespace prefix is null,
/// otherwise it's prefix + ":" + local name.
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    if (internal.prefix) |p| {
        // Qualified name: prefix + ":" + localName
        // Use instance.ctx.allocator for returned strings (interface layer will free)
        const qualified = try std.fmt.allocPrint(
            instance.ctx.allocator,
            "{s}:{s}",
            .{ p, internal.local_name },
        );
        return runtime.DOMString.initOwned(qualified);
    }
    // No prefix, clone local name to transfer ownership to caller
    return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.local_name);
}

/// Getter for value
/// DOM §4.9 - Returns this's value.
pub fn get_value(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clone to transfer ownership to caller (interface layer will free)
    return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.value);
}

/// Getter for ownerElement
/// DOM §4.9 - Returns this's element.
pub fn get_ownerElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.owner_element) |elem| {
        return elem;
    }
    return error.NotImplemented; // null
}

/// Getter for specified
/// DOM §4.9 - Always returns true (this is a legacy attribute).
pub fn get_specified(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return true;
}

// =============================================================================
// Setters - DOM §4.9
// =============================================================================

/// Setter for value
/// DOM §4.9 - Sets this's value.
/// Steps: Set an existing attribute value with this and the given value.
pub fn set_value(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const new_value = value.asSlice();

    // Step 1: If attribute's element is null, set attribute's value directly
    if (internal.owner_element == null) {
        if (internal.value.len > 0) {
            internal.allocator.free(internal.value);
        }
        internal.value = try internal.allocator.dupe(u8, new_value);
        return;
    }

    // Step 2: Otherwise, change attribute to value (with mutation observer notification)
    // TODO: Call dom.mutation_observer_algorithms.queueMutationRecord for "attributes"
    if (internal.value.len > 0) {
        internal.allocator.free(internal.value);
    }
    internal.value = try internal.allocator.dupe(u8, new_value);
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Create an Attr with the given properties
pub fn createAttr(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    namespace_uri: ?[]const u8,
    prefix: ?[]const u8,
    local_name: []const u8,
    value: []const u8,
) !*runtime.Instance {
    const instance = try init(allocator, State, &Attr.vtable, ctx);
    errdefer deinit(instance);

    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Set node type to ATTRIBUTE_NODE (2)
    try NodeImpl.setNodeType(instance, NodeImpl.NodeType.ATTRIBUTE_NODE);

    // Set attribute properties
    internal.namespace_uri = if (namespace_uri) |ns| try allocator.dupe(u8, ns) else null;
    internal.prefix = if (prefix) |p| try allocator.dupe(u8, p) else null;
    internal.local_name = try allocator.dupe(u8, local_name);
    internal.value = try allocator.dupe(u8, value);

    return instance;
}

/// Set the owner element
pub fn setOwnerElement(instance: *runtime.Instance, element: ?*runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.owner_element = element;
}
