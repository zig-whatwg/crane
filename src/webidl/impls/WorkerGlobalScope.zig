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

// A global scope is an EventTarget: it chains to EventTarget's state, and its
// event handler IDL attributes live in EventTarget's event handler map.
const EventTargetImpl = @import("EventTarget.zig");
const WorkerLocationImpl = @import("WorkerLocation.zig");
const WorkerNavigatorImpl = @import("WorkerNavigator.zig");
const same_object = @import("same_object.zig");

// Import event loop for timer support
const event_loop_mod = html_core.event_loop;
const EventLoop = event_loop_mod.EventLoop;

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
    /// WebCrypto §10: this worker's Crypto, kept by a collector-traced edge.
    crypto: ?struct {
        owner: *runtime.Instance,
        value: *runtime.Instance,
        edge: same_object.Traced = .{ .slot = .{ .name = "crypto" } },
    } = null,
    /// Trusted Types 4.1: this worker's trusted type policy factory, kept by a
    /// collector-traced edge.
    trusted_types: ?struct {
        owner: *runtime.Instance,
        value: *runtime.Instance,
        edge: same_object.Traced = .{ .slot = .{ .name = "trustedTypes" } },
    } = null,
    /// HR-Time: this worker global's Performance - made on first use, with
    /// the settings object's time origin - kept by a collector-traced edge, as
    /// LocalDOMWindow::Trace and WorkerGlobalScope::Trace visit performance_.
    performance: ?struct {
        owner: *runtime.Instance,
        value: *runtime.Instance,
        edge: same_object.Traced = .{ .slot = .{ .name = "performance" } },
    } = null,
    /// The settings object's time origin (HR-Time): "run a worker" step 3's
    /// unsafe worker creation time, monotonic nanoseconds as the worker host
    /// recorded it (worker_host.ScopeSettings); null when it recorded none.
    time_origin_ns: ?i64 = null,
    /// IndexedDB 4.3: one factory owned by this worker global's traced graph.
    indexed_db: ?struct {
        owner: *runtime.Instance,
        value: *runtime.Instance,
        edge: same_object.Traced = .{ .slot = .{ .name = "indexedDB" } },
    } = null,

    /// Reference to the worker's event loop (for timer APIs)
    /// This is set when the worker is fully initialized with an event loop.
    event_loop: ?*EventLoop = null,

    /// Worker script URL
    url: []const u8 = "",

    /// The user agent's cookie jar, from the worker's creator
    /// (worker_host.ScopeSettings; BORROWED).
    cookie_jar: ?*@import("cookiestore").CookieJar = null,

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
        if (self.indexed_db) |*factory| factory.edge.release(factory.owner);
        if (self.performance) |*performance| performance.edge.release(performance.owner);
        if (self.crypto) |*crypto| crypto.edge.release(crypto.owner);
        if (self.trusted_types) |*factory| factory.edge.release(factory.owner);
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
    const instance = try EventTargetImpl.init(allocator, StateType, vtable, ctx);
    errdefer EventTargetImpl.deinit(instance);
    if (@import("html").worker_host.scopeSettings(ctx)) |settings| {
        try setUpFromUrl(instance, allocator, settings.url, settings.worker_type);
        if (instance.getState(State).own._internal) |internal| {
            internal.cookie_jar = settings.cookie_jar;
            internal.time_origin_ns = settings.time_origin_ns;
        }
    }
    return instance;
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // The WindowOrWorkerGlobalScope mixin reads a worker's settings here.
    @import("dom").global_settings.install(.{
        .owns = &isWorkerGlobalScope,
        .origin = &settingsOrigin,
        .is_secure_context = &settingsIsSecureContext,
        .cross_origin_isolated = &settingsCrossOriginIsolated,
        .performance = &settingsPerformance,
        .time_origin = &settingsTimeOrigin,
        .crypto = &settingsCrypto,
        .trusted_types = &settingsTrustedTypes,
        .indexed_db = &settingsIndexedDB,
        .cookie_jar = &settingsCookieJar,
        .policy_container = &settingsPolicyContainer,
    });
}

/// The settings object's policy container: the worker global scope's, which
/// the host running the worker keeps (html.worker_host).
fn settingsPolicyContainer(instance: *runtime.Instance) ?*const @import("fetch").internal.PolicyContainer {
    const settings = @import("html").worker_host.scopeSettings(instance.ctx) orelse return null;
    return settings.policy_container;
}

/// The user agent's cookie jar, as the worker's creator handed it over.
fn settingsCookieJar(instance: *runtime.Instance) ?*@import("cookiestore").CookieJar {
    const internal = instance.getState(State).own._internal orelse return null;
    return internal.cookie_jar;
}

// ============================================================================
// This worker's environment settings, for the WindowOrWorkerGlobalScope mixin
// (dom.global_settings). A worker has no CacheStorage of its own yet.
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

/// HR-Time 4.4: "The performance getter steps are to return this's
/// Performance object" - one per global, made on first use. Its time origin
/// is the settings object's (`settingsTimeOrigin`), recorded when the worker
/// was made, never the moment this object is.
fn settingsPerformance(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    if (internal.performance) |performance| return performance.value;
    const performance = try interfaces.Performance.init(internal.allocator, instance.ctx);
    internal.performance = .{ .owner = instance, .value = performance };
    internal.performance.?.edge.hold(instance, performance);
    return performance;
}

/// The settings object's time origin: the worker's creation time.
fn settingsTimeOrigin(instance: *runtime.Instance) ?i64 {
    const internal = instance.getState(State).own._internal orelse return null;
    return internal.time_origin_ns;
}

/// WebCrypto §10: each worker global gets its own Crypto instance.
fn settingsCrypto(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    if (internal.crypto) |crypto| return crypto.value;
    const crypto = try interfaces.Crypto.init(internal.allocator, instance.ctx);
    internal.crypto = .{ .owner = instance, .value = crypto };
    internal.crypto.?.edge.hold(instance, crypto);
    return crypto;
}

/// Trusted Types 4.1: each worker global gets its own trusted type policy
/// factory.
fn settingsTrustedTypes(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    if (internal.trusted_types) |factory| return factory.value;
    const factory = try interfaces.TrustedTypePolicyFactory.init(internal.allocator, instance.ctx);
    internal.trusted_types = .{ .owner = instance, .value = factory };
    internal.trusted_types.?.edge.hold(instance, factory);
    return factory;
}

fn settingsIndexedDB(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    if (internal.indexed_db) |factory| return factory.value;
    const factory = try interfaces.IDBFactory.init(internal.allocator, instance.ctx);
    internal.indexed_db = .{ .owner = instance, .value = factory };
    internal.indexed_db.?.edge.hold(instance, factory);
    return factory;
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

/// Operation: importScripts - "import scripts into worker global scope"
/// given this and urls.
///
/// Spec: https://html.spec.whatwg.org/multipage/workers.html#import-scripts-into-worker-global-scope
/// 1. If worker global scope's type is "module", throw a TypeError.
/// 2. Let settings object be the current settings object.
/// 3. If urls is empty, return.
/// 4-5. Encoding-parse each url relative to settings object; a failure
///      throws a "SyntaxError" DOMException - before anything is fetched.
/// 6. For each urlRecord: fetch a classic worker-imported script (which
///    throws its "NetworkError"), and run it with rethrow errors true: what
///    it throws aborts these steps and reaches the calling script.
pub fn call_importScripts(instance: *runtime.Instance, urls: []const typedefs.TrustedScriptURLOrUSVString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.NotImplemented;
    const worker_host = @import("html").worker_host;

    // importScripts(...urls) steps 1-2: "Let urlStrings be « »"; for each url,
    // append get trusted type compliant string with TrustedScriptURL, this's
    // relevant global object, url, "WorkerGlobalScope importScripts" and
    // "script".
    const url_allocator = instance.ctx.allocator;
    var url_strings: std.ArrayListUnmanaged([]u8) = .empty;
    defer {
        for (url_strings.items) |u| url_allocator.free(u);
        url_strings.deinit(url_allocator);
    }
    for (urls) |url| {
        const compliant = try @import("dom").trusted_types.compliantStringFor(url_allocator, .script_url, instance, url, "WorkerGlobalScope importScripts");
        errdefer url_allocator.free(compliant);
        try url_strings.append(url_allocator, compliant);
    }

    // Step 1.
    if (internal.worker_type == .module) return error.TypeError;

    // Step 3.
    if (urls.len == 0) return;

    // Steps 2 and 4: relative to the settings object's API base URL - a
    // worker global scope's URL.
    const allocator = instance.ctx.allocator;
    const base_url: []const u8 = if (internal.internal_location) |loc| loc.getHref() else internal.url;
    var records: std.ArrayListUnmanaged([]const u8) = .empty;
    defer {
        for (records.items) |record| allocator.free(record);
        records.deinit(allocator);
    }
    try records.ensureTotalCapacity(allocator, urls.len);
    for (url_strings.items) |url| {
        const base_arg = if (base_url.len > 0)
            webidl.Opt(runtime.USVString).passed(base_url)
        else
            webidl.Opt(runtime.USVString).notPassed();
        const parsed = (try interfaces.URL.call_static_parse(instance, url, base_arg)) orelse
            return error.SyntaxError;
        defer runtime.Instance.deinit(parsed);
        records.appendAssumeCapacity(try interfaces.URL.get_href(parsed));
    }

    // Step 6.
    for (records.items) |record| {
        var script = try worker_host.fetchClassicWorkerImportedScript(instance.ctx, record);
        defer script.deinit();
        try worker_host.runImportedScript(instance.ctx, &script);
    }
}
