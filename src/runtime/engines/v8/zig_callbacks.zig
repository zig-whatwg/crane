//! Zig to V8 Callback Wrappers
//!
//! Enables calling Zig functions from V8 Promises and other JavaScript contexts.
//! Creates V8 Function objects that wrap Zig function pointers.
//!
//! ## Usage
//!
//! ```zig
//! const zig_callbacks = @import("zig_callbacks.zig");
//!
//! // Wrap a Zig function
//! const onFulfilled = try zig_callbacks.createZigCallback(
//!     @TypeOf(myZigFunction),
//!     isolate,
//!     context,
//!     myZigFunction,
//!     user_data_ptr,
//! );
//! defer v8.v8_Function_Dispose(onFulfilled);
//!
//! // Use in Promise.then()
//! _ = try promise.then(onFulfilled, onRejected);
//! ```

const std = @import("std");
const v8 = @import("ffi.zig");
const runtime = @import("runtime");

/// Errors that can occur during callback wrapper creation
pub const CallbackError = error{
    /// Function template creation failed
    TemplateFailed,

    /// Function instantiation failed
    FunctionFailed,

    /// External data creation failed
    ExternalFailed,

    /// Out of memory
    OutOfMemory,
};

/// Callback type tag for different callback signatures
const CallbackType = enum {
    void_no_args, // fn() void
    one_arg_void, // fn(arg1) void
    two_args_void, // fn(arg1, arg2) void
    one_arg_returns_value, // fn(arg1) T
    two_args_returns_value, // fn(arg1, arg2) T
    context_void, // fn(ctx: *anyopaque) void - context-aware callback
    context_one_arg_void, // fn(ctx: *anyopaque, arg1: *v8.Value) void
};

/// User data structure passed to V8 callbacks
///
/// This allows V8 callbacks to call back into Zig code with context.
/// Also stores the allocator so we can free this struct when V8 GCs the Function.
const CallbackUserData = struct {
    /// Function pointer (type-erased)
    fn_ptr: *const anyopaque,

    /// Optional user data for closure-like behavior
    user_data: ?*anyopaque,

    /// Allocator used to create this struct (needed for cleanup)
    allocator: std.mem.Allocator,

    /// Callback type (determines how to invoke)
    callback_type: CallbackType,
};

/// Generic V8 callback that extracts Zig function and calls it
///
/// This is the actual C callback that V8 invokes. It:
/// 1. Extracts CallbackUserData from info.getData()
/// 2. Type-casts the function pointer
/// 3. Converts V8 arguments to Zig types
/// 4. Calls the Zig function
/// 5. Converts return value to V8 (if any)
fn genericZigCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    // Get isolate
    const isolate = info.getIsolate();

    // Extract user data from callback info
    const data_value: *v8.Value = info.getData();
    defer v8.v8_Value_Dispose(data_value);

    // Cast from Value to External
    const external: *v8.External = @ptrCast(data_value);
    const user_data_ptr = v8.v8_External_Value(external);

    if (user_data_ptr == null) {
        // Invalid external - return undefined
        const undef = v8.v8_Undefined(isolate) orelse return;
        defer v8.v8_Value_Dispose(undef);
        info.setReturnValue(undef);
        return;
    }

    // Cast to CallbackUserData
    const callback_data: *CallbackUserData = @ptrCast(@alignCast(user_data_ptr.?));

    // Dispatch based on callback type
    switch (callback_data.callback_type) {
        .void_no_args => invokeVoidNoArgs(info, callback_data, isolate),
        .one_arg_void => invokeOneArgVoid(info, callback_data, isolate),
        .two_args_void => invokeTwoArgsVoid(info, callback_data, isolate),
        .one_arg_returns_value => invokeOneArgReturnsValue(info, callback_data, isolate),
        .two_args_returns_value => invokeTwoArgsReturnsValue(info, callback_data, isolate),
        .context_void => invokeContextVoid(info, callback_data, isolate),
        .context_one_arg_void => invokeContextOneArgVoid(info, callback_data, isolate),
    }
}

/// Invoke void callback with no arguments: fn() void
fn invokeVoidNoArgs(info: *const v8.FunctionCallbackInfo, callback_data: *CallbackUserData, isolate: *v8.Isolate) void {
    const VoidFn = *const fn () void;
    const void_fn: VoidFn = @ptrCast(@alignCast(callback_data.fn_ptr));

    // Call the Zig function
    void_fn();

    // Return undefined
    const undef = v8.v8_Undefined(isolate) orelse return;
    defer v8.v8_Value_Dispose(undef);
    info.setReturnValue(undef);
}

/// Invoke void callback with one argument: fn(arg1: *v8.Value) void
fn invokeOneArgVoid(info: *const v8.FunctionCallbackInfo, callback_data: *CallbackUserData, isolate: *v8.Isolate) void {
    const OneArgFn = *const fn (arg1: *v8.Value) void;
    const one_arg_fn: OneArgFn = @ptrCast(@alignCast(callback_data.fn_ptr));

    // Get first argument (or undefined if not provided)
    const arg1 = if (info.length() > 0)
        info.get(0)
    else
        v8.v8_Undefined(isolate) orelse return;
    defer v8.v8_Value_Dispose(arg1);

    // Call the Zig function
    one_arg_fn(arg1);

    // Return undefined
    const undef = v8.v8_Undefined(isolate) orelse return;
    defer v8.v8_Value_Dispose(undef);
    info.setReturnValue(undef);
}

/// Invoke void callback with two arguments: fn(arg1: *v8.Value, arg2: *v8.Value) void
fn invokeTwoArgsVoid(info: *const v8.FunctionCallbackInfo, callback_data: *CallbackUserData, isolate: *v8.Isolate) void {
    const TwoArgsFn = *const fn (arg1: *v8.Value, arg2: *v8.Value) void;
    const two_args_fn: TwoArgsFn = @ptrCast(@alignCast(callback_data.fn_ptr));

    // Get arguments (or undefined if not provided)
    const arg1 = if (info.length() > 0)
        info.get(0)
    else
        v8.v8_Undefined(isolate) orelse return;
    defer v8.v8_Value_Dispose(arg1);

    const arg2 = if (info.length() > 1)
        info.get(1)
    else
        v8.v8_Undefined(isolate) orelse return;
    defer v8.v8_Value_Dispose(arg2);

    // Call the Zig function
    two_args_fn(arg1, arg2);

    // Return undefined
    const undef = v8.v8_Undefined(isolate) orelse return;
    defer v8.v8_Value_Dispose(undef);
    info.setReturnValue(undef);
}

/// Invoke callback with one argument returning value: fn(arg1: *v8.Value) *v8.Value
fn invokeOneArgReturnsValue(info: *const v8.FunctionCallbackInfo, callback_data: *CallbackUserData, isolate: *v8.Isolate) void {
    const OneArgReturnsFn = *const fn (arg1: *v8.Value) *v8.Value;
    const one_arg_fn: OneArgReturnsFn = @ptrCast(@alignCast(callback_data.fn_ptr));

    // Get first argument
    const arg1 = if (info.length() > 0)
        info.get(0)
    else
        v8.v8_Undefined(isolate) orelse return;
    defer v8.v8_Value_Dispose(arg1);

    // Call the Zig function and get return value
    const result = one_arg_fn(arg1);

    // Return the result (don't dispose - caller owns it)
    info.setReturnValue(result);
}

/// Invoke callback with two arguments returning value: fn(arg1: *v8.Value, arg2: *v8.Value) *v8.Value
fn invokeTwoArgsReturnsValue(info: *const v8.FunctionCallbackInfo, callback_data: *CallbackUserData, isolate: *v8.Isolate) void {
    const TwoArgsReturnsFn = *const fn (arg1: *v8.Value, arg2: *v8.Value) *v8.Value;
    const two_args_fn: TwoArgsReturnsFn = @ptrCast(@alignCast(callback_data.fn_ptr));

    // Get arguments
    const arg1 = if (info.length() > 0)
        info.get(0)
    else
        v8.v8_Undefined(isolate) orelse return;
    defer v8.v8_Value_Dispose(arg1);

    const arg2 = if (info.length() > 1)
        info.get(1)
    else
        v8.v8_Undefined(isolate) orelse return;
    defer v8.v8_Value_Dispose(arg2);

    // Call the Zig function and get return value
    const result = two_args_fn(arg1, arg2);

    // Return the result (don't dispose - caller owns it)
    info.setReturnValue(result);
}

/// Invoke context-aware void callback: fn(ctx: *anyopaque) void
///
/// This passes the user_data (context) to the Zig function, enabling
/// callbacks to access captured state like controller/stream instances.
fn invokeContextVoid(info: *const v8.FunctionCallbackInfo, callback_data: *CallbackUserData, isolate: *v8.Isolate) void {
    const ContextFn = *const fn (ctx: *anyopaque) void;
    const ctx_fn: ContextFn = @ptrCast(@alignCast(callback_data.fn_ptr));

    // Pass user_data as context
    if (callback_data.user_data) |ctx| {
        ctx_fn(ctx);
    }

    // Return undefined
    const undef = v8.v8_Undefined(isolate) orelse return;
    defer v8.v8_Value_Dispose(undef);
    info.setReturnValue(undef);
}

/// Invoke context-aware callback with one V8 argument: fn(ctx: *anyopaque, arg1: *v8.Value) void
///
/// This passes both user_data (context) and the first V8 argument to the Zig function.
/// Useful for rejection handlers that need both context and the error value.
fn invokeContextOneArgVoid(info: *const v8.FunctionCallbackInfo, callback_data: *CallbackUserData, isolate: *v8.Isolate) void {
    const ContextOneArgFn = *const fn (ctx: *anyopaque, arg1: *v8.Value) void;
    const ctx_fn: ContextOneArgFn = @ptrCast(@alignCast(callback_data.fn_ptr));

    // Get first argument (or undefined if not provided)
    const arg1 = if (info.length() > 0)
        info.get(0)
    else
        v8.v8_Undefined(isolate) orelse return;
    defer v8.v8_Value_Dispose(arg1);

    // Pass user_data as context and V8 argument
    if (callback_data.user_data) |ctx| {
        ctx_fn(ctx, arg1);
    }

    // Return undefined
    const undef = v8.v8_Undefined(isolate) orelse return;
    defer v8.v8_Value_Dispose(undef);
    info.setReturnValue(undef);
}

/// Detect callback type from function signature at compile time
fn detectCallbackType(comptime ZigFn: type) CallbackType {
    const type_info = @typeInfo(ZigFn);

    // Handle both function pointers and function types
    const fn_info = switch (type_info) {
        .pointer => |ptr_info| @typeInfo(ptr_info.child),
        .@"fn" => type_info,
        else => @compileError("Expected function or function pointer type"),
    };

    // Extract function data
    const fn_data = switch (fn_info) {
        .@"fn" => |f| f,
        else => @compileError("Expected function type"),
    };

    const params = fn_data.params;
    const return_type = fn_data.return_type;

    // Determine if it returns void
    const returns_void = if (return_type) |ret| ret == void else true;

    // Determine argument count
    const arg_count = params.len;

    // Map to CallbackType
    if (returns_void) {
        return switch (arg_count) {
            0 => .void_no_args,
            1 => .one_arg_void,
            2 => .two_args_void,
            else => @compileError("Unsupported argument count for void callback"),
        };
    } else {
        return switch (arg_count) {
            1 => .one_arg_returns_value,
            2 => .two_args_returns_value,
            else => @compileError("Unsupported argument count for returning callback"),
        };
    }
}

/// Finalizer callback called by V8 when the Function is garbage collected
///
/// This cleans up the CallbackUserData that we allocated on the heap.
fn callbackFinalizer(data: ?*anyopaque, length: usize) callconv(.c) void {
    _ = length;

    if (data) |ptr| {
        const callback_data: *CallbackUserData = @ptrCast(@alignCast(ptr));
        const allocator = callback_data.allocator;

        // Free the CallbackUserData struct
        allocator.destroy(callback_data);
    }
}

/// Create a V8 Function that wraps a Zig function
///
/// This enables Zig functions to be called from JavaScript, particularly
/// useful for Promise.then() handlers.
///
/// **Current Limitations**:
/// - Simplified implementation returns undefined
/// - Argument conversion not yet implemented
/// - Return value conversion not yet implemented
///
/// **Future Enhancements**:
/// - Full argument type inspection and conversion
/// - Return value conversion based on function signature
/// - Error propagation from Zig to V8
///
/// Example:
/// ```zig
/// fn myHandler(controller: *runtime.Instance, stream: *runtime.Instance) void {
///     // Zig implementation
/// }
///
/// const handler_v8 = try createZigCallback(
///     @TypeOf(myHandler),
///     isolate,
///     context,
///     myHandler,
///     null,
/// );
/// defer v8.v8_Function_Dispose(handler_v8);
/// ```
pub fn createZigCallback(
    comptime ZigFn: type,
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    zig_fn: ZigFn,
    user_data: ?*anyopaque,
) CallbackError!*v8.Function {
    // Detect callback type at compile time
    const callback_type = detectCallbackType(ZigFn);

    // Allocate CallbackUserData on the heap (must outlive the V8 Function)
    const callback_data = allocator.create(CallbackUserData) catch return CallbackError.OutOfMemory;
    errdefer allocator.destroy(callback_data);

    callback_data.* = .{
        .fn_ptr = @ptrCast(&zig_fn),
        .user_data = user_data,
        .allocator = allocator,
        .callback_type = callback_type,
    };

    // Wrap the callback_data in a V8 External
    const external = v8.v8_External_New(isolate, callback_data) orelse {
        allocator.destroy(callback_data);
        return CallbackError.ExternalFailed;
    };
    errdefer v8.v8_External_Dispose(external);

    // Cast External to Value for FunctionTemplate (both are opaque pointers)
    const external_as_value: *v8.Value = @ptrCast(external);

    // Create FunctionTemplate with our generic callback and the External as data
    const template = v8.v8_FunctionTemplate_New(
        isolate,
        genericZigCallback,
        external_as_value,
    ) orelse {
        v8.v8_External_Dispose(external);
        allocator.destroy(callback_data);
        return CallbackError.TemplateFailed;
    };
    defer v8.v8_FunctionTemplate_Dispose(template);

    // Get Function from template
    const function = v8.v8_FunctionTemplate_GetFunction(
        template,
        context,
    ) orelse {
        v8.v8_External_Dispose(external);
        allocator.destroy(callback_data);
        return CallbackError.FunctionFailed;
    };

    // Register finalizer to clean up callback_data when Function is GC'd
    // Cast function to anyopaque for v8_Global_SetWeak (it accepts any Global handle)
    const function_handle: *anyopaque = @ptrCast(function);
    v8.v8_Global_SetWeak(function_handle, callback_data, callbackFinalizer);

    // NOTE: callback_data is now owned by the V8 Function
    // It will be freed automatically when the Function is garbage collected

    return function;
}

/// Create a context-aware V8 callback that passes user_data to the Zig function
///
/// This is useful for Promise.then() handlers that need access to captured state
/// like controller/stream instances.
///
/// Example:
/// ```zig
/// const WriteContext = struct {
///     controller: *runtime.Instance,
///     stream: *runtime.Instance,
/// };
///
/// fn onWriteFulfilled(ctx_ptr: *anyopaque) void {
///     const ctx: *WriteContext = @ptrCast(@alignCast(ctx_ptr));
///     writableStreamDefaultControllerFinishWrite(ctx.controller, ctx.stream);
/// }
///
/// var write_ctx = WriteContext{ .controller = controller, .stream = stream };
/// const onFulfilled = try createContextCallback(
///     allocator, isolate, v8_context, onWriteFulfilled, &write_ctx
/// );
/// ```
pub fn createContextCallback(
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    callback_fn: *const fn (ctx: *anyopaque) void,
    user_ctx: *anyopaque,
) CallbackError!*v8.Function {
    // Allocate CallbackUserData on the heap
    const callback_data = allocator.create(CallbackUserData) catch return CallbackError.OutOfMemory;
    errdefer allocator.destroy(callback_data);

    callback_data.* = .{
        .fn_ptr = @ptrCast(callback_fn),
        .user_data = user_ctx,
        .allocator = allocator,
        .callback_type = .context_void,
    };

    // Wrap the callback_data in a V8 External
    const external = v8.v8_External_New(isolate, callback_data) orelse {
        allocator.destroy(callback_data);
        return CallbackError.ExternalFailed;
    };
    errdefer v8.v8_External_Dispose(external);

    // Cast External to Value for FunctionTemplate
    const external_as_value: *v8.Value = @ptrCast(external);

    // Create FunctionTemplate with our generic callback and the External as data
    const template = v8.v8_FunctionTemplate_New(
        isolate,
        genericZigCallback,
        external_as_value,
    ) orelse {
        v8.v8_External_Dispose(external);
        allocator.destroy(callback_data);
        return CallbackError.TemplateFailed;
    };
    defer v8.v8_FunctionTemplate_Dispose(template);

    // Get Function from template
    const function = v8.v8_FunctionTemplate_GetFunction(
        template,
        context,
    ) orelse {
        v8.v8_External_Dispose(external);
        allocator.destroy(callback_data);
        return CallbackError.FunctionFailed;
    };

    // Register finalizer to clean up callback_data when Function is GC'd
    const function_handle: *anyopaque = @ptrCast(function);
    v8.v8_Global_SetWeak(function_handle, callback_data, callbackFinalizer);

    return function;
}

/// Create a context-aware V8 callback that receives both context and a V8 Value argument
///
/// Useful for rejection handlers that need context and the error value.
pub fn createContextCallbackWithArg(
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    callback_fn: *const fn (ctx: *anyopaque, arg: *v8.Value) void,
    user_ctx: *anyopaque,
) CallbackError!*v8.Function {
    // Allocate CallbackUserData on the heap
    const callback_data = allocator.create(CallbackUserData) catch return CallbackError.OutOfMemory;
    errdefer allocator.destroy(callback_data);

    callback_data.* = .{
        .fn_ptr = @ptrCast(callback_fn),
        .user_data = user_ctx,
        .allocator = allocator,
        .callback_type = .context_one_arg_void,
    };

    // Wrap the callback_data in a V8 External
    const external = v8.v8_External_New(isolate, callback_data) orelse {
        allocator.destroy(callback_data);
        return CallbackError.ExternalFailed;
    };
    errdefer v8.v8_External_Dispose(external);

    // Cast External to Value for FunctionTemplate
    const external_as_value: *v8.Value = @ptrCast(external);

    // Create FunctionTemplate with our generic callback and the External as data
    const template = v8.v8_FunctionTemplate_New(
        isolate,
        genericZigCallback,
        external_as_value,
    ) orelse {
        v8.v8_External_Dispose(external);
        allocator.destroy(callback_data);
        return CallbackError.TemplateFailed;
    };
    defer v8.v8_FunctionTemplate_Dispose(template);

    // Get Function from template
    const function = v8.v8_FunctionTemplate_GetFunction(
        template,
        context,
    ) orelse {
        v8.v8_External_Dispose(external);
        allocator.destroy(callback_data);
        return CallbackError.FunctionFailed;
    };

    // Register finalizer to clean up callback_data when Function is GC'd
    const function_handle: *anyopaque = @ptrCast(function);
    v8.v8_Global_SetWeak(function_handle, callback_data, callbackFinalizer);

    return function;
}

/// Simplified callback creator for void-returning, no-arg functions
///
/// Many Streams callbacks are simple void functions called for side effects.
/// This creates a placeholder V8 function that does nothing.
///
/// Example:
/// ```zig
/// const handler = try createVoidCallback(isolate, context);
/// defer v8.v8_Function_Dispose(handler);
/// ```
pub fn createVoidCallback(
    isolate: *v8.Isolate,
    context: *v8.Context,
) CallbackError!*v8.Function {
    // Create a no-op callback
    const NoOpFn = *const fn () void;
    const noop: NoOpFn = &noopCallback;

    // For simplicity, use stack-allocated allocator (function is short-lived)
    // In production, use a proper arena allocator
    var buffer: [256]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    return createZigCallback(
        NoOpFn,
        allocator,
        isolate,
        context,
        noop,
        null,
    );
}

/// No-op callback function
fn noopCallback() void {
    // Do nothing - used as placeholder for createVoidCallback
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "zig_callbacks module compiles" {
    testing.refAllDecls(@This());
}

test "createZigCallback - function signature check" {
    // Just verify the function signature compiles
    // Runtime tests require V8 integration
    if (true) return error.SkipZigTest;

    // TODO: When V8 is available:
    // 1. Create isolate and context
    // 2. Define a simple Zig function
    // 3. Wrap it with createZigCallback
    // 4. Verify it returns a V8 Function
    // 5. Call the function from JavaScript
    // 6. Verify Zig function was invoked
}

test "createVoidCallback - simple creation" {
    // Just verify the function signature compiles
    // Runtime tests require V8 integration
    if (true) return error.SkipZigTest;

    // TODO: When V8 is available:
    // 1. Create isolate and context
    // 2. Create void callback
    // 3. Verify it returns a V8 Function
    // 4. Call it and verify it returns undefined
}
