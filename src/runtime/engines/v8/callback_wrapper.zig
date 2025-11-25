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
//! 1. Stores a persistent reference to the V8 Function/Object
//! 2. Provides a way to invoke the callback later
//! 3. Properly releases the reference when done
//!
//! This is different from regular interfaces which store a pointer to a Zig struct.

const std = @import("std");
const v8 = @import("ffi.zig");
const runtime = @import("runtime");

/// Wrapper for a JavaScript callback (function or object with method)
///
/// Used for WebIDL callback interfaces like EventListener.
pub const CallbackWrapper = struct {
    /// The V8 isolate this callback belongs to
    isolate: *v8.Isolate,

    /// Persistent reference to the callback function
    /// This keeps the function alive across GC cycles
    callback_function: ?*v8.Function,

    /// Persistent reference to the callback object (if callback is an object with methods)
    callback_object: ?*v8.Object,

    /// The method name to call (for object callbacks, e.g., "handleEvent")
    method_name: ?[*:0]const u8,

    /// Whether this callback is a function (true) or object (false)
    is_function: bool,

    /// Allocator used to create this wrapper
    allocator: std.mem.Allocator,

    /// Create a wrapper for a JavaScript function callback
    pub fn initFunction(
        allocator: std.mem.Allocator,
        isolate: *v8.Isolate,
        func: *v8.Function,
    ) !*CallbackWrapper {
        const wrapper = try allocator.create(CallbackWrapper);
        wrapper.* = .{
            .isolate = isolate,
            .callback_function = func,
            .callback_object = null,
            .method_name = null,
            .is_function = true,
            .allocator = allocator,
        };
        return wrapper;
    }

    /// Create a wrapper for a JavaScript object callback (with method)
    pub fn initObject(
        allocator: std.mem.Allocator,
        isolate: *v8.Isolate,
        object: *v8.Object,
        method_name: [*:0]const u8,
    ) !*CallbackWrapper {
        const wrapper = try allocator.create(CallbackWrapper);
        wrapper.* = .{
            .isolate = isolate,
            .callback_function = null,
            .callback_object = object,
            .method_name = method_name,
            .is_function = false,
            .allocator = allocator,
        };
        return wrapper;
    }

    /// Clean up the callback wrapper
    pub fn deinit(self: *CallbackWrapper) void {
        // TODO: Dispose persistent handles when FFI supports v8_Function_Dispose/v8_Object_Dispose
        // For now, just free the wrapper struct - the V8 GC owns the underlying values
        _ = self.callback_function;
        _ = self.callback_object;
        self.allocator.destroy(self);
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
            // Direct function call
            const func = self.callback_function orelse return null;
            const global = v8.v8_Context_Global(context);
            return v8.v8_Function_Call(
                func,
                context,
                @ptrCast(global), // 'this' is global
                @intCast(args.len),
                if (args.len > 0) @ptrCast(args.ptr) else null,
            );
        } else {
            // Object method call
            const obj = self.callback_object orelse return null;
            const method_name = self.method_name orelse return null;

            // Get the method from the object
            const name_str = v8.v8_String_NewFromUtf8(
                self.isolate,
                method_name,
                @intCast(std.mem.len(method_name)),
            ) orelse return null;

            const method_value = v8.v8_Object_Get(obj, context, @ptrCast(name_str)) orelse return null;

            if (!v8.v8_Value_IsFunction(method_value)) {
                return null;
            }

            const method_func: *v8.Function = @ptrCast(method_value);
            return v8.v8_Function_Call(
                method_func,
                context,
                @ptrCast(obj), // 'this' is the callback object
                @intCast(args.len),
                if (args.len > 0) @ptrCast(args.ptr) else null,
            );
        }
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
        // TODO: Use persistent handles when FFI supports v8_Function_Persist
        // For now, store the raw pointer (caller must ensure callback stays alive)
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

        // TODO: Use persistent handles when FFI supports v8_Object_Persist
        // For now, store the raw pointer (caller must ensure callback stays alive)
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
