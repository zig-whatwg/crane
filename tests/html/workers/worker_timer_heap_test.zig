//! A worker's event loop after a burst of timers (lane timerheap1): each
//! worker thread's loop has a timer manager of its own
//! (WorkerEventLoop.timers), and every turn asks it for the next deadline
//! (waitBound) and polls it. The manager found what was due by walking its
//! whole id table, which keeps the capacity its biggest moment needed - so a
//! worker that once held 5,000 timers walked 8,192 slots a turn for the rest
//! of its life.
//!
//! The loop here is a real worker thread's (html.WorkerThread), run by a
//! host that makes no realm: its timers are native callbacks armed through
//! the loop's TimerInterface, as the worker host arms them. Measured with
//! the manager's test-build probe (runtime.native_timer.Probe). tests/html
//! is one executable: the thread this starts is joined before the test
//! returns.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const html = @import("html");
const WorkerLink = html.WorkerLink;
const WorkerThread = html.WorkerThread;
const TaskSink = runtime.TaskSink;
const NativeTimerManager = runtime.native_timer.NativeTimerManager;

const allocator = testing.allocator;

/// Short timers run before the burst, and after it.
const before_count = 1_000;
const after_count = 10_000;
const burst_count = 5_000;

fn noop(_: ?*anyopaque) void {}

/// The worker's part: a chain of 0 ms timers, each armed by the one before
/// as setTimeout(f, 0) chains are, with a burst of 5,000 armed and cleared
/// between the two halves. Read by the test once the thread is joined.
const ChainHost = struct {
    timers: ?*NativeTimerManager = null,
    timer: ?runtime.TimerInterface = null,
    link: ?*WorkerLink = null,
    ran: usize = 0,
    /// The probe at the start, either side of the burst, and at the end.
    start: Mark = .{},
    burst_start: Mark = .{},
    burst_end: Mark = .{},
    end: Mark = .{},
    failed: bool = false,

    const Mark = struct { slots: u64 = 0, polls: u64 = 0 };

    fn host(self: *ChainHost) WorkerThread.Host {
        return .{ .data = self, .start = startOnThread, .end_realm = endRealm, .free = free };
    }

    fn mark(self: *ChainHost) Mark {
        const probe = self.timers.?.probe;
        return .{ .slots = probe.slots, .polls = probe.polls };
    }

    fn startOnThread(data: ?*anyopaque, thread: *WorkerThread) bool {
        const self: *ChainHost = @ptrCast(@alignCast(data.?));
        self.timers = thread.loop.timers;
        self.timer = thread.loop.timerInterface();
        self.link = thread.link;
        // A long-lived interval's next run, live across everything below.
        if (self.timer.?.setTimeout(3_600_000, noop, null) == 0) return false;
        self.start = self.mark();
        return self.timer.?.setTimeout(0, step, self) != 0;
    }

    fn step(data: ?*anyopaque) void {
        const self: *ChainHost = @ptrCast(@alignCast(data.?));
        const timer = self.timer.?;
        self.ran += 1;
        if (self.ran == before_count) {
            // The burst: armed at once, then cleared before any is due.
            self.burst_start = self.mark();
            var ids: [burst_count]runtime.TimerId = undefined;
            for (&ids) |*id| {
                id.* = timer.setTimeout(60_000, noop, null);
                if (id.* == 0) self.failed = true;
            }
            for (ids) |id| if (!timer.clearTimeout(id)) {
                self.failed = true;
            };
            self.burst_end = self.mark();
        }
        if (self.ran == before_count + after_count) {
            self.end = self.mark();
            _ = self.link.?.requestClose();
            self.link.?.wake();
            return;
        }
        if (timer.setTimeout(0, step, self) == 0) {
            self.failed = true;
            _ = self.link.?.requestClose();
        }
    }

    fn endRealm(_: ?*anyopaque, _: *WorkerThread) void {}
    fn free(_: ?*anyopaque) void {}
};

const Owner = struct {
    ended: std.atomic.Value(bool) = .init(false),

    fn owner(self: *Owner) WorkerThread.Owner {
        return .{ .data = self, .ended = onEnded, .drop = onDrop };
    }

    fn onEnded(data: ?*anyopaque, link: *WorkerLink) void {
        const self: *Owner = @ptrCast(@alignCast(data.?));
        link.join();
        self.ended.store(true, .release);
    }

    fn onDrop(_: ?*anyopaque, link: *WorkerLink) void {
        link.join();
    }
};

/// The owner's loop, as a test spins it: run what `sink` receives until
/// `done` holds or `ms` pass.
fn spinUntil(sink: *TaskSink, done: *const std.atomic.Value(bool), ms: u64) bool {
    var taken: std.ArrayListUnmanaged(runtime.CrossThreadTask) = .empty;
    defer taken.deinit(allocator);
    var waited: u64 = 0;
    while (!done.load(.acquire) and waited < ms) : (waited += 1) {
        sink.takeAll(&taken, allocator) catch {};
        for (taken.items) |task| task.run(task.data);
        taken.clearRetainingCapacity();
        if (done.load(.acquire)) break;
        sink.waitForWork(1 * std.time.ns_per_ms);
    }
    return done.load(.acquire);
}

test "a worker loop's turn reads as little after 5,000 timers were armed and cleared as before them" {
    const owner_sink = try TaskSink.create(allocator);
    defer owner_sink.release();
    const link = try WorkerLink.create(allocator, owner_sink);
    defer link.release();

    var chain: ChainHost = .{};
    var owner: Owner = .{};
    try WorkerThread.spawn(allocator, link, chain.host(), owner.owner(), null);
    try testing.expect(spinUntil(owner_sink, &owner.ended, 60_000));
    try testing.expect(!chain.failed);
    try testing.expectEqual(@as(usize, before_count + after_count), chain.ran);

    // Per poll: each turn asks for the next deadline and polls once.
    const before = (chain.burst_start.slots - chain.start.slots) / (chain.burst_start.polls - chain.start.polls);
    const after = (chain.end.slots - chain.burst_end.slots) / (chain.end.polls - chain.burst_end.polls);
    if (after > before + 2) {
        std.debug.print("worker loop turns after a burst of 5,000: {d} slots read a poll, against {d} before it\n", .{ after, before });
        return error.BurstLeftTurnsSlow;
    }
}

/// How many timers `WaitHost` chains, and how long each is.
const wait_count = 40;
const wait_ms = 3;

/// The worker's part of the test below: forty 3 ms timers, each armed by
/// the one before, and nothing else to do. Read by the test once the thread
/// is joined.
const WaitHost = struct {
    timers: ?*NativeTimerManager = null,
    timer: ?runtime.TimerInterface = null,
    link: ?*WorkerLink = null,
    ran: usize = 0,
    polls_at_start: u64 = 0,
    polls_at_end: u64 = 0,
    failed: bool = false,

    fn host(self: *WaitHost) WorkerThread.Host {
        return .{ .data = self, .start = startOnThread, .end_realm = endRealm, .free = free };
    }

    fn startOnThread(data: ?*anyopaque, thread: *WorkerThread) bool {
        const self: *WaitHost = @ptrCast(@alignCast(data.?));
        self.timers = thread.loop.timers;
        self.timer = thread.loop.timerInterface();
        self.link = thread.link;
        self.polls_at_start = self.timers.?.probe.polls;
        return self.timer.?.setTimeout(wait_ms, step, self) != 0;
    }

    fn step(data: ?*anyopaque) void {
        const self: *WaitHost = @ptrCast(@alignCast(data.?));
        self.ran += 1;
        if (self.ran == wait_count) {
            self.polls_at_end = self.timers.?.probe.polls;
            _ = self.link.?.requestClose();
            self.link.?.wake();
            return;
        }
        if (self.timer.?.setTimeout(wait_ms, step, self) == 0) {
            self.failed = true;
            _ = self.link.?.requestClose();
        }
    }

    fn endRealm(_: ?*anyopaque, _: *WorkerThread) void {}
    fn free(_: ?*anyopaque) void {}
};

test "a worker's loop waits through a timer's last sub-millisecond: it does not turn without a wait until the timer is due" {
    const owner_sink = try TaskSink.create(allocator);
    defer owner_sink.release();
    const link = try WorkerLink.create(allocator, owner_sink);
    defer link.release();

    var chain: WaitHost = .{};
    var owner: Owner = .{};
    try WorkerThread.spawn(allocator, link, chain.host(), owner.owner(), null);
    try testing.expect(spinUntil(owner_sink, &owner.ended, 60_000));
    try testing.expect(!chain.failed);
    try testing.expectEqual(@as(usize, wait_count), chain.ran);

    // A count, not a time. A worker's turn polls its timers once, after its
    // wait (worker_event_loop.zig turn, steps 5 and 6), and with nothing
    // else to do a turn that WAITS for the next timer waits to its deadline:
    // a turn or two for each timer. `poll_bound` allows five.
    //
    // The loop took the time to the next timer in whole milliseconds, rounded
    // down, and "under a millisecond" for "do not wait" (waitBound): it
    // waited 2 of a timer's 3 ms and turned without a wait through the rest
    // (the window's loop did the same: tests/html/rep2_window_wake_test.zig
    // says what that cost a thread on a busy host).
    const polls = chain.polls_at_end - chain.polls_at_start;
    const poll_bound = wait_count * 5;
    if (polls > poll_bound) {
        std.debug.print("a worker's loop polled its timers {d} times for forty 3 ms timers (at most {d} when it waits for each)\n", .{ polls, poll_bound });
        return error.LoopTurnsWithoutWaiting;
    }
}
