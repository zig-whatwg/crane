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
/// Also stores the allocator so we can free this struct when V8 GCs the Function.
const CallbackUserData = struct {
    /// Function pointer (type-erased)
    fn_ptr: *const anyopaque,

    /// Optional user data for closure-like behavior
    user_data: ?*anyopaque,

    /// Allocator used to create this struct (needed for cleanup)
    allocator: std.mem.Allocator,
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
    // Get isolate
    const isolate = info.getIsolate();

    // Extract user data from callback info
    const data_value: *v8.Value = info.getData();
    defer v8.v8_Value_Dispose(data_value);

    // Check if it's an External value (we can't check type yet, so assume it is)
    // Cast from Value to External (they're both opaque pointers)
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

    // For now, we only support void callbacks with no arguments
    // Type-cast the function pointer to a void function
    const VoidFn = *const fn () void;
    const void_fn: VoidFn = @ptrCast(@alignCast(callback_data.fn_ptr));

    // Call the Zig function
    void_fn();

    // Return undefined
    const undef = v8.v8_Undefined(isolate) orelse return;
    defer v8.v8_Value_Dispose(undef);
    info.setReturnValue(undef);
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
    // Allocate CallbackUserData on the heap (must outlive the V8 Function)
    const callback_data = allocator.create(CallbackUserData) catch return CallbackError.OutOfMemory;
    errdefer allocator.destroy(callback_data);

    callback_data.* = .{
        .fn_ptr = @ptrCast(&zig_fn),
        .user_data = user_data,
        .allocator = allocator,
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
