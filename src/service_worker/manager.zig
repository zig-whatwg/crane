//! Service Worker Manager
//!
//! Browser-side service worker management logic.
//! This module has NO WebIDL dependencies and can be safely imported by Browser.
//!
//! The manager provides:
//! - Registration tracking via opaque handles
//! - Fetch interception coordination
//! - Lifecycle management hooks
//!
//! WebIDL-facing code remains in the main service_worker module.

const std = @import("std");
const common = @import("common.zig");

const RegistrationHandle = common.RegistrationHandle;
const ServiceWorkerHandle = common.ServiceWorkerHandle;
const RegistrationKey = common.RegistrationKey;
const ServiceWorkerState = common.ServiceWorkerState;

/// Service Worker Manager for browser-side coordination.
/// Tracks registrations and provides fetch interception hooks.
pub const ServiceWorkerManager = struct {
    allocator: std.mem.Allocator,
    /// Next handle ID for generating unique handles
    next_handle_id: u64 = 1,
    /// Map from handle ID to registration key (for reverse lookup)
    handle_to_key: std.AutoHashMap(u64, StoredKey),
    /// Map from registration key hash to handle
    key_to_handle: std.AutoHashMap(u64, RegistrationHandle),

    const StoredKey = struct {
        storage_key: []const u8,
        scope: []const u8,

        fn deinit(self: *StoredKey, allocator: std.mem.Allocator) void {
            allocator.free(self.storage_key);
            allocator.free(self.scope);
        }
    };

    pub fn init(allocator: std.mem.Allocator) ServiceWorkerManager {
        return .{
            .allocator = allocator,
            .handle_to_key = std.AutoHashMap(u64, StoredKey).init(allocator),
            .key_to_handle = std.AutoHashMap(u64, RegistrationHandle).init(allocator),
        };
    }

    pub fn deinit(self: *ServiceWorkerManager) void {
        // Free stored keys
        var it = self.handle_to_key.valueIterator();
        while (it.next()) |stored| {
            var mutable = stored.*;
            mutable.deinit(self.allocator);
        }
        self.handle_to_key.deinit();
        self.key_to_handle.deinit();
    }

    /// Register a service worker scope and get a handle.
    /// Returns an existing handle if already registered.
    pub fn registerScope(
        self: *ServiceWorkerManager,
        storage_key: []const u8,
        scope: []const u8,
    ) !RegistrationHandle {
        const key = RegistrationKey{
            .storage_key = storage_key,
            .scope = scope,
        };
        const key_hash = key.hash();

        // Check if already registered
        if (self.key_to_handle.get(key_hash)) |existing| {
            return existing;
        }

        // Create new handle
        const handle = RegistrationHandle{ .id = self.next_handle_id };
        self.next_handle_id += 1;

        // Store copies of the strings
        const stored = StoredKey{
            .storage_key = try self.allocator.dupe(u8, storage_key),
            .scope = try self.allocator.dupe(u8, scope),
        };

        try self.handle_to_key.put(handle.id, stored);
        try self.key_to_handle.put(key_hash, handle);

        return handle;
    }

    /// Unregister a service worker by handle.
    pub fn unregister(self: *ServiceWorkerManager, handle: RegistrationHandle) bool {
        if (self.handle_to_key.fetchRemove(handle.id)) |kv| {
            var stored = kv.value;
            const key = RegistrationKey{
                .storage_key = stored.storage_key,
                .scope = stored.scope,
            };
            _ = self.key_to_handle.remove(key.hash());
            stored.deinit(self.allocator);
            return true;
        }
        return false;
    }

    /// Find a registration that controls the given URL.
    /// Returns the handle with the longest matching scope.
    pub fn findControllingRegistration(
        self: *ServiceWorkerManager,
        storage_key: []const u8,
        url: []const u8,
    ) ?RegistrationHandle {
        var best_handle: ?RegistrationHandle = null;
        var best_scope_len: usize = 0;

        var it = self.handle_to_key.iterator();
        while (it.next()) |entry| {
            const stored = entry.value_ptr.*;
            // Must match storage key (origin)
            if (!std.mem.eql(u8, stored.storage_key, storage_key)) continue;

            // URL must start with scope
            if (std.mem.startsWith(u8, url, stored.scope)) {
                if (stored.scope.len > best_scope_len) {
                    best_scope_len = stored.scope.len;
                    best_handle = RegistrationHandle{ .id = entry.key_ptr.* };
                }
            }
        }

        return best_handle;
    }

    /// Check if a URL should be intercepted by a service worker.
    pub fn shouldInterceptFetch(
        self: *ServiceWorkerManager,
        storage_key: []const u8,
        url: []const u8,
    ) bool {
        return self.findControllingRegistration(storage_key, url) != null;
    }

    /// Get the scope for a registration handle.
    pub fn getScope(self: *ServiceWorkerManager, handle: RegistrationHandle) ?[]const u8 {
        if (self.handle_to_key.get(handle.id)) |stored| {
            return stored.scope;
        }
        return null;
    }

    /// Get count of active registrations.
    pub fn registrationCount(self: *ServiceWorkerManager) usize {
        return self.handle_to_key.count();
    }
};

// =============================================================================
// Tests
// =============================================================================

test "ServiceWorkerManager basic operations" {
    const allocator = std.testing.allocator;
    var manager = ServiceWorkerManager.init(allocator);
    defer manager.deinit();

    // Register a scope
    const handle1 = try manager.registerScope("https://example.com", "/app/");
    try std.testing.expect(handle1.isValid());
    try std.testing.expectEqual(@as(usize, 1), manager.registrationCount());

    // Re-registering same scope returns same handle
    const handle2 = try manager.registerScope("https://example.com", "/app/");
    try std.testing.expectEqual(handle1.id, handle2.id);
    try std.testing.expectEqual(@as(usize, 1), manager.registrationCount());

    // Different scope gets different handle
    const handle3 = try manager.registerScope("https://example.com", "/other/");
    try std.testing.expect(handle3.id != handle1.id);
    try std.testing.expectEqual(@as(usize, 2), manager.registrationCount());

    // Unregister
    try std.testing.expect(manager.unregister(handle1));
    try std.testing.expectEqual(@as(usize, 1), manager.registrationCount());
}

test "ServiceWorkerManager find controlling registration" {
    const allocator = std.testing.allocator;
    var manager = ServiceWorkerManager.init(allocator);
    defer manager.deinit();

    // Register scopes with different lengths
    const handle_app = try manager.registerScope("https://example.com", "/app/");
    const handle_app_admin = try manager.registerScope("https://example.com", "/app/admin/");
    _ = try manager.registerScope("https://other.com", "/app/");

    // /app/page.html controlled by /app/
    const ctrl1 = manager.findControllingRegistration("https://example.com", "/app/page.html");
    try std.testing.expect(ctrl1 != null);
    try std.testing.expectEqual(handle_app.id, ctrl1.?.id);

    // /app/admin/page.html controlled by /app/admin/ (longest match)
    const ctrl2 = manager.findControllingRegistration("https://example.com", "/app/admin/page.html");
    try std.testing.expect(ctrl2 != null);
    try std.testing.expectEqual(handle_app_admin.id, ctrl2.?.id);

    // /other/page.html not controlled
    const ctrl3 = manager.findControllingRegistration("https://example.com", "/other/page.html");
    try std.testing.expect(ctrl3 == null);

    // Different origin not controlled even with same path
    const ctrl4 = manager.findControllingRegistration("https://different.com", "/app/page.html");
    try std.testing.expect(ctrl4 == null);
}

test "ServiceWorkerManager shouldInterceptFetch" {
    const allocator = std.testing.allocator;
    var manager = ServiceWorkerManager.init(allocator);
    defer manager.deinit();

    _ = try manager.registerScope("https://example.com", "/app/");

    try std.testing.expect(manager.shouldInterceptFetch("https://example.com", "/app/index.html"));
    try std.testing.expect(!manager.shouldInterceptFetch("https://example.com", "/other/index.html"));
    try std.testing.expect(!manager.shouldInterceptFetch("https://other.com", "/app/index.html"));
}
