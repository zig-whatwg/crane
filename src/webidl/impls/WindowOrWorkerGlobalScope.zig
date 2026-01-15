//! Implementation for WindowOrWorkerGlobalScope interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const WindowOrWorkerGlobalScope = interfaces.WindowOrWorkerGlobalScope;

pub const State = WindowOrWorkerGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Getter for origin
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for isSecureContext
pub fn get_isSecureContext(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for crossOriginIsolated
pub fn get_crossOriginIsolated(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for indexedDB
pub fn get_indexedDB(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for trustedTypes
pub fn get_trustedTypes(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for performance
pub fn get_performance(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for caches
pub fn get_caches(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for scheduler
pub fn get_scheduler(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for crypto
pub fn get_crypto(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: reportError
pub fn call_reportError(instance: *runtime.Instance, e: runtime.JSValue) anyerror!void {
    _ = instance;
    _ = e;
    return error.NotImplemented;
}

/// Operation: setInterval
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-setinterval
///
/// TODO: When implementing, the handler MUST be stored as a V8 Global handle
/// if handler.function is a JavaScript callback. See:
/// - tmp/analysis/CALLBACK_STORAGE.md for the pattern
/// - src/webidl/impls/WebSocket.zig for example usage of OptionalGlobalHandle
///
/// Implementation requirements:
/// 1. For handler.function variant, create Global handle
/// 2. Store in interval registry with Global handle
/// 3. Dispose Global handle when interval is cleared via clearInterval
/// 4. Handle repeating invocation pattern
pub fn call_setInterval(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
    _ = instance;
    _ = handler;
    _ = timeout;
    _ = arguments;
    return error.NotImplemented;
}

/// Operation: atob
pub fn call_atob(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.ByteString {
    _ = instance;
    _ = data;
    return error.NotImplemented;
}

/// Operation: btoa
pub fn call_btoa(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.DOMString {
    _ = instance;
    _ = data;
    return error.NotImplemented;
}

/// Operation: createImageBitmap
pub fn call_createImageBitmap(instance: *runtime.Instance, image: typedefs.ImageBitmapSource, options: webidl.Opt(dictionaries.ImageBitmapOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = image;
    _ = options;
    return error.NotImplemented;
}

/// Operation: clearInterval
pub fn call_clearInterval(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    _ = instance;
    _ = id;
    return error.NotImplemented;
}

/// Operation: queueMicrotask
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-queuemicrotask
///
/// Queues a microtask to invoke the callback. The callback is a V8 GlobalHandle
/// (tagged pointer) that will be invoked when the microtask queue is processed.
pub fn call_queueMicrotask(instance: *runtime.Instance, callback: callbacks.VoidFunction) anyerror!void {
    const v8_engine = @import("v8");
    const v8_ffi = v8_engine.ffi;
    const pointer_tag = v8_engine.pointer_tag;

    // Get the V8 context from the instance (engine_ctx is a V8 Context pointer)
    const v8_context: *v8_ffi.Context = @ptrCast(@alignCast(instance.ctx.engine_ctx orelse {
        return error.NotImplemented;
    }));

    // Get the current V8 isolate
    const isolate = v8_ffi.v8_Isolate_GetCurrent() orelse {
        return error.NotImplemented;
    };

    // The callback parameter is a tagged pointer to a V8 GlobalHandle (the JS function)
    // We need to untag it to get the actual pointer
    const callback_ptr: *const anyopaque = @ptrCast(callback);
    const untagged = pointer_tag.untagPointer(callback_ptr);

    // Verify it's a global handle (callback functions are always passed as global handles)
    if (untagged.tag != .global_handle and untagged.tag != .untagged) {
        return error.NotImplemented;
    }

    // The untagged pointer is the V8 Global<Function>* (the JS function)
    const js_function: *v8_ffi.Function = @ptrCast(@alignCast(untagged.ptr));

    // Allocate context for the microtask callback
    // This will be freed after the microtask executes
    const ctx = instance.ctx.allocator.create(MicrotaskContext) catch return error.OutOfMemory;
    ctx.* = .{
        .js_function = js_function,
        .v8_context = v8_context,
        .isolate = isolate,
        .allocator = instance.ctx.allocator,
    };

    // Queue the microtask with V8
    const callback_fn: ?*const anyopaque = @ptrCast(&microtaskCallback);
    v8_ffi.v8_Isolate_EnqueueMicrotask(isolate, callback_fn, ctx);
}

/// Context passed to the microtask callback
const MicrotaskContext = struct {
    js_function: *@import("v8").ffi.Function,
    v8_context: *@import("v8").ffi.Context,
    isolate: *@import("v8").ffi.Isolate,
    allocator: std.mem.Allocator,
};

/// Microtask callback that invokes the JS function
fn microtaskCallback(data: ?*anyopaque) callconv(.c) void {
    const v8_ffi = @import("v8").ffi;

    const ctx: *MicrotaskContext = @ptrCast(@alignCast(data orelse return));
    defer ctx.allocator.destroy(ctx);

    // Create a HandleScope for V8 operations
    const handle_scope = v8_ffi.v8_HandleScope_New(ctx.isolate);
    defer v8_ffi.v8_HandleScope_Dispose(handle_scope);

    // Call the function with no arguments and undefined as 'this'
    // v8_Function_CallWithReceiver_Safe signature: (context, function, receiver, argc, argv)
    const undefined_val = v8_ffi.v8_Undefined(ctx.isolate);
    _ = v8_ffi.v8_Function_CallWithReceiver_Safe(
        ctx.v8_context,
        ctx.js_function,
        undefined_val,
        0,
        null, // No arguments
    );

    // Dispose the global handle after execution
    v8_ffi.v8_Function_Dispose(ctx.js_function);
}

/// Operation: structuredClone
pub fn call_structuredClone(instance: *runtime.Instance, value: runtime.JSValue, options: webidl.Opt(dictionaries.StructuredSerializeOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = value;
    _ = options;
    return error.NotImplemented;
}

/// Operation: setTimeout
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-settimeout
///
/// TODO: When implementing, the handler MUST be stored as a V8 Global handle
/// if handler.function is a JavaScript callback. See:
/// - tmp/analysis/CALLBACK_STORAGE.md for the pattern
/// - src/webidl/impls/WebSocket.zig for example usage of OptionalGlobalHandle
///
/// Implementation requirements:
/// 1. For handler.function variant, create Global handle
/// 2. Store in timer registry with Global handle
/// 3. Dispose Global handle when timer fires or is cleared via clearTimeout
/// 4. Handle one-shot invocation (unlike setInterval)
pub fn call_setTimeout(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
    _ = instance;
    _ = handler;
    _ = timeout;
    _ = arguments;
    return error.NotImplemented;
}

/// Operation: clearTimeout
pub fn call_clearTimeout(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    _ = instance;
    _ = id;
    return error.NotImplemented;
}

/// Operation: fetch
pub fn call_fetch(instance: *runtime.Instance, input: typedefs.RequestInfo, init_data: webidl.Opt(dictionaries.RequestInit)) anyerror!runtime.JSValue {
    _ = instance;
    _ = input;
    _ = init_data;
    return error.NotImplemented;
}
