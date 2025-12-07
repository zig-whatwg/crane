//! Callback Interface Wrappers
//!
//! This module provides proper handling for WebIDL callback interfaces.
//! Unlike regular interfaces, callback interfaces (like EventListener) are
//! JavaScript functions that need to be stored and invoked later.
//!
//! ## The Problem
//!
//! In WebIDL:
//! ```idl
//! callback interface EventListener {
//!     undefined handleEvent(Event event);
//! };
//! ```
//!
//! This is NOT a regular interface - it's a type that represents a callable.
//! In JavaScript, it's typically a function or an object with a handleEvent method.
//!
//! ## Solution
//!
//! We wrap JavaScript callbacks in a CallbackWrapper that:
//! 1. Stores a persistent reference to the V8 Function/Object using Global handles
//! 2. Provides a way to invoke the callback later
//! 3. Properly releases the reference when done
//!
//! This is different from regular interfaces which store a pointer to a Zig struct.
//!
//! ## V8 Handle Lifecycle
//!
//! V8 uses two types of handles:
//! - **Local<T>**: Stack-bound, invalid after HandleScope ends
//! - **Global<T>**: Heap-allocated, persists until explicitly disposed
//!
//! CallbackWrapper uses Global handles to ensure callbacks survive past the
//! HandleScope that created them.

const std = @import("std");
const v8 = @import("ffi.zig");
const global_handles = @import("global_handles.zig");
const GlobalHandle = global_handles.GlobalHandle;
const runtime = @import("runtime");

/// Wrapper for a JavaScript callback (function or object with method)
///
/// Used for WebIDL callback interfaces like EventListener.
/// Stores Global handles to ensure callbacks persist across GC cycles and HandleScope destruction.
pub const CallbackWrapper = struct {
    /// The V8 isolate this callback belongs to
    isolate: *v8.Isolate,

    /// Persistent Global handle to the callback function
    /// This keeps the function alive across GC cycles and HandleScope destruction
    callback_function_global: ?GlobalHandle,

    /// Persistent Global handle to the callback object (if callback is an object with methods)
    callback_object_global: ?GlobalHandle,

    /// The method name to call (for object callbacks, e.g., "handleEvent")
    method_name: ?[*:0]const u8,

    /// Whether this callback is a function (true) or object (false)
    is_function: bool,

    /// Allocator used to create this wrapper
    allocator: std.mem.Allocator,

    /// Create a wrapper for a JavaScript function callback
    ///
    /// The function pointer is converted to a Global handle for persistent storage.
    pub fn initFunction(
        allocator: std.mem.Allocator,
        isolate: *v8.Isolate,
        func: *v8.Function,
    ) !*CallbackWrapper {
        // Convert Local<Function> to Global<Value> for persistence
        const global = GlobalHandle.create(isolate, @ptrCast(func)) orelse {
            return error.GlobalHandleCreationFailed;
        };

        const wrapper = try allocator.create(CallbackWrapper);
        wrapper.* = .{
            .isolate = isolate,
            .callback_function_global = global,
            .callback_object_global = null,
            .method_name = null,
            .is_function = true,
            .allocator = allocator,
        };
        return wrapper;
    }

    /// Create a wrapper for a JavaScript object callback (with method)
    ///
    /// The object pointer is converted to a Global handle for persistent storage.
    pub fn initObject(
        allocator: std.mem.Allocator,
        isolate: *v8.Isolate,
        object: *v8.Object,
        method_name: [*:0]const u8,
    ) !*CallbackWrapper {
        // Convert Local<Object> to Global<Value> for persistence
        const global = GlobalHandle.create(isolate, @ptrCast(object)) orelse {
            return error.GlobalHandleCreationFailed;
        };

        const wrapper = try allocator.create(CallbackWrapper);
        wrapper.* = .{
            .isolate = isolate,
            .callback_function_global = null,
            .callback_object_global = global,
            .method_name = method_name,
            .is_function = false,
            .allocator = allocator,
        };
        return wrapper;
    }

    /// Clean up the callback wrapper and dispose Global handles
    pub fn deinit(self: *CallbackWrapper) void {
        // Dispose Global handles to allow V8 GC to collect the underlying values
        if (self.callback_function_global) |handle| {
            handle.dispose();
        }
        if (self.callback_object_global) |handle| {
            handle.dispose();
        }
        self.allocator.destroy(self);
    }

    /// Get the callback function as a Local pointer for invocation
    /// Returns null if no function is stored or the Global handle is empty
    fn getCallbackFunction(self: *CallbackWrapper) ?*v8.Function {
        if (self.callback_function_global) |handle| {
            const local = handle.get(self.isolate) orelse return null;
            return @ptrCast(local);
        }
        return null;
    }

    /// Get the callback object as a Local pointer for invocation
    /// Returns null if no object is stored or the Global handle is empty
    fn getCallbackObject(self: *CallbackWrapper) ?*v8.Object {
        if (self.callback_object_global) |handle| {
            const local = handle.get(self.isolate) orelse return null;
            return @ptrCast(local);
        }
        return null;
    }

    /// Invoke the callback with no arguments
    pub fn call0(self: *CallbackWrapper, context: *v8.Context) ?*v8.Value {
        return self.callN(context, &.{});
    }

    /// Invoke the callback with one argument
    pub fn call1(self: *CallbackWrapper, context: *v8.Context, arg0: *v8.Value) ?*v8.Value {
        return self.callN(context, &.{arg0});
    }

    /// Invoke the callback with multiple arguments
    pub fn callN(self: *CallbackWrapper, context: *v8.Context, args: []const *v8.Value) ?*v8.Value {
        if (self.is_function) {
            // Direct function call - get Local from Global handle
            const func = self.getCallbackFunction() orelse return null;
            const global_obj = v8.v8_Context_Global(context);
            // FFI expects [*]*Value which can't be null - use empty args case specially
            if (args.len > 0) {
                return v8.v8_Function_Call(
                    func,
                    context,
                    @ptrCast(global_obj), // 'this' is global
                    @intCast(args.len),
                    @ptrCast(@constCast(args.ptr)),
                );
            } else {
                // No args - use call0 pattern with undefined as placeholder
                // The FFI requires a valid pointer even with argc=0
                var empty_args: [1]*v8.Value = undefined;
                return v8.v8_Function_Call(
                    func,
                    context,
                    @ptrCast(global_obj),
                    0,
                    &empty_args,
                );
            }
        } else {
            // Object method call - get Local from Global handle
            const obj = self.getCallbackObject() orelse return null;
            const method_name_str = self.method_name orelse return null;

            // Get the method from the object
            const name_str = v8.v8_String_NewFromUtf8(
                self.isolate,
                method_name_str,
                @intCast(std.mem.len(method_name_str)),
            ) orelse return null;

            const method_value = v8.v8_Object_Get(obj, context, @ptrCast(name_str)) orelse return null;

            if (!v8.v8_Value_IsFunction(method_value)) {
                return null;
            }

            const method_func: *v8.Function = @ptrCast(method_value);
            // FFI expects [*]*Value which can't be null - use empty args case specially
            if (args.len > 0) {
                return v8.v8_Function_Call(
                    method_func,
                    context,
                    @ptrCast(obj), // 'this' is the callback object
                    @intCast(args.len),
                    @ptrCast(@constCast(args.ptr)),
                );
            } else {
                var empty_args: [1]*v8.Value = undefined;
                return v8.v8_Function_Call(
                    method_func,
                    context,
                    @ptrCast(obj),
                    0,
                    &empty_args,
                );
            }
        }
    }
};

/// Create a CallbackWrapper from a V8 value
///
/// Handles both function callbacks and object callbacks (with handleEvent method).
/// The V8 value is converted to a Global handle for persistent storage.
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
        // Direct function callback - initFunction will create Global handle
        const func: *v8.Function = @ptrCast(value);
        return try CallbackWrapper.initFunction(allocator, isolate, func);
    }

    if (v8.v8_Value_IsObject(value)) {
        // Check if object has the required method
        const obj: *v8.Object = @ptrCast(value);
        const name_str = v8.v8_String_NewFromUtf8(
            isolate,
            method_name,
            @intCast(std.mem.len(method_name)),
        ) orelse return error.OutOfMemory;

        const method_value = v8.v8_Object_Get(obj, context, @ptrCast(name_str)) orelse return null;

        if (!v8.v8_Value_IsFunction(method_value)) {
            return null;
        }

        // initObject will create Global handle for persistent storage
        return try CallbackWrapper.initObject(allocator, isolate, obj, method_name);
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
        return self.wrapper.call1(context, event);
    }
};
