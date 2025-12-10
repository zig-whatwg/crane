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

    // === Event Handlers (GlobalEventHandlers mixin) ===
    /// Event handler storage using handler name as key
    /// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes
    event_handlers: std.StringHashMap(typedefs.EventHandler),

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .popover_showing = false,
            .popover_invoker = null,
            .was_focused_by_script = false,
            .element_internals = null,
            .internals_attached = false,
            .is_dragging = false,
            .event_handlers = std.StringHashMap(typedefs.EventHandler).init(allocator),
        };
    }

    pub fn deinit(self: *InternalState) void {
        self.event_handlers.deinit();
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
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    try Registry.set(instance, internal);

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
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(allocator, State, &HTMLElement.vtable, ctx);
    errdefer deinit(instance);

    // HTMLElement constructor is typically not called directly
    // Elements are created via document.createElement()

    return instance;
}

// =============================================================================
// Helper Functions for Content Attribute Reflection
// =============================================================================

/// Get a content attribute value from this element
/// Uses Element's getAttribute via findAttribute
fn getContentAttribute(instance: *runtime.Instance, name: []const u8) ?runtime.DOMString {
    const elem_internal = ElementImpl.getInternalState(instance) orelse return null;

    // Search attributes for matching name using findAttribute
    if (elem_internal.findAttribute(null, name)) |attr| {
        return runtime.DOMString.initInterned(attr.value);
    }
    return null;
}

/// Set a content attribute value on this element
/// Uses Element's setAttribute via findAttributeMut and addAttribute
fn setContentAttribute(instance: *runtime.Instance, name: []const u8, value: runtime.DOMString) !void {
    const elem_internal = ElementImpl.getInternalState(instance) orelse return error.InvalidStateError;

    // Search for existing attribute using findAttributeMut
    if (elem_internal.findAttributeMut(null, name)) |attr| {
        // Update existing
        elem_internal.allocator.free(attr.value);
        attr.value = try elem_internal.allocator.dupe(u8, value.asSlice());
        return;
    }

    // Add new attribute using addAttribute
    const ElementModule = @import("Element.zig");
    try elem_internal.addAttribute(ElementModule.AttributeEntry{
        .namespace_uri = null,
        .prefix = null,
        .local_name = try elem_internal.allocator.dupe(u8, name),
        .value = try elem_internal.allocator.dupe(u8, value.asSlice()),
    });
}

/// Check if a content attribute exists
fn hasContentAttribute(instance: *runtime.Instance, name: []const u8) bool {
    const elem_internal = ElementImpl.getInternalState(instance) orelse return false;
    return elem_internal.findAttribute(null, name) != null;
}

/// Remove a content attribute
fn removeContentAttribute(instance: *runtime.Instance, name: []const u8) void {
    const elem_internal = ElementImpl.getInternalState(instance) orelse return;
    _ = elem_internal.removeAttribute(null, name);
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
pub fn get_hidden(instance: *runtime.Instance) anyerror!?*const anyopaque {
    if (getContentAttribute(instance, "hidden")) |value| {
        const s = value.asSlice();
        if (std.mem.eql(u8, s, "until-found")) {
            // Return pointer to static string "until-found"
            // In real implementation, this would be properly typed
            return @ptrCast(&until_found_str);
        }
        // Any other value (including empty) means hidden=true
        return @ptrCast(&hidden_true);
    }
    return null; // Not hidden
}

const until_found_str: [11]u8 = "until-found".*;
const hidden_true: bool = true;

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
/// Returns the inline CSSStyleDeclaration
pub fn get_style(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // Would return a CSSStyleDeclaration instance
    // For now, this needs CSSStyleDeclaration implementation
    _ = instance;
    return error.NotImplemented;
}

/// Getter for attributeStyleMap
/// Spec: https://drafts.css-houdini.org/css-typed-om-1/#dom-elementcssinlinestyle-attributestylemap
pub fn get_attributeStyleMap(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // Would return a StylePropertyMap instance
    _ = instance;
    return error.NotImplemented;
}

// =============================================================================
// Event Handler IDL Attributes (GlobalEventHandlers mixin)
// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes
// =============================================================================

/// Helper to get an event handler from internal state
fn getEventHandler(instance: *runtime.Instance, name: []const u8) typedefs.EventHandler {
    const internal = getInternalState(instance) orelse return null;
    return internal.event_handlers.get(name) orelse null;
}

/// Helper to set an event handler in internal state
fn setEventHandler(instance: *runtime.Instance, name: []const u8, handler: typedefs.EventHandler) !void {
    const internal = getInternalState(instance) orelse return error.InvalidStateError;
    if (handler) |_| {
        try internal.event_handlers.put(name, handler);
    } else {
        _ = internal.event_handlers.remove(name);
    }
}

/// Getter for onabort
pub fn get_onabort(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "abort");
}

/// Getter for onauxclick
pub fn get_onauxclick(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "auxclick");
}

/// Getter for onbeforeinput
pub fn get_onbeforeinput(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "beforeinput");
}

/// Getter for onbeforematch
pub fn get_onbeforematch(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "beforematch");
}

/// Getter for onbeforetoggle
pub fn get_onbeforetoggle(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "beforetoggle");
}

/// Getter for onblur
pub fn get_onblur(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "blur");
}

/// Getter for oncancel
pub fn get_oncancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "cancel");
}

/// Getter for oncanplay
pub fn get_oncanplay(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "canplay");
}

/// Getter for oncanplaythrough
pub fn get_oncanplaythrough(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "canplaythrough");
}

/// Getter for onchange
pub fn get_onchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "change");
}

/// Getter for onclick
pub fn get_onclick(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "click");
}

/// Getter for onclose
pub fn get_onclose(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "close");
}

/// Getter for oncommand
pub fn get_oncommand(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "command");
}

/// Getter for oncontextlost
pub fn get_oncontextlost(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "contextlost");
}

/// Getter for oncontextmenu
pub fn get_oncontextmenu(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "contextmenu");
}

/// Getter for oncontextrestored
pub fn get_oncontextrestored(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "contextrestored");
}

/// Getter for oncopy
pub fn get_oncopy(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "copy");
}

/// Getter for oncuechange
pub fn get_oncuechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "cuechange");
}

/// Getter for oncut
pub fn get_oncut(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "cut");
}

/// Getter for ondblclick
pub fn get_ondblclick(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "dblclick");
}

/// Getter for ondrag
pub fn get_ondrag(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "drag");
}

/// Getter for ondragend
pub fn get_ondragend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "dragend");
}

/// Getter for ondragenter
pub fn get_ondragenter(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "dragenter");
}

/// Getter for ondragleave
pub fn get_ondragleave(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "dragleave");
}

/// Getter for ondragover
pub fn get_ondragover(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "dragover");
}

/// Getter for ondragstart
pub fn get_ondragstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "dragstart");
}

/// Getter for ondrop
pub fn get_ondrop(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "drop");
}

/// Getter for ondurationchange
pub fn get_ondurationchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "durationchange");
}

/// Getter for onemptied
pub fn get_onemptied(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "emptied");
}

/// Getter for onended
pub fn get_onended(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "ended");
}

/// Getter for onerror
pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.OnErrorEventHandler {
    // OnErrorEventHandler is a special variant
    const internal = getInternalState(instance) orelse return null;
    // Note: OnErrorEventHandler has a different signature than EventHandler
    // For now, return from the same storage (simplified)
    _ = internal;
    return null;
}

/// Getter for onfocus
pub fn get_onfocus(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "focus");
}

/// Getter for onformdata
pub fn get_onformdata(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "formdata");
}

/// Getter for oninput
pub fn get_oninput(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "input");
}

/// Getter for oninvalid
pub fn get_oninvalid(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "invalid");
}

/// Getter for onkeydown
pub fn get_onkeydown(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "keydown");
}

/// Getter for onkeypress
pub fn get_onkeypress(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "keypress");
}

/// Getter for onkeyup
pub fn get_onkeyup(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "keyup");
}

/// Getter for onload
pub fn get_onload(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "load");
}

/// Getter for onloadeddata
pub fn get_onloadeddata(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "loadeddata");
}

/// Getter for onloadedmetadata
pub fn get_onloadedmetadata(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "loadedmetadata");
}

/// Getter for onloadstart
pub fn get_onloadstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "loadstart");
}

/// Getter for onmousedown
pub fn get_onmousedown(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "mousedown");
}

/// Getter for onmouseenter
pub fn get_onmouseenter(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "mouseenter");
}

/// Getter for onmouseleave
pub fn get_onmouseleave(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "mouseleave");
}

/// Getter for onmousemove
pub fn get_onmousemove(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "mousemove");
}

/// Getter for onmouseout
pub fn get_onmouseout(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "mouseout");
}

/// Getter for onmouseover
pub fn get_onmouseover(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "mouseover");
}

/// Getter for onmouseup
pub fn get_onmouseup(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "mouseup");
}

/// Getter for onpaste
pub fn get_onpaste(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "paste");
}

/// Getter for onpause
pub fn get_onpause(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pause");
}

/// Getter for onplay
pub fn get_onplay(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "play");
}

/// Getter for onplaying
pub fn get_onplaying(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "playing");
}

/// Getter for onprogress
pub fn get_onprogress(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "progress");
}

/// Getter for onratechange
pub fn get_onratechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "ratechange");
}

/// Getter for onreset
pub fn get_onreset(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "reset");
}

/// Getter for onresize
pub fn get_onresize(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "resize");
}

/// Getter for onscroll
pub fn get_onscroll(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "scroll");
}

/// Getter for onscrollend
pub fn get_onscrollend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "scrollend");
}

/// Getter for onsecuritypolicyviolation
pub fn get_onsecuritypolicyviolation(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "securitypolicyviolation");
}

/// Getter for onseeked
pub fn get_onseeked(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "seeked");
}

/// Getter for onseeking
pub fn get_onseeking(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "seeking");
}

/// Getter for onselect
pub fn get_onselect(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "select");
}

/// Getter for onslotchange
pub fn get_onslotchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "slotchange");
}

/// Getter for onstalled
pub fn get_onstalled(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "stalled");
}

/// Getter for onsubmit
pub fn get_onsubmit(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "submit");
}

/// Getter for onsuspend
pub fn get_onsuspend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "suspend");
}

/// Getter for ontimeupdate
pub fn get_ontimeupdate(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "timeupdate");
}

/// Getter for ontoggle
pub fn get_ontoggle(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "toggle");
}

/// Getter for onvolumechange
pub fn get_onvolumechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "volumechange");
}

/// Getter for onwaiting
pub fn get_onwaiting(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "waiting");
}

/// Getter for onwebkitanimationend
pub fn get_onwebkitanimationend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "webkitanimationend");
}

/// Getter for onwebkitanimationiteration
pub fn get_onwebkitanimationiteration(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "webkitanimationiteration");
}

/// Getter for onwebkitanimationstart
pub fn get_onwebkitanimationstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "webkitanimationstart");
}

/// Getter for onwebkittransitionend
pub fn get_onwebkittransitionend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "webkittransitionend");
}

/// Getter for onwheel
pub fn get_onwheel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "wheel");
}

/// Getter for onselectstart
pub fn get_onselectstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "selectstart");
}

/// Getter for onselectionchange
pub fn get_onselectionchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "selectionchange");
}

/// Getter for onanimationstart
pub fn get_onanimationstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "animationstart");
}

/// Getter for onanimationiteration
pub fn get_onanimationiteration(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "animationiteration");
}

/// Getter for onanimationend
pub fn get_onanimationend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "animationend");
}

/// Getter for onanimationcancel
pub fn get_onanimationcancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "animationcancel");
}

/// Getter for ontransitionrun
pub fn get_ontransitionrun(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "transitionrun");
}

/// Getter for ontransitionstart
pub fn get_ontransitionstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "transitionstart");
}

/// Getter for ontransitionend
pub fn get_ontransitionend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "transitionend");
}

/// Getter for ontransitioncancel
pub fn get_ontransitioncancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "transitioncancel");
}

/// Getter for onbeforexrselect
pub fn get_onbeforexrselect(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "beforexrselect");
}

/// Getter for onpointerover
pub fn get_onpointerover(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointerover");
}

/// Getter for onpointerenter
pub fn get_onpointerenter(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointerenter");
}

/// Getter for onpointerdown
pub fn get_onpointerdown(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointerdown");
}

/// Getter for onpointermove
pub fn get_onpointermove(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointermove");
}

/// Getter for onpointerrawupdate
pub fn get_onpointerrawupdate(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointerrawupdate");
}

/// Getter for onpointerup
pub fn get_onpointerup(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointerup");
}

/// Getter for onpointercancel
pub fn get_onpointercancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointercancel");
}

/// Getter for onpointerout
pub fn get_onpointerout(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointerout");
}

/// Getter for onpointerleave
pub fn get_onpointerleave(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointerleave");
}

/// Getter for ongotpointercapture
pub fn get_ongotpointercapture(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "gotpointercapture");
}

/// Getter for onlostpointercapture
pub fn get_onlostpointercapture(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "lostpointercapture");
}

/// Getter for ontouchstart
pub fn get_ontouchstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "touchstart");
}

/// Getter for ontouchend
pub fn get_ontouchend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "touchend");
}

/// Getter for ontouchmove
pub fn get_ontouchmove(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "touchmove");
}

/// Getter for ontouchcancel
pub fn get_ontouchcancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "touchcancel");
}

/// Getter for onfencedtreeclick
pub fn get_onfencedtreeclick(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "fencedtreeclick");
}

/// Getter for onsnapchanged
pub fn get_onsnapchanged(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "snapchanged");
}

/// Getter for onsnapchanging
pub fn get_onsnapchanging(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "snapchanging");
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
    // Would need to return a DOMStringMap instance
    // For now, not implemented
    _ = instance;
    return error.NotImplemented;
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
pub fn set_hidden(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
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
pub fn set_popover(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const s = value.asSlice();
    if (s.len == 0) {
        removeContentAttribute(instance, "popover");
    } else {
        try setContentAttribute(instance, "popover", value);
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
pub fn set_editContext(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
    // EditContext is not yet widely implemented
    _ = instance;
    _ = value;
}

// =============================================================================
// Event Handler Setters (GlobalEventHandlers mixin)
// =============================================================================

pub fn set_onabort(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "abort", value);
}

pub fn set_onauxclick(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "auxclick", value);
}

pub fn set_onbeforeinput(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "beforeinput", value);
}

pub fn set_onbeforematch(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "beforematch", value);
}

pub fn set_onbeforetoggle(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "beforetoggle", value);
}

pub fn set_onblur(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "blur", value);
}

pub fn set_oncancel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "cancel", value);
}

pub fn set_oncanplay(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "canplay", value);
}

pub fn set_oncanplaythrough(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "canplaythrough", value);
}

pub fn set_onchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "change", value);
}

pub fn set_onclick(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "click", value);
}

pub fn set_onclose(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "close", value);
}

pub fn set_oncommand(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "command", value);
}

pub fn set_oncontextlost(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "contextlost", value);
}

pub fn set_oncontextmenu(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "contextmenu", value);
}

pub fn set_oncontextrestored(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "contextrestored", value);
}

pub fn set_oncopy(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "copy", value);
}

pub fn set_oncuechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "cuechange", value);
}

pub fn set_oncut(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "cut", value);
}

pub fn set_ondblclick(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "dblclick", value);
}

pub fn set_ondrag(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "drag", value);
}

pub fn set_ondragend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "dragend", value);
}

pub fn set_ondragenter(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "dragenter", value);
}

pub fn set_ondragleave(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "dragleave", value);
}

pub fn set_ondragover(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "dragover", value);
}

pub fn set_ondragstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "dragstart", value);
}

pub fn set_ondrop(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "drop", value);
}

pub fn set_ondurationchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "durationchange", value);
}

pub fn set_onemptied(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "emptied", value);
}

pub fn set_onended(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "ended", value);
}

pub fn set_onerror(instance: *runtime.Instance, value: typedefs.OnErrorEventHandler) anyerror!void {
    // OnErrorEventHandler has special signature, simplified storage
    _ = instance;
    _ = value;
}

pub fn set_onfocus(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "focus", value);
}

pub fn set_onformdata(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "formdata", value);
}

pub fn set_oninput(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "input", value);
}

pub fn set_oninvalid(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "invalid", value);
}

pub fn set_onkeydown(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "keydown", value);
}

pub fn set_onkeypress(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "keypress", value);
}

pub fn set_onkeyup(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "keyup", value);
}

pub fn set_onload(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "load", value);
}

pub fn set_onloadeddata(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "loadeddata", value);
}

pub fn set_onloadedmetadata(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "loadedmetadata", value);
}

pub fn set_onloadstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "loadstart", value);
}

pub fn set_onmousedown(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "mousedown", value);
}

pub fn set_onmouseenter(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "mouseenter", value);
}

pub fn set_onmouseleave(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "mouseleave", value);
}

pub fn set_onmousemove(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "mousemove", value);
}

pub fn set_onmouseout(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "mouseout", value);
}

pub fn set_onmouseover(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "mouseover", value);
}

pub fn set_onmouseup(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "mouseup", value);
}

pub fn set_onpaste(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "paste", value);
}

pub fn set_onpause(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pause", value);
}

pub fn set_onplay(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "play", value);
}

pub fn set_onplaying(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "playing", value);
}

pub fn set_onprogress(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "progress", value);
}

pub fn set_onratechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "ratechange", value);
}

pub fn set_onreset(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "reset", value);
}

pub fn set_onresize(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "resize", value);
}

pub fn set_onscroll(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "scroll", value);
}

pub fn set_onscrollend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "scrollend", value);
}

pub fn set_onsecuritypolicyviolation(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "securitypolicyviolation", value);
}

pub fn set_onseeked(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "seeked", value);
}

pub fn set_onseeking(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "seeking", value);
}

pub fn set_onselect(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "select", value);
}

pub fn set_onslotchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "slotchange", value);
}

pub fn set_onstalled(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "stalled", value);
}

pub fn set_onsubmit(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "submit", value);
}

pub fn set_onsuspend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "suspend", value);
}

pub fn set_ontimeupdate(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "timeupdate", value);
}

pub fn set_ontoggle(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "toggle", value);
}

pub fn set_onvolumechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "volumechange", value);
}

pub fn set_onwaiting(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "waiting", value);
}

pub fn set_onwebkitanimationend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "webkitanimationend", value);
}

pub fn set_onwebkitanimationiteration(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "webkitanimationiteration", value);
}

pub fn set_onwebkitanimationstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "webkitanimationstart", value);
}

pub fn set_onwebkittransitionend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "webkittransitionend", value);
}

pub fn set_onwheel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "wheel", value);
}

pub fn set_onselectstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "selectstart", value);
}

pub fn set_onselectionchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "selectionchange", value);
}

pub fn set_onanimationstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "animationstart", value);
}

pub fn set_onanimationiteration(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "animationiteration", value);
}

pub fn set_onanimationend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "animationend", value);
}

pub fn set_onanimationcancel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "animationcancel", value);
}

pub fn set_ontransitionrun(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "transitionrun", value);
}

pub fn set_ontransitionstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "transitionstart", value);
}

pub fn set_ontransitionend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "transitionend", value);
}

pub fn set_ontransitioncancel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "transitioncancel", value);
}

pub fn set_onbeforexrselect(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "beforexrselect", value);
}

pub fn set_onpointerover(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pointerover", value);
}

pub fn set_onpointerenter(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pointerenter", value);
}

pub fn set_onpointerdown(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pointerdown", value);
}

pub fn set_onpointermove(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pointermove", value);
}

pub fn set_onpointerrawupdate(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pointerrawupdate", value);
}

pub fn set_onpointerup(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pointerup", value);
}

pub fn set_onpointercancel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pointercancel", value);
}

pub fn set_onpointerout(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pointerout", value);
}

pub fn set_onpointerleave(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pointerleave", value);
}

pub fn set_ongotpointercapture(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "gotpointercapture", value);
}

pub fn set_onlostpointercapture(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "lostpointercapture", value);
}

pub fn set_ontouchstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "touchstart", value);
}

pub fn set_ontouchend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "touchend", value);
}

pub fn set_ontouchmove(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "touchmove", value);
}

pub fn set_ontouchcancel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "touchcancel", value);
}

pub fn set_onfencedtreeclick(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "fencedtreeclick", value);
}

pub fn set_onsnapchanged(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "snapchanged", value);
}

pub fn set_onsnapchanging(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "snapchanging", value);
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
pub fn call_togglePopover(instance: *runtime.Instance, options: webidl.Opt(*const anyopaque)) anyerror!bool {
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
    if (getEventHandler(instance, "blur")) |handler| {
        _ = handler; // Would invoke handler
    }
}

/// Operation: click
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-click
pub fn call_click(instance: *runtime.Instance) anyerror!void {
    // Fire a click event at this element
    // In a full implementation, this would:
    // 1. Create a MouseEvent with type "click"
    // 2. Set bubbles=true, cancelable=true
    // 3. Dispatch the event via EventTarget.dispatchEvent()

    // For now, just invoke the onclick handler if present
    if (getEventHandler(instance, "click")) |handler| {
        _ = handler; // Would invoke handler
    }
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
    if (getEventHandler(instance, "beforetoggle")) |handler| {
        _ = handler; // Would invoke handler
    }

    // Show the popover (add to top layer)
    internal.popover_showing = true;

    // Fire toggle event
    if (getEventHandler(instance, "toggle")) |handler| {
        _ = handler; // Would invoke handler
    }
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
    if (getEventHandler(instance, "beforetoggle")) |handler| {
        _ = handler; // Would invoke handler
    }

    // Hide the popover (remove from top layer)
    internal.popover_showing = false;
    internal.popover_invoker = null;

    // Fire toggle event
    if (getEventHandler(instance, "toggle")) |handler| {
        _ = handler; // Would invoke handler
    }
}

/// Operation: focus
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-focus
pub fn call_focus(instance: *runtime.Instance, options: webidl.Opt(dictionaries.FocusOptions)) anyerror!void {
    const internal = getInternalState(instance) orelse return;
    _ = options; // FocusOptions - preventScroll, focusVisible

    // Run the focusing steps
    // In a full implementation, this would:
    // 1. Check if element is focusable
    // 2. Update document.activeElement
    // 3. Fire focus event
    // 4. Scroll into view (unless preventScroll)

    internal.was_focused_by_script = true;

    // Fire focus event (simplified)
    if (getEventHandler(instance, "focus")) |handler| {
        _ = handler; // Would invoke handler
    }
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
