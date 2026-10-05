//! Implementation for Window interface
//!
//! Implements the Window interface per HTML Standard §7.2.
//! Spec: https://html.spec.whatwg.org/multipage/window-object.html
//!
//! ## Overview
//!
//! The Window object is the primary global object in the browser environment.
//! It represents a browsing context's active document's Window, and provides
//! access to document, navigation, timers, UI prompts, and more.
//!
//! ## Architecture
//!
//! The Window implementation uses pluggable backends:
//! - BrowsingContext: Manages window relationships (parent, opener, etc.)
//! - UIBackend: Handles alert/confirm/prompt dialogs
//! - AnimationFrameScheduler: Manages requestAnimationFrame callbacks
//! - TimerManager: Handles setTimeout/setInterval (from event_loop)

const std = @import("std");
const log = std.log.scoped(.window);
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const Window = interfaces.Window;

// Import parent class impl for initialization chain
// Window inherits from EventTarget per WebIDL
const EventTargetImpl = @import("EventTarget.zig");

// Import WindowOrWorkerGlobalScope mixin impl for shared global methods

// HTML Window infrastructure modules (html_core - interface-free)
const html_core = @import("html_core");
const BrowsingContext = html_core.window.BrowsingContext;
const UIBackend = html_core.window.UIBackend;
const StubUIBackend = html_core.window.StubUIBackend;
const AnimationFrameScheduler = html_core.window.AnimationFrameScheduler;
const StubFrameTimingBackend = html_core.window.StubFrameTimingBackend;

// requestIdleCallback's idle periods: the event loop's and IdleDeadline's
// halves (src/dom/idle_periods.zig).
const idle_periods = @import("dom").idle_periods;

// Web Storage types for localStorage/sessionStorage
const web_storage = html_core.web_storage;
const WebStorage = web_storage.Storage;
const getLocalStorageBackend = web_storage.getLocalStorage;
const getSessionStorageBackend = web_storage.getSessionStorage;

// Storage WebIDL interface
const StorageImpl = @import("Storage.zig");

// IndexedDB types for window.indexedDB
const storage = @import("storage");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const IDBFactoryBackend = storage.indexeddb.IDBFactory;

// Cache Storage types for window.caches
// TODO: Add service_worker module to impls in build.zig to enable CacheStorage
// const service_worker_cache = @import("service_worker").cache;
// const CacheStorageBackend = service_worker_cache.CacheStorage;

pub const State = Window.State;

/// Whether this interface should have an immutable prototype.
/// Per WebIDL §3.8, global objects and their prototype chain must be immutable.
/// This constant is checked by the V8 interface binding generator.
pub const has_immutable_prototype = true;

pub const ImplError = error{
    NotImplemented,
    WindowClosed,
    SecurityError,
    InvalidAccess,
    InvalidStateError,
    OutOfMemory,
};

/// Internal state for Window implementation
/// Contains private data not exposed via WebIDL attributes.
pub const InternalState = struct {
    /// Allocator for this window's resources
    allocator: Allocator,

    /// The associated browsing context (§7.1)
    browsing_context: *BrowsingContext,

    /// The navigables this window made with open(). It owns their
    /// integrations - freeing one takes its navigable down - and frees them
    /// with itself, as an iframe element frees its own.
    auxiliary_navigables: std.ArrayListUnmanaged(*html_core.IFrameIntegration) = .empty,

    /// Whether we own the browsing context and should free it in deinit.
    /// Set to false when replaceBrowsingContext() assigns an external BC.
    /// This prevents double-free when iframe cleanup also frees the BC.
    owns_browsing_context: bool = true,

    /// Whether this window is closed
    closed: bool = false,

    /// The window's name (target name for links)
    name: []const u8 = "",

    /// The status bar text
    status: []const u8 = "",

    /// UI backend for alert/confirm/prompt
    ui_backend: UIBackend,

    /// Stub UI backend instance (default, can be replaced)
    stub_ui_backend: StubUIBackend,

    /// Animation frame scheduler
    animation_scheduler: ?*AnimationFrameScheduler = null,

    /// Stub frame timing backend (default, can be replaced)
    stub_timing_backend: StubFrameTimingBackend,

    /// The associated document (lazily set)
    document: ?*runtime.Instance = null,

    /// The opener window (if opened via window.open())
    opener: ?*runtime.Instance = null,

    /// Opener as anyopaque for the IDL getter
    opener_any: ?*const anyopaque = null,

    /// Sub-interface instances (lazily created)
    location: ?*runtime.Instance = null,
    history: ?*runtime.Instance = null,
    /// A Navigator this Window made itself (`get_navigator`) is kept by an
    /// edge from the Window's global object (engine.traceChild), as
    /// LocalDOMWindow::Trace visits navigator_ - so are the navigation API,
    /// the CustomElementRegistry, the six BarProps and both Storage objects
    /// below. Each pointer is a native one V8 cannot see; the edge is what
    /// keeps the object it names alive, for exactly as long as the Window's
    /// global object - never a root, so a removed frame's whole heap can go
    /// once nothing else holds it (tmp/plans/frame-realm-tracing-design.md).
    navigator: ?*runtime.Instance = null,
    /// The navigation API ([SameObject]), made on first use and kept alive
    /// for the Window's life the same way.
    navigation: ?*runtime.Instance = null,
    /// The global's Performance: the one the host's page set up made
    /// (`setPerformance`, kept by the realm's `__internal`), or else one
    /// this Window made on first use (`own_performance`).
    performance: ?*runtime.Instance = null,
    /// A Performance this Window made itself (`settingsPerformance`: a
    /// frame's, a navigated window's), traced from the global object for
    /// its whole lifetime, as LocalDOMWindow::Trace visits performance_.
    own_performance: ?struct {
        owner: *runtime.Instance,
        value: *runtime.Instance,
        edge: @import("same_object.zig").Traced = .{ .slot = .{ .name = "performance" } },
    } = null,
    /// The time origin of this window's environment settings object, a
    /// monotonic moment (ns, unsafe: Performance coarsens it). HTML: the
    /// associated Document's load timing info's navigation start time;
    /// recorded when the Window is made, which stands in for it until the
    /// navigation's timing records its start.
    time_origin_ns: i64 = 0,
    /// WebCrypto §10: this global's Crypto, traced for its whole lifetime.
    crypto: ?struct {
        owner: *runtime.Instance,
        value: *runtime.Instance,
        edge: @import("same_object.zig").Traced = .{ .slot = .{ .name = "crypto" } },
    } = null,
    /// Trusted Types 4.1: this global's trusted type policy factory, traced
    /// for its whole lifetime.
    trusted_types: ?struct {
        owner: *runtime.Instance,
        value: *runtime.Instance,
        edge: @import("same_object.zig").Traced = .{ .slot = .{ .name = "trustedTypes" } },
    } = null,
    /// LocalDOMWindow::Trace visits custom_elements_.
    custom_elements: ?*runtime.Instance = null,

    /// The six BarProp objects, each made on first read and kept for the
    /// Window's life.
    locationbar: ?*runtime.Instance = null,
    menubar: ?*runtime.Instance = null,
    personalbar: ?*runtime.Instance = null,
    scrollbars: ?*runtime.Instance = null,
    statusbar: ?*runtime.Instance = null,
    toolbar: ?*runtime.Instance = null,

    /// Screen-related (lazily created)
    screen: ?*runtime.Instance = null,
    visual_viewport: ?*runtime.Instance = null,

    /// requestIdleCallback's lists and identifier.
    /// Spec: https://w3c.github.io/requestidlecallback/#window_extensions
    idle: IdleCallbacks = .{},

    /// Storage instances (lazily created)
    /// HTML Standard § 12.2.2 (sessionStorage), § 12.2.3 (localStorage)
    local_storage: ?*runtime.Instance = null,
    session_storage: ?*runtime.Instance = null,
    /// Both Storage objects are kept for the Window's life - they are its
    /// Document's local and session storage holders - as Blink's
    /// DOMWindowStorage::Trace visits local_storage_ and session_storage_.
    /// Unkept, a collection freed the Storage under these pointers and the
    /// next read wrapped whatever the slab had put there: `sessionStorage`
    /// read undefined.
    local_storage_backend: ?*WebStorage = null,
    session_storage_backend: ?*WebStorage = null,

    /// IndexedDB factory (lazily created)
    /// IndexedDB spec: window.indexedDB getter
    indexeddb_factory: ?*runtime.Instance = null,
    indexeddb_backend: ?*IDBFactoryBackend = null,

    /// Cache storage (lazily created)
    /// Service Worker spec: window.caches getter
    /// TODO: Add service_worker module to impls in build.zig to enable CacheStorage backend
    cache_storage: ?*runtime.Instance = null,
    // cache_storage_backend: ?*CacheStorageBackend = null,

    /// CookieStore instance (lazily created)
    /// Cookie Store spec: window.cookieStore getter
    cookie_store: ?*runtime.Instance = null,

    /// Whether this is a secure context (for SecureContext checks)
    is_secure_context: bool = true,

    /// The origin this window was CREATED with: the page's for a top-level
    /// window, the container's for an iframe. It is the origin its document
    /// inherits when that document has none of its own (about:blank, srcdoc,
    /// javascript:); `effectiveOrigin` is the window's actual origin. Storage
    /// keys still read this one.
    origin: []const u8 = "null",

    /// `effectiveOrigin`'s answer for a document URL with an origin of its
    /// own, and the URL it was derived from; both owned. Recomputed only when
    /// the URL changes, because the cross-origin `document` check asks on every
    /// access from another window.
    derived_origin: ?[]const u8 = null,
    derived_origin_url: ?[]const u8 = null,

    /// Dimensions (defaults, can be updated by platform)
    inner_width: i32 = 1024,
    inner_height: i32 = 768,
    outer_width: i32 = 1024,
    outer_height: i32 = 768,
    screen_x: i32 = 0,
    screen_y: i32 = 0,
    scroll_x: f64 = 0.0,
    scroll_y: f64 = 0.0,
    device_pixel_ratio: f64 = 1.0,

    /// V8 global object that this Window IS bound to (for cross-realm support)
    /// When this is set, `instanceToV8` returns this global directly instead of
    /// creating a new wrapper. This enables `iframe.contentWindow.DOMRectReadOnly`
    /// to work correctly because the global has all interface constructors.
    /// Set by context_manager.createWindowBoundToGlobal().
    bound_v8_global: ?*anyopaque = null,

    /// HTML 6.4.1: the last activation timestamp and the last
    /// history-action activation timestamp, positive infinity until the
    /// first activation notification. Read and written by
    /// src/html/user_activation.zig through dom.user_activation_state.
    user_activation: @import("dom").user_activation_state.Timestamps = .{},

    pub fn init(allocator: Allocator) !InternalState {
        return .{
            .allocator = allocator,
            .browsing_context = try BrowsingContext.initTopLevel(allocator),
            .stub_ui_backend = StubUIBackend.init(.{}),
            .stub_timing_backend = StubFrameTimingBackend.init(),
            .ui_backend = undefined, // Set by caller after init
            .time_origin_ns = @intCast(@import("hr_time").MonotonicClock.unsafeCurrentTime()),
        };
    }

    pub fn deinit(self: *InternalState) void {
        if (self.crypto) |*crypto| crypto.edge.release(crypto.owner);
        if (self.own_performance) |*performance| performance.edge.release(performance.owner);
        if (self.trusted_types) |*factory| factory.edge.release(factory.owner);
        // The children traced from the global object need nothing here: the
        // edges go with it, and the realm's end frees the children.
        // The popups first: each integration ends its navigable's realm (a
        // child of this window's, and already gone if this window's page is
        // being torn down - destroyWindowRealm ends a realm once).
        for (self.auxiliary_navigables.items) |integration| {
            integration.deinit();
            self.allocator.destroy(integration);
        }
        self.auxiliary_navigables.deinit(self.allocator);

        // Clean up browsing context ONLY if we own it.
        // When replaceBrowsingContext() was called, we borrowed an external BC
        // (from iframe integration) which will be cleaned up by the iframe.
        // NOTE: BrowsingContext.deinit() already calls self.allocator.destroy(self)
        // so we only need to call deinit() here.
        if (self.owns_browsing_context) {
            self.browsing_context.deinit();
        }

        // Clean up event handlers

        // Clean up animation scheduler if created
        if (self.animation_scheduler) |scheduler| {
            scheduler.deinit();
        }

        // The idle callbacks normally ended with the window's document
        // (endIdleCallbacks, an unloading document cleanup step, which also
        // cancels their timeouts while the event loop lives). Whatever is
        // left is released here; a timeout's record cannot be: its timer is
        // on a loop that may already be gone.
        self.idle.releaseCallbacks(self.allocator);

        // Clean up storage backends
        if (self.local_storage_backend) |storage_backend| {
            storage_backend.deinit();
            self.allocator.destroy(storage_backend);
        }
        if (self.session_storage_backend) |storage_backend| {
            storage_backend.deinit();
            self.allocator.destroy(storage_backend);
        }

        // NOTE: Do NOT deinit indexeddb_backend here!
        // The backend is owned by the IDBFactory instance (indexeddb_factory),
        // which will be cleaned up via wrapper_cache.deinit → IDBFactory.deinit.
        // If we deinit the backend here AND the IDBFactory also deinits it,
        // we get a double-free. The backend pointer is cached here only for
        // quick access, not for ownership.
        self.indexeddb_backend = null;

        // Clean up Cache storage backend
        // TODO: Enable once service_worker module is available to impls
        // if (self.cache_storage_backend) |backend| {
        //     backend.deinit();
        // }

        // Free name if allocated
        if (self.name.len > 0) {
            self.allocator.free(self.name);
        }

        // Free origin if allocated: never "null", which is always the literal
        // (`setOrigin` keeps it so).
        if (!std.mem.eql(u8, self.origin, "null")) {
            self.allocator.free(self.origin);
        }
        if (self.derived_origin) |o| self.allocator.free(o);
        if (self.derived_origin_url) |u| self.allocator.free(u);

        // Free status if allocated
        if (self.status.len > 0) {
            self.allocator.free(self.status);
        }
    }
};

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

pub fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// Set the Window's origin for storage access.
/// This should be called when the document's origin is established.
pub fn setOrigin(instance: *runtime.Instance, origin: []const u8) !void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    // `internal.origin` is a copy of its own exactly when it is not "null":
    // the default is the literal, and so is every "null" set here. The free
    // below and InternalState.deinit's decide by that. Copying "null" too made
    // a copy they never freed - a frame nested in a sandboxed document gets
    // the opaque origin's "null" (leaks lane, 2026-10-02: 2 per
    // cookies/samesite/sandbox-iframe-nested.https.html run alone).
    const opaque_origin = "null";
    // Copy the origin string since it may be from temporary storage
    const origin_copy: []const u8 = if (std.mem.eql(u8, origin, opaque_origin))
        opaque_origin
    else
        try internal.allocator.dupe(u8, origin);
    // Free the old origin if it was allocated (not "null")
    if (!std.mem.eql(u8, internal.origin, opaque_origin)) {
        internal.allocator.free(internal.origin);
    }
    internal.origin = origin_copy;
}

/// This window's origin: its associated Document's origin.
///
/// HTML "create and initialize a Document object" gives a document fetched
/// from a URL that URL's origin, except that about:blank, about:srcdoc and
/// the result of a javascript: URL inherit their creator's - which is what
/// `internal.origin` holds. A browsing context sandboxed without
/// allow-same-origin is opaque whatever it loads.
///
/// `internal.origin` alone used to be the answer, and for an iframe that was
/// its PARENT's origin even after the frame loaded a document from another
/// origin: a message aimed at the frame's real origin was dropped as a
/// mismatch, one aimed at the parent's was delivered, and the parent could
/// read the frame's document.
///
/// The slice lives until the document's URL next changes; copy it to keep it.
fn effectiveOrigin(instance: *runtime.Instance, internal: *InternalState) []const u8 {
    if (internal.browsing_context.sandbox_flags) |flags| {
        if (flags.sandboxesSameOrigin()) return "null";
    }
    const document = internal.document orelse return internal.origin;
    const url = interfaces.Document.get_URL(document) catch return internal.origin;
    // The getter clones into the document's context allocator.
    defer document.ctx.allocator.free(url);
    if (url.len == 0 or inheritsCreatorOrigin(url)) return internal.origin;

    if (internal.derived_origin_url) |cached_url| {
        if (std.mem.eql(u8, cached_url, url)) return internal.derived_origin orelse internal.origin;
    }

    const parsed = (interfaces.URL.call_static_parse(instance, url, webidl.Opt(runtime.USVString).notPassed()) catch null) orelse
        return internal.origin;
    defer runtime.Instance.deinit(parsed);
    const serialized = interfaces.URL.get_origin(parsed) catch return internal.origin;
    defer parsed.ctx.allocator.free(serialized);

    const origin_copy = internal.allocator.dupe(u8, serialized) catch return internal.origin;
    const url_copy = internal.allocator.dupe(u8, url) catch {
        internal.allocator.free(origin_copy);
        return internal.origin;
    };
    if (internal.derived_origin) |old| internal.allocator.free(old);
    if (internal.derived_origin_url) |old| internal.allocator.free(old);
    internal.derived_origin = origin_copy;
    internal.derived_origin_url = url_copy;
    return origin_copy;
}

/// about:blank, about:srcdoc and a javascript: URL's result take their
/// creator's origin rather than one of their own.
fn inheritsCreatorOrigin(url: []const u8) bool {
    return std.ascii.startsWithIgnoreCase(url, "about:") or std.ascii.startsWithIgnoreCase(url, "javascript:");
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // "Destroy a document" and "unload a document" end the window's idle
    // callbacks and their timeouts (an unloading document cleanup step).
    @import("dom").unloading_cleanup.install(&endIdleCallbacks);
    // Other types reach a window's container through this hook.
    @import("dom").navigable_container.install(.{ .of = &containerOf });
    // A frame's host binds the Window to the global its realm made here.
    @import("dom").window_globals.install(.{ .bind = &setBoundV8Global });
    // The user activation algorithms (src/html/user_activation.zig) keep a
    // window's activation timestamps here.
    @import("dom").user_activation_state.install(.{ .get = &userActivationTimestamps, .set = &setUserActivationTimestamps });
    // The WindowOrWorkerGlobalScope mixin reads a window's settings here.
    @import("dom").global_settings.install(.{
        .owns = &isWindow,
        .origin = &settingsOrigin,
        .is_secure_context = &settingsIsSecureContext,
        .cross_origin_isolated = &settingsCrossOriginIsolated,
        .indexed_db = &settingsIndexedDB,
        .caches = &settingsCaches,
        .performance = &settingsPerformance,
        .time_origin = &settingsTimeOrigin,
        .crypto = &settingsCrypto,
        .trusted_types = &settingsTrustedTypes,
        .cookie_jar = &settingsCookieJar,
        .policy_container = &settingsPolicyContainer,
    });
}

/// Initialize Window instance
/// Creates the instance with a new top-level browsing context.
/// Chains to EventTarget.init() to ensure EventTarget internal state is registered.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {

    // Chain to parent class (EventTarget) to initialize EventTarget internal state
    // This ensures window.addEventListener() works correctly
    const instance = try EventTargetImpl.init(allocator, StateType, vtable, ctx);
    errdefer EventTargetImpl.deinit(instance);

    // Initialize Window's own internal state
    const state = instance.getState(StateType);
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = try InternalState.init(allocator);
    internal.ui_backend = internal.stub_ui_backend.backend();
    state.own._internal = internal;

    return instance;
}

// ============================================================================
// This window's environment settings, for the WindowOrWorkerGlobalScope mixin
// (dom.global_settings).
// ============================================================================

fn isWindow(global: *runtime.Instance) bool {
    return global.stateAs(State) != null;
}

/// dom.user_activation_state: `window`'s activation timestamps.
fn userActivationTimestamps(window: *runtime.Instance) ?@import("dom").user_activation_state.Timestamps {
    if (!isWindow(window)) return null;
    const internal = getInternal(window) orelse return null;
    return internal.user_activation;
}

/// dom.user_activation_state: set `window`'s activation timestamps.
fn setUserActivationTimestamps(window: *runtime.Instance, timestamps: @import("dom").user_activation_state.Timestamps) void {
    if (!isWindow(window)) return;
    const internal = getInternal(window) orelse return;
    internal.user_activation = timestamps;
}

/// The settings object's origin, serialized; the caller owns it.
fn settingsOrigin(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return instance.ctx.allocator.dupe(u8, effectiveOrigin(instance, internal));
}

/// The user agent's cookie jar, which a window reaches through its browsing
/// context (a frame's is its top-level context's).
fn settingsCookieJar(instance: *runtime.Instance) ?*@import("cookiestore").CookieJar {
    const internal = getInternal(instance) orelse return null;
    return internal.browsing_context.cookieJar();
}

/// The settings object's policy container: the window's associated
/// Document's (HTML 7.1.6), reached through dom.policy_containers.
fn settingsPolicyContainer(instance: *runtime.Instance) ?*const @import("fetch").internal.PolicyContainer {
    const internal = getInternal(instance) orelse return null;
    const document = internal.document orelse return null;
    return @import("dom").policy_containers.of(document);
}

fn settingsIsSecureContext(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.is_secure_context;
}

fn settingsCrossOriginIsolated(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.browsing_context.isCrossOriginIsolated();
}

/// This window's IDBFactory, made on first use.
fn settingsIndexedDB(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Return cached instance if available
    if (internal.indexeddb_factory) |factory_instance| {
        return factory_instance;
    }

    // Create the backend IDBFactory. Until the factory takes it over below,
    // it is this call's: the errdefers release it - once. (The factory's
    // failure path used to free it too, and then the errdefer freed it again:
    // a double free on every failed allocation of IDBFactory.init.)
    const backend = internal.allocator.create(IDBFactoryBackend) catch return error.OutOfMemory;
    errdefer internal.allocator.destroy(backend);

    backend.* = IDBFactoryBackend.init(internal.allocator);
    errdefer backend.deinit();
    backend.setStorageKey(internal.origin);

    // Create the WebIDL IDBFactory instance
    const factory_instance = interfaces.IDBFactory.init(internal.allocator, instance.ctx) catch return error.OutOfMemory;

    // Set the backend in the factory's internal state
    const factory_state = factory_instance.getState(interfaces.IDBFactory.State);
    if (factory_state.own._internal) |factory_internal| {
        // The IDBFactory impl creates its own backend, so we need to replace it
        factory_internal.factory.deinit();
        internal.allocator.destroy(factory_internal.factory);
        factory_internal.factory = backend;
    }

    // Cache both
    internal.indexeddb_backend = backend;
    internal.indexeddb_factory = factory_instance;

    return factory_instance;
}

/// This window's CacheStorage, made on first use.
fn settingsCaches(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Return cached instance if available
    if (internal.cache_storage) |cache_storage_instance| {
        return cache_storage_instance;
    }

    // Create the CacheStorage WebIDL instance
    const CacheStorageImpl = @import("CacheStorage.zig");
    const CacheStorage = interfaces.CacheStorage;

    const cache_storage_instance = CacheStorageImpl.init(
        internal.allocator,
        CacheStorage.State,
        &CacheStorage.vtable,
        instance.ctx,
    ) catch {
        return error.OutOfMemory;
    };

    // Cache and return the instance
    internal.cache_storage = cache_storage_instance;
    return cache_storage_instance;
}

/// HR-Time: one Performance per global, reached through the settings hook -
/// the page's (`setPerformance`), or one made on first use and traced from
/// the global. Its time origin is this window's (`settingsTimeOrigin`), not
/// the moment it is made.
fn settingsPerformance(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.performance) |performance| return performance;
    if (internal.own_performance) |own| return own.value;
    const performance = try interfaces.Performance.init(internal.allocator, instance.ctx);
    internal.own_performance = .{ .owner = instance, .value = performance };
    internal.own_performance.?.edge.hold(instance, performance);
    return performance;
}

/// The time origin of this window's settings object (monotonic ns).
fn settingsTimeOrigin(instance: *runtime.Instance) ?i64 {
    const internal = getInternal(instance) orelse return null;
    return internal.time_origin_ns;
}

/// WebCrypto §10: one Crypto per global, reached through the settings hook.
fn settingsCrypto(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.crypto) |crypto| return crypto.value;
    const crypto = try interfaces.Crypto.init(internal.allocator, instance.ctx);
    internal.crypto = .{ .owner = instance, .value = crypto };
    internal.crypto.?.edge.hold(instance, crypto);
    return crypto;
}

/// Trusted Types 4.1: one trusted type policy factory per global, reached
/// through the settings hook.
fn settingsTrustedTypes(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.trusted_types) |factory| return factory.value;
    const factory = try interfaces.TrustedTypePolicyFactory.init(internal.allocator, instance.ctx);
    internal.trusted_types = .{ .owner = instance, .value = factory };
    internal.trusted_types.?.edge.hold(instance, factory);
    return factory;
}

/// Deinitialize Window instance
pub fn deinit(instance: *runtime.Instance) void {
    // The host is freeing the Window: its wrapper must not free it again.
    // The realm's teardown frees the Window before the wrapper cache's, which
    // would otherwise run this deinit a second time.
    engine.platformObjectDestroyed(instance);

    // Clean up Window's own internal state
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        // Clean up [SameObject] sub-interface instances that we own.
        // These might or might not be in the wrapper cache (depends on whether
        // JavaScript accessed them). The cleanup order in wrapper_cache is not
        // guaranteed, so Location might already be cleaned up by the time
        // Window.deinit runs. Check isCleanupStarted to avoid double-free.
        if (internal.location) |loc| {
            // Clean up Location. It handles lifecycle tracking internally
            // to prevent double-free if already cleaned up.
            const LocationImpl = @import("Location.zig");
            LocationImpl.deinit(loc);
        }

        // Clean up History instance if it was lazily created
        if (internal.history) |history_inst| {
            const HistoryImpl = @import("History.zig");
            HistoryImpl.deinit(history_inst);
        }

        // Clean up Document and its entire DOM tree.
        // Per Chromium's pattern: Window.FrameDestroyed() calls Document.Shutdown()
        // which recursively cleans up all child nodes via DetachLayoutTree().
        // This is essential because:
        // 1. DOM nodes created by DomTreeAdapter during parsing may not be in wrapper cache
        // 2. If Document isn't cleaned up explicitly, its children leak
        // 3. Document.deinit() -> Node.deinit() recursively cleans all child nodes
        if (internal.document) |doc| {
            const DocumentImpl = @import("Document.zig");
            log.debug("[Window.deinit] Cleaning up Document {*}", .{doc});
            DocumentImpl.deinit(doc);
            internal.document = null;
            log.debug("[Window.deinit] Document cleanup DONE", .{});
        } else {
            log.debug("[Window.deinit] NO document to clean up", .{});
        }

        internal.deinit();
        // Return the block itself, not just what it points to. `internal.deinit()`
        // releases what the state OWNS; the state struct was staying allocated for
        // the life of the process.
        const Arena = @import("runtime").ArenaAllocator;
        if (Arena.tryGet() catch null) |arena| arena.destroy(InternalState, internal);
        state.own._internal = null;
    }

    // Chain to parent class (EventTarget) to clean up EventTarget internal state
    EventTargetImpl.deinit(instance);
    // NOTE: EventTarget.deinit() does NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

// ============================================================================
// Opener Management Helpers (for window.open() and navigation)
// ============================================================================

/// Set the opener Window for this window.
/// Called when creating an auxiliary browsing context via window.open().
/// Per HTML spec §7.1.5 (creating an auxiliary browsing context):
/// - The new browsing context's opener is set to the opener browsing context
/// - This creates a bidirectional relationship for window.opener access
pub fn setOpener(instance: *runtime.Instance, opener_window: *runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Store the opener Window instance
    internal.opener = opener_window;
    internal.opener_any = @ptrCast(opener_window);

    // Also update the browsing context's opener
    const opener_internal = getInternal(opener_window) orelse return error.InvalidStateError;
    internal.browsing_context.opener = opener_internal.browsing_context;
}

/// Set the opener with noopener semantics.
/// Per HTML spec, when noopener is specified:
/// - The new browsing context is created with disowned=true
/// - window.opener returns null from the start
pub fn setOpenerNoopener(instance: *runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Mark as disowned from creation
    internal.browsing_context.disowned = true;
    internal.opener = null;
    internal.opener_any = null;
}

/// Check if this window has an accessible opener.
/// Returns false if:
/// - No opener was ever set
/// - The opener relationship was disowned
pub fn hasOpener(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.opener != null and !internal.browsing_context.disowned;
}

/// Get the browsing context for this window (for internal use)
pub fn getBrowsingContext(instance: *runtime.Instance) ?*BrowsingContext {
    const internal = getInternal(instance) orelse return null;
    return internal.browsing_context;
}

/// Set the active window on a browsing context (for cross-module use)
/// This is used by context_manager when creating a Window for an existing
/// BrowsingContext from an iframe.
///
/// Parameters:
/// - bc_ptr: Opaque pointer to a BrowsingContext
/// - window_ptr: Opaque pointer to the Window instance to set as active
pub fn setActiveWindowOnBrowsingContext(bc_ptr: *anyopaque, window_ptr: *anyopaque) void {
    const bc: *BrowsingContext = @ptrCast(@alignCast(bc_ptr));
    bc.setActiveWindow(window_ptr);
}

/// Set the V8 global object that this Window IS bound to (for cross-realm support)
/// Called by context_manager.createWindowBoundToGlobal().
pub fn setBoundV8Global(instance: *runtime.Instance, global: *anyopaque) void {
    if (getInternal(instance)) |internal| {
        internal.bound_v8_global = global;
    }
}

/// Get the V8 global object that this Window IS bound to
/// Returns null if this Window was not created via createWindowBoundToGlobal().
pub fn getBoundV8Global(instance: *runtime.Instance) ?*anyopaque {
    const internal = getInternal(instance) orelse return null;
    return internal.bound_v8_global;
}

/// Replace this Window's browsing context with an existing one.
/// This is used when creating a Window for an iframe that already has a browsing context.
///
/// The iframe's browsing context was created when the iframe was inserted into the DOM
/// (via IFrameIntegration.onInsertedIntoDocument). When contentWindow is accessed,
/// a Window is created but it needs to use the iframe's EXISTING browsing context,
/// not create a new one.
///
/// This function:
/// 1. Deinitializes the auto-created browsing context
/// 2. Replaces it with the provided one
/// 3. Sets this Window as the active window on the provided context
///
/// Parameters:
/// - instance: The Window instance
/// - bc_ptr: Opaque pointer to the existing BrowsingContext
pub fn replaceBrowsingContext(instance: *runtime.Instance, bc_ptr: *anyopaque) void {
    const internal = getInternal(instance) orelse return;

    // Deinitialize the auto-created browsing context (created by Window.init)
    // Note: We must deinit it because it was allocated during init and we own it
    if (internal.owns_browsing_context) {
        internal.browsing_context.deinit();
    }

    // Replace with the existing browsing context (owned by iframe integration)
    const existing_bc: *BrowsingContext = @ptrCast(@alignCast(bc_ptr));
    internal.browsing_context = existing_bc;

    // Mark that we DON'T own this browsing context - iframe cleanup will free it
    // This prevents double-free when both Window.deinit and HTMLIFrameElement.deinit run
    internal.owns_browsing_context = false;

    // Set this Window as the active window on the browsing context
    log.debug("[replaceBrowsingContext] BC={*} Window={*} calling setActiveWindow", .{ existing_bc, instance });
    existing_bc.setActiveWindow(@ptrCast(instance));
}

/// Set the document associated with this Window.
/// This is called by browser context initialization after creating the Document.
/// The document must be set before frames[index] can work, as the indexed getter
/// needs to access the document to find iframe elements.
pub fn setDocument(instance: *runtime.Instance, document: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    // The document this one replaces - the initial about:blank, when a
    // navigation reuses its Window (HTML "create and initialize a Document
    // object" step 6) - is unloaded and, never salvageable, destroyed: HTML
    // "destroy a document" step 8 sets its browsing context to null. Its
    // defaultView answers null, the window's edge goes to its successor
    // (Document.setDefaultView), and nothing keeps it for the window: Blink
    // detaches the old document and the collector takes it once script lets
    // it go. (It used to be kept, with a pending-activity hold, until the
    // realm ended.)
    if (internal.document) |previous| if (previous != document) @import("dom").document_browsing_context.clearWindow(previous);
    internal.document = document;
    // A Window's associated Document is its browsing context's active
    // document while the Window is that context's active window.
    if (internal.browsing_context.getActiveWindow() == @as(?*anyopaque, @ptrCast(instance))) {
        internal.browsing_context.setActiveDocument(@ptrCast(document), @ptrCast(instance));
    }
}

/// Set the navigator associated with this Window.
/// This is called by browser context initialization after creating the Navigator.
pub fn setNavigator(instance: *runtime.Instance, navigator: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    internal.navigator = navigator;
}

/// Set the location associated with this Window.
/// This is called by browser context initialization after creating the Location.
pub fn setLocation(instance: *runtime.Instance, location: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    internal.location = location;
}

/// Set the history associated with this Window.
/// This is called by browser context initialization after creating the History.
pub fn setHistory(instance: *runtime.Instance, history: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    internal.history = history;
}

/// Set the performance associated with this Window.
/// This is called by browser context initialization after creating the Performance.
pub fn setPerformance(instance: *runtime.Instance, perf: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    internal.performance = perf;
}

/// Get the WindowProxy for this window
/// Per spec, window.window, window.self, and window.frames all return the WindowProxy.
fn getWindowProxy(instance: *runtime.Instance) typedefs.WindowProxy {
    // For now, WindowProxy is just the window instance pointer
    // In a full implementation, WindowProxy would be a separate object
    // that handles cross-origin access restrictions
    return @ptrCast(instance);
}

// ============================================================================
// Core Window Properties (§7.2.1)
// ============================================================================

/// Getter for window - Returns the WindowProxy object
/// Per spec: The window getter steps are to return this's relevant global object.
pub fn get_window(instance: *runtime.Instance) anyerror!typedefs.WindowProxy {
    return getWindowProxy(instance);
}

/// Getter for self - Same as window
/// Per spec: The self getter steps are to return this's relevant global object.
pub fn get_self(instance: *runtime.Instance) anyerror!typedefs.WindowProxy {
    return getWindowProxy(instance);
}

/// Getter for document
/// Per spec: Returns the Document associated with this window.
///
/// Security: Per HTML spec §7.2.3.1, accessing document cross-origin throws SecurityError.
/// This applies to sandboxed iframes without allow-same-origin which have opaque origins.
pub fn get_document(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // CRITICAL: Cross-origin security check per HTML spec §7.2.3.1
    // "document" is NOT a cross-origin accessible property of Window.
    // If the accessor (current context) is cross-origin with this Window,
    // we must throw SecurityError.
    //
    // This check is essential for sandbox security: sandboxed iframes without
    // allow-same-origin have opaque origins ("null") that never match the parent's
    // origin, so `parent.document` must throw SecurityError.
    //
    // The accessor is the window whose script reads `document`: the
    // incumbent realm's (the realm of the script that made the call - the
    // getter itself runs in this window's realm, so the current realm is not
    // it), or with no script on the stack the current realm's. Neither - an
    // internal call - is allowed below.
    const accessor_window: ?*runtime.Instance = windowOfRealm(engine.incumbentRealm() orelse engine.currentRealm());

    // Safety check: if accessing own document (same Window), always allow.
    // This handles initialization cases where the entered context might not
    // be fully set up, but the access is clearly same-origin (self-access).
    if (accessor_window) |aw| {
        if (aw == instance) return internal.document orelse error.NotImplemented;
        // IsPlatformObjectSameOrigin: the accessor's origin and this window's
        // must be same origin-domain - which document.domain can make two
        // different origins.
        if (!sameOriginDomain(aw, instance)) return error.SecurityError;
    } else if (std.mem.eql(u8, effectiveOrigin(instance, internal), "null")) {
        // No accessor window at all - an internal call - reaches a window
        // with an opaque origin only from itself.
        return error.SecurityError;
    }

    return internal.document orelse error.NotImplemented;
}

/// HTML "same origin-domain" for two windows' origins - their documents'.
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#same-origin-domain
fn sameOriginDomain(a: *runtime.Instance, b: *runtime.Instance) bool {
    const a_internal = getInternal(a) orelse return false;
    const b_internal = getInternal(b) orelse return false;
    const a_origin = effectiveOrigin(a, a_internal);
    const b_origin = effectiveOrigin(b, b_internal);
    // 1. "If A and B are the same opaque origin, then return true." An
    // opaque origin serializes as "null", which does not say which one it
    // is: two different windows are not known to share one.
    if (std.mem.eql(u8, a_origin, "null") or std.mem.eql(u8, b_origin, "null")) return false;
    // 2. "If A and B are both tuple origins, run these substeps:"
    const a_domain = originDomainOf(a, a_internal, 0);
    const b_domain = originDomainOf(b, b_internal, 0);
    // 2.1. "If A and B's schemes are identical, and their domains are
    // identical and non-null, then return true."
    if (a_domain != null and b_domain != null) {
        return std.mem.eql(u8, schemeOf(a_origin), schemeOf(b_origin)) and std.mem.eql(u8, a_domain.?, b_domain.?);
    }
    // 2.2. "Otherwise, if A and B are same origin and their domains are
    // identical and null, then return true."
    if (a_domain == null and b_domain == null) return std.mem.eql(u8, a_origin, b_origin);
    // 3. "Return false."
    return false;
}

/// The domain of the origin of `window`'s document, or null. A document
/// whose origin is its creator's - about:blank, about:srcdoc, a javascript:
/// URL's result (inheritsCreatorOrigin) - shares that origin, and so its
/// domain: setting document.domain in one of the two documents affects both
/// (HTML: the origin is aliased). Its creator's is read - the parent's for a
/// frame, the opener's for a popup. Deviation, stated: the setter run in the
/// aliasing document itself sets only that document's domain.
fn originDomainOf(window: *runtime.Instance, internal: *InternalState, depth: u8) ?[]const u8 {
    const document = internal.document orelse return null;
    if (depth < 16 and documentInheritsCreatorOrigin(document)) {
        const bc = internal.browsing_context;
        if (bc.parent orelse bc.opener) |creator_bc| {
            if (creator_bc.getActiveWindow()) |ptr| {
                const creator: *runtime.Instance = @ptrCast(@alignCast(ptr));
                if (creator != window) {
                    if (getInternal(creator)) |creator_internal| return originDomainOf(creator, creator_internal, depth + 1);
                }
            }
        }
    }
    return @import("dom").document_origin.domain(document);
}

/// Whether `document`'s URL is one whose document takes its creator's origin.
fn documentInheritsCreatorOrigin(document: *runtime.Instance) bool {
    const url = interfaces.Document.get_URL(document) catch return false;
    // The getter clones into the document's context allocator.
    defer document.ctx.allocator.free(url);
    return url.len == 0 or inheritsCreatorOrigin(url);
}

/// The scheme of a tuple origin's serialization.
fn schemeOf(serialized: []const u8) []const u8 {
    return serialized[0 .. std.mem.indexOf(u8, serialized, "://") orelse serialized.len];
}

/// Getter for name - The window's target name
/// Per spec: Returns the browsing context name.
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.browsing_context.target_name);
}

/// Getter for location
/// Per spec: Returns the Location object for this window.
pub fn get_location(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.location) |location| return location;
    // HTML 7.2.1: every Window has a Location object. One the host did not
    // make with the Window is made now, in the Window's realm - its relevant
    // global is this Window (Location.init reads it from the realm record).
    const location = try interfaces.Location.init(internal.allocator, instance.ctx);
    internal.location = location;
    return location;
}

/// Getter for history
/// Per spec: Returns the History object for this window.
/// Lazily creates the History instance on first access.
pub fn get_history(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Return cached instance if already created
    if (internal.history) |history| {
        return history;
    }

    // Lazily create the History instance
    const HistoryImpl = @import("History.zig");
    const History = interfaces.History;
    const history = try HistoryImpl.init(
        internal.allocator,
        HistoryImpl.State,
        &History.vtable,
        instance.ctx,
    );

    // Associate this History with the window, and the window's navigable
    // - whose traversable holds the session history it reads.
    if (HistoryImpl.getInternal(history)) |history_internal| {
        history_internal.window = instance;
        history_internal.browsing_context = internal.browsing_context;
    }

    // Cache for future access
    internal.history = history;
    return history;
}

/// Getter for navigation
/// Per spec: Returns the Navigation object for this window.
///
/// "Each Window has an associated navigation API, which is a Navigation
/// object. Upon creation of the Window object, its navigation API must be set
/// to a new Navigation object created in the Window object's relevant
/// realm." Made on first use here - nothing can observe the difference -
/// and kept by the Window (an edge from its global object), as Blink traces
/// navigation_ from LocalDOMWindow.
pub fn get_navigation(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.navigation) |navigation| return navigation;
    const navigation = try interfaces.Navigation.init(internal.allocator, instance.ctx);
    internal.navigation = navigation;
    engine.traceChild(instance, navigation, .{ .name = "navigation" });
    return navigation;
}

/// Getter for customElements
/// Per spec: Returns the CustomElementRegistry for this window.
/// Lazily creates the registry on first access.
///
/// Until this landed, `internal.custom_elements` was declared and never
/// assigned, so every `window.customElements` access threw NotImplemented and
/// script saw `undefined`. The whole custom elements subsystem - a 625-line
/// registry, a reaction stack, an upgrade path - was unreachable behind it,
/// and WPT reported `Cannot read properties of undefined (reading 'define')`.
///
/// Created with `is_scoped` left false, which is what the window's registry
/// is. `new CustomElementRegistry()` sets that flag instead; the two must not
/// share a construction path.
pub fn get_customElements(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    if (internal.custom_elements) |registry| {
        return registry;
    }

    const CustomElementRegistryImpl = @import("CustomElementRegistry.zig");
    const CustomElementRegistry = interfaces.CustomElementRegistry;
    const registry = try CustomElementRegistryImpl.init(
        internal.allocator,
        CustomElementRegistryImpl.State,
        &CustomElementRegistry.vtable,
        instance.ctx,
    );

    internal.custom_elements = registry;
    engine.traceChild(instance, registry, .{ .name = "customElements" });
    return registry;
}

// ============================================================================
// BarProp Properties (§7.2.2)
// ============================================================================

/// HTML §7.2.2.2: "The locationbar attribute must return the location bar
/// BarProp object" - and each of menubar, personalbar, scrollbars,
/// statusbar and toolbar its own BarProp object - made on first read.
fn barProp(instance: *runtime.Instance, comptime field: []const u8) !*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (@field(internal, field)) |bar| return bar;
    const bar = try interfaces.BarProp.init(instance.ctx.allocator, instance.ctx);
    @field(internal, field) = bar;
    engine.traceChild(instance, bar, .{ .name = field });
    return bar;
}

pub fn get_locationbar(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return barProp(instance, "locationbar");
}

pub fn get_menubar(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return barProp(instance, "menubar");
}

pub fn get_personalbar(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return barProp(instance, "personalbar");
}

pub fn get_scrollbars(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return barProp(instance, "scrollbars");
}

pub fn get_statusbar(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return barProp(instance, "statusbar");
}

pub fn get_toolbar(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return barProp(instance, "toolbar");
}

/// Getter for status - The status bar text
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_status(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.status);
}

// ============================================================================
// Window State Properties
// ============================================================================

/// Getter for closed
/// Per spec: Returns true if the browsing context has been discarded.
pub fn get_closed(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // "Return true if this's navigable is null or its is closing is true;
    // otherwise false."
    const navigable = navigableOf(instance, internal) orelse return true;
    return internal.closed or navigable.is_closing;
}

/// HTML "a Window's navigable": "the navigable whose active document is the
/// Window's associated Document's, or null if there is no such navigable."
/// Null for a Window a navigation replaced - its browsing context's active
/// window is its successor - and for one whose navigable was destroyed: its
/// container removed (BrowsingContext.discard) or an ancestor's, which closes
/// every descendant, or a top-level traversable definitely closed. HTML
/// "destroy a document" sets the document state's document to null, so the
/// navigable has no active document left that is this Window's. Blink's
/// DOMWindow::parent()/top() answer null for a detached frame (no GetFrame()).
/// A browsing context that has no active window yet (a Window being made) is
/// this Window's.
fn navigableOf(instance: *runtime.Instance, internal: *InternalState) ?*BrowsingContext {
    const bc_ptr = @intFromPtr(internal.browsing_context);
    if (bc_ptr == 0 or bc_ptr < 0x1000) return null;
    const bc = internal.browsing_context;
    if (bc.orphaned or bc.is_closed) return null;
    if (bc.getActiveWindow()) |active| {
        if (active != @as(*anyopaque, @ptrCast(instance))) return null;
    }
    return bc;
}

/// Getter for frames - Same as window
/// Per spec: The frames getter steps are to return this's relevant global object.
pub fn get_frames(instance: *runtime.Instance) anyerror!typedefs.WindowProxy {
    return getWindowProxy(instance);
}

/// Getter for length - Number of child browsing contexts
/// Per spec: Returns the number of child navigables.
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // "Return this's associated Document's document-tree child navigables's
    // size." A Window with no navigable has a destroyed document, whose child
    // navigables were destroyed with it - the context's list is its
    // successor's.
    const navigable = navigableOf(instance, internal) orelse return 0;
    return @intCast(navigable.children.items.len);
}

/// Indexed getter for frames[index] access
/// Per HTML spec §7.4.3.1 (WindowProxy [[GetOwnProperty]]):
/// - frames[0] should return first child iframe's contentWindow
/// - Returns null if index >= children.length
///
/// This enables `window.frames[0]`, `window[0]`, etc. to access child browsing contexts.
/// Spec: https://html.spec.whatwg.org/#windowproxy-getownproperty
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    // The document-tree child navigables of this's associated Document: none
    // once it has no navigable (see get_length).
    const navigable = navigableOf(instance, internal) orelse return null;
    const children = navigable.children.items;

    // Out of bounds check
    if (index >= children.len) {
        return null;
    }

    // Get the child browsing context's Window
    const child_ctx = children[index];
    const child_window = child_ctx.getActiveWindow() orelse return null;

    // Cast the InstancePtr (anyopaque) to runtime.Instance
    return @ptrCast(@alignCast(child_window));
}

/// Getter for top - The topmost browsing context
/// Per spec: Returns the WindowProxy of the top-level traversable.
pub fn get_top(instance: *runtime.Instance) anyerror!?typedefs.WindowProxy {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // "1. If this's navigable is null, then return null."
    const navigable = navigableOf(instance, internal) orelse return null;
    // "2. Return this's navigable's top-level traversable's active
    // WindowProxy."
    const top = navigable.getTop();
    if (top == navigable) return getWindowProxy(instance);
    const top_window = top.getActiveWindow() orelse return null;
    return @ptrCast(@alignCast(top_window));
}

/// Getter for opener
/// Per spec: Returns the WindowProxy of the opener browsing context.
pub fn get_opener(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // "1. Let current be this's browsing context. 2. If current is null, then
    // return null." A destroyed document's browsing context is null ("destroy
    // a document" step 8): a Window with no navigable has none.
    if (navigableOf(instance, internal) == null) return runtime.JSValue.jsNull;

    // If disowned, return null
    if (internal.browsing_context.disowned) {
        return runtime.JSValue.jsNull;
    }

    // HTML: the opener is the browsing context's opener browsing context's
    // WindowProxy - so its ACTIVE window, which a navigation of the opener
    // replaces; the Window that called open() may be gone from it.
    if (internal.browsing_context.opener) |opener_bc| {
        if (opener_bc.getActiveWindow()) |active| {
            return runtime.JSValue.fromInstanceAnyopaque(active);
        }
    }

    // Return opener if set - opener is a stored Window instance pointer
    // Use fromInstanceAnyopaque for legacy anyopaque instance pointers
    if (internal.opener_any) |opener| {
        return runtime.JSValue.fromInstanceAnyopaque(@constCast(opener));
    }

    // Return null for no opener
    return runtime.JSValue.jsNull;
}

/// Getter for parent
/// Per spec: Returns the WindowProxy of the parent browsing context.
pub fn get_parent(instance: *runtime.Instance) anyerror!?typedefs.WindowProxy {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // "1. Let navigable be this's navigable. 2. If navigable is null, then
    // return null."
    const navigable = navigableOf(instance, internal) orelse return null;
    // "3. If navigable's parent is not null, then set navigable to
    // navigable's parent. 4. Return navigable's active WindowProxy."
    const parent = navigable.parent orelse return getWindowProxy(instance);
    const parent_window = parent.getActiveWindow() orelse return null;
    return @ptrCast(@alignCast(parent_window));
}

/// Getter for frameElement
/// Per spec: Returns the Element in which this window is nested, if any.
pub fn get_frameElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Steps 1-4: "Let current be this's node navigable. If current is null,
    // then return null. Let container be current's container. If container is
    // null, then return null."
    const container = containerOf(instance) orelse return null;

    // Step 5: "If container's node document's origin is not same
    // origin-domain with the current settings object's origin, then return
    // null." The current settings object is this getter's, the window's own.
    const container_document = (interfaces.Node.get_ownerDocument(container) catch null) orelse return null;
    const container_window = (interfaces.Document.get_defaultView(container_document) catch null) orelse return null;
    const container_internal = getInternal(container_window) orelse return null;
    if (!std.mem.eql(u8, effectiveOrigin(container_window, container_internal), effectiveOrigin(instance, internal))) return null;

    // Step 6: "Return container."
    return container;
}

/// The container of `window`'s navigable (navigable_container's
/// implementation): the element its browsing context records, or null.
fn containerOf(window: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(window) orelse return null;
    const bc_ptr = @intFromPtr(internal.browsing_context);
    if (bc_ptr == 0 or bc_ptr < 0x1000) return null;
    const container = internal.browsing_context.container orelse return null;
    return @ptrCast(@alignCast(container));
}

/// Getter for navigator
/// Per spec: Returns the Navigator object for this window.
///
/// [SameObject]: the page's Window is given its Navigator by the browser
/// context; a frame's or popup's Window - and the Window a navigation left
/// behind, which script in its realm still reaches - makes its own on first
/// use, in its own realm. The Window keeps that one by an edge from its
/// global object (engine.traceChild), as Blink traces navigator_ from
/// LocalDOMWindow: unkept, its weak wrapper would let a collection free the
/// Navigator under this pointer.
pub fn get_navigator(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.navigator) |navigator| return navigator;
    const navigator = try interfaces.Navigator.init(internal.allocator, instance.ctx);
    internal.navigator = navigator;
    engine.traceChild(instance, navigator, .{ .name = "navigator" });
    return navigator;
}

/// Getter for clientInformation - Same as navigator
/// Per spec: Returns the Navigator object (legacy alias).
pub fn get_clientInformation(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return get_navigator(instance);
}

/// Getter for originAgentCluster
/// Per spec: Returns true if this window is in an origin-keyed agent cluster.
pub fn get_originAgentCluster(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    // Default: not origin-keyed
    return false;
}

/// Getter for ondeviceorientation
pub fn get_ondeviceorientation(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ondeviceorientationabsolute
pub fn get_ondeviceorientationabsolute(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ondevicemotion
pub fn get_ondevicemotion(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for viewport
pub fn get_viewport(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for cookieStore
/// Cookie Store spec: Returns the CookieStore object for this window.
/// https://cookiestore.spec.whatwg.org/#dom-window-cookiestore
///
/// The cookieStore attribute is only available in secure contexts (HTTPS, localhost).
pub fn get_cookieStore(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Return cached instance if available (SameObject behavior)
    if (internal.cookie_store) |cookie_store_instance| {
        return cookie_store_instance;
    }

    // Check SecureContext requirement
    if (!internal.is_secure_context) {
        return error.SecurityError;
    }

    // Create the CookieStore WebIDL instance
    const CookieStoreImpl = @import("CookieStore.zig");
    const CookieStore = interfaces.CookieStore;

    const cookie_store_instance = CookieStoreImpl.createForOrigin(
        internal.allocator,
        CookieStore.State,
        &CookieStore.vtable,
        instance.ctx,
        internal.is_secure_context,
    ) catch {
        return error.OutOfMemory;
    };

    // Cache and return the instance
    internal.cookie_store = cookie_store_instance;
    return cookie_store_instance;
}

/// Getter for credentialless
pub fn get_credentialless(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for speechSynthesis
pub fn get_speechSynthesis(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fence
pub fn get_fence(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for documentPictureInPicture
pub fn get_documentPictureInPicture(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for event
/// Getter for event
/// Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-window-event
/// "return this's current event" - the event whose listener is running in this
/// Window's realm (set by EventTarget's inner invoke), else undefined.
pub fn get_event(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const event = EventTargetImpl.currentEvent(instance) orelse return runtime.JSValue.jsUndefined;
    return .{ .instance = event };
}

/// Getter for orientation
pub fn get_orientation(instance: *runtime.Instance) anyerror!i16 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onorientationchange
pub fn get_onorientationchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for sharedStorage
pub fn get_sharedStorage(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for onappinstalled
pub fn get_onappinstalled(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onbeforeinstallprompt
pub fn get_onbeforeinstallprompt(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for external
pub fn get_external(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for screen
/// Per CSSOM View spec: Returns the Screen object for this window.
pub fn get_screen(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Return cached instance if available (SameObject behavior)
    if (internal.screen) |screen_instance| {
        return screen_instance;
    }

    // Create the Screen WebIDL instance
    const ScreenImpl = @import("Screen.zig");
    const Screen = interfaces.Screen;

    const screen_instance = try ScreenImpl.init(
        internal.allocator,
        Screen.State,
        &Screen.vtable,
        instance.ctx,
    );

    // Cache and return the instance
    internal.screen = screen_instance;
    return screen_instance;
}

/// Getter for visualViewport
pub fn get_visualViewport(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

// ============================================================================
// CSSOM View Properties (CSSOM View Module)
// ============================================================================

/// Getter for innerWidth
/// Per spec: Returns the viewport width in CSS pixels.
pub fn get_innerWidth(instance: *runtime.Instance) anyerror!i32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.inner_width;
}

/// Getter for innerHeight
/// Per spec: Returns the viewport height in CSS pixels.
pub fn get_innerHeight(instance: *runtime.Instance) anyerror!i32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.inner_height;
}

/// Getter for scrollX
/// Per spec: Returns the X scroll offset.
pub fn get_scrollX(instance: *runtime.Instance) anyerror!f64 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.scroll_x;
}

/// Getter for pageXOffset - Same as scrollX
/// Per spec: Legacy alias for scrollX.
pub fn get_pageXOffset(instance: *runtime.Instance) anyerror!f64 {
    return get_scrollX(instance);
}

/// Getter for scrollY
/// Per spec: Returns the Y scroll offset.
pub fn get_scrollY(instance: *runtime.Instance) anyerror!f64 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.scroll_y;
}

/// Getter for pageYOffset - Same as scrollY
/// Per spec: Legacy alias for scrollY.
pub fn get_pageYOffset(instance: *runtime.Instance) anyerror!f64 {
    return get_scrollY(instance);
}

/// Getter for screenX
/// Per spec: Returns the X position of the window on the screen.
pub fn get_screenX(instance: *runtime.Instance) anyerror!i32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.screen_x;
}

/// Getter for screenLeft - Same as screenX
/// Per spec: Legacy alias for screenX.
pub fn get_screenLeft(instance: *runtime.Instance) anyerror!i32 {
    return get_screenX(instance);
}

/// Getter for screenY
/// Per spec: Returns the Y position of the window on the screen.
pub fn get_screenY(instance: *runtime.Instance) anyerror!i32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.screen_y;
}

/// Getter for screenTop - Same as screenY
/// Per spec: Legacy alias for screenY.
pub fn get_screenTop(instance: *runtime.Instance) anyerror!i32 {
    return get_screenY(instance);
}

/// Getter for outerWidth
/// Per spec: Returns the width of the window including chrome.
pub fn get_outerWidth(instance: *runtime.Instance) anyerror!i32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.outer_width;
}

/// Getter for outerHeight
/// Per spec: Returns the height of the window including chrome.
pub fn get_outerHeight(instance: *runtime.Instance) anyerror!i32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.outer_height;
}

/// Getter for devicePixelRatio
/// Per spec: Returns the ratio of CSS pixels to physical pixels.
pub fn get_devicePixelRatio(instance: *runtime.Instance) anyerror!f64 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.device_pixel_ratio;
}

/// Getter for launchQueue
pub fn get_launchQueue(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for portalHost
pub fn get_portalHost(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

// =============================================================================
// Event handler IDL attributes (HTML §8.1.8.1)
// =============================================================================
//
// The GlobalEventHandlers and WindowEventHandlers members are inherited
// (impls/GlobalEventHandlers.zig, impls/WindowEventHandlers.zig). These
// helpers are for Window's own - ondevicemotion, onorientationchange, ... -
// whose target is the window, in its event handler map on EventTarget.

fn getEventHandler(instance: *runtime.Instance, name: []const u8) typedefs.EventHandler {
    return @import("EventTarget.zig").eventHandler(typedefs.EventHandler, instance, name);
}

fn setEventHandler(instance: *runtime.Instance, name: []const u8, handler: typedefs.EventHandler) !void {
    try @import("EventTarget.zig").setEventHandler(typedefs.EventHandler, instance, name, handler);
}

/// Set the secure context flag
/// Called by browser context when URL changes to update security state.
/// Per Secure Contexts spec, a context is secure if:
/// - URL scheme is https, wss, or file
/// - URL host is localhost or 127.0.0.1
pub fn setIsSecureContext(instance: *runtime.Instance, is_secure: bool) void {
    if (getInternal(instance)) |internal| {
        internal.is_secure_context = is_secure;
    }
}

/// Check if a URL scheme indicates a secure context
/// Per https://w3c.github.io/webappsec-secure-contexts/
pub fn isSecureScheme(scheme: []const u8) bool {
    return std.mem.eql(u8, scheme, "https") or
        std.mem.eql(u8, scheme, "wss") or
        std.mem.eql(u8, scheme, "file");
}

/// Check if a host is a secure localhost
pub fn isSecureLocalhost(host: []const u8) bool {
    return std.mem.eql(u8, host, "localhost") or
        std.mem.eql(u8, host, "127.0.0.1") or
        std.mem.eql(u8, host, "::1");
}

/// Getter for sessionStorage
/// HTML Standard § 12.2.2
/// Returns the Storage object for this browsing context's session storage area.
pub fn get_sessionStorage(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Return cached instance if available
    if (internal.session_storage) |storage_instance| {
        return storage_instance;
    }

    // Storage "obtain a session storage bottle map": the session storage
    // shed is the top-level traversable's, and in it the storage key - the
    // origin - picks the shelf. So every same-origin document of one tab
    // shares it: a frame and its parent, and the Windows a frame's
    // navigations make one after another. Keyed on the browsing context
    // itself, as it was, each frame had its own. Not modelled, stated: a
    // popup's traversable starting with a copy of its opener's shed.
    const context_id = internal.browsing_context.getTop().id;

    // Create the backend storage for this origin and browsing context
    const backend = internal.allocator.create(WebStorage) catch return error.OutOfMemory;
    errdefer internal.allocator.destroy(backend);

    backend.* = getSessionStorageBackend(internal.allocator, context_id, internal.origin) catch |err| {
        // Note: errdefer above handles cleanup, just return the error
        return switch (err) {
            web_storage.StorageError.SecurityError => error.SecurityError,
            web_storage.StorageError.OutOfMemory => error.OutOfMemory,
            else => error.InvalidStateError,
        };
    };

    // Create the WebIDL Storage instance wrapping the backend
    const storage_instance = StorageImpl.initWithStorage(
        internal.allocator,
        backend,
        false, // Window owns the backend, not the Storage instance
        instance.ctx,
    ) catch {
        // The errdefer above destroys the block; freed here too, it was
        // freed twice.
        backend.deinit();
        return error.OutOfMemory;
    };

    // Cache both
    internal.session_storage_backend = backend;
    internal.session_storage = storage_instance;
    engine.traceChild(instance, storage_instance, .{ .name = "sessionStorage" });

    return storage_instance;
}

/// Getter for localStorage
/// HTML Standard § 12.2.3
/// Returns the Storage object for this origin's local storage area.
pub fn get_localStorage(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Return cached instance if available
    if (internal.local_storage) |storage_instance| {
        return storage_instance;
    }

    // Create the backend storage for this origin
    const backend = internal.allocator.create(WebStorage) catch return error.OutOfMemory;
    errdefer internal.allocator.destroy(backend);

    backend.* = getLocalStorageBackend(internal.allocator, internal.origin) catch |err| {
        // The errdefer above destroys the block. Destroyed here as well, every
        // read in an opaque origin (SecurityError: a sandboxed frame without
        // allow-same-origin) freed it twice.
        return switch (err) {
            web_storage.StorageError.SecurityError => error.SecurityError,
            web_storage.StorageError.OutOfMemory => error.OutOfMemory,
            else => error.InvalidStateError,
        };
    };

    // Create the WebIDL Storage instance wrapping the backend
    const storage_instance = StorageImpl.initWithStorage(
        internal.allocator,
        backend,
        false, // Window owns the backend, not the Storage instance
        instance.ctx,
    ) catch {
        // The errdefer above destroys the block.
        backend.deinit();
        return error.OutOfMemory;
    };

    // Cache both
    internal.local_storage_backend = backend;
    internal.local_storage = storage_instance;
    engine.traceChild(instance, storage_instance, .{ .name = "localStorage" });

    return storage_instance;
}

/// Setter for name - Set the window's target name
/// Per HTML spec: Sets the browsing context name.
/// This is used for targeting links (e.g., target="myframe") and window.open().
pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const str_slice = value.asSlice();
    try internal.browsing_context.setTargetName(str_slice);
}

/// Setter for status - Set the status bar text
/// Per HTML Standard, this is deprecated but must be implemented for spec compliance.
/// Note: In modern browsers, this has no visible effect (the status bar is hidden),
/// but the value must still be stored and retrievable via the getter.
pub fn set_status(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Free existing status if allocated
    if (internal.status.len > 0) {
        internal.allocator.free(internal.status);
    }

    // Store the new status value
    // Duplicate the string since DOMString may be temporary
    const str_slice = value.asSlice();
    internal.status = try internal.allocator.dupe(u8, str_slice);
}

/// Setter for opener
/// Per HTML spec §7.2.1:
/// - Setting window.opener to null disowns the opener relationship
/// - The opener browsing context is no longer accessible
/// - This cannot be undone
///
/// Note: Per spec, setting to non-null values is allowed but has no effect
/// (the attribute is marked as settable but browsers ignore non-null assignments)
pub fn set_opener(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if value represents null
    // In WebIDL `any` type, null is represented by the .null variant
    if (value.isNull()) {
        // Setting opener to null disowns the relationship
        // Per spec: "If the given value is null, then set this's browsing context's
        // disowned to true."
        internal.browsing_context.disown();
        internal.opener = null;
        internal.opener_any = null;
    }
    // Non-null assignments are silently ignored per browser behavior
    // (The attribute is technically settable but browsers don't honor non-null values)
}

/// Setter for ondeviceorientation
pub fn set_ondeviceorientation(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ondeviceorientationabsolute
pub fn set_ondeviceorientationabsolute(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ondevicemotion
pub fn set_ondevicemotion(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onorientationchange
pub fn set_onorientationchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onappinstalled
pub fn set_onappinstalled(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onbeforeinstallprompt
pub fn set_onbeforeinstallprompt(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

// ============================================================================
// Window Operations
// ============================================================================

/// Operation: print
/// Per spec §8.8.4: Triggers the printing dialog.
pub fn call_print(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if window is closed
    if (internal.closed) {
        return; // No-op if window is closed
    }

    // Use the UI backend to show print dialog
    internal.ui_backend.showPrint();
}

/// Operation: confirm
/// Per spec §8.8.2: Shows a confirmation dialog.
pub fn call_confirm(instance: *runtime.Instance, message: webidl.Opt(runtime.DOMString)) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if window is closed
    if (internal.closed) {
        return false; // Return false if window is closed
    }

    // Get message string (default to empty)
    const msg = if (message.wasPassed()) message.getValue().asSlice() else "";

    // Use the UI backend to show confirm dialog
    return internal.ui_backend.showConfirm(msg);
}

/// Operation: postMessage
/// Spec: HTML "window post message steps"
/// https://html.spec.whatwg.org/multipage/web-messaging.html#window-post-message-steps
///
/// The message is serialized NOW (step 7) and delivered by a TASK (step 8),
/// and both halves are observable. A synchronous dispatch fires before a
/// listener added later in the same script exists - and the usual way a page
/// talks to its iframe is `appendChild(iframe)` then
/// `addEventListener("message", ...)`, while Crane loads the iframe inside
/// `appendChild`, so the child posts before its parent has listened. And a
/// message that is not a copy lets the poster change what the receiver reads.
pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue, targetOrigin: runtime.USVString, transfer: webidl.Opt(runtime.JSValue)) anyerror!void {
    _ = transfer; // TODO: step 6 - transferable objects

    if (getInternal(instance) == null) return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    // Step 2: the incumbent settings object. Its global - the posting window,
    // not the target - supplies the event's origin and source (steps 8.2 and
    // 8.3): the iframe's, for `parent.postMessage(...)`.
    const incumbent = engine.incumbentRealm() orelse engine.currentRealm() orelse return error.InvalidStateError;
    const source_window = windowOfRealm(incumbent);
    const source_origin: []const u8 = if (source_window) |sw|
        if (getInternal(sw)) |sw_internal| effectiveOrigin(sw, sw_internal) else "null"
    else
        "null";

    // Steps 3-5.
    const target_origin = try TargetOrigin.resolve(allocator, instance, targetOrigin, source_window, source_origin);
    errdefer target_origin.deinit(allocator);

    // Step 7: StructuredSerializeWithTransfer(message, transfer). Rethrow any
    // exceptions - which the serializer has already thrown, as the spec's
    // DataCloneError or as whatever script threw mid-walk.
    var serialized = try SerializedMessage.serialize(engine.currentRealm() orelse incumbent, allocator, message);
    errdefer serialized.deinit(allocator);

    const origin = try allocator.dupe(u8, source_origin);
    errdefer allocator.free(origin);

    const posted = try allocator.create(PostedMessage);
    posted.* = .{
        .allocator = allocator,
        .target = instance,
        .target_generation = runtime.SlabAllocator.generationOf(instance),
        .target_origin = target_origin,
        .origin = origin,
        .source = source_window,
        .source_generation = if (source_window) |sw| runtime.SlabAllocator.generationOf(sw) else 0,
        .message = serialized,
    };

    // Step 8: queue a global task on the posted message task source given
    // targetWindow - a task whose document is targetWindow's associated
    // Document ("queue a global task"): if that document is not fully active
    // when the task would run - its frame removed - the message is never
    // delivered. The task names the window, so the document asked about is
    // the one the window shows then (runtime.EventLoopTask.document).
    const loop = instance.ctx.getOptionalEventLoop() orelse {
        // No loop to queue on (a context built for tests): the message is
        // still owed, so deliver it now rather than lose it.
        runPostedMessage(posted);
        return;
    };
    loop.queueTask(.{
        .callback = &runPostedMessage,
        .context = posted,
        .drop = &dropPostedMessage,
        .document = instance,
        .document_generation = runtime.SlabAllocator.generationOf(instance),
    });
}

/// Operation: postMessage(message, options)
/// Spec: HTML "The postMessage(message, options) method steps are to run the
/// window post message steps providing this, message, and options" -
/// WindowPostMessageOptions' targetOrigin defaults to "/".
///
/// This overload was never bound until codegen kept overloads, so
/// `postMessage(m, {targetOrigin: "*"})` converted the dictionary to the
/// string "[object Object]" and threw SyntaxError.
pub fn call_postMessage__1(instance: *runtime.Instance, message: runtime.JSValue, options: webidl.Opt(dictionaries.WindowPostMessageOptions)) anyerror!void {
    const target_origin: []const u8 = if (options.was_passed)
        options.value.targetOrigin orelse "/"
    else
        "/";
    // TODO: step 6 - options.transfer, as in the three-argument form.
    return call_postMessage(instance, message, target_origin, webidl.Opt(runtime.JSValue).notPassed());
}

/// What `targetOrigin` names: steps 3-5 of the window post message steps.
const TargetOrigin = union(enum) {
    /// "*": any origin.
    any,
    /// An origin's ASCII serialization. Owned.
    origin: []const u8,

    fn resolve(
        allocator: Allocator,
        target_window: *runtime.Instance,
        target_origin: []const u8,
        incumbent_window: ?*runtime.Instance,
        incumbent_origin: []const u8,
    ) !TargetOrigin {
        if (std.mem.eql(u8, target_origin, "*")) return .any;

        // Step 4: "/" is the incumbent's own origin. An opaque origin
        // serializes as "null" and is same origin only with itself, which a
        // serialization cannot say - except in the case that needs no
        // comparison at all, a window posting to itself.
        if (std.mem.eql(u8, target_origin, "/")) {
            if (std.mem.eql(u8, incumbent_origin, "null") and incumbent_window == target_window) return .any;
            return .{ .origin = try allocator.dupe(u8, incumbent_origin) };
        }

        // Step 5: parse it as a URL and keep only its origin. Failure is a
        // SyntaxError - thrown, where a mismatch below is silent.
        const url = (interfaces.URL.call_static_parse(target_window, target_origin, webidl.Opt(runtime.USVString).notPassed()) catch
            return error.SyntaxError) orelse return error.SyntaxError;
        defer runtime.Instance.deinit(url);
        // The getter clones into the URL's context allocator; this frees it.
        const serialized = try interfaces.URL.get_origin(url);
        defer url.ctx.allocator.free(serialized);
        return .{ .origin = try allocator.dupe(u8, serialized) };
    }

    fn deinit(self: TargetOrigin, allocator: Allocator) void {
        switch (self) {
            .any => {},
            .origin => |o| allocator.free(o),
        }
    }

    /// Step 8.1: does the target document's origin match?
    fn admits(self: TargetOrigin, document_origin: []const u8) bool {
        return switch (self) {
            .any => true,
            // "null" is an opaque origin, same origin with nothing a
            // serialization can name.
            .origin => |o| !std.mem.eql(u8, o, "null") and std.mem.eql(u8, o, document_origin),
        };
    }
};

/// StructuredSerializeWithTransfer's result (step 7), held until the task
/// deserializes it in the target realm (step 8.4).
const SerializedMessage = union(enum) {
    undefined,
    null,
    boolean: bool,
    number: f64,
    /// Owned.
    string: []const u8,
    /// The engine's serialization of an object, OWNED (the allocator).
    serialized: engine.SerializedWithTransfer,

    /// Step 7, in `realm`. Primitives and strings arrive already converted;
    /// an object goes through the engine's serializer, which throws the
    /// DataCloneError itself.
    fn serialize(realm: runtime.Context, allocator: Allocator, value: runtime.JSValue) !SerializedMessage {
        return switch (value) {
            .undefined => .undefined,
            .null => .null,
            .boolean => |b| .{ .boolean = b },
            .number => |n| .{ .number = n },
            .string => |s| .{ .string = try allocator.dupe(u8, s.data) },
            // TODO: step 6 - the transfer list; none is passed yet.
            .handle, .instance => .{ .serialized = try engine.structuredSerializeWithTransfer(realm, value, &.{}, noTransferables, null, allocator) },
        };
    }

    /// Step 8.4, into `realm`. The value is OWNED - a string, or the
    /// engine's - and `createPostMessageEvent` takes it.
    fn deserialize(self: *SerializedMessage, realm: runtime.Context) !runtime.JSValue {
        switch (self.*) {
            .undefined => return runtime.JSValue.jsUndefined,
            .null => return runtime.JSValue.jsNull,
            .boolean => |b| return runtime.JSValue.fromBoolean(b),
            .number => |n| return runtime.JSValue.fromNumber(n),
            .string => |s| {
                self.* = .undefined; // moved into the value
                return .{ .string = .{ .data = s, .owned = true } };
            },
            .serialized => |serialized| {
                const value = try engine.structuredDeserializeWithTransfer(realm, serialized.serialized, serialized.array_buffers);
                return value.take();
            },
        }
    }

    fn deinit(self: *SerializedMessage, allocator: Allocator) void {
        switch (self.*) {
            .string => |s| allocator.free(s),
            .serialized => |*serialized| serialized.deinit(allocator),
            else => {},
        }
        self.* = .undefined;
    }

    /// Release a deserialized value that no event took.
    fn release(allocator: Allocator, value: runtime.JSValue) void {
        switch (value) {
            .string => |s| if (s.owned) allocator.free(s.data),
            .handle => (engine.Owned{ .value = value }).release(),
            else => {},
        }
    }
};

/// No platform object is transferable yet (step 6 is a TODO).
fn noTransferables(_: ?*anyopaque, _: *runtime.Instance) runtime.TransferableState {
    return .not_transferable;
}

/// A posted message waiting for its task: everything step 8 closes over.
///
/// Both windows are held as (address, slab generation), never as bare
/// pointers: nothing keeps either alive while the task is queued, and the slab
/// REUSES a freed Instance's address.
const PostedMessage = struct {
    allocator: Allocator,
    target: *runtime.Instance,
    target_generation: u64,
    target_origin: TargetOrigin,
    /// Step 8.2: the serialization of the incumbent's origin. Owned.
    origin: []const u8,
    /// Step 8.3: the incumbent's window.
    source: ?*runtime.Instance,
    source_generation: u64,
    message: SerializedMessage,

    fn destroy(self: *PostedMessage) void {
        self.target_origin.deinit(self.allocator);
        self.allocator.free(self.origin);
        self.message.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};

/// `Task.drop`: the page ended with the message still queued.
fn dropPostedMessage(context: ?*anyopaque) void {
    const posted: *PostedMessage = @ptrCast(@alignCast(context orelse return));
    posted.destroy();
}

/// Step 8's task.
fn runPostedMessage(context: ?*anyopaque) void {
    const posted: *PostedMessage = @ptrCast(@alignCast(context orelse return));
    defer posted.destroy();

    // The window was collected and its slot reissued: nobody is left to hear it.
    const target = posted.target;
    if (runtime.SlabAllocator.generationOf(target) != posted.target_generation) return;
    const internal = getInternal(target) orelse return;

    // Step 8.1.
    if (!posted.target_origin.admits(effectiveOrigin(target, internal))) return;

    // The task runs in the TARGET's realm, the realm step 8.4 deserializes
    // into. An error means that realm is gone.
    engine.runTaskInRealm(target.ctx, deliverPostedMessage, posted) catch |err| {
        log.debug("posted message not delivered: {}", .{err});
    };
}

/// Steps 8.3-8.7, in the target's realm.
fn deliverPostedMessage(data: ?*anyopaque) void {
    const posted: *PostedMessage = @ptrCast(@alignCast(data.?));
    const target = posted.target;

    // Step 8.3.
    const source: ?*runtime.Instance = if (posted.source) |sw|
        (if (runtime.SlabAllocator.generationOf(sw) == posted.source_generation) sw else null)
    else
        null;

    // Steps 8.4-8.5. A value that will not deserialize is a messageerror.
    const message = posted.message.deserialize(target.ctx) catch {
        fireMessageEvent(target, "messageerror", runtime.JSValue.jsUndefined, posted.origin, source);
        return;
    };

    // Step 8.7.
    fireMessageEvent(target, "message", message, posted.origin, source);
}

/// Fire `event_type` at `target` as a MessageEvent that takes `data`.
fn fireMessageEvent(target: *runtime.Instance, event_type: []const u8, data: runtime.JSValue, origin: []const u8, source: ?*runtime.Instance) void {
    const MessageEventImpl = @import("MessageEvent.zig");
    const event = MessageEventImpl.createPostMessageEvent(target.ctx.allocator, target.ctx, event_type, data, origin, source) catch {
        SerializedMessage.release(target.ctx.allocator, data);
        return;
    };
    const generation = runtime.SlabAllocator.generationOf(event);

    _ = EventTargetImpl.dispatchTrusted(target, event) catch {};

    // Who owns the event now. A GC during the dispatch may already have
    // collected it, once the last listener let go of the wrapper - then its
    // slot has moved on. A listener that kept it left a wrapper in the cache,
    // and V8 frees it when that dies. Only an event nothing ever wrapped is
    // still ours. Freeing it regardless is what this code used to do, and
    // `await new Promise(r => addEventListener("message", r))` then read the
    // event after it was gone.
    if (runtime.SlabAllocator.generationOf(event) != generation) return;
    if (engine.hasWrapper(event)) return;
    runtime.Instance.deinit(event);
}

/// Operation: showDirectoryPicker
pub fn call_showDirectoryPicker(instance: *runtime.Instance, options: webidl.Opt(dictionaries.DirectoryPickerOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: matchMedia
pub fn call_matchMedia(instance: *runtime.Instance, query: typedefs.CSSOMString) anyerror!*runtime.Instance {
    _ = instance;
    _ = query;
    return error.NotImplemented;
}

/// Operation: scroll(options)
/// CSSOM View: "1. If invoked with one argument: ... Normalize non-finite
/// values for left and top dictionary members of options, if present. Let x
/// be the value of the left dictionary member of options, if present, or the
/// viewport's current scroll position on the x axis otherwise. Let y be [the
/// same for top]" - then scroll the viewport to (x, y) and return a promise
/// that settles when the scroll completes.
///
/// Stated: layout is the host's, so no scrolling area bounds the position
/// here beyond its origin, and every scroll is instant - the promise is
/// already resolved.
pub fn call_scroll(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ScrollToOptions)) anyerror!runtime.JSValue {
    const opts: dictionaries.ScrollToOptions = if (options.wasPassed()) options.getValue() else .{ .base = .{} };
    return scrollViewportTo(instance, opts.left, opts.top);
}

/// Operation: scroll(x, y)
/// CSSOM View: "2. If invoked with two arguments: ... Let x and y be the
/// arguments, respectively. Normalize non-finite values for x and y. Let the
/// left dictionary member of options have the value x. Let the top
/// dictionary member of options have the value y."
pub fn call_scroll__1(instance: *runtime.Instance, x: f64, y: f64) anyerror!runtime.JSValue {
    return scrollViewportTo(instance, x, y);
}

/// Operation: scrollTo(options) - "When the scrollTo() method is invoked,
/// the user agent must act as if the scroll() method was invoked with the
/// same arguments."
pub fn call_scrollTo(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ScrollToOptions)) anyerror!runtime.JSValue {
    return call_scroll(instance, options);
}

/// Operation: scrollTo(x, y) - as scroll(x, y).
pub fn call_scrollTo__1(instance: *runtime.Instance, x: f64, y: f64) anyerror!runtime.JSValue {
    return call_scroll__1(instance, x, y);
}

/// CSSOM View "normalize non-finite values": NaN and the infinities become
/// 0.
fn normalizeNonFinite(value: f64) f64 {
    return if (std.math.isFinite(value)) value else 0;
}

/// scroll()'s steps from x and y (null: the current position on that axis):
/// the viewport's scroll position becomes (x, y), and the result is a
/// promise resolved in the current realm.
fn scrollViewportTo(instance: *runtime.Instance, left: ?f64, top: ?f64) !runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // A window whose navigable has gone has no viewport: "If there is no
    // viewport, return a resolved Promise and abort the remaining steps."
    if (!internal.closed) {
        if (left) |x| internal.scroll_x = @max(0, normalizeNonFinite(x));
        if (top) |y| internal.scroll_y = @max(0, normalizeNonFinite(y));
    }
    const realm = engine.currentRealm() orelse instance.ctx;
    return (try engine.createResolvedPromise(realm, runtime.JSValue.jsUndefined)).take();
}

/// Operation: resizeTo
/// Per CSSOM View: Resizes the window to the specified dimensions.
pub fn call_resizeTo(instance: *runtime.Instance, width: i32, height: i32) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if window is closed
    if (internal.closed) {
        return;
    }

    // Update outer dimensions
    internal.outer_width = width;
    internal.outer_height = height;

    // TODO: Notify platform to actually resize the window
}

/// Operation: showSaveFilePicker
pub fn call_showSaveFilePicker(instance: *runtime.Instance, options: webidl.Opt(dictionaries.SaveFilePickerOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: blur
/// Per spec: Removes focus from the window.
pub fn call_blur(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if window is closed
    if (internal.closed) {
        return; // No-op if window is closed
    }

    // TODO: Implement actual blur behavior
    // This would notify the platform to remove focus from the window
}

/// Operation: showOpenFilePicker
pub fn call_showOpenFilePicker(instance: *runtime.Instance, options: webidl.Opt(dictionaries.OpenFilePickerOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: scrollBy(options)
/// CSSOM View: "2. Normalize non-finite values for the left and top
/// dictionary members of options. 3. Add the value of scrollX to the left
/// dictionary member. 4. Add the value of scrollY to the top dictionary
/// member. 5. Act as if the scroll() method was invoked with options as the
/// only argument, and return the resulting promise." An absent member is 0
/// by then: the WebIDL default of neither is given, and adding the current
/// position to it scrolls nowhere on that axis.
pub fn call_scrollBy(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ScrollToOptions)) anyerror!runtime.JSValue {
    const opts: dictionaries.ScrollToOptions = if (options.wasPassed()) options.getValue() else .{ .base = .{} };
    return scrollViewportBy(instance, opts.left orelse 0, opts.top orelse 0);
}

/// Operation: scrollBy(x, y)
/// CSSOM View: "1. If invoked with two arguments: ... Let x and y be the
/// arguments, respectively. Normalize non-finite values for x and y. Let the
/// left dictionary member of options have the value x. Let the top
/// dictionary member of options have the value y." Then as scrollBy(options).
pub fn call_scrollBy__1(instance: *runtime.Instance, x: f64, y: f64) anyerror!runtime.JSValue {
    return scrollViewportBy(instance, x, y);
}

fn scrollViewportBy(instance: *runtime.Instance, dx: f64, dy: f64) !runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return scrollViewportTo(instance, internal.scroll_x + normalizeNonFinite(dx), internal.scroll_y + normalizeNonFinite(dy));
}

/// Operation: releaseEvents
/// Per spec: Legacy no-op method for backwards compatibility.
pub fn call_releaseEvents(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    // No-op per spec
}

/// Operation: alert
/// Per spec §8.8.1: Shows an alert dialog.
/// Note: The IDL has an overload with message parameter; this is the no-argument version.
pub fn call_alert(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if window is closed
    if (internal.closed) {
        return; // No-op if window is closed
    }

    // Show alert with empty message
    internal.ui_backend.showAlert("");
}

/// Operation: focus
/// Per spec: Focuses the window.
pub fn call_focus(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if window is closed
    if (internal.closed) {
        return; // No-op if window is closed
    }

    // TODO: Implement actual focus behavior
    // This would notify the platform to bring the window to front
}

/// Operation: requestIdleCallback
/// Spec: https://w3c.github.io/requestidlecallback/#the-requestidlecallback-method
pub fn call_requestIdleCallback(instance: *runtime.Instance, callback: callbacks.IdleRequestCallback, options: webidl.Opt(dictionaries.IdleRequestOptions)) anyerror!u32 {
    // The binding hands the callback over: take it before anything can fail.
    const function = engine.takeCallbackFunction(@ptrCast(callback));
    // 1. "Let window be this Window object."
    const internal = getInternal(instance) orelse {
        function.release();
        return error.InvalidStateError;
    };
    const idle = &internal.idle;
    // 2-3. "Increment the window's idle callback identifier by one." "Let
    // handle be the current value of window's idle callback identifier."
    idle.identifier +%= 1;
    const handle = idle.identifier;

    // A window whose document is gone has no idle periods (its tasks are
    // not runnable) and no timers: the callback can never run, so it is let
    // go now rather than kept for the window's life.
    if (idle.ended) {
        function.release();
        return handle;
    }

    // 4. "Push callback to the end of window's list of idle request
    // callbacks, associated with handle."
    idle.requests.append(internal.allocator, .{ .handle = handle, .callback = function }) catch |err| {
        function.release();
        return err;
    };
    idle.askForIdlePeriod(instance.ctx);

    // 5-6. "Return handle and then continue running this algorithm
    // asynchronously": "If the timeout property is present in options and
    // has a positive value", wait for it (a timer), then queue "invoke idle
    // callback timeout" (IdleTimeout.fired). Without a timer - a context
    // built for tests - there is no timeout.
    const timeout_ms: u32 = if (options.was_passed) (options.value.timeout orelse 0) else 0;
    if (timeout_ms > 0) {
        if (instance.ctx.getOptionalTimer()) |timer| {
            const entry = &idle.requests.items[idle.requests.items.len - 1];
            entry.timeout = IdleTimeout.arm(internal.allocator, instance.ctx, timer, handle, timeout_ms);
        }
    }
    return handle;
}

/// One idle callback in a window's lists.
const IdleCallbackEntry = struct {
    /// The handle requestIdleCallback returned.
    handle: u32,
    /// OWNED: released once it has run, been cancelled, or its window's
    /// document has gone.
    callback: engine.CallbackFunction,
    /// Its timeout, while the timer is armed or its task queued.
    timeout: ?*IdleTimeout = null,

    /// Let the callback go and cancel its timeout. The entry is out of its
    /// list already.
    fn end(self: IdleCallbackEntry) void {
        if (self.timeout) |timeout| timeout.cancel();
        self.callback.release();
    }
};

/// A Window's requestIdleCallback state ("Window interface extensions").
const IdleCallbacks = struct {
    /// "A list of idle request callbacks", in posting order.
    requests: std.ArrayListUnmanaged(IdleCallbackEntry) = .empty,
    /// "A list of runnable idle callbacks", in posting order.
    runnable: std.ArrayListUnmanaged(IdleCallbackEntry) = .empty,
    /// "An idle callback identifier, which is a number which MUST initially
    /// be zero."
    identifier: u32 = 0,
    /// The window has asked its event loop for an idle period that has not
    /// started yet.
    period_requested: bool = false,
    /// The window's document was unloaded or destroyed: its tasks are not
    /// runnable again (Crane keeps no bfcache), so nothing more is kept.
    ended: bool = false,

    /// Ask the event loop for an idle period, once until it starts.
    fn askForIdlePeriod(self: *IdleCallbacks, realm: runtime.Context) void {
        if (self.period_requested or self.ended) return;
        self.period_requested = true;
        idle_periods.requestIdlePeriod(realm, &startIdlePeriod);
    }

    /// The entry with `handle` in either list, removed from it.
    fn remove(self: *IdleCallbacks, handle: u32) ?IdleCallbackEntry {
        for (self.requests.items, 0..) |entry, i| {
            if (entry.handle == handle) return self.requests.orderedRemove(i);
        }
        for (self.runnable.items, 0..) |entry, i| {
            if (entry.handle == handle) return self.runnable.orderedRemove(i);
        }
        return null;
    }

    /// Every callback in both lists let go, their timeouts cancelled.
    fn end(self: *IdleCallbacks, allocator: Allocator) void {
        // Taken first: a callback's release runs no script, but nothing here
        // may iterate a list it could be changing.
        var requests = self.requests;
        var runnable = self.runnable;
        self.requests = .empty;
        self.runnable = .empty;
        for (requests.items) |entry| entry.end();
        for (runnable.items) |entry| entry.end();
        requests.deinit(allocator);
        runnable.deinit(allocator);
    }

    /// The Window's own end: callbacks released, the lists freed. A timeout
    /// left here is not cancelled (see InternalState.deinit).
    fn releaseCallbacks(self: *IdleCallbacks, allocator: Allocator) void {
        for (self.requests.items) |entry| entry.callback.release();
        for (self.runnable.items) |entry| entry.callback.release();
        self.requests.deinit(allocator);
        self.runnable.deinit(allocator);
        self.requests = .empty;
        self.runnable = .empty;
    }
};

/// The window of `realm`, and its idle callback state, while the realm can
/// still run script.
fn idleCallbacksOf(realm: runtime.Context) ?struct { window: *runtime.Instance, internal: *InternalState } {
    if (!realm.hasEngine()) return null;
    const window = windowOfRealm(realm) orelse return null;
    const internal = getInternal(window) orelse return null;
    return .{ .window = window, .internal = internal };
}

/// "Start an idle period" (steps 2-6), as the window's event loop runs it
/// for each window that asked (dom.idle_periods).
fn startIdlePeriod(realm: runtime.Context, period: idle_periods.Period) void {
    const found = idleCallbacksOf(realm) orelse return;
    const internal = found.internal;
    const idle = &internal.idle;
    idle.period_requested = false;
    if (idle.ended) return;
    // Step 1, "Optionally, if the user agent determines the idle period
    // should be delayed, return": the event loop decided that already.
    // Steps 2-5: "Append all entries from pending_list into run_list
    // preserving order", then "Clear pending_list".
    idle.runnable.appendSlice(internal.allocator, idle.requests.items) catch {
        // Kept where they are, for the next idle period.
        idle.askForIdlePeriod(realm);
        return;
    };
    idle.requests.clearRetainingCapacity();
    // Step 6: "Queue a task on the queue associated with the idle-task task
    // source, which performs the steps defined in the invoke idle callbacks
    // algorithm with window and getDeadline as parameters."
    if (idle.runnable.items.len > 0) InvokeIdleCallbacks.queue(internal.allocator, realm, period);
}

/// The task "invoke idle callbacks algorithm" runs in, on the idle-task task
/// source: the window's realm and its idle period (getDeadline).
const InvokeIdleCallbacks = struct {
    allocator: Allocator,
    realm: runtime.Context,
    period: idle_periods.Period,

    fn queue(allocator: Allocator, realm: runtime.Context, period: idle_periods.Period) void {
        const task = allocator.create(InvokeIdleCallbacks) catch {
            if (idleCallbacksOf(realm)) |found| found.internal.idle.askForIdlePeriod(realm);
            return;
        };
        task.* = .{ .allocator = allocator, .realm = realm, .period = period };
        task.queueSelf();
    }

    fn queueSelf(self: *InvokeIdleCallbacks) void {
        const loop = self.realm.getOptionalEventLoop() orelse {
            // No loop (a context built for tests): no idle periods either.
            self.allocator.destroy(self);
            return;
        };
        loop.queueTask(.{ .callback = &run, .context = self, .drop = &drop });
    }

    fn drop(context: ?*anyopaque) void {
        const self: *InvokeIdleCallbacks = @ptrCast(@alignCast(context orelse return));
        self.allocator.destroy(self);
    }

    /// Spec: https://w3c.github.io/requestidlecallback/#invoke-idle-callbacks-algorithm
    fn run(context: ?*anyopaque) void {
        const self: *InvokeIdleCallbacks = @ptrCast(@alignCast(context orelse return));
        const realm = self.realm;
        const found = idleCallbacksOf(realm) orelse return drop(self);
        const idle = &found.internal.idle;
        if (idle.ended) return drop(self);

        // Step 1, "If the user-agent believes it should end the idle period
        // early due to newly scheduled high-priority work, return": the
        // deadline below already ends it at the next timer.
        // 2. "Let now be the current time."
        const now: i64 = @intCast(clock.monotonicNanos());
        // 3. "If now is less than the result of calling getDeadline and the
        // window's list of runnable idle callbacks is not empty:"
        if (now < idle_periods.deadline(realm, self.period) and idle.runnable.items.len > 0) {
            // 3.1. "Pop the top callback from window's list of runnable idle
            // callbacks." Run in an idle period, its timeout no longer races.
            const entry = idle.runnable.orderedRemove(0);
            if (entry.timeout) |timeout| timeout.cancel();
            // 3.2-3.3. "Let deadlineArg be a new IdleDeadline whose get
            // deadline time algorithm is getDeadline." "Invoke callback with
            // « deadlineArg » and "report"."
            invokeIdleCallback(realm, entry.callback, .{ .period = self.period });
            entry.callback.release();
            // 3.4. "If window's list of runnable idle callbacks is not
            // empty, queue a task which performs the steps in the invoke
            // idle callbacks algorithm with getDeadline and window as
            // parameters and return from this algorithm." The callback may
            // have ended the window (a frame removing itself).
            const after = idleCallbacksOf(realm) orelse return drop(self);
            if (!after.internal.idle.ended and after.internal.idle.runnable.items.len > 0) return self.queueSelf();
            return drop(self);
        }
        // The idle period is over with runnable callbacks left: they run in
        // the next one.
        if (idle.runnable.items.len > 0) idle.askForIdlePeriod(realm);
        drop(self);
    }
};

/// A callback's timeout: "Wait for timeout milliseconds", then "Queue a task
/// on the queue associated with the idle-task task source, which performs
/// the invoke idle callback timeout algorithm, passing handle and window".
///
/// Owned by its timer while armed; by the task once the timer has fired; and
/// freed by whichever ends it - `cancel` when the timer is cleared before it
/// fires, else the task, which finds its callback gone or runs it.
const IdleTimeout = struct {
    allocator: Allocator,
    realm: runtime.Context,
    handle: u32,
    timer: runtime.TimerInterface,
    /// The armed timer; 0 once it has fired.
    id: runtime.TimerId = 0,

    fn arm(allocator: Allocator, realm: runtime.Context, timer: runtime.TimerInterface, handle: u32, timeout_ms: u32) ?*IdleTimeout {
        const self = allocator.create(IdleTimeout) catch return null;
        self.* = .{ .allocator = allocator, .realm = realm, .handle = handle, .timer = timer };
        self.id = timer.setTimeout(timeout_ms, &fired, self);
        if (self.id == 0) {
            allocator.destroy(self);
            return null;
        }
        return self;
    }

    /// Its callback ran in an idle period, was cancelled, or its window
    /// ended: "the idle and timeout callbacks are raced and cancel each
    /// other". A timer that has already fired leaves this to its task.
    fn cancel(self: *IdleTimeout) void {
        if (self.id != 0 and self.timer.clearTimeout(self.id)) self.allocator.destroy(self);
    }

    /// The timer fired (the event loop's timers, no realm entered): queue
    /// the task.
    fn fired(data: ?*anyopaque) void {
        const self: *IdleTimeout = @ptrCast(@alignCast(data orelse return));
        self.id = 0;
        if (!self.realm.hasEngine()) return self.allocator.destroy(self);
        const loop = self.realm.getOptionalEventLoop() orelse return self.allocator.destroy(self);
        loop.queueTask(.{ .callback = &run, .context = self, .drop = &drop });
    }

    fn drop(context: ?*anyopaque) void {
        const self: *IdleTimeout = @ptrCast(@alignCast(context orelse return));
        self.allocator.destroy(self);
    }

    /// Spec: https://w3c.github.io/requestidlecallback/#invoke-idle-callback-timeout-algorithm
    fn run(context: ?*anyopaque) void {
        const self: *IdleTimeout = @ptrCast(@alignCast(context orelse return));
        defer self.allocator.destroy(self);
        const found = idleCallbacksOf(self.realm) orelse return;
        // 1. "Let callback be the result of finding the entry in window's
        // list of idle request callbacks or the list of runnable idle
        // callbacks that is associated with the value given by the handle".
        // 2.1. "Remove callback from both lists."
        const entry = found.internal.idle.remove(self.handle) orelse return;
        // 2.2-2.3. "Let now be the current time." "Let deadlineArg be a new
        // IdleDeadline. Set the get deadline time algorithm associated with
        // deadlineArg to an algorithm returning now and set the timeout
        // associated with deadlineArg to true."
        const now: i64 = @intCast(clock.monotonicNanos());
        // 2.4. "Invoke callback with « deadlineArg » and "report"."
        invokeIdleCallback(self.realm, entry.callback, .{ .timed_out = now });
        entry.callback.release();
    }
};

/// WebIDL "invoke" an IdleRequestCallback with a new IdleDeadline in
/// `realm`, reporting what it throws. `callback` stays the caller's.
fn invokeIdleCallback(realm: runtime.Context, callback: engine.CallbackFunction, deadline: idle_periods.Deadline) void {
    const deadline_arg = idle_periods.createDeadline(realm, deadline) catch |err| {
        log.debug("an idle callback was not invoked: {}", .{err});
        return;
    };
    // Wrapped, the IdleDeadline is its wrapper's; never wrapped, it is still
    // ours to free.
    const generation = runtime.SlabAllocator.generationOf(deadline_arg);
    defer runtime.Instance.releaseIfUnwrapped(deadline_arg, generation);
    const completion = engine.invokeCallbackFunction(realm, &callback, .undefined, &.{.{ .instance = deadline_arg }}, .{
        .report = .{ .report = reportIdleCallbackException, .host = realm },
    }) catch |err| {
        log.debug("an idle callback was not invoked: {}", .{err});
        return;
    };
    switch (completion) {
        inline else => |value| value.release(),
    }
}

/// HTML "report an exception" for the global of the realm the engine names -
/// the callback's associated realm - or else the idle callback's window's
/// (`host`).
fn reportIdleCallbackException(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
    const window_realm: runtime.Context = @ptrCast(@alignCast(host orelse return));
    const realm = info.realm orelse window_realm;
    const record = realm.getRealm() orelse return;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return));
    const extracted: runtime.ErrorInfo = .{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = if (info.error_value == .undefined) null else info.error_value,
    };
    _ = @import("html").report_exception.reportErrorInfo(global, &extracted, .{});
}

/// Window's unloading document cleanup step (dom.unloading_cleanup): the
/// document of `environment`'s window was unloaded or destroyed, so its
/// idle callbacks never run - their tasks are not runnable, and Crane keeps
/// no bfcache to make them so again. They are let go and their timeouts
/// cancelled now, while the event loop that holds the timers lives.
fn endIdleCallbacks(environment: runtime.Context) void {
    const found = idleCallbacksOf(environment) orelse return;
    const idle = &found.internal.idle;
    idle.ended = true;
    idle.end(found.internal.allocator);
}

/// Operation: close
/// HTML §7.2.2.1, the close() method steps.
pub fn call_close(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // "1. Let thisTraversable be this's navigable. 2. If thisTraversable is
    // not a top-level traversable, then return."
    const bc = internal.browsing_context;
    if (bc.parent != null or bc.is_closed) return;
    // "3. If thisTraversable's is closing is true, then return."
    if (bc.is_closing or internal.closed) return;
    // Steps 4-6. Not modelled, stated: step 6's other two conditions - the
    // incumbent global's browsing context familiar with browsingContext,
    // and its navigable allowed by sandboxing to navigate thisTraversable.
    if (!bc.isScriptClosable()) return;
    // Step 6.1: "Set thisTraversable's is closing to true."
    bc.is_closing = true;
    internal.closed = true;
    // Step 6.2: "Queue a task on the DOM manipulation task source to
    // definitely close thisTraversable."
    queueDefinitelyClose(instance);
}

/// A queued "definitely close": the window whose traversable it closes, held
/// as (address, generation).
const CloseTask = struct {
    window: *runtime.Instance,
    generation: u64,
    allocator: std.mem.Allocator,

    fn run(data: ?*anyopaque) void {
        const task: *CloseTask = @ptrCast(@alignCast(data orelse return));
        defer task.allocator.destroy(task);
        if (runtime.SlabAllocator.generationOf(task.window) != task.generation) return;
        engine.runTaskInRealm(task.window.ctx, steps, task.window) catch {};
    }

    fn steps(data: ?*anyopaque) void {
        const window: *runtime.Instance = @ptrCast(@alignCast(data orelse return));
        // "Definitely close" is the navigable machinery's, HTMLIFrameElement's,
        // installed when the first iframe element is made: make one if no
        // page has yet. Nothing sees it.
        const auxiliary_navigables = @import("dom").auxiliary_navigables;
        _ = auxiliary_navigables.definitelyClose(window);
    }
};

fn queueDefinitelyClose(window: *runtime.Instance) void {
    const timer = window.ctx.getOptionalTimer() orelse return;
    const task = window.ctx.allocator.create(CloseTask) catch return;
    task.* = .{ .window = window, .generation = runtime.SlabAllocator.generationOf(window), .allocator = window.ctx.allocator };
    if (timer.setTimeout(0, CloseTask.run, task) == 0) task.allocator.destroy(task);
}

/// Operation: getDigitalGoodsService
pub fn call_getDigitalGoodsService(instance: *runtime.Instance, serviceProvider: runtime.DOMString) anyerror!runtime.JSValue {
    _ = instance;
    _ = serviceProvider;
    return error.NotImplemented;
}

/// Operation: moveBy
/// Per CSSOM View: Moves the window by the specified delta.
pub fn call_moveBy(instance: *runtime.Instance, x: i32, y: i32) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if window is closed
    if (internal.closed) {
        return;
    }

    // Apply delta to screen position
    internal.screen_x += x;
    internal.screen_y += y;

    // TODO: Notify platform to actually move the window
}

/// Operation: getSelection
/// Selection API: "The method must invoke and return the result of
/// getSelection() on this's associated Document."
pub fn call_getSelection(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const document = try interfaces.Window.get_document(instance);
    return interfaces.Document.call_getSelection(document);
}

/// Operation: stop
/// Per spec: Cancels the document loading.
pub fn call_stop(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if window is closed
    if (internal.closed) {
        return; // No-op if window is closed
    }

    // HTML "stop loading" this's navigable, as far as this engine keeps one:
    // step 2's "set the ongoing navigation for navigable to null" informs the
    // navigation API about aborting navigation - which aborts its ongoing
    // navigate event. Not modelled, stated: ending a frame's ongoing fetch
    // and "abort a document" (step 3).
    @import("dom").navigation_api.informAboutAbortingNavigation(instance);
}

/// Operation: resizeBy
/// Per CSSOM View: Resizes the window by the specified delta.
pub fn call_resizeBy(instance: *runtime.Instance, x: i32, y: i32) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if window is closed
    if (internal.closed) {
        return;
    }

    // Apply delta to outer dimensions
    internal.outer_width += x;
    internal.outer_height += y;

    // TODO: Notify platform to actually resize the window
}

/// Operation: open
/// Spec: HTML "window open steps"
/// https://html.spec.whatwg.org/multipage/nav-history-apis.html#window-open-steps
///
/// `_self`, `_parent` and `_top` navigate the navigable they name (step 16.1)
/// through dom.navigables, which for the top-level page runs what this engine
/// can of "navigate" - a fragment navigation and the navigate event.
pub fn call_open(this: *runtime.Instance, url: webidl.Opt(runtime.USVString), target: webidl.Opt(runtime.DOMString), features: webidl.Opt(runtime.DOMString)) anyerror!?typedefs.WindowProxy {
    if ((getInternal(this) orelse return error.InvalidStateError).closed) return null;
    // Step 1: "If the event loop's termination nesting level is nonzero,
    // return null" - no popups from beforeunload, pagehide or unload.
    if (html_core.navigation.termination_nesting.active()) return null;

    // The window open steps never read `this`: every step works from the
    // ENTRY global - the window whose script is running. For
    // `frame.contentWindow.open(url)` called by the page that is the page,
    // not the frame: the page is the opener, `url` resolves against the
    // page's document, and the popup lives, and goes, with the page.
    const instance = entryWindow() orelse this;
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const allocator = internal.allocator;

    // Step 2: "Let sourceDocument be the entry global object's associated
    // Document".
    const source_document = try get_document(instance);

    // Steps 3-4: "Set urlRecord to the result of encoding-parsing a URL given
    // url, relative to sourceDocument"; failure throws a "SyntaxError".
    const url_str: []const u8 = if (url.wasPassed()) url.getValue() else "";
    // Deviation, stated (encoding-parse-utf8): the query is encoded as UTF-8, not with the document's encoding - queued.
    const url_record: ?[]const u8 = if (url_str.len == 0) null else try parseUrlRelativeTo(source_document, url_str, allocator);
    defer if (url_record) |u| allocator.free(u);

    // Step 5: "If target is the empty string, then set target to "_blank"."
    const given_target: []const u8 = if (target.wasPassed()) target.getValue().asSlice() else "";
    const target_str: []const u8 = if (given_target.len == 0) "_blank" else given_target;

    // Steps 6-12: tokenize the features; noreferrer implies noopener.
    const window_features = WindowFeatures.parse(if (features.wasPassed()) features.getValue().asSlice() else "");
    const noopener = window_features.noopener or window_features.noreferrer;

    // Step 13: the rules for choosing a navigable. The keywords name this
    // one (see the deviation above).
    if (std.ascii.eqlIgnoreCase(target_str, "_self") or
        std.ascii.eqlIgnoreCase(target_str, "_parent") or
        std.ascii.eqlIgnoreCase(target_str, "_top"))
    {
        // Step 16.1: "If urlRecord is not null, then navigate targetNavigable
        // to urlRecord using sourceDocument". The navigable containers
        // install the navigation; a page with none makes one to install it.
        if (url_record) |u| {
            const navigables = @import("dom").navigables;
            // The rules start from this's navigable; sourceDocument navigates.
            const this_document = interfaces.Window.get_document(this) catch source_document;
            navigables.navigateByTarget(source_document, .{ .target = target_str, .url = u, .noopener = noopener, .current_document = this_document });
        }
        // Step 18: "Return targetNavigable's active WindowProxy" - this's,
        // its parent's or its top's.
        if (noopener) return null;
        if (std.ascii.eqlIgnoreCase(target_str, "_parent")) return (interfaces.Window.get_parent(this) catch null) orelse getWindowProxy(this);
        if (std.ascii.eqlIgnoreCase(target_str, "_top")) return (interfaces.Window.get_top(this) catch null) orelse getWindowProxy(this);
        return getWindowProxy(this);
    }

    // A name an open popup carries is that popup - any popup of the pages
    // related to this one: the root of the opener chain and every popup
    // opened from it, however deep. A popup's own script calling
    // `opener.open(url, name)` has the popup as the entry global, and the
    // name is one its opener gave.
    // "The rules for choosing a navigable" step 7: an existing navigable by
    // that name is chosen only when noopener is false - with noopener, every
    // open() makes a new one.
    if (!noopener and !std.ascii.eqlIgnoreCase(target_str, "_blank")) {
        // A frame of the source's page carrying the name, first - "find a
        // navigable by target name" looks through every navigable the
        // source is familiar with, and its page's frames are.
        const navigables = @import("dom").navigables;
        const this_document = interfaces.Window.get_document(this) catch source_document;
        if (navigables.findByName(this_document, target_str)) |frame_window| {
            // Step 16.1: navigate it, then (step 18) return its WindowProxy.
            if (url_record) |u| navigables.navigateByTarget(source_document, .{ .target = target_str, .url = u, .current_document = this_document });
            return frame_window;
        }
        var root = instance;
        var hops: usize = 0;
        while (hops < 16) : (hops += 1) {
            const root_internal = getInternal(root) orelse break;
            root = root_internal.opener orelse break;
        }
        if (namedPopup(root, target_str, 0)) |found| {
            // Step 16.1: "If urlRecord is not null, then navigate targetNavigable
            // to urlRecord using sourceDocument, with referrerPolicy and
            // exceptionsEnabled set to true."
            if (url_record) |u| found.integration.navigate(u, .{ .source_document = @ptrCast(source_document) });
            return if (noopener) null else found.window;
        }
    }

    // Step 15: a new top-level traversable, auxiliary unless noopener. The
    // machinery is HTMLIFrameElement's, installed when the first iframe
    // element is made: make one if no page has yet. Script never sees it, so
    // it goes as soon as it has done that.
    const auxiliary_navigables = @import("dom").auxiliary_navigables;
    // Step 15.1: "Set targetNavigable's active browsing context's is popup
    // to the result of checking if a popup window is requested". Deviation,
    // stated, matching Chrome and Safari (window-open-popup-behavior passes
    // 51/51 in both; Firefox follows the text): a window opened with noopener
    // or noreferrer is never a popup, whatever its features.
    const is_popup = window_features.popup and !noopener;
    const created = auxiliary_navigables.create(allocator, @ptrCast(internal.browsing_context), internal.origin, is_popup) orelse return null;
    const integration: *html_core.IFrameIntegration = @ptrCast(@alignCast(created.integration));
    internal.auxiliary_navigables.append(allocator, integration) catch {
        integration.deinit();
        allocator.destroy(integration);
        return error.OutOfMemory;
    };

    // A named target names the new navigable.
    if (!std.ascii.eqlIgnoreCase(target_str, "_blank")) {
        if (integration.browsing_context) |bc| bc.setTargetName(target_str) catch {};
    }

    // Its opener is this window, unless noopener.
    if (noopener) setOpenerNoopener(created.window) catch {} else setOpener(created.window, instance) catch {};

    // Steps 15.3-15.5: navigate it, unless the URL is about:blank - the
    // initial document it already has. "Navigate" fetches in parallel and
    // commits in a later task, so open() returns the window before its page
    // loads, as it must for `w.onload = f` to hear the load.
    if (url_record) |u| {
        if (!std.mem.startsWith(u8, u, "about:blank")) integration.navigate(u, .{ .source_document = @ptrCast(source_document) });
    }

    // Steps 17-18: "If noopener is true or windowType is "new with no
    // opener", then return null. Return targetNavigable's active WindowProxy."
    return if (noopener) null else created.window;
}

const NamedPopup = struct { integration: *html_core.IFrameIntegration, window: *runtime.Instance };

/// An open popup named `name` that `window` opened, or that one of its
/// popups did, depth first. A popup's page is torn down by its opener's, so
/// every window reached here is live.
fn namedPopup(window: *runtime.Instance, name: []const u8, depth: usize) ?NamedPopup {
    if (depth > 16) return null;
    const internal = getInternal(window) orelse return null;
    for (internal.auxiliary_navigables.items) |integration| {
        const bc = integration.browsing_context orelse continue;
        // A popup close() was called on is closing, and targeting passes it
        // by from that moment (close-method.window.js: "window.close()
        // affects name targeting immediately").
        if (bc.is_closed or bc.is_closing) continue;
        const popup: *runtime.Instance = @ptrCast(@alignCast(bc.getActiveWindow() orelse continue));
        if (std.mem.eql(u8, bc.target_name, name)) return .{ .integration = integration, .window = popup };
        if (namedPopup(popup, name, depth + 1)) |found| return found;
    }
    return null;
}

/// The entry global object, when it is a window: the global of the entry
/// realm (engine.entryRealm).
fn entryWindow() ?*runtime.Instance {
    return windowOfRealm(engine.entryRealm());
}

/// `realm`'s global object, when it is a Window.
fn windowOfRealm(realm: ?runtime.Context) ?*runtime.Instance {
    const record = (realm orelse return null).getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    if (global.stateAs(State) == null) return null;
    return global;
}

/// `url` parsed against `document`'s base URL, serialized; owned. Failure is
/// a "SyntaxError".
fn parseUrlRelativeTo(document: *runtime.Instance, url: []const u8, allocator: Allocator) ![]const u8 {
    const base = interfaces.Node.get_baseURI(document) catch "";
    defer if (base.len > 0) document.ctx.allocator.free(base);
    const base_arg = if (base.len > 0)
        webidl.Opt(runtime.USVString).passed(base)
    else
        webidl.Opt(runtime.USVString).notPassed();
    const parsed = (interfaces.URL.call_static_parse(document, url, base_arg) catch null) orelse return error.SyntaxError;
    defer runtime.Instance.deinit(parsed);
    const href = try interfaces.URL.get_href(parsed);
    defer document.ctx.allocator.free(href);
    return allocator.dupe(u8, href);
}

/// HTML "tokenize the features argument" (window.open()), and the three
/// features open() reads from the result.
/// Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-window-open-features-tokenize
const WindowFeatures = struct {
    noopener: bool = false,
    noreferrer: bool = false,
    popup: bool = false,

    const max_features = 32;

    fn parse(features: []const u8) WindowFeatures {
        var names: [max_features][]const u8 = undefined;
        var values: [max_features][]const u8 = undefined;
        var name_bufs: [max_features][32]u8 = undefined;
        var value_bufs: [max_features][32]u8 = undefined;
        var count: usize = 0;

        // Steps 2-3.
        var position: usize = 0;
        while (position < features.len) {
            // 3.3: skip leading separators.
            while (position < features.len and isSeparator(features[position])) position += 1;
            // 3.4: the name, ASCII lowercase; 3.5: normalized.
            const name_start = position;
            while (position < features.len and !isSeparator(features[position])) position += 1;
            const raw_name = features[name_start..position];
            // 3.6: up to the `=`, stopping at a `,` or a non-separator.
            while (position < features.len and features[position] != '=') {
                if (features[position] == ',' or !isSeparator(features[position])) break;
                position += 1;
            }
            // 3.7: the value.
            var raw_value: []const u8 = "";
            if (position < features.len and isSeparator(features[position])) {
                while (position < features.len and isSeparator(features[position])) {
                    if (features[position] == ',') break;
                    position += 1;
                }
                const value_start = position;
                while (position < features.len and !isSeparator(features[position])) position += 1;
                raw_value = features[value_start..position];
            }
            // 3.8: a named feature is recorded, the last value winning.
            if (raw_name.len == 0) continue;
            var name_tmp: [32]u8 = undefined;
            var value_tmp: [32]u8 = undefined;
            const name = normalizeName(lower(raw_name, &name_tmp));
            var slot: usize = count;
            for (names[0..count], 0..) |existing, i| {
                if (std.mem.eql(u8, existing, name)) slot = i;
            }
            if (slot == max_features) continue;
            names[slot] = store(name, &name_bufs[slot]);
            values[slot] = store(lower(raw_value, &value_tmp), &value_bufs[slot]);
            if (slot == count) count += 1;
        }

        const map = Map{ .names = names[0..count], .values = values[0..count] };
        return .{
            .noopener = if (map.get("noopener")) |v| parseBoolean(v) else false,
            .noreferrer = if (map.get("noreferrer")) |v| parseBoolean(v) else false,
            .popup = isPopupRequested(map),
        };
    }

    const Map = struct {
        names: []const []const u8,
        values: []const []const u8,

        fn get(self: Map, name: []const u8) ?[]const u8 {
            for (self.names, self.values) |n, v| {
                if (std.mem.eql(u8, n, name)) return v;
            }
            return null;
        }

        /// "Check if a window feature is set".
        fn isSet(self: Map, name: []const u8, default: bool) bool {
            return if (self.get(name)) |v| parseBoolean(v) else default;
        }
    };

    /// A feature separator: ASCII whitespace, `=` or `,`.
    fn isSeparator(c: u8) bool {
        return std.ascii.isWhitespace(c) or c == '=' or c == ',';
    }

    /// ASCII lowercase into `buf`; a longer token than any feature name is
    /// kept as it is, and matches nothing.
    fn lower(token: []const u8, buf: *[32]u8) []const u8 {
        if (token.len > buf.len) return token;
        return std.ascii.lowerString(buf[0..token.len], token);
    }

    /// `token` kept in `buf` when it fits; a longer one is a slice of the
    /// features string itself, which outlives the parse.
    fn store(token: []const u8, buf: *[32]u8) []const u8 {
        if (token.len > buf.len) return token;
        @memcpy(buf[0..token.len], token);
        return buf[0..token.len];
    }

    /// "Normalizing the feature name": the legacy size and position names.
    fn normalizeName(name: []const u8) []const u8 {
        if (std.mem.eql(u8, name, "screenx")) return "left";
        if (std.mem.eql(u8, name, "screeny")) return "top";
        if (std.mem.eql(u8, name, "innerwidth")) return "width";
        if (std.mem.eql(u8, name, "innerheight")) return "height";
        return name;
    }

    /// "Parse a boolean feature": empty, "yes" or "true" is true; otherwise
    /// the value as an integer, nonzero being true.
    fn parseBoolean(value: []const u8) bool {
        if (value.len == 0 or std.mem.eql(u8, value, "yes") or std.mem.eql(u8, value, "true")) return true;
        return parseInteger(value) != 0;
    }

    /// The rules for parsing integers, 0 on an error.
    fn parseInteger(value: []const u8) i64 {
        var i: usize = 0;
        while (i < value.len and std.ascii.isWhitespace(value[i])) i += 1;
        var sign: i64 = 1;
        if (i < value.len and (value[i] == '-' or value[i] == '+')) {
            if (value[i] == '-') sign = -1;
            i += 1;
        }
        var n: i64 = 0;
        var digits: usize = 0;
        while (i < value.len and std.ascii.isDigit(value[i])) : (i += 1) {
            n = n *| 10 +| @as(i64, value[i] - '0');
            digits += 1;
        }
        return if (digits == 0) 0 else sign * n;
    }

    /// "Check if a popup window is requested".
    fn isPopupRequested(map: Map) bool {
        if (map.names.len == 0) return false;
        if (map.get("popup")) |v| return parseBoolean(v);
        const location = map.isSet("location", false);
        const toolbar = map.isSet("toolbar", false);
        if (!location and !toolbar) return true;
        if (!map.isSet("menubar", false)) return true;
        if (!map.isSet("resizable", true)) return true;
        if (!map.isSet("scrollbars", false)) return true;
        if (!map.isSet("status", false)) return true;
        return false;
    }
};

/// Operation: moveTo
/// Per CSSOM View: Moves the window to the specified position.
pub fn call_moveTo(instance: *runtime.Instance, x: i32, y: i32) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if window is closed
    if (internal.closed) {
        return;
    }

    // Update screen position
    internal.screen_x = x;
    internal.screen_y = y;

    // TODO: Notify platform to actually move the window
}

/// Operation: prompt
/// Per spec §8.8.3: Shows a prompt dialog.
pub fn call_prompt(instance: *runtime.Instance, message: webidl.Opt(runtime.DOMString), default: webidl.Opt(runtime.DOMString)) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if window is closed
    if (internal.closed) {
        return null; // Return null if window is closed
    }

    // Get message and default strings
    const msg = if (message.wasPassed()) message.getValue().asSlice() else "";
    const default_value = if (default.wasPassed()) default.getValue().asSlice() else "";

    // Use the UI backend to show prompt dialog
    const result = internal.ui_backend.showPrompt(msg, default_value);
    if (result) |str| {
        return runtime.DOMString.initInterned(str);
    }
    return null;
}

/// Operation: getComputedStyle
/// Per CSSOM spec: Returns the computed style of an element.
/// https://drafts.csswg.org/cssom/#dom-window-getcomputedstyle
///
/// Returns a CSSStyleDeclaration that reflects computed values based on
/// the element type. This is a minimal implementation for WPT tests.
pub fn call_getComputedStyle(instance: *runtime.Instance, elt: *runtime.Instance, pseudoElt: webidl.Opt(?typedefs.CSSOMString)) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    _ = pseudoElt; // Would be used for pseudo-element computed styles

    // Create a CSSStyleDeclaration instance for the computed style
    // Per CSSOM spec, getComputedStyle returns a live CSSStyleDeclaration
    // that reflects the computed values of an element.
    //
    // We use initForComputedStyle to associate the element with the style
    // declaration, enabling element-type-based default values for properties
    // like 'display'.
    const CSSStyleDeclaration = interfaces.CSSStyleDeclaration;
    const CSSStyleDeclarationImpl = @import("CSSStyleDeclaration.zig");

    const css_instance = try CSSStyleDeclarationImpl.initForComputedStyle(
        internal.allocator,
        CSSStyleDeclaration.State,
        &CSSStyleDeclaration.vtable,
        instance.ctx,
        elt,
    );

    log.debug("[DEBUG] getComputedStyle returning instance={*}\n", .{css_instance});
    return css_instance;
}

/// Operation: cancelAnimationFrame
/// Per spec §8.14.2: Cancels a previously scheduled animation frame callback.
pub fn call_cancelAnimationFrame(instance: *runtime.Instance, handle: u32) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if window is closed
    if (internal.closed) {
        return; // No-op if window is closed
    }

    // Cancel the animation frame if scheduler exists
    if (internal.animation_scheduler) |scheduler| {
        scheduler.cancelAnimationFrame(handle);
    }
}

/// Operation: fetchLater
pub fn call_fetchLater(instance: *runtime.Instance, input: typedefs.RequestInfo, init_data: webidl.Opt(dictionaries.DeferredRequestInit)) anyerror!*runtime.Instance {
    _ = instance;
    _ = input;
    _ = init_data;
    return error.NotImplemented;
}

/// Operation: requestAnimationFrame
/// Per spec §8.14.2: Schedules a callback to be invoked before the next repaint.
///
/// TODO: When fully implementing, the callback MUST be stored as a V8 Global handle
/// to survive past the caller's HandleScope. See:
/// - tmp/analysis/CALLBACK_STORAGE.md for the pattern
/// - src/webidl/impls/WebSocket.zig for example usage of OptionalGlobalHandle
///
/// Implementation requirements:
/// 1. Create Global handle for the FrameRequestCallback
/// 2. Store in animation frame registry with Global handle
/// 3. Dispose Global handle when callback fires or is canceled
pub fn call_requestAnimationFrame(instance: *runtime.Instance, callback: callbacks.FrameRequestCallback) anyerror!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if window is closed
    if (internal.closed) {
        return 0; // Return 0 handle if window is closed
    }

    // Create animation scheduler lazily if not exists
    if (internal.animation_scheduler == null) {
        internal.animation_scheduler = try AnimationFrameScheduler.init(
            internal.allocator,
            internal.stub_timing_backend.backend(),
        );
    }

    // Schedule the callback
    // The callback needs to be wrapped to match our internal signature
    // TODO: Proper callback wrapping - for now return placeholder
    _ = callback;
    return 0; // Placeholder
}

/// Operation: cancelIdleCallback
/// Spec: https://w3c.github.io/requestidlecallback/#the-cancelidlecallback-method
pub fn call_cancelIdleCallback(instance: *runtime.Instance, handle: u32) anyerror!void {
    // 1. "Let window be this Window object."
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // 2-3. "Find the entry in either the window's list of idle request
    // callbacks or list of runnable idle callbacks that is associated with
    // the value handle." "If there is such an entry, remove it from both".
    const entry = internal.idle.remove(handle) orelse return;
    entry.end();
}

/// Operation: captureEvents
/// Per spec: Legacy no-op method for backwards compatibility.
pub fn call_captureEvents(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    // No-op per spec
}

/// Operation: queryLocalFonts
pub fn call_queryLocalFonts(instance: *runtime.Instance, options: webidl.Opt(dictionaries.QueryOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: navigate
pub fn call_navigate(instance: *runtime.Instance, dir: enums.SpatialNavigationDirection) anyerror!void {
    _ = instance;
    _ = dir;
    return error.NotImplemented;
}

/// Operation: getScreenDetails
pub fn call_getScreenDetails(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

// ============================================================================
// Named Property Access Support (for WindowProperties object)
// ============================================================================

// Import Element and Node impls for internal state access
const ElementImpl = @import("Element.zig");
const NodeImpl = @import("Node.zig");
const clock = @import("clock");

/// HTML "named objects" of a Window (§7.2.2.3) that a name attribute makes:
/// "embed, form, img, or object elements that have a name content attribute
/// whose value is name". An iframe's or frame's name is its navigable's target
/// name instead - a document-tree child navigable, which getNamedProperty
/// looks at first - and every HTML element is a named object by its id.
const named_element_types = [_][]const u8{
    "embed",
    "form",
    "img",
    "object",
};

/// Whether an element's name attribute makes it a named object.
fn isNamedElementType(local_name: []const u8) bool {
    for (named_element_types) |t| {
        if (std.ascii.eqlIgnoreCase(local_name, t)) return true;
    }
    return false;
}

/// Get the "name" attribute value from an element, if it has one
fn getElementName(elem_internal: *const ElementImpl.InternalState) ?[]const u8 {
    if (elem_internal.findAttribute(null, "name")) |entry| {
        if (entry.value.len > 0) {
            return entry.value;
        }
    }
    return null;
}

/// Search the document tree for elements matching the given name.
/// Returns the first matching element (or its browsing context for iframe/frame).
fn findNamedElement(document: *runtime.Instance, name: []const u8) ?runtime.JSValue {
    // Traverse tree in tree order (preorder depth-first)
    return findNamedElementRecursive(document, name);
}

fn findNamedElementRecursive(node: *runtime.Instance, target_name: []const u8) ?runtime.JSValue {
    var child = NodeImpl.getFirstChild(node);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            if (ElementImpl.getInternal(c)) |elem_internal| {
                const local_name = elem_internal.local_name.asSlice();

                // An HTML element whose id is the name is a named object -
                // the element itself, an iframe as much as any other: only a
                // navigable's target name makes the property a WindowProxy.
                const elem_id = elem_internal.id.asSlice();
                if (elem_id.len > 0 and std.mem.eql(u8, elem_id, target_name)) {
                    return runtime.JSValue.fromInstance(c);
                }

                // So is an embed, form, img or object element whose name
                // attribute is the name.
                if (isNamedElementType(local_name)) {
                    if (getElementName(elem_internal)) |element_name| {
                        if (std.mem.eql(u8, element_name, target_name)) {
                            return runtime.JSValue.fromInstance(c);
                        }
                    }
                }
            }
        }

        // Recursively search descendants
        if (findNamedElementRecursive(c, target_name)) |found| {
            return found;
        }

        child = NodeImpl.getNextSibling(c);
    }
    return null;
}

/// Check if an element matches the target name (by id or name attribute)
fn elementMatchesName(elem_internal: *const ElementImpl.InternalState, target_name: []const u8) bool {
    // Check id attribute
    const elem_id = elem_internal.id.asSlice();
    if (elem_id.len > 0 and std.mem.eql(u8, elem_id, target_name)) {
        return true;
    }

    // Check name attribute for specific element types
    const local_name = elem_internal.local_name.asSlice();
    if (isNamedElementType(local_name)) {
        if (getElementName(elem_internal)) |element_name| {
            if (std.mem.eql(u8, element_name, target_name)) {
                return true;
            }
        }
    }

    return false;
}

/// Recursively check if document contains an element matching the name
fn hasNamedElementRecursive(node: *runtime.Instance, target_name: []const u8) bool {
    var child = NodeImpl.getFirstChild(node);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            if (ElementImpl.getInternal(c)) |elem_internal| {
                if (elementMatchesName(elem_internal, target_name)) {
                    return true;
                }
            }
        }

        // Recursively search descendants
        if (hasNamedElementRecursive(c, target_name)) {
            return true;
        }

        child = NodeImpl.getNextSibling(c);
    }
    return false;
}

/// Collect all named property names from the document (for enumeration)
fn collectNamedElementNames(node: *runtime.Instance, names: *std.ArrayList(runtime.DOMString), allocator: std.mem.Allocator) !void {
    var child = NodeImpl.getFirstChild(node);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            if (ElementImpl.getInternal(c)) |elem_internal| {
                // Add id if present
                const elem_id = elem_internal.id.asSlice();
                if (elem_id.len > 0) {
                    const name = try runtime.DOMString.initDupe(allocator, elem_id);
                    try names.append(allocator, name);
                }

                // Add name attribute if element type participates
                const local_name = elem_internal.local_name.asSlice();
                if (isNamedElementType(local_name)) {
                    if (getElementName(elem_internal)) |element_name| {
                        const name = try runtime.DOMString.initDupe(allocator, element_name);
                        try names.append(allocator, name);
                    }
                }
            }
        }

        // Recursively collect from descendants
        try collectNamedElementNames(c, names, allocator);

        child = NodeImpl.getNextSibling(c);
    }
}

/// Get a named property by name.
/// This is called by window_properties.zig for the WindowProperties named property getter.
/// Named properties on Window include:
/// - Named elements (elements with id or name attributes)
/// - Child browsing context names (iframe names)
///
/// Per HTML spec §7.4 "Named access on the Window object"
pub fn getNamedProperty(instance: *runtime.Instance, name: []const u8) anyerror!?runtime.JSValue {
    const internal = getInternal(instance) orelse return null;

    log.debug("[getNamedProperty] Looking for name='{s}', children count={d}\n", .{ name, internal.browsing_context.children.items.len });

    // First, check if it's a child browsing context name
    for (internal.browsing_context.children.items, 0..) |child, i| {
        log.debug("[getNamedProperty] Child {d}: target_name='{s}'\n", .{ i, child.target_name });
        if (std.mem.eql(u8, child.target_name, name)) {
            const child_window = child.getActiveWindow() orelse continue;
            log.debug("[getNamedProperty] MATCH! Returning child window\n", .{});
            return runtime.JSValue.fromInstanceAnyopaque(@ptrCast(@alignCast(child_window)));
        }
    }

    // Check document for named elements (elements with matching id or name attributes)
    // The document might be stored in internal.document, OR we might need to get it from the
    // browsing context's active document
    const document: ?*runtime.Instance = internal.document orelse blk: {
        const active_doc_ptr = internal.browsing_context.getActiveDocument() orelse break :blk null;
        break :blk @ptrCast(@alignCast(active_doc_ptr));
    };

    if (document) |doc| {
        if (findNamedElement(doc, name)) |result| {
            return result;
        }
    }

    return null;
}

/// Check if a named property exists.
/// This is called by window_properties.zig for the WindowProperties named property query.
pub fn hasNamedProperty(instance: *runtime.Instance, name: []const u8) bool {
    const internal = getInternal(instance) orelse return false;

    // Check if it's a child browsing context name
    for (internal.browsing_context.children.items) |child| {
        if (std.mem.eql(u8, child.target_name, name)) {
            return true;
        }
    }

    // Check document for named elements
    // Use internal.document if available, otherwise get from browsing context
    const document: ?*runtime.Instance = internal.document orelse blk: {
        const active_doc_ptr = internal.browsing_context.getActiveDocument() orelse break :blk null;
        break :blk @ptrCast(@alignCast(active_doc_ptr));
    };
    if (document) |doc| {
        if (hasNamedElementRecursive(doc, name)) {
            return true;
        }
    }

    return false;
}

/// Get all supported property names.
/// This is called by window_properties.zig for the WindowProperties enumerator.
/// Returns the list of all named properties that can be accessed on the window.
pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) anyerror![]runtime.DOMString {
    const internal = getInternal(instance) orelse return &[_]runtime.DOMString{};

    var names: std.ArrayList(runtime.DOMString) = .empty;
    errdefer {
        for (names.items) |*n| n.deinit(allocator);
        names.deinit(allocator);
    }

    // Add child browsing context names
    for (internal.browsing_context.children.items) |child| {
        if (child.target_name.len > 0) {
            const name = try runtime.DOMString.initDupe(allocator, child.target_name);
            try names.append(allocator, name);
        }
    }

    // Add named elements from document
    // Use internal.document if available, otherwise get from browsing context
    const document: ?*runtime.Instance = internal.document orelse blk: {
        const active_doc_ptr = internal.browsing_context.getActiveDocument() orelse break :blk null;
        break :blk @ptrCast(@alignCast(active_doc_ptr));
    };
    if (document) |doc| {
        try collectNamedElementNames(doc, &names, allocator);
    }

    return names.toOwnedSlice(allocator);
}
