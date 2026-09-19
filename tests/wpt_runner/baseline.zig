//! Recorded expectations for a WPT run, and the comparison that makes CI red.
//!
//! A pass count on its own says nothing about whether today is better or worse
//! than yesterday. The baseline is the "yesterday": one line per test file
//! saying what that file did last time the numbers were accepted. A run is
//! compared against it, and anything that got *worse* fails.
//!
//! Deliberately per-file rather than per-subtest. The journal already
//! aggregates a file's global contexts into one record, and a file-level
//! baseline is small enough to read in a diff. Subtest-name granularity would
//! catch more, and is the obvious next step, but it needs the harness to report
//! stable subtest names first.
//!
//! What counts as worse:
//!
//!   - the file's status regressed (an OK that now times out, errors or crashes)
//!   - fewer subtests pass than the baseline recorded
//!   - a baselined file did not run at all
//!
//! Improvements and newly-appearing files are reported but do not fail. They
//! mean the baseline is behind, which is a thing to fix on purpose, not a
//! reason to block a change.

const std = @import("std");
const Allocator = std.mem.Allocator;
const journal = @import("journal.zig");
const host = @import("host");

/// What one test file is expected to do.
pub const Expectation = struct {
    path: []const u8,
    status: journal.Status,
    passed: usize = 0,
    failed: usize = 0,
    timed_out: usize = 0,
    notrun: usize = 0,

    /// True when `self` is a worse outcome than `other`.
    ///
    /// Two independent axes: the file-level status, and how many subtests got
    /// through. A file can stay "OK" while quietly passing fewer subtests, and
    /// that is exactly the regression a status-only comparison misses.
    pub fn worseThan(self: Expectation, other: Expectation) bool {
        if (self.status.severity() > other.status.severity()) return true;
        if (self.passed < other.passed) return true;
        return false;
    }

    /// True when `self` is a better outcome than `other`.
    pub fn betterThan(self: Expectation, other: Expectation) bool {
        if (self.status.severity() < other.status.severity()) return true;
        if (self.passed > other.passed) return true;
        return false;
    }
};

fn lessByPath(_: void, a: Expectation, b: Expectation) bool {
    return std.mem.lessThan(u8, a.path, b.path);
}

/// A whole baseline: every expected file, sorted by path.
///
/// Sorted because this file is committed and read in diffs. A baseline whose
/// line order followed discovery order would produce a diff full of moves every
/// time the manifest changed.
pub const Set = struct {
    allocator: Allocator,
    entries: []Expectation,

    pub fn deinit(self: *Set) void {
        for (self.entries) |e| self.allocator.free(e.path);
        self.allocator.free(self.entries);
    }

    /// Look up one path, or null if the baseline does not mention it.
    pub fn find(self: Set, path: []const u8) ?Expectation {
        var lo: usize = 0;
        var hi: usize = self.entries.len;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            switch (std.mem.order(u8, self.entries[mid].path, path)) {
                .lt => lo = mid + 1,
                .gt => hi = mid,
                .eq => return self.entries[mid],
            }
        }
        return null;
    }
};

/// Project a run's journal into a baseline.
///
/// Drops index, duration and message: all three are properties of *this* run
/// rather than of the expected outcome, and committing them would make the
/// baseline churn on every run for no signal.
///
/// A path appearing more than once keeps the worse record. That should not
/// happen - the journal writes one record per file - but a resumed run that
/// overlapped a slice would otherwise silently pick whichever came last.
pub fn fromLog(allocator: Allocator, log: journal.Log) !Set {
    var by_path: std.StringHashMapUnmanaged(Expectation) = .empty;
    defer by_path.deinit(allocator);

    for (log.records) |rec| {
        const candidate: Expectation = .{
            .path = rec.path,
            .status = rec.status,
            .passed = rec.passed,
            .failed = rec.failed,
            .timed_out = rec.timed_out,
            .notrun = rec.notrun,
        };
        const gop = try by_path.getOrPut(allocator, rec.path);
        if (!gop.found_existing or candidate.worseThan(gop.value_ptr.*)) {
            gop.value_ptr.* = candidate;
        }
    }

    return collect(allocator, by_path);
}

/// Build an owned, sorted Set from a borrowed map.
fn collect(allocator: Allocator, by_path: std.StringHashMapUnmanaged(Expectation)) !Set {
    var entries = try allocator.alloc(Expectation, by_path.count());
    var owned: usize = 0;
    errdefer {
        for (entries[0..owned]) |e| allocator.free(e.path);
        allocator.free(entries);
    }

    var it = by_path.iterator();
    while (it.next()) |kv| {
        entries[owned] = kv.value_ptr.*;
        entries[owned].path = try allocator.dupe(u8, kv.value_ptr.path);
        owned += 1;
    }

    std.mem.sort(Expectation, entries, {}, lessByPath);
    return .{ .allocator = allocator, .entries = entries };
}

/// Narrow a baseline to the paths a run actually selected.
///
/// A CI job that runs `url/` has nothing to say about `dom/`. Comparing it
/// against a whole-corpus baseline unscoped would report every file it never
/// asked for as missing, and a gate that is red for a reason nobody caused is
/// a gate people learn to ignore. Scoping keeps `removed` meaning what it
/// should: this was supposed to run, and it did not.
///
/// Only narrows. A selected path the baseline has never seen stays absent, so
/// it surfaces as `added` rather than as a zero-pass expectation to regress
/// from.
pub fn restrictTo(allocator: Allocator, set: Set, paths: []const []const u8) !Set {
    var wanted: std.StringHashMapUnmanaged(void) = .empty;
    defer wanted.deinit(allocator);
    for (paths) |p| try wanted.put(allocator, p, {});

    var kept: std.StringHashMapUnmanaged(Expectation) = .empty;
    defer kept.deinit(allocator);
    for (set.entries) |e| {
        if (wanted.contains(e.path)) try kept.put(allocator, e.path, e);
    }

    return collect(allocator, kept);
}

/// Fold a run's results into an existing baseline, replacing what it covers.
///
/// Recording after a subset run must not delete the expectations that run never
/// touched: `--update-baseline url/` should leave `dom/` exactly as it was.
///
/// Unlike `fromLog`, a path in `fresh` wins outright even when it is worse.
/// Recording a baseline is a deliberate "these are the numbers now"; keeping
/// the better old value would bake in an expectation the suite cannot meet and
/// leave CI red with no way to accept reality.
pub fn merge(allocator: Allocator, old: Set, fresh: Set) !Set {
    var by_path: std.StringHashMapUnmanaged(Expectation) = .empty;
    defer by_path.deinit(allocator);

    for (old.entries) |e| try by_path.put(allocator, e.path, e);
    for (fresh.entries) |e| try by_path.put(allocator, e.path, e);

    return collect(allocator, by_path);
}

/// Serialize a baseline, one JSON object per line.
pub fn write(w: *std.Io.Writer, set: Set) !void {
    for (set.entries) |e| {
        try w.writeAll("{\"path\":");
        try writeJsonString(w, e.path);
        try w.writeAll(",\"status\":");
        try writeJsonString(w, e.status.toString());
        try w.print(
            ",\"passed\":{d},\"failed\":{d},\"timed_out\":{d},\"notrun\":{d}}}\n",
            .{ e.passed, e.failed, e.timed_out, e.notrun },
        );
    }
}

pub fn writeToFile(path: []const u8, set: Set) !void {
    const io = host.io();
    if (std.fs.path.dirname(path)) |dir| {
        host.cwd().createDirPath(io, dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
    }
    var file = try host.cwd().createFile(io, path, .{});
    defer file.close(io);
    var buf: [64 * 1024]u8 = undefined;
    var fw = file.writer(io, &buf);
    try write(&fw.interface, set);
    try fw.interface.flush();
}

/// Parse a baseline's bytes.
///
/// Unlike the journal, a malformed line here is an error rather than something
/// to skip. A journal is read after a crash and is expected to be ragged; a
/// baseline is a committed file, and quietly ignoring a line would silently
/// drop an expectation and turn a regression green.
pub fn parse(allocator: Allocator, bytes: []const u8) !Set {
    var by_path: std.StringHashMapUnmanaged(Expectation) = .empty;
    defer by_path.deinit(allocator);

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const scratch = arena.allocator();

    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0) continue;

        const parsed = std.json.parseFromSliceLeaky(
            std.json.Value,
            scratch,
            line,
            .{},
        ) catch return error.MalformedBaseline;

        const obj = switch (parsed) {
            .object => |o| o,
            else => return error.MalformedBaseline,
        };

        const path = switch (obj.get("path") orelse return error.MalformedBaseline) {
            .string => |s| s,
            else => return error.MalformedBaseline,
        };
        const status_str = switch (obj.get("status") orelse return error.MalformedBaseline) {
            .string => |s| s,
            else => return error.MalformedBaseline,
        };
        const status = journal.Status.fromString(status_str) orelse return error.MalformedBaseline;

        try by_path.put(allocator, path, .{
            .path = path,
            .status = status,
            .passed = jsonUint(obj, "passed"),
            .failed = jsonUint(obj, "failed"),
            .timed_out = jsonUint(obj, "timed_out"),
            .notrun = jsonUint(obj, "notrun"),
        });
    }

    return collect(allocator, by_path);
}

/// Read a baseline from disk. An absent file is not an empty baseline - it is a
/// missing one, and treating it as empty would let a comparison pass by
/// accident.
pub fn read(allocator: Allocator, path: []const u8) !Set {
    const bytes = try host.cwd().readFileAlloc(host.io(), path, allocator, .limited(512 * 1024 * 1024));
    defer allocator.free(bytes);
    return parse(allocator, bytes);
}

/// One file whose outcome moved.
pub const Change = struct {
    path: []const u8,
    before: Expectation,
    after: Expectation,
};

/// What changed between a baseline and a run.
///
/// Every slice borrows its paths from the two Sets compared, so a Diff must not
/// outlive them.
pub const Diff = struct {
    allocator: Allocator,
    regressed: []Change,
    progressed: []Change,
    /// Ran, but the baseline has never heard of it.
    added: []Expectation,
    /// The baseline expects it, but it did not run.
    removed: []Expectation,

    pub fn deinit(self: *Diff) void {
        self.allocator.free(self.regressed);
        self.allocator.free(self.progressed);
        self.allocator.free(self.added);
        self.allocator.free(self.removed);
    }

    /// True when nothing got worse.
    ///
    /// Additions do not fail: a file the baseline has never seen has no
    /// expectation to violate, and failing on it would turn every WPT submodule
    /// bump red for a reason unrelated to the change under test. Removals do
    /// fail, because a baselined file that stops running is indistinguishable
    /// from a discovery regression until someone looks.
    pub fn ok(self: Diff) bool {
        return self.regressed.len == 0 and self.removed.len == 0;
    }
};

/// Compare a run against a baseline.
pub fn diff(allocator: Allocator, before: Set, after: Set) !Diff {
    var regressed: std.ArrayListUnmanaged(Change) = .empty;
    errdefer regressed.deinit(allocator);
    var progressed: std.ArrayListUnmanaged(Change) = .empty;
    errdefer progressed.deinit(allocator);
    var added: std.ArrayListUnmanaged(Expectation) = .empty;
    errdefer added.deinit(allocator);
    var removed: std.ArrayListUnmanaged(Expectation) = .empty;
    errdefer removed.deinit(allocator);

    for (after.entries) |now| {
        const then = before.find(now.path) orelse {
            try added.append(allocator, now);
            continue;
        };
        if (now.worseThan(then)) {
            try regressed.append(allocator, .{ .path = now.path, .before = then, .after = now });
        } else if (now.betterThan(then)) {
            try progressed.append(allocator, .{ .path = now.path, .before = then, .after = now });
        }
    }

    for (before.entries) |then| {
        if (after.find(then.path) == null) try removed.append(allocator, then);
    }

    return .{
        .allocator = allocator,
        .regressed = try regressed.toOwnedSlice(allocator),
        .progressed = try progressed.toOwnedSlice(allocator),
        .added = try added.toOwnedSlice(allocator),
        .removed = try removed.toOwnedSlice(allocator),
    };
}

/// Print a diff, worst first, and say plainly whether it passes.
pub fn report(w: *std.Io.Writer, d: Diff, max_lines: usize) !void {
    if (d.regressed.len > 0) {
        try w.print("\n{d} regressed:\n", .{d.regressed.len});
        for (d.regressed[0..@min(d.regressed.len, max_lines)]) |c| {
            try w.print("  {s}\n    was {s} {d} passed -> now {s} {d} passed\n", .{
                c.path,
                c.before.status.toString(),
                c.before.passed,
                c.after.status.toString(),
                c.after.passed,
            });
        }
        if (d.regressed.len > max_lines) {
            try w.print("  ... and {d} more\n", .{d.regressed.len - max_lines});
        }
    }

    if (d.removed.len > 0) {
        try w.print("\n{d} expected but did not run:\n", .{d.removed.len});
        for (d.removed[0..@min(d.removed.len, max_lines)]) |e| {
            try w.print("  {s}\n", .{e.path});
        }
        if (d.removed.len > max_lines) {
            try w.print("  ... and {d} more\n", .{d.removed.len - max_lines});
        }
    }

    if (d.progressed.len > 0) {
        try w.print("\n{d} improved (update the baseline to lock these in):\n", .{d.progressed.len});
        for (d.progressed[0..@min(d.progressed.len, max_lines)]) |c| {
            try w.print("  {s}: {s} {d} -> {s} {d}\n", .{
                c.path,
                c.before.status.toString(),
                c.before.passed,
                c.after.status.toString(),
                c.after.passed,
            });
        }
        if (d.progressed.len > max_lines) {
            try w.print("  ... and {d} more\n", .{d.progressed.len - max_lines});
        }
    }

    if (d.added.len > 0) {
        try w.print("\n{d} not in the baseline (regenerate it to cover them)\n", .{d.added.len});
    }

    if (d.ok()) {
        try w.writeAll("\nNothing regressed.\n");
    } else {
        try w.print(
            "\nFAILED: {d} regressed, {d} missing.\n",
            .{ d.regressed.len, d.removed.len },
        );
    }
}

fn jsonUint(obj: std.json.ObjectMap, key: []const u8) usize {
    const v = obj.get(key) orelse return 0;
    return switch (v) {
        .integer => |i| if (i < 0) 0 else @intCast(i),
        else => 0,
    };
}

/// Deliberately a copy of journal.writeJsonString: both modules stay std-only
/// and neither should have to import the other for four lines of escaping.
fn writeJsonString(w: *std.Io.Writer, str: []const u8) !void {
    try w.writeByte('"');
    for (str) |c| {
        switch (c) {
            '"' => try w.writeAll("\\\""),
            '\\' => try w.writeAll("\\\\"),
            '\n' => try w.writeAll("\\n"),
            '\r' => try w.writeAll("\\r"),
            '\t' => try w.writeAll("\\t"),
            0x00...0x08, 0x0B, 0x0C, 0x0E...0x1F => try w.print("\\u{x:0>4}", .{c}),
            else => try w.writeByte(c),
        }
    }
    try w.writeByte('"');
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

fn setFrom(allocator: Allocator, entries: []const Expectation) !Set {
    var by_path: std.StringHashMapUnmanaged(Expectation) = .empty;
    defer by_path.deinit(allocator);
    for (entries) |e| try by_path.put(allocator, e.path, e);
    return collect(allocator, by_path);
}

test "a baseline is written sorted by path" {
    // The file is committed and read in diffs; discovery order would make every
    // manifest change look like a rewrite.
    const allocator = testing.allocator;

    var set = try setFrom(allocator, &.{
        .{ .path = "url/a.html", .status = .ok, .passed = 1 },
        .{ .path = "dom/z.html", .status = .ok, .passed = 2 },
        .{ .path = "dom/a.html", .status = .timeout },
    });
    defer set.deinit();

    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();
    try write(&out.writer, set);

    try testing.expectEqualStrings(
        \\{"path":"dom/a.html","status":"TIMEOUT","passed":0,"failed":0,"timed_out":0,"notrun":0}
        \\{"path":"dom/z.html","status":"OK","passed":2,"failed":0,"timed_out":0,"notrun":0}
        \\{"path":"url/a.html","status":"OK","passed":1,"failed":0,"timed_out":0,"notrun":0}
        \\
    , out.written());
}

test "a baseline survives a write/parse round trip" {
    const allocator = testing.allocator;

    var set = try setFrom(allocator, &.{
        .{ .path = "dom/\"odd\"\\name.html", .status = .crash },
        .{ .path = "html/x.html", .status = .@"error", .passed = 3, .failed = 4, .timed_out = 5, .notrun = 6 },
    });
    defer set.deinit();

    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();
    try write(&out.writer, set);

    var back = try parse(allocator, out.written());
    defer back.deinit();

    try testing.expectEqual(@as(usize, 2), back.entries.len);
    const x = back.find("html/x.html").?;
    try testing.expectEqual(journal.Status.@"error", x.status);
    try testing.expectEqual(@as(usize, 3), x.passed);
    try testing.expectEqual(@as(usize, 4), x.failed);
    try testing.expectEqual(@as(usize, 5), x.timed_out);
    try testing.expectEqual(@as(usize, 6), x.notrun);
    try testing.expectEqual(journal.Status.crash, back.find("dom/\"odd\"\\name.html").?.status);
}

test "a malformed baseline line is an error, not a shrug" {
    // The journal skips ragged lines because it is read after a crash. A
    // baseline is committed: skipping a line would drop an expectation and turn
    // a real regression green.
    const allocator = testing.allocator;

    try testing.expectError(error.MalformedBaseline, parse(allocator, "{\"path\":\"a.html\""));
    try testing.expectError(error.MalformedBaseline, parse(allocator, "{\"path\":\"a.html\",\"status\":\"WAT\"}"));
    try testing.expectError(error.MalformedBaseline, parse(allocator, "{\"status\":\"OK\"}"));
}

test "an absent baseline is an error, not an empty one" {
    // Treating a missing file as "expect nothing" would let the comparison pass
    // by accident, which is the one outcome a gate must never produce.
    const allocator = testing.allocator;
    try testing.expectError(error.FileNotFound, read(allocator, "tests/wpt_runner/no-such-baseline.jsonl"));
}

test "a journal projects to a baseline without run-specific noise" {
    const allocator = testing.allocator;

    var log = try journal.parseLines(allocator,
        \\{"index":0,"path":"b.html","status":"OK","passed":4,"failed":1,"duration_ms":991}
        \\{"index":1,"path":"a.html","status":"CRASH","message":"boom","duration_ms":3}
        \\
    );
    defer log.deinit();

    var set = try fromLog(allocator, log);
    defer set.deinit();

    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();
    try write(&out.writer, set);

    // No index, no duration, no message: all three describe this run rather
    // than the expected outcome, and would churn the file on every run.
    try testing.expectEqualStrings(
        \\{"path":"a.html","status":"CRASH","passed":0,"failed":0,"timed_out":0,"notrun":0}
        \\{"path":"b.html","status":"OK","passed":4,"failed":1,"timed_out":0,"notrun":0}
        \\
    , out.written());
}

test "a duplicated path keeps the worse record" {
    const allocator = testing.allocator;

    var log = try journal.parseLines(allocator,
        \\{"index":0,"path":"a.html","status":"OK","passed":9}
        \\{"index":7,"path":"a.html","status":"CRASH"}
        \\
    );
    defer log.deinit();

    var set = try fromLog(allocator, log);
    defer set.deinit();

    try testing.expectEqual(@as(usize, 1), set.entries.len);
    try testing.expectEqual(journal.Status.crash, set.entries[0].status);
}

test "an unchanged run is clean" {
    const allocator = testing.allocator;

    var before = try setFrom(allocator, &.{
        .{ .path = "a.html", .status = .ok, .passed = 3 },
        .{ .path = "b.html", .status = .timeout },
    });
    defer before.deinit();
    var after = try setFrom(allocator, &.{
        .{ .path = "a.html", .status = .ok, .passed = 3 },
        .{ .path = "b.html", .status = .timeout },
    });
    defer after.deinit();

    var d = try diff(allocator, before, after);
    defer d.deinit();

    try testing.expect(d.ok());
    try testing.expectEqual(@as(usize, 0), d.regressed.len);
    try testing.expectEqual(@as(usize, 0), d.progressed.len);
    try testing.expectEqual(@as(usize, 0), d.added.len);
    try testing.expectEqual(@as(usize, 0), d.removed.len);
}

test "a worse status is a regression" {
    const allocator = testing.allocator;

    var before = try setFrom(allocator, &.{.{ .path = "a.html", .status = .ok, .passed = 3 }});
    defer before.deinit();
    var after = try setFrom(allocator, &.{.{ .path = "a.html", .status = .crash }});
    defer after.deinit();

    var d = try diff(allocator, before, after);
    defer d.deinit();

    try testing.expect(!d.ok());
    try testing.expectEqual(@as(usize, 1), d.regressed.len);
    try testing.expectEqualStrings("a.html", d.regressed[0].path);
}

test "fewer subtests passing is a regression even when the status holds" {
    // This is the regression a status-only comparison misses: the file still
    // reports OK, it just quietly stopped passing three of its assertions.
    const allocator = testing.allocator;

    var before = try setFrom(allocator, &.{.{ .path = "a.html", .status = .ok, .passed = 40, .failed = 0 }});
    defer before.deinit();
    var after = try setFrom(allocator, &.{.{ .path = "a.html", .status = .ok, .passed = 37, .failed = 3 }});
    defer after.deinit();

    var d = try diff(allocator, before, after);
    defer d.deinit();

    try testing.expect(!d.ok());
    try testing.expectEqual(@as(usize, 1), d.regressed.len);
    try testing.expectEqual(@as(usize, 40), d.regressed[0].before.passed);
    try testing.expectEqual(@as(usize, 37), d.regressed[0].after.passed);
}

test "a baselined file that did not run fails the comparison" {
    const allocator = testing.allocator;

    var before = try setFrom(allocator, &.{
        .{ .path = "a.html", .status = .ok, .passed = 1 },
        .{ .path = "gone.html", .status = .ok, .passed = 2 },
    });
    defer before.deinit();
    var after = try setFrom(allocator, &.{.{ .path = "a.html", .status = .ok, .passed = 1 }});
    defer after.deinit();

    var d = try diff(allocator, before, after);
    defer d.deinit();

    try testing.expect(!d.ok());
    try testing.expectEqual(@as(usize, 1), d.removed.len);
    try testing.expectEqualStrings("gone.html", d.removed[0].path);
}

test "improvements and new files are reported but do not fail" {
    // Failing on either would turn every WPT submodule bump red for a reason
    // that has nothing to do with the change under test.
    const allocator = testing.allocator;

    var before = try setFrom(allocator, &.{.{ .path = "a.html", .status = .timeout }});
    defer before.deinit();
    var after = try setFrom(allocator, &.{
        .{ .path = "a.html", .status = .ok, .passed = 12 },
        .{ .path = "brand-new.html", .status = .crash },
    });
    defer after.deinit();

    var d = try diff(allocator, before, after);
    defer d.deinit();

    try testing.expect(d.ok());
    try testing.expectEqual(@as(usize, 1), d.progressed.len);
    try testing.expectEqualStrings("a.html", d.progressed[0].path);
    try testing.expectEqual(@as(usize, 1), d.added.len);
    try testing.expectEqualStrings("brand-new.html", d.added[0].path);
}

test "a status that improves while passes drop still counts as a regression" {
    // Worse wins. A file that went from TIMEOUT to OK but reports fewer passing
    // subtests than the baseline has lost coverage, and calling that progress
    // would hide it.
    const allocator = testing.allocator;

    var before = try setFrom(allocator, &.{.{ .path = "a.html", .status = .timeout, .passed = 30 }});
    defer before.deinit();
    var after = try setFrom(allocator, &.{.{ .path = "a.html", .status = .ok, .passed = 2 }});
    defer after.deinit();

    var d = try diff(allocator, before, after);
    defer d.deinit();

    try testing.expect(!d.ok());
    try testing.expectEqual(@as(usize, 1), d.regressed.len);
    try testing.expectEqual(@as(usize, 0), d.progressed.len);
}

test "find locates any entry and rejects absent ones" {
    const allocator = testing.allocator;

    var set = try setFrom(allocator, &.{
        .{ .path = "a.html", .status = .ok },
        .{ .path = "m.html", .status = .timeout },
        .{ .path = "z.html", .status = .crash },
    });
    defer set.deinit();

    try testing.expectEqual(journal.Status.ok, set.find("a.html").?.status);
    try testing.expectEqual(journal.Status.timeout, set.find("m.html").?.status);
    try testing.expectEqual(journal.Status.crash, set.find("z.html").?.status);
    try testing.expect(set.find("b.html") == null);
    try testing.expect(set.find("zz.html") == null);
    try testing.expect(set.find("") == null);
}

test "an empty baseline finds nothing" {
    const allocator = testing.allocator;

    var set = try parse(allocator, "\n  \n");
    defer set.deinit();

    try testing.expectEqual(@as(usize, 0), set.entries.len);
    try testing.expect(set.find("a.html") == null);
}

test "report names what regressed and says it failed" {
    const allocator = testing.allocator;

    var before = try setFrom(allocator, &.{.{ .path = "a.html", .status = .ok, .passed = 5 }});
    defer before.deinit();
    var after = try setFrom(allocator, &.{.{ .path = "a.html", .status = .@"error", .passed = 0 }});
    defer after.deinit();

    var d = try diff(allocator, before, after);
    defer d.deinit();

    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();
    try report(&out.writer, d, 10);

    const text = out.written();
    try testing.expect(std.mem.indexOf(u8, text, "1 regressed") != null);
    try testing.expect(std.mem.indexOf(u8, text, "a.html") != null);
    try testing.expect(std.mem.indexOf(u8, text, "was OK 5 passed -> now ERROR 0 passed") != null);
    try testing.expect(std.mem.indexOf(u8, text, "FAILED") != null);
}

test "report truncates a long list rather than printing thousands of lines" {
    const allocator = testing.allocator;

    var before = try setFrom(allocator, &.{
        .{ .path = "a.html", .status = .ok, .passed = 1 },
        .{ .path = "b.html", .status = .ok, .passed = 1 },
        .{ .path = "c.html", .status = .ok, .passed = 1 },
    });
    defer before.deinit();
    var after = try setFrom(allocator, &.{
        .{ .path = "a.html", .status = .crash },
        .{ .path = "b.html", .status = .crash },
        .{ .path = "c.html", .status = .crash },
    });
    defer after.deinit();

    var d = try diff(allocator, before, after);
    defer d.deinit();

    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();
    try report(&out.writer, d, 1);

    try testing.expect(std.mem.indexOf(u8, out.written(), "... and 2 more") != null);
}

test "report says so plainly when nothing regressed" {
    const allocator = testing.allocator;

    var before = try setFrom(allocator, &.{.{ .path = "a.html", .status = .ok, .passed = 5 }});
    defer before.deinit();
    var after = try setFrom(allocator, &.{.{ .path = "a.html", .status = .ok, .passed = 5 }});
    defer after.deinit();

    var d = try diff(allocator, before, after);
    defer d.deinit();

    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();
    try report(&out.writer, d, 10);

    try testing.expect(std.mem.indexOf(u8, out.written(), "Nothing regressed.") != null);
    try testing.expect(std.mem.indexOf(u8, out.written(), "FAILED") == null);
}

test "a baseline written to disk reads back identically" {
    const allocator = testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir = try tmp.dir.realPathFileAlloc(std.testing.io, ".", allocator);
    defer allocator.free(dir);
    const path = try std.fs.path.join(allocator, &.{ dir, "nested", "baseline.jsonl" });
    defer allocator.free(path);

    var set = try setFrom(allocator, &.{
        .{ .path = "a.html", .status = .ok, .passed = 5, .failed = 1 },
        .{ .path = "b.html", .status = .crash },
    });
    defer set.deinit();

    try writeToFile(path, set);

    var back = try read(allocator, path);
    defer back.deinit();

    try testing.expectEqual(set.entries.len, back.entries.len);
    for (set.entries, back.entries) |want, got| {
        try testing.expectEqualStrings(want.path, got.path);
        try testing.expectEqual(want.status, got.status);
        try testing.expectEqual(want.passed, got.passed);
        try testing.expectEqual(want.failed, got.failed);
    }
}

test "restricting a baseline keeps only the paths a run selected" {
    // A CI job that runs url/ has nothing to say about dom/, so dom/ must not
    // be compared at all - not reported as missing.
    const allocator = testing.allocator;

    var full = try setFrom(allocator, &.{
        .{ .path = "dom/a.html", .status = .ok, .passed = 5 },
        .{ .path = "url/a.html", .status = .ok, .passed = 1 },
        .{ .path = "url/b.html", .status = .timeout },
    });
    defer full.deinit();

    var scoped = try restrictTo(allocator, full, &.{ "url/a.html", "url/b.html" });
    defer scoped.deinit();

    try testing.expectEqual(@as(usize, 2), scoped.entries.len);
    try testing.expectEqualStrings("url/a.html", scoped.entries[0].path);
    try testing.expectEqualStrings("url/b.html", scoped.entries[1].path);
    try testing.expectEqual(@as(usize, 1), scoped.entries[0].passed);
}

test "a selected path the baseline never mentioned stays absent" {
    // restrictTo narrows; it never invents an expectation. A brand new test
    // file has no recorded outcome and must show up as added, not as a
    // zero-pass expectation it then appears to regress from.
    const allocator = testing.allocator;

    var full = try setFrom(allocator, &.{
        .{ .path = "url/a.html", .status = .ok, .passed = 1 },
    });
    defer full.deinit();

    var scoped = try restrictTo(allocator, full, &.{ "url/a.html", "url/brand-new.html" });
    defer scoped.deinit();

    try testing.expectEqual(@as(usize, 1), scoped.entries.len);
    try testing.expectEqual(@as(?Expectation, null), scoped.find("url/brand-new.html"));
}

test "a subset run updates its own paths and leaves the rest of the baseline alone" {
    // --update-baseline after running only url/ must not delete every dom/
    // expectation. Recording a subset is normal; losing the rest is not.
    const allocator = testing.allocator;

    var old = try setFrom(allocator, &.{
        .{ .path = "dom/a.html", .status = .ok, .passed = 5 },
        .{ .path = "url/a.html", .status = .timeout, .passed = 0 },
    });
    defer old.deinit();

    var fresh = try setFrom(allocator, &.{
        .{ .path = "url/a.html", .status = .ok, .passed = 9 },
        .{ .path = "url/new.html", .status = .ok, .passed = 2 },
    });
    defer fresh.deinit();

    var merged = try merge(allocator, old, fresh);
    defer merged.deinit();

    try testing.expectEqual(@as(usize, 3), merged.entries.len);
    // Untouched by this run.
    try testing.expectEqual(@as(usize, 5), merged.find("dom/a.html").?.passed);
    // Replaced wholesale - including a status that got better.
    try testing.expectEqual(journal.Status.ok, merged.find("url/a.html").?.status);
    try testing.expectEqual(@as(usize, 9), merged.find("url/a.html").?.passed);
    // Newly recorded.
    try testing.expectEqual(@as(usize, 2), merged.find("url/new.html").?.passed);
}

test "merging records a run's result even when it is worse" {
    // merge is not fromLog: recording a baseline is an explicit act of saying
    // "these are the numbers now". A worse number that silently kept the old
    // better one would bake in an expectation nothing can meet.
    const allocator = testing.allocator;

    var old = try setFrom(allocator, &.{
        .{ .path = "url/a.html", .status = .ok, .passed = 100 },
    });
    defer old.deinit();

    var fresh = try setFrom(allocator, &.{
        .{ .path = "url/a.html", .status = .timeout, .passed = 0 },
    });
    defer fresh.deinit();

    var merged = try merge(allocator, old, fresh);
    defer merged.deinit();

    try testing.expectEqual(@as(usize, 1), merged.entries.len);
    try testing.expectEqual(journal.Status.timeout, merged.find("url/a.html").?.status);
    try testing.expectEqual(@as(usize, 0), merged.find("url/a.html").?.passed);
}
