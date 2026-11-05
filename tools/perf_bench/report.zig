//! /performance/: the report of every perf round, written as finished HTML
//! from the journals (the results-site rules: the content is in the HTML;
//! no script is needed to read it). Published beside the WPT site on
//! gh-pages, under performance/, with the WPT site's stylesheet.
//!
//! What the page shows, from the journals alone:
//!   - the headline: this round's Crane against each browser, time and
//!     memory, as the geometric mean over the workloads both ran of Crane's
//!     figure as a percentage of the browser's (lower is better for Crane);
//!   - the engines: each one's version, build and launch flags;
//!   - this round, workload by workload: each engine's median time and
//!     memory, and Crane's ratio to each browser;
//!   - the history: each workload's figures round by round, a browser's by
//!     version (an updated browser is a new data point);
//!   - the Crane-only rows (gc_bench), round by round;
//!   - Open Graph and Twitter summary_large_image metadata with the
//!     headline, and the 1200x630 card (card.zig).
//!
//! Medians, not means (a page's samples and a run's launches both have
//! outliers): a run's figure is the median of its samples; a cell's, the
//! median of its runs' figures, with the runs' spread (relative MAD).

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const html = @import("site_html");
const journal = @import("journal.zig");
const stats = @import("stats.zig");
const card = @import("card.zig");

const W = *Io.Writer;
const Error = Io.Writer.Error;
const EngineName = journal.EngineName;

pub const browsers = [_]EngineName{ .chrome, .firefox, .safari, .lightpanda };

/// One (round, engine, version, workload): every run's records, summarised.
pub const Cell = struct {
    round: u32,
    engine: EngineName,
    version: []const u8,
    workload: []const u8,
    page: []const u8,
    kind: journal.Kind,
    runs: u32 = 0,
    ok: u32 = 0,
    /// A failure's status and message (the last one seen), for a cell with
    /// no ok run.
    failure: ?journal.Status = null,
    message: ?[]const u8 = null,
    ops: u64 = 0,
    /// Median over runs of each run's median sample, ms.
    time_ms: ?f64 = null,
    /// Relative MAD of the runs' medians.
    spread: ?f64 = null,
    cpu_ms: ?f64 = null,
    instructions: ?u64 = null,
    /// Median over runs of the footprint at the end (bytes).
    footprint: ?u64 = null,
    peak: ?u64 = null,
    /// chain and instances: bytes per step or per instance (median slope).
    growth: ?f64 = null,
    /// gc_bench rows: their counters (median over runs), by name.
    counters: []const journal.Counter = &.{},
    /// The newest record's time: which version of an engine is current.
    latest_time: []const u8 = "",
    engine_info: journal.Engine,
    host: journal.Host,

    /// Time per operation, microseconds (timed rows).
    pub fn perOpUs(c: Cell) ?f64 {
        const t = c.time_ms orelse return null;
        if (c.kind != .timed or c.ops == 0) return t * 1000.0;
        return t * 1000.0 / @as(f64, @floatFromInt(c.ops));
    }

    /// The figure compared for time: per op for a timed row, per sample
    /// otherwise.
    pub fn timeFigure(c: Cell) ?f64 {
        if (c.ok == 0) return null;
        return switch (c.kind) {
            .timed => c.perOpUs(),
            .chain, .startup, .gc_bench => c.time_ms,
            .idle, .instances => null,
        };
    }

    /// The figure compared for memory: growth for the growth rows, the
    /// footprint otherwise.
    pub fn memoryFigure(c: Cell) ?f64 {
        if (c.ok == 0) return null;
        if (c.kind == .instances or std.mem.eql(u8, c.workload, "memory.page-growth")) {
            const g = c.growth orelse return null;
            return if (g > 0) g else null;
        }
        if (c.kind == .startup) return null;
        const f = c.footprint orelse return null;
        return @floatFromInt(f);
    }
};

pub const Model = struct {
    cells: []Cell,
    rounds: []u32,
    latest_round: u32,

    /// The cell of `engine` for `workload` in `round`, at the engine's newest
    /// version there.
    pub fn current(m: *const Model, round: u32, engine: EngineName, workload: []const u8) ?*const Cell {
        var best: ?*const Cell = null;
        for (m.cells) |*c| {
            if (c.round != round or c.engine != engine or !std.mem.eql(u8, c.workload, workload)) continue;
            if (best == null or std.mem.order(u8, c.latest_time, best.?.latest_time) == .gt) best = c;
        }
        return best;
    }

    /// The workloads of `round`, in their first appearance's order.
    pub fn workloads(m: *const Model, arena: Allocator, round: u32) ![]const []const u8 {
        var out: std.ArrayList([]const u8) = .empty;
        for (m.cells) |c| {
            if (c.round != round) continue;
            const seen = for (out.items) |w| {
                if (std.mem.eql(u8, w, c.workload)) break true;
            } else false;
            if (!seen) try out.append(arena, c.workload);
        }
        return out.items;
    }
};

fn eqlCellKey(c: Cell, r: journal.Record) bool {
    return c.round == r.round and c.engine == r.engine.name and std.mem.eql(u8, c.version, r.engine.version) and std.mem.eql(u8, c.workload, r.workload);
}

/// The model of `records` (all rounds).
pub fn build(arena: Allocator, records: []const journal.Record) !Model {
    var cells: std.ArrayList(Cell) = .empty;
    var groups: std.ArrayList(std.ArrayList(journal.Record)) = .empty;
    for (records) |r| {
        const i = for (cells.items, 0..) |c, i| {
            if (eqlCellKey(c, r)) break i;
        } else blk: {
            try cells.append(arena, .{
                .round = r.round,
                .engine = r.engine.name,
                .version = r.engine.version,
                .workload = r.workload,
                .page = r.page,
                .kind = r.kind,
                .engine_info = r.engine,
                .host = r.host,
            });
            try groups.append(arena, .empty);
            break :blk cells.items.len - 1;
        };
        try groups.items[i].append(arena, r);
    }
    for (cells.items, groups.items) |*c, g| try summarise(arena, c, g.items);

    var rounds: std.ArrayList(u32) = .empty;
    for (cells.items) |c| if (std.mem.indexOfScalar(u32, rounds.items, c.round) == null) try rounds.append(arena, c.round);
    std.mem.sort(u32, rounds.items, {}, std.sort.asc(u32));
    return .{ .cells = cells.items, .rounds = rounds.items, .latest_round = if (rounds.items.len > 0) rounds.items[rounds.items.len - 1] else 0 };
}

fn summarise(arena: Allocator, c: *Cell, runs: []const journal.Record) !void {
    var times: std.ArrayList(f64) = .empty;
    var cpus: std.ArrayList(f64) = .empty;
    var ins: std.ArrayList(u64) = .empty;
    var foot: std.ArrayList(u64) = .empty;
    var peak: std.ArrayList(u64) = .empty;
    var growth: std.ArrayList(f64) = .empty;
    var counter_names: std.ArrayList([]const u8) = .empty;
    for (runs) |r| {
        c.runs += 1;
        if (std.mem.order(u8, r.time, c.latest_time) == .gt) {
            c.latest_time = r.time;
            c.engine_info = r.engine;
            c.host = r.host;
        }
        if (r.status != .ok) {
            c.failure = r.status;
            c.message = r.message;
            continue;
        }
        c.ok += 1;
        c.ops = r.ops;
        if (try stats.median(arena, r.wall_ms)) |m| try times.append(arena, m);
        if (r.cpu_ms) |v| try cpus.append(arena, v);
        if (r.instructions) |v| try ins.append(arena, v);
        if (r.memory) |m| {
            try foot.append(arena, m.footprint_end);
            try peak.append(arena, m.footprint_peak);
        }
        if (stats.slope(r.series)) |s| try growth.append(arena, s);
        for (r.counters) |k| if (!containsStr(counter_names.items, k.name)) try counter_names.append(arena, k.name);
    }
    c.time_ms = try stats.median(arena, times.items);
    c.spread = try stats.relativeMad(arena, times.items);
    c.cpu_ms = try stats.median(arena, cpus.items);
    c.instructions = try stats.medianU64(arena, ins.items);
    c.footprint = try stats.medianU64(arena, foot.items);
    c.peak = try stats.medianU64(arena, peak.items);
    c.growth = try stats.median(arena, growth.items);
    var counters: std.ArrayList(journal.Counter) = .empty;
    for (counter_names.items) |name| {
        var vals: std.ArrayList(f64) = .empty;
        for (runs) |r| {
            if (r.status != .ok) continue;
            for (r.counters) |k| if (std.mem.eql(u8, k.name, name)) try vals.append(arena, k.value);
        }
        if (try stats.median(arena, vals.items)) |m| try counters.append(arena, .{ .name = name, .value = m });
    }
    c.counters = counters.items;
}

fn containsStr(list: []const []const u8, s: []const u8) bool {
    for (list) |x| if (std.mem.eql(u8, x, s)) return true;
    return false;
}

/// Crane against one browser in one round: the geometric mean over the
/// workloads both ran of Crane's figure over the browser's.
pub const Versus = struct {
    browser: EngineName,
    version: ?[]const u8 = null,
    time_ratio: ?f64 = null,
    time_n: usize = 0,
    memory_ratio: ?f64 = null,
    memory_n: usize = 0,
};

/// Whether a workload counts in the headline: start-up and the harness's own
/// floor are rows of their own, so the headline compares engine work, not
/// launchers or the harness (the integrator, 2026-11-05).
pub fn inHeadline(workload: []const u8) bool {
    return !std.mem.startsWith(u8, workload, "startup.") and !std.mem.startsWith(u8, workload, "overhead.");
}

pub fn versus(arena: Allocator, m: *const Model, round: u32, browser: EngineName) !Versus {
    var v: Versus = .{ .browser = browser };
    var t: std.ArrayList(f64) = .empty;
    var mem: std.ArrayList(f64) = .empty;
    for (try m.workloads(arena, round)) |w| {
        if (!inHeadline(w)) continue;
        const b = m.current(round, browser, w) orelse continue;
        v.version = b.version;
        const c = m.current(round, .crane, w) orelse continue;
        if (c.timeFigure()) |ct| if (b.timeFigure()) |bt| if (bt > 0) try t.append(arena, ct / bt);
        if (c.memoryFigure()) |cm| if (b.memoryFigure()) |bm| if (bm > 0) try mem.append(arena, cm / bm);
    }
    v.time_ratio = stats.geometricMean(t.items);
    v.time_n = t.items.len;
    v.memory_ratio = stats.geometricMean(mem.items);
    v.memory_n = mem.items.len;
    return v;
}

/// A ratio as a whole percentage ("54"), for the card and the headline.
pub fn percent(ratio: f64) u64 {
    return @intFromFloat(@round(ratio * 100.0));
}

// ============================================================================
// Writing
// ============================================================================

pub const Options = struct {
    /// The site's URL, ending in '/': og:url and og:image are absolute.
    site_url: []const u8 = "https://zig-whatwg.github.io/crane/",
    /// How the page reaches the WPT site's stylesheet and fonts.
    assets: []const u8 = "../",
};

/// Every file of /performance/ for `m`: name -> bytes.
pub const Output = struct {
    index_html: []const u8,
    card_png: []const u8,
};

pub fn render(arena: Allocator, m: *const Model, o: Options) !Output {
    var vs: [browsers.len]Versus = undefined;
    for (browsers, 0..) |b, i| vs[i] = try versus(arena, m, m.latest_round, b);
    var figures: card.Figures = .{ .round = m.latest_round };
    for (vs, 0..) |v, i| {
        figures.time[i] = if (v.time_ratio) |r| percent(r) else null;
        figures.memory[i] = if (v.memory_ratio) |r| percent(r) else null;
    }
    const png = try card.render(arena, figures);
    const card_ref = try std.fmt.allocPrint(arena, "card.png?v={x:0>8}", .{@as(u32, @truncate(std.hash.Wyhash.hash(0, png)))});

    var out: Io.Writer.Allocating = .init(arena);
    const w = &out.writer;
    try writePage(w, arena, m, &vs, o, card_ref);
    return .{ .index_html = out.written(), .card_png = png };
}

fn writePage(w: W, arena: Allocator, m: *const Model, vs: []const Versus, o: Options, card_ref: []const u8) !void {
    try w.writeAll(
        \\<!doctype html>
        \\<html lang="en">
        \\<head>
        \\<meta charset="utf-8">
        \\<meta name="viewport" content="width=device-width, initial-scale=1">
        \\
    );
    try w.print("<title>Crane performance: round {d}</title>\n<meta name=\"description\" content=\"", .{m.latest_round});
    try writeDescription(w, m, vs);
    try w.writeAll("\">\n<meta name=\"color-scheme\" content=\"light dark\">\n");
    try w.print("<link rel=\"stylesheet\" href=\"{s}site.css\">\n<link rel=\"icon\" href=\"data:,\">\n", .{o.assets});
    try writeSocial(w, m, vs, o, card_ref);
    try w.writeAll(style);
    try w.writeAll("</head>\n<body>\n<main class=\"doc perf\" id=\"main\">\n<header class=\"head\">\n<h1>Crane <span class=\"h1-rest\">Performance</span></h1>\n");
    try w.print("<p class=\"subtitle\">Round {d}: Crane beside Chrome, Firefox, Safari and Lightpanda, the same pages in every engine, CPU and memory.", .{m.latest_round});
    if (hostOf(m)) |h| {
        try w.writeAll(" Measured on ");
        try html.text(w, h.cpu);
        try w.print(", {d} cores, ", .{h.cores});
        try html.text(w, h.os);
        try w.writeAll(".");
    }
    try w.print(" <a href=\"{s}\">WPT results</a>.</p>\n</header>\n", .{o.assets});

    try writeHeadline(w, vs);
    try writeEngines(w, arena, m);
    try writeRound(w, arena, m);
    try writeHistory(w, arena, m);
    try writeCraneOnly(w, arena, m);
    try writeMethod(w);
    try w.writeAll("<footer class=\"foot\"><p>Written as HTML by <code>tools/perf_bench</code> from the benchmark journals (docs/performance.md).</p></footer>\n</main>\n</body>\n</html>\n");
}

const style =
    \\<style>
    \\.perf { margin: 0 auto; }
    \\.perf h2 { margin-top: 2.2rem; }
    \\.perf .ratio-good { color: var(--pass, #2e7d32); }
    \\.perf .ratio-bad { color: var(--fail, #b3261e); }
    \\.perf .fail { color: var(--fail, #b3261e); }
    \\.perf td.flags code { font-size: 0.78rem; overflow-wrap: anywhere; }
    \\.perf .listing tbody th { width: auto; }
    \\.perf .listing thead th { padding: 0.32rem 0.75rem; }
    \\</style>
    \\
;

fn hostOf(m: *const Model) ?journal.Host {
    for (m.cells) |c| if (c.round == m.latest_round) return c.host;
    return null;
}

fn writeDescription(w: W, m: *const Model, vs: []const Versus) !void {
    try w.print("Crane performance, round {d}: ", .{m.latest_round});
    var any = false;
    for (vs) |v| {
        const t = v.time_ratio orelse continue;
        if (any) try w.writeAll("; ");
        any = true;
        try w.print("{d}% of {s}'s time", .{ percent(t), v.browser.label() });
        if (v.memory_ratio) |mr| try w.print(" and {d}% of its memory", .{percent(mr)});
    }
    if (!any) try w.writeAll("no browser comparison yet");
    try w.writeAll(" (geometric means over the workloads both ran; lower is better for Crane). Crane is a headless web platform engine in Zig.");
}

fn writeSocial(w: W, m: *const Model, vs: []const Versus, o: Options, card_ref: []const u8) !void {
    try w.writeAll("<link rel=\"canonical\" href=\"");
    try html.text(w, o.site_url);
    try w.writeAll("performance/\">\n<meta property=\"og:type\" content=\"website\">\n<meta property=\"og:site_name\" content=\"Crane\">\n");
    try w.print("<meta property=\"og:title\" content=\"Crane performance: round {d}\">\n<meta property=\"og:description\" content=\"", .{m.latest_round});
    try writeDescription(w, m, vs);
    try w.writeAll("\">\n<meta property=\"og:url\" content=\"");
    try html.text(w, o.site_url);
    try w.writeAll("performance/\">\n<meta property=\"og:image\" content=\"");
    try html.text(w, o.site_url);
    try w.writeAll("performance/");
    try html.text(w, card_ref);
    try w.writeAll("\">\n<meta property=\"og:image:type\" content=\"image/png\">\n<meta property=\"og:image:width\" content=\"1200\">\n<meta property=\"og:image:height\" content=\"630\">\n");
    try w.writeAll("<meta property=\"og:image:alt\" content=\"Crane's time and memory as a percentage of Chrome's, Firefox's, Safari's and Lightpanda's.\">\n");
    try w.print("<meta name=\"twitter:card\" content=\"summary_large_image\">\n<meta name=\"twitter:title\" content=\"Crane performance: round {d}\">\n<meta name=\"twitter:description\" content=\"", .{m.latest_round});
    try writeDescription(w, m, vs);
    try w.writeAll("\">\n<meta name=\"twitter:image\" content=\"");
    try html.text(w, o.site_url);
    try w.writeAll("performance/");
    try html.text(w, card_ref);
    try w.writeAll("\">\n");
}

fn ratioClass(r: f64) []const u8 {
    return if (r <= 1.0) "ratio-good" else "ratio-bad";
}

fn writeHeadline(w: W, vs: []const Versus) !void {
    try w.writeAll("<section id=\"headline\"><h2>Crane against each browser</h2>\n<p>Crane&rsquo;s time and memory as a percentage of the browser&rsquo;s: the geometric mean, over the workloads both engines ran, of Crane&rsquo;s figure divided by the browser&rsquo;s. Below 100% Crane uses less. Start-up and the harness&rsquo;s own floor are rows of their own below, not in these figures.</p>\n");
    try w.writeAll("<div class=\"table-wrap\"><table class=\"listing\"><thead><tr><th scope=\"col\">Browser</th><th scope=\"col\">Version</th><th scope=\"col\" class=\"n\">Time</th><th scope=\"col\" class=\"n\">Workloads</th><th scope=\"col\" class=\"n\">Memory</th><th scope=\"col\" class=\"n\">Workloads</th></tr></thead><tbody>\n");
    for (vs) |v| {
        try w.print("<tr><th scope=\"row\">{s}</th><td>", .{v.browser.label()});
        if (v.version) |ver| try html.text(w, ver) else try w.writeAll("not run");
        try w.writeAll("</td>");
        if (v.time_ratio) |r| try w.print("<td class=\"n {s}\">{d}%</td>", .{ ratioClass(r), percent(r) }) else try w.writeAll("<td class=\"n\">&ndash;</td>");
        try w.print("<td class=\"n\">{d}</td>", .{v.time_n});
        if (v.memory_ratio) |r| try w.print("<td class=\"n {s}\">{d}%</td>", .{ ratioClass(r), percent(r) }) else try w.writeAll("<td class=\"n\">&ndash;</td>");
        try w.print("<td class=\"n\">{d}</td></tr>\n", .{v.memory_n});
    }
    try w.writeAll("</tbody></table></div></section>\n");
}

fn writeEngines(w: W, arena: Allocator, m: *const Model) !void {
    try w.writeAll("<section id=\"engines\"><h2>The engines</h2>\n<p>Every engine is pinned: its version and binary hash are in every journal row, and it is launched with exactly these flags (the page&rsquo;s URL and a fresh profile directory added).</p>\n");
    try w.writeAll("<div class=\"table-wrap\"><table class=\"listing\"><thead><tr><th scope=\"col\">Engine</th><th scope=\"col\">Version</th><th scope=\"col\">Build</th><th scope=\"col\">Launch flags</th></tr></thead><tbody>\n");
    var seen: std.ArrayList([]const u8) = .empty;
    for (m.cells) |c| {
        // A gc_bench row's engine is gc_bench, its flags gc_bench's: the
        // engines here are the ones the pages ran in.
        if (c.round != m.latest_round or c.kind == .gc_bench) continue;
        const key = try std.fmt.allocPrint(arena, "{s}/{s}", .{ @tagName(c.engine), c.version });
        if (containsStr(seen.items, key)) continue;
        try seen.append(arena, key);
        const e = c.engine_info;
        try w.print("<tr><th scope=\"row\">{s}</th><td><code>", .{e.name.label()});
        try html.text(w, e.version);
        try w.writeAll("</code></td><td>");
        try html.text(w, e.build);
        if (e.v8) |v8| {
            try w.writeAll("; V8 ");
            try html.text(w, v8);
        }
        if (e.optimize) |opt| {
            try w.writeAll("; ");
            try html.text(w, opt);
        }
        try w.writeAll("</td><td class=\"flags\"><code>");
        for (e.flags, 0..) |f, i| {
            if (i > 0) try w.writeByte(' ');
            try html.text(w, f);
        }
        try w.writeAll("</code></td></tr>\n");
    }
    try w.writeAll("</tbody></table></div></section>\n");
}

/// A time in the unit that reads best: ns, us, ms or s.
fn writeTime(w: W, us: f64) !void {
    if (us < 1.0) return w.print("{d:.0} ns", .{us * 1000.0});
    if (us < 10.0) return w.print("{d:.2} &micro;s", .{us});
    if (us < 1000.0) return w.print("{d:.1} &micro;s", .{us});
    if (us < 1_000_000.0) return w.print("{d:.1} ms", .{us / 1000.0});
    return w.print("{d:.2} s", .{us / 1_000_000.0});
}

fn writeBytes(w: W, b: f64) !void {
    const mb = b / (1024.0 * 1024.0);
    if (@abs(mb) >= 100) return w.print("{d:.0} MB", .{mb});
    if (@abs(mb) >= 1) return w.print("{d:.1} MB", .{mb});
    return w.print("{d:.0} KB", .{b / 1024.0});
}

fn writeTimeCell(w: W, c: ?*const Cell) !void {
    const cell = c orelse return w.writeAll("<td class=\"n\">&ndash;</td>");
    if (cell.ok == 0) return writeFailure(w, cell);
    const t = cell.timeFigure() orelse return w.writeAll("<td class=\"n\">&ndash;</td>");
    try w.writeAll("<td class=\"n\">");
    // Per op for a timed row; ms per load (chain, startup) otherwise.
    try writeTime(w, if (cell.kind == .timed) t else t * 1000.0);
    if (cell.spread) |s| if (s >= 0.05) try w.print(" <span class=\"quiet\" title=\"spread of the runs (relative MAD)\">&plusmn;{d:.0}%</span>", .{s * 100});
    try w.writeAll("</td>");
}

fn writeMemoryCell(w: W, c: ?*const Cell) !void {
    const cell = c orelse return w.writeAll("<td class=\"n\">&ndash;</td>");
    if (cell.ok == 0) return writeFailure(w, cell);
    const v = cell.memoryFigure() orelse return w.writeAll("<td class=\"n\">&ndash;</td>");
    try w.writeAll("<td class=\"n\">");
    try writeBytes(w, v);
    if (cell.kind == .instances) try w.writeAll(" each") else if (std.mem.eql(u8, cell.workload, "memory.page-growth")) try w.writeAll(" a page");
    try w.writeAll("</td>");
}

fn writeFailure(w: W, cell: *const Cell) !void {
    try w.writeAll("<td class=\"n fail\" title=\"");
    if (cell.message) |msg| try html.text(w, msg[0..@min(msg.len, 300)]);
    try w.writeAll("\">");
    try w.writeAll(if (cell.failure) |f| @tagName(f) else "failed");
    try w.writeAll("</td>");
}

fn writeRatio(w: W, crane: ?f64, other: ?f64) !void {
    const c = crane orelse return w.writeAll("<td class=\"n\"></td>");
    const o = other orelse return w.writeAll("<td class=\"n\"></td>");
    if (o <= 0) return w.writeAll("<td class=\"n\"></td>");
    const r = c / o;
    try w.print("<td class=\"n {s}\">{d}%</td>", .{ ratioClass(r), percent(r) });
}

fn writeRound(w: W, arena: Allocator, m: *const Model) !void {
    const round = m.latest_round;
    const ws = try m.workloads(arena, round);
    try w.print("<section id=\"round\"><h2>Round {d}, workload by workload</h2>\n", .{round});
    try w.writeAll("<p>Time is per operation for a timed workload (the median sample divided by its operations) and per load for a page load; memory is the engine&rsquo;s whole process set (phys_footprint, summed) when the workload ended, or what each page or instance adds. The percentage beside a browser is Crane&rsquo;s figure as a share of it.</p>\n");
    for ([_]bool{ true, false }) |is_time| {
        try w.print("<h3>{s}</h3>\n<div class=\"table-wrap\"><table class=\"listing\"><thead><tr><th scope=\"col\">Workload</th><th scope=\"col\" class=\"n\">Crane</th>", .{if (is_time) "Time" else "Memory"});
        for (browsers) |b| try w.print("<th scope=\"col\" class=\"n\">{s}</th><th scope=\"col\" class=\"n\">Crane / {s}</th>", .{ b.label(), b.label() });
        try w.writeAll("</tr></thead><tbody>\n");
        for (ws) |wl| {
            const c = m.current(round, .crane, wl);
            const kind = if (c) |cc| cc.kind else blk: {
                for (browsers) |b| if (m.current(round, b, wl)) |bc| break :blk bc.kind;
                break :blk journal.Kind.timed;
            };
            if (kind == .gc_bench) continue;
            if (is_time and (kind == .idle or kind == .instances)) continue;
            if (!is_time and kind == .startup) continue;
            try w.writeAll("<tr><th scope=\"row\"><code>");
            try html.text(w, wl);
            try w.writeAll("</code></th>");
            if (is_time) try writeTimeCell(w, c) else try writeMemoryCell(w, c);
            const cf: ?f64 = if (c) |cc| (if (is_time) cc.timeFigure() else cc.memoryFigure()) else null;
            for (browsers) |b| {
                const bc = m.current(round, b, wl);
                if (is_time) try writeTimeCell(w, bc) else try writeMemoryCell(w, bc);
                const bf: ?f64 = if (bc) |x| (if (is_time) x.timeFigure() else x.memoryFigure()) else null;
                try writeRatio(w, cf, bf);
            }
            try w.writeAll("</tr>\n");
        }
        try w.writeAll("</tbody></table></div>\n");
    }
    try w.writeAll("</section>\n");
}

fn writeHistory(w: W, arena: Allocator, m: *const Model) !void {
    try w.writeAll("<section id=\"history\"><h2>History</h2>\n<p>Each workload&rsquo;s figures round by round. A browser updated between rounds is a new version: each version keeps its own row.</p>\n");
    try w.writeAll("<div class=\"table-wrap\"><table class=\"listing\"><thead><tr><th scope=\"col\">Workload</th><th scope=\"col\">Engine</th><th scope=\"col\">Version</th><th scope=\"col\" class=\"n\">Round</th><th scope=\"col\" class=\"n\">Time</th><th scope=\"col\" class=\"n\">CPU</th><th scope=\"col\" class=\"n\">Memory</th><th scope=\"col\" class=\"n\">Runs ok</th></tr></thead><tbody>\n");
    var all: std.ArrayList([]const u8) = .empty;
    for (m.rounds) |r| for (try m.workloads(arena, r)) |wl| if (!containsStr(all.items, wl)) try all.append(arena, wl);
    for (all.items) |wl| {
        for ([_]EngineName{ .crane, .chrome, .firefox, .safari, .lightpanda }) |e| {
            for (m.cells) |*c| {
                if (c.engine != e or !std.mem.eql(u8, c.workload, wl) or c.kind == .gc_bench) continue;
                try w.writeAll("<tr><th scope=\"row\"><code>");
                try html.text(w, wl);
                try w.print("</code></th><td>{s}</td><td><code>", .{e.label()});
                try html.text(w, c.version);
                try w.print("</code></td><td class=\"n\">{d}</td>", .{c.round});
                try writeTimeCell(w, c);
                if (c.cpu_ms) |cpu| try w.print("<td class=\"n\">{d:.1} ms</td>", .{cpu}) else try w.writeAll("<td class=\"n\">&ndash;</td>");
                try writeMemoryCell(w, c);
                try w.print("<td class=\"n\">{d} / {d}</td></tr>\n", .{ c.ok, c.runs });
            }
        }
    }
    try w.writeAll("</tbody></table></div></section>\n");
}

fn writeCraneOnly(w: W, arena: Allocator, m: *const Model) !void {
    _ = arena;
    var any = false;
    for (m.cells) |c| if (c.kind == .gc_bench) {
        any = true;
    };
    if (!any) return;
    try w.writeAll("<section id=\"crane-only\"><h2>Crane-only rows</h2>\n<p>gc_bench&rsquo;s rows: the statements the workloads above run in every engine, measured as no browser can be - one process each, instructions retired, a full collection forced between batches (what is retained, not how fast), and the engine adapter&rsquo;s own counters.</p>\n");
    try w.writeAll("<div class=\"table-wrap\"><table class=\"listing\"><thead><tr><th scope=\"col\">Row</th><th scope=\"col\" class=\"n\">Round</th><th scope=\"col\">Version</th><th scope=\"col\" class=\"n\">Instructions</th><th scope=\"col\" class=\"n\">Wall</th><th scope=\"col\" class=\"n\">Peak footprint</th><th scope=\"col\">Counters</th></tr></thead><tbody>\n");
    for (m.cells) |*c| {
        if (c.kind != .gc_bench) continue;
        try w.writeAll("<tr><th scope=\"row\"><code>");
        try html.text(w, c.workload);
        try w.print("</code></th><td class=\"n\">{d}</td><td><code>", .{c.round});
        try html.text(w, c.version);
        try w.writeAll("</code></td>");
        if (c.ok == 0) {
            try writeFailure(w, c);
            try w.writeAll("<td></td><td></td><td></td></tr>\n");
            continue;
        }
        if (c.instructions) |n| {
            try w.writeAll("<td class=\"n\">");
            try html.num(w, n);
            try w.writeAll("</td>");
        } else try w.writeAll("<td class=\"n\">&ndash;</td>");
        if (c.time_ms) |t| try w.print("<td class=\"n\">{d:.2} s</td>", .{t / 1000.0}) else try w.writeAll("<td class=\"n\">&ndash;</td>");
        try w.writeAll("<td class=\"n\">");
        if (c.peak) |p| try writeBytes(w, @floatFromInt(p)) else try w.writeAll("&ndash;");
        try w.writeAll("</td><td>");
        for (c.counters, 0..) |k, i| {
            if (i > 0) try w.writeAll(", ");
            try html.text(w, k.name);
            try w.print(" {d}", .{k.value});
        }
        try w.writeAll("</td></tr>\n");
    }
    try w.writeAll("</tbody></table></div></section>\n");
}

fn writeMethod(w: W) !void {
    try w.writeAll(
        \\<section id="method"><h2>How it is measured</h2>
        \\<p>Every engine opens the same pages from <code>tests/perf/</code>, served from loopback with cross-origin isolation (so every engine&rsquo;s clock is at its finest), each launch a fresh process with a fresh profile, the engines in alternating order on one quiet host. A page times each workload itself (<code>performance.now()</code> around a fixed number of operations, after warm-up runs) and reports through the benchmark server, which reads the engine&rsquo;s whole process set when each mark arrives: CPU time and instructions between a workload&rsquo;s first and last mark, phys_footprint (Activity Monitor&rsquo;s Memory) at each, and the peak a 50 ms sampler saw between them. Start-up - from launch to the first page&rsquo;s load - is its own row, so no other row includes it. Crane is its release build: ReleaseSafe throughout, libc malloc, V8 linked statically; rendering and layout are not Crane&rsquo;s, so no workload measures them. The full method is in <code>docs/performance.md</code>.</p>
        \\</section>
        \\
    );
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

const host: journal.Host = .{ .name = "chat", .os = "macOS 26.1", .arch = "aarch64", .cpu = "Apple M4 Pro", .cores = 14, .memory_bytes = 1 };

fn engineOf(name: EngineName, version: []const u8) journal.Engine {
    return .{
        .name = name,
        .version = version,
        .build = if (name == .crane) "release" else "stable",
        .commit = if (name == .crane) "abc" else null,
        .optimize = if (name == .crane) "ReleaseSafe" else null,
        .v8 = if (name == .crane) "13.1.203 static" else null,
        .binary = "b",
        .binary_sha256 = "abababababababababababababababababababababababababababababababab",
        .flags = &.{"--headless=new"},
    };
}

/// A timed record; its samples live in `arena` (a record's slices must
/// outlive this call).
fn timed(arena: Allocator, round: u32, name: EngineName, version: []const u8, workload: []const u8, run: u32, sample: f64, footprint: u64) !journal.Record {
    return .{
        .format = journal.format_name,
        .round = round,
        .time = "2026-11-05T18:00:00Z",
        .host = host,
        .engine = engineOf(name, version),
        .page = "workloads/x.html",
        .workload = workload,
        .kind = .timed,
        .run = run,
        .status = .ok,
        .ops = 1000,
        .wall_ms = try arena.dupe(f64, &.{ sample, sample }),
        .cpu_ms = sample,
        .memory = .{ .footprint_start = footprint, .footprint_end = footprint, .footprint_peak = footprint, .resident_end = 0, .processes = 1 },
    };
}

test "the model: medians of runs, and Crane against a browser as a geometric mean" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const records = [_]journal.Record{
        try timed(a, 0, .crane, "abc", "dom.a", 0, 20, 100),
        try timed(a, 0, .crane, "abc", "dom.a", 1, 22, 100),
        try timed(a, 0, .crane, "abc", "dom.a", 2, 21, 100),
        try timed(a, 0, .chrome, "157", "dom.a", 0, 10, 400),
        try timed(a, 0, .crane, "abc", "dom.b", 0, 5, 100),
        try timed(a, 0, .chrome, "157", "dom.b", 0, 10, 400),
    };
    const m = try build(a, &records);
    try testing.expectEqual(@as(u32, 0), m.latest_round);
    const c = m.current(0, .crane, "dom.a").?;
    try testing.expectEqual(@as(u32, 3), c.runs);
    try testing.expectEqual(@as(?f64, 21), c.time_ms);
    try testing.expectApproxEqAbs(@as(f64, 21.0), c.perOpUs().?, 1e-9);
    const v = try versus(a, &m, 0, .chrome);
    // time: 21/10 and 5/10 -> sqrt(2.1 * 0.5) = 1.0247
    try testing.expectApproxEqAbs(@as(f64, 1.0247), v.time_ratio.?, 1e-4);
    try testing.expectEqual(@as(usize, 2), v.time_n);
    try testing.expectApproxEqAbs(@as(f64, 0.25), v.memory_ratio.?, 1e-12);
    try testing.expectEqual(@as(u64, 25), percent(v.memory_ratio.?));
    const none = try versus(a, &m, 0, .safari);
    try testing.expectEqual(@as(?f64, null), none.time_ratio);
}

test "start-up and the harness's floor are their own rows, never in the headline" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var crane_start = try timed(a, 0, .crane, "abc", "startup.idle-page", 0, 70, 100);
    crane_start.kind = .startup;
    crane_start.wall_ms = try a.dupe(f64, &.{70});
    var chrome_start = try timed(a, 0, .chrome, "157", "startup.idle-page", 0, 700, 400);
    chrome_start.kind = .startup;
    chrome_start.wall_ms = try a.dupe(f64, &.{700});
    const records = [_]journal.Record{
        try timed(a, 0, .crane, "abc", "dom.a", 0, 20, 100),
        try timed(a, 0, .chrome, "157", "dom.a", 0, 10, 400),
        crane_start,
        chrome_start,
        try timed(a, 0, .crane, "abc", "overhead.empty", 0, 1, 100),
        try timed(a, 0, .chrome, "157", "overhead.empty", 0, 4, 400),
    };
    const m = try build(a, &records);
    const v = try versus(a, &m, 0, .chrome);
    try testing.expectEqual(@as(usize, 1), v.time_n);
    try testing.expectApproxEqAbs(@as(f64, 2.0), v.time_ratio.?, 1e-12);
}

test "a browser updated within a round: its newest version is the one compared" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var newer = try timed(a, 0, .chrome, "158", "dom.a", 0, 5, 400);
    newer.time = "2026-11-06T18:00:00Z";
    const records = [_]journal.Record{ try timed(a, 0, .crane, "abc", "dom.a", 0, 10, 100), try timed(a, 0, .chrome, "157", "dom.a", 0, 10, 400), newer };
    const m = try build(a, &records);
    try testing.expectEqualStrings("158", m.current(0, .chrome, "dom.a").?.version);
    const v = try versus(a, &m, 0, .chrome);
    try testing.expectApproxEqAbs(@as(f64, 2.0), v.time_ratio.?, 1e-12);
}

test "the page: headline in the HTML, social metadata, the card, every engine named" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var failed = try timed(a, 0, .lightpanda, "nightly", "dom.a", 0, 1, 1);
    failed.status = .unsupported;
    failed.message = "no TextDecoderStream";
    // A Crane-only row, read first: the engines table still shows the
    // flags the pages ran with, not gc_bench's.
    var gc = try timed(a, 0, .crane, "abc", "gc-bench.getter-loop", 0, 160, 100);
    gc.kind = .gc_bench;
    gc.wall_ms = try a.dupe(f64, &.{160});
    gc.engine.flags = &.{ "100000", "100000", "--gc" };
    const records = [_]journal.Record{
        gc,
        try timed(a, 0, .crane, "abc", "dom.a", 0, 20, 100),
        try timed(a, 0, .chrome, "157", "dom.a", 0, 10, 400),
        failed,
    };
    const m = try build(a, &records);
    const out = try render(a, &m, .{});
    const page = out.index_html;
    try testing.expect(std.mem.indexOf(u8, page, "<title>Crane performance: round 0</title>") != null);
    try testing.expect(std.mem.indexOf(u8, page, "<meta name=\"twitter:card\" content=\"summary_large_image\">") != null);
    try testing.expect(std.mem.indexOf(u8, page, "<meta property=\"og:image\" content=\"https://zig-whatwg.github.io/crane/performance/card.png?v=") != null);
    try testing.expect(std.mem.indexOf(u8, page, "200% of Chrome's time and 25% of its memory") != null);
    try testing.expect(std.mem.indexOf(u8, page, "unsupported") != null);
    try testing.expect(std.mem.indexOf(u8, page, "no TextDecoderStream") != null);
    try testing.expect(std.mem.indexOf(u8, page, "13.1.203 static") != null);
    try testing.expect(std.mem.indexOf(u8, page, "--gc") == null);
    try testing.expect(std.mem.indexOf(u8, page, "<script") == null);
    // The social metadata is in the head, before the body.
    try testing.expect(std.mem.indexOf(u8, page, "og:image").? < std.mem.indexOf(u8, page, "</head>").?);
    try testing.expect(std.mem.startsWith(u8, out.card_png, "\x89PNG\r\n\x1a\n"));
    // Same journals, same bytes.
    const again = try render(a, &m, .{});
    try testing.expectEqualStrings(page, again.index_html);
    try testing.expectEqualSlices(u8, out.card_png, again.card_png);
}
