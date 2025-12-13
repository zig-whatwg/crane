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
    // Get WorkerV8Context from thread-local storage
    const self = current_worker_context orelse {
        return;
    };

    // Get the DedicatedWorker to send message
    const dedicated_worker = self.dedicated_worker orelse {
        std.log.warn("workerPostMessageCallback: no dedicated_worker set", .{});
        return;
    };

    // Get isolate and context
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        std.log.warn("workerPostMessageCallback: no V8 context", .{});
        return;
    };

    // Get the message argument (first argument)
    const argc = info.v8_FunctionCallbackInfo_Length();
    if (argc < 1) {
        // No arguments - send undefined
        var js_value = workers.message_channel.JSValue{ .undefined = {} };
        dedicated_worker.postMessageFromWorker(&js_value, null) catch |err| {
            std.log.warn("postMessageFromWorker failed: {}", .{err});
        };
        return;
    }

    const message_arg = info.get(0);

    // Serialize to JSON using V8's JSON.stringify
    // First, get the required buffer size (pass null buffer to get size)
    var dummy_buf: [1]u8 = undefined;
    const required_size = v8.ffi.v8_JSON_Stringify_ToBuffer(
        v8_context,
        message_arg,
        &dummy_buf,
        0,
    );

    if (required_size <= 0) {
        // JSON serialization failed (e.g., circular reference, function)
        // Fall back to undefined
        std.log.warn("workerPostMessageCallback: JSON.stringify failed", .{});
        var js_value = workers.message_channel.JSValue{ .undefined = {} };
        dedicated_worker.postMessageFromWorker(&js_value, null) catch |err| {
            std.log.warn("postMessageFromWorker failed: {}", .{err});
        };
        return;
    }

    // Allocate buffer and serialize
    var json_buffer: [8192]u8 = undefined;
    const buffer_to_use = if (required_size <= 8192)
        &json_buffer
    else blk: {
        // For very large messages, allocate on heap
        // This is rare for testharness.js messages
        break :blk self.allocator.alloc(u8, @intCast(required_size)) catch {
            std.log.warn("workerPostMessageCallback: allocation failed", .{});
            var js_value = workers.message_channel.JSValue{ .undefined = {} };
            dedicated_worker.postMessageFromWorker(&js_value, null) catch {};
            return;
        };
    };
    defer if (required_size > 8192) {
        self.allocator.free(buffer_to_use);
    };

    const written = v8.ffi.v8_JSON_Stringify_ToBuffer(
        v8_context,
        message_arg,
        buffer_to_use.ptr,
        @intCast(buffer_to_use.len),
    );

    if (written <= 0) {
        std.log.warn("workerPostMessageCallback: JSON.stringify write failed", .{});
        var js_value = workers.message_channel.JSValue{ .undefined = {} };
        dedicated_worker.postMessageFromWorker(&js_value, null) catch {};
        return;
    }

    // Create JSValue with the JSON string
    // We store the JSON in a string field - the receiver will parse it
    const json_str = buffer_to_use[0..@intCast(written)];

    // Create JSValue with string type, pointing directly to the stack buffer
    // structuredSerialize will duplicate the string, so we don't need to allocate here
    var js_value = workers.message_channel.JSValue{ .string = json_str };

    // Post the message - the receiver will deserialize the JSON
    // Note: structuredSerialize duplicates the string, so we don't need to manage memory
    dedicated_worker.postMessageFromWorker(&js_value, null) catch |err| {
        std.log.warn("postMessageFromWorker failed: {}", .{err});
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
