//! CSS Properties and Values §6.1: a view of an immutable registration.
//! The generated CSSRule construction chain owns the native rule record.
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dom = @import("dom");
const css = @import("css");

pub const State = interfaces.CSSPropertyRule.State;
pub const InternalState = struct {};

fn registrationOf(instance: *runtime.Instance) !*const css.property_registry.Registration {
    const rule = dom.style.hooks.cssRuleOf(instance) orelse return error.InvalidStateError;
    if (rule.data != .property) return error.InvalidStateError;
    return rule.data.property;
}

pub fn get_name(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return runtime.DOMString.initDupe(instance.ctx.allocator, (try registrationOf(instance)).name);
}

pub fn get_syntax(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return runtime.DOMString.initDupe(instance.ctx.allocator, (try registrationOf(instance)).syntax_text);
}

pub fn get_inherits(instance: *runtime.Instance) anyerror!bool {
    return (try registrationOf(instance)).inherits;
}

pub fn get_initialValue(instance: *runtime.Instance) anyerror!?typedefs.CSSOMString {
    const text = (try registrationOf(instance)).initial_text orelse return null;
    return try runtime.DOMString.initDupe(instance.ctx.allocator, text);
}
