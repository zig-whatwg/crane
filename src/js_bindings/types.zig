//! JS Bindings Type Definitions
//!
//! Defines engine-agnostic binding descriptor types that describe how to
//! expose WebIDL interfaces and namespaces to JavaScript engines.
//!
//! ## Type Safety Note
//!
//! This module uses `*const anyopaque` for function pointers and values in binding
//! descriptors. This is **intentional and legitimate** because:
//!
//! 1. **Comptime reflection limitation**: At comptime, we extract metadata from
//!    arbitrary WebIDL interfaces/namespaces. The exact function signatures are
//!    unknown until reflection runs - we can't parameterize descriptors by each
//!    unique function type.
//!
//! 2. **Heterogeneous registry pattern**: A single registry holds bindings for
//!    many different interfaces with different method signatures. Type erasure
//!    via `*const anyopaque` is the standard Zig pattern (see std.mem.Allocator).
//!
//! 3. **JS engine boundary**: These pointers are cast back to concrete types at
//!    the V8/JSC binding layer where the actual dispatch occurs.
//!
//! See: docs/legitimate-anyopaque.md for full documentation of legitimate uses.

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
    ///
    /// KEEP: anyopaque required - Constructor signatures vary per interface.
    /// Type is erased at comptime extraction, restored at JS engine binding layer.
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
    ///
    /// KEEP: anyopaque required - Method signatures vary per interface/namespace.
    /// Each method has unique parameter/return types discovered at comptime.
    /// Type is erased here, restored at JS engine binding layer via TypeDescriptor.
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
    ///
    /// KEEP: anyopaque required - Getter signatures vary per attribute type.
    /// Type is erased at comptime extraction, restored at JS engine binding layer.
    getter: *const anyopaque,

    /// Zig setter function pointer (null if readonly)
    /// fn(self: *T, value: ValueType) void
    ///
    /// KEEP: anyopaque required - Setter signatures vary per attribute type.
    /// Type is erased at comptime extraction, restored at JS engine binding layer.
    setter: ?*const anyopaque = null,
};

/// Descriptor for a constant
pub const ConstantDescriptor = struct {
    /// Constant name (e.g., "ELEMENT_NODE", "PI")
    name: []const u8,

    /// Constant type
    type: TypeDescriptor,

    /// Constant value (stored as anyopaque pointer)
    ///
    /// KEEP: anyopaque required - Constants can be any primitive type (u16, f64, etc.).
    /// Pointer to comptime-known value; actual type recovered via TypeDescriptor.kind.
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
    ///
    /// KEEP: anyopaque required - Default values can be any type matching parameter type.
    /// Pointer to comptime-known value; actual type recovered via self.type.kind.
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
