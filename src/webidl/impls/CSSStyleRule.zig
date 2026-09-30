//! Implementation for CSSStyleRule interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CSSStyleRule = interfaces.CSSStyleRule;

pub const State = CSSStyleRule.State;

pub const ImplError = error{
    NotImplemented,
};

// A style rule's selector and declarations are its model's
// (src/dom/cssom.zig), bound to this object by the CSSRuleList that made it.
const cssom = @import("dom").cssom;

/// Internal state for implementation-specific data: none - the rule's
/// state is its model's (`cssom.StyleRule`).
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance: its hold on its model ends.
pub fn deinit(instance: *runtime.Instance) void {
    cssom.unbindRule(instance);
    // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Getter for selectorText: the rule's selector list, serialized.
///
/// Spec: https://drafts.csswg.org/cssom-1/#dom-cssstylerule-selectortext
/// Deviation, stated: the selector is serialized from its component values
/// (src/css/rules.zig), not from a parsed selector list.
pub fn get_selectorText(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const model = cssom.ruleOf(instance) orelse return runtime.DOMString.initEmpty();
    // The model outlives the call: this object holds it.
    return runtime.DOMString.initInterned(model.selector_text);
}

/// Getter for style ([SameObject]): a CSS declaration block with the rule's
/// declarations.
///
/// Spec: https://drafts.csswg.org/cssom-1/#dom-cssstylerule-style
/// Deviation, stated: the block is a copy of the declarations made when it
/// is first read; changing it does not change the rule.
pub fn get_style(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const allocator = instance.ctx.allocator;
    const style = try interfaces.CSSStyleDeclaration.init(allocator, instance.ctx);
    errdefer runtime.Instance.deinit(style);
    const model = cssom.ruleOf(instance) orelse return style;
    const text = try model.declarationsText(allocator);
    defer allocator.free(text);
    try interfaces.CSSStyleDeclaration.set_cssText(style, runtime.DOMString.initInterned(text));
    return style;
}

/// Getter for styleMap
pub fn get_styleMap(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for selectorText: "Run the parse a group of selectors algorithm on
/// the given value. If the algorithm returns a non-null value replace the
/// associated CSS style rule's selectors with the returned value. If the
/// algorithm returns a null value, do nothing."
pub fn set_selectorText(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    const model = cssom.ruleOf(instance) orelse return;
    _ = try cssom.setSelectorText(model, value.asSlice());
}
