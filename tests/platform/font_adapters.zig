//! The font operations on the darwin and linux platforms (decision 20),
//! bound per platform by build.zig beside protocol_conformance_test.zig (the
//! directory's own executable binds `testing`). darwin answers from
//! CoreText; linux from kit/sfnt and, where the machine has it, fontconfig -
//! on a machine without it (any darwin host) linux's installed faces are
//! none and its system fonts the initial values. Web fonts go through
//! kit/sfnt on both, so what loads is what loads on testing.

const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform");

const testing = std.testing;

const limits: platform.FontLimits = .{ .max_bytes = 128 << 20, .max_sfnt_bytes = 128 << 20 };

const is_darwin = std.mem.eql(u8, platform.name, "darwin");
const is_linux = std.mem.eql(u8, platform.name, "linux");

fn readWpt(comptime path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(testing.io, "tests/wpt/" ++ path, testing.allocator, .limited(16 << 20));
}

fn present(units: platform.FontUnits) ?f32 {
    return if (units.present) units.value else null;
}

test "font_decoding is native where the platform runs on its own OS" {
    const native_os = (is_darwin and builtin.os.tag.isDarwin()) or (is_linux and builtin.os.tag == .linux);
    if (!native_os and is_darwin) return error.SkipZigTest;
    try testing.expectEqual(platform.Support.native, platform.capabilities.font_decoding);
}

test "Ahem.ttf: the font's names, and its metrics" {
    if (comptime platform.capabilities.font_decoding == .unsupported) return error.SkipZigTest;
    const bytes = try readWpt("fonts/Ahem.ttf");
    defer testing.allocator.free(bytes);
    var face = try platform.decodeFont(testing.allocator, .from(bytes), .{}, limits);
    defer face.deinit(testing.allocator);
    try testing.expectEqualStrings("Ahem", face.family.slice());
    try testing.expectEqualStrings("Ahem", face.postscript_name.slice());
    const m = face.metrics;
    try testing.expectEqual(@as(u16, 1000), m.units_per_em);
    try testing.expectEqual(@as(f32, 800), m.ascent);
    try testing.expectEqual(@as(f32, 200), m.descent);
    try testing.expectEqual(@as(f32, 0), m.line_gap);
    try testing.expectEqual(@as(?f32, 800), present(m.x_height));
    try testing.expectEqual(@as(?f32, 800), present(m.cap_height));
    try testing.expectEqual(@as(?f32, 1000), present(m.zero_advance));
    try testing.expectEqual(@as(?f32, 1000), present(m.ideographic_advance));
    // No vhea: CoreText would synthesize a vertical advance; absent here.
    try testing.expectEqual(@as(?f32, null), present(m.zero_vertical_advance));
    try testing.expectEqual(@as(?f32, null), present(m.ideographic_vertical_advance));
}

test "a CFF font's vertical advances" {
    if (comptime platform.capabilities.font_decoding == .unsupported) return error.SkipZigTest;
    const bytes = try readWpt("fonts/adobe-fonts/CSSHWOrientationTest.otf");
    defer testing.allocator.free(bytes);
    var face = try platform.decodeFont(testing.allocator, .from(bytes), .{}, limits);
    defer face.deinit(testing.allocator);
    try testing.expectEqual(@as(?f32, 500), present(face.metrics.zero_advance));
    try testing.expectEqual(@as(?f32, 1000), present(face.metrics.zero_vertical_advance));
    try testing.expectEqual(@as(?f32, 1000), present(face.metrics.ideographic_vertical_advance));
}

test "what kit/sfnt rejects, every platform rejects" {
    if (comptime platform.capabilities.font_decoding == .unsupported) return error.SkipZigTest;
    const bytes = try readWpt("fonts/Ahem.ttf");
    defer testing.allocator.free(bytes);
    try testing.expectError(error.Corrupt, platform.decodeFont(testing.allocator, .from(bytes[0 .. bytes.len / 2]), .{}, limits));
    try testing.expectError(error.UnsupportedFormat, platform.decodeFont(testing.allocator, .from(&[_]u8{0} ** 8), .{}, limits));
}

test "darwin: the generic families are WebKit's defaults; system-ui is the UI font" {
    if (comptime !is_darwin or platform.capabilities.font_decoding == .unsupported) return error.SkipZigTest;
    const expected = [_]struct { platform.GenericFontFamily, []const u8 }{
        .{ .serif, "Times" }, .{ .sans_serif, "Helvetica" }, .{ .monospace, "Courier" },
    };
    for (expected) |e| {
        var face = (try platform.genericFontFace(testing.allocator, e[0], .{})).?;
        defer face.deinit(testing.allocator);
        try testing.expectEqualStrings(e[1], face.family.slice());
        try testing.expect(face.metrics.units_per_em > 0);
        try testing.expect(face.metrics.x_height.present);
        try testing.expect(face.metrics.zero_advance.present);
    }
    var ui = (try platform.genericFontFace(testing.allocator, .system_ui, .{})).?;
    defer ui.deinit(testing.allocator);
    try testing.expect(ui.family.len > 0);
    try testing.expect(try platform.genericFontFace(testing.allocator, .ui_rounded, .{}) == null);
}

test "darwin: an installed family's nearest face; a local() name" {
    if (comptime !is_darwin or platform.capabilities.font_decoding == .unsupported) return error.SkipZigTest;
    var bold = (try platform.installedFontFace(testing.allocator, .from("helvetica"), .{ .weight = 700 })).?;
    defer bold.deinit(testing.allocator);
    try testing.expectEqualStrings("Helvetica", bold.family.slice());
    try testing.expectEqual(@as(u16, 700), bold.weight);
    var regular = (try platform.installedFontFace(testing.allocator, .from("Helvetica"), .{})).?;
    defer regular.deinit(testing.allocator);
    try testing.expectEqual(@as(u16, 400), regular.weight);
    try testing.expectEqual(platform.FontStyle.normal, regular.style);
    try testing.expect(try platform.installedFontFace(testing.allocator, .from("No Such Family 9a1a9f78"), .{}) == null);

    var local = (try platform.localFontFace(testing.allocator, .from("Helvetica-Bold"))).?;
    defer local.deinit(testing.allocator);
    try testing.expectEqualStrings("Helvetica-Bold", local.postscript_name.slice());
    try testing.expect(try platform.localFontFace(testing.allocator, .from("nonexistentfont-9a1a9f78-c8d4-11e9-af16-448a5b2c326f")) == null);
}

test "darwin: the system font keywords at macOS's UI sizes" {
    if (comptime !is_darwin or builtin.os.tag != .macos or platform.capabilities.font_decoding == .unsupported) return error.SkipZigTest;
    // NSFont's systemFontSize, smallSystemFontSize and labelFontSize, as
    // WebKit's SystemFontDatabaseCoreText reads them.
    const sizes = [_]struct { platform.SystemFontKeyword, f32 }{
        .{ .caption, 13 }, .{ .icon, 13 }, .{ .message_box, 13 }, .{ .menu, 13 }, .{ .small_caption, 11 }, .{ .status_bar, 10 },
    };
    for (sizes) |s| {
        var font = try platform.systemFont(testing.allocator, s[0], .{});
        defer font.deinit(testing.allocator);
        try testing.expect(font.family.len > 0);
        try testing.expect(font.system_ui);
        try testing.expectEqual(s[1], font.size);
        try testing.expectEqual(@as(f32, 0), font.oblique_angle);
    }
}

test "linux without fontconfig: no installed faces, the initial system font values" {
    if (comptime !is_linux or builtin.os.tag == .linux or platform.capabilities.font_decoding == .unsupported) return error.SkipZigTest;
    try testing.expect(try platform.genericFontFace(testing.allocator, .serif, .{}) == null);
    try testing.expect(try platform.installedFontFace(testing.allocator, .from("DejaVu Sans"), .{}) == null);
    try testing.expect(try platform.localFontFace(testing.allocator, .from("DejaVuSans")) == null);
    var font = try platform.systemFont(testing.allocator, .menu, .{});
    defer font.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 0), font.family.len);
    try testing.expectEqual(@as(f32, 0), font.size);
    try testing.expectEqual(@as(u16, 400), font.weight);
}

test "linux with fontconfig: the generic families resolve to installed faces" {
    if (comptime !is_linux or builtin.os.tag != .linux or platform.capabilities.font_decoding == .unsupported) return error.SkipZigTest;
    var serif = (try platform.genericFontFace(testing.allocator, .serif, .{})) orelse return error.SkipZigTest;
    defer serif.deinit(testing.allocator);
    try testing.expect(serif.family.len > 0);
    try testing.expect(serif.metrics.units_per_em > 0);
    var mono = (try platform.genericFontFace(testing.allocator, .monospace, .{})).?;
    defer mono.deinit(testing.allocator);
    try testing.expect(mono.metrics.zero_advance.present);
    var named = (try platform.installedFontFace(testing.allocator, serif.family, .{})).?;
    defer named.deinit(testing.allocator);
    try testing.expectEqualStrings(serif.family.slice(), named.family.slice());
    var local = (try platform.localFontFace(testing.allocator, serif.postscript_name)).?;
    defer local.deinit(testing.allocator);
    try testing.expectEqualStrings(serif.postscript_name.slice(), local.postscript_name.slice());
    try testing.expect(try platform.installedFontFace(testing.allocator, .from("No Such Family 9a1a9f78"), .{}) == null);
    try testing.expect(try platform.genericFontFace(testing.allocator, .ui_rounded, .{}) == null);
    var font = try platform.systemFont(testing.allocator, .caption, .{});
    defer font.deinit(testing.allocator);
    try testing.expect(font.family.len > 0);
    try testing.expect(font.system_ui);
}

test "every font operation fails cleanly at every allocation" {
    if (comptime platform.capabilities.font_decoding == .unsupported) return error.SkipZigTest;
    try testing.checkAllAllocationFailures(testing.allocator, struct {
        fn run(allocator: std.mem.Allocator) !void {
            if (try platform.genericFontFace(allocator, .monospace, .{})) |face| {
                var f = face;
                f.deinit(allocator);
            }
            var font = try platform.systemFont(allocator, .caption, .{});
            font.deinit(allocator);
        }
    }.run, .{});
}
