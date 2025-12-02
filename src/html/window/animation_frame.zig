//! Animation Frame Scheduling - HTML Standard §8.14.2
//!
//! Implements requestAnimationFrame() and cancelAnimationFrame() per spec.
//!
//! Spec: https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#animation-frames
//!
//! ## Overview
//!
//! requestAnimationFrame() schedules a callback to be invoked before the next
//! repaint, allowing smooth animations synchronized with the display refresh rate.
//!
//! ## Architecture
//!
//! ```
//! AnimationFrameScheduler
//! ├── callbacks: Map(handle -> callback)
//! ├── next_handle: u32
//! ├── pending_callbacks: ordered list
//! └── backend: FrameTimingBackend (pluggable)
//! ```
//!
//! ## Usage
//!
//! ```zig
//! const anim = @import("window/animation_frame.zig");
//!
//! var scheduler = try anim.AnimationFrameScheduler.init(allocator, backend);
//! defer scheduler.deinit();
//!
//! // Request animation frame
//! const handle = try scheduler.requestAnimationFrame(callback, context);
//!
//! // Cancel if needed
//! scheduler.cancelAnimationFrame(handle);
//!
//! // Execute pending callbacks (called from render loop)
//! try scheduler.runAnimationCallbacks(timestamp);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// DOMHighResTimeStamp - high resolution timestamp in milliseconds
pub const DOMHighResTimeStamp = f64;

/// Frame request callback signature
/// Per spec: callback FrameRequestCallback = undefined (DOMHighResTimeStamp time);
pub const FrameRequestCallback = *const fn (timestamp: DOMHighResTimeStamp, context: ?*anyopaque) void;

/// Frame timing backend interface
/// Allows pluggable timing sources (system vsync, mock time, etc.)
pub const FrameTimingBackend = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Get the current high-resolution timestamp
        now: *const fn (ptr: *anyopaque) DOMHighResTimeStamp,

        /// Request to be notified when next frame should be drawn
        /// Returns true if successfully scheduled
        requestFrame: *const fn (ptr: *anyopaque, callback: *const fn (ctx: ?*anyopaque) void, ctx: ?*anyopaque) bool,

        /// Get the target frame interval in milliseconds (e.g., 16.67 for 60fps)
        getFrameInterval: *const fn (ptr: *anyopaque) DOMHighResTimeStamp,
    };

    /// Get current timestamp
    pub fn now(self: FrameTimingBackend) DOMHighResTimeStamp {
        return self.vtable.now(self.ptr);
    }

    /// Request frame notification
    pub fn requestFrame(self: FrameTimingBackend, callback: *const fn (ctx: ?*anyopaque) void, ctx: ?*anyopaque) bool {
        return self.vtable.requestFrame(self.ptr, callback, ctx);
    }

    /// Get frame interval
    pub fn getFrameInterval(self: FrameTimingBackend) DOMHighResTimeStamp {
        return self.vtable.getFrameInterval(self.ptr);
    }
};

/// Stub frame timing backend (for testing)
/// Uses system time but doesn't actually sync to display
pub const StubFrameTimingBackend = struct {
    /// Base timestamp (for relative timing)
    base_timestamp: i64,

    /// Target FPS (default 60)
    target_fps: u32,

    /// Initialize
    pub fn init() StubFrameTimingBackend {
        return .{
            .base_timestamp = std.time.milliTimestamp(),
            .target_fps = 60,
        };
    }

    /// Initialize with custom FPS
    pub fn initWithFps(fps: u32) StubFrameTimingBackend {
        return .{
            .base_timestamp = std.time.milliTimestamp(),
            .target_fps = fps,
        };
    }

    /// Get the backend interface
    pub fn backend(self: *StubFrameTimingBackend) FrameTimingBackend {
        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    const vtable = FrameTimingBackend.VTable{
        .now = nowImpl,
        .requestFrame = requestFrameImpl,
        .getFrameInterval = getFrameIntervalImpl,
    };

    fn nowImpl(ptr: *anyopaque) DOMHighResTimeStamp {
        const self: *StubFrameTimingBackend = @ptrCast(@alignCast(ptr));
        const current = std.time.milliTimestamp();
        return @floatFromInt(current - self.base_timestamp);
    }

    fn requestFrameImpl(_: *anyopaque, _: *const fn (ctx: ?*anyopaque) void, _: ?*anyopaque) bool {
        // Stub backend doesn't actually schedule - caller should poll
        return true;
    }

    fn getFrameIntervalImpl(ptr: *anyopaque) DOMHighResTimeStamp {
        const self: *StubFrameTimingBackend = @ptrCast(@alignCast(ptr));
        return 1000.0 / @as(DOMHighResTimeStamp, @floatFromInt(self.target_fps));
    }
};

/// Mock frame timing backend for testing
/// Allows manual control of time
pub const MockFrameTimingBackend = struct {
    current_time: DOMHighResTimeStamp,
    frame_interval: DOMHighResTimeStamp,

    /// Initialize with starting time and frame interval
    pub fn init(start_time: DOMHighResTimeStamp, frame_interval: DOMHighResTimeStamp) MockFrameTimingBackend {
        return .{
            .current_time = start_time,
            .frame_interval = frame_interval,
        };
    }

    /// Advance time by the given amount
    pub fn advanceTime(self: *MockFrameTimingBackend, delta: DOMHighResTimeStamp) void {
        self.current_time += delta;
    }

    /// Advance by one frame
    pub fn advanceFrame(self: *MockFrameTimingBackend) void {
        self.current_time += self.frame_interval;
    }

    /// Set the current time
    pub fn setTime(self: *MockFrameTimingBackend, time: DOMHighResTimeStamp) void {
        self.current_time = time;
    }

    /// Get the backend interface
    pub fn backend(self: *MockFrameTimingBackend) FrameTimingBackend {
        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    const vtable = FrameTimingBackend.VTable{
        .now = nowImpl,
        .requestFrame = requestFrameImpl,
        .getFrameInterval = getFrameIntervalImpl,
    };

    fn nowImpl(ptr: *anyopaque) DOMHighResTimeStamp {
        const self: *MockFrameTimingBackend = @ptrCast(@alignCast(ptr));
        return self.current_time;
    }

    fn requestFrameImpl(_: *anyopaque, _: *const fn (ctx: ?*anyopaque) void, _: ?*anyopaque) bool {
        return true;
    }

    fn getFrameIntervalImpl(ptr: *anyopaque) DOMHighResTimeStamp {
        const self: *MockFrameTimingBackend = @ptrCast(@alignCast(ptr));
        return self.frame_interval;
    }
};

/// Stored callback entry
const CallbackEntry = struct {
    callback: FrameRequestCallback,
    context: ?*anyopaque,
    cancelled: bool,
};

/// Animation frame scheduler
/// Per HTML Standard §8.14.2
pub const AnimationFrameScheduler = struct {
    allocator: Allocator,

    /// Frame timing backend
    timing: FrameTimingBackend,

    /// Map of handle -> callback entry
    callbacks: std.AutoHashMap(u32, CallbackEntry),

    /// List of handles in order of registration (for ordered execution)
    pending_handles: std.ArrayListUnmanaged(u32),

    /// Next handle to assign
    next_handle: u32,

    /// Whether callbacks are currently being run
    running_callbacks: bool,

    /// Initialize the scheduler
    pub fn init(allocator: Allocator, timing: FrameTimingBackend) !*AnimationFrameScheduler {
        const scheduler = try allocator.create(AnimationFrameScheduler);
        scheduler.* = .{
            .allocator = allocator,
            .timing = timing,
            .callbacks = std.AutoHashMap(u32, CallbackEntry).init(allocator),
            .pending_handles = .{},
            .next_handle = 1,
            .running_callbacks = false,
        };
        return scheduler;
    }

    /// Deinitialize and free resources
    pub fn deinit(self: *AnimationFrameScheduler) void {
        self.callbacks.deinit();
        self.pending_handles.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Request animation frame (§8.14.2)
    /// Returns a handle that can be used to cancel the request
    pub fn requestAnimationFrame(
        self: *AnimationFrameScheduler,
        callback: FrameRequestCallback,
        context: ?*anyopaque,
    ) !u32 {
        // Per spec: Let handle be user-agent-defined integer >= 1
        const handle = self.next_handle;
        self.next_handle +%= 1;
        if (self.next_handle == 0) self.next_handle = 1;

        // Store the callback
        try self.callbacks.put(handle, .{
            .callback = callback,
            .context = context,
            .cancelled = false,
        });

        // Add to pending list
        try self.pending_handles.append(self.allocator, handle);

        return handle;
    }

    /// Cancel animation frame (§8.14.2)
    pub fn cancelAnimationFrame(self: *AnimationFrameScheduler, handle: u32) void {
        // Per spec: Remove the entry from map (or mark as cancelled if running)
        if (self.running_callbacks) {
            // Mark as cancelled - will be skipped when run
            if (self.callbacks.getPtr(handle)) |entry| {
                entry.cancelled = true;
            }
        } else {
            // Remove immediately
            _ = self.callbacks.remove(handle);

            // Remove from pending list
            for (self.pending_handles.items, 0..) |h, i| {
                if (h == handle) {
                    _ = self.pending_handles.orderedRemove(i);
                    break;
                }
            }
        }
    }

    /// Run animation callbacks (§8.14.2 step 7.13)
    /// Called from the event loop during "Update the rendering" step
    pub fn runAnimationCallbacks(self: *AnimationFrameScheduler, timestamp: DOMHighResTimeStamp) !void {
        if (self.pending_handles.items.len == 0) return;

        // Per spec: Let callbacks be a copy of map
        // We'll iterate over pending_handles and mark running
        self.running_callbacks = true;
        defer self.running_callbacks = false;

        // Take snapshot of pending handles
        const handles_to_run = try self.allocator.dupe(u32, self.pending_handles.items);
        defer self.allocator.free(handles_to_run);

        // Clear pending list
        self.pending_handles.clearRetainingCapacity();

        // Per spec: For each entry in callbacks, in order
        for (handles_to_run) |handle| {
            if (self.callbacks.get(handle)) |entry| {
                // Per spec: If entry is cancelled, skip
                if (!entry.cancelled) {
                    // Per spec: Invoke callback with timestamp
                    entry.callback(timestamp, entry.context);
                }

                // Remove from map after execution
                _ = self.callbacks.remove(handle);
            }
        }
    }

    /// Check if there are pending animation frame callbacks
    pub fn hasPendingCallbacks(self: *const AnimationFrameScheduler) bool {
        return self.pending_handles.items.len > 0;
    }

    /// Get the number of pending callbacks
    pub fn getPendingCount(self: *const AnimationFrameScheduler) usize {
        return self.pending_handles.items.len;
    }

    /// Get the current timestamp from the timing backend
    pub fn now(self: *const AnimationFrameScheduler) DOMHighResTimeStamp {
        return self.timing.now();
    }
};

test "AnimationFrameScheduler - basic request and run" {
    const allocator = std.testing.allocator;

    var timing = MockFrameTimingBackend.init(0.0, 16.67);
    var scheduler = try AnimationFrameScheduler.init(allocator, timing.backend());
    defer scheduler.deinit();

    var callback_count: u32 = 0;

    const handle = try scheduler.requestAnimationFrame(struct {
        fn callback(_: DOMHighResTimeStamp, ctx: ?*anyopaque) void {
            const count: *u32 = @ptrCast(@alignCast(ctx.?));
            count.* += 1;
        }
    }.callback, &callback_count);

    try std.testing.expect(handle >= 1);
    try std.testing.expect(scheduler.hasPendingCallbacks());
    try std.testing.expectEqual(@as(usize, 1), scheduler.getPendingCount());

    // Run callbacks
    timing.advanceFrame();
    try scheduler.runAnimationCallbacks(timing.current_time);

    try std.testing.expectEqual(@as(u32, 1), callback_count);
    try std.testing.expect(!scheduler.hasPendingCallbacks());
}

test "AnimationFrameScheduler - cancel before run" {
    const allocator = std.testing.allocator;

    var timing = MockFrameTimingBackend.init(0.0, 16.67);
    var scheduler = try AnimationFrameScheduler.init(allocator, timing.backend());
    defer scheduler.deinit();

    var callback_count: u32 = 0;

    const handle = try scheduler.requestAnimationFrame(struct {
        fn callback(_: DOMHighResTimeStamp, ctx: ?*anyopaque) void {
            const count: *u32 = @ptrCast(@alignCast(ctx.?));
            count.* += 1;
        }
    }.callback, &callback_count);

    // Cancel before run
    scheduler.cancelAnimationFrame(handle);

    try std.testing.expect(!scheduler.hasPendingCallbacks());

    // Run callbacks - should not invoke cancelled callback
    timing.advanceFrame();
    try scheduler.runAnimationCallbacks(timing.current_time);

    try std.testing.expectEqual(@as(u32, 0), callback_count);
}

test "AnimationFrameScheduler - multiple callbacks in order" {
    const allocator = std.testing.allocator;

    var timing = MockFrameTimingBackend.init(0.0, 16.67);
    var scheduler = try AnimationFrameScheduler.init(allocator, timing.backend());
    defer scheduler.deinit();

    var order: [3]u32 = .{ 0, 0, 0 };
    var order_index: usize = 0;

    _ = try scheduler.requestAnimationFrame(struct {
        fn callback(_: DOMHighResTimeStamp, ctx: ?*anyopaque) void {
            const state = @as(*struct { order: *[3]u32, index: *usize }, @ptrCast(@alignCast(ctx.?)));
            state.order[state.index.*] = 1;
            state.index.* += 1;
        }
    }.callback, &.{ .order = &order, .index = &order_index });

    _ = try scheduler.requestAnimationFrame(struct {
        fn callback(_: DOMHighResTimeStamp, ctx: ?*anyopaque) void {
            const state = @as(*struct { order: *[3]u32, index: *usize }, @ptrCast(@alignCast(ctx.?)));
            state.order[state.index.*] = 2;
            state.index.* += 1;
        }
    }.callback, &.{ .order = &order, .index = &order_index });

    _ = try scheduler.requestAnimationFrame(struct {
        fn callback(_: DOMHighResTimeStamp, ctx: ?*anyopaque) void {
            const state = @as(*struct { order: *[3]u32, index: *usize }, @ptrCast(@alignCast(ctx.?)));
            state.order[state.index.*] = 3;
            state.index.* += 1;
        }
    }.callback, &.{ .order = &order, .index = &order_index });

    try std.testing.expectEqual(@as(usize, 3), scheduler.getPendingCount());

    // Run callbacks
    timing.advanceFrame();
    try scheduler.runAnimationCallbacks(timing.current_time);

    // Verify order
    try std.testing.expectEqual(@as(u32, 1), order[0]);
    try std.testing.expectEqual(@as(u32, 2), order[1]);
    try std.testing.expectEqual(@as(u32, 3), order[2]);
}

test "AnimationFrameScheduler - callback receives timestamp" {
    const allocator = std.testing.allocator;

    var timing = MockFrameTimingBackend.init(100.0, 16.67);
    var scheduler = try AnimationFrameScheduler.init(allocator, timing.backend());
    defer scheduler.deinit();

    var received_timestamp: DOMHighResTimeStamp = 0.0;

    _ = try scheduler.requestAnimationFrame(struct {
        fn callback(timestamp: DOMHighResTimeStamp, ctx: ?*anyopaque) void {
            const ts: *DOMHighResTimeStamp = @ptrCast(@alignCast(ctx.?));
            ts.* = timestamp;
        }
    }.callback, &received_timestamp);

    timing.advanceFrame();
    try scheduler.runAnimationCallbacks(timing.current_time);

    try std.testing.expectApproxEqAbs(@as(DOMHighResTimeStamp, 116.67), received_timestamp, 0.01);
}

test "StubFrameTimingBackend - basic operations" {
    var timing = StubFrameTimingBackend.init();

    const t1 = timing.backend().now();
    std.time.sleep(1_000_000); // 1ms
    const t2 = timing.backend().now();

    try std.testing.expect(t2 >= t1);
    try std.testing.expectApproxEqAbs(@as(DOMHighResTimeStamp, 16.67), timing.backend().getFrameInterval(), 0.1);
}

test "MockFrameTimingBackend - manual time control" {
    var timing = MockFrameTimingBackend.init(0.0, 16.67);

    try std.testing.expectApproxEqAbs(@as(DOMHighResTimeStamp, 0.0), timing.backend().now(), 0.001);

    timing.advanceTime(100.0);
    try std.testing.expectApproxEqAbs(@as(DOMHighResTimeStamp, 100.0), timing.backend().now(), 0.001);

    timing.advanceFrame();
    try std.testing.expectApproxEqAbs(@as(DOMHighResTimeStamp, 116.67), timing.backend().now(), 0.01);

    timing.setTime(500.0);
    try std.testing.expectApproxEqAbs(@as(DOMHighResTimeStamp, 500.0), timing.backend().now(), 0.001);
}
