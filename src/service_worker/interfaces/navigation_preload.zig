//! NavigationPreloadManager WebIDL Interface
//!
//! Manages navigation preload for a service worker registration.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#navigation-preload-manager
//!
//! WebIDL:
//! ```idl
//! [SecureContext, Exposed=(Window,Worker)]
//! interface NavigationPreloadManager {
//!   [NewObject] Promise<undefined> enable();
//!   [NewObject] Promise<undefined> disable();
//!   [NewObject] Promise<undefined> setHeaderValue(ByteString value);
//!   [NewObject] Promise<NavigationPreloadState> getState();
//! };
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

const types = @import("types.zig");
const NavigationPreloadState = types.NavigationPreloadState;
const VoidPromise = types.VoidPromise;
const Promise = types.Promise;

// Internal registration struct
const registration_mod = @import("../registration.zig");
const InternalRegistration = registration_mod.Registration;

/// NavigationPreloadManager WebIDL interface.
///
/// Provides methods to manage navigation preload for a service worker registration.
///
/// Spec: https://w3c.github.io/ServiceWorker/#navigation-preload-manager
pub const NavigationPreloadManager = struct {
    allocator: Allocator,

    /// The underlying registration.
    registration: *InternalRegistration,

    const Self = @This();

    // =========================================================================
    // Construction
    // =========================================================================

    /// Create a NavigationPreloadManager for a registration.
    pub fn init(allocator: Allocator, registration: *InternalRegistration) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .registration = registration,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    // =========================================================================
    // WebIDL Methods
    // =========================================================================

    /// Enable navigation preload.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#navigation-preload-manager-enable
    ///
    /// Steps:
    /// 1. If this's service worker registration's active worker is null,
    ///    return a promise rejected with an "InvalidStateError" DOMException.
    /// 2. Set this's service worker registration's navigation preload enabled flag.
    /// 3. Return a promise resolved with undefined.
    pub fn enable(self: *Self) !VoidPromise {
        var promise = VoidPromise.init();

        // Step 1: Check for active worker
        if (self.registration.active_worker == null) {
            promise.reject(error.InvalidStateError);
            return promise;
        }

        // Step 2: Set the flag
        self.registration.enableNavigationPreload();

        // Step 3: Resolve
        promise.resolve({});
        return promise;
    }

    /// Disable navigation preload.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#navigation-preload-manager-disable
    ///
    /// Steps:
    /// 1. If this's service worker registration's active worker is null,
    ///    return a promise rejected with an "InvalidStateError" DOMException.
    /// 2. Unset this's service worker registration's navigation preload enabled flag.
    /// 3. Return a promise resolved with undefined.
    pub fn disable(self: *Self) !VoidPromise {
        var promise = VoidPromise.init();

        // Step 1: Check for active worker
        if (self.registration.active_worker == null) {
            promise.reject(error.InvalidStateError);
            return promise;
        }

        // Step 2: Clear the flag
        self.registration.disableNavigationPreload();

        // Step 3: Resolve
        promise.resolve({});
        return promise;
    }

    /// Set the header value.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#navigation-preload-manager-setheadervalue
    ///
    /// Steps:
    /// 1. If this's service worker registration's active worker is null,
    ///    return a promise rejected with an "InvalidStateError" DOMException.
    /// 2. If value is not a valid ByteString,
    ///    return a promise rejected with a TypeError.
    /// 3. Set this's service worker registration's navigation preload header value to value.
    /// 4. Return a promise resolved with undefined.
    pub fn setHeaderValue(self: *Self, value: []const u8) !VoidPromise {
        var promise = VoidPromise.init();

        // Step 1: Check for active worker
        if (self.registration.active_worker == null) {
            promise.reject(error.InvalidStateError);
            return promise;
        }

        // Step 2: Validate ByteString (all bytes must be 0x00-0xFF, which is always true for []const u8)
        // In practice, we might check for invalid HTTP header characters.
        for (value) |c| {
            // HTTP header values should not contain certain characters
            if (c == '\r' or c == '\n') {
                promise.reject(error.TypeError);
                return promise;
            }
        }

        // Step 3: Set the header value
        self.registration.setNavigationPreloadHeaderValue(value) catch {
            promise.reject(error.OutOfMemory);
            return promise;
        };

        // Step 4: Resolve
        promise.resolve({});
        return promise;
    }

    /// Get the navigation preload state.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#navigation-preload-manager-getstate
    ///
    /// Steps:
    /// 1. Return a promise resolved with a NavigationPreloadState whose
    ///    enabled is this's service worker registration's navigation preload enabled flag,
    ///    and whose headerValue is this's service worker registration's
    ///    navigation preload header value.
    pub fn getState(self: *Self) Promise(NavigationPreloadState) {
        var promise = Promise(NavigationPreloadState).init();
        promise.resolve(self.registration.getNavigationPreloadState());
        return promise;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "NavigationPreloadManager requires active worker" {
    const allocator = std.testing.allocator;

    // Create registration without active worker
    const reg = try InternalRegistration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const npm = try NavigationPreloadManager.init(allocator, reg);
    defer npm.deinit();

    // enable() should fail without active worker
    const enable_result = try npm.enable();
    try std.testing.expect(enable_result.isRejected());
    try std.testing.expectEqual(error.InvalidStateError, enable_result.err.?);

    // disable() should fail without active worker
    const disable_result = try npm.disable();
    try std.testing.expect(disable_result.isRejected());

    // setHeaderValue() should fail without active worker
    const header_result = try npm.setHeaderValue("custom-value");
    try std.testing.expect(header_result.isRejected());
}

test "NavigationPreloadManager with active worker" {
    const allocator = std.testing.allocator;

    // Create registration with active worker
    const reg = try InternalRegistration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const sw = @import("../service_worker.zig");
    const worker = try sw.ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer worker.deinit();

    reg.setActiveWorker(worker);

    const npm = try NavigationPreloadManager.init(allocator, reg);
    defer npm.deinit();

    // getState() returns current state
    const state1 = npm.getState();
    try std.testing.expect(state1.isFulfilled());
    try std.testing.expect(!state1.value.?.enabled);

    // enable() should succeed
    const enable_result = try npm.enable();
    try std.testing.expect(enable_result.isFulfilled());

    // State should be enabled
    const state2 = npm.getState();
    try std.testing.expect(state2.value.?.enabled);

    // setHeaderValue() should succeed
    const header_result = try npm.setHeaderValue("my-custom-header");
    try std.testing.expect(header_result.isFulfilled());

    // State should reflect new header
    const state3 = npm.getState();
    try std.testing.expectEqualStrings("my-custom-header", state3.value.?.header_value);

    // disable() should succeed
    const disable_result = try npm.disable();
    try std.testing.expect(disable_result.isFulfilled());

    // State should be disabled
    const state4 = npm.getState();
    try std.testing.expect(!state4.value.?.enabled);
}

test "NavigationPreloadManager setHeaderValue validation" {
    const allocator = std.testing.allocator;

    const reg = try InternalRegistration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const sw = @import("../service_worker.zig");
    const worker = try sw.ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer worker.deinit();

    reg.setActiveWorker(worker);

    const npm = try NavigationPreloadManager.init(allocator, reg);
    defer npm.deinit();

    // Invalid header with newline
    const result = try npm.setHeaderValue("invalid\nheader");
    try std.testing.expect(result.isRejected());
    try std.testing.expectEqual(error.TypeError, result.err.?);
}
