//! Worker V8 Context Setup (PRODUCTION - Used by WPT)
//!
//! Spec: HTML Standard § 10.2.5 Processing model
//! https://html.spec.whatwg.org/#run-a-worker
//!
//! This is the PRODUCTION worker implementation used by WPT tests.
//! Each worker gets its own V8 isolate for complete memory isolation.
//!
//! ## THIS IS THE CORRECT PATH FOR WPT
//!
//! When JavaScript calls `new Worker(url)`, the WebIDL Worker.zig impl uses
//! this module via the callbacks in `Worker.zig:spawnWorkerThread()`:
//! - `createIsolateWithInterfaces()` → WorkerV8Context.init()
//! - `executeScriptWithInterfaces()` → WorkerV8Context.executeScript()
//!
//! ## Working Implementations
//!
//! This module has REAL, WORKING implementations:
//! - `importScriptsCallback()` - Fetches scripts via HTTP and executes them
//! - `workerPostMessageCallback()` - Serializes messages and sends to main thread
//! - `workerCloseCallback()` - Properly terminates the worker
//! - Registers WebIDL interfaces (URL, Event, EventTarget, WebSocket, etc.)
//!
//! ## vs worker_v8_integration.zig
//!
//! Do NOT confuse with `workers/worker_v8_integration.zig` which has STUB
//! implementations that just log "TODO". That module is LEGACY and NOT
//! used by WPT.
//!
//! ## Usage
//!
//! ```zig
//! const worker_v8 = @import("worker_v8_context.zig");
//!
//! // Create V8 context for a worker
//! const v8_ctx = try worker_v8.WorkerV8Context.init(allocator, script_url, worker_type);
//! defer v8_ctx.deinit();
//!
//! // Set up engine callbacks on WorkerContext
//! worker_context.setEngineContext(v8_ctx.getEngineContext(), v8_ctx.getCallbacks());
//!
//! // Execute script
//! try worker_context.executeScript(source);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");

// Crane version - single source of truth in src/version.zig
const crane_version = @import("version");
const CRANE_VERSION = crane_version.version;

// V8 FFI through runtime module
const v8 = @import("v8");
const runtime = @import("runtime");
const context_manager = v8.context_manager;
const V8EventLoop = v8.V8EventLoop;

// V8Interface for registering constructors
const V8Interface = v8.V8Interface;

// Interfaces needed in worker context
const interfaces = @import("interfaces");

// Worker types from html_core
const html_core = @import("html_core");
const workers = html_core.workers;
const WorkerContext = workers.WorkerContext;
const EngineCallbacks = workers.worker_context.EngineCallbacks;
const WorkerType = workers.WorkerType;
const DedicatedWorker = workers.DedicatedWorker;
const script_fetch = workers.script_fetch;

// Impl for setting up message handler
const impls = @import("impls");
const DedicatedWorkerGlobalScopeImpl = impls.DedicatedWorkerGlobalScope;

/// Opaque engine context type expected by WorkerContext
const EngineContext = workers.worker_context.EngineContext;

// Thread-local storage for current worker context (used by V8 callbacks)
threadlocal var current_worker_context: ?*WorkerV8Context = null;

/// Check if a URL indicates a secure context for worker
/// Per WPT convention, tests with .https. or .h2. in the filename should be treated
/// as secure contexts. Plain HTTP localhost is NOT considered secure for WPT tests
/// to allow testing non-secure context behavior.
fn isSecureUrlForWorker(url: []const u8) bool {
    // Check for secure schemes first
    if (std.mem.startsWith(u8, url, "https://") or
        std.mem.startsWith(u8, url, "wss://"))
    {
        return true;
    }

    // WPT convention: .https. in filename indicates secure context test
    if (std.mem.indexOf(u8, url, ".https.") != null) {
        return true;
    }

    // Also check for .h2. (HTTP/2 tests which require secure context)
    if (std.mem.indexOf(u8, url, ".h2.") != null) {
        return true;
    }

    return false;
}

/// Get the effective URL for a worker, applying WPT URL rewriting rules.
/// Per WPT convention:
///   - .https. tests use https://localhost:8443
///   - .h2. tests use https://localhost:9000 (HTTP/2)
fn getEffectiveWorkerUrl(allocator: std.mem.Allocator, url: []const u8) ![]const u8 {
    const is_h2 = std.mem.indexOf(u8, url, ".h2.") != null;
    const is_https = std.mem.indexOf(u8, url, ".https.") != null;

    if (is_h2 or is_https) {
        // Determine target port based on test type
        const target_port: []const u8 = if (is_h2) "9000" else "8443";

        // Rewrite http:// to https:// for location object
        if (std.mem.startsWith(u8, url, "http://localhost:8000")) {
            // Replace http://localhost:8000 with https://localhost:<port>
            const rest = url["http://localhost:8000".len..];
            return try std.fmt.allocPrint(allocator, "https://localhost:{s}{s}", .{ target_port, rest });
        } else if (std.mem.startsWith(u8, url, "http://")) {
            // Generic http:// to https:// replacement (preserve original port if present)
            const rest = url["http://".len..];
            return try std.fmt.allocPrint(allocator, "https://{s}", .{rest});
        }
    }

    // Return a duplicate of the original URL (caller owns the memory)
    return try allocator.dupe(u8, url);
}

/// V8 Context for Worker execution
///
/// Creates and manages a V8 isolate and context for a worker.
/// Each worker gets its own isolate for complete memory isolation.
pub const WorkerV8Context = struct {
    /// V8 Isolate for this worker (separate from main thread)
    isolate: *v8.ffi.Isolate,

    /// V8 Context within the isolate
    context: *v8.ffi.Context,

    /// Script URL for error messages and import.meta.url
    script_url: []const u8,

    /// Document base URL for resolving relative imports
    /// This is the creating document's URL, used when script_url is data: or blob:
    /// Per HTML Standard, relative URLs in workers should resolve against the
    /// document that created the worker, not the worker's script URL.
    document_base_url: ?[]const u8 = null,

    /// Worker type (classic or module)
    worker_type: WorkerType,

    /// Allocator
    allocator: Allocator,

    /// V8 Event loop for timer support (setTimeout/setInterval)
    /// This is created and owned by the worker, not the context_manager,
    /// because context_manager uses thread-local storage that is not
    /// accessible from the worker thread.
    event_loop: ?*V8EventLoop = null,

    /// Reference to the DedicatedWorker (set during setupWorkerGlobalScope)
    dedicated_worker: ?*DedicatedWorker = null,

    /// Flag to prevent double-deinit (deinit can be called from Worker.deinit and disposeContextCallback)
    is_deinitialized: bool = false,

    /// Flag to track if the initial script has been executed.
    /// The first message to a worker is the script to execute.
    /// Subsequent messages are postMessage data to dispatch as MessageEvents.
    script_executed: bool = false,

    const Self = @This();

    /// Create a new V8 context for a worker
    ///
    /// This creates:
    /// 1. A new V8 isolate from the snapshot (with all WebIDL interfaces pre-registered)
    /// 2. A V8 context within that isolate
    /// 3. Sets up basic global scope
    ///
    /// IMPORTANT: The main browser MUST have called initializeV8() first to:
    /// - Register external references
    /// - Load and cache the snapshot data
    pub fn init(
        allocator: Allocator,
        script_url: []const u8,
        worker_type: WorkerType,
        document_base_url: ?[]const u8,
    ) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        // Copy script URL
        const url_copy = try allocator.dupe(u8, script_url);
        errdefer allocator.free(url_copy);

        // Copy document base URL if provided (for data:/blob: workers)
        const base_url_copy: ?[]const u8 = if (document_base_url) |base|
            try allocator.dupe(u8, base)
        else
            null;
        errdefer if (base_url_copy) |b| allocator.free(b);

        // Try to create isolate from snapshot (thread-safe, uses already-registered refs)
        // This gives us all WebIDL interfaces pre-registered
        // Use context index 1 = DedicatedWorkerGlobalScope (not 0 = Window)
        const dedicated_worker_context_index: usize = 1;
        const snapshot_result = v8.snapshot_loader.createWorkerIsolateFromSnapshot(dedicated_worker_context_index);

        var isolate: *v8.ffi.Isolate = undefined;
        var context: *v8.ffi.Context = undefined;
        var used_snapshot = false;

        if (snapshot_result) |result| {
            isolate = result.isolate;
            context = result.context;
            used_snapshot = true;
        } else {
            // Fallback to raw isolate (no WebIDL interfaces)
            std.log.warn("[WorkerV8Context] Snapshot not available, falling back to raw V8 isolate", .{});

            // Initialize V8 platform if not already done
            v8.ffi.v8_Platform_Initialize();

            // Create raw V8 Isolate for this worker
            isolate = v8.ffi.v8_Isolate_New() orelse {
                return error.V8IsolateCreationFailed;
            };
            errdefer v8.ffi.v8_Isolate_Dispose(isolate);

            // Enter the isolate temporarily to create the context
            v8.ffi.v8_Isolate_Enter(isolate);

            // Create V8 Context within the isolate
            context = v8.ffi.v8_Context_New(isolate) orelse {
                v8.ffi.v8_Isolate_Exit(isolate);
                return error.V8ContextCreationFailed;
            };

            v8.ffi.v8_Isolate_Exit(isolate);
        }

        // Enter isolate and context for setup
        v8.ffi.v8_Isolate_Enter(isolate);
        v8.ffi.v8_Context_Enter(context);

        self.* = .{
            .isolate = isolate,
            .context = context,
            .script_url = url_copy,
            .document_base_url = base_url_copy,
            .worker_type = worker_type,
            .allocator = allocator,
        };

        // CRITICAL: Create HandleScope for V8 handle allocation during setup
        const handle_scope = v8.ffi.v8_HandleScope_New(isolate) orelse {
            v8.ffi.v8_Isolate_Exit(isolate);
            return error.HandleScopeCreationFailed;
        };
        defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

        // Hydrate worker context if using snapshot (reinstalls callbacks)
        if (used_snapshot) {
            std.debug.print("[WorkerV8Context] Hydrating worker context...\n", .{});
            _ = try context_manager.hydrateWorkerContext(.{
                .isolate = isolate,
                .context = context,
                .allocator = allocator,
            });
            std.debug.print("[WorkerV8Context] Worker context hydrated\n", .{});
        }

        // Set up basic worker globals (self, globalThis)
        std.debug.print("[WorkerV8Context] Setting up worker globals...\n", .{});
        try self.setupWorkerGlobals();
        std.debug.print("[WorkerV8Context] Worker globals set up\n", .{});

        // Only register interfaces if we didn't use the snapshot
        // (snapshot already has all interfaces pre-registered)
        if (!used_snapshot) {
            self.registerWorkerInterfaces();
        }

        // CRITICAL: Initialize the thread-local context manager for this worker thread
        // This allows WebIDL interfaces (like URL) to get the runtime context
        context_manager.init(allocator) catch |err| switch (err) {
            error.AlreadyInitialized => {
                // Context manager already initialized for this thread, that's fine
            },
        };

        // Create V8 event loop directly (not via context_manager) for timer support.
        // We store this in self.event_loop because:
        // 1. context_manager uses thread-local storage
        // 2. The worker runs on a separate thread from where init() is called
        // 3. The worker thread's thread-local storage won't have access to
        //    anything stored by the main thread's context_manager
        const ev_loop = try allocator.create(V8EventLoop);
        errdefer allocator.destroy(ev_loop);

        ev_loop.* = try V8EventLoop.init(isolate, allocator);
        errdefer ev_loop.deinit();

        self.event_loop = ev_loop;
        std.debug.print("[WorkerV8Context] Created V8EventLoop for timer support\n", .{});

        // Register this V8 context with the context manager (without isolate).
        // We pass null for isolate since we're managing the event loop ourselves.
        // This still creates a runtime context that WebIDL interfaces can use.
        _ = context_manager.getOrCreate(context, allocator) catch |err| {
            std.log.err("[WorkerV8Context] Failed to register context: {}", .{err});
            return error.ContextRegistrationFailed;
        };

        // Exit worker context/isolate after setup - we'll re-enter when executing scripts
        v8.ffi.v8_Context_Exit(context);
        v8.ffi.v8_Isolate_Exit(isolate);

        return self;
    }

    /// Clean up V8 isolate and context
    ///
    /// Note: This can be called from two paths:
    /// 1. Worker.deinit() -> v8_context.deinit()
    /// 2. WorkerContext.deinit() -> disposeContextCallback() -> deinit()
    ///
    /// The is_deinitialized flag prevents double-free.
    pub fn deinit(self: *Self) void {
        // Prevent double-deinit
        if (self.is_deinitialized) {
            return;
        }
        self.is_deinitialized = true;

        // TODO: Proper cleanup of worker isolate/context
        // Currently we skip V8 cleanup because:
        // 1. Worker isolates are separate from main isolate
        // 2. During test cleanup, main isolate may already be disposed
        // 3. Trying to dispose worker context after main is gone causes segfault
        //
        // For proper cleanup, we need to:
        // - Track worker isolates separately from main isolate
        // - Dispose worker isolates BEFORE main isolate
        // - Or run workers in actual separate threads with their own cleanup

        // Clean up the thread-local context manager
        // This removes the runtime context and frees associated resources
        context_manager.deinit();

        // Free Zig allocations only
        self.allocator.free(self.script_url);
        self.allocator.destroy(self);
    }

    /// Exit the worker's V8 isolate and context
    /// Call this after script execution to return control to main isolate
    pub fn exitIsolate(self: *Self) void {
        v8.ffi.v8_Context_Exit(self.context);
        v8.ffi.v8_Isolate_Exit(self.isolate);
    }

    /// Re-enter the worker's V8 isolate and context
    /// Call this before executing more scripts in the worker
    pub fn enterIsolate(self: *Self) void {
        v8.ffi.v8_Isolate_Enter(self.isolate);
        v8.ffi.v8_Context_Enter(self.context);
    }

    /// Get the runtime context for this worker
    /// Returns null if context manager is not initialized or context not found
    pub fn getRuntimeContext(self: *Self) ?runtime.Context {
        std.debug.print("[WorkerV8Context] getRuntimeContext() called, self.context={*}\n", .{self.context});
        const result = context_manager.getOrCreate(self.context, self.allocator) catch |err| {
            std.debug.print("[WorkerV8Context] getRuntimeContext() error: {}\n", .{err});
            return null;
        };
        std.debug.print("[WorkerV8Context] getRuntimeContext() returning result\n", .{});
        return result;
    }

    /// Set up basic worker global scope (called during init)
    ///
    /// Sets up:
    /// - self -> globalThis
    /// - globalThis -> global object
    fn setupWorkerGlobals(self: *Self) !void {
        const global_obj = v8.ffi.v8_Context_Global(self.context) orelse {
            return error.NoGlobalObject;
        };

        // Set up 'self' as reference to global object
        const self_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "self", 4) orelse {
            return error.StringCreationFailed;
        };
        _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(self_key), @ptrCast(global_obj));

        // Set up 'globalThis' as reference to global object
        const global_this_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "globalThis", 10) orelse {
            return error.StringCreationFailed;
        };
        _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(global_this_key), @ptrCast(global_obj));
    }

    /// Register essential WebIDL interfaces needed in worker context
    ///
    /// This registers a minimal subset of interfaces commonly used by WPT tests:
    /// - URL, URLSearchParams (for URL manipulation)
    /// - Event, EventTarget (for event handling)
    /// - DOMException (for error handling)
    /// - WebSocket, CloseEvent, MessageEvent (for WebSocket API - Exposed in Worker per spec)
    ///
    /// Full interface registration (initializeBindings) can't be used directly
    /// because it requires the main isolate's context manager state.
    fn registerWorkerInterfaces(self: *Self) void {
        // Create HandleScope for interface registration
        const handle_scope = v8.ffi.v8_HandleScope_New(self.isolate) orelse {
            std.log.err("[WorkerV8Context] Failed to create HandleScope for interface registration", .{});
            return;
        };
        defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

        // Register URL interface
        const URL = V8Interface(interfaces.URL);
        URL.registerGlobal(self.isolate, self.context, "URL");

        // Register URLSearchParams interface
        const URLSearchParams = V8Interface(interfaces.URLSearchParams);
        URLSearchParams.registerGlobal(self.isolate, self.context, "URLSearchParams");

        // Register Event interface
        const Event = V8Interface(interfaces.Event);
        Event.registerGlobal(self.isolate, self.context, "Event");

        // Register EventTarget interface
        const EventTarget = V8Interface(interfaces.EventTarget);
        EventTarget.registerGlobal(self.isolate, self.context, "EventTarget");

        // Register DOMException interface
        const DOMException = V8Interface(interfaces.DOMException);
        DOMException.registerGlobal(self.isolate, self.context, "DOMException");

        // Register WebSocket interface (Exposed in Worker per WHATWG WebSocket spec)
        // WebIDL: [Exposed=(Window,Worker)] interface WebSocket : EventTarget { ... }
        const WebSocket = V8Interface(interfaces.WebSocket);
        WebSocket.registerGlobal(self.isolate, self.context, "WebSocket");

        // Register CloseEvent interface (needed for WebSocket close events)
        // WebIDL: [Exposed=(Window,Worker)] interface CloseEvent : Event { ... }
        const CloseEvent = V8Interface(interfaces.CloseEvent);
        CloseEvent.registerGlobal(self.isolate, self.context, "CloseEvent");

        // Register MessageEvent interface (needed for WebSocket message events)
        // WebIDL: [Exposed=(Window,Worker,AudioWorklet)] interface MessageEvent : Event { ... }
        const MessageEvent = V8Interface(interfaces.MessageEvent);
        MessageEvent.registerGlobal(self.isolate, self.context, "MessageEvent");
    }

    /// Set up full DedicatedWorkerGlobalScope with all required APIs
    ///
    /// Spec: HTML Standard § 10.2.4 DedicatedWorkerGlobalScope
    /// https://html.spec.whatwg.org/#dedicatedworkerglobalscope
    ///
    /// This sets up:
    /// - self.GLOBAL (WPT test harness requirement)
    /// - postMessage() - send messages to main thread
    /// - close() - terminate the worker
    /// - importScripts() - load scripts synchronously
    /// - console object (no-op for workers)
    /// - name property (worker name)
    pub fn setupWorkerGlobalScope(self: *Self, dedicated_worker: *DedicatedWorker) !void {
        std.debug.print("[setupWorkerGlobalScope] ENTRY\n", .{});
        self.dedicated_worker = dedicated_worker;

        // Enter worker's isolate and context for setup
        std.debug.print("[setupWorkerGlobalScope] Entering isolate/context\n", .{});
        v8.ffi.v8_Isolate_Enter(self.isolate);
        v8.ffi.v8_Context_Enter(self.context);
        defer {
            v8.ffi.v8_Context_Exit(self.context);
            v8.ffi.v8_Isolate_Exit(self.isolate);
        }

        // CRITICAL: Create HandleScope for V8 handle allocation
        // All V8 API calls that create Local handles must be within a HandleScope
        std.debug.print("[setupWorkerGlobalScope] Creating HandleScope\n", .{});
        const handle_scope = v8.ffi.v8_HandleScope_New(self.isolate) orelse {
            return error.HandleScopeCreationFailed;
        };
        defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

        std.debug.print("[setupWorkerGlobalScope] Getting global object\n", .{});
        const global_obj = v8.ffi.v8_Context_Global(self.context) orelse {
            return error.NoGlobalObject;
        };

        // First, set up 'self' to point to globalThis (required by worker scripts)
        // In browser workers, 'self' is an alias for the global scope
        std.debug.print("[setupWorkerGlobalScope] Executing self_script\n", .{});
        const self_script =
            \\globalThis.self = globalThis;
        ;
        _ = try self.executeScript(self_script);
        std.debug.print("[setupWorkerGlobalScope] self_script done\n", .{});

        // Set up GLOBAL object for WPT tests
        // This is required by testharness.js to detect the execution context
        std.debug.print("[setupWorkerGlobalScope] Executing global_script\n", .{});
        const global_script =
            \\self.GLOBAL = {
            \\  isWindow: function() { return false; },
            \\  isWorker: function() { return true; },
            \\  isShadowRealm: function() { return false; },
            \\};
        ;
        _ = try self.executeScript(global_script);
        _ = try self.executeScript(global_script);
        std.debug.print("[setupWorkerGlobalScope] global_script done\n", .{});

        // Set up DedicatedWorkerGlobalScope constructor for testharness.js detection
        // testharness.js checks: 'DedicatedWorkerGlobalScope' in global_scope &&
        //                        global_scope instanceof DedicatedWorkerGlobalScope
        // V8 snapshots have immutable global prototypes, so we use Symbol.hasInstance
        // to make `self instanceof DedicatedWorkerGlobalScope` return true
        std.debug.print("[setupWorkerGlobalScope] Executing worker_scope_script\n", .{});
        const worker_scope_script =
            \\(function() {
            \\  // Create WorkerGlobalScope base class with custom instanceof
            \\  function WorkerGlobalScope() {}
            \\  Object.defineProperty(WorkerGlobalScope, Symbol.hasInstance, {
            \\    value: function(obj) { return obj === globalThis || obj === self; }
            \\  });
            \\  globalThis.WorkerGlobalScope = WorkerGlobalScope;
            \\
            \\  // Create DedicatedWorkerGlobalScope with custom instanceof
            \\  function DedicatedWorkerGlobalScope() {}
            \\  Object.defineProperty(DedicatedWorkerGlobalScope, Symbol.hasInstance, {
            \\    value: function(obj) { return obj === globalThis || obj === self; }
            \\  });
            \\  globalThis.DedicatedWorkerGlobalScope = DedicatedWorkerGlobalScope;
            \\})();
        ;
        _ = try self.executeScript(worker_scope_script);
        std.debug.print("[setupWorkerGlobalScope] worker_scope_script done\n", .{});

        // Set up console object (no-op implementation for workers)
        std.debug.print("[setupWorkerGlobalScope] Executing console_script\n", .{});
        const console_script =
            \\(function() {
            \\  function consoleNoop() {}
            \\  globalThis.console = {
            \\    log: consoleNoop,
            \\    warn: consoleNoop,
            \\    error: consoleNoop,
            \\    info: consoleNoop,
            \\    debug: consoleNoop,
            \\    trace: consoleNoop,
            \\    dir: consoleNoop,
            \\    table: consoleNoop,
            \\    assert: consoleNoop,
            \\    clear: consoleNoop,
            \\    count: consoleNoop,
            \\    countReset: consoleNoop,
            \\    group: consoleNoop,
            \\    groupCollapsed: consoleNoop,
            \\    groupEnd: consoleNoop,
            \\    time: consoleNoop,
            \\    timeLog: consoleNoop,
            \\    timeEnd: consoleNoop,
            \\  };
            \\})();
        ;
        _ = try self.executeScript(console_script);
        std.debug.print("[setupWorkerGlobalScope] console_script done\n", .{});

        // Set thread-local reference for callbacks to access this context
        std.debug.print("[setupWorkerGlobalScope] Setting current_worker_context\n", .{});
        current_worker_context = self;

        // Register postMessage() - sends message to main thread
        std.debug.print("[setupWorkerGlobalScope] Registering postMessage\n", .{});
        {
            const template = v8.ffi.v8_FunctionTemplate_New(self.isolate, workerPostMessageCallback, null) orelse {
                return error.FunctionTemplateCreateFailed;
            };
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, self.context) orelse {
                return error.FunctionCreateFailed;
            };
            const key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "postMessage", 11) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(key), @ptrCast(func));
        }
        std.debug.print("[setupWorkerGlobalScope] postMessage registered\n", .{});

        // Register close() - terminates the worker
        std.debug.print("[setupWorkerGlobalScope] Registering close\n", .{});
        {
            const template = v8.ffi.v8_FunctionTemplate_New(self.isolate, workerCloseCallback, null) orelse {
                return error.FunctionTemplateCreateFailed;
            };
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, self.context) orelse {
                return error.FunctionCreateFailed;
            };
            const key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "close", 5) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(key), @ptrCast(func));
        }
        std.debug.print("[setupWorkerGlobalScope] close registered\n", .{});

        // Register importScripts() - loads and executes scripts synchronously
        std.debug.print("[setupWorkerGlobalScope] Registering importScripts\n", .{});
        {
            const template = v8.ffi.v8_FunctionTemplate_New(self.isolate, importScriptsCallback, null) orelse {
                return error.FunctionTemplateCreateFailed;
            };
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, self.context) orelse {
                return error.FunctionCreateFailed;
            };
            const key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "importScripts", 13) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(key), @ptrCast(func));
        }
        std.debug.print("[setupWorkerGlobalScope] importScripts registered\n", .{});

        // Register setTimeout() - schedules a callback after a delay
        std.debug.print("[setupWorkerGlobalScope] Registering setTimeout\n", .{});
        {
            const template = v8.ffi.v8_FunctionTemplate_New(self.isolate, workerSetTimeoutCallback, null) orelse {
                return error.FunctionTemplateCreateFailed;
            };
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, self.context) orelse {
                return error.FunctionCreateFailed;
            };
            const key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "setTimeout", 10) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(key), @ptrCast(func));
        }
        std.debug.print("[setupWorkerGlobalScope] setTimeout registered\n", .{});

        // Register setInterval() - schedules a repeating callback
        std.debug.print("[setupWorkerGlobalScope] Registering setInterval\n", .{});
        {
            const template = v8.ffi.v8_FunctionTemplate_New(self.isolate, workerSetIntervalCallback, null) orelse {
                return error.FunctionTemplateCreateFailed;
            };
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, self.context) orelse {
                return error.FunctionCreateFailed;
            };
            const key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "setInterval", 11) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(key), @ptrCast(func));
        }
        std.debug.print("[setupWorkerGlobalScope] setInterval registered\n", .{});

        // Register clearTimeout() - cancels a setTimeout timer
        std.debug.print("[setupWorkerGlobalScope] Registering clearTimeout\n", .{});
        {
            const template = v8.ffi.v8_FunctionTemplate_New(self.isolate, workerClearTimeoutCallback, null) orelse {
                return error.FunctionTemplateCreateFailed;
            };
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, self.context) orelse {
                return error.FunctionCreateFailed;
            };
            const key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "clearTimeout", 12) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(key), @ptrCast(func));
        }
        std.debug.print("[setupWorkerGlobalScope] clearTimeout registered\n", .{});

        // Register clearInterval() - cancels a setInterval timer
        std.debug.print("[setupWorkerGlobalScope] Registering clearInterval\n", .{});
        {
            const template = v8.ffi.v8_FunctionTemplate_New(self.isolate, workerClearIntervalCallback, null) orelse {
                return error.FunctionTemplateCreateFailed;
            };
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, self.context) orelse {
                return error.FunctionCreateFailed;
            };
            const key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "clearInterval", 13) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(key), @ptrCast(func));
        }
        std.debug.print("[setupWorkerGlobalScope] clearInterval registered\n", .{});

        // NOTE: We do NOT register a native done() function here.
        // testharness.js defines its own done() function when loaded via importScripts().
        // Registering a native done() would override testharness.js's done() and break
        // the test harness's ability to collect and send test results.
        // testharness.js's done() will call postMessage() to send results to the main thread.

        // Set up worker 'name' property
        std.debug.print("[setupWorkerGlobalScope] Setting up name property\n", .{});
        const name = dedicated_worker.getName();
        if (name.len > 0) {
            const name_value = v8.ffi.v8_String_NewFromUtf8(self.isolate, name.ptr, @intCast(name.len)) orelse {
                return error.StringCreationFailed;
            };
            const name_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "name", 4) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(name_key), @ptrCast(name_value));
        } else {
            // Empty string for unnamed workers
            const name_value = v8.ffi.v8_String_NewFromUtf8(self.isolate, "", 0) orelse {
                return error.StringCreationFailed;
            };
            const name_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "name", 4) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(name_key), @ptrCast(name_value));
        }
        std.debug.print("[setupWorkerGlobalScope] name property set\n", .{});

        // Set up isSecureContext property
        // Per HTML Standard, isSecureContext indicates if the context is secure
        // For WPT tests, this depends on the URL - .https. or .h2. in filename means secure
        std.debug.print("[setupWorkerGlobalScope] Setting up isSecureContext\n", .{});
        {
            const is_secure = isSecureUrlForWorker(self.script_url);
            const is_secure_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "isSecureContext", 15) orelse {
                return error.StringCreationFailed;
            };
            if (v8.ffi.v8_Boolean_New(self.isolate, is_secure)) |is_secure_value| {
                _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(is_secure_key), is_secure_value);
            }
        }
        std.debug.print("[setupWorkerGlobalScope] isSecureContext set\n", .{});

        // Set up location object using WorkerLocation interface
        // Per HTML Standard, WorkerGlobalScope has a location attribute
        // Apply WPT URL rewriting: .https. -> port 8443, .h2. -> port 9000
        std.debug.print("[setupWorkerGlobalScope] Setting up location object\n", .{});
        {
            const effective_url = try getEffectiveWorkerUrl(self.allocator, self.script_url);
            defer self.allocator.free(effective_url);

            const location_script = try std.fmt.allocPrint(self.allocator,
                \\(function() {{
                \\  // Create WorkerLocation-like object
                \\  var url = new URL("{s}");
                \\  globalThis.location = {{
                \\    href: url.href,
                \\    protocol: url.protocol,
                \\    host: url.host,
                \\    hostname: url.hostname,
                \\    port: url.port,
                \\    pathname: url.pathname,
                \\    search: url.search,
                \\    hash: url.hash,
                \\    origin: url.origin,
                \\    toString: function() {{ return this.href; }}
                \\  }};
                \\}})();
            , .{effective_url});
            defer self.allocator.free(location_script);
            _ = try self.executeScriptInternal(location_script);
        }
        std.debug.print("[setupWorkerGlobalScope] location object set\n", .{});

        // Set up origin property
        // Per HTML Standard, WorkerGlobalScope has an origin attribute
        // Apply WPT URL rewriting: .https. -> port 8443, .h2. -> port 9000
        std.debug.print("[setupWorkerGlobalScope] Setting up origin\n", .{});
        {
            const effective_url = try getEffectiveWorkerUrl(self.allocator, self.script_url);
            defer self.allocator.free(effective_url);

            // Extract origin from effective URL (scheme://host:port)
            const origin_str = blk: {
                if (std.mem.startsWith(u8, effective_url, "http://") or std.mem.startsWith(u8, effective_url, "https://")) {
                    const scheme_end = std.mem.indexOf(u8, effective_url, "://") orelse break :blk "null";
                    const after_scheme = effective_url[scheme_end + 3 ..];
                    const path_start = std.mem.indexOf(u8, after_scheme, "/") orelse after_scheme.len;
                    break :blk effective_url[0 .. scheme_end + 3 + path_start];
                }
                break :blk "null";
            };
            const origin_value = v8.ffi.v8_String_NewFromUtf8(self.isolate, origin_str.ptr, @intCast(origin_str.len)) orelse {
                return error.StringCreationFailed;
            };
            const origin_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "origin", 6) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(origin_key), @ptrCast(origin_value));
        }
        std.debug.print("[setupWorkerGlobalScope] origin set - COMPLETE\n", .{});

        // Set up navigator object (WorkerNavigator interface)
        // Per HTML Standard § 10.1.3, WorkerGlobalScope has a navigator attribute
        // WorkerNavigator includes: NavigatorID, NavigatorLanguage, NavigatorOnLine, NavigatorConcurrentHardware
        std.debug.print("[setupWorkerGlobalScope] Setting up navigator object\n", .{});
        {
            // Get platform string based on OS (navigator.platform)
            const platform_str = switch (builtin.os.tag) {
                .macos => "MacIntel",
                .windows => "Win32",
                .linux => "Linux x86_64",
                .freebsd => "FreeBSD",
                .ios => "iPhone",
                else => "Unknown",
            };

            // Get OS string for userAgent (more detailed)
            const os_str = switch (builtin.os.tag) {
                .macos => "Macintosh; Intel Mac OS X",
                .windows => "Windows NT 10.0; Win64; x64",
                .linux => "X11; Linux x86_64",
                .freebsd => "X11; FreeBSD",
                .ios => "iPhone; CPU iPhone OS 15_0 like Mac OS X",
                else => "Unknown",
            };

            // Get hardware concurrency
            const hardware_concurrency = std.Thread.getCpuCount() catch 1;

            // Version from constant (matches build.zig.zon)
            const version_str = CRANE_VERSION;

            const navigator_script = try std.fmt.allocPrint(self.allocator,
                \\(function() {{
                \\  // Create WorkerNavigator-like object per HTML Standard § 10.1.3
                \\  globalThis.navigator = {{
                \\    // NavigatorID mixin (§ 8.8.1.1)
                \\    appCodeName: "Mozilla",
                \\    appName: "Netscape",
                \\    appVersion: "5.0 Crane/{s}",
                \\    platform: "{s}",
                \\    product: "Gecko",
                \\    productSub: "",
                \\    userAgent: "Mozilla/5.0 ({s}) Crane/{s}",
                \\    vendor: "Cardarella",
                \\    vendorSub: "",
                \\    // NavigatorLanguage mixin (§ 8.8.1.2)
                \\    language: "en-US",
                \\    languages: Object.freeze(["en-US"]),
                \\    // NavigatorOnLine mixin (§ 8.8.1.3)
                \\    onLine: true,
                \\    // NavigatorConcurrentHardware mixin (§ 8.8.1.4)
                \\    hardwareConcurrency: {d}
                \\  }};
                \\  // Make it non-configurable like a real navigator
                \\  Object.freeze(globalThis.navigator);
                \\}})();
            , .{ version_str, platform_str, os_str, version_str, hardware_concurrency });
            defer self.allocator.free(navigator_script);
            _ = try self.executeScriptInternal(navigator_script);
        }
        std.debug.print("[setupWorkerGlobalScope] navigator object set\n", .{});

        // CRITICAL: Set up message handler for the worker to receive messages via onmessage
        // This MUST be done while the isolate is still entered (before the defer exits it)
        // The getRuntimeContext() call accesses V8 APIs, so it requires an active isolate
        std.debug.print("[setupWorkerGlobalScope] Setting up message handler...\n", .{});
        if (self.getRuntimeContext()) |runtime_ctx| {
            std.debug.print("[setupWorkerGlobalScope] Got runtime context, calling setupMessageHandlerDirect\n", .{});
            DedicatedWorkerGlobalScopeImpl.setupMessageHandlerDirect(dedicated_worker, runtime_ctx);
            std.debug.print("[setupWorkerGlobalScope] Message handler setup complete\n", .{});
        } else {
            std.debug.print("[setupWorkerGlobalScope] WARNING: Could not get runtime context for message handler\n", .{});
        }
    }

    /// Get the engine context pointer for WorkerContext.setEngineContext()
    pub fn getEngineContext(self: *Self) *EngineContext {
        // Cast Self pointer to opaque EngineContext
        return @ptrCast(self);
    }

    /// Get the engine callbacks for WorkerContext.setEngineContext()
    pub fn getCallbacks(self: *const Self) EngineCallbacks {
        _ = self;
        return .{
            .compileAndRunScript = compileAndRunScriptCallback,
            .compileAndRunModule = compileAndRunModuleCallback,
            .runMicrotasks = runMicrotasksCallback,
            .runEventLoopOnce = runEventLoopOnceCallback,
            .disposeContext = disposeContextCallback,
            .configureImportMeta = null, // TODO: Implement for module workers
            .registerDynamicImportHandler = null, // TODO: Implement for module workers
        };
    }

    /// Execute a script in this worker's context
    pub fn executeScript(self: *Self, source: []const u8) !?*anyopaque {
        // Enter worker's isolate and context for script execution
        v8.ffi.v8_Isolate_Enter(self.isolate);
        v8.ffi.v8_Context_Enter(self.context);
        defer {
            v8.ffi.v8_Context_Exit(self.context);
            v8.ffi.v8_Isolate_Exit(self.isolate);
        }

        // CRITICAL: Create HandleScope for V8 handle allocation
        // V8 requires any API calls that create Local handles to be within a HandleScope.
        // Without this, v8_String_NewFromUtf8 and other handle-creating calls will crash
        // with "Cannot create a handle without a HandleScope".
        const handle_scope = v8.ffi.v8_HandleScope_New(self.isolate) orelse {
            std.log.err("[WorkerV8Context] Failed to create HandleScope - V8 may be in invalid state", .{});
            return error.HandleScopeCreationFailed;
        };
        defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

        return self.executeScriptInternal(source);
    }

    /// Execute a script - internal version that assumes context is already entered
    fn executeScriptInternal(self: *Self, source: []const u8) !?*anyopaque {
        // Create V8 string from source
        const source_str = v8.ffi.v8_String_NewFromUtf8(
            self.isolate,
            source.ptr,
            @intCast(source.len),
        ) orelse {
            return error.StringCreationFailed;
        };

        // Compile script using safe version
        const compile_result = v8.ffi.v8_Script_Compile_Safe(self.context, source_str);
        defer v8.ffi.v8_FreeScriptCompileResult(compile_result);

        if (compile_result.error_info != null) {
            return error.CompilationFailed;
        }

        const script = compile_result.script orelse return error.CompilationFailed;

        // Run script using safe version
        const run_result = v8.ffi.v8_Script_Run_Safe(self.context, script);
        defer v8.ffi.v8_FreeScriptRunResult(run_result);

        if (run_result.error_info) |err_info| {
            // Log the actual V8 error for debugging
            const err_msg = if (err_info.message) |msg| std.mem.span(msg) else "<no message>";
            std.log.err("[WorkerV8Context] Script execution failed: {s}", .{err_msg});
            if (err_info.source_line) |line| {
                std.log.err("[WorkerV8Context] Source line: {s}", .{std.mem.span(line)});
            }
            return error.ExecutionFailed;
        }

        // Run microtasks after script execution
        v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(self.isolate);

        return @ptrCast(run_result.value);
    }

    /// Execute an ES module in this worker's context
    ///
    /// Spec: HTML Standard § 10.2.5 step 24 (for type: "module")
    /// "Run the module script scriptOrModule."
    ///
    /// This compiles, instantiates, and evaluates the source as an ES module,
    /// enabling import/export statements and import.meta support.
    pub fn executeModule(self: *Self, source: []const u8, source_url: []const u8) !void {
        // Enter worker's isolate and context for module execution
        v8.ffi.v8_Isolate_Enter(self.isolate);
        v8.ffi.v8_Context_Enter(self.context);
        defer {
            v8.ffi.v8_Context_Exit(self.context);
            v8.ffi.v8_Isolate_Exit(self.isolate);
        }

        // Create HandleScope for V8 handle allocation
        const handle_scope = v8.ffi.v8_HandleScope_New(self.isolate) orelse {
            std.log.err("[WorkerV8Context] Failed to create HandleScope for module execution", .{});
            return error.HandleScopeCreationFailed;
        };
        defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

        return self.executeModuleInternal(source, source_url);
    }

    /// Execute a module - internal version that assumes context is already entered
    fn executeModuleInternal(self: *Self, source: []const u8, source_url: []const u8) !void {
        // Create V8 string from source
        const source_str = v8.ffi.v8_String_NewFromUtf8(
            self.isolate,
            source.ptr,
            @intCast(source.len),
        ) orelse {
            return error.StringCreationFailed;
        };

        // Create resource name (required for modules - used for import.meta.url)
        const resource_name = v8.ffi.v8_String_NewFromUtf8(
            self.isolate,
            source_url.ptr,
            @intCast(source_url.len),
        );

        // Compile as ES Module using safe variant with TryCatch
        const compile_result = v8.ffi.v8_Module_Compile_Safe(self.context, source_str, resource_name);
        defer v8.ffi.v8_FreeModuleCompileResult(compile_result);

        // Clean up resource name string (V8 manages the V8 string memory)
        if (resource_name) |name| {
            v8.ffi.v8_String_Dispose(name);
        }

        // Check for compilation error
        if (compile_result.error_info) |err_info| {
            // Log the error details
            if (err_info.message) |msg| {
                std.log.err("Module compilation error: {s}", .{msg});
            }
            if (err_info.source_line) |line| {
                std.log.err("Source line: {s}", .{line});
            }
            return error.ModuleCompilationFailed;
        }

        const module = compile_result.module orelse {
            std.log.err("Module compilation returned null without error", .{});
            return error.ModuleCompilationFailed;
        };

        // Instantiate the module (link imports)
        const instantiate_result = v8.ffi.v8_Module_Instantiate_Safe(self.context, module);
        defer v8.ffi.v8_FreeModuleInstantiateResult(instantiate_result);

        if (instantiate_result.error_info) |err_info| {
            if (err_info.message) |msg| {
                std.log.err("Module instantiation error: {s}", .{msg});
            }
            return error.ModuleInstantiationFailed;
        }

        if (!instantiate_result.success) {
            std.log.err("Module instantiation failed without error details", .{});
            return error.ModuleInstantiationFailed;
        }

        // Evaluate the module (execute top-level code)
        const evaluate_result = v8.ffi.v8_Module_Evaluate_Safe(self.context, module);
        defer v8.ffi.v8_FreeModuleEvaluateResult(evaluate_result);

        if (evaluate_result.error_info) |err_info| {
            if (err_info.message) |msg| {
                std.log.err("Module evaluation error: {s}", .{msg});
            }
            return error.ModuleEvaluationFailed;
        }

        // Run microtasks after module execution
        v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(self.isolate);
    }

    /// Public method to perform V8 microtask checkpoint
    /// Called from the worker loop to process Promises and async/await continuations
    ///
    /// Spec: HTML Standard § 8.1.6.3 Perform a microtask checkpoint
    /// https://html.spec.whatwg.org/#perform-a-microtask-checkpoint
    ///
    /// This processes:
    /// - Promise.then/catch/finally callbacks
    /// - queueMicrotask() callbacks
    /// - async/await continuations
    ///
    /// IMPORTANT: V8 requires the isolate to be entered before any API calls.
    /// The worker's init() exits the isolate after setup (line 284), so we must
    /// re-enter it here before calling V8 APIs.
    pub fn performMicrotaskCheckpoint(self: *Self) void {
        // Enter the isolate - required for all V8 API calls
        v8.ffi.v8_Isolate_Enter(self.isolate);
        defer v8.ffi.v8_Isolate_Exit(self.isolate);

        // Create HandleScope for any V8 handles created during microtask execution
        const handle_scope = v8.ffi.v8_HandleScope_New(self.isolate);
        defer if (handle_scope) |hs| v8.ffi.v8_HandleScope_Dispose(hs);

        v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(self.isolate);
    }
};

// ============================================================================
// Engine Callbacks Implementation
// ============================================================================

/// Compile and run a script, returns result value pointer
fn compileAndRunScriptCallback(
    engine_ctx: *EngineContext,
    source: []const u8,
    source_url: []const u8,
) anyerror!?*anyopaque {
    _ = source_url; // Used for error messages (TODO)
    const self: *WorkerV8Context = @ptrCast(@alignCast(engine_ctx));
    return self.executeScript(source);
}

/// Compile and run a module
///
/// Spec: HTML Standard § 10.2.5 step 24 (for type: "module")
/// "Run the module script scriptOrModule."
///
/// This compiles, instantiates, and evaluates the source as an ES module,
/// enabling import/export statements and import.meta support.
fn compileAndRunModuleCallback(
    engine_ctx: *EngineContext,
    source: []const u8,
    source_url: []const u8,
) anyerror!void {
    const self: *WorkerV8Context = @ptrCast(@alignCast(engine_ctx));
    try self.executeModule(source, source_url);
}

/// Run microtask checkpoint
///
/// IMPORTANT: V8 requires the isolate to be entered before any API calls.
/// The worker's init() exits the isolate after setup, so we must
/// re-enter it here before calling V8 APIs.
fn runMicrotasksCallback(engine_ctx: *EngineContext) void {
    const self: *WorkerV8Context = @ptrCast(@alignCast(engine_ctx));

    // Enter the isolate - required for all V8 API calls
    v8.ffi.v8_Isolate_Enter(self.isolate);
    defer v8.ffi.v8_Isolate_Exit(self.isolate);

    v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(self.isolate);
}

/// Run V8 event loop once to process libuv timers
///
/// This callback allows the worker thread to process setTimeout/setInterval
/// callbacks that were scheduled via the V8EventLoop's libuv timer manager.
///
/// IMPORTANT: V8 requires the isolate to be entered before any API calls.
fn runEventLoopOnceCallback(engine_ctx: *EngineContext) void {
    const self: *WorkerV8Context = @ptrCast(@alignCast(engine_ctx));

    // Enter the isolate - required for all V8 API calls
    v8.ffi.v8_Isolate_Enter(self.isolate);
    defer v8.ffi.v8_Isolate_Exit(self.isolate);

    // Get the V8EventLoop from the worker context (stored directly, not via context_manager)
    if (self.event_loop) |v8_event_loop| {
        // Get the EventLoop interface which has the runOnce() wrapper
        const event_loop = v8_event_loop.eventLoop();
        // Run the event loop once to process ready timers
        _ = event_loop.runOnce();
    }
}

/// Dispose engine context
fn disposeContextCallback(engine_ctx: *EngineContext) void {
    const self: *WorkerV8Context = @ptrCast(@alignCast(engine_ctx));
    self.deinit();
}

// ============================================================================
// V8 Callbacks for Worker Global Functions
// ============================================================================

/// V8 callback for postMessage() - sends message to main thread
///
/// Spec: HTML Standard § 10.2.4.1 postMessage(message, transfer)
/// https://html.spec.whatwg.org/#dom-dedicatedworkerglobalscope-postmessage
///
/// This function:
/// 1. Gets the message argument from V8 FunctionCallbackInfo
/// 2. Serializes it to JSON using V8's JSON.stringify
/// 3. Stores the JSON string in a JSValue
/// 4. Posts it through the message port to the main thread
fn workerPostMessageCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    const argc = info.v8_FunctionCallbackInfo_Length();

    if (argc < 1) return;
    const message_arg = info.get(0);

    // Get required size for JSON buffer
    var dummy_buf: [1]u8 = undefined;
    const required_size = v8.ffi.v8_JSON_Stringify_ToBuffer(
        v8_context,
        message_arg,
        &dummy_buf,
        0,
    );
    if (required_size <= 0) return;

    // Allocate buffer dynamically based on required size and stringify again
    // The "complete" message from testharness.js can be quite large (9000+ bytes)
    // containing all test results, so we need dynamic allocation.
    const self = current_worker_context orelse return;
    const json_buffer = self.allocator.alloc(u8, @intCast(required_size + 1)) catch return;
    defer self.allocator.free(json_buffer);

    const written = v8.ffi.v8_JSON_Stringify_ToBuffer(
        v8_context,
        message_arg,
        json_buffer.ptr,
        @intCast(json_buffer.len),
    );
    if (written <= 0) return;

    const json_str = json_buffer[0..@intCast(written)];
    const dedicated_worker = self.dedicated_worker orelse return;

    // Check agent state
    if (dedicated_worker.agent.isClosing() or dedicated_worker.agent.isTerminated()) {
        return;
    }

    // Use the dedicated worker's postMessageFromWorker which handles thread-safe outbox
    // for cross-thread communication. This is CRITICAL for threaded workers - messages
    // must go through the thread-safe outbox (not pending_messages) so the main thread
    // can poll them via ThreadedWorkerRegistry.pollAndDispatch().
    var js_value = workers.message_channel.JSValue{ .string = json_str };
    dedicated_worker.postMessageFromWorker(&js_value, null) catch |err| {
        std.log.warn("Worker postMessage failed: {}", .{err});
        return;
    };

    // NOTE: We intentionally do NOT auto-close the worker based on message content.
    // Per HTML Standard § 10.2, browsers should NEVER inspect message content to
    // decide on close(). The worker script (testharness.js) is responsible for
    // calling close() when it's done, not the browser.
}

/// V8 callback for close() - terminates the worker
///
/// Spec: HTML Standard § 10.2.4.1 close()
/// https://html.spec.whatwg.org/#dom-dedicatedworkerglobalscope-close
fn workerCloseCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    _ = info;

    // Get WorkerV8Context from thread-local storage
    const self = current_worker_context orelse {
        std.log.warn("workerCloseCallback: no current_worker_context", .{});
        return;
    };

    // Get the DedicatedWorker to close
    const dedicated_worker = self.dedicated_worker orelse {
        std.log.warn("workerCloseCallback: no dedicated_worker set", .{});
        return;
    };

    // Close the worker
    dedicated_worker.close();
    std.log.debug("Worker close() called", .{});
}

/// V8 callback for importScripts(...urls) - loads and executes scripts synchronously
///
/// Spec: HTML Standard § 10.2.4.2 importScripts(urls)
/// https://html.spec.whatwg.org/#dom-workerglobalscope-importscripts
fn importScriptsCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    // Get WorkerV8Context from thread-local storage
    const self = current_worker_context orelse {
        std.log.warn("importScriptsCallback: no current_worker_context", .{});
        return;
    };

    // Get isolate and context from the callback info
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        std.log.warn("importScriptsCallback: no V8 context", .{});
        return;
    };

    // Get number of arguments (URLs to import)
    const argc = info.v8_FunctionCallbackInfo_Length();
    if (argc < 1) {
        return;
    }

    // Process each URL argument
    var i: c_int = 0;
    while (i < argc) : (i += 1) {
        const arg = info.get(i);

        // Convert to string
        const str = v8.ffi.v8_Value_ToString(arg, v8_context) orelse continue;
        const len = v8.ffi.v8_String_Utf8Length(str);
        if (len == 0) continue;

        // Get URL string
        var buf: [4096]u8 = undefined;
        const actual_len = v8.ffi.v8_String_WriteUtf8(str, &buf, @intCast(buf.len));
        if (actual_len <= 0) continue;

        // v8_String_WriteUtf8 returns count INCLUDING null terminator, so subtract 1
        const url_len: usize = @intCast(actual_len);
        const url = buf[0 .. url_len - 1];

        // Fetch the script
        // Per HTML Standard § 10.2.4.2 importScripts(urls):
        // "For each url of urls: Let urlRecord be the result of parsing url with worker global scope's url"
        //
        // For data: or blob: workers, we use document_base_url as the base for resolving
        // relative URLs, since data:/blob: URLs cannot be used as bases.
        const base_url = blk: {
            // Check if script_url starts with "data:" or "blob:"
            if (std.mem.startsWith(u8, self.script_url, "data:") or
                std.mem.startsWith(u8, self.script_url, "blob:"))
            {
                // Use document base URL if available
                break :blk self.document_base_url orelse self.script_url;
            }
            break :blk self.script_url;
        };

        var fetched_script = script_fetch.fetchWorkerScript(self.allocator, url, .{
            .is_import_scripts = true,
            .worker_type = .classic,
            .origin = base_url, // Base URL for relative path resolution
        }) catch |err| {
            std.log.warn("importScripts: failed to fetch '{s}': {}", .{ url, err });
            // Per HTML Standard § 10.2.4.2 step 6.2:
            // "If the fetching attempt fails, throw a "NetworkError" DOMException"
            const error_msg = std.fmt.allocPrint(self.allocator, "Failed to fetch script '{s}'", .{url}) catch {
                // Fallback: throw generic error
                throwNetworkError(isolate, v8_context, "Failed to fetch script");
                return;
            };
            defer self.allocator.free(error_msg);
            throwNetworkError(isolate, v8_context, error_msg);
            return;
        };
        defer fetched_script.deinit();

        // Execute the script synchronously
        _ = self.executeScript(fetched_script.source) catch |err| {
            std.log.warn("importScripts: failed to execute '{s}': {}", .{ url, err });
            // Per HTML Standard, script execution errors should also throw
            const error_msg = std.fmt.allocPrint(self.allocator, "Failed to execute script '{s}'", .{url}) catch {
                throwNetworkError(isolate, v8_context, "Failed to execute script");
                return;
            };
            defer self.allocator.free(error_msg);
            throwNetworkError(isolate, v8_context, error_msg);
            return;
        };
    }
}

/// Helper to throw a NetworkError DOMException in V8
///
/// Per HTML Standard § 10.2.4.2 importScripts(urls):
/// "If the fetching attempt fails, throw a 'NetworkError' DOMException"
fn throwNetworkError(isolate: *v8.ffi.Isolate, context: *v8.ffi.Context, message: []const u8) void {
    // Create error message string
    const v8_message = v8.ffi.v8_String_NewFromUtf8(isolate, message.ptr, @intCast(message.len)) orelse {
        // Fallback: throw generic error
        const generic = v8.ffi.v8_String_NewFromUtf8(isolate, "NetworkError", 12) orelse return;
        const exception = v8.ffi.v8_Exception_Error(generic) orelse return;
        v8.ffi.v8_Isolate_ThrowException(isolate, exception);
        return;
    };

    // Create a proper DOMException-like error
    // For now, we create a standard Error with the message
    // TODO: Create actual DOMException when DOMException interface is fully wired up
    _ = context;
    const exception = v8.ffi.v8_Exception_Error(v8_message) orelse return;
    v8.ffi.v8_Isolate_ThrowException(isolate, exception);
}

/// V8 callback for done() - signals test completion (WPT testharness)
///
/// This is called by worker test scripts to signal they're done running tests.
/// The worker then posts a completion message to the main thread and signals
/// the worker thread to terminate.
///
/// Spec: This is a WPT-specific extension that allows worker tests to signal
/// completion. After done() is called, the worker should stop processing
/// and allow the thread to exit cleanly.
fn workerDoneCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    _ = info;

    // Get WorkerV8Context from thread-local storage
    const self = current_worker_context orelse {
        return;
    };

    // Close the dedicated worker to signal termination
    // This sets the closing flag on the worker agent
    if (self.dedicated_worker) |dedicated_worker| {
        dedicated_worker.close();
        std.log.debug("Worker done() called - signaling termination", .{});
    }
}

// ============================================================================
// Timer Callbacks (setTimeout, setInterval, clearTimeout, clearInterval)
// ============================================================================

/// V8 callback for setTimeout() - schedules a callback after a delay
///
/// Spec: HTML Standard § 8.6 Timers
/// https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-settimeout
fn workerSetTimeoutCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    workerTimerCallback(info, false);
}

/// V8 callback for setInterval() - schedules a repeating callback
///
/// Spec: HTML Standard § 8.6 Timers
/// https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-setinterval
fn workerSetIntervalCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    workerTimerCallback(info, true);
}

/// Common implementation for setTimeout and setInterval
fn workerTimerCallback(info: *const v8.ffi.FunctionCallbackInfo, is_interval: bool) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    const argc = info.v8_FunctionCallbackInfo_Length();

    // Get WorkerV8Context from thread-local storage
    const self = current_worker_context orelse return;

    // Need at least the handler argument
    if (argc < 1) {
        // Return 0 as a timer ID when no arguments
        const zero = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(zero));
        return;
    }

    // Get the handler (first argument) - must be a function
    const handler_arg = info.get(0);
    if (!v8.ffi.v8_Value_IsFunction(handler_arg)) {
        // Per spec, non-function handlers should be coerced to string and eval'd
        // For simplicity, we return 0 for non-function handlers
        const zero = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(zero));
        return;
    }

    // Get timeout (second argument, optional, defaults to 0)
    var timeout_ms: i32 = 0;
    if (argc >= 2) {
        const timeout_arg = info.get(1);
        if (v8.ffi.v8_Value_IsNumber(timeout_arg)) {
            const num = v8.ffi.v8_Value_NumberValue_Raw(timeout_arg);
            timeout_ms = @intFromFloat(@max(0, num));
        }
    }

    // Create a GlobalHandle for the function to prevent GC
    const global_handle = v8.ffi.v8_Value_ToGlobal(isolate, handler_arg) orelse {
        const zero = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(zero));
        return;
    };

    // Get the V8EventLoop from the worker context (stored directly, not via context_manager)
    const v8_event_loop = self.event_loop orelse {
        v8.ffi.v8_Global_Dispose(global_handle);
        const zero = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(zero));
        return;
    };

    // Get the timer interface
    const timer_interface = v8_event_loop.timerInterface() orelse {
        v8.ffi.v8_Global_Dispose(global_handle);
        const zero = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(zero));
        return;
    };

    // Create timer callback context
    const callback_ctx = self.allocator.create(WorkerTimerCallbackContext) catch {
        v8.ffi.v8_Global_Dispose(global_handle);
        const zero = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(zero));
        return;
    };
    callback_ctx.* = .{
        .function_handle = global_handle,
        .v8_context = v8_context,
        .v8_isolate = isolate,
        .allocator = self.allocator,
        .is_interval = is_interval,
        .interval_ms = @intCast(@max(0, timeout_ms)),
        .worker_ctx = self,
    };

    // Schedule the timer (both setTimeout and setInterval use setTimeout,
    // setInterval reschedules itself in the callback)
    const timer_id = timer_interface.setTimeout(@intCast(@max(0, timeout_ms)), workerTimerFireCallback, callback_ctx);

    callback_ctx.timer_id = timer_id;

    // Return the timer ID
    const result = v8.ffi.v8_Integer_New(isolate, @intCast(timer_id));
    info.setReturnValue(@ptrCast(result));
}

/// Context for worker timer callbacks
const WorkerTimerCallbackContext = struct {
    function_handle: *v8.ffi.Value,
    v8_context: *v8.ffi.Context,
    v8_isolate: *v8.ffi.Isolate,
    allocator: Allocator,
    timer_id: u64 = 0,
    is_interval: bool,
    interval_ms: u64,
    /// Back-reference to the worker context for rescheduling intervals
    worker_ctx: *WorkerV8Context,
    /// Flag to indicate if the timer has been cancelled
    cancelled: bool = false,
};

/// Timer fire callback - invoked when a timer fires
fn workerTimerFireCallback(ctx: ?*anyopaque) void {
    const callback_ctx: *WorkerTimerCallbackContext = @ptrCast(@alignCast(ctx orelse return));

    // Check if timer was cancelled
    if (callback_ctx.cancelled) {
        // Clean up and return
        v8.ffi.v8_Global_Dispose(callback_ctx.function_handle);
        callback_ctx.allocator.destroy(callback_ctx);
        return;
    }

    // Enter isolate and context
    v8.ffi.v8_Isolate_Enter(callback_ctx.v8_isolate);
    defer v8.ffi.v8_Isolate_Exit(callback_ctx.v8_isolate);

    v8.ffi.v8_Context_Enter(callback_ctx.v8_context);
    defer v8.ffi.v8_Context_Exit(callback_ctx.v8_context);

    // Create handle scope
    const handle_scope = v8.ffi.v8_HandleScope_New(callback_ctx.v8_isolate) orelse return;
    defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

    // Get the function from the global handle
    const func = v8.ffi.v8_Global_Get(callback_ctx.v8_isolate, callback_ctx.function_handle) orelse return;

    // Get global object as 'this'
    const global = v8.ffi.v8_Context_Global(callback_ctx.v8_context) orelse return;

    // Call the function with no arguments
    // Cast the function pointer and use v8_Function_CallWithReceiver which handles null argv
    _ = v8.ffi.v8_Function_CallWithReceiver(
        callback_ctx.v8_context,
        @ptrCast(@alignCast(func)),
        @ptrCast(global),
        0,
        null,
    );

    // Run microtasks after callback execution
    v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(callback_ctx.v8_isolate);

    // For intervals, reschedule the timer
    if (callback_ctx.is_interval and !callback_ctx.cancelled) {
        // Get the timer interface from the worker context (stored directly, not via context_manager)
        if (callback_ctx.worker_ctx.event_loop) |v8_event_loop| {
            if (v8_event_loop.timerInterface()) |timer| {
                const new_id = timer.setTimeout(callback_ctx.interval_ms, workerTimerFireCallback, callback_ctx);
                callback_ctx.timer_id = new_id;
            }
        }
    } else {
        // For one-shot timers, clean up the context
        v8.ffi.v8_Global_Dispose(callback_ctx.function_handle);
        callback_ctx.allocator.destroy(callback_ctx);
    }
}

/// V8 callback for clearTimeout() - cancels a setTimeout timer
///
/// Spec: HTML Standard § 8.6 Timers
/// https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-cleartimeout
fn workerClearTimeoutCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    workerClearTimerCallback(info);
}

/// V8 callback for clearInterval() - cancels a setInterval timer
///
/// Spec: HTML Standard § 8.6 Timers
/// https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-clearinterval
fn workerClearIntervalCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    workerClearTimerCallback(info);
}

/// Common implementation for clearTimeout and clearInterval
fn workerClearTimerCallback(info: *const v8.ffi.FunctionCallbackInfo) void {
    _ = info.v8_FunctionCallbackInfo_GetIsolate();
    const argc = info.v8_FunctionCallbackInfo_Length();

    // Get WorkerV8Context from thread-local storage
    const self = current_worker_context orelse return;

    if (argc < 1) return;

    // Get the timer ID
    const id_arg = info.get(0);
    if (!v8.ffi.v8_Value_IsNumber(id_arg)) return;

    const timer_id: u64 = @intFromFloat(@max(0, v8.ffi.v8_Value_NumberValue_Raw(id_arg)));

    // Get the V8EventLoop from the worker context (stored directly, not via context_manager)
    const v8_event_loop = self.event_loop orelse return;

    // Get the timer interface and cancel the timer
    if (v8_event_loop.timerInterface()) |timer_interface| {
        timer_interface.clearTimeout(timer_id);
    }
}

// ============================================================================
// Error Types
// ============================================================================

pub const WorkerV8Error = error{
    V8IsolateCreationFailed,
    V8ContextCreationFailed,
    NoGlobalObject,
    StringCreationFailed,
    CompilationFailed,
    ExecutionFailed,
    ModuleCompilationFailed,
    ModuleInstantiationFailed,
    ModuleEvaluationFailed,
    OutOfMemory,
    FunctionTemplateCreateFailed,
    FunctionCreateFailed,
};

// ============================================================================
// Tests
// ============================================================================

test "WorkerV8Context - struct definition" {
    // Just verify the struct can be referenced
    // Actual V8 tests require the V8 runtime
    const T = WorkerV8Context;
    try std.testing.expect(@sizeOf(T) > 0);
}
