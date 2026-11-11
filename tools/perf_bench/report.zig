//! /performance/: the report of every perf round, written as finished HTML
//! from the journals (the results-site rules: the content is in the HTML;
//! no script is needed to read it). Published beside the WPT site on
//! gh-pages, under performance/, with the WPT site's stylesheet.
//!
//! What the page shows, from the journals alone:
//!   - the headline: this round's Crane against each browser, time and
//!     memory, as the geometric mean over the workloads both ran of Crane's
//!     figure as a percentage of the browser's (lower is better for Crane).
//!     Crane is its release build, ReleaseSafe (journal `crane`);
//!   - Crane ReleaseFast (journal `crane_fast`), where a round has it: the
//!     same comparison of the ReleaseFast build against the ReleaseSafe one
//!     and each browser, below the headline, and its own column in the
//!     round's tables (the user, 2026-11-05: an extra column, the headline
//!     stays ReleaseSafe);
//!   - a Crane-only window's comparison (`crane` against `crane_base`, lane
//!     perf2), where a round has a base: per workload, time and memory,
//!     with noise bands and two geometric means;
//!   - a Crane-only round (the user, 2026-11-06: re-measuring runs only
//!     Crane): each browser's rows are its latest earlier round's
//!     (`Model.standing`), and the drift control (`crane_control`, the binary
//!     that round measured as Crane) shows the host did not move; where the
//!     round has a base of the control's commit for the fixed CPU target,
//!     what the target alone did (`targetAlone`);
//!   - the progress (from the second round on): Crane over time - its own
//!     time and memory per measurement round as a share of its first round's,
//!     one line each - and the gap to the browsers, a table of Crane's figure
//!     as a multiple of each browser's per round (the user, 2026-11-07);
//!   - Crane round by round: each workload's figures per measurement round,
//!     its change since the first and its trend;
//!   - the engines: each one's version, build and launch flags;
//!   - this round, workload by workload: each engine's median time and
//!     memory, and Crane's ratio to each browser;
//!   - the history: each workload's figures round by round, a browser's by
//!     version (an updated browser is a new data point);
//!   - the Crane-only rows (gc_bench), round by round;
//!   - memory per element (the user, 2026-11-07: "can we get our nodes
//!     even smaller?", and "yes" to a fair comparison with the browsers):
//!     what one kept node costs each engine - the retained pages' rows
//!     (`retained`, tests/perf/elements.json), kept out of every other
//!     section, so the headline, the round tables and the progress are the
//!     suite's alone (`elementTable`);
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
const chart = @import("chart.zig");

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
    /// ... once the workload was over and the page idle (steady), when read.
    settled: ?u64 = null,
    peak: ?u64 = null,
    /// chain and instances: bytes per step or per instance (median slope).
    growth: ?f64 = null,
    /// chain: the footprint the chain levels off at - each run's median
    /// over the second half of its steps, the median over runs (bytes) -
    /// and the slope over that second half, bytes per page: what is still
    /// kept for each page once collections keep up (median over runs). Null
    /// for a record without its series.
    plateau: ?u64 = null,
    late_growth: ?f64 = null,
    /// gc_bench rows: their counters (median over runs), by name.
    counters: []const journal.Counter = &.{},
    /// retained rows: each ok run's footprint after its objects less its
    /// footprint before them (bytes; it can be negative), and the same for
    /// the JS heap where the engine reports it.
    run_deltas: []const f64 = &.{},
    run_js_deltas: []const f64 = &.{},
    /// retained rows: how many ok runs read both footprints after a
    /// collection the page asked for (`forced_gc`), and their idle time.
    forced_gc_runs: u32 = 0,
    settle_ms: ?f64 = null,
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
            .idle, .instances, .retained => null,
        };
    }

    /// The figure compared for memory: growth per instance for the
    /// instances row, the level a page chain's footprint reaches for
    /// memory.page-growth, the footprint otherwise.
    ///
    /// memory.page-growth compared the slope over all 30 steps until lane
    /// perf2 batch 7: a footprint that rises while nothing is collected and
    /// then levels off reads a LATER knee as more growth, so a tip below its
    /// base at every step read 1.175 of it (b6's pair). Every round is read
    /// this way, from its journals' series.
    pub fn memoryFigure(c: Cell) ?f64 {
        if (c.ok == 0) return null;
        if (std.mem.eql(u8, c.workload, "memory.page-growth")) {
            const level = c.plateau orelse return null;
            return @floatFromInt(level);
        }
        if (c.kind == .instances) {
            const g = c.growth orelse return null;
            return if (g > 0) g else null;
        }
        if (c.kind == .startup) return null;
        // Steady where it was read (after the workload and the settle time),
        // else at the workload's end.
        const f = c.settled orelse c.footprint orelse return null;
        return @floatFromInt(f);
    }

    /// The most the process set used during the workload.
    pub fn peakFigure(c: Cell) ?f64 {
        if (c.ok == 0 or c.kind == .startup) return null;
        const p = c.peak orelse return null;
        return @floatFromInt(p);
    }
};

pub const Model = struct {
    cells: []Cell,
    rounds: []u32,
    latest_round: u32,
    /// The retained pages' cells (memory per element), apart from `cells`:
    /// no headline, table, progress or drift reads them (`elementTable`).
    retained: []Cell = &.{},

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

    /// The round whose rows of `engine` stand for `round`: `round` itself
    /// when the engine ran in it; for a browser that did not, the latest
    /// earlier round it ran in (the user, 2026-11-06: re-measuring runs ONLY
    /// Crane, and a browser keeps its last rows until it updates). A Crane
    /// build's rows never stand for a later round: each is measured in its
    /// own, or is absent from it.
    pub fn standing(m: *const Model, round: u32, engine: EngineName) ?u32 {
        var best: ?u32 = null;
        for (m.cells) |c| {
            if (c.engine != engine or c.round > round) continue;
            if (c.round == round) return round;
            if (engine.isCrane()) continue;
            if (best == null or c.round > best.?) best = c.round;
        }
        return best;
    }

    /// `engine`'s cell for `workload` as it stands in `round` (`standing`).
    pub fn rowsFor(m: *const Model, round: u32, engine: EngineName, workload: []const u8) ?*const Cell {
        return m.current(m.standing(round, engine) orelse return null, engine, workload);
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

/// The model of `records` (all rounds). A retained row (memory per element)
/// goes to `Model.retained`, never to `cells`: its figure is not a
/// workload's, and its rows never make or move a round of the suite.
pub fn build(arena: Allocator, records: []const journal.Record) !Model {
    var suite_records: std.ArrayList(journal.Record) = .empty;
    var retained_records: std.ArrayList(journal.Record) = .empty;
    for (records) |r| try (if (r.kind == .retained) &retained_records else &suite_records).append(arena, r);
    const cells = try cellsOf(arena, suite_records.items);
    var rounds: std.ArrayList(u32) = .empty;
    for (cells) |c| if (std.mem.indexOfScalar(u32, rounds.items, c.round) == null) try rounds.append(arena, c.round);
    std.mem.sort(u32, rounds.items, {}, std.sort.asc(u32));
    return .{
        .cells = cells,
        .rounds = rounds.items,
        .latest_round = if (rounds.items.len > 0) rounds.items[rounds.items.len - 1] else 0,
        .retained = try cellsOf(arena, retained_records.items),
    };
}

/// `records` grouped into cells - one per (round, engine, version,
/// workload) - each summarised.
fn cellsOf(arena: Allocator, records: []const journal.Record) ![]Cell {
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
    return cells.items;
}

fn summarise(arena: Allocator, c: *Cell, runs: []const journal.Record) !void {
    var times: std.ArrayList(f64) = .empty;
    var cpus: std.ArrayList(f64) = .empty;
    var ins: std.ArrayList(u64) = .empty;
    var foot: std.ArrayList(u64) = .empty;
    var settled: std.ArrayList(u64) = .empty;
    var peak: std.ArrayList(u64) = .empty;
    var growth: std.ArrayList(f64) = .empty;
    var plateaus: std.ArrayList(u64) = .empty;
    var late_growth: std.ArrayList(f64) = .empty;
    var counter_names: std.ArrayList([]const u8) = .empty;
    var deltas: std.ArrayList(f64) = .empty;
    var js_deltas: std.ArrayList(f64) = .empty;
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
            if (m.footprint_settled) |v| try settled.append(arena, v);
            try peak.append(arena, m.footprint_peak);
        }
        if (stats.slope(r.series)) |s| try growth.append(arena, s);
        if (r.kind == .chain and r.series.len >= 4) {
            const second_half = r.series[r.series.len / 2 ..];
            if (try stats.medianU64(arena, second_half)) |level| try plateaus.append(arena, level);
            if (stats.slope(second_half)) |s| try late_growth.append(arena, s);
        }
        for (r.counters) |k| if (!containsStr(counter_names.items, k.name)) try counter_names.append(arena, k.name);
        if (r.kind == .retained) if (r.memory) |m| {
            try deltas.append(arena, @as(f64, @floatFromInt(m.footprint_end)) - @as(f64, @floatFromInt(m.footprint_start)));
            if (counterOf(r.counters, "js_heap_before")) |b| if (counterOf(r.counters, "js_heap_after")) |a| try js_deltas.append(arena, a - b);
            if ((counterOf(r.counters, "forced_gc") orelse 0) == 1) c.forced_gc_runs += 1;
            if (counterOf(r.counters, "settle_ms")) |v| c.settle_ms = v;
        };
    }
    c.run_deltas = deltas.items;
    c.run_js_deltas = js_deltas.items;
    c.time_ms = try stats.median(arena, times.items);
    c.spread = try stats.relativeMad(arena, times.items);
    c.cpu_ms = try stats.median(arena, cpus.items);
    c.instructions = try stats.medianU64(arena, ins.items);
    c.footprint = try stats.medianU64(arena, foot.items);
    c.settled = try stats.medianU64(arena, settled.items);
    c.peak = try stats.medianU64(arena, peak.items);
    c.growth = try stats.median(arena, growth.items);
    c.plateau = try stats.medianU64(arena, plateaus.items);
    c.late_growth = try stats.median(arena, late_growth.items);
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

fn counterOf(counters: []const journal.Counter, name: []const u8) ?f64 {
    for (counters) |k| if (std.mem.eql(u8, k.name, name)) return k.value;
    return null;
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
    /// The round `browser`'s rows come from (`Model.standing`).
    round: ?u32 = null,
    time_ratio: ?f64 = null,
    time_n: usize = 0,
    memory_ratio: ?f64 = null,
    memory_n: usize = 0,
};

/// Whether a workload counts in the headline: start-up and the harness's own
/// floor are rows of their own, so the headline compares engine work, not
/// launchers or the harness (the integrator, 2026-11-05); a page's own
/// memory row sums its workloads' rows, which count already.
pub fn inHeadline(workload: []const u8) bool {
    for ([_][]const u8{ "startup.", "overhead.", "page." }) |group| if (std.mem.startsWith(u8, workload, group)) return false;
    return true;
}

/// The headline's comparison: Crane's release build (ReleaseSafe) against
/// `browser`.
pub fn versus(arena: Allocator, m: *const Model, round: u32, browser: EngineName) !Versus {
    return compare(arena, m, round, .crane, browser);
}

/// `subject` against `other` in `round`: the geometric mean, over the
/// headline's workloads both ran, of `subject`'s figure over `other`'s
/// (`browser` and `version` name `other`).
pub fn compare(arena: Allocator, m: *const Model, round: u32, subject: EngineName, other: EngineName) !Versus {
    var v: Versus = .{ .browser = other, .round = m.standing(round, other) };
    var t: std.ArrayList(f64) = .empty;
    var mem: std.ArrayList(f64) = .empty;
    for (try m.workloads(arena, round)) |w| {
        if (!inHeadline(w)) continue;
        const b = m.rowsFor(round, other, w) orelse continue;
        // gc_bench's rows are Crane-only, with a history of their own.
        if (b.kind == .gc_bench) continue;
        v.version = b.version;
        const c = m.rowsFor(round, subject, w) orelse continue;
        if (c.timeFigure()) |ct| if (b.timeFigure()) |bt| if (bt > 0) try t.append(arena, ct / bt);
        if (c.memoryFigure()) |cm| if (b.memoryFigure()) |bm| if (bm > 0) try mem.append(arena, cm / bm);
    }
    v.time_ratio = stats.geometricMean(t.items);
    v.time_n = t.items.len;
    v.memory_ratio = stats.geometricMean(mem.items);
    v.memory_n = mem.items.len;
    return v;
}

/// Whether `round` has any row of `engine`.
pub fn hasEngine(m: *const Model, round: u32, engine: EngineName) bool {
    for (m.cells) |c| if (c.round == round and c.engine == engine) return true;
    return false;
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
    /// A re-measurement (`perf_bench report --control=<dir>`), when the
    /// round's rows of some engines come from a second window.
    remeasured: ?Remeasured = null,
};

/// Some engines' rows of a round come from a second window: the engines,
/// and the control - the second window's rows of an engine the round
/// already has (Crane ReleaseSafe), run alternating with them so that a
/// drift of the host between the windows shows (the integrator,
/// 2026-11-06). The control's rows never enter the round's cells.
pub const Remeasured = struct {
    engines: []const EngineName,
    control: *const Model,
    /// The engine both windows ran.
    engine: EngineName = .crane,
};

/// The control against the round, for one engine: per workload the
/// control's figure over the round's, and their geometric means.
pub const Drift = struct {
    engine: EngineName,
    time_ratio: ?f64 = null,
    time_n: usize = 0,
    memory_ratio: ?f64 = null,
    memory_n: usize = 0,
    /// Workloads whose time or memory ratio is outside its noise band
    /// (`noiseBand`).
    outside: usize = 0,
    /// Both geometric means within `drift_limit` of 1.
    within: bool = false,
};

/// How far the control's geometric means may stray from 1 and still be
/// within noise: 5%.
pub const drift_limit = 0.05;

/// A workload's noise band: 10%, or three times the runs' spread (the
/// larger of the two cells' relative MAD) where that is wider.
pub fn noiseBand(a: *const Cell, b: *const Cell) f64 {
    const s = @max(a.spread orelse 0, b.spread orelse 0);
    return @max(0.10, 3.0 * s);
}

pub fn drift(arena: Allocator, m: *const Model, control: *const Model, round: u32, engine: EngineName) !Drift {
    return driftBetween(arena, m, round, engine, control, round, engine);
}

/// `drift` between differently named rows: `control`'s `control_engine`
/// in `control_round` over `m`'s `engine` in `round`. A Crane-only
/// window's base (`crane_base` in the new round) against the same build's
/// rows in the round it came from (`crane` there): the drift control the
/// user's rule asks for before the tip's rows are published (lane perf2).
pub fn driftBetween(arena: Allocator, m: *const Model, round: u32, engine: EngineName, control: *const Model, control_round: u32, control_engine: EngineName) !Drift {
    var d: Drift = .{ .engine = control_engine };
    var t: std.ArrayList(f64) = .empty;
    var mem: std.ArrayList(f64) = .empty;
    for (try control.workloads(arena, control_round)) |w| {
        if (!inHeadline(w)) continue;
        const c = control.current(control_round, control_engine, w) orelse continue;
        const r = m.current(round, engine, w) orelse continue;
        // The rows a drift is checked for are the pages', which are set
        // beside the browsers'; gc_bench's Crane-only rows have their own
        // history.
        if (c.kind == .gc_bench) continue;
        const band = noiseBand(c, r);
        var out = false;
        if (c.timeFigure()) |ct| if (r.timeFigure()) |rt| if (rt > 0) {
            try t.append(arena, ct / rt);
            if (@abs(ct / rt - 1.0) > band) out = true;
        };
        if (c.memoryFigure()) |cm| if (r.memoryFigure()) |rm| if (rm > 0) {
            try mem.append(arena, cm / rm);
            if (@abs(cm / rm - 1.0) > @max(0.10, band)) out = true;
        };
        if (out) d.outside += 1;
    }
    d.time_ratio = stats.geometricMean(t.items);
    d.time_n = t.items.len;
    d.memory_ratio = stats.geometricMean(mem.items);
    d.memory_n = mem.items.len;
    const ok = struct {
        fn f(x: ?f64) bool {
            const v = x orelse return false;
            return @abs(v - 1.0) <= drift_limit;
        }
    }.f;
    d.within = ok(d.time_ratio) and ok(d.memory_ratio);
    return d;
}

/// A Crane-only window (the user, 2026-11-06: a re-measurement runs only
/// Crane; lane perf2): the new Crane (`crane`, the tip) alternating with a
/// frozen earlier one (`crane_base`) in one round. Per workload both ran,
/// the tip's figure over the base's for time, steady memory and peak
/// memory, against drift()'s noise band (`noiseBand`: 10%, or three times
/// the runs' spread; memory never under 10%), and the two geometric means
/// - time and steady memory - over the headline's workloads.
pub const BaseTipRow = struct {
    workload: []const u8,
    base: *const Cell,
    tip: *const Cell,
    time: ?f64 = null,
    steady: ?f64 = null,
    peak: ?f64 = null,
    band: f64,
    /// Any of the three ratios outside its band.
    outside: bool = false,
};

pub const BaseTip = struct {
    base_version: []const u8,
    tip_version: []const u8,
    rows: []const BaseTipRow,
    time_ratio: ?f64 = null,
    time_n: usize = 0,
    memory_ratio: ?f64 = null,
    memory_n: usize = 0,
    /// The workloads outside their bands, in the round's order.
    outside: []const []const u8,
};

/// The tip against its base in `round`; null when the round has no base.
pub fn baseTip(arena: Allocator, m: *const Model, round: u32) !?BaseTip {
    if (!hasEngine(m, round, .crane_base)) return null;
    var rows: std.ArrayList(BaseTipRow) = .empty;
    var outside: std.ArrayList([]const u8) = .empty;
    var t: std.ArrayList(f64) = .empty;
    var mem: std.ArrayList(f64) = .empty;
    var base_version: []const u8 = "";
    var tip_version: []const u8 = "";
    for (try m.workloads(arena, round)) |w| {
        const b = m.current(round, .crane_base, w) orelse continue;
        const c = m.current(round, .crane, w) orelse continue;
        if (b.kind == .gc_bench) continue;
        base_version = b.version;
        tip_version = c.version;
        const band = noiseBand(b, c);
        var row: BaseTipRow = .{ .workload = w, .base = b, .tip = c, .band = band };
        row.time = ratioOf(c.timeFigure(), b.timeFigure());
        row.steady = ratioOf(c.memoryFigure(), b.memoryFigure());
        row.peak = ratioOf(c.peakFigure(), b.peakFigure());
        const memory_band = @max(0.10, band);
        if (row.time) |r| if (@abs(r - 1.0) > band) {
            row.outside = true;
        };
        if (row.steady) |r| if (@abs(r - 1.0) > memory_band) {
            row.outside = true;
        };
        if (row.peak) |r| if (@abs(r - 1.0) > memory_band) {
            row.outside = true;
        };
        if (row.outside) try outside.append(arena, w);
        if (inHeadline(w)) {
            if (row.time) |r| try t.append(arena, r);
            if (row.steady) |r| try mem.append(arena, r);
        }
        try rows.append(arena, row);
    }
    return .{
        .base_version = base_version,
        .tip_version = tip_version,
        .rows = rows.items,
        .time_ratio = stats.geometricMean(t.items),
        .time_n = t.items.len,
        .memory_ratio = stats.geometricMean(mem.items),
        .memory_n = mem.items.len,
        .outside = outside.items,
    };
}

/// A round's drift control (`crane_control`): the frozen binary an earlier
/// round measured as `crane`, run again in this round's window, against
/// that round's rows (`driftBetween`). The user's rule (2026-11-06): the
/// control must be within noise before a Crane-only round's rows are set
/// beside the browsers' rows from an earlier round.
pub const ControlDrift = struct {
    /// The control's version (its commit) and the CPU its build is for, as
    /// its pin names it (none for a build from before it was recorded).
    version: []const u8,
    target_cpu: ?[]const u8 = null,
    sha256: []const u8,
    /// The latest earlier round whose Crane rows this binary made - found by
    /// its SHA-256, so a control that is not the same bytes is no control:
    /// null, and `drift` is empty.
    earlier_round: ?u32 = null,
    drift: Drift,
};

/// The drift control of `round`; null when the round has none.
pub fn controlDrift(arena: Allocator, m: *const Model, round: u32) !?ControlDrift {
    const ctl = for (m.cells) |*c| {
        if (c.round == round and c.engine == .crane_control and c.kind != .gc_bench) break c;
    } else return null;
    var out: ControlDrift = .{
        .version = ctl.version,
        .target_cpu = ctl.engine_info.target_cpu,
        .sha256 = ctl.engine_info.binary_sha256,
        .drift = .{ .engine = .crane_control },
    };
    for (m.cells) |c| {
        // A gc_bench row's binary is gc_bench, not the console.
        if (c.round >= round or c.engine != .crane or c.kind == .gc_bench) continue;
        if (!std.mem.eql(u8, c.engine_info.binary_sha256, out.sha256)) continue;
        if (out.earlier_round == null or c.round > out.earlier_round.?) out.earlier_round = c.round;
    }
    const earlier = out.earlier_round orelse return out;
    out.drift = try driftBetween(arena, m, earlier, .crane, m, round, .crane_control);
    return out;
}

/// Whether a round's Crane rows may stand beside its browsers': measured in
/// the same window, or a Crane-only round whose browsers' rows are an earlier
/// round's (`Model.standing`) with a drift control within noise. The other
/// two are not published (the user, 2026-11-06; `perf_bench report` refuses).
pub const Standing = enum { measured_together, carried_within_noise, carried_without_control, carried_drifted };

pub fn standingOf(arena: Allocator, m: *const Model, round: u32) !Standing {
    const carried = for (browsers) |b| {
        if (m.standing(round, b)) |r| if (r != round) break true;
    } else false;
    if (!carried) return .measured_together;
    const cd = (try controlDrift(arena, m, round)) orelse return .carried_without_control;
    if (cd.earlier_round == null) return .carried_without_control;
    return if (cd.drift.within) .carried_within_noise else .carried_drifted;
}

/// What the CPU target alone did: a round's base (`crane_base`) built from
/// the control's own commit for another CPU target, against the control -
/// the same source, two targets (round 1: round 0's source for apple_m1
/// against round 0's native build). Null unless the round has both, of one
/// commit and two named targets.
pub const TargetAlone = struct {
    /// The base's figures over the control's (`compare`).
    versus: Versus,
    base_target: []const u8,
    control_target: []const u8,
};

pub fn targetAlone(arena: Allocator, m: *const Model, round: u32) !?TargetAlone {
    var base: ?*const Cell = null;
    var control: ?*const Cell = null;
    for (m.cells) |*c| {
        if (c.round != round or c.kind == .gc_bench) continue;
        if (c.engine == .crane_base and base == null) base = c;
        if (c.engine == .crane_control and control == null) control = c;
    }
    const b = base orelse return null;
    const c = control orelse return null;
    if (!std.mem.eql(u8, b.version, c.version)) return null;
    const bt = b.engine_info.target_cpu orelse return null;
    const ct = c.engine_info.target_cpu orelse return null;
    if (std.mem.eql(u8, bt, ct)) return null;
    return .{ .versus = try compare(arena, m, round, .crane_base, .crane_control), .base_target = bt, .control_target = ct };
}

/// `subject` in `round` over `other` in `earlier`: the geometric mean over the headline's page
/// workloads both ran (`browser` names `other`, `round` its round). Crane against an earlier Crane
/// (the progress since round 0).
pub fn compareRounds(arena: Allocator, m: *const Model, round: u32, subject: EngineName, earlier: u32, other: EngineName) !Versus {
    var v: Versus = .{ .browser = other, .round = earlier };
    var t: std.ArrayList(f64) = .empty;
    var mem: std.ArrayList(f64) = .empty;
    for (try m.workloads(arena, round)) |w| {
        if (!inHeadline(w)) continue;
        const c = m.current(round, subject, w) orelse continue;
        const b = m.current(earlier, other, w) orelse continue;
        if (c.kind == .gc_bench) continue;
        v.version = b.version;
        if (c.timeFigure()) |ct| if (b.timeFigure()) |bt| if (bt > 0) try t.append(arena, ct / bt);
        if (c.memoryFigure()) |cm| if (b.memoryFigure()) |bm| if (bm > 0) try mem.append(arena, cm / bm);
    }
    v.time_ratio = stats.geometricMean(t.items);
    v.time_n = t.items.len;
    v.memory_ratio = stats.geometricMean(mem.items);
    v.memory_n = mem.items.len;
    return v;
}

/// What each round changed, for its line in the progress section: one line written when the
/// round is published (the WPT site's chart events are the same pattern, tools/wpt_site/chart.zig);
/// every figure beside it is the journals'. A round with no line shows none. A change of CPU
/// target is the journals' too (`targetChanges`), so no note repeats it.
pub const RoundNote = struct { round: u32, note: []const u8 };

pub const round_notes = [_]RoundNote{
    .{ .round = 0, .note = "The baseline: the suite's first measurement, of main 9b0f1b1f382, built for its build host's CPU." },
    .{ .round = 1, .note = "Lane perf1: DOM memory reported to V8, and a garbage tree's deferred teardown weighed by its nodes. Lane perf2: getElementsBy* return one live list per document, and querySelector, matches and closest parse through a per-document selector cache with Blink's ID path." },
    .{ .round = 2, .note = "Lane perf2: each node type's state in its own generated State, read with no hash lookup; a generated State that holds only its internal pointers (a kept div 4,683 -> 2,782 B); NodeBase 472 -> 208 B, and every block a node holds reported to V8. Lane perf3: a DOM call's values are V8 Locals - no Global per getter, setter or method call - and a Global's dispose takes no lock. Lane anim1: CSS transitions and animations from style." },
};

pub fn roundNote(round: u32) ?[]const u8 {
    for (round_notes) |n| if (n.round == round) return n.note;
    return null;
}

/// One point of Crane's progress: a measurement round of Crane's release build (`crane`), never a
/// methodology control (a round's base or drift control is not a point: the user, 2026-11-07, on
/// the chart that drew round 0's source rebuilt for round 1's CPU target as a point of its own -
/// "this graph is confusing for tracking Crane's progress"). Its geometric means against the
/// first round's (`since`), and against each browser's rows as they stood (`vs`,
/// `Model.standing`).
pub const ProgressPoint = struct {
    round: u32,
    commit: []const u8,
    /// The window's date, "2026-11-06" (its rows' latest time).
    date: []const u8,
    target: ?[]const u8,
    /// Crane's time and memory over the first round's (`compareRounds`): 1 at the first round.
    since: Versus,
    vs: [browsers.len]Versus,
};

/// The CPU target of `round`'s Crane rows; for a round from before it was recorded, the target a
/// later round's drift control - the same binary - names.
pub fn targetOf(arena: Allocator, m: *const Model, round: u32) !?[]const u8 {
    if (craneTarget(m, round)) |t| return t;
    for (m.rounds) |r| {
        if (r <= round) continue;
        const cd = (try controlDrift(arena, m, r)) orelse continue;
        if (cd.earlier_round == round) return cd.target_cpu;
    }
    return null;
}

fn dateOf(m: *const Model, round: u32, engine: EngineName) []const u8 {
    var latest: []const u8 = "";
    for (m.cells) |c| if (c.round == round and c.engine == engine and std.mem.order(u8, c.latest_time, latest) == .gt) {
        latest = c.latest_time;
    };
    return latest[0..@min(latest.len, 10)];
}

/// Crane's progress, oldest first: every round that has Crane's release build.
pub fn progress(arena: Allocator, m: *const Model) ![]const ProgressPoint {
    var out: std.ArrayList(ProgressPoint) = .empty;
    var first: ?u32 = null;
    for (m.rounds) |r| {
        if (!hasEngine(m, r, .crane)) continue;
        if (first == null) first = r;
        var p: ProgressPoint = .{
            .round = r,
            .commit = "",
            .date = dateOf(m, r, .crane),
            .target = try targetOf(arena, m, r),
            .since = try compareRounds(arena, m, r, .crane, first.?, .crane),
            .vs = undefined,
        };
        for (m.cells) |c| if (c.round == r and c.engine == .crane and c.kind != .gc_bench) {
            p.commit = c.version;
            break;
        };
        for (browsers, 0..) |b, i| p.vs[i] = try compare(arena, m, r, .crane, b);
        try out.append(arena, p);
    }
    return out.items;
}

/// Where a round changed Crane's CPU target and also rebuilt an earlier round's source for the new
/// one (`targetAlone`): what the target alone did, said once beside the progress charts instead of
/// a point on them.
pub const TargetChange = struct {
    round: u32,
    /// The round whose source was rebuilt (the drift control's round).
    source_round: u32,
    target: []const u8,
    /// The rebuilt source over the control (`compare` of `crane_base` against `crane_control`).
    versus: Versus,
};

pub fn targetChanges(arena: Allocator, m: *const Model) ![]const TargetChange {
    var out: std.ArrayList(TargetChange) = .empty;
    for (m.rounds) |r| {
        const t = (try targetAlone(arena, m, r)) orelse continue;
        const cd = (try controlDrift(arena, m, r)) orelse continue;
        try out.append(arena, .{ .round = r, .source_round = cd.earlier_round orelse r, .target = t.base_target, .versus = t.versus });
    }
    return out.items;
}

/// A gap's change from the round before: lower (better, for Crane), higher, or within the noise
/// limit the drift control itself is held to (`drift_limit`) - a move that small is not shown as
/// one.
pub const Change = enum { none, better, worse, steady };

pub fn changeOf(prev: ?f64, cur: ?f64) Change {
    const p = prev orelse return .none;
    const c = cur orelse return .none;
    if (p <= 0) return .none;
    const r = c / p;
    if (@abs(r - 1.0) <= drift_limit) return .steady;
    return if (r < 1.0) .better else .worse;
}

/// Crane's latest round over its first (`compareRounds`): the progress the card names. Null with
/// fewer than two rounds of Crane.
pub fn sinceFirst(arena: Allocator, m: *const Model) !?Versus {
    var first: ?u32 = null;
    var last: ?u32 = null;
    for (m.rounds) |r| if (hasEngine(m, r, .crane)) {
        if (first == null) first = r;
        last = r;
    };
    const f = first orelse return null;
    const l = last.?;
    if (f == l) return null;
    return try compareRounds(arena, m, l, .crane, f, .crane);
}

fn ratioOf(subject: ?f64, other: ?f64) ?f64 {
    const s = subject orelse return null;
    const o = other orelse return null;
    if (o <= 0) return null;
    return s / o;
}

/// Every file of /performance/ for `m`: name -> bytes.
/// The retained page that makes nothing (tests/perf/memory/elements-control.html): the
/// same steps as every case, so its difference between the readings is the footprint's
/// own drift over those steps, which each case's figure has subtracted (the integrator,
/// 2026-11-07: bytes per element = (case - control) / N).
pub const element_control = "elements.control";

/// One engine's figure for one case of memory per element.
pub const ElementFigure = struct {
    /// Bytes per object: each run's (case difference - the control's median difference) / N,
    /// the median over the runs.
    bytes: ?f64 = null,
    /// The runs' median absolute deviation of that figure, bytes per object.
    mad: ?f64 = null,
    /// The same for the JS heap, where the engine tells a page (Chrome's performance.memory).
    js_bytes: ?f64 = null,
    runs: u32 = 0,
    ok: u32 = 0,
    failure: ?journal.Status = null,
    message: ?[]const u8 = null,
};

/// One engine's row of memory per element.
pub const ElementRow = struct {
    engine: EngineName,
    version: []const u8,
    /// The round its rows come from: a browser keeps its last rows, a Crane build's are its
    /// round's own (`Model.standing`'s rule).
    round: u32,
    /// Every ok run of the control and the cases read both footprints after a collection the
    /// page asked for (`forced_gc`); false when the engine let the page ask for none.
    forced_gc: bool,
    settle_ms: ?f64,
    /// The control's median difference, bytes: what each figure has subtracted.
    control_delta: ?f64,
    /// One per `ElementTable.cases`.
    figures: []const ElementFigure,
};

pub const ElementTable = struct {
    round: u32,
    /// N: the objects each case made and kept.
    count: u64,
    /// The cases, in the order they ran, without the control.
    cases: []const []const u8,
    rows: []const ElementRow,
};

/// The order of the rows: Crane's builds first, then the browsers.
const element_engines = [_]EngineName{ .crane, .crane_fast, .crane_base, .chrome, .firefox, .safari, .lightpanda };

/// `engine`'s retained cell for `workload` in `round`, at the engine's newest version there.
fn retainedCell(m: *const Model, round: u32, engine: EngineName, workload: []const u8) ?*const Cell {
    var best: ?*const Cell = null;
    for (m.retained) |*c| {
        if (c.round != round or c.engine != engine or !std.mem.eql(u8, c.workload, workload)) continue;
        if (best == null or std.mem.order(u8, c.latest_time, best.?.latest_time) == .gt) best = c;
    }
    return best;
}

/// Memory per element, from the retained rows of the latest round that has any: for each
/// engine and case, bytes per object - each run's (case difference - the control's median
/// difference) / N, the median over the runs. A browser without rows in that round keeps
/// its latest earlier round's; a Crane build's rows are its round's own.
pub fn elementTable(arena: Allocator, m: *const Model) !?ElementTable {
    var round: ?u32 = null;
    for (m.retained) |c| {
        if (round == null or c.round > round.?) round = c.round;
    }
    const r = round orelse return null;
    var cases: std.ArrayList([]const u8) = .empty;
    for (m.retained) |c| {
        if (c.round > r or std.mem.eql(u8, c.workload, element_control) or containsStr(cases.items, c.workload)) continue;
        try cases.append(arena, c.workload);
    }
    var count: u64 = 0;
    var rows: std.ArrayList(ElementRow) = .empty;
    for (element_engines) |e| {
        // The round this engine's rows stand from.
        var from: ?u32 = null;
        for (m.retained) |c| {
            if (c.engine != e or c.round > r) continue;
            if (e.isCrane() and c.round != r) continue;
            if (from == null or c.round > from.?) from = c.round;
        }
        const er = from orelse continue;
        const control = retainedCell(m, er, e, element_control);
        const control_delta: ?f64 = if (control) |cc| try stats.median(arena, cc.run_deltas) else null;
        const control_js: ?f64 = if (control) |cc| try stats.median(arena, cc.run_js_deltas) else null;
        var figures: std.ArrayList(ElementFigure) = .empty;
        var version: []const u8 = "";
        var forced = true;
        var any_ok = false;
        var settle: ?f64 = null;
        if (control) |cc| {
            version = cc.version;
            settle = cc.settle_ms;
            if (cc.ok > 0) any_ok = true;
            if (cc.forced_gc_runs < cc.ok) forced = false;
        }
        for (cases.items) |w| {
            var f: ElementFigure = .{};
            const cell = retainedCell(m, er, e, w) orelse {
                try figures.append(arena, f);
                continue;
            };
            version = cell.version;
            f.runs = cell.runs;
            f.ok = cell.ok;
            f.failure = cell.failure;
            f.message = cell.message;
            if (cell.settle_ms) |v| settle = v;
            if (cell.ok > 0) {
                any_ok = true;
                if (cell.forced_gc_runs < cell.ok) forced = false;
                if (count == 0) count = cell.ops;
            }
            if (cell.ops > 0) if (control_delta) |cd| {
                const n: f64 = @floatFromInt(cell.ops);
                var per: std.ArrayList(f64) = .empty;
                for (cell.run_deltas) |d| try per.append(arena, (d - cd) / n);
                if (try stats.median(arena, per.items)) |med| {
                    f.bytes = med;
                    var dev: std.ArrayList(f64) = .empty;
                    for (per.items) |v| try dev.append(arena, @abs(v - med));
                    f.mad = try stats.median(arena, dev.items);
                }
                if (control_js) |cj| if (try stats.median(arena, cell.run_js_deltas)) |jd| {
                    f.js_bytes = (jd - cj) / n;
                };
            };
            try figures.append(arena, f);
        }
        try rows.append(arena, .{
            .engine = e,
            .version = version,
            .round = er,
            .forced_gc = forced and any_ok,
            .settle_ms = settle,
            .control_delta = control_delta,
            .figures = figures.items,
        });
    }
    return .{ .round = r, .count = count, .cases = cases.items, .rows = rows.items };
}

/// A case's column heading.
fn caseLabel(workload: []const u8) []const u8 {
    const labels = [_][2][]const u8{
        .{ "elements.detached-div", "Div, kept in an array" },
        .{ "elements.attached-div", "Div, in the document" },
        .{ "elements.div-two-attributes", "Div, 2 attributes" },
        .{ "elements.text-node", "Text node" },
        .{ "elements.parser-span", "Span, parsed (innerHTML)" },
    };
    for (labels) |l| if (std.mem.eql(u8, l[0], workload)) return l[1];
    return workload;
}

/// Bytes per object: whole bytes, grouped ("2,740 B"), one decimal under 10.
fn writePerElement(w: W, b: f64) !void {
    if (@abs(b) >= 10) {
        if (b < 0) try w.writeAll("&minus;");
        try html.num(w, @intFromFloat(@round(@abs(b))));
    } else try w.print("{d:.1}", .{b});
    try w.writeAll(" B");
}

/// "Memory per element": Crane's row first, then each browser, bytes per object per case;
/// under each browser's figure, Crane's as a multiple of it; the JS heap's share where the
/// engine tells a page; the method under the table, from the rows themselves.
fn writeElementMemory(w: W, arena: Allocator, m: *const Model) !void {
    const t = (try elementTable(arena, m)) orelse return;
    if (t.rows.len == 0 or t.cases.len == 0) return;
    const crane_row: ?ElementRow = for (t.rows) |row| {
        if (row.engine == .crane) break row;
    } else null;
    try w.writeAll("<section id=\"memory-per-element\"><h2>Memory per element</h2>\n<p>What one kept node costs each engine, in bytes: the footprint of the engine&rsquo;s processes after ");
    try html.num(w, t.count);
    try w.writeAll(" nodes were made and kept, less the footprint before, less the same difference for a page that made none, divided by ");
    try html.num(w, t.count);
    try w.writeAll(". Lower is better. Under each browser&rsquo;s figure is Crane&rsquo;s as a multiple of it.</p>\n");
    try w.writeAll("<div class=\"table-wrap\"><table class=\"listing elements\"><thead><tr><th scope=\"col\">Engine</th><th scope=\"col\">Version</th>");
    for (t.cases) |c| {
        try w.writeAll("<th scope=\"col\" class=\"n\">");
        try html.text(w, caseLabel(c));
        try w.writeAll("</th>");
    }
    try w.writeAll("</tr></thead><tbody>\n");
    for (t.rows) |row| {
        try w.print("<tr><th scope=\"row\">{s}</th><td><code>", .{row.engine.label()});
        try html.text(w, row.version);
        try w.writeAll("</code>");
        if (row.round != t.round) try w.print(" (round {d})", .{row.round});
        try w.writeAll("</td>");
        for (row.figures, 0..) |f, i| {
            if (f.ok == 0 and f.runs > 0) {
                try w.writeAll("<td class=\"n fail\" title=\"");
                if (f.message) |msg| try html.text(w, msg[0..@min(msg.len, 300)]);
                try w.writeAll("\">");
                try w.writeAll(if (f.failure) |st| @tagName(st) else "failed");
                try w.writeAll("</td>");
                continue;
            }
            const b = f.bytes orelse {
                try w.writeAll("<td class=\"n\">&ndash;</td>");
                continue;
            };
            try w.writeAll("<td class=\"n\">");
            try writePerElement(w, b);
            if (f.mad) |d| if (@abs(b) > 0 and d / @abs(b) >= 0.05) {
                try w.writeAll(" <span class=\"quiet\" title=\"the runs' median absolute deviation\">&plusmn;");
                try writePerElement(w, d);
                try w.writeAll("</span>");
            };
            if (f.js_bytes) |j| {
                try w.writeAll("<br><span class=\"quiet\">JS heap ");
                try writePerElement(w, j);
                try w.writeAll("</span>");
            }
            if (!row.engine.isCrane()) if (crane_row) |cr| if (cr.figures[i].bytes) |cb| if (b > 0) {
                try w.print("<br><span class=\"quiet\">Crane {d:.1}&times;</span>", .{cb / b});
            };
            try w.writeAll("</td>");
        }
        try w.writeAll("</tr>\n");
    }
    try w.writeAll("</tbody></table></div>\n");
    try writeElementMethod(w, arena, t);
    try w.writeAll("</section>\n");
}

/// The method, as the rows say it was measured: which engines collected before each
/// reading and how, the idle time, the runs.
/// "a", "a and b", "a, b and c".
fn writeList(w: W, items: []const []const u8) !void {
    for (items, 0..) |item, i| {
        if (i > 0) try w.writeAll(if (i + 1 == items.len) " and " else ", ");
        try w.writeAll(item);
    }
}

fn writeElementMethod(w: W, arena: Allocator, t: ElementTable) !void {
    try w.writeAll("<p class=\"chart-note\">How: one case per page (<code>tests/perf/elements.json</code>), each page in a fresh launch, so memory one case freed cannot make another&rsquo;s read smaller. A page first makes everything but the nodes - a slot for each in an array, a host element, the markup to parse - so both readings hold it. The runner reads the footprint (phys_footprint, summed over the engine&rsquo;s processes, as everywhere on this page) when the page reports, and the page reports after ");
    // Who collected and how: Crane's builds by TestUtils.gc(), Chrome by gc(); the others none.
    var crane_builds: std.ArrayList([]const u8) = .empty;
    var chrome_forced = false;
    var none: std.ArrayList([]const u8) = .empty;
    for (t.rows) |row| {
        if (!row.forced_gc) {
            try none.append(arena, row.engine.label());
            continue;
        }
        switch (row.engine) {
            .crane, .crane_fast, .crane_base, .crane_control => try crane_builds.append(arena, row.engine.label()),
            .chrome => chrome_forced = true,
            .firefox, .safari, .lightpanda => try none.append(arena, row.engine.label()),
        }
    }
    const any_forced = crane_builds.items.len > 0 or chrome_forced;
    if (any_forced) {
        try w.writeAll("a full collection it asks for (");
        if (crane_builds.items.len > 0) {
            try w.writeAll("<code>TestUtils.gc()</code> twice in ");
            try writeList(w, crane_builds.items);
        }
        if (chrome_forced) {
            if (crane_builds.items.len > 0) try w.writeAll("; ");
            try w.writeAll("<code>gc()</code> twice in Chrome, launched with <code>--js-flags=--expose-gc</code>");
        }
        try w.writeAll(") and then ");
    }
    var settle: ?f64 = null;
    for (t.rows) |row| {
        if (row.settle_ms) |v| settle = v;
    }
    if (settle) |v| try w.print("{d:.1} s idle", .{v / 1000.0}) else try w.writeAll("an idle time");
    if (none.items.len > 0) {
        try w.writeAll("; ");
        try writeList(w, none.items);
        try w.writeAll(" let no page ask for a collection, so their readings come after the idle time alone");
    }
    try w.writeAll(". Each figure is the median over the runs");
    var min_runs: ?u32 = null;
    var max_runs: u32 = 0;
    for (t.rows) |row| for (row.figures) |f| {
        if (f.ok == 0) continue;
        if (min_runs == null or f.ok < min_runs.?) min_runs = f.ok;
        max_runs = @max(max_runs, f.ok);
    };
    if (min_runs) |lo| {
        if (lo == max_runs) try w.print(" ({d} each)", .{lo}) else try w.print(" ({d} to {d})", .{ lo, max_runs });
    }
    try w.writeAll(", with the runs&rsquo; median absolute deviation beside it where that is 5% or more. The JS heap is Chrome&rsquo;s <code>performance.memory.usedJSHeapSize</code> (launched with <code>--enable-precise-memory-info</code>), the only engine here that tells a page its heap.");
    // The engines that render give a node in the document a layout object and a computed
    // style; Crane and Lightpanda draw nothing. Said wherever one of them has a row.
    var rendering: std.ArrayList([]const u8) = .empty;
    for (t.rows) |row| switch (row.engine) {
        .chrome, .firefox, .safari => try rendering.append(arena, row.engine.label()),
        else => {},
    };
    if (rendering.items.len > 0) {
        try w.writeAll(" In the engines that render - ");
        try writeList(w, rendering.items);
        try w.writeAll(" - a node in the document also gets a layout object and a computed style, so their figures for the nodes in the document and the parsed ones include rendering, which Crane and Lightpanda do not do; the nodes kept in an array, outside the document, are the DOM alone in every engine.");
    }
    // An engine whose own footprint moved a lot over the control's steps: its figures carry
    // that drift's spread (Firefox frees memory while a fresh page idles).
    for (t.rows) |row| {
        const cd = row.control_delta orelse continue;
        if (t.count == 0 or @abs(cd) / @as(f64, @floatFromInt(t.count)) < 50) continue;
        try w.print(" {s}&rsquo;s footprint moved by {d:.1} MB between the two readings of the page that made nothing (the median over its runs), which its figures have subtracted, so they carry that drift&rsquo;s spread.", .{ row.engine.label(), cd / (1024.0 * 1024.0) });
    }
    try w.writeAll("</p>\n");
}

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
    // The progress: Crane's time and memory against its first round's.
    if (try sinceFirst(arena, m)) |since| {
        figures.since_time = if (since.time_ratio) |r| percent(r) else null;
        figures.since_memory = if (since.memory_ratio) |r| percent(r) else null;
    }
    const png = try card.render(arena, figures);
    const card_ref = try std.fmt.allocPrint(arena, "card.png?v={x:0>8}", .{@as(u32, @truncate(std.hash.Wyhash.hash(0, png)))});

    var out: Io.Writer.Allocating = .init(arena);
    const w = &out.writer;
    try writePage(w, arena, m, &vs, o, card_ref);
    return .{ .index_html = out.written(), .card_png = png };
}

fn writePage(w: W, arena: Allocator, m: *const Model, vs: []const Versus, o: Options, card_ref: []const u8) !void {
    const since = try sinceFirst(arena, m);
    try w.writeAll(
        \\<!doctype html>
        \\<html lang="en">
        \\<head>
        \\<meta charset="utf-8">
        \\<meta name="viewport" content="width=device-width, initial-scale=1">
        \\
    );
    try w.print("<title>Crane performance: round {d}</title>\n<meta name=\"description\" content=\"", .{m.latest_round});
    try writeDescription(w, m, vs, since);
    try w.writeAll("\">\n<meta name=\"color-scheme\" content=\"light dark\">\n");
    try w.print("<link rel=\"stylesheet\" href=\"{s}site.css\">\n<link rel=\"icon\" href=\"data:,\">\n", .{o.assets});
    try writeSocial(w, m, vs, since, o, card_ref);
    try w.writeAll(style);
    try w.writeAll("</head>\n<body>\n<main class=\"doc perf\" id=\"main\">\n<header class=\"head\">\n<h1>Crane <span class=\"h1-rest\">Performance</span></h1>\n");
    try w.print("<p class=\"subtitle\">Round {d}: Crane beside Chrome, Firefox, Safari and Lightpanda, the same pages in every engine, CPU and memory.", .{m.latest_round});
    if (hasEngine(m, m.latest_round, .crane_fast)) try w.writeAll(" Crane is its release build, ReleaseSafe; a ReleaseFast build runs beside it as a column of its own.");
    if (carriedFrom(m, m.latest_round)) |r| try w.print(" Only Crane ran in this round; the browsers&rsquo; rows are round {d}&rsquo;s (a browser runs again when it updates).", .{r});
    if (craneTarget(m, m.latest_round)) |t| {
        try w.writeAll(" Crane is built for one fixed CPU, <code>");
        try html.text(w, t);
        try w.writeAll("</code>, never its build host&rsquo;s.");
    }
    if (hostOf(m)) |h| {
        try w.writeAll(" Measured on ");
        try html.text(w, h.cpu);
        try w.print(", {d} cores, ", .{h.cores});
        try html.text(w, h.os);
        try w.writeAll(".");
    }
    try w.print(" <a href=\"{s}\">WPT results</a>.</p>\n</header>\n", .{o.assets});

    try writeHeadline(w, vs, m.latest_round);
    try writeProgress(w, arena, m);
    try writeElementMemory(w, arena, m);
    try writeDrift(w, arena, m);
    try writeBaseTip(w, arena, m);
    if (o.remeasured) |rm| try writeRemeasured(w, arena, m, rm);
    try writeReleaseFast(w, arena, m);
    try writeEngines(w, arena, m);
    try writeRound(w, arena, m);
    try writeCraneHistory(w, arena, m);
    try writeHistory(w, arena, m);
    try writeCraneOnly(w, arena, m);
    try writeMethod(w, hasEngine(m, m.latest_round, .crane_fast), craneTarget(m, m.latest_round));
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
    \\.perf { --trend: #2a78d6; }
    \\@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) .perf { --trend: #3987e5; } }
    \\:root[data-theme="dark"] .perf { --trend: #3987e5; }
    \\.perf .trend-pair { display: grid; grid-template-columns: repeat(auto-fit, minmax(16rem, 1fr)); gap: 0 2.5rem; max-width: 52rem; }
    \\.perf .trend { margin: 1rem 0 0; }
    \\.perf .trend-title { margin: 0 0 0.35rem; font: 400 0.9rem/1.35 var(--sans); color: var(--ink-2); }
    \\.perf .trend-title strong { color: var(--ink); font-weight: 600; }
    \\.trend-svg .trend-line { fill: none; stroke: var(--trend); stroke-width: 2; stroke-linejoin: round; stroke-linecap: round; }
    \\.trend-svg .trend-dot { fill: var(--trend); stroke: var(--paper); stroke-width: 2; }
    \\.trend-svg .ref { stroke: var(--ink-2); stroke-width: 1; }
    \\.trend-svg .trend-value { font-size: 12px; font-weight: 600; fill: var(--ink); }
    \\.trend-svg .x-round { fill: var(--ink); font-weight: 600; }
    \\.trend-svg .x-title { font-size: 10px; }
    \\.trend-svg .x-date { font-size: 10px; }
    \\.trend-svg .x-commit { font-family: var(--mono); font-size: 9.5px; }
    \\.perf .chart-note, .perf .gap-legend { max-width: var(--measure); font: 400 0.88rem/1.45 var(--sans); color: var(--ink-2); }
    \\.perf .gap td.n { color: var(--ink); }
    \\.perf .gap td.ratio-good { color: var(--pass, #2e7d32); } .perf .gap td.ratio-bad { color: var(--fail, #b3261e); }
    \\.perf .gap thead th[scope="colgroup"] { text-align: center; }
    \\.perf .gap-wrap { display: inline-block; max-width: 100%; max-height: none; vertical-align: top; }
    \\.perf .listing.gap { width: auto; }
    \\.perf .listing.gap tbody th { padding-right: 2rem; }
    \\@media (max-width: 52rem) {
    \\  .perf .gap-wrap { display: block; }
    \\  .perf .listing.gap { width: 100%; }
    \\  .perf .listing.gap tbody tr { display: block; padding: 0.5rem 0.6rem; }
    \\  .perf .listing.gap tbody th { display: block; margin-bottom: 0.3rem; padding: 0; }
    \\  .perf .listing.gap tbody td { display: flex; align-items: baseline; gap: 0.45rem; padding: 0.12rem 0; }
    \\  .perf .listing.gap tbody td::before { content: attr(data-label); margin-right: auto; color: var(--ink-2); }
    \\}
    \\.spark { width: 96px; height: 26px; }
    \\.spark .spark-line { stroke: var(--ink-2); stroke-width: 1.5; }
    \\.spark .spark-dot { fill: var(--ink); }
    \\.perf .round-notes { font: 400 0.92rem/1.45 var(--sans); }
    \\</style>
    \\
;

/// The earliest round some browser's rows in `round` come from, when any
/// come from an earlier round (`Model.standing`).
fn carriedFrom(m: *const Model, round: u32) ?u32 {
    var out: ?u32 = null;
    for (browsers) |b| {
        const r = m.standing(round, b) orelse continue;
        if (r != round and (out == null or r < out.?)) out = r;
    }
    return out;
}

/// The CPU target `round`'s Crane rows name (`Engine.target_cpu`), if any.
fn craneTarget(m: *const Model, round: u32) ?[]const u8 {
    for (m.cells) |c| if (c.round == round and c.engine == .crane) if (c.engine_info.target_cpu) |t| return t;
    return null;
}

fn hostOf(m: *const Model) ?journal.Host {
    for (m.cells) |c| if (c.round == m.latest_round) return c.host;
    return null;
}

fn writeDescription(w: W, m: *const Model, vs: []const Versus, since: ?Versus) !void {
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
    try w.writeAll(" (geometric means over the workloads both ran; lower is better for Crane).");
    if (since) |sv| if (sv.time_ratio) |t| {
        try w.print(" Since round {d}: {d}% of its time", .{ sv.round.?, percent(t) });
        if (sv.memory_ratio) |mr| try w.print(" and {d}% of its memory", .{percent(mr)});
        try w.writeAll(".");
    };
    try w.writeAll(" Crane is a headless web platform engine in Zig.");
}

fn writeSocial(w: W, m: *const Model, vs: []const Versus, since: ?Versus, o: Options, card_ref: []const u8) !void {
    try w.writeAll("<link rel=\"canonical\" href=\"");
    try html.text(w, o.site_url);
    try w.writeAll("performance/\">\n<meta property=\"og:type\" content=\"website\">\n<meta property=\"og:site_name\" content=\"Crane\">\n");
    try w.print("<meta property=\"og:title\" content=\"Crane performance: round {d}\">\n<meta property=\"og:description\" content=\"", .{m.latest_round});
    try writeDescription(w, m, vs, since);
    try w.writeAll("\">\n<meta property=\"og:url\" content=\"");
    try html.text(w, o.site_url);
    try w.writeAll("performance/\">\n<meta property=\"og:image\" content=\"");
    try html.text(w, o.site_url);
    try w.writeAll("performance/");
    try html.text(w, card_ref);
    try w.writeAll("\">\n<meta property=\"og:image:type\" content=\"image/png\">\n<meta property=\"og:image:width\" content=\"1200\">\n<meta property=\"og:image:height\" content=\"630\">\n");
    try w.writeAll("<meta property=\"og:image:alt\" content=\"Crane's time and memory as a percentage of Chrome's, Firefox's, Safari's and Lightpanda's.\">\n");
    try w.print("<meta name=\"twitter:card\" content=\"summary_large_image\">\n<meta name=\"twitter:title\" content=\"Crane performance: round {d}\">\n<meta name=\"twitter:description\" content=\"", .{m.latest_round});
    try writeDescription(w, m, vs, since);
    try w.writeAll("\">\n<meta name=\"twitter:image\" content=\"");
    try html.text(w, o.site_url);
    try w.writeAll("performance/");
    try html.text(w, card_ref);
    try w.writeAll("\">\n");
}

fn ratioClass(r: f64) []const u8 {
    return if (r <= 1.0) "ratio-good" else "ratio-bad";
}

fn writeHeadline(w: W, vs: []const Versus, round: u32) !void {
    try w.writeAll("<section id=\"headline\"><h2>Crane against each browser</h2>\n<p>Crane&rsquo;s time and memory as a percentage of the browser&rsquo;s: the geometric mean, over the workloads both engines ran, of Crane&rsquo;s figure divided by the browser&rsquo;s. Below 100% Crane uses less. Start-up and the harness&rsquo;s own floor are rows of their own below, not in these figures.</p>\n");
    try w.writeAll("<div class=\"table-wrap\"><table class=\"listing\"><thead><tr><th scope=\"col\">Browser</th><th scope=\"col\">Version</th><th scope=\"col\" class=\"n\">Time</th><th scope=\"col\" class=\"n\">Workloads</th><th scope=\"col\" class=\"n\">Memory</th><th scope=\"col\" class=\"n\">Workloads</th></tr></thead><tbody>\n");
    for (vs) |v| {
        try w.print("<tr><th scope=\"row\">{s}</th><td>", .{v.browser.label()});
        if (v.version) |ver| try html.text(w, ver) else try w.writeAll("not run");
        // A browser's rows from an earlier round (a Crane-only round).
        if (v.version != null) if (v.round) |r| if (r != round) try w.print(" (round {d})", .{r});
        try w.writeAll("</td>");
        if (v.time_ratio) |r| try w.print("<td class=\"n {s}\">{d}%</td>", .{ ratioClass(r), percent(r) }) else try w.writeAll("<td class=\"n\">&ndash;</td>");
        try w.print("<td class=\"n\">{d}</td>", .{v.time_n});
        if (v.memory_ratio) |r| try w.print("<td class=\"n {s}\">{d}%</td>", .{ ratioClass(r), percent(r) }) else try w.writeAll("<td class=\"n\">&ndash;</td>");
        try w.print("<td class=\"n\">{d}</td></tr>\n", .{v.memory_n});
    }
    try w.writeAll("</tbody></table></div></section>\n");
}

/// Crane's progress (`progress`), from the second round on, in two parts (the user, 2026-11-07:
/// the chart of one line per browser with a CPU-target point "is confusing for tracking Crane's
/// progress"):
/// - "Crane over time", first: two small charts, time and memory, ONE line each - Crane's
///   geometric mean as a share of its first round's, a point per measurement round labelled with
///   its value (`chart.trendChart`); a footnote, never a point, for a round that changed the CPU
///   target (`targetChanges`); and what each round changed, with its figures (`round_notes`);
/// - "The gap to the browsers": a table of Crane's time and memory as a multiple of each
///   browser's, round by round, against each browser's rows as they stood (`Model.standing`, the
///   headline's rows), coloured by the change from the round before (`changeOf`).
fn writeProgress(w: W, arena: Allocator, m: *const Model) !void {
    const pts = try progress(arena, m);
    if (pts.len < 2) return;
    const first = pts[0].round;
    try w.print("<section id=\"progress\"><h2>Progress</h2>\n<h3>Crane over time</h3>\n<p>Crane&rsquo;s own time and memory in each measurement round as a share of round {d}&rsquo;s: the geometric mean, over the workloads both rounds ran, of each workload&rsquo;s figure over its round-{d} figure (memory is the steady footprint). Round {d} is 100%; lower is better.</p>\n<div class=\"trend-pair\">\n", .{ first, first, first });
    var cpoints: std.ArrayList(chart.Point) = .empty;
    for (pts) |p| try cpoints.append(arena, .{ .label = try std.fmt.allocPrint(arena, "Round {d}", .{p.round}), .short = try std.fmt.allocPrint(arena, "{d}", .{p.round}), .date = p.date, .commit = p.commit });
    for ([_]Measure{ .time, .steady }) |measure| {
        const what = if (measure == .time) "time" else "memory";
        var values: std.ArrayList(?f64) = .empty;
        var titles: std.ArrayList([]const u8) = .empty;
        for (pts) |p| {
            const r = if (measure == .time) p.since.time_ratio else p.since.memory_ratio;
            const n = if (measure == .time) p.since.time_n else p.since.memory_n;
            try values.append(arena, r);
            try titles.append(arena, if (r) |x| try std.fmt.allocPrint(arena, "Round {d}, {s}, Crane {s}: {d:.1}% of round {d}'s {s} (over {d} workloads)", .{ p.round, p.date, p.commit, x * 100, first, what, n }) else "");
        }
        try w.print("<figure class=\"chart trend\"><figcaption class=\"trend-title\"><strong>{s}</strong> as a share of round {d}&rsquo;s &middot; lower is better</figcaption>", .{ if (measure == .time) "Time" else "Memory", first });
        const aria = try std.fmt.allocPrint(arena, "Crane's {s} as a share of round {d}'s over {d} rounds, from round {d} to round {d}; lower is better. The figures are in the list below.", .{ what, first, pts.len, first, pts[pts.len - 1].round });
        try chart.trendChart(w, cpoints.items, .{ .aria = aria, .values = values.items, .titles = titles.items, .x_title = "Round" });
        try w.writeAll("</figure>\n");
    }
    try w.writeAll("</div>\n");
    try writeTargetNotes(w, try targetChanges(arena, m));
    try w.writeAll("<ul class=\"round-notes\">\n");
    for (pts, 0..) |p, i| {
        try w.print("<li><strong>Round {d}</strong>, ", .{p.round});
        try html.text(w, p.date);
        try w.writeAll(", Crane <code>");
        try html.text(w, p.commit);
        try w.writeAll("</code> for <code>");
        try html.text(w, p.target orelse "a CPU not recorded");
        try w.writeAll("</code>");
        if (i == 0) try w.writeAll(", the reference (100%)") else {
            try w.writeAll(", time ");
            try writePercent1(w, p.since.time_ratio);
            try w.writeAll(" and memory ");
            try writePercent1(w, p.since.memory_ratio);
            try w.print(" of round {d}&rsquo;s (over {d} and {d} workloads)", .{ first, p.since.time_n, p.since.memory_n });
        }
        if (roundNote(p.round)) |note| {
            try w.writeAll(": ");
            try html.text(w, note);
        } else try w.writeAll(".");
        try w.writeAll("</li>\n");
    }
    try w.writeAll("</ul>\n");
    try writeGap(w, arena, pts);
    try w.writeAll("</section>\n");
}

/// Whether a geometric mean of one build over another is within the noise limit (`drift_limit`).
fn withinNoise(ratio: ?f64) bool {
    const r = ratio orelse return false;
    return @abs(r - 1.0) <= drift_limit;
}

/// The footnote beside the progress charts for each round that changed the CPU target
/// (`targetChanges`): a methodology control, said in a sentence, never drawn as a point.
fn writeTargetNotes(w: W, changes: []const TargetChange) !void {
    for (changes) |c| {
        try w.print("<p class=\"chart-note\">From round {d} Crane is built for one fixed CPU target, <code>", .{c.round});
        try html.text(w, c.target);
        try w.print("</code>; re-measuring round {d}&rsquo;s source for it changed time by ", .{c.source_round});
        try writeTimes3(w, c.versus.time_ratio);
        try w.writeAll(" and memory by ");
        try writeTimes3(w, c.versus.memory_ratio);
        if (withinNoise(c.versus.time_ratio) and withinNoise(c.versus.memory_ratio))
            try w.print(", within noise (both within {d:.0}%).</p>\n", .{drift_limit * 100})
        else
            try w.print(", beyond the {d:.0}% noise limit.</p>\n", .{drift_limit * 100});
    }
}

fn writeTimes3(w: W, ratio: ?f64) !void {
    if (ratio) |r| try w.print("{d:.3}&times;", .{r}) else try w.writeAll("&ndash;");
}

/// "The gap to the browsers": per browser with any figure, Crane's time and memory as a multiple
/// of the browser's in each round (the headline's `compare`, against the rows standing then).
fn writeGap(w: W, arena: Allocator, pts: []const ProgressPoint) !void {
    try w.writeAll("<h3>The gap to the browsers</h3>\n<p>Crane&rsquo;s time and memory as a multiple of each browser&rsquo;s, round by round: the headline&rsquo;s geometric means, each round against the browsers&rsquo; rows as they stood then (each browser&rsquo;s last-measured rows).</p>\n");
    try w.print("<p class=\"gap-legend\">1.00&times; = the browser&rsquo;s own time (or memory); lower is better. Green: lower than the round before; red: higher; a change within {d:.0}%, the drift control&rsquo;s noise limit, is not coloured.</p>\n", .{drift_limit * 100});
    const n = pts.len;
    try w.print("<div class=\"table-wrap gap-wrap\"><table class=\"listing gap\"><thead><tr><th scope=\"col\" rowspan=\"2\">Browser</th><th scope=\"colgroup\" colspan=\"{d}\" class=\"n\">Time</th><th scope=\"colgroup\" colspan=\"{d}\" class=\"n\">Memory</th></tr>\n<tr>", .{ n, n });
    for (0..2) |_| for (pts) |p| try w.print("<th scope=\"col\" class=\"n\">Round {d}</th>", .{p.round});
    try w.writeAll("</tr></thead><tbody>\n");
    for (browsers, 0..) |b, bi| {
        const any = for (pts) |p| {
            if (p.vs[bi].time_ratio != null or p.vs[bi].memory_ratio != null) break true;
        } else false;
        if (!any) continue;
        // The row names the browser as it stands in the latest round; a cell whose rows were
        // another version says so in its tooltip.
        const latest_version = pts[n - 1].vs[bi].version;
        try w.print("<tr><th scope=\"row\">{s}", .{b.label()});
        if (latest_version) |v| {
            try w.writeAll(" <span class=\"quiet\">");
            try html.text(w, v);
            try w.writeAll("</span>");
        }
        try w.writeAll("</th>");
        for ([_]Measure{ .time, .steady }) |measure| {
            for (pts, 0..) |p, i| {
                const v = p.vs[bi];
                const pick = struct {
                    fn f(x: Versus, ms: Measure) ?f64 {
                        return if (ms == .time) x.time_ratio else x.memory_ratio;
                    }
                }.f;
                const label = try std.fmt.allocPrint(arena, "{s}, round {d}", .{ if (measure == .time) "Time" else "Memory", p.round });
                var title: []const u8 = "";
                if (v.version) |ver| if (latest_version == null or !std.mem.eql(u8, ver, latest_version.?)) {
                    title = try std.fmt.allocPrint(arena, "against {s} {s}, round {d}'s rows", .{ b.label(), ver, v.round orelse p.round });
                };
                try writeGapCell(w, label, title, pick(v, measure), if (i == 0) null else pick(pts[i - 1].vs[bi], measure));
            }
        }
        try w.writeAll("</tr>\n");
    }
    try w.writeAll("</tbody></table></div>\n");
}

/// One cell of the gap: "5.97x", from the second round on green when lower than the round before,
/// red when higher, uncoloured within the noise limit (`changeOf`). What it was is the column beside
/// it, never repeated in the cell (the integrator, 2026-11-07).
fn writeGapCell(w: W, label: []const u8, title: []const u8, cur: ?f64, prev: ?f64) !void {
    const c = cur orelse {
        try w.writeAll("<td class=\"n\" data-label=\"");
        try html.text(w, label);
        try w.writeAll("\">&ndash;</td>");
        return;
    };
    const class = switch (changeOf(prev, c)) {
        .better => "n ratio-good",
        .worse => "n ratio-bad",
        .none, .steady => "n",
    };
    try w.print("<td class=\"{s}\" data-label=\"", .{class});
    try html.text(w, label);
    try w.writeAll("\"");
    if (title.len > 0) {
        try w.writeAll(" title=\"");
        try html.text(w, title);
        try w.writeAll("\"");
    }
    try w.print(">{d:.2}&times;</td>", .{c});
}

fn writePercent1(w: W, ratio: ?f64) !void {
    if (ratio) |r| try w.print("{d:.1}%", .{r * 100}) else try w.writeAll("&ndash;");
}

/// A Crane-only round's drift control (`controlDrift`): the binary an
/// earlier round measured, run again in this round's window, against that
/// round's rows - within noise, or this round's rows are not comparable with
/// the browsers' from that round. And where the round has a base of the
/// control's commit for another CPU target, what that target alone did
/// (`targetAlone`).
fn writeDrift(w: W, arena: Allocator, m: *const Model) !void {
    const round = m.latest_round;
    const cd = (try controlDrift(arena, m, round)) orelse return;
    try w.writeAll("<section id=\"drift\"><h2>Drift control</h2>\n<p>Crane control is the binary <code>");
    try html.text(w, cd.version);
    try w.writeAll("</code>");
    if (cd.target_cpu) |t| {
        try w.writeAll(", built for <code>");
        try html.text(w, t);
        try w.writeAll("</code>,");
    }
    const earlier = cd.earlier_round orelse {
        try w.writeAll(" run in this round&rsquo;s window, but no earlier round measured these bytes (SHA-256 <code>");
        try html.text(w, cd.sha256[0..@min(cd.sha256.len, 12)]);
        try w.writeAll("</code>): <strong class=\"fail\">no drift control</strong>.</p>\n</section>\n");
        return;
    };
    const d = cd.drift;
    try w.print(" which round {d} measured as Crane, run again alternating with this round&rsquo;s Crane builds. Its time was ", .{earlier});
    try writePercent1(w, d.time_ratio);
    try w.writeAll(" and its memory ");
    try writePercent1(w, d.memory_ratio);
    try w.print(" of round {d}&rsquo;s (geometric means over {d} and {d} workloads): ", .{ earlier, d.time_n, d.memory_n });
    try w.writeAll(if (d.within) "<strong>within noise</strong>" else "<strong class=\"fail\">not within noise</strong>");
    try w.print(" (both means within {d:.0}% of 100%; {d} workload{s} outside {s} own band of 10% or three times the runs&rsquo; spread). ", .{ drift_limit * 100, d.outside, if (d.outside == 1) "" else "s", if (d.outside == 1) "its" else "their" });
    try w.print("Only a control within noise lets this round&rsquo;s rows stand beside the browsers&rsquo; round-{d} rows.</p>\n", .{earlier});
    const ta = try targetAlone(arena, m, round);
    if (ta) |t| {
        try w.writeAll("<p>Crane base is the same source built for <code>");
        try html.text(w, t.base_target);
        try w.writeAll("</code>, the control for <code>");
        try html.text(w, t.control_target);
        try w.writeAll("</code>: its time was ");
        try writePercent1(w, t.versus.time_ratio);
        try w.writeAll(" and its memory ");
        try writePercent1(w, t.versus.memory_ratio);
        try w.print(" of the control&rsquo;s (over {d} and {d} workloads) - what the CPU target alone did. Round {d}&rsquo;s Crane rows were the control&rsquo;s build.</p>\n", .{ t.versus.time_n, t.versus.memory_n, earlier });
    }
    try w.print("<div class=\"table-wrap\"><table class=\"listing\"><thead><tr><th scope=\"col\">Workload</th><th scope=\"col\" class=\"n\">Time, round {d}</th><th scope=\"col\" class=\"n\">Time, control</th><th scope=\"col\" class=\"n\">Control / round {d}</th><th scope=\"col\" class=\"n\">Memory, round {d}</th><th scope=\"col\" class=\"n\">Memory, control</th><th scope=\"col\" class=\"n\">Control / round {d}</th>", .{ earlier, earlier, earlier, earlier });
    if (ta != null) try w.writeAll("<th scope=\"col\" class=\"n\">Time, base</th><th scope=\"col\" class=\"n\">Base / control</th><th scope=\"col\" class=\"n\">Memory, base</th><th scope=\"col\" class=\"n\">Base / control</th>");
    try w.writeAll("</tr></thead><tbody>\n");
    for (try m.workloads(arena, round)) |wl| {
        if (!inHeadline(wl)) continue;
        const c = m.current(round, .crane_control, wl) orelse continue;
        if (c.kind == .gc_bench) continue;
        const r = m.current(earlier, .crane, wl);
        try w.writeAll("<tr><th scope=\"row\"><code>");
        try html.text(w, wl);
        try w.writeAll("</code></th>");
        try writeTimeCell(w, r);
        try writeTimeCell(w, c);
        try writeRatio(w, c.timeFigure(), if (r) |x| x.timeFigure() else null);
        try writeMemoryCell(w, r);
        try writeMemoryCell(w, c);
        try writeRatio(w, c.memoryFigure(), if (r) |x| x.memoryFigure() else null);
        if (ta != null) {
            const b = m.current(round, .crane_base, wl);
            try writeTimeCell(w, b);
            try writeRatio(w, if (b) |x| x.timeFigure() else null, c.timeFigure());
            try writeMemoryCell(w, b);
            try writeRatio(w, if (b) |x| x.memoryFigure() else null, c.memoryFigure());
        }
        try w.writeAll("</tr>\n");
    }
    try w.writeAll("</tbody></table></div></section>\n");
}

/// An engine as its build: Crane's release build is "Crane ReleaseSafe"
/// where another Crane build could be meant; the rest are their labels.
fn buildName(e: EngineName) []const u8 {
    return switch (e) {
        .crane => "Crane ReleaseSafe",
        else => e.label(),
    };
}

/// Which engines a re-measurement covers, and how the control compares:
/// the page says so, with each workload's ratio.
fn writeRemeasured(w: W, arena: Allocator, m: *const Model, rm: Remeasured) !void {
    const round = m.latest_round;
    const d = try drift(arena, m, rm.control, round, rm.engine);
    try w.writeAll("<section id=\"remeasured\"><h2>Re-measured</h2>\n<p>");
    for (rm.engines, 0..) |e, i| {
        if (i > 0) try w.writeAll(if (i + 1 == rm.engines.len) " and " else ", ");
        try w.writeAll(e.label());
    }
    const control_name = buildName(rm.engine);
    try w.print(" ran again in a second window, alternating with {s} as a drift control; this round&rsquo;s rows of ", .{control_name});
    for (rm.engines, 0..) |e, i| {
        if (i > 0) try w.writeAll(if (i + 1 == rm.engines.len) " and " else ", ");
        try w.writeAll(e.label());
    }
    try w.print(" are that window&rsquo;s, and {s}&rsquo;s are the first window&rsquo;s. In the second window {s}&rsquo;s time was ", .{ control_name, control_name });
    if (d.time_ratio) |r| try w.print("{d:.1}%", .{r * 100}) else try w.writeAll("&ndash;");
    try w.print(" and its memory ", .{});
    if (d.memory_ratio) |r| try w.print("{d:.1}%", .{r * 100}) else try w.writeAll("&ndash;");
    try w.print(" of the first window&rsquo;s (geometric means over {d} and {d} workloads): ", .{ d.time_n, d.memory_n });
    try w.writeAll(if (d.within) "<strong>within noise</strong>" else "<strong class=\"fail\">not within noise</strong>");
    try w.print(" (both means within {d:.0}% of 100%; {d} workload{s} outside {s} own band of 10% or three times the runs&rsquo; spread).</p>\n", .{ drift_limit * 100, d.outside, if (d.outside == 1) "" else "s", if (d.outside == 1) "its" else "their" });
    try w.print("<div class=\"table-wrap\"><table class=\"listing\"><thead><tr><th scope=\"col\">Workload</th><th scope=\"col\" class=\"n\">Time, first window</th><th scope=\"col\" class=\"n\">Time, control</th><th scope=\"col\" class=\"n\">Control / first</th><th scope=\"col\" class=\"n\">Memory, first window</th><th scope=\"col\" class=\"n\">Memory, control</th><th scope=\"col\" class=\"n\">Control / first</th></tr></thead><tbody>\n", .{});
    for (try rm.control.workloads(arena, round)) |wl| {
        if (!inHeadline(wl)) continue;
        const c = rm.control.current(round, rm.engine, wl) orelse continue;
        const r = m.current(round, rm.engine, wl);
        try w.writeAll("<tr><th scope=\"row\"><code>");
        try html.text(w, wl);
        try w.writeAll("</code></th>");
        try writeTimeCell(w, r);
        try writeTimeCell(w, c);
        try writeRatio(w, c.timeFigure(), if (r) |x| x.timeFigure() else null);
        try writeMemoryCell(w, r);
        try writeMemoryCell(w, c);
        try writeRatio(w, c.memoryFigure(), if (r) |x| x.memoryFigure() else null);
        try w.writeAll("</tr>\n");
    }
    try w.writeAll("</tbody></table></div></section>\n");
}

/// A Crane-only window's comparison (`baseTip`), where the round has a
/// base: each workload's tip / base ratio for time, steady and peak memory,
/// its noise band, and the two geometric means.
fn writeBaseTip(w: W, arena: Allocator, m: *const Model) !void {
    const bt = (try baseTip(arena, m, m.latest_round)) orelse return;
    try w.writeAll("<section id=\"base-tip\"><h2>Crane against its base</h2>\n<p>A Crane-only window: Crane at <code>");
    try html.text(w, bt.tip_version);
    try w.writeAll("</code> alternating with the earlier Crane at <code>");
    try html.text(w, bt.base_version);
    try w.writeAll("</code>, the same release build (ReleaseSafe), in the same runs");
    if (bt.rows.len > 0) {
        const tt = bt.rows[0].tip.engine_info.target_cpu;
        const bt_t = bt.rows[0].base.engine_info.target_cpu;
        if (tt != null and bt_t != null and std.mem.eql(u8, tt.?, bt_t.?)) {
            try w.writeAll(", both built for <code>");
            try html.text(w, tt.?);
            try w.writeAll("</code>: the comparison is the code&rsquo;s");
        }
    }
    try w.writeAll(". Its time was ");
    if (bt.time_ratio) |r| try w.print("{d:.1}%", .{r * 100}) else try w.writeAll("&ndash;");
    try w.writeAll(" and its memory ");
    if (bt.memory_ratio) |r| try w.print("{d:.1}%", .{r * 100}) else try w.writeAll("&ndash;");
    try w.print(" of the base&rsquo;s (geometric means over {d} and {d} workloads); {d} workload{s} outside {s} band of 10% or three times the runs&rsquo; spread.</p>\n", .{ bt.time_n, bt.memory_n, bt.outside.len, if (bt.outside.len == 1) "" else "s", if (bt.outside.len == 1) "its" else "their" });
    try w.writeAll("<div class=\"table-wrap\"><table class=\"listing\"><thead><tr><th scope=\"col\">Workload</th><th scope=\"col\" class=\"n\">Time, base</th><th scope=\"col\" class=\"n\">Time, tip</th><th scope=\"col\" class=\"n\">Tip / base</th><th scope=\"col\" class=\"n\">Steady, base</th><th scope=\"col\" class=\"n\">Steady, tip</th><th scope=\"col\" class=\"n\">Tip / base</th><th scope=\"col\" class=\"n\">Peak, base</th><th scope=\"col\" class=\"n\">Peak, tip</th><th scope=\"col\" class=\"n\">Tip / base</th><th scope=\"col\" class=\"n\">Band</th></tr></thead><tbody>\n");
    for (bt.rows) |row| {
        try w.writeAll("<tr><th scope=\"row\"><code>");
        try html.text(w, row.workload);
        try w.writeAll("</code>");
        if (row.outside) try w.writeAll(" <span class=\"fail\" title=\"outside its noise band\">moved</span>");
        try w.writeAll("</th>");
        for ([_]Measure{ .time, .steady, .peak }) |measure| {
            try writeMeasureCell(w, row.base, measure);
            try writeMeasureCell(w, row.tip, measure);
            try writeRatio(w, figureOf(row.tip, measure), figureOf(row.base, measure));
        }
        try w.print("<td class=\"n\">&plusmn;{d:.0}%</td></tr>\n", .{row.band * 100});
    }
    try w.writeAll("</tbody></table></div></section>\n");
}

/// Crane ReleaseFast against the release build (ReleaseSafe) and each
/// browser, where the round has it: what the ReleaseFast build buys. Never
/// the headline, which stays the ReleaseSafe build's.
fn writeReleaseFast(w: W, arena: Allocator, m: *const Model) !void {
    const round = m.latest_round;
    if (!hasEngine(m, round, .crane_fast)) return;
    try w.writeAll("<section id=\"release-fast\"><h2>Crane ReleaseFast</h2>\n<p>The same release build with only the optimize mode changed: Crane&rsquo;s Zig code and its C libraries ReleaseFast, no runtime safety checks and no C sanitizer, the same V8 and snapshot. Its time and memory as a percentage of the release build&rsquo;s (ReleaseSafe) and of each browser&rsquo;s, the same geometric means as above. The comparison above stays the release build&rsquo;s.</p>\n");
    try w.writeAll("<div class=\"table-wrap\"><table class=\"listing\"><thead><tr><th scope=\"col\">Against</th><th scope=\"col\">Version</th><th scope=\"col\" class=\"n\">Time</th><th scope=\"col\" class=\"n\">Workloads</th><th scope=\"col\" class=\"n\">Memory</th><th scope=\"col\" class=\"n\">Workloads</th></tr></thead><tbody>\n");
    const others = [_]EngineName{.crane} ++ browsers;
    for (others) |o| {
        const v = try compare(arena, m, round, .crane_fast, o);
        try w.print("<tr><th scope=\"row\">{s}</th><td>", .{if (o == .crane) "Crane ReleaseSafe" else o.label()});
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
        // engines here are the ones the pages ran in. A browser's rows from
        // an earlier round stand for this one (`Model.standing`): listed,
        // with that round.
        if (c.kind == .gc_bench) continue;
        if (c.round != m.latest_round and m.standing(m.latest_round, c.engine) != c.round) continue;
        const key = try std.fmt.allocPrint(arena, "{s}/{s}", .{ @tagName(c.engine), c.version });
        if (containsStr(seen.items, key)) continue;
        try seen.append(arena, key);
        const e = c.engine_info;
        try w.print("<tr><th scope=\"row\">{s}</th><td><code>", .{e.name.label()});
        try html.text(w, e.version);
        try w.writeAll("</code>");
        if (c.round != m.latest_round) try w.print(" (round {d}&rsquo;s rows)", .{c.round});
        try w.writeAll("</td><td>");
        try html.text(w, e.build);
        if (e.v8) |v8| {
            try w.writeAll("; V8 ");
            try html.text(w, v8);
        }
        if (e.optimize) |opt| {
            try w.writeAll("; ");
            try html.text(w, opt);
        }
        if (e.target_cpu) |t| {
            try w.writeAll("; for <code>");
            try html.text(w, t);
            try w.writeAll("</code>");
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
    if (cell.kind == .instances) try w.writeAll(" each");
    if (std.mem.eql(u8, cell.workload, "memory.page-growth")) {
        // The level; beside it, what each further page still keeps.
        if (cell.late_growth) |late| {
            try w.writeAll(" <span class=\"quiet\" title=\"the footprint's slope over the chain's second half: what each further page keeps\">");
            if (late >= 0) try w.writeAll("+");
            try writeBytes(w, late);
            try w.writeAll(" a page</span>");
        }
    }
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

const Measure = enum { time, steady, peak };

fn figureOf(c: *const Cell, measure: Measure) ?f64 {
    return switch (measure) {
        .time => c.timeFigure(),
        .steady => c.memoryFigure(),
        .peak => c.peakFigure(),
    };
}

fn writeMeasureCell(w: W, c: ?*const Cell, measure: Measure) !void {
    switch (measure) {
        .time => try writeTimeCell(w, c),
        .steady => try writeMemoryCell(w, c),
        .peak => {
            const cell = c orelse return w.writeAll("<td class=\"n\">&ndash;</td>");
            if (cell.ok == 0) return writeFailure(w, cell);
            const v = cell.peakFigure() orelse return w.writeAll("<td class=\"n\">&ndash;</td>");
            try w.writeAll("<td class=\"n\">");
            try writeBytes(w, v);
            try w.writeAll("</td>");
        },
    }
}

fn writeRound(w: W, arena: Allocator, m: *const Model) !void {
    const round = m.latest_round;
    const ws = try m.workloads(arena, round);
    const with_fast = hasEngine(m, round, .crane_fast);
    const with_base = hasEngine(m, round, .crane_base);
    try w.print("<section id=\"round\"><h2>Round {d}, workload by workload</h2>\n", .{round});
    try w.writeAll("<p>Time is per operation for a timed workload (the median sample divided by its operations) and per load for a page load; memory is the engine&rsquo;s whole process set (phys_footprint, summed) when the workload ended, or what each page or instance adds. The percentage beside a browser is Crane&rsquo;s figure as a share of it.");
    if (carriedFrom(m, round)) |r| try w.print(" The browsers&rsquo; figures are round {d}&rsquo;s.", .{r});
    try w.writeAll("</p>\n");
    for ([_]Measure{ .time, .steady, .peak }) |measure| {
        const is_time = measure == .time;
        try w.print("<h3>{s}</h3>\n<div class=\"table-wrap\"><table class=\"listing\"><thead><tr><th scope=\"col\">Workload</th><th scope=\"col\" class=\"n\">Crane</th>", .{switch (measure) {
            .time => "Time",
            .steady => "Memory, steady (after the workload, the page idle)",
            .peak => "Memory, peak (the most during the workload)",
        }});
        if (with_base) try w.writeAll("<th scope=\"col\" class=\"n\">Crane base</th><th scope=\"col\" class=\"n\">Crane / base</th>");
        if (with_fast) try w.writeAll("<th scope=\"col\" class=\"n\">Crane ReleaseFast</th><th scope=\"col\" class=\"n\">ReleaseFast / ReleaseSafe</th>");
        for (browsers) |b| try w.print("<th scope=\"col\" class=\"n\">{s}</th><th scope=\"col\" class=\"n\">Crane / {s}</th>", .{ b.label(), b.label() });
        try w.writeAll("</tr></thead><tbody>\n");
        for (ws) |wl| {
            const c = m.current(round, .crane, wl);
            const kind = if (c) |cc| cc.kind else blk: {
                for (browsers) |b| if (m.rowsFor(round, b, wl)) |bc| break :blk bc.kind;
                break :blk journal.Kind.timed;
            };
            if (kind == .gc_bench) continue;
            if (is_time and (kind == .idle or kind == .instances)) continue;
            if (!is_time and kind == .startup) continue;
            try w.writeAll("<tr><th scope=\"row\"><code>");
            try html.text(w, wl);
            try w.writeAll("</code></th>");
            try writeMeasureCell(w, c, measure);
            const cf: ?f64 = if (c) |cc| figureOf(cc, measure) else null;
            if (with_base) {
                const bc = m.current(round, .crane_base, wl);
                try writeMeasureCell(w, bc, measure);
                try writeRatio(w, cf, if (bc) |x| figureOf(x, measure) else null);
            }
            if (with_fast) {
                const fc = m.current(round, .crane_fast, wl);
                try writeMeasureCell(w, fc, measure);
                try writeRatio(w, if (fc) |x| figureOf(x, measure) else null, cf);
            }
            for (browsers) |b| {
                const bc = m.rowsFor(round, b, wl);
                try writeMeasureCell(w, bc, measure);
                const bf: ?f64 = if (bc) |x| figureOf(x, measure) else null;
                try writeRatio(w, cf, bf);
            }
            try w.writeAll("</tr>\n");
        }
        try w.writeAll("</tbody></table></div>\n");
    }
    try w.writeAll("</section>\n");
}

/// Crane (its release build, `crane`) round by round: each workload's time and steady memory in
/// every measurement round (`progress`), the latest round's over the first's, and its trend -
/// Crane's own rounds only, as in the progress charts (the user, 2026-11-07). What a round's CPU
/// target alone did to each workload is the drift control's table (`writeDrift`), not a step here.
fn writeCraneHistory(w: W, arena: Allocator, m: *const Model) !void {
    const pts = try progress(arena, m);
    if (pts.len < 2) return;
    const first = pts[0].round;
    const latest = pts[pts.len - 1].round;
    try w.print("<section id=\"crane-history\"><h2>Crane, round by round</h2>\n<p>Each workload&rsquo;s time per operation and steady memory for Crane&rsquo;s release build (ReleaseSafe) in every measurement round, round {d}&rsquo;s figure as a share of round {d}&rsquo;s, and its trend.", .{ latest, first });
    for (pts) |p| {
        try w.print(" Round {d}: <code>", .{p.round});
        try html.text(w, p.target orelse "target not recorded");
        try w.writeAll("</code>.");
    }
    if ((try targetAlone(arena, m, latest)) != null) try w.print(" What round {d}&rsquo;s CPU target alone did to each workload is in the <a href=\"#drift\">drift control</a>&rsquo;s table.", .{latest});
    try w.writeAll("</p>\n<div class=\"table-wrap\"><table class=\"listing\"><thead><tr><th scope=\"col\">Workload</th>");
    for ([_][]const u8{ "Time", "Memory" }) |what| {
        for (pts) |p| try w.print("<th scope=\"col\" class=\"n\">{s}, Round {d}</th>", .{ what, p.round });
        try w.print("<th scope=\"col\" class=\"n\">Since round {d}</th><th scope=\"col\">Trend</th>", .{first});
    }
    try w.writeAll("</tr></thead><tbody>\n");
    for (try m.workloads(arena, latest)) |wl| {
        const c = m.current(latest, .crane, wl) orelse continue;
        if (c.kind == .gc_bench) continue;
        const f = m.current(first, .crane, wl);
        try w.writeAll("<tr><th scope=\"row\"><code>");
        try html.text(w, wl);
        try w.writeAll("</code></th>");
        for ([_]Measure{ .time, .steady }) |measure| {
            var values: std.ArrayList(?f64) = .empty;
            for (pts) |p| {
                const cell = m.current(p.round, .crane, wl);
                try writeMeasureCell(w, cell, measure);
                try values.append(arena, if (cell) |x| figureOf(x, measure) else null);
            }
            try writeRatio(w, figureOf(c, measure), if (f) |x| figureOf(x, measure) else null);
            try w.writeAll("<td>");
            try chart.sparkline(w, try std.fmt.allocPrint(arena, "{s} {s} over the rounds", .{ wl, if (measure == .time) "time" else "memory" }), values.items);
            try w.writeAll("</td>");
        }
        try w.writeAll("</tr>\n");
    }
    try w.writeAll("</tbody></table></div></section>\n");
}

fn writeHistory(w: W, arena: Allocator, m: *const Model) !void {
    try w.writeAll("<section id=\"history\"><h2>History</h2>\n<p>Each workload&rsquo;s figures round by round. A browser updated between rounds is a new version: each version keeps its own row.</p>\n");
    try w.writeAll("<div class=\"table-wrap\"><table class=\"listing\"><thead><tr><th scope=\"col\">Workload</th><th scope=\"col\">Engine</th><th scope=\"col\">Version</th><th scope=\"col\" class=\"n\">Round</th><th scope=\"col\" class=\"n\">Time</th><th scope=\"col\" class=\"n\">CPU</th><th scope=\"col\" class=\"n\">Memory</th><th scope=\"col\" class=\"n\">Runs ok</th></tr></thead><tbody>\n");
    var all: std.ArrayList([]const u8) = .empty;
    for (m.rounds) |r| for (try m.workloads(arena, r)) |wl| if (!containsStr(all.items, wl)) try all.append(arena, wl);
    for (all.items) |wl| {
        for ([_]EngineName{ .crane, .crane_base, .crane_control, .crane_fast, .chrome, .firefox, .safari, .lightpanda }) |e| {
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
    try w.writeAll("<div class=\"table-wrap\"><table class=\"listing\"><thead><tr><th scope=\"col\">Row</th><th scope=\"col\" class=\"n\">Round</th><th scope=\"col\">Build</th><th scope=\"col\">Version</th><th scope=\"col\" class=\"n\">Instructions</th><th scope=\"col\" class=\"n\">Wall</th><th scope=\"col\" class=\"n\">Peak footprint</th><th scope=\"col\">Counters</th></tr></thead><tbody>\n");
    for (m.cells) |*c| {
        if (c.kind != .gc_bench) continue;
        try w.writeAll("<tr><th scope=\"row\"><code>");
        try html.text(w, c.workload);
        try w.print("</code></th><td class=\"n\">{d}</td><td>{s}</td><td><code>", .{ c.round, switch (c.engine) {
            .crane_fast => "ReleaseFast",
            .crane_base => "ReleaseSafe (base)",
            .crane_control => "ReleaseSafe (control)",
            else => "ReleaseSafe",
        } });
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

fn writeMethod(w: W, with_fast: bool, target: ?[]const u8) !void {
    try w.writeAll(
        \\<section id="method"><h2>How it is measured</h2>
        \\<p>Every engine opens the same pages from <code>tests/perf/</code>, served from loopback with cross-origin isolation (so every engine&rsquo;s clock is at its finest), each launch a fresh process with a fresh profile, the engines in alternating order on one quiet host. A page times each workload itself (<code>performance.now()</code> around a fixed number of operations, after warm-up runs) and reports through the benchmark server, which reads the engine&rsquo;s whole process set when each mark arrives: CPU time and instructions between a workload&rsquo;s first and last mark, phys_footprint (Activity Monitor&rsquo;s Memory) at each, and the peak a 50 ms sampler saw between them. Start-up - from launch to the first page&rsquo;s load - is its own row, so no other row includes it. Crane is its release build: ReleaseSafe throughout, libc malloc, V8 linked statically; rendering and layout are not Crane&rsquo;s, so no workload measures them. The full method is in <code>docs/performance.md</code>.</p>
        \\
    );
    if (with_fast) try w.writeAll("<p>Crane ReleaseFast is that build with only the optimize mode changed (<code>-Dwpt-runner-release-fast</code>: ReleaseFast throughout, no C sanitizer, the same V8 and snapshot), launched the same way and alternating with the other engines in the same runs.</p>\n");
    if (target) |t| {
        try w.writeAll("<p>Every Crane build is compiled for one fixed CPU, <code>");
        try html.text(w, t);
        try w.writeAll("</code> (<code>-Dcpu</code>), never its build host&rsquo;s: two builds of one source for two CPUs are two code layouts, and a sub-microsecond row can move about 15% between them. The browsers ship one build for every Apple Silicon Mac. The build records its target, every row carries it, and the runner refuses to compare Crane builds made for different CPUs.</p>\n");
    }
    try w.writeAll("</section>\n");
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
        .build = if (name.isCrane()) "release" else "stable",
        .commit = if (name.isCrane()) version else null,
        .optimize = if (name.isCrane()) "ReleaseSafe" else null,
        .v8 = if (name.isCrane()) "13.1.203 static" else null,
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

test "memory compares the steady footprint where it was read, and the peak beside it" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var r = try timed(a, 0, .crane, "abc", "dom.a", 0, 20, 1000);
    r.memory.?.footprint_settled = 600;
    r.memory.?.footprint_peak = 1500;
    const m = try build(a, &.{r});
    const c = m.current(0, .crane, "dom.a").?;
    try testing.expectEqual(@as(?f64, 600), c.memoryFigure());
    try testing.expectEqual(@as(?f64, 1500), c.peakFigure());
    const page = try render(a, &m, .{});
    try testing.expect(std.mem.indexOf(u8, page.index_html, "Memory, peak") != null);
}

test "page growth compares the footprint the chain levels off at, not a slope over its whole length" {
    // A chain's footprint rises while no collection runs, then levels off
    // once collections keep up. The slope over all its steps reads a later
    // knee as more growth: lane perf2 batch 7's tip was lower than its base
    // at every one of 30 steps, levelled off 1.2 MB lower and two pages
    // later - and its all-steps slope read 1.175 of the base's.
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var early: [30]u64 = @splat(0);
    var late: [30]u64 = @splat(0);
    for (0..30) |i| {
        // Base: +10 MB a page for 5 pages, then level at 50 MB. Tip: +8 MB a
        // page for 6 pages, then level at 48 MB - lower everywhere.
        const step: u64 = i;
        early[i] = (if (step < 5) step * 10 else 50) * 1_000_000;
        late[i] = (if (step < 6) step * 8 else 48) * 1_000_000;
    }
    var base = try timed(a, 2, .crane_base, "base", "memory.page-growth", 0, 10, 0);
    base.kind = .chain;
    base.series = &early;
    var tip = try timed(a, 2, .crane, "tip", "memory.page-growth", 0, 10, 0);
    tip.kind = .chain;
    tip.series = &late;
    const m = try build(a, &.{ base, tip });
    const b = m.current(2, .crane_base, "memory.page-growth").?;
    const t = m.current(2, .crane, "memory.page-growth").?;
    // The all-steps slope reads the tip as growing faster ...
    try testing.expect(t.growth.? > b.growth.?);
    // ... but the compared figure is the level, the median of the second
    // half of the steps: 48 MB against 50 MB.
    try testing.expectEqual(@as(?f64, 48_000_000), t.memoryFigure());
    try testing.expectEqual(@as(?f64, 50_000_000), b.memoryFigure());
    // What is still kept per page once levelled off: the second half's slope.
    try testing.expectApproxEqAbs(@as(f64, 0), t.late_growth.?, 1e-6);
    // A record without its series has no level: not measured.
    var bare = try timed(a, 2, .crane, "old", "memory.page-growth", 0, 10, 0);
    bare.kind = .chain;
    const mb = try build(a, &.{bare});
    try testing.expectEqual(@as(?f64, null), mb.current(2, .crane, "memory.page-growth").?.memoryFigure());
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

test "Crane ReleaseFast: its own column and its own comparison; the headline stays Crane ReleaseSafe" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const records = [_]journal.Record{
        try timed(a, 0, .crane, "abc", "dom.a", 0, 20, 100),
        try timed(a, 0, .crane_fast, "abc", "dom.a", 0, 10, 80),
        try timed(a, 0, .chrome, "157", "dom.a", 0, 10, 400),
        try timed(a, 0, .crane, "abc", "dom.b", 0, 8, 100),
        try timed(a, 0, .crane_fast, "abc", "dom.b", 0, 2, 50),
        try timed(a, 0, .chrome, "157", "dom.b", 0, 8, 400),
    };
    const m = try build(a, &records);
    // Same commit, two builds: two cells, never one.
    try testing.expectEqual(@as(?f64, 20), m.current(0, .crane, "dom.a").?.time_ms);
    try testing.expectEqual(@as(?f64, 10), m.current(0, .crane_fast, "dom.a").?.time_ms);
    // The headline is Crane ReleaseSafe against the browser: 20/10 and 8/8.
    const v = try versus(a, &m, 0, .chrome);
    try testing.expectApproxEqAbs(@as(f64, std.math.sqrt(2.0)), v.time_ratio.?, 1e-12);
    // What ReleaseFast buys: its figure over ReleaseSafe's, 10/20 and 2/8;
    // memory 80/100 and 50/100.
    const fast = try compare(a, &m, 0, .crane_fast, .crane);
    try testing.expectApproxEqAbs(@as(f64, std.math.sqrt(0.5 * 0.25)), fast.time_ratio.?, 1e-12);
    try testing.expectEqual(@as(usize, 2), fast.time_n);
    try testing.expectApproxEqAbs(@as(f64, std.math.sqrt(0.8 * 0.5)), fast.memory_ratio.?, 1e-12);
    try testing.expectEqualStrings("abc", fast.version.?);
    // And against a browser, beside the headline.
    const fast_chrome = try compare(a, &m, 0, .crane_fast, .chrome);
    try testing.expectApproxEqAbs(@as(f64, std.math.sqrt(1.0 * 0.25)), fast_chrome.time_ratio.?, 1e-12);

    const out = try render(a, &m, .{});
    const page = out.index_html;
    // Its own labelled column in the round's tables, with its ratio to the release build.
    try testing.expect(std.mem.indexOf(u8, page, "<th scope=\"col\" class=\"n\">Crane ReleaseFast</th>") != null);
    try testing.expect(std.mem.indexOf(u8, page, "ReleaseFast / ReleaseSafe") != null);
    try testing.expect(std.mem.indexOf(u8, page, "id=\"release-fast\"") != null);
    // The headline table and the description stay ReleaseSafe's: 141% of Chrome's time.
    try testing.expect(std.mem.indexOf(u8, page, "141% of Chrome's time") != null);
    const headline = page[std.mem.indexOf(u8, page, "id=\"headline\"").?..std.mem.indexOf(u8, page, "id=\"release-fast\"").?];
    try testing.expect(std.mem.indexOf(u8, headline, "ReleaseFast") == null);
    // History names it too.
    const history = page[std.mem.indexOf(u8, page, "id=\"history\"").?..];
    try testing.expect(std.mem.indexOf(u8, history, "<td>Crane ReleaseFast</td>") != null);
}

test "a round without Crane ReleaseFast has no column for it" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const records = [_]journal.Record{ try timed(a, 0, .crane, "abc", "dom.a", 0, 20, 100), try timed(a, 0, .chrome, "157", "dom.a", 0, 10, 400) };
    const m = try build(a, &records);
    const page = (try render(a, &m, .{})).index_html;
    try testing.expect(std.mem.indexOf(u8, page, "Crane ReleaseFast</th>") == null);
    try testing.expect(std.mem.indexOf(u8, page, "ReleaseFast / ReleaseSafe") == null);
    try testing.expect(std.mem.indexOf(u8, page, "id=\"release-fast\"") == null);
}

test "a re-measured engine: Crane's drift control against the first window, within noise or not" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    // The round as published: Crane from the first window, Safari from the second.
    const records = [_]journal.Record{
        try timed(a, 0, .crane, "abc", "dom.a", 0, 20, 100),
        try timed(a, 0, .crane, "abc", "dom.b", 0, 8, 200),
        try timed(a, 0, .safari, "27.2", "dom.a", 0, 10, 50),
        try timed(a, 0, .safari, "27.2", "dom.b", 0, 8, 50),
    };
    const m = try build(a, &records);
    // The second window's Crane rows: the drift control, never the round's.
    const steady = [_]journal.Record{
        try timed(a, 0, .crane, "abc", "dom.a", 0, 21, 102),
        try timed(a, 0, .crane, "abc", "dom.b", 0, 8, 200),
    };
    const control = try build(a, &steady);
    const d = try drift(a, &m, &control, 0, .crane);
    // time sqrt(21/20 * 8/8); memory sqrt(1.02 * 1)
    try testing.expectApproxEqAbs(@as(f64, std.math.sqrt(1.05)), d.time_ratio.?, 1e-12);
    try testing.expectEqual(@as(usize, 2), d.time_n);
    try testing.expectApproxEqAbs(@as(f64, std.math.sqrt(1.02)), d.memory_ratio.?, 1e-12);
    try testing.expect(d.within);
    try testing.expectEqual(@as(usize, 0), d.outside);
    // The control's rows change nothing in the round: Crane's cell is the first window's.
    try testing.expectEqual(@as(?f64, 20), m.current(0, .crane, "dom.a").?.time_ms);

    const page = (try render(a, &m, .{ .remeasured = .{ .engines = &.{.safari}, .control = &control } })).index_html;
    const i = std.mem.indexOf(u8, page, "id=\"remeasured\"").?;
    const section = page[i .. i + std.mem.indexOf(u8, page[i..], "</section>").?];
    try testing.expect(std.mem.indexOf(u8, section, "Safari") != null);
    // The control is named as the build it is, never a bare "Crane".
    try testing.expect(std.mem.indexOf(u8, section, "alternating with Crane ReleaseSafe as a drift control") != null);
    try testing.expect(std.mem.indexOf(u8, section, "Crane&rsquo;s") == null);
    try testing.expect(std.mem.indexOf(u8, section, "0 workloads outside") != null);
    try testing.expect(std.mem.indexOf(u8, section, "within noise") != null);
    try testing.expect(std.mem.indexOf(u8, section, "not within noise") == null);
    try testing.expect(std.mem.indexOf(u8, section, "<code>dom.a</code>") != null);
    // Without a re-measurement, no such section.
    try testing.expect(std.mem.indexOf(u8, (try render(a, &m, .{})).index_html, "id=\"remeasured\"") == null);

    // A control that drifted: Crane 50% slower in the second window.
    const drifted = [_]journal.Record{
        try timed(a, 0, .crane, "abc", "dom.a", 0, 30, 100),
        try timed(a, 0, .crane, "abc", "dom.b", 0, 12, 200),
    };
    const bad = try build(a, &drifted);
    const dd = try drift(a, &m, &bad, 0, .crane);
    try testing.expect(!dd.within);
    try testing.expectEqual(@as(usize, 2), dd.outside);
    const bad_page = (try render(a, &m, .{ .remeasured = .{ .engines = &.{.safari}, .control = &bad } })).index_html;
    try testing.expect(std.mem.indexOf(u8, bad_page, "not within noise") != null);
    try testing.expect(std.mem.indexOf(u8, bad_page, "2 workloads outside") != null);

    // One workload outside its band: "1 workload", singular.
    const one_off = [_]journal.Record{
        try timed(a, 0, .crane, "abc", "dom.a", 0, 30, 100),
        try timed(a, 0, .crane, "abc", "dom.b", 0, 8, 200),
    };
    const one = try build(a, &one_off);
    try testing.expectEqual(@as(usize, 1), (try drift(a, &m, &one, 0, .crane)).outside);
    const one_page = (try render(a, &m, .{ .remeasured = .{ .engines = &.{.safari}, .control = &one } })).index_html;
    try testing.expect(std.mem.indexOf(u8, one_page, "1 workload outside") != null);
    try testing.expect(std.mem.indexOf(u8, one_page, "1 workloads") == null);
}

test "a Crane-only window: the tip against its base per workload, time, steady and peak, with noise bands" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    // dom.a: the tip 4x faster, memory the same; dom.b: unchanged (within
    // noise); dom.c: memory 30% lower, peak lower; startup: its own row.
    var records: std.ArrayList(journal.Record) = .empty;
    for ([_]u32{ 0, 1, 2 }) |run| {
        try records.append(a, try timed(a, 1, .crane_base, "9b0f1b1f382", "dom.a", run, 40, 100));
        try records.append(a, try timed(a, 1, .crane, "d0d8be54612", "dom.a", run, 10, 100));
        try records.append(a, try timed(a, 1, .crane_base, "9b0f1b1f382", "dom.b", run, 10, 100));
        try records.append(a, try timed(a, 1, .crane, "d0d8be54612", "dom.b", run, 10.5, 101));
        var cb = try timed(a, 1, .crane_base, "9b0f1b1f382", "dom.c", run, 10, 1000);
        cb.memory.?.footprint_peak = 2000;
        var ct = try timed(a, 1, .crane, "d0d8be54612", "dom.c", run, 10, 700);
        ct.memory.?.footprint_peak = 1000;
        try records.append(a, cb);
        try records.append(a, ct);
    }
    var sb = try timed(a, 1, .crane_base, "9b0f1b1f382", "startup.idle-page", 0, 100, 100);
    sb.kind = .startup;
    sb.wall_ms = try a.dupe(f64, &.{100});
    var st = try timed(a, 1, .crane, "d0d8be54612", "startup.idle-page", 0, 200, 100);
    st.kind = .startup;
    st.wall_ms = try a.dupe(f64, &.{200});
    try records.append(a, sb);
    try records.append(a, st);
    const m = try build(a, records.items);
    const bt = (try baseTip(a, &m, 1)).?;
    try testing.expectEqualStrings("9b0f1b1f382", bt.base_version);
    try testing.expectEqualStrings("d0d8be54612", bt.tip_version);
    try testing.expectEqual(@as(usize, 4), bt.rows.len);
    const ra = bt.rows[0];
    try testing.expectEqualStrings("dom.a", ra.workload);
    try testing.expectApproxEqAbs(@as(f64, 0.25), ra.time.?, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 1.0), ra.steady.?, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0.10), ra.band, 1e-12);
    try testing.expect(ra.outside);
    try testing.expect(!bt.rows[1].outside);
    const rc = bt.rows[2];
    try testing.expectApproxEqAbs(@as(f64, 0.7), rc.steady.?, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0.5), rc.peak.?, 1e-12);
    try testing.expect(rc.outside);
    // Start-up is a row, outside its band, but in neither geometric mean.
    try testing.expectEqualStrings("startup.idle-page", bt.rows[3].workload);
    try testing.expect(bt.rows[3].outside);
    // The two geometric means over the headline's workloads: time
    // (0.25 * 1.05 * 1)^(1/3), memory (1 * 1.01 * 0.7)^(1/3).
    try testing.expectApproxEqAbs(std.math.pow(f64, 0.25 * 1.05, 1.0 / 3.0), bt.time_ratio.?, 1e-12);
    try testing.expectEqual(@as(usize, 3), bt.time_n);
    try testing.expectApproxEqAbs(std.math.pow(f64, 1.01 * 0.7, 1.0 / 3.0), bt.memory_ratio.?, 1e-12);
    try testing.expectEqual(@as(usize, 3), bt.memory_n);
    try testing.expectEqual(@as(usize, 3), bt.outside.len);
    try testing.expectEqualStrings("dom.a", bt.outside[0]);

    const page = (try render(a, &m, .{})).index_html;
    const i = std.mem.indexOf(u8, page, "id=\"base-tip\"").?;
    const section = page[i .. i + std.mem.indexOf(u8, page[i..], "</section>").?];
    try testing.expect(std.mem.indexOf(u8, section, "<code>9b0f1b1f382</code>") != null);
    try testing.expect(std.mem.indexOf(u8, section, "<code>d0d8be54612</code>") != null);
    try testing.expect(std.mem.indexOf(u8, section, "3 workloads outside") != null);
    try testing.expect(std.mem.indexOf(u8, section, "<code>dom.a</code>") != null);
    try testing.expect(std.mem.indexOf(u8, section, "Peak") != null);
    // Its own column in the round's tables, beside Crane's.
    try testing.expect(std.mem.indexOf(u8, page, "<th scope=\"col\" class=\"n\">Crane base</th>") != null);
    try testing.expect(std.mem.indexOf(u8, page, "Crane / base") != null);
    // The base against its own earlier rows (round 0, named `crane` there):
    // within noise when both means are within 5%.
    const earlier_rows = [_]journal.Record{
        try timed(a, 0, .crane, "9b0f1b1f382", "dom.a", 0, 41, 100),
        try timed(a, 0, .crane, "9b0f1b1f382", "dom.b", 0, 10, 100),
        try timed(a, 0, .crane, "9b0f1b1f382", "dom.c", 0, 10, 1000),
    };
    const earlier = try build(a, &earlier_rows);
    const bd = try driftBetween(a, &earlier, 0, .crane, &m, 1, .crane_base);
    try testing.expectEqual(@as(usize, 3), bd.time_n);
    try testing.expectApproxEqAbs(std.math.pow(f64, 40.0 / 41.0, 1.0 / 3.0), bd.time_ratio.?, 1e-12);
    try testing.expect(bd.within);
    try testing.expectEqual(@as(usize, 0), bd.outside);

    // A round without a base has no such section.
    const plain = [_]journal.Record{ try timed(a, 0, .crane, "abc", "dom.a", 0, 20, 100), try timed(a, 0, .chrome, "157", "dom.a", 0, 10, 400) };
    const pm = try build(a, &plain);
    try testing.expect((try baseTip(a, &pm, 0)) == null);
    try testing.expect(std.mem.indexOf(u8, (try render(a, &pm, .{})).index_html, "id=\"base-tip\"") == null);
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

/// `r` as made by the build with SHA-256 `sha` for `target` (null: none recorded, as round 0's).
fn built(r: journal.Record, sha: []const u8, target: ?[]const u8) journal.Record {
    var out = r;
    out.engine.binary_sha256 = sha;
    out.engine.target_cpu = target;
    return out;
}

const sha_round0 = "0000000000000000000000000000000000000000000000000000000000000000";
const sha_tip = "1111111111111111111111111111111111111111111111111111111111111111";
const sha_base = "2222222222222222222222222222222222222222222222222222222222222222";
const sha_fast = "3333333333333333333333333333333333333333333333333333333333333333";

/// Round 0 (Crane native, ReleaseFast, Chrome) and a Crane-only round 1:
/// the tip and ReleaseFast for apple_m1, round 0's source for apple_m1 (the
/// base), and round 0's binary again (the control). `control_time` and
/// `control_mem` scale the control's dom.a and dom.b against round 0's.
fn roundOneRecords(a: Allocator, control_time: f64, control_mem: f64) ![]const journal.Record {
    var rs: std.ArrayList(journal.Record) = .empty;
    for ([_]u32{ 0, 1, 2 }) |run| {
        // Round 0.
        try rs.append(a, built(try timed(a, 0, .crane, "9b0f1b1f382", "dom.a", run, 40, 1000), sha_round0, null));
        try rs.append(a, built(try timed(a, 0, .crane, "9b0f1b1f382", "dom.b", run, 10, 1000), sha_round0, null));
        try rs.append(a, built(try timed(a, 0, .crane_fast, "9b0f1b1f382", "dom.a", run, 36, 1000), sha_fast, null));
        try rs.append(a, try timed(a, 0, .chrome, "157", "dom.a", run, 10, 500));
        try rs.append(a, try timed(a, 0, .chrome, "157", "dom.b", run, 5, 500));
        // Round 1: Crane only.
        try rs.append(a, built(try timed(a, 1, .crane, "aaaaaaaaaaa", "dom.a", run, 20, 400), sha_tip, "apple_m1"));
        try rs.append(a, built(try timed(a, 1, .crane, "aaaaaaaaaaa", "dom.b", run, 10, 1000), sha_tip, "apple_m1"));
        try rs.append(a, built(try timed(a, 1, .crane_base, "9b0f1b1f382", "dom.a", run, 44, 1000), sha_base, "apple_m1"));
        try rs.append(a, built(try timed(a, 1, .crane_base, "9b0f1b1f382", "dom.b", run, 11, 1000), sha_base, "apple_m1"));
        try rs.append(a, built(try timed(a, 1, .crane_control, "9b0f1b1f382", "dom.a", run, 40 * control_time, @intFromFloat(1000 * control_mem)), sha_round0, "apple_m4 (native)"));
        try rs.append(a, built(try timed(a, 1, .crane_control, "9b0f1b1f382", "dom.b", run, 10 * control_time, @intFromFloat(1000 * control_mem)), sha_round0, "apple_m4 (native)"));
    }
    return rs.items;
}

test "a Crane-only round: the browsers keep their last rows, and the new Crane is set beside them" {
    // The user, 2026-11-06: re-measuring runs ONLY Crane; the browsers keep
    // their round-0 rows (a browser runs again only when it updates).
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const m = try build(a, try roundOneRecords(a, 1.0, 1.0));
    try testing.expectEqual(@as(u32, 1), m.latest_round);
    // A browser's rows stand for a later round it did not run in...
    try testing.expectEqual(@as(?u32, 0), m.standing(1, .chrome));
    try testing.expectEqual(@as(?u32, 0), m.standing(0, .chrome));
    try testing.expectEqualStrings("157", m.rowsFor(1, .chrome, "dom.a").?.version);
    // ...a Crane build's never: each is measured in its round, or absent.
    try testing.expectEqual(@as(?u32, null), m.standing(1, .crane_fast));
    try testing.expect(m.rowsFor(1, .crane_fast, "dom.a") == null);
    try testing.expectEqual(@as(?u32, 1), m.standing(1, .crane));
    try testing.expectEqual(@as(?u32, null), m.standing(1, .safari));
    // The headline: round 1's Crane against Chrome's round-0 rows: 20/10, 10/5.
    const v = try versus(a, &m, 1, .chrome);
    try testing.expectApproxEqAbs(@as(f64, 2.0), v.time_ratio.?, 1e-12);
    try testing.expectEqual(@as(?u32, 0), v.round);
    try testing.expectEqualStrings("157", v.version.?);
    const page = (try render(a, &m, .{})).index_html;
    try testing.expect(std.mem.indexOf(u8, page, "<title>Crane performance: round 1</title>") != null);
    try testing.expect(std.mem.indexOf(u8, page, "200% of Chrome's time") != null);
    // The page says whose rows are whose.
    const headline = page[std.mem.indexOf(u8, page, "id=\"headline\"").?..];
    try testing.expect(std.mem.indexOf(u8, headline[0..std.mem.indexOf(u8, headline, "</section>").?], "157 (round 0)") != null);
    try testing.expect(std.mem.indexOf(u8, page, "the browsers&rsquo; rows are round 0&rsquo;s") != null);
    // The round's tables carry Chrome's round-0 figures beside Crane's.
    const round = page[std.mem.indexOf(u8, page, "id=\"round\"").?..];
    try testing.expect(std.mem.indexOf(u8, round[0..std.mem.indexOf(u8, round, "</section>").?], ">200%<") != null);
    // Crane's CPU target is named: one fixed target, never the host's.
    try testing.expect(std.mem.indexOf(u8, page, "<code>apple_m1</code>") != null);
    // The engines table lists the browsers whose rows stand, with their round.
    const engines_s = page[std.mem.indexOf(u8, page, "id=\"engines\"").?..];
    const engines_t = engines_s[0..std.mem.indexOf(u8, engines_s, "</section>").?];
    try testing.expect(std.mem.indexOf(u8, engines_t, "<th scope=\"row\">Chrome</th>") != null);
    try testing.expect(std.mem.indexOf(u8, engines_t, "round 0") != null);
    try testing.expect(std.mem.indexOf(u8, engines_t, "apple_m1") != null);
}

test "the drift control: the binary an earlier round measured, against that round's rows" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const m = try build(a, try roundOneRecords(a, 1.02, 0.99));
    const cd = (try controlDrift(a, &m, 1)).?;
    // Found by its binary: round 0 measured these bytes as Crane.
    try testing.expectEqual(@as(?u32, 0), cd.earlier_round);
    try testing.expectEqualStrings("9b0f1b1f382", cd.version);
    try testing.expectEqualStrings("apple_m4 (native)", cd.target_cpu.?);
    try testing.expectApproxEqAbs(@as(f64, 1.02), cd.drift.time_ratio.?, 1e-9);
    try testing.expectApproxEqAbs(@as(f64, 0.99), cd.drift.memory_ratio.?, 1e-9);
    try testing.expect(cd.drift.within);
    try testing.expectEqual(Standing.carried_within_noise, try standingOf(a, &m, 1));
    const page = (try render(a, &m, .{})).index_html;
    const i = std.mem.indexOf(u8, page, "id=\"drift\"").?;
    const section = page[i .. i + std.mem.indexOf(u8, page[i..], "</section>").?];
    try testing.expect(std.mem.indexOf(u8, section, "<strong>within noise</strong>") != null);
    try testing.expect(std.mem.indexOf(u8, section, "102.0%") != null);
    try testing.expect(std.mem.indexOf(u8, section, "<code>apple_m4 (native)</code>") != null);
    try testing.expect(std.mem.indexOf(u8, section, "<code>dom.a</code>") != null);

    // A host that moved between the rounds: the control 20% slower.
    const moved = try build(a, try roundOneRecords(a, 1.2, 1.0));
    const md = (try controlDrift(a, &moved, 1)).?;
    try testing.expect(!md.drift.within);
    try testing.expectEqual(Standing.carried_drifted, try standingOf(a, &moved, 1));
    try testing.expect(std.mem.indexOf(u8, (try render(a, &moved, .{})).index_html, "<strong class=\"fail\">not within noise</strong>") != null);

    // No control at all, the browsers' rows carried: not publishable.
    var no_control: std.ArrayList(journal.Record) = .empty;
    for (try roundOneRecords(a, 1.0, 1.0)) |r| if (r.engine.name != .crane_control) try no_control.append(a, r);
    const nc = try build(a, no_control.items);
    try testing.expect((try controlDrift(a, &nc, 1)) == null);
    try testing.expectEqual(Standing.carried_without_control, try standingOf(a, &nc, 1));
    // A control whose binary no earlier round measured is no drift control.
    var stranger: std.ArrayList(journal.Record) = .empty;
    for (try roundOneRecords(a, 1.0, 1.0)) |r| try stranger.append(a, if (r.engine.name == .crane_control) built(r, sha_fast, null) else r);
    const st = try build(a, stranger.items);
    try testing.expectEqual(@as(?u32, null), (try controlDrift(a, &st, 1)).?.earlier_round);
    try testing.expectEqual(Standing.carried_without_control, try standingOf(a, &st, 1));
    // Every engine measured in its round: nothing carried.
    const r0 = [_]journal.Record{ try timed(a, 0, .crane, "abc", "dom.a", 0, 20, 100), try timed(a, 0, .chrome, "157", "dom.a", 0, 10, 400) };
    try testing.expectEqual(Standing.measured_together, try standingOf(a, &(try build(a, &r0)), 0));
}

test "the CPU target alone: round 0's source built for the fixed target, against round 0's binary" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const m = try build(a, try roundOneRecords(a, 1.0, 1.0));
    const t = (try targetAlone(a, &m, 1)).?;
    // The base (apple_m1) over the control (native): 44/40 and 11/10.
    try testing.expectApproxEqAbs(@as(f64, 1.1), t.versus.time_ratio.?, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 1.0), t.versus.memory_ratio.?, 1e-12);
    try testing.expectEqualStrings("apple_m1", t.base_target);
    try testing.expectEqualStrings("apple_m4 (native)", t.control_target);
    const page = (try render(a, &m, .{})).index_html;
    const i = std.mem.indexOf(u8, page, "id=\"drift\"").?;
    const section = page[i .. i + std.mem.indexOf(u8, page[i..], "</section>").?];
    try testing.expect(std.mem.indexOf(u8, section, "what the CPU target alone did") != null);
    try testing.expect(std.mem.indexOf(u8, section, "110.0%") != null);
    // The base and the tip are one target: the comparison is the code's.
    const bt_i = std.mem.indexOf(u8, page, "id=\"base-tip\"").?;
    try testing.expect(std.mem.indexOf(u8, page[bt_i .. bt_i + std.mem.indexOf(u8, page[bt_i..], "</section>").?], "both built for <code>apple_m1</code>") != null);
    // Without a base of the control's commit, no such comparison.
    const r0 = [_]journal.Record{ try timed(a, 0, .crane, "abc", "dom.a", 0, 20, 100), try timed(a, 0, .chrome, "157", "dom.a", 0, 10, 400) };
    try testing.expect((try targetAlone(a, &(try build(a, &r0)), 0)) == null);
}

/// The section `id` of `page`, up to its end.
fn sectionOf(page: []const u8, id: []const u8) ![]const u8 {
    var buf: [64]u8 = undefined;
    const open = try std.fmt.bufPrint(&buf, "<section id=\"{s}\">", .{id});
    const i = std.mem.indexOf(u8, page, open) orelse return error.TestUnexpectedResult;
    return page[i .. i + std.mem.indexOf(u8, page[i..], "</section>").?];
}

test "Crane round by round: each workload's figures in every measurement round, its trend, no target step" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const m = try build(a, try roundOneRecords(a, 1.0, 1.0));
    const page = (try render(a, &m, .{})).index_html;
    const section = try sectionOf(page, "crane-history");
    // A column per round, and the change since round 0 - nothing for round 0's source rebuilt
    // for round 1's CPU target (a control, not a round).
    try testing.expect(std.mem.indexOf(u8, section, "Time, Round 0</th>") != null);
    try testing.expect(std.mem.indexOf(u8, section, "Time, Round 1</th>") != null);
    try testing.expect(std.mem.indexOf(u8, section, "Memory, Round 1</th>") != null);
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, section, "Since round 0</th>"));
    try testing.expect(std.mem.indexOf(u8, section, "source</th>") == null);
    try testing.expect(std.mem.indexOf(u8, section, ">Code</th>") == null);
    try testing.expect(std.mem.indexOf(u8, section, ">Target</th>") == null);
    // dom.a: 40 -> 20 us per op (50%), memory 1000 -> 400 bytes (40%).
    try testing.expect(std.mem.indexOf(u8, section, "<code>dom.a</code>") != null);
    try testing.expect(std.mem.indexOf(u8, section, ">50%<") != null);
    try testing.expect(std.mem.indexOf(u8, section, ">40%<") != null);
    // A trend per workload and measure: two rounds each, never a dashed step.
    try testing.expectEqual(@as(usize, 4), std.mem.count(u8, section, "<svg class=\"chart-svg spark\""));
    try testing.expectEqual(@as(usize, 4), std.mem.count(u8, section, "<line class=\"spark-line\""));
    // Where the target's effect per workload is.
    try testing.expect(std.mem.indexOf(u8, section, "href=\"#drift\"") != null);
    // The control's and the base's rows are in the full history, named.
    const history = page[std.mem.indexOf(u8, page, "id=\"history\"").?..];
    try testing.expect(std.mem.indexOf(u8, history, "<td>Crane control</td>") != null);
    try testing.expect(std.mem.indexOf(u8, history, "<td>Crane base</td>") != null);
    // A single round has no round-by-round table.
    const r0 = [_]journal.Record{ try timed(a, 0, .crane, "abc", "dom.a", 0, 20, 100), try timed(a, 0, .chrome, "157", "dom.a", 0, 10, 400) };
    try testing.expect(std.mem.indexOf(u8, (try render(a, &(try build(a, &r0)), .{})).index_html, "id=\"crane-history\"") == null);
}

test "progress: measurement rounds only, Crane against its own round 0, the browsers' rows as they stood" {
    // The user, 2026-11-07, on the chart with a CPU-target point: "this graph is confusing for
    // tracking Crane's progress".
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const m = try build(a, try roundOneRecords(a, 1.0, 1.0));
    const pts = try progress(a, &m);
    // Rounds only: round 1's base (round 0's source for apple_m1) is a control, not a point.
    try testing.expectEqual(@as(usize, 2), pts.len);
    try testing.expectEqual(@as(u32, 0), pts[0].round);
    try testing.expectEqual(@as(u32, 1), pts[1].round);
    // Round 0: native, its target named by round 1's control (the same binary).
    try testing.expectEqualStrings("9b0f1b1f382", pts[0].commit);
    try testing.expectEqualStrings("apple_m4 (native)", pts[0].target.?);
    try testing.expectEqualStrings("2026-11-05", pts[0].date);
    try testing.expectEqualStrings("aaaaaaaaaaa", pts[1].commit);
    try testing.expectEqualStrings("apple_m1", pts[1].target.?);
    // Crane against its own round 0: 1 there; round 1's time 20/40 and 10/10, memory
    // 400/1000 and 1000/1000.
    try testing.expectApproxEqAbs(@as(f64, 1.0), pts[0].since.time_ratio.?, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 1.0), pts[0].since.memory_ratio.?, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, std.math.sqrt(0.5)), pts[1].since.time_ratio.?, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, std.math.sqrt(0.4)), pts[1].since.memory_ratio.?, 1e-12);
    try testing.expectEqual(@as(usize, 2), pts[1].since.time_n);
    // Against each browser's rows as they stood: Chrome's round-0 rows in both rounds,
    // time 40/10 and 10/5, then 20/10 and 10/5.
    try testing.expectApproxEqAbs(@as(f64, std.math.sqrt(8.0)), pts[0].vs[0].time_ratio.?, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 2.0), pts[1].vs[0].time_ratio.?, 1e-12);
    try testing.expectEqual(@as(?u32, 0), pts[1].vs[0].round);
    // The card's figure is the last point's.
    const since = (try sinceFirst(a, &m)).?;
    try testing.expectApproxEqAbs(pts[1].since.time_ratio.?, since.time_ratio.?, 1e-12);
    // What the CPU target alone did: round 1 rebuilt round 0's source for apple_m1 (44/40,
    // 11/10; memory the same).
    const tc = try targetChanges(a, &m);
    try testing.expectEqual(@as(usize, 1), tc.len);
    try testing.expectEqual(@as(u32, 1), tc[0].round);
    try testing.expectEqual(@as(u32, 0), tc[0].source_round);
    try testing.expectEqualStrings("apple_m1", tc[0].target);
    try testing.expectApproxEqAbs(@as(f64, 1.1), tc[0].versus.time_ratio.?, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 1.0), tc[0].versus.memory_ratio.?, 1e-12);

    const out = try render(a, &m, .{});
    const page = out.index_html;
    const section = try sectionOf(page, "progress");
    // Right after the headline.
    try testing.expect(std.mem.indexOf(u8, page, "id=\"progress\"").? < std.mem.indexOf(u8, page, "id=\"drift\"").?);
    // First, Crane over time: two small charts, time and memory, ONE line each; lower is better.
    const over = std.mem.indexOf(u8, section, "Crane over time</h3>").?;
    const gap = std.mem.indexOf(u8, section, "The gap to the browsers</h3>").?;
    try testing.expect(over < gap);
    try testing.expect(std.mem.indexOf(u8, section[0..over], "<svg") == null);
    try testing.expect(std.mem.indexOf(u8, section[0..over], "<table") == null);
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, section, "<svg class=\"chart-svg trend-svg\""));
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, section, "class=\"trend-line\""));
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, section, "lower is better</figcaption>"));
    try testing.expect(std.mem.indexOf(u8, section, ">71%</text>") != null);
    try testing.expect(std.mem.indexOf(u8, section, ">63%</text>") != null);
    try testing.expect(std.mem.indexOf(u8, section, ">Round 1</text>") != null);
    try testing.expect(std.mem.indexOf(u8, section, ">aaaaaaaaaaa</text>") != null);
    // No control point, no dashed step, no browser lines: a footnote says what the target did.
    try testing.expect(std.mem.indexOf(u8, section, "source</") == null);
    try testing.expect(std.mem.indexOf(u8, section, "Round 0&#39;s source") == null);
    try testing.expect(std.mem.indexOf(u8, section, "perf-chart") == null);
    try testing.expect(std.mem.indexOf(u8, section, "mark-line") == null);
    try testing.expect(std.mem.indexOf(u8, section, "From round 1 Crane is built for one fixed CPU target, <code>apple_m1</code>; re-measuring round 0&rsquo;s source for it changed time by 1.100&times; and memory by 1.000&times;") != null);
    // Each round says what it changed, with its figures.
    try testing.expect(std.mem.indexOf(u8, section, "Lane perf1") != null);
    try testing.expect(std.mem.indexOf(u8, section, "time 70.7% and memory 63.2% of round 0&rsquo;s") != null);
    // Nothing on the page draws a target step any more.
    try testing.expect(std.mem.indexOf(u8, page, "step-target") == null);
    try testing.expect(std.mem.indexOf(u8, page, "hollow") == null);
    // The description and the card name the progress.
    try testing.expect(std.mem.indexOf(u8, page, "Since round 0: 71% of its time and 63% of its memory.") != null);
    // Still no script: the content is all in the HTML.
    try testing.expect(std.mem.indexOf(u8, page, "<script") == null);
    // A single round has no progress section.
    const r0 = [_]journal.Record{ try timed(a, 0, .crane, "abc", "dom.a", 0, 20, 100), try timed(a, 0, .chrome, "157", "dom.a", 0, 10, 400) };
    const single = try build(a, &r0);
    try testing.expect((try sinceFirst(a, &single)) == null);
    try testing.expect(std.mem.indexOf(u8, (try render(a, &single, .{})).index_html, "id=\"progress\"") == null);
}

test "the gap to the browsers: a table of N.NN times each browser's per round, coloured by the change from the round before" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const m = try build(a, try roundOneRecords(a, 1.0, 1.0));
    const page = (try render(a, &m, .{})).index_html;
    const section = try sectionOf(page, "progress");
    const gap = section[std.mem.indexOf(u8, section, "The gap to the browsers</h3>").?..];
    // A table, not a chart; one row per browser with figures (the fixture has only Chrome).
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, gap, "<table"));
    try testing.expect(std.mem.indexOf(u8, gap, "<svg") == null);
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, gap, "<th scope=\"row\">"));
    try testing.expect(std.mem.indexOf(u8, gap, "<th scope=\"row\">Chrome") != null);
    try testing.expect(std.mem.indexOf(u8, gap, "Safari") == null);
    // The legend, one line.
    try testing.expect(std.mem.indexOf(u8, gap, "1.00&times; = the browser&rsquo;s own time") != null);
    try testing.expect(std.mem.indexOf(u8, gap, "lower is better") != null);
    // Round 0's time: sqrt(4 * 2) = 2.83x Chrome's, with nothing before it to compare.
    try testing.expect(std.mem.indexOf(u8, gap, "<td class=\"n\" data-label=\"Time, round 0\">2.83&times;</td>") != null);
    // Round 1's: 2.00x, lower than round 0's - green. What it was is the column beside it,
    // never repeated in the cell (the integrator, 2026-11-07).
    try testing.expect(std.mem.indexOf(u8, gap, "<td class=\"n ratio-good\" data-label=\"Time, round 1\">2.00&times;</td>") != null);
    try testing.expect(std.mem.indexOf(u8, gap, "(was") == null);
    // Memory: 2.00x, then sqrt(0.8 * 2) = 1.26x.
    try testing.expect(std.mem.indexOf(u8, gap, "data-label=\"Memory, round 0\">2.00&times;</td>") != null);
    try testing.expect(std.mem.indexOf(u8, gap, "<td class=\"n ratio-good\" data-label=\"Memory, round 1\">1.26&times;</td>") != null);
    // Its header: each measure across the rounds.
    try testing.expect(std.mem.indexOf(u8, gap, "<th scope=\"colgroup\" colspan=\"2\" class=\"n\">Time</th>") != null);
    try testing.expect(std.mem.indexOf(u8, gap, "<th scope=\"col\" class=\"n\">Round 1</th>") != null);
}

test "the gap's change marker: lower is green, higher red, a change within the noise limit uncoloured" {
    try testing.expectEqual(Change.none, changeOf(null, 2.0));
    try testing.expectEqual(Change.none, changeOf(2.0, null));
    try testing.expectEqual(Change.better, changeOf(7.36, 5.97));
    try testing.expectEqual(Change.worse, changeOf(5.97, 7.36));
    // Within 5% (drift_limit, the drift control's own limit): no colour either way.
    try testing.expectEqual(Change.steady, changeOf(2.0, 2.06));
    try testing.expectEqual(Change.steady, changeOf(2.0, 1.92));
    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    try writeGapCell(&out.writer, "Time, round 2", "t", 7.36, 5.97);
    try testing.expectEqualStrings("<td class=\"n ratio-bad\" data-label=\"Time, round 2\" title=\"t\">7.36&times;</td>", out.written());
    out.clearRetainingCapacity();
    try writeGapCell(&out.writer, "Memory, round 2", "", 2.06, 2.0);
    try testing.expectEqualStrings("<td class=\"n\" data-label=\"Memory, round 2\">2.06&times;</td>", out.written());
    out.clearRetainingCapacity();
    try writeGapCell(&out.writer, "Time, round 1", "", null, 2.0);
    try testing.expectEqualStrings("<td class=\"n\" data-label=\"Time, round 1\">&ndash;</td>", out.written());
}

test "the CPU target's footnote: what re-measuring a round's source for the new target did, within noise or not" {
    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    const within: TargetChange = .{ .round = 1, .source_round = 0, .target = "apple_m1-fuse_aes", .versus = .{ .browser = .crane_control, .time_ratio = 0.991, .memory_ratio = 1.010 } };
    try writeTargetNotes(&out.writer, &.{within});
    try testing.expectEqualStrings("<p class=\"chart-note\">From round 1 Crane is built for one fixed CPU target, <code>apple_m1-fuse_aes</code>; re-measuring round 0&rsquo;s source for it changed time by 0.991&times; and memory by 1.010&times;, within noise (both within 5%).</p>\n", out.written());
    out.clearRetainingCapacity();
    var beyond = within;
    beyond.versus.time_ratio = 1.1;
    try writeTargetNotes(&out.writer, &.{beyond});
    try testing.expect(std.mem.indexOf(u8, out.written(), "changed time by 1.100&times; and memory by 1.010&times;, beyond the 5% noise limit.") != null);
    out.clearRetainingCapacity();
    try writeTargetNotes(&out.writer, &.{});
    try testing.expectEqual(@as(usize, 0), out.written().len);
}

test "every round has its note, in order" {
    for (round_notes, 0..) |n, i| {
        try testing.expectEqual(@as(u32, @intCast(i)), n.round);
        try testing.expect(n.note.len > 0);
    }
    try testing.expect(roundNote(1) != null);
    try testing.expect(roundNote(2) != null);
    try testing.expect(roundNote(99) == null);
}

/// A retained row: `workload`'s objects (1,000) made and kept, the footprint `start` before and
/// `end` after; `forced`: both readings after a collection the page asked for; `js`: the JS
/// heap before and after, where the engine reports it.
fn retainedRow(arena: Allocator, round: u32, name: EngineName, version: []const u8, workload: []const u8, run: u32, start: u64, end: u64, forced: bool, js: ?[2]f64) !journal.Record {
    var counters: std.ArrayList(journal.Counter) = .empty;
    try counters.append(arena, .{ .name = "forced_gc", .value = if (forced) 1 else 0 });
    try counters.append(arena, .{ .name = "settle_ms", .value = 3000 });
    if (js) |j| {
        try counters.append(arena, .{ .name = "js_heap_before", .value = j[0] });
        try counters.append(arena, .{ .name = "js_heap_after", .value = j[1] });
    }
    return .{
        .format = journal.format_name,
        .round = round,
        .time = "2026-11-07T19:00:00Z",
        .host = host,
        .engine = engineOf(name, version),
        .page = "memory/elements-x.html",
        .workload = workload,
        .kind = .retained,
        .run = run,
        .status = .ok,
        .ops = 1000,
        .wall_ms = try arena.dupe(f64, &.{1.5}),
        .memory = .{ .footprint_start = start, .footprint_end = end, .footprint_peak = @max(start, end), .resident_end = 0, .processes = 1 },
        .counters = counters.items,
    };
}

test "memory per element stays out of the headline, the round tables and the progress" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const suite_rows = [_]journal.Record{
        try timed(a, 1, .crane, "abc", "dom.a", 0, 20, 100),
        try timed(a, 1, .chrome, "157", "dom.a", 0, 10, 400),
    };
    const without = try build(a, &suite_rows);
    // The same rows with memory-per-element rows beside them, of a later round.
    var all: std.ArrayList(journal.Record) = .empty;
    try all.appendSlice(a, &suite_rows);
    try all.append(a, try retainedRow(a, 2, .crane, "def", element_control, 0, 50_000_000, 50_100_000, true, null));
    try all.append(a, try retainedRow(a, 2, .crane, "def", "elements.detached-div", 0, 50_000_000, 52_850_000, true, null));
    try all.append(a, try retainedRow(a, 2, .chrome, "157", element_control, 0, 400_000_000, 400_000_000, true, .{ 1e6, 1e6 }));
    try all.append(a, try retainedRow(a, 2, .chrome, "157", "elements.detached-div", 0, 400_000_000, 400_130_000, true, .{ 1e6, 1.08e6 }));
    const with = try build(a, all.items);
    // The suite's model is untouched: its rounds, its cells, its comparisons.
    try testing.expectEqual(without.latest_round, with.latest_round);
    try testing.expectEqualSlices(u32, without.rounds, with.rounds);
    try testing.expectEqual(without.cells.len, with.cells.len);
    try testing.expectEqual(@as(usize, 4), with.retained.len);
    const v0 = try versus(a, &without, 1, .chrome);
    const v1 = try versus(a, &with, 1, .chrome);
    try testing.expectEqual(v0.time_ratio, v1.time_ratio);
    try testing.expectEqual(v0.memory_ratio, v1.memory_ratio);
    // The page is the same page with one section more.
    const p0 = (try render(a, &without, .{})).index_html;
    const p1 = (try render(a, &with, .{})).index_html;
    try testing.expect(std.mem.indexOf(u8, p0, "memory-per-element") == null);
    const start = std.mem.indexOf(u8, p1, "<section id=\"memory-per-element\">").?;
    const end = std.mem.indexOfPos(u8, p1, start, "</section>\n").? + "</section>\n".len;
    try testing.expectEqualStrings(p0, try std.mem.concat(a, u8, &.{ p1[0..start], p1[end..] }));
}

test "memory per element: (case - control) / N per run, the median and its deviation, Crane first" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var records: std.ArrayList(journal.Record) = .empty;
    // Crane: the control drifts 1.0-1.2 MB over its steps (median 1.1 MB); the case's
    // three runs grow 3.80, 3.85 and 3.90 MB: (d - 1.1 MB) / 1,000 = 2,700, 2,750, 2,800 B.
    for ([_]u64{ 1_000_000, 1_200_000, 1_100_000 }, 0..) |d, i| try records.append(a, try retainedRow(a, 2, .crane, "def", element_control, @intCast(i), 50_000_000, 50_000_000 + d, true, null));
    for ([_]u64{ 3_800_000, 3_850_000, 3_900_000 }, 0..) |d, i| try records.append(a, try retainedRow(a, 2, .crane, "def", "elements.detached-div", @intCast(i), 50_000_000, 50_000_000 + d, true, null));
    // Chrome: its control's footprint FELL 10 KB (a page can drift either way), its JS heap
    // stood still; the case's 120, 130, 140 KB, of which the JS heap 80 KB.
    for (0..3) |i| try records.append(a, try retainedRow(a, 2, .chrome, "157", element_control, @intCast(i), 400_010_000, 400_000_000, true, .{ 1e6, 1e6 }));
    for ([_]u64{ 110_000, 120_000, 130_000 }, 0..) |d, i| try records.append(a, try retainedRow(a, 2, .chrome, "157", "elements.detached-div", @intCast(i), 400_000_000, 400_000_000 + d, true, .{ 1e6, 1.08e6 }));
    // Firefox: no collection a page can ask for; a case that timed out in one run.
    try records.append(a, try retainedRow(a, 2, .firefox, "159.0.1", element_control, 0, 300_000_000, 300_000_000, false, null));
    try records.append(a, try retainedRow(a, 2, .firefox, "159.0.1", "elements.detached-div", 0, 300_000_000, 300_150_000, false, null));
    var timeout = try retainedRow(a, 2, .firefox, "159.0.1", "elements.text-node", 0, 0, 0, false, null);
    timeout.status = .timeout;
    timeout.message = "no result in 300 s";
    timeout.memory = null;
    try records.append(a, timeout);
    const m = try build(a, records.items);
    const t = (try elementTable(a, &m)).?;
    try testing.expectEqual(@as(u32, 2), t.round);
    try testing.expectEqual(@as(u64, 1000), t.count);
    try testing.expectEqual(@as(usize, 2), t.cases.len);
    try testing.expectEqualStrings("elements.detached-div", t.cases[0]);
    try testing.expectEqualStrings("elements.text-node", t.cases[1]);
    try testing.expectEqual(@as(usize, 3), t.rows.len);
    try testing.expectEqual(EngineName.crane, t.rows[0].engine);
    try testing.expectEqual(EngineName.chrome, t.rows[1].engine);
    try testing.expectEqual(EngineName.firefox, t.rows[2].engine);
    const crane = t.rows[0];
    try testing.expect(crane.forced_gc);
    try testing.expectApproxEqAbs(@as(f64, 1_100_000), crane.control_delta.?, 1e-6);
    try testing.expectApproxEqAbs(@as(f64, 2750), crane.figures[0].bytes.?, 1e-9);
    try testing.expectApproxEqAbs(@as(f64, 50), crane.figures[0].mad.?, 1e-9);
    try testing.expectEqual(@as(?f64, null), crane.figures[0].js_bytes);
    // Chrome: (120 KB + 10 KB) / 1,000 = 130 B, of which the JS heap 80 B.
    const chrome = t.rows[1];
    try testing.expectApproxEqAbs(@as(f64, 130), chrome.figures[0].bytes.?, 1e-9);
    try testing.expectApproxEqAbs(@as(f64, 80), chrome.figures[0].js_bytes.?, 1e-9);
    const firefox = t.rows[2];
    try testing.expect(!firefox.forced_gc);
    try testing.expectApproxEqAbs(@as(f64, 150), firefox.figures[0].bytes.?, 1e-9);
    try testing.expectEqual(journal.Status.timeout, firefox.figures[1].failure.?);

    const page = (try render(a, &m, .{})).index_html;
    const sec = try sectionOf(page, "memory-per-element");
    try testing.expect(std.mem.indexOf(u8, sec, "<h2>Memory per element</h2>") != null);
    try testing.expect(std.mem.indexOf(u8, sec, "after 1,000 nodes were made and kept") != null);
    // Crane's row before every browser's.
    try testing.expect(std.mem.indexOf(u8, sec, "<th scope=\"row\">Crane</th>").? < std.mem.indexOf(u8, sec, "<th scope=\"row\">Chrome</th>").?);
    try testing.expect(std.mem.indexOf(u8, sec, "2,750 B") != null);
    // Chrome's runs spread 10 B around 130 B (7.7%, shown); Crane's 50 B around 2,750 B (1.8%, not).
    try testing.expect(std.mem.indexOf(u8, sec, "130 B <span class=\"quiet\" title=\"the runs' median absolute deviation\">&plusmn;10 B</span><br><span class=\"quiet\">JS heap 80 B</span><br><span class=\"quiet\">Crane 21.2&times;</span>") != null);
    try testing.expect(std.mem.indexOf(u8, sec, "2,750 B</td>") != null);
    try testing.expect(std.mem.indexOf(u8, sec, "Crane 18.3&times;") != null);
    try testing.expect(std.mem.indexOf(u8, sec, ">timeout</td>") != null);
    // The method, as the rows say: who collected and how, who could not, the idle time, the runs.
    try testing.expect(std.mem.indexOf(u8, sec, "<code>TestUtils.gc()</code> twice in Crane; <code>gc()</code> twice in Chrome, launched with <code>--js-flags=--expose-gc</code>) and then 3.0 s idle; Firefox let no page ask for a collection") != null);
    try testing.expect(std.mem.indexOf(u8, sec, "(1 to 3)") != null);
    // Rendering is named for the engines that render, and a large control drift for its engine
    // (Crane's control moved 1.1 MB over 1,000 nodes here: 1,100 B a node).
    try testing.expect(std.mem.indexOf(u8, sec, "In the engines that render - Chrome and Firefox - a node in the document also gets a layout object") != null);
    try testing.expect(std.mem.indexOf(u8, sec, "Crane&rsquo;s footprint moved by 1.0 MB between the two readings") != null);
    try testing.expect(std.mem.indexOf(u8, sec, "Chrome&rsquo;s footprint moved") == null);
}

test "a list in a sentence: a, a and b, a, b and c" {
    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    for ([_][]const []const u8{ &.{"Firefox"}, &.{ "Firefox", "Safari" }, &.{ "Firefox", "Safari", "Lightpanda" } }) |items| {
        try writeList(&out.writer, items);
        try out.writer.writeAll("|");
    }
    try testing.expectEqualStrings("Firefox|Firefox and Safari|Firefox, Safari and Lightpanda|", out.written());
}
