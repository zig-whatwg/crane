//! Promise Rejection Tracking
//!
//! Implements tracking of unhandled promise rejections for the
//! "unhandledrejection" and "rejectionhandled" events per HTML § 8.1.4.7.
//!
//! ## Overview
//!
//! When a promise is rejected without a handler, the browser should:
//! 1. Add it to the "about to be notified rejected promises" list
//! 2. Queue a task to fire "unhandledrejection" event
//! 3. If handler is added later, fire "rejectionhandled" event
//!
//! This module:
//! - Registers a V8 promise rejection callback
//! - Tracks rejected promises awaiting notification
//! - Fires PromiseRejectionEvent to the appropriate global scope
//!
//! ## Usage
//!
//! ```zig
//! // During isolate initialization
//! try promise_rejection.init(allocator, isolate);
//! defer promise_rejection.deinit();
//! ```

const std = @import("std");
const ffi = @import("ffi.zig");
const runtime = @import("runtime");

/// State for tracking promise rejections
pub const PromiseRejectionTracker = struct {
    /// Allocator for internal state
    allocator: std.mem.Allocator,

    /// The V8 isolate being tracked
    isolate: *ffi.Isolate,

    /// Promises rejected with no handler, awaiting "unhandledrejection" notification
    /// Key: Promise Global handle pointer
    /// Value: Rejection info (reason, timestamp)
    pending_rejections: std.AutoHashMap(*anyopaque, RejectionInfo),

    /// Callback to fire when unhandled rejection is detected
    on_unhandled_rejection: ?OnRejectionCallback = null,

    /// Callback to fire when handler is added to rejected promise
    on_rejection_handled: ?OnRejectionCallback = null,

    /// User data for callbacks
    callback_context: ?*anyopaque = null,

    const Self = @This();

    /// Information about a rejected promise
    pub const RejectionInfo = struct {
        /// The rejection reason (Global handle, or null if undefined)
        reason: ?*anyopaque,
        /// Timestamp of rejection (for debugging)
        timestamp: i64,
    };

    /// Callback type for rejection events
    pub const OnRejectionCallback = *const fn (
        context: ?*anyopaque,
        promise: *anyopaque,
        reason: ?*anyopaque,
    ) void;

    /// Initialize promise rejection tracking for an isolate
    pub fn init(allocator: std.mem.Allocator, isolate: *ffi.Isolate) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        self.* = .{
            .allocator = allocator,
            .isolate = isolate,
            .pending_rejections = std.AutoHashMap(*anyopaque, RejectionInfo).init(allocator),
            .on_unhandled_rejection = null,
            .on_rejection_handled = null,
            .callback_context = null,
        };

        // Register V8 callback
        ffi.v8_Isolate_SetPromiseRejectCallback(isolate, self, promiseRejectCallback);

        return self;
    }

    /// Clean up promise rejection tracking
    pub fn deinit(self: *Self) void {
        // Clear V8 callback
        ffi.v8_Isolate_ClearPromiseRejectCallback(self.isolate);

        // Dispose any pending rejection handles
        var it = self.pending_rejections.iterator();
        while (it.next()) |entry| {
            // Dispose promise handle
            ffi.v8_Global_Dispose(@ptrCast(entry.key_ptr.*));
            // Dispose reason handle if present
            if (entry.value_ptr.reason) |reason| {
                ffi.v8_Global_Dispose(@ptrCast(reason));
            }
        }
        self.pending_rejections.deinit();

        self.allocator.destroy(self);
    }

    /// Set callbacks for rejection events
    pub fn setCallbacks(
        self: *Self,
        on_unhandled: ?OnRejectionCallback,
        on_handled: ?OnRejectionCallback,
        context: ?*anyopaque,
    ) void {
        self.on_unhandled_rejection = on_unhandled;
        self.on_rejection_handled = on_handled;
        self.callback_context = context;
    }

    /// Handle promise rejection without handler
    fn handleRejectWithNoHandler(self: *Self, promise: *anyopaque, reason: ?*anyopaque) void {
        // Track this rejection for later notification
        const info = RejectionInfo{
            .reason = reason,
            .timestamp = std.time.milliTimestamp(),
        };

        self.pending_rejections.put(promise, info) catch |err| {
            std.log.warn("Failed to track promise rejection: {}", .{err});
            return;
        };

        // Fire callback if registered
        if (self.on_unhandled_rejection) |callback| {
            callback(self.callback_context, promise, reason);
        }
    }

    /// Handle handler added to previously-rejected promise
    fn handleHandlerAddedAfterReject(self: *Self, promise: *anyopaque) void {
        // Remove from pending list
        if (self.pending_rejections.fetchRemove(promise)) |kv| {
            const reason = kv.value.reason;

            // Fire callback if registered
            if (self.on_rejection_handled) |callback| {
                callback(self.callback_context, promise, reason);
            }

            // Note: We don't dispose handles here - V8 may still reference them.
            // The caller is responsible for cleanup when processing the event.
        }
    }

    /// V8 callback for promise rejection events
    fn promiseRejectCallback(
        user_data: ?*anyopaque,
        event_type: c_int,
        promise: ?*anyopaque,
        value: ?*anyopaque,
    ) callconv(.c) void {
        const self: *Self = @ptrCast(@alignCast(user_data orelse return));
        const promise_ptr = promise orelse return;

        const event = @as(ffi.PromiseRejectEvent, @enumFromInt(event_type));

        switch (event) {
            .kPromiseRejectWithNoHandler => {
                self.handleRejectWithNoHandler(promise_ptr, value);
            },
            .kPromiseHandlerAddedAfterReject => {
                self.handleHandlerAddedAfterReject(promise_ptr);
            },
            .kPromiseRejectAfterResolved, .kPromiseResolveAfterResolved => {
                // These are typically ignored per spec
                // Log for debugging if needed
            },
        }
    }
};

// ============================================================================
// Thread-local tracker instance
// ============================================================================

/// Thread-local tracker instance (one per isolate/thread)
threadlocal var current_tracker: ?*PromiseRejectionTracker = null;

/// Initialize promise rejection tracking for the current thread's isolate
pub fn init(allocator: std.mem.Allocator, isolate: *ffi.Isolate) !void {
    if (current_tracker != null) {
        return error.AlreadyInitialized;
    }
    current_tracker = try PromiseRejectionTracker.init(allocator, isolate);
}

/// Clean up promise rejection tracking for the current thread
pub fn deinit() void {
    if (current_tracker) |tracker| {
        tracker.deinit();
        current_tracker = null;
    }
}

/// Get the current tracker instance
pub fn get() ?*PromiseRejectionTracker {
    return current_tracker;
}

/// Set callbacks for rejection events
pub fn setCallbacks(
    on_unhandled: ?PromiseRejectionTracker.OnRejectionCallback,
    on_handled: ?PromiseRejectionTracker.OnRejectionCallback,
    context: ?*anyopaque,
) void {
    if (current_tracker) |tracker| {
        tracker.setCallbacks(on_unhandled, on_handled, context);
    }
}
