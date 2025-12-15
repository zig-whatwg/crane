//! Implementation for CSSStyleDeclaration interface
//!
//! Implements the CSSStyleDeclaration interface per CSSOM spec.
//! This is used for both:
//! - getComputedStyle() return values (read-only computed styles)
//! - element.style property (inline styles, read-write)
//!
//! For computed styles, we return default CSS values based on the element type.
//! This is a minimal implementation for WPT infrastructure tests.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const CSSStyleDeclaration = interfaces.CSSStyleDeclaration;

// Import Element impl for tag name access
const ElementImpl = @import("Element.zig");

pub const State = CSSStyleDeclaration.State;

pub const ImplError = error{
    NotImplemented,
    OutOfMemory,
};

// Use shared InstanceRegistry utility for internal state management
const utils = webidl.utils;
const Registry = utils.InstanceRegistry(InternalState);

/// Internal state for CSSStyleDeclaration implementation
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The element this computed style is for (null for non-computed styles)
    element: ?*runtime.Instance = null,

    /// Whether this is a computed style (read-only) or inline style (read-write)
    is_computed: bool = false,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .element = null,
            .is_computed = false,
        };
    }

    pub fn deinit(self: *InternalState) void {
        _ = self;
        // No owned resources to free
    }
};

/// Get internal state from instance
pub fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
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

    // Initialize internal state in registry
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    try Registry.set(instance, internal);

    return instance;
}

/// Create a CSSStyleDeclaration for getComputedStyle()
/// Associates the element so we can return element-appropriate values
pub fn initForComputedStyle(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    element: *runtime.Instance,
) !*runtime.Instance {
    const instance = try init(allocator, StateType, vtable, ctx);
    errdefer deinit(instance);

    if (getInternal(instance)) |internal| {
        internal.element = element;
        internal.is_computed = true;
    }

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up internal state from registry
    if (Registry.get(instance)) |internal| {
        internal.deinit();
    }
    Registry.remove(instance);
    // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Getter for cssText
pub fn get_cssText(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for length
/// Returns the number of CSS properties in this declaration.
/// For computed styles, this would be all computed properties.
/// For our stub, we return 0.
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    // Stub: return 0 for now (no enumerable properties)
    return 0;
}

/// Getter for parentRule
pub fn get_parentRule(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Setter for cssText
pub fn set_cssText(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: item
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!typedefs.CSSOMString {
    _ = instance;
    _ = index;
    return error.NotImplemented;
}

/// Operation: removeProperty
pub fn call_removeProperty(instance: *runtime.Instance, property: typedefs.CSSOMString) anyerror!typedefs.CSSOMString {
    _ = instance;
    _ = property;
    return error.NotImplemented;
}

/// Operation: getPropertyCSSValue
pub fn call_getPropertyCSSValue(instance: *runtime.Instance, propertyName: runtime.DOMString) anyerror!*runtime.Instance {
    _ = instance;
    _ = propertyName;
    return error.NotImplemented;
}

/// Operation: getPropertyPriority
pub fn call_getPropertyPriority(instance: *runtime.Instance, property: typedefs.CSSOMString) anyerror!typedefs.CSSOMString {
    _ = instance;
    _ = property;
    return error.NotImplemented;
}

/// Operation: setProperty
pub fn call_setProperty(instance: *runtime.Instance, property: typedefs.CSSOMString, value: typedefs.CSSOMString, priority: webidl.Opt(typedefs.CSSOMString)) anyerror!void {
    _ = instance;
    _ = property;
    _ = value;
    _ = priority;
    return error.NotImplemented;
}

/// Operation: getPropertyValue
/// Returns the value of a CSS property.
/// For computed styles, returns computed values based on the element.
/// Per CSSOM spec: https://drafts.csswg.org/cssom/#dom-cssstyledeclaration-getpropertyvalue
pub fn call_getPropertyValue(instance: *runtime.Instance, property: typedefs.CSSOMString) anyerror!typedefs.CSSOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();

    const prop_name = property.asSlice();

    // For computed styles, return element-specific values
    if (internal.is_computed) {
        if (internal.element) |element| {
            return getComputedPropertyValue(prop_name, element);
        }
    }

    // For non-computed styles or if no element, return empty string
    return runtime.DOMString.initEmpty();
}

/// Get computed property value for an element
/// Returns default CSS values based on element type and property
fn getComputedPropertyValue(property: []const u8, element: *runtime.Instance) runtime.DOMString {
    // Handle display property - most commonly tested
    if (std.mem.eql(u8, property, "display")) {
        return runtime.DOMString.initInterned(getDefaultDisplay(element));
    }

    // Handle background-color
    if (std.mem.eql(u8, property, "background-color") or std.mem.eql(u8, property, "backgroundColor")) {
        return runtime.DOMString.initInterned("rgba(0, 0, 0, 0)");
    }

    // Handle visibility
    if (std.mem.eql(u8, property, "visibility")) {
        return runtime.DOMString.initInterned("visible");
    }

    // Handle position
    if (std.mem.eql(u8, property, "position")) {
        return runtime.DOMString.initInterned("static");
    }

    // Handle color
    if (std.mem.eql(u8, property, "color")) {
        return runtime.DOMString.initInterned("rgb(0, 0, 0)");
    }

    // Handle width/height (auto by default)
    if (std.mem.eql(u8, property, "width") or std.mem.eql(u8, property, "height")) {
        return runtime.DOMString.initInterned("auto");
    }

    // Handle margin/padding (0px by default)
    if (std.mem.startsWith(u8, property, "margin") or std.mem.startsWith(u8, property, "padding")) {
        return runtime.DOMString.initInterned("0px");
    }

    // Default: return empty string for unknown properties
    return runtime.DOMString.initEmpty();
}

/// Get the default display value for an element based on its tag name
/// Per HTML spec, different elements have different default display values
fn getDefaultDisplay(element: *runtime.Instance) []const u8 {
    // Get the element's tag name
    const elem_internal = ElementImpl.getInternal(element) orelse return "inline";
    const tag_name = elem_internal.local_name.asSlice();

    // Block-level elements
    if (isBlockElement(tag_name)) {
        return "block";
    }

    // List items
    if (std.ascii.eqlIgnoreCase(tag_name, "li")) {
        return "list-item";
    }

    // Table elements
    if (std.ascii.eqlIgnoreCase(tag_name, "table")) {
        return "table";
    }
    if (std.ascii.eqlIgnoreCase(tag_name, "tr")) {
        return "table-row";
    }
    if (std.ascii.eqlIgnoreCase(tag_name, "td") or std.ascii.eqlIgnoreCase(tag_name, "th")) {
        return "table-cell";
    }
    if (std.ascii.eqlIgnoreCase(tag_name, "thead")) {
        return "table-header-group";
    }
    if (std.ascii.eqlIgnoreCase(tag_name, "tbody")) {
        return "table-row-group";
    }
    if (std.ascii.eqlIgnoreCase(tag_name, "tfoot")) {
        return "table-footer-group";
    }
    if (std.ascii.eqlIgnoreCase(tag_name, "caption")) {
        return "table-caption";
    }
    if (std.ascii.eqlIgnoreCase(tag_name, "col")) {
        return "table-column";
    }
    if (std.ascii.eqlIgnoreCase(tag_name, "colgroup")) {
        return "table-column-group";
    }

    // Inline-block elements
    if (std.ascii.eqlIgnoreCase(tag_name, "button") or
        std.ascii.eqlIgnoreCase(tag_name, "input") or
        std.ascii.eqlIgnoreCase(tag_name, "select") or
        std.ascii.eqlIgnoreCase(tag_name, "textarea"))
    {
        return "inline-block";
    }

    // None display
    if (std.ascii.eqlIgnoreCase(tag_name, "script") or
        std.ascii.eqlIgnoreCase(tag_name, "style") or
        std.ascii.eqlIgnoreCase(tag_name, "head") or
        std.ascii.eqlIgnoreCase(tag_name, "meta") or
        std.ascii.eqlIgnoreCase(tag_name, "link") or
        std.ascii.eqlIgnoreCase(tag_name, "title") or
        std.ascii.eqlIgnoreCase(tag_name, "template"))
    {
        return "none";
    }

    // Default: inline
    return "inline";
}

/// Check if a tag name is a block-level element
fn isBlockElement(tag_name: []const u8) bool {
    const block_elements = [_][]const u8{
        "address",
        "article",
        "aside",
        "blockquote",
        "canvas",
        "dd",
        "div",
        "dl",
        "dt",
        "fieldset",
        "figcaption",
        "figure",
        "footer",
        "form",
        "h1",
        "h2",
        "h3",
        "h4",
        "h5",
        "h6",
        "header",
        "hgroup",
        "hr",
        "main",
        "nav",
        "noscript",
        "ol",
        "p",
        "pre",
        "search",
        "section",
        "ul",
        "video",
    };

    for (block_elements) |block_tag| {
        if (std.ascii.eqlIgnoreCase(tag_name, block_tag)) {
            return true;
        }
    }
    return false;
}
