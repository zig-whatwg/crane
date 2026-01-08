//! ServiceWorkerContainer WebIDL Interface
//!
//! The main entry point for service worker APIs from a client context.
//! Accessed via navigator.serviceWorker.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#serviceworkercontainer-interface
//!
//! WebIDL:
//! ```idl
//! [SecureContext, Exposed=(Window,Worker)]
//! interface ServiceWorkerContainer : EventTarget {
//!   readonly attribute ServiceWorker? controller;
//!   readonly attribute Promise<ServiceWorkerRegistration> ready;
//!
//!   [NewObject] Promise<ServiceWorkerRegistration> register(USVString scriptURL,
//!                                                           optional RegistrationOptions options = {});
//!
//!   [NewObject] Promise<(ServiceWorkerRegistration or undefined)> getRegistration(
//!                                                           optional USVString clientURL = "");
//!   [NewObject] Promise<FrozenArray<ServiceWorkerRegistration>> getRegistrations();
//!
//!   undefined startMessages();
//!
//!   // events
//!   attribute EventHandler oncontrollerchange;
//!   attribute EventHandler onmessage;
//!   attribute EventHandler onmessageerror;
//! };
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

const types = @import("types.zig");
const RegistrationOptions = types.RegistrationOptions;
const EventHandler = types.EventHandler;
const Promise = types.Promise;

const service_worker_iface = @import("service_worker.zig");
const ServiceWorkerInterface = service_worker_iface.ServiceWorkerInterface;

const registration_iface = @import("registration.zig");
const ServiceWorkerRegistrationInterface = registration_iface.ServiceWorkerRegistrationInterface;

// Internal modules
const registration_map_mod = @import("../registration_map.zig");
const RegistrationMap = registration_map_mod.RegistrationMap;

const client_mod = @import("../client.zig");
const Client = client_mod.Client;

/// ServiceWorkerContainer WebIDL interface.
///
/// The main interface for interacting with service workers from a client.
/// Accessed via `navigator.serviceWorker` in JavaScript.
///
/// Spec: https://w3c.github.io/ServiceWorker/#serviceworkercontainer-interface
pub const ServiceWorkerContainer = struct {
    allocator: Allocator,

    /// The client this container belongs to.
    client: *Client,

    /// Global registration map (shared reference).
    registration_map: *RegistrationMap,

    /// Cached controller interface.
    controller_interface: ?*ServiceWorkerInterface = null,

    /// The ready promise.
    /// Resolved when there's an active registration.
    ready_promise: ?Promise(*ServiceWorkerRegistrationInterface) = null,

    /// Whether messages have been started.
    messages_started: bool = false,

    /// Event handlers.
    oncontrollerchange: EventHandler = null,
    onmessage: EventHandler = null,
    onmessageerror: EventHandler = null,

    /// Cached registration interfaces.
    registration_cache: std.StringHashMapUnmanaged(*ServiceWorkerRegistrationInterface),

    const Self = @This();

    // =========================================================================
    // Construction
    // =========================================================================

    /// Create a ServiceWorkerContainer for a client.
    pub fn init(
        allocator: Allocator,
        client: *Client,
        registration_map: *RegistrationMap,
    ) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .client = client,
            .registration_map = registration_map,
            .registration_cache = .{},
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        // Free cached controller interface
        if (self.controller_interface) |iface| {
            iface.deinit();
        }

        // Free cached registration interfaces
        var iter = self.registration_cache.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.*.deinit();
        }
        self.registration_cache.deinit(self.allocator);

        self.allocator.destroy(self);
    }

    // =========================================================================
    // WebIDL Attributes
    // =========================================================================

    /// Get the controller.
    ///
    /// Returns the active service worker that controls this client, or null.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#serviceworkercontainer-controller
    pub fn getController(self: *Self) !?*ServiceWorkerInterface {
        const internal_worker = self.client.active_service_worker orelse {
            // Clear cached interface if no controller
            if (self.controller_interface) |iface| {
                iface.deinit();
                self.controller_interface = null;
            }
            return null;
        };

        // Check if cached interface is still valid
        if (self.controller_interface) |iface| {
            if (iface.internal == internal_worker) {
                return iface;
            }
            iface.deinit();
        }

        // Create new interface
        const iface = try ServiceWorkerInterface.init(self.allocator, internal_worker);
        self.controller_interface = iface;
        return iface;
    }

    /// Get the ready promise.
    ///
    /// Returns a promise that resolves when there's an active registration
    /// for this client's URL.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#serviceworkercontainer-ready
    pub fn getReady(self: *Self) !*Promise(*ServiceWorkerRegistrationInterface) {
        if (self.ready_promise) |*promise| {
            return promise;
        }

        // Create the ready promise
        self.ready_promise = Promise(*ServiceWorkerRegistrationInterface).init();

        // Check if there's already an active registration
        if (self.registration_map.getByClientUrl(self.client.url)) |internal_reg| {
            if (internal_reg.active_worker != null) {
                // There's an active registration - resolve immediately
                const reg_iface = try self.getOrCreateRegistrationInterface(internal_reg);
                self.ready_promise.?.resolve(reg_iface);
            }
        }

        return &self.ready_promise.?;
    }

    // =========================================================================
    // WebIDL Methods
    // =========================================================================

    /// Register a service worker.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#serviceworkercontainer-register
    ///
    /// Steps:
    /// 1. Parse scriptURL against entry settings object
    /// 2. If options.scope is present, parse it
    /// 3. Create a register job and queue it
    /// 4. Return the job's promise
    pub fn register(
        self: *Self,
        script_url: []const u8,
        options: RegistrationOptions,
    ) !Promise(*ServiceWorkerRegistrationInterface) {
        var promise = Promise(*ServiceWorkerRegistrationInterface).init();

        // Validate script URL
        // In a real implementation, we'd parse and validate the URL
        if (script_url.len == 0) {
            promise.reject(error.TypeError);
            return promise;
        }

        // Determine scope
        const scope = options.scope orelse blk: {
            // Default scope is the directory containing the script
            if (std.mem.lastIndexOf(u8, script_url, "/")) |idx| {
                break :blk script_url[0 .. idx + 1];
            }
            break :blk "/";
        };

        // TODO: Create a register job and queue it
        // For now, create a registration directly (stub implementation)

        // Check if registration already exists
        const storage_key = self.getStorageKey();
        if (self.registration_map.get(storage_key, scope)) |existing_reg| {
            // Return existing registration
            const reg_iface = try self.getOrCreateRegistrationInterface(existing_reg);
            promise.resolve(reg_iface);
            return promise;
        }

        // Create new registration
        const internal_reg = @import("../registration.zig");
        const new_reg = try internal_reg.Registration.init(self.allocator, storage_key, scope);

        // Add to registration map
        try self.registration_map.set(new_reg);

        // Create interface
        const reg_iface = try self.getOrCreateRegistrationInterface(new_reg);
        promise.resolve(reg_iface);

        return promise;
    }

    /// Get registration for a URL.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#serviceworkercontainer-getregistration
    pub fn getRegistration(
        self: *Self,
        client_url: ?[]const u8,
    ) !Promise(?*ServiceWorkerRegistrationInterface) {
        var promise = Promise(?*ServiceWorkerRegistrationInterface).init();

        const url = client_url orelse self.client.url;
        const storage_key = self.getStorageKey();

        if (self.registration_map.getByClientUrl(url)) |internal_reg| {
            // Check storage key matches
            if (std.mem.eql(u8, internal_reg.storage_key, storage_key)) {
                const reg_iface = try self.getOrCreateRegistrationInterface(internal_reg);
                promise.resolve(reg_iface);
                return promise;
            }
        }

        promise.resolve(null);
        return promise;
    }

    /// Get all registrations.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#serviceworkercontainer-getregistrations
    pub fn getRegistrations(self: *Self) !Promise([]*ServiceWorkerRegistrationInterface) {
        var promise = Promise([]*ServiceWorkerRegistrationInterface).init();

        const storage_key = self.getStorageKey();
        const internal_regs = try self.registration_map.getAllForStorageKey(self.allocator, storage_key);
        defer self.allocator.free(internal_regs);

        var interfaces = try self.allocator.alloc(*ServiceWorkerRegistrationInterface, internal_regs.len);
        errdefer self.allocator.free(interfaces);

        for (internal_regs, 0..) |internal_reg, i| {
            interfaces[i] = try self.getOrCreateRegistrationInterface(internal_reg);
        }

        promise.resolve(interfaces);
        return promise;
    }

    /// Start messages.
    ///
    /// Enables message event dispatch for this container.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#serviceworkercontainer-startmessages
    pub fn startMessages(self: *Self) void {
        self.messages_started = true;
        // TODO: Dispatch any queued messages
    }

    // =========================================================================
    // Event Handling
    // =========================================================================

    pub fn setOncontrollerchange(self: *Self, handler: EventHandler) void {
        self.oncontrollerchange = handler;
    }

    pub fn getOncontrollerchange(self: *const Self) EventHandler {
        return self.oncontrollerchange;
    }

    pub fn setOnmessage(self: *Self, handler: EventHandler) void {
        self.onmessage = handler;
    }

    pub fn getOnmessage(self: *const Self) EventHandler {
        return self.onmessage;
    }

    pub fn setOnmessageerror(self: *Self, handler: EventHandler) void {
        self.onmessageerror = handler;
    }

    pub fn getOnmessageerror(self: *const Self) EventHandler {
        return self.onmessageerror;
    }

    /// Fire the controllerchange event.
    pub fn fireControllerchange(self: *Self) void {
        if (self.oncontrollerchange) |handler| {
            handler(@ptrCast(self));
        }
    }

    // =========================================================================
    // Internal Helpers
    // =========================================================================

    /// Get the storage key for this client.
    fn getStorageKey(self: *const Self) []const u8 {
        // Extract origin from client URL
        // In a real implementation, this would properly parse the URL
        const url = self.client.url;
        if (std.mem.indexOf(u8, url, "://")) |scheme_end| {
            const after_scheme = url[scheme_end + 3 ..];
            if (std.mem.indexOf(u8, after_scheme, "/")) |path_start| {
                return url[0 .. scheme_end + 3 + path_start];
            }
        }
        return url;
    }

    /// Get or create a cached registration interface.
    fn getOrCreateRegistrationInterface(
        self: *Self,
        internal_reg: *@import("../registration.zig").Registration,
    ) !*ServiceWorkerRegistrationInterface {
        // Use scope as cache key
        if (self.registration_cache.get(internal_reg.scope_url)) |cached| {
            if (cached.internal == internal_reg) {
                return cached;
            }
            // Different internal, remove old
            if (self.registration_cache.fetchRemove(internal_reg.scope_url)) |old| {
                self.allocator.free(old.key);
                old.value.deinit();
            }
        }

        // Create new interface
        const reg_iface = try ServiceWorkerRegistrationInterface.init(self.allocator, internal_reg);
        errdefer reg_iface.deinit();

        // Cache it
        const scope_copy = try self.allocator.dupe(u8, internal_reg.scope_url);
        errdefer self.allocator.free(scope_copy);

        try self.registration_cache.put(self.allocator, scope_copy, reg_iface);

        return reg_iface;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "ServiceWorkerContainer.init" {
    const allocator = std.testing.allocator;

    const client = try Client.init(allocator, "https://example.com/page.html", .window);
    defer client.deinit();

    var reg_map = RegistrationMap.init();
    defer reg_map.deinit(allocator);

    const container = try ServiceWorkerContainer.init(allocator, client, &reg_map);
    defer container.deinit();

    // Controller should be null initially
    try std.testing.expect(try container.getController() == null);
}

test "ServiceWorkerContainer.getController" {
    const allocator = std.testing.allocator;

    const client = try Client.init(allocator, "https://example.com/page.html", .window);
    defer client.deinit();

    var reg_map = RegistrationMap.init();
    defer reg_map.deinit(allocator);

    const container = try ServiceWorkerContainer.init(allocator, client, &reg_map);
    defer container.deinit();

    // Create a service worker
    const sw_mod = @import("../service_worker.zig");
    const worker = try sw_mod.ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer worker.deinit();

    // Set as controller
    client.setController(worker);

    // Now controller should be returned
    const controller = try container.getController();
    try std.testing.expect(controller != null);
    try std.testing.expectEqualStrings("https://example.com/sw.js", controller.?.getScriptURL());
}

test "ServiceWorkerContainer.register" {
    const allocator = std.testing.allocator;

    const client = try Client.init(allocator, "https://example.com/page.html", .window);
    defer client.deinit();

    var reg_map = RegistrationMap.init();
    defer reg_map.deinit(allocator);

    const container = try ServiceWorkerContainer.init(allocator, client, &reg_map);
    defer container.deinit();

    // Register a service worker
    const promise = try container.register("https://example.com/sw.js", .{
        .scope = "/app/",
    });

    try std.testing.expect(promise.isFulfilled());
    try std.testing.expect(promise.value != null);

    const reg = promise.value.?;
    try std.testing.expectEqualStrings("/app/", reg.getScope());
}

test "ServiceWorkerContainer.startMessages" {
    const allocator = std.testing.allocator;

    const client = try Client.init(allocator, "https://example.com/page.html", .window);
    defer client.deinit();

    var reg_map = RegistrationMap.init();
    defer reg_map.deinit(allocator);

    const container = try ServiceWorkerContainer.init(allocator, client, &reg_map);
    defer container.deinit();

    try std.testing.expect(!container.messages_started);
    container.startMessages();
    try std.testing.expect(container.messages_started);
}
