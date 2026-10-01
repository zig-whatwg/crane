//! The revision history as inline SVG, drawn by the generator: WPT subtests
//! passing and not passing, stacked up to the total, one x step per
//! generation, oldest at the left. It is what a reader without script sees;
//! site.js redraws the same numbers, read from the table beside it, as an
//! interactive chart. Each generation's column carries a native tooltip.

const std = @import("std");
const html = @import("html.zig");
const Io = std.Io;
const W = *Io.Writer;

/// The subtest sums of one generation, exactly as the site's headline counts
/// them: every worklist file's journal record, whatever its status.
pub const Subs = struct {
    passed: u64 = 0,
    failed: u64 = 0,
    timed_out: u64 = 0,
    notrun: u64 = 0,

    pub fn total(s: Subs) u64 {
        return s.passed + s.failed + s.timed_out + s.notrun;
    }
};

/// One generation of wpt-results/progress-history.json.
pub const Generation = struct {
    n: u64 = 0,
    at: []const u8 = "",
    head: []const u8 = "?",
    reconstructed: bool = false,
    gate_rule: ?u64 = null,
    total: u64 = 0,
    run: u64 = 0,
    unrun: u64 = 0,
    blocking: u64 = 0,
    crash: u64 = 0,
    timeout: u64 = 0,
    @"error": u64 = 0,
    none_passed: ?u64 = null,
    clean: u64 = 0,
    partial: u64 = 0,
    /// Journal sums over files that finished OK (and, from gate rule 2, NONE-PASSED).
    sub_pass: u64 = 0,
    sub_fail: u64 = 0,
    /// The progress report's model: subtests passing, and subtests known to
    /// exist - which estimates files that reported none.
    sub_passing: ?u64 = null,
    sub_targeted: ?u64 = null,
    /// Recorded from 2026-09-30: the headline's own sums.
    subs: ?Subs = null,

    /// WPT subtests passing.
    pub fn passing(g: Generation) u64 {
        if (g.subs) |s| return s.passed;
        return g.sub_passing orelse g.sub_pass;
    }

    /// WPT subtests in all: exact when the generation recorded its sums,
    /// otherwise the report's count of those known to exist.
    pub fn subTotal(g: Generation) u64 {
        if (g.subs) |s| return s.total();
        return @max(g.sub_targeted orelse (g.sub_pass + g.sub_fail), g.passing());
    }

    /// The total is an estimate, not a sum of reported results.
    pub fn estimated(g: Generation) bool {
        return g.subs == null;
    }
};

/// A change in how the history was measured, marked where it lands. Keyed by
/// generation number: the history is append-only, so the numbers are stable
/// (a `rebuild_history` renumbers them, and these must then be re-placed).
pub const Event = struct { n: u64, label: []const u8 };

pub const events = [_]Event{
    // 71ffd213a: the navigated URL reaches location.*, so each ?variant of a
    // test runs its own slice. Generation 19 is the first sweep after it.
    .{ .n = 19, .label = "variant URLs reach the page" },
    // 98c4117d5: the progress report counts each variant run as its own test.
    .{ .n = 75, .label = "each variant counted as a test" },
    // The WPT snapshot moved to upstream afe89a5df4: 4,319 files to 4,712.
    .{ .n = 85, .label = "new WPT snapshot" },
    // The 0.1 scope adds tier 1 and tier 2 suites (the user, 2026-10-01): 4,712 files to 10,035.
    .{ .n = 96, .label = "0.1 scope: 10,035 files" },
};

pub fn eventAt(list: []const Event, n: u64) ?[]const u8 {
    for (list) |e| if (e.n == n) return e.label;
    return null;
}

pub const Options = struct {
    width: u32,
    height: u32,
    /// The header's sparkline: bands only, no axes, no tooltips.
    spark: bool = false,
    class: []const u8 = "",
    events: []const Event = &events,
};

const Pad = struct { l: f64, r: f64, t: f64, b: f64 };

fn writeOf(w: W, g: Generation) Io.Writer.Error!void {
    try html.num(w, g.passing());
    try w.writeAll(if (g.estimated()) " of about " else " of ");
    try html.num(w, g.subTotal());
}

/// "WPT subtests passing over 86 generations, 19 September 2026 to 30
/// September 2026: from 13,763 of about 188,338 to 1,288,088 of 1,333,081."
pub fn summary(w: W, gens: []const Generation) Io.Writer.Error!void {
    if (gens.len == 0) return w.writeAll("No history yet.");
    const a = gens[0];
    const b = gens[gens.len - 1];
    try w.writeAll("WPT subtests passing over ");
    try html.plural(w, gens.len, "generation", "generations");
    try w.writeAll(", ");
    try html.longDate(w, a.at);
    try w.writeAll(" to ");
    try html.longDate(w, b.at);
    try w.writeAll(": from ");
    try writeOf(w, a);
    try w.writeAll(" to ");
    try writeOf(w, b);
    try w.writeAll(".");
}

/// One generation in words, for its tooltip and nothing else.
pub fn describe(w: W, g: Generation) Io.Writer.Error!void {
    try w.print("Generation {d}, ", .{g.n});
    try html.longDate(w, g.at);
    if (g.head.len > 0 and !std.mem.eql(u8, g.head, "?")) {
        try w.writeAll(", Crane ");
        try html.text(w, g.head);
    }
    if (g.reconstructed) try w.writeAll(" (reconstructed)");
    try w.writeAll(": ");
    try writeOf(w, g);
    try w.writeAll(" WPT subtests passing");
}

/// A round step giving about five ticks up to `max`.
pub fn niceStep(max: u64) u64 {
    var mag: u64 = 1;
    while (mag * 10 <= max) mag *= 10;
    for ([_]u64{ 1, 2, 5, 10 }) |k| {
        const s = @max(1, mag * k / 10);
        if (max / s <= 6) return s;
    }
    return mag;
}

pub fn draw(w: W, gens: []const Generation, o: Options) Io.Writer.Error!void {
    const pad: Pad = if (o.spark) .{ .l = 0, .r = 0, .t = 1, .b = 0 } else .{ .l = 64, .r = 10, .t = 22, .b = 26 };
    const fw: f64 = @floatFromInt(o.width);
    const fh: f64 = @floatFromInt(o.height);
    const iw = fw - pad.l - pad.r;
    const ih = fh - pad.t - pad.b;
    try w.print("<svg class=\"{s}\" viewBox=\"0 0 {d} {d}\" width=\"{d}\" height=\"{d}\" role=\"img\" aria-label=\"", .{ o.class, o.width, o.height, o.width, o.height });
    try summary(w, gens);
    try w.writeAll("\">");
    if (gens.len == 0) return w.writeAll("</svg>");

    var max_t: u64 = 1;
    for (gens) |g| max_t = @max(max_t, g.subTotal());
    const step = niceStep(max_t);
    const top = if (o.spark) max_t else (max_t + step - 1) / step * step;
    const n: f64 = @floatFromInt(gens.len);
    const X = struct {
        pad: Pad,
        iw: f64,
        n: f64,
        fn at(s: @This(), i: usize) f64 {
            if (s.n <= 1) return s.pad.l + s.iw / 2;
            return s.pad.l + @as(f64, @floatFromInt(i)) / (s.n - 1) * s.iw;
        }
    };
    const x: X = .{ .pad = pad, .iw = iw, .n = n };
    const Y = struct {
        pad: Pad,
        ih: f64,
        max: f64,
        fn at(s: @This(), v: u64) f64 {
            return s.pad.t + s.ih - @as(f64, @floatFromInt(v)) / s.max * s.ih;
        }
    };
    const y: Y = .{ .pad = pad, .ih = ih, .max = @floatFromInt(top) };

    // Passing from zero; not passing from passing up to the total.
    const count = gens.len;
    try w.writeAll("<path class=\"band-pass\" d=\"");
    for (gens, 0..) |g, i| try w.print("{s}{d:.1},{d:.1}", .{ if (i == 0) "M" else "L", x.at(i), y.at(g.passing()) });
    try w.print("L{d:.1},{d:.1}L{d:.1},{d:.1}Z\"/>", .{ x.at(count - 1), y.at(0), x.at(0), y.at(0) });
    try w.writeAll("<path class=\"band-fail\" d=\"");
    for (gens, 0..) |g, i| try w.print("{s}{d:.1},{d:.1}", .{ if (i == 0) "M" else "L", x.at(i), y.at(g.subTotal()) });
    var i = count;
    while (i > 0) {
        i -= 1;
        try w.print("L{d:.1},{d:.1}", .{ x.at(i), y.at(gens[i].passing()) });
    }
    try w.writeAll("Z\"/>");
    if (o.spark) return w.writeAll("</svg>");
    try w.writeAll("<path class=\"line-total\" d=\"");
    for (gens, 0..) |g, k| try w.print("{s}{d:.1},{d:.1}", .{ if (k == 0) "M" else "L", x.at(k), y.at(g.subTotal()) });
    try w.writeAll("\"/>");

    // Subtest ticks at the left.
    const base = pad.t + ih + 0.5;
    try w.print("<line class=\"axis\" x1=\"{d:.1}\" x2=\"{d:.1}\" y1=\"{d:.1}\" y2=\"{d:.1}\"/>", .{ pad.l, fw - pad.r, base, base });
    var v: u64 = 0;
    while (v <= top) : (v += step) {
        const yy = y.at(v);
        if (v > 0) try w.print("<line class=\"grid\" x1=\"{d:.1}\" x2=\"{d:.1}\" y1=\"{d:.1}\" y2=\"{d:.1}\"/>", .{ pad.l, fw - pad.r, yy, yy });
        try w.print("<text x=\"{d:.1}\" y=\"{d:.1}\" text-anchor=\"end\">", .{ pad.l - 6, yy + 3.5 });
        try html.num(w, v);
        try w.writeAll("</text>");
    }
    // Day ticks along the bottom, a label wherever there is room for one.
    var last_x: f64 = -1e9;
    var last_day: ?html.Date = null;
    for (gens, 0..) |g, k| {
        const d = html.parseDate(g.at) orelse continue;
        if (last_day) |ld| if (ld.y == d.y and ld.m == d.m and ld.d == d.d) continue;
        last_day = d;
        const xx = x.at(k);
        try w.print("<line class=\"axis\" x1=\"{d:.1}\" x2=\"{d:.1}\" y1=\"{d:.1}\" y2=\"{d:.1}\"/>", .{ xx, xx, pad.t + ih, pad.t + ih + 4 });
        if (xx - last_x < 46 or xx > fw - pad.r - 14) continue;
        last_x = xx;
        try w.print("<text x=\"{d:.1}\" y=\"{d:.1}\" text-anchor=\"{s}\">", .{ xx, fh - 8, if (k == 0) "start" else "middle" });
        try html.shortDate(w, g.at);
        try w.writeAll("</text>");
    }
    // Where the live history begins, and each change of measurement.
    var live: ?usize = null;
    for (gens, 0..) |g, k| if (live == null and !g.reconstructed) {
        live = k;
    };
    if (live) |k| if (k > 0) try mark(w, x.at(k - 1), x.at(k), pad, ih, "live history begins", "start");
    for (gens, 0..) |g, k| {
        if (k == 0) continue;
        const label = eventAt(o.events, g.n) orelse continue;
        try mark(w, x.at(k - 1), x.at(k), pad, ih, label, "end");
    }
    // One column per generation, with its numbers as a native tooltip.
    const col = if (count > 1) iw / (n - 1) else iw;
    for (gens, 0..) |g, k| {
        const left = @max(pad.l, x.at(k) - col / 2);
        const right = @min(fw - pad.r, x.at(k) + col / 2);
        try w.print("<rect class=\"hit\" x=\"{d:.1}\" y=\"{d:.1}\" width=\"{d:.1}\" height=\"{d:.1}\"><title>", .{ left, pad.t, @max(0.5, right - left), ih });
        try describe(w, g);
        try w.writeAll("</title></rect>");
    }
    try w.writeAll("</svg>");
}

fn mark(w: W, x0: f64, x1: f64, pad: Pad, ih: f64, label: []const u8, anchor: []const u8) Io.Writer.Error!void {
    const xx = (x0 + x1) / 2;
    try w.print("<line class=\"mark-line\" x1=\"{d:.1}\" x2=\"{d:.1}\" y1=\"{d:.1}\" y2=\"{d:.1}\"/>", .{ xx, xx, pad.t - 4, pad.t + ih });
    const tx = if (std.mem.eql(u8, anchor, "end")) xx - 4 else xx + 4;
    try w.print("<text x=\"{d:.1}\" y=\"{d:.1}\" text-anchor=\"{s}\">", .{ tx, pad.t - 8, anchor });
    try html.text(w, label);
    try w.writeAll("</text>");
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

const two = [_]Generation{
    .{ .n = 1, .at = "2026-09-19T19:55:00", .reconstructed = true, .total = 10, .clean = 2, .partial = 3, .blocking = 1, .unrun = 4, .sub_passing = 400, .sub_targeted = 1000 },
    .{ .n = 2, .at = "2026-09-30T11:21:23", .head = "5c8dd64da", .gate_rule = 2, .total = 10, .clean = 5, .partial = 2, .blocking = 3, .subs = .{ .passed = 1200, .failed = 250, .timed_out = 30, .notrun = 20 } },
};
const two_events = [_]Event{.{ .n = 2, .label = "each variant counted as a test" }};

test "generation: subtests passing and total, exact when recorded, the report's estimate before" {
    try testing.expectEqual(@as(u64, 400), two[0].passing());
    try testing.expectEqual(@as(u64, 1000), two[0].subTotal());
    try testing.expect(two[0].estimated());
    try testing.expectEqual(@as(u64, 1200), two[1].passing());
    try testing.expectEqual(@as(u64, 1500), two[1].subTotal());
    try testing.expect(!two[1].estimated());
    // A generation older than both: the journal sums it always carried.
    const old: Generation = .{ .sub_pass = 7, .sub_fail = 3 };
    try testing.expectEqual(@as(u64, 7), old.passing());
    try testing.expectEqual(@as(u64, 10), old.subTotal());
    try testing.expect(old.estimated());
}

test "chart: subtests passing and not passing, the total, ticks, events and one tooltip per generation" {
    var aw: Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    try draw(&aw.writer, &two, .{ .width = 480, .height = 240, .class = "chart-svg", .events = &two_events });
    const svg = aw.written();
    try testing.expect(std.mem.startsWith(u8, svg, "<svg class=\"chart-svg\" viewBox=\"0 0 480 240\""));
    try testing.expect(std.mem.endsWith(u8, svg, "</svg>"));
    for ([_][]const u8{ "band-pass", "band-fail", "line-total" }) |b| {
        try testing.expect(std.mem.indexOf(u8, svg, b) != null);
    }
    try testing.expect(std.mem.indexOf(u8, svg, "band-clean") == null);
    try testing.expect(std.mem.indexOf(u8, svg, ">19 Sep</text>") != null);
    // Subtest ticks: 0 up past 1,500.
    try testing.expect(std.mem.indexOf(u8, svg, ">1,500</text>") != null);
    try testing.expect(std.mem.indexOf(u8, svg, ">live history begins</text>") != null);
    try testing.expect(std.mem.indexOf(u8, svg, ">each variant counted as a test</text>") != null);
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, svg, "<title>"));
    try testing.expect(std.mem.indexOf(u8, svg, "<title>Generation 2, 30 September 2026, Crane 5c8dd64da: 1,200 of 1,500 WPT subtests passing</title>") != null);
    try testing.expect(std.mem.indexOf(u8, svg, "<title>Generation 1, 19 September 2026 (reconstructed): 400 of about 1,000 WPT subtests passing</title>") != null);
    try testing.expect(std.mem.indexOf(u8, svg, "aria-label=\"WPT subtests passing over 2 generations, 19 September 2026 to 30 September 2026: from 400 of about 1,000 to 1,200 of 1,500.\"") != null);
    // No colour is written into the drawing: the bands take the page's tokens.
    try testing.expect(std.mem.indexOf(u8, svg, "#") == null);
}

test "chart: the sparkline is bands only, and an empty history draws nothing" {
    var aw: Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    try draw(&aw.writer, &two, .{ .width = 168, .height = 30, .spark = true, .class = "spark" });
    try testing.expect(std.mem.indexOf(u8, aw.written(), "band-pass") != null);
    try testing.expect(std.mem.indexOf(u8, aw.written(), "<text") == null);
    try testing.expect(std.mem.indexOf(u8, aw.written(), "<title>") == null);
    aw.clearRetainingCapacity();
    try draw(&aw.writer, &.{}, .{ .width = 168, .height = 30, .spark = true });
    try testing.expect(std.mem.indexOf(u8, aw.written(), "No history yet.") != null);
    try testing.expect(std.mem.indexOf(u8, aw.written(), "<path") == null);
}
