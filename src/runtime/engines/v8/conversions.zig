//! V8 Type Conversion Layer
//!
//! This module provides bidirectional type conversions between Zig WebIDL runtime types
//! and V8 JavaScript values. All conversions follow WebIDL specification semantics.
//!
//! ## Conversion Flow
//!
//! JavaScript (V8) ←→ Zig (WebIDL Runtime)
//!
//! Examples:
//! - v8::String → runtime.DOMString
//! - v8::Number → runtime.Double / runtime.Long
//! - v8::Array → runtime.sequence(T)
//! - v8::Object → runtime.record(K, V)
//! - v8::Value (any) → runtime.Any (opaque pointer)
//!
//! ## Error Handling
//!
//! Conversions can fail due to type mismatches or out-of-range values.
//! All conversion functions return error unions for proper error propagation.

const std = @import("std");
const v8 = @import("ffi.zig");
const runtime = @import("runtime");
const namespace = @import("namespace.zig");
const interface_mod = @import("interface.zig");
const dom_type_info = @import("dom_type_info.zig");
const callback_wrapper = @import("callback_wrapper.zig");
const typedefs = @import("typedefs");

/// Conversion errors that can occur during type conversion
pub const ConversionError = error{
    /// V8 value is not the expected type
    TypeError,

    /// Numeric value is out of range for target type
    RangeError,

    /// String contains invalid UTF-8 or violates constraints
    StringError,

    /// Memory allocation failed during conversion
    OutOfMemory,

    /// Context is required but was null
    NullContext,
};

// ============================================================================
// Helper Functions
// ============================================================================

/// Check if a runtime enum name matches a comptime Zig enum field name.
/// Handles the transformation from WebIDL format ("same-origin") to Zig format ("_same_origin_"):
/// - Hyphens in the runtime name match underscores in the field name
/// - Leading/trailing underscores in field name are ignored
fn enumNameMatches(comptime field_name: []const u8, runtime_name: []const u8) bool {
    // Get the normalized field name bounds (strip leading/trailing underscores)
    comptime var start: usize = 0;
    comptime var end: usize = field_name.len;
    if (field_name.len > 0 and field_name[0] == '_') start = 1;
    if (end > start and field_name[end - 1] == '_') end -= 1;
    const normalized_field = field_name[start..end];

    // Length must match
    if (normalized_field.len != runtime_name.len) return false;

    // Compare character by character, treating hyphens as underscores
    inline for (normalized_field, 0..) |fc, i| {
        const rc = runtime_name[i];
        // Field char is underscore, runtime char can be either underscore or hyphen
        if (fc == '_') {
            if (rc != '_' and rc != '-') return false;
        } else {
            if (fc != rc) return false;
        }
    }
    return true;
}

// ============================================================================
// JavaScript to Zig (V8 → Runtime)
// ============================================================================

/// Convert V8 String to Zig DOMString
///
/// Allocates memory for the string contents using the provided allocator.
/// Caller must call DOMString.deinit() when done.
pub fn fromV8String(
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: *v8.String,
) ConversionError!runtime.DOMString {
    _ = isolate;
    _ = context;

    // Get UTF-8 length (excludes null terminator)
    const length = v8.v8_String_Utf8Length(value);
    if (length < 0) {
        return ConversionError.StringError;
    }

    // Handle empty strings efficiently
    if (length == 0) {
        return runtime.DOMString.empty;
    }

    // Allocate buffer for UTF-8 data
    const buffer = try allocator.alloc(u8, @intCast(length));
    errdefer allocator.free(buffer);

    // Write UTF-8 to buffer
    const written = v8.v8_String_WriteUtf8(value, buffer.ptr, @intCast(length));
    if (written != length) {
        return ConversionError.StringError;
    }

    // Create DOMString from owned slice
    return runtime.DOMString.initOwned(buffer);
}

/// Convert V8 Value to Zig boolean
pub fn fromV8Boolean(
    isolate: *v8.Isolate,
    value: *v8.Value,
) runtime.Boolean {
    return v8.v8_Value_BooleanValue(value, isolate);
}

/// Convert V8 Value to Zig i32 (long)
pub fn fromV8Long(
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!runtime.Long {
    if (!v8.v8_Value_IsNumber(value)) {
        return ConversionError.TypeError;
    }
    return v8.v8_Value_Int32Value(value, context);
}

/// Convert V8 Value to Zig u32 (unsigned long)
pub fn fromV8UnsignedLong(
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!runtime.UnsignedLong {
    if (!v8.v8_Value_IsNumber(value)) {
        return ConversionError.TypeError;
    }
    return v8.v8_Value_Uint32Value(value, context);
}

/// Convert V8 Value to Zig i64 (long long)
pub fn fromV8LongLong(
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!runtime.LongLong {
    if (!v8.v8_Value_IsNumber(value)) {
        return ConversionError.TypeError;
    }
    return v8.v8_Value_IntegerValue(value, context);
}

/// Convert V8 Value to Zig u64 (unsigned long long)
pub fn fromV8UnsignedLongLong(
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!runtime.UnsignedLongLong {
    if (!v8.v8_Value_IsNumber(value)) {
        return ConversionError.TypeError;
    }
    const int_val = v8.v8_Value_IntegerValue(value, context);
    // JavaScript numbers can be negative, but unsigned long long should be >= 0
    if (int_val < 0) {
        return ConversionError.TypeError;
    }
    return @intCast(int_val);
}

/// Convert V8 Value to Zig f64 (double)
pub fn fromV8Double(
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!runtime.Double {
    if (!v8.v8_Value_IsNumber(value)) {
        return ConversionError.TypeError;
    }
    return v8.v8_Value_NumberValue(value, context);
}

/// Convert V8 Value to Zig f32 (float)
pub fn fromV8Float(
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!runtime.Float {
    const double = try fromV8Double(context, value);
    return @floatCast(double);
}

/// Convert V8 Value to runtime.Any (opaque pointer)
///
/// The V8 value is type-erased and stored as an opaque pointer.
/// This is used for WebIDL 'any' type parameters.
pub fn fromV8Any(value: *v8.Value) runtime.Any {
    return @ptrCast(value);
}

/// Convert V8 Object to runtime.Object (opaque pointer)
pub fn fromV8Object(value: *v8.Object) runtime.Object {
    return @ptrCast(value);
}

/// Convert V8 Array to Zig sequence
///
/// Allocates memory for the sequence and converts each element.
/// Caller must free the returned slice when done.
pub fn fromV8Sequence(
    comptime T: type,
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    array: *v8.Array,
) ConversionError![]T {
    const length = v8.v8_Array_Length(array);
    const slice = try allocator.alloc(T, length);
    errdefer allocator.free(slice);

    for (0..length) |i| {
        const v8_value = v8.v8_Array_Get(context, array, @intCast(i)) orelse continue;
        slice[i] = try fromV8Value(T, allocator, isolate, context, v8_value);
    }

    return slice;
}

/// Convert V8 Object to WebIDL record<K,V>
///
/// Iterates over object properties and creates key-value pairs.
/// Caller must call record.deinit() when done.
pub fn fromV8Record(
    comptime K: type,
    comptime V: type,
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    object: *v8.Object,
) ConversionError!runtime.record(K, V) {
    // Get own property names (excludes inherited properties)
    const names = v8.v8_Object_GetOwnPropertyNames(context, object) orelse {
        // If property enumeration fails, return empty record
        return runtime.record(K, V).init(allocator);
    };
    defer v8.v8_Array_Dispose(names);

    const length = v8.v8_Array_Length(names);
    var rec = try runtime.record(K, V).init(allocator);
    errdefer rec.deinit();

    for (0..length) |i| {
        // Get property name as V8 value
        const key_value = v8.v8_Array_Get(names, context, @intCast(i)) orelse continue;
        defer v8.v8_Value_Dispose(key_value);

        // Convert key from V8 to K type
        const key = try fromV8Value(K, allocator, isolate, context, key_value);
        errdefer if (K == runtime.DOMString or K == runtime.USVString or K == runtime.ByteString) {
            // Free string keys on error
            if (@TypeOf(key) == runtime.DOMString) key.deinit();
        };

        // Get property value from object
        const val_v8 = v8.v8_Object_Get(object, context, key_value) orelse {
            // Property disappeared between enumeration and access - skip it
            continue;
        };
        defer v8.v8_Value_Dispose(val_v8);

        // Convert value from V8 to V type
        const value = try fromV8Value(V, allocator, isolate, context, val_v8);
        errdefer if (V == runtime.DOMString or V == runtime.USVString or V == runtime.ByteString) {
            // Free string values on error
            if (@TypeOf(value) == runtime.DOMString) value.deinit();
        };

        // Add key-value pair to record
        try rec.put(key, value);
    }

    return rec;
}

/// Convert V8 value to HeadersInit union
/// Handles: sequence<sequence<ByteString>>, record<ByteString, ByteString>, Headers
fn convertHeadersInit(
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!typedefs.HeadersInit {
    _ = isolate; // Used only for potential future error reporting
    // Check if it's an array (sequence<sequence<ByteString>>)
    if (v8.v8_Value_IsArray(value)) {
        const array = @as(*v8.Array, @ptrCast(value));
        const length = v8.v8_Array_Length(array);

        // Allocate array for pairs
        const pairs = try allocator.alloc([2][]const u8, length);
        errdefer allocator.free(pairs);

        for (0..length) |i| {
            const elem = v8.v8_Array_Get(context, array, @intCast(i)) orelse continue;

            // Each element should be an array of [key, value]
            if (!v8.v8_Value_IsArray(elem)) {
                // Not a valid pair, skip
                pairs[i] = .{ "", "" };
                continue;
            }

            const pair_array = @as(*v8.Array, @ptrCast(elem));
            const pair_len = v8.v8_Array_Length(pair_array);
            if (pair_len < 2) {
                pairs[i] = .{ "", "" };
                continue;
            }

            // Get key and value
            const key_val = v8.v8_Array_Get(context, pair_array, 0);
            const val_val = v8.v8_Array_Get(context, pair_array, 1);

            var key_str: []const u8 = "";
            var val_str: []const u8 = "";

            if (key_val) |kv| {
                if (v8.v8_Value_IsString(kv)) {
                    const str = v8.v8_Value_ToString(kv, context);
                    if (str) |s| {
                        const len = v8.v8_String_Utf8Length(s);
                        if (len > 0) {
                            const buf = try allocator.alloc(u8, @intCast(len));
                            _ = v8.v8_String_WriteUtf8(s, buf.ptr, @intCast(len));
                            key_str = buf;
                        }
                    }
                }
            }

            if (val_val) |vv| {
                if (v8.v8_Value_IsString(vv)) {
                    const str = v8.v8_Value_ToString(vv, context);
                    if (str) |s| {
                        const len = v8.v8_String_Utf8Length(s);
                        if (len > 0) {
                            const buf = try allocator.alloc(u8, @intCast(len));
                            _ = v8.v8_String_WriteUtf8(s, buf.ptr, @intCast(len));
                            val_str = buf;
                        }
                    }
                }
            }

            pairs[i] = .{ key_str, val_str };
        }

        return .{ .pairs = pairs };
    }

    // Check if it's an object (record<ByteString, ByteString> or Headers)
    if (v8.v8_Value_IsObject(value)) {
        const obj = @as(*v8.Object, @ptrCast(value));

        // Check if it's a Headers object (has internal fields with instance)
        // Plain JS objects have 0 internal fields, wrapped Zig objects have 2
        const field_count = v8.v8_Object_InternalFieldCount(obj);
        if (field_count >= 1) {
            const internal_ptr = v8.v8_Object_GetAlignedPointerFromInternalField(obj, 0);
            if (internal_ptr != null) {
                // This might be a Headers object - pass as headers_ptr
                return .{ .headers_ptr = @ptrCast(internal_ptr) };
            }
        }

        // It's a plain object - get OWN property names only (not inherited)
        // This avoids including __proto__, constructor, toString, etc.
        const prop_names = v8.v8_Object_GetOwnPropertyNames(context, obj) orelse {
            // Empty object
            return .{ .record = &.{} };
        };

        const prop_count = v8.v8_Array_Length(prop_names);
        // Use the actual HeaderEntry type from typedefs
        const entries = try allocator.alloc(typedefs.HeaderEntry, prop_count);
        errdefer allocator.free(entries);

        var valid_count: usize = 0;
        for (0..prop_count) |i| {
            const prop_name_val = v8.v8_Array_Get(context, prop_names, @intCast(i)) orelse continue;

            // Get property name as string
            const prop_name_str = v8.v8_Value_ToString(prop_name_val, context) orelse continue;
            const name_len = v8.v8_String_Utf8Length(prop_name_str);
            if (name_len <= 0) continue;

            const name_buf = try allocator.alloc(u8, @intCast(name_len));
            errdefer allocator.free(name_buf);
            _ = v8.v8_String_WriteUtf8(prop_name_str, name_buf.ptr, @intCast(name_len));

            // Get property value
            const prop_val = v8.v8_Object_Get(obj, context, @ptrCast(prop_name_val)) orelse continue;

            var val_str: []const u8 = "";
            if (v8.v8_Value_IsString(prop_val)) {
                const str = v8.v8_Value_ToString(prop_val, context);
                if (str) |s| {
                    const len = v8.v8_String_Utf8Length(s);
                    if (len > 0) {
                        const buf = try allocator.alloc(u8, @intCast(len));
                        _ = v8.v8_String_WriteUtf8(s, buf.ptr, @intCast(len));
                        val_str = buf;
                    }
                }
            }

            entries[valid_count] = .{
                .name = name_buf,
                .value = val_str,
            };
            valid_count += 1;
        }

        return .{ .record = entries[0..valid_count] };
    }

    // Fallback - pass V8 value as opaque
    return .{ .v8_value = @ptrCast(value) };
}

/// Convert V8 value to BodyInit union
/// Handles: USVString, TypedArray (Uint8Array, etc.)
/// TODO: Add support for Blob, FormData, URLSearchParams, ReadableStream
fn convertBodyInit(
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!typedefs.BodyInit {
    _ = isolate; // Used only for potential future error reporting

    // Check for null/undefined - return empty string
    if (v8.v8_Value_IsNullOrUndefined(value)) {
        return .{ .string = "" };
    }

    // Check if it's a string (most common case: USVString)
    if (v8.v8_Value_IsString(value)) {
        const string = v8.v8_Value_ToString(value, context) orelse return ConversionError.TypeError;
        const length = v8.v8_String_Utf8Length(string);
        if (length <= 0) {
            return .{ .string = "" };
        }

        const buffer = try allocator.alloc(u8, @intCast(length));
        errdefer allocator.free(buffer);
        const written = v8.v8_String_WriteUtf8(string, buffer.ptr, @intCast(length));
        if (written != length) {
            allocator.free(buffer);
            return ConversionError.StringError;
        }
        return .{ .string = buffer };
    }

    // Check if it's a TypedArray (Uint8Array, etc.)
    if (v8.v8_Value_IsTypedArray(value)) {
        const byte_length = v8.v8_TypedArray_ByteLength(value);

        if (byte_length == 0) {
            return .{ .buffer = "" };
        }

        // Get the underlying ArrayBuffer and offset
        const ab = v8.v8_TypedArray_Buffer(value) orelse return .{ .buffer = "" };
        const byte_offset = v8.v8_TypedArray_ByteOffset(value);
        const data = v8.v8_ArrayBuffer_Data(ab);

        if (data == null) {
            return .{ .buffer = "" };
        }

        // Copy the data from the correct offset
        const buffer = try allocator.alloc(u8, byte_length);
        const src_ptr = @as([*]const u8, @ptrCast(data.?)) + byte_offset;
        @memcpy(buffer, src_ptr[0..byte_length]);
        return .{ .buffer = buffer };
    }

    // TODO: Check for Blob, FormData, URLSearchParams, ReadableStream instances
    // These require checking the object's constructor name or internal state

    // Fallback - pass V8 value as opaque for later processing
    return .{ .v8_value = @ptrCast(value) };
}

/// Generic V8 Value to Zig type conversion
///
/// Dispatches to the appropriate conversion function based on target type.
pub fn fromV8Value(
    comptime T: type,
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!T {
    // Handle optional types (nullable)
    const type_info = @typeInfo(T);
    if (type_info == .optional) {
        // Check for null/undefined
        if (v8.v8_Value_IsNullOrUndefined(value)) {
            return null;
        }
        // Recursively convert the child type
        const ChildType = type_info.optional.child;
        return try fromV8Value(ChildType, allocator, isolate, context, value);
    }

    // Handle slices (sequence<T> or ByteString)
    if (type_info == .pointer and type_info.pointer.size == .slice) {
        const ElemType = type_info.pointer.child;

        // Special case: []const u8 (ByteString/USVString) - convert using ToString
        // Per WebIDL spec, USVString and DOMString use ToString coercion on any value
        // except Symbol (which throws TypeError).
        // https://webidl.spec.whatwg.org/#idl-USVString
        if (ElemType == u8) {
            // Check for Symbol - throws TypeError per WebIDL spec
            if (v8.v8_Value_IsSymbol(value)) {
                return ConversionError.TypeError;
            }
            // Use ToString coercion for everything else (numbers, booleans, objects, etc.)
            // This matches browser behavior where formData.append('key', 123) stores "123"
            const string = v8.v8_Value_ToString(value, context) orelse return ConversionError.TypeError;
            const length = v8.v8_String_Utf8Length(string);
            if (length < 0) return ConversionError.StringError;
            if (length == 0) return &[_]u8{};

            const buffer = try allocator.alloc(u8, @intCast(length));
            const written = v8.v8_String_WriteUtf8(string, buffer.ptr, @intCast(length));
            if (written != length) {
                allocator.free(buffer);
                return ConversionError.StringError;
            }
            return buffer;
        }

        // Generic sequence handling - value must be an array
        if (!v8.v8_Value_IsArray(value)) {
            return ConversionError.TypeError;
        }
        const array = @as(*v8.Array, @ptrCast(value));
        return try fromV8Sequence(ElemType, allocator, isolate, context, array);
    }

    // Handle DOMString specially (it's a union type but should be treated as a string)
    if (T == runtime.DOMString) {
        if (!v8.v8_Value_IsString(value)) {
            return ConversionError.TypeError;
        }
        const string = v8.v8_Value_ToString(value, context) orelse return ConversionError.TypeError;
        return try fromV8String(allocator, isolate, context, string);
    }

    // Handle HeadersInit specially - parse V8 value to appropriate variant
    if (T == @import("typedefs").HeadersInit) {
        return try convertHeadersInit(allocator, isolate, context, value);
    }

    // Handle BodyInit specially - parse V8 value to appropriate variant
    if (T == @import("typedefs").BodyInit) {
        return try convertBodyInit(allocator, isolate, context, value);
    }

    // Handle unions (for constructor overloading and type unions)
    if (type_info == .@"union") {
        // Union types require runtime type discrimination per WebIDL specification.
        //
        // For common union patterns (HeadersInit, BodyInit, etc.), we try to
        // find the best matching variant based on the V8 value type.
        //
        // Strategy: At comptime, find which variant matches each JS type category,
        // then dispatch at runtime based on the actual value type.

        const union_info = type_info.@"union";
        const fields = union_info.fields;

        // Find indices for different type categories at comptime
        // Note: []const u8 (ByteString, USVString) could match both string and sequence
        // so we need to check for byte slices specifically

        // String types: DOMString (union), or []const u8 (ByteString/USVString)
        const string_idx: ?usize = comptime blk: {
            for (fields, 0..) |field, i| {
                if (field.type == runtime.DOMString) {
                    break :blk i;
                }
                // Check for []const u8 (ByteString, USVString, runtime.ByteString, runtime.USVString)
                const field_info = @typeInfo(field.type);
                if (field_info == .pointer and field_info.pointer.size == .slice and
                    field_info.pointer.child == u8)
                {
                    break :blk i;
                }
            }
            break :blk null;
        };

        // Sequence types: slices that are NOT []const u8
        const sequence_idx: ?usize = comptime blk: {
            for (fields, 0..) |field, i| {
                const field_info = @typeInfo(field.type);
                if (field_info == .pointer and field_info.pointer.size == .slice) {
                    // Skip []const u8 which is handled as string above
                    if (field_info.pointer.child == u8) continue;
                    break :blk i;
                }
            }
            break :blk null;
        };

        const dict_idx: ?usize = comptime blk: {
            for (fields, 0..) |field, i| {
                const field_info = @typeInfo(field.type);
                if (field_info == .@"struct" and !@hasDecl(field.type, "Meta")) {
                    break :blk i;
                }
            }
            break :blk null;
        };

        const boolean_idx: ?usize = comptime blk: {
            for (fields, 0..) |field, i| {
                if (field.type == runtime.Boolean) {
                    break :blk i;
                }
            }
            break :blk null;
        };

        const number_idx: ?usize = comptime blk: {
            for (fields, 0..) |field, i| {
                const field_info = @typeInfo(field.type);
                if (field_info == .int or field_info == .float or
                    field.type == runtime.Double or field.type == runtime.Long)
                {
                    break :blk i;
                }
            }
            break :blk null;
        };

        // Check if this union has only *anyopaque variants (generated for unresolved unions)
        const anyopaque_idx: ?usize = comptime blk: {
            for (fields, 0..) |field, i| {
                if (field.type == *const anyopaque or field.type == *anyopaque) {
                    break :blk i;
                }
            }
            break :blk null;
        };

        // Runtime dispatch based on V8 value type
        if (v8.v8_Value_IsArray(value)) {
            if (sequence_idx) |idx| {
                const FieldType = fields[idx].type;
                const converted = try fromV8Value(FieldType, allocator, isolate, context, value);
                return @unionInit(T, fields[idx].name, converted);
            }
        } else if (v8.v8_Value_IsString(value)) {
            if (string_idx) |idx| {
                const FieldType = fields[idx].type;
                const converted = try fromV8Value(FieldType, allocator, isolate, context, value);
                return @unionInit(T, fields[idx].name, converted);
            }
        } else if (v8.v8_Value_IsBoolean(value)) {
            if (boolean_idx) |idx| {
                const FieldType = fields[idx].type;
                const converted = try fromV8Value(FieldType, allocator, isolate, context, value);
                return @unionInit(T, fields[idx].name, converted);
            }
        } else if (v8.v8_Value_IsNumber(value)) {
            if (number_idx) |idx| {
                const FieldType = fields[idx].type;
                const converted = try fromV8Value(FieldType, allocator, isolate, context, value);
                return @unionInit(T, fields[idx].name, converted);
            }
        } else if (v8.v8_Value_IsObject(value)) {
            if (dict_idx) |idx| {
                const FieldType = fields[idx].type;
                const converted = try fromV8Value(FieldType, allocator, isolate, context, value);
                return @unionInit(T, fields[idx].name, converted);
            }
        }

        // Fallback: If no typed variant matched but we have an anyopaque variant,
        // use it to pass through the V8 value. This handles unions like HeadersInit
        // where codegen generates *anyopaque variants for unresolved types.
        if (anyopaque_idx) |idx| {
            // Pass through the V8 value as an opaque pointer
            // The implementation is responsible for parsing this
            return @unionInit(T, fields[idx].name, @ptrCast(value));
        }

        // No matching variant found - return error
        return ConversionError.TypeError;
    }

    // Handle integers (beyond WebIDL standard types)
    if (type_info == .int) {
        if (!v8.v8_Value_IsNumber(value)) {
            return ConversionError.TypeError;
        }
        const num_value = v8.v8_Value_NumberValue(value, context);

        // Check range and convert
        const int_value: i64 = @intFromFloat(num_value);
        if (!runtime.isInRange(T, int_value)) {
            return ConversionError.RangeError;
        }
        return @intCast(int_value);
    }

    // Handle enums (convert from string or integer)
    if (type_info == .@"enum") {
        if (v8.v8_Value_IsString(value)) {
            // Try to parse enum from string name
            const string = v8.v8_Value_ToString(value, context) orelse return ConversionError.TypeError;
            var dom_string = try fromV8String(allocator, isolate, context, string);
            defer dom_string.deinit(allocator);

            // Try to match enum name
            const enum_name = switch (dom_string) {
                .empty => "",
                .interned => |s| s,
                .owned => |s| s,
            };

            // Use @typeInfo to iterate enum fields and match by name
            // WebIDL enum values like "same-origin" are stored as _same_origin_ in Zig:
            // - Hyphens become underscores
            // - Leading/trailing underscores wrap reserved words
            inline for (std.meta.fields(T)) |field| {
                // Try matching with WebIDL normalization (handles hyphens, underscores, etc.)
                if (enumNameMatches(field.name, enum_name)) {
                    return @enumFromInt(field.value);
                }
            }
            return ConversionError.TypeError;
        } else if (v8.v8_Value_IsNumber(value)) {
            // Convert from integer value
            const num_value = v8.v8_Value_NumberValue(value, context);
            const int_value: i32 = @intFromFloat(num_value);
            return @enumFromInt(int_value);
        } else {
            return ConversionError.TypeError;
        }
    }

    // Handle *runtime.Instance (interface instance pointers)
    if (T == *runtime.Instance) {
        // Extract instance pointer from V8 object's internal field
        if (!v8.v8_Value_IsObject(value)) {
            return ConversionError.TypeError;
        }

        // Check if this is a function (callback interface like EventListener)
        // Functions don't have internal fields, so we can't extract a *runtime.Instance
        //
        // NOTE: This is an architectural limitation. Callback interfaces (EventListener,
        // NodeFilter, XPathNSResolver) should be generated as *CallbackWrapper types,
        // not *runtime.Instance. Until codegen is updated:
        //
        // - Functions passed as callback interface params will return TypeError
        // - The impl code should handle null callbacks gracefully
        //
        // TODO: Update codegen to generate proper callback interface types
        // See: src/webidl/v8_bindings/callback_wrapper.zig for CallbackWrapper
        if (v8.v8_Value_IsFunction(value)) {
            // Return null instead of error - allows impl to handle gracefully
            // This is a workaround until proper callback interface support is added
            return ConversionError.TypeError;
        }

        const object = @as(*v8.Object, @ptrCast(value));

        // First try to get stored WrapperTypeInfo for validation
        if (interface_mod.getWrapperTypeInfo(object)) |wrapper_info| {
            // We have type info - use type-safe unwrapping
            // For generic *runtime.Instance, we accept any valid wrapped object
            // by checking that it has a valid type tag (any tag is fine)
            if (wrapper_info.this_tag > 0) {
                // Valid type info, get instance from slot 0
                return interface_mod.getInstance(runtime.Instance, object) orelse {
                    return ConversionError.TypeError;
                };
            }
        }

        // Fall back to legacy extraction (no type info stored)
        // Get the instance pointer from internal field 0
        const internal_field = v8.v8_Object_GetAlignedPointerFromInternalField(object, 0) orelse {
            return ConversionError.TypeError;
        };

        return @ptrCast(@alignCast(internal_field));
    }

    // Handle function pointers (callbacks)
    if (type_info == .pointer) {
        const child_info = @typeInfo(type_info.pointer.child);
        if (child_info == .@"fn") {
            // Function pointer - store as opaque pointer for now
            // The V8 function object will be wrapped and called later
            return @ptrCast(@alignCast(@constCast(value)));
        }
    }

    // Handle webidl.Opt (Optional wrapper type)
    // This must come before generic struct handling since Opt is a struct
    if (type_info == .@"struct" and @hasDecl(T, "notPassed") and @hasDecl(T, "wasPassed")) {
        // This is a webidl.Opt(InnerType) - convert the inner value and wrap it
        // Get the inner type from the 'value' field using comptime struct field access
        const InnerType = comptime blk: {
            const fields = std.meta.fields(T);
            for (fields) |field| {
                if (std.mem.eql(u8, field.name, "value")) {
                    break :blk field.type;
                }
            }
            // Opt types always have a 'value' field
            @compileError("webidl.Opt type missing 'value' field");
        };

        // Check for null/undefined - return notPassed
        if (v8.v8_Value_IsNullOrUndefined(value)) {
            return T.notPassed();
        }

        // Convert the inner value
        const inner_value = try fromV8Value(InnerType, allocator, isolate, context, value);
        return T.passed(inner_value);
    }

    // Handle structs (dictionaries vs interfaces)
    if (type_info == .@"struct") {
        // Check if this is a WebIDL interface (has Meta subtype)
        if (@hasDecl(T, "Meta")) {
            // This is a WebIDL interface, not a dictionary
            // TODO: Extract *runtime.Instance from V8 object's internal field
            // For now, interfaces in constructor parameters are not fully supported
            return error.TypeError;
        }

        // Regular dictionary struct - convert from V8 object
        if (!v8.v8_Value_IsObject(value)) {
            return ConversionError.TypeError;
        }
        const object = @as(*v8.Object, @ptrCast(value));

        var result: T = undefined;
        inline for (std.meta.fields(T)) |field| {
            // Special handling for 'base' field in dictionary inheritance
            // In WebIDL, child dictionaries inherit parent fields directly on the object
            // e.g., { bubbles: true, oldVersion: 1 } not { base: { bubbles: true }, oldVersion: 1 }
            if (comptime std.mem.eql(u8, field.name, "base")) {
                const field_type_info = @typeInfo(field.type);
                if (field_type_info == .@"struct") {
                    // Recursively extract parent dictionary fields from the same object
                    @field(result, field.name) = try fromV8Value(
                        field.type,
                        allocator,
                        isolate,
                        context,
                        value, // Pass the same object, not a nested property
                    );
                    continue;
                }
            }

            // Get property name
            const field_name_str = v8.v8_String_NewFromUtf8(
                isolate,
                field.name.ptr,
                @intCast(field.name.len),
            );

            // Get property value from object
            const field_v8_opt = v8.v8_Object_Get(object, context, @ptrCast(field_name_str));

            if (field_v8_opt) |field_v8| {
                // Convert field value
                @field(result, field.name) = try fromV8Value(
                    field.type,
                    allocator,
                    isolate,
                    context,
                    field_v8,
                );
            } else {
                // Property doesn't exist
                if (@typeInfo(field.type) == .optional) {
                    @field(result, field.name) = null;
                } else {
                    return ConversionError.TypeError;
                }
            }
        }
        return result;
    }

    // Handle void (used for no-argument constructors)
    if (T == void) {
        // Void doesn't need conversion from V8
        return {};
    }

    // Handle primitive and special types using if-chain to avoid compile errors
    if (T == runtime.Boolean) return fromV8Boolean(isolate, value);
    if (T == runtime.Long) return try fromV8Long(context, value);
    if (T == runtime.UnsignedLong) return try fromV8UnsignedLong(context, value);
    if (T == runtime.LongLong) return try fromV8LongLong(context, value);
    if (T == runtime.UnsignedLongLong) return try fromV8UnsignedLongLong(context, value);
    if (T == u64) return try fromV8UnsignedLongLong(context, value);
    if (T == runtime.Double) return try fromV8Double(context, value);
    if (T == runtime.Float) return try fromV8Float(context, value);
    if (T == runtime.DOMString) {
        if (!v8.v8_Value_IsString(value)) {
            return ConversionError.TypeError;
        }
        const string = v8.v8_Value_ToString(value, context) orelse return ConversionError.TypeError;
        return try fromV8String(allocator, isolate, context, string);
    }
    if (T == runtime.Any) return fromV8Any(value);
    if (T == *const anyopaque) {
        // For anyopaque parameters (WebIDL 'any' type), pass through the V8 value as-is.
        // The V8 value pointer (Global<Value>*) is returned so it can be stored and
        // passed back to JavaScript unchanged.
        //
        // IMPORTANT: Do NOT convert the value to Zig types here!
        // - Streams API uses 'any' for chunks that should round-trip to JS unchanged
        // - Converting to DOMString would lose the original V8 reference
        // - When the value is later passed back (e.g., in iterator.next()), we need
        //   the original V8 pointer to pass to toV8() which expects a V8 value
        return @ptrCast(value);
    }

    // Handle CallbackWrapper types (for callback interfaces like EventListener, NodeFilter, etc.)
    // We use the V8-specific callback wrapper and cast to runtime.CallbackWrapper pointer
    if (T == *runtime.CallbackWrapper) {
        // Create a V8 CallbackWrapper from the V8 value (function or object with handleEvent)
        const v8_wrapper = try callback_wrapper.createFromV8Value(
            allocator,
            isolate,
            context,
            value,
            "handleEvent", // Default method name for callback interfaces
        ) orelse return ConversionError.TypeError;
        // Cast to opaque runtime.CallbackWrapper pointer
        // The runtime.CallbackWrapper and v8 CallbackWrapper are layout-compatible for this use
        return @ptrCast(v8_wrapper);
    }
    if (T == ?*runtime.CallbackWrapper) {
        // Optional callback - null/undefined is valid
        if (v8.v8_Value_IsNullOrUndefined(value)) {
            return null;
        }
        const v8_wrapper = try callback_wrapper.createFromV8Value(
            allocator,
            isolate,
            context,
            value,
            "handleEvent",
        );
        if (v8_wrapper) |w| {
            return @ptrCast(w);
        }
        return null;
    }

    // Handle pointer types that might be generated by codegen for buffer sources
    // This catches things like *ArrayBuffer, *TypedArray, etc.
    if (type_info == .pointer and type_info.pointer.size == .one) {
        const ChildType = type_info.pointer.child;
        const child_info = @typeInfo(ChildType);

        // Check if child type is a struct (like ArrayBuffer)
        if (child_info == .@"struct") {
            // For now, return TypeError - buffer source conversion requires
            // special V8 API calls that aren't yet implemented
            // TODO: Implement V8 ArrayBuffer/TypedArray extraction
            return ConversionError.TypeError;
        }
    }

    // If we get here, it's an unsupported type
    @compileError("Unsupported type for V8 conversion: " ++ @typeName(T));
}

// ============================================================================
// Zig to JavaScript (Runtime → V8)
// ============================================================================

/// Convert Zig DOMString to V8 String
pub fn toV8String(
    isolate: *v8.Isolate,
    value: runtime.DOMString,
) *v8.String {
    // Get string slice from DOMString
    const slice = switch (value) {
        .empty => "",
        .interned => |s| s,
        .owned => |s| s,
    };

    if (slice.len == 0) {
        return v8.v8_String_Empty(isolate) orelse {
            // Fallback if Empty fails
            return v8.v8_String_NewFromUtf8(isolate, "".ptr, 0).?;
        };
    }

    return v8.v8_String_NewFromUtf8(
        isolate,
        slice.ptr,
        @intCast(slice.len),
    ) orelse {
        // Fallback to empty string if creation fails
        return v8.v8_String_Empty(isolate).?;
    };
}

/// Convert Zig boolean to V8 Boolean
pub fn toV8Boolean(
    isolate: *v8.Isolate,
    value: runtime.Boolean,
) *v8.Boolean {
    // Use v8_Boolean_New to create a proper V8 Boolean
    const v8_bool = v8.v8_Boolean_New(isolate, value) orelse unreachable;
    return @ptrCast(v8_bool);
}

/// Convert Zig i32 (long) to V8 Number
pub fn toV8Long(
    isolate: *v8.Isolate,
    value: runtime.Long,
) *v8.Number {
    return v8.v8_Number_New(isolate, @floatFromInt(value));
}

/// Convert Zig u32 (unsigned long) to V8 Number
pub fn toV8UnsignedLong(
    isolate: *v8.Isolate,
    value: runtime.UnsignedLong,
) *v8.Number {
    return v8.v8_Number_New(isolate, @floatFromInt(value));
}

/// Convert Zig i64 (long long) to V8 Number
pub fn toV8LongLong(
    isolate: *v8.Isolate,
    value: runtime.LongLong,
) *v8.Number {
    return v8.v8_Number_New(isolate, @floatFromInt(value));
}

/// Convert Zig u64 (unsigned long long) to V8 Number
pub fn toV8UnsignedLongLong(
    isolate: *v8.Isolate,
    value: runtime.UnsignedLongLong,
) *v8.Number {
    return v8.v8_Number_New(isolate, @floatFromInt(value));
}

/// Convert Zig f64 (double) to V8 Number
pub fn toV8Double(
    isolate: *v8.Isolate,
    value: runtime.Double,
) *v8.Number {
    return v8.v8_Number_New(isolate, value);
}

/// Convert Zig f32 (float) to V8 Number
pub fn toV8Float(
    isolate: *v8.Isolate,
    value: runtime.Float,
) *v8.Number {
    return v8.v8_Number_New(isolate, @floatCast(value));
}

/// Convert runtime.Any (opaque pointer) to V8 Value
pub fn toV8Any(value: runtime.Any) *v8.Value {
    return @ptrCast(@alignCast(value));
}

/// Convert runtime.Object (opaque pointer) to V8 Object
pub fn toV8Object(value: runtime.Object) *v8.Object {
    return @ptrCast(@alignCast(value));
}

/// Convert Zig undefined to V8 Undefined
pub fn toV8Undefined(isolate: *v8.Isolate) *v8.Value {
    return v8.v8_Undefined(isolate) orelse unreachable; // Undefined always succeeds
}

/// Convert Zig null to V8 Null
pub fn toV8Null(isolate: *v8.Isolate) *v8.Value {
    return v8.v8_Null(isolate) orelse unreachable; // Null always succeeds
}

/// Convert Zig enum to V8 String (for WebIDL enums)
/// Strips leading/trailing underscores from enum field names (used for reserved words)
/// Converts internal underscores to hyphens (WebIDL values like "same-origin" become _same_origin_ in Zig)
pub fn enumToV8String(comptime T: type, isolate: *v8.Isolate, value: T) *v8.Value {
    // Get the tag name at runtime
    const tag_name = @tagName(value);

    // Strip leading/trailing underscores
    var name: []const u8 = tag_name;
    if (name.len > 0 and name[0] == '_') name = name[1..];
    if (name.len > 0 and name[name.len - 1] == '_') name = name[0 .. name.len - 1];

    // Convert internal underscores to hyphens
    // WebIDL enum values like "same-origin" are stored as _same_origin_ in Zig
    var buffer: [256]u8 = undefined;
    if (name.len <= buffer.len) {
        for (name, 0..) |c, i| {
            buffer[i] = if (c == '_') '-' else c;
        }
        if (v8.v8_String_NewFromUtf8(isolate, &buffer, @intCast(name.len))) |str| {
            return @ptrCast(str);
        }
    } else {
        // Fallback for very long names (shouldn't happen in practice)
        if (v8.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len))) |str| {
            return @ptrCast(str);
        }
    }
    return v8.v8_Undefined(isolate) orelse unreachable;
}

/// Convert Zig sequence to V8 Array
pub fn toV8Sequence(
    comptime T: type,
    isolate: *v8.Isolate,
    context: *v8.Context,
    slice: []const T,
) ConversionError!*v8.Array {
    const array = v8.v8_Array_New(isolate, @intCast(slice.len));

    for (slice, 0..) |item, i| {
        const v8_value = try toV8Value(T, isolate, context, item);
        _ = v8.v8_Array_Set(array, context, @intCast(i), v8_value);
    }

    return array;
}

/// Convert WebIDL record<K,V> to V8 Object
pub fn toV8Record(
    comptime K: type,
    comptime V: type,
    isolate: *v8.Isolate,
    context: *v8.Context,
    rec: runtime.record(K, V),
) ConversionError!*v8.Object {
    const object = v8.v8_Object_New(isolate);

    for (rec.entries) |entry| {
        const key_str = if (K == runtime.DOMString)
            toV8String(isolate, entry.key)
        else
            // For ByteString/USVString, convert to string
            // TODO: Proper conversion for different string types
            toV8String(isolate, runtime.DOMString.initOwned(entry.key));

        const value_v8 = try toV8Value(V, isolate, context, entry.value);
        _ = v8.v8_Object_Set(object, context, @ptrCast(key_str), value_v8);
    }

    return object;
}

/// Generic Zig type to V8 Value conversion
///
/// Dispatches to the appropriate conversion function based on source type.
pub fn toV8Value(
    comptime T: type,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: T,
) ConversionError!*v8.Value {
    // Handle optional types (nullable)
    const type_info = @typeInfo(T);
    if (type_info == .optional) {
        if (value) |v| {
            // Recursively convert the child value
            const ChildType = type_info.optional.child;
            return try toV8Value(ChildType, isolate, context, v);
        } else {
            // null becomes V8 Null
            return toV8Null(isolate);
        }
    }

    // Handle error unions
    if (type_info == .error_union) {
        const unwrapped = value catch |err| {
            // Convert error to V8 exception
            const err_name = @errorName(err);
            const err_msg = v8.v8_String_NewFromUtf8(isolate, err_name.ptr, @intCast(err_name.len)) orelse {
                // Fallback to generic error if string creation fails
                const fallback = v8.v8_String_NewFromUtf8(isolate, "Error".ptr, 5).?;
                return @ptrCast(v8.v8_Exception_Error(fallback));
            };
            return @ptrCast(v8.v8_Exception_Error(err_msg));
        };
        const PayloadType = type_info.error_union.payload;
        return try toV8Value(PayloadType, isolate, context, unwrapped);
    }

    // Handle slices (sequence<T>)
    if (type_info == .pointer and type_info.pointer.size == .slice) {
        const ElemType = type_info.pointer.child;
        // Special case: []const u8 and []u8 are strings, not arrays
        if (ElemType == u8) {
            const str = v8.v8_String_NewFromUtf8(isolate, value.ptr, @intCast(value.len));
            return @ptrCast(str);
        }
        return @ptrCast(try toV8Sequence(ElemType, isolate, context, value));
    }

    // Handle integers (all sizes, signed and unsigned)
    if (type_info == .int) {
        const num = v8.v8_Number_New(isolate, @floatFromInt(value));
        return @ptrCast(num);
    }

    // Handle floats (f32, f64, etc.)
    if (type_info == .float) {
        const num = v8.v8_Number_New(isolate, @floatCast(value));
        return @ptrCast(num);
    }

    // Handle booleans
    if (type_info == .bool or T == bool) {
        return @ptrCast(toV8Boolean(isolate, value));
    }

    // Handle enums (convert to string for WebIDL compatibility)
    if (type_info == .@"enum") {
        // Get the enum field name and convert to string
        // WebIDL enums are represented as strings in JavaScript
        const fields = std.meta.fields(T);
        const enum_int: usize = @intFromEnum(value);
        if (enum_int < fields.len) {
            // Get the field name and strip leading/trailing underscores (used for reserved words)
            var name = fields[enum_int].name;
            // Strip leading underscore if present (e.g., "_open_" -> "open_")
            if (name.len > 0 and name[0] == '_') {
                name = name[1..];
            }
            // Strip trailing underscore if present (e.g., "open_" -> "open")
            if (name.len > 0 and name[name.len - 1] == '_') {
                name = name[0 .. name.len - 1];
            }
            const str = v8.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse {
                return toV8Undefined(isolate);
            };
            return @ptrCast(str);
        }
        // Fallback to integer for out-of-range values
        const num = v8.v8_Number_New(isolate, @floatFromInt(enum_int));
        return @ptrCast(num);
    }

    // Handle structs (convert to V8 object with fields)
    if (type_info == .@"struct") {
        const obj = v8.v8_Object_New(isolate) orelse return ConversionError.OutOfMemory;
        inline for (std.meta.fields(T)) |field| {
            if (v8.v8_String_NewFromUtf8(
                isolate,
                field.name.ptr,
                @intCast(field.name.len),
            )) |field_name_str| {
                const field_value = @field(value, field.name);
                const field_v8 = try toV8Value(field.type, isolate, context, field_value);
                _ = v8.v8_Object_Set(obj, context, @ptrCast(field_name_str), field_v8);
            }
        }
        return @ptrCast(obj);
    }

    // Handle unions (convert active field to V8)
    if (type_info == .@"union") {
        const union_info = type_info.@"union";
        const fields = union_info.fields;

        // Use inline switch to dispatch on active field at runtime
        inline for (fields) |field| {
            if (std.mem.eql(u8, @tagName(value), field.name)) {
                const field_value = @field(value, field.name);

                // Special case: *const anyopaque and *anyopaque are wrapped interface instances
                // These need to be converted back to V8 objects using instanceToV8
                if (field.type == *const anyopaque or field.type == *anyopaque) {
                    // The anyopaque pointer is actually a *runtime.Instance
                    const instance: *runtime.Instance = @ptrCast(@alignCast(@constCast(field_value)));
                    return instanceToV8(isolate, instance);
                }

                // For other types, recursively convert
                return try toV8Value(field.type, isolate, context, field_value);
            }
        }

        // No active field found (shouldn't happen with valid union)
        return toV8Undefined(isolate);
    }

    // Handle void (return undefined)
    if (T == void) {
        return toV8Undefined(isolate);
    }

    // Handle CallbackWrapper types (EventHandler, etc.)
    // Extract the V8 Function from the wrapper for getters
    if (T == *runtime.CallbackWrapper) {
        // Cast to V8-specific CallbackWrapper to access the V8 function
        const v8_wrapper: *callback_wrapper.CallbackWrapper = @ptrCast(@alignCast(value));
        if (v8_wrapper.callback_function) |func| {
            return @ptrCast(func);
        }
        // If no function stored, return undefined
        return toV8Undefined(isolate);
    }

    // Handle pointers (convert to Any)
    if (type_info == .pointer) {
        return toV8Any(@ptrCast(@constCast(value)));
    }

    // Handle WebIDL primitive types with explicit conversion functions
    // Note: Most types should be handled by the checks above (int, float, bool, enum, struct, pointer, etc.)
    // This switch only catches specific runtime types that need special handling
    if (T == runtime.Boolean) return @ptrCast(toV8Boolean(isolate, value));
    if (T == runtime.Long) return @ptrCast(toV8Long(isolate, value));
    if (T == runtime.UnsignedLong) return @ptrCast(toV8UnsignedLong(isolate, value));
    if (T == runtime.LongLong) return @ptrCast(toV8LongLong(isolate, value));
    if (T == runtime.UnsignedLongLong) return @ptrCast(toV8UnsignedLongLong(isolate, value));
    if (T == u64) return @ptrCast(toV8UnsignedLongLong(isolate, value));
    if (T == runtime.Double) return @ptrCast(toV8Double(isolate, value));
    if (T == runtime.Float) return @ptrCast(toV8Float(isolate, value));
    if (T == runtime.DOMString) return @ptrCast(toV8String(isolate, value));
    if (T == runtime.Any) return toV8Any(value);

    // If we get here, it's an unsupported type that wasn't handled by any of the above cases
    // This should be rare - most types are covered by generic handlers (int, float, struct, pointer, etc.)
    @compileError("Unsupported type for V8 conversion: " ++ @typeName(T) ++
        ". If this is a struct, make sure it's being handled by the struct case above.");
}

// ============================================================================
// Argument Extraction Helpers
// ============================================================================

/// Extract and convert function arguments from V8 callback info
///
/// This is a convenience function for extracting multiple arguments at once.
/// Returns a tuple of converted arguments matching the parameter types.
///
/// Example:
/// ```zig
/// const args = try extractArgs(
///     .{ runtime.DOMString, runtime.Long, runtime.Boolean },
///     allocator,
///     info,
/// );
/// defer allocator.free(args[0]); // Free DOMString if owned
///
/// const label = args[0];
/// const count = args[1];
/// const enabled = args[2];
/// ```
pub fn extractArgs(
    comptime Types: anytype,
    allocator: std.mem.Allocator,
    info: *const v8.FunctionCallbackInfo,
) ConversionError!Types {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate);
    const length = info.length();

    const type_info = @typeInfo(@TypeOf(Types));
    if (type_info != .Struct or !type_info.Struct.is_tuple) {
        @compileError("Types must be a tuple of types");
    }

    const fields = type_info.Struct.fields;
    var result: Types = undefined;

    inline for (fields, 0..) |field, i| {
        if (i >= length) {
            // Not enough arguments provided
            return ConversionError.TypeError;
        }

        const v8_value = info.get(@intCast(i));
        result[i] = try fromV8Value(
            field.type,
            allocator,
            isolate,
            context,
            v8_value,
        );
    }

    return result;
}

/// Check if V8 argument at index exists and is not undefined
pub fn hasArgument(info: *const v8.FunctionCallbackInfo, index: c_int) bool {
    if (index >= info.length()) {
        return false;
    }
    const value = info.get(index);
    return !v8.v8_Value_IsUndefined(value);
}

/// Get optional argument with default value
pub fn getOptionalArg(
    comptime T: type,
    allocator: std.mem.Allocator,
    info: *const v8.FunctionCallbackInfo,
    index: c_int,
    default: T,
) ConversionError!T {
    if (!hasArgument(info, index)) {
        return default;
    }

    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate);
    const v8_value = info.get(index);

    return try fromV8Value(T, allocator, isolate, context, v8_value);
}

// ============================================================================
// Return Value Helpers
// ============================================================================

/// Set return value for V8 callback
///
/// Converts Zig value to V8 and sets it as the return value of the callback.
pub fn setReturnValue(
    comptime T: type,
    info: *const v8.FunctionCallbackInfo,
    value: T,
) ConversionError!void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate).?;
    const v8_value = try toV8Value(T, isolate, context, value);
    info.setReturnValue(v8_value);
}

/// Set undefined as return value
pub fn setReturnUndefined(info: *const v8.FunctionCallbackInfo) void {
    const isolate = info.getIsolate();
    const v8_value = toV8Undefined(isolate);
    info.setReturnValue(v8_value);
}

/// Set null as return value
pub fn setReturnNull(info: *const v8.FunctionCallbackInfo) void {
    const isolate = info.getIsolate();
    const v8_value = toV8Null(isolate);
    info.setReturnValue(v8_value);
}

// ============================================================================
// Exception Helpers
// ============================================================================

/// Throw a TypeError in V8
pub fn throwTypeError(
    isolate: *v8.Isolate,
    message: []const u8,
) void {
    // Log error through context if available
    if (namespace.getGlobalContext()) |ctx| {
        ctx.logger.@"error"("V8 TypeError: {s}", .{message}) catch {};
    }

    const msg_str = v8.v8_String_NewFromUtf8(
        isolate,
        message.ptr,
        @intCast(message.len),
    ) orelse return; // Failed to create string, can't throw
    const exception = v8.v8_Exception_TypeError(msg_str) orelse return; // Failed to create exception
    v8.v8_Isolate_ThrowException(isolate, exception);
}

/// Throw a RangeError in V8
pub fn throwRangeError(
    isolate: *v8.Isolate,
    message: []const u8,
) void {
    // Log error through context if available
    if (namespace.getGlobalContext()) |ctx| {
        ctx.logger.@"error"("V8 RangeError: {s}", .{message}) catch {};
    }

    const msg_str = v8.v8_String_NewFromUtf8(
        isolate,
        message.ptr,
        @intCast(message.len),
    ) orelse return; // Failed to create string, can't throw
    const exception = v8.v8_Exception_RangeError(msg_str) orelse return;
    v8.v8_Isolate_ThrowException(isolate, exception);
}

/// Throw a generic Error in V8
pub fn throwError(
    isolate: *v8.Isolate,
    message: []const u8,
) void {
    // Log error through context if available
    if (namespace.getGlobalContext()) |ctx| {
        ctx.logger.@"error"("V8 Error: {s}", .{message}) catch {};
    }

    const msg_str = v8.v8_String_NewFromUtf8(
        isolate,
        message.ptr,
        @intCast(message.len),
    );
    const exception = v8.v8_Exception_Error(msg_str.?) orelse return;
    v8.v8_Isolate_ThrowException(isolate, exception);
}

// ============================================================================
// Console Value Conversion
// ============================================================================

/// Convert V8 Value to ConsoleValue for console logging
///
/// This function inspects the V8 value type and creates an appropriate
/// ConsoleValue representation. Strings and BigInts allocate memory that
/// must be freed by calling ConsoleValue.deinit().
pub fn toConsoleValue(
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!runtime.ConsoleValue {
    // Check type and convert accordingly

    // Undefined
    if (v8.v8_Value_IsUndefined(value)) {
        return runtime.ConsoleValue{ .undefined = {} };
    }

    // Null
    if (v8.v8_Value_IsNull(value)) {
        return runtime.ConsoleValue{ .null = {} };
    }

    // Boolean
    if (v8.v8_Value_IsBoolean(value)) {
        const bool_val = v8.v8_Value_BooleanValue(value, isolate);
        return runtime.ConsoleValue{ .boolean = bool_val };
    }

    // Number
    if (v8.v8_Value_IsNumber(value)) {
        const num_val = v8.v8_Value_NumberValue(value, context);
        return runtime.ConsoleValue{ .number = num_val };
    }

    // String
    if (v8.v8_Value_IsString(value)) {
        const string = v8.v8_Value_ToString(value, context) orelse return ConversionError.TypeError;

        // Get string length
        const length = v8.v8_String_Utf8Length(string);

        // Allocate buffer
        const buffer = try allocator.alloc(u8, @intCast(length));
        errdefer allocator.free(buffer);

        // Write UTF-8 to buffer
        _ = v8.v8_String_WriteUtf8(string, buffer.ptr, @intCast(length));

        return runtime.ConsoleValue{ .string = buffer };
    }

    // Symbol
    if (v8.v8_Value_IsSymbol(value)) {
        return runtime.ConsoleValue{ .symbol = @ptrCast(value) };
    }

    // BigInt (convert to string representation)
    if (v8.v8_Value_IsBigInt(value)) {
        // For now, return placeholder
        // TODO: Implement BigInt to string conversion
        const bigint_str = try allocator.dupe(u8, "0");
        return runtime.ConsoleValue{ .bigint = bigint_str };
    }

    // Everything else is an Object
    return runtime.ConsoleValue{ .object = @ptrCast(value) };
}

// ============================================================================
// Instance to V8 Object Conversion (Phase 5: Streams Integration)
// ============================================================================

/// Convert runtime.Instance to V8 Object
///
/// This creates or retrieves a V8 wrapper object for a Zig runtime instance.
/// Used when passing controller instances to JavaScript callbacks.
///
/// Currently simplified: creates a plain V8 Object.
/// TODO: Use full V8Interface infrastructure for proper prototype chain.
///
/// Example:
/// ```zig
/// const controller_v8 = try instanceToV8Object(
///     controller_instance,
///     isolate,
///     context,
/// );
/// defer v8.v8_Object_Dispose(controller_v8);
/// ```
pub fn instanceToV8Object(
    instance: *runtime.Instance,
    isolate: *v8.Isolate,
    context: *v8.Context,
) ConversionError!*v8.Object {
    _ = instance; // TODO: Use instance state to populate V8 object

    // For now, create a plain V8 Object
    // In a full implementation, this would:
    // 1. Check if instance already has a V8 wrapper (stored in internal field)
    // 2. If not, create V8 Object with correct prototype
    // 3. Store instance pointer in V8 Object internal field
    // 4. Store V8 Object reference in instance for future lookups

    const obj = v8.v8_Object_New(isolate) orelse return ConversionError.OutOfMemory;
    _ = context; // Will be needed for property setup

    // TODO: Set up properties and methods using V8Interface infrastructure
    // For now, return plain object (sufficient for callbacks that don't access controller)

    return obj;
}

/// Convert runtime.Instance to V8 Value with correct prototype chain
///
/// This is the preferred function for returning interface instances from
/// property getters and methods. It uses the template registry to wrap
/// the instance with the correct V8 prototype chain.
///
/// Unlike instanceToV8Object (which creates a plain object), this function:
/// 1. Looks up the interface name from the instance's vtable
/// 2. Wraps the instance with the correct FunctionTemplate
/// 3. Returns a cached wrapper if one exists (preserving object identity)
///
/// Example:
/// ```zig
/// // In a property getter returning *runtime.Instance:
/// const v8_value = conv.instanceToV8(isolate, instance);
/// info.setReturnValue(v8_value);
/// ```
pub fn instanceToV8(isolate: *v8.Isolate, instance: *runtime.Instance) *v8.Value {
    const template_registry = @import("template_registry.zig");

    // Get interface name from instance vtable
    const interface_name = template_registry.getInstanceInterfaceName(instance);

    // Get current context
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        // No context available, return undefined
        return v8.v8_Undefined(isolate) orelse unreachable;
    };

    // Wrap with correct prototype using template registry
    const v8_obj = template_registry.wrapInstanceAsV8Object(
        instance,
        interface_name,
        isolate,
        context,
    ) catch {
        // Template not registered or other error, return undefined
        return v8.v8_Undefined(isolate) orelse unreachable;
    };

    return @ptrCast(v8_obj);
}

/// Chunk type tag for type-safe chunk conversion
///
/// When passing chunks through Streams, we wrap them in this tagged union
/// to preserve type information. This avoids unsafe type punning.
pub const ChunkType = enum {
    v8_value, // Already a V8 Value
    instance, // runtime.Instance
    string, // []const u8
    number_f64, // f64
    number_i32, // i32
    boolean, // bool
    undefined_type, // Explicitly undefined
};

/// Type-safe chunk wrapper
///
/// Use this when passing chunks through Streams to preserve type information.
pub const Chunk = union(ChunkType) {
    v8_value: *v8.Value,
    instance: *runtime.Instance,
    string: []const u8,
    number_f64: f64,
    number_i32: i32,
    boolean: bool,
    undefined_type: void,
};

/// Convert a type-safe Chunk to V8 Value
///
/// This is the preferred way to convert chunks - type-safe and explicit.
///
/// Example:
/// ```zig
/// const chunk = Chunk{ .string = "hello" };
/// const chunk_v8 = try chunkToV8ValueSafe(chunk, isolate, context);
/// defer v8.v8_Value_Dispose(chunk_v8);
/// ```
pub fn chunkToV8ValueSafe(
    chunk: Chunk,
    isolate: *v8.Isolate,
    context: *v8.Context,
) ConversionError!*v8.Value {
    return switch (chunk) {
        .v8_value => |v| v,

        .instance => |inst| blk: {
            const obj = try instanceToV8Object(inst, isolate, context);
            break :blk @ptrCast(obj);
        },

        .string => |str| blk: {
            const v8_str = v8.v8_String_NewFromUtf8(
                isolate,
                str.ptr,
                @intCast(str.len),
            ) orelse return ConversionError.OutOfMemory;
            break :blk @ptrCast(v8_str);
        },

        .number_f64 => |num| blk: {
            const v8_num = v8.v8_Number_New(isolate, num);
            break :blk @ptrCast(v8_num);
        },

        .number_i32 => |num| blk: {
            const v8_num = v8.v8_Number_New(isolate, @floatFromInt(num));
            break :blk @ptrCast(v8_num);
        },

        .boolean => |b| blk: {
            // TODO: Implement v8_Boolean_New in v8_wrapper.cpp
            // For now, use number conversion (0/1) cast to boolean
            const num_val: f64 = if (b) 1.0 else 0.0;
            const v8_num = v8.v8_Number_New(isolate, num_val);
            break :blk @ptrCast(v8_num);
        },

        .undefined_type => blk: {
            _ = chunk.undefined_type;
            const undef = v8.v8_Undefined(isolate) orelse
                return ConversionError.OutOfMemory;
            break :blk undef;
        },
    };
}

/// Convert an opaque chunk pointer to a V8 Value (legacy/unsafe)
///
/// **DEPRECATED**: Use chunkToV8ValueSafe() with Chunk union instead.
///
/// This function attempts to guess the chunk type from an opaque pointer,
/// which is inherently unsafe. It's kept for backward compatibility but
/// should be replaced with the type-safe Chunk approach.
///
/// Example:
/// ```zig
/// const chunk_v8 = try chunkToV8Value(
///     chunk_ptr,
///     isolate,
///     context,
/// );
/// defer v8.v8_Value_Dispose(chunk_v8);
/// ```
pub fn chunkToV8Value(
    chunk: *const anyopaque,
    isolate: *v8.Isolate,
    context: *v8.Context,
) ConversionError!*v8.Value {
    _ = chunk;
    _ = context;

    // Without type information, we can't safely convert
    // Return undefined as safe fallback
    //
    // TODO: Migrate call sites to use Chunk union + chunkToV8ValueSafe()

    const undef = v8.v8_Undefined(isolate) orelse return ConversionError.OutOfMemory;
    return undef;
}

// ============================================================================
// Generic Conversion Functions
// ============================================================================

/// Generic Zig to V8 value conversion
///
/// Handles conversion of common Zig types to V8 values.
/// Used by Promise.resolve() and other generic APIs.
///
/// Supported types:
/// - void: converts to undefined
/// - bool: converts to V8 Boolean
/// - integers: convert to V8 Number
/// - floats: convert to V8 Number
/// - []const u8 / DOMString: convert to V8 String
/// - *anyopaque: returns as-is (assumes already a V8 Value)
/// - structs with value/done fields: creates iterator result object
pub fn toV8(
    comptime T: type,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: T,
) ConversionError!*v8.Value {
    const info = @typeInfo(T);

    switch (info) {
        .void => {
            return v8.v8_Undefined(isolate) orelse return ConversionError.OutOfMemory;
        },
        .bool => {
            return toV8Boolean(isolate, value);
        },
        .int, .comptime_int => {
            const float_val: f64 = @floatFromInt(value);
            return @ptrCast(v8.v8_Number_New(isolate, float_val) orelse return ConversionError.OutOfMemory);
        },
        .float, .comptime_float => {
            return @ptrCast(v8.v8_Number_New(isolate, @floatCast(value)) orelse return ConversionError.OutOfMemory);
        },
        .pointer => |ptr_info| {
            if (ptr_info.size == .slice and ptr_info.child == u8) {
                // []const u8 - convert to string
                return @ptrCast(v8.v8_String_NewFromUtf8(
                    isolate,
                    value.ptr,
                    @intCast(value.len),
                ) orelse return ConversionError.OutOfMemory);
            } else if (ptr_info.child == anyopaque) {
                // *anyopaque - assume it's already a V8 value pointer
                return @ptrCast(value);
            } else {
                // Unsupported pointer type
                return ConversionError.TypeError;
            }
        },
        .@"struct" => {
            // Check if it's an IteratorResult-like struct
            if (@hasField(T, "value") and @hasField(T, "done")) {
                // Create { value: X, done: Y } object
                const obj = v8.v8_Object_New(isolate) orelse return ConversionError.OutOfMemory;

                // Set "done" property
                const done_key = v8.v8_String_NewFromUtf8(isolate, "done", 4) orelse
                    return ConversionError.OutOfMemory;
                const done_value: *v8.Value = @ptrCast(toV8Boolean(isolate, value.done));
                _ = v8.v8_Object_Set(obj, context, @ptrCast(done_key), done_value);

                // Set "value" property
                const value_key = v8.v8_String_NewFromUtf8(isolate, "value", 5) orelse
                    return ConversionError.OutOfMemory;

                // Value is ?*anyopaque, convert appropriately
                const value_v8: *v8.Value = if (value.value) |v|
                    @ptrCast(v)
                else
                    v8.v8_Undefined(isolate) orelse return ConversionError.OutOfMemory;

                _ = v8.v8_Object_Set(obj, context, @ptrCast(value_key), value_v8);

                return @ptrCast(obj);
            }
            return ConversionError.TypeError;
        },
        .optional => |opt_info| {
            if (value) |v| {
                return toV8(opt_info.child, isolate, context, v);
            } else {
                return v8.v8_Null(isolate) orelse return ConversionError.OutOfMemory;
            }
        },
        else => {
            return ConversionError.TypeError;
        },
    }
}

// ============================================================================
// V8 Value Type Detection (for external JSValue conversion)
// ============================================================================

/// V8 value type tag (used by callers to build their own JSValue)
///
/// This allows modules with JSValue access to convert V8 values without
/// this module needing to import streams_common (avoiding circular deps).
pub const V8ValueType = enum {
    undefined,
    null_type,
    boolean,
    number,
    string,
    object,
    typed_array,
    other,
};

/// Detect the type of a V8 Value
///
/// Returns a type tag that callers can use to build JSValue or other types.
pub fn detectV8ValueType(value: *v8.Value) V8ValueType {
    if (v8.v8_Value_IsUndefined(value)) return .undefined;
    if (v8.v8_Value_IsNull(value)) return .null_type;
    if (v8.v8_Value_IsBoolean(value)) return .boolean;
    if (v8.v8_Value_IsNumber(value)) return .number;
    if (v8.v8_Value_IsString(value)) return .string;
    if (v8.v8_Value_IsTypedArray(value)) return .typed_array;
    if (v8.v8_Value_IsObject(value)) return .object;
    return .other;
}

/// Extract boolean value from V8 Value
pub fn extractV8Boolean(isolate: *v8.Isolate, value: *v8.Value) bool {
    return v8.v8_Value_BooleanValue(value, isolate);
}

/// Extract number value from V8 Value
pub fn extractV8Number(context: *v8.Context, value: *v8.Value) f64 {
    return v8.v8_Value_NumberValue(value, context);
}

/// Extract string from V8 Value (allocates)
pub fn extractV8StringAlloc(
    allocator: std.mem.Allocator,
    context: *v8.Context,
    value: *v8.Value,
) ConversionError![]u8 {
    const str = v8.v8_Value_ToString(value, context) orelse return ConversionError.StringError;
    defer v8.v8_String_Dispose(str);

    const length = v8.v8_String_Utf8Length(str);
    if (length < 0) return ConversionError.StringError;

    if (length == 0) {
        return &[_]u8{};
    }

    const buffer = try allocator.alloc(u8, @intCast(length));
    errdefer allocator.free(buffer);

    const written = v8.v8_String_WriteUtf8(str, buffer.ptr, @intCast(length));
    if (written != length) {
        return ConversionError.StringError;
    }

    return buffer;
}

/// Create V8 undefined value
pub fn createV8Undefined(isolate: *v8.Isolate) ConversionError!*v8.Value {
    return v8.v8_Undefined(isolate) orelse return ConversionError.OutOfMemory;
}

/// Create V8 null value
pub fn createV8Null(isolate: *v8.Isolate) ConversionError!*v8.Value {
    return v8.v8_Null(isolate) orelse return ConversionError.OutOfMemory;
}

/// Create V8 boolean value
pub fn createV8Boolean(isolate: *v8.Isolate, value: bool) ConversionError!*v8.Value {
    return v8.v8_Boolean_New(isolate, value) orelse return ConversionError.OutOfMemory;
}

/// Create V8 number value
pub fn createV8Number(isolate: *v8.Isolate, value: f64) ConversionError!*v8.Value {
    return @ptrCast(v8.v8_Number_New(isolate, value));
}

/// Create V8 string value from slice
pub fn createV8String(isolate: *v8.Isolate, value: []const u8) ConversionError!*v8.Value {
    const str = v8.v8_String_NewFromUtf8(isolate, value.ptr, @intCast(value.len)) orelse
        return ConversionError.OutOfMemory;
    return @ptrCast(str);
}

// ============================================================================
// Tests
// ============================================================================

test "conversion module compiles" {
    const testing = std.testing;
    testing.refAllDecls(@This());
}
