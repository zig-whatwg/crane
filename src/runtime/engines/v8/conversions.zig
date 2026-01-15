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
const debug = @import("debug.zig");
const v8 = @import("ffi.zig");
const runtime = @import("runtime");
const namespace = @import("namespace.zig");
const interface_mod = @import("interface.zig");
const dom_type_info = @import("dom_type_info.zig");
const callback_wrapper = @import("callback_wrapper.zig");
const callback_registry = @import("callback_registry.zig");
const engine_mod = @import("engine.zig");
const typedefs = @import("typedefs");
const js_value_mod = @import("js_value.zig");
const pointer_tag = @import("pointer_tag.zig");
const DebugAssertions = pointer_tag.DebugAssertions;
const global_handles = @import("global_handles.zig");

/// Type-safe JavaScript value representation
pub const JSValue = js_value_mod.JSValue;

/// Optional JSValue for WebIDL optional parameters
pub const OptionalJSValue = js_value_mod.OptionalJSValue;

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

    /// Failed to create a V8 Global handle for persistent storage
    GlobalHandleCreationFailed,

    /// A JavaScript exception is already pending in V8 (rethrown from conversion)
    /// When this error is returned, the caller should NOT throw another exception
    ExceptionPending,
};

// ============================================================================
// Helper Functions
// ============================================================================

/// Check if a runtime enum name matches a comptime Zig enum field name.
/// Handles the transformation from WebIDL format ("same-origin", "text/html") to Zig format ("_same_origin_", "_text_html_"):
/// - Hyphens in the runtime name match underscores in the field name
/// - Slashes in the runtime name match underscores in the field name (e.g., "text/html" -> "text_html")
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

    // Compare character by character, treating hyphens and slashes as underscores
    inline for (normalized_field, 0..) |fc, i| {
        const rc = runtime_name[i];
        // Field char is underscore, runtime char can be underscore, hyphen, or slash
        if (fc == '_') {
            if (rc != '_' and rc != '-' and rc != '/') return false;
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

/// Convert V8 Value to JSValue (type-safe)
///
/// This is the preferred way to convert V8 values for WebIDL 'any' type.
/// Unlike fromV8Any, this preserves type information and eliminates the need
/// for unsafe pointer tagging or sentinel values.
///
/// ## Return Values
/// - Primitives (undefined, null, boolean, number) are stored directly
/// - Wrapped Zig instances return `.instance` variant
/// - Functions and objects needing persistence return `.global` variant
/// - Other values return `.local` variant (temporary, scope-bound)
///
/// ## Example
/// ```zig
/// const js_value = try fromV8ValueTyped(v8_value, isolate, context);
/// defer js_value.deinit(allocator); // Clean up if needed
///
/// switch (js_value) {
///     .undefined_value => // handle undefined,
///     .instance => |inst| // use Zig instance,
///     .global => |g| // use V8 object/function,
///     // ...
/// }
/// ```
pub fn fromV8ValueTyped(
    value: *v8.Value,
    isolate: *v8.Isolate,
    context: *v8.Context,
) ConversionError!JSValue {
    // Check for undefined
    if (v8.v8_Value_IsUndefined(value)) {
        return JSValue.jsUndefined;
    }

    // Check for null
    if (v8.v8_Value_IsNull(value)) {
        return JSValue.jsNull;
    }

    // Check for boolean (optimize: no allocation needed)
    if (v8.v8_Value_IsBoolean(value)) {
        return JSValue.fromBoolean(v8.v8_Value_BooleanValue(value, isolate));
    }

    // Check for number (optimize: no allocation needed)
    if (v8.v8_Value_IsNumber(value)) {
        return JSValue.fromNumber(v8.v8_Value_NumberValue(value, context));
    }

    // Check for object/function - look for wrapped Zig instance first
    if (v8.v8_Value_IsObject(value)) {
        const obj: *v8.Object = @ptrCast(value);
        const field_count = v8.v8_Object_InternalFieldCount(obj);

        // Check if this V8 object wraps a Zig instance
        if (field_count > 0) {
            if (v8.v8_Object_GetAlignedPointerFromInternalField(obj, 0)) |internal_ptr| {
                // This is a wrapped Zig instance - return it directly
                const instance: *runtime.Instance = @ptrCast(@alignCast(internal_ptr));
                return JSValue.fromInstance(instance);
            }
        }

        // Not a wrapped instance - the value IS already a Global handle
        // (from v8_FunctionCallbackInfo_GetArgument which creates and tracks a Global)
        // Just use it directly - no need to call v8_Value_ToGlobal
        return JSValue.fromGlobal(@ptrCast(value));
    }

    // For other values (strings, etc.) - return as local handle
    // NOTE: Local handles are only valid within the current HandleScope!
    return JSValue.fromLocal(value);
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
        // Use v8_Object_Get with integer key instead of v8_Array_Get to properly
        // walk the prototype chain for holey arrays. Per WebIDL spec, sequence
        // conversion must use [[Get]] which includes prototype lookup.
        const index_key = v8.v8_Integer_New(isolate, @intCast(i));
        const v8_value = v8.v8_Object_Get(@ptrCast(array), context, @ptrCast(index_key)) orelse continue;
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
/// HeadersInit = (sequence<sequence<ByteString>> or record<ByteString, ByteString>)
fn convertHeadersInit(
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!typedefs.HeadersInit {
    _ = isolate; // Used only for potential future error reporting

    // Check if it's an array (sequence<sequence<ByteString>>)
    // Format: [["key1", "value1"], ["key2", "value2"]]
    if (v8.v8_Value_IsArray(value)) {
        const array = @as(*v8.Array, @ptrCast(value));
        const length = v8.v8_Array_Length(array);

        // Allocate array of inner sequences (each inner sequence is []const ByteString)
        const outer_seq = try allocator.alloc([]const runtime.ByteString, length);
        errdefer allocator.free(outer_seq);

        for (0..length) |i| {
            const elem = v8.v8_Array_Get(context, array, @intCast(i)) orelse {
                // Empty inner sequence
                outer_seq[i] = &.{};
                continue;
            };

            // Each element should be an array of [key, value]
            if (!v8.v8_Value_IsArray(elem)) {
                outer_seq[i] = &.{};
                continue;
            }

            const pair_array = @as(*v8.Array, @ptrCast(elem));
            const pair_len = v8.v8_Array_Length(pair_array);

            // Allocate inner sequence
            const inner_seq = try allocator.alloc(runtime.ByteString, pair_len);
            errdefer allocator.free(inner_seq);

            for (0..pair_len) |j| {
                const item = v8.v8_Array_Get(context, pair_array, @intCast(j));
                if (item) |it| {
                    if (v8.v8_Value_IsSymbol_Local(@ptrCast(it))) {
                        return ConversionError.TypeError;
                    }
                    const str = v8.v8_Value_ToString(it, context);
                    if (str) |s| {
                        const len = v8.v8_String_Utf8Length(s);
                        if (len > 0) {
                            const buf = try allocator.alloc(u8, @intCast(len));
                            _ = v8.v8_String_WriteUtf8(s, buf.ptr, @intCast(len));
                            inner_seq[j] = buf;
                            continue;
                        } else if (len == 0) {
                            inner_seq[j] = "";
                            continue;
                        }
                    }
                }
                inner_seq[j] = ""; // Fallback for failed ToString
            }

            outer_seq[i] = inner_seq;
        }

        return .{ .sequence_byte_string_sequence = outer_seq };
    }

    // Check if it's an object (record<ByteString, ByteString>)
    // Format: { "key1": "value1", "key2": "value2" }
    if (v8.v8_Value_IsObject(value)) {
        const obj = @as(*v8.Object, @ptrCast(value));

        // Get OWN property names only (not inherited)
        const prop_names = v8.v8_Object_GetOwnPropertyNames(context, obj) orelse {
            // Empty record
            return .{ .byte_string_byte_string_record = &.{} };
        };

        const prop_count = v8.v8_Array_Length(prop_names);
        // Get the entry type from the typedef's union field
        const RecordSlice = @TypeOf(@as(typedefs.HeadersInit, undefined).byte_string_byte_string_record);
        const RecordEntry = std.meta.Elem(RecordSlice);
        const entries = try allocator.alloc(RecordEntry, prop_count);
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

            var val_str: runtime.ByteString = "";
            if (!v8.v8_Value_IsSymbol_Local(@ptrCast(prop_val))) {
                const str = v8.v8_Value_ToString(prop_val, context);
                if (str) |s| {
                    const len = v8.v8_String_Utf8Length(s);
                    if (len > 0) {
                        const buf = try allocator.alloc(u8, @intCast(len));
                        _ = v8.v8_String_WriteUtf8(s, buf.ptr, @intCast(len));
                        val_str = buf;
                    } else {
                        val_str = "";
                    }
                }
            }

            entries[valid_count] = .{
                .key = name_buf,
                .value = val_str,
            };
            valid_count += 1;
        }

        return .{ .byte_string_byte_string_record = entries[0..valid_count] };
    }

    // Fallback - return empty record for unsupported types
    return .{ .byte_string_byte_string_record = &.{} };
}

const buffer_sources = @import("webidl").buffer_sources;

/// Convert V8 TypedArray/DataView to AllowSharedBufferSource
///
/// WHATWG Encoding Standard § 5.1.4 - TextDecoder.decode() input parameter
/// typedef (ArrayBuffer or SharedArrayBuffer or [AllowShared] ArrayBufferView) AllowSharedBufferSource
///
/// This function creates a non-owning byte slice view into the V8 buffer data.
/// The V8 buffer remains valid during the synchronous decode operation, so no copy is needed.
/// IMPORTANT: The returned byte_slice is only valid during the current V8 call - do not
/// store it beyond the scope of the function call that triggered this conversion.
fn convertAllowSharedBufferSource(
    allocator: std.mem.Allocator,
    value: *v8.Value,
) ConversionError!typedefs.AllowSharedBufferSource {
    _ = allocator; // Not needed - we create a non-owning view

    // Check for TypedArray (Uint8Array, Int8Array, etc.) or DataView
    const is_typed_array = v8.v8_Value_IsTypedArray(value);
    const is_data_view = v8.v8_Value_IsDataView(value);

    if (is_typed_array or is_data_view) {
        // Get byte range from the view
        const byte_length = v8.v8_TypedArray_ByteLength(value);
        const byte_offset = v8.v8_TypedArray_ByteOffset(value);

        // Get the underlying ArrayBuffer from V8
        const v8_ab = v8.v8_TypedArray_Buffer(value) orelse {
            // Empty buffer - return empty byte slice
            return .{ .byte_slice = &[_]u8{} };
        };
        // NOTE: We do NOT dispose the V8 ArrayBuffer here because we're creating
        // a non-owning view into it. The buffer will be disposed by V8 GC after
        // the JS call completes.

        // Get raw data pointer from V8 ArrayBuffer
        const v8_data = v8.v8_ArrayBuffer_Data(v8_ab);
        if (v8_data == null or byte_length == 0) {
            return .{ .byte_slice = &[_]u8{} };
        }

        // Create a non-owning byte slice view directly into the V8 buffer
        // This is safe because:
        // 1. The V8 buffer remains valid during the synchronous decode call
        // 2. We're not storing this pointer beyond the current call scope
        const src_ptr = @as([*]const u8, @ptrCast(v8_data.?)) + byte_offset;
        return .{ .byte_slice = src_ptr[0..byte_length] };
    }

    // For null/undefined, return empty byte slice
    if (v8.v8_Value_IsNullOrUndefined(value)) {
        return .{ .byte_slice = &[_]u8{} };
    }

    // Unsupported type
    return ConversionError.TypeError;
}

/// Convert V8 value to BodyInit union
/// BodyInit = (ReadableStream or XMLHttpRequestBodyInit)
/// XMLHttpRequestBodyInit = (Blob or BufferSource or FormData or URLSearchParams or USVString)
fn convertBodyInit(
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!typedefs.BodyInit {
    _ = isolate; // Used only for potential future error reporting

    // Check for null/undefined - return empty USVString (preserving standard coercion)
    // NOTE: Fetch/XHR treat null body as no-body (empty), matching this behavior.
    if (v8.v8_Value_IsNullOrUndefined(value)) {
        // Use ToString() to be explicit and follow WebIDL §3.2.1
        const string = v8.v8_Value_ToString(value, context) orelse return ConversionError.TypeError;
        const length = v8.v8_String_Utf8Length(string);
        const buffer = try allocator.alloc(u8, @intCast(length));
        errdefer allocator.free(buffer);
        _ = v8.v8_String_WriteUtf8(string, buffer.ptr, @intCast(length));
        return .{ .xmlhttp_request_body_init = .{ .usvstring = buffer } };
    }

    // Check if it's a string (most common case: USVString)
    if (v8.v8_Value_IsString(value)) {
        const string = v8.v8_Value_ToString(value, context) orelse return ConversionError.TypeError;
        const length = v8.v8_String_Utf8Length(string);
        if (length <= 0) {
            return .{ .xmlhttp_request_body_init = .{ .usvstring = "" } };
        }

        const buffer = try allocator.alloc(u8, @intCast(length));
        errdefer allocator.free(buffer);
        const written = v8.v8_String_WriteUtf8(string, buffer.ptr, @intCast(length));
        if (written != length) {
            allocator.free(buffer);
            return ConversionError.StringError;
        }
        return .{ .xmlhttp_request_body_init = .{ .usvstring = buffer } };
    }

    // Check if it's a TypedArray (Uint8Array, etc.) - maps to BufferSource
    if (v8.v8_Value_IsTypedArray(value)) {
        const byte_length = v8.v8_TypedArray_ByteLength(value);

        if (byte_length == 0) {
            // Empty BufferSource - for now use an empty string as USVString fallback
            // TODO: Properly handle BufferSource typedef when it's fully implemented
            return .{ .xmlhttp_request_body_init = .{ .usvstring = "" } };
        }

        // Get the underlying ArrayBuffer and offset
        const ab = v8.v8_TypedArray_Buffer(value) orelse {
            return .{ .xmlhttp_request_body_init = .{ .usvstring = "" } };
        };
        const byte_offset = v8.v8_TypedArray_ByteOffset(value);
        const data = v8.v8_ArrayBuffer_Data(ab);

        if (data == null) {
            return .{ .xmlhttp_request_body_init = .{ .usvstring = "" } };
        }

        // Copy the data from the correct offset
        const buffer = try allocator.alloc(u8, byte_length);
        const src_ptr = @as([*]const u8, @ptrCast(data.?)) + byte_offset;
        @memcpy(buffer, src_ptr[0..byte_length]);

        // TODO: Return as BufferSource when typedef is properly implemented
        // For now, return as USVString (the buffer contains raw bytes, this is lossy)
        return .{ .xmlhttp_request_body_init = .{ .usvstring = buffer } };
    }

    // TODO: Check for ReadableStream - return .readable_stream variant
    // TODO: Check for Blob, FormData, URLSearchParams instances

    // Fallback for other objects (RegExp, etc.) - convert to string via toString()
    // Per WebIDL §3.2.1, DOMString/USVString conversion calls ToString() on the value
    const string = v8.v8_Value_ToString(value, context) orelse return ConversionError.TypeError;
    const length = v8.v8_String_Utf8Length(string);
    if (length <= 0) {
        return .{ .xmlhttp_request_body_init = .{ .usvstring = "" } };
    }

    const buffer = try allocator.alloc(u8, @intCast(length));
    errdefer allocator.free(buffer);
    const written = v8.v8_String_WriteUtf8(string, buffer.ptr, @intCast(length));
    if (written != length) {
        allocator.free(buffer);
        return ConversionError.StringError;
    }
    return .{ .xmlhttp_request_body_init = .{ .usvstring = buffer } };
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
    // Validate the value pointer is properly aligned before any V8 API calls
    // V8 values must be 8-byte aligned on 64-bit systems
    const value_addr = @intFromPtr(value);
    if (value_addr == 0 or (value_addr & 0x7) != 0) {
        // Null or misaligned pointer - this is an internal error
        return ConversionError.TypeError;
    }

    // Handle optional types (nullable)
    const type_info = @typeInfo(T);
    if (type_info == .optional) {
        // Check for null/undefined
        if (v8.v8_Value_IsNullOrUndefined(value)) {
            return null;
        }

        const ChildType = type_info.optional.child;

        // Special handling for optional callback types (like EventHandler = ?EventHandlerNonNull)
        // Per WebIDL spec, EventHandler treats non-function values as null, not as a type error.
        // This is because EventHandler is nullable and non-callable objects convert to null.
        // https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler
        const child_type_info = @typeInfo(ChildType);
        if (child_type_info == .pointer) {
            const pointer_child_info = @typeInfo(child_type_info.pointer.child);
            if (pointer_child_info == .@"fn") {
                // This is an optional callback (?*fn(...))
                // If value is not a function, return null instead of erroring
                // NOTE: value from v8_FunctionCallbackInfo_GetArgument is already a Global<Value>*.
                if (!v8.v8_Value_IsFunction(value)) {
                    return null;
                }
            }
        }

        // Recursively convert the child type
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
            if (v8.v8_Value_IsSymbol_Local(@ptrCast(value))) {
                return ConversionError.TypeError;
            }
            // Use safe ToString that captures exceptions from toString() methods
            // Per WebIDL § 3.2.1, if ToString throws, we must propagate the exception
            const result = v8.v8_Value_ToString_Safe(value, context);
            defer v8.v8_FreeToStringResult(result);

            // If toString() threw an exception, rethrow it and signal caller not to throw again
            if (result.exception) |exc| {
                v8.v8_Isolate_ThrowException(isolate, exc);
                return ConversionError.ExceptionPending;
            }

            const string = result.value orelse return ConversionError.TypeError;
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
    // Per WebIDL spec, DOMString uses ToString coercion on any value except Symbol
    // https://webidl.spec.whatwg.org/#idl-DOMString
    // This means null -> "null", undefined -> "undefined", 123 -> "123", etc.
    if (T == runtime.DOMString) {
        // Check for Symbol - throws TypeError per WebIDL spec
        if (v8.v8_Value_IsSymbol(value)) {
            return ConversionError.TypeError;
        }
        // Use safe ToString that captures exceptions from toString() methods
        // Per WebIDL § 3.2.1, if ToString throws, we must propagate the exception
        const result = v8.v8_Value_ToString_Safe(value, context);
        defer v8.v8_FreeToStringResult(result);

        // If toString() threw an exception, rethrow it and signal caller not to throw again
        if (result.exception) |exc| {
            v8.v8_Isolate_ThrowException(isolate, exc);
            return ConversionError.ExceptionPending;
        }

        const string = result.value orelse return ConversionError.TypeError;
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

    // Handle AllowSharedBufferSource - extract bytes from TypedArray/DataView/ArrayBuffer
    if (T == typedefs.AllowSharedBufferSource) {
        return try convertAllowSharedBufferSource(allocator, value);
    }

    // Handle engine-agnostic runtime.JSValue BEFORE generic union handling
    // runtime.JSValue is a special type that wraps JS values for use in impl files
    // We must convert V8 values to the appropriate runtime.JSValue variant
    if (T == runtime.JSValue) {
        // Check for undefined
        if (v8.v8_Value_IsUndefined(value)) {
            return runtime.JSValue{ .undefined = {} };
        }

        // Check for null
        if (v8.v8_Value_IsNull(value)) {
            return runtime.JSValue{ .null = {} };
        }

        // Check for boolean
        if (v8.v8_Value_IsBoolean(value)) {
            return runtime.JSValue{ .boolean = v8.v8_Value_BooleanValue(value, isolate) };
        }

        // Check for number
        if (v8.v8_Value_IsNumber(value)) {
            return runtime.JSValue{ .number = v8.v8_Value_NumberValue(value, context) };
        }

        // Check for string - extract and allocate copy
        if (v8.v8_Value_IsString(value)) {
            const string = v8.v8_Value_ToString(value, context) orelse return ConversionError.TypeError;
            const length = v8.v8_String_Utf8Length(string);
            if (length < 0) return ConversionError.StringError;
            if (length == 0) {
                return runtime.JSValue{ .string = .{ .data = "", .owned = false } };
            }

            const buffer = try allocator.alloc(u8, @intCast(length));
            const written = v8.v8_String_WriteUtf8(string, buffer.ptr, @intCast(length));
            if (written != length) {
                allocator.free(buffer);
                return ConversionError.StringError;
            }
            return runtime.JSValue{ .string = .{ .data = buffer, .owned = true } };
        }

        // For objects/functions/etc., the value IS already a Global handle
        // (from v8_FunctionCallbackInfo_GetArgument which creates and tracks a Global)
        // Just store it directly - no need to persist again
        return runtime.JSValue{ .handle = .{ .ptr = @ptrCast(value) } };
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

        // Interface pointer types: *runtime.Instance (for unions like NodeOrString)
        // These match JS objects that are wrapped platform objects (DOM nodes, etc.)
        const instance_idx: ?usize = comptime blk: {
            for (fields, 0..) |field, i| {
                if (field.type == *runtime.Instance) {
                    break :blk i;
                }
            }
            break :blk null;
        };

        // Callback function types: *anyopaque (for unions like TimerHandler)
        // The "Function" callback is generated as *anyopaque to hold V8 GlobalHandle pointers.
        // These match JavaScript functions that need to be stored for later invocation.
        const function_idx: ?usize = comptime blk: {
            for (fields, 0..) |field, i| {
                // Check for *anyopaque (used for callback.Function)
                if (field.type == *anyopaque) {
                    break :blk i;
                }
                // Also check for *const fn(...) for backwards compatibility with other callbacks
                const field_info = @typeInfo(field.type);
                if (field_info == .pointer and field_info.pointer.size == .one) {
                    const child_info = @typeInfo(field_info.pointer.child);
                    if (child_info == .@"fn") {
                        break :blk i;
                    }
                }
            }
            break :blk null;
        };

        // Runtime dispatch based on V8 value type
        // Check function FIRST since functions are also objects in JavaScript
        if (v8.v8_Value_IsFunction(value)) {
            if (function_idx) |idx| {
                // IMPORTANT: The 'value' from v8_FunctionCallbackInfo_GetArgument is already
                // a Global<Value>* pointer. We do NOT need to call v8_Value_ToGlobal again.
                // Handle the different callback pointer types
                const FieldType = fields[idx].type;
                if (FieldType == *anyopaque) {
                    // For *anyopaque (callbacks.Function), tag so we can identify it later as GlobalHandle
                    const tagged = pointer_tag.tagPointer(@ptrCast(value), .global_handle);
                    return @unionInit(T, fields[idx].name, @constCast(tagged));
                } else {
                    // For typed function pointer fields (*const fn(...)), do NOT tag the pointer.
                    // Tagged pointers have low bits set which violates Zig's alignment requirements
                    // for function pointers. The union variant type already tells us what it is.
                    const ptr_value: usize = @intFromPtr(value);
                    return @unionInit(T, fields[idx].name, @ptrFromInt(ptr_value));
                }
            }
        } else if (v8.v8_Value_IsArray(value)) {
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
            // For objects, we need to distinguish between:
            // 1. Wrapped platform objects (DOM nodes, etc.) - have internal fields
            // 2. Plain JS objects (dictionaries, String objects, etc.) - no internal fields
            //
            // The problem: v8_Object_InternalFieldCount_Raw segfaults on plain objects.
            // Solution: Try instance conversion, but if it returns an instance with null
            // internal pointer, treat it as a plain object.
            if (instance_idx) |idx| {
                const FieldType = fields[idx].type;
                // Try to extract as instance - but first check if we have a string alternative
                // because strings should take priority over treating them as objects
                if (string_idx != null and v8.v8_Value_IsString(value)) {
                    // This is a string, skip instance extraction and let string handling below deal with it
                } else if (fromV8Value(FieldType, allocator, isolate, context, value)) |converted| {
                    return @unionInit(T, fields[idx].name, converted);
                } else |_| {
                    // Instance conversion failed - this might be a native JS object like URL.
                    // If we have a string variant, try to convert the object to string via toString()
                    if (string_idx) |str_idx| {
                        // Call toString() on the object to get a string representation
                        if (v8.v8_Value_ToString(value, context)) |str_value| {
                            const StringFieldType = fields[str_idx].type;
                            if (fromV8Value(StringFieldType, allocator, isolate, context, @ptrCast(str_value))) |str_converted| {
                                return @unionInit(T, fields[str_idx].name, str_converted);
                            } else |_| {
                                // String conversion also failed, fall through
                            }
                        }
                    }
                    // Fall through to dict_idx
                }
            }
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

        // Only accept objects that have valid WrapperTypeInfo - this means they
        // were created by our WebIDL bindings. Native JS objects (like URL, Date, etc.)
        // should NOT be converted to *runtime.Instance.
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

        // FALLBACK: No valid WrapperTypeInfo stored, but the object might still be a valid
        // WebIDL-wrapped object from our bindings. This happens when:
        // 1. The wrapper_type_info_registry.getWrapperTypeInfoByName() is a stub (returns null)
        // 2. The constructor fell back to setInstance() instead of setInstanceWithTypeInfo()
        //
        // Try to extract the instance from slot 0. This is safe because:
        // - Native JS objects won't have anything in internal fields
        // - Our constructor always stores the instance in slot 0
        return interface_mod.getInstance(runtime.Instance, object) orelse {
            return ConversionError.TypeError;
        };
    }

    // Handle function pointers (callbacks)
    //
    // CRITICAL: V8 callback persistence fix
    //
    // When JavaScript passes a callback function (e.g., `new WritableStream({ start: fn })`),
    // the V8 value is a Local<Function> that's only valid within the current HandleScope.
    // If we just store the Local handle pointer, it becomes invalid when the HandleScope ends
    // (typically when the constructor returns).
    //
    // The fix: Create a V8 Global handle immediately during dictionary extraction.
    // Global handles persist until explicitly disposed, surviving HandleScope destruction.
    //
    // We return the Global handle's internal pointer tagged with `.global_handle` so that
    // consumers (like jsCallbackAlgorithmGlobal in algorithm.zig) can detect it's a Global
    // and wrap it appropriately without trying to create another Global from an invalid Local.
    //
    // Memory management: The consumer is responsible for disposing the Global handle when done.
    // The GlobalHandle struct wraps the internal pointer for proper disposal.
    //
    // See: src/runtime/engines/v8/global_handles.zig for GlobalHandle documentation
    // See: src/runtime/engines/v8/pointer_tag.zig for pointer tagging documentation
    // See: whatwg-9bmsj for the bug report this fixes
    // Note: Direct function pointer conversion is problematic because V8 functions
    // can't be directly converted to Zig function pointers. For proper callback handling,
    // use CallbackWrapper types instead.
    //
    // For backward compatibility with code that expects function pointers (like EventHandler),
    // we create a GlobalHandle and return a tagged pointer. The consumer MUST untag it
    // and use it through the GlobalHandle API, NOT call it directly as a function pointer.
    if (type_info == .pointer) {
        const child_info = @typeInfo(type_info.pointer.child);
        if (child_info == .@"fn") {
            // Verify this is actually a V8 function
            // NOTE: value from v8_FunctionCallbackInfo_GetArgument is ALREADY a Global<Value>*
            // (the C++ function creates a new Global from the Local argument and returns it).
            // So we use v8_Value_IsFunction which expects Global<Value>*.
            if (!v8.v8_Value_IsFunction(value)) {
                return ConversionError.TypeError;
            }

            // The value is already a Global<Value>* from v8_FunctionCallbackInfo_GetArgument.
            // We don't need to create another Global - just use this one directly.
            // Tag the pointer so consumers know it's a GlobalHandle.
            //
            // Consumers should:
            // 1. Call pointer_tag.untagPointer() to get the raw pointer and tag
            // 2. Check for .global_handle tag
            // 3. Wrap in GlobalHandle{ .ptr = @ptrCast(untagged.ptr) } for proper disposal
            //
            // IMPORTANT: Tagged pointers are intentionally misaligned (low bits used for tag).
            // We can't use normal pointer casts because Zig checks alignment for function pointers.
            // Instead, we use a union type-pun to bypass alignment checks entirely.
            // The pointer MUST be untagged before any alignment-sensitive operations.
            const tagged_ptr = pointer_tag.tagPointer(@ptrCast(value), .global_handle);

            // Bypass Zig's alignment checking for function pointers.
            // This is safe because:
            // 1. The tagged pointer is never dereferenced directly
            // 2. Consumers must untag before using
            // 3. The underlying GlobalHandle maintains proper alignment
            //
            // We use a packed struct to bypass Zig's alignment checks completely.
            // This is necessary because tagged pointers have intentionally misaligned
            // addresses (low bits used for the tag).
            const tagged_addr: usize = @intFromPtr(tagged_ptr);
            const PackedPtr = packed struct { ptr: T };
            const packed_val: PackedPtr = @bitCast(tagged_addr);
            return packed_val.ptr;
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

        // Per WebIDL spec, for optional parameters:
        // - undefined means "not passed" (use default value)
        // - null is a valid value for string types (stringified to "null")
        // https://webidl.spec.whatwg.org/#idl-optional
        const is_string_type = comptime blk: {
            if (InnerType == runtime.DOMString or
                InnerType == runtime.USVString or
                InnerType == runtime.ByteString)
            {
                break :blk true;
            }
            // Check for []const u8 slice type
            const inner_info = @typeInfo(InnerType);
            if (inner_info == .pointer and inner_info.pointer.size == .slice and
                inner_info.pointer.child == u8)
            {
                break :blk true;
            }
            break :blk false;
        };

        if (v8.v8_Value_IsUndefined(value)) {
            return T.notPassed();
        }

        // For non-string types, null also means "not passed"
        if (!is_string_type and v8.v8_Value_IsNull(value)) {
            return T.notPassed();
        }

        // Convert the inner value (for strings, null will be stringified to "null")
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
        // Use ToString coercion for all values except Symbol (WebIDL standard behavior)
        if (v8.v8_Value_IsSymbol_Local(@ptrCast(value))) {
            return ConversionError.TypeError;
        }
        const string = v8.v8_Value_ToString(value, context) orelse return ConversionError.TypeError;
        return try fromV8String(allocator, isolate, context, string);
    }
    if (T == runtime.Any) return fromV8Any(value);

    // Handle V8-specific JSValue (type-safe JavaScript value wrapper)
    // Note: This is the V8-specific JSValue from engines/v8/js_value.zig
    if (T == JSValue) {
        return try fromV8ValueTyped(value, isolate, context);
    }

    // Handle V8-specific OptionalJSValue (for optional 'any' parameters)
    if (T == OptionalJSValue) {
        if (v8.v8_Value_IsNullOrUndefined(value)) {
            return OptionalJSValue.notPassed;
        }
        return OptionalJSValue.fromValue(try fromV8ValueTyped(value, isolate, context));
    }

    // Handle engine-agnostic runtime.OptionalJSValue
    if (T == runtime.OptionalJSValue) {
        if (v8.v8_Value_IsNullOrUndefined(value)) {
            return runtime.OptionalJSValue.notPassed;
        }
        return runtime.OptionalJSValue.fromValue(try fromV8Value(runtime.JSValue, allocator, isolate, context, value));
    }

    if (T == *const anyopaque) {
        // ============================================================================
        // POINTER TAGGING DOCUMENTATION
        // ============================================================================
        //
        // ## Overview
        //
        // This is the PRODUCER side of the pointer tagging contract. When converting
        // V8 values to `*const anyopaque`, we tag the returned pointer so consumers
        // can safely determine what type of pointer they received.
        //
        // ## Why Tagging is Necessary
        //
        // Dictionary fields and WebIDL 'any' type parameters are declared as
        // `*const anyopaque` in Zig. Without tagging, consumers cannot distinguish:
        // - A V8 Local<Value> handle (temporary, for primitives/strings)
        // - A V8 Global<Value> handle (persisted, for functions/objects)
        // - A Zig *runtime.Instance (wrapped interface, not a V8 pointer at all!)
        //
        // CRITICAL: If a V8 object wraps a Zig instance, we MUST return the Instance
        // pointer, NOT the V8 pointer. Otherwise, callers casting to *runtime.Instance
        // will crash by interpreting V8 memory as Zig structs.
        //
        // ## Tagging Contract
        //
        // **PRODUCER (here in fromV8Value):**
        // - Tags ALL `*const anyopaque` return values using TaggedPointer.init()
        // - Detection logic:
        //   1. If V8 object with internal fields → extract Instance, tag as .runtime_instance
        //   2. If function/object needing persistence → create Global, tag as .global_handle
        //   3. Otherwise → tag Local handle as .local_value
        //
        // **CONSUMERS (engine.zig, binding.zig, impl code):**
        // - MUST use TaggedPointer.fromRaw() or untagPointer() before using the pointer
        // - Check the tag to determine how to handle:
        //   - .runtime_instance: Cast to *runtime.Instance, use directly
        //   - .global_handle/.local_value: Cast to V8 FFI type, call V8 APIs
        //   - .untagged: Legacy compatibility (assume V8 Local handle)
        //
        // ## V8 Handle Lifetimes
        //
        // - Local<Value>: Stack-bound to current HandleScope, becomes invalid when scope ends
        // - Global<Value>: Persists until explicitly disposed, safe across scopes
        // - Functions/objects stored for later callback MUST use Global handles
        // - Primitives are safe as Local (V8 copies values internally)
        //
        // ## Example Consumer Code
        //
        // ```zig
        // fn processAnyValue(tagged_ptr: *const anyopaque) void {
        //     const tagged = TaggedPointer.fromRaw(@intFromPtr(tagged_ptr));
        //     switch (untagged.tag) {
        //         .runtime_instance => {
        //             const instance: *runtime.Instance = @ptrCast(@alignCast(untagged.ptr));
        //             // Use as Zig instance...
        //         },
        //         .global_handle, .local_value, .untagged => {
        //             const v8_value: *ffi.Value = @ptrCast(untagged.ptr);
        //             // Call V8 FFI functions...
        //         },
        //     }
        // }
        // ```
        //
        // ============================================================================

        const TaggedPointer = pointer_tag.TaggedPointer;

        // Step 1: Check if V8 object wraps a Zig instance
        // Detection: Objects with internal fields store Zig instances in field 0
        if (v8.v8_Value_IsObject(value)) {
            const obj: *v8.Object = @ptrCast(value);
            const field_count = v8.v8_Object_InternalFieldCount(obj);
            if (field_count > 0) {
                if (v8.v8_Object_GetAlignedPointerFromInternalField(obj, 0)) |internal_ptr| {
                    // TAGGING: .runtime_instance - this is a Zig object, NOT a V8 handle
                    // Consumer MUST NOT pass this to V8 FFI functions!
                    DebugAssertions.logTaggedPointerCreation(@ptrCast(internal_ptr), .runtime_instance);
                    return TaggedPointer.init(internal_ptr, .runtime_instance).toConstPtr();
                }
                // Internal field null - object not fully initialized, fall through
            }
        }

        // Step 2: Create WEAK Global handle for functions/objects needing persistence
        // NOTE: Local handles become invalid when HandleScope ends
        //
        // MEMORY MANAGEMENT: We use weak Global handles (not strong) because:
        // - Strong handles require manual disposal → causes memory leaks if forgotten
        // - Weak handles let V8 GC clean them up when JS no longer references them
        // - This matches JavaScript semantics: object is kept alive by JS references
        //
        // The weak handle with null callback means:
        // - Handle survives HandleScope (essential for callbacks stored in dictionaries)
        // - V8 can GC the value when no JS references remain
        // - No Zig-side cleanup callback needed (we don't track these handles)
        if (v8.v8_Value_IsFunction(value) or v8.v8_Value_IsObject(value)) {
            if (v8.v8_Value_ToWeakGlobal(isolate, @ptrCast(value), null, null)) |global| {
                // TAGGING: .global_handle - V8 Global<Value>* (weak), survives HandleScope
                // Consumer: untag before V8 FFI, V8 GC handles disposal
                DebugAssertions.logTaggedPointerCreation(@ptrCast(global), .global_handle);
                return TaggedPointer.init(global, .global_handle).toConstPtr();
            }
            // Global creation failed (OOM), fall through to Local
        }

        // Step 3: Return Local handle for primitives
        // TAGGING: .local_value - V8 Local<Value>*, temporary handle
        // Consumer: untag before V8 FFI, only valid within current HandleScope
        DebugAssertions.logTaggedPointerCreation(@ptrCast(@constCast(value)), .local_value);
        return TaggedPointer.init(@ptrCast(@constCast(value)), .local_value).toConstPtr();
    }

    // Handle CallbackWrapper types (for callback interfaces like EventListener, NodeFilter, etc.)
    // We create a runtime.CallbackWrapper that wraps the V8-specific callback wrapper.
    // The runtime.CallbackWrapper uses the engine interface to invoke the V8 callback.
    if (T == *runtime.CallbackWrapper) {
        // CRITICAL: CallbackWrappers MUST use a persistent allocator, NOT the arena allocator.
        // The arena is reset during GC sweeps (onGCSweep -> ArenaAllocator.reset()), but
        // callbacks stored in EventTarget must survive across GC cycles.
        // Using arena allocator here causes use-after-free when event listeners are invoked.
        const persistent_allocator = std.heap.page_allocator;

        // Create a V8 CallbackWrapper from the V8 value (function or object with handleEvent)
        // Note: createFromV8Value may return callback-specific errors which we map to TypeError
        const v8_wrapper_opt = callback_wrapper.createFromV8Value(
            persistent_allocator,
            isolate,
            context,
            value,
            "handleEvent", // Default method name for callback interfaces
        ) catch return ConversionError.TypeError;
        const v8_wrapper = v8_wrapper_opt orelse return ConversionError.TypeError;
        // Register wrapper for cleanup when context is destroyed
        callback_registry.register(v8_wrapper);

        // Create a runtime.CallbackWrapper that properly wraps the V8 callback.
        // CRITICAL: We cannot just @ptrCast because runtime.CallbackWrapper and V8 CallbackWrapper
        // have INCOMPATIBLE struct layouts! runtime.CallbackWrapper.invoke() calls
        // self.engine.invokeCallback(), so we must set up the engine interface correctly.
        const runtime_wrapper = persistent_allocator.create(runtime.CallbackWrapper) catch return ConversionError.TypeError;
        runtime_wrapper.* = .{
            .engine_handle = v8_wrapper, // V8 CallbackWrapper pointer
            .engine = &engine_mod.v8_engine_interface, // V8 engine interface with invokeCallback
            .engine_ctx = context, // V8 context for invoking callbacks
            .allocator = persistent_allocator,
        };
        return runtime_wrapper;
    }
    if (T == ?*runtime.CallbackWrapper) {
        // Optional callback - null/undefined is valid
        if (v8.v8_Value_IsNullOrUndefined(value)) {
            return null;
        }
        // CRITICAL: Use persistent allocator for optional callbacks too (same reason as above)
        const persistent_allocator = std.heap.page_allocator;

        // Note: createFromV8Value may return callback-specific errors which we map to TypeError
        const v8_wrapper = callback_wrapper.createFromV8Value(
            persistent_allocator,
            isolate,
            context,
            value,
            "handleEvent",
        ) catch return ConversionError.TypeError;
        if (v8_wrapper) |w| {
            // Register wrapper for cleanup when context is destroyed
            callback_registry.register(w);

            // Create a runtime.CallbackWrapper that properly wraps the V8 callback
            const runtime_wrapper = persistent_allocator.create(runtime.CallbackWrapper) catch return ConversionError.TypeError;
            runtime_wrapper.* = .{
                .engine_handle = w, // V8 CallbackWrapper pointer
                .engine = &engine_mod.v8_engine_interface, // V8 engine interface
                .engine_ctx = context, // V8 context
                .allocator = persistent_allocator,
            };
            return runtime_wrapper;
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
    // CROSS-REALM SUPPORT: Create object in specified context for correct prototype chain
    const object = v8.v8_Object_NewInContext(context) orelse return ConversionError.OutOfMemory;

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
    // CRITICAL: Handle JSValue types first - they're special union types that need
    // custom conversion, not generic union handling (which would convert
    // the StringValue inner struct to an object with "data" and "owned" fields)

    // Handle V8-specific JSValue (from engines/v8/js_value.zig)
    if (T == JSValue) {
        return value.toV8(isolate);
    }
    if (T == OptionalJSValue) {
        return switch (value) {
            .not_passed => toV8Undefined(isolate),
            .passed => |v| v.toV8(isolate),
        };
    }

    // Handle engine-agnostic JSValue (from runtime/js_value.zig)
    // This is used by WebIDL impls that want to remain engine-agnostic
    if (T == runtime.JSValue) {
        return switch (value) {
            .undefined => toV8Undefined(isolate),
            .null => toV8Null(isolate),
            .boolean => |b| @ptrCast(toV8Boolean(isolate, b)),
            .number => |n| @ptrCast(v8.v8_Number_New(isolate, n)),
            .string => |s| blk: {
                if (s.data.len == 0) {
                    break :blk @ptrCast(v8.v8_String_Empty(isolate) orelse return ConversionError.StringError);
                }
                break :blk @ptrCast(v8.v8_String_NewFromUtf8(isolate, s.data.ptr, @intCast(s.data.len)) orelse return ConversionError.StringError);
            },
            .handle => |h| blk: {
                // SAFETY CHECK: V8 Global handles must be 8-byte aligned.
                // If the pointer is not aligned, it's likely a Zig pointer that was
                // incorrectly stored via fromAnyopaque() - return undefined instead of crashing.
                const ptr_addr = @intFromPtr(h.ptr);
                if (ptr_addr % 8 != 0) {
                    // Not a valid V8 handle - this is a bug in the calling code
                    // but we handle it gracefully instead of crashing
                    debug.print("WARNING: Misaligned handle in runtime.JSValue: 0x{x}\n", .{ptr_addr});
                    break :blk toV8Undefined(isolate);
                }

                // For both Global and Local handles, return the pointer directly.
                // The caller (setReturnValue) will use SetReturnValueGlobal which
                // handles Global<Value>* pointers correctly by calling Get() internally.
                // For Local handles, this also works because SetReturnValueGlobal
                // can handle both Global and Local pointers - it checks if the
                // pointer is valid and handles conversion appropriately.
                break :blk @ptrCast(h.ptr);
            },
            .instance => |i| instanceToV8(isolate, @ptrCast(@alignCast(i))),
        };
    }
    if (T == runtime.OptionalJSValue) {
        return switch (value) {
            .not_passed => toV8Undefined(isolate),
            .passed => |v| try toV8Value(runtime.JSValue, isolate, context, v),
        };
    }

    // Handle webidl.Opt types (WebIDL optional parameters)
    // These are structs with was_passed and value fields, used for optional parameters
    // that need to distinguish between "not passed" and "passed with value"
    if (@typeInfo(T) == .@"struct") {
        if (@hasDecl(T, "notPassed") and @hasDecl(T, "wasPassed") and @hasDecl(T, "getValue")) {
            // This is a webidl.Opt type
            if (!value.wasPassed()) {
                // Not passed -> undefined
                return toV8Undefined(isolate);
            } else {
                // Passed -> convert inner value
                const InnerType = @TypeOf(value.getValue());
                return try toV8Value(InnerType, isolate, context, value.getValue());
            }
        }
    }

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
            // Handle empty strings specially - empty slice may have undefined ptr
            if (value.len == 0) {
                const str = v8.v8_String_Empty(isolate) orelse {
                    return ConversionError.StringError;
                };
                return @ptrCast(str);
            }
            const str = v8.v8_String_NewFromUtf8(isolate, value.ptr, @intCast(value.len)) orelse {
                return ConversionError.StringError;
            };
            return @ptrCast(str);
        }

        // Special case: Slice of structs with "key" and "value" fields => WebIDL record type
        // Convert to JavaScript object where key becomes property name
        const elem_type_info = @typeInfo(ElemType);
        if (elem_type_info == .@"struct") {
            const has_key = @hasField(ElemType, "key");
            const has_value = @hasField(ElemType, "value");
            const field_count = std.meta.fields(ElemType).len;
            if (has_key and has_value and field_count == 2) {
                // This is a record-like type - convert to object
                // CROSS-REALM SUPPORT: Create object in specified context
                const obj = v8.v8_Object_NewInContext(context) orelse return ConversionError.OutOfMemory;
                for (value) |entry| {
                    // Get key as string
                    const key_v8 = try toV8Value(@TypeOf(entry.key), isolate, context, entry.key);
                    // Get value - handle anyopaque as string pointer
                    const val_v8 = blk: {
                        const ValueType = @TypeOf(entry.value);
                        if (ValueType == *const anyopaque or ValueType == *anyopaque) {
                            // The value is a pointer to a string slice
                            const str_ptr: *const []const u8 = @ptrCast(@alignCast(entry.value));
                            const str = str_ptr.*;
                            if (str.len == 0) {
                                break :blk @as(*v8.Value, @ptrCast(v8.v8_String_Empty(isolate) orelse return ConversionError.StringError));
                            }
                            break :blk @as(*v8.Value, @ptrCast(v8.v8_String_NewFromUtf8(isolate, str.ptr, @intCast(str.len)) orelse return ConversionError.StringError));
                        } else {
                            break :blk try toV8Value(ValueType, isolate, context, entry.value);
                        }
                    };
                    _ = v8.v8_Object_Set(obj, context, key_v8, val_v8);
                }
                return @ptrCast(obj);
            }
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
        // Use inline for to compare at comptime and get the name
        inline for (std.meta.fields(T)) |field| {
            if (@intFromEnum(value) == field.value) {
                // Get the field name and strip leading/trailing underscores (used for reserved words)
                const name = field.name;
                var start: usize = 0;
                var end: usize = name.len;
                // Strip leading underscore if present (e.g., "_open_" -> "open_")
                if (name.len > 0 and name[0] == '_') {
                    start = 1;
                }
                // Strip trailing underscore if present (e.g., "open_" -> "open")
                if (end > start and name[end - 1] == '_') {
                    end = end - 1;
                }
                const str = v8.v8_String_NewFromUtf8(isolate, name.ptr + start, @intCast(end - start)) orelse {
                    return toV8Undefined(isolate);
                };
                return @ptrCast(str);
            }
        }
        // Fallback to integer for out-of-range values (shouldn't happen for valid enums)
        const enum_int: usize = @intFromEnum(value);
        const num = v8.v8_Number_New(isolate, @floatFromInt(enum_int));
        return @ptrCast(num);
    }

    // Handle structs (convert to V8 object with fields)
    // WebIDL dictionaries: optional fields that are null should NOT be set on the object
    // (accessing them returns undefined, not null)
    if (type_info == .@"struct") {
        // CROSS-REALM SUPPORT: Use v8_Object_NewInContext to create object in the specified context.
        // This ensures the object's prototype is context.Object.prototype, not current context's.
        // Critical for WPT test: default-toJSON-cross-realm.html
        const obj = v8.v8_Object_NewInContext(context) orelse return ConversionError.OutOfMemory;
        inline for (std.meta.fields(T)) |field| {
            const field_value = @field(value, field.name);
            const field_type_info = @typeInfo(field.type);

            // For optional fields, only set if non-null (null => property not set => undefined in JS)
            const should_set = comptime if (field_type_info == .optional) blk: {
                break :blk true; // Need runtime check
            } else blk: {
                break :blk true; // Non-optional, always set
            };

            if (should_set) {
                // Runtime check for optional fields
                const is_null_optional = if (field_type_info == .optional)
                    field_value == null
                else
                    false;

                if (!is_null_optional) {
                    if (v8.v8_String_NewFromUtf8(
                        isolate,
                        field.name.ptr,
                        @intCast(field.name.len),
                    )) |field_name_str| {
                        const field_v8 = try toV8Value(field.type, isolate, context, field_value);
                        _ = v8.v8_Object_Set(obj, context, @ptrCast(field_name_str), field_v8);
                    }
                }
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

    // Handle *runtime.Instance pointers - these need to be wrapped as V8 objects
    // This enables toV8Sequence to work with []const *runtime.Instance
    if (T == *runtime.Instance) {
        return instanceToV8(isolate, value);
    }
    if (T == *const runtime.Instance) {
        return instanceToV8(isolate, @constCast(value));
    }

    // Handle pointers - SAFETY: Cannot blindly cast Zig pointers to V8 Values
    // Zig heap pointers are NOT V8 Global<Value>* handles and will cause crashes
    // if passed to V8. Return undefined instead.
    // Note: runtime.Instance* is handled above with proper wrapping.
    if (type_info == .pointer) {
        // Return undefined for unknown pointer types to prevent crashes
        return toV8Undefined(isolate);
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
    // SAFETY: runtime.Any is *anyopaque which might not be a valid V8 Value pointer
    // Return undefined instead of blindly casting to prevent crashes
    if (T == runtime.Any) return toV8Undefined(isolate);

    // NOTE: JSValue and OptionalJSValue are handled at the top of this function
    // to ensure they're converted correctly before generic union handling runs

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
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;

    // Log error through context if available
    if (namespace.getGlobalContext()) |ctx| {
        ctx.logger.@"error"("V8 TypeError: {s}", .{message}) catch {};
    }

    const msg_str = v8.v8_String_NewFromUtf8(
        isolate,
        message.ptr,
        @intCast(message.len),
    ) orelse return; // Failed to create string, can't throw
    const exception = v8.v8_Exception_TypeErrorInContext(context, msg_str) orelse return; // Failed to create exception
    v8.v8_Isolate_ThrowException(isolate, exception);
}

/// Throw a TypeError from a specific context's realm (for cross-realm support).
///
/// Per WebIDL spec, when a method throws TypeError for invalid `this`,
/// the error must come from the method's realm (callee's realm), not the caller's realm.
/// This is essential for cross-realm scenarios like:
///
/// ```javascript
/// const other = iframe.contentWindow;
/// const notElement = Object.create(other.HTMLElement.prototype);
/// // This must throw other.TypeError (iframe's TypeError), NOT main window's TypeError
/// Object.getOwnPropertyDescriptor(other.HTMLElement.prototype, "title").get.call(notElement);
/// ```
///
/// @param isolate - The V8 isolate
/// @param context - The context/realm where the TypeError should originate (callee's realm)
/// @param message - The error message
pub fn throwTypeErrorFromContext(
    isolate: *v8.Isolate,
    context: *v8.Context,
    message: []const u8,
) void {
    // CRITICAL: Enter the context before creating and throwing the exception.

    // This ensures that:
    // 1. The TypeError object is an instance of context.TypeError
    // 2. The stack trace and other details are correctly associated with this realm
    // 3. The exception is thrown within this context
    v8.v8_Context_Enter(context);
    defer v8.v8_Context_Exit(context);

    // Log error through context if available
    if (namespace.getGlobalContext()) |ctx| {
        ctx.logger.@"error"("V8 TypeError (cross-realm): {s}", .{message}) catch {};
    }

    const msg_str = v8.v8_String_NewFromUtf8(
        isolate,
        message.ptr,
        @intCast(message.len),
    ) orelse return; // Failed to create string, can't throw

    const exception = v8.v8_Exception_TypeErrorInContext(context, msg_str) orelse {
        // Fallback to regular TypeError if context-specific creation fails
        const fallback = v8.v8_Exception_TypeError(msg_str) orelse return;
        v8.v8_Isolate_ThrowException(isolate, fallback);
        return;
    };
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

/// Throw an Error with a specific name property set (DOMException fallback)
///
/// This is used when we can't create a proper DOMException instance but need
/// to throw an error with the correct `.name` property for WPT tests.
/// Per WebIDL spec, tests check `e.name === "SyntaxError"` etc.
fn throwDOMExceptionFallback(
    isolate: *v8.Isolate,
    name: []const u8,
    message: []const u8,
) void {
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        throwError(isolate, message);
        return;
    };

    // Create the error message string
    const msg_str = v8.v8_String_NewFromUtf8(
        isolate,
        message.ptr,
        @intCast(message.len),
    ) orelse {
        throwError(isolate, message);
        return;
    };

    // Create a generic Error
    const exception = v8.v8_Exception_Error(msg_str) orelse {
        throwError(isolate, message);
        return;
    };

    // Set the .name property to the DOMException name
    const name_key = v8.v8_String_NewFromUtf8(isolate, "name", 4) orelse {
        v8.v8_Isolate_ThrowException(isolate, exception);
        return;
    };
    const name_value = v8.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse {
        v8.v8_Isolate_ThrowException(isolate, exception);
        return;
    };
    _ = v8.v8_Object_Set(@ptrCast(exception), context, @ptrCast(name_key), @ptrCast(name_value));

    // Set the .code property to the legacy error code
    const code_key = v8.v8_String_NewFromUtf8(isolate, "code", 4) orelse {
        v8.v8_Isolate_ThrowException(isolate, exception);
        return;
    };
    const code = getLegacyCodeForDOMExceptionName(name);
    const code_value = v8.v8_Number_New(isolate, @floatFromInt(code));
    _ = v8.v8_Object_Set(@ptrCast(exception), context, @ptrCast(code_key), @ptrCast(code_value));

    v8.v8_Isolate_ThrowException(isolate, exception);
}

/// Get legacy error code for a DOMException name
fn getLegacyCodeForDOMExceptionName(name: []const u8) u16 {
    const legacy_codes = std.StaticStringMap(u16).initComptime(.{
        .{ "IndexSizeError", 1 },
        .{ "HierarchyRequestError", 3 },
        .{ "WrongDocumentError", 4 },
        .{ "InvalidCharacterError", 5 },
        .{ "NoModificationAllowedError", 7 },
        .{ "NotFoundError", 8 },
        .{ "NotSupportedError", 9 },
        .{ "InUseAttributeError", 10 },
        .{ "InvalidStateError", 11 },
        .{ "SyntaxError", 12 },
        .{ "InvalidModificationError", 13 },
        .{ "NamespaceError", 14 },
        .{ "InvalidAccessError", 15 },
        .{ "TypeMismatchError", 17 },
        .{ "SecurityError", 18 },
        .{ "NetworkError", 19 },
        .{ "AbortError", 20 },
        .{ "URLMismatchError", 21 },
        .{ "QuotaExceededError", 22 },
        .{ "TimeoutError", 23 },
        .{ "InvalidNodeTypeError", 24 },
        .{ "DataCloneError", 25 },
    });
    return legacy_codes.get(name) orelse 0;
}

/// Throw a DOMException in V8
///
/// Creates a proper DOMException instance with the correct name and message properties.
/// This is essential for WebIDL error handling where tests check:
/// - e instanceof DOMException === true
/// - e.name === "ErrorName"
/// - e.code === <legacy code>
///
/// If DOMException constructor is not available, falls back to generic Error.
pub fn throwDOMException(
    isolate: *v8.Isolate,
    name: []const u8,
    message: []const u8,
) void {
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    const global = v8.v8_Context_Global(context) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };

    // Get the DOMException constructor from global
    const dom_exception_key = v8.v8_String_NewFromUtf8(isolate, "DOMException", 12) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    const dom_exception_ctor = v8.v8_Object_Get(global, context, @ptrCast(dom_exception_key)) orelse {
        // DOMException not registered, fall back to Error with .name property
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };

    if (!v8.v8_Value_IsFunction(dom_exception_ctor)) {
        // DOMException is not a function, fall back to Error with .name property
        throwDOMExceptionFallback(isolate, name, message);
        return;
    }

    // Create V8 strings for the arguments
    const v8_message = v8.v8_String_NewFromUtf8(isolate, message.ptr, @intCast(message.len)) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    const v8_name = v8.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };

    // Use Reflect.construct to call the constructor
    // Reflect.construct(DOMException, [message, name])
    const reflect_key = v8.v8_String_NewFromUtf8(isolate, "Reflect", 7) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    const reflect_obj = v8.v8_Object_Get(global, context, @ptrCast(reflect_key)) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    const construct_key = v8.v8_String_NewFromUtf8(isolate, "construct", 9) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    const construct_fn_value = v8.v8_Object_Get(@ptrCast(reflect_obj), context, @ptrCast(construct_key)) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    if (!v8.v8_Value_IsFunction(construct_fn_value)) {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    }
    const construct_fn: *v8.Function = @ptrCast(construct_fn_value);

    // Create argument array: [message, name]
    const args_array = v8.v8_Array_New(isolate, 2);
    _ = v8.v8_Array_Set(args_array, context, 0, @ptrCast(v8_message));
    _ = v8.v8_Array_Set(args_array, context, 1, @ptrCast(v8_name));

    // Call Reflect.construct(DOMException, [message, name])
    var args = [_]*v8.Value{ dom_exception_ctor, @ptrCast(args_array) };
    const exception = v8.v8_Function_Call(construct_fn, context, reflect_obj, 2, &args) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };

    v8.v8_Isolate_ThrowException(isolate, exception);
}

/// List of DOMException names as defined by WebIDL spec
/// Used to determine if an error name is a DOMException or a simple exception
pub const dom_exception_names = [_][]const u8{
    "IndexSizeError",
    "HierarchyRequestError",
    "WrongDocumentError",
    "InvalidCharacterError",
    "NoModificationAllowedError",
    "NotFoundError",
    "NotSupportedError",
    "InUseAttributeError",
    "InvalidStateError",
    "SyntaxError",
    "InvalidModificationError",
    "NamespaceError",
    "InvalidAccessError",
    "SecurityError",
    "NetworkError",
    "AbortError",
    "URLMismatchError",
    "QuotaExceededError",
    "TimeoutError",
    "InvalidNodeTypeError",
    "DataCloneError",
    "EncodingError",
    "NotReadableError",
    "UnknownError",
    "ConstraintError",
    "DataError",
    "TransactionInactiveError",
    "ReadOnlyError",
    "VersionError",
    "OperationError",
    "NotAllowedError",
};

/// Check if an error name is a DOMException name
pub fn isDOMExceptionName(name: []const u8) bool {
    for (dom_exception_names) |dom_name| {
        if (std.mem.eql(u8, name, dom_name)) {
            return true;
        }
    }
    return false;
}

/// Throw an appropriate exception based on the error name
pub fn throwWebIDLError(
    isolate: *v8.Isolate,
    error_name: []const u8,
) void {
    const context = v8.v8_Isolate_GetCurrentContext(isolate);
    throwWebIDLErrorFromContext(isolate, context.?, error_name);
}

/// Throw an appropriate exception from a specific context's realm
pub fn throwWebIDLErrorFromContext(
    isolate: *v8.Isolate,
    context: *v8.Context,
    error_name: []const u8,
) void {
    if (isDOMExceptionName(error_name)) {
        // TODO: implement throwDOMExceptionFromContext
        throwDOMException(isolate, error_name, error_name);
    } else if (std.mem.eql(u8, error_name, "TypeError")) {
        throwTypeErrorFromContext(isolate, context, "TypeError");
    } else if (std.mem.eql(u8, error_name, "RangeError")) {
        // TODO: implement throwRangeErrorFromContext
        throwRangeError(isolate, "RangeError");
    } else if (std.mem.eql(u8, error_name, "InvalidEncoding")) {
        throwRangeError(isolate, "The encoding label provided is invalid.");
    } else if (std.mem.eql(u8, error_name, "ReplacementEncoding")) {
        throwRangeError(isolate, "The encoding label provided is a replacement encoding.");
    } else if (std.mem.eql(u8, error_name, "DecodingError")) {
        throwTypeErrorFromContext(isolate, context, "The encoded data was not valid.");
    } else if (std.mem.eql(u8, error_name, "NotImplemented")) {
        throwDOMException(isolate, "NotSupportedError", "This feature is not yet implemented");
    } else {
        throwError(isolate, error_name);
    }
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
    if (v8.v8_Value_IsSymbol_Local(@ptrCast(value))) {
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

    // Safety check: if instance pointer looks invalid, return undefined
    // This can happen with use-after-free or invalid pointers from DOM methods
    if (@intFromPtr(instance) < 0x1000) {
        // Pointer is in low memory region (likely null or invalid)
        return v8.v8_Undefined(isolate) orelse unreachable;
    }

    // Get interface name from instance vtable
    const interface_name = template_registry.getInstanceInterfaceName(instance);

    // Special handling for Window instances with bound V8 global
    // This enables cross-realm support: iframe.contentWindow returns the V8 global
    // which has DOMRectReadOnly and other constructors on it.
    if (std.mem.eql(u8, interface_name, "Window")) {
        const WindowImpl = @import("impls").Window;
        if (WindowImpl.getBoundV8Global(instance)) |bound_global| {
            // Return the bound global directly - this is the key for cross-realm!
            // bound_global is a Global<Object>* which is the correct type for setReturnValue
            return @ptrCast(bound_global);
        }
    }

    // Get the instance's creation context - this is critical for cross-realm support!
    // When returning interface instances from toJSON, they must be wrapped with their
    // ORIGINAL realm's prototype, not the current context's prototype.
    // e.g., DOMQuad.toJSON returns p1-p4 DOMPoints - these should have the DOMPoint
    // prototype from the realm where they were created, not the toJSON method's realm.
    const context: *v8.Context = if (instance.ctx.getEngineContext()) |engine_ctx|
        @ptrCast(@alignCast(engine_ctx))
    else
        v8.v8_Isolate_GetCurrentContext(isolate) orelse {
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
                // CROSS-REALM SUPPORT: Create object in specified context
                const obj = v8.v8_Object_NewInContext(context) orelse return ConversionError.OutOfMemory;

                // Set "done" property
                const done_key = v8.v8_String_NewFromUtf8(isolate, "done", 4) orelse
                    return ConversionError.OutOfMemory;
                const done_value: *v8.Value = @ptrCast(toV8Boolean(isolate, value.done));
                _ = v8.v8_Object_Set(obj, context, @ptrCast(done_key), done_value);

                // Set "value" property
                const value_key = v8.v8_String_NewFromUtf8(isolate, "value", 5) orelse
                    return ConversionError.OutOfMemory;

                // Value may be runtime.JSValue (tagged union) or *anyopaque
                // Handle both cases for compatibility
                const value_v8: *v8.Value = if (value.value) |v| blk: {
                    // Check if v is a runtime.JSValue by checking if it has asEngineHandle
                    const V = @TypeOf(v);
                    if (@typeInfo(V) == .@"union") {
                        // This is a runtime.JSValue - convert using toV8Value which handles
                        // Global/Local handle scopes correctly
                        break :blk toV8Value(V, isolate, context, v) catch {
                            break :blk v8.v8_Undefined(isolate) orelse return ConversionError.OutOfMemory;
                        };
                    } else if (@typeInfo(V) == .pointer) {
                        // Legacy *anyopaque case - assume it's already a Global handle
                        break :blk @ptrCast(v);
                    } else {
                        break :blk v8.v8_Undefined(isolate) orelse return ConversionError.OutOfMemory;
                    }
                } else v8.v8_Undefined(isolate) orelse return ConversionError.OutOfMemory;

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
// Symbol.iterator Helpers (for WebIDL sequence conversion)
// ============================================================================

/// Entry from iterating a sequence<sequence<USVString>> (e.g., for URLSearchParams)
pub const SequencePair = struct {
    name: []const u8,
    value: []const u8,
};

/// Iterate a V8 object using Symbol.iterator and return name-value pairs.
/// This implements the WebIDL sequence<sequence<USVString>> conversion.
///
/// Per the URL Standard, URLSearchParams constructor accepts:
/// 1. A string (query string)
/// 2. A sequence<sequence<USVString>> where each inner sequence has exactly 2 items
/// 3. A record<USVString, USVString>
///
/// This function handles case 2 by:
/// - Getting Symbol.iterator from the object
/// - Calling the iterator to get an iterator object
/// - Iterating with next() until done
/// - Each yielded value must be iterable and produce exactly 2 string items
///
/// Returns null if the object is not iterable.
/// Returns error.TypeError if inner sequences don't have exactly 2 elements.
pub fn iterateAsSequencePairs(
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!?[]SequencePair {
    // Must be an object to be iterable
    if (!v8.v8_Value_IsObject(value)) {
        return null;
    }
    const obj: *v8.Object = @ptrCast(value);

    // Get Symbol.iterator
    const symbol_iterator = v8.v8_Symbol_GetIterator(isolate) orelse return null;

    // Get the @@iterator method from the object
    const iterator_method = v8.v8_Object_GetPropertyWithSymbol(context, obj, symbol_iterator) orelse return null;

    // Must be a function
    if (!v8.v8_Value_IsFunction(iterator_method)) {
        return null;
    }
    const iterator_fn: *v8.Function = @ptrCast(iterator_method);

    // Call the iterator function with the object as 'this'
    var dummy_args: [0]*v8.Value = undefined;
    const iterator_obj = v8.v8_Function_Call(iterator_fn, context, @ptrCast(obj), 0, &dummy_args) orelse return null;

    if (!v8.v8_Value_IsObject(iterator_obj)) {
        return null;
    }

    // Get the "next" method from the iterator
    const next_key = v8.v8_String_NewFromUtf8(isolate, "next", 4) orelse return ConversionError.OutOfMemory;
    const next_method = v8.v8_Object_Get(@ptrCast(iterator_obj), context, @ptrCast(next_key)) orelse return null;

    if (!v8.v8_Value_IsFunction(next_method)) {
        return null;
    }
    const next_fn: *v8.Function = @ptrCast(next_method);

    // Collect pairs by iterating
    var pairs: std.ArrayList(SequencePair) = .{};
    errdefer {
        for (pairs.items) |pair| {
            if (pair.name.len > 0) allocator.free(pair.name);
            if (pair.value.len > 0) allocator.free(pair.value);
        }
        pairs.deinit(allocator);
    }

    const done_key = v8.v8_String_NewFromUtf8(isolate, "done", 4) orelse return ConversionError.OutOfMemory;
    const value_key = v8.v8_String_NewFromUtf8(isolate, "value", 5) orelse return ConversionError.OutOfMemory;

    // Iterate
    while (true) {
        // Call next()
        var next_args: [0]*v8.Value = undefined;
        const result = v8.v8_Function_Call(next_fn, context, iterator_obj, 0, &next_args) orelse break;

        if (!v8.v8_Value_IsObject(result)) break;

        // Check if done
        const done_val = v8.v8_Object_Get(@ptrCast(result), context, @ptrCast(done_key)) orelse break;
        if (v8.v8_Value_BooleanValue(done_val, isolate)) break;

        // Get the yielded value
        const yielded = v8.v8_Object_Get(@ptrCast(result), context, @ptrCast(value_key)) orelse continue;

        // The yielded value must be iterable (inner sequence) with exactly 2 elements
        // Iterate it to get name and value
        const pair_result = try iteratePairElements(allocator, isolate, context, yielded);
        if (pair_result == null) {
            // Not a valid pair - throw TypeError
            return ConversionError.TypeError;
        }
        try pairs.append(allocator, pair_result.?);
    }

    return try pairs.toOwnedSlice(allocator);
}

/// Iterate an inner sequence to extract exactly 2 string elements.
/// Returns null if the value is not iterable or doesn't have exactly 2 elements.
fn iteratePairElements(
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!?SequencePair {
    // Handle array case (most common)
    if (v8.v8_Value_IsArray(value)) {
        const arr: *v8.Array = @ptrCast(value);
        const len = v8.v8_Array_Length(arr);

        // Must have exactly 2 elements
        if (len != 2) {
            return null;
        }

        // Get elements
        const elem0 = v8.v8_Array_Get(context, arr, 0) orelse return null;
        const elem1 = v8.v8_Array_Get(context, arr, 1) orelse return null;

        // Convert to strings using ToString
        const name = try extractV8StringAlloc(allocator, context, elem0);
        errdefer allocator.free(name);
        const val = try extractV8StringAlloc(allocator, context, elem1);

        return SequencePair{
            .name = name,
            .value = val,
        };
    }

    // Handle general iterable case using Symbol.iterator
    if (!v8.v8_Value_IsObject(value)) {
        return null;
    }
    const obj: *v8.Object = @ptrCast(value);

    // Get Symbol.iterator
    const symbol_iterator = v8.v8_Symbol_GetIterator(isolate) orelse return null;
    const iterator_method = v8.v8_Object_GetPropertyWithSymbol(context, obj, symbol_iterator) orelse return null;

    if (!v8.v8_Value_IsFunction(iterator_method)) {
        return null;
    }
    const iterator_fn: *v8.Function = @ptrCast(iterator_method);

    // Call the iterator
    var dummy_args: [0]*v8.Value = undefined;
    const iterator_obj = v8.v8_Function_Call(iterator_fn, context, @ptrCast(obj), 0, &dummy_args) orelse return null;

    if (!v8.v8_Value_IsObject(iterator_obj)) {
        return null;
    }

    // Get next method
    const next_key = v8.v8_String_NewFromUtf8(isolate, "next", 4) orelse return ConversionError.OutOfMemory;
    const next_method = v8.v8_Object_Get(@ptrCast(iterator_obj), context, @ptrCast(next_key)) orelse return null;

    if (!v8.v8_Value_IsFunction(next_method)) {
        return null;
    }
    const next_fn: *v8.Function = @ptrCast(next_method);

    const done_key = v8.v8_String_NewFromUtf8(isolate, "done", 4) orelse return ConversionError.OutOfMemory;
    const value_key = v8.v8_String_NewFromUtf8(isolate, "value", 5) orelse return ConversionError.OutOfMemory;

    // Collect exactly 2 elements
    var elements: [2][]u8 = .{ &[_]u8{}, &[_]u8{} };
    var count: usize = 0;

    while (count < 3) { // Iterate up to 3 times to detect if there are more than 2 elements
        var next_args: [0]*v8.Value = undefined;
        const result = v8.v8_Function_Call(next_fn, context, iterator_obj, 0, &next_args) orelse break;

        if (!v8.v8_Value_IsObject(result)) break;

        const done_val = v8.v8_Object_Get(@ptrCast(result), context, @ptrCast(done_key)) orelse break;
        if (v8.v8_Value_BooleanValue(done_val, isolate)) break;

        const elem = v8.v8_Object_Get(@ptrCast(result), context, @ptrCast(value_key)) orelse continue;

        if (count < 2) {
            elements[count] = try extractV8StringAlloc(allocator, context, elem);
        }
        count += 1;
    }

    // Must have exactly 2 elements
    if (count != 2) {
        // Free any allocated strings
        if (elements[0].len > 0) allocator.free(elements[0]);
        if (elements[1].len > 0) allocator.free(elements[1]);
        return null;
    }

    return SequencePair{
        .name = elements[0],
        .value = elements[1],
    };
}

/// Check if a V8 value is iterable (has Symbol.iterator method).
pub fn isIterable(isolate: *v8.Isolate, context: *v8.Context, value: *v8.Value) bool {
    if (!v8.v8_Value_IsObject(value)) {
        // Strings are iterable but we handle them separately
        return v8.v8_Value_IsString(value);
    }
    const obj: *v8.Object = @ptrCast(value);

    // Get Symbol.iterator
    const symbol_iterator = v8.v8_Symbol_GetIterator(isolate) orelse return false;
    const iterator_method = v8.v8_Object_GetPropertyWithSymbol(context, obj, symbol_iterator) orelse return false;

    return v8.v8_Value_IsFunction(iterator_method);
}

/// Iterate a V8 object as record<USVString, USVString> for URLSearchParams.
/// Returns the object's own enumerable string-keyed properties as pairs.
pub fn iterateAsRecordPairs(
    allocator: std.mem.Allocator,
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!?[]SequencePair {
    if (!v8.v8_Value_IsObject(value)) {
        return null;
    }
    const obj: *v8.Object = @ptrCast(value);

    // Get own property names
    const names = v8.v8_Object_GetOwnPropertyNames(context, obj) orelse return null;

    const length = v8.v8_Array_Length(names);
    if (length == 0) {
        return &[_]SequencePair{};
    }

    var pairs: std.ArrayList(SequencePair) = .{};
    errdefer {
        for (pairs.items) |pair| {
            if (pair.name.len > 0) allocator.free(pair.name);
            if (pair.value.len > 0) allocator.free(pair.value);
        }
        pairs.deinit(allocator);
    }

    for (0..length) |i| {
        const key_val = v8.v8_Array_Get(context, names, @intCast(i)) orelse continue;
        const prop_val = v8.v8_Object_Get(obj, context, key_val) orelse continue;

        const key_str = try extractV8StringAlloc(allocator, context, key_val);
        errdefer allocator.free(key_str);
        const val_str = try extractV8StringAlloc(allocator, context, prop_val);

        try pairs.append(allocator, SequencePair{
            .name = key_str,
            .value = val_str,
        });
    }

    return try pairs.toOwnedSlice(allocator);
}

// ============================================================================
// Tests
// ============================================================================

test "conversion module compiles" {
    const testing = std.testing;
    testing.refAllDecls(@This());
}
