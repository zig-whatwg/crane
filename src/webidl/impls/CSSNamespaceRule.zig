//! Implementation for CSSNamespaceRule interface (CSSOM 6.4.9)
//!
//! Spec: https://drafts.csswg.org/cssom-1/#the-cssnamespacerule-interface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const webidl = @import("webidl");
const dom = @import("dom");
const CSSNamespaceRule = interfaces.CSSNamespaceRule;

pub const State = CSSNamespaceRule.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// The rule this object is a view of: its CSSRule part's.
fn ruleOf(instance: *runtime.Instance) ?*dom.style.Rule {
    return dom.style.hooks.cssRuleOf(instance);
}

/// Getter for namespaceURI: "the namespace of the @namespace at-rule".
pub fn get_namespaceURI(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const rule = ruleOf(instance) orelse return runtime.DOMString.initEmpty();
    return switch (rule.data) {
        .namespace => |n| runtime.DOMString.initDupe(instance.ctx.allocator, n.uri),
        else => runtime.DOMString.initEmpty(),
    };
}

/// Getter for prefix: "the prefix of the @namespace at-rule or the empty
/// string if there is no prefix".
pub fn get_prefix(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const rule = ruleOf(instance) orelse return runtime.DOMString.initEmpty();
    return switch (rule.data) {
        .namespace => |n| runtime.DOMString.initDupe(instance.ctx.allocator, n.prefix),
        else => runtime.DOMString.initEmpty(),
    };
}
