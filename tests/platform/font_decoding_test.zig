//! Font decoding through the platform protocol (decision 20;
//! docs/platform-protocol.md 6.10.5): `platform.decodeFont` validates one web
//! font resource as the browsers' sanitizers do and describes its face,
//! behind the `font_decoding` capability. The testing platform decodes with
//! kit/sfnt, in Zig, so these run against it.
//!
//! Expected values come from fontTools 4.62 (the name table's US English
//! records, OS/2, hhea, cmap, hmtx and vmtx, and each glyph's recalculated
//! bounds), read from the same files, not from kit/sfnt. The fonts are WPT's
//! own, read in place: fonts/Ahem.ttf, fonts/CanvasTest.ttf,
//! fonts/adobe-fonts/CSSHWOrientationTest.otf and
//! css/css-fonts/variations/resources/ahem.ttc.

const std = @import("std");
const platform = @import("platform");

const testing = std.testing;

const limits: platform.FontLimits = .{ .max_bytes = 128 << 20, .max_sfnt_bytes = 128 << 20 };

fn readWpt(comptime path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(testing.io, "tests/wpt/" ++ path, testing.allocator, .limited(16 << 20));
}

fn decode(bytes: []const u8, name: []const u8) platform.FontError!platform.DecodedFont {
    return platform.decodeFont(testing.allocator, .from(bytes), .from(name), limits);
}

fn expectUnits(expected: ?f32, actual: platform.FontUnits) !void {
    if (expected) |value| {
        try testing.expect(actual.present);
        try testing.expectEqual(value, actual.value);
    } else {
        try testing.expect(!actual.present);
    }
}

test "font_decoding is native on the testing platform" {
    try testing.expectEqual(platform.Support.native, platform.capabilities.font_decoding);
}

test "Ahem.ttf: its names, style and every metric" {
    const bytes = try readWpt("fonts/Ahem.ttf");
    defer testing.allocator.free(bytes);
    var face = try decode(bytes, "");
    defer face.deinit(testing.allocator);

    try testing.expectEqualStrings("Ahem", face.family.slice());
    try testing.expectEqualStrings("Regular", face.style_name.slice());
    try testing.expectEqualStrings("Ahem", face.full_name.slice());
    try testing.expectEqualStrings("Ahem", face.postscript_name.slice());
    try testing.expectEqual(@as(u16, 400), face.weight);
    try testing.expectEqual(platform.FontStyle.normal, face.style);
    try testing.expectEqual(@as(f32, 100), face.stretch);
    try testing.expect(!face.matched_name);

    const m = face.metrics;
    try testing.expectEqual(@as(u16, 1000), m.units_per_em);
    try testing.expectEqual(@as(f32, 800), m.ascent);
    try testing.expectEqual(@as(f32, 200), m.descent);
    try testing.expectEqual(@as(f32, 0), m.line_gap);
    try expectUnits(800, m.x_height);
    try expectUnits(800, m.cap_height);
    try expectUnits(1000, m.zero_advance);
    try expectUnits(1000, m.ideographic_advance);
    // Ahem has no vhea/vmtx: the vertical advances are absent, so CSS uses
    // its 1em fallback - never a synthesized value.
    try expectUnits(null, m.zero_vertical_advance);
    try expectUnits(null, m.ideographic_vertical_advance);
    try testing.expectEqual(@as(?f32, 0.8), m.x_height.ratio(m.units_per_em));
}

test "CanvasTest.ttf: USE_TYPO_METRICS chooses the OS/2 typo metrics; no '0' glyph" {
    const bytes = try readWpt("fonts/CanvasTest.ttf");
    defer testing.allocator.free(bytes);
    var face = try decode(bytes, "");
    defer face.deinit(testing.allocator);

    try testing.expectEqualStrings("CanvasTest", face.family.slice());
    try testing.expectEqualStrings("Medium", face.style_name.slice());
    try testing.expectEqual(@as(u16, 500), face.weight);
    const m = face.metrics;
    try testing.expectEqual(@as(u16, 1024), m.units_per_em);
    try testing.expectEqual(@as(f32, 768), m.ascent);
    try testing.expectEqual(@as(f32, 256), m.descent);
    try testing.expectEqual(@as(f32, 92), m.line_gap);
    try expectUnits(512, m.x_height);
    try expectUnits(768, m.cap_height);
    try expectUnits(null, m.zero_advance);
    try expectUnits(null, m.ideographic_advance);
}

test "CSSHWOrientationTest.otf: a CFF font with vertical metrics" {
    const bytes = try readWpt("fonts/adobe-fonts/CSSHWOrientationTest.otf");
    defer testing.allocator.free(bytes);
    var face = try decode(bytes, "");
    defer face.deinit(testing.allocator);

    try testing.expectEqualStrings("CSS Half-Width Orientation Test", face.family.slice());
    try testing.expectEqualStrings("CSSHWOrientationTest", face.postscript_name.slice());
    const m = face.metrics;
    try testing.expectEqual(@as(u16, 1000), m.units_per_em);
    try testing.expectEqual(@as(f32, 880), m.ascent);
    try testing.expectEqual(@as(f32, 120), m.descent);
    try expectUnits(500, m.zero_advance);
    try expectUnits(1000, m.zero_vertical_advance);
    try expectUnits(500, m.ideographic_advance);
    try expectUnits(1000, m.ideographic_vertical_advance);
    // No OS/2 x/cap height, and CFF outlines are not measured: absent, so
    // CSS falls back (0.5em, the ascent).
    try expectUnits(null, m.x_height);
    try expectUnits(null, m.cap_height);
}

test "a collection: the first face, the face its PostScript name selects, and face 0 when none matches" {
    const bytes = try readWpt("css/css-fonts/variations/resources/ahem.ttc");
    defer testing.allocator.free(bytes);

    var first = try decode(bytes, "");
    defer first.deinit(testing.allocator);
    try testing.expectEqualStrings("Ahem", first.postscript_name.slice());
    try testing.expect(!first.matched_name);

    var second = try decode(bytes, "AhemNBSP");
    defer second.deinit(testing.allocator);
    try testing.expectEqualStrings("AhemNBSP", second.family.slice());
    try testing.expect(second.matched_name);

    // CSS Fonts 4 4.3.2 matches exactly: case matters.
    var unmatched = try decode(bytes, "ahemnbsp");
    defer unmatched.deinit(testing.allocator);
    try testing.expectEqualStrings("Ahem", unmatched.postscript_name.slice());
    try testing.expect(!unmatched.matched_name);
}

test "a single font: its own name matches, another falls back to it" {
    const bytes = try readWpt("fonts/Ahem.ttf");
    defer testing.allocator.free(bytes);
    var named = try decode(bytes, "Ahem");
    defer named.deinit(testing.allocator);
    try testing.expect(named.matched_name);
    var other = try decode(bytes, "Other");
    defer other.deinit(testing.allocator);
    try testing.expect(!other.matched_name);
    try testing.expectEqualStrings("Ahem", other.family.slice());
}

test "not a font format: UnsupportedFormat" {
    // css-font-loading/fontface-invalid-arraybuffer.html: eight zero bytes.
    try testing.expectError(error.UnsupportedFormat, decode(&[_]u8{0} ** 8, ""));
    try testing.expectError(error.UnsupportedFormat, decode("", ""));
    try testing.expectError(error.UnsupportedFormat, decode("<svg xmlns=\"http://www.w3.org/2000/svg\"/>", ""));
    // An EOT header (its magic 0x504C at offset 34) is not an sfnt.
    var eot = [_]u8{0} ** 64;
    eot[34] = 0x4C;
    eot[35] = 0x50;
    try testing.expectError(error.UnsupportedFormat, decode(&eot, ""));
}

test "data that ends early is Corrupt: a font is used whole or not at all" {
    const bytes = try readWpt("fonts/Ahem.ttf");
    defer testing.allocator.free(bytes);
    try testing.expectError(error.Corrupt, decode(bytes[0..4], ""));
    try testing.expectError(error.Corrupt, decode(bytes[0..12], ""));
    try testing.expectError(error.Corrupt, decode(bytes[0 .. bytes.len / 2], ""));
}

test "the resource limit: TooLarge before anything is parsed" {
    const bytes = try readWpt("fonts/Ahem.ttf");
    defer testing.allocator.free(bytes);
    const small: platform.FontLimits = .{ .max_bytes = bytes.len - 1, .max_sfnt_bytes = 128 << 20 };
    try testing.expectError(error.TooLarge, platform.decodeFont(testing.allocator, .from(bytes), .{}, small));
    // Exactly the limit is allowed.
    const exact: platform.FontLimits = .{ .max_bytes = bytes.len, .max_sfnt_bytes = 128 << 20 };
    var face = try platform.decodeFont(testing.allocator, .from(bytes), .{}, exact);
    face.deinit(testing.allocator);
}

test "decodeFont fails cleanly at every allocation" {
    const bytes = try readWpt("fonts/Ahem.ttf");
    defer testing.allocator.free(bytes);
    try testing.checkAllAllocationFailures(testing.allocator, struct {
        fn run(allocator: std.mem.Allocator, data: []const u8) !void {
            var face = try platform.decodeFont(allocator, .from(data), .{}, limits);
            face.deinit(allocator);
        }
    }.run, .{bytes});
}
