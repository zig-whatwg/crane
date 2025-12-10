//! Implementation for WorkerNavigator interface
//!
//! Spec: HTML Standard § 10.1.3 The WorkerNavigator interface
//! https://html.spec.whatwg.org/#workernavigator
//!
//! The WorkerNavigator interface provides navigator-like information
//! within worker contexts, with a subset of the Window's Navigator API.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const WorkerNavigator = interfaces.WorkerNavigator;

// Import workers infrastructure
const html_core = @import("html_core");
const workers = html_core.workers;
const InternalWorkerNavigator = workers.WorkerNavigator;

pub const State = WorkerNavigator.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for WorkerNavigator implementation
///
/// Contains a reference to the backing WorkerNavigator from src/html/workers/.
pub const InternalState = struct {
    /// Backing implementation from workers module
    internal_navigator: *InternalWorkerNavigator,

    /// Allocator used for this state
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
        self.internal_navigator.deinit();
    }
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Initialize with internal navigator
pub fn initWithInternal(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Create internal WorkerNavigator
    const internal_navigator = try InternalWorkerNavigator.init(allocator);
    errdefer internal_navigator.deinit();

    // Create internal state
    const internal_state = try allocator.create(InternalState);
    internal_state.* = .{
        .internal_navigator = internal_navigator,
        .allocator = allocator,
    };

    // Store internal state
    var state = instance.getState(State);
    state.own._internal = internal_state;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Getter for mediaCapabilities
pub fn get_mediaCapabilities(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for serial
pub fn get_serial(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for permissions
pub fn get_permissions(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for smartCard
pub fn get_smartCard(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for usb
pub fn get_usb(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for hid
pub fn get_hid(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for serviceWorker
pub fn get_serviceWorker(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for locks
pub fn get_locks(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for gpu
pub fn get_gpu(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for globalPrivacyControl
pub fn get_globalPrivacyControl(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for connection
pub fn get_connection(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ml
pub fn get_ml(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for deviceMemory
pub fn get_deviceMemory(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for storage
pub fn get_storage(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for storageBuckets
pub fn get_storageBuckets(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for appCodeName
///
/// Spec: HTML Standard § 8.8.1.1 NavigatorID
/// "Must return the string 'Mozilla'."
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_appCodeName(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.internal_navigator.getAppCodeName());
    }
    return try runtime.DOMString.initDupe(instance.ctx.allocator, "Mozilla");
}

/// Getter for appName
///
/// Spec: HTML Standard § 8.8.1.1 NavigatorID
/// "Must return the string 'Netscape'."
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_appName(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.internal_navigator.getAppName());
    }
    return try runtime.DOMString.initDupe(instance.ctx.allocator, "Netscape");
}

/// Getter for appVersion
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_appVersion(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.internal_navigator.getAppVersion());
    }
    return try runtime.DOMString.initDupe(instance.ctx.allocator, "5.0");
}

/// Getter for platform
///
/// Spec: HTML Standard § 8.8.1.1 NavigatorID
/// "Must return a string representing the platform on which the browser is executing."
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_platform(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.internal_navigator.getPlatform());
    }
    return error.NotImplemented;
}

/// Getter for product
///
/// Spec: HTML Standard § 8.8.1.1 NavigatorID
/// "Must return the string 'Gecko'."
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_product(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.internal_navigator.getProduct());
    }
    return try runtime.DOMString.initDupe(instance.ctx.allocator, "Gecko");
}

/// Getter for productSub
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_productSub(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.internal_navigator.getProductSub());
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for userAgent
///
/// Spec: HTML Standard § 8.8.1.1 NavigatorID
/// "Must return the default User-Agent value."
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_userAgent(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.internal_navigator.getUserAgent());
    }
    return error.NotImplemented;
}

/// Getter for vendor
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_vendor(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.internal_navigator.getVendor());
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for vendorSub
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_vendorSub(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.internal_navigator.getVendorSub());
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for oscpu
pub fn get_oscpu(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    // Not commonly exposed
    return runtime.DOMString.initEmpty();
}

/// Getter for language
///
/// Spec: HTML Standard § 8.8.1.2 NavigatorLanguage
/// "Must return a valid BCP 47 language tag representing the user's preferred language."
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_language(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.internal_navigator.getLanguage());
    }
    return try runtime.DOMString.initDupe(instance.ctx.allocator, "en-US");
}

/// Getter for languages
///
/// Spec: HTML Standard § 8.8.1.2 NavigatorLanguage
/// "Must return a frozen array of valid BCP 47 language tags."
pub fn get_languages(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        // Return as JSValue wrapping pointer to slice
        return runtime.JSValue.fromAnyopaque(@ptrCast(internal.internal_navigator.getLanguages().ptr));
    }
    return error.NotImplemented;
}

/// Getter for onLine
///
/// Spec: HTML Standard § 8.8.1.3 NavigatorOnLine
/// "Must return false if the user agent is definitely offline, true otherwise."
pub fn get_onLine(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.internal_navigator.isOnLine();
    }
    return true;
}

/// Getter for hardwareConcurrency
///
/// Spec: HTML Standard § 8.8.1.4 NavigatorConcurrentHardware
/// "Must return a number representing the approximate number of logical processors."
pub fn get_hardwareConcurrency(instance: *runtime.Instance) anyerror!u64 {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return @intCast(internal.internal_navigator.getHardwareConcurrency());
    }
    return 1;
}

/// Getter for userAgentData
pub fn get_userAgentData(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: taintEnabled
pub fn call_taintEnabled(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setAppBadge
pub fn call_setAppBadge(instance: *runtime.Instance, contents: webidl.Opt(u64)) anyerror!runtime.JSValue {
    _ = instance;
    _ = contents;
    return error.NotImplemented;
}

/// Operation: clearAppBadge
pub fn call_clearAppBadge(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}
