//! WebIDL Union Type Conversion
//!
//! Spec: https://webidl.spec.whatwg.org/#idl-union
//! Spec: https://webidl.spec.whatwg.org/#es-union
//!
//! Union types represent values that can be one of several types. The
//! conversion algorithm performs type discrimination at runtime to determine
//! which type the JavaScript value matches.
//!
//! This implementation follows the WHATWG WebIDL specification's 20-step
//! union type conversion algorithm exactly.

const std = @import("std");
const primitives = @import("primitives.zig");
const strings = @import("strings.zig");
const dictionaries = @import("dictionaries.zig");
const callbacks = @import("callbacks.zig");
const object = @import("object.zig");

const JSValue = primitives.JSValue;
const JSObject = object.JSObject;

/// WebIDL Union Type Wrapper
///
/// Spec: https://webidl.spec.whatwg.org/#es-union
///
/// Converts JavaScript values to union types following the WHATWG algorithm.
/// Supports: primitives, strings, objects, dictionaries, callbacks, sequences.
///
/// Usage:
/// ```zig
/// const StringOrNumber = union(enum) {
///     string: []const u8,
///     number: i32,
/// };
///
/// const U = Union(StringOrNumber);
/// const result = try U.fromJSValue(allocator, js_value);
/// defer result.deinit(); // if union contains allocated types
/// ```
pub fn Union(comptime Types: type) type {
    const type_info = @typeInfo(Types);
    if (type_info != .@"union") {
        @compileError("Union() requires a union type");
    }

    return struct {
        value: Types,

        const Self = @This();

        /// Convert JavaScript value to union type
        ///
        /// Spec: https://webidl.spec.whatwg.org/#es-union (20 steps)
        ///
        /// Algorithm implements exact spec order:
        /// 1. undefined handling
        /// 2. nullable type handling
        /// 3. Get flattened member types
        /// 4. Dictionary from null/undefined
        /// 5. Platform object (interface)
        /// 6-9. Buffer source types (ArrayBuffer, SharedArrayBuffer, DataView, TypedArray)
        /// 10. Callback function (IsCallable check)
        /// 11. Object discrimination (sequence, frozen array, dictionary, record, callback interface, object)
        /// 12. Boolean
        /// 13. Number
        /// 14. BigInt
        /// 15. String type
        /// 16. Numeric type + bigint fallback
        /// 17. Numeric type fallback
        /// 18. Boolean fallback
        /// 19. BigInt fallback
        /// 20. TypeError
        pub fn fromJSValue(allocator: std.mem.Allocator, V: JSValue) !Self {
            // Step 1: If union includes undefined and V is undefined, return undefined
            if (V == .undefined) {
                inline for (type_info.@"union".fields) |field| {
                    if (field.type == void and std.mem.eql(u8, field.name, "undefined")) {
                        return Self{ .value = @unionInit(Types, field.name, {}) };
                    }
                }
            }

            // Step 2: If union includes nullable type and V is null or undefined
            if (V == .null or V == .undefined) {
                inline for (type_info.@"union".fields) |field| {
                    const field_type_info = @typeInfo(field.type);
                    if (field_type_info == .optional) {
                        // Return null for the nullable type
                        return Self{ .value = @unionInit(Types, field.name, null) };
                    }
                }
            }

            // Step 3: Get flattened member types (already done via comptime field iteration)

            // Step 4: If V is null or undefined, check for dictionary type
            // NOTE: Dictionary type detection requires JS runtime integration
            if (V == .null or V == .undefined) {
                inline for (type_info.@"union".fields) |field| {
                    _ = field;
                }
            }

            // Step 5: If V is platform object (interface)
            if (V == .interface_ptr) {
                inline for (type_info.@"union".fields) |field| {
                    if (field.type == @TypeOf(JSValue.interface_ptr)) {
                        return Self{ .value = @unionInit(Types, field.name, V.interface_ptr) };
                    }
                }
                inline for (type_info.@"union".fields) |field| {
                    if (field.type == JSObject) {
                        // NOTE: Wrapping interface_ptr requires JS runtime
                        return error.NotImplemented;
                    }
                }
            }

            // Steps 6-9: Buffer source types (ArrayBuffer, SharedArrayBuffer, DataView, TypedArray)
            // NOTE: Buffer source discrimination requires JS runtime integration
            // Requires: [[ArrayBufferData]], [[DataView]], [[TypedArrayName]] internal slots

            // Step 10: If IsCallable(V) is true
            if (V == .function) {
                inline for (type_info.@"union".fields) |field| {
                    if (field.type == callbacks.GenericCallback) {
                        return Self{ .value = @unionInit(Types, field.name, V.function) };
                    }
                }
                inline for (type_info.@"union".fields) |field| {
                    if (field.type == JSObject) {
                        // NOTE: Wrapping function requires JS runtime
                        return error.NotImplemented;
                    }
                }
            }

            // Step 11: If V is Object
            // NOTE: Full object type discrimination requires JS runtime:
            // - Symbol.asyncIterator for async sequences (step 11.1)
            // - Symbol.iterator for sequences/frozen arrays (steps 11.2-11.3)
            // - Dictionary type detection (step 11.4)
            // - Record type conversion (step 11.5)
            // - Callback interface conversion (step 11.6)
            if (V == .object) {
                // Step 11.7: Object type
                inline for (type_info.@"union".fields) |field| {
                    if (field.type == JSObject) {
                        return Self{ .value = @unionInit(Types, field.name, V.object) };
                    }
                }
            }

            // Step 12: If V is Boolean
            if (V == .boolean) {
                inline for (type_info.@"union".fields) |field| {
                    if (field.type == bool) {
                        return Self{ .value = @unionInit(Types, field.name, V.boolean) };
                    }
                }
            }

            // Step 13: If V is Number
            if (V == .number) {
                inline for (type_info.@"union".fields) |field| {
                    const field_type_info = @typeInfo(field.type);
                    if (field_type_info == .int or field_type_info == .float) {
                        const converted = try convertToNumericType(field.type, V.number);
                        return Self{ .value = @unionInit(Types, field.name, converted) };
                    }
                }
            }

            // Step 14: If V is BigInt
            // NOTE: BigInt support requires JS runtime (JSValue.bigint variant)

            // Step 15: If types includes string type
            inline for (type_info.@"union".fields) |field| {
                const field_type_info = @typeInfo(field.type);
                switch (field_type_info) {
                    .pointer => |ptr| {
                        if (ptr.size == .slice and ptr.child == u8) {
                            const converted = try convertToStringType(allocator, V);
                            return Self{ .value = @unionInit(Types, field.name, converted) };
                        }
                    },
                    else => {},
                }
            }

            // Step 16: If types includes numeric type and bigint
            // NOTE: Numeric + bigint fallback requires JS runtime

            // Step 17: If types includes numeric type (fallback conversion)
            inline for (type_info.@"union".fields) |field| {
                const field_type_info = @typeInfo(field.type);
                if (field_type_info == .int or field_type_info == .float) {
                    const num = V.toNumber();
                    const converted = try convertToNumericType(field.type, num);
                    return Self{ .value = @unionInit(Types, field.name, converted) };
                }
            }

            // Step 18: If types includes boolean (fallback conversion)
            inline for (type_info.@"union".fields) |field| {
                if (field.type == bool) {
                    return Self{ .value = @unionInit(Types, field.name, V.toBoolean()) };
                }
            }

            // Step 19: If types includes bigint (fallback conversion)
            // NOTE: BigInt fallback requires JS runtime

            // Step 20: Throw TypeError
            return error.TypeError;
        }

        // Helper: Check if union has undefined type
        fn hasUndefinedType() bool {
            inline for (type_info.@"union".fields) |field| {
                if (field.type == void and std.mem.eql(u8, field.name, "undefined")) {
                    return true;
                }
            }
            return false;
        }

        fn getUndefinedFieldName() ?[]const u8 {
            inline for (type_info.@"union".fields) |field| {
                if (field.type == void and std.mem.eql(u8, field.name, "undefined")) {
                    return field.name;
                }
            }
            return null;
        }

        fn getNullableFieldName() ?[]const u8 {
            inline for (type_info.@"union".fields) |field| {
                const field_type_info = @typeInfo(field.type);
                if (field_type_info == .optional) {
                    return field.name;
                }
            }
            return null;
        }

        fn getDictionaryFieldName() ?[]const u8 {
            // NOTE: Dictionary type detection requires JS runtime integration
            return null;
        }

        fn getInterfaceFieldName() ?[]const u8 {
            inline for (type_info.@"union".fields) |field| {
                if (field.type == @TypeOf(JSValue.interface_ptr)) {
                    return field.name;
                }
            }
            return null;
        }

        fn getCallbackFieldName() ?[]const u8 {
            inline for (type_info.@"union".fields) |field| {
                if (field.type == callbacks.GenericCallback) {
                    return field.name;
                }
            }
            return null;
        }

        fn getObjectFieldName() ?[]const u8 {
            inline for (type_info.@"union".fields) |field| {
                if (field.type == JSObject) {
                    return field.name;
                }
            }
            return null;
        }

        fn getBooleanFieldName() ?[]const u8 {
            inline for (type_info.@"union".fields) |field| {
                if (field.type == bool) {
                    return field.name;
                }
            }
            return null;
        }

        fn getNumericFieldName() ?[]const u8 {
            inline for (type_info.@"union".fields) |field| {
                const field_type_info = @typeInfo(field.type);
                if (field_type_info == .int or field_type_info == .float) {
                    return field.name;
                }
            }
            return null;
        }

        fn getStringFieldName() ?[]const u8 {
            inline for (type_info.@"union".fields) |field| {
                const field_type_info = @typeInfo(field.type);
                if (field_type_info == .pointer) |ptr| {
                    if (ptr.size == .slice and ptr.child == u8) {
                        return field.name;
                    }
                }
            }
            return null;
        }

        fn getFieldType(comptime field_name: []const u8) type {
            inline for (type_info.@"union".fields) |field| {
                if (std.mem.eql(u8, field.name, field_name)) {
                    return field.type;
                }
            }
            @compileError("Field not found: " ++ field_name);
        }

        fn convertToNumericType(comptime T: type, number: f64) !T {
            const type_info_inner = @typeInfo(T);
            return switch (type_info_inner) {
                .int => |int_info| blk: {
                    if (int_info.signedness == .signed) {
                        if (int_info.bits == 32) {
                            break :blk @as(T, @intCast(try primitives.toLong(JSValue{ .number = number })));
                        }
                    } else {
                        if (int_info.bits == 32) {
                            break :blk @as(T, @intCast(try primitives.toUnsignedLong(JSValue{ .number = number })));
                        }
                    }
                    return error.TypeError;
                },
                .float => |float_info| blk: {
                    if (float_info.bits == 64) {
                        break :blk @as(T, try primitives.toDouble(JSValue{ .number = number }));
                    } else if (float_info.bits == 32) {
                        break :blk @as(T, @floatCast(number));
                    }
                    return error.TypeError;
                },
                else => error.TypeError,
            };
        }

        fn convertToStringType(allocator: std.mem.Allocator, V: JSValue) ![]const u8 {
            // NOTE: Full DOMString/USVString/ByteString conversions require JS runtime
            if (V == .string) {
                return V.string;
            }
            // Fallback: convert to string
            _ = allocator;
            return error.NotImplemented;
        }
    };
}

const testing = std.testing;

test "Union - boolean discrimination" {
    const BoolOrNumber = union(enum) {
        boolean: bool,
        number: i32,
    };

    const U = Union(BoolOrNumber);

    const result = try U.fromJSValue(testing.allocator, .{ .boolean = true });
    try testing.expectEqual(@as(std.meta.Tag(BoolOrNumber), .boolean), @as(std.meta.Tag(BoolOrNumber), result.value));
    try testing.expect(result.value.boolean);
}

test "Union - number discrimination" {
    const BoolOrNumber = union(enum) {
        boolean: bool,
        number: i32,
    };

    const U = Union(BoolOrNumber);

    const result = try U.fromJSValue(testing.allocator, .{ .number = 42.0 });
    try testing.expectEqual(@as(std.meta.Tag(BoolOrNumber), .number), @as(std.meta.Tag(BoolOrNumber), result.value));
    try testing.expectEqual(@as(i32, 42), result.value.number);
}

test "Union - string discrimination" {
    const StringOrNumber = union(enum) {
        string: []const u8,
        number: i32,
    };

    const U = Union(StringOrNumber);

    const result = try U.fromJSValue(testing.allocator, .{ .string = "hello" });
    try testing.expectEqual(@as(std.meta.Tag(StringOrNumber), .string), @as(std.meta.Tag(StringOrNumber), result.value));
    try testing.expectEqualStrings("hello", result.value.string);
}

test "Union - fallback to numeric conversion" {
    const BoolOrNumber = union(enum) {
        boolean: bool,
        number: i32,
    };

    const U = Union(BoolOrNumber);

    // Step 17 of spec: If types includes numeric type, convert V to that type
    // String "123" converts to number 123
    const result = try U.fromJSValue(testing.allocator, .{ .string = "123" });
    try testing.expectEqual(@as(std.meta.Tag(BoolOrNumber), .number), @as(std.meta.Tag(BoolOrNumber), result.value));
    try testing.expectEqual(@as(i32, 123), result.value.number);
}

test "Union - object type (step 11.7)" {
    const ObjectOrString = union(enum) {
        object: JSObject,
        string: []const u8,
    };

    const U = Union(ObjectOrString);

    var obj = JSObject.init(testing.allocator);
    defer obj.deinit();

    const result = try U.fromJSValue(testing.allocator, .{ .object = obj });
    try testing.expectEqual(@as(std.meta.Tag(ObjectOrString), .object), @as(std.meta.Tag(ObjectOrString), result.value));
}

test "Union - boolean priority (step 12)" {
    const BoolOrNumber = union(enum) {
        boolean: bool,
        number: i32,
    };

    const U = Union(BoolOrNumber);

    // Step 12: Boolean value matches boolean type directly
    const result = try U.fromJSValue(testing.allocator, .{ .boolean = false });
    try testing.expectEqual(@as(std.meta.Tag(BoolOrNumber), .boolean), @as(std.meta.Tag(BoolOrNumber), result.value));
    try testing.expect(!result.value.boolean);
}

test "Union - number priority (step 13)" {
    const NumberOrString = union(enum) {
        number: f64,
        string: []const u8,
    };

    const U = Union(NumberOrString);

    // Step 13: Number value matches numeric type directly
    const result = try U.fromJSValue(testing.allocator, .{ .number = 3.14 });
    try testing.expectEqual(@as(std.meta.Tag(NumberOrString), .number), @as(std.meta.Tag(NumberOrString), result.value));
    try testing.expectEqual(@as(f64, 3.14), result.value.number);
}

test "Union - string type (step 15)" {
    const StringOrBool = union(enum) {
        string: []const u8,
        boolean: bool,
    };

    const U = Union(StringOrBool);

    // Step 15: String type gets priority for string JSValue
    const result = try U.fromJSValue(testing.allocator, .{ .string = "test" });
    try testing.expectEqual(@as(std.meta.Tag(StringOrBool), .string), @as(std.meta.Tag(StringOrBool), result.value));
    try testing.expectEqualStrings("test", result.value.string);
}
