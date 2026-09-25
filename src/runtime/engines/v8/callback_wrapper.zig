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

    /// Whether `deinit` releases `callback_context`. False by default: most
    /// callers pass a context handle they go on using, and releasing it here
    /// would free it under them. A caller that hands the handle over sets this.
    owns_callback_context: bool = false,

    /// Create a wrapper for a JavaScript function callback
    pub fn initFunction(
        allocator: std.mem.Allocator,
        isolate: *v8.Isolate,
        context: *v8.Context,
        func: *v8.Function,
    ) !*CallbackWrapper {
        // IMPORTANT: In our architecture, values from FunctionCallbackInfo_GetArgument
        // are ALREADY Global<Value>* handles (heap-allocated by the C++ side).
        // We should NOT call v8_Value_ToGlobal on them, as that function expects
        // a raw Local<Value> internal pointer, not a Global<Value>*.
        //
        // Instead, we just wrap the existing Global pointer.
        const global = GlobalHandle{ .ptr = @ptrCast(func) };

        // Use the provided context where this callback was created/intended to run
        const current_ctx = context;

        // Get the raw V8 context address for stable identity comparison
        // (Global handle pointers change each time GetCurrentContext is called)
        const raw_addr = v8.v8_Context_GetRawAddress(current_ctx);

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
        return wrapper;
    }

    /// Create a wrapper for a JavaScript object callback (with method)
    pub fn initObject(
        allocator: std.mem.Allocator,
        isolate: *v8.Isolate,
        context: *v8.Context,
        object: *v8.Object,
        method_name: [*:0]const u8,
    ) !*CallbackWrapper {
        // `object` is a Global<Value>* - the conversion layer's handle for the
        // argument (v8_FunctionCallbackInfo_GetArgument allocates one) - and,
        // as initFunction does with a function, the wrapper takes it over.
        // It used to be passed to GlobalHandle.create, which reads its
        // argument as a LOCAL slot: one indirection off, so the wrapper held
        // the handle's own address as a Smi, not the object.
        const global = GlobalHandle{ .ptr = @ptrCast(object) };

        // Use the provided context
        const current_ctx = context;

        // Get the raw V8 context address for stable identity comparison
        const raw_addr = v8.v8_Context_GetRawAddress(current_ctx);

        const wrapper = try allocator.create(CallbackWrapper);
        wrapper.* = .{
            .isolate = isolate,
            .callback_function_global = null,
            .callback_object_global = global,
            .method_name = method_name,
            .is_function = false,
            .allocator = allocator,
            .callback_context = current_ctx,
            .callback_context_raw_addr = raw_addr,
        };
        return wrapper;
    }

    /// Clean up the callback wrapper and dispose Global handles
    pub fn deinit(self: *CallbackWrapper) void {
        // Dispose Global handles to allow V8 GC to collect the underlying values
        // Safety checks are now in GlobalHandle.dispose()
        if (self.callback_function_global) |handle| {
            handle.dispose();
        }
        if (self.callback_object_global) |handle| {
            handle.dispose();
        }
        if (self.owns_callback_context) {
            if (self.callback_context) |context| v8.v8_Context_Dispose(context);
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

    /// Get the underlying V8 Global<Value>* for identity comparison
    /// This allows comparing two CallbackWrappers by their underlying V8 function
    pub fn getGlobalValuePtr(self: *const CallbackWrapper) ?*v8.Value {
        if (self.callback_function_global) |handle| {
            return handle.ptr;
        }
        if (self.callback_object_global) |handle| {
            return handle.ptr;
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

    /// The completion of invoking a callback: what it returned, or what it threw.
    pub const Completion = union(enum) {
        /// Owned Global<Value>* of the return value, or null when there is none.
        normal: ?*v8.Value,
        /// Owned Global<Value>* of the thrown value, or null when there is
        /// nothing to report (the call could not be made, or the isolate is
        /// terminating).
        thrown: ?*v8.Value,
    };

    /// Invoke the callback like `callN`, but keep what it throws.
    ///
    /// DOM's inner invoke has to REPORT a listener's exception (step 2.11), and
    /// `callN` - through `v8_Function_Call_Safe` - reduces it to "null". This
    /// returns the thrown value itself, via `v8_Function_CallCatching`, which
    /// also enters the callback's creation context on its own, so none of
    /// callN's context bookkeeping is needed.
    ///
    /// `args` are Local slots, as `callN` takes them. `this_arg` is WebIDL's
    /// thisArg (a Global<Value>*, or null for undefined): "call a user object's
    /// operation" calls a CALLABLE callback with it - for an event listener,
    /// the event's currentTarget - and only an object callback's method with
    /// the object itself.
    ///
    /// Only function callbacks report their exceptions here. An object
    /// callback ("handleEvent") still goes through `callN`: its method lookup
    /// uses `v8_Object_Get`, which has no TryCatch, so a throwing getter could
    /// not be caught anyway - giving that path a catching Get is its own change.
    pub fn callNCatching(self: *CallbackWrapper, context: *v8.Context, this_arg: ?*v8.Value, args: []const *v8.Value) Completion {
        if (!self.is_function) {
            const name = self.method_name orelse return .{ .thrown = null };
            return self.callMethodCatching(context, std.mem.span(name), args);
        }

        const function = self.callback_function_global orelse return .{ .thrown = null };
        const effective_context = self.callback_context orelse context;
        const isolate = v8.v8_Isolate_GetCurrent() orelse self.isolate;

        var global_args: [16]*v8.Value = undefined;
        const arg_count = @min(args.len, global_args.len);
        var made: usize = 0;
        defer for (global_args[0..made]) |arg| v8.v8_Global_Dispose(arg);
        for (0..arg_count) |i| {
            global_args[i] = v8.v8_Value_ToGlobal(isolate, @ptrCast(args[i])) orelse return .{ .thrown = null };
            made += 1;
        }

        var threw = false;
        const value = v8.v8_Function_CallCatching(
            effective_context,
            @ptrCast(function.ptr),
            this_arg,
            @intCast(arg_count),
            &global_args,
            &threw,
        );
        return if (threw) .{ .thrown = value } else .{ .normal = value };
    }

    /// WebIDL 3.11 "call a user object's operation" `op_name` with `args`
    /// (Local slots, as callNCatching takes them). A callable callback value
    /// is called directly with `this_arg`; for an object the operation is
    /// looked up now. `method_name` is only the default a conversion recorded,
    /// so a caller that knows its interface - NodeFilter's "acceptNode" -
    /// names it here.
    pub fn callOperationCatching(self: *CallbackWrapper, context: *v8.Context, op_name: []const u8, this_arg: ?*v8.Value, args: []const *v8.Value) Completion {
        if (self.is_function) return self.callNCatching(context, this_arg, args);
        return self.callMethodCatching(context, op_name, args);
    }

    /// Steps 10.1-10.4 and 12 of "call a user object's operation" for an
    /// object that is not callable: X = Get(O, opName) - rethrowing what that
    /// throws - a TypeError when X is not callable, and the call with O as
    /// thisArg. Every handle here is a Global: the object's is the wrapper's
    /// own, and GetCatching and CallCatching return Globals the caller owns.
    fn callMethodCatching(self: *CallbackWrapper, context: *v8.Context, op_name: []const u8, args: []const *v8.Value) Completion {
        const object = self.callback_object_global orelse return .{ .thrown = null };
        const isolate = v8.v8_Isolate_GetCurrent() orelse self.isolate;

        var threw = false;
        const method = v8.v8_Object_GetCatching(context, object.ptr, op_name.ptr, @intCast(op_name.len), &threw);
        if (threw) return .{ .thrown = method };
        const function = method orelse return .{ .thrown = null };
        defer v8.v8_Global_Dispose(function);

        if (!v8.v8_Value_IsFunction(function)) {
            return .{ .thrown = notCallable(isolate, op_name) };
        }

        var global_args: [16]*v8.Value = undefined;
        const arg_count = @min(args.len, global_args.len);
        var made: usize = 0;
        defer for (global_args[0..made]) |arg| v8.v8_Global_Dispose(arg);
        for (0..arg_count) |i| {
            global_args[i] = v8.v8_Value_ToGlobal(isolate, @ptrCast(args[i])) orelse return .{ .thrown = null };
            made += 1;
        }

        const value = v8.v8_Function_CallCatching(
            context,
            function,
            object.ptr,
            @intCast(arg_count),
            &global_args,
            &threw,
        );
        return if (threw) .{ .thrown = value } else .{ .normal = value };
    }

    /// The TypeError step 10.3 throws, as a value for the caller to rethrow
    /// or report. Null only if V8 could not allocate it.
    fn notCallable(isolate: *v8.Isolate, op_name: []const u8) ?*v8.Value {
        var buf: [96]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "The callback's '{s}' property is not callable", .{op_name}) catch "The callback's operation is not callable";
        const message = v8.v8_String_NewFromUtf8(isolate, text.ptr, @intCast(text.len)) orelse return null;
        defer v8.v8_Value_Dispose(@ptrCast(message));
        return v8.v8_Exception_TypeError(message);
    }

    /// Invoke the callback with multiple arguments
    ///
    /// NOTE: The v8_Function_Call FFI expects Global<T>* handles, not Local<T> values.
    /// We pass the raw GlobalHandle.ptr which IS the Global<T>* from the C++ side.
    /// The arguments are also expected to be Global handles, but since they come from
    /// the active HandleScope context (e.g., wrapping a MessageEvent), we need to
    /// convert them to Global handles first.
    pub fn callN(self: *CallbackWrapper, context: *v8.Context, args: []const *v8.Value) ?*v8.Value {
        // Check isolate and context consistency
        const current_ctx = v8.v8_Isolate_GetCurrentContext(self.isolate);

        // CRITICAL: Use the context where the callback was created, not the call-site context!
        // This ensures closure variables are resolved correctly.
        const effective_context = self.callback_context orelse context;

        // Compare raw V8 context addresses (not Global handle pointers!) to determine
        // if we need to switch contexts. Global handle pointers are different each time
        // GetCurrentContext is called, even for the same underlying V8 context.
        const current_raw_addr = if (current_ctx) |ctx| v8.v8_Context_GetRawAddress(ctx) else null;
        const need_context_switch = (current_raw_addr != self.callback_context_raw_addr);

        if (need_context_switch) {
            v8.v8_Context_Enter(effective_context);
        }
        defer if (need_context_switch) {
            v8.v8_Context_Exit(effective_context);
        };

        if (self.is_function) {
            // Direct function call - use Global handle directly (not .get() which gives Local)
            const func_global = self.callback_function_global orelse {
                return null;
            };

            // Get receiver - use undefined since callbacks don't typically use 'this'
            // Note: v8_Undefined already returns a Global<Value>*, so we don't need to wrap it again
            const recv_global = v8.v8_Undefined(self.isolate);
            // No defer needed - v8_Undefined returns a static Global that shouldn't be disposed

            // Convert args to Global handles for the FFI call
            // The args are Local values that need to be converted
            var global_args: [16]*v8.Value = undefined; // Max 16 args
            const arg_count = @min(args.len, 16);

            // Use current isolate for arg conversion (same as what v8_Function_Call_Safe uses)
            const current_isolate_for_args = v8.v8_Isolate_GetCurrent() orelse self.isolate;

            for (0..arg_count) |i| {
                // Convert Local to Global for the FFI call
                const global_arg = v8.v8_Value_ToGlobal(current_isolate_for_args, @ptrCast(args[i]));
                if (global_arg == null) {
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
            if (call_result.error_info) |_| {
                return null;
            }

            return call_result.value;
        } else {
            // Object callback: WebIDL's user-object operation call, through
            // the same path callNCatching takes. callN reports no exception,
            // so a thrown value is released and the answer is null.
            const name = self.method_name orelse return null;
            return switch (self.callMethodCatching(effective_context, std.mem.span(name), args)) {
                .normal => |value| value,
                .thrown => |exception| blk: {
                    if (exception) |e| v8.v8_Global_Dispose(e);
                    break :blk null;
                },
            };
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
        // Direct function callback - initFunction now takes context
        const func: *v8.Function = @ptrCast(value);
        return try CallbackWrapper.initFunction(allocator, isolate, context, func);
    }

    if (v8.v8_Value_IsObject(value)) {
        // WebIDL 3.2.16: converting to a callback interface only requires an
        // object. The operation is looked up when the callback is CALLED
        // ("call a user object's operation", step 10.2) - every time, and
        // what that Get throws is the caller's to rethrow or report. Looking
        // `method_name` up here ran a `handleEvent` getter at
        // addEventListener time and rejected objects whose operation is
        // named something else, such as a NodeFilter's `acceptNode`.
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
        return self.wrapper.call1(context, event);
    }
};
