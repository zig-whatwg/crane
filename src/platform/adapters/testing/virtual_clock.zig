//! The testing platform's virtual clock (docs/platform-protocol.md 6.2 and
//! section 9): a Browser's clock of its own, opt in with
//! PlatformBrowserOptions.virtual_clock.
//!
//! Chromium's TaskEnvironment::TimeSource::MOCK_TIME is the model ("Delayed
//! tasks use a mock clock which only advances when reaching 'idle' ... time
//! advances to the soonest delay", base/test/task_environment.h): the clock
//! stands still while the Browser works and moves only when
//! - its event loop is idle - no runnable task, no I/O in flight - and a
//!   timer is due: the loop fast-forwards it to that wake-up
//!   (`fastForwardTo`, TimeDomain::MaybeFastForwardToWakeUp), or
//! - a test advances it (`advance`, MOCK_TIME's FastForwardBy without the
//!   task running: the test then turns the Browser's event loop).
//! So work never takes time: a page that busy-waits on performance.now() or
//! Date.now() never sees time pass, as under MOCK_TIME; a timer-heavy page
//! runs as fast as its callbacks, and replays its timer order exactly.
//!
//! Per Browser, never per process: Chromium's MOCK_TIME and Blink's virtual
//! time override the process clock (ScopedTimeClockOverrides), which works
//! because a renderer runs one page; Crane runs many Browsers in a process.
//! Monotonic and wall time move together: the wall clock is the monotonic one
//! plus a fixed offset, so nothing a page reads ever jumps on its own.
//!
//! Reads and moves are atomic: the Browser's thread moves it, and any thread
//! may read it (the platform contract's "any thread").

const std = @import("std");
const platform = @import("platform");

/// Where the monotonic clock starts: an arbitrary origin, as every monotonic
/// clock's, but never 0, which several timestamps use for "not yet" (the
/// event loop's last idle period start, the frame clock's last opportunity).
pub const monotonic_origin_ns: u64 = 1_000 * std.time.ns_per_s;

pub const VirtualClock = struct {
    /// Whether the Browser asked for it; a Browser that did not reads the
    /// platform's own clocks (`browserClock` answers `.real`).
    enabled: bool,
    /// The monotonic clock's current time, ns.
    now_ns: std.atomic.Value(u64),
    /// The wall clock is the monotonic one plus this: ns since the epoch at
    /// monotonic 0.
    wall_offset_ns: i64,

    pub fn init(options: *const platform.PlatformBrowserOptions) VirtualClock {
        const wall_start_ns = options.virtual_clock_wall_start_ms * std.time.ns_per_ms;
        return .{
            .enabled = options.virtual_clock,
            .now_ns = .init(monotonic_origin_ns),
            .wall_offset_ns = wall_start_ns - @as(i64, @intCast(monotonic_origin_ns)),
        };
    }

    /// The protocol's BrowserClock for this Browser.
    pub fn browserClock(self: *VirtualClock) platform.BrowserClock {
        if (!self.enabled) return .real;
        return .{
            .context = self,
            .monotonic_now = monotonicNow,
            .wall_now = wallNow,
            .fast_forward_to = fastForwardTo,
        };
    }

    /// Test control: move the clock `nanoseconds` on. Nothing for a Browser
    /// whose clock is the platform's.
    pub fn advance(self: *VirtualClock, nanoseconds: u64) void {
        if (!self.enabled) return;
        _ = self.now_ns.fetchAdd(nanoseconds, .acq_rel);
    }

    fn of(context: ?*anyopaque) *VirtualClock {
        return @ptrCast(@alignCast(context.?));
    }

    fn monotonicNow(context: ?*anyopaque) callconv(.c) u64 {
        return of(context).now_ns.load(.acquire);
    }

    fn wallNow(context: ?*anyopaque) callconv(.c) i64 {
        const self = of(context);
        return self.wall_offset_ns + @as(i64, @intCast(self.now_ns.load(.acquire)));
    }

    fn fastForwardTo(context: ?*anyopaque, wake_up: u64) callconv(.c) bool {
        // Never back: a wake-up already past only means nothing need wait.
        _ = of(context).now_ns.fetchMax(wake_up, .acq_rel);
        return true;
    }
};
