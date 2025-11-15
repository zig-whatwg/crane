//! WebIDL Codegen API
//!
//! This module provides compile-time functions for marking structs as WebIDL interfaces,
//! namespaces, and mixins. The actual code generation happens at build time via the
//! webidl-codegen executable.

const std = @import("std");

/// Extended attribute value types
/// Spec: https://webidl.spec.whatwg.org/#idl-extended-attributes
pub const ExtendedAttributeValue = union(enum) {
    /// No value - [Serializable], [Transferable]
    none,

    /// Single identifier - [Exposed=Window], [Global=Window]
    identifier: []const u8,

    /// List of identifiers - [Exposed=(Window,Worker)], [Global=(Window,Worker)]
    identifier_list: []const []const u8,

    /// Wildcard - [Exposed=*]
    wildcard,

    /// String literal - [LegacyFactoryFunction="Image(...)"]
    string: []const u8,

    /// Integer - [Constructor(unsigned long value)]
    integer: i64,

    /// Decimal - [SomeAttr=3.14]
    decimal: f64,

    /// Named argument list - [LegacyFactoryFunction=Image(unsigned long width)]
    named_arg_list: []const NamedArg,

    pub const NamedArg = struct {
        name: []const u8,
        value: []const u8,
    };
};

/// Extended attribute (key-value pair)
/// Represents a single WebIDL extended attribute
pub const ExtendedAttribute = struct {
    /// Attribute name (e.g., "Exposed", "Transferable", "Global")
    name: []const u8,

    /// Attribute value (optional for no-arg attributes)
    value: ExtendedAttributeValue,
};

// ============================================================================
// Helper Functions for Extended Attributes
// ============================================================================

/// Create [Exposed=*] attribute (globally exposed)
pub fn exposed(comptime value: []const u8) ExtendedAttribute {
    if (std.mem.eql(u8, value, "*")) {
        return .{ .name = "Exposed", .value = .wildcard };
    }
    return .{ .name = "Exposed", .value = .{ .identifier = value } };
}

/// Create [Exposed=(Window,Worker)] attribute (multiple scopes)
pub fn exposedList(comptime values: []const []const u8) ExtendedAttribute {
    return .{ .name = "Exposed", .value = .{ .identifier_list = values } };
}

/// Create no-argument extended attribute ([Serializable], [Transferable])
pub fn noArgs(comptime name: []const u8) ExtendedAttribute {
    return .{ .name = name, .value = .none };
}

/// Create [Global=Window] attribute (single global name)
pub fn global(comptime value: []const u8) ExtendedAttribute {
    return .{ .name = "Global", .value = .{ .identifier = value } };
}

/// Create [Global=(Window,Worker)] attribute (multiple global names)
pub fn globalList(comptime values: []const []const u8) ExtendedAttribute {
    return .{ .name = "Global", .value = .{ .identifier_list = values } };
}

/// Create string-valued extended attribute
pub fn stringAttr(comptime name: []const u8, comptime value: []const u8) ExtendedAttribute {
    return .{ .name = name, .value = .{ .string = value } };
}

/// Create identifier-valued extended attribute
pub fn identifierAttr(comptime name: []const u8, comptime value: []const u8) ExtendedAttribute {
    return .{ .name = name, .value = .{ .identifier = value } };
}

// ============================================================================
// WebIDL Declaration Functions
// ============================================================================

/// Mark a struct as a WebIDL interface (supports inheritance, methods, properties)
///
/// Usage:
/// ```zig
/// pub const MyInterface = webidl.interface(struct {
///     pub const extends = ParentInterface;
///     // fields and methods
/// }, &.{
///     exposed("*"),
///     noArgs("Transferable"),
/// });
/// ```
pub fn interface(comptime T: type, comptime attrs: []const ExtendedAttribute) type {
    _ = attrs; // Attributes are parsed by codegen at build time
    return T;
}

/// Mark a struct as a WebIDL namespace (static-only API, no instances)
///
/// Usage:
/// ```zig
/// pub const MyNamespace = webidl.namespace(struct {
///     // static methods only
/// }, &.{
///     exposed("*"),
/// });
/// ```
pub fn namespace(comptime T: type, comptime attrs: []const ExtendedAttribute) type {
    _ = attrs; // Attributes are parsed by codegen at build time
    return T;
}

/// Mark a struct as a WebIDL interface mixin (reusable member bundles)
///
/// Mixins can optionally have [Exposed] attributes:
/// https://webidl.spec.whatwg.org/#idl-interface-mixins
///
/// Usage:
/// ```zig
/// pub const MyMixin = webidl.mixin(struct {
///     // mixin members
/// }, &.{
///     exposed("*"),
/// });
/// ```
pub fn mixin(comptime T: type, comptime attrs: []const ExtendedAttribute) type {
    _ = attrs; // Attributes are parsed by codegen at build time
    return T;
}

/// Configuration for WebIDL code generation
pub const ClassConfig = struct {
    /// Additional options (reserved for future use)
    options: ?*anyopaque = null,
};
