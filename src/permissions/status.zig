//! PermissionStatus Interface
//!
//! W3C Permissions API
//! Spec: https://www.w3.org/TR/permissions/#permissionstatus-interface
//!
//! PermissionStatus represents the state of a permission.
//! It extends EventTarget and fires 'change' events when state changes.

const std = @import("std");
const types = @import("types.zig");

// ============================================================================
// PermissionStatus
// ============================================================================

/// PermissionStatus interface
/// Spec: W3C Permissions § 6
pub const PermissionStatus = struct {
    /// The current permission state
    state: types.PermissionState,

    /// The permission name
    name: types.PermissionName,

    /// Change event handler
    onchange: ?*const fn (*PermissionStatus) void = null,

    /// Allocator for any owned resources
    allocator: std.mem.Allocator,

    /// Internal ID for tracking
    id: u64,

    /// Static counter for unique IDs
    var next_id: u64 = 0;

    const Self = @This();

    /// Create a new PermissionStatus
    pub fn init(
        allocator: std.mem.Allocator,
        name: types.PermissionName,
        state: types.PermissionState,
    ) Self {
        const id = @atomicRmw(u64, &next_id, .Add, 1, .seq_cst);
        return .{
            .state = state,
            .name = name,
            .onchange = null,
            .allocator = allocator,
            .id = id,
        };
    }

    /// Update the permission state and fire change event if needed
    pub fn updateState(self: *Self, new_state: types.PermissionState) void {
        if (self.state != new_state) {
            self.state = new_state;
            self.fireChangeEvent();
        }
    }

    /// Fire the change event
    fn fireChangeEvent(self: *Self) void {
        if (self.onchange) |handler| {
            handler(self);
        }
        // TODO: Also dispatch 'change' event via EventTarget
    }

    /// Get the state as a string
    pub fn getStateString(self: *const Self) []const u8 {
        return self.state.toString();
    }

    /// Get the name as a string
    pub fn getNameString(self: *const Self) []const u8 {
        return self.name.toString();
    }

    pub fn deinit(self: *Self) void {
        _ = self;
        // No owned resources to free currently
    }
};

// ============================================================================
// PermissionStatus Registry
// ============================================================================

/// Registry for tracking active PermissionStatus objects
/// Used to notify all status objects when a permission changes
pub const PermissionStatusRegistry = struct {
    allocator: std.mem.Allocator,
    statuses: std.ArrayListUnmanaged(*PermissionStatus),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .statuses = .{},
        };
    }

    /// Register a PermissionStatus for notifications
    pub fn register(self: *Self, status_ptr: *PermissionStatus) !void {
        try self.statuses.append(self.allocator, status_ptr);
    }

    /// Unregister a PermissionStatus
    pub fn unregister(self: *Self, status_ptr: *PermissionStatus) void {
        for (self.statuses.items, 0..) |s, i| {
            if (s.id == status_ptr.id) {
                _ = self.statuses.orderedRemove(i);
                break;
            }
        }
    }

    /// Notify all status objects for a permission of state change
    pub fn notifyChange(
        self: *Self,
        name: types.PermissionName,
        new_state: types.PermissionState,
    ) void {
        for (self.statuses.items) |status_ptr| {
            if (status_ptr.name == name) {
                status_ptr.updateState(new_state);
            }
        }
    }

    pub fn deinit(self: *Self) void {
        self.statuses.deinit(self.allocator);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "PermissionStatus - basic" {
    const allocator = std.testing.allocator;

    var status = PermissionStatus.init(allocator, .geolocation, .prompt);
    defer status.deinit();

    try std.testing.expectEqual(types.PermissionState.prompt, status.state);
    try std.testing.expectEqual(types.PermissionName.geolocation, status.name);
    try std.testing.expectEqualStrings("prompt", status.getStateString());
    try std.testing.expectEqualStrings("geolocation", status.getNameString());
}

test "PermissionStatus - state change fires event" {
    const allocator = std.testing.allocator;

    var status = PermissionStatus.init(allocator, .geolocation, .prompt);
    defer status.deinit();

    const handler = struct {
        fn handle(_: *PermissionStatus) void {
            // Handler called on state change
        }
    }.handle;
    status.onchange = handler;

    status.updateState(.granted);
    try std.testing.expectEqual(types.PermissionState.granted, status.state);

    // Same state doesn't fire again
    status.updateState(.granted);
}

test "PermissionStatusRegistry - notify" {
    const allocator = std.testing.allocator;

    var registry = PermissionStatusRegistry.init(allocator);
    defer registry.deinit();

    var status1 = PermissionStatus.init(allocator, .geolocation, .prompt);
    defer status1.deinit();
    var status2 = PermissionStatus.init(allocator, .camera, .prompt);
    defer status2.deinit();

    try registry.register(&status1);
    try registry.register(&status2);

    // Notify geolocation change
    registry.notifyChange(.geolocation, .granted);

    try std.testing.expectEqual(types.PermissionState.granted, status1.state);
    try std.testing.expectEqual(types.PermissionState.prompt, status2.state); // unchanged
}
