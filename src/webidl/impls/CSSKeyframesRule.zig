//! CSS Animations 1 §6.3. Live keyframe lists use the ordinary CSSOM
//! counted models and existing traced parent/child slots, without roots.
//! Design: Blink CSSKeyframesRule's last-match search and cached children.
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dom = @import("dom");

pub const State = interfaces.CSSKeyframesRule.State;
pub const InternalState = struct {};
pub const ImplError = error{InvalidStateError};

fn keyframesOf(instance: *runtime.Instance) ?*dom.style.Rule {
    const rule = dom.style.hooks.cssRuleOf(instance) orelse return null;
    return if (rule.kind() == .keyframes) rule else null;
}

pub fn get_name(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const rule = keyframesOf(instance) orelse return error.InvalidStateError;
    return runtime.DOMString.initDupe(instance.ctx.allocator, rule.prelude);
}

pub fn set_name(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    const rule = keyframesOf(instance) orelse return error.InvalidStateError;
    // §6.3.2's setter stores the supplied name, including reserved words;
    // validation belongs to @keyframes parsing, serialization to the model.
    const name = try rule.allocator.dupe(u8, value.asSlice());
    rule.allocator.free(rule.prelude);
    rule.prelude = name;
    if (rule.sheet()) |record| record.changed();
}

pub fn get_cssRules(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const rule = keyframesOf(instance) orelse return error.InvalidStateError;
    return dom.style.objects.ruleList(.{ .rule = rule }, instance);
}

pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const rule = keyframesOf(instance) orelse return 0;
    return @intCast(rule.data.keyframes.children.items.len);
}

pub fn call_getter(instance: *runtime.Instance, index: u32) anyerror!*runtime.Instance {
    const rule = keyframesOf(instance) orelse return error.InvalidStateError;
    // The generated indexed binding checks get_length before invoking a
    // non-null getter, so an absent index is JavaScript undefined.
    if (index >= rule.data.keyframes.children.items.len) return error.InvalidStateError;
    return dom.style.objects.listRuleObject(instance.ctx, rule.data.keyframes.children.items[index]);
}

pub fn call_appendRule(instance: *runtime.Instance, rule: typedefs.CSSOMString) anyerror!void {
    const parent = keyframesOf(instance) orelse return error.InvalidStateError;
    try dom.style.cssom.appendKeyframe(instance, parent, rule.asSlice());
}

pub fn call_deleteRule(instance: *runtime.Instance, select: typedefs.CSSOMString) anyerror!void {
    const parent = keyframesOf(instance) orelse return error.InvalidStateError;
    try dom.style.cssom.deleteKeyframe(parent, select.asSlice());
}

pub fn call_findRule(instance: *runtime.Instance, select: typedefs.CSSOMString) anyerror!?*runtime.Instance {
    const parent = keyframesOf(instance) orelse return error.InvalidStateError;
    const index = try dom.style.cssom.keyframeIndex(parent, select.asSlice()) orelse return null;
    return dom.style.objects.listRuleObject(instance.ctx, parent.data.keyframes.children.items[index]);
}
