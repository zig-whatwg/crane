//! Returning the allocator's free memory to the OS when a page goes idle:
//! the rule for WHEN, and for how much it may cost.
//!
//! The OS allocators keep what a page frees (glibc inside its heaps, macOS
//! in its reclaim ring), and no setting of theirs returns it without
//! slowing the allocation path (lane mem2: every fixed glibc threshold pair
//! cost perf_bench's fetch.loopback-stream x1.10 to x1.47). So the memory
//! is returned away from that path, as the browsers return theirs:
//!
//! - Chrome runs PartitionAlloc's MemoryReclaimer::ReclaimFast as a task in
//!   idle time, every 4 seconds, and ReclaimAll once 10 seconds after the
//!   renderer goes to the background (base/allocator/
//!   partition_alloc_support.cc, MemoryReclaimerSupport and
//!   PartitionAllocSupport::OnBackgrounded; partition_alloc/
//!   memory_reclaimer.cc).
//! - Firefox purges mozjemalloc's dirty pages when the main thread has no
//!   task left, once 500 ms have passed since that memory was last reused,
//!   in a task a ready task interrupts (xpcom/threads/TaskController.cpp,
//!   MayScheduleMemoryCleanup and InterruptiblePurgeTask;
//!   memory.lazypurge.reuse_grace_period).
//! - WebKit calls malloc_trim(0) / malloc_zone_pressure_relief(NULL, 0) 10
//!   seconds after its process has no visible page (Source/WebKit/WebProcess/
//!   WebProcess.cpp, nonVisibleProcessEarlyMemoryCleanupTimerFired) and on
//!   memory pressure, and then refuses the next pressure event for 20 times
//!   the time the release took, at least 5 seconds, and 30 seconds when it
//!   returned under 1 MB (Source/WTF/wtf/unix/MemoryPressureHandlerUnix.cpp,
//!   respondToMemoryPressure).
//!
//! Crane's rule (lane idle1, the integrator's approval 2026-11-16):
//!
//! 1. WHEN. A window event loop asks (`Gate.release(.idle)`) on a turn that
//!    finds nothing to run, once it has had nothing to run for
//!    `idle_delay_ns` of real time - counted from the first such turn after
//!    it last did work - and once per idle stretch: it asks again only
//!    after it has worked again (event_loop.zig, the turn's last step). The
//!    delay is longer than any idle period HTML gives a page (50 ms), so a
//!    loop between two bursts of one workload is not idle: memory about to
//!    be used again is not returned first.
//! 2. WHERE. Not on the loop's thread. glibc's trim can be neither
//!    interrupted nor given a time limit (about 8 ms for 275 MB returned),
//!    and a page idle for 200 ms must not have its next wake - a worker's
//!    reply - wait for one: Chrome keeps its foreground reclaim to about a
//!    millisecond, Firefox's purge yields to a ready task, WebKit hands the
//!    darwin call to a background queue (cocoa/WebProcessCocoa.mm,
//!    releaseSystemMallocMemory: dispatch_async, no thread of its own). As
//!    WebKit: the loop starts a thread for the one release and detaches it
//!    (platform.spawnThread, detachThread); that thread makes the call
//!    (platform.releaseFreeMemory) and writes the hold-off when it has
//!    ended. No thread is kept between releases, and none is joined. What a
//!    release can still delay is an allocation from the arena being trimmed
//!    at that moment.
//! 3. HOW MUCH. For the whole process - the allocator is the process's,
//!    whichever Browser's loop asks - no release is asked for while one runs,
//!    nor until `holdOff` has passed since the last one ended: WebKit's
//!    three numbers, unchanged. Releases therefore take at most a twentieth
//!    of one thread's time, and one that finds nothing to return is not
//!    repeated for 30 seconds. The process's hold-off is in the process's
//!    own record (process.start MemoryHoldOff); `Gate` is the rule over it.
//!
//! Not here yet: the OS's memory-pressure notification (no platform posts
//! platform events yet; when they are delivered, a critical one is
//! engine.notifyMemoryPressure and then `Gate.release(.pressure)`), and a
//! host that stops turning an idle loop (it gets no idle turn to ask on).

const std = @import("std");
const platform = @import("platform");
const process_start = @import("dom").process_start;

/// How long a loop has had nothing to run before it asks: 200 ms.
pub const idle_delay_ns: i64 = 200 * std.time.ns_per_ms;

/// WebKit's s_holdOffMultiplier: no release sooner than this many times the
/// last one's duration - a twentieth of the time at most.
pub const hold_off_multiplier: i64 = 20;

/// WebKit's s_minimumHoldOffTime.
pub const min_hold_off_ns: i64 = 5 * std.time.ns_per_s;

/// WebKit's s_maximumHoldOffTime: the wait after a release that returned
/// less than `small_release_bytes`.
pub const small_release_hold_off_ns: i64 = 30 * std.time.ns_per_s;

/// WebKit's s_minimumBytesFreedToUseMinimumHoldOffTime: 1 MiB.
pub const small_release_bytes: usize = 1024 * 1024;

/// How long no release starts after one that took `duration_ns` and
/// returned `returned_bytes`.
pub fn holdOff(duration_ns: i64, returned_bytes: usize) i64 {
    const wanted = if (returned_bytes >= small_release_bytes)
        @max(0, duration_ns) *| hold_off_multiplier
    else
        small_release_hold_off_ns;
    return @max(wanted, min_hold_off_ns);
}

/// One event loop's side of the rule: how long it has had nothing to run,
/// and whether it has worked since it last had memory released. The loop's
/// own, read and written on its thread.
pub const IdleWatch = struct {
    /// When the current idle stretch began - the first turn that found
    /// nothing to run since the loop last worked, real monotonic ns; null
    /// while there has been none.
    idle_since_ns: ?i64 = null,

    /// Whether the loop has worked since its last release. True from the
    /// start: what made the page was work.
    armed: bool = true,

    /// The loop did work this turn: the idle stretch, if any, is over.
    pub fn worked(self: *IdleWatch) void {
        self.idle_since_ns = null;
        self.armed = true;
    }

    /// A turn found nothing to run, at `now_ns`. Whether it should ask for
    /// a release: the loop has worked since its last one, and has had
    /// nothing to run for `idle_delay_ns`.
    pub fn idleTurn(self: *IdleWatch, now_ns: i64) bool {
        if (!self.armed) return false;
        const since = self.idle_since_ns orelse {
            self.idle_since_ns = now_ns;
            return false;
        };
        return now_ns - since >= idle_delay_ns;
    }

    /// The release ran: nothing more to ask for until the loop works again.
    pub fn released(self: *IdleWatch) void {
        self.armed = false;
    }
};

/// The record a gate reads and writes: the time before which no release is
/// asked for, whether one runs, how many have ended. The process has one, in
/// its own record (process.start); a test makes its own.
pub const HoldOff = process_start.MemoryHoldOff;

/// The clock a gate reads and the way its releases are started: the
/// platform's (`Source.platform_source`), or a test's.
pub const Source = struct {
    context: ?*anyopaque = null,
    /// Real monotonic time, ns.
    now: *const fn (context: ?*anyopaque) i64,
    /// Start the release `hold` was just claimed for (its level is
    /// `hold.level`), off the calling thread, and return at once. True: it
    /// was started, and `ended(hold, ...)` will be called exactly once when
    /// it is over. False: it could not be started; `ended` is not called.
    start: *const fn (context: ?*anyopaque, hold: *HoldOff) bool,

    pub const platform_source: Source = .{ .now = platformNow, .start = platformStart };

    fn platformNow(_: ?*anyopaque) i64 {
        return @intCast(platform.monotonicNow().ns);
    }

    /// A thread for this one release, detached: it ends by itself, and
    /// nobody joins it (WebKit hands the same call to a background queue).
    fn platformStart(_: ?*anyopaque, hold: *HoldOff) bool {
        const thread = platform.spawnThread(.{ .name = .from("crane-memory") }, runRelease, hold) catch return false;
        platform.detachThread(thread);
        return true;
    }

    /// The release's thread: the allocator's call, then the hold-off. It
    /// touches the hold-off's atomics and the platform's clock, nothing
    /// else - no loop, no realm, no Browser.
    fn runRelease(context: ?*anyopaque) callconv(.c) void {
        const hold: *HoldOff = @ptrCast(@alignCast(context.?));
        const level: platform.MemoryRelease = @fromBackingInt(@intCast(hold.level.load(.acquire)));
        const start = platformNow(null);
        const returned = platform.releaseFreeMemory(level);
        const end = platformNow(null);
        ended(hold, end, returned, end - start);
    }
};

/// A release started for `hold` is over: at `end_ns` (real monotonic), after
/// `duration_ns` of the allocator's work, with `returned_bytes` returned.
/// Counts it and opens the record again after the hold-off - that store
/// comes last: after it, a record that is not the process's may go. Atomics
/// only; called on the release's thread.
pub fn ended(hold: *HoldOff, end_ns: i64, returned_bytes: usize, duration_ns: i64) void {
    _ = hold.releases.fetchAdd(1, .monotonic);
    hold.not_before_ns.store(end_ns +| holdOff(duration_ns, returned_bytes), .release);
}

/// The rule between releases, over one hold-off record: everything that
/// shares an allocator shares the record. A value - the record it points to
/// is what must outlive a release (the process's does; a test's waits,
/// `settle`). Any thread.
pub const Gate = struct {
    /// BORROWED: the process's (`processGate`), or a test's own.
    hold: *HoldOff,
    source: Source = .platform_source,

    /// Start a release of the allocator's free memory on a thread of its
    /// own, unless the hold-off after the last release - or a release still
    /// running - refuses. Whether one was started; it never waits for the
    /// release, whose thread writes the hold-off when it is over. When no
    /// thread could be started the gate asks again after `min_hold_off_ns`.
    pub fn release(self: Gate, level: platform.MemoryRelease) bool {
        const now = self.source.now(self.source.context);
        const not_before = self.hold.not_before_ns.load(.acquire);
        if (now < not_before) return false;
        if (self.hold.not_before_ns.cmpxchgStrong(not_before, HoldOff.releasing, .acq_rel, .acquire) != null) return false;
        self.hold.level.store(@backingInt(level), .release);
        if (!self.source.start(self.source.context, self.hold)) {
            self.hold.not_before_ns.store(now +| min_hold_off_ns, .release);
            return false;
        }
        return true;
    }

    /// How many releases started through this gate's record have ended.
    pub fn count(self: Gate) u64 {
        return self.hold.releases.load(.monotonic);
    }

    /// Whether a release is running.
    pub fn isReleasing(self: Gate) bool {
        return self.hold.not_before_ns.load(.acquire) == HoldOff.releasing;
    }

    /// Wait until no release is running: the process's end
    /// (crane.Process.deinit, after its last Browser), and a test before its
    /// own record goes out of scope. Nothing asks any more by then - the
    /// loops have ended, or have another gate.
    pub fn settle(self: Gate) void {
        while (self.isReleasing()) platform.sleepThread(100 * std.time.ns_per_us);
    }
};

/// The process's gate, over the process's record: every event loop's,
/// unless a test gives a loop its own (EventLoop.memory_gate).
pub fn processGate() Gate {
    return .{ .hold = process_start.memoryHoldOff() };
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

/// A clock a test moves and releases that take and return what the test
/// says. Each release ends inside the start (`hold_open` false) or when the
/// test says so (`finish`).
const Fake = struct {
    now_ns: i64 = 1_000 * std.time.ns_per_s,
    /// How long each release takes, and what it returns.
    release_takes_ns: i64 = 0,
    release_returns: usize = 0,
    /// Whether a release can be started.
    starts: bool = true,
    /// Keep a release running until `finish`.
    hold_open: bool = false,
    running: ?*HoldOff = null,
    asked: u32 = 0,
    last_level: ?platform.MemoryRelease = null,
    hold: HoldOff = .{},

    fn gate(self: *Fake) Gate {
        return .{ .hold = &self.hold, .source = .{ .context = self, .now = now, .start = start } };
    }

    fn now(context: ?*anyopaque) i64 {
        const self: *Fake = @ptrCast(@alignCast(context.?));
        return self.now_ns;
    }

    fn start(context: ?*anyopaque, hold: *HoldOff) bool {
        const self: *Fake = @ptrCast(@alignCast(context.?));
        self.asked += 1;
        const level: platform.MemoryRelease = @fromBackingInt(@intCast(hold.level.load(.acquire)));
        self.last_level = level;
        if (!self.starts) return false;
        if (self.hold_open) {
            self.running = hold;
            return true;
        }
        self.end(hold);
        return true;
    }

    fn end(self: *Fake, hold: *HoldOff) void {
        self.now_ns += self.release_takes_ns;
        ended(hold, self.now_ns, self.release_returns, self.release_takes_ns);
    }

    /// End the release that was kept running.
    fn finish(self: *Fake) void {
        const hold = self.running.?;
        self.running = null;
        self.end(hold);
    }
};

test "IdleWatch: a loop asks once it has had nothing to run for 200 ms, not before" {
    const ms = std.time.ns_per_ms;
    var watch: IdleWatch = .{};
    // The stretch begins at the first turn with nothing to run - however
    // long ago the loop was made.
    try testing.expect(!watch.idleTurn(7_000 * ms));
    try testing.expect(!watch.idleTurn(7_001 * ms));
    try testing.expect(!watch.idleTurn(7_199 * ms));
    try testing.expect(watch.idleTurn(7_200 * ms));
    // Work ends the stretch; the next begins at the next idle turn.
    watch.worked();
    try testing.expect(!watch.idleTurn(7_300 * ms));
    try testing.expect(!watch.idleTurn(7_499 * ms));
    try testing.expect(watch.idleTurn(7_500 * ms));
}

test "IdleWatch: work every 150 ms keeps the loop from asking, however long it goes on" {
    const ms = std.time.ns_per_ms;
    var watch: IdleWatch = .{};
    var now: i64 = 0;
    for (0..100) |_| {
        // 149 idle turns a millisecond apart, then a turn that works.
        for (0..149) |_| {
            now += ms;
            try testing.expect(!watch.idleTurn(now));
        }
        now += ms;
        watch.worked();
    }
}

test "IdleWatch: once per idle stretch - again only after the loop has worked again" {
    const ms = std.time.ns_per_ms;
    var watch: IdleWatch = .{};
    try testing.expect(!watch.idleTurn(0));
    try testing.expect(watch.idleTurn(200 * ms));
    watch.released();
    // Idle for a minute more: nothing new was freed, nothing to ask for.
    try testing.expect(!watch.idleTurn(201 * ms));
    try testing.expect(!watch.idleTurn(60_000 * ms));
    // Work, then another idle stretch.
    watch.worked();
    try testing.expect(!watch.idleTurn(60_010 * ms));
    try testing.expect(!watch.idleTurn(60_209 * ms));
    try testing.expect(watch.idleTurn(60_210 * ms));
}

test "IdleWatch: a refused release leaves the loop asking" {
    const ms = std.time.ns_per_ms;
    var watch: IdleWatch = .{};
    try testing.expect(!watch.idleTurn(0));
    // The gate refused (another Browser's release 2 seconds ago): the loop
    // does not call `released`, and is still due on its next idle turns.
    try testing.expect(watch.idleTurn(250 * ms));
    try testing.expect(watch.idleTurn(251 * ms));
    try testing.expect(watch.idleTurn(4_000 * ms));
}

test "holdOff: 20 times the release's duration, at least 5 seconds; 30 seconds when under 1 MiB came back" {
    const ms = std.time.ns_per_ms;
    const s = std.time.ns_per_s;
    // A release that returned memory: 20 times its duration, from 5 s up.
    try testing.expectEqual(@as(i64, 5 * s), holdOff(8 * ms, 275 * 1024 * 1024));
    try testing.expectEqual(@as(i64, 5 * s), holdOff(250 * ms, small_release_bytes));
    try testing.expectEqual(@as(i64, 6 * s), holdOff(300 * ms, small_release_bytes));
    try testing.expectEqual(@as(i64, 40 * s), holdOff(2 * s, 1 << 30));
    // One that returned under 1 MiB: 30 seconds, however short it was.
    try testing.expectEqual(@as(i64, 30 * s), holdOff(0, 0));
    try testing.expectEqual(@as(i64, 30 * s), holdOff(8 * ms, small_release_bytes - 1));
    // A clock that went backwards is no negative hold-off.
    try testing.expectEqual(@as(i64, 5 * s), holdOff(-1, small_release_bytes));
}

test "Gate: the first release is started, at the level asked" {
    var fake: Fake = .{ .release_returns = 64 * 1024 * 1024 };
    const gate = fake.gate();
    try testing.expect(gate.release(.idle));
    try testing.expectEqual(@as(u32, 1), fake.asked);
    try testing.expectEqual(platform.MemoryRelease.idle, fake.last_level.?);
    try testing.expectEqual(@as(u64, 1), gate.count());
    try testing.expect(!gate.isReleasing());
}

test "Gate: after a release that returned memory the next is refused for 20 times its duration, at least 5 seconds" {
    const ms = std.time.ns_per_ms;
    var fake: Fake = .{ .release_takes_ns = 8 * ms, .release_returns = 275 * 1024 * 1024 };
    const gate = fake.gate();
    try testing.expect(gate.release(.idle));
    const end = fake.now_ns;

    // 20 x 8 ms is under the floor: 5 seconds from the release's end.
    fake.now_ns = end + 5 * std.time.ns_per_s - 1;
    try testing.expect(!gate.release(.idle));
    try testing.expectEqual(@as(u32, 1), fake.asked);
    fake.now_ns = end + 5 * std.time.ns_per_s;
    fake.release_takes_ns = 400 * ms;
    try testing.expect(gate.release(.pressure));
    try testing.expectEqual(platform.MemoryRelease.pressure, fake.last_level.?);
    const second_end = fake.now_ns;

    // 20 x 400 ms = 8 seconds from the second one's end.
    fake.now_ns = second_end + 8 * std.time.ns_per_s - 1;
    try testing.expect(!gate.release(.idle));
    fake.now_ns = second_end + 8 * std.time.ns_per_s;
    try testing.expect(gate.release(.idle));
    try testing.expectEqual(@as(u32, 3), fake.asked);
    try testing.expectEqual(@as(u64, 3), gate.count());
}

test "Gate: a release that returned under 1 MiB is not repeated for 30 seconds" {
    var fake: Fake = .{ .release_takes_ns = 20 * std.time.ns_per_us, .release_returns = 4096 };
    const gate = fake.gate();
    try testing.expect(gate.release(.idle));
    const end = fake.now_ns;
    fake.now_ns = end + 30 * std.time.ns_per_s - 1;
    try testing.expect(!gate.release(.idle));
    fake.now_ns = end + 30 * std.time.ns_per_s;
    try testing.expect(gate.release(.idle));
    try testing.expectEqual(@as(u32, 2), fake.asked);
}

test "Gate: starting does not wait for the release - while it runs none is started, and its end sets the hold-off" {
    const ms = std.time.ns_per_ms;
    var fake: Fake = .{ .hold_open = true, .release_takes_ns = 400 * ms, .release_returns = 300 * 1024 * 1024 };
    const gate = fake.gate();
    // The release is started and the caller goes on: it has not ended, and
    // nothing is counted yet.
    try testing.expect(gate.release(.idle));
    try testing.expect(gate.isReleasing());
    try testing.expectEqual(@as(u64, 0), gate.count());
    // However long it runs, no second one is started - by this gate or by
    // another over the same record (another Browser's loop).
    fake.now_ns += 60 * std.time.ns_per_s;
    try testing.expect(!gate.release(.idle));
    try testing.expect(!gate.release(.pressure));
    try testing.expect(!fake.gate().release(.idle));
    try testing.expectEqual(@as(u32, 1), fake.asked);

    // It ends (on its own thread, in the engine): 20 x 400 ms from its end.
    fake.finish();
    const end = fake.now_ns;
    try testing.expect(!gate.isReleasing());
    try testing.expectEqual(@as(u64, 1), gate.count());
    fake.now_ns = end + 8 * std.time.ns_per_s - 1;
    try testing.expect(!gate.release(.idle));
    fake.now_ns = end + 8 * std.time.ns_per_s;
    fake.hold_open = false;
    try testing.expect(gate.release(.idle));
    try testing.expectEqual(@as(u32, 2), fake.asked);
}

test "Gate: when no thread can be started the gate asks again after 5 seconds, and nothing is counted" {
    var fake: Fake = .{ .starts = false };
    const gate = fake.gate();
    const asked_at = fake.now_ns;
    try testing.expect(!gate.release(.idle));
    try testing.expect(!gate.isReleasing());
    try testing.expectEqual(@as(u64, 0), gate.count());
    // Not on every idle turn: after the floor.
    fake.now_ns = asked_at + 5 * std.time.ns_per_s - 1;
    try testing.expect(!gate.release(.idle));
    try testing.expectEqual(@as(u32, 1), fake.asked);
    fake.now_ns = asked_at + 5 * std.time.ns_per_s;
    fake.starts = true;
    try testing.expect(gate.release(.idle));
    try testing.expectEqual(@as(u32, 2), fake.asked);
    try testing.expectEqual(@as(u64, 1), gate.count());
}

test "Gate: of several threads that find the record open at once, exactly one starts a release" {
    const Race = struct {
        hold: HoldOff = .{},
        asked: std.atomic.Value(u32) = .init(0),
        go: std.atomic.Value(bool) = .init(false),

        fn now(_: ?*anyopaque) i64 {
            return 0;
        }

        fn start(context: ?*anyopaque, hold: *HoldOff) bool {
            const self: *@This() = @ptrCast(@alignCast(context.?));
            _ = self.asked.fetchAdd(1, .monotonic);
            ended(hold, 0, 0, 0);
            return true;
        }

        fn thread(self: *@This()) void {
            while (!self.go.load(.acquire)) std.atomic.spinLoopHint();
            const gate: Gate = .{ .hold = &self.hold, .source = .{ .context = self, .now = now, .start = start } };
            _ = gate.release(.idle);
        }
    };
    var race: Race = .{};
    var threads: [8]std.Thread = undefined;
    for (&threads) |*t| t.* = try std.Thread.spawn(.{}, Race.thread, .{&race});
    race.go.store(true, .release);
    for (threads) |t| t.join();
    // The clock stands at 0 and the first release's hold-off ends at 30 s:
    // every thread after the first finds the record claimed or held.
    try testing.expectEqual(@as(u32, 1), race.asked.load(.monotonic));
    try testing.expectEqual(@as(u64, 1), race.hold.releases.load(.monotonic));
}

test "Gate: the platform's release runs on a detached thread of its own, and settle waits for its end" {
    // The real clock, thread and allocator: whatever the allocator returns
    // here, the release ran once, off this thread, and the record is open
    // again - held off for at least 5 seconds.
    var hold: HoldOff = .{};
    const gate: Gate = .{ .hold = &hold };
    try testing.expect(gate.release(.idle));
    gate.settle();
    try testing.expectEqual(@as(u64, 1), gate.count());
    try testing.expect(!gate.isReleasing());
    try testing.expect(!gate.release(.idle));
}

test "Gate.settle - what the process's end waits with - returns only once the release in flight has ended" {
    // crane.Process.deinit calls settle on the process's gate after its last
    // Browser. Here, a record of the test's own and a release kept running
    // on a detached thread: settle returns after the thread's last write,
    // and nothing is left behind (the thread is detached; no join, no
    // allocation).
    const Slow = struct {
        hold: HoldOff = .{},
        finished: std.atomic.Value(bool) = .init(false),

        fn now(_: ?*anyopaque) i64 {
            return @intCast(platform.monotonicNow().ns);
        }

        fn start(context: ?*anyopaque, hold: *HoldOff) bool {
            _ = hold;
            const thread = platform.spawnThread(.{ .name = .from("slow-release") }, run, context) catch return false;
            platform.detachThread(thread);
            return true;
        }

        fn run(context: ?*anyopaque) callconv(.c) void {
            const self: *@This() = @ptrCast(@alignCast(context.?));
            platform.sleepThread(50 * std.time.ns_per_ms);
            self.finished.store(true, .release);
            ended(&self.hold, now(null), 2 * small_release_bytes, 50 * std.time.ns_per_ms);
        }
    };
    var slow: Slow = .{};
    const gate: Gate = .{ .hold = &slow.hold, .source = .{ .context = &slow, .now = Slow.now, .start = Slow.start } };
    try testing.expect(gate.release(.idle));
    // Started, not waited for.
    try testing.expect(gate.isReleasing() or slow.finished.load(.acquire));
    gate.settle();
    try testing.expect(slow.finished.load(.acquire));
    try testing.expect(!gate.isReleasing());
    try testing.expectEqual(@as(u64, 1), gate.count());
    // Settled twice is settled.
    gate.settle();
}

test "the process has one gate, over the process's record, on the platform's clock and threads" {
    try testing.expect(processGate().hold == processGate().hold);
    try testing.expect(processGate().hold == process_start.memoryHoldOff());
    try testing.expect(processGate().source.start == Source.platform_source.start);
}
