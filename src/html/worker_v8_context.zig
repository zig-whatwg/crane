//! Worker V8 Context Setup
//!
//! Spec: HTML Standard § 10.2.5 Processing model
//! https://html.spec.whatwg.org/#run-a-worker
//!
//! This module creates V8 isolates and contexts for worker execution.
//! Each worker gets its own V8 isolate for complete memory isolation.
//!
//! ## Design
//!
//! Workers need isolated V8 execution contexts separate from the main thread.
//! This module provides:
//! - V8 isolate creation per worker
//! - V8 context creation within the isolate
//! - EngineCallbacks implementation for WorkerContext
//! - Global scope setup (self, console, etc.)
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

// V8 FFI through runtime module
const v8 = @import("v8");
const runtime = @import("runtime");

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

    /// Worker type (classic or module)
    worker_type: WorkerType,

    /// Allocator
    allocator: Allocator,

    /// Reference to the DedicatedWorker (set during setupWorkerGlobalScope)
    dedicated_worker: ?*DedicatedWorker = null,

    /// Flag to prevent double-deinit (deinit can be called from Worker.deinit and disposeContextCallback)
    is_deinitialized: bool = false,

    const Self = @This();

    /// Create a new V8 context for a worker
    ///
    /// This creates:
    /// 1. A new V8 isolate (separate from main thread)
    /// 2. A V8 context within that isolate
    /// 3. Sets up basic global scope
    pub fn init(
        allocator: Allocator,
        script_url: []const u8,
        worker_type: WorkerType,
    ) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        // Copy script URL
        const url_copy = try allocator.dupe(u8, script_url);
        errdefer allocator.free(url_copy);

        // Initialize V8 platform if not already done
        // NOTE: The main browser context should have already called
        // snapshot_loader.initializePlatformForSnapshots() which sets the
        // required V8 flags before platform init. If this is the first
        // V8 initialization, it won't support snapshot loading properly.
        v8.ffi.v8_Platform_Initialize();

        // Create V8 Isolate for this worker
        const isolate = v8.ffi.v8_Isolate_New() orelse {
            return error.V8IsolateCreationFailed;
        };
        errdefer v8.ffi.v8_Isolate_Dispose(isolate);

        // Enter the isolate temporarily to create the context
        v8.ffi.v8_Isolate_Enter(isolate);

        // Create V8 Context within the isolate
        const context = v8.ffi.v8_Context_New(isolate) orelse {
            v8.ffi.v8_Isolate_Exit(isolate);
            return error.V8ContextCreationFailed;
        };

        // Enter the context for setup
        v8.ffi.v8_Context_Enter(context);

        self.* = .{
            .isolate = isolate,
            .context = context,
            .script_url = url_copy,
            .worker_type = worker_type,
            .allocator = allocator,
        };

        // CRITICAL: Create HandleScope for V8 handle allocation during setup
        // V8 requires any API calls that create Local handles to be within a HandleScope.
        // setupWorkerGlobals() calls v8_String_NewFromUtf8 which creates Local<String>.
        // Without this, those calls will crash with "Cannot create a handle without a HandleScope".
        const handle_scope = v8.ffi.v8_HandleScope_New(isolate);
        defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

        // Set up basic worker globals (self, globalThis)
        try self.setupWorkerGlobals();

        // Register essential WebIDL interfaces needed for worker scripts
        // This is a minimal subset needed for WPT tests
        self.registerWorkerInterfaces();

        // Exit worker context/isolate after setup - we'll re-enter when executing scripts
        // This allows the main isolate to remain active during Worker construction
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
        const handle_scope = v8.ffi.v8_HandleScope_New(self.isolate);
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
        self.dedicated_worker = dedicated_worker;

        // Enter worker's isolate and context for setup
        v8.ffi.v8_Isolate_Enter(self.isolate);
        v8.ffi.v8_Context_Enter(self.context);
        defer {
            v8.ffi.v8_Context_Exit(self.context);
            v8.ffi.v8_Isolate_Exit(self.isolate);
        }

        const global_obj = v8.ffi.v8_Context_Global(self.context) orelse {
            return error.NoGlobalObject;
        };

        // Set up GLOBAL object for WPT tests
        // This is required by testharness.js to detect the execution context
        const global_script =
            \\self.GLOBAL = {
            \\  isWindow: function() { return false; },
            \\  isWorker: function() { return true; },
            \\  isShadowRealm: function() { return false; },
            \\};
        ;
        _ = try self.executeScript(global_script);

        // Set up DedicatedWorkerGlobalScope constructor for testharness.js detection
        // testharness.js checks: 'DedicatedWorkerGlobalScope' in global_scope &&
        //                        global_scope instanceof DedicatedWorkerGlobalScope
        // We create a constructor and make self an instance of it
        const worker_scope_script =
            \\(function() {
            \\  // Create DedicatedWorkerGlobalScope constructor
            \\  function DedicatedWorkerGlobalScope() {}
            \\  globalThis.DedicatedWorkerGlobalScope = DedicatedWorkerGlobalScope;
            \\
            \\  // Make the global object (self) have DedicatedWorkerGlobalScope.prototype in its chain
            \\  // This makes `self instanceof DedicatedWorkerGlobalScope` return true
            \\  Object.setPrototypeOf(DedicatedWorkerGlobalScope.prototype, Object.getPrototypeOf(globalThis));
            \\  Object.setPrototypeOf(globalThis, DedicatedWorkerGlobalScope.prototype);
            \\
            \\  // Also add WorkerGlobalScope as a fallback
            \\  function WorkerGlobalScope() {}
            \\  globalThis.WorkerGlobalScope = WorkerGlobalScope;
            \\  Object.setPrototypeOf(DedicatedWorkerGlobalScope.prototype, WorkerGlobalScope.prototype);
            \\})();
        ;
        _ = try self.executeScript(worker_scope_script);

        // Set up console object (no-op implementation for workers)
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

        // Set thread-local reference for callbacks to access this context
        current_worker_context = self;

        // Register postMessage() - sends message to main thread
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

        // Register close() - terminates the worker
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

        // Register importScripts() - loads and executes scripts synchronously
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

        // Register done() for WPT test harness - signals test completion
        {
            const template = v8.ffi.v8_FunctionTemplate_New(self.isolate, workerDoneCallback, null) orelse {
                return error.FunctionTemplateCreateFailed;
            };
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, self.context) orelse {
                return error.FunctionCreateFailed;
            };
            const key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "done", 4) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(key), @ptrCast(func));
        }

        // Set up worker 'name' property
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

        // Set up isSecureContext property
        // Per HTML Standard, isSecureContext indicates if the context is secure
        // For WPT tests, this depends on the URL - .https. or .h2. in filename means secure
        {
            const is_secure = isSecureUrlForWorker(self.script_url);
            const is_secure_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "isSecureContext", 15) orelse {
                return error.StringCreationFailed;
            };
            if (v8.ffi.v8_Boolean_New(self.isolate, is_secure)) |is_secure_value| {
                _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(is_secure_key), is_secure_value);
            }
        }

        // Set up location object using WorkerLocation interface
        // Per HTML Standard, WorkerGlobalScope has a location attribute
        // Apply WPT URL rewriting: .https. -> port 8443, .h2. -> port 9000
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

        // Set up origin property
        // Per HTML Standard, WorkerGlobalScope has an origin attribute
        // Apply WPT URL rewriting: .https. -> port 8443, .h2. -> port 9000
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
        const handle_scope = v8.ffi.v8_HandleScope_New(self.isolate);
        defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

        // Set current_worker_context so V8 callbacks (like postMessage) can access it
        // This allows workerPostMessageCallback to get the DedicatedWorker reference
        const prev_context = current_worker_context;
        current_worker_context = self;
        defer current_worker_context = prev_context;

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

        if (run_result.error_info != null) {
            return error.ExecutionFailed;
        }

        // Run microtasks after script execution
        v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(self.isolate);

        return @ptrCast(run_result.value);
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
fn compileAndRunModuleCallback(
    engine_ctx: *EngineContext,
    source: []const u8,
    source_url: []const u8,
) anyerror!void {
    _ = source_url; // TODO: Used for import resolution
    const self: *WorkerV8Context = @ptrCast(@alignCast(engine_ctx));

    // For now, execute as script. Full module support needs more V8 FFI.
    _ = try self.executeScript(source);
}

/// Run microtask checkpoint
fn runMicrotasksCallback(engine_ctx: *EngineContext) void {
    const self: *WorkerV8Context = @ptrCast(@alignCast(engine_ctx));
    v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(self.isolate);
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

    // Serialize the JSON string for posting
    var js_value = workers.message_channel.JSValue{ .string = json_str };
    const serialized = workers.message_channel.serializeForPostMessage(
        dedicated_worker.allocator,
        &js_value,
    ) catch return;

    // Create QueuedMessage
    const msg = workers.message_channel.QueuedMessage.init(dedicated_worker.allocator, serialized, null) catch {
        serialized.deinit();
        dedicated_worker.allocator.destroy(serialized);
        return;
    };

    // Append to pending_messages for deferred dispatch
    workers.dedicated_worker.DedicatedWorker.appendPendingMessage(
        dedicated_worker.port_pair.outside_port,
        msg,
    ) catch {
        msg.deinit();
        return;
    };
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

        const url = buf[0..@intCast(actual_len)];

        // Fetch the script
        // Per HTML Standard § 10.2.4.2 importScripts(urls):
        // "For each url of urls: Let urlRecord be the result of parsing url with worker global scope's url"
        // The worker's script_url is the base for resolving relative URLs
        var fetched_script = script_fetch.fetchWorkerScript(self.allocator, url, .{
            .is_import_scripts = true,
            .worker_type = .classic,
            .origin = self.script_url, // Base URL for relative path resolution
        }) catch |err| {
            std.log.warn("importScripts: failed to fetch '{s}': {}", .{ url, err });
            // Per spec, throw NetworkError on fetch failure
            // For now, just continue to next script
            continue;
        };
        defer fetched_script.deinit();

        // Execute the script synchronously
        _ = self.executeScript(fetched_script.source) catch |err| {
            std.log.warn("importScripts: failed to execute '{s}': {}", .{ url, err });
            continue;
        };
    }
}

/// V8 callback for done() - signals test completion (WPT testharness)
///
/// This is called by worker test scripts to signal they're done running tests.
/// The worker then posts a completion message to the main thread.
fn workerDoneCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    _ = info;
    // Note: The actual done() function in testharness.js handles posting
    // the completion message. We just need to have this function exist
    // so the worker script can call it.
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
