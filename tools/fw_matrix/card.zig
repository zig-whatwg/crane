//! /frameworks/'s social card (og:image, twitter:image): 1200x630, the pass
//! rate of each framework's own tests and of TodoMVC's apps' tests in Crane
//! beside Chrome, and the frameworks Crane cannot run yet - one row each, as
//! many rows as the page's chart has.
//!
//! Composed from three drawn parts, never re-drawn per run:
//! - card/base.png, the frame: title, scope line, column heads, the rules
//!   above and below the rows (`rows_top`, `rows_bottom`), footer;
//! - the WPT site's digit atlas (tools/wpt_site/card.zig: the same glyphs,
//!   cuts and metrics as the progress and performance cards, so the three
//!   cannot drift apart) for each rate's digits;
//! - card/marks.png, the glyph sheet: what the atlas lacks - each rate's
//!   ">", "<", "." and "%" - and printable ASCII in the row labels' faces
//!   (`Face`), so that any row title is written from it.
//! The rows take the largest size they fit in between the rules (`sizeFor`):
//! the atlas's 60px cut, then its 40px cut. A chart with more rows than the
//! smallest fits, or a title with a glyph the sheet lacks, draws no card
//! (error.CardOutOfDate, the reason logged: `outOfDate`). Same rates, same
//! bytes. card/source.html draws the parts (card/README.md).

const std = @import("std");
const Allocator = std.mem.Allocator;
const wpt_card = @import("site_card");
const png = wpt_card.png;

const log = std.log.scoped(.fw_matrix_card);

pub const width = 1200;
pub const height = 630;

pub const Row = struct {
    title: []const u8,
    /// The rate as the page writes it (`rateOf`); null: no run.
    crane: ?Rate,
    chrome: ?Rate,
};

pub const Figures = struct {
    /// The frameworks Crane runs and TodoMVC, in the chart's order.
    rows: []const Row,
    /// The frameworks that cannot run yet: a row each, after the others.
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
const sheet_png = @embedFile("card/marks.png");

/// One face of the glyph sheet: its glyphs, one per cell (`cell_w` x
/// `cell_h`, the glyph's origin at `ox` and `baseline` in its cell), black
/// on white, `per_row` cells to a row from y `row_y`, and their advances as
/// Chrome measured them (card/source.html FACES and PER_ROW, ?part=metrics).
pub const Face = struct {
    row_y: u32,
    cell_w: u32,
    cell_h: u32,
    ox: u32,
    baseline: u32,
    glyphs: []const u8,
    advances: []const f64,

    /// Cells to a row of the sheet (source.html PER_ROW).
    pub const per_row = 32;

    /// Glyph `i`'s cell's top-left corner in the sheet.
    pub fn cellOf(f: Face, i: usize) struct { u32, u32 } {
        return .{ @intCast((i % per_row) * f.cell_w), @intCast(f.row_y + (i / per_row) * f.cell_h) };
    }

    fn index(f: Face, g: u8) ?usize {
        return std.mem.indexOfScalar(u8, f.glyphs, g);
    }

    /// Whether the face writes every glyph of `s`.
    pub fn writes(f: Face, s: []const u8) bool {
        for (s) |g| if (f.index(g) == null) return false;
        return true;
    }

    pub fn measure(f: Face, s: []const u8) f64 {
        var w: f64 = 0;
        for (s) |g| w += f.advances[f.index(g) orelse continue];
        return w;
    }
};

/// Printable ASCII, the label faces' glyphs.
const ascii: [95]u8 = blk: {
    var a: [95]u8 = undefined;
    for (&a, 0..) |*c, i| c.* = @intCast(0x20 + i);
    break :blk a;
};

/// Source Serif 4 400 60px - the atlas's `of` cut's face: ">", "<", ".".
pub const large_marks: Face = .{ .row_y = 0, .cell_w = 60, .cell_h = 80, .ox = 10, .baseline = 62, .glyphs = "><.", .advances = &large_marks_advances };
/// Source Serif 4 400 40px: the 60px rates' "%".
pub const large_percent: Face = .{ .row_y = 80, .cell_w = 44, .cell_h = 56, .ox = 8, .baseline = 42, .glyphs = "%", .advances = &large_percent_advances };
/// Source Serif 4 600 40px - the atlas's `small` cut's face: ">", "<", ".".
pub const small_marks: Face = .{ .row_y = 136, .cell_w = 44, .cell_h = 56, .ox = 8, .baseline = 42, .glyphs = "><.", .advances = &small_marks_advances };
/// Source Serif 4 400 28px: the 40px rates' "%".
pub const small_percent: Face = .{ .row_y = 192, .cell_w = 32, .cell_h = 40, .ox = 6, .baseline = 30, .glyphs = "%", .advances = &small_percent_advances };
/// Public Sans 500 28px: the rows' labels at the 60px size.
pub const label_large: Face = .{ .row_y = 232, .cell_w = 40, .cell_h = 44, .ox = 6, .baseline = 32, .glyphs = &ascii, .advances = &label_large_advances };
/// Public Sans 500 22px: the rows' labels at the 40px size.
pub const label_small: Face = .{ .row_y = 364, .cell_w = 32, .cell_h = 36, .ox = 5, .baseline = 26, .glyphs = &ascii, .advances = &label_small_advances };

// The advances (card/source.html ?part=metrics, Chrome for Testing
// 157.0.8103.78, 2026-11-22).
const large_marks_advances = [3]f64{ 30, 30, 15.484375 };
const large_percent_advances = [1]f64{33.484375};
const small_marks_advances = [3]f64{ 20.8125, 20.8125, 11.1875 };
const small_percent_advances = [1]f64{24.171875};
const label_large_advances = [95]f64{ 6.671875, 7.265625, 12.328125, 17, 19.609375, 25.59375, 20.421875, 7.046875, 8.71875, 8.875, 11.640625, 15.796875, 8.40625, 10.6875, 8.40625, 10.0625, 19.609375, 19.609375, 19.609375, 19.609375, 19.609375, 19.609375, 19.609375, 19.609375, 19.609375, 19.609375, 6.65625, 7.03125, 15.53125, 15.796875, 15.515625, 14.6875, 23.25, 20.015625, 18.890625, 19.515625, 19.625, 17.484375, 16.78125, 20.734375, 21.484375, 8.125, 10.984375, 19.375, 16.171875, 25.046875, 21.328125, 20.765625, 17.953125, 21.140625, 19.09375, 18.9375, 16.796875, 19.796875, 19.078125, 26.8125, 19.5, 17.46875, 18.09375, 8.75, 10.0625, 8.75, 13.328125, 14.765625, 6.46875, 15.59375, 16.796875, 15.25, 16.796875, 15.953125, 11.09375, 17.484375, 16.265625, 7.078125, 7.546875, 15.875, 8.6875, 24.453125, 16.28125, 15.921875, 16.765625, 16.765625, 11.109375, 14.328125, 11.109375, 16.375, 14.25, 21.90625, 15.984375, 15.203125, 13.578125, 9.609375, 7.421875, 9.703125, 16.25 };
const label_small_advances = [95]f64{ 5.234375, 5.71875, 9.6875, 13.359375, 15.40625, 20.109375, 16.046875, 5.546875, 6.84375, 6.96875, 9.15625, 12.40625, 6.609375, 8.40625, 6.609375, 7.90625, 15.40625, 15.40625, 15.40625, 15.40625, 15.40625, 15.40625, 15.40625, 15.40625, 15.40625, 15.40625, 5.234375, 5.515625, 12.203125, 12.40625, 12.203125, 11.546875, 18.265625, 15.734375, 14.84375, 15.328125, 15.421875, 13.75, 13.1875, 16.28125, 16.875, 6.390625, 8.640625, 15.21875, 12.71875, 19.671875, 16.765625, 16.3125, 14.109375, 16.609375, 15, 14.875, 13.203125, 15.5625, 14.984375, 21.078125, 15.328125, 13.71875, 14.21875, 6.875, 7.90625, 6.875, 10.484375, 11.609375, 5.078125, 12.25, 13.203125, 11.984375, 13.203125, 12.53125, 8.71875, 13.734375, 12.78125, 5.5625, 5.9375, 12.46875, 6.828125, 19.21875, 12.796875, 12.5, 13.171875, 13.171875, 8.734375, 11.265625, 8.734375, 12.875, 11.203125, 17.21875, 12.5625, 11.953125, 10.671875, 7.5625, 5.828125, 7.625, 12.765625 };

/// A size the rows are laid out in: the atlas cut of their digits, the faces
/// of their marks, "%" and labels, and where each row's parts go relative to
/// its baseline.
pub const Size = struct {
    name: []const u8,
    cut: wpt_card.Cut,
    marks: Face,
    percent: Face,
    label: Face,
    /// The first row's baseline, and from one row's to the next's.
    first: i32,
    pitch: i32,
    /// How far below its baseline a row reaches (descenders).
    descent: i32,
    /// The Crane meter, above the baseline.
    meter_up: i32,
    meter_down: i32,
    /// A missing rate's dash, from its column's right edge and the baseline.
    dash_left: i32,
    dash_right: i32,
    dash_up: i32,
    dash_down: i32,
    /// The "%" from the tenth's right edge.
    percent_gap: f64,
};

/// The atlas's 60px cut: up to five rows (the page's first chart had four).
pub const large: Size = .{ .name = "60px", .cut = wpt_card.of, .marks = large_marks, .percent = large_percent, .label = label_large, .first = 296, .pitch = 62, .descent = 14, .meter_up = 26, .meter_down = 14, .dash_left = 34, .dash_right = 6, .dash_up = 22, .dash_down = 18, .percent_gap = 4 };
/// The atlas's 40px cut, the smallest the card writes a rate in (the
/// progress card's counts): up to seven rows.
pub const small: Size = .{ .name = "40px", .cut = wpt_card.small, .marks = small_marks, .percent = small_percent, .label = label_small, .first = 280, .pitch = 44, .descent = 10, .meter_up = 20, .meter_down = 12, .dash_left = 24, .dash_right = 4, .dash_up = 16, .dash_down = 13, .percent_gap = 3 };
/// Largest first.
pub const sizes = [_]Size{ large, small };

/// The rules base.png draws above and below the rows: the rows go between.
pub const rows_top = 232;
pub const rows_bottom = 572;
/// Where each column's tenths digit ends (its "%" just right of it).
pub const column_right = [2]f64{ 780, 1040 };
/// The labels' left edge, and the meters between labels and rates.
pub const label_x = 80;
pub const meter_x0 = 330;
pub const meter_x1 = 610;
/// What a waiting row says, where a running row has its meter.
pub const waiting_text = "can't run yet";

/// The largest size `rows` rows fit in between the rules; null when they do
/// not fit even in the smallest.
pub fn sizeFor(rows: usize) ?Size {
    for (sizes) |s| {
        if (rows == 0) return s;
        const last = s.first + @as(i32, @intCast(rows - 1)) * s.pitch;
        if (s.first - @as(i32, @intCast(s.cut.baseline)) >= rows_top - 8 and last + s.descent <= rows_bottom - 4) return s;
    }
    return null;
}

/// The most rows the card holds (at its smallest size).
pub fn maxRows() usize {
    var n: usize = 1;
    while (sizeFor(n + 1) != null) n += 1;
    return n;
}

/// A row's label: its title, but for TodoMVC's ("TodoMVC apps": its rate is
/// the apps' tests').
fn labelOf(title: []const u8) []const u8 {
    return if (std.mem.eql(u8, title, "TodoMVC")) "TodoMVC apps" else title;
}

/// Why `f` draws no card, into `buf`; null when it draws one.
pub fn outOfDate(f: Figures, buf: []u8) ?[]const u8 {
    const n = f.rows.len + f.waiting.len;
    const size = sizeFor(n) orelse return std.fmt.bufPrint(buf, "the chart has {d} rows; the card holds at most {d}, at its smallest size ({s})", .{ n, maxRows(), sizes[sizes.len - 1].name }) catch "the chart has more rows than the card holds";
    for (f.rows) |r| if (!size.label.writes(labelOf(r.title))) return std.fmt.bufPrint(buf, "row title \"{s}\" has a character the card's glyph sheet lacks (it holds printable ASCII)", .{r.title}) catch "a row title has a character the card's glyph sheet lacks";
    for (f.waiting) |t| if (!size.label.writes(labelOf(t))) return std.fmt.bufPrint(buf, "row title \"{s}\" has a character the card's glyph sheet lacks (it holds printable ASCII)", .{t}) catch "a row title has a character the card's glyph sheet lacks";
    return null;
}

const ink = [3]u8{ 0x20, 0x21, 0x24 };
const ink_2 = [3]u8{ 0x5a, 0x5e, 0x63 };
/// The site's pass and fail tokens (site.css, light): each row's Crane meter,
/// as the page draws it - green for the tests passed, red for the rest.
const pass_color = [3]u8{ 0x2e, 0x7d, 0x32 };
const fail_color = [3]u8{ 0xb3, 0x26, 0x1e };

/// Paint a box.
fn fill(img: *png.Image, x0: i32, y0: i32, x1: i32, y1: i32, color: [3]u8) void {
    var y = @max(y0, 0);
    while (y < @min(y1, @as(i32, @intCast(img.height)))) : (y += 1) {
        var x = @max(x0, 0);
        while (x < @min(x1, @as(i32, @intCast(img.width)))) : (x += 1) img.at(@intCast(x), @intCast(y)).* = color;
    }
}

/// Write `s` in face `f` of the sheet from pen x `x` on baseline `y`, in
/// `color` (the atlas's blend, wpt_card.draw); returns the pen after it.
fn drawText(img: *png.Image, sheet: *const png.Image, f: Face, s: []const u8, x: f64, y: i32, color: [3]u8) f64 {
    var pen = x;
    for (s) |g| {
        const i = f.index(g) orelse continue;
        const gx: i32 = @as(i32, @intFromFloat(@round(pen))) - @as(i32, @intCast(f.ox));
        const gy: i32 = y - @as(i32, @intCast(f.baseline));
        const cell = f.cellOf(i);
        for (0..f.cell_h) |cy| for (0..f.cell_w) |cx| {
            const ax: u32 = cell[0] + @as(u32, @intCast(cx));
            const ay: u32 = cell[1] + @as(u32, @intCast(cy));
            if (ax >= sheet.width or ay >= sheet.height) continue;
            const cov: u16 = 255 - @as(u16, sheet.at(ax, ay)[0]);
            if (cov == 0) continue;
            const dx = gx + @as(i32, @intCast(cx));
            const dy = gy + @as(i32, @intCast(cy));
            if (dx < 0 or dy < 0 or dx >= img.width or dy >= img.height) continue;
            const p = img.at(@intCast(dx), @intCast(dy));
            for (p, color) |*ch, want| ch.* = @intCast((@as(u16, ch.*) * (255 - cov) + @as(u16, want) * cov + 127) / 255);
        };
        pen += f.advances[i];
    }
    return pen;
}

/// The baseline of row `i` at `size`.
pub fn baselineOf(size: Size, i: usize) i32 {
    return size.first + @as(i32, @intCast(i)) * size.pitch;
}

/// Where a rate's decimal point goes: just left of its tenth.
pub fn pointX(size: Size, right: f64) f64 {
    return right - size.cut.digit - size.marks.advances[2];
}

/// The card for `f`, as PNG bytes owned by the caller.
pub fn render(gpa: Allocator, f: Figures) ![]u8 {
    var why: [256]u8 = undefined;
    if (outOfDate(f, &why)) |reason| {
        log.warn("no card: {s}", .{reason});
        return error.CardOutOfDate;
    }
    const size = sizeFor(f.rows.len + f.waiting.len).?;

    var img = try png.decode(gpa, base_png);
    defer img.deinit(gpa);
    var atlas = try png.decode(gpa, wpt_card.atlas_png);
    defer atlas.deinit(gpa);
    var sheet = try png.decode(gpa, sheet_png);
    defer sheet.deinit(gpa);

    var buf: [8]u8 = undefined;
    for (f.rows, 0..) |r, i| {
        const y = baselineOf(size, i);
        _ = drawText(&img, &sheet, size.label, labelOf(r.title), label_x, y, ink);
        if (r.crane) |rv| {
            const green_end: i32 = meter_x0 + @as(i32, @intFromFloat(@round(@as(f64, @floatFromInt(meter_x1 - meter_x0)) * @as(f64, @floatFromInt(rv.tenths)) / 1000.0)));
            fill(&img, meter_x0, y - size.meter_up, green_end, y - size.meter_down, pass_color);
            fill(&img, green_end, y - size.meter_up, meter_x1, y - size.meter_down, fail_color);
        }
        for ([_]?Rate{ r.crane, r.chrome }, column_right, 0..) |value, right, col| {
            const color = if (col == 0) ink else ink_2;
            const rv = value orelse {
                // No run: a dash, no point and no "%".
                const r0: i32 = @intFromFloat(right);
                fill(&img, r0 - size.dash_left, y - size.dash_up, r0 - size.dash_right, y - size.dash_down, ink_2);
                continue;
            };
            const whole = std.fmt.bufPrint(&buf, "{d}", .{rv.tenths / 10}) catch unreachable;
            const point_x = pointX(size, right);
            const whole_x = point_x - wpt_card.measure(size.cut, whole);
            _ = wpt_card.draw(&img, &atlas, size.cut, whole, whole_x, y, color);
            _ = drawText(&img, &sheet, size.marks, ".", point_x, y, color);
            const tenth = [1]u8{'0' + @as(u8, @intCast(rv.tenths % 10))};
            _ = wpt_card.draw(&img, &atlas, size.cut, &tenth, right - size.cut.digit, y, color);
            _ = drawText(&img, &sheet, size.percent, "%", right + size.percent_gap, y, ink_2);
            if (rv.qualifier) |q| {
                const mark = [1]u8{q};
                _ = drawText(&img, &sheet, size.marks, &mark, whole_x - size.marks.measure(&mark), y, color);
            }
        }
    }
    for (f.waiting, f.rows.len..) |title, i| {
        const y = baselineOf(size, i);
        _ = drawText(&img, &sheet, size.label, labelOf(title), label_x, y, ink);
        _ = drawText(&img, &sheet, size.label, waiting_text, meter_x0, y, ink_2);
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
fn darkIn(img: png.Image, x0: i32, y0: i32, x1: i32, y1: i32) usize {
    var n: usize = 0;
    var y = @max(y0, 0);
    while (y < y1) : (y += 1) {
        var x = @max(x0, 0);
        while (x < x1) : (x += 1) {
            if (img.at(@intCast(x), @intCast(y))[0] < 128) n += 1;
        }
    }
    return n;
}

/// Pixels of exactly `want` in row `y` between the meter's ends.
fn countIn(img: png.Image, y: i32, want: [3]u8) u32 {
    var n: u32 = 0;
    var x: i32 = meter_x0;
    while (x < meter_x1) : (x += 1) n += @intFromBool(std.mem.eql(u8, img.at(@intCast(x), @intCast(y)), &want));
    return n;
}

const four = [_]Row{
    .{ .title = "Angular", .crane = .{ .tenths = 998 }, .chrome = .{ .qualifier = '>', .tenths = 999 } },
    .{ .title = "htmx", .crane = .{ .tenths = 999 }, .chrome = null },
    .{ .title = "jQuery", .crane = .{ .tenths = 994 }, .chrome = .{ .tenths = 997 } },
    .{ .title = "TodoMVC", .crane = .{ .tenths = 764 }, .chrome = .{ .tenths = 767 } },
};
const seven = [_]Row{
    .{ .title = "Angular", .crane = .{ .tenths = 997 }, .chrome = .{ .qualifier = '>', .tenths = 999 } },
    .{ .title = "htmx", .crane = .{ .tenths = 997 }, .chrome = .{ .tenths = 1000 } },
    .{ .title = "jQuery", .crane = .{ .tenths = 994 }, .chrome = .{ .tenths = 997 } },
    .{ .title = "React", .crane = .{ .tenths = 0 }, .chrome = .{ .tenths = 1000 } },
    .{ .title = "Svelte", .crane = .{ .tenths = 924 }, .chrome = null },
    .{ .title = "Vue", .crane = .{ .tenths = 670 }, .chrome = .{ .tenths = 995 } },
    .{ .title = "TodoMVC", .crane = .{ .tenths = 687 }, .chrome = .{ .tenths = 668 } },
};

test "card: the base decodes at 1200x630 and is paper between its rules, where the rows go" {
    var base = try png.decode(testing.allocator, base_png);
    defer base.deinit(testing.allocator);
    try testing.expectEqual(@as(u32, width), base.width);
    try testing.expectEqual(@as(u32, height), base.height);
    try testing.expectEqual(@as(usize, 0), darkIn(base, 0, rows_top + 2, width, rows_bottom - 1));
    // The rules and the column heads are there.
    try testing.expect(base.at(600, rows_top)[0] < 0xf0);
    try testing.expect(base.at(600, rows_bottom)[0] < 0xf0);
    try testing.expect(darkIn(base, 700, 190, 1100, 220) > 100);
}

test "card: the sheet holds every face's glyphs, each with ink in its cell" {
    var sheet = try png.decode(testing.allocator, sheet_png);
    defer sheet.deinit(testing.allocator);
    for ([_]Face{ large_marks, large_percent, small_marks, small_percent, label_large, label_small }) |f| {
        try testing.expectEqual(f.glyphs.len, f.advances.len);
        const last = f.cellOf(f.glyphs.len - 1);
        try testing.expect(last[1] + f.cell_h <= sheet.height);
        try testing.expect(@min(f.glyphs.len, Face.per_row) * f.cell_w <= sheet.width);
        for (f.glyphs, 0..) |g, i| {
            const cell = f.cellOf(i);
            const x0: i32 = @intCast(cell[0]);
            const y0: i32 = @intCast(cell[1]);
            const ink_n = darkIn(sheet, x0, y0, x0 + @as(i32, @intCast(f.cell_w)), y0 + @as(i32, @intCast(f.cell_h)));
            if (g == ' ') try testing.expectEqual(@as(usize, 0), ink_n) else try testing.expect(ink_n > 0);
            try testing.expect(f.advances[i] > 0);
        }
    }
}

test "card: the rows take the largest size they fit in - 60px up to five, 40px up to seven - and no more" {
    for (1..6) |n| try testing.expectEqualStrings("60px", sizeFor(n).?.name);
    for (6..8) |n| try testing.expectEqualStrings("40px", sizeFor(n).?.name);
    try testing.expect(sizeFor(8) == null);
    try testing.expectEqual(@as(usize, 7), maxRows());
    // Every row of the largest count of each size stays between the rules.
    for ([_]struct { Size, usize }{ .{ large, 5 }, .{ small, 7 } }) |c| {
        try testing.expect(baselineOf(c[0], 0) - @as(i32, @intCast(c[0].cut.baseline)) >= rows_top - 8);
        try testing.expect(baselineOf(c[0], c[1] - 1) + c[0].descent <= rows_bottom - 4);
    }
}

test "card: a chart with more rows than fit, or a title the sheet cannot write, is refused, saying why" {
    var eight: [8]Row = undefined;
    @memcpy(eight[0..7], &seven);
    eight[7] = .{ .title = "Lit", .crane = .{ .tenths = 990 }, .chrome = null };
    var buf: [256]u8 = undefined;
    const reason = outOfDate(.{ .rows = &eight, .waiting = &.{} }, &buf).?;
    try testing.expect(std.mem.indexOf(u8, reason, "8 rows") != null);
    try testing.expect(std.mem.indexOf(u8, reason, "at most 7") != null);
    try testing.expectError(error.CardOutOfDate, render(testing.allocator, .{ .rows = &eight, .waiting = &.{} }));
    // Seven running and one waiting are eight too.
    try testing.expect(outOfDate(.{ .rows = &seven, .waiting = &.{"Lit"} }, &buf) != null);
    var odd = four;
    odd[1].title = "h\u{2019}mx";
    const why = outOfDate(.{ .rows = &odd, .waiting = &.{} }, &buf).?;
    try testing.expect(std.mem.indexOf(u8, why, "glyph sheet") != null);
    try testing.expectError(error.CardOutOfDate, render(testing.allocator, .{ .rows = &odd, .waiting = &.{} }));
    try testing.expect(outOfDate(.{ .rows = &seven, .waiting = &.{} }, &buf) == null);
}

fn expectRates(img: png.Image, size: Size, rows: []const Row) !void {
    for (rows, 0..) |r, i| {
        const y = baselineOf(size, i);
        const glyph_h: i32 = @intFromFloat(size.cut.digit * 1.4);
        for ([_]?Rate{ r.crane, r.chrome }, column_right) |value, right| {
            const ri: i32 = @intFromFloat(right);
            const point: i32 = @intFromFloat(pointX(size, right));
            if (value == null) {
                // Blank but for the dash.
                try testing.expectEqual(@as(usize, 0), darkIn(img, point - 70, y - glyph_h, ri + 30, y - size.dash_up - 1));
                try testing.expect(darkIn(img, ri - size.dash_left, y - size.dash_up, ri - size.dash_right, y - size.dash_down) > 20);
                continue;
            }
            // The integer part, the tenth, and the "%" each have ink.
            try testing.expect(darkIn(img, point - @as(i32, @intFromFloat(2 * size.cut.digit)), y - glyph_h, point - 1, y + 2) > 40);
            try testing.expect(darkIn(img, ri - @as(i32, @intFromFloat(size.cut.digit)) + 1, y - glyph_h, ri, y + 2) > 20);
            try testing.expect(darkIn(img, ri + 1, y - glyph_h, ri + 30, y + 2) > 10);
        }
        // The label has ink.
        try testing.expect(darkIn(img, label_x, y - 20, label_x + 60, y + 2) > 30);
    }
}

test "card: four rows in the 60px size, seven in the 40px: each rate lands in its cell, a missing one is a dash" {
    for ([_]struct { []const Row, Size }{ .{ &four, large }, .{ &seven, small } }) |c| {
        const bytes = try render(testing.allocator, .{ .rows = c[0], .waiting = &.{} });
        defer testing.allocator.free(bytes);
        var img = try png.decode(testing.allocator, bytes);
        defer img.deinit(testing.allocator);
        try testing.expectEqual(@as(u32, width), img.width);
        try expectRates(img, c[1], c[0]);
        // Nothing below the last row.
        const last = baselineOf(c[1], c[0].len - 1);
        try testing.expectEqual(@as(usize, 0), darkIn(img, 0, last + c[1].descent + 2, width, rows_bottom - 1));
    }
}

test "card: each row's Crane meter is green for its rate and red for the rest" {
    const bytes = try render(testing.allocator, .{ .rows = &seven, .waiting = &.{} });
    defer testing.allocator.free(bytes);
    var img = try png.decode(testing.allocator, bytes);
    defer img.deinit(testing.allocator);
    // TodoMVC 68.7%: 192 of 280 pixels green; React 0.0%: all red.
    const todo_y = baselineOf(small, 6) - small.meter_down - 2;
    try testing.expectEqual(@as(u32, 192), countIn(img, todo_y, pass_color));
    try testing.expectEqual(@as(u32, 88), countIn(img, todo_y, fail_color));
    try testing.expectEqual(@as(u32, 280), countIn(img, baselineOf(small, 3) - small.meter_down - 2, fail_color));
}

test "card: a qualified rate carries its mark before the number; an exact one has none" {
    const bytes = try render(testing.allocator, .{ .rows = &four, .waiting = &.{} });
    defer testing.allocator.free(bytes);
    var img = try png.decode(testing.allocator, bytes);
    defer img.deinit(testing.allocator);
    // Angular's Chrome rate, ">99.9": a mark just left of its "99"; Crane's
    // "99.8" in the same row has none.
    const y = baselineOf(large, 0);
    for (column_right, 0..) |right, col| {
        const whole_x: i32 = @intFromFloat(pointX(large, right) - 2 * large.cut.digit);
        const ink_left = darkIn(img, whole_x - 34, y - 40, whole_x - 2, y);
        if (col == 1) try testing.expect(ink_left > 30) else try testing.expectEqual(@as(usize, 0), ink_left);
    }
}

test "card: a framework that cannot run yet is a row of its own, saying so, with no rates" {
    const bytes = try render(testing.allocator, .{ .rows = &four, .waiting = &.{ "React", "Vue" } });
    defer testing.allocator.free(bytes);
    var img = try png.decode(testing.allocator, bytes);
    defer img.deinit(testing.allocator);
    // Six rows: the 40px size.
    for (4..6) |i| {
        const y = baselineOf(small, i);
        try testing.expect(darkIn(img, label_x, y - 18, label_x + 50, y + 2) > 20);
        try testing.expect(darkIn(img, meter_x0, y - 18, meter_x0 + 120, y + 2) > 40);
        // No meter colour and no rate.
        try testing.expectEqual(@as(u32, 0), countIn(img, y - small.meter_down - 2, pass_color));
        try testing.expectEqual(@as(usize, 0), darkIn(img, @as(i32, @intFromFloat(pointX(small, column_right[0]))) - 60, y - 30, width, y + 2));
    }
}

test "card: same rates, same bytes; another rate, another card; small enough for every crawler" {
    const bytes = try render(testing.allocator, .{ .rows = &seven, .waiting = &.{} });
    defer testing.allocator.free(bytes);
    const again = try render(testing.allocator, .{ .rows = &seven, .waiting = &.{} });
    defer testing.allocator.free(again);
    try testing.expectEqualSlices(u8, bytes, again);
    var other = seven;
    other[0].crane = .{ .tenths = 996 };
    const c = try render(testing.allocator, .{ .rows = &other, .waiting = &.{} });
    defer testing.allocator.free(c);
    try testing.expect(!std.mem.eql(u8, bytes, c));
    try testing.expect(bytes.len < 400 * 1024);
}

test "rateOf: rounded, never 100.0 with a failure, never 0.0 with a pass - the page's text and the card's" {
    var buf: [16]u8 = undefined;
    try testing.expectEqualStrings("99.8%", rateOf(12099, 12126).?.text(&buf));
    try testing.expectEqualStrings(">99.9%", rateOf(13164, 13165).?.text(&buf));
    try testing.expectEqualStrings("100.0%", rateOf(5, 5).?.text(&buf));
    try testing.expectEqualStrings("<0.1%", rateOf(1, 100000).?.text(&buf));
    try testing.expect(rateOf(0, 0) == null);
}
