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

    /// The opener Window (if opened via window.open()), as it was when set:
    /// the IDL getter's fallback when the browsing context's opener has no
    /// active window to answer with. Held with its slab generation
    /// (runtime.window_holders.Link), beside a traced edge from this Window
    /// to the opener's WindowProxy when the opener is another realm's
    /// (`opener_slot`) - the proxy is what the getter answers (lane winslot1,
    /// kind 2).
    opener: ?runtime.window_holders.Link = null,

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
    /// The settings object's storage key for non-storage purposes,
    /// serialized (storage.StorageKey.serialize): computed once, on first
    /// use, for the environment the Window's document is
    /// (`settingsStorageKey`), and dropped when its document changes. OWNED.
    storage_key: ?[]u8 = null,

    /// IndexedDB factory (lazily created)
    /// IndexedDB spec: window.indexedDB getter
    indexeddb_factory: ?*runtime.Instance = null,

    /// Service Workers 5.3: this global's CacheStorage, made on first use
    /// and traced for its whole lifetime.
    cache_storage: ?struct {
        owner: *runtime.Instance,
        value: *runtime.Instance,
        edge: @import("same_object.zig").Traced = .{ .slot = .{ .name = "caches" } },
    } = null,

    /// CookieStore instance (lazily created)
    /// Cookie Store spec: window.cookieStore getter
    cookie_store: ?*runtime.Instance = null,

    /// The secure context answer of the window whose page created this
    /// window's browsing context - a popup's opener, noopener or not - taken
    /// when it was made. An about:blank document with no parent inherits it
    /// (WebKit Document::initSecurityContext copies its owner's
    /// m_isSecureContext). Null when nothing created it (`secureContext`).
    creator_is_secure_context: ?bool = null,

    /// The origin this window was CREATED with: the page's for a top-level
    /// window, the container document's for an iframe. It is a fallback only:
    /// the window's origin is its associated Document's (`effectiveOrigin`),
    /// and this copy answers only before the window has a document whose
    /// origin is known. A Window made for a later navigation of the same
    /// navigable is given the navigable's first creation origin, so this goes
    /// stale the moment the frame navigates to another origin - which is why
    /// nothing reads it while the document's origin record can answer.
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
    /// HTML 6.10.2: "Each Window has a close watcher manager." Read and
    /// written by src/html/close_watchers.zig through
    /// dom.close_watcher_manager.
    close_watcher_manager: @import("dom").close_watcher_manager.Manager,
    reporting: @import("dom").reporting.State = .{},
    /// Fetch 2.4: this global's settings object's fetch group - its
    /// in-flight keepalive bytes (dom.keepalive_fetch). Plain data.
    fetch_group: @import("dom").document_fetches.FetchGroup = .{},

    pub fn init(allocator: Allocator, navigables: *html_core.Navigables) !InternalState {
        return .{
            .allocator = allocator,
            .browsing_context = try BrowsingContext.initTopLevel(allocator, navigables),
            .stub_ui_backend = StubUIBackend.init(.{}),
            .stub_timing_backend = StubFrameTimingBackend.init(),
            .ui_backend = undefined, // Set by caller after init
            .time_origin_ns = @intCast(@import("hr_time").MonotonicClock.unsafeCurrentTime()),
            .close_watcher_manager = @import("dom").close_watcher_manager.Manager.init(allocator),
        };
    }

    pub fn deinit(self: *InternalState) void {
        // The close watchers stop being active, and let their owners go.
        self.close_watcher_manager.deinit();
        self.reporting.deinit(self.allocator);
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

        if (self.storage_key) |key| self.allocator.free(key);
        self.storage_key = null;

        // Clean up storage backends
        if (self.local_storage_backend) |storage_backend| {
            storage_backend.deinit();
            self.allocator.destroy(storage_backend);
        }
        if (self.session_storage_backend) |storage_backend| {
            storage_backend.deinit();
            self.allocator.destroy(storage_backend);
        }

        if (self.cache_storage) |*caches| caches.edge.release(caches.owner);

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
/// HTML "set up a window environment settings object": the settings
/// object's origin is the associated Document's origin, which "create and
/// initialize a Document object" decided ("determining the origin"): a
/// fetched document's URL's origin, a new opaque origin when sandboxed, and
/// for about:blank, about:srcdoc and a javascript: URL's result the
/// creator's, the container document's or the initiator's origin itself -
/// which the document's origin record (dom.origin_record) holds, shared.
/// The record is the one source: a frame's srcdoc child nested in a
/// cross-origin document has that document's origin, and an about:blank
/// child of a frame its creator's, whatever window made them
/// (webstorage/localstorage-share-data-unrelated-origins.html passes in
/// Chrome 155, Firefox 158 and Safari 27).
///
/// `internal.origin` - the origin the Window was created with - used to
/// answer for an about: or javascript: URL, and for an iframe that was its
/// PARENT's origin, or for a Window a later navigation made, the navigable's
/// FIRST container's: a srcdoc frame inside a cross-origin frame read the
/// top-level page's storage, and a popup's frame's about:blank children
/// were cross-origin to their own parent. It answers now only for a
/// document whose record has no serialization yet (the top-level page's,
/// until something shares it), and before the window has a document.
///
/// The slice lives while the document holds its record, or until its URL
/// next changes; copy it to keep it.
fn effectiveOrigin(instance: *runtime.Instance, internal: *InternalState) []const u8 {
    const document = internal.document orelse return internal.origin;
    // A Window's origin is its associated Document's: its origin record's,
    // opaque or not, once the record knows its serialization - a document
    // made with a new opaque origin (a network error's, one its response's
    // CSP sandboxes) whatever its URL, and an inheriting document with the
    // origin it shares.
    if (@import("dom").document_origin.record(document)) |record| {
        if (record.serialized) |serialized| return serialized;
    }
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
    @import("dom").window_globals.install(.{
        .bind = &setBoundV8Global,
        .set_document = &setDocument,
        .bound_global = &getBoundV8Global,
        .release_browsing_context = &releaseBrowsingContext,
        .adopt_browsing_context = &replaceBrowsingContext,
        .set_origin = &setOrigin,
    });
    // A hyperlink's or form's target that names no frame: the popups this
    // window keeps, or a new one (the rules for choosing a navigable).
    @import("dom").auxiliary_navigables.installTopLevelChooser(.{ .choose = &chooseTopLevelTraversable });
    // The user activation algorithms (src/html/user_activation.zig) keep a
    // window's activation timestamps here.
    @import("dom").user_activation_state.install(.{ .get = &userActivationTimestamps, .set = &setUserActivationTimestamps });
    // The close watcher algorithms (src/html/close_watchers.zig) keep a
    // window's close watcher manager here.
    @import("dom").close_watcher_manager.install(.{ .of = &closeWatcherManager });
    // The WindowOrWorkerGlobalScope mixin reads a window's settings here.
    @import("dom").global_settings.install(.{
        .owns = &isWindow,
        .origin = &settingsOrigin,
        .origin_record = &settingsOriginRecord,
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
        .referrer_source = &settingsReferrerSource,
        .cookie_url = &settingsCookieUrl,
        .reporting = &settingsReporting,
        .fetch_group = &settingsFetchGroup,
        .prohibits_mixed_security_contexts = &settingsProhibitsMixedSecurityContexts,
        .top_level_site = &settingsTopLevelSite,
        .top_level_origin = &settingsTopLevelOrigin,
        .storage_key = &settingsStorageKey,
    });
}

/// Window's own construction steps: the generated chain runs EventTarget's
/// first, so window.addEventListener() finds EventTarget's state.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    // Initialize Window's own internal state
    const state = instance.getState(State);
    const internal = try runtime.arenaOf(instance).create(InternalState);
    // The Window's own top-level context, on its Browser's list - until a
    // navigable it is shown in replaces it (replaceBrowsingContext).
    const navigables = @import("dom").browser_state.navigablesOf(instance.ctx) orelse return error.NoBrowserScope;
    internal.* = try InternalState.init(allocator, navigables);
    internal.ui_backend = internal.stub_ui_backend.backend();
    state.own._internal = internal;
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

/// dom.close_watcher_manager: `window`'s close watcher manager.
fn closeWatcherManager(window: *runtime.Instance) ?*@import("dom").close_watcher_manager.Manager {
    if (!isWindow(window)) return null;
    const internal = getInternal(window) orelse return null;
    internal.close_watcher_manager.window = window;
    return &internal.close_watcher_manager;
}

/// The settings object's origin, serialized; the caller owns it.
fn settingsOrigin(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return instance.ctx.allocator.dupe(u8, effectiveOrigin(instance, internal));
}

/// The settings object's origin as an object: the associated Document's
/// origin record (borrowed), or null before the window has a document.
fn settingsOriginRecord(instance: *runtime.Instance) ?*@import("dom").origin_record.OriginRecord {
    if (!isWindow(instance)) return null;
    const internal = getInternal(instance) orelse return null;
    const document = internal.document orelse return null;
    return @import("dom").document_origin.record(document);
}

/// Mixed Content 4.3: any authenticated embedding document prohibits
/// mixed content, even when this document's own origin is opaque.
fn settingsProhibitsMixedSecurityContexts(instance: *runtime.Instance) error{OutOfMemory}!bool {
    const internal = getInternal(instance) orelse return false;
    const mixed = @import("fetch").mixed_content;
    // 1. Check this environment settings object's origin.
    if (try mixed.isOriginAuthenticated(instance.ctx.allocator, effectiveOrigin(instance, internal))) return true;
    // Deviation, stated (golden rule 2): an origin made opaque by the
    // document's sandboxed origin browsing context flag is judged by its
    // precursor, the tuple origin of the document's URL, as Blink does
    // (MixedContentChecker::IsMixedContent asks
    // GetOriginOrPrecursorOriginIfOpaque). The text's opaque origin is never
    // potentially trustworthy, which would let an https page under a CSP
    // sandbox load http subresources; Chrome 154, Firefox 157 and Safari 27
    // each pass mixed-content/csp.https.window.html 3/3 (aligned wpt.fyi
    // revision cc74d2669f), whose top-level page is exactly that.
    if (try sandboxedPrecursorIsAuthenticated(internal)) return true;
    // 2.2.1. Check each ancestor navigable's active document origin. This is not
    // isSecureContext: one authenticated ancestor is sufficient.
    const navigable = navigableOf(instance, internal) orelse return false;
    var parent = navigable.parent;
    while (parent) |ancestor| : (parent = ancestor.parent) {
        const active = ancestor.getActiveWindow() orelse continue;
        const global: *runtime.Instance = @ptrCast(@alignCast(active));
        const settings = @import("dom").global_settings.of(global) orelse continue;
        const ancestor_origin = settings.origin(global) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            // An unreadable embedding origin must not authorize a downgrade.
            else => return true,
        };
        defer global.ctx.allocator.free(ancestor_origin);
        if (try mixed.isOriginAuthenticated(instance.ctx.allocator, ancestor_origin)) return true;
    }
    // 3. Does not restrict mixed security contexts.
    return false;
}

/// Whether the window's document is sandboxed into an opaque origin (its
/// active sandboxing flag set has the sandboxed origin browsing context flag)
/// and its URL's origin - the opaque origin's precursor - is potentially
/// trustworthy.
fn sandboxedPrecursorIsAuthenticated(internal: *InternalState) error{OutOfMemory}!bool {
    const document = internal.document orelse return false;
    if (!@import("dom").document_scripts.activeSandboxingFlags(document).origin) return false;
    const url = interfaces.Document.get_URL(document) catch return false;
    defer document.ctx.allocator.free(url);
    const allocator = internal.allocator;
    // An unreadable precursor must not authorize a downgrade.
    const precursor = @import("fetch").internal.origins.serializedOriginOf(allocator, url) catch return true;
    defer allocator.free(precursor);
    return @import("fetch").mixed_content.isOriginAuthenticated(allocator, precursor);
}

/// The user agent's cookie jar, which a window reaches through its browsing
/// context (a frame's is its top-level context's).
fn settingsCookieJar(instance: *runtime.Instance) ?*@import("cookiestore").CookieJar {
    const internal = getInternal(instance) orelse return null;
    return internal.browsing_context.cookieJar();
}

fn settingsReporting(instance: *runtime.Instance) ?*@import("dom").reporting.State {
    const internal = getInternal(instance) orelse return null;
    return &internal.reporting;
}

fn settingsFetchGroup(instance: *runtime.Instance) ?*@import("dom").document_fetches.FetchGroup {
    const internal = getInternal(instance) orelse return null;
    return &internal.fetch_group;
}

/// The settings object's policy container: the window's associated
/// Document's (HTML 7.1.6), reached through dom.policy_containers.
///
/// A container that cannot be found - a Window with no state, or one whose
/// document has no Document state (a Registry entry gone) - answers the
/// static PolicyContainer.unavailable, against which every CSP decision is
/// "Blocked". Null read as "this global keeps none": its requests stayed on
/// "client" and main fetch checked no CSP, and its eval, Function, wasm and
/// Trusted Types checks allowed everything (lane leaks4's report).
///
/// A Window not given a document yet keeps none (null), as before: nothing
/// has delivered a policy to it. HTML has no such Window; Crane makes one
/// while a realm is set up, and tests/v8 realms run script in one (an
/// innerHTML there is not a Trusted Types violation).
fn settingsPolicyContainer(instance: *runtime.Instance) ?*const @import("fetch").internal.PolicyContainer {
    const unavailable = &@import("fetch").internal.PolicyContainer.unavailable;
    const internal = getInternal(instance) orelse return unavailable;
    const document = internal.document orelse return null;
    return @import("dom").policy_containers.of(document) orelse unavailable;
}

/// Referrer Policy 8.3 step 3.1.3: while the document is srcdoc, use its
/// container's node document. Borrow the first non-srcdoc document URL;
/// neither a base element nor the opaque-origin rule changes this walk.
fn settingsReferrerSource(instance: *runtime.Instance) ?[]const u8 {
    var window = instance;
    var source = window.ctx.documentUrl() orelse return null;
    while (std.mem.eql(u8, source, "about:srcdoc") or std.mem.startsWith(u8, source, "about:srcdoc#")) {
        const internal = getInternal(window) orelse break;
        if (internal.document == null) break;
        const navigable = navigableOf(window, internal) orelse break;
        const parent = navigable.parent orelse break;
        const active = parent.getActiveWindow() orelse break;
        const parent_window: *runtime.Instance = @ptrCast(@alignCast(active));
        const parent_internal = getInternal(parent_window) orelse break;
        if (parent_internal.document == null) break;
        const parent_url = parent_window.ctx.documentUrl() orelse break;
        window = parent_window;
        source = parent_url;
    }
    return source;
}

/// The cookie URL (dom.global_settings.cookieUrlOf): the realm's creation
/// URL - its document's URL when it was made, never a same-document change's
/// - walked to the parent's for an about:blank or about:srcdoc document, as
/// Blink (DocumentInit::GetCookieUrl, the owner document's) and WebKit
/// (initSecurityContext, the owner document's cookieURL) inherit it. A
/// top-level about:blank has no creator here: its own, cookie-averse URL.
fn settingsCookieUrl(instance: *runtime.Instance) ?[]const u8 {
    var window = instance;
    var depth: usize = 0;
    while (depth < 64) : (depth += 1) {
        // A window whose realm recorded no URL shows its initial
        // about:blank document (Document.get_URL answers so).
        const url = window.ctx.creationUrl() orelse window.ctx.documentUrl() orelse "about:blank";
        if (!inheritsCookieUrl(url)) return url;
        const internal = getInternal(window) orelse return url;
        const navigable = navigableOf(window, internal) orelse return url;
        const parent = navigable.parent orelse return url;
        const active = parent.getActiveWindow() orelse return url;
        window = @ptrCast(@alignCast(active));
    }
    return null;
}

/// about:blank and about:srcdoc, with any query or fragment: the documents
/// whose cookie URL is their creator's.
fn inheritsCookieUrl(url: []const u8) bool {
    inline for (.{ "about:blank", "about:srcdoc" }) |prefix| {
        if (std.ascii.startsWithIgnoreCase(url, prefix)) {
            const rest = url[prefix.len..];
            if (rest.len == 0 or rest[0] == '#' or rest[0] == '?') return true;
        }
    }
    return false;
}

fn settingsIsSecureContext(instance: *runtime.Instance) bool {
    return secureContext(instance, 0);
}

/// HTML 8.1.3.5 "secure context" for this window's environment settings
/// object, decided as the browsers do (html.secure_context): its document's
/// own URL is potentially trustworthy and its parent's active window is a
/// secure context; about:blank and about:srcdoc take the parent's answer,
/// else the creator's. Decided from the document the window has NOW - a
/// Crane top-level Window keeps its object across its page's loads - so
/// nothing has to set it at each creation path.
fn secureContext(instance: *runtime.Instance, depth: usize) bool {
    const internal = getInternal(instance) orelse return false;
    // The parent's answer, walking up the navigable tree (bounded).
    const parent: ?bool = if (parentWindowOf(internal)) |parent_window|
        (if (depth < 64) secureContext(parent_window, depth + 1) else false)
    else
        null;
    // The getter clones the URL into the document's context allocator.
    const document = internal.document;
    const url: ?[]const u8 = if (document) |d| interfaces.Document.get_URL(d) catch return false else null;
    defer if (url) |owned| document.?.ctx.allocator.free(owned);
    return @import("html").secure_context.ofDocument(instance.ctx.allocator, .{
        .url = url orelse "about:blank",
        .parent = parent,
        .creator = internal.creator_is_secure_context,
    }) catch false;
}

/// The settings object's top-level site (Fetch "determine the network
/// partition key" steps 1-4): its top-level origin - HTML "initialize the
/// document object" gives a child its parent environment's, so the top-level
/// traversable's active window's - obtained as a site (HTML "obtain a site"),
/// serialized and OWNED (`instance.ctx.allocator`). Null when that origin is
/// opaque or not a tuple origin: no partition, so a request bypasses the
/// per-Browser preflight cache and authentication entries (Codex row 44 Q4).
fn settingsTopLevelSite(instance: *runtime.Instance) error{OutOfMemory}!?[]u8 {
    var top = instance;
    var depth: usize = 0;
    while (true) : (depth += 1) {
        const internal = getInternal(top) orelse return null;
        const parent = parentWindowOf(internal) orelse break;
        // Bounded, as the secure-context walk is: a cycle is a bug, not a site.
        if (depth >= 64) return null;
        top = parent;
    }
    const top_internal = getInternal(top) orelse return null;
    const origin = effectiveOrigin(top, top_internal);
    if (origin.len == 0 or std.mem.eql(u8, origin, "null")) return null;
    return @import("html").agent_clusters.siteOf(instance.ctx.allocator, origin) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        // An origin with no host (file:) has no site to key by.
        else => null,
    };
}

/// Storage "obtain a storage key for non-storage purposes" for this window's
/// environment settings object, serialized (storage.StorageKey.serialize):
/// its origin; its top-level origin - the top-level traversable's active
/// window's, as `settingsTopLevelSite` walks to it - obtained as a site,
/// "null" when opaque; and HTML's "has cross-site ancestor"
/// (`hasCrossSiteAncestor`). The browsers' key, not the Storage Standard's
/// origin-only text (golden rule 2: storage.StorageKey says why). A popup is
/// a top-level traversable: its own origin's site, no cross-site ancestor -
/// so an about:blank popup a third-party frame opens is not that frame's
/// partition (localstorage-about-blank-3P-iframe-opens-3P-window). An
/// about:blank or srcdoc document has its creator's origin, and so its
/// container's site.
///
/// Computed once per environment (its top-level origin and ancestors are
/// fixed while its document lives) and kept on the window until its
/// document changes: BORROWED. Null when the window has no state.
fn settingsStorageKey(instance: *runtime.Instance) error{OutOfMemory}!?[]const u8 {
    const internal = getInternal(instance) orelse return null;
    if (internal.storage_key) |key| return key;
    const allocator = internal.allocator;
    const origin = effectiveOrigin(instance, internal);
    // The top-level origin as a site; an opaque one, or one with no host, is
    // "null" (still ineligible for persistent storage).
    const site = (try settingsTopLevelSite(instance)) orelse try instance.ctx.allocator.dupe(u8, "null");
    defer instance.ctx.allocator.free(site);
    var key = storage.StorageKey.initBorrowed(if (origin.len == 0) "null" else origin, site, try hasCrossSiteAncestor(instance));
    if (try @import("dom").global_settings.shareableOriginOf(instance)) |record|
        key.origin_nonce = try record.opaqueNonce(instance.ctx.browserScope());
    if (std.mem.eql(u8, site, "null")) {
        if (topLevelWindowForStorage(instance)) |top| {
            if (try @import("dom").global_settings.shareableOriginOf(top)) |record|
                key.top_level_nonce = try record.opaqueNonce(top.ctx.browserScope());
        }
    }
    internal.storage_key = try key.serialize(allocator);
    return internal.storage_key;
}

fn topLevelWindowForStorage(instance: *runtime.Instance) ?*runtime.Instance {
    var window = instance;
    for (0..64) |_| {
        const internal = getInternal(window) orelse return null;
        window = parentWindowOf(internal) orelse return window;
    }
    return null;
}

/// HTML 8.1.3.2, a window's environment settings object's "has cross-site
/// ancestor" (whatwg/html PR 11133), with its recursion unrolled:
/// "1. If window's navigable's parent is null, then return false. 2-3. If
/// parentDocument's relevant settings object's has cross-site ancestor is
/// true, then return true. 4. If parentDocument's origin is not same site
/// with window's associated Document's origin, then return true. 5. Return
/// false." - true exactly when some window on the way up to the top-level
/// one is cross-site with its parent. Bounded, as the other parent walks.
fn hasCrossSiteAncestor(instance: *runtime.Instance) error{OutOfMemory}!bool {
    var window = instance;
    var depth: usize = 0;
    while (depth < 64) : (depth += 1) {
        const internal = getInternal(window) orelse return false;
        const parent = parentWindowOf(internal) orelse return false;
        const parent_internal = getInternal(parent) orelse return false;
        if (!try sameSiteWindows(parent, parent_internal, window, internal)) return true;
        window = parent;
    }
    // A cycle is a bug, not an ancestor chain: the answer that shares less.
    return true;
}

/// HTML "same site" for two windows' documents' origins: two opaque origins
/// only when they are one origin (one record - dom.origin_record), two tuple
/// origins when their sites are equal (HTML "obtain a site": scheme and
/// registrable domain), an opaque and a tuple origin never.
fn sameSiteWindows(a: *runtime.Instance, a_internal: *InternalState, b: *runtime.Instance, b_internal: *InternalState) error{OutOfMemory}!bool {
    const a_origin = effectiveOrigin(a, a_internal);
    const b_origin = effectiveOrigin(b, b_internal);
    const a_opaque = a_origin.len == 0 or std.mem.eql(u8, a_origin, "null");
    const b_opaque = b_origin.len == 0 or std.mem.eql(u8, b_origin, "null");
    if (a_opaque or b_opaque) {
        if (!(a_opaque and b_opaque)) return false;
        const a_record = @import("dom").global_settings.originRecordOf(a) orelse return false;
        return @import("dom").global_settings.originRecordOf(b) == a_record;
    }
    if (std.mem.eql(u8, a_origin, b_origin)) return true;
    const allocator = a.ctx.allocator;
    const site_of = @import("html").agent_clusters.siteOf;
    const a_site = site_of(allocator, a_origin) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return false,
    };
    defer allocator.free(a_site);
    const b_site = site_of(allocator, b_origin) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return false,
    };
    defer allocator.free(b_site);
    return std.ascii.eqlIgnoreCase(a_site, b_site);
}

/// Permissions 5.1 step 5: the top-level traversable's active document's
/// origin. Use the settings origin, including inherited about:blank origins.
fn settingsTopLevelOrigin(instance: *runtime.Instance) error{OutOfMemory}!?[]u8 {
    const internal = getInternal(instance) orelse return null;
    const top_bc = internal.browsing_context.getTop();
    const top: *runtime.Instance = @ptrCast(@alignCast(top_bc.getActiveWindow() orelse return null));
    const top_internal = getInternal(top) orelse return null;
    const origin = effectiveOrigin(top, top_internal);
    if (origin.len == 0 or std.mem.eql(u8, origin, "null")) return null;
    return try instance.ctx.allocator.dupe(u8, origin);
}

/// The active window of the parent of this window's navigable; null for a
/// top-level traversable.
fn parentWindowOf(internal: *InternalState) ?*runtime.Instance {
    const bc_ptr = @intFromPtr(internal.browsing_context);
    if (bc_ptr == 0 or bc_ptr < 0x1000) return null;
    const parent = internal.browsing_context.parent orelse return null;
    const active = parent.getActiveWindow() orelse return null;
    return @ptrCast(@alignCast(active));
}

fn settingsCrossOriginIsolated(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.browsing_context.isCrossOriginIsolated();
}

/// This window's IDBFactory, made on first use. Its databases are the
/// Browser's (the IndexedDB server, a BrowserScope supplement), shared with
/// every same-origin frame, worker and tab of the Browser.
fn settingsIndexedDB(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.indexeddb_factory) |factory_instance| return factory_instance;
    const factory_instance = try interfaces.IDBFactory.init(internal.allocator, instance.ctx);
    internal.indexeddb_factory = factory_instance;
    return factory_instance;
}

/// This window's CacheStorage, made on first use.
fn settingsCaches(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    if (internal.cache_storage) |caches| return caches.value;
    const caches = try interfaces.CacheStorage.init(internal.allocator, instance.ctx);
    internal.cache_storage = .{ .owner = instance, .value = caches };
    internal.cache_storage.?.edge.hold(instance, caches);
    return caches;
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

/// Window's own teardown: the generated chain runs EventTarget's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    // The host is freeing the Window: its wrapper must not free it again.
    // The realm's teardown frees the Window before the wrapper cache's, which
    // would otherwise run this deinit a second time.
    engine.platformObjectDestroyed(instance);

    // Clean up Window's own internal state
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        // Its document, as it was: what `forgetWindow` below compares.
        const associated_document = internal.document;

        // The window's Location and History ([SameObject]: one each for the
        // window's life) go WHOLE with it: their destructors, and their
        // storage back from whoever can reach them last (runtime.gc
        // .releaseOwned) - now, or after the realm teardown under way, when
        // no wrapper can; else their wrappers' ends, which return a completed
        // cleanup's storage (the realm's wrapper cache sweep severs a wrapper
        // whose instance goes). Only their destructors used to run here, and
        // the realm's end took the Location's wrapper out of its cache
        // unsevered first: each page kept its Location's slab slot and state
        // block until its Browser ended (lane pageretention1).
        if (internal.location) |loc| {
            runtime.gc.releaseOwned(loc);
            internal.location = null;
        }
        if (internal.history) |history_inst| {
            runtime.gc.releaseOwned(history_inst);
            internal.history = null;
        }

        // The window's document and its tree go with the window, through
        // Node's own teardown (dom.node_creation.destroyRoot), whose storage
        // rule is every node's: back once no wrapper can reach the slot - at
        // the end of the realm teardown under way - else at its wrapper's end.
        // Chromium's Window.FrameDestroyed() calls Document.Shutdown() the
        // same way. Only the document's destructor ran here before: a window
        // whose document's wrapper was collected first - a removed frame's
        // realm, which the collector takes whole - kept the document's slot
        // until its Browser ended (lane pageretention1).
        if (internal.document) |doc| {
            log.debug("[Window.deinit] Cleaning up Document {*}", .{doc});
            @import("dom").node_creation.destroyRoot(doc);
            internal.document = null;
            log.debug("[Window.deinit] Document cleanup DONE", .{});
        } else {
            log.debug("[Window.deinit] NO document to clean up", .{});
        }

        // No browsing context names this Window from here on - its own, or a
        // retired one that kept it (Navigables.forgetWindow) - before
        // `internal.deinit` can free a context the Window owns.
        if (internal.browsing_context.navigables) |navigables| {
            navigables.forgetWindow(@ptrCast(instance), if (associated_document) |d| @ptrCast(d) else null);
        }

        internal.deinit();
        // Return the block itself, not just what it points to. `internal.deinit()`
        // releases what the state OWNS; the state struct was staying allocated for
        // the life of the process.
        runtime.arenaOf(instance).destroy(InternalState, internal);
        state.own._internal = null;
    }

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

    // Keep the opener: its WindowProxy, when it is another realm's - a
    // WindowProxy holder keeps the PROXY (the integrator's ruling of
    // 2026-10-25 on the three-browser probe, Firefox's behaviour; WebKit's
    // Frame keeps WeakPtr<Frame> m_opener, read through its WindowProxy) -
    // and the Window, for when there is no edge to read.
    forgetOpener(instance, internal);
    internal.opener = runtime.window_holders.Link.of(opener_window);
    if (opener_window.ctx != instance.ctx) engine.traceValue(instance, .{ .instance = opener_window }, opener_slot);

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
    forgetOpener(instance, internal);
}

/// The member a Window keeps another realm's opener (its WindowProxy) in.
const opener_slot: engine.TracedSlot = .{ .name = "opener" };

/// Let go of the opener `setOpener` kept.
fn forgetOpener(instance: *runtime.Instance, internal: *InternalState) void {
    const link = internal.opener orelse return;
    internal.opener = null;
    if (link.realm != instance.ctx) engine.forgetTracedChild(instance, opener_slot);
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

    // The window's position and viewport size window.open() set up for the
    // browsing context: every Window it shows reports them.
    applyRequestedWindow(internal);
}

/// dom.window_globals: the Window stops owning the top-level browsing
/// context Window.init made, and hands it to the caller - the host page's
/// top-level traversable keeps it across every Window a navigation makes
/// (lane newwin1). Null when this Window owns none (a frame's, a popup's).
fn releaseBrowsingContext(instance: *runtime.Instance) ?*anyopaque {
    const internal = getInternal(instance) orelse return null;
    if (!internal.owns_browsing_context) return null;
    internal.owns_browsing_context = false;
    return @ptrCast(internal.browsing_context);
}

/// CSSOM View "set up browsing context features", as a Window of the
/// browsing context reports it: the requested position (screenX/screenY)
/// and viewport size (innerWidth/innerHeight), each that was given.
fn applyRequestedWindow(internal: *InternalState) void {
    const requested = internal.browsing_context.requested_window;
    if (requested.x) |x| internal.screen_x = x;
    if (requested.y) |y| internal.screen_y = y;
    if (requested.width) |width| internal.inner_width = width;
    if (requested.height) |height| internal.inner_height = height;
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
    if (internal.document) |previous| if (previous != document) {
        @import("dom").document_browsing_context.clearWindow(previous);
        // The window's idle callbacks are the new document's from here
        // (endIdleCallbacks): ended with the replaced document - Crane unloads
        // it, running its cleanup steps, before the new one is set here - or,
        // were its cleanup still to come, ending with that cleanup nothing of
        // the new document's.
        if (!internal.idle.ended) internal.idle.replaced_pending_end = true;
        internal.idle.ended = false;
    };
    internal.document = document;
    // A new document is a new environment: its storage key is computed anew.
    if (internal.storage_key) |key| internal.allocator.free(key);
    internal.storage_key = null;
    _ = @import("dom").custom_elements.ensureGlobalRegistry(document) catch {};
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

    // [cross_origin_objects]: the engine runs HTML 7.2.1's checks itself -
    // a cross-origin `w.document` fails its access check, and WebIDL's
    // "perform a security check" refuses the getter a cross-origin `this` -
    // so the getter's steps are only "return this's associated Document".
    if (comptime engine.capabilities.cross_origin_objects != .unsupported) {
        return internal.document orelse error.NotImplemented;
    }

    // The declared fallback, for an engine that runs no cross-origin checks.
    // Cross-origin security check per HTML spec §7.2.3.1
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
/// A document whose origin is its creator's - about:blank, about:srcdoc, a
/// javascript: URL's result - holds its creator's origin record, so one
/// record on both sides is one origin (step 1, or 2 with identical
/// domains), and a domain set through either document is both documents'.
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#same-origin-domain
fn sameOriginDomain(a: *runtime.Instance, b: *runtime.Instance) bool {
    const a_internal = getInternal(a) orelse return false;
    const b_internal = getInternal(b) orelse return false;
    return @import("dom").origin_record.sameOriginDomain(
        .{ .serialized = effectiveOrigin(a, a_internal), .record = settingsOriginRecord(a) },
        .{ .serialized = effectiveOrigin(b, b_internal), .record = settingsOriginRecord(b) },
    );
}

/// Getter for name - The window's target name
/// Per spec: Returns the navigable's target name, or "" without a navigable.
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // HTML name getter steps 1-2: a Window without a navigable has no name.
    const navigable = navigableOf(instance, internal) orelse return runtime.DOMString.initInterned("");
    return try runtime.DOMString.initDupe(instance.ctx.allocator, navigable.target_name);
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
/// HTML 4.13.4: return the associated Document's global registry.
pub fn get_customElements(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return @import("dom").custom_elements.ensureGlobalRegistry(internal.document orelse return error.InvalidStateError);
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

/// HTML "document-tree child navigables", steps 1–5, supplies membership,
/// excluding shadow trees. A replaced or destroyed Window has none of its
/// successor's list. Window indices retain navigable insertion order.
fn documentTreeChildNavigables(instance: *runtime.Instance, internal: *InternalState, allocator: std.mem.Allocator) std.ArrayListUnmanaged(@import("dom").navigables.ChildNavigable) {
    const navigable = navigableOf(instance, internal) orelse return .empty;
    const document = internal.document orelse blk: {
        const raw = navigable.getActiveDocument() orelse return .empty;
        break :blk @as(*runtime.Instance, @ptrCast(@alignCast(raw)));
    };
    // Membership and order: dom.navigables (the engine adapter's indexed
    // interceptor walks the same list).
    return @import("dom").navigables.documentTreeChildNavigables(navigable, document, allocator);
}

/// Getter for length - Number of document-tree child navigables.
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // "Return this's associated Document's document-tree child navigables's
    // size." A Window with no navigable has a destroyed document, whose child
    // navigables were destroyed with it - the context's list is its
    // successor's.
    var children = documentTreeChildNavigables(instance, internal, internal.allocator);
    defer children.deinit(internal.allocator);
    return @intCast(children.items.len);
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
    var children = documentTreeChildNavigables(instance, internal, internal.allocator);
    defer children.deinit(internal.allocator);

    // Out of bounds check
    if (index >= children.items.len) {
        return null;
    }

    // Get the child browsing context's Window
    const child_ctx = children.items[index].browsing_context;
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
        // An opener whose traversable was closed - its browsing context
        // discarded - is no opener: null, as in Blink (Frame::Detach disposes
        // the OpenedFrameTracker, which clears every openee's opener) and
        // Gecko (BrowsingContext::GetOpener answers null for a discarded
        // context). The popup lives on, a top-level traversable of its own.
        if (opener_bc.is_closed) return runtime.JSValue.jsNull;
        if (opener_bc.getActiveWindow()) |active| {
            return runtime.JSValue.fromInstanceAnyopaque(active);
        }
    }

    // Return opener if set - opener is a stored Window instance pointer
    // Use fromInstanceAnyopaque for legacy anyopaque instance pointers
    if (internal.opener) |link| {
        if (link.realm != instance.ctx) {
            if (engine.tracedValue(instance, opener_slot)) |held| return held.take();
        }
        if (link.get()) |opener| return .{ .instance = opener };
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
    _ = getInternal(instance) orelse return error.InvalidStateError;

    // Steps 1-4: "Let current be this's node navigable. If current is null,
    // then return null. Let container be current's container. If container is
    // null, then return null."
    const container = containerOf(instance) orelse return null;

    // Step 5: "If container's node document's origin is not same
    // origin-domain with the current settings object's origin, then return
    // null." The current settings object is this getter's, the window's own.
    const container_document = (interfaces.Node.get_ownerDocument(container) catch null) orelse return null;
    const container_window = (interfaces.Document.get_defaultView(container_document) catch null) orelse return null;
    if (!sameOriginDomain(container_window, instance)) return null;

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

/// HTML 7.1.2 originAgentCluster: "return the surrounding agent's agent
/// cluster's is origin-keyed". The surrounding agent is this window's
/// whenever script can reach this getter: a window it reaches is same
/// origin-domain with it, and so in its agent cluster.
///
/// The cluster is origin-keyed when "obtain a similar-origin window agent"
/// keyed it by the document's origin: the origin is opaque, the group is
/// cross-origin isolated, or the group's historical agent cluster key map
/// says so - as the navigation that created a document of this origin in
/// this window's browsing context group recorded it (dom.agent_cluster_keys).
pub fn get_originAgentCluster(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    return @import("dom").agent_cluster_keys.isOriginKeyed(
        runtime.BrowserScope.ofInstance(instance),
        internal.browsing_context.virtual_group_id,
        effectiveOrigin(instance, internal),
        settingsCrossOriginIsolated(instance),
    );
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

    // Create the CookieStore WebIDL instance. In a non-secure context the
    // attribute is not exposed at all ([SecureContext]); until that exposure
    // lands, its getter answers - throwing here broke every page that reads
    // each property of `window` (webidl/ecmascript-binding/
    // attributes-accessors-unique-function-objects.html) - and the store's
    // operations reject.
    const cookie_store_instance = interfaces.CookieStore.initWith(
        internal.allocator,
        instance.ctx,
        .{ .is_secure_context = secureContext(instance, 0) },
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
    const event = @import("dom").fire_event.currentEvent(instance) orelse return runtime.JSValue.jsUndefined;
    return .{ .instance = event };
}

/// Getter for orientation
pub fn get_orientation(instance: *runtime.Instance) anyerror!i16 {
    _ = instance;
    return error.NotImplemented;
}

/// HTML 16.3.3: return an External object. The generated [SameObject] getter
/// owns the cache and traces its child, including reads made from native code.
pub fn get_external(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return interfaces.External.init(instance.ctx.allocator, instance.ctx);
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
    // origin, the top-level site and the has-cross-site-ancestor bit
    // (`settingsStorageKey`) - picks the shelf. So every same-origin,
    // same-partition document of one tab shares it: a frame and its parent,
    // and the Windows a frame's navigations make one after another; the
    // origin framed under another top-level site does not. A popup's
    // traversable starts with a copy of its opener's shed
    // (`newTopLevelTraversable`).
    const context_id = internal.browsing_context.getTop().id;
    const key = (try @import("dom").global_settings.storageKeyForNonStoragePurposesOf(instance)) orelse return error.SecurityError;

    // The shed is the Browser's (its scope's supplement): a realm no Browser
    // made has none - "the user agent is configured to not allow" storage.
    const user_agent_storage = @import("dom").browser_state.userAgentStorageOf(instance.ctx) orelse return error.SecurityError;

    // Create the backend storage for this origin and browsing context
    const backend = internal.allocator.create(WebStorage) catch return error.OutOfMemory;
    errdefer internal.allocator.destroy(backend);

    backend.* = getSessionStorageBackend(internal.allocator, user_agent_storage, context_id, key) catch |err| {
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

    // HTML 12.2.3 step 2's local storage bottle map, in the user agent's
    // storage shed - the Browser's this Window's realm belongs to (its
    // scope's supplement), never another Browser's. A realm no Browser made
    // has none: "the user agent is configured to not allow" storage.
    const user_agent_storage = @import("dom").browser_state.userAgentStorageOf(instance.ctx) orelse return error.SecurityError;
    // Its shelf is the storage key's (`settingsStorageKey`): one origin
    // framed under two top-level sites has two areas, as in every browser.
    const key = (try @import("dom").global_settings.storageKeyForNonStoragePurposesOf(instance)) orelse return error.SecurityError;

    // Create the backend storage for this storage key
    const backend = internal.allocator.create(WebStorage) catch return error.OutOfMemory;
    errdefer internal.allocator.destroy(backend);

    backend.* = getLocalStorageBackend(internal.allocator, user_agent_storage, key) catch |err| {
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
    // HTML name setter step 1: a Window without a navigable ignores writes.
    const navigable = navigableOf(instance, internal) orelse return;
    const str_slice = value.asSlice();
    try navigable.setTargetName(str_slice);
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

/// HTML opener setter: null disowns the browsing context's opener; a
/// non-null value replaces this accessor with an own data property.
pub fn set_opener(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1 applies only when this's browsing context is non-null.
    if (value.isNull()) {
        if (navigableOf(instance, internal) == null) return;
        internal.browsing_context.disown();
        forgetOpener(instance, internal);
        return;
    }

    // Step 2: DefinePropertyOrThrow. The engine owns the data property's
    // value; the native opener relationship stays unchanged. WebKit's
    // JSDOMWindowCustom::setOpener likewise uses createDataProperty here.
    try engine.defineOwnProperty(instance.ctx, .{ .instance = instance }, "opener", value, .{
        .writable = true,
        .enumerable = true,
        .configurable = true,
    });
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

    // The printing steps, step 1: "If the active sandboxing flag set of
    // this's associated Document has the sandboxed modals flag set, then
    // return."
    if (sandboxedModals(internal)) return;

    // Use the UI backend to show print dialog
    internal.ui_backend.showPrint();
}

/// HTML "cannot show simple dialogs" step 1 (and the printing steps' step
/// 1): the window's associated Document's active sandboxing flag set has the
/// sandboxed modals flag set.
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#cannot-show-simple-dialogs
fn sandboxedModals(internal: *InternalState) bool {
    const document = internal.document orelse return false;
    return @import("dom").document_scripts.activeSandboxingFlags(document).modals;
}

/// Operation: confirm
/// Per spec §8.8.2: Shows a confirmation dialog.
pub fn call_confirm(instance: *runtime.Instance, message: webidl.Opt(runtime.DOMString)) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if window is closed
    if (internal.closed) {
        return false; // Return false if window is closed
    }

    // Step 1: "If we cannot show simple dialogs for this, then return false."
    if (sandboxedModals(internal)) return false;

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
    if (getInternal(instance) == null) return error.InvalidStateError;
    // "2. Let options be «[ "targetOrigin" → targetOrigin, "transfer" →
    // transfer ]»": the sequence<object> the binding hands over as a value.
    if (!transfer.wasPassed()) return windowPostMessageSteps(instance, message, targetOrigin, &.{});
    const allocator = instance.ctx.allocator;
    const objects = try engine.convertToSequenceOfObjects(instance.ctx, transfer.getValue(), allocator);
    defer {
        for (objects) |object| object.release();
        allocator.free(objects);
    }
    const list = try allocator.alloc(runtime.JSValue, objects.len);
    defer allocator.free(list);
    for (objects, list) |object, *item| item.* = object.value;
    return windowPostMessageSteps(instance, message, targetOrigin, list);
}

/// The current realm of the window post message steps, as a conforming
/// binding would make it: `current` (the postMessage function's realm), or,
/// when the caller - `incumbent`, whose window is `source` - is not same
/// origin-domain with that realm's window, the caller's realm: its
/// cross-origin function wrapper's (see windowPostMessageSteps).
fn serializationRealm(current: ?runtime.Context, incumbent: runtime.Context, source: ?*runtime.Instance) runtime.Context {
    const realm = current orelse return incumbent;
    const window = windowOfRealm(realm) orelse return realm;
    const caller = source orelse return realm;
    if (caller == window or sameOriginDomain(caller, window)) return realm;
    return incumbent;
}

/// HTML "window post message steps" given targetWindow `instance`,
/// `message`, and options' targetOrigin and transfer.
fn windowPostMessageSteps(instance: *runtime.Instance, message: runtime.JSValue, targetOrigin: []const u8, transfer: []const runtime.JSValue) anyerror!void {
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

    // Step 8.2 carries the actual origin, including an opaque origin's
    // identity. Keep it before StructuredSerialize can run script; the
    // posted task owns this reference until delivery, drop or teardown.
    // The record stays on this Browser's window-agent thread.
    const origin_record = if (source_window) |sw| settingsOriginRecord(sw) else null;
    if (origin_record) |record| {
        try record.resolve(source_origin);
        _ = record.retain();
    }
    errdefer if (origin_record) |record| record.release();

    // Steps 3-5.
    const target_origin = try TargetOrigin.resolve(allocator, instance, targetOrigin, source_window, source_origin);
    errdefer target_origin.deinit(allocator);

    // The transfer-list path still uses the serialization. Copy it before
    // serialization can run a getter that navigates the sending Window.
    const origin = try allocator.dupe(u8, source_origin);
    errdefer allocator.free(origin);

    // Steps 6-7: StructuredSerializeWithTransfer(message, transfer). Rethrow
    // any exceptions - which the serializer has already thrown, as the
    // spec's DataCloneError or as whatever script threw mid-walk. A transfer
    // list ships its MessagePorts (their transfer steps, dom.message_ports)
    // and detaches its ArrayBuffers, as a port's and a worker's postMessage
    // do (html.worker_host.serializePortMessage).
    //
    // The realm they run in is the current realm: the realm of the postMessage
    // function object - this window's for a script of its own origin-domain.
    // A script of another origin-domain reaches postMessage through HTML's
    // cross-origin property access, whose function is created in the
    // ACCESSOR's current realm (7.2.3.4 CrossOriginGetOwnPropertyHelper, its
    // cross-origin function wrapper); the binding hands that caller this
    // window's own function, so that call serializes in the incumbent realm,
    // the caller's, as the wrapper would. It is the realm a DataCloneError is
    // made in, and a WebAssembly.Module's [[AgentCluster]] (WebAssembly Web API
    // section 3) - the posting window's cluster, never the target's.
    const serialize_realm = serializationRealm(engine.currentRealm(), incumbent, source_window);
    // StructuredSerializeWithTransfer step 5.4.3's DetachArrayBuffer throws a
    // TypeError for an ArrayBuffer whose [[ArrayBufferDetachKey]] is not
    // undefined - a WebAssembly.Memory's. Checked before the engine's
    // serializer, which detaches without asking (V8 aborts: "Only detachable
    // ArrayBuffers can be detached").
    for (transfer) |item| {
        if (engine.borrowArrayBufferBytes(serialize_realm, item) == null) continue;
        if (!engine.canTransferArrayBuffer(serialize_realm, item)) return error.TypeError;
    }
    var serialized: SerializedMessage = if (transfer.len > 0)
        .{ .with_transfer = try @import("html").worker_host.serializePortMessage(serialize_realm, message, transfer, allocator) }
    else
        try SerializedMessage.serialize(serialize_realm, allocator, message);
    errdefer serialized.deinit(allocator);

    const posted = try allocator.create(PostedMessage);
    posted.* = .{
        .allocator = allocator,
        .target = instance,
        .target_generation = runtime.SlabAllocator.generationOf(instance),
        .target_origin = target_origin,
        .origin = origin,
        .origin_record = origin_record,
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
    const transfer: []const runtime.JSValue = if (options.was_passed) (options.value.base.transfer orelse &.{}) else &.{};
    return windowPostMessageSteps(instance, message, target_origin, transfer);
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
    /// A message posted with a transfer list: the serialization, the
    /// transferred ArrayBuffers' contents and the shipped ports' ends - a
    /// port message's shape (dom.port_channels). OWNED.
    with_transfer: *@import("dom").port_channels.PortMessage,

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
            // No transfer list (a message with one is serialized by
            // html.worker_host.serializePortMessage).
            .handle, .instance => .{ .serialized = try engine.structuredSerializeWithTransfer(realm, value, &.{}, noTransferables, null, allocator) },
        };
    }

    /// Step 8.4, into `realm`. The value is OWNED - a string, or the
    /// engine's - and fireMessageEvent releases it after construction.
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
                // No transfer list (`.with_transfer` has one): no platform
                // object was transferred.
                const value = try engine.structuredDeserializeWithOptions(realm, serialized.serialized, .{ .array_buffers = serialized.array_buffers, .shared_memory = serialized.shared_memory });
                return value.take();
            },
            // Delivered by `deliverWithTransfer`, which receives its ports.
            .with_transfer => return error.DataCloneError,
        }
    }

    fn deinit(self: *SerializedMessage, allocator: Allocator) void {
        switch (self.*) {
            .string => |s| allocator.free(s),
            .serialized => |*serialized| serialized.deinit(allocator),
            // Its ends no port took are discarded with it.
            .with_transfer => |message| message.destroy(),
            else => {},
        }
        self.* = .undefined;
    }

    /// Release a deserialized value after an event has kept its own copy,
    /// or when construction failed.
    fn release(allocator: Allocator, value: runtime.JSValue) void {
        switch (value) {
            .string => |s| if (s.owned) allocator.free(s.data),
            .handle => (engine.Owned{ .value = value }).release(),
            else => {},
        }
    }
};

/// A message posted with no transfer list transfers nothing.
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
    /// Step 8.2's actual origin; one reference owned by this queued task.
    origin_record: ?*@import("dom").origin_record.OriginRecord,
    /// Step 8.3: the incumbent's window.
    source: ?*runtime.Instance,
    source_generation: u64,
    message: SerializedMessage,

    fn destroy(self: *PostedMessage) void {
        self.target_origin.deinit(self.allocator);
        self.allocator.free(self.origin);
        if (self.origin_record) |record| record.release();
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

    // Steps 8.4-8.7 for a message with a transfer list.
    switch (posted.message) {
        .with_transfer => |message| return deliverWithTransfer(target, message, posted.origin, source),
        else => {},
    }

    // Steps 8.4-8.5. A value that will not deserialize is a messageerror.
    const message = posted.message.deserialize(target.ctx) catch {
        fireMessageEvent(target, "messageerror", runtime.JSValue.jsUndefined, posted.origin, posted.origin_record, source);
        return;
    };

    // Step 8.7.
    fireMessageEvent(target, "message", message, posted.origin, posted.origin_record, source);
}

/// Steps 8.4-8.7 for `message`, posted with a transfer list, in `target`'s
/// realm: its MessagePorts received into the realm (their transfer-receiving
/// steps) - newPorts, in transfer-list order - and the message deserialized
/// with its transferred ArrayBuffers; `message` fired with them, or
/// `messageerror` when it does not deserialize. The message keeps nothing it
/// handed over; it is freed with the posted message.
fn deliverWithTransfer(target: *runtime.Instance, message: *@import("dom").port_channels.PortMessage, origin: []const u8, source: ?*runtime.Instance) void {
    const dom = @import("dom");
    const allocator = target.ctx.allocator;
    var ports: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer ports.deinit(allocator);
    const ends = message.takeEnds();
    defer message.allocator.free(ends);
    for (ends) |end| {
        const port = dom.message_ports.receive(target.ctx, @ptrCast(end)) catch continue;
        ports.append(allocator, port) catch continue;
    }
    // Step 8.4: StructuredDeserializeWithTransfer in the target's realm, the
    // received ports its memory for the transferred ones the value refers to
    // (step 3.5); an exception is a messageerror, with origin and source - a
    // port whose transfer-receiving steps failed too (step 3.4.4 throws), as
    // the value's references are by place in the transfer list.
    if (ports.items.len != ends.len) {
        fireTransferEvent(target, "messageerror", runtime.JSValue.jsUndefined, origin, source, &.{});
        return;
    }
    const data = engine.structuredDeserializeWithOptions(target.ctx, message.serialized, .{ .array_buffers = message.array_buffers, .transferred = ports.items, .shared_memory = message.shared_memory }) catch {
        fireTransferEvent(target, "messageerror", runtime.JSValue.jsUndefined, origin, source, &.{});
        return;
    };
    defer data.release();
    // Steps 8.5-8.7: messageClone, newPorts, and the message event.
    fireTransferEvent(target, "message", data.value, origin, source, ports.items);
}

/// Fire `event_type` at `target` as a trusted MessageEvent with origin,
/// source and ports. `data` is borrowed: the event keeps its own.
fn fireTransferEvent(target: *runtime.Instance, event_type: []const u8, data: runtime.JSValue, origin: []const u8, source: ?*runtime.Instance, ports: []const *runtime.Instance) void {
    const init_dict = dictionaries.MessageEventInit{
        .base = .{},
        .data = data,
        .origin = origin,
        .source = if (source) |sw| typedefs.MessageEventSource{ .window_proxy = @ptrCast(sw) } else null,
        .ports = ports,
    };
    const event = interfaces.MessageEvent.call_constructor(
        target.ctx,
        runtime.DOMString.initInterned(event_type),
        webidl.Opt(dictionaries.MessageEventInit).passed(init_dict),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    // Fired by the user agent: trusted (DOM 2.10).
    _ = @import("dom").fire_event.dispatchTrusted(target, event) catch {};
    event.releaseIfUnwrapped(generation);
}

/// Steps 8.4 and 8.7: fire a UA MessageEvent with the sender's actual origin.
/// Takes `data`; the event retains its own value and origin reference.
fn fireMessageEvent(target: *runtime.Instance, event_type: []const u8, data: runtime.JSValue, origin: []const u8, origin_record: ?*@import("dom").origin_record.OriginRecord, source: ?*runtime.Instance) void {
    defer SerializedMessage.release(target.ctx.allocator, data);
    const event = interfaces.MessageEvent.initWith(target.ctx.allocator, target.ctx, .{
        .message_type = runtime.DOMString.initInterned(event_type),
        .message_init = dictionaries.MessageEventInit{
            .base = .{},
            .data = data,
            // The record supplies its serialization. Keep a string only
            // when the sending Window had no associated origin record.
            .origin = if (origin_record != null) "" else origin,
            .source = if (source) |sw| typedefs.MessageEventSource{ .window_proxy = @ptrCast(sw) } else null,
        },
        .message_origin_record = origin_record,
    }) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);

    _ = @import("dom").fire_event.dispatchTrusted(target, event) catch {};

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

/// Operation: matchMedia(query) - CSSOM View 4: "1. Let parsed media query
/// list be the result of parsing query. 2. Return a new MediaQueryList
/// object, with this's associated Document as the document, with parsed
/// media query list as its associated media query list." (The list parses
/// the query as it is made.)
///
/// Spec: https://drafts.csswg.org/cssom-view/#dom-window-matchmedia
pub fn call_matchMedia(instance: *runtime.Instance, query: typedefs.CSSOMString) anyerror!*runtime.Instance {
    const document = try interfaces.Window.get_document(instance);
    return interfaces.MediaQueryList.initWith(instance.ctx.allocator, instance.ctx, .{ .media_document = document, .media_query = query.asSlice() });
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

    // Step 1: "If we cannot show simple dialogs for this, then return."
    if (sandboxedModals(internal)) return;

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
    /// runnable again (Crane keeps no bfcache), so nothing more is kept -
    /// until a new document becomes the window's (setDocument), which a
    /// window reused for a navigable's first document is.
    ended: bool = false,
    /// setDocument replaced a document whose unloading document cleanup has
    /// not run yet: the next end step (endIdleCallbacks) is that document's,
    /// and must not end the new one's callbacks.
    replaced_pending_end: bool = false,

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
///
/// The step is keyed on the realm, which a window reused for a navigable's
/// first document shares with the initial about:blank one (HTML "create and
/// initialize a Document object" step 6). It ends the state of the document
/// that unloaded, never its successor's: Crane runs it before setDocument
/// gives the window its new document (the frame's commit unloads and destroys
/// the old document first, Blink's FrameLoader::DetachDocument order), and
/// setDocument then lets the window ask for idle periods again; were it to
/// run after, setDocument has marked it as the replaced document's, and it
/// ends nothing of the new one's.
fn endIdleCallbacks(environment: runtime.Context) void {
    const found = idleCallbacksOf(environment) orelse return;
    const idle = &found.internal.idle;
    if (idle.replaced_pending_end) {
        idle.replaced_pending_end = false;
        return;
    }
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
    // Steps 4-6. Not modelled, stated: step 6's second condition - the
    // incumbent global's browsing context familiar with browsingContext.
    if (!bc.isScriptClosable()) return;
    // Step 5: "Let sourceSnapshotParams be the result of snapshotting source
    // snapshot params given thisTraversable's active document." Step 6's
    // third condition: "the incumbent global object's navigable is allowed
    // by sandboxing to navigate thisTraversable, given sourceSnapshotParams".
    if (windowOfRealm(engine.incumbentRealm())) |incumbent| {
        if (getInternal(incumbent)) |incumbent_internal| {
            if (internal.document) |document| {
                const flags = @import("dom").document_scripts.activeSandboxingFlags(document);
                if (!html_core.navigation.sandbox_navigation.allowedBySandboxingToNavigate(incumbent_internal.browsing_context, bc, .{
                    .sandboxing_flags = flags,
                    .has_transient_activation = @import("html").user_activation.hasTransientActivation(instance),
                })) return;
            }
        }
    }
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

    /// The task never ran: its realm's timers ended with it armed - the
    /// popup, or the whole Browser, went first.
    fn drop(data: ?*anyopaque) void {
        const task: *CloseTask = @ptrCast(@alignCast(data orelse return));
        task.allocator.destroy(task);
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
    // Owned by the timer: a task its realm's end drops is freed then. With a
    // plain timer, a popup closed just before its Browser ended leaked this
    // task - lane httpcache1's one intermittent allocation (lane leaks6;
    // docs/lessons/architecture-a-task-queued-on-a-loop-that-never-runs-again-leaks-its-data.md).
    if (timer.setTimeoutOwned(0, CloseTask.run, task, CloseTask.drop) != 0) return;
    // A timer that cannot promise the drop: the plain one, as before.
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

    // Step 1: "If this's navigable is null, then return."
    if (navigableOf(instance, internal) == null) return;
    // Step 2: "Stop loading this's navigable": a frame's or popup's ongoing
    // navigation is set to null (dom.content_navigables) - its fetch ends,
    // and nothing commits - which informs the navigation API about aborting
    // navigation. The top-level page has no navigation of Crane's to end:
    // its navigation API is informed directly (an intercepted navigation's
    // navigate event is aborted either way). The same owner hook performs
    // step 3, aborting the document and its descendants.
    if (get_document(instance)) |document| {
        @import("dom").content_navigables.stopLoading(document);
    } else |_| {}
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

    // The entry global supplies the source Document, URL/referrer, and
    // creator for a new popup. Existing-target selection starts from this
    // Window, matching browsers (see the named lookup below).
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
    // "Get noopener for window open" step 1: a blob URL whose creator is not
    // same site with sourceDocument's top-level origin forces noopener
    // (dom.blob_partition.forcesNoopener).
    const window_features = WindowFeatures.parse(if (features.wasPassed()) features.getValue().asSlice() else "");
    const blob_noopener = if (url_record) |u| @import("dom").blob_partition.forcesNoopener(instance, u) else false;
    const noopener = blob_noopener or window_features.noopener or window_features.noreferrer;
    // Steps 11-12: "Let referrerPolicy be the empty string. If noreferrer is
    // true, then set noopener to true and set referrerPolicy to
    // "no-referrer"."
    const referrer_policy: @FieldType(html_core.window.iframe_integration.NavigateRequest, "referrer_policy") = if (window_features.noreferrer) .no_referrer else .empty;

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
        // Steps 18-19: these special targets return their WindowProxy even
        // with noopener. Chrome/Firefox pass all three targets; Safari also
        // passes _parent and _top (window-open-noopener.html).
        if (std.ascii.eqlIgnoreCase(target_str, "_parent")) return (interfaces.Window.get_parent(this) catch null) orelse getWindowProxy(this);
        if (std.ascii.eqlIgnoreCase(target_str, "_top")) return (interfaces.Window.get_top(this) catch null) orelse getWindowProxy(this);
        return getWindowProxy(this);
    }

    // A name an open popup carries is that popup - any popup of the pages
    // related to this one: the root of the opener chain and every popup
    // opened from it, however deep. A popup's own script calling
    // `opener.open(url, name)` has the popup as the entry global, and the
    // name is one its opener gave.
    // "The rules for choosing a navigable" step 7: "find a navigable by
    // target name" whatever noopener is - noopener decides only what a NEW
    // top-level traversable is (step 8.7). A window that was opened with
    // noopener is in a browsing context group of its own, which step 7's
    // search of this page's group never reaches (`namedPopup`).
    if (!std.ascii.eqlIgnoreCase(target_str, "_blank")) {
        // A frame of the source's page carrying the name, first - "find a
        // navigable by target name" looks through every navigable the
        // source is familiar with, and its page's frames are.
        const navigables = @import("dom").navigables;
        const this_document = interfaces.Window.get_document(this) catch source_document;
        if (navigables.findByName(this_document, target_str)) |frame_window| {
            // Step 16.1: navigate it, then (step 18) return its WindowProxy -
            // or null with noopener.
            if (url_record) |u| navigables.navigateByTarget(source_document, .{ .target = target_str, .url = u, .current_document = this_document, .noopener = noopener });
            return if (noopener) null else frame_window;
        }
        // Deviation from HTML window-open step 13, which starts selection
        // from sourceDocument's entry global: all three engines use the
        // receiver. Blink LocalDOMWindow::open selects on GetFrame()->Tree();
        // WebKit LocalDOMWindow::open passes this->frame() to createWindow;
        // Gecko OpenWindow2 looks up names relative to its receiver parent.
        // https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/frame/local_dom_window.cc
        // https://github.com/WebKit/WebKit/blob/main/Source/WebCore/page/LocalDOMWindow.cpp
        // https://github.com/mozilla-firefox/firefox/blob/main/toolkit/components/windowwatcher/nsWindowWatcher.cpp
        // Steps 4 and 7 must share the receiver: skipping the entry top here
        // can exclude a popup whose callback has called into its opener.
        if (popupByName(this, target_str)) |found| {
            // Step 16.1: "If urlRecord is not null, then navigate targetNavigable
            // to urlRecord using sourceDocument, with referrerPolicy and
            // exceptionsEnabled set to true."
            if (url_record) |u| {
                if (found.integration) |integration| {
                    integration.navigate(u, .{ .source_document = @ptrCast(source_document), .referrer_policy = referrer_policy });
                } else {
                    const host_document = interfaces.Window.get_document(found.window) catch return null;
                    // A host has no integration. _self takes its existing
                    // page-navigation branch without another name search.
                    navigables.navigateByTarget(source_document, .{ .target = "_self", .url = u, .current_document = host_document, .noopener = noopener });
                }
            }
            return if (noopener) null else found.window;
        }
    }

    // "The rules for choosing a navigable" step 3: "Let sandboxingFlagSet be
    // currentNavigable's active document's active sandboxing flag set" -
    // this's navigable's, which the rules are given (step 13) whatever the
    // entry global. Step 8: with its sandboxed auxiliary navigation browsing
    // context flag set no new top-level traversable is made, and (step 14)
    // "if targetNavigable is null, then return null".
    const current_flags = sandboxingFlagsOfWindow(this);
    if (current_flags.auxiliary_navigation) return null;

    // Step 15: a new top-level traversable, auxiliary unless noopener.
    // Step 15.1: "Set targetNavigable's active browsing context's is popup
    // to the result of checking if a popup window is requested". Deviation,
    // stated, matching Chrome and Safari (window-open-popup-behavior passes
    // 51/51 in both; Firefox follows the text): a window opened with noopener
    // or noreferrer is never a popup, whatever its features.
    const is_popup = window_features.popup and !noopener;
    const created = try newTopLevelTraversable(instance, target_str, noopener, is_popup, this) orelse return null;
    const integration = created.integration;
    // Step 15.2: "Set up browsing context features for targetNavigable's
    // active browsing context given tokenizedFeatures" - the window's
    // position and viewport size, which each of its Windows reports
    // (replaceBrowsingContext gives a later one the same).
    if (getInternal(created.window)) |created_internal| {
        created_internal.browsing_context.requested_window = window_features.geometry;
        applyRequestedWindow(created_internal);
    }

    // Steps 15.3-15.5: navigate it, unless the URL is about:blank - the
    // initial document it already has. "Navigate" fetches in parallel and
    // commits in a later task, so open() returns the window before its page
    // loads, as it must for `w.onload = f` to hear the load.
    if (url_record) |u| {
        if (html_core.navigation.navigate_steps.matchesAboutBlank(u)) {
            // Step 15.4: "If urlRecord matches about:blank, then perform the
            // URL and history update steps given targetNavigable's active
            // document and urlRecord" - about:blank#frag or ?query becomes the
            // initial about:blank's URL, a replace, with no navigation.
            if (!std.mem.eql(u8, u, "about:blank")) {
                if (!@import("dom").history_traversal.isInstalled()) _ = get_history(created.window) catch {};
                @import("dom").history_traversal.urlAndHistoryUpdate(created.window, u, null, .replace);
            }
        } else integration.navigate(u, .{ .source_document = @ptrCast(source_document), .referrer_policy = referrer_policy });
    }

    // Steps 17-18: "If noopener is true or windowType is "new with no
    // opener", then return null. Return targetNavigable's active WindowProxy."
    return if (noopener) null else created.window;
}

const NamedPopup = struct {
    /// Null for a host page, whose Window identifies the target.
    integration: ?*html_core.IFrameIntegration,
    window: *runtime.Instance,
};

/// "Find a navigable by target name" steps 5-7: search the other top-level
/// contexts in this page's group, including their frames. Blink's
/// FrameTree::FindFrameForNavigationInternal likewise visits related pages.
fn popupByName(window: *runtime.Instance, name: []const u8) ?NamedPopup {
    const internal = getInternal(window) orelse return null;
    const current = internal.browsing_context;
    const top = current.getTop();
    const navigables = current.navigables orelse return null;
    // Step 7 permits a consistent order: use the Browser's live-list order.
    // This synchronous traversal runs no script and retains no list entry.
    // Group membership survives disowning an opener; an opener-chain walk
    // cannot enumerate the group.
    for (navigables.contexts()) |candidate| {
        if (candidate == top or candidate.parent != null or candidate.orphaned or
            candidate.is_closed or candidate.is_closing) continue;
        if (candidate.virtual_group_id != top.virtual_group_id) continue;
        const page: *runtime.Instance = @ptrCast(@alignCast(candidate.getActiveWindow() orelse continue));
        if (namedPopup(page, name, current)) |found| return found;
    }
    return null;
}

/// "The rules for choosing a navigable" step 8 for `window`'s navigable (the
/// currentNavigable): "creating a new top-level traversable" - given
/// `window`'s browsing context as the opener, or given null with noopener -
/// its target name `target` unless that is "_blank", showing its initial
/// about:blank document. The popup is `window`'s: it goes with `window`'s
/// page. The machinery is HTMLIFrameElement's (dom.auxiliary_navigables).
/// Null when none can be made.
fn newTopLevelTraversable(window: *runtime.Instance, target: []const u8, noopener: bool, is_popup: bool, current_window: *runtime.Instance) error{OutOfMemory}!?struct { integration: *html_core.IFrameIntegration, window: *runtime.Instance } {
    const internal = getInternal(window) orelse return null;
    const allocator = internal.allocator;
    const auxiliary_navigables = @import("dom").auxiliary_navigables;
    // Step 3's sandboxingFlagSet: the current navigable's active document's.
    // Step 9: "If sandboxingFlagSet's sandbox propagates to auxiliary
    // browsing contexts flag is set, then all the flags that are set in
    // sandboxingFlagSet must be set in chosen's active browsing context's
    // popup sandboxing flag set."
    const current_flags = sandboxingFlagsOfWindow(current_window);
    const popup_flags = @import("dom").sandboxing.popupSandboxingFlags(current_flags);
    // Choosing a navigable, step 8.1: consume only when creating a new
    // traversable. `window` is the entry global for open(), or the element's
    // document's Window for links/forms; `current_window` is open()'s this.
    // HTML PR 10547 deliberately chose the entry global. The multi-global
    // failures in Chromium 379674022 and Gecko 1931035 are spec lag, not a
    // contrary browser policy: https://github.com/whatwg/html/pull/10547.
    @import("html").user_activation.consume(window);
    const created = auxiliary_navigables.create(allocator, @ptrCast(internal.browsing_context), internal.origin, is_popup, popup_flags) orelse return null;
    const integration: *html_core.IFrameIntegration = @ptrCast(@alignCast(created.integration));
    internal.auxiliary_navigables.append(allocator, integration) catch {
        integration.deinit();
        allocator.destroy(integration);
        return error.OutOfMemory;
    };
    // HTML "create a new top-level traversable", step 10: only an opener
    // supplies a session-storage snapshot. An iframe opener uses its TOP's
    // whole shed; a named target reused by window.open never reaches here.
    // The owner list holds the integration before storage is published, so
    // an append failure cannot leave an unreachable tab's copied shelves.
    if (!noopener) if (integration.browsing_context) |created_bc| {
        if (@import("dom").browser_state.userAgentStorageOf(window.ctx)) |browser_storage| {
            web_storage.web_storage.cloneSessionStorage(browser_storage, internal.browsing_context.getTop().id, created_bc.getTop().id) catch {};
        }
    };
    // Steps 8.5-8.6: a named target names the new navigable.
    if (!std.ascii.eqlIgnoreCase(target, "_blank")) {
        if (integration.browsing_context) |bc| bc.setTargetName(target) catch {};
    }
    // Its initial about:blank document takes this window's secure context
    // (WebKit Document::initSecurityContext: the owner is the parent, else
    // the opener); taken now, so the answer does not follow this window's
    // later navigations.
    if (getInternal(created.window)) |created_internal| created_internal.creator_is_secure_context = secureContext(window, 0);
    // Steps 8.7-8.8: its opener is this window, unless noopener - which makes
    // it a new top-level traversable "given null" opener, in a browsing
    // context group of its own.
    if (noopener) {
        setOpenerNoopener(created.window) catch {};
        if (integration.browsing_context) |bc| bc.startOwnGroup();
    } else {
        setOpener(created.window, window) catch {};
        // Step 8.8.2: "If sandboxingFlagSet's sandboxed navigation browsing
        // context flag is set, then set chosen's active browsing context's
        // one permitted sandboxed navigator to currentNavigable's active
        // browsing context" - the context it was created given, its opener:
        // "which allows the browsing context that created them to actually
        // navigate them". Crane's opener is `window`'s (the entry global's,
        // as call_open states), which then navigates it; Blink's
        // LocalFrame::CanNavigate lets a sandboxed frame navigate a popup
        // whose opener it is (popup-from-initial-empty-sandboxed-document:
        // `iframe_name.open(url)` from the sandboxed frame).
        if (current_flags.navigation) {
            if (integration.browsing_context) |bc| bc.one_permitted_sandboxed_navigator = internal.browsing_context;
        }
    }
    return .{ .integration = integration, .window = created.window };
}

/// `window`'s associated Document's active sandboxing flag set: what "the
/// rules for choosing a navigable" read as sandboxingFlagSet for the
/// navigable whose active window `window` is. Empty with no document.
fn sandboxingFlagsOfWindow(window: *runtime.Instance) @import("dom").sandboxing.SandboxingFlagSet {
    const internal = getInternal(window) orelse return .empty;
    const document = internal.document orelse return .empty;
    return @import("dom").document_scripts.activeSandboxingFlags(document);
}

/// dom.auxiliary_navigables: the rest of "the rules for choosing a navigable"
/// for a hyperlink or a form whose target names no frame of its page - an
/// open popup of that name in the page's group (step 7), else a new
/// top-level traversable (step 8).
fn chooseTopLevelTraversable(current_window: *runtime.Instance, target: []const u8, noopener: bool) ?@import("dom").auxiliary_navigables.Chosen {
    if (!std.ascii.eqlIgnoreCase(target, "_blank")) {
        if (popupByName(current_window, target)) |found| return .{
            .integration = if (found.integration) |integration| @ptrCast(integration) else null,
            .window = found.window,
        };
    }
    // Step 8: no new top-level traversable for a document whose active
    // sandboxing flag set has the sandboxed auxiliary navigation browsing
    // context flag set.
    if (sandboxingFlagsOfWindow(current_window).auxiliary_navigation) return null;
    const created = (newTopLevelTraversable(current_window, target, noopener, false, current_window) catch null) orelse return null;
    return .{ .integration = @ptrCast(created.integration), .window = created.window };
}

/// Step 7.3: the named navigable among a related page's inclusive
/// descendants, provided the calling context is familiar with it.
fn namedPopup(window: *runtime.Instance, name: []const u8, current: *html_core.BrowsingContext) ?NamedPopup {
    const internal = getInternal(window) orelse return null;
    const document = internal.document orelse return null;
    const navigables = @import("dom").navigables;
    var documents = navigables.inclusiveDescendantDocuments(document, std.heap.page_allocator);
    defer documents.deinit(std.heap.page_allocator);
    const group = current.getTop().virtual_group_id;
    for (documents.items) |entry| {
        const bc = entry.browsing_context orelse internal.browsing_context;
        if (bc.orphaned or bc.is_closed or bc.is_closing) continue;
        if (bc.virtual_group_id != group) continue;
        if (!std.mem.eql(u8, bc.target_name, name)) continue;
        if (!familiarNamedContext(current, bc)) continue;
        const integration = navigables.integrationOf(@ptrCast(bc));
        const target: *runtime.Instance = @ptrCast(@alignCast(bc.getActiveWindow() orelse continue));
        return .{ .integration = integration, .window = target };
    }
    return null;
}

/// HTML "familiar with", for the active documents of two live contexts.
/// Group membership alone is insufficient: a foreign page's child is not
/// familiar just because its top-level page was opened by this one.
/// Blink's LocalFrame::CanNavigate/CanAccessAncestor likewise compare the
/// target/ancestor origins and the auxiliary opener when resolving names.
fn familiarNamedContext(current: *html_core.BrowsingContext, other: *html_core.BrowsingContext) bool {
    const navigables = current.navigables orelse return false;
    const contexts = navigables.contexts();
    const a = liveNamedContext(contexts, current) orelse return false;
    const a_origin = namedContextOrigin(a) orelse return false;
    const a_top: ?*html_core.BrowsingContext = blk: {
        var ancestor = a;
        for (0..contexts.len) |_| {
            const parent = ancestor.parent orelse break :blk ancestor;
            ancestor = liveNamedContext(contexts, parent) orelse break :blk null;
        }
        break :blk null;
    };
    var b = liveNamedContext(contexts, other) orelse return false;

    // Steps 1, 2 and 4 are alternatives to step 3's recursive result, so
    // check them before tail-following B's auxiliary opener. A valid chain
    // has at most contexts.len entries; that bound also terminates cycles
    // without truncating a longer valid chain at an arbitrary fixed depth.
    for (0..contexts.len) |_| {
        // 1. A's and B's active documents have the same origin.
        if (namedContextOrigin(b)) |b_origin| {
            if (@import("dom").origin_record.sameOrigin(a_origin, b_origin)) return true;
        }
        // 2. B is A's top-level browsing context.
        if (a_top == b) return true;
        // 4. An ancestor of B has the same origin as A's active document.
        var ancestor = liveNamedContext(contexts, b.parent);
        for (0..contexts.len) |_| {
            const parent = ancestor orelse break;
            if (namedContextOrigin(parent)) |origin| {
                if (@import("dom").origin_record.sameOrigin(a_origin, origin)) return true;
            }
            ancestor = liveNamedContext(contexts, parent.parent);
        }
        // 3. B is auxiliary and A is familiar with B's opener.
        if (b.parent != null or b.disowned) return false;
        b = liveNamedContext(contexts, b.opener) orelse return false;
    }
    return false;
}

/// Borrow a context from the Browser's live list before following a stored
/// parent/opener edge. The lookup runs no script and retains no pointer.
fn liveNamedContext(contexts: []const *html_core.BrowsingContext, wanted: ?*html_core.BrowsingContext) ?*html_core.BrowsingContext {
    const pointer = wanted orelse return null;
    for (contexts) |context| {
        if (context != pointer) continue;
        if (context.orphaned or context.is_closed or context.is_closing) return null;
        return context;
    }
    return null;
}

fn namedContextOrigin(context: *html_core.BrowsingContext) ?@import("dom").origin_record.Origin {
    if (context.getActiveDocument() == null) return null;
    const window: *runtime.Instance = @ptrCast(@alignCast(context.getActiveWindow() orelse return null));
    const internal = getInternal(window) orelse return null;
    const record = settingsOriginRecord(window);
    // Familiarity compares active DOCUMENT origins. An initial about:blank
    // child shares its creator's resolved record even when the Window's
    // creation-origin string is stale after a cross-origin navigation.
    return .{
        .serialized = if (record) |origin| origin.serialized orelse effectiveOrigin(window, internal) else effectiveOrigin(window, internal),
        .record = record,
    };
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
    /// CSSOM View's supported open() feature names - left, top, width and
    /// height - as "set up browsing context features" reads them.
    geometry: html_core.window.browsing_context.WindowGeometry = .{},

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
            .geometry = geometryOf(map),
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

    /// A feature separator: Infra ASCII whitespace, `=` or `,`. VT is not
    /// ASCII whitespace (unlike std.ascii.isWhitespace).
    fn isSeparator(c: u8) bool {
        return @import("infra").code_point.isAsciiWhitespaceCodePoint(c) or c == '=' or c == ',';
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
        // Integer parsing step 4 skips Infra ASCII whitespace, not VT.
        while (i < value.len and @import("infra").code_point.isAsciiWhitespaceCodePoint(value[i])) i += 1;
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

    /// The smallest viewport a window.open() size feature gives: the
    /// "optionally, clamp" of CSSOM View steps 7.3.1 and 8.3.1, as Blink
    /// and Gecko clamp a popup to 100 x 100 CSS pixels.
    const min_window_size: i32 = 100;

    /// CSSOM View "set up browsing context features" steps 5-8: each of
    /// left, top, width and height that is given, through the rules for
    /// parsing integers (an error is 0). A width or height of 0 sizes
    /// nothing. The optional clamps: a position stays on the screen area -
    /// not left of or above its origin - and a size is at least
    /// `min_window_size` (open-features-negative-*.html: a negative or tiny
    /// value gives the same window as width=1).
    fn geometryOf(map: Map) html_core.window.browsing_context.WindowGeometry {
        var geometry: html_core.window.browsing_context.WindowGeometry = .{};
        if (map.get("left")) |v| geometry.x = @max(0, clampI32(parseInteger(v)));
        if (map.get("top")) |v| geometry.y = @max(0, clampI32(parseInteger(v)));
        if (map.get("width")) |v| {
            const width = clampI32(parseInteger(v));
            if (width != 0) geometry.width = @max(min_window_size, width);
        }
        if (map.get("height")) |v| {
            const height = clampI32(parseInteger(v));
            if (height != 0) geometry.height = @max(min_window_size, height);
        }
        return geometry;
    }

    fn clampI32(value: i64) i32 {
        return @intCast(std.math.clamp(value, std.math.minInt(i32), std.math.maxInt(i32)));
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

    // Step 1: "If we cannot show simple dialogs for this, then return null."
    if (sandboxedModals(internal)) return null;

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

/// Operation: getComputedStyle (CSSOM 7.2)
/// https://drafts.csswg.org/cssom-1/#dom-window-getcomputedstyle
///
/// Steps 1-3 here; steps 4-5 - which declarations, and their resolved
/// values - are the returned object's, which reads them live on every
/// access (CSSStyleDeclaration's `computed` kind, through dom.style).
pub fn call_getComputedStyle(instance: *runtime.Instance, elt: *runtime.Instance, pseudoElt: webidl.Opt(?typedefs.CSSOMString)) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // 2. "Let obj be elt."
    var target: @import("dom").style.ComputedFor = .{ .element = elt };
    var name_buffer: [64]u8 = undefined;
    // 3. "If pseudoElt is provided, is not the empty string, and starts with
    // a colon": parse it as a <pseudo-element-selector>; failure, ::slotted()
    // or ::part() makes obj null; otherwise obj is that pseudo-element.
    if (pseudoElt.wasPassed()) if (pseudoElt.getValue()) |given| {
        const text = given.asSlice();
        if (text.len > 0 and text[0] == ':') {
            if (pseudoElementName(internal.allocator, text, &name_buffer)) |name| {
                target.pseudo = name;
            } else target.no_object = true;
        }
    };
    // 6. "Return a live CSSStyleProperties object" - computed and readonly,
    // its owner node obj.
    return interfaces.CSSStyleProperties.initWith(internal.allocator, instance.ctx, .{ .computed_for = target });
}

/// The pseudo-element `text` names when it parses as a
/// <pseudo-element-selector> - lowercase, no colons, into `buffer` - or
/// null (and for ::slotted() and ::part(), which getComputedStyle does not
/// take). CSS 2's single-colon forms count (CSSOM 7.2 step 3's note).
fn pseudoElementName(allocator: std.mem.Allocator, text: []const u8, buffer: []u8) ?[]const u8 {
    const selector = @import("selector");
    var list = selector.parse(allocator, text) catch return null;
    defer list.deinit();
    if (list.selectors.len != 1) return null;
    const complex = &list.selectors[0];
    if (complex.combinators.len != 0) return null;
    var name: ?[]const u8 = null;
    for (complex.compound.simple_selectors) |*simple| switch (simple.*) {
        .PseudoElement => |p| name = p.name,
        // Only the implicit universal selector may stand beside it.
        .Universal => {},
        else => return null,
    };
    const found = name orelse return null;
    if (std.ascii.eqlIgnoreCase(found, "slotted") or std.ascii.eqlIgnoreCase(found, "part")) return null;
    if (found.len > buffer.len) return null;
    return std.ascii.lowerString(buffer[0..found.len], found);
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

// A document's ID and named-property maps (domindex1): its elements' IDs,
// name attributes and types, kept by insertion, removal and attribute change.
const tree_ordered_map = @import("dom").tree_ordered_map;
const clock = @import("clock");

/// HTML 7.2.2.3 "the document-tree child navigable target name property
/// set", asked for one name (domindex1): the window of the FIRST child
/// navigable whose target name is `name` (step 3, firstNamedChildren) when
/// that navigable's active document is same origin with `window`'s (step
/// 5.2), else null - "so that a cross-origin frame's name is not exposed":
/// a later same-origin child of the same name does not bring the name back
/// (html/browsers/the-window-object/named-access-on-the-window-object/
/// cross-origin-named-access.sub.html). A child with no active window
/// exposes nothing.
fn childNavigableNamed(window: *runtime.Instance, internal: *InternalState, name: []const u8) ?*runtime.Instance {
    if (name.len == 0) return null;
    var children = documentTreeChildNavigables(window, internal, internal.allocator);
    defer children.deinit(internal.allocator);
    return childNavigableNamedIn(window, internal, children.items, name);
}

/// The first same-named child decides visibility, even when its origin
/// prevents exposure. Reuse one document-tree list during enumeration.
fn childNavigableNamedIn(window: *runtime.Instance, internal: *InternalState, children: []const @import("dom").navigables.ChildNavigable, name: []const u8) ?*runtime.Instance {
    if (name.len == 0) return null;
    for (children) |entry| {
        const child = entry.browsing_context;
        if (!std.mem.eql(u8, child.target_name, name)) continue;
        const raw = child.getActiveWindow() orelse return null;
        const child_window: *runtime.Instance = @ptrCast(@alignCast(raw));
        const child_internal = getInternal(child_window) orelse return null;
        // The records decide only between opaque origins: for a tuple origin
        // a record shared from an initial about:blank is not yet exact for
        // the document that replaced it (effectiveOrigin), and two windows
        // sharing one would read as one origin across a cross-origin
        // navigation.
        const parent_origin = effectiveOrigin(window, internal);
        const child_origin = effectiveOrigin(child_window, child_internal);
        const both_opaque = std.mem.eql(u8, parent_origin, "null") and std.mem.eql(u8, child_origin, "null");
        const same_origin = @import("dom").origin_record.sameOrigin(
            .{ .serialized = parent_origin, .record = if (both_opaque) settingsOriginRecord(window) else null },
            .{ .serialized = child_origin, .record = if (both_opaque) settingsOriginRecord(child_window) else null },
        );
        return if (same_origin) child_window else null;
    }
    return null;
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

    // Steps 1-2: a document-tree child navigable named so - its WindowProxy.
    if (childNavigableNamed(instance, internal, name)) |child_window| return runtime.JSValue.fromInstance(child_window);

    // Check document for named elements (elements with matching id or name attributes)
    // The document might be stored in internal.document, OR we might need to get it from the
    // browsing context's active document
    const document: ?*runtime.Instance = internal.document orelse blk: {
        const active_doc_ptr = internal.browsing_context.getActiveDocument() orelse break :blk null;
        break :blk @ptrCast(@alignCast(active_doc_ptr));
    };

    // domindex1: HTML 7.2.2.3 steps 3-4 for the rest of the named objects -
    // embed, form, img and object elements by name, every element by ID -
    // from the document's maps (dom.tree_ordered_map), not a walk: one
    // element is that element; several are "an HTMLCollection rooted at
    // window's associated Document, whose filter matches only named objects
    // of window with the name name", the same one while its wrapper lives
    // (Blink Document::WindowNamedItems' cached collection).
    if (document) |doc| {
        const objects = tree_ordered_map.named(doc, .window, name);
        if (objects.count == 0) return null;
        if (objects.count == 1) return runtime.JSValue.fromInstance(objects.first.?);
        return .{ .instance = try tree_ordered_map.namedCollection(doc, .window, name) };
    }

    return null;
}

/// Check if a named property exists.
/// This is called by window_properties.zig for the WindowProperties named property query.
pub fn hasNamedProperty(instance: *runtime.Instance, name: []const u8) bool {
    const internal = getInternal(instance) orelse return false;

    // The child navigables' target names this window exposes.
    if (childNavigableNamed(instance, internal, name) != null) return true;

    // Check document for named elements
    // Use internal.document if available, otherwise get from browsing context
    const document: ?*runtime.Instance = internal.document orelse blk: {
        const active_doc_ptr = internal.browsing_context.getActiveDocument() orelse break :blk null;
        break :blk @ptrCast(@alignCast(active_doc_ptr));
    };
    // domindex1: one lookup in the document's maps, not a walk.
    if (document) |doc| {
        if (tree_ordered_map.isNamed(doc, .window, name)) return true;
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

    // The document-tree child navigable target name property set: each name
    // once, and only while its first navigable is same origin (domindex1).
    var children = documentTreeChildNavigables(instance, internal, allocator);
    defer children.deinit(allocator);
    for (children.items) |entry| {
        const child = entry.browsing_context;
        if (childNavigableNamedIn(instance, internal, children.items, child.target_name) == null) continue;
        const listed = for (names.items) |existing| {
            if (std.mem.eql(u8, existing.asSlice(), child.target_name)) break true;
        } else false;
        if (listed) continue;
        const name = try runtime.DOMString.initDupe(allocator, child.target_name);
        names.append(allocator, name) catch |err| {
            var dropped = name;
            dropped.deinit(allocator);
            return err;
        };
    }

    // Add named elements from document
    // Use internal.document if available, otherwise get from browsing context
    const document: ?*runtime.Instance = internal.document orelse blk: {
        const active_doc_ptr = internal.browsing_context.getActiveDocument() orelse break :blk null;
        break :blk @ptrCast(@alignCast(active_doc_ptr));
    };
    // domindex1: the element-contributed names in tree order, ID before
    // name, from the walk the document's maps' rule makes (HTML 7.2.2.3's
    // list "ignoring later duplicates").
    if (document) |doc| {
        const from_elements = try tree_ordered_map.supportedNames(doc, .window, allocator);
        defer allocator.free(from_elements);
        // Each name is moved into `names` or freed here, the rest on a failure.
        var taken: usize = 0;
        errdefer for (from_elements[taken..]) |*name| name.deinit(allocator);
        try names.ensureUnusedCapacity(allocator, from_elements.len);
        for (from_elements) |*name| {
            taken += 1;
            const duplicate = for (names.items) |existing| {
                if (std.mem.eql(u8, existing.asSlice(), name.asSlice())) break true;
            } else false;
            if (duplicate) name.deinit(allocator) else names.appendAssumeCapacity(name.*);
        }
    }

    return names.toOwnedSlice(allocator);
}

/// Getter for crashReport
pub fn get_crashReport(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: requestResize
pub fn call_requestResize(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setResizable
pub fn call_setResizable(instance: *runtime.Instance, resizable: bool) anyerror!runtime.JSValue {
    _ = instance;
    _ = resizable;
    return error.NotImplemented;
}

/// Operation: maximize
pub fn call_maximize(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: restore
pub fn call_restore(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: minimize
pub fn call_minimize(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}
