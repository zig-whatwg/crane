//! Implementation for HTMLElement interface
//!
//! Spec: https://html.spec.whatwg.org/multipage/dom.html#htmlelement
//! HTML Standard §3.2.3
//!
//! HTMLElement is the base interface for all HTML elements. It provides
//! common properties and methods for elements in an HTML document.
//!
//! ## Architecture Note (Golden Rule #13)
//!
//! Per Golden Rule #13, impls should call interfaces, not other impls.
//! This file uses interfaces for cross-type calls but may use impls
//! for internal initialization and parent chaining.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const HTMLElement = interfaces.HTMLElement;

// Import parent impl for chaining initialization
const ElementImpl = @import("Element.zig");

// Import CSSStyleDeclaration impl for inline style creation
const CSSStyleDeclarationImpl = @import("CSSStyleDeclaration.zig");

// Platform layout backend for CSSOM View metrics
const layout_backend = @import("platform").layout_backend;

pub const State = HTMLElement.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    NotSupportedError,
    OutOfMemory,
};

/// Popover state enum
/// Spec: https://html.spec.whatwg.org/multipage/popover.html#attr-popover
pub const PopoverState = enum {
    none, // Not a popover
    auto, // Auto-dismiss popover
    manual, // Manual popover (no auto-dismiss)
    hint, // Hint popover (new in spec)
};

/// Internal state for HTMLElement implementation
/// Stores HTML-specific data not exposed via WebIDL attributes
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    // === Popover State ===
    /// Current popover visibility state
    /// Spec: https://html.spec.whatwg.org/multipage/popover.html#popover-visibility-state
    popover_showing: bool = false,

    /// Popover invoker element (the element that opened this popover)
    popover_invoker: ?*runtime.Instance = null,

    // === Focus State ===
    /// Whether this element has been focused programmatically
    was_focused_by_script: bool = false,

    // === Element Internals ===
    /// ElementInternals instance if attachInternals() was called
    element_internals: ?*runtime.Instance = null,

    /// Whether attachInternals() has been called (can only be called once)
    internals_attached: bool = false,

    // === Drag State ===
    /// Whether element is being dragged
    is_dragging: bool = false,

    // === Style ===
    /// Cached inline CSSStyleDeclaration wrapper for this element
    /// Note: This may be garbage collected by V8, but the properties are stored
    /// separately in inline_style_properties below
    /// Spec: https://drafts.csswg.org/cssom/#dom-elementcssinlinestyle-style
    style_declaration: ?*runtime.Instance = null,

    /// Inline style properties storage (property name -> value)
    /// These are stored here (not in CSSStyleDeclaration) so they survive V8 GC
    /// of the CSSStyleDeclaration wrapper. Properties persist as long as the element exists.
    inline_style_properties: std.StringHashMapUnmanaged([]const u8) = .{},

    /// Cached inline style cssText
    inline_style_css_text: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .popover_showing = false,
            .popover_invoker = null,
            .was_focused_by_script = false,
            .element_internals = null,
            .internals_attached = false,
            .is_dragging = false,
            .style_declaration = null,
            .inline_style_properties = .{},
            .inline_style_css_text = null,
        };
    }

    pub fn deinit(self: *InternalState) void {
        // Clean up inline style properties
        var iter = self.inline_style_properties.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.inline_style_properties.deinit(self.allocator);
        if (self.inline_style_css_text) |text| {
            self.allocator.free(text);
        }
        // Note: style_declaration runtime.Instance is owned by the GC layer, don't deinit here
    }

    /// Get inline style property value
    pub fn getInlineStyleProperty(self: *InternalState, name: []const u8) ?[]const u8 {
        return self.inline_style_properties.get(name);
    }

    /// Set inline style property value
    pub fn setInlineStyleProperty(self: *InternalState, name: []const u8, value: []const u8) !void {
        // Check if property already exists
        if (self.inline_style_properties.get(name)) |old_value| {
            // Free old value
            self.allocator.free(old_value);
            // Update with new value (key already exists, no need to dup key)
            const value_copy = try self.allocator.dupe(u8, value);
            self.inline_style_properties.putAssumeCapacity(name, value_copy);
        } else {
            // New property - need to allocate both key and value
            const name_copy = try self.allocator.dupe(u8, name);
            errdefer self.allocator.free(name_copy);
            const value_copy = try self.allocator.dupe(u8, value);
            try self.inline_style_properties.put(self.allocator, name_copy, value_copy);
        }
        // Invalidate cssText cache
        if (self.inline_style_css_text) |old_text| {
            self.allocator.free(old_text);
            self.inline_style_css_text = null;
        }
    }

    /// Remove inline style property
    pub fn removeInlineStyleProperty(self: *InternalState, name: []const u8) void {
        if (self.inline_style_properties.fetchRemove(name)) |entry| {
            self.allocator.free(entry.key);
            self.allocator.free(entry.value);
            // Invalidate cssText cache
            if (self.inline_style_css_text) |old_text| {
                self.allocator.free(old_text);
                self.inline_style_css_text = null;
            }
        }
    }

    /// Get inline style cssText
    pub fn getInlineStyleCssText(self: *InternalState) []const u8 {
        return self.inline_style_css_text orelse "";
    }

    /// Set inline style cssText (parses and updates properties)
    pub fn setInlineStyleCssText(self: *InternalState, text: []const u8) !void {
        // Clear existing properties
        var iter = self.inline_style_properties.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.inline_style_properties.clearRetainingCapacity();

        if (self.inline_style_css_text) |old_text| {
            self.allocator.free(old_text);
        }

        // Store the cssText
        self.inline_style_css_text = try self.allocator.dupe(u8, text);

        // Parse simple "property: value" pairs separated by semicolons
        var declarations = std.mem.splitScalar(u8, text, ';');
        while (declarations.next()) |decl| {
            const trimmed = std.mem.trim(u8, decl, " \t\n\r");
            if (trimmed.len == 0) continue;

            // Find the colon
            if (std.mem.indexOf(u8, trimmed, ":")) |colon_pos| {
                const prop_name = std.mem.trim(u8, trimmed[0..colon_pos], " \t");
                const prop_value = std.mem.trim(u8, trimmed[colon_pos + 1 ..], " \t");

                if (prop_name.len > 0) {
                    const name_copy = try self.allocator.dupe(u8, prop_name);
                    errdefer self.allocator.free(name_copy);
                    const value_copy = try self.allocator.dupe(u8, prop_value);
                    try self.inline_style_properties.put(self.allocator, name_copy, value_copy);
                }
            }
        }
    }

    /// Get count of inline style properties
    pub fn getInlineStylePropertyCount(self: *InternalState) u32 {
        return @intCast(self.inline_style_properties.count());
    }
};

// Use shared InstanceRegistry utility for internal state management
const utils = @import("webidl").utils;
const Registry = utils.InstanceRegistry(InternalState);

/// Get HTMLElement's internal state from the registry
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// Initialize instance (creates the instance)
/// Chains to parent class: Element -> Node -> EventTarget
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain to parent class (Element)
    const instance = try ElementImpl.init(allocator, StateType, vtable, ctx);
    errdefer ElementImpl.deinit(instance);

    // Initialize HTMLElement's own internal state in registry
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    // The registry owns this block, so `Registry.remove` returns it to the
    // arena. With `set` it was dropped from the map and held to process
    // exit - 904 bytes per discarded element, measured.
    const internal = try Registry.createIn(instance, ArenaAllocator.get());
    internal.* = InternalState.init(allocator);

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up from registry
    if (Registry.get(instance)) |internal| {
        internal.deinit();
    }
    Registry.remove(instance);
    // Parent cleanup happens via inheritance chain
    ElementImpl.deinit(instance);
}

/// Constructor implementation
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#htmlelement
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &HTMLElement.vtable, ctx);
    errdefer deinit(instance);

    // HTMLElement constructor is typically not called directly
    // Elements are created via document.createElement()

    return instance;
}

// =============================================================================
// Helper Functions for Content Attribute Reflection
// =============================================================================

/// The value of this element's content attribute `name` (no namespace), or
/// null when it has none.
fn getContentAttribute(instance: *runtime.Instance, name: []const u8) ?runtime.DOMString {
    const elem_internal = ElementImpl.getInternalState(instance) orelse return null;
    const attr = elem_internal.findAttribute(null, name) orelse return null;
    return runtime.DOMString.initInterned(attr.value);
}

/// Set content attribute `name` - DOM "set an attribute value", the setter
/// steps of a reflected attribute - so the change is observed like any other.
fn setContentAttribute(instance: *runtime.Instance, name: []const u8, value: runtime.DOMString) !void {
    try ElementImpl.setAttributeValue(instance, name, value.asSlice(), null, null);
}

/// Check if a content attribute exists
fn hasContentAttribute(instance: *runtime.Instance, name: []const u8) bool {
    const elem_internal = ElementImpl.getInternalState(instance) orelse return false;
    return elem_internal.findAttribute(null, name) != null;
}

/// Remove content attribute `name` - DOM "remove an attribute by namespace
/// and local name" with a null namespace.
fn removeContentAttribute(instance: *runtime.Instance, name: []const u8) void {
    ElementImpl.removeAttributeByNamespaceAndLocalName(instance, null, name);
}

// =============================================================================
// Content Attribute Reflection Properties
// Spec: https://html.spec.whatwg.org/multipage/dom.html#reflecting-content-attributes-in-idl-attributes
// =============================================================================

/// Getter for title
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#attr-title
/// Reflects the title content attribute
pub fn get_title(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return getContentAttribute(instance, "title") orelse runtime.DOMString.initEmpty();
}

/// Getter for lang
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#attr-lang
/// Reflects the lang content attribute
pub fn get_lang(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return getContentAttribute(instance, "lang") orelse runtime.DOMString.initEmpty();
}

/// Getter for translate
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#attr-translate
/// Returns true if translate is "yes" or missing (inherit), false if "no"
pub fn get_translate(instance: *runtime.Instance) anyerror!bool {
    if (getContentAttribute(instance, "translate")) |value| {
        const s = value.asSlice();
        // "no" means don't translate
        if (std.mem.eql(u8, s, "no")) return false;
        // "yes" or any other value means translate
        return true;
    }
    // Missing attribute: inherit from parent (default to true)
    return true;
}

/// Getter for dir
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#attr-dir
/// Reflects the dir content attribute (ltr, rtl, auto, or "")
pub fn get_dir(instance: *runtime.Instance) anyerror!runtime.DOMString {
    if (getContentAttribute(instance, "dir")) |value| {
        const s = value.asSlice();
        // Only valid values are returned; invalid values return ""
        if (std.mem.eql(u8, s, "ltr") or
            std.mem.eql(u8, s, "rtl") or
            std.mem.eql(u8, s, "auto"))
        {
            return value;
        }
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for hidden
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#the-hidden-attribute
/// Returns null (not hidden), true ("hidden"), or "until-found"
pub fn get_hidden(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    if (getContentAttribute(instance, "hidden")) |value| {
        const s = value.asSlice();
        if (std.mem.eql(u8, s, "until-found")) {
            // Return the string "until-found"
            return runtime.JSValue.fromStringRef("until-found");
        }
        // Any other value (including empty) means hidden=true
        return runtime.JSValue.fromBoolean(true);
    }
    return null; // Not hidden
}

/// Getter for inert
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#the-inert-attribute
/// Boolean attribute
pub fn get_inert(instance: *runtime.Instance) anyerror!bool {
    return hasContentAttribute(instance, "inert");
}

/// Getter for accessKey
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#the-accesskey-attribute
pub fn get_accessKey(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return getContentAttribute(instance, "accesskey") orelse runtime.DOMString.initEmpty();
}

/// Getter for accessKeyLabel
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-accesskeylabel
/// Returns the assigned access key (computed, may differ from accessKey attribute)
pub fn get_accessKeyLabel(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // Simplified: return the accesskey attribute value
    // Full implementation would compute the actual key label based on platform
    return getContentAttribute(instance, "accesskey") orelse runtime.DOMString.initEmpty();
}

/// Getter for draggable
/// Spec: https://html.spec.whatwg.org/multipage/dnd.html#the-draggable-attribute
/// Returns true if draggable="true", false if "false", auto-determined otherwise
pub fn get_draggable(instance: *runtime.Instance) anyerror!bool {
    if (getContentAttribute(instance, "draggable")) |value| {
        const s = value.asSlice();
        if (std.mem.eql(u8, s, "true")) return true;
        if (std.mem.eql(u8, s, "false")) return false;
    }
    // Auto: images and links are draggable by default
    // Simplified: return false for auto
    return false;
}

/// Getter for spellcheck
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#spelling-and-grammar-checking
pub fn get_spellcheck(instance: *runtime.Instance) anyerror!bool {
    if (getContentAttribute(instance, "spellcheck")) |value| {
        const s = value.asSlice();
        if (std.mem.eql(u8, s, "true") or s.len == 0) return true;
        if (std.mem.eql(u8, s, "false")) return false;
    }
    // Default: inherited or element-dependent
    return true;
}

/// Getter for writingSuggestions
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#attr-writingsuggestions
pub fn get_writingSuggestions(instance: *runtime.Instance) anyerror!runtime.DOMString {
    if (getContentAttribute(instance, "writingsuggestions")) |value| {
        const s = value.asSlice();
        if (std.mem.eql(u8, s, "true") or std.mem.eql(u8, s, "false")) {
            return value;
        }
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for autocapitalize
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#attr-autocapitalize
pub fn get_autocapitalize(instance: *runtime.Instance) anyerror!runtime.DOMString {
    if (getContentAttribute(instance, "autocapitalize")) |value| {
        const s = value.asSlice();
        // Valid values: off/none, on/sentences, words, characters
        if (std.mem.eql(u8, s, "off") or std.mem.eql(u8, s, "none") or
            std.mem.eql(u8, s, "on") or std.mem.eql(u8, s, "sentences") or
            std.mem.eql(u8, s, "words") or std.mem.eql(u8, s, "characters"))
        {
            return value;
        }
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for autocorrect
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#attr-autocorrect
pub fn get_autocorrect(instance: *runtime.Instance) anyerror!bool {
    if (getContentAttribute(instance, "autocorrect")) |value| {
        const s = value.asSlice();
        if (std.mem.eql(u8, s, "off")) return false;
    }
    return true; // Default is on
}

/// Getter for innerText
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#the-innertext-idl-attribute
/// Returns the rendered text content (layout-dependent)
pub fn get_innerText(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // Get text content - in a full implementation this would use the layout backend
    // For now, fall back to textContent-like behavior
    const NodeImpl = @import("Node.zig");

    // Use Node's textContent as fallback
    if (try NodeImpl.get_textContent(instance)) |text| {
        return text;
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for outerText
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#the-outertext-idl-attribute
/// Same as innerText for getter
pub fn get_outerText(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return get_innerText(instance);
}

/// Getter for popover
/// Spec: https://html.spec.whatwg.org/multipage/popover.html#attr-popover
pub fn get_popover(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    if (getContentAttribute(instance, "popover")) |value| {
        const s = value.asSlice();
        // Normalize to canonical values
        if (s.len == 0 or std.mem.eql(u8, s, "auto")) {
            return runtime.DOMString.initInterned("auto");
        }
        if (std.mem.eql(u8, s, "manual")) {
            return runtime.DOMString.initInterned("manual");
        }
        if (std.mem.eql(u8, s, "hint")) {
            return runtime.DOMString.initInterned("hint");
        }
        // Invalid value: treat as "auto"
        return runtime.DOMString.initInterned("auto");
    }
    return null; // Not a popover
}

/// Getter for headingOffset
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#attr-headingoffset
pub fn get_headingOffset(instance: *runtime.Instance) anyerror!u32 {
    if (getContentAttribute(instance, "headingoffset")) |value| {
        const s = value.asSlice();
        // Parse as unsigned integer
        return std.fmt.parseInt(u32, s, 10) catch 0;
    }
    return 0;
}

/// Getter for headingReset
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#attr-headingreset
/// Boolean attribute
pub fn get_headingReset(instance: *runtime.Instance) anyerror!bool {
    return hasContentAttribute(instance, "headingreset");
}

/// Getter for editContext
/// Spec: https://w3c.github.io/edit-context/#dom-htmlelement-editcontext
pub fn get_editContext(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    // EditContext is not yet widely implemented
    // Return null for now
    _ = instance;
    return null;
}

/// Getter for scrollParent
/// Spec: CSSOM View - returns the nearest scrollable ancestor
pub fn get_scrollParent(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    // Would need to traverse ancestors and check for overflow: scroll/auto
    // Simplified: return null (document is scroll parent)
    _ = instance;
    return null;
}

// =============================================================================
// CSSOM View Properties (Layout-Dependent)
// Spec: https://drafts.csswg.org/cssom-view/#extensions-to-the-htmlelement-interface
// =============================================================================

/// Getter for offsetParent
/// Spec: https://drafts.csswg.org/cssom-view/#dom-htmlelement-offsetparent
pub fn get_offsetParent(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    // Would need layout backend to determine this properly
    // The offsetParent is the nearest positioned ancestor
    _ = instance;
    return null;
}

/// Getter for offsetTop
/// Spec: https://drafts.csswg.org/cssom-view/#dom-htmlelement-offsettop
pub fn get_offsetTop(instance: *runtime.Instance) anyerror!i32 {
    // Requires layout computation
    _ = instance;
    return 0;
}

/// Getter for offsetLeft
/// Spec: https://drafts.csswg.org/cssom-view/#dom-htmlelement-offsetleft
pub fn get_offsetLeft(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return 0;
}

/// Getter for offsetWidth
/// Spec: https://drafts.csswg.org/cssom-view/#dom-htmlelement-offsetwidth
pub fn get_offsetWidth(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return 0;
}

/// Getter for offsetHeight
/// Spec: https://drafts.csswg.org/cssom-view/#dom-htmlelement-offsetheight
pub fn get_offsetHeight(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return 0;
}

/// Getter for style
/// Spec: https://drafts.csswg.org/cssom/#dom-elementcssinlinestyle-style
/// Returns the inline CSSStyleDeclaration for this element.
/// Each element has exactly one associated inline CSSStyleDeclaration object.
/// Note: CSS properties are stored in HTMLElement's InternalState, not in the CSSStyleDeclaration.
/// This allows properties to survive V8 GC of the CSSStyleDeclaration wrapper.
pub fn get_style(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // Get internal state to check for cached style declaration
    const internal = getInternalState(instance) orelse return error.InvalidStateError;

    // Return cached style declaration if it exists
    if (internal.style_declaration) |style| {
        return style;
    }

    // Create a new CSSStyleDeclaration for inline styles
    const allocator = instance.ctx.allocator;
    const ctx = instance.ctx;
    const CSSStyleDeclaration = interfaces.CSSStyleDeclaration;

    // Initialize the style declaration using initForInlineStyle
    // This sets is_inline_style=true and stores the owner element reference
    // Properties will be delegated to this HTMLElement's InternalState
    const style = try CSSStyleDeclarationImpl.initForInlineStyle(
        allocator,
        CSSStyleDeclaration.State,
        &CSSStyleDeclaration.vtable,
        ctx,
        instance, // owner element
    );
    errdefer CSSStyleDeclaration.deinit(style);

    // Cache it in internal state for future access
    internal.style_declaration = style;

    return style;
}

/// Getter for attributeStyleMap
/// Spec: https://drafts.css-houdini.org/css-typed-om-1/#dom-elementcssinlinestyle-attributestylemap
pub fn get_attributeStyleMap(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // Would return a StylePropertyMap instance
    _ = instance;
    return error.NotImplemented;
}

// =============================================================================
// ElementContentEditable Mixin Properties
// Spec: https://html.spec.whatwg.org/multipage/interaction.html#elementcontenteditable
// =============================================================================

/// Getter for contentEditable
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-contenteditable
pub fn get_contentEditable(instance: *runtime.Instance) anyerror!runtime.DOMString {
    if (getContentAttribute(instance, "contenteditable")) |value| {
        const s = value.asSlice();
        if (std.mem.eql(u8, s, "true") or s.len == 0) {
            return runtime.DOMString.initInterned("true");
        }
        if (std.mem.eql(u8, s, "false")) {
            return runtime.DOMString.initInterned("false");
        }
        if (std.mem.eql(u8, s, "plaintext-only")) {
            return runtime.DOMString.initInterned("plaintext-only");
        }
    }
    return runtime.DOMString.initInterned("inherit");
}

/// Getter for enterKeyHint
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#attr-enterkeyhint
pub fn get_enterKeyHint(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return getContentAttribute(instance, "enterkeyhint") orelse runtime.DOMString.initEmpty();
}

/// Getter for isContentEditable
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-iscontenteditable
pub fn get_isContentEditable(instance: *runtime.Instance) anyerror!bool {
    const ce = try get_contentEditable(instance);
    const s = ce.asSlice();
    if (std.mem.eql(u8, s, "true") or std.mem.eql(u8, s, "plaintext-only")) {
        return true;
    }
    // Inherit - would need to check parent, simplified to false
    return false;
}

/// Getter for inputMode
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#attr-inputmode
pub fn get_inputMode(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return getContentAttribute(instance, "inputmode") orelse runtime.DOMString.initEmpty();
}

/// Getter for virtualKeyboardPolicy
/// Spec: https://w3c.github.io/virtual-keyboard/#dom-elementcontenteditable-virtualkeyboardpolicy
pub fn get_virtualKeyboardPolicy(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return getContentAttribute(instance, "virtualkeyboardpolicy") orelse runtime.DOMString.initEmpty();
}

// =============================================================================
// HTMLOrSVGElement Mixin Properties
// Spec: https://html.spec.whatwg.org/multipage/dom.html#htmlorsvgelement
// =============================================================================

/// Getter for dataset
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-dataset
/// Returns a DOMStringMap for data-* attributes
pub fn get_dataset(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const DOMStringMapImpl = @import("DOMStringMap.zig");
    return DOMStringMapImpl.create(instance.ctx.allocator, instance.ctx, instance);
}

/// Getter for nonce
/// Spec: https://html.spec.whatwg.org/multipage/urls-and-fetching.html#dom-noncedelement-nonce
pub fn get_nonce(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return getContentAttribute(instance, "nonce") orelse runtime.DOMString.initEmpty();
}

/// Getter for autofocus
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-fe-autofocus
pub fn get_autofocus(instance: *runtime.Instance) anyerror!bool {
    return hasContentAttribute(instance, "autofocus");
}

/// Getter for tabIndex
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-tabindex
pub fn get_tabIndex(instance: *runtime.Instance) anyerror!i32 {
    if (getContentAttribute(instance, "tabindex")) |value| {
        return std.fmt.parseInt(i32, value.asSlice(), 10) catch -1;
    }
    // Default depends on element type; -1 for most
    return -1;
}

// =============================================================================
// Content Attribute Reflection Setters
// =============================================================================

/// Setter for title
pub fn set_title(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "title", value);
}

/// Setter for lang
pub fn set_lang(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "lang", value);
}

/// Setter for translate
pub fn set_translate(instance: *runtime.Instance, value: bool) anyerror!void {
    if (value) {
        try setContentAttribute(instance, "translate", runtime.DOMString.initInterned("yes"));
    } else {
        try setContentAttribute(instance, "translate", runtime.DOMString.initInterned("no"));
    }
}

/// Setter for dir
pub fn set_dir(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "dir", value);
}

/// Setter for hidden
/// Complex type: can be boolean, null, or "until-found"
pub fn set_hidden(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    // Simplified: treat as boolean
    // The value pointer being non-null means hidden is set
    // In full implementation, would check if it's "until-found" string
    _ = value;
    // For now, always set hidden when this is called with any non-null value
    try setContentAttribute(instance, "hidden", runtime.DOMString.initEmpty());
}

/// Setter for inert
pub fn set_inert(instance: *runtime.Instance, value: bool) anyerror!void {
    if (value) {
        try setContentAttribute(instance, "inert", runtime.DOMString.initEmpty());
    } else {
        removeContentAttribute(instance, "inert");
    }
}

/// Setter for accessKey
pub fn set_accessKey(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "accesskey", value);
}

/// Setter for draggable
pub fn set_draggable(instance: *runtime.Instance, value: bool) anyerror!void {
    if (value) {
        try setContentAttribute(instance, "draggable", runtime.DOMString.initInterned("true"));
    } else {
        try setContentAttribute(instance, "draggable", runtime.DOMString.initInterned("false"));
    }
}

/// Setter for spellcheck
pub fn set_spellcheck(instance: *runtime.Instance, value: bool) anyerror!void {
    if (value) {
        try setContentAttribute(instance, "spellcheck", runtime.DOMString.initInterned("true"));
    } else {
        try setContentAttribute(instance, "spellcheck", runtime.DOMString.initInterned("false"));
    }
}

/// Setter for writingSuggestions
pub fn set_writingSuggestions(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "writingsuggestions", value);
}

/// Setter for autocapitalize
pub fn set_autocapitalize(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "autocapitalize", value);
}

/// Setter for autocorrect
pub fn set_autocorrect(instance: *runtime.Instance, value: bool) anyerror!void {
    if (value) {
        try setContentAttribute(instance, "autocorrect", runtime.DOMString.initInterned("on"));
    } else {
        try setContentAttribute(instance, "autocorrect", runtime.DOMString.initInterned("off"));
    }
}

/// Setter for innerText
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#the-innertext-idl-attribute
pub fn set_innerText(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // Setting innerText replaces all children with text nodes
    // This is a simplified implementation - use Node's textContent setter
    const NodeImpl = @import("Node.zig");
    try NodeImpl.set_textContent(instance, value);
}

/// Setter for outerText
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#the-outertext-idl-attribute
pub fn set_outerText(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // Setting outerText replaces the element with text nodes
    // Simplified: just set inner text (full impl would replace element)
    try set_innerText(instance, value);
}

/// Setter for popover
pub fn set_popover(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    if (value) |v| {
        const s = v.asSlice();
        if (s.len == 0) {
            removeContentAttribute(instance, "popover");
        } else {
            try setContentAttribute(instance, "popover", v);
        }
    } else {
        removeContentAttribute(instance, "popover");
    }
}

/// Setter for headingOffset
pub fn set_headingOffset(instance: *runtime.Instance, value: u32) anyerror!void {
    var buf: [16]u8 = undefined;
    const str = std.fmt.bufPrint(&buf, "{d}", .{value}) catch return;
    try setContentAttribute(instance, "headingoffset", runtime.DOMString.initInterned(str));
}

/// Setter for headingReset
pub fn set_headingReset(instance: *runtime.Instance, value: bool) anyerror!void {
    if (value) {
        try setContentAttribute(instance, "headingreset", runtime.DOMString.initEmpty());
    } else {
        removeContentAttribute(instance, "headingreset");
    }
}

/// Setter for editContext
pub fn set_editContext(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    // EditContext is not yet widely implemented
    _ = instance;
    _ = value;
}

// =============================================================================
// ElementContentEditable Mixin Setters
// =============================================================================

pub fn set_contentEditable(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "contenteditable", value);
}

pub fn set_enterKeyHint(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "enterkeyhint", value);
}

pub fn set_inputMode(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "inputmode", value);
}

pub fn set_virtualKeyboardPolicy(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "virtualkeyboardpolicy", value);
}

// =============================================================================
// HTMLOrSVGElement Mixin Setters
// =============================================================================

pub fn set_nonce(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "nonce", value);
}

pub fn set_autofocus(instance: *runtime.Instance, value: bool) anyerror!void {
    if (value) {
        try setContentAttribute(instance, "autofocus", runtime.DOMString.initEmpty());
    } else {
        removeContentAttribute(instance, "autofocus");
    }
}

pub fn set_tabIndex(instance: *runtime.Instance, value: i32) anyerror!void {
    var buf: [16]u8 = undefined;
    const str = std.fmt.bufPrint(&buf, "{d}", .{value}) catch return;
    try setContentAttribute(instance, "tabindex", runtime.DOMString.initInterned(str));
}

// =============================================================================
// Operations
// =============================================================================

/// Operation: togglePopover
/// Spec: https://html.spec.whatwg.org/multipage/popover.html#dom-togglepopover
pub fn call_togglePopover(instance: *runtime.Instance, options: webidl.Opt(runtime.JSValue)) anyerror!bool {
    const internal = getInternalState(instance) orelse return error.InvalidStateError;
    _ = options; // ShowPopoverOptions - simplified for now

    // Check if this is a popover
    if ((try get_popover(instance)) == null) {
        return error.NotSupportedError;
    }

    if (internal.popover_showing) {
        try call_hidePopover(instance);
        return false;
    } else {
        try call_showPopover(instance, webidl.Opt(dictionaries.ShowPopoverOptions).notPassed());
        return true;
    }
}

/// Operation: blur
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-blur
pub fn call_blur(instance: *runtime.Instance) anyerror!void {
    // Run the unfocusing steps
    // In a full implementation, this would:
    // 1. Remove focus from this element
    // 2. Fire blur event
    // 3. Update document.activeElement
    const internal = getInternalState(instance) orelse return;
    internal.was_focused_by_script = false;

    // Fire blur event (simplified)
    // TODO(events): fire "blur" at the element - nothing is dispatched
    // yet. (This used to read the onblur handler and drop it.)
}

/// Operation: click
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-click
pub fn call_click(instance: *runtime.Instance) anyerror!void {
    // Fire a click event at this element
    // In a full implementation, this would:
    // 1. Create a MouseEvent with type "click"
    // 2. Set bubbles=true, cancelable=true
    // 3. Dispatch the event via EventTarget.dispatchEvent()

    // TODO(events): "fire a synthetic pointer event named click" at the
    // element, with activation behaviour - nothing is dispatched yet. (This
    // used to read the onclick handler and drop it.)
    _ = instance;
}

/// Operation: showPopover
/// Spec: https://html.spec.whatwg.org/multipage/popover.html#dom-showpopover
pub fn call_showPopover(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ShowPopoverOptions)) anyerror!void {
    const internal = getInternalState(instance) orelse return error.InvalidStateError;
    _ = options; // ShowPopoverOptions - simplified for now

    // Check if this is a popover
    if ((try get_popover(instance)) == null) {
        return error.NotSupportedError;
    }

    // Check if already showing
    if (internal.popover_showing) {
        return error.InvalidStateError;
    }

    // Fire beforetoggle event
    // TODO(events): fire "beforetoggle" at the element - nothing is dispatched
    // yet. (This used to read the onbeforetoggle handler and drop it.)

    // Show the popover (add to top layer)
    internal.popover_showing = true;

    // Fire toggle event
    // TODO(events): fire "toggle" at the element - nothing is dispatched
    // yet. (This used to read the ontoggle handler and drop it.)
}

/// Operation: hidePopover
/// Spec: https://html.spec.whatwg.org/multipage/popover.html#dom-hidepopover
pub fn call_hidePopover(instance: *runtime.Instance) anyerror!void {
    const internal = getInternalState(instance) orelse return error.InvalidStateError;

    // Check if this is a popover
    if ((try get_popover(instance)) == null) {
        return error.NotSupportedError;
    }

    // Check if already hidden
    if (!internal.popover_showing) {
        return error.InvalidStateError;
    }

    // Fire beforetoggle event
    // TODO(events): fire "beforetoggle" at the element - nothing is dispatched
    // yet. (This used to read the onbeforetoggle handler and drop it.)

    // Hide the popover (remove from top layer)
    internal.popover_showing = false;
    internal.popover_invoker = null;

    // Fire toggle event
    // TODO(events): fire "toggle" at the element - nothing is dispatched
    // yet. (This used to read the ontoggle handler and drop it.)
}

/// Operation: focus
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-focus
///
/// The focus(options) method steps are:
/// 1. If this element is a focusable element, run the focusing steps for it.
/// 2. Otherwise, do nothing.
///
/// For now, we implement a simplified version that:
/// - Updates document.activeElement
/// - Fires focus event
/// - TODO: Check focusability, handle preventScroll option
pub fn call_focus(instance: *runtime.Instance, options: webidl.Opt(dictionaries.FocusOptions)) anyerror!void {
    const internal = getInternalState(instance) orelse return;
    _ = options; // FocusOptions - preventScroll, focusVisible

    // Mark as focused by script
    internal.was_focused_by_script = true;

    // Get the owner document and update its activeElement
    // Per spec: "the Document of the area element is the active document of the
    // browsing context, and its activeElement is the element"
    const NodeImpl = @import("Node.zig");
    if (NodeImpl.get_ownerDocument(instance) catch null) |owner_doc| {
        const DocumentImpl = @import("Document.zig");
        DocumentImpl.setActiveElement(owner_doc, instance);
    }

    // Fire focus event (simplified)
    // TODO: Fire proper FocusEvent with relatedTarget
    // TODO(events): fire "focus" at the element - nothing is dispatched
    // yet. (This used to read the onfocus handler and drop it.)
}

/// Operation: attachInternals
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#dom-attachinternals
pub fn call_attachInternals(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternalState(instance) orelse return error.InvalidStateError;

    // Check if internals already attached
    if (internal.internals_attached) {
        return error.NotSupportedError;
    }

    // Mark as attached
    internal.internals_attached = true;

    // Create and return ElementInternals instance
    // For now, this is not fully implemented
    return error.NotImplemented;
}

/// Clean up ALL remaining internal states.
pub fn cleanupAllRemainingInternal() void {
    Registry.deinitAllAndClear();
}
