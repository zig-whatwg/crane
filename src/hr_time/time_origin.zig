//! Time Origin Management for High Resolution Time
//!
//! WHATWG/W3C HR-Time Spec: https://w3c.github.io/hr-time/
//! Spec Reference: Section 3.4 "Time Origin"
//!
//! This module manages the time origin for environment settings objects.
//! The time origin is the moment when a context (Window, Worker) was created,
//! used as the reference point for Performance.now() measurements.
//!
//! ## Concepts
//!
//! - **Time Origin**: The moment when the context was created (navigation start
//!   for Window, worker start for Worker)
//! - **Estimated Monotonic Time of Unix Epoch**: A shared reference point that
//!   allows correlating monotonic time with wall clock time
//!
//! ## Per Spec Section 3.4:
//!
//! "The Unix epoch is the moment on the wall clock corresponding to
//! 1 January 1970 00:00:00 UTC."
//!
//! "Each group of environment settings objects that could possibly communicate
//! in any way has an estimated monotonic time of the Unix epoch."

const std = @import("std");
const clock = @import("clock.zig");
const coarsen = @import("coarsen.zig");
const Hook = @import("process").Hook;

/// Time Origin for an environment settings object
///
/// Per HR-Time spec, each context has a time origin that represents
/// when the context was created. This is used as the reference point
/// for Performance.now() which returns time relative to the origin.
pub const TimeOrigin = struct {
    /// The moment on the monotonic clock when this context was created.
    /// This is a coarsened moment (safe to expose).
    origin_moment: clock.Nanoseconds,

    /// The same moment before coarsening - the unsafe moment the time
    /// origin was made from. Never exposed: read only to tell a fetch
    /// timestamp at or before the origin from one after it
    /// (`relativeFetchTime`).
    unsafe_origin_moment: clock.Nanoseconds,

    /// Estimated monotonic time of the Unix epoch.
    /// Shared across related contexts that can communicate.
    /// This is used to calculate Performance.timeOrigin.
    estimated_epoch: clock.Nanoseconds,

    /// Whether this context has cross-origin isolated capability.
    /// Affects timer resolution per spec section 3.6.
    cross_origin_isolated: bool,

    /// The clocks it reads: the process's, or its global's Browser's
    /// (clock.Source; the testing platform's opt-in virtual clock).
    source: clock.Source = .process,

    const Self = @This();

    /// Initialize a new time origin for a context, now
    ///
    /// This should be called when creating a new environment settings object:
    /// - For Window: at navigation start
    /// - For Worker: when the worker is run
    ///
    /// The estimated monotonic time of the Unix epoch is the group's, one
    /// moment shared by every time origin (estimatedMonotonicTimeOfUnixEpoch).
    pub fn init(cross_origin_isolated: bool) Self {
        return initOn(.process, cross_origin_isolated);
    }

    /// `init`, now on `source` - its global's Browser's clocks - which the
    /// time origin then reads.
    pub fn initOn(source: clock.Source, cross_origin_isolated: bool) Self {
        const monotonic_time = source.monotonicTime();
        return Self{
            .origin_moment = coarsen.coarsenTime(monotonic_time, cross_origin_isolated),
            .unsafe_origin_moment = monotonic_time,
            .estimated_epoch = estimatedMonotonicTimeOfUnixEpochOn(source),
            .cross_origin_isolated = cross_origin_isolated,
            .source = source,
        };
    }

    /// Initialize with a specific origin moment (for testing or custom
    /// scenarios), already coarsened; it stands for its unsafe moment too.
    pub fn initWithOrigin(
        origin_moment: clock.Nanoseconds,
        estimated_epoch: clock.Nanoseconds,
        cross_origin_isolated: bool,
    ) Self {
        return Self{
            .origin_moment = origin_moment,
            .unsafe_origin_moment = origin_moment,
            .estimated_epoch = estimated_epoch,
            .cross_origin_isolated = cross_origin_isolated,
        };
    }

    /// Initialize at `unsafe_moment`, a moment of the unsafe shared current
    /// time recorded earlier (a Window's creation, a navigation's start):
    /// the origin is that moment coarsened.
    pub fn initAtUnsafe(
        unsafe_moment: clock.Nanoseconds,
        estimated_epoch: clock.Nanoseconds,
        cross_origin_isolated: bool,
    ) Self {
        return Self{
            .origin_moment = coarsen.coarsenTime(unsafe_moment, cross_origin_isolated),
            .unsafe_origin_moment = unsafe_moment,
            .estimated_epoch = estimated_epoch,
            .cross_origin_isolated = cross_origin_isolated,
        };
    }

    /// The time origin becomes `unsafe_moment`, coarsened: HTML gives a
    /// document a navigation made the navigation's start time as its time
    /// origin (its load timing info's navigation start time).
    pub fn moveTo(self: *Self, unsafe_moment: clock.Nanoseconds) void {
        self.origin_moment = coarsen.coarsenTime(unsafe_moment, self.cross_origin_isolated);
        self.unsafe_origin_moment = unsafe_moment;
    }

    /// Resource Timing "convert fetch timestamp" step 2 for `unsafe_moment`,
    /// a fetch timing info's moment of the unsafe shared current time (step
    /// 1, a zero timestamp, is the caller's): its relative high resolution
    /// coarse time - never 0 for a moment after the origin.
    ///
    /// Golden rule 2 (the integrator's ruling, 2026-11-27 8:05 PM ET, lane
    /// tbfix1): WebKit's networkLoadTimeToDOMHighResTimeStamp
    /// (Source/WebCore/page/PerformanceResourceTiming.cpp; 306074@main,
    /// e97d460dbd39, bug 306010, in Safari 27.2's safari-7625.2.8.11-branch)
    /// returns 0 for a time at or before the time origin, and raises a
    /// reduced 0 to one tick - "A timestamp of 0.0 means that there is no
    /// timestamp" - for every network timestamp; unload, DOM and load marks
    /// keep the plain relative time (PerformanceNavigationTiming::
    /// millisecondsSinceOrigin). The spec's relative coarse time reads 0 for
    /// a moment in the origin's tick, the value of a mark never taken:
    /// Crane's navigation starts its fetch 25-120 us after its time origin,
    /// so on the 125 us grid a same-origin redirect's redirectStart, and a
    /// reused connection's fetchStart and secureConnectionStart, read "no
    /// redirect" and "no connection time" in about half of all navigations
    /// (navigation-timing/nav2-test-redirect-server.html, secure-connection-
    /// start-non-zero.https.html, nav2-test-timing-persistent.html,
    /// test-timing-attributes-dependent-on-document-load.html: Chrome and
    /// Safari pass all four, Firefox fails, wpt.fyi fb385fbf9c 2026-11-27).
    /// Chrome reaches them through its process hop (navigation_start taken
    /// in the renderer, fetch_start in the browser's
    /// NavigationRequest::OnStartChecksComplete: milliseconds later) and
    /// reports the clamped clock as it is (Blink's
    /// Performance::MonotonicTimeToDOMHighResTimeStamp), as Gecko does
    /// (PerformanceTimingData::TimeStampToReducedDOMHighResOrFetchStart);
    /// Crane has no hop, and a delay would be an invented path. Coarsening
    /// itself, performance.now() and timeOrigin are unchanged.
    pub fn relativeFetchTime(self: *const Self, unsafe_moment: clock.Nanoseconds) clock.Nanoseconds {
        // At or before the time origin: 0.
        if (unsafe_moment <= self.unsafe_origin_moment) return 0;
        // The relative high resolution coarse time.
        const relative = coarsen.coarsenTime(unsafe_moment, self.cross_origin_isolated) - self.origin_moment;
        if (relative > 0) return relative;
        // After the origin, inside its tick: one tick.
        return coarsen.getResolution(self.cross_origin_isolated);
    }

    /// Get the current relative timestamp
    ///
    /// Per spec: "current relative timestamp" is the duration from
    /// the time origin to the current monotonic time.
    ///
    /// This is what Performance.now() returns.
    pub fn currentRelativeTimestamp(self: *const Self) clock.Nanoseconds {
        const current_time = self.source.monotonicTime();
        const coarsened = coarsen.coarsenTime(current_time, self.cross_origin_isolated);
        return coarsened - self.origin_moment;
    }

    /// Get the current relative timestamp in milliseconds
    ///
    /// This is the value returned by Performance.now()
    pub fn currentRelativeTimestampMs(self: *const Self) f64 {
        return clock.toMilliseconds(self.currentRelativeTimestamp());
    }

    /// Get the time origin timestamp
    ///
    /// Per spec "get time origin timestamp":
    /// 1. Let timeOrigin be the time origin
    /// 2. Return the duration from the estimated monotonic time of the
    ///    Unix epoch to timeOrigin
    ///
    /// This is what Performance.timeOrigin returns.
    pub fn getTimeOriginTimestamp(self: *const Self) clock.Nanoseconds {
        return self.origin_moment - self.estimated_epoch;
    }

    /// Get the time origin timestamp in milliseconds
    ///
    /// This is the value returned by Performance.timeOrigin
    pub fn getTimeOriginTimestampMs(self: *const Self) f64 {
        return clock.toMilliseconds(self.getTimeOriginTimestamp());
    }

    /// Get the current monotonic time (coarsened)
    ///
    /// Per spec: "current monotonic time" for an environment settings object
    /// is the coarsened current time from the monotonic clock.
    pub fn currentMonotonicTime(self: *const Self) clock.Nanoseconds {
        const current_time = self.source.monotonicTime();
        return coarsen.coarsenTime(current_time, self.cross_origin_isolated);
    }

    /// Get the current wall time (coarsened)
    ///
    /// Per spec: "current wall time" for an environment settings object
    /// is the coarsened current time from the wall clock.
    pub fn currentWallTime(self: *const Self) clock.Nanoseconds {
        const current_time = self.source.wallTime();
        return coarsen.coarsenTime(current_time, self.cross_origin_isolated);
    }
};

/// HR-Time 4: "Each group of environment settings objects that could
/// possibly communicate in any way has an estimated monotonic time of the
/// Unix epoch" - ONE moment for the group, initialized once, which every
/// member's timeOrigin (get time origin timestamp) is measured from. Crane's
/// group is the process: every Browser and worker in it reads the same two
/// clocks, and a process is a superset of each group that can communicate.
/// It is estimated once, at process start (`estimateAtProcessStart`, from
/// Performance's installHooks), and every reader on every thread after gets
/// that value. A process that never started (a unit test without
/// crane.Process) gets a fresh estimate per call, stored nowhere.
///
/// Before (lane flaky2), each Performance object made its own estimate from a
/// fresh wall and monotonic reading. A thread preempted between the two reads
/// moved its estimate by the preemption, so under load a worker's timeOrigin
/// could come out earlier than its creator's time when it was created
/// (hr-time/timeOrigin.html "Window and worker timeOrigins are close when
/// created one after another"). Gecko keeps one PerformanceService per
/// process (PerformanceService::GetOrCreate: one mCreationTimeStamp and
/// mCreationEpochTime pair that every window and worker timeOrigin is
/// computed from).
pub fn estimatedMonotonicTimeOfUnixEpoch() clock.Nanoseconds {
    return process_estimated_epoch.get() orelse estimateEpoch();
}

/// The estimated monotonic time of the Unix epoch on `source`: the
/// process's one estimate for the process's clocks; for a Browser's own
/// clocks (a virtual clock, which keeps its wall time a fixed offset from
/// its monotonic time) the same steps on them - exact, since nothing moves
/// between the two readings - so its time origins are measured on the
/// clocks its performance.now() reads.
pub fn estimatedMonotonicTimeOfUnixEpochOn(source: clock.Source) clock.Nanoseconds {
    if (source.isProcess()) return estimatedMonotonicTimeOfUnixEpoch();
    return coarsen.coarsenTime(source.monotonicTime() - source.wallTime(), false);
}

/// Estimate the process's estimated monotonic time of the Unix epoch. Once
/// per process, while it starts, before any Browser or worker thread exists
/// (Performance.installHooks, through crane.Process); a second call keeps
/// the first estimate. A Hook slot: the first estimate is written only while
/// the process starts (a unit test: through process_start.installForTest).
pub fn estimateAtProcessStart() void {
    if (process_estimated_epoch.get() == null) process_estimated_epoch.install(estimateEpoch());
}

/// The steps that initialize the estimated monotonic time of the Unix epoch
/// (HR-Time 4):
/// 1. Let wall time be the wall clock's unsafe current time
/// 2. Let monotonic time be the monotonic clock's unsafe current time
/// 3. Let epoch time be monotonic time - (wall time - Unix epoch)
/// 4. Initialize the estimated monotonic time of the Unix epoch to
///    the result of calling coarsen time with epoch time.
/// (wall time is ns since the Unix epoch, so step 3 is monotonic - wall.) The
/// estimate is shared across contexts, so it takes the default resolution.
fn estimateEpoch() clock.Nanoseconds {
    const wall_time = clock.WallClock.unsafeCurrentTime();
    const monotonic_time = clock.MonotonicClock.unsafeCurrentTime();
    return coarsen.coarsenTime(monotonic_time - wall_time, false);
}

// Null until the process starts; a process that never started it (a bare unit test with no
// crane.Process) reads a fresh estimate per call (estimatedMonotonicTimeOfUnixEpoch), stored nowhere.
// process-wide: HR-Time's one estimated monotonic time of the Unix epoch per group of settings objects that can communicate (the process is a superset of every group, and its Browsers on many threads share one monotonic and one wall clock; Gecko keeps one PerformanceService per process); written once while the process starts (Performance.installHooks), before any Browser or worker thread, and only read after.
var process_estimated_epoch: Hook(?clock.Nanoseconds) = .init(null);

/// Get the unsafe shared current time
///
/// Per spec: "unsafe shared current time" must return the
/// monotonic clock's unsafe current time.
///
/// This is NOT coarsened and should only be used internally.
pub fn unsafeSharedCurrentTime() clock.Nanoseconds {
    return clock.MonotonicClock.unsafeCurrentTime();
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

/// A time origin 10 us into the tick that starts at 1 s.
fn originTenMicrosecondsIntoATick(cross_origin_isolated: bool) TimeOrigin {
    return TimeOrigin.initAtUnsafe(std.time.ns_per_s + 10_000, 0, cross_origin_isolated);
}

test "initAtUnsafe coarsens the origin and keeps its unsafe moment" {
    const origin = originTenMicrosecondsIntoATick(false);
    try testing.expectEqual(@as(clock.Nanoseconds, std.time.ns_per_s), origin.origin_moment);
    try testing.expectEqual(@as(clock.Nanoseconds, std.time.ns_per_s + 10_000), origin.unsafe_origin_moment);
}

test "moveTo makes a navigation's start the origin, coarsened" {
    var origin = originTenMicrosecondsIntoATick(false);
    origin.moveTo(2 * std.time.ns_per_s + 130_000);
    try testing.expectEqual(@as(clock.Nanoseconds, 2 * std.time.ns_per_s + 125_000), origin.origin_moment);
    try testing.expectEqual(@as(clock.Nanoseconds, 2 * std.time.ns_per_s + 130_000), origin.unsafe_origin_moment);
}

test "a fetch moment after the origin inside its tick is one tick, not 0" {
    const origin = originTenMicrosecondsIntoATick(false);
    // 49 us later (nav2-test-redirect-server's redirectStart), same tick.
    try testing.expectEqual(@as(clock.Nanoseconds, 125_000), origin.relativeFetchTime(std.time.ns_per_s + 59_000));
    // The last nanosecond of the tick.
    try testing.expectEqual(@as(clock.Nanoseconds, 125_000), origin.relativeFetchTime(std.time.ns_per_s + 124_999));
    // One nanosecond after the origin.
    try testing.expectEqual(@as(clock.Nanoseconds, 125_000), origin.relativeFetchTime(std.time.ns_per_s + 10_001));
}

test "a fetch moment at or before the origin is 0" {
    const origin = originTenMicrosecondsIntoATick(false);
    try testing.expectEqual(@as(clock.Nanoseconds, 0), origin.relativeFetchTime(std.time.ns_per_s + 10_000));
    // Before the origin, in its tick.
    try testing.expectEqual(@as(clock.Nanoseconds, 0), origin.relativeFetchTime(std.time.ns_per_s + 5_000));
    // Before the origin's tick.
    try testing.expectEqual(@as(clock.Nanoseconds, 0), origin.relativeFetchTime(std.time.ns_per_s - 300_000));
}

test "a fetch moment past the origin's tick is its relative coarse time" {
    const origin = originTenMicrosecondsIntoATick(false);
    // The next tick: its start, then a moment inside it.
    try testing.expectEqual(@as(clock.Nanoseconds, 125_000), origin.relativeFetchTime(std.time.ns_per_s + 125_000));
    try testing.expectEqual(@as(clock.Nanoseconds, 125_000), origin.relativeFetchTime(std.time.ns_per_s + 249_999));
    try testing.expectEqual(@as(clock.Nanoseconds, 250_000), origin.relativeFetchTime(std.time.ns_per_s + 250_000));
    // 1.049 ms after the origin floors to the origin's tick + 1 ms.
    try testing.expectEqual(@as(clock.Nanoseconds, std.time.ns_per_ms), origin.relativeFetchTime(std.time.ns_per_s + 1_059_000));
}

test "a cross-origin isolated fetch moment inside the origin's tick is one 15.625 us tick" {
    const origin = originTenMicrosecondsIntoATick(true);
    // 1 s + 10 us is 64000.64 ticks of 15.625 us: the origin floors to
    // 1 s, and its tick ends at 1 s + 15.625 us.
    try testing.expectEqual(@as(clock.Nanoseconds, std.time.ns_per_s), origin.origin_moment);
    try testing.expectEqual(@as(clock.Nanoseconds, 15_625), origin.relativeFetchTime(std.time.ns_per_s + 12_000));
    try testing.expectEqual(@as(clock.Nanoseconds, 15_625), origin.relativeFetchTime(std.time.ns_per_s + 20_000));
    try testing.expectEqual(@as(clock.Nanoseconds, 31_250), origin.relativeFetchTime(std.time.ns_per_s + 40_000));
}

test "a time origin made from a coarse moment stands for its unsafe moment" {
    const origin = TimeOrigin.initWithOrigin(std.time.ns_per_s, 0, false);
    try testing.expectEqual(@as(clock.Nanoseconds, 0), origin.relativeFetchTime(std.time.ns_per_s));
    try testing.expectEqual(@as(clock.Nanoseconds, 125_000), origin.relativeFetchTime(std.time.ns_per_s + 1));
}
