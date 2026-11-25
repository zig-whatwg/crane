//! `perf_bench cost`: a lane's cost pair - the new Crane (`crane`, the tip)
//! against the Crane it is based on (`crane_base`), measured in alternation
//! by `perf_bench run` - read against the 3% bar (AGENTS.md, "The 3% memory
//! bar reads what Crane holds"; docs/performance.md, "A lane's cost pair").
//! It replaces the tables each lane wrote for itself (lane wb1's
//! w-perfsum.py and memrows.sh, lane mem2's cost_sum.py).
//!
//! Two passes of the pair:
//! - the DEFAULT pass: time, CPU and instructions are read and judged
//!   here; its steady and peak memory are printed for information and
//!   never judged (the allocator's ring is on: the same bytes read in two
//!   levels by chance);
//! - the MEMORY pass, memory only, both sides with macOS malloc's
//!   deferred-reclamation ring off (`MallocLargeCache=0`) and one malloc
//!   magazine (`MallocMaxMagazines=1`, the user 2026-11-23) and, when it was
//!   run with `--collected`, each workload's footprint read once more after
//!   a full collection the page asked for (`footprint_collected`).
//!
//! THE RULE (AGENTS.md; the user, 2026-11-15 and 2026-11-17): a memory row
//! is judged on the steady figure and the peak of the MEMORY pass - the
//! tip's median over the base's, over all its launches - and only there.
//! A figure above the bar may be CLEARED, with every launch's value
//! printed, when
//! (a) both sides reached a common level and each such level's tip / base
//!     ratio is within the bar, or
//! (b) the row's collected figure is within the bar.
//! A figure above the bar that neither clears is OVER (`Verdict`), and the
//! command then exits 1. The collected figure never replaces steady and
//! peak: it is read only to clear a row they put over the bar.
//!
//! What the two clearing readings are, for the rows a median cannot read (lane
//! wb1, 2026-11-16: the streams, attributes, page-growth and fetch rows sit
//! on two memory levels; a median of 3 or 9 launches flips between them,
//! and two consoles can sit on different levels with disjoint ranges in
//! either direction - +3.3% on one pair of trees, -3.3% on the next, the
//! same lane diff):
//! 1. LEVELS OF BOTH SIDES TOGETHER (`Joint`). The two sides run the same
//!    page on the same host in alternation, so a level belongs to the page:
//!    it is looked for in the launches of both sides at once, and each
//!    launch is then put on the low or the high one (`jointLevels`).
//!    report.zig's own levels (`levelsOf`, lane mem1) need two tight groups
//!    on ONE side, so
//!    they miss a side with 8 launches low and 1 high, any pass of 3
//!    launches, and two sides that each sit on one level. Per level both
//!    sides reached, the tip's median over the base's; and each side's
//!    share of high launches, with the chance of shares that far apart from
//!    one coin (Fisher's exact test).
//! 2. THE COLLECTED FIGURE. With the ring off, what is left of a level is
//!    garbage waiting for a collection at the settle mark: whether V8
//!    started a marking task in the idle half second (the streams page),
//!    whether a full collection landed inside the page (the attributes
//!    page). After a collection the page asks for, the footprint is what
//!    the workload keeps, and the collector's schedule cannot choose it.
//! A row whose sides share no level ("apart") is the one the steady figure
//! cannot settle: the tip may hold more, or the two builds may each prefer
//! a level. The collected figure is printed for it; where there is none,
//! the row says so.
//!
//! Engine-free and file-free: records in, text out.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const journal = @import("journal.zig");
const stats = @import("stats.zig");
const report = @import("report.zig");

const W = *Io.Writer;

/// The cost bar: a ratio above it is over.
pub const default_bar = 1.03;

/// Shares of high launches that differ with less than this chance under
/// one coin are named as differing.
pub const share_chance = 0.05;

pub const Measure = enum {
    time,
    cpu,
    instructions,
    steady,
    peak,
    collected,

    pub fn isMemory(m: Measure) bool {
        return switch (m) {
            .time, .cpu, .instructions => false,
            .steady, .peak, .collected => true,
        };
    }
};

const measure_count = @typeInfo(Measure).@"enum".field_names.len;

/// The launches of both sides for one row and one memory measure, read
/// together.
pub const Joint = struct {
    /// The tip's median over the base's, all launches: the rule's figure.
    plain: f64,
    /// Null: the launches of both sides form one level.
    levels: ?Levels = null,

    pub const Levels = struct {
        /// Each level: the median of every launch on it, either side (bytes).
        low: u64,
        high: u64,
        tip_low: u32,
        tip_high: u32,
        base_low: u32,
        base_high: u32,
        /// The tip's median on the level over the base's; null when a side
        /// has no launch on it.
        low_ratio: ?f64 = null,
        high_ratio: ?f64 = null,
        /// The chance of high-launch shares at least this far apart when
        /// both sides draw their level from one coin (Fisher's exact test,
        /// two-sided).
        share_chance: f64,

        /// Whether the sides reached a level in common.
        pub fn shared(l: Levels) bool {
            return l.low_ratio != null or l.high_ratio != null;
        }

        /// Level against level: the geometric mean of the ratios on the
        /// levels both sides reached; null when they share none.
        pub fn ratio(l: Levels) ?f64 {
            if (l.low_ratio) |a| {
                if (l.high_ratio) |b| return @sqrt(a * b);
                return a;
            }
            return l.high_ratio;
        }

        /// Whether the tip's launches are on the high level more often than
        /// the base's by more than one coin would give.
        pub fn tipHigherShare(l: Levels) bool {
            const tip_n = l.tip_low + l.tip_high;
            const base_n = l.base_low + l.base_high;
            if (tip_n == 0 or base_n == 0) return false;
            return l.share_chance < share_chance and l.tip_high * base_n > l.base_high * tip_n;
        }
    };
};

fn f64Of(v: u64) f64 {
    return @floatFromInt(v);
}

/// Whether `v` is nearer `low` than `high`, in ratio.
fn nearerLow(low: u64, high: u64, v: u64) bool {
    return @abs(@log(f64Of(v) / f64Of(low))) <= @abs(@log(f64Of(v) / f64Of(high)));
}

/// Two groups of both sides' launches are two levels when each is closer
/// together than half the gap between them: its own range at most the gap
/// over this. report.zig asks a quarter of one side's launches
/// (`level_tightness`); two sides together double the launches a group
/// holds and add the difference between two builds on one level, and a
/// level found here is evidence beside the rule, never the rule (lane
/// impls8's cost window: events.dispatch read 35.3-35.7 and 36.6-37.3 MB on
/// both sides, 1.1 MB apart, and 1.035 by the medians).
pub const joint_tightness = 2;

/// The two levels of both sides' launches, `all`: report.zig's test
/// (`levelsOf`: split at the widest gap between neighbours; the gap at
/// least `level_gap` of the lower group's median; `level_min_runs` in each
/// group) with `joint_tightness` for how tight a group must be.
fn jointLevels(gpa: Allocator, all: []const u64) Allocator.Error!?report.Levels {
    if (all.len < 2 * report.level_min_runs) return null;
    const sorted = try gpa.dupe(u64, all);
    defer gpa.free(sorted);
    std.mem.sort(u64, sorted, {}, std.sort.asc(u64));
    if (sorted[0] == 0) return null;
    var split: usize = 1;
    for (1..sorted.len) |i| {
        if (sorted[i] - sorted[i - 1] > sorted[split] - sorted[split - 1]) split = i;
    }
    const low = sorted[0..split];
    const high = sorted[split..];
    if (low.len < report.level_min_runs or high.len < report.level_min_runs) return null;
    const gap = high[0] - low[low.len - 1];
    const low_level = (try stats.medianU64(gpa, low)).?;
    if (f64Of(gap) < report.level_gap * f64Of(low_level)) return null;
    const widest = @max(low[low.len - 1] - low[0], high[high.len - 1] - high[0]);
    if (widest * joint_tightness > gap) return null;
    return .{
        .low = low_level,
        .low_runs = @intCast(low.len),
        .high = (try stats.medianU64(gpa, high)).?,
        .high_runs = @intCast(high.len),
    };
}

/// Both sides' launches of one row, read together; null when a side has
/// none, or a median is zero.
///
/// The levels are looked for in the launches of both sides at once
/// (`jointLevels`: two groups at least 3% apart, two launches or more in
/// each, each closer together than half the gap).
pub fn joint(gpa: Allocator, tip: []const u64, base: []const u64) Allocator.Error!?Joint {
    const tip_median = (try stats.medianU64(gpa, tip)) orelse return null;
    const base_median = (try stats.medianU64(gpa, base)) orelse return null;
    if (base_median == 0 or tip_median == 0) return null;
    var out: Joint = .{ .plain = f64Of(tip_median) / f64Of(base_median) };
    const all = try gpa.alloc(u64, tip.len + base.len);
    defer gpa.free(all);
    @memcpy(all[0..tip.len], tip);
    @memcpy(all[tip.len..], base);
    const found = (try jointLevels(gpa, all)) orelse return out;
    var levels: Joint.Levels = .{ .low = found.low, .high = found.high, .tip_low = 0, .tip_high = 0, .base_low = 0, .base_high = 0, .share_chance = 1 };
    const sides = [_][]const u64{ tip, base };
    var medians: [2][2]?u64 = @splat(@splat(null));
    for (sides, 0..) |values, side| {
        const low = try gpa.alloc(u64, values.len);
        defer gpa.free(low);
        const high = try gpa.alloc(u64, values.len);
        defer gpa.free(high);
        var n_low: usize = 0;
        var n_high: usize = 0;
        for (values) |v| {
            if (nearerLow(found.low, found.high, v)) {
                low[n_low] = v;
                n_low += 1;
            } else {
                high[n_high] = v;
                n_high += 1;
            }
        }
        medians[side][0] = try stats.medianU64(gpa, low[0..n_low]);
        medians[side][1] = try stats.medianU64(gpa, high[0..n_high]);
        if (side == 0) {
            levels.tip_low = @intCast(n_low);
            levels.tip_high = @intCast(n_high);
        } else {
            levels.base_low = @intCast(n_low);
            levels.base_high = @intCast(n_high);
        }
    }
    if (medians[0][0]) |t| if (medians[1][0]) |b| {
        levels.low_ratio = f64Of(t) / f64Of(b);
    };
    if (medians[0][1]) |t| if (medians[1][1]) |b| {
        levels.high_ratio = f64Of(t) / f64Of(b);
    };
    levels.share_chance = fisherTwoSided(levels.tip_high, levels.tip_low, levels.base_high, levels.base_low);
    out.levels = levels;
    return out;
}

/// The number of ways to choose `k` of `n`, as a float (exact to a float's
/// precision for the launch counts a pass has).
fn choose(n: u32, k: u32) f64 {
    if (k > n) return 0;
    const m = @min(k, n - k);
    var c: f64 = 1;
    var i: u32 = 0;
    while (i < m) : (i += 1) c = c * @as(f64, @floatFromInt(n - i)) / @as(f64, @floatFromInt(i + 1));
    return c;
}

/// Fisher's exact test, two-sided, of the table (a b / c d): the chance,
/// with the row and column totals fixed, of a table no more likely than
/// this one. For two sides' launches on the high and the low level, the
/// chance of shares at least this far apart from one coin. 1 for an empty
/// row or column.
pub fn fisherTwoSided(a: u32, b: u32, c: u32, d: u32) f64 {
    const row1 = a + b;
    const row2 = c + d;
    const col1 = a + c;
    const n = row1 + row2;
    if (row1 == 0 or row2 == 0 or col1 == 0 or col1 == n) return 1;
    const total = choose(n, col1);
    const observed = choose(row1, a) * choose(row2, c) / total;
    const least = col1 -| row2;
    const most = @min(col1, row1);
    var sum: f64 = 0;
    var x = least;
    while (x <= most) : (x += 1) {
        const p = choose(row1, x) * choose(row2, col1 - x) / total;
        // No more likely than the observed table (a hair of tolerance for
        // the float arithmetic).
        if (p <= observed * (1 + 1e-9)) sum += p;
    }
    return @min(sum, 1);
}

/// One side of one row in one pass: each ok launch's figure, per measure.
pub const SideRuns = struct {
    version: []const u8 = "",
    launches: u32 = 0,
    values: [measure_count]std.ArrayList(f64) = @splat(.empty),

    pub fn of(s: *const SideRuns, m: Measure) []const f64 {
        return s.values[@backingInt(m)].items;
    }
};

/// A launch's figure for `m`, as report.zig's cells read it
/// (`Cell.memoryFigure`, `Cell.peakFigure`, `summarise`): the steady
/// footprint where the record has it, else the one at the workload's end;
/// the level a page chain's footprint reaches for memory.page-growth; the
/// growth per instance for an instances row; nothing for a start-up row.
pub fn figureOf(gpa: Allocator, r: journal.Record, m: Measure) Allocator.Error!?f64 {
    if (r.status != .ok) return null;
    switch (m) {
        .time => return try stats.median(gpa, r.wall_ms),
        .cpu => return r.cpu_ms,
        .instructions => return if (r.instructions) |v| f64Of(v) else null,
        .steady => {
            if (std.mem.eql(u8, r.workload, "memory.page-growth")) {
                if (r.series.len < 4) return null;
                const level = (try stats.medianU64(gpa, r.series[r.series.len / 2 ..])) orelse return null;
                return f64Of(level);
            }
            if (r.kind == .instances) {
                const g = stats.slope(r.series) orelse return null;
                return if (g > 0) g else null;
            }
            if (r.kind == .startup) return null;
            const mem = r.memory orelse return null;
            return f64Of(mem.footprint_settled orelse mem.footprint_end);
        },
        .peak => {
            if (r.kind == .startup) return null;
            const mem = r.memory orelse return null;
            return f64Of(mem.footprint_peak);
        },
        .collected => {
            const mem = r.memory orelse return null;
            return if (mem.footprint_collected) |v| f64Of(v) else null;
        },
    }
}

/// One row of one pass: both sides' launches.
pub const Row = struct {
    workload: []const u8,
    page: []const u8,
    tip: SideRuns = .{},
    base: SideRuns = .{},
};

/// One pass of the pair: every workload both sides ran, in the journal's
/// order.
pub const Pass = struct {
    rows: []Row,
    tip_version: []const u8 = "",
    base_version: []const u8 = "",
    /// The most launches a row has, per side.
    tip_launches: u32 = 0,
    base_launches: u32 = 0,

    /// Whether any row has a collected figure (the pass was run with
    /// `--collected`). Every row is asked, not the headline's mean: a pass
    /// of rows outside the headline (`--only=overhead`) has them too.
    pub fn readCollected(p: *const Pass) bool {
        for (p.rows) |*r| if (r.tip.of(.collected).len > 0 or r.base.of(.collected).len > 0) return true;
        return false;
    }

    pub fn row(p: *const Pass, workload: []const u8) ?*const Row {
        for (p.rows) |*r| if (std.mem.eql(u8, r.workload, workload)) return r;
        return null;
    }
};

pub const PassError = error{
    /// No record of `crane`, or none of `crane_base`.
    NoTip,
    NoBase,
    /// Two versions of one side in one pass: which is compared?
    TwoTips,
    TwoBases,
} || Allocator.Error;

/// The pass `records` hold. gc_bench's rows and the retained pages (memory
/// per element) are not a cost pair's rows.
pub fn passOf(arena: Allocator, records: []const journal.Record) PassError!Pass {
    var rows: std.ArrayList(Row) = .empty;
    var pass: Pass = .{ .rows = &.{} };
    for (records) |r| {
        const is_tip = switch (r.engine.name) {
            .crane => true,
            .crane_base => false,
            else => continue,
        };
        if (r.kind == .gc_bench or r.kind == .retained) continue;
        const version: *[]const u8 = if (is_tip) &pass.tip_version else &pass.base_version;
        if (version.len == 0) {
            version.* = r.engine.version;
        } else if (!std.mem.eql(u8, version.*, r.engine.version)) {
            return if (is_tip) error.TwoTips else error.TwoBases;
        }
        const at = for (rows.items, 0..) |row, i| {
            if (std.mem.eql(u8, row.workload, r.workload)) break i;
        } else blk: {
            try rows.append(arena, .{ .workload = r.workload, .page = r.page });
            break :blk rows.items.len - 1;
        };
        const side: *SideRuns = if (is_tip) &rows.items[at].tip else &rows.items[at].base;
        if (r.status != .ok) continue;
        side.launches += 1;
        inline for (@typeInfo(Measure).@"enum".field_values) |fv| {
            const m: Measure = @fromBackingInt(@intCast(fv));
            if (try figureOf(arena, r, m)) |v| try side.values[@backingInt(m)].append(arena, v);
        }
    }
    if (pass.tip_version.len == 0) return error.NoTip;
    if (pass.base_version.len == 0) return error.NoBase;
    for (rows.items) |row| {
        pass.tip_launches = @max(pass.tip_launches, row.tip.launches);
        pass.base_launches = @max(pass.base_launches, row.base.launches);
    }
    pass.rows = rows.items;
    return pass;
}

/// One row's reading of one measure in one pass.
pub const Reading = struct {
    /// The tip's median over the base's, all launches: the rule's figure.
    ratio: f64,
    tip_median: f64,
    base_median: f64,
    /// The two sides' launches do not overlap.
    apart: bool,
    /// Memory measures: the levels of both sides together (`Joint`).
    levels: ?Joint.Levels = null,
};

/// `row`'s reading of `m`; null when either side has no figure for it.
pub fn reading(gpa: Allocator, row: *const Row, m: Measure) Allocator.Error!?Reading {
    const tip = row.tip.of(m);
    const base = row.base.of(m);
    const tip_median = (try stats.median(gpa, tip)) orelse return null;
    const base_median = (try stats.median(gpa, base)) orelse return null;
    if (!(base_median > 0) or !(tip_median > 0)) return null;
    var out: Reading = .{
        .ratio = tip_median / base_median,
        .tip_median = tip_median,
        .base_median = base_median,
        .apart = std.mem.min(f64, tip) > std.mem.max(f64, base) or std.mem.max(f64, tip) < std.mem.min(f64, base),
    };
    if (m.isMemory()) {
        const t = try gpa.alloc(u64, tip.len);
        defer gpa.free(t);
        const b = try gpa.alloc(u64, base.len);
        defer gpa.free(b);
        for (tip, t) |v, *o| o.* = @intFromFloat(v);
        for (base, b) |v, *o| o.* = @intFromFloat(v);
        if (try joint(gpa, t, b)) |j| out.levels = j.levels;
    }
    return out;
}

/// The geometric mean of `m`'s ratios over a pass's rows, and how many.
/// Over the headline's workloads, as report.zig's means are (`inHeadline`:
/// start-up, the harness's own floor and a page's own row are not in it).
pub fn mean(gpa: Allocator, pass: *const Pass, m: Measure) Allocator.Error!struct { ratio: ?f64, n: usize } {
    var ratios: std.ArrayList(f64) = .empty;
    defer ratios.deinit(gpa);
    for (pass.rows) |*row| {
        if (!report.inHeadline(row.workload)) continue;
        if (try reading(gpa, row, m)) |r| try ratios.append(gpa, r.ratio);
    }
    return .{ .ratio = stats.geometricMean(ratios.items), .n = ratios.items.len };
}

pub const Options = struct {
    bar: f64 = default_bar,
    /// What the passes are, for the header (a directory each).
    default_name: []const u8 = "",
    memory_name: []const u8 = "",
};

/// What the rule says of one steady or peak figure.
pub const Verdict = enum {
    /// At or under the bar.
    within,
    /// Above the bar, and cleared: (a) both sides reached a common level
    /// and each such level's ratio is within the bar.
    cleared_by_levels,
    /// Above the bar, and cleared: (b) the collected figure is within it.
    cleared_by_collected,
    /// Above the bar and not cleared.
    over,

    pub fn cleared(v: Verdict) bool {
        return v == .cleared_by_levels or v == .cleared_by_collected;
    }
};

/// The rule's verdict on a steady or peak reading `r`, with the row's
/// collected reading where the memory pass read one.
pub fn verdictOf(r: Reading, collected: ?Reading, bar: f64) Verdict {
    if (!(r.ratio > bar)) return .within;
    if (r.levels) |l| if (l.shared()) {
        const low_ok = if (l.low_ratio) |x| x <= bar else true;
        const high_ok = if (l.high_ratio) |x| x <= bar else true;
        if (low_ok and high_ok) return .cleared_by_levels;
    };
    if (collected) |c| if (c.ratio <= bar) return .cleared_by_collected;
    return .over;
}

/// What the cost command decided, beside its text.
pub const Summary = struct {
    /// Time and instruction rows over the bar (above it, the sides apart).
    time_over: usize = 0,
    instructions_over: usize = 0,
    /// Steady and peak figures of the MEMORY pass above the bar...
    memory_over: usize = 0,
    /// ... of which cleared by (a), by (b), and not cleared.
    memory_cleared_levels: usize = 0,
    memory_cleared_collected: usize = 0,
    memory_not_cleared: usize = 0,
    /// Memory figures whose sides share no level (in the pass the bar is
    /// read on): the figure alone cannot settle them.
    memory_apart_levels: usize = 0,
    /// Steady and peak figures of the DEFAULT pass above the bar: printed
    /// for information, never part of the verdict (the ring is on).
    default_pass_above: usize = 0,
    /// Whether a memory pass was read: without one, memory is not judged.
    memory_judged: bool = false,

    /// Whether the pair is over the bar: a time or instruction row, or a
    /// memory figure the rule does not clear.
    pub fn failed(s: Summary) bool {
        return s.time_over + s.instructions_over + s.memory_not_cleared > 0;
    }
};

const mb = 1024.0 * 1024.0;

fn writeUnit(w: W, m: Measure, v: f64) !void {
    switch (m) {
        .time, .cpu => try w.print("{d:.3} ms", .{v}),
        .instructions => try w.print("{d:.1} M", .{v / 1e6}),
        .steady, .peak, .collected => try w.print("{d:.1} MB", .{v / mb}),
    }
}

fn writeLaunches(w: W, gpa: Allocator, m: Measure, label: []const u8, values: []const f64) !void {
    const sorted = try gpa.dupe(f64, values);
    defer gpa.free(sorted);
    std.mem.sort(f64, sorted, {}, std.sort.asc(f64));
    try w.print("      {s}", .{label});
    for (sorted) |v| switch (m) {
        .time, .cpu => try w.print(" {d:.3}", .{v}),
        .instructions => try w.print(" {d:.1}", .{v / 1e6}),
        .steady, .peak, .collected => try w.print(" {d:.1}", .{v / mb}),
    };
    try w.writeByte('\n');
}

/// The levels line of a memory reading: "levels of both sides together:
/// 297.3 and 308.1 MB; tip 2 low / 7 high, base 6 low / 3 high (...)".
fn writeLevels(w: W, l: Joint.Levels) !void {
    try w.print("      levels of both sides together: {d:.1} and {d:.1} MB; tip {d} low / {d} high, base {d} low / {d} high", .{
        f64Of(l.low) / mb, f64Of(l.high) / mb, l.tip_low, l.tip_high, l.base_low, l.base_high,
    });
    if (!l.shared()) {
        try w.writeAll(": the sides share no level - this figure cannot say whether the tip holds more or the two builds each prefer a level\n");
        return;
    }
    try w.writeAll("; level against level:");
    if (l.low_ratio) |r| try w.print(" low {d:.3}", .{r});
    if (l.high_ratio) |r| try w.print(" high {d:.3}", .{r});
    try w.print("; the chance of these shares from one coin {d:.3}{s}\n", .{ l.share_chance, if (l.tipHigherShare()) " - the tip is on the high level more often" else "" });
}

/// One memory finding in full: the figure's ratio, every launch, the
/// levels, and the row's collected figure from the memory pass where it
/// has one, with every launch of that too; for a steady or peak figure
/// above `bar`, the rule's verdict (null: no verdict is printed).
///
/// `other_pass_row`: for a figure of the default pass, the same row of the
/// memory pass, whose reading of the same figure is printed - with the ring
/// off it is the nearer of the two to what Crane holds, and it is judged in
/// its own right.
fn writeMemoryFinding(w: W, gpa: Allocator, row: *const Row, m: Measure, r: Reading, pass_label: []const u8, collected_row: ?*const Row, bar: ?f64, other_pass_row: ?*const Row) !void {
    try w.print("  {s}  {s}, {s}: {d:.3} (tip ", .{ row.workload, pass_label, @tagName(m), r.ratio });
    try writeUnit(w, m, r.tip_median);
    try w.writeAll(" | base ");
    try writeUnit(w, m, r.base_median);
    try w.writeAll(")\n");
    try writeLaunches(w, gpa, m, "launches, MB   tip: ", row.tip.of(m));
    try writeLaunches(w, gpa, m, "               base:", row.base.of(m));
    if (r.levels) |l| {
        try writeLevels(w, l);
    } else try w.writeAll("      one level: the launches of both sides form no two groups\n");
    if (m == .collected) return;
    if (other_pass_row) |other| {
        if (try reading(gpa, other, m)) |o| {
            try w.print("      the same figure on the memory pass (the ring off): {d:.3} (tip {d:.1} MB | base {d:.1} MB)\n", .{ o.ratio, o.tip_median / mb, o.base_median / mb });
        } else try w.writeAll("      the same figure on the memory pass: not read\n");
    }
    var collected: ?Reading = null;
    if (collected_row) |c_row| collected = try reading(gpa, c_row, .collected);
    if (collected) |c| {
        try w.print("      collected (after a full collection the page asked for): {d:.3} (tip {d:.1} MB | base {d:.1} MB)", .{ c.ratio, c.tip_median / mb, c.base_median / mb });
        if (c.levels) |l| {
            try w.writeAll(" - it reads two levels too:\n");
            try writeLevels(w, l);
        } else try w.writeAll(", one level\n");
        try writeLaunches(w, gpa, .collected, "collected, MB  tip: ", collected_row.?.tip.of(.collected));
        try writeLaunches(w, gpa, .collected, "               base:", collected_row.?.base.of(.collected));
    } else try w.writeAll("      collected: not read (run the memory pass with --collected)\n");
    const limit = bar orelse return;
    switch (verdictOf(r, collected, limit)) {
        .within => {},
        .cleared_by_levels => try w.writeAll("      VERDICT: CLEARED (a) - both sides reached a common level, and each level they share reads within the bar\n"),
        .cleared_by_collected => try w.print("      VERDICT: CLEARED (b) - the collected figure reads within the bar ({d:.3})\n", .{collected.?.ratio}),
        .over => {
            try w.writeAll("      VERDICT: OVER THE BAR - (a) ");
            if (r.levels) |l| {
                if (l.shared()) try w.writeAll("a level both sides reached reads over the bar") else try w.writeAll("the sides share no level");
            } else try w.writeAll("the launches form one level");
            if (collected) |c| try w.print("; (b) the collected figure reads {d:.3}\n", .{c.ratio}) else try w.writeAll("; (b) no collected figure was read\n");
        },
    }
}

/// What a table cell's figure is to the verdict.
const CellKind = union(enum) {
    /// Time or instructions: `!` above the bar.
    plain,
    /// A memory figure of the default pass: `i` above the bar (for
    /// information; memory is judged on the memory pass).
    information,
    /// A memory figure of the memory pass: `!` above the bar and not
    /// cleared, `c` above it and cleared.
    judged: Verdict,
};

/// A table cell: the ratio, its flag (`CellKind`), and `*` when the two
/// sides' launches are apart.
fn writeCell(w: W, r: ?Reading, bar: f64, kind: CellKind) !void {
    const x = r orelse return w.writeAll("       -  ");
    const flag: []const u8 = if (!(x.ratio > bar)) " " else switch (kind) {
        .plain => "!",
        .information => "i",
        .judged => |verdict| if (verdict.cleared()) "c" else "!",
    };
    try w.print("  {d:>6.3}{s}{s}", .{ x.ratio, flag, if (x.apart) "*" else " " });
}

/// The cost pair's table. `memory` is the memory-only pass (null: none was
/// run, and the memory bar is read on the default pass alone).
pub fn write(w: W, gpa: Allocator, default: *const Pass, memory: ?*const Pass, options: Options) !Summary {
    var summary: Summary = .{};
    const bar = options.bar;
    try w.print("perf_bench cost: tip {s} against base {s}; the bar is {d:.2} (tip / base)\n", .{ default.tip_version, default.base_version, bar });
    try w.print("  default pass{s}{s}: {d} rows, {d} launches of the tip and {d} of the base\n", .{ if (options.default_name.len > 0) " " else "", options.default_name, default.rows.len, default.tip_launches, default.base_launches });
    if (memory) |p| {
        try w.print("  memory pass{s}{s}: {d} rows, {d} launches of the tip and {d} of the base; the collected figure {s}\n", .{ if (options.memory_name.len > 0) " " else "", options.memory_name, p.rows.len, p.tip_launches, p.base_launches, if (p.readCollected()) "was read" else "was not read (no --collected)" });
        if (!std.mem.eql(u8, p.tip_version, default.tip_version) or !std.mem.eql(u8, p.base_version, default.base_version)) {
            try w.print("  NOTE: the memory pass compares {s} against {s}: not the default pass's builds\n", .{ p.tip_version, p.base_version });
        }
    } else try w.writeAll("  memory pass: none - MEMORY IS NOT JUDGED (the bar is read on a memory-only pass with the allocator's ring off; the default pass's memory figures are for information)\n");
    summary.memory_judged = memory != null;

    try w.writeAll("GEOMETRIC MEANS (tip / base, over the headline's workloads)\n  default pass:");
    inline for (.{ Measure.time, Measure.cpu, Measure.instructions, Measure.steady, Measure.peak }) |m| {
        const g = try mean(gpa, default, m);
        if (g.ratio) |r| try w.print(" {s} {d:.4} (n={d})", .{ @tagName(m), r, g.n }) else try w.print(" {s} not measured", .{@tagName(m)});
    }
    try w.writeByte('\n');
    if (memory) |p| {
        try w.writeAll("  memory pass: ");
        inline for (.{ Measure.steady, Measure.peak, Measure.collected }) |m| {
            const g = try mean(gpa, p, m);
            if (g.ratio) |r| try w.print(" {s} {d:.4} (n={d})", .{ @tagName(m), r, g.n }) else try w.print(" {s} not measured", .{@tagName(m)});
        }
        try w.writeByte('\n');
    }

    // Time and instructions: the default pass. A row is over when its ratio
    // is above the bar and the two sides' launches do not overlap (a ratio
    // inside the launches' own range is their spread).
    try w.writeAll("TIME AND INSTRUCTIONS OVER THE BAR (default pass; over = above the bar with the two sides' launches apart)\n");
    var any = false;
    for (default.rows) |*row| {
        inline for (.{ Measure.time, Measure.instructions }) |m| {
            if (try reading(gpa, row, m)) |r| if (r.ratio > bar and r.apart) {
                any = true;
                if (m == .time) summary.time_over += 1 else summary.instructions_over += 1;
                try w.print("  {s}  {s}: {d:.3} (tip ", .{ row.workload, @tagName(m), r.ratio });
                try writeUnit(w, m, r.tip_median);
                try w.writeAll(" | base ");
                try writeUnit(w, m, r.base_median);
                try w.writeAll(")\n");
                try writeLaunches(w, gpa, m, if (m == .time) "launches, ms   tip: " else "launches, M    tip: ", row.tip.of(m));
                try writeLaunches(w, gpa, m, "               base:", row.base.of(m));
            };
        }
    }
    if (!any) try w.writeAll("  none\n");

    // Memory by the rule: the memory pass's medians, steady and peak; a
    // figure above the bar with the two readings that may clear it.
    try w.writeAll("MEMORY ABOVE THE BAR ON STEADY OR PEAK (the memory pass: the medians of all its launches), AND THE RULE'S VERDICT\n");
    any = false;
    if (memory) |pass| {
        for (pass.rows) |*row| {
            inline for (.{ Measure.steady, Measure.peak }) |m| {
                if (try reading(gpa, row, m)) |r| if (r.ratio > bar) {
                    any = true;
                    summary.memory_over += 1;
                    switch (verdictOf(r, try reading(gpa, row, .collected), bar)) {
                        .within => unreachable,
                        .cleared_by_levels => summary.memory_cleared_levels += 1,
                        .cleared_by_collected => summary.memory_cleared_collected += 1,
                        .over => summary.memory_not_cleared += 1,
                    }
                    try writeMemoryFinding(w, gpa, row, m, r, "memory pass", row, bar, null);
                };
            }
        }
        if (!any) try w.writeAll("  none\n");
    } else try w.writeAll("  not judged: no memory pass\n");

    // The default pass's memory, for information: the ring is on, so the
    // same bytes read in two levels by chance, and the verdict never reads
    // these figures. Each says what the memory pass read for it.
    try w.writeAll("MEMORY ABOVE THE BAR ON THE DEFAULT PASS (the ring on: FOR INFORMATION, never part of the verdict)\n");
    any = false;
    for (default.rows) |*row| {
        const memory_row: ?*const Row = if (memory) |p| p.row(row.workload) else null;
        inline for (.{ Measure.steady, Measure.peak }) |m| {
            if (try reading(gpa, row, m)) |r| if (r.ratio > bar) {
                any = true;
                summary.default_pass_above += 1;
                try writeMemoryFinding(w, gpa, row, m, r, "default pass", memory_row, null, memory_row);
            };
        }
    }
    if (!any) try w.writeAll("  none\n");

    // What the medians do not show, in the pass the bar is read on: sides
    // on different levels with the tip the lower (the next pair of trees
    // may read the other way), and shares of high launches that differ.
    const judged = memory orelse default;
    const judged_label: []const u8 = if (memory != null) "memory pass" else "default pass";
    try w.print("LEVELS THE MEDIANS DO NOT SHOW ({s}; rows at or under the bar)\n", .{judged_label});
    any = false;
    for (judged.rows) |*row| {
        inline for (.{ Measure.steady, Measure.peak, Measure.collected }) |m| {
            if (try reading(gpa, row, m)) |r| {
                if (r.levels) |l| {
                    if (m != .collected and !l.shared()) summary.memory_apart_levels += 1;
                    const over_by_rule = m != .collected and r.ratio > bar;
                    if (!over_by_rule and (!l.shared() or l.tipHigherShare() or m == .collected)) {
                        any = true;
                        try writeMemoryFinding(w, gpa, row, m, r, judged_label, if (m == .collected) null else row, null, null);
                    }
                }
            }
        }
    }
    if (!any) try w.writeAll("  none\n");

    // Every row.
    try w.writeAll("ALL ROWS (tip / base; ! = above the bar, c = a memory-pass figure above the bar that the rule clears, i = a default-pass memory figure above the bar: for information, * = the two sides' launches apart, L = two levels)\n");
    try w.print("  {s:<34} {s:>9} {s:>9} {s:>9} {s:>9}", .{ "default pass, then | memory pass", "time", "instr", "steady", "peak" });
    if (memory != null) try w.print(" | {s:>9} {s:>9} {s:>9}", .{ "steady", "peak", "collected" });
    try w.writeByte('\n');
    for (default.rows) |*row| {
        try w.print("  {s:<34}", .{row.workload});
        inline for (.{ Measure.time, Measure.instructions, Measure.steady, Measure.peak }) |m| {
            try writeCell(w, try reading(gpa, row, m), bar, if (m.isMemory()) .information else .plain);
        }
        if (memory) |p| {
            try w.writeAll(" |");
            var leveled = false;
            if (p.row(row.workload)) |mrow| {
                const collected = try reading(gpa, mrow, .collected);
                inline for (.{ Measure.steady, Measure.peak, Measure.collected }) |m| {
                    const r = try reading(gpa, mrow, m);
                    if (r) |x| if (x.levels != null) {
                        leveled = true;
                    };
                    // The collected figure is not a figure of the bar: no flag.
                    if (m == .collected) {
                        if (r) |x| try w.print("  {d:>6.3}  ", .{x.ratio}) else try w.writeAll("       -  ");
                    } else try writeCell(w, r, bar, .{ .judged = if (r) |x| verdictOf(x, collected, bar) else .within });
                }
            } else try w.writeAll("       -         -         -  ");
            if (leveled) try w.writeAll(" L");
        }
        try w.writeByte('\n');
    }
    try w.print("SUMMARY: time {d} and instructions {d} rows over the bar; memory (the memory pass) {d} steady or peak figures above it - {d} cleared by (a) common levels within the bar, {d} cleared by (b) the collected figure, {d} NOT CLEARED; {d} memory figures whose sides share no level; {d} default-pass memory figures above the bar, for information\n", .{
        summary.time_over, summary.instructions_over, summary.memory_over, summary.memory_cleared_levels, summary.memory_cleared_collected, summary.memory_not_cleared, summary.memory_apart_levels, summary.default_pass_above,
    });
    try w.print("VERDICT: {s}{s}\n", .{ if (summary.failed()) "OVER THE BAR" else "within the bar", if (summary.memory_judged) "" else " on time and instructions; MEMORY NOT JUDGED (no memory pass)" });
    return summary;
}

// ---------------------------------------------------------------------------

const testing = std.testing;

const mib = 1024 * 1024;

test "levels of both sides together: a side with one launch on the other level, and the per-level ratios" {
    const a = testing.allocator;
    // Lane wb1's streams rows: both sides read 297 and 308 MB, the tip high
    // in 7 launches of 9 and the base in 3 - neither side's medians are on
    // one level, and the medians' ratio reads +3.4%.
    const tip = [_]u64{ 297_100_000, 297_300_000, 307_900_000, 308_000_000, 308_100_000, 308_200_000, 308_200_000, 308_300_000, 308_400_000 };
    const base = [_]u64{ 297_000_000, 297_200_000, 297_300_000, 297_500_000, 297_900_000, 298_000_000, 307_800_000, 308_000_000, 308_300_000 };
    const j = (try joint(a, &tip, &base)).?;
    try testing.expect(j.plain > 1.03);
    const l = j.levels.?;
    try testing.expectEqual(@as(u32, 2), l.tip_low);
    try testing.expectEqual(@as(u32, 7), l.tip_high);
    try testing.expectEqual(@as(u32, 6), l.base_low);
    try testing.expectEqual(@as(u32, 3), l.base_high);
    try testing.expect(l.shared());
    // On each level the two builds hold the same.
    try testing.expectApproxEqAbs(@as(f64, 1.0), l.low_ratio.?, 0.002);
    try testing.expectApproxEqAbs(@as(f64, 1.0), l.high_ratio.?, 0.002);
    try testing.expectApproxEqAbs(@as(f64, 1.0), l.ratio().?, 0.002);
    // 7 of 9 against 3 of 9: not beyond one coin at nine launches a side.
    try testing.expectApproxEqAbs(@as(f64, 0.153), l.share_chance, 0.001);
    try testing.expect(!l.tipHigherShare());

    // 8 low and 1 high against 1 low and 8 high: no side alone has two
    // levels of two launches (report.levelsOf says one level with an
    // outlier, and the medians are compared: +3.6%); together they do.
    const t2 = [_]u64{ 100 * mib, 100 * mib + 4096, 100 * mib, 100 * mib + 8192, 100 * mib, 100 * mib + 4096, 100 * mib, 100 * mib, 104 * mib };
    const b2 = [_]u64{ 100 * mib, 104 * mib, 104 * mib + 4096, 104 * mib, 104 * mib + 8192, 104 * mib, 104 * mib, 104 * mib + 4096, 104 * mib };
    try testing.expectEqual(@as(?report.Levels, null), try report.levelsOf(a, &t2));
    try testing.expectEqual(@as(?report.Levels, null), try report.levelsOf(a, &b2));
    const j2 = (try joint(a, &t2, &b2)).?;
    try testing.expect(j2.plain < 0.97);
    const l2 = j2.levels.?;
    try testing.expectEqual(@as(u32, 8), l2.tip_low);
    try testing.expectEqual(@as(u32, 1), l2.tip_high);
    try testing.expectEqual(@as(u32, 1), l2.base_low);
    try testing.expectEqual(@as(u32, 8), l2.base_high);
    try testing.expectApproxEqAbs(@as(f64, 1.0), l2.ratio().?, 0.001);
    // 1 of 9 against 8 of 9 is beyond one coin - and it is the BASE that is
    // high more often.
    try testing.expect(l2.share_chance < 0.01);
    try testing.expect(!l2.tipHigherShare());
    const reversed = (try joint(a, &b2, &t2)).?.levels.?;
    try testing.expect(reversed.tipHigherShare());
}

test "levels of both sides together: a pass of three launches a side, sides that share no level, and one level" {
    const a = testing.allocator;
    // Three launches a side: no side can show two levels of two launches.
    const tip = [_]u64{ 297 * mib, 308 * mib, 308 * mib + 8192 };
    const base = [_]u64{ 297 * mib + 4096, 297 * mib + 8192, 308 * mib + 4096 };
    const l = (try joint(a, &tip, &base)).?.levels.?;
    try testing.expectEqual(@as(u32, 1), l.tip_low);
    try testing.expectEqual(@as(u32, 2), l.tip_high);
    try testing.expectEqual(@as(u32, 2), l.base_low);
    try testing.expectEqual(@as(u32, 1), l.base_high);
    try testing.expectApproxEqAbs(@as(f64, 1.0), l.ratio().?, 0.001);

    // Lane wb1's merged pair: every launch of the tip at 271 MB, every
    // launch of the base at 280 MB. Two levels, none shared: no ratio, and
    // the row is not settled by this figure.
    const t3 = [_]u64{ 271 * mib, 271 * mib + 65536, 271 * mib + 4096, 271 * mib + 8192 };
    const b3 = [_]u64{ 280 * mib, 280 * mib + 4096, 280 * mib + 65536, 280 * mib + 8192 };
    const j3 = (try joint(a, &t3, &b3)).?;
    try testing.expectApproxEqAbs(@as(f64, 271.0 / 280.0), j3.plain, 0.001);
    const l3 = j3.levels.?;
    try testing.expect(!l3.shared());
    try testing.expectEqual(@as(?f64, null), l3.ratio());
    try testing.expectEqual(@as(u32, 4), l3.tip_low);
    try testing.expectEqual(@as(u32, 0), l3.tip_high);
    try testing.expectEqual(@as(u32, 4), l3.base_high);

    // One level: both sides within a fraction of a percent.
    const t4 = [_]u64{ 150 * mib, 150 * mib + 65536, 150 * mib + 4096 };
    const b4 = [_]u64{ 150 * mib + 8192, 150 * mib, 150 * mib + 32768 };
    const j4 = (try joint(a, &t4, &b4)).?;
    try testing.expectEqual(@as(?Joint.Levels, null), j4.levels);
    try testing.expectApproxEqAbs(@as(f64, 1.0), j4.plain, 0.001);
    // A side with no launch reads nothing.
    try testing.expectEqual(@as(?Joint, null), try joint(a, &.{}, &b4));
}

test "levels of both sides together: groups wider than a quarter of the gap, as two builds on one level are" {
    const a = testing.allocator;
    // Lane impls8's cost window, events.dispatch on the default pass: both
    // sides read about 35.4 and about 36.9 MB, the groups 0.4 and 0.7 MB
    // wide and 0.9 MB apart; the medians read 1.035.
    const mb10 = mib / 10;
    const tip = [_]u64{ 354 * mb10, 355 * mb10, 357 * mb10, 368 * mb10, 368 * mb10, 372 * mb10, 373 * mb10 };
    const base = [_]u64{ 353 * mb10, 354 * mb10, 354 * mb10, 355 * mb10, 368 * mb10, 368 * mb10, 369 * mb10 };
    const j = (try joint(a, &tip, &base)).?;
    try testing.expect(j.plain > 1.03);
    const l = j.levels.?;
    try testing.expectEqual(@as(u32, 3), l.tip_low);
    try testing.expectEqual(@as(u32, 4), l.tip_high);
    try testing.expectEqual(@as(u32, 4), l.base_low);
    try testing.expectEqual(@as(u32, 3), l.base_high);
    try testing.expect(l.low_ratio.? < 1.01 and l.high_ratio.? < 1.01);
    try testing.expect(!l.tipHigherShare());
    // A spread with no gap that wide is one level: 81-83 MB and five
    // launches from 92 to 97 (the streams page's collected figure, lane
    // tl2's demonstration) - the upper group is wider than half the gap.
    const spread = [_]u64{ 817 * mb10, 819 * mb10, 820 * mb10, 821 * mb10, 824 * mb10, 825 * mb10, 923 * mb10, 964 * mb10 };
    const spread_base = [_]u64{ 817 * mb10, 818 * mb10, 820 * mb10, 822 * mb10, 822 * mb10, 917 * mb10, 967 * mb10, 972 * mb10 };
    try testing.expectEqual(@as(?Joint.Levels, null), (try joint(a, &spread, &spread_base)).?.levels);
}

test "Fisher's exact test, two-sided: the chance of shares this far apart from one coin" {
    // The classic tea-tasting table (3 1 / 1 3): 34 / 70.
    try testing.expectApproxEqAbs(@as(f64, 34.0 / 70.0), fisherTwoSided(3, 1, 1, 3), 1e-12);
    // Every launch of one side high, every launch of the other low, four a
    // side: 2 / 70.
    try testing.expectApproxEqAbs(@as(f64, 2.0 / 70.0), fisherTwoSided(4, 0, 0, 4), 1e-12);
    // Lane wrap2's streams.reader: 17 of 19 high against 8 of 19.
    try testing.expect(fisherTwoSided(17, 2, 8, 11) < 0.01);
    // Equal shares, and a table with an empty row or column.
    try testing.expectApproxEqAbs(@as(f64, 1.0), fisherTwoSided(3, 3, 3, 3), 1e-12);
    try testing.expectEqual(@as(f64, 1), fisherTwoSided(0, 0, 3, 3));
    try testing.expectEqual(@as(f64, 1), fisherTwoSided(0, 5, 0, 5));
    try testing.expectEqual(@as(f64, 1), fisherTwoSided(5, 0, 5, 0));
}

fn testRecord(arena: Allocator, name: journal.EngineName, version: []const u8, workload: []const u8, run: u32, wall: f64, instructions: u64, settled: u64, peak: u64, collected: ?u64) !journal.Record {
    return .{
        .format = journal.format_name,
        .round = 0,
        .time = "2026-11-17T10:00:00Z",
        .host = .{ .name = "h", .os = "macOS", .arch = "aarch64", .cpu = "M", .cores = 8, .memory_bytes = 1 },
        .engine = .{ .name = name, .version = version, .build = "release", .commit = version, .optimize = "o", .v8 = "v8", .binary = "/b/repl", .binary_sha256 = "abababababababababababababababababababababababababababababababab", .flags = &.{} },
        .page = "workloads/streams.html",
        .workload = workload,
        .kind = .timed,
        .run = run,
        .status = .ok,
        .ops = 100,
        .wall_ms = try arena.dupe(f64, &.{ wall, wall, wall }),
        .cpu_ms = wall * 3,
        .instructions = instructions,
        .memory = .{ .footprint_start = settled, .footprint_end = settled, .footprint_peak = peak, .resident_end = settled, .processes = 1, .footprint_settled = settled, .footprint_collected = collected },
    };
}

test "a pass: both sides' launches per row, read as the report's cells read them; other engines and gc_bench rows are not a pair's" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    var records: std.ArrayList(journal.Record) = .empty;
    for (0..3) |i| {
        const run: u32 = @intCast(i);
        try records.append(a, try testRecord(a, .crane, "tip1", "streams.reader", run, 10.0 + @as(f64, @floatFromInt(i)), 1_000_000, 300 * mib, 400 * mib, 250 * mib));
        try records.append(a, try testRecord(a, .crane_base, "base1", "streams.reader", run, 10.0, 1_000_000, 300 * mib, 400 * mib, 250 * mib));
        try records.append(a, try testRecord(a, .chrome, "157", "streams.reader", run, 5.0, 1, 1, 1, null));
    }
    var gc = try testRecord(a, .crane, "tip1", "gc-bench.getter-loop", 0, 1, 1, 1, 1, null);
    gc.kind = .gc_bench;
    try records.append(a, gc);
    var failed = try testRecord(a, .crane, "tip1", "streams.reader", 3, 1, 1, 1, 1, null);
    failed.status = .timeout;
    failed.message = "no result in 300 s";
    try records.append(a, failed);

    const pass = try passOf(a, records.items);
    try testing.expectEqual(@as(usize, 1), pass.rows.len);
    try testing.expectEqualStrings("tip1", pass.tip_version);
    try testing.expectEqualStrings("base1", pass.base_version);
    try testing.expectEqual(@as(u32, 3), pass.tip_launches);
    const row = pass.row("streams.reader").?;
    // The failed launch has no figure; the three ok ones have each.
    try testing.expectEqualSlices(f64, &.{ 10, 11, 12 }, row.tip.of(.time));
    try testing.expectEqual(@as(usize, 3), row.base.of(.steady).len);
    try testing.expectEqual(@as(f64, 250 * mib), row.tip.of(.collected)[0]);
    const time = (try reading(a, row, .time)).?;
    try testing.expectApproxEqAbs(@as(f64, 1.1), time.ratio, 1e-12);
    // 10, 11, 12 against 10, 10, 10: they touch at 10, so not apart.
    try testing.expect(!time.apart);

    // The steady figure is the cell's: report.zig's median over the same
    // records is this pass's median.
    const model = try report.build(a, records.items);
    const cell = model.current(0, .crane, "streams.reader").?;
    try testing.expectEqual(cell.memoryFigure().?, (try stats.median(a, row.tip.of(.steady))).?);
    try testing.expectEqual(cell.peakFigure().?, (try stats.median(a, row.tip.of(.peak))).?);

    // A pass needs both sides, one version of each.
    try testing.expectError(error.NoBase, passOf(a, records.items[0..1]));
    try testing.expectError(error.NoTip, passOf(a, records.items[1..2]));
    try records.append(a, try testRecord(a, .crane, "tip2", "streams.reader", 4, 1, 1, 1, 1, null));
    try testing.expectError(error.TwoTips, passOf(a, records.items));
}

test "the cost table: the rule's verdict stays the medians'; the levels and the collected figure stand beside it" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    // The default pass: one row, no change.
    var default_records: std.ArrayList(journal.Record) = .empty;
    for (0..3) |i| {
        const run: u32 = @intCast(i);
        try default_records.append(a, try testRecord(a, .crane, "tip1", "streams.reader", run, 10, 1_000_000, 320 * mib, 400 * mib, null));
        try default_records.append(a, try testRecord(a, .crane_base, "base1", "streams.reader", run, 10, 1_000_000, 320 * mib, 400 * mib, null));
        // A row whose time is over the bar with the sides apart.
        try default_records.append(a, try testRecord(a, .crane, "tip1", "dom.clone-node", run, 10.5, 1_050_000, 100 * mib, 110 * mib, null));
        try default_records.append(a, try testRecord(a, .crane_base, "base1", "dom.clone-node", run, 10, 1_000_000, 100 * mib, 110 * mib, null));
    }
    // The memory pass: streams.reader on two levels, the tip high in 7 of 9
    // and the base in 3 of 9; collected, both read 250 MB.
    var memory_records: std.ArrayList(journal.Record) = .empty;
    for (0..9) |i| {
        const run: u32 = @intCast(i);
        const jitter: u64 = @as(u64, i) * 4096;
        try memory_records.append(a, try testRecord(a, .crane, "tip1", "streams.reader", run, 10, 1, (if (i < 2) @as(u64, 297) else 308) * mib + jitter, 400 * mib, 250 * mib + jitter));
        try memory_records.append(a, try testRecord(a, .crane_base, "base1", "streams.reader", run, 10, 1, (if (i < 6) @as(u64, 297) else 308) * mib + jitter, 400 * mib, 250 * mib + jitter));
        // A row whose sides share no level, the tip the lower one.
        try memory_records.append(a, try testRecord(a, .crane, "tip1", "dom.clone-node", run, 10, 1, 271 * mib + jitter, 300 * mib, 200 * mib));
        try memory_records.append(a, try testRecord(a, .crane_base, "base1", "dom.clone-node", run, 10, 1, 280 * mib + jitter, 300 * mib, 200 * mib));
    }
    const default = try passOf(a, default_records.items);
    const memory = try passOf(a, memory_records.items);
    var out: Io.Writer.Allocating = .init(a);
    const summary = try write(&out.writer, a, &default, &memory, .{ .default_name = "d", .memory_name = "m" });
    const text = out.written();

    // The rule: the medians. streams.reader steady is over in the memory
    // pass (308 against 297), and it is the one memory figure over.
    try testing.expectEqual(@as(usize, 1), summary.memory_over);
    try testing.expectEqual(@as(usize, 1), summary.memory_cleared_levels);
    try testing.expectEqual(@as(usize, 0), summary.memory_not_cleared);
    // The time and instruction rows put the pair over all the same.
    try testing.expect(summary.failed());
    try testing.expectEqual(@as(usize, 1), summary.time_over);
    try testing.expectEqual(@as(usize, 1), summary.instructions_over);
    try testing.expectEqual(@as(usize, 1), summary.memory_apart_levels);
    try testing.expect(std.mem.indexOf(u8, text, "perf_bench cost: tip tip1 against base base1; the bar is 1.03") != null);
    try testing.expect(std.mem.indexOf(u8, text, "streams.reader  memory pass, steady: 1.037 (tip 308.0 MB | base 297.0 MB)") != null);
    // Beside it: every launch, the levels of both sides together, level
    // against level, and the collected figure.
    try testing.expect(std.mem.indexOf(u8, text, "launches, MB   tip:  297.0 297.0 308.0 308.0 308.0 308.0 308.0 308.0 308.0") != null);
    try testing.expect(std.mem.indexOf(u8, text, "tip 2 low / 7 high, base 6 low / 3 high; level against level: low 1.000 high 1.000; the chance of these shares from one coin 0.153") != null);
    try testing.expect(std.mem.indexOf(u8, text, "collected (after a full collection the page asked for): 1.000 (tip 250.0 MB | base 250.0 MB), one level") != null);
    try testing.expect(std.mem.indexOf(u8, text, "collected, MB  tip:  250.0 250.0 250.0 250.0 250.0 250.0 250.0 250.0 250.0") != null);
    try testing.expect(std.mem.indexOf(u8, text, "VERDICT: CLEARED (a) - both sides reached a common level, and each level they share reads within the bar") != null);
    // Time and instructions over the bar, with their launches.
    try testing.expect(std.mem.indexOf(u8, text, "dom.clone-node  time: 1.050 (tip 10.500 ms | base 10.000 ms)") != null);
    try testing.expect(std.mem.indexOf(u8, text, "dom.clone-node  instructions: 1.050") != null);
    // The row whose sides share no level is under the bar (0.968) and is
    // named all the same: the next pair may read it the other way.
    try testing.expect(std.mem.indexOf(u8, text, "LEVELS THE MEDIANS DO NOT SHOW (memory pass; rows at or under the bar)\n  dom.clone-node  memory pass, steady: 0.968") != null);
    try testing.expect(std.mem.indexOf(u8, text, "tip 9 low / 0 high, base 0 low / 9 high: the sides share no level") != null);
    // Every row once, in the journal's order.
    const table = text[std.mem.indexOf(u8, text, "ALL ROWS").?..];
    try testing.expect(std.mem.indexOf(u8, table, "streams.reader").? < std.mem.indexOf(u8, table, "dom.clone-node").?);
    try testing.expect(std.mem.indexOf(u8, table, " 1.037c ") != null);
    try testing.expect(std.mem.endsWith(u8, text, "VERDICT: OVER THE BAR\n"));
    try testing.expect(std.mem.indexOf(u8, table, " 1.050!*") != null);

    // With no memory pass the bar is read on the default pass, and says so.
    var alone: Io.Writer.Allocating = .init(a);
    const s2 = try write(&alone.writer, a, &default, null, .{});
    try testing.expectEqual(@as(usize, 0), s2.memory_over);
    try testing.expect(std.mem.indexOf(u8, alone.written(), "memory pass: none - MEMORY IS NOT JUDGED") != null);
    try testing.expect(!s2.memory_judged);
    try testing.expect(std.mem.endsWith(u8, alone.written(), "VERDICT: OVER THE BAR on time and instructions; MEMORY NOT JUDGED (no memory pass)\n"));
    try testing.expect(std.mem.indexOf(u8, alone.written(), "AND THE RULE'S VERDICT\n  not judged: no memory pass\n") != null);
}

fn levelsFor(low_ratio: ?f64, high_ratio: ?f64) Joint.Levels {
    return .{ .low = 297 * mib, .high = 308 * mib, .tip_low = 4, .tip_high = 5, .base_low = 5, .base_high = 4, .low_ratio = low_ratio, .high_ratio = high_ratio, .share_chance = 1 };
}

test "the rule's verdict on a figure above the bar: cleared by common levels, cleared by the collected figure, or over" {
    const bar = default_bar;
    const over: Reading = .{ .ratio = 1.037, .tip_median = 308, .base_median = 297, .apart = false };
    const collected_same: Reading = .{ .ratio = 1.001, .tip_median = 250, .base_median = 250, .apart = false };
    const collected_more: Reading = .{ .ratio = 1.035, .tip_median = 259, .base_median = 250, .apart = true };
    // At or under the bar there is nothing to clear.
    try testing.expectEqual(Verdict.within, verdictOf(.{ .ratio = 1.03, .tip_median = 1, .base_median = 1, .apart = false }, null, bar));
    try testing.expectEqual(Verdict.within, verdictOf(.{ .ratio = 0.9, .tip_median = 1, .base_median = 1, .apart = true }, collected_more, bar));
    // (a) Both sides reached a common level and each such level is within
    // the bar - both levels, or the one level they share.
    var by_levels = over;
    by_levels.levels = levelsFor(1.004, 0.995);
    try testing.expectEqual(Verdict.cleared_by_levels, verdictOf(by_levels, null, bar));
    try testing.expectEqual(Verdict.cleared_by_levels, verdictOf(by_levels, collected_more, bar));
    by_levels.levels = levelsFor(null, 1.01);
    try testing.expectEqual(Verdict.cleared_by_levels, verdictOf(by_levels, null, bar));
    // (b) The collected figure within the bar: for sides that share no
    // level, for one level, and for a shared level that reads over.
    var apart_levels = over;
    apart_levels.levels = levelsFor(null, null);
    try testing.expectEqual(Verdict.cleared_by_collected, verdictOf(apart_levels, collected_same, bar));
    try testing.expectEqual(Verdict.cleared_by_collected, verdictOf(over, collected_same, bar));
    var one_level_over = over;
    one_level_over.levels = levelsFor(1.002, 1.04);
    try testing.expectEqual(Verdict.cleared_by_collected, verdictOf(one_level_over, collected_same, bar));
    // Not cleared: a real change - over on both levels and on the collected
    // figure - and every case with no reading that clears it.
    var real = over;
    real.levels = levelsFor(1.035, 1.036);
    try testing.expectEqual(Verdict.over, verdictOf(real, collected_more, bar));
    try testing.expectEqual(Verdict.over, verdictOf(real, null, bar));
    try testing.expectEqual(Verdict.over, verdictOf(one_level_over, collected_more, bar));
    try testing.expectEqual(Verdict.over, verdictOf(apart_levels, null, bar));
    try testing.expectEqual(Verdict.over, verdictOf(apart_levels, collected_more, bar));
    try testing.expectEqual(Verdict.over, verdictOf(over, null, bar));
    try testing.expect(Verdict.cleared_by_levels.cleared() and Verdict.cleared_by_collected.cleared());
    try testing.expect(!Verdict.over.cleared() and !Verdict.within.cleared());
}

test "a pair's verdict from its journals: one row cleared by levels, one by the collected figure, and a real 3.5% on both levels and collected is over" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const rows = [_][]const u8{ "streams.reader", "streams.enqueue-read", "streams.blob-stream" };
    var default_records: std.ArrayList(journal.Record) = .empty;
    var memory_records: std.ArrayList(journal.Record) = .empty;
    for (0..9) |i| {
        const run: u32 = @intCast(i);
        const jitter: u64 = @as(u64, i) * 4096;
        // The default pass: no row moved.
        for (rows) |name| {
            try default_records.append(a, try testRecord(a, .crane, "tip1", name, run, 10, 1_000_000, 320 * mib + jitter, 400 * mib, null));
            try default_records.append(a, try testRecord(a, .crane_base, "base1", name, run, 10, 1_000_000, 320 * mib + jitter, 400 * mib, null));
        }
        // (a) Both sides on 297 and 308 MB, the tip high more often.
        try memory_records.append(a, try testRecord(a, .crane, "tip1", rows[0], run, 10, 1, (if (i < 2) @as(u64, 297) else 308) * mib + jitter, 400 * mib, 250 * mib + jitter));
        try memory_records.append(a, try testRecord(a, .crane_base, "base1", rows[0], run, 10, 1, (if (i < 6) @as(u64, 297) else 308) * mib + jitter, 400 * mib, 250 * mib + jitter));
        // (b) Every launch of the tip on the high level, every launch of
        // the base on the low one; collected, they hold the same.
        try memory_records.append(a, try testRecord(a, .crane, "tip1", rows[1], run, 10, 1, 308 * mib + jitter, 400 * mib, 250 * mib + jitter));
        try memory_records.append(a, try testRecord(a, .crane_base, "base1", rows[1], run, 10, 1, 297 * mib + jitter, 400 * mib, 250 * mib + jitter));
        // A real change: the tip holds 3.5% more on the low level, on the
        // high level and collected; both sides 4 launches low and 5 high.
        const level: u64 = (if (i < 4) @as(u64, 297) else 340) * mib;
        try memory_records.append(a, try testRecord(a, .crane, "tip1", rows[2], run, 10, 1, level * 1035 / 1000 + jitter, 400 * mib, 250 * mib * 1035 / 1000 + jitter));
        try memory_records.append(a, try testRecord(a, .crane_base, "base1", rows[2], run, 10, 1, level + jitter, 400 * mib, 250 * mib + jitter));
    }
    const default = try passOf(a, default_records.items);
    const memory = try passOf(a, memory_records.items);
    var out: Io.Writer.Allocating = .init(a);
    const summary = try write(&out.writer, a, &default, &memory, .{});
    const text = out.written();
    try testing.expectEqual(@as(usize, 3), summary.memory_over);
    try testing.expectEqual(@as(usize, 1), summary.memory_cleared_levels);
    try testing.expectEqual(@as(usize, 1), summary.memory_cleared_collected);
    try testing.expectEqual(@as(usize, 1), summary.memory_not_cleared);
    try testing.expectEqual(@as(usize, 0), summary.time_over);
    try testing.expect(summary.failed());
    // Each row's verdict follows its own finding, in the journal's order.
    const first = std.mem.indexOf(u8, text, "streams.reader  memory pass, steady: 1.037").?;
    const second = std.mem.indexOf(u8, text, "streams.enqueue-read  memory pass, steady: 1.037").?;
    const third = std.mem.indexOf(u8, text, "streams.blob-stream  memory pass, steady: 1.035").?;
    try testing.expect(first < second and second < third);
    try testing.expect(std.mem.indexOf(u8, text[first..second], "VERDICT: CLEARED (a)") != null);
    try testing.expect(std.mem.indexOf(u8, text[second..third], "the sides share no level") != null);
    try testing.expect(std.mem.indexOf(u8, text[second..third], "VERDICT: CLEARED (b) - the collected figure reads within the bar (1.000)") != null);
    // Every launch of the figure that clears it is printed.
    try testing.expect(std.mem.indexOf(u8, text[second..third], "collected, MB  tip:  250.0 250.0 250.0 250.0 250.0 250.0 250.0 250.0 250.0") != null);
    const tail = text[third..];
    try testing.expect(std.mem.indexOf(u8, tail, "tip 4 low / 5 high, base 4 low / 5 high; level against level: low 1.035 high 1.035") != null);
    try testing.expect(std.mem.indexOf(u8, tail, "VERDICT: OVER THE BAR - (a) a level both sides reached reads over the bar; (b) the collected figure reads 1.035") != null);
    try testing.expect(std.mem.endsWith(u8, text, "VERDICT: OVER THE BAR\n"));

    // A memory figure of the DEFAULT pass above the bar is printed for
    // information, with what the same figure reads with the ring off, and
    // is never part of the verdict: memory is judged on the memory pass.
    var ring_on: std.ArrayList(journal.Record) = .empty;
    for (0..9) |i| {
        const run: u32 = @intCast(i);
        try ring_on.append(a, try testRecord(a, .crane, "tip1", rows[1], run, 10, 1_000_000, 105 * mib + @as(u64, i) * 4096, 400 * mib, null));
        try ring_on.append(a, try testRecord(a, .crane_base, "base1", rows[1], run, 10, 1_000_000, 100 * mib + @as(u64, i) * 4096, 400 * mib, null));
    }
    const ring_on_pass = try passOf(a, ring_on.items);
    var out3: Io.Writer.Allocating = .init(a);
    const s3 = try write(&out3.writer, a, &ring_on_pass, &memory, .{});
    try testing.expect(std.mem.indexOf(u8, out3.written(), "streams.enqueue-read  default pass, steady: 1.050") != null);
    try testing.expect(std.mem.indexOf(u8, out3.written(), "the same figure on the memory pass (the ring off): 1.037 (tip 308.0 MB | base 297.0 MB)") != null);
    try testing.expectEqual(@as(usize, 1), s3.default_pass_above);
    // The verdict counts the memory pass's figures alone: the same three.
    try testing.expectEqual(@as(usize, 3), s3.memory_over);
    try testing.expectEqual(@as(usize, 1), s3.memory_cleared_collected);
    try testing.expectEqual(@as(usize, 1), s3.memory_not_cleared);
    const information = out3.written()[std.mem.indexOf(u8, out3.written(), "MEMORY ABOVE THE BAR ON THE DEFAULT PASS").?..];
    try testing.expect(std.mem.indexOf(u8, information[0..std.mem.indexOf(u8, information, "LEVELS THE MEDIANS").?], "VERDICT:") == null);

    // A rise on the ring-on pass ALONE does not fail the pair: the memory
    // pass reads the row level, so nothing is above the bar where memory is
    // judged.
    var level_memory: std.ArrayList(journal.Record) = .empty;
    for (0..9) |i| {
        const run: u32 = @intCast(i);
        try level_memory.append(a, try testRecord(a, .crane, "tip1", rows[1], run, 10, 1, 100 * mib + @as(u64, i) * 4096, 400 * mib, null));
        try level_memory.append(a, try testRecord(a, .crane_base, "base1", rows[1], run, 10, 1, 100 * mib + @as(u64, i) * 4096, 400 * mib, null));
    }
    const level_memory_pass = try passOf(a, level_memory.items);
    var out4: Io.Writer.Allocating = .init(a);
    const s4 = try write(&out4.writer, a, &ring_on_pass, &level_memory_pass, .{});
    try testing.expectEqual(@as(usize, 1), s4.default_pass_above);
    try testing.expectEqual(@as(usize, 0), s4.memory_over);
    try testing.expectEqual(@as(usize, 0), s4.memory_not_cleared);
    try testing.expect(!s4.failed());
    try testing.expect(std.mem.indexOf(u8, out4.written(), "streams.enqueue-read  default pass, steady: 1.050") != null);
    try testing.expect(std.mem.indexOf(u8, out4.written(), "the same figure on the memory pass (the ring off): 1.000") != null);
    try testing.expect(std.mem.indexOf(u8, out4.written(), " 1.050i*") != null);
    try testing.expect(std.mem.endsWith(u8, out4.written(), "VERDICT: within the bar\n"));

    // Without the row that really moved, the pair is within the bar: two
    // figures above it, both cleared.
    var cleared_records: std.ArrayList(journal.Record) = .empty;
    for (memory_records.items) |r| if (!std.mem.eql(u8, r.workload, rows[2])) try cleared_records.append(a, r);
    const cleared_pass = try passOf(a, cleared_records.items);
    var out2: Io.Writer.Allocating = .init(a);
    const s2 = try write(&out2.writer, a, &default, &cleared_pass, .{});
    try testing.expectEqual(@as(usize, 2), s2.memory_over);
    try testing.expectEqual(@as(usize, 0), s2.memory_not_cleared);
    try testing.expect(!s2.failed());
    try testing.expect(std.mem.endsWith(u8, out2.written(), "VERDICT: within the bar\n"));
}

// Rule (a)'s level grouping against its text (lane tool1, queue item 10,
// 2026-11-24): docs/performance.md, "A lane's cost pair" - "two groups at
// least 3% apart, two launches or more in each, each closer together than
// half the gap between them". The launches are the two windows the queue
// names; each test says which clause decides.

fn tenths(comptime values: anytype) [values.len]u64 {
    var out: [values.len]u64 = undefined;
    inline for (values, 0..) |v, i| out[i] = v * (mib / 10);
    return out;
}

test "rule (a)'s grouping, tab1's timers.message-channel: the tip between the base's two groups is one level by the text, and must be" {
    const a = testing.allocator;
    // The queue's ranges (the launches themselves were deleted with tab1's
    // bins): base 22.7-23.2 MB x6 and 24.3-24.9 x3, tip 23.8-24.6 x9.
    const base = tenths(.{ 227, 228, 229, 230, 231, 232, 243, 246, 249 });
    const tip = tenths(.{ 238, 239, 240, 241, 242, 243, 244, 245, 246 });
    const j = (try joint(a, &tip, &base)).?;
    // The medians: 24.2 over 23.1.
    try testing.expect(j.plain > 1.03);
    // Both sides together: the widest gap between neighbours is 23.2 ->
    // 23.8 MB, 0.6 MB, 2.6% of the lower group's median - under "at least
    // 3% apart". One level, as the tool said.
    try testing.expectEqual(@as(?Joint.Levels, null), j.levels);
    // The base alone looks bimodal (1.1 MB apart, 4.8%), but its upper
    // group is 0.6 MB wide, more than half that gap (and report.zig's own
    // test, a quarter, refuses it too): one level by both texts.
    try testing.expectEqual(@as(?report.Levels, null), try report.levelsOf(a, &base));
    // Why the text must not group these: were the base's upper group and
    // the tip one level, every tip launch would be on it (23.8 is nearer
    // 24.6 than 22.95 in ratio) and the level against level would read
    // within the bar - clearing a tip that sits on NEITHER of the base's
    // levels. The user ruled on this row instead (2026-11-23).
    try testing.expect(!nearerLow(229 * (mib / 10) + mib / 20, 246 * (mib / 10), 238 * (mib / 10)));
}

test "rule (a)'s grouping, cs1's observers.resize-construct: peak one level; collected bimodal but its upper mode too wide to be a level by the text" {
    const a = testing.allocator;
    // cs1's 9-launch pair, memory pass (chat.local
    // ~/crane-work/cs1-c-bins/costpair-635d7dfd6, 2026-11-24), MB.
    const tip_peak = tenths(.{ 658, 690, 693, 699, 699, 703, 712, 717, 744 });
    const base_peak = tenths(.{ 588, 662, 670, 670, 677, 693, 745, 746, 767 });
    const peak = (try joint(a, &tip_peak, &base_peak)).?;
    try testing.expectApproxEqAbs(@as(f64, 1.033), peak.plain, 0.001);
    // The widest gap is the base's lowest launch (58.8 -> 65.8): one launch
    // below it, not "two launches or more in each". One level.
    try testing.expectEqual(@as(?Joint.Levels, null), peak.levels);

    const tip_collected = tenths(.{ 193, 193, 203, 258, 262, 271, 279, 283, 284 });
    const base_collected = tenths(.{ 194, 204, 204, 204, 247, 271, 274, 283, 318 });
    const collected = (try joint(a, &tip_collected, &base_collected)).?;
    // 1.059 in the window's table, whose launches had more digits.
    try testing.expectApproxEqAbs(@as(f64, 1.059), collected.plain, 0.003);
    // Two modes by eye: 19.3-20.4 MB (7 launches) and 24.7-31.8 (11), 4.3
    // MB apart (21%). The upper one spans 7.1 MB - not "closer together
    // than half the gap" (2.15 MB) - so the text says one level, and the
    // code reads it so.
    try testing.expectEqual(@as(?Joint.Levels, null), collected.levels);
    // Without its widest launch (the base's 31.8) the upper mode still
    // spans 3.7 MB: the text's clause, not one stray launch, decides.
    try testing.expectEqual(@as(?Joint.Levels, null), (try joint(a, &tip_collected, base_collected[0..8])).?.levels);

    // The verdict the window printed: rule (a) has no levels to clear the
    // peak by, and rule (b) reads the collected median, which the 9-launch
    // sample put on different modes (tip median 26.2 high, base 24.7 high
    // but the base has 4 of 9 low against the tip's 3).
    const r: Reading = .{ .ratio = peak.plain, .tip_median = 69.9, .base_median = 67.7, .apart = false, .levels = peak.levels };
    const c: Reading = .{ .ratio = collected.plain, .tip_median = 26.2, .base_median = 24.7, .apart = false, .levels = collected.levels };
    try testing.expectEqual(Verdict.over, verdictOf(r, c, default_bar));
}

test "the memory pass's header says the collected figure was read when any row has it, in the headline or not" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    // A pass of the harness's floor alone (`--only=overhead`), which is not
    // in the headline: lane tool1's dry window said "was not read" over
    // records that carry it.
    var records: std.ArrayList(journal.Record) = .empty;
    for ([_]journal.EngineName{ .crane, .crane_base }) |name| try records.append(a, try testRecord(a, name, if (name == .crane) "tip1" else "base1", "overhead.empty", 0, 1, 1, 30 * mib, 31 * mib, 29 * mib));
    const memory = try passOf(a, records.items);
    try testing.expect(memory.readCollected());
    var out: Io.Writer.Allocating = .init(a);
    _ = try write(&out.writer, a, &memory, &memory, .{});
    try testing.expect(std.mem.indexOf(u8, out.written(), "the collected figure was read") != null);
    // And a pass with none says so.
    for (records.items) |*r| r.memory.?.footprint_collected = null;
    const plain = try passOf(a, records.items);
    try testing.expect(!plain.readCollected());
}
