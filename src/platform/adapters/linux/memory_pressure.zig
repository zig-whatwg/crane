//! The linux platform's memory-pressure observer (docs/platform-protocol.md
//! 3.3 and 7): one thread per Browser that reads /proc/meminfo and the
//! memory files of the process's cgroup, and posts a `memory_pressure` event
//! through the Browser's EventSink when the level changes.
//!
//! Linux gives a desktop process no notification, so the browsers that
//! answer memory pressure there poll (kit/posix/meminfo.zig has the rule and
//! where each number comes from):
//!
//! - WebKit: a thread "MemoryPressureMonitor" in its UI process
//!   (Source/WebKit/UIProcess/linux/MemoryPressureMonitor.cpp) polls every
//!   5 s, faster as memory fills, down to 1 s. It judges a process inside a
//!   cgroup with a memory limit against that limit too, and so does this
//!   one (`meminfo.readLevel`).
//! - Firefox: a thread "MemoryPoller" (xpcom/base/
//!   AvailableMemoryWatcherLinux.cpp) polls every 5 s, every 1 s while
//!   memory is low.
//! - Chromium: no monitor on desktop Linux.
//!
//! Crane's: every 5 s at the normal level, every 1 s at warning or critical
//! (Firefox's two periods; WebKit's ends), on a thread of the Browser's
//! platform state. It posts only when the level CHANGES - an edge, as the
//! darwin platform's dispatch source reports one - where WebKit notifies
//! again at every poll and relies on its handler's hold-off; the first
//! reading is compared with the normal level, so a Browser made on a machine
//! already short of memory is told. `stop` wakes the thread at once and
//! joins it: no post is made after it returns.
//!
//! The thread is compiled in only for Linux: the conformance test builds
//! every platform on every host.

const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform");
const posix = @import("kit_posix");

/// The poll's period at the normal level.
pub const normal_period_ns: u64 = 5 * std.time.ns_per_s;
/// The poll's period at warning or critical.
pub const pressure_period_ns: u64 = 1 * std.time.ns_per_s;

const enabled = builtin.os.tag == .linux;

pub const Observer = struct {
    /// The Browser's sink, BORROWED until `stop` returns.
    events: platform.EventSink = undefined,
    thread: ?platform.Thread = null,
    /// The word the poller sleeps on: 0 while it runs, 1 to end it.
    stopping: std.atomic.Value(u32) = .init(0),

    /// Start the poller. `self` is at its final address. With no thread to
    /// be had the Browser has no observer, and is told nothing.
    pub fn start(self: *Observer, events: platform.EventSink) void {
        if (comptime !enabled) return;
        self.events = events;
        self.thread = posix.spawnThread(.{ .name = .from("crane-mempress") }, run, self) catch null;
    }

    /// End the poller and wait for its thread: it posts nothing after this
    /// returns. Nothing for an observer that never started.
    pub fn stop(self: *Observer) void {
        const thread = self.thread orelse return;
        self.thread = null;
        self.stopping.store(1, .release);
        futexIo().futexWake(u32, &self.stopping.raw, 1);
        posix.joinThread(thread);
    }

    fn run(context: ?*anyopaque) callconv(.c) void {
        const self: *Observer = @ptrCast(@alignCast(context.?));
        var last: platform.MemoryPressureLevel = .normal;
        while (self.stopping.load(.acquire) == 0) {
            var period = normal_period_ns;
            if (posix.meminfo.readLevel()) |level| {
                if (level != last) {
                    last = level;
                    const event: platform.PlatformEvent = .{ .kind = .memory_pressure, .memory_pressure = level };
                    self.events.post(self.events.context, &event);
                }
                if (level != .normal) period = pressure_period_ns;
            }
            // Returns at once when `stop` already stored 1; a spurious
            // return only reads the file early.
            futexIo().futexWaitTimeout(u32, &self.stopping.raw, 0, .{ .duration = .{
                .raw = .fromNanoseconds(period),
                .clock = .awake,
            } }) catch {};
        }
    }
};

/// The futex calls' `Io`: plain system calls on an address, the same
/// through any `Io.Threaded` (as runtime.TaskSink's wait).
fn futexIo() std.Io {
    return std.Io.Threaded.global_single_threaded.io();
}
