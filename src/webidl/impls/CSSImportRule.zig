//! Implementation for CSSImportRule interface (CSSOM 6.4.4)
//!
//! Spec: https://drafts.csswg.org/cssom-1/#the-cssimportrule-interface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const webidl = @import("webidl");
const dom = @import("dom");
const CSSImportRule = interfaces.CSSImportRule;

pub const State = CSSImportRule.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// The rule this object is a view of: its CSSRule part's.
fn ruleOf(instance: *runtime.Instance) ?*dom.style.Rule {
    return dom.style.hooks.cssRuleOf(instance);
}

fn importOf(instance: *runtime.Instance) ?*dom.style.rules.Import {
    const rule = ruleOf(instance) orelse return null;
    return switch (rule.data) {
        .import => |*i| i,
        else => null,
    };
}

/// Getter for href: "the URL of the urlString of the @import rule".
pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
    const import = importOf(instance) orelse return "";
    return instance.ctx.allocator.dupe(u8, import.href);
}

/// Getter for media ([SameObject, PutForwards=mediaText]): "the value of
/// the media attribute of the associated CSS style sheet". The imported
/// sheet delegates to this same view of the rule's media list.
pub fn get_media(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const rule = ruleOf(instance) orelse return error.InvalidStateError;
    return interfaces.MediaList.initWith(instance.ctx.allocator, instance.ctx, .{ .media_of = dom.style.MediaOf{ .rule = rule } });
}

/// Getter for styleSheet: "the associated CSS style sheet, if any, or null
/// otherwise" - the sheet the loader fetched for the rule, which this rule's
/// object keeps.
pub fn get_styleSheet(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const import = importOf(instance) orelse return null;
    const child = import.child orelse return null;
    const sheet = try dom.style.objects.sheetObject(child, instance.ctx);
    engine.traceChild(instance, sheet, dom.style.objects.slots.style_sheet);
    return sheet;
}

/// Getter for layerName: "the layer name declared in the at-rule itself,
/// or an empty string if the layer is anonymous, or null if the at-rule
/// does not declare a layer".
pub fn get_layerName(instance: *runtime.Instance) anyerror!?typedefs.CSSOMString {
    const import = importOf(instance) orelse return null;
    const layer = import.layer orelse return null;
    return try runtime.DOMString.initDupe(instance.ctx.allocator, layer);
}

/// Getter for supportsText: "the supports() condition specified in the
/// at-rule itself, or null if the at-rule does not specify one".
pub fn get_supportsText(instance: *runtime.Instance) anyerror!?typedefs.CSSOMString {
    const import = importOf(instance) orelse return null;
    const text = import.supports orelse return null;
    return try runtime.DOMString.initDupe(instance.ctx.allocator, text);
}
