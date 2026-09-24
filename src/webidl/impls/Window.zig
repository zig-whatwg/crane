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
const WindowOrWorkerGlobalScopeImpl = @import("WindowOrWorkerGlobalScope.zig");

// HTML Window infrastructure modules (html_core - interface-free)
const html_core = @import("html_core");
const BrowsingContext = html_core.window.BrowsingContext;
const UIBackend = html_core.window.UIBackend;
const StubUIBackend = html_core.window.StubUIBackend;
const AnimationFrameScheduler = html_core.window.AnimationFrameScheduler;
const StubFrameTimingBackend = html_core.window.StubFrameTimingBackend;

// Event loop types for requestIdleCallback
const event_loop = html_core.event_loop;
const IdleCallbackManager = event_loop.IdleCallbackManager;

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
    navigator: ?*runtime.Instance = null,
    performance: ?*runtime.Instance = null,
    custom_elements: ?*runtime.Instance = null,

    /// BarProp instances (lazily created)
    locationbar: ?*runtime.Instance = null,
    menubar: ?*runtime.Instance = null,
    personalbar: ?*runtime.Instance = null,
    scrollbars: ?*runtime.Instance = null,
    statusbar: ?*runtime.Instance = null,
    toolbar: ?*runtime.Instance = null,

    /// Screen-related (lazily created)
    screen: ?*runtime.Instance = null,
    visual_viewport: ?*runtime.Instance = null,

    /// Idle callback manager for requestIdleCallback/cancelIdleCallback
    /// Spec: https://w3c.github.io/requestidlecallback/
    idle_callback_manager: ?*IdleCallbackManager = null,

    /// Storage instances (lazily created)
    /// HTML Standard § 12.2.2 (sessionStorage), § 12.2.3 (localStorage)
    local_storage: ?*runtime.Instance = null,
    session_storage: ?*runtime.Instance = null,
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

    pub fn init(allocator: Allocator) !InternalState {
        return .{
            .allocator = allocator,
            .browsing_context = try BrowsingContext.initTopLevel(allocator),
            .stub_ui_backend = StubUIBackend.init(.{}),
            .stub_timing_backend = StubFrameTimingBackend.init(),
            .ui_backend = undefined, // Set by caller after init
        };
    }

    pub fn deinit(self: *InternalState) void {
        // The popups first: each integration destroys its navigable's context
        // (a child of this window's, and already gone if this window's page is
        // being torn down - destroyChildContext runs once per context).
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

        // Clean up idle callback manager if created
        if (self.idle_callback_manager) |manager| {
            manager.deinit();
            self.allocator.destroy(manager);
        }

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

        // Free origin if allocated (not the default "null" string literal)
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
    // Copy the origin string since it may be from temporary storage
    const origin_copy = try internal.allocator.dupe(u8, origin);
    // Free the old origin if it was allocated (not the default "null")
    if (!std.mem.eql(u8, internal.origin, "null")) {
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

/// Initialize Window instance
/// Creates the instance with a new top-level browsing context.
/// Chains to EventTarget.init() to ensure EventTarget internal state is registered.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Other types reach a window's container through this hook.
    @import("dom").navigable_container.install(.{ .of = &containerOf });

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

/// Deinitialize Window instance
pub fn deinit(instance: *runtime.Instance) void {
    // Mark as cleaned up in V8 wrapper cache to prevent double-free
    // Window is in the wrapper cache, and context_manager.deinit cleans up Window
    // before calling wrapper_cache.deinit. Without this marker, wrapper_cache
    // would try to call deinit again.
    const context_manager = @import("v8").context_manager;
    context_manager.markInstanceCleanedUp(instance);

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
pub fn setBoundV8Global(instance: *runtime.Instance, v8_global: *anyopaque) void {
    if (getInternal(instance)) |internal| {
        internal.bound_v8_global = v8_global;
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
    internal.document = document;
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
    const v8 = @import("v8");
    const v8_isolate = v8.ffi.v8_Isolate_GetCurrent() orelse return error.InvalidStateError;

    // Get the accessor Window for cross-origin security checks.
    //
    // V8's context stack doesn't work correctly for cross-context property access:
    // when accessing `parent.document` from an iframe, V8 enters the parent's context
    // for the property access, making GetEnteredOrMicrotaskContext return the wrong context.
    //
    // We use a Zig-level accessor stack that is pushed/popped by script execution.
    // This correctly tracks which Window is executing JavaScript code.
    //
    // If no accessor is on the stack, fall back to V8's current context.
    // This handles:
    // - Native/internal calls (no JavaScript on the stack)
    // - Callbacks where we haven't pushed the accessor
    const accessor_window: ?*runtime.Instance = v8.context_manager.getCurrentAccessorWindow() orelse blk: {
        // No accessor on stack - fall back to V8's current context
        const current_ctx = v8.ffi.v8_Isolate_GetCurrentContext(v8_isolate) orelse break :blk null;
        defer v8.ffi.v8_Context_Dispose(current_ctx);
        break :blk v8.context_manager.getWindowForContext(current_ctx);
    };

    // Safety check: if accessing own document (same Window), always allow.
    // This handles initialization cases where the entered context might not
    // be fully set up, but the access is clearly same-origin (self-access).
    if (accessor_window) |aw| {
        if (aw == instance) {
            // Accessing own document - always allowed
            return internal.document orelse error.NotImplemented;
        }
    }

    // Cross-origin check for accessing other Window's document
    const accessor_origin: []const u8 = if (accessor_window) |aw|
        if (getInternal(aw)) |aw_internal| effectiveOrigin(aw, aw_internal) else "null"
    else
        // No accessor window at all - likely internal call, allow access
        effectiveOrigin(instance, internal);

    // Get this Window's origin (target origin)
    const target_origin = effectiveOrigin(instance, internal);

    // Cross-origin check:
    // - If accessor has opaque origin ("null"), it's always cross-origin (except self-access handled above)
    // - If target has opaque origin ("null"), it's always cross-origin
    // - Otherwise, compare origin strings
    const is_same_origin = !std.mem.eql(u8, accessor_origin, "null") and
        !std.mem.eql(u8, target_origin, "null") and
        std.mem.eql(u8, accessor_origin, target_origin);

    if (!is_same_origin) {
        // Cross-origin access to document is blocked per spec.
        return error.SecurityError;
    }

    return internal.document orelse error.NotImplemented;
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
    // TODO: Create Location instance lazily
    return internal.location orelse error.NotImplemented;
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

    // Associate this History with the window
    if (HistoryImpl.getInternal(history)) |history_internal| {
        history_internal.window = instance;

        // Initialize with a single entry for the current document's URL
        // Per spec, session history starts with one entry for the initial document
        const initial_entry = HistoryImpl.HistoryEntry{
            .url = try internal.allocator.dupe(u8, "about:blank"),
            .state = null,
        };
        try history_internal.entries.append(internal.allocator, initial_entry);
        history_internal.current_index = 0;
    }

    // Cache for future access
    internal.history = history;
    return history;
}

/// Getter for navigation
/// Per spec: Returns the Navigation object for this window.
pub fn get_navigation(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // TODO: Create Navigation instance lazily
    _ = internal;
    return error.NotImplemented;
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
    return registry;
}

// ============================================================================
// BarProp Properties (§7.2.2)
// ============================================================================

/// Getter for locationbar
pub fn get_locationbar(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.locationbar orelse error.NotImplemented;
}

/// Getter for menubar
pub fn get_menubar(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.menubar orelse error.NotImplemented;
}

/// Getter for personalbar
pub fn get_personalbar(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.personalbar orelse error.NotImplemented;
}

/// Getter for scrollbars
pub fn get_scrollbars(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.scrollbars orelse error.NotImplemented;
}

/// Getter for statusbar
pub fn get_statusbar(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.statusbar orelse error.NotImplemented;
}

/// Getter for toolbar
pub fn get_toolbar(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.toolbar orelse error.NotImplemented;
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
    return internal.closed or internal.browsing_context.is_closed;
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
    return @intCast(internal.browsing_context.children.items.len);
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
    const children = internal.browsing_context.children.items;

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

    // Walk up the parent chain to find the top-level context
    var ctx = internal.browsing_context;
    while (ctx.parent) |parent| {
        ctx = parent;
    }

    // If we're already at the top, return self
    if (ctx == internal.browsing_context) {
        return getWindowProxy(instance);
    }

    // Get the active Window from the top browsing context
    if (ctx.getActiveWindow()) |top_window_ptr| {
        const top_window: *runtime.Instance = @ptrCast(@alignCast(top_window_ptr));
        return @ptrCast(top_window);
    }

    // Fallback to self if top window not found (shouldn't happen if browsing context is set up correctly)
    return getWindowProxy(instance);
}

/// Getter for opener
/// Per spec: Returns the WindowProxy of the opener browsing context.
pub fn get_opener(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // If disowned, return null
    if (internal.browsing_context.disowned) {
        return runtime.JSValue.jsNull;
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

    // Safety check: browsing_context should never be null for a valid Window,
    // but check anyway to prevent segfault in case of corruption/cleanup race
    const bc_ptr = @intFromPtr(internal.browsing_context);
    if (bc_ptr == 0 or bc_ptr < 0x1000) {
        // Invalid pointer - check if this Window has a bound V8 global to return
        if (internal.bound_v8_global) |bound_global| {
            // Return the bound global directly - this will be dereferenced by SetReturnValueGlobal
            // Cast through usize to satisfy alignment requirements
            return @ptrFromInt(@intFromPtr(bound_global));
        }
        return getWindowProxy(instance);
    }

    // Per HTML spec §7.2.2, the parent getter:
    // 1. If this browsing context has a parent, return parent's WindowProxy
    // 2. Otherwise, return this Window's WindowProxy (self)
    if (internal.browsing_context.parent) |parent_bc| {
        // Get the active Window from the parent browsing context
        if (parent_bc.getActiveWindow()) |parent_window_ptr| {
            // Cast from *anyopaque to *runtime.Instance
            const parent_window: *runtime.Instance = @ptrCast(@alignCast(parent_window_ptr));
            return @ptrCast(parent_window);
        }
    }

    // If no parent or no parent window, return self per spec
    return getWindowProxy(instance);
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
pub fn get_navigator(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // TODO: Create Navigator instance lazily
    return internal.navigator orelse error.NotImplemented;
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
        internal.origin,
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

/// Getter for origin
/// WindowOrWorkerGlobalScope `origin`: the serialization of the relevant
/// settings object's origin - this window's document's.
/// The binding frees the returned string.
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return instance.ctx.allocator.dupe(u8, effectiveOrigin(instance, internal));
}

/// Getter for isSecureContext
/// Per HTML spec §7.1.1: Returns true if this window's global object is in a secure context.
/// A secure context is one where the top-level document was loaded over HTTPS,
/// from localhost, or from a file:// URL.
/// Spec: https://w3c.github.io/webappsec-secure-contexts/#is-settings-object-contextually-secure
pub fn get_isSecureContext(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    return internal.is_secure_context;
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

/// Getter for crossOriginIsolated
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#dom-crossoriginisolated
///
/// Returns true if this window's browsing context is cross-origin isolated.
/// A browsing context is cross-origin isolated when:
/// 1. COOP (Cross-Origin-Opener-Policy) is "same-origin"
/// 2. COEP (Cross-Origin-Embedder-Policy) is "require-corp" or "credentialless"
///
/// This enables access to powerful APIs like SharedArrayBuffer.
pub fn get_crossOriginIsolated(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    return internal.browsing_context.isCrossOriginIsolated();
}

/// Getter for indexedDB
/// IndexedDB spec: Returns the IDBFactory object for this origin.
/// https://w3c.github.io/IndexedDB/#dom-windoworworkerglobalscope-indexeddb
pub fn get_indexedDB(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Return cached instance if available
    if (internal.indexeddb_factory) |factory_instance| {
        return factory_instance;
    }

    // Create the backend IDBFactory
    const backend = internal.allocator.create(IDBFactoryBackend) catch return error.OutOfMemory;
    errdefer internal.allocator.destroy(backend);

    backend.* = IDBFactoryBackend.init(internal.allocator);
    backend.setStorageKey(internal.origin);

    // Create the WebIDL IDBFactory instance
    const factory_instance = interfaces.IDBFactory.init(internal.allocator, instance.ctx) catch {
        backend.deinit();
        internal.allocator.destroy(backend);
        return error.OutOfMemory;
    };

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

/// Getter for trustedTypes
pub fn get_trustedTypes(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for performance
/// Per spec: Returns the Performance object for this window.
pub fn get_performance(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.performance orelse error.NotImplemented;
}

/// Getter for caches
/// Service Worker spec: Returns the CacheStorage object for this origin.
/// https://w3c.github.io/ServiceWorker/#self-caches
pub fn get_caches(instance: *runtime.Instance) anyerror!*runtime.Instance {
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

/// Getter for sessionStorage
/// HTML Standard § 12.2.2
/// Returns the Storage object for this browsing context's session storage area.
pub fn get_sessionStorage(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Return cached instance if available
    if (internal.session_storage) |storage_instance| {
        return storage_instance;
    }

    // Get the browsing context ID for session storage scoping
    const context_id = internal.browsing_context.id;

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
        backend.deinit();
        internal.allocator.destroy(backend);
        return error.OutOfMemory;
    };

    // Cache both
    internal.session_storage_backend = backend;
    internal.session_storage = storage_instance;

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
        internal.allocator.destroy(backend);
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
        backend.deinit();
        internal.allocator.destroy(backend);
        return error.OutOfMemory;
    };

    // Cache both
    internal.local_storage_backend = backend;
    internal.local_storage = storage_instance;

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
    // 8.3). The entered context is the caller's: the iframe's, for
    // `parent.postMessage(...)`.
    const v8 = @import("v8");
    const v8_isolate = v8.ffi.v8_Isolate_GetCurrent() orelse return error.InvalidStateError;
    const incumbent_ctx = v8.ffi.v8_Isolate_GetEnteredOrMicrotaskContext(v8_isolate) orelse
        v8.ffi.v8_Isolate_GetCurrentContext(v8_isolate) orelse return error.InvalidStateError;
    defer v8.ffi.v8_Context_Dispose(incumbent_ctx);
    const source_window = v8.context_manager.getWindowForContext(incumbent_ctx);
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
    var serialized = try SerializedMessage.serialize(allocator, message);
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
    // targetWindow.
    const loop = instance.ctx.getOptionalEventLoop() orelse {
        // No loop to queue on (a context built for tests): the message is
        // still owed, so deliver it now rather than lose it.
        runPostedMessage(posted);
        return;
    };
    loop.queueTask(.{ .callback = &runPostedMessage, .context = posted, .drop = &dropPostedMessage });
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
    /// V8's wire format, malloc'd by the serializer.
    bytes: []u8,

    /// Step 7. Primitives and strings arrive already converted; an object goes
    /// through V8's serializer, which throws the DataCloneError itself.
    fn serialize(allocator: Allocator, value: runtime.JSValue) !SerializedMessage {
        return switch (value) {
            .undefined => .undefined,
            .null => .null,
            .boolean => |b| .{ .boolean = b },
            .number => |n| .{ .number = n },
            .string => |s| .{ .string = try allocator.dupe(u8, s.data) },
            .handle => |h| blk: {
                const v8 = @import("v8");
                var no_transfer: [1]*v8.ffi.Value = undefined;
                var no_buffers: [1]v8.ffi.ArrayBufferTransferData = undefined;
                var size: usize = 0;
                var code: c_int = 0;
                const bytes = v8.ffi.v8_Value_StructuredSerializeWithTransfer(
                    @ptrCast(@alignCast(h.ptr)),
                    &no_transfer,
                    0,
                    &size,
                    &no_buffers,
                    &code,
                ) orelse return if (code == 3) error.ExceptionPending else error.DataCloneError;
                break :blk .{ .bytes = bytes[0..size] };
            },
            // A platform object the binding handed over unwrapped. None is
            // [Serializable] here yet.
            .instance => error.DataCloneError,
        };
    }

    /// Step 8.4, into the realm the caller has entered. The value is OWNED - a
    /// string or a Global - and `createPostMessageEvent` takes it.
    fn deserialize(self: *SerializedMessage) !runtime.JSValue {
        switch (self.*) {
            .undefined => return runtime.JSValue.jsUndefined,
            .null => return runtime.JSValue.jsNull,
            .boolean => |b| return runtime.JSValue.fromBoolean(b),
            .number => |n| return runtime.JSValue.fromNumber(n),
            .string => |s| {
                self.* = .undefined; // moved into the value
                return .{ .string = .{ .data = s, .owned = true } };
            },
            .bytes => |b| {
                const v8 = @import("v8");
                const no_buffers: [1]v8.ffi.ArrayBufferTransferData = undefined;
                var code: c_int = 0;
                const value = v8.ffi.v8_Value_DeserializeWithTransfer_CrossIsolate(b.ptr, b.len, &no_buffers, 0, &code) orelse
                    return error.DataCloneError;
                return .{ .handle = .{ .ptr = @ptrCast(value), .needs_disposal = true, .handle_scope = .global } };
            },
        }
    }

    fn deinit(self: *SerializedMessage, allocator: Allocator) void {
        switch (self.*) {
            .string => |s| allocator.free(s),
            .bytes => |b| @import("v8").ffi.v8_Free_SerializedBuffer(b.ptr),
            else => {},
        }
        self.* = .undefined;
    }

    /// Release a deserialized value that no event took.
    fn release(allocator: Allocator, value: runtime.JSValue) void {
        switch (value) {
            .string => |s| if (s.owned) allocator.free(s.data),
            .handle => |h| @import("v8").ffi.v8_Global_Dispose(@ptrCast(@alignCast(h.ptr))),
            else => {},
        }
    }
};

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

    // A task runs from the event loop, not from V8: there is no HandleScope
    // and no entered context unless it opens them, and wrapping the event for
    // a listener without them is a V8 CHECK (SIGTRAP), not an error. Entering
    // the TARGET's context also makes it the realm step 8.4 deserializes into.
    // A null scope means that context is gone.
    const v8 = @import("v8");
    const scope = v8.JsScope.init(target.ctx) orelse return;
    defer scope.deinit();

    // Step 8.3.
    const source: ?*runtime.Instance = if (posted.source) |sw|
        (if (runtime.SlabAllocator.generationOf(sw) == posted.source_generation) sw else null)
    else
        null;

    // Steps 8.4-8.5. A value that will not deserialize is a messageerror.
    const data = posted.message.deserialize() catch {
        fireMessageEvent(target, "messageerror", runtime.JSValue.jsUndefined, posted.origin, source);
        return;
    };

    // Step 8.7.
    fireMessageEvent(target, "message", data, posted.origin, source);
}

/// Fire `event_type` at `target` as a MessageEvent that takes `data`.
fn fireMessageEvent(target: *runtime.Instance, event_type: []const u8, data: runtime.JSValue, origin: []const u8, source: ?*runtime.Instance) void {
    const v8 = @import("v8");
    const MessageEventImpl = @import("MessageEvent.zig");
    const event = MessageEventImpl.createPostMessageEvent(target.ctx.allocator, target.ctx, event_type, data, origin, source) catch {
        SerializedMessage.release(target.ctx.allocator, data);
        return;
    };
    const generation = runtime.SlabAllocator.generationOf(event);

    _ = interfaces.EventTarget.call_dispatchEvent(target, event) catch {};

    // Who owns the event now. A GC during the dispatch may already have
    // collected it, once the last listener let go of the wrapper - then its
    // slot has moved on. A listener that kept it left a wrapper in the cache,
    // and V8 frees it when that dies. Only an event nothing ever wrapped is
    // still ours. Freeing it regardless is what this code used to do, and
    // `await new Promise(r => addEventListener("message", r))` then read the
    // event after it was gone.
    if (runtime.SlabAllocator.generationOf(event) != generation) return;
    if (event.ctx.getV8WrapperCacheStorage()) |cache_storage| {
        const cache: *v8.WrapperCache = @ptrCast(@alignCast(cache_storage));
        if (cache.get(event) != null) return;
    }
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

/// Operation: scroll
/// Per CSSOM View: Scrolls to a particular position.
pub fn call_scroll(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ScrollToOptions)) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if window is closed
    if (internal.closed) {
        return error.NotImplemented;
    }

    // Apply scroll options if provided
    if (options.wasPassed()) {
        const opts = options.getValue();
        if (opts.left) |left| {
            internal.scroll_x = left;
        }
        if (opts.top) |top| {
            internal.scroll_y = top;
        }
        // TODO: Handle behavior (smooth vs instant) from opts.base.behavior
    }

    return error.NotImplemented;
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

/// Operation: setTimeout
pub fn call_setTimeout(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
    _ = instance;
    _ = handler;
    _ = timeout;
    _ = arguments;
    return error.NotImplemented;
}

/// Operation: clearInterval
pub fn call_clearInterval(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    _ = instance;
    _ = id;
    return error.NotImplemented;
}

/// Operation: fetch
pub fn call_fetch(instance: *runtime.Instance, input: typedefs.RequestInfo, init_data: webidl.Opt(dictionaries.RequestInit)) anyerror!runtime.JSValue {
    _ = instance;
    _ = input;
    _ = init_data;
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

/// Operation: scrollBy
/// Per CSSOM View: Scrolls by a given amount.
pub fn call_scrollBy(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ScrollToOptions)) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if window is closed
    if (internal.closed) {
        return error.NotImplemented;
    }

    // Apply scroll delta if provided
    if (options.wasPassed()) {
        const opts = options.getValue();
        if (opts.left) |left| {
            internal.scroll_x += left;
        }
        if (opts.top) |top| {
            internal.scroll_y += top;
        }
        // TODO: Handle behavior (smooth vs instant) from opts.base.behavior
    }

    return error.NotImplemented;
}

/// Operation: releaseEvents
/// Per spec: Legacy no-op method for backwards compatibility.
pub fn call_releaseEvents(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    // No-op per spec
}

/// Operation: atob
pub fn call_atob(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.ByteString {
    _ = instance;
    _ = data;
    return error.NotImplemented;
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

/// Operation: btoa
pub fn call_btoa(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.DOMString {
    _ = instance;
    _ = data;
    return error.NotImplemented;
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
/// Queues a callback to be executed during browser idle periods.
pub fn call_requestIdleCallback(instance: *runtime.Instance, callback: callbacks.IdleRequestCallback, options: webidl.Opt(dictionaries.IdleRequestOptions)) anyerror!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if window is closed
    if (internal.closed) {
        return 0; // Return 0 for closed window
    }

    // Lazily create the idle callback manager
    if (internal.idle_callback_manager == null) {
        const manager = try internal.allocator.create(IdleCallbackManager);
        manager.* = IdleCallbackManager.init(internal.allocator);
        internal.idle_callback_manager = manager;
    }

    const manager = internal.idle_callback_manager.?;

    // Get timeout from options (if specified)
    const timeout_ms: ?i64 = if (options.wasPassed()) blk: {
        const opts = options.getValue();
        if (opts.timeout) |timeout| {
            break :blk @intCast(timeout);
        }
        break :blk null;
    } else null;

    // Get current time (use std.time for now)
    const current_time = clock.monotonicMillis();

    // Register the idle callback
    // Note: The callback is stored but invocation requires event loop integration.
    // In a full implementation, the event loop would invoke pending idle callbacks
    // during idle periods (when no tasks are runnable).
    // For now, we store the callback and return a valid handle.
    const handle = try manager.requestIdleCallback(
        // We need a wrapper that adapts the JS callback to our internal signature
        // For now, use a placeholder that would be replaced by proper V8 integration
        struct {
            fn wrapper(ctx: ?*anyopaque, deadline: *event_loop.IdleDeadline) void {
                _ = ctx;
                _ = deadline;
                // In full implementation: invoke the JS callback via V8
                // v8.callFunction(callback, deadline_wrapper);
            }
        }.wrapper,
        @ptrCast(@constCast(&callback)), // Store callback reference
        timeout_ms,
        current_time,
    );

    return handle;
}

/// Operation: queueMicrotask
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-queuemicrotask
pub fn call_queueMicrotask(instance: *runtime.Instance, callback: callbacks.VoidFunction) anyerror!void {
    // Delegate to WindowOrWorkerGlobalScope mixin implementation
    return WindowOrWorkerGlobalScopeImpl.call_queueMicrotask(instance, callback);
}

/// Operation: structuredClone
/// Spec: https://html.spec.whatwg.org/multipage/structured-data.html#dom-structuredclone
pub fn call_structuredClone(instance: *runtime.Instance, value: runtime.JSValue, options: webidl.Opt(dictionaries.StructuredSerializeOptions)) anyerror!runtime.JSValue {
    // Delegate to WindowOrWorkerGlobalScope mixin implementation
    return WindowOrWorkerGlobalScopeImpl.call_structuredClone(instance, value, options);
}

/// Operation: close
/// Per spec §7.4.6: Closes the browsing context if it's script-closable.
pub fn call_close(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if already closed
    if (internal.closed) {
        return;
    }

    // Check if the browsing context is script-closable
    // A browsing context is script-closable if:
    // 1. It's an auxiliary browsing context (opened via window.open)
    // 2. Or it's a top-level traversable with a single session history entry
    if (internal.browsing_context.isScriptClosable()) {
        internal.browsing_context.close();
        internal.closed = true;
    }
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

    // TODO: Implement stop - abort document loading
    // This should abort any ongoing navigation
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
/// Deviation, stated: `_self`, `_parent` and `_top` return this window without
/// navigating it - navigating the page a test runs in is not supported - so
/// only a new or named navigable is navigated.
pub fn call_open(instance: *runtime.Instance, url: webidl.Opt(runtime.USVString), target: webidl.Opt(runtime.DOMString), features: webidl.Opt(runtime.DOMString)) anyerror!?typedefs.WindowProxy {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.closed) return null;
    const allocator = internal.allocator;

    // Step 2: "Let sourceDocument be the entry global object's associated
    // Document" - this window's, whose script called open().
    const source_document = try get_document(instance);

    // Steps 3-4: "Set urlRecord to the result of encoding-parsing a URL given
    // url, relative to sourceDocument"; failure throws a "SyntaxError".
    const url_str: []const u8 = if (url.wasPassed()) url.getValue() else "";
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
        return if (noopener) null else getWindowProxy(instance);
    }

    // A name one of this window's open popups carries is that popup.
    if (!std.ascii.eqlIgnoreCase(target_str, "_blank")) {
        for (internal.auxiliary_navigables.items) |existing| {
            const bc = existing.browsing_context orelse continue;
            if (bc.is_closed or !std.mem.eql(u8, bc.target_name, target_str)) continue;
            const window: *runtime.Instance = @ptrCast(@alignCast(bc.getActiveWindow() orelse continue));
            // Step 16.1: "If urlRecord is not null, then navigate targetNavigable
            // to urlRecord".
            if (url_record) |u| queuePopupNavigation(existing, window, u);
            return if (noopener) null else window;
        }
    }

    // Step 15: a new top-level traversable, auxiliary unless noopener. The
    // machinery is HTMLIFrameElement's, installed when the first iframe
    // element is made: make one if no page has yet. Script never sees it, so
    // it goes as soon as it has done that.
    const auxiliary_navigables = @import("dom").auxiliary_navigables;
    if (!auxiliary_navigables.isInstalled()) {
        const installer = try interfaces.Document.call_createElement(source_document, runtime.DOMString.initInterned("iframe"), webidl.Opt(runtime.JSValue).notPassed());
        installer.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(installer));
    }
    const created = auxiliary_navigables.create(allocator, @ptrCast(internal.browsing_context), internal.origin, window_features.popup) orelse return null;
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
    // initial document it already has. Queued: open() returns the window
    // before its page loads, as it must for `w.onload = f` to hear the load.
    if (url_record) |u| {
        if (!std.mem.startsWith(u8, u, "about:blank")) queuePopupNavigation(integration, created.window, u);
    }

    // Steps 17-18: "If noopener is true or windowType is "new with no
    // opener", then return null. Return targetNavigable's active WindowProxy."
    return if (noopener) null else created.window;
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

/// A popup's navigation, queued by open().
const PopupNavigation = struct {
    allocator: Allocator,
    integration: *html_core.IFrameIntegration,
    window: *runtime.Instance,
    generation: u64,
    url: []u8,

    fn destroy(self: *PopupNavigation) void {
        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }
};

/// Navigate the popup `window` (whose integration is `integration`) to
/// `url`, as a task: HTML navigates asynchronously, and the caller of open()
/// must get the window before its page runs.
fn queuePopupNavigation(integration: *html_core.IFrameIntegration, window: *runtime.Instance, url: []const u8) void {
    const allocator = window.ctx.allocator;
    const navigation = allocator.create(PopupNavigation) catch return;
    const url_copy = allocator.dupe(u8, url) catch {
        allocator.destroy(navigation);
        return;
    };
    navigation.* = .{
        .allocator = allocator,
        .integration = integration,
        .window = window,
        .generation = runtime.SlabAllocator.generationOf(window),
        .url = url_copy,
    };
    const loop = window.ctx.getOptionalEventLoop() orelse {
        runPopupNavigation(navigation);
        return;
    };
    loop.queueTask(.{ .callback = &runPopupNavigation, .context = navigation, .drop = &dropPopupNavigation });
}

fn dropPopupNavigation(context: ?*anyopaque) void {
    const navigation: *PopupNavigation = @ptrCast(@alignCast(context orelse return));
    navigation.destroy();
}

fn runPopupNavigation(context: ?*anyopaque) void {
    const navigation: *PopupNavigation = @ptrCast(@alignCast(context orelse return));
    defer navigation.destroy();
    // Closed, or its page torn down since: nothing is left to navigate.
    if (runtime.SlabAllocator.generationOf(navigation.window) != navigation.generation) return;
    const window_internal = getInternal(navigation.window) orelse return;
    if (window_internal.closed) return;
    // A task runs from the event loop, not from V8: the page's scripts need a
    // scope and the popup's realm entered.
    const scope = @import("v8").JsScope.init(navigation.window.ctx) orelse return;
    defer scope.deinit();
    navigation.integration.navigateToSrc(navigation.url) catch {};
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

/// Operation: scrollTo
/// Per CSSOM View: Same as scroll() - scrolls to a particular position.
pub fn call_scrollTo(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ScrollToOptions)) anyerror!runtime.JSValue {
    return call_scroll(instance, options);
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

/// Operation: reportError
pub fn call_reportError(instance: *runtime.Instance, e: runtime.JSValue) anyerror!void {
    _ = instance;
    _ = e;
    return error.NotImplemented;
}

/// Operation: clearTimeout
pub fn call_clearTimeout(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    _ = instance;
    _ = id;
    return error.NotImplemented;
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

/// Operation: setInterval
pub fn call_setInterval(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
    _ = instance;
    _ = handler;
    _ = timeout;
    _ = arguments;
    return error.NotImplemented;
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

/// Operation: createImageBitmap
pub fn call_createImageBitmap(instance: *runtime.Instance, image: typedefs.ImageBitmapSource, options: webidl.Opt(dictionaries.ImageBitmapOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = image;
    _ = options;
    return error.NotImplemented;
}

/// Operation: cancelIdleCallback
/// Spec: https://w3c.github.io/requestidlecallback/#the-cancelidlecallback-method
/// Cancels a previously scheduled idle callback.
pub fn call_cancelIdleCallback(instance: *runtime.Instance, handle: u32) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if window is closed
    if (internal.closed) {
        return; // No-op for closed window
    }

    // If no idle callback manager exists, nothing to cancel
    if (internal.idle_callback_manager) |manager| {
        manager.cancelIdleCallback(handle);
    }
    // If manager doesn't exist, the callback was never registered - no-op
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

/// Element types that participate in named access via the "name" attribute.
/// Per HTML spec §7.4 "Named access on the Window object":
/// - embed, form, img, object: name attribute exposes the element
/// - iframe, frame, object: name attribute exposes the nested browsing context (if any)
const named_element_types = [_][]const u8{
    "a",
    "embed",
    "form",
    "img",
    "object",
};

/// Element types whose name attribute exposes a browsing context
const browsing_context_element_types = [_][]const u8{
    "iframe",
    "frame",
    "object",
};

/// Check if an element type uses the name attribute for named property access
fn isNamedElementType(local_name: []const u8) bool {
    for (named_element_types) |t| {
        if (std.ascii.eqlIgnoreCase(local_name, t)) return true;
    }
    for (browsing_context_element_types) |t| {
        if (std.ascii.eqlIgnoreCase(local_name, t)) return true;
    }
    return false;
}

/// Check if the element should return a browsing context (contentWindow) for named access
fn shouldReturnBrowsingContext(local_name: []const u8) bool {
    for (browsing_context_element_types) |t| {
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

                // Check 1: Does element have id matching target_name?
                const elem_id = elem_internal.id.asSlice();
                if (elem_id.len > 0 and std.mem.eql(u8, elem_id, target_name)) {
                    // For iframe/frame, return contentWindow
                    if (shouldReturnBrowsingContext(local_name)) {
                        if (getIframeContentWindow(c)) |window_val| {
                            return window_val;
                        }
                    }
                    // Return the element itself
                    return runtime.JSValue.fromInstance(c);
                }

                // Check 2: Does element have name attribute matching target_name?
                // Only certain element types participate in named property access via name attr
                if (isNamedElementType(local_name)) {
                    if (getElementName(elem_internal)) |element_name| {
                        if (std.mem.eql(u8, element_name, target_name)) {
                            // For iframe/frame/object, return contentWindow
                            if (shouldReturnBrowsingContext(local_name)) {
                                if (getIframeContentWindow(c)) |window_val| {
                                    return window_val;
                                }
                            }
                            // Return the element itself
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

/// Get the contentWindow from an iframe element
fn getIframeContentWindow(iframe_element: *runtime.Instance) ?runtime.JSValue {
    // Try to get HTMLIFrameElement's contentWindow via the interface
    // This handles all the lazy initialization and V8 context creation
    const HTMLIFrameElement = interfaces.HTMLIFrameElement;
    const window_proxy = HTMLIFrameElement.get_contentWindow(iframe_element) catch return null;
    if (window_proxy) |wp| {
        // WindowProxy is defined as ?*const anyopaque, convert to JSValue
        return runtime.JSValue.fromInstanceAnyopaque(@ptrCast(@constCast(wp)));
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
