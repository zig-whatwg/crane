//! ServiceWorkerRegistration WebIDL Interface
//!
//! Client-side interface representing a service worker registration.
//! This wraps the internal Registration struct.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#serviceworkerregistration-interface
//!
//! WebIDL:
//! ```idl
//! [SecureContext, Exposed=(Window,Worker)]
//! interface ServiceWorkerRegistration : EventTarget {
//!   readonly attribute ServiceWorker? installing;
//!   readonly attribute ServiceWorker? waiting;
//!   readonly attribute ServiceWorker? active;
//!   [SameObject] readonly attribute NavigationPreloadManager navigationPreload;
//!
//!   readonly attribute USVString scope;
//!   readonly attribute ServiceWorkerUpdateViaCache updateViaCache;
//!
//!   [NewObject] Promise<undefined> update();
//!   [NewObject] Promise<boolean> unregister();
//!
//!   attribute EventHandler onupdatefound;
//! };
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

const types = @import("types.zig");
const UpdateViaCacheMode = types.UpdateViaCacheMode;
const EventHandler = types.EventHandler;
const VoidPromise = types.VoidPromise;
const BoolPromise = types.BoolPromise;

const service_worker_iface = @import("service_worker.zig");
const ServiceWorkerInterface = service_worker_iface.ServiceWorkerInterface;

const navigation_preload = @import("navigation_preload.zig");
const NavigationPreloadManager = navigation_preload.NavigationPreloadManager;

// Internal registration struct
const internal_reg = @import("../registration.zig");
const InternalRegistration = internal_reg.Registration;

/// ServiceWorkerRegistration WebIDL interface.
///
/// Represents a service worker registration from the client's perspective.
/// Extends EventTarget (via composition).
///
/// Spec: https://w3c.github.io/ServiceWorker/#serviceworkerregistration-interface
pub const ServiceWorkerRegistrationInterface = struct {
    allocator: Allocator,

    /// The underlying internal registration.
    internal: *InternalRegistration,

    /// Whether this interface owns the internal registration.
    owns_internal: bool = false,

    /// Cached ServiceWorker interfaces for the workers.
    /// These are lazily created and cached.
    installing_interface: ?*ServiceWorkerInterface = null,
    waiting_interface: ?*ServiceWorkerInterface = null,
    active_interface: ?*ServiceWorkerInterface = null,

    /// The NavigationPreloadManager (created lazily, [SameObject]).
    navigation_preload_manager: ?*NavigationPreloadManager = null,

    /// Event handler for update found.
    onupdatefound: EventHandler = null,

    const Self = @This();

    // =========================================================================
    // Construction
    // =========================================================================

    /// Create a new ServiceWorkerRegistration interface wrapping an internal registration.
    ///
    /// The internal registration is NOT owned by this interface.
    pub fn init(allocator: Allocator, internal_registration: *InternalRegistration) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .internal = internal_registration,
            .owns_internal = false,
        };
        return self;
    }

    /// Create a new ServiceWorkerRegistration interface that owns its internal registration.
    pub fn initOwned(
        allocator: Allocator,
        storage_key: []const u8,
        scope_url: []const u8,
    ) !*Self {
        const internal_registration = try InternalRegistration.init(allocator, storage_key, scope_url);
        errdefer internal_registration.deinit();

        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .internal = internal_registration,
            .owns_internal = true,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        // Free cached interfaces
        if (self.installing_interface) |iface| {
            iface.deinit();
        }
        if (self.waiting_interface) |iface| {
            iface.deinit();
        }
        if (self.active_interface) |iface| {
            iface.deinit();
        }
        if (self.navigation_preload_manager) |npm| {
            npm.deinit();
        }

        // Free internal if owned
        if (self.owns_internal) {
            self.internal.deinit();
        }

        self.allocator.destroy(self);
    }

    // =========================================================================
    // WebIDL Attributes - Workers
    // =========================================================================

    /// Get the installing worker interface.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#serviceworkerregistration-installing
    pub fn getInstalling(self: *Self) !?*ServiceWorkerInterface {
        const internal_worker = self.internal.installing_worker orelse {
            // Clear cached interface if worker is gone
            if (self.installing_interface) |iface| {
                iface.deinit();
                self.installing_interface = null;
            }
            return null;
        };

        // Check if we need to update the cached interface
        if (self.installing_interface) |iface| {
            if (iface.internal == internal_worker) {
                return iface;
            }
            // Different worker, free old interface
            iface.deinit();
        }

        // Create new interface
        const iface = try ServiceWorkerInterface.init(self.allocator, internal_worker);
        self.installing_interface = iface;
        return iface;
    }

    /// Get the waiting worker interface.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#serviceworkerregistration-waiting
    pub fn getWaiting(self: *Self) !?*ServiceWorkerInterface {
        const internal_worker = self.internal.waiting_worker orelse {
            if (self.waiting_interface) |iface| {
                iface.deinit();
                self.waiting_interface = null;
            }
            return null;
        };

        if (self.waiting_interface) |iface| {
            if (iface.internal == internal_worker) {
                return iface;
            }
            iface.deinit();
        }

        const iface = try ServiceWorkerInterface.init(self.allocator, internal_worker);
        self.waiting_interface = iface;
        return iface;
    }

    /// Get the active worker interface.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#serviceworkerregistration-active
    pub fn getActive(self: *Self) !?*ServiceWorkerInterface {
        const internal_worker = self.internal.active_worker orelse {
            if (self.active_interface) |iface| {
                iface.deinit();
                self.active_interface = null;
            }
            return null;
        };

        if (self.active_interface) |iface| {
            if (iface.internal == internal_worker) {
                return iface;
            }
            iface.deinit();
        }

        const iface = try ServiceWorkerInterface.init(self.allocator, internal_worker);
        self.active_interface = iface;
        return iface;
    }

    // =========================================================================
    // WebIDL Attributes - NavigationPreload
    // =========================================================================

    /// Get the NavigationPreloadManager.
    ///
    /// This is a [SameObject] attribute - always returns the same instance.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#serviceworkerregistration-navigationpreload
    pub fn getNavigationPreload(self: *Self) !*NavigationPreloadManager {
        if (self.navigation_preload_manager) |npm| {
            return npm;
        }

        const npm = try NavigationPreloadManager.init(self.allocator, self.internal);
        self.navigation_preload_manager = npm;
        return npm;
    }

    // =========================================================================
    // WebIDL Attributes - Other
    // =========================================================================

    /// Get the scope URL.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#serviceworkerregistration-scope
    pub fn getScope(self: *const Self) []const u8 {
        return self.internal.scope_url;
    }

    /// Get the update via cache mode.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#serviceworkerregistration-updateviacache
    pub fn getUpdateViaCache(self: *const Self) UpdateViaCacheMode {
        return self.internal.update_via_cache_mode;
    }

    /// Get the update via cache mode as a string.
    pub fn getUpdateViaCacheString(self: *const Self) []const u8 {
        return types.serviceWorkerUpdateViaCacheToString(self.internal.update_via_cache_mode);
    }

    // =========================================================================
    // WebIDL Methods
    // =========================================================================

    /// Update the service worker registration.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#serviceworkerregistration-update
    ///
    /// This initiates the update algorithm for this registration.
    /// In a real implementation, this would:
    /// 1. Create an Update job
    /// 2. Queue it to the job queue
    /// 3. Return a promise that resolves when the job completes
    pub fn update(self: *Self) VoidPromise {
        _ = self;
        var promise = VoidPromise.init();

        // TODO: Implement the Update algorithm
        // For now, just resolve immediately
        // In a real implementation:
        // 1. Let job be a new job with job type "update"
        // 2. Set job's various fields
        // 3. Schedule job
        // 4. Return job's promise

        promise.resolve({});
        return promise;
    }

    /// Unregister the service worker registration.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#serviceworkerregistration-unregister
    ///
    /// This initiates the unregister algorithm for this registration.
    /// Returns a promise that resolves with true if the registration was
    /// unregistered, false if it was already unregistered.
    pub fn unregister(self: *Self) BoolPromise {
        _ = self;
        var promise = BoolPromise.init();

        // TODO: Implement the Unregister algorithm
        // For now, just resolve with true
        // In a real implementation:
        // 1. Let job be a new job with job type "unregister"
        // 2. Set job's various fields
        // 3. Schedule job
        // 4. Return job's promise

        promise.resolve(true);
        return promise;
    }

    // =========================================================================
    // Event Handling
    // =========================================================================

    /// Set the onupdatefound event handler.
    pub fn setOnupdatefound(self: *Self, handler: EventHandler) void {
        self.onupdatefound = handler;
    }

    /// Get the onupdatefound event handler.
    pub fn getOnupdatefound(self: *const Self) EventHandler {
        return self.onupdatefound;
    }

    /// Fire the updatefound event.
    ///
    /// This should be called when the installing worker changes.
    pub fn fireUpdatefound(self: *Self) void {
        if (self.onupdatefound) |handler| {
            handler(@ptrCast(self));
        }
    }

    // =========================================================================
    // Internal Access
    // =========================================================================

    /// Get the internal registration.
    pub fn getInternal(self: *Self) *InternalRegistration {
        return self.internal;
    }

    /// Get the unique ID.
    pub fn getId(self: *const Self) u64 {
        return self.internal.id;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "ServiceWorkerRegistrationInterface.init" {
    const allocator = std.testing.allocator;

    const internal_reg_mod = @import("../registration.zig");
    const internal = try internal_reg_mod.Registration.init(
        allocator,
        "https://example.com",
        "https://example.com/app/",
    );
    defer internal.deinit();

    const reg = try ServiceWorkerRegistrationInterface.init(allocator, internal);
    defer reg.deinit();

    try std.testing.expectEqualStrings("https://example.com/app/", reg.getScope());
    try std.testing.expectEqual(UpdateViaCacheMode.imports, reg.getUpdateViaCache());
    try std.testing.expectEqualStrings("imports", reg.getUpdateViaCacheString());
}

test "ServiceWorkerRegistrationInterface.initOwned" {
    const allocator = std.testing.allocator;

    const reg = try ServiceWorkerRegistrationInterface.initOwned(
        allocator,
        "https://example.com",
        "https://example.com/",
    );
    defer reg.deinit();

    try std.testing.expect(reg.owns_internal);
    try std.testing.expectEqualStrings("https://example.com/", reg.getScope());
}

test "ServiceWorkerRegistrationInterface workers null when not set" {
    const allocator = std.testing.allocator;

    const reg = try ServiceWorkerRegistrationInterface.initOwned(
        allocator,
        "https://example.com",
        "https://example.com/",
    );
    defer reg.deinit();

    try std.testing.expect(try reg.getInstalling() == null);
    try std.testing.expect(try reg.getWaiting() == null);
    try std.testing.expect(try reg.getActive() == null);
}

test "ServiceWorkerRegistrationInterface workers returned when set" {
    const allocator = std.testing.allocator;

    const reg = try ServiceWorkerRegistrationInterface.initOwned(
        allocator,
        "https://example.com",
        "https://example.com/",
    );
    defer reg.deinit();

    // Create internal workers
    const sw_mod = @import("../service_worker.zig");
    const worker = try sw_mod.ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer worker.deinit();

    reg.internal.setActiveWorker(worker);

    // Get active should return interface
    const active = try reg.getActive();
    try std.testing.expect(active != null);
    try std.testing.expectEqualStrings("https://example.com/sw.js", active.?.getScriptURL());

    // Same object on second call
    const active2 = try reg.getActive();
    try std.testing.expectEqual(active, active2);
}

test "ServiceWorkerRegistrationInterface.getNavigationPreload same object" {
    const allocator = std.testing.allocator;

    const reg = try ServiceWorkerRegistrationInterface.initOwned(
        allocator,
        "https://example.com",
        "https://example.com/",
    );
    defer reg.deinit();

    const npm1 = try reg.getNavigationPreload();
    const npm2 = try reg.getNavigationPreload();

    // Should be the same object
    try std.testing.expectEqual(npm1, npm2);
}

test "ServiceWorkerRegistrationInterface.update and unregister" {
    const allocator = std.testing.allocator;

    const reg = try ServiceWorkerRegistrationInterface.initOwned(
        allocator,
        "https://example.com",
        "https://example.com/",
    );
    defer reg.deinit();

    // update() returns resolved promise (stub)
    const update_promise = reg.update();
    try std.testing.expect(update_promise.isFulfilled());

    // unregister() returns resolved promise with true (stub)
    const unregister_promise = reg.unregister();
    try std.testing.expect(unregister_promise.isFulfilled());
    try std.testing.expect(unregister_promise.value.?);
}
