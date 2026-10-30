//! CSSOM §6.4.7: page selectors, descriptors and margin grouping.
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dom = @import("dom");
const css = @import("css");
pub const State = interfaces.CSSPageRule.State;
pub const InternalState = struct {};
pub const ImplError = error{InvalidStateError};

fn ruleOf(instance: *runtime.Instance) !*dom.style.Rule {
    const rule = dom.style.hooks.cssRuleOf(instance) orelse return error.InvalidStateError;
    if (rule.kind() != .page) return error.InvalidStateError;
    return rule;
}

pub fn get_selectorText(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const rule = try ruleOf(instance);
    return runtime.DOMString.initDupe(instance.ctx.allocator, rule.prelude);
}

pub fn set_selectorText(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    const rule = try ruleOf(instance);
    // Setter steps 1–3: invalid lists leave the old selectors unchanged.
    const parsed = try css.page_values.selectors(rule.allocator, value.asSlice()) orelse return;
    rule.allocator.free(rule.prelude);
    rule.prelude = parsed;
    if (rule.sheet()) |sheet| sheet.changed();
}

pub fn get_style(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const rule = try ruleOf(instance);
    const style = try interfaces.CSSPageDescriptors.initWith(instance.ctx.allocator, instance.ctx, .{ .rule_block_of = rule });
    // Q50: the existing Keyframe/PositionTry reverse edge, paired with
    // the generated SameObject edge, retains identity after deleteRule.
    dom.style.objects.keepFrom(style, instance, dom.style.objects.slots.parent_rule);
    return style;
}
