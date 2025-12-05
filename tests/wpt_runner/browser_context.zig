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

// V8 Event Loop with timer support (uses libuv under the hood)
const V8EventLoop = v8.V8EventLoop;
const TimerInterface = runtime.TimerInterface;
const TimerId = runtime.TimerId;
const TimerCallback = runtime.TimerCallback;

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

        // Clear timer interface from thread-local storage
        clearTimerInterface();

        // Cleanup V8 event loop (which cleans up libuv timer manager)
        if (self.v8_event_loop) |event_loop| {
            event_loop.deinit();
            self.allocator.destroy(event_loop);
        }

        // Cleanup context manager (this cleans up wrapper cache which deinits all instances)
        if (self.context != null) {
            context_manager.deinit();
        }

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
        if (self.isolate) |isolate| {
            v8.ffi.v8_Isolate_RequestGarbageCollection(isolate);
            v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);
            v8.ffi.v8_Isolate_RequestGarbageCollection(isolate);
            v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);

            v8.ffi.v8_Isolate_Exit(isolate);
            v8.ffi.v8_Isolate_Dispose(isolate);
        }

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

        // Create V8 context
        const context = v8.ffi.v8_Context_New(isolate) orelse return error.ContextCreateFailed;
        self.context = context;

        v8.ffi.v8_Context_Enter(context);

        // Initialize context manager for V8 callbacks
        context_manager.init(self.allocator) catch |err| {
            std.debug.print("Warning: Context manager init failed: {}\n", .{err});
        };

        // Register context with context manager for wrapper caching
        _ = context_manager.getOrCreateWithIsolate(context, isolate, self.allocator) catch |err| {
            std.debug.print("Warning: Context registration failed: {}\n", .{err});
        };

        // Register all WebIDL interfaces using the centralized function
        // This is the single source of truth for interface binding setup
        v8.interface_bindings.initializeBindings(isolate, context);

        // Register all namespaces using the generic function
        v8.interface_bindings.registerNamespacesGeneric(namespaces, isolate, context);

        // Register browser globals (Window, document, navigator, etc.)
        try self.registerBrowserGlobals();

        // Register WPT result callbacks
        try self.registerWptCallbacks();

        // Set up window/self globals via JavaScript
        // We do this via JS because V8's global proxy has special semantics
        // that make C++ property setting behave differently from JS assignment.
        try self.setupGlobalAliases();

        // Set up timer interface in thread-local storage
        // This needs to be available for testharness.js which uses setTimeout
        if (self.v8_event_loop) |event_loop| {
            if (event_loop.timerInterface()) |timer| {
                setTimerInterface(timer, self.allocator);
            }
        }

        self.initialized = true;
    }

    /// Set up window/self/globalThis aliases and GLOBAL object via JavaScript
    fn setupGlobalAliases(self: *BrowserContext) !void {
        // Simple direct assignment on globalThis
        const setup_script =
            \\// Assign self and window to globalThis
            \\globalThis.self = globalThis;
            \\globalThis.window = globalThis;
            \\
            \\// Set up GLOBAL object for WPT tests
            \\// This is normally injected by the WPT server's HTML wrapper
            \\self.GLOBAL = {
            \\  isWindow: function() { return true; },
            \\  isWorker: function() { return false; },
            \\  isShadowRealm: function() { return false; },
            \\};
        ;

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
        // 2. Set window/self via JavaScript after context setup

        // Register Document singleton
        {
            const Document = interfaces.Document;
            const doc_instance = Document.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create document singleton: {}\n", .{err});
                return;
            };
            self.document_instance = doc_instance;

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
            _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(doc_key), @ptrCast(v8_document));
        }

        // Register Navigator singleton
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
            _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(nav_key), @ptrCast(v8_navigator));
        }

        // Register Location singleton
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
            _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(loc_key), @ptrCast(v8_location));
        }

        // Register History singleton
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
            _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(hist_key), @ptrCast(v8_history));
        }

        // Register Performance singleton
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
            _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(perf_key), @ptrCast(v8_performance));
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
        // Register 'self' as reference to global object (WorkerGlobalScope)
        const self_key = v8.ffi.v8_String_NewFromUtf8(isolate, "self", 4) orelse return error.StringCreateFailed;
        _ = v8.ffi.v8_Object_Set(global_obj, context, @ptrCast(self_key), @ptrCast(global_obj));

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
    }

    /// Register common globals (setTimeout, fetch, console, etc.)
    fn registerCommonGlobals(
        self: *BrowserContext,
        isolate: *v8.ffi.Isolate,
        context: *v8.ffi.Context,
        global_obj: *v8.ffi.Object,
    ) !void {
        _ = self;

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
    }

    /// Set the test URL (updates location object)
    pub fn setTestUrl(self: *BrowserContext, url: []const u8) !void {
        self.allocator.free(self.test_url);
        self.test_url = try self.allocator.dupe(u8, url);

        // TODO: Update location object in V8 context
    }

    /// Start tracking results for a new test file
    pub fn startTest(self: *BrowserContext, test_path: []const u8) !void {
        try self.result_collector.startTest(test_path);
        // Set result collector for V8 callbacks
        setResultCollector(&self.result_collector);
    }

    /// Reset the result collector for the next test
    pub fn resetForNextTest(self: *BrowserContext) void {
        // Reset completion flag but keep collected results
        self.result_collector.completion_signaled = false;
        self.result_collector.completed = false;
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

        // Compile script
        const script = v8.ffi.v8_Script_Compile(context, source_str) orelse {
            // Get exception message
            const exception = v8.ffi.v8_TryCatch_Exception(context);
            if (exception) |exc| {
                const exc_str = v8.ffi.v8_Value_ToString(exc, context);
                if (exc_str) |str| {
                    const len = v8.ffi.v8_String_Utf8Length(str);
                    const buffer = try self.allocator.alloc(u8, @intCast(len));
                    defer self.allocator.free(buffer);
                    _ = v8.ffi.v8_String_WriteUtf8(str, buffer.ptr, @intCast(len));
                    std.debug.print("Script compile error: {s}\n", .{buffer});
                }
            }
            return error.CompileError;
        };

        // Run script
        _ = v8.ffi.v8_Script_Run(context, script) orelse {
            const exception = v8.ffi.v8_TryCatch_Exception(context);
            if (exception) |exc| {
                const exc_str = v8.ffi.v8_Value_ToString(exc, context);
                if (exc_str) |str| {
                    const len = v8.ffi.v8_String_Utf8Length(str);
                    const buffer = try self.allocator.alloc(u8, @intCast(len));
                    defer self.allocator.free(buffer);
                    _ = v8.ffi.v8_String_WriteUtf8(str, buffer.ptr, @intCast(len));
                    std.debug.print("Script runtime error: {s}\n", .{buffer});
                }
            }
            return error.RuntimeError;
        };

        // Run microtasks
        v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);
    }

    /// Execute a test and wait for completion
    pub fn executeTest(self: *BrowserContext, test_content: []const u8, timeout: config.Timeout) !test_harness.TestResult {
        // Set result collector for V8 callbacks
        // Timer interface is set once in initialize() and persists for the context lifetime
        setResultCollector(&self.result_collector);
        defer clearResultCollector();

        // Execute test script
        try self.executeScript(test_content);

        // Trigger testharness.js completion - it normally waits for window load
        // but our mock environment doesn't have proper event dispatch
        try self.triggerTestHarnessCompletion();

        // Run event loop until completion or timeout
        const timeout_ms = timeout.toMillis();
        try self.runEventLoop(timeout_ms);

        // Collect and return results
        return self.result_collector.finalize(self.allocator, "test");
    }

    /// Trigger testharness.js completion
    /// testharness.js in WindowTestEnvironment waits for window load event,
    /// but our mock environment doesn't have proper event dispatch.
    /// The `done()` function is exposed globally by testharness.js and can
    /// be called to signal that all tests have been defined.
    fn triggerTestHarnessCompletion(self: *BrowserContext) !void {
        const completion_script =
            \\(function() {
            \\  // CRITICAL: testharness.js WindowTestEnvironment sets all_loaded = true
            \\  // only when the window 'load' event fires. Since we don't have a real
            \\  // window load event, we need to set this manually for tests.all_done() to work.
            \\  // test_environment is a global variable in testharness.js
            \\  if (typeof test_environment !== 'undefined') {
            \\    test_environment.all_loaded = true;
            \\  }
            \\  
            \\  // Call the exposed done() function to signal test completion
            \\  // testharness.js exposes this globally via expose(done, 'done')
            \\  if (typeof done === 'function') {
            \\    // Use setTimeout 0 to allow any pending microtasks/promises to resolve first
            \\    setTimeout(function() {
            \\      done();
            \\    }, 0);
            \\  }
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

            // 1. Run one iteration of the V8 event loop
            // This processes ready timers (via libuv), runs tasks, and runs microtasks
            _ = event_loop.eventLoop().runOnce();

            // 2. Check if completion callback has been called
            if (self.result_collector.completed) {
                return;
            }

            // 3. Check timeout
            const elapsed: u64 = @intCast(now - start_time);
            if (elapsed > timeout_ms) {
                // Mark the test as timed out
                try self.result_collector.finishTest(.timeout, "Test timed out", elapsed);
                return;
            }

            // 4. Short sleep to avoid busy-waiting
            // The libuv loop handles actual timer scheduling, we just need to poll frequently
            std.Thread.sleep(1 * std.time.ns_per_ms);
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
};

// Thread-local storage for result collector (accessible from V8 callbacks)
// V8 callbacks are C functions that can't easily capture context,
// so we use thread-local storage to pass the result collector.
threadlocal var current_result_collector: ?*test_harness.ResultCollector = null;

// Thread-local storage for timer interface (accessible from V8 callbacks)
threadlocal var current_timer_interface: ?TimerInterface = null;

// Thread-local storage for allocator (needed for timer callback contexts)
threadlocal var current_allocator: ?std.mem.Allocator = null;

// Thread-local storage for ALL timer contexts (for cleanup on clearTimeout/clearInterval and deinit)
// Maps timer_id -> V8TimerContext* so we can clean up pending timers when context is torn down
threadlocal var timer_contexts: ?std.AutoHashMap(TimerId, *V8TimerContext) = null;

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
        timer_contexts = std.AutoHashMap(TimerId, *V8TimerContext).init(allocator);
    }
}

/// Get the current timer interface (for V8 callbacks)
pub fn getTimerInterface() ?TimerInterface {
    return current_timer_interface;
}

/// Clear the timer interface reference and clean up ALL pending timer contexts
pub fn clearTimerInterface() void {
    // Clean up any remaining timer contexts (both one-shot and intervals)
    if (timer_contexts) |*map| {
        var iter = map.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.*.destroy();
        }
        map.deinit();
        timer_contexts = null;
    }
    current_timer_interface = null;
    current_allocator = null;
}

/// Register a timer context for cleanup tracking (both one-shot and intervals)
fn registerTimerContext(timer_id: TimerId, ctx: *V8TimerContext) void {
    if (timer_contexts) |*map| {
        map.put(timer_id, ctx) catch {};
    }
}

/// Unregister a timer context (marks intervals as cancelled, removes from tracking)
fn unregisterTimerContext(timer_id: TimerId) void {
    if (timer_contexts) |*map| {
        if (map.fetchRemove(timer_id)) |kv| {
            // Mark as cancelled so interval callbacks know to stop rescheduling
            kv.value.cancelled = true;
            // Don't destroy here - the callback will clean up when it fires
        }
    }
}

// V8 Callback Functions

/// Context for V8 timer callbacks
/// Stores references needed to invoke the V8 function when the timer fires
///
/// NOTE: This stores raw V8 function pointers without proper persistent handles.
/// The V8 FFI doesn't currently support Persistent/Global handle creation.
/// This works for short-lived WPT tests but could cause issues if V8 GCs
/// the function before the timer fires. For production use, the V8 FFI
/// would need to expose v8::Global<v8::Function> creation.
const V8TimerContext = struct {
    /// Raw pointer to the V8 function (not GC-protected!)
    callback_fn: *v8.ffi.Function,
    /// V8 isolate
    isolate: *v8.ffi.Isolate,
    /// Allocator for cleanup
    allocator: std.mem.Allocator,
    /// Whether this is an interval (repeating) timer - affects cleanup
    is_interval: bool,
    /// For intervals: the delay in ms for rescheduling
    interval_delay_ms: u64 = 0,
    /// For intervals: the current timer ID (updated on each reschedule)
    current_timer_id: TimerId = 0,
    /// For intervals: whether the interval has been cancelled
    cancelled: bool = false,

    /// Create a new timer context
    fn create(allocator: std.mem.Allocator, isolate: *v8.ffi.Isolate, callback_value: *v8.ffi.Value, is_interval: bool) !*V8TimerContext {
        // Verify it's a function
        if (!v8.ffi.v8_Value_IsFunction(callback_value)) {
            return error.NotAFunction;
        }

        const ctx = try allocator.create(V8TimerContext);
        ctx.* = V8TimerContext{
            .callback_fn = @ptrCast(callback_value),
            .isolate = isolate,
            .allocator = allocator,
            .is_interval = is_interval,
        };
        return ctx;
    }

    /// Free resources
    fn destroy(self: *V8TimerContext) void {
        // NOTE: We don't have a way to release the V8 function reference
        // since we're not using proper persistent handles
        self.allocator.destroy(self);
    }
};

/// Timer callback that invokes the V8 function (one-shot timers)
fn v8TimerCallback(ctx_ptr: ?*anyopaque) void {
    const timer_ctx: *V8TimerContext = @ptrCast(@alignCast(ctx_ptr orelse return));

    // Unregister from timer_contexts map before destroying (prevents double-free on deinit)
    if (timer_contexts) |*map| {
        _ = map.remove(timer_ctx.current_timer_id);
    }

    // Always destroy one-shot timer contexts after execution
    defer timer_ctx.destroy();

    const isolate = timer_ctx.isolate;
    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    const global = v8.ffi.v8_Context_Global(context) orelse return;

    // Invoke the V8 function (stored directly, not via persistent handle)
    var empty_args: [1]*v8.ffi.Value = undefined;
    _ = v8.ffi.v8_Function_Call(timer_ctx.callback_fn, context, @ptrCast(global), 0, &empty_args);

    // Run microtasks after the timer callback (per event loop semantics)
    v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);
}

/// Interval callback that invokes the V8 function and reschedules itself
fn v8IntervalCallback(ctx_ptr: ?*anyopaque) void {
    const timer_ctx: *V8TimerContext = @ptrCast(@alignCast(ctx_ptr orelse return));

    // Helper to unregister and destroy the timer context
    const destroyTimerCtx = struct {
        fn f(ctx: *V8TimerContext) void {
            if (timer_contexts) |*map| {
                _ = map.remove(ctx.current_timer_id);
            }
            ctx.destroy();
        }
    }.f;

    // Check if interval was cancelled
    if (timer_ctx.cancelled) {
        destroyTimerCtx(timer_ctx);
        return;
    }

    const isolate = timer_ctx.isolate;
    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    const global = v8.ffi.v8_Context_Global(context) orelse return;

    // Invoke the V8 function
    var empty_args: [1]*v8.ffi.Value = undefined;
    _ = v8.ffi.v8_Function_Call(timer_ctx.callback_fn, context, @ptrCast(global), 0, &empty_args);

    // Run microtasks after the timer callback
    v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);

    // Reschedule the interval if not cancelled
    if (!timer_ctx.cancelled) {
        if (getTimerInterface()) |timer| {
            const new_timer_id = timer.setTimeout(timer_ctx.interval_delay_ms, v8IntervalCallback, timer_ctx);
            if (new_timer_id != 0) {
                // Update the timer ID for potential clearInterval calls
                const old_id = timer_ctx.current_timer_id;
                timer_ctx.current_timer_id = new_timer_id;
                // Update the timer context map with new ID
                if (timer_contexts) |*map| {
                    _ = map.remove(old_id);
                    map.put(new_timer_id, timer_ctx) catch {};
                }
            } else {
                // Failed to reschedule, clean up
                destroyTimerCtx(timer_ctx);
            }
        } else {
            // No timer interface, clean up
            destroyTimerCtx(timer_ctx);
        }
    } else {
        // Cancelled, clean up
        destroyTimerCtx(timer_ctx);
    }
}

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
            delay_ms = @intFromFloat(v8.ffi.v8_Value_NumberValue(delay_value, context));
            if (delay_ms < 0) delay_ms = 0;
        }
    }

    // Get timer interface from thread-local storage
    const timer = getTimerInterface() orelse {
        // Fallback: execute immediately if no timer interface
        std.debug.print("WARNING: No timer interface, executing setTimeout callback immediately\n", .{});
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

    // Create timer context to hold V8 callback reference (not an interval)
    const timer_ctx = V8TimerContext.create(allocator, isolate, callback_value, false) catch {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Schedule the timer using TimerInterface
    const delay_u64: u64 = if (delay_ms >= 0) @intCast(delay_ms) else 0;
    const timer_id = timer.setTimeout(delay_u64, v8TimerCallback, timer_ctx);
    if (timer_id == 0) {
        timer_ctx.destroy();
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    }

    // Store the timer ID in the context so the callback can unregister it
    timer_ctx.current_timer_id = timer_id;

    // Register the timer context for cleanup tracking (prevents memory leak on deinit)
    registerTimerContext(timer_id, timer_ctx);

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
            delay_ms = @intFromFloat(v8.ffi.v8_Value_NumberValue(delay_value, context));
            if (delay_ms < 0) delay_ms = 0;
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

    // Create timer context to hold V8 callback reference (this IS an interval)
    const timer_ctx = V8TimerContext.create(allocator, isolate, callback_value, true) catch {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Store the interval delay in the context for re-scheduling
    timer_ctx.interval_delay_ms = if (delay_ms >= 0) @intCast(delay_ms) else 0;

    // Schedule the first timeout (intervals reschedule themselves in v8IntervalCallback)
    const delay_u64: u64 = if (delay_ms >= 0) @intCast(delay_ms) else 0;
    const timer_id = timer.setTimeout(delay_u64, v8IntervalCallback, timer_ctx);
    if (timer_id == 0) {
        timer_ctx.destroy();
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    }

    // Store the timer ID in the context so it can be used for rescheduling
    timer_ctx.current_timer_id = timer_id;

    // Register the interval context for cleanup when clearInterval is called
    registerTimerContext(timer_id, timer_ctx);

    // Return timer ID (truncate to i32 for V8 Integer)
    const result = v8.ffi.v8_Integer_New(isolate, @intCast(@as(u32, @truncate(timer_id))));
    info.setReturnValue(@ptrCast(result));
}

/// Mock addEventListener callback - stores event listeners for the global object
/// The WPT testharness.js calls window.addEventListener('load', callback) to register
/// callbacks that should fire when the document is loaded.
/// For our mock environment, we just store them and they'll be called when we trigger 'load'.
fn addEventListenerCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    // For now, just return undefined - we don't actually need event handling
    // The testharness.js just needs this function to exist and not throw.
    // In the future, we could store listeners and dispatch events properly.
    if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
        info.setReturnValue(undef_value);
    }
}

/// Mock removeEventListener callback - no-op for now
fn removeEventListenerCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
        info.setReturnValue(undef_value);
    }
}

/// Mock dispatchEvent callback - returns true (event was not cancelled)
fn dispatchEventCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    // Return true to indicate the event was not cancelled
    if (v8.ffi.v8_Boolean_New(isolate, true)) |result| {
        info.setReturnValue(result);
    }
}

/// WPT result reporting callback - called by testharnessreport.js for each test result
/// Signature: __wpt_report_result(name, status, message, stack, duration)
fn wptReportResultCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    std.debug.print("WPT: __wpt_report_result called!\n", .{});

    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        std.debug.print("WPT: No context in __wpt_report_result\n", .{});
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    };

    // Get result collector from thread-local storage
    const collector = getResultCollector() orelse {
        std.debug.print("WPT: No result collector set\n", .{});
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    };

    // Parse arguments: name, status, message, stack, duration
    const arg_count = info.v8_FunctionCallbackInfo_Length();
    if (arg_count < 2) {
        std.debug.print("WPT: __wpt_report_result requires at least 2 arguments\n", .{});
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    }

    // Use a simple allocator for this callback
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Arg 0: name (string)
    const name_value = info.get(0);
    const name_str = extractString(allocator, isolate, context, name_value) catch |err| {
        std.debug.print("WPT: Failed to extract name: {}\n", .{err});
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    };
    defer allocator.free(name_str);

    // Arg 1: status (number: 0=PASS, 1=FAIL, 2=TIMEOUT, 3=NOTRUN, 4=PRECONDITION_FAILED)
    const status_value = info.get(1);
    const status_num: u8 = if (v8.ffi.v8_Value_IsNumber(status_value))
        @intFromFloat(v8.ffi.v8_Value_NumberValue(status_value, context))
    else
        1; // Default to FAIL
    const status = test_harness.TestStatus.fromInt(status_num);

    // Arg 2: message (string or null)
    var message_str: ?[]const u8 = null;
    var message_owned: ?[]u8 = null;
    if (arg_count > 2) {
        const msg_value = info.get(2);
        if (!v8.ffi.v8_Value_IsNull(msg_value) and !v8.ffi.v8_Value_IsUndefined(msg_value)) {
            message_owned = extractString(allocator, isolate, context, msg_value) catch null;
            message_str = message_owned;
        }
    }
    defer if (message_owned) |m| allocator.free(m);

    // Arg 3: stack (string or null)
    var stack_str: ?[]const u8 = null;
    var stack_owned: ?[]u8 = null;
    if (arg_count > 3) {
        const stack_value = info.get(3);
        if (!v8.ffi.v8_Value_IsNull(stack_value) and !v8.ffi.v8_Value_IsUndefined(stack_value)) {
            stack_owned = extractString(allocator, isolate, context, stack_value) catch null;
            stack_str = stack_owned;
        }
    }
    defer if (stack_owned) |s| allocator.free(s);

    // Arg 4: duration (number)
    var duration_ms: u64 = 0;
    if (arg_count > 4) {
        const duration_value = info.get(4);
        if (v8.ffi.v8_Value_IsNumber(duration_value)) {
            const duration_float = v8.ffi.v8_Value_NumberValue(duration_value, context);
            duration_ms = @intFromFloat(@max(0.0, duration_float));
        }
    }

    // Create SubtestResult and add to collector using collector's allocator
    const subtest = test_harness.SubtestResult{
        .name = collector.allocator.dupe(u8, name_str) catch {
            std.debug.print("WPT: Failed to allocate name\n", .{});
            if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
                info.setReturnValue(undef_value);
            }
            return;
        },
        .status = status,
        .message = if (message_str) |m| collector.allocator.dupe(u8, m) catch null else null,
        .stack = if (stack_str) |s| collector.allocator.dupe(u8, s) catch null else null,
        .duration_ms = duration_ms,
    };

    collector.addResult(subtest) catch |err| {
        std.debug.print("WPT: Failed to add result: {}\n", .{err});
    };

    if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
        info.setReturnValue(undef_value);
    }
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
    collector.finishTest(harness_status, null, 0) catch |err| {
        std.debug.print("WPT: Failed to finish test: {}\n", .{err});
    };

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
