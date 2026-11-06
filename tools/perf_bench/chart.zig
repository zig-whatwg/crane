//! /performance/'s charts as inline SVG, drawn by the generator (the results-site rules: the
//! content is in the HTML and every number is in the table beside its chart; no script is needed,
//! and each point carries a native tooltip). The classes are the WPT site's chart classes
//! (site.css: .chart-svg, .axis, .grid, .mark-line, .hit) plus the page's own series classes
//! (report.zig `style`), so light and dark both read.
//!
//! - `ratioChart`: Crane's figure as a share of each browser's, one line per browser, one x step
//!   per point of Crane's progress, on a log scale (a ratio of 2 and one of 1/2 are the same
//!   distance from 100%), with 100% drawn as the parity line.
//! - `sparkline`: one workload's figure over the same points, for a table row.
//!
//! A point can be `hollow`: not a round of its own but an earlier round's source rebuilt for a
//! later round's CPU target (report.zig `targetAlone`). The segment into it is dashed - that step
//! is the target's, not the code's - and a `Mark` names where the target changed.

const std = @import("std");
const Io = std.Io;
const html = @import("site_html");
const W = *Io.Writer;

pub const Point = struct {
    /// "Round 1"; and a second line under it, "apple_m1".
    label: []const u8,
    sub: []const u8 = "",
    hollow: bool = false,
};

pub const Line = struct {
    name: []const u8,
    /// The series class (report.zig `style`: s1..s4).
    class: []const u8,
    /// One per point: a ratio (1.0 = parity), null where there is none.
    values: []const ?f64,
    /// One tooltip per point.
    titles: []const []const u8,
};

/// A dashed vertical line just before point `at`, labelled.
pub const Mark = struct {
    at: usize,
    label: []const u8,
};

pub const Options = struct {
    /// The whole chart's accessible name: what it shows and its range.
    aria: []const u8,
    width: f64 = 640,
    height: f64 = 270,
};

const pad = struct {
    const l = 72.0;
    const r = 56.0;
    const t = 26.0;
    const b = 44.0;
};

/// The powers of two that bound `lo`..`hi` (both > 0), as exponents.
fn bounds(lo: f64, hi: f64) [2]i32 {
    const a: i32 = @intFromFloat(@floor(std.math.log2(lo)));
    var b: i32 = @intFromFloat(@ceil(std.math.log2(hi)));
    if (b <= a) b = a + 1;
    return .{ a, b };
}

fn xOf(o: Options, n: usize, i: usize) f64 {
    const iw = o.width - pad.l - pad.r;
    if (n <= 1) return pad.l + iw / 2;
    return pad.l + iw * @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(n - 1));
}

fn writePercent(w: W, ratio: f64) !void {
    // 12.5% stays 12.5%: a grid line is a power of two.
    if (ratio < 0.2) return w.print("{d:.1}%", .{ratio * 100});
    try w.print("{d}%", .{@as(u64, @intFromFloat(@round(ratio * 100)))});
}

/// Whether a chart of values `lo`..`hi` draws the parity line: its scale, the powers of two
/// around the data, reaches 100%.
pub fn reachesParity(lo: f64, hi: f64) bool {
    if (hi <= 0) return false;
    const e = bounds(lo, hi);
    return e[0] <= 0 and e[1] >= 0;
}

pub fn ratioChart(w: W, o: Options, points: []const Point, lines: []const Line, mark: ?Mark) !void {
    // The scale spans the data's powers of two; 100% (parity) is drawn when it falls inside,
    // never forced in - a time chart of 500%..800% would otherwise sit in its top quarter.
    var lo: f64 = std.math.floatMax(f64);
    var hi: f64 = 0;
    for (lines) |ln| for (ln.values) |v| if (v) |x| if (x > 0) {
        lo = @min(lo, x);
        hi = @max(hi, x);
    };
    if (hi == 0) {
        lo = 1;
        hi = 1;
    }
    const e = bounds(lo, hi);
    const ih = o.height - pad.t - pad.b;
    const span: f64 = @floatFromInt(e[1] - e[0]);
    const yOf = struct {
        fn f(v: f64, e0: i32, range: f64, h: f64) f64 {
            return pad.t + h - h * (std.math.log2(v) - @as(f64, @floatFromInt(e0))) / range;
        }
    }.f;
    try w.print("<svg class=\"chart-svg perf-chart\" viewBox=\"0 0 {d} {d}\" width=\"{d}\" height=\"{d}\" role=\"img\" aria-label=\"", .{ o.width, o.height, o.width, o.height });
    try html.text(w, o.aria);
    try w.writeAll("\">");
    // The grid: each power of two, labelled; 100% is the parity line.
    var k = e[0];
    while (k <= e[1]) : (k += 1) {
        const v = std.math.pow(f64, 2, @floatFromInt(k));
        const y = yOf(v, e[0], span, ih);
        try w.print("<line class=\"{s}\" x1=\"{d:.1}\" x2=\"{d:.1}\" y1=\"{d:.1}\" y2=\"{d:.1}\"/>", .{ if (k == 0) "parity" else "grid", pad.l, o.width - pad.r, y, y });
        try w.print("<text x=\"{d:.1}\" y=\"{d:.1}\" text-anchor=\"end\">", .{ pad.l - 6, y + 4 });
        try writePercent(w, v);
        try w.writeAll("</text>");
    }
    for (points, 0..) |p, i| {
        const x = xOf(o, points.len, i);
        try w.print("<text x=\"{d:.1}\" y=\"{d:.1}\" text-anchor=\"middle\">", .{ x, pad.t + ih + 18 });
        try html.text(w, p.label);
        try w.writeAll("</text>");
        if (p.sub.len > 0) {
            try w.print("<text x=\"{d:.1}\" y=\"{d:.1}\" text-anchor=\"middle\">", .{ x, pad.t + ih + 32 });
            try html.text(w, p.sub);
            try w.writeAll("</text>");
        }
    }
    if (mark) |mk| if (mk.at > 0 and mk.at < points.len) {
        const x = (xOf(o, points.len, mk.at - 1) + xOf(o, points.len, mk.at)) / 2;
        try w.print("<line class=\"mark-line\" x1=\"{d:.1}\" x2=\"{d:.1}\" y1=\"{d:.1}\" y2=\"{d:.1}\"/>", .{ x, x, pad.t - 8, pad.t + ih });
        try w.print("<text class=\"mark-label\" x=\"{d:.1}\" y=\"{d:.1}\" text-anchor=\"middle\">", .{ x, pad.t - 12 });
        try html.text(w, mk.label);
        try w.writeAll("</text>");
    };
    for (lines) |ln| {
        // Segment by segment: one into a hollow point is the target's step, dashed.
        var prev: ?usize = null;
        for (ln.values, 0..) |v, i| {
            const x = v orelse continue;
            if (x <= 0) continue;
            if (prev) |j| {
                try w.print("<line class=\"{s}{s}\" x1=\"{d:.1}\" x2=\"{d:.1}\" y1=\"{d:.1}\" y2=\"{d:.1}\"/>", .{
                    ln.class,
                    if (points[i].hollow) " step-target" else "",
                    xOf(o, points.len, j),
                    xOf(o, points.len, i),
                    yOf(ln.values[j].?, e[0], span, ih),
                    yOf(x, e[0], span, ih),
                });
            }
            prev = i;
        }
        for (ln.values, 0..) |v, i| {
            const x = v orelse continue;
            if (x <= 0) continue;
            const cx = xOf(o, points.len, i);
            const cy = yOf(x, e[0], span, ih);
            try w.print("<g><circle class=\"hit\" cx=\"{d:.1}\" cy=\"{d:.1}\" r=\"9\"/><circle class=\"{s} dot{s}\" cx=\"{d:.1}\" cy=\"{d:.1}\" r=\"4\"/><title>", .{ cx, cy, ln.class, if (points[i].hollow) " hollow" else "", cx, cy });
            try html.text(w, ln.titles[i]);
            try w.writeAll("</title></g>");
        }
    }
    try w.writeAll("</svg>");
}

/// One row's figure over the points: its own scale (min to max), a dot on the latest point, a
/// hollow one on a hollow point, the segment into a hollow point dashed, and a mark before
/// `mark_at`. Nothing when fewer than two points have a figure.
const sw: f64 = 96;
const sh: f64 = 26;
const sp: f64 = 3;

pub fn sparkline(w: W, aria: []const u8, values: []const ?f64, points: []const Point, mark_at: ?usize) !void {
    var lo: f64 = std.math.floatMax(f64);
    var hi: f64 = -std.math.floatMax(f64);
    var n: usize = 0;
    var last: usize = 0;
    for (values, 0..) |v, i| if (v) |x| {
        lo = @min(lo, x);
        hi = @max(hi, x);
        n += 1;
        last = i;
    };
    if (n < 2) return;
    if (hi - lo < hi * 1e-9) {
        lo -= 1;
        hi += 1;
    }
    const step = (sw - 2 * sp) / @as(f64, @floatFromInt(@max(values.len, 2) - 1));
    try w.print("<svg class=\"chart-svg spark\" viewBox=\"0 0 {d} {d}\" width=\"{d}\" height=\"{d}\" role=\"img\" aria-label=\"", .{ sw, sh, sw, sh });
    try html.text(w, aria);
    try w.writeAll("\">");
    const y = struct {
        fn f(v: f64, l: f64, h: f64) f64 {
            return sp + (sh - 2 * sp) * (1 - (v - l) / (h - l));
        }
    }.f;
    if (mark_at) |m| if (m > 0 and m < values.len) {
        const x = sp + step * (@as(f64, @floatFromInt(m)) - 0.5);
        try w.print("<line class=\"mark-line\" x1=\"{d:.1}\" x2=\"{d:.1}\" y1=\"0\" y2=\"{d}\"/>", .{ x, x, sh });
    };
    var prev: ?usize = null;
    for (values, 0..) |v, i| {
        const x = v orelse continue;
        if (prev) |j| try w.print("<line class=\"spark-line{s}\" x1=\"{d:.1}\" x2=\"{d:.1}\" y1=\"{d:.1}\" y2=\"{d:.1}\"/>", .{
            if (points[i].hollow) " step-target" else "",
            sp + step * @as(f64, @floatFromInt(j)),
            sp + step * @as(f64, @floatFromInt(i)),
            y(values[j].?, lo, hi),
            y(x, lo, hi),
        });
        prev = i;
    }
    for (values, 0..) |v, i| {
        const x = v orelse continue;
        if (!points[i].hollow and i != last) continue;
        try w.print("<circle class=\"spark-dot{s}\" cx=\"{d:.1}\" cy=\"{d:.1}\" r=\"2.5\"/>", .{ if (points[i].hollow) " hollow" else "", sp + step * @as(f64, @floatFromInt(i)), y(x, lo, hi) });
    }
    try w.writeAll("</svg>");
}

const testing = std.testing;

test "Crane's share of each browser on a log scale: parity drawn, the target's step dashed, a tooltip per point" {
    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    const points = [_]Point{ .{ .label = "Round 0", .sub = "apple_m4 (native)" }, .{ .label = "Round 0's source", .sub = "apple_m1", .hollow = true }, .{ .label = "Round 1", .sub = "apple_m1" } };
    const lines = [_]Line{
        .{ .name = "Chrome", .class = "s1", .values = &.{ 7.36, 7.5, 5.1 }, .titles = &.{ "a", "b", "c" } },
        .{ .name = "Lightpanda", .class = "s4", .values = &.{ 0.5, null, 0.4 }, .titles = &.{ "d", "e", "f" } },
    };
    try ratioChart(&out.writer, .{ .aria = "Crane's time as a share of each browser's" }, &points, &lines, .{ .at = 1, .label = "-Dcpu=apple_m1" });
    const svg = out.written();
    try testing.expect(std.mem.startsWith(u8, svg, "<svg class=\"chart-svg perf-chart\" viewBox=\"0 0 640 270\""));
    try testing.expect(std.mem.endsWith(u8, svg, "</svg>"));
    // 0.4 .. 7.5 lies between 2^-2 and 2^3: 25% .. 800%, with 100% the parity line inside.
    try testing.expect(std.mem.indexOf(u8, svg, ">25%</text>") != null);
    try testing.expect(std.mem.indexOf(u8, svg, ">800%</text>") != null);
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, svg, "class=\"parity\""));
    // Chrome's step into the hollow point is the target's (dashed); the next is the code's.
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, svg, "class=\"s1 step-target\""));
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, svg, "<line class=\"s1\""));
    // Lightpanda has no hollow point: one solid segment across it.
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, svg, "<line class=\"s4\""));
    try testing.expectEqual(@as(usize, 5), std.mem.count(u8, svg, "<title>"));
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, svg, "dot hollow"));
    try testing.expect(std.mem.indexOf(u8, svg, ">-Dcpu=apple_m1</text>") != null);
    try testing.expect(std.mem.indexOf(u8, svg, ">apple_m4 (native)</text>") != null);
    try testing.expect(std.mem.indexOf(u8, svg, "aria-label=\"Crane&#39;s time as a share of each browser&#39;s\"") != null);
}

test "the scale is the data's: parity only when it falls inside, small shares with their decimal" {
    const points = [_]Point{ .{ .label = "0" }, .{ .label = "1" } };
    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    try ratioChart(&out.writer, .{ .aria = "t" }, &points, &.{.{ .name = "Chrome", .class = "s1", .values = &.{ 7.36, 5.1 }, .titles = &.{ "a", "b" } }}, null);
    // 510%..736%: 400%..800%, no parity line.
    try testing.expect(std.mem.indexOf(u8, out.written(), ">400%</text>") != null);
    try testing.expect(std.mem.indexOf(u8, out.written(), ">200%</text>") == null);
    try testing.expectEqual(@as(usize, 0), std.mem.count(u8, out.written(), "class=\"parity\""));
    try testing.expect(!reachesParity(5.1, 7.36));
    try testing.expect(reachesParity(0.32, 0.9));
    try testing.expect(reachesParity(0.4, 7.5));
    var small: Io.Writer.Allocating = .init(testing.allocator);
    defer small.deinit();
    try ratioChart(&small.writer, .{ .aria = "m" }, &points, &.{.{ .name = "Firefox", .class = "s2", .values = &.{ 0.32, 0.15 }, .titles = &.{ "a", "b" } }}, null);
    try testing.expect(std.mem.indexOf(u8, small.written(), ">12.5%</text>") != null);
}

test "a sparkline: two points or more, the latest dotted, the hollow point hollow" {
    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    const points = [_]Point{ .{ .label = "0" }, .{ .label = "b", .hollow = true }, .{ .label = "1" } };
    try sparkline(&out.writer, "dom.a time", &.{ 40, 44, 20 }, &points, 1);
    const svg = out.written();
    try testing.expect(std.mem.startsWith(u8, svg, "<svg class=\"chart-svg spark\""));
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, svg, "<line class=\"spark-line"));
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, svg, "spark-line step-target"));
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, svg, "<circle"));
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, svg, "spark-dot hollow"));
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, svg, "class=\"mark-line\""));
    // One figure: nothing to draw.
    var none: Io.Writer.Allocating = .init(testing.allocator);
    defer none.deinit();
    try sparkline(&none.writer, "x", &.{ 40, null, null }, &points, null);
    try testing.expectEqual(@as(usize, 0), none.written().len);
    // A flat row still draws, mid-height.
    var flat: Io.Writer.Allocating = .init(testing.allocator);
    defer flat.deinit();
    try sparkline(&flat.writer, "x", &.{ 10, 10 }, points[0..2], null);
    try testing.expect(std.mem.indexOf(u8, flat.written(), "<line class=\"spark-line") != null);
}
