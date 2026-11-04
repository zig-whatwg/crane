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
    _ = engine;
    return true;
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
    _ = status;
    return "OK";
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
        _ = t;
        _ = status;
        _ = message;
        _ = subtests;
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

pub const Measure = struct {
    wall_s: f64,
    user_s: f64,
    sys_s: f64,
};

pub const CraneMeasure = struct {
    wall_s: f64,
    user_s: f64,
    sys_s: f64,
    /// Worklist files Crane's runner ran.
    files: u64 = 0,
    /// The frozen runner that ran them (its directory or commit).
    runner: []const u8 = "",
};

pub const Overhead = struct {
    /// Trivial test files (tests/wpt/crane/harness-overhead/), run by both.
    files: u64,
    reference: Measure,
    crane: Measure,
};

/// Wall and CPU time of the whole run on one host, with the same runner
/// count for both engines, and the harness overhead measured beside them.
pub const Timing = struct {
    processes: u32,
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
    _ = arena;
    _ = engine;
    _ = report_bytes;
    _ = manifest_bytes;
    _ = worklist_text;
    _ = meta_bytes;
    diag.set("not implemented", .{});
    return error.InvalidReference;
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
    _ = w;
    _ = imp;
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
    _ = arena;
    _ = bytes;
    diag.set("not implemented", .{});
    return error.InvalidReference;
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
