//! /frameworks/'s social card (og:image, twitter:image): 1200x630, the pass
//! rate of each framework's own tests and of TodoMVC's apps' tests in Crane
//! beside Chrome, and the frameworks Crane cannot run yet. The rates are
//! composited onto card/base.png from the WPT site's own digit atlas
//! (tools/wpt_site/card.zig: the same glyphs, cuts and metrics as the
//! progress and performance cards, so the three cannot drift apart).
//! base.png carries everything that is not a rate - the title, the row and
//! column labels, each rate's decimal point and "%", the waiting line - drawn
//! once from card/source.html with headless Chrome (card/README.md). Its rows
//! are `row_titles` and `waiting_titles`: a page whose rows differ refuses
//! to draw a card (error.CardOutOfDate) until base.png is remade. Same rates,
//! same bytes.

const std = @import("std");
const Allocator = std.mem.Allocator;
const wpt_card = @import("site_card");
const png = wpt_card.png;

pub const width = 1200;
pub const height = 630;

/// The rows base.png names, top to bottom (report.zig chartRows' order).
pub const row_titles = [_][]const u8{ "Angular", "htmx", "jQuery", "TodoMVC" };
/// The frameworks its waiting line names.
pub const waiting_titles = [_][]const u8{ "React", "Svelte", "Vue" };

pub const Row = struct {
    title: []const u8,
    /// Tenths of a percent (998 = 99.8%); null: no run.
    crane: ?u16,
    chrome: ?u16,
};

pub const Figures = struct {
    rows: []const Row,
    waiting: []const []const u8,
};

/// Passed over run in tenths of a percent, rounded; never 100.0% with a
/// failure, never 0.0% with a pass; null with nothing run.
pub fn tenths(pass: u32, ran: u32) ?u16 {
    if (ran == 0) return null;
    const t: u16 = @intCast((@as(u64, pass) * 1000 + ran / 2) / ran);
    if (pass < ran and t == 1000) return 999;
    if (pass > 0 and t == 0) return 1;
    return t;
}

const base_png = @embedFile("card/base.png");

/// The cut the rates are drawn in: Source Serif 4, 400, 60px.
const cut = wpt_card.of;
/// The advance of "." in that cut, measured in Chrome with the atlas's
/// (card/source.html ?part=metrics); base.png draws each decimal point at
/// `right - cut.digit - period`.
pub const period = 15.484375;
/// Where each column's tenths digit ends (its "%" is in base.png just right
/// of it), and the rows' baselines (card/source.html COLUMN_RIGHT,
/// ROW_BASELINE).
pub const column_right = [2]f64{ 780, 1040 };
pub const row_baseline = [4]i32{ 296, 358, 420, 482 };
/// The box a blanked rate fills, from its column's right edge and its row's
/// baseline: its integer part, its point and its "%".
const blank_left = 112;
const blank_right = 44;
const blank_up = 50;
const blank_down = 10;

const ink = [3]u8{ 0x20, 0x21, 0x24 };
const ink_2 = [3]u8{ 0x5a, 0x5e, 0x63 };

/// Paint a box with the paper colour.
fn blank(img: *png.Image, x0: u32, y0: u32, x1: u32, y1: u32) void {
    var y = y0;
    while (y < @min(y1, img.height)) : (y += 1) {
        var x = x0;
        while (x < @min(x1, img.width)) : (x += 1) img.at(x, y).* = .{ 0xff, 0xff, 0xff };
    }
}

fn sameTitles(got: []const []const u8, want: []const []const u8) bool {
    if (got.len != want.len) return false;
    for (got, want) |a, b| if (!std.mem.eql(u8, a, b)) return false;
    return true;
}

/// The card for `f`, as PNG bytes owned by the caller.
pub fn render(gpa: Allocator, f: Figures) ![]u8 {
    var titles: [row_titles.len][]const u8 = undefined;
    if (f.rows.len != row_titles.len) return error.CardOutOfDate;
    for (f.rows, 0..) |r, i| titles[i] = r.title;
    if (!sameTitles(&titles, &row_titles) or !sameTitles(f.waiting, &waiting_titles)) return error.CardOutOfDate;

    var img = try png.decode(gpa, base_png);
    defer img.deinit(gpa);
    var atlas = try png.decode(gpa, wpt_card.atlas_png);
    defer atlas.deinit(gpa);

    var buf: [8]u8 = undefined;
    for (f.rows, row_baseline) |r, y| {
        for ([_]?u16{ r.crane, r.chrome }, column_right, 0..) |value, right, col| {
            const color = if (col == 0) ink else ink_2;
            if (value) |t| {
                const whole = std.fmt.bufPrint(&buf, "{d}", .{t / 10}) catch unreachable;
                const point_x = right - cut.digit - period;
                _ = wpt_card.draw(&img, &atlas, cut, whole, point_x - wpt_card.measure(cut, whole), y, color);
                const tenth = [1]u8{'0' + @as(u8, @intCast(t % 10))};
                _ = wpt_card.draw(&img, &atlas, cut, &tenth, right - cut.digit, y, color);
            } else {
                // No run: no point and no "%", a dash in their place.
                const r0: u32 = @intFromFloat(right);
                const yy: u32 = @intCast(y);
                blank(&img, r0 - blank_left, yy - blank_up, r0 + blank_right, yy + blank_down);
                var dy = yy - 22;
                while (dy < yy - 18) : (dy += 1) {
                    var dx = r0 - 34;
                    while (dx < r0 - 6) : (dx += 1) img.at(dx, dy).* = ink_2;
                }
            }
        }
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

const sample = [_]Row{
    .{ .title = "Angular", .crane = 998, .chrome = 999 },
    .{ .title = "htmx", .crane = 999, .chrome = null },
    .{ .title = "jQuery", .crane = 994, .chrome = 997 },
    .{ .title = "TodoMVC", .crane = 764, .chrome = 767 },
};
const sample_figures: Figures = .{ .rows = &sample, .waiting = &waiting_titles };

test "card: the base decodes at 1200x630 and carries no rate: each integer and tenth's place is paper" {
    var base = try png.decode(testing.allocator, base_png);
    defer base.deinit(testing.allocator);
    try testing.expectEqual(@as(u32, width), base.width);
    try testing.expectEqual(@as(u32, height), base.height);
    for (row_baseline) |y| for (column_right) |right| {
        const yy: u32 = @intCast(y);
        const r: u32 = @intFromFloat(right);
        const point: u32 = @intFromFloat(right - cut.digit - period);
        // The integer part's place and the tenth's are blank ...
        try testing.expectEqual(@as(usize, 0), darkIn(base, point - 90, yy - 44, point - 1, yy + 2));
        try testing.expectEqual(@as(usize, 0), darkIn(base, r - @as(u32, @intFromFloat(cut.digit)) + 1, yy - 44, r, yy + 2));
        // ... and the point and the "%" are there.
        try testing.expect(darkIn(base, point, yy - 12, point + @as(u32, @intFromFloat(period)), yy + 2) > 10);
        try testing.expect(darkIn(base, r + 2, yy - 34, r + blank_right, yy + 2) > 20);
    };
}

test "card: each rate lands in its cell, a missing one is a dash with no point or %" {
    const bytes = try render(testing.allocator, sample_figures);
    defer testing.allocator.free(bytes);
    var img = try png.decode(testing.allocator, bytes);
    defer img.deinit(testing.allocator);
    try testing.expectEqual(@as(u32, width), img.width);
    for (row_baseline, 0..) |y, i| for (column_right, 0..) |right, col| {
        const yy: u32 = @intCast(y);
        const r: u32 = @intFromFloat(right);
        const point: u32 = @intFromFloat(right - cut.digit - period);
        if (i == 1 and col == 1) {
            // htmx in Chrome: blank but for the dash.
            try testing.expectEqual(@as(usize, 0), darkIn(img, point - 90, yy - 44, r + blank_right, yy - 24));
            try testing.expect(darkIn(img, r - 34, yy - 22, r - 6, yy - 18) > 50);
            continue;
        }
        try testing.expect(darkIn(img, point - 60, yy - 44, point - 1, yy + 2) > 200);
        try testing.expect(darkIn(img, r - @as(u32, @intFromFloat(cut.digit)) + 1, yy - 44, r, yy + 2) > 100);
    };
    // Same rates, same bytes; another rate, another card; small enough for
    // every crawler.
    const again = try render(testing.allocator, sample_figures);
    defer testing.allocator.free(again);
    try testing.expectEqualSlices(u8, bytes, again);
    var other = sample;
    other[0].crane = 997;
    const c = try render(testing.allocator, .{ .rows = &other, .waiting = &waiting_titles });
    defer testing.allocator.free(c);
    try testing.expect(!std.mem.eql(u8, bytes, c));
    try testing.expect(bytes.len < 400 * 1024);
}

test "card: rows other than base.png's are refused until it is remade" {
    var renamed = sample;
    renamed[1].title = "Lit";
    try testing.expectError(error.CardOutOfDate, render(testing.allocator, .{ .rows = &renamed, .waiting = &waiting_titles }));
    try testing.expectError(error.CardOutOfDate, render(testing.allocator, .{ .rows = sample[0..3], .waiting = &waiting_titles }));
    try testing.expectError(error.CardOutOfDate, render(testing.allocator, .{ .rows = &sample, .waiting = &.{ "React", "Vue" } }));
}

test "tenths: rounded, never 100.0 with a failure, never 0.0 with a pass" {
    try testing.expectEqual(@as(?u16, 998), tenths(12099, 12126));
    try testing.expectEqual(@as(?u16, 999), tenths(13164, 13165));
    try testing.expectEqual(@as(?u16, 1000), tenths(5, 5));
    try testing.expectEqual(@as(?u16, 1), tenths(1, 100000));
    try testing.expectEqual(@as(?u16, null), tenths(0, 0));
}
