//! The linux platform's fonts (decision 20): kit/sfnt for web fonts and for
//! reading installed font files, fontconfig for finding them.
//!
//! Web fonts are kit/sfnt's entirely, with no FreeType (the integrator's
//! ruling, Q2): the metric rules Blink and Gecko apply on Linux are their own
//! code over FreeType's raw table values (Skia's SkScalerContext_FreeType,
//! Gecko's gfxFT2FontBase::InitMetrics), the same rules kit/sfnt applies to
//! the same tables, and Crane renders nothing; FreeType would add only CFF
//! outline bounds for a missing x-height or cap-height (contract 10.2: ship
//! the smallest library).
//!
//! fontconfig is loaded at run time (contract 10: a library a headless
//! server may lack), with RTLD_NODELETE so its configuration, which it keeps
//! process-wide itself, outlives each call's dlclose. Without it there are
//! no installed faces - genericFontFace, installedFontFace and localFontFace
//! answer null - and the system font keywords take CSS Fonts 4 2.7's
//! initial values; web fonts are unaffected.
//!
//! - A generic family is fontconfig's alias of that name ("serif",
//!   "sans-serif", "monospace", "cursive", "fantasy", "system-ui", "emoji",
//!   "math", "fangsong") matched with the request's weight, slant, width and
//!   language (FcConfigSubstitute, FcDefaultSubstitute, FcFontMatch); the
//!   ui-* families have no fontconfig alias and no face.
//! - An installed family is FcFontMatch on that family, kept only when the
//!   match is that family (fontconfig substitutes another rather than fail;
//!   CSS Fonts 4 5.1 compares caselessly).
//! - A local() name is the face FcFontList finds by PostScript name, else by
//!   full name (fontconfig compares strings caselessly).
//! - The system font keywords are Blink's default provider over fontconfig
//!   (layout_theme_font_provider.cc: every keyword is the GUI font at the
//!   default size): the system-ui match, at no preferred size (medium).
//!   Gecko reads the GTK font setting instead, which needs GTK.
//!
//! Every face found is read from its file and described by kit/sfnt.
//! Request matching is fontconfig's, by style class: a request's oblique
//! angle is not matched.

const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform");
const sfnt = @import("kit_sfnt");
const posix = @import("kit_posix");

pub const decodeFont = sfnt.decodeFont;

// ---------------------------------------------------------------------------
// fontconfig, loaded at run time (fontconfig.h; every call is a function
// over opaque pointers, but for FcFontSet, a public struct)
// ---------------------------------------------------------------------------

const FcPattern = opaque {};
const FcObjectSet = opaque {};
const FcFontSet = extern struct { nfont: c_int, sfont: c_int, fonts: [*]*FcPattern };

const FcMatchPattern: c_int = 0;
const FcResultMatch: c_int = 0;
const FC_SLANT_ROMAN: c_int = 0;
const FC_SLANT_ITALIC: c_int = 100;
const FC_SLANT_OBLIQUE: c_int = 110;

/// The fontconfig calls Crane makes, looked up in one dlopen.
const Fc = struct {
    handle: *anyopaque,
    PatternCreate: *const fn () callconv(.c) ?*FcPattern,
    PatternDestroy: *const fn (*FcPattern) callconv(.c) void,
    PatternAddString: *const fn (*FcPattern, [*:0]const u8, [*:0]const u8) callconv(.c) c_int,
    PatternAddInteger: *const fn (*FcPattern, [*:0]const u8, c_int) callconv(.c) c_int,
    PatternAddDouble: *const fn (*FcPattern, [*:0]const u8, f64) callconv(.c) c_int,
    PatternGetString: *const fn (*const FcPattern, [*:0]const u8, c_int, *?[*:0]const u8) callconv(.c) c_int,
    PatternGetInteger: *const fn (*const FcPattern, [*:0]const u8, c_int, *c_int) callconv(.c) c_int,
    ConfigSubstitute: *const fn (?*anyopaque, *FcPattern, c_int) callconv(.c) c_int,
    DefaultSubstitute: *const fn (*FcPattern) callconv(.c) void,
    FontMatch: *const fn (?*anyopaque, *FcPattern, *c_int) callconv(.c) ?*FcPattern,
    FontList: *const fn (?*anyopaque, *FcPattern, *FcObjectSet) callconv(.c) ?*FcFontSet,
    FontSetDestroy: *const fn (*FcFontSet) callconv(.c) void,
    ObjectSetCreate: *const fn () callconv(.c) ?*FcObjectSet,
    ObjectSetAdd: *const fn (*FcObjectSet, [*:0]const u8) callconv(.c) c_int,
    ObjectSetDestroy: *const fn (*FcObjectSet) callconv(.c) void,

    /// fontconfig, or null when this machine has none.
    fn open() ?Fc {
        if (builtin.os.tag != .linux) return null;
        const handle = std.c.dlopen("libfontconfig.so.1", .{ .LAZY = true, .NODELETE = true }) orelse return null;
        var fc: Fc = undefined;
        fc.handle = handle;
        inline for (@typeInfo(Fc).@"struct".field_names) |field_name| {
            if (comptime std.mem.eql(u8, field_name, "handle")) continue;
            const symbol = std.c.dlsym(handle, "Fc" ++ field_name) orelse {
                _ = std.c.dlclose(handle);
                return null;
            };
            @field(fc, field_name) = @ptrCast(@alignCast(symbol));
        }
        return fc;
    }

    fn close(self: Fc) void {
        _ = std.c.dlclose(self.handle);
    }
};

/// CSS weight to fontconfig's scale (fontconfig.h FC_WEIGHT_*), between
/// the named points by the nearest.
fn fcWeight(css: u16) c_int {
    const points = [_]struct { u16, c_int }{
        .{ 100, 0 },   .{ 200, 40 },  .{ 300, 50 },  .{ 350, 55 },  .{ 380, 75 },  .{ 400, 80 },
        .{ 500, 100 }, .{ 600, 180 }, .{ 700, 200 }, .{ 800, 205 }, .{ 900, 210 }, .{ 1000, 215 },
    };
    var best = points[0][1];
    var best_distance: u16 = std.math.maxInt(u16);
    for (points) |p| {
        const d = if (p[0] > css) p[0] - css else css - p[0];
        if (d < best_distance) {
            best = p[1];
            best_distance = d;
        }
    }
    return best;
}

/// A NUL-terminated copy of `text`, OWNED.
fn z(allocator: std.mem.Allocator, text: []const u8) error{OutOfMemory}![:0]u8 {
    return allocator.dupeSentinel(u8, text, 0);
}

/// The best face fontconfig has for `family` and `request`, and whether it
/// is that family.
fn match(allocator: std.mem.Allocator, fc: Fc, family: []const u8, request: platform.FontRequest, exact_family: bool) platform.FontError!?platform.DecodedFont {
    const pattern = fc.PatternCreate() orelse return error.OutOfMemory;
    defer fc.PatternDestroy(pattern);
    const family_z = try z(allocator, family);
    defer allocator.free(family_z);
    if (fc.PatternAddString(pattern, "family", family_z) == 0) return error.OutOfMemory;
    _ = fc.PatternAddInteger(pattern, "weight", fcWeight(request.weight));
    _ = fc.PatternAddInteger(pattern, "slant", switch (request.style) {
        .normal => FC_SLANT_ROMAN,
        .italic => FC_SLANT_ITALIC,
        .oblique => FC_SLANT_OBLIQUE,
    });
    _ = fc.PatternAddInteger(pattern, "width", @intFromFloat(@round(request.stretch)));
    if (request.language.len > 0) {
        const lang = try z(allocator, request.language.slice());
        defer allocator.free(lang);
        _ = fc.PatternAddString(pattern, "lang", lang);
    }
    _ = fc.ConfigSubstitute(null, pattern, FcMatchPattern);
    fc.DefaultSubstitute(pattern);
    var result: c_int = 0;
    const found = fc.FontMatch(null, pattern, &result) orelse return null;
    defer fc.PatternDestroy(found);
    if (exact_family and !hasFamily(fc, found, family)) return null;
    return describeFound(allocator, fc, found);
}

fn hasFamily(fc: Fc, pattern: *const FcPattern, family: []const u8) bool {
    var n: c_int = 0;
    while (true) : (n += 1) {
        var value: ?[*:0]const u8 = null;
        if (fc.PatternGetString(pattern, "family", n, &value) != FcResultMatch) return false;
        if (sfnt.caseless.equal(std.mem.span(value.?), family)) return true;
    }
}

/// The face a pattern names, read from its file by kit/sfnt. A file kit/sfnt
/// cannot read is no face (the caller tries the next family either way).
fn describeFound(allocator: std.mem.Allocator, fc: Fc, pattern: *const FcPattern) platform.FontError!?platform.DecodedFont {
    var file: ?[*:0]const u8 = null;
    if (fc.PatternGetString(pattern, "file", 0, &file) != FcResultMatch) return null;
    var index: c_int = 0;
    _ = fc.PatternGetInteger(pattern, "index", 0, &index);
    // An index's high bits name a variable font's instance.
    const face: u32 = @as(u32, @bitCast(index)) & 0xffff;
    const bytes = posix.readFile(allocator, .from(std.mem.span(file.?)), 512 << 20) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => null,
    };
    defer allocator.free(bytes);
    return sfnt.describeFile(allocator, bytes, face) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => null,
    };
}

pub fn genericFontFace(allocator: std.mem.Allocator, generic: platform.GenericFontFamily, request: platform.FontRequest) platform.FontError!?platform.DecodedFont {
    const alias: []const u8 = switch (generic) {
        .serif => "serif",
        .sans_serif => "sans-serif",
        .monospace => "monospace",
        .cursive => "cursive",
        .fantasy => "fantasy",
        .system_ui => "system-ui",
        .emoji => "emoji",
        .math => "math",
        .fangsong => "fangsong",
        .ui_serif, .ui_sans_serif, .ui_monospace, .ui_rounded => return null,
    };
    const fc = Fc.open() orelse return null;
    defer fc.close();
    return match(allocator, fc, alias, request, false);
}

pub fn installedFontFace(allocator: std.mem.Allocator, family: platform.Str, request: platform.FontRequest) platform.FontError!?platform.DecodedFont {
    const fc = Fc.open() orelse return null;
    defer fc.close();
    return match(allocator, fc, family.slice(), request, true);
}

pub fn localFontFace(allocator: std.mem.Allocator, face_name: platform.Str) platform.FontError!?platform.DecodedFont {
    const fc = Fc.open() orelse return null;
    defer fc.close();
    const name = try z(allocator, face_name.slice());
    defer allocator.free(name);
    const objects = fc.ObjectSetCreate() orelse return error.OutOfMemory;
    defer fc.ObjectSetDestroy(objects);
    for ([_][*:0]const u8{ "file", "index" }) |object| {
        if (fc.ObjectSetAdd(objects, object) == 0) return error.OutOfMemory;
    }
    // CSS Fonts 4 4.3.3.1: the PostScript name, or the full name.
    for ([_][*:0]const u8{ "postscriptname", "fullname" }) |key| {
        const pattern = fc.PatternCreate() orelse return error.OutOfMemory;
        defer fc.PatternDestroy(pattern);
        if (fc.PatternAddString(pattern, key, name) == 0) return error.OutOfMemory;
        const set = fc.FontList(null, pattern, objects) orelse continue;
        defer fc.FontSetDestroy(set);
        if (set.nfont < 1) continue;
        if (try describeFound(allocator, fc, set.fonts[0])) |face| return face;
    }
    return null;
}

pub fn systemFont(allocator: std.mem.Allocator, keyword: platform.SystemFontKeyword, language: platform.Str) platform.FontError!platform.SystemFont {
    _ = keyword;
    var face = try genericFontFace(allocator, .system_ui, .{ .language = language }) orelse return .{
        // No fontconfig: CSS Fonts 4 2.7's initial values.
        .family = .{},
        .system_ui = false,
        .size = 0,
        .style = .normal,
        .weight = 400,
        .stretch = 100,
        .strings = .{},
    };
    defer face.deinit(allocator);
    const strings = try allocator.dupe(u8, face.family.slice());
    return .{
        .family = .from(strings),
        .system_ui = true,
        .size = 0,
        .style = .normal,
        .weight = 400,
        .stretch = 100,
        .strings = .from(strings),
    };
}
