//! Media fetching progress, with an owned timer ticket and no script callback.
const std = @import("std");

/// Reuse the existing realm-timer cancellation protocol: a failed clear detaches
/// the owner, leaving only an inert ticket for a late callback to free.
pub fn Deadline(comptime Timer: type) type {
    return struct {
        timer: @import("eventsource").Retry(Timer) = .{},
        pub fn start(self: *@This(), allocator: std.mem.Allocator, timer: Timer, delay: u64, callback: *const fn (*anyopaque) void, context: *anyopaque) !void {
            try self.timer.start(allocator, timer, delay, callback, context);
        }
        pub fn cancel(self: *@This()) void {
            self.timer.cancel();
        }
        pub fn pending(self: *const @This()) bool {
            return self.timer.ticket != null;
        }
    };
}

/// Resource fetch algorithm: report bytes at most every 350ms, and one stalled
/// notification after the UA's stall timeout (3s) until progress resumes.
pub const Progress = struct {
    bytes_pending: bool = false,
    stalled: bool = false,
    pub fn reset(self: *@This()) void {
        self.* = .{};
    }
    pub fn received(self: *@This()) void {
        self.bytes_pending = true;
    }
    pub fn takeProgress(self: *@This()) bool {
        if (!self.bytes_pending) return false;
        self.bytes_pending = false;
        self.stalled = false;
        return true;
    }
    pub fn takeStalled(self: *@This()) bool {
        if (self.stalled) return false;
        self.stalled = true;
        return true;
    }
};
