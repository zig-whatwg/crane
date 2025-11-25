//! Implementation for Element interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-element
//! WHATWG DOM Standard §4.8
//!
//! Element is the most general base class from which all element objects
//! (i.e. objects that represent elements) in a Document inherit. It only
//! has methods and properties common to all kinds of elements.
//!
//! Migrated from: webidl/src/dom/element.zig

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const Element = interfaces.Element;

// Import related impls
const NodeImpl = @import("Node.zig");

pub const State = Element.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    NotFoundError,
    SyntaxError,
    InvalidCharacterError,
    OutOfMemory,
};

/// Custom element state per HTML spec
/// Spec: https://html.spec.whatwg.org/#custom-element-state
pub const CustomElementState = enum {
    undefined,
    failed,
    uncustomized,
    precustomized,
    custom,
};

/// Internal state for Element implementation
/// Stores element-specific data: namespace, prefix, local name, attributes
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The namespace URI of this element (null for HTML elements in HTML documents)
    namespace_uri: ?runtime.DOMString = null,

    /// The namespace prefix (null if no prefix)
    prefix: ?runtime.DOMString = null,

    /// The local name of this element (the tag name without prefix)
    local_name: runtime.DOMString,

    /// The element's id attribute value (cached for fast lookup)
    id: runtime.DOMString,

    /// The element's class attribute value (cached for classList)
    class_name: runtime.DOMString,

    /// The element's slot attribute value
    slot: runtime.DOMString,

    /// Shadow root attached to this element (null if not a shadow host)
    shadow_root: ?*runtime.Instance = null,

    /// Custom element state per HTML spec
    custom_element_state: CustomElementState = .undefined,

    /// "is" value for customized built-in elements
    is_value: ?runtime.DOMString = null,

    /// Attributes list - stored as pairs of (name, value)
    /// TODO: Replace with proper Attr instances when NamedNodeMap is implemented
    attributes: std.ArrayList(AttributeEntry),

    pub const AttributeEntry = struct {
        namespace_uri: ?[]const u8,
        prefix: ?[]const u8,
        local_name: []const u8,
        value: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .namespace_uri = null,
            .prefix = null,
            .local_name = runtime.DOMString.initEmpty(),
            .id = runtime.DOMString.initEmpty(),
            .class_name = runtime.DOMString.initEmpty(),
            .slot = runtime.DOMString.initEmpty(),
            .shadow_root = null,
            .custom_element_state = .undefined,
            .is_value = null,
            .attributes = .{},
        };
    }

    pub fn deinit(self: *InternalState) void {
        if (self.namespace_uri) |*ns| {
            ns.deinit(self.allocator);
        }
        if (self.prefix) |*p| {
            p.deinit(self.allocator);
        }
        self.local_name.deinit(self.allocator);
        self.id.deinit(self.allocator);
        self.class_name.deinit(self.allocator);
        self.slot.deinit(self.allocator);
        if (self.is_value) |*v| {
            v.deinit(self.allocator);
        }

        // Free attribute entries
        for (self.attributes.items) |entry| {
            if (entry.namespace_uri) |ns| {
                self.allocator.free(ns);
            }
            if (entry.prefix) |p| {
                self.allocator.free(p);
            }
            self.allocator.free(entry.local_name);
            self.allocator.free(entry.value);
        }
        self.attributes.deinit(self.allocator);
    }
};

/// Get the internal state from an instance
/// Made public for use by Document's getElementById, getElementsByTagName, etc.
pub fn getInternal(instance: *runtime.Instance) ?*InternalState {
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

    // Initialize Element internal state
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
    runtime.Instance.deinit(instance);
}

// =============================================================================
// Setters for internal state (used by Document factory methods)
// =============================================================================

/// Set the namespace URI of this element
/// Used by Document.createElementNS
pub fn setNamespaceURI(instance: *runtime.Instance, namespace: ?[]const u8) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Free existing namespace if any
    if (internal.namespace_uri) |*ns| {
        ns.deinit(internal.allocator);
        internal.namespace_uri = null;
    }

    // Set new namespace if provided
    if (namespace) |ns| {
        internal.namespace_uri = try runtime.DOMString.initDupe(internal.allocator, ns);
    }
}

/// Set the namespace prefix of this element
/// Used by Document.createElementNS
pub fn setPrefix(instance: *runtime.Instance, prefix: ?[]const u8) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Free existing prefix if any
    if (internal.prefix) |*p| {
        p.deinit(internal.allocator);
        internal.prefix = null;
    }

    // Set new prefix if provided
    if (prefix) |p| {
        internal.prefix = try runtime.DOMString.initDupe(internal.allocator, p);
    }
}

/// Set the local name of this element
/// Used by Document.createElement and Document.createElementNS
pub fn setLocalName(instance: *runtime.Instance, local_name: []const u8) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Free existing local name
    internal.local_name.deinit(internal.allocator);

    // Set new local name
    internal.local_name = try runtime.DOMString.initDupe(internal.allocator, local_name);
}

/// Getter for namespaceURI
/// DOM §4.8 - Returns the namespace URI of this element
pub fn get_namespaceURI(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.namespace_uri) |ns| {
        return ns;
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for prefix
/// DOM §4.8 - Returns the namespace prefix of this element
pub fn get_prefix(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.prefix) |p| {
        return p;
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for localName
/// DOM §4.8 - Returns the local name of this element
pub fn get_localName(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.local_name;
}

/// Getter for tagName
/// DOM §4.8 - Returns the qualified name of this element
/// For HTML elements in HTML documents, this is uppercase
pub fn get_tagName(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // If there's a prefix, return "prefix:localName"
    if (internal.prefix) |p| {
        // TODO: Concatenate prefix:localName
        // For now, return local name
        _ = p;
        return internal.local_name;
    }

    // No prefix, return just local name
    // TODO: Uppercase for HTML elements in HTML documents
    return internal.local_name;
}

/// Getter for id
/// DOM §4.8 - Returns the value of the id attribute
pub fn get_id(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.id;
}

/// Getter for className
/// DOM §4.8 - Returns the value of the class attribute
pub fn get_className(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.class_name;
}

/// Getter for classList
/// DOM §4.8 - Returns a DOMTokenList for the class attribute
/// TODO: Implement DOMTokenList interface
pub fn get_classList(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for slot
/// DOM §4.8 - Returns the value of the slot attribute
pub fn get_slot(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.slot;
}

/// Getter for attributes
/// DOM §4.8 - Returns a NamedNodeMap of the element's attributes
/// TODO: Implement NamedNodeMap interface
pub fn get_attributes(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for shadowRoot
/// DOM §4.8 - Returns the element's shadow root if attached and mode is "open"
pub fn get_shadowRoot(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.shadow_root) |root| {
        // TODO: Check if shadow root mode is "open"
        return root;
    }
    return error.NotImplemented; // Return null
}

/// Getter for customElementRegistry
pub fn get_customElementRegistry(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onfullscreenchange
pub fn get_onfullscreenchange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onfullscreenerror
pub fn get_onfullscreenerror(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for elementTiming
pub fn get_elementTiming(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for part
pub fn get_part(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for activeViewTransition
pub fn get_activeViewTransition(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for innerHTML
pub fn get_innerHTML(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for outerHTML
pub fn get_outerHTML(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for scrollTop
pub fn get_scrollTop(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for scrollLeft
pub fn get_scrollLeft(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for scrollWidth
pub fn get_scrollWidth(instance: *runtime.Instance) ImplError!i32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for scrollHeight
pub fn get_scrollHeight(instance: *runtime.Instance) ImplError!i32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for clientTop
pub fn get_clientTop(instance: *runtime.Instance) ImplError!i32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for clientLeft
pub fn get_clientLeft(instance: *runtime.Instance) ImplError!i32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for clientWidth
pub fn get_clientWidth(instance: *runtime.Instance) ImplError!i32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for clientHeight
pub fn get_clientHeight(instance: *runtime.Instance) ImplError!i32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for currentCSSZoom
pub fn get_currentCSSZoom(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for role
pub fn get_role(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaActiveDescendantElement
pub fn get_ariaActiveDescendantElement(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaAtomic
pub fn get_ariaAtomic(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaAutoComplete
pub fn get_ariaAutoComplete(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaBrailleLabel
pub fn get_ariaBrailleLabel(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaBrailleRoleDescription
pub fn get_ariaBrailleRoleDescription(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaBusy
pub fn get_ariaBusy(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaChecked
pub fn get_ariaChecked(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaColCount
pub fn get_ariaColCount(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaColIndex
pub fn get_ariaColIndex(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaColIndexText
pub fn get_ariaColIndexText(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaColSpan
pub fn get_ariaColSpan(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaControlsElements
pub fn get_ariaControlsElements(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaCurrent
pub fn get_ariaCurrent(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaDescribedByElements
pub fn get_ariaDescribedByElements(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaDescription
pub fn get_ariaDescription(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaDetailsElements
pub fn get_ariaDetailsElements(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaDisabled
pub fn get_ariaDisabled(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaErrorMessageElements
pub fn get_ariaErrorMessageElements(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaExpanded
pub fn get_ariaExpanded(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaFlowToElements
pub fn get_ariaFlowToElements(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaHasPopup
pub fn get_ariaHasPopup(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaHidden
pub fn get_ariaHidden(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaInvalid
pub fn get_ariaInvalid(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaKeyShortcuts
pub fn get_ariaKeyShortcuts(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaLabel
pub fn get_ariaLabel(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaLabelledByElements
pub fn get_ariaLabelledByElements(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaLevel
pub fn get_ariaLevel(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaLive
pub fn get_ariaLive(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaModal
pub fn get_ariaModal(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaMultiLine
pub fn get_ariaMultiLine(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaMultiSelectable
pub fn get_ariaMultiSelectable(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaOrientation
pub fn get_ariaOrientation(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaOwnsElements
pub fn get_ariaOwnsElements(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaPlaceholder
pub fn get_ariaPlaceholder(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaPosInSet
pub fn get_ariaPosInSet(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaPressed
pub fn get_ariaPressed(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaReadOnly
pub fn get_ariaReadOnly(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaRelevant
pub fn get_ariaRelevant(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaRequired
pub fn get_ariaRequired(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaRoleDescription
pub fn get_ariaRoleDescription(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaRowCount
pub fn get_ariaRowCount(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaRowIndex
pub fn get_ariaRowIndex(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaRowIndexText
pub fn get_ariaRowIndexText(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaRowSpan
pub fn get_ariaRowSpan(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaSelected
pub fn get_ariaSelected(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaSetSize
pub fn get_ariaSetSize(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaSort
pub fn get_ariaSort(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaValueMax
pub fn get_ariaValueMax(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaValueMin
pub fn get_ariaValueMin(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaValueNow
pub fn get_ariaValueNow(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ariaValueText
pub fn get_ariaValueText(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for regionOverset
pub fn get_regionOverset(instance: *runtime.Instance) ImplError!typedefs.CSSOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for children
pub fn get_children(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for firstElementChild
pub fn get_firstElementChild(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for lastElementChild
pub fn get_lastElementChild(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for childElementCount
pub fn get_childElementCount(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for previousElementSibling
pub fn get_previousElementSibling(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for nextElementSibling
pub fn get_nextElementSibling(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for assignedSlot
pub fn get_assignedSlot(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for id
/// DOM §4.8 - Sets the id attribute value
pub fn set_id(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Free old value
    internal.id.deinit(internal.allocator);

    // Clone and store new value
    internal.id = try value.clone(internal.allocator);

    // Also set as attribute
    try setAttributeInternal(internal, null, null, "id", value.asSlice());
}

/// Setter for className
/// DOM §4.8 - Sets the class attribute value
pub fn set_className(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Free old value
    internal.class_name.deinit(internal.allocator);

    // Clone and store new value
    internal.class_name = try value.clone(internal.allocator);

    // Also set as attribute
    try setAttributeInternal(internal, null, null, "class", value.asSlice());
}

/// Setter for slot
/// DOM §4.8 - Sets the slot attribute value
pub fn set_slot(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Free old value
    internal.slot.deinit(internal.allocator);

    // Clone and store new value
    internal.slot = try value.clone(internal.allocator);

    // Also set as attribute
    try setAttributeInternal(internal, null, null, "slot", value.asSlice());
}

/// Internal helper to get an attribute by namespace and local name
fn getAttributeByNS(
    internal: *InternalState,
    namespace_uri: ?[]const u8,
    local_name: []const u8,
) ?*InternalState.AttributeEntry {
    // Step 1: Empty string namespace becomes null per spec
    const ns = if (namespace_uri) |n| if (n.len == 0) null else n else null;

    // Step 2: Find attribute with matching namespace and local name
    for (internal.attributes.items) |*entry| {
        const ns_match = (ns == null and entry.namespace_uri == null) or
            (ns != null and entry.namespace_uri != null and
                std.mem.eql(u8, ns.?, entry.namespace_uri.?));
        const name_match = std.mem.eql(u8, local_name, entry.local_name);

        if (ns_match and name_match) {
            return entry;
        }
    }
    return null;
}

/// Internal helper to remove an attribute by namespace and local name
fn removeAttributeByNS(
    internal: *InternalState,
    namespace_uri: ?[]const u8,
    local_name: []const u8,
) void {
    // Step 1: Empty string namespace becomes null per spec
    const ns = if (namespace_uri) |n| if (n.len == 0) null else n else null;

    var i: usize = 0;
    while (i < internal.attributes.items.len) {
        const entry = internal.attributes.items[i];
        const ns_match = (ns == null and entry.namespace_uri == null) or
            (ns != null and entry.namespace_uri != null and
                std.mem.eql(u8, ns.?, entry.namespace_uri.?));
        const name_match = std.mem.eql(u8, local_name, entry.local_name);

        if (ns_match and name_match) {
            // Free the entry's strings
            if (entry.namespace_uri) |ens| internal.allocator.free(ens);
            if (entry.prefix) |p| internal.allocator.free(p);
            internal.allocator.free(entry.local_name);
            internal.allocator.free(entry.value);

            // Remove from list
            _ = internal.attributes.orderedRemove(i);
            return;
        }
        i += 1;
    }
}

/// Internal helper to set an attribute
fn setAttributeInternal(
    internal: *InternalState,
    namespace_uri: ?[]const u8,
    prefix: ?[]const u8,
    local_name: []const u8,
    value: []const u8,
) !void {
    // Look for existing attribute
    for (internal.attributes.items) |*entry| {
        const ns_match = (namespace_uri == null and entry.namespace_uri == null) or
            (namespace_uri != null and entry.namespace_uri != null and
                std.mem.eql(u8, namespace_uri.?, entry.namespace_uri.?));
        const name_match = std.mem.eql(u8, local_name, entry.local_name);

        if (ns_match and name_match) {
            // Update existing attribute
            internal.allocator.free(entry.value);
            entry.value = try internal.allocator.dupe(u8, value);
            return;
        }
    }

    // Create new attribute entry
    const entry = InternalState.AttributeEntry{
        .namespace_uri = if (namespace_uri) |ns| try internal.allocator.dupe(u8, ns) else null,
        .prefix = if (prefix) |p| try internal.allocator.dupe(u8, p) else null,
        .local_name = try internal.allocator.dupe(u8, local_name),
        .value = try internal.allocator.dupe(u8, value),
    };
    try internal.attributes.append(internal.allocator, entry);
}

/// Setter for onfullscreenchange
pub fn set_onfullscreenchange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onfullscreenerror
pub fn set_onfullscreenerror(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for elementTiming
pub fn set_elementTiming(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for innerHTML
pub fn set_innerHTML(instance: *runtime.Instance, value: *const anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for outerHTML
pub fn set_outerHTML(instance: *runtime.Instance, value: *const anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for scrollTop
pub fn set_scrollTop(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for scrollLeft
pub fn set_scrollLeft(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for role
pub fn set_role(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaActiveDescendantElement
pub fn set_ariaActiveDescendantElement(instance: *runtime.Instance, value: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaAtomic
pub fn set_ariaAtomic(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaAutoComplete
pub fn set_ariaAutoComplete(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaBrailleLabel
pub fn set_ariaBrailleLabel(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaBrailleRoleDescription
pub fn set_ariaBrailleRoleDescription(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaBusy
pub fn set_ariaBusy(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaChecked
pub fn set_ariaChecked(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaColCount
pub fn set_ariaColCount(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaColIndex
pub fn set_ariaColIndex(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaColIndexText
pub fn set_ariaColIndexText(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaColSpan
pub fn set_ariaColSpan(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaControlsElements
pub fn set_ariaControlsElements(instance: *runtime.Instance, value: *const anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaCurrent
pub fn set_ariaCurrent(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaDescribedByElements
pub fn set_ariaDescribedByElements(instance: *runtime.Instance, value: *const anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaDescription
pub fn set_ariaDescription(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaDetailsElements
pub fn set_ariaDetailsElements(instance: *runtime.Instance, value: *const anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaDisabled
pub fn set_ariaDisabled(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaErrorMessageElements
pub fn set_ariaErrorMessageElements(instance: *runtime.Instance, value: *const anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaExpanded
pub fn set_ariaExpanded(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaFlowToElements
pub fn set_ariaFlowToElements(instance: *runtime.Instance, value: *const anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaHasPopup
pub fn set_ariaHasPopup(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaHidden
pub fn set_ariaHidden(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaInvalid
pub fn set_ariaInvalid(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaKeyShortcuts
pub fn set_ariaKeyShortcuts(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaLabel
pub fn set_ariaLabel(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaLabelledByElements
pub fn set_ariaLabelledByElements(instance: *runtime.Instance, value: *const anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaLevel
pub fn set_ariaLevel(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaLive
pub fn set_ariaLive(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaModal
pub fn set_ariaModal(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaMultiLine
pub fn set_ariaMultiLine(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaMultiSelectable
pub fn set_ariaMultiSelectable(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaOrientation
pub fn set_ariaOrientation(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaOwnsElements
pub fn set_ariaOwnsElements(instance: *runtime.Instance, value: *const anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaPlaceholder
pub fn set_ariaPlaceholder(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaPosInSet
pub fn set_ariaPosInSet(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaPressed
pub fn set_ariaPressed(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaReadOnly
pub fn set_ariaReadOnly(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaRelevant
pub fn set_ariaRelevant(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaRequired
pub fn set_ariaRequired(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaRoleDescription
pub fn set_ariaRoleDescription(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaRowCount
pub fn set_ariaRowCount(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaRowIndex
pub fn set_ariaRowIndex(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaRowIndexText
pub fn set_ariaRowIndexText(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaRowSpan
pub fn set_ariaRowSpan(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaSelected
pub fn set_ariaSelected(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaSetSize
pub fn set_ariaSetSize(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaSort
pub fn set_ariaSort(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaValueMax
pub fn set_ariaValueMax(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaValueMin
pub fn set_ariaValueMin(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaValueNow
pub fn set_ariaValueNow(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaValueText
pub fn set_ariaValueText(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: getAttributeNS
/// DOM §4.8 - Returns the value of the attribute with the given namespace and local name
/// Spec: https://dom.spec.whatwg.org/#dom-element-getattributens
pub fn call_getAttributeNS(instance: *runtime.Instance, namespace: runtime.DOMString, localName: runtime.DOMString) ImplError!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const ns_slice = namespace.asSlice();
    const name_slice = localName.asSlice();

    // Get attribute by namespace and local name
    if (getAttributeByNS(internal, if (ns_slice.len > 0) ns_slice else null, name_slice)) |entry| {
        return runtime.DOMString.initInterned(entry.value);
    }

    // Return empty for not found (WebIDL nullable maps to empty)
    return runtime.DOMString.initEmpty();
}

/// Operation: getAttribute
/// DOM §4.8 - Returns the value of the named attribute, or null if not found
pub fn call_getAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString) ImplError!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const name = qualifiedName.asSlice();

    // TODO: Lowercase name for HTML elements in HTML documents

    // Search attributes by local name (no namespace)
    for (internal.attributes.items) |entry| {
        if (entry.namespace_uri == null and std.mem.eql(u8, entry.local_name, name)) {
            return runtime.DOMString.initInterned(entry.value);
        }
    }

    // Return empty for not found (WebIDL nullable maps to empty)
    return runtime.DOMString.initEmpty();
}

/// Operation: hasAttribute
/// DOM §4.8 - Returns true if the element has an attribute with the given name
pub fn call_hasAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString) ImplError!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const name = qualifiedName.asSlice();

    // TODO: Lowercase name for HTML elements in HTML documents

    for (internal.attributes.items) |entry| {
        if (entry.namespace_uri == null and std.mem.eql(u8, entry.local_name, name)) {
            return true;
        }
    }

    return false;
}

/// Operation: matches
pub fn call_matches(instance: *runtime.Instance, selectors: runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = selectors;
    return error.NotImplemented;
}

/// Operation: releasePointerCapture
pub fn call_releasePointerCapture(instance: *runtime.Instance, pointerId: i32) ImplError!void {
    _ = instance;
    _ = pointerId;
    return error.NotImplemented;
}

/// Operation: computedStyleMap
pub fn call_computedStyleMap(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: scroll
pub fn call_scroll(instance: *runtime.Instance, options: dictionaries.ScrollToOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: getClientRects
pub fn call_getClientRects(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: scrollBy
pub fn call_scrollBy(instance: *runtime.Instance, options: dictionaries.ScrollToOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: prepend
pub fn call_prepend(instance: *runtime.Instance, nodes: *const anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    return error.NotImplemented;
}

/// Operation: replaceWith
pub fn call_replaceWith(instance: *runtime.Instance, nodes: *const anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    return error.NotImplemented;
}

/// Operation: convertQuadFromNode
pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: dictionaries.DOMQuadInit, from: typedefs.GeometryNode, options: dictionaries.ConvertCoordinateOptions) ImplError!*runtime.Instance {
    _ = instance;
    _ = quad;
    _ = from;
    _ = options;
    return error.NotImplemented;
}

/// Operation: setAttributeNodeNS
pub fn call_setAttributeNodeNS(instance: *runtime.Instance, attr: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    _ = attr;
    return error.NotImplemented;
}

/// Operation: getAttributeNodeNS
pub fn call_getAttributeNodeNS(instance: *runtime.Instance, namespace: runtime.DOMString, localName: runtime.DOMString) ImplError!*runtime.Instance {
    _ = instance;
    _ = namespace;
    _ = localName;
    return error.NotImplemented;
}

/// Operation: setAttributeNS
/// DOM §4.8 - Sets the attribute with the given namespace and qualified name
/// Spec: https://dom.spec.whatwg.org/#dom-element-setattributens
pub fn call_setAttributeNS(instance: *runtime.Instance, namespace: runtime.DOMString, qualifiedName: runtime.DOMString, value: *const anyopaque) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const ns_slice = namespace.asSlice();
    const qname_slice = qualifiedName.asSlice();

    // Cast value - it should be a DOMString
    const value_str: *const runtime.DOMString = @ptrCast(@alignCast(value));
    const val = value_str.asSlice();

    // Parse qualified name for prefix and local name
    var prefix: ?[]const u8 = null;
    var local_name: []const u8 = qname_slice;

    if (std.mem.indexOfScalar(u8, qname_slice, ':')) |colon_pos| {
        prefix = qname_slice[0..colon_pos];
        local_name = qname_slice[colon_pos + 1 ..];
    }

    // Set attribute value with namespace and prefix
    const ns = if (ns_slice.len > 0) ns_slice else null;
    try setAttributeInternal(internal, ns, prefix, local_name, val);
}

/// Operation: setAttributeNode
pub fn call_setAttributeNode(instance: *runtime.Instance, attr: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    _ = attr;
    return error.NotImplemented;
}

/// Operation: scrollTo
pub fn call_scrollTo(instance: *runtime.Instance, options: dictionaries.ScrollToOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: getElementsByTagNameNS
pub fn call_getElementsByTagNameNS(instance: *runtime.Instance, namespace: runtime.DOMString, localName: runtime.DOMString) ImplError!*runtime.Instance {
    _ = instance;
    _ = namespace;
    _ = localName;
    return error.NotImplemented;
}

/// Operation: replaceChildren
pub fn call_replaceChildren(instance: *runtime.Instance, nodes: *const anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    return error.NotImplemented;
}

/// Operation: getRegionFlowRanges
pub fn call_getRegionFlowRanges(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getBoxQuads
pub fn call_getBoxQuads(instance: *runtime.Instance, options: dictionaries.BoxQuadOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: focusableAreas
pub fn call_focusableAreas(instance: *runtime.Instance, option: dictionaries.FocusableAreasOption) ImplError!*const anyopaque {
    _ = instance;
    _ = option;
    return error.NotImplemented;
}

/// Operation: convertPointFromNode
pub fn call_convertPointFromNode(instance: *runtime.Instance, point: dictionaries.DOMPointInit, from: typedefs.GeometryNode, options: dictionaries.ConvertCoordinateOptions) ImplError!*runtime.Instance {
    _ = instance;
    _ = point;
    _ = from;
    _ = options;
    return error.NotImplemented;
}

/// Operation: getAnimations
pub fn call_getAnimations(instance: *runtime.Instance, options: dictionaries.GetAnimationsOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: getElementsByClassName
pub fn call_getElementsByClassName(instance: *runtime.Instance, classNames: runtime.DOMString) ImplError!*runtime.Instance {
    _ = instance;
    _ = classNames;
    return error.NotImplemented;
}

/// Operation: insertAdjacentElement
pub fn call_insertAdjacentElement(instance: *runtime.Instance, where: runtime.DOMString, element: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    _ = where;
    _ = element;
    return error.NotImplemented;
}

/// Operation: webkitMatchesSelector
pub fn call_webkitMatchesSelector(instance: *runtime.Instance, selectors: runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = selectors;
    return error.NotImplemented;
}

/// Operation: spatialNavigationSearch
pub fn call_spatialNavigationSearch(instance: *runtime.Instance, dir: enums.SpatialNavigationDirection, options: dictionaries.SpatialNavigationSearchOptions) ImplError!*runtime.Instance {
    _ = instance;
    _ = dir;
    _ = options;
    return error.NotImplemented;
}

/// Operation: getElementsByTagName
pub fn call_getElementsByTagName(instance: *runtime.Instance, qualifiedName: runtime.DOMString) ImplError!*runtime.Instance {
    _ = instance;
    _ = qualifiedName;
    return error.NotImplemented;
}

/// Operation: querySelector
pub fn call_querySelector(instance: *runtime.Instance, selectors: runtime.DOMString) ImplError!*runtime.Instance {
    _ = instance;
    _ = selectors;
    return error.NotImplemented;
}

/// Operation: closest
pub fn call_closest(instance: *runtime.Instance, selectors: runtime.DOMString) ImplError!*runtime.Instance {
    _ = instance;
    _ = selectors;
    return error.NotImplemented;
}

/// Operation: getSpatialNavigationContainer
pub fn call_getSpatialNavigationContainer(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: remove
pub fn call_remove(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: removeAttribute
/// DOM §4.8 - Removes the named attribute
pub fn call_removeAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const name = qualifiedName.asSlice();

    // TODO: Lowercase name for HTML elements in HTML documents

    // Find and remove the attribute
    var i: usize = 0;
    while (i < internal.attributes.items.len) {
        const entry = internal.attributes.items[i];
        if (entry.namespace_uri == null and std.mem.eql(u8, entry.local_name, name)) {
            // Free the entry's strings
            if (entry.namespace_uri) |ns| internal.allocator.free(ns);
            if (entry.prefix) |p| internal.allocator.free(p);
            internal.allocator.free(entry.local_name);
            internal.allocator.free(entry.value);

            // Remove from list
            _ = internal.attributes.orderedRemove(i);

            // Clear cached values if applicable
            if (std.mem.eql(u8, name, "id")) {
                internal.id.deinit(internal.allocator);
                internal.id = runtime.DOMString.initEmpty();
            } else if (std.mem.eql(u8, name, "class")) {
                internal.class_name.deinit(internal.allocator);
                internal.class_name = runtime.DOMString.initEmpty();
            } else if (std.mem.eql(u8, name, "slot")) {
                internal.slot.deinit(internal.allocator);
                internal.slot = runtime.DOMString.initEmpty();
            }

            return;
        }
        i += 1;
    }
}

/// Operation: convertRectFromNode
pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: *runtime.Instance, from: typedefs.GeometryNode, options: dictionaries.ConvertCoordinateOptions) ImplError!*runtime.Instance {
    _ = instance;
    _ = rect;
    _ = from;
    _ = options;
    return error.NotImplemented;
}

/// Operation: removeAttributeNode
pub fn call_removeAttributeNode(instance: *runtime.Instance, attr: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    _ = attr;
    return error.NotImplemented;
}

/// Operation: removeAttributeNS
/// DOM §4.8 - Removes the attribute with the given namespace and local name
/// Spec: https://dom.spec.whatwg.org/#dom-element-removeattributens
pub fn call_removeAttributeNS(instance: *runtime.Instance, namespace: runtime.DOMString, localName: runtime.DOMString) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const ns_slice = namespace.asSlice();
    const name_slice = localName.asSlice();

    // Remove by namespace and local name
    removeAttributeByNS(internal, if (ns_slice.len > 0) ns_slice else null, name_slice);
}

/// Operation: insertAdjacentText
pub fn call_insertAdjacentText(instance: *runtime.Instance, where: runtime.DOMString, data: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = where;
    _ = data;
    return error.NotImplemented;
}

/// Operation: requestFullscreen
pub fn call_requestFullscreen(instance: *runtime.Instance, options: dictionaries.FullscreenOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: animate
pub fn call_animate(instance: *runtime.Instance, keyframes: *const anyopaque, options: *const anyopaque) ImplError!*runtime.Instance {
    _ = instance;
    _ = keyframes;
    _ = options;
    return error.NotImplemented;
}

/// Operation: append
pub fn call_append(instance: *runtime.Instance, nodes: *const anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    return error.NotImplemented;
}

/// Operation: moveBefore
pub fn call_moveBefore(instance: *runtime.Instance, node: *runtime.Instance, child: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = node;
    _ = child;
    return error.NotImplemented;
}

/// Operation: getHTML
pub fn call_getHTML(instance: *runtime.Instance, options: dictionaries.GetHTMLOptions) ImplError!runtime.DOMString {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: getAttributeNode
pub fn call_getAttributeNode(instance: *runtime.Instance, qualifiedName: runtime.DOMString) ImplError!*runtime.Instance {
    _ = instance;
    _ = qualifiedName;
    return error.NotImplemented;
}

/// Operation: startViewTransition
pub fn call_startViewTransition(instance: *runtime.Instance, callbackOptions: *const anyopaque) ImplError!*runtime.Instance {
    _ = instance;
    _ = callbackOptions;
    return error.NotImplemented;
}

/// Operation: setHTMLUnsafe
pub fn call_setHTMLUnsafe(instance: *runtime.Instance, html: *const anyopaque) ImplError!void {
    _ = instance;
    _ = html;
    return error.NotImplemented;
}

/// Operation: scrollIntoView
pub fn call_scrollIntoView(instance: *runtime.Instance, arg: *const anyopaque) ImplError!*const anyopaque {
    _ = instance;
    _ = arg;
    return error.NotImplemented;
}

/// Operation: hasAttributes
/// DOM §4.8 - Returns true if the element has any attributes
/// Spec: https://dom.spec.whatwg.org/#dom-element-hasattributes
pub fn call_hasAttributes(instance: *runtime.Instance) ImplError!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.attributes.items.len > 0;
}

/// Operation: hasPointerCapture
pub fn call_hasPointerCapture(instance: *runtime.Instance, pointerId: i32) ImplError!bool {
    _ = instance;
    _ = pointerId;
    return error.NotImplemented;
}

/// Operation: toggleAttribute
/// DOM §4.8 - Toggles the named attribute: removes it if present, adds it if not
/// Spec: https://dom.spec.whatwg.org/#dom-element-toggleattribute
///
/// Steps:
/// 1. If qualifiedName is invalid, throw InvalidCharacterError
/// 2. If HTML element in HTML document, lowercase qualifiedName
/// 3. If attribute exists and force is not true, remove it and return false
/// 4. If attribute doesn't exist and force is not false, add it with empty value and return true
/// 5. Return whether attribute now exists
pub fn call_toggleAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString, force: bool) ImplError!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const name = qualifiedName.asSlice();

    // Step 1: Validate qualified name (simplified - just check non-empty)
    if (name.len == 0) {
        return error.InvalidCharacterError;
    }

    // TODO: Step 2: Lowercase name for HTML elements in HTML documents

    // Step 3: Check if attribute exists
    var attr_index: ?usize = null;
    for (internal.attributes.items, 0..) |entry, i| {
        if (entry.namespace_uri == null and std.mem.eql(u8, entry.local_name, name)) {
            attr_index = i;
            break;
        }
    }

    if (attr_index != null) {
        // Attribute exists
        if (!force) {
            // Remove it
            const entry = internal.attributes.items[attr_index.?];
            if (entry.namespace_uri) |ns| internal.allocator.free(ns);
            if (entry.prefix) |p| internal.allocator.free(p);
            internal.allocator.free(entry.local_name);
            internal.allocator.free(entry.value);
            _ = internal.attributes.orderedRemove(attr_index.?);

            // Clear cached values if applicable
            if (std.mem.eql(u8, name, "id")) {
                internal.id.deinit(internal.allocator);
                internal.id = runtime.DOMString.initEmpty();
            } else if (std.mem.eql(u8, name, "class")) {
                internal.class_name.deinit(internal.allocator);
                internal.class_name = runtime.DOMString.initEmpty();
            } else if (std.mem.eql(u8, name, "slot")) {
                internal.slot.deinit(internal.allocator);
                internal.slot = runtime.DOMString.initEmpty();
            }

            return false;
        }
        // force is true, attribute exists - return true
        return true;
    } else {
        // Attribute doesn't exist
        if (force) {
            // Add it with empty value
            try setAttributeInternal(internal, null, null, name, "");
            return true;
        }
        // force is false, attribute doesn't exist - return false
        return false;
    }
}

/// Operation: pseudo
pub fn call_pseudo(instance: *runtime.Instance, @"type": typedefs.CSSOMString) ImplError!*runtime.Instance {
    _ = instance;
    _ = @"type";
    return error.NotImplemented;
}

/// Operation: before
pub fn call_before(instance: *runtime.Instance, nodes: *const anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    return error.NotImplemented;
}

/// Operation: after
pub fn call_after(instance: *runtime.Instance, nodes: *const anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    return error.NotImplemented;
}

/// Operation: setAttribute
/// DOM §4.8 - Sets the value of the named attribute
/// TODO: value is typed as anyopaque due to codegen - should be DOMString
pub fn call_setAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString, value: *const anyopaque) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const name = qualifiedName.asSlice();

    // TODO: Validate qualifiedName per https://dom.spec.whatwg.org/#validate

    // Cast value - it should be a DOMString
    const value_str: *const runtime.DOMString = @ptrCast(@alignCast(value));
    const val = value_str.asSlice();

    // TODO: Lowercase name for HTML elements in HTML documents

    // Update special cached attributes
    if (std.mem.eql(u8, name, "id")) {
        internal.id.deinit(internal.allocator);
        internal.id = try runtime.DOMString.initDupe(internal.allocator, val);
    } else if (std.mem.eql(u8, name, "class")) {
        internal.class_name.deinit(internal.allocator);
        internal.class_name = try runtime.DOMString.initDupe(internal.allocator, val);
    } else if (std.mem.eql(u8, name, "slot")) {
        internal.slot.deinit(internal.allocator);
        internal.slot = try runtime.DOMString.initDupe(internal.allocator, val);
    }

    // Set in attribute list
    try setAttributeInternal(internal, null, null, name, val);
}

/// Operation: insertAdjacentHTML
pub fn call_insertAdjacentHTML(instance: *runtime.Instance, position: runtime.DOMString, string: *const anyopaque) ImplError!void {
    _ = instance;
    _ = position;
    _ = string;
    return error.NotImplemented;
}

/// Operation: checkVisibility
pub fn call_checkVisibility(instance: *runtime.Instance, options: dictionaries.CheckVisibilityOptions) ImplError!bool {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: getAttributeNames
pub fn call_getAttributeNames(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: attachShadow
pub fn call_attachShadow(instance: *runtime.Instance, init_data: dictionaries.ShadowRootInit) ImplError!*runtime.Instance {
    _ = instance;
    _ = init_data;
    return error.NotImplemented;
}

/// Operation: requestPointerLock
pub fn call_requestPointerLock(instance: *runtime.Instance, options: dictionaries.PointerLockOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: hasAttributeNS
/// DOM §4.8 - Returns true if the element has an attribute with the given namespace and local name
/// Spec: https://dom.spec.whatwg.org/#dom-element-hasattributens
pub fn call_hasAttributeNS(instance: *runtime.Instance, namespace: runtime.DOMString, localName: runtime.DOMString) ImplError!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const ns_slice = namespace.asSlice();
    const name_slice = localName.asSlice();

    return getAttributeByNS(internal, if (ns_slice.len > 0) ns_slice else null, name_slice) != null;
}

/// Operation: getBoundingClientRect
pub fn call_getBoundingClientRect(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: querySelectorAll
pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: runtime.DOMString) ImplError!*runtime.Instance {
    _ = instance;
    _ = selectors;
    return error.NotImplemented;
}

/// Operation: setPointerCapture
pub fn call_setPointerCapture(instance: *runtime.Instance, pointerId: i32) ImplError!void {
    _ = instance;
    _ = pointerId;
    return error.NotImplemented;
}
