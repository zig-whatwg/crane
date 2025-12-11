//! IndexedDB Event Handling
//!
//! Implements event firing algorithms per W3C IndexedDB 3.0 specification.
//! https://w3c.github.io/IndexedDB/
//!
//! ## Algorithms Implemented
//!
//! - fire a success event (§4.3.1)
//! - fire an error event (§4.3.2)
//! - fire a version change event (§4.3.3)
//!
//! ## Event Flow
//!
//! IndexedDB events follow a specific pattern:
//! 1. Create event object
//! 2. Set event properties (type, bubbles, cancelable)
//! 3. Activate transaction state during dispatch
//! 4. Dispatch event to target
//! 5. Handle post-dispatch actions (auto-commit, abort)
//!
//! ## Spec Reference
//!
//! https://w3c.github.io/IndexedDB/#fire-a-success-event
//! https://w3c.github.io/IndexedDB/#fire-an-error-event
//! https://w3c.github.io/IndexedDB/#fire-a-version-change-event

const std = @import("std");
const IDBRequest = @import("request.zig").IDBRequest;
const IDBOpenDBRequest = @import("request.zig").IDBOpenDBRequest;
const IDBTransaction = @import("transaction.zig").IDBTransaction;
const IDBTransactionState = @import("transaction.zig").IDBTransactionState;
const IDBVersionChangeEvent = @import("version_change_event.zig").IDBVersionChangeEvent;
const IDBError = @import("errors.zig").IDBError;

/// Generic IDB Event for success/error
pub const IDBEvent = struct {
    const Self = @This();

    /// Event type
    event_type: EventType,

    /// Whether event bubbles
    bubbles: bool,

    /// Whether event is cancelable
    cancelable: bool,

    /// Whether default was prevented
    default_prevented: bool,

    /// Event phase
    event_phase: EventPhase,

    /// Target
    /// KEEP: anyopaque is intentional - DOM events can target multiple types
    /// (IDBRequest, IDBTransaction, IDBDatabase). Per DOM Events spec, target
    /// is polymorphic and type erasure is appropriate here.
    target: ?*anyopaque,

    /// Current target
    /// KEEP: anyopaque is intentional - same polymorphism as target field
    current_target: ?*anyopaque,

    /// Whether propagation was stopped
    propagation_stopped: bool,

    /// Whether immediate propagation was stopped
    immediate_propagation_stopped: bool,

    /// Event types
    pub const EventType = enum {
        success,
        @"error",
        complete,
        abort,
    };

    /// Event phase
    pub const EventPhase = enum(u8) {
        none = 0,
        capturing_phase = 1,
        at_target = 2,
        bubbling_phase = 3,
    };

    /// Create a success event
    pub fn success() Self {
        return Self{
            .event_type = .success,
            .bubbles = false, // Success events don't bubble
            .cancelable = false, // Success events are not cancelable
            .default_prevented = false,
            .event_phase = .none,
            .target = null,
            .current_target = null,
            .propagation_stopped = false,
            .immediate_propagation_stopped = false,
        };
    }

    /// Create an error event
    pub fn @"error"() Self {
        return Self{
            .event_type = .@"error",
            .bubbles = true, // Error events bubble
            .cancelable = true, // Error events are cancelable
            .default_prevented = false,
            .event_phase = .none,
            .target = null,
            .current_target = null,
            .propagation_stopped = false,
            .immediate_propagation_stopped = false,
        };
    }

    /// Create a complete event
    pub fn complete() Self {
        return Self{
            .event_type = .complete,
            .bubbles = false,
            .cancelable = false,
            .default_prevented = false,
            .event_phase = .none,
            .target = null,
            .current_target = null,
            .propagation_stopped = false,
            .immediate_propagation_stopped = false,
        };
    }

    /// Create an abort event
    pub fn abort() Self {
        return Self{
            .event_type = .abort,
            .bubbles = true, // Abort events bubble
            .cancelable = false, // Abort events are not cancelable
            .default_prevented = false,
            .event_phase = .none,
            .target = null,
            .current_target = null,
            .propagation_stopped = false,
            .immediate_propagation_stopped = false,
        };
    }

    /// Prevent default action
    pub fn preventDefault(self: *Self) void {
        if (self.cancelable) {
            self.default_prevented = true;
        }
    }

    /// Stop propagation
    pub fn stopPropagation(self: *Self) void {
        self.propagation_stopped = true;
    }

    /// Stop immediate propagation
    pub fn stopImmediatePropagation(self: *Self) void {
        self.propagation_stopped = true;
        self.immediate_propagation_stopped = true;
    }

    /// Get event type as string
    pub fn getType(self: *const Self) []const u8 {
        return switch (self.event_type) {
            .success => "success",
            .@"error" => "error",
            .complete => "complete",
            .abort => "abort",
        };
    }
};

/// Result of event dispatch
pub const EventDispatchResult = struct {
    /// Whether listeners threw an exception
    listeners_threw: bool,
    /// Whether event was canceled (preventDefault called)
    canceled: bool,
};

// ============================================================================
// Event Firing Algorithms
// ============================================================================

/// Fire a success event at a request
/// https://w3c.github.io/IndexedDB/#fire-a-success-event
///
/// Steps:
/// 1. Create event using Event
/// 2. Set type to "success"
/// 3. Set bubbles and cancelable to false
/// 4. Get transaction from request
/// 5. If transaction inactive, set to active
/// 6. Dispatch event with legacyOutputDidListenersThrowFlag
/// 7. If transaction active, set to inactive
/// 8. If listeners threw, abort transaction with AbortError
/// 9. If request list empty, commit transaction
pub fn fireSuccessEvent(request: *IDBRequest) EventDispatchResult {
    // Step 1: Create event
    var event = IDBEvent.success();

    // Step 2-3: Type, bubbles, cancelable already set by IDBEvent.success()

    // Step 4: Get transaction
    // REFACTORED: request.transaction is now properly typed as ?*IDBTransaction
    const txn = request.transaction orelse {
        // No transaction - just call handler and return
        if (request.onsuccess) |handler| {
            handler(request);
        }
        return .{ .listeners_threw = false, .canceled = false };
    };

    // Step 5: If transaction inactive, set to active
    var was_inactive = false;
    if (txn.state == .inactive) {
        txn.state = .active;
        was_inactive = true;
    }

    // Step 6: Dispatch event
    // Note: listeners_threw would be set by exception handling in a full impl
    const listeners_threw = false;
    event.target = request;
    event.current_target = request;
    event.event_phase = .at_target;

    // Call success handler
    if (request.onsuccess) |handler| {
        // In real impl, would catch exceptions and set listeners_threw
        handler(request);
    }

    // Step 7-8: Post-dispatch handling
    if (txn.state == .active) {
        // Step 7: Set to inactive
        txn.state = .inactive;

        // Step 8: If listeners threw, abort with AbortError
        if (listeners_threw) {
            txn.err = IDBError.AbortError;
            txn.state = .finished;
            if (txn.onabort) |abort_handler| {
                abort_handler(txn);
            }
            return .{ .listeners_threw = true, .canceled = false };
        }

        // Step 9: If request list empty, commit transaction
        if (txn.requests.items.len == 0 or allRequestsProcessed(txn)) {
            txn.commit() catch {
                // Commit failed, abort
                txn.err = IDBError.AbortError;
                txn.state = .finished;
            };
        }
    }

    return .{ .listeners_threw = listeners_threw, .canceled = event.default_prevented };
}

/// Fire an error event at a request
/// https://w3c.github.io/IndexedDB/#fire-an-error-event
///
/// Steps:
/// 1. Create event using Event
/// 2. Set type to "error"
/// 3. Set bubbles and cancelable to true
/// 4. Get transaction from request
/// 5. If transaction inactive, set to active
/// 6. Dispatch event with legacyOutputDidListenersThrowFlag
/// 7. If transaction active:
///    - Set to inactive
///    - If listeners threw, abort with AbortError
///    - If not canceled, abort with request's error
///    - If request list empty, commit
pub fn fireErrorEvent(request: *IDBRequest) EventDispatchResult {
    // Step 1: Create event
    var event = IDBEvent.@"error"();

    // Step 2-3: Type, bubbles, cancelable already set

    // Step 4: Get transaction
    // REFACTORED: request.transaction is now properly typed as ?*IDBTransaction
    const txn = request.transaction orelse {
        // No transaction - just call handler
        if (request.onerror) |handler| {
            handler(request);
        }
        return .{ .listeners_threw = false, .canceled = false };
    };

    // Step 5: If transaction inactive, set to active
    if (txn.state == .inactive) {
        txn.state = .active;
    }

    // Step 6: Dispatch event
    // Note: listeners_threw would be set by exception handling in a full impl
    const listeners_threw = false;
    event.target = request;
    event.current_target = request;
    event.event_phase = .at_target;

    // Call error handler
    if (request.onerror) |handler| {
        handler(request);
    }

    // Step 7: Post-dispatch handling
    if (txn.state == .active) {
        txn.state = .inactive;

        // If listeners threw, abort with AbortError
        if (listeners_threw) {
            txn.err = IDBError.AbortError;
            txn.state = .finished;
            if (txn.onabort) |abort_handler| {
                abort_handler(txn);
            }
            return .{ .listeners_threw = true, .canceled = event.default_prevented };
        }

        // If not canceled, abort with request's error
        if (!event.default_prevented) {
            txn.err = request.err orelse IDBError.AbortError;
            txn.state = .finished;
            if (txn.onabort) |abort_handler| {
                abort_handler(txn);
            }
            return .{ .listeners_threw = false, .canceled = false };
        }

        // If request list empty, commit
        if (txn.requests.items.len == 0 or allRequestsProcessed(txn)) {
            txn.commit() catch {
                txn.err = IDBError.AbortError;
                txn.state = .finished;
            };
        }
    }

    return .{ .listeners_threw = listeners_threw, .canceled = event.default_prevented };
}

/// Fire a version change event
/// https://w3c.github.io/IndexedDB/#fire-a-version-change-event
///
/// Steps:
/// 1. Create event using IDBVersionChangeEvent
/// 2. Set type to event_name
/// 3. Set bubbles and cancelable to false
/// 4. Set oldVersion and newVersion
/// 5. Dispatch event
/// 6. Return legacyOutputDidListenersThrowFlag
pub fn fireVersionChangeEvent(
    target: *IDBOpenDBRequest,
    event_type: IDBVersionChangeEvent.EventType,
    old_version: u64,
    new_version: ?u64,
) EventDispatchResult {
    // Steps 1-4: Create event with all properties
    var event = IDBVersionChangeEvent.init(event_type, .{
        .old_version = old_version,
        .new_version = new_version,
    });

    // Step 5: Dispatch
    // Note: listeners_threw would be set by exception handling in a full impl
    const listeners_threw = false;
    event.target = target;
    event.current_target = target;
    event.event_phase = .at_target;

    // Call appropriate handler
    switch (event_type) {
        .upgradeneeded => {
            if (target.onupgradeneeded) |handler| {
                handler(target);
            }
        },
        .blocked => {
            if (target.onblocked) |handler| {
                handler(target);
            }
        },
        .success => {
            if (target.base.onsuccess) |handler| {
                handler(&target.base);
            }
        },
        .versionchange => {
            // versionchange is fired on database, not request
            // In a full impl, would dispatch to db.onversionchange
        },
    }

    // Step 6: Return
    return .{ .listeners_threw = listeners_threw, .canceled = event.default_prevented };
}

/// Fire a blocked event at a request
/// Helper for when database upgrade is blocked by open connections
pub fn fireBlockedEvent(
    request: *IDBOpenDBRequest,
    old_version: u64,
    new_version: ?u64,
) EventDispatchResult {
    return fireVersionChangeEvent(request, .blocked, old_version, new_version);
}

/// Fire an upgradeneeded event at a request
/// Helper for when database needs schema upgrade
pub fn fireUpgradeneededEvent(
    request: *IDBOpenDBRequest,
    old_version: u64,
    new_version: u64,
) EventDispatchResult {
    return fireVersionChangeEvent(request, .upgradeneeded, old_version, new_version);
}

/// Fire a complete event at a transaction
pub fn fireCompleteEvent(txn: *IDBTransaction) EventDispatchResult {
    var event = IDBEvent.complete();
    event.target = txn;
    event.current_target = txn;
    event.event_phase = .at_target;

    if (txn.oncomplete) |handler| {
        handler(txn);
    }

    return .{ .listeners_threw = false, .canceled = false };
}

/// Fire an abort event at a transaction
pub fn fireAbortEvent(txn: *IDBTransaction) EventDispatchResult {
    var event = IDBEvent.abort();
    event.target = txn;
    event.current_target = txn;
    event.event_phase = .at_target;

    if (txn.onabort) |handler| {
        handler(txn);
    }

    return .{ .listeners_threw = false, .canceled = false };
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Check if all requests in transaction have been processed
fn allRequestsProcessed(txn: *IDBTransaction) bool {
    for (txn.requests.items) |req| {
        if (!req.processed_flag) {
            return false;
        }
    }
    return true;
}

// ============================================================================
// Tests
// ============================================================================

test "IDBEvent - success event properties" {
    const event = IDBEvent.success();

    try std.testing.expectEqual(IDBEvent.EventType.success, event.event_type);
    try std.testing.expect(!event.bubbles);
    try std.testing.expect(!event.cancelable);
    try std.testing.expectEqualStrings("success", event.getType());
}

test "IDBEvent - error event properties" {
    const event = IDBEvent.@"error"();

    try std.testing.expectEqual(IDBEvent.EventType.@"error", event.event_type);
    try std.testing.expect(event.bubbles);
    try std.testing.expect(event.cancelable);
    try std.testing.expectEqualStrings("error", event.getType());
}

test "IDBEvent - complete event properties" {
    const event = IDBEvent.complete();

    try std.testing.expectEqual(IDBEvent.EventType.complete, event.event_type);
    try std.testing.expect(!event.bubbles);
    try std.testing.expect(!event.cancelable);
}

test "IDBEvent - abort event properties" {
    const event = IDBEvent.abort();

    try std.testing.expectEqual(IDBEvent.EventType.abort, event.event_type);
    try std.testing.expect(event.bubbles);
    try std.testing.expect(!event.cancelable);
}

test "IDBEvent - preventDefault only works on cancelable" {
    var success_event = IDBEvent.success();
    success_event.preventDefault();
    try std.testing.expect(!success_event.default_prevented);

    var error_event = IDBEvent.@"error"();
    error_event.preventDefault();
    try std.testing.expect(error_event.default_prevented);
}

test "IDBEvent - stopPropagation" {
    var event = IDBEvent.success();
    try std.testing.expect(!event.propagation_stopped);

    event.stopPropagation();
    try std.testing.expect(event.propagation_stopped);
}

test "IDBEvent - stopImmediatePropagation" {
    var event = IDBEvent.success();
    try std.testing.expect(!event.propagation_stopped);
    try std.testing.expect(!event.immediate_propagation_stopped);

    event.stopImmediatePropagation();
    try std.testing.expect(event.propagation_stopped);
    try std.testing.expect(event.immediate_propagation_stopped);
}

test "fireSuccessEvent - without transaction" {
    const allocator = std.testing.allocator;

    var request = IDBRequest.init(allocator);
    defer request.deinit();
    request.setResult(.{ .count = 42 });

    var handler_called = false;
    const Handler = struct {
        var called: *bool = undefined;
        fn handle(_: *IDBRequest) void {
            called.* = true;
        }
    };
    Handler.called = &handler_called;
    request.onsuccess = Handler.handle;

    const result = fireSuccessEvent(&request);

    try std.testing.expect(!result.listeners_threw);
    try std.testing.expect(!result.canceled);
    try std.testing.expect(handler_called);
}

test "fireErrorEvent - without transaction" {
    const allocator = std.testing.allocator;

    var request = IDBRequest.init(allocator);
    defer request.deinit();
    request.setError(IDBError.NotFoundError);

    var handler_called = false;
    const Handler = struct {
        var called: *bool = undefined;
        fn handle(_: *IDBRequest) void {
            called.* = true;
        }
    };
    Handler.called = &handler_called;
    request.onerror = Handler.handle;

    const result = fireErrorEvent(&request);

    try std.testing.expect(!result.listeners_threw);
    try std.testing.expect(handler_called);
}

test "fireVersionChangeEvent - upgradeneeded" {
    const allocator = std.testing.allocator;

    var request = IDBOpenDBRequest.init(allocator);
    defer request.deinit();

    var handler_called = false;
    const Handler = struct {
        var called: *bool = undefined;
        fn handle(_: *IDBOpenDBRequest) void {
            called.* = true;
        }
    };
    Handler.called = &handler_called;
    request.onupgradeneeded = Handler.handle;

    const result = fireUpgradeneededEvent(&request, 1, 2);

    try std.testing.expect(!result.listeners_threw);
    try std.testing.expect(handler_called);
}

test "fireVersionChangeEvent - blocked" {
    const allocator = std.testing.allocator;

    var request = IDBOpenDBRequest.init(allocator);
    defer request.deinit();

    var handler_called = false;
    const Handler = struct {
        var called: *bool = undefined;
        fn handle(_: *IDBOpenDBRequest) void {
            called.* = true;
        }
    };
    Handler.called = &handler_called;
    request.onblocked = Handler.handle;

    const result = fireBlockedEvent(&request, 1, 2);

    try std.testing.expect(!result.listeners_threw);
    try std.testing.expect(handler_called);
}
