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
    /// The rate as the page writes it (`rateOf`); null: no run.
    crane: ?Rate,
    chrome: ?Rate,
};

pub const Figures = struct {
    rows: []const Row,
    waiting: []const []const u8,
};

/// A pass rate as the page and the card both write it: tenths of a
/// percent, rounded, with ">" where it rounds to 100.0% though a test failed
/// (">99.9%") and "<" where it rounds to 0.0% though one passed ("<0.1%").
pub const Rate = struct {
    qualifier: ?u8 = null,
    tenths: u16,

    /// "99.8%", ">99.9%".
    pub fn text(r: Rate, buf: []u8) []const u8 {
        if (r.qualifier) |q| return std.fmt.bufPrint(buf, "{c}{d}.{d}%", .{ q, r.tenths / 10, r.tenths % 10 }) catch unreachable;
        return std.fmt.bufPrint(buf, "{d}.{d}%", .{ r.tenths / 10, r.tenths % 10 }) catch unreachable;
    }
};

/// Passed over run (report.zig writes every rate on the page through it);
/// null with nothing run.
pub fn rateOf(pass: u32, ran: u32) ?Rate {
    if (ran == 0) return null;
    const t: u16 = @intCast((@as(u64, pass) * 1000 + ran / 2) / ran);
    if (pass < ran and t == 1000) return .{ .qualifier = '>', .tenths = 999 };
    if (pass > 0 and t == 0) return .{ .qualifier = '<', .tenths = 1 };
    return .{ .tenths = t };
}

const base_png = @embedFile("card/base.png");
/// ">" and "<" in the rates' cut, one per cell as the WPT atlas's `of` row
/// holds its glyphs (card/source.html ?part=marks): the atlas has no such
/// glyph, and the page writes ">99.9%".
const marks_png = @embedFile("card/marks.png");
const marks = "><";
/// Their advances in the cut, measured with the point's (?part=metrics).
pub const mark_advance = [2]f64{ 30, 30 };

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
/// The site's pass and fail tokens (site.css, light): each row's Crane meter,
/// as the page draws it - green for the tests passed, red for the rest.
const pass_color = [3]u8{ 0x2e, 0x7d, 0x32 };
const fail_color = [3]u8{ 0xb3, 0x26, 0x1e };
/// Where the meters sit: between the row labels and the rates, above each
/// row's baseline (base.png is paper there).
pub const meter_x0 = 330;
pub const meter_x1 = 610;
const meter_up = 26;
const meter_down = 14;

/// Paint a box with the paper colour.
fn blank(img: *png.Image, x0: u32, y0: u32, x1: u32, y1: u32) void {
    var y = y0;
    while (y < @min(y1, img.height)) : (y += 1) {
        var x = x0;
        while (x < @min(x1, img.width)) : (x += 1) img.at(x, y).* = .{ 0xff, 0xff, 0xff };
    }
}

/// Mark `i` of the marks sheet with its origin at pen x `x` on baseline `y`
/// (wpt_card.draw's blend, for a sheet laid out as one of its rows).
fn drawMark(img: *png.Image, sheet: *const png.Image, c: wpt_card.Cut, i: usize, x: f64, y: i32, color: [3]u8) void {
    const gx: i32 = @as(i32, @intFromFloat(@round(x))) - @as(i32, @intCast(c.ox));
    const gy: i32 = y - @as(i32, @intCast(c.baseline));
    for (0..c.cell_h) |cy| for (0..c.cell_w) |cx| {
        const ax: u32 = @intCast(i * c.cell_w + cx);
        const ay: u32 = @intCast(c.row_y + cy);
        if (ax >= sheet.width or ay >= sheet.height) continue;
        const cov: u16 = 255 - @as(u16, sheet.at(ax, ay)[0]);
        if (cov == 0) continue;
        const dx = gx + @as(i32, @intCast(cx));
        const dy = gy + @as(i32, @intCast(cy));
        if (dx < 0 or dy < 0 or dx >= img.width or dy >= img.height) continue;
        const p = img.at(@intCast(dx), @intCast(dy));
        for (p, color) |*ch, want| ch.* = @intCast((@as(u16, ch.*) * (255 - cov) + @as(u16, want) * cov + 127) / 255);
    };
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

    var marks_img = try png.decode(gpa, marks_png);
    defer marks_img.deinit(gpa);
    // The marks sheet is one row of the atlas's `of` cut, at row 0.
    var mark_cut = cut;
    mark_cut.row_y = 0;

    var buf: [8]u8 = undefined;
    for (f.rows, row_baseline) |r, y| {
        if (r.crane) |rv| {
            const green_end: u32 = meter_x0 + @as(u32, @intFromFloat(@round(@as(f64, @floatFromInt(meter_x1 - meter_x0)) * @as(f64, @floatFromInt(rv.tenths)) / 1000.0)));
            const yy: u32 = @intCast(y);
            var my = yy - meter_up;
            while (my < yy - meter_down) : (my += 1) {
                var mx: u32 = meter_x0;
                while (mx < meter_x1) : (mx += 1) img.at(mx, my).* = if (mx < green_end) pass_color else fail_color;
            }
        }
        for ([_]?Rate{ r.crane, r.chrome }, column_right, 0..) |value, right, col| {
            const color = if (col == 0) ink else ink_2;
            if (value) |rv| {
                const t = rv.tenths;
                const whole = std.fmt.bufPrint(&buf, "{d}", .{t / 10}) catch unreachable;
                const point_x = right - cut.digit - period;
                const whole_x = point_x - wpt_card.measure(cut, whole);
                _ = wpt_card.draw(&img, &atlas, cut, whole, whole_x, y, color);
                const tenth = [1]u8{'0' + @as(u8, @intCast(t % 10))};
                _ = wpt_card.draw(&img, &atlas, cut, &tenth, right - cut.digit, y, color);
                if (rv.qualifier) |q| {
                    const mi = std.mem.indexOfScalar(u8, marks, q).?;
                    drawMark(&img, &marks_img, mark_cut, mi, whole_x - mark_advance[mi], y, color);
                }
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
    .{ .title = "Angular", .crane = .{ .tenths = 998 }, .chrome = .{ .qualifier = '>', .tenths = 999 } },
    .{ .title = "htmx", .crane = .{ .tenths = 999 }, .chrome = null },
    .{ .title = "jQuery", .crane = .{ .tenths = 994 }, .chrome = .{ .tenths = 997 } },
    .{ .title = "TodoMVC", .crane = .{ .tenths = 764 }, .chrome = .{ .tenths = 767 } },
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
    other[0].crane = .{ .tenths = 997 };
    const c = try render(testing.allocator, .{ .rows = &other, .waiting = &waiting_titles });
    defer testing.allocator.free(c);
    try testing.expect(!std.mem.eql(u8, bytes, c));
    try testing.expect(bytes.len < 400 * 1024);
}

test "card: each row's Crane meter is green for its rate and red for the rest" {
    const bytes = try render(testing.allocator, sample_figures);
    defer testing.allocator.free(bytes);
    var img = try png.decode(testing.allocator, bytes);
    defer img.deinit(testing.allocator);
    const Count = struct {
        fn of(im: png.Image, y: u32, want: [3]u8) u32 {
            var n: u32 = 0;
            var x: u32 = meter_x0;
            while (x < meter_x1) : (x += 1) n += @intFromBool(std.mem.eql(u8, im.at(x, y), &want));
            return n;
        }
    };
    // TodoMVC 76.4%: 214 of 280 pixels green, the rest red; Angular 99.8%: 279 green.
    const todo_y: u32 = @intCast(row_baseline[3] - 20);
    try testing.expectEqual(@as(u32, 214), Count.of(img, todo_y, pass_color));
    try testing.expectEqual(@as(u32, 66), Count.of(img, todo_y, fail_color));
    try testing.expectEqual(@as(u32, 279), Count.of(img, @intCast(row_baseline[0] - 20), pass_color));
    // The base is paper where the meters go.
    var base = try png.decode(testing.allocator, base_png);
    defer base.deinit(testing.allocator);
    for (row_baseline) |y| try testing.expectEqual(@as(usize, 0), darkIn(base, meter_x0, @intCast(y - meter_up), meter_x1, @intCast(y - meter_down)));
}

test "card: rows other than base.png's are refused until it is remade" {
    var renamed = sample;
    renamed[1].title = "Lit";
    try testing.expectError(error.CardOutOfDate, render(testing.allocator, .{ .rows = &renamed, .waiting = &waiting_titles }));
    try testing.expectError(error.CardOutOfDate, render(testing.allocator, .{ .rows = sample[0..3], .waiting = &waiting_titles }));
    try testing.expectError(error.CardOutOfDate, render(testing.allocator, .{ .rows = &sample, .waiting = &.{ "React", "Vue" } }));
}

test "rateOf: rounded, never 100.0 with a failure, never 0.0 with a pass - the page's text and the card's" {
    var buf: [16]u8 = undefined;
    try testing.expectEqualStrings("99.8%", rateOf(12099, 12126).?.text(&buf));
    try testing.expectEqualStrings(">99.9%", rateOf(13164, 13165).?.text(&buf));
    try testing.expectEqualStrings("100.0%", rateOf(5, 5).?.text(&buf));
    try testing.expectEqualStrings("<0.1%", rateOf(1, 100000).?.text(&buf));
    try testing.expect(rateOf(0, 0) == null);
}

test "card: a qualified rate carries its mark before the number; an exact one has none" {
    const bytes = try render(testing.allocator, sample_figures);
    defer testing.allocator.free(bytes);
    var img = try png.decode(testing.allocator, bytes);
    defer img.deinit(testing.allocator);
    var marks_img = try png.decode(testing.allocator, marks_png);
    defer marks_img.deinit(testing.allocator);
    // The sheet has ink in each of its cells.
    for (0..marks.len) |i| try testing.expect(darkIn(marks_img, @intCast(i * cut.cell_w), 0, @intCast((i + 1) * cut.cell_w), cut.cell_h) > 20);
    // Angular's Chrome rate, ">99.9": a mark just left of its "99"; Crane's
    // "99.8" in the same row has none.
    const y: u32 = @intCast(row_baseline[0]);
    for (column_right, 0..) |right, col| {
        const whole_x: u32 = @intFromFloat(right - cut.digit - period - 2 * cut.digit);
        const ink_left = darkIn(img, whole_x - 34, y - 40, whole_x - 2, y);
        if (col == 1) try testing.expect(ink_left > 30) else try testing.expectEqual(@as(usize, 0), ink_left);
    }
}
