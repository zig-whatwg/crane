//! Implementation for WorkerGlobalScope interface
//!
//! Spec: HTML Standard § 10.1 The WorkerGlobalScope common interface
//! https://html.spec.whatwg.org/#workerglobalscope
//!
//! WorkerGlobalScope is the base interface for all worker global scopes
//! (DedicatedWorkerGlobalScope, SharedWorkerGlobalScope, ServiceWorkerGlobalScope).
//! It provides common functionality like location, navigator, importScripts, etc.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const WorkerGlobalScope = interfaces.WorkerGlobalScope;
const WorkerLocation = interfaces.WorkerLocation;
const WorkerNavigator = interfaces.WorkerNavigator;

// Import workers infrastructure
const html_core = @import("html_core");
const workers = html_core.workers;
const InternalWorkerLocation = workers.WorkerLocation;
const InternalWorkerNavigator = workers.WorkerNavigator;
const WorkerType = workers.WorkerType;

// Import structured clone
const structured_clone = html_core.structured_clone;

pub const State = WorkerGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
    NetworkError,
    TypeError,
    OutOfMemory,
};

/// Internal state for WorkerGlobalScope implementation
///
/// Contains cached WorkerLocation and WorkerNavigator objects,
/// as well as worker type information.
pub const InternalState = struct {
    /// Cached WorkerLocation instance
    location: ?*InternalWorkerLocation = null,

    /// Cached WorkerNavigator instance
    navigator: ?*InternalWorkerNavigator = null,

    /// Worker script URL
    url: []const u8 = "",

    /// Worker type (classic or module)
    worker_type: WorkerType = .classic,

    /// Origin
    origin: []const u8 = "",

    /// Is secure context
    is_secure_context: bool = false,

    /// Cross-origin isolated
    cross_origin_isolated: bool = false,

    /// Allocator used for this state
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
        if (self.location) |loc| {
            loc.deinit();
        }
        if (self.navigator) |nav| {
            nav.deinit();
        }
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

/// Initialize with worker URL and type
pub fn initWithUrl(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    url: []const u8,
    worker_type: WorkerType,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Create internal state
    const internal_state = try allocator.create(InternalState);
    errdefer allocator.destroy(internal_state);

    // Create WorkerLocation
    const location = try InternalWorkerLocation.init(allocator, url);
    errdefer location.deinit();

    // Create WorkerNavigator
    const navigator = try InternalWorkerNavigator.init(allocator);
    errdefer navigator.deinit();

    // Determine if secure context
    const is_secure = std.mem.startsWith(u8, url, "https://") or
        std.mem.startsWith(u8, url, "wss://") or
        std.mem.startsWith(u8, url, "file://");

    internal_state.* = .{
        .location = location,
        .navigator = navigator,
        .url = url,
        .worker_type = worker_type,
        .origin = location.getOrigin(),
        .is_secure_context = is_secure,
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

/// Getter for self
///
/// Spec: HTML Standard § 10.1
/// "The self attribute must return the WorkerGlobalScope object itself."
pub fn get_self(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return instance;
}

/// Getter for location
///
/// Spec: HTML Standard § 10.1.2
/// "The location attribute must return the WorkerLocation object created for
/// the WorkerGlobalScope object when the worker was created."
pub fn get_location(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // TODO: Return wrapped WorkerLocation instance
    // For now, return the instance itself (location is accessed through internal state)
    _ = instance;
    return error.NotImplemented;
}

/// Getter for navigator
///
/// Spec: HTML Standard § 10.1.3
/// "The navigator attribute must return the WorkerNavigator object created for
/// the WorkerGlobalScope object when the worker was created."
pub fn get_navigator(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // TODO: Return wrapped WorkerNavigator instance
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onerror
pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.OnErrorEventHandler {
    const state = instance.getState(State);
    return state.own.onerror;
}

/// Getter for onlanguagechange
pub fn get_onlanguagechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onlanguagechange;
}

/// Getter for onoffline
pub fn get_onoffline(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onoffline;
}

/// Getter for ononline
pub fn get_ononline(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.ononline;
}

/// Getter for onrejectionhandled
pub fn get_onrejectionhandled(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onrejectionhandled;
}

/// Getter for onunhandledrejection
pub fn get_onunhandledrejection(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onunhandledrejection;
}

/// Getter for fonts
pub fn get_fonts(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // FontFaceSet is not yet implemented
    _ = instance;
    return error.NotImplemented;
}

/// Getter for origin
///
/// Spec: HTML Standard § 10.1.1
/// "The origin attribute must return this's relevant settings object's origin,
/// serialized."
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.origin;
    }
    return "null";
}

/// Getter for isSecureContext
///
/// Spec: HTML Standard § 10.1.1
/// "The isSecureContext attribute must return true if this's relevant settings
/// object is a secure context, and false otherwise."
pub fn get_isSecureContext(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.is_secure_context;
    }
    return false;
}

/// Getter for crossOriginIsolated
///
/// Spec: HTML Standard § 10.1.1
/// "The crossOriginIsolated attribute must return this's relevant settings object's
/// cross-origin isolated capability."
pub fn get_crossOriginIsolated(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.cross_origin_isolated;
    }
    return false;
}

/// Getter for indexedDB
pub fn get_indexedDB(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for trustedTypes
pub fn get_trustedTypes(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for performance
pub fn get_performance(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for caches
pub fn get_caches(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for scheduler
pub fn get_scheduler(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for crypto
pub fn get_crypto(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for onerror
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.OnErrorEventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onlanguagechange
pub fn set_onlanguagechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onoffline
pub fn set_onoffline(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ononline
pub fn set_ononline(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onrejectionhandled
pub fn set_onrejectionhandled(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onunhandledrejection
pub fn set_onunhandledrejection(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: reportError
pub fn call_reportError(instance: *runtime.Instance, e: *const anyopaque) anyerror!void {
    _ = instance;
    _ = e;
    return error.NotImplemented;
}

/// Operation: atob
pub fn call_atob(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.ByteString {
    _ = instance;
    _ = data;
    return error.NotImplemented;
}

/// Operation: btoa
pub fn call_btoa(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.DOMString {
    _ = instance;
    _ = data;
    return error.NotImplemented;
}

/// Operation: setInterval
pub fn call_setInterval(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: webidl.Opt(i32), arguments: []const *const anyopaque) anyerror!i32 {
    _ = instance;
    _ = handler;
    _ = timeout;
    _ = arguments;
    return error.NotImplemented;
}

/// Operation: createImageBitmap
pub fn call_createImageBitmap(instance: *runtime.Instance, image: typedefs.ImageBitmapSource, options: webidl.Opt(dictionaries.ImageBitmapOptions)) anyerror!*const anyopaque {
    _ = instance;
    _ = image;
    _ = options;
    return error.NotImplemented;
}

/// Operation: clearInterval
pub fn call_clearInterval(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    _ = instance;
    _ = id;
    return error.NotImplemented;
}

/// Operation: queueMicrotask
pub fn call_queueMicrotask(instance: *runtime.Instance, callback: callbacks.VoidFunction) anyerror!void {
    _ = instance;
    _ = callback;
    return error.NotImplemented;
}

/// Operation: structuredClone
///
/// Spec: HTML Standard § 2.7.9 structuredClone(value, options)
/// https://html.spec.whatwg.org/#dom-structuredclone
///
/// "The structuredClone(value, options) method, when invoked, must run these steps:
/// 1. Let serialized be ? StructuredSerializeWithTransfer(value, options["transfer"]).
/// 2. Let deserializeRecord be ? StructuredDeserializeWithTransfer(serialized, this's relevant Realm).
/// 3. Return deserializeRecord.[[Deserialized]]."
pub fn call_structuredClone(instance: *runtime.Instance, value: *const anyopaque, options: webidl.Opt(dictionaries.StructuredSerializeOptions)) anyerror!*const anyopaque {
    // Get allocator from instance
    const state = instance.getState(State);
    if (state.own._internal == null) {
        return error.NotImplemented;
    }
    const internal = state.own._internal.?;

    // Parse options for transfer list
    const transfer_list: ?[]structured_clone.Transferable = if (options.wasPassed()) blk: {
        // Transfer list parsing would be done here
        _ = options.getValue();
        break :blk null;
    } else null;

    // The value parameter represents the JavaScript value to clone
    // In a full implementation, this would be properly converted to JSValue
    // based on the actual JavaScript type. For now, treat as undefined if null.
    const js_value = if (@intFromPtr(value) != 0)
        // Non-null value - simplified handling
        structured_clone.JSValue{ .object = .{ .properties = &[_]structured_clone.JSValue.ObjectValue.ObjectProperty{} } }
    else
        structured_clone.JSValue.undefined;

    // Perform structured clone
    const cloned = structured_clone.structuredClone(
        internal.allocator,
        &js_value,
        transfer_list,
    ) catch {
        return error.OutOfMemory;
    };

    // Return as opaque pointer
    return @ptrCast(cloned);
}

/// Operation: importScripts
///
/// Spec: HTML Standard § 10.1.5 importScripts(urls...)
/// https://html.spec.whatwg.org/#dom-workerglobalscope-importscripts
///
/// "The importScripts(urls) method, when invoked, must run these steps:
/// 1. If this is a module script, throw a TypeError exception.
/// 2. Let settings object be this's relevant settings object.
/// 3. If urls is empty, return.
/// 4. Parse each value in urls, relative to settings object...
/// 5. For each url in the resulting URL records, fetch the script..."
pub fn call_importScripts(instance: *runtime.Instance, urls: []const runtime.DOMString) anyerror!void {
    const state = instance.getState(State);

    // Step 1: Check if module worker
    if (state.own._internal) |internal| {
        if (internal.worker_type == .module) {
            // Spec: "throw a TypeError exception" for module workers
            return error.TypeError;
        }
    }

    // Step 3: If urls is empty, return
    if (urls.len == 0) {
        return;
    }

    // Steps 4-5: Parse and fetch each script
    // TODO: Actually fetch and execute scripts
    // This requires:
    // 1. Resolve relative URLs against worker's base URL
    // 2. Fetch each script synchronously
    // 3. Execute each script in order
    //
    // For now, we just validate URLs and return
    for (urls) |url| {
        // Validate URL
        const url_str = url.asSlice();
        if (url_str.len == 0) {
            continue;
        }
        // TODO: Actual fetch and execution
    }
}

/// Operation: clearTimeout
pub fn call_clearTimeout(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    _ = instance;
    _ = id;
    return error.NotImplemented;
}

/// Operation: setTimeout
pub fn call_setTimeout(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: webidl.Opt(i32), arguments: []const *const anyopaque) anyerror!i32 {
    _ = instance;
    _ = handler;
    _ = timeout;
    _ = arguments;
    return error.NotImplemented;
}

/// Operation: fetch
pub fn call_fetch(instance: *runtime.Instance, input: typedefs.RequestInfo, init_data: webidl.Opt(dictionaries.RequestInit)) anyerror!*const anyopaque {
    _ = instance;
    _ = input;
    _ = init_data;
    return error.NotImplemented;
}
