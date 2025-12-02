//! Permission Storage
//!
//! W3C Permissions API
//! Spec: https://www.w3.org/TR/permissions/
//!
//! This module provides persistence for permission states.
//! Permissions are stored per-origin.

const std = @import("std");
const types = @import("types.zig");

// ============================================================================
// Permission Key
// ============================================================================

/// Key for permission storage (origin + permission name)
pub const PermissionKey = struct {
    /// Serialized origin (e.g., "https://example.com:443")
    origin: []const u8,
    /// Permission name
    name: types.PermissionName,

    /// Check equality
    pub fn eql(a: PermissionKey, b: PermissionKey) bool {
        return std.mem.eql(u8, a.origin, b.origin) and a.name == b.name;
    }

    /// Hash for use in HashMap
    pub fn hash(key: PermissionKey) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(key.origin);
        hasher.update(&[_]u8{@intFromEnum(key.name)});
        return hasher.final();
    }
};

// ============================================================================
// Permission Storage
// ============================================================================

/// In-memory permission storage with optional persistence backend
pub const PermissionStorage = struct {
    allocator: std.mem.Allocator,

    /// In-memory cache of permissions
    cache: std.HashMap(PermissionKey, types.PermissionState, PermissionKeyContext, 80),

    /// Storage backend for persistence (optional)
    backend: ?*StorageBackend = null,

    const PermissionKeyContext = struct {
        pub fn hash(_: @This(), key: PermissionKey) u64 {
            return PermissionKey.hash(key);
        }

        pub fn eql(_: @This(), a: PermissionKey, b: PermissionKey) bool {
            return PermissionKey.eql(a, b);
        }
    };

    const Self = @This();

    /// Initialize storage
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .cache = std.HashMap(PermissionKey, types.PermissionState, PermissionKeyContext, 80).init(allocator),
            .backend = null,
        };
    }

    /// Initialize with persistence backend
    pub fn initWithBackend(allocator: std.mem.Allocator, backend: *StorageBackend) Self {
        var storage = init(allocator);
        storage.backend = backend;
        return storage;
    }

    /// Get permission state for origin and permission
    pub fn get(self: *Self, origin: *const types.Origin, name: types.PermissionName) types.PermissionState {
        // Create key
        const origin_str = origin.serialize(self.allocator) catch return .prompt;
        defer self.allocator.free(origin_str);

        const key = PermissionKey{
            .origin = origin_str,
            .name = name,
        };

        // Check cache first
        if (self.cache.get(key)) |state| {
            return state;
        }

        // Try backend
        if (self.backend) |backend| {
            if (backend.load(origin_str, name)) |state| {
                return state;
            }
        }

        // Default: prompt
        return .prompt;
    }

    /// Set permission state for origin and permission
    pub fn set(self: *Self, origin: *const types.Origin, name: types.PermissionName, state: types.PermissionState) !void {
        // Create key with owned origin string
        const origin_str = try origin.serialize(self.allocator);
        errdefer self.allocator.free(origin_str);

        const key = PermissionKey{
            .origin = origin_str,
            .name = name,
        };

        // Update cache
        try self.cache.put(key, state);

        // Persist to backend
        if (self.backend) |backend| {
            try backend.save(origin_str, name, state);
        }
    }

    /// Remove permission state (reset to prompt)
    pub fn remove(self: *Self, origin: *const types.Origin, name: types.PermissionName) void {
        const origin_str = origin.serialize(self.allocator) catch return;
        defer self.allocator.free(origin_str);

        const key = PermissionKey{
            .origin = origin_str,
            .name = name,
        };

        // Remove from cache
        if (self.cache.fetchRemove(key)) |entry| {
            self.allocator.free(entry.key.origin);
        }

        // Remove from backend
        if (self.backend) |backend| {
            backend.remove(origin_str, name);
        }
    }

    /// Clear all permissions for an origin
    pub fn clearOrigin(self: *Self, origin: *const types.Origin) void {
        const origin_str = origin.serialize(self.allocator) catch return;
        defer self.allocator.free(origin_str);

        // Remove matching entries from cache
        var to_remove: std.ArrayListUnmanaged(PermissionKey) = .{};
        defer to_remove.deinit(self.allocator);

        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            if (std.mem.eql(u8, entry.key_ptr.origin, origin_str)) {
                to_remove.append(self.allocator, entry.key_ptr.*) catch continue;
            }
        }

        for (to_remove.items) |key| {
            if (self.cache.fetchRemove(key)) |entry| {
                self.allocator.free(entry.key.origin);
            }
        }

        // Clear from backend
        if (self.backend) |backend| {
            backend.clearOrigin(origin_str);
        }
    }

    /// Clear all permissions
    pub fn clearAll(self: *Self) void {
        // Free all origin strings
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.origin);
        }
        self.cache.clearRetainingCapacity();

        // Clear backend
        if (self.backend) |backend| {
            backend.clearAll();
        }
    }

    pub fn deinit(self: *Self) void {
        // Free all origin strings
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.origin);
        }
        self.cache.deinit();
    }
};

// ============================================================================
// Storage Backend Interface
// ============================================================================

/// Interface for persistence backends
pub const StorageBackend = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        load: *const fn (ctx: *anyopaque, origin: []const u8, name: types.PermissionName) ?types.PermissionState,
        save: *const fn (ctx: *anyopaque, origin: []const u8, name: types.PermissionName, state: types.PermissionState) anyerror!void,
        remove: *const fn (ctx: *anyopaque, origin: []const u8, name: types.PermissionName) void,
        clearOrigin: *const fn (ctx: *anyopaque, origin: []const u8) void,
        clearAll: *const fn (ctx: *anyopaque) void,
    };

    pub fn load(self: *StorageBackend, origin: []const u8, name: types.PermissionName) ?types.PermissionState {
        return self.vtable.load(self.ptr, origin, name);
    }

    pub fn save(self: *StorageBackend, origin: []const u8, name: types.PermissionName, state: types.PermissionState) !void {
        return self.vtable.save(self.ptr, origin, name, state);
    }

    pub fn remove(self: *StorageBackend, origin: []const u8, name: types.PermissionName) void {
        self.vtable.remove(self.ptr, origin, name);
    }

    pub fn clearOrigin(self: *StorageBackend, origin: []const u8) void {
        self.vtable.clearOrigin(self.ptr, origin);
    }

    pub fn clearAll(self: *StorageBackend) void {
        self.vtable.clearAll(self.ptr);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "PermissionStorage - basic operations" {
    const allocator = std.testing.allocator;

    var storage = PermissionStorage.init(allocator);
    defer storage.deinit();

    var origin = types.Origin.createBorrowed("https", "example.com", 443);

    // Default is prompt
    try std.testing.expectEqual(types.PermissionState.prompt, storage.get(&origin, .geolocation));

    // Set and get
    try storage.set(&origin, .geolocation, .granted);
    try std.testing.expectEqual(types.PermissionState.granted, storage.get(&origin, .geolocation));

    // Different permission is still prompt
    try std.testing.expectEqual(types.PermissionState.prompt, storage.get(&origin, .camera));
}

test "PermissionStorage - origin isolation" {
    const allocator = std.testing.allocator;

    var storage = PermissionStorage.init(allocator);
    defer storage.deinit();

    var origin1 = types.Origin.createBorrowed("https", "example.com", 443);
    var origin2 = types.Origin.createBorrowed("https", "other.com", 443);

    try storage.set(&origin1, .geolocation, .granted);

    // origin1 has permission
    try std.testing.expectEqual(types.PermissionState.granted, storage.get(&origin1, .geolocation));

    // origin2 does not
    try std.testing.expectEqual(types.PermissionState.prompt, storage.get(&origin2, .geolocation));
}

test "PermissionStorage - remove" {
    const allocator = std.testing.allocator;

    var storage = PermissionStorage.init(allocator);
    defer storage.deinit();

    var origin = types.Origin.createBorrowed("https", "example.com", 443);

    try storage.set(&origin, .geolocation, .granted);
    try std.testing.expectEqual(types.PermissionState.granted, storage.get(&origin, .geolocation));

    storage.remove(&origin, .geolocation);
    try std.testing.expectEqual(types.PermissionState.prompt, storage.get(&origin, .geolocation));
}
