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
pub const InternalState = struct {
    /// Kept by value in this interface's own State (runtime.OwnState, the
    /// State's `_embedded`; lane perf2 batch 5, Z7): a node is one block.
    pub const embedded_in_state = true;

    // Nothing here (lane perf3 D2): every field it kept - the nonce, the
    // ElementInternals and element.style objects with their edges, the
    // internals flags, 88 bytes on every HTML element - is in the element's
    // sparse rare block (dom.element_rare_data; lane rare1), each made on
    // first use; click()'s flag is in Element's padding. Reached through
    // the hook Element installs (dom.element_rare_data.access), never
    // through Element's impl.

    pub fn deinit(self: *InternalState) void {
        _ = self;
    }
};

/// HTMLElement's fields of the element's rare data (dom.element_rare_data:
/// element_internals and its flags; style and nonce, which the
/// ElementCSSInlineStyle and HTMLOrSVGOrMathMLElement mixins' impls write and
/// this element's teardown releases). The block MOVES when a
/// field is added: read it by value (`rare_data.of`), write it through the
/// holder's address (`rare_data.access`), and never keep either across a
/// call that can run script or add a field.
const rare_data = dom.element_rare_data;

/// `instance`'s rare holder's address and click()'s flag; null for an
/// instance that is no element.
fn accessOf(instance: *runtime.Instance) ?rare_data.Access {
    return rare_data.access(instance);
}

/// Free HTMLElement's fields of the rare data: the nonce, and element.style's
/// object (severed from the element; its wrapper, which the element's
/// traced, goes with the element's) - both made by the mixins' impls. Its
/// deinit and its teardown sweep run this; Element's teardown then frees the
/// block (and would free the nonce's bytes, as it does an SVG or MathML
/// element's).
fn releaseRare(instance: *runtime.Instance, allocator: std.mem.Allocator) void {
    const a = accessOf(instance) orelse return;
    rare_data.clearBytes(.{ .allocator = allocator }, a.holder, .nonce);
    rare_data.keptReleaseOwned(a.holder, .style);
}

// Its internal state, in its own generated State (`own._internal`): runtime.OwnState.
const utils = @import("webidl").utils;
const Registry = runtime.OwnState(State, InternalState);

/// Get HTMLElement's internal state
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// HTMLElement's own construction steps: the generated chain runs Element's first.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    // What it frees goes through its Browser's allocator (runtime.allocatorOf),
    // which Element's init, run first by the generated chain, asserts it was
    // made with.
    _ = allocator;
    // Initialize HTMLElement's own internal state in its own State (runtime.OwnState)
    // The block is the arena's, and `Registry.remove` returns it to the
    // arena. With `set` it was dropped from the map and held to process
    // exit - 904 bytes per discarded element, measured.
    const internal = try Registry.create(instance);
    internal.* = .{};
}

/// HTMLElement's own teardown: the generated chain runs Element's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    // Clean up its internal state
    if (Registry.get(instance)) |internal| {
        internal.deinit();
        // Its fields of the rare data, before Element's teardown (which the
        // generated chain runs after this) frees the block.
        if (accessOf(instance)) |a| {
            const traced = rare_data.flag(a.holder.*, .internals_traced);
            if (traced) @import("engine").forgetTracedChild(instance, .{ .name = "elementInternals" });
            if (!traced) if (rare_data.get(a.holder.*, .element_internals)) |internals| runtime.Instance.deinit(internals);
            rare_data.clear(a.holder, .element_internals);
            releaseRare(instance, runtime.allocatorOf(instance));
        }
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
/// Returns rendered text through computed style and HTML text collection.
pub fn get_innerText(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return @import("html").inner_text.getText(instance);
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
    // CSSOM View: update style first, as browsers do (dom.style.engine.updateStyleForRead).
    dom.style.engine.updateStyleForRead(instance);
    return null;
}

/// Getter for offsetTop
/// Spec: https://drafts.csswg.org/cssom-view/#dom-htmlelement-offsettop
pub fn get_offsetTop(instance: *runtime.Instance) anyerror!i32 {
    // Requires layout computation
    // CSSOM View: update style first, as browsers do (dom.style.engine.updateStyleForRead).
    dom.style.engine.updateStyleForRead(instance);
    return 0;
}

/// Getter for offsetLeft
/// Spec: https://drafts.csswg.org/cssom-view/#dom-htmlelement-offsetleft
pub fn get_offsetLeft(instance: *runtime.Instance) anyerror!i32 {
    // CSSOM View: update style first, as browsers do (dom.style.engine.updateStyleForRead).
    dom.style.engine.updateStyleForRead(instance);
    return 0;
}

/// Getter for offsetWidth
/// Spec: https://drafts.csswg.org/cssom-view/#dom-htmlelement-offsetwidth
pub fn get_offsetWidth(instance: *runtime.Instance) anyerror!i32 {
    // CSSOM View: update style first, as browsers do (dom.style.engine.updateStyleForRead).
    dom.style.engine.updateStyleForRead(instance);
    return 0;
}

/// Getter for offsetHeight
/// Spec: https://drafts.csswg.org/cssom-view/#dom-htmlelement-offsetheight
pub fn get_offsetHeight(instance: *runtime.Instance) anyerror!i32 {
    // CSSOM View: update style first, as browsers do (dom.style.engine.updateStyleForRead).
    dom.style.engine.updateStyleForRead(instance);
    return 0;
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
    try @import("html").inner_text.setInnerText(instance, value);
}

/// Setter for outerText
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#the-outertext-idl-attribute
pub fn set_outerText(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try @import("html").inner_text.setOuterText(instance, value);
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
// Operations
// =============================================================================

/// Operation: togglePopover
/// Spec: https://html.spec.whatwg.org/multipage/popover.html#dom-togglepopover
pub fn call_togglePopover(instance: *runtime.Instance, options: webidl.Opt(runtime.JSValue)) anyerror!bool {
    return @import("html").popover.toggleMethod(instance, if (options.was_passed) options.value else null);
}

/// Operation: click
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-click
pub fn call_click(instance: *runtime.Instance) anyerror!void {
    _ = getInternalState(instance) orelse return;
    // Step 1: "If this element is a form control that is disabled, then
    // return."
    if (isDisabledFormControl(instance)) return;
    const a = accessOf(instance) orelse return;
    // Step 2: "If this element's click in progress flag is set, then return."
    if (a.click_in_progress.*) return;
    // Step 3: "Set this element's click in progress flag." In Element's
    // padding, no rare block (lane rare1).
    a.click_in_progress.* = true;
    // Step 5, however the dispatch leaves. Looked up again: the handlers can
    // run anything, its element's teardown included.
    defer if (getInternalState(instance) != null) if (accessOf(instance)) |after| {
        after.click_in_progress.* = false;
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
    const name = data.localName();
    const controls = [_][]const u8{ "button", "input", "select", "textarea" };
    for (controls) |control| {
        if (std.mem.eql(u8, name, control)) return element_data.hasAttribute(data, "disabled");
    }
    return false;
}

/// Operation: showPopover
/// Spec: https://html.spec.whatwg.org/multipage/popover.html#dom-showpopover
pub fn call_showPopover(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ShowPopoverOptions)) anyerror!void {
    try @import("html").popover.showPopover(instance, true, if (options.was_passed) options.value.source else null);
}

/// Operation: hidePopover
/// Spec: https://html.spec.whatwg.org/multipage/popover.html#dom-hidepopover
pub fn call_hidePopover(instance: *runtime.Instance) anyerror!void {
    try @import("html").popover.hideMethod(instance);
}

/// Operation: attachInternals
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#dom-attachinternals
pub fn call_attachInternals(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = getInternalState(instance) orelse return error.InvalidStateError;
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
    if (rare_data.flag(rare_data.of(instance), .internals_attached)) return error.NotSupportedError;
    if (data.state != .precustomized and data.state != .custom) return error.NotSupportedError;
    const internals = try ensureInternals(instance);
    // ensureInternals made the field, so the block is there.
    rare_data.setFlag((accessOf(instance) orelse return error.InvalidStateError).holder, .internals_attached, true);
    return internals;
}

fn ensureInternals(instance: *runtime.Instance) !*runtime.Instance {
    _ = getInternalState(instance) orelse return error.InvalidStateError;
    const a = accessOf(instance) orelse return error.InvalidStateError;
    if (rare_data.get(a.holder.*, .element_internals)) |internals| return internals;
    // Kept in rare data (Blink's kElementInternals): its slot reserved (a
    // cleared field) before the object is made, so that nothing can fail
    // after it is.
    try rare_data.reserve(rare_data.contextOf(instance), a.holder, .element_internals);
    // Steps 7–8: the element and its internals trace one another. Either can
    // survive alone in script, and neither creates a persistent engine root.
    const internals = try interfaces.ElementInternals.init(instance.ctx.allocator, instance.ctx);
    errdefer runtime.Instance.deinit(internals);
    try @import("dom").custom_elements.setInternalsTarget(internals, instance);
    // In place, through the holder read now.
    rare_data.putReserved(a.holder, .element_internals, internals);
    if (instance.ctx.hasEngine()) {
        @import("engine").traceChild(instance, internals, .{ .name = "elementInternals" });
        rare_data.setFlag(a.holder, .internals_traced, true);
    }
    return internals;
}

pub fn installHooks() void {
    dom.attribute_change_steps.installForAttribute("http://www.w3.org/1999/xhtml", "popover", .{ .change = &@import("html").popover.attributeChanged });
    dom.mutation.registerRemovingStepsCallback(&@import("html").popover.removingSteps) catch @panic("out of memory installing popover removal steps");
    // Its states left at its Browser's end (Browser.deinit).
    @import("dom").teardown_sweeps.install(.html_elements, &sweepRemaining);
    @import("dom").html_pseudo_classes.install(.{ .matches = &@import("html").pseudo_classes.matches, .popover_showing = &popoverShowing });
    @import("dom").custom_elements.installHTMLElement(.{ .internals = &attachedInternals, .ensure_internals = &ensureInternals });
}

fn popoverShowing(instance: *runtime.Instance) bool {
    if (instance.stateAs(State) == null) return false;
    return @import("html").popover.showing(instance);
}

fn attachedInternals(instance: *runtime.Instance) ?*runtime.Instance {
    _ = getInternalState(instance) orelse return null;
    return rare_data.get(rare_data.of(instance), .element_internals);
}

/// dom.teardown_sweeps: at its Browser's end, every HTMLElement state still in
/// `scope`'s table - an orphan's no teardown reached - frees what it owns.
fn sweepRemaining(scope: *runtime.BrowserScope) void {
    // Its fields of each one's rare data, which Element's sweep (the next
    // phase, dom.teardown_sweeps' order) then frees with the block.
    Registry.sweep(scope, scope, struct {
        fn visit(browser_scope: *runtime.BrowserScope, instance: *runtime.Instance, internal: *InternalState) void {
            internal.deinit();
            releaseRare(instance, browser_scope.allocator);
        }
    }.visit);
}
