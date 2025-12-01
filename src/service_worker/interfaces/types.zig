//! Service Worker WebIDL Interface Types
//!
//! Supporting types for client-side Service Worker WebIDL interfaces.
//!
//! Spec: https://w3c.github.io/ServiceWorker/

const std = @import("std");
const Allocator = std.mem.Allocator;

// Re-export core types from parent module
pub const core_types = @import("../types.zig");
pub const ServiceWorkerState = core_types.ServiceWorkerState;
pub const WorkerType = core_types.WorkerType;
pub const UpdateViaCacheMode = core_types.UpdateViaCacheMode;
pub const FrameType = core_types.FrameType;
pub const ClientType = core_types.ClientType;
pub const VisibilityState = core_types.VisibilityState;
pub const RegistrationOptions = core_types.RegistrationOptions;
pub const NavigationPreloadState = core_types.NavigationPreloadState;
pub const ClientQueryOptions = core_types.ClientQueryOptions;

// =============================================================================
// Promise Types
// =============================================================================

/// A simple promise representation for async operations.
/// In a real implementation, this would integrate with the JavaScript engine.
pub fn Promise(comptime T: type) type {
    return struct {
        const Self = @This();

        state: State,
        value: ?T = null,
        err: ?anyerror = null,

        // Callbacks
        on_resolve: ?*const fn (T) void = null,
        on_reject: ?*const fn (anyerror) void = null,

        pub const State = enum {
            pending,
            fulfilled,
            rejected,
        };

        pub fn init() Self {
            return .{ .state = .pending };
        }

        pub fn resolve(self: *Self, value: T) void {
            if (self.state != .pending) return;
            self.state = .fulfilled;
            self.value = value;
            if (self.on_resolve) |callback| {
                callback(value);
            }
        }

        pub fn reject(self: *Self, err: anyerror) void {
            if (self.state != .pending) return;
            self.state = .rejected;
            self.err = err;
            if (self.on_reject) |callback| {
                callback(err);
            }
        }

        pub fn isPending(self: *const Self) bool {
            return self.state == .pending;
        }

        pub fn isFulfilled(self: *const Self) bool {
            return self.state == .fulfilled;
        }

        pub fn isRejected(self: *const Self) bool {
            return self.state == .rejected;
        }
    };
}

/// Void promise for operations that return undefined.
pub const VoidPromise = Promise(void);

/// Boolean promise for unregister().
pub const BoolPromise = Promise(bool);

// =============================================================================
// Event Handler Types
// =============================================================================

/// Event handler callback type.
pub const EventHandler = ?*const fn (*anyopaque) void;

/// Event handler with event parameter.
pub const EventHandlerWithEvent = ?*const fn (*anyopaque, *anyopaque) void;

// =============================================================================
// Structured Clone Options
// =============================================================================

/// Options for postMessage structured clone.
///
/// Spec: https://html.spec.whatwg.org/multipage/structured-data.html#structuredserializeoptions
pub const StructuredSerializeOptions = struct {
    /// Objects to transfer (move ownership).
    transfer: []const *anyopaque = &[_]*anyopaque{},
};

// =============================================================================
// Service Worker Update Via Cache (WebIDL enum)
// =============================================================================

/// ServiceWorkerUpdateViaCache WebIDL enum.
/// Maps to our internal UpdateViaCacheMode.
pub fn serviceWorkerUpdateViaCacheToString(mode: UpdateViaCacheMode) []const u8 {
    return switch (mode) {
        .imports => "imports",
        .all => "all",
        .none => "none",
    };
}

/// Parse ServiceWorkerUpdateViaCache from string.
pub fn serviceWorkerUpdateViaCacheFromString(s: []const u8) ?UpdateViaCacheMode {
    if (std.mem.eql(u8, s, "imports")) return .imports;
    if (std.mem.eql(u8, s, "all")) return .all;
    if (std.mem.eql(u8, s, "none")) return .none;
    return null;
}

// =============================================================================
// Service Worker State (WebIDL enum)
// =============================================================================

/// Convert ServiceWorkerState to WebIDL string.
pub fn serviceWorkerStateToString(state: ServiceWorkerState) []const u8 {
    return switch (state) {
        .parsed => "parsed",
        .installing => "installing",
        .installed => "installed",
        .activating => "activating",
        .activated => "activated",
        .redundant => "redundant",
    };
}

// =============================================================================
// Tests
// =============================================================================

test "Promise basic operations" {
    var promise = Promise(u32).init();
    try std.testing.expect(promise.isPending());

    promise.resolve(42);
    try std.testing.expect(promise.isFulfilled());
    try std.testing.expectEqual(@as(u32, 42), promise.value.?);
}

test "Promise rejection" {
    var promise = Promise(u32).init();
    promise.reject(error.TestError);

    try std.testing.expect(promise.isRejected());
    try std.testing.expectEqual(error.TestError, promise.err.?);
}

test "VoidPromise" {
    var promise = VoidPromise.init();
    promise.resolve({});
    try std.testing.expect(promise.isFulfilled());
}

test "serviceWorkerUpdateViaCacheToString" {
    try std.testing.expectEqualStrings("imports", serviceWorkerUpdateViaCacheToString(.imports));
    try std.testing.expectEqualStrings("all", serviceWorkerUpdateViaCacheToString(.all));
    try std.testing.expectEqualStrings("none", serviceWorkerUpdateViaCacheToString(.none));
}

test "serviceWorkerUpdateViaCacheFromString" {
    try std.testing.expectEqual(UpdateViaCacheMode.imports, serviceWorkerUpdateViaCacheFromString("imports").?);
    try std.testing.expectEqual(UpdateViaCacheMode.all, serviceWorkerUpdateViaCacheFromString("all").?);
    try std.testing.expectEqual(UpdateViaCacheMode.none, serviceWorkerUpdateViaCacheFromString("none").?);
    try std.testing.expect(serviceWorkerUpdateViaCacheFromString("invalid") == null);
}

test "serviceWorkerStateToString" {
    try std.testing.expectEqualStrings("parsed", serviceWorkerStateToString(.parsed));
    try std.testing.expectEqualStrings("installing", serviceWorkerStateToString(.installing));
    try std.testing.expectEqualStrings("activated", serviceWorkerStateToString(.activated));
}
