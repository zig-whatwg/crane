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

    /// V8 context Global handle where this callback was created
    /// This is used to ensure we call the callback in the correct context
    callback_context: ?*v8.Context = null,

    /// Raw V8 context address (stable identity for comparison)
    /// Unlike Global handle pointers, this is the actual V8 internal context address
    callback_context_raw_addr: ?*anyopaque = null,

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

        // Store the current context where this callback was created
        const current_ctx = v8.v8_Isolate_GetCurrentContext(isolate);

        // Get the raw V8 context address for stable identity comparison
        // (Global handle pointers change each time GetCurrentContext is called)
        const raw_addr = if (current_ctx) |ctx| v8.v8_Context_GetRawAddress(ctx) else null;

        const wrapper = try allocator.create(CallbackWrapper);
        wrapper.* = .{
            .isolate = isolate,
            .callback_function_global = global,
            .callback_object_global = null,
            .method_name = null,
            .is_function = true,
            .allocator = allocator,
            .callback_context = current_ctx,
            .callback_context_raw_addr = raw_addr,
        };
        std.log.debug("CallbackWrapper.initFunction: created wrapper with context={?*}, raw_addr={?*}", .{ current_ctx, raw_addr });
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
    ///
    /// NOTE: The v8_Function_Call FFI expects Global<T>* handles, not Local<T> values.
    /// We pass the raw GlobalHandle.ptr which IS the Global<T>* from the C++ side.
    /// The arguments are also expected to be Global handles, but since they come from
    /// the active HandleScope context (e.g., wrapping a MessageEvent), we need to
    /// convert them to Global handles first.
    pub fn callN(self: *CallbackWrapper, context: *v8.Context, args: []const *v8.Value) ?*v8.Value {
        std.log.debug("CallbackWrapper.callN: is_function={}, has_func_global={}, has_obj_global={}", .{ self.is_function, self.callback_function_global != null, self.callback_object_global != null });

        // Check isolate and context consistency
        const current_isolate = v8.v8_Isolate_GetCurrent();
        const current_ctx = v8.v8_Isolate_GetCurrentContext(self.isolate);
        std.log.debug("CallbackWrapper.callN: self.isolate={*}, current_isolate={?*}, match={}", .{ self.isolate, current_isolate, current_isolate == self.isolate });
        std.log.debug("CallbackWrapper.callN: creation_context={?*}, call_context={*}, current_context={?*}", .{ self.callback_context, context, current_ctx });

        // CRITICAL: Use the context where the callback was created, not the call-site context!
        // This ensures closure variables are resolved correctly.
        const effective_context = self.callback_context orelse context;
        std.log.debug("CallbackWrapper.callN: using effective_context={*}", .{effective_context});

        // Compare raw V8 context addresses (not Global handle pointers!) to determine
        // if we need to switch contexts. Global handle pointers are different each time
        // GetCurrentContext is called, even for the same underlying V8 context.
        const current_raw_addr = if (current_ctx) |ctx| v8.v8_Context_GetRawAddress(ctx) else null;
        const need_context_switch = (current_raw_addr == null) or (current_raw_addr != self.callback_context_raw_addr);
        std.log.debug("CallbackWrapper.callN: current_raw_addr={?*}, creation_raw_addr={?*}, need_switch={}", .{ current_raw_addr, self.callback_context_raw_addr, need_context_switch });

        if (need_context_switch) {
            std.log.debug("CallbackWrapper.callN: entering callback context (raw addr mismatch)", .{});
            v8.v8_Context_Enter(effective_context);
        }
        defer if (need_context_switch) {
            v8.v8_Context_Exit(effective_context);
        };

        if (self.is_function) {
            // Direct function call - use Global handle directly (not .get() which gives Local)
            const func_global = self.callback_function_global orelse {
                std.log.debug("CallbackWrapper.callN: no function global handle", .{});
                return null;
            };
            std.log.debug("CallbackWrapper.callN: func_global.ptr={*}", .{func_global.ptr});

            // Debug: Try to get a Local from the Global to verify it's still valid
            const local_func = func_global.get(self.isolate);
            std.log.debug("CallbackWrapper.callN: global.get() = {?*}", .{local_func});
            if (local_func) |local_val| {
                const is_func = v8.v8_Value_IsFunction(local_val);
                std.log.debug("CallbackWrapper.callN: local is function = {}", .{is_func});
            }

            // Get receiver - use undefined since callbacks don't typically use 'this'
            // Note: v8_Undefined already returns a Global<Value>*, so we don't need to wrap it again
            const recv_global = v8.v8_Undefined(self.isolate);
            // No defer needed - v8_Undefined returns a static Global that shouldn't be disposed

            std.log.debug("CallbackWrapper.callN: using undefined as receiver={?*}", .{recv_global});

            // Convert args to Global handles for the FFI call
            // The args are Local values that need to be converted
            var global_args: [16]*v8.Value = undefined; // Max 16 args
            const arg_count = @min(args.len, 16);

            // Use current isolate for arg conversion (same as what v8_Function_Call_Safe uses)
            const current_isolate_for_args = v8.v8_Isolate_GetCurrent() orelse self.isolate;
            std.log.debug("CallbackWrapper.callN: arg conversion isolate={*}", .{current_isolate_for_args});

            for (0..arg_count) |i| {
                // Convert Local to Global for the FFI call
                const global_arg = v8.v8_Value_ToGlobal(current_isolate_for_args, @ptrCast(args[i]));
                if (global_arg == null) {
                    std.log.debug("CallbackWrapper.callN: failed to convert arg {d} to global", .{i});
                    return null;
                }
                global_args[i] = global_arg.?;
            }
            defer {
                // Dispose temporary Global handles after the call
                for (0..arg_count) |i| {
                    v8.v8_Global_Dispose(global_args[i]);
                }
            }

            // Pass Global handles: func_global.ptr is the Global<Function>*
            std.log.debug("CallbackWrapper.callN: calling v8_Function_Call_Safe with {d} args", .{arg_count});
            std.log.debug("CallbackWrapper.callN: effective_context={*}, recv_global={?*}", .{ effective_context, recv_global });
            if (arg_count > 0) {
                std.log.debug("CallbackWrapper.callN: global_args[0]={*}", .{global_args[0]});
            }

            // Use the safe version with TryCatch to capture any exceptions
            const call_result = if (arg_count > 0)
                v8.v8_Function_Call_Safe(
                    @ptrCast(func_global.ptr), // Global<Function>*
                    effective_context, // Global<Context>* - use creation context!
                    @ptrCast(recv_global), // Global<Value>* - 'this' is undefined
                    @intCast(arg_count),
                    @ptrCast(&global_args),
                )
            else blk: {
                // No args - use call0 pattern with undefined as placeholder
                var empty_args: [1]*v8.Value = undefined;
                break :blk v8.v8_Function_Call_Safe(
                    @ptrCast(func_global.ptr),
                    effective_context, // Global<Context>* - use creation context!
                    @ptrCast(recv_global),
                    0,
                    &empty_args,
                );
            };
            defer v8.v8_FreeFunctionCallResult(call_result);

            // Check for error
            if (call_result.error_info) |err_info| {
                if (err_info.getMessage()) |msg| {
                    std.log.err("CallbackWrapper.callN: exception: {s}", .{msg});
                }
                if (err_info.getStackTrace()) |stack| {
                    std.log.err("CallbackWrapper.callN: stack: {s}", .{stack});
                }
                return null;
            }

            std.log.debug("CallbackWrapper.callN: call returned result={?*}", .{call_result.value});
            return call_result.value;
        } else {
            // Object method call - get Local from Global handle for property access
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

            // Convert method to Global handle for FFI call
            const method_global = v8.v8_Value_ToGlobal(self.isolate, method_value) orelse return null;
            defer v8.v8_Global_Dispose(method_global);

            // Convert object to Global for 'this' parameter
            const obj_global = self.callback_object_global orelse return null;

            // Convert args to Global handles
            var global_args: [16]*v8.Value = undefined;
            const arg_count = @min(args.len, 16);
            for (0..arg_count) |i| {
                const global_arg = v8.v8_Value_ToGlobal(self.isolate, @ptrCast(args[i]));
                if (global_arg == null) return null;
                global_args[i] = global_arg.?;
            }
            defer {
                for (0..arg_count) |i| {
                    v8.v8_Global_Dispose(global_args[i]);
                }
            }

            if (arg_count > 0) {
                return v8.v8_Function_Call(
                    @ptrCast(method_global), // Global<Function>*
                    context, // Global<Context>*
                    @ptrCast(obj_global.ptr), // Global<Object>* - 'this' is callback object
                    @intCast(arg_count),
                    @ptrCast(&global_args),
                );
            } else {
                var empty_args: [1]*v8.Value = undefined;
                return v8.v8_Function_Call(
                    @ptrCast(method_global),
                    context,
                    @ptrCast(obj_global.ptr),
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
