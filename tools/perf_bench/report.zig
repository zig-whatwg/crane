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
//!   - Crane round by round: each workload's figures per round, split into
//!     the code's change and the CPU target's where the round has both;
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
    var settled: std.ArrayList(u64) = .empty;
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
            if (m.footprint_settled) |v| try settled.append(arena, v);
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
    c.settled = try stats.medianU64(arena, settled.items);
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

/// What each round changed, for its point in the progress section: one line written when the
/// round is published (the WPT site's chart events are the same pattern, tools/wpt_site/chart.zig);
/// every figure beside it is the journals'. A round with no line shows none.
pub const RoundNote = struct { round: u32, note: []const u8 };

pub const round_notes = [_]RoundNote{
    .{ .round = 0, .note = "The baseline: the suite's first measurement, of main 9b0f1b1f382, built for its build host's CPU." },
    .{ .round = 1, .note = "Lane perf1: DOM memory reported to V8, and a garbage tree's deferred teardown weighed by its nodes. Lane perf2: getElementsBy* return one live list per document, and querySelector, matches and closest parse through a per-document selector cache with Blink's ID path. From this round every Crane build is for one fixed CPU, apple_m1." },
};

pub fn roundNote(round: u32) ?[]const u8 {
    for (round_notes) |n| if (n.round == round) return n.note;
    return null;
}

/// One point of Crane's progress: its headline against each browser, the browsers' rows as they
/// stood (`Model.standing`). A round's Crane (`crane`), and before it, where the round rebuilt an
/// earlier round's source for its own CPU target (`targetAlone`), that base (`crane_base`): the
/// step into the base is the target's, the step out of it the code's.
pub const ProgressPoint = struct {
    round: u32,
    engine: EngineName,
    /// For a base: the round whose source it is (the control's round).
    source_round: u32,
    commit: []const u8,
    /// The window's date, "2026-11-06" (its rows' latest time).
    date: []const u8,
    target: ?[]const u8,
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
    for (m.rounds) |r| {
        if (!hasEngine(m, r, .crane)) continue;
        if (try targetAlone(arena, m, r)) |t| {
            const cd = (try controlDrift(arena, m, r)).?;
            var bp: ProgressPoint = .{ .round = r, .engine = .crane_base, .source_round = cd.earlier_round orelse r, .commit = cd.version, .date = dateOf(m, r, .crane_base), .target = t.base_target, .vs = undefined };
            for (browsers, 0..) |b, i| bp.vs[i] = try compare(arena, m, r, .crane_base, b);
            try out.append(arena, bp);
        }
        var p: ProgressPoint = .{ .round = r, .engine = .crane, .source_round = r, .commit = "", .date = dateOf(m, r, .crane), .target = try targetOf(arena, m, r), .vs = undefined };
        for (m.cells) |c| if (c.round == r and c.engine == .crane and c.kind != .gc_bench) {
            p.commit = c.version;
            break;
        };
        for (browsers, 0..) |b, i| p.vs[i] = try compare(arena, m, r, .crane, b);
        try out.append(arena, p);
    }
    return out.items;
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
    \\.perf { --s1: #2a78d6; --s2: #eb6834; --s3: #1baf7a; --s4: #eda100; }
    \\@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) .perf { --s1: #3987e5; --s2: #d95926; --s3: #199e70; --s4: #c98500; } }
    \\:root[data-theme="dark"] .perf { --s1: #3987e5; --s2: #d95926; --s3: #199e70; --s4: #c98500; }
    \\.perf-chart .s1, .chart-key .s1 { stroke: var(--s1); } .perf-chart .s2, .chart-key .s2 { stroke: var(--s2); }
    \\.perf-chart .s3, .chart-key .s3 { stroke: var(--s3); } .perf-chart .s4, .chart-key .s4 { stroke: var(--s4); }
    \\.perf-chart line.s1, .perf-chart line.s2, .perf-chart line.s3, .perf-chart line.s4, .chart-key line { stroke-width: 2; stroke-linecap: round; }
    \\.perf-chart .step-target, .spark .step-target { stroke-dasharray: 4 3; }
    \\.perf-chart .dot { stroke: var(--paper); stroke-width: 2; }
    \\.perf-chart .dot.s1 { fill: var(--s1); } .perf-chart .dot.s2 { fill: var(--s2); } .perf-chart .dot.s3 { fill: var(--s3); } .perf-chart .dot.s4 { fill: var(--s4); }
    \\.perf-chart .dot.hollow { fill: var(--paper); stroke-width: 2; }
    \\.perf-chart .dot.hollow.s1 { stroke: var(--s1); } .perf-chart .dot.hollow.s2 { stroke: var(--s2); } .perf-chart .dot.hollow.s3 { stroke: var(--s3); } .perf-chart .dot.hollow.s4 { stroke: var(--s4); }
    \\.perf-chart .parity { stroke: var(--ink-2); stroke-width: 1; }
    \\.perf-chart .mark-label { fill: var(--ink); }
    \\.spark { width: 96px; height: 26px; }
    \\.spark .spark-line { stroke: var(--ink-2); stroke-width: 1.5; }
    \\.spark .spark-dot { fill: var(--ink); } .spark .spark-dot.hollow { fill: var(--paper); stroke: var(--ink); stroke-width: 1.2; }
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

fn pointLabel(arena: Allocator, p: ProgressPoint) ![]const u8 {
    return switch (p.engine) {
        .crane_base => try std.fmt.allocPrint(arena, "Round {d}'s source", .{p.source_round}),
        else => try std.fmt.allocPrint(arena, "Round {d}", .{p.round}),
    };
}

const series_classes = [browsers.len][]const u8{ "s1", "s2", "s3", "s4" };

/// Crane's progress (`progress`): its headline round by round against each browser, as a chart
/// and a table for time and for memory, each point labelled with its round, date, commit, CPU
/// target and what the round changed (`round_notes`). Shown from the second round on.
fn writeProgress(w: W, arena: Allocator, m: *const Model) !void {
    const pts = try progress(arena, m);
    if (pts.len < 2) return;
    try w.writeAll("<section id=\"progress\"><h2>Progress</h2>\n<p>Crane&rsquo;s headline round by round: its time and memory as a percentage of each browser&rsquo;s, each point against the browsers&rsquo; rows as they stood then - each browser&rsquo;s last-measured rows. Lower is better for Crane.");
    if (try sinceFirst(arena, m)) |sv| {
        try w.print(" Since round {d}, Crane&rsquo;s time is ", .{sv.round.?});
        try writePercent1(w, sv.time_ratio);
        try w.writeAll(" and its memory ");
        try writePercent1(w, sv.memory_ratio);
        try w.print(" of round {d}&rsquo;s (geometric means over {d} and {d} workloads).", .{ sv.round.?, sv.time_n, sv.memory_n });
    }
    try w.writeAll("</p>\n<ul class=\"round-notes\">\n");
    var mark: ?chart.Mark = null;
    for (pts, 0..) |p, i| {
        try w.writeAll("<li><strong>");
        try html.text(w, try pointLabel(arena, p));
        try w.writeAll("</strong>, ");
        try html.text(w, p.date);
        try w.writeAll(", Crane <code>");
        try html.text(w, p.commit);
        try w.writeAll("</code>, for <code>");
        try html.text(w, p.target orelse "a CPU not recorded");
        try w.writeAll("</code>");
        if (p.engine == .crane_base) {
            try w.print(": measured in round {d}&rsquo;s window, it is the step the CPU target alone made (dashed on the charts); the step from it to round {d} is the code&rsquo;s.", .{ p.round, p.round });
            if (mark == null and i > 0) mark = .{ .at = i, .label = try std.fmt.allocPrint(arena, "CPU target {s}", .{p.target orelse "?"}) };
        } else if (roundNote(p.round)) |note| {
            try w.writeAll(": ");
            try html.text(w, note);
        } else try w.writeAll(".");
        try w.writeAll("</li>\n");
    }
    try w.writeAll("</ul>\n");
    var cpoints: std.ArrayList(chart.Point) = .empty;
    for (pts) |p| try cpoints.append(arena, .{ .label = try pointLabel(arena, p), .sub = p.target orelse "", .hollow = p.engine == .crane_base });
    for ([_]Measure{ .time, .steady }) |measure| {
        const what = if (measure == .time) "time" else "memory";
        var lines: std.ArrayList(chart.Line) = .empty;
        for (browsers, 0..) |b, bi| {
            var values: std.ArrayList(?f64) = .empty;
            var titles: std.ArrayList([]const u8) = .empty;
            var any = false;
            for (pts) |p| {
                const v = p.vs[bi];
                const r = if (measure == .time) v.time_ratio else v.memory_ratio;
                if (r != null) any = true;
                try values.append(arena, r);
                try titles.append(arena, if (r) |x| try std.fmt.allocPrint(arena, "{s}, {s}, Crane {s}: {d}% of {s}'s {s} ({s} {s}, round {d}'s rows)", .{ try pointLabel(arena, p), p.date, p.commit, percent(x), b.label(), what, b.label(), v.version orelse "", v.round orelse 0 }) else "");
            }
            if (any) try lines.append(arena, .{ .name = b.label(), .class = series_classes[bi], .values = values.items, .titles = titles.items });
        }
        try w.print("<h3>{s}</h3>\n<figure class=\"chart\">", .{if (measure == .time) "Time" else "Memory, steady"});
        const aria = try std.fmt.allocPrint(arena, "Crane's {s} as a percentage of each browser's over {d} points, from {s} to {s}; the numbers are in the table below.", .{ what, pts.len, try pointLabel(arena, pts[0]), try pointLabel(arena, pts[pts.len - 1]) });
        try chart.ratioChart(w, .{ .aria = aria }, cpoints.items, lines.items, mark);
        try w.writeAll("<figcaption class=\"chart-key\">");
        for (lines.items) |ln| {
            try w.print("<span><svg width=\"22\" height=\"10\" aria-hidden=\"true\"><line class=\"{s}\" x1=\"1\" x2=\"21\" y1=\"5\" y2=\"5\"/></svg>", .{ln.class});
            try html.text(w, ln.name);
            try w.writeAll("</span>");
        }
        // The parity line is drawn only where the chart's scale reaches it (chart.ratioChart).
        var lo: f64 = std.math.floatMax(f64);
        var hi: f64 = 0;
        for (lines.items) |ln| for (ln.values) |v| if (v) |x| {
            lo = @min(lo, x);
            hi = @max(hi, x);
        };
        if (chart.reachesParity(lo, hi)) try w.writeAll("<span>100%: parity</span>");
        if (mark != null) try w.writeAll("<span>dashed: the CPU target&rsquo;s step</span>");
        try w.writeAll("</figcaption></figure>\n");
        try w.writeAll("<div class=\"table-wrap\"><table class=\"listing\"><thead><tr><th scope=\"col\">Point</th><th scope=\"col\">Date</th><th scope=\"col\">Crane</th><th scope=\"col\">CPU target</th>");
        for (browsers) |b| try w.print("<th scope=\"col\" class=\"n\">{s}</th>", .{b.label()});
        try w.writeAll("</tr></thead><tbody>\n");
        for (pts) |p| {
            try w.writeAll("<tr><th scope=\"row\">");
            try html.text(w, try pointLabel(arena, p));
            try w.writeAll("</th><td>");
            try html.text(w, p.date);
            try w.writeAll("</td><td><code>");
            try html.text(w, p.commit);
            try w.writeAll("</code></td><td><code>");
            try html.text(w, p.target orelse "not recorded");
            try w.writeAll("</code></td>");
            for (p.vs) |v| {
                const r = if (measure == .time) v.time_ratio else v.memory_ratio;
                if (r) |x| try w.print("<td class=\"n {s}\">{d}%</td>", .{ ratioClass(x), percent(x) }) else try w.writeAll("<td class=\"n\">&ndash;</td>");
            }
            try w.writeAll("</tr>\n");
        }
        try w.writeAll("</tbody></table></div>\n");
    }
    try w.writeAll("</section>\n");
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

/// Crane (its release build, `crane`) round by round: each workload's time
/// and steady memory in every round that has it, and the latest round's
/// over the one before. Where the round has a drift control and a base of
/// the control's commit for the fixed target (`targetAlone`), the change
/// splits in two: the code's (tip over base, one target) and the target's
/// (base over control, one source).
fn writeCraneHistory(w: W, arena: Allocator, m: *const Model) !void {
    const pts = try progress(arena, m);
    if (pts.len < 2) return;
    const first = pts[0].round;
    const latest = pts[pts.len - 1].round;
    const split = (try targetAlone(arena, m, latest)) != null;
    var cpoints: std.ArrayList(chart.Point) = .empty;
    var mark_at: ?usize = null;
    for (pts, 0..) |p, i| {
        try cpoints.append(arena, .{ .label = try pointLabel(arena, p), .hollow = p.engine == .crane_base });
        if (p.engine == .crane_base and mark_at == null and i > 0) mark_at = i;
    }
    try w.print("<section id=\"crane-history\"><h2>Crane, round by round</h2>\n<p>Each workload&rsquo;s time per operation and steady memory for Crane&rsquo;s release build (ReleaseSafe) at every point of its progress, and round {d}&rsquo;s figure as a share of round {d}&rsquo;s.", .{ latest, first });
    for (pts) |p| {
        try w.writeAll(" ");
        try html.text(w, try pointLabel(arena, p));
        try w.writeAll(": <code>");
        try html.text(w, p.target orelse "target not recorded");
        try w.writeAll("</code>.");
    }
    if (split) try w.writeAll(" Where a round has both, its change splits into the code&rsquo;s (Crane over its base, one CPU target) and the CPU target&rsquo;s (the base over the control, one source); on the sparklines the target&rsquo;s step is dashed.");
    try w.writeAll("</p>\n<div class=\"table-wrap\"><table class=\"listing\"><thead><tr><th scope=\"col\">Workload</th>");
    for ([_][]const u8{ "Time", "Memory" }) |what| {
        for (pts) |p| {
            try w.print("<th scope=\"col\" class=\"n\">{s}, ", .{what});
            try html.text(w, try pointLabel(arena, p));
            try w.writeAll("</th>");
        }
        try w.print("<th scope=\"col\" class=\"n\">Since round {d}</th>", .{first});
        if (split) try w.writeAll("<th scope=\"col\" class=\"n\">Code</th><th scope=\"col\" class=\"n\">Target</th>");
        try w.writeAll("<th scope=\"col\">Trend</th>");
    }
    try w.writeAll("</tr></thead><tbody>\n");
    for (try m.workloads(arena, latest)) |wl| {
        const c = m.current(latest, .crane, wl) orelse continue;
        if (c.kind == .gc_bench) continue;
        const f = m.current(first, .crane, wl);
        const base = m.current(latest, .crane_base, wl);
        const control = m.current(latest, .crane_control, wl);
        try w.writeAll("<tr><th scope=\"row\"><code>");
        try html.text(w, wl);
        try w.writeAll("</code></th>");
        for ([_]Measure{ .time, .steady }) |measure| {
            var values: std.ArrayList(?f64) = .empty;
            for (pts) |p| {
                const cell = m.current(p.round, p.engine, wl);
                try writeMeasureCell(w, cell, measure);
                try values.append(arena, if (cell) |x| figureOf(x, measure) else null);
            }
            try writeRatio(w, figureOf(c, measure), if (f) |x| figureOf(x, measure) else null);
            if (split) {
                try writeRatio(w, figureOf(c, measure), if (base) |x| figureOf(x, measure) else null);
                try writeRatio(w, if (base) |x| figureOf(x, measure) else null, if (control) |x| figureOf(x, measure) else null);
            }
            try w.writeAll("<td>");
            try chart.sparkline(w, try std.fmt.allocPrint(arena, "{s} {s} over the points", .{ wl, if (measure == .time) "time" else "memory" }), values.items, cpoints.items, mark_at);
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

test "Crane round by round: each workload's figures in every round, and the latest over the one before" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const m = try build(a, try roundOneRecords(a, 1.0, 1.0));
    const page = (try render(a, &m, .{})).index_html;
    const i = std.mem.indexOf(u8, page, "id=\"crane-history\"").?;
    const section = page[i .. i + std.mem.indexOf(u8, page[i..], "</section>").?];
    try testing.expect(std.mem.indexOf(u8, section, "Round 0") != null);
    try testing.expect(std.mem.indexOf(u8, section, "Round 1") != null);
    // dom.a: 40 -> 20 us per op (50%), memory 1000 -> 400 bytes (40%).
    try testing.expect(std.mem.indexOf(u8, section, "<code>dom.a</code>") != null);
    try testing.expect(std.mem.indexOf(u8, section, ">50%<") != null);
    try testing.expect(std.mem.indexOf(u8, section, ">40%<") != null);
    // The control's and the base's rows are in the full history, named.
    const history = page[std.mem.indexOf(u8, page, "id=\"history\"").?..];
    try testing.expect(std.mem.indexOf(u8, history, "<td>Crane control</td>") != null);
    // A single round has no round-by-round table.
    const r0 = [_]journal.Record{ try timed(a, 0, .crane, "abc", "dom.a", 0, 20, 100), try timed(a, 0, .chrome, "157", "dom.a", 0, 10, 400) };
    try testing.expect(std.mem.indexOf(u8, (try render(a, &(try build(a, &r0)), .{})).index_html, "id=\"crane-history\"") == null);
}

test "progress: Crane's headline round by round, the target's step apart from the code's" {
    // The user, 2026-11-06: the page shows the progress Crane makes over time.
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const m = try build(a, try roundOneRecords(a, 1.0, 1.0));
    const pts = try progress(a, &m);
    try testing.expectEqual(@as(usize, 3), pts.len);
    // Round 0: native, its target named by round 1's control (the same binary).
    try testing.expectEqual(EngineName.crane, pts[0].engine);
    try testing.expectEqualStrings("9b0f1b1f382", pts[0].commit);
    try testing.expectEqualStrings("apple_m4 (native)", pts[0].target.?);
    try testing.expectEqualStrings("2026-11-05", pts[0].date);
    // Round 0's source for apple_m1, measured in round 1: 44/10 and 11/5 of Chrome's.
    try testing.expectEqual(EngineName.crane_base, pts[1].engine);
    try testing.expectEqual(@as(u32, 1), pts[1].round);
    try testing.expectEqual(@as(u32, 0), pts[1].source_round);
    try testing.expectEqualStrings("apple_m1", pts[1].target.?);
    try testing.expectApproxEqAbs(@as(f64, std.math.sqrt(4.4 * 2.2)), pts[1].vs[0].time_ratio.?, 1e-12);
    // Round 1, against Chrome's round-0 rows: 20/10 and 10/5.
    try testing.expectEqualStrings("aaaaaaaaaaa", pts[2].commit);
    try testing.expectApproxEqAbs(@as(f64, 2.0), pts[2].vs[0].time_ratio.?, 1e-12);
    try testing.expectEqual(@as(?u32, 0), pts[2].vs[0].round);
    try testing.expectApproxEqAbs(@as(f64, std.math.sqrt(8.0)), pts[0].vs[0].time_ratio.?, 1e-12);
    // Since round 0: time 20/40 and 10/10, memory 400/1000 and 1000/1000.
    const since = (try sinceFirst(a, &m)).?;
    try testing.expectApproxEqAbs(@as(f64, std.math.sqrt(0.5)), since.time_ratio.?, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, std.math.sqrt(0.4)), since.memory_ratio.?, 1e-12);
    try testing.expectEqual(@as(?u32, 0), since.round);

    const out = try render(a, &m, .{});
    const page = out.index_html;
    const i = std.mem.indexOf(u8, page, "id=\"progress\"").?;
    const section = page[i .. i + std.mem.indexOf(u8, page[i..], "</section>").?];
    // Near the top: right after the headline.
    try testing.expect(i < std.mem.indexOf(u8, page, "id=\"drift\"").?);
    // A chart and a table each for time and memory, the numbers in the tables.
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, section, "<svg class=\"chart-svg perf-chart\""));
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, section, "<table"));
    try testing.expect(std.mem.indexOf(u8, section, "Round 0&#39;s source") != null);
    try testing.expect(std.mem.indexOf(u8, section, ">283%<") != null);
    try testing.expect(std.mem.indexOf(u8, section, ">200%<") != null);
    // Each point says what its round changed, and where the target changed.
    try testing.expect(std.mem.indexOf(u8, section, "Lane perf1") != null);
    try testing.expect(std.mem.indexOf(u8, section, ">CPU target apple_m1</text>") != null);
    try testing.expect(std.mem.indexOf(u8, section, "Since round 0, Crane&rsquo;s time is 70.7%") != null);
    // The description and the card name the progress.
    try testing.expect(std.mem.indexOf(u8, page, "Since round 0: 71% of its time and 63% of its memory.") != null);
    // Every workload's history has its trend drawn, and its change since round 0.
    const h = std.mem.indexOf(u8, page, "id=\"crane-history\"").?;
    const hist = page[h .. h + std.mem.indexOf(u8, page[h..], "</section>").?];
    try testing.expectEqual(@as(usize, 4), std.mem.count(u8, hist, "<svg class=\"chart-svg spark\""));
    try testing.expect(std.mem.indexOf(u8, hist, "Since round 0</th>") != null);
    // Still no script: the content is all in the HTML.
    try testing.expect(std.mem.indexOf(u8, page, "<script") == null);
    // A single round has no progress section.
    const r0 = [_]journal.Record{ try timed(a, 0, .crane, "abc", "dom.a", 0, 20, 100), try timed(a, 0, .chrome, "157", "dom.a", 0, 10, 400) };
    const single = try build(a, &r0);
    try testing.expect((try sinceFirst(a, &single)) == null);
    try testing.expect(std.mem.indexOf(u8, (try render(a, &single, .{})).index_html, "id=\"progress\"") == null);
}

test "every round has its note, in order" {
    for (round_notes, 0..) |n, i| {
        try testing.expectEqual(@as(u32, @intCast(i)), n.round);
        try testing.expect(n.note.len > 0);
    }
    try testing.expect(roundNote(1) != null);
    try testing.expect(roundNote(99) == null);
}
