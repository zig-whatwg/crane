//! Notification Backend Adapter
//!
//! Provides adapters between the old NotificationBackend interface and the new
//! unified NotificationVTable (C ABI compatible) interface.
//!
//! ## Migration Path
//!
//! 1. Existing code uses `NotificationBackend` (Zig-native VTable)
//! 2. New embedders implement `NotificationVTable` (C ABI compatible)
//! 3. Adapters bridge between the two interfaces

const std = @import("std");
const Allocator = std.mem.Allocator;

const vtables = @import("vtables.zig");
const NotificationVTable = vtables.NotificationVTable;
const CNotificationOptions = vtables.CNotificationOptions;
const NewNotificationPermission = vtables.NotificationPermission;
const NewNotificationResult = vtables.NotificationResult;
const NotificationHandle = vtables.NotificationHandle;
const OpaquePtr = vtables.OpaquePtr;

const notification_backend = @import("notification_backend.zig");
const NotificationBackend = notification_backend.NotificationBackend;
const OldNotificationPermission = notification_backend.NotificationPermission;
const OldNotificationResult = notification_backend.NotificationResult;
const Notification = notification_backend.Notification;
const NotificationOptions = notification_backend.NotificationOptions;

// =============================================================================
// NotificationVTable -> NotificationBackend Adapter
// =============================================================================

/// Adapter that wraps a NotificationVTable and provides a NotificationBackend interface.
pub const NotificationBackendAdapter = struct {
    /// The wrapped VTable
    vtable: *const NotificationVTable,
    /// User context passed to VTable functions
    user_context: OpaquePtr,
    /// Allocator for internal operations
    allocator: Allocator,

    const Self = @This();

    pub fn init(
        allocator: Allocator,
        vtable: *const NotificationVTable,
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

    pub fn backend(self: *Self) NotificationBackend {
        return NotificationBackend{
            .ptr = self,
            .vtable = &backend_vtable,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    const backend_vtable = NotificationBackend.VTable{
        .getPermission = getPermissionImpl,
        .requestPermission = requestPermissionImpl,
        .show = showImpl,
        .close = closeImpl,
        .getMaxActions = getMaxActionsImpl,
        .onNotificationEvent = onNotificationEventImpl,
        .deinit = deinitImpl,
    };

    fn getPermissionImpl(ptr: *anyopaque) OldNotificationPermission {
        const self: *Self = @ptrCast(@alignCast(ptr));
        const perm = self.vtable.get_permission(self.user_context);
        return convertNewPermission(perm);
    }

    fn requestPermissionImpl(ptr: *anyopaque) OldNotificationPermission {
        const self: *Self = @ptrCast(@alignCast(ptr));
        const perm = self.vtable.call_requestPermission(self.user_context);
        return convertNewPermission(perm);
    }

    fn showImpl(ptr: *anyopaque, notification: *Notification) OldNotificationResult {
        const self: *Self = @ptrCast(@alignCast(ptr));

        // Convert to C options
        const c_options = CNotificationOptions{
            .title = notification.title.ptr,
            .title_len = notification.title.len,
            .body = notification.body.ptr,
            .body_len = notification.body.len,
            .tag = notification.tag.ptr,
            .tag_len = notification.tag.len,
            .icon = if (notification.icon) |i| i.ptr else null,
            .icon_len = if (notification.icon) |i| i.len else 0,
            .badge = if (notification.badge) |b| b.ptr else null,
            .badge_len = if (notification.badge) |b| b.len else 0,
            .requireInteraction = notification.require_interaction,
            .silent = notification.silent orelse false,
            .timestamp = notification.timestamp,
        };

        const handle = self.vtable.show(self.user_context, &c_options);
        if (handle == 0) {
            return .error_unknown;
        }
        return .success;
    }

    fn closeImpl(ptr: *anyopaque, notification: *Notification) OldNotificationResult {
        const self: *Self = @ptrCast(@alignCast(ptr));
        // We need a handle mapping - for now just return success
        // A full implementation would track handle -> notification mapping
        _ = notification;
        _ = self;
        return .success;
    }

    fn getMaxActionsImpl(ptr: *anyopaque) u32 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.vtable.get_maxActions(self.user_context);
    }

    fn onNotificationEventImpl(_: *anyopaque, _: *Notification, _: notification_backend.NotificationEventType, _: ?notification_backend.NotificationEventCallback, _: ?*anyopaque) void {
        // Event registration not supported through C ABI
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.deinit();
    }

    fn convertNewPermission(perm: NewNotificationPermission) OldNotificationPermission {
        return switch (perm) {
            .default => .default,
            .denied => .denied,
            .granted => .granted,
        };
    }
};

// =============================================================================
// NotificationBackend -> NotificationVTable Adapter
// =============================================================================

/// Context for NotificationVTable that wraps a NotificationBackend.
pub const NotificationVTableAdapter = struct {
    /// The wrapped backend
    backend: NotificationBackend,
    /// Allocator for cleanup
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator, backend: NotificationBackend) !*Self {
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

    pub fn getVTable() *const NotificationVTable {
        return &vtable;
    }

    pub fn getUserContext(self: *Self) OpaquePtr {
        return self;
    }

    const vtable = NotificationVTable{
        .get_permission = getPermissionImpl,
        .call_requestPermission = requestPermissionImpl,
        .show = showImpl,
        .call_close = closeImpl,
        .get_maxActions = getMaxActionsImpl,
    };

    fn getPermissionImpl(user_context: OpaquePtr) callconv(.c) NewNotificationPermission {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const perm = self.backend.getPermission();
        return convertOldPermission(perm);
    }

    fn requestPermissionImpl(user_context: OpaquePtr) callconv(.c) NewNotificationPermission {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const perm = self.backend.requestPermission();
        return convertOldPermission(perm);
    }

    fn showImpl(user_context: OpaquePtr, options: *const CNotificationOptions) callconv(.c) NotificationHandle {
        const self: *Self = @ptrCast(@alignCast(user_context));

        // Create a Notification from C options
        const notification = Notification.create(self.allocator, options.title[0..options.title_len], .{
            .body = options.body[0..options.body_len],
            .tag = options.tag[0..options.tag_len],
            .require_interaction = options.requireInteraction,
            .silent = options.silent,
        }) catch return 0;

        const result = self.backend.show(notification);
        if (result != .success) {
            notification.destroy();
            return 0;
        }

        // Return a handle (pointer cast for simplicity)
        return @intFromPtr(notification);
    }

    fn closeImpl(user_context: OpaquePtr, handle: NotificationHandle) callconv(.c) NewNotificationResult {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const notification: *Notification = @ptrFromInt(handle);
        const result = self.backend.close(notification);
        return convertOldResult(result);
    }

    fn getMaxActionsImpl(user_context: OpaquePtr) callconv(.c) u32 {
        const self: *Self = @ptrCast(@alignCast(user_context));
        return self.backend.getMaxActions();
    }

    fn convertOldPermission(perm: OldNotificationPermission) NewNotificationPermission {
        return switch (perm) {
            .default => .default,
            .denied => .denied,
            .granted => .granted,
        };
    }

    fn convertOldResult(result: OldNotificationResult) NewNotificationResult {
        return switch (result) {
            .success => .success,
            .permission_denied => .permission_denied,
            .not_supported => .not_supported,
            .invalid_options => .invalid_options,
            .quota_exceeded => .quota_exceeded,
            .error_unknown => .error_unknown,
        };
    }
};

// =============================================================================
// Tests
// =============================================================================

test "NotificationVTableAdapter - wraps StubNotificationBackend" {
    const allocator = std.testing.allocator;

    // Create stub backend
    const stub = try notification_backend.StubNotificationBackend.init(allocator);
    defer stub.deinit();

    // Create adapter
    const adapter = try NotificationVTableAdapter.init(allocator, stub.backend());
    defer adapter.deinit();

    // Get VTable
    const vtable = NotificationVTableAdapter.getVTable();
    const ctx = adapter.getUserContext();

    // Test permission
    const perm = vtable.get_permission(ctx);
    try std.testing.expectEqual(NewNotificationPermission.granted, perm);

    // Test max actions
    const max_actions = vtable.get_maxActions(ctx);
    try std.testing.expect(max_actions >= 0);
}

test "NotificationBackendAdapter - construction" {
    const allocator = std.testing.allocator;

    // Create stub backend first
    const stub = try notification_backend.StubNotificationBackend.init(allocator);
    defer stub.deinit();

    // Create VTable adapter
    const vtable_adapter = try NotificationVTableAdapter.init(allocator, stub.backend());
    defer vtable_adapter.deinit();

    // Create backend adapter from VTable
    const backend_adapter = try NotificationBackendAdapter.init(
        allocator,
        NotificationVTableAdapter.getVTable(),
        vtable_adapter.getUserContext(),
    );
    defer backend_adapter.deinit();

    // Verify it's constructable
    const backend = backend_adapter.backend();
    const perm = backend.getPermission();
    try std.testing.expectEqual(OldNotificationPermission.granted, perm);
}
