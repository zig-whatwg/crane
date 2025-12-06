//! QuickJS Engine Interface Implementation
//!
//! This module provides the QuickJS implementation of the abstract EngineInterface.
//! It bridges the gap between engine-agnostic WebIDL impls and QuickJS-specific code.
//!
//! ## Design
//!
//! QuickJS uses a simpler model than V8/JSC:
//! - JSRuntime - manages memory, single-threaded, similar to an Isolate
//! - JSContext - execution context, can have multiple per runtime
//! - JSValue - 64-bit tagged union, not a pointer (unlike V8/JSC handles)
//! - Reference counting via JS_DupValue/JS_FreeValue
//!
//! ## Usage
//!
//! ```zig
//! const quickjs_engine = @import("quickjs").engine;
//! const runtime = @import("runtime");
//!
//! // Create context with QuickJS engine
//! var ctx_data = try runtime.ContextData.init(allocator, .{
//!     .engine = &quickjs_engine.quickjs_engine_interface,
//!     .engine_ctx = quickjs_context,  // *JSContext pointer
//! });
//! ```

const std = @import("std");
const runtime = @import("runtime");
const EngineInterface = runtime.EngineInterface;
const EngineError = runtime.EngineError;

// QuickJS FFI
const ffi = @import("ffi.zig");

/// QuickJS implementation of the abstract EngineInterface
pub const quickjs_engine_interface: EngineInterface = .{
    .wrapAsyncIterator = quickjsWrapAsyncIterator,
    .createPromise = quickjsCreatePromise,
    .resolvePromise = quickjsResolvePromise,
    .rejectPromise = quickjsRejectPromise,
    .getPromiseObject = quickjsGetPromiseObject,
    .createString = quickjsCreateString,
    .createArrayBuffer = quickjsCreateArrayBuffer,
    .createUint8Array = quickjsCreateUint8Array,
    .parseJson = quickjsParseJson,
    .wrapInstance = quickjsWrapInstance,
    .isString = quickjsIsString,
    .extractString = quickjsExtractString,
    .createStringArray = quickjsCreateStringArray,
    .createEventLoop = quickjsCreateEventLoop,
    .destroyEventLoop = quickjsDestroyEventLoop,
    .createCallbackWrapper = quickjsCreateCallbackWrapper,
    .invokeCallback = quickjsInvokeCallback,
    .destroyCallbackWrapper = quickjsDestroyCallbackWrapper,
    .requestGarbageCollection = quickjsRequestGarbageCollection,
    .scheduleOnMainThread = quickjsScheduleOnMainThread,
    .invokeStreamCallback = quickjsInvokeStreamCallback,
    .getWrapperForInstance = quickjsGetWrapperForInstance,
    .chainPromiseHandlers = quickjsChainPromiseHandlers,
    .compileScript = quickjsCompileScript,
    .runScript = quickjsRunScript,
    .compileModule = quickjsCompileModule,
    .runModule = quickjsRunModule,
    .disposeScript = quickjsDisposeScript,
    .disposeModule = quickjsDisposeModule,
    .runModuleAsync = quickjsRunModuleAsync,
    .hasTopLevelAwait = quickjsHasTopLevelAwait,
    .freeze = quickjsFreeze,
    .thaw = quickjsThaw,
    .isFrozen = quickjsIsFrozen,
    .name = "QuickJS",
    .version = "2024-01",
};

/// Promise handle for tracking QuickJS promise state
const QuickJSPromiseHandle = struct {
    ctx: *ffi.JSContext,
    promise: ffi.JSValue,
    resolve_fn: ffi.JSValue,
    reject_fn: ffi.JSValue,
};

/// Wrap a Zig async iterator for QuickJS
fn quickjsWrapAsyncIterator(
    engine_ctx: *anyopaque,
    zig_iterator: *anyopaque,
) EngineError!*anyopaque {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));
    _ = zig_iterator;

    // Create an object that implements the async iterator protocol
    // TODO: Implement full async iterator wrapping
    const obj = ffi.JS_NewObject(ctx);
    if (obj.isException()) {
        return EngineError.OperationFailed;
    }

    // Return a pointer to a heap-allocated JSValue
    // Since JSValue is a value type, we need to box it
    const boxed = std.heap.page_allocator.create(ffi.JSValue) catch
        return EngineError.OutOfMemory;
    boxed.* = obj;
    return @ptrCast(boxed);
}

/// Create a QuickJS Promise that can be resolved/rejected from Zig
fn quickjsCreatePromise(
    engine_ctx: *anyopaque,
    allocator: std.mem.Allocator,
) EngineError!*anyopaque {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));

    var resolving_funcs: [2]ffi.JSValue = undefined;
    const promise = ffi.JS_NewPromiseCapability(ctx, &resolving_funcs);

    if (promise.isException()) {
        return EngineError.PromiseError;
    }

    // Allocate handle to track the promise
    const handle = allocator.create(QuickJSPromiseHandle) catch
        return EngineError.OutOfMemory;

    handle.* = .{
        .ctx = ctx,
        .promise = promise,
        .resolve_fn = resolving_funcs[0],
        .reject_fn = resolving_funcs[1],
    };

    return @ptrCast(handle);
}

/// Resolve a QuickJS Promise with a value
fn quickjsResolvePromise(
    engine_ctx: *anyopaque,
    promise_handle: *anyopaque,
    value: ?*const anyopaque,
) EngineError!void {
    _ = engine_ctx;
    const handle: *QuickJSPromiseHandle = @ptrCast(@alignCast(promise_handle));

    // Convert value to QuickJS Value
    const qjs_value: ffi.JSValue = if (value) |v| blk: {
        const boxed: *const ffi.JSValue = @ptrCast(@alignCast(v));
        break :blk boxed.*;
    } else ffi.JSValue.UNDEFINED;

    const args = [_]ffi.JSValue{qjs_value};
    const result = ffi.JS_Call(
        handle.ctx,
        handle.resolve_fn,
        ffi.JSValue.UNDEFINED,
        1,
        &args,
    );

    if (result.isException()) {
        return EngineError.PromiseError;
    }

    // Free the result
    ffi.JS_FreeValue(handle.ctx, result);
}

/// Reject a QuickJS Promise with an error
fn quickjsRejectPromise(
    engine_ctx: *anyopaque,
    promise_handle: *anyopaque,
    err: anyerror,
) EngineError!void {
    _ = engine_ctx;
    const handle: *QuickJSPromiseHandle = @ptrCast(@alignCast(promise_handle));

    // Create error message string
    const err_name = @errorName(err);
    const err_value = ffi.JS_NewString(handle.ctx, err_name.ptr);
    if (err_value.isException()) {
        return EngineError.PromiseError;
    }

    // Create Error object
    const error_obj = ffi.JS_NewError(handle.ctx);
    if (error_obj.isException()) {
        ffi.JS_FreeValue(handle.ctx, err_value);
        return EngineError.PromiseError;
    }

    // Set the message property
    _ = ffi.JS_SetPropertyStr(handle.ctx, error_obj, "message", err_value);

    const args = [_]ffi.JSValue{error_obj};
    const result = ffi.JS_Call(
        handle.ctx,
        handle.reject_fn,
        ffi.JSValue.UNDEFINED,
        1,
        &args,
    );

    if (result.isException()) {
        return EngineError.PromiseError;
    }

    ffi.JS_FreeValue(handle.ctx, result);
}

/// Get the QuickJS Promise object to return to JavaScript
fn quickjsGetPromiseObject(promise_handle: *anyopaque) *anyopaque {
    const handle: *QuickJSPromiseHandle = @ptrCast(@alignCast(promise_handle));

    // Box the JSValue so we can return a pointer
    const boxed = std.heap.page_allocator.create(ffi.JSValue) catch
        return @ptrFromInt(0);
    boxed.* = handle.promise;
    return @ptrCast(boxed);
}

/// Create a QuickJS String from UTF-8 bytes
fn quickjsCreateString(
    engine_ctx: *anyopaque,
    bytes: []const u8,
) EngineError!*anyopaque {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));

    const value = ffi.createString(ctx, bytes);
    if (value.isException()) {
        return EngineError.OutOfMemory;
    }

    // Box the JSValue
    const boxed = std.heap.page_allocator.create(ffi.JSValue) catch
        return EngineError.OutOfMemory;
    boxed.* = value;
    return @ptrCast(boxed);
}

/// Create a QuickJS ArrayBuffer from bytes
fn quickjsCreateArrayBuffer(
    engine_ctx: *anyopaque,
    bytes: []const u8,
) EngineError!*anyopaque {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));

    // Create ArrayBuffer by copying data
    const buffer = ffi.JS_NewArrayBufferCopy(ctx, bytes.ptr, bytes.len);
    if (buffer.isException()) {
        return EngineError.OperationFailed;
    }

    // Box the JSValue
    const boxed = std.heap.page_allocator.create(ffi.JSValue) catch
        return EngineError.OutOfMemory;
    boxed.* = buffer;
    return @ptrCast(boxed);
}

/// Create a QuickJS Uint8Array from bytes
fn quickjsCreateUint8Array(
    engine_ctx: *anyopaque,
    bytes: []const u8,
) EngineError!*anyopaque {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));

    // First create an ArrayBuffer
    const buffer = ffi.JS_NewArrayBufferCopy(ctx, bytes.ptr, bytes.len);
    if (buffer.isException()) {
        return EngineError.OperationFailed;
    }

    // Create Uint8Array from the ArrayBuffer
    // QuickJS's JS_NewTypedArray takes constructor arguments
    var args = [_]ffi.JSValue{buffer};
    const typed_array = ffi.JS_NewTypedArray(ctx, 1, &args, 3); // 3 = Uint8Array
    ffi.JS_FreeValue(ctx, buffer);

    if (typed_array.isException()) {
        return EngineError.OperationFailed;
    }

    // Box the JSValue
    const boxed = std.heap.page_allocator.create(ffi.JSValue) catch
        return EngineError.OutOfMemory;
    boxed.* = typed_array;
    return @ptrCast(boxed);
}

/// Parse a JSON string and return a QuickJS value
fn quickjsParseJson(
    engine_ctx: *anyopaque,
    json_str: []const u8,
) EngineError!*anyopaque {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));

    const result = ffi.JS_ParseJSON(ctx, json_str.ptr, json_str.len, "<input>");
    if (result.isException()) {
        return EngineError.OperationFailed;
    }

    // Box the JSValue
    const boxed = std.heap.page_allocator.create(ffi.JSValue) catch
        return EngineError.OutOfMemory;
    boxed.* = result;
    return @ptrCast(boxed);
}

/// Wrap a Zig runtime.Instance as a QuickJS object
fn quickjsWrapInstance(
    engine_ctx: *anyopaque,
    instance_ptr: *anyopaque,
) EngineError!*anyopaque {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));

    // Create an object and store the instance pointer as opaque data
    const obj = ffi.JS_NewObject(ctx);
    if (obj.isException()) {
        return EngineError.OperationFailed;
    }

    ffi.JS_SetOpaque(obj, instance_ptr);

    // Box the JSValue
    const boxed = std.heap.page_allocator.create(ffi.JSValue) catch
        return EngineError.OutOfMemory;
    boxed.* = obj;
    return @ptrCast(boxed);
}

/// Check if a QuickJS value is a string
fn quickjsIsString(
    js_value: *const anyopaque,
) bool {
    const boxed: *const ffi.JSValue = @ptrCast(@alignCast(js_value));
    return boxed.isString();
}

/// Extract a string from a QuickJS value
fn quickjsExtractString(
    engine_ctx: *anyopaque,
    js_value: *const anyopaque,
    allocator: std.mem.Allocator,
) EngineError![]const u8 {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));
    const boxed: *const ffi.JSValue = @ptrCast(@alignCast(js_value));

    return ffi.extractString(ctx, boxed.*, allocator) catch return EngineError.TypeError;
}

/// Create a QuickJS array from a slice of strings
fn quickjsCreateStringArray(
    engine_ctx: *anyopaque,
    strings: []const []const u8,
) EngineError!*anyopaque {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));

    // Create array
    const array = ffi.JS_NewArray(ctx);
    if (array.isException()) {
        return EngineError.OperationFailed;
    }

    // Add each string
    for (strings, 0..) |str, i| {
        const str_val = ffi.createString(ctx, str);
        if (str_val.isException()) continue;

        _ = ffi.JS_SetPropertyUint32(ctx, array, @intCast(i), str_val);
    }

    // Box the JSValue
    const boxed = std.heap.page_allocator.create(ffi.JSValue) catch
        return EngineError.OutOfMemory;
    boxed.* = array;
    return @ptrCast(boxed);
}

/// Create a QuickJS event loop
fn quickjsCreateEventLoop(
    engine_ctx: *anyopaque,
    allocator: std.mem.Allocator,
) EngineError!*anyopaque {
    _ = engine_ctx;
    _ = allocator;
    // QuickJS doesn't have a built-in event loop
    // For now, return a placeholder
    return EngineError.OperationFailed;
}

/// Destroy a QuickJS event loop
fn quickjsDestroyEventLoop(
    event_loop: *anyopaque,
    allocator: std.mem.Allocator,
) void {
    _ = event_loop;
    _ = allocator;
}

/// Create a QuickJS callback wrapper from a JavaScript value
fn quickjsCreateCallbackWrapper(
    engine_ctx: *anyopaque,
    js_value: *anyopaque,
    method_name: [*:0]const u8,
    allocator: std.mem.Allocator,
) EngineError!?*anyopaque {
    _ = engine_ctx;
    _ = js_value;
    _ = method_name;
    _ = allocator;
    // TODO: Implement callback wrapper
    return null;
}

/// Invoke a QuickJS callback wrapper with arguments
fn quickjsInvokeCallback(
    engine_ctx: *anyopaque,
    callback_wrapper: *anyopaque,
    args: [*]const *anyopaque,
    args_len: usize,
) EngineError!?*anyopaque {
    _ = engine_ctx;
    _ = callback_wrapper;
    _ = args;
    _ = args_len;
    // TODO: Implement callback invocation
    return null;
}

/// Destroy a QuickJS callback wrapper
fn quickjsDestroyCallbackWrapper(
    callback_wrapper: *anyopaque,
) void {
    _ = callback_wrapper;
    // TODO: Implement cleanup
}

/// Request garbage collection via QuickJS
fn quickjsRequestGarbageCollection(engine_ctx: *anyopaque) EngineError!void {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));
    const rt = ffi.JS_GetRuntime(ctx);
    ffi.JS_RunGC(rt);
}

/// Schedule a callback on the main thread
fn quickjsScheduleOnMainThread(
    engine_ctx: *anyopaque,
    callback: runtime.MainThreadCallback,
    user_data: *anyopaque,
) EngineError!void {
    _ = engine_ctx;
    // QuickJS is single-threaded, execute immediately
    callback(user_data);
}

/// Invoke a JavaScript callback function for stream algorithms
fn quickjsInvokeStreamCallback(
    engine_ctx: *anyopaque,
    js_callback: *const anyopaque,
    controller_v8: ?*anyopaque,
    arg: ?*const anyopaque,
) EngineError!?*anyopaque {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));
    const callback_boxed: *const ffi.JSValue = @ptrCast(@alignCast(js_callback));

    // Build arguments array
    var args: [2]ffi.JSValue = undefined;
    var arg_count: c_int = 0;

    if (controller_v8) |ctrl| {
        const ctrl_boxed: *const ffi.JSValue = @ptrCast(@alignCast(ctrl));
        args[@intCast(arg_count)] = ctrl_boxed.*;
        arg_count += 1;
    }

    if (arg) |a| {
        const arg_boxed: *const ffi.JSValue = @ptrCast(@alignCast(a));
        args[@intCast(arg_count)] = arg_boxed.*;
        arg_count += 1;
    }

    const result = ffi.JS_Call(
        ctx,
        callback_boxed.*,
        ffi.JSValue.UNDEFINED,
        arg_count,
        if (arg_count > 0) &args else &[_]ffi.JSValue{},
    );

    if (result.isException()) {
        return null;
    }

    if (!result.isUndefined()) {
        // Box the result
        const boxed = std.heap.page_allocator.create(ffi.JSValue) catch
            return null;
        boxed.* = result;
        return @ptrCast(boxed);
    }

    return null;
}

/// Get the QuickJS wrapper for a Zig runtime instance
fn quickjsGetWrapperForInstance(
    engine_ctx: *anyopaque,
    wrapper_cache: *anyopaque,
    instance: *anyopaque,
) ?*anyopaque {
    _ = engine_ctx;
    _ = wrapper_cache;
    _ = instance;
    // TODO: Implement wrapper cache for QuickJS
    return null;
}

/// Chain a fulfillment/rejection handler to a QuickJS Promise
fn quickjsChainPromiseHandlers(
    engine_ctx: *anyopaque,
    js_promise: *anyopaque,
    on_fulfill: runtime.PromiseFulfillCallback,
    on_fulfill_ctx: ?*anyopaque,
    on_reject: runtime.PromiseRejectCallback,
    on_reject_ctx: ?*anyopaque,
) EngineError!void {
    _ = engine_ctx;
    _ = js_promise;
    _ = on_fulfill;
    _ = on_fulfill_ctx;
    _ = on_reject;
    _ = on_reject_ctx;
    // TODO: Implement promise chaining for QuickJS
    return EngineError.OperationFailed;
}

/// Compiled script handle for QuickJS
const CompiledScript = struct {
    source: []const u8,
    source_url: ?[]const u8,
};

/// Compile a classic script from source using QuickJS
fn quickjsCompileScript(
    engine_ctx: *anyopaque,
    source: []const u8,
    source_url: ?[]const u8,
) EngineError!?*anyopaque {
    _ = engine_ctx;
    // QuickJS doesn't have separate compile/run for scripts
    // Store the source for later evaluation
    const script = std.heap.page_allocator.create(CompiledScript) catch
        return EngineError.OutOfMemory;

    script.* = .{
        .source = source,
        .source_url = source_url,
    };

    return @ptrCast(script);
}

/// Run a compiled QuickJS script
fn quickjsRunScript(
    engine_ctx: *anyopaque,
    script: *anyopaque,
) EngineError!?*anyopaque {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));
    const compiled: *CompiledScript = @ptrCast(@alignCast(script));

    const filename = if (compiled.source_url) |url| url.ptr else "<script>";

    // Evaluate the script
    const result = ffi.JS_Eval(
        ctx,
        compiled.source.ptr,
        compiled.source.len,
        @ptrCast(filename),
        ffi.JS_EVAL_TYPE_GLOBAL,
    );

    if (result.isException()) {
        return EngineError.OperationFailed;
    }

    if (!result.isUndefined()) {
        const boxed = std.heap.page_allocator.create(ffi.JSValue) catch
            return EngineError.OutOfMemory;
        boxed.* = result;
        return @ptrCast(boxed);
    }

    return null;
}

/// Compiled module handle for QuickJS
const CompiledModule = struct {
    source: []const u8,
    source_url: []const u8,
    module_def: ?*ffi.JSModuleDef,
};

/// Compile an ES module from source using QuickJS
fn quickjsCompileModule(
    engine_ctx: *anyopaque,
    source: []const u8,
    source_url: []const u8,
) EngineError!?*anyopaque {
    _ = engine_ctx;
    // Store the module source for later evaluation
    const module = std.heap.page_allocator.create(CompiledModule) catch
        return EngineError.OutOfMemory;

    module.* = .{
        .source = source,
        .source_url = source_url,
        .module_def = null,
    };

    return @ptrCast(module);
}

/// Instantiate and evaluate a QuickJS module
fn quickjsRunModule(
    engine_ctx: *anyopaque,
    module: *anyopaque,
) EngineError!void {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));
    const compiled: *CompiledModule = @ptrCast(@alignCast(module));

    // Evaluate as module
    const result = ffi.JS_Eval(
        ctx,
        compiled.source.ptr,
        compiled.source.len,
        @ptrCast(compiled.source_url.ptr),
        ffi.JS_EVAL_TYPE_MODULE,
    );

    if (result.isException()) {
        return EngineError.OperationFailed;
    }

    ffi.JS_FreeValue(ctx, result);
}

/// Dispose of a compiled QuickJS script
fn quickjsDisposeScript(
    script: *anyopaque,
) void {
    const compiled: *CompiledScript = @ptrCast(@alignCast(script));
    std.heap.page_allocator.destroy(compiled);
}

/// Dispose of a compiled QuickJS module
fn quickjsDisposeModule(
    module: *anyopaque,
) void {
    const compiled: *CompiledModule = @ptrCast(@alignCast(module));
    std.heap.page_allocator.destroy(compiled);
}

/// Evaluate a QuickJS module asynchronously
fn quickjsRunModuleAsync(
    engine_ctx: *anyopaque,
    module: *anyopaque,
) EngineError!?*anyopaque {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));
    const compiled: *CompiledModule = @ptrCast(@alignCast(module));

    // Evaluate as module with async flag
    const result = ffi.JS_Eval(
        ctx,
        compiled.source.ptr,
        compiled.source.len,
        @ptrCast(compiled.source_url.ptr),
        ffi.JS_EVAL_TYPE_MODULE | ffi.JS_EVAL_FLAG_ASYNC,
    );

    if (result.isException()) {
        return EngineError.OperationFailed;
    }

    if (!result.isUndefined()) {
        const boxed = std.heap.page_allocator.create(ffi.JSValue) catch
            return EngineError.OutOfMemory;
        boxed.* = result;
        return @ptrCast(boxed);
    }

    return null;
}

/// Check if a QuickJS module contains top-level await
fn quickjsHasTopLevelAwait(
    module: *anyopaque,
) bool {
    _ = module;
    // QuickJS doesn't provide a way to check this
    // We'd need to parse the source manually
    return false;
}

// ============================================================================
// Bfcache Freeze/Thaw Support (Stub - QuickJS is single-threaded)
// ============================================================================

/// Freeze a QuickJS context for the back-forward cache
fn quickjsFreeze(
    engine_ctx: *anyopaque,
    context_handle: *anyopaque,
) EngineError!void {
    _ = engine_ctx;
    _ = context_handle;
    // QuickJS is embeddable and single-threaded
    // Bfcache is typically not applicable in the same way
    // Return success (no-op) for compatibility
}

/// Thaw a QuickJS context from the back-forward cache
fn quickjsThaw(
    engine_ctx: *anyopaque,
    context_handle: *anyopaque,
) EngineError!void {
    _ = engine_ctx;
    _ = context_handle;
    // Return success (no-op) for compatibility
}

/// Check if a QuickJS context is currently frozen
fn quickjsIsFrozen(
    engine_ctx: *anyopaque,
    context_handle: *anyopaque,
) bool {
    _ = engine_ctx;
    _ = context_handle;
    // Not tracked in this stub implementation
    return false;
}

// ============================================================================
// Tests
// ============================================================================

test "quickjs_engine_interface - has all required functions" {
    const testing = std.testing;

    try testing.expect(quickjs_engine_interface.wrapAsyncIterator != null);
    try testing.expect(quickjs_engine_interface.createPromise != null);
    try testing.expect(quickjs_engine_interface.resolvePromise != null);
    try testing.expect(quickjs_engine_interface.rejectPromise != null);
    try testing.expect(quickjs_engine_interface.getPromiseObject != null);
    try testing.expect(quickjs_engine_interface.createEventLoop != null);
    try testing.expect(quickjs_engine_interface.destroyEventLoop != null);
    try testing.expect(quickjs_engine_interface.createCallbackWrapper != null);
    try testing.expect(quickjs_engine_interface.invokeCallback != null);
    try testing.expect(quickjs_engine_interface.destroyCallbackWrapper != null);
    try testing.expectEqualStrings("QuickJS", quickjs_engine_interface.name);
}
