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

const dom = @import("dom");
// An element's attributes and local name, read in place (dom.element_data,
// which Element installs); written through dom.element_attributes.
const element_data = dom.element_data;

// [SameObject] children kept for the element's life (element.style).
const same_object = @import("same_object.zig");

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

    /// HTML 2.5.6 [[CryptographicNonce]], owned independently of the content
    /// attribute. Null means unused/removed; an explicitly empty slot may
    /// still accompany a nonempty attribute that must hide on connection.
    cryptographic_nonce: ?[]u8 = null,

    // === Popover State ===
    /// Current popover visibility state
    /// Spec: https://html.spec.whatwg.org/multipage/popover.html#popover-visibility-state
    popover_showing: bool = false,

    /// Popover invoker element (the element that opened this popover)
    popover_invoker: ?*runtime.Instance = null,

    // === Focus State ===
    /// Whether this element has been focused programmatically
    was_focused_by_script: bool = false,

    /// HTML "click in progress flag" (click() steps 2-5): a click() reached
    /// again from its own event's handlers does nothing.
    click_in_progress: bool = false,

    // === Element Internals ===
    /// ElementInternals instance if attachInternals() was called
    element_internals: ?*runtime.Instance = null,
    internals_traced: bool = false,

    /// Whether attachInternals() has been called (can only be called once)
    internals_attached: bool = false,

    // === Drag State ===
    /// Whether element is being dragged
    is_dragging: bool = false,

    // === Style ===
    /// element.style ([SameObject]): the CSSStyleProperties over the
    /// element's inline declaration block. The block is the element's
    /// (dom.style.inline_style, in its style state), so it outlives this
    /// object; the object itself is kept for the element's life
    /// (`style_declaration_kept`).
    /// Spec: https://drafts.csswg.org/cssom/#dom-elementcssinlinestyle-style
    style_declaration: ?*runtime.Instance = null,
    style_declaration_kept: same_object.KeptChild = .{},

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .cryptographic_nonce = null,
            .popover_showing = false,
            .popover_invoker = null,
            .was_focused_by_script = false,
            .element_internals = null,
            .internals_attached = false,
            .is_dragging = false,
            .style_declaration = null,
        };
    }

    pub fn deinit(self: *InternalState) void {
        if (self.cryptographic_nonce) |nonce| self.allocator.free(nonce);
        // element.style is severed from the element (its wrapper, which the
        // element's traced, goes with the element's).
        if (self.style_declaration) |style| self.style_declaration_kept.release(style, interfaces.CSSStyleProperties.deinit);
        self.style_declaration = null;
    }
};

// Use shared InstanceRegistry utility for internal state management
const utils = @import("webidl").utils;
const Registry = runtime.InstanceRegistry(.html_element, InternalState);

/// Get HTMLElement's internal state from the registry
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// HTMLElement's own construction steps: the generated chain runs Element's first.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    // Initialize HTMLElement's own internal state in registry
    // The registry owns this block, so `Registry.remove` returns it to the
    // arena. With `set` it was dropped from the map and held to process
    // exit - 904 bytes per discarded element, measured.
    const internal = try Registry.createIn(instance, runtime.arenaOf(instance));
    internal.* = InternalState.init(allocator);
}

/// HTMLElement's own teardown: the generated chain runs Element's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    // Clean up from registry
    if (Registry.get(instance)) |internal| {
        if (internal.internals_traced) @import("engine").forgetTracedChild(instance, .{ .name = "elementInternals" });
        if (!internal.internals_traced) if (internal.element_internals) |internals| runtime.Instance.deinit(internals);
        internal.deinit();
    }
    Registry.remove(instance);
}

/// Constructor implementation
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#htmlelement
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const instance = try HTMLElement.init(ctx.allocator, ctx);
    errdefer HTMLElement.deinit(instance);

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
    const data = element_data.of(instance) orelse return null;
    const attr = element_data.getAttributeByNamespaceAndLocalName(data, null, name) orelse return null;
    return runtime.DOMString.initInterned(attr.value);
}

/// Set content attribute `name` - DOM "set an attribute value", the setter
/// steps of a reflected attribute - so the change is observed like any other.
fn setContentAttribute(instance: *runtime.Instance, name: []const u8, value: runtime.DOMString) !void {
    try dom.element_attributes.set(instance, name, value.asSlice(), .{});
}

/// Remove content attribute `name` - DOM "remove an attribute by namespace
/// and local name" with a null namespace.
fn removeContentAttribute(instance: *runtime.Instance, name: []const u8) void {
    dom.element_attributes.remove(instance, null, name);
}

// =============================================================================
// Content Attribute Reflection Properties
// Spec: https://html.spec.whatwg.org/multipage/dom.html#reflecting-content-attributes-in-idl-attributes
// =============================================================================

/// Getter for translate
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#attr-translate
/// HTML 3.2.6.3: the computed translation mode, inherited through parent elements.
pub fn get_translate(instance: *runtime.Instance) anyerror!bool {
    var current: ?*runtime.Instance = instance;
    while (current) |element| : (current = try interfaces.Node.get_parentElement(element)) {
        // Only HTML elements have a translate content attribute. Foreign
        // elements still inherit a mode, ignoring an attribute of this name.
        var namespace = try interfaces.Element.get_namespaceURI(element);
        defer if (namespace) |*value| value.deinit(element.ctx.allocator);
        if (namespace == null or !std.mem.eql(u8, namespace.?.asSlice(), "http://www.w3.org/1999/xhtml")) continue;
        var attribute = try interfaces.Element.call_getAttributeNS(element, null, runtime.DOMString.initInterned("translate"));
        defer if (attribute) |*value| value.deinit(element.ctx.allocator);
        if (attribute) |value| {
            const keyword = value.asSlice();
            // Enumerated states: empty/yes -> Yes; no -> No. Missing and
            // invalid values -> Inherit. Keywords are ASCII case-insensitive.
            if (keyword.len == 0 or std.ascii.eqlIgnoreCase(keyword, "yes")) return true;
            if (std.ascii.eqlIgnoreCase(keyword, "no")) return false;
        }
    }
    // No parent element (including a DocumentFragment/ShadowRoot): enabled.
    return true;
}

/// Getter for dir
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#attr-dir
/// Reflects the dir content attribute (ltr, rtl, auto, or "")
pub fn get_dir(instance: *runtime.Instance) anyerror!runtime.DOMString {
    var attribute = try interfaces.Element.call_getAttributeNS(instance, null, runtime.DOMString.initInterned("dir"));
    defer if (attribute) |*value| value.deinit(instance.ctx.allocator);
    if (attribute) |value| {
        const s = value.asSlice();
        // HTML reflection, limited to known values: return the canonical
        // keyword for the state, rather than the spelling in the attribute.
        inline for (.{ "ltr", "rtl", "auto" }) |keyword|
            if (std.ascii.eqlIgnoreCase(s, keyword)) return runtime.DOMString.initInterned(keyword);
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for hidden
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#the-hidden-attribute
/// Returns false, true, or "until-found".
pub fn get_hidden(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    if (getContentAttribute(instance, "hidden")) |value| {
        // Getter step 1: the enumerated Hidden Until Found state.
        if (std.ascii.eqlIgnoreCase(value.asSlice(), "until-found")) {
            return runtime.JSValue.fromStringRef("until-found");
        }
        // Step 2: any other present attribute means hidden.
        return runtime.JSValue.fromBoolean(true);
    }
    // Step 3: absence is the boolean false, not the nullable union's null.
    return runtime.JSValue.fromBoolean(false);
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
    // Use Node's textContent as fallback
    if (try interfaces.Node.get_textContent(instance)) |text| {
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
/// The declarations are the element's inline block (dom.style), not the
/// object's, so they survive V8 GC of the object's wrapper.
pub fn get_style(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // Get internal state to check for cached style declaration
    const internal = getInternalState(instance) orelse return error.InvalidStateError;

    // The same object for the element's whole life.
    if (internal.style_declaration) |style| {
        internal.style_declaration_kept.handOut(instance, style, .{ .name = "style" });
        return style;
    }

    // "A CSSStyleProperties object whose readonly flag is unset, whose parent
    // CSS rule is null, and whose owner node is this."
    const style = try interfaces.CSSStyleProperties.initWith(instance.ctx.allocator, instance.ctx, .{ .inline_owner = instance });
    internal.style_declaration = style;
    internal.style_declaration_kept.made(style);
    internal.style_declaration_kept.handOut(instance, style, .{ .name = "style" });
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
    var attribute = try interfaces.Element.call_getAttributeNS(instance, null, runtime.DOMString.initInterned("contenteditable"));
    defer if (attribute) |*value| value.deinit(instance.ctx.allocator);
    if (attribute) |value| {
        const keyword = value.asSlice();
        // HTML 6.8.1: empty is True, missing/invalid is Inherit. Return the
        // canonical keyword of the enumerated state.
        if (keyword.len == 0) return runtime.DOMString.initInterned("true");
        inline for (.{ "true", "false", "plaintext-only" }) |state|
            if (std.ascii.eqlIgnoreCase(keyword, state)) return runtime.DOMString.initInterned(state);
    }
    return runtime.DOMString.initInterned("inherit");
}

/// Getter for enterKeyHint
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#attr-enterkeyhint
pub fn get_enterKeyHint(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return dom.reflection.getEnumerated(runtime.DOMString, instance, .{
        .name = "enterkeyhint",
        .keywords = &.{ "enter", "done", "go", "next", "previous", "search", "send" },
    });
}

/// Getter for isContentEditable
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-iscontenteditable
// Browser binding comparison, 2026-10-10 (Q14): Blink's
// HTMLElement::isContentEditableForBinding and Gecko's nsGenericHTMLElement
// use contenteditable without an activity gate. WebKit Node::isContentEditable
// additionally rejects documents that cannot render; follow the 2/3 majority.
// https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/html/html_element.cc
// https://searchfox.org/mozilla-central/source/dom/html/nsGenericHTMLElement.cpp
// https://github.com/WebKit/WebKit/blob/main/Source/WebCore/dom/Node.cpp
// Upstream contenteditable-enumerated-ascii-case-insensitive.html is 24/24
// in stable Chrome 154, Firefox 157 and Safari 27 (wpt.fyi, 2026-10-10).
pub fn get_isContentEditable(instance: *runtime.Instance) anyerror!bool {
    var current: ?*runtime.Instance = instance;
    while (current) |element| {
        var namespace = try interfaces.Element.get_namespaceURI(element);
        defer if (namespace) |*value| value.deinit(element.ctx.allocator);
        const ns = if (namespace) |value| value.asSlice() else "";
        const is_html = std.mem.eql(u8, ns, "http://www.w3.org/1999/xhtml");
        const parent = try interfaces.Node.get_parentNode(element);
        if (is_html) {
            var state = try interfaces.HTMLElement.get_contentEditable(element);
            defer state.deinit(element.ctx.allocator);
            const value = state.asSlice();
            // HTML 6.8.4: either explicit state establishes an editing host.
            if (std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "plaintext-only")) return true;
            // An HTML child of a design-mode document is an editing host,
            // even if it is not itself editable (the false state).
            if (parent) |node| {
                if (try interfaces.Node.get_nodeType(node) == interfaces.Node.get_DOCUMENT_NODE()) {
                    var mode = try interfaces.Document.get_designMode(node);
                    defer mode.deinit(node.ctx.allocator);
                    return std.mem.eql(u8, mode.asSlice(), "on");
                }
            }
            if (std.mem.eql(u8, value, "false")) return false;
        } else {
            // execCommand's "editable" definition (specs/w3c/execCommand.md):
            // only HTML elements and the SVG svg/MathML math roots inherit
            // editability. Arbitrary foreign descendants end the chain.
            var name = try interfaces.Element.get_localName(element);
            defer name.deinit(element.ctx.allocator);
            if (!((std.mem.eql(u8, ns, "http://www.w3.org/2000/svg") and std.mem.eql(u8, name.asSlice(), "svg")) or
                (std.mem.eql(u8, ns, "http://www.w3.org/1998/Math/MathML") and std.mem.eql(u8, name.asSlice(), "math")))) return false;
        }
        // Inherit through the light-tree parent. Documents/fragments are not
        // editable, so detached and shadow roots stop here.
        current = if (parent) |node|
            if (try interfaces.Node.get_nodeType(node) == interfaces.Node.get_ELEMENT_NODE()) node else null
        else
            null;
    }
    return false;
}

/// Getter for inputMode
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#attr-inputmode
pub fn get_inputMode(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return dom.reflection.getEnumerated(runtime.DOMString, instance, .{
        .name = "inputmode",
        .keywords = &.{ "none", "text", "tel", "url", "email", "numeric", "decimal", "search" },
    });
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
    // HTML 2.5.6: the IDL attribute reads the private slot. Its result is
    // the caller's, valid even after the element changes or is destroyed.
    return runtime.DOMString.initDupe(instance.ctx.allocator, nonceValueOf(instance));
}

/// Getter for tabIndex
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-tabindex
pub fn get_tabIndex(instance: *runtime.Instance) anyerror!i32 {
    // Getter steps 1-2: HTML's integer prefix parser, then the IDL long range.
    if (getContentAttribute(instance, "tabindex")) |value| {
        if (dom.reflection.parseInteger(value.asSlice())) |parsed| {
            if (parsed >= std.math.minInt(i32) and parsed <= std.math.maxInt(i32)) return @intCast(parsed);
        }
    }
    // Step 3: historical defaults depend on the element's name, not its
    // current focusability (disabled and hidden inputs still default to 0).
    const data = element_data.of(instance) orelse return -1;
    const namespace = data.namespaceSlice() orelse return -1;
    const name = data.local_name.asSlice();
    const html_namespace = "http://www.w3.org/1999/xhtml";
    if (std.mem.eql(u8, namespace, html_namespace)) {
        inline for (.{ "a", "area", "button", "frame", "iframe", "input", "object", "select", "textarea" }) |tag| {
            if (std.mem.eql(u8, name, tag)) return 0;
        }
        if (std.mem.eql(u8, name, "summary")) {
            const parent = (try interfaces.Node.get_parentElement(instance)) orelse return -1;
            const parent_data = element_data.of(parent) orelse return -1;
            if (!std.mem.eql(u8, parent_data.namespaceSlice() orelse "", html_namespace) or
                !std.mem.eql(u8, parent_data.local_name.asSlice(), "details")) return -1;
            // A summary for its parent details is its first summary child.
            var child = try interfaces.Node.get_firstChild(parent);
            while (child) |node| : (child = try interfaces.Node.get_nextSibling(node)) {
                const child_data = element_data.of(node) orelse continue;
                if (std.mem.eql(u8, child_data.namespaceSlice() orelse "", html_namespace) and
                    std.mem.eql(u8, child_data.local_name.asSlice(), "summary")) return if (node == instance) 0 else -1;
            }
        }
    } else if (std.mem.eql(u8, name, "a") and
        (std.mem.eql(u8, namespace, "http://www.w3.org/2000/svg") or
            std.mem.eql(u8, namespace, "http://www.w3.org/1998/Math/MathML")))
    {
        return 0;
    }
    return -1;
}

// =============================================================================
// Content Attribute Reflection Setters
// =============================================================================

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
/// HTML hidden setter steps 1-7, after WebIDL union conversion.
pub fn set_hidden(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    const allocator = instance.ctx.allocator;
    var converted: ?[]u8 = null;
    defer if (converted) |bytes| allocator.free(bytes);
    const given = value orelse runtime.JSValue.jsNull;
    const normalized = switch (given) {
        .handle, .instance => blk: {
            // WebIDL union conversion step 15: the remaining ECMAScript
            // values select DOMString. The binding passes these as borrowed
            // values; conversion can throw and must precede any mutation.
            const engine = @import("engine");
            converted = try engine.convertToDOMString(engine.currentRealm() orelse instance.ctx, given, allocator);
            break :blk runtime.JSValue.fromStringRef(converted.?);
        },
        else => given,
    };
    const attribute: ?[]const u8 = switch (normalized) {
        // Step 1 precedes the empty-string removal in step 3.
        .string => |s| if (std.ascii.eqlIgnoreCase(s.data, "until-found")) "until-found" else if (s.data.len == 0) null else "",
        .boolean => |b| if (b) "" else null, // Steps 2 and 7.
        .null, .undefined => null, // Step 4; nullable union step 2 maps undefined to null.
        .number => |n| if (n == 0 or std.math.isNan(n)) null else "", // Steps 5-7.
        .handle, .instance => unreachable,
    };
    if (attribute) |text| {
        try setContentAttribute(instance, "hidden", runtime.DOMString.initInterned(text));
    } else {
        removeContentAttribute(instance, "hidden");
    }
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

/// Setter for editContext
pub fn set_editContext(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    // EditContext is not yet widely implemented
    _ = instance;
    _ = value;
}

// =============================================================================
// ElementContentEditable Mixin Setters
// =============================================================================

/// HTML 6.8.1 contentEditable setter: canonical keywords, removal for
/// inherit, and SyntaxError before any mutation for every other string.
pub fn set_contentEditable(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const keyword = value.asSlice();
    const name = runtime.DOMString.initInterned("contenteditable");
    if (std.ascii.eqlIgnoreCase(keyword, "inherit")) {
        try interfaces.Element.call_removeAttributeNS(instance, null, name);
        return;
    }
    inline for (.{ "true", "false", "plaintext-only" }) |state| {
        if (std.ascii.eqlIgnoreCase(keyword, state)) {
            try interfaces.Element.call_setAttributeNS(instance, null, name, .{ .domstring = runtime.DOMString.initInterned(state) });
            return;
        }
    }
    return error.SyntaxError;
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
    const internal = getInternalState(instance) orelse return error.InvalidStateError;
    const copy = try internal.allocator.dupe(u8, value.asSlice());
    if (internal.cryptographic_nonce) |old| internal.allocator.free(old);
    internal.cryptographic_nonce = copy;
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

/// Operation: blur (HTMLOrSVGElement): the unfocusing steps
/// (src/html/focus.zig, shared with SVGElement and the mixin).
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-blur
pub fn call_blur(instance: *runtime.Instance) anyerror!void {
    @import("html").focus.blurMethod(instance);
}

/// Operation: click
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-click
pub fn call_click(instance: *runtime.Instance) anyerror!void {
    const internal = getInternalState(instance) orelse return;
    // Step 1: "If this element is a form control that is disabled, then
    // return."
    if (isDisabledFormControl(instance)) return;
    // Step 2: "If this element's click in progress flag is set, then return."
    if (internal.click_in_progress) return;
    // Step 3: "Set this element's click in progress flag."
    internal.click_in_progress = true;
    // Step 5, however the dispatch leaves. The state is looked up again: the
    // handlers can run anything.
    defer if (getInternalState(instance)) |after| {
        after.click_in_progress = false;
    };
    // Step 4: "Fire a synthetic pointer event named click at this element,
    // with the not trusted flag set."
    fireSyntheticPointerEvent(instance, "click");
}

/// HTML "fire a synthetic pointer event named `event_type` at target, with
/// the not trusted flag set": a PointerEvent that bubbles, is cancelable and
/// composed, whose view is the target's node document's Window, with no
/// modifier keys - dispatched, so a click runs the activation behaviour of
/// its target or an ancestor (dom.activation).
fn fireSyntheticPointerEvent(target: *runtime.Instance, comptime event_type: []const u8) void {
    const view: ?*runtime.Instance = blk: {
        const document = (interfaces.Node.get_ownerDocument(target) catch null) orelse break :blk null;
        break :blk interfaces.Document.get_defaultView(document) catch null;
    };
    // Steps 3-4: bubbles, cancelable, composed; step 7: view.
    const init_dict: dictionaries.PointerEventInit = .{ .base = .{ .base = .{ .base = .{
        .base = .{ .bubbles = true, .cancelable = true, .composed = true },
        .view = view,
    } } } };
    const event = interfaces.PointerEvent.call_constructor(
        target.ctx,
        runtime.DOMString.initInterned(event_type),
        webidl.Opt(dictionaries.PointerEventInit).passed(init_dict),
    ) catch return;
    // A listener can keep the event; otherwise it is done after dispatch.
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);
    // Step 5: isTrusted stays false (the not trusted flag). Step 9: dispatch.
    _ = interfaces.EventTarget.call_dispatchEvent(target, event) catch {};
}

/// Whether `instance` is a disabled form control: a button, input, select or
/// textarea with a disabled attribute. Deviation, stated: a control disabled
/// only through a disabled fieldset ancestor is not recognised here.
fn isDisabledFormControl(instance: *runtime.Instance) bool {
    const data = element_data.of(instance) orelse return false;
    const name = data.local_name.asSlice();
    const controls = [_][]const u8{ "button", "input", "select", "textarea" };
    for (controls) |control| {
        if (std.mem.eql(u8, name, control)) return element_data.hasAttribute(data, "disabled");
    }
    return false;
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

/// Operation: focus (HTMLOrSVGElement): the focusing steps
/// (src/html/focus.zig, shared with SVGElement and the mixin).
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-focus
pub fn call_focus(instance: *runtime.Instance, options: webidl.Opt(dictionaries.FocusOptions)) anyerror!void {
    // preventScroll and focusVisible: nothing is rendered or scrolled.
    _ = options;
    @import("html").focus.focusMethod(instance);
}

/// Operation: attachInternals
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#dom-attachinternals
pub fn call_attachInternals(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternalState(instance) orelse return error.InvalidStateError;
    const ce = @import("dom").custom_elements;
    const data = ce.get(instance) orelse return error.NotSupportedError;
    // HTML 4.13.7 steps 1–4: an autonomous definition must enable internals.
    if (data.is_value != null) return error.NotSupportedError;
    var namespace = try interfaces.Element.get_namespaceURI(instance);
    defer if (namespace) |*value| value.deinit(instance.ctx.allocator);
    var name = try interfaces.Element.get_localName(instance);
    defer name.deinit(instance.ctx.allocator);
    const registry = try interfaces.Element.get_customElementRegistry(instance);
    const definition = ce.lookup(registry, if (namespace) |value| value.asSlice() else null, name.asSlice(), null) orelse return error.NotSupportedError;
    if (definition.disable_internals) return error.NotSupportedError;
    // Steps 5–6: reject repeat calls and elements whose upgrade has failed.
    if (internal.internals_attached) return error.NotSupportedError;
    if (data.state != .precustomized and data.state != .custom) return error.NotSupportedError;
    const internals = try ensureInternals(instance);
    internal.internals_attached = true;
    return internals;
}

fn ensureInternals(instance: *runtime.Instance) !*runtime.Instance {
    const internal = getInternalState(instance) orelse return error.InvalidStateError;
    if (internal.element_internals) |internals| return internals;
    // Steps 7–8: the element and its internals trace one another. Either can
    // survive alone in script, and neither creates a persistent engine root.
    const internals = try interfaces.ElementInternals.init(instance.ctx.allocator, instance.ctx);
    errdefer runtime.Instance.deinit(internals);
    try @import("dom").custom_elements.setInternalsTarget(internals, instance);
    if (instance.ctx.hasEngine()) {
        @import("engine").traceChild(instance, internals, .{ .name = "elementInternals" });
        internal.internals_traced = true;
    }
    internal.element_internals = internals;
    return internals;
}

pub fn installHooks() void {
    dom.attribute_change_steps.installForAttribute("http://www.w3.org/1999/xhtml", "nonce", .{ .change = &nonceAttributeChanged, .read = &nonceValueOf });
    dom.mutation.registerPostConnectionStepsCallback(&nonceConnectionSteps) catch @panic("out of memory installing nonce connection steps");
    dom.cloning_steps.install(&nonceCloningSteps);
    // Its states left at its Browser's end (Browser.deinit).
    @import("dom").teardown_sweeps.install(.html_elements, &sweepRemaining);
    @import("dom").html_pseudo_classes.install(.{ .matches = &@import("html").pseudo_classes.matches, .popover_showing = &popoverShowing });
    @import("dom").custom_elements.installHTMLElement(.{ .internals = &attachedInternals, .ensure_internals = &ensureInternals });
}

/// The internal CSP reader borrows; the IDL getter above copies.
fn nonceValueOf(instance: *runtime.Instance) []const u8 {
    const internal = getInternalState(instance) orelse return "";
    return internal.cryptographic_nonce orelse "";
}

/// HTML 2.5.6 attribute change steps 1-4. The registry has checked the
/// element namespace and attribute local name; namespaced attributes do
/// not change [[CryptographicNonce]]. Removal clears it.
fn nonceAttributeChanged(instance: *runtime.Instance, _: []const u8, _: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    if (namespace != null) return;
    const internal = getInternalState(instance) orelse return;
    if (value) |bytes| {
        set_nonce(instance, runtime.DOMString.initInterned(bytes)) catch {
            // The attribute has already changed. A failed copy must never
            // leave its previous nonce authorizing the new content.
            if (internal.cryptographic_nonce) |old| internal.allocator.free(old);
            internal.cryptographic_nonce = null;
        };
    } else {
        if (internal.cryptographic_nonce) |old| internal.allocator.free(old);
        internal.cryptographic_nonce = null;
    }
}

/// HTML 2.5.6: when browsing-context connected, hide a nonempty nonce
/// content attribute if any policy was header-delivered. WebKit's
/// Element::hideNonceSlow likewise preserves the slot around the change.
/// Deviation: HTML 2.1.4 (cached html.md:4216-4224) ties this to insertion,
/// before connectedCallback is enqueued. All three aligned stable browsers
/// pass script-nonces-hidden.html 12/12 (cc74d2669f, 2026-10-06), requiring
/// Connected before AttributeChanged(hiding). Use the existing later phase.
fn nonceConnectionSteps(node: *dom.NodeBase) void {
    if (node.node_type != 1 or !node.is_connected) return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse return));
    const internal = getInternalState(instance) orelse return;
    const saved = internal.cryptographic_nonce orelse return;
    const data = element_data.of(instance) orelse return;
    const attribute = element_data.getAttributeByNamespaceAndLocalName(data, null, "nonce") orelse return;
    if (attribute.value.len == 0) return;
    const document = (interfaces.Node.get_ownerDocument(instance) catch null) orelse return;
    const container = dom.policy_containers.of(document) orelse return;
    if (!container.csp_list.contains_header_policy) return;
    if ((interfaces.Document.get_defaultView(document) catch null) == null) return;
    // Steps 2.1-2.3: keep the old allocation outside the slot while the
    // attribute-change step clears it, then restore it without copying.
    internal.cryptographic_nonce = null;
    defer {
        if (internal.cryptographic_nonce) |empty| internal.allocator.free(empty);
        internal.cryptographic_nonce = saved;
    }
    dom.element_attributes.set(instance, "nonce", "", .{}) catch {};
}

/// HTML 2.5.6 cloning steps: the clone owns a copy, not the source buffer.
fn nonceCloningSteps(node: *runtime.Instance, copy: *runtime.Instance, _: bool) anyerror!void {
    const source = getInternalState(node) orelse return;
    if (source.cryptographic_nonce) |nonce| {
        try set_nonce(copy, runtime.DOMString.initInterned(nonce));
    } else if (getInternalState(copy)) |target| {
        if (target.cryptographic_nonce) |old| target.allocator.free(old);
        target.cryptographic_nonce = null;
    }
}

fn popoverShowing(instance: *runtime.Instance) bool {
    if (instance.stateAs(State) == null) return false;
    return (getInternalState(instance) orelse return false).popover_showing;
}

fn attachedInternals(instance: *runtime.Instance) ?*runtime.Instance {
    return (getInternalState(instance) orelse return null).element_internals;
}

/// dom.teardown_sweeps: at its Browser's end, every HTMLElement state still in
/// `scope`'s table - an orphan's no teardown reached - frees what it owns.
fn sweepRemaining(scope: *runtime.BrowserScope) void {
    Registry.deinitAllAndClear(scope);
}
