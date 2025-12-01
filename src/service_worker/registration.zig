//! Service Worker Registration Internal Structure
//!
//! Internal representation of a service worker registration per spec Section 2.3.
//! This is NOT the WebIDL ServiceWorkerRegistration interface (that's in interfaces/).
//!
//! Spec: https://w3c.github.io/ServiceWorker/#dfn-service-worker-registration

const std = @import("std");
const Allocator = std.mem.Allocator;

const types = @import("types.zig");
const UpdateViaCacheMode = types.UpdateViaCacheMode;
const NavigationPreloadState = types.NavigationPreloadState;
const service_worker_mod = @import("service_worker.zig");
const ServiceWorker = service_worker_mod.ServiceWorker;

/// Internal service worker registration structure.
///
/// A service worker registration is a tuple of a scope URL, a storage key,
/// and a set of service workers (installing, waiting, active).
///
/// Spec: https://w3c.github.io/ServiceWorker/#dfn-service-worker-registration
pub const Registration = struct {
    allocator: Allocator,

    /// Unique identifier for this registration.
    id: u64,

    /// Storage key for this registration.
    /// Typically derived from the origin.
    storage_key: []const u8,

    /// Scope URL for this registration.
    scope_url: []const u8,

    /// Installing worker (state = "installing").
    /// Null if no worker is currently installing.
    installing_worker: ?*ServiceWorker = null,

    /// Waiting worker (state = "installed").
    /// Null if no worker is waiting to activate.
    waiting_worker: ?*ServiceWorker = null,

    /// Active worker (state = "activating" or "activated").
    /// Null if no worker is active.
    active_worker: ?*ServiceWorker = null,

    /// Last update check time.
    /// Null if never checked.
    last_update_check_time: ?i64 = null,

    /// Update via cache mode.
    update_via_cache_mode: UpdateViaCacheMode = .imports,

    /// Navigation preload enabled flag.
    navigation_preload_enabled: bool = false,

    /// Navigation preload header value.
    navigation_preload_header_value: []const u8,

    /// Counter for generating unique IDs.
    var next_id: u64 = 0;

    const Self = @This();

    /// 24 hours in seconds - registration is stale after this.
    pub const STALE_THRESHOLD_SECONDS: i64 = 86400;

    /// Create a new registration.
    pub fn init(allocator: Allocator, storage_key: []const u8, scope_url: []const u8) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        const storage_key_copy = try allocator.dupe(u8, storage_key);
        errdefer allocator.free(storage_key_copy);

        const scope_url_copy = try allocator.dupe(u8, scope_url);
        errdefer allocator.free(scope_url_copy);

        const header_value = try allocator.dupe(u8, "true");

        self.* = .{
            .allocator = allocator,
            .id = next_id,
            .storage_key = storage_key_copy,
            .scope_url = scope_url_copy,
            .navigation_preload_header_value = header_value,
        };
        next_id += 1;

        return self;
    }

    pub fn deinit(self: *Self) void {
        // Note: We don't own the workers - they're managed elsewhere
        // and just referenced here.

        self.allocator.free(self.storage_key);
        self.allocator.free(self.scope_url);
        self.allocator.free(self.navigation_preload_header_value);
        self.allocator.destroy(self);
    }

    // === Worker Management ===

    /// Get the newest worker.
    ///
    /// Returns installing > waiting > active, in that order.
    ///
    /// Spec: Get Newest Worker algorithm
    pub fn getNewestWorker(self: *const Self) ?*ServiceWorker {
        if (self.installing_worker) |w| return w;
        if (self.waiting_worker) |w| return w;
        if (self.active_worker) |w| return w;
        return null;
    }

    /// Set the installing worker.
    pub fn setInstallingWorker(self: *Self, worker: ?*ServiceWorker) void {
        self.installing_worker = worker;
        if (worker) |w| {
            w.containing_registration = self;
        }
    }

    /// Set the waiting worker.
    pub fn setWaitingWorker(self: *Self, worker: ?*ServiceWorker) void {
        self.waiting_worker = worker;
        if (worker) |w| {
            w.containing_registration = self;
        }
    }

    /// Set the active worker.
    pub fn setActiveWorker(self: *Self, worker: ?*ServiceWorker) void {
        self.active_worker = worker;
        if (worker) |w| {
            w.containing_registration = self;
        }
    }

    /// Clear the installing worker.
    pub fn clearInstallingWorker(self: *Self) void {
        if (self.installing_worker) |w| {
            w.containing_registration = null;
        }
        self.installing_worker = null;
    }

    /// Clear the waiting worker.
    pub fn clearWaitingWorker(self: *Self) void {
        if (self.waiting_worker) |w| {
            w.containing_registration = null;
        }
        self.waiting_worker = null;
    }

    /// Clear the active worker.
    pub fn clearActiveWorker(self: *Self) void {
        if (self.active_worker) |w| {
            w.containing_registration = null;
        }
        self.active_worker = null;
    }

    // === Staleness ===

    /// Check if the registration is stale.
    ///
    /// A registration is stale if the last update check time is non-null
    /// and more than 24 hours ago.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#dfn-stale
    pub fn isStale(self: *const Self) bool {
        if (self.last_update_check_time) |check_time| {
            const now = std.time.timestamp();
            return (now - check_time) > STALE_THRESHOLD_SECONDS;
        }
        return false;
    }

    /// Mark as checked (update last_update_check_time).
    pub fn markChecked(self: *Self) void {
        self.last_update_check_time = std.time.timestamp();
    }

    // === Navigation Preload ===

    /// Enable navigation preload.
    pub fn enableNavigationPreload(self: *Self) void {
        self.navigation_preload_enabled = true;
    }

    /// Disable navigation preload.
    pub fn disableNavigationPreload(self: *Self) void {
        self.navigation_preload_enabled = false;
    }

    /// Set navigation preload header value.
    pub fn setNavigationPreloadHeaderValue(self: *Self, value: []const u8) !void {
        const new_value = try self.allocator.dupe(u8, value);
        self.allocator.free(self.navigation_preload_header_value);
        self.navigation_preload_header_value = new_value;
    }

    /// Get navigation preload state.
    pub fn getNavigationPreloadState(self: *const Self) NavigationPreloadState {
        return .{
            .enabled = self.navigation_preload_enabled,
            .header_value = self.navigation_preload_header_value,
        };
    }

    // === Queries ===

    /// Check if the registration has any workers.
    pub fn hasAnyWorker(self: *const Self) bool {
        return self.installing_worker != null or
            self.waiting_worker != null or
            self.active_worker != null;
    }

    /// Check if the registration can be cleared.
    ///
    /// A registration can be cleared when it has no workers.
    pub fn canBeCleaned(self: *const Self) bool {
        return !self.hasAnyWorker();
    }

    /// Get the scope URL.
    pub fn getScope(self: *const Self) []const u8 {
        return self.scope_url;
    }

    /// Get the update via cache mode.
    pub fn getUpdateViaCache(self: *const Self) UpdateViaCacheMode {
        return self.update_via_cache_mode;
    }

    /// Set the update via cache mode.
    pub fn setUpdateViaCache(self: *Self, mode: UpdateViaCacheMode) void {
        self.update_via_cache_mode = mode;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "Registration.init and deinit" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(
        allocator,
        "https://example.com",
        "https://example.com/",
    );
    defer reg.deinit();

    try std.testing.expectEqualStrings("https://example.com", reg.storage_key);
    try std.testing.expectEqualStrings("https://example.com/", reg.scope_url);
    try std.testing.expect(!reg.navigation_preload_enabled);
    try std.testing.expectEqualStrings("true", reg.navigation_preload_header_value);
}

test "Registration.getNewestWorker" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    // No workers initially
    try std.testing.expect(reg.getNewestWorker() == null);

    // Add active worker
    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    reg.setActiveWorker(sw);
    try std.testing.expectEqual(sw, reg.getNewestWorker().?);

    // Add waiting worker - should be returned instead
    const sw2 = try ServiceWorker.init(allocator, "https://example.com/sw2.js", .classic);
    defer sw2.deinit();

    reg.setWaitingWorker(sw2);
    try std.testing.expectEqual(sw2, reg.getNewestWorker().?);

    // Add installing worker - should be returned instead
    const sw3 = try ServiceWorker.init(allocator, "https://example.com/sw3.js", .classic);
    defer sw3.deinit();

    reg.setInstallingWorker(sw3);
    try std.testing.expectEqual(sw3, reg.getNewestWorker().?);
}

test "Registration.isStale" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    // Not stale initially (never checked)
    try std.testing.expect(!reg.isStale());

    // Mark as checked - not stale
    reg.markChecked();
    try std.testing.expect(!reg.isStale());

    // Simulate old check time (more than 24 hours ago)
    reg.last_update_check_time = std.time.timestamp() - (Registration.STALE_THRESHOLD_SECONDS + 1);
    try std.testing.expect(reg.isStale());
}

test "Registration.navigationPreload" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    // Disabled by default
    const state1 = reg.getNavigationPreloadState();
    try std.testing.expect(!state1.enabled);
    try std.testing.expectEqualStrings("true", state1.header_value);

    // Enable
    reg.enableNavigationPreload();
    const state2 = reg.getNavigationPreloadState();
    try std.testing.expect(state2.enabled);

    // Set custom header
    try reg.setNavigationPreloadHeaderValue("custom-value");
    const state3 = reg.getNavigationPreloadState();
    try std.testing.expectEqualStrings("custom-value", state3.header_value);

    // Disable
    reg.disableNavigationPreload();
    const state4 = reg.getNavigationPreloadState();
    try std.testing.expect(!state4.enabled);
}

test "Registration.hasAnyWorker" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    try std.testing.expect(!reg.hasAnyWorker());
    try std.testing.expect(reg.canBeCleaned());

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    reg.setActiveWorker(sw);
    try std.testing.expect(reg.hasAnyWorker());
    try std.testing.expect(!reg.canBeCleaned());

    reg.clearActiveWorker();
    try std.testing.expect(!reg.hasAnyWorker());
    try std.testing.expect(reg.canBeCleaned());
}

test "Registration.updateViaCache" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    try std.testing.expectEqual(UpdateViaCacheMode.imports, reg.getUpdateViaCache());

    reg.setUpdateViaCache(.none);
    try std.testing.expectEqual(UpdateViaCacheMode.none, reg.getUpdateViaCache());
}
