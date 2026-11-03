//! Verify mode: the gate for new and changed tests, before they land.
//!
//! Every engine runs a test it has just been given more than once before it
//! trusts it: Gecko's test-verify (TV) runs each new or changed test 10 times
//! in one browser, 5 times each in a fresh one, then both again in chaos
//! mode, and stops at the first failure (testing/mochitest/runtests.py
//! verifyTests); Chromium's flakiness check runs new tests 20 times; WebKit's
//! commit queue repeats changed layout tests 10 (or 100) times
//! (tmp/analysis/test-research/gecko.md, chromium.md, webkit.md). A test
//! that passes once and fails one time in ten is a flake from its first day,
//! and the one-flake-then-bug rule starts with a bug nobody owns.
//!
//! Crane's form, for the tests of one test executable that a branch added or
//! changed (build.zig `test-verify`, which names them by file):
//!   - batched: the selected tests, in order, `batched` times over, in ONE
//!     process - so a test that passes alone but not after itself, or after
//!     the others of its file, fails here;
//!   - alone:   each selected test `alone` times, each in a fresh process.
//! Any run that is not a pass (fail, crash, timeout, leak, an error logged -
//! the Crane test runner's state check among them) fails the test's
//! verification. Under -Dsanitize-thread the same mode runs once
//! (build.zig: batched 1, alone 0) - "once under ThreadSanitizer".
//!
//! The process work goes through the scheduler's `Executor`, so this is
//! tested with a fake one (below) and runs real processes through child.zig.

const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const sched = @import("scheduler.zig");

pub const Options = struct {
    /// Runs of the whole selection in one process.
    batched: u32 = 10,
    /// Runs of each test alone, each in a fresh process.
    alone: u32 = 5,
    jobs: u32 = 1,
};

pub const Phase = enum { batched, alone };

/// One selected test's runs.
pub const Outcome = struct {
    batched_runs: u32 = 0,
    batched_ok: u32 = 0,
    alone_runs: u32 = 0,
    alone_ok: u32 = 0,
    /// The first run that was not a pass: its phase, its number (from 1)
    /// and status; `output` is what it printed.
    first_bad: ?struct { phase: Phase, run: u32, status: sched.Status } = null,
    output: []u8 = &.{},

    pub fn passed(o: Outcome, options: Options) bool {
        return o.first_bad == null and o.batched_runs == options.batched and o.alone_runs == options.alone;
    }
};

pub const Verify = struct {
    gpa: Allocator,
    io: Io,
    exec: sched.Executor,
    /// The selected tests, by index into the executable's test list.
    tests: []const u32,
    options: Options,
    /// One per selected test, in `tests` order.
    outcomes: []Outcome,
    next_job: std.atomic.Value(u32) = .init(0),
    lock: Io.Mutex = .init,
    /// Processes started.
    processes: std.atomic.Value(u32) = .init(0),

    pub fn init(gpa: Allocator, io: Io, exec: sched.Executor, tests: []const u32, options: Options) !Verify {
        const outcomes = try gpa.alloc(Outcome, tests.len);
        for (outcomes) |*o| o.* = .{};
        return .{ .gpa = gpa, .io = io, .exec = exec, .tests = tests, .options = options, .outcomes = outcomes };
    }

    pub fn deinit(v: *Verify) void {
        for (v.outcomes) |o| v.gpa.free(o.output);
        v.gpa.free(v.outcomes);
    }

    /// Job 0 is the batched sequence (when asked for); then one job per
    /// (test, alone run).
    fn jobCount(v: *const Verify) u32 {
        const batched_jobs: u32 = @intFromBool(v.options.batched != 0 and v.tests.len != 0);
        return batched_jobs + @as(u32, @intCast(v.tests.len)) * v.options.alone;
    }

    pub fn execute(v: *Verify) !void {
        const jobs = @max(v.options.jobs, 1);
        if (jobs == 1) return v.worker(0);
        var group: Io.Group = .init;
        defer group.cancel(v.io);
        for (0..jobs) |w| {
            group.concurrent(v.io, worker, .{ v, @as(u32, @intCast(w)) }) catch |err| switch (err) {
                error.ConcurrencyUnavailable => try v.worker(@intCast(w)),
            };
        }
        try group.await(v.io);
    }

    fn worker(v: *Verify, w: u32) Io.Cancelable!void {
        const total = v.jobCount();
        const has_batched = v.options.batched != 0 and v.tests.len != 0;
        while (true) {
            const job = v.next_job.fetchAdd(1, .monotonic);
            if (job >= total) return;
            if (has_batched and job == 0) {
                v.runBatched(w);
                continue;
            }
            const k = job - @intFromBool(has_batched);
            const position = k / v.options.alone;
            const run_number = k % v.options.alone + 1;
            v.runSequence(w, &.{v.tests[position]}, .alone, run_number);
        }
    }

    fn runBatched(v: *Verify, w: u32) void {
        // The whole selection, `batched` times, as one sequence in one
        // process (a new one only after a crash or timeout kills it).
        const sequence = v.gpa.alloc(u32, v.tests.len * v.options.batched) catch {
            v.record(0, .batched, 1, .{ .status = .launcher_error, .output = &.{} });
            return;
        };
        defer v.gpa.free(sequence);
        for (0..v.options.batched) |k| @memcpy(sequence[k * v.tests.len ..][0..v.tests.len], v.tests);
        v.runSequence(w, sequence, .batched, 0);
    }

    /// Runs `sequence` in order, restarting after a crash or timeout. In the
    /// batched phase a test's run number is its round; alone, `run_number`.
    fn runSequence(v: *Verify, w: u32, sequence: []const u32, phase: Phase, run_number: u32) void {
        var i: usize = 0;
        while (i < sequence.len) {
            _ = v.processes.fetchAdd(1, .monotonic);
            var why: Io.Writer.Allocating = .init(v.gpa);
            defer why.deinit();
            v.exec.vtable.start(v.exec.ptr, w, sequence[i..], &why.writer) catch |err| {
                while (i < sequence.len) : (i += 1) {
                    const msg: []u8 = std.fmt.allocPrint(v.gpa, "launcher: could not start the test process: {s}\n", .{
                        if (why.written().len != 0) why.written() else @errorName(err),
                    }) catch &.{};
                    v.record(v.positionOf(sequence[i]), phase, v.roundOf(phase, i, run_number), .{ .status = .launcher_error, .output = msg });
                }
                return;
            };
            while (i < sequence.len) {
                const t = sequence[i];
                const round = v.roundOf(phase, i, run_number);
                i += 1;
                const res = v.exec.vtable.run(v.exec.ptr, w, t) catch |err| sched.RunResult{
                    .status = .crash,
                    .output = std.fmt.allocPrint(v.gpa, "launcher: lost the test process: {t}\n", .{err}) catch &.{},
                };
                const dead = res.status.killsProcess();
                v.record(v.positionOf(t), phase, round, res);
                if (dead) break;
            }
            v.exec.vtable.stop(v.exec.ptr, w);
        }
    }

    fn roundOf(v: *const Verify, phase: Phase, i: usize, run_number: u32) u32 {
        return switch (phase) {
            .batched => @intCast(i / v.tests.len + 1),
            .alone => run_number,
        };
    }

    fn positionOf(v: *const Verify, t: u32) usize {
        return std.mem.indexOfScalar(u32, v.tests, t).?;
    }

    fn record(v: *Verify, position: usize, phase: Phase, round: u32, res: sched.RunResult) void {
        v.lock.lockUncancelable(v.io);
        defer v.lock.unlock(v.io);
        const o = &v.outcomes[position];
        const ok = res.status.ok();
        switch (phase) {
            .batched => {
                o.batched_runs += 1;
                o.batched_ok += @intFromBool(ok);
            },
            .alone => {
                o.alone_runs += 1;
                o.alone_ok += @intFromBool(ok);
            },
        }
        if (!ok and o.first_bad == null) {
            o.first_bad = .{ .phase = phase, .run = round, .status = res.status };
            o.output = res.output;
        } else v.gpa.free(res.output);
    }

    pub fn failures(v: *const Verify) u32 {
        var n: u32 = 0;
        for (v.outcomes) |o| n += @intFromBool(!o.passed(v.options));
        return n;
    }

    /// One line per test: "VERIFY PASS|FAIL <name>: batched a/b in one
    /// process, alone c/d", then for a failure its first bad run and the
    /// tail of what it printed.
    pub fn writeReport(v: *const Verify, w: *Io.Writer, names: []const []const u8) Io.Writer.Error!void {
        for (v.tests, v.outcomes) |t, o| {
            try w.print("VERIFY {s} {s}: batched {d}/{d} in one process, alone {d}/{d}\n", .{
                if (o.passed(v.options)) "PASS" else "FAIL", names[t], o.batched_ok, v.options.batched, o.alone_ok, v.options.alone,
            });
            if (o.first_bad) |bad| {
                try w.print("  first failure: {t} run {d}: {t}\n", .{ bad.phase, bad.run, bad.status });
                var lines = std.mem.splitBackwardsScalar(u8, std.mem.trimEnd(u8, o.output, "\n"), '\n');
                var tail: [30][]const u8 = undefined;
                var n: usize = 0;
                while (lines.next()) |line| : (n += 1) {
                    if (n == tail.len) break;
                    tail[n] = line;
                }
                while (n > 0) {
                    n -= 1;
                    try w.print("  | {s}\n", .{tail[n]});
                }
            }
        }
    }
};

// ---------------------------------------------------------------------------
// Tests, with a fake executor.

const testing = std.testing;

/// Test 0 passes; test 1 fails on its 3rd run in a process that has run it
/// before (it fails after itself); test 2 fails on its 7th run overall
/// (a 1-in-N flake); test 3 crashes the second time it runs alone (its
/// first run in a process is counted: the batched one, then each alone run).
const Fake = struct {
    gpa: Allocator,
    runs: [4]std.atomic.Value(u32) = @splat(.init(0)),
    alone_starts: [4]std.atomic.Value(u32) = @splat(.init(0)),
    /// Per worker: how often each test ran in its current process.
    in_process: [4][4]u32 = @splat(@splat(0)),
    starts: std.atomic.Value(u32) = .init(0),

    fn executor(f: *Fake) sched.Executor {
        return .{ .ptr = f, .vtable = &.{ .start = start, .run = run, .stop = stop } };
    }
    fn start(ptr: *anyopaque, w: u32, _: []const u32, _: *Io.Writer) anyerror!void {
        const f: *Fake = @ptrCast(@alignCast(ptr));
        _ = f.starts.fetchAdd(1, .monotonic);
        f.in_process[w] = @splat(0);
    }
    fn stop(_: *anyopaque, _: u32) void {}
    fn run(ptr: *anyopaque, w: u32, t: u32) anyerror!sched.RunResult {
        const f: *Fake = @ptrCast(@alignCast(ptr));
        const overall = f.runs[t].fetchAdd(1, .monotonic) + 1;
        f.in_process[w][t] += 1;
        const here = f.in_process[w][t];
        const status: sched.Status = switch (t) {
            1 => if (here == 3) .fail else .pass,
            2 => if (overall == 7) .fail else .pass,
            3 => if (here == 1 and f.alone_starts[3].fetchAdd(1, .monotonic) == 2) .crash else .pass,
            else => .pass,
        };
        const out: []u8 = if (status.ok()) &.{} else try std.fmt.allocPrint(f.gpa, "test {d} said no on run {d}\n", .{ t, overall });
        return .{ .status = status, .ns = 1, .output = out };
    }
};

test "verify: a test that passes every run passes; one that fails once in ten, or only after itself, fails, naming its first bad run" {
    var fake: Fake = .{ .gpa = testing.allocator };
    var v = try Verify.init(testing.allocator, testing.io, fake.executor(), &.{ 0, 1, 2 }, .{ .batched = 10, .alone = 5, .jobs = 1 });
    defer v.deinit();
    try v.execute();
    // Test 0: 10/10 batched, 5/5 alone.
    try testing.expect(v.outcomes[0].passed(v.options));
    try testing.expectEqual(@as(u32, 10), v.outcomes[0].batched_ok);
    try testing.expectEqual(@as(u32, 5), v.outcomes[0].alone_ok);
    // Test 1 fails its third run in the batched process - only after itself.
    try testing.expect(!v.outcomes[1].passed(v.options));
    try testing.expectEqual(Phase.batched, v.outcomes[1].first_bad.?.phase);
    try testing.expectEqual(@as(u32, 3), v.outcomes[1].first_bad.?.run);
    try testing.expectEqual(@as(u32, 5), v.outcomes[1].alone_ok);
    // Test 2's 7th run overall fails: batched round 7.
    try testing.expect(!v.outcomes[2].passed(v.options));
    try testing.expectEqual(@as(u32, 7), v.outcomes[2].first_bad.?.run);
    try testing.expectEqual(@as(u32, 2), v.failures());
    // One process for the batched phase, one per alone run.
    try testing.expectEqual(@as(u32, 1 + 3 * 5), v.processes.load(.monotonic));

    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    try v.writeReport(&out.writer, &.{ "a.test.zero", "a.test.one", "a.test.two" });
    const text = out.written();
    try testing.expect(std.mem.indexOf(u8, text, "VERIFY PASS a.test.zero: batched 10/10 in one process, alone 5/5") != null);
    try testing.expect(std.mem.indexOf(u8, text, "VERIFY FAIL a.test.one: batched 9/10 in one process, alone 5/5") != null);
    try testing.expect(std.mem.indexOf(u8, text, "first failure: batched run 3: fail") != null);
    try testing.expect(std.mem.indexOf(u8, text, "| test 1 said no on run 3") != null);
}

test "verify: a crash in an alone run fails the test and the next runs go on in new processes, several jobs at once" {
    var fake: Fake = .{ .gpa = testing.allocator };
    var v = try Verify.init(testing.allocator, testing.io, fake.executor(), &.{ 0, 3 }, .{ .batched = 2, .alone = 5, .jobs = 3 });
    defer v.deinit();
    try v.execute();
    try testing.expect(v.outcomes[0].passed(v.options));
    const o = v.outcomes[1];
    try testing.expect(!o.passed(v.options));
    try testing.expectEqual(sched.Status.crash, o.first_bad.?.status);
    try testing.expectEqual(@as(u32, 5), o.alone_runs);
    try testing.expectEqual(@as(u32, 4), o.alone_ok);
}

test "verify under ThreadSanitizer: once, in one process, no alone runs" {
    var fake: Fake = .{ .gpa = testing.allocator };
    var v = try Verify.init(testing.allocator, testing.io, fake.executor(), &.{ 0, 1 }, .{ .batched = 1, .alone = 0 });
    defer v.deinit();
    try v.execute();
    try testing.expectEqual(@as(u32, 0), v.failures());
    try testing.expectEqual(@as(u32, 1), v.processes.load(.monotonic));
    try testing.expectEqual(@as(u32, 1), v.outcomes[1].batched_runs);
}

test "real processes: verify mode catches the fixture's test that fails on its third run in a process, and passes a clean one" {
    // build.zig compiles tools/test_launcher/fixture_test.zig and passes its path.
    const fixture = @import("launcher_fixture");
    const child_mod = @import("child.zig");
    const gpa = testing.allocator;
    const io = testing.io;
    const argv = [_][]const u8{ fixture.path, "--listen=-", "--seed=0x1" };
    const md = try child_mod.queryMetadata(gpa, io, &argv);
    defer md.deinit(gpa);
    var selected: [2]u32 = undefined;
    for ([_][]const u8{ "test.passes", "test.fails on its third run in a process" }, &selected) |want, *index| {
        index.* = for (md.names, 0..) |n, i| {
            if (std.mem.endsWith(u8, n, want)) break @intCast(i);
        } else return error.FixtureTestMissing;
    }
    var exec = try child_mod.Executor.init(gpa, io, &argv, 30 * std.time.ns_per_s, 2);
    defer exec.deinit();
    var v = try Verify.init(gpa, io, exec.executor(), &selected, .{ .batched = 10, .alone = 5, .jobs = 2 });
    defer v.deinit();
    try v.execute();
    errdefer std.debug.print("{s}\n", .{v.outcomes[1].output});
    // The clean test: 10/10 in one process, 5/5 alone.
    try testing.expect(v.outcomes[0].passed(v.options));
    // The flake: passes alone every time, fails in round 3 of the batched run.
    const flaky = v.outcomes[1];
    try testing.expect(!flaky.passed(v.options));
    try testing.expectEqual(Phase.batched, flaky.first_bad.?.phase);
    try testing.expectEqual(@as(u32, 3), flaky.first_bad.?.run);
    try testing.expectEqual(@as(u32, 9), flaky.batched_ok);
    try testing.expectEqual(@as(u32, 5), flaky.alone_ok);
    try testing.expectEqual(@as(u32, 1), v.failures());
}
