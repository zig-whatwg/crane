//! The testing platform's fonts (decision 20): web fonts through kit/sfnt,
//! and a fixed set of installed faces, so no answer depends on the machine
//! the WPT runner happens to run on.
//!
//! The installed faces are four, each one regular face, described by these
//! numbers - no font file is in Crane. Times New Roman, Arial and Courier
//! New are the families every browser's Windows defaults name and that
//! Liberation Serif, Sans and Mono match metric for metric on Linux; their
//! numbers were read by kit/sfnt (and fontTools 4.62, which agrees) from
//! the copies macOS 27 ships in /System/Library/Fonts/Supplemental/
//! ("Times New Roman.ttf", "Arial.ttf", "Courier New.ttf"), 2026-10-22.
//! Ahem's are WPT's fonts/Ahem.ttf's (CSS Fonts' test font: every glyph a
//! 1em square, ascent 0.8em, descent 0.2em), so a test that names Ahem
//! without loading /fonts/ahem.css finds it installed, as wptrunner
//! installs it for the browsers.
//!
//! | Generic family | Face |
//! |---|---|
//! | serif | Times New Roman |
//! | sans-serif, system-ui, cursive, fantasy | Arial |
//! | monospace | Courier New |
//! | emoji, math, fangsong, ui-serif, ui-sans-serif, ui-monospace, ui-rounded | none |
//!
//! A request's weight, style, width and language choose nothing: each
//! family has its one regular face (a deviation from a real platform, which
//! has bold and italic faces). Every system font keyword is Arial, the
//! system-ui face, at no preferred size (medium), as Blink's default
//! provider answers on Linux and Windows (layout_theme_font_provider.cc:
//! every keyword is the GUI font at the default size).

const std = @import("std");
const platform = @import("platform");
const sfnt = @import("kit_sfnt");

pub const decodeFont = sfnt.decodeFont;

const Face = struct {
    family: []const u8,
    full_name: []const u8,
    postscript_name: []const u8,
    metrics: platform.FontMetrics,
};

fn units(value: f32) platform.FontUnits {
    return .of(value);
}

const absent: platform.FontUnits = .{};

/// Read from macOS 27's /System/Library/Fonts/Supplemental/Times New
/// Roman.ttf: hhea 1825/-443/87 (USE_TYPO_METRICS clear), OS/2 v2 sxHeight
/// 916, sCapHeight 1356, '0' advance 1024; no vertical metrics, no U+6C34.
const times_new_roman: Face = .{
    .family = "Times New Roman",
    .full_name = "Times New Roman",
    .postscript_name = "TimesNewRomanPSMT",
    .metrics = .{
        .units_per_em = 2048,
        .ascent = 1825,
        .descent = 443,
        .line_gap = 87,
        .x_height = units(916),
        .cap_height = units(1356),
        .zero_advance = units(1024),
        .zero_vertical_advance = absent,
        .ideographic_advance = absent,
        .ideographic_vertical_advance = absent,
    },
};

/// Arial.ttf: hhea 1854/-434/67, sxHeight 1062, sCapHeight 1467, '0' 1139.
const arial: Face = .{
    .family = "Arial",
    .full_name = "Arial",
    .postscript_name = "ArialMT",
    .metrics = .{
        .units_per_em = 2048,
        .ascent = 1854,
        .descent = 434,
        .line_gap = 67,
        .x_height = units(1062),
        .cap_height = units(1467),
        .zero_advance = units(1139),
        .zero_vertical_advance = absent,
        .ideographic_advance = absent,
        .ideographic_vertical_advance = absent,
    },
};

/// Courier New.ttf: hhea 1705/-615/0, sxHeight 866, sCapHeight 1170, '0'
/// 1229.
const courier_new: Face = .{
    .family = "Courier New",
    .full_name = "Courier New",
    .postscript_name = "CourierNewPSMT",
    .metrics = .{
        .units_per_em = 2048,
        .ascent = 1705,
        .descent = 615,
        .line_gap = 0,
        .x_height = units(866),
        .cap_height = units(1170),
        .zero_advance = units(1229),
        .zero_vertical_advance = absent,
        .ideographic_advance = absent,
        .ideographic_vertical_advance = absent,
    },
};

/// WPT's fonts/Ahem.ttf: hhea 800/-200/0, sxHeight and sCapHeight 800, '0'
/// and U+6C34 advances 1000; no vertical metrics.
const ahem: Face = .{
    .family = "Ahem",
    .full_name = "Ahem",
    .postscript_name = "Ahem",
    .metrics = .{
        .units_per_em = 1000,
        .ascent = 800,
        .descent = 200,
        .line_gap = 0,
        .x_height = units(800),
        .cap_height = units(800),
        .zero_advance = units(1000),
        .zero_vertical_advance = absent,
        .ideographic_advance = units(1000),
        .ideographic_vertical_advance = absent,
    },
};

const installed = [_]*const Face{ &times_new_roman, &arial, &courier_new, &ahem };

fn decoded(allocator: std.mem.Allocator, face: *const Face) error{OutOfMemory}!platform.DecodedFont {
    const style = "Regular";
    const strings = try std.mem.concat(allocator, u8, &.{ face.family, style, face.full_name, face.postscript_name });
    var at: usize = 0;
    var parts: [4]platform.Str = undefined;
    for ([_][]const u8{ face.family, style, face.full_name, face.postscript_name }, &parts) |text, *part| {
        part.* = .from(strings[at..][0..text.len]);
        at += text.len;
    }
    return .{
        .family = parts[0],
        .style_name = parts[1],
        .full_name = parts[2],
        .postscript_name = parts[3],
        .weight = 400,
        .style = .normal,
        .stretch = 100,
        .metrics = face.metrics,
        .strings = .from(strings),
    };
}

pub fn genericFontFace(allocator: std.mem.Allocator, generic: platform.GenericFontFamily, request: platform.FontRequest) platform.FontError!?platform.DecodedFont {
    _ = request;
    const face: *const Face = switch (generic) {
        .serif => &times_new_roman,
        .sans_serif, .system_ui, .cursive, .fantasy => &arial,
        .monospace => &courier_new,
        .emoji, .math, .fangsong, .ui_serif, .ui_sans_serif, .ui_monospace, .ui_rounded => return null,
    };
    return try decoded(allocator, face);
}

pub fn installedFontFace(allocator: std.mem.Allocator, family: platform.Str, request: platform.FontRequest) platform.FontError!?platform.DecodedFont {
    _ = request;
    for (installed) |face| {
        if (sfnt.caseless.equal(face.family, family.slice())) return try decoded(allocator, face);
    }
    return null;
}

pub fn localFontFace(allocator: std.mem.Allocator, face_name: platform.Str) platform.FontError!?platform.DecodedFont {
    for (installed) |face| {
        if (sfnt.caseless.equal(face.full_name, face_name.slice()) or sfnt.caseless.equal(face.postscript_name, face_name.slice()))
            return try decoded(allocator, face);
    }
    return null;
}

pub fn systemFont(allocator: std.mem.Allocator, keyword: platform.SystemFontKeyword, language: platform.Str) platform.FontError!platform.SystemFont {
    _ = .{ keyword, language };
    const strings = try allocator.dupe(u8, arial.family);
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
