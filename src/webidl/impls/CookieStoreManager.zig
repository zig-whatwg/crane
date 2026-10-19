//! Implementation for CookieStoreManager interface
//!
//! WHATWG Cookie Store Standard 4: https://cookiestore.spec.whatwg.org/#cookiestoremanager
//!
//! A CookieStoreManager has an associated registration (a service worker
//! registration): a realm's ServiceWorkerRegistration object makes its
//! manager with the registration's id and scope url as construction
//! arguments, as it makes its NavigationPreloadManager. The registration's
//! cookie change subscription list lives on its record, in the Browser's
//! service worker registry (src/service_worker): a window's
//! `registration.cookies` and the service worker's own `registration.cookies`
//! read and change the one list. Each method's steps before "in parallel" run
//! in this realm; the rest run on the manager's job thread, in order with the
//! cookie changes the jar reports, and the promise settles in a later task of
//! this realm (service_worker.realm.cookieSubscriptions).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const service_worker = @import("service_worker");
const CookieStoreManager = interfaces.CookieStoreManager;

pub const State = CookieStoreManager.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
};

/// Its registration: the record's id, and its scope url (copied).
pub const construction_args = .{ "registration_id", "scope_url" };

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The associated service worker registration (an id: the record is the
    /// Browser's, reached under its manager's lock).
    registration_id: u64,
    /// The registration's scope url, serialized. OWNED.
    scope_url: []u8,
};

/// CookieStoreManager's own construction steps.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    if (!@hasField(@TypeOf(args), "registration_id")) return;
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);
    internal.* = .{
        .allocator = allocator,
        .registration_id = args.registration_id,
        .scope_url = try allocator.dupe(u8, args.scope_url),
    };
    instance.getState(State).own._internal = internal;
}

/// CookieStoreManager's own teardown.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.allocator.free(internal.scope_url);
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

fn internalOf(instance: *runtime.Instance) !*InternalState {
    return instance.getState(State).own._internal orelse error.InvalidStateError;
}

/// Operation: subscribe(subscriptions) (4.1).
pub fn call_subscribe(instance: *runtime.Instance, subscriptions: runtime.JSValue) anyerror!runtime.JSValue {
    const internal = try internalOf(instance);
    return service_worker.realm.cookieSubscriptions(instance, internal.registration_id, internal.scope_url, .subscribe, subscriptions);
}

/// Operation: getSubscriptions() (4.2).
pub fn call_getSubscriptions(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = try internalOf(instance);
    return service_worker.realm.cookieSubscriptions(instance, internal.registration_id, internal.scope_url, .get, null);
}

/// Operation: unsubscribe(subscriptions) (4.3).
pub fn call_unsubscribe(instance: *runtime.Instance, subscriptions: runtime.JSValue) anyerror!runtime.JSValue {
    const internal = try internalOf(instance);
    return service_worker.realm.cookieSubscriptions(instance, internal.registration_id, internal.scope_url, .unsubscribe, subscriptions);
}
