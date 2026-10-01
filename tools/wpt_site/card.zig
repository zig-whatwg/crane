//! The social card (og:image, twitter:image): a 1200x630 PNG that shows the
//! headline numbers, rendered by the generator.
//!
//! The card is card/base.png - the title, labels and rules, drawn once in the
//! site's faces - with the numbers composited onto it from card/atlas.png, a
//! sheet of Source Serif 4's tabular digits (plus comma, slash and space) in
//! three cuts, black on white, one glyph per cell. Both images were made once
//! with headless Chrome from card/source.html; card/README.md says how. The
//! cell geometry and advances below are that page's constants and its
//! measured metrics: change them together.
//!
//! Glyph coverage is the atlas's darkness (255 - red), blended over the base
//! in sRGB. Same numbers, same bytes: the PNG encoder writes no timestamps.

const std = @import("std");
const png = @import("png.zig");
const Allocator = std.mem.Allocator;

pub const width = 1200;
pub const height = 630;

pub const Figures = struct {
    pass: u64,
    reported: u64,
    failed: u64,
    timed_out: u64,
    notrun: u64,
    files: u64,
    blocking: u64,
};

const atlas_png = @embedFile("card/atlas.png");
const base_png = @embedFile("card/base.png");

const glyphs = "0123456789,/ ";

/// One cut of the atlas: a row of cells, and the advances measured in
/// Chrome (getComputedTextLength) for that font, size and weight.
const Cut = struct {
    row_y: u32,
    cell_w: u32,
    cell_h: u32,
    /// Where the glyph's origin sits inside its cell.
    ox: u32,
    baseline: u32,
    digit: f64,
    comma: f64,
    slash: f64,
    space: f64,

    fn advance(c: Cut, g: u8) f64 {
        return switch (g) {
            '0'...'9' => c.digit,
            ',' => c.comma,
            '/' => c.slash,
            else => c.space,
        };
    }
};

/// Source Serif 4, 600, 132px: the passing count.
const big: Cut = .{ .row_y = 0, .cell_w = 110, .cell_h = 170, .ox = 20, .baseline = 135, .digit = 64.40625, .comma = 34.234375, .slash = 42.328125, .space = 26.40625 };
/// Source Serif 4, 400, 60px: " / reported".
const of: Cut = .{ .row_y = 170, .cell_w = 60, .cell_h = 80, .ox = 10, .baseline = 62, .digit = 28.203125, .comma = 15.484375, .slash = 18.546875, .space = 12.25 };
/// Source Serif 4, 600, 40px: the five counts beneath.
const small: Cut = .{ .row_y = 250, .cell_w = 44, .cell_h = 56, .ox = 8, .baseline = 42, .digit = 20.15625, .comma = 11.1875, .slash = 13.546875, .space = 8.484375 };

/// Placements, matching card/source.html's labels.
const left = 80;
const headline_baseline = 332;
const counts_baseline = 510;
const column_step = 212;

const ink = [3]u8{ 0x20, 0x21, 0x24 };
const ink_2 = [3]u8{ 0x5a, 0x5e, 0x63 };
/// Red is failure; grey is blocking (the user, 2026-09-30).
const fail = [3]u8{ 0xb3, 0x26, 0x1e };
const block = [3]u8{ 0x6b, 0x70, 0x76 };

/// `n` with thousands separators into `buf`.
fn grouped(buf: []u8, n: u64) []const u8 {
    var digits: [32]u8 = undefined;
    const d = std.fmt.bufPrint(&digits, "{d}", .{n}) catch unreachable;
    var k: usize = 0;
    for (d, 0..) |c, i| {
        if (i > 0 and (d.len - i) % 3 == 0) {
            buf[k] = ',';
            k += 1;
        }
        buf[k] = c;
        k += 1;
    }
    return buf[0..k];
}

fn measure(cut: Cut, s: []const u8) f64 {
    var w: f64 = 0;
    for (s) |g| w += cut.advance(g);
    return w;
}

/// Draw `s` in `cut` from pen x `x` on baseline `y`; returns the pen after it.
fn draw(img: *png.Image, atlas: *const png.Image, cut: Cut, s: []const u8, x: f64, y: i32, color: [3]u8) f64 {
    var pen = x;
    for (s) |g| {
        const idx = std.mem.indexOfScalar(u8, glyphs, g) orelse continue;
        const gx: i32 = @as(i32, @intFromFloat(@round(pen))) - @as(i32, @intCast(cut.ox));
        const gy: i32 = y - @as(i32, @intCast(cut.baseline));
        for (0..cut.cell_h) |cy| for (0..cut.cell_w) |cx| {
            const ax: u32 = @intCast(idx * cut.cell_w + cx);
            const ay: u32 = @intCast(cut.row_y + cy);
            if (ax >= atlas.width or ay >= atlas.height) continue;
            const cov: u16 = 255 - @as(u16, atlas.at(ax, ay)[0]);
            if (cov == 0) continue;
            const dx = gx + @as(i32, @intCast(cx));
            const dy = gy + @as(i32, @intCast(cy));
            if (dx < 0 or dy < 0 or dx >= img.width or dy >= img.height) continue;
            const p = img.at(@intCast(dx), @intCast(dy));
            for (p, color) |*c, want| c.* = @intCast((@as(u16, c.*) * (255 - cov) + @as(u16, want) * cov + 127) / 255);
        };
        pen += cut.advance(g);
    }
    return pen;
}

/// The card for `f`, as PNG bytes owned by the caller.
pub fn render(gpa: Allocator, f: Figures) ![]u8 {
    var img = try png.decode(gpa, base_png);
    defer img.deinit(gpa);
    var atlas = try png.decode(gpa, atlas_png);
    defer atlas.deinit(gpa);

    var buf: [40]u8 = undefined;
    var pen = draw(&img, &atlas, big, grouped(&buf, f.pass), left, headline_baseline, ink);
    pen = draw(&img, &atlas, of, " / ", pen, headline_baseline, ink_2);
    _ = draw(&img, &atlas, of, grouped(&buf, f.reported), pen, headline_baseline, ink_2);

    const counts = [_]u64{ f.failed, f.timed_out, f.notrun, f.files, f.blocking };
    for (counts, 0..) |n, i| {
        const color = if (n == 0) ink else switch (i) {
            0 => fail,
            4 => block,
            else => ink,
        };
        _ = draw(&img, &atlas, small, grouped(&buf, n), @floatFromInt(left + i * column_step), counts_baseline, color);
    }

    var out: std.Io.Writer.Allocating = .init(gpa);
    errdefer out.deinit();
    try png.encodeRgb(gpa, &out.writer, img.width, img.height, img.rgb);
    return out.toOwnedSlice();
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

const sample: Figures = .{ .pass = 1287946, .reported = 1334731, .failed = 44465, .timed_out = 1234, .notrun = 1086, .files = 4712, .blocking = 1368 };

fn darkIn(img: png.Image, x0: u32, y0: u32, x1: u32, y1: u32) usize {
    var n: usize = 0;
    for (y0..y1) |y| for (x0..x1) |x| {
        const p = img.at(@intCast(x), @intCast(y));
        if (@as(u16, p[0]) + p[1] + p[2] < 3 * 160) n += 1;
    };
    return n;
}

test "card: the committed base and atlas decode, and every glyph cell has ink" {
    const gpa = testing.allocator;
    var base = try png.decode(gpa, base_png);
    defer base.deinit(gpa);
    try testing.expectEqual(@as(u32, width), base.width);
    try testing.expectEqual(@as(u32, height), base.height);
    var atlas = try png.decode(gpa, atlas_png);
    defer atlas.deinit(gpa);
    const used = [_]struct { Cut, []const u8 }{ .{ big, "0123456789," }, .{ of, "0123456789,/ " }, .{ small, "0123456789," } };
    for (used) |u| {
        const cut = u[0];
        for (u[1]) |g| {
            const i = std.mem.indexOfScalar(u8, glyphs, g).?;
            const x0: u32 = @intCast(i * cut.cell_w);
            try testing.expect(x0 + cut.cell_w <= atlas.width and cut.row_y + cut.cell_h <= atlas.height);
            const n = darkIn(atlas, x0, cut.row_y, x0 + cut.cell_w, cut.row_y + cut.cell_h);
            if (g == ' ') try testing.expectEqual(@as(usize, 0), n) else try testing.expect(n > 0);
        }
    }
    // The base carries no numbers: the headline's place is blank paper.
    try testing.expectEqual(@as(usize, 0), darkIn(base, left, headline_baseline - 95, 1120, headline_baseline + 20));
}

test "card: the numbers are drawn where the labels expect them, and the rest stays put" {
    const gpa = testing.allocator;
    const bytes = try render(gpa, sample);
    defer gpa.free(bytes);
    var img = try png.decode(gpa, bytes);
    defer img.deinit(gpa);
    try testing.expectEqual(@as(u32, width), img.width);
    try testing.expectEqual(@as(u32, height), img.height);
    // The passing count, large, from the left margin.
    try testing.expect(darkIn(img, left, headline_baseline - 95, left + 400, headline_baseline) > 3000);
    // Each of the five counts under its label.
    for (0..5) |i| {
        const x: u32 = @intCast(left + i * column_step);
        try testing.expect(darkIn(img, x, counts_baseline - 30, x + 80, counts_baseline) > 60);
    }
    // Failed subtests, when there are any, in red; blocking files in grey, never red.
    const Tint = struct {
        fn red(im: png.Image, x0: u32) bool {
            for (counts_baseline - 30..counts_baseline) |y| for (x0..x0 + 80) |x| {
                const p = im.at(@intCast(x), @intCast(y));
                if (p[0] > 150 and p[1] < 80 and p[2] < 80) return true;
            };
            return false;
        }
    };
    try testing.expect(Tint.red(img, left));
    try testing.expect(!Tint.red(img, left + 4 * column_step));
    // The title is the base's, untouched.
    var base = try png.decode(gpa, base_png);
    defer base.deinit(gpa);
    for (60..130) |y| for (60..800) |x| {
        try testing.expectEqualSlices(u8, base.at(@intCast(x), @intCast(y)), img.at(@intCast(x), @intCast(y)));
    };
}

test "card: same numbers, same bytes; different numbers, a different card" {
    const gpa = testing.allocator;
    const a = try render(gpa, sample);
    defer gpa.free(a);
    const b = try render(gpa, sample);
    defer gpa.free(b);
    try testing.expectEqualSlices(u8, a, b);
    var other = sample;
    other.pass += 1;
    const c = try render(gpa, other);
    defer gpa.free(c);
    try testing.expect(!std.mem.eql(u8, a, c));
    // Small enough for every crawler (5 MB is the tightest limit).
    try testing.expect(a.len < 400 * 1024);
}

test "card: the headline line fits the card up to a hundred million subtests" {
    var buf: [40]u8 = undefined;
    const w = measure(big, grouped(&buf, 99_999_999)) + measure(of, " / ") + measure(of, grouped(&buf, 99_999_999));
    try testing.expect(left + w <= width - left);
    try testing.expectEqualStrings("1,287,946", grouped(&buf, 1287946));
    try testing.expectEqualStrings("0", grouped(&buf, 0));
}
