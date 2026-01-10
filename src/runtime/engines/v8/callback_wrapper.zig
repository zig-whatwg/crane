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
///
/// ## Two Modes of Operation
///
/// 1. **Registered Mode** (callback_id != 0):
///    - Used by addEventListener to store callbacks that will be invoked later
///    - The callback is registered with C++ CallbackManager
///    - CallbackManager owns the Global<Function> handle
///    - Supports invocation via invoke0/invoke1/invoke
///
/// 2. **Comparison-Only Mode** (callback_id == 0, comparison_global != null):
///    - Used by removeEventListener to compare against registered callbacks
///    - The callback is NOT registered with CallbackManager
///    - We own a temporary Global<Function> for comparison
///    - Does NOT support invocation (use only for equals())
///    - MUST be cleaned up after use
///
/// This design follows Chromium's approach: removeEventListener doesn't need
/// to create a persistent registration, it just needs to compare.
pub const CallbackWrapper = struct {
    /// Opaque callback ID - C++ CallbackManager owns the actual V8 handle
    /// Set to 0 for comparison-only wrappers
    callback_id: u64,

    /// For comparison-only mode: temporary Global<Function>* that we own
    /// Set to null for registered wrappers
    comparison_global: ?*anyopaque = null,

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

    /// Create a comparison-only wrapper WITHOUT registering with CallbackManager
    ///
    /// This is used by removeEventListener to compare against registered callbacks
    /// without creating unnecessary registrations. The wrapper stores a temporary
    /// Global<Function> that we own and must clean up.
    ///
    /// IMPORTANT: This wrapper:
    /// - CANNOT be invoked (invoke0/invoke1/invoke will fail)
    /// - MUST be cleaned up via deinit() after use
    /// - Is only valid for equals() comparison
    ///
    /// CRITICAL: This MUST be called while inside the V8 callback handler where
    /// `func` and `context` are valid Local handles.
    pub fn initForComparisonOnly(
        allocator: std.mem.Allocator,
        isolate: *v8.Isolate,
        context: *v8.Context,
        func: *v8.Function,
    ) !*CallbackWrapper {
        // Create a Global<Function> without registering with CallbackManager
        const comparison_global = v8.crane_create_function_global(
            @ptrCast(func),
            @ptrCast(context),
        );

        if (comparison_global == null) {
            return error.CallbackCreationFailed;
        }

        const wrapper = try allocator.create(CallbackWrapper);
        wrapper.* = .{
            .callback_id = 0, // Not registered
            .comparison_global = comparison_global,
            .isolate = isolate,
            .allocator = allocator,
            .is_function = true,
            .method_name = null,
        };
        return wrapper;
    }

    /// Check if this is a comparison-only wrapper (not registered)
    pub fn isComparisonOnly(self: *const CallbackWrapper) bool {
        return self.callback_id == 0 and self.comparison_global != null;
    }

    /// Clean up the callback wrapper
    ///
    /// For registered wrappers: removes from C++ CallbackManager
    /// For comparison-only wrappers: releases the temporary Global<Function>
    pub fn deinit(self: *CallbackWrapper) void {
        if (self.callback_id != 0) {
            // Registered wrapper - remove from C++ CallbackManager
            v8.crane_callback_remove(self.callback_id);
        } else if (self.comparison_global) |global| {
            // Comparison-only wrapper - release the temporary Global
            v8.crane_release_function_global(global);
        }
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
    /// Used for removeEventListener to match callbacks.
    ///
    /// Per DOM spec, two event listeners are the same if they have the same callback.
    /// This uses V8's StrictEquals to compare the underlying JavaScript function objects.
    ///
    /// Supports mixed comparisons:
    /// - Registered vs Registered: uses crane_callback_compare
    /// - Registered vs Comparison-only: uses crane_callback_matches_raw_function
    /// - Comparison-only vs Comparison-only: not supported (returns false)
    pub fn equals(self: *const CallbackWrapper, other: *const CallbackWrapper) bool {
        const self_registered = self.callback_id != 0;
        const other_registered = other.callback_id != 0;

        if (self_registered and other_registered) {
            // Both registered - use the standard comparison
            return v8.crane_callback_compare(self.callback_id, other.callback_id);
        }

        if (self_registered and other.comparison_global != null) {
            // Self is registered, other is comparison-only
            // Compare registered callback against raw function
            return v8.crane_callback_matches_raw_function(self.callback_id, other.comparison_global.?);
        }

        if (other_registered and self.comparison_global != null) {
            // Other is registered, self is comparison-only
            // Compare registered callback against raw function
            return v8.crane_callback_matches_raw_function(other.callback_id, self.comparison_global.?);
        }

        // Both comparison-only or invalid - not supported
        return false;
    }

    /// Get the callback ID (for external comparison if needed)
    pub fn getId(self: *const CallbackWrapper) u64 {
        return self.callback_id;
    }

    // ========================================================================
    // Weak Callback Support
    // ========================================================================
    //
    // Weak callbacks allow V8's GC to collect JavaScript functions that are
    // no longer referenced from JavaScript. This prevents memory leaks.
    //
    // NOTE: Event listeners should generally NOT be weak - the listener
    // should stay alive as long as the EventTarget exists.

    /// Make this callback weak - V8 can GC the function when no JS refs remain
    /// When collected, subsequent invoke calls will return an error.
    /// Returns true on success, false if already weak.
    pub fn makeWeak(self: *CallbackWrapper) bool {
        return v8.crane_callback_make_weak(self.callback_id);
    }

    /// Clear weak status - make callback strong again (prevents GC collection)
    /// Returns true on success, false if not currently weak.
    pub fn clearWeak(self: *CallbackWrapper) bool {
        return v8.crane_callback_clear_weak(self.callback_id);
    }

    /// Check if this callback is currently weak
    pub fn isWeak(self: *const CallbackWrapper) bool {
        return v8.crane_callback_is_weak(self.callback_id);
    }

    /// Check if this callback has been collected by GC
    /// If true, the callback can no longer be invoked.
    pub fn isCollected(self: *const CallbackWrapper) bool {
        return v8.crane_callback_is_collected(self.callback_id);
    }
};

/// Create a CallbackWrapper from a V8 value
///
/// Handles both function callbacks and object callbacks (with handleEvent method).
/// Returns null if the value is not a valid callback.
///
/// The created wrapper is REGISTERED with CallbackManager - use this for callbacks
/// that will be stored and invoked later (e.g., addEventListener).
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

/// Create a comparison-only CallbackWrapper from a V8 value
///
/// This creates a wrapper that is NOT registered with CallbackManager.
/// Use this for callbacks that are only used for comparison (e.g., removeEventListener).
///
/// The caller MUST call deinit() on the returned wrapper to avoid memory leaks.
/// Only function callbacks are supported (not object callbacks with handleEvent).
pub fn createForComparisonOnly(
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: *v8.Value,
) !?*CallbackWrapper {
    if (v8.v8_Value_IsNullOrUndefined(value)) {
        return null;
    }

    if (v8.v8_Value_IsFunction(value)) {
        const func: *v8.Function = @ptrCast(value);
        return try CallbackWrapper.initForComparisonOnly(allocator, isolate, context, func);
    }

    // For object callbacks with handleEvent, we need to extract the method
    // For now, this is not supported in comparison-only mode
    // (removeEventListener with object callbacks is rare)
    if (v8.v8_Value_IsObject(value)) {
        // Get the handleEvent method and create comparison-only wrapper for it
        const obj: *v8.Object = @ptrCast(value);
        const method_name = "handleEvent";
        const name_str = v8.v8_String_NewFromUtf8(
            isolate,
            method_name,
            @intCast(std.mem.len(method_name)),
        ) orelse return null;
        defer v8.v8_String_Dispose(name_str);

        const method_value = v8.v8_Object_Get(@ptrCast(obj), context, @ptrCast(name_str)) orelse {
            return null;
        };

        if (v8.v8_Value_IsFunction(method_value)) {
            const method_func: *v8.Function = @ptrCast(method_value);
            return try CallbackWrapper.initForComparisonOnly(allocator, isolate, context, method_func);
        }
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

// ============================================================================
// Global Callback Cleanup Functions
// ============================================================================

/// Clean up callbacks that have been collected by V8's GC
/// Frees memory associated with collected callbacks.
/// Should be called periodically (e.g., in the event loop) to reclaim memory.
///
/// Returns the number of callbacks cleaned up.
pub fn cleanupCollectedCallbacks() u64 {
    return v8.crane_callback_cleanup_collected();
}

/// Get the count of callbacks that have been collected but not yet cleaned up
pub fn getCollectedCallbackCount() u64 {
    return v8.crane_callback_collected_count();
}

/// Get the total count of registered callbacks (for debugging)
pub fn getCallbackCount() u64 {
    return v8.crane_callback_count();
}
