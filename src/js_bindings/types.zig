//! JS Bindings Type Definitions
//!
//! Defines engine-agnostic binding descriptor types that describe how to
//! expose WebIDL interfaces and namespaces to JavaScript engines.

const std = @import("std");

/// Engine-agnostic binding descriptor for a namespace
pub const NamespaceBinding = struct {
    /// Namespace name (e.g., "console", "CSS", "WebAssembly")
    name: []const u8,

    /// Namespace methods to expose
    methods: []const MethodDescriptor,

    /// Namespace constants to expose
    constants: []const ConstantDescriptor = &.{},
};

/// Engine-agnostic binding descriptor for an interface
pub const InterfaceBinding = struct {
    /// Interface name (e.g., "Node", "Element", "Document")
    name: []const u8,

    /// Parent interface (for inheritance), null if no parent
    parent: ?[]const u8 = null,

    /// Constructor method, null if not constructable
    constructor: ?ConstructorDescriptor = null,

    /// Instance methods
    methods: []const MethodDescriptor = &.{},

    /// Instance attributes (properties)
    attributes: []const AttributeDescriptor = &.{},

    /// Static methods
    static_methods: []const MethodDescriptor = &.{},

    /// Static attributes
    static_attributes: []const AttributeDescriptor = &.{},

    /// Constants
    constants: []const ConstantDescriptor = &.{},
};

/// Descriptor for a constructor
pub const ConstructorDescriptor = struct {
    /// Parameter descriptors
    parameters: []const ParameterDescriptor,

    /// Zig function pointer to call for construction
    /// fn(allocator: Allocator, args: anytype) !*InstanceType
    impl: *const anyopaque,
};

/// Descriptor for a method (namespace method or interface method)
pub const MethodDescriptor = struct {
    /// Method name (e.g., "log", "appendChild", "querySelector")
    name: []const u8,

    /// Parameter descriptors
    parameters: []const ParameterDescriptor,

    /// Return type descriptor
    return_type: TypeDescriptor,

    /// Zig function pointer to call
    /// For namespace: fn(args: anytype) ReturnType
    /// For instance method: fn(self: *T, args: anytype) ReturnType
    impl: *const anyopaque,
};

/// Descriptor for an attribute (property)
pub const AttributeDescriptor = struct {
    /// Attribute name (e.g., "nodeType", "textContent", "classList")
    name: []const u8,

    /// Attribute type
    type: TypeDescriptor,

    /// Is this attribute read-only?
    readonly: bool = false,

    /// Zig getter function pointer
    /// fn(self: *T) ReturnType
    getter: *const anyopaque,

    /// Zig setter function pointer (null if readonly)
    /// fn(self: *T, value: ValueType) void
    setter: ?*const anyopaque = null,
};

/// Descriptor for a constant
pub const ConstantDescriptor = struct {
    /// Constant name (e.g., "ELEMENT_NODE", "PI")
    name: []const u8,

    /// Constant type
    type: TypeDescriptor,

    /// Constant value (stored as anyopaque pointer)
    value: *const anyopaque,
};

/// Descriptor for a parameter
pub const ParameterDescriptor = struct {
    /// Parameter name
    name: []const u8,

    /// Parameter type
    type: TypeDescriptor,

    /// Is this parameter optional?
    optional: bool = false,

    /// Default value (null if no default)
    default_value: ?*const anyopaque = null,
};

/// Type descriptor for WebIDL types
pub const TypeDescriptor = struct {
    /// Type kind
    kind: TypeKind,

    /// For complex types, additional type info
    inner: ?*const TypeDescriptor = null,

    /// For sequence/record types
    element_type: ?*const TypeDescriptor = null,
    key_type: ?*const TypeDescriptor = null,

    /// Is this type nullable?
    nullable: bool = false,
};

/// WebIDL type kinds
pub const TypeKind = enum {
    // Primitive types
    void,
    boolean,
    byte,
    octet,
    short,
    unsigned_short,
    long,
    unsigned_long,
    long_long,
    unsigned_long_long,
    float,
    double,

    // String types
    dom_string,
    byte_string,
    usv_string,

    // Special types
    any,
    object,
    symbol,

    // Complex types
    interface, // Named interface
    dictionary, // Dictionary type
    enumeration, // Enum type
    callback, // Callback function
    sequence, // sequence<T>
    record, // record<K, V>
    promise, // Promise<T>
    frozen_array, // FrozenArray<T>
    observable_array, // ObservableArray<T>

    // Union types
    union_type, // (T1 or T2 or ...)

    // Buffer types
    array_buffer,
    data_view,
    typed_array,
};
