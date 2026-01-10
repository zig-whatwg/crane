//! Callback Interface Wrappers
//!
//! This module provides proper handling for WebIDL callback interfaces.
//! Unlike regular interfaces, callback interfaces (like EventListener) are
//! JavaScript functions that need to be stored and invoked later.
//!
//! ## Architecture
//!
//! V8 handles NEVER cross the FFI boundary. Instead, we use opaque callback IDs:
//!
//! ```
//! ┌─────────────────────────────────────────────────────────────────┐
//! │ Zig DOM Implementation                                          │
//! │ - EventTarget stores opaque callback IDs (u64)                  │
//! │ - Calls C++ to register/invoke callbacks                        │
//! │ - Never sees V8 types                                           │
//! └───────────────────────────┬─────────────────────────────────────┘
//!                             │ FFI (opaque IDs only)
//! ┌───────────────────────────▼─────────────────────────────────────┐
//! │ C++ CallbackManager                                              │
//! │ - Owns all Global<Function> handles                              │
//! │ - Handles registration: Local → Global immediately               │
//! │ - Handles invocation with proper HandleScope                     │
//! │ - Integrates with V8 GC via weak callbacks                       │
//! └───────────────────────────┬─────────────────────────────────────┘
//!                             │
//!                             ▼
//!                           V8
//! ```
//!
//! ## The Problem (Previous Architecture)
//!
//! V8's `Local<T>` is NOT just a `T*` pointer - it's a handle containing `T**`
//! that points to a slot in an active HandleScope. When we passed the internal
//! pointer through FFI and tried to reconstruct the Local, we created garbage.
//!
//! ## The Solution
//!
//! Callbacks are registered with the C++ CallbackManager IMMEDIATELY upon receipt
//! (while still in the V8 callback handler). The Zig side only ever sees opaque
//! uint64 callback IDs, never V8 handles.

const std = @import("std");
const v8 = @import("ffi.zig");
const runtime = @import("runtime");

/// Wrapper for a JavaScript callback (function or object with method)
///
/// Used for WebIDL callback interfaces like EventListener.
/// Stores an opaque callback ID - the actual V8 Global handles are owned by
/// the C++ CallbackManager.
pub const CallbackWrapper = struct {
    /// Opaque callback ID - C++ CallbackManager owns the actual V8 handle
    callback_id: u64,

    /// The V8 isolate this callback belongs to (for creating HandleScopes)
    isolate: *v8.Isolate,

    /// Allocator used to create this wrapper
    allocator: std.mem.Allocator,

    /// Whether this callback is a function (true) or object with handleEvent (false)
    is_function: bool,

    /// The method name to call (for object callbacks, e.g., "handleEvent")
    /// Null for direct function callbacks
    method_name: ?[*:0]const u8,

    /// Create a wrapper by registering a JavaScript function with the CallbackManager
    ///
    /// CRITICAL: This MUST be called while inside the V8 callback handler where
    /// `func` and `context` are valid Local handles. The function is immediately
    /// converted to a Global handle in C++ before any FFI boundary crossing.
    pub fn initFromFunction(
        allocator: std.mem.Allocator,
        isolate: *v8.Isolate,
        context: *v8.Context,
        func: *v8.Function,
        receiver: ?*v8.Value,
    ) !*CallbackWrapper {
        // Register with C++ CallbackManager - MUST happen while Locals are valid
        const callback_id = v8.crane_callback_register(
            @ptrCast(func),
            @ptrCast(context),
            if (receiver) |r| @ptrCast(r) else null,
        );

        if (callback_id == 0) {
            std.debug.print("[CallbackWrapper.initFromFunction] ERROR: registration failed\n", .{});
            return error.CallbackRegistrationFailed;
        }

        std.debug.print("[CallbackWrapper.initFromFunction] SUCCESS: callback_id={d}\n", .{callback_id});

        const wrapper = try allocator.create(CallbackWrapper);
        wrapper.* = .{
            .callback_id = callback_id,
            .isolate = isolate,
            .allocator = allocator,
            .is_function = true,
            .method_name = null,
        };
        return wrapper;
    }

    /// Legacy compatibility: Create from function with context
    /// This is the same as initFromFunction but matches the old API signature
    pub fn initFunction(
        allocator: std.mem.Allocator,
        isolate: *v8.Isolate,
        context: *v8.Context,
        func: *v8.Function,
    ) !*CallbackWrapper {
        return initFromFunction(allocator, isolate, context, func, null);
    }

    /// Create a wrapper for a JavaScript object callback (with method like handleEvent)
    ///
    /// For object callbacks, we register the object and store the method name.
    /// The method is looked up and called when invoke is called.
    pub fn initObject(
        allocator: std.mem.Allocator,
        isolate: *v8.Isolate,
        context: *v8.Context,
        object: *v8.Object,
        method_name: [*:0]const u8,
    ) !*CallbackWrapper {
        // For object callbacks, we need to get the method and register that
        // First, look up the method on the object
        const name_str = v8.v8_String_NewFromUtf8(
            isolate,
            method_name,
            @intCast(std.mem.len(method_name)),
        ) orelse return error.OutOfMemory;
        defer v8.v8_String_Dispose(name_str);

        const method_value = v8.v8_Object_Get(@ptrCast(object), context, @ptrCast(name_str)) orelse {
            return error.MethodNotFound;
        };

        if (!v8.v8_Value_IsFunction(method_value)) {
            return error.MethodNotCallable;
        }

        // Register the method function with the object as receiver
        const callback_id = v8.crane_callback_register(
            @ptrCast(method_value),
            @ptrCast(context),
            @ptrCast(object), // 'this' binding
        );

        if (callback_id == 0) {
            return error.CallbackRegistrationFailed;
        }

        const wrapper = try allocator.create(CallbackWrapper);
        wrapper.* = .{
            .callback_id = callback_id,
            .isolate = isolate,
            .allocator = allocator,
            .is_function = false,
            .method_name = method_name,
        };
        return wrapper;
    }

    /// Clean up the callback wrapper and remove from CallbackManager
    pub fn deinit(self: *CallbackWrapper) void {
        // Remove from C++ CallbackManager (releases the Global handle)
        v8.crane_callback_remove(self.callback_id);
        self.allocator.destroy(self);
    }

    /// Invoke the callback with no arguments
    pub fn invoke0(self: *CallbackWrapper) !?*v8.Value {
        const result = v8.crane_callback_invoke0(self.callback_id);
        defer if (result.return_value) |rv| v8.crane_callback_free_result(rv);

        if (!result.success) {
            if (result.getErrorMessage()) |msg| {
                std.debug.print("[CallbackWrapper.invoke0] ERROR: {s}\n", .{msg});
            }
            return error.CallbackInvocationFailed;
        }

        return result.return_value;
    }

    /// Invoke the callback with one argument
    pub fn invoke1(self: *CallbackWrapper, arg: *v8.Value) !?*v8.Value {
        const result = v8.crane_callback_invoke1(self.callback_id, arg);
        // Note: Don't free return_value here - caller may need it
        // The return value is owned by the caller now

        if (!result.success) {
            if (result.getErrorMessage()) |msg| {
                std.debug.print("[CallbackWrapper.invoke1] ERROR: {s}\n", .{msg});
            }
            return error.CallbackInvocationFailed;
        }

        return result.return_value;
    }

    /// Invoke the callback with multiple arguments
    pub fn invoke(self: *CallbackWrapper, args: []const *v8.Value) !?*v8.Value {
        const result = v8.crane_callback_invoke(
            self.callback_id,
            @intCast(args.len),
            if (args.len > 0) @ptrCast(@constCast(args.ptr)) else null,
        );

        if (!result.success) {
            if (result.getErrorMessage()) |msg| {
                std.debug.print("[CallbackWrapper.invoke] ERROR: {s}\n", .{msg});
            }
            return error.CallbackInvocationFailed;
        }

        return result.return_value;
    }

    /// Legacy compatibility: call0
    pub fn call0(self: *CallbackWrapper, context: *v8.Context) ?*v8.Value {
        _ = context;
        return self.invoke0() catch null;
    }

    /// Legacy compatibility: call1
    pub fn call1(self: *CallbackWrapper, context: *v8.Context, arg: *v8.Value) ?*v8.Value {
        _ = context;
        return self.invoke1(arg) catch null;
    }

    /// Legacy compatibility: callN
    pub fn callN(self: *CallbackWrapper, context: *v8.Context, args: []const *v8.Value) ?*v8.Value {
        _ = context;
        return self.invoke(args) catch null;
    }

    /// Check if two CallbackWrappers represent the same callback
    /// Used for removeEventListener to match callbacks
    pub fn equals(self: *const CallbackWrapper, other: *const CallbackWrapper) bool {
        return self.callback_id == other.callback_id;
    }

    /// Get the callback ID (for external comparison if needed)
    pub fn getId(self: *const CallbackWrapper) u64 {
        return self.callback_id;
    }
};

/// Create a CallbackWrapper from a V8 value
///
/// Handles both function callbacks and object callbacks (with handleEvent method).
/// Returns null if the value is not a valid callback.
pub fn createFromV8Value(
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: *v8.Value,
    method_name: [*:0]const u8,
) !?*CallbackWrapper {
    if (v8.v8_Value_IsNullOrUndefined(value)) {
        return null;
    }

    if (v8.v8_Value_IsFunction(value)) {
        // Direct function callback
        const func: *v8.Function = @ptrCast(value);
        return try CallbackWrapper.initFromFunction(allocator, isolate, context, func, null);
    }

    if (v8.v8_Value_IsObject(value)) {
        // Check if object has the required method
        const obj: *v8.Object = @ptrCast(value);
        return try CallbackWrapper.initObject(allocator, isolate, context, obj, method_name);
    }

    return null;
}

// ============================================================================
// EventListener specific wrapper
// ============================================================================

/// EventListener callback wrapper
///
/// Per DOM spec, EventListener can be:
/// - A function: `addEventListener("click", function(e) { ... })`
/// - An object with handleEvent: `addEventListener("click", { handleEvent: function(e) { ... } })`
pub const EventListenerCallback = struct {
    wrapper: *CallbackWrapper,

    pub fn init(
        allocator: std.mem.Allocator,
        isolate: *v8.Isolate,
        context: *v8.Context,
        value: *v8.Value,
    ) !?EventListenerCallback {
        const wrapper = try createFromV8Value(
            allocator,
            isolate,
            context,
            value,
            "handleEvent",
        ) orelse return null;

        return EventListenerCallback{ .wrapper = wrapper };
    }

    pub fn deinit(self: EventListenerCallback) void {
        self.wrapper.deinit();
    }

    /// Call the event listener with an Event argument
    pub fn handleEvent(self: EventListenerCallback, context: *v8.Context, event: *v8.Value) ?*v8.Value {
        _ = context;
        return self.wrapper.invoke1(event) catch null;
    }
};
