//! The style engine (tmp/plans/style-design.md section 3.2): the sheets a
//! document applies, matched against its elements and cascaded into each
//! element's computed style, resolved lazily when something reads it. The
//! pure layer - values, properties, declaration blocks, media queries, the
//! cascade - is src/css.

/// The pure layer this engine drives.
pub const css = @import("css");
pub const hooks = @import("hooks.zig");
pub const sheet = @import("sheet.zig");
pub const rules = @import("rules.zig");
pub const objects = @import("objects.zig");
pub const cssom = @import("cssom.zig");
pub const adopted = @import("adopted.zig");
pub const element_style = @import("element_style.zig");
pub const environment_variables = @import("environment_variables.zig");
pub const ua_sheet = @import("ua_sheet.zig");
pub const engine = @import("engine.zig");
pub const inline_style = @import("inline_style.zig");
pub const typed_om = @import("typed_om.zig");
pub const content_visibility = @import("content_visibility.zig");
pub const font_hints = @import("font_hints.zig");

pub const StyleEngine = engine.StyleEngine;
pub const SheetRecord = sheet.SheetRecord;
pub const Rule = rules.Rule;
pub const MediaOf = sheet.MediaOf;
pub const RulesOf = sheet.RulesOf;
pub const ElementStyle = element_style.ElementStyle;
pub const computedStyle = engine.computedStyle;
pub const hasComputedStyle = engine.hasComputedStyle;
pub const isBeingRendered = engine.isBeingRendered;
pub const reportMediaQueryChanges = engine.reportMediaQueryChanges;
pub const scopeSheets = engine.scopeSheets;
pub const slotAssignmentChanged = engine.slotAssignmentChanged;
pub const inlineValue = inline_style.inlineValue;

/// What a computed CSSStyleDeclaration is of (getComputedStyle's construction
/// argument, CSSOM 7.2 steps 2-3): its element and pseudo-element.
pub const ComputedFor = struct {
    element: *@import("runtime").Instance,
    /// The pseudo-element's name, lowercase, without colons; null for the
    /// element itself. Borrowed for construction (copied).
    pseudo: ?[]const u8 = null,
    /// Step 3.2: the pseudo-element did not parse (or is ::slotted or
    /// ::part) - obj is null, and the declarations are empty.
    no_object: bool = false,
};

/// A sheet of `document` was made, removed or changed one of its flags.
pub fn sheetsChanged(document: *@import("runtime").Instance) void {
    if (hooks.engineOf(document)) |e| e.sheetsChanged();
}

/// A style sheet a load fetched (src/html/style_sheet_loading.zig): `bytes`
/// at `url`, for `owner` - a link element's own sheet when `path` is empty,
/// else the sheet of the @import rule `path` names (each index an @import
/// rule's among its sheet's, outermost first). The bytes are decoded as
/// UTF-8 with its BOM removed (stated: @charset and the environment
/// encoding of CSS Syntax "decode" are not read).
pub fn deliverSheet(owner: *@import("runtime").Instance, path: []const u16, bytes: []const u8, url: []const u8, origin_clean: bool) void {
    const allocator = owner.ctx.allocator;
    const text = css.rules.decodeUtf8(allocator, bytes) catch return;
    defer allocator.free(text);
    if (path.len == 0) return hooks.linkSheetArrived(owner, text, url, origin_clean);
    const root = hooks.sheetOf(owner) orelse return;
    const parent = root.importAt(path[0 .. path.len - 1]) orelse return;
    const child = SheetRecord.create(allocator, text, .{ .location = url, .base_url = url, .origin_clean = origin_clean, .mode = root.mode }) catch return;
    var url_context = parent.urlContext(owner);
    parent.attachImport(parent.parseOptions(&url_context), path[path.len - 1], child) catch return;
    const document = (@import("interfaces").Node.get_ownerDocument(owner) catch null) orelse return;
    sheetsChanged(document);
}

/// Metadata of the response just delivered above, before the lazy rule
/// parse. Keeping it on the actual child sheet avoids confusing an
/// @import's policy with its parent's, and survives removal of the owner.
pub fn setDeliveredSheetPolicy(owner: *@import("runtime").Instance, path: []const u16, policy: @import("fetch").internal.ReferrerPolicy) void {
    const root = hooks.sheetOf(owner) orelse return;
    const delivered = root.importAt(path) orelse return;
    delivered.referrer_policy = policy;
}

// No refAllDecls here: the dom module's own tests are not V8-linked, and
// the resolver's functions reach the engine. Each file's tests run as it
// is imported; tests/v8/style_engine_test.zig drives the resolver.

// Q73/Q95: discover the private helper's pure inline test without forcing
// resolver functions that reach the engine. Deliberately not refAllDecls.
test {
    _ = engine;
}
