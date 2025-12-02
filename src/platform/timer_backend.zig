//! Platform Timer Backend Abstraction
//!
//! Provides a pluggable interface for timer operations, allowing the event loop
//! to work with different timer implementations (real OS timers, mock timers for
//! testing, etc.).
//!
//! The timer backend is responsible for:
//! - Getting the current time
//! - Scheduling wake-ups at specific times
//! - Cancelling scheduled wake-ups

const std = @import("std");

/// Abstract timer backend interface.
///
/// This uses a vtable pattern to allow different implementations
/// (real timers, mock timers) to be swapped at runtime.
pub const TimerBackend = struct {
    /// Implementation pointer.
    ptr: *anyopaque,

    /// Virtual function table.
    vtable: *const VTable,

    pub const VTable = struct {
        /// Get the current time in milliseconds since epoch.
        getCurrentTime: *const fn (ptr: *anyopaque) i64,

        /// Get the current high-resolution time in nanoseconds.
        /// Used for performance timing.
        getHighResTime: *const fn (ptr: *anyopaque) i64,

        /// Schedule a wake-up at the specified time (milliseconds since epoch).
        /// The wake-up callback will be invoked when the time is reached.
        scheduleWakeup: *const fn (ptr: *anyopaque, time_ms: i64) void,

        /// Cancel any pending wake-up.
        cancelWakeup: *const fn (ptr: *anyopaque) void,

        /// Sleep until the next scheduled wake-up or until the specified timeout.
        /// Returns the actual time slept in milliseconds.
        sleepUntilWakeup: *const fn (ptr: *anyopaque, timeout_ms: ?i64) i64,

        /// Free any resources associated with this backend.
        deinit: *const fn (ptr: *anyopaque) void,
    };

    /// Get the current time in milliseconds since epoch.
    pub fn getCurrentTime(self: TimerBackend) i64 {
        return self.vtable.getCurrentTime(self.ptr);
    }

    /// Get the current high-resolution time in nanoseconds.
    pub fn getHighResTime(self: TimerBackend) i64 {
        return self.vtable.getHighResTime(self.ptr);
    }

    /// Schedule a wake-up at the specified time.
    pub fn scheduleWakeup(self: TimerBackend, time_ms: i64) void {
        self.vtable.scheduleWakeup(self.ptr, time_ms);
    }

    /// Cancel any pending wake-up.
    pub fn cancelWakeup(self: TimerBackend) void {
        self.vtable.cancelWakeup(self.ptr);
    }

    /// Sleep until the next scheduled wake-up or timeout.
    pub fn sleepUntilWakeup(self: TimerBackend, timeout_ms: ?i64) i64 {
        return self.vtable.sleepUntilWakeup(self.ptr, timeout_ms);
    }

    /// Free resources.
    pub fn deinit(self: TimerBackend) void {
        self.vtable.deinit(self.ptr);
    }
};

/// Mock timer backend for testing.
///
/// Allows precise control over time progression without real delays.
/// Time only advances when explicitly advanced via advanceTime().
pub const MockTimerBackend = struct {
    /// Current simulated time in milliseconds.
    current_time_ms: i64,

    /// High-resolution time in nanoseconds.
    high_res_time_ns: i64,

    /// Scheduled wake-up time, if any.
    scheduled_wakeup: ?i64,

    /// Allocator for cleanup.
    allocator: std.mem.Allocator,

    /// Initialize a new mock timer backend.
    pub fn init(allocator: std.mem.Allocator) !*MockTimerBackend {
        const self = try allocator.create(MockTimerBackend);
        self.* = MockTimerBackend{
            .current_time_ms = 0,
            .high_res_time_ns = 0,
            .scheduled_wakeup = null,
            .allocator = allocator,
        };
        return self;
    }

    /// Set the current time.
    pub fn setCurrentTime(self: *MockTimerBackend, time_ms: i64) void {
        self.current_time_ms = time_ms;
        self.high_res_time_ns = time_ms * 1_000_000;
    }

    /// Advance time by the specified duration.
    /// Returns true if a wake-up was triggered.
    pub fn advanceTime(self: *MockTimerBackend, delta_ms: i64) bool {
        const new_time = self.current_time_ms + delta_ms;
        self.current_time_ms = new_time;
        self.high_res_time_ns = new_time * 1_000_000;

        // Check if we passed a scheduled wake-up
        if (self.scheduled_wakeup) |wakeup| {
            if (new_time >= wakeup) {
                self.scheduled_wakeup = null;
                return true;
            }
        }
        return false;
    }

    /// Get the time until the next wake-up, or null if none scheduled.
    pub fn getTimeUntilWakeup(self: *const MockTimerBackend) ?i64 {
        if (self.scheduled_wakeup) |wakeup| {
            const delta = wakeup - self.current_time_ms;
            return if (delta > 0) delta else 0;
        }
        return null;
    }

    /// Create a TimerBackend interface for this mock.
    pub fn backend(self: *MockTimerBackend) TimerBackend {
        return TimerBackend{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    const vtable = TimerBackend.VTable{
        .getCurrentTime = getCurrentTimeImpl,
        .getHighResTime = getHighResTimeImpl,
        .scheduleWakeup = scheduleWakeupImpl,
        .cancelWakeup = cancelWakeupImpl,
        .sleepUntilWakeup = sleepUntilWakeupImpl,
        .deinit = deinitImpl,
    };

    fn getCurrentTimeImpl(ptr: *anyopaque) i64 {
        const self: *MockTimerBackend = @ptrCast(@alignCast(ptr));
        return self.current_time_ms;
    }

    fn getHighResTimeImpl(ptr: *anyopaque) i64 {
        const self: *MockTimerBackend = @ptrCast(@alignCast(ptr));
        return self.high_res_time_ns;
    }

    fn scheduleWakeupImpl(ptr: *anyopaque, time_ms: i64) void {
        const self: *MockTimerBackend = @ptrCast(@alignCast(ptr));
        // Only schedule if it's earlier than current scheduled time
        if (self.scheduled_wakeup) |current| {
            if (time_ms < current) {
                self.scheduled_wakeup = time_ms;
            }
        } else {
            self.scheduled_wakeup = time_ms;
        }
    }

    fn cancelWakeupImpl(ptr: *anyopaque) void {
        const self: *MockTimerBackend = @ptrCast(@alignCast(ptr));
        self.scheduled_wakeup = null;
    }

    fn sleepUntilWakeupImpl(ptr: *anyopaque, timeout_ms: ?i64) i64 {
        const self: *MockTimerBackend = @ptrCast(@alignCast(ptr));

        // In mock mode, we don't actually sleep.
        // Just advance time to the wake-up time or timeout.
        var sleep_time: i64 = 0;

        if (self.scheduled_wakeup) |wakeup| {
            const delta = wakeup - self.current_time_ms;
            if (delta > 0) {
                if (timeout_ms) |timeout| {
                    sleep_time = @min(delta, timeout);
                } else {
                    sleep_time = delta;
                }
            }
        } else if (timeout_ms) |timeout| {
            sleep_time = timeout;
        }

        if (sleep_time > 0) {
            _ = self.advanceTime(sleep_time);
        }

        return sleep_time;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *MockTimerBackend = @ptrCast(@alignCast(ptr));
        self.allocator.destroy(self);
    }
};

/// Real timer backend using system time.
///
/// Uses std.time for actual timing operations.
pub const RealTimerBackend = struct {
    /// Scheduled wake-up time, if any.
    scheduled_wakeup: ?i64,

    /// Allocator for cleanup.
    allocator: std.mem.Allocator,

    /// Initialize a new real timer backend.
    pub fn init(allocator: std.mem.Allocator) !*RealTimerBackend {
        const self = try allocator.create(RealTimerBackend);
        self.* = RealTimerBackend{
            .scheduled_wakeup = null,
            .allocator = allocator,
        };
        return self;
    }

    /// Create a TimerBackend interface for this real backend.
    pub fn backend(self: *RealTimerBackend) TimerBackend {
        return TimerBackend{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    const vtable = TimerBackend.VTable{
        .getCurrentTime = getCurrentTimeImpl,
        .getHighResTime = getHighResTimeImpl,
        .scheduleWakeup = scheduleWakeupImpl,
        .cancelWakeup = cancelWakeupImpl,
        .sleepUntilWakeup = sleepUntilWakeupImpl,
        .deinit = deinitImpl,
    };

    fn getCurrentTimeImpl(_: *anyopaque) i64 {
        return std.time.milliTimestamp();
    }

    fn getHighResTimeImpl(_: *anyopaque) i64 {
        return std.time.nanoTimestamp();
    }

    fn scheduleWakeupImpl(ptr: *anyopaque, time_ms: i64) void {
        const self: *RealTimerBackend = @ptrCast(@alignCast(ptr));
        if (self.scheduled_wakeup) |current| {
            if (time_ms < current) {
                self.scheduled_wakeup = time_ms;
            }
        } else {
            self.scheduled_wakeup = time_ms;
        }
    }

    fn cancelWakeupImpl(ptr: *anyopaque) void {
        const self: *RealTimerBackend = @ptrCast(@alignCast(ptr));
        self.scheduled_wakeup = null;
    }

    fn sleepUntilWakeupImpl(ptr: *anyopaque, timeout_ms: ?i64) i64 {
        const self: *RealTimerBackend = @ptrCast(@alignCast(ptr));

        const start_time = std.time.milliTimestamp();
        var sleep_time: i64 = 0;

        if (self.scheduled_wakeup) |wakeup| {
            const delta = wakeup - start_time;
            if (delta > 0) {
                if (timeout_ms) |timeout| {
                    sleep_time = @min(delta, timeout);
                } else {
                    sleep_time = delta;
                }
            }
        } else if (timeout_ms) |timeout| {
            sleep_time = timeout;
        }

        if (sleep_time > 0) {
            std.time.sleep(@intCast(sleep_time * 1_000_000));
        }

        return std.time.milliTimestamp() - start_time;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *RealTimerBackend = @ptrCast(@alignCast(ptr));
        self.allocator.destroy(self);
    }
};

test "MockTimerBackend - basic time operations" {
    const allocator = std.testing.allocator;

    const mock = try MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    try std.testing.expectEqual(@as(i64, 0), mock.current_time_ms);

    mock.setCurrentTime(1000);
    try std.testing.expectEqual(@as(i64, 1000), mock.current_time_ms);

    _ = mock.advanceTime(500);
    try std.testing.expectEqual(@as(i64, 1500), mock.current_time_ms);
}

test "MockTimerBackend - wake-up scheduling" {
    const allocator = std.testing.allocator;

    const mock = try MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    mock.setCurrentTime(1000);

    const timer_backend = mock.backend();

    // Schedule a wake-up at time 2000
    timer_backend.scheduleWakeup(2000);
    try std.testing.expectEqual(@as(?i64, 2000), mock.scheduled_wakeup);

    // Advance time but not past wake-up
    const triggered1 = mock.advanceTime(500);
    try std.testing.expect(!triggered1);
    try std.testing.expectEqual(@as(?i64, 2000), mock.scheduled_wakeup);

    // Advance time past wake-up
    const triggered2 = mock.advanceTime(600);
    try std.testing.expect(triggered2);
    try std.testing.expectEqual(@as(?i64, null), mock.scheduled_wakeup);
}

test "MockTimerBackend - cancel wake-up" {
    const allocator = std.testing.allocator;

    const mock = try MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const timer_backend = mock.backend();

    timer_backend.scheduleWakeup(2000);
    try std.testing.expect(mock.scheduled_wakeup != null);

    timer_backend.cancelWakeup();
    try std.testing.expectEqual(@as(?i64, null), mock.scheduled_wakeup);
}

test "MockTimerBackend - TimerBackend interface" {
    const allocator = std.testing.allocator;

    const mock = try MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    mock.setCurrentTime(5000);

    const timer_backend = mock.backend();

    try std.testing.expectEqual(@as(i64, 5000), timer_backend.getCurrentTime());
    try std.testing.expectEqual(@as(i64, 5000 * 1_000_000), timer_backend.getHighResTime());
}

test "MockTimerBackend - sleepUntilWakeup" {
    const allocator = std.testing.allocator;

    const mock = try MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    mock.setCurrentTime(1000);

    const timer_backend = mock.backend();

    // Schedule wake-up at 1500
    timer_backend.scheduleWakeup(1500);

    // Sleep until wake-up
    const slept = timer_backend.sleepUntilWakeup(null);
    try std.testing.expectEqual(@as(i64, 500), slept);
    try std.testing.expectEqual(@as(i64, 1500), mock.current_time_ms);
}

test "MockTimerBackend - sleepUntilWakeup with timeout" {
    const allocator = std.testing.allocator;

    const mock = try MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    mock.setCurrentTime(1000);

    const timer_backend = mock.backend();

    // Schedule wake-up at 2000
    timer_backend.scheduleWakeup(2000);

    // Sleep with timeout of 300ms (less than 1000ms to wake-up)
    const slept = timer_backend.sleepUntilWakeup(300);
    try std.testing.expectEqual(@as(i64, 300), slept);
    try std.testing.expectEqual(@as(i64, 1300), mock.current_time_ms);
}
