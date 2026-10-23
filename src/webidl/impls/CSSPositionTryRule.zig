//! CSS Anchor Position 1 §8.1: the CSSOM view of a position-try rule.
//! The generated construction chain owns its CSSRule state. The descriptor
//! object uses the same counted model and traced parent links as CSSOM.
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dom = @import("dom");

pub const State = interfaces.CSSPositionTryRule.State;
pub const InternalState = struct {};
pub const ImplError = error{InvalidStateError};

fn positionTryOf(instance: *runtime.Instance) ?*dom.style.Rule {
    const rule = dom.style.hooks.cssRuleOf(instance) orelse return null;
    return if (rule.kind() == .position_try) rule else null;
}

/// Blink CSSPositionTryRule::name serializes the identifier, as its cssText
/// does: https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/css/css_position_try_rule.cc
pub fn get_name(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const rule = positionTryOf(instance) orelse return error.InvalidStateError;
    return runtime.DOMString.initDupe(instance.ctx.allocator, rule.prelude);
}

/// §8.1: one live CSSPositionTryDescriptors whose parent CSS rule is this.
/// The generated [SameObject] edge keeps the descriptor from this rule;
/// the existing CSSOM parent slot keeps the rule from its descriptor.
pub fn get_style(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const rule = positionTryOf(instance) orelse return error.InvalidStateError;
    const descriptor = try interfaces.CSSPositionTryDescriptors.initWith(instance.ctx.allocator, instance.ctx, .{ .rule_block_of = rule });
    dom.style.objects.keepFrom(descriptor, instance, dom.style.objects.slots.parent_rule);
    return descriptor;
}
