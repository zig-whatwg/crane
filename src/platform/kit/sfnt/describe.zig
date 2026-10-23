//! A checked face, described: its names, weight, style and width, and the
//! metrics CSS reads - by the rules the browsers apply to the sanitized font
//! on the platforms where they read the tables themselves (Skia's FreeType
//! backend under Blink, Gecko's gfxFT2FontBase::InitMetrics):
//!
//! - ascent, descent, line gap: OS/2's typo metrics when fsSelection's
//!   USE_TYPO_METRICS bit (7) is set; else hhea's, as FreeType reads them -
//!   and when hhea's ascender and descender are both 0, OS/2's typo metrics,
//!   or failing those its usWin metrics (with no line gap);
//! - x-height, cap-height: OS/2 (version 2 and later) sxHeight and
//!   sCapHeight when above 0; else the outline top of 'x' (U+0078) and 'H'
//!   (U+0048), measured from TrueType outlines only (a CFF outline is not
//!   measured here: absent); else absent;
//! - advances: the cmap's glyph for U+0030 and U+6C34, then hmtx, and vmtx
//!   when the face has vertical metrics - never synthesized.

const std = @import("std");
const platform = @import("platform");
const tables = @import("tables.zig");
const names = @import("names.zig");
const caseless = @import("caseless.zig");

pub const Error = error{ Corrupt, OutOfMemory };

/// CSS Fonts 4 2.3's font-width percentages for usWidthClass 1-9.
const width_percent = [9]f32{ 50, 62.5, 75, 87.5, 100, 112.5, 125, 150, 200 };

pub fn metrics(face: tables.Checked) Error!platform.FontMetrics {
    const os2 = face.os2;
    var m: platform.FontMetrics = .{
        .units_per_em = face.units_per_em,
        .ascent = 0,
        .descent = 0,
        .line_gap = 0,
        .x_height = .{},
        .cap_height = .{},
        .zero_advance = .{},
        .zero_vertical_advance = .{},
        .ideographic_advance = .{},
        .ideographic_vertical_advance = .{},
    };
    if (os2.selection & (1 << 7) != 0) {
        m.ascent = @floatFromInt(os2.typo_ascender);
        m.descent = @floatFromInt(-@as(i32, os2.typo_descender));
        m.line_gap = @floatFromInt(os2.typo_line_gap);
    } else if (face.hhea.ascent != 0 or face.hhea.descent != 0) {
        m.ascent = @floatFromInt(face.hhea.ascent);
        m.descent = @floatFromInt(-@as(i32, face.hhea.descent));
        m.line_gap = @floatFromInt(face.hhea.line_gap);
    } else if (os2.typo_ascender != 0 or os2.typo_descender != 0) {
        m.ascent = @floatFromInt(os2.typo_ascender);
        m.descent = @floatFromInt(-@as(i32, os2.typo_descender));
        m.line_gap = @floatFromInt(os2.typo_line_gap);
    } else {
        m.ascent = @floatFromInt(os2.win_ascent);
        m.descent = @floatFromInt(os2.win_descent);
    }

    if (os2.version >= 2 and os2.x_height > 0) {
        m.x_height = .of(@floatFromInt(os2.x_height));
    } else if (try top(face, 'x')) |y| {
        m.x_height = .of(@floatFromInt(y));
    }
    if (os2.version >= 2 and os2.cap_height > 0) {
        m.cap_height = .of(@floatFromInt(os2.cap_height));
    } else if (try top(face, 'H')) |y| {
        m.cap_height = .of(@floatFromInt(y));
    }
    if (tables.glyphFor(face, '0')) |glyph| {
        m.zero_advance = .of(@floatFromInt(tables.advance(face.hmtx, face.hhea.num_metrics, glyph)));
        if (face.vertical) |v| m.zero_vertical_advance = .of(@floatFromInt(tables.advance(v.vmtx, v.header.num_metrics, glyph)));
    }
    if (tables.glyphFor(face, 0x6C34)) |glyph| {
        m.ideographic_advance = .of(@floatFromInt(tables.advance(face.hmtx, face.hhea.num_metrics, glyph)));
        if (face.vertical) |v| m.ideographic_vertical_advance = .of(@floatFromInt(tables.advance(v.vmtx, v.header.num_metrics, glyph)));
    }
    return m;
}

fn top(face: tables.Checked, code_point: u21) Error!?i32 {
    if (face.outlines != .truetype) return null;
    const glyph = tables.glyphFor(face, code_point) orelse return null;
    return tables.outlineTop(face, glyph);
}

/// The face's names, weight, style and width with `face_metrics`, its
/// strings in one OWNED allocation.
pub fn describe(allocator: std.mem.Allocator, face: tables.Checked, face_metrics: platform.FontMetrics) Error!platform.DecodedFont {
    const family = names.find(face.name, names.id.typographic_family) orelse names.find(face.name, names.id.family);
    const style_name = names.find(face.name, names.id.typographic_subfamily) orelse names.find(face.name, names.id.subfamily);
    const full = names.find(face.name, names.id.full);
    const postscript = names.find(face.name, names.id.postscript);
    const all = [4]?names.Name{ family, style_name, full, postscript };
    var total: usize = 0;
    for (all) |maybe| {
        if (maybe) |n| total += n.utf8Len();
    }
    const strings = try allocator.alloc(u8, total);
    var written: [4]platform.Str = undefined;
    var at: usize = 0;
    for (all, &written) |maybe, *out| {
        const n = maybe orelse {
            out.* = .from(strings[at..at]);
            continue;
        };
        const text = n.writeUtf8(strings[at..]);
        out.* = .from(text);
        at += text.len;
    }
    const os2 = face.os2;
    return .{
        .family = written[0],
        .style_name = written[1],
        .full_name = written[2],
        .postscript_name = written[3],
        .weight = os2.weight_class,
        .style = if (os2.selection & 1 != 0) .italic else if (os2.selection & (1 << 9) != 0) .oblique else .normal,
        .stretch = width_percent[os2.width_class - 1],
        .metrics = face_metrics,
        .strings = .from(strings),
    };
}

/// The face's PostScript name equals `wanted` exactly (CSS Fonts 4 4.3.2).
pub fn hasPostScriptName(face: tables.Checked, wanted: []const u8) bool {
    const n = names.find(face.name, names.id.postscript) orelse return false;
    var buffer: [4 * 64]u8 = undefined;
    if (n.utf8Len() > buffer.len) return false;
    return std.mem.eql(u8, n.writeUtf8(&buffer), wanted);
}

/// The face's full name or PostScript name is `wanted` (CSS Fonts 4
/// 4.3.3.1's local() matching), compared caselessly as family names are
/// (5.1; caseless.zig): Gecko lowercases local names, Blink folds them.
pub fn hasLocalName(face: tables.Checked, wanted: []const u8) bool {
    for ([_]u16{ names.id.full, names.id.postscript }) |name_id| {
        const n = names.find(face.name, name_id) orelse continue;
        var buffer: [4 * 256]u8 = undefined;
        if (n.utf8Len() > buffer.len) continue;
        if (caseless.equal(n.writeUtf8(&buffer), wanted)) return true;
    }
    return false;
}

/// A face's weight, slope and width.
pub const Traits = struct {
    weight: u16 = 400,
    style: platform.FontStyle = .normal,
    /// Percent.
    stretch: f32 = 100,
};

/// The traits an OS/2 table gives, as OTS's sanitizer leaves them; null
/// when the table does not check.
pub fn traitsFromOs2(data: []const u8) ?Traits {
    const os2 = tables.checkOs2(data) catch return null;
    return .{
        .weight = os2.weight_class,
        .style = if (os2.selection & 1 != 0) .italic else if (os2.selection & (1 << 9) != 0) .oblique else .normal,
        .stretch = width_percent[os2.width_class - 1],
    };
}

/// A description from its parts (a platform that reads names and metrics
/// from its own font engine): the four names copied into one OWNED
/// allocation.
pub fn fromParts(allocator: std.mem.Allocator, family: []const u8, style_name: []const u8, full_name: []const u8, postscript_name: []const u8, traits: Traits, face_metrics: platform.FontMetrics) error{OutOfMemory}!platform.DecodedFont {
    const parts = [4][]const u8{ family, style_name, full_name, postscript_name };
    const strings = try std.mem.concat(allocator, u8, &parts);
    var at: usize = 0;
    var out: [4]platform.Str = undefined;
    for (parts, &out) |text, *str| {
        str.* = .from(strings[at..][0..text.len]);
        at += text.len;
    }
    return .{
        .family = out[0],
        .style_name = out[1],
        .full_name = out[2],
        .postscript_name = out[3],
        .weight = traits.weight,
        .style = traits.style,
        .stretch = traits.stretch,
        .metrics = face_metrics,
        .strings = .from(strings),
    };
}
