//! HTML Timer Manager
//!
//! Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html
//! HTML Standard §8.6 "Timers"
//!
//! Implements setTimeout() and setInterval() with:
//! - Nesting level tracking for 4ms clamping
//! - Priority queue of pending timers
//! - Pluggable platform backend

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("../../infra/root.zig");
const timer_backend = @import("../../platform/timer_backend.zig");
const TimerBackend = timer_backend.TimerBackend;

/// A scheduled timer.
pub const Timer = struct {
    /// Unique timer ID (returned by setTimeout/setInterval).
    id: u32,

    /// When this timer should fire (absolute time in ms).
    fire_time: i64,

    /// The callback to invoke when the timer fires.
    callback: TimerCallback,

    /// Context for the callback.
    context: ?*anyopaque,

    /// Whether this is a repeating timer (setInterval).
    is_interval: bool,

    /// The interval delay for repeating timers.
    interval_ms: i64,

    /// The nesting level when this timer was created.
    /// Used for 4ms minimum delay clamping.
    nesting_level: u32,

    /// Whether this timer has been cancelled.
    cancelled: bool,

    /// Function type for timer callbacks.
    pub const TimerCallback = *const fn (context: ?*anyopaque) void;

    /// Compare timers by fire time for priority queue.
    pub fn compareFireTime(a: *Timer, b: *Timer) std.math.Order {
        return std.math.order(a.fire_time, b.fire_time);
    }
};

/// Visibility state affecting timer throttling.
pub const VisibilityState = enum {
    visible,
    hidden,
};

/// Timer manager implementing setTimeout/setInterval.
///
/// HTML Standard §8.6 "Timers":
/// The setTimeout() and setInterval() methods allow authors to schedule
/// timer-based callbacks.
pub const TimerManager = struct {
    /// All pending timers, keyed by ID for O(1) lookup.
    timers: std.AutoHashMap(u32, *Timer),

    /// Timer IDs sorted by fire time.
    /// This is a simple list; for production use a priority queue.
    sorted_ids: infra.List(u32),

    /// Next timer ID to assign.
    next_id: u32,

    /// Current nesting level for nested timer calls.
    /// HTML Standard §8.6: "each task that calls setTimeout or setInterval
    /// must increase the nesting level by one"
    nesting_level: u32,

    /// Document visibility state for throttling.
    visibility_state: VisibilityState,

    /// Platform timer backend.
    platform: TimerBackend,

    /// Allocator for timer management.
    allocator: Allocator,

    /// Minimum timer delay.
    /// HTML Standard §8.6: "If timeout is less than 0, then set timeout to 0."
    pub const MIN_DELAY_MS: i64 = 0;

    /// Minimum delay for deeply nested timers.
    /// HTML Standard §8.6: "If nesting level is greater than 5, and timeout
    /// is less than 4, then set timeout to 4."
    pub const MIN_NESTED_DELAY_MS: i64 = 4;

    /// Nesting level threshold for 4ms clamping.
    pub const NESTING_LEVEL_THRESHOLD: u32 = 5;

    /// Throttle delay for hidden pages (1000ms).
    pub const HIDDEN_THROTTLE_MS: i64 = 1000;

    /// Initialize a new timer manager.
    pub fn init(allocator: Allocator, platform: TimerBackend) TimerManager {
        return TimerManager{
            .timers = std.AutoHashMap(u32, *Timer).init(allocator),
            .sorted_ids = infra.List(u32).init(allocator),
            .next_id = 1,
            .nesting_level = 0,
            .visibility_state = .visible,
            .platform = platform,
            .allocator = allocator,
        };
    }

    /// Free all resources.
    pub fn deinit(self: *TimerManager) void {
        // Free all timers
        var iter = self.timers.iterator();
        while (iter.next()) |entry| {
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.timers.deinit();
        self.sorted_ids.deinit();
    }

    /// Set a one-shot timer.
    ///
    /// HTML Standard §8.6 "The setTimeout() method":
    /// Returns a timer ID that can be used to cancel the timer.
    pub fn setTimeout(
        self: *TimerManager,
        callback: Timer.TimerCallback,
        delay_ms: i64,
        context: ?*anyopaque,
    ) !u32 {
        return self.setTimerInternal(callback, delay_ms, context, false);
    }

    /// Set a repeating timer.
    ///
    /// HTML Standard §8.6 "The setInterval() method":
    /// Returns a timer ID that can be used to cancel the timer.
    pub fn setInterval(
        self: *TimerManager,
        callback: Timer.TimerCallback,
        delay_ms: i64,
        context: ?*anyopaque,
    ) !u32 {
        return self.setTimerInternal(callback, delay_ms, context, true);
    }

    /// Internal timer creation logic.
    fn setTimerInternal(
        self: *TimerManager,
        callback: Timer.TimerCallback,
        delay_ms: i64,
        context: ?*anyopaque,
        is_interval: bool,
    ) !u32 {
        // Get current nesting level
        const nesting = self.nesting_level;

        // Clamp delay according to spec
        var actual_delay = delay_ms;

        // Step 1: If timeout is less than 0, then set timeout to 0.
        if (actual_delay < MIN_DELAY_MS) {
            actual_delay = MIN_DELAY_MS;
        }

        // Step 2: If nesting level is greater than 5, and timeout is less than 4,
        // then set timeout to 4.
        if (nesting > NESTING_LEVEL_THRESHOLD and actual_delay < MIN_NESTED_DELAY_MS) {
            actual_delay = MIN_NESTED_DELAY_MS;
        }

        // Step 3: Apply visibility throttling for hidden pages
        if (self.visibility_state == .hidden) {
            if (actual_delay < HIDDEN_THROTTLE_MS) {
                actual_delay = HIDDEN_THROTTLE_MS;
            }
        }

        // Calculate fire time
        const now = self.platform.getCurrentTime();
        const fire_time = now + actual_delay;

        // Create timer
        const timer = try self.allocator.create(Timer);
        const id = self.next_id;
        self.next_id +%= 1;

        timer.* = Timer{
            .id = id,
            .fire_time = fire_time,
            .callback = callback,
            .context = context,
            .is_interval = is_interval,
            .interval_ms = actual_delay,
            .nesting_level = nesting,
            .cancelled = false,
        };

        // Add to collections
        try self.timers.put(id, timer);
        try self.insertSorted(id, fire_time);

        // Update platform wake-up
        self.updatePlatformWakeup();

        return id;
    }

    /// Insert timer ID in sorted order by fire time.
    fn insertSorted(self: *TimerManager, id: u32, fire_time: i64) !void {
        const slice = self.sorted_ids.toSlice();
        var insert_pos: usize = slice.len;

        for (slice, 0..) |existing_id, i| {
            if (self.timers.get(existing_id)) |existing| {
                if (fire_time < existing.fire_time) {
                    insert_pos = i;
                    break;
                }
            }
        }

        try self.sorted_ids.insert(insert_pos, id);
    }

    /// Update platform backend's wake-up time.
    fn updatePlatformWakeup(self: *TimerManager) void {
        if (self.getNextWakeTime()) |wake_time| {
            self.platform.scheduleWakeup(wake_time);
        } else {
            self.platform.cancelWakeup();
        }
    }

    /// Clear a one-shot timer.
    pub fn clearTimeout(self: *TimerManager, id: u32) void {
        self.cancelTimer(id);
    }

    /// Clear a repeating timer.
    pub fn clearInterval(self: *TimerManager, id: u32) void {
        self.cancelTimer(id);
    }

    /// Cancel a timer by ID.
    fn cancelTimer(self: *TimerManager, id: u32) void {
        if (self.timers.get(id)) |timer| {
            timer.cancelled = true;
        }
    }

    /// Get the time when the next timer should fire.
    pub fn getNextWakeTime(self: *const TimerManager) ?i64 {
        const slice = self.sorted_ids.toSlice();
        for (slice) |id| {
            if (self.timers.get(id)) |timer| {
                if (!timer.cancelled) {
                    return timer.fire_time;
                }
            }
        }
        return null;
    }

    /// Process all timers that are ready to fire.
    /// Returns the number of timers fired.
    pub fn processReadyTimers(self: *TimerManager, now: i64) !u32 {
        var fired_count: u32 = 0;
        var to_remove = infra.List(u32).init(self.allocator);
        defer to_remove.deinit();

        var to_reschedule = infra.List(Timer).init(self.allocator);
        defer to_reschedule.deinit();

        // Find all ready timers
        const slice = self.sorted_ids.toSlice();
        for (slice) |id| {
            if (self.timers.get(id)) |timer| {
                if (timer.cancelled) {
                    try to_remove.append(id);
                    continue;
                }

                if (timer.fire_time <= now) {
                    // Increase nesting level during callback
                    const old_nesting = self.nesting_level;
                    self.nesting_level = timer.nesting_level + 1;

                    // Fire the callback
                    timer.callback(timer.context);
                    fired_count += 1;

                    // Restore nesting level
                    self.nesting_level = old_nesting;

                    // Handle interval timers
                    if (timer.is_interval) {
                        // Reschedule for next interval
                        var rescheduled = timer.*;
                        rescheduled.fire_time = now + timer.interval_ms;
                        try to_reschedule.append(rescheduled);
                        try to_remove.append(id);
                    } else {
                        // One-shot timer, remove it
                        try to_remove.append(id);
                    }
                } else {
                    // Timers are sorted, so we can stop here
                    break;
                }
            }
        }

        // Remove fired/cancelled timers
        const remove_slice = to_remove.toSlice();
        for (remove_slice) |id| {
            if (self.timers.fetchRemove(id)) |kv| {
                self.allocator.destroy(kv.value);
            }
            // Remove from sorted list
            self.removeFromSorted(id);
        }

        // Add rescheduled interval timers
        const reschedule_slice = to_reschedule.toSlice();
        for (reschedule_slice) |timer_data| {
            const timer = try self.allocator.create(Timer);
            timer.* = timer_data;
            try self.timers.put(timer.id, timer);
            try self.insertSorted(timer.id, timer.fire_time);
        }

        // Update platform wake-up
        self.updatePlatformWakeup();

        return fired_count;
    }

    /// Remove timer ID from sorted list.
    fn removeFromSorted(self: *TimerManager, id: u32) void {
        const slice = self.sorted_ids.toSlice();
        for (slice, 0..) |existing_id, i| {
            if (existing_id == id) {
                _ = self.sorted_ids.remove(i) catch unreachable;
                break;
            }
        }
    }

    /// Set the visibility state (affects throttling).
    pub fn setVisibilityState(self: *TimerManager, state: VisibilityState) void {
        self.visibility_state = state;
    }

    /// Get the number of pending timers.
    pub fn pendingCount(self: *const TimerManager) usize {
        return self.timers.count();
    }

    /// Check if there are any pending timers.
    pub fn hasPendingTimers(self: *const TimerManager) bool {
        return self.timers.count() > 0;
    }
};

test "TimerManager - basic setTimeout" {
    const allocator = std.testing.allocator;

    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    var tm = TimerManager.init(allocator, mock.backend());
    defer tm.deinit();

    var executed = false;
    const id = try tm.setTimeout(
        struct {
            fn callback(ctx: ?*anyopaque) void {
                const flag: *bool = @ptrCast(@alignCast(ctx.?));
                flag.* = true;
            }
        }.callback,
        100,
        @ptrCast(&executed),
    );

    try std.testing.expect(id > 0);
    try std.testing.expect(tm.hasPendingTimers());
    try std.testing.expect(!executed);

    // Advance time past the timer
    _ = mock.advanceTime(150);
    _ = try tm.processReadyTimers(mock.current_time_ms);

    try std.testing.expect(executed);
    try std.testing.expect(!tm.hasPendingTimers());
}

test "TimerManager - setInterval" {
    const allocator = std.testing.allocator;

    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    var tm = TimerManager.init(allocator, mock.backend());
    defer tm.deinit();

    var count: u32 = 0;
    const id = try tm.setInterval(
        struct {
            fn callback(ctx: ?*anyopaque) void {
                const c: *u32 = @ptrCast(@alignCast(ctx.?));
                c.* += 1;
            }
        }.callback,
        100,
        @ptrCast(&count),
    );

    try std.testing.expect(id > 0);

    // Fire first interval
    _ = mock.advanceTime(100);
    _ = try tm.processReadyTimers(mock.current_time_ms);
    try std.testing.expectEqual(@as(u32, 1), count);

    // Fire second interval
    _ = mock.advanceTime(100);
    _ = try tm.processReadyTimers(mock.current_time_ms);
    try std.testing.expectEqual(@as(u32, 2), count);

    // Fire third interval
    _ = mock.advanceTime(100);
    _ = try tm.processReadyTimers(mock.current_time_ms);
    try std.testing.expectEqual(@as(u32, 3), count);

    // Timer should still be pending
    try std.testing.expect(tm.hasPendingTimers());

    // Clear it
    tm.clearInterval(id);
    _ = mock.advanceTime(100);
    _ = try tm.processReadyTimers(mock.current_time_ms);
    try std.testing.expectEqual(@as(u32, 3), count); // No more increments
}

test "TimerManager - clearTimeout" {
    const allocator = std.testing.allocator;

    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    var tm = TimerManager.init(allocator, mock.backend());
    defer tm.deinit();

    var executed = false;
    const id = try tm.setTimeout(
        struct {
            fn callback(ctx: ?*anyopaque) void {
                const flag: *bool = @ptrCast(@alignCast(ctx.?));
                flag.* = true;
            }
        }.callback,
        100,
        @ptrCast(&executed),
    );

    // Cancel before it fires
    tm.clearTimeout(id);

    // Advance time past the timer
    _ = mock.advanceTime(150);
    _ = try tm.processReadyTimers(mock.current_time_ms);

    // Should NOT have executed
    try std.testing.expect(!executed);
}

test "TimerManager - negative delay clamped to 0" {
    const allocator = std.testing.allocator;

    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    var tm = TimerManager.init(allocator, mock.backend());
    defer tm.deinit();

    var executed = false;
    _ = try tm.setTimeout(
        struct {
            fn callback(ctx: ?*anyopaque) void {
                const flag: *bool = @ptrCast(@alignCast(ctx.?));
                flag.* = true;
            }
        }.callback,
        -100, // Negative delay
        @ptrCast(&executed),
    );

    // Should fire immediately (delay clamped to 0)
    _ = try tm.processReadyTimers(mock.current_time_ms);
    try std.testing.expect(executed);
}

test "TimerManager - multiple timers ordered by fire time" {
    const allocator = std.testing.allocator;

    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    var tm = TimerManager.init(allocator, mock.backend());
    defer tm.deinit();

    var order: u32 = 0;

    // Add timers in reverse order
    _ = try tm.setTimeout(
        struct {
            fn callback(ctx: ?*anyopaque) void {
                const o: *u32 = @ptrCast(@alignCast(ctx.?));
                o.* = o.* * 10 + 3;
            }
        }.callback,
        300,
        @ptrCast(&order),
    );

    _ = try tm.setTimeout(
        struct {
            fn callback(ctx: ?*anyopaque) void {
                const o: *u32 = @ptrCast(@alignCast(ctx.?));
                o.* = o.* * 10 + 1;
            }
        }.callback,
        100,
        @ptrCast(&order),
    );

    _ = try tm.setTimeout(
        struct {
            fn callback(ctx: ?*anyopaque) void {
                const o: *u32 = @ptrCast(@alignCast(ctx.?));
                o.* = o.* * 10 + 2;
            }
        }.callback,
        200,
        @ptrCast(&order),
    );

    // Process all
    _ = mock.advanceTime(400);
    _ = try tm.processReadyTimers(mock.current_time_ms);

    // Should fire in order: 1, 2, 3
    try std.testing.expectEqual(@as(u32, 123), order);
}

test "TimerManager - visibility throttling" {
    const allocator = std.testing.allocator;

    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    var tm = TimerManager.init(allocator, mock.backend());
    defer tm.deinit();

    // Set page as hidden
    tm.setVisibilityState(.hidden);

    var executed = false;
    _ = try tm.setTimeout(
        struct {
            fn callback(ctx: ?*anyopaque) void {
                const flag: *bool = @ptrCast(@alignCast(ctx.?));
                flag.* = true;
            }
        }.callback,
        100, // Would fire at 100ms normally
        @ptrCast(&executed),
    );

    // At 500ms it should NOT have fired yet (throttled to 1000ms)
    _ = mock.advanceTime(500);
    _ = try tm.processReadyTimers(mock.current_time_ms);
    try std.testing.expect(!executed);

    // At 1000ms it should fire
    _ = mock.advanceTime(500);
    _ = try tm.processReadyTimers(mock.current_time_ms);
    try std.testing.expect(executed);
}
