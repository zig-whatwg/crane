//! Code Generator from IR
//!
//! Generates clean, correct Zig code from EnhancedClassIR.
//!
//! Key improvements over string-based generation:
//! 1. All imports emitted once, deduplicated
//! 2. No shadowing conflicts (scope-aware)
//! 3. Proper handling of inherited methods
//! 4. Clean, maintainable output

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");
const ir = @import("ir.zig");

/// Generate Zig code from enhanced class IR
/// If module_definitions is provided, they will be included after imports
/// If post_class_definitions is provided, they will be included after the class
pub fn generateCode(
    allocator: Allocator,
    enhanced: ir.EnhancedClassIR,
    module_definitions: ?[]const u8,
    post_class_definitions: ?[]const u8,
) ![]const u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);

    const writer = output.writer(allocator);

    // Header
    try writeHeader(writer);

    // Filter module definitions first (to remove import aliases)
    const filtered_module_defs = if (module_definitions) |defs| blk: {
        if (defs.len > 0) {
            break :blk try filterModuleDefinitions(allocator, defs, enhanced.all_imports);
        } else {
            break :blk try allocator.dupe(u8, "");
        }
    } else try allocator.dupe(u8, "");
    defer allocator.free(filtered_module_defs);

    // Extract names from FILTERED definitions (not unfiltered)
    const module_def_names = if (filtered_module_defs.len > 0)
        try extractModuleDefinitionNames(allocator, filtered_module_defs)
    else
        &[_][]const u8{};
    defer {
        for (module_def_names) |name| allocator.free(name);
        if (module_def_names.len > 0) allocator.free(module_def_names);
    }

    try writeImports(writer, enhanced.all_imports, enhanced.class.own_constants, module_def_names);

    // Module-level definitions (if this is the first class in the file)
    // Note: filtered_module_defs was already computed and filtered earlier
    if (filtered_module_defs.len > 0) {
        try writer.writeAll("\n");
        try writer.writeAll(filtered_module_defs);
        try writer.writeAll("\n");
    }

    // Add helper functions needed by inherited methods
    if (needsCallbackEquals(enhanced)) {
        try writer.writeAll("\n");
        try writer.writeAll(
            \\/// Compare two callbacks for equality (from EventTarget)
            \\pub fn callbackEquals(a: ?webidl.JSValue, b: ?webidl.JSValue) bool {
            \\    if (a == null and b == null) return true;
            \\    if (a == null or b == null) return false;
            \\    const a_val = a.?;
            \\    const b_val = b.?;
            \\    if (@as(std.meta.Tag(webidl.JSValue), a_val) != @as(std.meta.Tag(webidl.JSValue), b_val)) {
            \\        return false;
            \\    }
            \\    return switch (a_val) {
            \\        .undefined, .null => true,
            \\        .boolean => |a_bool| a_bool == b_val.boolean,
            \\        .number => |a_num| a_num == b_val.number,
            \\        .string => |a_str| std.mem.eql(u8, a_str, b_val.string),
            \\        .object => |a_obj| @intFromPtr(&a_obj) == @intFromPtr(&b_val.object),
            \\        else => false,
            \\    };
            \\}
            \\
        );
    }

    try writer.writeAll("\n");

    // Class definition
    try writeClass(allocator, writer, enhanced);

    // Post-class definitions (helper types defined after the class)
    if (post_class_definitions) |post_defs| {
        if (post_defs.len > 0) {
            try writer.writeAll("\n\n");
            try writer.writeAll(post_defs);
            try writer.writeAll("\n");
        }
    }

    return output.toOwnedSlice(allocator);
}

/// Check if class needs callbackEquals helper function
fn needsCallbackEquals(enhanced: ir.EnhancedClassIR) bool {
    const class = enhanced.class;

    // EventTarget itself has it in module definitions
    if (std.mem.eql(u8, class.name, "EventTarget")) return false;

    // Check if any method uses callbackEquals
    for (enhanced.all_methods) |method| {
        if (std.mem.indexOf(u8, method.body, "callbackEquals") != null) {
            return true;
        }
    }

    return false;
}

/// Check if class needs Node constant aliases
fn needsNodeConstantAliases(enhanced: ir.EnhancedClassIR) bool {
    const class = enhanced.class;

    // Node itself doesn't need aliases
    if (std.mem.eql(u8, class.name, "Node")) return false;

    // Check if any method uses Node constants
    for (enhanced.all_methods) |method| {
        if (std.mem.indexOf(u8, method.body, "ELEMENT_NODE") != null or
            std.mem.indexOf(u8, method.body, "ATTRIBUTE_NODE") != null or
            std.mem.indexOf(u8, method.body, "DOCUMENT_NODE") != null or
            std.mem.indexOf(u8, method.body, "DOCUMENT_TYPE_NODE") != null)
        {
            return true;
        }
    }

    return false;
}

/// Write file header
fn writeHeader(writer: anytype) !void {
    try writer.writeAll(
        \\// Auto-generated by webidl-codegen (AST/IR-based)
        \\// DO NOT EDIT - changes will be overwritten
        \\//
        \\// This file was generated from the source file with the same name.
        \\// Class definitions have been enhanced with:
        \\//   - Inherited methods from parent classes
        \\//   - Property getters and setters
        \\//   - Optimized field layouts
        \\//   - Automatic import resolution
        \\
        \\
    );
}

/// Extract names of constants/types defined in module definitions
fn extractModuleDefinitionNames(allocator: Allocator, defs: []const u8) ![][]const u8 {
    var names: std.ArrayList([]const u8) = .empty;
    errdefer names.deinit(allocator);

    var lines = std.mem.splitScalar(u8, defs, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");

        // Pattern: (pub) const Name = ...
        const const_start = if (std.mem.startsWith(u8, trimmed, "pub const "))
            @as(usize, "pub const ".len)
        else if (std.mem.startsWith(u8, trimmed, "const "))
            @as(usize, "const ".len)
        else
            continue;

        const after_const = trimmed[const_start..];
        if (std.mem.indexOfAny(u8, after_const, " =:")) |end_pos| {
            const name = after_const[0..end_pos];
            if (name.len > 0) {
                try names.append(allocator, try allocator.dupe(u8, name));
            }
        }
    }

    return try names.toOwnedSlice(allocator);
}

/// Write all imports (filtered to exclude class constants and module-level definitions)
fn writeImports(writer: anytype, imports: []ir.Import, constants: []ir.Constant, module_def_names: []const []const u8) !void {
    // Debug: Check if this is MutationObserver
    const is_mutation_observer = blk: {
        for (imports) |import| {
            if (std.mem.indexOf(u8, import.name, "MutationObserver")) |_| break :blk true;
        }
        break :blk false;
    };

    if (is_mutation_observer) {
        std.debug.print("\n=== MutationObserver Imports List ===\n", .{});
        for (imports, 0..) |import, i| {
            std.debug.print("[{d}] name=[{s}] module=[{s}]\n", .{ i, import.name, import.module });
        }
        std.debug.print("module_def_names.len={d}\n", .{module_def_names.len});
        for (module_def_names, 0..) |name, i| {
            std.debug.print("  [{d}] {s}\n", .{ i, name });
        }
        std.debug.print("=== END ===\n", .{});
    }

    // Build set of names to exclude from imports
    var excluded_names = std.StringHashMap(void).init(std.heap.page_allocator);
    defer excluded_names.deinit();

    // Exclude class constant names
    for (constants) |constant| {
        try excluded_names.put(constant.name, {});
    }

    // Exclude module definition names
    for (module_def_names) |name| {
        try excluded_names.put(name, {});
    }

    // Sort imports by name for consistent output
    var sorted_imports: std.ArrayList(ir.Import) = .empty;
    defer sorted_imports.deinit(std.heap.page_allocator);

    for (imports) |import| {
        // Skip imports that match excluded names
        if (excluded_names.contains(import.name)) {
            continue;
        }
        try sorted_imports.append(std.heap.page_allocator, import);
    }

    // Simple bubble sort (small lists)
    var i: usize = 0;
    while (i < sorted_imports.items.len) : (i += 1) {
        var j: usize = i + 1;
        while (j < sorted_imports.items.len) : (j += 1) {
            if (std.mem.order(u8, sorted_imports.items[i].name, sorted_imports.items[j].name) == .gt) {
                const temp = sorted_imports.items[i];
                sorted_imports.items[i] = sorted_imports.items[j];
                sorted_imports.items[j] = temp;
            }
        }
    }

    // Write sorted imports
    for (sorted_imports.items) |import| {
        const vis = if (import.visibility == .public) "pub " else "";

        // Special case: std.mem aliases (Allocator, ArrayList, etc.)
        // These should be written as: const Allocator = std.mem.Allocator;
        if (std.mem.eql(u8, import.module, "std.mem")) {
            try writer.print("{s}const {s} = std.mem.{s};\n", .{
                vis,
                import.name,
                import.name,
            });
            continue;
        }

        // Heuristic: Determine if this is a module import vs type import
        // Module imports: const std = @import("std"), const common = @import("common")
        // Type imports: const Foo = @import("foo").Foo
        // Special case: const FooModule = @import("foo") (module with "Module" suffix)
        const name_is_lowercase = import.name.len > 0 and import.name[0] >= 'a' and import.name[0] <= 'z';
        const ends_with_module = std.mem.endsWith(u8, import.name, "Module");
        const is_module_import = !import.is_type or name_is_lowercase or ends_with_module;

        if (!is_module_import and import.is_type) {
            // Type import: const Foo = @import("foo").Foo;
            try writer.print("{s}const {s} = @import(\"{s}\").{s};\n", .{
                vis,
                import.name,
                import.module,
                import.name,
            });
        } else {
            // Module import: const std = @import("std");
            try writer.print("{s}const {s} = @import(\"{s}\");\n", .{
                vis,
                import.name,
                import.module,
            });
        }
    }

    try writer.writeAll("\n");
}

/// Write class definition
fn writeClass(allocator: Allocator, writer: anytype, enhanced: ir.EnhancedClassIR) !void {
    const class = enhanced.class;

    // Class doc comment
    if (class.doc_comment) |doc| {
        var lines = std.mem.splitScalar(u8, doc, '\n');
        while (lines.next()) |line| {
            try writer.print("/// {s}\n", .{line});
        }
    }

    // Class declaration
    try writer.print("pub const {s} = struct {{\n", .{class.name});

    // Fields
    // Write struct fields (mixin + own, but not parent inherited)
    // Mixin fields must be written because mixins are composition (includes)
    // Parent fields are not written because Zig doesn't support field inheritance
    if (enhanced.struct_fields.len > 0) {
        try writer.writeAll("    // ========================================================================\n");
        try writer.writeAll("    // Fields\n");
        try writer.writeAll("    // ========================================================================\n\n");
        for (enhanced.struct_fields) |field| {
            if (field.doc_comment) |doc| {
                try writer.print("    /// {s}\n", .{doc});
            }
            try writer.print("    {s}: {s},\n", .{ field.name, field.type_name });
        }
    }

    // Constants
    const has_constants = class.own_constants.len > 0;
    const needs_node_constants = needsNodeConstantAliases(enhanced);

    if (has_constants or needs_node_constants) {
        try writer.writeAll("\n    // ========================================================================\n");
        try writer.writeAll("    // Constants\n");
        try writer.writeAll("    // ========================================================================\n\n");

        // Own constants
        for (class.own_constants) |constant| {
            try writer.print("    {s}const {s}", .{ constant.visibility.toString(), constant.name });
            if (constant.type_name) |type_name| {
                try writer.print(": {s}", .{type_name});
            }
            try writer.print(" = {s};\n", .{constant.value});
        }

        // Node constant aliases (for classes inheriting from Node)
        if (needs_node_constants and !std.mem.eql(u8, class.name, "Node")) {
            if (has_constants) try writer.writeAll("\n");
            try writer.writeAll("    // Node type constants (inherited)\n");
            try writer.writeAll("    pub const ELEMENT_NODE: u16 = Node.ELEMENT_NODE;\n");
            try writer.writeAll("    pub const ATTRIBUTE_NODE: u16 = Node.ATTRIBUTE_NODE;\n");
            try writer.writeAll("    pub const TEXT_NODE: u16 = Node.TEXT_NODE;\n");
            try writer.writeAll("    pub const CDATA_SECTION_NODE: u16 = Node.CDATA_SECTION_NODE;\n");
            try writer.writeAll("    pub const PROCESSING_INSTRUCTION_NODE: u16 = Node.PROCESSING_INSTRUCTION_NODE;\n");
            try writer.writeAll("    pub const COMMENT_NODE: u16 = Node.COMMENT_NODE;\n");
            try writer.writeAll("    pub const DOCUMENT_NODE: u16 = Node.DOCUMENT_NODE;\n");
            try writer.writeAll("    pub const DOCUMENT_TYPE_NODE: u16 = Node.DOCUMENT_TYPE_NODE;\n");
            try writer.writeAll("    pub const DOCUMENT_FRAGMENT_NODE: u16 = Node.DOCUMENT_FRAGMENT_NODE;\n");
        }
    }

    // WebIDL Metadata
    try writer.writeAll("\n    // ========================================================================\n");
    try writer.writeAll("    // WebIDL Metadata\n");
    try writer.writeAll("    // ========================================================================\n\n");
    try writer.writeAll("    pub const __webidl__ = .{\n");
    try writer.print("        .name = \"{s}\",\n", .{class.name});

    const kind_str = switch (class.kind) {
        .interface => "interface",
        .namespace => "namespace",
        .mixin => "mixin",
    };
    try writer.print("        .kind = .{s},\n", .{kind_str});
    try writer.writeAll("    };\n");

    // Methods
    if (enhanced.all_methods.len > 0) {
        try writer.writeAll("\n    // ========================================================================\n");
        try writer.writeAll("    // Methods\n");
        try writer.writeAll("    // ========================================================================\n\n");

        for (enhanced.all_methods) |method| {
            try writeMethod(allocator, writer, method, enhanced.all_imports, class.name);
            try writer.writeAll("\n");
        }
    }

    try writer.writeAll("};\n");
}

/// Rewrite self parameter type in method signature for mixin inheritance
/// Example: (self: *ReadableStreamGenericReader, ...) -> (self: *ReadableStreamBYOBReader, ...)
/// Also handles: (self: *const ReadableStreamGenericReader, ...) -> (self: *const ReadableStreamBYOBReader, ...)
/// And: (self: *const @This()) -> (self: *const TargetClass)
fn rewriteSelfParameterType(allocator: Allocator, signature: []const u8, target_class: []const u8) ![]const u8 {
    // Find "self: " pattern in signature
    const self_pattern = "self: ";
    const self_start = std.mem.indexOf(u8, signature, self_pattern) orelse {
        // No self parameter - return unchanged
        return signature;
    };

    var cursor = self_start + self_pattern.len;

    // Skip pointer syntax: * or *const
    if (cursor < signature.len and signature[cursor] == '*') {
        cursor += 1;
        // Check for "const " after the *
        if (cursor + 6 < signature.len and std.mem.startsWith(u8, signature[cursor..], "const ")) {
            cursor += 6; // "const "
        }
    }

    const type_start = cursor;

    // Check for @This() special case
    var type_end = type_start;
    if (std.mem.startsWith(u8, signature[type_start..], "@This()")) {
        type_end = type_start + "@This()".len;
    } else {
        // Find the end of the type name (next comma, paren, or whitespace)
        while (type_end < signature.len) : (type_end += 1) {
            const c = signature[type_end];
            if (c == ',' or c == ')' or c == ' ' or c == '\t' or c == '\n') {
                break;
            }
        }
    }

    const original_type = signature[type_start..type_end];

    // If the type is already the target class, no rewrite needed
    if (std.mem.eql(u8, original_type, target_class)) {
        return signature;
    }

    // Build rewritten signature
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    try result.appendSlice(allocator, signature[0..type_start]); // Up to and including "self: *" or "self: *const "
    try result.appendSlice(allocator, target_class); // New type name
    try result.appendSlice(allocator, signature[type_end..]); // Rest of signature (including closing paren if @This())

    return try result.toOwnedSlice(allocator);
}

/// Write a single method
fn writeMethod(allocator: Allocator, writer: anytype, method: ir.Method, top_level_imports: []ir.Import, class_name: []const u8) !void {
    // Doc comment
    if (method.doc_comment) |doc| {
        var lines = std.mem.splitScalar(u8, doc, '\n');
        while (lines.next()) |line| {
            try writer.print("    /// {s}\n", .{line});
        }
    }

    // Method signature - rewrite self parameter type for mixin methods
    const rewritten_signature = try rewriteSelfParameterType(allocator, method.signature, class_name);
    defer if (rewritten_signature.ptr != method.signature.ptr) allocator.free(rewritten_signature);

    const pub_str = if (method.modifiers.is_public) "pub " else "";
    const inline_str = if (method.modifiers.is_inline) "inline " else "";

    try writer.print("    {s}{s}fn {s}{s} {{\n", .{
        pub_str,
        inline_str,
        method.name,
        rewritten_signature,
    });

    // Method body - strip local imports that shadow top-level imports or the current class
    const cleaned_body = try stripShadowingImports(allocator, method.body, top_level_imports, class_name);
    defer if (cleaned_body.ptr != method.body.ptr) allocator.free(cleaned_body);
    try writer.writeAll(cleaned_body);

    try writer.writeAll("\n    }\n");
}

/// Remove local imports from method body if they shadow top-level imports or the current class
/// Example: removes `const DocumentType = @import("document_type").DocumentType;`
/// if DocumentType is already imported at file level OR if it's the current class name
fn stripShadowingImports(allocator: Allocator, body: []const u8, top_level_imports: []ir.Import, class_name: []const u8) ![]const u8 {
    // Build set of imported names
    var imported_names = std.StringHashMap(void).init(allocator);
    defer imported_names.deinit();

    for (top_level_imports) |import| {
        try imported_names.put(import.name, {});
    }

    // Also add the current class name to prevent self-reference shadowing
    try imported_names.put(class_name, {});

    // Scan for local imports: `const Name = @import("...")`
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    var pos: usize = 0;
    while (pos < body.len) {
        // Look for pattern: const Name = @import(
        const const_pos = std.mem.indexOfPos(u8, body, pos, "const ") orelse {
            // No more consts, append rest
            try result.appendSlice(allocator, body[pos..]);
            break;
        };

        // Append everything before this const
        try result.appendSlice(allocator, body[pos..const_pos]);

        // Check if this is an import statement
        const after_const = const_pos + "const ".len;
        const eq_pos = std.mem.indexOfScalarPos(u8, body, after_const, '=') orelse {
            // No = sign, not an import, keep it
            try result.appendSlice(allocator, "const ");
            pos = after_const;
            continue;
        };

        const name_end = eq_pos;
        // Trim whitespace
        var name_start = after_const;
        while (name_start < name_end and std.ascii.isWhitespace(body[name_start])) : (name_start += 1) {}
        var name_end_trimmed = name_end;
        while (name_end_trimmed > name_start and std.ascii.isWhitespace(body[name_end_trimmed - 1])) : (name_end_trimmed -= 1) {}

        const name = body[name_start..name_end_trimmed];

        // Check if this is an @import statement
        const after_eq = eq_pos + 1;
        const import_pos = std.mem.indexOfPos(u8, body, after_eq, "@import(") orelse {
            // Not an import, keep it
            try result.appendSlice(allocator, body[const_pos..after_eq]);
            pos = after_eq;
            continue;
        };

        // This is a const Name = @import(...); statement
        // Find the semicolon
        const semicolon_pos = std.mem.indexOfScalarPos(u8, body, import_pos, ';') orelse {
            // No semicolon found, keep it
            try result.appendSlice(allocator, body[const_pos..]);
            pos = body.len;
            break;
        };

        // Check if this name is already imported at top level
        if (imported_names.contains(name)) {
            // Skip this entire line (it shadows a top-level import)
            // Find the end of the line
            const newline_pos = std.mem.indexOfScalarPos(u8, body, semicolon_pos, '\n') orelse body.len;
            pos = newline_pos;
            if (pos < body.len and body[pos] == '\n') pos += 1; // Skip the newline
        } else {
            // Keep this import (not shadowing)
            try result.appendSlice(allocator, body[const_pos .. semicolon_pos + 1]);
            pos = semicolon_pos + 1;
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Filter module definitions to remove type aliases that duplicate top-level imports
/// Example: removes `const Allocator = std.mem.Allocator;` if Allocator is already imported
fn filterModuleDefinitions(allocator: Allocator, defs: []const u8, top_level_imports: []ir.Import) ![]const u8 {
    // Build set of imported names
    var imported_names = std.StringHashMap(void).init(allocator);
    defer imported_names.deinit();

    for (top_level_imports) |import| {
        try imported_names.put(import.name, {});
    }

    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    // Process line by line
    var lines = std.mem.splitScalar(u8, defs, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");

        // Check if this is a type alias that duplicates an import
        // Pattern: const Name = SomeOtherType; (NOT const Name = struct/enum/union)
        var should_skip = false;

        if (std.mem.startsWith(u8, trimmed, "const ") or std.mem.startsWith(u8, trimmed, "pub const ")) {
            const after_const = if (std.mem.startsWith(u8, trimmed, "pub const "))
                trimmed["pub const ".len..]
            else
                trimmed["const ".len..];

            // Extract the name (before =)
            if (std.mem.indexOfScalar(u8, after_const, '=')) |eq_pos| {
                const name = std.mem.trim(u8, after_const[0..eq_pos], " \t\r");

                // Check if this name is already imported
                if (imported_names.contains(name)) {
                    // Check if the value is NOT a struct/enum/union definition
                    const after_eq = std.mem.trim(u8, after_const[eq_pos + 1 ..], " \t\r");
                    const is_type_def = std.mem.startsWith(u8, after_eq, "struct {") or
                        std.mem.startsWith(u8, after_eq, "enum {") or
                        std.mem.startsWith(u8, after_eq, "union(");

                    if (!is_type_def) {
                        // This is a type alias for an already-imported name, skip it
                        should_skip = true;
                    }
                }
            }
        }

        if (!should_skip) {
            try result.appendSlice(allocator, line);
            try result.append(allocator, '\n');
        }
    }

    // Trim trailing whitespace
    const full_result = try result.toOwnedSlice(allocator);
    const trimmed_result = std.mem.trim(u8, full_result, " \t\r\n");
    const final = try allocator.dupe(u8, trimmed_result);
    allocator.free(full_result);

    return final;
}
