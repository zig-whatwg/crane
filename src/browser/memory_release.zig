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
//!    millisecond, Firefox's purge yields to a ready task, WebKit moves the
//!    darwin call to a background queue. The loop only posts the request;
//!    the platform's helper thread makes the call
//!    (platform.releaseFreeMemory) and tells the gate when it has ended.
//!    What a release can still delay is an allocation from the arena being
//!    trimmed at that moment.
//! 3. HOW MUCH. For the whole process - the allocator is the process's,
//!    whichever Browser's loop asks - no release is asked for while one runs,
//!    nor until `holdOff` has passed since the last one ended: WebKit's
//!    three numbers, unchanged. Releases therefore take at most a twentieth
//!    of one thread's time, and one that finds nothing to return is not
//!    repeated for 30 seconds.
//!
//! Not here yet: the OS's memory-pressure notification (no platform posts
//! platform events yet; when they are delivered, a critical one is
//! engine.notifyMemoryPressure and then `Gate.release(.pressure)`), and a
//! host that stops turning an idle loop (it gets no idle turn to ask on).

const std = @import("std");
const platform = @import("platform");

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

/// The clock and the allocator a gate works with: the platform's
/// (`Source.platform_source`), or a test's.
pub const Source = struct {
    context: ?*anyopaque = null,
    /// Real monotonic time, ns. Called on the asking thread and on the
    /// platform's (from `done`).
    now: *const fn (context: ?*anyopaque) i64,
    /// platform.releaseFreeMemory: true when the request was accepted, and
    /// `done` will be called exactly once.
    request: *const fn (context: ?*anyopaque, level: platform.MemoryRelease, done: platform.MemoryReleaseDone) bool,

    pub const platform_source: Source = .{ .now = platformNow, .request = platformRequest };

    fn platformNow(_: ?*anyopaque) i64 {
        return @intCast(platform.monotonicNow().ns);
    }

    fn platformRequest(_: ?*anyopaque, level: platform.MemoryRelease, done: platform.MemoryReleaseDone) bool {
        return platform.releaseFreeMemory(level, done);
    }
};

/// The hold-off between releases, for everything that shares one allocator:
/// the process has one (`processGate`); a test makes its own. Any thread.
///
/// A gate must outlive the release it asked for: the platform's thread tells
/// it when the release has ended (`done`). The process's gate lives as long
/// as the process; a test's waits (`settle`) before it goes.
pub const Gate = struct {
    /// Real monotonic time (ns) before which no release is asked for;
    /// `releasing` from a request's acceptance until its `done`. A release
    /// claims the gate by swapping the value it read for `releasing`, so of
    /// several loops that find the gate open at once exactly one asks.
    not_before_ns: std.atomic.Value(i64) = .init(open),

    /// How many releases have ended: a count that only rises.
    releases: std.atomic.Value(u64) = .init(0),

    /// The gate's clock and allocator. Never written after the gate is
    /// made: `done` reads it on the platform's thread.
    source: Source = .platform_source,

    const open: i64 = std.math.minInt(i64);
    const releasing: i64 = std.math.maxInt(i64);

    /// Ask the platform to release the allocator's free memory, unless the
    /// hold-off after the last release - or a release still running -
    /// refuses. Whether the request was posted; it never waits for the
    /// release, whose end `done` hears on the platform's thread. When the
    /// platform takes no request (it is releasing for another gate, it is
    /// ending, or it has no allocator to ask) the gate asks again after
    /// `min_hold_off_ns`.
    pub fn release(self: *Gate, level: platform.MemoryRelease) bool {
        const now = self.source.now(self.source.context);
        const not_before = self.not_before_ns.load(.acquire);
        if (now < not_before) return false;
        if (self.not_before_ns.cmpxchgStrong(not_before, releasing, .acq_rel, .acquire) != null) return false;
        if (!self.source.request(self.source.context, level, .{ .context = self, .call = done })) {
            self.not_before_ns.store(now +| min_hold_off_ns, .release);
            return false;
        }
        return true;
    }

    /// platform.MemoryReleaseDone: the release this gate asked for has ended.
    /// On the platform's thread: atomics only. The store that reopens the
    /// gate comes last - after it, a gate that is not the process's may go.
    fn done(context: ?*anyopaque, returned_bytes: usize, duration_ns: u64) callconv(.c) void {
        const self: *Gate = @ptrCast(@alignCast(context.?));
        const end = self.source.now(self.source.context);
        const duration: i64 = @intCast(@min(duration_ns, std.math.maxInt(i64)));
        _ = self.releases.fetchAdd(1, .monotonic);
        self.not_before_ns.store(end +| holdOff(duration, returned_bytes), .release);
    }

    /// How many releases asked through this gate have ended.
    pub fn count(self: *const Gate) u64 {
        return self.releases.load(.monotonic);
    }

    /// Whether a release this gate asked for is still running.
    pub fn isReleasing(self: *const Gate) bool {
        return self.not_before_ns.load(.acquire) == releasing;
    }

    /// Wait until no release this gate asked for is running: before a gate
    /// that is not the process's goes out of scope (tests). The caller has
    /// stopped asking - its loop has ended, or has another gate.
    pub fn settle(self: *const Gate) void {
        while (self.isReleasing()) platform.sleepThread(100 * std.time.ns_per_us);
    }
};

// process-wide: the system allocator is one per process, so the time before which nobody asks it for its free memory again is too - whichever Browser's event loop asked last, on whichever thread; two atomics (std.atomic.Value): the deadline, claimed with a compare-and-swap so that of several loops finding it passed exactly one asks, and reopened by the platform's thread when the release has ended; and a count of releases that only rises
var process_gate: Gate = .{};

/// The process's gate: every event loop's, unless a test gives a loop its
/// own (EventLoop.memory_gate).
pub fn processGate() *Gate {
    return &process_gate;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

/// A clock a test moves and an allocator that reports what the test says.
/// Each release ends inside the request (`hold` false) or when the test
/// says so (`finish`).
const Fake = struct {
    now_ns: i64 = 1_000 * std.time.ns_per_s,
    /// How long each release takes, and what it returns.
    release_takes_ns: i64 = 0,
    release_returns: usize = 0,
    /// Whether the platform accepts requests.
    accepts: bool = true,
    /// Keep a release running until `finish`.
    hold: bool = false,
    held: ?platform.MemoryReleaseDone = null,
    asked: u32 = 0,
    last_level: ?platform.MemoryRelease = null,

    fn source(self: *Fake) Source {
        return .{ .context = self, .now = now, .request = request };
    }

    fn now(context: ?*anyopaque) i64 {
        const self: *Fake = @ptrCast(@alignCast(context.?));
        return self.now_ns;
    }

    fn request(context: ?*anyopaque, level: platform.MemoryRelease, done: platform.MemoryReleaseDone) bool {
        const self: *Fake = @ptrCast(@alignCast(context.?));
        self.asked += 1;
        self.last_level = level;
        if (!self.accepts) return false;
        if (self.hold) {
            self.held = done;
            return true;
        }
        self.end(done);
        return true;
    }

    fn end(self: *Fake, done: platform.MemoryReleaseDone) void {
        self.now_ns += self.release_takes_ns;
        done.call(done.context, self.release_returns, @intCast(self.release_takes_ns));
    }

    /// End the release that was kept running.
    fn finish(self: *Fake) void {
        const done = self.held.?;
        self.held = null;
        self.end(done);
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

test "Gate: the first release is asked for, at the level asked" {
    var fake: Fake = .{ .release_returns = 64 * 1024 * 1024 };
    var gate: Gate = .{ .source = fake.source() };
    try testing.expect(gate.release(.idle));
    try testing.expectEqual(@as(u32, 1), fake.asked);
    try testing.expectEqual(platform.MemoryRelease.idle, fake.last_level.?);
    try testing.expectEqual(@as(u64, 1), gate.count());
    try testing.expect(!gate.isReleasing());
}

test "Gate: after a release that returned memory the next is refused for 20 times its duration, at least 5 seconds" {
    const ms = std.time.ns_per_ms;
    var fake: Fake = .{ .release_takes_ns = 8 * ms, .release_returns = 275 * 1024 * 1024 };
    var gate: Gate = .{ .source = fake.source() };
    try testing.expect(gate.release(.idle));
    const ended = fake.now_ns;

    // 20 x 8 ms is under the floor: 5 seconds from the release's end.
    fake.now_ns = ended + 5 * std.time.ns_per_s - 1;
    try testing.expect(!gate.release(.idle));
    try testing.expectEqual(@as(u32, 1), fake.asked);
    fake.now_ns = ended + 5 * std.time.ns_per_s;
    fake.release_takes_ns = 400 * ms;
    try testing.expect(gate.release(.pressure));
    try testing.expectEqual(platform.MemoryRelease.pressure, fake.last_level.?);
    const second_ended = fake.now_ns;

    // 20 x 400 ms = 8 seconds from the second one's end.
    fake.now_ns = second_ended + 8 * std.time.ns_per_s - 1;
    try testing.expect(!gate.release(.idle));
    fake.now_ns = second_ended + 8 * std.time.ns_per_s;
    try testing.expect(gate.release(.idle));
    try testing.expectEqual(@as(u32, 3), fake.asked);
    try testing.expectEqual(@as(u64, 3), gate.count());
}

test "Gate: a release that returned under 1 MiB is not repeated for 30 seconds" {
    var fake: Fake = .{ .release_takes_ns = 20 * std.time.ns_per_us, .release_returns = 4096 };
    var gate: Gate = .{ .source = fake.source() };
    try testing.expect(gate.release(.idle));
    const ended = fake.now_ns;
    fake.now_ns = ended + 30 * std.time.ns_per_s - 1;
    try testing.expect(!gate.release(.idle));
    fake.now_ns = ended + 30 * std.time.ns_per_s;
    try testing.expect(gate.release(.idle));
    try testing.expectEqual(@as(u32, 2), fake.asked);
}

test "Gate: asking does not wait for the release - while it runs nothing more is asked, and its end sets the hold-off" {
    const ms = std.time.ns_per_ms;
    var fake: Fake = .{ .hold = true, .release_takes_ns = 400 * ms, .release_returns = 300 * 1024 * 1024 };
    var gate: Gate = .{ .source = fake.source() };
    // The request is posted and the caller goes on: the release has not
    // ended, and nothing is counted yet.
    try testing.expect(gate.release(.idle));
    try testing.expect(gate.isReleasing());
    try testing.expectEqual(@as(u64, 0), gate.count());
    // However long it runs, the platform is not asked a second time.
    fake.now_ns += 60 * std.time.ns_per_s;
    try testing.expect(!gate.release(.idle));
    try testing.expect(!gate.release(.pressure));
    try testing.expectEqual(@as(u32, 1), fake.asked);

    // It ends (on the platform's thread, in the engine): 20 x 400 ms from
    // its end.
    fake.finish();
    const ended = fake.now_ns;
    try testing.expect(!gate.isReleasing());
    try testing.expectEqual(@as(u64, 1), gate.count());
    fake.now_ns = ended + 8 * std.time.ns_per_s - 1;
    try testing.expect(!gate.release(.idle));
    fake.now_ns = ended + 8 * std.time.ns_per_s;
    fake.hold = false;
    try testing.expect(gate.release(.idle));
    try testing.expectEqual(@as(u32, 2), fake.asked);
}

test "Gate: a platform that takes no request is asked again after 5 seconds, and nothing is counted" {
    var fake: Fake = .{ .accepts = false };
    var gate: Gate = .{ .source = fake.source() };
    const asked_at = fake.now_ns;
    try testing.expect(!gate.release(.idle));
    try testing.expect(!gate.isReleasing());
    try testing.expectEqual(@as(u64, 0), gate.count());
    // Not on every idle turn: after the floor.
    fake.now_ns = asked_at + 5 * std.time.ns_per_s - 1;
    try testing.expect(!gate.release(.idle));
    try testing.expectEqual(@as(u32, 1), fake.asked);
    fake.now_ns = asked_at + 5 * std.time.ns_per_s;
    fake.accepts = true;
    try testing.expect(gate.release(.idle));
    try testing.expectEqual(@as(u32, 2), fake.asked);
    try testing.expectEqual(@as(u64, 1), gate.count());
}

test "Gate: of several threads that find it open at once, exactly one asks" {
    const Race = struct {
        gate: Gate,
        asked: std.atomic.Value(u32) = .init(0),
        go: std.atomic.Value(bool) = .init(false),

        fn now(_: ?*anyopaque) i64 {
            return 0;
        }

        fn request(context: ?*anyopaque, _: platform.MemoryRelease, done: platform.MemoryReleaseDone) bool {
            const self: *@This() = @ptrCast(@alignCast(context.?));
            _ = self.asked.fetchAdd(1, .monotonic);
            done.call(done.context, 0, 0);
            return true;
        }

        fn thread(self: *@This()) void {
            while (!self.go.load(.acquire)) std.atomic.spinLoopHint();
            _ = self.gate.release(.idle);
        }
    };
    var race: Race = .{ .gate = undefined };
    race.gate = .{ .source = .{ .context = &race, .now = Race.now, .request = Race.request } };
    var threads: [8]std.Thread = undefined;
    for (&threads) |*t| t.* = try std.Thread.spawn(.{}, Race.thread, .{&race});
    race.go.store(true, .release);
    for (threads) |t| t.join();
    // The clock stands at 0 and the first release's hold-off ends at 30 s:
    // every thread after the first finds the gate claimed or held.
    try testing.expectEqual(@as(u32, 1), race.asked.load(.monotonic));
    try testing.expectEqual(@as(u64, 1), race.gate.count());
}

test "the process has one gate, on the platform's clock and allocator" {
    try testing.expect(processGate() == processGate());
    try testing.expect(processGate().source.request == Source.platform_source.request);
}
