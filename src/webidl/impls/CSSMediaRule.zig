//! Implementation for CSSMediaRule interface (CSS Conditional 3 9.2)
//!
//! Spec: https://drafts.csswg.org/css-conditional-3/#the-cssmediarule-interface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const webidl = @import("webidl");
const dom = @import("dom");
const CSSMediaRule = interfaces.CSSMediaRule;

pub const State = CSSMediaRule.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// The rule this object is a view of: its CSSRule part's.
fn ruleOf(instance: *runtime.Instance) ?*dom.style.Rule {
    return dom.style.hooks.cssRuleOf(instance);
}

/// Getter for media ([SameObject, PutForwards=mediaText]): "a MediaList
/// object for the list of media queries specified with the @media rule".
pub fn get_media(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const rule = ruleOf(instance) orelse return error.InvalidStateError;
    return interfaces.MediaList.initWith(instance.ctx.allocator, instance.ctx, .{ .media_of = dom.style.MediaOf{ .rule = rule } });
}

/// Getter for matches (CSS Conditional 5): whether the media query list
/// matches the state of the rendered document - the document of the sheet's
/// owner node, else of its constructor; false with neither.
pub fn get_matches(instance: *runtime.Instance) anyerror!bool {
    const rule = ruleOf(instance) orelse return false;
    if (rule.data != .media) return false;
    const document = dom.style.objects.documentOfRule(rule) orelse return false;
    const values = dom.style.hooks.mediaValues(document);
    return rule.data.media.list.matches(&values);
}
