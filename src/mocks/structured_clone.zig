//! Structured Clone Algorithm Mock
//!
//! Mock implementation of the HTML Structured Clone Algorithm.
//!
//! ## Specification
//!
//! - HTML Living Standard §2.7: https://html.spec.whatwg.org/multipage/structured-data.html
//! - Structured Clone Algorithm: https://html.spec.whatwg.org/multipage/structured-data.html#structuredserializeinternal
//!
//! ## Why This Mock Exists
//!
//! IndexedDB uses the Structured Clone Algorithm to serialize values for storage
//! and deserialize them on retrieval. This mock provides basic functionality
//! for primitive types while returning errors for complex types.
//!
//! ## Supported Types (Mock)
//!
//! - null, undefined
//! - Boolean
//! - Number (including Infinity, -Infinity, NaN)
//! - String
//! - Array (shallow - elements must be supported types)
//!
//! ## Unsupported Types (Returns Error)
//!
//! - Date
//! - RegExp
//! - Blob, File
//! - FileList
//! - ArrayBuffer, TypedArrays
//! - Map, Set
//! - Error objects
//! - DOM nodes
//! - Transferable objects
//!
//! ## TODO: Full Implementation Required
//!
//! A complete implementation requires:
//! - Full type support per spec
//! - Circular reference handling
//! - Transfer semantics
//! - Integration with JavaScript engine for object inspection
//!

const std = @import("std");
const root = @import("root.zig");
const MockError = root.MockError;

/// Serialized value representation
///
/// This is a simplified representation for the mock.
/// Full implementation would use a proper binary format.
pub const SerializedValue = struct {
    data: []const u8,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.data);
    }
};

/// JavaScript value type tags for serialization
pub const ValueType = enum(u8) {
    // Primitive types (supported by mock)
    Null = 0x00,
    Undefined = 0x01,
    BooleanTrue = 0x02,
    BooleanFalse = 0x03,
    NumberZero = 0x04,
    NumberPositiveInt = 0x05,
    NumberNegativeInt = 0x06,
    NumberDouble = 0x07,
    NumberNaN = 0x08,
    NumberPositiveInfinity = 0x09,
    NumberNegativeInfinity = 0x0A,
    String = 0x10,
    StringEmpty = 0x11,

    // Array (partially supported)
    ArrayEmpty = 0x20,
    ArrayWithLength = 0x21,

    // Object types (NOT supported by mock - returns error)
    Object = 0x30,
    Date = 0x31,
    RegExp = 0x32,
    Map = 0x33,
    Set = 0x34,
    ArrayBuffer = 0x40,
    TypedArray = 0x41,
    DataView = 0x42,
    Blob = 0x50,
    File = 0x51,
    FileList = 0x52,
    Error = 0x60,
    DOMException = 0x61,

    // Special
    ObjectReference = 0xFE, // For circular references
    Unsupported = 0xFF,
};

/// Structured Clone Options
pub const StructuredCloneOptions = struct {
    /// Objects to transfer (ownership moves to clone)
    transfer: ?[]const *anyopaque = null,
};

/// Serialize a value using the Structured Clone Algorithm (Mock)
///
/// This mock implementation handles primitive types only.
///
/// ## Arguments
/// - `allocator`: Allocator for the serialized data
/// - `value`: The value to serialize (as a tagged union or raw bytes)
///
/// ## Returns
/// - `SerializedValue` on success
/// - `MockError.UnsupportedType` for complex types
/// - `MockError.NotImplemented` for types requiring full implementation
///
/// TODO(Structured Clone): Full implementation per HTML spec
/// https://html.spec.whatwg.org/multipage/structured-data.html#structuredserializeinternal
pub fn serialize(allocator: std.mem.Allocator, value: Value) !SerializedValue {
    var buffer: std.ArrayListUnmanaged(u8) = .{};
    errdefer buffer.deinit(allocator);

    try serializeInternal(allocator, &buffer, value);

    return SerializedValue{
        .data = try buffer.toOwnedSlice(allocator),
        .allocator = allocator,
    };
}

/// Internal serialization
fn serializeInternal(allocator: std.mem.Allocator, buffer: *std.ArrayListUnmanaged(u8), value: Value) !void {
    switch (value) {
        .Null => try buffer.append(allocator, @intFromEnum(ValueType.Null)),
        .Undefined => try buffer.append(allocator, @intFromEnum(ValueType.Undefined)),
        .Boolean => |b| {
            if (b) {
                try buffer.append(allocator, @intFromEnum(ValueType.BooleanTrue));
            } else {
                try buffer.append(allocator, @intFromEnum(ValueType.BooleanFalse));
            }
        },
        .Integer => |i| {
            if (i == 0) {
                try buffer.append(allocator, @intFromEnum(ValueType.NumberZero));
            } else if (i > 0) {
                try buffer.append(allocator, @intFromEnum(ValueType.NumberPositiveInt));
                try buffer.appendSlice(allocator, std.mem.asBytes(&i));
            } else {
                try buffer.append(allocator, @intFromEnum(ValueType.NumberNegativeInt));
                try buffer.appendSlice(allocator, std.mem.asBytes(&i));
            }
        },
        .Float => |f| {
            if (std.math.isNan(f)) {
                try buffer.append(allocator, @intFromEnum(ValueType.NumberNaN));
            } else if (std.math.isPositiveInf(f)) {
                try buffer.append(allocator, @intFromEnum(ValueType.NumberPositiveInfinity));
            } else if (std.math.isNegativeInf(f)) {
                try buffer.append(allocator, @intFromEnum(ValueType.NumberNegativeInfinity));
            } else {
                try buffer.append(allocator, @intFromEnum(ValueType.NumberDouble));
                try buffer.appendSlice(allocator, std.mem.asBytes(&f));
            }
        },
        .String => |s| {
            if (s.len == 0) {
                try buffer.append(allocator, @intFromEnum(ValueType.StringEmpty));
            } else {
                try buffer.append(allocator, @intFromEnum(ValueType.String));
                const len: u32 = @intCast(s.len);
                try buffer.appendSlice(allocator, std.mem.asBytes(&len));
                try buffer.appendSlice(allocator, s);
            }
        },
        .Array => |arr| {
            if (arr.len == 0) {
                try buffer.append(allocator, @intFromEnum(ValueType.ArrayEmpty));
            } else {
                try buffer.append(allocator, @intFromEnum(ValueType.ArrayWithLength));
                const len: u32 = @intCast(arr.len);
                try buffer.appendSlice(allocator, std.mem.asBytes(&len));
                for (arr) |elem| {
                    try serializeInternal(allocator, buffer, elem);
                }
            }
        },
        // Complex types not supported by mock
        .Object, .Date, .RegExp, .Map, .Set, .ArrayBuffer, .Blob, .Error => {
            return MockError.UnsupportedType;
        },
    }
}

/// Deserialize a value using the Structured Clone Algorithm (Mock)
///
/// TODO(Structured Clone): Full implementation
pub fn deserialize(allocator: std.mem.Allocator, serialized: SerializedValue) !Value {
    var stream = std.io.fixedBufferStream(serialized.data);
    return deserializeInternal(allocator, stream.reader());
}

/// Internal deserialization
fn deserializeInternal(allocator: std.mem.Allocator, reader: anytype) !Value {
    const type_tag = try reader.readByte();
    const value_type: ValueType = @enumFromInt(type_tag);

    switch (value_type) {
        .Null => return Value{ .Null = {} },
        .Undefined => return Value{ .Undefined = {} },
        .BooleanTrue => return Value{ .Boolean = true },
        .BooleanFalse => return Value{ .Boolean = false },
        .NumberZero => return Value{ .Integer = 0 },
        .NumberPositiveInt, .NumberNegativeInt => {
            const i = try reader.readInt(i64, .little);
            return Value{ .Integer = i };
        },
        .NumberDouble => {
            var bytes: [8]u8 = undefined;
            _ = try reader.readAll(&bytes);
            return Value{ .Float = @bitCast(bytes) };
        },
        .NumberNaN => return Value{ .Float = std.math.nan(f64) },
        .NumberPositiveInfinity => return Value{ .Float = std.math.inf(f64) },
        .NumberNegativeInfinity => return Value{ .Float = -std.math.inf(f64) },
        .StringEmpty => return Value{ .String = "" },
        .String => {
            const len = try reader.readInt(u32, .little);
            const str = try allocator.alloc(u8, len);
            _ = try reader.readAll(str);
            return Value{ .String = str };
        },
        .ArrayEmpty => return Value{ .Array = &[_]Value{} },
        .ArrayWithLength => {
            const len = try reader.readInt(u32, .little);
            const arr = try allocator.alloc(Value, len);
            for (arr) |*elem| {
                elem.* = try deserializeInternal(allocator, reader);
            }
            return Value{ .Array = arr };
        },
        else => return MockError.UnsupportedType,
    }
}

/// Structured Clone (convenience function)
///
/// Clone a value using serialize + deserialize.
///
/// TODO(Structured Clone): Optimize to avoid full serialization for in-memory clone
pub fn clone(allocator: std.mem.Allocator, value: Value) !Value {
    var serialized = try serialize(allocator, value);
    defer serialized.deinit();
    return deserialize(allocator, serialized);
}

/// Value union for testing
///
/// This represents JavaScript values in Zig for testing purposes.
/// Full implementation would integrate with the JS engine.
pub const Value = union(enum) {
    Null,
    Undefined,
    Boolean: bool,
    Integer: i64,
    Float: f64,
    String: []const u8,
    Array: []const Value,
    // Unsupported types (included for error handling)
    Object,
    Date,
    RegExp,
    Map,
    Set,
    ArrayBuffer,
    Blob,
    Error,
};

// ============================================================================
// Tests
// ============================================================================

test "serialize and deserialize null" {
    const allocator = std.testing.allocator;

    var serialized = try serialize(allocator, Value{ .Null = {} });
    defer serialized.deinit();

    const deserialized = try deserialize(allocator, serialized);
    try std.testing.expect(deserialized == .Null);
}

test "serialize and deserialize boolean" {
    const allocator = std.testing.allocator;

    // True
    var ser_true = try serialize(allocator, Value{ .Boolean = true });
    defer ser_true.deinit();
    const des_true = try deserialize(allocator, ser_true);
    try std.testing.expectEqual(true, des_true.Boolean);

    // False
    var ser_false = try serialize(allocator, Value{ .Boolean = false });
    defer ser_false.deinit();
    const des_false = try deserialize(allocator, ser_false);
    try std.testing.expectEqual(false, des_false.Boolean);
}

test "serialize and deserialize integer" {
    const allocator = std.testing.allocator;

    var serialized = try serialize(allocator, Value{ .Integer = 42 });
    defer serialized.deinit();

    const deserialized = try deserialize(allocator, serialized);
    try std.testing.expectEqual(@as(i64, 42), deserialized.Integer);
}

test "serialize and deserialize negative integer" {
    const allocator = std.testing.allocator;

    var serialized = try serialize(allocator, Value{ .Integer = -123 });
    defer serialized.deinit();

    const deserialized = try deserialize(allocator, serialized);
    try std.testing.expectEqual(@as(i64, -123), deserialized.Integer);
}

test "serialize and deserialize float" {
    const allocator = std.testing.allocator;

    var serialized = try serialize(allocator, Value{ .Float = 3.14159 });
    defer serialized.deinit();

    const deserialized = try deserialize(allocator, serialized);
    try std.testing.expectApproxEqAbs(@as(f64, 3.14159), deserialized.Float, 0.00001);
}

test "serialize and deserialize special floats" {
    const allocator = std.testing.allocator;

    // NaN
    var ser_nan = try serialize(allocator, Value{ .Float = std.math.nan(f64) });
    defer ser_nan.deinit();
    const des_nan = try deserialize(allocator, ser_nan);
    try std.testing.expect(std.math.isNan(des_nan.Float));

    // Positive infinity
    var ser_pinf = try serialize(allocator, Value{ .Float = std.math.inf(f64) });
    defer ser_pinf.deinit();
    const des_pinf = try deserialize(allocator, ser_pinf);
    try std.testing.expect(std.math.isPositiveInf(des_pinf.Float));

    // Negative infinity
    var ser_ninf = try serialize(allocator, Value{ .Float = -std.math.inf(f64) });
    defer ser_ninf.deinit();
    const des_ninf = try deserialize(allocator, ser_ninf);
    try std.testing.expect(std.math.isNegativeInf(des_ninf.Float));
}

test "serialize and deserialize string" {
    const allocator = std.testing.allocator;

    var serialized = try serialize(allocator, Value{ .String = "hello world" });
    defer serialized.deinit();

    const deserialized = try deserialize(allocator, serialized);
    defer allocator.free(deserialized.String);
    try std.testing.expectEqualStrings("hello world", deserialized.String);
}

test "serialize and deserialize empty string" {
    const allocator = std.testing.allocator;

    var serialized = try serialize(allocator, Value{ .String = "" });
    defer serialized.deinit();

    const deserialized = try deserialize(allocator, serialized);
    try std.testing.expectEqualStrings("", deserialized.String);
}

test "unsupported types return error" {
    const allocator = std.testing.allocator;

    try std.testing.expectError(MockError.UnsupportedType, serialize(allocator, Value{ .Object = {} }));
    try std.testing.expectError(MockError.UnsupportedType, serialize(allocator, Value{ .Date = {} }));
    try std.testing.expectError(MockError.UnsupportedType, serialize(allocator, Value{ .ArrayBuffer = {} }));
}

test "clone value" {
    const allocator = std.testing.allocator;

    const original = Value{ .Integer = 999 };
    const cloned = try clone(allocator, original);
    try std.testing.expectEqual(@as(i64, 999), cloned.Integer);
}
