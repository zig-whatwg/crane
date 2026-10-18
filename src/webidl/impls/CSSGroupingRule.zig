//! Implementation for CSSGroupingRule interface (CSSOM 6.4.5)
//!
//! A group rule's child CSS rules: cssRules ([SameObject]) lists them live;
//! insertRule() and deleteRule() edit them (dom.style.cssom). A style rule
//! is a grouping rule too (CSS Nesting); Crane's style rules hold no child
//! rules (stated in dom.style.rules), so theirs is empty and takes none.
//!
//! Spec: https://drafts.csswg.org/cssom-1/#the-cssgroupingrule-interface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const webidl = @import("webidl");
const dom = @import("dom");
const CSSGroupingRule = interfaces.CSSGroupingRule;

pub const State = CSSGroupingRule.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// The rule this object is a view of: its CSSRule part's.
fn ruleOf(instance: *runtime.Instance) ?*dom.style.Rule {
    return dom.style.hooks.cssRuleOf(instance);
}

/// Getter for cssRules ([SameObject]): "a CSSRuleList object for the child
/// CSS rules".
pub fn get_cssRules(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const rule = ruleOf(instance) orelse return error.InvalidStateError;
    return dom.style.objects.ruleList(.{ .rule = rule }, instance);
}

/// insertRule(rule, index): "Return the result of invoking insert a CSS
/// rule rule into the child CSS rules at index, with nested set to true if
/// this is a nested group rule, or false otherwise."
pub fn call_insertRule(instance: *runtime.Instance, rule: typedefs.CSSOMString, index: webidl.Opt(u32)) anyerror!u32 {
    const model = ruleOf(instance) orelse return error.InvalidStateError;
    if (model.children() == null) return error.HierarchyRequestError;
    return dom.style.cssom.insertRule(instance, .{ .rule = model }, rule.asSlice(), index.getOrDefault(0), .{});
}

/// deleteRule(index): "Remove a CSS rule from the child CSS rules at
/// index."
pub fn call_deleteRule(instance: *runtime.Instance, index: u32) anyerror!void {
    const model = ruleOf(instance) orelse return error.InvalidStateError;
    if (model.children() == null) return error.IndexSizeError;
    try dom.style.cssom.removeRule(instance, .{ .rule = model }, index);
}
