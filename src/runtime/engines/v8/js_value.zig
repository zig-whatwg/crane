//! # Type-Safe JavaScript Value Representation
//!
//! This module provides `JSValue` and `OptionalJSValue` types for representing
//! JavaScript values in a type-safe manner, replacing raw `*const anyopaque`
//! usage throughout the codebase.
//!
//! ## Problem Statement
//!
//! The current codebase uses `*const anyopaque` for WebIDL `any` type, which:
//! - Loses type information at compilation time
//! - Requires unsafe pointer tagging for runtime type discrimination
//! - Uses `@ptrFromInt(1)` sentinels for "undefined" (dangerous!)
//! - Makes debugging difficult when V8 vs Zig instance pointers are confused
//!
//! ## Solution
//!
//! `JSValue` is a tagged union that explicitly represents the different
//! categories of JavaScript values that can flow through the system:
//!
//! ```zig
//! const value: JSValue = .{ .undefined = {} };
//! const value: JSValue = .{ .null = {} };
//! const value: JSValue = .{ .boolean = true };
//! const value: JSValue = .{ .number = 42.0 };
//! const value: JSValue = .{ .global = .{ .ptr = v8_global_handle } };
//! const value: JSValue = .{ .instance = zig_runtime_instance };
//! ```
//!
//! ## Usage
//!
//! ### Converting from V8 Value (in conversions.zig)
//!
//! ```zig
//! pub fn fromV8ValueTyped(value: *v8.Value, isolate: *v8.Isolate, context: *v8.Context) !JSValue {
//!     if (v8.v8_Value_IsUndefined(value)) return .{ .undefined = {} };
//!     if (v8.v8_Value_IsNull(value)) return .{ .null = {} };
//!     // ... etc
//! }
//! ```
//!
//! ### Checking value type
//!
//! ```zig
//! switch (js_value) {
//!     .undefined => // handle undefined,
//!     .null => // handle null,
//!     .boolean => |b| // use boolean value,
//!     .number => |n| // use number value,
//!     .global => |g| // use V8 global handle,
//!     .instance => |i| // use Zig runtime instance,
//! }
//! ```
//!
//! ### Converting to V8 Value
//!
//! ```zig
//! const v8_value = js_value.toV8(isolate);
//! ```

const std = @import("std");
const v8 = @import("ffi.zig");
const runtime = @import("runtime");
const pointer_tag = @import("pointer_tag.zig");
const GlobalHandleImport = @import("global_handles.zig");

/// Type-safe representation of a JavaScript value.
///
/// This replaces raw `*const anyopaque` for WebIDL `any` type parameters,
/// providing compile-time type safety and eliminating sentinel value hacks.
pub const JSValue = union(enum) {
    /// JavaScript `undefined` value
    undefined_value: void,

    /// JavaScript `null` value
    null_value: void,

    /// JavaScript boolean primitive
    boolean: bool,

    /// JavaScript number primitive (IEEE 754 double)
    number: f64,

    /// JavaScript string (owned, allocated copy)
    string: StringValue,

    /// V8 Global handle - for objects/functions that need to persist
    /// The handle must be disposed when no longer needed
    global: GlobalHandleImport.GlobalHandle,

    /// Zig runtime.Instance - a wrapped WebIDL interface instance
    /// This is NOT a V8 pointer and must not be passed to V8 FFI!
    instance: *runtime.Instance,

    /// V8 Local handle - for temporary values within a HandleScope
    /// WARNING: Only valid within the current HandleScope!
    local: LocalHandle,

    /// String value storage
    pub const StringValue = struct {
        data: []const u8,
        owned: bool,

        pub fn deinit(self: *StringValue, allocator: std.mem.Allocator) void {
            if (self.owned and self.data.len > 0) {
                allocator.free(self.data);
            }
        }
    };

    /// V8 Local handle wrapper (temporary, only valid within HandleScope)
    pub const LocalHandle = struct {
        ptr: *v8.Value,

        /// Convert to Global for persistent storage
        ///
        /// MUST be called before storing the value in a struct field!
        /// Local handles become invalid when their HandleScope ends.
        pub fn toGlobal(self: LocalHandle, isolate: *v8.Isolate) !GlobalHandleImport.GlobalHandle {
            return GlobalHandleImport.GlobalHandle.create(isolate, @ptrCast(self.ptr)) orelse
                return error.GlobalHandleCreationFailed;
        }

        /// Check if this is a function
        pub fn isFunction(self: LocalHandle) bool {
            return v8.v8_Value_IsFunction(self.ptr);
        }

        /// Check if this is an object
        pub fn isObject(self: LocalHandle) bool {
            return v8.v8_Value_IsObject(self.ptr);
        }
    };

    // ========================================================================
    // Constructors
    // ========================================================================

    /// Create an undefined JSValue
    pub const jsUndefined = JSValue{ .undefined_value = {} };

    /// Create a null JSValue
    pub const jsNull = JSValue{ .null_value = {} };

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

    /// Create a JSValue from a V8 Global handle
    pub fn fromGlobal(ptr: *v8.Value) JSValue {
        return .{ .global = GlobalHandleImport.GlobalHandle{ .ptr = ptr } };
    }

    /// Create a JSValue from a Zig runtime instance
    pub fn fromInstance(inst: *runtime.Instance) JSValue {
        return .{ .instance = inst };
    }

    /// Create a JSValue from a V8 Local handle
    pub fn fromLocal(ptr: *v8.Value) JSValue {
        return .{ .local = .{ .ptr = ptr } };
    }

    /// Convert from legacy anyopaque (uses pointer tagging for type detection)
    ///
    /// This is for gradual migration from raw `*const anyopaque` to JSValue.
    /// The pointer must be tagged using pointer_tag.zig conventions.
    pub fn fromAnyopaque(ptr: *const anyopaque) JSValue {
        const untagged = pointer_tag.untagPointer(ptr);

        return switch (untagged.tag) {
            .global_handle => .{ .global = .{ .ptr = @ptrCast(untagged.ptr) } },
            .runtime_instance => .{ .instance = @ptrCast(@alignCast(untagged.ptr)) },
            .local_value => .{ .local = .{ .ptr = @ptrCast(untagged.ptr) } },
            .untagged => {
                // Legacy untagged pointer - assume it's a local value
                // This is for backward compatibility during migration
                return .{ .local = .{ .ptr = @ptrCast(untagged.ptr) } };
            },
        };
    }

    // ========================================================================
    // Type Queries
    // ========================================================================

    /// Check if this is undefined
    pub fn isUndefined(self: JSValue) bool {
        return self == .undefined_value;
    }

    /// Check if this is null
    pub fn isNull(self: JSValue) bool {
        return self == .null_value;
    }

    /// Check if this is null or undefined
    pub fn isNullOrUndefined(self: JSValue) bool {
        return self == .undefined_value or self == .null_value;
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

    /// Check if this is a V8 global handle (object/function)
    pub fn isGlobal(self: JSValue) bool {
        return self == .global;
    }

    /// Check if this is a Zig runtime instance
    pub fn isInstance(self: JSValue) bool {
        return self == .instance;
    }

    /// Check if this is a V8 local handle
    pub fn isLocal(self: JSValue) bool {
        return self == .local;
    }

    /// Check if this value might be callable (function)
    /// Note: Only global handles might be functions; we can't know for sure without V8 check
    pub fn mightBeCallable(self: JSValue) bool {
        return self == .global or self == .local;
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

    /// Get instance pointer, or null if not an instance
    pub fn asInstance(self: JSValue) ?*runtime.Instance {
        return switch (self) {
            .instance => |i| i,
            else => null,
        };
    }

    /// Get global handle pointer, or null if not a global
    pub fn asGlobalPtr(self: JSValue) ?*v8.Value {
        return switch (self) {
            .global => |g| g.ptr,
            else => null,
        };
    }

    /// Get local handle pointer, or null if not a local
    pub fn asLocalPtr(self: JSValue) ?*v8.Value {
        return switch (self) {
            .local => |l| l.ptr,
            else => null,
        };
    }

    /// Convert Local to Global for persistent storage
    ///
    /// REQUIRED before storing JSValue in struct fields!
    /// - If already a Global, returns self unchanged
    /// - If Local, creates a new Global handle
    /// - For primitives (null, undefined, boolean, number, string), returns self unchanged
    /// - For instances, returns self unchanged (Zig pointers don't need V8 handles)
    pub fn toGlobal(self: JSValue, isolate: *v8.Isolate) !JSValue {
        return switch (self) {
            .local => |l| .{ .global = try l.toGlobal(isolate) },
            .global => self, // Already a Global, return as-is
            else => self, // Primitives and instances don't need conversion
        };
    }

    /// Check if this value is callable (a function) by querying V8
    ///
    /// Only Global and Local handles can be functions.
    /// Returns false for primitives, instances, null, undefined.
    pub fn isCallable(self: JSValue, isolate: *v8.Isolate) bool {
        return switch (self) {
            .global => |g| blk: {
                const value = g.get(isolate) orelse break :blk false;
                break :blk v8.v8_Value_IsFunction(value);
            },
            .local => |l| l.isFunction(),
            else => false,
        };
    }

    // ========================================================================
    // V8 Conversion
    // ========================================================================

    /// Convert JSValue to V8 Value for passing back to JavaScript
    pub fn toV8(self: JSValue, isolate: *v8.Isolate) *v8.Value {
        return switch (self) {
            .undefined_value => v8.v8_Undefined(isolate) orelse unreachable,
            .null_value => v8.v8_Null(isolate) orelse unreachable,
            .boolean => |b| v8.v8_Boolean_New(isolate, b) orelse unreachable,
            .number => |n| @ptrCast(v8.v8_Number_New(isolate, n)),
            .string => |s| blk: {
                const str = v8.v8_String_NewFromUtf8(
                    isolate,
                    s.data.ptr,
                    @intCast(s.data.len),
                ) orelse {
                    break :blk v8.v8_Undefined(isolate) orelse unreachable;
                };
                break :blk @ptrCast(str);
            },
            .global => |g| @ptrCast(g.ptr),
            .instance => |_| {
                // Instance needs proper wrapping via template registry
                // For now return undefined - caller should use instanceToV8()
                return v8.v8_Undefined(isolate) orelse unreachable;
            },
            .local => |l| l.ptr,
        };
    }

    /// Convert to *const anyopaque for legacy compatibility
    ///
    /// WARNING: This loses type information! Use only for transitional code.
    /// The returned pointer is tagged using pointer_tag.zig conventions.
    pub fn toAnyopaque(self: JSValue) ?*const anyopaque {
        return switch (self) {
            .undefined_value, .null_value => null,
            .boolean => null, // Booleans can't be represented as pointers
            .number => null, // Numbers can't be represented as pointers
            .string => null, // Strings need allocation
            .global => |g| pointer_tag.tagPointer(@ptrCast(g.ptr), .global_handle),
            .instance => |i| pointer_tag.tagPointer(@ptrCast(i), .runtime_instance),
            .local => |l| pointer_tag.tagPointer(@ptrCast(l.ptr), .local_value),
        };
    }

    // ========================================================================
    // Cleanup
    // ========================================================================

    /// Free any owned resources
    pub fn deinit(self: *JSValue, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .string => |*s| s.deinit(allocator),
            .global => |g| g.dispose(),
            else => {},
        }
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
// Tests
// ============================================================================

test "JSValue undefined" {
    const value = JSValue.jsUndefined;
    try std.testing.expect(value.isUndefined());
    try std.testing.expect(value.isNullOrUndefined());
    try std.testing.expect(!value.isNull());
    try std.testing.expect(!value.isBoolean());
}

test "JSValue null value" {
    const value = JSValue.jsNull;
    try std.testing.expect(value.isNull());
    try std.testing.expect(value.isNullOrUndefined());
    try std.testing.expect(!value.isUndefined());
}

test "JSValue null with jsNull" {
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

test "JSValue toAnyopaque for non-pointer types returns null" {
    const undef = JSValue.jsUndefined;
    try std.testing.expect(undef.toAnyopaque() == null);

    const boolean = JSValue.fromBoolean(true);
    try std.testing.expect(boolean.toAnyopaque() == null);

    const number = JSValue.fromNumber(42);
    try std.testing.expect(number.toAnyopaque() == null);
}
