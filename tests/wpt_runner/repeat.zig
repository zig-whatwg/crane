//! `wpt_runner --repeat=N`: the flakiness reproducer.
//!
//! One worklist - normally one file - run N times, each repetition a fresh
//! child process of this supervisor, all of them under its one `wpt serve`,
//! its stall watchdog and its crash handling. `--repeat-with=<runner>` runs
//! N more with another runner binary (a frozen main's), alternating with
//! this one, so a base/tip comparison is interleaved on one host. `--load=K`
//! keeps K threads of this process busy for the whole series: background
//! load, added deliberately and stated.
//!
//! The result is the per-subtest failure rate: for every subtest that did
//! not pass in some run, how many of each runner's runs it failed - a
//! subtest a run never reported (the page timed out before it, the child
//! crashed) counts as failed in that run - and each runner's file statuses.
//! It is written to `<output>/repeat-tally.txt` and printed.
//!
//! A repetition never writes a sweep record. Its child keeps its own journal
//! and result stream under `<output>/repeat/<k>/` (`Layout`), two levels
//! below the output directory, where tools/wpt_progress.py never reads (it
//! reads `*.jsonl` in wpt-results/ and one directory below it), and never
//! the parent's `--journal=`. The tally is a `.txt`.
//!
//! Why a runner mode rather than a separate tool: the supervisor already
//! owns the server, the child processes, the watchdog and the crash records,
//! and a frozen runner from before this mode existed still runs as the child
//! (the child's options are the ones every runner has had).

const std = @import("std");
const Allocator = std.mem.Allocator;
const journal = @import("journal.zig");
const options_mod = @import("options.zig");

/// Which runner a repetition used: this binary, or `--repeat-with`'s.
pub const Side = enum(u1) {
    this,
    with,
};

/// The runner of repetition `k` (from 0). With a second runner they
/// alternate, the other one first: base, tip, base, tip - the order the
/// integrator's isolated pairs have always run in.
pub fn sideOf(k: usize, alternating: bool) Side {
    if (!alternating) return .this;
    return if (k % 2 == 0) .with else .this;
}

/// Repetitions in all: N for each runner.
pub fn totalRuns(n: usize, alternating: bool) usize {
    return if (alternating) 2 * n else n;
}

/// The directory runner binary `exe` runs from: `<root>` for
/// `<root>/zig-out/bin/<exe>`, the layout of a build and of a
/// ~/crane-frozen/main-<sha>/ copy. A runner finds its V8 snapshot from its
/// working directory (browser.Process: zig-out/bin/whatwg_snapshot.bin
/// first), so `--repeat-with`'s runner, started from the supervisor's
/// directory, restored the SUPERVISOR's snapshot - accepted whenever the two
/// builds' external-reference counts matched, the only thing the stamp
/// checks - or none. From its own root it restores its own, as it does in a
/// sweep. Null for any other layout: the runner inherits the directory.
pub fn runnerRoot(exe: []const u8) ?[]const u8 {
    const bin = std.fs.path.dirname(exe) orelse return null;
    if (!std.mem.eql(u8, std.fs.path.basename(bin), "bin")) return null;
    const zig_out = std.fs.path.dirname(bin) orelse return null;
    if (!std.mem.eql(u8, std.fs.path.basename(zig_out), "zig-out")) return null;
    return std.fs.path.dirname(zig_out) orelse ".";
}

/// Where a repeat series keeps its files, under the `--output` directory.
pub const Layout = struct {
    output_dir: []const u8,

    pub fn dir(self: Layout, allocator: Allocator) ![]u8 {
        return std.fs.path.join(allocator, &.{ self.output_dir, "repeat" });
    }

    /// The worklist every repetition runs.
    pub fn worklist(self: Layout, allocator: Allocator) ![]u8 {
        return std.fs.path.join(allocator, &.{ self.output_dir, "repeat", "worklist.txt" });
    }

    /// Repetition k's own directory: its child's `--output`.
    pub fn runDir(self: Layout, allocator: Allocator, k: usize) ![]u8 {
        var buf: [24]u8 = undefined;
        const name = std.fmt.bufPrint(&buf, "{d}", .{k}) catch unreachable;
        return std.fs.path.join(allocator, &.{ self.output_dir, "repeat", name });
    }

    /// Repetition k's child's journal - its own, never the parent's.
    pub fn runJournal(self: Layout, allocator: Allocator, k: usize) ![]u8 {
        const d = try self.runDir(allocator, k);
        defer allocator.free(d);
        return std.fs.path.join(allocator, &.{ d, "run.jsonl" });
    }

    /// The result stream the child writes beside that journal
    /// (options.resultsStreamPath: `<stem>.wptreport.jsonl`).
    pub fn runStream(self: Layout, allocator: Allocator, k: usize) ![]u8 {
        const d = try self.runDir(allocator, k);
        defer allocator.free(d);
        return std.fs.path.join(allocator, &.{ d, "run.wptreport.jsonl" });
    }

    /// The series' result.
    pub fn tally(self: Layout, allocator: Allocator) ![]u8 {
        return std.fs.path.join(allocator, &.{ self.output_dir, "repeat-tally.txt" });
    }
};

/// The statuses `--verify` tells apart: WPT's subtest and harness statuses
/// and the journal's file statuses; anything else is `other`.
const SeenStatus = enum { OK, PASS, FAIL, ERROR, TIMEOUT, NOTRUN, PRECONDITION_FAILED, CRASH, other };

fn seenStatus(text: []const u8) SeenStatus {
    return std.meta.stringToEnum(SeenStatus, text) orelse .other;
}

/// One subtest's (or one test URL's harness status's, or one journal
/// file's) record over the series.
const Counts = struct {
    /// Runs in which it passed (a subtest) or was OK (a harness status).
    pass: [2]usize = .{ 0, 0 },
    /// The first failure seen, "STATUS: message", for the report.
    first_failure: ?[]u8 = null,
    /// Runs that reported each status, per runner (`--verify`).
    seen: [2][@typeInfo(SeenStatus).@"enum".field_names.len]usize = @splat(@splat(0)),

    fn reported(c: Counts, s: usize) usize {
        var n: usize = 0;
        for (c.seen[s]) |k| n += k;
        return n;
    }

    /// Whether its status differed between the runner's runs: two statuses,
    /// or reported by some runs and not by others.
    fn differs(c: Counts, s: usize, runs: usize) bool {
        var kinds: usize = 0;
        for (c.seen[s]) |k| kinds += @intFromBool(k != 0);
        const n = c.reported(s);
        return kinds > 1 or (n != 0 and n < runs);
    }
};

/// The per-subtest failure rate over a repeat series.
pub const Tally = struct {
    allocator: Allocator,
    /// Repetitions per runner.
    runs: [2]usize = .{ 0, 0 },
    /// Journal records by status, per runner (one per file per run).
    statuses: [2][4]usize = .{ .{ 0, 0, 0, 0 }, .{ 0, 0, 0, 0 } },
    /// "<test URL>\t<subtest name>" -> counts.
    subtests: std.StringArrayHashMapUnmanaged(Counts) = .empty,
    /// "<test URL>" -> harness OK counts.
    harness: std.StringArrayHashMapUnmanaged(Counts) = .empty,
    /// "<journal path>[\t<context>]" -> the file's journal statuses
    /// (`--verify`: a file whose status differs between runs).
    files: std.StringArrayHashMapUnmanaged(Counts) = .empty,

    pub fn init(allocator: Allocator) Tally {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Tally) void {
        inline for (.{ &self.subtests, &self.harness, &self.files }) |map| {
            for (map.keys(), map.values()) |k, v| {
                self.allocator.free(k);
                if (v.first_failure) |f| self.allocator.free(f);
            }
            map.deinit(self.allocator);
        }
    }

    /// How many of each runner's runs subtest `name` of test URL `url`
    /// failed - including runs that never reported it - or null when no run
    /// reported it at all.
    pub fn failures(self: *const Tally, url: []const u8, name: []const u8) ?[2]usize {
        var buf: [1024]u8 = undefined;
        const key = std.fmt.bufPrint(&buf, "{s}\t{s}", .{ url, name }) catch return null;
        const c = self.subtests.get(key) orelse return null;
        return .{ self.runs[0] -| c.pass[0], self.runs[1] -| c.pass[1] };
    }

    fn entry(self: *Tally, map: *std.StringArrayHashMapUnmanaged(Counts), key: []const u8) !*Counts {
        const gop = try map.getOrPut(self.allocator, key);
        if (!gop.found_existing) {
            gop.key_ptr.* = self.allocator.dupe(u8, key) catch |err| {
                _ = map.pop();
                return err;
            };
            gop.value_ptr.* = .{};
        }
        return gop.value_ptr;
    }

    fn noteFailure(self: *Tally, c: *Counts, status: []const u8, message: ?[]const u8) !void {
        if (c.first_failure != null) return;
        c.first_failure = try std.fmt.allocPrint(self.allocator, "{s}: {s}", .{ status, message orelse "" });
    }

    /// One repetition: its child's journal and result stream, as bytes.
    /// Unparseable lines are skipped (a crash truncates the last one).
    pub fn addRun(self: *Tally, side: Side, journal_bytes: []const u8, stream_bytes: []const u8) !void {
        const s = @backingInt(side);
        self.runs[s] += 1;

        var log = try journal.parseLines(self.allocator, journal_bytes);
        defer log.deinit();
        for (log.records) |rec| {
            self.statuses[s][@backingInt(rec.status)] += 1;
            var key_buf: [2048]u8 = undefined;
            const key = if (rec.context.len == 0) rec.path else std.fmt.bufPrint(&key_buf, "{s}\t{s}", .{ rec.path, rec.context }) catch rec.path;
            const f = try self.entry(&self.files, key);
            f.seen[s][@backingInt(seenStatus(rec.status.toString()))] += 1;
        }

        var lines = std.mem.splitScalar(u8, stream_bytes, '\n');
        while (lines.next()) |raw| {
            const line = std.mem.trim(u8, raw, " \t\r");
            if (line.len == 0) continue;
            var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, line, .{}) catch continue;
            defer parsed.deinit();
            const obj = switch (parsed.value) {
                .object => |o| o,
                else => continue,
            };
            const url = stringField(obj, "test") orelse continue;
            const status = stringField(obj, "status") orelse continue;

            const h = try self.entry(&self.harness, url);
            h.seen[s][@backingInt(seenStatus(status))] += 1;
            if (std.mem.eql(u8, status, "OK")) h.pass[s] += 1 else try self.noteFailure(h, status, stringField(obj, "message"));

            const subs = switch (obj.get("subtests") orelse continue) {
                .array => |a| a,
                else => continue,
            };
            // A name a file reports twice in one run is two subtests: its
            // second is "<name> #2", so two differently-ending subtests of
            // one name are not one subtest whose status differs.
            var occurrences: std.StringHashMapUnmanaged(u32) = .empty;
            defer occurrences.deinit(self.allocator);
            for (subs.items) |sv| {
                const so = switch (sv) {
                    .object => |o| o,
                    else => continue,
                };
                const name = stringField(so, "name") orelse continue;
                const sub_status = stringField(so, "status") orelse continue;
                const seen_before = try occurrences.getOrPut(self.allocator, name);
                seen_before.value_ptr.* = if (seen_before.found_existing) seen_before.value_ptr.* + 1 else 1;
                const key = if (seen_before.value_ptr.* == 1)
                    try std.fmt.allocPrint(self.allocator, "{s}\t{s}", .{ url, name })
                else
                    try std.fmt.allocPrint(self.allocator, "{s}\t{s} #{d}", .{ url, name, seen_before.value_ptr.* });
                defer self.allocator.free(key);
                const c = try self.entry(&self.subtests, key);
                c.seen[s][@backingInt(seenStatus(sub_status))] += 1;
                if (std.mem.eql(u8, sub_status, "PASS")) c.pass[s] += 1 else try self.noteFailure(c, sub_status, stringField(so, "message"));
            }
        }
    }

    pub const Header = struct {
        /// This runner's path, and `--repeat-with`'s (null when none).
        this: []const u8,
        with: ?[]const u8,
        load_threads: u32 = 0,
        /// `--verify`: end with the verdict and every unstable entry.
        verify: bool = false,
    };

    /// `--verify`: how many files, harness statuses and subtests had a
    /// status that differed between `side`'s runs. A consistent failure is
    /// not one; a status a run never reported is.
    pub fn unstable(self: *const Tally, side: Side) usize {
        const s = @backingInt(side);
        var n: usize = 0;
        inline for (.{ &self.files, &self.harness, &self.subtests }) |map| {
            for (map.values()) |c| n += @intFromBool(c.differs(s, self.runs[s]));
        }
        return n;
    }

    /// `--verify`'s exit status: 1 when any status differed between runs.
    pub fn verifyExitCode(self: *const Tally) u8 {
        return if (self.unstable(.this) + self.unstable(.with) == 0) 0 else 1;
    }

    fn writeVerify(self: *const Tally, w: *std.Io.Writer, header: Header) !void {
        const sides: []const Side = if (header.with != null) &.{ .this, .with } else &.{.this};
        for (sides) |side| {
            const s = @backingInt(side);
            const label = if (header.with == null) "" else if (side == .this) " (this)" else " (with)";
            const bad = self.unstable(side);
            if (bad == 0) {
                try w.print("verify{s}: STABLE over {d} runs (every file, harness status and subtest had one status in every run)\n", .{ label, self.runs[s] });
                continue;
            }
            try w.print("verify{s}: UNSTABLE - {d} with a status that differs between the {d} runs:\n", .{ label, bad, self.runs[s] });
            const kinds = [_]struct { name: []const u8, map: *const std.StringArrayHashMapUnmanaged(Counts) }{
                .{ .name = "file", .map = &self.files },
                .{ .name = "harness", .map = &self.harness },
                .{ .name = "subtest", .map = &self.subtests },
            };
            for (kinds) |kind| {
                for (kind.map.keys(), kind.map.values()) |key, c| {
                    if (!c.differs(s, self.runs[s])) continue;
                    try w.print("  {s} ", .{kind.name});
                    if (std.mem.indexOfScalar(u8, key, '\t')) |tab| {
                        try w.print("{s} | {s}: ", .{ key[0..tab], key[tab + 1 ..] });
                    } else try w.print("{s}: ", .{key});
                    var first = true;
                    for (c.seen[s], 0..) |k, i| {
                        if (k == 0) continue;
                        try w.print("{s}{s} {d}", .{ if (first) "" else ", ", @typeInfo(SeenStatus).@"enum".field_names[i], k });
                        first = false;
                    }
                    const missing = self.runs[s] -| c.reported(s);
                    if (missing != 0) try w.print("{s}(not reported) {d}", .{ if (first) "" else ", ", missing });
                    try w.writeByte('\n');
                }
            }
        }
    }

    fn failed(self: *const Tally, c: Counts) usize {
        return (self.runs[0] -| c.pass[0]) + (self.runs[1] -| c.pass[1]);
    }

    fn rate(self: *const Tally, w: *std.Io.Writer, c: Counts, header: Header) !void {
        try w.print("{d}/{d}", .{ self.runs[0] -| c.pass[0], self.runs[0] });
        if (header.with != null) try w.print("  {d}/{d}", .{ self.runs[1] -| c.pass[1], self.runs[1] });
    }

    const Order = struct {
        tally: *const Tally,
        map: *const std.StringArrayHashMapUnmanaged(Counts),
        pub fn lessThan(ctx: Order, a: usize, b: usize) bool {
            const vals = ctx.map.values();
            const fa = ctx.tally.failed(vals[a]);
            const fb = ctx.tally.failed(vals[b]);
            if (fa != fb) return fa > fb;
            return std.mem.lessThan(u8, ctx.map.keys()[a], ctx.map.keys()[b]);
        }
    };

    fn writeSection(self: *const Tally, w: *std.Io.Writer, map: *const std.StringArrayHashMapUnmanaged(Counts), header: Header) !usize {
        var order: std.ArrayList(usize) = .empty;
        defer order.deinit(self.allocator);
        for (map.values(), 0..) |c, i| if (self.failed(c) > 0) try order.append(self.allocator, i);
        std.mem.sort(usize, order.items, Order{ .tally = self, .map = map }, Order.lessThan);
        for (order.items) |i| {
            const c = map.values()[i];
            try w.writeAll("  ");
            try self.rate(w, c, header);
            try w.writeAll("  ");
            const key = map.keys()[i];
            if (std.mem.indexOfScalar(u8, key, '\t')) |tab| {
                try w.print("{s} | {s}", .{ key[0..tab], key[tab + 1 ..] });
            } else try w.writeAll(key);
            if (c.first_failure) |f| try w.print("\n      first: {s}", .{f});
            try w.writeByte('\n');
        }
        return order.items.len;
    }

    /// The report: runners, load, file statuses, then every harness status
    /// and subtest that failed in some run, worst first, as
    /// `<this fails>/<this runs>  [<with fails>/<with runs>]  <url> | <name>`.
    pub fn write(self: *const Tally, w: *std.Io.Writer, header: Header) !void {
        try w.print("repeat: {d} runs of {s}\n", .{ self.runs[0], header.this });
        if (header.with) |other| try w.print("        {d} runs of {s} (alternating, it first; its rates are the second column)\n", .{ self.runs[1], other });
        if (header.load_threads > 0)
            try w.print("load: {d} busy threads in the supervisor for the whole series\n", .{header.load_threads})
        else
            try w.writeAll("load: none added\n");

        const sides: []const Side = if (header.with != null) &.{ .this, .with } else &.{.this};
        for (sides) |side| {
            const s = @backingInt(side);
            try w.print("file statuses ({s}):", .{if (side == .this) "this" else "with"});
            inline for (@typeInfo(journal.Status).@"enum".field_values) |fv| {
                const st: journal.Status = @fromBackingInt(@intCast(fv));
                const n = self.statuses[s][@backingInt(st)];
                if (n > 0) try w.print(" {s} {d}", .{ st.toString(), n });
            }
            try w.writeByte('\n');
        }

        try w.writeAll("harness status not OK (runs):\n");
        if (try self.writeSection(w, &self.harness, header) == 0) try w.writeAll("  none\n");
        try w.writeAll("subtests that failed in some run (runs failed):\n");
        const failing = try self.writeSection(w, &self.subtests, header);
        if (failing == 0) try w.writeAll("  none\n");
        const steady = self.subtests.count() - failing;
        try w.print("{d} subtest{s} passed in every run\n", .{ steady, if (steady == 1) "" else "s" });
        if (header.verify) try self.writeVerify(w, header);
    }
};

fn stringField(obj: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    return switch (obj.get(key) orelse return null) {
        .string => |s| s,
        else => null,
    };
}

/// `--load=K`: K threads that spin until stopped.
pub const Load = struct {
    stop_flag: std.atomic.Value(bool) = .init(false),
    threads: []std.Thread = &.{},

    fn spin(self: *Load) void {
        // This thread's alternate signal stack, for a stack overflow's report (signal_stack.zig).
        const signal_stack = @import("signal_stack.zig").attach();
        defer @import("signal_stack.zig").detach(signal_stack);
        var x: u64 = 0;
        while (!self.stop_flag.load(.monotonic)) {
            x +%= 0x9E3779B97F4A7C15;
            std.mem.doNotOptimizeAway(x);
        }
    }

    pub fn start(self: *Load, allocator: Allocator, n: u32) !void {
        if (n == 0) return;
        self.threads = try allocator.alloc(std.Thread, n);
        var started: usize = 0;
        errdefer {
            self.stop_flag.store(true, .monotonic);
            for (self.threads[0..started]) |t| t.join();
            allocator.free(self.threads);
            self.threads = &.{};
        }
        while (started < n) : (started += 1) self.threads[started] = try std.Thread.spawn(.{}, spin, .{self});
    }

    pub fn stop(self: *Load, allocator: Allocator) void {
        if (self.threads.len == 0) return;
        self.stop_flag.store(true, .monotonic);
        for (self.threads) |t| t.join();
        allocator.free(self.threads);
        self.threads = &.{};
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

/// How many directory levels `path` lies below `dir` (a prefix of it).
fn depthBelow(dir: []const u8, path: []const u8) usize {
    std.debug.assert(std.mem.startsWith(u8, path, dir));
    return std.mem.count(u8, std.mem.trimStart(u8, path[dir.len..], "/"), "/");
}

test "a repetition's files live under <output>/repeat/<k>/, below where the progress report reads" {
    const allocator = testing.allocator;
    for ([_][]const u8{ "wpt-results", "wpt-results/lanes/x", "out" }) |out| {
        const layout: Layout = .{ .output_dir = out };
        const j = try layout.runJournal(allocator, 3);
        defer allocator.free(j);
        const s = try layout.runStream(allocator, 3);
        defer allocator.free(s);
        const d = try layout.runDir(allocator, 3);
        defer allocator.free(d);
        const t = try layout.tally(allocator);
        defer allocator.free(t);

        // wpt_progress.py reads <results>/*.jsonl and <results>/*/*.jsonl:
        // a repetition's journal is at least two levels below the output.
        try testing.expect(depthBelow(out, j) >= 2);
        try testing.expect(depthBelow(out, s) >= 2);
        try testing.expect(!std.mem.startsWith(u8, std.fs.path.basename(j), "journal"));
        try testing.expect(std.mem.endsWith(u8, s, ".wptreport.jsonl"));
        // The child derives its stream from its journal (options.resultsStreamPath).
        try testing.expectEqualStrings(std.fs.path.dirname(j).?, d);
        // The tally is never a journal.
        try testing.expect(!std.mem.endsWith(u8, t, ".jsonl"));
        try testing.expectEqual(@as(usize, 0), depthBelow(out, t));
    }
}

test "a repetition's child keeps its own journal, never the parent's" {
    const allocator = testing.allocator;
    var parent = try options_mod.parseArgs(allocator, &.{
        "--repeat=5",
        "--journal=wpt-results/sweep-x/journal.jsonl",
        "--output=wpt-results/sweep-x",
        "a/b.html",
    });
    defer parent.deinit();
    const layout: Layout = .{ .output_dir = parent.output_dir };

    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const argv = try options_mod.childArgv(a, parent, .{
        .exe = "/frozen/wpt_runner",
        .worklist = try layout.worklist(a),
        .start_index = 0,
        .journal = try layout.runJournal(a, 0),
        .output_dir = try layout.runDir(a, 0),
        .heartbeat = "hb",
    });

    try testing.expectEqualStrings("/frozen/wpt_runner", argv[0]);
    var journals: usize = 0;
    for (argv) |arg| {
        try testing.expect(std.mem.indexOf(u8, arg, "sweep-x/journal.jsonl") == null);
        try testing.expect(!std.mem.startsWith(u8, arg, "--repeat"));
        if (std.mem.startsWith(u8, arg, "--journal=")) {
            journals += 1;
            try testing.expectEqualStrings("--journal=wpt-results/sweep-x/repeat/0/run.jsonl", arg);
        }
        if (std.mem.startsWith(u8, arg, "--output=")) try testing.expectEqualStrings("--output=wpt-results/sweep-x/repeat/0", arg);
    }
    try testing.expectEqual(@as(usize, 1), journals);
}

test "with a second runner, repetitions alternate, the other runner first" {
    try testing.expectEqual(Side.with, sideOf(0, true));
    try testing.expectEqual(Side.this, sideOf(1, true));
    try testing.expectEqual(Side.with, sideOf(2, true));
    try testing.expectEqual(Side.this, sideOf(0, false));
    try testing.expectEqual(Side.this, sideOf(1, false));
    try testing.expectEqual(@as(usize, 10), totalRuns(5, true));
    try testing.expectEqual(@as(usize, 5), totalRuns(5, false));
}

test "the other runner runs from its own root, where its own snapshot is" {
    try testing.expectEqualStrings("/u/crane-frozen/main-0aa6c6c8cf", runnerRoot("/u/crane-frozen/main-0aa6c6c8cf/zig-out/bin/wpt_runner").?);
    try testing.expectEqualStrings("/u/crane-work/lane", runnerRoot("/u/crane-work/lane/zig-out/bin/wpt_runner").?);
    try testing.expectEqualStrings(".", runnerRoot("zig-out/bin/wpt_runner").?);
    // Any other layout keeps the supervisor's directory.
    try testing.expect(runnerRoot("/u/bins/wpt_runner") == null);
    try testing.expect(runnerRoot("/u/zig-out/wpt_runner") == null);
    try testing.expect(runnerRoot("wpt_runner") == null);
}

const ok_record = "{\"index\":0,\"path\":\"a.html\",\"context\":\"\",\"status\":\"OK\",\"passed\":2,\"failed\":0}\n";

test "the tally counts each subtest's failures per runner, a missing subtest as failed" {
    const allocator = testing.allocator;
    var t = Tally.init(allocator);
    defer t.deinit();

    try t.addRun(.this, ok_record,
        \\{"test": "/a.html", "status": "OK", "message": null, "duration": 1, "subtests": [{"name": "x", "status": "PASS", "message": null}, {"name": "y", "status": "FAIL", "message": "assert_equals: 1 got 2"}]}
        \\
    );
    try t.addRun(.this, "{\"index\":0,\"path\":\"a.html\",\"context\":\"\",\"status\":\"TIMEOUT\",\"passed\":1}\n",
        \\{"test": "/a.html", "status": "TIMEOUT", "message": "Test timed out", "duration": 1, "subtests": [{"name": "x", "status": "PASS", "message": null}]}
        \\
    );
    try t.addRun(.with, ok_record,
        \\{"test": "/a.html", "status": "OK", "message": null, "duration": 1, "subtests": [{"name": "x", "status": "PASS", "message": null}, {"name": "y", "status": "PASS", "message": null}]}
        \\
    );

    try testing.expectEqual(@as(usize, 2), t.runs[@backingInt(Side.this)]);
    try testing.expectEqual(@as(usize, 1), t.runs[@backingInt(Side.with)]);
    // y: FAIL in run 1, never reported in run 2 (the page timed out first).
    try testing.expectEqual([2]usize{ 2, 0 }, t.failures("/a.html", "y").?);
    try testing.expectEqual([2]usize{ 0, 0 }, t.failures("/a.html", "x").?);
    try testing.expect(t.failures("/a.html", "z") == null);
    // File statuses, per runner, from the journals.
    try testing.expectEqual(@as(usize, 1), t.statuses[@backingInt(Side.this)][@backingInt(journal.Status.ok)]);
    try testing.expectEqual(@as(usize, 1), t.statuses[@backingInt(Side.this)][@backingInt(journal.Status.timeout)]);
    try testing.expectEqual(@as(usize, 1), t.statuses[@backingInt(Side.with)][@backingInt(journal.Status.ok)]);
}

test "a run that crashed before streaming anything fails every subtest" {
    const allocator = testing.allocator;
    var t = Tally.init(allocator);
    defer t.deinit();
    try t.addRun(.this, ok_record,
        \\{"test": "/a.html", "status": "OK", "message": null, "duration": 1, "subtests": [{"name": "x", "status": "PASS", "message": null}]}
        \\
    );
    try t.addRun(.this, "{\"index\":0,\"path\":\"a.html\",\"context\":\"\",\"status\":\"CRASH\",\"message\":\"process terminated\"}\n", "");
    try testing.expectEqual([2]usize{ 1, 0 }, t.failures("/a.html", "x").?);
    try testing.expectEqual(@as(usize, 1), t.statuses[@backingInt(Side.this)][@backingInt(journal.Status.crash)]);
}

test "the report lists failing subtests worst first, with their rates and first failure" {
    const allocator = testing.allocator;
    var t = Tally.init(allocator);
    defer t.deinit();
    const line =
        \\{"test": "/a.html", "status": "OK", "message": null, "duration": 1, "subtests": [{"name": "rare", "status": "PASS", "message": null}, {"name": "often", "status": "FAIL", "message": "boom"}, {"name": "never", "status": "PASS", "message": null}]}
        \\
    ;
    const line2 =
        \\{"test": "/a.html", "status": "OK", "message": null, "duration": 1, "subtests": [{"name": "rare", "status": "FAIL", "message": "once"}, {"name": "often", "status": "FAIL", "message": "boom"}, {"name": "never", "status": "PASS", "message": null}]}
        \\
    ;
    try t.addRun(.this, ok_record, line);
    try t.addRun(.this, ok_record, line2);

    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();
    try t.write(&out.writer, .{ .this = "tip/wpt_runner", .with = null, .load_threads = 2 });
    const text = out.written();

    const often = std.mem.indexOf(u8, text, "2/2  /a.html | often") orelse return error.TestExpectedEqual;
    const rare = std.mem.indexOf(u8, text, "1/2  /a.html | rare") orelse return error.TestExpectedEqual;
    try testing.expect(often < rare);
    try testing.expect(std.mem.indexOf(u8, text, "FAIL: boom") != null);
    try testing.expect(std.mem.indexOf(u8, text, "| never") == null);
    try testing.expect(std.mem.indexOf(u8, text, "load: 2 busy threads") != null);
    try testing.expect(std.mem.indexOf(u8, text, "1 subtest passed in every run") != null);
}

// ---------------------------------------------------------------------------
// --verify: the changed-test gate (AGENTS.md "Before every commit"). A file
// or subtest whose status differs between the runs of a series fails it; a
// consistent failure does not.

fn subtestLine(comptime status: []const u8) []const u8 {
    return "{\"test\": \"/a.html\", \"status\": \"OK\", \"message\": null, \"duration\": 1, \"subtests\": [{\"name\": \"x\", \"status\": \"" ++ status ++ "\", \"message\": null}]}\n";
}

test "verify: a subtest that fails in every run, the same way, is stable" {
    var t = Tally.init(testing.allocator);
    defer t.deinit();
    for (0..10) |_| try t.addRun(.this, ok_record, subtestLine("FAIL"));
    try testing.expectEqual(@as(usize, 0), t.unstable(.this));
    try testing.expectEqual(@as(u8, 0), t.verifyExitCode());
}

test "verify: a subtest that passes in some runs and fails in others is unstable" {
    var t = Tally.init(testing.allocator);
    defer t.deinit();
    for (0..9) |_| try t.addRun(.this, ok_record, subtestLine("PASS"));
    try t.addRun(.this, ok_record, subtestLine("FAIL"));
    try testing.expectEqual(@as(usize, 1), t.unstable(.this));
    try testing.expectEqual(@as(u8, 1), t.verifyExitCode());
}

test "verify: a subtest that fails in every run but with different statuses is unstable" {
    var t = Tally.init(testing.allocator);
    defer t.deinit();
    try t.addRun(.this, ok_record, subtestLine("FAIL"));
    try t.addRun(.this, ok_record, subtestLine("TIMEOUT"));
    try testing.expectEqual(@as(usize, 1), t.unstable(.this));
}

test "verify: a subtest a run never reported is unstable" {
    var t = Tally.init(testing.allocator);
    defer t.deinit();
    try t.addRun(.this, ok_record, subtestLine("PASS"));
    // The page ended before x reported, but the file's status is the same.
    try t.addRun(.this, ok_record, "{\"test\": \"/a.html\", \"status\": \"OK\", \"message\": null, \"duration\": 1, \"subtests\": []}\n");
    try testing.expectEqual(@as(usize, 1), t.unstable(.this));
}

test "verify: a file whose status differs between runs is unstable, even with no subtest to show it" {
    var t = Tally.init(testing.allocator);
    defer t.deinit();
    try t.addRun(.this, ok_record, "");
    try t.addRun(.this, "{\"index\":0,\"path\":\"a.html\",\"context\":\"\",\"status\":\"TIMEOUT\"}\n", "");
    try testing.expectEqual(@as(usize, 1), t.unstable(.this));
    // A file that crashes in every run is a consistent failure.
    var c = Tally.init(testing.allocator);
    defer c.deinit();
    for (0..3) |_| try c.addRun(.this, "{\"index\":0,\"path\":\"a.html\",\"context\":\"\",\"status\":\"CRASH\"}\n", "");
    try testing.expectEqual(@as(usize, 0), c.unstable(.this));
}

test "verify: two subtests of one name that end differently, the same in every run, are stable" {
    var t = Tally.init(testing.allocator);
    defer t.deinit();
    const twice = "{\"test\": \"/a.html\", \"status\": \"OK\", \"message\": null, \"duration\": 1, \"subtests\": [{\"name\": \"x\", \"status\": \"PASS\", \"message\": null}, {\"name\": \"x\", \"status\": \"FAIL\", \"message\": null}]}\n";
    for (0..3) |_| try t.addRun(.this, ok_record, twice);
    try testing.expectEqual(@as(usize, 0), t.unstable(.this));
    try testing.expectEqual([2]usize{ 3, 0 }, t.failures("/a.html", "x #2").?);
}

test "verify: the report names every unstable file and subtest with each status it had" {
    var t = Tally.init(testing.allocator);
    defer t.deinit();
    try t.addRun(.this, ok_record, subtestLine("PASS"));
    try t.addRun(.this, "{\"index\":0,\"path\":\"a.html\",\"context\":\"\",\"status\":\"TIMEOUT\"}\n", subtestLine("NOTRUN"));
    var out: std.Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    try t.write(&out.writer, .{ .this = "tip/wpt_runner", .with = null, .verify = true });
    const text = out.written();
    try testing.expect(std.mem.indexOf(u8, text, "verify: UNSTABLE") != null);
    try testing.expect(std.mem.indexOf(u8, text, "file a.html: OK 1, TIMEOUT 1") != null);
    try testing.expect(std.mem.indexOf(u8, text, "subtest /a.html | x: PASS 1, NOTRUN 1") != null);

    var s = Tally.init(testing.allocator);
    defer s.deinit();
    try s.addRun(.this, ok_record, subtestLine("PASS"));
    try s.addRun(.this, ok_record, subtestLine("PASS"));
    var quiet: std.Io.Writer.Allocating = .init(testing.allocator);
    defer quiet.deinit();
    try s.write(&quiet.writer, .{ .this = "tip/wpt_runner", .with = null, .verify = true });
    try testing.expect(std.mem.indexOf(u8, quiet.written(), "verify: STABLE over 2 runs") != null);
}
