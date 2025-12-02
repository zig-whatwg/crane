//! Structured Clone Types
//!
//! Type definitions for the structured clone algorithm per HTML Standard §2.7.
//! https://html.spec.whatwg.org/#safe-passing-of-structured-data
//!
//! ## Overview
//!
//! This module defines the core types used by the structured clone algorithm:
//! - `SerializedValue`: The realm-independent serialized representation
//! - `SerializationType`: Enum of all serializable types
//! - `CloneError`: Error types for cloning failures
//! - `Transferable`: Union of all transferable object types
//!
//! ## Spec Reference
//!
//! HTML Standard §2.7.3 StructuredSerializeInternal defines the serialized format.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Error types for structured clone operations
///
/// Per HTML Standard §2.7.3, cloning can fail with:
/// - DataCloneError: Value is not cloneable (functions, symbols, DOM nodes, etc.)
/// - TransferError: Transfer operation failed
/// - DeserializeError: Serialized data is invalid
pub const CloneError = error{
    /// Value cannot be cloned (functions, symbols, WeakMap, WeakSet, etc.)
    DataCloneError,
    /// Transfer operation failed (already detached, etc.)
    TransferError,
    /// Deserialization failed (invalid or corrupted data)
    DeserializeError,
    /// Memory allocation failed
    OutOfMemory,
    /// Buffer is detached and cannot be accessed
    DetachedBuffer,
    /// Cross-origin restriction prevents cloning
    CrossOriginError,
};

/// Serialization type identifiers
///
/// Per HTML Standard §2.7.3, the [[Type]] field identifies the serialized value type.
pub const SerializationType = enum {
    // Primitives (step 4)
    primitive,

    // Boxed primitives (steps 7-10)
    boolean_object,
    number_object,
    bigint_object,
    string_object,

    // Date (step 11)
    date,

    // RegExp (step 12)
    regexp,

    // ArrayBuffer variants (step 13)
    array_buffer,
    resizable_array_buffer,
    shared_array_buffer,
    growable_shared_array_buffer,

    // ArrayBufferView (step 14)
    array_buffer_view,

    // Map (step 15)
    map,

    // Set (step 16)
    set,

    // Error (step 17)
    error_object,

    // Array (step 18)
    array,

    // Plain object (step 24)
    object,

    // Platform objects (step 19)
    // These use the interface name as the type string
    blob,
    file,
    file_list,
    image_bitmap,
    image_data,
    message_port,
    readable_stream,
    writable_stream,
    transform_stream,
    offscreen_canvas,
    audio_data,
    video_frame,
    dom_exception,
    dom_point,
    dom_point_readonly,
    dom_rect,
    dom_rect_readonly,
    dom_matrix,
    dom_matrix_readonly,
    dom_quad,
    crypto_key,
};

/// Error name for Error objects
///
/// Per HTML Standard §2.7.3 step 17, only specific error types are preserved.
pub const ErrorName = enum {
    Error,
    EvalError,
    RangeError,
    ReferenceError,
    SyntaxError,
    TypeError,
    URIError,

    /// Parse error name from string, defaulting to "Error"
    pub fn fromString(name: []const u8) ErrorName {
        if (std.mem.eql(u8, name, "EvalError")) return .EvalError;
        if (std.mem.eql(u8, name, "RangeError")) return .RangeError;
        if (std.mem.eql(u8, name, "ReferenceError")) return .ReferenceError;
        if (std.mem.eql(u8, name, "SyntaxError")) return .SyntaxError;
        if (std.mem.eql(u8, name, "TypeError")) return .TypeError;
        if (std.mem.eql(u8, name, "URIError")) return .URIError;
        return .Error;
    }

    pub fn toString(self: ErrorName) []const u8 {
        return switch (self) {
            .Error => "Error",
            .EvalError => "EvalError",
            .RangeError => "RangeError",
            .ReferenceError => "ReferenceError",
            .SyntaxError => "SyntaxError",
            .TypeError => "TypeError",
            .URIError => "URIError",
        };
    }
};

/// Typed array constructor names
///
/// Per HTML Standard §2.7.3 step 14.6, these identify TypedArray types.
pub const TypedArrayConstructor = enum {
    Int8Array,
    Uint8Array,
    Uint8ClampedArray,
    Int16Array,
    Uint16Array,
    Int32Array,
    Uint32Array,
    Float32Array,
    Float64Array,
    BigInt64Array,
    BigUint64Array,
    DataView,

    pub fn fromString(name: []const u8) ?TypedArrayConstructor {
        const map = std.StaticStringMap(TypedArrayConstructor).initComptime(.{
            .{ "Int8Array", .Int8Array },
            .{ "Uint8Array", .Uint8Array },
            .{ "Uint8ClampedArray", .Uint8ClampedArray },
            .{ "Int16Array", .Int16Array },
            .{ "Uint16Array", .Uint16Array },
            .{ "Int32Array", .Int32Array },
            .{ "Uint32Array", .Uint32Array },
            .{ "Float32Array", .Float32Array },
            .{ "Float64Array", .Float64Array },
            .{ "BigInt64Array", .BigInt64Array },
            .{ "BigUint64Array", .BigUint64Array },
            .{ "DataView", .DataView },
        });
        return map.get(name);
    }

    pub fn elementSize(self: TypedArrayConstructor) usize {
        return switch (self) {
            .Int8Array, .Uint8Array, .Uint8ClampedArray => 1,
            .Int16Array, .Uint16Array => 2,
            .Int32Array, .Uint32Array, .Float32Array => 4,
            .Float64Array, .BigInt64Array, .BigUint64Array => 8,
            .DataView => 1, // DataView doesn't have fixed element size
        };
    }
};

/// Primitive value types that can be directly serialized
pub const PrimitiveValue = union(enum) {
    undefined: void,
    null: void,
    boolean: bool,
    number: f64,
    bigint: i128, // Simplified; real impl would use arbitrary precision
    string: []const u8,
};

/// Serialized value record
///
/// Per HTML Standard §2.7.3, this represents the realm-independent form of a value.
/// The structure varies based on [[Type]].
pub const SerializedValue = struct {
    type: SerializationType,
    allocator: Allocator,

    // Fields depend on type - using tagged union for type safety
    data: SerializedData,

    pub const SerializedData = union(SerializationType) {
        // Primitives
        primitive: PrimitiveValue,

        // Boxed primitives
        boolean_object: bool,
        number_object: f64,
        bigint_object: i128,
        string_object: []const u8,

        // Date
        date: f64, // [[DateValue]] - milliseconds since epoch

        // RegExp
        regexp: RegExpData,

        // ArrayBuffer variants
        array_buffer: ArrayBufferData,
        resizable_array_buffer: ResizableArrayBufferData,
        shared_array_buffer: SharedArrayBufferData,
        growable_shared_array_buffer: GrowableSharedArrayBufferData,

        // ArrayBufferView
        array_buffer_view: ArrayBufferViewData,

        // Map
        map: MapData,

        // Set
        set: SetData,

        // Error
        error_object: ErrorData,

        // Array
        array: ArrayData,

        // Object
        object: ObjectData,

        // Platform objects - each has its own serialization
        blob: BlobData,
        file: FileData,
        file_list: FileListData,
        image_bitmap: ImageBitmapData,
        image_data: ImageDataData,
        message_port: void, // MessagePort is transferable-only
        readable_stream: void, // Streams are transferable-only
        writable_stream: void,
        transform_stream: void,
        offscreen_canvas: void,
        audio_data: void,
        video_frame: void,
        dom_exception: DOMExceptionData,
        dom_point: DOMPointData,
        dom_point_readonly: DOMPointData,
        dom_rect: DOMRectData,
        dom_rect_readonly: DOMRectData,
        dom_matrix: DOMMatrixData,
        dom_matrix_readonly: DOMMatrixData,
        dom_quad: DOMQuadData,
        crypto_key: void, // CryptoKey has special handling
    };

    pub fn deinit(self: *SerializedValue) void {
        switch (self.data) {
            .primitive => |p| {
                if (p == .string) {
                    self.allocator.free(p.string);
                }
            },
            .string_object => |s| self.allocator.free(s),
            .array_buffer => |ab| self.allocator.free(ab.data),
            .resizable_array_buffer => |rab| self.allocator.free(rab.data),
            .array_buffer_view => |view| {
                if (view.buffer_serialized) |buf| {
                    var mutable_buf = @constCast(buf);
                    mutable_buf.deinit();
                    self.allocator.destroy(mutable_buf);
                }
            },
            .map => |m| {
                for (m.entries.items) |entry| {
                    var mutable_key = @constCast(entry.key);
                    mutable_key.deinit();
                    self.allocator.destroy(mutable_key);
                    var mutable_value = @constCast(entry.value);
                    mutable_value.deinit();
                    self.allocator.destroy(mutable_value);
                }
                @constCast(&m.entries).deinit();
            },
            .set => |s| {
                for (s.entries.items) |entry| {
                    var mutable_entry = @constCast(entry);
                    mutable_entry.deinit();
                    self.allocator.destroy(mutable_entry);
                }
                @constCast(&s.entries).deinit();
            },
            .error_object => |e| {
                if (e.message) |msg| self.allocator.free(msg);
                if (e.stack) |stack| self.allocator.free(stack);
            },
            .array => |a| {
                for (a.properties.items) |prop| {
                    self.allocator.free(prop.key);
                    var mutable_value = @constCast(prop.value);
                    mutable_value.deinit();
                    self.allocator.destroy(mutable_value);
                }
                @constCast(&a.properties).deinit();
            },
            .object => |o| {
                for (o.properties.items) |prop| {
                    self.allocator.free(prop.key);
                    var mutable_value = @constCast(prop.value);
                    mutable_value.deinit();
                    self.allocator.destroy(mutable_value);
                }
                @constCast(&o.properties).deinit();
            },
            .blob => |b| {
                self.allocator.free(b.data);
                self.allocator.free(b.content_type);
            },
            .file => |f| {
                self.allocator.free(f.data);
                self.allocator.free(f.name);
                self.allocator.free(f.content_type);
            },
            .file_list => |fl| {
                for (fl.files.items) |file| {
                    var mutable_file = @constCast(file);
                    mutable_file.deinit();
                    self.allocator.destroy(mutable_file);
                }
                @constCast(&fl.files).deinit();
            },
            else => {},
        }
    }
};

/// RegExp serialization data
pub const RegExpData = struct {
    source: []const u8,
    flags: []const u8,
};

/// ArrayBuffer serialization data
pub const ArrayBufferData = struct {
    data: []u8,
    byte_length: usize,
};

/// Resizable ArrayBuffer serialization data
pub const ResizableArrayBufferData = struct {
    data: []u8,
    byte_length: usize,
    max_byte_length: usize,
};

/// SharedArrayBuffer serialization data
pub const SharedArrayBufferData = struct {
    data: []u8,
    byte_length: usize,
    agent_cluster: u64, // Identifier for the agent cluster
};

/// Growable SharedArrayBuffer serialization data
pub const GrowableSharedArrayBufferData = struct {
    data: []u8,
    byte_length_data: *usize, // Shared mutable length
    max_byte_length: usize,
    agent_cluster: u64,
};

/// ArrayBufferView serialization data
pub const ArrayBufferViewData = struct {
    constructor: TypedArrayConstructor,
    buffer_serialized: ?*const SerializedValue,
    byte_length: usize,
    byte_offset: usize,
    array_length: ?usize, // Only for TypedArrays, not DataView
};

/// Map serialization data
pub const MapData = struct {
    entries: std.ArrayList(MapEntry),

    pub const MapEntry = struct {
        key: *const SerializedValue,
        value: *const SerializedValue,
    };
};

/// Set serialization data
pub const SetData = struct {
    entries: std.ArrayList(*const SerializedValue),
};

/// Error serialization data
pub const ErrorData = struct {
    name: ErrorName,
    message: ?[]const u8,
    stack: ?[]const u8, // Optional stack trace
};

/// Array serialization data
pub const ArrayData = struct {
    length: usize,
    properties: std.ArrayList(PropertyEntry),
};

/// Object serialization data
pub const ObjectData = struct {
    properties: std.ArrayList(PropertyEntry),
};

/// Property entry for objects and arrays
pub const PropertyEntry = struct {
    key: []const u8,
    value: *const SerializedValue,
};

/// Blob serialization data
pub const BlobData = struct {
    data: []const u8,
    content_type: []const u8,
};

/// File serialization data
pub const FileData = struct {
    data: []const u8,
    name: []const u8,
    content_type: []const u8,
    last_modified: i64, // Milliseconds since epoch
};

/// FileList serialization data
pub const FileListData = struct {
    files: std.ArrayList(*const SerializedValue),
};

/// ImageBitmap serialization data
pub const ImageBitmapData = struct {
    width: u32,
    height: u32,
    // Image data would be stored here
    origin_clean: bool,
};

/// ImageData serialization data
pub const ImageDataData = struct {
    width: u32,
    height: u32,
    data: []const u8, // RGBA pixel data
    color_space: []const u8,
};

/// DOMException serialization data
pub const DOMExceptionData = struct {
    name: []const u8,
    message: []const u8,
};

/// DOMPoint serialization data
pub const DOMPointData = struct {
    x: f64,
    y: f64,
    z: f64,
    w: f64,
};

/// DOMRect serialization data
pub const DOMRectData = struct {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
};

/// DOMMatrix serialization data (4x4 matrix)
pub const DOMMatrixData = struct {
    values: [16]f64,
    is_2d: bool,
};

/// DOMQuad serialization data
pub const DOMQuadData = struct {
    p1: DOMPointData,
    p2: DOMPointData,
    p3: DOMPointData,
    p4: DOMPointData,
};

/// Transfer data holder for transferable objects
///
/// Per HTML Standard §2.7.6, this holds data during transfer.
pub const TransferDataHolder = struct {
    type: SerializationType,
    data: TransferData,

    pub const TransferData = union(enum) {
        array_buffer: ArrayBufferData,
        resizable_array_buffer: ResizableArrayBufferData,
        message_port: MessagePortTransfer,
        readable_stream: StreamTransfer,
        writable_stream: StreamTransfer,
        transform_stream: TransformStreamTransfer,
        image_bitmap: ImageBitmapTransfer,
        offscreen_canvas: OffscreenCanvasTransfer,
        audio_data: void,
        video_frame: void,
    };
};

/// MessagePort transfer data
pub const MessagePortTransfer = struct {
    port_id: u64,
    // Additional state for port entanglement
};

/// Stream transfer data
pub const StreamTransfer = struct {
    // Cross-realm transform setup data
    port: MessagePortTransfer,
};

/// TransformStream transfer data
pub const TransformStreamTransfer = struct {
    readable: StreamTransfer,
    writable: StreamTransfer,
};

/// ImageBitmap transfer data
pub const ImageBitmapTransfer = struct {
    width: u32,
    height: u32,
    // The actual image data is transferred, not copied
};

/// OffscreenCanvas transfer data
pub const OffscreenCanvasTransfer = struct {
    width: u32,
    height: u32,
    // The canvas context is transferred
};

/// Result of StructuredSerializeWithTransfer
pub const SerializeWithTransferResult = struct {
    serialized: *SerializedValue,
    transfer_data_holders: std.ArrayList(TransferDataHolder),
    allocator: Allocator,

    pub fn deinit(self: *SerializeWithTransferResult) void {
        self.serialized.deinit();
        self.allocator.destroy(self.serialized);
        self.transfer_data_holders.deinit();
    }
};

/// Result of StructuredDeserializeWithTransfer
pub const DeserializeWithTransferResult = struct {
    deserialized: *anyopaque, // The deserialized JavaScript value
    transferred_values: std.ArrayList(*anyopaque),
};

test "ErrorName.fromString" {
    const testing = std.testing;
    try testing.expectEqual(ErrorName.TypeError, ErrorName.fromString("TypeError"));
    try testing.expectEqual(ErrorName.RangeError, ErrorName.fromString("RangeError"));
    try testing.expectEqual(ErrorName.Error, ErrorName.fromString("CustomError"));
}

test "TypedArrayConstructor.elementSize" {
    const testing = std.testing;
    try testing.expectEqual(@as(usize, 1), TypedArrayConstructor.Uint8Array.elementSize());
    try testing.expectEqual(@as(usize, 4), TypedArrayConstructor.Float32Array.elementSize());
    try testing.expectEqual(@as(usize, 8), TypedArrayConstructor.Float64Array.elementSize());
}
