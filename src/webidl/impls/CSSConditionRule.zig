//! Implementation for CSSConditionRule interface (CSS Conditional 3 9.1)
//!
//! Spec: https://drafts.csswg.org/css-conditional-3/#the-cssconditionrule-interface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const webidl = @import("webidl");
const dom = @import("dom");
const CSSConditionRule = interfaces.CSSConditionRule;

pub const State = CSSConditionRule.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// The rule this object is a view of: its CSSRule part's.
fn ruleOf(instance: *runtime.Instance) ?*dom.style.Rule {
    return dom.style.hooks.cssRuleOf(instance);
}

/// Getter for conditionText: an @media rule's media query list serialized;
/// an @supports rule's condition, as written (its component values
/// serialized).
pub fn get_conditionText(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const rule = ruleOf(instance) orelse return runtime.DOMString.initEmpty();
    return switch (rule.data) {
        .media => |*m| runtime.DOMString.initOwned(try dom.style.rules.serializeMedia(instance.ctx.allocator, &m.list)),
        else => runtime.DOMString.initDupe(instance.ctx.allocator, rule.prelude),
    };
}
