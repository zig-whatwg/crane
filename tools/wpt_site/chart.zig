//! The revision history as inline SVG, drawn by the generator: stacked bands
//! of files by standing, one x step per generation, oldest at the left. No
//! script: the numbers behind every generation are in the table beside it,
//! and each generation's column carries a native tooltip (`<title>`).

const std = @import("std");
const html = @import("html.zig");
const Io = std.Io;
const W = *Io.Writer;

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

    fn height(g: Generation) u64 {
        return @max(g.total, g.clean + g.partial + g.blocking + g.unrun);
    }
};

pub const Options = struct {
    width: u32,
    height: u32,
    /// The header's sparkline: bands only, no axes, no tooltips.
    spark: bool = false,
    class: []const u8 = "",
};

const Band = struct { class: []const u8, get: *const fn (Generation) u64 };
const bands = [_]Band{
    .{ .class = "band-clean", .get = struct {
        fn f(g: Generation) u64 {
            return g.clean;
        }
    }.f },
    .{ .class = "band-partial", .get = struct {
        fn f(g: Generation) u64 {
            return g.partial;
        }
    }.f },
    .{ .class = "band-blocking", .get = struct {
        fn f(g: Generation) u64 {
            return g.blocking;
        }
    }.f },
    .{ .class = "band-unrun", .get = struct {
        fn f(g: Generation) u64 {
            return g.unrun;
        }
    }.f },
};

/// The sum of the first `k` bands of `g`.
fn stacked(g: Generation, k: usize) u64 {
    var sum: u64 = 0;
    for (bands[0..k]) |b| sum += b.get(g);
    return sum;
}

const Pad = struct { l: f64, r: f64, t: f64, b: f64 };

/// "Files by standing over 85 generations, 19 September 2026 to 30 September
/// 2026: blocking went from 959 to 1,368, and clean files from 144 to 2,578."
pub fn summary(w: W, gens: []const Generation) Io.Writer.Error!void {
    if (gens.len == 0) return w.writeAll("No history yet.");
    const a = gens[0];
    const b = gens[gens.len - 1];
    try w.writeAll("Files by standing over ");
    try html.plural(w, gens.len, "generation", "generations");
    try w.writeAll(", ");
    try html.longDate(w, a.at);
    try w.writeAll(" to ");
    try html.longDate(w, b.at);
    try w.writeAll(": blocking went from ");
    try html.num(w, a.blocking);
    try w.writeAll(" to ");
    try html.num(w, b.blocking);
    try w.writeAll(", and clean files from ");
    try html.num(w, a.clean);
    try w.writeAll(" to ");
    try html.num(w, b.clean);
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
    try html.num(w, g.clean);
    try w.writeAll(" clean, ");
    try html.num(w, g.partial);
    try w.writeAll(" with failures, ");
    try html.num(w, g.blocking);
    try w.writeAll(" blocking");
    if (g.unrun > 0) {
        try w.writeAll(", ");
        try html.num(w, g.unrun);
        try w.writeAll(" not run");
    }
    try w.writeAll(" of ");
    try html.num(w, g.total);
    try w.writeAll(" files");
}

fn niceStep(max: u64) u64 {
    for ([_]u64{ 1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000, 100000 }) |s| {
        if (max / s <= 5) return s;
    }
    return @max(1, max / 5);
}

pub fn draw(w: W, gens: []const Generation, o: Options) Io.Writer.Error!void {
    const pad: Pad = if (o.spark) .{ .l = 0, .r = 0, .t = 1, .b = 0 } else .{ .l = 44, .r = 10, .t = 22, .b = 26 };
    const fw: f64 = @floatFromInt(o.width);
    const fh: f64 = @floatFromInt(o.height);
    const iw = fw - pad.l - pad.r;
    const ih = fh - pad.t - pad.b;
    try w.print("<svg class=\"{s}\" viewBox=\"0 0 {d} {d}\" width=\"{d}\" height=\"{d}\" role=\"img\" aria-label=\"", .{ o.class, o.width, o.height, o.width, o.height });
    try summary(w, gens);
    try w.writeAll("\">");
    if (gens.len == 0) return w.writeAll("</svg>");

    var max_t: u64 = 1;
    for (gens) |g| max_t = @max(max_t, g.height());
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
    const y: Y = .{ .pad = pad, .ih = ih, .max = @floatFromInt(max_t) };

    // Bands, bottom up: clean, with failures, blocking, not run.
    const count = gens.len;
    for (bands, 0..) |band, k| {
        try w.print("<path class=\"{s}\" d=\"", .{band.class});
        for (gens, 0..) |g, i| try w.print("{s}{d:.1},{d:.1}", .{ if (i == 0) "M" else "L", x.at(i), y.at(stacked(g, k + 1)) });
        var i = count;
        while (i > 0) {
            i -= 1;
            try w.print("L{d:.1},{d:.1}", .{ x.at(i), y.at(stacked(gens[i], k)) });
        }
        try w.writeAll("Z\"/>");
    }
    if (o.spark) return w.writeAll("</svg>");

    // Count ticks at the left.
    const base = pad.t + ih + 0.5;
    try w.print("<line class=\"axis\" x1=\"{d:.1}\" x2=\"{d:.1}\" y1=\"{d:.1}\" y2=\"{d:.1}\"/>", .{ pad.l, fw - pad.r, base, base });
    const step = niceStep(max_t);
    var v: u64 = 0;
    while (v <= max_t) : (v += step) {
        const yy = y.at(v);
        try w.print("<line class=\"axis\" x1=\"{d:.1}\" x2=\"{d:.1}\" y1=\"{d:.1}\" y2=\"{d:.1}\"/>", .{ pad.l - 3, pad.l, yy, yy });
        try w.print("<text x=\"{d:.1}\" y=\"{d:.1}\" text-anchor=\"end\">", .{ pad.l - 6, yy + 3.5 });
        try html.num(w, v);
        try w.writeAll("</text>");
    }
    // Day ticks along the bottom, a label wherever there is room for one.
    var last_x: f64 = -1e9;
    var last_day: ?html.Date = null;
    for (gens, 0..) |g, i| {
        const d = html.parseDate(g.at) orelse continue;
        if (last_day) |ld| if (ld.y == d.y and ld.m == d.m and ld.d == d.d) continue;
        last_day = d;
        const xx = x.at(i);
        try w.print("<line class=\"axis\" x1=\"{d:.1}\" x2=\"{d:.1}\" y1=\"{d:.1}\" y2=\"{d:.1}\"/>", .{ xx, xx, pad.t + ih, pad.t + ih + 4 });
        if (xx - last_x < 46 or xx > fw - pad.r - 14) continue;
        last_x = xx;
        try w.print("<text x=\"{d:.1}\" y=\"{d:.1}\" text-anchor=\"{s}\">", .{ xx, fh - 8, if (i == 0) "start" else "middle" });
        try html.shortDate(w, g.at);
        try w.writeAll("</text>");
    }
    // The two changes of rule.
    var live: ?usize = null;
    var rule2: ?usize = null;
    for (gens, 0..) |g, i| {
        if (live == null and !g.reconstructed) live = i;
        if (rule2 == null and g.gate_rule != null and g.gate_rule.? == 2) rule2 = i;
    }
    const marks = [_]struct { at: ?usize, label: []const u8, anchor: []const u8 }{
        .{ .at = live, .label = "live history begins", .anchor = "start" },
        .{ .at = rule2, .label = "NONE-PASSED blocks", .anchor = "end" },
    };
    for (marks) |m| {
        const i = m.at orelse continue;
        if (i == 0) continue;
        const xx = (x.at(i - 1) + x.at(i)) / 2;
        try w.print("<line class=\"mark-line\" x1=\"{d:.1}\" x2=\"{d:.1}\" y1=\"{d:.1}\" y2=\"{d:.1}\"/>", .{ xx, xx, pad.t - 4, pad.t + ih });
        const tx = if (std.mem.eql(u8, m.anchor, "end")) xx - 4 else xx + 4;
        try w.print("<text x=\"{d:.1}\" y=\"{d:.1}\" text-anchor=\"{s}\">{s}</text>", .{ tx, pad.t - 8, m.anchor, m.label });
    }
    // One column per generation, with its numbers as a native tooltip.
    const col = if (count > 1) iw / (n - 1) else iw;
    for (gens, 0..) |g, i| {
        const left = @max(pad.l, x.at(i) - col / 2);
        const right = @min(fw - pad.r, x.at(i) + col / 2);
        try w.print("<rect class=\"hit\" x=\"{d:.1}\" y=\"{d:.1}\" width=\"{d:.1}\" height=\"{d:.1}\"><title>", .{ left, pad.t, @max(0.5, right - left), ih });
        try describe(w, g);
        try w.writeAll("</title></rect>");
    }
    try w.writeAll("</svg>");
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

const two = [_]Generation{
    .{ .n = 1, .at = "2026-09-19T19:55:00", .reconstructed = true, .total = 10, .clean = 2, .partial = 3, .blocking = 1, .unrun = 4 },
    .{ .n = 2, .at = "2026-09-30T11:21:23", .head = "5c8dd64da", .gate_rule = 2, .total = 10, .clean = 5, .partial = 2, .blocking = 3 },
};

test "chart: bands, ticks, rule marks and one tooltip per generation" {
    var aw: Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    try draw(&aw.writer, &two, .{ .width = 480, .height = 240, .class = "chart-svg" });
    const svg = aw.written();
    try testing.expect(std.mem.startsWith(u8, svg, "<svg class=\"chart-svg\" viewBox=\"0 0 480 240\""));
    try testing.expect(std.mem.endsWith(u8, svg, "</svg>"));
    for ([_][]const u8{ "band-clean", "band-partial", "band-blocking", "band-unrun" }) |b| {
        try testing.expect(std.mem.indexOf(u8, svg, b) != null);
    }
    try testing.expect(std.mem.indexOf(u8, svg, ">19 Sep</text>") != null);
    try testing.expect(std.mem.indexOf(u8, svg, ">live history begins</text>") != null);
    try testing.expect(std.mem.indexOf(u8, svg, ">NONE-PASSED blocks</text>") != null);
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, svg, "<title>"));
    try testing.expect(std.mem.indexOf(u8, svg, "<title>Generation 2, 30 September 2026, Crane 5c8dd64da: 5 clean, 2 with failures, 3 blocking of 10 files</title>") != null);
    // No colour is written into the drawing: the bands take the page's tokens.
    try testing.expect(std.mem.indexOf(u8, svg, "#") == null);
}

test "chart: the sparkline is bands only, and an empty history draws nothing" {
    var aw: Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    try draw(&aw.writer, &two, .{ .width = 168, .height = 30, .spark = true, .class = "spark" });
    try testing.expect(std.mem.indexOf(u8, aw.written(), "<text") == null);
    try testing.expect(std.mem.indexOf(u8, aw.written(), "<title>") == null);
    aw.clearRetainingCapacity();
    try draw(&aw.writer, &.{}, .{ .width = 168, .height = 30, .spark = true });
    try testing.expect(std.mem.indexOf(u8, aw.written(), "No history yet.") != null);
    try testing.expect(std.mem.indexOf(u8, aw.written(), "<path") == null);
}
