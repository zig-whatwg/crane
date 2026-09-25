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
const WorkerGlobalScope = interfaces.WorkerGlobalScope;
const WorkerLocation = interfaces.WorkerLocation;
const WorkerNavigator = interfaces.WorkerNavigator;

// Import workers infrastructure
const html_core = @import("html_core");
const workers = html_core.workers;
const InternalWorkerLocation = workers.WorkerLocation;
const InternalWorkerNavigator = workers.WorkerNavigator;
const WorkerType = workers.WorkerType;

// A global scope is an EventTarget: it chains to EventTarget's state, and its
// event handler IDL attributes live in EventTarget's event handler map.
const EventTargetImpl = @import("EventTarget.zig");
const WorkerLocationImpl = @import("WorkerLocation.zig");
const WorkerNavigatorImpl = @import("WorkerNavigator.zig");
const same_object = @import("same_object.zig");

// Import event loop for timer support
const event_loop_mod = html_core.event_loop;
const EventLoop = event_loop_mod.EventLoop;

// Import script fetching for importScripts
const script_fetch = html_core.workers.script_fetch;

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
/// as well as worker type information and event loop reference.
pub const InternalState = struct {
    /// Internal WorkerLocation (from src/html/workers/). Owned: the
    /// WorkerLocation object borrows it.
    internal_location: ?*InternalWorkerLocation = null,

    /// Internal WorkerNavigator (from src/html/workers/). Owned: the
    /// WorkerNavigator object borrows it.
    internal_navigator: ?*InternalWorkerNavigator = null,

    /// The WorkerLocation object, [SameObject]. Its wrapper is pinned while
    /// this global scope lives (same_object.zig): nothing else holds it, and a
    /// collection would otherwise free it under this pointer.
    location_instance: ?*runtime.Instance = null,
    location_pin: same_object.Pin = .{},

    /// The WorkerNavigator object, [SameObject], pinned the same way.
    navigator_instance: ?*runtime.Instance = null,
    navigator_pin: same_object.Pin = .{},

    /// Reference to the worker's event loop (for timer APIs)
    /// This is set when the worker is fully initialized with an event loop.
    event_loop: ?*EventLoop = null,

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

    /// Whether the worker is closing
    /// Spec: HTML Standard § 10.1.5 "Terminating a worker"
    closing: bool = false,

    /// Allocator used for this state
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
        // The WorkerLocation and WorkerNavigator objects are the wrapper
        // cache's: they are freed with it, not here. Only the pins are ours.
        self.location_pin.release();
        self.navigator_pin.release();
        if (self.internal_location) |loc| {
            loc.deinit();
        }
        if (self.internal_navigator) |nav| {
            nav.deinit();
        }
        // Note: event_loop is not owned, so we don't deinit it
    }

    /// Set the event loop reference (called after worker initialization)
    pub fn setEventLoop(self: *InternalState, loop: *EventLoop) void {
        self.event_loop = loop;
    }

    /// Mark the worker as closing
    ///
    /// Spec: HTML Standard § 10.1.5 "Terminating a worker"
    pub fn setClosing(self: *InternalState, value: bool) void {
        self.closing = value;
    }

    /// Check if the worker is closing
    ///
    /// Spec: HTML Standard § 10.1.5 "Terminating a worker"
    pub fn isClosing(self: *const InternalState) bool {
        return self.closing;
    }
};

/// Initialize instance (creates the instance)
///
/// A WorkerGlobalScope is an EventTarget, so this chains to EventTarget's
/// init. When `ctx` is the realm of a worker the host is running, the scope
/// takes that worker's type and URL ("run a worker" steps 7-9 set them on the
/// global scope before its script runs).
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // The WindowOrWorkerGlobalScope mixin reads a worker's settings here.
    installSettings();
    const instance = try EventTargetImpl.init(allocator, StateType, vtable, ctx);
    errdefer EventTargetImpl.deinit(instance);
    if (@import("html").worker_v8_context.scopeSettings(ctx)) |settings| {
        try setUpFromUrl(instance, allocator, settings.url, settings.worker_type);
    }
    return instance;
}

fn installSettings() void {
    @import("dom").global_settings.install(.{
        .owns = &isWorkerGlobalScope,
        .origin = &settingsOrigin,
        .is_secure_context = &settingsIsSecureContext,
        .cross_origin_isolated = &settingsCrossOriginIsolated,
    });
}

// ============================================================================
// This worker's environment settings, for the WindowOrWorkerGlobalScope mixin
// (dom.global_settings). A worker has no IDBFactory, CacheStorage or
// Performance of its own yet.
// ============================================================================

fn isWorkerGlobalScope(global: *runtime.Instance) bool {
    return global.stateAs(State) != null;
}

/// The settings object's origin, serialized; the caller owns it. Handing
/// out `internal.origin` itself, as the getter did, let the binding free it.
fn settingsOrigin(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const origin = if (state.own._internal) |internal| internal.origin else "null";
    return instance.ctx.allocator.dupe(u8, if (origin.len == 0) "null" else origin);
}

fn settingsIsSecureContext(instance: *runtime.Instance) bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return false;
    return internal.is_secure_context;
}

fn settingsCrossOriginIsolated(instance: *runtime.Instance) bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return false;
    return internal.cross_origin_isolated;
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
    installSettings();
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    try setUpFromUrl(instance, allocator, url, worker_type);
    return instance;
}

/// Give `instance` its worker's URL and type, and what follows from the URL:
/// its location, its origin and whether it is a secure context.
fn setUpFromUrl(instance: *runtime.Instance, allocator: std.mem.Allocator, url: []const u8, worker_type: WorkerType) !void {
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
        .internal_location = location,
        .internal_navigator = navigator,
        .url = location.getHref(),
        .worker_type = worker_type,
        .origin = location.getOrigin(),
        .is_secure_context = is_secure,
        .allocator = allocator,
    };

    // Store internal state
    var state = instance.getState(State);
    state.own._internal = internal_state;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    EventTargetImpl.deinit(instance);
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Set the event loop reference for this WorkerGlobalScope.
///
/// Must be called after initialization to wire up timer APIs (setTimeout, setInterval).
/// The WorkerAgent or WorkerContext should call this after creating the global scope.
///
/// Spec: HTML Standard § 10.1.4 Worker Event Loops
/// "Each worker has an event loop that is responsible for executing tasks"
pub fn setEventLoop(instance: *runtime.Instance, loop: *EventLoop) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.setEventLoop(loop);
    }
}

/// Close the worker global scope.
///
/// This marks the worker as closing and stops the event loop.
/// After calling close(), the worker will not accept new tasks and
/// will terminate once the current task completes.
///
/// Spec: HTML Standard § 10.1.5 "Terminating a worker"
/// "Set worker global scope's closing flag to true."
pub fn close(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.setClosing(true);
        // Stop the event loop if running
        if (internal.event_loop) |loop| {
            loop.stop();
        }
    }
}

/// Check if the worker is closing.
///
/// Returns true if close() has been called on this worker.
///
/// Spec: HTML Standard § 10.1.5 "Terminating a worker"
/// "If the worker global scope's closing flag is true, return."
pub fn isClosing(instance: *runtime.Instance) bool {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.isClosing();
    }
    return false;
}

/// Run the event loop (convenience method for testing).
///
/// Spins the event loop to process pending tasks.
pub fn runEventLoop(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.event_loop) |loop| {
            loop.run() catch {};
        }
    }
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
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.NotImplemented;
    if (internal.location_instance) |loc_inst| return loc_inst;
    const loc = internal.internal_location orelse return error.NotImplemented;

    const loc_instance = try WorkerLocation.init(internal.allocator, instance.ctx);
    const loc_internal = internal.allocator.create(WorkerLocationImpl.InternalState) catch {
        runtime.Instance.deinit(loc_instance);
        return error.OutOfMemory;
    };
    loc_internal.* = .{ .internal_location = loc, .allocator = internal.allocator, .owned = false };
    loc_instance.getState(WorkerLocation.State).own._internal = loc_internal;

    internal.location_instance = loc_instance;
    internal.location_pin.hold(loc_instance);
    return loc_instance;
}

/// Getter for navigator
///
/// Spec: HTML Standard § 10.1.3
/// "The navigator attribute must return the WorkerNavigator object created for
/// the WorkerGlobalScope object when the worker was created."
pub fn get_navigator(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.NotImplemented;
    if (internal.navigator_instance) |nav_inst| return nav_inst;
    const nav = internal.internal_navigator orelse return error.NotImplemented;

    const nav_instance = try WorkerNavigator.init(internal.allocator, instance.ctx);
    const nav_internal = internal.allocator.create(WorkerNavigatorImpl.InternalState) catch {
        runtime.Instance.deinit(nav_instance);
        return error.OutOfMemory;
    };
    nav_internal.* = .{ .internal_navigator = nav, .allocator = internal.allocator, .owned = false };
    nav_instance.getState(WorkerNavigator.State).own._internal = nav_internal;

    internal.navigator_instance = nav_instance;
    internal.navigator_pin.hold(nav_instance);
    return nav_instance;
}

// Event handler IDL attributes (HTML §8.1.8.1). Every one keeps its value in
// EventTarget's event handler map, which is also where dispatch finds it.

fn handler(comptime Handler: type, instance: *runtime.Instance, comptime event_type: []const u8) Handler {
    return EventTargetImpl.eventHandler(Handler, instance, event_type);
}

fn setHandler(comptime Handler: type, instance: *runtime.Instance, comptime event_type: []const u8, value: Handler) !void {
    try EventTargetImpl.setEventHandler(Handler, instance, event_type, value);
}

/// Getter for onerror
pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.OnErrorEventHandler {
    return handler(typedefs.OnErrorEventHandler, instance, "error");
}

/// Getter for onlanguagechange
pub fn get_onlanguagechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handler(typedefs.EventHandler, instance, "languagechange");
}

/// Getter for onoffline
pub fn get_onoffline(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handler(typedefs.EventHandler, instance, "offline");
}

/// Getter for ononline
pub fn get_ononline(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handler(typedefs.EventHandler, instance, "online");
}

/// Getter for onrejectionhandled
pub fn get_onrejectionhandled(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handler(typedefs.EventHandler, instance, "rejectionhandled");
}

/// Getter for onunhandledrejection
pub fn get_onunhandledrejection(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handler(typedefs.EventHandler, instance, "unhandledrejection");
}

/// Getter for fonts
pub fn get_fonts(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // FontFaceSet is not yet implemented
    _ = instance;
    return error.NotImplemented;
}

/// Setter for onerror
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.OnErrorEventHandler) anyerror!void {
    try setHandler(typedefs.OnErrorEventHandler, instance, "error", value);
}

/// Setter for onlanguagechange
pub fn set_onlanguagechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandler(typedefs.EventHandler, instance, "languagechange", value);
}

/// Setter for onoffline
pub fn set_onoffline(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandler(typedefs.EventHandler, instance, "offline", value);
}

/// Setter for ononline
pub fn set_ononline(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandler(typedefs.EventHandler, instance, "online", value);
}

/// Setter for onrejectionhandled
pub fn set_onrejectionhandled(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandler(typedefs.EventHandler, instance, "rejectionhandled", value);
}

/// Setter for onunhandledrejection
pub fn set_onunhandledrejection(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandler(typedefs.EventHandler, instance, "unhandledrejection", value);
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
    const internal = state.own._internal orelse return error.NotImplemented;

    // Step 1: Check if module worker
    // Spec: "throw a TypeError exception" for module workers
    if (internal.worker_type == .module) {
        return error.TypeError;
    }

    // Step 3: If urls is empty, return
    if (urls.len == 0) {
        return;
    }

    // Steps 4-5: Parse and fetch each script in order
    // Per spec, scripts are fetched and executed synchronously in order

    // Get the worker's script URL for resolving relative URLs
    // Per HTML spec, relative URLs in importScripts() resolve against worker's location
    const base_url: ?[]const u8 = if (internal.internal_location) |loc| loc.getHref() else null;

    for (urls) |url| {
        const url_str = url.asSlice();
        if (url_str.len == 0) {
            continue;
        }

        // Fetch the script using the script_fetch module
        // Pass base_url (worker's script URL) for relative URL resolution
        var fetched = script_fetch.fetchWorkerScript(internal.allocator, url_str, .{
            .worker_type = .classic,
            .origin = base_url orelse internal.origin,
            .credentials = .same_origin,
            .is_import_scripts = true,
        }) catch |err| {
            return switch (err) {
                script_fetch.WorkerScriptError.NetworkError => error.NetworkError,
                script_fetch.WorkerScriptError.InvalidUrl => error.TypeError,
                script_fetch.WorkerScriptError.ModuleNotAllowed => error.TypeError,
                script_fetch.WorkerScriptError.OutOfMemory => error.OutOfMemory,
                else => error.NetworkError,
            };
        };
        defer fetched.deinit();

        // Execute the script
        // NOTE: Script execution requires access to the worker's V8 context.
        // The WorkerAgent.executeScript() should be called here, but we don't
        // have direct access to it from the WebIDL implementation layer.
        // For now, we just verify the script was fetched successfully.
        // Full integration would need:
        // 1. Access to the WorkerAgent through a stored reference
        // 2. Call agent.executeScript(fetched.source)
        //
        // The script source is available in fetched.source for execution.
        _ = fetched.source;
    }
}
