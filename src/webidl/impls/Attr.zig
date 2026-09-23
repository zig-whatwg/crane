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

    /// The element this attribute belongs to (null or an element). While it
    /// is set, the attribute's value lives in that element's attribute list
    /// and `value` above is unused; the slab generation tells a live element
    /// from a freed slot in a teardown sweep.
    owner_element: ?*runtime.Instance,
    owner_generation: u64 = 0,

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
/// Chains to parent class initialization: Node -> EventTarget
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain to parent class (Node) which chains to EventTarget
    const instance = try NodeImpl.init(allocator, StateType, vtable, ctx);
    errdefer NodeImpl.deinit(instance);

    // Initialize Attr internal state
    const state = instance.getState(StateType);
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    state.own._internal = internal;

    // An attribute node's node type, whichever path made it.
    try NodeImpl.setNodeType(instance, NodeImpl.NodeType.ATTRIBUTE_NODE);

    // The hook elements and Document's factories fill a new node through.
    dom.attr_nodes.install(.{ .name = &nameHook, .attach = &attachHook, .detach = &detachHook });

    return instance;
}

/// This attribute's element, if it has one that is still alive.
fn liveElement(internal: *const InternalState) ?*runtime.Instance {
    const element = internal.owner_element orelse return null;
    if (runtime.SlabAllocator.generationOf(element) != internal.owner_generation) return null;
    return element;
}

/// `dom.attr_nodes.name`.
fn nameHook(instance: *runtime.Instance, namespace: ?[]const u8, prefix: ?[]const u8, local_name: []const u8) dom.attr_nodes.Error!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const allocator = internal.allocator;
    const namespace_copy: ?[]const u8 = if (namespace) |ns| try allocator.dupe(u8, ns) else null;
    errdefer if (namespace_copy) |ns| allocator.free(ns);
    const prefix_copy: ?[]const u8 = if (prefix) |p| try allocator.dupe(u8, p) else null;
    errdefer if (prefix_copy) |p| allocator.free(p);
    const local_copy = try allocator.dupe(u8, local_name);

    if (internal.namespace_uri) |old| allocator.free(old);
    if (internal.prefix) |old| allocator.free(old);
    if (internal.local_name.len > 0) allocator.free(internal.local_name);
    internal.namespace_uri = namespace_copy;
    internal.prefix = prefix_copy;
    internal.local_name = local_copy;
}

/// `dom.attr_nodes.attach`: "set attribute's element to element" and "set
/// attribute's node document to element's node document".
fn attachHook(instance: *runtime.Instance, element: *runtime.Instance) dom.attr_nodes.Error!void {
    setOwnerElement(instance, element) catch return error.InvalidStateError;
}

/// `dom.attr_nodes.detach`: "set attribute's element to null", keeping the
/// value the element's list held for it.
fn detachHook(instance: *runtime.Instance, value: []const u8) dom.attr_nodes.Error!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const copy = try internal.allocator.dupe(u8, value);
    if (internal.value.len > 0) internal.allocator.free(internal.value);
    internal.value = copy;
    internal.owner_element = null;
    internal.owner_generation = 0;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();

        // Return the block itself, not just what it points to.
        // `internal.deinit()` releases the strings and lists the state
        // OWNS; without this the state struct stays allocated for the
        // life of the process - measured at 208 bytes per discarded
        // element across the impls still doing it this way.
        const Arena = @import("runtime").ArenaAllocator;
        if (Arena.tryGet() catch null) |arena| arena.destroy(InternalState, internal);
        state.own._internal = null;
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
    // `DOMString?`: no namespace is null, not "".
    const ns = internal.namespace_uri orelse return null;
    // Clone to transfer ownership to caller (interface layer will free)
    return try runtime.DOMString.initDupe(instance.ctx.allocator, ns);
}

/// Getter for prefix
/// DOM §4.9 - Returns this's namespace prefix.
pub fn get_prefix(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // `DOMString?`: no prefix is null, not "".
    const p = internal.prefix orelse return null;
    // Clone to transfer ownership to caller (interface layer will free)
    return try runtime.DOMString.initDupe(instance.ctx.allocator, p);
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
    // An attribute with an element has its value in that element's list: read
    // it there, so a change made through setAttribute shows here.
    if (liveElement(internal)) |element| {
        const namespace: ?runtime.DOMString = if (internal.namespace_uri) |ns| runtime.DOMString.initInterned(ns) else null;
        const found = interfaces.Element.call_getAttributeNS(element, namespace, runtime.DOMString.initInterned(internal.local_name)) catch null;
        if (found) |value| return try runtime.DOMString.initDupe(instance.ctx.allocator, value.asSlice());
    }
    // Clone to transfer ownership to caller (interface layer will free)
    return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.value);
}

/// Getter for ownerElement
/// DOM §4.9 - Returns this's element.
pub fn get_ownerElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return liveElement(internal);
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

    // "Set an existing attribute value":
    // Step 1: "If attribute's element is null, then set attribute's value to
    // value."
    const element = liveElement(internal) orelse {
        const copy = try internal.allocator.dupe(u8, new_value);
        if (internal.value.len > 0) internal.allocator.free(internal.value);
        internal.value = copy;
        return;
    };

    // Step 2: "Otherwise, change attribute to value" - in its element's list,
    // which queues the record and runs the attribute change steps.
    try dom.element_attributes.change(element, internal.namespace_uri, internal.local_name, new_value);
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
///
/// An attribute's node document is its element's (DOM "attribute" concept):
/// taken here, because every path that hands an element's attribute to script
/// creates the Attr and then sets its element. Without it `attr.baseURI`
/// threw InvalidStateError, having no document to ask.
pub fn setOwnerElement(instance: *runtime.Instance, element: ?*runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.owner_element = element;
    internal.owner_generation = if (element) |el| runtime.SlabAllocator.generationOf(el) else 0;
    if (element) |el| {
        if (interfaces.Node.get_ownerDocument(el) catch null) |document| {
            try NodeImpl.setOwnerDocument(instance, document);
        }
    }
}
