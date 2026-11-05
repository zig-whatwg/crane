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
            }
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
    // Safari has no figure: its cells are as the base has them.
    const sx0: u32 = @intFromFloat(column_right[2] - 120);
    const sx1: u32 = @intFromFloat(column_right[2]);
    try testing.expectEqual(darkIn(empty, sx0, memory_baseline - 50, sx1, memory_baseline + 5), darkIn(img, sx0, memory_baseline - 50, sx1, memory_baseline + 5));
    // Same figures, same bytes.
    const again = try render(testing.allocator, .{ .round = 3, .time = .{ 54, 61, null, 112 }, .memory = .{ 23, 19, null, 88 } });
    defer testing.allocator.free(again);
    try testing.expectEqualSlices(u8, bytes, again);
}
