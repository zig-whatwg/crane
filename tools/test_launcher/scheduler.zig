//! Runs a plan's batches on N workers and classifies every failure.
//!
//! Phase 1 (the run): each worker claims the next batch, starts a child
//! process, and runs the batch's tests in order. A crash or a timeout kills
//! the process; the test that was running is blamed, a new process starts,
//! and the batch continues with the next test - what Zig's build runner does
//! (compiler/Maker/Step/Run.zig evalZigTest: "Report it against that test,
//! and continue to the next test"), and what Chromium's launcher and WebKit's
//! api-tests runner do after a crash.
//!
//! Phase 2 (classification): every test that did not pass is re-run ALONE,
//! in a fresh process, `alone_runs` times, with the same seed (V8's
//! run-tests.py reruns with the same seed; Chromium retries serially with
//! batch size 1). Then:
//!   - every alone run fails:                  FAIL
//!   - the alone runs disagree:                FLAKY
//!   - every alone run passes: the batch's prefix up to the test is replayed
//!     in one fresh process, same order -
//!       it fails again:                       ORDER-DEPENDENT (batch + seed)
//!       it passes:                            FLAKY
//! None of the three counts as a pass (Crane's one-flake-then-bug rule;
//! Gecko's retries, which absorb flakes, are the cautionary case).
//!
//! The process work goes through `Executor`, so the scheduling, the restart
//! and the classification are tested here with a fake one.

const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const plan_mod = @import("plan.zig");
const Plan = plan_mod.Plan;

/// What one run of one test came to. `crash` and `timeout` mean the process
/// is gone.
pub const Status = enum {
    pass,
    skip,
    fail,
    crash,
    timeout,
    /// Passed, but std.testing.allocator reported leaks (the build runner
    /// fails these too).
    leak,
    /// Passed, but logged errors (the build runner fails these too).
    log_err,

    pub fn ok(s: Status) bool {
        return s == .pass or s == .skip;
    }

    pub fn killsProcess(s: Status) bool {
        return s == .crash or s == .timeout;
    }
};

pub const RunResult = struct {
    status: Status,
    ns: u64 = 0,
    /// The test's stderr (or the crash report), allocated with the
    /// scheduler's `gpa`; the scheduler frees it.
    output: []u8 = &.{},
};

pub const Verdict = enum {
    pass,
    skip,
    fail,
    order_dependent,
    flaky,
    /// Never ran (the launcher was stopped).
    not_run,

    pub fn label(v: Verdict) []const u8 {
        return switch (v) {
            .pass => "PASS",
            .skip => "SKIP",
            .fail => "FAIL",
            .order_dependent => "ORDER-DEPENDENT",
            .flaky => "FLAKY",
            .not_run => "NOT-RUN",
        };
    }

    pub fn ok(v: Verdict) bool {
        return v == .pass or v == .skip;
    }
};

pub const max_alone_runs = 8;

/// The classification rule, on its own so it can be pinned.
/// `replay` is null when there was nothing before the test in its batch.
pub fn classify(first: Status, alone: []const Status, replay: ?Status) Verdict {
    if (first == .pass) return .pass;
    if (first == .skip) return .skip;
    if (alone.len == 0) return .fail;
    var bad: usize = 0;
    for (alone) |s| {
        if (!s.ok()) bad += 1;
    }
    if (bad == alone.len) return .fail;
    if (bad != 0) return .flaky;
    // Passes every time alone.
    const r = replay orelse return .flaky;
    return if (r.ok()) .flaky else .order_dependent;
}

/// The process side. `run` runs one test in the worker's current process;
/// after a `crash` or `timeout` the process is gone and `start` must be
/// called again. Every function is called only from its worker's thread.
pub const Executor = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        start: *const fn (ptr: *anyopaque, worker: u32) anyerror!void,
        run: *const fn (ptr: *anyopaque, worker: u32, test_index: u32) anyerror!RunResult,
        stop: *const fn (ptr: *anyopaque, worker: u32) void,
    };

    fn start(e: Executor, w: u32) anyerror!void {
        return e.vtable.start(e.ptr, w);
    }
    fn run(e: Executor, w: u32, t: u32) anyerror!RunResult {
        return e.vtable.run(e.ptr, w, t);
    }
    fn stop(e: Executor, w: u32) void {
        e.vtable.stop(e.ptr, w);
    }
};

pub const TestRecord = struct {
    /// The test's batch and its position in it (from the plan).
    batch: u32 = 0,
    position: u32 = 0,
    first: Status = .pass,
    ran: bool = false,
    ns: u64 = 0,
    output: []u8 = &.{},
    alone: [max_alone_runs]Status = undefined,
    alone_len: u8 = 0,
    replay: ?Status = null,
    verdict: Verdict = .not_run,

    pub fn aloneRuns(r: *const TestRecord) []const Status {
        return r.alone[0..r.alone_len];
    }
};

pub const Options = struct {
    jobs: u32 = 1,
    alone_runs: u8 = 2,
    /// Called (under a lock) as each test's verdict becomes known, for
    /// progress output. Optional.
    on_verdict: ?*const fn (ctx: ?*anyopaque, test_index: u32, record: *const TestRecord) void = null,
    on_verdict_ctx: ?*anyopaque = null,
    /// Called (under a lock) after each batch of phase 1 with the number of
    /// batches done and the total. Optional.
    on_progress: ?*const fn (ctx: ?*anyopaque, done: u32, total: u32) void = null,
    /// Run only this batch of the plan (to replay an ORDER-DEPENDENT report).
    only_batch: ?u32 = null,
};

/// The run's state: one record per test index of the binary (tests the
/// plan does not select stay `not_run`).
pub const Run = struct {
    gpa: Allocator,
    io: Io,
    plan: *const Plan,
    exec: Executor,
    options: Options,
    records: []TestRecord,
    next_batch: std.atomic.Value(u32) = .init(0),
    done_batches: std.atomic.Value(u32) = .init(0),
    next_suspect: std.atomic.Value(u32) = .init(0),
    suspects: std.ArrayList(u32) = .empty,
    /// Child processes started (each `start`).
    processes: std.atomic.Value(u32) = .init(0),
    lock: Io.Mutex = .init,

    pub fn init(gpa: Allocator, io: Io, plan: *const Plan, test_count: usize, exec: Executor, options: Options) !Run {
        const records = try gpa.alloc(TestRecord, test_count);
        for (records) |*r| r.* = .{};
        for (0..plan.batches.len) |b| {
            for (plan.batchTests(b), 0..) |t, pos| {
                records[t].batch = @intCast(b);
                records[t].position = @intCast(pos);
            }
        }
        return .{ .gpa = gpa, .io = io, .plan = plan, .exec = exec, .options = options, .records = records };
    }

    pub fn deinit(r: *Run) void {
        for (r.records) |rec| r.gpa.free(rec.output);
        r.gpa.free(r.records);
        r.suspects.deinit(r.gpa);
    }

    /// The batches this run covers.
    pub fn batchCount(r: *const Run) u32 {
        if (r.options.only_batch != null) return 1;
        return @intCast(r.plan.batches.len);
    }

    pub fn batchId(r: *const Run, k: u32) u32 {
        return r.options.only_batch orelse k;
    }

    /// Both phases. Returns when every selected test has a verdict.
    pub fn execute(r: *Run) !void {
        if (r.options.only_batch) |b| {
            if (b >= r.plan.batches.len) return error.NoSuchBatch;
        }
        try r.parallel(phase1Worker);
        for (0..r.batchCount()) |k| {
            for (r.plan.batchTests(r.batchId(@intCast(k)))) |t| {
                const rec = &r.records[t];
                if (!rec.ran) continue;
                if (rec.first.ok()) {
                    rec.verdict = classify(rec.first, &.{}, null);
                    r.report(t);
                } else try r.suspects.append(r.gpa, t);
            }
        }
        try r.parallel(phase2Worker);
    }

    fn parallel(r: *Run, comptime worker: fn (*Run, u32) Io.Cancelable!void) !void {
        const jobs = @max(r.options.jobs, 1);
        if (jobs == 1) return worker(r, 0);
        var group: Io.Group = .init;
        defer group.cancel(r.io);
        for (0..jobs) |w| {
            group.concurrent(r.io, worker, .{ r, @as(u32, @intCast(w)) }) catch |err| switch (err) {
                // No threads to run it on: run it here, after the others.
                error.ConcurrencyUnavailable => try worker(r, @intCast(w)),
            };
        }
        try group.await(r.io);
    }

    fn report(r: *Run, t: u32) void {
        const cb = r.options.on_verdict orelse return;
        r.lock.lockUncancelable(r.io);
        defer r.lock.unlock(r.io);
        cb(r.options.on_verdict_ctx, t, &r.records[t]);
    }

    fn startProcess(r: *Run, w: u32) !void {
        _ = r.processes.fetchAdd(1, .monotonic);
        try r.exec.start(w);
    }

    /// Runs `tests` in order in fresh processes, restarting after a crash or
    /// timeout, and hands each result to `sink`. A failed start blames every
    /// test still to run.
    fn runSequence(r: *Run, w: u32, tests: []const u32, sink: anytype) void {
        var i: usize = 0;
        while (i < tests.len) {
            r.startProcess(w) catch |err| {
                while (i < tests.len) : (i += 1) {
                    const msg: []u8 = std.fmt.allocPrint(r.gpa, "launcher: could not start the test process: {t}\n", .{err}) catch &.{};
                    sink.take(tests[i], .{ .status = .crash, .output = msg });
                }
                return;
            };
            while (i < tests.len) {
                const t = tests[i];
                i += 1;
                const res = r.exec.run(w, t) catch |err| RunResult{
                    .status = .crash,
                    .output = std.fmt.allocPrint(r.gpa, "launcher: lost the test process: {t}\n", .{err}) catch &.{},
                };
                const dead = res.status.killsProcess();
                sink.take(t, res);
                if (dead) break;
            }
            r.exec.stop(w);
        }
    }

    fn phase1Worker(r: *Run, w: u32) Io.Cancelable!void {
        const Sink = struct {
            run: *Run,
            fn take(s: @This(), t: u32, res: RunResult) void {
                const rec = &s.run.records[t];
                rec.ran = true;
                rec.first = res.status;
                rec.ns = res.ns;
                rec.output = res.output;
            }
        };
        const total = r.batchCount();
        while (true) {
            const k = r.next_batch.fetchAdd(1, .monotonic);
            if (k >= total) return;
            r.runSequence(w, r.plan.batchTests(r.batchId(k)), Sink{ .run = r });
            const done = r.done_batches.fetchAdd(1, .monotonic) + 1;
            if (r.options.on_progress) |cb| {
                r.lock.lockUncancelable(r.io);
                defer r.lock.unlock(r.io);
                cb(r.options.on_verdict_ctx, done, total);
            }
        }
    }

    fn phase2Worker(r: *Run, w: u32) Io.Cancelable!void {
        while (true) {
            const k = r.next_suspect.fetchAdd(1, .monotonic);
            if (k >= r.suspects.items.len) return;
            const t = r.suspects.items[k];
            r.classifyOne(w, t);
            r.report(t);
        }
    }

    /// Re-runs one failed test alone, then (if it always passes alone) its
    /// batch's prefix, and records the verdict.
    fn classifyOne(r: *Run, w: u32, t: u32) void {
        const rec = &r.records[t];
        const Collect = struct {
            run: *Run,
            target: u32,
            out: *?Status,
            fn take(s: @This(), test_index: u32, res: RunResult) void {
                s.run.gpa.free(res.output);
                if (test_index == s.target) s.out.* = res.status;
            }
        };
        const runs = @min(r.options.alone_runs, max_alone_runs);
        for (0..runs) |_| {
            var got: ?Status = null;
            r.runSequence(w, &.{t}, Collect{ .run = r, .target = t, .out = &got });
            rec.alone[rec.alone_len] = got orelse .crash;
            rec.alone_len += 1;
        }
        var all_pass = rec.alone_len > 0;
        for (rec.aloneRuns()) |s| {
            if (!s.ok()) all_pass = false;
        }
        if (all_pass and rec.position > 0) {
            const prefix = r.plan.batchTests(rec.batch)[0 .. rec.position + 1];
            var got: ?Status = null;
            r.runSequence(w, prefix, Collect{ .run = r, .target = t, .out = &got });
            rec.replay = got orelse .crash;
        }
        rec.verdict = classify(rec.first, rec.aloneRuns(), rec.replay);
    }

    pub const Counts = struct {
        pass: u32 = 0,
        skip: u32 = 0,
        fail: u32 = 0,
        order_dependent: u32 = 0,
        flaky: u32 = 0,
        not_run: u32 = 0,

        pub fn bad(c: Counts) u32 {
            return c.fail + c.order_dependent + c.flaky + c.not_run;
        }
    };

    pub fn counts(r: *const Run) Counts {
        var c: Counts = .{};
        for (0..r.batchCount()) |k| for (r.plan.batchTests(r.batchId(@intCast(k)))) |t| switch (r.records[t].verdict) {
            .pass => c.pass += 1,
            .skip => c.skip += 1,
            .fail => c.fail += 1,
            .order_dependent => c.order_dependent += 1,
            .flaky => c.flaky += 1,
            .not_run => c.not_run += 1,
        };
        return c;
    }
};

// ---------------------------------------------------------------------------
// Tests, with a fake executor.

const testing = std.testing;

test "classify: the rule" {
    try testing.expectEqual(Verdict.pass, classify(.pass, &.{}, null));
    try testing.expectEqual(Verdict.skip, classify(.skip, &.{}, null));
    // Fails alone every time.
    try testing.expectEqual(Verdict.fail, classify(.fail, &.{ .fail, .fail }, null));
    try testing.expectEqual(Verdict.fail, classify(.crash, &.{ .crash, .fail }, .crash));
    try testing.expectEqual(Verdict.fail, classify(.leak, &.{ .leak, .leak }, null));
    // Alone runs disagree.
    try testing.expectEqual(Verdict.flaky, classify(.fail, &.{ .pass, .fail }, null));
    try testing.expectEqual(Verdict.flaky, classify(.timeout, &.{ .timeout, .pass }, .pass));
    // Passes alone, fails again after its batch's prefix.
    try testing.expectEqual(Verdict.order_dependent, classify(.fail, &.{ .pass, .pass }, .fail));
    try testing.expectEqual(Verdict.order_dependent, classify(.crash, &.{ .pass, .pass }, .crash));
    // Passes alone and after the prefix: it failed once and nothing reproduces it.
    try testing.expectEqual(Verdict.flaky, classify(.fail, &.{ .pass, .pass }, .pass));
    // First in its batch (nothing to replay) and passes alone.
    try testing.expectEqual(Verdict.flaky, classify(.fail, &.{.pass}, null));
    // No alone runs requested: a failure stands.
    try testing.expectEqual(Verdict.fail, classify(.fail, &.{}, null));
}

test "classify: none of FAIL, ORDER-DEPENDENT, FLAKY is ok" {
    try testing.expect(!Verdict.fail.ok());
    try testing.expect(!Verdict.order_dependent.ok());
    try testing.expect(!Verdict.flaky.ok());
    try testing.expect(!Verdict.not_run.ok());
    try testing.expect(Verdict.pass.ok());
}

/// A fake process: each worker's "process" remembers the tests it ran; a
/// behaviour function decides each result from the test, that history and
/// how many times the test has run in all.
const Fake = struct {
    gpa: Allocator,
    behaviour: *const fn (f: *Fake, t: u32, history: []const u32, attempt: u32) Status,
    history: [8]std.ArrayList(u32) = @splat(.empty),
    alive: [8]bool = @splat(false),
    attempts: [64]std.atomic.Value(u32) = @splat(.init(0)),
    starts: std.atomic.Value(u32) = .init(0),
    /// Every (worker, test) run, for the order checks.
    log: std.ArrayList(u32) = .empty,
    log_lock: std.atomic.Mutex = .unlocked,

    fn executor(f: *Fake) Executor {
        return .{ .ptr = f, .vtable = &.{ .start = start, .run = run, .stop = stop } };
    }
    fn deinit(f: *Fake) void {
        for (&f.history) |*h| h.deinit(f.gpa);
        f.log.deinit(f.gpa);
    }
    fn start(ptr: *anyopaque, w: u32) anyerror!void {
        const f: *Fake = @ptrCast(@alignCast(ptr));
        std.debug.assert(!f.alive[w]);
        f.alive[w] = true;
        f.history[w].clearRetainingCapacity();
        _ = f.starts.fetchAdd(1, .monotonic);
    }
    fn run(ptr: *anyopaque, w: u32, t: u32) anyerror!RunResult {
        const f: *Fake = @ptrCast(@alignCast(ptr));
        std.debug.assert(f.alive[w]);
        const attempt = f.attempts[t].fetchAdd(1, .monotonic);
        const s = f.behaviour(f, t, f.history[w].items, attempt);
        try f.history[w].append(f.gpa, t);
        while (!f.log_lock.tryLock()) {}
        defer f.log_lock.unlock();
        try f.log.append(f.gpa, t);
        if (s.killsProcess()) f.alive[w] = false;
        const out: []u8 = if (s.ok()) &.{} else try std.fmt.allocPrint(f.gpa, "test {d} said no\n", .{t});
        return .{ .status = s, .ns = 1000, .output = out };
    }
    fn stop(ptr: *anyopaque, w: u32) void {
        const f: *Fake = @ptrCast(@alignCast(ptr));
        f.alive[w] = false;
    }
};

fn iota(buf: []u32) []u32 {
    for (buf, 0..) |*x, i| x.* = @intCast(i);
    return buf;
}

const Harness = struct {
    plan: Plan,
    fake: *Fake,
    run: Run,

    fn init(h: *Harness, behaviour: *const fn (*Fake, u32, []const u32, u32) Status, n: usize, plan_options: plan_mod.Options, options: Options) !void {
        var buf: [64]u32 = undefined;
        h.plan = try plan_mod.make(testing.allocator, iota(buf[0..n]), plan_options);
        h.fake = try testing.allocator.create(Fake);
        h.fake.* = .{ .gpa = testing.allocator, .behaviour = behaviour };
        h.run = try Run.init(testing.allocator, testing.io, &h.plan, n, h.fake.executor(), options);
    }
    fn deinit(h: *Harness) void {
        h.run.deinit();
        h.fake.deinit();
        testing.allocator.destroy(h.fake);
        h.plan.deinit(testing.allocator);
    }
};

fn allPass(_: *Fake, _: u32, _: []const u32, _: u32) Status {
    return .pass;
}

test "every test runs once, in its batch's order, one process per batch" {
    var h: Harness = undefined;
    try h.init(allPass, 23, .{ .seed = 7, .batch_size = 5 }, .{ .jobs = 1 });
    defer h.deinit();
    try h.run.execute();
    try testing.expectEqualSlices(u32, h.plan.order, h.fake.log.items);
    try testing.expectEqual(@as(u32, 5), h.fake.starts.load(.monotonic));
    const c = h.run.counts();
    try testing.expectEqual(@as(u32, 23), c.pass);
    try testing.expectEqual(@as(u32, 0), c.bad());
}

test "several workers: every test still runs exactly once" {
    var h: Harness = undefined;
    try h.init(allPass, 40, .{ .seed = 11, .batch_size = 3 }, .{ .jobs = 4 });
    defer h.deinit();
    try h.run.execute();
    try testing.expectEqual(@as(usize, 40), h.fake.log.items.len);
    for (0..40) |t| try testing.expectEqual(@as(u32, 1), h.fake.attempts[t].load(.monotonic));
    try testing.expectEqual(@as(u32, 40), h.run.counts().pass);
}

fn crashesOnThree(_: *Fake, t: u32, _: []const u32, _: u32) Status {
    return if (t == 3) .crash else .pass;
}

test "a crash is blamed on its test, a new process starts, and the batch goes on" {
    var h: Harness = undefined;
    // No shuffle, one batch: 0 1 2 3 4 5.
    try h.init(crashesOnThree, 6, .{ .seed = 1, .shuffle = false, .batch_size = 0 }, .{ .jobs = 1, .alone_runs = 2 });
    defer h.deinit();
    try h.run.execute();
    // 0..5 in the first pass, then 3 twice alone.
    try testing.expectEqualSlices(u32, &.{ 0, 1, 2, 3, 4, 5, 3, 3 }, h.fake.log.items);
    // Batch process, its restart after the crash, two alone processes.
    try testing.expectEqual(@as(u32, 4), h.fake.starts.load(.monotonic));
    try testing.expectEqual(Status.crash, h.run.records[3].first);
    try testing.expectEqual(Verdict.fail, h.run.records[3].verdict);
    try testing.expectEqual(Verdict.pass, h.run.records[4].verdict);
    try testing.expectEqual(@as(u32, 1), h.run.counts().fail);
}

fn timesOutOnZero(_: *Fake, t: u32, _: []const u32, _: u32) Status {
    return if (t == 0) .timeout else .pass;
}

test "a timeout is blamed like a crash" {
    var h: Harness = undefined;
    try h.init(timesOutOnZero, 3, .{ .seed = 1, .shuffle = false, .batch_size = 0 }, .{ .jobs = 1, .alone_runs = 1 });
    defer h.deinit();
    try h.run.execute();
    try testing.expectEqual(Status.timeout, h.run.records[0].first);
    try testing.expectEqual(Verdict.fail, h.run.records[0].verdict);
    try testing.expectEqual(Verdict.pass, h.run.records[1].verdict);
    try testing.expectEqual(Verdict.pass, h.run.records[2].verdict);
}

/// Test 4 fails when test 1 ran before it in the same process.
fn fourNeedsAFreshProcess(_: *Fake, t: u32, history: []const u32, _: u32) Status {
    if (t != 4) return .pass;
    return if (std.mem.indexOfScalar(u32, history, 1) != null) .fail else .pass;
}

test "fails after a batch-mate, passes alone: ORDER-DEPENDENT, with its batch" {
    var h: Harness = undefined;
    try h.init(fourNeedsAFreshProcess, 6, .{ .seed = 1, .shuffle = false, .batch_size = 0 }, .{ .jobs = 1, .alone_runs = 2 });
    defer h.deinit();
    try h.run.execute();
    const rec = h.run.records[4];
    try testing.expectEqual(Verdict.order_dependent, rec.verdict);
    try testing.expectEqualSlices(Status, &.{ .pass, .pass }, rec.aloneRuns());
    try testing.expectEqual(@as(?Status, .fail), rec.replay);
    try testing.expectEqual(@as(u32, 0), rec.batch);
    try testing.expectEqual(@as(u32, 4), rec.position);
    try testing.expectEqual(@as(u32, 1), h.run.counts().order_dependent);
    try testing.expectEqual(@as(u32, 5), h.run.counts().pass);
}

test "the same order dependence is invisible at batch size 1" {
    var h: Harness = undefined;
    try h.init(fourNeedsAFreshProcess, 6, .{ .seed = 1, .shuffle = false, .batch_size = 1 }, .{ .jobs = 2 });
    defer h.deinit();
    try h.run.execute();
    try testing.expectEqual(@as(u32, 6), h.run.counts().pass);
}

/// Test 2 fails on its first run only.
fn twoFailsOnce(_: *Fake, t: u32, _: []const u32, attempt: u32) Status {
    return if (t == 2 and attempt == 0) .fail else .pass;
}

test "fails once, passes alone and after its prefix: FLAKY" {
    var h: Harness = undefined;
    try h.init(twoFailsOnce, 5, .{ .seed = 1, .shuffle = false, .batch_size = 0 }, .{ .jobs = 1, .alone_runs = 2 });
    defer h.deinit();
    try h.run.execute();
    const rec = h.run.records[2];
    try testing.expectEqual(Verdict.flaky, rec.verdict);
    try testing.expectEqual(@as(?Status, .pass), rec.replay);
}

/// Test 0 fails on every even attempt.
fn zeroAlternates(_: *Fake, t: u32, _: []const u32, attempt: u32) Status {
    return if (t == 0 and attempt % 2 == 0) .fail else .pass;
}

test "alone runs that disagree: FLAKY, with no prefix replay" {
    var h: Harness = undefined;
    try h.init(zeroAlternates, 3, .{ .seed = 1, .shuffle = false, .batch_size = 0 }, .{ .jobs = 1, .alone_runs = 2 });
    defer h.deinit();
    try h.run.execute();
    const rec = h.run.records[0];
    try testing.expectEqual(Verdict.flaky, rec.verdict);
    try testing.expectEqualSlices(Status, &.{ .pass, .fail }, rec.aloneRuns());
    try testing.expectEqual(@as(?Status, null), rec.replay);
}

fn leaksOnOne(_: *Fake, t: u32, _: []const u32, _: u32) Status {
    return if (t == 1) .leak else .pass;
}

test "a leak fails the test, and does not kill its process" {
    var h: Harness = undefined;
    try h.init(leaksOnOne, 3, .{ .seed = 1, .shuffle = false, .batch_size = 0 }, .{ .jobs = 1, .alone_runs = 1 });
    defer h.deinit();
    try h.run.execute();
    try testing.expectEqual(Verdict.fail, h.run.records[1].verdict);
    // The batch process plus one alone run: no restart for a leak.
    try testing.expectEqual(@as(u32, 2), h.fake.starts.load(.monotonic));
}

test "the same seed classifies the same way at any job count" {
    var verdicts: [2][12]Verdict = undefined;
    for ([_]u32{ 1, 3 }, 0..) |jobs, k| {
        var h: Harness = undefined;
        try h.init(fourNeedsAFreshProcess, 12, .{ .seed = 0xABC, .batch_size = 4 }, .{ .jobs = jobs, .alone_runs = 2 });
        defer h.deinit();
        try h.run.execute();
        for (0..12) |t| verdicts[k][t] = h.run.records[t].verdict;
    }
    try testing.expectEqualSlices(Verdict, &verdicts[0], &verdicts[1]);
}

test "only one batch: replays that batch alone, with its own numbering" {
    var h: Harness = undefined;
    try h.init(fourNeedsAFreshProcess, 6, .{ .seed = 1, .shuffle = false, .batch_size = 3 }, .{ .jobs = 1, .only_batch = 1 });
    defer h.deinit();
    try h.run.execute();
    // Batch 1 is tests 3 4 5: 4 runs without 1 before it.
    try testing.expectEqualSlices(u32, &.{ 3, 4, 5 }, h.fake.log.items);
    try testing.expectEqual(@as(u32, 3), h.run.counts().pass);
    try testing.expectEqual(@as(u32, 1), h.run.records[4].batch);
    try testing.expectEqual(Verdict.not_run, h.run.records[0].verdict);
}
