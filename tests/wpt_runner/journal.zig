//! Crash-tolerant run journal for the WPT runner.
//!
//! The runner executes every test in one process against one V8 isolate. A
//! segfault in any single test therefore ends the entire run, and a run that
//! cannot finish cannot produce a baseline. The journal is the piece that makes
//! a full run possible: each completed test is appended to a JSONL file and
//! written straight through to the file descriptor, so after an abnormal exit
//! the records on disk say exactly how far the process got.
//!
//! A supervisor reads `nextIndex()` from the journal, records a `crash` entry
//! for the test that did not report, and restarts the child one past it.
//!
//! Records are written unbuffered, one `writeAll` per line. Buffering would
//! lose the last few records precisely when they matter most - identifying the
//! test that crashed depends on the record *before* it having reached the disk.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Outcome of running one test file in one global context.
///
/// The first three mirror WPT's harness statuses; `crash` is ours, written by
/// the supervisor for a test that never reported one of its own.
pub const Status = enum {
    ok,
    @"error",
    timeout,
    crash,

    pub fn toString(self: Status) []const u8 {
        return switch (self) {
            .ok => "OK",
            .@"error" => "ERROR",
            .timeout => "TIMEOUT",
            .crash => "CRASH",
        };
    }

    pub fn fromString(s: []const u8) ?Status {
        inline for (@typeInfo(Status).@"enum".fields) |field| {
            const value: Status = @enumFromInt(field.value);
            if (std.mem.eql(u8, s, value.toString())) return value;
        }
        return null;
    }

    /// How bad an outcome is, for "worst wins" aggregation over the several
    /// global contexts one test file runs in.
    ///
    /// A timeout ranks below an error: the test at least got as far as running.
    /// Declared explicitly rather than leaning on the enum's integer values,
    /// which exist to name the wire format, not to rank it.
    pub fn severity(self: Status) u8 {
        return switch (self) {
            .ok => 0,
            .timeout => 1,
            .@"error" => 2,
            .crash => 3,
        };
    }
};

/// One journal line: what happened to one test.
pub const Record = struct {
    /// Position in the worklist. This is what makes resumption possible, so it
    /// must be the index into the worklist file, not into whatever subset of it
    /// a given child happened to run.
    index: usize,
    path: []const u8,
    context: []const u8 = "",
    status: Status,
    passed: usize = 0,
    failed: usize = 0,
    timed_out: usize = 0,
    notrun: usize = 0,
    /// Sum of the durations the harness reported for this file's subtests.
    ///
    /// This is *not* how long the file took. A subtest that never finished is
    /// never charged, and nothing outside a subtest - navigation, context
    /// construction, teardown - is charged at all. Use `wall_ms` for cost.
    duration_ms: u64 = 0,
    /// Wall-clock time the runner spent on this file, measured around every
    /// context of it. `wall_ms - duration_ms` is the per-file overhead.
    ///
    /// Zero in journals written before this field existed.
    wall_ms: u64 = 0,
    message: ?[]const u8 = null,
};

/// Escape a string for JSON output.
///
/// Deliberately a copy of `result_reporter.writeJsonString` rather than an
/// import: this module stays std-only so it can run under `zig build test`
/// without V8 or libuv, and the reporter does not.
fn writeJsonString(w: *std.Io.Writer, str: []const u8) !void {
    try w.writeByte('"');
    for (str) |c| {
        switch (c) {
            '"' => try w.writeAll("\\\""),
            '\\' => try w.writeAll("\\\\"),
            '\n' => try w.writeAll("\\n"),
            '\r' => try w.writeAll("\\r"),
            '\t' => try w.writeAll("\\t"),
            // Other control characters (0x00-0x08, 0x0B, 0x0C, 0x0E-0x1F)
            0x00...0x08, 0x0B, 0x0C, 0x0E...0x1F => {
                try w.print("\\u{x:0>4}", .{c});
            },
            else => try w.writeByte(c),
        }
    }
    try w.writeByte('"');
}

/// Serialize one record as a single JSON line, newline included.
pub fn writeRecord(w: *std.Io.Writer, rec: Record) !void {
    try w.print("{{\"index\":{d},\"path\":", .{rec.index});
    try writeJsonString(w, rec.path);
    try w.writeAll(",\"context\":");
    try writeJsonString(w, rec.context);
    try w.writeAll(",\"status\":");
    try writeJsonString(w, rec.status.toString());
    try w.print(
        ",\"passed\":{d},\"failed\":{d},\"timed_out\":{d},\"notrun\":{d}" ++
            ",\"duration_ms\":{d},\"wall_ms\":{d}",
        .{ rec.passed, rec.failed, rec.timed_out, rec.notrun, rec.duration_ms, rec.wall_ms },
    );
    if (rec.message) |msg| {
        try w.writeAll(",\"message\":");
        try writeJsonString(w, msg);
    }
    try w.writeAll("}\n");
}

/// Append-only writer over a journal file.
pub const Journal = struct {
    allocator: Allocator,
    file: std.fs.File,
    line: std.Io.Writer.Allocating,

    /// Start a fresh journal, discarding any previous run at this path.
    pub fn create(allocator: Allocator, path: []const u8) !Journal {
        const file = try std.fs.cwd().createFile(path, .{ .truncate = true });
        return .{
            .allocator = allocator,
            .file = file,
            .line = .init(allocator),
        };
    }

    /// Continue an existing journal, or start one if it is absent.
    pub fn append(allocator: Allocator, path: []const u8) !Journal {
        const file = std.fs.cwd().openFile(path, .{ .mode = .write_only }) catch |err| switch (err) {
            error.FileNotFound => return create(allocator, path),
            else => return err,
        };
        try file.seekFromEnd(0);
        return .{
            .allocator = allocator,
            .file = file,
            .line = .init(allocator),
        };
    }

    pub fn deinit(self: *Journal) void {
        self.line.deinit();
        self.file.close();
    }

    /// Append one record and get it onto the file descriptor before returning.
    ///
    /// The line is formatted in memory first so it reaches the file in a single
    /// `writeAll`: a record that is half-written when the process dies is a
    /// record the reader has to throw away, and throwing away the *last* record
    /// is what loses the identity of the crashing test.
    pub fn record(self: *Journal, rec: Record) !void {
        self.line.clearRetainingCapacity();
        try writeRecord(&self.line.writer, rec);
        try self.file.writeAll(self.line.written());
    }
};

/// Aggregate counts over a journal, for the end-of-run line.
pub const Summary = struct {
    ok: usize = 0,
    errored: usize = 0,
    timed_out: usize = 0,
    crashed: usize = 0,
    subtests_passed: usize = 0,
    subtests_failed: usize = 0,
    subtests_timed_out: usize = 0,
    subtests_notrun: usize = 0,
};

/// A parsed journal.
pub const Log = struct {
    allocator: Allocator,
    records: []Record,

    pub fn deinit(self: *Log) void {
        for (self.records) |rec| {
            self.allocator.free(rec.path);
            self.allocator.free(rec.context);
            if (rec.message) |m| self.allocator.free(m);
        }
        self.allocator.free(self.records);
    }

    /// Worklist index to resume from.
    ///
    /// One past the *highest* index present, not one past the last line: a
    /// supervisor appends its crash record after the child has already exited,
    /// and resuming below an index that already reported would run that test
    /// twice.
    pub fn nextIndex(self: *const Log) usize {
        var highest: ?usize = null;
        for (self.records) |rec| {
            if (highest == null or rec.index > highest.?) highest = rec.index;
        }
        return if (highest) |h| h + 1 else 0;
    }

    pub fn summarize(self: *const Log) Summary {
        var s: Summary = .{};
        for (self.records) |rec| {
            switch (rec.status) {
                .ok => s.ok += 1,
                .@"error" => s.errored += 1,
                .timeout => s.timed_out += 1,
                .crash => s.crashed += 1,
            }
            s.subtests_passed += rec.passed;
            s.subtests_failed += rec.failed;
            s.subtests_timed_out += rec.timed_out;
            s.subtests_notrun += rec.notrun;
        }
        return s;
    }
};

fn jsonUint(obj: std.json.ObjectMap, key: []const u8) usize {
    const v = obj.get(key) orelse return 0;
    return switch (v) {
        .integer => |i| if (i < 0) 0 else @intCast(i),
        else => 0,
    };
}

fn jsonString(allocator: Allocator, obj: std.json.ObjectMap, key: []const u8) !?[]const u8 {
    const v = obj.get(key) orelse return null;
    return switch (v) {
        .string => |s| try allocator.dupe(u8, s),
        else => null,
    };
}

/// Parse a journal's bytes.
///
/// Unparseable lines are skipped rather than fatal. A journal is read after
/// something went wrong, so its final line is routinely a partial write; a
/// parser that refused to read such a file would be useless exactly when it is
/// needed.
pub fn parseLines(allocator: Allocator, bytes: []const u8) !Log {
    var records: std.ArrayListUnmanaged(Record) = .empty;
    errdefer {
        for (records.items) |rec| {
            allocator.free(rec.path);
            allocator.free(rec.context);
            if (rec.message) |m| allocator.free(m);
        }
        records.deinit(allocator);
    }

    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0) continue;

        var parsed = std.json.parseFromSlice(std.json.Value, allocator, line, .{}) catch continue;
        defer parsed.deinit();

        const obj = switch (parsed.value) {
            .object => |o| o,
            else => continue,
        };

        const status_str = switch (obj.get("status") orelse continue) {
            .string => |s| s,
            else => continue,
        };
        const status = Status.fromString(status_str) orelse continue;

        const path = (try jsonString(allocator, obj, "path")) orelse continue;
        errdefer allocator.free(path);
        const context = (try jsonString(allocator, obj, "context")) orelse
            try allocator.dupe(u8, "");
        errdefer allocator.free(context);
        const message = try jsonString(allocator, obj, "message");
        errdefer if (message) |m| allocator.free(m);

        try records.append(allocator, .{
            .index = jsonUint(obj, "index"),
            .path = path,
            .context = context,
            .status = status,
            .passed = jsonUint(obj, "passed"),
            .failed = jsonUint(obj, "failed"),
            .timed_out = jsonUint(obj, "timed_out"),
            .notrun = jsonUint(obj, "notrun"),
            .duration_ms = jsonUint(obj, "duration_ms"),
            .wall_ms = jsonUint(obj, "wall_ms"),
            .message = message,
        });
    }

    return .{
        .allocator = allocator,
        .records = try records.toOwnedSlice(allocator),
    };
}

/// Read a journal from disk. An absent file is an empty journal, not an error -
/// that is the state of the very first attempt at a run.
pub fn read(allocator: Allocator, path: []const u8) !Log {
    const bytes = std.fs.cwd().readFileAlloc(allocator, path, 512 * 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => return .{ .allocator = allocator, .records = &.{} },
        else => return err,
    };
    defer allocator.free(bytes);
    return parseLines(allocator, bytes);
}

// ============================================================================
// Tests
// ============================================================================

fn expectRoundTrip(rec: Record) !void {
    const allocator = std.testing.allocator;

    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();
    try writeRecord(&out.writer, rec);

    var log = try parseLines(allocator, out.written());
    defer log.deinit();

    try std.testing.expectEqual(@as(usize, 1), log.records.len);
    const got = log.records[0];
    try std.testing.expectEqual(rec.index, got.index);
    try std.testing.expectEqualStrings(rec.path, got.path);
    try std.testing.expectEqualStrings(rec.context, got.context);
    try std.testing.expectEqual(rec.status, got.status);
    try std.testing.expectEqual(rec.passed, got.passed);
    try std.testing.expectEqual(rec.failed, got.failed);
    try std.testing.expectEqual(rec.timed_out, got.timed_out);
    try std.testing.expectEqual(rec.notrun, got.notrun);
    try std.testing.expectEqual(rec.duration_ms, got.duration_ms);
    try std.testing.expectEqual(rec.wall_ms, got.wall_ms);
    if (rec.message) |want| {
        try std.testing.expectEqualStrings(want, got.message.?);
    } else {
        try std.testing.expect(got.message == null);
    }
}

test "a record survives a write/parse round trip" {
    try expectRoundTrip(.{
        .index = 7,
        .path = "dom/nodes/Node-appendChild.html",
        .context = "window",
        .status = .ok,
        .passed = 41,
        .failed = 2,
        .timed_out = 1,
        .notrun = 3,
        .duration_ms = 1234,
        .wall_ms = 5678,
        .message = null,
    });
}

test "wall time is recorded even when no subtest reported a duration" {
    // `duration_ms` is a sum over harness-reported subtest times, so it is 0 on
    // every path where the harness never finished a test: load failures, parse
    // failures, and errors raised before the first subtest completed. Those are
    // precisely the files worth measuring, and reading `duration_ms` as "time
    // spent on this file" silently scores them as free.
    //
    // `wall_ms` is measured by the runner around the whole file, so it is
    // non-zero whenever real time passed. The gap between the two is the
    // per-file overhead - navigation, context construction, teardown - that no
    // subtest is ever charged for.
    try expectRoundTrip(.{
        .index = 12,
        .path = "encoding/legacy-mb-korean/euckr-encode-href-errors-han.html",
        .status = .@"error",
        .notrun = 11_183,
        .duration_ms = 0,
        .wall_ms = 19_710,
        .message = "harness did not start",
    });
}

test "an older journal without wall_ms still parses" {
    // Journals are read back by `--resume` and by the scoreboard, both of which
    // must keep working against files written before this field existed.
    const allocator = std.testing.allocator;

    const line =
        \\{"index":0,"path":"a.html","context":"","status":"OK","passed":1,"failed":0,"timed_out":0,"notrun":0,"duration_ms":5}
    ++ "\n";

    var log = try parseLines(allocator, line);
    defer log.deinit();

    try std.testing.expectEqual(@as(usize, 1), log.records.len);
    try std.testing.expectEqual(@as(u64, 5), log.records[0].duration_ms);
    try std.testing.expectEqual(@as(u64, 0), log.records[0].wall_ms);
}

test "record strings are JSON-escaped" {
    // A harness message can contain anything a test chose to throw, including
    // quotes, backslashes and newlines. One record must stay on one line.
    try expectRoundTrip(.{
        .index = 0,
        .path = "html/dom/\"weird\"\\name.html",
        .context = "dedicatedworker",
        .status = .@"error",
        .message = "assert_equals: expected \"a\\nb\"\n  at foo\t(bar)\x01",
    });
}

test "every status round-trips through its wire name" {
    for ([_]Status{ .ok, .@"error", .timeout, .crash }) |status| {
        try std.testing.expectEqual(status, Status.fromString(status.toString()).?);
    }
    try std.testing.expect(Status.fromString("NOPE") == null);
}

test "severity ranks a crash worst and a pass best" {
    try std.testing.expect(Status.ok.severity() < Status.timeout.severity());
    try std.testing.expect(Status.timeout.severity() < Status.@"error".severity());
    try std.testing.expect(Status.@"error".severity() < Status.crash.severity());
}

test "one record is written per line" {
    const allocator = std.testing.allocator;

    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();

    try writeRecord(&out.writer, .{ .index = 0, .path = "a.html", .status = .ok });
    try writeRecord(&out.writer, .{ .index = 1, .path = "b.html", .status = .@"error" });

    const written = out.written();
    try std.testing.expectEqual(@as(usize, 2), std.mem.count(u8, written, "\n"));
    try std.testing.expect(std.mem.endsWith(u8, written, "\n"));
}

test "parse skips a line truncated by a crash" {
    const allocator = std.testing.allocator;

    // The process died partway through writing the third record. The first two
    // are still authoritative.
    const bytes =
        \\{"index":0,"path":"a.html","context":"","status":"OK","passed":1,"failed":0,"timed_out":0,"notrun":0,"duration_ms":5}
        \\{"index":1,"path":"b.html","context":"","status":"OK","passed":2,"failed":0,"timed_out":0,"notrun":0,"duration_ms":6}
        \\{"index":2,"path":"c.htm
    ;

    var log = try parseLines(allocator, bytes);
    defer log.deinit();

    try std.testing.expectEqual(@as(usize, 2), log.records.len);
    try std.testing.expectEqualStrings("b.html", log.records[1].path);
}

test "parse ignores blank lines and unrecognised statuses" {
    const allocator = std.testing.allocator;

    const bytes =
        \\{"index":0,"path":"a.html","status":"OK"}
        \\
        \\{"index":1,"path":"b.html","status":"WAT"}
        \\{"index":2,"path":"c.html","status":"CRASH"}
        \\
    ;

    var log = try parseLines(allocator, bytes);
    defer log.deinit();

    try std.testing.expectEqual(@as(usize, 2), log.records.len);
    try std.testing.expectEqualStrings("c.html", log.records[1].path);
    try std.testing.expectEqual(Status.crash, log.records[1].status);
}

test "nextIndex is one past the highest index on disk" {
    const allocator = std.testing.allocator;

    const bytes =
        \\{"index":0,"path":"a.html","status":"OK"}
        \\{"index":5,"path":"f.html","status":"CRASH"}
        \\{"index":3,"path":"d.html","status":"OK"}
        \\
    ;

    var log = try parseLines(allocator, bytes);
    defer log.deinit();

    // Highest, not last: a resumed child may append out of order relative to a
    // supervisor's crash record, and resuming below a completed test would run
    // it twice.
    try std.testing.expectEqual(@as(usize, 6), log.nextIndex());
}

test "nextIndex is zero for an empty journal" {
    const allocator = std.testing.allocator;

    var log = try parseLines(allocator, "");
    defer log.deinit();

    try std.testing.expectEqual(@as(usize, 0), log.records.len);
    try std.testing.expectEqual(@as(usize, 0), log.nextIndex());
}

test "reading an absent journal yields an empty log" {
    const allocator = std.testing.allocator;

    var log = try read(allocator, "tests/wpt_runner/does-not-exist.jsonl");
    defer log.deinit();

    try std.testing.expectEqual(@as(usize, 0), log.records.len);
    try std.testing.expectEqual(@as(usize, 0), log.nextIndex());
}

test "a reopened journal appends rather than truncating" {
    const allocator = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);
    const path = try std.fs.path.join(allocator, &.{ dir_path, "run.jsonl" });
    defer allocator.free(path);

    {
        var journal = try Journal.create(allocator, path);
        defer journal.deinit();
        try journal.record(.{ .index = 0, .path = "a.html", .status = .ok });
    }
    {
        // This is what a resumed child does: reopen, keep what is there.
        var journal = try Journal.append(allocator, path);
        defer journal.deinit();
        try journal.record(.{ .index = 1, .path = "b.html", .status = .crash });
    }

    var log = try read(allocator, path);
    defer log.deinit();

    try std.testing.expectEqual(@as(usize, 2), log.records.len);
    try std.testing.expectEqualStrings("a.html", log.records[0].path);
    try std.testing.expectEqualStrings("b.html", log.records[1].path);
    try std.testing.expectEqual(@as(usize, 2), log.nextIndex());
}

test "create truncates an existing journal" {
    const allocator = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);
    const path = try std.fs.path.join(allocator, &.{ dir_path, "run.jsonl" });
    defer allocator.free(path);

    {
        var journal = try Journal.create(allocator, path);
        defer journal.deinit();
        try journal.record(.{ .index = 0, .path = "stale.html", .status = .ok });
    }
    {
        var journal = try Journal.create(allocator, path);
        defer journal.deinit();
        try journal.record(.{ .index = 0, .path = "fresh.html", .status = .ok });
    }

    var log = try read(allocator, path);
    defer log.deinit();

    try std.testing.expectEqual(@as(usize, 1), log.records.len);
    try std.testing.expectEqualStrings("fresh.html", log.records[0].path);
}

test "summarize counts records by status" {
    const allocator = std.testing.allocator;

    const bytes =
        \\{"index":0,"path":"a.html","status":"OK","passed":3,"failed":1}
        \\{"index":1,"path":"b.html","status":"ERROR"}
        \\{"index":2,"path":"c.html","status":"CRASH"}
        \\{"index":3,"path":"d.html","status":"OK","passed":2,"failed":0}
        \\{"index":4,"path":"e.html","status":"TIMEOUT"}
        \\
    ;

    var log = try parseLines(allocator, bytes);
    defer log.deinit();

    const s = log.summarize();
    try std.testing.expectEqual(@as(usize, 2), s.ok);
    try std.testing.expectEqual(@as(usize, 1), s.errored);
    try std.testing.expectEqual(@as(usize, 1), s.timed_out);
    try std.testing.expectEqual(@as(usize, 1), s.crashed);
    try std.testing.expectEqual(@as(usize, 5), s.subtests_passed);
    try std.testing.expectEqual(@as(usize, 1), s.subtests_failed);
}
