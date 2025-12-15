//! WPT Browser Context Setup
//!
//! This module creates and manages browser-like execution contexts for WPT tests.
//! It sets up Window/WorkerGlobalScope as the global object in V8 and registers
//! all required browser globals (document, navigator, location, history, etc.).
//!
//! ## Context Types
//!
//! - `WindowContext` - For .window.js and .html tests
//!   - window, document, self, globalThis
//!   - navigator, location, history
//!   - console, setTimeout, setInterval
//!
//! - `WorkerContext` - For .worker.js tests
//!   - self (WorkerGlobalScope)
//!   - navigator, location
//!   - postMessage, close, importScripts
//!
//! ## Usage
//!
//! ```zig
//! var ctx = try BrowserContext.initWindow(allocator, "tests/wpt");
//! defer ctx.deinit();
//!
//! try ctx.loadTestHarness();
//! const result = try ctx.executeTest(test_content, .normal);
//! ```

const std = @import("std");
const config = @import("config.zig");
const test_parser = @import("test_parser.zig");
const test_harness = @import("test_harness.zig");

// V8 and Runtime imports - these are configured via build.zig imports
const v8 = @import("v8");
const runtime = @import("runtime");
const context_manager = v8.context_manager;
const interfaces = @import("interfaces");
const namespaces = @import("namespaces");
const impls = @import("impls");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");

// DOM and HTML modules for thread-local state cleanup on isolate disposal
const dom = @import("dom");
const html_full = @import("html_full");

// Platform module for timer backend cleanup
const platform = @import("platform");

// V8 Event Loop with timer support (uses libuv under the hood)
const V8EventLoop = v8.V8EventLoop;
const TimerInterface = runtime.TimerInterface;
const TimerId = runtime.TimerId;
const TimerCallback = runtime.TimerCallback;

// Typed callback wrappers for type-safe timer contexts
// Using SelfContainedWorkCallback which stores allocator internally for no-arg destroy()
const typed_callback = runtime.typed_callback;
const SelfContainedWorkCallback = typed_callback.SelfContainedWorkCallback;

/// Execution context type
pub const ContextType = enum {
    /// Window/document context (for .window.js, .html tests)
    window,
    /// Dedicated worker context (for .worker.js tests)
    worker,
    /// Shared worker context
    shared_worker,
    /// Service worker context
    service_worker,
};

/// Browser-like execution context for WPT tests
pub const BrowserContext = struct {
    allocator: std.mem.Allocator,
    context_type: ContextType,
    /// Result collector for this context
    result_collector: test_harness.ResultCollector,
    /// WPT root directory
    wpt_root: []const u8,
    /// Current test URL (for location object)
    test_url: []const u8,
    /// Whether context is ready for execution
    initialized: bool = false,

    // V8 handles
    isolate: ?*v8.ffi.Isolate = null,
    context: ?*v8.ffi.Context = null,

    // Singleton instances that need cleanup
    window_instance: ?*runtime.Instance = null,
    document_instance: ?*runtime.Instance = null,
    navigator_instance: ?*runtime.Instance = null,
    location_instance: ?*runtime.Instance = null,
    history_instance: ?*runtime.Instance = null,
    performance_instance: ?*runtime.Instance = null,

    // V8 event loop with timer support (libuv-based)
    // This is initialized after V8 isolate is created
    v8_event_loop: ?*V8EventLoop = null,

    pub fn init(allocator: std.mem.Allocator, context_type: ContextType, wpt_root: []const u8) !BrowserContext {
        // V8 event loop will be created during initialize() after isolate is ready
        return BrowserContext{
            .allocator = allocator,
            .context_type = context_type,
            .result_collector = test_harness.ResultCollector.init(allocator),
            .wpt_root = try allocator.dupe(u8, wpt_root),
            .test_url = try allocator.dupe(u8, "http://web-platform.test:8000/"),
        };
    }

    pub fn deinit(self: *BrowserContext) void {
        self.result_collector.deinit();
        self.allocator.free(self.wpt_root);
        self.allocator.free(self.test_url);

        // Explicitly clean up the document instance and its DOM tree.
        // This is necessary because:
        // 1. The document may have been replaced by loadHTMLDocument()
        // 2. The new document might not be in wrapper_cache (if wrapping failed/skipped)
        // 3. Even if in cache, we need to clean up BEFORE context_manager.deinit()
        //    to ensure proper ordering (DOM cleanup before V8 context disposal)
        //
        // Document.deinit() chains to Node.deinit() which recursively cleans up
        // all child nodes (Elements, Text nodes, etc.), freeing their CharacterData.
        //
        // NOTE: The deinit functions are idempotent - they check their registries
        // before cleaning up, so double-calls from wrapper cache are safe.
        if (self.document_instance) |doc| {
            interfaces.Document.deinit(doc);
            self.document_instance = null;
        }

        // Clear timer interface from thread-local storage
        clearTimerInterface();

        // Clear iframe src load hook
        impls.HTMLIFrameElement.setIframeSrcLoadHook(null);

        // Cleanup V8 event loop (which cleans up libuv timer manager)
        if (self.v8_event_loop) |event_loop| {
            event_loop.deinit();
            self.allocator.destroy(event_loop);
        }

        // Cleanup context manager (this cleans up wrapper cache which deinits all instances)
        if (self.context != null) {
            context_manager.deinit();
        }

        // CRITICAL: Clear DOM/HTML thread-local state BEFORE clearing V8 templates
        // These may hold references to V8 objects that become invalid after isolate disposal.
        // Order: DOM state → V8 templates → V8 isolate
        //
        // Phase 2a: Clear thread-local DOM state on isolate disposal
        // - Custom element reactions stack and queues
        // - Mutation observer agent state (TODO: re-enable when mutation_observer module is properly configured)
        html_full.custom_elements.deinitThreadLocalState();
        // NOTE: mutation_observer_algorithms.resetAgent() is commented out because the
        // mutation_observer module is not fully configured for the WPT runner build.
        // dom.mutation_observer_algorithms.resetAgent();

        // CRITICAL: Clear template registry BEFORE disposing isolate
        // V8 FunctionTemplates are bound to specific isolates and cannot be reused.
        // Failure to clear before creating a new isolate causes bus errors when
        // trying to use stale template references.
        v8.template_registry.clear();

        // Exit and dispose V8 context
        if (self.context) |ctx| {
            v8.ffi.v8_Context_Exit(ctx);
            v8.ffi.v8_Context_Dispose(ctx);
        }

        // Force V8 garbage collection before isolate disposal
        // NOTE: We set MicrotasksPolicy to Explicit and skip PerformMicrotaskCheckpoint
        // during cleanup. Running microtasks here can trigger unhandled promise rejection
        // handlers for promises that were created but never awaited during tests. This
        // causes "<unknown>:764: Uncaught [object DOMException]" errors from testharness.js
        // promise_test rejection handling. The promises are about to be garbage
        // collected anyway, so there's no need to run their callbacks.
        if (self.isolate) |isolate| {
            // Set microtasks policy to explicit to prevent automatic execution during disposal
            v8.ffi.v8_Isolate_SetMicrotasksPolicy(isolate, @intFromEnum(v8.ffi.MicrotasksPolicy.Explicit));

            // Single GC call is sufficient after wrapper cache cleanup
            // Multiple GC calls add unnecessary overhead
            v8.ffi.v8_Isolate_RequestGarbageCollection(isolate);

            v8.ffi.v8_Isolate_Exit(isolate);
            v8.ffi.v8_Isolate_Dispose(isolate);
        }

        // Clean up any orphaned DOM nodes that were removed from the tree during
        // test execution but not properly deinited. This catches nodes that were
        // created during parsing but then removed by testharness.js or the test code.
        // Must be called BEFORE deinitializeRuntime() since it frees owned strings.
        impls.cleanup.cleanupAllDomRegistries();

        // Clean up the global timer backend (if it was lazily initialized)
        // This frees the RealTimerBackend that may have been created by Worker constructors
        platform.deinitDefaultTimerBackend();

        // Cleanup WebIDL runtime
        runtime.deinitializeRuntime();
    }

    /// Initialize the V8 context with browser globals
    pub fn initialize(self: *BrowserContext) !void {
        // Initialize WebIDL runtime (SlabAllocator, ArenaAllocator)
        runtime.initializeRuntime(self.allocator);

        // Initialize V8 platform (once per process)
        v8.ffi.v8_Platform_Initialize();

        // Create V8 isolate
        const isolate = v8.ffi.v8_Isolate_New() orelse return error.V8InitFailed;
        self.isolate = isolate;

        v8.ffi.v8_Isolate_Enter(isolate);

        // Create V8 event loop with timer support (uses libuv under the hood)
        const event_loop_ptr = try self.allocator.create(V8EventLoop);
        errdefer self.allocator.destroy(event_loop_ptr);
        event_loop_ptr.* = try V8EventLoop.init(isolate, self.allocator);
        self.v8_event_loop = event_loop_ptr;

        // Create V8 context with immutable prototype on global object
        // Per WebIDL spec, global objects (Window, WorkerGlobalScope) must have
        // immutable [[Prototype]] - Object.setPrototypeOf(window, {}) must throw TypeError
        // but Object.setPrototypeOf(window, window.__proto__) must succeed (same prototype)
        const global_template = v8.ffi.v8_ObjectTemplate_New(isolate);
        v8.ffi.v8_ObjectTemplate_SetImmutableProto(global_template);

        // Set internal field count for Window binding (2 fields: impl pointer + type info)
        // This is required for bindWindowToContext() to bind the Window instance to the global
        v8.ffi.v8_ObjectTemplate_SetInternalFieldCount(global_template, 2);

        // Set up indexed property handler for frames[index] access
        // Per HTML spec §7.4.3.1 (WindowProxy [[GetOwnProperty]]):
        // - Numeric indices return child browsing context Windows
        v8.ffi.v8_ObjectTemplate_SetIndexedPropertyHandlerFull(
            global_template,
            context_manager.windowIndexedPropertyGetter,
            context_manager.windowIndexedPropertyQuery,
            context_manager.windowIndexedPropertyEnumerator,
            null, // descriptor callback - not needed for basic access
        );

        const context = v8.ffi.v8_Context_NewWithGlobalTemplate(isolate, global_template) orelse return error.ContextCreateFailed;
        self.context = context;

        v8.ffi.v8_Context_Enter(context);

        // Initialize context manager for V8 callbacks
        context_manager.init(self.allocator) catch |err| {
            std.debug.print("Warning: Context manager init failed: {}\n", .{err});
        };

        // Register context with context manager for wrapper caching
        // IMPORTANT: Pass our timer and event loop interfaces so all runtime contexts
        // share the same libuv loop. This ensures setTimeout/setInterval timers from
        // Worker constructors use the same loop we poll in runEventLoop().
        const timer_iface = if (self.v8_event_loop) |ev| ev.timerInterface() else null;
        const event_loop_iface = if (self.v8_event_loop) |ev| ev.eventLoop() else null;
        _ = context_manager.getOrCreateWithExternalEventLoop(context, timer_iface, event_loop_iface, self.allocator) catch |err| {
            std.debug.print("Warning: Context registration failed: {}\n", .{err});
        };

        // Register all WebIDL interfaces using the centralized function
        // This is the single source of truth for interface binding setup
        v8.interface_bindings.initializeBindings(isolate, context);

        // Register all namespaces using the generic function
        v8.interface_bindings.registerNamespacesGeneric(namespaces, isolate, context);

        // Bind Window instance to context for cross-realm support (frames[0], contentWindow)
        // This creates a Window runtime.Instance and binds it to the V8 global object.
        // Must be done after interface bindings are initialized.
        self.window_instance = context_manager.bindWindowToContext(context, isolate, self.allocator) catch |err| blk: {
            std.debug.print("Warning: Failed to bind Window to context: {}\n", .{err});
            break :blk null;
        };

        // Register Window properties as own properties on the global object.
        // This is required for WebIDL compliance: window.length, window.name, etc.
        // must be accessible as own properties via Object.getOwnPropertyDescriptor.
        const global_obj = v8.ffi.v8_Context_Global(context) orelse return error.GlobalNotFound;
        v8.interface_bindings.Window.registerPropertiesAsOwnOnObject(isolate, context, global_obj);

        // CRITICAL: Set up window/self globals via JavaScript FIRST
        // This MUST happen before registerBrowserGlobals() because that function
        // executes scripts that reference `self` (e.g., `self.console = {...}`).
        // We do this via JS because V8's global proxy has special semantics
        // that make C++ property setting behave differently from JS assignment.
        try self.setupGlobalAliases();

        // Register browser globals (Window, document, navigator, etc.)
        // Now scripts in registerCommonGlobals() can safely use `self`
        try self.registerBrowserGlobals();

        // Register WPT result callbacks
        try self.registerWptCallbacks();

        // Set up timer interface in thread-local storage
        // This needs to be available for testharness.js which uses setTimeout
        if (self.v8_event_loop) |event_loop| {
            if (event_loop.timerInterface()) |timer| {
                setTimerInterface(timer, self.allocator);
            }
        }

        // Set up iframe src load hook for WPT tests
        // This allows iframe.src = "relative/path.html" to work in tests
        impls.HTMLIFrameElement.setIframeSrcLoadHook(iframeSrcLoadHook);

        self.initialized = true;
    }

    /// Set up window/self/globalThis aliases and GLOBAL object via JavaScript
    fn setupGlobalAliases(self: *BrowserContext) !void {
        // Context-specific setup based on context_type
        // Per HTML spec §7.2.2.4 "Accessing related windows" (window context only)
        //
        // Per WebIDL §3.8, global object properties must be accessor properties that:
        // 1. Return globalThis when called with null/undefined this
        // 2. Throw TypeError when called with incompatible this (e.g., Object.create(globalThis))
        //
        // The checkThis helper validates that 'this' is either null/undefined or the global.
        const setup_script = switch (self.context_type) {
            .window =>
            \\// Helper function to check 'this' for global object properties
            \\// Per WebIDL §3.8:
            \\// - If this is null/undefined, use globalThis
            \\// - If this === globalThis, allow
            \\// - Otherwise, throw TypeError
            \\function __checkGlobalThis(thisArg, propName) {
            \\  if (thisArg === null || thisArg === undefined) {
            \\    return globalThis;
            \\  }
            \\  if (thisArg === globalThis) {
            \\    return globalThis;
            \\  }
            \\  throw new TypeError("'" + propName + "' called on an object that does not implement interface Window.");
            \\}
            \\
            \\// Define 'self' as an accessor property with proper global object checks
            \\Object.defineProperty(globalThis, 'self', {
            \\  get: function() {
            \\    return __checkGlobalThis(this, 'self');
            \\  },
            \\  set: function(v) {
            \\    __checkGlobalThis(this, 'self');
            \\    // self is not actually settable per spec, but we allow it for compat
            \\  },
            \\  enumerable: true,
            \\  configurable: true
            \\});
            \\
            \\// Define 'window' as an accessor property with proper global object checks
            \\Object.defineProperty(globalThis, 'window', {
            \\  get: function() {
            \\    return __checkGlobalThis(this, 'window');
            \\  },
            \\  set: function(v) {
            \\    __checkGlobalThis(this, 'window');
            \\  },
            \\  enumerable: true,
            \\  configurable: true
            \\});
            \\
            \\// Window hierarchy properties (per HTML spec §7.2.2.4)
            \\// For a top-level browsing context:
            \\// - parent returns the window itself
            \\// - top returns the window itself
            \\// - opener returns null (no opener)
            \\// - frames returns the window itself
            \\// - length returns 0 (no child navigables)
            \\Object.defineProperty(globalThis, 'parent', {
            \\  get: function() { return __checkGlobalThis(this, 'parent'); },
            \\  enumerable: true, configurable: true
            \\});
            \\Object.defineProperty(globalThis, 'top', {
            \\  get: function() { return __checkGlobalThis(this, 'top'); },
            \\  enumerable: true, configurable: true
            \\});
            \\Object.defineProperty(globalThis, 'frames', {
            \\  get: function() { return __checkGlobalThis(this, 'frames'); },
            \\  enumerable: true, configurable: true
            \\});
            \\globalThis.opener = null;
            \\// NOTE: 'length' is now provided by registerPropertiesAsOwnOnObject
            \\// which binds to Window.get_length() returning browsing_context.children.len
            \\
            \\// Internal storage for accessor properties
            \\// These are set by registerWindowGlobals() and accessed via getters below
            \\globalThis.__internal = {
            \\  navigator: null,
            \\  location: null,
            \\  document: null,
            \\  history: null,
            \\  performance: null,
            \\  origin: 'null',
            \\  isSecureContext: false,
            \\  crossOriginIsolated: false,
            \\  onerror: null,
            \\  onoffline: null,
            \\  ononline: null,
            \\};
            \\
            \\// Define accessor properties for browser singletons with proper global object checks
            \\// Per WebIDL §3.8, these must throw TypeError when called with incompatible this
            \\Object.defineProperty(globalThis, 'navigator', {
            \\  get: function() { __checkGlobalThis(this, 'navigator'); return globalThis.__internal.navigator; },
            \\  enumerable: true, configurable: true
            \\});
            \\Object.defineProperty(globalThis, 'location', {
            \\  get: function() { __checkGlobalThis(this, 'location'); return globalThis.__internal.location; },
            \\  set: function(v) { __checkGlobalThis(this, 'location'); globalThis.__internal.location = v; },
            \\  enumerable: true, configurable: true
            \\});
            \\Object.defineProperty(globalThis, 'document', {
            \\  get: function() { __checkGlobalThis(this, 'document'); return globalThis.__internal.document; },
            \\  enumerable: true, configurable: true
            \\});
            \\Object.defineProperty(globalThis, 'history', {
            \\  get: function() { __checkGlobalThis(this, 'history'); return globalThis.__internal.history; },
            \\  enumerable: true, configurable: true
            \\});
            \\Object.defineProperty(globalThis, 'performance', {
            \\  get: function() { __checkGlobalThis(this, 'performance'); return globalThis.__internal.performance; },
            \\  enumerable: true, configurable: true
            \\});
            \\Object.defineProperty(globalThis, 'origin', {
            \\  get: function() { __checkGlobalThis(this, 'origin'); return globalThis.__internal.origin; },
            \\  set: function(v) { __checkGlobalThis(this, 'origin'); globalThis.__internal.origin = v; },
            \\  enumerable: true, configurable: true
            \\});
            \\Object.defineProperty(globalThis, 'isSecureContext', {
            \\  get: function() { __checkGlobalThis(this, 'isSecureContext'); return globalThis.__internal.isSecureContext; },
            \\  enumerable: true, configurable: true
            \\});
            \\Object.defineProperty(globalThis, 'crossOriginIsolated', {
            \\  get: function() { __checkGlobalThis(this, 'crossOriginIsolated'); return globalThis.__internal.crossOriginIsolated; },
            \\  enumerable: true, configurable: true
            \\});
            \\Object.defineProperty(globalThis, 'onerror', {
            \\  get: function() { __checkGlobalThis(this, 'onerror'); return globalThis.__internal.onerror; },
            \\  set: function(v) { __checkGlobalThis(this, 'onerror'); globalThis.__internal.onerror = v; },
            \\  enumerable: true, configurable: true
            \\});
            \\Object.defineProperty(globalThis, 'onoffline', {
            \\  get: function() { __checkGlobalThis(this, 'onoffline'); return globalThis.__internal.onoffline; },
            \\  set: function(v) { __checkGlobalThis(this, 'onoffline'); globalThis.__internal.onoffline = v; },
            \\  enumerable: true, configurable: true
            \\});
            \\Object.defineProperty(globalThis, 'ononline', {
            \\  get: function() { __checkGlobalThis(this, 'ononline'); return globalThis.__internal.ononline; },
            \\  set: function(v) { __checkGlobalThis(this, 'ononline'); globalThis.__internal.ononline = v; },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Helper function to check 'this' for global object operations (methods)
            \\// For operations, we use __checkGlobalOp which validates then returns (not the global)
            \\function __checkGlobalOp(thisArg, opName) {
            \\  if (thisArg === null || thisArg === undefined) {
            \\    return; // OK - use global implicitly
            \\  }
            \\  if (thisArg === globalThis) {
            \\    return; // OK - called on global directly
            \\  }
            \\  throw new TypeError("'" + opName + "' called on an object that does not implement interface Window.");
            \\}
            \\
            \\// Internal storage for original operation implementations
            \\globalThis.__internalOps = {};
            \\
            \\// Wrap setInterval with global object check
            \\// Store original before wrapping (will be set by registerCommonGlobals)
            \\Object.defineProperty(globalThis, 'setInterval', {
            \\  get: function() {
            \\    const origOp = globalThis.__internalOps.setInterval;
            \\    return function(...args) {
            \\      __checkGlobalOp(this, 'setInterval');
            \\      return origOp.apply(globalThis, args);
            \\    };
            \\  },
            \\  set: function(v) { globalThis.__internalOps.setInterval = v; },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Wrap clearTimeout with global object check
            \\Object.defineProperty(globalThis, 'clearTimeout', {
            \\  get: function() {
            \\    const origOp = globalThis.__internalOps.clearTimeout;
            \\    return function(...args) {
            \\      __checkGlobalOp(this, 'clearTimeout');
            \\      return origOp ? origOp.apply(globalThis, args) : undefined;
            \\    };
            \\  },
            \\  set: function(v) { globalThis.__internalOps.clearTimeout = v; },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Wrap btoa with global object check  
            \\Object.defineProperty(globalThis, 'btoa', {
            \\  get: function() {
            \\    const origOp = globalThis.__internalOps.btoa;
            \\    return function(...args) {
            \\      __checkGlobalOp(this, 'btoa');
            \\      return origOp ? origOp.apply(globalThis, args) : undefined;
            \\    };
            \\  },
            \\  set: function(v) { globalThis.__internalOps.btoa = v; },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Wrap atob with global object check
            \\Object.defineProperty(globalThis, 'atob', {
            \\  get: function() {
            \\    const origOp = globalThis.__internalOps.atob;
            \\    return function(...args) {
            \\      __checkGlobalOp(this, 'atob');
            \\      return origOp ? origOp.apply(globalThis, args) : undefined;
            \\    };
            \\  },
            \\  set: function(v) { globalThis.__internalOps.atob = v; },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Wrap focus with global object check
            \\Object.defineProperty(globalThis, 'focus', {
            \\  get: function() {
            \\    const origOp = globalThis.__internalOps.focus;
            \\    return function(...args) {
            \\      __checkGlobalOp(this, 'focus');
            \\      return origOp ? origOp.apply(globalThis, args) : undefined;
            \\    };
            \\  },
            \\  set: function(v) { globalThis.__internalOps.focus = v; },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Wrap removeEventListener with global object check
            \\Object.defineProperty(globalThis, 'removeEventListener', {
            \\  get: function() {
            \\    const origOp = globalThis.__internalOps.removeEventListener;
            \\    return function(...args) {
            \\      __checkGlobalOp(this, 'removeEventListener');
            \\      return origOp ? origOp.apply(globalThis, args) : undefined;
            \\    };
            \\  },
            \\  set: function(v) { globalThis.__internalOps.removeEventListener = v; },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Wrap addEventListener with global object check
            \\Object.defineProperty(globalThis, 'addEventListener', {
            \\  get: function() {
            \\    const origOp = globalThis.__internalOps.addEventListener;
            \\    return function(...args) {
            \\      __checkGlobalOp(this, 'addEventListener');
            \\      return origOp ? origOp.apply(globalThis, args) : undefined;
            \\    };
            \\  },
            \\  set: function(v) { globalThis.__internalOps.addEventListener = v; },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Wrap dispatchEvent with global object check
            \\Object.defineProperty(globalThis, 'dispatchEvent', {
            \\  get: function() {
            \\    const origOp = globalThis.__internalOps.dispatchEvent;
            \\    return function(...args) {
            \\      __checkGlobalOp(this, 'dispatchEvent');
            \\      return origOp ? origOp.apply(globalThis, args) : false;
            \\    };
            \\  },
            \\  set: function(v) { globalThis.__internalOps.dispatchEvent = v; },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Set up GLOBAL object for WPT tests - WINDOW context
            \\globalThis.GLOBAL = {
            \\  isWindow: function() { return true; },
            \\  isWorker: function() { return false; },
            \\  isShadowRealm: function() { return false; },
            \\};
            ,
            .worker =>
            \\// Worker context: only self, no window
            \\// Helper function to check 'this' for global object properties
            \\function __checkGlobalThis(thisArg, propName) {
            \\  if (thisArg === null || thisArg === undefined) {
            \\    return globalThis;
            \\  }
            \\  if (thisArg === globalThis) {
            \\    return globalThis;
            \\  }
            \\  throw new TypeError("'" + propName + "' called on an object that does not implement interface WorkerGlobalScope.");
            \\}
            \\
            \\Object.defineProperty(globalThis, 'self', {
            \\  get: function() { return __checkGlobalThis(this, 'self'); },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Set up GLOBAL object for WPT tests - WORKER context
            \\globalThis.GLOBAL = {
            \\  isWindow: function() { return false; },
            \\  isWorker: function() { return true; },
            \\  isShadowRealm: function() { return false; },
            \\};
            ,
            .shared_worker, .service_worker =>
            \\// Shared/Service worker context: only self, no window
            \\function __checkGlobalThis(thisArg, propName) {
            \\  if (thisArg === null || thisArg === undefined) {
            \\    return globalThis;
            \\  }
            \\  if (thisArg === globalThis) {
            \\    return globalThis;
            \\  }
            \\  throw new TypeError("'" + propName + "' called on an object that does not implement interface WorkerGlobalScope.");
            \\}
            \\
            \\Object.defineProperty(globalThis, 'self', {
            \\  get: function() { return __checkGlobalThis(this, 'self'); },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Set up GLOBAL object for WPT tests - WORKER context
            \\globalThis.GLOBAL = {
            \\  isWindow: function() { return false; },
            \\  isWorker: function() { return true; },
            \\  isShadowRealm: function() { return false; },
            \\};
            ,
        };

        self.executeScript(setup_script) catch |err| {
            std.debug.print("ERROR: Failed to set up global aliases: {}\n", .{err});
            return err;
        };
    }

    /// Register browser globals (Window, document, navigator, etc.)
    fn registerBrowserGlobals(self: *BrowserContext) !void {
        const isolate = self.isolate orelse return error.NotInitialized;
        const context = self.context orelse return error.NotInitialized;
        const global_obj = v8.ffi.v8_Context_Global(context) orelse return error.NoGlobal;

        // Get runtime context for wrapper caching
        const runtime_ctx = context_manager.getOrCreate(context, self.allocator) catch |err| {
            std.debug.print("Warning: Failed to get runtime context: {}\n", .{err});
            return;
        };

        // Register based on context type
        switch (self.context_type) {
            .window => {
                try self.registerWindowGlobals(isolate, context, global_obj, runtime_ctx);
            },
            .worker => {
                try self.registerWorkerGlobals(isolate, context, global_obj, runtime_ctx);
            },
            else => {
                // Shared worker and service worker - TODO
            },
        }

        // Register common globals (setTimeout, setInterval, console, fetch, etc.)
        try self.registerCommonGlobals(isolate, context, global_obj);
    }

    /// Register Window context globals
    fn registerWindowGlobals(
        self: *BrowserContext,
        isolate: *v8.ffi.Isolate,
        context: *v8.ffi.Context,
        global_obj: *v8.ffi.Object,
        runtime_ctx: runtime.Context,
    ) !void {
        // NOTE: We intentionally DO NOT set Window.prototype as the global's prototype.
        // The reason is that Window.prototype has getters (like 'self', 'window') that
        // try to access internal fields of a Window instance. The global object is NOT
        // a proper Window instance and doesn't have those internal fields set up.
        // Setting the prototype would cause "Internal field out of bounds" crashes.
        //
        // Instead, we:
        // 1. Register needed globals (document, navigator, etc.) directly on global
        // 2. Set window/self as accessor properties in setupGlobalAliases()
        //
        // NOTE: window/self are NOT set here - they're defined as accessor properties
        // in setupGlobalAliases() with proper global object checks per WebIDL §3.8.

        // Get __internal object for storing singleton values
        // The accessor properties defined in setupGlobalAliases() read from __internal
        const internal_key = v8.ffi.v8_String_NewFromUtf8(isolate, "__internal", 10) orelse return error.StringCreateFailed;
        const internal_obj = v8.ffi.v8_Object_Get(global_obj, context, @ptrCast(internal_key)) orelse {
            std.debug.print("Warning: __internal object not found on global\n", .{});
            return error.ObjectNotFound;
        };

        // Register Document singleton (stored in __internal.document)
        {
            const Document = interfaces.Document;
            const doc_instance = Document.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create document singleton: {}\n", .{err});
                return;
            };
            self.document_instance = doc_instance;

            // CRITICAL: Link the document to the Window's internal state.
            // This is required for frames[index] to work, as the indexed getter
            // needs to access the document to find iframe elements when scripts
            // run during HTML parsing (before initializeIframeBrowsingContexts).
            if (self.window_instance) |win| {
                impls.Window.setDocument(win, doc_instance);
            }

            const v8_document = v8.template_registry.wrapInstanceAsV8Object(
                doc_instance,
                "Document",
                isolate,
                context,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap document singleton: {}\n", .{err});
                return;
            };

            const doc_key = v8.ffi.v8_String_NewFromUtf8(isolate, "document", 8) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(@ptrCast(internal_obj), context, @ptrCast(doc_key), @ptrCast(v8_document));
        }

        // Register Navigator singleton (stored in __internal.navigator)
        {
            const Navigator = interfaces.Navigator;
            const nav_instance = Navigator.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create navigator singleton: {}\n", .{err});
                return;
            };
            self.navigator_instance = nav_instance;

            const v8_navigator = v8.template_registry.wrapInstanceAsV8Object(
                nav_instance,
                "Navigator",
                isolate,
                context,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap navigator singleton: {}\n", .{err});
                return;
            };

            const nav_key = v8.ffi.v8_String_NewFromUtf8(isolate, "navigator", 9) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(@ptrCast(internal_obj), context, @ptrCast(nav_key), @ptrCast(v8_navigator));
        }

        // Register Location singleton (stored in __internal.location)
        {
            const Location = interfaces.Location;
            const loc_instance = Location.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create location singleton: {}\n", .{err});
                return;
            };
            self.location_instance = loc_instance;

            const v8_location = v8.template_registry.wrapInstanceAsV8Object(
                loc_instance,
                "Location",
                isolate,
                context,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap location singleton: {}\n", .{err});
                return;
            };

            const loc_key = v8.ffi.v8_String_NewFromUtf8(isolate, "location", 8) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(@ptrCast(internal_obj), context, @ptrCast(loc_key), @ptrCast(v8_location));
        }

        // Register History singleton (stored in __internal.history)
        {
            const History = interfaces.History;
            const hist_instance = History.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create history singleton: {}\n", .{err});
                return;
            };
            self.history_instance = hist_instance;

            const v8_history = v8.template_registry.wrapInstanceAsV8Object(
                hist_instance,
                "History",
                isolate,
                context,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap history singleton: {}\n", .{err});
                return;
            };

            const hist_key = v8.ffi.v8_String_NewFromUtf8(isolate, "history", 7) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(@ptrCast(internal_obj), context, @ptrCast(hist_key), @ptrCast(v8_history));
        }

        // Register Performance singleton (stored in __internal.performance)
        {
            const Performance = interfaces.Performance;
            const perf_instance = Performance.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create performance singleton: {}\n", .{err});
                return;
            };
            self.performance_instance = perf_instance;

            const v8_performance = v8.template_registry.wrapInstanceAsV8Object(
                perf_instance,
                "Performance",
                isolate,
                context,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap performance singleton: {}\n", .{err});
                return;
            };

            const perf_key = v8.ffi.v8_String_NewFromUtf8(isolate, "performance", 11) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(@ptrCast(internal_obj), context, @ptrCast(perf_key), @ptrCast(v8_performance));
        }

        // Register HTMLDocument as legacy alias for Document
        // Per HTML spec, HTMLDocument is a historical alias that maps to Document
        {
            const doc_key = v8.ffi.v8_String_NewFromUtf8(isolate, "Document", 8) orelse return error.StringCreateFailed;
            const doc_ctor = v8.ffi.v8_Object_Get(global_obj, context, @ptrCast(doc_key));
            if (doc_ctor) |ctor| {
                const html_doc_key = v8.ffi.v8_String_NewFromUtf8(isolate, "HTMLDocument", 12) orelse return error.StringCreateFailed;
                _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(html_doc_key), ctor);
            }
        }
    }

    /// Register Worker context globals
    fn registerWorkerGlobals(
        self: *BrowserContext,
        isolate: *v8.ffi.Isolate,
        context: *v8.ffi.Context,
        global_obj: *v8.ffi.Object,
        runtime_ctx: runtime.Context,
    ) !void {
        // NOTE: 'self' is set up as an accessor property in setupGlobalAliases()
        // with proper global object checks per WebIDL §3.8.

        // Register WorkerNavigator singleton
        {
            const WorkerNavigator = interfaces.WorkerNavigator;
            const nav_instance = WorkerNavigator.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create worker navigator singleton: {}\n", .{err});
                return;
            };

            const v8_navigator = v8.template_registry.wrapInstanceAsV8Object(
                nav_instance,
                "WorkerNavigator",
                isolate,
                context,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap worker navigator singleton: {}\n", .{err});
                return;
            };

            const nav_key = v8.ffi.v8_String_NewFromUtf8(isolate, "navigator", 9) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(nav_key), @ptrCast(v8_navigator));
        }

        // Register WorkerLocation singleton
        {
            const WorkerLocation = interfaces.WorkerLocation;
            const loc_instance = WorkerLocation.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create worker location singleton: {}\n", .{err});
                return;
            };

            const v8_location = v8.template_registry.wrapInstanceAsV8Object(
                loc_instance,
                "WorkerLocation",
                isolate,
                context,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap worker location singleton: {}\n", .{err});
                return;
            };

            const loc_key = v8.ffi.v8_String_NewFromUtf8(isolate, "location", 8) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(loc_key), @ptrCast(v8_location));
        }

        // Register importScripts() - loads and executes scripts synchronously
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, importScriptsCallback, null) orelse return error.FunctionTemplateCreateFailed;
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, context) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "importScripts", 13) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(key), @ptrCast(func));
        }

        // Register postMessage() - stub for WPT tests (sends message to parent context)
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, workerPostMessageCallback, null) orelse return error.FunctionTemplateCreateFailed;
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, context) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "postMessage", 11) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(key), @ptrCast(func));
        }

        // Register close() - stub for WPT tests (terminates the worker)
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, workerCloseCallback, null) orelse return error.FunctionTemplateCreateFailed;
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, context) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "close", 5) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(key), @ptrCast(func));
        }

        // Register isSecureContext on Worker global scope
        // Per HTML spec, WorkerGlobalScope exposes isSecureContext
        {
            const is_secure = isSecureUrl(self.test_url);
            const is_secure_key = v8.ffi.v8_String_NewFromUtf8(isolate, "isSecureContext", 15) orelse return error.StringCreateFailed;
            if (v8.ffi.v8_Boolean_New(isolate, is_secure)) |is_secure_val| {
                _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(is_secure_key), is_secure_val);
            }
        }

        // Register origin on Worker global scope
        {
            const origin_key = v8.ffi.v8_String_NewFromUtf8(isolate, "origin", 6) orelse return error.StringCreateFailed;
            // Extract origin from test_url (scheme://host:port)
            const origin_str = blk: {
                if (std.mem.startsWith(u8, self.test_url, "http://") or std.mem.startsWith(u8, self.test_url, "https://")) {
                    const scheme_end = std.mem.indexOf(u8, self.test_url, "://") orelse break :blk "null";
                    const after_scheme = self.test_url[scheme_end + 3 ..];
                    const path_start = std.mem.indexOf(u8, after_scheme, "/") orelse after_scheme.len;
                    break :blk self.test_url[0 .. scheme_end + 3 + path_start];
                }
                break :blk "null";
            };
            const origin_val = v8.ffi.v8_String_NewFromUtf8(isolate, origin_str.ptr, @intCast(origin_str.len)) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(origin_key), @ptrCast(origin_val));
        }
    }

    /// Register common globals (setTimeout, fetch, console, etc.)
    fn registerCommonGlobals(
        self: *BrowserContext,
        isolate: *v8.ffi.Isolate,
        context: *v8.ffi.Context,
        global_obj: *v8.ffi.Object,
    ) !void {
        // Register fetch() as a global function
        // This is the approach from whatwg-d6ike: Direct Global Function Registration
        // (bypasses Window instance issues, similar to how setTimeout is exposed)
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, fetchCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 1); // fetch(input, init?)
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, context) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "fetch", 5) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(key), @ptrCast(func));
        }

        // Register setTimeout (mock implementation for now)
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, setTimeoutCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 1);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, context) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "setTimeout", 10) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(key), @ptrCast(func));
        }

        // Register clearTimeout
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, clearTimeoutCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 1);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, context) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "clearTimeout", 12) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(key), @ptrCast(func));
        }

        // Register setInterval (uses proper interval callback)
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, setIntervalCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 1);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, context) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "setInterval", 11) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(key), @ptrCast(func));
        }

        // Register clearInterval
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, clearTimeoutCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 1);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, context) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "clearInterval", 13) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(key), @ptrCast(func));
        }

        // Register EventTarget methods on the global object
        // The global object (window/self) needs these methods for testharness.js to work
        // testharness.js calls on_event(window, 'load', callback) which internally calls
        // window.addEventListener('load', callback, false)
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, addEventListenerCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 2);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, context) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "addEventListener", 16) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(key), @ptrCast(func));
        }

        // Register removeEventListener
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, removeEventListenerCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 2);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, context) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "removeEventListener", 19) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(key), @ptrCast(func));
        }

        // Register dispatchEvent
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, dispatchEventCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 1);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, context) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "dispatchEvent", 13) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(key), @ptrCast(func));
        }

        // Register console object with proper WebIDL namespace semantics
        // Per WebIDL spec §3.8.1 "Namespace objects":
        // - The prototype chain is: console -> empty object -> Object.prototype
        // - The namespace has Symbol.toStringTag = "console" (non-writable, non-enumerable, configurable)
        // - All console methods are own properties
        //
        // Per WHATWG Console Standard, methods that take a label (count, countReset,
        // time, timeLog, timeEnd) must call toString() on the label if it's an object,
        // and re-throw any exceptions from the toString() call.
        {
            const console_script =
                \\(function() {
                \\  function consoleNoop() {}
                \\  
                \\  // Helper to convert label to string per WHATWG Console Standard
                \\  // If label is an object, calls its toString() method and re-throws exceptions
                \\  function convertLabel(label) {
                \\    if (label === undefined) {
                \\      return "default";
                \\    }
                \\    // Per spec: If label is an object, call its toString()
                \\    // This allows exceptions from toString() to propagate
                \\    if (label !== null && typeof label === "object") {
                \\      return label.toString();
                \\    }
                \\    return String(label);
                \\  }
                \\  
                \\  // Internal state for count and time operations
                \\  var countMap = {};
                \\  var timerMap = {};
                \\  
                \\  // Create the empty prototype object (between console and Object.prototype)
                \\  // Per WebIDL: "The [[Prototype]] internal slot of a namespace object is
                \\  // an immutable prototype exotic object that has no own properties and
                \\  // [[Prototype]] is %ObjectPrototype%"
                \\  var consoleProto = Object.create(Object.prototype);
                \\  Object.freeze(consoleProto);  // Make prototype immutable
                \\  
                \\  // Create console object with the proper prototype chain
                \\  globalThis.console = Object.create(consoleProto);
                \\  
                \\  // Define all console methods as own properties
                \\  // Methods that take a label parameter must call convertLabel()
                \\  var methods = {
                \\    log: consoleNoop,
                \\    warn: consoleNoop,
                \\    error: consoleNoop,
                \\    info: consoleNoop,
                \\    debug: consoleNoop,
                \\    trace: consoleNoop,
                \\    dir: consoleNoop,
                \\    dirxml: consoleNoop,
                \\    table: consoleNoop,
                \\    assert: consoleNoop,
                \\    clear: consoleNoop,
                \\    group: consoleNoop,
                \\    groupCollapsed: consoleNoop,
                \\    groupEnd: consoleNoop,
                \\  };
                \\  
                \\  // Helper to create a function with a specific length property
                \\  // Per WebIDL, when all parameters are optional, length should be 0
                \\  function createLabelMethod(fn, length) {
                \\    Object.defineProperty(fn, 'length', { value: length, configurable: true });
                \\    return fn;
                \\  }
                \\  
                \\  // count, countReset, time, timeLog, timeEnd must call toString() on label objects
                \\  // Per WebIDL, these functions have length 0 because all params are optional
                \\  methods.count = createLabelMethod(function(label) {
                \\    var key = convertLabel(label);
                \\    countMap[key] = (countMap[key] || 0) + 1;
                \\  }, 0);
                \\  
                \\  methods.countReset = createLabelMethod(function(label) {
                \\    var key = convertLabel(label);
                \\    delete countMap[key];
                \\  }, 0);
                \\  
                \\  methods.time = createLabelMethod(function(label) {
                \\    var key = convertLabel(label);
                \\    if (!(key in timerMap)) {
                \\      timerMap[key] = Date.now();
                \\    }
                \\  }, 0);
                \\  
                \\  methods.timeLog = createLabelMethod(function(label) {
                \\    var key = convertLabel(label);
                \\    // No-op for output, but still convert the label
                \\  }, 0);
                \\  
                \\  methods.timeEnd = createLabelMethod(function(label) {
                \\    var key = convertLabel(label);
                \\    delete timerMap[key];
                \\  }, 0);
                \\  
                \\  for (var name in methods) {
                \\    Object.defineProperty(globalThis.console, name, {
                \\      value: methods[name],
                \\      writable: true,
                \\      enumerable: true,
                \\      configurable: true
                \\    });
                \\  }
                \\  
                \\  // Add Symbol.toStringTag per WebIDL namespace semantics
                \\  // Per WebIDL: "@@toStringTag is the namespace identifier with
                \\  // writable: false, enumerable: false, configurable: true"
                \\  Object.defineProperty(globalThis.console, Symbol.toStringTag, {
                \\    value: "console",
                \\    writable: false,
                \\    enumerable: false,
                \\    configurable: true
                \\  });
                \\})();
            ;
            self.executeScript(console_script) catch |err| {
                std.debug.print("Warning: Failed to register console: {}\n", .{err});
            };
        }

        // Register btoa/atob for base64 encoding/decoding
        // These are needed by some WPT tests (e.g., percent-encoding.window.js)
        {
            const btoa_atob_script =
                \\(function() {
                \\  // btoa: binary string to base64
                \\  globalThis.btoa = function(str) {
                \\    var chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
                \\    var result = '';
                \\    var i = 0;
                \\    while (i < str.length) {
                \\      var a = str.charCodeAt(i++) || 0;
                \\      var b = str.charCodeAt(i++) || 0;
                \\      var c = str.charCodeAt(i++) || 0;
                \\      var triplet = (a << 16) | (b << 8) | c;
                \\      result += chars[(triplet >> 18) & 63];
                \\      result += chars[(triplet >> 12) & 63];
                \\      result += (i > str.length + 1) ? '=' : chars[(triplet >> 6) & 63];
                \\      result += (i > str.length) ? '=' : chars[triplet & 63];
                \\    }
                \\    return result;
                \\  };
                \\  
                \\  // atob: base64 to binary string
                \\  globalThis.atob = function(str) {
                \\    var chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
                \\    str = str.replace(/=+$/, '');
                \\    var result = '';
                \\    var i = 0;
                \\    while (i < str.length) {
                \\      var a = chars.indexOf(str[i++]);
                \\      var b = chars.indexOf(str[i++]);
                \\      var c = chars.indexOf(str[i++]);
                \\      var d = chars.indexOf(str[i++]);
                \\      var triplet = (a << 18) | (b << 12) | (c << 6) | d;
                \\      result += String.fromCharCode((triplet >> 16) & 255);
                \\      if (c !== -1) result += String.fromCharCode((triplet >> 8) & 255);
                \\      if (d !== -1) result += String.fromCharCode(triplet & 255);
                \\    }
                \\    return result;
                \\  };
                \\})();
            ;
            self.executeScript(btoa_atob_script) catch |err| {
                std.debug.print("Warning: Failed to register btoa/atob: {}\n", .{err});
            };
        }

        // Register getComputedStyle as a global function
        // Per CSSOM spec, window.getComputedStyle(element, pseudoElt) returns computed styles
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, getComputedStyleCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 1); // getComputedStyle(element, pseudoElt?)
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, context) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "getComputedStyle", 16) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(key), @ptrCast(func));
        }
    }

    /// Register WPT result callbacks (__wpt_report_result, __wpt_report_completion)
    fn registerWptCallbacks(self: *BrowserContext) !void {
        const isolate = self.isolate orelse return error.NotInitialized;
        const context = self.context orelse return error.NotInitialized;
        const global_obj = v8.ffi.v8_Context_Global(context) orelse return error.NoGlobal;

        // Register __wpt_report_result callback
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, wptReportResultCallback, null) orelse return error.FunctionTemplateCreateFailed;
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, context) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "__wpt_report_result", 19) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(key), @ptrCast(func));
        }

        // Register __wpt_report_completion callback
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, wptReportCompletionCallback, null) orelse return error.FunctionTemplateCreateFailed;
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, context) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "__wpt_report_completion", 23) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(key), @ptrCast(func));
        }

        // Register __wpt_debug_log callback (for debugging testharness.js)
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, wptDebugLogCallback, null) orelse return error.FunctionTemplateCreateFailed;
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, context) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "__wpt_debug_log", 15) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(key), @ptrCast(func));
        }
    }

    /// Set the test URL (updates location object and secure context flag)
    /// For WPT tests with .https. in filename, rewrites URL to use https:// scheme
    /// to properly simulate secure context behavior.
    pub fn setTestUrl(self: *BrowserContext, url: []const u8) !void {
        self.allocator.free(self.test_url);
        self.test_url = try self.allocator.dupe(u8, url);

        // Determine if this should be treated as an HTTPS URL
        // WPT tests with .https. or .h2. in filename should use https:// scheme
        // Per WPT convention:
        //   - .https. tests use port 8443
        //   - .h2. tests use port 9000 (HTTP/2)
        const effective_url = blk: {
            const is_h2 = std.mem.indexOf(u8, url, ".h2.") != null;
            const is_https = std.mem.indexOf(u8, url, ".https.") != null;

            if (is_h2 or is_https) {
                // Determine target port based on test type
                const target_port: []const u8 = if (is_h2) "9000" else "8443";

                // Rewrite http:// to https:// for location object
                if (std.mem.startsWith(u8, url, "http://localhost:8000")) {
                    // Replace http://localhost:8000 with https://localhost:<port>
                    const rest = url["http://localhost:8000".len..];
                    break :blk try std.fmt.allocPrint(self.allocator, "https://localhost:{s}{s}", .{ target_port, rest });
                } else if (std.mem.startsWith(u8, url, "http://")) {
                    // Generic http:// to https:// replacement (preserve original port if present)
                    const rest = url["http://".len..];
                    break :blk try std.fmt.allocPrint(self.allocator, "https://{s}", .{rest});
                }
            }
            break :blk try self.allocator.dupe(u8, url);
        };
        defer if (effective_url.ptr != url.ptr) self.allocator.free(effective_url);

        // Update location object with effective URL (may be https:// for .https. tests)
        if (self.location_instance) |loc| {
            impls.Location.setURLFromString(loc, effective_url) catch |err| {
                std.debug.print("Warning: Failed to update location URL: {}\n", .{err});
            };
        }

        // Update secure context flag based on URL scheme
        // Per Secure Contexts spec: https, wss, file schemes are secure
        // localhost is also considered secure
        const is_secure = isSecureUrl(url);

        // Update the Zig-side Window instance (if exists)
        if (self.window_instance) |win| {
            impls.Window.setIsSecureContext(win, is_secure);
        }

        // Update JavaScript globals based on context type
        if (self.isolate != null and self.context != null) {
            switch (self.context_type) {
                .window => {
                    // Window: update __internal.isSecureContext via accessor property
                    const js_script = if (is_secure)
                        "globalThis.__internal.isSecureContext = true;"
                    else
                        "globalThis.__internal.isSecureContext = false;";

                    self.executeScript(js_script) catch |err| {
                        std.debug.print("Warning: Failed to update isSecureContext: {}\n", .{err});
                    };
                },
                .worker, .shared_worker, .service_worker => {
                    // Worker: update isSecureContext directly on globalThis
                    const js_script = if (is_secure)
                        "globalThis.isSecureContext = true;"
                    else
                        "globalThis.isSecureContext = false;";

                    self.executeScript(js_script) catch |err| {
                        std.debug.print("Warning: Failed to update worker isSecureContext: {}\n", .{err});
                    };

                    // Also update WorkerLocation with the effective URL
                    // WorkerLocation is stored directly on globalThis.location
                    const loc_script = std.fmt.allocPrint(self.allocator,
                        \\(function() {{
                        \\  if (typeof location !== 'undefined' && location && typeof location._setHref === 'function') {{
                        \\    location._setHref("{s}");
                        \\  }}
                        \\}})();
                    , .{effective_url}) catch |err| {
                        std.debug.print("Warning: Failed to format location update script: {}\n", .{err});
                        return;
                    };
                    defer self.allocator.free(loc_script);

                    self.executeScript(loc_script) catch {
                        // WorkerLocation might not have _setHref, that's OK
                    };
                },
            }
        }
    }

    /// Check if a URL indicates a secure context
    /// Per WPT convention, tests with .https. or .h2. in the filename should be treated
    /// as secure contexts. Plain HTTP localhost is NOT considered secure for WPT tests
    /// (unlike the general Secure Contexts spec) to allow testing non-secure context behavior.
    fn isSecureUrl(url: []const u8) bool {
        // Check for secure schemes first
        if (std.mem.startsWith(u8, url, "https://") or
            std.mem.startsWith(u8, url, "wss://"))
        {
            return true;
        }

        // WPT convention: .https. in filename indicates secure context test
        // These tests are meant to be run over HTTPS but we serve them over HTTP
        if (std.mem.indexOf(u8, url, ".https.") != null) {
            return true;
        }

        // Also check for .h2. (HTTP/2 tests which require secure context)
        if (std.mem.indexOf(u8, url, ".h2.") != null) {
            return true;
        }

        // NOTE: We intentionally do NOT treat plain http://localhost as secure here.
        // While the Secure Contexts spec does consider localhost secure, WPT tests
        // need to be able to test non-secure context behavior on localhost.
        // Tests that need secure context use .https. or .h2. in their filenames.

        return false;
    }

    /// Start tracking results for a new test file
    pub fn startTest(self: *BrowserContext, test_path: []const u8) !void {
        try self.result_collector.startTest(test_path);
        // Set result collector for V8 callbacks
        setResultCollector(&self.result_collector);
    }

    /// Load and execute a script file
    pub fn loadScript(self: *BrowserContext, script_path: []const u8) !void {
        _ = self.isolate orelse return error.NotInitialized;
        _ = self.context orelse return error.NotInitialized;

        // Read script file
        const file = try std.fs.cwd().openFile(script_path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 10 * 1024 * 1024); // 10MB max
        defer self.allocator.free(content);

        try self.executeScript(content);
    }

    /// Load testharness.js and testharnessreport.js
    pub fn loadTestHarness(self: *BrowserContext) !void {
        // Re-ensure global aliases are set before loading testharness.js
        // testharness.js may overwrite or depend on these globals
        try self.setupGlobalAliases();

        const harness_path = try std.fs.path.join(self.allocator, &.{ self.wpt_root, "resources", "testharness.js" });
        defer self.allocator.free(harness_path);

        try self.loadScript(harness_path);

        // Load our custom testharnessreport.js content (inline)
        try self.executeScript(test_harness.testharnessreport_js);
    }

    /// Execute inline script content
    pub fn executeScript(self: *BrowserContext, content: []const u8) !void {
        const isolate = self.isolate orelse return error.NotInitialized;
        const context = self.context orelse return error.NotInitialized;

        // Create V8 string from content
        const source_str = v8.ffi.v8_String_NewFromUtf8(isolate, content.ptr, @intCast(content.len)) orelse return error.StringCreateFailed;

        // Compile script (use safe version to capture errors)
        const compile_result = v8.ffi.v8_Script_Compile_Safe(context, source_str);
        defer v8.ffi.v8_FreeScriptCompileResult(compile_result);

        if (compile_result.error_info) |err| {
            std.debug.print("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
            std.debug.print("║ V8 COMPILE ERROR                                             ║\n", .{});
            std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
            if (err.getMessage()) |msg| {
                std.debug.print("Exception: {s}\n", .{msg});
            }
            if (err.getStackTrace()) |stack| {
                std.debug.print("Stack:\n{s}\n", .{stack});
            }
            if (err.getSourceLine()) |line| {
                std.debug.print("Source line: {s}\n", .{line});
            }
            if (err.line_number >= 0) {
                std.debug.print("Location: line {d}, column {d}\n", .{ err.line_number, err.column_number });
            }
            const preview_len = @min(content.len, 500);
            std.debug.print("Script preview ({d} chars total):\n{s}...\n", .{ content.len, content[0..preview_len] });
            std.debug.print("────────────────────────────────────────────────────────────────\n\n", .{});
            return error.CompileError;
        }

        const script = compile_result.script orelse return error.CompileError;

        // Run script (use safe version to capture errors)
        const run_result = v8.ffi.v8_Script_Run_Safe(context, script);
        defer v8.ffi.v8_FreeScriptRunResult(run_result);

        if (run_result.error_info) |err| {
            std.debug.print("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
            std.debug.print("║ V8 RUNTIME ERROR                                             ║\n", .{});
            std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
            if (err.getMessage()) |msg| {
                std.debug.print("Exception: {s}\n", .{msg});
            }
            if (err.getStackTrace()) |stack| {
                std.debug.print("Stack:\n{s}\n", .{stack});
            }
            if (err.getSourceLine()) |line| {
                std.debug.print("Source line: {s}\n", .{line});
            }
            if (err.line_number >= 0) {
                std.debug.print("Location: line {d}, column {d}\n", .{ err.line_number, err.column_number });
            }
            const preview_len = @min(content.len, 500);
            std.debug.print("Script preview ({d} chars total):\n{s}...\n", .{ content.len, content[0..preview_len] });
            std.debug.print("────────────────────────────────────────────────────────────────\n\n", .{});
            return error.RuntimeError;
        }

        // Run microtasks
        v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);
    }

    /// Execute a test and wait for completion
    pub fn executeTest(self: *BrowserContext, test_path: []const u8, test_content: []const u8, timeout: config.Timeout) !test_harness.TestResult {
        // Start tracking results for this test file
        try self.result_collector.startTest(test_path);

        // Set result collector for V8 callbacks
        // Timer interface is set once in initialize() and persists for the context lifetime
        setResultCollector(&self.result_collector);
        defer clearResultCollector();

        // Set WPT root and test path for fetch callback URL resolution
        setWptRoot(self.wpt_root);
        setCurrentTestPath(test_path);

        // Execute test script
        try self.executeScript(test_content);

        // Trigger testharness.js completion - it normally waits for window load
        // but our mock environment doesn't have proper event dispatch
        try self.triggerTestHarnessCompletion();

        // Run event loop until completion or timeout
        const timeout_ms = timeout.toMillis();
        try self.runEventLoop(timeout_ms);

        // Collect and return results
        return self.result_collector.finalize(self.allocator, test_path);
    }

    /// Trigger testharness.js completion
    /// testharness.js in WindowTestEnvironment waits for window load event,
    /// but our mock environment doesn't have proper event dispatch.
    /// The `done()` function is exposed globally by testharness.js and can
    /// be called to signal that all tests have been defined.
    pub fn triggerTestHarnessCompletion(self: *BrowserContext) !void {
        // Trigger testharness.js completion.
        //
        // testharness.js's WindowTestEnvironment waits for the window 'load' event
        // before considering tests complete. We simulate this by:
        // 1. Setting test_environment.all_loaded = true (simulates window load)
        // 2. Calling done() to signal we're done defining tests
        // 3. Adding a fallback timeout to force completion if needed
        //
        // For sync tests, they've already run during HTML parsing, so we just
        // need to trigger the completion callbacks.
        const completion_script =
            \\(function() {
            \\  // Simulate window load event by setting all_loaded
            \\  if (typeof test_environment !== 'undefined' && test_environment) {
            \\    test_environment.all_loaded = true;
            \\  }
            \\  
            \\  // Use setTimeout to ensure any sync tests have completed
            \\  setTimeout(function() {
            \\    // Try to trigger testharness.js completion
            \\    if (typeof done === 'function') {
            \\      try { done(); } catch(e) {}
            \\    }
            \\    
            \\    // Fallback: force completion after brief delay if not already done
            \\    // This handles edge cases where testharness.js doesn't call our callback
            \\    setTimeout(function() {
            \\      if (typeof __wpt_report_completion === 'function') {
            \\        __wpt_report_completion(0, null);
            \\      }
            \\    }, 50);
            \\  }, 0);
            \\})();
        ;
        try self.executeScript(completion_script);
    }

    /// Run event loop until completion or timeout
    /// This implements proper browser event loop semantics:
    /// 1. Process ready timers (macrotasks from setTimeout/setInterval via libuv)
    /// 2. Run V8 microtasks (Promise resolution)
    /// 3. Check completion condition
    /// 4. Sleep until next timer or short interval
    pub fn runEventLoop(self: *BrowserContext, timeout_ms: u64) !void {
        const event_loop = self.v8_event_loop orelse return error.NotInitialized;

        const start_time = std.time.milliTimestamp();

        while (true) {
            const now = std.time.milliTimestamp();
            const elapsed: u64 = @intCast(now - start_time);

            // 1. Run one iteration of the V8 event loop
            // This processes ready timers (via libuv), runs tasks, and runs microtasks
            const did_work = event_loop.eventLoop().runOnce();

            // 2. Check if completion callback has been called
            if (self.result_collector.completed) {
                return;
            }

            // 3. Check timeout
            if (elapsed > timeout_ms) {
                // Mark the test as timed out
                try self.result_collector.finishTest(.timeout, "Test timed out", elapsed);
                return;
            }

            // 4. If no work was done (no timers ready, no tasks), briefly yield
            // to avoid busy-waiting. When work is being done, keep processing.
            if (!did_work) {
                std.Thread.sleep(1 * std.time.ns_per_ms);
            }
        }
    }

    /// Execute a test and wait for completion with async support
    /// This handles promise_test, async_test, and explicit_done tests
    pub fn executeTestAsync(self: *BrowserContext, test_path: []const u8, test_content: []const u8, timeout: config.Timeout) !test_harness.TestResult {
        // Start tracking this test
        try self.startTest(test_path);

        // Execute test script
        try self.executeScript(test_content);

        // Run event loop until completion or timeout
        // This handles:
        // - promise_test: Promises resolve via microtask queue
        // - async_test: t.done() triggers completion callback
        // - explicit_done: done() triggers completion callback
        const timeout_ms = timeout.toMillis();
        try self.runEventLoop(timeout_ms);

        // Return the collected results
        return self.result_collector.finalize(self.allocator, test_path);
    }

    /// Load and parse an HTML document, replacing the current document
    ///
    /// This is the main entry point for HTML tests in the WPT runner.
    /// It uses the HTMLParser to parse HTML content, build the DOM tree,
    /// and execute scripts during parsing.
    ///
    /// @param html_content The HTML content to parse
    /// @param base_url The base URL for resolving relative URLs
    /// @return void on success, error on failure
    pub fn loadHTMLDocument(self: *BrowserContext, html_content: []const u8, base_url: []const u8) !void {
        const runtime_ctx = context_manager.getOrCreate(self.context.?, self.allocator) catch |err| {
            std.debug.print("Failed to get runtime context: {}\n", .{err});
            return error.NotInitialized;
        };

        // Update location object with the document's URL
        try self.setTestUrl(base_url);

        // Use HTMLParser from impls module
        const HTMLParser = impls.HTMLParser;

        // Create script loader that intercepts testharnessreport.js
        // but falls back to HTTP fetch for everything else (default behavior)
        const script_loader = HTMLParser.ScriptLoader{
            .context = self,
            .loadScript = wptScriptLoader,
        };

        // CRITICAL FIX: Pass the existing document to the parser!
        // The document was created and registered in V8 during initialize().
        // By passing it to the parser, scripts executing DURING parsing can
        // access DOM elements via document.getElementById(), querySelector(), etc.
        // Previously, the parser created a NEW document internally, and V8's
        // document reference was only updated AFTER parsing - too late for scripts!
        const document = self.document_instance orelse {
            std.debug.print("ERROR: document_instance is null - initialize() must be called first\n", .{});
            return error.NotInitialized;
        };

        // Parse HTML into the existing document (already registered in V8)
        _ = HTMLParser.parseHTMLWithScripting(
            self.allocator,
            runtime_ctx,
            html_content,
            .{
                .scripting_enabled = true,
                .base_url = base_url,
                .script_loader = script_loader,
                .existing_document = document,
            },
        ) catch |err| {
            std.debug.print("HTML parse error: {}\n", .{err});
            return error.ParseError;
        };

        // Document is already registered in V8 - no need to update the reference!
        // The existing document_instance has been populated with the parsed DOM.

        // Initialize browsing contexts for any iframes in the document.
        // This is necessary because when iframes are parsed, their browsing contexts
        // aren't automatically created (that requires DOM insertion hooks which we
        // don't have). We need to initialize them so that window.frames[N] works.
        //
        // This is done by calling contentWindow on each iframe, which triggers lazy
        // initialization of its browsing context and V8 context.
        self.initializeIframeBrowsingContexts(document) catch |err| {
            // Non-fatal - some iframes may not need initialization
            std.debug.print("Warning: Failed to initialize iframe browsing contexts: {}\n", .{err});
        };
    }

    /// Initialize browsing contexts for all iframes in a document.
    /// This triggers lazy initialization of iframe browsing contexts by accessing
    /// their contentWindow property.
    fn initializeIframeBrowsingContexts(_: *BrowserContext, document: *runtime.Instance) !void {
        // Get all iframe elements using getElementsByTagName
        const iframes = try interfaces.Document.call_getElementsByTagName(
            document,
            runtime.DOMString.initInterned("iframe"),
        );

        // Get the collection length
        const length = try interfaces.HTMLCollection.get_length(iframes);
        if (length == 0) return;

        // Access contentWindow on each iframe to trigger browsing context initialization
        var i: u32 = 0;
        while (i < length) : (i += 1) {
            const element = try interfaces.HTMLCollection.call_item(iframes, i);
            if (element) |iframe_elem| {
                // Cast to HTMLIFrameElement and access contentWindow
                // This triggers IFrameIntegration.ensureBrowsingContext
                _ = impls.HTMLIFrameElement.get_contentWindow(iframe_elem) catch |err| {
                    std.debug.print("Warning: Failed to initialize iframe {d}: {}\n", .{ i, err });
                };
            }
        }
    }

    /// Fire the DOMContentLoaded event on the document
    ///
    /// NOTE: For HTML parsing via loadHTMLDocument(), DOMContentLoaded is now
    /// fired automatically by the HTMLParser after deferred scripts execute.
    /// This method is kept for:
    /// - Non-parsing contexts (e.g., dynamic document creation)
    /// - Manual triggering in tests
    /// - Compatibility with existing code
    ///
    /// Per HTML Standard §13.2.7 "The end" step 4:
    /// Fire an event named "DOMContentLoaded" at the Document object,
    /// with its bubbles attribute initialized to true.
    pub fn fireDOMContentLoaded(self: *BrowserContext) !void {
        const document = self.document_instance orelse return error.NotInitialized;

        // Create DOMContentLoaded event using call_constructor for proper initialization
        // Event type, bubbles = true, cancelable = false per HTML spec
        const runtime_ctx = context_manager.getOrCreate(self.context.?, self.allocator) catch return error.NotInitialized;
        const event_type = runtime.DOMString.initInterned("DOMContentLoaded");
        const event_init = dictionaries.EventInit{
            .bubbles = true,
            .cancelable = false,
        };
        const event = interfaces.Event.call_constructor(runtime_ctx, event_type, webidl.Opt(dictionaries.EventInit).passed(event_init)) catch return error.OutOfMemory;
        errdefer interfaces.Event.deinit(event);

        // Dispatch on document
        _ = interfaces.EventTarget.call_dispatchEvent(document, event) catch return error.DispatchError;
    }
};

/// Type-safe WPT script loader implementation
///
/// Intercepts testharnessreport.js to return our custom version with result callbacks.
/// For all other scripts, returns null to trigger the default HTTP fetch behavior.
///
/// This function receives a typed *BrowserContext pointer, eliminating the need
/// for manual anyopaque casts. The TypedScriptLoader wrapper handles the conversion.
fn wptScriptLoaderTyped(self: *BrowserContext, url: []const u8) ?[]const u8 {
    // Intercept testharnessreport.js and return our custom version
    // This ensures our result callbacks are registered with the testharness.js
    // that the HTML test actually loads (not our pre-loaded version)
    if (std.mem.eql(u8, url, "/resources/testharnessreport.js") or
        std.mem.endsWith(u8, url, "/testharnessreport.js"))
    {
        return self.allocator.dupe(u8, test_harness.testharnessreport_js) catch return null;
    }

    // For all other scripts, return null to use default HTTP fetch behavior
    // This ensures proper browser-like loading via wpt serve
    return null;
}

/// Legacy-compatible wrapper for the typed script loader.
/// Uses TypedScriptLoader to generate a function that casts anyopaque to *BrowserContext.
///
/// PATTERN: TypedScriptLoader demonstrates the comptime generic pattern for type-safe
/// callbacks. The HTMLParser needs a generic callback type for script loading, and
/// TypedScriptLoader provides compile-time type safety while generating an anyopaque-
/// compatible callback for the C/FFI boundary.
const wptScriptLoader = impls.HTMLParser.TypedScriptLoader(BrowserContext).makeTypedLoader(wptScriptLoaderTyped);

// =============================================================================
// Iframe Document Loading Support (Phase 4 of whatwg-wv486)
// =============================================================================

/// Parse charset from WPT .headers file content
/// Handles formats like:
/// - "Content-Type: text/html; charset=utf-8"
/// - "Content-Type: text/html;charset=utf-8"
/// - "Content-Type: text/html; charset=\"utf-8\""
pub fn parseCharsetFromHeaders(content: []const u8) ?[]const u8 {
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &.{ ' ', '\t', '\r' });

        // Check if this is a Content-Type header (case-insensitive)
        if (trimmed.len > 13) {
            // Check for "Content-Type:" prefix
            var is_content_type = true;
            const prefix = "content-type:";
            for (prefix, 0..) |expected, i| {
                if (i >= trimmed.len or std.ascii.toLower(trimmed[i]) != expected) {
                    is_content_type = false;
                    break;
                }
            }

            if (is_content_type) {
                const value = trimmed[13..]; // After "Content-Type:"

                // Find "charset=" (case-insensitive) in the value
                var i: usize = 0;
                while (i + 8 <= value.len) : (i += 1) {
                    // Check for "charset="
                    var found = true;
                    const charset_prefix = "charset=";
                    for (charset_prefix, 0..) |expected, j| {
                        if (i + j >= value.len or std.ascii.toLower(value[i + j]) != expected) {
                            found = false;
                            break;
                        }
                    }

                    if (found) {
                        const charset_start = i + 8;
                        var charset_end = charset_start;

                        // Handle quoted charset values
                        if (charset_start < value.len and (value[charset_start] == '"' or value[charset_start] == '\'')) {
                            const quote_char = value[charset_start];
                            charset_end = charset_start + 1;
                            while (charset_end < value.len and value[charset_end] != quote_char) {
                                charset_end += 1;
                            }
                            return value[charset_start + 1 .. charset_end];
                        }

                        // Unquoted: find end of charset value (semicolon, space, or end)
                        while (charset_end < value.len and
                            value[charset_end] != ';' and
                            value[charset_end] != ' ' and
                            value[charset_end] != '\r' and
                            value[charset_end] != '\n')
                        {
                            charset_end += 1;
                        }
                        return value[charset_start..charset_end];
                    }
                }
            }
        }
    }
    return null;
}

/// Read charset from a .headers file if it exists
/// Returns the charset label or null if no headers file or no charset specified
pub fn readHeadersFileCharset(allocator: std.mem.Allocator, file_path: []const u8) ?[]const u8 {
    // Construct .headers file path
    const headers_path = std.fmt.allocPrint(allocator, "{s}.headers", .{file_path}) catch return null;
    defer allocator.free(headers_path);

    // Try to read the headers file
    const headers_file = std.fs.cwd().openFile(headers_path, .{}) catch return null;
    defer headers_file.close();

    const headers_content = headers_file.readToEndAlloc(allocator, 4096) catch return null;
    defer allocator.free(headers_content);

    // Parse charset from headers
    return parseCharsetFromHeaders(headers_content);
}

/// Hook for iframe src loading
/// This is called by HTMLIFrameElement.set_src when a relative or HTTP URL is set.
/// The hook resolves the URL, loads the content, and fires the load event.
///
/// Returns true if the load was handled, false otherwise.
pub fn iframeSrcLoadHook(iframe_instance: *runtime.Instance, src: []const u8) bool {
    // Get the WPT context from thread-local storage
    const wpt_root = getWptRoot() orelse {
        std.debug.print("iframeSrcLoadHook: No WPT root set\n", .{});
        return false;
    };
    const test_path = getCurrentTestPath() orelse {
        std.debug.print("iframeSrcLoadHook: No test path set\n", .{});
        return false;
    };
    const allocator = current_allocator orelse {
        std.debug.print("iframeSrcLoadHook: No allocator set\n", .{});
        return false;
    };

    // Get test directory from test path
    const test_dir = if (std.mem.lastIndexOf(u8, test_path, "/")) |pos|
        test_path[0..pos]
    else
        "";

    // Resolve the src URL
    var resolved_path: []u8 = undefined;
    if (std.mem.startsWith(u8, src, "/")) {
        // Absolute path from WPT root
        resolved_path = std.fs.path.join(allocator, &.{ wpt_root, src[1..] }) catch {
            std.debug.print("iframeSrcLoadHook: Failed to join path\n", .{});
            return false;
        };
    } else if (std.mem.startsWith(u8, src, "http://") or std.mem.startsWith(u8, src, "https://")) {
        // HTTP URL - extract the path portion and resolve from WPT root
        // e.g., "http://web-platform.test:8000/webidl/foo.html" -> "/webidl/foo.html"
        const path_start = if (std.mem.indexOf(u8, src[7..], "/")) |pos| pos + 7 else src.len;
        if (path_start < src.len) {
            resolved_path = std.fs.path.join(allocator, &.{ wpt_root, src[path_start + 1 ..] }) catch {
                std.debug.print("iframeSrcLoadHook: Failed to join HTTP path\n", .{});
                return false;
            };
        } else {
            return false;
        }
    } else {
        // Relative path - resolve against test directory
        resolved_path = std.fs.path.join(allocator, &.{ wpt_root, test_dir, src }) catch {
            std.debug.print("iframeSrcLoadHook: Failed to join relative path\n", .{});
            return false;
        };
    }
    defer allocator.free(resolved_path);

    // Read the file content
    const file = std.fs.cwd().openFile(resolved_path, .{}) catch |err| {
        std.debug.print("iframeSrcLoadHook: Failed to open {s}: {}\n", .{ resolved_path, err });
        return false;
    };
    defer file.close();

    const content = file.readToEndAlloc(allocator, 10 * 1024 * 1024) catch |err| {
        std.debug.print("iframeSrcLoadHook: Failed to read file: {}\n", .{err});
        return false;
    };
    defer allocator.free(content);

    // Get runtime context for the current V8 context
    const isolate = v8.ffi.v8_Isolate_GetCurrent() orelse {
        std.debug.print("iframeSrcLoadHook: No V8 isolate\n", .{});
        return false;
    };
    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        std.debug.print("iframeSrcLoadHook: No V8 context\n", .{});
        return false;
    };
    const runtime_ctx = context_manager.getOrCreate(v8_context, allocator) catch {
        std.debug.print("iframeSrcLoadHook: Failed to get runtime context\n", .{});
        return false;
    };

    // Get iframe's internal state
    const HTMLIFrameElementImpl = impls.HTMLIFrameElement;
    const iframe_internal = HTMLIFrameElementImpl.getInternal(iframe_instance) orelse {
        std.debug.print("iframeSrcLoadHook: Failed to get iframe internal\n", .{});
        return false;
    };

    // Ensure browsing context exists for the iframe
    // We need the parent browsing context to create a child
    const parent_window = context_manager.getWindowForContext(v8_context) orelse {
        std.debug.print("iframeSrcLoadHook: No parent window\n", .{});
        return false;
    };

    const WindowImpl = impls.Window;
    const parent_window_internal = WindowImpl.getInternal(parent_window) orelse {
        std.debug.print("iframeSrcLoadHook: Failed to get parent window internal\n", .{});
        return false;
    };

    // Ensure browsing context exists
    _ = iframe_internal.integration.ensureBrowsingContext(
        @ptrCast(parent_window_internal.browsing_context),
    ) orelse {
        std.debug.print("iframeSrcLoadHook: Failed to ensure browsing context\n", .{});
        return false;
    };

    // Now ensure the iframe has a proper V8 context (triggers contentWindow lazy init)
    const iframe_content_window = HTMLIFrameElementImpl.get_contentWindow(iframe_instance) catch {
        std.debug.print("iframeSrcLoadHook: Failed to get contentWindow\n", .{});
        return false;
    };

    if (iframe_content_window == null) {
        std.debug.print("iframeSrcLoadHook: contentWindow is null\n", .{});
        return false;
    }

    // Get the iframe's V8 context and runtime context for parsing
    const iframe_v8_ctx: *v8.ffi.Context = @ptrCast(@alignCast(iframe_internal.integration.engine_context orelse {
        std.debug.print("iframeSrcLoadHook: No iframe V8 context\n", .{});
        return false;
    }));
    const iframe_runtime_ctx = context_manager.getOrCreate(iframe_v8_ctx, allocator) catch {
        std.debug.print("iframeSrcLoadHook: Failed to get iframe runtime context\n", .{});
        return false;
    };

    // CRITICAL: Enter the iframe's V8 context before parsing
    // Scripts in the iframe HTML need to run in the iframe's context, not the parent's.
    // Without this, property setters (like window.text = ...) would try to use the
    // parent context's allocator, causing memory corruption.
    v8.ffi.v8_Context_Enter(iframe_v8_ctx);
    defer v8.ffi.v8_Context_Exit(iframe_v8_ctx);

    // Get the existing document from the Window that was created during createChildContext.
    // We MUST pass this to parseHTMLWithScripting so the DOM tree is built into THIS document.
    // Otherwise, scripts will access window.document (the existing document) but the DOM tree
    // will be in a separate new document, causing document.body etc. to return null.
    const existing_document = if (iframe_content_window) |window|
        WindowImpl.get_document(window) catch null
    else
        null;

    // Parse HTML with scripting enabled (the dummy-iframe.html has a <script> tag)
    const HTMLParser = impls.HTMLParser;
    const iframe_document = HTMLParser.parseHTMLWithScripting(
        allocator,
        iframe_runtime_ctx,
        content,
        .{
            .scripting_enabled = true,
            .base_url = resolved_path,
            .script_loader = null, // Use default HTTP loader
            .existing_document = existing_document, // Use the Window's document
        },
    ) catch |err| {
        std.debug.print("iframeSrcLoadHook: Failed to parse HTML: {}\n", .{err});
        return false;
    };

    // Set the document in the browsing context
    if (iframe_internal.integration.browsing_context) |browsing_ctx| {
        // Set up the document in the iframe's window
        if (iframe_content_window) |window| {
            WindowImpl.setDocument(window, iframe_document);
        }
        browsing_ctx.setActiveDocument(@ptrCast(iframe_document), @ptrCast(iframe_content_window));
    }

    // Fire 'load' event on the iframe element
    // Per HTML spec, the load event fires on the iframe element when navigation completes
    // Use call_constructor to properly initialize Event with type and internal state
    const event_type = runtime.DOMString.initInterned("load");
    const event_init = dictionaries.EventInit{
        .bubbles = false, // load event doesn't bubble
        .cancelable = false,
    };
    const event = interfaces.Event.call_constructor(runtime_ctx, event_type, webidl.Opt(dictionaries.EventInit).passed(event_init)) catch {
        std.debug.print("iframeSrcLoadHook: Failed to create event\n", .{});
        return true; // Still return true - document was loaded
    };
    defer interfaces.Event.deinit(event); // Always free the event after use

    _ = interfaces.EventTarget.call_dispatchEvent(iframe_instance, event) catch {
        std.debug.print("iframeSrcLoadHook: Failed to dispatch event\n", .{});
        return true;
    };

    return true;
}

/// Load an iframe document from the WPT file system
/// This handles:
/// 1. Resolving the src URL relative to the test directory
/// 2. Reading .headers files for charset information
/// 3. Parsing HTML with the correct encoding
/// 4. Storing the document in the iframe's browsing context
///
/// @param self The browser context
/// @param iframe_element The HTMLIFrameElement instance
/// @param src The src attribute value (relative URL)
/// @param test_dir The directory containing the test file
/// @return void on success, error on failure
pub fn loadIframeDocument(
    self: *BrowserContext,
    iframe_element: *runtime.Instance,
    src: []const u8,
    test_dir: []const u8,
) !void {
    if (src.len == 0) return;

    // 1. Resolve src URL relative to test directory
    const iframe_path = try std.fs.path.join(self.allocator, &.{ self.wpt_root, test_dir, src });
    defer self.allocator.free(iframe_path);

    // 2. Check for .headers file for charset
    const charset = readHeadersFileCharset(self.allocator, iframe_path);
    _ = charset; // TODO: Use charset when parsing

    // 3. Read iframe content
    const iframe_file = std.fs.cwd().openFile(iframe_path, .{}) catch |err| {
        std.debug.print("Failed to open iframe file {s}: {}\n", .{ iframe_path, err });
        return error.FileNotFound;
    };
    defer iframe_file.close();

    const iframe_content = iframe_file.readToEndAlloc(self.allocator, 10 * 1024 * 1024) catch |err| {
        std.debug.print("Failed to read iframe file: {}\n", .{err});
        return error.ReadError;
    };
    defer self.allocator.free(iframe_content);

    // 4. Get runtime context
    const runtime_ctx = context_manager.getOrCreate(self.context.?, self.allocator) catch |err| {
        std.debug.print("Failed to get runtime context: {}\n", .{err});
        return error.RuntimeError;
    };

    // 5. Parse HTML (with scripting disabled for data files)
    const HTMLParser = impls.HTMLParser;
    const iframe_document = HTMLParser.parseHTMLWithScripting(
        self.allocator,
        runtime_ctx,
        iframe_content,
        .{
            .scripting_enabled = false, // Data files typically don't need scripts
            .base_url = iframe_path,
            .script_loader = null,
        },
    ) catch |err| {
        std.debug.print("Failed to parse iframe HTML: {}\n", .{err});
        return error.ParseError;
    };

    // 6. Get iframe's internal state and set the document in its browsing context
    const HTMLIFrameElementImpl = impls.HTMLIFrameElement;
    const iframe_internal = HTMLIFrameElementImpl.getInternal(iframe_element) orelse {
        std.debug.print("Failed to get iframe internal state\n", .{});
        interfaces.Document.deinit(iframe_document);
        return error.InvalidState;
    };

    if (iframe_internal.integration.browsing_context) |browsing_ctx| {
        // Create a window for the iframe document (simplified - just use document as window for now)
        // TODO: Properly create Window instance
        browsing_ctx.setActiveDocument(@ptrCast(iframe_document), @ptrCast(iframe_document));
    } else {
        std.debug.print("Iframe has no browsing context\n", .{});
        interfaces.Document.deinit(iframe_document);
        return error.NoBrowsingContext;
    }

    // 7. Fire 'load' event on iframe element using call_constructor for proper initialization
    const event_type = runtime.DOMString.initInterned("load");
    const event_init = dictionaries.EventInit{
        .bubbles = false, // load event doesn't bubble
        .cancelable = false,
    };
    const event = interfaces.Event.call_constructor(runtime_ctx, event_type, webidl.Opt(dictionaries.EventInit).passed(event_init)) catch return error.OutOfMemory;
    errdefer interfaces.Event.deinit(event);

    _ = interfaces.EventTarget.call_dispatchEvent(iframe_element, event) catch return error.DispatchError;
}

// ============================================================================
// V8CallbackContext - Consolidated Thread-Local State
// ============================================================================
//
// V8 callbacks are C functions that can't easily capture context,
// so we use thread-local storage to pass state to callbacks.
//
// This struct consolidates all thread-local state for better organization
// and to prevent forgetting to set/clear individual fields.

/// Consolidated context for V8 callbacks in WPT tests.
///
/// This struct groups all thread-local state needed by V8 callbacks.
/// Use `enter()` and `leave()` for scope-based management, or access
/// individual fields through the accessor functions below.
///
/// ## Usage
/// ```zig
/// var ctx = V8CallbackContext.init(allocator);
/// defer ctx.deinit();
///
/// ctx.result_collector = &collector;
/// ctx.timer_interface = timer;
/// ctx.wpt_root = wpt_root;
/// ctx.test_path = test_path;
///
/// ctx.enter();
/// defer ctx.leave();
///
/// // V8 callbacks can now access the context via V8CallbackContext.get()
/// ```
pub const V8CallbackContext = struct {
    /// Result collector for test assertions
    result_collector: ?*test_harness.ResultCollector = null,
    /// Timer interface for setTimeout/setInterval
    timer_interface: ?TimerInterface = null,
    /// Allocator for timer callback contexts
    allocator: ?std.mem.Allocator = null,
    /// WPT root directory for URL resolution
    wpt_root: ?[]const u8 = null,
    /// Current test path for URL resolution
    test_path: ?[]const u8 = null,
    /// Base URL for Worker constructor
    base_url: ?[]const u8 = null,
    /// Timer contexts for cleanup tracking (stores SelfContainedCallback wrappers)
    timer_contexts: std.AutoHashMap(TimerId, *V8TimerCallback),
    /// Whether this context is currently active
    is_active: bool = false,

    /// Thread-local pointer to current context
    threadlocal var current: ?*V8CallbackContext = null;

    /// Initialize a new callback context.
    ///
    /// The allocator is used for the timer_contexts map and must remain valid
    /// for the lifetime of the context.
    pub fn init(alloc: std.mem.Allocator) V8CallbackContext {
        return .{
            .timer_contexts = std.AutoHashMap(TimerId, *V8TimerCallback).init(alloc),
            .allocator = alloc,
        };
    }

    /// Enter this context (make it current).
    ///
    /// Asserts that no other context is active to catch nesting bugs.
    /// Use with defer: `ctx.enter(); defer ctx.leave();`
    pub fn enter(self: *V8CallbackContext) void {
        std.debug.assert(current == null); // Prevent nesting bugs
        current = self;
        self.is_active = true;

        // Also set individual thread-locals for backward compatibility
        current_result_collector = self.result_collector;
        current_timer_interface = self.timer_interface;
        current_allocator = self.allocator;
        current_wpt_root = self.wpt_root;
        current_test_path = self.test_path;
        current_base_url = self.base_url;
        timer_contexts = self.timer_contexts;
    }

    /// Leave this context (clear current).
    ///
    /// Asserts that this is the active context.
    pub fn leave(self: *V8CallbackContext) void {
        std.debug.assert(current == self);

        // Sync timer_contexts back (it may have been modified)
        self.timer_contexts = timer_contexts orelse self.timer_contexts;

        current = null;
        self.is_active = false;

        // Clear individual thread-locals
        current_result_collector = null;
        current_timer_interface = null;
        current_allocator = null;
        current_wpt_root = null;
        current_test_path = null;
        current_base_url = null;
        timer_contexts = null;
    }

    /// Get the current active context, if any.
    pub fn get() ?*V8CallbackContext {
        return current;
    }

    /// Clean up resources (timer contexts map and pending timers).
    pub fn deinit(self: *V8CallbackContext) void {
        // Clean up any remaining timer contexts
        var iter = self.timer_contexts.iterator();
        while (iter.next()) |entry| {
            const ctx = entry.value_ptr.*;
            // Cancel the timer if we have a timer interface
            if (self.timer_interface) |timer| {
                timer.clearTimeout(ctx.current_timer_id);
            }
            ctx.destroy();
        }
        self.timer_contexts.deinit();
    }
};

// ============================================================================
// Legacy Thread-Local Variables (for backward compatibility)
// ============================================================================
// These are kept for compatibility with existing code that accesses them directly.
// New code should use V8CallbackContext instead.

threadlocal var current_result_collector: ?*test_harness.ResultCollector = null;
threadlocal var current_timer_interface: ?TimerInterface = null;
threadlocal var current_allocator: ?std.mem.Allocator = null;
threadlocal var current_wpt_root: ?[]const u8 = null;
threadlocal var current_test_path: ?[]const u8 = null;
threadlocal var current_base_url: ?[]const u8 = null;

/// Set the WPT root for fetch callback URL resolution
pub fn setWptRoot(wpt_root: []const u8) void {
    current_wpt_root = wpt_root;
}

/// Set the current test path for fetch callback URL resolution
pub fn setCurrentTestPath(test_path: []const u8) void {
    current_test_path = test_path;
}

/// Get the WPT root (for V8 callbacks)
pub fn getWptRoot() ?[]const u8 {
    return current_wpt_root;
}

/// Get the current test path (for V8 callbacks)
pub fn getCurrentTestPath() ?[]const u8 {
    return current_test_path;
}

/// Set the current base URL for relative URL resolution (e.g., Worker constructor)
pub fn setCurrentBaseUrl(base_url: []const u8) void {
    current_base_url = base_url;

    // Also set the document origin in html_core's workers module
    // This is needed for Worker constructor to resolve relative script URLs
    // Extract origin from URL (scheme://host:port)
    if (std.mem.startsWith(u8, base_url, "http://") or std.mem.startsWith(u8, base_url, "https://")) {
        // Find the end of the origin (after scheme://host:port, before path)
        const scheme_end = std.mem.indexOf(u8, base_url, "://") orelse return;
        const after_scheme = base_url[scheme_end + 3 ..];
        const path_start = std.mem.indexOf(u8, after_scheme, "/") orelse after_scheme.len;
        const origin = base_url[0 .. scheme_end + 3 + path_start];
        html_full.workers.setDocumentOrigin(origin);
    }
}

/// Get the current base URL (for Worker constructor)
pub fn getCurrentBaseUrl() ?[]const u8 {
    return current_base_url;
}

// Thread-local storage for ALL timer contexts (for cleanup on clearTimeout/clearInterval and deinit)
// Maps timer_id -> V8TimerCallback* (SelfContainedCallback wrapper) for cleanup tracking
threadlocal var timer_contexts: ?std.AutoHashMap(TimerId, *V8TimerCallback) = null;

// ============================================================================
// Event Listener Storage (for dispatchEvent)
// ============================================================================

/// Event listener entry - stores either a function or an object with handleEvent
/// NOTE: This is a simplified implementation for WPT tests that run synchronously.
/// The listener_value is a raw pointer that's only valid during the script execution.
/// For production use, this would need proper persistent handle management.
const EventListenerEntry = struct {
    /// Event type (e.g., "testevent", "load")
    event_type: []const u8,
    /// The listener value (function or object with handleEvent method)
    /// Raw V8 Value pointer - only valid during same script execution
    listener_value: ?*v8.ffi.Value,
    /// Capture phase flag
    capture: bool,
    /// Once flag (auto-remove after first invocation)
    once: bool,

    /// Check if this listener matches the given criteria for removal
    fn matches(self: *const EventListenerEntry, event_type: []const u8, listener_ptr: *v8.ffi.Value, capture: bool) bool {
        if (!std.mem.eql(u8, self.event_type, event_type)) return false;
        if (self.capture != capture) return false;
        // Compare the stored value pointer with the provided one
        if (self.listener_value) |stored| {
            return v8.ffi.v8_Value_StrictEquals(stored, listener_ptr);
        }
        return false;
    }

    fn deinit(self: *EventListenerEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.event_type);
        // Note: We don't own the V8 value, just storing the pointer
    }
};

/// Thread-local storage for event listeners on the global object
threadlocal var global_event_listeners: ?std.ArrayList(EventListenerEntry) = null;

/// Initialize event listener storage
fn initEventListenerStorage(allocator: std.mem.Allocator) void {
    _ = allocator;
    if (global_event_listeners == null) {
        // Zig 0.15: ArrayList is unmanaged - no allocator in init
        global_event_listeners = .{};
    }
}

/// Clear all event listeners (called on context cleanup)
fn clearEventListeners(allocator: std.mem.Allocator) void {
    if (global_event_listeners) |*listeners| {
        for (listeners.items) |*entry| {
            entry.deinit(allocator);
        }
        // Zig 0.15: deinit takes allocator
        listeners.deinit(allocator);
        global_event_listeners = null;
    }
}

/// Set the current result collector for V8 callbacks
pub fn setResultCollector(collector: *test_harness.ResultCollector) void {
    current_result_collector = collector;
}

/// Get the current result collector (for V8 callbacks)
pub fn getResultCollector() ?*test_harness.ResultCollector {
    return current_result_collector;
}

/// Clear the result collector reference
pub fn clearResultCollector() void {
    current_result_collector = null;
}

/// Set the current timer interface for V8 callbacks
pub fn setTimerInterface(timer: TimerInterface, allocator: std.mem.Allocator) void {
    current_timer_interface = timer;
    current_allocator = allocator;
    // Initialize timer contexts map if needed
    if (timer_contexts == null) {
        timer_contexts = std.AutoHashMap(TimerId, *V8TimerCallback).init(allocator);
    }
}

/// Get the current timer interface (for V8 callbacks)
pub fn getTimerInterface() ?TimerInterface {
    return current_timer_interface;
}

/// Clear the timer interface reference and clean up ALL pending timer contexts
/// This properly cancels libuv timers to prevent handle accumulation
pub fn clearTimerInterface() void {
    // Clean up any remaining timer contexts (both one-shot and intervals)
    if (timer_contexts) |*map| {
        var iter = map.iterator();
        while (iter.next()) |entry| {
            const wrapper = entry.value_ptr.*;
            // Cancel the timer at the libuv level to prevent callback from firing
            // and to properly clean up the libuv timer handle
            if (current_timer_interface) |timer| {
                timer.clearTimeout(wrapper.getData().current_timer_id);
            }
            wrapper.destroy();
        }
        map.deinit();
        timer_contexts = null;
    }

    // Clean up event listeners
    if (current_allocator) |allocator| {
        clearEventListeners(allocator);
    }

    current_timer_interface = null;
    current_allocator = null;
}

/// Clear ALL pending timer contexts but keep the timer interface
/// This is used during test isolation to cancel timers without tearing down the interface
pub fn clearPendingTimers() void {
    if (timer_contexts) |*map| {
        var iter = map.iterator();
        while (iter.next()) |entry| {
            const wrapper = entry.value_ptr.*;
            // Cancel the timer at the libuv level
            if (current_timer_interface) |timer| {
                timer.clearTimeout(wrapper.getData().current_timer_id);
            }
            // Destroy the timer wrapper
            wrapper.destroy();
        }
        map.clearRetainingCapacity();
    }

    // Also clear event listeners between tests
    if (current_allocator) |allocator| {
        if (global_event_listeners) |*listeners| {
            for (listeners.items) |*entry| {
                entry.deinit(allocator);
            }
            listeners.clearRetainingCapacity();
        }
    }
}

/// Reset all V8/runtime state between tests for proper isolation
///
/// This function is CRITICAL for running multiple WPT tests sequentially.
/// Without proper cleanup, state from previous tests persists and causes:
/// - Use-after-free when V8 GC fires weak callbacks on freed entries
/// - Internal state registry contains stale entries from old tests
/// - Timer contexts reference callbacks from reloaded testharness.js
/// - Wrapper cache maps instances to old V8 objects
///
/// ## Cleanup Order (IMPORTANT)
/// 1. Force V8 GC first - triggers weak callbacks while references are valid
/// 2. Clear pending timers - cancel callbacks that may reference stale state
/// 3. Clear wrapper caches - removes V8→Zig mappings (two-phase cleanup)
/// 4. Reset internal state registry - removes Zig instance→state mappings
/// 5. Force V8 GC again - collect any newly-orphaned objects
///
/// ## Usage
/// Call this between test executions in the WPT runner:
/// ```zig
/// for (test_files) |test_file| {
///     try ctx.resetBetweenTests();  // Clean slate
///     const result = try ctx.executeTest(test_file, ...);
/// }
/// ```
///
/// ## Thread Safety
/// All cleared state is thread-local (V8 isolates are single-threaded).
pub fn resetBetweenTests(isolate: ?*v8.ffi.Isolate) void {
    // Step 1: Force V8 GC first while references are still valid
    // This triggers weak callbacks which safely clean up entries
    if (isolate) |iso| {
        v8.ffi.v8_Isolate_RequestGarbageCollection(iso);
    }

    // Step 2: Clear pending timers
    // These may hold references to V8 functions from the previous test's testharness.js
    clearPendingTimers();

    // Step 3: Clear wrapper caches across all contexts
    // Uses two-phase cleanup: first disables weak callbacks, then cleans entries
    // This prevents use-after-free from weak callbacks firing during cleanup
    context_manager.clearWrapperCaches();

    // Step 4: Reset internal state registry
    // Removes all instance→InternalState mappings from previous test
    runtime.resetInternalStateRegistry();

    // Step 5: Force V8 GC again to collect newly-orphaned objects
    // The wrapper cache clear may have orphaned V8 objects
    if (isolate) |iso| {
        v8.ffi.v8_Isolate_RequestGarbageCollection(iso);
    }
}

/// Register a timer context for cleanup tracking (both one-shot and intervals)
fn registerTimerContext(timer_id: TimerId, wrapper: *V8TimerCallback) void {
    if (timer_contexts) |*map| {
        map.put(timer_id, wrapper) catch |err| {
            // If we can't track the timer, we must destroy it to prevent leaks
            std.debug.print("Warning: Failed to register timer context {}: {}\n", .{ timer_id, err });
            wrapper.destroy();
        };
    } else {
        // timer_contexts is null - this shouldn't happen if setTimerInterface was called
        // Destroy the context to prevent memory leak
        std.debug.print("Warning: timer_contexts is null, destroying untracked timer {}\n", .{timer_id});
        wrapper.destroy();
    }
}

/// Unregister a timer context (cancels and destroys it)
fn unregisterTimerContext(timer_id: TimerId) void {
    if (timer_contexts) |*map| {
        if (map.fetchRemove(timer_id)) |kv| {
            const wrapper = kv.value;
            // Mark as cancelled so interval callbacks know to stop rescheduling
            wrapper.getData().cancelled = true;
            // Cancel the timer at the libuv level to prevent callback from firing
            if (current_timer_interface) |timer| {
                timer.clearTimeout(timer_id);
            }
            // Destroy the wrapper immediately - the timer won't fire anymore
            wrapper.destroy();
        }
    }
}

// V8 Callback Functions
//
// NOTE ON V8 FFI @ptrCast USAGE:
// The @ptrCast calls in this file are legitimate C FFI boundary casts.
// V8's C API uses generic Value* pointers for all JavaScript values, so we must
// cast between specific types (String*, Function*, Integer*, Object*) and Value*.
// These casts cannot be avoided without changing the V8 FFI layer itself.
// See docs/legitimate-anyopaque.md for more details on FFI boundary patterns.

/// V8 Timer Context Data
///
/// Holds the V8 function reference and metadata for timer/interval callbacks.
/// This works for short-lived WPT tests but could cause issues if V8 GCs
/// the function before the timer fires. For production use, the V8 FFI
/// would need to expose v8::Global<v8::Function> creation.
///
/// NOTE: This stores raw V8 function pointers without proper persistent handles.
/// The V8 FFI doesn't currently support Persistent/Global handle creation.
const V8TimerContextData = struct {
    /// Raw pointer to the V8 function (not GC-protected!)
    callback_fn: *v8.ffi.Function,
    /// V8 isolate
    isolate: *v8.ffi.Isolate,
    /// Whether this is an interval (repeating) timer - affects cleanup
    is_interval: bool,
    /// For intervals: the delay in ms for rescheduling
    interval_delay_ms: u64 = 0,
    /// For intervals: the current timer ID (updated on each reschedule)
    current_timer_id: TimerId = 0,
    /// For intervals: whether the interval has been cancelled
    cancelled: bool = false,
};

/// Type-safe timer callback wrapper for V8 timer contexts.
///
/// Uses SelfContainedWorkCallback to bundle the callback function and context data
/// together, providing compile-time type safety and eliminating manual
/// anyopaque casts in callback functions. The work callback variant stores
/// the allocator internally for no-argument destroy().
///
/// PATTERN: This demonstrates the typed callback pattern recommended for
/// anyopaque refactoring. The SelfContainedWorkCallback provides:
/// - Type-safe context data (V8TimerContextData)
/// - Automatic memory management (allocator stored internally)
/// - A trampoline callback that handles the anyopaque->typed conversion at the FFI boundary
const V8TimerCallback = SelfContainedWorkCallback(V8TimerContextData);

/// Create a new V8 timer context wrapper
fn createV8TimerContext(allocator: std.mem.Allocator, isolate: *v8.ffi.Isolate, callback_value: *v8.ffi.Value, is_interval: bool) !*V8TimerCallback {
    // Verify it's a function
    if (!v8.ffi.v8_Value_IsFunction(callback_value)) {
        return error.NotAFunction;
    }

    const callback_fn = if (is_interval) &v8IntervalHandler else &v8TimerHandler;
    return try V8TimerCallback.create(
        allocator,
        callback_fn,
        .{
            .callback_fn = @ptrCast(callback_value),
            .isolate = isolate,
            .is_interval = is_interval,
        },
    );
}

/// Handler function for one-shot timer callbacks (invoked via SelfContainedCallback trampoline)
fn v8TimerHandler(data: *V8TimerContextData) void {
    // Unregister from timer_contexts map before destroying (prevents double-free on deinit)
    if (timer_contexts) |*map| {
        _ = map.remove(data.current_timer_id);
    }

    const isolate = data.isolate;
    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    const global = v8.ffi.v8_Context_Global(context) orelse return;

    // Invoke the V8 function (stored directly, not via persistent handle)
    var empty_args: [1]*v8.ffi.Value = undefined;
    _ = v8.ffi.v8_Function_Call(data.callback_fn, context, @ptrCast(global), 0, &empty_args);

    // Run microtasks after the timer callback (per event loop semantics)
    v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);

    // Destroy the wrapper - this is a one-shot timer, so clean up after execution
    // Get the wrapper pointer from the data pointer (data is embedded in SelfContainedCallback)
    const wrapper: *V8TimerCallback = @fieldParentPtr("data", data);
    wrapper.destroy();
}

/// Handler function for interval callbacks (invoked via SelfContainedCallback trampoline)
fn v8IntervalHandler(data: *V8TimerContextData) void {
    // Check if interval was cancelled
    if (data.cancelled) {
        if (timer_contexts) |*map| {
            _ = map.remove(data.current_timer_id);
        }
        // Note: The SelfContainedCallback wrapper is destroyed after this returns
        // via invokeAndDestroy() in the trampoline
        return;
    }

    const isolate = data.isolate;
    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    const global = v8.ffi.v8_Context_Global(context) orelse return;

    // Invoke the V8 function
    var empty_args: [1]*v8.ffi.Value = undefined;
    _ = v8.ffi.v8_Function_Call(data.callback_fn, context, @ptrCast(global), 0, &empty_args);

    // Run microtasks after the timer callback
    v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);

    // Reschedule the interval if not cancelled
    if (!data.cancelled) {
        if (getTimerInterface()) |timer| {
            // Get the wrapper pointer from the data pointer
            // The data is embedded in the SelfContainedCallback, so we can calculate the wrapper address
            const wrapper: *V8TimerCallback = @fieldParentPtr("data", data);

            const new_timer_id = timer.setTimeout(
                data.interval_delay_ms,
                V8TimerCallback.getTrampolineCallback(),
                wrapper.eraseForFFI(),
            );
            if (new_timer_id != 0) {
                // Update the timer ID for potential clearInterval calls
                const old_id = data.current_timer_id;
                data.current_timer_id = new_timer_id;
                // Update the timer context map with new ID
                if (timer_contexts) |*map| {
                    _ = map.remove(old_id);
                    map.put(new_timer_id, wrapper) catch {};
                }
            } else {
                // Failed to reschedule, clean up
                if (timer_contexts) |*map| {
                    _ = map.remove(data.current_timer_id);
                }
                wrapper.destroy();
            }
        } else {
            // No timer interface, clean up
            if (timer_contexts) |*map| {
                _ = map.remove(data.current_timer_id);
            }
            const wrapper: *V8TimerCallback = @fieldParentPtr("data", data);
            wrapper.destroy();
        }
    } else {
        // Cancelled, clean up
        if (timer_contexts) |*map| {
            _ = map.remove(data.current_timer_id);
        }
        const wrapper: *V8TimerCallback = @fieldParentPtr("data", data);
        wrapper.destroy();
    }
}

// NOTE: The old v8TimerCallback and v8IntervalCallback functions have been replaced by
// typed handlers v8TimerHandler and v8IntervalHandler above, which are invoked via the
// SelfContainedCallback trampoline pattern for type safety.

/// setTimeout callback - schedules callback to run after delay using TimerManager
fn setTimeoutCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();

    // Get the callback function (first argument)
    if (info.v8_FunctionCallbackInfo_Length() < 1) {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    }

    const callback_value = info.get(0);
    if (!v8.ffi.v8_Value_IsFunction(callback_value)) {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    }

    // Get delay (second argument, default 0)
    var delay_ms: i64 = 0;
    if (info.v8_FunctionCallbackInfo_Length() >= 2) {
        const delay_value = info.get(1);
        if (v8.ffi.v8_Value_IsNumber(delay_value)) {
            const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
                const result = v8.ffi.v8_Integer_New(isolate, 0);
                info.setReturnValue(@ptrCast(result));
                return;
            };
            const delay_f64 = v8.ffi.v8_Value_NumberValue(delay_value, context);
            // Safety check for NaN/Inf/negative values
            if (!std.math.isNan(delay_f64) and !std.math.isInf(delay_f64) and delay_f64 >= 0 and delay_f64 <= @as(f64, @floatFromInt(std.math.maxInt(i64)))) {
                delay_ms = @intFromFloat(delay_f64);
            }
        }
    }

    // Get timer interface from thread-local storage
    const timer = getTimerInterface() orelse {
        // Fallback: execute immediately if no timer interface
        const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
            const result = v8.ffi.v8_Integer_New(isolate, 0);
            info.setReturnValue(@ptrCast(result));
            return;
        };
        const callback_fn: *v8.ffi.Function = @ptrCast(callback_value);
        const global = v8.ffi.v8_Context_Global(context) orelse {
            const result = v8.ffi.v8_Integer_New(isolate, 0);
            info.setReturnValue(@ptrCast(result));
            return;
        };
        var empty_args: [1]*v8.ffi.Value = undefined;
        _ = v8.ffi.v8_Function_Call(callback_fn, context, @ptrCast(global), 0, &empty_args);
        const result = v8.ffi.v8_Integer_New(isolate, 1);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    const allocator = current_allocator orelse {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Create typed timer context wrapper (one-shot timer)
    const timer_wrapper = createV8TimerContext(allocator, isolate, callback_value, false) catch {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Schedule the timer using TimerInterface with typed callback trampoline
    const delay_u64: u64 = if (delay_ms >= 0) @intCast(delay_ms) else 0;
    const timer_id = timer.setTimeout(
        delay_u64,
        V8TimerCallback.getTrampolineCallback(),
        timer_wrapper.eraseForFFI(),
    );
    if (timer_id == 0) {
        timer_wrapper.destroy();
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    }

    // Store the timer ID in the context so the callback can unregister it
    timer_wrapper.getData().current_timer_id = timer_id;

    // Register the timer context for cleanup tracking (prevents memory leak on deinit)
    registerTimerContext(timer_id, timer_wrapper);

    // Return timer ID (truncate to i32 for V8 Integer)
    const result = v8.ffi.v8_Integer_New(isolate, @intCast(@as(u32, @truncate(timer_id))));
    info.setReturnValue(@ptrCast(result));
}

/// clearTimeout callback - cancels a pending timer
fn clearTimeoutCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();

    // Get timer ID (first argument)
    if (info.v8_FunctionCallbackInfo_Length() < 1) {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    }

    const id_value = info.get(0);
    if (!v8.ffi.v8_Value_IsNumber(id_value)) {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    }

    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    };

    const timer_id_f64 = v8.ffi.v8_Value_NumberValue(id_value, context);

    // Safety check: ensure the float is a valid positive integer that fits in TimerId
    if (std.math.isNan(timer_id_f64) or std.math.isInf(timer_id_f64) or
        timer_id_f64 < 0 or timer_id_f64 > @as(f64, @floatFromInt(std.math.maxInt(TimerId))))
    {
        // Invalid timer ID - just return without doing anything
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    }
    const timer_id: TimerId = @intFromFloat(timer_id_f64);

    // Get timer interface and cancel the timer
    if (getTimerInterface()) |timer| {
        timer.clearTimeout(timer_id);
    }

    // Clean up interval context if this was an interval timer
    // (clearTimeout and clearInterval use the same underlying mechanism)
    unregisterTimerContext(timer_id);

    if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
        info.setReturnValue(undef_value);
    }
}

/// setInterval callback - schedules repeating callback using TimerManager
fn setIntervalCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();

    // Get the callback function (first argument)
    if (info.v8_FunctionCallbackInfo_Length() < 1) {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    }

    const callback_value = info.get(0);
    if (!v8.ffi.v8_Value_IsFunction(callback_value)) {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    }

    // Get delay (second argument, default 0)
    var delay_ms: i64 = 0;
    if (info.v8_FunctionCallbackInfo_Length() >= 2) {
        const delay_value = info.get(1);
        if (v8.ffi.v8_Value_IsNumber(delay_value)) {
            const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
                const result = v8.ffi.v8_Integer_New(isolate, 0);
                info.setReturnValue(@ptrCast(result));
                return;
            };
            const delay_f64 = v8.ffi.v8_Value_NumberValue(delay_value, context);
            // Safety check for NaN/Inf/negative values
            if (!std.math.isNan(delay_f64) and !std.math.isInf(delay_f64) and delay_f64 >= 0 and delay_f64 <= @as(f64, @floatFromInt(std.math.maxInt(i64)))) {
                delay_ms = @intFromFloat(delay_f64);
            }
        }
    }

    // Get timer interface from thread-local storage
    const timer = getTimerInterface() orelse {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    const allocator = current_allocator orelse {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Create typed timer context wrapper (interval timer)
    const timer_wrapper = createV8TimerContext(allocator, isolate, callback_value, true) catch {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Store the interval delay in the context for re-scheduling
    const delay_u64: u64 = if (delay_ms >= 0) @intCast(delay_ms) else 0;
    timer_wrapper.getData().interval_delay_ms = delay_u64;

    // Schedule the first timeout (intervals reschedule themselves in v8IntervalHandler)
    const timer_id = timer.setTimeout(
        delay_u64,
        V8TimerCallback.getTrampolineCallback(),
        timer_wrapper.eraseForFFI(),
    );
    if (timer_id == 0) {
        timer_wrapper.destroy();
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    }

    // Store the timer ID in the context so it can be used for rescheduling
    timer_wrapper.getData().current_timer_id = timer_id;

    // Register the interval context for cleanup when clearInterval is called
    registerTimerContext(timer_id, timer_wrapper);

    // Return timer ID (truncate to i32 for V8 Integer)
    const result = v8.ffi.v8_Integer_New(isolate, @intCast(@as(u32, @truncate(timer_id))));
    info.setReturnValue(@ptrCast(result));
}

/// Mock addEventListener callback - stores event listeners for the global object
/// The WPT testharness.js calls window.addEventListener('load', callback) to register
/// callbacks that should fire when the document is loaded.
/// Per DOM spec, addEventListener(type, callback, options) stores the listener for later dispatch.
fn addEventListenerCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();

    // Need at least event type and callback
    if (info.v8_FunctionCallbackInfo_Length() < 2) {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    }

    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    };

    const allocator = current_allocator orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    };

    // Initialize storage if needed
    initEventListenerStorage(allocator);

    // Get event type (first argument)
    const type_value = info.get(0);
    const event_type = extractString(allocator, isolate, context, type_value) catch {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    };
    // event_type ownership transferred to EventListenerEntry

    // Get callback (second argument) - can be function or object with handleEvent
    const callback_value = info.get(1);
    if (v8.ffi.v8_Value_IsNull(callback_value) or v8.ffi.v8_Value_IsUndefined(callback_value)) {
        allocator.free(event_type);
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    }

    // Parse options (third argument) - can be boolean (capture) or object
    var capture = false;
    var once = false;
    if (info.v8_FunctionCallbackInfo_Length() >= 3) {
        const options_value = info.get(2);
        if (v8.ffi.v8_Value_IsBoolean(options_value)) {
            capture = v8.ffi.v8_Value_BooleanValue(options_value, isolate);
        } else if (v8.ffi.v8_Value_IsObject(options_value)) {
            const options_obj: *v8.ffi.Object = @ptrCast(options_value);
            const capture_key = v8.ffi.v8_String_NewFromUtf8(isolate, "capture", 7);
            const once_key = v8.ffi.v8_String_NewFromUtf8(isolate, "once", 4);
            if (capture_key) |ck| {
                if (v8.ffi.v8_Object_Get(options_obj, context, @ptrCast(ck))) |cap_val| {
                    if (v8.ffi.v8_Value_IsBoolean(cap_val)) {
                        capture = v8.ffi.v8_Value_BooleanValue(cap_val, isolate);
                    }
                }
            }
            if (once_key) |ok| {
                if (v8.ffi.v8_Object_Get(options_obj, context, @ptrCast(ok))) |once_val| {
                    if (v8.ffi.v8_Value_IsBoolean(once_val)) {
                        once = v8.ffi.v8_Value_BooleanValue(once_val, isolate);
                    }
                }
            }
        }
    }

    // Check if this exact listener already exists (per spec: duplicates are ignored)
    if (global_event_listeners) |*listeners| {
        for (listeners.items) |*entry| {
            if (entry.matches(event_type, callback_value, capture)) {
                // Duplicate - free resources and return
                allocator.free(event_type);
                if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
                    info.setReturnValue(undef_value);
                }
                return;
            }
        }

        // Add new listener
        // NOTE: We store the raw pointer - this is safe for synchronous WPT tests
        // but would need persistent handles for production use with async/GC
        // Zig 0.15: append takes allocator
        listeners.append(allocator, .{
            .event_type = event_type,
            .listener_value = callback_value,
            .capture = capture,
            .once = once,
        }) catch {
            allocator.free(event_type);
        };
    }

    if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
        info.setReturnValue(undef_value);
    }
}

/// removeEventListener callback - removes event listeners from the global object
/// Per DOM spec, removeEventListener(type, callback, options) removes a matching listener.
fn removeEventListenerCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();

    // Need at least event type and callback
    if (info.v8_FunctionCallbackInfo_Length() < 2) {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    }

    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    };

    const allocator = current_allocator orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    };

    // Get event type (first argument)
    const type_value = info.get(0);
    const event_type = extractString(allocator, isolate, context, type_value) catch {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    };
    defer allocator.free(event_type);

    // Get callback (second argument)
    const callback_value = info.get(1);
    if (v8.ffi.v8_Value_IsNull(callback_value) or v8.ffi.v8_Value_IsUndefined(callback_value)) {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    }

    // Parse options (third argument) - can be boolean (capture) or object
    var capture = false;
    if (info.v8_FunctionCallbackInfo_Length() >= 3) {
        const options_value = info.get(2);
        if (v8.ffi.v8_Value_IsBoolean(options_value)) {
            capture = v8.ffi.v8_Value_BooleanValue(options_value, isolate);
        } else if (v8.ffi.v8_Value_IsObject(options_value)) {
            const options_obj: *v8.ffi.Object = @ptrCast(options_value);
            const capture_key = v8.ffi.v8_String_NewFromUtf8(isolate, "capture", 7);
            if (capture_key) |ck| {
                if (v8.ffi.v8_Object_Get(options_obj, context, @ptrCast(ck))) |cap_val| {
                    if (v8.ffi.v8_Value_IsBoolean(cap_val)) {
                        capture = v8.ffi.v8_Value_BooleanValue(cap_val, isolate);
                    }
                }
            }
        }
    }

    // Find and remove the listener
    if (global_event_listeners) |*listeners| {
        var i: usize = 0;
        while (i < listeners.items.len) {
            if (listeners.items[i].matches(event_type, callback_value, capture)) {
                var entry = listeners.orderedRemove(i);
                entry.deinit(allocator);
                // Don't increment i, as we removed the item
            } else {
                i += 1;
            }
        }
    }

    if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
        info.setReturnValue(undef_value);
    }
}

/// dispatchEvent callback - dispatches event to registered listeners
/// Per DOM spec, dispatchEvent(event) invokes matching event listeners.
/// Uses direct V8 function calls to avoid CallbackWrapper issues with Global handles.
fn dispatchEventCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();

    // Need event argument
    if (info.v8_FunctionCallbackInfo_Length() < 1) {
        // Per spec: throw TypeError if no argument
        const msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Failed to execute 'dispatchEvent': 1 argument required", 55);
        if (msg) |m| {
            if (v8.ffi.v8_Exception_TypeError(m)) |exc| {
                v8.ffi.v8_Isolate_ThrowException(isolate, exc);
            }
        }
        return;
    }

    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        if (v8.ffi.v8_Boolean_New(isolate, true)) |result| {
            info.setReturnValue(result);
        }
        return;
    };

    const allocator = current_allocator orelse {
        if (v8.ffi.v8_Boolean_New(isolate, true)) |result| {
            info.setReturnValue(result);
        }
        return;
    };

    // Get event argument
    const event_value = info.get(0);
    if (v8.ffi.v8_Value_IsNull(event_value) or v8.ffi.v8_Value_IsUndefined(event_value)) {
        // Per spec: throw TypeError if event is null/undefined
        const msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Failed to execute 'dispatchEvent': parameter 1 is not of type 'Event'", 69);
        if (msg) |m| {
            if (v8.ffi.v8_Exception_TypeError(m)) |exc| {
                v8.ffi.v8_Isolate_ThrowException(isolate, exc);
            }
        }
        return;
    }

    // Get event type from the event object
    const event_obj: *v8.ffi.Object = @ptrCast(event_value);
    const type_key = v8.ffi.v8_String_NewFromUtf8(isolate, "type", 4) orelse {
        if (v8.ffi.v8_Boolean_New(isolate, true)) |result| {
            info.setReturnValue(result);
        }
        return;
    };
    const type_value = v8.ffi.v8_Object_Get(event_obj, context, @ptrCast(type_key)) orelse {
        if (v8.ffi.v8_Boolean_New(isolate, true)) |result| {
            info.setReturnValue(result);
        }
        return;
    };
    const event_type = extractString(allocator, isolate, context, type_value) catch {
        if (v8.ffi.v8_Boolean_New(isolate, true)) |result| {
            info.setReturnValue(result);
        }
        return;
    };
    defer allocator.free(event_type);

    // Get global object for 'this' in callback invocations
    const global = v8.ffi.v8_Context_Global(context) orelse {
        if (v8.ffi.v8_Boolean_New(isolate, true)) |result| {
            info.setReturnValue(result);
        }
        return;
    };

    // Track listeners to remove (for once:true)
    var to_remove: std.ArrayList(usize) = .{};
    defer to_remove.deinit(allocator);

    // Invoke matching listeners
    if (global_event_listeners) |*listeners| {
        for (listeners.items, 0..) |*entry, idx| {
            if (std.mem.eql(u8, entry.event_type, event_type)) {
                // Get the listener value from stored pointer
                if (entry.listener_value) |listener_value| {
                    // Prepare argument array with event
                    var args: [1]*v8.ffi.Value = .{event_value};

                    if (v8.ffi.v8_Value_IsFunction(listener_value)) {
                        // Listener is a function - call it directly
                        const listener_fn: *v8.ffi.Function = @ptrCast(listener_value);
                        _ = v8.ffi.v8_Function_Call(listener_fn, context, @ptrCast(global), 1, &args);
                    } else if (v8.ffi.v8_Value_IsObject(listener_value)) {
                        // Listener is an object - call handleEvent method (per EventListener callback interface)
                        const listener_obj: *v8.ffi.Object = @ptrCast(listener_value);
                        const handleEvent_key = v8.ffi.v8_String_NewFromUtf8(isolate, "handleEvent", 11);
                        if (handleEvent_key) |hk| {
                            if (v8.ffi.v8_Object_Get(listener_obj, context, @ptrCast(hk))) |handleEvent_value| {
                                if (v8.ffi.v8_Value_IsFunction(handleEvent_value)) {
                                    // Call handleEvent with listener object as 'this'
                                    const handleEvent_fn: *v8.ffi.Function = @ptrCast(handleEvent_value);
                                    _ = v8.ffi.v8_Function_Call(handleEvent_fn, context, listener_value, 1, &args);
                                }
                            }
                        }
                    }

                    // Track for removal if once:true
                    if (entry.once) {
                        to_remove.append(allocator, idx) catch {};
                    }
                }
            }
        }

        // Remove once listeners (in reverse order to maintain indices)
        var i = to_remove.items.len;
        while (i > 0) {
            i -= 1;
            const idx = to_remove.items[i];
            var removed = listeners.orderedRemove(idx);
            removed.deinit(allocator);
        }
    }

    // Run microtasks after event dispatch (per event loop semantics)
    v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);

    // Return true (event not cancelled) - we don't track cancellation for now
    if (v8.ffi.v8_Boolean_New(isolate, true)) |result| {
        info.setReturnValue(result);
    }
}

// ============================================================================
// Worker-Specific Callbacks
// ============================================================================

/// importScripts() callback - loads and executes scripts synchronously from WPT file system
/// Per Web Workers spec, importScripts(urls...) loads and executes one or more scripts.
/// For WPT tests, this loads scripts from the WPT file system.
fn importScriptsCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    };

    const arg_count = info.v8_FunctionCallbackInfo_Length();
    if (arg_count == 0) {
        // importScripts() with no args is a no-op
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    }

    // Use a temporary allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Get WPT root and test path for URL resolution
    const wpt_root = getWptRoot() orelse {
        const msg = v8.ffi.v8_String_NewFromUtf8(isolate, "importScripts: No WPT root set", 30) orelse return;
        if (v8.ffi.v8_Exception_Error(msg)) |exc| {
            v8.ffi.v8_Isolate_ThrowException(isolate, exc);
        }
        return;
    };

    const test_path = getCurrentTestPath();
    const test_dir = if (test_path) |tp|
        if (std.mem.lastIndexOf(u8, tp, "/")) |pos| tp[0..pos] else ""
    else
        "";

    // Process each URL argument
    var i: c_int = 0;
    while (i < arg_count) : (i += 1) {
        const url_value = info.get(i);

        // Extract URL string
        const url_str = extractString(allocator, isolate, v8_context, url_value) catch {
            const msg = v8.ffi.v8_String_NewFromUtf8(isolate, "importScripts: Failed to convert URL", 37) orelse return;
            if (v8.ffi.v8_Exception_TypeError(msg)) |exc| {
                v8.ffi.v8_Isolate_ThrowException(isolate, exc);
            }
            return;
        };
        defer allocator.free(url_str);

        // Resolve URL to file path
        var full_path: []u8 = undefined;
        if (std.mem.startsWith(u8, url_str, "/")) {
            // Absolute path from WPT root
            full_path = std.fs.path.join(allocator, &.{ wpt_root, url_str[1..] }) catch {
                const msg = v8.ffi.v8_String_NewFromUtf8(isolate, "importScripts: Failed to join path", 35) orelse return;
                if (v8.ffi.v8_Exception_Error(msg)) |exc| {
                    v8.ffi.v8_Isolate_ThrowException(isolate, exc);
                }
                return;
            };
        } else {
            // Relative path - resolve against test directory
            full_path = std.fs.path.join(allocator, &.{ wpt_root, test_dir, url_str }) catch {
                const msg = v8.ffi.v8_String_NewFromUtf8(isolate, "importScripts: Failed to join path", 35) orelse return;
                if (v8.ffi.v8_Exception_Error(msg)) |exc| {
                    v8.ffi.v8_Isolate_ThrowException(isolate, exc);
                }
                return;
            };
        }
        defer allocator.free(full_path);

        // Read the script file
        const file = std.fs.cwd().openFile(full_path, .{}) catch {
            // Format error message with URL
            var err_buf: [256]u8 = undefined;
            const err_msg = std.fmt.bufPrint(&err_buf, "importScripts: Failed to load '{s}'", .{url_str}) catch "importScripts: Failed to load script";
            const msg = v8.ffi.v8_String_NewFromUtf8(isolate, err_msg.ptr, @intCast(err_msg.len)) orelse return;
            if (v8.ffi.v8_Exception_Error(msg)) |exc| {
                v8.ffi.v8_Isolate_ThrowException(isolate, exc);
            }
            return;
        };
        defer file.close();

        const content = file.readToEndAlloc(allocator, 10 * 1024 * 1024) catch {
            const msg = v8.ffi.v8_String_NewFromUtf8(isolate, "importScripts: Failed to read script", 36) orelse return;
            if (v8.ffi.v8_Exception_Error(msg)) |exc| {
                v8.ffi.v8_Isolate_ThrowException(isolate, exc);
            }
            return;
        };
        defer allocator.free(content);

        // Compile and execute the script
        const source_str = v8.ffi.v8_String_NewFromUtf8(isolate, content.ptr, @intCast(content.len)) orelse {
            const msg = v8.ffi.v8_String_NewFromUtf8(isolate, "importScripts: Failed to create source string", 45) orelse return;
            if (v8.ffi.v8_Exception_Error(msg)) |exc| {
                v8.ffi.v8_Isolate_ThrowException(isolate, exc);
            }
            return;
        };

        const compile_result = v8.ffi.v8_Script_Compile_Safe(v8_context, source_str);
        defer v8.ffi.v8_FreeScriptCompileResult(compile_result);

        if (compile_result.error_info != null) {
            const msg = v8.ffi.v8_String_NewFromUtf8(isolate, "importScripts: Script compilation failed", 40) orelse return;
            if (v8.ffi.v8_Exception_SyntaxError(msg)) |exc| {
                v8.ffi.v8_Isolate_ThrowException(isolate, exc);
            }
            return;
        }

        const script = compile_result.script orelse {
            const msg = v8.ffi.v8_String_NewFromUtf8(isolate, "importScripts: Script compilation failed", 40) orelse return;
            if (v8.ffi.v8_Exception_SyntaxError(msg)) |exc| {
                v8.ffi.v8_Isolate_ThrowException(isolate, exc);
            }
            return;
        };

        const run_result = v8.ffi.v8_Script_Run_Safe(v8_context, script);
        defer v8.ffi.v8_FreeScriptRunResult(run_result);

        if (run_result.error_info != null) {
            // Log the error for debugging
            std.log.warn("importScripts: Script execution failed for '{s}'", .{url_str});
            if (run_result.error_info) |err_info| {
                if (err_info.message) |err_msg| {
                    const err_len = std.mem.len(err_msg);
                    std.log.warn("  Error: {s}", .{err_msg[0..err_len]});
                }
            }
            const msg = v8.ffi.v8_String_NewFromUtf8(isolate, "importScripts: Script execution failed", 38) orelse return;
            if (v8.ffi.v8_Exception_Error(msg)) |exc| {
                v8.ffi.v8_Isolate_ThrowException(isolate, exc);
            }
            return;
        }

        // Run microtasks after each script
        v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);
    }

    if (v8.ffi.v8_Undefined(isolate)) |undef| {
        info.setReturnValue(undef);
    }
}

/// Worker postMessage() callback - stub for WPT tests
/// In a real implementation, this would send a message to the parent context.
/// For WPT tests, this is a no-op since we don't have actual worker threads.
fn workerPostMessageCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    // No-op stub - just return undefined
    if (v8.ffi.v8_Undefined(isolate)) |undef| {
        info.setReturnValue(undef);
    }
}

/// Worker close() callback - stub for WPT tests
/// In a real implementation, this would terminate the worker.
/// For WPT tests, this is a no-op since we don't have actual worker threads.
fn workerCloseCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    // No-op stub - just return undefined
    if (v8.ffi.v8_Undefined(isolate)) |undef| {
        info.setReturnValue(undef);
    }
}

// ============================================================================
// Fetch API Callback
// ============================================================================

// Import the fetch implementation
const global_fetch = @import("fetch").webidl.global_fetch;
const FetchInput = global_fetch.FetchInput;
const FetchResult = global_fetch.FetchResult;
const Response = @import("fetch").webidl.Response;

/// Global fetch() callback for WPT tests
/// Implements the WHATWG Fetch Standard global fetch() function.
///
/// This callback:
/// 1. Extracts the URL from the first argument
/// 2. Calls the real Zig fetch implementation
/// 3. Wraps the result in a V8 Promise (per spec, fetch() returns Promise<Response>)
///
/// For file: URLs, it reads the file directly (needed for WPT test resources).
fn fetchCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        // Return undefined on failure
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    };

    // fetch() requires at least 1 argument (input)
    if (info.v8_FunctionCallbackInfo_Length() < 1) {
        // Throw TypeError: "Failed to execute 'fetch': 1 argument required, but only 0 present."
        const msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Failed to execute 'fetch': 1 argument required", 47) orelse {
            if (v8.ffi.v8_Undefined(isolate)) |undef| {
                info.setReturnValue(undef);
            }
            return;
        };
        if (v8.ffi.v8_Exception_TypeError(msg)) |exc| {
            v8.ffi.v8_Isolate_ThrowException(isolate, exc);
        }
        return;
    }

    // Get the URL from first argument
    const input_value = info.get(0);

    // Use a temporary allocator for this callback
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Extract URL string from input
    const url_str = extractString(allocator, isolate, v8_context, input_value) catch {
        const msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Failed to convert input to string", 34) orelse {
            if (v8.ffi.v8_Undefined(isolate)) |undef| {
                info.setReturnValue(undef);
            }
            return;
        };
        if (v8.ffi.v8_Exception_TypeError(msg)) |exc| {
            v8.ffi.v8_Isolate_ThrowException(isolate, exc);
        }
        return;
    };
    defer allocator.free(url_str);

    // Create a Promise to return (fetch() returns Promise<Response>)
    const resolver = v8.ffi.v8_PromiseResolver_New(v8_context) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    };
    const promise = v8.ffi.v8_PromiseResolver_GetPromise(resolver) orelse {
        v8.ffi.v8_PromiseResolver_Dispose(resolver);
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    };

    // Set the Promise as return value immediately (async behavior)
    info.setReturnValue(@ptrCast(promise));

    // Check for relative URLs (used by WPT tests like "resources/urltestdata.json")
    // Resolve them relative to the current test file in the WPT directory
    const is_relative = !std.mem.startsWith(u8, url_str, "http://") and
        !std.mem.startsWith(u8, url_str, "https://") and
        !std.mem.startsWith(u8, url_str, "file://") and
        !std.mem.startsWith(u8, url_str, "data:");

    if (is_relative) {
        // Get the WPT root and current test path for resolution
        const wpt_root = getWptRoot() orelse {
            const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "No WPT root set", 15) orelse return;
            if (v8.ffi.v8_Exception_TypeError(err_msg)) |exc| {
                _ = v8.ffi.v8_PromiseResolver_Reject(resolver, v8_context, exc);
            }
            return;
        };
        const test_path = getCurrentTestPath() orelse {
            const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "No test path set", 16) orelse return;
            if (v8.ffi.v8_Exception_TypeError(err_msg)) |exc| {
                _ = v8.ffi.v8_PromiseResolver_Reject(resolver, v8_context, exc);
            }
            return;
        };

        // Construct full path based on whether URL is absolute (starts with /) or relative
        var full_path: []u8 = undefined;
        if (std.mem.startsWith(u8, url_str, "/")) {
            // Absolute path from WPT root (e.g., "/interfaces/console.idl")
            full_path = std.fs.path.join(allocator, &.{ wpt_root, url_str[1..] }) catch {
                const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Failed to join path", 19) orelse return;
                if (v8.ffi.v8_Exception_TypeError(err_msg)) |exc| {
                    _ = v8.ffi.v8_PromiseResolver_Reject(resolver, v8_context, exc);
                }
                return;
            };
        } else {
            // Relative path - resolve against test directory
            const test_dir = if (std.mem.lastIndexOf(u8, test_path, "/")) |pos|
                test_path[0..pos]
            else
                "";
            full_path = std.fs.path.join(allocator, &.{ wpt_root, test_dir, url_str }) catch {
                const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Failed to join path", 19) orelse return;
                if (v8.ffi.v8_Exception_TypeError(err_msg)) |exc| {
                    _ = v8.ffi.v8_PromiseResolver_Reject(resolver, v8_context, exc);
                }
                return;
            };
        }
        defer allocator.free(full_path);

        // Read the file
        const file = std.fs.cwd().openFile(full_path, .{}) catch {
            const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Failed to open file", 19) orelse return;
            if (v8.ffi.v8_Exception_TypeError(err_msg)) |exc| {
                _ = v8.ffi.v8_PromiseResolver_Reject(resolver, v8_context, exc);
            }
            return;
        };
        defer file.close();

        const content = file.readToEndAlloc(allocator, 10 * 1024 * 1024) catch {
            const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Failed to read file", 19) orelse return;
            if (v8.ffi.v8_Exception_TypeError(err_msg)) |exc| {
                _ = v8.ffi.v8_PromiseResolver_Reject(resolver, v8_context, exc);
            }
            return;
        };
        defer allocator.free(content);

        // Create Response-like object
        const response_obj = v8.ffi.v8_Object_New(isolate) orelse {
            const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Failed to create response", 25) orelse return;
            if (v8.ffi.v8_Exception_TypeError(err_msg)) |exc| {
                _ = v8.ffi.v8_PromiseResolver_Reject(resolver, v8_context, exc);
            }
            return;
        };

        // Set ok = true
        const ok_key = v8.ffi.v8_String_NewFromUtf8(isolate, "ok", 2) orelse return;
        if (v8.ffi.v8_Boolean_New(isolate, true)) |ok_val| {
            _ = v8.ffi.v8_Object_Set(response_obj, v8_context, @ptrCast(ok_key), ok_val);
        }

        // Set status = 200
        const status_key = v8.ffi.v8_String_NewFromUtf8(isolate, "status", 6) orelse return;
        const status_val: *v8.ffi.Value = @ptrCast(v8.ffi.v8_Integer_New(isolate, 200));
        _ = v8.ffi.v8_Object_Set(response_obj, v8_context, @ptrCast(status_key), status_val);

        // Store content for json() method
        const body_key = v8.ffi.v8_String_NewFromUtf8(isolate, "_body", 5) orelse return;
        const body_str = v8.ffi.v8_String_NewFromUtf8(isolate, content.ptr, @intCast(content.len)) orelse return;
        _ = v8.ffi.v8_Object_Set(response_obj, v8_context, @ptrCast(body_key), @ptrCast(body_str));

        // Add json() method
        const json_template = v8.ffi.v8_FunctionTemplate_New(isolate, responseJsonCallback, null) orelse return;
        const json_func = v8.ffi.v8_FunctionTemplate_GetFunction(json_template, v8_context) orelse return;
        const json_key = v8.ffi.v8_String_NewFromUtf8(isolate, "json", 4) orelse return;
        _ = v8.ffi.v8_Object_Set(response_obj, v8_context, @ptrCast(json_key), @ptrCast(json_func));

        // Add text() method
        const text_template = v8.ffi.v8_FunctionTemplate_New(isolate, responseTextCallback, null) orelse return;
        const text_func = v8.ffi.v8_FunctionTemplate_GetFunction(text_template, v8_context) orelse return;
        const text_key = v8.ffi.v8_String_NewFromUtf8(isolate, "text", 4) orelse return;
        _ = v8.ffi.v8_Object_Set(response_obj, v8_context, @ptrCast(text_key), @ptrCast(text_func));

        // Resolve the promise
        _ = v8.ffi.v8_PromiseResolver_Resolve(resolver, v8_context, @ptrCast(response_obj));
        return;
    }

    // Check for file: URL scheme (needed for WPT test resources)
    if (std.mem.startsWith(u8, url_str, "file://")) {
        // Extract the file path from file:// URL
        const file_path = url_str[7..]; // Skip "file://"

        // Read the file
        const file = std.fs.cwd().openFile(file_path, .{}) catch {
            // Reject with network error
            const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Failed to open file", 19) orelse return;
            if (v8.ffi.v8_Exception_TypeError(err_msg)) |exc| {
                _ = v8.ffi.v8_PromiseResolver_Reject(resolver, v8_context, exc);
            }
            return;
        };
        defer file.close();

        const content = file.readToEndAlloc(allocator, 10 * 1024 * 1024) catch {
            const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Failed to read file", 19) orelse return;
            if (v8.ffi.v8_Exception_TypeError(err_msg)) |exc| {
                _ = v8.ffi.v8_PromiseResolver_Reject(resolver, v8_context, exc);
            }
            return;
        };
        defer allocator.free(content);

        // Create a simple Response-like object for file contents
        // In a full implementation, we'd create a proper Response instance
        // For now, create an object with json() method for WPT tests
        const response_obj = v8.ffi.v8_Object_New(isolate) orelse {
            const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Failed to create response", 25) orelse return;
            if (v8.ffi.v8_Exception_TypeError(err_msg)) |exc| {
                _ = v8.ffi.v8_PromiseResolver_Reject(resolver, v8_context, exc);
            }
            return;
        };

        // Set ok = true
        const ok_key = v8.ffi.v8_String_NewFromUtf8(isolate, "ok", 2) orelse return;
        if (v8.ffi.v8_Boolean_New(isolate, true)) |ok_val| {
            _ = v8.ffi.v8_Object_Set(response_obj, v8_context, @ptrCast(ok_key), ok_val);
        }

        // Set status = 200
        const status_key = v8.ffi.v8_String_NewFromUtf8(isolate, "status", 6) orelse return;
        const status_val: *v8.ffi.Value = @ptrCast(v8.ffi.v8_Integer_New(isolate, 200));
        _ = v8.ffi.v8_Object_Set(response_obj, v8_context, @ptrCast(status_key), status_val);

        // Store the content for json() method
        // We'll create a json() method that parses and returns the content
        const body_key = v8.ffi.v8_String_NewFromUtf8(isolate, "_body", 5) orelse return;
        const body_str = v8.ffi.v8_String_NewFromUtf8(isolate, content.ptr, @intCast(content.len)) orelse return;
        _ = v8.ffi.v8_Object_Set(response_obj, v8_context, @ptrCast(body_key), @ptrCast(body_str));

        // Add json() method
        const json_template = v8.ffi.v8_FunctionTemplate_New(isolate, responseJsonCallback, null) orelse return;
        const json_func = v8.ffi.v8_FunctionTemplate_GetFunction(json_template, v8_context) orelse return;
        const json_key = v8.ffi.v8_String_NewFromUtf8(isolate, "json", 4) orelse return;
        _ = v8.ffi.v8_Object_Set(response_obj, v8_context, @ptrCast(json_key), @ptrCast(json_func));

        // Add text() method
        const text_template = v8.ffi.v8_FunctionTemplate_New(isolate, responseTextCallback, null) orelse return;
        const text_func = v8.ffi.v8_FunctionTemplate_GetFunction(text_template, v8_context) orelse return;
        const text_key = v8.ffi.v8_String_NewFromUtf8(isolate, "text", 4) orelse return;
        _ = v8.ffi.v8_Object_Set(response_obj, v8_context, @ptrCast(text_key), @ptrCast(text_func));

        // Resolve the promise with the response object
        _ = v8.ffi.v8_PromiseResolver_Resolve(resolver, v8_context, @ptrCast(response_obj));
        return;
    }

    // For non-file URLs, use the real fetch implementation
    var fetch_result = global_fetch.globalFetch(allocator, .{ .url = url_str }, .{});
    defer fetch_result.deinit();

    switch (fetch_result) {
        .response => |response| {
            // Create a Response-like object
            const response_obj = v8.ffi.v8_Object_New(isolate) orelse {
                const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Failed to create response", 25) orelse return;
                if (v8.ffi.v8_Exception_TypeError(err_msg)) |exc| {
                    _ = v8.ffi.v8_PromiseResolver_Reject(resolver, v8_context, exc);
                }
                return;
            };

            // Set ok based on status
            const ok_key = v8.ffi.v8_String_NewFromUtf8(isolate, "ok", 2) orelse return;
            const is_ok = response.status() >= 200 and response.status() < 300;
            if (v8.ffi.v8_Boolean_New(isolate, is_ok)) |ok_val| {
                _ = v8.ffi.v8_Object_Set(response_obj, v8_context, @ptrCast(ok_key), ok_val);
            }

            // Set status
            const status_key = v8.ffi.v8_String_NewFromUtf8(isolate, "status", 6) orelse return;
            const status_val: *v8.ffi.Value = @ptrCast(v8.ffi.v8_Integer_New(isolate, @intCast(response.status())));
            _ = v8.ffi.v8_Object_Set(response_obj, v8_context, @ptrCast(status_key), status_val);

            // Get body if available
            if (response.internal.body) |body| {
                switch (body.source) {
                    .bytes => |source| {
                        const body_key = v8.ffi.v8_String_NewFromUtf8(isolate, "_body", 5) orelse return;
                        const body_str = v8.ffi.v8_String_NewFromUtf8(isolate, source.ptr, @intCast(source.len)) orelse return;
                        _ = v8.ffi.v8_Object_Set(response_obj, v8_context, @ptrCast(body_key), @ptrCast(body_str));
                    },
                    .none, .blob, .form_data => {},
                }
            }

            // Add json() method
            const json_template = v8.ffi.v8_FunctionTemplate_New(isolate, responseJsonCallback, null) orelse return;
            const json_func = v8.ffi.v8_FunctionTemplate_GetFunction(json_template, v8_context) orelse return;
            const json_key = v8.ffi.v8_String_NewFromUtf8(isolate, "json", 4) orelse return;
            _ = v8.ffi.v8_Object_Set(response_obj, v8_context, @ptrCast(json_key), @ptrCast(json_func));

            // Add text() method
            const text_template = v8.ffi.v8_FunctionTemplate_New(isolate, responseTextCallback, null) orelse return;
            const text_func = v8.ffi.v8_FunctionTemplate_GetFunction(text_template, v8_context) orelse return;
            const text_key = v8.ffi.v8_String_NewFromUtf8(isolate, "text", 4) orelse return;
            _ = v8.ffi.v8_Object_Set(response_obj, v8_context, @ptrCast(text_key), @ptrCast(text_func));

            // Resolve the promise with the response object
            _ = v8.ffi.v8_PromiseResolver_Resolve(resolver, v8_context, @ptrCast(response_obj));
        },
        .err => |err| {
            const err_str = switch (err) {
                global_fetch.FetchError.NetworkError => "NetworkError",
                global_fetch.FetchError.AbortError => "AbortError",
                global_fetch.FetchError.TypeError => "TypeError",
                global_fetch.FetchError.OutOfMemory => "OutOfMemory",
            };
            const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, err_str.ptr, @intCast(err_str.len)) orelse return;
            if (v8.ffi.v8_Exception_TypeError(err_msg)) |exc| {
                _ = v8.ffi.v8_PromiseResolver_Reject(resolver, v8_context, exc);
            }
        },
    }
}

/// Response.json() callback - parses the _body as JSON and returns a Promise
fn responseJsonCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    };

    // Get 'this' (the Response object)
    const this_obj = info.getThis();

    // Get the _body property
    const body_key = v8.ffi.v8_String_NewFromUtf8(isolate, "_body", 5) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    };
    const body_value = v8.ffi.v8_Object_Get(this_obj, v8_context, @ptrCast(body_key)) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    };

    // Create a Promise for the result
    const resolver = v8.ffi.v8_PromiseResolver_New(v8_context) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    };
    const promise = v8.ffi.v8_PromiseResolver_GetPromise(resolver) orelse {
        v8.ffi.v8_PromiseResolver_Dispose(resolver);
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    };

    // Set promise as return value
    info.setReturnValue(@ptrCast(promise));

    // Parse JSON using JavaScript's JSON.parse()
    // We need to call JSON.parse(body_value)
    const global = v8.ffi.v8_Context_Global(v8_context) orelse {
        const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Failed to get global", 20) orelse return;
        if (v8.ffi.v8_Exception_TypeError(err_msg)) |exc| {
            _ = v8.ffi.v8_PromiseResolver_Reject(resolver, v8_context, exc);
        }
        return;
    };

    // Get JSON object
    const json_key = v8.ffi.v8_String_NewFromUtf8(isolate, "JSON", 4) orelse return;
    const json_obj = v8.ffi.v8_Object_Get(global, v8_context, @ptrCast(json_key)) orelse {
        const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "JSON not found", 14) orelse return;
        if (v8.ffi.v8_Exception_TypeError(err_msg)) |exc| {
            _ = v8.ffi.v8_PromiseResolver_Reject(resolver, v8_context, exc);
        }
        return;
    };

    // Get JSON.parse
    const parse_key = v8.ffi.v8_String_NewFromUtf8(isolate, "parse", 5) orelse return;
    const parse_value = v8.ffi.v8_Object_Get(@ptrCast(json_obj), v8_context, @ptrCast(parse_key)) orelse {
        const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "JSON.parse not found", 20) orelse return;
        if (v8.ffi.v8_Exception_TypeError(err_msg)) |exc| {
            _ = v8.ffi.v8_PromiseResolver_Reject(resolver, v8_context, exc);
        }
        return;
    };

    // Call JSON.parse(body_value)
    const parse_fn: *v8.ffi.Function = @ptrCast(parse_value);
    var args = [_]*v8.ffi.Value{body_value};
    const parsed = v8.ffi.v8_Function_Call(parse_fn, v8_context, json_obj, 1, &args);

    if (parsed) |result| {
        _ = v8.ffi.v8_PromiseResolver_Resolve(resolver, v8_context, result);
    } else {
        // JSON parse failed - get the exception
        if (v8.ffi.v8_TryCatch_Exception(v8_context)) |exc| {
            _ = v8.ffi.v8_PromiseResolver_Reject(resolver, v8_context, exc);
        } else {
            const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "JSON parse failed", 17) orelse return;
            if (v8.ffi.v8_Exception_TypeError(err_msg)) |exc| {
                _ = v8.ffi.v8_PromiseResolver_Reject(resolver, v8_context, exc);
            }
        }
    }
}

/// Response.text() callback - returns the _body as a string Promise
fn responseTextCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    };

    // Get 'this' (the Response object)
    const this_obj = info.getThis();

    // Get the _body property
    const body_key = v8.ffi.v8_String_NewFromUtf8(isolate, "_body", 5) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    };
    const body_value = v8.ffi.v8_Object_Get(this_obj, v8_context, @ptrCast(body_key));

    // Create a Promise for the result
    const resolver = v8.ffi.v8_PromiseResolver_New(v8_context) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    };
    const promise = v8.ffi.v8_PromiseResolver_GetPromise(resolver) orelse {
        v8.ffi.v8_PromiseResolver_Dispose(resolver);
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    };

    // Set promise as return value
    info.setReturnValue(@ptrCast(promise));

    // Resolve with the body text (or empty string if no body)
    if (body_value) |value| {
        _ = v8.ffi.v8_PromiseResolver_Resolve(resolver, v8_context, value);
    } else {
        const empty_str = v8.ffi.v8_String_NewFromUtf8(isolate, "", 0) orelse return;
        _ = v8.ffi.v8_PromiseResolver_Resolve(resolver, v8_context, @ptrCast(empty_str));
    }
}

/// WPT result reporting callback - called by testharnessreport.js for each test result
/// Signature: __wpt_report_result(name, status, message, stack, duration)
///
/// OPTIMIZATION: This callback is called once per test assertion (14,000+ times for
/// encoding character tests). We use the collector's allocator directly instead of
/// creating a fresh GeneralPurposeAllocator per callback, which was extremely wasteful.
/// We also extract strings directly into the collector's allocator to avoid double-copy.
fn wptReportResultCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    };

    // Get result collector from thread-local storage
    const collector = getResultCollector() orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    };

    // Parse arguments: name, status, message, stack, duration
    const arg_count = info.v8_FunctionCallbackInfo_Length();
    if (arg_count < 2) {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    }

    // Use the collector's allocator directly - avoid creating fresh GPA per callback
    // This is a major optimization for tests with 14,000+ assertions
    const allocator = collector.allocator;

    // Arg 0: name (string) - extract directly into collector's allocator
    const name_value = info.get(0);
    const name_str = extractString(allocator, isolate, context, name_value) catch {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    };
    // Note: name_str is now owned by collector.allocator, no need for separate dupe

    // Arg 1: status (number: 0=PASS, 1=FAIL, 2=TIMEOUT, 3=NOTRUN, 4=PRECONDITION_FAILED)
    const status_value = info.get(1);
    const status_num: u8 = if (v8.ffi.v8_Value_IsNumber(status_value))
        @intFromFloat(v8.ffi.v8_Value_NumberValue(status_value, context))
    else
        1; // Default to FAIL
    const status = test_harness.TestStatus.fromInt(status_num);

    // Arg 2: message (string or null) - extract directly into collector's allocator
    var message_str: ?[]u8 = null;
    if (arg_count > 2) {
        const msg_value = info.get(2);
        if (!v8.ffi.v8_Value_IsNull(msg_value) and !v8.ffi.v8_Value_IsUndefined(msg_value)) {
            message_str = extractString(allocator, isolate, context, msg_value) catch null;
        }
    }

    // Arg 3: stack (string or null) - extract directly into collector's allocator
    var stack_str: ?[]u8 = null;
    if (arg_count > 3) {
        const stack_value = info.get(3);
        if (!v8.ffi.v8_Value_IsNull(stack_value) and !v8.ffi.v8_Value_IsUndefined(stack_value)) {
            stack_str = extractString(allocator, isolate, context, stack_value) catch null;
        }
    }

    // Arg 4: duration (number)
    var duration_ms: u64 = 0;
    if (arg_count > 4) {
        const duration_value = info.get(4);
        if (v8.ffi.v8_Value_IsNumber(duration_value)) {
            const duration_float = v8.ffi.v8_Value_NumberValue(duration_value, context);
            duration_ms = @intFromFloat(@max(0.0, duration_float));
        }
    }

    // Create SubtestResult - strings are already in collector's allocator, no dupe needed
    const subtest = test_harness.SubtestResult{
        .name = name_str,
        .status = status,
        .message = message_str,
        .stack = stack_str,
        .duration_ms = duration_ms,
    };

    collector.addResult(subtest) catch |err| {
        std.debug.print("WPT: Failed to add result: {}\n", .{err});
        // Clean up on failure since we can't add to collector
        allocator.free(name_str);
        if (message_str) |m| allocator.free(m);
        if (stack_str) |s| allocator.free(s);
    };

    if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
        info.setReturnValue(undef_value);
    }
}

/// Debug log callback - prints messages from JavaScript to stderr
fn wptDebugLogCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;

    const arg_count = info.v8_FunctionCallbackInfo_Length();
    if (arg_count == 0) return;

    const arg = info.get(0);
    const str = v8.ffi.v8_Value_ToString(arg, context) orelse return;
    const len = v8.ffi.v8_String_Utf8Length(str);
    if (len <= 0) return;

    var buf: [4096]u8 = undefined;
    const copy_len: usize = @min(@as(usize, @intCast(len)), buf.len - 1);
    _ = v8.ffi.v8_String_WriteUtf8(str, &buf, @intCast(copy_len));
    buf[copy_len] = 0;

    std.debug.print("{s}\n", .{buf[0..copy_len]});
}

/// WPT completion callback - called when all tests in a file complete
/// Signature: __wpt_report_completion(status, message)
fn wptReportCompletionCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    };

    // Get result collector from thread-local storage
    const collector = getResultCollector() orelse {
        std.debug.print("WPT: No result collector set for completion\n", .{});
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    };

    const arg_count = info.v8_FunctionCallbackInfo_Length();

    // Arg 0: status (number: 0=OK, 1=ERROR, 2=TIMEOUT)
    var harness_status = test_harness.HarnessStatus.ok;
    if (arg_count > 0) {
        const status_value = info.get(0);
        if (v8.ffi.v8_Value_IsNumber(status_value)) {
            const status_num: u8 = @intFromFloat(v8.ffi.v8_Value_NumberValue(status_value, context));
            harness_status = test_harness.HarnessStatus.fromInt(status_num);
        }
    }

    // Arg 1: message (string or null)
    if (arg_count > 1) {
        const msg_value = info.get(1);
        if (!v8.ffi.v8_Value_IsNull(msg_value) and !v8.ffi.v8_Value_IsUndefined(msg_value)) {
            // Use a simple allocator for extraction
            var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            const allocator = gpa.allocator();
            defer _ = gpa.deinit();

            if (extractString(allocator, isolate, context, msg_value)) |msg_str| {
                defer allocator.free(msg_str);
                // The finishTest will dupe the message
                collector.finishTest(harness_status, msg_str, 0) catch |err| {
                    std.debug.print("WPT: Failed to finish test: {}\n", .{err});
                };
                if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
                    info.setReturnValue(undef_value);
                }
                return;
            } else |_| {
                // Ignore extraction error, proceed without message
            }
        }
    }

    // Finish the test with no message
    collector.finishTest(harness_status, null, 0) catch {};

    if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
        info.setReturnValue(undef_value);
    }
}

/// Helper to extract a string from a V8 value
fn extractString(allocator: std.mem.Allocator, isolate: *v8.ffi.Isolate, context: *v8.ffi.Context, value: *v8.ffi.Value) ![]u8 {
    _ = isolate;
    const str = v8.ffi.v8_Value_ToString(value, context) orelse return error.StringConversionFailed;
    const len = v8.ffi.v8_String_Utf8Length(str);
    if (len <= 0) return allocator.dupe(u8, "");

    const buffer = try allocator.alloc(u8, @intCast(len));
    errdefer allocator.free(buffer);

    const written = v8.ffi.v8_String_WriteUtf8(str, buffer.ptr, @intCast(len));
    if (written <= 0) {
        allocator.free(buffer);
        return error.StringWriteFailed;
    }

    return buffer[0..@intCast(written)];
}

/// Create a window context for .window.js and .html tests
pub fn createWindowContext(allocator: std.mem.Allocator, wpt_root: []const u8) !BrowserContext {
    var ctx = try BrowserContext.init(allocator, .window, wpt_root);
    errdefer ctx.deinit();

    try ctx.initialize();
    return ctx;
}

/// Create a worker context for .worker.js tests
pub fn createWorkerContext(allocator: std.mem.Allocator, wpt_root: []const u8) !BrowserContext {
    var ctx = try BrowserContext.init(allocator, .worker, wpt_root);
    errdefer ctx.deinit();

    try ctx.initialize();
    return ctx;
}

/// Create context appropriate for the test file type
pub fn createContextForTest(
    allocator: std.mem.Allocator,
    wpt_root: []const u8,
    global_type: test_parser.GlobalType,
) !BrowserContext {
    const context_type: ContextType = switch (global_type) {
        .window => .window,
        .worker => .worker,
        .sharedworker => .shared_worker,
        .serviceworker => .service_worker,
    };

    var ctx = try BrowserContext.init(allocator, context_type, wpt_root);
    errdefer ctx.deinit();

    try ctx.initialize();
    return ctx;
}

test "BrowserContext basic init" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var ctx = try BrowserContext.init(allocator, .window, "tests/wpt");
    defer ctx.deinit();

    try testing.expectEqual(ContextType.window, ctx.context_type);
    try testing.expectEqualStrings("tests/wpt", ctx.wpt_root);
}

test "createContextForTest" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var ctx = try BrowserContext.init(allocator, .worker, "tests/wpt");
    defer ctx.deinit();

    try testing.expectEqual(ContextType.worker, ctx.context_type);
}

// =============================================================================
// getComputedStyle callback
// =============================================================================

/// Callback for window.getComputedStyle(element, pseudoElt)
/// Returns a CSSStyleDeclaration-like object with computed style values.
/// This is a simplified implementation that creates a plain JS object with CSS properties
/// directly accessible via property names (e.g., style.display, style['display']).
/// Per CSSOM spec: https://drafts.csswg.org/cssom/#dom-window-getcomputedstyle
fn getComputedStyleCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    };

    // getComputedStyle requires at least 1 argument (element)
    if (info.v8_FunctionCallbackInfo_Length() < 1) {
        const msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Failed to execute 'getComputedStyle': 1 argument required", 57) orelse {
            if (v8.ffi.v8_Undefined(isolate)) |undef| {
                info.setReturnValue(undef);
            }
            return;
        };
        if (v8.ffi.v8_Exception_TypeError(msg)) |exc| {
            v8.ffi.v8_Isolate_ThrowException(isolate, exc);
        }
        return;
    }

    // Get the element argument
    const element_value = info.get(0);

    // Validate that argument is an object (Element)
    if (!v8.ffi.v8_Value_IsObject(element_value)) {
        const msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Failed to execute 'getComputedStyle': parameter 1 is not of type 'Element'", 74) orelse {
            if (v8.ffi.v8_Undefined(isolate)) |undef| {
                info.setReturnValue(undef);
            }
            return;
        };
        if (v8.ffi.v8_Exception_TypeError(msg)) |exc| {
            v8.ffi.v8_Isolate_ThrowException(isolate, exc);
        }
        return;
    }

    // Extract the runtime.Instance from the V8 object to get tag name
    const element_obj: *v8.ffi.Object = @ptrCast(element_value);
    const instance_ptr = v8.ffi.v8_Object_GetAlignedPointerFromInternalField(element_obj, 0);

    // Get tag name from element for element-type-specific styles
    var tag_name: []const u8 = "div"; // Default
    if (instance_ptr) |ptr| {
        const element_instance: *runtime.Instance = @ptrCast(@alignCast(ptr));
        // Try to get the tag name from the Element impl
        const ElementImpl = impls.Element;
        if (ElementImpl.getInternal(element_instance)) |internal| {
            tag_name = internal.local_name.asSlice();
        }
    }

    // Create a plain JS object that acts as CSSStyleDeclaration
    const result = v8.ffi.v8_Object_New(isolate) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    };

    // Add getPropertyValue method
    const get_prop_template = v8.ffi.v8_FunctionTemplate_New(isolate, getPropertyValueCallback, null) orelse return;
    const get_prop_func = v8.ffi.v8_FunctionTemplate_GetFunction(get_prop_template, v8_context) orelse return;
    const get_prop_key = v8.ffi.v8_String_NewFromUtf8(isolate, "getPropertyValue", 16) orelse return;
    _ = v8.ffi.v8_Object_Set(result, v8_context, @ptrCast(get_prop_key), @ptrCast(get_prop_func));

    // Determine display value based on element tag name
    const display_value: []const u8 = getDefaultDisplayForTag(tag_name);

    // Add CSS properties directly on the object for property access (style.display, style['display'])
    const props = [_]struct { name: []const u8, camel: []const u8, value: []const u8 }{
        .{ .name = "display", .camel = "display", .value = display_value },
        .{ .name = "visibility", .camel = "visibility", .value = "visible" },
        .{ .name = "position", .camel = "position", .value = "static" },
        .{ .name = "color", .camel = "color", .value = "rgb(0, 0, 0)" },
        .{ .name = "background-color", .camel = "backgroundColor", .value = "rgba(0, 0, 0, 0)" },
        .{ .name = "width", .camel = "width", .value = "auto" },
        .{ .name = "height", .camel = "height", .value = "auto" },
        .{ .name = "margin", .camel = "margin", .value = "0px" },
        .{ .name = "padding", .camel = "padding", .value = "0px" },
        .{ .name = "border", .camel = "border", .value = "0px none rgb(0, 0, 0)" },
        .{ .name = "font-size", .camel = "fontSize", .value = "16px" },
        .{ .name = "font-family", .camel = "fontFamily", .value = "sans-serif" },
        .{ .name = "line-height", .camel = "lineHeight", .value = "normal" },
        .{ .name = "overflow", .camel = "overflow", .value = "visible" },
        .{ .name = "z-index", .camel = "zIndex", .value = "auto" },
    };

    for (props) |prop| {
        // Set both kebab-case and camelCase versions
        if (v8.ffi.v8_String_NewFromUtf8(isolate, prop.name.ptr, @intCast(prop.name.len))) |key| {
            if (v8.ffi.v8_String_NewFromUtf8(isolate, prop.value.ptr, @intCast(prop.value.len))) |value| {
                _ = v8.ffi.v8_Object_Set(result, v8_context, @ptrCast(key), @ptrCast(value));
            }
        }
        if (!std.mem.eql(u8, prop.name, prop.camel)) {
            if (v8.ffi.v8_String_NewFromUtf8(isolate, prop.camel.ptr, @intCast(prop.camel.len))) |key| {
                if (v8.ffi.v8_String_NewFromUtf8(isolate, prop.value.ptr, @intCast(prop.value.len))) |value| {
                    _ = v8.ffi.v8_Object_Set(result, v8_context, @ptrCast(key), @ptrCast(value));
                }
            }
        }
    }

    // Add length property (for iteration)
    const length_key = v8.ffi.v8_String_NewFromUtf8(isolate, "length", 6) orelse return;
    const length_val = v8.ffi.v8_Number_New(isolate, 0.0);
    _ = v8.ffi.v8_Object_Set(result, v8_context, @ptrCast(length_key), @ptrCast(length_val));

    info.setReturnValue(@ptrCast(result));
}

/// Get the default display value for an HTML element tag name
fn getDefaultDisplayForTag(tag_name: []const u8) []const u8 {
    // Block elements
    if (std.mem.eql(u8, tag_name, "div") or
        std.mem.eql(u8, tag_name, "p") or
        std.mem.eql(u8, tag_name, "h1") or
        std.mem.eql(u8, tag_name, "h2") or
        std.mem.eql(u8, tag_name, "h3") or
        std.mem.eql(u8, tag_name, "h4") or
        std.mem.eql(u8, tag_name, "h5") or
        std.mem.eql(u8, tag_name, "h6") or
        std.mem.eql(u8, tag_name, "header") or
        std.mem.eql(u8, tag_name, "footer") or
        std.mem.eql(u8, tag_name, "main") or
        std.mem.eql(u8, tag_name, "section") or
        std.mem.eql(u8, tag_name, "article") or
        std.mem.eql(u8, tag_name, "aside") or
        std.mem.eql(u8, tag_name, "nav") or
        std.mem.eql(u8, tag_name, "address") or
        std.mem.eql(u8, tag_name, "blockquote") or
        std.mem.eql(u8, tag_name, "pre") or
        std.mem.eql(u8, tag_name, "form") or
        std.mem.eql(u8, tag_name, "fieldset") or
        std.mem.eql(u8, tag_name, "hr") or
        std.mem.eql(u8, tag_name, "ul") or
        std.mem.eql(u8, tag_name, "ol") or
        std.mem.eql(u8, tag_name, "dl") or
        std.mem.eql(u8, tag_name, "figure") or
        std.mem.eql(u8, tag_name, "figcaption"))
    {
        return "block";
    }

    // List items
    if (std.mem.eql(u8, tag_name, "li")) {
        return "list-item";
    }

    // Table elements
    if (std.mem.eql(u8, tag_name, "table")) {
        return "table";
    }
    if (std.mem.eql(u8, tag_name, "thead") or
        std.mem.eql(u8, tag_name, "tbody") or
        std.mem.eql(u8, tag_name, "tfoot"))
    {
        return "table-row-group";
    }
    if (std.mem.eql(u8, tag_name, "tr")) {
        return "table-row";
    }
    if (std.mem.eql(u8, tag_name, "td") or std.mem.eql(u8, tag_name, "th")) {
        return "table-cell";
    }
    if (std.mem.eql(u8, tag_name, "caption")) {
        return "table-caption";
    }
    if (std.mem.eql(u8, tag_name, "colgroup")) {
        return "table-column-group";
    }
    if (std.mem.eql(u8, tag_name, "col")) {
        return "table-column";
    }

    // Inline elements
    if (std.mem.eql(u8, tag_name, "span") or
        std.mem.eql(u8, tag_name, "a") or
        std.mem.eql(u8, tag_name, "strong") or
        std.mem.eql(u8, tag_name, "em") or
        std.mem.eql(u8, tag_name, "b") or
        std.mem.eql(u8, tag_name, "i") or
        std.mem.eql(u8, tag_name, "u") or
        std.mem.eql(u8, tag_name, "code") or
        std.mem.eql(u8, tag_name, "small") or
        std.mem.eql(u8, tag_name, "sub") or
        std.mem.eql(u8, tag_name, "sup") or
        std.mem.eql(u8, tag_name, "abbr") or
        std.mem.eql(u8, tag_name, "cite") or
        std.mem.eql(u8, tag_name, "label") or
        std.mem.eql(u8, tag_name, "img") or
        std.mem.eql(u8, tag_name, "br"))
    {
        return "inline";
    }

    // Inline-block elements
    if (std.mem.eql(u8, tag_name, "button") or
        std.mem.eql(u8, tag_name, "select") or
        std.mem.eql(u8, tag_name, "input") or
        std.mem.eql(u8, tag_name, "textarea"))
    {
        return "inline-block";
    }

    // None (hidden elements)
    if (std.mem.eql(u8, tag_name, "head") or
        std.mem.eql(u8, tag_name, "script") or
        std.mem.eql(u8, tag_name, "style") or
        std.mem.eql(u8, tag_name, "meta") or
        std.mem.eql(u8, tag_name, "link") or
        std.mem.eql(u8, tag_name, "title") or
        std.mem.eql(u8, tag_name, "template"))
    {
        return "none";
    }

    // Default to block for unknown elements
    return "block";
}

/// Callback for CSSStyleDeclaration.getPropertyValue(propertyName)
fn getPropertyValueCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    };

    // Get the 'this' object (the CSSStyleDeclaration-like object)
    const this_obj = info.getThis();

    // Get the property name argument
    const arg_count = info.v8_FunctionCallbackInfo_Length();
    if (arg_count < 1) {
        const empty = v8.ffi.v8_String_NewFromUtf8(isolate, "", 0) orelse return;
        info.setReturnValue(@ptrCast(empty));
        return;
    }

    const prop_value = info.get(0);
    const prop_str = v8.ffi.v8_Value_ToString(prop_value, context) orelse {
        const empty = v8.ffi.v8_String_NewFromUtf8(isolate, "", 0) orelse return;
        info.setReturnValue(@ptrCast(empty));
        return;
    };

    // Get the property value from the object itself
    // Since we set the properties on the object, we can just look them up
    if (v8.ffi.v8_Object_Get(this_obj, context, @ptrCast(prop_str))) |value| {
        if (!v8.ffi.v8_Value_IsUndefined(value)) {
            info.setReturnValue(value);
            return;
        }
    }

    // Return empty string for unknown properties
    const empty = v8.ffi.v8_String_NewFromUtf8(isolate, "", 0) orelse return;
    info.setReturnValue(@ptrCast(empty));
}

// =============================================================================
// Tests
// =============================================================================

test "BrowserContext - window context has correct GLOBAL" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Create window context
    var ctx = try BrowserContext.init(allocator, .window, "tests/wpt");
    defer ctx.deinit();

    try ctx.initialize();

    // Test that GLOBAL.isWindow() returns true
    // We can't easily capture JS return values, so we test by checking
    // that the script doesn't throw
    try ctx.executeScript(
        \\if (!self.GLOBAL.isWindow()) throw new Error("isWindow should be true in window context");
        \\if (self.GLOBAL.isWorker()) throw new Error("isWorker should be false in window context");
    );
}

test "BrowserContext - worker context has correct GLOBAL" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Create worker context
    var ctx = try BrowserContext.init(allocator, .worker, "tests/wpt");
    defer ctx.deinit();

    try ctx.initialize();

    // Test that GLOBAL.isWorker() returns true
    try ctx.executeScript(
        \\if (self.GLOBAL.isWindow()) throw new Error("isWindow should be false in worker context");
        \\if (!self.GLOBAL.isWorker()) throw new Error("isWorker should be true in worker context");
    );
}

test "BrowserContext - worker context has self but not window" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Create worker context
    var ctx = try BrowserContext.init(allocator, .worker, "tests/wpt");
    defer ctx.deinit();

    try ctx.initialize();

    // Test that 'self' exists but 'window' does not
    try ctx.executeScript(
        \\if (typeof self === 'undefined') throw new Error("self should be defined in worker");
        \\if (typeof window !== 'undefined') throw new Error("window should NOT be defined in worker");
    );
}

test "BrowserContext - window context has both self and window" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Create window context
    var ctx = try BrowserContext.init(allocator, .window, "tests/wpt");
    defer ctx.deinit();

    try ctx.initialize();

    // Test that both 'self' and 'window' exist
    try ctx.executeScript(
        \\if (typeof self === 'undefined') throw new Error("self should be defined in window");
        \\if (typeof window === 'undefined') throw new Error("window should be defined in window");
        \\if (self !== window) throw new Error("self and window should be the same in window context");
    );
}

test "BrowserContext - worker context has navigator" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Create worker context
    var ctx = try BrowserContext.init(allocator, .worker, "tests/wpt");
    defer ctx.deinit();

    try ctx.initialize();

    // Test that navigator exists in worker
    try ctx.executeScript(
        \\if (typeof navigator === 'undefined') throw new Error("navigator should be defined in worker");
    );
}
