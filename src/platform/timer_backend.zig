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
    /// KEEP: VTable polymorphism - type erasure for pluggable backend implementations
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
        const ns: i128 = std.time.nanoTimestamp();
        return @intCast(@mod(ns, std.math.maxInt(i64)));
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
            std.Thread.sleep(@intCast(sleep_time * 1_000_000));
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

// =============================================================================
// Global Default Timer Backend
// =============================================================================

/// Thread-local default timer backend instance.
/// Lazily initialized on first access via getDefault().
threadlocal var default_backend_instance: ?*RealTimerBackend = null;

/// Optional custom timer backend override.
/// Embedders can set this to provide platform-specific timing.
threadlocal var custom_backend: ?TimerBackend = null;

/// Allocator used for the default backend (needed for cleanup).
threadlocal var default_backend_allocator: ?std.mem.Allocator = null;

/// Get the current timer backend.
///
/// Returns (in order of precedence):
/// 1. Custom backend if set via setCustomBackend()
/// 2. Default RealTimerBackend (lazily initialized)
///
/// The default backend uses std.time for portable timing that works
/// on all platforms Zig supports.
///
/// For most uses, this just works without any setup. Embedders who need
/// native platform integration (iOS RunLoop, Android Looper, etc.) can
/// call setCustomBackend() to override.
pub fn getDefault(allocator: std.mem.Allocator) !TimerBackend {
    // Return custom backend if set
    if (custom_backend) |backend| {
        return backend;
    }

    // Lazily initialize default backend
    if (default_backend_instance == null) {
        default_backend_instance = try RealTimerBackend.init(allocator);
        default_backend_allocator = allocator;
    }

    return default_backend_instance.?.backend();
}

/// Get the current timer backend if available, without initializing.
///
/// Returns null if no backend is available (neither custom nor default initialized).
/// Use getDefault() if you want automatic initialization.
pub fn getCurrent() ?TimerBackend {
    if (custom_backend) |backend| {
        return backend;
    }
    if (default_backend_instance) |instance| {
        return instance.backend();
    }
    return null;
}

/// Set a custom timer backend.
///
/// This overrides the default RealTimerBackend. Use this when you need
/// platform-specific timing integration (e.g., iOS RunLoop, Android Looper).
///
/// Pass null to clear the custom backend and revert to the default.
pub fn setCustomBackend(backend: ?TimerBackend) void {
    custom_backend = backend;
}

/// Cleanup the default timer backend.
///
/// Call this during shutdown to free resources. After calling this,
/// getDefault() will create a new instance on next access.
///
/// Note: This does NOT cleanup custom backends - embedders are responsible
/// for managing their own backend lifecycle.
pub fn deinitDefault() void {
    if (default_backend_instance) |instance| {
        instance.allocator.destroy(instance);
        default_backend_instance = null;
        default_backend_allocator = null;
    }
}

test "getDefault - returns RealTimerBackend" {
    const allocator = std.testing.allocator;

    // Get default backend
    const backend = try getDefault(allocator);
    defer deinitDefault();

    // Should return current time (non-zero after epoch)
    const time = backend.getCurrentTime();
    try std.testing.expect(time > 0);
}

test "setCustomBackend - overrides default" {
    const allocator = std.testing.allocator;

    // Create a mock backend
    const mock = try MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    mock.setCurrentTime(12345);

    // Set as custom backend
    setCustomBackend(mock.backend());
    defer setCustomBackend(null);

    // getDefault should return the custom backend
    const backend = try getDefault(allocator);

    // Should return mock's time, not real time
    const time = backend.getCurrentTime();
    try std.testing.expectEqual(@as(i64, 12345), time);
}

test "getCurrent - returns null when not initialized" {
    // Clear any existing state
    setCustomBackend(null);
    deinitDefault();

    // Should return null
    const backend = getCurrent();
    try std.testing.expect(backend == null);
}

test "getCurrent - returns backend after getDefault" {
    const allocator = std.testing.allocator;

    // Initialize via getDefault
    _ = try getDefault(allocator);
    defer deinitDefault();

    // Now getCurrent should return it
    const backend = getCurrent();
    try std.testing.expect(backend != null);
}
