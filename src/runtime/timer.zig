//! Host-Agnostic Timer Interface
//!
//! This module defines a timer interface that can be implemented by different
//! host environments (V8+libuv, JavaScriptCore, standalone Zig, etc.).
//!
//! ## Design
//!
//! The timer interface is deliberately minimal and host-agnostic:
//! - `setTimeout` schedules a one-shot callback after N milliseconds
//! - `clearTimeout` cancels a pending timer
//!
//! Each host provides its own implementation. For V8 this is
//! engines/v8/native_timer.zig, which needs only a monotonic clock.
//! Future hosts can use their native timer facilities.
//!
//! ## Usage (Legacy anyopaque API)
//!
//! ```zig
//! // Get timer interface from runtime context
//! const timer = ctx.timer orelse return error.NoTimerSupport;
//!
//! // Schedule a timer
//! const id = timer.schedule(1000, myCallback, &myData);
//!
//! // Cancel if needed
//! timer.cancel(id);
//! ```
//!
//! ## Usage (Typed Callback API)
//!
//! For type-safe callbacks, use the typed wrapper pattern:
//!
//! ```zig
//! const typed_callback = @import("typed_callback.zig");
//!
//! const MyContext = struct {
//!     request_id: u64,
//!     on_timeout: *const fn (u64) void,
//! };
//!
//! fn handleTimeout(ctx: *MyContext) void {
//!     ctx.on_timeout(ctx.request_id);
//! }
//!
//! // Create typed wrapper
//! var ctx = MyContext{ .request_id = 123, .on_timeout = &logTimeout };
//! const wrapper = try typed_callback.SelfContainedCallback(MyContext, void).create(
//!     allocator,
//!     &handleTimeout,
//!     ctx,
//! );
//!
//! // Use with timer
//! const id = timer.setTimeoutTyped(
//!     wrapper.getTrampolineCallback(),
//!     wrapper.toAnyopaque(),
//!     1000,
//! );
//! ```
//!
//! ## Lifetime Contracts
//!
//! ### Timer Callbacks
//! - UserData must remain valid until timer fires OR is cancelled
//! - After callback invocation, timer system no longer references data
//! - If timer is cancelled, callback is NOT invoked - caller must clean up data
//! - For typed callbacks using SelfContainedCallback, remember to call destroy()
//!   after the timer fires or is cancelled

const std = @import("std");

/// Unique identifier for a scheduled timer.
/// Used to cancel pending timers via clearTimeout.
pub const TimerId = u64;

/// Callback function signature for timer expiration.
/// Called when the timer fires with the user-provided data.
pub const TimerCallback = *const fn (user_data: ?*anyopaque) void;

/// VTable for timer operations.
/// Host implementations provide these function pointers.
pub const TimerVTable = struct {
    /// Schedule a one-shot timer.
    setTimeout: *const fn (ctx: *anyopaque, ms: u64, callback: TimerCallback, user_data: ?*anyopaque) TimerId,

    /// Cancel a pending timer.
    ///
    /// Returns true only if a live timer with this id was found and cancelled.
    /// False means the callback may still fire - the id was unknown to THIS
    /// implementation, which is the normal cross-realm case: the thread-local
    /// TimerInterface belongs to the realm calling clearTimeout, not necessarily
    /// the realm that scheduled the timer. A caller that frees the callback's
    /// user_data on a false return frees memory the timer still points at.
    clearTimeout: *const fn (ctx: *anyopaque, id: TimerId) bool,
};

/// Host-agnostic timer interface.
///
/// Implementations provide the actual timer scheduling mechanism.
/// This could be libuv, platform APIs, or even a test mock.
pub const TimerInterface = struct {
    /// VTable with timer operations
    vtable: *const TimerVTable,

    /// Opaque context pointer for the timer implementation.
    /// This is passed as the first argument to vtable functions.
    ctx: *anyopaque,

    const Self = @This();

    /// Schedule a one-shot timer.
    ///
    /// Returns a TimerId that can be used to cancel the timer.
    /// The callback will be invoked after `ms` milliseconds with `user_data`.
    ///
    /// If `ms` is 0, the callback is scheduled to run as soon as possible
    /// (typically on the next event loop iteration).
    pub fn setTimeout(self: Self, ms: u64, callback: TimerCallback, user_data: ?*anyopaque) TimerId {
        return self.vtable.setTimeout(self.ctx, ms, callback, user_data);
    }

    /// Cancel a pending timer.
    ///
    /// If the timer has already fired or was already cancelled, this is a no-op.
    /// It is safe to call clearTimeout multiple times with the same id.
    /// Cancel a pending timer. See `TimerVTable.clearTimeout` - the return value
    /// must be honoured before freeing any user_data the timer holds.
    pub fn clearTimeout(self: Self, id: TimerId) bool {
        return self.vtable.clearTimeout(self.ctx, id);
    }
};

/// Error returned when timer operations are not available.
pub const TimerError = error{
    /// No timer interface is configured in the runtime context.
    NoTimerSupport,
    /// Timer allocation failed (too many concurrent timers).
    TimerAllocationFailed,
    /// The timer system is not initialized.
    TimerNotInitialized,
};

// ============================================================================
// Tests
// ============================================================================

test "TimerInterface - struct layout" {
    // Verify the interface struct has expected fields
    const vtable = TimerVTable{
        .setTimeout = undefined,
        .clearTimeout = undefined,
    };
    const ti = TimerInterface{
        .vtable = &vtable,
        .ctx = undefined,
    };
    _ = ti;
}
