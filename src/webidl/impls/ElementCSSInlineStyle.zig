//! Implementation for the ElementCSSInlineStyle mixin: `style` (CSSOM 6.7)
//! and `attributeStyleMap` (CSS Typed OM 1, its partial mixin), which
//! HTMLElement, SVGElement and MathMLElement include.
//!
//! Its includers inherit these members by alias (codegen/inherited_mixins.zig):
//! each is implemented here once, with the element as `this`
//! (src/webidl/AGENTS.md "Mixin members are inherited").
//!
//! Spec: https://drafts.csswg.org/cssom/#the-elementcssinlinestyle-mixin
//! Spec: https://drafts.css-houdini.org/css-typed-om-1/#dom-elementcssinlinestyle-attributestylemap

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const ElementCSSInlineStyle = interfaces.ElementCSSInlineStyle;

pub const State = ElementCSSInlineStyle.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
};

/// Internal state for implementation-specific data. None: a mixin has no
/// instances; what it keeps is its includer's (the element's rare data).
pub const InternalState = struct {};

/// The element's sparse rare block (dom.element_rare_data), which Element
/// installs the access to.
const rare_data = dom.element_rare_data;

/// Getter for style: "a CSSStyleProperties object whose readonly flag is
/// unset, whose parent CSS rule is null, and whose owner node is this" -
/// the same object for the element's whole life ([SameObject]). Its
/// declarations are the element's inline block (dom.style), not the
/// object's, so they survive the object's wrapper being collected.
///
/// Where the object is kept is the element family's, and differs only in
/// storage (codegen/writer.zig `impl_kept_same_object` and
/// `element_rare_caches`): an HTML element keeps it in its rare data's
/// `style` field (Blink's kCssomWrapper), traced on hand-out, and
/// HTMLElement's teardown frees it whole with the element - its generated
/// getter is this function itself. An SVG or MathML element's generated
/// getter caches what this makes in the rare data's `inline_style` field,
/// owned by its wrapper.
pub fn get_style(instance: *runtime.Instance) anyerror!*runtime.Instance {
    if (instance.stateAs(interfaces.HTMLElement.State) != null) return keptStyle(instance);
    return interfaces.CSSStyleProperties.initWith(instance.ctx.allocator, instance.ctx, .{ .inline_owner = instance });
}

/// An HTML element's style object, kept in its rare data.
fn keptStyle(instance: *runtime.Instance) !*runtime.Instance {
    const a = rare_data.access(instance) orelse return error.InvalidStateError;

    // The same object for the element's whole life.
    if (rare_data.keptGet(a.holder.*, .style)) |style| {
        rare_data.keptHandOut(a.holder, .style, instance, style, .{ .name = "style" });
        return style;
    }

    // Kept in rare data (Blink's kCssomWrapper) at bit 1: its two slots (the
    // object and its generation) reserved before the object is made, so
    // that nothing can fail after it is - 32 bytes for an element with no
    // other rare field.
    try rare_data.keptReserve(rare_data.contextOf(instance), a.holder, .style);
    const style = try interfaces.CSSStyleProperties.initWith(instance.ctx.allocator, instance.ctx, .{ .inline_owner = instance });
    // In place, through the holder read now: making the object may have
    // added fields and moved the block (Blink 601c5205e1d5).
    rare_data.keptSet(a.holder, .style, style);
    rare_data.keptHandOut(a.holder, .style, instance, style, .{ .name = "style" });
    return style;
}

/// Getter for attributeStyleMap: the StylePropertyMap over the element's
/// inline declarations. The generated [SameObject] accessor of each
/// includer supplies identity and the owner edge.
pub fn get_attributeStyleMap(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return dom.style.typed_om.inlineMap(instance);
}
