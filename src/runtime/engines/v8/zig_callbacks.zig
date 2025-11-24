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

/// User data structure passed to V8 callbacks
///
/// This allows V8 callbacks to call back into Zig code with context.
const CallbackUserData = struct {
    /// Function pointer (type-erased)
    fn_ptr: *const anyopaque,

    /// Optional user data for closure-like behavior
    user_data: ?*anyopaque,
};

/// Generic V8 callback that extracts Zig function and calls it
///
/// This is the actual C callback that V8 invokes. It:
/// 1. Extracts CallbackUserData from info.getData()
/// 2. Type-casts the function pointer
/// 3. Converts V8 arguments to Zig types (simplified for now)
/// 4. Calls the Zig function
/// 5. Converts return value to V8 (if any)
fn genericZigCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    // PLACEHOLDER: Just do nothing for now
    // TODO: Implement full callback trampolining when V8 FFI supports:
    // - v8_FunctionCallbackInfo_GetData()
    // - v8_FunctionCallbackInfo_GetIsolate()
    // - v8_FunctionCallbackInfo_SetReturnValue()
    // - v8_External_New() / v8_External_Value()
    //
    // When complete, this will:
    // 1. Extract CallbackUserData from info
    // 2. Call the Zig function with converted arguments
    // 3. Set return value on info
    _ = info;
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
    isolate: *v8.Isolate,
    context: *v8.Context,
    zig_fn: ZigFn,
    user_data: ?*anyopaque,
) CallbackError!*v8.Function {
    _ = zig_fn; // TODO: Store in CallbackUserData
    _ = user_data; // TODO: Store in CallbackUserData

    // Create FunctionTemplate with our generic callback
    // NOTE: We're not passing user data yet because we need v8_External_New
    // which isn't currently in the FFI bindings
    const template = v8.v8_FunctionTemplate_New(
        isolate,
        genericZigCallback,
        null, // TODO: Pass External with CallbackUserData
    ) orelse return CallbackError.TemplateFailed;
    defer v8.v8_FunctionTemplate_Dispose(template);

    // Get Function from template
    const function = v8.v8_FunctionTemplate_GetFunction(
        template,
        context,
    ) orelse return CallbackError.FunctionFailed;

    return function;
}

/// Simplified callback creator for void-returning functions
///
/// Many Streams callbacks return void (they're called for side effects).
/// This simplified version handles that common case.
///
/// Example:
/// ```zig
/// fn finishWrite(controller: *runtime.Instance, stream: *runtime.Instance) void {
///     // Implementation
/// }
///
/// const handler = try createVoidCallback(isolate, context);
/// defer v8.v8_Function_Dispose(handler);
/// ```
pub fn createVoidCallback(
    isolate: *v8.Isolate,
    context: *v8.Context,
) CallbackError!*v8.Function {
    // Create a function that just returns undefined
    const template = v8.v8_FunctionTemplate_New(
        isolate,
        genericZigCallback,
        null,
    ) orelse return CallbackError.TemplateFailed;
    defer v8.v8_FunctionTemplate_Dispose(template);

    const function = v8.v8_FunctionTemplate_GetFunction(
        template,
        context,
    ) orelse return CallbackError.FunctionFailed;

    return function;
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
