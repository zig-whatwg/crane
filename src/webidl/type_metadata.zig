//! WebIDL Type Metadata System
//!
//! This module provides compile-time type metadata for all WebIDL types,
//! enabling code generation tools to query type information and conversion
//! functions for generating JavaScript runtime bindings.
//!
//! ## Usage
//!
//! ```zig
//! const webidl = @import("webidl");
//!
//! // Query metadata for any WebIDL type
//! const long_meta = webidl.typeMetadata("long");
//! // Returns:
//! // .zig_type = i32
//! // .kind = .primitive
//! // .js_type = "number"
//! // .conversion.from_js = &toLong
//!
//! // Query union type metadata
//! const buffer_meta = webidl.typeMetadata("BufferSource");
//! // Returns:
//! // .kind = .union_type
//! // .union_members = ["ArrayBufferView", "ArrayBuffer"]
//!
//! // Query generic container metadata
//! const seq_meta = webidl.typeMetadata("sequence");
//! // Returns:
//! // .kind = .sequence
//! // .inner_types = ["T"]
//! ```

const std = @import("std");
const primitives = @import("types/primitives.zig");
const strings = @import("types/strings.zig");
const bigint_mod = @import("types/bigint.zig");
const buffer_sources = @import("types/buffer_sources.zig");
const wrappers = @import("wrappers.zig");
const errors = @import("errors.zig");
const callbacks = @import("types/callbacks.zig");
const frozen_arrays = @import("types/frozen_arrays.zig");
const observable_arrays = @import("types/observable_arrays.zig");
const maplike = @import("types/maplike.zig");
const setlike = @import("types/setlike.zig");

/// Function signature metadata for type conversion functions
pub const FunctionSignature = struct {
    /// Whether the function requires an allocator parameter
    needs_allocator: bool,

    /// Whether the function requires a comptime type parameter
    needs_type_param: bool,

    /// Whether the function accepts extended attribute parameters ([Clamp], [EnforceRange])
    needs_extended_attrs: bool,

    /// Parameter types (excluding allocator and type params)
    param_types: []const type,

    /// Return type
    return_type: type,

    /// Possible error types
    errors: ?[]const type,
};

/// Conversion function information
pub const ConversionInfo = struct {
    /// Function pointer for converting from JavaScript to WebIDL type
    from_js: ?*const anyopaque,

    /// Signature metadata for from_js function
    from_js_sig: ?FunctionSignature,

    /// Function pointer for converting from WebIDL type to JavaScript
    to_js: ?*const anyopaque,

    /// Signature metadata for to_js function
    to_js_sig: ?FunctionSignature,
};

/// WebIDL type categories
pub const TypeKind = enum {
    // Primitives
    primitive, // boolean, byte, short, long, float, double, etc.
    bigint, // bigint
    string, // DOMString, ByteString, USVString

    // Objects
    object, // plain object type
    interface, // DOM interfaces
    dictionary, // WebIDL dictionaries
    enumeration, // WebIDL enums
    callback, // callback functions/interfaces

    // Buffers
    buffer, // ArrayBuffer, SharedArrayBuffer
    typed_array, // Int8Array, Uint8Array, etc.
    buffer_view, // DataView

    // Containers
    union_type, // (A or B)
    sequence, // sequence<T>
    record, // record<K, V>
    frozen_array, // FrozenArray<T>
    observable_array, // ObservableArray<T>
    promise, // Promise<T>

    // Special
    nullable, // T?
    any, // any type
    undefined, // undefined type
    symbol, // symbol type
};

/// Complete metadata for a WebIDL type
pub const TypeMetadata = struct {
    /// The Zig type that represents this WebIDL type
    zig_type: type,

    /// WebIDL type category
    kind: TypeKind,

    /// JavaScript type name for V8 type checking
    /// Values: "string", "number", "bigint", "boolean", "object", "symbol", "undefined"
    js_type: []const u8,

    /// For union types: array of member type names
    /// For non-unions: null
    union_members: ?[]const []const u8,

    /// For generic types: array of type parameter names
    /// e.g., sequence has ["T"], record has ["K", "V"]
    inner_types: ?[]const []const u8,

    /// Conversion function information (null if no conversion needed)
    conversion: ?ConversionInfo,
};

/// Compile-time lookup function to get metadata for any WebIDL type
pub fn typeMetadata(comptime name: []const u8) TypeMetadata {
    // Primitive numeric types
    if (std.mem.eql(u8, name, "boolean")) return metadata_boolean;
    if (std.mem.eql(u8, name, "byte")) return metadata_byte;
    if (std.mem.eql(u8, name, "octet")) return metadata_octet;
    if (std.mem.eql(u8, name, "short")) return metadata_short;
    if (std.mem.eql(u8, name, "unsigned short")) return metadata_unsigned_short;
    if (std.mem.eql(u8, name, "long")) return metadata_long;
    if (std.mem.eql(u8, name, "unsigned long")) return metadata_unsigned_long;
    if (std.mem.eql(u8, name, "long long")) return metadata_long_long;
    if (std.mem.eql(u8, name, "unsigned long long")) return metadata_unsigned_long_long;
    if (std.mem.eql(u8, name, "float")) return metadata_float;
    if (std.mem.eql(u8, name, "unrestricted float")) return metadata_unrestricted_float;
    if (std.mem.eql(u8, name, "double")) return metadata_double;
    if (std.mem.eql(u8, name, "unrestricted double")) return metadata_unrestricted_double;
    if (std.mem.eql(u8, name, "bigint")) return metadata_bigint;

    // String types
    if (std.mem.eql(u8, name, "DOMString")) return metadata_DOMString;
    if (std.mem.eql(u8, name, "ByteString")) return metadata_ByteString;
    if (std.mem.eql(u8, name, "USVString")) return metadata_USVString;

    // Special types
    if (std.mem.eql(u8, name, "any")) return metadata_any;
    if (std.mem.eql(u8, name, "undefined")) return metadata_undefined;
    if (std.mem.eql(u8, name, "object")) return metadata_object;
    if (std.mem.eql(u8, name, "symbol")) return metadata_symbol;

    // Buffer types
    if (std.mem.eql(u8, name, "ArrayBuffer")) return metadata_ArrayBuffer;
    if (std.mem.eql(u8, name, "SharedArrayBuffer")) return metadata_SharedArrayBuffer;
    if (std.mem.eql(u8, name, "DataView")) return metadata_DataView;
    if (std.mem.eql(u8, name, "Int8Array")) return metadata_Int8Array;
    if (std.mem.eql(u8, name, "Uint8Array")) return metadata_Uint8Array;
    if (std.mem.eql(u8, name, "Uint8ClampedArray")) return metadata_Uint8ClampedArray;
    if (std.mem.eql(u8, name, "Int16Array")) return metadata_Int16Array;
    if (std.mem.eql(u8, name, "Uint16Array")) return metadata_Uint16Array;
    if (std.mem.eql(u8, name, "Int32Array")) return metadata_Int32Array;
    if (std.mem.eql(u8, name, "Uint32Array")) return metadata_Uint32Array;
    if (std.mem.eql(u8, name, "Int64Array")) return metadata_Int64Array;
    if (std.mem.eql(u8, name, "Uint64Array")) return metadata_Uint64Array;
    if (std.mem.eql(u8, name, "BigInt64Array")) return metadata_BigInt64Array;
    if (std.mem.eql(u8, name, "BigUint64Array")) return metadata_BigUint64Array;
    if (std.mem.eql(u8, name, "Float32Array")) return metadata_Float32Array;
    if (std.mem.eql(u8, name, "Float64Array")) return metadata_Float64Array;

    // Union typedefs
    if (std.mem.eql(u8, name, "ArrayBufferView")) return metadata_ArrayBufferView;
    if (std.mem.eql(u8, name, "BufferSource")) return metadata_BufferSource;
    if (std.mem.eql(u8, name, "AllowSharedBufferSource")) return metadata_AllowSharedBufferSource;

    // Generic containers
    if (std.mem.eql(u8, name, "sequence")) return metadata_sequence;
    if (std.mem.eql(u8, name, "record")) return metadata_record;
    if (std.mem.eql(u8, name, "FrozenArray")) return metadata_FrozenArray;
    if (std.mem.eql(u8, name, "ObservableArray")) return metadata_ObservableArray;
    if (std.mem.eql(u8, name, "Promise")) return metadata_Promise;
    if (std.mem.eql(u8, name, "nullable")) return metadata_nullable;

    // Error types
    if (std.mem.eql(u8, name, "DOMException")) return metadata_DOMException;

    @compileError("Unknown WebIDL type: " ++ name);
}

// ============================================================================
// Metadata Definitions
// ============================================================================

// Primitive Types
const metadata_boolean = TypeMetadata{
    .zig_type = bool,
    .kind = .primitive,
    .js_type = "boolean",
    .union_members = null,
    .inner_types = null,
    .conversion = .{
        .from_js = @ptrCast(&primitives.toBoolean),
        .from_js_sig = .{
            .needs_allocator = false,
            .needs_type_param = false,
            .needs_extended_attrs = false,
            .param_types = &[_]type{primitives.JSValue},
            .return_type = bool,
            .errors = null,
        },
        .to_js = null, // TODO: Add when implemented
        .to_js_sig = null,
    },
};

const metadata_byte = TypeMetadata{
    .zig_type = i8,
    .kind = .primitive,
    .js_type = "number",
    .union_members = null,
    .inner_types = null,
    .conversion = .{
        .from_js = @ptrCast(&primitives.toByte),
        .from_js_sig = .{
            .needs_allocator = false,
            .needs_type_param = false,
            .needs_extended_attrs = false,
            .param_types = &[_]type{primitives.JSValue},
            .return_type = i8,
            .errors = null,
        },
        .to_js = null,
        .to_js_sig = null,
    },
};

const metadata_octet = TypeMetadata{
    .zig_type = u8,
    .kind = .primitive,
    .js_type = "number",
    .union_members = null,
    .inner_types = null,
    .conversion = .{
        .from_js = @ptrCast(&primitives.toOctet),
        .from_js_sig = .{
            .needs_allocator = false,
            .needs_type_param = false,
            .needs_extended_attrs = false,
            .param_types = &[_]type{primitives.JSValue},
            .return_type = u8,
            .errors = null,
        },
        .to_js = null,
        .to_js_sig = null,
    },
};

const metadata_short = TypeMetadata{
    .zig_type = i16,
    .kind = .primitive,
    .js_type = "number",
    .union_members = null,
    .inner_types = null,
    .conversion = .{
        .from_js = @ptrCast(&primitives.toShort),
        .from_js_sig = .{
            .needs_allocator = false,
            .needs_type_param = false,
            .needs_extended_attrs = false,
            .param_types = &[_]type{primitives.JSValue},
            .return_type = i16,
            .errors = null,
        },
        .to_js = null,
        .to_js_sig = null,
    },
};

const metadata_unsigned_short = TypeMetadata{
    .zig_type = u16,
    .kind = .primitive,
    .js_type = "number",
    .union_members = null,
    .inner_types = null,
    .conversion = .{
        .from_js = @ptrCast(&primitives.toUnsignedShort),
        .from_js_sig = .{
            .needs_allocator = false,
            .needs_type_param = false,
            .needs_extended_attrs = false,
            .param_types = &[_]type{primitives.JSValue},
            .return_type = u16,
            .errors = null,
        },
        .to_js = null,
        .to_js_sig = null,
    },
};

const metadata_long = TypeMetadata{
    .zig_type = i32,
    .kind = .primitive,
    .js_type = "number",
    .union_members = null,
    .inner_types = null,
    .conversion = .{
        .from_js = @ptrCast(&primitives.toLong),
        .from_js_sig = .{
            .needs_allocator = false,
            .needs_type_param = false,
            .needs_extended_attrs = false,
            .param_types = &[_]type{primitives.JSValue},
            .return_type = i32,
            .errors = null,
        },
        .to_js = null,
        .to_js_sig = null,
    },
};

const metadata_unsigned_long = TypeMetadata{
    .zig_type = u32,
    .kind = .primitive,
    .js_type = "number",
    .union_members = null,
    .inner_types = null,
    .conversion = .{
        .from_js = @ptrCast(&primitives.toUnsignedLong),
        .from_js_sig = .{
            .needs_allocator = false,
            .needs_type_param = false,
            .needs_extended_attrs = false,
            .param_types = &[_]type{primitives.JSValue},
            .return_type = u32,
            .errors = null,
        },
        .to_js = null,
        .to_js_sig = null,
    },
};

const metadata_long_long = TypeMetadata{
    .zig_type = i64,
    .kind = .primitive,
    .js_type = "number",
    .union_members = null,
    .inner_types = null,
    .conversion = .{
        .from_js = @ptrCast(&primitives.toLongLong),
        .from_js_sig = .{
            .needs_allocator = false,
            .needs_type_param = false,
            .needs_extended_attrs = false,
            .param_types = &[_]type{primitives.JSValue},
            .return_type = i64,
            .errors = null,
        },
        .to_js = null,
        .to_js_sig = null,
    },
};

const metadata_unsigned_long_long = TypeMetadata{
    .zig_type = u64,
    .kind = .primitive,
    .js_type = "number",
    .union_members = null,
    .inner_types = null,
    .conversion = .{
        .from_js = @ptrCast(&primitives.toUnsignedLongLong),
        .from_js_sig = .{
            .needs_allocator = false,
            .needs_type_param = false,
            .needs_extended_attrs = false,
            .param_types = &[_]type{primitives.JSValue},
            .return_type = u64,
            .errors = null,
        },
        .to_js = null,
        .to_js_sig = null,
    },
};

const metadata_float = TypeMetadata{
    .zig_type = f32,
    .kind = .primitive,
    .js_type = "number",
    .union_members = null,
    .inner_types = null,
    .conversion = .{
        .from_js = @ptrCast(&primitives.toFloat),
        .from_js_sig = .{
            .needs_allocator = false,
            .needs_type_param = false,
            .needs_extended_attrs = false,
            .param_types = &[_]type{primitives.JSValue},
            .return_type = f32,
            .errors = null,
        },
        .to_js = null,
        .to_js_sig = null,
    },
};

const metadata_unrestricted_float = TypeMetadata{
    .zig_type = f32,
    .kind = .primitive,
    .js_type = "number",
    .union_members = null,
    .inner_types = null,
    .conversion = .{
        .from_js = @ptrCast(&primitives.toUnrestrictedFloat),
        .from_js_sig = .{
            .needs_allocator = false,
            .needs_type_param = false,
            .needs_extended_attrs = false,
            .param_types = &[_]type{primitives.JSValue},
            .return_type = f32,
            .errors = null,
        },
        .to_js = null,
        .to_js_sig = null,
    },
};

const metadata_double = TypeMetadata{
    .zig_type = f64,
    .kind = .primitive,
    .js_type = "number",
    .union_members = null,
    .inner_types = null,
    .conversion = .{
        .from_js = @ptrCast(&primitives.toDouble),
        .from_js_sig = .{
            .needs_allocator = false,
            .needs_type_param = false,
            .needs_extended_attrs = false,
            .param_types = &[_]type{primitives.JSValue},
            .return_type = f64,
            .errors = null,
        },
        .to_js = null,
        .to_js_sig = null,
    },
};

const metadata_unrestricted_double = TypeMetadata{
    .zig_type = f64,
    .kind = .primitive,
    .js_type = "number",
    .union_members = null,
    .inner_types = null,
    .conversion = .{
        .from_js = @ptrCast(&primitives.toUnrestrictedDouble),
        .from_js_sig = .{
            .needs_allocator = false,
            .needs_type_param = false,
            .needs_extended_attrs = false,
            .param_types = &[_]type{primitives.JSValue},
            .return_type = f64,
            .errors = null,
        },
        .to_js = null,
        .to_js_sig = null,
    },
};

const metadata_bigint = TypeMetadata{
    .zig_type = bigint_mod.BigInt,
    .kind = .bigint,
    .js_type = "bigint",
    .union_members = null,
    .inner_types = null,
    .conversion = .{
        .from_js = @ptrCast(&bigint_mod.toBigInt),
        .from_js_sig = .{
            .needs_allocator = true,
            .needs_type_param = false,
            .needs_extended_attrs = false,
            .param_types = &[_]type{ std.mem.Allocator, primitives.JSValue },
            .return_type = bigint_mod.BigInt,
            .errors = &[_]type{std.mem.Allocator.Error},
        },
        .to_js = null,
        .to_js_sig = null,
    },
};

// String Types
const metadata_DOMString = TypeMetadata{
    .zig_type = strings.DOMString,
    .kind = .string,
    .js_type = "string",
    .union_members = null,
    .inner_types = null,
    .conversion = .{
        .from_js = @ptrCast(&strings.toDOMString),
        .from_js_sig = .{
            .needs_allocator = true,
            .needs_type_param = false,
            .needs_extended_attrs = false,
            .param_types = &[_]type{ std.mem.Allocator, primitives.JSValue },
            .return_type = strings.DOMString,
            .errors = &[_]type{std.mem.Allocator.Error},
        },
        .to_js = null,
        .to_js_sig = null,
    },
};

const metadata_ByteString = TypeMetadata{
    .zig_type = strings.ByteString,
    .kind = .string,
    .js_type = "string",
    .union_members = null,
    .inner_types = null,
    .conversion = .{
        .from_js = @ptrCast(&strings.toByteString),
        .from_js_sig = .{
            .needs_allocator = true,
            .needs_type_param = false,
            .needs_extended_attrs = false,
            .param_types = &[_]type{ std.mem.Allocator, primitives.JSValue },
            .return_type = strings.ByteString,
            .errors = &[_]type{std.mem.Allocator.Error},
        },
        .to_js = null,
        .to_js_sig = null,
    },
};

const metadata_USVString = TypeMetadata{
    .zig_type = strings.USVString,
    .kind = .string,
    .js_type = "string",
    .union_members = null,
    .inner_types = null,
    .conversion = .{
        .from_js = @ptrCast(&strings.toUSVString),
        .from_js_sig = .{
            .needs_allocator = true,
            .needs_type_param = false,
            .needs_extended_attrs = false,
            .param_types = &[_]type{ std.mem.Allocator, primitives.JSValue },
            .return_type = strings.USVString,
            .errors = &[_]type{std.mem.Allocator.Error},
        },
        .to_js = null,
        .to_js_sig = null,
    },
};

// Special Types
const metadata_any = TypeMetadata{
    .zig_type = primitives.JSValue,
    .kind = .any,
    .js_type = "any",
    .union_members = null,
    .inner_types = null,
    .conversion = null,
};

const metadata_undefined = TypeMetadata{
    .zig_type = void,
    .kind = .undefined,
    .js_type = "undefined",
    .union_members = null,
    .inner_types = null,
    .conversion = null,
};

const metadata_object = TypeMetadata{
    .zig_type = *anyopaque,
    .kind = .object,
    .js_type = "object",
    .union_members = null,
    .inner_types = null,
    .conversion = null,
};

const metadata_symbol = TypeMetadata{
    .zig_type = *anyopaque,
    .kind = .symbol,
    .js_type = "symbol",
    .union_members = null,
    .inner_types = null,
    .conversion = null,
};

// Buffer Types
const metadata_ArrayBuffer = TypeMetadata{
    .zig_type = buffer_sources.ArrayBuffer,
    .kind = .buffer,
    .js_type = "object",
    .union_members = null,
    .inner_types = null,
    .conversion = null, // TODO: Add conversion functions
};

const metadata_SharedArrayBuffer = TypeMetadata{
    .zig_type = buffer_sources.SharedArrayBuffer,
    .kind = .buffer,
    .js_type = "object",
    .union_members = null,
    .inner_types = null,
    .conversion = null,
};

const metadata_DataView = TypeMetadata{
    .zig_type = buffer_sources.DataView,
    .kind = .buffer_view,
    .js_type = "object",
    .union_members = null,
    .inner_types = null,
    .conversion = null,
};

// Typed Array Types
const metadata_Int8Array = TypeMetadata{
    .zig_type = buffer_sources.TypedArray(i8),
    .kind = .typed_array,
    .js_type = "object",
    .union_members = null,
    .inner_types = null,
    .conversion = null,
};

const metadata_Uint8Array = TypeMetadata{
    .zig_type = buffer_sources.TypedArray(u8),
    .kind = .typed_array,
    .js_type = "object",
    .union_members = null,
    .inner_types = null,
    .conversion = null,
};

const metadata_Uint8ClampedArray = TypeMetadata{
    .zig_type = buffer_sources.TypedArray(u8),
    .kind = .typed_array,
    .js_type = "object",
    .union_members = null,
    .inner_types = null,
    .conversion = null,
};

const metadata_Int16Array = TypeMetadata{
    .zig_type = buffer_sources.TypedArray(i16),
    .kind = .typed_array,
    .js_type = "object",
    .union_members = null,
    .inner_types = null,
    .conversion = null,
};

const metadata_Uint16Array = TypeMetadata{
    .zig_type = buffer_sources.TypedArray(u16),
    .kind = .typed_array,
    .js_type = "object",
    .union_members = null,
    .inner_types = null,
    .conversion = null,
};

const metadata_Int32Array = TypeMetadata{
    .zig_type = buffer_sources.TypedArray(i32),
    .kind = .typed_array,
    .js_type = "object",
    .union_members = null,
    .inner_types = null,
    .conversion = null,
};

const metadata_Uint32Array = TypeMetadata{
    .zig_type = buffer_sources.TypedArray(u32),
    .kind = .typed_array,
    .js_type = "object",
    .union_members = null,
    .inner_types = null,
    .conversion = null,
};

const metadata_Int64Array = TypeMetadata{
    .zig_type = buffer_sources.TypedArray(i64),
    .kind = .typed_array,
    .js_type = "object",
    .union_members = null,
    .inner_types = null,
    .conversion = null,
};

const metadata_Uint64Array = TypeMetadata{
    .zig_type = buffer_sources.TypedArray(u64),
    .kind = .typed_array,
    .js_type = "object",
    .union_members = null,
    .inner_types = null,
    .conversion = null,
};

const metadata_BigInt64Array = TypeMetadata{
    .zig_type = buffer_sources.BigInt64Array,
    .kind = .typed_array,
    .js_type = "object",
    .union_members = null,
    .inner_types = null,
    .conversion = null,
};

const metadata_BigUint64Array = TypeMetadata{
    .zig_type = buffer_sources.BigUint64Array,
    .kind = .typed_array,
    .js_type = "object",
    .union_members = null,
    .inner_types = null,
    .conversion = null,
};

const metadata_Float32Array = TypeMetadata{
    .zig_type = buffer_sources.TypedArray(f32),
    .kind = .typed_array,
    .js_type = "object",
    .union_members = null,
    .inner_types = null,
    .conversion = null,
};

const metadata_Float64Array = TypeMetadata{
    .zig_type = buffer_sources.TypedArray(f64),
    .kind = .typed_array,
    .js_type = "object",
    .union_members = null,
    .inner_types = null,
    .conversion = null,
};

// Union Typedefs
const metadata_ArrayBufferView = TypeMetadata{
    .zig_type = buffer_sources.ArrayBufferView,
    .kind = .union_type,
    .js_type = "object",
    .union_members = &[_][]const u8{
        "Int8Array",         "Int16Array",    "Int32Array",
        "Uint8Array",        "Uint16Array",   "Uint32Array",
        "Uint8ClampedArray", "BigInt64Array", "BigUint64Array",
        "Float32Array",      "Float64Array",  "DataView",
    },
    .inner_types = null,
    .conversion = null,
};

const metadata_BufferSource = TypeMetadata{
    .zig_type = buffer_sources.BufferSource,
    .kind = .union_type,
    .js_type = "object",
    .union_members = &[_][]const u8{ "ArrayBufferView", "ArrayBuffer" },
    .inner_types = null,
    .conversion = null,
};

const metadata_AllowSharedBufferSource = TypeMetadata{
    .zig_type = buffer_sources.AllowSharedBufferSource,
    .kind = .union_type,
    .js_type = "object",
    .union_members = &[_][]const u8{ "ArrayBuffer", "SharedArrayBuffer", "ArrayBufferView" },
    .inner_types = null,
    .conversion = null,
};

// Generic Containers
const metadata_sequence = TypeMetadata{
    .zig_type = type, // Generic function, not a concrete type
    .kind = .sequence,
    .js_type = "object",
    .union_members = null,
    .inner_types = &[_][]const u8{"T"},
    .conversion = null, // Generic conversion handled by instantiation
};

const metadata_record = TypeMetadata{
    .zig_type = type,
    .kind = .record,
    .js_type = "object",
    .union_members = null,
    .inner_types = &[_][]const u8{ "K", "V" },
    .conversion = null,
};

const metadata_FrozenArray = TypeMetadata{
    .zig_type = type,
    .kind = .frozen_array,
    .js_type = "object",
    .union_members = null,
    .inner_types = &[_][]const u8{"T"},
    .conversion = null,
};

const metadata_ObservableArray = TypeMetadata{
    .zig_type = type,
    .kind = .observable_array,
    .js_type = "object",
    .union_members = null,
    .inner_types = &[_][]const u8{"T"},
    .conversion = null,
};

const metadata_Promise = TypeMetadata{
    .zig_type = type,
    .kind = .promise,
    .js_type = "object",
    .union_members = null,
    .inner_types = &[_][]const u8{"T"},
    .conversion = null,
};

const metadata_nullable = TypeMetadata{
    .zig_type = type,
    .kind = .nullable,
    .js_type = "any", // Can be null or the inner type's JS type
    .union_members = null,
    .inner_types = &[_][]const u8{"T"},
    .conversion = null,
};

// Error Types
const metadata_DOMException = TypeMetadata{
    .zig_type = errors.DOMException,
    .kind = .interface,
    .js_type = "object",
    .union_members = null,
    .inner_types = null,
    .conversion = null,
};
