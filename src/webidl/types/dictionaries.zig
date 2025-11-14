//! WebIDL Dictionary Conversion
//!
//! Spec: https://webidl.spec.whatwg.org/#idl-dictionaries
//!
//! Dictionaries are ordered maps of key-value pairs converted from JavaScript objects.
//! They support required fields, optional fields with defaults, and inheritance.
//!
//! # Usage
//!
//! ```zig
//! // Extract dictionary member from JSValue
//! const hwm = try webidl.extractDictionaryMember(
//!     f64,
//!     js_value,  // JSValue (must be .object or .undefined)
//!     "highWaterMark",
//!     false,  // optional
//!     1.0,    // default value
//! );
//! ```

const std = @import("std");
const primitives = @import("primitives.zig");
const object = @import("object.zig");
const callbacks = @import("callbacks.zig");

pub const JSValue = primitives.JSValue;
pub const JSObject = object.JSObject;
pub const GenericCallback = callbacks.GenericCallback;

/// Extract dictionary member from JavaScript value
///
/// Spec: WebIDL § 3.2.23 Step 4 (dictionary member conversion)
///
/// Algorithm:
/// 1. If V is not Object and V is undefined and member is not required, return default
/// 2. If V is not Object, throw TypeError
/// 3. Let value be ? Get(V, key)
/// 4. If value is undefined and member is not required:
///    a. Return default value if present
///    b. Otherwise return type's default
/// 5. If member is required and value is undefined, throw TypeError
/// 6. Convert value to member's type
///
/// # Parameters
/// - `T`: Target type for conversion
/// - `value`: JavaScript value to extract from (must be .object or .undefined)
/// - `key`: Property name
/// - `required`: If true, throw if property missing
/// - `default_value`: Value to use if property undefined (optional members only)
///
/// # Returns
/// Converted value of type T, or error if:
/// - Required member is missing
/// - Type conversion fails
/// - Value is not an object (unless undefined and optional)
///
/// # Example
/// ```zig
/// var obj = webidl.JSObject.init(allocator);
/// defer obj.deinit();
/// try obj.set("highWaterMark", .{ .number = 16.0 });
///
/// const hwm = try webidl.extractDictionaryMember(
///     f64,
///     .{ .object = obj },
///     "highWaterMark",
///     false,  // optional
///     1.0,    // default
/// );
/// // hwm == 16.0
/// ```
pub fn extractDictionaryMember(
    comptime T: type,
    value: JSValue,
    comptime key: []const u8,
    comptime required: bool,
    comptime default_value: ?T,
) !T {
    // Step 1: Handle undefined value for optional members
    if (value == .undefined and !required) {
        return default_value orelse getTypeDefault(T);
    }

    // Step 2: Validate value is an object
    if (value != .object) {
        return error.TypeError;
    }

    const obj = value.object;

    // Step 3: Get property
    const prop = obj.get(key);

    // Step 4: Handle missing or undefined property
    if (prop == null or prop.? == .undefined) {
        if (required) {
            return error.RequiredFieldMissing;
        }
        return default_value orelse getTypeDefault(T);
    }

    // Step 5: Convert to target type
    return try convertToType(T, prop.?);
}

/// Get WebIDL default value for a type
///
/// Per WebIDL spec, types have implicit default values:
/// - boolean: false
/// - numeric types: 0
/// - DOMString/ByteString/USVString: "" (empty string)
/// - nullable types: null
fn getTypeDefault(comptime T: type) T {
    return switch (@typeInfo(T)) {
        .bool => false,
        .int => 0,
        .float => 0.0,
        .pointer => |ptr| {
            if (ptr.size == .slice and ptr.child == u8) {
                return "";
            }
            @compileError("No default for pointer type " ++ @typeName(T));
        },
        .optional => null,
        else => @compileError("No default for type " ++ @typeName(T)),
    };
}

/// Convert JSValue to target type using WebIDL conversion rules
///
/// Uses comptime type introspection to select the appropriate conversion function.
/// Public for use by record_conversion.zig and other conversion utilities.
pub fn convertToType(comptime T: type, value: JSValue) !T {
    return switch (@typeInfo(T)) {
        .bool => primitives.toBoolean(value),
        .int => |int_info| convertInteger(T, int_info, value),
        .float => |float_info| convertFloat(T, float_info, value),
        .pointer => |ptr| convertPointer(T, ptr, value),
        .optional => |opt| convertOptional(T, opt, value),
        else => error.UnsupportedType,
    };
}

/// Convert JSValue to integer type
fn convertInteger(comptime T: type, comptime info: std.builtin.Type.Int, value: JSValue) !T {
    if (info.signedness == .signed) {
        return switch (info.bits) {
            8 => @as(T, try primitives.toByte(value)),
            16 => @as(T, try primitives.toShort(value)),
            32 => @as(T, try primitives.toLong(value)),
            64 => @as(T, try primitives.toLongLong(value)),
            else => error.UnsupportedIntegerSize,
        };
    } else {
        return switch (info.bits) {
            8 => @as(T, try primitives.toOctet(value)),
            16 => @as(T, try primitives.toUnsignedShort(value)),
            32 => @as(T, try primitives.toUnsignedLong(value)),
            64 => @as(T, try primitives.toUnsignedLongLong(value)),
            else => error.UnsupportedIntegerSize,
        };
    }
}

/// Convert JSValue to float type
fn convertFloat(comptime T: type, comptime info: std.builtin.Type.Float, value: JSValue) !T {
    return switch (info.bits) {
        32 => @as(T, try primitives.toFloat(value)),
        64 => @as(T, try primitives.toDouble(value)),
        else => error.UnsupportedFloatSize,
    };
}

/// Convert JSValue to pointer type (string slices)
fn convertPointer(comptime T: type, comptime info: std.builtin.Type.Pointer, value: JSValue) !T {
    if (info.size == .slice and info.child == u8) {
        // String type - just return the slice (no allocation needed for []const u8)
        if (value == .string) {
            return value.string;
        }
        return error.TypeError;
    }
    return error.UnsupportedPointerType;
}

/// Convert JSValue to optional type
fn convertOptional(comptime T: type, comptime info: std.builtin.Type.Optional, value: JSValue) !T {
    if (value == .undefined or value == .null) {
        return null;
    }
    const child_value = try convertToType(info.child, value);
    return @as(T, child_value);
}

/// Extract nested dictionary member by navigating property path
///
/// Spec: WebIDL § 3.2.23 (recursive dictionary member extraction)
///
/// Example: Extract `obj.readableStrategy.highWaterMark` (nested path)
///
/// # Parameters
/// - `T`: Target type for conversion
/// - `value`: JavaScript value to extract from
/// - `path`: Array of property names forming the path
/// - `required`: If true, throw if any property in path is missing
/// - `default_value`: Value to use if property undefined (optional members only)
///
/// # Example
/// ```zig
/// // Extract: obj.readableStrategy.highWaterMark
/// const hwm = try extractNestedMember(
///     f64,
///     js_value,
///     &.{ "readableStrategy", "highWaterMark" },
///     false,
///     1.0,
/// );
/// ```
pub fn extractNestedMember(
    comptime T: type,
    value: JSValue,
    comptime path: []const []const u8,
    comptime required: bool,
    comptime default_value: ?T,
) !T {
    // Validate path is not empty
    if (path.len == 0) {
        @compileError("Path must contain at least one property name");
    }

    var current = value;

    // Navigate path (all but last segment)
    for (path[0 .. path.len - 1]) |segment| {
        const next = current.getProperty(segment);
        if (next == null or next.? == .undefined) {
            if (required) {
                return error.RequiredFieldMissing;
            }
            return default_value orelse getTypeDefault(T);
        }
        current = next.?;
    }

    // Extract final property using standard extraction
    const final_key = path[path.len - 1];
    return extractDictionaryMember(T, current, final_key, required, default_value);
}

/// Extract callback function from dictionary member
///
/// Spec: WebIDL § 3.2.10 - Callback function types
///
/// # Parameters
/// - `value`: JavaScript value to extract from
/// - `key`: Property name
/// - `required`: If true, throw if property missing or not callable
///
/// # Returns
/// Optional callback function, or null if property missing/undefined (when optional)
///
/// # Example
/// ```zig
/// const on_success = try extractCallback(js_value, "onSuccess", false);
/// if (on_success) |callback| {
///     // Later, invoke via zig-js-runtime
///     // const result = try runtime.invokeCallback(callback, &args);
/// }
/// ```
pub fn extractCallback(
    value: JSValue,
    comptime key: []const u8,
    comptime required: bool,
) !?GenericCallback {
    // Handle undefined value for optional callbacks
    if (value == .undefined and !required) {
        return null;
    }

    // Validate value is an object
    if (value != .object) {
        if (required) {
            return error.TypeError;
        }
        return null;
    }

    const obj = value.object;

    // Get property
    const prop = obj.get(key);

    // Handle missing or undefined property
    if (prop == null or prop.? == .undefined) {
        if (required) {
            return error.RequiredFieldMissing;
        }
        return null;
    }

    // Check if property is a function
    if (prop.? != .function) {
        if (required) {
            return error.TypeError; // Required callback but property is not a function
        }
        return null; // Optional callback but property is not a function
    }

    return prop.?.function;
}

/// Extended attribute options for dictionary member extraction
///
/// Spec: WebIDL § 3.3 - Extended attributes
pub const ExtendedAttributeOptions = struct {
    /// [EnforceRange] - Enforce value is in target type range
    enforce_range: bool = false,

    /// [Clamp] - Clamp value to target type range
    clamp: bool = false,
};

/// Extract dictionary member with extended attributes
///
/// Spec: WebIDL § 3.3 - Extended attributes
///
/// Supports [EnforceRange] and [Clamp] attributes for numeric types.
///
/// # Example
/// ```zig
/// // WebIDL: [EnforceRange] unsigned long long autoAllocateChunkSize;
/// const chunk_size = try extractDictionaryMemberWithAttrs(
///     u64,
///     js_value,
///     "autoAllocateChunkSize",
///     false,
///     null,
///     .{ .enforce_range = true },
/// );
/// ```
pub fn extractDictionaryMemberWithAttrs(
    comptime T: type,
    value: JSValue,
    comptime key: []const u8,
    comptime required: bool,
    comptime default_value: ?T,
    comptime attrs: ExtendedAttributeOptions,
) !T {
    // Step 1: Handle undefined value for optional members
    if (value == .undefined and !required) {
        return default_value orelse getTypeDefault(T);
    }

    // Step 2: Validate value is an object
    if (value != .object) {
        return error.TypeError;
    }

    const obj = value.object;

    // Step 3: Get property
    const prop = obj.get(key);

    // Step 4: Handle missing or undefined property
    if (prop == null or prop.? == .undefined) {
        if (required) {
            return error.RequiredFieldMissing;
        }
        return default_value orelse getTypeDefault(T);
    }

    // Step 5: Convert to target type with extended attributes
    return try convertToTypeWithAttrs(T, prop.?, attrs);
}

/// Convert JSValue to target type with extended attribute support
fn convertToTypeWithAttrs(comptime T: type, value: JSValue, comptime attrs: ExtendedAttributeOptions) !T {
    const type_info = @typeInfo(T);

    // Extended attributes only apply to integer types
    if (type_info == .int) {
        const int_info = type_info.int;
        if (attrs.enforce_range) {
            return try convertIntegerEnforceRange(T, int_info, value);
        } else if (attrs.clamp) {
            return convertIntegerClamped(T, int_info, value);
        }
    }

    // For non-integer types or no extended attrs, use standard conversion
    return try convertToType(T, value);
}

/// Convert integer with [EnforceRange]
fn convertIntegerEnforceRange(comptime T: type, comptime info: std.builtin.Type.Int, value: JSValue) !T {
    if (info.signedness == .signed) {
        return switch (info.bits) {
            8 => @as(T, try primitives.toByte(value)), // No EnforceRange for byte
            16 => @as(T, try primitives.toShortEnforceRange(value)),
            32 => @as(T, try primitives.toLongEnforceRange(value)),
            64 => @as(T, try primitives.toLongLongEnforceRange(value)),
            else => error.UnsupportedIntegerSize,
        };
    } else {
        return switch (info.bits) {
            8 => @as(T, try primitives.toOctet(value)), // No EnforceRange for octet
            16 => @as(T, try primitives.toUnsignedShortEnforceRange(value)),
            32 => @as(T, try primitives.toUnsignedLongEnforceRange(value)),
            64 => @as(T, try primitives.toUnsignedLongLongEnforceRange(value)),
            else => error.UnsupportedIntegerSize,
        };
    }
}

/// Convert integer with [Clamp]
fn convertIntegerClamped(comptime T: type, comptime info: std.builtin.Type.Int, value: JSValue) T {
    if (info.signedness == .signed) {
        return switch (info.bits) {
            8 => clampToByte(value),
            16 => @as(T, primitives.toShortClamped(value)),
            32 => @as(T, primitives.toLongClamped(value)),
            64 => @as(T, primitives.toLongLongClamped(value)),
            else => unreachable,
        };
    } else {
        return switch (info.bits) {
            8 => clampToOctet(value),
            16 => @as(T, primitives.toUnsignedShortClamped(value)),
            32 => @as(T, primitives.toUnsignedLongClamped(value)),
            64 => @as(T, primitives.toUnsignedLongLongClamped(value)),
            else => unreachable,
        };
    }
}

/// Manual clamp for byte (i8) since primitives doesn't provide toByteClamped
fn clampToByte(value: JSValue) i8 {
    var x = value.toNumber();
    if (std.math.isNan(x)) return 0;
    x = @min(@max(x, -128.0), 127.0);
    x = @round(x);
    return @intFromFloat(x);
}

/// Manual clamp for octet (u8) since primitives doesn't provide toOctetClamped
fn clampToOctet(value: JSValue) u8 {
    var x = value.toNumber();
    if (std.math.isNan(x)) return 0;
    x = @min(@max(x, 0.0), 255.0);
    x = @round(x);
    return @intFromFloat(x);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;






















// ============================================================================
// Callback Extraction Tests
// ============================================================================

// Mock vtable for testing
const MockCallbackVTable = callbacks.CallbackVTable{
    .invoke = mockInvoke,
    .release = mockRelease,
    .isCallable = mockIsCallable,
};

fn mockInvoke(
    handle: *anyopaque,
    context: ?*anyopaque,
    args: []const primitives.JSValue,
) anyerror!primitives.JSValue {
    _ = handle;
    _ = context;
    _ = args;
    return .{ .number = 42.0 };
}

fn mockRelease(handle: *anyopaque, context: ?*anyopaque) void {
    _ = handle;
    _ = context;
}

fn mockIsCallable(handle: *anyopaque, context: ?*anyopaque) bool {
    _ = handle;
    _ = context;
    return true;
}

var mock_data: u8 = 0;

fn createMockCallback() GenericCallback {
    return .{
        .handle = @ptrCast(&mock_data),
        .context = null,
        .vtable = &MockCallbackVTable,
    };
}








// ============================================================================
// Extended Attribute Tests
// ============================================================================






