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

// Worker types from html_core
const html_core = @import("html_core");
const workers = html_core.workers;
const WorkerContext = workers.WorkerContext;
const EngineCallbacks = workers.worker_context.EngineCallbacks;
const WorkerType = workers.WorkerType;

/// Opaque engine context type expected by WorkerContext
const EngineContext = workers.worker_context.EngineContext;

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

        // Enter the isolate
        v8.ffi.v8_Isolate_Enter(isolate);

        // Create V8 Context within the isolate
        const context = v8.ffi.v8_Context_New(isolate) orelse {
            v8.ffi.v8_Isolate_Exit(isolate);
            return error.V8ContextCreationFailed;
        };

        // Enter the context
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

        return self;
    }

    /// Clean up V8 isolate and context
    pub fn deinit(self: *Self) void {
        // Exit context
        v8.ffi.v8_Context_Exit(self.context);
        v8.ffi.v8_Context_Dispose(self.context);

        // Exit and dispose isolate
        v8.ffi.v8_Isolate_Exit(self.isolate);
        v8.ffi.v8_Isolate_Dispose(self.isolate);

        // Free allocations
        self.allocator.free(self.script_url);
        self.allocator.destroy(self);
    }

    /// Set up worker global scope
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
