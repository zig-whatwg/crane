//! Implementation for NamedNodeMap interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-namednodemap
//! WHATWG DOM Standard §4.9.1
//!
//! A NamedNodeMap represents a collection of Attr objects. It's used for
//! Element.attributes and provides both indexed and named access.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const infra = @import("infra");
const NamedNodeMap = interfaces.NamedNodeMap;
const AttrImpl = @import("Attr.zig");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;

pub const State = NamedNodeMap.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
    NotFoundError,
    InUseAttributeError,
};

/// Internal state for NamedNodeMap implementation
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The list of Attr nodes
    attrs: infra.List(*runtime.Instance),

    /// Owner element (for attribute modification tracking)
    owner_element: ?*runtime.Instance = null,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .attrs = infra.List(*runtime.Instance).init(allocator),
        };
    }

    pub fn deinit(self: *InternalState) void {
        self.attrs.deinit();
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
/// Spec: https://dom.spec.whatwg.org/#dom-namednodemap-length
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return 0;
    return @intCast(internal.attrs.size());
}

/// Operation: item(index)
/// Spec: https://dom.spec.whatwg.org/#dom-namednodemap-item
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    // Return null for out of bounds per spec
    return internal.attrs.get(index);
}

/// Operation: getNamedItem(qualifiedName)
/// Spec: https://dom.spec.whatwg.org/#dom-namednodemap-getnameditem
pub fn call_getNamedItem(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidState;
    const name = qualifiedName.asSlice();

    // Find attribute by qualified name
    // Use interface per Golden Rule #13
    const attrs = internal.attrs.toSlice();
    for (attrs) |attr| {
        // Get attr's name (qualified name)
        const attr_name = interfaces.Attr.get_name(attr) catch continue;
        if (std.mem.eql(u8, attr_name.asSlice(), name)) {
            return attr;
        }
    }

    return null; // Not found
}

/// Operation: getNamedItemNS(namespace, localName)
/// Spec: https://dom.spec.whatwg.org/#dom-namednodemap-getnameditemns
pub fn call_getNamedItemNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidState;
    const ns = if (namespace) |n| n.asSlice() else "";
    const name = localName.asSlice();

    // Normalize empty namespace to null per spec
    const ns_to_match: ?[]const u8 = if (ns.len == 0) null else ns;

    // Find attribute by namespace and local name (use interface per Golden Rule #13)
    const attrs = internal.attrs.toSlice();
    for (attrs) |attr| {
        // Get attr's namespace and local name
        const attr_ns_opt = interfaces.Attr.get_namespaceURI(attr) catch continue;
        const attr_local = interfaces.Attr.get_localName(attr) catch continue;

        const attr_ns_slice = if (attr_ns_opt) |attr_ns| attr_ns.asSlice() else "";
        const attr_local_slice = attr_local.asSlice();

        // Check namespace match
        const ns_match = if (ns_to_match == null)
            attr_ns_slice.len == 0
        else
            std.mem.eql(u8, attr_ns_slice, ns_to_match.?);

        // Check local name match
        if (ns_match and std.mem.eql(u8, attr_local_slice, name)) {
            return attr;
        }
    }

    return error.NotImplemented; // null
}

/// Operation: setNamedItem(attr)
/// Spec: https://dom.spec.whatwg.org/#dom-namednodemap-setnameditem
pub fn call_setNamedItem(instance: *runtime.Instance, attr: *runtime.Instance) anyerror!?*runtime.Instance {
    return setAttr(instance, attr);
}

/// Operation: setNamedItemNS(attr)
/// Spec: https://dom.spec.whatwg.org/#dom-namednodemap-setnameditemns
pub fn call_setNamedItemNS(instance: *runtime.Instance, attr: *runtime.Instance) anyerror!?*runtime.Instance {
    return setAttr(instance, attr);
}

/// Operation: removeNamedItem(qualifiedName)
/// Spec: https://dom.spec.whatwg.org/#dom-namednodemap-removenameditem
pub fn call_removeNamedItem(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidState;
    const name = qualifiedName.asSlice();

    // Find and remove attribute by qualified name (use interface per Golden Rule #13)
    for (internal.attrs.toSlice(), 0..) |attr, i| {
        const attr_name = interfaces.Attr.get_name(attr) catch continue;
        if (std.mem.eql(u8, attr_name.asSlice(), name)) {
            // Remove from list
            const removed = internal.attrs.remove(i) catch return error.NotFoundError;

            // Update length
            const state = instance.getState(State);
            state.own.length = @intCast(internal.attrs.size());

            // Clear owner element
            AttrImpl.setOwnerElement(removed, null) catch {};

            return removed;
        }
    }

    return error.NotFoundError;
}

/// Operation: removeNamedItemNS(namespace, localName)
/// Spec: https://dom.spec.whatwg.org/#dom-namednodemap-removenameditemns
pub fn call_removeNamedItemNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidState;
    const ns = if (namespace) |n| n.asSlice() else "";
    const name = localName.asSlice();

    // Normalize empty namespace to null per spec
    const ns_to_match: ?[]const u8 = if (ns.len == 0) null else ns;

    // Find and remove attribute by namespace and local name (use interface per Golden Rule #13)
    for (internal.attrs.toSlice(), 0..) |attr, i| {
        const attr_ns_opt = interfaces.Attr.get_namespaceURI(attr) catch continue;
        const attr_local = interfaces.Attr.get_localName(attr) catch continue;

        const attr_ns_slice = if (attr_ns_opt) |attr_ns| attr_ns.asSlice() else "";
        const attr_local_slice = attr_local.asSlice();

        // Check namespace match
        const ns_match = if (ns_to_match == null)
            attr_ns_slice.len == 0
        else
            std.mem.eql(u8, attr_ns_slice, ns_to_match.?);

        // Check local name match
        if (ns_match and std.mem.eql(u8, attr_local_slice, name)) {
            // Remove from list
            const removed = internal.attrs.remove(i) catch return error.NotFoundError;

            // Update length
            const state = instance.getState(State);
            state.own.length = @intCast(internal.attrs.size());

            // Clear owner element
            AttrImpl.setOwnerElement(removed, null) catch {};

            return removed;
        }
    }

    return error.NotFoundError;
}

// ============================================================================
// Internal helper functions
// ============================================================================

/// Set an attribute in the map
fn setAttr(instance: *runtime.Instance, attr: *runtime.Instance) !*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidState;
    try internal.attrs.append(attr);

    // Update length
    const state = instance.getState(State);
    state.own.length = @intCast(internal.attrs.size());

    return attr;
}

/// Add an attribute to the map (internal API)
pub fn addAttr(instance: *runtime.Instance, attr: *runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    try internal.attrs.append(attr);

    // Update length
    const state = instance.getState(State);
    state.own.length = @intCast(internal.attrs.size());
}

/// Set the owner element
pub fn setOwnerElement(instance: *runtime.Instance, element: ?*runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    internal.owner_element = element;
}

/// Get the attrs as a slice
pub fn getAttrs(instance: *runtime.Instance) []const *runtime.Instance {
    const internal = getInternal(instance) orelse return &[_]*runtime.Instance{};
    return internal.attrs.toSlice();
}
