//! Context - V8 Context per Navigation
//!
//! This module manages a V8 context (JavaScript execution environment) for a single
//! page navigation. A new context is created for each navigation while the isolate
//! is reused.
//!
//! ## Responsibilities
//!
//! - Create V8 context within existing isolate
//! - Register browser globals (window, document, navigator, etc.)
//! - Register WebIDL bindings
//! - Execute scripts and handle events
//!
//! ## Performance
//!
//! Context creation is cheap (~1-5ms) compared to isolate creation (~50-100ms).
//! This enables efficient WPT test execution.
//!
//! ## Specification References
//!
//! - HTML Standard: Browsing contexts https://html.spec.whatwg.org/multipage/document-sequences.html
//! - HTML Standard: Window object https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-window-object

const std = @import("std");
const v8 = @import("v8");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const namespaces = @import("namespaces");

const Storage = @import("storage/Storage.zig");
const context_manager = v8.context_manager;

/// Context type for determining which globals to register
pub const ContextType = enum {
    /// Window context (for HTML pages)
    window,
    /// Dedicated worker context
    worker,
    /// Shared worker context
    shared_worker,
    /// Service worker context
    service_worker,
};

/// V8 Context representing a single page navigation
pub const Context = struct {
    allocator: std.mem.Allocator,
    /// V8 isolate (owned by Browser, not Context)
    isolate: *v8.ffi.Isolate,
    /// V8 context for this navigation
    v8_context: ?*v8.ffi.Context,
    /// Storage subsystem (shared across navigations)
    storage: *Storage,
    /// Current URL
    url: []const u8,
    /// Context type
    context_type: ContextType,
    /// Whether context is ready for execution
    initialized: bool,
    /// Event loop reference (owned by Browser)
    event_loop: ?*v8.V8EventLoop,

    // Singleton instances for cleanup
    window_instance: ?*runtime.Instance = null,
    document_instance: ?*runtime.Instance = null,
    navigator_instance: ?*runtime.Instance = null,
    location_instance: ?*runtime.Instance = null,
    history_instance: ?*runtime.Instance = null,
    performance_instance: ?*runtime.Instance = null,

    /// Initialize a new Context
    ///
    /// Creates a V8 context within the existing isolate and registers all
    /// browser globals.
    pub fn init(
        allocator: std.mem.Allocator,
        isolate: *v8.ffi.Isolate,
        storage: *Storage,
        url: []const u8,
        event_loop: ?*v8.V8EventLoop,
    ) !*Context {
        const ctx = try allocator.create(Context);
        errdefer allocator.destroy(ctx);

        ctx.* = Context{
            .allocator = allocator,
            .isolate = isolate,
            .v8_context = null,
            .storage = storage,
            .url = try allocator.dupe(u8, url),
            .context_type = .window, // Default to window context
            .initialized = false,
            .event_loop = event_loop,
        };

        try ctx.createV8Context();
        return ctx;
    }

    /// Create V8 context and register globals
    fn createV8Context(self: *Context) !void {
        // Create V8 context
        const v8_ctx = v8.ffi.v8_Context_New(self.isolate) orelse {
            return error.ContextCreateFailed;
        };
        self.v8_context = v8_ctx;

        v8.ffi.v8_Context_Enter(v8_ctx);

        // Initialize context manager for V8 callbacks
        context_manager.init(self.allocator) catch |err| {
            std.debug.print("Warning: Context manager init failed: {}\n", .{err});
        };

        // Register context with context manager for wrapper caching
        _ = context_manager.getOrCreateWithIsolate(v8_ctx, self.isolate, self.allocator) catch |err| {
            std.debug.print("Warning: Context registration failed: {}\n", .{err});
        };

        // Register all WebIDL interfaces
        v8.interface_bindings.initializeBindings(self.isolate, v8_ctx);

        // Register all namespaces
        v8.interface_bindings.registerNamespacesGeneric(namespaces, self.isolate, v8_ctx);

        // Register browser globals based on context type
        try self.registerBrowserGlobals();

        // Set up global aliases (window, self, GLOBAL)
        try self.setupGlobalAliases();

        self.initialized = true;
    }

    /// Register browser globals based on context type
    fn registerBrowserGlobals(self: *Context) !void {
        const v8_ctx = self.v8_context orelse return error.NotInitialized;
        const global_obj = v8.ffi.v8_Context_Global(v8_ctx) orelse return error.NoGlobal;

        // Get runtime context for wrapper caching
        const runtime_ctx = context_manager.getOrCreate(v8_ctx, self.allocator) catch |err| {
            std.debug.print("Warning: Failed to get runtime context: {}\n", .{err});
            return;
        };

        switch (self.context_type) {
            .window => try self.registerWindowGlobals(global_obj, runtime_ctx),
            .worker => try self.registerWorkerGlobals(global_obj, runtime_ctx),
            else => {},
        }

        // Register common globals (setTimeout, fetch, console, etc.)
        try self.registerCommonGlobals(global_obj);
    }

    /// Register Window context globals
    fn registerWindowGlobals(
        self: *Context,
        global_obj: *v8.ffi.Object,
        runtime_ctx: runtime.Context,
    ) !void {
        const isolate = self.isolate;
        const v8_ctx = self.v8_context orelse return error.NotInitialized;

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
                v8_ctx,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap document: {}\n", .{err});
                return;
            };

            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "document", 8) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(v8_document));
        }

        // Register Navigator singleton
        {
            const Navigator = interfaces.Navigator;
            const nav_instance = Navigator.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create navigator: {}\n", .{err});
                return;
            };
            self.navigator_instance = nav_instance;

            const v8_navigator = v8.template_registry.wrapInstanceAsV8Object(
                nav_instance,
                "Navigator",
                isolate,
                v8_ctx,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap navigator: {}\n", .{err});
                return;
            };

            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "navigator", 9) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(v8_navigator));
        }

        // Register Location singleton
        {
            const Location = interfaces.Location;
            const loc_instance = Location.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create location: {}\n", .{err});
                return;
            };
            self.location_instance = loc_instance;

            const v8_location = v8.template_registry.wrapInstanceAsV8Object(
                loc_instance,
                "Location",
                isolate,
                v8_ctx,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap location: {}\n", .{err});
                return;
            };

            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "location", 8) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(v8_location));
        }

        // Register History singleton
        {
            const History = interfaces.History;
            const hist_instance = History.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create history: {}\n", .{err});
                return;
            };
            self.history_instance = hist_instance;

            const v8_history = v8.template_registry.wrapInstanceAsV8Object(
                hist_instance,
                "History",
                isolate,
                v8_ctx,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap history: {}\n", .{err});
                return;
            };

            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "history", 7) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(v8_history));
        }

        // Register Performance singleton
        {
            const Performance = interfaces.Performance;
            const perf_instance = Performance.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create performance: {}\n", .{err});
                return;
            };
            self.performance_instance = perf_instance;

            const v8_performance = v8.template_registry.wrapInstanceAsV8Object(
                perf_instance,
                "Performance",
                isolate,
                v8_ctx,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap performance: {}\n", .{err});
                return;
            };

            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "performance", 11) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(v8_performance));
        }
    }

    /// Register Worker context globals
    fn registerWorkerGlobals(
        self: *Context,
        global_obj: *v8.ffi.Object,
        runtime_ctx: runtime.Context,
    ) !void {
        const isolate = self.isolate;
        const v8_ctx = self.v8_context orelse return error.NotInitialized;

        // Register 'self' as reference to global object
        const self_key = v8.ffi.v8_String_NewFromUtf8(isolate, "self", 4) orelse return error.StringCreateFailed;
        _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(self_key), @ptrCast(global_obj));

        // Register WorkerNavigator
        {
            const WorkerNavigator = interfaces.WorkerNavigator;
            const nav_instance = WorkerNavigator.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create worker navigator: {}\n", .{err});
                return;
            };

            const v8_navigator = v8.template_registry.wrapInstanceAsV8Object(
                nav_instance,
                "WorkerNavigator",
                isolate,
                v8_ctx,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap worker navigator: {}\n", .{err});
                return;
            };

            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "navigator", 9) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(v8_navigator));
        }
    }

    /// Register common globals (setTimeout, fetch, console, etc.)
    fn registerCommonGlobals(self: *Context, global_obj: *v8.ffi.Object) !void {
        const isolate = self.isolate;
        const v8_ctx = self.v8_context orelse return error.NotInitialized;

        // setTimeout
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, setTimeoutCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 1);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "setTimeout", 10) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
        }

        // clearTimeout
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, clearTimeoutCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 1);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "clearTimeout", 12) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
        }

        // setInterval
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, setIntervalCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 1);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "setInterval", 11) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
        }

        // clearInterval
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, clearTimeoutCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 1);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "clearInterval", 13) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
        }

        // addEventListener
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, addEventListenerCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 2);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "addEventListener", 16) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
        }

        // removeEventListener
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, removeEventListenerCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 2);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "removeEventListener", 19) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
        }

        // dispatchEvent
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, dispatchEventCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 1);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "dispatchEvent", 13) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
        }
    }

    /// Set up global aliases via JavaScript
    fn setupGlobalAliases(self: *Context) !void {
        const setup_script =
            \\globalThis.self = globalThis;
            \\globalThis.window = globalThis;
            \\globalThis.parent = globalThis;
            \\globalThis.top = globalThis;
            \\globalThis.opener = null;
            \\globalThis.frames = globalThis;
            \\globalThis.length = 0;
            \\self.GLOBAL = {
            \\  isWindow: function() { return true; },
            \\  isWorker: function() { return false; },
            \\  isShadowRealm: function() { return false; },
            \\};
        ;

        _ = self.evaluateScript(setup_script) catch |err| {
            std.debug.print("ERROR: Failed to set up global aliases: {}\n", .{err});
            return err;
        };
    }

    /// Load page content (fetch, parse, execute)
    pub fn loadPage(self: *Context) !void {
        // TODO: Implement full page loading
        // For now, just ensure context is ready
        _ = self;
    }

    /// Evaluate JavaScript in this context
    pub fn evaluateScript(self: *Context, script: []const u8) !?*v8.ffi.Value {
        const isolate = self.isolate;
        const v8_ctx = self.v8_context orelse return error.NotInitialized;

        // Create V8 string from content
        const source_str = v8.ffi.v8_String_NewFromUtf8(isolate, script.ptr, @intCast(script.len)) orelse return error.StringCreateFailed;

        // Compile script
        const compiled = v8.ffi.v8_Script_Compile(v8_ctx, source_str) orelse {
            const exception = v8.ffi.v8_TryCatch_Exception(v8_ctx);
            if (exception) |exc| {
                const exc_str = v8.ffi.v8_Value_ToString(exc, v8_ctx);
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
        const result = v8.ffi.v8_Script_Run(v8_ctx, compiled) orelse {
            const exception = v8.ffi.v8_TryCatch_Exception(v8_ctx);
            if (exception) |exc| {
                const exc_str = v8.ffi.v8_Value_ToString(exc, v8_ctx);
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

        return result;
    }

    /// Deinitialize the context
    pub fn deinit(self: *Context) void {
        // Cleanup context manager
        if (self.v8_context) |ctx| {
            context_manager.deinit();

            // Exit and dispose V8 context
            v8.ffi.v8_Context_Exit(ctx);
            v8.ffi.v8_Context_Dispose(ctx);
        }

        self.allocator.free(self.url);
        self.initialized = false;
    }
};

// ============================================================================
// V8 Callback Implementations (stubs for now, full implementation in browser_context.zig)
// ============================================================================

fn setTimeoutCallback(_: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    // TODO: Implement using timer interface
}

fn clearTimeoutCallback(_: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    // TODO: Implement using timer interface
}

fn setIntervalCallback(_: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    // TODO: Implement using timer interface
}

fn addEventListenerCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    if (v8.ffi.v8_Undefined(isolate)) |undef| {
        info.setReturnValue(undef);
    }
}

fn removeEventListenerCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    if (v8.ffi.v8_Undefined(isolate)) |undef| {
        info.setReturnValue(undef);
    }
}

fn dispatchEventCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    if (v8.ffi.v8_Boolean_New(isolate, true)) |result| {
        info.setReturnValue(result);
    }
}
