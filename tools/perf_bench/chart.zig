//! /performance/'s charts as inline SVG, drawn by the generator (the results-site rules: the
//! content is in the HTML and every number is in the HTML beside its chart; no script is needed,
//! and each point carries a native tooltip). The classes are the WPT site's chart classes
//! (site.css: .chart-svg, .grid, .axis, .hit) plus the page's own (report.zig `style`), so light
//! and dark both read.
//!
//! - `trendChart`: one measure of Crane over its measurement rounds, as a share of its first
//!   round (1.0 = the same), on a linear scale from 0: ONE line, each point labelled with its
//!   value, the first round's level (100%) drawn as the reference line. The user, 2026-11-07,
//!   on the chart it replaces (one line per browser on a log scale, with a CPU-target point and
//!   a dashed step): "this graph is confusing for tracking Crane's progress". A point is a
//!   measurement round, never a methodology control (report.zig `progress`).
//! - `sparkline`: one workload's figure over the same rounds, for a table row.

const std = @import("std");
const Io = std.Io;
const html = @import("site_html");
const W = *Io.Writer;

/// One measurement round on the x axis: "Round 1", and under it the window's date and Crane's
/// commit.
pub const Point = struct {
    label: []const u8,
    date: []const u8 = "",
    commit: []const u8 = "",
};

pub const Trend = struct {
    /// The whole chart's accessible name: what it shows and its range.
    aria: []const u8,
    /// One per point: the share of the first round's figure (1.0 = the same), null where
    /// there is none.
    values: []const ?f64,
    /// One tooltip per point.
    titles: []const []const u8,
    width: f64 = 360,
    height: f64 = 232,
};

const pad = struct {
    const l = 42.0;
    const r = 10.0;
    const t = 24.0;
    /// Three lines of x label: the round, the date, the commit.
    const b = 60.0;
    /// The first and the last point sit this far inside the plot, so their labels fit.
    const inset = 40.0;
};

/// Below this many units between two points, an x label is the round alone (no date, no
/// commit: they would collide).
const full_label_spacing = 84.0;

/// The scale of a trend: from 0 to its top, 100% or the data's highest point, whichever is
/// higher, rounded up to a whole grid step - 25% up to 150%, 50% up to 300%, 100% beyond.
pub const Scale = struct { top: f64, step: f64 };

pub fn scaleOf(hi: f64) Scale {
    const h = @max(1.0, hi);
    const step: f64 = if (h <= 1.5) 0.25 else if (h <= 3.0) 0.5 else 1.0;
    // The epsilon keeps a top that is already a step (100%) from rounding up a step.
    return .{ .top = @ceil(h / step - 1e-9) * step, .step = step };
}

/// A share as a whole percentage ("81%", "0%"); a small one that is not whole keeps its decimal
/// ("12.5%").
fn writePercent(w: W, ratio: f64) !void {
    const pct = ratio * 100;
    if (ratio < 0.2 and @abs(pct - @round(pct)) > 1e-9) return w.print("{d:.1}%", .{pct});
    try w.print("{d}%", .{@as(u64, @intFromFloat(@round(pct)))});
}

pub fn trendChart(w: W, points: []const Point, t: Trend) !void {
    var hi: f64 = 0;
    for (t.values) |v| if (v) |x| {
        hi = @max(hi, x);
    };
    const s = scaleOf(hi);
    const ih = t.height - pad.t - pad.b;
    const x0 = pad.l + pad.inset;
    const x1 = t.width - pad.r - pad.inset;
    const n = points.len;
    const spacing = if (n <= 1) x1 - x0 else (x1 - x0) / @as(f64, @floatFromInt(n - 1));
    const geo = struct {
        x0: f64,
        spacing: f64,
        n: usize,
        ih: f64,
        top: f64,
        fn x(g: @This(), i: usize) f64 {
            if (g.n <= 1) return g.x0 + g.spacing / 2;
            return g.x0 + g.spacing * @as(f64, @floatFromInt(i));
        }
        fn y(g: @This(), v: f64) f64 {
            return pad.t + g.ih * (1 - v / g.top);
        }
    }{ .x0 = x0, .spacing = spacing, .n = n, .ih = ih, .top = s.top };

    try w.print("<svg class=\"chart-svg trend-svg\" viewBox=\"0 0 {d} {d}\" width=\"{d}\" height=\"{d}\" role=\"img\" aria-label=\"", .{ t.width, t.height, t.width, t.height });
    try html.text(w, t.aria);
    try w.writeAll("\">");
    // The grid, every step from 0 to the top, labelled; 0 is the axis, and 100% - the first
    // round's own level - the reference line.
    const steps: usize = @intFromFloat(@round(s.top / s.step));
    for (0..steps + 1) |k| {
        const v = s.step * @as(f64, @floatFromInt(k));
        const y = geo.y(v);
        const class = if (k == 0) "axis" else if (@abs(v - 1.0) < 1e-9) "ref" else "grid";
        try w.print("<line class=\"{s}\" x1=\"{d:.1}\" x2=\"{d:.1}\" y1=\"{d:.1}\" y2=\"{d:.1}\"/>", .{ class, pad.l, t.width - pad.r, y, y });
        try w.print("<text x=\"{d:.1}\" y=\"{d:.1}\" text-anchor=\"end\">", .{ pad.l - 6, y + 4 });
        try writePercent(w, v);
        try w.writeAll("</text>");
    }
    // The x labels: the round; under it its date and Crane's commit, where they fit.
    const full = n <= 1 or spacing >= full_label_spacing;
    const base = pad.t + ih;
    for (points, 0..) |p, i| {
        const x = geo.x(i);
        try w.print("<text class=\"x-round\" x=\"{d:.1}\" y=\"{d:.1}\" text-anchor=\"middle\">", .{ x, base + 17 });
        try html.text(w, p.label);
        try w.writeAll("</text>");
        if (!full) continue;
        if (p.date.len > 0) {
            try w.print("<text x=\"{d:.1}\" y=\"{d:.1}\" text-anchor=\"middle\">", .{ x, base + 32 });
            try html.text(w, p.date);
            try w.writeAll("</text>");
        }
        if (p.commit.len > 0) {
            try w.print("<text class=\"x-commit\" x=\"{d:.1}\" y=\"{d:.1}\" text-anchor=\"middle\">", .{ x, base + 46 });
            try html.text(w, p.commit);
            try w.writeAll("</text>");
        }
    }
    // ONE line through every round with a figure; a round without one breaks it.
    try w.writeAll("<path class=\"trend-line\" d=\"");
    var pen = false;
    for (t.values, 0..) |v, i| {
        const x = v orelse {
            pen = false;
            continue;
        };
        try w.print("{s}{d:.1} {d:.1}", .{ if (pen) " L" else if (i == 0) "M" else " M", geo.x(i), geo.y(x) });
        pen = true;
    }
    try w.writeAll("\"/>");
    // Each round's dot, its value above it, and its tooltip.
    for (t.values, 0..) |v, i| {
        const x = v orelse continue;
        const cx = geo.x(i);
        const cy = geo.y(x);
        try w.print("<g><circle class=\"hit\" cx=\"{d:.1}\" cy=\"{d:.1}\" r=\"10\"/><circle class=\"trend-dot\" cx=\"{d:.1}\" cy=\"{d:.1}\" r=\"4.5\"/>", .{ cx, cy, cx, cy });
        try w.print("<text class=\"trend-value\" x=\"{d:.1}\" y=\"{d:.1}\" text-anchor=\"middle\">", .{ cx, cy - 10 });
        try writePercent(w, x);
        try w.writeAll("</text><title>");
        try html.text(w, t.titles[i]);
        try w.writeAll("</title></g>");
    }
    try w.writeAll("</svg>");
}

/// One row's figure over the rounds: its own scale (min to max) and a dot on the latest
/// round. Nothing when fewer than two rounds have a figure.
const sw: f64 = 96;
const sh: f64 = 26;
const sp: f64 = 3;

pub fn sparkline(w: W, aria: []const u8, values: []const ?f64) !void {
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
    var prev: ?usize = null;
    for (values, 0..) |v, i| {
        const x = v orelse continue;
        if (prev) |j| try w.print("<line class=\"spark-line\" x1=\"{d:.1}\" x2=\"{d:.1}\" y1=\"{d:.1}\" y2=\"{d:.1}\"/>", .{
            sp + step * @as(f64, @floatFromInt(j)),
            sp + step * @as(f64, @floatFromInt(i)),
            y(values[j].?, lo, hi),
            y(x, lo, hi),
        });
        prev = i;
    }
    try w.print("<circle class=\"spark-dot\" cx=\"{d:.1}\" cy=\"{d:.1}\" r=\"2.5\"/>", .{ sp + step * @as(f64, @floatFromInt(last)), y(values[last].?, lo, hi) });
    try w.writeAll("</svg>");
}

const testing = std.testing;

test "Crane's trend: one line, each point labelled with its value, round 0's level the reference, no dashed segment" {
    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    const points = [_]Point{
        .{ .label = "Round 0", .date = "2026-11-06", .commit = "9b0f1b1f382" },
        .{ .label = "Round 1", .date = "2026-11-06", .commit = "0b6101f5f65" },
    };
    try trendChart(&out.writer, &points, .{ .aria = "Crane's time as a share of round 0's", .values = &.{ 1.0, 0.812 }, .titles = &.{ "a", "b" } });
    const svg = out.written();
    try testing.expect(std.mem.startsWith(u8, svg, "<svg class=\"chart-svg trend-svg\" viewBox=\"0 0 360 232\""));
    try testing.expect(std.mem.endsWith(u8, svg, "</svg>"));
    try testing.expect(std.mem.indexOf(u8, svg, "aria-label=\"Crane&#39;s time as a share of round 0&#39;s\"") != null);
    // ONE line: one path through every point.
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, svg, "class=\"trend-line\""));
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, svg, "<path"));
    // Each point labelled with its value, a dot and a tooltip each.
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, svg, "<text class=\"trend-value\""));
    try testing.expect(std.mem.indexOf(u8, svg, ">100%</text>") != null);
    try testing.expect(std.mem.indexOf(u8, svg, ">81%</text>") != null);
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, svg, "class=\"trend-dot\""));
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, svg, "<title>"));
    // The x labels: the round, the date, the commit.
    try testing.expect(std.mem.indexOf(u8, svg, ">Round 0</text>") != null);
    try testing.expect(std.mem.indexOf(u8, svg, ">Round 1</text>") != null);
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, svg, ">2026-11-06</text>"));
    try testing.expect(std.mem.indexOf(u8, svg, ">0b6101f5f65</text>") != null);
    // The scale: 0% to 100% in steps of 25%; 100% (round 0's level) is the reference line.
    try testing.expect(std.mem.indexOf(u8, svg, ">0%</text>") != null);
    try testing.expect(std.mem.indexOf(u8, svg, ">25%</text>") != null);
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, svg, "class=\"ref\""));
    // No dashed segment, no hollow point, no mark: a point is a round.
    try testing.expect(std.mem.indexOf(u8, svg, "dash") == null);
    try testing.expect(std.mem.indexOf(u8, svg, "step-target") == null);
    try testing.expect(std.mem.indexOf(u8, svg, "hollow") == null);
    try testing.expect(std.mem.indexOf(u8, svg, "mark-line") == null);
}

test "the trend's value labels: 100% and 81%, the whole percentage" {
    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    const points = [_]Point{ .{ .label = "Round 0" }, .{ .label = "Round 1" } };
    try trendChart(&out.writer, &points, .{ .aria = "t", .values = &.{ 1.0, 0.812 }, .titles = &.{ "a", "b" } });
    const svg = out.written();
    const first = std.mem.indexOf(u8, svg, "<text class=\"trend-value\"").?;
    try testing.expect(std.mem.indexOf(u8, svg[first..], ">100%</text>") != null);
    try testing.expect(std.mem.indexOf(u8, svg[first..], ">81%</text>") != null);
}

test "the scale: from 0 to 100% or the data's top, in whole steps" {
    try testing.expectEqual(Scale{ .top = 1.0, .step = 0.25 }, scaleOf(0.7));
    try testing.expectEqual(Scale{ .top = 1.0, .step = 0.25 }, scaleOf(1.0));
    try testing.expectEqual(Scale{ .top = 1.25, .step = 0.25 }, scaleOf(1.2));
    try testing.expectEqual(Scale{ .top = 2.0, .step = 0.5 }, scaleOf(1.7));
    try testing.expectEqual(Scale{ .top = 5.0, .step = 1.0 }, scaleOf(4.2));
    // A round that got slower reaches above 100%: the axis goes to its step.
    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    const points = [_]Point{ .{ .label = "Round 0" }, .{ .label = "Round 1" }, .{ .label = "Round 2" } };
    try trendChart(&out.writer, &points, .{ .aria = "m", .values = &.{ 1.0, 1.16, null }, .titles = &.{ "a", "b", "" } });
    const svg = out.written();
    try testing.expect(std.mem.indexOf(u8, svg, ">125%</text>") != null);
    try testing.expect(std.mem.indexOf(u8, svg, ">116%</text>") != null);
    // A round with no figure has no dot, no label, no tooltip.
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, svg, "class=\"trend-dot\""));
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, svg, "<title>"));
}

test "many rounds: an x label is the round alone where the date and commit would collide" {
    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    var points: [8]Point = undefined;
    var values: [8]?f64 = undefined;
    var titles: [8][]const u8 = undefined;
    const labels = [_][]const u8{ "Round 0", "Round 1", "Round 2", "Round 3", "Round 4", "Round 5", "Round 6", "Round 7" };
    for (&points, &values, &titles, labels, 0..) |*p, *v, *t, l, i| {
        p.* = .{ .label = l, .date = "2026-11-06", .commit = "0b6101f5f65" };
        v.* = 1.0 - 0.05 * @as(f64, @floatFromInt(i));
        t.* = "x";
    }
    try trendChart(&out.writer, &points, .{ .aria = "t", .values = &values, .titles = &titles });
    const svg = out.written();
    try testing.expectEqual(@as(usize, 8), std.mem.count(u8, svg, "class=\"x-round\""));
    try testing.expect(std.mem.indexOf(u8, svg, ">2026-11-06</text>") == null);
    try testing.expect(std.mem.indexOf(u8, svg, ">0b6101f5f65</text>") == null);
}

test "a sparkline: two rounds or more, the latest dotted, no dashed step" {
    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    try sparkline(&out.writer, "dom.a time", &.{ 40, 44, 20 });
    const svg = out.written();
    try testing.expect(std.mem.startsWith(u8, svg, "<svg class=\"chart-svg spark\""));
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, svg, "<line class=\"spark-line\""));
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, svg, "<circle"));
    try testing.expect(std.mem.indexOf(u8, svg, "step-target") == null);
    try testing.expect(std.mem.indexOf(u8, svg, "hollow") == null);
    try testing.expect(std.mem.indexOf(u8, svg, "mark-line") == null);
    // One figure: nothing to draw.
    var none: Io.Writer.Allocating = .init(testing.allocator);
    defer none.deinit();
    try sparkline(&none.writer, "x", &.{ 40, null, null });
    try testing.expectEqual(@as(usize, 0), none.written().len);
    // A flat row still draws, mid-height.
    var flat: Io.Writer.Allocating = .init(testing.allocator);
    defer flat.deinit();
    try sparkline(&flat.writer, "x", &.{ 10, 10 });
    try testing.expect(std.mem.indexOf(u8, flat.written(), "<line class=\"spark-line") != null);
}
