//! What the style engine reaches through its owners: the Document's engine
//! and media environment, an Element's style state, and the style sheet a
//! style or link element owns. Each owner installs its part once, at process
//! start, from its installHooks (docs/instances.md); none of them is named
//! here (AGENTS.md "The impls boundary").
//!
//! lint-impls: hook for Document, ShadowRoot, Element, HTMLStyleElement, HTMLLinkElement, ProcessingInstruction, MediaQueryList, StyleSheet, CSSRule
//! lint-impls: hook for FontFace, FontFaceSet, HTMLInputElement, HTMLTextAreaElement
//! lint-impls: hook for CSSStyleValue, StylePropertyMapReadOnly

const std = @import("std");
const runtime = @import("runtime");
const css = @import("css");
const process_start = @import("../process_start.zig");
const engine_mod = @import("engine.zig");
const element_style = @import("element_style.zig");
const sheet = @import("sheet.zig");
const adopted = @import("adopted.zig");

pub const Hooks = struct {
    /// Document: its engine (its state embeds it).
    engine_of: ?*const fn (document: *runtime.Instance) ?*engine_mod.StyleEngine = null,
    /// Document: the media environment its elements are styled in (the
    /// viewport its window reports, the platform's preferences, scripting).
    media_values: ?*const fn (document: *runtime.Instance) css.media_queries.MediaValues = null,
    /// CSS Environment Variables 1: the revision of the document's
    /// environment variables, which moves whenever one changes (Codex row
    /// 121's environment_variables.revision). Unset: 0, which never
    /// invalidates.
    environment_revision: ?*const fn (document: *runtime.Instance) u64 = null,
    /// HTML's document-to-platform environment value and revision lookup.
    environment_provider: ?@import("environment_variables.zig").Hooks = null,
    /// Element: the slot its style state lives in (its state holds it).
    element_style_slot: ?*const fn (element: *runtime.Instance) ?*?*element_style.ElementStyle = null,
    /// Control owners remember their first style state without a lookup on
    /// each later value write. Each callback rejects other receiver types.
    input_style_state_created: ?*const fn (element: *runtime.Instance) void = null,
    textarea_style_state_created: ?*const fn (element: *runtime.Instance) void = null,
    /// A style element: the CSS style sheet associated with it, if any.
    style_sheet_of: ?*const fn (element: *runtime.Instance) ?*sheet.SheetRecord = null,
    /// A link element: likewise.
    link_sheet_of: ?*const fn (element: *runtime.Instance) ?*sheet.SheetRecord = null,
    /// A link element: its style sheet's resource arrived (HTML "process
    /// the linked resource" for the stylesheet link type), `text` decoded,
    /// at `url`: it creates its CSS style sheet.
    link_sheet_arrived: ?*const fn (element: *runtime.Instance, text: []const u8, url: []const u8, origin_clean: bool) void = null,
    /// CSSOM 6.3.4: an xml-stylesheet processing instruction's sheet.
    pi_sheet_of: ?*const fn (owner: *runtime.Instance) ?*sheet.SheetRecord = null,
    pi_sheet_arrived: ?*const fn (owner: *runtime.Instance, text: []const u8, url: []const u8, origin_clean: bool) void = null,
    /// MediaQueryList: CSSOM View 4.2's substep for one list - fire
    /// `change` at it if its matches state changed since the last report.
    report_media_query_list: ?*const fn (list: *runtime.Instance) void = null,
    /// StyleSheet: the CSS style sheet a StyleSheet object is over.
    sheet_record_of: ?*const fn (object: *runtime.Instance) ?*sheet.SheetRecord = null,
    /// CSSRule: the CSS rule a CSSRule object is over.
    css_rule_of: ?*const fn (object: *runtime.Instance) ?*sheet.Rule = null,
    /// CSSStyleValue owns its immutable native reification and property identity.
    style_value_of: ?*const fn (object: *runtime.Instance) ?*@import("typed_om.zig").NativeValue = null,
    /// StylePropertyMapReadOnly owns the live source shared with its subclass.
    property_map_of: ?*const fn (object: *runtime.Instance) ?*@import("typed_om.zig").PropertyMap = null,
    /// Document, ShadowRoot: the view of its adoptedStyleSheets each keeps.
    document_adopted_sheets: ?*const fn (scope: *runtime.Instance) ?*adopted.AdoptedSheets = null,
    shadow_root_adopted_sheets: ?*const fn (scope: *runtime.Instance) ?*adopted.AdoptedSheets = null,
    /// SVG resource owners react to href/crossorigin through one namespace hook.
    svg_image_resource_changed: ?*const fn (element: *runtime.Instance) void = null,
    svg_use_resource_changed: ?*const fn (element: *runtime.Instance) void = null,
    /// UA resource parsing, installed by SVGUseElement; not a script sink.
    svg_parse_resource_document: ?*const fn (document: *runtime.Instance, bytes: []const u8, content_type: []const u8) anyerror!bool = null,
    font_face_of: ?*const fn (face: *runtime.Instance) ?*@import("font_loading.zig").Face = null,
    font_set_of: ?*const fn (set: *runtime.Instance) ?*@import("font_loading.zig").Set = null,
};

// process-wide: immutable function pointers that Document, Element, HTMLStyleElement and HTMLLinkElement install once at process start (crane.Process); each reads only the object it is given, so one serves every Browser and thread
var hooks: Hooks = .{};

/// Called by each owner's installHooks, once, at process start; each
/// installs only its own members.
pub fn install(owned: Hooks) void {
    process_start.assertInstalling();
    inline for (@typeInfo(Hooks).@"struct".field_names) |field_name| {
        if (@field(owned, field_name)) |f| @field(hooks, field_name) = f;
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

/// The document's environment revision (0: no provider).
pub fn environmentRevision(document: *runtime.Instance) u64 {
    const f = hooks.environment_revision orelse return 0;
    return f(document);
}

pub fn environmentProvider() ?@import("environment_variables.zig").Hooks {
    return hooks.environment_provider;
}

pub fn elementStyleSlot(element: *runtime.Instance) ?*?*element_style.ElementStyle {
    const f = hooks.element_style_slot orelse return null;
    return f(element);
}

/// Called only after the first successful ElementStyle allocation.
pub fn controlStyleStateCreated(element: *runtime.Instance) void {
    if (hooks.input_style_state_created) |f| f(element);
    if (hooks.textarea_style_state_created) |f| f(element);
}

/// The CSS style sheet `owner` - a style or a link element - is associated
/// with, if any.
pub fn sheetOf(owner: *runtime.Instance) ?*sheet.SheetRecord {
    if (hooks.style_sheet_of) |f| if (f(owner)) |record| return record;
    if (hooks.link_sheet_of) |f| if (f(owner)) |record| return record;
    if (hooks.pi_sheet_of) |f| if (f(owner)) |record| return record;
    return null;
}

pub fn linkSheetArrived(element: *runtime.Instance, text: []const u8, url: []const u8, origin_clean: bool) void {
    if (hooks.link_sheet_arrived) |f| f(element, text, url, origin_clean);
    if (hooks.pi_sheet_arrived) |f| f(element, text, url, origin_clean);
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

/// The native CSS representation owned by this CSSStyleValue, if any.
pub fn styleValueOf(object: *runtime.Instance) ?*@import("typed_om.zig").NativeValue {
    const f = hooks.style_value_of orelse return null;
    return f(object);
}

/// The live source owned by this StylePropertyMapReadOnly.
pub fn propertyMapOf(object: *runtime.Instance) ?*@import("typed_om.zig").PropertyMap {
    const f = hooks.property_map_of orelse return null;
    return f(object);
}

/// The adopted style sheets of `scope`, a Document or a ShadowRoot.
pub fn adoptedSheetsOf(scope: *runtime.Instance) ?*adopted.AdoptedSheets {
    if (hooks.document_adopted_sheets) |f| if (f(scope)) |a| return a;
    if (hooks.shadow_root_adopted_sheets) |f| if (f(scope)) |a| return a;
    return null;
}

pub fn reportMediaQueryList(list: *runtime.Instance) void {
    const f = hooks.report_media_query_list orelse return;
    f(list);
}

pub fn svgImageResourceChanged(element: *runtime.Instance) void {
    const f = hooks.svg_image_resource_changed orelse return;
    f(element);
}

pub fn svgUseResourceChanged(element: *runtime.Instance) void {
    const f = hooks.svg_use_resource_changed orelse return;
    f(element);
}

pub fn svgParseResourceDocument(document: *runtime.Instance, bytes: []const u8, content_type: []const u8) !bool {
    const f = hooks.svg_parse_resource_document orelse return error.InvalidState;
    return try f(document, bytes, content_type);
}

pub fn fontFaceOf(face: *runtime.Instance) ?*@import("font_loading.zig").Face {
    const f = hooks.font_face_of orelse return null;
    return f(face);
}

pub fn fontSetOf(set: *runtime.Instance) ?*@import("font_loading.zig").Set {
    const f = hooks.font_set_of orelse return null;
    return f(set);
}
