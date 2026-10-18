//! Implementation for CSSRule interface (CSSOM 6.4.2)
//!
//! A CSSRule object - always one of its subclasses - is a view of a CSS rule
//! (dom.style.Rule), which it holds (counted) from construction: a rule
//! removed from its list stays readable through its object, with no
//! parents. The rule links back to this object for identity; the
//! subclasses read it through dom.style's `css_rule_of`, which this
//! installs.
//!
//! Spec: https://drafts.csswg.org/cssom-1/#the-cssrule-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dom = @import("dom");
const CSSRule = interfaces.CSSRule;

pub const State = CSSRule.State;

pub const ImplError = error{
    NotImplemented,
};

/// The CSS rule this object is a view of (its construction argument).
pub const construction_args = .{"css_rule"};

pub const InternalState = struct {
    /// Held.
    rule: *dom.style.Rule,
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

fn ruleOf(instance: *runtime.Instance) ?*dom.style.Rule {
    const internal = getInternal(instance) orelse return null;
    return internal.rule;
}

/// The hooks this type owns, installed once, at process start.
pub fn installHooks() void {
    dom.style.hooks.install(.{ .css_rule_of = &ruleOf });
}

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = allocator;
    const rule: *dom.style.Rule = args.css_rule;
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{ .rule = rule };
    rule.ref();
    instance.getState(State).own._internal = internal;
}

/// The object goes: it lets its rule go.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    internal.rule.object.clearIf(instance);
    internal.rule.unref();
    runtime.arenaOf(instance).destroy(InternalState, internal);
}

/// Getter for cssText: "return a serialization of the CSS rule".
///
/// Spec: https://drafts.csswg.org/cssom-1/#dom-cssrule-csstext
pub fn get_cssText(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const rule = ruleOf(instance) orelse return runtime.DOMString.initEmpty();
    return runtime.DOMString.initOwned(try rule.serialize(instance.ctx.allocator));
}

/// Setter for cssText: "On setting the cssText attribute must do nothing."
pub fn set_cssText(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    _ = instance;
    _ = value;
}

/// Getter for parentRule: "the parent CSS rule".
pub fn get_parentRule(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const rule = ruleOf(instance) orelse return null;
    const parent = rule.parent_rule orelse return null;
    return try dom.style.objects.ruleObject(parent, instance.ctx);
}

/// Getter for parentStyleSheet: "the parent CSS style sheet" - the sheet
/// the rule is in, through its parent rules; null once removed.
///
/// Spec: https://drafts.csswg.org/cssom-1/#dom-cssrule-parentstylesheet
pub fn get_parentStyleSheet(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const rule = ruleOf(instance) orelse return null;
    if (rule.parent_rule == null and rule.parent_sheet == null) return null;
    const record = rule.sheet() orelse return null;
    return try dom.style.objects.sheetObject(record, instance.ctx);
}

/// Getter for type: the constant of the rule's kind, 0 for the kinds CSSOM
/// gives none.
///
/// Spec: https://drafts.csswg.org/cssom-1/#dom-cssrule-type
pub fn get_type(instance: *runtime.Instance) anyerror!u16 {
    const rule = ruleOf(instance) orelse return 0;
    return rule.kind().typeConstant();
}
