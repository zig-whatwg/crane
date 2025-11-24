//! Cross-Interface Reference Resolution
//!
//! This module provides functions for resolving references between WebIDL interfaces.

const std = @import("std");
const types = @import("types.zig");

/// Collect all interface references from an interface definition
///
/// This includes:
/// - Base type (inheritance)
/// - Mixin types (includes)
/// - Attribute types
/// - Operation parameter types
/// - Operation return types
///
/// Returns an allocated list of unique interface names.
/// Caller owns the returned slice and all strings within it.
pub fn collectInterfaceReferences(
    allocator: std.mem.Allocator,
    interface: types.Interface,
) ![][]const u8 {
    var refs = std.StringHashMap(void).init(allocator);
    defer refs.deinit();

    // Add base type
    if (interface.inheritance) |base| {
        try refs.put(base, {});
    }

    // Add mixins
    for (interface.includes) |mixin| {
        try refs.put(mixin, {});
    }

    // Add types from members
    for (interface.members) |member| {
        switch (member.type) {
            .attribute => if (member.attribute) |attr| {
                try collectTypeReferences(&refs, attr.idlType);
            },
            .operation => if (member.operation) |op| {
                try collectTypeReferences(&refs, op.idlType);
                for (op.arguments) |arg| {
                    try collectTypeReferences(&refs, arg.idlType);
                }
            },
            .constructor => if (member.constructor) |ctor| {
                for (ctor.arguments) |arg| {
                    try collectTypeReferences(&refs, arg.idlType);
                }
            },
            .constant => if (member.constant) |const_val| {
                try collectTypeReferences(&refs, const_val.idlType);
            },
            .iterable => if (member.iterable) |iter| {
                try collectTypeReferences(&refs, iter.keyType);
                if (iter.valueType) |vtype| {
                    try collectTypeReferences(&refs, vtype);
                }
            },
            .async_iterable => if (member.async_iterable) |async_iter| {
                try collectTypeReferences(&refs, async_iter.keyType);
                if (async_iter.valueType) |vtype| {
                    try collectTypeReferences(&refs, vtype);
                }
                for (async_iter.arguments) |arg| {
                    try collectTypeReferences(&refs, arg.idlType);
                }
            },
        }
    }

    // Convert to slice
    var result = std.ArrayList([]const u8).empty;
    errdefer {
        for (result.items) |item| allocator.free(item);
        result.deinit(allocator);
    }

    var iter = refs.keyIterator();
    while (iter.next()) |key| {
        const name = try allocator.dupe(u8, key.*);
        try result.append(allocator, name);
    }

    return result.toOwnedSlice(allocator);
}

/// Parse a union type string and collect member type references
/// Input: "(Type1 or Type2 or Type3)" or "(Type1 or Type2)?"
/// Extracts: Type1, Type2, Type3 (skipping primitives)
fn collectUnionMemberReferences(refs: *std.StringHashMap(void), union_string: []const u8) !void {
    var trimmed = union_string;

    // Remove leading '(' and trailing ')' or ')?'
    if (trimmed.len > 0 and trimmed[0] == '(') {
        trimmed = trimmed[1..];
    }
    if (trimmed.len > 0 and trimmed[trimmed.len - 1] == ')') {
        trimmed = trimmed[0 .. trimmed.len - 1];
    } else if (trimmed.len > 1 and trimmed[trimmed.len - 1] == '?' and trimmed[trimmed.len - 2] == ')') {
        trimmed = trimmed[0 .. trimmed.len - 2];
    }

    // Split on " or "
    var iter = std.mem.splitSequence(u8, trimmed, " or ");
    while (iter.next()) |type_name_raw| {
        // Trim whitespace
        var type_name = std.mem.trim(u8, type_name_raw, " \t\n\r");

        // Remove trailing '?' for nullable types
        if (type_name.len > 0 and type_name[type_name.len - 1] == '?') {
            type_name = type_name[0 .. type_name.len - 1];
        }

        // Skip primitive types
        if (isPrimitiveType(type_name)) {
            continue;
        }

        // Add non-primitive types to refs
        if (type_name.len > 0) {
            try refs.put(type_name, {});
        }
    }
}

/// Collect interface references from a type
fn collectTypeReferences(refs: *std.StringHashMap(void), idl_type: types.IDLType) !void {
    // Skip if type is empty or invalid
    if (idl_type.type.len == 0) {
        return;
    }

    // Check if this is a generic wrapper type (sequence, Promise, FrozenArray, etc.)
    // Don't add the wrapper itself, just recurse into the inner type
    if (isGenericWrapperType(idl_type.type)) {
        // First, try the structured field (idl_type.sequence)
        if (idl_type.sequence) |seq| {
            try collectTypeReferences(refs, seq.*);
            return;
        }

        // Second, check the .generic field (populated by our parser)
        // This is the string form: Promise<Response> has generic="Response"
        if (idl_type.generic) |generic_param| {
            // Check if the inner type is an interface (not a primitive)
            if (!isPrimitiveType(generic_param)) {
                const clean = cleanTypeName(generic_param);
                if (clean.len > 0) {
                    try refs.put(clean, {});
                }
            }
            return;
        }

        // Fallback: Extract inner type from string like "FrozenArray<BluetoothLEScanFilter>"
        if (extractInnerType(idl_type.type)) |inner_type_name| {
            // Check if the inner type is an interface (not a primitive)
            if (!isPrimitiveType(inner_type_name)) {
                const clean = cleanTypeName(inner_type_name);
                if (clean.len > 0) {
                    try refs.put(clean, {});
                }
            }
        }
        return;
    }

    // Check if this is an interface type (not a primitive)
    if (isPrimitiveType(idl_type.type)) {
        // Still need to check union types even for primitives
        if (idl_type.unionTypes) |union_types| {
            for (union_types) |ut| {
                try collectTypeReferences(refs, ut);
            }
        }
        return;
    }

    // Clean the type name (remove nullable suffix if present)
    const clean_type = cleanTypeName(idl_type.type);

    // Add the type name (only if it's not empty after cleaning and not a union type string)
    // Union types look like "(TypeA or TypeB)"
    if (clean_type.len > 0 and !std.mem.startsWith(u8, clean_type, "(")) {
        try refs.put(clean_type, {});
    } else if (std.mem.startsWith(u8, clean_type, "(")) {
        // Parse union type string: "(Type1 or Type2 or Type3)"
        // Extract member types and add them individually
        try collectUnionMemberReferences(refs, clean_type);
    }

    // Recurse into generic types
    if (idl_type.sequence) |seq| {
        try collectTypeReferences(refs, seq.*);
    }

    if (idl_type.record) |rec| {
        try collectTypeReferences(refs, rec.key.*);
        try collectTypeReferences(refs, rec.value.*);
    }

    // Handle union types
    if (idl_type.unionTypes) |union_types| {
        for (union_types) |ut| {
            try collectTypeReferences(refs, ut);
        }
    }
}

/// Check if a type is a WebIDL primitive type
fn isPrimitiveType(type_name: []const u8) bool {
    const primitives = [_][]const u8{
        "void",
        "undefined", // WebIDL return type (like void)
        "boolean",
        "byte",
        "octet",
        "short",
        "unsigned short",
        "long",
        "unsigned long",
        "long long",
        "unsigned long long",
        "float",
        "unrestricted float",
        "double",
        "unrestricted double",
        // Note: DOMString, ByteString, USVString are typedefs, not primitives
        "object",
        "symbol",
        "any",
    };

    for (primitives) |prim| {
        if (std.mem.eql(u8, type_name, prim)) {
            return true;
        }
    }

    return false;
}

/// Check if a type is a generic wrapper type (sequence, Promise, FrozenArray, etc.)
/// These types wrap other types and shouldn't be imported as interfaces themselves
/// Handles both bare names (e.g., "FrozenArray") and parameterized names (e.g., "FrozenArray<T>")
fn isGenericWrapperType(type_name: []const u8) bool {
    const wrappers = [_][]const u8{
        "sequence",
        "FrozenArray",
        "ObservableArray",
        "Promise",
        "record",
    };

    for (wrappers) |wrapper| {
        // Check exact match
        if (std.mem.eql(u8, type_name, wrapper)) {
            return true;
        }
        // Check if type name starts with wrapper followed by '<' (parameterized type)
        if (type_name.len > wrapper.len and
            std.mem.startsWith(u8, type_name, wrapper) and
            type_name[wrapper.len] == '<')
        {
            return true;
        }
    }

    return false;
}

/// Clean a type name by removing nullable suffix and other decorators
/// For example: "Node?" -> "Node", "EventTarget?" -> "EventTarget"
fn cleanTypeName(type_name: []const u8) []const u8 {
    // Remove trailing '?' if present
    if (type_name.len > 0 and type_name[type_name.len - 1] == '?') {
        return type_name[0 .. type_name.len - 1];
    }
    return type_name;
}

/// Extract inner type from parameterized type string
/// For example: "FrozenArray<BluetoothLEScanFilter>" -> "BluetoothLEScanFilter"
///              "Promise<Response>" -> "Response"
///              "record<DOMString, DOMString>" -> null (multiple type parameters)
/// Returns null if not a parameterized type or if parsing fails
fn extractInnerType(type_name: []const u8) ?[]const u8 {
    // Find opening angle bracket
    const open_pos = std.mem.indexOfScalar(u8, type_name, '<') orelse return null;

    // Find closing angle bracket
    const close_pos = std.mem.lastIndexOfScalar(u8, type_name, '>') orelse return null;

    // Make sure brackets are in correct order
    if (close_pos <= open_pos + 1) return null;

    // Extract the content between brackets
    const inner = type_name[open_pos + 1 .. close_pos];

    // Trim whitespace
    var start: usize = 0;
    var end: usize = inner.len;

    while (start < end and (inner[start] == ' ' or inner[start] == '\t')) {
        start += 1;
    }

    while (end > start and (inner[end - 1] == ' ' or inner[end - 1] == '\t')) {
        end -= 1;
    }

    if (end <= start) return null;

    const trimmed = inner[start..end];

    // Skip if it contains a comma (multiple type parameters like record<K,V>)
    // We'd need more sophisticated parsing for those
    if (std.mem.indexOfScalar(u8, trimmed, ',')) |_| {
        return null;
    }

    return trimmed;
}

// Unit tests
const testing = std.testing;

test "collectInterfaceReferences includes base type" {
    const allocator = testing.allocator;

    const interface: types.Interface = .{
        .name = "Node",
        .inheritance = "EventTarget",
    };

    const refs = try collectInterfaceReferences(allocator, interface);
    defer {
        for (refs) |ref| allocator.free(ref);
        allocator.free(refs);
    }

    try testing.expectEqual(@as(usize, 1), refs.len);
    try testing.expectEqualStrings("EventTarget", refs[0]);
}

test "collectInterfaceReferences includes mixins" {
    const allocator = testing.allocator;

    const includes = [_][]const u8{ "ParentNode", "ChildNode" };
    const interface: types.Interface = .{
        .name = "Element",
        .includes = @constCast(&includes),
    };

    const refs = try collectInterfaceReferences(allocator, interface);
    defer {
        for (refs) |ref| allocator.free(ref);
        allocator.free(refs);
    }

    try testing.expectEqual(@as(usize, 2), refs.len);
    // Order not guaranteed, so check both are present
    var found_parent = false;
    var found_child = false;
    for (refs) |ref| {
        if (std.mem.eql(u8, ref, "ParentNode")) found_parent = true;
        if (std.mem.eql(u8, ref, "ChildNode")) found_child = true;
    }
    try testing.expect(found_parent);
    try testing.expect(found_child);
}

test "collectInterfaceReferences includes attribute types" {
    const allocator = testing.allocator;

    const members = [_]types.Member{
        .{
            .type = .attribute,
            .attribute = .{
                .name = "ownerDocument",
                .idlType = .{ .type = "Document" },
            },
        },
    };

    const interface: types.Interface = .{
        .name = "Node",
        .members = @constCast(&members),
    };

    const refs = try collectInterfaceReferences(allocator, interface);
    defer {
        for (refs) |ref| allocator.free(ref);
        allocator.free(refs);
    }

    try testing.expectEqual(@as(usize, 1), refs.len);
    try testing.expectEqualStrings("Document", refs[0]);
}

test "collectInterfaceReferences includes operation return types" {
    const allocator = testing.allocator;

    const members = [_]types.Member{
        .{
            .type = .operation,
            .operation = .{
                .name = "cloneNode",
                .idlType = .{ .type = "Node" },
            },
        },
    };

    const interface: types.Interface = .{
        .name = "Node",
        .members = @constCast(&members),
    };

    const refs = try collectInterfaceReferences(allocator, interface);
    defer {
        for (refs) |ref| allocator.free(ref);
        allocator.free(refs);
    }

    try testing.expectEqual(@as(usize, 1), refs.len);
    try testing.expectEqualStrings("Node", refs[0]);
}

test "collectInterfaceReferences includes operation parameter types" {
    const allocator = testing.allocator;

    const args: []const types.Argument = &[_]types.Argument{
        .{
            .name = "node",
            .idlType = .{ .type = "Node" },
        },
    };

    const members = [_]types.Member{
        .{
            .type = .operation,
            .operation = .{
                .name = "appendChild",
                .idlType = .{ .type = "Node" },
                .arguments = @constCast(args),
            },
        },
    };

    const interface: types.Interface = .{
        .name = "Node",
        .members = @constCast(&members),
    };

    const refs = try collectInterfaceReferences(allocator, interface);
    defer {
        for (refs) |ref| allocator.free(ref);
        allocator.free(refs);
    }

    try testing.expectEqual(@as(usize, 1), refs.len);
    try testing.expectEqualStrings("Node", refs[0]);
}

test "collectInterfaceReferences excludes primitives" {
    const allocator = testing.allocator;

    const members = [_]types.Member{
        .{
            .type = .attribute,
            .attribute = .{
                .name = "nodeType",
                .idlType = .{ .type = "unsigned short" },
            },
        },
    };

    const interface: types.Interface = .{
        .name = "Node",
        .members = @constCast(&members),
    };

    const refs = try collectInterfaceReferences(allocator, interface);
    defer {
        for (refs) |ref| allocator.free(ref);
        allocator.free(refs);
    }

    try testing.expectEqual(@as(usize, 0), refs.len);
}

test "collectInterfaceReferences deduplicates references" {
    const allocator = testing.allocator;

    const members = [_]types.Member{
        .{
            .type = .attribute,
            .attribute = .{
                .name = "parentNode",
                .idlType = .{ .type = "Node" },
            },
        },
        .{
            .type = .attribute,
            .attribute = .{
                .name = "firstChild",
                .idlType = .{ .type = "Node" },
            },
        },
    };

    const interface: types.Interface = .{
        .name = "Node",
        .members = @constCast(&members),
    };

    const refs = try collectInterfaceReferences(allocator, interface);
    defer {
        for (refs) |ref| allocator.free(ref);
        allocator.free(refs);
    }

    // Should only have one "Node" reference despite two attributes
    try testing.expectEqual(@as(usize, 1), refs.len);
    try testing.expectEqualStrings("Node", refs[0]);
}

test "isPrimitiveType recognizes primitives" {
    try testing.expect(isPrimitiveType("void"));
    try testing.expect(isPrimitiveType("undefined"));
    try testing.expect(isPrimitiveType("boolean"));
    try testing.expect(isPrimitiveType("unsigned short"));
    try testing.expect(!isPrimitiveType("DOMString")); // DOMString is a typedef, not a primitive
    try testing.expect(!isPrimitiveType("Node"));
    try testing.expect(!isPrimitiveType("Document"));
}

test "isGenericWrapperType recognizes wrapper types" {
    try testing.expect(isGenericWrapperType("sequence"));
    try testing.expect(isGenericWrapperType("FrozenArray"));
    try testing.expect(isGenericWrapperType("ObservableArray"));
    try testing.expect(isGenericWrapperType("Promise"));
    try testing.expect(isGenericWrapperType("record"));
    try testing.expect(!isGenericWrapperType("Node"));
    try testing.expect(!isGenericWrapperType("Document"));

    // Test parameterized types (with angle brackets)
    try testing.expect(isGenericWrapperType("FrozenArray<ScreenDetailed>"));
    try testing.expect(isGenericWrapperType("Promise<Response>"));
    try testing.expect(isGenericWrapperType("ObservableArray<Node>"));
    try testing.expect(isGenericWrapperType("sequence<DOMString>"));

    // Test that similar names don't match
    try testing.expect(!isGenericWrapperType("FrozenArrayLike"));
    try testing.expect(!isGenericWrapperType("MyPromise"));
}

test "cleanTypeName removes nullable suffix" {
    try testing.expectEqualStrings("Node", cleanTypeName("Node?"));
    try testing.expectEqualStrings("EventTarget", cleanTypeName("EventTarget?"));
    try testing.expectEqualStrings("Document", cleanTypeName("Document"));
    try testing.expectEqualStrings("", cleanTypeName("?"));
}

test "collectInterfaceReferences excludes undefined" {
    const allocator = testing.allocator;

    const members = [_]types.Member{
        .{
            .type = .operation,
            .operation = .{
                .name = "preventDefault",
                .idlType = .{ .type = "undefined" }, // Should be excluded
            },
        },
    };

    const interface: types.Interface = .{
        .name = "Event",
        .members = @constCast(&members),
    };

    const refs = try collectInterfaceReferences(allocator, interface);
    defer {
        for (refs) |ref| allocator.free(ref);
        allocator.free(refs);
    }

    // Should have no references (undefined is a primitive)
    try testing.expectEqual(@as(usize, 0), refs.len);
}

test "collectInterfaceReferences excludes sequence wrapper" {
    const allocator = testing.allocator;

    const inner_type = types.IDLType{ .type = "Node" };
    const members = [_]types.Member{
        .{
            .type = .operation,
            .operation = .{
                .name = "getNodes",
                .idlType = .{
                    .type = "sequence",
                    .sequence = @constCast(&inner_type),
                },
            },
        },
    };

    const interface: types.Interface = .{
        .name = "Test",
        .members = @constCast(&members),
    };

    const refs = try collectInterfaceReferences(allocator, interface);
    defer {
        for (refs) |ref| allocator.free(ref);
        allocator.free(refs);
    }

    // Should only have "Node", not "sequence"
    try testing.expectEqual(@as(usize, 1), refs.len);
    try testing.expectEqualStrings("Node", refs[0]);
}

test "collectInterfaceReferences cleans nullable types" {
    const allocator = testing.allocator;

    const members = [_]types.Member{
        .{
            .type = .attribute,
            .attribute = .{
                .name = "parentNode",
                .idlType = .{ .type = "Node?" }, // Nullable type
            },
        },
    };

    const interface: types.Interface = .{
        .name = "Node",
        .members = @constCast(&members),
    };

    const refs = try collectInterfaceReferences(allocator, interface);
    defer {
        for (refs) |ref| allocator.free(ref);
        allocator.free(refs);
    }

    // Should have "Node" without the "?" suffix
    try testing.expectEqual(@as(usize, 1), refs.len);
    try testing.expectEqualStrings("Node", refs[0]);
}

/// Collect type references from a list of members
/// This is useful for collecting refs from resolved all_members including inherited ones
pub fn collectMemberReferences(
    allocator: std.mem.Allocator,
    members: []const types.Member,
) ![][]const u8 {
    var refs = std.StringHashMap(void).init(allocator);
    defer refs.deinit();

    // Add types from members
    for (members) |member| {
        switch (member.type) {
            .attribute => if (member.attribute) |attr| {
                try collectTypeReferences(&refs, attr.idlType);
            },
            .operation => if (member.operation) |op| {
                try collectTypeReferences(&refs, op.idlType);
                for (op.arguments) |arg| {
                    try collectTypeReferences(&refs, arg.idlType);
                }
            },
            .constructor => if (member.constructor) |ctor| {
                for (ctor.arguments) |arg| {
                    try collectTypeReferences(&refs, arg.idlType);
                }
            },
            .constant => if (member.constant) |const_val| {
                try collectTypeReferences(&refs, const_val.idlType);
            },
            .iterable => if (member.iterable) |iter| {
                try collectTypeReferences(&refs, iter.keyType);
                if (iter.valueType) |vtype| {
                    try collectTypeReferences(&refs, vtype);
                }
            },
            .async_iterable => if (member.async_iterable) |async_iter| {
                try collectTypeReferences(&refs, async_iter.keyType);
                if (async_iter.valueType) |vtype| {
                    try collectTypeReferences(&refs, vtype);
                }
                for (async_iter.arguments) |arg| {
                    try collectTypeReferences(&refs, arg.idlType);
                }
            },
        }
    }

    // Convert to slice
    var result = std.ArrayList([]const u8).empty;
    errdefer {
        for (result.items) |item| allocator.free(item);
        result.deinit(allocator);
    }

    var iter = refs.keyIterator();
    while (iter.next()) |key| {
        const name = try allocator.dupe(u8, key.*);
        try result.append(allocator, name);
    }

    return result.toOwnedSlice(allocator);
}
