//! The many-Browsers variant's neighbour: work that runs on a thread of its
//! own, beside every test of the process, in iterations - and that the
//! Crane test runner holds between two iterations while it reads the
//! process's state (state.zig), so the digest before and after each test
//! sees no neighbour mid-work.
//!
//! The approved test plan (tmp/plans/test-architecture-recommendation.md
//! section 4): "each suite also runs with a second, busy Browser on another
//! thread in the same process" - V8's `--isolates` variant, which runs each
//! mjsunit test in a second isolate on its own thread at the same time
//! (src/d8/d8.cc, `--isolate`; its own TSAN builder, "V8 Linux64 TSAN -
//! isolates"), and WebKit's DumpRenderTree `--threaded`, "run a concurrent
//! JavaScript thread with each test". Crane runs many Browsers on many
//! threads of one process (docs/instances.md), with no process boundary to
//! hide state two instances share: this is where that shows up, as a test's
//! failure, a failure of the busy Browser, or (with -Dsanitize-thread) a race.
//!
//! The work itself is busy_browser.zig (a Browser per iteration: page loads,
//! timers, DOM churn); this file is the thread and its handshake, std only,
//! and its own tests run with a fake work function (build.zig: the
//! `test_runner-neighbour` suite).
//!
//! The handshake: `hold` waits until the work is between iterations and
//! keeps the next one from starting; `release` lets it go on. An iteration
//! makes and ends everything it uses (its Browser among them), so while the
//! neighbour is held the process holds nothing of it - the state check
//! compares the process as it would without the variant. A failed iteration
//! is kept, with its error and what the work wrote about it, until the
//! runner takes it after the test it happened during.

const std = @import("std");
const Io = std.Io;

pub const Work = struct {
    ctx: ?*anyopaque = null,
    /// One iteration. On failure it returns the error, having written what
    /// went wrong to `why` (bounded: the rest is cut).
    iterate: *const fn (ctx: ?*anyopaque, why: *Io.Writer) anyerror!void,
};

/// A failed iteration, as the runner reports it.
pub const Failure = struct {
    err: anyerror,
    /// The iteration it happened in (from 1).
    iteration: u64,
    text: [1024]u8 = undefined,
    text_len: usize = 0,

    pub fn message(f: *const Failure) []const u8 {
        return f.text[0..f.text_len];
    }
};

pub const Neighbour = struct {
    io: Io,
    work: Work,
    mutex: Io.Mutex = .init,
    cond: Io.Condition = .init,
    hold_requested: bool = false,
    stop_requested: bool = false,
    in_iteration: bool = false,
    /// Iterations finished.
    iterations: u64 = 0,
    /// The first failure not yet taken.
    failure: ?Failure = null,
    /// Failures after the first one before it was taken (only counted).
    more_failures: u64 = 0,
    thread: ?std.Thread = null,
    /// The thread's id, for `isOwnThread` (0: none).
    thread_id: std.atomic.Value(std.Thread.Id) = .init(0),

    pub fn init(io: Io, work: Work) Neighbour {
        return .{ .io = io, .work = work };
    }

    /// Starts the thread. The neighbour must not move afterwards.
    pub fn start(n: *Neighbour) std.Thread.SpawnError!void {
        std.debug.assert(n.thread == null);
        n.thread = try std.Thread.spawn(.{}, loop, .{n});
    }

    pub fn running(n: *const Neighbour) bool {
        return n.thread != null;
    }

    /// Whether the caller is the neighbour's thread (its log lines are
    /// marked, and read no test's settings).
    pub fn isOwnThread(n: *const Neighbour) bool {
        const id = n.thread_id.load(.acquire);
        return id != 0 and id == std.Thread.getCurrentId();
    }

    fn loop(n: *Neighbour) void {
        n.thread_id.store(std.Thread.getCurrentId(), .release);
        while (true) {
            n.mutex.lockUncancelable(n.io);
            while (n.hold_requested and !n.stop_requested) n.cond.waitUncancelable(n.io, &n.mutex);
            if (n.stop_requested) {
                n.mutex.unlock(n.io);
                return;
            }
            n.in_iteration = true;
            const iteration = n.iterations + 1;
            n.mutex.unlock(n.io);

            var failure: Failure = .{ .err = error.None, .iteration = iteration };
            var why: Io.Writer = .fixed(&failure.text);
            const result = n.work.iterate(n.work.ctx, &why);
            failure.text_len = why.end;

            n.mutex.lockUncancelable(n.io);
            n.in_iteration = false;
            n.iterations = iteration;
            if (result) |_| {} else |err| {
                failure.err = err;
                if (n.failure == null) n.failure = failure else n.more_failures += 1;
            }
            n.cond.broadcast(n.io);
            n.mutex.unlock(n.io);
        }
    }

    /// Waits until the work is between iterations, and keeps it there until
    /// `release`. Nothing to do when the neighbour never started.
    pub fn hold(n: *Neighbour) void {
        if (n.thread == null) return;
        n.mutex.lockUncancelable(n.io);
        defer n.mutex.unlock(n.io);
        n.hold_requested = true;
        while (n.in_iteration) n.cond.waitUncancelable(n.io, &n.mutex);
    }

    pub fn release(n: *Neighbour) void {
        if (n.thread == null) return;
        n.mutex.lockUncancelable(n.io);
        defer n.mutex.unlock(n.io);
        n.hold_requested = false;
        n.cond.broadcast(n.io);
    }

    /// `hold`, as a dom.process_start.OverrideObserver's `first_made`: a
    /// test's first hook override holds the neighbour before the slot
    /// changes (`ctx` is the neighbour). An override is a statement about the
    /// whole process - the neighbour reads the same slot - so it waits, with
    /// nothing alive, until the override's restore: Chromium's
    /// ScopedFeatureList, the process-wide override held for its scope.
    pub fn holdFor(ctx: ?*anyopaque) void {
        const n: *Neighbour = @ptrCast(@alignCast(ctx.?));
        n.hold();
    }

    /// `release`, as the observer's `last_restored`: after the test's last
    /// restore the neighbour goes on.
    pub fn releaseFor(ctx: ?*anyopaque) void {
        const n: *Neighbour = @ptrCast(@alignCast(ctx.?));
        n.release();
    }

    pub const Taken = struct { failure: ?Failure, more_failures: u64, iterations: u64 };

    /// What has failed since the last take, and how many iterations have
    /// finished in all. Call while held.
    pub fn take(n: *Neighbour) Taken {
        n.mutex.lockUncancelable(n.io);
        defer n.mutex.unlock(n.io);
        const result: Taken = .{ .failure = n.failure, .more_failures = n.more_failures, .iterations = n.iterations };
        n.failure = null;
        n.more_failures = 0;
        return result;
    }

    /// Ends the thread after the iteration in progress (held or not).
    pub fn stop(n: *Neighbour) void {
        const thread = n.thread orelse return;
        n.mutex.lockUncancelable(n.io);
        n.stop_requested = true;
        n.cond.broadcast(n.io);
        n.mutex.unlock(n.io);
        thread.join();
        n.thread = null;
    }
};

// ---------------------------------------------------------------------------
// Tests, with a fake work function.

const testing = std.testing;

const Fake = struct {
    /// Iterations started, and whether one is running now: read by the test
    /// thread while the neighbour writes them.
    started: std.atomic.Value(u64) = .init(0),
    active: std.atomic.Value(bool) = .init(false),
    /// Iterations that fail (by number, from 1).
    fail_at: []const u64 = &.{},
    io: Io,

    fn work(f: *Fake) Work {
        return .{ .ctx = f, .iterate = iterate };
    }

    fn iterate(ctx: ?*anyopaque, why: *Io.Writer) anyerror!void {
        const f: *Fake = @ptrCast(@alignCast(ctx.?));
        const k = f.started.fetchAdd(1, .seq_cst) + 1;
        f.active.store(true, .seq_cst);
        defer f.active.store(false, .seq_cst);
        f.io.sleep(.fromMilliseconds(5), .awake) catch {};
        for (f.fail_at) |bad| if (bad == k) {
            why.print("iteration {d} said no", .{k}) catch {};
            return error.FakeFailed;
        };
    }
};

fn waitFor(io: Io, value: *const std.atomic.Value(u64), at_least: u64) !void {
    var tries: u32 = 0;
    while (value.load(.seq_cst) < at_least) : (tries += 1) {
        if (tries > 5000) return error.NeighbourNeverRan;
        io.sleep(.fromMilliseconds(1), .awake) catch {};
    }
}

test "the work runs between holds; a hold waits for the iteration in progress and keeps the next from starting" {
    const io = testing.io;
    var fake: Fake = .{ .io = io };
    var n: Neighbour = .init(io, fake.work());
    try n.start();
    defer n.stop();
    try waitFor(io, &fake.started, 3);
    try testing.expect(!n.isOwnThread());

    n.hold();
    try testing.expect(!fake.active.load(.seq_cst));
    const held_at = fake.started.load(.seq_cst);
    io.sleep(.fromMilliseconds(40), .awake) catch {};
    // Nothing started while held, and nothing is running.
    try testing.expectEqual(held_at, fake.started.load(.seq_cst));
    try testing.expect(!fake.active.load(.seq_cst));
    try testing.expectEqual(held_at, n.take().iterations);
    n.release();

    try waitFor(io, &fake.started, held_at + 2);
}

test "a hook override's observer pauses the work until the restore, then it goes on" {
    // What dom.process_start calls (hook.zig pins the order: first_made
    // before the override's write, last_restored after the restore's).
    const io = testing.io;
    var fake: Fake = .{ .io = io };
    var n: Neighbour = .init(io, fake.work());
    try n.start();
    defer n.stop();
    try waitFor(io, &fake.started, 2);

    Neighbour.holdFor(&n); // the test's first override
    try testing.expect(!fake.active.load(.seq_cst));
    const paused_at = fake.started.load(.seq_cst);
    io.sleep(.fromMilliseconds(40), .awake) catch {};
    // While the override is outstanding no iteration starts or runs.
    try testing.expectEqual(paused_at, fake.started.load(.seq_cst));
    try testing.expect(!fake.active.load(.seq_cst));
    Neighbour.releaseFor(&n); // its restore

    try waitFor(io, &fake.started, paused_at + 2);
}

test "a failed iteration is kept, with its error, number and message, until it is taken" {
    const io = testing.io;
    var fake: Fake = .{ .io = io, .fail_at = &.{ 2, 4 } };
    var n: Neighbour = .init(io, fake.work());
    try n.start();
    defer n.stop();
    try waitFor(io, &fake.started, 6);
    n.hold();
    defer n.release();
    const got = n.take();
    const failure = got.failure orelse return error.NoFailureKept;
    try testing.expectEqual(error.FakeFailed, failure.err);
    try testing.expectEqual(@as(u64, 2), failure.iteration);
    try testing.expectEqualStrings("iteration 2 said no", failure.message());
    try testing.expectEqual(@as(u64, 1), got.more_failures);
    // Taken: the next take has none.
    try testing.expect(n.take().failure == null);
}

test "stop ends the thread while it is held, and a neighbour never started holds and stops as a no-op" {
    const io = testing.io;
    var fake: Fake = .{ .io = io };
    var n: Neighbour = .init(io, fake.work());
    try n.start();
    try waitFor(io, &fake.started, 1);
    n.hold();
    n.stop();
    try testing.expect(!n.running());

    var idle: Neighbour = .init(io, fake.work());
    idle.hold();
    idle.release();
    idle.stop();
    try testing.expect(!idle.running());
}
