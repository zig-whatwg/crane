//! Implementation for CSSLayerBlockRule interface (CSS Cascade 5 7.1)
//!
//! Spec: https://drafts.csswg.org/css-cascade-5/#the-csslayerblockrule-interface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const webidl = @import("webidl");
const dom = @import("dom");
const CSSLayerBlockRule = interfaces.CSSLayerBlockRule;

pub const State = CSSLayerBlockRule.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// The rule this object is a view of: its CSSRule part's.
fn ruleOf(instance: *runtime.Instance) ?*dom.style.Rule {
    return dom.style.hooks.cssRuleOf(instance);
}

/// Getter for name: "the name of the associated cascade layer" - "" for an
/// anonymous one.
pub fn get_name(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const rule = ruleOf(instance) orelse return runtime.DOMString.initEmpty();
    return switch (rule.data) {
        .layer_block => |l| if (l.name) |n| runtime.DOMString.initDupe(instance.ctx.allocator, n) else runtime.DOMString.initEmpty(),
        else => runtime.DOMString.initEmpty(),
    };
}
