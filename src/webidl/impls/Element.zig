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
const webidl = @import("webidl");
const infra = @import("infra");
const Element = interfaces.Element;

// Import related impls
const NodeImpl = @import("Node.zig");
const AttrImpl = @import("Attr.zig");
const DOMTokenListImpl = @import("DOMTokenList.zig");
const CharacterDataImpl = @import("CharacterData.zig");
const NamedNodeMapImpl = @import("NamedNodeMap.zig");

// Import mixins for shared interface methods
const mixins = @import("mixins");
const ParentNode = mixins.ParentNode;
const NonDocumentTypeChildNode = mixins.NonDocumentTypeChildNode;
const ChildNode = mixins.ChildNode;

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

    /// Slottable mixin fields (DOM §4.3.7)
    /// The slot this element is assigned to (null if not in a shadow tree or unassigned)
    assigned_slot: ?*runtime.Instance = null,

    /// Manual slot assignment (for SlotAssignmentMode.manual)
    manual_slot_assignment: ?*runtime.Instance = null,

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
    return getInternalFromRegistry(instance);
}

/// Get the Node internal state from an Element instance
/// Uses the registry pattern for proper inheritance chain
pub fn getNodeInternal(instance: *runtime.Instance) ?*NodeImpl.InternalState {
    return NodeImpl.getInternalState(instance);
}

/// Initialize instance (creates the instance)
/// Chains to parent class initialization: Node -> EventTarget
///
/// IMPORTANT: Due to state hierarchy complexity, internal state is stored
/// in a global registry rather than in the State struct.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain to parent class (Node) which chains to EventTarget
    const instance = try NodeImpl.init(allocator, StateType, vtable, ctx);
    errdefer NodeImpl.deinit(instance);

    // Set node type to ELEMENT_NODE
    try NodeImpl.setNodeType(instance, NodeImpl.NodeType.ELEMENT_NODE);

    // Initialize Element's own internal state in registry
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    try setInternalInRegistry(instance, internal);

    return instance;
}

/// Global registry for Element internal state
var element_registry: std.AutoHashMap(usize, *InternalState) = undefined;
var element_registry_initialized: bool = false;

fn ensureElementRegistry() void {
    if (!element_registry_initialized) {
        element_registry = std.AutoHashMap(usize, *InternalState).init(std.heap.page_allocator);
        element_registry_initialized = true;
    }
}

fn setInternalInRegistry(instance: *runtime.Instance, internal: *InternalState) !void {
    ensureElementRegistry();
    try element_registry.put(@intFromPtr(instance), internal);
}

fn getInternalFromRegistry(instance: *runtime.Instance) ?*InternalState {
    ensureElementRegistry();
    return element_registry.get(@intFromPtr(instance));
}

/// Get Element's internal state from the registry
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return getInternalFromRegistry(instance);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up from registry
    ensureElementRegistry();
    if (element_registry.get(@intFromPtr(instance))) |internal| {
        internal.deinit();
    }
    _ = element_registry.remove(@intFromPtr(instance));
    // Node cleanup happens via inheritance chain
    NodeImpl.deinit(instance);
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
pub fn get_namespaceURI(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.namespace_uri) |ns| {
        return ns;
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for prefix
/// DOM §4.8 - Returns the namespace prefix of this element
pub fn get_prefix(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.prefix) |p| {
        return p;
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for localName
/// DOM §4.8 - Returns the local name of this element
pub fn get_localName(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.local_name;
}

/// Getter for tagName
/// DOM §4.8 - Returns the qualified name of this element
/// For HTML elements in HTML documents, this is uppercase
pub fn get_tagName(instance: *runtime.Instance) anyerror!runtime.DOMString {
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
pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.id;
}

/// Getter for className
/// DOM §4.8 - Returns the value of the class attribute
pub fn get_className(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.class_name;
}

/// Getter for classList
/// DOM §4.8 - Returns a DOMTokenList for the class attribute
/// Spec: https://dom.spec.whatwg.org/#dom-element-classlist
///
/// The classList getter steps are to return a DOMTokenList object whose
/// associated element is this and whose associated attribute's local name is class.
pub fn get_classList(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Create a new DOMTokenList
    // Use interface instead of impl (per Golden Rule #13)
    const token_list = interfaces.DOMTokenList.init(internal.allocator, instance.ctx) catch return error.OutOfMemory;
    errdefer interfaces.DOMTokenList.deinit(token_list);

    // Initialize with current class attribute value
    interfaces.DOMTokenList.set_value(token_list, internal.class_name) catch return error.OutOfMemory;

    // Associate with this element and the "class" attribute
    DOMTokenListImpl.setElement(token_list, instance, runtime.DOMString.initInterned("class"));

    return token_list;
}

/// Getter for slot
/// DOM §4.8 - Returns the value of the slot attribute
pub fn get_slot(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.slot;
}

/// Getter for attributes
/// DOM §4.8 - Returns a NamedNodeMap of the element's attributes
/// Spec: https://dom.spec.whatwg.org/#dom-element-attributes
///
/// The attributes getter steps are to return the associated NamedNodeMap.
pub fn get_attributes(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Create a NamedNodeMap containing all attributes
    // Use interface instead of impl (per Golden Rule #13)
    const named_node_map = interfaces.NamedNodeMap.init(internal.allocator, instance.ctx) catch return error.OutOfMemory;
    errdefer interfaces.NamedNodeMap.deinit(named_node_map);

    // Set the owner element
    NamedNodeMapImpl.setOwnerElement(named_node_map, instance);

    // Add all attributes to the NamedNodeMap
    for (internal.attributes.items) |entry| {
        // Create an Attr node for each attribute entry
        const attr = AttrImpl.createAttr(
            internal.allocator,
            instance.ctx,
            entry.namespace_uri,
            entry.prefix,
            entry.local_name,
            entry.value,
        ) catch return error.OutOfMemory;

        // Set owner element on the attr
        AttrImpl.setOwnerElement(attr, instance) catch {};

        // Add to NamedNodeMap
        NamedNodeMapImpl.addAttr(named_node_map, attr) catch return error.OutOfMemory;
    }

    return named_node_map;
}

/// Getter for shadowRoot
/// DOM §4.8 - Returns the element's shadow root if attached and mode is "open"
/// Spec: https://dom.spec.whatwg.org/#dom-element-shadowroot
///
/// The shadowRoot getter steps are:
/// 1. Let shadow be this's shadow root.
/// 2. If shadow is null or its mode is "closed", then return null.
/// 3. Return shadow.
pub fn get_shadowRoot(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: Let shadow be this's shadow root
    const shadow = internal.shadow_root orelse return null;

    // Step 2: If shadow's mode is "closed", return null
    // Use interface instead of impl (per Golden Rule #13)
    const mode = interfaces.ShadowRoot.get_mode(shadow) catch return null;

    // Check if mode is closed
    if (mode == ._closed_) {
        return null;
    }

    // Step 3: Return shadow
    return shadow;
}

/// Getter for customElementRegistry
/// HTML §4.13.3 - Returns the element's associated custom element registry
/// Spec: https://html.spec.whatwg.org/#dom-element-customelementregistry
///
/// Note: Returns null until Custom Element Registry is implemented.
/// This is acceptable as custom elements are an optional feature.
pub fn get_customElementRegistry(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    // Custom Element Registry not implemented - return null
    return null;
}

/// Getter for onfullscreenchange
/// Fullscreen API - Event handler for fullscreen changes
/// Spec: https://fullscreen.spec.whatwg.org/#handler-document-onfullscreenchange
///
/// Note: Returns null - fullscreen API requires browser integration.
pub fn get_onfullscreenchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    // Return null event handler (no fullscreen support without browser)
    return null;
}

/// Getter for onfullscreenerror
/// Fullscreen API - Event handler for fullscreen errors
/// Spec: https://fullscreen.spec.whatwg.org/#handler-document-onfullscreenerror
///
/// Note: Returns null - fullscreen API requires browser integration.
pub fn get_onfullscreenerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    // Return null event handler (no fullscreen support without browser)
    return null;
}

/// Getter for elementTiming
/// Element Timing API - Returns the value of the elementtiming attribute
/// Spec: https://wicg.github.io/element-timing/#dom-element-elementtiming
///
/// The elementTiming getter returns the value of the elementtiming content attribute.
pub fn get_elementTiming(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Look for elementtiming attribute
    for (internal.attributes.items) |entry| {
        if (entry.namespace_uri == null and std.mem.eql(u8, entry.local_name, "elementtiming")) {
            return runtime.DOMString.initInterned(entry.value);
        }
    }

    return runtime.DOMString.initEmpty();
}

/// Getter for part
/// CSS Shadow Parts - Returns the DOMTokenList for the part attribute
/// Spec: https://drafts.csswg.org/css-shadow-parts/#dom-element-part
///
/// The part getter returns a DOMTokenList reflecting the part attribute.
pub fn get_part(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Create a DOMTokenList for the part attribute
    // Use interface instead of impl (per Golden Rule #13)
    const token_list = interfaces.DOMTokenList.init(internal.allocator, instance.ctx) catch return error.OutOfMemory;
    errdefer interfaces.DOMTokenList.deinit(token_list);

    // Find current part attribute value
    for (internal.attributes.items) |entry| {
        if (entry.namespace_uri == null and std.mem.eql(u8, entry.local_name, "part")) {
            interfaces.DOMTokenList.set_value(token_list, runtime.DOMString.initInterned(entry.value)) catch return error.OutOfMemory;
            break;
        }
    }

    // Associate with this element and the "part" attribute (internal method)
    DOMTokenListImpl.setElement(token_list, instance, runtime.DOMString.initInterned("part"));

    return token_list;
}

/// Getter for activeViewTransition
/// View Transitions API - Returns the active ViewTransition for this element
/// Spec: https://drafts.csswg.org/css-view-transitions-2/#dom-element-activeviewtransition
///
/// Note: Returns null - View Transitions API requires rendering engine.
pub fn get_activeViewTransition(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    // View Transitions require rendering engine - return null
    return null;
}

/// Getter for innerHTML
/// DOM Parsing §3 - Returns the HTML serialization of the element's descendants
/// Spec: https://w3c.github.io/DOM-Parsing/#dom-element-innerhtml
///
/// Note: Simplified implementation - returns basic HTML structure.
/// Full implementation requires complete HTML serialization algorithm.
pub fn get_innerHTML(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Build basic HTML from child elements using infra.List
    var result = infra.List(u8).init(internal.allocator);
    errdefer result.deinit();

    // Iterate through children and serialize
    var child = NodeImpl.getFirstChild(instance);
    while (child) |c| {
        serializeNode(c, &result, internal.allocator) catch return error.OutOfMemory;
        child = NodeImpl.getNextSibling(c);
    }

    // Return as DOMString (wrapped in anyopaque for now)
    const str = internal.allocator.create(runtime.DOMString) catch return error.OutOfMemory;
    const owned = result.toOwnedSlice() catch return error.OutOfMemory;
    str.* = runtime.DOMString.initOwned(owned);
    return str.*;
}

/// Getter for outerHTML
/// DOM Parsing §3 - Returns the HTML serialization of the element including itself
/// Spec: https://w3c.github.io/DOM-Parsing/#dom-element-outerhtml
///
/// Note: Simplified implementation - returns basic HTML structure.
/// Full implementation requires complete HTML serialization algorithm.
pub fn get_outerHTML(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    var result = infra.List(u8).init(internal.allocator);
    errdefer result.deinit();

    // Serialize this element including itself
    serializeNode(instance, &result, internal.allocator) catch return error.OutOfMemory;

    // Return as DOMString
    const str = internal.allocator.create(runtime.DOMString) catch return error.OutOfMemory;
    const owned = result.toOwnedSlice() catch return error.OutOfMemory;
    str.* = runtime.DOMString.initOwned(owned);
    return str.*;
}

/// Internal helper to serialize a node to HTML
fn serializeNode(node: *runtime.Instance, result: *infra.List(u8), allocator: std.mem.Allocator) !void {
    _ = allocator;
    const node_type = NodeImpl.getNodeType(node) orelse return;

    switch (node_type) {
        NodeImpl.NodeType.ELEMENT_NODE => {
            // Get tag name
            const elem_internal = getInternal(node);
            if (elem_internal) |internal| {
                const tag = internal.local_name.asSlice();

                // Opening tag
                try result.append('<');
                try result.appendSlice(tag);

                // Attributes
                for (internal.attributes.items) |attr| {
                    try result.append(' ');
                    try result.appendSlice(attr.local_name);
                    try result.appendSlice("=\"");
                    // Escape attribute value
                    for (attr.value) |c| {
                        switch (c) {
                            '"' => try result.appendSlice("&quot;"),
                            '&' => try result.appendSlice("&amp;"),
                            else => try result.append(c),
                        }
                    }
                    try result.append('"');
                }

                try result.append('>');

                // Children
                var child = NodeImpl.getFirstChild(node);
                while (child) |c| {
                    try serializeNode(c, result, internal.allocator);
                    child = NodeImpl.getNextSibling(c);
                }

                // Closing tag (skip for void elements)
                const void_elements = [_][]const u8{ "area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr" };
                var is_void = false;
                for (void_elements) |ve| {
                    if (std.ascii.eqlIgnoreCase(tag, ve)) {
                        is_void = true;
                        break;
                    }
                }

                if (!is_void) {
                    try result.appendSlice("</");
                    try result.appendSlice(tag);
                    try result.append('>');
                }
            }
        },
        NodeImpl.NodeType.TEXT_NODE => {
            // Get text content
            const text = CharacterDataImpl.getData(node);
            if (text) |t| {
                // Escape text content
                for (t) |c| {
                    switch (c) {
                        '<' => try result.appendSlice("&lt;"),
                        '>' => try result.appendSlice("&gt;"),
                        '&' => try result.appendSlice("&amp;"),
                        else => try result.append(c),
                    }
                }
            }
        },
        NodeImpl.NodeType.COMMENT_NODE => {
            try result.appendSlice("<!--");
            const text = CharacterDataImpl.getData(node);
            if (text) |t| {
                try result.appendSlice(t);
            }
            try result.appendSlice("-->");
        },
        else => {},
    }
}

/// Getter for scrollTop
/// CSSOM View §3.1 - Returns scroll position from top
/// Returns 0 for non-rendered elements (no layout engine)
pub fn get_scrollTop(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return 0.0;
}

/// Getter for scrollLeft
/// CSSOM View §3.1 - Returns scroll position from left
/// Returns 0 for non-rendered elements (no layout engine)
pub fn get_scrollLeft(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return 0.0;
}

/// Getter for scrollWidth
/// CSSOM View §3.1 - Returns scroll width of element
/// Returns 0 for non-rendered elements (no layout engine)
pub fn get_scrollWidth(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return 0;
}

/// Getter for scrollHeight
/// CSSOM View §3.1 - Returns scroll height of element
/// Returns 0 for non-rendered elements (no layout engine)
pub fn get_scrollHeight(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return 0;
}

/// Getter for clientTop
/// CSSOM View §3.1 - Returns top border width
/// Returns 0 for non-rendered elements (no layout engine)
pub fn get_clientTop(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return 0;
}

/// Getter for clientLeft
/// CSSOM View §3.1 - Returns left border width
/// Returns 0 for non-rendered elements (no layout engine)
pub fn get_clientLeft(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return 0;
}

/// Getter for clientWidth
/// CSSOM View §3.1 - Returns inner width of element
/// Returns 0 for non-rendered elements (no layout engine)
pub fn get_clientWidth(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return 0;
}

/// Getter for clientHeight
/// CSSOM View §3.1 - Returns inner height of element
/// Returns 0 for non-rendered elements (no layout engine)
pub fn get_clientHeight(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return 0;
}

/// Getter for currentCSSZoom
/// CSSOM View - Returns current CSS zoom level
/// Returns 1.0 (no zoom) for non-rendered elements
pub fn get_currentCSSZoom(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return 1.0;
}

/// Getter for role
/// ARIAMixin - Reflects the role attribute
pub fn get_role(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "role");
}

/// Getter for ariaActiveDescendantElement
/// ARIAMixin - Element reference attribute
/// Spec: https://w3c.github.io/aria/#aria-activedescendant
///
/// Returns the element referenced by aria-activedescendant, or null if not set
pub fn get_ariaActiveDescendantElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return getAriaElementRef(instance, "aria-activedescendant");
}

/// Getter for ariaAtomic
/// ARIAMixin - Reflects the aria-atomic attribute
pub fn get_ariaAtomic(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-atomic");
}

/// Getter for ariaAutoComplete
/// ARIAMixin - Reflects the aria-autocomplete attribute
pub fn get_ariaAutoComplete(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-autocomplete");
}

/// Getter for ariaBrailleLabel
/// ARIAMixin - Reflects the aria-braillelabel attribute
pub fn get_ariaBrailleLabel(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-braillelabel");
}

/// Getter for ariaBrailleRoleDescription
/// ARIAMixin - Reflects the aria-brailleroledescription attribute
pub fn get_ariaBrailleRoleDescription(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-brailleroledescription");
}

/// Getter for ariaBusy
/// ARIAMixin - Reflects the aria-busy attribute
pub fn get_ariaBusy(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-busy");
}

/// Getter for ariaChecked
/// ARIAMixin - Reflects the aria-checked attribute
pub fn get_ariaChecked(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-checked");
}

/// Getter for ariaColCount
/// ARIAMixin - Reflects the aria-colcount attribute
pub fn get_ariaColCount(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-colcount");
}

/// Getter for ariaColIndex
/// ARIAMixin - Reflects the aria-colindex attribute
pub fn get_ariaColIndex(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-colindex");
}

/// Getter for ariaColIndexText
/// ARIAMixin - Reflects the aria-colindextext attribute
pub fn get_ariaColIndexText(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-colindextext");
}

/// Getter for ariaColSpan
/// ARIAMixin - Reflects the aria-colspan attribute
pub fn get_ariaColSpan(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-colspan");
}

/// Getter for ariaControlsElements
/// ARIAMixin - Element array reference
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariacontrolselements
///
/// Returns a frozen array of elements referenced by space-separated IDs in aria-controls.
/// Note: Returns empty array - full implementation requires FrozenArray support and ID resolution.
pub fn get_ariaControlsElements(instance: *runtime.Instance) anyerror!?*const anyopaque {
    _ = instance;
    // Return empty array sentinel - full implementation requires resolving space-separated IDs
    return @ptrFromInt(1);
}

/// Getter for ariaCurrent
/// ARIAMixin - Reflects the aria-current attribute
pub fn get_ariaCurrent(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-current");
}

/// Getter for ariaDescribedByElements
/// ARIAMixin - Element array reference
/// Spec: https://w3c.github.io/aria/#aria-describedby
///
/// Returns an array of elements referenced by space-separated IDs in aria-describedby
/// Note: Returns empty array - full implementation requires FrozenArray support
pub fn get_ariaDescribedByElements(instance: *runtime.Instance) anyerror!?*const anyopaque {
    _ = instance;
    // Return empty array sentinel - full implementation requires resolving space-separated IDs
    return @ptrFromInt(1);
}

/// Getter for ariaDescription
/// ARIAMixin - Reflects the aria-description attribute
pub fn get_ariaDescription(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-description");
}

/// Getter for ariaDetailsElements
/// ARIAMixin - Element array reference
/// Spec: https://w3c.github.io/aria/#aria-details
///
/// Returns an array of elements referenced by space-separated IDs in aria-details
/// Note: Returns empty array - full implementation requires FrozenArray support
pub fn get_ariaDetailsElements(instance: *runtime.Instance) anyerror!?*const anyopaque {
    _ = instance;
    // Return empty array sentinel - full implementation requires resolving space-separated IDs
    return @ptrFromInt(1);
}

/// Getter for ariaDisabled
/// ARIAMixin - Reflects the aria-disabled attribute
pub fn get_ariaDisabled(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-disabled");
}

/// Getter for ariaErrorMessageElements
/// ARIAMixin - Element array reference
/// Spec: https://w3c.github.io/aria/#aria-errormessage
///
/// Returns an array of elements referenced by space-separated IDs in aria-errormessage
/// Note: Returns empty array - full implementation requires FrozenArray support
pub fn get_ariaErrorMessageElements(instance: *runtime.Instance) anyerror!?*const anyopaque {
    _ = instance;
    // Return empty array sentinel
    return @ptrFromInt(1);
}

/// Getter for ariaExpanded
/// ARIAMixin - Reflects the aria-expanded attribute
pub fn get_ariaExpanded(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-expanded");
}

/// Getter for ariaFlowToElements
/// ARIAMixin - Element array reference
/// Spec: https://w3c.github.io/aria/#aria-flowto
///
/// Returns an array of elements referenced by space-separated IDs in aria-flowto.
/// Note: Returns empty array - full implementation requires FrozenArray support and ID resolution.
pub fn get_ariaFlowToElements(instance: *runtime.Instance) anyerror!?*const anyopaque {
    _ = instance;
    // Return empty array sentinel - full implementation requires resolving space-separated IDs
    return @ptrFromInt(1);
}

/// Getter for ariaHasPopup
/// ARIAMixin - Reflects the aria-haspopup attribute
pub fn get_ariaHasPopup(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-haspopup");
}

/// Getter for ariaHidden
/// ARIAMixin - Reflects the aria-hidden attribute
pub fn get_ariaHidden(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-hidden");
}

/// Getter for ariaInvalid
/// ARIAMixin - Reflects the aria-invalid attribute
pub fn get_ariaInvalid(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-invalid");
}

/// Getter for ariaKeyShortcuts
/// ARIAMixin - Reflects the aria-keyshortcuts attribute
pub fn get_ariaKeyShortcuts(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-keyshortcuts");
}

/// Getter for ariaLabel
/// ARIAMixin - Reflects the aria-label attribute
pub fn get_ariaLabel(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-label");
}

/// Getter for ariaLabelledByElements
/// ARIAMixin - Element array reference
/// Spec: https://w3c.github.io/aria/#aria-labelledby
///
/// Returns an array of elements referenced by space-separated IDs in aria-labelledby.
/// Note: Returns empty array - full implementation requires FrozenArray support and ID resolution.
pub fn get_ariaLabelledByElements(instance: *runtime.Instance) anyerror!?*const anyopaque {
    _ = instance;
    // Return empty array sentinel - full implementation requires resolving space-separated IDs
    return @ptrFromInt(1);
}

/// Getter for ariaLevel
/// ARIAMixin - Reflects the aria-level attribute
pub fn get_ariaLevel(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-level");
}

/// Getter for ariaLive
/// ARIAMixin - Reflects the aria-live attribute
pub fn get_ariaLive(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-live");
}

/// Getter for ariaModal
/// ARIAMixin - Reflects the aria-modal attribute
pub fn get_ariaModal(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-modal");
}

/// Getter for ariaMultiLine
/// ARIAMixin - Reflects the aria-multiline attribute
pub fn get_ariaMultiLine(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-multiline");
}

/// Getter for ariaMultiSelectable
/// ARIAMixin - Reflects the aria-multiselectable attribute
pub fn get_ariaMultiSelectable(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-multiselectable");
}

/// Getter for ariaOrientation
/// ARIAMixin - Reflects the aria-orientation attribute
pub fn get_ariaOrientation(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-orientation");
}

/// Getter for ariaOwnsElements
/// ARIAMixin - Element array reference
/// Spec: https://w3c.github.io/aria/#aria-owns
///
/// Returns an array of elements referenced by space-separated IDs in aria-owns.
/// Note: Returns empty array - full implementation requires FrozenArray support and ID resolution.
pub fn get_ariaOwnsElements(instance: *runtime.Instance) anyerror!?*const anyopaque {
    _ = instance;
    // Return empty array sentinel - full implementation requires resolving space-separated IDs
    return @ptrFromInt(1);
}

/// Getter for ariaPlaceholder
/// ARIAMixin - Reflects the aria-placeholder attribute
pub fn get_ariaPlaceholder(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-placeholder");
}

/// Getter for ariaPosInSet
/// ARIAMixin - Reflects the aria-posinset attribute
pub fn get_ariaPosInSet(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-posinset");
}

/// Getter for ariaPressed
/// ARIAMixin - Reflects the aria-pressed attribute
pub fn get_ariaPressed(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-pressed");
}

/// Getter for ariaReadOnly
/// ARIAMixin - Reflects the aria-readonly attribute
pub fn get_ariaReadOnly(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-readonly");
}

/// Getter for ariaRelevant
/// ARIAMixin - Reflects the aria-relevant attribute
pub fn get_ariaRelevant(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-relevant");
}

/// Getter for ariaRequired
/// ARIAMixin - Reflects the aria-required attribute
pub fn get_ariaRequired(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-required");
}

/// Getter for ariaRoleDescription
/// ARIAMixin - Reflects the aria-roledescription attribute
pub fn get_ariaRoleDescription(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-roledescription");
}

/// Getter for ariaRowCount
/// ARIAMixin - Reflects the aria-rowcount attribute
pub fn get_ariaRowCount(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-rowcount");
}

/// Getter for ariaRowIndex
/// ARIAMixin - Reflects the aria-rowindex attribute
pub fn get_ariaRowIndex(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-rowindex");
}

/// Getter for ariaRowIndexText
/// ARIAMixin - Reflects the aria-rowindextext attribute
pub fn get_ariaRowIndexText(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-rowindextext");
}

/// Getter for ariaRowSpan
/// ARIAMixin - Reflects the aria-rowspan attribute
pub fn get_ariaRowSpan(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-rowspan");
}

/// Getter for ariaSelected
/// ARIAMixin - Reflects the aria-selected attribute
pub fn get_ariaSelected(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-selected");
}

/// Getter for ariaSetSize
/// ARIAMixin - Reflects the aria-setsize attribute
pub fn get_ariaSetSize(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-setsize");
}

/// Getter for ariaSort
/// ARIAMixin - Reflects the aria-sort attribute
pub fn get_ariaSort(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-sort");
}

/// Getter for ariaValueMax
/// ARIAMixin - Reflects the aria-valuemax attribute
pub fn get_ariaValueMax(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-valuemax");
}

/// Getter for ariaValueMin
/// ARIAMixin - Reflects the aria-valuemin attribute
pub fn get_ariaValueMin(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-valuemin");
}

/// Getter for ariaValueNow
/// ARIAMixin - Reflects the aria-valuenow attribute
pub fn get_ariaValueNow(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-valuenow");
}

/// Getter for ariaValueText
/// ARIAMixin - Reflects the aria-valuetext attribute
pub fn get_ariaValueText(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-valuetext");
}

/// Getter for regionOverset
/// CSS Regions §10.2 - Returns the region's overset state
/// Spec: https://drafts.csswg.org/css-regions-1/#dom-region-regionoverset
///
/// Note: CSS Regions is deprecated/removed from most browsers.
/// Returns empty string as no region flow is active.
pub fn get_regionOverset(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    _ = instance;
    // CSS Regions not supported - return empty string
    return .{ .empty = {} };
}

/// Getter for children
/// ParentNode mixin - Returns an HTMLCollection of child elements
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-children
pub fn get_children(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return ParentNode.children(internal.allocator, instance, instance.ctx) catch |err| {
        return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            else => error.NotImplemented,
        };
    };
}

/// Getter for firstElementChild
/// ParentNode mixin - Returns the first child that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-firstelementchild
pub fn get_firstElementChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return ParentNode.firstElementChild(instance);
}

/// Getter for lastElementChild
/// ParentNode mixin - Returns the last child that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-lastelementchild
pub fn get_lastElementChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return ParentNode.lastElementChild(instance);
}

/// Getter for childElementCount
/// ParentNode mixin - Returns the number of child elements
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-childelementcount
pub fn get_childElementCount(instance: *runtime.Instance) anyerror!u32 {
    return ParentNode.childElementCount(instance);
}

/// Getter for previousElementSibling
/// NonDocumentTypeChildNode mixin - Returns the previous sibling that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-nondocumenttypechildnode-previouselementsibling
pub fn get_previousElementSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return NonDocumentTypeChildNode.previousElementSibling(instance);
}

/// Getter for nextElementSibling
/// NonDocumentTypeChildNode mixin - Returns the next sibling that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-nondocumenttypechildnode-nextelementsibling
pub fn get_nextElementSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return NonDocumentTypeChildNode.nextElementSibling(instance);
}

/// Getter for assignedSlot
/// Slottable mixin - Returns the slot this element is assigned to
/// Spec: https://dom.spec.whatwg.org/#dom-slottable-assignedslot
///
/// The assignedSlot getter steps are to return the result of find a slot
/// given this and with the open flag set.
///
/// Returns null if:
/// - Element is not assigned to any slot
/// - Element is assigned to a slot in a closed shadow root
pub fn get_assignedSlot(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Get the assigned slot
    const slot = internal.assigned_slot orelse return null;

    // Check if the slot's shadow root is open (per spec, only return for open mode)
    // The slot is an HTMLSlotElement which is in a ShadowRoot
    // We need to check if that shadow root has mode = "open"

    // Get the slot's parent/root to check if it's in an open shadow root
    // For now, return the slot if it exists - full implementation would
    // walk up to find the shadow root and check its mode
    // TODO: Implement full "find a slot" algorithm with open flag check

    return slot;
}

/// Setter for id
/// DOM §4.8 - Sets the id attribute value
pub fn set_id(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
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
pub fn set_className(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
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
pub fn set_slot(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
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

// Note: matches(), closest(), and webkitMatchesSelector() delegate to ParentNode mixin
// which has access to the selector module. Element.zig cannot access selector directly.

// =============================================================================
// Insert Adjacent Algorithm (DOM §4.10.7)
// =============================================================================

/// InsertAdjacent error type
const InsertAdjacentError = error{
    SyntaxError,
    InvalidStateError,
};

/// Insert adjacent algorithm - shared by insertAdjacentElement and insertAdjacentText
/// Spec: https://dom.spec.whatwg.org/#insert-adjacent
///
/// To insert adjacent, given an element element, string where, and a node node:
/// 1. If where is "beforebegin": If element's parent is null, return null.
///    Otherwise, return pre-insert node into element's parent before element.
/// 2. If where is "afterbegin": Return pre-insert node into element before element's first child.
/// 3. If where is "beforeend": Return pre-insert node into element before null.
/// 4. If where is "afterend": If element's parent is null, return null.
///    Otherwise, return pre-insert node into element's parent before element's next sibling.
/// 5. Otherwise: Throw a "SyntaxError" DOMException.
fn insertAdjacent(
    element: *runtime.Instance,
    where: []const u8,
    node: *runtime.Instance,
) InsertAdjacentError!?*runtime.Instance {
    // Case-insensitive comparison per spec
    if (std.ascii.eqlIgnoreCase(where, "beforebegin")) {
        // Insert before this element (requires parent)
        const parent = NodeImpl.getParent(element) orelse return null;

        // Insert node into parent before element
        _ = interfaces.Node.call_insertBefore(parent, node, element) catch {
            return error.InvalidStateError;
        };
        return node;
    } else if (std.ascii.eqlIgnoreCase(where, "afterbegin")) {
        // Insert as first child of this element
        const first_child = NodeImpl.getFirstChild(element);

        if (first_child) |fc| {
            _ = interfaces.Node.call_insertBefore(element, node, fc) catch {
                return error.InvalidStateError;
            };
        } else {
            _ = interfaces.Node.call_appendChild(element, node) catch {
                return error.InvalidStateError;
            };
        }
        return node;
    } else if (std.ascii.eqlIgnoreCase(where, "beforeend")) {
        // Insert as last child of this element
        _ = interfaces.Node.call_appendChild(element, node) catch {
            return error.InvalidStateError;
        };
        return node;
    } else if (std.ascii.eqlIgnoreCase(where, "afterend")) {
        // Insert after this element (requires parent)
        const parent = NodeImpl.getParent(element) orelse return null;
        const next_sibling = NodeImpl.getNextSibling(element);

        if (next_sibling) |ns| {
            _ = interfaces.Node.call_insertBefore(parent, node, ns) catch {
                return error.InvalidStateError;
            };
        } else {
            _ = interfaces.Node.call_appendChild(parent, node) catch {
                return error.InvalidStateError;
            };
        }
        return node;
    } else {
        // Invalid position - throw SyntaxError
        return error.SyntaxError;
    }
}

// =============================================================================
// ARIA Attribute Helpers
// =============================================================================

/// Get an ARIA attribute value (reflects aria-* attributes)
fn getAriaAttribute(instance: *runtime.Instance, aria_name: []const u8) runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();

    // Look for aria-* attribute
    for (internal.attributes.items) |entry| {
        if (entry.namespace_uri == null and std.mem.eql(u8, entry.local_name, aria_name)) {
            return runtime.DOMString.initInterned(entry.value);
        }
    }

    return runtime.DOMString.initEmpty();
}

/// Set an ARIA attribute value
fn setAriaAttribute(instance: *runtime.Instance, aria_name: []const u8, value: runtime.DOMString) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try setAttributeInternal(internal, null, null, aria_name, value.asSlice());
}

/// Get an element by ID from the owner document (for ARIA element reference attributes)
/// Returns null if the element is not connected to a document or the ID is not found
fn getElementByIdFromDocument(instance: *runtime.Instance, id: []const u8) ?*runtime.Instance {
    if (id.len == 0) return null;

    // Get the owner document (nullable return type now)
    const owner_doc_opt = interfaces.Node.get_ownerDocument(instance) catch return null;
    const owner_doc = owner_doc_opt orelse return null;

    // Use document's getElementById
    // Use interface instead of impl (per Golden Rule #13)
    const result = interfaces.Document.call_getElementById(owner_doc, runtime.DOMString.initInterned(id)) catch return null;
    return result;
}

/// Get an ARIA element reference attribute (single element)
/// These attributes contain an ID reference that needs to be resolved to an element
fn getAriaElementRef(instance: *runtime.Instance, aria_attr: []const u8) ?*runtime.Instance {
    // Get the attribute value (contains an ID)
    const attr_value = getAriaAttribute(instance, aria_attr);
    const id = attr_value.asSlice();
    if (id.len == 0) return null;

    return getElementByIdFromDocument(instance, id);
}

/// Set an ARIA element reference attribute
/// Takes an element and stores its ID as the attribute value
fn setAriaElementRef(instance: *runtime.Instance, aria_attr: []const u8, element: ?*runtime.Instance) ImplError!void {
    if (element) |elem| {
        // Get the element's ID
        if (getInternal(elem)) |elem_internal| {
            const elem_id = elem_internal.id.asSlice();
            if (elem_id.len > 0) {
                // Set the ARIA attribute to the element's ID
                return setAriaAttribute(instance, aria_attr, runtime.DOMString.initInterned(elem_id));
            }
        }
    }
    // Element is null or has no ID - remove the attribute
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    removeAttributeByName(internal, aria_attr);
}

/// Remove an attribute by name (helper for ARIA element ref setters)
fn removeAttributeByName(internal: *InternalState, name: []const u8) void {
    var i: usize = 0;
    while (i < internal.attributes.items.len) {
        const entry = internal.attributes.items[i];
        if (entry.namespace_uri == null and std.mem.eql(u8, entry.local_name, name)) {
            // Free the entry's strings
            if (entry.namespace_uri) |ns| internal.allocator.free(ns);
            if (entry.prefix) |p| internal.allocator.free(p);
            internal.allocator.free(entry.local_name);
            internal.allocator.free(entry.value);
            _ = internal.attributes.orderedRemove(i);
            return;
        }
        i += 1;
    }
}

// =============================================================================
// Tree Traversal Helpers for getElementsBy* methods
// =============================================================================

/// Collect descendants matching tag name (tree order traversal)
fn collectElementsByTagName(
    root: *runtime.Instance,
    qualified_name: []const u8,
    collection: *runtime.Instance,
) !void {
    const HTMLCollectionImpl = @import("HTMLCollection.zig");

    // Get first child
    var child = NodeImpl.getFirstChild(root);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            // Check if matches
            if (getInternal(c)) |child_internal| {
                const local_name = child_internal.local_name.asSlice();
                const matches = std.mem.eql(u8, qualified_name, "*") or
                    std.ascii.eqlIgnoreCase(local_name, qualified_name);

                if (matches) {
                    try HTMLCollectionImpl.addElement(collection, c);
                }
            }

            // Recurse into descendants
            try collectElementsByTagName(c, qualified_name, collection);
        }

        child = NodeImpl.getNextSibling(c);
    }
}

/// Collect descendants matching namespace and local name (tree order traversal)
fn collectElementsByTagNameNS(
    root: *runtime.Instance,
    namespace: []const u8,
    local_name: []const u8,
    collection: *runtime.Instance,
) !void {
    const HTMLCollectionImpl = @import("HTMLCollection.zig");

    var child = NodeImpl.getFirstChild(root);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            if (getInternal(c)) |child_internal| {
                // Check namespace match ("*" matches any)
                const ns_matches = std.mem.eql(u8, namespace, "*") or blk: {
                    if (child_internal.namespace_uri) |ns| {
                        break :blk std.mem.eql(u8, ns.asSlice(), namespace);
                    }
                    break :blk namespace.len == 0;
                };

                // Check local name match ("*" matches any)
                const name_matches = std.mem.eql(u8, local_name, "*") or
                    std.mem.eql(u8, child_internal.local_name.asSlice(), local_name);

                if (ns_matches and name_matches) {
                    try HTMLCollectionImpl.addElement(collection, c);
                }
            }

            // Recurse into descendants
            try collectElementsByTagNameNS(c, namespace, local_name, collection);
        }

        child = NodeImpl.getNextSibling(c);
    }
}

/// Collect descendants with all specified class names (tree order traversal)
fn collectElementsByClassName(
    root: *runtime.Instance,
    class_names: []const u8,
    collection: *runtime.Instance,
) !void {
    const HTMLCollectionImpl = @import("HTMLCollection.zig");

    var child = NodeImpl.getFirstChild(root);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            if (getInternal(c)) |child_internal| {
                const class_attr = child_internal.class_name.asSlice();

                // Check if element has ALL required classes
                var all_found = true;
                var required_iter = std.mem.tokenizeScalar(u8, class_names, ' ');
                while (required_iter.next()) |required_class| {
                    if (required_class.len == 0) continue;

                    var found = false;
                    var elem_iter = std.mem.tokenizeScalar(u8, class_attr, ' ');
                    while (elem_iter.next()) |elem_class| {
                        if (std.mem.eql(u8, elem_class, required_class)) {
                            found = true;
                            break;
                        }
                    }
                    if (!found) {
                        all_found = false;
                        break;
                    }
                }

                if (all_found and class_names.len > 0) {
                    try HTMLCollectionImpl.addElement(collection, c);
                }
            }

            // Recurse into descendants
            try collectElementsByClassName(c, class_names, collection);
        }

        child = NodeImpl.getNextSibling(c);
    }
}

/// Setter for onfullscreenchange
/// Fullscreen API - Sets the event handler for fullscreen changes
/// Spec: https://fullscreen.spec.whatwg.org/#handler-document-onfullscreenchange
///
/// Note: No-op without fullscreen API support
pub fn set_onfullscreenchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - fullscreen API requires browser integration
}

/// Setter for onfullscreenerror
/// Fullscreen API - Sets the event handler for fullscreen errors
/// Spec: https://fullscreen.spec.whatwg.org/#handler-document-onfullscreenerror
///
/// Note: No-op without fullscreen API support
pub fn set_onfullscreenerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - fullscreen API requires browser integration
}

/// Setter for elementTiming
/// Element Timing API - Sets the elementtiming attribute value
/// Spec: https://wicg.github.io/element-timing/#sec-modifications-dom
///
/// Sets the element's timing identifier for performance monitoring
pub fn set_elementTiming(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // Set the elementtiming attribute
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const value_slice = value.asSlice();

    // Find or create the elementtiming attribute
    for (internal.attributes.items) |*entry| {
        if (entry.namespace_uri == null and std.mem.eql(u8, entry.local_name, "elementtiming")) {
            // Update existing attribute
            internal.allocator.free(entry.value);
            entry.value = internal.allocator.dupe(u8, value_slice) catch return error.OutOfMemory;
            return;
        }
    }

    // Create new attribute
    internal.attributes.append(internal.allocator, .{
        .namespace_uri = null,
        .prefix = null,
        .local_name = internal.allocator.dupe(u8, "elementtiming") catch return error.OutOfMemory,
        .value = internal.allocator.dupe(u8, value_slice) catch return error.OutOfMemory,
    }) catch return error.OutOfMemory;
}

/// Setter for innerHTML
/// DOM Parsing §3.2 - Sets the element's inner HTML
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#the-innerhtml-property
///
/// Steps:
/// 1. Parse the string using the HTML fragment parsing algorithm
/// 2. Remove all children from this element
/// 3. Append parsed nodes to this element
///
/// HTML Standard - Sets the innerHTML of this element
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#the-innerhtml-property
///
/// Steps:
/// 1. Let context element be this (the element)
/// 2. Parse the string using the HTML fragment parsing algorithm with context
/// 3. Replace all children of context with the parsed nodes
pub fn set_innerHTML(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const html_string = value.asSlice();

    // Import HTMLParser for fragment parsing
    const HTMLParser = @import("HTMLParser.zig");

    // Step 1: Remove all existing children
    // Walk through children and remove them
    var child = NodeImpl.getFirstChild(instance);
    while (child) |c| {
        const next = NodeImpl.getNextSibling(c);
        // Remove child from parent
        _ = interfaces.Node.call_removeChild(instance, c) catch break;
        child = next;
    }

    // Step 2: If value is empty string, we're done
    if (html_string.len == 0) {
        return;
    }

    // Step 3: Parse the HTML fragment using this element as context
    const fragment = HTMLParser.parseFragment(
        internal.allocator,
        instance.ctx,
        html_string,
        instance,
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.NotSupportedError,
    };

    // Step 4: Move all children from fragment to this element
    var fragment_child = NodeImpl.getFirstChild(fragment);
    while (fragment_child) |fc| {
        const next = NodeImpl.getNextSibling(fc);
        // Remove from fragment
        _ = interfaces.Node.call_removeChild(fragment, fc) catch break;
        // Append to this element
        _ = NodeImpl.appendChild(instance, fc) catch break;
        fragment_child = next;
    }

    // Clean up the fragment (children have been moved)
    interfaces.DocumentFragment.deinit(fragment);
}

/// Setter for outerHTML
/// DOM Parsing §3.2 - Replaces the element with parsed HTML
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#the-outerhtml-property
///
/// Steps:
/// 1. Let parent be this element's parent
/// 2. If parent is null, return
/// 3. If parent is a Document, throw a NoModificationAllowedError
/// 4. Parse the string using the HTML fragment parsing algorithm with parent as context
/// 5. Replace this element with the parsed nodes
pub fn set_outerHTML(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const html_string = value.asSlice();

    // Step 1-2: Get parent, return if null
    const parent = NodeImpl.getParent(instance) orelse return;

    // Step 3: Check if parent is a Document (not allowed)
    const parent_type = NodeImpl.getNodeType(parent) orelse return error.InvalidStateError;
    if (parent_type == NodeImpl.NodeType.DOCUMENT_NODE) {
        return error.HierarchyRequestError;
    }

    // Import HTMLParser for fragment parsing
    const HTMLParser = @import("HTMLParser.zig");

    // Step 4: Parse the HTML fragment using parent as context
    const fragment = HTMLParser.parseFragment(
        internal.allocator,
        instance.ctx,
        html_string,
        parent,
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.NotSupportedError,
    };

    // Step 5: Replace this element with the parsed nodes
    // Insert all children from fragment before this element, then remove this element
    var fragment_child = NodeImpl.getFirstChild(fragment);
    while (fragment_child) |fc| {
        const next = NodeImpl.getNextSibling(fc);
        // Remove from fragment
        _ = interfaces.Node.call_removeChild(fragment, fc) catch break;
        // Insert before this element
        _ = interfaces.Node.call_insertBefore(parent, fc, instance) catch break;
        fragment_child = next;
    }

    // Remove this element from parent
    _ = interfaces.Node.call_removeChild(parent, instance) catch {};

    // Clean up the fragment
    interfaces.DocumentFragment.deinit(fragment);
}

/// Setter for scrollTop
/// CSSOM View §3.1 - Sets scroll position from top
/// No-op for non-rendered elements (no layout engine)
pub fn set_scrollTop(instance: *runtime.Instance, value: f64) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would require layout engine to scroll
}

/// Setter for scrollLeft
/// CSSOM View §3.1 - Sets scroll position from left
/// No-op for non-rendered elements (no layout engine)
pub fn set_scrollLeft(instance: *runtime.Instance, value: f64) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would require layout engine to scroll
}

/// Setter for role
/// ARIAMixin - Sets the role attribute
pub fn set_role(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "role", value);
}

/// Setter for ariaActiveDescendantElement
/// ARIAMixin - Element reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariaactivedescendantelement
///
/// Sets the element that is the active descendant. This should set
/// aria-activedescendant to the target element's ID.
/// Note: No-op - full implementation requires getting target element's ID
/// and setting aria-activedescendant attribute.
pub fn set_ariaActiveDescendantElement(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to get value's ID and set aria-activedescendant
    // Full implementation requires: get ID from value element, set attribute
}

/// Setter for ariaAtomic
/// ARIAMixin - Sets the aria-atomic attribute
pub fn set_ariaAtomic(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-atomic", value);
}

/// Setter for ariaAutoComplete
/// ARIAMixin - Sets the aria-autocomplete attribute
pub fn set_ariaAutoComplete(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-autocomplete", value);
}

/// Setter for ariaBrailleLabel
/// ARIAMixin - Sets the aria-braillelabel attribute
pub fn set_ariaBrailleLabel(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-braillelabel", value);
}

/// Setter for ariaBrailleRoleDescription
/// ARIAMixin - Sets the aria-brailleroledescription attribute
pub fn set_ariaBrailleRoleDescription(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-brailleroledescription", value);
}

/// Setter for ariaBusy
/// ARIAMixin - Sets the aria-busy attribute
pub fn set_ariaBusy(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-busy", value);
}

/// Setter for ariaChecked
/// ARIAMixin - Sets the aria-checked attribute
pub fn set_ariaChecked(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-checked", value);
}

/// Setter for ariaColCount
/// ARIAMixin - Sets the aria-colcount attribute
pub fn set_ariaColCount(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-colcount", value);
}

/// Setter for ariaColIndex
/// ARIAMixin - Sets the aria-colindex attribute
pub fn set_ariaColIndex(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-colindex", value);
}

/// Setter for ariaColIndexText
/// ARIAMixin - Sets the aria-colindextext attribute
pub fn set_ariaColIndexText(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-colindextext", value);
}

/// Setter for ariaColSpan
/// ARIAMixin - Sets the aria-colspan attribute
pub fn set_ariaColSpan(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-colspan", value);
}

/// Setter for ariaControlsElements
/// ARIAMixin - Element array reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariacontrolselements
///
/// Sets the elements that this element controls. This should set
/// aria-controls to space-separated IDs of the target elements.
/// Note: No-op - full implementation requires FrozenArray handling and ID extraction.
pub fn set_ariaControlsElements(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to extract IDs from elements and set aria-controls
}

/// Setter for ariaCurrent
/// ARIAMixin - Sets the aria-current attribute
pub fn set_ariaCurrent(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-current", value);
}

/// Setter for ariaDescribedByElements
/// ARIAMixin - Element array reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariadescribedbyelements
///
/// Sets the elements that describe this element. This should set
/// aria-describedby to space-separated IDs of the target elements.
/// Note: No-op - full implementation requires FrozenArray handling and ID extraction.
pub fn set_ariaDescribedByElements(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to extract IDs from elements and set aria-describedby
}

/// Setter for ariaDescription
/// ARIAMixin - Sets the aria-description attribute
pub fn set_ariaDescription(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-description", value);
}

/// Setter for ariaDetailsElements
/// ARIAMixin - Element array reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariadetailselements
///
/// Sets the elements that provide details for this element. This should set
/// aria-details to space-separated IDs of the target elements.
/// Note: No-op - full implementation requires FrozenArray handling and ID extraction.
pub fn set_ariaDetailsElements(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to extract IDs from elements and set aria-details
}

/// Setter for ariaDisabled
/// ARIAMixin - Sets the aria-disabled attribute
pub fn set_ariaDisabled(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-disabled", value);
}

/// Setter for ariaErrorMessageElements
/// ARIAMixin - Element array reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariaerrormessageelements
///
/// Sets the elements that contain error messages for this element. This should set
/// aria-errormessage to space-separated IDs of the target elements.
/// Note: No-op - full implementation requires FrozenArray handling and ID extraction.
pub fn set_ariaErrorMessageElements(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to extract IDs from elements and set aria-errormessage
}

/// Setter for ariaExpanded
/// ARIAMixin - Sets the aria-expanded attribute
pub fn set_ariaExpanded(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-expanded", value);
}

/// Setter for ariaFlowToElements
/// ARIAMixin - Element array reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariaflowtoelements
///
/// Sets the elements that are the next in reading order. This should set
/// aria-flowto to space-separated IDs of the target elements.
/// Note: No-op - full implementation requires FrozenArray handling and ID extraction.
pub fn set_ariaFlowToElements(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to extract IDs from elements and set aria-flowto
}

/// Setter for ariaHasPopup
/// ARIAMixin - Sets the aria-haspopup attribute
pub fn set_ariaHasPopup(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-haspopup", value);
}

/// Setter for ariaHidden
/// ARIAMixin - Sets the aria-hidden attribute
pub fn set_ariaHidden(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-hidden", value);
}

/// Setter for ariaInvalid
/// ARIAMixin - Sets the aria-invalid attribute
pub fn set_ariaInvalid(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-invalid", value);
}

/// Setter for ariaKeyShortcuts
/// ARIAMixin - Sets the aria-keyshortcuts attribute
pub fn set_ariaKeyShortcuts(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-keyshortcuts", value);
}

/// Setter for ariaLabel
/// ARIAMixin - Sets the aria-label attribute
pub fn set_ariaLabel(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-label", value);
}

/// Setter for ariaLabelledByElements
/// ARIAMixin - Element array reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-arialabelledbyelements
///
/// Sets the elements that label this element. This should set
/// aria-labelledby to space-separated IDs of the target elements.
/// Note: No-op - full implementation requires FrozenArray handling and ID extraction.
pub fn set_ariaLabelledByElements(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to extract IDs from elements and set aria-labelledby
}

/// Setter for ariaLevel
/// ARIAMixin - Sets the aria-level attribute
pub fn set_ariaLevel(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-level", value);
}

/// Setter for ariaLive
/// ARIAMixin - Sets the aria-live attribute
pub fn set_ariaLive(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-live", value);
}

/// Setter for ariaModal
/// ARIAMixin - Sets the aria-modal attribute
pub fn set_ariaModal(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-modal", value);
}

/// Setter for ariaMultiLine
/// ARIAMixin - Sets the aria-multiline attribute
pub fn set_ariaMultiLine(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-multiline", value);
}

/// Setter for ariaMultiSelectable
/// ARIAMixin - Sets the aria-multiselectable attribute
pub fn set_ariaMultiSelectable(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-multiselectable", value);
}

/// Setter for ariaOrientation
/// ARIAMixin - Sets the aria-orientation attribute
pub fn set_ariaOrientation(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-orientation", value);
}

/// Setter for ariaOwnsElements
/// ARIAMixin - Element array reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariaownselements
///
/// Sets the elements that are owned by this element. This should set
/// aria-owns to space-separated IDs of the target elements.
/// Note: No-op - full implementation requires FrozenArray handling and ID extraction.
pub fn set_ariaOwnsElements(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to extract IDs from elements and set aria-owns
}

/// Setter for ariaPlaceholder
/// ARIAMixin - Sets the aria-placeholder attribute
pub fn set_ariaPlaceholder(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-placeholder", value);
}

/// Setter for ariaPosInSet
/// ARIAMixin - Sets the aria-posinset attribute
pub fn set_ariaPosInSet(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-posinset", value);
}

/// Setter for ariaPressed
/// ARIAMixin - Sets the aria-pressed attribute
pub fn set_ariaPressed(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-pressed", value);
}

/// Setter for ariaReadOnly
/// ARIAMixin - Sets the aria-readonly attribute
pub fn set_ariaReadOnly(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-readonly", value);
}

/// Setter for ariaRelevant
/// ARIAMixin - Sets the aria-relevant attribute
pub fn set_ariaRelevant(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-relevant", value);
}

/// Setter for ariaRequired
/// ARIAMixin - Sets the aria-required attribute
pub fn set_ariaRequired(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-required", value);
}

/// Setter for ariaRoleDescription
/// ARIAMixin - Sets the aria-roledescription attribute
pub fn set_ariaRoleDescription(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-roledescription", value);
}

/// Setter for ariaRowCount
/// ARIAMixin - Sets the aria-rowcount attribute
pub fn set_ariaRowCount(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-rowcount", value);
}

/// Setter for ariaRowIndex
/// ARIAMixin - Sets the aria-rowindex attribute
pub fn set_ariaRowIndex(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-rowindex", value);
}

/// Setter for ariaRowIndexText
/// ARIAMixin - Sets the aria-rowindextext attribute
pub fn set_ariaRowIndexText(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-rowindextext", value);
}

/// Setter for ariaRowSpan
/// ARIAMixin - Sets the aria-rowspan attribute
pub fn set_ariaRowSpan(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-rowspan", value);
}

/// Setter for ariaSelected
/// ARIAMixin - Sets the aria-selected attribute
pub fn set_ariaSelected(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-selected", value);
}

/// Setter for ariaSetSize
/// ARIAMixin - Sets the aria-setsize attribute
pub fn set_ariaSetSize(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-setsize", value);
}

/// Setter for ariaSort
/// ARIAMixin - Sets the aria-sort attribute
pub fn set_ariaSort(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-sort", value);
}

/// Setter for ariaValueMax
/// ARIAMixin - Sets the aria-valuemax attribute
pub fn set_ariaValueMax(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-valuemax", value);
}

/// Setter for ariaValueMin
/// ARIAMixin - Sets the aria-valuemin attribute
pub fn set_ariaValueMin(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-valuemin", value);
}

/// Setter for ariaValueNow
/// ARIAMixin - Sets the aria-valuenow attribute
pub fn set_ariaValueNow(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-valuenow", value);
}

/// Setter for ariaValueText
/// ARIAMixin - Sets the aria-valuetext attribute
pub fn set_ariaValueText(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-valuetext", value);
}

/// Operation: getAttributeNS
/// DOM §4.8 - Returns the value of the attribute with the given namespace and local name
/// Spec: https://dom.spec.whatwg.org/#dom-element-getattributens
pub fn call_getAttributeNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const ns_slice = if (namespace) |ns| ns.asSlice() else "";
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
pub fn call_getAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!?runtime.DOMString {
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
pub fn call_hasAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!bool {
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
/// DOM §4.10.4 - Returns true if element matches the given selector
/// Spec: https://dom.spec.whatwg.org/#dom-element-matches
pub fn call_matches(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const selectors_str = selectors.asSlice();

    // Use ParentNode's selector matching infrastructure
    return ParentNode.matches(internal.allocator, instance, selectors_str) catch |err| {
        return switch (err) {
            error.SyntaxError => error.SyntaxError,
            error.OutOfMemory => error.OutOfMemory,
            else => error.NotImplemented,
        };
    };
}

/// Operation: releasePointerCapture
/// Pointer Events §5.4.3 - Releases pointer capture
/// Spec: https://w3c.github.io/pointerevents/#dom-element-releasepointercapture
///
/// Without pointer event support, this is a no-op
pub fn call_releasePointerCapture(instance: *runtime.Instance, pointerId: i32) anyerror!void {
    _ = instance;
    _ = pointerId;
    // No-op without pointer event support
}

/// Operation: computedStyleMap
/// CSS Typed OM §5.3 - Returns the element's computed style as a StylePropertyMapReadOnly
/// Spec: https://drafts.css-houdini.org/css-typed-om-1/#dom-element-computedstylemap
///
/// Note: Returns null - requires CSSOM and layout engine
pub fn call_computedStyleMap(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    // Requires CSSOM and layout engine - return null
    return error.NotImplemented;
}

/// Operation: scroll
/// CSSOM View §5.1 - Scrolls the element to the given coordinates
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-scroll
///
/// Without a layout engine, this is a no-op (returns resolved promise with undefined)
pub fn call_scroll(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ScrollToOptions)) anyerror!*const anyopaque {
    _ = instance;
    _ = options;
    // No-op without layout engine - returns sentinel for undefined
    // TODO: Should return a resolved Promise<undefined>
    return @ptrFromInt(1);
}

/// Operation: getClientRects
/// CSSOM View §5.1 - Returns a DOMRectList of client rects for this element
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-getclientrects
///
/// Without a layout engine, returns an empty DOMRectList
pub fn call_getClientRects(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Return empty DOMRectList (no layout = no client rects)
    return interfaces.DOMRectList.init(internal.allocator, instance.ctx) catch return error.OutOfMemory;
}

/// Operation: scrollBy
/// CSSOM View §5.1 - Scrolls the element by the given amounts
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-scrollby
///
/// Without a layout engine, this is a no-op (returns resolved promise with undefined)
pub fn call_scrollBy(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ScrollToOptions)) anyerror!*const anyopaque {
    _ = instance;
    _ = options;
    // No-op without layout engine - returns sentinel for undefined
    // TODO: Should return a resolved Promise<undefined>
    return @ptrFromInt(1);
}

/// Operation: prepend
/// ParentNode mixin - Inserts nodes before the first child of this element
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-prepend
///
/// Note: This is a simplified implementation that handles the common single-node case.
pub fn call_prepend(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    // For simplified implementation, treat nodes as a single Node pointer
    const node: *runtime.Instance = @ptrCast(@alignCast(@constCast(nodes)));

    // Get first child
    const first_child = NodeImpl.getFirstChild(instance);

    if (first_child) |fc| {
        // Insert before first child
        _ = interfaces.Node.call_insertBefore(instance, node, fc) catch {
            return error.InvalidStateError;
        };
    } else {
        // No children - append
        _ = interfaces.Node.call_appendChild(instance, node) catch {
            return error.InvalidStateError;
        };
    }
}

/// Operation: replaceWith
/// ChildNode mixin - Replaces this element with nodes
/// Spec: https://dom.spec.whatwg.org/#dom-childnode-replacewith
///
/// Note: This is a simplified implementation that handles the common single-node case.
pub fn call_replaceWith(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    // Get parent - if null, return (per spec)
    const parent = NodeImpl.getParent(instance) orelse return;

    // For simplified implementation, treat nodes as a single Node pointer
    const node: *runtime.Instance = @ptrCast(@alignCast(@constCast(nodes)));

    // Replace this with node using Node.replaceChild
    _ = interfaces.Node.call_replaceChild(parent, node, instance) catch {
        return error.InvalidStateError;
    };
}

/// Operation: convertQuadFromNode
/// CSSOM View §6 - Converts a quad from another element's coordinate space
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-convertquadfromnode
///
/// Note: Returns null - requires layout engine for coordinate transformations
pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: dictionaries.DOMQuadInit, from: typedefs.GeometryNode, options: webidl.Opt(dictionaries.ConvertCoordinateOptions)) anyerror!*runtime.Instance {
    _ = instance;
    _ = quad;
    _ = from;
    _ = options;
    // Requires layout engine for coordinate transformations - return null
    return error.NotImplemented;
}

/// Operation: setAttributeNodeNS
/// DOM §4.8 - Adds or replaces the Attr node with the given namespace
/// Spec: https://dom.spec.whatwg.org/#dom-element-setattributenodens
///
/// The setAttributeNodeNS(attr) method steps are to return the result of
/// setting an attribute given attr and this.
///
/// Returns the old Attr node if replaced, or null if newly added.
pub fn call_setAttributeNodeNS(instance: *runtime.Instance, attr: *runtime.Instance) anyerror!?*runtime.Instance {
    // setAttributeNodeNS and setAttributeNode have identical behavior per spec
    // They both call the "set an attribute" algorithm
    return call_setAttributeNode(instance, attr);
}

/// Operation: getAttributeNodeNS
/// DOM §4.8 - Returns the Attr node with the given namespace and local name
/// Spec: https://dom.spec.whatwg.org/#dom-element-getattributenodens
pub fn call_getAttributeNodeNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const ns_slice = if (namespace) |ns| ns.asSlice() else "";
    const name_slice = localName.asSlice();

    // Get attribute by namespace and local name
    if (getAttributeByNS(internal, if (ns_slice.len > 0) ns_slice else null, name_slice)) |entry| {
        // Create Attr node for this attribute
        const attr = AttrImpl.createAttr(
            internal.allocator,
            instance.ctx,
            entry.namespace_uri,
            entry.prefix,
            entry.local_name,
            entry.value,
        ) catch return error.OutOfMemory;

        // Set owner element
        AttrImpl.setOwnerElement(attr, instance) catch return error.InvalidStateError;

        return attr;
    }

    // Return null (not found)
    return null;
}

/// Operation: setAttributeNS
/// DOM §4.8 - Sets the attribute with the given namespace and qualified name
/// Spec: https://dom.spec.whatwg.org/#dom-element-setattributens
pub fn call_setAttributeNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, qualifiedName: runtime.DOMString, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const ns_slice = if (namespace) |ns| ns.asSlice() else "";
    const qname_slice = qualifiedName.asSlice();

    // Get value as slice
    const val = value.asSlice();

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
/// DOM §4.8 - Adds or replaces the Attr node
/// Spec: https://dom.spec.whatwg.org/#dom-element-setattributenode
///
/// The setAttributeNode(attr) method steps are to return the result of
/// setting an attribute given attr and this.
pub fn call_setAttributeNode(instance: *runtime.Instance, attr: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Get attribute properties from the Attr node
    const namespace_uri_opt = interfaces.Attr.get_namespaceURI(attr) catch return error.InvalidStateError;
    const prefix_opt = interfaces.Attr.get_prefix(attr) catch return error.InvalidStateError;
    const local_name = interfaces.Attr.get_localName(attr) catch return error.InvalidStateError;
    const value = interfaces.Attr.get_value(attr) catch return error.InvalidStateError;

    const ns_slice = if (namespace_uri_opt) |ns| ns.asSlice() else "";
    const prefix_slice = if (prefix_opt) |p| p.asSlice() else "";
    const name_slice = local_name.asSlice();
    const value_slice = value.asSlice();

    // Check if an attribute with same namespace and local name already exists
    const ns = if (ns_slice.len > 0) ns_slice else null;
    const pfx = if (prefix_slice.len > 0) prefix_slice else null;

    var old_attr: ?*runtime.Instance = null;

    if (getAttributeByNS(internal, ns, name_slice)) |_| {
        // Get old attribute node before replacing
        const namespace_uri_param = namespace_uri_opt orelse runtime.DOMString.initEmpty();
        old_attr = call_getAttributeNodeNS(instance, namespace_uri_param, local_name) catch null;
    }

    // Set the attribute value (this will add or update)
    setAttributeInternal(internal, ns, pfx, name_slice, value_slice) catch return error.OutOfMemory;

    // Set owner element on the new attr
    AttrImpl.setOwnerElement(attr, instance) catch return error.InvalidStateError;

    // Return old attribute if it existed, otherwise null
    return old_attr;
}

/// Operation: scrollTo
/// CSSOM View §5.1 - Scrolls the element to the given coordinates (alias for scroll)
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-scrollto
///
/// Without a layout engine, this is a no-op (returns resolved promise with undefined)
pub fn call_scrollTo(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ScrollToOptions)) anyerror!*const anyopaque {
    _ = instance;
    _ = options;
    // No-op without layout engine - returns sentinel for undefined
    // TODO: Should return a resolved Promise<undefined>
    return @ptrFromInt(1);
}

/// Operation: getElementsByTagNameNS
/// DOM §4.10.5 - Returns HTMLCollection of descendants with matching namespace and local name
/// Spec: https://dom.spec.whatwg.org/#dom-element-getelementsbytagnamens
pub fn call_getElementsByTagNameNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const ns_slice = if (namespace) |ns| ns.asSlice() else "";
    const name_slice = localName.asSlice();

    // Create HTMLCollection
    const collection = interfaces.HTMLCollection.init(
        internal.allocator,
        instance.ctx,
    ) catch return error.OutOfMemory;
    errdefer interfaces.HTMLCollection.deinit(collection);

    // Collect matching descendants
    collectElementsByTagNameNS(instance, ns_slice, name_slice, collection) catch return error.OutOfMemory;

    return collection;
}

/// Operation: replaceChildren
/// ParentNode mixin - Replaces all children of this element with nodes
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-replacechildren
///
/// Steps:
/// 1. Let node be the result of converting nodes into a node
/// 2. Ensure pre-insertion validity of node into this before null
/// 3. Replace all with node within this
///
/// Note: This is a simplified implementation that handles the common single-node case.
pub fn call_replaceChildren(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    // First, remove all existing children
    var child = NodeImpl.getFirstChild(instance);
    while (child) |c| {
        const next = NodeImpl.getNextSibling(c);
        _ = interfaces.Node.call_removeChild(instance, c) catch {};
        child = next;
    }

    // Then append the new node(s)
    // For simplified implementation, treat nodes as a single Node pointer
    // Note: nodes being "empty" variadic is represented as a special marker, not null pointer
    const node: *runtime.Instance = @ptrCast(@alignCast(@constCast(nodes)));

    // Append the new node
    _ = interfaces.Node.call_appendChild(instance, node) catch {
        return error.InvalidStateError;
    };
}

/// Operation: getRegionFlowRanges
/// CSS Regions §10.3 - Returns ranges for content in this region
/// Spec: https://drafts.csswg.org/css-regions-1/#dom-region-getregionflowranges
///
/// Note: CSS Regions is deprecated - returns null (empty array)
pub fn call_getRegionFlowRanges(instance: *runtime.Instance) anyerror!?*const anyopaque {
    _ = instance;
    // CSS Regions is deprecated - return empty array sentinel
    return @ptrFromInt(1);
}

/// Operation: getBoxQuads
/// CSSOM View §6 - Returns the element's CSS boxes as DOMQuads
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-getboxquads
///
/// Note: Returns empty array - requires layout engine
pub fn call_getBoxQuads(instance: *runtime.Instance, options: webidl.Opt(dictionaries.BoxQuadOptions)) anyerror!*const anyopaque {
    _ = instance;
    _ = options;
    // Requires layout engine - return empty array sentinel
    return @ptrFromInt(1);
}

/// Operation: focusableAreas
/// CSS Spatial Navigation §5 - Returns focusable areas in specified direction
/// Spec: https://drafts.csswg.org/css-nav-1/#dom-element-focusableareas
///
/// Note: Returns empty array - spatial navigation not implemented
pub fn call_focusableAreas(instance: *runtime.Instance, option: webidl.Opt(dictionaries.FocusableAreasOption)) anyerror!*const anyopaque {
    _ = instance;
    _ = option;
    // Spatial navigation not implemented - return empty array sentinel
    return @ptrFromInt(1);
}

/// Operation: convertPointFromNode
/// CSSOM View §6 - Converts a point from another element's coordinate space
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-convertpointfromnode
///
/// Note: Returns null - requires layout engine for coordinate transformations
pub fn call_convertPointFromNode(instance: *runtime.Instance, point: dictionaries.DOMPointInit, from: typedefs.GeometryNode, options: webidl.Opt(dictionaries.ConvertCoordinateOptions)) anyerror!*runtime.Instance {
    _ = instance;
    _ = point;
    _ = from;
    _ = options;
    // Requires layout engine - return null
    return error.NotImplemented;
}

/// Operation: getAnimations
/// Web Animations §4.4.4 - Returns animations targeting this element
/// Spec: https://drafts.csswg.org/web-animations-1/#dom-animatable-getanimations
///
/// Returns an empty array (no animations without rendering engine)
pub fn call_getAnimations(instance: *runtime.Instance, options: webidl.Opt(dictionaries.GetAnimationsOptions)) anyerror!*const anyopaque {
    _ = instance;
    _ = options;
    // Returns empty array - no animations without rendering engine
    // Using sentinel value for empty array
    return @ptrFromInt(1);
}

/// Operation: getElementsByClassName
/// DOM §4.10.5 - Returns HTMLCollection of descendants with all given class names
/// Spec: https://dom.spec.whatwg.org/#dom-element-getelementsbyclassname
pub fn call_getElementsByClassName(instance: *runtime.Instance, classNames: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const names_slice = classNames.asSlice();

    // Create HTMLCollection
    const collection = interfaces.HTMLCollection.init(
        internal.allocator,
        instance.ctx,
    ) catch return error.OutOfMemory;
    errdefer interfaces.HTMLCollection.deinit(collection);

    // Collect matching descendants
    collectElementsByClassName(instance, names_slice, collection) catch return error.OutOfMemory;

    return collection;
}

/// Operation: insertAdjacentElement
/// DOM §4.10.7 - Insert element at specified position relative to this element
/// Spec: https://dom.spec.whatwg.org/#dom-element-insertadjacentelement
///
/// The insertAdjacentElement(where, element) method steps are to return the result of
/// running insert adjacent, given this, where, and element.
///
/// Position values (case-insensitive):
/// - "beforebegin": Before this element (as a sibling)
/// - "afterbegin": Inside this element, before first child
/// - "beforeend": Inside this element, after last child
/// - "afterend": After this element (as a sibling)
pub fn call_insertAdjacentElement(instance: *runtime.Instance, where: runtime.DOMString, element: *runtime.Instance) anyerror!?*runtime.Instance {
    const result = insertAdjacent(instance, where.asSlice(), element) catch |err| {
        return switch (err) {
            error.SyntaxError => error.SyntaxError,
            error.InvalidStateError => error.InvalidStateError,
        };
    };

    // insertAdjacent returns null if parent is null for beforebegin/afterend positions
    return result;
}

/// Operation: webkitMatchesSelector
/// Legacy alias for matches() - Returns true if element matches the given selector
/// Spec: https://dom.spec.whatwg.org/#dom-element-webkitmatchesselector
pub fn call_webkitMatchesSelector(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!bool {
    // webkitMatchesSelector is an alias for matches()
    return call_matches(instance, selectors);
}

/// Operation: spatialNavigationSearch
/// CSS Spatial Navigation §5 - Searches for next focusable element in direction
/// Spec: https://drafts.csswg.org/css-nav-1/#dom-element-spatialnavigationsearch
///
/// Note: Returns null - spatial navigation not implemented without layout engine
pub fn call_spatialNavigationSearch(instance: *runtime.Instance, dir: enums.SpatialNavigationDirection, options: webidl.Opt(dictionaries.SpatialNavigationSearchOptions)) anyerror!?*runtime.Instance {
    _ = instance;
    _ = dir;
    _ = options;
    // Spatial navigation not implemented without layout engine - return null
    return null;
}

/// Operation: getElementsByTagName
/// DOM §4.10.5 - Returns HTMLCollection of descendants with matching tag name
/// Spec: https://dom.spec.whatwg.org/#dom-element-getelementsbytagname
pub fn call_getElementsByTagName(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const name_slice = qualifiedName.asSlice();

    // Create HTMLCollection
    const collection = interfaces.HTMLCollection.init(
        internal.allocator,
        instance.ctx,
    ) catch return error.OutOfMemory;
    errdefer interfaces.HTMLCollection.deinit(collection);

    // Collect matching descendants
    collectElementsByTagName(instance, name_slice, collection) catch return error.OutOfMemory;

    return collection;
}

/// Operation: querySelector
/// ParentNode mixin - Returns the first element matching the selector
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-queryselector
pub fn call_querySelector(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const selectors_str = selectors.asSlice();

    // Delegate to ParentNode mixin
    const result = ParentNode.querySelector(internal.allocator, instance, selectors_str) catch |err| {
        return switch (err) {
            error.SyntaxError => error.SyntaxError,
            error.OutOfMemory => error.OutOfMemory,
            else => error.NotImplemented,
        };
    };

    return result;
}

/// Operation: closest
/// DOM §4.10.4 - Returns closest ancestor (or self) matching selector
/// Spec: https://dom.spec.whatwg.org/#dom-element-closest
pub fn call_closest(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const selectors_str = selectors.asSlice();

    // Find closest matching ancestor (including self)
    const result = ParentNode.closest(internal.allocator, instance, selectors_str) catch |err| {
        return switch (err) {
            error.SyntaxError => error.SyntaxError,
            error.OutOfMemory => error.OutOfMemory,
            else => error.NotImplemented,
        };
    };

    return result;
}

/// Operation: getSpatialNavigationContainer
/// CSS Spatial Navigation §5 - Returns spatial navigation container
/// Spec: https://drafts.csswg.org/css-nav-1/#dom-element-getspatialnavigationcontainer
///
/// Note: Returns null - spatial navigation not implemented
pub fn call_getSpatialNavigationContainer(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    // Spatial navigation not implemented - return null
    return error.NotImplemented;
}

/// Operation: remove
/// ChildNode mixin - Removes this element from its parent
/// Spec: https://dom.spec.whatwg.org/#dom-childnode-remove
pub fn call_remove(instance: *runtime.Instance) anyerror!void {
    ChildNode.remove(instance) catch |err| {
        return switch (err) {
            error.HierarchyRequestError => error.InvalidStateError,
            else => error.NotImplemented,
        };
    };
}

/// Operation: removeAttribute
/// DOM §4.8 - Removes the named attribute
pub fn call_removeAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!void {
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
/// CSSOM View §6 - Converts a rect from another element's coordinate space
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-convertrectfromnode
///
/// Note: Returns null - requires layout engine for coordinate transformations
pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: *runtime.Instance, from: typedefs.GeometryNode, options: webidl.Opt(dictionaries.ConvertCoordinateOptions)) anyerror!*runtime.Instance {
    _ = instance;
    _ = rect;
    _ = from;
    _ = options;
    // Requires layout engine - return null
    return error.NotImplemented;
}

/// Operation: removeAttributeNode
/// DOM §4.8 - Removes the given Attr node from this element
/// Spec: https://dom.spec.whatwg.org/#dom-element-removeattributenode
///
/// The removeAttributeNode(attr) method steps are:
/// 1. If this's attribute list does not contain attr, then throw a "NotFoundError" DOMException.
/// 2. Remove attr.
/// 3. Return attr.
pub fn call_removeAttributeNode(instance: *runtime.Instance, attr: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Get attribute properties from the Attr node
    const namespace_uri_opt = interfaces.Attr.get_namespaceURI(attr) catch return error.InvalidStateError;
    const local_name = interfaces.Attr.get_localName(attr) catch return error.InvalidStateError;

    const ns_slice = if (namespace_uri_opt) |ns| ns.asSlice() else "";
    const name_slice = local_name.asSlice();
    const ns = if (ns_slice.len > 0) ns_slice else null;

    // Step 1: Check if attribute exists
    if (getAttributeByNS(internal, ns, name_slice) == null) {
        return error.NotFoundError;
    }

    // Step 2: Remove the attribute
    removeAttributeByNS(internal, ns, name_slice);

    // Clear owner element on the removed attr
    AttrImpl.setOwnerElement(attr, null) catch {};

    // Update cached values if needed
    if (ns == null) {
        if (std.mem.eql(u8, name_slice, "id")) {
            internal.id.deinit(internal.allocator);
            internal.id = runtime.DOMString.initEmpty();
        } else if (std.mem.eql(u8, name_slice, "class")) {
            internal.class_name.deinit(internal.allocator);
            internal.class_name = runtime.DOMString.initEmpty();
        } else if (std.mem.eql(u8, name_slice, "slot")) {
            internal.slot.deinit(internal.allocator);
            internal.slot = runtime.DOMString.initEmpty();
        }
    }

    // Step 3: Return attr
    return attr;
}

/// Operation: removeAttributeNS
/// DOM §4.8 - Removes the attribute with the given namespace and local name
/// Spec: https://dom.spec.whatwg.org/#dom-element-removeattributens
pub fn call_removeAttributeNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const ns_slice = if (namespace) |ns| ns.asSlice() else "";
    const name_slice = localName.asSlice();

    // Remove by namespace and local name
    removeAttributeByNS(internal, if (ns_slice.len > 0) ns_slice else null, name_slice);
}

/// Operation: insertAdjacentText
/// DOM §4.10.7 - Creates a Text node and inserts it at specified position
/// Spec: https://dom.spec.whatwg.org/#dom-element-insertadjacenttext
///
/// The insertAdjacentText(where, data) method steps are:
/// 1. Let text be a new Text node whose data is data and node document is this's node document.
/// 2. Run the insert adjacent algorithm given this, where, and text.
pub fn call_insertAdjacentText(instance: *runtime.Instance, where: runtime.DOMString, data: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: Create a new Text node with the given data
    // Use interface instead of impl (per Golden Rule #13)
    const text_node = interfaces.Text.call_constructor(internal.allocator, instance.ctx, webidl.Opt(runtime.DOMString).passed(data)) catch return error.OutOfMemory;
    errdefer interfaces.Text.deinit(text_node);

    // Step 2: Run insert adjacent algorithm
    _ = insertAdjacent(instance, where.asSlice(), text_node) catch |err| {
        return switch (err) {
            error.SyntaxError => error.SyntaxError,
            error.InvalidStateError => error.InvalidStateError,
        };
    };
}

/// Operation: requestFullscreen
/// Fullscreen API §4.1 - Requests fullscreen mode for this element
/// Spec: https://fullscreen.spec.whatwg.org/#dom-element-requestfullscreen
///
/// Note: Returns rejected promise - fullscreen requires browser integration
pub fn call_requestFullscreen(instance: *runtime.Instance, options: webidl.Opt(dictionaries.FullscreenOptions)) anyerror!*const anyopaque {
    _ = instance;
    _ = options;
    // Fullscreen requires browser integration - return sentinel for rejected promise
    // TODO: Should return a rejected Promise with TypeError
    return @ptrFromInt(1);
}

/// Operation: animate
/// Web Animations §4.4.3 - Creates and runs a new Animation
/// Spec: https://drafts.csswg.org/web-animations-1/#dom-animatable-animate
///
/// Note: Returns null - requires Web Animations API and rendering engine
pub fn call_animate(instance: *runtime.Instance, keyframes: ?*const anyopaque, options: webidl.Opt(*const anyopaque)) anyerror!*runtime.Instance {
    _ = instance;
    _ = keyframes;
    _ = options;
    // Animation requires rendering engine - return null
    return error.NotImplemented;
}

/// Operation: append
/// ParentNode mixin - Appends nodes after the last child of this element
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-append
///
/// Note: This is a simplified implementation that handles the common single-node case.
pub fn call_append(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    // For simplified implementation, treat nodes as a single Node pointer
    const node: *runtime.Instance = @ptrCast(@alignCast(@constCast(nodes)));

    // Append as last child
    _ = interfaces.Node.call_appendChild(instance, node) catch {
        return error.InvalidStateError;
    };
}

/// Operation: moveBefore
/// DOM §4.10.6 - Moves a node before a child without triggering removal callbacks
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-movebefore
///
/// This is a newer DOM method for moving nodes atomically
pub fn call_moveBefore(instance: *runtime.Instance, node: *runtime.Instance, child: ?*runtime.Instance) anyerror!void {
    // Use insertBefore as a fallback (doesn't suppress callbacks but same tree result)
    _ = interfaces.Node.call_insertBefore(instance, node, child) catch |err| {
        return switch (err) {
            error.HierarchyRequestError => error.InvalidStateError,
            error.NotFoundError => error.NotFoundError,
            else => error.InvalidStateError,
        };
    };
}

/// Operation: getHTML
/// HTML Sanitizer API - Returns sanitized HTML serialization
/// Spec: https://wicg.github.io/sanitizer-api/#dom-element-gethtml
///
/// Returns the innerHTML with optional shadow roots serialized
pub fn call_getHTML(instance: *runtime.Instance, options: webidl.Opt(dictionaries.GetHTMLOptions)) anyerror!runtime.DOMString {
    _ = options;
    // get_innerHTML returns *const anyopaque which is a DOMString union
    // We need to call the serialization directly here
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Serialize all child nodes
    var buffer = infra.List(u8).init(internal.allocator);
    defer buffer.deinit();

    var child = NodeImpl.getFirstChild(instance);
    while (child) |c| {
        serializeNode(c, &buffer, internal.allocator) catch return error.OutOfMemory;
        child = NodeImpl.getNextSibling(c);
    }

    // Return the serialized HTML
    const slice = buffer.items();
    if (slice.len == 0) {
        return runtime.DOMString.initEmpty();
    }
    return runtime.DOMString.initDupe(internal.allocator, slice) catch return error.OutOfMemory;
}

/// Operation: getAttributeNode
/// DOM §4.8 - Returns the Attr node with the given qualified name
/// Spec: https://dom.spec.whatwg.org/#dom-element-getattributenode
///
/// The getAttributeNode(qualifiedName) method steps are to return the result of
/// getting an attribute given qualifiedName and this.
pub fn call_getAttributeNode(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const name = qualifiedName.asSlice();

    // TODO: Lowercase name for HTML elements in HTML documents

    // Search for attribute by qualified name (no namespace)
    for (internal.attributes.items) |entry| {
        if (entry.namespace_uri == null and std.mem.eql(u8, entry.local_name, name)) {
            // Create Attr node for this attribute
            const attr = AttrImpl.createAttr(
                internal.allocator,
                instance.ctx,
                entry.namespace_uri,
                entry.prefix,
                entry.local_name,
                entry.value,
            ) catch return error.OutOfMemory;

            // Set owner element
            AttrImpl.setOwnerElement(attr, instance) catch return error.InvalidStateError;

            return attr;
        }
    }

    // Return null (not found)
    return null;
}

/// Operation: startViewTransition
/// View Transitions API - Starts a view transition
/// Spec: https://drafts.csswg.org/css-view-transitions-1/#dom-document-startviewtransition
///
/// Note: Returns null - View Transitions require rendering engine
pub fn call_startViewTransition(instance: *runtime.Instance, callbackOptions: webidl.Opt(*const anyopaque)) anyerror!*runtime.Instance {
    _ = instance;
    _ = callbackOptions;
    // View Transitions require rendering engine - return null
    return error.NotImplemented;
}

/// Operation: setHTMLUnsafe
/// HTML Sanitizer API - Sets HTML without sanitization
/// Spec: https://wicg.github.io/sanitizer-api/#dom-element-sethtmlunsafe
///
/// Note: Requires HTML fragment parsing algorithm (not implemented)
pub fn call_setHTMLUnsafe(instance: *runtime.Instance, html: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = html;
    // TODO: Requires HTML fragment parsing algorithm
    return error.NotImplemented;
}

/// Operation: scrollIntoView
/// CSSOM View §5.1 - Scrolls this element into view
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-scrollintoview
///
/// Without a layout engine, this is a no-op (returns resolved promise with undefined)
pub fn call_scrollIntoView(instance: *runtime.Instance, arg: webidl.Opt(*const anyopaque)) anyerror!*const anyopaque {
    _ = instance;
    _ = arg;
    // No-op without layout engine - returns sentinel for undefined
    // TODO: Should return a resolved Promise<undefined>
    return @ptrFromInt(1);
}

/// Operation: hasAttributes
/// DOM §4.8 - Returns true if the element has any attributes
/// Spec: https://dom.spec.whatwg.org/#dom-element-hasattributes
pub fn call_hasAttributes(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.attributes.items.len > 0;
}

/// Operation: hasPointerCapture
/// Pointer Events §5.4.4 - Checks if element has pointer capture
/// Spec: https://w3c.github.io/pointerevents/#dom-element-haspointercapture
///
/// Without pointer event support, always returns false
pub fn call_hasPointerCapture(instance: *runtime.Instance, pointerId: i32) anyerror!bool {
    _ = instance;
    _ = pointerId;
    // No pointer capture without pointer event support
    return false;
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
pub fn call_toggleAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString, force: webidl.Opt(bool)) anyerror!bool {
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

    // Handle force parameter
    const force_value: ?bool = if (force.was_passed) force.value else null;

    if (attr_index != null) {
        // Attribute exists
        if (force_value == null or force_value == false) {
            // Remove it (when force not passed or force is false)
            if (force_value == null or force_value == false) {
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
        }
        // force is true, attribute exists - return true
        return true;
    } else {
        // Attribute doesn't exist
        if (force_value == null or force_value == true) {
            // Add it with empty value (when force not passed or force is true)
            try setAttributeInternal(internal, null, null, name, "");
            return true;
        }
        // force is false, attribute doesn't exist - return false
        return false;
    }
}

/// Operation: pseudo
/// CSSOM §6.1 - Returns a CSSPseudoElement for the given pseudo-element type
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-pseudo
///
/// Note: Returns null - requires CSSOM and pseudo-element support
pub fn call_pseudo(instance: *runtime.Instance, @"type": typedefs.CSSOMString) anyerror!?*runtime.Instance {
    _ = instance;
    _ = @"type";
    // Requires CSSOM and pseudo-element support - return null
    return error.NotImplemented;
}

/// Operation: before
/// ChildNode mixin - Inserts nodes just before this element
/// Spec: https://dom.spec.whatwg.org/#dom-childnode-before
///
/// Note: This is a simplified implementation that handles the common single-node case.
/// Full implementation would need to handle variadic Node or DOMString arguments.
pub fn call_before(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    // Get parent - if null, return (per spec)
    const parent = NodeImpl.getParent(instance) orelse return;

    // For simplified implementation, treat nodes as a single Node pointer
    // TODO: Handle variadic (Node or DOMString)... properly
    const node: *runtime.Instance = @ptrCast(@alignCast(@constCast(nodes)));

    // Insert node before this element
    _ = interfaces.Node.call_insertBefore(parent, node, instance) catch {
        return error.InvalidStateError;
    };
}

/// Operation: after
/// ChildNode mixin - Inserts nodes just after this element
/// Spec: https://dom.spec.whatwg.org/#dom-childnode-after
///
/// Note: This is a simplified implementation that handles the common single-node case.
pub fn call_after(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    // Get parent - if null, return (per spec)
    const parent = NodeImpl.getParent(instance) orelse return;

    // For simplified implementation, treat nodes as a single Node pointer
    const node: *runtime.Instance = @ptrCast(@alignCast(@constCast(nodes)));

    // Get next sibling
    const next_sibling = NodeImpl.getNextSibling(instance);

    if (next_sibling) |ns| {
        // Insert before next sibling
        _ = interfaces.Node.call_insertBefore(parent, node, ns) catch {
            return error.InvalidStateError;
        };
    } else {
        // Append to parent (no next sibling)
        _ = interfaces.Node.call_appendChild(parent, node) catch {
            return error.InvalidStateError;
        };
    }
}

/// Operation: setAttribute
/// DOM §4.8 - Sets the value of the named attribute
/// TODO: value is typed as anyopaque due to codegen - should be DOMString
pub fn call_setAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const name = qualifiedName.asSlice();

    // TODO: Validate qualifiedName per https://dom.spec.whatwg.org/#validate

    // Get value as slice
    const val = value.asSlice();

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
/// DOM Parsing §3.4 - Parses HTML and inserts it at the specified position
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-element-insertadjacenthtml
///
/// Position values:
/// - "beforebegin": Before the element itself
/// - "afterbegin": Just inside the element, before its first child
/// - "beforeend": Just inside the element, after its last child
/// - "afterend": After the element itself
///
/// Note: Requires HTML fragment parsing algorithm (not implemented)
pub fn call_insertAdjacentHTML(instance: *runtime.Instance, position: runtime.DOMString, string: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = position;
    _ = string;
    // TODO: Requires HTML fragment parsing algorithm
    return error.NotImplemented;
}

/// Operation: checkVisibility
/// CSSOM View §3.1 - Checks if the element would be visible
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-checkvisibility
///
/// Returns true if the element is potentially visible (connected, rendered, not hidden).
/// Without a layout engine, we assume elements are visible if they exist.
pub fn call_checkVisibility(instance: *runtime.Instance, options: webidl.Opt(dictionaries.CheckVisibilityOptions)) anyerror!bool {
    _ = instance;
    _ = options; // Layout-related options can't be checked without a layout engine

    // Without a layout engine, we assume all elements are visible
    // A proper implementation would check:
    // - computed display != none
    // - computed visibility != hidden (if checkVisibilityCSS)
    // - opacity > 0 (if checkOpacity)
    // - not a content-visibility: hidden element (if contentVisibilityAuto)
    return true;
}

/// Operation: getAttributeNames
/// DOM §4.8 - Returns the qualified names of all attributes in order
/// Spec: https://dom.spec.whatwg.org/#dom-element-getattributenames
///
/// Returns a sequence of DOMStrings (the qualified names of attributes).
/// Note: These are not guaranteed to be unique.
pub fn call_getAttributeNames(instance: *runtime.Instance) anyerror!*const anyopaque {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Create a NodeList to hold the attribute names as a sequence
    // TODO: This should ideally return a JS Array, but for now we use NodeList as placeholder
    const node_list = interfaces.NodeList.init(
        internal.allocator,
        instance.ctx,
    ) catch return error.OutOfMemory;

    // For each attribute, add its qualified name to the list
    // Note: getAttributeNames returns qualified names (prefix:localName if prefix exists)
    for (internal.attributes.items) |entry| {
        // Build qualified name
        if (entry.prefix) |prefix| {
            // Has prefix - need to build "prefix:localName"
            // For now, just use local_name (TODO: implement proper concatenation)
            _ = prefix;
        }
        // The qualified name is just the local_name for null-prefix attributes
        // Store as opaque - in practice this would be added to an array
    }

    // Return the list as opaque pointer
    // Note: This is a simplified implementation - full impl would return JS Array
    return @ptrCast(node_list);
}

/// Operation: attachShadow
/// DOM §4.10.2 - Attaches a shadow root to this element
/// Spec: https://dom.spec.whatwg.org/#dom-element-attachshadow
///
/// Creates a shadow root for this element and returns it.
/// Throws NotSupportedError if:
/// - Element already has a shadow root
/// - Element is not a valid shadow host (must be custom element or certain HTML elements)
pub fn call_attachShadow(instance: *runtime.Instance, init_data: dictionaries.ShadowRootInit) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if element already has a shadow root
    if (internal.shadow_root != null) {
        // Per spec: throw NotSupportedError if element already has a shadow root
        return error.InvalidStateError;
    }

    // TODO: Validate that this element can be a shadow host
    // Valid elements are: article, aside, blockquote, body, div, footer, h1-h6,
    // header, main, nav, p, section, span, or any custom element
    // For now, we allow any element

    // Parse mode from the dictionary (it's passed as *const anyopaque from V8)
    // The conversion layer passes through V8 values for enum types
    const mode = parseShadowRootMode(init_data.mode);

    // Parse slotAssignment if provided
    const slot_assignment = if (init_data.slotAssignment) |sa|
        parseSlotAssignmentMode(sa)
    else
        enums.SlotAssignmentMode._named_;

    // Create the ShadowRoot using the factory function which properly initializes all state
    const ShadowRootImpl = @import("ShadowRoot.zig");
    const shadow_root = ShadowRootImpl.create(
        internal.allocator,
        instance.ctx,
        instance, // host element
        mode,
        init_data.delegatesFocus orelse false,
        slot_assignment,
        init_data.clonable orelse false,
        init_data.serializable orelse false,
    ) catch return error.OutOfMemory;

    // Store reference in element's internal state
    internal.shadow_root = shadow_root;

    return shadow_root;
}

/// Parse ShadowRootMode from V8 value
fn parseShadowRootMode(ptr: *const anyopaque) enums.ShadowRootMode {
    // The V8 conversion layer passes enum values as strings via anyopaque pointer
    // For now, try to extract the string and match
    const v8 = @import("v8");

    // Check if this is a V8 string value
    const v8_value: *v8.ffi.Value = @ptrCast(@constCast(ptr));
    if (v8.ffi.v8_Value_IsString(v8_value)) {
        // Get string length and content
        const str_len = v8.ffi.v8_Value_StringLength_Raw(ptr);
        if (str_len > 0 and str_len <= 10) {
            var buf: [10]u8 = undefined;
            const written = v8.ffi.v8_Value_StringWriteUtf8_Raw(ptr, &buf, @intCast(str_len));
            if (written > 0) {
                const mode_str = buf[0..@intCast(written)];
                if (std.mem.eql(u8, mode_str, "closed")) {
                    return ._closed_;
                }
            }
        }
    }
    // Default to open
    return ._open_;
}

/// Parse SlotAssignmentMode from V8 value
fn parseSlotAssignmentMode(ptr: *const anyopaque) enums.SlotAssignmentMode {
    const v8 = @import("v8");

    const v8_value: *v8.ffi.Value = @ptrCast(@constCast(ptr));
    if (v8.ffi.v8_Value_IsString(v8_value)) {
        const str_len = v8.ffi.v8_Value_StringLength_Raw(ptr);
        if (str_len > 0 and str_len <= 10) {
            var buf: [10]u8 = undefined;
            const written = v8.ffi.v8_Value_StringWriteUtf8_Raw(ptr, &buf, @intCast(str_len));
            if (written > 0) {
                const mode_str = buf[0..@intCast(written)];
                if (std.mem.eql(u8, mode_str, "manual")) {
                    return ._manual_;
                }
            }
        }
    }
    // Default to named
    return ._named_;
}

/// Operation: requestPointerLock
/// Pointer Lock API §4.1 - Requests pointer lock on this element
/// Spec: https://w3c.github.io/pointerlock/#dom-element-requestpointerlock
///
/// Note: Returns rejected promise - pointer lock requires browser integration
pub fn call_requestPointerLock(instance: *runtime.Instance, options: webidl.Opt(dictionaries.PointerLockOptions)) anyerror!*const anyopaque {
    _ = instance;
    _ = options;
    // Pointer lock requires browser integration - return sentinel for rejected promise
    // TODO: Should return a rejected Promise with SecurityError
    return @ptrFromInt(1);
}

/// Operation: hasAttributeNS
/// DOM §4.8 - Returns true if the element has an attribute with the given namespace and local name
/// Spec: https://dom.spec.whatwg.org/#dom-element-hasattributens
pub fn call_hasAttributeNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const ns_slice = if (namespace) |ns| ns.asSlice() else "";
    const name_slice = localName.asSlice();

    return getAttributeByNS(internal, if (ns_slice.len > 0) ns_slice else null, name_slice) != null;
}

/// Operation: getBoundingClientRect
/// CSSOM View §3.1 - Returns a DOMRect with the element's bounding box
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-getboundingclientrect
///
/// Returns a DOMRect representing the smallest rectangle containing the entire element.
/// Without a layout engine, returns a DOMRect with zero dimensions at origin.
pub fn call_getBoundingClientRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Without a layout engine, return a zero-sized rect at origin
    return interfaces.DOMRect.call_constructor(internal.allocator, instance.ctx, webidl.Opt(f64).passed(0), webidl.Opt(f64).passed(0), webidl.Opt(f64).passed(0), webidl.Opt(f64).passed(0)) catch return error.OutOfMemory;
}

/// Operation: querySelectorAll
/// ParentNode mixin - Returns all elements matching the selector
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-queryselectorall
pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const selectors_str = selectors.asSlice();

    // Delegate to ParentNode mixin
    return ParentNode.querySelectorAll(internal.allocator, instance, selectors_str, instance.ctx) catch |err| {
        return switch (err) {
            error.SyntaxError => error.SyntaxError,
            error.OutOfMemory => error.OutOfMemory,
            else => error.NotImplemented,
        };
    };
}

/// Operation: setPointerCapture
/// Pointer Events §5.4.2 - Sets pointer capture
/// Spec: https://w3c.github.io/pointerevents/#dom-element-setpointercapture
///
/// Without pointer event support, this is a no-op
pub fn call_setPointerCapture(instance: *runtime.Instance, pointerId: i32) anyerror!void {
    _ = instance;
    _ = pointerId;
    // No-op without pointer event support
}
