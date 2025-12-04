//! JSC Engine Interface Implementation
//!
//! This module provides the JavaScriptCore implementation of the abstract EngineInterface.
//! It bridges the gap between engine-agnostic WebIDL impls and JSC-specific code.
//!
//! ## Design
//!
//! JSC uses a different model than V8:
//! - Context Group (similar to V8 Isolate) - execution environment
//! - Global Context (similar to V8 Context) - JavaScript execution context
//! - Reference counting via JSValueProtect/Unprotect (vs V8 handles)
//!
//! ## Usage
//!
//! ```zig
//! const jsc_engine = @import("jsc").engine;
//! const runtime = @import("runtime");
//!
//! // Create context with JSC engine
//! var ctx_data = try runtime.ContextData.init(allocator, .{
//!     .engine = &jsc_engine.jsc_engine_interface,
//!     .engine_ctx = jsc_context,  // JSGlobalContextRef pointer
//! });
//! ```

const std = @import("std");
const runtime = @import("runtime");
const EngineInterface = runtime.EngineInterface;
const EngineError = runtime.EngineError;

// JSC FFI
const ffi = @import("ffi.zig");

/// JSC implementation of the abstract EngineInterface
pub const jsc_engine_interface: EngineInterface = .{
    .wrapAsyncIterator = jscWrapAsyncIterator,
    .createPromise = jscCreatePromise,
    .resolvePromise = jscResolvePromise,
    .rejectPromise = jscRejectPromise,
    .getPromiseObject = jscGetPromiseObject,
    .createString = jscCreateString,
    .createArrayBuffer = jscCreateArrayBuffer,
    .createUint8Array = jscCreateUint8Array,
    .parseJson = jscParseJson,
    .wrapInstance = jscWrapInstance,
    .isString = jscIsString,
    .extractString = jscExtractString,
    .createStringArray = jscCreateStringArray,
    .createEventLoop = jscCreateEventLoop,
    .destroyEventLoop = jscDestroyEventLoop,
    .createCallbackWrapper = jscCreateCallbackWrapper,
    .invokeCallback = jscInvokeCallback,
    .destroyCallbackWrapper = jscDestroyCallbackWrapper,
    .requestGarbageCollection = jscRequestGarbageCollection,
    .scheduleOnMainThread = jscScheduleOnMainThread,
    .invokeStreamCallback = jscInvokeStreamCallback,
    .getWrapperForInstance = jscGetWrapperForInstance,
    .chainPromiseHandlers = jscChainPromiseHandlers,
    .compileScript = jscCompileScript,
    .runScript = jscRunScript,
    .compileModule = jscCompileModule,
    .runModule = jscRunModule,
    .disposeScript = jscDisposeScript,
    .disposeModule = jscDisposeModule,
    .runModuleAsync = jscRunModuleAsync,
    .hasTopLevelAwait = jscHasTopLevelAwait,
    .name = "JavaScriptCore",
    .version = "WebKit",
};

/// Promise handle for tracking JSC promise state
const JSCPromiseHandle = struct {
    ctx: ffi.JSContextRef,
    promise: ffi.JSObjectRef,
    resolve_fn: ffi.JSObjectRef,
    reject_fn: ffi.JSObjectRef,
};

/// Wrap a Zig async iterator for JSC
fn jscWrapAsyncIterator(
    engine_ctx: *anyopaque,
    zig_iterator: *anyopaque,
) EngineError!*anyopaque {
    const ctx: ffi.JSContextRef = @ptrCast(@alignCast(engine_ctx));
    _ = zig_iterator;

    // Create an object that implements the async iterator protocol
    // TODO: Implement full async iterator wrapping
    const obj = ffi.JSObjectMake(ctx, null, null);
    return @ptrCast(obj);
}

/// Create a JSC Promise that can be resolved/rejected from Zig
fn jscCreatePromise(
    engine_ctx: *anyopaque,
    allocator: std.mem.Allocator,
) EngineError!*anyopaque {
    const ctx: ffi.JSContextRef = @ptrCast(@alignCast(engine_ctx));

    var resolve_fn: ?ffi.JSObjectRef = null;
    var reject_fn: ?ffi.JSObjectRef = null;
    var exception: ?ffi.JSValueRef = null;

    const promise = ffi.JSObjectMakeDeferredPromise(ctx, &resolve_fn, &reject_fn, &exception);

    if (exception != null) {
        return EngineError.PromiseError;
    }

    // Protect the promise and functions from GC
    ffi.JSValueProtect(ctx, @ptrCast(promise));
    if (resolve_fn) |rf| ffi.JSValueProtect(ctx, @ptrCast(rf));
    if (reject_fn) |rjf| ffi.JSValueProtect(ctx, @ptrCast(rjf));

    // Allocate handle to track the promise
    const handle = allocator.create(JSCPromiseHandle) catch
        return EngineError.OutOfMemory;

    handle.* = .{
        .ctx = ctx,
        .promise = promise,
        .resolve_fn = resolve_fn orelse return EngineError.PromiseError,
        .reject_fn = reject_fn orelse return EngineError.PromiseError,
    };

    return @ptrCast(handle);
}

/// Resolve a JSC Promise with a value
fn jscResolvePromise(
    engine_ctx: *anyopaque,
    promise_handle: *anyopaque,
    value: ?*const anyopaque,
) EngineError!void {
    _ = engine_ctx;
    const handle: *JSCPromiseHandle = @ptrCast(@alignCast(promise_handle));

    // Convert value to JSC Value
    const jsc_value: ffi.JSValueRef = if (value) |v|
        @ptrCast(@alignCast(@constCast(v)))
    else
        ffi.JSValueMakeUndefined(handle.ctx);

    var exception: ?ffi.JSValueRef = null;
    const args = [_]ffi.JSValueRef{jsc_value};

    _ = ffi.JSObjectCallAsFunction(
        handle.ctx,
        handle.resolve_fn,
        null,
        1,
        &args,
        &exception,
    );

    if (exception != null) {
        return EngineError.PromiseError;
    }
}

/// Reject a JSC Promise with an error
fn jscRejectPromise(
    engine_ctx: *anyopaque,
    promise_handle: *anyopaque,
    err: anyerror,
) EngineError!void {
    _ = engine_ctx;
    const handle: *JSCPromiseHandle = @ptrCast(@alignCast(promise_handle));

    // Create error message string
    const err_name = @errorName(err);
    const err_str = ffi.JSStringCreateWithUTF8CString(err_name.ptr);
    defer ffi.JSStringRelease(err_str);

    // Create Error object
    const msg_value = ffi.JSValueMakeString(handle.ctx, err_str);
    var exception: ?ffi.JSValueRef = null;
    const error_args = [_]ffi.JSValueRef{msg_value};

    const error_obj = ffi.JSObjectMakeError(handle.ctx, 1, &error_args, &exception);
    if (exception != null) {
        return EngineError.PromiseError;
    }

    const reject_args = [_]ffi.JSValueRef{@ptrCast(error_obj)};
    _ = ffi.JSObjectCallAsFunction(
        handle.ctx,
        handle.reject_fn,
        null,
        1,
        &reject_args,
        &exception,
    );

    if (exception != null) {
        return EngineError.PromiseError;
    }
}

/// Get the JSC Promise object to return to JavaScript
fn jscGetPromiseObject(promise_handle: *anyopaque) *anyopaque {
    const handle: *JSCPromiseHandle = @ptrCast(@alignCast(promise_handle));
    return @ptrCast(handle.promise);
}

/// Create a JSC String from UTF-8 bytes
fn jscCreateString(
    engine_ctx: *anyopaque,
    bytes: []const u8,
) EngineError!*anyopaque {
    const ctx: ffi.JSContextRef = @ptrCast(@alignCast(engine_ctx));

    // Create null-terminated string
    var buf: [8192]u8 = undefined;
    if (bytes.len >= buf.len) {
        return EngineError.OutOfMemory;
    }
    @memcpy(buf[0..bytes.len], bytes);
    buf[bytes.len] = 0;

    const jsc_str = ffi.JSStringCreateWithUTF8CString(@ptrCast(&buf));
    defer ffi.JSStringRelease(jsc_str);

    const value = ffi.JSValueMakeString(ctx, jsc_str);
    return @ptrCast(value);
}

/// Create a JSC ArrayBuffer from bytes
fn jscCreateArrayBuffer(
    engine_ctx: *anyopaque,
    bytes: []const u8,
) EngineError!*anyopaque {
    const ctx: ffi.JSContextRef = @ptrCast(@alignCast(engine_ctx));
    var exception: ?ffi.JSValueRef = null;

    // Create ArrayBuffer with the data
    // Note: JSC's ArrayBuffer API requires managing memory lifetime carefully
    const buffer = ffi.JSObjectMakeTypedArray(
        ctx,
        .kJSTypedArrayTypeArrayBuffer,
        bytes.len,
        &exception,
    );

    if (exception != null) {
        return EngineError.OperationFailed;
    }

    // Copy the bytes into the ArrayBuffer
    if (bytes.len > 0) {
        const data = ffi.JSObjectGetArrayBufferBytesPtr(ctx, buffer, &exception);
        if (data) |d| {
            const dest: [*]u8 = @ptrCast(d);
            @memcpy(dest[0..bytes.len], bytes);
        }
    }

    return @ptrCast(buffer);
}

/// Create a JSC Uint8Array from bytes
fn jscCreateUint8Array(
    engine_ctx: *anyopaque,
    bytes: []const u8,
) EngineError!*anyopaque {
    const ctx: ffi.JSContextRef = @ptrCast(@alignCast(engine_ctx));
    var exception: ?ffi.JSValueRef = null;

    // Create Uint8Array
    const typed_array = ffi.JSObjectMakeTypedArray(
        ctx,
        .kJSTypedArrayTypeUint8Array,
        bytes.len,
        &exception,
    );

    if (exception != null) {
        return EngineError.OperationFailed;
    }

    // Copy the bytes
    if (bytes.len > 0) {
        const data = ffi.JSObjectGetTypedArrayBytesPtr(ctx, typed_array, &exception);
        if (data) |d| {
            const dest: [*]u8 = @ptrCast(d);
            @memcpy(dest[0..bytes.len], bytes);
        }
    }

    return @ptrCast(typed_array);
}

/// Parse a JSON string and return a JSC value
fn jscParseJson(
    engine_ctx: *anyopaque,
    json_str: []const u8,
) EngineError!*anyopaque {
    const ctx: ffi.JSContextRef = @ptrCast(@alignCast(engine_ctx));

    // Create null-terminated string
    var buf: [65536]u8 = undefined;
    if (json_str.len >= buf.len) {
        return EngineError.OutOfMemory;
    }
    @memcpy(buf[0..json_str.len], json_str);
    buf[json_str.len] = 0;

    const jsc_str = ffi.JSStringCreateWithUTF8CString(@ptrCast(&buf));
    defer ffi.JSStringRelease(jsc_str);

    const result = ffi.JSValueMakeFromJSONString(ctx, jsc_str);
    if (@intFromPtr(result) == 0) {
        return EngineError.OperationFailed;
    }

    return @ptrCast(result);
}

/// Wrap a Zig runtime.Instance as a JSC object
fn jscWrapInstance(
    engine_ctx: *anyopaque,
    instance_ptr: *anyopaque,
) EngineError!*anyopaque {
    const ctx: ffi.JSContextRef = @ptrCast(@alignCast(engine_ctx));

    // Create an object and store the instance pointer as private data
    const obj = ffi.JSObjectMake(ctx, null, instance_ptr);
    return @ptrCast(obj);
}

/// Check if a JSC value is a string
fn jscIsString(
    js_value: *const anyopaque,
) bool {
    // We can't check without a context in JSC, but we can check the value's encoding
    // This is a limitation - caller should use context-aware version when possible
    _ = js_value;
    return false; // Conservative default
}

/// Extract a string from a JSC value
fn jscExtractString(
    engine_ctx: *anyopaque,
    js_value: *const anyopaque,
    allocator: std.mem.Allocator,
) EngineError![]const u8 {
    const ctx: ffi.JSContextRef = @ptrCast(@alignCast(engine_ctx));
    const value: ffi.JSValueRef = @ptrCast(@alignCast(@constCast(js_value)));
    var exception: ?ffi.JSValueRef = null;

    const jsc_str = ffi.JSValueToStringCopy(ctx, value, &exception);
    if (exception != null) {
        return EngineError.TypeError;
    }
    defer ffi.JSStringRelease(jsc_str);

    return ffi.getString(allocator, jsc_str) catch return EngineError.OutOfMemory;
}

/// Create a JSC array from a slice of strings
fn jscCreateStringArray(
    engine_ctx: *anyopaque,
    strings: []const []const u8,
) EngineError!*anyopaque {
    const ctx: ffi.JSContextRef = @ptrCast(@alignCast(engine_ctx));
    var exception: ?ffi.JSValueRef = null;

    // Create array
    const array = ffi.JSObjectMakeArray(ctx, 0, null, &exception);
    if (exception != null) {
        return EngineError.OperationFailed;
    }

    // Add each string
    for (strings, 0..) |str, i| {
        var buf: [8192]u8 = undefined;
        if (str.len >= buf.len) continue;
        @memcpy(buf[0..str.len], str);
        buf[str.len] = 0;

        const jsc_str = ffi.JSStringCreateWithUTF8CString(@ptrCast(&buf));
        defer ffi.JSStringRelease(jsc_str);

        const value = ffi.JSValueMakeString(ctx, jsc_str);
        ffi.JSObjectSetPropertyAtIndex(ctx, array, @intCast(i), value, &exception);
    }

    return @ptrCast(array);
}

/// Create a JSC event loop
fn jscCreateEventLoop(
    engine_ctx: *anyopaque,
    allocator: std.mem.Allocator,
) EngineError!*anyopaque {
    _ = engine_ctx;
    _ = allocator;
    // JSC on Apple platforms uses CFRunLoop, on other platforms uses GLib
    // For now, return a placeholder
    return EngineError.OperationFailed;
}

/// Destroy a JSC event loop
fn jscDestroyEventLoop(
    event_loop: *anyopaque,
    allocator: std.mem.Allocator,
) void {
    _ = event_loop;
    _ = allocator;
}

/// Create a JSC callback wrapper from a JavaScript value
fn jscCreateCallbackWrapper(
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

/// Invoke a JSC callback wrapper with arguments
fn jscInvokeCallback(
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

/// Destroy a JSC callback wrapper
fn jscDestroyCallbackWrapper(
    callback_wrapper: *anyopaque,
) void {
    _ = callback_wrapper;
    // TODO: Implement cleanup
}

/// Request garbage collection via JSC
fn jscRequestGarbageCollection(engine_ctx: *anyopaque) EngineError!void {
    const ctx: ffi.JSContextRef = @ptrCast(@alignCast(engine_ctx));
    ffi.JSGarbageCollect(ctx);
}

/// Schedule a callback on the main thread
fn jscScheduleOnMainThread(
    engine_ctx: *anyopaque,
    callback: runtime.MainThreadCallback,
    user_data: *anyopaque,
) EngineError!void {
    _ = engine_ctx;
    // For now, execute immediately (assumes we're on main thread)
    // TODO: Use CFRunLoop on macOS/iOS or GLib on other platforms
    callback(user_data);
}

/// Invoke a JavaScript callback function for stream algorithms
fn jscInvokeStreamCallback(
    engine_ctx: *anyopaque,
    js_callback: *const anyopaque,
    controller_v8: ?*anyopaque,
    arg: ?*const anyopaque,
) EngineError!?*anyopaque {
    const ctx: ffi.JSContextRef = @ptrCast(@alignCast(engine_ctx));
    const callback_fn: ffi.JSObjectRef = @ptrCast(@alignCast(@constCast(js_callback)));
    var exception: ?ffi.JSValueRef = null;

    // Build arguments array
    var args: [2]ffi.JSValueRef = undefined;
    var arg_count: usize = 0;

    if (controller_v8) |ctrl| {
        args[arg_count] = @ptrCast(@alignCast(ctrl));
        arg_count += 1;
    }

    if (arg) |a| {
        args[arg_count] = @ptrCast(@alignCast(@constCast(a)));
        arg_count += 1;
    }

    const result = ffi.JSObjectCallAsFunction(
        ctx,
        callback_fn,
        null,
        arg_count,
        if (arg_count > 0) &args else null,
        &exception,
    );

    if (exception != null) {
        return null;
    }

    if (@intFromPtr(result) != 0) {
        return @ptrCast(result);
    }

    return null;
}

/// Get the JSC wrapper for a Zig runtime instance
fn jscGetWrapperForInstance(
    engine_ctx: *anyopaque,
    wrapper_cache: *anyopaque,
    instance: *anyopaque,
) ?*anyopaque {
    _ = engine_ctx;
    _ = wrapper_cache;
    _ = instance;
    // TODO: Implement wrapper cache for JSC
    return null;
}

/// Chain a fulfillment/rejection handler to a JSC Promise
fn jscChainPromiseHandlers(
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
    // TODO: Implement promise chaining for JSC
    return EngineError.OperationFailed;
}

/// Compile a classic script from source using JSC
fn jscCompileScript(
    engine_ctx: *anyopaque,
    source: []const u8,
    source_url: ?[]const u8,
) EngineError!?*anyopaque {
    _ = engine_ctx;
    _ = source;
    _ = source_url;
    // JSC doesn't have separate compile/run - use JSEvaluateScript directly in runScript
    // Return a handle that stores the source for later evaluation
    return EngineError.OperationFailed;
}

/// Run a compiled JSC script
fn jscRunScript(
    engine_ctx: *anyopaque,
    script: *anyopaque,
) EngineError!?*anyopaque {
    _ = engine_ctx;
    _ = script;
    // TODO: Implement script execution
    return EngineError.OperationFailed;
}

/// Compile an ES module from source using JSC
fn jscCompileModule(
    engine_ctx: *anyopaque,
    source: []const u8,
    source_url: []const u8,
) EngineError!?*anyopaque {
    _ = engine_ctx;
    _ = source;
    _ = source_url;
    // JSC has module support via JSC's ModuleLoader
    // TODO: Implement module compilation
    return EngineError.OperationFailed;
}

/// Instantiate and evaluate a JSC module
fn jscRunModule(
    engine_ctx: *anyopaque,
    module: *anyopaque,
) EngineError!void {
    _ = engine_ctx;
    _ = module;
    // TODO: Implement module execution
    return EngineError.OperationFailed;
}

/// Dispose of a compiled JSC script
fn jscDisposeScript(
    script: *anyopaque,
) void {
    _ = script;
    // TODO: Implement cleanup
}

/// Dispose of a compiled JSC module
fn jscDisposeModule(
    module: *anyopaque,
) void {
    _ = module;
    // TODO: Implement cleanup
}

/// Evaluate a JSC module asynchronously
fn jscRunModuleAsync(
    engine_ctx: *anyopaque,
    module: *anyopaque,
) EngineError!?*anyopaque {
    _ = engine_ctx;
    _ = module;
    // TODO: Implement async module execution
    return EngineError.OperationFailed;
}

/// Check if a JSC module contains top-level await
fn jscHasTopLevelAwait(
    module: *anyopaque,
) bool {
    _ = module;
    // TODO: Implement TLA detection
    return false;
}

// ============================================================================
// Tests
// ============================================================================

test "jsc_engine_interface - has all required functions" {
    const testing = std.testing;

    try testing.expect(jsc_engine_interface.wrapAsyncIterator != null);
    try testing.expect(jsc_engine_interface.createPromise != null);
    try testing.expect(jsc_engine_interface.resolvePromise != null);
    try testing.expect(jsc_engine_interface.rejectPromise != null);
    try testing.expect(jsc_engine_interface.getPromiseObject != null);
    try testing.expect(jsc_engine_interface.createEventLoop != null);
    try testing.expect(jsc_engine_interface.destroyEventLoop != null);
    try testing.expect(jsc_engine_interface.createCallbackWrapper != null);
    try testing.expect(jsc_engine_interface.invokeCallback != null);
    try testing.expect(jsc_engine_interface.destroyCallbackWrapper != null);
    try testing.expectEqualStrings("JavaScriptCore", jsc_engine_interface.name);
}
