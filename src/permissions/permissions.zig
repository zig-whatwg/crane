//! Permissions Interface
//!
//! W3C Permissions API
//! Spec: https://www.w3.org/TR/permissions/#permissions-interface
//!
//! The Permissions interface provides methods for querying and
//! requesting permission states.

const std = @import("std");
const types = @import("types.zig");
const storage = @import("storage.zig");
const status = @import("status.zig");

// ============================================================================
// Permissions Interface
// ============================================================================

/// Permissions interface (navigator.permissions)
/// Spec: W3C Permissions § 7
pub const Permissions = struct {
    allocator: std.mem.Allocator,

    /// Permission storage
    permission_storage: *storage.PermissionStorage,

    /// Status registry for change notifications
    status_registry: status.PermissionStatusRegistry,

    /// Current origin (for permission isolation)
    origin: types.Origin,

    const Self = @This();

    /// Create a new Permissions object
    pub fn init(
        allocator: std.mem.Allocator,
        permission_storage: *storage.PermissionStorage,
        origin: types.Origin,
    ) Self {
        return .{
            .allocator = allocator,
            .permission_storage = permission_storage,
            .status_registry = status.PermissionStatusRegistry.init(allocator),
            .origin = origin,
        };
    }

    /// Query the current permission state
    /// Spec: W3C Permissions § 7.1
    ///
    /// Returns a PermissionStatus that reflects the current state
    /// and will be updated when the state changes.
    pub fn query(self: *Self, descriptor: types.PermissionDescriptor) !*status.PermissionStatus {
        // Get current state from storage
        const current_state = self.permission_storage.get(&self.origin, descriptor.name);

        // Create PermissionStatus
        const perm_status = try self.allocator.create(status.PermissionStatus);
        perm_status.* = status.PermissionStatus.init(self.allocator, descriptor.name, current_state);

        // Register for updates
        try self.status_registry.register(perm_status);

        return perm_status;
    }

    /// Request permission from the user
    /// Spec: W3C Permissions § 7.2
    ///
    /// This is implementation-defined - may show UI, may immediately return.
    /// For now, we return the current state without prompting.
    pub fn request(self: *Self, descriptor: types.PermissionDescriptor) !*status.PermissionStatus {
        // In a real implementation, this would:
        // 1. Check if permission is already granted/denied
        // 2. If prompt, show UI to ask user
        // 3. Store the user's decision
        // 4. Return the result

        // For now, just query current state
        return self.query(descriptor);
    }

    /// Revoke a permission
    /// Spec: W3C Permissions § 7.3 (deprecated but still supported)
    ///
    /// Resets the permission to 'prompt' state.
    pub fn revoke(self: *Self, descriptor: types.PermissionDescriptor) !*status.PermissionStatus {
        // Remove from storage (resets to prompt)
        self.permission_storage.remove(&self.origin, descriptor.name);

        // Notify all status objects
        self.status_registry.notifyChange(descriptor.name, .prompt);

        // Return new status
        return self.query(descriptor);
    }

    /// Set permission state (for testing/simulation)
    /// This is NOT part of the W3C spec - used for testing.
    pub fn setPermission(
        self: *Self,
        descriptor: types.PermissionDescriptor,
        state: types.PermissionState,
    ) !void {
        try self.permission_storage.set(&self.origin, descriptor.name, state);
        self.status_registry.notifyChange(descriptor.name, state);
    }

    /// Release a PermissionStatus (cleanup)
    pub fn releaseStatus(self: *Self, perm_status: *status.PermissionStatus) void {
        self.status_registry.unregister(perm_status);
        perm_status.deinit();
        self.allocator.destroy(perm_status);
    }

    pub fn deinit(self: *Self) void {
        self.status_registry.deinit();
    }
};

// ============================================================================
// Convenience Functions
// ============================================================================

/// Check if a permission is granted
pub fn isGranted(
    permissions: *Permissions,
    name: types.PermissionName,
) bool {
    const state = permissions.permission_storage.get(&permissions.origin, name);
    return state == .granted;
}

/// Check if a permission is denied
pub fn isDenied(
    permissions: *Permissions,
    name: types.PermissionName,
) bool {
    const state = permissions.permission_storage.get(&permissions.origin, name);
    return state == .denied;
}

/// Check if a permission needs to be requested
pub fn needsRequest(
    permissions: *Permissions,
    name: types.PermissionName,
) bool {
    const state = permissions.permission_storage.get(&permissions.origin, name);
    return state == .prompt;
}

// ============================================================================
// Tests
// ============================================================================

test "Permissions.query" {
    const allocator = std.testing.allocator;

    var perm_storage = storage.PermissionStorage.init(allocator);
    defer perm_storage.deinit();

    const origin = types.Origin.createBorrowed("https", "example.com", 443);

    var permissions = Permissions.init(allocator, &perm_storage, origin);
    defer permissions.deinit();

    // Query returns prompt by default
    const perm_status = try permissions.query(types.PermissionDescriptor.simple(.geolocation));
    defer permissions.releaseStatus(perm_status);

    try std.testing.expectEqual(types.PermissionState.prompt, perm_status.state);
    try std.testing.expectEqual(types.PermissionName.geolocation, perm_status.name);
}

test "Permissions.setPermission" {
    const allocator = std.testing.allocator;

    var perm_storage = storage.PermissionStorage.init(allocator);
    defer perm_storage.deinit();

    const origin = types.Origin.createBorrowed("https", "example.com", 443);

    var permissions = Permissions.init(allocator, &perm_storage, origin);
    defer permissions.deinit();

    // Set permission
    try permissions.setPermission(types.PermissionDescriptor.simple(.camera), .granted);

    // Query reflects the change
    const perm_status = try permissions.query(types.PermissionDescriptor.simple(.camera));
    defer permissions.releaseStatus(perm_status);

    try std.testing.expectEqual(types.PermissionState.granted, perm_status.state);
}

test "Permissions.revoke" {
    const allocator = std.testing.allocator;

    var perm_storage = storage.PermissionStorage.init(allocator);
    defer perm_storage.deinit();

    const origin = types.Origin.createBorrowed("https", "example.com", 443);

    var permissions = Permissions.init(allocator, &perm_storage, origin);
    defer permissions.deinit();

    // Grant permission
    try permissions.setPermission(types.PermissionDescriptor.simple(.microphone), .granted);

    // Revoke it
    const perm_status = try permissions.revoke(types.PermissionDescriptor.simple(.microphone));
    defer permissions.releaseStatus(perm_status);

    try std.testing.expectEqual(types.PermissionState.prompt, perm_status.state);
}

test "isGranted/isDenied/needsRequest" {
    const allocator = std.testing.allocator;

    var perm_storage = storage.PermissionStorage.init(allocator);
    defer perm_storage.deinit();

    const origin = types.Origin.createBorrowed("https", "example.com", 443);

    var permissions = Permissions.init(allocator, &perm_storage, origin);
    defer permissions.deinit();

    // Default is prompt
    try std.testing.expect(needsRequest(&permissions, .geolocation));
    try std.testing.expect(!isGranted(&permissions, .geolocation));
    try std.testing.expect(!isDenied(&permissions, .geolocation));

    // Grant
    try permissions.setPermission(types.PermissionDescriptor.simple(.geolocation), .granted);
    try std.testing.expect(isGranted(&permissions, .geolocation));
    try std.testing.expect(!needsRequest(&permissions, .geolocation));

    // Deny
    try permissions.setPermission(types.PermissionDescriptor.simple(.camera), .denied);
    try std.testing.expect(isDenied(&permissions, .camera));
}
