//! Implementation for CSSStyleSheet interface (CSSOM 6.1.2)
//!
//! A CSSStyleSheet is a view of a CSS style sheet (dom.style.SheetRecord),
//! which its StyleSheet part holds; this reads it through dom.style's
//! `sheet_record_of`. The sheet's CSS rules are its record's rule tree
//! (dom.style.rules); its CSSRuleList (cssRules and rules, one object) and
//! the CSSRule objects are dom.style.objects'.
//!
//! The origin-clean flag guards the rules: a sheet fetched from another
//! origin without CORS throws SecurityError on cssRules, insertRule() and
//! deleteRule().
//!
//! Spec: https://drafts.csswg.org/cssom-1/#the-cssstylesheet-interface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const dom = @import("dom");
const CSSStyleSheet = interfaces.CSSStyleSheet;

pub const State = CSSStyleSheet.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

fn recordOf(instance: *runtime.Instance) !*dom.style.SheetRecord {
    return dom.style.hooks.sheetRecordOf(instance) orelse error.InvalidStateError;
}

/// new CSSStyleSheet(options): CSSOM "create a constructed CSSStyleSheet".
///
/// Spec: https://drafts.csswg.org/cssom-1/#create-a-constructed-cssstylesheet
/// "2. Set sheet's location to the base URL of the associated Document for
///  the current global object. 3. Set sheet's stylesheet base URL to the
///  baseURL attribute value from options. ... 10. Set sheet's constructed
///  flag. 11. Set sheet's Constructor document to the associated Document
///  for the current global object. 12. If the media attribute of options is
///  a string, create a MediaList object from the string and assign it as
///  sheet's media. Otherwise, serialize a media query list from the
///  attribute and then create a MediaList object from the resulting string
///  and set it as sheet's media. 13. If the disabled attribute of options is
///  true, set sheet's disabled flag."
///
/// The base URL is parsed relative to the location, and one that does not
/// parse throws NotAllowedError: the spec leaves both unsaid, and all three
/// browsers do so (css/cssom/CSSStyleSheet-constructable-baseURL.html passes
/// in Chrome, Firefox and Safari at wpt.fyi).
pub fn call_constructor(ctx: runtime.Context, options: webidl.Opt(dictionaries.CSSStyleSheetInit)) !*runtime.Instance {
    const allocator = ctx.allocator;
    const init: dictionaries.CSSStyleSheetInit = if (options.wasPassed()) options.getValue() else .{};
    const document = dom.style.objects.associatedDocument(ctx) orelse return error.NotSupportedError;
    // 2.
    const location = try interfaces.Node.get_baseURI(document);
    defer document.ctx.allocator.free(location);
    // 3.
    var base: []const u8 = location;
    var parsed_base: ?[]u8 = null;
    defer if (parsed_base) |b| allocator.free(b);
    if (init.baseURL) |given| {
        parsed_base = dom.style.objects.parseUrl(document, given.asSlice(), location) orelse return error.NotAllowedError;
        base = parsed_base.?;
    }
    // 12.
    var media_text: []const u8 = "";
    var media_owned: ?[]u8 = null;
    defer if (media_owned) |m| allocator.free(m);
    if (init.media) |media| {
        if (engine.convertToPlatformObject(ctx, media)) |object| {
            if (object.vtable == &interfaces.MediaList.vtable) {
                var text = try interfaces.MediaList.get_mediaText(object);
                defer text.deinit(object.ctx.allocator);
                media_owned = try allocator.dupe(u8, text.asSlice());
                media_text = media_owned.?;
            }
        }
        if (media_owned == null) {
            media_owned = try engine.convertToDOMString(ctx, media, allocator);
            media_text = media_owned.?;
        }
    }
    const record = try dom.style.SheetRecord.create(allocator, "", .{
        .location = location,
        .base_url = base,
        .media = media_text,
        .mode = .{ .quirks = dom.document_internals.getMode(document) == .quirks },
    });
    defer record.unref();
    // 10, 11.
    record.constructed = true;
    record.constructor_document = document;
    record.constructor_document_generation = runtime.SlabAllocator.generationOf(document);
    // 13.
    record.disabled = init.disabled orelse false;
    const sheet = try interfaces.CSSStyleSheet.initWith(allocator, ctx, .{ .sheet_record = record });
    record.object.set(sheet);
    return sheet;
}

/// Getter for ownerRule: the owner CSS rule - the @import rule whose sheet
/// this is - as its CSSImportRule object.
pub fn get_ownerRule(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const record = try recordOf(instance);
    const rule = record.owner_rule orelse return null;
    return try dom.style.objects.ruleObject(rule, instance.ctx);
}

/// Getter for cssRules ([SameObject]): "1. If the origin-clean flag is
/// unset, throw a SecurityError exception. 2. Return a read-only, live
/// CSSRuleList object representing the CSS rules." `rules` is the same
/// object.
///
/// Spec: https://drafts.csswg.org/cssom-1/#dom-cssstylesheet-cssrules
pub fn get_cssRules(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return ruleList(instance);
}

/// Getter for rules: "The rules attribute must follow the same steps as
/// cssRules, and return the same object cssRules would return."
pub fn get_rules(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return ruleList(instance);
}

fn ruleList(instance: *runtime.Instance) !*runtime.Instance {
    const record = try recordOf(instance);
    if (!record.origin_clean) return error.SecurityError;
    const state = instance.getState(State);
    if (state.own.cached_cssRules) |list| return list;
    if (state.own.cached_rules) |list| return list;
    return dom.style.objects.ruleList(.{ .sheet = record }, instance);
}

/// insertRule(rule, index): "1. If the origin-clean flag is unset, throw a
/// SecurityError exception. 2. If the disallow modification flag is set,
/// throw a NotAllowedError DOMException. 3. Let parsed rule be the return
/// value of invoking parse a rule with rule. 4. If parsed rule is a syntax
/// error, throw a SyntaxError DOMException. 5. If parsed rule is an @import
/// rule, and the constructed flag is set, throw a SyntaxError DOMException.
/// 6. Return the result of invoking insert a CSS rule rule in the CSS rules
/// at index."
///
/// Spec: https://drafts.csswg.org/cssom-1/#dom-cssstylesheet-insertrule
pub fn call_insertRule(instance: *runtime.Instance, rule: typedefs.CSSOMString, index: webidl.Opt(u32)) anyerror!u32 {
    const record = try recordOf(instance);
    if (!record.origin_clean) return error.SecurityError;
    if (record.disallow_modification) return error.NotAllowedError;
    return dom.style.cssom.insertRule(instance, .{ .sheet = record }, rule.asSlice(), index.getOrDefault(0), .{ .forbid_import = record.constructed });
}

/// deleteRule(index): "1. If the origin-clean flag is unset, throw a
/// SecurityError exception. 2. If the disallow modification flag is set,
/// throw a NotAllowedError DOMException. 3. Remove a CSS rule in the CSS
/// rules at index."
pub fn call_deleteRule(instance: *runtime.Instance, index: u32) anyerror!void {
    const record = try recordOf(instance);
    if (!record.origin_clean) return error.SecurityError;
    if (record.disallow_modification) return error.NotAllowedError;
    try dom.style.cssom.removeRule(instance, .{ .sheet = record }, index);
}

/// replaceSync(text): CSSOM "synchronously replace the rules of a
/// CSSStyleSheet": "1. If the constructed flag is not set, or the disallow
/// modification flag is set, throw a NotAllowedError DOMException. 2. Let
/// rules be the result of running parse a stylesheet's contents from text.
/// 3. If rules contains one or more @import rules, remove those rules from
/// rules. 4. Set sheet's CSS rules to rules."
///
/// Spec: https://drafts.csswg.org/cssom-1/#synchronously-replace-the-rules-of-a-cssstylesheet
pub fn call_replaceSync(instance: *runtime.Instance, text: runtime.USVString) anyerror!void {
    const record = try recordOf(instance);
    if (!record.constructed or record.disallow_modification) return error.NotAllowedError;
    try dom.style.cssom.replaceRules(instance, record, text);
}

/// replace(text): "1. Let promise be a promise. 2. If the constructed flag
/// is not set, or the disallow modification flag is set, reject promise
/// with a NotAllowedError DOMException and return promise. 3. Set the
/// disallow modification flag. 4. In parallel, do these steps: 1. Let rules
/// be the result of running parse a stylesheet's contents from text. 2. If
/// rules contains one or more @import rules, remove those rules from rules.
/// 3. Set sheet's CSS rules to rules. 4. Unset sheet's disallow
/// modification flag. 5. Resolve promise with sheet. 5. Return promise."
///
/// The parse runs in a task of the sheet's realm (the DOM manipulation task
/// source), as "in parallel" lets it: what script sees - the flag set until
/// the promise resolves, the rules replaced when it does - is the same.
pub fn call_replace(instance: *runtime.Instance, text: runtime.USVString) anyerror!runtime.JSValue {
    const record = try recordOf(instance);
    return dom.style.cssom.replace(instance, record, text);
}

/// addRule(selector, block, optionalIndex): "1. Let rule be an empty
/// string. 2. Append selector to rule. 3. Append " { " to rule. 4. If block
/// is not empty, append block, followed by a space, to rule. 5. Append "}"
/// to rule. 6. Let index be optionalIndex if provided, or the number of CSS
/// rules in the stylesheet otherwise. 7. Call insertRule(), with rule and
/// index as arguments. 8. Return -1."
pub fn call_addRule(instance: *runtime.Instance, selector: webidl.Opt(runtime.DOMString), style: webidl.Opt(runtime.DOMString), index: webidl.Opt(u32)) anyerror!i32 {
    const allocator = instance.ctx.allocator;
    const selector_text = if (selector.wasPassed()) selector.getValue().asSlice() else "undefined";
    const block = if (style.wasPassed()) style.getValue().asSlice() else "undefined";
    var rule: std.ArrayList(u8) = .empty;
    defer rule.deinit(allocator);
    try rule.appendSlice(allocator, selector_text);
    try rule.appendSlice(allocator, " { ");
    if (block.len != 0) {
        try rule.appendSlice(allocator, block);
        try rule.append(allocator, ' ');
    }
    try rule.append(allocator, '}');
    const at: u32 = if (index.wasPassed()) index.getValue() else blk: {
        const record = try recordOf(instance);
        if (!record.origin_clean) return error.SecurityError;
        const list = try record.rulesOf(instance);
        break :blk @intCast(list.items.len);
    };
    _ = try call_insertRule(instance, runtime.DOMString.initInterned(rule.items), webidl.Opt(u32).passed(at));
    return -1;
}

/// removeRule(index): "must run the same steps as deleteRule()".
pub fn call_removeRule(instance: *runtime.Instance, index: webidl.Opt(u32)) anyerror!void {
    return call_deleteRule(instance, index.getOrDefault(0));
}
