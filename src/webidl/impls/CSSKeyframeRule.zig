//! CSS Animations 1 §6.2. The generated CSSRule construction chain owns
//! the model, and CSSStyleProperties owns its declared block view.
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dom = @import("dom");
const css = @import("css");

pub const State = interfaces.CSSKeyframeRule.State;
pub const InternalState = struct {};
pub const ImplError = error{InvalidStateError};

fn keyframeOf(instance: *runtime.Instance) ?*dom.style.Rule {
    const rule = dom.style.hooks.cssRuleOf(instance) orelse return null;
    return if (rule.kind() == .keyframe) rule else null;
}

pub fn get_keyText(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const rule = keyframeOf(instance) orelse return error.InvalidStateError;
    return runtime.DOMString.initDupe(instance.ctx.allocator, rule.prelude);
}

pub fn set_keyText(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    const rule = keyframeOf(instance) orelse return error.InvalidStateError;
    // Q63: Firefox/Safari preserve the old value without throwing on an
    // invalid selector. The 2018 spec's SyntaxError has no newer-rule lag.
    var selectors = try css.keyframe_values.Selectors.parse(rule.allocator, value.asSlice()) orelse return;
    errdefer selectors.deinit();
    const prelude = try selectors.serialize(rule.allocator);
    rule.data.keyframe.selectors.deinit();
    rule.allocator.free(rule.prelude);
    rule.data.keyframe.selectors = selectors;
    rule.prelude = prelude;
    if (rule.sheet()) |record| record.changed();
}

pub fn get_style(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const rule = keyframeOf(instance) orelse return error.InvalidStateError;
    const style = try interfaces.CSSStyleProperties.initWith(instance.ctx.allocator, instance.ctx, .{ .rule_block_of = rule });
    // The generated [SameObject] edge is rule→style. This reverse edge
    // keeps the whole parent chain reachable when only the style survives.
    dom.style.objects.keepFrom(style, instance, dom.style.objects.slots.parent_rule);
    return style;
}
