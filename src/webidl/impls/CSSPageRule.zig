//! Implementation for CSSPageRule interface (CSSOM 6.4.7)
//!
//! The rule's selector (its prelude) and descriptors are kept (cssText
//! reads them back); `style`, a CSSPageDescriptors object, is not
//! implemented, and selectorText is read-only here (stated).
//!
//! Spec: https://drafts.csswg.org/cssom-1/#the-csspagerule-interface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const webidl = @import("webidl");
const dom = @import("dom");
const CSSPageRule = interfaces.CSSPageRule;

pub const State = CSSPageRule.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// The rule this object is a view of: its CSSRule part's.
fn ruleOf(instance: *runtime.Instance) ?*dom.style.Rule {
    return dom.style.hooks.cssRuleOf(instance);
}

/// Getter for selectorText: the page selector list, as written.
pub fn get_selectorText(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const rule = ruleOf(instance) orelse return runtime.DOMString.initEmpty();
    return runtime.DOMString.initDupe(instance.ctx.allocator, rule.prelude);
}

/// Getter for style (CSSPageDescriptors): not implemented.
pub fn get_style(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for selectorText: not modelled (stated).
pub fn set_selectorText(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    _ = instance;
    _ = value;
}
