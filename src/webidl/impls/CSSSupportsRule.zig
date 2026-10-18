//! Implementation for CSSSupportsRule interface (CSS Conditional 3 9.3)
//!
//! Spec: https://drafts.csswg.org/css-conditional-3/#the-csssupportsrule-interface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const webidl = @import("webidl");
const dom = @import("dom");
const CSSSupportsRule = interfaces.CSSSupportsRule;

pub const State = CSSSupportsRule.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// The rule this object is a view of: its CSSRule part's.
fn ruleOf(instance: *runtime.Instance) ?*dom.style.Rule {
    return dom.style.hooks.cssRuleOf(instance);
}

/// Getter for matches (CSS Conditional 5): whether the condition holds,
/// decided when the rule was parsed.
pub fn get_matches(instance: *runtime.Instance) anyerror!bool {
    const rule = ruleOf(instance) orelse return false;
    return switch (rule.data) {
        .supports => |s| s.holds,
        else => false,
    };
}
