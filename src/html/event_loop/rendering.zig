//! HTML Event Loop Rendering Steps
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#update-the-rendering
//! HTML Standard §8.1.7.2 "Processing model" - Update the rendering steps
//!
//! This module handles the rendering-related steps of the event loop,
//! including requestAnimationFrame callbacks and the rendering pipeline.

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");

/// A callback registered via requestAnimationFrame.
pub const FrameRequestCallback = struct {
    /// Unique handle for this callback.
    handle: u32,

    /// The callback function to invoke.
    callback: *const fn (context: ?*anyopaque, timestamp: f64) void,

    /// User context for the callback.
    context: ?*anyopaque,

    /// Whether this callback has been cancelled.
    cancelled: bool,
};

/// Manages requestAnimationFrame callbacks.
///
/// HTML Standard §8.1.7.2 step 3.14:
/// "For each doc of docs, run the animation frame callbacks for doc,
/// passing in the relative high resolution time given frameTimestamp
/// and doc's relevant global object as the timestamp."
pub const AnimationFrameProvider = struct {
    /// Registered callbacks.
    callbacks: infra.List(FrameRequestCallback),

    /// Next handle to assign.
    next_handle: u32,

    /// Allocator for memory management.
    allocator: Allocator,

    /// Initialize a new animation frame provider.
    pub fn init(allocator: Allocator) AnimationFrameProvider {
        return AnimationFrameProvider{
            .callbacks = infra.List(FrameRequestCallback).init(allocator),
            .next_handle = 1,
            .allocator = allocator,
        };
    }

    /// Free all resources.
    pub fn deinit(self: *AnimationFrameProvider) void {
        self.callbacks.deinit();
    }

    /// Register a callback to be invoked before the next repaint.
    ///
    /// Returns a handle that can be used to cancel the callback.
    ///
    /// HTML Standard §8.6.4 "Animation frames":
    /// The requestAnimationFrame(callback) method must run the following steps:
    /// 1. Let handle be a user-agent-defined integer that is greater than zero
    /// 2. Let callbacks be this's map of animation frame callbacks
    /// 3. Set callbacks[handle] to callback
    /// 4. Return handle
    pub fn requestAnimationFrame(
        self: *AnimationFrameProvider,
        callback: *const fn (context: ?*anyopaque, timestamp: f64) void,
        context: ?*anyopaque,
    ) !u32 {
        const handle = self.next_handle;
        self.next_handle +%= 1;

        try self.callbacks.append(FrameRequestCallback{
            .handle = handle,
            .callback = callback,
            .context = context,
            .cancelled = false,
        });

        return handle;
    }

    /// Cancel a previously registered callback.
    ///
    /// HTML Standard §8.6.4 "Animation frames":
    /// The cancelAnimationFrame(handle) method must remove the entry in
    /// this's map of animation frame callbacks with the given handle.
    pub fn cancelAnimationFrame(self: *AnimationFrameProvider, handle: u32) void {
        const slice = self.callbacks.toSlice();
        for (slice, 0..) |*cb, i| {
            if (cb.handle == handle) {
                // Mark as cancelled instead of removing (for safe iteration)
                var callbacks_mut = self.callbacks.toSliceMut();
                callbacks_mut[i].cancelled = true;
                break;
            }
        }
    }

    /// Run all registered animation frame callbacks.
    ///
    /// HTML Standard §8.1.7.2 "Run the animation frame callbacks":
    /// To run the animation frame callbacks for a Document doc with
    /// a timestamp now:
    /// 1. Let callbacks be doc's map of animation frame callbacks
    /// 2. Set doc's map of animation frame callbacks to an empty map
    /// 3. For each (handle, callback) in callbacks, run the following
    ///    substeps in parallel:
    ///    a. Invoke callback with now as the argument
    pub fn runAnimationFrameCallbacks(self: *AnimationFrameProvider, timestamp: f64) void {
        // Take the current callbacks and reset the list
        var callbacks_to_run = infra.List(FrameRequestCallback).init(self.allocator);
        defer callbacks_to_run.deinit();

        // Move all callbacks to the execution list
        const slice = self.callbacks.toSlice();
        for (slice) |cb| {
            if (!cb.cancelled) {
                callbacks_to_run.append(cb) catch continue;
            }
        }

        // Clear the original list
        self.callbacks.clear();

        // Run all callbacks
        const run_slice = callbacks_to_run.toSlice();
        for (run_slice) |cb| {
            cb.callback(cb.context, timestamp);
        }
    }

    /// Check if there are any pending callbacks.
    pub fn hasPendingCallbacks(self: *const AnimationFrameProvider) bool {
        const slice = self.callbacks.toSlice();
        for (slice) |cb| {
            if (!cb.cancelled) return true;
        }
        return false;
    }

    /// Get the number of pending callbacks.
    pub fn pendingCount(self: *const AnimationFrameProvider) usize {
        var count: usize = 0;
        const slice = self.callbacks.toSlice();
        for (slice) |cb| {
            if (!cb.cancelled) count += 1;
        }
        return count;
    }
};

/// Rendering state for a document.
pub const RenderingState = struct {
    /// Animation frame callbacks.
    animation_frames: AnimationFrameProvider,

    /// Whether rendering is suppressed.
    render_suppressed: bool,

    /// Last render time.
    last_render_time: i64,

    /// Target frame rate in Hz.
    target_frame_rate: u32,

    /// Allocator for memory management.
    allocator: Allocator,

    /// Initialize rendering state.
    pub fn init(allocator: Allocator) RenderingState {
        return RenderingState{
            .animation_frames = AnimationFrameProvider.init(allocator),
            .render_suppressed = false,
            .last_render_time = 0,
            .target_frame_rate = 60,
            .allocator = allocator,
        };
    }

    /// Free all resources.
    pub fn deinit(self: *RenderingState) void {
        self.animation_frames.deinit();
    }

    /// Check if there's a rendering opportunity.
    ///
    /// HTML Standard §8.1.7.2:
    /// "A navigable has a rendering opportunity if the user agent is
    /// currently able to present the contents of the navigable to the user"
    pub fn hasRenderingOpportunity(self: *const RenderingState, current_time: i64) bool {
        if (self.render_suppressed) return false;

        const frame_interval = @divTrunc(@as(i64, 1000), @as(i64, self.target_frame_rate));
        return (current_time - self.last_render_time) >= frame_interval;
    }

    /// Set whether rendering is suppressed.
    pub fn setRenderSuppressed(self: *RenderingState, suppressed: bool) void {
        self.render_suppressed = suppressed;
    }

    /// Set the target frame rate.
    pub fn setTargetFrameRate(self: *RenderingState, rate: u32) void {
        self.target_frame_rate = if (rate > 0) rate else 60;
    }

    /// Mark that rendering occurred at the given time.
    pub fn markRendered(self: *RenderingState, time: i64) void {
        self.last_render_time = time;
    }
};

/// Idle callback for requestIdleCallback.
pub const IdleCallback = struct {
    /// Unique handle.
    handle: u32,

    /// The callback function.
    callback: *const fn (context: ?*anyopaque, deadline: *IdleDeadline) void,

    /// User context.
    context: ?*anyopaque,

    /// Whether this callback has been cancelled.
    cancelled: bool,

    /// Timeout time (if specified), or null for no timeout.
    timeout_time: ?i64,
};

/// Deadline info passed to idle callbacks.
pub const IdleDeadline = struct {
    /// The deadline time.
    deadline: i64,

    /// Whether the callback was invoked due to timeout.
    did_timeout: bool,

    /// Current time function.
    get_current_time: *const fn () i64,

    /// Get the time remaining until the deadline.
    pub fn timeRemaining(self: *const IdleDeadline) f64 {
        const now = self.get_current_time();
        const remaining = self.deadline - now;
        return if (remaining > 0) @floatFromInt(remaining) else 0;
    }
};

/// Manager for requestIdleCallback.
///
/// HTML Standard §8.1.7.2 step 5:
/// "If this is a window event loop that has no runnable task in this
/// event loop's task queues..."
pub const IdleCallbackManager = struct {
    /// Registered callbacks.
    callbacks: infra.List(IdleCallback),

    /// Next handle to assign.
    next_handle: u32,

    /// Allocator.
    allocator: Allocator,

    /// Initialize.
    pub fn init(allocator: Allocator) IdleCallbackManager {
        return IdleCallbackManager{
            .callbacks = infra.List(IdleCallback).init(allocator),
            .next_handle = 1,
            .allocator = allocator,
        };
    }

    /// Free resources.
    pub fn deinit(self: *IdleCallbackManager) void {
        self.callbacks.deinit();
    }

    /// Register an idle callback.
    pub fn requestIdleCallback(
        self: *IdleCallbackManager,
        callback: *const fn (context: ?*anyopaque, deadline: *IdleDeadline) void,
        context: ?*anyopaque,
        timeout_ms: ?i64,
        current_time: i64,
    ) !u32 {
        const handle = self.next_handle;
        self.next_handle +%= 1;

        const timeout_time = if (timeout_ms) |ms| current_time + ms else null;

        try self.callbacks.append(IdleCallback{
            .handle = handle,
            .callback = callback,
            .context = context,
            .cancelled = false,
            .timeout_time = timeout_time,
        });

        return handle;
    }

    /// Cancel an idle callback.
    pub fn cancelIdleCallback(self: *IdleCallbackManager, handle: u32) void {
        const slice = self.callbacks.toSlice();
        for (slice, 0..) |_, i| {
            if (self.callbacks.get(i)) |cb| {
                if (cb.handle == handle) {
                    var callbacks_mut = self.callbacks.toSliceMut();
                    callbacks_mut[i].cancelled = true;
                    break;
                }
            }
        }
    }

    /// Check if there are pending callbacks (optionally checking timeouts).
    pub fn hasPendingCallbacks(self: *const IdleCallbackManager) bool {
        const slice = self.callbacks.toSlice();
        for (slice) |cb| {
            if (!cb.cancelled) return true;
        }
        return false;
    }
};

test "AnimationFrameProvider - basic usage" {
    const allocator = std.testing.allocator;

    var provider = AnimationFrameProvider.init(allocator);
    defer provider.deinit();

    try std.testing.expect(!provider.hasPendingCallbacks());

    var executed = false;
    const handle = try provider.requestAnimationFrame(
        struct {
            fn callback(ctx: ?*anyopaque, _: f64) void {
                const flag: *bool = @ptrCast(@alignCast(ctx.?));
                flag.* = true;
            }
        }.callback,
        @ptrCast(&executed),
    );

    try std.testing.expect(handle > 0);
    try std.testing.expect(provider.hasPendingCallbacks());
    try std.testing.expectEqual(@as(usize, 1), provider.pendingCount());

    provider.runAnimationFrameCallbacks(16.67);

    try std.testing.expect(executed);
    try std.testing.expect(!provider.hasPendingCallbacks());
}

test "AnimationFrameProvider - cancel callback" {
    const allocator = std.testing.allocator;

    var provider = AnimationFrameProvider.init(allocator);
    defer provider.deinit();

    var executed = false;
    const handle = try provider.requestAnimationFrame(
        struct {
            fn callback(ctx: ?*anyopaque, _: f64) void {
                const flag: *bool = @ptrCast(@alignCast(ctx.?));
                flag.* = true;
            }
        }.callback,
        @ptrCast(&executed),
    );

    provider.cancelAnimationFrame(handle);
    provider.runAnimationFrameCallbacks(16.67);

    try std.testing.expect(!executed);
}

test "AnimationFrameProvider - multiple callbacks" {
    const allocator = std.testing.allocator;

    var provider = AnimationFrameProvider.init(allocator);
    defer provider.deinit();

    var order: u32 = 0;

    _ = try provider.requestAnimationFrame(
        struct {
            fn callback(ctx: ?*anyopaque, _: f64) void {
                const o: *u32 = @ptrCast(@alignCast(ctx.?));
                o.* = o.* * 10 + 1;
            }
        }.callback,
        @ptrCast(&order),
    );

    _ = try provider.requestAnimationFrame(
        struct {
            fn callback(ctx: ?*anyopaque, _: f64) void {
                const o: *u32 = @ptrCast(@alignCast(ctx.?));
                o.* = o.* * 10 + 2;
            }
        }.callback,
        @ptrCast(&order),
    );

    _ = try provider.requestAnimationFrame(
        struct {
            fn callback(ctx: ?*anyopaque, _: f64) void {
                const o: *u32 = @ptrCast(@alignCast(ctx.?));
                o.* = o.* * 10 + 3;
            }
        }.callback,
        @ptrCast(&order),
    );

    try std.testing.expectEqual(@as(usize, 3), provider.pendingCount());

    provider.runAnimationFrameCallbacks(16.67);

    // Should run in order: 1, 2, 3
    try std.testing.expectEqual(@as(u32, 123), order);
    try std.testing.expectEqual(@as(usize, 0), provider.pendingCount());
}

test "AnimationFrameProvider - timestamp passed correctly" {
    const allocator = std.testing.allocator;

    var provider = AnimationFrameProvider.init(allocator);
    defer provider.deinit();

    var received_timestamp: f64 = 0;

    _ = try provider.requestAnimationFrame(
        struct {
            fn callback(ctx: ?*anyopaque, timestamp: f64) void {
                const ts: *f64 = @ptrCast(@alignCast(ctx.?));
                ts.* = timestamp;
            }
        }.callback,
        @ptrCast(&received_timestamp),
    );

    provider.runAnimationFrameCallbacks(1234.5678);

    try std.testing.expectApproxEqAbs(@as(f64, 1234.5678), received_timestamp, 0.0001);
}

test "RenderingState - rendering opportunity" {
    const allocator = std.testing.allocator;

    var state = RenderingState.init(allocator);
    defer state.deinit();

    // At time 0, should have opportunity (no previous render)
    try std.testing.expect(state.hasRenderingOpportunity(0));

    // Mark rendered at time 0
    state.markRendered(0);

    // At time 10ms, should NOT have opportunity (60Hz = 16.67ms frame)
    try std.testing.expect(!state.hasRenderingOpportunity(10));

    // At time 17ms, should have opportunity
    try std.testing.expect(state.hasRenderingOpportunity(17));
}

test "RenderingState - suppressed rendering" {
    const allocator = std.testing.allocator;

    var state = RenderingState.init(allocator);
    defer state.deinit();

    try std.testing.expect(state.hasRenderingOpportunity(0));

    state.setRenderSuppressed(true);

    try std.testing.expect(!state.hasRenderingOpportunity(0));
    try std.testing.expect(!state.hasRenderingOpportunity(1000));

    state.setRenderSuppressed(false);

    try std.testing.expect(state.hasRenderingOpportunity(0));
}

test "IdleCallbackManager - basic usage" {
    const allocator = std.testing.allocator;

    var manager = IdleCallbackManager.init(allocator);
    defer manager.deinit();

    try std.testing.expect(!manager.hasPendingCallbacks());

    const handle = try manager.requestIdleCallback(
        struct {
            fn callback(_: ?*anyopaque, _: *IdleDeadline) void {}
        }.callback,
        null,
        null,
        0,
    );

    try std.testing.expect(handle > 0);
    try std.testing.expect(manager.hasPendingCallbacks());

    manager.cancelIdleCallback(handle);

    try std.testing.expect(!manager.hasPendingCallbacks());
}
