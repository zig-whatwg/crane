//! WebIDL Code Generator
//!
//! This module provides the main code generation function that ties together
//! all the other codegen modules.

const std = @import("std");
const types = @import("types.zig");
const parser = @import("parser.zig");
const writer = @import("writer.zig");
const files = @import("files.zig");
const refs = @import("refs.zig");
const ir_mod = @import("ir.zig");
const config_mod = @import("config.zig");
const overload = @import("overload.zig");
const CodegenConfig = config_mod.CodegenConfig;

/// Check if a name is a Zig reserved keyword
fn isZigKeyword(name: []const u8) bool {
    const keywords = [_][]const u8{
        "error",    "type",        "defer",   "return",   "var",      "const",     "fn",       "struct",
        "enum",     "union",       "opaque",  "try",      "catch",    "async",     "await",    "suspend",
        "resume",   "export",      "extern",  "pub",      "inline",   "comptime",  "callconv", "test",
        "and",      "or",          "switch",  "if",       "else",     "while",     "for",      "break",
        "continue", "unreachable", "anytype", "anyframe", "anyerror", "anyopaque", "align",
    };

    for (keywords) |keyword| {
        if (std.mem.eql(u8, name, keyword)) {
            return true;
        }
    }

    return false;
}

/// Check if a name conflicts with impl-specific reserved function names
/// These are functions we generate in every impl file (init, deinit, constructor)
fn isImplReservedName(name: []const u8) bool {
    const reserved = [_][]const u8{
        "init", // Instance initialization function
        "deinit", // Instance cleanup function
        "constructor", // Constructor implementation function
    };

    for (reserved) |r| {
        if (std.mem.eql(u8, name, r)) {
            return true;
        }
    }

    return false;
}

/// Write escaped parameter name for impl file generation
/// For impl-reserved names (init, deinit, constructor), append suffix instead of using @"identifier"
/// because Zig doesn't allow parameter names that shadow declarations even with escaping
fn writeEscapedImplParamName(w: anytype, name: []const u8) !void {
    if (isImplReservedName(name)) {
        // Rename reserved names: init → init_data, deinit → deinit_data, constructor → ctor_data
        try w.print("{s}_data", .{name});
    } else if (isZigKeyword(name)) {
        // Use @"identifier" for Zig keywords
        try w.print("@\"{s}\"", .{name});
    } else {
        // Normal names
        try w.print("{s}", .{name});
    }
}

/// Sanitize a name for use in function names (cannot use @"..." for functions)
/// Converts hyphens to underscores
fn sanitizeFunctionName(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    // Check if name contains hyphens
    if (std.mem.indexOfScalar(u8, name, '-')) |_| {
        // Replace hyphens with underscores
        var result = try allocator.alloc(u8, name.len);
        for (name, 0..) |c, i| {
            result[i] = if (c == '-') '_' else c;
        }
        return result;
    }
    // No hyphens, return as-is (no allocation needed)
    return name;
}

/// Deduplicate attributes by name (keep first occurrence)
fn deduplicateAttributes(allocator: std.mem.Allocator, attrs: *std.ArrayList(types.Attribute)) !void {
    if (attrs.items.len <= 1) return;

    var unique = std.ArrayList(types.Attribute).empty;
    defer unique.deinit(allocator);

    var seen = std.StringHashMap(void).init(allocator);
    defer seen.deinit();

    for (attrs.items) |attr| {
        const entry = try seen.getOrPut(attr.name);
        if (!entry.found_existing) {
            // First occurrence - keep it
            try unique.append(allocator, attr);
        }
        // Duplicate - skip it
    }

    // Replace original list with deduplicated one
    attrs.clearRetainingCapacity();
    try attrs.appendSlice(allocator, unique.items);
}

/// Deduplicate constants by name (keep first occurrence)
fn deduplicateConstants(allocator: std.mem.Allocator, constants: *std.ArrayList(types.Constant)) !void {
    if (constants.items.len <= 1) return;

    var unique = std.ArrayList(types.Constant).empty;
    defer unique.deinit(allocator);

    var seen = std.StringHashMap(void).init(allocator);
    defer seen.deinit();

    for (constants.items) |constant| {
        const entry = try seen.getOrPut(constant.name);
        if (!entry.found_existing) {
            // First occurrence - keep it
            try unique.append(allocator, constant);
        }
        // Duplicate - skip it
    }

    // Replace original list with deduplicated one
    constants.clearRetainingCapacity();
    try constants.appendSlice(allocator, unique.items);
}

/// Deduplicate constructors by argument count (simple deduplication)
/// For more complex overloading, argument types should also be compared
fn deduplicateConstructors(allocator: std.mem.Allocator, constructors: *std.ArrayList(types.Constructor)) !void {
    if (constructors.items.len <= 1) return;

    var unique = std.ArrayList(types.Constructor).empty;
    defer unique.deinit(allocator);

    var seen = std.AutoHashMap(usize, void).init(allocator);
    defer seen.deinit();

    for (constructors.items) |ctor| {
        const arg_count = ctor.arguments.len;
        const entry = try seen.getOrPut(arg_count);
        if (!entry.found_existing) {
            // First occurrence with this argument count - keep it
            try unique.append(allocator, ctor);
        }
        // Duplicate signature - skip it
    }

    // Replace original list with deduplicated one
    constructors.clearRetainingCapacity();
    try constructors.appendSlice(allocator, unique.items);
}

/// Deduplicate operations by name (keep first occurrence)
fn deduplicateOperations(allocator: std.mem.Allocator, ops: *std.ArrayList(types.Operation)) !void {
    if (ops.items.len <= 1) return;

    var unique = std.ArrayList(types.Operation).empty;
    defer unique.deinit(allocator);

    var seen = std.StringHashMap(void).init(allocator);
    defer seen.deinit();

    for (ops.items) |op| {
        const op_name = op.name orelse continue;
        const entry = try seen.getOrPut(op_name);
        if (!entry.found_existing) {
            // First occurrence - keep it
            try unique.append(allocator, op);
        }
        // Duplicate - skip it
    }

    // Replace original list with deduplicated one
    ops.clearRetainingCapacity();
    try ops.appendSlice(allocator, unique.items);
}

/// Generate root.zig file that exports all interfaces
pub fn generateInterfacesRoot(
    allocator: std.mem.Allocator,
    interfaces_path: []const u8,
    interface_names: []const []const u8,
) !void {
    const root_path = try std.fs.path.join(allocator, &.{ interfaces_path, "root.zig" });
    defer allocator.free(root_path);

    const root_file = try std.fs.cwd().createFile(root_path, .{});
    defer root_file.close();

    var buffer: [4096]u8 = undefined;
    var file_writer = root_file.writer(&buffer);
    const w = &file_writer.interface;

    // Write header
    try w.writeAll("//! Auto-generated root file for all WebIDL interfaces\n");
    try w.writeAll("//!\n");
    try w.writeAll("//! This file is AUTO-GENERATED. Do not edit manually.\n");
    try w.writeAll("\n");

    // Sort interface names for deterministic output
    const sorted_names = try allocator.dupe([]const u8, interface_names);
    defer allocator.free(sorted_names);
    std.mem.sort([]const u8, sorted_names, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lessThan);

    // Export all interfaces
    for (sorted_names) |name| {
        try w.print("pub const {s} = @import(\"{s}.zig\").{s};\n", .{ name, name, name });
    }

    try w.flush();
}

/// Generate root.zig file that exports all implementations
pub fn generateImplsRoot(
    allocator: std.mem.Allocator,
    impls_path: []const u8,
    interface_names: []const []const u8,
    namespace_names: []const []const u8,
) !void {
    const root_path = try std.fs.path.join(allocator, &.{ impls_path, "root.zig" });
    defer allocator.free(root_path);

    const root_file = try std.fs.cwd().createFile(root_path, .{});
    defer root_file.close();

    var buffer: [4096]u8 = undefined;
    var file_writer = root_file.writer(&buffer);
    const w = &file_writer.interface;

    // Write header
    try w.writeAll("//! Auto-generated root file for all WebIDL implementations\n");
    try w.writeAll("//!\n");
    try w.writeAll("//! This file is AUTO-GENERATED and will be overwritten.\n");
    try w.writeAll("\n");

    // Sort interface names for deterministic output
    const sorted_names = try allocator.dupe([]const u8, interface_names);
    defer allocator.free(sorted_names);
    std.mem.sort([]const u8, sorted_names, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lessThan);

    // Export all interface implementations
    for (sorted_names) |name| {
        // Check if implementation file exists
        const impl_filename = try std.fmt.allocPrint(allocator, "{s}.zig", .{name});
        defer allocator.free(impl_filename);

        const impl_path = try std.fs.path.join(allocator, &.{ impls_path, impl_filename });
        defer allocator.free(impl_path);

        std.fs.cwd().access(impl_path, .{}) catch {
            // File doesn't exist - export a stub that will fail at compile time
            try w.print("pub const {s} = @compileError(\"Implementation for {s} not found. Create {s}/{s}.zig\");\n", .{ name, name, impls_path, name });
            continue;
        };

        // File exists - import it as namespace (impl files don't have struct types)
        try w.print("pub const {s} = @import(\"{s}.zig\");\n", .{ name, name });
    }

    // Export all namespace implementations
    const sorted_ns_names = try allocator.dupe([]const u8, namespace_names);
    defer allocator.free(sorted_ns_names);
    std.mem.sort([]const u8, sorted_ns_names, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lessThan);

    for (sorted_ns_names) |name| {
        const impl_filename = try std.fmt.allocPrint(allocator, "{s}.zig", .{name});
        defer allocator.free(impl_filename);

        const impl_path = try std.fs.path.join(allocator, &.{ impls_path, impl_filename });
        defer allocator.free(impl_path);

        std.fs.cwd().access(impl_path, .{}) catch {
            // File doesn't exist - skip it
            continue;
        };

        // File exists - import it (namespaces use same naming as interfaces)
        try w.print("pub const {s} = @import(\"{s}.zig\");\n", .{ name, name });
    }

    try w.flush();
}

/// Generate root.zig file that exports all typedefs
pub fn generateTypedefsRoot(
    allocator: std.mem.Allocator,
    typedefs_path: []const u8,
    typedef_names: []const []const u8,
) !void {
    const root_path = try std.fs.path.join(allocator, &.{ typedefs_path, "root.zig" });
    defer allocator.free(root_path);

    const root_file = try std.fs.cwd().createFile(root_path, .{});
    defer root_file.close();

    var buffer: [4096]u8 = undefined;
    var file_writer = root_file.writer(&buffer);
    const w = &file_writer.interface;

    try w.writeAll("//! Auto-generated\n");

    const sorted_names = try allocator.dupe([]const u8, typedef_names);
    defer allocator.free(sorted_names);
    std.mem.sort([]const u8, sorted_names, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lessThan);

    for (sorted_names) |name| {
        try w.print("pub const {s} = @import(\"{s}.zig\").{s};\n", .{ name, name, name });
    }

    try w.flush();
}

/// Generate root.zig file that exports all dictionaries
pub fn generateDictionariesRoot(
    allocator: std.mem.Allocator,
    dictionaries_path: []const u8,
    dictionary_names: []const []const u8,
) !void {
    const root_path = try std.fs.path.join(allocator, &.{ dictionaries_path, "root.zig" });
    defer allocator.free(root_path);

    const root_file = try std.fs.cwd().createFile(root_path, .{});
    defer root_file.close();

    var buffer: [4096]u8 = undefined;
    var file_writer = root_file.writer(&buffer);
    const w = &file_writer.interface;

    try w.writeAll("//! Auto-generated\n");

    const sorted_names = try allocator.dupe([]const u8, dictionary_names);
    defer allocator.free(sorted_names);
    std.mem.sort([]const u8, sorted_names, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lessThan);

    for (sorted_names) |name| {
        try w.print("pub const {s} = @import(\"{s}.zig\").{s};\n", .{ name, name, name });
    }

    try w.flush();
}

/// Generate root.zig file that exports all enums
pub fn generateEnumsRoot(
    allocator: std.mem.Allocator,
    enums_path: []const u8,
    enum_names: []const []const u8,
) !void {
    const root_path = try std.fs.path.join(allocator, &.{ enums_path, "root.zig" });
    defer allocator.free(root_path);

    const root_file = try std.fs.cwd().createFile(root_path, .{});
    defer root_file.close();

    var buffer: [4096]u8 = undefined;
    var file_writer = root_file.writer(&buffer);
    const w = &file_writer.interface;

    try w.writeAll("//! Auto-generated\n");

    const sorted_names = try allocator.dupe([]const u8, enum_names);
    defer allocator.free(sorted_names);
    std.mem.sort([]const u8, sorted_names, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lessThan);

    for (sorted_names) |name| {
        try w.print("pub const {s} = @import(\"{s}.zig\").{s};\n", .{ name, name, name });
    }

    try w.flush();
}

/// Generate root.zig file that exports all callbacks
pub fn generateCallbacksRoot(
    allocator: std.mem.Allocator,
    callbacks_path: []const u8,
    callback_names: []const []const u8,
) !void {
    const root_path = try std.fs.path.join(allocator, &.{ callbacks_path, "root.zig" });
    defer allocator.free(root_path);

    const root_file = try std.fs.cwd().createFile(root_path, .{});
    defer root_file.close();

    var buffer: [4096]u8 = undefined;
    var file_writer = root_file.writer(&buffer);
    const w = &file_writer.interface;

    try w.writeAll("//! Auto-generated\n");

    const sorted_names = try allocator.dupe([]const u8, callback_names);
    defer allocator.free(sorted_names);
    std.mem.sort([]const u8, sorted_names, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lessThan);

    for (sorted_names) |name| {
        try w.print("pub const {s} = @import(\"{s}.zig\").{s};\n", .{ name, name, name });
    }

    try w.flush();
}

/// Generate root.zig file that exports all namespaces
pub fn generateNamespacesRoot(
    allocator: std.mem.Allocator,
    namespaces_path: []const u8,
    namespace_names: []const []const u8,
) !void {
    const root_path = try std.fs.path.join(allocator, &.{ namespaces_path, "root.zig" });
    defer allocator.free(root_path);

    const root_file = try std.fs.cwd().createFile(root_path, .{});
    defer root_file.close();

    var buffer: [4096]u8 = undefined;
    var file_writer = root_file.writer(&buffer);
    const w = &file_writer.interface;

    try w.writeAll("//! Auto-generated\n");

    const sorted_names = try allocator.dupe([]const u8, namespace_names);
    defer allocator.free(sorted_names);
    std.mem.sort([]const u8, sorted_names, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lessThan);

    for (sorted_names) |name| {
        try w.print("pub const {s} = @import(\"{s}.zig\").{s};\n", .{ name, name, name });
    }

    try w.flush();
}

/// Check if a typedef has a special hand-written implementation that should not be generated
/// These typedefs are in webidl/types/buffer_sources.zig with proper union types and methods
pub fn isSpecialTypedef(name: []const u8) bool {
    const special_typedefs = [_][]const u8{
        // Buffer source types with rich implementations in buffer_sources.zig
        "ArrayBufferView",
        "BufferSource",
        "AllowSharedBufferSource",
    };

    for (special_typedefs) |special| {
        if (std.mem.eql(u8, name, special)) {
            return true;
        }
    }
    return false;
}

/// Check if a union type is the (Node or DOMString) pattern used by DOM mutation methods
/// This pattern is used by ParentNode.prepend/append/replaceChildren and ChildNode.before/after/replaceWith
fn isNodeOrDOMStringUnion(union_types: []const types.IDLType) bool {
    if (union_types.len != 2) return false;

    var has_node = false;
    var has_string = false;

    for (union_types) |ut| {
        const t = ut.type;
        if (std.mem.eql(u8, t, "Node")) has_node = true;
        if (std.mem.eql(u8, t, "DOMString")) has_string = true;
        // Also handle TrustedScript variant used in some specs
        if (std.mem.eql(u8, t, "TrustedScript")) has_string = true;
    }

    return has_node and has_string;
}

/// Check if a union type is a (TrustedType or DOMString/USVString) pattern
/// These unions are used for Trusted Types API integration but since TrustedTypes
/// are not yet implemented, we treat them as plain DOMString/USVString.
///
/// Matches patterns like:
/// - (TrustedType or DOMString)
/// - (TrustedHTML or DOMString)
/// - (TrustedScript or DOMString)
/// - (TrustedScriptURL or USVString)
fn isTrustedTypeOrStringUnion(union_types: []const types.IDLType) bool {
    if (union_types.len != 2) return false;

    var has_trusted_type = false;
    var has_string = false;

    for (union_types) |ut| {
        const t = ut.type;
        // Check for TrustedTypes (not yet implemented, treat as string)
        if (std.mem.eql(u8, t, "TrustedType")) has_trusted_type = true;
        if (std.mem.eql(u8, t, "TrustedHTML")) has_trusted_type = true;
        if (std.mem.eql(u8, t, "TrustedScript")) has_trusted_type = true;
        if (std.mem.eql(u8, t, "TrustedScriptURL")) has_trusted_type = true;
        // Check for string types
        if (std.mem.eql(u8, t, "DOMString")) has_string = true;
        if (std.mem.eql(u8, t, "USVString")) has_string = true;
    }

    return has_trusted_type and has_string;
}

/// Write a parameter type with proper nullable and variadic handling
/// Handles: nullable types (T?), variadic (T...), and combinations
fn writeParamType(w: anytype, arg: types.Argument, type_registry: ?*const ir_mod.TypeRegistry) !void {
    // Handle optional parameters: optional T becomes webidl.Opt(T)
    // Must happen BEFORE variadic/nullable wrapping
    if (arg.optional) {
        try w.writeAll("webidl.Opt(");
    }

    // Handle variadic parameters: T... becomes []const T
    if (arg.variadic) {
        try w.writeAll("[]const ");
    }

    // Handle nullable parameters: T? becomes ?T (but not for variadic - slice handles null)
    if (arg.idlType.nullable and !arg.variadic) {
        try w.writeAll("?");
    }

    try writeTypeSimple(w, arg.idlType, type_registry);

    // Close optional wrapper
    if (arg.optional) {
        try w.writeAll(")");
    }
}

/// Helper to write a WebIDL type as Zig type string (simplified)
fn writeTypeSimple(w: anytype, webidl_type: types.IDLType, type_registry: ?*const ir_mod.TypeRegistry) !void {
    // Handle union types first
    if (webidl_type.unionTypes) |union_types| {
        if (isNodeOrDOMStringUnion(union_types)) {
            // Use the mixin's NodeOrString type for (Node or DOMString) pattern
            try w.writeAll("mixins.ParentNode.NodeOrString");
            return;
        }
        if (isTrustedTypeOrStringUnion(union_types)) {
            // TrustedTypes are not yet implemented - treat as DOMString
            // This handles (TrustedType or DOMString), (TrustedHTML or DOMString), etc.
            try w.writeAll("runtime.DOMString");
            return;
        }
        // Fallback for other union types - use anyopaque
        try w.writeAll("*const anyopaque");
        return;
    }

    var type_str = webidl_type.type;

    // Strip namespace prefix if present (e.g., "dom::DOMString" -> "DOMString")
    if (std.mem.indexOf(u8, type_str, "::")) |colon_pos| {
        type_str = type_str[colon_pos + 2 ..];
    }

    // Map common primitive types
    if (std.mem.eql(u8, type_str, "boolean")) {
        try w.writeAll("bool");
    } else if (std.mem.eql(u8, type_str, "byte")) {
        try w.writeAll("i8");
    } else if (std.mem.eql(u8, type_str, "octet")) {
        try w.writeAll("u8");
    } else if (std.mem.eql(u8, type_str, "short")) {
        try w.writeAll("i16");
    } else if (std.mem.eql(u8, type_str, "unsigned short")) {
        try w.writeAll("u16");
    } else if (std.mem.eql(u8, type_str, "long")) {
        try w.writeAll("i32");
    } else if (std.mem.eql(u8, type_str, "unsigned long")) {
        try w.writeAll("u32");
    } else if (std.mem.eql(u8, type_str, "long long")) {
        try w.writeAll("i64");
    } else if (std.mem.eql(u8, type_str, "unsigned long long")) {
        try w.writeAll("u64");
    } else if (std.mem.eql(u8, type_str, "float") or std.mem.eql(u8, type_str, "unrestricted float")) {
        try w.writeAll("f32");
    } else if (std.mem.eql(u8, type_str, "double") or std.mem.eql(u8, type_str, "unrestricted double")) {
        try w.writeAll("f64");
    } else if (std.mem.eql(u8, type_str, "DOMString")) {
        try w.writeAll("runtime.DOMString");
    } else if (std.mem.eql(u8, type_str, "USVString")) {
        try w.writeAll("runtime.USVString");
    } else if (std.mem.eql(u8, type_str, "ByteString")) {
        try w.writeAll("runtime.ByteString");
    } else if (std.mem.eql(u8, type_str, "undefined") or std.mem.eql(u8, type_str, "void")) {
        try w.writeAll("void");
    } else if (std.mem.eql(u8, type_str, "any") or std.mem.eql(u8, type_str, "object")) {
        // Use type-safe JSValue for 'any' and 'object' types
        // This replaces the unsafe *const anyopaque with a tagged union
        try w.writeAll("v8.JSValue");
    } else {
        // Check type registry if available
        if (type_registry) |reg| {
            if (reg.lookup(type_str)) |kind| {
                switch (kind) {
                    .interface => {
                        // For impl files, interface parameters should be *runtime.Instance
                        // so they can access the runtime object's internal state
                        try w.writeAll("*runtime.Instance");
                    },
                    .callback_interface => {
                        // Callback interfaces use engine-agnostic CallbackWrapper
                        try w.writeAll("?*runtime.CallbackWrapper");
                    },
                    .typedef => {
                        // Qualify with module
                        try w.print("typedefs.{s}", .{type_str});
                    },
                    .enum_type => {
                        // Qualify with module
                        try w.print("enums.{s}", .{type_str});
                    },
                    .dictionary => {
                        // Qualify with module
                        try w.print("dictionaries.{s}", .{type_str});
                    },
                    .callback => {
                        // Qualify with callbacks module
                        try w.print("callbacks.{s}", .{type_str});
                    },
                    .namespace, .primitive => {
                        // Shouldn't appear as attribute types, but handle gracefully
                        try w.writeAll("*const anyopaque");
                    },
                }
                return;
            }
        }

        // For unknown types (no registry or not found), use pointer to anyopaque
        // This allows passing interface references that aren't fully resolved yet
        try w.writeAll("*const anyopaque");
    }
}

/// Generate implementation stub file with full method stubs
/// NOTE: Always generates to impls_tmp/ directory (gitignored).
/// Developers must manually migrate stubs to impls/ to preserve custom code.
fn generateImplFile(
    allocator: std.mem.Allocator,
    interface: types.Interface,
    impls_path: []const u8,
    ir: ?*ir_mod.IR,
) !void {
    // Create impls_tmp directory
    try std.fs.cwd().makePath(impls_path);

    // Create implementation stub file
    const output_filename = try std.fmt.allocPrint(allocator, "{s}.zig", .{interface.name});
    defer allocator.free(output_filename);

    const output_path = try std.fs.path.join(allocator, &.{ impls_path, output_filename });
    defer allocator.free(output_path);

    // Always generate to impls_tmp/ (overwrite existing stubs)
    // Custom implementations live in impls/ and are never overwritten
    const output_file = try std.fs.cwd().createFile(output_path, .{});
    defer output_file.close();

    var buffer: [4096]u8 = undefined;
    var file_writer = output_file.writer(&buffer);
    const w = &file_writer.interface;

    // Get type registry for proper type mapping
    const type_reg = if (ir) |ir_ptr| &ir_ptr.type_registry else null;

    // Write header with strict DO NOT COMPILE notices for impls_tmp/ files
    // These warnings should be removed when copying to impls/
    try w.writeAll("//! ============================================================================\n");
    try w.writeAll("//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY\n");
    try w.writeAll("//! ============================================================================\n");
    try w.writeAll("//!\n");
    try w.print("//! Implementation stub for {s} interface\n", .{interface.name});
    try w.writeAll("//!\n");
    try w.writeAll("//! This file is AUTO-GENERATED into impls_tmp/ directory.\n");
    try w.writeAll("//! The impls_tmp/ directory is gitignored and NOT part of the build.\n");
    try w.writeAll("//!\n");
    try w.writeAll("//! TO USE THIS STUB:\n");
    try w.writeAll("//!   1. Copy this file to src/webidl/impls/\n");
    try w.writeAll("//!   2. Remove this header comment block\n");
    try w.writeAll("//!   3. Add your implementation logic\n");
    try w.writeAll("//!   4. The impls/ directory is the canonical location for implementations\n");
    try w.writeAll("//!\n");
    try w.writeAll("//! If updating an existing implementation:\n");
    try w.writeAll("//!   1. Diff this stub against the existing file in impls/\n");
    try w.writeAll("//!   2. Manually merge new signatures while preserving custom code\n");
    try w.writeAll("//!\n");
    try w.writeAll("//! ============================================================================\n");
    try w.writeAll("\n");

    // Write imports
    try w.writeAll("const std = @import(\"std\");\n");
    try w.writeAll("const runtime = @import(\"runtime\");\n");
    try w.writeAll("const webidl = @import(\"webidl\");\n");
    try w.writeAll("const v8 = @import(\"v8\");\n");
    try w.writeAll("const interfaces = @import(\"interfaces\");\n");
    try w.writeAll("const typedefs = @import(\"typedefs\");\n");
    try w.writeAll("const enums = @import(\"enums\");\n");
    try w.writeAll("const dictionaries = @import(\"dictionaries\");\n");
    try w.writeAll("const callbacks = @import(\"callbacks\");\n");
    try w.writeAll("const mixins = @import(\"mixins\");\n");
    try w.print("const {s} = interfaces.{s};\n\n", .{ interface.name, interface.name });

    // State type alias
    try w.print("pub const State = {s}.State;\n\n", .{interface.name});

    // Error set for unimplemented methods
    try w.writeAll("pub const ImplError = error{\n");
    try w.writeAll("    NotImplemented,\n");
    try w.writeAll("};\n\n");

    // Internal state struct (empty by default, implementations can add fields)
    try w.writeAll("/// Internal state for implementation-specific data\n");
    try w.writeAll("/// Implementations can replace this with a real struct containing:\n");
    try w.writeAll("/// - Private data not exposed via WebIDL attributes\n");
    try w.writeAll("/// - Cached computations, buffers, etc.\n");
    try w.writeAll("pub const InternalState = struct {};\n\n");

    // Init and deinit functions - delegate to runtime.Instance
    try w.writeAll("/// Initialize instance (creates the instance)\n");
    try w.writeAll("pub fn init(\n");
    try w.writeAll("    allocator: std.mem.Allocator,\n");
    try w.writeAll("    comptime StateType: type,\n");
    try w.writeAll("    vtable: *const runtime.VTable,\n");
    try w.writeAll("    ctx: runtime.Context,\n");
    try w.writeAll(") !*runtime.Instance {\n");
    try w.writeAll("    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);\n");
    try w.writeAll("    // TODO: Initialize your instance state here if needed\n");
    try w.writeAll("    return instance;\n");
    try w.writeAll("}\n\n");

    try w.writeAll("/// Deinitialize instance - clean up owned resources only\n");
    try w.writeAll("/// NOTE: Do NOT call runtime.Instance.deinit() here - the GC integration\n");
    try w.writeAll("/// layer (gc_integration.onObjectFreed) handles freeing the slab after\n");
    try w.writeAll("/// calling this deinit function. Calling it here causes double-free.\n");
    try w.writeAll("pub fn deinit(instance: *runtime.Instance) void {\n");
    try w.writeAll("    _ = instance;\n");
    try w.writeAll("    // TODO: Clean up your instance's owned resources here (strings, arrays, etc.)\n");
    try w.writeAll("}\n\n");

    // Collect ONLY own members (not inherited)
    // Impl files should only implement their interface's own operations
    // Inherited operations are implemented in parent impl files
    var all_attrs = std.ArrayList(types.Attribute).empty;
    defer all_attrs.deinit(allocator);

    var all_ops = std.ArrayList(types.Operation).empty;
    defer all_ops.deinit(allocator);

    // Only collect constructors from THIS interface (not inherited)
    var own_constructors = std.ArrayList(types.Constructor).empty;
    defer own_constructors.deinit(allocator);

    // Collect own members only (regardless of IR availability)
    for (interface.members) |member| {
        switch (member.type) {
            .attribute => if (member.attribute) |attr| try all_attrs.append(allocator, attr),
            .operation => if (member.operation) |op| try all_ops.append(allocator, op),
            .constructor => if (member.constructor) |ctor| try own_constructors.append(allocator, ctor),
            else => {},
        }
    }

    // Deduplicate attributes, operations, and constructors before generating impl stubs
    // This prevents duplicate function declarations from multiple partial interfaces
    const before_attrs = all_attrs.items.len;
    try deduplicateAttributes(allocator, &all_attrs);
    const after_attrs = all_attrs.items.len;

    const before_ops = all_ops.items.len;
    try deduplicateOperations(allocator, &all_ops);
    const after_ops = all_ops.items.len;

    try deduplicateConstructors(allocator, &own_constructors);

    // Deduplication done silently - debug output removed for performance
    _ = before_attrs;
    _ = after_attrs;
    _ = before_ops;
    _ = after_ops;

    // Generate call_constructor if interface has WebIDL constructor
    if (own_constructors.items.len > 0) {
        try w.writeAll("/// Constructor implementation\n");
        try w.writeAll("/// This is called when the interface is constructed from JavaScript\n");

        // If multiple constructors (overloaded), accept ConstructorArgs union
        if (own_constructors.items.len > 1) {
            try w.print("pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, args: interfaces.{s}.ConstructorArgs) !*runtime.Instance {{\n", .{interface.name});
            try w.writeAll("    // Create instance through init()\n");
            try w.print("    const instance = try init(allocator, State, &{s}.vtable, ctx);\n", .{interface.name});
            try w.writeAll("    errdefer deinit(instance);\n");
            try w.writeAll("\n");
            try w.writeAll("    _ = args;\n");
            try w.writeAll("    // TODO: Implement constructor logic for each overload\n");
            try w.writeAll("    // Use: switch (args) { .VariantName => |variant_args| { ... } }\n");
            try w.writeAll("\n");
            try w.writeAll("    return instance;\n");
            try w.writeAll("}\n\n");
        } else {
            // Single constructor - use direct parameters
            const ctor = own_constructors.items[0];
            try w.print("pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context", .{});
            for (ctor.arguments) |arg| {
                try w.writeAll(", ");
                try writeEscapedImplParamName(w, arg.name);
                try w.writeAll(": ");
                try writeParamType(w, arg, type_reg);
            }
            try w.writeAll(") !*runtime.Instance {\n");
            try w.writeAll("    // Create instance through init()\n");
            try w.print("    const instance = try init(allocator, State, &{s}.vtable, ctx);\n", .{interface.name});
            try w.writeAll("    errdefer deinit(instance);\n");
            try w.writeAll("\n");
            for (ctor.arguments) |arg| {
                try w.writeAll("    _ = ");
                try writeEscapedImplParamName(w, arg.name);
                try w.writeAll(";\n");
            }
            try w.writeAll("    // TODO: Implement constructor logic with parameters\n");
            try w.writeAll("\n");
            try w.writeAll("    return instance;\n");
            try w.writeAll("}\n\n");
        }
    }

    // Generate getter stubs
    for (all_attrs.items) |attr| {
        // Sanitize attribute name for function names (convert hyphens to underscores)
        const sanitized_name = try sanitizeFunctionName(allocator, attr.name);
        const name_was_sanitized = !std.mem.eql(u8, sanitized_name, attr.name);
        defer if (name_was_sanitized) allocator.free(sanitized_name);

        try w.print("/// Getter for {s}\n", .{attr.name});
        try w.print("pub fn get_{s}(instance: *runtime.Instance) anyerror!", .{sanitized_name});
        // For nullable types, return ?T instead of T
        if (attr.idlType.nullable) {
            try w.writeAll("?");
        }
        try writeTypeSimple(w, attr.idlType, type_reg);
        try w.writeAll(" {\n");
        try w.writeAll("    _ = instance;\n");
        // For nullable types, return null instead of error.NotImplemented
        if (attr.idlType.nullable) {
            try w.writeAll("    return null;\n");
        } else {
            try w.writeAll("    return error.NotImplemented;\n");
        }
        try w.writeAll("}\n\n");
    }

    // Generate setter stubs
    for (all_attrs.items) |attr| {
        if (!attr.readonly) {
            // Sanitize attribute name for function names (convert hyphens to underscores)
            const sanitized_name = try sanitizeFunctionName(allocator, attr.name);
            const name_was_sanitized = !std.mem.eql(u8, sanitized_name, attr.name);
            defer if (name_was_sanitized) allocator.free(sanitized_name);

            try w.print("/// Setter for {s}\n", .{attr.name});
            try w.print("pub fn set_{s}(instance: *runtime.Instance, value: ", .{sanitized_name});
            try writeTypeSimple(w, attr.idlType, type_reg);
            try w.writeAll(") anyerror!void {\n");
            try w.writeAll("    _ = instance;\n");
            try w.writeAll("    _ = value;\n");
            try w.writeAll("    return error.NotImplemented;\n");
            try w.writeAll("}\n\n");
        }
    }

    // Generate operation stubs using overload-aware logic
    // This must match the interface generation to ensure signatures are identical
    const overload_mod = @import("overload.zig");
    const overload_sets = try overload_mod.groupOperationsByName(allocator, all_ops.items);
    defer overload_mod.freeOverloadSets(allocator, overload_sets);

    for (overload_sets) |set| {
        if (set.isOverloaded()) {
            // Multiple overloads - generate ONE impl stub that accepts the Args union
            const first_op = set.operations[0];
            const op_name = first_op.name orelse "unnamed";
            const is_nullable_return = first_op.idlType.nullable;

            try w.print("/// Operation: {s} (overloaded - {d} variants)\n", .{ op_name, set.operations.len });
            try w.print("pub fn call_{s}(instance: *runtime.Instance, args: interfaces.{s}.", .{ op_name, interface.name });

            // Generate Args union type name: "StartArgs", "ItemArgs", etc.
            var capitalized_name = std.ArrayList(u8).empty;
            defer capitalized_name.deinit(allocator);
            try capitalized_name.append(allocator, std.ascii.toUpper(op_name[0]));
            try capitalized_name.appendSlice(allocator, op_name[1..]);
            try capitalized_name.appendSlice(allocator, "Args");

            try w.print("{s}) anyerror!", .{capitalized_name.items});
            // For nullable return types, return ?T instead of T
            if (is_nullable_return) {
                try w.writeAll("?");
            }
            try writeTypeSimple(w, first_op.idlType, type_reg);
            try w.writeAll(" {\n");
            try w.writeAll("    _ = instance;\n");
            try w.writeAll("    _ = args;\n");
            // For nullable types, return null instead of error.NotImplemented
            if (is_nullable_return) {
                try w.writeAll("    return null;\n");
            } else {
                try w.writeAll("    return error.NotImplemented;\n");
            }
            try w.writeAll("}\n\n");
        } else {
            // Single operation - generate normal function (same as before)
            const op = set.operations[0];
            const op_name = op.name orelse "unnamed";
            const is_nullable_return = op.idlType.nullable;

            try w.print("/// Operation: {s}\n", .{op_name});
            try w.print("pub fn call_{s}(instance: *runtime.Instance", .{op_name});
            for (op.arguments) |arg| {
                try w.writeAll(", ");
                try writeEscapedImplParamName(w, arg.name);
                try w.writeAll(": ");
                try writeParamType(w, arg, type_reg);
            }
            try w.writeAll(") anyerror!");
            // For nullable return types, return ?T instead of T
            if (is_nullable_return) {
                try w.writeAll("?");
            }
            try writeTypeSimple(w, op.idlType, type_reg);
            try w.writeAll(" {\n");
            try w.writeAll("    _ = instance;\n");
            for (op.arguments) |arg| {
                try w.writeAll("    _ = ");
                try writeEscapedImplParamName(w, arg.name);
                try w.writeAll(";\n");
            }
            // For nullable types, return null instead of error.NotImplemented
            if (is_nullable_return) {
                try w.writeAll("    return null;\n");
            } else {
                try w.writeAll("    return error.NotImplemented;\n");
            }
            try w.writeAll("}\n\n");
        }
    }

    // Add forEach stub for iterable interfaces
    var has_iterable = false;
    for (interface.members) |member| {
        if (member.type == .iterable) {
            has_iterable = true;
            break;
        }
    }

    if (has_iterable) {
        try w.writeAll("/// Operation: forEach\n");
        try w.writeAll("pub fn call_forEach(instance: *runtime.Instance, callback: *const anyopaque) anyerror!void {\n");
        try w.writeAll("    _ = instance;\n");
        try w.writeAll("    _ = callback;\n");
        try w.writeAll("    return error.NotImplemented;\n");
        try w.writeAll("}\n\n");
    }

    try w.flush();
}

/// Generate Zig code for a single WebIDL interface
///
/// Creates a .zig file in the output directory with the generated code.
pub fn generateInterface(
    allocator: std.mem.Allocator,
    interface: types.Interface,
    source_file: []const u8,
    ir: ?*ir_mod.IR,
    cfg: *CodegenConfig,
) !void {
    // Generate interface file if path is specified
    if (try cfg.getInterfacesPath()) |interfaces_path| {
        try generateInterfaceFile(allocator, interface, source_file, interfaces_path, ir);
    }

    // Generate impl stub file if path is specified
    if (try cfg.getImplsPath()) |impls_path| {
        try generateImplFile(allocator, interface, impls_path, ir);
    }
}

fn generateInterfaceFile(
    allocator: std.mem.Allocator,
    interface: types.Interface,
    source_file: []const u8,
    interfaces_path: []const u8,
    ir: ?*ir_mod.IR,
) !void {
    // Create interfaces directory
    try std.fs.cwd().makePath(interfaces_path);

    // Create output file in interfaces directory
    const output_filename = try std.fmt.allocPrint(allocator, "{s}.zig", .{interface.name});
    defer allocator.free(output_filename);

    const output_path = try std.fs.path.join(allocator, &.{ interfaces_path, output_filename });
    defer allocator.free(output_path);

    const output_file = try std.fs.cwd().createFile(output_path, .{});
    defer output_file.close();

    var buffer: [4096]u8 = undefined;
    var file_writer = output_file.writer(&buffer);
    const w = &file_writer.interface;

    // First, collect interface references from own members
    const own_interface_refs = try refs.collectInterfaceReferences(allocator, interface);
    defer {
        for (own_interface_refs) |ref| allocator.free(ref);
        allocator.free(own_interface_refs);
    }

    // Then collect additional refs from ALL members (including inherited)
    // This is needed to import types used in inherited operations
    const all_members_for_refs = if (ir) |ir_ptr|
        try ir_ptr.resolveAllMembers(interface.name)
    else
        interface.members;
    defer if (ir != null) allocator.free(all_members_for_refs);

    const all_interface_refs = try refs.collectMemberReferences(allocator, all_members_for_refs);
    defer {
        for (all_interface_refs) |ref| allocator.free(ref);
        allocator.free(all_interface_refs);
    }

    // Merge both sets of refs (deduplicating)
    var merged_refs = std.StringHashMap(void).init(allocator);
    defer merged_refs.deinit();

    for (own_interface_refs) |ref| {
        try merged_refs.put(ref, {});
    }
    for (all_interface_refs) |ref| {
        try merged_refs.put(ref, {});
    }

    // Convert to slice
    var interface_refs_list = std.ArrayList([]const u8).empty;
    defer interface_refs_list.deinit(allocator);

    var iter = merged_refs.keyIterator();
    while (iter.next()) |key| {
        const name = try allocator.dupe(u8, key.*);
        try interface_refs_list.append(allocator, name);
    }

    const interface_refs = try interface_refs_list.toOwnedSlice(allocator);
    defer {
        for (interface_refs) |ref| allocator.free(ref);
        allocator.free(interface_refs);
    }

    // Generate header with source filename
    const source_basename = std.fs.path.basename(source_file);
    try writer.writeHeader(w, source_basename, null);

    // Generate imports
    var mixin_list = std.ArrayList([]const u8).empty;
    defer mixin_list.deinit(allocator);

    for (interface.includes) |mixin| {
        try mixin_list.append(allocator, mixin);
    }

    const type_registry = if (ir) |interface_ir| &interface_ir.type_registry else null;
    try writer.writeImports(w, interface.name, interface.inheritance, mixin_list.items, interface_refs, type_registry);

    // Generate interface struct
    try writer.writeInterfaceStruct(w, interface.name);

    // Collect OWN members (for State struct - no inheritance)
    var own_attrs = std.ArrayList(types.Attribute).empty;
    defer own_attrs.deinit(allocator);

    var own_ops = std.ArrayList(types.Operation).empty;
    defer own_ops.deinit(allocator);

    var own_constructors = std.ArrayList(types.Constructor).empty;
    defer own_constructors.deinit(allocator);

    var own_constants = std.ArrayList(types.Constant).empty;
    defer own_constants.deinit(allocator);

    var iterable_member: ?types.Iterable = null;
    var async_iterable_member: ?types.AsyncIterable = null;

    for (interface.members) |member| {
        switch (member.type) {
            .attribute => if (member.attribute) |attr| {
                try own_attrs.append(allocator, attr);
            },
            .operation => if (member.operation) |op| {
                try own_ops.append(allocator, op);
            },
            .constructor => if (member.constructor) |ctor| {
                try own_constructors.append(allocator, ctor);
            },
            .constant => if (member.constant) |const_val| {
                try own_constants.append(allocator, const_val);
            },
            .iterable => if (member.iterable) |iterable_def| {
                iterable_member = iterable_def;
            },
            .async_iterable => if (member.async_iterable) |async_iterable_def| {
                async_iterable_member = async_iterable_def;
            },
        }
    }

    // Collect ALL members (including inherited - for VTable and delegate functions)
    const all_members = if (ir) |ir_ptr|
        try ir_ptr.resolveAllMembers(interface.name)
    else
        interface.members;
    defer if (ir != null) allocator.free(all_members);

    var all_attrs = std.ArrayList(types.Attribute).empty;
    defer all_attrs.deinit(allocator);

    var all_ops = std.ArrayList(types.Operation).empty;
    defer all_ops.deinit(allocator);

    var all_constants = std.ArrayList(types.Constant).empty;
    defer all_constants.deinit(allocator);

    for (all_members) |member| {
        switch (member.type) {
            .attribute => if (member.attribute) |attr| {
                try all_attrs.append(allocator, attr);
            },
            .operation => if (member.operation) |op| {
                try all_ops.append(allocator, op);
            },
            .constant => if (member.constant) |const_val| {
                try all_constants.append(allocator, const_val);
            },
            else => {},
        }
    }

    // Check if interface has constructors
    const has_constructor = own_constructors.items.len > 0;

    // Deduplicate own constants before generating constant getters
    // Partial interfaces can cause duplicate constant definitions
    try deduplicateConstants(allocator, &own_constants);

    // Track allocated forEach arrays for cleanup
    var forEach_args_own_alloc: ?[]types.Argument = null;
    var forEach_extAttrs_own_alloc: ?[]types.ExtendedAttribute = null;
    defer if (forEach_args_own_alloc) |arr| allocator.free(arr);
    defer if (forEach_extAttrs_own_alloc) |arr| allocator.free(arr);

    // Add forEach to own_ops for iterable interfaces (per WebIDL spec)
    // This ensures forEach appears in own_methods and gets registered in V8
    if (iterable_member != null) {
        var forEach_args_own = try allocator.alloc(types.Argument, 1);
        forEach_args_own_alloc = forEach_args_own;
        forEach_args_own[0] = types.Argument{
            .name = "callback",
            .idlType = types.IDLType{ .type = "any" },
            .optional = false,
            .variadic = false,
            .default = null,
        };

        const forEach_extAttrs_own = try allocator.alloc(types.ExtendedAttribute, 0);
        forEach_extAttrs_own_alloc = forEach_extAttrs_own;

        const forEach_op_own = types.Operation{
            .name = "forEach",
            .idlType = types.IDLType{ .type = "void" },
            .arguments = forEach_args_own,
            .special = null,
            .extAttrs = forEach_extAttrs_own,
        };
        try own_ops.append(allocator, forEach_op_own);
    }

    // Track allocated async iterator method arrays for cleanup
    var values_args_alloc: ?[]types.Argument = null;
    var values_extAttrs_alloc: ?[]types.ExtendedAttribute = null;
    var getAsyncIterator_args_alloc: ?[]types.Argument = null;
    var getAsyncIterator_extAttrs_alloc: ?[]types.ExtendedAttribute = null;
    defer if (values_args_alloc) |arr| allocator.free(arr);
    defer if (values_extAttrs_alloc) |arr| allocator.free(arr);
    defer if (getAsyncIterator_args_alloc) |arr| allocator.free(arr);
    defer if (getAsyncIterator_extAttrs_alloc) |arr| allocator.free(arr);

    // Add values() and [Symbol.asyncIterator]() for async_iterable interfaces (per WebIDL spec)
    // This ensures they appear in own_methods and get registered in V8
    if (async_iterable_member) |async_iter| {
        // Create values() operation with same arguments as async_iterable declaration
        const values_args = try allocator.dupe(types.Argument, async_iter.arguments);
        values_args_alloc = values_args;

        const values_extAttrs = try allocator.alloc(types.ExtendedAttribute, 0);
        values_extAttrs_alloc = values_extAttrs;

        const values_op = types.Operation{
            .name = "values",
            .idlType = types.IDLType{ .type = "ReadableStreamAsyncIterator" },
            .arguments = values_args,
            .special = null,
            .extAttrs = values_extAttrs,
        };
        try own_ops.append(allocator, values_op);

        // Create [Symbol.asyncIterator]() operation (mapped to getAsyncIterator in impl)
        const getAsyncIterator_args = try allocator.dupe(types.Argument, async_iter.arguments);
        getAsyncIterator_args_alloc = getAsyncIterator_args;

        const getAsyncIterator_extAttrs = try allocator.alloc(types.ExtendedAttribute, 0);
        getAsyncIterator_extAttrs_alloc = getAsyncIterator_extAttrs;

        const getAsyncIterator_op = types.Operation{
            .name = "getAsyncIterator",
            .idlType = types.IDLType{ .type = "ReadableStreamAsyncIterator" },
            .arguments = getAsyncIterator_args,
            .special = null,
            .extAttrs = getAsyncIterator_extAttrs,
        };
        try own_ops.append(allocator, getAsyncIterator_op);
    }

    // Check if base type is an interface (vs dictionary/typedef)
    // If base is an interface, we use BaseType = ParentInterface.State for embedded inheritance
    // If base is not an interface (e.g., dictionary), we use BaseType = *Dictionary pointer
    const base_is_interface = if (interface.inheritance) |base_name| blk: {
        if (type_registry) |reg| {
            if (reg.lookup(base_name)) |kind| {
                break :blk (kind == .interface or kind == .callback_interface);
            }
        }
        // Default to true if we can't determine (most common case)
        break :blk true;
    } else false;

    // Generate metadata with property/method hints for V8 bindings
    try writer.writeMetadata(
        w,
        interface.name,
        null, // spec_url - would come from extended attributes
        interface.inheritance,
        base_is_interface,
        mixin_list.items,
        interface.extAttrs,
        all_attrs.items, // Metadata includes all attributes (for reflection)
        all_ops.items, // All operations including inherited
        own_ops.items, // Own operations (for tracking overrides)
        own_constants.items, // Constants (for V8 static property registration)
        has_constructor,
        interface.mixin, // Whether this is a mixin interface
        interface.callback, // Whether this is a callback interface
        iterable_member, // Iterable declaration if present
        own_attrs.items, // Own attributes (for V8 property registration)
        async_iterable_member, // Async iterable declaration if present
    );

    // Deduplicate own attributes before generating State struct
    // Partial interfaces can cause duplicate attribute definitions
    try deduplicateAttributes(allocator, &own_attrs);

    // Deduplicate own operations before generating methods metadata
    // Partial interfaces can cause duplicate operation definitions
    try deduplicateOperations(allocator, &own_ops);

    // Deduplicate own constructors before generating constructor functions
    // Partial interfaces can cause duplicate constructor definitions
    try deduplicateConstructors(allocator, &own_constructors);

    // impl_name needed for State generation and delegate functions
    const impl_name = try std.fmt.allocPrint(allocator, "{s}Impl", .{interface.name});
    defer allocator.free(impl_name);

    // Generate State struct from OWN attributes only (preserving WebIDL casing and types)
    // State includes only this interface's own attributes
    // FullState will flatten with inheritance/mixins via runtime.FlattenedState
    try writer.writeGeneratedState(w, own_attrs.items, impl_name, type_registry);

    // Generate constant getters (static functions returning const values)
    // Only generate OWN constants - inherited constants accessed via parent vtable
    try writer.writeConstants(w, own_constants.items);

    // Deduplicate attributes, operations, and constants before generating VTable and delegate functions
    // This prevents duplicate vtable entries and delegate functions from multiple inheritance/mixins
    try deduplicateAttributes(allocator, &all_attrs);
    try deduplicateOperations(allocator, &all_ops);
    try deduplicateConstants(allocator, &all_constants);

    // Track allocated forEach arrays for cleanup
    var forEach_args_alloc: ?[]types.Argument = null;
    var forEach_extAttrs_alloc: ?[]types.ExtendedAttribute = null;
    defer if (forEach_args_alloc) |arr| allocator.free(arr);
    defer if (forEach_extAttrs_alloc) |arr| allocator.free(arr);

    // Add forEach operation for iterable interfaces (per WebIDL spec)
    if (iterable_member != null) {
        // Create synthetic forEach operation
        var forEach_args = try allocator.alloc(types.Argument, 1);
        forEach_args_alloc = forEach_args;
        forEach_args[0] = types.Argument{
            .name = "callback",
            .idlType = types.IDLType{ .type = "any" },
            .optional = false,
            .variadic = false,
            .default = null,
        };

        const forEach_extAttrs = try allocator.alloc(types.ExtendedAttribute, 0);
        forEach_extAttrs_alloc = forEach_extAttrs;

        const forEach_op = types.Operation{
            .name = "forEach",
            .idlType = types.IDLType{ .type = "void" },
            .arguments = forEach_args,
            .special = null,
            .extAttrs = forEach_extAttrs,
        };
        try all_ops.append(allocator, forEach_op);
    }

    // Generate VTable (with ONLY own attributes/operations, not inherited)
    try writer.writeVTable(w, all_constants.items, own_constants.items, own_attrs.items, own_ops.items);

    // Generate lifecycle functions
    try writer.writeLifecycleFunctions(w, impl_name);

    // Generate constructors (WebIDL interfaces can have multiple constructors)
    if (own_constructors.items.len > 0) {
        const type_reg = if (ir) |ir_ptr| &ir_ptr.type_registry else null;

        if (own_constructors.items.len == 1) {
            // Single constructor - generate normal function
            try writer.writeConstructor(w, impl_name, own_constructors.items[0], type_reg);
        } else {
            // Multiple constructors - generate overloaded version with tagged union
            const ctor_set = try overload.groupConstructors(allocator, own_constructors.items);
            defer overload.freeConstructorSet(allocator, ctor_set);
            try writer.writeOverloadedConstructor(w, impl_name, ctor_set, type_reg);
        }
    }

    // Generate delegate functions (ONLY for own attributes/operations, not inherited)
    const type_reg = if (ir) |ir_ptr| &ir_ptr.type_registry else null;
    try writer.writeDelegateFunctions(w, impl_name, type_reg, own_attrs.items, own_ops.items);

    // Generate iterable support if interface has iterable declaration
    if (iterable_member) |iterable| {
        try writer.writeIterableSupport(w, impl_name, iterable);
    }

    // Close struct
    try writer.writeStructEnd(w);

    // Flush writer
    try w.flush();
}

/// Generate Zig code for all interfaces in a WebIDL file (.idl or .json)
pub fn generateFromFile(
    allocator: std.mem.Allocator,
    input_path: []const u8,
    cfg: *CodegenConfig,
) !void {
    const parsed = try parser.parseIDLFile(allocator, input_path);
    defer parsed.deinit();

    // Use IR to merge partial interfaces
    var ir = try ir_mod.IR.init(allocator);
    defer ir.deinit();

    // Add all interfaces to IR (this merges partials automatically)
    for (parsed.value.interfaces) |iface| {
        ir.addInterface(iface, input_path) catch |err| {
            if (err == error.DuplicateInterface) {
                // Skip duplicates
                continue;
            } else {
                return err;
            }
        };
    }

    // Add dictionaries to IR
    for (parsed.value.dictionaries) |dict| {
        try ir.addDictionary(dict, input_path);
    }

    // Add typedefs to IR
    for (parsed.value.typedefs) |typedef| {
        try ir.addTypedef(typedef, input_path);
    }

    // Add namespaces to IR
    for (parsed.value.namespaces) |namespace| {
        try ir.addNamespace(namespace, input_path);
    }

    // Process includes statements to merge mixins
    try ir.processIncludes(parsed.value.includes);

    // Collect interface names for root.zig generation
    var interface_names = std.ArrayList([]const u8).empty;
    defer {
        for (interface_names.items) |name| {
            allocator.free(name);
        }
        interface_names.deinit(allocator);
    }

    // Generate code for each merged interface
    var iface_iter = ir.interfaces.iterator();
    while (iface_iter.next()) |entry| {
        const merged_iface = entry.value_ptr;

        // Convert back to types.Interface for generation
        const types_iface = try merged_iface.toTypes(allocator);
        defer {
            allocator.free(types_iface.name);
            if (types_iface.inheritance) |inh| allocator.free(inh);
            allocator.free(types_iface.members);
            allocator.free(types_iface.extAttrs);
            allocator.free(types_iface.includes);
        }

        // Collect interface name for root.zig
        const name_copy = try allocator.dupe(u8, types_iface.name);
        try interface_names.append(allocator, name_copy);

        try generateInterface(allocator, types_iface, input_path, &ir, cfg);
    }

    // Generate typedefs
    if (try cfg.getTypedefsPath()) |typedefs_path| {
        var typedef_iter = ir.typedefs.iterator();
        while (typedef_iter.next()) |entry| {
            const typedef = entry.value_ptr.*;
            // Skip typedefs that have special hand-written implementations
            // These are in webidl/types/buffer_sources.zig with proper union types and methods
            if (isSpecialTypedef(typedef.name)) continue;
            try generateTypedef(allocator, typedef, typedefs_path, &ir);
        }
    }

    // Generate dictionaries
    if (try cfg.getDictionariesPath()) |dictionaries_path| {
        var dict_iter = ir.dictionaries.iterator();
        while (dict_iter.next()) |entry| {
            const dict = entry.value_ptr.*;
            try generateDictionary(allocator, dict, dictionaries_path, &ir);
        }
    }

    // Generate enums
    if (try cfg.getEnumsPath()) |enums_path| {
        var enum_iter = ir.enums.iterator();
        while (enum_iter.next()) |entry| {
            const enum_type = entry.value_ptr.*;
            try generateEnum(allocator, enum_type, enums_path);
        }
    }

    // Generate callbacks
    if (try cfg.getCallbacksPath()) |callbacks_path| {
        var callback_iter = ir.callbacks.iterator();
        while (callback_iter.next()) |entry| {
            const callback = entry.value_ptr.*;
            try generateCallback(allocator, callback, callbacks_path);
        }
    }

    // Collect namespace names for root.zig generation
    var namespace_names = std.ArrayList([]const u8).empty;
    defer {
        for (namespace_names.items) |name| {
            allocator.free(name);
        }
        namespace_names.deinit(allocator);
    }

    // Generate namespaces
    if (try cfg.getNamespacesPath()) |namespaces_path| {
        var namespace_iter = ir.namespaces.iterator();
        while (namespace_iter.next()) |entry| {
            const namespace = entry.value_ptr.*;
            try generateNamespace(allocator, namespace, namespaces_path);

            // Generate impl stub if requested
            if (try cfg.getImplsPath()) |impls_path_for_ns| {
                try generateNamespaceImpl(allocator, namespace, impls_path_for_ns);
            }

            // Collect namespace name for root.zig
            const name_copy = try allocator.dupe(u8, namespace.name);
            try namespace_names.append(allocator, name_copy);
        }
    }

    // Generate root.zig files
    if (try cfg.getInterfacesPath()) |interfaces_path| {
        try generateInterfacesRoot(allocator, interfaces_path, interface_names.items);
    }

    if (try cfg.getImplsPath()) |impls_path| {
        try generateImplsRoot(allocator, impls_path, interface_names.items, namespace_names.items);
    }
}

/// Generate Zig code for all WebIDL JSON files in a directory
pub fn generateFromDirectory(
    allocator: std.mem.Allocator,
    input_dir: []const u8,
    cfg: *CodegenConfig,
) !void {
    const idl_files = try files.findIDLFiles(allocator, input_dir);
    defer {
        for (idl_files) |path| allocator.free(path);
        allocator.free(idl_files);
    }

    for (idl_files) |file_path| {
        try generateFromFile(allocator, file_path, cfg);
    }
}

// Unit tests
const testing = std.testing;

test "generateInterface creates output file" {
    const allocator = testing.allocator;

    // Create a temporary directory for output
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    // Simple test interface
    const test_interface: types.Interface = .{
        .name = "TestInterface",
    };

    // Generate code
    var cfg = CodegenConfig.default(allocator);
    defer cfg.deinit();
    cfg.dest_root = tmp_path;

    try generateInterface(allocator, test_interface, "test.idl", null, &cfg);

    // Verify output file was created
    const interfaces_path = try std.fs.path.join(allocator, &.{ tmp_path, "interfaces" });
    defer allocator.free(interfaces_path);
    const output_path = try std.fs.path.join(allocator, &.{ interfaces_path, "TestInterface.zig" });
    defer allocator.free(output_path);

    const file = try std.fs.cwd().openFile(output_path, .{});
    defer file.close();

    // Read and verify content
    const content = try file.readToEndAlloc(allocator, 10 * 1024);
    defer allocator.free(content);

    // Should contain struct declaration
    try testing.expect(std.mem.indexOf(u8, content, "pub const TestInterface = struct {") != null);
    // Should contain header
    try testing.expect(std.mem.indexOf(u8, content, "Generated from: test.idl") != null);
}

test "generateInterface includes base type in imports" {
    const allocator = testing.allocator;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const test_interface: types.Interface = .{
        .name = "Node",
        .inheritance = "EventTarget",
    };

    var cfg = CodegenConfig.default(allocator);
    defer cfg.deinit();
    cfg.dest_root = tmp_path;

    try generateInterface(allocator, test_interface, "dom.idl", null, &cfg);

    const interfaces_path = try std.fs.path.join(allocator, &.{ tmp_path, "interfaces" });
    defer allocator.free(interfaces_path);
    const output_path = try std.fs.path.join(allocator, &.{ interfaces_path, "Node.zig" });
    defer allocator.free(output_path);

    const file = try std.fs.cwd().openFile(output_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 10 * 1024);
    defer allocator.free(content);

    // Should import base type from "interfaces" module
    try testing.expect(std.mem.indexOf(u8, content, "const EventTarget = @import(\"interfaces\").EventTarget;") != null);
}

test "generateInterface includes lifecycle functions" {
    const allocator = testing.allocator;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const test_interface: types.Interface = .{
        .name = "TestInterface",
    };

    var cfg = CodegenConfig.default(allocator);
    defer cfg.deinit();
    cfg.dest_root = tmp_path;

    try generateInterface(allocator, test_interface, "test.idl", null, &cfg);

    const interfaces_path = try std.fs.path.join(allocator, &.{ tmp_path, "interfaces" });
    defer allocator.free(interfaces_path);
    const output_path = try std.fs.path.join(allocator, &.{ interfaces_path, "TestInterface.zig" });
    defer allocator.free(output_path);

    const file = try std.fs.cwd().openFile(output_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 10 * 1024);
    defer allocator.free(content);

    // Should have init and deinit
    try testing.expect(std.mem.indexOf(u8, content, "pub fn init(") != null);
    try testing.expect(std.mem.indexOf(u8, content, "pub fn deinit(") != null);
    // init() should delegate to TestInterfaceImpl with State and vtable
    try testing.expect(std.mem.indexOf(u8, content, "TestInterfaceImpl.init(allocator, State, &vtable, ctx)") != null);
}

/// Check if a type references a callback (by checking if callback file exists)
fn typeReferencesCallback(allocator: std.mem.Allocator, idl_type: types.IDLType, typedefs_path: []const u8) !bool {
    // Get the callbacks directory (sibling to typedefs)
    const parent_dir = std.fs.path.dirname(typedefs_path) orelse ".";
    const callbacks_dir = try std.fs.path.join(allocator, &.{ parent_dir, "callbacks" });
    defer allocator.free(callbacks_dir);

    // Check if the type name exists as a callback file
    const callback_filename = try std.fmt.allocPrint(allocator, "{s}.zig", .{idl_type.type});
    defer allocator.free(callback_filename);

    const callback_path = try std.fs.path.join(allocator, &.{ callbacks_dir, callback_filename });
    defer allocator.free(callback_path);

    // If file exists, this is a callback reference
    std.fs.cwd().access(callback_path, .{}) catch {
        // Also check union member types
        if (idl_type.unionTypes) |union_types| {
            for (union_types) |union_member| {
                if (try typeReferencesCallback(allocator, union_member, typedefs_path)) {
                    return true;
                }
            }
        }
        return false;
    };

    return true;
}

/// Check if an IDL type references a typedef (to determine if we need to import typedefs module)
fn typeReferencesTypedef(idl_type: types.IDLType, type_registry: *const ir_mod.TypeRegistry) bool {
    // Check the main type
    if (type_registry.lookup(idl_type.type)) |kind| {
        if (kind == .typedef) return true;
    }

    // Check sequence element type (populated by some code paths)
    if (idl_type.sequence) |elem_type| {
        if (typeReferencesTypedef(elem_type.*, type_registry)) return true;
    }

    // Check generic field (used by parser for sequence<T> and record<K,V>)
    if (idl_type.generic) |generic_str| {
        if (checkGenericStringForType(generic_str, type_registry, .typedef)) return true;
    }

    // Check record key and value types
    if (idl_type.record) |rec| {
        if (typeReferencesTypedef(rec.key.*, type_registry)) return true;
        if (typeReferencesTypedef(rec.value.*, type_registry)) return true;
    }

    // Check union member types
    if (idl_type.unionTypes) |union_types| {
        for (union_types) |union_member| {
            if (typeReferencesTypedef(union_member, type_registry)) return true;
        }
    }

    return false;
}

/// Check if an IDL type references an enum (to determine if we need to import enums module)
fn typeReferencesEnum(idl_type: types.IDLType, type_registry: *const ir_mod.TypeRegistry) bool {
    // Check the main type
    if (type_registry.lookup(idl_type.type)) |kind| {
        if (kind == .enum_type) return true;
    }

    // Check sequence element type
    if (idl_type.sequence) |elem_type| {
        if (typeReferencesEnum(elem_type.*, type_registry)) return true;
    }

    // Check generic field
    if (idl_type.generic) |generic_str| {
        if (checkGenericStringForType(generic_str, type_registry, .enum_type)) return true;
    }

    // Check record key and value types
    if (idl_type.record) |rec| {
        if (typeReferencesEnum(rec.key.*, type_registry)) return true;
        if (typeReferencesEnum(rec.value.*, type_registry)) return true;
    }

    // Check union member types
    if (idl_type.unionTypes) |union_types| {
        for (union_types) |union_member| {
            if (typeReferencesEnum(union_member, type_registry)) return true;
        }
    }

    return false;
}

/// Check if an IDL type references a dictionary (to determine if we need to import dictionaries module)
fn typeReferencesDictionary(idl_type: types.IDLType, type_registry: *const ir_mod.TypeRegistry) bool {
    // Check the main type
    if (type_registry.lookup(idl_type.type)) |kind| {
        if (kind == .dictionary) return true;
    }

    // Check sequence element type
    if (idl_type.sequence) |elem_type| {
        if (typeReferencesDictionary(elem_type.*, type_registry)) return true;
    }

    // Check generic field
    if (idl_type.generic) |generic_str| {
        if (checkGenericStringForType(generic_str, type_registry, .dictionary)) return true;
    }

    // Check record key and value types
    if (idl_type.record) |rec| {
        if (typeReferencesDictionary(rec.key.*, type_registry)) return true;
        if (typeReferencesDictionary(rec.value.*, type_registry)) return true;
    }

    // Check union member types
    if (idl_type.unionTypes) |union_types| {
        for (union_types) |union_member| {
            if (typeReferencesDictionary(union_member, type_registry)) return true;
        }
    }

    return false;
}

/// Check if a generic string (like "CookieListItem" or "K, V") contains a type of the specified kind
fn checkGenericStringForType(generic_str: []const u8, type_registry: *const ir_mod.TypeRegistry, target_kind: ir_mod.TypeKind) bool {
    // Split on commas and check each part
    var iter = std.mem.splitSequence(u8, generic_str, ",");
    while (iter.next()) |part| {
        const trimmed = std.mem.trim(u8, part, " \t\n<>");
        // Extract just the type name (skip sequence/record keywords)
        var type_name = trimmed;
        if (std.mem.startsWith(u8, trimmed, "sequence<")) {
            const start = "sequence<".len;
            if (start < trimmed.len) {
                type_name = std.mem.trim(u8, trimmed[start..], " \t\n<>");
            }
        }
        // Check if this type is the target kind
        if (type_registry.lookup(type_name)) |kind| {
            if (kind == target_kind) return true;
        }
    }
    return false;
}

/// Collect dictionary type names referenced by an IDL type (excluding self)
/// Used to generate individual import statements instead of root import
fn collectReferencedDictionaries(idl_type: types.IDLType, type_registry: *const ir_mod.TypeRegistry, self_name: []const u8, result: *std.StringHashMap(void)) !void {
    // Check the main type
    if (type_registry.lookup(idl_type.type)) |kind| {
        if (kind == .dictionary and !std.mem.eql(u8, idl_type.type, self_name)) {
            try result.put(idl_type.type, {});
        }
    }

    // Check sequence element type
    if (idl_type.sequence) |elem_type| {
        try collectReferencedDictionaries(elem_type.*, type_registry, self_name, result);
    }

    // Check generic field
    if (idl_type.generic) |generic_str| {
        if (checkGenericStringForType(generic_str, type_registry, .dictionary)) {
            // Extract the dictionary names from generic string
            var iter = std.mem.splitSequence(u8, generic_str, ",");
            while (iter.next()) |part| {
                const trimmed = std.mem.trim(u8, part, " \t\n<>");
                if (type_registry.lookup(trimmed)) |kind| {
                    if (kind == .dictionary and !std.mem.eql(u8, trimmed, self_name)) {
                        try result.put(trimmed, {});
                    }
                }
            }
        }
    }

    // Check record key and value types
    if (idl_type.record) |rec| {
        try collectReferencedDictionaries(rec.key.*, type_registry, self_name, result);
        try collectReferencedDictionaries(rec.value.*, type_registry, self_name, result);
    }

    // Check union member types
    if (idl_type.unionTypes) |union_types| {
        for (union_types) |union_member| {
            try collectReferencedDictionaries(union_member, type_registry, self_name, result);
        }
    }
}

/// Derive a semantic variant name from an IDL type
/// Converts WebIDL type names to valid Zig identifiers in snake_case
fn deriveVariantName(allocator: std.mem.Allocator, idl_type: types.IDLType) ![]const u8 {
    // Handle sequence types: sequence<T> -> "t_sequence"
    if (idl_type.sequence) |elem_type| {
        const elem_name = try deriveVariantName(allocator, elem_type.*);
        defer allocator.free(elem_name);
        return std.fmt.allocPrint(allocator, "{s}_sequence", .{elem_name});
    }

    // Handle record types: record<K, V> -> "k_v_record"
    if (idl_type.record) |rec| {
        const key_name = try deriveVariantName(allocator, rec.key.*);
        defer allocator.free(key_name);
        const val_name = try deriveVariantName(allocator, rec.value.*);
        defer allocator.free(val_name);
        return std.fmt.allocPrint(allocator, "{s}_{s}_record", .{ key_name, val_name });
    }

    // Handle union types (nested unions) - use first type's name with "_union" suffix
    if (idl_type.unionTypes) |union_types| {
        if (union_types.len > 0) {
            const first_name = try deriveVariantName(allocator, union_types[0]);
            defer allocator.free(first_name);
            return std.fmt.allocPrint(allocator, "{s}_union", .{first_name});
        }
        return allocator.dupe(u8, "union");
    }

    // Handle record type stored with .generic field: record<K, V>
    if (std.mem.eql(u8, idl_type.type, "record") and idl_type.generic != null) {
        const generic_str = idl_type.generic.?;
        if (std.mem.indexOf(u8, generic_str, ",")) |comma_idx| {
            const key_str = std.mem.trim(u8, generic_str[0..comma_idx], " \t");
            const val_str = std.mem.trim(u8, generic_str[comma_idx + 1 ..], " \t");
            const key_name = try sanitizeTypeName(allocator, key_str);
            defer allocator.free(key_name);
            const val_name = try sanitizeTypeName(allocator, val_str);
            defer allocator.free(val_name);
            return std.fmt.allocPrint(allocator, "{s}_{s}_record", .{ key_name, val_name });
        }
    }

    // Handle sequence type stored with .generic field: sequence<T>
    if (std.mem.eql(u8, idl_type.type, "sequence") and idl_type.generic != null) {
        const generic_str = idl_type.generic.?;
        const elem_name = try sanitizeTypeName(allocator, generic_str);
        defer allocator.free(elem_name);
        return std.fmt.allocPrint(allocator, "{s}_sequence", .{elem_name});
    }

    // Handle other generic types: Promise<T> -> "t_promise"
    if (idl_type.generic) |generic_arg| {
        const sanitized_generic = try sanitizeTypeName(allocator, generic_arg);
        defer allocator.free(sanitized_generic);
        const sanitized_base = try sanitizeTypeName(allocator, idl_type.type);
        defer allocator.free(sanitized_base);
        return std.fmt.allocPrint(allocator, "{s}_{s}", .{ sanitized_generic, sanitized_base });
    }

    // Simple type name - sanitize to valid Zig identifier
    return sanitizeTypeName(allocator, idl_type.type);
}

/// Sanitize a WebIDL type name to a valid Zig identifier in snake_case
fn sanitizeTypeName(allocator: std.mem.Allocator, type_name: []const u8) ![]const u8 {
    // Handle empty type name
    if (type_name.len == 0) {
        return allocator.dupe(u8, "unknown");
    }

    // Map common multi-word types
    const mappings = .{
        .{ "unsigned short", "ushort" },
        .{ "unsigned long long", "ulong_long" },
        .{ "unsigned long", "ulong" },
        .{ "long long", "long_long" },
        .{ "unrestricted float", "float" },
        .{ "unrestricted double", "double" },
    };

    inline for (mappings) |mapping| {
        if (std.mem.eql(u8, type_name, mapping[0])) {
            return allocator.dupe(u8, mapping[1]);
        }
    }

    // Allocate worst-case buffer: underscore before every char
    const buf = try allocator.alloc(u8, type_name.len * 2);
    errdefer allocator.free(buf);

    var len: usize = 0;
    var prev_was_lower = false;

    for (type_name) |c| {
        // Skip invalid characters for Zig identifiers
        if (c == ' ' or c == '-' or c == '<' or c == '>' or c == ',' or c == '?' or c == '(' or c == ')') {
            if (len > 0 and buf[len - 1] != '_') {
                buf[len] = '_';
                len += 1;
            }
            prev_was_lower = false;
            continue;
        }

        // Insert underscore before uppercase letters (for camelCase/PascalCase)
        if (std.ascii.isUpper(c)) {
            if (prev_was_lower and len > 0) {
                buf[len] = '_';
                len += 1;
            }
            buf[len] = std.ascii.toLower(c);
            len += 1;
            prev_was_lower = false;
        } else {
            buf[len] = c;
            len += 1;
            prev_was_lower = std.ascii.isLower(c);
        }
    }

    // Remove trailing underscores
    while (len > 0 and buf[len - 1] == '_') {
        len -= 1;
    }

    // Handle empty result
    if (len == 0) {
        allocator.free(buf);
        return allocator.dupe(u8, "value");
    }

    // Return slice of actual size
    const result = try allocator.dupe(u8, buf[0..len]);
    allocator.free(buf);
    return result;
}

/// Parse an inline type string like "sequence<ByteString>" or "ByteString" into an IDLType
fn parseInlineType(allocator: std.mem.Allocator, type_str: []const u8) !types.IDLType {
    const trimmed = std.mem.trim(u8, type_str, " \t\n");

    // Handle sequence<T>
    if (std.mem.startsWith(u8, trimmed, "sequence<")) {
        const start = "sequence<".len;
        var depth: usize = 1;
        var end = start;
        while (end < trimmed.len and depth > 0) {
            if (trimmed[end] == '<') depth += 1;
            if (trimmed[end] == '>') depth -= 1;
            if (depth > 0) end += 1;
        }
        if (end > start) {
            const inner = trimmed[start..end];
            return types.IDLType{
                .type = try allocator.dupe(u8, "sequence"),
                .generic = try allocator.dupe(u8, inner),
            };
        }
    }

    // Handle record<K, V>
    if (std.mem.startsWith(u8, trimmed, "record<")) {
        const start = "record<".len;
        var depth: usize = 1;
        var end = start;
        while (end < trimmed.len and depth > 0) {
            if (trimmed[end] == '<') depth += 1;
            if (trimmed[end] == '>') depth -= 1;
            if (depth > 0) end += 1;
        }
        if (end > start) {
            const inner = trimmed[start..end];
            return types.IDLType{
                .type = try allocator.dupe(u8, "record"),
                .generic = try allocator.dupe(u8, inner),
            };
        }
    }

    // Simple type name
    return types.IDLType{
        .type = try allocator.dupe(u8, trimmed),
    };
}

/// Write a type for typedef generation (handles callback references)
fn writeTypeForTypedef(allocator: std.mem.Allocator, w: anytype, idl_type: types.IDLType, typedefs_path: []const u8) !void {
    return writeTypeForTypedefWithRegistry(allocator, w, idl_type, typedefs_path, null);
}

/// Write a type for typedef generation with type registry for proper interface resolution
fn writeTypeForTypedefWithRegistry(allocator: std.mem.Allocator, w: anytype, idl_type: types.IDLType, typedefs_path: []const u8, type_registry: ?*const ir_mod.TypeRegistry) !void {
    const type_str = idl_type.type;

    // Check if this is a callback reference
    if (try typeReferencesCallback(allocator, idl_type, typedefs_path)) {
        // Reference the callback from callbacks module
        try w.print("callbacks.{s}", .{type_str});
        return;
    }

    // Handle sequence types: sequence<T> -> []const T
    if (idl_type.sequence) |elem_type| {
        try w.writeAll("[]const ");
        try writeTypeForTypedefWithRegistry(allocator, w, elem_type.*, typedefs_path, type_registry);
        return;
    }

    // Handle sequence type stored with .generic field (parser sometimes uses this format)
    if (std.mem.eql(u8, type_str, "sequence") and idl_type.generic != null) {
        const inner_type_str = idl_type.generic.?;
        try w.writeAll("[]const ");
        const inner_idl_type = try parseInlineType(allocator, inner_type_str);
        try writeTypeForTypedefWithRegistry(allocator, w, inner_idl_type, typedefs_path, type_registry);
        return;
    }

    // Handle record types: record<K, V> -> []const struct { key: K, value: V }
    if (idl_type.record) |rec| {
        try w.writeAll("[]const struct { key: ");
        try writeTypeForTypedefWithRegistry(allocator, w, rec.key.*, typedefs_path, type_registry);
        try w.writeAll(", value: ");
        try writeTypeForTypedefWithRegistry(allocator, w, rec.value.*, typedefs_path, type_registry);
        try w.writeAll(" }");
        return;
    }

    // Handle record type stored with .generic field
    if (std.mem.eql(u8, type_str, "record") and idl_type.generic != null) {
        const generic_str = idl_type.generic.?;
        if (std.mem.indexOf(u8, generic_str, ",")) |comma_idx| {
            const key_str = std.mem.trim(u8, generic_str[0..comma_idx], " \t");
            const val_str = std.mem.trim(u8, generic_str[comma_idx + 1 ..], " \t");
            try w.writeAll("[]const struct { key: ");
            const key_idl = try parseInlineType(allocator, key_str);
            try writeTypeForTypedefWithRegistry(allocator, w, key_idl, typedefs_path, type_registry);
            try w.writeAll(", value: ");
            const val_idl = try parseInlineType(allocator, val_str);
            try writeTypeForTypedefWithRegistry(allocator, w, val_idl, typedefs_path, type_registry);
            try w.writeAll(" }");
            return;
        }
    }

    // Use writeTypeSimple with registry for proper type resolution
    try writeTypeSimple(w, idl_type, type_registry);
}

/// Generate a typedef Zig file
pub fn generateTypedef(
    allocator: std.mem.Allocator,
    typedef: types.Typedef,
    typedefs_path: []const u8,
    ir: *const ir_mod.IR,
) !void {
    // Create typedefs directory
    try std.fs.cwd().makePath(typedefs_path);

    // Create typedef file
    const output_filename = try std.fmt.allocPrint(allocator, "{s}.zig", .{typedef.name});
    defer allocator.free(output_filename);

    const output_path = try std.fs.path.join(allocator, &.{ typedefs_path, output_filename });
    defer allocator.free(output_path);

    const output_file = try std.fs.cwd().createFile(output_path, .{});
    defer output_file.close();

    var buffer: [4096]u8 = undefined;
    var file_writer = output_file.writer(&buffer);
    const w = &file_writer.interface;

    // Write header
    try w.print("//! WebIDL typedef: {s}\n", .{typedef.name});
    try w.writeAll("//!\n");
    try w.writeAll("//! This file is AUTO-GENERATED. Do not edit manually.\n");
    try w.writeAll("\n");

    // Import runtime (needed for DOMString types and Instance)
    try w.writeAll("const runtime = @import(\"runtime\");\n");
    try w.writeAll("const v8 = @import(\"v8\");\n");

    // Check if typedef references a callback - if so, import callbacks module
    const needs_callbacks = try typeReferencesCallback(allocator, typedef.idlType, typedefs_path);
    if (needs_callbacks) {
        try w.writeAll("const callbacks = @import(\"callbacks\");\n");
    }

    // Check if typedef references other typedefs - if so, import typedefs module
    const needs_typedefs = typeReferencesTypedef(typedef.idlType, &ir.type_registry);
    if (needs_typedefs) {
        try w.writeAll("const typedefs = @import(\"root.zig\");\n");
    }

    // Check if typedef references dictionaries - if so, import dictionaries module
    // This is needed for union types that include dictionary variants
    const needs_dictionaries = typeReferencesDictionary(typedef.idlType, &ir.type_registry);
    if (needs_dictionaries) {
        try w.writeAll("const dictionaries = @import(\"dictionaries\");\n");
    }

    // Check if typedef references enums - if so, import enums module
    const needs_enums = typeReferencesEnum(typedef.idlType, &ir.type_registry);
    if (needs_enums) {
        try w.writeAll("const enums = @import(\"enums\");\n");
    }

    try w.writeAll("\n");

    // Check if it's a union type
    if (typedef.idlType.unionTypes) |union_types| {
        // Generate tagged union with semantic variant names
        try w.print("pub const {s} = union(enum) {{\n", .{typedef.name});

        // Track used names to handle duplicates
        var used_names = std.StringHashMap(u32).init(allocator);
        defer {
            var key_iter = used_names.keyIterator();
            while (key_iter.next()) |key| {
                allocator.free(key.*);
            }
            used_names.deinit();
        }

        for (union_types) |union_type| {
            // Derive semantic name from the IDL type
            const base_name = try deriveVariantName(allocator, union_type);
            defer allocator.free(base_name);

            // Handle duplicate names by appending a number
            const count = used_names.get(base_name) orelse 0;
            const key_copy = try allocator.dupe(u8, base_name);
            try used_names.put(key_copy, count + 1);

            const variant_name = if (count == 0)
                try allocator.dupe(u8, base_name)
            else
                try std.fmt.allocPrint(allocator, "{s}_{d}", .{ base_name, count });
            defer allocator.free(variant_name);

            try w.print("    {s}: ", .{variant_name});
            try writeTypeForTypedefWithRegistry(allocator, w, union_type, typedefs_path, &ir.type_registry);
            try w.writeAll(",\n");
        }

        try w.writeAll("};\n");
    } else {
        // Simple type alias
        try w.print("pub const {s} = ", .{typedef.name});

        // Handle nullable prefix
        if (typedef.idlType.nullable) {
            try w.writeAll("?");
        }

        try writeTypeForTypedefWithRegistry(allocator, w, typedef.idlType, typedefs_path, &ir.type_registry);
        try w.writeAll(";\n");
    }

    try w.flush();
}

/// Write a type for dictionary member with proper type resolution
/// Handles sequence types, record types, and uses type registry for resolution
fn writeDictionaryMemberType(allocator: std.mem.Allocator, w: anytype, idl_type: types.IDLType, type_registry: *const ir_mod.TypeRegistry) !void {
    const type_str = idl_type.type;

    // Handle sequence types: sequence<T> -> []const T
    if (idl_type.sequence) |elem_type| {
        try w.writeAll("[]const ");
        try writeDictionaryMemberType(allocator, w, elem_type.*, type_registry);
        return;
    }

    // Handle sequence type stored with .generic field (parser sometimes uses this format)
    if (std.mem.eql(u8, type_str, "sequence") and idl_type.generic != null) {
        const inner_type_str = idl_type.generic.?;
        try w.writeAll("[]const ");
        const inner_idl_type = try parseInlineType(allocator, inner_type_str);
        try writeDictionaryMemberType(allocator, w, inner_idl_type, type_registry);
        return;
    }

    // Handle record types: record<K, V> -> []const struct { key: K, value: V }
    if (idl_type.record) |rec| {
        try w.writeAll("[]const struct { key: ");
        try writeDictionaryMemberType(allocator, w, rec.key.*, type_registry);
        try w.writeAll(", value: ");
        try writeDictionaryMemberType(allocator, w, rec.value.*, type_registry);
        try w.writeAll(" }");
        return;
    }

    // Handle record type stored with .generic field
    if (std.mem.eql(u8, type_str, "record") and idl_type.generic != null) {
        const generic_str = idl_type.generic.?;
        if (std.mem.indexOf(u8, generic_str, ",")) |comma_idx| {
            const key_str = std.mem.trim(u8, generic_str[0..comma_idx], " \t");
            const val_str = std.mem.trim(u8, generic_str[comma_idx + 1 ..], " \t");
            try w.writeAll("[]const struct { key: ");
            const key_idl = try parseInlineType(allocator, key_str);
            try writeDictionaryMemberType(allocator, w, key_idl, type_registry);
            try w.writeAll(", value: ");
            const val_idl = try parseInlineType(allocator, val_str);
            try writeDictionaryMemberType(allocator, w, val_idl, type_registry);
            try w.writeAll(" }");
            return;
        }
    }

    // Special handling for dictionary references - use direct import (no module prefix)
    // since dictionaries import each other directly to avoid circular imports via root
    if (type_registry.lookup(type_str)) |kind| {
        if (kind == .dictionary) {
            // Use the type name directly (imported at top of file)
            try w.print("{s}", .{type_str});
            return;
        }
    }

    // Use writeTypeSimple with registry for proper type resolution of other types
    try writeTypeSimple(w, idl_type, type_registry);
}

/// Generate a dictionary Zig struct
pub fn generateDictionary(
    allocator: std.mem.Allocator,
    dictionary: types.Dictionary,
    dictionaries_path: []const u8,
    ir: *const ir_mod.IR,
) !void {
    // Create dictionaries directory
    try std.fs.cwd().makePath(dictionaries_path);

    // Create dictionary file
    const output_filename = try std.fmt.allocPrint(allocator, "{s}.zig", .{dictionary.name});
    defer allocator.free(output_filename);

    const output_path = try std.fs.path.join(allocator, &.{ dictionaries_path, output_filename });
    defer allocator.free(output_path);

    const output_file = try std.fs.cwd().createFile(output_path, .{});
    defer output_file.close();

    var buffer: [4096]u8 = undefined;
    var file_writer = output_file.writer(&buffer);
    const w = &file_writer.interface;

    // Write header
    try w.print("//! WebIDL dictionary: {s}\n", .{dictionary.name});
    try w.writeAll("//!\n");
    try w.writeAll("//! This file is AUTO-GENERATED. Do not edit manually.\n");
    try w.writeAll("\n");

    // Scan dictionary members to determine required imports
    var needs_typedefs = false;
    var needs_enums = false;
    var needs_callbacks = false;

    // Collect referenced dictionary names for individual imports (not self)
    var referenced_dicts = std.StringHashMap(void).init(allocator);
    defer referenced_dicts.deinit();

    for (dictionary.members) |member| {
        if (!needs_typedefs and typeReferencesTypedef(member.idlType, &ir.type_registry)) {
            needs_typedefs = true;
        }
        if (!needs_enums and typeReferencesEnum(member.idlType, &ir.type_registry)) {
            needs_enums = true;
        }
        // Collect dictionary type names instead of just setting a flag
        try collectReferencedDictionaries(member.idlType, &ir.type_registry, dictionary.name, &referenced_dicts);
        if (!needs_callbacks) {
            if (typeReferencesCallback(allocator, member.idlType, dictionaries_path) catch false) {
                needs_callbacks = true;
            }
        }
    }

    // Write imports
    try w.writeAll("const runtime = @import(\"runtime\");\n");
    try w.writeAll("const v8 = @import(\"v8\");\n");
    if (needs_typedefs) {
        try w.writeAll("const typedefs = @import(\"typedefs\");\n");
    }
    if (needs_enums) {
        try w.writeAll("const enums = @import(\"enums\");\n");
    }
    // Import specific dictionary files instead of root (to avoid circular imports)
    var dict_iter = referenced_dicts.iterator();
    while (dict_iter.next()) |entry| {
        const dict_name = entry.key_ptr.*;
        try w.print("const {s} = @import(\"{s}.zig\").{s};\n", .{ dict_name, dict_name, dict_name });
    }
    if (needs_callbacks) {
        try w.writeAll("const callbacks = @import(\"callbacks\");\n");
    }

    // Import base dictionary if inheritance exists
    if (dictionary.inheritance) |base_name| {
        // Don't duplicate if already imported
        if (!referenced_dicts.contains(base_name)) {
            try w.print("const {s} = @import(\"{s}.zig\").{s};\n", .{ base_name, base_name, base_name });
        }
    }

    try w.writeAll("\n");

    // Generate struct
    try w.print("pub const {s} = struct {{\n", .{dictionary.name});

    // If inheriting, embed base dictionary fields
    if (dictionary.inheritance) |base_name| {
        try w.print("    // Inherited from {s}\n", .{base_name});
        try w.print("    base: {s},\n\n", .{base_name});
    }

    // Generate fields from members
    for (dictionary.members) |member| {
        // Escape Zig keywords by wrapping in @"..." syntax
        if (isZigKeyword(member.name)) {
            try w.print("    @\"{s}\": ", .{member.name});
        } else {
            try w.print("    {s}: ", .{member.name});
        }

        // Dictionary members are optional by default unless required
        const is_required = member.required;
        if (!is_required) {
            try w.writeAll("?");
        }

        try writeDictionaryMemberType(allocator, w, member.idlType, &ir.type_registry);

        // Default value
        if (!is_required) {
            try w.writeAll(" = null");
        }

        try w.writeAll(",\n");
    }

    try w.writeAll("};\n");

    try w.flush();
}

/// Generate an enum Zig file
pub fn generateEnum(
    allocator: std.mem.Allocator,
    enum_type: types.Enum,
    enums_path: []const u8,
) !void {
    // Create enums directory
    try std.fs.cwd().makePath(enums_path);

    // Create enum file
    const output_filename = try std.fmt.allocPrint(allocator, "{s}.zig", .{enum_type.name});
    defer allocator.free(output_filename);

    const output_path = try std.fs.path.join(allocator, &.{ enums_path, output_filename });
    defer allocator.free(output_path);

    const output_file = try std.fs.cwd().createFile(output_path, .{});
    defer output_file.close();

    var buffer: [4096]u8 = undefined;
    var file_writer = output_file.writer(&buffer);
    const w = &file_writer.interface;

    // Write header
    try w.print("//! WebIDL enum: {s}\n", .{enum_type.name});
    try w.writeAll("//!\n");
    try w.writeAll("//! This file is AUTO-GENERATED. Do not edit manually.\n");
    try w.writeAll("\n");

    // Generate enum
    try w.print("pub const {s} = enum {{\n", .{enum_type.name});

    for (enum_type.values) |value| {
        // Convert enum value to valid Zig identifier
        const zig_name = try allocator.dupe(u8, value);
        defer allocator.free(zig_name);

        // Replace invalid characters with underscores
        for (zig_name) |*c| {
            if (!std.ascii.isAlphanumeric(c.*) and c.* != '_') {
                c.* = '_';
            }
        }

        try w.print("    {s},\n", .{zig_name});
    }

    try w.writeAll("};\n");

    try w.flush();
}

/// Generate a callback Zig file
pub fn generateCallback(
    allocator: std.mem.Allocator,
    callback: types.Callback,
    callbacks_path: []const u8,
) !void {
    // Create callbacks directory
    try std.fs.cwd().makePath(callbacks_path);

    // Create callback file
    const output_filename = try std.fmt.allocPrint(allocator, "{s}.zig", .{callback.name});
    defer allocator.free(output_filename);

    const output_path = try std.fs.path.join(allocator, &.{ callbacks_path, output_filename });
    defer allocator.free(output_path);

    const output_file = try std.fs.cwd().createFile(output_path, .{});
    defer output_file.close();

    var buffer: [4096]u8 = undefined;
    var file_writer = output_file.writer(&buffer);
    const w = &file_writer.interface;

    // Write header
    try w.print("//! WebIDL callback: {s}\n", .{callback.name});
    try w.writeAll("//!\n");
    try w.writeAll("//! This file is AUTO-GENERATED. Do not edit manually.\n");
    try w.writeAll("\n");

    // Write imports
    try w.writeAll("const runtime = @import(\"runtime\");\n");
    try w.writeAll("const webidl = @import(\"webidl\");\n");
    try w.writeAll("const v8 = @import(\"v8\");\n\n");

    // Generate callback function type
    try w.print("pub const {s} = *const fn (", .{callback.name});

    for (callback.arguments, 0..) |arg, i| {
        if (i > 0) try w.writeAll(", ");

        // Escape Zig keywords by wrapping in @"..." syntax
        if (isZigKeyword(arg.name)) {
            try w.print("@\"{s}\": ", .{arg.name});
        } else {
            try w.print("{s}: ", .{arg.name});
        }

        try writeParamType(w, arg, null);
    }

    try w.writeAll(") ");
    try writeTypeSimple(w, callback.idlType, null);
    try w.writeAll(";\n");

    try w.flush();
}

/// Generate a namespace Zig file
pub fn generateNamespace(
    allocator: std.mem.Allocator,
    namespace: types.Namespace,
    namespaces_path: []const u8,
) !void {
    // Create namespaces directory
    try std.fs.cwd().makePath(namespaces_path);

    // Create namespace file
    const output_filename = try std.fmt.allocPrint(allocator, "{s}.zig", .{namespace.name});
    defer allocator.free(output_filename);

    const output_path = try std.fs.path.join(allocator, &.{ namespaces_path, output_filename });
    defer allocator.free(output_path);

    const output_file = try std.fs.cwd().createFile(output_path, .{});
    defer output_file.close();

    var buffer: [4096]u8 = undefined;
    var file_writer = output_file.writer(&buffer);
    const w = &file_writer.interface;

    // Write header
    try w.print("//! WebIDL namespace: {s}\n", .{namespace.name});
    try w.writeAll("//!\n");
    try w.writeAll("//! This file is AUTO-GENERATED. Do not edit manually.\n");
    try w.writeAll("\n");

    // Write imports
    try w.writeAll("const runtime = @import(\"runtime\");\n");
    try w.writeAll("const webidl = @import(\"webidl\");\n");
    try w.writeAll("const v8 = @import(\"v8\");\n");
    try w.print("const {s}_impl = @import(\"impls\").{s};\n\n", .{ namespace.name, namespace.name });

    // Generate namespace as a struct with only static methods
    try w.print("pub const {s} = struct {{\n", .{namespace.name});

    // Collect operations for overload detection
    var operations = std.ArrayList(types.Operation).empty;
    defer operations.deinit(allocator);

    for (namespace.members) |member| {
        if (member.type == .operation) {
            if (member.operation) |op| {
                try operations.append(allocator, op);
            }
        }
    }

    // Group operations by name to detect overloads
    const overload_sets = try overload.groupOperationsByName(allocator, operations.items);
    defer overload.freeOverloadSets(allocator, overload_sets);

    // Generate Meta struct for V8 bindings
    try w.print("    pub const Meta = struct {{\n", .{});
    try w.print("        pub const name = \"{s}\";\n", .{namespace.name});
    try w.writeAll("        pub const is_namespace = true;\n");
    try w.writeAll("        pub const BaseType = ?*anyopaque;\n");
    try w.writeAll("        pub const MixinTypes = &.{};\n");
    try w.writeAll("        \n");
    try w.writeAll("        /// Method binding hints for V8Interface (JS name, Zig function name)\n");
    try w.writeAll("        pub const methods = .{\n");
    for (overload_sets) |set| {
        if (set.isOverloaded()) {
            // Multiple operations with same name - generate variants
            for (set.operations) |op| {
                const variant_name = try overload.generateVariantName(allocator, op);
                defer allocator.free(variant_name);
                try w.print("            .{{ \"{s}_{s}\", \"call_{s}_{s}\" }},\n", .{ set.name, variant_name, set.name, variant_name });
            }
        } else {
            try w.print("            .{{ \"{s}\", \"call_{s}\" }},\n", .{ set.name, set.name });
        }
    }
    try w.writeAll("        };\n");
    try w.writeAll("        \n");
    try w.writeAll("        pub const has_constructor = false;\n");
    try w.writeAll("        pub const properties = .{};\n");
    try w.writeAll("    };\n\n");

    // Generate empty State for V8Interface compatibility
    try w.writeAll("    pub const State = struct {};\n\n");

    // Generate operations (methods)
    for (overload_sets) |set| {
        if (set.isOverloaded()) {
            // Multiple operations with same name - generate variants
            for (set.operations) |op| {
                const variant_name = try overload.generateVariantName(allocator, op);
                defer allocator.free(variant_name);

                const full_name = try std.fmt.allocPrint(allocator, "{s}_{s}", .{ set.name, variant_name });
                defer allocator.free(full_name);

                // Prefix with call_ for JS bindings convention
                const prefixed_full_name = try std.fmt.allocPrint(allocator, "call_{s}", .{full_name});
                defer allocator.free(prefixed_full_name);

                // Escape Zig keywords in function names
                if (isZigKeyword(prefixed_full_name)) {
                    try w.print("    pub fn @\"{s}\"(ctx: runtime.Context", .{prefixed_full_name});
                } else {
                    try w.print("    pub fn {s}(ctx: runtime.Context", .{prefixed_full_name});
                }

                for (op.arguments) |arg| {
                    try w.writeAll(", ");
                    try w.print("{s}: ", .{arg.name});
                    try writeParamType(w, arg, null);
                }

                try w.writeAll(") anyerror!");
                try writeTypeSimple(w, op.idlType, null);
                try w.writeAll(" {\n");
                // Delegate to impl - use the prefixed full_name (impl has call_ prefix too)
                try w.print("        return try {s}_impl.{s}(ctx", .{ namespace.name, prefixed_full_name });
                for (op.arguments) |arg| {
                    try w.writeAll(", ");
                    try w.print("{s}", .{arg.name});
                }
                try w.writeAll(");\n");
                try w.writeAll("    }\n\n");
            }
        } else {
            // Single operation with this name
            const op = set.operations[0];
            const op_name = set.name;

            // Escape Zig keywords in function names
            // Prefix with call_ for JS bindings convention
            const prefixed_name = try std.fmt.allocPrint(allocator, "call_{s}", .{op_name});
            defer allocator.free(prefixed_name);

            if (isZigKeyword(prefixed_name)) {
                try w.print("    pub fn @\"{s}\"(ctx: runtime.Context", .{prefixed_name});
            } else {
                try w.print("    pub fn {s}(ctx: runtime.Context", .{prefixed_name});
            }

            for (op.arguments) |arg| {
                try w.writeAll(", ");
                try w.print("{s}: ", .{arg.name});
                try writeParamType(w, arg, null);
            }

            try w.writeAll(") anyerror!");
            try writeTypeSimple(w, op.idlType, null);
            try w.writeAll(" {\n");
            // Delegate to impl (use prefixed name since impl has call_ prefix too)
            if (isZigKeyword(prefixed_name)) {
                try w.print("        return try {s}_impl.@\"{s}\"(ctx", .{ namespace.name, prefixed_name });
            } else {
                try w.print("        return try {s}_impl.{s}(ctx", .{ namespace.name, prefixed_name });
            }
            for (op.arguments) |arg| {
                try w.writeAll(", ");
                try w.print("{s}", .{arg.name});
            }
            try w.writeAll(");\n");
            try w.writeAll("    }\n\n");
        }
    }

    // Generate attributes
    for (namespace.members) |member| {
        if (member.type == .attribute) {
            if (member.attribute) |attr| {
                // Namespace attributes are typically read-only
                // Escape Zig keywords in attribute names
                if (isZigKeyword(attr.name)) {
                    try w.print("    pub const @\"{s}\": ", .{attr.name});
                } else {
                    try w.print("    pub const {s}: ", .{attr.name});
                }
                try writeTypeSimple(w, attr.idlType, null);
                try w.writeAll(" = undefined;\n\n");
            }
        }
    }

    try w.writeAll("};\n");

    try w.flush();
}

/// Generate namespace implementation stub
pub fn generateNamespaceImpl(
    allocator: std.mem.Allocator,
    namespace: types.Namespace,
    impls_path: []const u8,
) !void {
    // Create impls directory
    try std.fs.cwd().makePath(impls_path);

    // Create impl file (use same naming as interfaces: {name}.zig)
    const output_filename = try std.fmt.allocPrint(allocator, "{s}.zig", .{namespace.name});
    defer allocator.free(output_filename);

    const output_path = try std.fs.path.join(allocator, &.{ impls_path, output_filename });
    defer allocator.free(output_path);

    const output_file = try std.fs.cwd().createFile(output_path, .{});
    defer output_file.close();

    var buffer: [4096]u8 = undefined;
    var file_writer = output_file.writer(&buffer);
    const w = &file_writer.interface;

    // Write header
    try w.print("//! Implementation stub for WebIDL namespace: {s}\n", .{namespace.name});
    try w.writeAll("//!\n");
    try w.writeAll("//! This file is AUTO-GENERATED. Do not edit manually.\n");
    try w.writeAll("//! Implement the functions below to provide actual functionality.\n");
    try w.writeAll("\n");

    // Write imports
    try w.writeAll("const runtime = @import(\"runtime\");\n");
    try w.writeAll("const v8 = @import(\"v8\");\n\n");

    // Collect operations for overload detection
    var operations = std.ArrayList(types.Operation).empty;
    defer operations.deinit(allocator);

    for (namespace.members) |member| {
        if (member.type == .operation) {
            if (member.operation) |op| {
                try operations.append(allocator, op);
            }
        }
    }

    // Group operations by name to detect overloads
    const overload_sets = try overload.groupOperationsByName(allocator, operations.items);
    defer overload.freeOverloadSets(allocator, overload_sets);

    // Generate operation implementations
    for (overload_sets) |set| {
        if (set.isOverloaded()) {
            // Multiple operations with same name - generate variants
            for (set.operations) |op| {
                const variant_name = try overload.generateVariantName(allocator, op);
                defer allocator.free(variant_name);

                const full_name = try std.fmt.allocPrint(allocator, "{s}_{s}", .{ set.name, variant_name });
                defer allocator.free(full_name);

                // Prefix with call_ for JS bindings convention
                const prefixed_full_name = try std.fmt.allocPrint(allocator, "call_{s}", .{full_name});
                defer allocator.free(prefixed_full_name);

                // Generate function signature
                try w.print("pub fn {s}(ctx: runtime.Context", .{prefixed_full_name});

                for (op.arguments) |arg| {
                    try w.writeAll(", ");
                    try w.print("{s}: ", .{arg.name});
                    try writeParamType(w, arg, null);
                }

                try w.writeAll(") anyerror!");
                try writeTypeSimple(w, op.idlType, null);
                try w.writeAll(" {\n");
                // Unused var suppression
                try w.writeAll("    _ = ctx;\n");
                for (op.arguments) |arg| {
                    try w.print("    _ = {s};\n", .{arg.name});
                }
                try w.writeAll("    return error.NotImplemented;\n");
                try w.writeAll("}\n\n");
            }
        } else {
            // Single operation with this name
            const op = set.operations[0];
            const op_name = set.name;

            // Prefix with call_ for JS bindings convention
            const prefixed_name = try std.fmt.allocPrint(allocator, "call_{s}", .{op_name});
            defer allocator.free(prefixed_name);

            // Generate function signature
            if (isZigKeyword(prefixed_name)) {
                try w.print("pub fn @\"{s}\"(ctx: runtime.Context", .{prefixed_name});
            } else {
                try w.print("pub fn {s}(ctx: runtime.Context", .{prefixed_name});
            }

            for (op.arguments) |arg| {
                try w.writeAll(", ");
                try w.print("{s}: ", .{arg.name});
                try writeParamType(w, arg, null);
            }

            try w.writeAll(") anyerror!");
            try writeTypeSimple(w, op.idlType, null);
            try w.writeAll(" {\n");
            // Unused var suppression
            try w.writeAll("    _ = ctx;\n");
            for (op.arguments) |arg| {
                try w.print("    _ = {s};\n", .{arg.name});
            }
            try w.writeAll("    return error.NotImplemented;\n");
            try w.writeAll("}\n\n");
        }
    }

    try w.flush();
}
