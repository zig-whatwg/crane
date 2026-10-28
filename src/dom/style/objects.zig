//! The CSSOM objects over the style models: one CSSStyleSheet per
//! `SheetRecord`, one CSSRule object per `rules.Rule`, made the first time
//! script reaches them and kept, while script can still reach them, by the
//! objects that lead to them - never by the models, which only link back to
//! their object for identity (`style.sheet === document.styleSheets[0]`,
//! `cssRules[0] === cssRules[0]`).
//!
//! Blink keeps these by tracing, and so does this (engine.traceChild: edges,
//! never roots):
//!
//! - a style or link element keeps its sheet's object (StyleElement /
//!   LinkStyle trace their sheet_), until the sheet is removed;
//! - a sheet object keeps its CSSRuleList and its MediaList (the generated
//!   [SameObject] edges), and the object of each of its rules a rule list
//!   handed out (CSSStyleSheet's child_rule_cssom_wrappers_; a group rule's
//!   object likewise); a rule list keeps the object whose rules it lists
//!   (StyleSheetCSSRuleList traces style_sheet_), and a rule object keeps its
//!   parent's (CSSRule::Trace visits parent_) - until the rule is removed;
//! - an @import rule's object keeps its sheet's (CSSImportRule traces
//!   style_sheet_).
//!
//! An element script never touched can be reached through
//! document.styleSheets; it is wrapped first, so its edge is drawn on a
//! wrapper the tree keeps, never held strongly while it waits for one
//! (same_object.zig: a hold on an unwrapped owner is a root that can keep a
//! realm alive).
//!
//! Spec: https://drafts.csswg.org/cssom-1/#the-cssstylesheet-interface
//! Spec: https://drafts.csswg.org/cssom-1/#the-cssrule-interface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const sheet_mod = @import("sheet.zig");
const rules_mod = @import("rules.zig");

const SheetRecord = sheet_mod.SheetRecord;
const Rule = rules_mod.Rule;

/// The traced slots, in the "CSSOM:" namespace.
pub const slots = struct {
    pub const sheet: engine.TracedSlot = .{ .name = "CSSOM:sheet" };
    pub const parent: engine.TracedSlot = .{ .name = "CSSOM:parent" };
    pub const style_sheet: engine.TracedSlot = .{ .name = "CSSOM:styleSheet" };
    pub const parent_rule: engine.TracedSlot = .{ .name = "CSSOM:parentRule" };

    /// A rule list's slot for the object of `rule`.
    pub fn rule(buffer: []u8, model: *const Rule) engine.TracedSlot {
        return .{ .name = std.fmt.bufPrint(buffer, "CSSOM:rule:{x}", .{@intFromPtr(model)}) catch "CSSOM:rule" };
    }
};

/// The CSSStyleSheet object of `record`, made now (in `realm`) if it has
/// none. Its owner element, if any, keeps it.
pub fn sheetObject(record: *SheetRecord, realm: runtime.Context) anyerror!*runtime.Instance {
    if (record.object.get()) |object| return object;
    const object = try interfaces.CSSStyleSheet.initWith(realm.allocator, realm, .{ .sheet_record = record });
    record.object.set(object);
    if (record.owner_node) |owner| keepFrom(owner, object, slots.sheet);
    return object;
}

/// The CSSRule object of `rule`, made now (in `realm`) if it has none, of
/// the interface its kind is. It keeps its parent's object, while it has a
/// parent.
pub fn ruleObject(rule: *Rule, realm: runtime.Context) anyerror!*runtime.Instance {
    if (rule.object.get()) |object| return object;
    const args = .{ .css_rule = rule };
    const a = realm.allocator;
    const object = try switch (rule.kind()) {
        .style => interfaces.CSSStyleRule.initWith(a, realm, args),
        .nested_declarations => interfaces.CSSNestedDeclarations.initWith(a, realm, args),
        .container => interfaces.CSSContainerRule.initWith(a, realm, args),
        .scope => interfaces.CSSScopeRule.initWith(a, realm, args),
        .import => interfaces.CSSImportRule.initWith(a, realm, args),
        .media => interfaces.CSSMediaRule.initWith(a, realm, args),
        .supports => interfaces.CSSSupportsRule.initWith(a, realm, args),
        .layer_block => interfaces.CSSLayerBlockRule.initWith(a, realm, args),
        .layer_statement => interfaces.CSSLayerStatementRule.initWith(a, realm, args),
        .namespace => interfaces.CSSNamespaceRule.initWith(a, realm, args),
        .font_face => interfaces.CSSFontFaceRule.initWith(a, realm, args),
        .page => interfaces.CSSPageRule.initWith(a, realm, args),
        .position_try => interfaces.CSSPositionTryRule.initWith(a, realm, args),
        .property => interfaces.CSSPropertyRule.initWith(a, realm, args),
        .keyframes => interfaces.CSSKeyframesRule.initWith(a, realm, args),
        .keyframe => interfaces.CSSKeyframeRule.initWith(a, realm, args),
    };
    rule.object.set(object);
    if (try parentObject(rule, realm)) |parent| engine.traceChild(object, parent, slots.parent);
    return object;
}

/// The object of `rule`'s parent CSS rule, or else of its parent CSS style
/// sheet; null for a removed rule.
pub fn parentObject(rule: *Rule, realm: runtime.Context) anyerror!?*runtime.Instance {
    if (rule.parent_rule) |parent| return try ruleObject(parent, realm);
    if (rule.parent_sheet) |record| return try sheetObject(record, realm);
    return null;
}

/// `rule` is being removed from its list ("remove a CSS rule" steps 5-6):
/// its parent's object no longer keeps its object, nor it its parent's, and
/// it has no parents.
pub fn ruleRemoved(rule: *Rule) void {
    @import("font_loading.zig").disconnectRule(rule);
    if (rule.object.get()) |object| {
        const parent: ?*runtime.Instance = if (rule.parent_rule) |p| p.object.get() else if (rule.parent_sheet) |p| p.object.get() else null;
        if (parent) |p| {
            var buffer: [48]u8 = undefined;
            engine.forgetTracedChild(p, slots.rule(&buffer, rule));
        }
        engine.forgetTracedChild(object, slots.parent);
    }
    rule.parent_rule = null;
    rule.parent_sheet = null;
}

/// `owner` - an element, a rule object - keeps `child` in `slot`. An owner
/// script has not wrapped yet is wrapped first (see the file comment).
pub fn keepFrom(owner: *runtime.Instance, child: *runtime.Instance, slot: engine.TracedSlot) void {
    if (!engine.hasWrapper(owner)) {
        const held = engine.retainValue(owner.ctx, .{ .instance = owner }) catch return;
        held.release();
    }
    engine.traceChild(owner, child, slot);
}

/// The style or link element `owner` let its sheet go ("remove a CSS style
/// sheet"): it no longer keeps the sheet's object.
pub fn ownerReleased(owner: *runtime.Instance) void {
    engine.forgetTracedChild(owner, slots.sheet);
}

/// A new CSSRuleList of `of`, for `owner` - the sheet or group rule object
/// whose cssRules it is - which it keeps.
pub fn ruleList(of: sheet_mod.RulesOf, owner: *runtime.Instance) !*runtime.Instance {
    const list = try interfaces.CSSRuleList.initWith(owner.ctx.allocator, owner.ctx, .{ .rules_of = of });
    engine.traceChild(list, owner, slots.parent);
    return list;
}

/// The object of `rule`, a rule a CSSRuleList of `realm` hands out: kept by
/// its parent's object (Blink's child_rule_cssom_wrappers_ on CSSStyleSheet
/// and CSSGroupingRule), until the rule is removed.
pub fn listRuleObject(realm: runtime.Context, rule: *Rule) !*runtime.Instance {
    const object = try ruleObject(rule, realm);
    if (try parentObject(rule, realm)) |parent| {
        var buffer: [48]u8 = undefined;
        engine.traceChild(parent, object, slots.rule(&buffer, rule));
    }
    return object;
}

/// HTML "associated Document" of `realm`'s global object, when it is a
/// Window.
pub fn associatedDocument(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.realm orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    if (global.vtable != &interfaces.Window.vtable) return null;
    return interfaces.Window.get_document(global) catch null;
}

/// `url` parsed relative to `base` and serialized, owned by `instance`'s
/// allocator; null when it does not parse.
pub fn parseUrl(instance: *runtime.Instance, url: []const u8, base: []const u8) ?[]u8 {
    const webidl = @import("webidl");
    const base_arg = if (base.len > 0) webidl.Opt(runtime.USVString).passed(base) else webidl.Opt(runtime.USVString).notPassed();
    const parsed = (interfaces.URL.call_static_parse(instance, url, base_arg) catch null) orelse return null;
    defer runtime.Instance.deinit(parsed);
    const href = interfaces.URL.get_href(parsed) catch return null;
    return @constCast(href);
}

/// The document a rule's media are evaluated against: its sheet's owner
/// node's document, else its sheet's constructor document (through the
/// sheets an @import chain leads to).
pub fn documentOfRule(rule: *Rule) ?*runtime.Instance {
    var record = rule.sheet() orelse return null;
    var depth: usize = 0;
    while (depth < 32) : (depth += 1) {
        if (record.owner_node) |owner| return interfaces.Node.get_ownerDocument(owner) catch null;
        if (record.constructorDocument()) |document| return document;
        record = record.parentSheet() orelse return null;
    }
    return null;
}
