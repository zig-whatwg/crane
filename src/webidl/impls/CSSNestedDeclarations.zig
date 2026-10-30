//! CSS Nesting 1 section 5.1: the declaration block of this nested rule.
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

pub const State = interfaces.CSSNestedDeclarations.State;
pub const InternalState = struct {};

/// The generated SameObject machinery keeps this declaration object on
/// its rule, exactly as for CSSStyleRule.style.
pub fn get_style(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const rule = dom.style.hooks.cssRuleOf(instance) orelse return error.InvalidStateError;
    if (rule.kind() != .nested_declarations) return error.InvalidStateError;
    return interfaces.CSSStyleProperties.initWith(instance.ctx.allocator, instance.ctx, .{ .rule_block_of = rule });
}
