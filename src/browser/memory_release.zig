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
//!    loop between two bursts of one workload is not idle. glibc's trim can
//!    be neither interrupted nor given a time limit, as Chrome's and
//!    Firefox's purges can: hence a real idle stretch, not any gap between
//!    tasks.
//! 2. HOW MUCH. Never inside a task. For the whole process - the allocator
//!    is the process's, whichever Browser's loop asks - a release is refused
//!    until `holdOff` has passed since the last one ended: WebKit's three
//!    numbers, unchanged. A release therefore takes at most a twentieth of
//!    the process's time, and one that finds nothing to return is not
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
/// (`Source.platform`), or a test's.
pub const Source = struct {
    context: ?*anyopaque = null,
    /// Real monotonic time, ns.
    now: *const fn (context: ?*anyopaque) i64,
    /// platform.releaseFreeMemory: the bytes returned.
    release: *const fn (context: ?*anyopaque, level: platform.MemoryRelease) usize,

    pub const platform_source: Source = .{ .now = platformNow, .release = platformRelease };

    fn platformNow(_: ?*anyopaque) i64 {
        return @intCast(platform.monotonicNow().ns);
    }

    fn platformRelease(_: ?*anyopaque, level: platform.MemoryRelease) usize {
        return platform.releaseFreeMemory(level);
    }
};

/// The hold-off between releases, for everything that shares one allocator:
/// the process has one (`processGate`); a test makes its own. Any thread.
pub const Gate = struct {
    /// Real monotonic time (ns) before which no release starts; `releasing`
    /// while one runs. A release claims the gate by swapping the value it
    /// read for `releasing`, so of several loops that find the gate open at
    /// once exactly one releases.
    not_before_ns: std.atomic.Value(i64) = .init(open),

    /// How many releases ran: a count that only rises.
    releases: std.atomic.Value(u64) = .init(0),

    const open: i64 = std.math.minInt(i64);
    const releasing: i64 = std.math.maxInt(i64);

    /// Ask the platform to release the allocator's free memory, unless the
    /// hold-off after the last release - or a release running now on another
    /// thread - refuses. Whether it ran. Never from inside a task.
    pub fn release(self: *Gate, level: platform.MemoryRelease) bool {
        return self.releaseFrom(level, .platform_source);
    }

    /// `release` with `source`'s clock and allocator.
    pub fn releaseFrom(self: *Gate, level: platform.MemoryRelease, source: Source) bool {
        const start = source.now(source.context);
        const not_before = self.not_before_ns.load(.acquire);
        if (start < not_before) return false;
        if (self.not_before_ns.cmpxchgStrong(not_before, releasing, .acq_rel, .acquire) != null) return false;
        const returned = source.release(source.context, level);
        const end = source.now(source.context);
        _ = self.releases.fetchAdd(1, .monotonic);
        self.not_before_ns.store(end +| holdOff(end - start, returned), .release);
        return true;
    }

    /// How many releases ran through this gate.
    pub fn count(self: *const Gate) u64 {
        return self.releases.load(.monotonic);
    }
};

// process-wide: the system allocator is one per process, so the time before which nobody asks it for its free memory again is too - whichever Browser's event loop asked last, on whichever thread; two atomics (std.atomic.Value): the deadline, claimed with a compare-and-swap so that of several loops finding it passed exactly one releases, and a count of releases that only rises
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
const Fake = struct {
    now_ns: i64 = 1_000 * std.time.ns_per_s,
    /// How long each release takes, and what it returns.
    release_takes_ns: i64 = 0,
    release_returns: usize = 0,
    asked: u32 = 0,
    last_level: ?platform.MemoryRelease = null,

    fn source(self: *Fake) Source {
        return .{ .context = self, .now = now, .release = release };
    }

    fn now(context: ?*anyopaque) i64 {
        const self: *Fake = @ptrCast(@alignCast(context.?));
        return self.now_ns;
    }

    fn release(context: ?*anyopaque, level: platform.MemoryRelease) usize {
        const self: *Fake = @ptrCast(@alignCast(context.?));
        self.asked += 1;
        self.last_level = level;
        self.now_ns += self.release_takes_ns;
        return self.release_returns;
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

test "Gate: the first release runs, at the level asked" {
    var fake: Fake = .{ .release_returns = 64 * 1024 * 1024 };
    var gate: Gate = .{};
    try testing.expect(gate.releaseFrom(.idle, fake.source()));
    try testing.expectEqual(@as(u32, 1), fake.asked);
    try testing.expectEqual(platform.MemoryRelease.idle, fake.last_level.?);
    try testing.expectEqual(@as(u64, 1), gate.count());
}

test "Gate: after a release that returned memory the next is refused for 20 times its duration, at least 5 seconds" {
    const ms = std.time.ns_per_ms;
    var fake: Fake = .{ .release_takes_ns = 8 * ms, .release_returns = 275 * 1024 * 1024 };
    var gate: Gate = .{};
    try testing.expect(gate.releaseFrom(.idle, fake.source()));
    const ended = fake.now_ns;

    // 20 x 8 ms is under the floor: 5 seconds from the release's end.
    fake.now_ns = ended + 5 * std.time.ns_per_s - 1;
    try testing.expect(!gate.releaseFrom(.idle, fake.source()));
    try testing.expectEqual(@as(u32, 1), fake.asked);
    fake.now_ns = ended + 5 * std.time.ns_per_s;
    fake.release_takes_ns = 400 * ms;
    try testing.expect(gate.releaseFrom(.pressure, fake.source()));
    try testing.expectEqual(platform.MemoryRelease.pressure, fake.last_level.?);
    const second_ended = fake.now_ns;

    // 20 x 400 ms = 8 seconds from the second one's end.
    fake.now_ns = second_ended + 8 * std.time.ns_per_s - 1;
    try testing.expect(!gate.releaseFrom(.idle, fake.source()));
    fake.now_ns = second_ended + 8 * std.time.ns_per_s;
    try testing.expect(gate.releaseFrom(.idle, fake.source()));
    try testing.expectEqual(@as(u32, 3), fake.asked);
    try testing.expectEqual(@as(u64, 3), gate.count());
}

test "Gate: a release that returned under 1 MiB is not repeated for 30 seconds" {
    var fake: Fake = .{ .release_takes_ns = 20 * std.time.ns_per_us, .release_returns = 4096 };
    var gate: Gate = .{};
    try testing.expect(gate.releaseFrom(.idle, fake.source()));
    const ended = fake.now_ns;
    fake.now_ns = ended + 30 * std.time.ns_per_s - 1;
    try testing.expect(!gate.releaseFrom(.idle, fake.source()));
    fake.now_ns = ended + 30 * std.time.ns_per_s;
    try testing.expect(gate.releaseFrom(.idle, fake.source()));
    try testing.expectEqual(@as(u32, 2), fake.asked);
}

test "Gate: while one release runs, another thread's is refused" {
    // The second ask arrives from inside the first one's release - where
    // another thread's would while the allocator works.
    const Nested = struct {
        gate: Gate = .{},
        inner_ran: ?bool = null,
        asked: u32 = 0,

        fn now(_: ?*anyopaque) i64 {
            return 0;
        }

        fn release(context: ?*anyopaque, level: platform.MemoryRelease) usize {
            const self: *@This() = @ptrCast(@alignCast(context.?));
            self.asked += 1;
            if (self.inner_ran == null) {
                self.inner_ran = false;
                self.inner_ran = self.gate.releaseFrom(level, .{ .context = self, .now = now, .release = release });
            }
            return 0;
        }
    };
    var nested: Nested = .{};
    try testing.expect(nested.gate.releaseFrom(.idle, .{ .context = &nested, .now = Nested.now, .release = Nested.release }));
    try testing.expectEqual(false, nested.inner_ran.?);
    try testing.expectEqual(@as(u32, 1), nested.asked);
    try testing.expectEqual(@as(u64, 1), nested.gate.count());
}

test "Gate: of several threads that find it open at once, exactly one releases" {
    const Race = struct {
        gate: Gate = .{},
        asked: std.atomic.Value(u32) = .init(0),
        go: std.atomic.Value(bool) = .init(false),

        fn now(_: ?*anyopaque) i64 {
            return 0;
        }

        fn release(context: ?*anyopaque, _: platform.MemoryRelease) usize {
            const self: *@This() = @ptrCast(@alignCast(context.?));
            _ = self.asked.fetchAdd(1, .monotonic);
            return 0;
        }

        fn thread(self: *@This()) void {
            while (!self.go.load(.acquire)) std.atomic.spinLoopHint();
            _ = self.gate.releaseFrom(.idle, .{ .context = self, .now = now, .release = release });
        }
    };
    var race: Race = .{};
    var threads: [8]std.Thread = undefined;
    for (&threads) |*t| t.* = try std.Thread.spawn(.{}, Race.thread, .{&race});
    race.go.store(true, .release);
    for (threads) |t| t.join();
    // The clock stands at 0 and the first release's hold-off ends at 30 s:
    // every thread after the first finds the gate claimed or held.
    try testing.expectEqual(@as(u32, 1), race.asked.load(.monotonic));
    try testing.expectEqual(@as(u64, 1), race.gate.count());
}

test "the process has one gate" {
    try testing.expect(processGate() == processGate());
}
