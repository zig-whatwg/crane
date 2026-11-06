//! /performance/'s social card (og:image, twitter:image): 1200x630, this
//! round's headline - Crane's time and memory as a percentage of each
//! browser's - composited onto card/base.png from the WPT site's own digit
//! atlas (tools/wpt_site/card.zig: the same glyphs, cuts and metrics, so the
//! two cards cannot drift apart). base.png is drawn once from
//! card/source.html with headless Chrome (card/README.md); the column and
//! row positions below are that page's constants: change them together.
//! Same numbers, same bytes.

const std = @import("std");
const Allocator = std.mem.Allocator;
const wpt_card = @import("site_card");
const png = wpt_card.png;

pub const width = 1200;
pub const height = 630;

pub const Figures = struct {
    round: u32 = 0,
    /// Chrome, Firefox, Safari, Lightpanda: Crane's percentage of each; null
    /// where there is no comparison.
    time: [4]?u64 = @splat(null),
    memory: [4]?u64 = @splat(null),
    /// The progress: Crane's time and memory in this round as a percentage of
    /// its first round's (report.zig `sinceFirst`); null in a first round,
    /// whose card then shows no progress line at all.
    since_time: ?u64 = null,
    since_memory: ?u64 = null,
};

const base_png = @embedFile("card/base.png");

/// The right edges the numbers end at, one per browser column (each
/// column's "%" is in base.png just right of it), and the rows' baselines.
pub const column_right = [4]f64{ 498, 688, 878, 1078 };
pub const time_baseline = 404;
pub const memory_baseline = 504;
/// The round number's pen and baseline, after base.png's "Round".
pub const round_x = 206;
pub const round_baseline = 178;
/// The progress line, on the round's baseline: "Since round 0:", then
/// "time" and "memory", each number right-aligned at its edge in the small
/// cut, with its "%" in base.png just right of it.
pub const since_time_right = 862;
pub const since_memory_right = 1078;
pub const since_baseline = round_baseline;
/// The progress line's whole box, blanked on a first round.
const since_box = [4]u32{ 455, 140, 1125, 190 };

/// The box base.png's "%" (serif 40px, at right + 4) sits in, from its
/// column's right edge and its row's baseline.
const percent_width = 44;
const percent_height = 36;
const percent_descent = 8;

/// Paint a box with the paper colour.
fn blank(img: *png.Image, x0: u32, y0: u32, x1: u32, y1: u32) void {
    var y = y0;
    while (y < @min(y1, img.height)) : (y += 1) {
        var x = x0;
        while (x < @min(x1, img.width)) : (x += 1) img.at(x, y).* = .{ 0xff, 0xff, 0xff };
    }
}

const ink = [3]u8{ 0x20, 0x21, 0x24 };
const ink_2 = [3]u8{ 0x5a, 0x5e, 0x63 };

pub fn render(gpa: Allocator, f: Figures) ![]u8 {
    var img = try png.decode(gpa, base_png);
    defer img.deinit(gpa);
    var atlas = try png.decode(gpa, wpt_card.atlas_png);
    defer atlas.deinit(gpa);

    var buf: [24]u8 = undefined;
    const round_text = std.fmt.bufPrint(&buf, "{d}", .{f.round}) catch unreachable;
    _ = wpt_card.draw(&img, &atlas, wpt_card.small, round_text, round_x, round_baseline, ink_2);

    for (column_right, 0..) |right, i| {
        inline for (.{ .{ f.time[i], time_baseline }, .{ f.memory[i], memory_baseline } }) |cell| {
            if (cell[0]) |n| {
                const text = std.fmt.bufPrint(&buf, "{d}", .{n}) catch unreachable;
                const x = right - wpt_card.measure(wpt_card.of, text);
                _ = wpt_card.draw(&img, &atlas, wpt_card.of, text, x, cell[1], ink);
            } else {
                // No figure: the cell is blank, its "%" too.
                blank(&img, @intFromFloat(right), cell[1] - percent_height, @intFromFloat(right + percent_width), cell[1] + percent_descent);
            }
        }
    }

    if (f.since_time == null and f.since_memory == null) {
        blank(&img, since_box[0], since_box[1], since_box[2], since_box[3]);
    } else {
        for ([_]struct { ?u64, f64 }{ .{ f.since_time, since_time_right }, .{ f.since_memory, since_memory_right } }) |cell| {
            if (cell[0]) |n| {
                const text = std.fmt.bufPrint(&buf, "{d}", .{n}) catch unreachable;
                const x = cell[1] - wpt_card.measure(wpt_card.small, text);
                _ = wpt_card.draw(&img, &atlas, wpt_card.small, text, x, since_baseline, ink);
            } else blank(&img, @intFromFloat(cell[1]), since_baseline - percent_height, @intFromFloat(cell[1] + percent_width), since_baseline + percent_descent);
        }
    }

    var out: std.Io.Writer.Allocating = .init(gpa);
    errdefer out.deinit();
    try png.encodeRgb(gpa, &out.writer, img.width, img.height, img.rgb);
    return out.toOwnedSlice();
}

const testing = std.testing;

/// Dark pixels (any channel under 128) in a box.
fn darkIn(img: png.Image, x0: u32, y0: u32, x1: u32, y1: u32) usize {
    var n: usize = 0;
    var y = y0;
    while (y < y1) : (y += 1) {
        var x = x0;
        while (x < x1) : (x += 1) {
            if (img.at(x, y)[0] < 128) n += 1;
        }
    }
    return n;
}

test "the card: 1200x630, a number where each figure is, none where there is none" {
    const bytes = try render(testing.allocator, .{ .round = 3, .time = .{ 54, 61, null, 112 }, .memory = .{ 23, 19, null, 88 } });
    defer testing.allocator.free(bytes);
    var img = try png.decode(testing.allocator, bytes);
    defer img.deinit(testing.allocator);
    try testing.expectEqual(@as(u32, width), img.width);
    try testing.expectEqual(@as(u32, height), img.height);

    const empty_bytes = try render(testing.allocator, .{});
    defer testing.allocator.free(empty_bytes);
    var empty = try png.decode(testing.allocator, empty_bytes);
    defer empty.deinit(testing.allocator);

    // Chrome's time cell has ink in the figures' card and less in the empty one.
    const cx0: u32 = @intFromFloat(column_right[0] - 120);
    const cx1: u32 = @intFromFloat(column_right[0]);
    try testing.expect(darkIn(img, cx0, time_baseline - 50, cx1, time_baseline + 5) > darkIn(empty, cx0, time_baseline - 50, cx1, time_baseline + 5) + 50);
    // Safari has no figure: its cell is blank, "%" and all.
    const sx0: u32 = @intFromFloat(column_right[2] - 120);
    const sx1: u32 = @intFromFloat(column_right[2] + percent_width);
    try testing.expectEqual(@as(usize, 0), darkIn(img, sx0, memory_baseline - 50, sx1, memory_baseline + 5));
    // A cell with a figure keeps its "%".
    const px0: u32 = @intFromFloat(column_right[0]);
    try testing.expect(darkIn(img, px0, time_baseline - percent_height, px0 + percent_width, time_baseline + percent_descent) > 20);
    // Same figures, same bytes.
    const again = try render(testing.allocator, .{ .round = 3, .time = .{ 54, 61, null, 112 }, .memory = .{ 23, 19, null, 88 } });
    defer testing.allocator.free(again);
    try testing.expectEqualSlices(u8, bytes, again);
}

test "the card names the progress since the first round, and a first round's card has no progress line" {
    const with = try render(testing.allocator, .{ .round = 1, .time = .{ 510, 440, 505, 470 }, .memory = .{ 40, 23, 84, 220 }, .since_time = 71, .since_memory = 63 });
    defer testing.allocator.free(with);
    var img = try png.decode(testing.allocator, with);
    defer img.deinit(testing.allocator);
    const first = try render(testing.allocator, .{ .round = 0, .time = .{ 510, 440, 505, 470 }, .memory = .{ 40, 23, 84, 220 } });
    defer testing.allocator.free(first);
    var none = try png.decode(testing.allocator, first);
    defer none.deinit(testing.allocator);
    // Each progress number lands left of its edge, on the round's baseline.
    for ([_]f64{ since_time_right, since_memory_right }) |right| {
        const x0: u32 = @intFromFloat(right - 50);
        const x1: u32 = @intFromFloat(right);
        try testing.expect(darkIn(img, x0, since_baseline - 34, x1, since_baseline + 2) > 30);
    }
    // A first round: the whole line is blank, labels and all.
    try testing.expectEqual(@as(usize, 0), darkIn(none, since_box[0], since_box[1], since_box[2], since_box[3]));
    // One figure missing: its number and "%" blank, the other drawn.
    const half = try render(testing.allocator, .{ .round = 1, .since_time = 71 });
    defer testing.allocator.free(half);
    var h = try png.decode(testing.allocator, half);
    defer h.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 0), darkIn(h, since_memory_right - 50, since_baseline - 34, since_memory_right + percent_width, since_baseline + 2));
    try testing.expect(darkIn(h, since_time_right - 50, since_baseline - 34, since_time_right, since_baseline + 2) > 30);
}
