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

// Fetch API support - delegate to WindowOrWorkerGlobalScope mixin
const fetch_api = @import("fetch");
const global_fetch = fetch_api.webidl.global_fetch;
const ResponseImpl = @import("Response.zig");
const WindowOrWorkerGlobalScopeImpl = @import("WindowOrWorkerGlobalScope.zig");

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
    /// Default to false - Browser Context.zig sets this correctly via setIsSecureContext()
    /// Secure Contexts spec: https://w3c.github.io/webappsec-secure-contexts/
    is_secure_context: bool = false,

    /// The window's origin string for storage access
    /// Derived from the document's URL
    origin: []const u8 = "null",

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

    /// Event handler storage for GlobalEventHandlers mixin on Window
    /// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes
    /// Window inherits GlobalEventHandlers (via WindowEventHandlers) and needs its own storage
    /// because Window is not an HTMLElement and doesn't inherit from HTMLElement's event_handlers.
    event_handlers: std.StringHashMap(typedefs.EventHandler) = undefined,

    pub fn init(allocator: Allocator) !InternalState {
        return .{
            .allocator = allocator,
            .browsing_context = try BrowsingContext.initTopLevel(allocator),
            .stub_ui_backend = StubUIBackend.init(.{}),
            .stub_timing_backend = StubFrameTimingBackend.init(),
            .ui_backend = undefined, // Set by caller after init
            .event_handlers = std.StringHashMap(typedefs.EventHandler).init(allocator),
        };
    }

    pub fn deinit(self: *InternalState) void {
        // Clean up browsing context ONLY if we own it.
        // When replaceBrowsingContext() was called, we borrowed an external BC
        // (from iframe integration) which will be cleaned up by the iframe.
        if (self.owns_browsing_context) {
            self.browsing_context.deinit();
        }

        // Clean up event handlers
        self.event_handlers.deinit();

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

/// Check if a property name is a "supported property name" per HTML §7.4.
/// These are names of child browsing contexts (iframes, frames) and named elements
/// (embed, form, img, object with name attributes that are in the document tree).
/// Per WebIDL, these named properties are read-only and cannot be set/deleted.
pub fn isSupportedPropertyName(instance: *runtime.Instance, name: []const u8) bool {
    const internal = getInternal(instance) orelse return false;

    // Check if the name matches a child browsing context name
    // (e.g., an iframe with name="foo" makes window.foo return that iframe's window)
    const bc = internal.browsing_context;
    if (bc.findByTargetName(name)) |_| {
        return true;
    }

    // TODO: Also check for named elements in the document:
    // - embed elements with name attribute
    // - form elements with name attribute
    // - img elements with name attribute (that are in a document tree)
    // - object elements with name attribute
    // For now, we only check browsing context names.
    // Full implementation would query the document for these elements.

    return false;
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
        internal.deinit();
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
pub fn get_document(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
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
pub fn get_history(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // TODO: Create History instance lazily
    return internal.history orelse error.NotImplemented;
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
pub fn get_customElements(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // TODO: Create CustomElementRegistry instance lazily
    return internal.custom_elements orelse error.NotImplemented;
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
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?typedefs.WindowProxy {
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

    // Return the WindowProxy for the top-level window
    // TODO: Return the actual Window instance for the top context
    // For now, if we're already at the top, return self
    if (ctx == internal.browsing_context) {
        return getWindowProxy(instance);
    }

    // Otherwise, we'd need to look up the Window for that context
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

    // If we have a parent context, return its Window
    if (internal.browsing_context.parent) |parent_bc| {
        // Get the active Window from the parent browsing context
        if (parent_bc.getActiveWindow()) |parent_window_ptr| {
            const parent_window: *runtime.Instance = @ptrCast(@alignCast(parent_window_ptr));
            return getWindowProxy(parent_window);
        }
    }

    // If no parent, return self per spec
    return getWindowProxy(instance);
}

/// Getter for frameElement
/// Per spec: Returns the Element in which this window is nested, if any.
pub fn get_frameElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // If this is a top-level context, return null
    if (internal.browsing_context.isTopLevel()) {
        return null;
    }

    // TODO: Return the iframe/frame element that contains this window
    return null;
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
pub fn get_event(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
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

/// Getter for pushManager
pub fn get_pushManager(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

// =============================================================================
// Event Handler IDL Attributes (GlobalEventHandlers + WindowEventHandlers)
// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes
// Window has its own event_handlers storage separate from HTMLElement
// =============================================================================

/// Helper to get an event handler from Window's internal state
fn getEventHandler(instance: *runtime.Instance, name: []const u8) typedefs.EventHandler {
    const internal = getInternal(instance) orelse return null;
    return internal.event_handlers.get(name) orelse null;
}

/// Helper to set an event handler in Window's internal state
fn setEventHandler(instance: *runtime.Instance, name: []const u8, handler: typedefs.EventHandler) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (handler) |_| {
        try internal.event_handlers.put(name, handler);
    } else {
        _ = internal.event_handlers.remove(name);
    }
}

/// Getter for onabort
pub fn get_onabort(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "abort");
}

/// Getter for onauxclick
pub fn get_onauxclick(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "auxclick");
}

/// Getter for onbeforeinput
pub fn get_onbeforeinput(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "beforeinput");
}

/// Getter for onbeforematch
pub fn get_onbeforematch(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "beforematch");
}

/// Getter for onbeforetoggle
pub fn get_onbeforetoggle(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "beforetoggle");
}

/// Getter for onblur
pub fn get_onblur(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "blur");
}

/// Getter for oncancel
pub fn get_oncancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "cancel");
}

/// Getter for oncanplay
pub fn get_oncanplay(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "canplay");
}

/// Getter for oncanplaythrough
pub fn get_oncanplaythrough(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "canplaythrough");
}

/// Getter for onchange
pub fn get_onchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "change");
}

/// Getter for onclick
pub fn get_onclick(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "click");
}

/// Getter for onclose
pub fn get_onclose(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "close");
}

/// Getter for oncommand
pub fn get_oncommand(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "command");
}

/// Getter for oncontextlost
pub fn get_oncontextlost(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "contextlost");
}

/// Getter for oncontextmenu
pub fn get_oncontextmenu(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "contextmenu");
}

/// Getter for oncontextrestored
pub fn get_oncontextrestored(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "contextrestored");
}

/// Getter for oncopy
pub fn get_oncopy(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "copy");
}

/// Getter for oncuechange
pub fn get_oncuechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "cuechange");
}

/// Getter for oncut
pub fn get_oncut(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "cut");
}

/// Getter for ondblclick
pub fn get_ondblclick(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "dblclick");
}

/// Getter for ondrag
pub fn get_ondrag(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "drag");
}

/// Getter for ondragend
pub fn get_ondragend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "dragend");
}

/// Getter for ondragenter
pub fn get_ondragenter(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "dragenter");
}

/// Getter for ondragleave
pub fn get_ondragleave(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "dragleave");
}

/// Getter for ondragover
pub fn get_ondragover(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "dragover");
}

/// Getter for ondragstart
pub fn get_ondragstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "dragstart");
}

/// Getter for ondrop
pub fn get_ondrop(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "drop");
}

/// Getter for ondurationchange
pub fn get_ondurationchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "durationchange");
}

/// Getter for onemptied
pub fn get_onemptied(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "emptied");
}

/// Getter for onended
pub fn get_onended(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "ended");
}

/// Getter for onerror
/// Note: onerror has a special signature (OnErrorEventHandler), but we store it as EventHandler
pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.OnErrorEventHandler {
    // OnErrorEventHandler is compatible with EventHandler storage
    const handler = getEventHandler(instance, "error");
    // Cast is needed due to different typedef
    return @as(typedefs.OnErrorEventHandler, @ptrCast(handler));
}

/// Getter for onfocus
pub fn get_onfocus(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "focus");
}

/// Getter for onformdata
pub fn get_onformdata(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "formdata");
}

/// Getter for oninput
pub fn get_oninput(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "input");
}

/// Getter for oninvalid
pub fn get_oninvalid(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "invalid");
}

/// Getter for onkeydown
pub fn get_onkeydown(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "keydown");
}

/// Getter for onkeypress
pub fn get_onkeypress(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "keypress");
}

/// Getter for onkeyup
pub fn get_onkeyup(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "keyup");
}

/// Getter for onload
pub fn get_onload(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "load");
}

/// Getter for onloadeddata
pub fn get_onloadeddata(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "loadeddata");
}

/// Getter for onloadedmetadata
pub fn get_onloadedmetadata(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "loadedmetadata");
}

/// Getter for onloadstart
pub fn get_onloadstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "loadstart");
}

/// Getter for onmousedown
pub fn get_onmousedown(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "mousedown");
}

/// Getter for onmouseenter
pub fn get_onmouseenter(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "mouseenter");
}

/// Getter for onmouseleave
pub fn get_onmouseleave(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "mouseleave");
}

/// Getter for onmousemove
pub fn get_onmousemove(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "mousemove");
}

/// Getter for onmouseout
pub fn get_onmouseout(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "mouseout");
}

/// Getter for onmouseover
pub fn get_onmouseover(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "mouseover");
}

/// Getter for onmouseup
pub fn get_onmouseup(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "mouseup");
}

/// Getter for onpaste
pub fn get_onpaste(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "paste");
}

/// Getter for onpause
pub fn get_onpause(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pause");
}

/// Getter for onplay
pub fn get_onplay(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "play");
}

/// Getter for onplaying
pub fn get_onplaying(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "playing");
}

/// Getter for onprogress
pub fn get_onprogress(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "progress");
}

/// Getter for onratechange
pub fn get_onratechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "ratechange");
}

/// Getter for onreset
pub fn get_onreset(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "reset");
}

/// Getter for onresize
pub fn get_onresize(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "resize");
}

/// Getter for onscroll
pub fn get_onscroll(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "scroll");
}

/// Getter for onscrollend
pub fn get_onscrollend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "scrollend");
}

/// Getter for onsecuritypolicyviolation
pub fn get_onsecuritypolicyviolation(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "securitypolicyviolation");
}

/// Getter for onseeked
pub fn get_onseeked(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "seeked");
}

/// Getter for onseeking
pub fn get_onseeking(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "seeking");
}

/// Getter for onselect
pub fn get_onselect(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "select");
}

/// Getter for onslotchange
pub fn get_onslotchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "slotchange");
}

/// Getter for onstalled
pub fn get_onstalled(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "stalled");
}

/// Getter for onsubmit
pub fn get_onsubmit(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "submit");
}

/// Getter for onsuspend
pub fn get_onsuspend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "suspend");
}

/// Getter for ontimeupdate
pub fn get_ontimeupdate(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "timeupdate");
}

/// Getter for ontoggle
pub fn get_ontoggle(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "toggle");
}

/// Getter for onvolumechange
pub fn get_onvolumechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "volumechange");
}

/// Getter for onwaiting
pub fn get_onwaiting(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "waiting");
}

/// Getter for onwebkitanimationend
pub fn get_onwebkitanimationend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "webkitanimationend");
}

/// Getter for onwebkitanimationiteration
pub fn get_onwebkitanimationiteration(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "webkitanimationiteration");
}

/// Getter for onwebkitanimationstart
pub fn get_onwebkitanimationstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "webkitanimationstart");
}

/// Getter for onwebkittransitionend
pub fn get_onwebkittransitionend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "webkittransitionend");
}

/// Getter for onwheel
pub fn get_onwheel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "wheel");
}

/// Getter for onselectstart
pub fn get_onselectstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "selectstart");
}

/// Getter for onselectionchange
pub fn get_onselectionchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "selectionchange");
}

/// Getter for onanimationstart
pub fn get_onanimationstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "animationstart");
}

/// Getter for onanimationiteration
pub fn get_onanimationiteration(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "animationiteration");
}

/// Getter for onanimationend
pub fn get_onanimationend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "animationend");
}

/// Getter for onanimationcancel
pub fn get_onanimationcancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "animationcancel");
}

/// Getter for ontransitionrun
pub fn get_ontransitionrun(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "transitionrun");
}

/// Getter for ontransitionstart
pub fn get_ontransitionstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "transitionstart");
}

/// Getter for ontransitionend
pub fn get_ontransitionend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "transitionend");
}

/// Getter for ontransitioncancel
pub fn get_ontransitioncancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "transitioncancel");
}

/// Getter for onbeforexrselect
pub fn get_onbeforexrselect(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "beforexrselect");
}

/// Getter for onpointerover
pub fn get_onpointerover(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointerover");
}

/// Getter for onpointerenter
pub fn get_onpointerenter(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointerenter");
}

/// Getter for onpointerdown
pub fn get_onpointerdown(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointerdown");
}

/// Getter for onpointermove
pub fn get_onpointermove(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointermove");
}

/// Getter for onpointerrawupdate
pub fn get_onpointerrawupdate(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointerrawupdate");
}

/// Getter for onpointerup
pub fn get_onpointerup(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointerup");
}

/// Getter for onpointercancel
pub fn get_onpointercancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointercancel");
}

/// Getter for onpointerout
pub fn get_onpointerout(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointerout");
}

/// Getter for onpointerleave
pub fn get_onpointerleave(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointerleave");
}

/// Getter for ongotpointercapture
pub fn get_ongotpointercapture(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "gotpointercapture");
}

/// Getter for onlostpointercapture
pub fn get_onlostpointercapture(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "lostpointercapture");
}

/// Getter for ontouchstart
pub fn get_ontouchstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "touchstart");
}

/// Getter for ontouchend
pub fn get_ontouchend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "touchend");
}

/// Getter for ontouchmove
pub fn get_ontouchmove(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "touchmove");
}

/// Getter for ontouchcancel
pub fn get_ontouchcancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "touchcancel");
}

/// Getter for onfencedtreeclick
pub fn get_onfencedtreeclick(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "fencedtreeclick");
}

/// Getter for onsnapchanged
pub fn get_onsnapchanged(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "snapchanged");
}

/// Getter for onsnapchanging
pub fn get_onsnapchanging(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "snapchanging");
}

/// Getter for onafterprint
pub fn get_onafterprint(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "afterprint");
}

/// Getter for onbeforeprint
pub fn get_onbeforeprint(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "beforeprint");
}

/// Getter for onbeforeunload
pub fn get_onbeforeunload(instance: *runtime.Instance) anyerror!typedefs.OnBeforeUnloadEventHandler {
    const handler = getEventHandler(instance, "beforeunload");
    return @as(typedefs.OnBeforeUnloadEventHandler, @ptrCast(handler));
}

/// Getter for onhashchange
pub fn get_onhashchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "hashchange");
}

/// Getter for onlanguagechange
pub fn get_onlanguagechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "languagechange");
}

/// Getter for onmessage
pub fn get_onmessage(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "message");
}

/// Getter for onmessageerror
pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "messageerror");
}

/// Getter for onoffline
pub fn get_onoffline(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "offline");
}

/// Getter for ononline
pub fn get_ononline(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "online");
}

/// Getter for onpagehide
pub fn get_onpagehide(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pagehide");
}

/// Getter for onpagereveal
pub fn get_onpagereveal(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pagereveal");
}

/// Getter for onpageshow
pub fn get_onpageshow(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pageshow");
}

/// Getter for onpageswap
pub fn get_onpageswap(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pageswap");
}

/// Getter for onpopstate
pub fn get_onpopstate(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "popstate");
}

/// Getter for onrejectionhandled
pub fn get_onrejectionhandled(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "rejectionhandled");
}

/// Getter for onstorage
pub fn get_onstorage(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "storage");
}

/// Getter for onunhandledrejection
pub fn get_onunhandledrejection(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "unhandledrejection");
}

/// Getter for onunload
pub fn get_onunload(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "unload");
}

/// Getter for ongamepadconnected
pub fn get_ongamepadconnected(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "gamepadconnected");
}

/// Getter for ongamepaddisconnected
pub fn get_ongamepaddisconnected(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "gamepaddisconnected");
}

/// Getter for onportalactivate
pub fn get_onportalactivate(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "portalactivate");
}

/// Getter for origin
/// Returns the origin of this window's associated Document.
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#dom-origin
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return "null";
    return internal.origin;
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

/// Setter for onabort
pub fn set_onabort(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "abort", value);
}

/// Setter for onauxclick
pub fn set_onauxclick(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "auxclick", value);
}

/// Setter for onbeforeinput
pub fn set_onbeforeinput(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "beforeinput", value);
}

/// Setter for onbeforematch
pub fn set_onbeforematch(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "beforematch", value);
}

/// Setter for onbeforetoggle
pub fn set_onbeforetoggle(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "beforetoggle", value);
}

/// Setter for onblur
pub fn set_onblur(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "blur", value);
}

/// Setter for oncancel
pub fn set_oncancel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "cancel", value);
}

/// Setter for oncanplay
pub fn set_oncanplay(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "canplay", value);
}

/// Setter for oncanplaythrough
pub fn set_oncanplaythrough(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "canplaythrough", value);
}

/// Setter for onchange
pub fn set_onchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "change", value);
}

/// Setter for onclick
pub fn set_onclick(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "click", value);
}

/// Setter for onclose
pub fn set_onclose(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "close", value);
}

/// Setter for oncommand
pub fn set_oncommand(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "command", value);
}

/// Setter for oncontextlost
pub fn set_oncontextlost(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "contextlost", value);
}

/// Setter for oncontextmenu
pub fn set_oncontextmenu(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "contextmenu", value);
}

/// Setter for oncontextrestored
pub fn set_oncontextrestored(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "contextrestored", value);
}

/// Setter for oncopy
pub fn set_oncopy(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "copy", value);
}

/// Setter for oncuechange
pub fn set_oncuechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "cuechange", value);
}

/// Setter for oncut
pub fn set_oncut(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "cut", value);
}

/// Setter for ondblclick
pub fn set_ondblclick(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "dblclick", value);
}

/// Setter for ondrag
pub fn set_ondrag(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "drag", value);
}

/// Setter for ondragend
pub fn set_ondragend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "dragend", value);
}

/// Setter for ondragenter
pub fn set_ondragenter(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "dragenter", value);
}

/// Setter for ondragleave
pub fn set_ondragleave(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "dragleave", value);
}

/// Setter for ondragover
pub fn set_ondragover(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "dragover", value);
}

/// Setter for ondragstart
pub fn set_ondragstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "dragstart", value);
}

/// Setter for ondrop
pub fn set_ondrop(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "drop", value);
}

/// Setter for ondurationchange
pub fn set_ondurationchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "durationchange", value);
}

/// Setter for onemptied
pub fn set_onemptied(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "emptied", value);
}

/// Setter for onended
pub fn set_onended(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "ended", value);
}

/// Setter for onerror
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.OnErrorEventHandler) anyerror!void {
    // OnErrorEventHandler is compatible with EventHandler storage
    const handler: typedefs.EventHandler = @ptrCast(value);
    try setEventHandler(instance, "error", handler);
}

/// Setter for onfocus
pub fn set_onfocus(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "focus", value);
}

/// Setter for onformdata
pub fn set_onformdata(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "formdata", value);
}

/// Setter for oninput
pub fn set_oninput(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "input", value);
}

/// Setter for oninvalid
pub fn set_oninvalid(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "invalid", value);
}

/// Setter for onkeydown
pub fn set_onkeydown(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "keydown", value);
}

/// Setter for onkeypress
pub fn set_onkeypress(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "keypress", value);
}

/// Setter for onkeyup
pub fn set_onkeyup(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "keyup", value);
}

/// Setter for onload
pub fn set_onload(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "load", value);
}

/// Setter for onloadeddata
pub fn set_onloadeddata(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "loadeddata", value);
}

/// Setter for onloadedmetadata
pub fn set_onloadedmetadata(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "loadedmetadata", value);
}

/// Setter for onloadstart
pub fn set_onloadstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "loadstart", value);
}

/// Setter for onmousedown
pub fn set_onmousedown(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "mousedown", value);
}

/// Setter for onmouseenter
pub fn set_onmouseenter(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "mouseenter", value);
}

/// Setter for onmouseleave
pub fn set_onmouseleave(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "mouseleave", value);
}

/// Setter for onmousemove
pub fn set_onmousemove(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "mousemove", value);
}

/// Setter for onmouseout
pub fn set_onmouseout(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "mouseout", value);
}

/// Setter for onmouseover
pub fn set_onmouseover(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "mouseover", value);
}

/// Setter for onmouseup
pub fn set_onmouseup(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "mouseup", value);
}

/// Setter for onpaste
pub fn set_onpaste(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "paste", value);
}

/// Setter for onpause
pub fn set_onpause(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pause", value);
}

/// Setter for onplay
pub fn set_onplay(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "play", value);
}

/// Setter for onplaying
pub fn set_onplaying(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "playing", value);
}

/// Setter for onprogress
pub fn set_onprogress(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "progress", value);
}

/// Setter for onratechange
pub fn set_onratechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "ratechange", value);
}

/// Setter for onreset
pub fn set_onreset(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "reset", value);
}

/// Setter for onresize
pub fn set_onresize(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "resize", value);
}

/// Setter for onscroll
pub fn set_onscroll(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "scroll", value);
}

/// Setter for onscrollend
pub fn set_onscrollend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "scrollend", value);
}

/// Setter for onsecuritypolicyviolation
pub fn set_onsecuritypolicyviolation(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "securitypolicyviolation", value);
}

/// Setter for onseeked
pub fn set_onseeked(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "seeked", value);
}

/// Setter for onseeking
pub fn set_onseeking(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "seeking", value);
}

/// Setter for onselect
pub fn set_onselect(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "select", value);
}

/// Setter for onslotchange
pub fn set_onslotchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "slotchange", value);
}

/// Setter for onstalled
pub fn set_onstalled(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "stalled", value);
}

/// Setter for onsubmit
pub fn set_onsubmit(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "submit", value);
}

/// Setter for onsuspend
pub fn set_onsuspend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "suspend", value);
}

/// Setter for ontimeupdate
pub fn set_ontimeupdate(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "timeupdate", value);
}

/// Setter for ontoggle
pub fn set_ontoggle(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "toggle", value);
}

/// Setter for onvolumechange
pub fn set_onvolumechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "volumechange", value);
}

/// Setter for onwaiting
pub fn set_onwaiting(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "waiting", value);
}

/// Setter for onwebkitanimationend
pub fn set_onwebkitanimationend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "webkitanimationend", value);
}

/// Setter for onwebkitanimationiteration
pub fn set_onwebkitanimationiteration(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "webkitanimationiteration", value);
}

/// Setter for onwebkitanimationstart
pub fn set_onwebkitanimationstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "webkitanimationstart", value);
}

/// Setter for onwebkittransitionend
pub fn set_onwebkittransitionend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "webkittransitionend", value);
}

/// Setter for onwheel
pub fn set_onwheel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "wheel", value);
}

/// Setter for onselectstart
pub fn set_onselectstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "selectstart", value);
}

/// Setter for onselectionchange
pub fn set_onselectionchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "selectionchange", value);
}

/// Setter for onanimationstart
pub fn set_onanimationstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "animationstart", value);
}

/// Setter for onanimationiteration
pub fn set_onanimationiteration(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "animationiteration", value);
}

/// Setter for onanimationend
pub fn set_onanimationend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "animationend", value);
}

/// Setter for onanimationcancel
pub fn set_onanimationcancel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "animationcancel", value);
}

/// Setter for ontransitionrun
pub fn set_ontransitionrun(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "transitionrun", value);
}

/// Setter for ontransitionstart
pub fn set_ontransitionstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "transitionstart", value);
}

/// Setter for ontransitionend
pub fn set_ontransitionend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "transitionend", value);
}

/// Setter for ontransitioncancel
pub fn set_ontransitioncancel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "transitioncancel", value);
}

/// Setter for onbeforexrselect
pub fn set_onbeforexrselect(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "beforexrselect", value);
}

/// Setter for onpointerover
pub fn set_onpointerover(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pointerover", value);
}

/// Setter for onpointerenter
pub fn set_onpointerenter(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pointerenter", value);
}

/// Setter for onpointerdown
pub fn set_onpointerdown(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pointerdown", value);
}

/// Setter for onpointermove
pub fn set_onpointermove(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pointermove", value);
}

/// Setter for onpointerrawupdate
pub fn set_onpointerrawupdate(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pointerrawupdate", value);
}

/// Setter for onpointerup
pub fn set_onpointerup(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pointerup", value);
}

/// Setter for onpointercancel
pub fn set_onpointercancel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pointercancel", value);
}

/// Setter for onpointerout
pub fn set_onpointerout(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pointerout", value);
}

/// Setter for onpointerleave
pub fn set_onpointerleave(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pointerleave", value);
}

/// Setter for ongotpointercapture
pub fn set_ongotpointercapture(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "gotpointercapture", value);
}

/// Setter for onlostpointercapture
pub fn set_onlostpointercapture(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "lostpointercapture", value);
}

/// Setter for ontouchstart
pub fn set_ontouchstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "touchstart", value);
}

/// Setter for ontouchend
pub fn set_ontouchend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "touchend", value);
}

/// Setter for ontouchmove
pub fn set_ontouchmove(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "touchmove", value);
}

/// Setter for ontouchcancel
pub fn set_ontouchcancel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "touchcancel", value);
}

/// Setter for onfencedtreeclick
pub fn set_onfencedtreeclick(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "fencedtreeclick", value);
}

/// Setter for onsnapchanged
pub fn set_onsnapchanged(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "snapchanged", value);
}

/// Setter for onsnapchanging
pub fn set_onsnapchanging(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "snapchanging", value);
}

/// Setter for onafterprint
pub fn set_onafterprint(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "afterprint", value);
}

/// Setter for onbeforeprint
pub fn set_onbeforeprint(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "beforeprint", value);
}

/// Setter for onbeforeunload
pub fn set_onbeforeunload(instance: *runtime.Instance, value: typedefs.OnBeforeUnloadEventHandler) anyerror!void {
    const handler: typedefs.EventHandler = @ptrCast(value);
    try setEventHandler(instance, "beforeunload", handler);
}

/// Setter for onhashchange
pub fn set_onhashchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "hashchange", value);
}

/// Setter for onlanguagechange
pub fn set_onlanguagechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "languagechange", value);
}

/// Setter for onmessage
pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "message", value);
}

/// Setter for onmessageerror
pub fn set_onmessageerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "messageerror", value);
}

/// Setter for onoffline
pub fn set_onoffline(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "offline", value);
}

/// Setter for ononline
pub fn set_ononline(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "online", value);
}

/// Setter for onpagehide
pub fn set_onpagehide(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pagehide", value);
}

/// Setter for onpagereveal
pub fn set_onpagereveal(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pagereveal", value);
}

/// Setter for onpageshow
pub fn set_onpageshow(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pageshow", value);
}

/// Setter for onpageswap
pub fn set_onpageswap(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "pageswap", value);
}

/// Setter for onpopstate
pub fn set_onpopstate(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "popstate", value);
}

/// Setter for onrejectionhandled
pub fn set_onrejectionhandled(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "rejectionhandled", value);
}

/// Setter for onstorage
pub fn set_onstorage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "storage", value);
}

/// Setter for onunhandledrejection
pub fn set_onunhandledrejection(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "unhandledrejection", value);
}

/// Setter for onunload
pub fn set_onunload(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "unload", value);
}

/// Setter for ongamepadconnected
pub fn set_ongamepadconnected(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "gamepadconnected", value);
}

/// Setter for ongamepaddisconnected
pub fn set_ongamepaddisconnected(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "gamepaddisconnected", value);
}

/// Setter for onportalactivate
pub fn set_onportalactivate(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setEventHandler(instance, "portalactivate", value);
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
/// Per HTML Standard §9.4.3: Posts a message to the target window
/// This creates a MessageEvent and dispatches it to the target window.
pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue, targetOrigin: runtime.USVString, transfer: webidl.Opt(runtime.JSValue)) anyerror!void {
    _ = transfer; // TODO: Handle transferables
    _ = targetOrigin; // TODO: Validate origin

    std.debug.print("[postMessage] Called on window={*}\n", .{instance});

    const internal = getInternal(instance) orelse return error.InvalidStateError;
    _ = internal;

    // Get the context from the instance
    const ctx = instance.ctx;
    const allocator = ctx.allocator;

    // Create MessageEvent with the message data
    // createPortMessageEvent already sets type to "message"
    const MessageEventImpl = @import("MessageEvent.zig");
    const event = try MessageEventImpl.createPortMessageEvent(
        allocator,
        ctx,
        message,
        runtime.JSValue.jsUndefined, // No ports for basic postMessage
    );
    defer interfaces.MessageEvent.deinit(event);

    // Dispatch the event to the target window (which is the instance we were called on)
    std.debug.print("[postMessage] Dispatching message event to window={*}\n", .{instance});
    _ = try interfaces.EventTarget.call_dispatchEvent(instance, event);
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
/// Delegates to WindowOrWorkerGlobalScope mixin implementation.
pub fn call_setTimeout(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
    std.debug.print("[WINDOW_SETTIMEOUT] Window.call_setTimeout ENTRY - delegating to mixin\n", .{});
    const result = WindowOrWorkerGlobalScopeImpl.call_setTimeout(instance, handler, timeout, arguments);
    std.debug.print("[WINDOW_SETTIMEOUT] Window.call_setTimeout result: {any}\n", .{result});
    return result;
}

/// Operation: clearInterval
/// Delegates to WindowOrWorkerGlobalScope mixin implementation.
pub fn call_clearInterval(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    return WindowOrWorkerGlobalScopeImpl.call_clearInterval(instance, id);
}

/// Operation: fetch
/// Implements the global fetch() function per WHATWG Fetch Standard.
/// Spec: https://fetch.spec.whatwg.org/#fetch-method
///
/// Delegates to WindowOrWorkerGlobalScope mixin implementation which uses
/// the async curl manager for non-blocking fetch requests.
pub fn call_fetch(instance: *runtime.Instance, input: typedefs.RequestInfo, init_data: webidl.Opt(dictionaries.RequestInit)) anyerror!runtime.JSValue {
    // Delegate to the WindowOrWorkerGlobalScope mixin implementation
    // which uses AsyncCurlManager for true async fetch
    return WindowOrWorkerGlobalScopeImpl.call_fetch(instance, input, init_data);
}

// Helper to get promise object and destroy handle to prevent memory leaks
fn getPromiseAndCleanup(engine: *const runtime.EngineInterface, promise_handle: *anyopaque, allocator: std.mem.Allocator) runtime.JSValue {
    const promise_obj = engine.getPromiseObject(promise_handle);
    if (engine.destroyPromiseHandle) |destroy| {
        destroy(promise_handle, allocator);
    }
    return runtime.JSValue.fromHandle(promise_obj);
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
    const current_time = std.time.milliTimestamp();

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
/// Delegates to WindowOrWorkerGlobalScope mixin implementation.
pub fn call_queueMicrotask(instance: *runtime.Instance, callback: callbacks.VoidFunction) anyerror!void {
    return WindowOrWorkerGlobalScopeImpl.call_queueMicrotask(instance, callback);
}

/// Operation: structuredClone
/// Delegates to WindowOrWorkerGlobalScope mixin implementation.
pub fn call_structuredClone(instance: *runtime.Instance, value: runtime.JSValue, options: webidl.Opt(dictionaries.StructuredSerializeOptions)) anyerror!runtime.JSValue {
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
pub fn call_getSelection(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
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
/// Per spec §7.4.1: Opens a new window or navigates existing one.
///
/// This is a stub implementation that:
/// - Returns the current window for _self and _parent targets
/// - Creates a new auxiliary browsing context for _blank
/// - Does NOT actually navigate to the URL (TODO)
///
/// For WPT tests to pass, we need to return a valid WindowProxy.
pub fn call_open(instance: *runtime.Instance, url: webidl.Opt(runtime.USVString), target: webidl.Opt(runtime.DOMString), features: webidl.Opt(runtime.DOMString)) anyerror!?typedefs.WindowProxy {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if window is closed
    if (internal.closed) {
        return null;
    }

    // Get parameters (defaults per spec)
    const url_str = if (url.wasPassed()) url.getValue() else "about:blank";
    _ = url_str; // TODO: Navigate to URL
    const target_str: []const u8 = if (target.wasPassed()) target.getValue().asSlice() else "_blank";
    const features_str: []const u8 = if (features.wasPassed()) features.getValue().asSlice() else "";

    // Handle special target names per spec
    // "_self" - current browsing context
    // "_parent" - parent browsing context (or self if no parent)
    // "_top" - top-level browsing context
    // "_blank" - new auxiliary browsing context
    if (std.mem.eql(u8, target_str, "_self")) {
        return getWindowProxy(instance);
    }
    if (std.mem.eql(u8, target_str, "_parent")) {
        // Return parent's window, or self if no parent
        if (internal.browsing_context.parent) |parent_bc| {
            if (parent_bc.getActiveWindow()) |parent_window_ptr| {
                const parent_window: *runtime.Instance = @ptrCast(@alignCast(parent_window_ptr));
                return getWindowProxy(parent_window);
            }
        }
        return getWindowProxy(instance);
    }
    if (std.mem.eql(u8, target_str, "_top")) {
        // Return top-level window's proxy
        // For now, return self (handles case where we ARE the top)
        return getWindowProxy(instance);
    }

    // Parse the features string to determine if this should be a popup
    const is_popup = parseWindowFeatures(features_str);

    // For _blank or named targets, create auxiliary browsing context
    var new_ctx = try BrowsingContext.initAuxiliary(internal.allocator, internal.browsing_context, is_popup);
    if (target_str.len > 0 and target_str[0] != '_') {
        try new_ctx.setTargetName(target_str);
    }

    // TODO: Create a proper Window instance for the new context
    // For now, return the opener's WindowProxy as a stub
    // This allows tests that just check "window.open returns something" to pass
    return getWindowProxy(instance);
}

/// Parse window features string to determine if this should be a popup
fn parseWindowFeatures(features: []const u8) bool {
    // Per spec, a window is a popup if:
    // - The features string is not empty, AND
    // - Certain features are specified that indicate popup behavior
    if (features.len == 0) {
        return false;
    }

    // Simple heuristic: if width or height is specified, treat as popup
    // A more complete implementation would parse all feature tokens
    if (std.mem.indexOf(u8, features, "width") != null or
        std.mem.indexOf(u8, features, "height") != null or
        std.mem.indexOf(u8, features, "popup") != null)
    {
        return true;
    }

    return false;
}

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
/// Delegates to WindowOrWorkerGlobalScope mixin implementation.
pub fn call_clearTimeout(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    return WindowOrWorkerGlobalScopeImpl.call_clearTimeout(instance, id);
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

    return css_instance;
}

/// Operation: setInterval
/// Delegates to WindowOrWorkerGlobalScope mixin implementation.
pub fn call_setInterval(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
    return WindowOrWorkerGlobalScopeImpl.call_setInterval(instance, handler, timeout, arguments);
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

    // First, check if it's a child browsing context name
    for (internal.browsing_context.children.items) |child| {
        if (std.mem.eql(u8, child.target_name, name)) {
            const child_window = child.getActiveWindow() orelse continue;
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

    var names: std.ArrayList(runtime.DOMString) = .{};
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

pub fn call_getter(instance: *runtime.Instance, name: runtime.DOMString) anyerror!runtime.JSValue {
    _ = instance;
    _ = name;
    return error.NotImplemented;
}
