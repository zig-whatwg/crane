//! The rules the public WPT results site is built on, std only, so that
//! `zig build test` pins them.
//!
//! * `gateOf` - how one test file's latest record reads under the 0.1 gate
//!   (tools/wpt_progress.py `gate_status`, rule 2): TIMEOUT, ERROR and CRASH
//!   block, and so does an OK run in which none of the file's subtests
//!   passed (NONE-PASSED). A file that reported no subtests at all is not
//!   NONE-PASSED - there was nothing to fail.
//! * `Totals` - the counts a conformance box shows. Subtests are REPORTED
//!   counts (pass + fail + timeout + notrun as the journal line sums them),
//!   never a model or an estimate, and there is deliberately no ratio here:
//!   the site shows no headline pass percentage.
//! * `sourceForTestUrl` - which worklist source a wptreport test URL belongs
//!   to (`/x/y.any.worker.html?v` -> `x/y.any.js`).
//! * `labelCommit` - the Crane commit a results label names
//!   (`sweep-5c8dd64da` -> `5c8dd64da`).
//! * `isoUtc` - a journal mtime as an ISO 8601 UTC timestamp.

const std = @import("std");

// ============================================================================
// The gate
// ============================================================================

/// One file's standing. The first four are the runner's OK; `timeout`,
/// `err` and `crash` are its other statuses; `unrun` is a worklist file with
/// no record at all.
pub const Gate = enum {
    /// OK, and every subtest it reported passed.
    clean,
    /// OK, some subtests pass and some do not.
    partial,
    /// OK, and it reported no subtests at all.
    empty,
    /// OK, but none of its subtests passed: blocks the gate.
    none_passed,
    timeout,
    err,
    crash,
    unrun,

    pub fn blocking(g: Gate) bool {
        return switch (g) {
            .none_passed, .timeout, .err, .crash => true,
            else => false,
        };
    }

    /// The word the site prints and the JSON carries.
    pub fn word(g: Gate) []const u8 {
        return switch (g) {
            .clean => "clean",
            .partial => "partial",
            .empty => "empty",
            .none_passed => "none-passed",
            .timeout => "timeout",
            .err => "error",
            .crash => "crash",
            .unrun => "unrun",
        };
    }
};

/// Subtest counts as the journal reports them for one file (every run of
/// the file summed: each global and each declared variant is one WPT test).
pub const Counts = struct {
    passed: u64 = 0,
    failed: u64 = 0,
    timed_out: u64 = 0,
    notrun: u64 = 0,

    pub fn reported(c: Counts) u64 {
        return c.passed + c.failed + c.timed_out + c.notrun;
    }
};

/// The gate status of a record with runner status `status` (null: no
/// record) and subtest counts `c`.
///
/// Where this differs from tools/wpt_progress.py: that tool files an OK run
/// whose only non-passing subtests are NOTRUN as clean (its clean test looks
/// at failed and timed_out only). A NOTRUN subtest did not pass, so here such
/// a file is `partial` - "Clean" on the site means every reported subtest passed.
/// The blocking set is identical.
pub fn gateOf(status: ?[]const u8, c: Counts) Gate {
    const st = status orelse return .unrun;
    if (std.mem.eql(u8, st, "OK")) {
        if (c.reported() == 0) return .empty;
        if (c.passed == 0) return .none_passed;
        if (c.passed == c.reported()) return .clean;
        return .partial;
    }
    if (std.mem.eql(u8, st, "TIMEOUT")) return .timeout;
    if (std.mem.eql(u8, st, "CRASH")) return .crash;
    // ERROR, EXTERNAL-TIMEOUT, PRECONDITION_FAILED and anything unknown:
    // a status we do not recognise is not a pass (wpt_progress.py files
    // these under error in its history too).
    return .err;
}

// ============================================================================
// Totals
// ============================================================================

pub const Totals = struct {
    files: u64 = 0,
    clean: u64 = 0,
    partial: u64 = 0,
    empty: u64 = 0,
    none_passed: u64 = 0,
    timeout: u64 = 0,
    err: u64 = 0,
    crash: u64 = 0,
    unrun: u64 = 0,
    sub_pass: u64 = 0,
    sub_fail: u64 = 0,
    sub_timeout: u64 = 0,
    sub_notrun: u64 = 0,

    pub fn add(t: *Totals, g: Gate, c: Counts) void {
        t.files += 1;
        switch (g) {
            .clean => t.clean += 1,
            .partial => t.partial += 1,
            .empty => t.empty += 1,
            .none_passed => t.none_passed += 1,
            .timeout => t.timeout += 1,
            .err => t.err += 1,
            .crash => t.crash += 1,
            .unrun => t.unrun += 1,
        }
        t.sub_pass += c.passed;
        t.sub_fail += c.failed;
        t.sub_timeout += c.timed_out;
        t.sub_notrun += c.notrun;
    }

    pub fn merge(t: *Totals, o: Totals) void {
        inline for (@typeInfo(Totals).@"struct".fields) |f| @field(t, f.name) += @field(o, f.name);
    }

    pub fn blocking(t: Totals) u64 {
        return t.none_passed + t.timeout + t.err + t.crash;
    }

    pub fn subReported(t: Totals) u64 {
        return t.sub_pass + t.sub_fail + t.sub_timeout + t.sub_notrun;
    }

    /// Keys in sorted order, so an unchanged directory writes unchanged bytes.
    pub fn writeJson(t: Totals, w: *std.Io.Writer) std.Io.Writer.Error!void {
        try w.print(
            "{{\"blocking\":{d},\"clean\":{d},\"crash\":{d},\"empty\":{d},\"error\":{d},\"files\":{d}," ++
                "\"none_passed\":{d},\"partial\":{d},\"sub_fail\":{d},\"sub_notrun\":{d},\"sub_pass\":{d}," ++
                "\"sub_reported\":{d},\"sub_timeout\":{d},\"timeout\":{d},\"unrun\":{d}}}",
            .{
                t.blocking(),  t.clean,   t.crash,    t.empty,      t.err,      t.files,
                t.none_passed, t.partial, t.sub_fail, t.sub_notrun, t.sub_pass, t.subReported(),
                t.sub_timeout, t.timeout, t.unrun,
            },
        );
    }
};

// ============================================================================
// Test URLs and sources
// ============================================================================

/// The source path a wptreport test URL was generated from, when that source
/// is in `known` (keys are worklist paths without a leading slash). Returns
/// the key as stored in `known`, or null.
///
/// WPT names a test by its URL: a plain document is its own path; a
/// `.any.js` source becomes `.any.html`, `.any.worker.html` and the other
/// `.any.<global>.html` forms; `.window.js` becomes `.window.html` and
/// `.worker.js` `.worker.html`; a variant adds `?query`. A real document
/// named `x.worker.html` stays itself, which is why `known` is consulted
/// before any rewrite.
pub fn sourceForTestUrl(known: *const std.StringHashMapUnmanaged(void), url: []const u8) ?[]const u8 {
    var p = url;
    if (std.mem.startsWith(u8, p, "/")) p = p[1..];
    if (std.mem.indexOfAny(u8, p, "?#")) |q| p = p[0..q];
    if (known.getKey(p)) |k| return k;

    var buf: [1024]u8 = undefined;
    const slash = if (std.mem.lastIndexOfScalar(u8, p, '/')) |s| s + 1 else 0;
    const base = p[slash..];
    if (std.mem.indexOf(u8, base, ".any.")) |i| {
        if (std.mem.endsWith(u8, base, ".html")) {
            const cand = std.fmt.bufPrint(&buf, "{s}.any.js", .{p[0 .. slash + i]}) catch return null;
            if (known.getKey(cand)) |k| return k;
        }
        return null;
    }
    const rewrites = [_][2][]const u8{
        .{ ".window.html", ".window.js" },
        .{ ".worker.html", ".worker.js" },
        .{ ".extension.html", ".extension.js" },
    };
    for (rewrites) |r| {
        if (std.mem.endsWith(u8, p, r[0])) {
            const cand = std.fmt.bufPrint(&buf, "{s}{s}", .{ p[0 .. p.len - r[0].len], r[1] }) catch return null;
            if (known.getKey(cand)) |k| return k;
        }
    }
    return null;
}

/// The Crane commit a results label names, by the repository's convention
/// that a run's directory is `<purpose>-<short sha>` (wpt-results/ab-<sha>,
/// sweep-<sha>, testdriver-<sha>). Null when the label ends in anything but
/// 7 to 40 lowercase hex digits.
pub fn labelCommit(label: []const u8) ?[]const u8 {
    const dash = std.mem.lastIndexOfScalar(u8, label, '-') orelse return null;
    const tail = label[dash + 1 ..];
    if (tail.len < 7 or tail.len > 40) return null;
    for (tail) |c| if (!std.ascii.isDigit(c) and !(c >= 'a' and c <= 'f')) return null;
    return tail;
}

/// `secs` (Unix time) as `YYYY-MM-DDTHH:MM:SSZ`.
pub fn isoUtc(buf: *[20]u8, secs: u64) []const u8 {
    const es: std.time.epoch.EpochSeconds = .{ .secs = secs };
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();
    const ds = es.getDaySeconds();
    return std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z", .{
        yd.year,              md.month.numeric(),      @as(u32, md.day_index) + 1,
        ds.getHoursIntoDay(), ds.getMinutesIntoHour(), ds.getSecondsIntoMinute(),
    }) catch unreachable;
}

// ============================================================================
// Subtest detail
// ============================================================================

/// Above this many subtests in one file, its detail shard keeps every
/// subtest that did not pass, in full, and only a count of the passing ones:
/// the encoding/ codepoint sweeps report up to 23,097 each, nearly all PASS.
pub const detail_limit: usize = 500;

/// Whether a file with `total` subtests across its runs keeps its passing
/// ones in its detail shard.
pub fn keepsPassing(total: usize) bool {
    return total <= detail_limit;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "gate: an OK run with nothing passing is NONE-PASSED, and it blocks" {
    const g = gateOf("OK", .{ .failed = 3 });
    try testing.expectEqual(Gate.none_passed, g);
    try testing.expect(g.blocking());
    try testing.expectEqualStrings("none-passed", g.word());
    // Timed-out or not-run subtests alone are still nothing passing.
    try testing.expectEqual(Gate.none_passed, gateOf("OK", .{ .timed_out = 1, .notrun = 2 }));
}

test "gate: an OK run with no subtests at all is empty, not NONE-PASSED" {
    const g = gateOf("OK", .{});
    try testing.expectEqual(Gate.empty, g);
    try testing.expect(!g.blocking());
}

test "gate: clean means every reported subtest passed, NOTRUN included" {
    try testing.expectEqual(Gate.clean, gateOf("OK", .{ .passed = 5 }));
    try testing.expectEqual(Gate.partial, gateOf("OK", .{ .passed = 5, .failed = 1 }));
    try testing.expectEqual(Gate.partial, gateOf("OK", .{ .passed = 5, .timed_out = 1 }));
    // wpt_progress.py would call this clean; a NOTRUN subtest did not pass.
    try testing.expectEqual(Gate.partial, gateOf("OK", .{ .passed = 5, .notrun = 1 }));
}

test "gate: runner statuses, the unknown default, and no record" {
    try testing.expectEqual(Gate.timeout, gateOf("TIMEOUT", .{ .passed = 4 }));
    try testing.expectEqual(Gate.crash, gateOf("CRASH", .{}));
    try testing.expectEqual(Gate.err, gateOf("ERROR", .{}));
    try testing.expectEqual(Gate.err, gateOf("EXTERNAL-TIMEOUT", .{}));
    try testing.expectEqual(Gate.err, gateOf("PRECONDITION_FAILED", .{}));
    // The default for a status nobody taught this code is the safe one.
    try testing.expectEqual(Gate.err, gateOf("SOMETHING-NEW", .{ .passed = 9 }));
    try testing.expect(gateOf("SOMETHING-NEW", .{}).blocking());
    try testing.expectEqual(Gate.unrun, gateOf(null, .{}));
    try testing.expect(!Gate.unrun.blocking());
}

test "totals: blocking is the four blocking kinds, subtests are reported counts" {
    var t: Totals = .{};
    t.add(gateOf("OK", .{ .passed = 2 }), .{ .passed = 2 });
    t.add(gateOf("OK", .{ .passed = 1, .failed = 1 }), .{ .passed = 1, .failed = 1 });
    t.add(gateOf("OK", .{ .failed = 4 }), .{ .failed = 4 });
    t.add(gateOf("TIMEOUT", .{ .passed = 3, .timed_out = 1 }), .{ .passed = 3, .timed_out = 1 });
    t.add(gateOf("CRASH", .{}), .{});
    t.add(gateOf("ERROR", .{}), .{});
    t.add(gateOf(null, .{}), .{});
    try testing.expectEqual(@as(u64, 7), t.files);
    try testing.expectEqual(@as(u64, 4), t.blocking());
    try testing.expectEqual(@as(u64, 1), t.clean);
    try testing.expectEqual(@as(u64, 1), t.partial);
    try testing.expectEqual(@as(u64, 1), t.unrun);
    // A timed-out file's passing subtests still count as passed subtests.
    try testing.expectEqual(@as(u64, 6), t.sub_pass);
    try testing.expectEqual(@as(u64, 12), t.subReported());

    var sum: Totals = .{};
    sum.merge(t);
    sum.merge(t);
    try testing.expectEqual(@as(u64, 14), sum.files);
    try testing.expectEqual(@as(u64, 8), sum.blocking());
}

test "totals: JSON keys are sorted and every count is present" {
    var t: Totals = .{};
    t.add(.timeout, .{ .passed = 1, .timed_out = 2 });
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    try t.writeJson(&aw.writer);
    const json = aw.written();
    try testing.expectEqualStrings(
        "{\"blocking\":1,\"clean\":0,\"crash\":0,\"empty\":0,\"error\":0,\"files\":1,\"none_passed\":0," ++
            "\"partial\":0,\"sub_fail\":0,\"sub_notrun\":0,\"sub_pass\":1,\"sub_reported\":3,\"sub_timeout\":2," ++
            "\"timeout\":1,\"unrun\":0}",
        json,
    );
    // Sorted keys: every key is greater than the one before it.
    const parsed = try std.json.parseFromSlice(std.json.Value, testing.allocator, json, .{});
    defer parsed.deinit();
    const keys = parsed.value.object.keys();
    for (keys[1..], keys[0 .. keys.len - 1]) |k, prev| try testing.expect(std.mem.order(u8, prev, k) == .lt);
    // And no ratio anywhere: the site shows no headline percentage.
    try testing.expect(std.mem.indexOf(u8, json, "pct") == null and std.mem.indexOf(u8, json, "rate") == null);
}

test "test URLs map back to their worklist source" {
    var known: std.StringHashMapUnmanaged(void) = .empty;
    defer known.deinit(testing.allocator);
    for ([_][]const u8{
        "console/console-is-a-namespace.any.js",
        "dom/nodes/Node-cloneNode.html",
        "html/x/real.worker.html",
        "fetch/api/basic.window.js",
        "workers/thing.worker.js",
        "encoding/legacy-mb-korean/euc-kr/euckr-encode-href-errors-han.html",
    }) |k| try known.put(testing.allocator, k, {});

    const cases = [_][2][]const u8{
        .{ "/console/console-is-a-namespace.any.html", "console/console-is-a-namespace.any.js" },
        .{ "/console/console-is-a-namespace.any.worker.html", "console/console-is-a-namespace.any.js" },
        .{ "/console/console-is-a-namespace.any.sharedworker-module.html", "console/console-is-a-namespace.any.js" },
        .{ "/dom/nodes/Node-cloneNode.html", "dom/nodes/Node-cloneNode.html" },
        .{ "/fetch/api/basic.window.html", "fetch/api/basic.window.js" },
        .{ "/workers/thing.worker.html", "workers/thing.worker.js" },
        // A document that really is named .worker.html is not rewritten.
        .{ "/html/x/real.worker.html", "html/x/real.worker.html" },
        // A variant's query is not part of the source.
        .{ "/encoding/legacy-mb-korean/euc-kr/euckr-encode-href-errors-han.html?1001-2000", "encoding/legacy-mb-korean/euc-kr/euckr-encode-href-errors-han.html" },
    };
    for (cases) |c| {
        const got = sourceForTestUrl(&known, c[0]) orelse return error.TestExpectedSource;
        try testing.expectEqualStrings(c[1], got);
    }
    try testing.expect(sourceForTestUrl(&known, "/not/in/worklist.html") == null);
    try testing.expect(sourceForTestUrl(&known, "/crane/our-own.any.html") == null);
}

test "a results label names its Crane commit by its hex suffix" {
    try testing.expectEqualStrings("5c8dd64da", labelCommit("sweep-5c8dd64da").?);
    try testing.expectEqualStrings("97899d589", labelCommit("testdriver-97899d589").?);
    try testing.expectEqualStrings("1abc6828a", labelCommit("networking-1abc6828a").?);
    try testing.expect(labelCommit("sweep-1c0e1f867-partial") == null);
    try testing.expect(labelCommit("ab-scripting") == null);
    try testing.expect(labelCommit("archive") == null);
    try testing.expect(labelCommit("x-ABCDEF0123") == null);
    try testing.expect(labelCommit("x-abc12") == null);
}

test "a journal mtime renders as ISO 8601 UTC" {
    var buf: [20]u8 = undefined;
    try testing.expectEqualStrings("1970-01-01T00:00:00Z", isoUtc(&buf, 0));
    // The testdriver sweep's journal, 1790781505 = 2026-09-30 15:18:25 UTC.
    try testing.expectEqualStrings("2026-09-30T15:18:25Z", isoUtc(&buf, 1790781505));
}

test "detail shards keep passing subtests only up to the limit" {
    try testing.expect(keepsPassing(0));
    try testing.expect(keepsPassing(detail_limit));
    try testing.expect(!keepsPassing(detail_limit + 1));
    try testing.expect(!keepsPassing(23097));
}
