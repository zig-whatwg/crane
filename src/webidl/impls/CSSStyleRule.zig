//! Implementation for CSSStyleRule interface (CSSOM 6.4.3)
//!
//! A style rule's object: its selector text and its declarations, live -
//! `style` is a CSSStyleDeclaration over the rule's own block, and writing
//! it (or selectorText) changes what the sheet applies. The rule is its
//! CSSRule part's (dom.style's `css_rule_of`).
//!
//! Spec: https://drafts.csswg.org/cssom-1/#the-cssstylerule-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const selector = @import("selector");
const dom = @import("dom");
const CSSStyleRule = interfaces.CSSStyleRule;

pub const State = CSSStyleRule.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

fn styleRuleOf(instance: *runtime.Instance) ?*dom.style.Rule {
    const rule = dom.style.hooks.cssRuleOf(instance) orelse return null;
    if (rule.kind() != .style) return null;
    return rule;
}

/// Getter for selectorText: "the result of performing serialize a group of
/// selectors on the associated group of selectors".
///
/// Spec: https://drafts.csswg.org/cssom-1/#dom-cssstylerule-selectortext
/// Deviation, stated: the selector is serialized from its component values
/// (src/css/rules.zig), not from the parsed selector list.
pub fn get_selectorText(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const rule = styleRuleOf(instance) orelse return runtime.DOMString.initEmpty();
    return runtime.DOMString.initDupe(instance.ctx.allocator, rule.prelude);
}

/// Setter for selectorText: "Run the parse a group of selectors algorithm on
/// the given value. If the algorithm returns a non-null value replace the
/// associated group of selectors with the returned value. If the algorithm
/// returns a null value, do nothing."
pub fn set_selectorText(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    const rule = styleRuleOf(instance) orelse return;
    const a = rule.allocator;
    const text = try a.dupe(u8, std.mem.trim(u8, value.asSlice(), " \t\n\r\x0c"));
    var parsed = selector.parse(a, text) catch |err| {
        a.free(text);
        if (err == error.OutOfMemory) return err;
        return;
    };
    errdefer parsed.deinit();
    // The old selectors borrow the old text: both go together.
    rule.data.style.selectors.deinit();
    a.free(rule.prelude);
    rule.prelude = text;
    rule.data.style.selectors = parsed;
    if (rule.sheet()) |record| record.changed();
}

/// Getter for style ([SameObject]): "a CSSStyleProperties object for the
/// style rule" - live, over the rule's own declaration block.
///
/// Spec: https://drafts.csswg.org/cssom-1/#dom-cssstylerule-style
pub fn get_style(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const rule = styleRuleOf(instance) orelse return error.InvalidStateError;
    return interfaces.CSSStyleProperties.initWith(instance.ctx.allocator, instance.ctx, .{ .rule_block_of = rule });
}

/// Getter for styleMap (CSS Typed OM): not implemented.
pub fn get_styleMap(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}
