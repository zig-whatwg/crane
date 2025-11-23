//! Metadata Reader
//!
//! Uses Zig's comptime reflection to read metadata from generated WebIDL
//! interface and namespace modules, converting them into binding descriptors.
//!
//! This allows the JS bindings system to be fully automatic - as long as
//! WebIDL interfaces/namespaces are properly generated, the bindings are
//! automatically created without manual intervention.

const std = @import("std");
const types = @import("types.zig");
const NamespaceBinding = types.NamespaceBinding;
const InterfaceBinding = types.InterfaceBinding;
const MethodDescriptor = types.MethodDescriptor;
const AttributeDescriptor = types.AttributeDescriptor;
const ConstantDescriptor = types.ConstantDescriptor;
const ParameterDescriptor = types.ParameterDescriptor;
const TypeDescriptor = types.TypeDescriptor;
const TypeKind = types.TypeKind;

/// Extract namespace binding metadata from a Zig namespace module
///
/// Example usage:
/// ```zig
/// const console = @import("generated/namespaces/console.zig");
/// const binding = extractNamespaceMetadata(@TypeOf(console));
/// ```
pub fn extractNamespaceMetadata(comptime NamespaceType: type) NamespaceBinding {
    // Namespaces are simple - they only have static methods
    const type_info = @typeInfo(NamespaceType);

    const decls = switch (type_info) {
        .@"struct" => |s| s.decls,
        else => @compileError("NamespaceType must be a struct"),
    };

    var methods: []const MethodDescriptor = &.{};
    var constants: []const ConstantDescriptor = &.{};

    // Iterate through all declarations in the namespace
    inline for (decls) |decl| {
        const decl_value = @field(NamespaceType, decl.name);
        const decl_type = @TypeOf(decl_value);

        // Check if this is a function
        switch (@typeInfo(decl_type)) {
            .@"fn" => {
                // Extract method metadata
                const method = extractMethodMetadata(decl.name, decl_value);
                methods = methods ++ &[_]MethodDescriptor{method};
            },
            else => {
                // Check if this is a constant
                if (isConstant(decl.name)) {
                    const constant = extractConstantMetadata(decl.name, decl_value);
                    constants = constants ++ &[_]ConstantDescriptor{constant};
                }
            },
        }
    }

    return NamespaceBinding{
        .name = getNamespaceName(NamespaceType),
        .methods = methods,
        .constants = constants,
    };
}

/// Extract interface binding metadata from a Zig interface module
///
/// Example usage:
/// ```zig
/// const Element = @import("generated/interfaces/Element.zig");
/// const binding = extractInterfaceMetadata(@TypeOf(Element));
/// ```
pub fn extractInterfaceMetadata(comptime InterfaceType: type) InterfaceBinding {
    const type_info = @typeInfo(InterfaceType);

    const decls = switch (type_info) {
        .@"struct" => |s| s.decls,
        else => @compileError("Interface must be a struct type"),
    };

    var methods: []const MethodDescriptor = &.{};
    var attributes: []const AttributeDescriptor = &.{};
    var static_methods: []const MethodDescriptor = &.{};
    var static_attributes: []const AttributeDescriptor = &.{};
    var constants: []const ConstantDescriptor = &.{};

    // Track which attributes we've already processed (to avoid duplicates from get_/set_ pairs)
    comptime var processed_attributes: []const []const u8 = &.{};

    // Find parent interface (if any)
    const parent = findParentInterface(InterfaceType);

    // Find constructor (if any)
    const constructor = findConstructor(InterfaceType);

    // Iterate through all declarations
    inline for (decls) |decl| {
        // Skip special declarations
        if (std.mem.eql(u8, decl.name, "Self")) continue;
        if (std.mem.eql(u8, decl.name, "deinit")) continue;
        if (std.mem.eql(u8, decl.name, "init")) continue; // Constructor handled separately
        if (std.mem.eql(u8, decl.name, "vtable")) continue; // Skip vtable
        if (std.mem.eql(u8, decl.name, "Meta")) continue; // Skip Meta struct
        if (std.mem.eql(u8, decl.name, "State")) continue; // Skip State type
        if (std.mem.eql(u8, decl.name, "call_constructor")) continue; // Constructor handled separately

        const decl_value = @field(InterfaceType, decl.name);
        const decl_type = @TypeOf(decl_value);

        // Determine if this is static or instance member
        const is_static = isStaticMember(decl.name, decl_type);

        switch (@typeInfo(decl_type)) {
            .@"fn" => {
                // Check if this is a getter/setter (attribute) or method
                if (std.mem.startsWith(u8, decl.name, "get_")) {
                    // This is an attribute getter
                    const attr_name = decl.name[4..]; // Strip "get_" prefix

                    // Check if we've already processed this attribute
                    var already_processed = false;
                    inline for (processed_attributes) |processed| {
                        if (std.mem.eql(u8, processed, attr_name)) {
                            already_processed = true;
                            break;
                        }
                    }

                    if (!already_processed) {
                        const attribute = extractAttributeFromGetterSetter(attr_name, InterfaceType);
                        if (is_static) {
                            static_attributes = static_attributes ++ &[_]AttributeDescriptor{attribute};
                        } else {
                            attributes = attributes ++ &[_]AttributeDescriptor{attribute};
                        }
                        processed_attributes = processed_attributes ++ &[_][]const u8{attr_name};
                    }
                } else if (std.mem.startsWith(u8, decl.name, "set_")) {
                    // This is an attribute setter - will be handled when we process the getter
                    continue;
                } else if (std.mem.startsWith(u8, decl.name, "call_")) {
                    // This is a regular method
                    const method = extractMethodMetadata(decl.name, decl_value);
                    if (is_static) {
                        static_methods = static_methods ++ &[_]MethodDescriptor{method};
                    } else {
                        methods = methods ++ &[_]MethodDescriptor{method};
                    }
                } else {
                    // Other functions (might be utility functions)
                    // Treat as methods for now
                    const method = extractMethodMetadata(decl.name, decl_value);
                    if (is_static) {
                        static_methods = static_methods ++ &[_]MethodDescriptor{method};
                    } else {
                        methods = methods ++ &[_]MethodDescriptor{method};
                    }
                }
            },
            else => {
                // Check if this is a constant
                if (isConstant(decl.name)) {
                    const constant = extractConstantMetadata(decl.name, decl_value);
                    constants = constants ++ &[_]ConstantDescriptor{constant};
                }
            },
        }
    }

    return InterfaceBinding{
        .name = getInterfaceName(InterfaceType),
        .parent = parent,
        .constructor = constructor,
        .methods = methods,
        .attributes = attributes,
        .static_methods = static_methods,
        .static_attributes = static_attributes,
        .constants = constants,
    };
}

/// Extract method metadata from a function
fn extractMethodMetadata(comptime name: []const u8, comptime func: anytype) MethodDescriptor {
    const func_type = @TypeOf(func);
    const func_info = switch (@typeInfo(func_type)) {
        .@"fn" => |f| f,
        else => @compileError("Expected function type"),
    };

    // Extract parameters (skip 'self' parameter for instance methods)
    var parameters: []const ParameterDescriptor = &.{};
    const param_start = if (func_info.params.len > 0 and isSelfParam(func_info.params[0])) 1 else 0;

    inline for (func_info.params[param_start..], 0..) |param, i| {
        const param_desc = ParameterDescriptor{
            .name = std.fmt.comptimePrint("arg{d}", .{i}),
            .type = extractTypeDescriptor(param.type.?),
            .optional = false, // TODO: detect optional from param attributes
        };
        parameters = parameters ++ &[_]ParameterDescriptor{param_desc};
    }

    // Extract return type
    const return_type = extractTypeDescriptor(func_info.return_type.?);

    return MethodDescriptor{
        .name = name,
        .parameters = parameters,
        .return_type = return_type,
        .impl = @ptrCast(&func),
    };
}

/// Extract attribute metadata from getter/setter pair
///
/// Given an attribute name (without get_/set_ prefix), finds the getter and optional setter
fn extractAttributeFromGetterSetter(comptime attr_name: []const u8, comptime InterfaceType: type) AttributeDescriptor {
    const getter_name = "get_" ++ attr_name;
    const setter_name = "set_" ++ attr_name;

    const has_getter = @hasDecl(InterfaceType, getter_name);
    const has_setter = @hasDecl(InterfaceType, setter_name);

    if (!has_getter) {
        @compileError("Attribute '" ++ attr_name ++ "' must have a getter function '" ++ getter_name ++ "'");
    }

    const getter = @field(InterfaceType, getter_name);
    const getter_info = switch (@typeInfo(@TypeOf(getter))) {
        .@"fn" => |f| f,
        else => @compileError("Getter must be a function"),
    };

    // Extract return type from getter
    // Getter signature: fn(instance: *runtime.Instance) anyerror!T
    // We need to unwrap the error union to get the actual type
    const return_type_raw = getter_info.return_type.?;
    const attr_type = extractTypeDescriptor(return_type_raw);

    const setter: ?*const anyopaque = if (has_setter)
        @ptrCast(&@field(InterfaceType, setter_name))
    else
        null;

    return AttributeDescriptor{
        .name = attr_name,
        .type = attr_type,
        .readonly = !has_setter,
        .getter = @ptrCast(&getter),
        .setter = setter,
    };
}

/// Extract constant metadata
fn extractConstantMetadata(comptime name: []const u8, comptime value: anytype) ConstantDescriptor {
    const value_type = @TypeOf(value);

    return ConstantDescriptor{
        .name = name,
        .type = extractTypeDescriptor(value_type),
        .value = @ptrCast(&value),
    };
}

/// Extract type descriptor from a Zig type
fn extractTypeDescriptor(comptime T: type) TypeDescriptor {
    const type_info = @typeInfo(T);

    return switch (type_info) {
        .void => TypeDescriptor{ .kind = .void },
        .bool => TypeDescriptor{ .kind = .boolean },
        .int => |int_info| blk: {
            const kind: TypeKind = switch (int_info.signedness) {
                .signed => switch (int_info.bits) {
                    8 => .byte,
                    16 => .short,
                    32 => .long,
                    64 => .long_long,
                    else => @compileError("Unsupported int size"),
                },
                .unsigned => switch (int_info.bits) {
                    8 => .octet,
                    16 => .unsigned_short,
                    32 => .unsigned_long,
                    64 => .unsigned_long_long,
                    else => @compileError("Unsupported int size"),
                },
            };
            break :blk TypeDescriptor{ .kind = kind };
        },
        .float => |float_info| TypeDescriptor{
            .kind = if (float_info.bits == 32) .float else .double,
        },
        .pointer => |ptr_info| blk: {
            // Check for string types
            if (ptr_info.size == .slice and ptr_info.child == u8) {
                break :blk TypeDescriptor{ .kind = .dom_string };
            }
            // Check for interface types (pointers to structs)
            if (ptr_info.size == .one and @typeInfo(ptr_info.child) == .@"struct") {
                break :blk TypeDescriptor{ .kind = .interface };
            }
            // Default to any for unknown pointer types
            break :blk TypeDescriptor{ .kind = .any };
        },
        .optional => |opt_info| blk: {
            var base_type = extractTypeDescriptor(opt_info.child);
            base_type.nullable = true;
            break :blk base_type;
        },
        .@"struct" => TypeDescriptor{ .kind = .interface },
        .@"enum" => TypeDescriptor{ .kind = .enumeration },
        else => TypeDescriptor{ .kind = .any },
    };
}

/// Check if a parameter is a 'self' parameter
fn isSelfParam(comptime param: std.builtin.Type.Fn.Param) bool {
    if (param.type) |param_type| {
        const type_info = @typeInfo(param_type);
        switch (type_info) {
            .pointer => |ptr_info| {
                if (ptr_info.size == .one) {
                    return switch (@typeInfo(ptr_info.child)) {
                        .@"struct" => true,
                        else => false,
                    };
                }
            },
            else => {},
        }
    }
    return false;
}

/// Check if a declaration name indicates a constant (all uppercase)
fn isConstant(comptime name: []const u8) bool {
    if (name.len == 0) return false;

    // Constants are typically ALL_CAPS
    var has_upper = false;
    var has_lower = false;

    for (name) |char| {
        if (char >= 'A' and char <= 'Z') has_upper = true;
        if (char >= 'a' and char <= 'z') has_lower = true;
    }

    return has_upper and !has_lower;
}

/// Check if a declaration is attribute-like
fn isAttributeLike(comptime name: []const u8, comptime T: type) bool {
    _ = T;
    // Attributes are typically camelCase or snake_case
    // Not functions, not constants
    return !isConstant(name);
}

/// Check if a member is static
fn isStaticMember(comptime name: []const u8, comptime T: type) bool {
    _ = name;
    const type_info = @typeInfo(T);
    switch (type_info) {
        .@"fn" => |func_info| {
            // Static methods don't have a 'self' parameter
            if (func_info.params.len == 0) return true;
            return !isSelfParam(func_info.params[0]);
        },
        else => return false,
    }
}

/// Get namespace name from type
fn getNamespaceName(comptime NamespaceType: type) []const u8 {
    const type_name = @typeName(NamespaceType);
    // Extract last component after last '.'
    var i = type_name.len;
    while (i > 0) {
        i -= 1;
        if (type_name[i] == '.') {
            return type_name[i + 1 ..];
        }
    }
    return type_name;
}

/// Get interface name from type
fn getInterfaceName(comptime InterfaceType: type) []const u8 {
    const type_name = @typeName(InterfaceType);
    // Extract last component after last '.'
    var i = type_name.len;
    while (i > 0) {
        i -= 1;
        if (type_name[i] == '.') {
            return type_name[i + 1 ..];
        }
    }
    return type_name;
}

/// Find parent interface name (if any)
fn findParentInterface(comptime InterfaceType: type) ?[]const u8 {
    // Check if there's a 'parent' field or declaration
    if (@hasDecl(InterfaceType, "parent_interface")) {
        return @field(InterfaceType, "parent_interface");
    }
    return null;
}

/// Find constructor descriptor (if any)
fn findConstructor(comptime InterfaceType: type) ?types.ConstructorDescriptor {
    if (@hasDecl(InterfaceType, "init")) {
        const init_fn = @field(InterfaceType, "init");
        const func_info = switch (@typeInfo(@TypeOf(init_fn))) {
            .@"fn" => |f| f,
            else => return null,
        };

        // Extract constructor parameters
        var parameters: []const ParameterDescriptor = &.{};
        inline for (func_info.params, 0..) |param, i| {
            // Skip allocator parameter (first param)
            if (i == 0) continue;

            const param_desc = ParameterDescriptor{
                .name = std.fmt.comptimePrint("arg{d}", .{i - 1}),
                .type = extractTypeDescriptor(param.type.?),
                .optional = false,
            };
            parameters = parameters ++ &[_]ParameterDescriptor{param_desc};
        }

        return types.ConstructorDescriptor{
            .parameters = parameters,
            .impl = @ptrCast(&init_fn),
        };
    }
    return null;
}
