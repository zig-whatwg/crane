//! # Type-Safe Callback Storage
//!
//! This module provides `TypedCallback` - a generic type for type-safe storage of
//! JavaScript callback functions with automatic lifecycle management.
//!
//! ## Problem Statement
//!
//! Currently callbacks are stored as raw pointers:
//! ```zig
//! onopen: ?*const anyopaque,           // WebSocket
//! onreadystatechange: ?*const anyopaque,  // XMLHttpRequest
//! transform_callback: ?*const anyopaque,  // TransformStream
//! ```
//!
//! Issues:
//! - No guarantee the pointer is actually a function
//! - No automatic disposal of Global handles
//! - No type information about expected signature
//! - Memory leaks if Global handles aren't disposed
//!
//! ## Solution
//!
//! `TypedCallback` wraps a GlobalHandle with:
//! - Validation that the value is actually a function
//! - Automatic conversion from Local to Global for safe storage
//! - Proper disposal of Global handles
//! - Type-safe invocation methods
//!
//! ## Usage
//!
//! ```zig
//! const TypedCallback = @import("typed_callback.zig").TypedCallback;
//! const AnyCallback = @import("typed_callback.zig").AnyCallback;
//!
//! pub const InternalState = struct {
//!     onopen: AnyCallback = .{},
//!     onerror: AnyCallback = .{},
//!
//!     pub fn deinit(self: *InternalState) void {
//!         self.onopen.dispose();
//!         self.onerror.dispose();
//!     }
//! };
//!
//! // Store handler (validates it's a function)
//! try internal.onopen.set(handler, isolate);
//!
//! // Call handler
//! if (internal.onopen.isSet()) {
//!     _ = try internal.onopen.call1(isolate, context, null, event_obj);
//! }
//! ```

const std = @import("std");
const v8 = @import("ffi.zig");
const GlobalHandle = @import("global_handles.zig").GlobalHandle;
const js_value = @import("js_value.zig");
const JSValue = js_value.JSValue;

/// Generic type-safe callback storage
///
/// Ensures proper Global handle lifecycle and type safety.
/// The Signature parameter is used for documentation and future type-safe invocation.
pub fn TypedCallback(comptime Signature: type) type {
    // Signature is used for documentation/future typed invocation
    _ = Signature;

    return struct {
        const Self = @This();

        /// The stored Global handle (null if not set)
        handle: ?GlobalHandle = null,

        // ====================================================================
        // Storage Methods
        // ====================================================================

        /// Set callback from JSValue
        ///
        /// Validates that the value is a function before storing.
        /// If the value is a Local handle, creates a Global for safe storage.
        /// Disposes any previously stored callback.
        pub fn set(self: *Self, value: JSValue, isolate: *v8.Isolate) !void {
            // Dispose existing callback first
            self.dispose();

            switch (value) {
                .global => |g| {
                    // Validate it's a function
                    const v8_value = g.get(isolate) orelse return error.InvalidGlobalHandle;
                    if (!v8.v8_Value_IsFunction(v8_value)) {
                        return error.ExpectedFunction;
                    }
                    self.handle = g;
                },
                .local => |l| {
                    // Validate it's a function
                    if (!v8.v8_Value_IsFunction(l.ptr)) {
                        return error.ExpectedFunction;
                    }
                    // Convert Local to Global for safe storage
                    self.handle = GlobalHandle.create(isolate, @ptrCast(l.ptr)) orelse
                        return error.GlobalHandleCreationFailed;
                },
                .null_value, .undefined_value => {
                    self.handle = null;
                },
                else => return error.ExpectedFunction,
            }
        }

        /// Set callback from GlobalHandle directly
        ///
        /// Assumes the GlobalHandle is already validated as a function.
        /// Use when you've already validated the value is a function.
        pub fn setGlobal(self: *Self, handle: GlobalHandle) void {
            self.dispose();
            self.handle = handle;
        }

        /// Set from legacy anyopaque (for migration)
        ///
        /// Assumes the pointer is a V8 Global handle containing a function.
        /// Returns error if the value is not a function.
        pub fn setAnyopaque(self: *Self, ptr: ?*const anyopaque, isolate: *v8.Isolate) !void {
            if (ptr) |p| {
                // Treat as Global handle pointer (legacy behavior)
                const global = GlobalHandle{ .ptr = @constCast(p) };
                const v8_value = global.get(isolate) orelse return error.InvalidGlobalHandle;
                if (!v8.v8_Value_IsFunction(v8_value)) {
                    return error.ExpectedFunction;
                }
                self.dispose();
                self.handle = global;
            } else {
                self.dispose();
            }
        }

        /// Set from raw V8 Value pointer (Local handle)
        ///
        /// Creates a Global handle for safe storage.
        /// Returns error if the value is not a function.
        pub fn setFromV8Value(self: *Self, value: *v8.Value, isolate: *v8.Isolate) !void {
            self.dispose();

            if (!v8.v8_Value_IsFunction(value)) {
                return error.ExpectedFunction;
            }

            self.handle = GlobalHandle.create(isolate, @ptrCast(value)) orelse
                return error.GlobalHandleCreationFailed;
        }

        // ====================================================================
        // Query Methods
        // ====================================================================

        /// Check if callback is set
        pub fn isSet(self: Self) bool {
            return self.handle != null;
        }

        /// Get the function for manual invocation
        ///
        /// Returns the V8 Function if the callback is set, null otherwise.
        pub fn getFunction(self: Self, isolate: *v8.Isolate) ?*v8.Function {
            const h = self.handle orelse return null;
            const value = h.get(isolate) orelse return null;
            if (v8.v8_Value_IsFunction(value)) {
                return @ptrCast(value);
            }
            return null;
        }

        /// Get as V8 Value for passing to other V8 APIs
        pub fn getValue(self: Self, isolate: *v8.Isolate) ?*v8.Value {
            const h = self.handle orelse return null;
            return h.get(isolate);
        }

        // ====================================================================
        // Invocation Methods
        // ====================================================================

        /// Call with no arguments
        pub fn call0(self: Self, isolate: *v8.Isolate, context: *v8.Context, this: ?*v8.Value) !?*v8.Value {
            const func = self.getFunction(isolate) orelse return error.CallbackNotSet;
            const receiver = this orelse v8.v8_Undefined(isolate) orelse return error.V8Error;
            return v8.v8_Function_Call(func, context, receiver, 0, null);
        }

        /// Call with one argument
        pub fn call1(self: Self, isolate: *v8.Isolate, context: *v8.Context, this: ?*v8.Value, arg0: *v8.Value) !?*v8.Value {
            const func = self.getFunction(isolate) orelse return error.CallbackNotSet;
            const receiver = this orelse v8.v8_Undefined(isolate) orelse return error.V8Error;
            var args = [_]*v8.Value{arg0};
            return v8.v8_Function_Call(func, context, receiver, 1, &args);
        }

        /// Call with two arguments
        pub fn call2(self: Self, isolate: *v8.Isolate, context: *v8.Context, this: ?*v8.Value, arg0: *v8.Value, arg1: *v8.Value) !?*v8.Value {
            const func = self.getFunction(isolate) orelse return error.CallbackNotSet;
            const receiver = this orelse v8.v8_Undefined(isolate) orelse return error.V8Error;
            var args = [_]*v8.Value{ arg0, arg1 };
            return v8.v8_Function_Call(func, context, receiver, 2, &args);
        }

        /// Call with three arguments
        pub fn call3(
            self: Self,
            isolate: *v8.Isolate,
            context: *v8.Context,
            this: ?*v8.Value,
            arg0: *v8.Value,
            arg1: *v8.Value,
            arg2: *v8.Value,
        ) !?*v8.Value {
            const func = self.getFunction(isolate) orelse return error.CallbackNotSet;
            const receiver = this orelse v8.v8_Undefined(isolate) orelse return error.V8Error;
            var args = [_]*v8.Value{ arg0, arg1, arg2 };
            return v8.v8_Function_Call(func, context, receiver, 3, &args);
        }

        /// Call with variable number of arguments
        pub fn callN(
            self: Self,
            isolate: *v8.Isolate,
            context: *v8.Context,
            this: ?*v8.Value,
            args: []*v8.Value,
        ) !?*v8.Value {
            const func = self.getFunction(isolate) orelse return error.CallbackNotSet;
            const receiver = this orelse v8.v8_Undefined(isolate) orelse return error.V8Error;
            return v8.v8_Function_Call(func, context, receiver, @intCast(args.len), args.ptr);
        }

        // ====================================================================
        // Lifecycle Methods
        // ====================================================================

        /// Dispose the callback (releases Global handle)
        ///
        /// This MUST be called when done with the callback, or Global handles will leak!
        /// Safe to call multiple times (no-op if not set).
        pub fn dispose(self: *Self) void {
            if (self.handle) |h| {
                h.dispose();
            }
            self.handle = null;
        }

        /// Clear the callback without disposing the Global handle
        ///
        /// Use when ownership of the Global handle is transferred elsewhere.
        pub fn clear(self: *Self) void {
            self.handle = null;
        }

        /// Convert to legacy anyopaque (for migration)
        ///
        /// Returns the raw Global handle pointer, or null if not set.
        pub fn toAnyopaque(self: Self) ?*const anyopaque {
            const h = self.handle orelse return null;
            return @ptrCast(h.ptr);
        }

        /// Get the underlying GlobalHandle (for advanced use)
        pub fn getHandle(self: Self) ?GlobalHandle {
            return self.handle;
        }
    };
}

// ============================================================================
// Predefined Callback Types
// ============================================================================

/// Signature for event handler callbacks (e.g., onclick, onopen)
pub const EventHandlerSignature = struct {
    pub const Args = struct { event: *v8.Value };
    pub const Return = void;
};

/// Event handler callback (e.g., onclick, onopen)
pub const EventHandlerCallback = TypedCallback(EventHandlerSignature);

/// Signature for transform callbacks (chunk, controller) -> Promise
pub const TransformSignature = struct {
    pub const Args = struct { chunk: *v8.Value, controller: *v8.Value };
    pub const Return = *v8.Value; // Promise
};

/// Transform callback (chunk, controller) -> Promise
pub const TransformCallback = TypedCallback(TransformSignature);

/// Signature for flush callbacks (controller) -> Promise
pub const FlushSignature = struct {
    pub const Args = struct { controller: *v8.Value };
    pub const Return = *v8.Value; // Promise
};

/// Flush callback (controller) -> Promise
pub const FlushCallback = TypedCallback(FlushSignature);

/// Signature for start callbacks (controller) -> Promise|undefined
pub const StartSignature = struct {
    pub const Args = struct { controller: *v8.Value };
    pub const Return = ?*v8.Value; // Promise or undefined
};

/// Start callback (controller) -> Promise|undefined
pub const StartCallback = TypedCallback(StartSignature);

/// Signature for pull callbacks (controller) -> Promise|undefined
pub const PullSignature = struct {
    pub const Args = struct { controller: *v8.Value };
    pub const Return = ?*v8.Value; // Promise or undefined
};

/// Pull callback (controller) -> Promise|undefined
pub const PullCallback = TypedCallback(PullSignature);

/// Signature for cancel callbacks (reason) -> Promise|undefined
pub const CancelSignature = struct {
    pub const Args = struct { reason: ?*v8.Value };
    pub const Return = ?*v8.Value; // Promise or undefined
};

/// Cancel callback (reason) -> Promise|undefined
pub const CancelCallback = TypedCallback(CancelSignature);

/// Signature for write callbacks (chunk, controller) -> Promise|undefined
pub const WriteSignature = struct {
    pub const Args = struct { chunk: *v8.Value, controller: *v8.Value };
    pub const Return = ?*v8.Value; // Promise or undefined
};

/// Write callback (chunk, controller) -> Promise|undefined
pub const WriteCallback = TypedCallback(WriteSignature);

/// Signature for close callbacks () -> Promise|undefined
pub const CloseSignature = struct {
    pub const Args = struct {};
    pub const Return = ?*v8.Value; // Promise or undefined
};

/// Close callback () -> Promise|undefined
pub const CloseCallback = TypedCallback(CloseSignature);

/// Signature for abort callbacks (reason) -> Promise|undefined
pub const AbortSignature = struct {
    pub const Args = struct { reason: ?*v8.Value };
    pub const Return = ?*v8.Value; // Promise or undefined
};

/// Abort callback (reason) -> Promise|undefined
pub const AbortCallback = TypedCallback(AbortSignature);

/// Generic callback with no signature validation
pub const AnyCallback = TypedCallback(struct {});

// ============================================================================
// Tests
// ============================================================================

test "TypedCallback not set" {
    var cb = AnyCallback{};
    try std.testing.expect(!cb.isSet());
    try std.testing.expect(cb.toAnyopaque() == null);
}

test "TypedCallback dispose when not set" {
    var cb = AnyCallback{};
    // Can dispose even when not set (no-op)
    cb.dispose();
    try std.testing.expect(!cb.isSet());
}

test "TypedCallback clear when not set" {
    var cb = AnyCallback{};
    cb.clear();
    try std.testing.expect(!cb.isSet());
}

test "EventHandlerCallback default state" {
    var cb = EventHandlerCallback{};
    try std.testing.expect(!cb.isSet());
    try std.testing.expect(cb.getHandle() == null);
}

test "StartCallback default state" {
    var cb = StartCallback{};
    try std.testing.expect(!cb.isSet());
}

test "WriteCallback default state" {
    var cb = WriteCallback{};
    try std.testing.expect(!cb.isSet());
}
