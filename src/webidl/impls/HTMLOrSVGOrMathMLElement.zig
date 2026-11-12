//! Implementation for the HTMLOrSVGOrMathMLElement mixin (formerly
//! HTMLOrSVGElement; HTML includes it in HTMLElement, SVGElement and
//! MathMLElement): dataset, nonce, autofocus, tabIndex, focus() and blur().
//!
//! Its includers inherit these members by alias (codegen/inherited_mixins.zig):
//! each is implemented here once, with the element as `this`
//! (src/webidl/AGENTS.md "Mixin members are inherited"). autofocus is
//! [Reflect]: the generated mixin module reflects it.
//!
//! The [[CryptographicNonce]] slot (HTML 2.5.6) is every includer's, in its
//! element's sparse rare block (dom.element_rare_data's `nonce` bytes:
//! WebKit's m_nonce, Blink's kNonce), which Element's rare-data teardown
//! frees at both of the element's exits - its deinit and its Browser's
//! teardown sweep. The nonce steps - attribute change, hiding when
//! browsing-context connected, cloning - are installed here once, for the
//! three namespaces.
//!
//! Spec: https://html.spec.whatwg.org/multipage/dom.html#htmlorsvgelement
//! Spec: https://html.spec.whatwg.org/multipage/urls-and-fetching.html#nonce-attributes

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const dom = @import("dom");
const HTMLOrSVGOrMathMLElement = interfaces.HTMLOrSVGOrMathMLElement;

pub const State = HTMLOrSVGOrMathMLElement.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
};

/// Internal state for implementation-specific data. None: a mixin has no
/// instances; the nonce slot is its includer's rare data.
pub const InternalState = struct {};

/// The element's sparse rare block (dom.element_rare_data). The block MOVES
/// when a field is added: read it by value (`rare_data.of`), write it
/// through the holder's address (`rare_data.access`), and never keep either
/// across a call that can run script or add a field.
const rare_data = dom.element_rare_data;
const element_data = dom.element_data;

const html_namespace = "http://www.w3.org/1999/xhtml";
const svg_namespace = "http://www.w3.org/2000/svg";
const mathml_namespace = "http://www.w3.org/1998/Math/MathML";

/// The hooks this mixin owns (src/dom), installed once, at process start.
pub fn installHooks() void {
    // HTML 2.5.6's nonce attribute change steps, for "elements that
    // include HTMLOrSVGOrMathMLElement" - every element of the three
    // namespaces.
    inline for (.{ html_namespace, svg_namespace, mathml_namespace }) |namespace| {
        dom.attribute_change_steps.installForAttribute(namespace, "nonce", .{ .change = &nonceAttributeChanged, .read = &nonceValueOf });
    }
    // Hiding, when browsing-context connected: an HTML element's in the
    // post-connection steps, an SVG or MathML element's in the insertion
    // steps (`nonceConnectionSteps`).
    dom.mutation.registerPostConnectionStepsCallback(&nonceConnectionSteps) catch @panic("out of memory installing nonce connection steps");
    dom.mutation.registerInsertionStepsCallback(&nonceInsertionSteps) catch @panic("out of memory installing nonce insertion steps");
    dom.cloning_steps.install(&nonceCloningSteps);
}

/// Whether `instance` is an element that includes this mixin: an HTML, SVG
/// or MathML element. The binding's brand check guarantees it for script;
/// a native caller can pass any instance.
fn includesMixin(instance: *runtime.Instance) bool {
    return instance.stateAs(interfaces.HTMLElement.State) != null or
        instance.stateAs(interfaces.SVGElement.State) != null or
        instance.stateAs(interfaces.MathMLElement.State) != null;
}

// =============================================================================
// dataset
// =============================================================================

/// Getter for dataset: a DOMStringMap whose element is this one (its
/// construction argument). The generated [SameObject] accessor of each
/// includer keeps it in the element's rare data.
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-dataset
pub fn get_dataset(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return interfaces.DOMStringMap.initWith(instance.ctx.allocator, instance.ctx, .{ .element = instance });
}

// =============================================================================
// nonce: HTML 2.5.6 [[CryptographicNonce]]
// =============================================================================

/// Getter for nonce: the slot's value. Its result is the caller's, valid
/// even after the element changes or is destroyed.
/// Spec: https://html.spec.whatwg.org/multipage/urls-and-fetching.html#dom-noncedelement-nonce
pub fn get_nonce(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initDupe(instance.ctx.allocator, nonceValueOf(instance));
}

/// Setter for nonce: the slot becomes the value - bytes of their own, the
/// copy made before the old one is freed. An instance that is no includer
/// is rejected before anything is copied.
pub fn set_nonce(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    if (!includesMixin(instance)) return error.InvalidStateError;
    const a = rare_data.access(instance) orelse return error.InvalidStateError;
    try rare_data.putBytes(rare_data.contextOf(instance), a.holder, .nonce, value.asSlice());
}

/// The internal CSP reader (dom.attribute_change_steps.readForAttribute)
/// borrows; the IDL getter copies. "" for no slot, and for an element with
/// no rare data, which has none.
fn nonceValueOf(instance: *runtime.Instance) []const u8 {
    return rare_data.getBytes(rare_data.of(instance), .nonce) orelse "";
}

/// HTML 2.5.6 attribute change steps 1-4. The registry has checked the
/// element namespace and attribute local name; a namespaced attribute does
/// not change [[CryptographicNonce]]. Removal clears it.
fn nonceAttributeChanged(instance: *runtime.Instance, _: []const u8, _: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    if (namespace != null) return;
    if (!includesMixin(instance)) return;
    if (value) |bytes| {
        set_nonce(instance, runtime.DOMString.initInterned(bytes)) catch {
            // The attribute has already changed. A failed copy must never
            // leave its previous nonce authorizing the new content.
            clearNonce(instance);
        };
    } else {
        clearNonce(instance);
    }
}

/// HTML 2.5.6: "Whenever an element including HTMLOrSVGOrMathMLElement
/// becomes browsing-context connected", hide a nonempty nonce content
/// attribute if any policy was header-delivered. WebKit's
/// Element::hideNonceSlow likewise preserves the slot around the change.
///
/// When: an SVG or MathML element hides in its insertion steps - "becomes
/// browsing-context connected" happens as it is inserted (HTML 2.1.4), so
/// an SVG script, which runs in its own insertion steps after this one
/// (crane/cn-nonce-hidden-during-script.html), already sees the attribute
/// hidden. Deviation for an HTML element, stated: it hides in the
/// post-connection steps (`nonceConnectionSteps`), before an HTML script
/// runs in its own: all three aligned stable browsers pass
/// script-nonces-hidden.html 12/12 (cc74d2669f, 2026-10-06), which needs a
/// custom element's connectedCallback enqueued before the hiding's
/// attributeChangedCallback - and only HTML elements are custom elements.
fn nonceInsertionSteps(node: *dom.NodeBase) void {
    const instance = nonceCandidate(node) orelse return;
    if (instance.stateAs(interfaces.HTMLElement.State) != null) return;
    hideNonce(instance);
}

/// The post-connection half of `nonceInsertionSteps`: an HTML element's.
fn nonceConnectionSteps(node: *dom.NodeBase) void {
    const instance = nonceCandidate(node) orelse return;
    if (instance.stateAs(interfaces.HTMLElement.State) == null) return;
    hideNonce(instance);
}

/// A connected element with a nonce slot: every connected element passes
/// here, and one without a slot has no nonce to hide - nothing is made for
/// it. Only includers ever have one (set_nonce).
fn nonceCandidate(node: *dom.NodeBase) ?*runtime.Instance {
    if (node.node_type != 1 or !node.is_connected) return null;
    const instance: *runtime.Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse return null));
    if (rare_data.getBytes(rare_data.of(instance), .nonce) == null) return null;
    return instance;
}

/// HTML 2.5.6's hiding steps 1-2.3 for `instance`, connected with a slot.
fn hideNonce(instance: *runtime.Instance) void {
    const data = element_data.of(instance) orelse return;
    const attribute = element_data.getAttributeByNamespaceAndLocalName(data, null, "nonce") orelse return;
    if (attribute.value.len == 0) return;
    const document = (interfaces.Node.get_ownerDocument(instance) catch null) orelse return;
    // Step 2's "CSP list contains a header-delivered Content Security
    // Policy": a list that cannot be read - no policy container, or an
    // unenforceable one - may hold one, and hiding is the closed answer
    // (lane leaks6).
    if (dom.policy_containers.of(document)) |container| {
        if (!container.csp_list.contains_header_policy and !container.csp_list.blocksEverything()) return;
    }
    if ((interfaces.Document.get_defaultView(document) catch null) == null) return;
    // Steps 2.1-2.3: keep the old allocation outside the slot while the
    // attribute-change step clears it, then restore it without copying. The
    // holder is read again after the change: the steps can add fields and
    // move the block (the nonce keeps its bit, so the restore never
    // allocates).
    const a = rare_data.access(instance) orelse return;
    const saved = rare_data.takeBytes(a.holder, .nonce) orelse return;
    defer rare_data.restoreBytes(rare_data.contextOf(instance), a.holder, .nonce, saved);
    dom.element_attributes.set(instance, "nonce", "", .{}) catch {};
}

/// HTML 2.5.6 cloning steps: "set copy's [[CryptographicNonce]] to node's
/// [[CryptographicNonce]]" - an owned copy, not the source buffer. Copying
/// the attributes may have set the copy's slot from the nonce attribute; a
/// node with no slot leaves the copy with none.
fn nonceCloningSteps(node: *runtime.Instance, copy: *runtime.Instance, _: bool) anyerror!void {
    if (rare_data.getBytes(rare_data.of(node), .nonce)) |value| {
        try set_nonce(copy, runtime.DOMString.initInterned(value));
    } else if (rare_data.getBytes(rare_data.of(copy), .nonce) != null) {
        clearNonce(copy);
    }
}

/// [[CryptographicNonce]] becomes null; nothing to do for an element with no
/// rare data, which has none.
fn clearNonce(instance: *runtime.Instance) void {
    const a = rare_data.access(instance) orelse return;
    rare_data.clearBytes(rare_data.contextOf(instance), a.holder, .nonce);
}

// =============================================================================
// tabIndex
// =============================================================================

/// Getter for tabIndex. The setter is [ReflectSetter]: the generated mixin
/// module reflects it.
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-tabindex
pub fn get_tabIndex(instance: *runtime.Instance) anyerror!i32 {
    const data = element_data.of(instance) orelse return -1;
    // Getter steps 1-2: HTML's integer prefix parser, then the IDL long range.
    if (element_data.getAttributeByNamespaceAndLocalName(data, null, "tabindex")) |attribute| {
        if (dom.reflection.parseInteger(attribute.value)) |parsed| {
            if (parsed >= std.math.minInt(i32) and parsed <= std.math.maxInt(i32)) return @intCast(parsed);
        }
    }
    // Step 3: "If this is an a, area, button, frame, iframe, input, object,
    // select, textarea, or SVG a element, or is a summary element that is a
    // summary for its parent details, then return 0" - and MathML Core
    // 2.1.4 adds the MathML a. Historical defaults depend on the element's
    // name, not its current focusability (disabled and hidden inputs still
    // default to 0). Step 4: return -1.
    const namespace = data.namespaceSlice() orelse return -1;
    const name = data.localName();
    if (std.mem.eql(u8, namespace, html_namespace)) {
        inline for (.{ "a", "area", "button", "frame", "iframe", "input", "object", "select", "textarea" }) |tag| {
            if (std.mem.eql(u8, name, tag)) return 0;
        }
        if (std.mem.eql(u8, name, "summary")) {
            const parent = (try interfaces.Node.get_parentElement(instance)) orelse return -1;
            const parent_data = element_data.of(parent) orelse return -1;
            if (!std.mem.eql(u8, parent_data.namespaceSlice() orelse "", html_namespace) or
                !std.mem.eql(u8, parent_data.localName(), "details")) return -1;
            // A summary for its parent details is its first summary child.
            var child = try interfaces.Node.get_firstChild(parent);
            while (child) |node| : (child = try interfaces.Node.get_nextSibling(node)) {
                const child_data = element_data.of(node) orelse continue;
                if (std.mem.eql(u8, child_data.namespaceSlice() orelse "", html_namespace) and
                    std.mem.eql(u8, child_data.localName(), "summary")) return if (node == instance) 0 else -1;
            }
        }
    } else if (std.mem.eql(u8, name, "a") and
        (std.mem.eql(u8, namespace, svg_namespace) or std.mem.eql(u8, namespace, mathml_namespace)))
    {
        return 0;
    }
    return -1;
}

// =============================================================================
// focus() and blur()
// =============================================================================

/// Operation: focus: the focusing steps (src/html/focus.zig).
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-focus
pub fn call_focus(instance: *runtime.Instance, options: webidl.Opt(dictionaries.FocusOptions)) anyerror!void {
    // preventScroll and focusVisible: nothing is rendered or scrolled.
    _ = options;
    @import("html").focus.focusMethod(instance);
}

/// Operation: blur: the unfocusing steps (src/html/focus.zig).
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-blur
pub fn call_blur(instance: *runtime.Instance) anyerror!void {
    @import("html").focus.blurMethod(instance);
}
