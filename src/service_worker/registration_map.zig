//! Service Worker Registration Map
//!
//! Global map of service worker registrations, keyed by (storage_key, scope_url).
//!
//! Spec: https://w3c.github.io/ServiceWorker/#dfn-scope-to-registration-map

const std = @import("std");
const Allocator = std.mem.Allocator;

const registration_mod = @import("registration.zig");
const Registration = registration_mod.Registration;

/// Key for the registration map.
/// Combines storage_key and scope_url.
pub const RegistrationKey = struct {
    storage_key: []const u8,
    scope_url: []const u8,

    /// Create a composite string key for hashing.
    pub fn toCompositeKey(self: RegistrationKey, allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "{s}\x00{s}", .{ self.storage_key, self.scope_url });
    }
};

/// Global registration map.
///
/// The user agent has a registration map that stores the entries of the tuple
/// of service worker registration's (storage key, serialized scope url) and
/// the corresponding service worker registration.
///
/// Spec: https://w3c.github.io/ServiceWorker/#dfn-scope-to-registration-map
pub const RegistrationMap = struct {
    allocator: Allocator,

    /// Map from composite key to registration.
    map: std.StringHashMapUnmanaged(*Registration),

    /// Mutex for thread-safe access.
    /// In real implementation, this would use proper locking.
    mutex: std.Thread.Mutex = .{},

    const Self = @This();

    /// Initialize the registration map.
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .map = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        // Free all composite keys
        var iter = self.map.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.map.deinit(self.allocator);
    }

    /// Get a registration by key.
    pub fn get(self: *Self, storage_key: []const u8, scope_url: []const u8) ?*Registration {
        self.mutex.lock();
        defer self.mutex.unlock();

        const composite_key = std.fmt.allocPrint(self.allocator, "{s}\x00{s}", .{ storage_key, scope_url }) catch return null;
        defer self.allocator.free(composite_key);

        return self.map.get(composite_key);
    }

    /// Set a registration.
    pub fn set(self: *Self, storage_key: []const u8, scope_url: []const u8, registration: *Registration) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const composite_key = try std.fmt.allocPrint(self.allocator, "{s}\x00{s}", .{ storage_key, scope_url });
        errdefer self.allocator.free(composite_key);

        // Remove old key if exists
        if (self.map.fetchRemove(composite_key)) |old| {
            self.allocator.free(old.key);
        }

        try self.map.put(self.allocator, composite_key, registration);
    }

    /// Remove a registration.
    pub fn remove(self: *Self, storage_key: []const u8, scope_url: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        const composite_key = std.fmt.allocPrint(self.allocator, "{s}\x00{s}", .{ storage_key, scope_url }) catch return false;
        defer self.allocator.free(composite_key);

        if (self.map.fetchRemove(composite_key)) |old| {
            self.allocator.free(old.key);
            return true;
        }
        return false;
    }

    /// Check if a registration exists.
    pub fn has(self: *Self, storage_key: []const u8, scope_url: []const u8) bool {
        return self.get(storage_key, scope_url) != null;
    }

    /// Get all registrations for a storage key.
    pub fn getRegistrationsForStorageKey(self: *Self, storage_key: []const u8) ![]*Registration {
        self.mutex.lock();
        defer self.mutex.unlock();

        var result = std.ArrayListUnmanaged(*Registration){};
        errdefer result.deinit(self.allocator);

        const prefix = std.fmt.allocPrint(self.allocator, "{s}\x00", .{storage_key}) catch return &[_]*Registration{};
        defer self.allocator.free(prefix);

        var iter = self.map.iterator();
        while (iter.next()) |entry| {
            if (std.mem.startsWith(u8, entry.key_ptr.*, prefix)) {
                try result.append(self.allocator, entry.value_ptr.*);
            }
        }

        return try result.toOwnedSlice(self.allocator);
    }

    /// Find the most specific registration for a URL.
    ///
    /// Returns the registration with the longest matching scope.
    ///
    /// Spec: Match Service Worker Registration algorithm
    pub fn matchRegistration(self: *Self, storage_key: []const u8, url: []const u8) ?*Registration {
        self.mutex.lock();
        defer self.mutex.unlock();

        const prefix = std.fmt.allocPrint(self.allocator, "{s}\x00", .{storage_key}) catch return null;
        defer self.allocator.free(prefix);

        var best_match: ?*Registration = null;
        var best_scope_len: usize = 0;

        var iter = self.map.iterator();
        while (iter.next()) |entry| {
            if (std.mem.startsWith(u8, entry.key_ptr.*, prefix)) {
                const registration = entry.value_ptr.*;
                const scope = registration.scope_url;

                // Check if URL starts with scope
                if (std.mem.startsWith(u8, url, scope)) {
                    if (scope.len > best_scope_len) {
                        best_match = registration;
                        best_scope_len = scope.len;
                    }
                }
            }
        }

        return best_match;
    }

    /// Get total number of registrations.
    pub fn count(self: *Self) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.map.count();
    }

    /// Clear all registrations.
    pub fn clear(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var iter = self.map.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.map.clearRetainingCapacity();
    }
};

// =============================================================================
// Tests
// =============================================================================

test "RegistrationMap.init and deinit" {
    const allocator = std.testing.allocator;

    var map = RegistrationMap.init(allocator);
    defer map.deinit();

    try std.testing.expectEqual(@as(usize, 0), map.count());
}

test "RegistrationMap.set and get" {
    const allocator = std.testing.allocator;

    var map = RegistrationMap.init(allocator);
    defer map.deinit();

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    try map.set("https://example.com", "https://example.com/", reg);

    const retrieved = map.get("https://example.com", "https://example.com/");
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqual(reg, retrieved.?);
}

test "RegistrationMap.has" {
    const allocator = std.testing.allocator;

    var map = RegistrationMap.init(allocator);
    defer map.deinit();

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    try std.testing.expect(!map.has("https://example.com", "https://example.com/"));

    try map.set("https://example.com", "https://example.com/", reg);
    try std.testing.expect(map.has("https://example.com", "https://example.com/"));
}

test "RegistrationMap.remove" {
    const allocator = std.testing.allocator;

    var map = RegistrationMap.init(allocator);
    defer map.deinit();

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    try map.set("https://example.com", "https://example.com/", reg);
    try std.testing.expectEqual(@as(usize, 1), map.count());

    const removed = map.remove("https://example.com", "https://example.com/");
    try std.testing.expect(removed);
    try std.testing.expectEqual(@as(usize, 0), map.count());
}

test "RegistrationMap.matchRegistration finds longest scope" {
    const allocator = std.testing.allocator;

    var map = RegistrationMap.init(allocator);
    defer map.deinit();

    const reg1 = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg1.deinit();

    const reg2 = try Registration.init(allocator, "https://example.com", "https://example.com/app/");
    defer reg2.deinit();

    try map.set("https://example.com", "https://example.com/", reg1);
    try map.set("https://example.com", "https://example.com/app/", reg2);

    // URL under /app/ should match reg2 (more specific)
    const match1 = map.matchRegistration("https://example.com", "https://example.com/app/page.html");
    try std.testing.expectEqual(reg2, match1.?);

    // URL outside /app/ should match reg1
    const match2 = map.matchRegistration("https://example.com", "https://example.com/other/page.html");
    try std.testing.expectEqual(reg1, match2.?);

    // Different origin should not match
    const match3 = map.matchRegistration("https://other.com", "https://other.com/page.html");
    try std.testing.expect(match3 == null);
}

test "RegistrationMap.getRegistrationsForStorageKey" {
    const allocator = std.testing.allocator;

    var map = RegistrationMap.init(allocator);
    defer map.deinit();

    const reg1 = try Registration.init(allocator, "https://example.com", "https://example.com/a/");
    defer reg1.deinit();

    const reg2 = try Registration.init(allocator, "https://example.com", "https://example.com/b/");
    defer reg2.deinit();

    const reg3 = try Registration.init(allocator, "https://other.com", "https://other.com/");
    defer reg3.deinit();

    try map.set("https://example.com", "https://example.com/a/", reg1);
    try map.set("https://example.com", "https://example.com/b/", reg2);
    try map.set("https://other.com", "https://other.com/", reg3);

    const regs = try map.getRegistrationsForStorageKey("https://example.com");
    defer allocator.free(regs);

    try std.testing.expectEqual(@as(usize, 2), regs.len);
}

test "RegistrationMap.clear" {
    const allocator = std.testing.allocator;

    var map = RegistrationMap.init(allocator);
    defer map.deinit();

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    try map.set("https://example.com", "https://example.com/", reg);
    try std.testing.expectEqual(@as(usize, 1), map.count());

    map.clear();
    try std.testing.expectEqual(@as(usize, 0), map.count());
}
