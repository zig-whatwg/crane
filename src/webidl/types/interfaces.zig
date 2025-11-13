//! WebIDL Interface Object Support
//!
//! Spec: https://webidl.spec.whatwg.org/#dfn-interface-object
//!
//! This module provides runtime support for WebIDL interface types, allowing
//! Zig implementations to be wrapped/unwrapped from JSValue for FFI boundaries.
//!
//! ## Architecture
//!
//! Following browser implementations (Chrome/V8, Firefox/SpiderMonkey, Safari/JSC):
//! - JSValue.interface_ptr stores type-erased pointer to native Zig object
//! - wrapInterface() wraps a Zig pointer into JSValue
//! - unwrapInterface() extracts Zig pointer from JSValue with type checking
//!
//! ## Usage
//!
//! ```zig
//! const webidl = @import("webidl");
//! const WritableStream = @import("streams").WritableStream;
//!
//! // Wrapping a native object
//! var stream = try WritableStream.init(allocator);
//! const js_value = webidl.wrapInterface(WritableStream, &stream);
//!
//! // Unwrapping back to native
//! const unwrapped = try webidl.unwrapInterface(WritableStream, js_value);
//! // unwrapped is *WritableStream
//! ```
//!
//! ## IMPORTANT: When to Use
//!
//! - ✅ Use for WebIDL interface parameters (ReadableStream, WritableStream, etc.)
//! - ✅ Use at FFI boundaries between JS and Zig
//! - ❌ DO NOT use for internal Zig code (use pointers directly)
//! - ❌ DO NOT use for primitive types (use existing JSValue variants)

const std = @import("std");
const primitives = @import("primitives.zig");

/// Wrapper for WebIDL interface objects
///
/// This type is stored in JSValue.interface_ptr and represents a
/// native Zig object that implements a WebIDL interface.
pub const InterfaceWrapper = struct {
    /// Type-erased pointer to the native object
    ptr: *anyopaque,

    /// Type name for runtime type checking
    /// In production: would use type ID or vtable
    /// For now: string comparison (debug builds only)
    type_name: []const u8,

    /// Reserved for future use (vtable, prototype chain, etc.)
    vtable: ?*const anyopaque = null,
};

/// Wrap a Zig interface pointer into a JSValue
///
/// This is the FFI boundary: converts native Zig objects into
/// JSValue for passing to JavaScript or storing in WebIDL types.
///
/// Example:
/// ```zig
/// var stream = try WritableStream.init(allocator);
/// const js_value = wrapInterface(WritableStream, &stream);
/// ```
///
/// Spec: § 3.2.1 Interface objects
pub fn wrapInterface(comptime T: type, ptr: *T) primitives.JSValue {
    return .{
        .interface_ptr = .{
            .ptr = @ptrCast(ptr),
            .type_name = @typeName(T),
            .vtable = null,
        },
    };
}

/// Wrap a const Zig interface pointer into a JSValue
///
/// Same as wrapInterface but for const pointers (read-only access).
pub fn wrapInterfaceConst(comptime T: type, ptr: *const T) primitives.JSValue {
    // Note: We still store mutable pointer but caller must ensure read-only use
    return .{
        .interface_ptr = .{
            .ptr = @ptrCast(@constCast(ptr)),
            .type_name = @typeName(T),
            .vtable = null,
        },
    };
}

/// Unwrap a JSValue to a Zig interface pointer
///
/// This is the FFI boundary: extracts native Zig objects from
/// JSValue received from JavaScript or WebIDL method calls.
///
/// Returns error.TypeError if:
/// - JSValue is not an interface_ptr
/// - Type name doesn't match (type mismatch)
///
/// Example:
/// ```zig
/// pub fn pipeTo(self: *ReadableStream, dest_value: webidl.JSValue) !void {
///     const dest = try webidl.unwrapInterface(WritableStream, dest_value);
///     // dest is *WritableStream
///     try self.pipeToInternal(dest);
/// }
/// ```
///
/// Spec: § 3.2.1 Interface objects
pub fn unwrapInterface(comptime T: type, value: primitives.JSValue) !*T {
    if (value != .interface_ptr) return error.TypeError;

    const wrapper = value.interface_ptr;

    // Runtime type check (always enforced for safety)
    const expected_name = @typeName(T);
    if (!std.mem.eql(u8, wrapper.type_name, expected_name)) {
        if (std.debug.runtime_safety) {
            std.debug.print(
                "Type mismatch: expected {s}, got {s}\n",
                .{ expected_name, wrapper.type_name },
            );
        }
        return error.TypeError;
    }

    return @ptrCast(@alignCast(wrapper.ptr));
}

/// Unwrap a JSValue to a const Zig interface pointer
///
/// Same as unwrapInterface but returns const pointer (read-only access).
pub fn unwrapInterfaceConst(comptime T: type, value: primitives.JSValue) !*const T {
    const mutable = try unwrapInterface(T, value);
    return mutable;
}

/// Check if a JSValue is a wrapped interface
///
/// Returns true if value is interface_ptr, false otherwise.
pub fn isInterface(value: primitives.JSValue) bool {
    return value == .interface_ptr;
}

/// Check if a JSValue is a specific interface type
///
/// Returns true if value is interface_ptr with matching type name.
pub fn isInterfaceType(comptime T: type, value: primitives.JSValue) bool {
    if (value != .interface_ptr) return false;

    const expected_name = @typeName(T);
    return std.mem.eql(u8, value.interface_ptr.type_name, expected_name);
}

// Tests

const testing = std.testing;

// Mock interface for testing
const MockInterface = struct {
    value: i32,

    pub fn init(value: i32) MockInterface {
        return .{ .value = value };
    }
};

test "wrapInterface - basic wrapping" {
    var obj = MockInterface.init(42);
    const js_value = wrapInterface(MockInterface, &obj);

    try testing.expect(js_value == .interface_ptr);
    try testing.expectEqualStrings(@typeName(MockInterface), js_value.interface_ptr.type_name);
}

test "unwrapInterface - basic unwrapping" {
    var obj = MockInterface.init(42);
    const js_value = wrapInterface(MockInterface, &obj);

    const unwrapped = try unwrapInterface(MockInterface, js_value);
    try testing.expectEqual(@as(i32, 42), unwrapped.value);
    try testing.expectEqual(&obj, unwrapped);
}

test "unwrapInterface - type mismatch error" {
    const OtherInterface = struct { x: f64 };

    var obj = MockInterface.init(42);
    const js_value = wrapInterface(MockInterface, &obj);

    // Should fail because type doesn't match
    try testing.expectError(error.TypeError, unwrapInterface(OtherInterface, js_value));
}

test "unwrapInterface - not an interface error" {
    const js_value = primitives.JSValue{ .number = 42.0 };

    try testing.expectError(error.TypeError, unwrapInterface(MockInterface, js_value));
}

test "wrapInterfaceConst and unwrapInterfaceConst" {
    const obj = MockInterface.init(42);
    const js_value = wrapInterfaceConst(MockInterface, &obj);

    const unwrapped = try unwrapInterfaceConst(MockInterface, js_value);
    try testing.expectEqual(@as(i32, 42), unwrapped.value);
}

test "isInterface - basic check" {
    var obj = MockInterface.init(42);
    const js_value = wrapInterface(MockInterface, &obj);

    try testing.expect(isInterface(js_value));
    try testing.expect(!isInterface(primitives.JSValue{ .number = 42.0 }));
}

test "isInterfaceType - type checking" {
    const OtherInterface = struct { x: f64 };

    var obj = MockInterface.init(42);
    const js_value = wrapInterface(MockInterface, &obj);

    try testing.expect(isInterfaceType(MockInterface, js_value));
    try testing.expect(!isInterfaceType(OtherInterface, js_value));
}

test "unwrapInterface - modify through pointer" {
    var obj = MockInterface.init(42);
    const js_value = wrapInterface(MockInterface, &obj);

    const unwrapped = try unwrapInterface(MockInterface, js_value);
    unwrapped.value = 100;

    try testing.expectEqual(@as(i32, 100), obj.value);
}
