//! Reference runs: another engine's results on Crane's own worklist, kept
//! beside Crane's and never counted as Crane's (lane chromeref1, the user,
//! 2026-11-03: "I want the chrome results on the same files represented in
//! our progress report").
//!
//!     zig build wpt-site -- import-reference --engine=chrome --report=<wptreport.json> \
//!         --manifest=<MANIFEST.json> --worklist=<txt> --meta=<run.json> --out=<dir>
//!
//! A reference run is a browser driven by WPT's own runner (`wpt run chrome
//! ... --log-wptreport`) over the test URLs of the worklist's sources. Its
//! wptreport names tests by URL; Crane's journal names them by source and
//! sums every URL of a source into one record (FileTally in
//! tests/wpt_runner/main.zig). `import` joins the two through the manifest
//! the run used (docs/lessons/testing-compare-wpt-results-through-the-manifest.md):
//! each URL goes to the source the manifest lists it under, never to a source
//! guessed from its suffix; a URL the manifest does not list, or lists under
//! a source outside the worklist, is counted and left out. Every URL of a
//! source that the report lacks (or SKIPped) is a missing URL, counted per
//! file and in total, so a pass-count difference is never read across two
//! populations without saying so.
//!
//! Per source the URLs are summed as Crane's runner sums its runs: worst
//! status wins (OK < TIMEOUT < ERROR < CRASH), PASS / FAIL and
//! PRECONDITION_FAILED / TIMEOUT / NOTRUN subtests counted as passed /
//! failed / timed out / not run.
//!
//! The result is `reference.json` in `--out` (wpt-results/reference/<engine>-<version>/):
//! a .json file, so no journal glob (`*.jsonl`) ever reads it, in a directory
//! two levels under wpt-results/, below where the progress report looks; and
//! every record in it carries `"engine"`. A journal line carrying an engine
//! other than Crane is refused by both readers of journals
//! (tools/wpt_progress.py and generate.zig), with a message: a reference
//! result placed where Crane's results are read is never counted as Crane's.

const std = @import("std");
const model = @import("model.zig");
const Allocator = std.mem.Allocator;

pub const format_id = "crane-wpt-reference/1";

/// The directory under wpt-results/ that holds reference runs, one
/// directory per run. It is not a run label: no journal is read from it.
pub const dir_name = "reference";

/// Whether a record that says it came from `engine` may be counted as
/// Crane's: one with no `engine` at all (every line Crane's runner writes) or
/// "crane". Anything else is a reference run's, and refused.
pub fn isCrane(engine: ?[]const u8) bool {
    const e = engine orelse return true;
    return std.mem.eql(u8, e, "crane");
}

// ============================================================================
// Statuses
// ============================================================================

fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

/// A test URL's harness status as Crane's runner files it for its source
/// (FileTally.add): OK, TIMEOUT and CRASH stay; wptrunner's
/// EXTERNAL-TIMEOUT is a TIMEOUT; ERROR, PRECONDITION_FAILED, INTERNAL-ERROR
/// and anything unknown are ERROR. SKIP is null: the URL did not run.
pub fn fileStatus(status: []const u8) ?[]const u8 {
    if (eql(status, "SKIP")) return null;
    if (eql(status, "OK")) return "OK";
    if (eql(status, "TIMEOUT") or eql(status, "EXTERNAL-TIMEOUT")) return "TIMEOUT";
    if (eql(status, "CRASH")) return "CRASH";
    return "ERROR";
}

/// journal.Status.severity's ranking, for "worst wins" over a source's URLs.
fn severity(file_status: []const u8) u8 {
    if (eql(file_status, "OK")) return 0;
    if (eql(file_status, "TIMEOUT")) return 1;
    if (eql(file_status, "CRASH")) return 3;
    return 2;
}

/// One source's URLs, summed.
pub const Tally = struct {
    status: []const u8 = "OK",
    counts: model.Counts = .{},
    /// URLs reported for the source (SKIP not included).
    urls: u32 = 0,
    /// URLs the manifest lists for the source that the report lacks or skipped.
    missing_urls: u32 = 0,
    /// The harness message of the URL that set the status (the first
    /// non-OK one with a message, when none outranks it).
    message: ?[]const u8 = null,

    /// Add one reported URL. `status` must not be SKIP (`fileStatus` null).
    pub fn add(t: *Tally, status: []const u8, message: ?[]const u8, subtests: []const ReportSub) void {
        const st = fileStatus(status) orelse return;
        t.urls += 1;
        if (!eql(st, "OK")) {
            if (message) |m| {
                if (severity(st) > severity(t.status) or t.message == null) t.message = m;
            }
        }
        if (severity(st) > severity(t.status)) t.status = st;
        for (subtests) |s| {
            if (eql(s.status, "PASS")) {
                t.counts.passed += 1;
            } else if (eql(s.status, "TIMEOUT")) {
                t.counts.timed_out += 1;
            } else if (eql(s.status, "NOTRUN")) {
                t.counts.notrun += 1;
            } else {
                // FAIL, PRECONDITION_FAILED and anything unknown: not a pass.
                t.counts.failed += 1;
            }
        }
    }
};

// ============================================================================
// Inputs: the wptreport, the manifest, the run's metadata
// ============================================================================

pub const ReportSub = struct { status: []const u8 };

pub const ReportResult = struct {
    @"test": []const u8,
    status: []const u8,
    message: ?[]const u8 = null,
    subtests: []const ReportSub = &.{},
};

pub const ReportRunInfo = struct {
    product: ?[]const u8 = null,
    browser_version: ?[]const u8 = null,
};

/// The parts of a wptreport (wptrunner's `--log-wptreport`) the join reads.
pub const Report = struct {
    results: []const ReportResult = &.{},
    run_info: ReportRunInfo = .{},
    /// Milliseconds since the epoch.
    time_start: ?u64 = null,
    time_end: ?u64 = null,
};

/// items.testharness of a MANIFEST.json: source <-> test URLs (no leading '/').
pub const Manifest = struct {
    urls_of: std.StringHashMapUnmanaged([]const []const u8) = .empty,
    source_of: std.StringHashMapUnmanaged([]const u8) = .empty,

    pub fn parse(arena: Allocator, bytes: []const u8) !Manifest {
        var m: Manifest = .{};
        const v = try std.json.parseFromSliceLeaky(std.json.Value, arena, bytes, .{});
        if (v != .object) return error.NotAManifest;
        const items = v.object.get("items") orelse return error.NotAManifest;
        if (items != .object) return error.NotAManifest;
        const th = items.object.get("testharness") orelse return error.NotAManifest;
        try m.walk(arena, "", th);
        return m;
    }

    fn walk(m: *Manifest, arena: Allocator, prefix: []const u8, node: std.json.Value) !void {
        switch (node) {
            .object => |obj| {
                var it = obj.iterator();
                while (it.next()) |e| {
                    const p = if (prefix.len == 0)
                        e.key_ptr.*
                    else
                        try std.fmt.allocPrint(arena, "{s}/{s}", .{ prefix, e.key_ptr.* });
                    try m.walk(arena, p, e.value_ptr.*);
                }
            },
            .array => |arr| {
                // [hash, [url or null, extras], ...]: a null URL is the source's own path.
                var list: std.ArrayList([]const u8) = .empty;
                if (arr.items.len > 1) for (arr.items[1..]) |entry| {
                    if (entry != .array or entry.array.items.len == 0) continue;
                    const url = switch (entry.array.items[0]) {
                        .string => |s| std.mem.trimStart(u8, s, "/"),
                        .null => prefix,
                        else => continue,
                    };
                    try list.append(arena, url);
                    try m.source_of.put(arena, url, prefix);
                };
                try m.urls_of.put(arena, prefix, list.items);
            },
            else => {},
        }
    }
};

/// The memory of a run's process tree, sampled every second: each process's
/// phys_footprint (its own dirty pages, anonymous and compressed - Activity
/// Monitor's "Memory"; the kernel charges a shared page to one owner, so a sum
/// over processes counts it once) summed into the ENGINE (the browser's
/// processes; Crane's runner processes that run files) and the HARNESS (the
/// test runner, its servers, the WebDriver), and the engine per runner group;
/// RSS summed over everything, for reference (it counts a shared page in every
/// process that maps it). Megabytes.
pub const Memory = struct {
    samples: u64 = 0,
    engine_peak_mb: f64 = 0,
    engine_mean_mb: f64 = 0,
    harness_peak_mb: f64 = 0,
    harness_mean_mb: f64 = 0,
    total_peak_mb: f64 = 0,
    total_mean_mb: f64 = 0,
    rss_total_peak_mb: f64 = 0,
    rss_total_mean_mb: f64 = 0,
    groups: u64 = 0,
    group_peak_max_mb: f64 = 0,
    group_peak_mean_mb: f64 = 0,
};

/// One timed run: wall clock, and the CPU of the run's whole process tree:
/// the rusage of everything it waited for (`user_s`, `sys_s`), and a sample of
/// the tree once a second (`tree_cpu_s`), which also sees a process no parent
/// waited for - Chrome's rusage missed a sixth of its CPU in the pilot. Crane's
/// runner uses the host's shared `wpt serve`, which is not its child, so its
/// share of that server's CPU over the run is `server_cpu_s`; wptrunner starts
/// its own servers, whose CPU is already in its tree.
pub const Measure = struct {
    wall_s: f64,
    user_s: f64,
    sys_s: f64,
    server_cpu_s: f64 = 0,
    tree_cpu_s: f64 = 0,
    /// Test URLs the run ran; zero: not recorded (the worklist's are assumed).
    tests: u64 = 0,
    /// Subtests passing, and reported, in this run; zero reported: not recorded.
    passed: u64 = 0,
    reported: u64 = 0,
    memory: ?Memory = null,

    /// The larger of the rusage and the sampled tree, plus the server share.
    pub fn cpu(m: Measure) f64 {
        return @max(m.user_s + m.sys_s, m.tree_cpu_s) + m.server_cpu_s;
    }
};

pub const CraneMeasure = struct {
    wall_s: f64,
    user_s: f64,
    sys_s: f64,
    server_cpu_s: f64 = 0,
    tree_cpu_s: f64 = 0,
    /// Test URLs the run ran; zero: not recorded.
    tests: u64 = 0,
    /// Subtests passing, and reported, in this run; zero reported: not recorded.
    passed: u64 = 0,
    reported: u64 = 0,
    memory: ?Memory = null,
    /// How this runner was built, in words ("release runner: ReleaseSafe throughout, ...").
    build: []const u8 = "",
    /// Worklist files Crane's runner ran.
    files: u64 = 0,
    /// The frozen runner that ran them (its directory or commit).
    runner: []const u8 = "",

    pub fn cpu(m: CraneMeasure) f64 {
        return @max(m.user_s + m.sys_s, m.tree_cpu_s) + m.server_cpu_s;
    }
};

pub const Overhead = struct {
    /// Trivial test files (tests/wpt/crane/harness-overhead/), run by both.
    files: u64,
    reference: Measure,
    crane: Measure,
    /// The same run over fewer of those files, which separates a harness's
    /// fixed start-up (wptrunner loads the manifest and starts its servers
    /// and browsers) from what each test costs. Zero / null: not measured.
    small_files: u64 = 0,
    small_reference: ?Measure = null,
    small_crane: ?Measure = null,
};

/// What a harness costs, from its overhead runs: the wall clock each empty
/// test adds to the whole runner pool, and the fixed start-up before the
/// first test. With one size of run, everything is per test.
pub const HarnessSplit = struct {
    per_test_s: f64,
    startup_s: f64,

    /// The harness's share of a run of `tests` test URLs.
    pub fn of(h: HarnessSplit, tests: u64) f64 {
        return h.startup_s + h.per_test_s * @as(f64, @floatFromInt(tests));
    }
};

pub fn harnessSplit(files: u64, wall_s: f64, small_files: u64, small_wall_s: ?f64) HarnessSplit {
    if (files == 0) return .{ .per_test_s = 0, .startup_s = 0 };
    if (small_wall_s) |sw| if (small_files > 0 and files > small_files and wall_s > sw) {
        const per = (wall_s - sw) / @as(f64, @floatFromInt(files - small_files));
        return .{ .per_test_s = per, .startup_s = @max(sw - per * @as(f64, @floatFromInt(small_files)), 0) };
    };
    return .{ .per_test_s = wall_s / @as(f64, @floatFromInt(files)), .startup_s = 0 };
}

pub fn harnessOf(o: Overhead, crane: bool) HarnessSplit {
    const m = if (crane) o.crane else o.reference;
    const sm = if (crane) o.small_crane else o.small_reference;
    return harnessSplit(o.files, m.wall_s, o.small_files, if (sm) |x| x.wall_s else null);
}

/// Wall and CPU time of the whole run on one host, with the same runner
/// count for both engines, and the harness overhead measured beside them.
pub const Timing = struct {
    processes: u32,
    /// Set when the reference's run is reused from an earlier window beside a
    /// later Crane run: why that is fair (the host and its conditions).
    reference_reused: []const u8 = "",
    reference: Measure,
    crane: ?CraneMeasure = null,
    overhead: ?Overhead = null,
};

/// What the window script records about the run (`--meta`).
pub const RunMeta = struct {
    browser_version: []const u8,
    webdriver_version: []const u8 = "",
    channel: []const u8 = "",
    /// The WPT tree the run used: Crane's tests/wpt gitlink at the worklist's commit.
    wpt_revision: []const u8,
    /// The Crane commit whose tests/wpt_0_1_worklist.txt chose the files.
    worklist_commit: []const u8,
    processes: u32,
    host: []const u8 = "",
    /// The command line, for the record.
    command: []const u8 = "",
    /// How the reference engine was built, in words ("official release build").
    build: []const u8 = "",
    /// The reference's JavaScript engine ("V8 15.7.212.1"), and Crane's ("V8 13.1.203").
    js_engine: []const u8 = "",
    crane_js_engine: []const u8 = "",
    /// Crane's runner build, named when no full Crane run is recorded yet
    /// (its overhead runs are): `timing.crane.build` names it otherwise.
    crane_build: []const u8 = "",
    /// ISO 8601 UTC. Taken from the report's time_start when it has one.
    date: []const u8 = "",
};

pub const Meta = struct {
    run: RunMeta,
    timing: ?Timing = null,
};

pub const Coverage = struct {
    /// Worklist sources, and those the manifest lists.
    sources: u64 = 0,
    sources_in_manifest: u64 = 0,
    /// Sources with at least one reported URL.
    sources_reported: u64 = 0,
    /// The manifest's URLs of the worklist's sources.
    urls_expected: u64 = 0,
    /// Distinct reported URLs among them.
    urls_reported: u64 = 0,
    /// Reported as SKIP.
    urls_skipped: u64 = 0,
    /// Expected and not reported (skipped included).
    urls_missing: u64 = 0,
    /// Reported, listed by the manifest, under a source outside the worklist.
    urls_outside: u64 = 0,
    /// Reported, not in the manifest at all.
    urls_unknown: u64 = 0,
};

// ============================================================================
// The join
// ============================================================================

pub const Diag = struct {
    buf: [512]u8 = undefined,
    len: usize = 0,

    pub fn message(d: *const Diag) []const u8 {
        return d.buf[0..d.len];
    }

    fn set(d: *Diag, comptime fmt: []const u8, args: anytype) void {
        const s = std.fmt.bufPrint(&d.buf, fmt, args) catch d.buf[0..];
        d.len = s.len;
    }
};

pub const ImportError = error{InvalidReference} || Allocator.Error;

pub const Imported = struct {
    engine: []const u8,
    meta: Meta,
    product: []const u8,
    time_start: ?u64,
    time_end: ?u64,
    coverage: Coverage,
    /// Sources with a record, sorted.
    paths: []const []const u8,
    tallies: []const Tally,
};

pub fn isHex(s: []const u8, min: usize, max: usize) bool {
    if (s.len < min or s.len > max) return false;
    for (s) |c| if (!std.ascii.isDigit(c) and !(c >= 'a' and c <= 'f')) return false;
    return true;
}

fn parseWorklist(arena: Allocator, text: []const u8) ![]const []const u8 {
    var list: std.ArrayList([]const u8) = .empty;
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        try list.append(arena, line);
    }
    return list.items;
}

/// Join a wptreport to the worklist through the manifest. Everything lives in
/// `arena`. An invalid input is error.InvalidReference with `diag` saying why.
pub fn import(
    arena: Allocator,
    engine: []const u8,
    report_bytes: []const u8,
    manifest_bytes: []const u8,
    worklist_text: []const u8,
    meta_bytes: []const u8,
    diag: *Diag,
) ImportError!Imported {
    if (engine.len == 0 or isCrane(engine)) {
        diag.set("--engine must name the reference engine (chrome, firefox, safari), not Crane", .{});
        return error.InvalidReference;
    }
    const opts: std.json.ParseOptions = .{ .ignore_unknown_fields = true };
    const meta = std.json.parseFromSliceLeaky(Meta, arena, meta_bytes, opts) catch |e| {
        diag.set("--meta is not a run record ({s}): it needs run.browser_version, run.wpt_revision, run.worklist_commit and run.processes", .{@errorName(e)});
        return error.InvalidReference;
    };
    if (meta.run.browser_version.len == 0) {
        diag.set("--meta: run.browser_version is empty", .{});
        return error.InvalidReference;
    }
    if (!isHex(meta.run.wpt_revision, 40, 40)) {
        diag.set("--meta: run.wpt_revision '{s}' is not a 40-digit WPT commit", .{meta.run.wpt_revision});
        return error.InvalidReference;
    }
    if (!isHex(meta.run.worklist_commit, 7, 40)) {
        diag.set("--meta: run.worklist_commit '{s}' is not a Crane commit", .{meta.run.worklist_commit});
        return error.InvalidReference;
    }
    if (meta.run.processes == 0) {
        diag.set("--meta: run.processes is 0", .{});
        return error.InvalidReference;
    }
    const report = std.json.parseFromSliceLeaky(Report, arena, report_bytes, opts) catch |e| {
        diag.set("--report is not a wptreport ({s})", .{@errorName(e)});
        return error.InvalidReference;
    };
    const product = report.run_info.product orelse "";
    if (!eql(product, engine)) {
        diag.set("--report's run_info.product is '{s}', not '{s}': refusing to file one engine's results as another's", .{ product, engine });
        return error.InvalidReference;
    }
    if (report.run_info.browser_version) |v| {
        if (!eql(v, meta.run.browser_version)) {
            diag.set("--report ran browser version '{s}', but --meta says '{s}'", .{ v, meta.run.browser_version });
            return error.InvalidReference;
        }
    }
    const manifest = Manifest.parse(arena, manifest_bytes) catch |e| {
        diag.set("--manifest is not a MANIFEST.json with items.testharness ({s})", .{@errorName(e)});
        return error.InvalidReference;
    };
    const worklist = try parseWorklist(arena, worklist_text);
    if (worklist.len == 0) {
        diag.set("--worklist lists no files", .{});
        return error.InvalidReference;
    }

    var cov: Coverage = .{};
    var in_worklist: std.StringHashMapUnmanaged(void) = .empty;
    for (worklist) |p| {
        const gop = try in_worklist.getOrPut(arena, p);
        if (gop.found_existing) continue;
        cov.sources += 1;
        if (manifest.urls_of.get(p)) |urls| {
            cov.sources_in_manifest += 1;
            cov.urls_expected += urls.len;
        }
    }

    // The latest result per URL: a rerun appends, and the last line wins.
    var latest: std.StringArrayHashMapUnmanaged(usize) = .empty;
    for (report.results, 0..) |r, i| {
        try latest.put(arena, std.mem.trimStart(u8, r.@"test", "/"), i);
    }
    // In URL order, so the message a tally keeps does not depend on the run's order.
    latest.sort(struct {
        keys: []const []const u8,
        pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
            return std.mem.order(u8, ctx.keys[a], ctx.keys[b]) == .lt;
        }
    }{ .keys = latest.keys() });

    var tallies: std.StringArrayHashMapUnmanaged(Tally) = .empty;
    for (latest.keys(), latest.values()) |url, i| {
        const r = report.results[i];
        const src = manifest.source_of.get(url) orelse {
            cov.urls_unknown += 1;
            continue;
        };
        if (!in_worklist.contains(src)) {
            cov.urls_outside += 1;
            continue;
        }
        if (fileStatus(r.status) == null) {
            cov.urls_skipped += 1;
            continue;
        }
        cov.urls_reported += 1;
        const gop = try tallies.getOrPut(arena, src);
        if (!gop.found_existing) gop.value_ptr.* = .{};
        gop.value_ptr.add(r.status, r.message, r.subtests);
    }
    cov.sources_reported = tallies.count();
    cov.urls_missing = cov.urls_expected - cov.urls_reported;
    for (tallies.keys(), tallies.values()) |src, *t| {
        const expected = if (manifest.urls_of.get(src)) |u| u.len else 0;
        t.missing_urls = @intCast(expected -| t.urls);
    }
    tallies.sort(struct {
        keys: []const []const u8,
        pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
            return std.mem.order(u8, ctx.keys[a], ctx.keys[b]) == .lt;
        }
    }{ .keys = tallies.keys() });

    var m = meta;
    if (report.time_start) |ms| {
        const buf = try arena.create([20]u8);
        m.run.date = model.isoUtc(buf, ms / 1000);
    }
    if (m.run.date.len == 0) {
        diag.set("neither --report's time_start nor --meta's run.date says when the run was", .{});
        return error.InvalidReference;
    }
    return .{
        .engine = engine,
        .meta = m,
        .product = product,
        .time_start = report.time_start,
        .time_end = report.time_end,
        .coverage = cov,
        .paths = tallies.keys(),
        .tallies = tallies.values(),
    };
}

// ============================================================================
// reference.json
// ============================================================================

const max_message = 1000;

fn str(w: *std.Io.Writer, s: []const u8) std.Io.Writer.Error!void {
    try std.json.Stringify.value(s, .{}, w);
}

/// `reference.json`: one header line per part, then one line per file, so a
/// later run's file diffs line by line. Keys are in a fixed order.
pub fn write(w: *std.Io.Writer, imp: Imported) std.Io.Writer.Error!void {
    try w.writeAll("{\"format\":");
    try str(w, format_id);
    try w.writeAll(",\"engine\":");
    try str(w, imp.engine);
    try w.writeAll(",\n\"run\":");
    try std.json.Stringify.value(imp.meta.run, .{}, w);
    try w.writeAll(",\n\"product\":");
    try str(w, imp.product);
    try w.print(",\"time_start\":{?d},\"time_end\":{?d}", .{ imp.time_start, imp.time_end });
    try w.writeAll(",\n\"timing\":");
    try std.json.Stringify.value(imp.meta.timing, .{}, w);
    try w.writeAll(",\n\"coverage\":");
    try std.json.Stringify.value(imp.coverage, .{}, w);
    try w.writeAll(",\n\"files\":{");
    for (imp.paths, imp.tallies, 0..) |p, t, i| {
        try w.writeAll(if (i == 0) "\n" else ",\n");
        try str(w, p);
        try w.writeAll(":{\"engine\":");
        try str(w, imp.engine);
        try w.writeAll(",\"status\":");
        try str(w, t.status);
        try w.print(",\"passed\":{d},\"failed\":{d},\"timed_out\":{d},\"notrun\":{d},\"urls\":{d},\"missing_urls\":{d},\"message\":", .{
            t.counts.passed, t.counts.failed, t.counts.timed_out, t.counts.notrun, t.urls, t.missing_urls,
        });
        if (t.message) |m| try str(w, m[0..@min(m.len, max_message)]) else try w.writeAll("null");
        try w.writeAll("}");
    }
    try w.writeAll("\n}}\n");
}

// ============================================================================
// Reading it back (the site)
// ============================================================================

pub const FileRecord = struct {
    engine: []const u8 = "",
    status: []const u8 = "ERROR",
    passed: u64 = 0,
    failed: u64 = 0,
    timed_out: u64 = 0,
    notrun: u64 = 0,
    urls: u64 = 0,
    missing_urls: u64 = 0,
    message: ?[]const u8 = null,

    pub fn counts(r: FileRecord) model.Counts {
        return .{ .passed = r.passed, .failed = r.failed, .timed_out = r.timed_out, .notrun = r.notrun };
    }
};

pub const Reference = struct {
    format: []const u8,
    engine: []const u8,
    run: RunMeta,
    product: []const u8 = "",
    time_start: ?u64 = null,
    time_end: ?u64 = null,
    timing: ?Timing = null,
    coverage: Coverage = .{},
    files: std.json.ArrayHashMap(FileRecord) = .{},

    /// "Chrome", "Firefox", "Safari": the engine as the pages name it.
    pub fn label(r: *const Reference) []const u8 {
        return engineLabel(r.engine);
    }
};

pub fn engineLabel(engine: []const u8) []const u8 {
    if (eql(engine, "chrome")) return "Chrome";
    if (eql(engine, "firefox")) return "Firefox";
    if (eql(engine, "safari")) return "Safari";
    return engine;
}

/// Parse a reference.json. One that is not this format, names Crane as its
/// engine, or holds a record of another engine is error.InvalidReference.
pub fn parse(arena: Allocator, bytes: []const u8, diag: *Diag) ImportError!Reference {
    const r = std.json.parseFromSliceLeaky(Reference, arena, bytes, .{ .ignore_unknown_fields = true }) catch |e| {
        diag.set("not a reference.json ({s})", .{@errorName(e)});
        return error.InvalidReference;
    };
    if (!eql(r.format, format_id)) {
        diag.set("format '{s}' is not {s}", .{ r.format, format_id });
        return error.InvalidReference;
    }
    if (isCrane(r.engine)) {
        diag.set("a reference run of Crane itself: Crane's results are its journals", .{});
        return error.InvalidReference;
    }
    for (r.files.map.keys(), r.files.map.values()) |p, rec| {
        if (!eql(rec.engine, r.engine)) {
            diag.set("{s}: record of engine '{s}' in a {s} reference", .{ p, rec.engine, r.engine });
            return error.InvalidReference;
        }
    }
    return r;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

const fixture_manifest =
    \\{"version":9,"url_base":"/","items":{"testharness":{
    \\ "dom":{"a.html":["h1",[null,{}]],
    \\        "b.any.js":["h2",["dom/b.any.html",{}],["dom/b.any.worker.html",{}],["dom/b.any.sharedworker.html",{}]],
    \\        "v.html":["h3",["dom/v.html?1-10",{}],["dom/v.html?11-last",{}]],
    \\        "gone.html":["h4",[null,{}]]},
    \\ "url":{"outside.html":["h5",[null,{}]]}
    \\}}}
;

const fixture_worklist =
    \\# the worklist
    \\dom/a.html
    \\dom/b.any.js
    \\dom/v.html
    \\dom/gone.html
    \\dom/unlisted.html
    \\
;

const fixture_meta =
    \\{"run":{"browser_version":"150.0.7000.1","webdriver_version":"150.0.7000.1","channel":"stable",
    \\ "wpt_revision":"56d7fe562b35dfcb063fac457f24bd0a38205481","worklist_commit":"0c228a97aa9",
    \\ "processes":5,"host":"chat.local","command":"wpt run chrome"},
    \\ "timing":{"processes":5,"reference":{"wall_s":3600.5,"user_s":9000,"sys_s":1200.25},
    \\  "crane":{"wall_s":2400,"user_s":8000,"sys_s":400,"files":13197,"runner":"main-0c228a97aa"},
    \\  "overhead":{"files":200,"reference":{"wall_s":60,"user_s":100,"sys_s":20},"crane":{"wall_s":10,"user_s":30,"sys_s":5}}}}
;

const fixture_report =
    \\{"time_start":1793790000000,"time_end":1793793600000,
    \\ "run_info":{"product":"chrome","browser_version":"150.0.7000.1","os":"mac"},
    \\ "results":[
    \\ {"test":"/dom/a.html","status":"OK","message":null,"subtests":[{"name":"x","status":"PASS","message":null},{"name":"y","status":"FAIL","message":"no"}]},
    \\ {"test":"/dom/b.any.html","status":"OK","subtests":[{"name":"x","status":"PASS"},{"name":"p","status":"PRECONDITION_FAILED"}]},
    \\ {"test":"/dom/b.any.worker.html","status":"TIMEOUT","message":"worker hung","subtests":[{"name":"x","status":"PASS"},{"name":"t","status":"TIMEOUT"},{"name":"n","status":"NOTRUN"}]},
    \\ {"test":"/dom/b.any.sharedworker.html","status":"SKIP","subtests":[]},
    \\ {"test":"/dom/v.html?1-10","status":"ERROR","message":"first","subtests":[]},
    \\ {"test":"/dom/v.html?11-last","status":"OK","subtests":[{"name":"z","status":"PASS"}]},
    \\ {"test":"/dom/a.html","status":"OK","message":null,"subtests":[{"name":"x","status":"PASS","message":null},{"name":"y","status":"PASS","message":null}]},
    \\ {"test":"/url/outside.html","status":"OK","subtests":[{"name":"o","status":"PASS"}]},
    \\ {"test":"/not/in/manifest.html","status":"OK","subtests":[]}
    \\]}
;

fn importFixture(arena: Allocator, report: []const u8, meta: []const u8, diag: *Diag) ImportError!Imported {
    return import(arena, "chrome", report, fixture_manifest, fixture_worklist, meta, diag);
}

fn tallyOf(imp: Imported, path: []const u8) ?Tally {
    for (imp.paths, imp.tallies) |p, t| if (eql(p, path)) return t;
    return null;
}

test "reference: two sizes of overhead run separate a harness's start-up from what each test costs" {
    // One size: everything is per test.
    const one = harnessSplit(200, 60, 0, null);
    try testing.expectEqual(@as(f64, 0.3), one.per_test_s);
    try testing.expectEqual(@as(f64, 0), one.startup_s);
    // 50 tests in 30 s, 200 in 60 s: 0.2 s a test, 20 s before the first.
    const two = harnessSplit(200, 60, 50, 30);
    try testing.expectApproxEqAbs(@as(f64, 0.2), two.per_test_s, 1e-9);
    try testing.expectApproxEqAbs(@as(f64, 20), two.startup_s, 1e-9);
    try testing.expectApproxEqAbs(@as(f64, 20 + 0.2 * 17663), two.of(17663), 1e-6);
    // A smaller run that took as long is noise, not a slope.
    try testing.expectEqual(one, harnessSplit(200, 60, 50, 61));
    try testing.expectEqual(HarnessSplit{ .per_test_s = 0, .startup_s = 0 }, harnessSplit(0, 60, 0, null));
}

test "reference: a run's CPU is the larger of its rusage and its sampled process tree, plus its server share" {
    // rusage only: user + system + the shared server's share.
    try testing.expectEqual(@as(f64, 7), (Measure{ .wall_s = 1, .user_s = 1, .sys_s = 2, .server_cpu_s = 4 }).cpu());
    // Chrome's renderers that no parent waited for are missing from rusage, not from the samples.
    try testing.expectEqual(@as(f64, 120), (Measure{ .wall_s = 1, .user_s = 72, .sys_s = 28, .tree_cpu_s = 120 }).cpu());
    // A sample misses up to a second of each short process: rusage wins when larger.
    try testing.expectEqual(@as(f64, 32.5 + 11.5), (Measure{ .wall_s = 1, .user_s = 25.5, .sys_s = 7, .tree_cpu_s = 30, .server_cpu_s = 11.5 }).cpu());
}

test "reference: a test URL's status is filed as Crane's runner files it" {
    try testing.expectEqualStrings("OK", fileStatus("OK").?);
    try testing.expectEqualStrings("TIMEOUT", fileStatus("TIMEOUT").?);
    try testing.expectEqualStrings("TIMEOUT", fileStatus("EXTERNAL-TIMEOUT").?);
    try testing.expectEqualStrings("CRASH", fileStatus("CRASH").?);
    try testing.expectEqualStrings("ERROR", fileStatus("ERROR").?);
    try testing.expectEqualStrings("ERROR", fileStatus("PRECONDITION_FAILED").?);
    try testing.expectEqualStrings("ERROR", fileStatus("INTERNAL-ERROR").?);
    try testing.expectEqualStrings("ERROR", fileStatus("SOMETHING-NEW").?);
    try testing.expect(fileStatus("SKIP") == null);
}

test "reference: only a record with no engine, or Crane's, is Crane's" {
    try testing.expect(isCrane(null));
    try testing.expect(isCrane("crane"));
    try testing.expect(!isCrane("chrome"));
    try testing.expect(!isCrane("firefox"));
    try testing.expect(!isCrane(""));
}

test "reference: URLs join their sources through the manifest, summed as Crane sums a file's runs" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    var diag: Diag = .{};
    const imp = try importFixture(arena_state.allocator(), fixture_report, fixture_meta, &diag);

    // The latest result of a URL wins: dom/a.html's rerun passed both.
    const a = tallyOf(imp, "dom/a.html").?;
    try testing.expectEqualStrings("OK", a.status);
    try testing.expectEqual(@as(u64, 2), a.counts.passed);
    try testing.expectEqual(@as(u64, 0), a.counts.failed);
    try testing.expectEqual(@as(u32, 1), a.urls);
    try testing.expectEqual(@as(u32, 0), a.missing_urls);

    // Two URLs reported, worst status wins with its message; the skipped
    // shared-worker URL is missing, not a failure.
    const b = tallyOf(imp, "dom/b.any.js").?;
    try testing.expectEqualStrings("TIMEOUT", b.status);
    try testing.expectEqualStrings("worker hung", b.message.?);
    try testing.expectEqual(model.Counts{ .passed = 2, .failed = 1, .timed_out = 1, .notrun = 1 }, b.counts);
    try testing.expectEqual(@as(u32, 2), b.urls);
    try testing.expectEqual(@as(u32, 1), b.missing_urls);

    // Variants are URLs of one source.
    const v = tallyOf(imp, "dom/v.html").?;
    try testing.expectEqualStrings("ERROR", v.status);
    try testing.expectEqualStrings("first", v.message.?);
    try testing.expectEqual(@as(u64, 1), v.counts.passed);
    try testing.expectEqual(@as(u32, 2), v.urls);

    // A worklist file the report lacks has no record; one outside the worklist
    // or the manifest never joins.
    try testing.expect(tallyOf(imp, "dom/gone.html") == null);
    try testing.expect(tallyOf(imp, "url/outside.html") == null);
    try testing.expectEqual(@as(usize, 3), imp.paths.len);
    try testing.expectEqualStrings("dom/a.html", imp.paths[0]);
    try testing.expectEqualStrings("dom/b.any.js", imp.paths[1]);

    try testing.expectEqual(Coverage{
        .sources = 5,
        .sources_in_manifest = 4,
        .sources_reported = 3,
        .urls_expected = 7,
        .urls_reported = 5,
        .urls_skipped = 1,
        .urls_missing = 2,
        .urls_outside = 1,
        .urls_unknown = 1,
    }, imp.coverage);
    // The run's date is the report's own start.
    try testing.expectEqualStrings("2026-11-04T11:00:00Z", imp.meta.run.date);
}

test "reference: a report of another product, a version the record contradicts, or Crane as the engine is refused" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var diag: Diag = .{};

    const firefox = try std.mem.replaceOwned(u8, arena, fixture_report, "\"product\":\"chrome\"", "\"product\":\"firefox\"");
    try testing.expectError(error.InvalidReference, importFixture(arena, firefox, fixture_meta, &diag));
    try testing.expect(std.mem.indexOf(u8, diag.message(), "firefox") != null);

    const other_version = try std.mem.replaceOwned(u8, arena, fixture_meta, "\"browser_version\":\"150.0.7000.1\"", "\"browser_version\":\"149.0.1\"");
    try testing.expectError(error.InvalidReference, importFixture(arena, fixture_report, other_version, &diag));
    try testing.expect(std.mem.indexOf(u8, diag.message(), "149.0.1") != null);

    const bad_rev = try std.mem.replaceOwned(u8, arena, fixture_meta, "56d7fe562b35dfcb063fac457f24bd0a38205481", "main");
    try testing.expectError(error.InvalidReference, importFixture(arena, fixture_report, bad_rev, &diag));

    try testing.expectError(error.InvalidReference, import(arena, "crane", fixture_report, fixture_manifest, fixture_worklist, fixture_meta, &diag));
    try testing.expectError(error.InvalidReference, importFixture(arena, "{\"results\":", fixture_meta, &diag));
}

test "reference: reference.json reads back, every record marked with its engine" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var diag: Diag = .{};
    const imp = try importFixture(arena, fixture_report, fixture_meta, &diag);
    var aw: std.Io.Writer.Allocating = .init(arena);
    try write(&aw.writer, imp);
    const bytes = aw.written();

    // One line per file, each saying whose it is.
    try testing.expectEqual(@as(usize, 3), std.mem.count(u8, bytes, "{\"engine\":\"chrome\",\"status\""));
    const r = try parse(arena, bytes, &diag);
    try testing.expectEqualStrings("chrome", r.engine);
    try testing.expectEqualStrings("Chrome", r.label());
    try testing.expectEqualStrings("150.0.7000.1", r.run.browser_version);
    try testing.expectEqualStrings("56d7fe562b35dfcb063fac457f24bd0a38205481", r.run.wpt_revision);
    try testing.expectEqual(@as(u32, 5), r.run.processes);
    try testing.expectEqual(@as(f64, 3600.5), r.timing.?.reference.wall_s);
    try testing.expectEqual(@as(u64, 200), r.timing.?.overhead.?.files);
    try testing.expectEqual(@as(u64, 13197), r.timing.?.crane.?.files);
    try testing.expectEqual(imp.coverage, r.coverage);
    try testing.expectEqual(@as(usize, 3), r.files.map.count());
    const b = r.files.map.get("dom/b.any.js").?;
    try testing.expectEqualStrings("TIMEOUT", b.status);
    try testing.expectEqual(@as(u64, 1), b.missing_urls);
    try testing.expectEqual(model.Counts{ .passed = 2, .failed = 1, .timed_out = 1, .notrun = 1 }, b.counts());

    // The same input writes the same bytes.
    var aw2: std.Io.Writer.Allocating = .init(arena);
    try write(&aw2.writer, try importFixture(arena, fixture_report, fixture_meta, &diag));
    try testing.expectEqualStrings(bytes, aw2.written());
}

test "reference: a reference.json of another format, of Crane, or with a record of another engine is invalid" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var diag: Diag = .{};
    const ok =
        \\{"format":"crane-wpt-reference/1","engine":"chrome","run":{"browser_version":"1","wpt_revision":"56d7fe562b35dfcb063fac457f24bd0a38205481","worklist_commit":"0c228a97aa9","processes":5,"date":"2026-11-04T08:20:00Z"},
        \\"files":{"dom/a.html":{"engine":"chrome","status":"OK","passed":1}}}
    ;
    _ = try parse(arena, ok, &diag);
    try testing.expectError(error.InvalidReference, parse(arena, try std.mem.replaceOwned(u8, arena, ok, "crane-wpt-reference/1", "crane-wpt-reference/0"), &diag));
    try testing.expectError(error.InvalidReference, parse(arena, try std.mem.replaceOwned(u8, arena, ok, "\"engine\":\"chrome\",\"run\"", "\"engine\":\"crane\",\"run\""), &diag));
    try testing.expectError(error.InvalidReference, parse(arena, try std.mem.replaceOwned(u8, arena, ok, "{\"engine\":\"chrome\",\"status\"", "{\"engine\":\"firefox\",\"status\""), &diag));
    try testing.expect(std.mem.indexOf(u8, diag.message(), "firefox") != null);
}
