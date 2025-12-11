//! Platform Push Backend Abstraction
//!
//! Spec: https://w3c.github.io/push-api/
//! Push API
//!
//! Provides a pluggable interface for push notification operations, allowing
//! service workers to receive push messages from a push service.
//!
//! The push backend is responsible for:
//! - Managing push subscriptions
//! - Handling push message delivery
//! - Managing encryption keys (VAPID, P-256)
//!
//! ## Usage
//!
//! ```zig
//! const push_backend = @import("platform/push_backend.zig");
//!
//! // Create a stub backend for testing
//! const stub = try StubPushBackend.init(allocator);
//! defer stub.deinit();
//!
//! // Get push interface
//! const push = stub.backend();
//!
//! // Subscribe to push notifications
//! const options = PushSubscriptionOptions{
//!     .user_visible_only = true,
//!     .application_server_key = vapid_key,
//! };
//! const subscription = try push.subscribe(allocator, options);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Push permission state
/// Spec: https://w3c.github.io/push-api/#dom-pushpermissionstate
pub const PushPermissionState = enum {
    /// Permission has been granted
    granted,
    /// Permission has been denied
    denied,
    /// Permission has not been requested yet (prompt will be shown)
    prompt,
};

/// Push encryption key name
/// Spec: https://w3c.github.io/push-api/#dom-pushencryptionkeyname
pub const PushEncryptionKeyName = enum {
    /// P-256 Diffie-Hellman public key
    p256dh,
    /// Authentication secret
    auth,
};

/// Result of a push operation
pub const PushResult = enum {
    success,
    permission_denied,
    not_supported,
    invalid_state,
    network_error,
    abort_error,
    error_unknown,
};

/// Push subscription options
/// Spec: https://w3c.github.io/push-api/#dom-pushsubscriptionoptionsinit
pub const PushSubscriptionOptions = struct {
    /// Indicates that the push subscription will only be used for messages
    /// whose effect is made visible to the user
    user_visible_only: bool = false,

    /// A Base64-encoded DOMString or ArrayBuffer containing an ECDSA P-256
    /// public key that the push server will use to authenticate your application server
    application_server_key: ?[]const u8 = null,
};

/// Push subscription keys
/// Contains the encryption keys needed to decrypt push messages
pub const PushSubscriptionKeys = struct {
    /// P-256 ECDH public key for message encryption (Base64 URL-encoded)
    p256dh: []const u8,
    /// Authentication secret (Base64 URL-encoded)
    auth: []const u8,
    allocator: Allocator,

    pub fn deinit(self: *PushSubscriptionKeys) void {
        self.allocator.free(self.p256dh);
        self.allocator.free(self.auth);
    }

    pub fn clone(self: PushSubscriptionKeys, allocator: Allocator) !PushSubscriptionKeys {
        return PushSubscriptionKeys{
            .p256dh = try allocator.dupe(u8, self.p256dh),
            .auth = try allocator.dupe(u8, self.auth),
            .allocator = allocator,
        };
    }
};

/// Push subscription
/// Spec: https://w3c.github.io/push-api/#dom-pushsubscription
pub const PushSubscription = struct {
    /// The push subscription's endpoint URL
    endpoint: []const u8,

    /// The subscription expiration time, if any (milliseconds since epoch)
    expiration_time: ?i64,

    /// The encryption keys
    keys: PushSubscriptionKeys,

    /// Options used to create this subscription
    options: PushSubscriptionOptions,

    /// Allocator used for this subscription
    allocator: Allocator,

    /// Application server key (owned copy)
    application_server_key_owned: ?[]const u8,

    pub fn init(
        allocator: Allocator,
        endpoint: []const u8,
        keys: PushSubscriptionKeys,
        options: PushSubscriptionOptions,
        expiration_time: ?i64,
    ) !*PushSubscription {
        const self = try allocator.create(PushSubscription);
        errdefer allocator.destroy(self);

        self.* = PushSubscription{
            .endpoint = try allocator.dupe(u8, endpoint),
            .expiration_time = expiration_time,
            .keys = try keys.clone(allocator),
            .options = .{
                .user_visible_only = options.user_visible_only,
                .application_server_key = null,
            },
            .allocator = allocator,
            .application_server_key_owned = null,
        };

        // Clone application server key if provided
        if (options.application_server_key) |key| {
            self.application_server_key_owned = try allocator.dupe(u8, key);
            self.options.application_server_key = self.application_server_key_owned;
        }

        return self;
    }

    pub fn deinit(self: *PushSubscription) void {
        self.allocator.free(self.endpoint);
        self.keys.deinit();
        if (self.application_server_key_owned) |key| {
            self.allocator.free(key);
        }
        self.allocator.destroy(self);
    }

    /// Get a key by name
    /// Spec: https://w3c.github.io/push-api/#dom-pushsubscription-getkey
    pub fn getKey(self: *const PushSubscription, name: PushEncryptionKeyName) []const u8 {
        return switch (name) {
            .p256dh => self.keys.p256dh,
            .auth => self.keys.auth,
        };
    }

    /// Serialize to JSON
    /// Spec: https://w3c.github.io/push-api/#dom-pushsubscription-tojson
    pub fn toJson(self: *const PushSubscription, allocator: Allocator) ![]const u8 {
        var buffer: std.ArrayListUnmanaged(u8) = .empty;
        errdefer buffer.deinit(allocator);

        try buffer.appendSlice(allocator, "{\"endpoint\":\"");
        try buffer.appendSlice(allocator, self.endpoint);
        try buffer.appendSlice(allocator, "\",\"expirationTime\":");

        if (self.expiration_time) |exp| {
            var num_buf: [32]u8 = undefined;
            const num_str = std.fmt.bufPrint(&num_buf, "{d}", .{exp}) catch unreachable;
            try buffer.appendSlice(allocator, num_str);
        } else {
            try buffer.appendSlice(allocator, "null");
        }

        try buffer.appendSlice(allocator, ",\"keys\":{\"p256dh\":\"");
        try buffer.appendSlice(allocator, self.keys.p256dh);
        try buffer.appendSlice(allocator, "\",\"auth\":\"");
        try buffer.appendSlice(allocator, self.keys.auth);
        try buffer.appendSlice(allocator, "\"}}");

        return buffer.toOwnedSlice(allocator);
    }
};

/// Push message data
/// Represents the payload of a push message
pub const PushMessageData = struct {
    /// Raw bytes of the push message
    data: []const u8,
    allocator: Allocator,

    pub fn init(allocator: Allocator, data: []const u8) !*PushMessageData {
        const self = try allocator.create(PushMessageData);
        self.* = PushMessageData{
            .data = try allocator.dupe(u8, data),
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *PushMessageData) void {
        self.allocator.free(self.data);
        self.allocator.destroy(self);
    }

    /// Get data as ArrayBuffer (raw bytes)
    pub fn arrayBuffer(self: *const PushMessageData) []const u8 {
        return self.data;
    }

    /// Get data as text (UTF-8 string)
    pub fn text(self: *const PushMessageData) []const u8 {
        return self.data;
    }

    /// Get data as JSON (returns raw bytes, caller parses)
    pub fn json(self: *const PushMessageData) []const u8 {
        return self.data;
    }
};

/// Abstract push backend interface.
///
/// This uses a vtable pattern to allow different implementations
/// (real push service, mock push) to be swapped at runtime.
pub const PushBackend = struct {
    /// Implementation pointer.
    /// KEEP: VTable polymorphism - type erasure for pluggable backend implementations
    ptr: *anyopaque,

    /// Virtual function table
    vtable: *const VTable,

    pub const VTable = struct {
        // === Subscription Management ===

        /// Subscribe to push notifications
        /// Spec: https://w3c.github.io/push-api/#dom-pushmanager-subscribe
        subscribe: *const fn (ptr: *anyopaque, allocator: Allocator, options: PushSubscriptionOptions) SubscribeResult,

        /// Get the current push subscription
        /// Spec: https://w3c.github.io/push-api/#dom-pushmanager-getsubscription
        getSubscription: *const fn (ptr: *anyopaque, allocator: Allocator) ?*PushSubscription,

        /// Unsubscribe from push notifications
        /// Spec: https://w3c.github.io/push-api/#dom-pushsubscription-unsubscribe
        unsubscribe: *const fn (ptr: *anyopaque, subscription: *PushSubscription) PushResult,

        // === Permission ===

        /// Get the current permission state
        /// Spec: https://w3c.github.io/push-api/#dom-pushmanager-permissionstate
        permissionState: *const fn (ptr: *anyopaque, options: PushSubscriptionOptions) PushPermissionState,

        // === Push Message Handling ===

        /// Called when a push message is received (for testing)
        /// In real implementation, this would be triggered by the OS/browser
        simulatePush: *const fn (ptr: *anyopaque, allocator: Allocator, data: []const u8) ?*PushMessageData,

        // === Lifecycle ===

        /// Free backend resources
        deinit: *const fn (ptr: *anyopaque) void,
    };

    pub const SubscribeResult = struct {
        subscription: ?*PushSubscription,
        result: PushResult,
    };

    // === Convenience Methods ===

    /// Subscribe to push notifications
    pub fn subscribe(self: PushBackend, allocator: Allocator, options: PushSubscriptionOptions) SubscribeResult {
        return self.vtable.subscribe(self.ptr, allocator, options);
    }

    /// Get the current subscription
    pub fn getSubscription(self: PushBackend, allocator: Allocator) ?*PushSubscription {
        return self.vtable.getSubscription(self.ptr, allocator);
    }

    /// Unsubscribe
    pub fn unsubscribe(self: PushBackend, subscription: *PushSubscription) PushResult {
        return self.vtable.unsubscribe(self.ptr, subscription);
    }

    /// Get permission state
    pub fn permissionState(self: PushBackend, options: PushSubscriptionOptions) PushPermissionState {
        return self.vtable.permissionState(self.ptr, options);
    }

    /// Simulate receiving a push message (for testing)
    pub fn simulatePush(self: PushBackend, allocator: Allocator, data: []const u8) ?*PushMessageData {
        return self.vtable.simulatePush(self.ptr, allocator, data);
    }

    /// Free resources
    pub fn deinit(self: PushBackend) void {
        self.vtable.deinit(self.ptr);
    }
};

/// Stub push backend for testing and development.
///
/// Provides an in-memory push subscription system that:
/// - Tracks permission state
/// - Stores subscriptions
/// - Generates fake encryption keys
/// - Useful for testing without a real push service
pub const StubPushBackend = struct {
    allocator: Allocator,

    /// Current permission state
    permission: PushPermissionState,

    /// Current subscription (if any)
    subscription: ?SubscriptionData,

    /// Counter for generating unique endpoints
    subscription_counter: u64,

    /// Callback for push events (for testing)
    on_push: ?*const fn (data: *PushMessageData) void,

    const SubscriptionData = struct {
        endpoint: []u8,
        p256dh: []u8,
        auth: []u8,
        user_visible_only: bool,
        application_server_key: ?[]u8,
        expiration_time: ?i64,
    };

    /// Initialize a new stub push backend
    pub fn init(allocator: Allocator) !*StubPushBackend {
        const self = try allocator.create(StubPushBackend);
        self.* = StubPushBackend{
            .allocator = allocator,
            .permission = .prompt,
            .subscription = null,
            .subscription_counter = 0,
            .on_push = null,
        };
        return self;
    }

    /// Create a PushBackend interface for this stub
    pub fn backend(self: *StubPushBackend) PushBackend {
        return PushBackend{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    /// Free the stub backend
    pub fn deinit(self: *StubPushBackend) void {
        if (self.subscription) |*sub| {
            self.allocator.free(sub.endpoint);
            self.allocator.free(sub.p256dh);
            self.allocator.free(sub.auth);
            if (sub.application_server_key) |key| {
                self.allocator.free(key);
            }
        }
        self.allocator.destroy(self);
    }

    /// Set permission state (for testing)
    pub fn setPermission(self: *StubPushBackend, permission: PushPermissionState) void {
        self.permission = permission;
    }

    /// Set push event callback (for testing)
    pub fn setOnPush(self: *StubPushBackend, callback: ?*const fn (data: *PushMessageData) void) void {
        self.on_push = callback;
    }

    const vtable = PushBackend.VTable{
        .subscribe = subscribeImpl,
        .getSubscription = getSubscriptionImpl,
        .unsubscribe = unsubscribeImpl,
        .permissionState = permissionStateImpl,
        .simulatePush = simulatePushImpl,
        .deinit = deinitImpl,
    };

    fn subscribeImpl(ptr: *anyopaque, allocator: Allocator, options: PushSubscriptionOptions) PushBackend.SubscribeResult {
        const self: *StubPushBackend = @ptrCast(@alignCast(ptr));

        // Check permission
        if (self.permission == .denied) {
            return .{ .subscription = null, .result = .permission_denied };
        }

        // Auto-grant permission on subscribe attempt (simulating user clicking "Allow")
        if (self.permission == .prompt) {
            self.permission = .granted;
        }

        // Clean up existing subscription
        if (self.subscription) |*sub| {
            self.allocator.free(sub.endpoint);
            self.allocator.free(sub.p256dh);
            self.allocator.free(sub.auth);
            if (sub.application_server_key) |key| {
                self.allocator.free(key);
            }
            self.subscription = null;
        }

        // Generate fake endpoint
        self.subscription_counter += 1;
        var endpoint_buf: [128]u8 = undefined;
        const endpoint_str = std.fmt.bufPrint(&endpoint_buf, "https://push.example.com/send/{d}", .{self.subscription_counter}) catch {
            return .{ .subscription = null, .result = .error_unknown };
        };
        const endpoint = self.allocator.dupe(u8, endpoint_str) catch {
            return .{ .subscription = null, .result = .error_unknown };
        };

        // Generate fake keys (Base64 URL-encoded)
        const p256dh = self.allocator.dupe(u8, "BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTpQtUbVlUls0VJXg7A8u-Ts1XbjhazAkj7I99e8QcYP7DkA") catch {
            self.allocator.free(endpoint);
            return .{ .subscription = null, .result = .error_unknown };
        };
        const auth = self.allocator.dupe(u8, "tBHItJI5svbpez7KI4CCXg") catch {
            self.allocator.free(endpoint);
            self.allocator.free(p256dh);
            return .{ .subscription = null, .result = .error_unknown };
        };

        // Clone application server key if provided
        var app_key: ?[]u8 = null;
        if (options.application_server_key) |key| {
            app_key = self.allocator.dupe(u8, key) catch {
                self.allocator.free(endpoint);
                self.allocator.free(p256dh);
                self.allocator.free(auth);
                return .{ .subscription = null, .result = .error_unknown };
            };
        }

        // Store subscription data
        self.subscription = SubscriptionData{
            .endpoint = endpoint,
            .p256dh = p256dh,
            .auth = auth,
            .user_visible_only = options.user_visible_only,
            .application_server_key = app_key,
            .expiration_time = null,
        };

        // Create subscription object for caller
        const keys = PushSubscriptionKeys{
            .p256dh = p256dh,
            .auth = auth,
            .allocator = allocator,
        };

        const subscription = PushSubscription.init(
            allocator,
            endpoint,
            keys,
            options,
            null,
        ) catch {
            return .{ .subscription = null, .result = .error_unknown };
        };

        return .{ .subscription = subscription, .result = .success };
    }

    fn getSubscriptionImpl(ptr: *anyopaque, allocator: Allocator) ?*PushSubscription {
        const self: *StubPushBackend = @ptrCast(@alignCast(ptr));

        const sub = self.subscription orelse return null;

        const keys = PushSubscriptionKeys{
            .p256dh = sub.p256dh,
            .auth = sub.auth,
            .allocator = allocator,
        };

        const options = PushSubscriptionOptions{
            .user_visible_only = sub.user_visible_only,
            .application_server_key = sub.application_server_key,
        };

        return PushSubscription.init(
            allocator,
            sub.endpoint,
            keys,
            options,
            sub.expiration_time,
        ) catch null;
    }

    fn unsubscribeImpl(ptr: *anyopaque, subscription: *PushSubscription) PushResult {
        const self: *StubPushBackend = @ptrCast(@alignCast(ptr));

        // Check if this subscription matches our stored one
        if (self.subscription) |*sub| {
            if (std.mem.eql(u8, sub.endpoint, subscription.endpoint)) {
                self.allocator.free(sub.endpoint);
                self.allocator.free(sub.p256dh);
                self.allocator.free(sub.auth);
                if (sub.application_server_key) |key| {
                    self.allocator.free(key);
                }
                self.subscription = null;
                return .success;
            }
        }

        return .invalid_state;
    }

    fn permissionStateImpl(ptr: *anyopaque, _: PushSubscriptionOptions) PushPermissionState {
        const self: *StubPushBackend = @ptrCast(@alignCast(ptr));
        return self.permission;
    }

    fn simulatePushImpl(ptr: *anyopaque, allocator: Allocator, data: []const u8) ?*PushMessageData {
        const self: *StubPushBackend = @ptrCast(@alignCast(ptr));

        // Must have an active subscription
        if (self.subscription == null) return null;

        // Create push message data
        const msg = PushMessageData.init(allocator, data) catch return null;

        // Trigger callback if set
        if (self.on_push) |callback| {
            callback(msg);
        }

        return msg;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *StubPushBackend = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

/// Permission-denied push backend.
///
/// A push backend that always denies permission.
/// Useful for testing permission error handling.
pub const DeniedPushBackend = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) !*DeniedPushBackend {
        const self = try allocator.create(DeniedPushBackend);
        self.* = DeniedPushBackend{
            .allocator = allocator,
        };
        return self;
    }

    pub fn backend(self: *DeniedPushBackend) PushBackend {
        return PushBackend{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    pub fn deinit(self: *DeniedPushBackend) void {
        self.allocator.destroy(self);
    }

    const vtable = PushBackend.VTable{
        .subscribe = subscribeImpl,
        .getSubscription = getSubscriptionImpl,
        .unsubscribe = unsubscribeImpl,
        .permissionState = permissionStateImpl,
        .simulatePush = simulatePushImpl,
        .deinit = deinitImpl,
    };

    fn subscribeImpl(_: *anyopaque, _: Allocator, _: PushSubscriptionOptions) PushBackend.SubscribeResult {
        return .{ .subscription = null, .result = .permission_denied };
    }

    fn getSubscriptionImpl(_: *anyopaque, _: Allocator) ?*PushSubscription {
        return null;
    }

    fn unsubscribeImpl(_: *anyopaque, _: *PushSubscription) PushResult {
        return .permission_denied;
    }

    fn permissionStateImpl(_: *anyopaque, _: PushSubscriptionOptions) PushPermissionState {
        return .denied;
    }

    fn simulatePushImpl(_: *anyopaque, _: Allocator, _: []const u8) ?*PushMessageData {
        return null;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *DeniedPushBackend = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "StubPushBackend - subscribe creates subscription" {
    const allocator = std.testing.allocator;

    const stub = try StubPushBackend.init(allocator);
    const push = stub.backend();
    defer push.deinit();

    const options = PushSubscriptionOptions{
        .user_visible_only = true,
        .application_server_key = "BEl62iUYgUivxIkv69yViEuiBIa-Ib9-SkvMeAtA3LFgDzkrxZJjSgSnfckjBJuBkr3qBUYIHBQFLXYp5Nksh8U",
    };

    const result = push.subscribe(allocator, options);
    try std.testing.expectEqual(PushResult.success, result.result);
    try std.testing.expect(result.subscription != null);

    const subscription = result.subscription.?;
    defer subscription.deinit();

    // Check endpoint
    try std.testing.expect(std.mem.startsWith(u8, subscription.endpoint, "https://push.example.com/send/"));

    // Check keys exist
    try std.testing.expect(subscription.keys.p256dh.len > 0);
    try std.testing.expect(subscription.keys.auth.len > 0);

    // Check options preserved
    try std.testing.expect(subscription.options.user_visible_only);
}

test "StubPushBackend - getSubscription returns existing subscription" {
    const allocator = std.testing.allocator;

    const stub = try StubPushBackend.init(allocator);
    const push = stub.backend();
    defer push.deinit();

    // No subscription initially
    try std.testing.expectEqual(@as(?*PushSubscription, null), push.getSubscription(allocator));

    // Subscribe
    const result = push.subscribe(allocator, .{});
    try std.testing.expectEqual(PushResult.success, result.result);
    result.subscription.?.deinit();

    // Now should have subscription
    const sub = push.getSubscription(allocator);
    try std.testing.expect(sub != null);
    sub.?.deinit();
}

test "StubPushBackend - unsubscribe removes subscription" {
    const allocator = std.testing.allocator;

    const stub = try StubPushBackend.init(allocator);
    const push = stub.backend();
    defer push.deinit();

    // Subscribe
    const result = push.subscribe(allocator, .{});
    const subscription = result.subscription.?;
    defer subscription.deinit();

    // Unsubscribe
    try std.testing.expectEqual(PushResult.success, push.unsubscribe(subscription));

    // No subscription now
    try std.testing.expectEqual(@as(?*PushSubscription, null), push.getSubscription(allocator));
}

test "StubPushBackend - permission state" {
    const allocator = std.testing.allocator;

    const stub = try StubPushBackend.init(allocator);
    const push = stub.backend();
    defer push.deinit();

    // Initially prompt
    try std.testing.expectEqual(PushPermissionState.prompt, push.permissionState(.{}));

    // After subscribe, should be granted
    const result = push.subscribe(allocator, .{});
    result.subscription.?.deinit();
    try std.testing.expectEqual(PushPermissionState.granted, push.permissionState(.{}));
}

test "StubPushBackend - denied permission blocks subscribe" {
    const allocator = std.testing.allocator;

    const stub = try StubPushBackend.init(allocator);
    stub.setPermission(.denied);
    const push = stub.backend();
    defer push.deinit();

    const result = push.subscribe(allocator, .{});
    try std.testing.expectEqual(PushResult.permission_denied, result.result);
    try std.testing.expectEqual(@as(?*PushSubscription, null), result.subscription);
}

test "StubPushBackend - simulate push message" {
    const allocator = std.testing.allocator;

    const stub = try StubPushBackend.init(allocator);
    const push = stub.backend();
    defer push.deinit();

    // Must subscribe first
    const result = push.subscribe(allocator, .{});
    result.subscription.?.deinit();

    // Simulate push
    const msg = push.simulatePush(allocator, "{\"title\":\"Test\",\"body\":\"Hello\"}");
    try std.testing.expect(msg != null);
    defer msg.?.deinit();

    try std.testing.expectEqualStrings("{\"title\":\"Test\",\"body\":\"Hello\"}", msg.?.text());
}

test "StubPushBackend - simulate push without subscription fails" {
    const allocator = std.testing.allocator;

    const stub = try StubPushBackend.init(allocator);
    const push = stub.backend();
    defer push.deinit();

    // No subscription - should fail
    try std.testing.expectEqual(@as(?*PushMessageData, null), push.simulatePush(allocator, "test"));
}

test "DeniedPushBackend - all operations denied" {
    const allocator = std.testing.allocator;

    const denied = try DeniedPushBackend.init(allocator);
    const push = denied.backend();
    defer push.deinit();

    // Permission denied
    try std.testing.expectEqual(PushPermissionState.denied, push.permissionState(.{}));

    // Subscribe denied
    const result = push.subscribe(allocator, .{});
    try std.testing.expectEqual(PushResult.permission_denied, result.result);

    // No subscription
    try std.testing.expectEqual(@as(?*PushSubscription, null), push.getSubscription(allocator));
}

test "PushSubscription - getKey" {
    const allocator = std.testing.allocator;

    const stub = try StubPushBackend.init(allocator);
    const push = stub.backend();
    defer push.deinit();

    const result = push.subscribe(allocator, .{});
    const subscription = result.subscription.?;
    defer subscription.deinit();

    // Get keys by name
    const p256dh = subscription.getKey(.p256dh);
    const auth = subscription.getKey(.auth);

    try std.testing.expect(p256dh.len > 0);
    try std.testing.expect(auth.len > 0);
    try std.testing.expectEqualStrings(subscription.keys.p256dh, p256dh);
    try std.testing.expectEqualStrings(subscription.keys.auth, auth);
}

test "PushSubscription - toJson" {
    const allocator = std.testing.allocator;

    const stub = try StubPushBackend.init(allocator);
    const push = stub.backend();
    defer push.deinit();

    const result = push.subscribe(allocator, .{});
    const subscription = result.subscription.?;
    defer subscription.deinit();

    const json = try subscription.toJson(allocator);
    defer allocator.free(json);

    // Verify JSON structure
    try std.testing.expect(std.mem.indexOf(u8, json, "\"endpoint\":\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"expirationTime\":null") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"keys\":{") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"p256dh\":\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"auth\":\"") != null);
}

test "PushMessageData - data access methods" {
    const allocator = std.testing.allocator;

    const data = try PushMessageData.init(allocator, "test message");
    defer data.deinit();

    try std.testing.expectEqualStrings("test message", data.arrayBuffer());
    try std.testing.expectEqualStrings("test message", data.text());
    try std.testing.expectEqualStrings("test message", data.json());
}
