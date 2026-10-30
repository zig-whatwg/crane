//! CSS Cascade 6 section 4.1: the serialized scoping boundaries.
//! Evaluation and scope proximity are tracked by CSS @SCOPE EVALUATION.
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dom = @import("dom");

pub const State = interfaces.CSSScopeRule.State;
pub const InternalState = struct {};

pub fn get_start(instance: *runtime.Instance) anyerror!?typedefs.CSSOMString {
    const rule = dom.style.hooks.cssRuleOf(instance) orelse return null;
    if (rule.data != .scope) return null;
    const text = rule.data.scope.start orelse return null;
    return try runtime.DOMString.initDupe(instance.ctx.allocator, text);
}

pub fn get_end(instance: *runtime.Instance) anyerror!?typedefs.CSSOMString {
    const rule = dom.style.hooks.cssRuleOf(instance) orelse return null;
    if (rule.data != .scope) return null;
    const text = rule.data.scope.end orelse return null;
    return try runtime.DOMString.initDupe(instance.ctx.allocator, text);
}
