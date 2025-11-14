//! WebIDL Callback Functions and Interfaces
//!
//! Spec: https://webidl.spec.whatwg.org/#idl-callback-functions
//!       https://webidl.spec.whatwg.org/#idl-callback-interfaces
//!
//! Callbacks represent JavaScript functions and objects that can be invoked from native code.
//!
//! # Engine Integration
//!
//! This module provides TWO callback representations:
//!
//! 1. **GenericCallback** - Vtable-based, engine-agnostic (for dictionary extraction)
//! 2. **CallbackFunction(ReturnType, Args)** - Type-safe, generic (for typed APIs)
//!
//! The `zig-js-runtime` codegen will provide engine-specific vtable implementations.

const std = @import("std");
const primitives = @import("primitives.zig");

// ============================================================================
// Engine-Agnostic Callback (for dictionary extraction)
// ============================================================================

/// Opaque callback handle - engine-agnostic representation
///
/// This is intentionally opaque. The zig-js-runtime codegen will:
/// 1. Map this to engine-specific types (v8::Function*, JSObjectRef, etc.)
/// 2. Generate invoke wrappers that call through engine FFI
/// 3. Handle lifetime management per engine semantics
///
/// Design: Keep webidl library engine-agnostic. Runtime knows engines.
///
/// Example usage:
/// ```zig
/// // Extract callback from dictionary
/// const on_success = try extractCallback(js_value, "onSuccess", false);
/// if (on_success) |callback| {
///     // Later, invoke via zig-js-runtime
///     // const result = try runtime.invokeCallback(callback, &args);
/// }
/// ```
pub const GenericCallback = struct {
    /// Engine-specific function handle (type-erased)
    /// - V8: v8::Persistent<v8::Function>*
    /// - JSC: JSObjectRef (retained)
    /// - SpiderMonkey: JS::PersistentRooted<JSObject*>*
    handle: *anyopaque,

    /// Engine-specific context (for multi-isolate support)
    context: ?*anyopaque = null,

    /// Vtable for engine operations (set by zig-js-runtime)
    vtable: *const CallbackVTable,
};

/// Vtable for engine-specific callback operations
/// zig-js-runtime generates implementations for each engine
pub const CallbackVTable = struct {
    /// Invoke callback with arguments
    /// Returns JSValue result or error
    invoke: *const fn (handle: *anyopaque, context: ?*anyopaque, args: []const primitives.JSValue) anyerror!primitives.JSValue,

    /// Release callback reference (called on deinit)
    release: *const fn (handle: *anyopaque, context: ?*anyopaque) void,

    /// Check if callback is valid/callable
    isCallable: *const fn (handle: *anyopaque, context: ?*anyopaque) bool,
};

// ============================================================================
// Existing Generic Callbacks (type-safe)
// ============================================================================

pub const CallbackContext = struct {
    incumbent_settings: ?*anyopaque,
    callback_context: ?*anyopaque,

    pub fn init() CallbackContext {
        return .{
            .incumbent_settings = null,
            .callback_context = null,
        };
    }
};

pub fn CallbackFunction(comptime ReturnType: type, comptime Args: type) type {
    return struct {
        function_ref: *const anyopaque,
        context: CallbackContext,

        const Self = @This();

        pub fn init(function_ref: *const anyopaque, context: CallbackContext) Self {
            return .{
                .function_ref = function_ref,
                .context = context,
            };
        }

        pub fn invoke(self: Self, args: Args) !ReturnType {
            _ = self;
            _ = args;
            return error.CallbackNotImplemented;
        }

        pub fn invokeWithDefault(self: Self, args: Args, default: ReturnType) ReturnType {
            return self.invoke(args) catch default;
        }
    };
}

pub const CallbackInterface = struct {
    object_ref: *const anyopaque,
    context: CallbackContext,

    pub fn init(object_ref: *const anyopaque, context: CallbackContext) CallbackInterface {
        return .{
            .object_ref = object_ref,
            .context = context,
        };
    }

    pub fn invokeOperation(
        self: CallbackInterface,
        comptime ReturnType: type,
        operation_name: []const u8,
        args: anytype,
    ) !ReturnType {
        _ = self;
        _ = operation_name;
        _ = args;
        return error.CallbackNotImplemented;
    }
};

pub fn SingleOperationCallbackInterface(comptime ReturnType: type, comptime Args: type) type {
    return struct {
        interface: CallbackInterface,
        operation_name: []const u8,

        const Self = @This();

        pub fn init(object_ref: *const anyopaque, context: CallbackContext, operation_name: []const u8) Self {
            return .{
                .interface = CallbackInterface.init(object_ref, context),
                .operation_name = operation_name,
            };
        }

        pub fn invoke(self: Self, args: Args) !ReturnType {
            return self.interface.invokeOperation(ReturnType, self.operation_name, args);
        }
    };
}

pub fn treatAsFunction(callback_interface: CallbackInterface, comptime ReturnType: type, comptime Args: type) !CallbackFunction(ReturnType, Args) {
    return CallbackFunction(ReturnType, Args).init(callback_interface.object_ref, callback_interface.context);
}

const testing = std.testing;









