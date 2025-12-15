//! WebIDL Function Overloading Support
//!
//! This module provides utilities for detecting and handling WebIDL function overloading.
//! Since Zig doesn't support function overloading, we use tagged unions to represent
//! different overload signatures and generate dispatch functions.

const std = @import("std");
const types = @import("types.zig");

/// A group of operations with the same name (overload set)
pub const OverloadSet = struct {
    name: []const u8,
    operations: []const types.Operation,

    /// Check if this is an overloaded operation (more than one signature)
    pub fn isOverloaded(self: OverloadSet) bool {
        return self.operations.len > 1;
    }
};

/// A group of constructors (overload set)
/// All constructors for an interface are grouped together
pub const ConstructorSet = struct {
    constructors: []const types.Constructor,

    /// Check if constructors are overloaded (more than one signature)
    pub fn isOverloaded(self: ConstructorSet) bool {
        return self.constructors.len > 1;
    }
};

/// Compound key for grouping operations by name AND static/instance status
const OperationKey = struct {
    name: []const u8,
    is_static: bool,

    pub fn hash(self: OperationKey) u64 {
        var h = std.hash.Wyhash.init(0);
        h.update(self.name);
        h.update(&[_]u8{if (self.is_static) 1 else 0});
        return h.final();
    }

    pub fn eql(self: OperationKey, other: OperationKey) bool {
        return self.is_static == other.is_static and std.mem.eql(u8, self.name, other.name);
    }
};

const OperationKeyContext = struct {
    pub fn hash(_: OperationKeyContext, key: OperationKey) u64 {
        return key.hash();
    }
    pub fn eql(_: OperationKeyContext, a: OperationKey, b: OperationKey) bool {
        return a.eql(b);
    }
};

/// Group operations by name AND static status to detect overloads
/// Static and instance methods with the same name are NOT grouped together
pub fn groupOperationsByName(
    allocator: std.mem.Allocator,
    operations: []const types.Operation,
) ![]OverloadSet {
    var groups = std.HashMap(OperationKey, std.ArrayList(types.Operation), OperationKeyContext, std.hash_map.default_max_load_percentage).init(allocator);
    defer {
        var iter = groups.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit(allocator);
        }
        groups.deinit();
    }

    // Group operations by name AND static status
    // This ensures static json(data, init) and instance json() are separate groups
    for (operations) |op| {
        const name = op.name orelse continue; // Skip unnamed operations

        const key = OperationKey{ .name = name, .is_static = op.static };
        const entry = try groups.getOrPut(key);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(types.Operation).empty;
        }

        try entry.value_ptr.append(allocator, op);
    }

    // Convert to OverloadSet array
    var result = std.ArrayList(OverloadSet).empty;
    errdefer result.deinit(allocator);

    var iter = groups.iterator();
    while (iter.next()) |entry| {
        const owned_name = try allocator.dupe(u8, entry.key_ptr.name);
        const owned_ops = try entry.value_ptr.toOwnedSlice(allocator);

        try result.append(allocator, .{
            .name = owned_name,
            .operations = owned_ops,
        });
    }

    return try result.toOwnedSlice(allocator);
}

/// Free memory allocated for overload sets
pub fn freeOverloadSets(allocator: std.mem.Allocator, sets: []OverloadSet) void {
    for (sets) |set| {
        allocator.free(set.name);
        allocator.free(set.operations);
    }
    allocator.free(sets);
}

/// Generate a unique name for an overload variant based on its parameters
pub fn generateVariantName(
    allocator: std.mem.Allocator,
    op: types.Operation,
) ![]const u8 {
    if (op.arguments.len == 0) {
        return try allocator.dupe(u8, "no_params");
    }

    // Generate name based on parameter types
    var name_parts = std.ArrayList([]const u8).empty;
    defer {
        for (name_parts.items) |part| allocator.free(part);
        name_parts.deinit(allocator);
    }

    for (op.arguments) |arg| {
        const simplified_type = simplifyTypeName(arg.idlType.type);
        try name_parts.append(allocator, try allocator.dupe(u8, simplified_type));
    }

    // Join with underscores
    return try std.mem.join(allocator, "_", name_parts.items);
}

/// Simplify a WebIDL type name for use in variant names
fn simplifyTypeName(type_name: []const u8) []const u8 {
    // Handle union types: "(Type1 or Type2)" → "union"
    if (std.mem.startsWith(u8, type_name, "(")) {
        return "union";
    }

    // Map common types to short names (do this before handling "unrestricted")
    if (std.mem.eql(u8, type_name, "DOMString")) return "string";
    if (std.mem.eql(u8, type_name, "boolean")) return "bool";
    if (std.mem.eql(u8, type_name, "double")) return "double";
    if (std.mem.eql(u8, type_name, "unrestricted double")) return "unrestricted_double";
    if (std.mem.eql(u8, type_name, "unrestricted float")) return "unrestricted_float";
    if (std.mem.eql(u8, type_name, "long")) return "long";
    if (std.mem.eql(u8, type_name, "unsigned long")) return "unsigned_long";
    if (std.mem.eql(u8, type_name, "unsigned short")) return "unsigned_short";
    if (std.mem.eql(u8, type_name, "unsigned long long")) return "unsigned_long_long";
    if (std.mem.eql(u8, type_name, "long long")) return "long_long";
    if (std.mem.eql(u8, type_name, "any")) return "any";
    if (std.mem.eql(u8, type_name, "object")) return "object";

    // Return as-is for other types (they should be single identifiers)
    return type_name;
}

/// Check if two operations have the same signature (for deduplication)
pub fn haveSameSignature(op1: types.Operation, op2: types.Operation) bool {
    if (op1.arguments.len != op2.arguments.len) return false;

    for (op1.arguments, op2.arguments) |arg1, arg2| {
        if (!std.mem.eql(u8, arg1.idlType.type, arg2.idlType.type)) {
            return false;
        }
    }

    return true;
}

/// Group constructors (all constructors for an interface form one overload set)
pub fn groupConstructors(
    allocator: std.mem.Allocator,
    constructors: []const types.Constructor,
) !ConstructorSet {
    // All constructors belong to the same overload set
    const owned_ctors = try allocator.dupe(types.Constructor, constructors);
    return ConstructorSet{
        .constructors = owned_ctors,
    };
}

/// Free memory allocated for constructor set
pub fn freeConstructorSet(allocator: std.mem.Allocator, set: ConstructorSet) void {
    allocator.free(set.constructors);
}

/// Generate a unique name for a constructor variant based on its parameters
pub fn generateConstructorVariantName(
    allocator: std.mem.Allocator,
    ctor: types.Constructor,
) ![]const u8 {
    if (ctor.arguments.len == 0) {
        return try allocator.dupe(u8, "no_params");
    }

    // Generate name based on parameter types
    var name_parts = std.ArrayList([]const u8).empty;
    defer {
        for (name_parts.items) |part| allocator.free(part);
        name_parts.deinit(allocator);
    }

    for (ctor.arguments) |arg| {
        const simplified_type = simplifyTypeName(arg.idlType.type);
        try name_parts.append(allocator, try allocator.dupe(u8, simplified_type));
    }

    // Join with underscores
    const joined = try std.mem.join(allocator, "_", name_parts.items);
    defer allocator.free(joined);

    // Sanitize the result (remove invalid Zig identifier characters like '?')
    var result = try allocator.alloc(u8, joined.len);
    var write_idx: usize = 0;
    for (joined) |c| {
        if (c == '?' or c == '(' or c == ')' or c == ' ') {
            // Skip invalid characters
            continue;
        }
        result[write_idx] = c;
        write_idx += 1;
    }

    // Resize to actual length
    return allocator.realloc(result, write_idx);
}
