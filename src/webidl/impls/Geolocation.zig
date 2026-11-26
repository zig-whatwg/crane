//! Implementation for Geolocation interface
//! Spec: https://www.w3.org/TR/geolocation/#geolocation_interface (specs/w3c/geolocation.md §6)

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const dom = @import("dom");
const permissions = @import("permissions");
const html = @import("html");
const Geolocation = interfaces.Geolocation;

pub const State = Geolocation.State;

pub const ImplError = error{
    NotImplemented,
    OutOfMemory,
};

pub const InternalState = struct {};

/// Process-wide hook installation (called once at process start by crane.Process).
pub fn installHooks() void {
    // Document-only unloading cleanup: cancel active geolocation watches,
    // timers, platform requests, and cached positions when a document unloads.
    dom.unloading_cleanup.installDocumentOnly(&html.geolocation.unloadingCleanup);
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    html.geolocation.geolocationDestroyed(instance);
}

/// Read this Browser's "geolocation" permission override from `BrowserStore`
/// (same top-level origin key as Permissions.zig). Thread-safe under mutex.
fn readGeolocationPermission(scope: *runtime.BrowserScope, key: []const u8) ?html.geolocation.PermissionState {
    const store = scope.existing(permissions.BrowserStore) orelse return null;
    std.Io.Threaded.mutexLockUncancelable(&store.mutex);
    defer std.Io.Threaded.mutexUnlock(&store.mutex);
    const state = store.get(key, permissions.PermissionDescriptor.simple(.geolocation)) orelse return null;
    return switch (state) {
        .granted => .granted,
        .denied => .denied,
        .prompt => .prompt,
    };
}

/// Operation: getCurrentPosition (§6.2)
pub fn call_getCurrentPosition(
    instance: *runtime.Instance,
    successCallback: callbacks.PositionCallback,
    errorCallback: webidl.Opt(?callbacks.PositionErrorCallback),
    options: webidl.Opt(dictionaries.PositionOptions),
) anyerror!void {
    try html.geolocation.getCurrentPosition(
        instance,
        successCallback,
        errorCallback,
        options,
        &readGeolocationPermission,
    );
}

/// Operation: watchPosition (§6.3)
pub fn call_watchPosition(
    instance: *runtime.Instance,
    successCallback: callbacks.PositionCallback,
    errorCallback: webidl.Opt(?callbacks.PositionErrorCallback),
    options: webidl.Opt(dictionaries.PositionOptions),
) anyerror!i32 {
    return try html.geolocation.watchPosition(
        instance,
        successCallback,
        errorCallback,
        options,
        &readGeolocationPermission,
    );
}

/// Operation: clearWatch (§6.4)
pub fn call_clearWatch(instance: *runtime.Instance, watchId: i32) anyerror!void {
    html.geolocation.clearWatch(instance, watchId);
}
