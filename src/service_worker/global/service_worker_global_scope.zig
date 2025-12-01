//! ServiceWorkerGlobalScope
//!
//! The global object inside a service worker context.
//! Extends WorkerGlobalScope with service worker-specific APIs.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#serviceworkerglobalscope-interface
//!
//! WebIDL:
//! ```idl
//! [Global=(Worker,ServiceWorker), Exposed=ServiceWorker, SecureContext]
//! interface ServiceWorkerGlobalScope : WorkerGlobalScope {
//!   [SameObject] readonly attribute Clients clients;
//!   [SameObject] readonly attribute ServiceWorkerRegistration registration;
//!   [SameObject] readonly attribute ServiceWorker serviceWorker;
//!
//!   [NewObject] Promise<undefined> skipWaiting();
//!
//!   attribute EventHandler oninstall;
//!   attribute EventHandler onactivate;
//!   attribute EventHandler onfetch;
//!
//!   attribute EventHandler onmessage;
//!   attribute EventHandler onmessageerror;
//! };
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

// HTML mocks (Phase 1)
const mocks = @import("../../mocks/root.zig");
const WorkerGlobalScope = mocks.WorkerGlobalScope;

// Internal types
const internal_sw = @import("../service_worker.zig");
const InternalServiceWorker = internal_sw.ServiceWorker;

const internal_reg = @import("../registration.zig");
const InternalRegistration = internal_reg.Registration;

const types = @import("../types.zig");
const ServiceWorkerState = types.ServiceWorkerState;
const WorkerType = types.WorkerType;

// Interface types
const iface_types = @import("../interfaces/types.zig");
const VoidPromise = iface_types.VoidPromise;
const EventHandler = iface_types.EventHandler;

const sw_iface = @import("../interfaces/service_worker.zig");
const ServiceWorkerInterface = sw_iface.ServiceWorkerInterface;

const reg_iface = @import("../interfaces/registration.zig");
const ServiceWorkerRegistrationInterface = reg_iface.ServiceWorkerRegistrationInterface;

// Clients API
const clients_mod = @import("clients.zig");
const Clients = clients_mod.Clients;

/// ServiceWorkerGlobalScope.
///
/// The global scope for a running service worker. Provides access to:
/// - clients: Controlled browsing contexts
/// - registration: The service worker's registration
/// - serviceWorker: Reference to the service worker itself
/// - Event handlers for lifecycle and functional events
///
/// Spec: https://w3c.github.io/ServiceWorker/#serviceworkerglobalscope-interface
pub const ServiceWorkerGlobalScope = struct {
    allocator: Allocator,

    /// The base WorkerGlobalScope.
    /// Provides location, navigator, event loop, etc.
    base: *WorkerGlobalScope,

    /// Whether we own the base scope.
    owns_base: bool = false,

    /// The internal service worker.
    internal_service_worker: *InternalServiceWorker,

    /// The internal registration.
    internal_registration: *InternalRegistration,

    /// The Clients API ([SameObject]).
    clients: *Clients,

    /// Cached ServiceWorker interface ([SameObject]).
    service_worker_interface: ?*ServiceWorkerInterface = null,

    /// Cached ServiceWorkerRegistration interface ([SameObject]).
    registration_interface: ?*ServiceWorkerRegistrationInterface = null,

    // === Event Handlers ===

    /// Install event handler.
    oninstall: EventHandler = null,

    /// Activate event handler.
    onactivate: EventHandler = null,

    /// Fetch event handler.
    onfetch: EventHandler = null,

    /// Message event handler.
    onmessage: EventHandler = null,

    /// Message error event handler.
    onmessageerror: EventHandler = null,

    const Self = @This();

    // =========================================================================
    // Construction
    // =========================================================================

    /// Create a new ServiceWorkerGlobalScope.
    ///
    /// This is called when a service worker starts executing.
    pub fn init(
        allocator: Allocator,
        service_worker: *InternalServiceWorker,
        registration: *InternalRegistration,
    ) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        // Create base WorkerGlobalScope
        const worker_type: WorkerGlobalScope.WorkerType = switch (service_worker.worker_type) {
            .classic => .classic,
            .module => .module,
        };
        const base = try WorkerGlobalScope.init(allocator, service_worker.script_url, worker_type);
        errdefer base.deinit();

        // Create Clients API
        const clients_api = try Clients.init(allocator, registration.scope_url);
        errdefer clients_api.deinit();

        self.* = .{
            .allocator = allocator,
            .base = base,
            .owns_base = true,
            .internal_service_worker = service_worker,
            .internal_registration = registration,
            .clients = clients_api,
        };

        // Set the global object reference on the internal service worker
        service_worker.global_object = self;

        return self;
    }

    pub fn deinit(self: *Self) void {
        // Clear global object reference
        self.internal_service_worker.global_object = null;

        // Free cached interfaces
        if (self.service_worker_interface) |iface| {
            iface.deinit();
        }
        if (self.registration_interface) |iface| {
            iface.deinit();
        }

        // Free Clients API
        self.clients.deinit();

        // Free base if owned
        if (self.owns_base) {
            self.base.deinit();
        }

        self.allocator.destroy(self);
    }

    // =========================================================================
    // WebIDL Attributes
    // =========================================================================

    /// Get the Clients API.
    ///
    /// Returns the Clients object for accessing controlled clients.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#serviceworkerglobalscope-clients
    pub fn getClients(self: *Self) *Clients {
        return self.clients;
    }

    /// Get the registration.
    ///
    /// Returns the service worker's registration object.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#serviceworkerglobalscope-registration
    pub fn getRegistration(self: *Self) !*ServiceWorkerRegistrationInterface {
        if (self.registration_interface) |iface| {
            return iface;
        }

        const iface = try ServiceWorkerRegistrationInterface.init(
            self.allocator,
            self.internal_registration,
        );
        self.registration_interface = iface;
        return iface;
    }

    /// Get the service worker.
    ///
    /// Returns a reference to the service worker itself.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#serviceworkerglobalscope-serviceworker
    pub fn getServiceWorker(self: *Self) !*ServiceWorkerInterface {
        if (self.service_worker_interface) |iface| {
            return iface;
        }

        const iface = try ServiceWorkerInterface.init(
            self.allocator,
            self.internal_service_worker,
        );
        self.service_worker_interface = iface;
        return iface;
    }

    // =========================================================================
    // WebIDL Methods
    // =========================================================================

    /// Skip waiting.
    ///
    /// Allows an installing service worker to activate without waiting
    /// for existing clients to close.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#serviceworkerglobalscope-skipwaiting
    ///
    /// Steps:
    /// 1. Set this service worker's skip waiting flag.
    /// 2. Return a promise resolved with undefined.
    pub fn skipWaiting(self: *Self) VoidPromise {
        var promise = VoidPromise.init();

        // Set skip waiting flag
        self.internal_service_worker.setSkipWaiting();

        promise.resolve({});
        return promise;
    }

    // =========================================================================
    // Event Handler Setters/Getters
    // =========================================================================

    pub fn setOninstall(self: *Self, handler: EventHandler) void {
        self.oninstall = handler;
        if (handler != null) {
            self.internal_service_worker.addEventTypeToHandle("install") catch {};
        }
    }

    pub fn getOninstall(self: *const Self) EventHandler {
        return self.oninstall;
    }

    pub fn setOnactivate(self: *Self, handler: EventHandler) void {
        self.onactivate = handler;
        if (handler != null) {
            self.internal_service_worker.addEventTypeToHandle("activate") catch {};
        }
    }

    pub fn getOnactivate(self: *const Self) EventHandler {
        return self.onactivate;
    }

    pub fn setOnfetch(self: *Self, handler: EventHandler) void {
        self.onfetch = handler;
        if (handler != null) {
            self.internal_service_worker.addEventTypeToHandle("fetch") catch {};
        }
    }

    pub fn getOnfetch(self: *const Self) EventHandler {
        return self.onfetch;
    }

    pub fn setOnmessage(self: *Self, handler: EventHandler) void {
        self.onmessage = handler;
        if (handler != null) {
            self.internal_service_worker.addEventTypeToHandle("message") catch {};
        }
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

    // =========================================================================
    // Inherited from WorkerGlobalScope
    // =========================================================================

    /// Get self (the global scope).
    pub fn getSelf(self: *Self) *Self {
        return self;
    }

    /// Get location.
    pub fn getLocation(self: *Self) *mocks.WorkerLocation {
        return self.base.getLocation();
    }

    /// Get navigator.
    pub fn getNavigator(self: *Self) *mocks.WorkerNavigator {
        return self.base.getNavigator();
    }

    /// Get origin.
    pub fn getOrigin(self: *const Self) []const u8 {
        return self.base.getOrigin();
    }

    /// Get isSecureContext.
    pub fn getIsSecureContext(self: *const Self) bool {
        return self.base.getIsSecureContext();
    }

    // =========================================================================
    // Event Dispatching
    // =========================================================================

    /// Fire the install event.
    pub fn fireInstallEvent(self: *Self) void {
        if (self.oninstall) |handler| {
            handler(@ptrCast(self));
        }
    }

    /// Fire the activate event.
    pub fn fireActivateEvent(self: *Self) void {
        if (self.onactivate) |handler| {
            handler(@ptrCast(self));
        }
    }

    /// Fire the fetch event.
    /// Returns true if the event was handled.
    pub fn fireFetchEvent(self: *Self, request_ctx: ?*anyopaque) bool {
        _ = request_ctx;
        if (self.onfetch) |handler| {
            handler(@ptrCast(self));
            return true;
        }
        return false;
    }

    /// Fire the message event.
    pub fn fireMessageEvent(self: *Self, message_ctx: ?*anyopaque) void {
        _ = message_ctx;
        if (self.onmessage) |handler| {
            handler(@ptrCast(self));
        }
    }

    // =========================================================================
    // Internal Methods
    // =========================================================================

    /// Get the internal service worker.
    pub fn getInternalServiceWorker(self: *Self) *InternalServiceWorker {
        return self.internal_service_worker;
    }

    /// Get the internal registration.
    pub fn getInternalRegistration(self: *Self) *InternalRegistration {
        return self.internal_registration;
    }

    /// Run the event loop.
    pub fn runEventLoop(self: *Self) void {
        self.base.runEventLoop();
    }

    /// Close the worker.
    pub fn close(self: *Self) void {
        self.base.close();
    }

    /// Check if closing.
    pub fn isClosing(self: *const Self) bool {
        return self.base.isClosing();
    }
};

// =============================================================================
// Tests
// =============================================================================

test "ServiceWorkerGlobalScope.init and deinit" {
    const allocator = std.testing.allocator;

    // Create internal service worker
    const sw = try InternalServiceWorker.init(allocator, "https://example.com/sw.js", .module);
    defer sw.deinit();

    // Create internal registration
    const reg = try InternalRegistration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    // Create global scope
    const scope = try ServiceWorkerGlobalScope.init(allocator, sw, reg);
    defer scope.deinit();

    try std.testing.expectEqualStrings("https://example.com", scope.getOrigin());
    try std.testing.expect(scope.getIsSecureContext());
}

test "ServiceWorkerGlobalScope.getClients" {
    const allocator = std.testing.allocator;

    const sw = try InternalServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    const reg = try InternalRegistration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const scope = try ServiceWorkerGlobalScope.init(allocator, sw, reg);
    defer scope.deinit();

    const clients_api = scope.getClients();
    try std.testing.expectEqualStrings("https://example.com/", clients_api.registration_scope);
}

test "ServiceWorkerGlobalScope.getRegistration same object" {
    const allocator = std.testing.allocator;

    const sw = try InternalServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    const reg = try InternalRegistration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const scope = try ServiceWorkerGlobalScope.init(allocator, sw, reg);
    defer scope.deinit();

    const reg1 = try scope.getRegistration();
    const reg2 = try scope.getRegistration();

    // Should be same object
    try std.testing.expectEqual(reg1, reg2);
}

test "ServiceWorkerGlobalScope.getServiceWorker same object" {
    const allocator = std.testing.allocator;

    const sw = try InternalServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    const reg = try InternalRegistration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const scope = try ServiceWorkerGlobalScope.init(allocator, sw, reg);
    defer scope.deinit();

    const sw1 = try scope.getServiceWorker();
    const sw2 = try scope.getServiceWorker();

    try std.testing.expectEqual(sw1, sw2);
}

test "ServiceWorkerGlobalScope.skipWaiting" {
    const allocator = std.testing.allocator;

    const sw = try InternalServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    const reg = try InternalRegistration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const scope = try ServiceWorkerGlobalScope.init(allocator, sw, reg);
    defer scope.deinit();

    try std.testing.expect(!sw.shouldSkipWaiting());

    const promise = scope.skipWaiting();
    try std.testing.expect(promise.isFulfilled());
    try std.testing.expect(sw.shouldSkipWaiting());
}

test "ServiceWorkerGlobalScope.setOninstall registers event type" {
    const allocator = std.testing.allocator;

    const sw = try InternalServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    const reg = try InternalRegistration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const scope = try ServiceWorkerGlobalScope.init(allocator, sw, reg);
    defer scope.deinit();

    try std.testing.expect(!sw.handlesEventType("install"));

    scope.setOninstall(struct {
        fn handler(_: *anyopaque) void {}
    }.handler);

    try std.testing.expect(sw.handlesEventType("install"));
}

test "ServiceWorkerGlobalScope.setOnfetch registers event type" {
    const allocator = std.testing.allocator;

    const sw = try InternalServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    const reg = try InternalRegistration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const scope = try ServiceWorkerGlobalScope.init(allocator, sw, reg);
    defer scope.deinit();

    try std.testing.expect(!sw.handlesFetchEvents());

    scope.setOnfetch(struct {
        fn handler(_: *anyopaque) void {}
    }.handler);

    try std.testing.expect(sw.handlesFetchEvents());
}

test "ServiceWorkerGlobalScope.global_object set correctly" {
    const allocator = std.testing.allocator;

    const sw = try InternalServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    const reg = try InternalRegistration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    // Before creating scope, global_object is null
    try std.testing.expect(!sw.isRunning());

    const scope = try ServiceWorkerGlobalScope.init(allocator, sw, reg);

    // Now should be running
    try std.testing.expect(sw.isRunning());

    scope.deinit();

    // After deinit, should not be running
    try std.testing.expect(!sw.isRunning());
}
