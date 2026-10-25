//! Implementation for CSSFontFaceRule interface (CSS Fonts 4)
//!
//! The rule owns a validated descriptor block. Its SameObject style view
//! uses the generated CSSStyleDeclaration parent and traces its cached view.
//!
//! Spec: https://drafts.csswg.org/css-fonts-4/#om-fontface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const webidl = @import("webidl");
const dom = @import("dom");
const CSSFontFaceRule = interfaces.CSSFontFaceRule;

pub const State = CSSFontFaceRule.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// The rule this object is a view of: its CSSRule part's.
fn ruleOf(instance: *runtime.Instance) ?*dom.style.Rule {
    return dom.style.hooks.cssRuleOf(instance);
}

/// CSS Fonts 4 §12.1: the live descriptor block (SameObject is generated).
pub fn get_style(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const rule = ruleOf(instance) orelse return error.InvalidStateError;
    return interfaces.CSSFontFaceDescriptors.initWith(instance.ctx.allocator, instance.ctx, .{ .rule_block_of = rule });
}
