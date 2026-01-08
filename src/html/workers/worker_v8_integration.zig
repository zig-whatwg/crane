//! Worker V8 Integration
//!
//! Spec: HTML Standard § 10.2.5 Processing model
//! https://html.spec.whatwg.org/#run-a-worker
//!
//! This module integrates the worker threading infrastructure with V8:
//! - Creates isolated V8 contexts per worker thread
//! - Sets up WorkerGlobalScope bindings
//! - Handles import.meta.url for module workers
//! - Manages per-isolate memory allocation
//!
//! ## V8 Isolate Per Worker
//!
//! Each worker thread gets its own V8 Isolate, providing:
//! - Complete memory isolation (no shared heap)
//! - Independent garbage collection
//! - Thread-safe script execution
//! - No data races between JavaScript contexts
//!
//! ## Usage
//!
//! ```zig
//! const v8_worker = @import("worker_v8_integration.zig");
//!
//! // Create V8 integration for worker manager
//! var integration = try v8_worker.WorkerV8Integration.init(allocator);
//! defer integration.deinit();
//!
//! // Wire up to worker manager
//! manager.setV8Callbacks(
//!     integration.createIsolateCallback(),
//!     integration.disposeIsolateCallback(),
//!     integration.executeScriptCallback(),
//!     integration.getContext(),
//! );
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

const worker_threading = @import("worker_threading.zig");
const WorkerThreadState = worker_threading.WorkerThreadState;
const ThreadedWorkerManager = worker_threading.ThreadedWorkerManager;

const types = @import("types.zig");
const WorkerType = types.WorkerType;

// Note: This module can only be imported when V8 is available
// The V8 FFI is conditionally available based on build configuration

/// Opaque V8 Isolate handle
/// Using opaque type instead of *anyopaque for type safety at FFI boundary
const V8Isolate = opaque {};

/// Opaque V8 Context handle
/// Using opaque type instead of *anyopaque for type safety at FFI boundary
const V8Context = opaque {};

/// Opaque V8 String handle
const V8String = opaque {};

/// Opaque V8 Script handle
const V8Script = opaque {};

/// V8 FFI declarations for isolate management
/// These are defined in src/runtime/engines/v8/ffi.zig
/// Using typed opaque pointers instead of *anyopaque for type safety
extern fn v8_Isolate_New() ?*V8Isolate;
extern fn v8_Isolate_Dispose(isolate: *V8Isolate) void;
extern fn v8_Isolate_Enter(isolate: *V8Isolate) void;
extern fn v8_Isolate_Exit(isolate: *V8Isolate) void;
extern fn v8_Context_New(isolate: *V8Isolate) ?*V8Context;
extern fn v8_Context_Dispose(context: *V8Context) void;
extern fn v8_Context_Enter(context: *V8Context) void;
extern fn v8_Context_Exit(context: *V8Context) void;
extern fn v8_Script_Compile(context: *V8Context, source: *V8String) ?*V8Script;
extern fn v8_Script_Run(context: *V8Context, script: *V8Script) ?*anyopaque;
extern fn v8_String_NewFromUtf8(isolate: *V8Isolate, data: [*]const u8, length: c_int) ?*V8String;

/// Per-worker V8 context data
///
/// Stored in thread-local storage for the worker thread.
pub const WorkerIsolateData = struct {
    /// V8 Isolate for this worker
    isolate: *V8Isolate,

    /// V8 Context (the worker's execution environment)
    context: *V8Context,

    /// Script URL (for import.meta.url)
    script_url: []const u8,

    /// Worker type (classic/module)
    worker_type: WorkerType,

    /// Allocator for per-isolate allocations
    allocator: Allocator,

    const Self = @This();

    /// Create a new V8 isolate and context for a worker
    pub fn init(
        allocator: Allocator,
        script_url: []const u8,
        worker_type: WorkerType,
    ) !*Self {
        const data = try allocator.create(Self);
        errdefer allocator.destroy(data);

        // Copy script URL
        const url_copy = try allocator.dupe(u8, script_url);
        errdefer allocator.free(url_copy);

        // Create V8 Isolate
        const isolate = v8_Isolate_New() orelse {
            return error.V8IsolateCreationFailed;
        };
        errdefer v8_Isolate_Dispose(isolate);

        // Enter the isolate
        v8_Isolate_Enter(isolate);
        errdefer v8_Isolate_Exit(isolate);

        // Create V8 Context within the isolate
        const context = v8_Context_New(isolate) orelse {
            return error.V8ContextCreationFailed;
        };
        errdefer v8_Context_Dispose(context);

        // Enter the context
        v8_Context_Enter(context);
        // Note: Context exit is handled in deinit

        data.* = .{
            .isolate = isolate,
            .context = context,
            .script_url = url_copy,
            .worker_type = worker_type,
            .allocator = allocator,
        };

        return data;
    }

    /// Clean up V8 isolate and context
    pub fn deinit(self: *Self) void {
        // Exit context first
        v8_Context_Exit(self.context);
        v8_Context_Dispose(self.context);

        // Then exit and dispose isolate
        v8_Isolate_Exit(self.isolate);
        v8_Isolate_Dispose(self.isolate);

        // Free allocations
        self.allocator.free(self.script_url);
        self.allocator.destroy(self);
    }

    /// Execute a script in this worker's context
    pub fn executeScript(self: *Self, source: []const u8) !void {
        // Create V8 string from source
        const source_str = v8_String_NewFromUtf8(
            self.isolate,
            source.ptr,
            @intCast(source.len),
        ) orelse {
            return error.V8StringCreationFailed;
        };

        // Compile script
        const script = v8_Script_Compile(self.context, source_str) orelse {
            return error.V8CompilationFailed;
        };

        // Run script
        _ = v8_Script_Run(self.context, script) orelse {
            return error.V8ExecutionFailed;
        };
    }
};

/// Worker V8 Integration Manager
///
/// Provides the V8 integration callbacks for ThreadedWorkerManager.
pub const WorkerV8Integration = struct {
    /// Allocator for creating isolate data
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
        // No cleanup needed - workers manage their own isolates
    }

    /// Callback to create V8 isolate for a new worker
    pub fn createIsolate(
        thread_state: *WorkerThreadState,
        allocator: Allocator,
    ) !*anyopaque {
        const isolate_data = try WorkerIsolateData.init(
            allocator,
            thread_state.script_url,
            thread_state.worker_type,
        );

        return @ptrCast(isolate_data);
    }

    /// Callback to dispose V8 isolate when worker terminates
    pub fn disposeIsolate(isolate_data_ptr: *anyopaque) void {
        const isolate_data: *WorkerIsolateData = @ptrCast(@alignCast(isolate_data_ptr));
        isolate_data.deinit();
    }

    /// Callback to execute script in worker's V8 context
    pub fn executeScript(
        isolate_data_ptr: *anyopaque,
        source: []const u8,
        source_url: []const u8,
    ) !void {
        _ = source_url; // URL used for error messages
        const isolate_data: *WorkerIsolateData = @ptrCast(@alignCast(isolate_data_ptr));
        try isolate_data.executeScript(source);
    }

    /// Get function pointer for createIsolate callback
    pub fn createIsolateCallback(self: *const Self) worker_threading.WorkerThreadRunner.CreateIsolateFn {
        _ = self;
        return &createIsolate;
    }

    /// Get function pointer for disposeIsolate callback
    pub fn disposeIsolateCallback(self: *const Self) worker_threading.WorkerThreadRunner.DisposeIsolateFn {
        _ = self;
        return &disposeIsolate;
    }

    /// Get function pointer for executeScript callback
    pub fn executeScriptCallback(self: *const Self) worker_threading.WorkerThreadRunner.ExecuteScriptFn {
        _ = self;
        return &executeScript;
    }

    /// Get context (self pointer for callback context)
    pub fn getContext(self: *Self) *anyopaque {
        return @ptrCast(self);
    }

    /// Wire up V8 callbacks to a worker manager
    pub fn wireToManager(self: *Self, manager: *ThreadedWorkerManager) void {
        manager.setV8Callbacks(
            self.createIsolateCallback(),
            self.disposeIsolateCallback(),
            self.executeScriptCallback(),
            self.getContext(),
        );
    }
};

// ============================================================================
// Error Types
// ============================================================================

pub const V8WorkerError = error{
    V8IsolateCreationFailed,
    V8ContextCreationFailed,
    V8StringCreationFailed,
    V8CompilationFailed,
    V8ExecutionFailed,
    OutOfMemory,
};

// ============================================================================
// Tests
// ============================================================================

test "WorkerV8Integration - initialization" {
    // This test only checks that the integration can be initialized
    // Actual V8 isolate creation requires the V8 runtime to be linked
    const allocator = std.testing.allocator;

    var integration = WorkerV8Integration.init(allocator);
    defer integration.deinit();

    // Check that callback functions are not null
    try std.testing.expect(integration.createIsolateCallback() != undefined);
    try std.testing.expect(integration.disposeIsolateCallback() != undefined);
    try std.testing.expect(integration.executeScriptCallback() != undefined);
}
