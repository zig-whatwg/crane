//! ServiceWorker WebIDL Interface
//!
//! Client-side interface representing a service worker.
//! This wraps the internal ServiceWorker struct.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#serviceworker-interface
//!
//! WebIDL:
//! ```idl
//! [SecureContext, Exposed=(Window,Worker)]
//! interface ServiceWorker : EventTarget {
//!   readonly attribute USVString scriptURL;
//!   readonly attribute ServiceWorkerState state;
//!   undefined postMessage(any message, sequence<object> transfer);
//!   undefined postMessage(any message, optional StructuredSerializeOptions options = {});
//!
//!   attribute EventHandler onstatechange;
//! };
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

const types = @import("types.zig");
const ServiceWorkerState = types.ServiceWorkerState;
const EventHandler = types.EventHandler;
const StructuredSerializeOptions = types.StructuredSerializeOptions;

// Internal service worker struct
const internal = @import("../service_worker.zig");
const InternalServiceWorker = internal.ServiceWorker;

/// ServiceWorker WebIDL interface.
///
/// Represents a service worker from the client's perspective.
/// Extends EventTarget (via composition, since we don't have EventTarget impl yet).
///
/// Spec: https://w3c.github.io/ServiceWorker/#serviceworker-interface
pub const ServiceWorkerInterface = struct {
    allocator: Allocator,

    /// The underlying internal service worker.
    internal: *InternalServiceWorker,

    /// Whether this interface owns the internal service worker.
    /// If true, deinit will free the internal worker.
    owns_internal: bool = false,

    /// Event handler for state changes.
    onstatechange: EventHandler = null,

    /// Cached previous state for change detection.
    previous_state: ServiceWorkerState = .parsed,

    const Self = @This();

    // =========================================================================
    // Construction
    // =========================================================================

    /// Create a new ServiceWorker interface wrapping an internal worker.
    ///
    /// The internal worker is NOT owned by this interface - caller must manage its lifetime.
    pub fn init(allocator: Allocator, internal_worker: *InternalServiceWorker) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .internal = internal_worker,
            .owns_internal = false,
            .previous_state = internal_worker.state,
        };
        return self;
    }

    /// Create a new ServiceWorker interface that owns its internal worker.
    pub fn initOwned(allocator: Allocator, script_url: []const u8, worker_type: types.WorkerType) !*Self {
        const internal_worker = try InternalServiceWorker.init(allocator, script_url, worker_type);
        errdefer internal_worker.deinit();

        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .internal = internal_worker,
            .owns_internal = true,
            .previous_state = internal_worker.state,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        if (self.owns_internal) {
            self.internal.deinit();
        }
        self.allocator.destroy(self);
    }

    // =========================================================================
    // WebIDL Attributes
    // =========================================================================

    /// Get the script URL.
    ///
    /// Returns the service worker's script URL as a USVString.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#serviceworker-scripturl
    pub fn getScriptURL(self: *const Self) []const u8 {
        return self.internal.script_url;
    }

    /// Get the current state.
    ///
    /// Returns the service worker's state (parsed, installing, installed,
    /// activating, activated, or redundant).
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#serviceworker-state
    pub fn getState(self: *const Self) ServiceWorkerState {
        return self.internal.state;
    }

    /// Get the state as a string (for WebIDL compatibility).
    pub fn getStateString(self: *const Self) []const u8 {
        return types.serviceWorkerStateToString(self.internal.state);
    }

    // =========================================================================
    // WebIDL Methods
    // =========================================================================

    /// Post a message to the service worker.
    ///
    /// Sends a message to the service worker, which will receive it as a
    /// message event.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#serviceworker-postmessage
    ///
    /// Note: This is a simplified implementation. A full implementation would:
    /// 1. Serialize the message using structured clone
    /// 2. Transfer any transferable objects
    /// 3. Queue a task to dispatch a message event to the worker
    pub fn postMessage(
        self: *Self,
        message: *anyopaque,
        options: StructuredSerializeOptions,
    ) !void {
        _ = message;
        _ = options;

        // Check if the worker is in a valid state to receive messages
        const state = self.internal.state;
        if (state == .redundant) {
            return error.InvalidStateError;
        }

        // In a real implementation, this would:
        // 1. Serialize the message
        // 2. Queue a task to dispatch MessageEvent to the worker's global scope
        // For now, this is a stub that validates state.
    }

    /// Post a message with transfer list (overload).
    pub fn postMessageWithTransfer(
        self: *Self,
        message: *anyopaque,
        transfer: []const *anyopaque,
    ) !void {
        try self.postMessage(message, .{ .transfer = transfer });
    }

    // =========================================================================
    // Event Handling
    // =========================================================================

    /// Set the onstatechange event handler.
    pub fn setOnstatechange(self: *Self, handler: EventHandler) void {
        self.onstatechange = handler;
    }

    /// Get the onstatechange event handler.
    pub fn getOnstatechange(self: *const Self) EventHandler {
        return self.onstatechange;
    }

    /// Check for state changes and fire onstatechange if needed.
    ///
    /// This should be called after internal state transitions.
    pub fn checkStateChange(self: *Self) void {
        const current_state = self.internal.state;
        if (current_state != self.previous_state) {
            self.previous_state = current_state;
            if (self.onstatechange) |handler| {
                // In a real implementation, we'd create an Event object
                // and pass it to the handler.
                handler(@ptrCast(self));
            }
        }
    }

    // =========================================================================
    // Internal Access
    // =========================================================================

    /// Get the internal service worker (for algorithms).
    pub fn getInternal(self: *Self) *InternalServiceWorker {
        return self.internal;
    }

    /// Get the unique ID.
    pub fn getId(self: *const Self) u64 {
        return self.internal.id;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "ServiceWorkerInterface.init wrapping internal" {
    const allocator = std.testing.allocator;

    // Create internal worker first
    const internal_sw = try InternalServiceWorker.init(allocator, "https://example.com/sw.js", .module);
    defer internal_sw.deinit();

    // Wrap it
    const sw = try ServiceWorkerInterface.init(allocator, internal_sw);
    defer sw.deinit();

    try std.testing.expectEqualStrings("https://example.com/sw.js", sw.getScriptURL());
    try std.testing.expectEqual(ServiceWorkerState.parsed, sw.getState());
    try std.testing.expectEqualStrings("parsed", sw.getStateString());
}

test "ServiceWorkerInterface.initOwned" {
    const allocator = std.testing.allocator;

    const sw = try ServiceWorkerInterface.initOwned(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    try std.testing.expectEqualStrings("https://example.com/sw.js", sw.getScriptURL());
    try std.testing.expect(sw.owns_internal);
}

test "ServiceWorkerInterface.postMessage state check" {
    const allocator = std.testing.allocator;

    const sw = try ServiceWorkerInterface.initOwned(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    // Should succeed in parsed state
    var dummy: u8 = 0;
    try sw.postMessage(&dummy, .{});

    // Transition to redundant
    try sw.internal.transitionTo(.installing);
    try sw.internal.transitionTo(.redundant);

    // Should fail in redundant state
    const result = sw.postMessage(&dummy, .{});
    try std.testing.expectError(error.InvalidStateError, result);
}

test "ServiceWorkerInterface.onstatechange" {
    const allocator = std.testing.allocator;

    const sw = try ServiceWorkerInterface.initOwned(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    const handler = struct {
        fn handle(_: *anyopaque) void {
            // In real code, we'd update state here
            // but Zig doesn't have closures, so we just verify it compiles
        }
    }.handle;

    sw.setOnstatechange(handler);
    try std.testing.expect(sw.getOnstatechange() != null);
}

test "ServiceWorkerInterface.getId" {
    const allocator = std.testing.allocator;

    const sw1 = try ServiceWorkerInterface.initOwned(allocator, "https://example.com/sw1.js", .classic);
    defer sw1.deinit();

    const sw2 = try ServiceWorkerInterface.initOwned(allocator, "https://example.com/sw2.js", .classic);
    defer sw2.deinit();

    // IDs should be unique
    try std.testing.expect(sw1.getId() != sw2.getId());
}
