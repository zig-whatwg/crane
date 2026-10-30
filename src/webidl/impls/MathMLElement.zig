//! Implementation for MathMLElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const MathMLElement = interfaces.MathMLElement;

pub const State = MathMLElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

// No state of our own: use the generated Element/Node construction and
// destruction chain, including when MathMLAnchorElement derives from us.

/// Getter for style
pub fn get_style(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for attributeStyleMap
pub fn get_attributeStyleMap(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // The generated SameObject accessor supplies identity and the owner edge.
    return dom.style.typed_om.inlineMap(instance);
}

// =============================================================================
// HTMLOrSVGOrMathMLElement members. HTML now includes the mixin in
// MathMLElement too. The mixin is not on codegen/inherited_mixins.zig yet,
// so its includers' impls answer its members; moving them into the mixin's
// impl (with the nonce slot into a src/dom store) is a queued follow-up.
// =============================================================================

/// Getter for dataset. Not implemented for MathML elements: HTMLElement's
/// DOMStringMap creation lives in its impl, not in a shared helper.
pub fn get_dataset(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for nonce. Not implemented: the nonce slot is per includer impl.
pub fn get_nonce(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for nonce. Not implemented: the nonce slot is per includer impl.
pub fn set_nonce(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// HTML tabIndex getter, shared by MathML Core 2.1.4.
/// https://html.spec.whatwg.org/multipage/interaction.html#dom-tabindex
pub fn get_tabIndex(instance: *runtime.Instance) anyerror!i32 {
    // Steps 1–2: integer prefix parsing, then the IDL long range.
    if (try interfaces.Element.call_getAttribute(instance, runtime.DOMString.initInterned("tabindex"))) |attribute| {
        var value = attribute;
        defer value.deinit(instance.ctx.allocator);
        if (dom.reflection.parseInteger(value.asSlice())) |parsed| {
            if (parsed >= std.math.minInt(i32) and parsed <= std.math.maxInt(i32)) return @intCast(parsed);
        }
    }
    // Step 3 explicitly includes MathML a, independently of href/focusability.
    // The complete HTML getter names it; other MathML elements default to -1.
    const data = dom.element_data.of(instance) orelse return -1;
    return if (std.mem.eql(u8, data.namespaceSlice() orelse "", "http://www.w3.org/1998/Math/MathML") and
        std.mem.eql(u8, data.local_name.asSlice(), "a")) 0 else -1;
}

/// Operation: focus: the focusing steps (src/html/focus.zig), as
/// HTMLElement and SVGElement run them.
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
