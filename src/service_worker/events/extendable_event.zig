//! ExtendableEvent
//!
//! Base event class for Service Worker events that support waitUntil().
//!
//! Spec: https://w3c.github.io/ServiceWorker/#extendableevent-interface
//!
//! WebIDL:
//! ```idl
//! [Exposed=ServiceWorker]
//! interface ExtendableEvent : Event {
//!   constructor(DOMString type, optional ExtendableEventInit eventInitDict = {});
//!   undefined waitUntil(Promise<any> f);
//! };
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// ExtendableEvent initialization options.
pub const ExtendableEventInit = struct {
    /// Event bubbles up through the DOM tree.
    bubbles: bool = false,
    /// Event can be canceled.
    cancelable: bool = false,
};

/// Promise handle for waitUntil tracking.
pub const PromiseHandle = struct {
    /// Unique ID for this promise.
    id: u64,
    /// Whether this promise has settled.
    settled: bool = false,
    /// Whether the promise was rejected.
    rejected: bool = false,
    /// Error message if rejected.
    error_message: ?[]const u8 = null,
};

/// ExtendableEvent.
///
/// Base event for install, activate, and other SW lifecycle events.
/// Supports waitUntil() to extend the event's lifetime until promises settle.
///
/// Spec: https://w3c.github.io/ServiceWorker/#extendableevent-interface
pub const ExtendableEvent = struct {
    allocator: Allocator,

    /// Event type (e.g., "install", "activate").
    event_type: []const u8,

    /// Whether the event bubbles.
    bubbles: bool = false,

    /// Whether the event is cancelable.
    cancelable: bool = false,

    /// Whether the default action was prevented.
    default_prevented: bool = false,

    /// The event target (ServiceWorkerGlobalScope).
    target: ?*anyopaque = null,

    /// Whether the event is being dispatched.
    dispatch_flag: bool = false,

    /// Whether extensions are allowed (true during dispatch).
    extensions_allowed: bool = true,

    /// List of promises added via waitUntil().
    extend_lifetime_promises: std.ArrayListUnmanaged(PromiseHandle),

    /// Count of pending (unsettled) promises.
    pending_promises_count: u32 = 0,

    /// Whether the event timed out.
    timed_out_flag: bool = false,

    /// Counter for promise IDs.
    next_promise_id: u64 = 0,

    const Self = @This();

    // =========================================================================
    // Construction
    // =========================================================================

    /// Create a new ExtendableEvent.
    pub fn init(allocator: Allocator, event_type: []const u8, options: ExtendableEventInit) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        const type_copy = try allocator.dupe(u8, event_type);

        self.* = .{
            .allocator = allocator,
            .event_type = type_copy,
            .bubbles = options.bubbles,
            .cancelable = options.cancelable,
            .extend_lifetime_promises = .{},
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        // Free any error messages in promises
        for (self.extend_lifetime_promises.items) |promise| {
            if (promise.error_message) |msg| {
                self.allocator.free(msg);
            }
        }
        self.extend_lifetime_promises.deinit(self.allocator);
        self.allocator.free(self.event_type);
        self.allocator.destroy(self);
    }

    // =========================================================================
    // WebIDL Methods
    // =========================================================================

    /// Add a promise to extend the event's lifetime.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#extendableevent-waituntil
    ///
    /// Steps:
    /// 1. If extensions_allowed is false, throw InvalidStateError
    /// 2. Add promise to extend_lifetime_promises
    /// 3. Increment pending_promises_count
    pub fn waitUntil(self: *Self) !u64 {
        // Step 1: Check if extensions are allowed
        if (!self.extensions_allowed) {
            return error.InvalidStateError;
        }

        // Step 2: Create promise handle
        const promise_id = self.next_promise_id;
        self.next_promise_id += 1;

        const handle = PromiseHandle{
            .id = promise_id,
            .settled = false,
        };

        try self.extend_lifetime_promises.append(self.allocator, handle);

        // Step 3: Increment pending count
        self.pending_promises_count += 1;

        return promise_id;
    }

    /// Resolve a waitUntil promise.
    pub fn resolvePromise(self: *Self, promise_id: u64) void {
        for (self.extend_lifetime_promises.items) |*promise| {
            if (promise.id == promise_id and !promise.settled) {
                promise.settled = true;
                promise.rejected = false;
                if (self.pending_promises_count > 0) {
                    self.pending_promises_count -= 1;
                }
                break;
            }
        }
    }

    /// Reject a waitUntil promise.
    pub fn rejectPromise(self: *Self, promise_id: u64, error_message: ?[]const u8) void {
        for (self.extend_lifetime_promises.items) |*promise| {
            if (promise.id == promise_id and !promise.settled) {
                promise.settled = true;
                promise.rejected = true;
                if (error_message) |msg| {
                    promise.error_message = self.allocator.dupe(u8, msg) catch null;
                }
                if (self.pending_promises_count > 0) {
                    self.pending_promises_count -= 1;
                }
                break;
            }
        }
    }

    // =========================================================================
    // Event Dispatch
    // =========================================================================

    /// Begin dispatch phase.
    pub fn startDispatch(self: *Self, target_ptr: *anyopaque) void {
        self.dispatch_flag = true;
        self.extensions_allowed = true;
        self.target = target_ptr;
    }

    /// End dispatch phase.
    ///
    /// After dispatch ends, extensions are no longer allowed.
    pub fn endDispatch(self: *Self) void {
        self.dispatch_flag = false;
        self.extensions_allowed = false;
    }

    // =========================================================================
    // State Queries
    // =========================================================================

    /// Check if all promises have settled.
    pub fn isComplete(self: *const Self) bool {
        return self.pending_promises_count == 0;
    }

    /// Check if any promise was rejected.
    pub fn hasRejection(self: *const Self) bool {
        for (self.extend_lifetime_promises.items) |promise| {
            if (promise.rejected) {
                return true;
            }
        }
        return false;
    }

    /// Get the number of pending promises.
    pub fn getPendingCount(self: *const Self) u32 {
        return self.pending_promises_count;
    }

    /// Check if extensions are still allowed.
    pub fn canExtend(self: *const Self) bool {
        return self.extensions_allowed;
    }

    /// Get the event type.
    pub fn getType(self: *const Self) []const u8 {
        return self.event_type;
    }

    /// Prevent default action.
    pub fn preventDefault(self: *Self) void {
        if (self.cancelable) {
            self.default_prevented = true;
        }
    }

    /// Check if default was prevented.
    pub fn isDefaultPrevented(self: *const Self) bool {
        return self.default_prevented;
    }

    /// Set timeout flag.
    pub fn setTimeout(self: *Self) void {
        self.timed_out_flag = true;
    }

    /// Check if timed out.
    pub fn isTimedOut(self: *const Self) bool {
        return self.timed_out_flag;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "ExtendableEvent.init and deinit" {
    const allocator = std.testing.allocator;

    const event = try ExtendableEvent.init(allocator, "install", .{});
    defer event.deinit();

    try std.testing.expectEqualStrings("install", event.getType());
    try std.testing.expect(event.canExtend());
    try std.testing.expect(event.isComplete());
}

test "ExtendableEvent.waitUntil" {
    const allocator = std.testing.allocator;

    const event = try ExtendableEvent.init(allocator, "activate", .{});
    defer event.deinit();

    // Add promise via waitUntil
    const promise_id = try event.waitUntil();
    try std.testing.expectEqual(@as(u32, 1), event.getPendingCount());
    try std.testing.expect(!event.isComplete());

    // Resolve the promise
    event.resolvePromise(promise_id);
    try std.testing.expectEqual(@as(u32, 0), event.getPendingCount());
    try std.testing.expect(event.isComplete());
}

test "ExtendableEvent.waitUntil multiple promises" {
    const allocator = std.testing.allocator;

    const event = try ExtendableEvent.init(allocator, "install", .{});
    defer event.deinit();

    const p1 = try event.waitUntil();
    const p2 = try event.waitUntil();
    const p3 = try event.waitUntil();

    try std.testing.expectEqual(@as(u32, 3), event.getPendingCount());

    event.resolvePromise(p1);
    try std.testing.expectEqual(@as(u32, 2), event.getPendingCount());

    event.rejectPromise(p2, "test error");
    try std.testing.expectEqual(@as(u32, 1), event.getPendingCount());
    try std.testing.expect(event.hasRejection());

    event.resolvePromise(p3);
    try std.testing.expect(event.isComplete());
}

test "ExtendableEvent.waitUntil after dispatch ends" {
    const allocator = std.testing.allocator;

    const event = try ExtendableEvent.init(allocator, "install", .{});
    defer event.deinit();

    // Start and end dispatch
    var dummy: u8 = 0;
    event.startDispatch(&dummy);
    event.endDispatch();

    // waitUntil should fail now
    try std.testing.expect(!event.canExtend());
    const result = event.waitUntil();
    try std.testing.expectError(error.InvalidStateError, result);
}

test "ExtendableEvent.preventDefault" {
    const allocator = std.testing.allocator;

    // Non-cancelable event
    const event1 = try ExtendableEvent.init(allocator, "install", .{ .cancelable = false });
    defer event1.deinit();

    event1.preventDefault();
    try std.testing.expect(!event1.isDefaultPrevented());

    // Cancelable event
    const event2 = try ExtendableEvent.init(allocator, "install", .{ .cancelable = true });
    defer event2.deinit();

    event2.preventDefault();
    try std.testing.expect(event2.isDefaultPrevented());
}

test "ExtendableEvent.timeout" {
    const allocator = std.testing.allocator;

    const event = try ExtendableEvent.init(allocator, "install", .{});
    defer event.deinit();

    try std.testing.expect(!event.isTimedOut());

    event.setTimeout();
    try std.testing.expect(event.isTimedOut());
}
