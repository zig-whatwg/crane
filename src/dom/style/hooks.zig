//! What the style engine reaches through its owners: the Document's engine
//! and media environment, an Element's style state, and the style sheet a
//! style or link element owns. Each owner installs its part once, at process
//! start, from its installHooks (docs/instances.md); none of them is named
//! here (AGENTS.md "The impls boundary").
//!
//! lint-impls: hook for Document, Element, HTMLStyleElement, HTMLLinkElement, MediaQueryList, StyleSheet, CSSRule

const std = @import("std");
const runtime = @import("runtime");
const css = @import("css");
const process_start = @import("../process_start.zig");
const engine_mod = @import("engine.zig");
const element_style = @import("element_style.zig");
const sheet = @import("sheet.zig");

pub const Hooks = struct {
    /// Document: its engine (its state embeds it).
    engine_of: ?*const fn (document: *runtime.Instance) ?*engine_mod.StyleEngine = null,
    /// Document: the media environment its elements are styled in (the
    /// viewport its window reports, the platform's preferences, scripting).
    media_values: ?*const fn (document: *runtime.Instance) css.media_queries.MediaValues = null,
    /// Element: the slot its style state lives in (its state holds it).
    element_style_slot: ?*const fn (element: *runtime.Instance) ?*?*element_style.ElementStyle = null,
    /// A style element: the CSS style sheet associated with it, if any.
    style_sheet_of: ?*const fn (element: *runtime.Instance) ?*sheet.SheetRecord = null,
    /// A link element: likewise.
    link_sheet_of: ?*const fn (element: *runtime.Instance) ?*sheet.SheetRecord = null,
    /// A link element: its style sheet's resource arrived (HTML "process
    /// the linked resource" for the stylesheet link type), `text` decoded,
    /// at `url`: it creates its CSS style sheet.
    link_sheet_arrived: ?*const fn (element: *runtime.Instance, text: []const u8, url: []const u8, origin_clean: bool) void = null,
    /// MediaQueryList: CSSOM View 4.2's substep for one list - fire
    /// `change` at it if its matches state changed since the last report.
    report_media_query_list: ?*const fn (list: *runtime.Instance) void = null,
    /// StyleSheet: the CSS style sheet a StyleSheet object is over.
    sheet_record_of: ?*const fn (object: *runtime.Instance) ?*sheet.SheetRecord = null,
    /// CSSRule: the CSS rule a CSSRule object is over.
    css_rule_of: ?*const fn (object: *runtime.Instance) ?*sheet.Rule = null,
};

// process-wide: immutable function pointers that Document, Element, HTMLStyleElement and HTMLLinkElement install once at process start (crane.Process); each reads only the object it is given, so one serves every Browser and thread
var hooks: Hooks = .{};

/// Called by each owner's installHooks, once, at process start; each
/// installs only its own members.
pub fn install(owned: Hooks) void {
    process_start.assertInstalling();
    inline for (@typeInfo(Hooks).@"struct".fields) |field| {
        if (@field(owned, field.name)) |f| @field(hooks, field.name) = f;
    }
}

pub fn engineOf(document: *runtime.Instance) ?*engine_mod.StyleEngine {
    const f = hooks.engine_of orelse return null;
    return f(document);
}

pub fn mediaValues(document: *runtime.Instance) css.media_queries.MediaValues {
    const f = hooks.media_values orelse return .{};
    return f(document);
}

pub fn elementStyleSlot(element: *runtime.Instance) ?*?*element_style.ElementStyle {
    const f = hooks.element_style_slot orelse return null;
    return f(element);
}

/// The CSS style sheet `owner` - a style or a link element - is associated
/// with, if any.
pub fn sheetOf(owner: *runtime.Instance) ?*sheet.SheetRecord {
    if (hooks.style_sheet_of) |f| if (f(owner)) |record| return record;
    if (hooks.link_sheet_of) |f| if (f(owner)) |record| return record;
    return null;
}

pub fn linkSheetArrived(element: *runtime.Instance, text: []const u8, url: []const u8, origin_clean: bool) void {
    const f = hooks.link_sheet_arrived orelse return;
    f(element, text, url, origin_clean);
}

/// The CSS style sheet the StyleSheet object `object` is over; null for an
/// object that is not one.
pub fn sheetRecordOf(object: *runtime.Instance) ?*sheet.SheetRecord {
    const f = hooks.sheet_record_of orelse return null;
    return f(object);
}

/// The CSS rule the CSSRule object `object` is over.
pub fn cssRuleOf(object: *runtime.Instance) ?*sheet.Rule {
    const f = hooks.css_rule_of orelse return null;
    return f(object);
}

pub fn reportMediaQueryList(list: *runtime.Instance) void {
    const f = hooks.report_media_query_list orelse return;
    f(list);
}
