//! Hierarchical Timing Wheel for Event Loop
//!
//! Implements O(1) timer operations using a hierarchical timing wheel.
//! Based on the design from "Hashed and Hierarchical Timing Wheels"
//! by Varghese and Lauck.
//!
//! ## Design
//!
//! - Level 0 (L0): 1024 slots for milliseconds (0-1023ms)
//! - Level 1 (L1): 1024 slots for seconds (0-1023s, ~17 minutes)
//!
//! ## Operations
//!
//! - schedule(): O(1) - Insert timer at calculated slot
//! - cancel(): O(1) - Remove from intrusive list
//! - tick(): O(1) amortized - Process current slot, cascade if needed
//!
//! ## References
//!
//! - WHATWG HTML Standard: Timers
//! - Varghese & Lauck: Hashed and Hierarchical Timing Wheels

const std = @import("std");

/// Timer callback function type
pub const TimerCallback = *const fn (user_data: ?*anyopaque) void;

/// Timer node for embedding in user structures
pub const TimerNode = struct {
    /// Intrusive list links
    prev: ?*TimerNode = null,
    next: ?*TimerNode = null,

    /// Callback to execute when timer fires
    callback: TimerCallback,

    /// User-provided context data
    user_data: ?*anyopaque = null,

    /// Absolute expiration time in milliseconds
    expiration_ms: u64 = 0,

    /// Whether timer repeats
    repeating: bool = false,

    /// Repeat interval (only if repeating)
    interval_ms: u64 = 0,

    /// Whether timer is active (in wheel)
    active: bool = false,

    /// Initialize a timer node
    pub fn init(callback: TimerCallback, user_data: ?*anyopaque) TimerNode {
        return .{
            .callback = callback,
            .user_data = user_data,
        };
    }

    /// Execute the timer callback
    pub fn execute(self: *TimerNode) void {
        self.callback(self.user_data);
    }
};

/// Intrusive doubly-linked list for timer slots
const TimerList = struct {
    head: ?*TimerNode = null,
    tail: ?*TimerNode = null,

    /// Add timer to list
    fn push(self: *TimerList, timer: *TimerNode) void {
        timer.prev = self.tail;
        timer.next = null;

        if (self.tail) |tail| {
            tail.next = timer;
        } else {
            self.head = timer;
        }
        self.tail = timer;
    }

    /// Remove timer from list
    fn remove(self: *TimerList, timer: *TimerNode) void {
        if (timer.prev) |prev| {
            prev.next = timer.next;
        } else {
            self.head = timer.next;
        }

        if (timer.next) |next| {
            next.prev = timer.prev;
        } else {
            self.tail = timer.prev;
        }

        timer.prev = null;
        timer.next = null;
    }

    /// Check if list is empty
    fn isEmpty(self: *const TimerList) bool {
        return self.head == null;
    }
};

/// Hierarchical timing wheel
pub const TimerWheel = struct {
    const L0_BITS = 10; // 2^10 = 1024 slots
    const L1_BITS = 10;
    const L0_SIZE = 1 << L0_BITS;
    const L1_SIZE = 1 << L1_BITS;
    const L0_MASK = L0_SIZE - 1;
    const L1_MASK = L1_SIZE - 1;

    /// Level 0: millisecond resolution
    l0: [L0_SIZE]TimerList = [_]TimerList{.{}} ** L0_SIZE,

    /// Level 1: second resolution (1024ms per slot)
    l1: [L1_SIZE]TimerList = [_]TimerList{.{}} ** L1_SIZE,

    /// Current cursor position (absolute time in ms)
    current_ms: u64 = 0,

    /// Statistics
    timers_scheduled: usize = 0,
    timers_fired: usize = 0,
    timers_cancelled: usize = 0,

    const Self = @This();

    /// Initialize timer wheel
    pub fn init() Self {
        return .{};
    }

    /// Initialize with start time
    pub fn initWithTime(start_ms: u64) Self {
        return .{
            .current_ms = start_ms,
        };
    }

    /// Schedule a timer to fire after delay_ms milliseconds
    pub fn schedule(self: *Self, timer: *TimerNode, delay_ms: u64) void {
        const expiration = self.current_ms + delay_ms;
        timer.expiration_ms = expiration;
        timer.active = true;

        self.insertTimer(timer, expiration);
        self.timers_scheduled += 1;
    }

    /// Schedule a repeating timer
    pub fn scheduleRepeating(self: *Self, timer: *TimerNode, interval_ms: u64) void {
        timer.repeating = true;
        timer.interval_ms = interval_ms;
        self.schedule(timer, interval_ms);
    }

    /// Insert timer into appropriate wheel slot
    fn insertTimer(self: *Self, timer: *TimerNode, expiration: u64) void {
        const delta = if (expiration > self.current_ms) expiration - self.current_ms else 0;

        if (delta < L0_SIZE) {
            // Fits in L0
            const slot = @as(usize, @intCast(expiration & L0_MASK));
            self.l0[slot].push(timer);
        } else if (delta < L0_SIZE * L1_SIZE) {
            // Fits in L1
            const slot = @as(usize, @intCast((expiration >> L0_BITS) & L1_MASK));
            self.l1[slot].push(timer);
        } else {
            // Too far in future, put in last L1 slot
            // Will be re-cascaded when we reach it
            self.l1[L1_SIZE - 1].push(timer);
        }
    }

    /// Cancel a scheduled timer
    pub fn cancel(self: *Self, timer: *TimerNode) bool {
        if (!timer.active) {
            return false;
        }

        // Find which list contains this timer and remove it
        // Since we have the timer pointer, we can use intrusive removal
        const delta = if (timer.expiration_ms > self.current_ms) timer.expiration_ms - self.current_ms else 0;

        if (delta < L0_SIZE) {
            const slot = @as(usize, @intCast(timer.expiration_ms & L0_MASK));
            self.l0[slot].remove(timer);
        } else {
            const slot = @as(usize, @intCast((timer.expiration_ms >> L0_BITS) & L1_MASK));
            self.l1[slot].remove(timer);
        }

        timer.active = false;
        timer.repeating = false;
        self.timers_cancelled += 1;
        return true;
    }

    /// Update (reschedule) a timer
    pub fn update(self: *Self, timer: *TimerNode, new_delay_ms: u64) void {
        if (timer.active) {
            _ = self.cancel(timer);
            self.timers_cancelled -= 1; // Don't count as cancelled
        }
        self.schedule(timer, new_delay_ms);
    }

    /// Advance time and process expired timers
    ///
    /// Returns number of timers fired.
    pub fn tick(self: *Self, elapsed_ms: u64) usize {
        var fired: usize = 0;
        const target_ms = self.current_ms + elapsed_ms;

        while (self.current_ms <= target_ms) {
            // Check if we need to cascade from L1
            if ((self.current_ms & L0_MASK) == 0 and self.current_ms > 0) {
                self.cascade();
            }

            // Process current L0 slot
            const slot = @as(usize, @intCast(self.current_ms & L0_MASK));
            fired += self.processSlot(&self.l0[slot]);

            if (self.current_ms == target_ms) break;
            self.current_ms += 1;
        }

        self.timers_fired += fired;
        return fired;
    }

    /// Process a single slot, firing all timers
    fn processSlot(self: *Self, list: *TimerList) usize {
        var fired: usize = 0;

        while (list.head) |timer| {
            list.remove(timer);
            timer.active = false;

            // Execute callback
            timer.execute();
            fired += 1;

            // Reschedule if repeating
            if (timer.repeating) {
                self.schedule(timer, timer.interval_ms);
            }
        }

        return fired;
    }

    /// Cascade timers from L1 to L0
    fn cascade(self: *Self) void {
        const l1_slot = @as(usize, @intCast((self.current_ms >> L0_BITS) & L1_MASK));
        var list = &self.l1[l1_slot];

        // Move all timers from L1 slot to appropriate L0 slots
        while (list.head) |timer| {
            list.remove(timer);
            self.insertTimer(timer, timer.expiration_ms);
        }
    }

    /// Get current time
    pub fn getCurrentTime(self: *const Self) u64 {
        return self.current_ms;
    }

    /// Get statistics
    pub const Stats = struct {
        current_ms: u64,
        timers_scheduled: usize,
        timers_fired: usize,
        timers_cancelled: usize,
    };

    pub fn getStats(self: *const Self) Stats {
        return .{
            .current_ms = self.current_ms,
            .timers_scheduled = self.timers_scheduled,
            .timers_fired = self.timers_fired,
            .timers_cancelled = self.timers_cancelled,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "TimerWheel - basic scheduling" {
    var wheel = TimerWheel.init();

    var fired = false;
    var timer = TimerNode.init(setFlagCallback, &fired);

    wheel.schedule(&timer, 100); // Fire after 100ms
    try std.testing.expect(timer.active);
    try std.testing.expect(!fired);

    // Advance 50ms - shouldn't fire
    _ = wheel.tick(50);
    try std.testing.expect(!fired);

    // Advance another 50ms - should fire
    _ = wheel.tick(50);
    try std.testing.expect(fired);
    try std.testing.expect(!timer.active);
}

test "TimerWheel - multiple timers" {
    var wheel = TimerWheel.init();

    var order: [10]usize = [_]usize{0} ** 10;
    var order_idx: usize = 0;

    var ctx1 = OrderCtx{ .order = &order, .order_idx = &order_idx, .id = 1 };
    var ctx2 = OrderCtx{ .order = &order, .order_idx = &order_idx, .id = 2 };
    var ctx3 = OrderCtx{ .order = &order, .order_idx = &order_idx, .id = 3 };

    var timer1 = TimerNode.init(orderCallback, &ctx1);
    var timer2 = TimerNode.init(orderCallback, &ctx2);
    var timer3 = TimerNode.init(orderCallback, &ctx3);

    wheel.schedule(&timer3, 300); // Fires last
    wheel.schedule(&timer1, 100); // Fires first
    wheel.schedule(&timer2, 200); // Fires second

    _ = wheel.tick(400);

    try std.testing.expectEqual(@as(usize, 1), order[0]);
    try std.testing.expectEqual(@as(usize, 2), order[1]);
    try std.testing.expectEqual(@as(usize, 3), order[2]);
}

test "TimerWheel - cancel" {
    var wheel = TimerWheel.init();

    var fired = false;
    var timer = TimerNode.init(setFlagCallback, &fired);

    wheel.schedule(&timer, 100);
    try std.testing.expect(timer.active);

    const cancelled = wheel.cancel(&timer);
    try std.testing.expect(cancelled);
    try std.testing.expect(!timer.active);

    _ = wheel.tick(200);
    try std.testing.expect(!fired);
}

test "TimerWheel - update" {
    var wheel = TimerWheel.init();

    var fired = false;
    var timer = TimerNode.init(setFlagCallback, &fired);

    wheel.schedule(&timer, 100);

    // Update to fire later
    wheel.update(&timer, 200);

    _ = wheel.tick(150);
    try std.testing.expect(!fired); // Should not have fired yet

    _ = wheel.tick(100);
    try std.testing.expect(fired); // Now it should fire
}

test "TimerWheel - repeating timer" {
    var wheel = TimerWheel.init();

    var count: usize = 0;
    var timer = TimerNode.init(countCallback, &count);

    wheel.scheduleRepeating(&timer, 100);

    _ = wheel.tick(350); // Should fire 3 times

    try std.testing.expectEqual(@as(usize, 3), count);
    try std.testing.expect(timer.active); // Still active
    try std.testing.expect(timer.repeating);

    // Cancel repeating timer
    _ = wheel.cancel(&timer);
    _ = wheel.tick(200);
    try std.testing.expectEqual(@as(usize, 3), count); // No more fires
}

test "TimerWheel - L1 cascade" {
    var wheel = TimerWheel.init();

    var fired = false;
    var timer = TimerNode.init(setFlagCallback, &fired);

    // Schedule beyond L0 range (>1024ms)
    wheel.schedule(&timer, 2000);

    _ = wheel.tick(1500);
    try std.testing.expect(!fired);

    _ = wheel.tick(600);
    try std.testing.expect(fired);
}

test "TimerWheel - statistics" {
    var wheel = TimerWheel.init();

    var counter: usize = 0;
    var timer1 = TimerNode.init(countCallback, &counter);
    var timer2 = TimerNode.init(countCallback, &counter);

    wheel.schedule(&timer1, 50);
    wheel.schedule(&timer2, 100);

    _ = wheel.tick(150);

    const stats = wheel.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats.timers_scheduled);
    try std.testing.expectEqual(@as(usize, 2), stats.timers_fired);
    try std.testing.expectEqual(@as(usize, 0), stats.timers_cancelled);
}

// Test helpers

fn setFlagCallback(user_data: ?*anyopaque) void {
    const flag: *bool = @ptrCast(@alignCast(user_data.?));
    flag.* = true;
}

fn countCallback(user_data: ?*anyopaque) void {
    const counter: *usize = @ptrCast(@alignCast(user_data.?));
    counter.* += 1;
}

const OrderCtx = struct {
    order: *[10]usize,
    order_idx: *usize,
    id: usize,
};

fn orderCallback(user_data: ?*anyopaque) void {
    const ctx: *OrderCtx = @ptrCast(@alignCast(user_data.?));
    ctx.order[ctx.order_idx.*] = ctx.id;
    ctx.order_idx.* += 1;
}
