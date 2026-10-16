//! The state of a realm's ServiceWorker and ServiceWorkerRegistration
//! objects (Service Workers 3.1, 3.2), made by the realm's environment
//! (realm.zig) and handed to each object as a construction argument: the
//! object's impl owns it - its getters read it, its teardown frees it - and
//! the environment, which makes and keeps the object for the realm's life,
//! sets what changes ("set workerObj's state", "set the installing
//! attribute"). Neither names the other's impl (AGENTS.md, the impls
//! boundary): the state is the module's type.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const registry_mod = @import("registry.zig");
const manager_mod = @import("manager.zig");

/// A ServiceWorker object's state: the service worker it represents, and its
/// `state` attribute's value - "the value (in ServiceWorkerState
/// enumeration) to which it was last set".
pub const ServiceWorkerObject = struct {
    allocator: Allocator,
    /// The service worker (the registry's id).
    worker_id: u64,
    /// Its serialized script url (the scriptURL getter). OWNED.
    script_url: []u8,
    state: registry_mod.WorkerState,

    pub fn create(allocator: Allocator, worker_id: u64, script_url: []const u8, state: registry_mod.WorkerState) Allocator.Error!*ServiceWorkerObject {
        const self = try allocator.create(ServiceWorkerObject);
        errdefer allocator.destroy(self);
        self.* = .{
            .allocator = allocator,
            .worker_id = worker_id,
            .script_url = try allocator.dupe(u8, script_url),
            .state = state,
        };
        return self;
    }

    pub fn destroy(self: *ServiceWorkerObject) void {
        self.allocator.free(self.script_url);
        self.allocator.destroy(self);
    }
};

/// A ServiceWorkerRegistration object's state: the registration it
/// represents, and the values its installing, waiting and active attributes
/// were last set to - ServiceWorker objects of the same realm, which its
/// environment keeps alive for as long as the realm lives.
pub const RegistrationObject = struct {
    allocator: Allocator,
    registration_id: u64,
    /// The registration's serialized scope url (the scope getter). OWNED.
    scope_url: []u8,
    /// Its storage key: what update() and unregister() make their jobs with,
    /// even once the registry has let the registration go. OWNED.
    storage_key: []u8,
    update_via_cache: registry_mod.UpdateViaCache,
    installing: ?*runtime.Instance = null,
    waiting: ?*runtime.Instance = null,
    active: ?*runtime.Instance = null,
    /// The NavigationPreloadManager ([SameObject]), made on first use.
    navigation_preload: ?*runtime.Instance = null,

    pub fn create(allocator: Allocator, registration_id: u64, scope_url: []const u8, storage_key: []const u8, update_via_cache: registry_mod.UpdateViaCache) Allocator.Error!*RegistrationObject {
        const self = try allocator.create(RegistrationObject);
        errdefer allocator.destroy(self);
        const scope = try allocator.dupe(u8, scope_url);
        errdefer allocator.free(scope);
        self.* = .{
            .allocator = allocator,
            .registration_id = registration_id,
            .scope_url = scope,
            .storage_key = try allocator.dupe(u8, storage_key),
            .update_via_cache = update_via_cache,
        };
        return self;
    }

    pub fn slot(self: *RegistrationObject, which: registry_mod.Slot) *?*runtime.Instance {
        return switch (which) {
            .installing => &self.installing,
            .waiting => &self.waiting,
            .active => &self.active,
        };
    }

    pub fn destroy(self: *RegistrationObject) void {
        self.allocator.free(self.scope_url);
        self.allocator.free(self.storage_key);
        self.allocator.destroy(self);
    }
};

/// A Client object's state (4.2): the service worker client it represents,
/// as the registry described it when the object was made - Create Client,
/// Create Window Client. The Client impl owns it; a WindowClient's own part
/// borrows `window` from it (the Client part outlives it: the destruction
/// chain ends the WindowClient part first).
pub const ClientObject = struct {
    allocator: Allocator,
    /// The client's environment in the registry: what postMessage posts to.
    environment: u64,
    /// Its id.
    id: [36]u8,
    /// Its creation URL, serialized. OWNED.
    url: []u8,
    kind: registry_mod.EnvironmentKind,
    /// Its frame type ("none" unless stated otherwise).
    frame_type: registry_mod.FrameType,
    /// A WindowClient's visibility state, focus state and ancestor origins
    /// array; null for a Client.
    window: ?manager_mod.WindowData,

    pub fn create(allocator: Allocator, info: *const manager_mod.ClientInfo) Allocator.Error!*ClientObject {
        const self = try allocator.create(ClientObject);
        errdefer allocator.destroy(self);
        const url = try allocator.dupe(u8, info.url);
        errdefer allocator.free(url);
        self.* = .{
            .allocator = allocator,
            .environment = info.environment,
            .id = info.id,
            .url = url,
            .kind = info.kind,
            .frame_type = info.frame_type,
            .window = if (info.window) |*w| try w.clone(allocator) else null,
        };
        return self;
    }

    pub fn destroy(self: *ClientObject) void {
        if (self.window) |*w| w.deinit(self.allocator);
        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }
};

/// What a service worker's thread makes its message event from
/// (ServiceWorker.postMessage step 6.2.5.3): the ExtendableMessageEvent's
/// construction argument `message`. Every field BORROWED for the
/// construction; the event keeps holds of its own.
pub const ExtendableMessageInit = struct {
    /// messageClone, or null for a messageerror event.
    data: runtime.JSValue = runtime.JSValue.jsNull,
    /// Its origin, serialized - an origin, not a string: the event's
    /// extract-an-origin steps return it.
    origin: []const u8,
    /// Its source: a Client, a ServiceWorker or a MessagePort of the event's
    /// realm, or null.
    source: ?*runtime.Instance = null,
    /// newPorts.
    ports: []const *runtime.Instance = &.{},
};
