//! Implementation for CSSRule interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CSSRule = interfaces.CSSRule;

pub const State = CSSRule.State;

pub const ImplError = error{
    NotImplemented,
};

// A rule's text and parent sheet are its model's (src/dom/cssom.zig).
const cssom = @import("dom").cssom;

/// Internal state for implementation-specific data: none - a rule's state
/// is its model's (`cssom.StyleRule`).
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

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    cssom.unbindRule(instance);
    // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Getter for cssText: "serialize a CSS rule".
///
/// Spec: https://drafts.csswg.org/cssom-1/#dom-cssrule-csstext
pub fn get_cssText(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const model = cssom.ruleOf(instance) orelse return runtime.DOMString.initEmpty();
    return runtime.DOMString.initOwned(try model.cssText(instance.ctx.allocator));
}

/// Getter for parentRule: no rule here is nested in another.
pub fn get_parentRule(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for parentStyleSheet: the rule's parent CSS style sheet, null once
/// it is removed from the sheet's rules (or the sheet has gone).
///
/// Spec: https://drafts.csswg.org/cssom-1/#dom-cssrule-parentstylesheet
pub fn get_parentStyleSheet(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const model = cssom.ruleOf(instance) orelse return null;
    return cssom.parentSheetOf(model);
}

/// Getter for type: STYLE_RULE for a style rule, the only kind modelled.
///
/// Spec: https://drafts.csswg.org/cssom-1/#dom-cssrule-type
pub fn get_type(instance: *runtime.Instance) anyerror!u16 {
    if (cssom.ruleOf(instance) == null) return 0;
    return interfaces.CSSRule.get_STYLE_RULE();
}

/// Setter for cssText: "On setting the cssText attribute must do nothing."
pub fn set_cssText(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    _ = instance;
    _ = value;
}
