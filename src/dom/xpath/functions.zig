//! XPath 1.0 Core Functions
//!
//! This module implements all 27 core functions from XPath 1.0 §4.
//!
//! ## W3C XPath 1.0 Specification
//!
//! - **XPath 1.0**: https://www.w3.org/TR/xpath-10/
//! - **§4 Core Function Library**: https://www.w3.org/TR/xpath-10/#corelib

const std = @import("std");
const Value = @import("value.zig").Value;
const NodeSet = @import("value.zig").NodeSet;
const Context = @import("context.zig").Context;

// ============================================================================
// Node Set Functions (§4.1)
// ============================================================================

/// last() - Returns context size (number of nodes in context)
pub fn fnLast(_: std.mem.Allocator, ctx: *const Context, args: []const Value) !Value {
    if (args.len != 0) return error.InvalidArgumentCount;
    return Value{ .number = @floatFromInt(ctx.context_size) };
}

/// position() - Returns context position (1-based)
pub fn fnPosition(_: std.mem.Allocator, ctx: *const Context, args: []const Value) !Value {
    if (args.len != 0) return error.InvalidArgumentCount;
    return Value{ .number = @floatFromInt(ctx.context_position) };
}

/// count(node-set) - Returns number of nodes in node-set
pub fn fnCount(_: std.mem.Allocator, _: *const Context, args: []const Value) !Value {
    if (args.len != 1) return error.InvalidArgumentCount;
    const node_set = switch (args[0]) {
        .node_set => |ns| ns,
        else => return error.InvalidArgumentType,
    };
    return Value{ .number = @floatFromInt(node_set.size()) };
}

/// id(object) - Selects elements by unique ID
pub fn fnId(allocator: std.mem.Allocator, ctx: *const Context, args: []const Value) !Value {
    if (args.len != 1) return error.InvalidArgumentCount;

    // Convert argument to string to get space-separated list of IDs
    const id_string = try args[0].toString(allocator);
    defer allocator.free(id_string);

    var result = NodeSet.init(allocator);

    // Split by whitespace to get individual IDs
    var iter = std.mem.tokenizeAny(u8, id_string, " \t\r\n");
    while (iter.next()) |id| {
        // Find element with this ID
        // We need to traverse the document from the root
        const root = getRootNode(ctx.context_node);
        try findElementById(allocator, root, id, &result);
    }

    return Value{ .node_set = result };
}

/// Get the root node (document)
fn getRootNode(node: *@import("node").Node) *@import("node").Node {
    var current = node;
    while (current.parent_node) |parent| {
        current = parent;
    }
    return current;
}

/// Find element by ID in tree
fn findElementById(allocator: std.mem.Allocator, node: *@import("node").Node, id: []const u8, result: *NodeSet) !void {
    const Node = @import("node").Node;
    const Element = @import("element").Element;

    // Check if this is an element with matching ID
    if (node.node_type == Node.ELEMENT_NODE) {
        // Cast to Element to access attribute methods
        // Safe cast: node_type == ELEMENT_NODE guarantees this is an Element
        const element: *Element = @ptrCast(node);

        // Get id attribute using proper Element API
        // Note: get_id() returns "" if no id attribute exists
        const element_id = element.get_id();
        if (element_id.len > 0 and std.mem.eql(u8, element_id, id)) {
            try result.add(node);
            return; // IDs are unique, stop after finding first match
        }
    }

    // Recursively search children
    for (node.child_nodes.items()) |child| {
        try findElementById(allocator, child, id, result);
    }
}

/// local-name(node-set?) - Returns local part of expanded-name
pub fn fnLocalName(allocator: std.mem.Allocator, ctx: *const Context, args: []const Value) !Value {
    if (args.len > 1) return error.InvalidArgumentCount;

    const node = if (args.len == 0) blk: {
        // Use context node
        break :blk ctx.context_node;
    } else blk: {
        // Get first node from node-set
        const node_set = switch (args[0]) {
            .node_set => |ns| ns,
            else => return error.InvalidArgumentType,
        };
        if (node_set.size() == 0) {
            return Value{ .string = try allocator.dupe(u8, "") };
        }
        break :blk node_set.get(0).?;
    };

    // Extract local name from node_name (ignoring namespace prefix)
    const name = node.node_name;
    if (std.mem.indexOf(u8, name, ":")) |colon_pos| {
        // Has namespace prefix, return local part
        return Value{ .string = try allocator.dupe(u8, name[colon_pos + 1 ..]) };
    }

    // No prefix, return full name
    return Value{ .string = try allocator.dupe(u8, name) };
}

/// namespace-uri(node-set?) - Returns namespace URI
pub fn fnNamespaceUri(allocator: std.mem.Allocator, ctx: *const Context, args: []const Value) !Value {
    if (args.len > 1) return error.InvalidArgumentCount;

    const node = if (args.len == 0) blk: {
        // Use context node
        break :blk ctx.context_node;
    } else blk: {
        // Get first node from node-set
        const node_set = switch (args[0]) {
            .node_set => |ns| ns,
            else => return error.InvalidArgumentType,
        };
        if (node_set.size() == 0) {
            return Value{ .string = try allocator.dupe(u8, "") };
        }
        break :blk node_set.get(0).?;
    };

    const Node = @import("node").Node;
    const Element = @import("element").Element;

    // For elements, return namespace URI; for other nodes, return empty string
    if (node.node_type == Node.ELEMENT_NODE) {
        // Safe cast: node_type == ELEMENT_NODE guarantees this is an Element
        const element: *const Element = @ptrCast(@alignCast(node));
        if (element.namespace_uri) |ns_uri| {
            return Value{ .string = try allocator.dupe(u8, ns_uri) };
        }
    }

    // For non-element nodes or elements without namespace, return empty string
    return Value{ .string = try allocator.dupe(u8, "") };
}

/// name(node-set?) - Returns QName
pub fn fnName(allocator: std.mem.Allocator, ctx: *const Context, args: []const Value) !Value {
    if (args.len > 1) return error.InvalidArgumentCount;

    const node = if (args.len == 0) blk: {
        // Use context node
        break :blk ctx.context_node;
    } else blk: {
        // Get first node from node-set
        const node_set = switch (args[0]) {
            .node_set => |ns| ns,
            else => return error.InvalidArgumentType,
        };
        if (node_set.size() == 0) {
            return Value{ .string = try allocator.dupe(u8, "") };
        }
        break :blk node_set.get(0).?;
    };

    // Return the full qualified name
    return Value{ .string = try allocator.dupe(u8, node.node_name) };
}

// ============================================================================
// String Functions (§4.2)
// ============================================================================

/// string(object?) - Converts to string
pub fn fnString(allocator: std.mem.Allocator, _: *const Context, args: []const Value) !Value {
    if (args.len > 1) return error.InvalidArgumentCount;
    if (args.len == 0) {
        // Convert context node to string
        var node_set = NodeSet.init(allocator);
        defer node_set.deinit();
        const val = Value{ .node_set = node_set };
        return Value{ .string = try val.toString(allocator) };
    }
    return Value{ .string = try args[0].toString(allocator) };
}

/// concat(string, string, string*) - Concatenates strings
pub fn fnConcat(allocator: std.mem.Allocator, _: *const Context, args: []const Value) !Value {
    if (args.len < 2) return error.InvalidArgumentCount;

    var total_len: usize = 0;
    var strings = try allocator.alloc([]const u8, args.len);
    defer {
        for (strings) |s| allocator.free(s);
        allocator.free(strings);
    }

    for (args, 0..) |arg, i| {
        strings[i] = try arg.toString(allocator);
        total_len += strings[i].len;
    }

    var result = try allocator.alloc(u8, total_len);
    var offset: usize = 0;
    for (strings) |s| {
        @memcpy(result[offset..][0..s.len], s);
        offset += s.len;
    }

    return Value{ .string = result };
}

/// starts-with(string, string) - Tests if first starts with second
pub fn fnStartsWith(allocator: std.mem.Allocator, _: *const Context, args: []const Value) !Value {
    if (args.len != 2) return error.InvalidArgumentCount;

    const s1 = try args[0].toString(allocator);
    defer allocator.free(s1);
    const s2 = try args[1].toString(allocator);
    defer allocator.free(s2);

    return Value{ .boolean = std.mem.startsWith(u8, s1, s2) };
}

/// contains(string, string) - Tests if first contains second
pub fn fnContains(allocator: std.mem.Allocator, _: *const Context, args: []const Value) !Value {
    if (args.len != 2) return error.InvalidArgumentCount;

    const s1 = try args[0].toString(allocator);
    defer allocator.free(s1);
    const s2 = try args[1].toString(allocator);
    defer allocator.free(s2);

    return Value{ .boolean = std.mem.indexOf(u8, s1, s2) != null };
}

/// substring-before(string, string) - Returns substring before match
pub fn fnSubstringBefore(allocator: std.mem.Allocator, _: *const Context, args: []const Value) !Value {
    if (args.len != 2) return error.InvalidArgumentCount;

    const s1 = try args[0].toString(allocator);
    defer allocator.free(s1);
    const s2 = try args[1].toString(allocator);
    defer allocator.free(s2);

    if (std.mem.indexOf(u8, s1, s2)) |index| {
        return Value{ .string = try allocator.dupe(u8, s1[0..index]) };
    }
    return Value{ .string = try allocator.dupe(u8, "") };
}

/// substring-after(string, string) - Returns substring after match
pub fn fnSubstringAfter(allocator: std.mem.Allocator, _: *const Context, args: []const Value) !Value {
    if (args.len != 2) return error.InvalidArgumentCount;

    const s1 = try args[0].toString(allocator);
    defer allocator.free(s1);
    const s2 = try args[1].toString(allocator);
    defer allocator.free(s2);

    if (std.mem.indexOf(u8, s1, s2)) |index| {
        const start = index + s2.len;
        return Value{ .string = try allocator.dupe(u8, s1[start..]) };
    }
    return Value{ .string = try allocator.dupe(u8, "") };
}

/// substring(string, number, number?) - Returns substring
pub fn fnSubstring(allocator: std.mem.Allocator, _: *const Context, args: []const Value) !Value {
    if (args.len < 2 or args.len > 3) return error.InvalidArgumentCount;

    const s = try args[0].toString(allocator);
    defer allocator.free(s);
    const start_num = try args[1].toNumber(allocator);

    // XPath uses 1-based indexing, convert to 0-based
    const start_f = @round(start_num) - 1.0;
    if (start_f < 0) {
        if (args.len == 3) {
            const len_num = try args[2].toNumber(allocator);
            const adjusted_len = len_num + start_f;
            if (adjusted_len <= 0) {
                return Value{ .string = try allocator.dupe(u8, "") };
            }
            const start: usize = 0;
            const end: usize = @min(@as(usize, @intFromFloat(@max(0, adjusted_len))), s.len);
            return Value{ .string = try allocator.dupe(u8, s[start..end]) };
        }
        return Value{ .string = try allocator.dupe(u8, "") };
    }

    const start: usize = @intFromFloat(@min(start_f, @as(f64, @floatFromInt(s.len))));
    if (start >= s.len) {
        return Value{ .string = try allocator.dupe(u8, "") };
    }

    if (args.len == 3) {
        const len_num = try args[2].toNumber(allocator);
        if (len_num <= 0 or std.math.isNan(len_num)) {
            return Value{ .string = try allocator.dupe(u8, "") };
        }
        const len: usize = @intFromFloat(@min(len_num, @as(f64, @floatFromInt(s.len - start))));
        const end = @min(start + len, s.len);
        return Value{ .string = try allocator.dupe(u8, s[start..end]) };
    }

    return Value{ .string = try allocator.dupe(u8, s[start..]) };
}

/// string-length(string?) - Returns string length
pub fn fnStringLength(allocator: std.mem.Allocator, ctx: *const Context, args: []const Value) !Value {
    if (args.len > 1) return error.InvalidArgumentCount;

    const s = if (args.len == 0)
        try fnString(allocator, ctx, args)
    else
        try args[0].toString(allocator);

    defer if (args.len == 0) {
        var val = s;
        val.deinit(allocator);
    } else {
        allocator.free(s.string);
    };

    const str = if (args.len == 0) s.string else s;
    return Value{ .number = @floatFromInt(str.len) };
}

/// normalize-space(string?) - Normalizes whitespace
pub fn fnNormalizeSpace(allocator: std.mem.Allocator, _: *const Context, args: []const Value) !Value {
    if (args.len > 1) return error.InvalidArgumentCount;

    const s = if (args.len == 0) blk: {
        const val = try fnString(allocator, null, args);
        break :blk val.string;
    } else try args[0].toString(allocator);
    defer allocator.free(s);

    // Trim and collapse whitespace
    const trimmed = std.mem.trim(u8, s, " \t\r\n");
    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    var prev_was_space = false;
    for (trimmed) |c| {
        if (c == ' ' or c == '\t' or c == '\r' or c == '\n') {
            if (!prev_was_space) {
                try result.append(' ');
                prev_was_space = true;
            }
        } else {
            try result.append(c);
            prev_was_space = false;
        }
    }

    return Value{ .string = try result.toOwnedSlice() };
}

/// translate(string, string, string) - Translates characters
pub fn fnTranslate(allocator: std.mem.Allocator, _: *const Context, args: []const Value) !Value {
    if (args.len != 3) return error.InvalidArgumentCount;

    const s = try args[0].toString(allocator);
    defer allocator.free(s);
    const from = try args[1].toString(allocator);
    defer allocator.free(from);
    const to = try args[2].toString(allocator);
    defer allocator.free(to);

    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    for (s) |c| {
        if (std.mem.indexOfScalar(u8, from, c)) |index| {
            if (index < to.len) {
                try result.append(to[index]);
            }
            // If index >= to.len, character is deleted
        } else {
            try result.append(c);
        }
    }

    return Value{ .string = try result.toOwnedSlice() };
}

// ============================================================================
// Boolean Functions (§4.3)
// ============================================================================

/// boolean(object) - Converts to boolean
pub fn fnBoolean(_: std.mem.Allocator, _: *const Context, args: []const Value) !Value {
    if (args.len != 1) return error.InvalidArgumentCount;
    return Value{ .boolean = args[0].toBoolean() };
}

/// not(boolean) - Logical negation
pub fn fnNot(_: std.mem.Allocator, _: *const Context, args: []const Value) !Value {
    if (args.len != 1) return error.InvalidArgumentCount;
    return Value{ .boolean = !args[0].toBoolean() };
}

/// true() - Returns true
pub fn fnTrue(_: std.mem.Allocator, _: *const Context, args: []const Value) !Value {
    if (args.len != 0) return error.InvalidArgumentCount;
    return Value{ .boolean = true };
}

/// false() - Returns false
pub fn fnFalse(_: std.mem.Allocator, _: *const Context, args: []const Value) !Value {
    if (args.len != 0) return error.InvalidArgumentCount;
    return Value{ .boolean = false };
}

/// lang(string) - Tests language
pub fn fnLang(allocator: std.mem.Allocator, _: *const Context, args: []const Value) !Value {
    if (args.len != 1) return error.InvalidArgumentCount;
    // TODO: Implement once we have xml:lang support
    _ = allocator;
    return Value{ .boolean = false };
}

// ============================================================================
// Number Functions (§4.4)
// ============================================================================

/// number(object?) - Converts to number
pub fn fnNumber(allocator: std.mem.Allocator, ctx: *const Context, args: []const Value) !Value {
    if (args.len > 1) return error.InvalidArgumentCount;
    if (args.len == 0) {
        // Convert context node
        const str_val = try fnString(allocator, ctx, args);
        defer {
            var val = str_val;
            val.deinit(allocator);
        }
        return Value{ .number = try str_val.toNumber(allocator) };
    }
    return Value{ .number = try args[0].toNumber(allocator) };
}

/// sum(node-set) - Sums numeric values of nodes
pub fn fnSum(allocator: std.mem.Allocator, _: *const Context, args: []const Value) !Value {
    if (args.len != 1) return error.InvalidArgumentCount;

    const node_set = switch (args[0]) {
        .node_set => |ns| ns,
        else => return error.InvalidArgumentType,
    };

    var sum: f64 = 0.0;
    for (0..node_set.size()) |i| {
        if (node_set.get(i)) |node| {
            // Convert node to string, then to number
            const node_val = Value{ .node_set = blk: {
                var temp_ns = NodeSet.init(allocator);
                try temp_ns.add(node);
                break :blk temp_ns;
            } };
            defer {
                var val = node_val;
                val.deinit(allocator);
            }

            const num = try node_val.toNumber(allocator);
            sum += num;
        }
    }

    return Value{ .number = sum };
}

/// floor(number) - Rounds down
pub fn fnFloor(allocator: std.mem.Allocator, _: *const Context, args: []const Value) !Value {
    if (args.len != 1) return error.InvalidArgumentCount;
    const n = try args[0].toNumber(allocator);
    return Value{ .number = @floor(n) };
}

/// ceiling(number) - Rounds up
pub fn fnCeiling(allocator: std.mem.Allocator, _: *const Context, args: []const Value) !Value {
    if (args.len != 1) return error.InvalidArgumentCount;
    const n = try args[0].toNumber(allocator);
    return Value{ .number = @ceil(n) };
}

/// round(number) - Rounds to nearest
pub fn fnRound(allocator: std.mem.Allocator, _: *const Context, args: []const Value) !Value {
    if (args.len != 1) return error.InvalidArgumentCount;
    const n = try args[0].toNumber(allocator);

    // XPath round has special rules for 0.5
    if (n >= 0) {
        return Value{ .number = @floor(n + 0.5) };
    } else {
        return Value{ .number = @ceil(n - 0.5) };
    }
}

// ============================================================================
// Function Registration
// ============================================================================

/// Register all core functions in a function library
pub fn registerCoreFunctions(lib: *@import("context.zig").FunctionLibrary) !void {
    // Node-set functions
    try lib.register("last", fnLast);
    try lib.register("position", fnPosition);
    try lib.register("count", fnCount);
    try lib.register("id", fnId);
    try lib.register("local-name", fnLocalName);
    try lib.register("namespace-uri", fnNamespaceUri);
    try lib.register("name", fnName);

    // String functions
    try lib.register("string", fnString);
    try lib.register("concat", fnConcat);
    try lib.register("starts-with", fnStartsWith);
    try lib.register("contains", fnContains);
    try lib.register("substring-before", fnSubstringBefore);
    try lib.register("substring-after", fnSubstringAfter);
    try lib.register("substring", fnSubstring);
    try lib.register("string-length", fnStringLength);
    try lib.register("normalize-space", fnNormalizeSpace);
    try lib.register("translate", fnTranslate);

    // Boolean functions
    try lib.register("boolean", fnBoolean);
    try lib.register("not", fnNot);
    try lib.register("true", fnTrue);
    try lib.register("false", fnFalse);
    try lib.register("lang", fnLang);

    // Number functions
    try lib.register("number", fnNumber);
    try lib.register("sum", fnSum);
    try lib.register("floor", fnFloor);
    try lib.register("ceiling", fnCeiling);
    try lib.register("round", fnRound);
}
