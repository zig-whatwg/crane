//! Push Backend Adapter
//!
//! Provides adapters between the old PushBackend interface and the new
//! unified PushVTable (C ABI compatible) interface.
//!
//! ## Migration Path
//!
//! 1. Existing code uses `PushBackend` (Zig-native VTable)
//! 2. New embedders implement `PushVTable` (C ABI compatible)
//! 3. Adapters bridge between the two interfaces

const std = @import("std");
const Allocator = std.mem.Allocator;

const vtables = @import("vtables.zig");
const PushVTable = vtables.PushVTable;
const PushSubscriptionHandle = vtables.PushSubscriptionHandle;
const OpaquePtr = vtables.OpaquePtr;

const push_backend = @import("push_backend.zig");
const PushBackend = push_backend.PushBackend;
const PushResult = push_backend.PushResult;
const PushSubscription = push_backend.PushSubscription;
const PushSubscriptionOptions = push_backend.PushSubscriptionOptions;

// =============================================================================
// PushVTable -> PushBackend Adapter
// =============================================================================

/// Adapter that wraps a PushVTable and provides a PushBackend interface.
pub const PushBackendAdapter = struct {
    /// The wrapped VTable
    vtable: *const PushVTable,
    /// User context passed to VTable functions
    user_context: OpaquePtr,
    /// Allocator for internal operations
    allocator: Allocator,

    const Self = @This();

    pub fn init(
        allocator: Allocator,
        vtable: *const PushVTable,
        user_context: OpaquePtr,
    ) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .vtable = vtable,
            .user_context = user_context,
            .allocator = allocator,
        };
        return self;
    }

    pub fn backend(self: *Self) PushBackend {
        return PushBackend{
            .ptr = self,
            .vtable = &backend_vtable,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    const backend_vtable = PushBackend.VTable{
        .subscribe = subscribeImpl,
        .unsubscribe = unsubscribeImpl,
        .getSubscription = getSubscriptionImpl,
        .permissionState = permissionStateImpl,
        .isSupported = isSupportedImpl,
        .deinit = deinitImpl,
    };

    fn subscribeImpl(ptr: *anyopaque, allocator: Allocator, options: PushSubscriptionOptions) ?*PushSubscription {
        const self: *Self = @ptrCast(@alignCast(ptr));
        const key = options.application_server_key orelse return null;

        const handle = self.vtable.call_subscribe(self.user_context, key.ptr, key.len);
        if (handle == 0) {
            return null;
        }

        // Create a minimal subscription - full implementation would get details from handle
        const subscription = allocator.create(PushSubscription) catch return null;
        subscription.* = PushSubscription{
            .endpoint = allocator.dupe(u8, "https://push.example.com/subscription") catch {
                allocator.destroy(subscription);
                return null;
            },
            .expiration_time = null,
            .keys = .{
                .p256dh = allocator.dupe(u8, "") catch {
                    allocator.destroy(subscription);
                    return null;
                },
                .auth = allocator.dupe(u8, "") catch {
                    allocator.destroy(subscription);
                    return null;
                },
                .allocator = allocator,
            },
            .options = options,
            .allocator = allocator,
        };

        return subscription;
    }

    fn unsubscribeImpl(ptr: *anyopaque, subscription: *PushSubscription) PushResult {
        const self: *Self = @ptrCast(@alignCast(ptr));
        // Use endpoint hash as handle for simplicity
        const handle: PushSubscriptionHandle = @intFromPtr(subscription);
        const success = self.vtable.call_unsubscribe(self.user_context, handle);
        return if (success) .success else .error_unknown;
    }

    fn getSubscriptionImpl(ptr: *anyopaque, allocator: Allocator) ?*PushSubscription {
        const self: *Self = @ptrCast(@alignCast(ptr));
        const handle = self.vtable.call_getSubscription(self.user_context);
        if (handle == 0) {
            return null;
        }

        // Create minimal subscription
        const subscription = allocator.create(PushSubscription) catch return null;
        subscription.* = PushSubscription{
            .endpoint = allocator.dupe(u8, "https://push.example.com/subscription") catch {
                allocator.destroy(subscription);
                return null;
            },
            .expiration_time = null,
            .keys = .{
                .p256dh = allocator.dupe(u8, "") catch {
                    allocator.destroy(subscription);
                    return null;
                },
                .auth = allocator.dupe(u8, "") catch {
                    allocator.destroy(subscription);
                    return null;
                },
                .allocator = allocator,
            },
            .options = .{},
            .allocator = allocator,
        };

        return subscription;
    }

    fn permissionStateImpl(_: *anyopaque) push_backend.PushPermissionState {
        // Not directly exposed in C VTable - assume granted if supported
        return .granted;
    }

    fn isSupportedImpl(ptr: *anyopaque) bool {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.vtable.isSupported(self.user_context);
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

// =============================================================================
// PushBackend -> PushVTable Adapter
// =============================================================================

/// Context for PushVTable that wraps a PushBackend.
pub const PushVTableAdapter = struct {
    /// The wrapped backend
    backend: PushBackend,
    /// Allocator for cleanup
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator, backend: PushBackend) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .backend = backend,
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    pub fn getVTable() *const PushVTable {
        return &vtable;
    }

    pub fn getUserContext(self: *Self) OpaquePtr {
        return self;
    }

    const vtable = PushVTable{
        .call_subscribe = subscribeImpl,
        .call_unsubscribe = unsubscribeImpl,
        .call_getSubscription = getSubscriptionImpl,
        .isSupported = isSupportedImpl,
    };

    fn subscribeImpl(user_context: OpaquePtr, key: [*]const u8, key_len: usize) callconv(.c) PushSubscriptionHandle {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const options = PushSubscriptionOptions{
            .user_visible_only = true,
            .application_server_key = key[0..key_len],
        };

        const subscription = self.backend.subscribe(self.allocator, options);
        if (subscription) |sub| {
            return @intFromPtr(sub);
        }
        return 0;
    }

    fn unsubscribeImpl(user_context: OpaquePtr, handle: PushSubscriptionHandle) callconv(.c) bool {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const subscription: *PushSubscription = @ptrFromInt(handle);
        const result = self.backend.unsubscribe(subscription);
        return result == .success;
    }

    fn getSubscriptionImpl(user_context: OpaquePtr) callconv(.c) PushSubscriptionHandle {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const subscription = self.backend.getSubscription(self.allocator);
        if (subscription) |sub| {
            return @intFromPtr(sub);
        }
        return 0;
    }

    fn isSupportedImpl(user_context: OpaquePtr) callconv(.c) bool {
        const self: *Self = @ptrCast(@alignCast(user_context));
        return self.backend.isSupported();
    }
};

// =============================================================================
// Tests
// =============================================================================

test "PushVTableAdapter - wraps StubPushBackend" {
    const allocator = std.testing.allocator;

    // Create stub backend
    const stub = try push_backend.StubPushBackend.init(allocator);
    defer stub.deinit();

    // Create adapter
    const adapter = try PushVTableAdapter.init(allocator, stub.backend());
    defer adapter.deinit();

    // Get VTable
    const vtable = PushVTableAdapter.getVTable();
    const ctx = adapter.getUserContext();

    // Test isSupported
    const supported = vtable.isSupported(ctx);
    try std.testing.expect(supported);
}

test "PushBackendAdapter - construction" {
    const allocator = std.testing.allocator;

    // Create stub backend first
    const stub = try push_backend.StubPushBackend.init(allocator);
    defer stub.deinit();

    // Create VTable adapter
    const vtable_adapter = try PushVTableAdapter.init(allocator, stub.backend());
    defer vtable_adapter.deinit();

    // Create backend adapter from VTable
    const backend_adapter = try PushBackendAdapter.init(
        allocator,
        PushVTableAdapter.getVTable(),
        vtable_adapter.getUserContext(),
    );
    defer backend_adapter.deinit();

    // Verify it's constructable
    const backend = backend_adapter.backend();
    const supported = backend.isSupported();
    try std.testing.expect(supported);
}
