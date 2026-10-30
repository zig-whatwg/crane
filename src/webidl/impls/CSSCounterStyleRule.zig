//! Counter Styles 3 §9.2: live CSSOM views of the rule's descriptors.
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const css = @import("css");
const dom = @import("dom");

pub const State = interfaces.CSSCounterStyleRule.State;
pub const ImplError = error{OutOfMemory};
pub const InternalState = struct {};

fn ruleOf(instance: *runtime.Instance) !*dom.style.Rule {
    const rule = dom.style.hooks.cssRuleOf(instance) orelse return error.InvalidStateError;
    if (rule.data != .counter_style) return error.InvalidStateError;
    return rule;
}

fn descriptor(instance: *runtime.Instance, kind: css.counter_style_descriptors.Descriptor) !typedefs.CSSOMString {
    const rule = try ruleOf(instance);
    return runtime.DOMString.initDupe(instance.ctx.allocator, rule.data.counter_style.get(kind));
}

fn setDescriptor(instance: *runtime.Instance, kind: css.counter_style_descriptors.Descriptor, value: typedefs.CSSOMString) !void {
    const rule = try ruleOf(instance);
    if (try rule.data.counter_style.set(kind, value.asSlice())) {
        if (rule.sheet()) |sheet| sheet.changed();
    }
}

pub fn get_name(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const rule = try ruleOf(instance);
    return runtime.DOMString.initDupe(instance.ctx.allocator, rule.data.counter_style.name);
}

pub fn set_name(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    const rule = try ruleOf(instance);
    if (try rule.data.counter_style.setName(value.asSlice())) {
        if (rule.sheet()) |sheet| sheet.changed();
    }
}

pub fn get_system(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, .system);
}

pub fn set_system(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return setDescriptor(instance, .system, value);
}

pub fn get_symbols(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, .symbols);
}

pub fn set_symbols(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return setDescriptor(instance, .symbols, value);
}

pub fn get_additiveSymbols(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, .additive_symbols);
}

pub fn set_additiveSymbols(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return setDescriptor(instance, .additive_symbols, value);
}

pub fn get_negative(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, .negative);
}

pub fn set_negative(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return setDescriptor(instance, .negative, value);
}

pub fn get_prefix(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, .prefix);
}

pub fn set_prefix(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return setDescriptor(instance, .prefix, value);
}

pub fn get_suffix(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, .suffix);
}

pub fn set_suffix(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return setDescriptor(instance, .suffix, value);
}

pub fn get_range(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, .range);
}

pub fn set_range(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return setDescriptor(instance, .range, value);
}

pub fn get_pad(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, .pad);
}

pub fn set_pad(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return setDescriptor(instance, .pad, value);
}

pub fn get_speakAs(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, .speak_as);
}

pub fn set_speakAs(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return setDescriptor(instance, .speak_as, value);
}

pub fn get_fallback(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, .fallback);
}

pub fn set_fallback(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return setDescriptor(instance, .fallback, value);
}
