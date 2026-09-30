//! Implementation for CSSStyleSheet interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const CSSStyleSheet = interfaces.CSSStyleSheet;

pub const State = CSSStyleSheet.State;

pub const ImplError = error{
    NotImplemented,
};

// A sheet's CSS rules and flags are the CSSOM model's (src/dom/cssom.zig),
// which CSSRuleList and the CSSRule objects read too.
const cssom = @import("dom").cssom;

/// Internal state for implementation-specific data: none - the sheet's
/// state is its model's (`cssom.Sheet`).
pub const InternalState = struct {};

/// Initialize instance (creates the instance), bound to an empty model.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    _ = try cssom.createSheet(instance);
    return instance;
}

/// Deinitialize instance: the model goes, and its rules lose their parent
/// CSS style sheet.
pub fn deinit(instance: *runtime.Instance) void {
    cssom.destroySheet(instance);
    // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// new CSSStyleSheet(options): CSSOM "create a constructed CSSStyleSheet".
///
/// Spec: https://drafts.csswg.org/cssom-1/#dom-cssstylesheet-cssstylesheet
/// "1. Construct a new CSSStyleSheet object sheet. 2. Set sheet's location to
///  the base URL of the associated Document for the current global object.
///  ... 5. Set sheet's constructed flag. 6. Set sheet's constructor document
///  ... 7. If the baseURL attribute is set, set sheet's stylesheet base URL
///  to the result of parsing it relative to sheet's location ... 8. If the
///  media attribute is a string, create a MediaList ... 9. If the disabled
///  attribute is true, set sheet's disabled flag."
///
/// Deviation, stated: location, base URL, media and disabled are not kept -
/// no style sheet model reads them yet (relative URLs in the rules are kept
/// as written, and nothing applies a sheet).
pub fn call_constructor(ctx: runtime.Context, options: webidl.Opt(dictionaries.CSSStyleSheetInit)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &CSSStyleSheet.vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    _ = options;
    // Step 5.
    const sheet = cssom.sheetOf(instance) orelse return error.InvalidStateError;
    sheet.constructed = true;
    return instance;
}

/// Getter for ownerRule: a constructed sheet, or one no @import owns, has
/// none.
pub fn get_ownerRule(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for cssRules ([SameObject]): a CSSRuleList of the sheet's CSS
/// rules. `rules` is the same object (see `ruleList`).
///
/// Spec: https://drafts.csswg.org/cssom-1/#dom-cssstylesheet-cssrules
/// (The origin-clean flag is always set: no sheet here is fetched
/// cross-origin.)
pub fn get_cssRules(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return ruleList(instance);
}

/// Getter for rules: "The rules attribute must follow the same steps as
/// cssRules".
pub fn get_rules(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return ruleList(instance);
}

/// The one CSSRuleList of the sheet: made on first read, and kept in the
/// [SameObject] cache of whichever of the two getters asked first.
fn ruleList(instance: *runtime.Instance) !*runtime.Instance {
    const state = instance.getState(State);
    if (state.own.cached_cssRules) |list| return list;
    if (state.own.cached_rules) |list| return list;
    const list = try interfaces.CSSRuleList.init(instance.ctx.allocator, instance.ctx);
    errdefer runtime.Instance.deinit(list);
    try cssom.bindRuleList(list, instance);
    return list;
}

/// Operation: deleteRule
pub fn call_deleteRule(instance: *runtime.Instance, index: u32) anyerror!void {
    _ = instance;
    _ = index;
    return error.NotImplemented;
}

/// Operation: replaceSync(text)
///
/// Spec: https://drafts.csswg.org/cssom-1/#dom-cssstylesheet-replacesync
/// "1. If the constructed flag is not set, or the disallow modification flag
///  is set, throw a NotAllowedError DOMException. 2. Let rules be the result
///  of running parse a stylesheet's contents from text. 3. If rules contains
///  one or more @import rules, remove those rules from rules. 4. Set sheet's
///  CSS rules to rules." (Steps 2-4: cssom.replaceRules.)
pub fn call_replaceSync(instance: *runtime.Instance, text: runtime.USVString) anyerror!void {
    const sheet = cssom.sheetOf(instance) orelse return error.InvalidStateError;
    // Step 1.
    if (!sheet.constructed or sheet.disallow_modification) return error.NotAllowedError;
    try cssom.replaceRules(instance, text);
}

/// Operation: replace
pub fn call_replace(instance: *runtime.Instance, text: runtime.USVString) anyerror!runtime.JSValue {
    _ = instance;
    _ = text;
    return error.NotImplemented;
}

/// Operation: insertRule
pub fn call_insertRule(instance: *runtime.Instance, rule: typedefs.CSSOMString, index: webidl.Opt(u32)) anyerror!u32 {
    _ = instance;
    _ = rule;
    _ = index;
    return error.NotImplemented;
}

/// Operation: addRule
pub fn call_addRule(instance: *runtime.Instance, selector: webidl.Opt(runtime.DOMString), style: webidl.Opt(runtime.DOMString), index: webidl.Opt(u32)) anyerror!i32 {
    _ = instance;
    _ = selector;
    _ = style;
    _ = index;
    return error.NotImplemented;
}

/// Operation: removeRule
pub fn call_removeRule(instance: *runtime.Instance, index: webidl.Opt(u32)) anyerror!void {
    _ = instance;
    _ = index;
    return error.NotImplemented;
}
