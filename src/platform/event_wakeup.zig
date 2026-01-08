//! Event Wakeup Platform Abstraction
//!
//! Cross-platform event notification primitive for waking up waiting threads.
//! Inspired by TigerBeetle's wakeup mechanism for efficient thread coordination.
//!
//! This provides a lightweight, zero-allocation-after-init way to signal
//! between threads without busy-polling.
//!
//! ## Platform Implementations
//!
//! - **Linux**: Uses eventfd(2) - a lightweight semaphore-like file descriptor
//! - **macOS**: Uses kqueue with EVFILT_USER for manual triggering
//!
//! ## Usage
//!
//! ```zig
//! var wakeup = try EventWakeup.init();
//! defer wakeup.deinit();
//!
//! // In worker thread:
//! wakeup.signal();  // Thread-safe, non-blocking
//!
//! // In main thread:
//! const was_signaled = try wakeup.wait(1000);  // Wait up to 1s
//! ```
//!
//! ## Spec Reference
//!
//! This supports the HTML Standard's event loop requirement for efficient
//! inter-thread communication when workers post messages to the main thread.
//! See: https://html.spec.whatwg.org/#event-loops

const std = @import("std");
const builtin = @import("builtin");

/// Cross-platform event notification primitive.
///
/// Provides efficient thread wakeup without busy-polling:
/// - Linux: eventfd(2) - lightweight semaphore-like fd
/// - macOS: kqueue with EVFILT_USER for manual triggering
pub const EventWakeup = struct {
    /// File descriptor (eventfd on Linux, kqueue on macOS)
    fd: std.posix.fd_t,
    /// Platform-specific implementation
    platform: Platform,

    pub const Platform = enum {
        linux_eventfd,
        darwin_kqueue,
    };

    /// Create a new event wakeup primitive
    ///
    /// Returns an initialized EventWakeup that can be signaled from any thread
    /// and waited on from any thread.
    pub fn init() !EventWakeup {
        if (builtin.os.tag == .linux) {
            // Linux: Use eventfd for lightweight signaling
            // EFD_NONBLOCK: Don't block on read/write
            // EFD_CLOEXEC: Close on exec
            const fd = try std.posix.eventfd(0, .{ .NONBLOCK = true, .CLOEXEC = true });
            return .{ .fd = fd, .platform = .linux_eventfd };
        } else if (builtin.os.tag == .macos) {
            // macOS: Use kqueue with EVFILT_USER for manual triggering
            const kq = try std.posix.kqueue();
            errdefer std.posix.close(kq);

            // Register EVFILT_USER for manual triggering
            // EV_ADD: Add the event
            // EV_CLEAR: Clear the event after delivery (edge-triggered)
            var changelist = [_]std.posix.Kevent{.{
                .ident = 1, // Use 1 as our event identifier
                .filter = std.posix.system.EVFILT.USER,
                .flags = std.posix.system.EV.ADD | std.posix.system.EV.CLEAR,
                .fflags = 0,
                .data = 0,
                .udata = 0,
            }};
            _ = try std.posix.kevent(kq, &changelist, &[_]std.posix.Kevent{}, null);
            return .{ .fd = kq, .platform = .darwin_kqueue };
        } else {
            return error.UnsupportedPlatform;
        }
    }

    /// Signal the event (wake up waiters). Thread-safe.
    ///
    /// This is safe to call from any thread and will immediately wake up
    /// any thread blocked in wait(). Multiple signals before a wait()
    /// are coalesced into a single wakeup.
    pub fn signal(self: *EventWakeup) void {
        switch (self.platform) {
            .linux_eventfd => {
                // Write 1 to the eventfd to signal
                const value: u64 = 1;
                _ = std.posix.write(self.fd, std.mem.asBytes(&value)) catch {};
            },
            .darwin_kqueue => {
                // Trigger the EVFILT_USER event
                var changelist = [_]std.posix.Kevent{.{
                    .ident = 1,
                    .filter = std.posix.system.EVFILT.USER,
                    .flags = 0,
                    .fflags = std.posix.system.NOTE.TRIGGER,
                    .data = 0,
                    .udata = 0,
                }};
                _ = std.posix.kevent(self.fd, &changelist, &[_]std.posix.Kevent{}, null) catch {};
            },
        }
    }

    /// Wait for signal or timeout.
    ///
    /// Blocks until either:
    /// - The event is signaled via signal() - returns true
    /// - The timeout expires - returns false
    /// - null timeout means wait indefinitely
    ///
    /// After a successful wait, the event is reset (consumed).
    pub fn wait(self: *EventWakeup, timeout_ms: ?u32) !bool {
        switch (self.platform) {
            .linux_eventfd => {
                // Poll the eventfd with timeout
                var pollfds = [_]std.posix.pollfd{.{
                    .fd = self.fd,
                    .events = std.posix.POLL.IN,
                    .revents = 0,
                }};
                const timeout: i32 = if (timeout_ms) |t| @intCast(t) else -1;
                const result = try std.posix.poll(&pollfds, timeout);
                if (result > 0 and (pollfds[0].revents & std.posix.POLL.IN) != 0) {
                    // Consume the event by reading
                    var buf: u64 = undefined;
                    _ = std.posix.read(self.fd, std.mem.asBytes(&buf)) catch {};
                    return true;
                }
                return false;
            },
            .darwin_kqueue => {
                // Wait for kevent with timeout
                var eventlist: [1]std.posix.Kevent = undefined;
                const ts: ?std.posix.timespec = if (timeout_ms) |t| .{
                    .sec = @intCast(t / 1000),
                    .nsec = @intCast((t % 1000) * 1_000_000),
                } else null;
                const result = try std.posix.kevent(self.fd, &[_]std.posix.Kevent{}, &eventlist, if (ts) |*s| s else null);
                return result > 0;
            },
        }
    }

    /// Get the file descriptor for advanced use cases (e.g., adding to poll set)
    pub fn getFd(self: *const EventWakeup) std.posix.fd_t {
        return self.fd;
    }

    /// Clean up resources
    pub fn deinit(self: *EventWakeup) void {
        std.posix.close(self.fd);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "EventWakeup - basic signal and wait" {
    var wakeup = try EventWakeup.init();
    defer wakeup.deinit();

    // Signal before wait - should return immediately
    wakeup.signal();

    const signaled = try wakeup.wait(100); // 100ms timeout
    try std.testing.expect(signaled);
}

test "EventWakeup - timeout when not signaled" {
    var wakeup = try EventWakeup.init();
    defer wakeup.deinit();

    // Wait without signal - should timeout
    const start = std.time.milliTimestamp();
    const signaled = try wakeup.wait(50); // 50ms timeout
    const elapsed = std.time.milliTimestamp() - start;

    try std.testing.expect(!signaled);
    try std.testing.expect(elapsed >= 40); // Allow some timing slack
}

test "EventWakeup - cross-thread signal" {
    var wakeup = try EventWakeup.init();
    defer wakeup.deinit();

    var signaled = false;
    var thread_done = false;

    // Spawn a thread that will signal after a short delay
    const thread = try std.Thread.spawn(.{}, struct {
        fn run(w: *EventWakeup, done: *bool) void {
            std.Thread.sleep(10 * std.time.ns_per_ms); // 10ms delay
            w.signal();
            done.* = true;
        }
    }.run, .{ &wakeup, &thread_done });

    // Wait for signal from other thread
    signaled = try wakeup.wait(1000); // 1s timeout

    thread.join();

    try std.testing.expect(signaled);
    try std.testing.expect(thread_done);
}
