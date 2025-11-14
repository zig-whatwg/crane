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
    var output = infra.List(u8).init(allocator);
    errdefer output.deinit();

    const writer = output.writer();

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

    return output.toOwnedSlice();
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
    var names = infra.List([]const u8).init(allocator);
    errdefer names.deinit();

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
                try names.append(try allocator.dupe(u8, name));
            }
        }
    }

    return try names.toOwnedSlice();
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
    var sorted_imports = infra.List(ir.Import).init(std.heap.page_allocator);
    defer sorted_imports.deinit();

    for (imports) |import| {
        // Skip imports that match excluded names
        if (excluded_names.contains(import.name)) {
            continue;
        }
        try sorted_imports.append(import);
    }

    // Simple bubble sort (small lists)
    var i: usize = 0;
    while (i < sorted_imports.len) : (i += 1) {
        var j: usize = i + 1;
        while (j < sorted_imports.len) : (j += 1) {
            const name_i = sorted_imports.get(i).?.name;
            const name_j = sorted_imports.get(j).?.name;
            if (std.mem.order(u8, name_i, name_j) == .gt) {
                const temp = sorted_imports.get(i).?;
                sorted_imports.toSliceMut()[i] = sorted_imports.get(j).?;
                sorted_imports.toSliceMut()[j] = temp;
            }
        }
    }

    // Write sorted imports
    for (0..sorted_imports.len) |idx| {
        const import = sorted_imports.get(idx).?;
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
                var lines = std.mem.splitScalar(u8, doc, '\n');
                while (lines.next()) |line| {
                    try writer.print("    /// {s}\n", .{line});
                }
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
            try writeMethod(allocator, writer, method, enhanced.all_imports, class.name, enhanced.struct_fields);
            try writer.writeAll("\n");
        }
    }

    // Type Conversion Helpers (Downcast Methods)
    try writeDowncastHelpers(allocator, writer, enhanced);

    try writer.writeAll("};\n");
}

/// Generate type conversion helper methods for safe downcasting
/// Only generates for Node and its descendants (uses node_type discriminator)
fn writeDowncastHelpers(allocator: Allocator, writer: anytype, enhanced: ir.EnhancedClassIR) !void {
    _ = allocator;
    const class = enhanced.class;

    // Only generate for Node and classes that inherit from Node
    const inherits_from_node = blk: {
        if (std.mem.eql(u8, class.name, "Node")) break :blk true;

        // Check if this class or any parent is Node
        const current_parent = class.parent;
        while (current_parent) |parent_name| {
            if (std.mem.eql(u8, parent_name, "Node")) break :blk true;
            // For simplicity, we'll check direct parent only
            // A more complete solution would traverse the full hierarchy
            break;
        }
        break :blk false;
    };

    if (!inherits_from_node) return;

    // Only Node itself gets the downcast helpers
    // (Children inherit them through flattened inheritance)
    if (!std.mem.eql(u8, class.name, "Node")) return;

    try writer.writeAll("\n    // ========================================================================\n");
    try writer.writeAll("    // Type Conversion Helpers (Safe Downcasting)\n");
    try writer.writeAll("    // ========================================================================\n");
    try writer.writeAll("    // With flattened inheritance, we need runtime type checking to safely\n");
    try writer.writeAll("    // downcast from Node to more specific types.\n\n");

    // CharacterData downcast (TEXT, COMMENT, CDATA_SECTION, PROCESSING_INSTRUCTION)
    try writer.writeAll("    /// Safe downcast to CharacterData (returns null if not a CharacterData node)\n");
    try writer.writeAll("    pub fn asCharacterData(self: *Node) ?*CharacterData {\n");
    try writer.writeAll("        return switch (self.node_type) {\n");
    try writer.writeAll("            TEXT_NODE,\n");
    try writer.writeAll("            COMMENT_NODE,\n");
    try writer.writeAll("            CDATA_SECTION_NODE,\n");
    try writer.writeAll("            PROCESSING_INSTRUCTION_NODE => @ptrCast(@alignCast(self)),\n");
    try writer.writeAll("            else => null,\n");
    try writer.writeAll("        };\n");
    try writer.writeAll("    }\n\n");

    try writer.writeAll("    /// Safe const downcast to CharacterData\n");
    try writer.writeAll("    pub fn asCharacterDataConst(self: *const Node) ?*const CharacterData {\n");
    try writer.writeAll("        return switch (self.node_type) {\n");
    try writer.writeAll("            TEXT_NODE,\n");
    try writer.writeAll("            COMMENT_NODE,\n");
    try writer.writeAll("            CDATA_SECTION_NODE,\n");
    try writer.writeAll("            PROCESSING_INSTRUCTION_NODE => @ptrCast(@alignCast(self)),\n");
    try writer.writeAll("            else => null,\n");
    try writer.writeAll("        };\n");
    try writer.writeAll("    }\n\n");

    // Element downcast
    try writer.writeAll("    /// Safe downcast to Element (returns null if not an Element node)\n");
    try writer.writeAll("    pub fn asElement(self: *Node) ?*Element {\n");
    try writer.writeAll("        return if (self.node_type == ELEMENT_NODE) @ptrCast(@alignCast(self)) else null;\n");
    try writer.writeAll("    }\n\n");

    try writer.writeAll("    /// Safe const downcast to Element\n");
    try writer.writeAll("    pub fn asElementConst(self: *const Node) ?*const Element {\n");
    try writer.writeAll("        return if (self.node_type == ELEMENT_NODE) @ptrCast(@alignCast(self)) else null;\n");
    try writer.writeAll("    }\n\n");

    // Document downcast
    try writer.writeAll("    /// Safe downcast to Document (returns null if not a Document node)\n");
    try writer.writeAll("    pub fn asDocument(self: *Node) ?*Document {\n");
    try writer.writeAll("        return if (self.node_type == DOCUMENT_NODE) @ptrCast(@alignCast(self)) else null;\n");
    try writer.writeAll("    }\n\n");

    try writer.writeAll("    /// Safe const downcast to Document\n");
    try writer.writeAll("    pub fn asDocumentConst(self: *const Node) ?*const Document {\n");
    try writer.writeAll("        return if (self.node_type == DOCUMENT_NODE) @ptrCast(@alignCast(self)) else null;\n");
    try writer.writeAll("    }\n\n");

    // DocumentFragment downcast
    try writer.writeAll("    /// Safe downcast to DocumentFragment (returns null if not a DocumentFragment node)\n");
    try writer.writeAll("    pub fn asDocumentFragment(self: *Node) ?*DocumentFragment {\n");
    try writer.writeAll("        return if (self.node_type == DOCUMENT_FRAGMENT_NODE) @ptrCast(@alignCast(self)) else null;\n");
    try writer.writeAll("    }\n\n");

    try writer.writeAll("    /// Safe const downcast to DocumentFragment\n");
    try writer.writeAll("    pub fn asDocumentFragmentConst(self: *const Node) ?*const DocumentFragment {\n");
    try writer.writeAll("        return if (self.node_type == DOCUMENT_FRAGMENT_NODE) @ptrCast(@alignCast(self)) else null;\n");
    try writer.writeAll("    }\n\n");

    // Text downcast
    try writer.writeAll("    /// Safe downcast to Text (returns null if not a Text node)\n");
    try writer.writeAll("    pub fn asText(self: *Node) ?*Text {\n");
    try writer.writeAll("        return if (self.node_type == TEXT_NODE) @ptrCast(@alignCast(self)) else null;\n");
    try writer.writeAll("    }\n\n");

    try writer.writeAll("    /// Safe const downcast to Text\n");
    try writer.writeAll("    pub fn asTextConst(self: *const Node) ?*const Text {\n");
    try writer.writeAll("        return if (self.node_type == TEXT_NODE) @ptrCast(@alignCast(self)) else null;\n");
    try writer.writeAll("    }\n\n");

    // Attr downcast
    try writer.writeAll("    /// Safe downcast to Attr (returns null if not an Attr node)\n");
    try writer.writeAll("    pub fn asAttr(self: *Node) ?*Attr {\n");
    try writer.writeAll("        return if (self.node_type == ATTRIBUTE_NODE) @ptrCast(@alignCast(self)) else null;\n");
    try writer.writeAll("    }\n\n");

    try writer.writeAll("    /// Safe const downcast to Attr\n");
    try writer.writeAll("    pub fn asAttrConst(self: *const Node) ?*const Attr {\n");
    try writer.writeAll("        return if (self.node_type == ATTRIBUTE_NODE) @ptrCast(@alignCast(self)) else null;\n");
    try writer.writeAll("    }\n\n");
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
    var result = infra.List(u8).init(allocator);
    defer result.deinit();

    try result.appendSlice(signature[0..type_start]); // Up to and including "self: *" or "self: *const "
    try result.appendSlice(target_class); // New type name
    try result.appendSlice(signature[type_end..]); // Rest of signature (including closing paren if @This())

    return try result.toOwnedSlice();
}

/// Synthesize init method body from field init expressions
fn synthesizeInitMethod(
    allocator: Allocator,
    struct_fields: []ir.Field,
    method_signature: []const u8,
    class_name: []const u8,
) ![]const u8 {
    var body = infra.List(u8).init(allocator);
    errdefer body.deinit();
    const writer = body.writer();

    // Parse parameters from signature to know what's available
    const params = try parseInitParameters(allocator, method_signature);
    defer {
        for (params) |param| {
            allocator.free(param.name);
            allocator.free(param.type_name);
        }
        allocator.free(params);
    }

    try writer.writeAll("\n        return .{\n");

    // For each field, generate initialization code
    for (struct_fields) |field| {
        const init_code = if (field.init_expr) |expr|
            try generateInitCodeFromExpression(allocator, expr, params, class_name)
        else
            try inferDefaultInit(allocator, field.type_name, params, class_name);

        defer allocator.free(init_code);

        try writer.print("            .{s} = {s},\n", .{ field.name, init_code });
    }

    try writer.writeAll("        };\n    ");

    return body.toOwnedSlice();
}

/// Parameter info extracted from init signature
const InitParameter = struct {
    name: []const u8,
    type_name: []const u8,
};

/// Parse init method parameters from signature
fn parseInitParameters(allocator: Allocator, signature: []const u8) ![]InitParameter {
    var params_list = infra.List(InitParameter).init(allocator);
    errdefer {
        for (params_list.toSliceMut()) |param| {
            allocator.free(param.name);
            allocator.free(param.type_name);
        }
        params_list.deinit();
    }

    // Find parameter list: (param1: Type1, param2: Type2) !ReturnType
    const paren_start = std.mem.indexOf(u8, signature, "(") orelse return params_list.toOwnedSlice();
    const paren_end = std.mem.indexOf(u8, signature[paren_start..], ")") orelse return params_list.toOwnedSlice();
    const params_str = signature[paren_start + 1 .. paren_start + paren_end];

    // Split by comma (accounting for nested generics)
    var pos: usize = 0;
    var param_start: usize = 0;
    var angle_depth: i32 = 0;

    while (pos < params_str.len) : (pos += 1) {
        if (params_str[pos] == '<') angle_depth += 1;
        if (params_str[pos] == '>') angle_depth -= 1;

        if (params_str[pos] == ',' and angle_depth == 0) {
            const param_str = std.mem.trim(u8, params_str[param_start..pos], " \t\n\r");
            if (param_str.len > 0) {
                if (try parseParameter(allocator, param_str)) |param| {
                    try params_list.append(param);
                }
            }
            param_start = pos + 1;
        }
    }

    // Last parameter
    const param_str = std.mem.trim(u8, params_str[param_start..], " \t\n\r");
    if (param_str.len > 0) {
        if (try parseParameter(allocator, param_str)) |param| {
            try params_list.append(param);
        }
    }

    return params_list.toOwnedSlice();
}

/// Parse a single parameter: "name: Type"
fn parseParameter(allocator: Allocator, param_str: []const u8) !?InitParameter {
    const colon_pos = std.mem.indexOf(u8, param_str, ":") orelse return null;

    const name = std.mem.trim(u8, param_str[0..colon_pos], " \t");
    const type_name = std.mem.trim(u8, param_str[colon_pos + 1 ..], " \t");

    return InitParameter{
        .name = try allocator.dupe(u8, name),
        .type_name = try allocator.dupe(u8, type_name),
    };
}

/// Generate init code from an InitExpression
fn generateInitCodeFromExpression(
    allocator: Allocator,
    expr: ir.Field.InitExpression,
    params: []InitParameter,
    class_name: []const u8,
) ![]const u8 {
    return switch (expr) {
        .literal => |lit| try allocator.dupe(u8, lit),

        .function_call => |fc| blk: {
            var code = infra.List(u8).init(allocator);
            defer code.deinit();

            try code.appendSlice(fc.function);
            try code.append('(');
            for (fc.args, 0..) |arg, i| {
                if (i > 0) try code.appendSlice(", ");
                try code.appendSlice(arg);
            }
            try code.append(')');

            break :blk try code.toOwnedSlice();
        },

        .constant_ref => |cr| try allocator.dupe(u8, cr),

        .parameter => |p| blk: {
            // Verify parameter exists
            for (params) |param| {
                if (std.mem.eql(u8, param.name, p)) {
                    break :blk try allocator.dupe(u8, p);
                }
            }
            // Parameter not found in current signature - use class-specific defaults
            // This happens when a child class inherits a field that was initialized
            // from a parameter in the parent's init, but child's init doesn't have that param
            if (std.mem.eql(u8, p, "node_type")) {
                break :blk try getDefaultNodeType(allocator, class_name);
            } else if (std.mem.eql(u8, p, "node_name")) {
                break :blk try getDefaultNodeName(allocator, class_name);
            }
            // Fallback: assume it's available (will cause compile error if not, which is good)
            break :blk try allocator.dupe(u8, p);
        },

        .complex => |c| try allocator.dupe(u8, c),
    };
}

/// Get default node_type for a class
fn getDefaultNodeType(allocator: Allocator, class_name: []const u8) ![]const u8 {
    // Map class names to their node types
    if (std.mem.eql(u8, class_name, "Document")) {
        return try allocator.dupe(u8, "Node.DOCUMENT_NODE");
    } else if (std.mem.eql(u8, class_name, "DocumentType")) {
        return try allocator.dupe(u8, "Node.DOCUMENT_TYPE_NODE");
    } else if (std.mem.eql(u8, class_name, "DocumentFragment")) {
        return try allocator.dupe(u8, "Node.DOCUMENT_FRAGMENT_NODE");
    } else if (std.mem.eql(u8, class_name, "CharacterData")) {
        // CharacterData is abstract, should not be instantiated directly
        // But if it is, use a safe default
        return try allocator.dupe(u8, "Node.TEXT_NODE");
    }
    // Default: 0 (will cause compile error if wrong, which is good)
    return try allocator.dupe(u8, "0");
}

/// Get default node_name for a class
fn getDefaultNodeName(allocator: Allocator, class_name: []const u8) ![]const u8 {
    // Map class names to their node names
    if (std.mem.eql(u8, class_name, "Document")) {
        return try allocator.dupe(u8, "\"#document\"");
    } else if (std.mem.eql(u8, class_name, "DocumentFragment")) {
        return try allocator.dupe(u8, "\"#document-fragment\"");
    } else if (std.mem.eql(u8, class_name, "CharacterData")) {
        return try allocator.dupe(u8, "\"#text\"");
    }
    // Default: empty string
    return try allocator.dupe(u8, "\"\"");
}

/// Infer default initialization for a field type
fn inferDefaultInit(
    allocator: Allocator,
    type_name: []const u8,
    params: []InitParameter,
    class_name: []const u8,
) ![]const u8 {
    _ = params; // May use params for smarter inference later
    _ = class_name; // May use class_name for smarter inference later

    // Optional types → null
    if (type_name.len > 0 and type_name[0] == '?') {
        return try allocator.dupe(u8, "null");
    }

    // Lists → List.init(allocator)
    if (std.mem.indexOf(u8, type_name, "infra.List(") != null or
        std.mem.indexOf(u8, type_name, "List(") != null)
    {
        return try std.fmt.allocPrint(allocator, "{s}.init(allocator)", .{type_name});
    }

    // Integers → 0
    if (std.mem.eql(u8, type_name, "u8") or
        std.mem.eql(u8, type_name, "u16") or
        std.mem.eql(u8, type_name, "u32") or
        std.mem.eql(u8, type_name, "u64") or
        std.mem.eql(u8, type_name, "usize") or
        std.mem.eql(u8, type_name, "i8") or
        std.mem.eql(u8, type_name, "i16") or
        std.mem.eql(u8, type_name, "i32") or
        std.mem.eql(u8, type_name, "i64") or
        std.mem.eql(u8, type_name, "isize"))
    {
        return try allocator.dupe(u8, "0");
    }

    // Booleans → false
    if (std.mem.eql(u8, type_name, "bool")) {
        return try allocator.dupe(u8, "false");
    }

    // Strings → ""
    if (std.mem.eql(u8, type_name, "[]const u8") or
        std.mem.eql(u8, type_name, "[]u8"))
    {
        return try allocator.dupe(u8, "\"\"");
    }

    // std.Thread.Mutex → {}
    if (std.mem.indexOf(u8, type_name, "std.Thread.Mutex") != null or
        std.mem.indexOf(u8, type_name, "Thread.Mutex") != null or
        std.mem.indexOf(u8, type_name, "Mutex") != null)
    {
        return try std.fmt.allocPrint(allocator, "{s}{{}}", .{type_name});
    }

    // HashMaps → HashMap.init(allocator)
    if (std.mem.indexOf(u8, type_name, "HashMap") != null or
        std.mem.indexOf(u8, type_name, "StringHashMap") != null)
    {
        return try std.fmt.allocPrint(allocator, "{s}.init(allocator)", .{type_name});
    }

    // Default: null for complex types (likely pointers or optionals)
    return try allocator.dupe(u8, "null");
}

/// Write a single method
fn writeMethod(
    allocator: Allocator,
    writer: anytype,
    method: ir.Method,
    top_level_imports: []ir.Import,
    class_name: []const u8,
    struct_fields: []ir.Field,
) !void {
    // Doc comment
    if (method.doc_comment) |doc| {
        var lines = std.mem.splitScalar(u8, doc, '\n');
        while (lines.next()) |line| {
            try writer.print("    /// {s}\n", .{line});
        }
    }

    // Method signature - rewrite self parameter type for inherited and mixin methods
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

    // Check if this is an init method - only synthesize if body is empty/missing
    // If the source file has a custom init implementation, preserve it
    const should_synthesize_init = std.mem.eql(u8, method.name, "init") and
        std.mem.trim(u8, method.body, " \t\n\r").len == 0;

    if (should_synthesize_init) {
        const synthesized_body = try synthesizeInitMethod(allocator, struct_fields, method.signature, class_name);
        defer allocator.free(synthesized_body);

        try writer.writeAll(synthesized_body);
        try writer.writeAll("\n    }\n");
        return; // Early return - synthesized init replaces original body
    }

    // Check if this is an inherited method (signature was rewritten)
    const is_inherited = rewritten_signature.ptr != method.signature.ptr;

    if (is_inherited) {
        // For inherited methods, add a @ptrCast at the start to convert self to parent type
        // Extract the original parent type from the method signature
        const parent_type_info = try extractSelfTypeInfo(allocator, method.signature);
        defer if (parent_type_info) |pti| {
            if (pti.type_name) |tn| allocator.free(tn);
        };

        if (parent_type_info) |pti| {
            if (pti.type_name) |pt| {
                // Rewrite body to use self_parent for field access, self for method calls
                const rewritten_body = try rewriteSelfReferences(allocator, method.body, "self_parent");
                defer allocator.free(rewritten_body);

                // Check if self_parent is actually used in the rewritten body
                const needs_self_parent = std.mem.indexOf(u8, rewritten_body, "self_parent") != null;

                // Only declare self_parent if it's actually used (for field access)
                if (needs_self_parent) {
                    // Cast self to parent type for method body
                    // This works because flattened fields guarantee compatible memory layout
                    if (pti.has_pointer) {
                        // Check if the rewritten signature has const to preserve it
                        const is_const = std.mem.indexOf(u8, rewritten_signature, "self: *const ") != null;
                        if (is_const and pti.has_const) {
                            try writer.print("        const self_parent: *const {s} = @ptrCast(self);\n", .{pt});
                        } else if (is_const and !pti.has_const) {
                            // Parent was not const, but child is - need @constCast
                            try writer.print("        const self_parent: *{s} = @ptrCast(@constCast(self));\n", .{pt});
                        } else if (!is_const and pti.has_const) {
                            // Parent was const, child is not - preserve const
                            try writer.print("        const self_parent: *const {s} = @ptrCast(self);\n", .{pt});
                        } else {
                            try writer.print("        const self_parent: *{s} = @ptrCast(self);\n", .{pt});
                        }
                    } else {
                        // Non-pointer self (e.g., self: anytype) - no cast needed, just rename
                        try writer.print("        const self_parent = self;\n", .{});
                    }
                }

                const cleaned_body = try stripShadowingImports(allocator, rewritten_body, top_level_imports, class_name);
                defer if (cleaned_body.ptr != rewritten_body.ptr) allocator.free(cleaned_body);
                try writer.writeAll(cleaned_body);
            } else {
                // No type name extracted - use body as-is
                const cleaned_body = try stripShadowingImports(allocator, method.body, top_level_imports, class_name);
                defer if (cleaned_body.ptr != method.body.ptr) allocator.free(cleaned_body);
                try writer.writeAll(cleaned_body);
            }
        } else {
            // Fallback: use body as-is
            const cleaned_body = try stripShadowingImports(allocator, method.body, top_level_imports, class_name);
            defer if (cleaned_body.ptr != method.body.ptr) allocator.free(cleaned_body);
            try writer.writeAll(cleaned_body);
        }
    } else {
        // Own method - use body as-is
        const cleaned_body = try stripShadowingImports(allocator, method.body, top_level_imports, class_name);
        defer if (cleaned_body.ptr != method.body.ptr) allocator.free(cleaned_body);
        try writer.writeAll(cleaned_body);
    }

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
    var result = infra.List(u8).init(allocator);
    errdefer result.deinit();

    var pos: usize = 0;
    while (pos < body.len) {
        // Look for pattern: const Name = @import(
        const const_pos = std.mem.indexOfPos(u8, body, pos, "const ") orelse {
            // No more consts, append rest
            try result.appendSlice(body[pos..]);
            break;
        };

        // Append everything before this const
        try result.appendSlice(body[pos..const_pos]);

        // Check if this is an import statement
        const after_const = const_pos + "const ".len;
        const eq_pos = std.mem.indexOfScalarPos(u8, body, after_const, '=') orelse {
            // No = sign, not an import, keep it
            try result.appendSlice("const ");
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
            try result.appendSlice(body[const_pos..after_eq]);
            pos = after_eq;
            continue;
        };

        // This is a const Name = @import(...); statement
        // Find the semicolon
        const semicolon_pos = std.mem.indexOfScalarPos(u8, body, import_pos, ';') orelse {
            // No semicolon found, keep it
            try result.appendSlice(body[const_pos..]);
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
            try result.appendSlice(body[const_pos .. semicolon_pos + 1]);
            pos = semicolon_pos + 1;
        }
    }

    return result.toOwnedSlice();
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

    var result = infra.List(u8).init(allocator);
    errdefer result.deinit();

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
            try result.appendSlice(line);
            try result.append('\n');
        }
    }

    // Trim trailing whitespace
    const full_result = try result.toOwnedSlice();
    const trimmed_result = std.mem.trim(u8, full_result, " \t\r\n");
    const final = try allocator.dupe(u8, trimmed_result);
    allocator.free(full_result);

    return final;
}

const SelfTypeInfo = struct {
    type_name: ?[]const u8,
    has_pointer: bool,
    has_const: bool,
};

/// Extract the type info from a self parameter in a method signature
/// Example: "(self: *EventTarget, ...)" -> SelfTypeInfo{ .type_name = "EventTarget", .has_pointer = true }
/// Example: "(self: *const Node, ...)" -> SelfTypeInfo{ .type_name = "Node", .has_pointer = true }
/// Example: "(self: anytype, ...)" -> SelfTypeInfo{ .type_name = "anytype", .has_pointer = false }
fn extractSelfTypeInfo(allocator: Allocator, signature: []const u8) !?SelfTypeInfo {
    // Find "self: " pattern
    const self_pattern = "self: ";
    const self_start = std.mem.indexOf(u8, signature, self_pattern) orelse return null;

    var cursor = self_start + self_pattern.len;
    var has_pointer = false;
    var has_const = false;

    // Skip pointer syntax: * or *const
    if (cursor < signature.len and signature[cursor] == '*') {
        has_pointer = true;
        cursor += 1;
        // Check for "const " after the *
        if (cursor + 6 < signature.len and std.mem.startsWith(u8, signature[cursor..], "const ")) {
            has_const = true;
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

    if (type_end <= type_start) return null;

    const type_name = signature[type_start..type_end];
    return SelfTypeInfo{
        .type_name = try allocator.dupe(u8, type_name),
        .has_pointer = has_pointer,
        .has_const = has_const,
    };
}

/// Rewrite "self" references in method body to use a different name for field access
/// Example: rewriteSelfReferences(body, "self_parent") replaces "self.field" with "self_parent.field"
///
/// Method calls (self.methodName()) are kept as "self" because inherited methods
/// exist in the child class and should be called on self, not self_parent.
fn rewriteSelfReferences(allocator: Allocator, body: []const u8, new_name: []const u8) ![]const u8 {
    var result = infra.List(u8).init(allocator);
    errdefer result.deinit();

    var pos: usize = 0;
    while (pos < body.len) {
        // Look for "self" keyword
        const self_pos = std.mem.indexOfPos(u8, body, pos, "self") orelse {
            // No more self references, append rest
            try result.appendSlice(body[pos..]);
            break;
        };

        // Check if this is actually the "self" keyword (not part of another identifier)
        const is_valid_self = blk: {
            // Check character before "self"
            if (self_pos > 0) {
                const before = body[self_pos - 1];
                if ((before >= 'a' and before <= 'z') or
                    (before >= 'A' and before <= 'Z') or
                    (before >= '0' and before <= '9') or
                    before == '_')
                {
                    break :blk false; // Part of another identifier
                }
            }

            // Check character after "self"
            const after_pos = self_pos + 4;
            if (after_pos < body.len) {
                const after = body[after_pos];
                if ((after >= 'a' and after <= 'z') or
                    (after >= 'A' and after <= 'Z') or
                    (after >= '0' and after <= '9') or
                    after == '_')
                {
                    break :blk false; // Part of another identifier
                }
            }

            break :blk true;
        };

        // Append everything before this self
        try result.appendSlice(body[pos..self_pos]);

        if (is_valid_self) {
            // Check if this is a method call: self.methodName(
            // If so, keep as "self" because methods are inherited into child class
            const is_method_call = blk: {
                var scan_pos = self_pos + 4; // After "self"

                // Skip whitespace
                while (scan_pos < body.len and (body[scan_pos] == ' ' or body[scan_pos] == '\t')) {
                    scan_pos += 1;
                }

                // Must have '.'
                if (scan_pos >= body.len or body[scan_pos] != '.') break :blk false;
                scan_pos += 1;

                // Skip whitespace
                while (scan_pos < body.len and (body[scan_pos] == ' ' or body[scan_pos] == '\t')) {
                    scan_pos += 1;
                }

                // Must have identifier
                if (scan_pos >= body.len) break :blk false;
                const first_char = body[scan_pos];
                if (!((first_char >= 'a' and first_char <= 'z') or
                    (first_char >= 'A' and first_char <= 'Z') or
                    first_char == '_'))
                {
                    break :blk false;
                }

                // Skip identifier
                while (scan_pos < body.len) {
                    const ch = body[scan_pos];
                    if ((ch >= 'a' and ch <= 'z') or
                        (ch >= 'A' and ch <= 'Z') or
                        (ch >= '0' and ch <= '9') or
                        ch == '_')
                    {
                        scan_pos += 1;
                    } else {
                        break;
                    }
                }

                // Skip whitespace
                while (scan_pos < body.len and (body[scan_pos] == ' ' or body[scan_pos] == '\t')) {
                    scan_pos += 1;
                }

                // Check if followed by '(' - if so, it's a method call
                if (scan_pos < body.len and body[scan_pos] == '(') {
                    break :blk true;
                }

                break :blk false;
            };

            if (is_method_call) {
                // Keep as "self" for method calls (inherited methods are in child class)
                try result.appendSlice("self");
            } else {
                // Replace with new name for field access
                try result.appendSlice(new_name);
            }
            pos = self_pos + 4; // Skip "self"
        } else {
            // Keep original "self" (it's part of another word)
            try result.appendSlice("self");
            pos = self_pos + 4;
        }
    }

    return result.toOwnedSlice();
}
