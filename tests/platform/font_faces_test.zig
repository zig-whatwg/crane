//! The testing platform's installed faces (decision 20; src/platform/
//! adapters/testing/fonts.zig): generic families, installed families,
//! local() names and the system font keywords, from a fixed table so no
//! answer depends on the machine. Consumers (the cascade's first available
//! font, @font-face local(), the font shorthand's system keywords) call
//! these operations as written here.

const std = @import("std");
const platform = @import("platform");

const testing = std.testing;

fn generic(family: platform.GenericFontFamily) !?platform.DecodedFont {
    return platform.genericFontFace(testing.allocator, family, .{});
}

test "the generic families' faces, and the families with none" {
    var serif = (try generic(.serif)).?;
    defer serif.deinit(testing.allocator);
    try testing.expectEqualStrings("Times New Roman", serif.family.slice());
    try testing.expectEqualStrings("TimesNewRomanPSMT", serif.postscript_name.slice());
    try testing.expectEqual(@as(u16, 2048), serif.metrics.units_per_em);
    try testing.expectEqual(@as(?f32, 916.0 / 2048.0), serif.metrics.x_height.ratio(2048));

    inline for (.{ .sans_serif, .system_ui, .cursive, .fantasy }) |family| {
        var face = (try generic(family)).?;
        defer face.deinit(testing.allocator);
        try testing.expectEqualStrings("Arial", face.family.slice());
    }
    var mono = (try generic(.monospace)).?;
    defer mono.deinit(testing.allocator);
    try testing.expectEqualStrings("Courier New", mono.family.slice());
    try testing.expectEqual(@as(f32, 1229), mono.metrics.zero_advance.value);

    inline for (.{ .emoji, .math, .fangsong, .ui_serif, .ui_sans_serif, .ui_monospace, .ui_rounded }) |family| {
        try testing.expect(try generic(family) == null);
    }
}

test "an installed family matches caselessly; another is not installed" {
    var ahem = (try platform.installedFontFace(testing.allocator, .from("AHEM"), .{})).?;
    defer ahem.deinit(testing.allocator);
    try testing.expectEqualStrings("Ahem", ahem.family.slice());
    try testing.expectEqual(@as(f32, 800), ahem.metrics.ascent);
    try testing.expectEqual(@as(f32, 1000), ahem.metrics.ideographic_advance.value);
    try testing.expect(!ahem.metrics.ideographic_vertical_advance.present);

    var tnr = (try platform.installedFontFace(testing.allocator, .from("times new roman"), .{ .weight = 700 })).?;
    defer tnr.deinit(testing.allocator);
    try testing.expectEqualStrings("Times New Roman", tnr.family.slice());

    try testing.expect(try platform.installedFontFace(testing.allocator, .from("Helvetica"), .{}) == null);
    try testing.expect(try platform.installedFontFace(testing.allocator, .from("Arial "), .{}) == null);
}

test "local(): a full name or a PostScript name; nothing else" {
    var by_postscript = (try platform.localFontFace(testing.allocator, .from("ArialMT"))).?;
    defer by_postscript.deinit(testing.allocator);
    try testing.expectEqualStrings("Arial", by_postscript.family.slice());
    var by_full = (try platform.localFontFace(testing.allocator, .from("Courier New"))).?;
    defer by_full.deinit(testing.allocator);
    try testing.expectEqualStrings("CourierNewPSMT", by_full.postscript_name.slice());
    // css-font-loading/font-face-reject.html's name.
    try testing.expect(try platform.localFontFace(testing.allocator, .from("nonexistentfont-9a1a9f78-c8d4-11e9-af16-448a5b2c326f")) == null);
}

test "the system font keywords: the system-ui face at no preferred size" {
    inline for (.{ .caption, .icon, .menu, .message_box, .small_caption, .status_bar }) |keyword| {
        var font = try platform.systemFont(testing.allocator, keyword, .{});
        defer font.deinit(testing.allocator);
        try testing.expectEqualStrings("Arial", font.family.slice());
        try testing.expect(font.system_ui);
        try testing.expectEqual(@as(f32, 0), font.size);
        try testing.expectEqual(@as(u16, 400), font.weight);
        try testing.expectEqual(platform.FontStyle.normal, font.style);
        try testing.expectEqual(@as(f32, 100), font.stretch);
    }
}

// The fixed table's provenance: kit/sfnt reads the same numbers from the
// fonts they were taken from, where those fonts are (macOS's copies).
test "the fixed faces' metrics are kit/sfnt's reading of their fonts" {
    const sources = [_]struct { []const u8, platform.GenericFontFamily }{
        .{ "/System/Library/Fonts/Supplemental/Times New Roman.ttf", .serif },
        .{ "/System/Library/Fonts/Supplemental/Arial.ttf", .sans_serif },
        .{ "/System/Library/Fonts/Supplemental/Courier New.ttf", .monospace },
    };
    var checked: usize = 0;
    for (sources) |source| {
        const bytes = std.Io.Dir.cwd().readFileAlloc(testing.io, source[0], testing.allocator, .limited(16 << 20)) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        defer testing.allocator.free(bytes);
        var read = try platform.decodeFont(testing.allocator, .from(bytes), .{}, .{ .max_bytes = 16 << 20, .max_sfnt_bytes = 16 << 20 });
        defer read.deinit(testing.allocator);
        var fixed = (try generic(source[1])).?;
        defer fixed.deinit(testing.allocator);
        try testing.expectEqualStrings(read.family.slice(), fixed.family.slice());
        try testing.expectEqualStrings(read.full_name.slice(), fixed.full_name.slice());
        try testing.expectEqualStrings(read.postscript_name.slice(), fixed.postscript_name.slice());
        try testing.expectEqual(read.metrics, fixed.metrics);
        checked += 1;
    }
    if (checked == 0) return error.SkipZigTest;
}

test "Ahem's fixed metrics are kit/sfnt's reading of WPT's fonts/Ahem.ttf" {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(testing.io, "tests/wpt/fonts/Ahem.ttf", testing.allocator, .limited(1 << 20));
    defer testing.allocator.free(bytes);
    var read = try platform.decodeFont(testing.allocator, .from(bytes), .{}, .{ .max_bytes = 1 << 20, .max_sfnt_bytes = 1 << 20 });
    defer read.deinit(testing.allocator);
    var fixed = (try platform.installedFontFace(testing.allocator, .from("Ahem"), .{})).?;
    defer fixed.deinit(testing.allocator);
    try testing.expectEqual(read.metrics, fixed.metrics);
    try testing.expectEqualStrings(read.postscript_name.slice(), fixed.postscript_name.slice());
}

test "a request's oblique angle round-trips, and the testing faces match by style class alone" {
    var request: platform.FontRequest = .{ .style = .oblique, .oblique_angle = 20 };
    try testing.expectEqual(@as(f32, 20), request.oblique_angle);
    try testing.expectEqual(@as(f32, 0), (platform.FontRequest{}).oblique_angle);
    var twenty = (try platform.installedFontFace(testing.allocator, .from("Arial"), request)).?;
    defer twenty.deinit(testing.allocator);
    request.oblique_angle = 14;
    var fourteen = (try platform.installedFontFace(testing.allocator, .from("Arial"), request)).?;
    defer fourteen.deinit(testing.allocator);
    try testing.expectEqualStrings(fourteen.postscript_name.slice(), twenty.postscript_name.slice());
    try testing.expectEqual(fourteen.metrics, twenty.metrics);
    var font = try platform.systemFont(testing.allocator, .caption, .{});
    defer font.deinit(testing.allocator);
    try testing.expectEqual(@as(f32, 0), font.oblique_angle);
}
