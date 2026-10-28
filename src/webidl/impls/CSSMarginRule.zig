//! CSSOM §6.4.8: a margin at-rule belonging to a page rule.
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dom = @import("dom");
pub const State = interfaces.CSSMarginRule.State;
pub const InternalState = struct {};
pub const ImplError = error{InvalidStateError};

fn ruleOf(instance: *runtime.Instance) !*dom.style.Rule {
    const rule = dom.style.hooks.cssRuleOf(instance) orelse return error.InvalidStateError;
    if (rule.kind() != .margin) return error.InvalidStateError;
    return rule;
}

pub fn get_name(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const rule = try ruleOf(instance);
    return runtime.DOMString.initDupe(instance.ctx.allocator, rule.data.margin.name);
}

pub fn get_style(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const rule = try ruleOf(instance);
    // The pinned IDL returns CSSStyleDeclaration. Updating that snapshot
    // is the separately owned webref/codegen procedure.
    const style = try interfaces.CSSStyleDeclaration.initWith(instance.ctx.allocator, instance.ctx, .{ .rule_block_of = rule });
    dom.style.objects.keepFrom(style, instance, dom.style.objects.slots.parent_rule);
    return style;
}
