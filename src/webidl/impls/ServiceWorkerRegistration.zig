//! Implementation for ServiceWorkerRegistration interface
//!
//! Spec: Service Workers 3.2 ServiceWorkerRegistration
//! https://w3c.github.io/ServiceWorker/#serviceworkerregistration-interface
//!
//! A ServiceWorkerRegistration has a service worker registration. Its realm's
//! environment (src/service_worker/realm.zig, "get the service worker
//! registration object") makes it with the registration's state as a
//! construction argument - the scope, the update via cache mode and the
//! installing, waiting and active attributes, which the environment sets as
//! Update Registration State's tasks run - and this impl owns that state. Its
//! onupdatefound is the generated event handler (dom.event_handlers).
//!
//! Cookie Store 4.4: the cookies attribute returns the registration's
//! CookieStoreManager - made here with the registration's id and scope url,
//! as navigationPreload's manager is.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const service_worker = @import("service_worker");
const ServiceWorkerRegistration = interfaces.ServiceWorkerRegistration;

pub const State = ServiceWorkerRegistration.State;

pub const ImplError = error{
    NotImplemented,
    SecurityError,
    OutOfMemory,
};

/// Its service worker registration: what its realm's environment gives it.
pub const construction_args = .{"service_worker_registration"};

/// Internal state for ServiceWorkerRegistration implementation
pub const InternalState = struct {
    /// The registration's state, OWNED (the environment sets what changes).
    registration: *service_worker.RegistrationObject,
    /// Allocator for internal allocations
    allocator: std.mem.Allocator,
};

/// ServiceWorkerRegistration's own construction steps: the generated chain
/// runs EventTarget's first. `args.service_worker_registration` is taken.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    if (!@hasField(@TypeOf(args), "service_worker_registration")) return;
    const registration: *service_worker.RegistrationObject = args.service_worker_registration;
    const internal = try allocator.create(InternalState);
    internal.* = .{
        .registration = registration,
        .allocator = allocator,
    };
    instance.getState(State).own._internal = internal;
}

/// ServiceWorkerRegistration's own teardown: the generated chain runs
/// EventTarget's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.registration.destroy();
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

/// Helper to get internal state from instance
fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

fn registrationOf(instance: *runtime.Instance) !*service_worker.RegistrationObject {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    return internal.registration;
}

/// Getter for installing (3.2.2): "the value to which it was last set".
pub fn get_installing(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return (try registrationOf(instance)).installing;
}

/// Getter for waiting (3.2.3).
pub fn get_waiting(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return (try registrationOf(instance)).waiting;
}

/// Getter for active (3.2.4).
pub fn get_active(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return (try registrationOf(instance)).active;
}

/// Getter for navigationPreload (3.2.5): the registration's
/// NavigationPreloadManager - one per object here ([SameObject], kept by the
/// generated getter), associated with its service worker registration.
pub fn get_navigationPreload(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const registration = try registrationOf(instance);
    return interfaces.NavigationPreloadManager.initWith(instance.ctx.allocator, instance.ctx, .{ .registration_id = registration.registration_id });
}

/// Getter for scope (3.2.6): the registration's serialized scope url.
pub fn get_scope(instance: *runtime.Instance) anyerror!runtime.USVString {
    return instance.ctx.allocator.dupe(u8, (try registrationOf(instance)).scope_url);
}

/// Getter for updateViaCache (3.2.7): the registration's update via cache
/// mode.
pub fn get_updateViaCache(instance: *runtime.Instance) anyerror!enums.ServiceWorkerUpdateViaCache {
    return switch ((try registrationOf(instance)).update_via_cache) {
        .imports => ._imports_,
        .all => ._all_,
        .none => ._none_,
    };
}

/// Getter for periodicSync
pub fn get_periodicSync(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for cookies (Cookie Store 4.4): the registration's
/// CookieStoreManager - one per object here ([SameObject], kept by the
/// generated getter), associated with its service worker registration.
pub fn get_cookies(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const registration = try registrationOf(instance);
    return interfaces.CookieStoreManager.initWith(instance.ctx.allocator, instance.ctx, .{
        .registration_id = registration.registration_id,
        .scope_url = registration.scope_url,
    });
}

/// Getter for sync
pub fn get_sync(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for index
pub fn get_index(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for backgroundFetch
pub fn get_backgroundFetch(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for paymentManager
pub fn get_paymentManager(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: unregister (3.2.9).
pub fn call_unregister(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return service_worker.realm.unregister(instance, try registrationOf(instance));
}

/// Operation: update (3.2.8).
pub fn call_update(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return service_worker.realm.update(instance, try registrationOf(instance));
}

/// Operation: showNotification
pub fn call_showNotification(instance: *runtime.Instance, title: runtime.DOMString, options: webidl.Opt(dictionaries.NotificationOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = title;
    _ = options;
    return error.NotImplemented;
}

/// Operation: getNotifications
pub fn call_getNotifications(instance: *runtime.Instance, filter: webidl.Opt(dictionaries.GetNotificationOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = filter;
    return error.NotImplemented;
}
