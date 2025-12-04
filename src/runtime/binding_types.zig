//! WebIDL Binding Descriptor Types
//!
//! This module defines the descriptor types used by EngineBinding to generate
//! JavaScript bindings from WebIDL interfaces. These types describe the shape
//! of interfaces, methods, properties, and types in a way that any JavaScript
//! engine can use to create bindings.
//!
//! ## Design Principles
//!
//! 1. **Engine Agnostic**: Descriptors contain no engine-specific types
//! 2. **Comptime Friendly**: Can be constructed at compile time
//! 3. **C ABI Compatible**: Extern structs for FFI compatibility
//! 4. **Complete WebIDL Coverage**: Supports all WebIDL constructs
//!
//! ## Usage
//!
//! ```zig
//! const desc = InterfaceDescriptor{
//!     .name = "Blob",
//!     .parent = "Object",
//!     .constructor = &.{
//!         .name = "Blob",
//!         .arguments = &.{...},
//!     },
//!     .methods = &.{...},
//!     .properties = &.{...},
//! };
//! ```

const std = @import("std");

// =============================================================================
// WebIDL Type Descriptors
// =============================================================================

/// WebIDL primitive types
pub const PrimitiveType = enum(u8) {
    /// void - no return value
    void = 0,
    /// boolean
    boolean = 1,
    /// byte (signed 8-bit)
    byte = 2,
    /// octet (unsigned 8-bit)
    octet = 3,
    /// short (signed 16-bit)
    short = 4,
    /// unsigned short
    unsigned_short = 5,
    /// long (signed 32-bit)
    long = 6,
    /// unsigned long
    unsigned_long = 7,
    /// long long (signed 64-bit)
    long_long = 8,
    /// unsigned long long
    unsigned_long_long = 9,
    /// float (32-bit IEEE 754)
    float = 10,
    /// unrestricted float
    unrestricted_float = 11,
    /// double (64-bit IEEE 754)
    double = 12,
    /// unrestricted double
    unrestricted_double = 13,
    /// bigint
    bigint = 14,
    /// DOMString
    DOMString = 15,
    /// ByteString
    ByteString = 16,
    /// USVString
    USVString = 17,
    /// object
    object = 18,
    /// symbol
    symbol = 19,
    /// any
    any = 20,
    /// undefined
    undefined = 21,
};

/// WebIDL type kind
pub const TypeKind = enum(u8) {
    /// Primitive type (boolean, number, string, etc.)
    primitive = 0,
    /// Interface type reference
    interface = 1,
    /// Dictionary type reference
    dictionary = 2,
    /// Enum type reference
    @"enum" = 3,
    /// Callback function type
    callback = 4,
    /// Callback interface type
    callback_interface = 5,
    /// Sequence<T> type
    sequence = 6,
    /// FrozenArray<T> type
    frozen_array = 7,
    /// ObservableArray<T> type
    observable_array = 8,
    /// record<K, V> type
    record = 9,
    /// Promise<T> type
    promise = 10,
    /// Union type (A or B or C)
    @"union" = 11,
    /// Nullable type (T?)
    nullable = 12,
    /// ArrayBuffer
    array_buffer = 13,
    /// ArrayBufferView (any TypedArray or DataView)
    array_buffer_view = 14,
    /// DataView
    data_view = 15,
    /// Int8Array
    int8_array = 16,
    /// Int16Array
    int16_array = 17,
    /// Int32Array
    int32_array = 18,
    /// Uint8Array
    uint8_array = 19,
    /// Uint8ClampedArray
    uint8_clamped_array = 20,
    /// Uint16Array
    uint16_array = 21,
    /// Uint32Array
    uint32_array = 22,
    /// BigInt64Array
    bigint64_array = 23,
    /// BigUint64Array
    biguint64_array = 24,
    /// Float32Array
    float32_array = 25,
    /// Float64Array
    float64_array = 26,
};

/// Describes a WebIDL type
pub const TypeDescriptor = extern struct {
    /// Kind of type
    kind: TypeKind,

    /// For primitives: which primitive type
    primitive: PrimitiveType = .void,

    /// For interface/dictionary/enum/callback: the type name
    /// For sequence/array/promise/nullable: null (see inner_type)
    type_name: ?[*:0]const u8 = null,

    /// For parameterized types (sequence, promise, nullable): inner type
    inner_type: ?*const TypeDescriptor = null,

    /// For record types: key type (always a string type)
    key_type: ?*const TypeDescriptor = null,

    /// For union types: array of member types
    union_members: ?[*]const *const TypeDescriptor = null,
    union_members_len: u32 = 0,

    /// Create a primitive type descriptor
    pub fn primitive_(prim: PrimitiveType) TypeDescriptor {
        return .{
            .kind = .primitive,
            .primitive = prim,
        };
    }

    /// Create an interface type descriptor
    pub fn interface_(name: [*:0]const u8) TypeDescriptor {
        return .{
            .kind = .interface,
            .type_name = name,
        };
    }

    /// Create a sequence type descriptor
    pub fn sequence_(inner: *const TypeDescriptor) TypeDescriptor {
        return .{
            .kind = .sequence,
            .inner_type = inner,
        };
    }

    /// Create a promise type descriptor
    pub fn promise_(inner: *const TypeDescriptor) TypeDescriptor {
        return .{
            .kind = .promise,
            .inner_type = inner,
        };
    }

    /// Create a nullable type descriptor
    pub fn nullable_(inner: *const TypeDescriptor) TypeDescriptor {
        return .{
            .kind = .nullable,
            .inner_type = inner,
        };
    }
};

// =============================================================================
// Argument Descriptors
// =============================================================================

/// Describes a method/constructor argument
pub const ArgumentDescriptor = extern struct {
    /// Argument name
    name: [*:0]const u8,

    /// Argument type
    type: *const TypeDescriptor,

    /// Is this argument optional?
    optional: bool = false,

    /// Does this argument have a default value?
    has_default: bool = false,

    /// Is this a variadic argument (...rest)?
    variadic: bool = false,

    /// Default value as JSON string (if has_default)
    /// e.g., "null", "0", "\"\"", "true"
    default_value: ?[*:0]const u8 = null,
};

// =============================================================================
// Method Descriptors
// =============================================================================

/// Special method kinds
pub const MethodKind = enum(u8) {
    /// Regular method
    regular = 0,
    /// Getter (indexed or named property getter)
    getter = 1,
    /// Setter (indexed or named property setter)
    setter = 2,
    /// Deleter (indexed or named property deleter)
    deleter = 3,
    /// Stringifier (toString)
    stringifier = 4,
    /// Iterator (Symbol.iterator)
    iterator = 5,
    /// Async iterator (Symbol.asyncIterator)
    async_iterator = 6,
    /// Static method
    static = 7,
};

/// Describes a method on an interface
pub const MethodDescriptor = extern struct {
    /// Method name (null for special operations like getter/setter)
    name: ?[*:0]const u8,

    /// Method kind
    kind: MethodKind = .regular,

    /// Return type
    return_type: *const TypeDescriptor,

    /// Arguments
    arguments: ?[*]const ArgumentDescriptor = null,
    arguments_len: u32 = 0,

    /// Is this method overloaded? (has multiple signatures)
    overloaded: bool = false,

    /// Overload index (0-based, for overloaded methods)
    overload_index: u8 = 0,

    /// CEReactions flag
    ce_reactions: bool = false,

    /// Does this method return a new object? (for optimization)
    returns_new_object: bool = false,
};

// =============================================================================
// Property Descriptors
// =============================================================================

/// Describes a property (attribute) on an interface
pub const PropertyDescriptor = extern struct {
    /// Property name
    name: [*:0]const u8,

    /// Property type
    type: *const TypeDescriptor,

    /// Is this a readonly property?
    readonly: bool = false,

    /// Is this a static property?
    static: bool = false,

    /// CEReactions flag (for setters)
    ce_reactions: bool = false,

    /// Does getting this property reflect a content attribute?
    /// If so, attribute_name is the HTML attribute name
    reflects: bool = false,
    attribute_name: ?[*:0]const u8 = null,

    /// Is this a replaceable property? ([Replaceable])
    replaceable: bool = false,

    /// Is this a LegacyLenientSetter property?
    lenient_setter: bool = false,

    /// Is this a LegacyLenientThis property?
    lenient_this: bool = false,

    /// Is this a PutForwards property?
    put_forwards: ?[*:0]const u8 = null,
};

// =============================================================================
// Constant Descriptors
// =============================================================================

/// Describes a constant on an interface
pub const ConstantDescriptor = extern struct {
    /// Constant name
    name: [*:0]const u8,

    /// Constant type (must be primitive)
    type: *const TypeDescriptor,

    /// Constant value as JSON string
    /// e.g., "0", "1", "\"string\"", "true", "null"
    value: [*:0]const u8,
};

// =============================================================================
// Interface Descriptors
// =============================================================================

/// Describes a WebIDL interface
pub const InterfaceDescriptor = extern struct {
    /// Interface name
    name: [*:0]const u8,

    /// Parent interface name (null for no parent)
    parent: ?[*:0]const u8 = null,

    /// Is this interface a mixin?
    is_mixin: bool = false,

    /// Is this interface a callback interface?
    is_callback_interface: bool = false,

    /// Is this interface a namespace? (static-only)
    is_namespace: bool = false,

    /// Does this interface have a constructor?
    has_constructor: bool = false,

    /// Constructor descriptors (may be multiple for overloading)
    constructors: ?[*]const MethodDescriptor = null,
    constructors_len: u32 = 0,

    /// Methods
    methods: ?[*]const MethodDescriptor = null,
    methods_len: u32 = 0,

    /// Properties (attributes)
    properties: ?[*]const PropertyDescriptor = null,
    properties_len: u32 = 0,

    /// Constants
    constants: ?[*]const ConstantDescriptor = null,
    constants_len: u32 = 0,

    /// Mixins included by this interface (names)
    includes: ?[*]const [*:0]const u8 = null,
    includes_len: u32 = 0,

    /// Extended attributes
    /// [Exposed] - where this interface is exposed
    exposed: ?[*:0]const u8 = null,

    /// [Global] - is this a global object interface?
    global: bool = false,

    /// [LegacyWindowAlias] - legacy alias name
    legacy_window_alias: ?[*:0]const u8 = null,

    /// [LegacyNoInterfaceObject] - don't expose constructor
    legacy_no_interface_object: bool = false,

    /// [LegacyNamespace] - use namespace semantics
    legacy_namespace: bool = false,

    /// [SecureContext] - requires secure context
    secure_context: bool = false,

    /// [Transferable] - supports structured clone transfer
    transferable: bool = false,

    /// [Serializable] - supports structured clone serialization
    serializable: bool = false,
};

// =============================================================================
// Dictionary Descriptors
// =============================================================================

/// Describes a dictionary member
pub const DictionaryMemberDescriptor = extern struct {
    /// Member name
    name: [*:0]const u8,

    /// Member type
    type: *const TypeDescriptor,

    /// Is this member required?
    required: bool = false,

    /// Default value as JSON string (if not required and has default)
    default_value: ?[*:0]const u8 = null,
};

/// Describes a WebIDL dictionary
pub const DictionaryDescriptor = extern struct {
    /// Dictionary name
    name: [*:0]const u8,

    /// Parent dictionary name (null for no parent)
    parent: ?[*:0]const u8 = null,

    /// Members
    members: ?[*]const DictionaryMemberDescriptor = null,
    members_len: u32 = 0,
};

// =============================================================================
// Enum Descriptors
// =============================================================================

/// Describes a WebIDL enumeration
pub const EnumDescriptor = extern struct {
    /// Enum name
    name: [*:0]const u8,

    /// Enum values (as null-terminated strings)
    values: [*]const [*:0]const u8,
    values_len: u32,
};

// =============================================================================
// Callback Descriptors
// =============================================================================

/// Describes a WebIDL callback function
pub const CallbackDescriptor = extern struct {
    /// Callback name
    name: [*:0]const u8,

    /// Return type
    return_type: *const TypeDescriptor,

    /// Arguments
    arguments: ?[*]const ArgumentDescriptor = null,
    arguments_len: u32 = 0,
};

// =============================================================================
// Common Type Descriptors (compile-time constants)
// =============================================================================

/// Pre-defined type descriptors for common types
pub const Types = struct {
    pub const void_type = TypeDescriptor.primitive_(.void);
    pub const boolean = TypeDescriptor.primitive_(.boolean);
    pub const byte = TypeDescriptor.primitive_(.byte);
    pub const octet = TypeDescriptor.primitive_(.octet);
    pub const short = TypeDescriptor.primitive_(.short);
    pub const unsigned_short = TypeDescriptor.primitive_(.unsigned_short);
    pub const long = TypeDescriptor.primitive_(.long);
    pub const unsigned_long = TypeDescriptor.primitive_(.unsigned_long);
    pub const long_long = TypeDescriptor.primitive_(.long_long);
    pub const unsigned_long_long = TypeDescriptor.primitive_(.unsigned_long_long);
    pub const float = TypeDescriptor.primitive_(.float);
    pub const unrestricted_float = TypeDescriptor.primitive_(.unrestricted_float);
    pub const double = TypeDescriptor.primitive_(.double);
    pub const unrestricted_double = TypeDescriptor.primitive_(.unrestricted_double);
    pub const bigint = TypeDescriptor.primitive_(.bigint);
    pub const DOMString = TypeDescriptor.primitive_(.DOMString);
    pub const ByteString = TypeDescriptor.primitive_(.ByteString);
    pub const USVString = TypeDescriptor.primitive_(.USVString);
    pub const object = TypeDescriptor.primitive_(.object);
    pub const any = TypeDescriptor.primitive_(.any);
    pub const @"undefined" = TypeDescriptor.primitive_(.undefined);

    // Buffer types
    pub const ArrayBuffer = TypeDescriptor{ .kind = .array_buffer };
    pub const ArrayBufferView = TypeDescriptor{ .kind = .array_buffer_view };
    pub const DataView = TypeDescriptor{ .kind = .data_view };
    pub const Uint8Array = TypeDescriptor{ .kind = .uint8_array };
    pub const Uint8ClampedArray = TypeDescriptor{ .kind = .uint8_clamped_array };
    pub const Uint16Array = TypeDescriptor{ .kind = .uint16_array };
    pub const Uint32Array = TypeDescriptor{ .kind = .uint32_array };
    pub const Int8Array = TypeDescriptor{ .kind = .int8_array };
    pub const Int16Array = TypeDescriptor{ .kind = .int16_array };
    pub const Int32Array = TypeDescriptor{ .kind = .int32_array };
    pub const Float32Array = TypeDescriptor{ .kind = .float32_array };
    pub const Float64Array = TypeDescriptor{ .kind = .float64_array };
    pub const BigInt64Array = TypeDescriptor{ .kind = .bigint64_array };
    pub const BigUint64Array = TypeDescriptor{ .kind = .biguint64_array };
};

// =============================================================================
// Tests
// =============================================================================

test "TypeDescriptor - primitive types" {
    const t = Types.DOMString;
    try std.testing.expectEqual(TypeKind.primitive, t.kind);
    try std.testing.expectEqual(PrimitiveType.DOMString, t.primitive);
}

test "TypeDescriptor - interface type" {
    const t = TypeDescriptor.interface_("Blob");
    try std.testing.expectEqual(TypeKind.interface, t.kind);
    try std.testing.expectEqualStrings("Blob", std.mem.span(t.type_name.?));
}

test "TypeDescriptor - sequence type" {
    const inner = Types.DOMString;
    const t = TypeDescriptor.sequence_(&inner);
    try std.testing.expectEqual(TypeKind.sequence, t.kind);
    try std.testing.expectEqual(&inner, t.inner_type.?);
}

test "InterfaceDescriptor - basic" {
    const desc = InterfaceDescriptor{
        .name = "Blob",
        .has_constructor = true,
    };
    try std.testing.expectEqualStrings("Blob", std.mem.span(desc.name));
    try std.testing.expect(desc.has_constructor);
    try std.testing.expect(!desc.is_mixin);
}

test "extern struct layout" {
    // Verify structs are extern for FFI
    try std.testing.expect(@typeInfo(TypeDescriptor).@"struct".layout == .@"extern");
    try std.testing.expect(@typeInfo(MethodDescriptor).@"struct".layout == .@"extern");
    try std.testing.expect(@typeInfo(PropertyDescriptor).@"struct".layout == .@"extern");
    try std.testing.expect(@typeInfo(InterfaceDescriptor).@"struct".layout == .@"extern");
}
