//! WebIDL JSON Parsing Types
//!
//! This module defines Zig types for parsing WebIDL interface definitions from JSON.
//! The JSON format is based on the output of WebIDL parsers like webidl2.js.
//!
//! ## Example JSON Structure
//!
//! ```json
//! {
//!   "interfaces": [
//!     {
//!       "name": "EventTarget",
//!       "inheritance": null,
//!       "members": [
//!         {
//!           "type": "operation",
//!           "name": "addEventListener",
//!           "idlType": { "type": "void" },
//!           "arguments": [...]
//!         },
//!         {
//!           "type": "attribute",
//!           "name": "eventPhase",
//!           "idlType": { "type": "unsigned short" },
//!           "readonly": true
//!         }
//!       ],
//!       "extAttrs": [
//!         { "name": "Exposed", "rhs": { "type": "identifier", "value": "Window" } }
//!       ]
//!     }
//!   ]
//! }
//! ```
//!
//! ## Usage
//!
//! ```zig
//! const std = @import("std");
//! const types = @import("types.zig");
//!
//! const json_source = try std.fs.cwd().readFileAlloc(allocator, "dom.json", 1024 * 1024);
//! defer allocator.free(json_source);
//!
//! const parsed = try std.json.parseFromSlice(types.IDLFile, allocator, json_source, .{});
//! defer parsed.deinit();
//!
//! for (parsed.value.interfaces) |interface| {
//!     std.debug.print("Interface: {s}\n", .{interface.name});
//! }
//! ```

const std = @import("std");

/// Represents an "includes" statement: InterfaceName includes MixinName;
pub const Includes = struct {
    /// The interface that includes the mixin
    target: []const u8,

    /// The mixin being included
    mixin: []const u8,
};

/// Top-level WebIDL file structure
pub const IDLFile = struct {
    /// List of interface definitions in this file
    interfaces: []Interface = &.{},

    /// List of namespace definitions (e.g., console)
    namespaces: []Namespace = &.{},

    /// List of dictionary definitions
    dictionaries: []Dictionary = &.{},

    /// List of enum definitions
    enums: []Enum = &.{},

    /// List of callback definitions
    callbacks: []Callback = &.{},

    /// List of typedef definitions
    typedefs: []Typedef = &.{},

    /// List of includes statements (InterfaceName includes MixinName)
    includes: []Includes = &.{},
};

/// WebIDL interface definition
pub const Interface = struct {
    /// Interface name (e.g., "EventTarget")
    name: []const u8,

    /// Base interface name (null if no inheritance)
    inheritance: ?[]const u8 = null,

    /// List of members (attributes, operations, constants)
    members: []Member = &.{},

    /// Extended attributes (e.g., [Exposed=Window])
    extAttrs: []ExtendedAttribute = &.{},

    /// Whether this is a partial interface
    partial: bool = false,

    /// Whether this is a mixin
    mixin: bool = false,

    /// Mixin interfaces that this interface includes
    includes: [][]const u8 = &.{},
};

/// WebIDL namespace definition (e.g., console)
pub const Namespace = struct {
    /// Namespace name
    name: []const u8,

    /// List of members (operations, attributes)
    members: []Member = &.{},

    /// Extended attributes
    extAttrs: []ExtendedAttribute = &.{},

    /// Whether this is a partial namespace
    partial: bool = false,
};

/// WebIDL dictionary definition
pub const Dictionary = struct {
    /// Dictionary name
    name: []const u8,

    /// Base dictionary (inheritance)
    inheritance: ?[]const u8 = null,

    /// List of dictionary members
    members: []DictionaryMember = &.{},

    /// Extended attributes
    extAttrs: []ExtendedAttribute = &.{},

    /// Whether this is a partial dictionary
    partial: bool = false,
};

/// Dictionary member (field)
pub const DictionaryMember = struct {
    /// Member name
    name: []const u8,

    /// Member type
    idlType: IDLType,

    /// Whether this member is required
    required: bool = false,

    /// Default value (if any)
    default: ?Value = null,

    /// Extended attributes
    extAttrs: []ExtendedAttribute = &.{},
};

/// WebIDL enum definition
pub const Enum = struct {
    /// Enum name
    name: []const u8,

    /// List of enum values
    values: [][]const u8 = &.{},

    /// Extended attributes
    extAttrs: []ExtendedAttribute = &.{},
};

/// WebIDL callback definition
pub const Callback = struct {
    /// Callback name
    name: []const u8,

    /// Return type
    idlType: IDLType,

    /// Arguments
    arguments: []Argument = &.{},

    /// Extended attributes
    extAttrs: []ExtendedAttribute = &.{},
};

/// WebIDL typedef definition
pub const Typedef = struct {
    /// Typedef name
    name: []const u8,

    /// Type being aliased
    idlType: IDLType,

    /// Extended attributes
    extAttrs: []ExtendedAttribute = &.{},
};

/// WebIDL iterable declaration
pub const Iterable = struct {
    /// Key type (for pair iterables) or value type (for value iterables)
    keyType: IDLType,

    /// Value type (null for value iterables)
    valueType: ?IDLType = null,

    /// Extended attributes
    extAttrs: []ExtendedAttribute = &.{},
};

/// Interface/namespace member (attribute, operation, constant)
pub const Member = struct {
    /// Member type discriminator
    type: MemberType,

    /// Member-specific data (use getters to access)
    attribute: ?Attribute = null,
    operation: ?Operation = null,
    constant: ?Constant = null,
    constructor: ?Constructor = null,
    iterable: ?Iterable = null,

    /// Get as attribute (returns null if not an attribute)
    pub fn asAttribute(self: Member) ?Attribute {
        return if (self.type == .attribute) self.attribute else null;
    }

    /// Get as operation (returns null if not an operation)
    pub fn asOperation(self: Member) ?Operation {
        return if (self.type == .operation) self.operation else null;
    }

    /// Get as constant (returns null if not a constant)
    pub fn asConstant(self: Member) ?Constant {
        return if (self.type == .constant) self.constant else null;
    }

    /// Get as constructor (returns null if not a constructor)
    pub fn asConstructor(self: Member) ?Constructor {
        return if (self.type == .constructor) self.constructor else null;
    }

    /// Get as iterable (returns null if not an iterable)
    pub fn asIterable(self: Member) ?Iterable {
        return if (self.type == .iterable) self.iterable else null;
    }
};

/// Member type discriminator
pub const MemberType = enum {
    attribute,
    operation,
    constant,
    constructor,
    iterable,
};

/// WebIDL attribute definition
pub const Attribute = struct {
    /// Attribute name
    name: []const u8,

    /// Attribute type
    idlType: IDLType,

    /// Whether this attribute is readonly
    readonly: bool = false,

    /// Whether this attribute is static
    static: bool = false,

    /// Extended attributes
    extAttrs: []ExtendedAttribute = &.{},
};

/// WebIDL operation (method) definition
pub const Operation = struct {
    /// Operation name (null for special operations like stringifiers)
    name: ?[]const u8 = null,

    /// Return type
    idlType: IDLType,

    /// Arguments
    arguments: []Argument = &.{},

    /// Whether this operation is static
    static: bool = false,

    /// Special operation type (getter, setter, deleter, etc.)
    special: ?SpecialOperation = null,

    /// Extended attributes
    extAttrs: []ExtendedAttribute = &.{},
};

/// Special operation types
pub const SpecialOperation = enum {
    getter,
    setter,
    deleter,
    stringifier,
};

/// WebIDL constant definition
pub const Constant = struct {
    /// Constant name
    name: []const u8,

    /// Constant type
    idlType: IDLType,

    /// Constant value
    value: Value,

    /// Extended attributes
    extAttrs: []ExtendedAttribute = &.{},
};

/// WebIDL constructor definition
pub const Constructor = struct {
    /// Constructor arguments
    arguments: []Argument = &.{},

    /// Extended attributes
    extAttrs: []ExtendedAttribute = &.{},
};

/// Operation/callback argument
pub const Argument = struct {
    /// Argument name
    name: []const u8,

    /// Argument type
    idlType: IDLType,

    /// Whether this argument is optional
    optional: bool = false,

    /// Whether this is a variadic argument
    variadic: bool = false,

    /// Default value (if any)
    default: ?Value = null,

    /// Extended attributes
    extAttrs: []ExtendedAttribute = &.{},
};

/// WebIDL type definition
pub const IDLType = struct {
    /// Type name (e.g., "boolean", "DOMString", "EventTarget")
    type: []const u8,

    /// Whether this type is nullable (T?)
    nullable: bool = false,

    /// Generic type arguments (e.g., Promise<T> has generic = [T])
    generic: ?[]const u8 = null,

    /// Union types (e.g., (DOMString or long))
    unionTypes: ?[]IDLType = null,

    /// Sequence element type (e.g., sequence<DOMString>)
    sequence: ?*IDLType = null,

    /// Record key/value types (e.g., record<DOMString, any>)
    record: ?struct {
        key: *IDLType,
        value: *IDLType,
    } = null,
};

/// Extended attribute (e.g., [Exposed=Window], [SameObject])
pub const ExtendedAttribute = struct {
    /// Attribute name
    name: []const u8,

    /// Right-hand side value (if any)
    rhs: ?ExtAttrRHS = null,
};

/// Extended attribute right-hand side
pub const ExtAttrRHS = union(enum) {
    /// Identifier value (e.g., [Exposed=Window])
    identifier: []const u8,

    /// Identifier list (e.g., [Exposed=(Window,Worker)])
    identifierList: [][]const u8,

    /// String literal
    string: []const u8,

    /// Integer literal
    integer: i64,
};

/// Constant/default value
pub const Value = union(enum) {
    /// Null value
    null,

    /// Boolean value
    boolean: bool,

    /// Integer value
    integer: i64,

    /// Float value
    float: f64,

    /// String value
    string: []const u8,

    /// Infinity value
    infinity: enum { positive, negative },

    /// NaN value
    nan,

    /// Empty sequence []
    emptySequence,

    /// Empty dictionary {}
    emptyDictionary,
};

// Unit tests
const testing = std.testing;

test "IDLFile has default empty slices" {
    const file: IDLFile = .{};
    try testing.expectEqual(@as(usize, 0), file.interfaces.len);
    try testing.expectEqual(@as(usize, 0), file.namespaces.len);
}

test "Interface has default values" {
    const iface: Interface = .{
        .name = "TestInterface",
    };
    try testing.expectEqualStrings("TestInterface", iface.name);
    try testing.expect(iface.inheritance == null);
    try testing.expectEqual(@as(usize, 0), iface.members.len);
    try testing.expectEqual(false, iface.partial);
    try testing.expectEqual(false, iface.mixin);
}

test "Member type discriminator" {
    const attr_member: Member = .{
        .type = .attribute,
        .attribute = .{
            .name = "foo",
            .idlType = .{ .type = "boolean" },
        },
    };

    try testing.expect(attr_member.asAttribute() != null);
    try testing.expect(attr_member.asOperation() == null);
    try testing.expect(attr_member.asConstant() == null);
}

test "Attribute defaults" {
    const attr: Attribute = .{
        .name = "test",
        .idlType = .{ .type = "DOMString" },
    };
    try testing.expectEqual(false, attr.readonly);
    try testing.expectEqual(false, attr.static);
}

test "Operation defaults" {
    const op: Operation = .{
        .idlType = .{ .type = "void" },
    };
    try testing.expect(op.name == null);
    try testing.expectEqual(false, op.static);
    try testing.expect(op.special == null);
}

test "IDLType basic" {
    const t: IDLType = .{ .type = "boolean" };
    try testing.expectEqualStrings("boolean", t.type);
    try testing.expectEqual(false, t.nullable);
}

test "IDLType nullable" {
    const t: IDLType = .{
        .type = "DOMString",
        .nullable = true,
    };
    try testing.expectEqual(true, t.nullable);
}

test "Value variants" {
    const v1: Value = .null;
    const v2: Value = .{ .boolean = true };
    const v3: Value = .{ .integer = 42 };
    const v4: Value = .{ .string = "test" };

    try testing.expect(v1 == .null);
    try testing.expect(v2 == .boolean);
    try testing.expectEqual(true, v2.boolean);
    try testing.expectEqual(@as(i64, 42), v3.integer);
    try testing.expectEqualStrings("test", v4.string);
}

test "ExtAttrRHS variants" {
    const rhs1: ExtAttrRHS = .{ .identifier = "Window" };
    const rhs2: ExtAttrRHS = .{ .integer = 10 };

    try testing.expectEqualStrings("Window", rhs1.identifier);
    try testing.expectEqual(@as(i64, 10), rhs2.integer);
}
