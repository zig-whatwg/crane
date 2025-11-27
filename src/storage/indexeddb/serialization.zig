//! IndexedDB Structured Clone Implementation
//!
//! Implements the HTML Standard's Structured Clone algorithm for IndexedDB.
//! https://html.spec.whatwg.org/multipage/structured-data.html
//!
//! ## Overview
//!
//! The Structured Clone algorithm serializes JavaScript values into a
//! realm-independent form that can be stored in IndexedDB and later
//! deserialized. This implementation focuses on the subset relevant
//! to IndexedDB storage (StructuredSerializeForStorage).
//!
//! ## Supported Types
//!
//! - Primitives: undefined, null, boolean, number, bigint, string
//! - Objects: Date, RegExp, ArrayBuffer, TypedArrays, DataView
//! - Collections: Array, Object, Map, Set
//! - Errors: Error and subtypes
//! - Platform objects with [Serializable] (e.g., Blob, File, FileList)
//!
//! ## Not Serializable (throw DataCloneError)
//!
//! - Symbol
//! - Function
//! - DOM nodes
//! - SharedArrayBuffer (for storage)
//! - WeakMap, WeakSet
//! - Proxy
//!
//! ## Spec Reference
//!
//! - StructuredSerializeInternal: §2.7.3
//! - StructuredDeserialize: §2.7.5
//! - StructuredSerializeForStorage: §2.7.4 (used by IndexedDB)

const std = @import("std");
const IDBError = @import("errors.zig").IDBError;

/// Type tags for serialized values
/// These correspond to the [[Type]] field in the spec's serialization records
pub const SerializedType = enum(u8) {
    // Primitives
    primitive_undefined = 0,
    primitive_null = 1,
    primitive_boolean = 2,
    primitive_number = 3,
    primitive_bigint = 4,
    primitive_string = 5,

    // Boxed primitives
    boolean_object = 10,
    number_object = 11,
    bigint_object = 12,
    string_object = 13,

    // Built-in objects
    date = 20,
    regexp = 21,

    // Binary data
    array_buffer = 30,
    resizable_array_buffer = 31,
    shared_array_buffer = 32, // Only for non-storage serialization
    growable_shared_array_buffer = 33, // Only for non-storage serialization
    array_buffer_view = 34,

    // Collections
    array = 40,
    object = 41,
    map = 42,
    set = 43,

    // Errors
    @"error" = 50,

    // Platform objects (extensible)
    blob = 60,
    file = 61,
    file_list = 62,
    image_data = 63,
    image_bitmap = 64,
    dom_exception = 65,
    crypto_key = 66,

    // Marker for circular reference (internal use)
    reference = 255,
};

/// TypedArray constructor names
pub const TypedArrayConstructor = enum(u8) {
    DataView = 0,
    Int8Array = 1,
    Uint8Array = 2,
    Uint8ClampedArray = 3,
    Int16Array = 4,
    Uint16Array = 5,
    Int32Array = 6,
    Uint32Array = 7,
    Float32Array = 8,
    Float64Array = 9,
    BigInt64Array = 10,
    BigUint64Array = 11,
};

/// Error type names for serialized errors
pub const ErrorName = enum(u8) {
    Error = 0,
    EvalError = 1,
    RangeError = 2,
    ReferenceError = 3,
    SyntaxError = 4,
    TypeError = 5,
    URIError = 6,
};

/// A serialized value record
/// This is the Zig representation of the spec's serialization record
pub const SerializedValue = struct {
    /// The type tag
    type_tag: SerializedType,

    /// Serialized data (type-specific)
    data: SerializedData,

    /// For collections/objects: nested properties
    properties: ?[]Property = null,

    /// For Map: key-value pairs
    map_data: ?[]MapEntry = null,

    /// For Set: values
    set_data: ?[]SerializedValue = null,

    /// Allocator used for owned data
    allocator: ?std.mem.Allocator = null,

    pub const Property = struct {
        key: []const u8,
        value: SerializedValue,
    };

    pub const MapEntry = struct {
        key: SerializedValue,
        value: SerializedValue,
    };

    /// Clean up allocated memory
    pub fn deinit(self: *SerializedValue) void {
        const alloc = self.allocator orelse return;

        // Clean up data based on type
        switch (self.type_tag) {
            .primitive_string, .string_object => {
                if (self.data.string.len > 0) {
                    alloc.free(self.data.string);
                }
            },
            .primitive_bigint, .bigint_object => {
                if (self.data.bigint.len > 0) {
                    alloc.free(self.data.bigint);
                }
            },
            .regexp => {
                if (self.data.regexp.source.len > 0) {
                    alloc.free(self.data.regexp.source);
                }
                if (self.data.regexp.flags.len > 0) {
                    alloc.free(self.data.regexp.flags);
                }
            },
            .array_buffer, .resizable_array_buffer => {
                if (self.data.array_buffer.data.len > 0) {
                    alloc.free(self.data.array_buffer.data);
                }
            },
            .@"error" => {
                if (self.data.@"error".message) |msg| {
                    if (msg.len > 0) {
                        alloc.free(msg);
                    }
                }
            },
            else => {},
        }

        // Clean up properties
        if (self.properties) |props| {
            for (props) |*prop| {
                alloc.free(prop.key);
                var val = prop.value;
                val.deinit();
            }
            alloc.free(props);
        }

        // Clean up map data
        if (self.map_data) |entries| {
            for (entries) |*entry| {
                var k = entry.key;
                k.deinit();
                var v = entry.value;
                v.deinit();
            }
            alloc.free(entries);
        }

        // Clean up set data
        if (self.set_data) |items| {
            for (items) |*item| {
                var i = item.*;
                i.deinit();
            }
            alloc.free(items);
        }
    }
};

/// Type-specific serialized data
pub const SerializedData = union {
    /// No data (undefined, null)
    none: void,

    /// Boolean value
    boolean: bool,

    /// Number value (IEEE 754 double)
    number: f64,

    /// BigInt bytes (two's complement, little-endian)
    bigint: []const u8,

    /// String value (UTF-8)
    string: []const u8,

    /// Date value (milliseconds since epoch)
    date: i64,

    /// RegExp data
    regexp: RegExpData,

    /// ArrayBuffer data
    array_buffer: ArrayBufferData,

    /// ArrayBufferView data
    array_buffer_view: ArrayBufferViewData,

    /// Array length (properties stored separately)
    array_length: u32,

    /// Error data
    @"error": ErrorData,

    /// Reference index (for circular references)
    reference_index: u32,

    /// Blob data
    blob: BlobData,

    /// File data
    file: FileData,
};

pub const RegExpData = struct {
    source: []const u8,
    flags: []const u8,
};

pub const ArrayBufferData = struct {
    data: []const u8,
    max_byte_length: ?u32 = null, // For resizable buffers
};

pub const ArrayBufferViewData = struct {
    constructor: TypedArrayConstructor,
    buffer_index: u32, // Index into memory map for the buffer
    byte_length: u32,
    byte_offset: u32,
    array_length: ?u32 = null, // For TypedArrays (not DataView)
};

pub const ErrorData = struct {
    name: ErrorName,
    message: ?[]const u8,
};

pub const BlobData = struct {
    type: []const u8,
    size: u64,
    // In a real implementation, this would reference blob storage
    blob_id: ?u64 = null,
};

pub const FileData = struct {
    name: []const u8,
    type: []const u8,
    size: u64,
    last_modified: i64,
    // In a real implementation, this would reference file storage
    file_id: ?u64 = null,
};

/// Structured Clone Serializer
/// Implements StructuredSerializeInternal from the HTML spec
pub const Serializer = struct {
    allocator: std.mem.Allocator,

    /// Memory map for cycle detection (object identity -> index)
    /// In a real JS integration, this would map JS object references
    memory: std.AutoHashMap(usize, u32),

    /// List of serialized objects (for reference resolution)
    serialized_objects: std.ArrayList(SerializedValue),

    /// Whether serializing for storage (affects SharedArrayBuffer handling)
    for_storage: bool,

    pub fn init(allocator: std.mem.Allocator, for_storage: bool) Serializer {
        return .{
            .allocator = allocator,
            .memory = std.AutoHashMap(usize, u32).init(allocator),
            .serialized_objects = .empty,
            .for_storage = for_storage,
        };
    }

    pub fn deinit(self: *Serializer) void {
        self.memory.deinit();
        for (self.serialized_objects.items) |*item| {
            item.deinit();
        }
        self.serialized_objects.deinit(self.allocator);
    }

    /// Serialize a primitive undefined value
    pub fn serializeUndefined(self: *Serializer) SerializedValue {
        _ = self;
        return .{
            .type_tag = .primitive_undefined,
            .data = .{ .none = {} },
        };
    }

    /// Serialize a primitive null value
    pub fn serializeNull(self: *Serializer) SerializedValue {
        _ = self;
        return .{
            .type_tag = .primitive_null,
            .data = .{ .none = {} },
        };
    }

    /// Serialize a primitive boolean value
    pub fn serializeBoolean(self: *Serializer, value: bool) SerializedValue {
        _ = self;
        return .{
            .type_tag = .primitive_boolean,
            .data = .{ .boolean = value },
        };
    }

    /// Serialize a primitive number value
    pub fn serializeNumber(self: *Serializer, value: f64) SerializedValue {
        _ = self;
        return .{
            .type_tag = .primitive_number,
            .data = .{ .number = value },
        };
    }

    /// Serialize a primitive string value
    pub fn serializeString(self: *Serializer, value: []const u8) !SerializedValue {
        const owned = try self.allocator.dupe(u8, value);
        return .{
            .type_tag = .primitive_string,
            .data = .{ .string = owned },
            .allocator = self.allocator,
        };
    }

    /// Serialize a primitive BigInt value (as bytes)
    pub fn serializeBigInt(self: *Serializer, bytes: []const u8) !SerializedValue {
        const owned = try self.allocator.dupe(u8, bytes);
        return .{
            .type_tag = .primitive_bigint,
            .data = .{ .bigint = owned },
            .allocator = self.allocator,
        };
    }

    /// Serialize a Date object
    pub fn serializeDate(self: *Serializer, timestamp: i64) SerializedValue {
        _ = self;
        return .{
            .type_tag = .date,
            .data = .{ .date = timestamp },
        };
    }

    /// Serialize a RegExp object
    pub fn serializeRegExp(self: *Serializer, source: []const u8, flags: []const u8) !SerializedValue {
        const owned_source = try self.allocator.dupe(u8, source);
        errdefer self.allocator.free(owned_source);
        const owned_flags = try self.allocator.dupe(u8, flags);
        return .{
            .type_tag = .regexp,
            .data = .{ .regexp = .{
                .source = owned_source,
                .flags = owned_flags,
            } },
            .allocator = self.allocator,
        };
    }

    /// Serialize an ArrayBuffer
    pub fn serializeArrayBuffer(self: *Serializer, data: []const u8) !SerializedValue {
        const owned = try self.allocator.dupe(u8, data);
        return .{
            .type_tag = .array_buffer,
            .data = .{ .array_buffer = .{
                .data = owned,
            } },
            .allocator = self.allocator,
        };
    }

    /// Serialize a resizable ArrayBuffer
    pub fn serializeResizableArrayBuffer(self: *Serializer, data: []const u8, max_byte_length: u32) !SerializedValue {
        const owned = try self.allocator.dupe(u8, data);
        return .{
            .type_tag = .resizable_array_buffer,
            .data = .{ .array_buffer = .{
                .data = owned,
                .max_byte_length = max_byte_length,
            } },
            .allocator = self.allocator,
        };
    }

    /// Check if SharedArrayBuffer can be serialized
    /// Per spec: throws DataCloneError if for_storage is true
    pub fn checkSharedArrayBuffer(self: *Serializer) IDBError!void {
        if (self.for_storage) {
            return IDBError.DataCloneError;
        }
        // Additional check: cross-origin isolated capability
        // This would be checked via the settings object in a real implementation
    }

    /// Serialize an Array
    pub fn serializeArray(self: *Serializer, length: u32, properties: []const SerializedValue.Property) !SerializedValue {
        const owned_props = try self.allocator.alloc(SerializedValue.Property, properties.len);
        errdefer self.allocator.free(owned_props);

        for (properties, 0..) |prop, i| {
            owned_props[i] = .{
                .key = try self.allocator.dupe(u8, prop.key),
                .value = prop.value,
            };
        }

        return .{
            .type_tag = .array,
            .data = .{ .array_length = length },
            .properties = owned_props,
            .allocator = self.allocator,
        };
    }

    /// Serialize a plain Object
    pub fn serializeObject(self: *Serializer, properties: []const SerializedValue.Property) !SerializedValue {
        const owned_props = try self.allocator.alloc(SerializedValue.Property, properties.len);
        errdefer self.allocator.free(owned_props);

        for (properties, 0..) |prop, i| {
            owned_props[i] = .{
                .key = try self.allocator.dupe(u8, prop.key),
                .value = prop.value,
            };
        }

        return .{
            .type_tag = .object,
            .data = .{ .none = {} },
            .properties = owned_props,
            .allocator = self.allocator,
        };
    }

    /// Serialize a Map
    pub fn serializeMap(self: *Serializer, entries: []const SerializedValue.MapEntry) !SerializedValue {
        const owned_entries = try self.allocator.alloc(SerializedValue.MapEntry, entries.len);
        errdefer self.allocator.free(owned_entries);

        for (entries, 0..) |entry, i| {
            owned_entries[i] = entry;
        }

        return .{
            .type_tag = .map,
            .data = .{ .none = {} },
            .map_data = owned_entries,
            .allocator = self.allocator,
        };
    }

    /// Serialize a Set
    pub fn serializeSet(self: *Serializer, items: []const SerializedValue) !SerializedValue {
        const owned_items = try self.allocator.alloc(SerializedValue, items.len);
        errdefer self.allocator.free(owned_items);

        for (items, 0..) |item, i| {
            owned_items[i] = item;
        }

        return .{
            .type_tag = .set,
            .data = .{ .none = {} },
            .set_data = owned_items,
            .allocator = self.allocator,
        };
    }

    /// Serialize an Error object
    pub fn serializeError(self: *Serializer, name: ErrorName, message: ?[]const u8) !SerializedValue {
        const owned_message = if (message) |msg|
            try self.allocator.dupe(u8, msg)
        else
            null;

        return .{
            .type_tag = .@"error",
            .data = .{ .@"error" = .{
                .name = name,
                .message = owned_message,
            } },
            .allocator = self.allocator,
        };
    }

    /// Create a reference to an already-serialized object (for cycles)
    pub fn serializeReference(self: *Serializer, index: u32) SerializedValue {
        _ = self;
        return .{
            .type_tag = .reference,
            .data = .{ .reference_index = index },
        };
    }

    /// Check if an object was already serialized (returns index if so)
    pub fn checkMemory(self: *Serializer, object_id: usize) ?u32 {
        return self.memory.get(object_id);
    }

    /// Add an object to the memory map
    pub fn addToMemory(self: *Serializer, object_id: usize) !u32 {
        const index: u32 = @intCast(self.serialized_objects.items.len);
        try self.memory.put(object_id, index);
        return index;
    }
};

/// Structured Clone Deserializer
/// Implements StructuredDeserialize from the HTML spec
pub const Deserializer = struct {
    allocator: std.mem.Allocator,

    /// Memory map for cycle resolution (index -> deserialized value)
    memory: std.AutoHashMap(u32, usize),

    pub fn init(allocator: std.mem.Allocator) Deserializer {
        return .{
            .allocator = allocator,
            .memory = std.AutoHashMap(u32, usize).init(allocator),
        };
    }

    pub fn deinit(self: *Deserializer) void {
        self.memory.deinit();
    }

    /// Check if a serialized type is a primitive
    pub fn isPrimitive(type_tag: SerializedType) bool {
        return switch (type_tag) {
            .primitive_undefined,
            .primitive_null,
            .primitive_boolean,
            .primitive_number,
            .primitive_bigint,
            .primitive_string,
            => true,
            else => false,
        };
    }

    /// Check if deserialization requires deep processing
    pub fn requiresDeep(type_tag: SerializedType) bool {
        return switch (type_tag) {
            .array, .object, .map, .set => true,
            // Platform objects with [Serializable] also require deep processing
            .blob, .file, .file_list, .image_data, .image_bitmap => true,
            else => false,
        };
    }
};

/// Binary serialization format for IndexedDB storage
/// This converts SerializedValue to/from bytes for actual storage
pub const BinaryFormat = struct {
    /// Magic bytes to identify structured clone data
    pub const MAGIC: [4]u8 = .{ 'S', 'C', 'L', 'N' };

    /// Format version
    pub const VERSION: u8 = 1;

    /// Errors that can occur during encoding
    pub const EncodeError = error{OutOfMemory};

    /// Errors that can occur during decoding
    pub const DecodeError = error{
        InvalidFormat,
        InvalidMagic,
        UnsupportedVersion,
        UnexpectedEof,
        InvalidLength,
        OutOfMemory,
    };

    /// Serialize a SerializedValue to bytes for storage
    pub fn encode(allocator: std.mem.Allocator, value: SerializedValue) ![]u8 {
        var buffer: std.ArrayListUnmanaged(u8) = .empty;
        errdefer buffer.deinit(allocator);

        // Write header
        try buffer.appendSlice(allocator, &MAGIC);
        try buffer.append(allocator, VERSION);

        // Write the value recursively
        try encodeValue(allocator, &buffer, value);

        return buffer.toOwnedSlice(allocator);
    }

    /// Deserialize bytes to a SerializedValue
    pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !SerializedValue {
        if (bytes.len < 5) return error.InvalidFormat;

        // Check magic
        if (!std.mem.eql(u8, bytes[0..4], &MAGIC)) {
            return error.InvalidMagic;
        }

        // Check version
        if (bytes[4] != VERSION) {
            return error.UnsupportedVersion;
        }

        var pos: usize = 5;
        return try decodeValue(allocator, bytes, &pos);
    }

    fn encodeValue(allocator: std.mem.Allocator, buffer: *std.ArrayListUnmanaged(u8), value: SerializedValue) EncodeError!void {
        // Write type tag
        try buffer.append(allocator, @intFromEnum(value.type_tag));

        // Write type-specific data
        switch (value.type_tag) {
            .primitive_undefined, .primitive_null => {
                // No additional data
            },
            .primitive_boolean => {
                try buffer.append(allocator, if (value.data.boolean) 1 else 0);
            },
            .primitive_number => {
                const bytes = std.mem.asBytes(&value.data.number);
                try buffer.appendSlice(allocator, bytes);
            },
            .primitive_string, .string_object => {
                try writeLength(allocator, buffer, @intCast(value.data.string.len));
                try buffer.appendSlice(allocator, value.data.string);
            },
            .primitive_bigint, .bigint_object => {
                try writeLength(allocator, buffer, @intCast(value.data.bigint.len));
                try buffer.appendSlice(allocator, value.data.bigint);
            },
            .date => {
                const bytes = std.mem.asBytes(&value.data.date);
                try buffer.appendSlice(allocator, bytes);
            },
            .regexp => {
                try writeLength(allocator, buffer, @intCast(value.data.regexp.source.len));
                try buffer.appendSlice(allocator, value.data.regexp.source);
                try writeLength(allocator, buffer, @intCast(value.data.regexp.flags.len));
                try buffer.appendSlice(allocator, value.data.regexp.flags);
            },
            .array_buffer, .resizable_array_buffer => {
                try writeLength(allocator, buffer, @intCast(value.data.array_buffer.data.len));
                try buffer.appendSlice(allocator, value.data.array_buffer.data);
                if (value.data.array_buffer.max_byte_length) |max| {
                    try buffer.append(allocator, 1);
                    try writeU32(allocator, buffer, max);
                } else {
                    try buffer.append(allocator, 0);
                }
            },
            .array => {
                try writeU32(allocator, buffer, value.data.array_length);
                try encodeProperties(allocator, buffer, value.properties);
            },
            .object => {
                try encodeProperties(allocator, buffer, value.properties);
            },
            .map => {
                try encodeMapData(allocator, buffer, value.map_data);
            },
            .set => {
                try encodeSetData(allocator, buffer, value.set_data);
            },
            .@"error" => {
                try buffer.append(allocator, @intFromEnum(value.data.@"error".name));
                if (value.data.@"error".message) |msg| {
                    try buffer.append(allocator, 1);
                    try writeLength(allocator, buffer, @intCast(msg.len));
                    try buffer.appendSlice(allocator, msg);
                } else {
                    try buffer.append(allocator, 0);
                }
            },
            .reference => {
                try writeU32(allocator, buffer, value.data.reference_index);
            },
            else => {
                // For unsupported types, write a placeholder
                // In a full implementation, each type would have specific encoding
            },
        }
    }

    fn encodeProperties(allocator: std.mem.Allocator, buffer: *std.ArrayListUnmanaged(u8), properties: ?[]SerializedValue.Property) EncodeError!void {
        const props = properties orelse {
            try writeLength(allocator, buffer, 0);
            return;
        };

        try writeLength(allocator, buffer, @intCast(props.len));
        for (props) |prop| {
            try writeLength(allocator, buffer, @intCast(prop.key.len));
            try buffer.appendSlice(allocator, prop.key);
            try encodeValue(allocator, buffer, prop.value);
        }
    }

    fn encodeMapData(allocator: std.mem.Allocator, buffer: *std.ArrayListUnmanaged(u8), map_data: ?[]SerializedValue.MapEntry) EncodeError!void {
        const entries = map_data orelse {
            try writeLength(allocator, buffer, 0);
            return;
        };

        try writeLength(allocator, buffer, @intCast(entries.len));
        for (entries) |entry| {
            try encodeValue(allocator, buffer, entry.key);
            try encodeValue(allocator, buffer, entry.value);
        }
    }

    fn encodeSetData(allocator: std.mem.Allocator, buffer: *std.ArrayListUnmanaged(u8), set_data: ?[]SerializedValue) EncodeError!void {
        const items = set_data orelse {
            try writeLength(allocator, buffer, 0);
            return;
        };

        try writeLength(allocator, buffer, @intCast(items.len));
        for (items) |item| {
            try encodeValue(allocator, buffer, item);
        }
    }

    fn writeLength(allocator: std.mem.Allocator, buffer: *std.ArrayListUnmanaged(u8), len: u32) EncodeError!void {
        // Variable-length encoding for lengths
        if (len < 128) {
            try buffer.append(allocator, @intCast(len));
        } else if (len < 16384) {
            try buffer.append(allocator, @as(u8, @intCast(len & 0x7F)) | 0x80);
            try buffer.append(allocator, @intCast((len >> 7) & 0x7F));
        } else {
            try buffer.append(allocator, @as(u8, @intCast(len & 0x7F)) | 0x80);
            try buffer.append(allocator, @as(u8, @intCast((len >> 7) & 0x7F)) | 0x80);
            try buffer.append(allocator, @as(u8, @intCast((len >> 14) & 0x7F)) | 0x80);
            try buffer.append(allocator, @intCast(len >> 21));
        }
    }

    fn writeU32(allocator: std.mem.Allocator, buffer: *std.ArrayListUnmanaged(u8), value: u32) EncodeError!void {
        const bytes = std.mem.asBytes(&value);
        try buffer.appendSlice(allocator, bytes);
    }

    fn decodeValue(allocator: std.mem.Allocator, bytes: []const u8, pos: *usize) DecodeError!SerializedValue {
        if (pos.* >= bytes.len) return error.UnexpectedEof;

        const type_tag: SerializedType = @enumFromInt(bytes[pos.*]);
        pos.* += 1;

        return switch (type_tag) {
            .primitive_undefined => .{
                .type_tag = .primitive_undefined,
                .data = .{ .none = {} },
            },
            .primitive_null => .{
                .type_tag = .primitive_null,
                .data = .{ .none = {} },
            },
            .primitive_boolean => blk: {
                if (pos.* >= bytes.len) return error.UnexpectedEof;
                const value = bytes[pos.*] != 0;
                pos.* += 1;
                break :blk .{
                    .type_tag = .primitive_boolean,
                    .data = .{ .boolean = value },
                };
            },
            .primitive_number => blk: {
                if (pos.* + 8 > bytes.len) return error.UnexpectedEof;
                const value = std.mem.bytesToValue(f64, bytes[pos.*..][0..8]);
                pos.* += 8;
                break :blk .{
                    .type_tag = .primitive_number,
                    .data = .{ .number = value },
                };
            },
            .primitive_string, .string_object => blk: {
                const len = try readLength(bytes, pos);
                if (pos.* + len > bytes.len) return error.UnexpectedEof;
                const str = try allocator.dupe(u8, bytes[pos.*..][0..len]);
                pos.* += len;
                break :blk .{
                    .type_tag = type_tag,
                    .data = .{ .string = str },
                    .allocator = allocator,
                };
            },
            .primitive_bigint, .bigint_object => blk: {
                const len = try readLength(bytes, pos);
                if (pos.* + len > bytes.len) return error.UnexpectedEof;
                const bigint_bytes = try allocator.dupe(u8, bytes[pos.*..][0..len]);
                pos.* += len;
                break :blk .{
                    .type_tag = type_tag,
                    .data = .{ .bigint = bigint_bytes },
                    .allocator = allocator,
                };
            },
            .date => blk: {
                if (pos.* + 8 > bytes.len) return error.UnexpectedEof;
                const timestamp = std.mem.bytesToValue(i64, bytes[pos.*..][0..8]);
                pos.* += 8;
                break :blk .{
                    .type_tag = .date,
                    .data = .{ .date = timestamp },
                };
            },
            .regexp => blk: {
                const source_len = try readLength(bytes, pos);
                if (pos.* + source_len > bytes.len) return error.UnexpectedEof;
                const source = try allocator.dupe(u8, bytes[pos.*..][0..source_len]);
                pos.* += source_len;

                const flags_len = try readLength(bytes, pos);
                if (pos.* + flags_len > bytes.len) return error.UnexpectedEof;
                const flags = try allocator.dupe(u8, bytes[pos.*..][0..flags_len]);
                pos.* += flags_len;

                break :blk .{
                    .type_tag = .regexp,
                    .data = .{ .regexp = .{
                        .source = source,
                        .flags = flags,
                    } },
                    .allocator = allocator,
                };
            },
            .array_buffer, .resizable_array_buffer => blk: {
                const len = try readLength(bytes, pos);
                if (pos.* + len > bytes.len) return error.UnexpectedEof;
                const data = try allocator.dupe(u8, bytes[pos.*..][0..len]);
                pos.* += len;

                if (pos.* >= bytes.len) return error.UnexpectedEof;
                const has_max = bytes[pos.*] != 0;
                pos.* += 1;

                const max_byte_length: ?u32 = if (has_max) blk2: {
                    if (pos.* + 4 > bytes.len) return error.UnexpectedEof;
                    const max = std.mem.bytesToValue(u32, bytes[pos.*..][0..4]);
                    pos.* += 4;
                    break :blk2 max;
                } else null;

                break :blk .{
                    .type_tag = type_tag,
                    .data = .{ .array_buffer = .{
                        .data = data,
                        .max_byte_length = max_byte_length,
                    } },
                    .allocator = allocator,
                };
            },
            .array => blk: {
                if (pos.* + 4 > bytes.len) return error.UnexpectedEof;
                const array_length = std.mem.bytesToValue(u32, bytes[pos.*..][0..4]);
                pos.* += 4;

                const properties = try decodeProperties(allocator, bytes, pos);

                break :blk .{
                    .type_tag = .array,
                    .data = .{ .array_length = array_length },
                    .properties = properties,
                    .allocator = allocator,
                };
            },
            .object => blk: {
                const properties = try decodeProperties(allocator, bytes, pos);

                break :blk .{
                    .type_tag = .object,
                    .data = .{ .none = {} },
                    .properties = properties,
                    .allocator = allocator,
                };
            },
            .map => blk: {
                const map_data = try decodeMapData(allocator, bytes, pos);

                break :blk .{
                    .type_tag = .map,
                    .data = .{ .none = {} },
                    .map_data = map_data,
                    .allocator = allocator,
                };
            },
            .set => blk: {
                const set_data = try decodeSetData(allocator, bytes, pos);

                break :blk .{
                    .type_tag = .set,
                    .data = .{ .none = {} },
                    .set_data = set_data,
                    .allocator = allocator,
                };
            },
            .@"error" => blk: {
                if (pos.* >= bytes.len) return error.UnexpectedEof;
                const name: ErrorName = @enumFromInt(bytes[pos.*]);
                pos.* += 1;

                if (pos.* >= bytes.len) return error.UnexpectedEof;
                const has_message = bytes[pos.*] != 0;
                pos.* += 1;

                const message: ?[]const u8 = if (has_message) blk2: {
                    const len = try readLength(bytes, pos);
                    if (pos.* + len > bytes.len) return error.UnexpectedEof;
                    const msg = try allocator.dupe(u8, bytes[pos.*..][0..len]);
                    pos.* += len;
                    break :blk2 msg;
                } else null;

                break :blk .{
                    .type_tag = .@"error",
                    .data = .{ .@"error" = .{
                        .name = name,
                        .message = message,
                    } },
                    .allocator = allocator,
                };
            },
            .reference => blk: {
                if (pos.* + 4 > bytes.len) return error.UnexpectedEof;
                const index = std.mem.bytesToValue(u32, bytes[pos.*..][0..4]);
                pos.* += 4;
                break :blk .{
                    .type_tag = .reference,
                    .data = .{ .reference_index = index },
                };
            },
            else => .{
                .type_tag = type_tag,
                .data = .{ .none = {} },
            },
        };
    }

    fn decodeProperties(allocator: std.mem.Allocator, bytes: []const u8, pos: *usize) DecodeError!?[]SerializedValue.Property {
        const count = try readLength(bytes, pos);
        if (count == 0) return null;

        const properties = try allocator.alloc(SerializedValue.Property, count);
        errdefer allocator.free(properties);

        for (properties) |*prop| {
            const key_len = try readLength(bytes, pos);
            if (pos.* + key_len > bytes.len) return error.UnexpectedEof;
            prop.key = try allocator.dupe(u8, bytes[pos.*..][0..key_len]);
            pos.* += key_len;

            prop.value = try decodeValue(allocator, bytes, pos);
        }

        return properties;
    }

    fn decodeMapData(allocator: std.mem.Allocator, bytes: []const u8, pos: *usize) DecodeError!?[]SerializedValue.MapEntry {
        const count = try readLength(bytes, pos);
        if (count == 0) return null;

        const entries = try allocator.alloc(SerializedValue.MapEntry, count);
        errdefer allocator.free(entries);

        for (entries) |*entry| {
            entry.key = try decodeValue(allocator, bytes, pos);
            entry.value = try decodeValue(allocator, bytes, pos);
        }

        return entries;
    }

    fn decodeSetData(allocator: std.mem.Allocator, bytes: []const u8, pos: *usize) DecodeError!?[]SerializedValue {
        const count = try readLength(bytes, pos);
        if (count == 0) return null;

        const items = try allocator.alloc(SerializedValue, count);
        errdefer allocator.free(items);

        for (items) |*item| {
            item.* = try decodeValue(allocator, bytes, pos);
        }

        return items;
    }

    fn readLength(bytes: []const u8, pos: *usize) DecodeError!usize {
        if (pos.* >= bytes.len) return error.UnexpectedEof;

        var result: usize = 0;
        var shift: u5 = 0;

        while (true) {
            if (pos.* >= bytes.len) return error.UnexpectedEof;
            const b = bytes[pos.*];
            pos.* += 1;

            result |= @as(usize, b & 0x7F) << shift;

            if (b & 0x80 == 0) break;
            shift += 7;
            if (shift >= 28) return error.InvalidLength;
        }

        return result;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Serializer - primitive undefined" {
    var serializer = Serializer.init(std.testing.allocator, true);
    defer serializer.deinit();

    const result = serializer.serializeUndefined();
    try std.testing.expectEqual(SerializedType.primitive_undefined, result.type_tag);
}

test "Serializer - primitive null" {
    var serializer = Serializer.init(std.testing.allocator, true);
    defer serializer.deinit();

    const result = serializer.serializeNull();
    try std.testing.expectEqual(SerializedType.primitive_null, result.type_tag);
}

test "Serializer - primitive boolean" {
    var serializer = Serializer.init(std.testing.allocator, true);
    defer serializer.deinit();

    const result_true = serializer.serializeBoolean(true);
    try std.testing.expectEqual(SerializedType.primitive_boolean, result_true.type_tag);
    try std.testing.expect(result_true.data.boolean);

    const result_false = serializer.serializeBoolean(false);
    try std.testing.expect(!result_false.data.boolean);
}

test "Serializer - primitive number" {
    var serializer = Serializer.init(std.testing.allocator, true);
    defer serializer.deinit();

    const result = serializer.serializeNumber(42.5);
    try std.testing.expectEqual(SerializedType.primitive_number, result.type_tag);
    try std.testing.expectEqual(@as(f64, 42.5), result.data.number);
}

test "Serializer - primitive string" {
    var serializer = Serializer.init(std.testing.allocator, true);
    defer serializer.deinit();

    var result = try serializer.serializeString("hello");
    defer result.deinit();

    try std.testing.expectEqual(SerializedType.primitive_string, result.type_tag);
    try std.testing.expectEqualStrings("hello", result.data.string);
}

test "Serializer - Date" {
    var serializer = Serializer.init(std.testing.allocator, true);
    defer serializer.deinit();

    const timestamp: i64 = 1700000000000;
    const result = serializer.serializeDate(timestamp);

    try std.testing.expectEqual(SerializedType.date, result.type_tag);
    try std.testing.expectEqual(timestamp, result.data.date);
}

test "Serializer - RegExp" {
    var serializer = Serializer.init(std.testing.allocator, true);
    defer serializer.deinit();

    var result = try serializer.serializeRegExp("test.*", "gi");
    defer result.deinit();

    try std.testing.expectEqual(SerializedType.regexp, result.type_tag);
    try std.testing.expectEqualStrings("test.*", result.data.regexp.source);
    try std.testing.expectEqualStrings("gi", result.data.regexp.flags);
}

test "Serializer - ArrayBuffer" {
    var serializer = Serializer.init(std.testing.allocator, true);
    defer serializer.deinit();

    const data = [_]u8{ 1, 2, 3, 4, 5 };
    var result = try serializer.serializeArrayBuffer(&data);
    defer result.deinit();

    try std.testing.expectEqual(SerializedType.array_buffer, result.type_tag);
    try std.testing.expectEqualSlices(u8, &data, result.data.array_buffer.data);
}

test "Serializer - Error" {
    var serializer = Serializer.init(std.testing.allocator, true);
    defer serializer.deinit();

    var result = try serializer.serializeError(.TypeError, "invalid type");
    defer result.deinit();

    try std.testing.expectEqual(SerializedType.@"error", result.type_tag);
    try std.testing.expectEqual(ErrorName.TypeError, result.data.@"error".name);
    try std.testing.expectEqualStrings("invalid type", result.data.@"error".message.?);
}

test "Serializer - SharedArrayBuffer rejected for storage" {
    var serializer = Serializer.init(std.testing.allocator, true);
    defer serializer.deinit();

    const result = serializer.checkSharedArrayBuffer();
    try std.testing.expectError(IDBError.DataCloneError, result);
}

test "BinaryFormat - roundtrip primitive undefined" {
    const serialized = SerializedValue{
        .type_tag = .primitive_undefined,
        .data = .{ .none = {} },
    };

    const bytes = try BinaryFormat.encode(std.testing.allocator, serialized);
    defer std.testing.allocator.free(bytes);

    var decoded = try BinaryFormat.decode(std.testing.allocator, bytes);
    defer decoded.deinit();

    try std.testing.expectEqual(SerializedType.primitive_undefined, decoded.type_tag);
}

test "BinaryFormat - roundtrip primitive boolean" {
    const serialized = SerializedValue{
        .type_tag = .primitive_boolean,
        .data = .{ .boolean = true },
    };

    const bytes = try BinaryFormat.encode(std.testing.allocator, serialized);
    defer std.testing.allocator.free(bytes);

    var decoded = try BinaryFormat.decode(std.testing.allocator, bytes);
    defer decoded.deinit();

    try std.testing.expectEqual(SerializedType.primitive_boolean, decoded.type_tag);
    try std.testing.expect(decoded.data.boolean);
}

test "BinaryFormat - roundtrip primitive number" {
    const serialized = SerializedValue{
        .type_tag = .primitive_number,
        .data = .{ .number = 3.14159 },
    };

    const bytes = try BinaryFormat.encode(std.testing.allocator, serialized);
    defer std.testing.allocator.free(bytes);

    var decoded = try BinaryFormat.decode(std.testing.allocator, bytes);
    defer decoded.deinit();

    try std.testing.expectEqual(SerializedType.primitive_number, decoded.type_tag);
    try std.testing.expectApproxEqRel(@as(f64, 3.14159), decoded.data.number, 0.0001);
}

test "BinaryFormat - roundtrip primitive string" {
    var serializer = Serializer.init(std.testing.allocator, true);
    defer serializer.deinit();

    var serialized = try serializer.serializeString("hello world");
    defer serialized.deinit();

    const bytes = try BinaryFormat.encode(std.testing.allocator, serialized);
    defer std.testing.allocator.free(bytes);

    var decoded = try BinaryFormat.decode(std.testing.allocator, bytes);
    defer decoded.deinit();

    try std.testing.expectEqual(SerializedType.primitive_string, decoded.type_tag);
    try std.testing.expectEqualStrings("hello world", decoded.data.string);
}

test "BinaryFormat - roundtrip Date" {
    const serialized = SerializedValue{
        .type_tag = .date,
        .data = .{ .date = 1700000000000 },
    };

    const bytes = try BinaryFormat.encode(std.testing.allocator, serialized);
    defer std.testing.allocator.free(bytes);

    var decoded = try BinaryFormat.decode(std.testing.allocator, bytes);
    defer decoded.deinit();

    try std.testing.expectEqual(SerializedType.date, decoded.type_tag);
    try std.testing.expectEqual(@as(i64, 1700000000000), decoded.data.date);
}

test "BinaryFormat - roundtrip Error" {
    var serializer = Serializer.init(std.testing.allocator, true);
    defer serializer.deinit();

    var serialized = try serializer.serializeError(.RangeError, "out of bounds");
    defer serialized.deinit();

    const bytes = try BinaryFormat.encode(std.testing.allocator, serialized);
    defer std.testing.allocator.free(bytes);

    var decoded = try BinaryFormat.decode(std.testing.allocator, bytes);
    defer decoded.deinit();

    try std.testing.expectEqual(SerializedType.@"error", decoded.type_tag);
    try std.testing.expectEqual(ErrorName.RangeError, decoded.data.@"error".name);
    try std.testing.expectEqualStrings("out of bounds", decoded.data.@"error".message.?);
}

test "BinaryFormat - invalid magic" {
    const bytes = [_]u8{ 'X', 'Y', 'Z', 'W', 1, 0 };
    const result = BinaryFormat.decode(std.testing.allocator, &bytes);
    try std.testing.expectError(error.InvalidMagic, result);
}

test "BinaryFormat - unsupported version" {
    var bytes = BinaryFormat.MAGIC ++ [_]u8{99};
    const result = BinaryFormat.decode(std.testing.allocator, &bytes);
    try std.testing.expectError(error.UnsupportedVersion, result);
}
