//! Shared signature generation for WebIDL codegen
//!
//! This module provides unified signature generation used by both
//! interface files (writer.zig) and impl stub files (generator.zig).
//!
//! The goal is to ensure interfaces and impls always have matching
//! function signatures, differing only in the error type:
//! - Interface: anyerror!T
//! - Impl: ImplError!T

const std = @import("std");
const types = @import("types.zig");
const ir_mod = @import("ir.zig");

/// Configuration for signature generation
pub const SignatureConfig = struct {
    /// Error type to use in return signatures
    /// - For interfaces: "anyerror"
    /// - For impls: "ImplError"
    error_type: []const u8 = "anyerror",

    /// Type registry for resolving custom types
    type_registry: ?*const ir_mod.TypeRegistry = null,
};

/// Reserved names that conflict with impl file declarations
const impl_reserved_names = [_][]const u8{
    "init",
    "deinit",
    "State",
    "InternalState",
    "ImplError",
};

/// Reserved names that conflict with interface file declarations
const interface_reserved_names = [_][]const u8{
    "init",
    "deinit",
    "State",
};

/// Zig keywords that need @"..." escaping for identifiers
const zig_keywords = [_][]const u8{
    "type",     "error",       "defer",   "return",   "var",      "const",     "fn",       "struct",
    "enum",     "union",       "opaque",  "try",      "catch",    "async",     "await",    "suspend",
    "resume",   "export",      "extern",  "pub",      "inline",   "comptime",  "callconv", "test",
    "and",      "or",          "switch",  "if",       "else",     "while",     "for",      "break",
    "continue", "unreachable", "anytype", "anyframe", "anyerror", "anyopaque", "align",
};

/// Check if a name is a Zig keyword
pub fn isZigKeyword(name: []const u8) bool {
    for (zig_keywords) |keyword| {
        if (std.mem.eql(u8, name, keyword)) {
            return true;
        }
    }
    return false;
}

/// Check if name is reserved in impl context
fn isImplReservedName(name: []const u8) bool {
    for (impl_reserved_names) |reserved| {
        if (std.mem.eql(u8, name, reserved)) {
            return true;
        }
    }
    return false;
}

/// Check if name is reserved in interface context
fn isInterfaceReservedName(name: []const u8) bool {
    for (interface_reserved_names) |reserved| {
        if (std.mem.eql(u8, name, reserved)) {
            return true;
        }
    }
    return false;
}

/// Check if a parameter name shadows its type
/// e.g., parameter "RestrictionTarget" of type RestrictionTarget
fn parameterShadowsType(name: []const u8, idl_type: types.IDLType) bool {
    // Case-insensitive comparison for shadowing
    const type_name = idl_type.type;
    if (name.len != type_name.len) return false;

    for (name, type_name) |n, t| {
        if (std.ascii.toLower(n) != std.ascii.toLower(t)) return false;
    }
    return true;
}

/// Write an escaped parameter name suitable for both interface and impl files
///
/// This uses a unified escaping strategy:
/// - Reserved names (init, deinit, etc.) -> name_data
/// - Zig keywords (type, error, etc.) -> @"name"
/// - Type-shadowing names -> lowercasename_param
pub fn writeEscapedParamName(writer: anytype, name: []const u8, idl_type: types.IDLType) !void {
    // Check for reserved names first (both impl and interface)
    if (isImplReservedName(name) or isInterfaceReservedName(name)) {
        try writer.print("{s}_data", .{name});
        return;
    }

    // Check for type shadowing (e.g., RestrictionTarget param of type RestrictionTarget)
    if (parameterShadowsType(name, idl_type)) {
        var buf: [256]u8 = undefined;
        const lower_name = std.ascii.lowerString(&buf, name);
        try writer.print("{s}_param", .{lower_name});
        return;
    }

    // Check for Zig keywords
    if (isZigKeyword(name)) {
        try writer.print("@\"{s}\"", .{name});
        return;
    }

    // Normal names pass through unchanged
    try writer.print("{s}", .{name});
}

/// Sanitize a name for use in function names (cannot use @"..." for functions)
/// Converts hyphens to underscores
pub fn sanitizeFunctionName(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    // Check if name contains hyphens
    if (std.mem.indexOfScalar(u8, name, '-')) |_| {
        // Replace hyphens with underscores
        const result = try allocator.alloc(u8, name.len);
        for (name, 0..) |c, i| {
            result[i] = if (c == '-') '_' else c;
        }
        return result;
    }
    // No hyphens, return as-is (no allocation needed)
    return name;
}

/// Check if union is (Node or DOMString) pattern
fn isNodeOrDOMStringUnion(union_types: []const types.IDLType) bool {
    if (union_types.len != 2) return false;

    var has_node = false;
    var has_string = false;

    for (union_types) |ut| {
        if (std.mem.eql(u8, ut.type, "Node")) has_node = true;
        if (std.mem.eql(u8, ut.type, "DOMString") or
            std.mem.eql(u8, ut.type, "USVString") or
            std.mem.eql(u8, ut.type, "TrustedScript"))
        {
            has_string = true;
        }
    }

    return has_node and has_string;
}

/// Check if union is (TrustedType or String) pattern
fn isTrustedTypeOrStringUnion(union_types: []const types.IDLType) bool {
    for (union_types) |ut| {
        if (std.mem.startsWith(u8, ut.type, "Trusted")) {
            return true;
        }
    }
    return false;
}

/// Write a parameter type with proper wrapping for optional/variadic/nullable
pub fn writeParamType(writer: anytype, arg: types.Argument, config: SignatureConfig) !void {
    // Handle optional parameters: optional T becomes webidl.Opt(T)
    if (arg.optional) {
        try writer.writeAll("webidl.Opt(");
    }

    // Handle variadic parameters: T... becomes []const T
    if (arg.variadic) {
        try writer.writeAll("[]const ");
    }

    // Check for union types FIRST (before anyopaque fallback)
    if (arg.idlType.unionTypes) |union_types| {
        if (isNodeOrDOMStringUnion(union_types)) {
            // Handle nullable: (Node or DOMString)? is unusual but possible
            if (arg.idlType.nullable and !arg.variadic) {
                try writer.writeAll("?");
            }
            try writer.writeAll("mixins.ParentNode.NodeOrString");

            // Close optional wrapper if needed
            if (arg.optional) {
                try writer.writeAll(")");
            }
            return;
        }
        if (isTrustedTypeOrStringUnion(union_types)) {
            if (arg.idlType.nullable and !arg.variadic) {
                try writer.writeAll("?");
            }
            try writer.writeAll("runtime.DOMString");
            if (arg.optional) {
                try writer.writeAll(")");
            }
            return;
        }
        // Other union types - use anyopaque pointer
        if (arg.idlType.nullable and !arg.variadic) {
            try writer.writeAll("?");
        }
        try writer.writeAll("*const anyopaque");
        if (arg.optional) {
            try writer.writeAll(")");
        }
        return;
    }

    // Handle nullable parameters: T? becomes ?T (but not for variadic - slice handles null)
    if (arg.idlType.nullable and !arg.variadic) {
        try writer.writeAll("?");
    }

    // Write the base type
    try writeType(writer, arg.idlType, config);

    // Close optional wrapper
    if (arg.optional) {
        try writer.writeAll(")");
    }
}

/// Write a WebIDL type as Zig type string
pub fn writeType(writer: anytype, idl_type: types.IDLType, config: SignatureConfig) !void {
    // Handle union types first
    if (idl_type.unionTypes) |union_types| {
        if (isNodeOrDOMStringUnion(union_types)) {
            try writer.writeAll("mixins.ParentNode.NodeOrString");
            return;
        }
        if (isTrustedTypeOrStringUnion(union_types)) {
            try writer.writeAll("runtime.DOMString");
            return;
        }
        // Fallback for other union types
        try writer.writeAll("*const anyopaque");
        return;
    }

    var type_str = idl_type.type;

    // Strip namespace prefix if present (e.g., "dom::DOMString" -> "DOMString")
    if (std.mem.indexOf(u8, type_str, "::")) |colon_pos| {
        type_str = type_str[colon_pos + 2 ..];
    }

    // Map primitive types
    if (std.mem.eql(u8, type_str, "boolean")) {
        try writer.writeAll("bool");
    } else if (std.mem.eql(u8, type_str, "byte")) {
        try writer.writeAll("i8");
    } else if (std.mem.eql(u8, type_str, "octet")) {
        try writer.writeAll("u8");
    } else if (std.mem.eql(u8, type_str, "short")) {
        try writer.writeAll("i16");
    } else if (std.mem.eql(u8, type_str, "unsigned short")) {
        try writer.writeAll("u16");
    } else if (std.mem.eql(u8, type_str, "long")) {
        try writer.writeAll("i32");
    } else if (std.mem.eql(u8, type_str, "unsigned long")) {
        try writer.writeAll("u32");
    } else if (std.mem.eql(u8, type_str, "long long")) {
        try writer.writeAll("i64");
    } else if (std.mem.eql(u8, type_str, "unsigned long long")) {
        try writer.writeAll("u64");
    } else if (std.mem.eql(u8, type_str, "float") or std.mem.eql(u8, type_str, "unrestricted float")) {
        try writer.writeAll("f32");
    } else if (std.mem.eql(u8, type_str, "double") or std.mem.eql(u8, type_str, "unrestricted double")) {
        try writer.writeAll("f64");
    } else if (std.mem.eql(u8, type_str, "void") or std.mem.eql(u8, type_str, "undefined")) {
        try writer.writeAll("void");
    } else if (std.mem.eql(u8, type_str, "any") or std.mem.eql(u8, type_str, "object")) {
        try writer.writeAll("v8.JSValue");
    } else if (std.mem.eql(u8, type_str, "DOMString") or std.mem.eql(u8, type_str, "USVString") or std.mem.eql(u8, type_str, "ByteString")) {
        try writer.print("runtime.{s}", .{type_str});
    } else if (std.mem.eql(u8, type_str, "ArrayBuffer") or std.mem.eql(u8, type_str, "ArrayBufferView")) {
        try writer.print("runtime.{s}", .{type_str});
    } else if (std.mem.startsWith(u8, type_str, "sequence<") or std.mem.startsWith(u8, type_str, "FrozenArray<")) {
        try writer.writeAll("*const anyopaque");
    } else if (std.mem.startsWith(u8, type_str, "Promise<")) {
        try writer.writeAll("*const anyopaque");
    } else if (std.mem.startsWith(u8, type_str, "record<")) {
        try writer.writeAll("*const anyopaque");
    } else {
        // Check type registry for custom types
        if (config.type_registry) |reg| {
            if (reg.lookup(type_str)) |kind| {
                switch (kind) {
                    .interface, .callback_interface => {
                        // Interfaces use runtime.Instance pointer
                        try writer.writeAll("*runtime.Instance");
                        return;
                    },
                    .typedef => {
                        try writer.print("typedefs.{s}", .{type_str});
                        return;
                    },
                    .dictionary => {
                        try writer.print("dictionaries.{s}", .{type_str});
                        return;
                    },
                    .enum_type => {
                        try writer.print("enums.{s}", .{type_str});
                        return;
                    },
                    .callback => {
                        try writer.print("callbacks.{s}", .{type_str});
                        return;
                    },
                    .namespace => {
                        try writer.print("namespaces.{s}", .{type_str});
                        return;
                    },
                    .primitive => {
                        // Primitives already handled above
                    },
                }
            }
        }

        // Unknown type - use anyopaque pointer
        try writer.writeAll("*const anyopaque");
    }
}

/// Write a return type with error union
pub fn writeReturnType(writer: anytype, idl_type: types.IDLType, config: SignatureConfig) !void {
    try writer.print("{s}!", .{config.error_type});

    // Handle nullable return types
    if (idl_type.nullable) {
        try writer.writeAll("?");
    }

    try writeType(writer, idl_type, config);
}

/// Write a getter signature
pub fn writeGetterSignature(
    writer: anytype,
    attr_name: []const u8,
    idl_type: types.IDLType,
    config: SignatureConfig,
) !void {
    try writer.print("pub fn get_{s}(instance: *runtime.Instance) ", .{attr_name});
    try writeReturnType(writer, idl_type, config);
}

/// Write a setter signature
pub fn writeSetterSignature(
    writer: anytype,
    attr_name: []const u8,
    idl_type: types.IDLType,
    config: SignatureConfig,
) !void {
    try writer.print("pub fn set_{s}(instance: *runtime.Instance, value: ", .{attr_name});

    // Handle nullable for value type
    if (idl_type.nullable) {
        try writer.writeAll("?");
    }
    try writeType(writer, idl_type, config);

    try writer.print(") {s}!void", .{config.error_type});
}

/// Write an operation signature (single, non-overloaded)
pub fn writeOperationSignature(
    writer: anytype,
    op: types.Operation,
    config: SignatureConfig,
) !void {
    const name = op.name orelse return;

    try writer.print("pub fn call_{s}(instance: *runtime.Instance", .{name});

    // Write parameters
    for (op.arguments) |arg| {
        try writer.writeAll(", ");
        try writeEscapedParamName(writer, arg.name, arg.idlType);
        try writer.writeAll(": ");
        try writeParamType(writer, arg, config);
    }

    try writer.writeAll(") ");
    try writeReturnType(writer, op.idlType, config);
}

/// Write an overloaded operation signature (accepts Args union)
pub fn writeOverloadedOperationSignature(
    writer: anytype,
    op_name: []const u8,
    interface_name: []const u8,
    return_type: types.IDLType,
    config: SignatureConfig,
) !void {
    const allocator = std.heap.page_allocator;

    // Generate Args union type name: "StartArgs", "ItemArgs", etc.
    var capitalized_name = std.ArrayList(u8).init(allocator);
    defer capitalized_name.deinit();
    try capitalized_name.append(std.ascii.toUpper(op_name[0]));
    try capitalized_name.appendSlice(op_name[1..]);
    try capitalized_name.appendSlice("Args");

    try writer.print("pub fn call_{s}(instance: *runtime.Instance, args: interfaces.{s}.{s}) ", .{
        op_name,
        interface_name,
        capitalized_name.items,
    });
    try writeReturnType(writer, return_type, config);
}

/// Write a constructor signature
pub fn writeConstructorSignature(
    writer: anytype,
    ctor: types.Constructor,
    config: SignatureConfig,
) !void {
    try writer.writeAll("pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context");

    for (ctor.arguments) |arg| {
        try writer.writeAll(", ");
        try writeEscapedParamName(writer, arg.name, arg.idlType);
        try writer.writeAll(": ");
        try writeParamType(writer, arg, config);
    }

    try writer.writeAll(") !*runtime.Instance");
}

/// Write an overloaded constructor signature (accepts ConstructorArgs union)
pub fn writeOverloadedConstructorSignature(
    writer: anytype,
    interface_name: []const u8,
) !void {
    try writer.print("pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, args: interfaces.{s}.ConstructorArgs) !*runtime.Instance", .{interface_name});
}

// Tests
test "isZigKeyword" {
    try std.testing.expect(isZigKeyword("type"));
    try std.testing.expect(isZigKeyword("error"));
    try std.testing.expect(isZigKeyword("return"));
    try std.testing.expect(!isZigKeyword("foo"));
    try std.testing.expect(!isZigKeyword("myVariable"));
}

test "sanitizeFunctionName" {
    const allocator = std.testing.allocator;

    // Normal names pass through
    const normal = try sanitizeFunctionName(allocator, "myFunction");
    try std.testing.expectEqualStrings("myFunction", normal);
    // No allocation for normal names, so no free needed

    // Hyphenated names get underscores
    const hyphenated = try sanitizeFunctionName(allocator, "my-function-name");
    defer allocator.free(hyphenated);
    try std.testing.expectEqualStrings("my_function_name", hyphenated);
}
