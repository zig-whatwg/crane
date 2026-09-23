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
const dom = @import("dom");
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

    /// The element whose attribute list this map is.
    owner_element: ?*runtime.Instance = null,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *InternalState) void {
        _ = self;
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
        // CRITICAL: Clear the pointer after deinit to prevent double-free.
        // Without this, a second call to deinit (e.g., from both Element cleanup
        // and wrapper_cache cleanup) would try to deinit already-freed memory,
        // causing integer overflow crashes when ArrayList tries to free its
        // heap storage with corrupted slice.len.
        const Arena = @import("runtime").ArenaAllocator;
        if (Arena.tryGet() catch null) |arena| arena.destroy(InternalState, internal);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// The element this map is the attribute list of - live while it is.
fn ownerOf(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    return internal.owner_element;
}

/// Getter for length: "the attribute list's size".
/// Spec: https://dom.spec.whatwg.org/#dom-namednodemap-length
///
/// A NamedNodeMap is its element's attribute list, not a copy of it: every
/// member below reads the element when it is called.
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const owner = ownerOf(instance) orelse return 0;
    return @intCast(dom.element_attributes.count(owner));
}

/// Operation: item(index) - "If index is equal to or greater than this's
/// attribute list's size, then return null. Otherwise, return this's
/// attribute list[index]."
/// Spec: https://dom.spec.whatwg.org/#dom-namednodemap-item
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
    const owner = ownerOf(instance) orelse return null;
    return dom.element_attributes.nodeAt(owner, index);
}

/// Operation: getNamedItem(qualifiedName) - "getting an attribute given
/// qualifiedName and element".
/// Spec: https://dom.spec.whatwg.org/#dom-namednodemap-getnameditem
pub fn call_getNamedItem(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!?*runtime.Instance {
    const owner = ownerOf(instance) orelse return null;
    return interfaces.Element.call_getAttributeNode(owner, qualifiedName);
}

/// Operation: getNamedItemNS(namespace, localName)
/// Spec: https://dom.spec.whatwg.org/#dom-namednodemap-getnameditemns
pub fn call_getNamedItemNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!?*runtime.Instance {
    const owner = ownerOf(instance) orelse return null;
    return interfaces.Element.call_getAttributeNodeNS(owner, namespace, localName);
}

/// Operation: setNamedItem(attr) - "setting an attribute given attr and
/// element".
/// Spec: https://dom.spec.whatwg.org/#dom-namednodemap-setnameditem
pub fn call_setNamedItem(instance: *runtime.Instance, attr: *runtime.Instance) anyerror!?*runtime.Instance {
    const owner = ownerOf(instance) orelse return error.InvalidState;
    return interfaces.Element.call_setAttributeNode(owner, attr);
}

/// Operation: setNamedItemNS(attr)
/// Spec: https://dom.spec.whatwg.org/#dom-namednodemap-setnameditemns
pub fn call_setNamedItemNS(instance: *runtime.Instance, attr: *runtime.Instance) anyerror!?*runtime.Instance {
    const owner = ownerOf(instance) orelse return error.InvalidState;
    return interfaces.Element.call_setAttributeNodeNS(owner, attr);
}

/// Operation: removeNamedItem(qualifiedName)
/// Spec: https://dom.spec.whatwg.org/#dom-namednodemap-removenameditem
///
/// "1. Let attr be the result of removing an attribute given qualifiedName
/// and element. 2. If attr is null, then throw a "NotFoundError"
/// DOMException. 3. Return attr." The node removing hands back is the one
/// getAttributeNode names, so the element's own members do both steps.
pub fn call_removeNamedItem(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!*runtime.Instance {
    const owner = ownerOf(instance) orelse return error.NotFoundError;
    const attr = (try interfaces.Element.call_getAttributeNode(owner, qualifiedName)) orelse return error.NotFoundError;
    return interfaces.Element.call_removeAttributeNode(owner, attr);
}

/// Operation: removeNamedItemNS(namespace, localName) - the same, by
/// namespace and local name.
/// Spec: https://dom.spec.whatwg.org/#dom-namednodemap-removenameditemns
pub fn call_removeNamedItemNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!*runtime.Instance {
    const owner = ownerOf(instance) orelse return error.NotFoundError;
    const attr = (try interfaces.Element.call_getAttributeNodeNS(owner, namespace, localName)) orelse return error.NotFoundError;
    return interfaces.Element.call_removeAttributeNode(owner, attr);
}

// ============================================================================
// Internal helper functions
// ============================================================================

/// Set the owner element
pub fn setOwnerElement(instance: *runtime.Instance, element: ?*runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    internal.owner_element = element;
}

/// The supported property names.
/// Spec: https://dom.spec.whatwg.org/#ref-for-dfn-supported-property-names
///
/// "1. Let names be the qualified names of the attributes in this NamedNodeMap
/// object's attribute list, with duplicates omitted, in order.
/// 2. If this NamedNodeMap object's element is in the HTML namespace and its
/// node document is an HTML document, then for each name of names: if name,
/// in ASCII lowercase, is not name, remove name from names."
pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
    const owner = ownerOf(instance) orelse return &[_]runtime.DOMString{};
    const lowercase_only = isHtmlElementInHtmlDocument(owner);

    var names: std.ArrayList(runtime.DOMString) = .empty;
    errdefer {
        for (names.items) |*name| name.deinit(allocator);
        names.deinit(allocator);
    }

    var index: usize = 0;
    while (dom.element_attributes.at(owner, index)) |attribute| : (index += 1) {
        const qualified = if (attribute.prefix) |prefix|
            try std.fmt.allocPrint(allocator, "{s}:{s}", .{ prefix, attribute.local_name })
        else
            try allocator.dupe(u8, attribute.local_name);
        var name = runtime.DOMString.initOwned(qualified);

        const has_upper = for (qualified) |c| {
            if (std.ascii.isUpper(c)) break true;
        } else false;
        const duplicate = for (names.items) |existing| {
            if (std.mem.eql(u8, existing.asSlice(), qualified)) break true;
        } else false;
        if (duplicate or (lowercase_only and has_upper)) {
            name.deinit(allocator);
            continue;
        }
        try names.append(allocator, name);
    }

    return names.toOwnedSlice(allocator);
}

/// "element is in the HTML namespace and its node document is an HTML
/// document", asked through Element's own members.
fn isHtmlElementInHtmlDocument(element: *runtime.Instance) bool {
    var namespace = (interfaces.Element.get_namespaceURI(element) catch return false) orelse return false;
    defer namespace.deinit(element.ctx.allocator);
    if (!std.mem.eql(u8, namespace.asSlice(), infra.namespaces.HTML_NAMESPACE)) return false;
    const document = (interfaces.Node.get_ownerDocument(element) catch return false) orelse return false;
    return dom.document_internals.getDocumentType(document) == .html;
}
