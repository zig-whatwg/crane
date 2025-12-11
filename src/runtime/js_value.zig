//! # Engine-Agnostic JavaScript Value Type
//!
//! This module provides `JSValue` - a type-safe, engine-agnostic representation
//! of JavaScript values for use in WebIDL impl files.
//!
//! ## Design Goals
//!
//! 1. **Engine Independence**: No imports from engine-specific modules (v8, jsc, etc.)
//! 2. **Type Safety**: Tagged union prevents type confusion at compile time
//! 3. **No Sentinel Values**: Explicit undefined/null variants instead of @ptrFromInt(1)
//! 4. **Lifecycle Clarity**: Distinguish between values that need disposal and those that don't
//!
//! ## Usage in Impl Files
//!
//! ```zig
//! const runtime = @import("runtime");
//!
//! pub fn call_forEach(instance: *runtime.Instance, callback: runtime.JSValue) !void {
//!     if (callback.isNullOrUndefined()) return;
//!
//!     // Get engine to invoke callback
//!     const ctx = instance.ctx;
//!     const engine = ctx.getEngine() orelse return error.NoEngine;
//!
//!     // Convert to engine-specific handle for invocation
//!     const handle = callback.asEngineHandle() orelse return error.InvalidCallback;
//!     try engine.invokeCallback(ctx.engine_ctx, handle, &.{});
//! }
//! ```
//!
//! ## Relationship to Engine-Specific Types
//!
//! - `runtime.JSValue` is the PUBLIC type used in impl files
//! - `v8.JSValue` (in src/runtime/engines/v8/) is the engine-specific implementation
//! - The two are compatible via `asEngineHandle()` and engine conversion functions

const std = @import("std");

/// Engine-agnostic JavaScript value representation.
///
/// This is the type that WebIDL impl files should use for `any` and `object`
/// type parameters. It provides type safety without coupling to a specific
/// JavaScript engine.
///
/// The engine-specific conversion happens at the boundary when calling
/// engine operations through EngineInterface.
pub const JSValue = union(enum) {
    /// JavaScript `undefined` value
    undefined: void,

    /// JavaScript `null` value
    null: void,

    /// JavaScript boolean primitive
    boolean: bool,

    /// JavaScript number primitive (IEEE 754 double)
    number: f64,

    /// JavaScript string value
    /// The data may or may not be owned depending on context
    string: StringValue,

    /// Opaque handle to an engine-managed object/function
    /// This could be a V8 Global handle, JSC JSValueRef, etc.
    /// The handle is managed by the engine and may need disposal
    handle: EngineHandle,

    /// Zig runtime.Instance pointer
    /// This is NOT a JavaScript value - it's a Zig object that may be
    /// wrapped by the engine when returned to JavaScript
    instance: *anyopaque,

    // ========================================================================
    // Nested Types
    // ========================================================================

    /// String value storage
    pub const StringValue = struct {
        data: []const u8,
        owned: bool,

        /// Free owned string data
        pub fn deinit(self: *StringValue, allocator: std.mem.Allocator) void {
            if (self.owned and self.data.len > 0) {
                allocator.free(self.data);
            }
        }
    };

    /// Opaque engine handle
    /// The actual pointer type depends on the engine:
    /// - V8: Global<Value>* (persistent handle)
    /// - JSC: JSValueRef (protected value)
    /// - SpiderMonkey: JS::PersistentRooted<JS::Value>*
    pub const EngineHandle = struct {
        ptr: *anyopaque,

        /// Engine-specific disposal flag
        /// If true, the engine's disposal function should be called
        needs_disposal: bool = true,

        /// Handle scope type - whether this handle is local (stack-bound) or global (heap)
        /// Local handles are only valid within the current HandleScope and must NOT be stored
        /// Global handles persist until explicitly disposed and CAN be stored
        handle_scope: HandleScope = .global,

        /// Handle scope discriminator
        pub const HandleScope = enum {
            /// Local handle - only valid within current HandleScope
            /// WARNING: Do NOT store in struct fields!
            local,
            /// Global handle - persists until explicit disposal
            /// Safe to store in struct fields
            global,
        };

        /// Check if this handle can safely be stored in struct fields
        pub fn canBeStored(self: EngineHandle) bool {
            return self.handle_scope == .global;
        }

        /// Debug assertion to verify handle is global before storage
        /// In release builds, this is a no-op
        pub fn assertGlobalForStorage(self: EngineHandle) void {
            if (@import("builtin").mode == .Debug) {
                if (self.handle_scope != .global) {
                    @panic("Attempted to store a local V8 handle! Convert to Global first.");
                }
            }
        }
    };

    // ========================================================================
    // Constructors
    // ========================================================================

    /// Create an undefined JSValue
    pub const jsUndefined = JSValue{ .undefined = {} };

    /// Create a null JSValue
    pub const jsNull = JSValue{ .null = {} };

    /// Create a boolean JSValue
    pub fn fromBoolean(value: bool) JSValue {
        return .{ .boolean = value };
    }

    /// Create a number JSValue
    pub fn fromNumber(value: f64) JSValue {
        return .{ .number = value };
    }

    /// Create a string JSValue (does not take ownership)
    pub fn fromStringRef(data: []const u8) JSValue {
        return .{ .string = .{ .data = data, .owned = false } };
    }

    /// Create a string JSValue (takes ownership of allocated slice)
    pub fn fromStringOwned(data: []const u8) JSValue {
        return .{ .string = .{ .data = data, .owned = true } };
    }

    /// Create a JSValue from a GLOBAL engine handle (safe to store)
    /// Use this for Global<Value> handles that persist beyond HandleScope
    pub fn fromHandle(ptr: *anyopaque) JSValue {
        return .{ .handle = .{ .ptr = ptr, .needs_disposal = true, .handle_scope = .global } };
    }

    /// Create a JSValue from a GLOBAL handle that doesn't need disposal
    /// (e.g., when the caller retains ownership)
    pub fn fromHandleNonOwning(ptr: *anyopaque) JSValue {
        return .{ .handle = .{ .ptr = ptr, .needs_disposal = false, .handle_scope = .global } };
    }

    /// Create a JSValue from a LOCAL engine handle (DO NOT store!)
    /// Use this for temporary values within a HandleScope
    /// WARNING: The returned JSValue must NOT be stored in struct fields!
    pub fn fromLocalHandle(ptr: *anyopaque) JSValue {
        return .{ .handle = .{ .ptr = ptr, .needs_disposal = false, .handle_scope = .local } };
    }

    /// Create a JSValue from a V8 Promise pointer.
    ///
    /// Use this when returning promises to JavaScript. The promise pointer
    /// should be obtained from:
    /// - `Promise(T).getPromise()` (from src/runtime/engines/v8/promise.zig)
    /// - `asyncPromiseToV8()` (bridge from Zig AsyncPromise to V8 Promise)
    /// - `createRejectedV8Promise()` or `createResolvedV8Promise()`
    ///
    /// ## IMPORTANT
    ///
    /// Do NOT use `fromAnyopaque(@ptrCast(zig_promise))` for Zig AsyncPromise!
    /// Zig pointers are NOT V8 handles and will cause crashes.
    ///
    /// ## Example
    ///
    /// ```zig
    /// // WRONG - Zig pointer is not a V8 handle!
    /// const zig_promise = try AsyncPromise(void).init(allocator, event_loop);
    /// return runtime.JSValue.fromAnyopaque(@ptrCast(zig_promise)); // CRASH!
    ///
    /// // CORRECT - Use the bridge to create a V8 Promise
    /// const v8_promise = try asyncPromiseToV8(void, allocator, isolate, context, zig_promise);
    /// return runtime.JSValue.fromPromise(v8_promise);
    /// ```
    pub fn fromPromise(promise_ptr: *anyopaque) JSValue {
        // V8 Promises are V8 handles and should be treated as global handles
        // that don't need disposal (V8's GC manages them once returned to JS)
        return .{ .handle = .{ .ptr = promise_ptr, .needs_disposal = false, .handle_scope = .global } };
    }

    /// Create a JSValue from a Zig runtime instance
    pub fn fromInstance(inst: *anyopaque) JSValue {
        return .{ .instance = inst };
    }

    /// Create from legacy anyopaque pointer
    ///
    /// This is for gradual migration. The pointer is treated as an engine handle.
    /// Use with caution - the type information is lost.
    pub fn fromAnyopaque(ptr: ?*const anyopaque) JSValue {
        if (ptr) |p| {
            return .{ .handle = .{ .ptr = @ptrCast(@constCast(p)), .needs_disposal = false } };
        }
        return jsNull;
    }

    // ========================================================================
    // Type Queries
    // ========================================================================

    /// Check if this is undefined
    pub fn isUndefined(self: JSValue) bool {
        return self == .undefined;
    }

    /// Check if this is null
    pub fn isNull(self: JSValue) bool {
        return self == .null;
    }

    /// Check if this is null or undefined
    pub fn isNullOrUndefined(self: JSValue) bool {
        return self == .undefined or self == .null;
    }

    /// Check if this is a boolean
    pub fn isBoolean(self: JSValue) bool {
        return self == .boolean;
    }

    /// Check if this is a number
    pub fn isNumber(self: JSValue) bool {
        return self == .number;
    }

    /// Check if this is a string
    pub fn isString(self: JSValue) bool {
        return self == .string;
    }

    /// Check if this is an engine handle (object/function)
    pub fn isHandle(self: JSValue) bool {
        return self == .handle;
    }

    /// Check if this is a Zig instance
    pub fn isInstance(self: JSValue) bool {
        return self == .instance;
    }

    // ========================================================================
    // Value Extraction
    // ========================================================================

    /// Get boolean value, or null if not a boolean
    pub fn asBoolean(self: JSValue) ?bool {
        return switch (self) {
            .boolean => |b| b,
            else => null,
        };
    }

    /// Get number value, or null if not a number
    pub fn asNumber(self: JSValue) ?f64 {
        return switch (self) {
            .number => |n| n,
            else => null,
        };
    }

    /// Get string value, or null if not a string
    pub fn asString(self: JSValue) ?[]const u8 {
        return switch (self) {
            .string => |s| s.data,
            else => null,
        };
    }

    /// Get engine handle pointer, or null if not a handle
    pub fn asEngineHandle(self: JSValue) ?*anyopaque {
        return switch (self) {
            .handle => |h| h.ptr,
            else => null,
        };
    }

    /// Get instance pointer, or null if not an instance
    pub fn asInstance(self: JSValue) ?*anyopaque {
        return switch (self) {
            .instance => |i| i,
            else => null,
        };
    }

    /// Convert to legacy anyopaque pointer
    ///
    /// WARNING: This loses type information! Use only for transitional code.
    pub fn toAnyopaque(self: JSValue) ?*const anyopaque {
        return switch (self) {
            .undefined, .null => null,
            .boolean => null, // Booleans can't be represented as pointers
            .number => null, // Numbers can't be represented as pointers
            .string => null, // Strings need special handling
            .handle => |h| @ptrCast(h.ptr),
            .instance => |i| @ptrCast(i),
        };
    }

    // ========================================================================
    // Lifecycle
    // ========================================================================

    /// Check if this value needs engine-side disposal
    pub fn needsDisposal(self: JSValue) bool {
        return switch (self) {
            .handle => |h| h.needs_disposal,
            .string => |s| s.owned,
            else => false,
        };
    }

    /// Free any owned resources (strings only - engine handles need engine disposal)
    pub fn deinit(self: *JSValue, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .string => |*s| s.deinit(allocator),
            else => {},
        }
        self.* = jsUndefined;
    }
};

/// Optional JSValue - used for WebIDL optional parameters
///
/// This distinguishes between:
/// - Parameter was not passed at all (not_passed)
/// - Parameter was passed with a value (passed)
pub const OptionalJSValue = union(enum) {
    /// Parameter was not passed
    not_passed: void,

    /// Parameter was passed with this value
    passed: JSValue,

    /// Check if parameter was passed
    pub fn wasPassed(self: OptionalJSValue) bool {
        return self == .passed;
    }

    /// Get the value if passed, or null
    pub fn getValue(self: OptionalJSValue) ?JSValue {
        return switch (self) {
            .not_passed => null,
            .passed => |v| v,
        };
    }

    /// Get the value if passed, or return default
    pub fn getValueOr(self: OptionalJSValue, default: JSValue) JSValue {
        return switch (self) {
            .not_passed => default,
            .passed => |v| v,
        };
    }

    /// Create from a value
    pub fn fromValue(value: JSValue) OptionalJSValue {
        return .{ .passed = value };
    }

    /// Create not-passed variant
    pub const notPassed = OptionalJSValue{ .not_passed = {} };

    /// Free any owned resources
    pub fn deinit(self: *OptionalJSValue, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .passed => |*v| v.deinit(allocator),
            .not_passed => {},
        }
    }
};

// ============================================================================
// LocalValue - Move-only type for temporary V8 values
// ============================================================================

/// A V8 Local handle that is only valid within the current HandleScope.
///
/// This type is designed to PREVENT accidental storage of Local handles.
/// It should be used for temporary values that are:
/// - Returned from V8 FFI calls
/// - Used within a single function
/// - NOT stored in struct fields
///
/// To persist the value beyond the HandleScope, convert to a GlobalHandle
/// using `toGlobal()`.
///
/// ## Usage
///
/// ```zig
/// // Get a local value from V8
/// const local = LocalValue.fromRawPtr(v8_function_call_result);
///
/// // Use it immediately
/// const result = try someV8Operation(local.rawPtr());
///
/// // If you need to store it, convert to global first
/// if (local.toGlobal(isolate)) |global| {
///     my_struct.stored_callback = global;
/// }
/// ```
pub const LocalValue = struct {
    /// The underlying V8 Local value pointer
    ptr: *anyopaque,

    /// Create a LocalValue from a raw pointer (from V8 FFI)
    pub fn fromRawPtr(ptr: *anyopaque) LocalValue {
        return .{ .ptr = ptr };
    }

    /// Get the raw pointer for FFI calls
    /// WARNING: Use immediately, do NOT store the result!
    pub fn rawPtr(self: LocalValue) *anyopaque {
        return self.ptr;
    }

    /// Convert to a JSValue (marked as local, should not be stored)
    pub fn toJSValue(self: LocalValue) JSValue {
        return JSValue.fromLocalHandle(self.ptr);
    }

    /// Check if this contains a valid (non-null) pointer
    pub fn isValid(self: LocalValue) bool {
        // In V8, null pointers indicate empty handles
        return self.ptr != @as(*anyopaque, @ptrFromInt(0));
    }
};

/// Create a LocalValue from an optional raw pointer
pub fn localValueFromOptional(ptr: ?*anyopaque) ?LocalValue {
    if (ptr) |p| {
        return LocalValue.fromRawPtr(p);
    }
    return null;
}

// ============================================================================
// Promise - Type-safe wrapper for V8 Promises
// ============================================================================

/// A type-safe wrapper for V8 Promise handles.
///
/// Promises ALWAYS use GlobalHandle internally to ensure the promise
/// survives beyond the HandleScope where it was created. This prevents
/// use-after-free when the promise is resolved/rejected later.
///
/// ## Type Parameter
///
/// The type parameter `T` represents the resolved value type.
/// This is for documentation purposes - the actual JavaScript value
/// is stored in the GlobalHandle.
///
/// ## Usage
///
/// ```zig
/// // Create a promise
/// const promise = try Promise(void).create(isolate, local_promise_ptr);
/// defer promise.deinit();
///
/// // Store it safely
/// my_struct.pending_promise = promise;
///
/// // Later, resolve or reject
/// try promise.resolve(isolate, result_value);
/// ```
pub fn Promise(comptime T: type) type {
    _ = T; // Type parameter for documentation only

    return struct {
        /// The GlobalHandle storing the Promise object
        /// This MUST be a global handle to survive HandleScope destruction
        handle: ?*anyopaque = null,

        /// Whether this promise handle is valid
        is_valid: bool = false,

        const Self = @This();

        /// Create a Promise from a local promise pointer
        /// The local handle is converted to a global handle for storage
        pub fn create(handle_ptr: *anyopaque) Self {
            return .{
                .handle = handle_ptr,
                .is_valid = true,
            };
        }

        /// Create an empty/invalid promise
        pub fn empty() Self {
            return .{
                .handle = null,
                .is_valid = false,
            };
        }

        /// Check if this promise is valid
        pub fn isValid(self: Self) bool {
            return self.is_valid and self.handle != null;
        }

        /// Get the raw handle pointer for V8 operations
        pub fn getHandle(self: Self) ?*anyopaque {
            if (self.is_valid) {
                return self.handle;
            }
            return null;
        }

        /// Dispose of the promise handle
        /// After calling this, the promise should not be used
        pub fn deinit(self: *Self) void {
            self.handle = null;
            self.is_valid = false;
        }
    };
}

// ============================================================================
// Tests
// ============================================================================

test "JSValue undefined" {
    const value = JSValue.jsUndefined;
    try std.testing.expect(value.isUndefined());
    try std.testing.expect(value.isNullOrUndefined());
    try std.testing.expect(!value.isNull());
    try std.testing.expect(!value.isBoolean());
}

test "JSValue null" {
    const value = JSValue.jsNull;
    try std.testing.expect(value.isNull());
    try std.testing.expect(value.isNullOrUndefined());
    try std.testing.expect(!value.isUndefined());
}

test "JSValue boolean" {
    const value_true = JSValue.fromBoolean(true);
    const value_false = JSValue.fromBoolean(false);

    try std.testing.expect(value_true.isBoolean());
    try std.testing.expectEqual(true, value_true.asBoolean());
    try std.testing.expectEqual(false, value_false.asBoolean());
}

test "JSValue number" {
    const value = JSValue.fromNumber(42.5);
    try std.testing.expect(value.isNumber());
    try std.testing.expectEqual(@as(f64, 42.5), value.asNumber().?);
}

test "JSValue string" {
    const value = JSValue.fromStringRef("hello");
    try std.testing.expect(value.isString());
    try std.testing.expectEqualStrings("hello", value.asString().?);
    try std.testing.expect(!value.needsDisposal());
}

test "JSValue handle" {
    var dummy: u8 = 0;
    const value = JSValue.fromHandle(&dummy);
    try std.testing.expect(value.isHandle());
    try std.testing.expect(value.asEngineHandle().? == @as(*anyopaque, &dummy));
    try std.testing.expect(value.needsDisposal());
}

test "JSValue handle non-owning" {
    var dummy: u8 = 0;
    const value = JSValue.fromHandleNonOwning(&dummy);
    try std.testing.expect(value.isHandle());
    try std.testing.expect(value.asEngineHandle().? == @as(*anyopaque, &dummy));
    try std.testing.expect(!value.needsDisposal());
}

test "OptionalJSValue not passed" {
    const opt = OptionalJSValue.notPassed;
    try std.testing.expect(!opt.wasPassed());
    try std.testing.expect(opt.getValue() == null);
}

test "OptionalJSValue passed" {
    const opt = OptionalJSValue.fromValue(JSValue.fromNumber(123));
    try std.testing.expect(opt.wasPassed());
    try std.testing.expectEqual(@as(f64, 123), opt.getValue().?.asNumber().?);
}

test "JSValue toAnyopaque for primitives returns null" {
    const undef = JSValue.jsUndefined;
    try std.testing.expect(undef.toAnyopaque() == null);

    const boolean = JSValue.fromBoolean(true);
    try std.testing.expect(boolean.toAnyopaque() == null);

    const number = JSValue.fromNumber(42);
    try std.testing.expect(number.toAnyopaque() == null);
}

test "JSValue toAnyopaque for handle returns pointer" {
    var dummy: u8 = 0;
    const value = JSValue.fromHandle(&dummy);
    try std.testing.expect(value.toAnyopaque() != null);
}

test "JSValue handle scope - global can be stored" {
    var dummy: u8 = 0;
    const value = JSValue.fromHandle(&dummy);
    switch (value) {
        .handle => |h| {
            try std.testing.expect(h.handle_scope == .global);
            try std.testing.expect(h.canBeStored());
        },
        else => try std.testing.expect(false),
    }
}

test "JSValue handle scope - local should not be stored" {
    var dummy: u8 = 0;
    const value = JSValue.fromLocalHandle(&dummy);
    switch (value) {
        .handle => |h| {
            try std.testing.expect(h.handle_scope == .local);
            try std.testing.expect(!h.canBeStored());
        },
        else => try std.testing.expect(false),
    }
}

test "LocalValue basic operations" {
    var dummy: u8 = 42;
    const local = LocalValue.fromRawPtr(&dummy);
    try std.testing.expect(local.isValid());
    try std.testing.expect(local.rawPtr() == @as(*anyopaque, &dummy));
}

test "LocalValue to JSValue marks as local" {
    var dummy: u8 = 0;
    const local = LocalValue.fromRawPtr(&dummy);
    const js_value = local.toJSValue();
    switch (js_value) {
        .handle => |h| {
            try std.testing.expect(h.handle_scope == .local);
        },
        else => try std.testing.expect(false),
    }
}

test "Promise type wrapper" {
    var dummy: u8 = 0;
    const PromiseVoid = Promise(void);
    var promise = PromiseVoid.create(&dummy);
    try std.testing.expect(promise.isValid());
    try std.testing.expect(promise.getHandle() != null);

    promise.deinit();
    try std.testing.expect(!promise.isValid());
    try std.testing.expect(promise.getHandle() == null);
}

test "Promise empty" {
    const PromiseVoid = Promise(void);
    const promise = PromiseVoid.empty();
    try std.testing.expect(!promise.isValid());
    try std.testing.expect(promise.getHandle() == null);
}
