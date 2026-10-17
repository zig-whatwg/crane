//! Implementation for NavigationPreloadManager interface
//!
//! Spec: Service Workers 3.6 NavigationPreloadManager
//! https://w3c.github.io/ServiceWorker/#navigationpreloadmanager
//!
//! A registration's NavigationPreloadManager, as a realm's
//! ServiceWorkerRegistration object makes it: its service worker registration
//! is the construction argument `registration_id`. The registration's
//! navigation preload enabled flag and header value live on its record
//! (src/service_worker); each method's in parallel steps read or write them
//! there, and its promise settles in a later task of this realm
//! (service_worker.realm.navigationPreload).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const service_worker = @import("service_worker");
const NavigationPreloadManager = interfaces.NavigationPreloadManager;

pub const State = NavigationPreloadManager.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
};

/// Its service worker registration's id.
pub const construction_args = .{"registration_id"};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The associated service worker registration (an id: the record is the
    /// Browser's, reached under its lock).
    registration_id: u64,
};

/// NavigationPreloadManager's own construction steps.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    if (!@hasField(@TypeOf(args), "registration_id")) return;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator, .registration_id = args.registration_id };
    instance.getState(State).own._internal = internal;
}

/// NavigationPreloadManager's own teardown.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

fn registrationOf(instance: *runtime.Instance) !u64 {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return internal.registration_id;
}

/// Operation: enable (3.6.1).
pub fn call_enable(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return service_worker.realm.navigationPreload(instance, try registrationOf(instance), .enable);
}

/// Operation: disable (3.6.2).
pub fn call_disable(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return service_worker.realm.navigationPreload(instance, try registrationOf(instance), .disable);
}

/// Operation: setHeaderValue (3.6.3).
pub fn call_setHeaderValue(instance: *runtime.Instance, value: runtime.ByteString) anyerror!runtime.JSValue {
    const registration_id = try registrationOf(instance);
    // 1-2. Not a header value: a promise rejected with a TypeError.
    if (try service_worker.realm.rejectedHeaderValue(instance, value)) |promise| return promise;
    // 3-5.
    return service_worker.realm.navigationPreload(instance, registration_id, .{ .set_header_value = value });
}

/// Operation: getState (3.6.4).
pub fn call_getState(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return service_worker.realm.navigationPreload(instance, try registrationOf(instance), .get_state);
}
