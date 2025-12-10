//! V8 Engine Interface Implementation
//!
//! This module provides the V8 implementation of the abstract EngineInterface.
//! It bridges the gap between engine-agnostic WebIDL impls and V8-specific code.
//!
//! ## Usage
//!
//! ```zig
//! const v8_engine = @import("v8").engine;
//! const runtime = @import("runtime");
//!
//! // Create context with V8 engine
//! var ctx_data = try runtime.ContextData.init(allocator, .{
//!     .engine = &v8_engine.v8_engine_interface,
//!     .engine_ctx = isolate,  // V8 Isolate pointer
//! });
//! ```

const std = @import("std");
const runtime = @import("runtime");
const EngineInterface = runtime.EngineInterface;
const EngineError = runtime.EngineError;

// V8 FFI and helpers
const ffi = @import("ffi.zig");
const async_iterator = @import("async_iterator.zig");
const promise_mod = @import("promise.zig");
const event_loop_mod = @import("event_loop.zig");
const callback_wrapper_mod = @import("callback_wrapper.zig");
const pointer_tag = @import("pointer_tag.zig");
const TaggedPointer = pointer_tag.TaggedPointer;
const DebugAssertions = pointer_tag.DebugAssertions;

// Logging for V8 exceptions
const log = std.log.scoped(.v8_engine);

// ============================================================================
// V8 Exception Logging Helpers
// ============================================================================

/// Log detailed V8 error information
/// Call this when a _Safe function returns an error to get full exception details.
fn logV8Error(error_info: *const ffi.V8ErrorInfo, operation: []const u8) void {
    if (!error_info.has_error) return;

    const message = error_info.getMessage() orelse "Unknown error";
    const resource = error_info.getResourceName() orelse "<unknown>";

    if (error_info.line_number >= 0) {
        log.err("{s} failed at {s}:{d}:{d}: {s}", .{
            operation,
            resource,
            error_info.line_number,
            error_info.column_number,
            message,
        });
    } else {
        log.err("{s} failed: {s}", .{ operation, message });
    }

    // Log source line if available
    if (error_info.getSourceLine()) |source_line| {
        log.err("  Source: {s}", .{source_line});
        // Add caret pointing to error column
        if (error_info.column_number >= 0 and error_info.column_number < 200) {
            var caret_buf: [256]u8 = undefined;
            const col: usize = @intCast(error_info.column_number);
            @memset(caret_buf[0..col], ' ');
            caret_buf[col] = '^';
            log.err("  {s}", .{caret_buf[0 .. col + 1]});
        }
    }

    // Log stack trace if available
    if (error_info.getStackTrace()) |stack| {
        log.err("Stack trace:\n{s}", .{stack});
    }
}

/// V8 implementation of the abstract EngineInterface
pub const v8_engine_interface: EngineInterface = .{
    .wrapAsyncIterator = v8WrapAsyncIterator,
    .createPromise = v8CreatePromise,
    .resolvePromise = v8ResolvePromise,
    .rejectPromise = v8RejectPromise,
    .getPromiseObject = v8GetPromiseObject,
    .destroyPromiseHandle = v8DestroyPromiseHandle,
    .createString = v8CreateString,
    .createArrayBuffer = v8CreateArrayBuffer,
    .createUint8Array = v8CreateUint8Array,
    .parseJson = v8ParseJson,
    .wrapInstance = v8WrapInstance,
    .isString = v8IsString,
    .extractString = v8ExtractString,
    .createStringArray = v8CreateStringArray,
    .createEventLoop = v8CreateEventLoop,
    .destroyEventLoop = v8DestroyEventLoop,
    .createCallbackWrapper = v8CreateCallbackWrapper,
    .invokeCallback = v8InvokeCallback,
    .destroyCallbackWrapper = v8DestroyCallbackWrapper,
    .requestGarbageCollection = v8RequestGarbageCollection,
    .scheduleOnMainThread = v8ScheduleOnMainThread,
    .invokeStreamCallback = v8InvokeStreamCallback,
    .getWrapperForInstance = v8GetWrapperForInstance,
    .chainPromiseHandlers = v8ChainPromiseHandlers,
    .compileScript = v8CompileScript,
    .runScript = v8RunScript,
    .compileModule = v8CompileModule,
    .runModule = v8RunModule,
    .disposeScript = v8DisposeScript,
    .disposeModule = v8DisposeModule,
    .runModuleAsync = v8RunModuleAsync,
    .hasTopLevelAwait = v8HasTopLevelAwait,
    .freeze = v8Freeze,
    .thaw = v8Thaw,
    .isFrozen = v8IsFrozen,
    .name = "V8",
    .version = "12.x", // TODO: Get actual version from V8
};

/// Promise handle for tracking V8 promise state
const V8PromiseHandle = struct {
    resolver: *ffi.PromiseResolver,
    promise: *ffi.Promise,
    isolate: *ffi.Isolate,
    context: *ffi.Context,
};

/// Wrap a Zig async iterator for V8
///
/// Takes a Zig ReadableStreamAsyncIterator and creates a V8 async iterator
/// object that JavaScript can use with `for await...of` loops.
fn v8WrapAsyncIterator(
    engine_ctx: *anyopaque,
    zig_iterator: *anyopaque,
) EngineError!*anyopaque {
    // engine_ctx is the V8 Context (set by context_manager.zig)
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    // Get current isolate - the context should be entered so this works
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Import the ReadableStreamAsyncIterator type
    const readable_stream_async_iterator = @import("streams_readable_stream_async_iterator");
    const ReadableStreamAsyncIterator = readable_stream_async_iterator.ReadableStreamAsyncIterator;

    const iterator: *ReadableStreamAsyncIterator = @ptrCast(@alignCast(zig_iterator));

    const v8_object = async_iterator.wrapAsyncIterator(isolate, context, iterator) catch
        return EngineError.AsyncIteratorError;

    return @ptrCast(v8_object);
}

/// Create a V8 Promise that can be resolved/rejected from Zig
fn v8CreatePromise(
    engine_ctx: *anyopaque,
    allocator: std.mem.Allocator,
) EngineError!*anyopaque {
    // engine_ctx is the V8 Context (set by context_manager.zig)
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    // Get current isolate - the context should be entered so this works
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    const resolver = ffi.v8_PromiseResolver_New(context) orelse
        return EngineError.PromiseError;

    const promise = ffi.v8_PromiseResolver_GetPromise(resolver) orelse {
        ffi.v8_PromiseResolver_Dispose(resolver);
        return EngineError.PromiseError;
    };

    // Allocate handle to track the promise
    const handle = allocator.create(V8PromiseHandle) catch
        return EngineError.OutOfMemory;

    handle.* = .{
        .resolver = resolver,
        .promise = promise,
        .isolate = isolate,
        .context = context,
    };

    return @ptrCast(handle);
}

/// Resolve a V8 Promise with a value
fn v8ResolvePromise(
    engine_ctx: *anyopaque,
    promise_handle: *anyopaque,
    value: ?*const anyopaque,
) EngineError!void {
    _ = engine_ctx;
    const handle: *V8PromiseHandle = @ptrCast(@alignCast(promise_handle));

    // Convert value to V8 Value, untagging if necessary
    const v8_value: *ffi.Value = if (value) |v| blk: {
        const tagged = TaggedPointer.fromRaw(@intFromPtr(v));
        const result = tagged.untagAs(*ffi.Value);
        DebugAssertions.logPointerUntagging(tagged.raw, @ptrCast(result), tagged.getTag());
        break :blk result;
    } else ffi.v8_Undefined(handle.isolate) orelse return EngineError.OperationFailed;

    if (!ffi.v8_PromiseResolver_Resolve(handle.resolver, handle.context, v8_value)) {
        return EngineError.PromiseError;
    }
}

/// Reject a V8 Promise with an error
fn v8RejectPromise(
    engine_ctx: *anyopaque,
    promise_handle: *anyopaque,
    err: anyerror,
) EngineError!void {
    _ = engine_ctx;
    const handle: *V8PromiseHandle = @ptrCast(@alignCast(promise_handle));

    // Create error message string
    const err_name = @errorName(err);
    const err_str = ffi.v8_String_NewFromUtf8(
        handle.isolate,
        err_name.ptr,
        @intCast(err_name.len),
    ) orelse return EngineError.OperationFailed;

    // Create appropriate Error object based on error type
    const err_obj = switch (err) {
        error.SyntaxError => ffi.v8_Exception_SyntaxError(err_str) orelse
            return EngineError.OperationFailed,
        error.TypeError => ffi.v8_Exception_TypeError(err_str) orelse
            return EngineError.OperationFailed,
        error.RangeError => ffi.v8_Exception_RangeError(err_str) orelse
            return EngineError.OperationFailed,
        else => ffi.v8_Exception_Error(err_str) orelse
            return EngineError.OperationFailed,
    };

    if (!ffi.v8_PromiseResolver_Reject(handle.resolver, handle.context, err_obj)) {
        return EngineError.PromiseError;
    }
}

/// Get the V8 Promise object to return to JavaScript
fn v8GetPromiseObject(promise_handle: *anyopaque) *anyopaque {
    const handle: *V8PromiseHandle = @ptrCast(@alignCast(promise_handle));
    return @ptrCast(handle.promise);
}

/// Destroy a V8 Promise handle after use
/// The Promise object itself remains valid (managed by V8 GC), but the
/// handle struct is freed.
fn v8DestroyPromiseHandle(promise_handle: *anyopaque, allocator: std.mem.Allocator) void {
    const handle: *V8PromiseHandle = @ptrCast(@alignCast(promise_handle));
    // Note: We don't dispose the resolver/promise here as they're V8-managed
    // and the Promise object needs to remain valid after this call.
    // The V8 GC will clean them up when the Promise is no longer referenced.
    allocator.destroy(handle);
}

/// Create a V8 String from UTF-8 bytes
fn v8CreateString(
    engine_ctx: *anyopaque,
    bytes: []const u8,
) EngineError!*anyopaque {
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    const v8_string = ffi.v8_String_NewFromUtf8(
        isolate,
        bytes.ptr,
        @intCast(bytes.len),
    ) orelse return EngineError.OperationFailed;

    return @ptrCast(v8_string);
}

/// Create a V8 ArrayBuffer from bytes
fn v8CreateArrayBuffer(
    engine_ctx: *anyopaque,
    bytes: []const u8,
) EngineError!*anyopaque {
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Create a new ArrayBuffer with the specified length
    const array_buffer = ffi.v8_ArrayBuffer_New(isolate, bytes.len) orelse
        return EngineError.OperationFailed;

    // Copy the bytes into the ArrayBuffer's backing store
    if (bytes.len > 0) {
        const data = ffi.v8_ArrayBuffer_Data(array_buffer) orelse
            return EngineError.OperationFailed;
        const dest: [*]u8 = @ptrCast(data);
        @memcpy(dest[0..bytes.len], bytes);
    }

    return @ptrCast(array_buffer);
}

/// Create a V8 Uint8Array from bytes
fn v8CreateUint8Array(
    engine_ctx: *anyopaque,
    bytes: []const u8,
) EngineError!*anyopaque {
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Create a backing ArrayBuffer
    const array_buffer = ffi.v8_ArrayBuffer_New(isolate, bytes.len) orelse
        return EngineError.OperationFailed;

    // Copy the bytes into the ArrayBuffer's backing store
    if (bytes.len > 0) {
        const data = ffi.v8_ArrayBuffer_Data(array_buffer) orelse
            return EngineError.OperationFailed;
        const dest: [*]u8 = @ptrCast(data);
        @memcpy(dest[0..bytes.len], bytes);
    }

    // Create Uint8Array view over the ArrayBuffer
    const uint8_array = ffi.v8_Uint8Array_New(isolate, array_buffer, 0, bytes.len) orelse
        return EngineError.OperationFailed;

    return @ptrCast(uint8_array);
}

/// Parse a JSON string and return a V8 value
fn v8ParseJson(
    engine_ctx: *anyopaque,
    json_str: []const u8,
) EngineError!*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Create V8 string from JSON
    const v8_str = ffi.v8_String_NewFromUtf8(
        isolate,
        json_str.ptr,
        @intCast(json_str.len),
    ) orelse return EngineError.OperationFailed;

    // JSON.parse needs the string as a JavaScript string literal
    // Build: JSON.parse('...escaped json...')

    // Escape the JSON for JavaScript string literal (escape backslashes and quotes)
    var escaped: std.ArrayListUnmanaged(u8) = .{};
    defer escaped.deinit(std.heap.c_allocator);

    // Start with JSON.parse('
    escaped.appendSlice(std.heap.c_allocator, "JSON.parse('") catch return EngineError.OutOfMemory;

    for (json_str) |c| {
        switch (c) {
            '\\' => escaped.appendSlice(std.heap.c_allocator, "\\\\") catch return EngineError.OutOfMemory,
            '\'' => escaped.appendSlice(std.heap.c_allocator, "\\'") catch return EngineError.OutOfMemory,
            '\n' => escaped.appendSlice(std.heap.c_allocator, "\\n") catch return EngineError.OutOfMemory,
            '\r' => escaped.appendSlice(std.heap.c_allocator, "\\r") catch return EngineError.OutOfMemory,
            '\t' => escaped.appendSlice(std.heap.c_allocator, "\\t") catch return EngineError.OutOfMemory,
            else => escaped.append(std.heap.c_allocator, c) catch return EngineError.OutOfMemory,
        }
    }

    // End with ')
    escaped.appendSlice(std.heap.c_allocator, "')") catch return EngineError.OutOfMemory;

    _ = v8_str; // Not used - we build the script directly

    const parse_str = ffi.v8_String_NewFromUtf8(
        isolate,
        escaped.items.ptr,
        @intCast(escaped.items.len),
    ) orelse return EngineError.OperationFailed;

    // Compile using safe variant for error reporting
    const compile_result = ffi.v8_Script_Compile_Safe(context, parse_str);
    defer ffi.v8_FreeScriptCompileResult(compile_result);

    if (compile_result.error_info) |err| {
        logV8Error(err, "JSON.parse compilation");
        return EngineError.OperationFailed;
    }

    const script = compile_result.script orelse
        return EngineError.OperationFailed;
    defer ffi.v8_Script_Dispose(script);

    // Run using safe variant for error reporting
    const run_result = ffi.v8_Script_Run_Safe(context, script);
    defer ffi.v8_FreeScriptRunResult(run_result);

    if (run_result.error_info) |err| {
        logV8Error(err, "JSON.parse execution");
        return EngineError.OperationFailed;
    }

    const result = run_result.value orelse
        return EngineError.OperationFailed;

    return @ptrCast(result);
}

/// Wrap a Zig runtime.Instance as a V8 object
fn v8WrapInstance(
    engine_ctx: *anyopaque,
    instance_ptr: *anyopaque,
) EngineError!*anyopaque {
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_ptr));

    // Use the conversions module to wrap the instance
    const conv = @import("conversions.zig");
    const v8_obj = conv.instanceToV8(isolate, instance);

    return @ptrCast(v8_obj);
}

/// Check if a V8 value is a string
fn v8IsString(
    js_value: *const anyopaque,
) bool {
    const tagged = TaggedPointer.fromRaw(@intFromPtr(js_value));
    const value = tagged.untagAs(*ffi.Value);
    DebugAssertions.logPointerUntagging(tagged.raw, @ptrCast(value), tagged.getTag());
    return ffi.v8_Value_IsString(value);
}

/// Extract a string from a V8 value
fn v8ExtractString(
    engine_ctx: *anyopaque,
    js_value: *const anyopaque,
    allocator: std.mem.Allocator,
) EngineError![]const u8 {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    const tagged = TaggedPointer.fromRaw(@intFromPtr(js_value));
    const value = tagged.untagAs(*ffi.Value);
    DebugAssertions.logPointerUntagging(tagged.raw, @ptrCast(value), tagged.getTag());

    // Use the conversions module to extract the string
    const conv = @import("conversions.zig");
    const dom_string = conv.fromV8String(allocator, isolate, context, @ptrCast(value)) catch
        return EngineError.OperationFailed;

    // Extract the slice from DOMString
    // Note: DOMString.asSlice() returns a slice, but the memory is managed by DOMString
    // We need to dupe the bytes to give caller ownership
    const slice = dom_string.asSlice();
    const owned_slice = allocator.dupe(u8, slice) catch
        return EngineError.OutOfMemory;

    return owned_slice;
}

/// Create a V8 array from a slice of strings
fn v8CreateStringArray(
    engine_ctx: *anyopaque,
    strings: []const []const u8,
) EngineError!*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Create a new V8 array with the given length
    const array = ffi.v8_Array_New(isolate, @intCast(strings.len));

    // Add each string to the array
    for (strings, 0..) |str, i| {
        const v8_str = ffi.v8_String_NewFromUtf8(isolate, str.ptr, @intCast(str.len)) orelse
            continue; // Skip on error
        _ = ffi.v8_Array_Set(array, context, @intCast(i), @ptrCast(v8_str));
    }

    return @ptrCast(array);
}

/// Create a V8 event loop
fn v8CreateEventLoop(
    engine_ctx: *anyopaque,
    allocator: std.mem.Allocator,
) EngineError!*anyopaque {
    // engine_ctx is the V8 Context, get the current isolate
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    const v8_loop_ptr = allocator.create(event_loop_mod.V8EventLoop) catch
        return EngineError.OutOfMemory;

    v8_loop_ptr.* = event_loop_mod.V8EventLoop.init(isolate, allocator) catch
        return EngineError.OperationFailed;

    return @ptrCast(v8_loop_ptr);
}

/// Destroy a V8 event loop
fn v8DestroyEventLoop(
    event_loop: *anyopaque,
    allocator: std.mem.Allocator,
) void {
    const v8_loop: *event_loop_mod.V8EventLoop = @ptrCast(@alignCast(event_loop));
    v8_loop.deinit();
    allocator.destroy(v8_loop);
}

// ============================================================================
// Callback Wrapper Implementation
// ============================================================================

/// Create a V8 callback wrapper from a JavaScript value
///
/// Used for WebIDL callback interfaces like EventListener.
/// Supports both direct function callbacks and object callbacks with methods.
fn v8CreateCallbackWrapper(
    engine_ctx: *anyopaque,
    js_value: *anyopaque,
    method_name: [*:0]const u8,
    allocator: std.mem.Allocator,
) EngineError!?*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;
    const value: *ffi.Value = @ptrCast(@alignCast(js_value));

    const wrapper = callback_wrapper_mod.createFromV8Value(
        allocator,
        isolate,
        context,
        value,
        method_name,
    ) catch return EngineError.OutOfMemory;

    if (wrapper) |w| {
        return @ptrCast(w);
    }
    return null;
}

/// Invoke a V8 callback wrapper with arguments
fn v8InvokeCallback(
    engine_ctx: *anyopaque,
    callback_wrapper: *anyopaque,
    args: [*]const *anyopaque,
    args_len: usize,
) EngineError!?*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const wrapper: *callback_wrapper_mod.CallbackWrapper = @ptrCast(@alignCast(callback_wrapper));

    // Convert args to V8 values
    const v8_args: [*]const *ffi.Value = @ptrCast(args);
    const v8_args_slice = v8_args[0..args_len];

    const result = wrapper.callN(context, v8_args_slice);
    if (result) |r| {
        return @ptrCast(r);
    }
    return null;
}

/// Destroy a V8 callback wrapper
fn v8DestroyCallbackWrapper(
    callback_wrapper: *anyopaque,
) void {
    const wrapper: *callback_wrapper_mod.CallbackWrapper = @ptrCast(@alignCast(callback_wrapper));
    wrapper.deinit();
}

// ============================================================================
// Garbage Collection (TestUtils support)
// ============================================================================

/// Request garbage collection via V8
///
/// Uses LowMemoryNotification() which triggers a full GC cycle.
/// Per WHATWG TestUtils spec: "Run implementation-defined steps to perform
/// a garbage collection covering at least the entry Realm."
fn v8RequestGarbageCollection(engine_ctx: *anyopaque) EngineError!void {
    // engine_ctx is the V8 Context, get the current isolate
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Use LowMemoryNotification which triggers a full GC
    // This is more reliable than RequestGarbageCollectionForTesting
    // and doesn't require special build flags
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
}

// ============================================================================
// Main Thread Scheduling
// ============================================================================

/// Schedule a callback on the main thread
///
/// For V8, we execute the callback immediately since we're typically
/// already on the main thread. A full implementation would use
/// platform->GetForegroundTaskRunner(isolate)->PostTask().
fn v8ScheduleOnMainThread(
    _: *anyopaque,
    callback: runtime.MainThreadCallback,
    user_data: *anyopaque,
) EngineError!void {
    // For now, execute immediately (assumes we're on main thread)
    // TODO: Use V8 platform task runner for true async scheduling
    callback(user_data);
}

// ============================================================================
// Stream Algorithm Callback Support
// ============================================================================

/// Invoke a JavaScript callback function for stream algorithms (pull, cancel, etc.)
///
/// This invokes a JS function that was stored during stream construction.
/// The function receives the controller as first argument and optional arg as second.
///
/// Arguments:
///   - engine_ctx: V8 Context pointer
///   - js_callback: V8 Global<Value>* pointing to the JS function
///   - controller_v8: V8 Object* for the controller wrapper (or null)
///   - arg: Optional V8 Value* for additional argument (e.g., cancel reason)
///
/// Returns:
///   - V8 Promise* from calling the function, or null on failure
fn v8InvokeStreamCallback(
    engine_ctx: *anyopaque,
    js_callback: *const anyopaque,
    controller_v8: ?*anyopaque,
    arg: ?*const anyopaque,
) EngineError!?*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Get the JS function value from the Global handle, untagging if necessary
    const tagged_callback = TaggedPointer.fromRaw(@intFromPtr(js_callback));
    const callback_value = tagged_callback.untagAs(*ffi.Value);
    DebugAssertions.logPointerUntagging(tagged_callback.raw, @ptrCast(callback_value), tagged_callback.getTag());

    // Check if it's actually a function
    if (!ffi.v8_Value_IsFunction(callback_value)) {
        return EngineError.TypeError;
    }

    const callback_fn: *ffi.Function = @ptrCast(callback_value);

    // Build arguments array
    var args: [2]*ffi.Value = undefined;
    var arg_count: usize = 0;

    // First argument: controller (if provided), untag if necessary
    if (controller_v8) |ctrl| {
        args[arg_count] = TaggedPointer.fromRaw(@intFromPtr(ctrl)).untagAs(*ffi.Value);
        arg_count += 1;
    }

    // Second argument: additional arg (if provided), untag if necessary
    if (arg) |a| {
        args[arg_count] = TaggedPointer.fromRaw(@intFromPtr(a)).untagAs(*ffi.Value);
        arg_count += 1;
    }

    // Get 'this' value (undefined for stream callbacks)
    const this_val = ffi.v8_Undefined(isolate) orelse
        return EngineError.OperationFailed;

    // Call the function using safe variant with TryCatch
    const args_ptr: [*]*ffi.Value = &args;
    const call_result = ffi.v8_Function_Call_Safe(
        callback_fn,
        context,
        this_val,
        @intCast(arg_count),
        if (arg_count > 0) args_ptr else null,
    );
    defer ffi.v8_FreeFunctionCallResult(call_result);

    // Check for error
    if (call_result.error_info) |err| {
        logV8Error(err, "Stream callback invocation");
        return null;
    }

    if (call_result.value) |r| {
        // If result is a Promise, return it directly
        if (ffi.v8_Value_IsPromise(r)) {
            return @ptrCast(r);
        }

        // If result is not a Promise, wrap it in a resolved Promise
        // Per spec, stream callbacks can return undefined or a Promise
        const resolver = ffi.v8_PromiseResolver_New(context) orelse
            return EngineError.PromiseError;
        _ = ffi.v8_PromiseResolver_Resolve(resolver, context, r);
        const promise = ffi.v8_PromiseResolver_GetPromise(resolver) orelse
            return EngineError.PromiseError;
        return @ptrCast(promise);
    }

    // Call returned null without error - unexpected
    log.warn("Stream callback returned null without error", .{});
    return null;
}

/// Get the V8 wrapper for a Zig runtime instance from the cache
///
/// Arguments:
///   - engine_ctx: V8 Context pointer (unused, cache has its own context)
///   - wrapper_cache: WrapperCache pointer
///   - instance: runtime.Instance pointer
///
/// Returns:
///   - V8 Object* if found in cache, null otherwise
fn v8GetWrapperForInstance(
    _: *anyopaque,
    wrapper_cache: *anyopaque,
    instance: *anyopaque,
) ?*anyopaque {
    const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
    const cache: *WrapperCache = @ptrCast(@alignCast(wrapper_cache));
    const inst: *runtime.Instance = @ptrCast(@alignCast(instance));

    if (cache.get(inst)) |wrapper| {
        return @ptrCast(wrapper);
    }
    return null;
}

/// Chain fulfillment/rejection handlers to a V8 Promise
///
/// Creates JavaScript functions that call into Zig when the promise settles.
/// Used to bridge V8 Promises to Zig AsyncPromise.
///
/// Arguments:
///   - engine_ctx: V8 Context pointer
///   - js_promise: V8 Promise* to chain handlers onto
///   - on_fulfill: Zig callback for fulfillment
///   - on_fulfill_ctx: Context passed to fulfillment callback
///   - on_reject: Zig callback for rejection
///   - on_reject_ctx: Context passed to rejection callback
fn v8ChainPromiseHandlers(
    engine_ctx: *anyopaque,
    js_promise: *anyopaque,
    on_fulfill: runtime.PromiseFulfillCallback,
    on_fulfill_ctx: ?*anyopaque,
    on_reject: runtime.PromiseRejectCallback,
    on_reject_ctx: ?*anyopaque,
) EngineError!void {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const promise: *ffi.Promise = @ptrCast(@alignCast(js_promise));

    // Create fulfill handler that calls Zig callback
    const fulfill_handler = ffi.v8_CreateZigFulfillHandler(
        context,
        on_fulfill,
        on_fulfill_ctx,
    ) orelse return EngineError.PromiseError;

    // Create reject handler that calls Zig callback
    const reject_handler = ffi.v8_CreateZigRejectHandler(
        context,
        on_reject,
        on_reject_ctx,
    ) orelse {
        ffi.v8_DisposeZigCallbackHandler(fulfill_handler);
        return EngineError.PromiseError;
    };

    // Chain the handlers onto the promise
    _ = ffi.v8_Promise_Then(promise, context, fulfill_handler, reject_handler) orelse {
        ffi.v8_DisposeZigCallbackHandler(reject_handler);
        ffi.v8_DisposeZigCallbackHandler(fulfill_handler);
        return EngineError.PromiseError;
    };

    // Note: The handlers are now owned by the promise chain
    // The callback data will be cleaned up when the handlers are GC'd
}

// ============================================================================
// Script Execution Support
// ============================================================================

/// Compile a classic script from source using V8
///
/// Compiles JavaScript source code into a V8 Script object.
///
/// Arguments:
///   - engine_ctx: V8 Context pointer
///   - source: UTF-8 encoded JavaScript source code
///   - source_url: Optional URL for error messages and source maps
///
/// Returns:
///   - V8 Script* on success
///   - null if compilation failed (syntax error)
///   - EngineError on engine-level failure
fn v8CompileScript(
    engine_ctx: *anyopaque,
    source: []const u8,
    source_url: ?[]const u8,
) EngineError!?*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Create V8 string from source
    const source_str = ffi.v8_String_NewFromUtf8(
        isolate,
        source.ptr,
        @intCast(source.len),
    ) orelse return EngineError.OutOfMemory;

    // Create resource name if URL provided
    var resource_name: ?*ffi.String = null;
    if (source_url) |url| {
        resource_name = ffi.v8_String_NewFromUtf8(
            isolate,
            url.ptr,
            @intCast(url.len),
        );
    }

    // Compile the script using safe variant with TryCatch
    const compile_result = if (resource_name) |name|
        ffi.v8_Script_CompileWithOrigin_Safe(context, source_str, name)
    else
        ffi.v8_Script_Compile_Safe(context, source_str);
    defer ffi.v8_FreeScriptCompileResult(compile_result);

    // Clean up resource name if created
    if (resource_name) |name| {
        ffi.v8_String_Dispose(name);
    }

    // Check for compilation error
    if (compile_result.error_info) |err| {
        logV8Error(err, "Script compilation");
        return null;
    }

    if (compile_result.script) |s| {
        return @ptrCast(s);
    }

    // Compilation failed without error info - unexpected
    log.warn("Script compilation returned null without error", .{});
    return null;
}

/// Run a compiled V8 script
///
/// Executes a previously compiled script in the current context.
///
/// Arguments:
///   - engine_ctx: V8 Context pointer
///   - script: V8 Script* from v8CompileScript
///
/// Returns:
///   - V8 Value* result on success
///   - null if execution threw an exception
///   - EngineError on engine-level failure
fn v8RunScript(
    engine_ctx: *anyopaque,
    script: *anyopaque,
) EngineError!?*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const v8_script: *ffi.Script = @ptrCast(@alignCast(script));

    // Run script using safe variant with TryCatch
    const run_result = ffi.v8_Script_Run_Safe(context, v8_script);
    defer ffi.v8_FreeScriptRunResult(run_result);

    // Check for execution error
    if (run_result.error_info) |err| {
        logV8Error(err, "Script execution");
        return null;
    }

    if (run_result.value) |r| {
        return @ptrCast(r);
    }

    // Execution returned null without error - unexpected
    log.warn("Script execution returned null without error", .{});
    return null;
}

/// Compile an ES module from source using V8
///
/// Compiles JavaScript module source code into a V8 Module object.
///
/// Arguments:
///   - engine_ctx: V8 Context pointer
///   - source: UTF-8 encoded JavaScript module source code
///   - source_url: URL for the module (required for import resolution)
///
/// Returns:
///   - V8 Module* on success
///   - null if compilation failed
///   - EngineError on engine-level failure
fn v8CompileModule(
    engine_ctx: *anyopaque,
    source: []const u8,
    source_url: []const u8,
) EngineError!?*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Create V8 string from source
    const source_str = ffi.v8_String_NewFromUtf8(
        isolate,
        source.ptr,
        @intCast(source.len),
    ) orelse return EngineError.OutOfMemory;

    // Create resource name (required for modules)
    const resource_name = ffi.v8_String_NewFromUtf8(
        isolate,
        source_url.ptr,
        @intCast(source_url.len),
    );

    // Compile as ES Module using safe variant with TryCatch
    const compile_result = ffi.v8_Module_Compile_Safe(context, source_str, resource_name);
    defer ffi.v8_FreeModuleCompileResult(compile_result);

    // Clean up strings (V8 manages the V8 string memory)
    if (resource_name) |name| {
        ffi.v8_String_Dispose(name);
    }

    // Check for compilation error
    if (compile_result.error_info) |err| {
        logV8Error(err, "Module compilation");
        return null;
    }

    if (compile_result.module) |m| {
        return @ptrCast(m);
    }

    // Compilation failed without error info - unexpected
    log.warn("Module compilation returned null without error", .{});
    return null;
}

/// Instantiate and evaluate a V8 module
///
/// Links module dependencies and executes the module's top-level code.
///
/// Arguments:
///   - engine_ctx: V8 Context pointer
///   - module: V8 Module* from v8CompileModule
///
/// Returns:
///   - void on success
///   - EngineError on instantiation or evaluation failure
fn v8RunModule(
    engine_ctx: *anyopaque,
    module: *anyopaque,
) EngineError!void {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const v8_module: *ffi.Module = @ptrCast(@alignCast(module));

    // Instantiate the module (link imports) using safe variant
    const instantiate_result = ffi.v8_Module_Instantiate_Safe(context, v8_module);
    defer ffi.v8_FreeModuleInstantiateResult(instantiate_result);

    if (instantiate_result.error_info) |err| {
        logV8Error(err, "Module instantiation");
        return EngineError.OperationFailed;
    }

    if (!instantiate_result.success) {
        log.err("Module instantiation failed without error details", .{});
        return EngineError.OperationFailed;
    }

    // Evaluate the module (execute top-level code) using safe variant
    const evaluate_result = ffi.v8_Module_Evaluate_Safe(context, v8_module);
    defer ffi.v8_FreeModuleEvaluateResult(evaluate_result);

    if (evaluate_result.error_info) |err| {
        logV8Error(err, "Module evaluation");
        return EngineError.OperationFailed;
    }

    // Success (value is discarded for sync evaluation)
}

/// Dispose of a compiled V8 script
///
/// Releases resources associated with a compiled script.
///
/// Arguments:
///   - script: V8 Script* from v8CompileScript
fn v8DisposeScript(
    script: *anyopaque,
) void {
    const v8_script: *ffi.Script = @ptrCast(@alignCast(script));
    ffi.v8_Script_Dispose(v8_script);
}

/// Dispose of a compiled V8 module
///
/// Releases resources associated with a compiled module.
///
/// Arguments:
///   - module: V8 Module* from v8CompileModule
fn v8DisposeModule(
    module: *anyopaque,
) void {
    const v8_module: *ffi.Module = @ptrCast(@alignCast(module));
    ffi.v8_Module_Dispose(v8_module);
}

/// Evaluate a V8 module asynchronously (for top-level await support)
///
/// Returns the evaluation Promise that resolves when the module finishes
/// executing, including any top-level await expressions.
///
/// Per HTML Standard "run a module script":
/// - Module.Evaluate() returns a Promise for TLA modules
/// - The Promise resolves with undefined on success
/// - The Promise rejects if there's an error during evaluation
///
/// Arguments:
///   - engine_ctx: V8 Context pointer
///   - module: V8 Module* (must be instantiated)
///
/// Returns:
///   - V8 Promise* that resolves when evaluation completes
///   - null if evaluation cannot start
///   - EngineError on engine-level failure
fn v8RunModuleAsync(
    engine_ctx: *anyopaque,
    module: *anyopaque,
) EngineError!?*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const v8_module: *ffi.Module = @ptrCast(@alignCast(module));

    // Instantiate the module if not already done (idempotent - V8 tracks module status)
    // Using safe variant for detailed error reporting
    const instantiate_result = ffi.v8_Module_Instantiate_Safe(context, v8_module);
    defer ffi.v8_FreeModuleInstantiateResult(instantiate_result);

    if (instantiate_result.error_info) |err| {
        logV8Error(err, "Module instantiation (async)");
        return EngineError.OperationFailed;
    }

    if (!instantiate_result.success) {
        log.err("Module instantiation failed without error details", .{});
        return EngineError.OperationFailed;
    }

    // Evaluate the module using safe variant - returns a Promise for TLA modules
    // For non-TLA modules, the Promise resolves immediately
    const evaluate_result = ffi.v8_Module_Evaluate_Safe(context, v8_module);
    defer ffi.v8_FreeModuleEvaluateResult(evaluate_result);

    if (evaluate_result.error_info) |err| {
        logV8Error(err, "Module evaluation (async)");
        return EngineError.OperationFailed;
    }

    if (evaluate_result.value) |result| {
        // V8's Module::Evaluate() always returns a Promise (as of V8 9.0+)
        // For modules without TLA, it's an already-resolved Promise
        // For modules with TLA, it resolves when async execution completes
        return @ptrCast(result);
    }

    // Evaluation returned null without error - unexpected
    log.warn("Module evaluation returned null without error", .{});
    return null;
}

/// Check if a V8 module contains top-level await
///
/// Uses V8's IsGraphAsync() to check if the module or any of its
/// dependencies contain top-level await, requiring async evaluation.
///
/// Arguments:
///   - module: V8 Module* (must be instantiated)
///
/// Returns:
///   - true if the module graph has TLA
///   - false otherwise
fn v8HasTopLevelAwait(
    module: *anyopaque,
) bool {
    const v8_module: *ffi.Module = @ptrCast(@alignCast(module));
    return ffi.v8_Module_IsGraphAsync(v8_module);
}

// ============================================================================
// Helper functions for V8-specific operations
// ============================================================================

/// Get the V8 Isolate from a runtime Context
///
/// This is a convenience function for code that needs direct V8 access.
/// Prefer using the EngineInterface methods when possible.
pub fn getIsolate(ctx: runtime.Context) ?*ffi.Isolate {
    const engine_ctx = ctx.getEngineContext() orelse return null;
    return @ptrCast(@alignCast(engine_ctx));
}

/// Get the V8 Context from a runtime Context
///
/// This is a convenience function for code that needs direct V8 access.
/// Prefer using the EngineInterface methods when possible.
pub fn getV8Context(ctx: runtime.Context) ?*ffi.Context {
    const isolate = getIsolate(ctx) orelse return null;
    return ffi.v8_Isolate_GetCurrentContext(isolate);
}

// ============================================================================
// Dynamic Import Support
// ============================================================================

/// Callback type for handling dynamic imports
///
/// This is the Zig-side callback that receives dynamic import requests from V8.
/// The callback receives:
///   - ctx: Context passed during registration
///   - referrer: Module specifier of the calling module (may be empty)
///   - specifier: The specifier passed to import()
///   - resolver: Handle to resolve/reject the import promise
///
/// The callback must call resolveDynamicImport or rejectDynamicImport to complete.
pub const DynamicImportHandler = struct {
    callback: *const fn (ctx: ?*anyopaque, referrer: []const u8, specifier: []const u8, resolver: DynamicImportResolver) void,
    context: ?*anyopaque,
};

/// Handle for resolving/rejecting a dynamic import
pub const DynamicImportResolver = struct {
    context: *anyopaque,
    resolver: *anyopaque,

    /// Resolve with a successfully loaded module's namespace
    pub fn resolve(self: DynamicImportResolver, module_namespace: *ffi.Object) void {
        ffi.v8_DynamicImport_Resolve(self.context, self.resolver, module_namespace);
    }

    /// Reject with an error message
    pub fn reject(self: DynamicImportResolver, error_message: []const u8) void {
        ffi.v8_DynamicImport_Reject(
            self.context,
            self.resolver,
            error_message.ptr,
            @intCast(error_message.len),
        );
    }
};

/// Global dynamic import handler (set per isolate)
var g_dynamic_import_handler: ?DynamicImportHandler = null;

/// FFI callback wrapper that converts C types to Zig types
fn dynamicImportCallbackWrapper(
    user_data: ?*anyopaque,
    context: ?*anyopaque,
    referrer_specifier: ?[*]const u8,
    referrer_len: c_int,
    specifier: [*]const u8,
    specifier_len: c_int,
    promise_resolver: *anyopaque,
) callconv(.c) void {
    _ = user_data;

    const handler = g_dynamic_import_handler orelse {
        // No handler registered, reject with error
        const ctx = context orelse return;
        ffi.v8_DynamicImport_Reject(
            ctx,
            promise_resolver,
            "No dynamic import handler registered".ptr,
            @intCast("No dynamic import handler registered".len),
        );
        return;
    };

    const ctx = context orelse return;

    // Convert referrer to slice
    const referrer = if (referrer_specifier) |ref|
        ref[0..@intCast(referrer_len)]
    else
        "";

    // Convert specifier to slice
    const spec = specifier[0..@intCast(specifier_len)];

    // Create resolver handle
    const resolver = DynamicImportResolver{
        .context = ctx,
        .resolver = promise_resolver,
    };

    // Call the Zig handler
    handler.callback(handler.context, referrer, spec, resolver);
}

/// Register a dynamic import handler for the given isolate
///
/// This enables import() expressions in JavaScript. When JavaScript calls import(),
/// V8 will invoke the handler which must:
/// 1. Fetch the requested module
/// 2. Compile and instantiate it
/// 3. Call resolver.resolve(namespace) or resolver.reject(error)
///
/// Example:
/// ```zig
/// fn handleDynamicImport(ctx: ?*anyopaque, referrer: []const u8, specifier: []const u8, resolver: DynamicImportResolver) void {
///     // Fetch and compile module...
///     const module = try compileModule(specifier);
///     const namespace = ffi.v8_Module_GetModuleNamespace(module);
///     resolver.resolve(namespace.?);
/// }
///
/// setDynamicImportHandler(isolate, .{
///     .callback = handleDynamicImport,
///     .context = my_context,
/// });
/// ```
pub fn setDynamicImportHandler(isolate: *ffi.Isolate, handler: DynamicImportHandler) void {
    g_dynamic_import_handler = handler;
    ffi.v8_Isolate_SetHostImportModuleDynamicallyCallback(
        isolate,
        handler.context,
        dynamicImportCallbackWrapper,
    );
}

/// Clear the dynamic import handler
pub fn clearDynamicImportHandler() void {
    g_dynamic_import_handler = null;
}

// ============================================================================
// Bfcache Freeze/Thaw Support
// ============================================================================

// Import the context manager for accessing event loops
const context_manager = @import("context_manager.zig");

/// Freeze a V8 context for the back-forward cache
///
/// This freezes the event loop associated with the context, stopping
/// all timer and task processing.
fn v8Freeze(
    engine_ctx: *anyopaque,
    context_handle: *anyopaque,
) EngineError!void {
    _ = context_handle;

    // engine_ctx is the V8 Context
    const v8_ctx: *ffi.Context = @ptrCast(@alignCast(engine_ctx));

    // Get the context entry which contains the event loop
    const ctx = context_manager.get(v8_ctx) orelse
        return EngineError.OperationFailed;

    // Get the event loop from context (use optional version for graceful handling)
    if (ctx.getOptionalEventLoop()) |ev_loop| {
        const event_loop_ptr = ev_loop.ptr;
        const v8_event_loop: *event_loop_mod.V8EventLoop = @ptrCast(@alignCast(event_loop_ptr));
        v8_event_loop.freeze() catch return EngineError.OperationFailed;
    }

    // Mark context as frozen (v8::Context::Exit is called by FrozenContextManager)
}

/// Thaw a V8 context from the back-forward cache
///
/// This resumes the event loop associated with the context.
fn v8Thaw(
    engine_ctx: *anyopaque,
    context_handle: *anyopaque,
) EngineError!void {
    _ = context_handle;

    // engine_ctx is the V8 Context
    const v8_ctx: *ffi.Context = @ptrCast(@alignCast(engine_ctx));

    // Re-enter the V8 context
    ffi.v8_Context_Enter(v8_ctx);

    // Get the context entry which contains the event loop
    const ctx = context_manager.get(v8_ctx) orelse
        return EngineError.OperationFailed;

    // Thaw the event loop (use optional version for graceful handling)
    if (ctx.getOptionalEventLoop()) |ev_loop| {
        const event_loop_ptr = ev_loop.ptr;
        const v8_event_loop: *event_loop_mod.V8EventLoop = @ptrCast(@alignCast(event_loop_ptr));
        v8_event_loop.thaw() catch return EngineError.OperationFailed;
    }
}

/// Check if a V8 context is currently frozen
fn v8IsFrozen(
    engine_ctx: *anyopaque,
    context_handle: *anyopaque,
) bool {
    _ = context_handle;

    // engine_ctx is the V8 Context
    const v8_ctx: *ffi.Context = @ptrCast(@alignCast(engine_ctx));

    // Get the context entry which contains the event loop
    const ctx = context_manager.get(v8_ctx) orelse return false;

    // Check if event loop is frozen (use optional version for graceful handling)
    if (ctx.getOptionalEventLoop()) |ev_loop| {
        const event_loop_ptr = ev_loop.ptr;
        const v8_event_loop: *event_loop_mod.V8EventLoop = @ptrCast(@alignCast(event_loop_ptr));
        return v8_event_loop.isFrozen();
    }

    return false;
}

// ============================================================================
// Tests
// ============================================================================

test "v8_engine_interface - has all required functions" {
    const testing = std.testing;

    try testing.expect(v8_engine_interface.wrapAsyncIterator != null);
    try testing.expect(v8_engine_interface.createPromise != null);
    try testing.expect(v8_engine_interface.resolvePromise != null);
    try testing.expect(v8_engine_interface.rejectPromise != null);
    try testing.expect(v8_engine_interface.getPromiseObject != null);
    try testing.expect(v8_engine_interface.createEventLoop != null);
    try testing.expect(v8_engine_interface.destroyEventLoop != null);
    try testing.expect(v8_engine_interface.createCallbackWrapper != null);
    try testing.expect(v8_engine_interface.invokeCallback != null);
    try testing.expect(v8_engine_interface.destroyCallbackWrapper != null);
    try testing.expectEqualStrings("V8", v8_engine_interface.name);
}
