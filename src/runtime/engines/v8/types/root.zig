//! V8 Type Conversion for WebIDL
//!
//! Bidirectional conversion between WebIDL types and V8 values:
//! - WebIDL primitives ↔ V8 primitives
//! - DOMString, USVString ↔ V8 String
//! - sequence<T> ↔ V8 Array
//! - record<K,V> ↔ V8 Object
//! - Union types ↔ V8 tagged unions
//!
//! Based on patterns from zig-js-runtime (Lightpanda headless browser).
//!
//! ## Type Mapping
//!
//! | WebIDL Type | V8 Type |
//! |-------------|---------|
//! | boolean | v8::Boolean |
//! | byte, octet | v8::Int32 |
//! | short, unsigned short | v8::Int32 |
//! | long, unsigned long | v8::Int32 |
//! | long long | v8::BigInt |
//! | float, unrestricted float | v8::Number |
//! | double, unrestricted double | v8::Number |
//! | DOMString, USVString, ByteString | v8::String |
//! | object | v8::Object |
//! | sequence<T> | v8::Array |
//! | record<K,V> | v8::Object |
//! | T? (nullable) | v8::Value (can be null) |
//!
//! ## Usage
//!
//! ```zig
//! const v8_types = @import("runtime").v8_types;
//!
//! // Zig → V8
//! const v8_bool = try v8_types.toV8(allocator, true);
//! const v8_str = try v8_types.toV8(allocator, "Hello");
//! const v8_num = try v8_types.toV8(allocator, 42);
//!
//! // V8 → Zig
//! const zig_bool = try v8_types.fromV8(bool, v8_bool);
//! const zig_str = try v8_types.fromV8([]const u8, v8_str);
//! const zig_num = try v8_types.fromV8(i32, v8_num);
//! ```

const std = @import("std");
const DOMString = @import("../../../types.zig").DOMString;
const USVString = @import("../../../types.zig").USVString;
const ByteString = @import("../../../types.zig").ByteString;
const ffi = @import("../ffi.zig");

/// Mock V8 Array for testing
pub const MockV8Array = struct {
    items: std.ArrayList(V8Value),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) MockV8Array {
        return .{
            .items = std.ArrayList(V8Value){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MockV8Array) void {
        // Note: We don't free strings here because they might be string literals
        // In real V8, string handles would be managed by V8's GC
        // Caller is responsible for string lifetime management
        self.items.deinit(self.allocator);
    }

    pub fn append(self: *MockV8Array, value: V8Value) !void {
        try self.items.append(self.allocator, value);
    }

    pub fn length(self: *const MockV8Array) u32 {
        return @intCast(self.items.items.len);
    }

    pub fn get(self: *const MockV8Array, index: u32) ?V8Value {
        if (index >= self.items.items.len) return null;
        return self.items.items[index];
    }
};

/// V8 Value handle
///
/// When `use_real_v8 = true`: wraps v8::Local<v8::Value> (opaque pointer)
/// When `use_real_v8 = false`: mock union for testing
pub const V8Value = if (ffi.use_real_v8)
    struct {
        handle: *ffi.v8_Value,

        pub fn isUndefined(self: V8Value) bool {
            return ffi.v8_Value_IsUndefined(self.handle);
        }

        pub fn isNull(self: V8Value) bool {
            return ffi.v8_Value_IsNull(self.handle);
        }

        pub fn isNullish(self: V8Value) bool {
            return self.isNull() or self.isUndefined();
        }

        pub fn isBoolean(self: V8Value) bool {
            return ffi.v8_Value_IsBoolean(self.handle);
        }

        pub fn isNumber(self: V8Value) bool {
            return ffi.v8_Value_IsNumber(self.handle);
        }

        pub fn isString(self: V8Value) bool {
            return ffi.v8_Value_IsString(self.handle);
        }

        pub fn isObject(self: V8Value) bool {
            return ffi.v8_Value_IsObject(self.handle);
        }

        pub fn isArray(self: V8Value) bool {
            return ffi.v8_Value_IsArray(self.handle);
        }
    }
else
    union(enum) {
        undefined: void,
        null_value: void,
        boolean: bool,
        int32: i32,
        uint32: u32,
        int64: i64,
        uint64: u64,
        float: f32,
        double: f64,
        string: []const u8,
        object: usize, // Mock object handle
        array: *MockV8Array, // Mock array (changed to pointer)
        bigint: i64,

        /// Check if value is undefined
        pub fn isUndefined(self: V8Value) bool {
            return self == .undefined;
        }

        /// Check if value is null
        pub fn isNull(self: V8Value) bool {
            return self == .null_value;
        }

        /// Check if value is nullish (null or undefined)
        pub fn isNullish(self: V8Value) bool {
            return self.isNull() or self.isUndefined();
        }

        /// Check if value is boolean
        pub fn isBoolean(self: V8Value) bool {
            return self == .boolean;
        }

        /// Check if value is number
        pub fn isNumber(self: V8Value) bool {
            return switch (self) {
                .int32, .uint32, .int64, .uint64, .float, .double => true,
                else => false,
            };
        }

        /// Check if value is string
        pub fn isString(self: V8Value) bool {
            return self == .string;
        }

        /// Check if value is object
        pub fn isObject(self: V8Value) bool {
            return self == .object;
        }

        /// Check if value is array
        pub fn isArray(self: V8Value) bool {
            return self == .array;
        }
    };

/// Convert Zig value to V8 value
///
/// In real V8 integration:
/// ```c++
/// v8::Local<v8::Value> toV8(v8::Isolate* isolate, T value) {
///     if constexpr (std::is_same_v<T, bool>) {
///         return v8::Boolean::New(isolate, value);
///     } else if constexpr (std::is_integral_v<T>) {
///         return v8::Int32::New(isolate, value);
///     } else if constexpr (std::is_floating_point_v<T>) {
///         return v8::Number::New(isolate, value);
///     } else if constexpr (std::is_convertible_v<T, std::string>) {
///         return v8::String::NewFromUtf8(isolate, value);
///     }
/// }
/// ```
pub fn toV8(allocator: std.mem.Allocator, value: anytype) !V8Value {
    const T = @TypeOf(value);
    const type_info = @typeInfo(T);

    // Handle optionals
    if (type_info == .optional) {
        if (value) |v| {
            return toV8(allocator, v);
        } else {
            return .null_value;
        }
    }

    // Handle specific types
    switch (type_info) {
        .bool => return .{ .boolean = value },
        .int => |int_info| {
            if (int_info.signedness == .signed) {
                if (int_info.bits <= 32) {
                    return .{ .int32 = @intCast(value) };
                } else {
                    return .{ .int64 = @intCast(value) };
                }
            } else {
                if (int_info.bits <= 32) {
                    return .{ .uint32 = @intCast(value) };
                } else {
                    return .{ .uint64 = @intCast(value) };
                }
            }
        },
        .comptime_int => {
            if (value < 0) {
                return .{ .int32 = @intCast(value) };
            } else {
                return .{ .uint32 = @intCast(value) };
            }
        },
        .float => |float_info| {
            if (float_info.bits <= 32) {
                return .{ .float = @floatCast(value) };
            } else {
                return .{ .double = @floatCast(value) };
            }
        },
        .comptime_float => {
            return .{ .double = @floatCast(value) };
        },
        .pointer => |ptr_info| {
            // Handle slices ([]const u8, []u8)
            if (ptr_info.size == .slice and ptr_info.child == u8) {
                return .{ .string = value };
            }
            // Handle string literals (*const [N:0]u8)
            if (ptr_info.size == .one) {
                const child_info = @typeInfo(ptr_info.child);
                if (child_info == .array and child_info.array.child == u8) {
                    // String literal - convert to slice
                    return .{ .string = value };
                }
            }
            return error.UnsupportedType;
        },
        .@"struct" => {
            // Handle DOMString, USVString, etc.
            if (T == DOMString) {
                const str = value.toString(allocator) catch return error.StringConversion;
                return .{ .string = str };
            }
            if (T == USVString) {
                const str = value.toString(allocator) catch return error.StringConversion;
                return .{ .string = str };
            }
            if (T == ByteString) {
                const str = value.toString(allocator) catch return error.StringConversion;
                return .{ .string = str };
            }
            return error.UnsupportedType;
        },
        else => return error.UnsupportedType,
    }
}

/// Convert V8 value to Zig value
///
/// In real V8 integration:
/// ```c++
/// T fromV8(v8::Local<v8::Value> value) {
///     if (value->IsBoolean()) {
///         return value->BooleanValue();
///     } else if (value->IsInt32()) {
///         return value->Int32Value();
///     } else if (value->IsNumber()) {
///         return value->NumberValue();
///     } else if (value->IsString()) {
///         v8::String::Utf8Value str(value);
///         return std::string(*str, str.length());
///     }
/// }
/// ```
pub fn fromV8(comptime T: type, allocator: std.mem.Allocator, v8_value: V8Value) !T {
    const type_info = @typeInfo(T);

    // Handle optionals
    if (type_info == .optional) {
        if (v8_value.isNullish()) {
            return null;
        }
        const child_type = type_info.optional.child;
        return try fromV8(child_type, allocator, v8_value);
    }

    // Handle specific types
    switch (type_info) {
        .bool => {
            if (!v8_value.isBoolean()) return error.TypeMismatch;
            return v8_value.boolean;
        },
        .int => {
            if (!v8_value.isNumber()) return error.TypeMismatch;
            return switch (v8_value) {
                .int32 => |v| @intCast(v),
                .uint32 => |v| @intCast(v),
                .int64 => |v| @intCast(v),
                .uint64 => |v| @intCast(v),
                .float => |v| @intFromFloat(v),
                .double => |v| @intFromFloat(v),
                else => error.TypeMismatch,
            };
        },
        .float => {
            if (!v8_value.isNumber()) return error.TypeMismatch;
            return switch (v8_value) {
                .int32 => |v| @floatFromInt(v),
                .uint32 => |v| @floatFromInt(v),
                .int64 => |v| @floatFromInt(v),
                .uint64 => |v| @floatFromInt(v),
                .float => |v| @floatCast(v),
                .double => |v| @floatCast(v),
                else => error.TypeMismatch,
            };
        },
        .pointer => |ptr_info| {
            if (ptr_info.size == .slice and ptr_info.child == u8) {
                // []const u8 or []u8
                if (!v8_value.isString()) return error.TypeMismatch;
                // In real V8, would allocate and copy string
                return try allocator.dupe(u8, v8_value.string);
            }
            return error.UnsupportedType;
        },
        .@"struct" => {
            // Handle DOMString, USVString, etc.
            if (T == DOMString) {
                if (!v8_value.isString()) return error.TypeMismatch;
                return DOMString.fromUtf8(allocator, v8_value.string);
            }
            if (T == USVString) {
                if (!v8_value.isString()) return error.TypeMismatch;
                return USVString.fromUtf8(allocator, v8_value.string);
            }
            if (T == ByteString) {
                if (!v8_value.isString()) return error.TypeMismatch;
                return ByteString.fromUtf8(allocator, v8_value.string);
            }
            return error.UnsupportedType;
        },
        else => return error.UnsupportedType,
    }
}

/// Convert sequence<T> to V8 Array
///
/// In real V8:
/// ```c++
/// v8::Local<v8::Array> toV8Array(v8::Isolate* isolate, const std::vector<T>& vec) {
///     auto arr = v8::Array::New(isolate, vec.size());
///     for (size_t i = 0; i < vec.size(); i++) {
///         arr->Set(i, toV8(isolate, vec[i]));
///     }
///     return arr;
/// }
/// ```
pub fn sequenceToV8(allocator: std.mem.Allocator, comptime T: type, sequence: []const T) !V8Value {
    var arr = try allocator.create(MockV8Array);
    errdefer allocator.destroy(arr);

    arr.* = MockV8Array.init(allocator);
    errdefer arr.deinit();

    // Convert each element to V8Value
    for (sequence) |item| {
        const v8_item = try toV8(allocator, item);
        try arr.append(v8_item);
    }

    return .{ .array = arr };
}

/// Convert V8 Array to sequence<T>
///
/// In real V8:
/// ```c++
/// std::vector<T> fromV8Array(v8::Local<v8::Array> arr) {
///     std::vector<T> result;
///     for (uint32_t i = 0; i < arr->Length(); i++) {
///         result.push_back(fromV8<T>(arr->Get(i)));
///     }
///     return result;
/// }
/// ```
pub fn sequenceFromV8(comptime T: type, allocator: std.mem.Allocator, v8_array: V8Value) ![]T {
    if (!v8_array.isArray()) return error.TypeMismatch;

    const arr = v8_array.array;
    const len = arr.length();

    var result = try allocator.alloc(T, len);
    errdefer allocator.free(result);

    for (0..len) |i| {
        const v8_item = arr.get(@intCast(i)) orelse return error.ArrayIndexOutOfBounds;
        result[i] = try fromV8(T, allocator, v8_item);
    }

    return result;
}

/// Convert record<K,V> to V8 Object
///
/// In real V8:
/// ```c++
/// v8::Local<v8::Object> toV8Record(v8::Isolate* isolate, const std::map<K,V>& map) {
///     auto obj = v8::Object::New(isolate);
///     for (const auto& [key, value] : map) {
///         obj->Set(toV8(isolate, key), toV8(isolate, value));
///     }
///     return obj;
/// }
/// ```
pub fn recordToV8(allocator: std.mem.Allocator, comptime K: type, comptime V: type, map: std.AutoHashMap(K, V)) !V8Value {
    _ = allocator;
    _ = map;
    // Mock: return object handle
    return .{ .object = 0x2000 };
}

/// Union type conversion helper
///
/// WebIDL union types like (DOMString or long) are represented as Zig tagged unions.
/// This function converts Zig union values to V8 by dispatching on the active tag.
///
/// In real V8:
/// ```c++
/// v8::Local<v8::Value> toV8Union(v8::Isolate* isolate, const Union& u) {
///     switch (u.type) {
///         case Union::STRING: return v8::String::NewFromUtf8(isolate, u.string_value);
///         case Union::LONG: return v8::Int32::New(isolate, u.long_value);
///     }
/// }
/// ```
///
/// Example:
/// ```zig
/// const StringOrLong = union(enum) {
///     string: []const u8,
///     long: i32,
/// };
///
/// const value = StringOrLong{ .long = 42 };
/// const v8_value = try unionToV8(allocator, value);
/// ```
pub fn unionToV8(allocator: std.mem.Allocator, value: anytype) !V8Value {
    const T = @TypeOf(value);
    const type_info = @typeInfo(T);

    if (type_info != .@"union") {
        @compileError("unionToV8 requires a union type");
    }

    const union_info = type_info.@"union";
    if (union_info.tag_type == null) {
        @compileError("unionToV8 requires a tagged union");
    }

    // Get active tag and field
    inline for (union_info.fields) |field| {
        if (std.mem.eql(u8, @tagName(value), field.name)) {
            const field_value = @field(value, field.name);
            return try toV8(allocator, field_value);
        }
    }

    unreachable;
}

/// Convert V8 value to WebIDL union type
///
/// Attempts to convert the V8 value to each union member type in order,
/// returning the first successful conversion.
///
/// In real V8:
/// ```c++
/// Union fromV8Union(v8::Local<v8::Value> value) {
///     if (value->IsString()) {
///         return Union::FromString(value->ToString());
///     } else if (value->IsInt32()) {
///         return Union::FromLong(value->Int32Value());
///     }
///     throw TypeError("Value does not match union types");
/// }
/// ```
///
/// Example:
/// ```zig
/// const StringOrLong = union(enum) {
///     string: []const u8,
///     long: i32,
/// };
///
/// const v8_int = V8Value{ .int32 = 42 };
/// const result = try unionFromV8(StringOrLong, allocator, v8_int);
/// // result == StringOrLong{ .long = 42 }
/// ```
pub fn unionFromV8(comptime T: type, allocator: std.mem.Allocator, v8_value: V8Value) !T {
    const type_info = @typeInfo(T);

    if (type_info != .@"union") {
        @compileError("unionFromV8 requires a union type");
    }

    const union_info = type_info.@"union";
    if (union_info.tag_type == null) {
        @compileError("unionFromV8 requires a tagged union");
    }

    // Try to convert to each union member type
    // Return first successful conversion
    var last_error: anyerror = error.NoMatchingUnionType;

    inline for (union_info.fields) |field| {
        const FieldType = field.type;

        // Attempt conversion to this field type
        if (fromV8(FieldType, allocator, v8_value)) |result| {
            // Success - construct union with this field
            return @unionInit(T, field.name, result);
        } else |err| {
            last_error = err;
        }
    }

    // No conversion succeeded
    return last_error;
}

// Unit tests

const testing = std.testing;

test "toV8 converts boolean" {
    const v8_true = try toV8(testing.allocator, true);
    try testing.expect(v8_true == .boolean);
    try testing.expectEqual(true, v8_true.boolean);

    const v8_false = try toV8(testing.allocator, false);
    try testing.expectEqual(false, v8_false.boolean);
}

test "toV8 converts integers" {
    const v8_i32 = try toV8(testing.allocator, @as(i32, -42));
    try testing.expect(v8_i32 == .int32);
    try testing.expectEqual(@as(i32, -42), v8_i32.int32);

    const v8_u32 = try toV8(testing.allocator, @as(u32, 42));
    try testing.expect(v8_u32 == .uint32);
    try testing.expectEqual(@as(u32, 42), v8_u32.uint32);
}

test "toV8 converts floats" {
    const v8_f32 = try toV8(testing.allocator, @as(f32, 3.14));
    try testing.expect(v8_f32 == .float);
    try testing.expectApproxEqAbs(@as(f32, 3.14), v8_f32.float, 0.001);

    const v8_f64 = try toV8(testing.allocator, @as(f64, 3.14159));
    try testing.expect(v8_f64 == .double);
    try testing.expectApproxEqAbs(@as(f64, 3.14159), v8_f64.double, 0.00001);
}

test "toV8 converts strings" {
    const v8_str = try toV8(testing.allocator, "hello");
    try testing.expect(v8_str == .string);
    try testing.expectEqualStrings("hello", v8_str.string);
}

test "toV8 converts null optionals" {
    const v8_null = try toV8(testing.allocator, @as(?i32, null));
    try testing.expect(v8_null.isNull());
}

test "toV8 converts non-null optionals" {
    const v8_value = try toV8(testing.allocator, @as(?i32, 42));
    try testing.expect(v8_value == .int32);
    try testing.expectEqual(@as(i32, 42), v8_value.int32);
}

test "fromV8 converts boolean" {
    const v8_true = V8Value{ .boolean = true };
    const zig_bool = try fromV8(bool, testing.allocator, v8_true);
    try testing.expectEqual(true, zig_bool);
}

test "fromV8 converts integers" {
    const v8_int = V8Value{ .int32 = -42 };
    const zig_int = try fromV8(i32, testing.allocator, v8_int);
    try testing.expectEqual(@as(i32, -42), zig_int);
}

test "fromV8 converts floats" {
    const v8_double = V8Value{ .double = 3.14 };
    const zig_float = try fromV8(f64, testing.allocator, v8_double);
    try testing.expectApproxEqAbs(@as(f64, 3.14), zig_float, 0.001);
}

test "fromV8 converts strings" {
    const v8_str = V8Value{ .string = "hello" };
    const zig_str = try fromV8([]const u8, testing.allocator, v8_str);
    defer testing.allocator.free(zig_str);

    try testing.expectEqualStrings("hello", zig_str);
}

test "fromV8 converts null to null optional" {
    const v8_null = V8Value{ .null_value = {} };
    const zig_opt = try fromV8(?i32, testing.allocator, v8_null);
    try testing.expectEqual(@as(?i32, null), zig_opt);
}

test "fromV8 converts value to non-null optional" {
    const v8_int = V8Value{ .int32 = 42 };
    const zig_opt = try fromV8(?i32, testing.allocator, v8_int);
    try testing.expectEqual(@as(?i32, 42), zig_opt);
}

test "fromV8 returns error on type mismatch" {
    const v8_str = V8Value{ .string = "not a number" };
    const result = fromV8(i32, testing.allocator, v8_str);
    try testing.expectError(error.TypeMismatch, result);
}

test "V8Value type checking methods" {
    const v8_bool = V8Value{ .boolean = true };
    try testing.expect(v8_bool.isBoolean());
    try testing.expect(!v8_bool.isNumber());

    const v8_int = V8Value{ .int32 = 42 };
    try testing.expect(v8_int.isNumber());
    try testing.expect(!v8_int.isString());

    const v8_str = V8Value{ .string = "hello" };
    try testing.expect(v8_str.isString());
    try testing.expect(!v8_str.isBoolean());

    const v8_null = V8Value{ .null_value = {} };
    try testing.expect(v8_null.isNull());
    try testing.expect(v8_null.isNullish());

    const v8_undefined = V8Value{ .undefined = {} };
    try testing.expect(v8_undefined.isUndefined());
    try testing.expect(v8_undefined.isNullish());
}

test "sequenceToV8 converts empty array" {
    const empty: []const i32 = &[_]i32{};
    const v8_arr = try sequenceToV8(testing.allocator, i32, empty);
    defer {
        v8_arr.array.deinit();
        testing.allocator.destroy(v8_arr.array);
    }

    try testing.expect(v8_arr.isArray());
    try testing.expectEqual(@as(u32, 0), v8_arr.array.length());
}

test "sequenceToV8 converts integer array" {
    const nums = [_]i32{ 1, 2, 3, 4, 5 };
    const v8_arr = try sequenceToV8(testing.allocator, i32, &nums);
    defer {
        v8_arr.array.deinit();
        testing.allocator.destroy(v8_arr.array);
    }

    try testing.expect(v8_arr.isArray());
    try testing.expectEqual(@as(u32, 5), v8_arr.array.length());

    // Check each element
    for (0..5) |i| {
        const item = v8_arr.array.get(@intCast(i)).?;
        try testing.expectEqual(nums[i], item.int32);
    }
}

test "sequenceToV8 converts string array" {
    const strs = [_][]const u8{ "hello", "world", "test" };
    const v8_arr = try sequenceToV8(testing.allocator, []const u8, &strs);
    defer {
        v8_arr.array.deinit();
        testing.allocator.destroy(v8_arr.array);
    }

    try testing.expect(v8_arr.isArray());
    try testing.expectEqual(@as(u32, 3), v8_arr.array.length());

    try testing.expectEqualStrings("hello", v8_arr.array.get(0).?.string);
    try testing.expectEqualStrings("world", v8_arr.array.get(1).?.string);
    try testing.expectEqualStrings("test", v8_arr.array.get(2).?.string);
}

test "sequenceToV8 converts boolean array" {
    const bools = [_]bool{ true, false, true };
    const v8_arr = try sequenceToV8(testing.allocator, bool, &bools);
    defer {
        v8_arr.array.deinit();
        testing.allocator.destroy(v8_arr.array);
    }

    try testing.expectEqual(@as(u32, 3), v8_arr.array.length());
    try testing.expectEqual(true, v8_arr.array.get(0).?.boolean);
    try testing.expectEqual(false, v8_arr.array.get(1).?.boolean);
    try testing.expectEqual(true, v8_arr.array.get(2).?.boolean);
}

test "sequenceFromV8 converts empty array" {
    var arr = MockV8Array.init(testing.allocator);
    defer arr.deinit();

    const v8_arr = V8Value{ .array = &arr };
    const result = try sequenceFromV8(i32, testing.allocator, v8_arr);
    defer testing.allocator.free(result);

    try testing.expectEqual(@as(usize, 0), result.len);
}

test "sequenceFromV8 converts integer array" {
    var arr = MockV8Array.init(testing.allocator);
    defer arr.deinit();

    try arr.append(.{ .int32 = 10 });
    try arr.append(.{ .int32 = 20 });
    try arr.append(.{ .int32 = 30 });

    const v8_arr = V8Value{ .array = &arr };
    const result = try sequenceFromV8(i32, testing.allocator, v8_arr);
    defer testing.allocator.free(result);

    try testing.expectEqual(@as(usize, 3), result.len);
    try testing.expectEqual(@as(i32, 10), result[0]);
    try testing.expectEqual(@as(i32, 20), result[1]);
    try testing.expectEqual(@as(i32, 30), result[2]);
}

test "sequenceFromV8 converts string array" {
    var arr = MockV8Array.init(testing.allocator);
    defer arr.deinit();

    try arr.append(.{ .string = "foo" });
    try arr.append(.{ .string = "bar" });

    const v8_arr = V8Value{ .array = &arr };
    const result = try sequenceFromV8([]const u8, testing.allocator, v8_arr);
    defer {
        for (result) |str| testing.allocator.free(str);
        testing.allocator.free(result);
    }

    try testing.expectEqual(@as(usize, 2), result.len);
    try testing.expectEqualStrings("foo", result[0]);
    try testing.expectEqualStrings("bar", result[1]);
}

test "sequenceFromV8 converts boolean array" {
    var arr = MockV8Array.init(testing.allocator);
    defer arr.deinit();

    try arr.append(.{ .boolean = true });
    try arr.append(.{ .boolean = false });
    try arr.append(.{ .boolean = true });

    const v8_arr = V8Value{ .array = &arr };
    const result = try sequenceFromV8(bool, testing.allocator, v8_arr);
    defer testing.allocator.free(result);

    try testing.expectEqual(@as(usize, 3), result.len);
    try testing.expectEqual(true, result[0]);
    try testing.expectEqual(false, result[1]);
    try testing.expectEqual(true, result[2]);
}

test "sequenceFromV8 returns error on non-array" {
    const v8_int = V8Value{ .int32 = 42 };
    const result = sequenceFromV8(i32, testing.allocator, v8_int);
    try testing.expectError(error.TypeMismatch, result);
}

test "sequenceToV8 and sequenceFromV8 round-trip" {
    const original = [_]f64{ 1.5, 2.5, 3.5, 4.5 };

    // Zig -> V8
    const v8_arr = try sequenceToV8(testing.allocator, f64, &original);
    defer {
        v8_arr.array.deinit();
        testing.allocator.destroy(v8_arr.array);
    }

    // V8 -> Zig
    const result = try sequenceFromV8(f64, testing.allocator, v8_arr);
    defer testing.allocator.free(result);

    try testing.expectEqual(original.len, result.len);
    for (original, result) |expected, actual| {
        try testing.expectApproxEqAbs(expected, actual, 0.001);
    }
}

test "MockV8Array basic operations" {
    var arr = MockV8Array.init(testing.allocator);
    defer arr.deinit();

    try testing.expectEqual(@as(u32, 0), arr.length());

    try arr.append(.{ .int32 = 42 });
    try testing.expectEqual(@as(u32, 1), arr.length());
    try testing.expectEqual(@as(i32, 42), arr.get(0).?.int32);

    try arr.append(.{ .boolean = true });
    try testing.expectEqual(@as(u32, 2), arr.length());
    try testing.expectEqual(true, arr.get(1).?.boolean);

    // Out of bounds returns null
    try testing.expectEqual(@as(?V8Value, null), arr.get(100));
}

// Union type tests

const StringOrLong = union(enum) {
    string: []const u8,
    long: i32,
};

const BoolOrDouble = union(enum) {
    boolean: bool,
    number: f64,
};

test "unionToV8 converts string variant" {
    const value = StringOrLong{ .string = "hello" };
    const v8_value = try unionToV8(testing.allocator, value);

    try testing.expect(v8_value.isString());
    try testing.expectEqualStrings("hello", v8_value.string);
}

test "unionToV8 converts long variant" {
    const value = StringOrLong{ .long = 42 };
    const v8_value = try unionToV8(testing.allocator, value);

    try testing.expect(v8_value.isNumber());
    try testing.expectEqual(@as(i32, 42), v8_value.int32);
}

test "unionToV8 converts boolean variant" {
    const value = BoolOrDouble{ .boolean = true };
    const v8_value = try unionToV8(testing.allocator, value);

    try testing.expect(v8_value.isBoolean());
    try testing.expectEqual(true, v8_value.boolean);
}

test "unionToV8 converts double variant" {
    const value = BoolOrDouble{ .number = 3.14 };
    const v8_value = try unionToV8(testing.allocator, value);

    try testing.expect(v8_value.isNumber());
    try testing.expectApproxEqAbs(@as(f64, 3.14), v8_value.double, 0.001);
}

test "unionFromV8 converts to string variant" {
    const v8_str = V8Value{ .string = "test" };
    const result = try unionFromV8(StringOrLong, testing.allocator, v8_str);

    try testing.expect(result == .string);
    try testing.expectEqualStrings("test", result.string);

    testing.allocator.free(result.string);
}

test "unionFromV8 converts to long variant" {
    const v8_int = V8Value{ .int32 = 99 };
    const result = try unionFromV8(StringOrLong, testing.allocator, v8_int);

    try testing.expect(result == .long);
    try testing.expectEqual(@as(i32, 99), result.long);
}

test "unionFromV8 converts to boolean variant" {
    const v8_bool = V8Value{ .boolean = false };
    const result = try unionFromV8(BoolOrDouble, testing.allocator, v8_bool);

    try testing.expect(result == .boolean);
    try testing.expectEqual(false, result.boolean);
}

test "unionFromV8 converts to double variant" {
    const v8_num = V8Value{ .double = 2.71 };
    const result = try unionFromV8(BoolOrDouble, testing.allocator, v8_num);

    try testing.expect(result == .number);
    try testing.expectApproxEqAbs(@as(f64, 2.71), result.number, 0.001);
}

test "unionFromV8 prefers first matching type" {
    // When multiple types could match, should try in order
    const v8_int = V8Value{ .int32 = 42 };

    // BoolOrDouble has boolean first, but int32 can't convert to bool
    // So it should try number next
    const result = try unionFromV8(BoolOrDouble, testing.allocator, v8_int);

    try testing.expect(result == .number);
    try testing.expectEqual(@as(f64, 42.0), result.number);
}

test "unionToV8 and unionFromV8 round-trip string" {
    const original = StringOrLong{ .string = "round-trip" };

    // Zig union -> V8
    const v8_value = try unionToV8(testing.allocator, original);

    // V8 -> Zig union
    const result = try unionFromV8(StringOrLong, testing.allocator, v8_value);
    defer testing.allocator.free(result.string);

    try testing.expect(result == .string);
    try testing.expectEqualStrings("round-trip", result.string);
}

test "unionToV8 and unionFromV8 round-trip long" {
    const original = StringOrLong{ .long = 12345 };

    // Zig union -> V8
    const v8_value = try unionToV8(testing.allocator, original);

    // V8 -> Zig union
    const result = try unionFromV8(StringOrLong, testing.allocator, v8_value);

    try testing.expect(result == .long);
    try testing.expectEqual(@as(i32, 12345), result.long);
}
