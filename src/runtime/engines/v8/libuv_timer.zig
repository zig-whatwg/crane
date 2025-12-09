//! libuv-based Timer Implementation for V8
//!
//! This module provides timer support for V8 embeddings using libuv.
//! Each V8 isolate gets its own libuv event loop and timer manager.
//!
//! ## Design
//!
//! - One libuv loop per V8 isolate (isolate-local timers)
//! - Timer handles are pooled and reused to avoid frequent allocations
//! - Timer IDs are monotonically increasing u64 values
//! - Cancelled timers are cleaned up lazily during event loop runs
//!
//! ## Integration
//!
//! The V8EventLoop runs libuv's event loop in UV_RUN_NOWAIT mode during
//! its runOnce() call, which processes any ready timer callbacks.

const std = @import("std");
const Allocator = std.mem.Allocator;
const libuv = @import("libuv.zig");

// Import timer types from the runtime module
// v8 module imports runtime, so we access timer through it
const runtime = @import("runtime");

pub const TimerId = runtime.TimerId;
pub const TimerCallback = runtime.TimerCallback;
pub const TimerInterface = runtime.TimerInterface;
pub const TimerVTable = runtime.TimerVTable;

/// Context stored in each timer handle's data field.
/// Contains everything needed to invoke the callback and clean up.
const TimerContext = struct {
    /// The user's callback function
    callback: TimerCallback,
    /// User data to pass to callback
    user_data: ?*anyopaque,
    /// Timer ID for this timer
    id: TimerId,
    /// Back-reference to the timer manager
    manager: *LibuvTimerManager,
    /// The libuv timer handle (embedded to avoid extra allocation)
    handle: libuv.uv_timer_t,
    /// Whether this timer has been cancelled
    cancelled: bool,
    /// Whether this timer is in the process of closing
    closing: bool,
};

/// Manages libuv timers for a single V8 isolate.
pub const LibuvTimerManager = struct {
    /// Allocator for timer contexts
    allocator: Allocator,
    /// The libuv event loop (allocated, owned by this manager)
    loop: *libuv.uv_loop_t,
    /// Next timer ID to assign
    next_id: TimerId,
    /// Active timers indexed by ID
    timers: std.AutoHashMap(TimerId, *TimerContext),
    /// Whether the loop has been initialized
    initialized: bool,

    const Self = @This();

    /// Initialize a new timer manager with its own libuv loop.
    pub fn init(allocator: Allocator) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        // Allocate the libuv loop
        // libuv tells us the size via uv_loop_size(), use pointer alignment
        const loop_size = libuv.getLoopSize();
        const loop_bytes = try allocator.alignedAlloc(u8, .@"8", loop_size);
        errdefer allocator.free(loop_bytes);

        const loop: *libuv.uv_loop_t = @ptrCast(loop_bytes.ptr);

        // Initialize the loop
        try libuv.loopInit(loop);

        self.* = .{
            .allocator = allocator,
            .loop = loop,
            .next_id = 1,
            .timers = std.AutoHashMap(TimerId, *TimerContext).init(allocator),
            .initialized = true,
        };

        return self;
    }

    /// Shut down the timer manager.
    /// Cancels all pending timers and closes the libuv loop.
    pub fn deinit(self: *Self) void {
        if (!self.initialized) return;

        // Cancel and close all active timers
        var it = self.timers.iterator();
        while (it.next()) |entry| {
            const ctx = entry.value_ptr.*;
            if (!ctx.closing) {
                ctx.cancelled = true;
                ctx.closing = true;
                _ = libuv.timerStop(&ctx.handle) catch {};
                libuv.close(libuv.timerToHandle(&ctx.handle), closeCallback);
            }
        }

        // Run the loop to process close callbacks
        while (self.timers.count() > 0) {
            _ = libuv.run(self.loop, .UV_RUN_NOWAIT);
        }

        // Close the loop
        libuv.loopClose(self.loop) catch {};

        // Free the loop memory
        // Cast back to aligned slice for proper deallocation
        const loop_bytes: [*]align(8) u8 = @ptrCast(@alignCast(self.loop));
        self.allocator.free(loop_bytes[0..libuv.getLoopSize()]);

        self.timers.deinit();
        self.allocator.destroy(self);
    }

    /// Schedule a one-shot timer.
    pub fn setTimeout(self: *Self, ms: u64, callback: TimerCallback, user_data: ?*anyopaque) TimerId {
        const id = self.next_id;
        self.next_id += 1;

        // Allocate timer context
        const ctx = self.allocator.create(TimerContext) catch {
            // If allocation fails, return 0 (invalid ID)
            return 0;
        };

        ctx.* = .{
            .callback = callback,
            .user_data = user_data,
            .id = id,
            .manager = self,
            .handle = undefined,
            .cancelled = false,
            .closing = false,
        };

        // Initialize the timer handle
        libuv.timerInit(self.loop, &ctx.handle) catch {
            self.allocator.destroy(ctx);
            return 0;
        };

        // Store context in handle's data field
        ctx.handle.data = ctx;

        // Start the timer
        libuv.timerStart(&ctx.handle, timerCallback, ms, 0) catch {
            libuv.close(libuv.timerToHandle(&ctx.handle), closeCallback);
            return 0;
        };

        // Track the timer
        self.timers.put(id, ctx) catch {
            _ = libuv.timerStop(&ctx.handle) catch {};
            libuv.close(libuv.timerToHandle(&ctx.handle), closeCallback);
            return 0;
        };

        return id;
    }

    /// Cancel a pending timer.
    pub fn clearTimeout(self: *Self, id: TimerId) void {
        if (id == 0) return; // Invalid ID

        const ctx = self.timers.get(id) orelse return;
        if (ctx.cancelled or ctx.closing) return;

        ctx.cancelled = true;
        ctx.closing = true;

        // Stop and close the timer
        _ = libuv.timerStop(&ctx.handle) catch {};
        libuv.close(libuv.timerToHandle(&ctx.handle), closeCallback);
    }

    /// Run the event loop once (non-blocking).
    /// This processes any ready timer callbacks without blocking.
    /// Returns true if there are still active handles.
    pub fn poll(self: *Self) bool {
        if (!self.initialized) return false;
        // Use UV_RUN_NOWAIT for non-blocking behavior.
        // This returns immediately even if there are pending timers.
        // The WPT runner's event loop has its own timeout mechanism.
        const result = libuv.run(self.loop, .UV_RUN_NOWAIT);
        return result > 0;
    }

    /// Run the event loop once (blocking).
    /// This blocks until at least one callback has been invoked, or until
    /// there are no more active handles.
    /// Returns true if there are still active handles.
    pub fn pollBlocking(self: *Self) bool {
        if (!self.initialized) return false;
        const result = libuv.run(self.loop, .UV_RUN_ONCE);
        return result > 0;
    }

    /// Get the timer interface for this manager.
    pub fn timerInterface(self: *Self) TimerInterface {
        return .{
            .vtable = &vtable,
            .ctx = self,
        };
    }

    // ========================================================================
    // VTable Implementation
    // ========================================================================

    const vtable = TimerVTable{
        .setTimeout = setTimeoutVTable,
        .clearTimeout = clearTimeoutVTable,
    };

    fn setTimeoutVTable(ctx: *anyopaque, ms: u64, callback: TimerCallback, user_data: ?*anyopaque) TimerId {
        const self: *Self = @ptrCast(@alignCast(ctx));
        return self.setTimeout(ms, callback, user_data);
    }

    fn clearTimeoutVTable(ctx: *anyopaque, id: TimerId) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.clearTimeout(id);
    }
};

// ============================================================================
// libuv Callbacks
// ============================================================================

/// Called by libuv when a timer fires.
fn timerCallback(handle: *libuv.uv_timer_t) callconv(.c) void {
    const ctx: *TimerContext = @ptrCast(@alignCast(handle.data));

    // Don't invoke callback if cancelled
    if (ctx.cancelled) return;

    // Mark as closing (one-shot timer)
    ctx.closing = true;

    // Invoke the user's callback
    ctx.callback(ctx.user_data);

    // Close the handle (will trigger closeCallback)
    libuv.close(libuv.timerToHandle(handle), closeCallback);
}

/// Called by libuv when a handle is fully closed.
fn closeCallback(handle: *libuv.uv_handle_t) callconv(.c) void {
    // Get the timer handle (same address due to embedding)
    const timer_handle: *libuv.uv_timer_t = @ptrCast(@alignCast(handle));
    const ctx: *TimerContext = @ptrCast(@alignCast(timer_handle.data));

    // Remove from tracking
    _ = ctx.manager.timers.remove(ctx.id);

    // Free the context
    ctx.manager.allocator.destroy(ctx);
}

// ============================================================================
// Tests
// ============================================================================

test "LibuvTimerManager - init and deinit" {
    const allocator = std.testing.allocator;

    const manager = try LibuvTimerManager.init(allocator);
    defer manager.deinit();

    try std.testing.expect(manager.initialized);
    try std.testing.expect(manager.next_id == 1);
}

test "LibuvTimerManager - setTimeout returns valid ID" {
    const allocator = std.testing.allocator;

    const manager = try LibuvTimerManager.init(allocator);
    defer manager.deinit();

    var called = false;
    const id = manager.setTimeout(0, struct {
        fn callback(data: ?*anyopaque) void {
            const ptr: *bool = @ptrCast(@alignCast(data.?));
            ptr.* = true;
        }
    }.callback, &called);

    try std.testing.expect(id != 0);
    try std.testing.expect(manager.timers.count() == 1);
}

test "LibuvTimerManager - clearTimeout" {
    const allocator = std.testing.allocator;

    const manager = try LibuvTimerManager.init(allocator);
    defer manager.deinit();

    var called = false;
    const id = manager.setTimeout(1000, struct {
        fn callback(data: ?*anyopaque) void {
            const ptr: *bool = @ptrCast(@alignCast(data.?));
            ptr.* = true;
        }
    }.callback, &called);

    try std.testing.expect(id != 0);

    // Cancel the timer
    manager.clearTimeout(id);

    // Poll to process the close
    _ = manager.poll();

    // Should not have been called
    try std.testing.expect(!called);
}

test "LibuvTimerManager - timer fires" {
    const allocator = std.testing.allocator;

    const manager = try LibuvTimerManager.init(allocator);
    defer manager.deinit();

    var called = false;
    const id = manager.setTimeout(1, struct {
        fn callback(data: ?*anyopaque) void {
            const ptr: *bool = @ptrCast(@alignCast(data.?));
            ptr.* = true;
        }
    }.callback, &called);

    try std.testing.expect(id != 0);

    // Wait for timer to fire (poll multiple times)
    var iterations: usize = 0;
    while (!called and iterations < 100) : (iterations += 1) {
        _ = manager.poll();
        std.time.sleep(1 * std.time.ns_per_ms);
    }

    try std.testing.expect(called);
}
