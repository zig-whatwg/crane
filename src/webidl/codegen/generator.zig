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
const optimizer = @import("optimizer.zig");

/// Generate Zig code from enhanced class IR
/// If module_definitions is provided, they will be included after imports
/// If post_class_definitions is provided, they will be included after the class
pub fn generateCode(
    allocator: Allocator,
    enhanced: ir.EnhancedClassIR,
    module_definitions: ?[]const u8,
    post_class_definitions: ?[]const u8,
    registry: *const optimizer.ClassRegistry,
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
    try writeClass(allocator, writer, enhanced, registry);

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
/// Generate discriminator value constant for child types (e.g., node_type_VALUE)
/// This constant is used by the parent's as() method for type checking
fn writeDiscriminatorValueConstant(
    allocator: Allocator,
    writer: anytype,
    class: ir.ClassDef,
    enhanced: ir.EnhancedClassIR,
    registry: *const optimizer.ClassRegistry,
) !void {
    _ = enhanced;

    // Only generate for child classes (not the parent with discriminator)
    const parent_name = class.parent orelse return;

    // Cast away const - registry.get() requires mutable but we only read
    const mutable_registry = @constCast(registry);
    var current_parent_class = mutable_registry.get(parent_name) orelse return;
    var constants_class_name = parent_name;

    // Walk up parent chain to find a class with constants (the discriminator owner)
    // e.g., Text -> CharacterData -> Node (Node has constants)
    var depth: usize = 0;
    while (depth < 10) : (depth += 1) {
        if (current_parent_class.own_constants.len > 0) {
            // Found a class with constants
            break;
        }

        // No constants, try grandparent
        const grandparent_name = current_parent_class.parent orelse return; // No constants in hierarchy
        constants_class_name = grandparent_name;
        current_parent_class = mutable_registry.get(grandparent_name) orelse return;
    }

    // Find which discriminator constant matches this child
    const discriminator_constant = try findDiscriminatorConstantForChild(
        allocator,
        class.name,
        current_parent_class,
    ) orelse return;
    defer allocator.free(discriminator_constant);

    // Determine the root class with the discriminator (walk up the hierarchy)
    // For DOM, this is always Node, but be generic
    var root_class_name = constants_class_name;
    var current = current_parent_class;
    depth = 0; // Reset depth counter
    const max_depth = 10; // Prevent infinite loops

    while (depth < max_depth) : (depth += 1) {
        const grandparent_name = current.parent orelse break;
        const grandparent = mutable_registry.get(grandparent_name) orelse break;

        // Check if grandparent has the same constant (means it's higher in hierarchy)
        var found = false;
        for (grandparent.own_constants) |constant| {
            if (std.mem.eql(u8, constant.name, discriminator_constant)) {
                root_class_name = grandparent_name;
                current = grandparent;
                found = true;
                break;
            }
        }

        if (!found) break;
    }

    // Generate the constant
    // For Node children: pub const node_type_VALUE = Node.ELEMENT_NODE;
    // For CharacterData children: pub const node_type_VALUE = Node.TEXT_NODE;
    try writer.writeAll("\n    // Discriminator value for parent's as() method\n");
    try writer.print("    pub const node_type_VALUE = {s}.{s};\n", .{ root_class_name, discriminator_constant });
}

/// Find the discriminator constant that matches a child class
/// Walks up the parent chain to find constants if parent doesn't have them
fn findDiscriminatorConstantForChild(
    allocator: Allocator,
    child_name: []const u8,
    parent_class: *ir.ClassDef,
) !?[]const u8 {
    // Check parent's own constants first
    for (parent_class.own_constants) |constant| {
        if (matchConstantToChildName(constant.name, child_name)) {
            return try allocator.dupe(u8, constant.name);
        }
    }

    // Parent doesn't have constants - this can happen with intermediate classes
    // like CharacterData (extends Node but has no node_type constants)
    // Return null and let caller handle it
    return null;
}

/// Write an ExtendedAttributeValue to the output
fn writeExtendedAttributeValue(writer: anytype, value: anytype) !void {
    switch (value) {
        .none => try writer.writeAll(".none"),
        .identifier => |id| {
            try writer.writeAll(".{ .identifier = \"");
            try writer.writeAll(id);
            try writer.writeAll("\" }");
        },
        .identifier_list => |list| {
            try writer.writeAll(".{ .identifier_list = &.{");
            for (list, 0..) |id, i| {
                if (i > 0) try writer.writeAll(", ");
                try writer.writeAll("\"");
                try writer.writeAll(id);
                try writer.writeAll("\"");
            }
            try writer.writeAll("} }");
        },
        .wildcard => try writer.writeAll(".wildcard"),
        .string => |s| {
            try writer.writeAll(".{ .string = \"");
            try writer.writeAll(s);
            try writer.writeAll("\" }");
        },
        .integer => |i| {
            try writer.print(".{{ .integer = {} }}", .{i});
        },
        .decimal => |d| {
            try writer.print(".{{ .decimal = {} }}", .{d});
        },
        .named_arg_list => |args| {
            try writer.writeAll(".{ .named_arg_list = &.{");
            for (args, 0..) |arg, i| {
                if (i > 0) try writer.writeAll(", ");
                try writer.writeAll(".{ .name = \"");
                try writer.writeAll(arg.name);
                try writer.writeAll("\", .value = \"");
                try writer.writeAll(arg.value);
                try writer.writeAll("\" }");
            }
            try writer.writeAll("} }");
        },
    }
}

fn writeClass(allocator: Allocator, writer: anytype, enhanced: ir.EnhancedClassIR, registry: *const optimizer.ClassRegistry) !void {
    const class = enhanced.class;

    // Class doc comment
    if (class.doc_comment) |doc| {
        var lines = std.mem.splitScalar(u8, doc, '\n');
        while (lines.next()) |line| {
            try writer.print("/// {s}\n", .{line});
        }
    }

    // Class declaration
    // CRITICAL: We need guaranteed field order for @ptrCast to work with inheritance.
    //
    // Unfortunately, neither `extern struct` nor `packed struct` works for us:
    // - extern struct: Can't contain Allocator (not extern-compatible)
    // - packed struct: Would waste memory with padding
    //
    // SOLUTION: Generate explicit field ordering comment + rely on Zig's current behavior
    // which tends to preserve source order (though not guaranteed). The real fix requires
    // using @fieldParentPtr or redesigning inheritance.
    //
    // TODO: Replace @ptrCast with proper @fieldParentPtr-based casting
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

        // Auto-generate discriminator value constant for child types
        try writeDiscriminatorValueConstant(allocator, writer, class, enhanced, registry);
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

    // Parent interface (for inheritance chain)
    if (class.parent) |parent| {
        try writer.print("        .parent = \"{s}\",\n", .{parent});
    } else {
        try writer.writeAll("        .parent = null,\n");
    }

    // Extended attributes
    if (class.extended_attrs.len > 0) {
        try writer.writeAll("        .extended_attrs = &.{\n");
        for (class.extended_attrs) |attr| {
            try writer.writeAll("            .{ .name = \"");
            try writer.writeAll(attr.name);
            try writer.writeAll("\", .value = ");
            try writeExtendedAttributeValue(writer, attr.value);
            try writer.writeAll(" },\n");
        }
        try writer.writeAll("        },\n");
    } else {
        try writer.writeAll("        .extended_attrs = &.{},\n");
    }

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
    try writeDowncastHelpers(allocator, writer, enhanced, registry);

    try writer.writeAll("};\n");
}

/// Inheritance hierarchy information for downcast generation
const InheritanceInfo = struct {
    discriminator_field: []const u8, // Field used for type checking (e.g., "node_type")
    children: []ChildTypeInfo, // Direct children of this class

    const ChildTypeInfo = struct {
        class_name: []const u8, // Child class name (e.g., "Element", "CharacterData")
        discriminator_values: [][]const u8, // Values that map to this type (e.g., "ELEMENT_NODE", "TEXT_NODE")
    };
};

/// Detect discriminator field for a class by analyzing its constants and parent
fn detectDiscriminatorField(class: ir.ClassDef, enhanced: ir.EnhancedClassIR) ?[]const u8 {
    // Look for common discriminator patterns in own constants
    for (class.own_constants) |constant| {
        const name = constant.name;

        // Pattern 1: *_NODE constants (DOM Node hierarchy)
        if (std.mem.endsWith(u8, name, "_NODE")) {
            return "node_type";
        }

        // Pattern 2: *_TYPE constants (generic type discriminator)
        if (std.mem.endsWith(u8, name, "_TYPE")) {
            return "type";
        }

        // Pattern 3: KIND_* constants
        if (std.mem.startsWith(u8, name, "KIND_")) {
            return "kind";
        }
    }

    // Check if we have node_type field (inherited from Node)
    for (enhanced.struct_fields) |field| {
        if (std.mem.eql(u8, field.name, "node_type")) {
            return "node_type";
        }
        if (std.mem.eql(u8, field.name, "type")) {
            return "type";
        }
        if (std.mem.eql(u8, field.name, "kind")) {
            return "kind";
        }
    }

    return null;
}

/// Find all direct children of a class in the registry
fn findDirectChildren(allocator: Allocator, class_name: []const u8, registry: *const optimizer.ClassRegistry) ![][]const u8 {
    var children = infra.List([]const u8).init(allocator);

    // Iterate through all classes in registry
    var iter = registry.classes.iterator();
    while (iter.next()) |entry| {
        const potential_child = entry.value_ptr.*;

        // Check if this class's parent matches our class_name
        if (potential_child.parent) |parent_name| {
            if (std.mem.eql(u8, parent_name, class_name)) {
                try children.append(try allocator.dupe(u8, potential_child.name));
            }
        }
    }

    return try children.toOwnedSlice();
}

/// Try to match a constant name to a child class name
/// Examples: TEXT_NODE -> Text, ELEMENT_NODE -> Element, TEXT_TYPE -> Text
fn matchConstantToChildName(constant_name: []const u8, child_name: []const u8) bool {
    // Common patterns:
    // 1. CHILDNAME_NODE (e.g., TEXT_NODE -> Text)
    // 2. CHILDNAME_TYPE (e.g., TEXT_TYPE -> Text)
    // 3. KIND_CHILDNAME (e.g., KIND_TEXT -> Text)

    // Convert child_name to UPPERCASE (simple)
    var upper_child_buf: [128]u8 = undefined;
    if (child_name.len > 64) return false; // Conservative limit

    const upper_child = std.ascii.upperString(&upper_child_buf, child_name);

    // Build UPPER_CASE version with underscores for CamelCase
    // e.g., "DocumentType" -> "DOCUMENT_TYPE"
    var upper_child_underscore_buf: [128]u8 = undefined;
    const upper_child_underscore = blk: {
        var write_pos: usize = 0;
        for (child_name, 0..) |c, i| {
            // Insert underscore before uppercase letters (except first)
            if (i > 0 and std.ascii.isUpper(c) and !std.ascii.isUpper(child_name[i - 1])) {
                upper_child_underscore_buf[write_pos] = '_';
                write_pos += 1;
            }
            upper_child_underscore_buf[write_pos] = std.ascii.toUpper(c);
            write_pos += 1;
        }
        break :blk upper_child_underscore_buf[0..write_pos];
    };

    // Pattern 1a: CHILDNAME_NODE (exact match, e.g., TEXT_NODE -> Text)
    if (std.mem.endsWith(u8, constant_name, "_NODE")) {
        const prefix = constant_name[0 .. constant_name.len - "_NODE".len];
        if (std.mem.eql(u8, prefix, upper_child)) {
            return true;
        }
    }

    // Pattern 1a': Abbreviated form (constant prefix is abbreviated child name)
    // e.g., ATTRIBUTE_NODE -> Attr (prefix="ATTRIBUTE" starts with "ATTR")
    if (std.mem.endsWith(u8, constant_name, "_NODE")) {
        const prefix = constant_name[0 .. constant_name.len - "_NODE".len];
        // Constant prefix must exactly match child, or
        // child must be 3+ chars and be the start of the prefix
        if (upper_child.len >= 3 and prefix.len > upper_child.len) {
            // The constant prefix must START with the child name
            // e.g., "ATTRIBUTE" starts with "ATTR" ✓
            // BUT "DOCUMENT_TYPE" does NOT start with "DOCUMENT" (it equals, then has more)
            // Actually that DOES start with "DOCUMENT"... the issue is we need exact or abbreviated
            // Let me be more precise: child name abbreviates the prefix
            // ATTR abbreviates ATTRIBUTE (ATTR is start of ATTRIBUTE) ✓
            // DOCUMENT does NOT abbreviate DOCUMENT_TYPE (can't have underscore in between)

            // Only match if there's no underscore in the prefix after the child length
            const after_child = prefix[upper_child.len..];
            if (std.mem.startsWith(u8, prefix, upper_child) and
                after_child.len > 0 and after_child[0] != '_')
            {
                return true;
            }
        }
    }

    // Pattern 1b: CHILD_NAME_NODE (with underscores, e.g., DOCUMENT_TYPE_NODE -> DocumentType)
    if (std.mem.endsWith(u8, constant_name, "_NODE")) {
        const prefix = constant_name[0 .. constant_name.len - "_NODE".len];
        if (std.mem.eql(u8, prefix, upper_child_underscore)) {
            return true;
        }
    }

    // Pattern 2: CHILDNAME_TYPE or CHILD_NAME_TYPE
    if (std.mem.endsWith(u8, constant_name, "_TYPE")) {
        const prefix = constant_name[0 .. constant_name.len - "_TYPE".len];
        if (std.mem.eql(u8, prefix, upper_child) or std.mem.eql(u8, prefix, upper_child_underscore)) {
            return true;
        }
    }

    // Pattern 3: KIND_CHILDNAME or KIND_CHILD_NAME
    if (std.mem.startsWith(u8, constant_name, "KIND_")) {
        const suffix = constant_name["KIND_".len..];
        if (std.mem.eql(u8, suffix, upper_child) or std.mem.eql(u8, suffix, upper_child_underscore)) {
            return true;
        }
    }

    return false;
}

/// Find all constants that map to a specific child class
fn findConstantsForChild(
    allocator: Allocator,
    child_name: []const u8,
    parent_class: ir.ClassDef,
) ![][]const u8 {
    var matching_constants = infra.List([]const u8).init(allocator);

    // Check all constants in the parent class
    for (parent_class.own_constants) |constant| {
        if (matchConstantToChildName(constant.name, child_name)) {
            try matching_constants.append(constant.name);
        }
    }

    return try matching_constants.toOwnedSlice();
}

/// Build inheritance information for generating downcast helpers
fn buildInheritanceInfo(allocator: Allocator, class: ir.ClassDef, enhanced: ir.EnhancedClassIR, registry: *const optimizer.ClassRegistry) !?InheritanceInfo {
    // Detect discriminator field
    const discriminator = detectDiscriminatorField(class, enhanced) orelse return null;

    // Find all direct children dynamically from registry
    const child_names = try findDirectChildren(allocator, class.name, registry);
    defer {
        for (child_names) |name| allocator.free(name);
        allocator.free(child_names);
    }

    // If no children, no downcast helpers needed
    if (child_names.len == 0) return null;

    // Build children info dynamically by auto-detecting constant-to-type mappings
    var children_list = infra.List(InheritanceInfo.ChildTypeInfo).init(allocator);

    // For each child, auto-detect which constants map to it
    for (child_names) |child_name| {
        // Find all constants that match this child's name
        const constants = try findConstantsForChild(allocator, child_name, class);
        defer allocator.free(constants);

        // Only include children that have at least one matching constant
        if (constants.len > 0) {
            var values = infra.List([]const u8).init(allocator);
            for (constants) |constant_name| {
                try values.append(constant_name);
            }
            try children_list.append(.{
                .class_name = try allocator.dupe(u8, child_name), // Duplicate so it survives defer cleanup
                .discriminator_values = try values.toOwnedSlice(),
            });
        }
    }

    // If no children with constants found, no downcast helpers needed
    if (children_list.len == 0) return null;

    return InheritanceInfo{
        .discriminator_field = discriminator,
        .children = try children_list.toOwnedSlice(),
    };
}

/// Generate single generic type conversion helper for safe downcasting
fn writeDowncastHelpers(allocator: Allocator, writer: anytype, enhanced: ir.EnhancedClassIR, registry: *const optimizer.ClassRegistry) !void {
    _ = allocator;
    const class = enhanced.class;

    // Detect discriminator field - if none, no downcast helper needed
    const discriminator = detectDiscriminatorField(class, enhanced) orelse return;

    try writer.writeAll("\n    // ========================================================================\n");
    try writer.writeAll("    // Type Conversion Helper (Safe Downcasting)\n");
    try writer.writeAll("    // ========================================================================\n");
    try writer.writeAll("    // Generic downcast that works for any child type.\n");
    try writer.print("    // Child types must declare: pub const {s}_VALUE = <discriminator_constant>\n\n", .{discriminator});

    // Generate single generic as() method (mutable version)
    try writer.writeAll("    /// Safe downcast to child type T\n");
    try writer.writeAll("    /// Returns null if this instance is not of type T\n");
    try writer.writeAll("    /// \n");
    try writer.print("    /// Requires: T must declare `pub const {s}_VALUE`\n", .{discriminator});
    try writer.writeAll("    /// \n");
    try writer.writeAll("    /// Example:\n");
    try writer.print("    ///   if (node.as(Element)) |elem| {{\n", .{});
    try writer.writeAll("    ///       // use elem\n");
    try writer.writeAll("    ///   }\n");
    try writer.print("    pub fn as(self: *{s}, comptime T: type) ?*T {{\n", .{class.name});
    try writer.writeAll("        comptime {\n");
    try writer.print("            if (!@hasDecl(T, \"{s}_VALUE\")) {{\n", .{discriminator});
    try writer.print("                @compileError(\"Cannot cast to \" ++ @typeName(T) ++ \": type must declare 'pub const {s}_VALUE'\");\n", .{discriminator});
    try writer.writeAll("            }\n");
    try writer.writeAll("        }\n");
    try writer.print("        return if (self.{s} == T.{s}_VALUE)\n", .{ discriminator, discriminator });
    try writer.writeAll("            @ptrCast(@alignCast(self))\n");
    try writer.writeAll("        else\n");
    try writer.writeAll("            null;\n");
    try writer.writeAll("    }\n\n");

    // Generate const version
    try writer.writeAll("    /// Safe downcast to child type T (const version)\n");
    try writer.print("    pub fn asConst(self: *const {s}, comptime T: type) ?*const T {{\n", .{class.name});
    try writer.writeAll("        comptime {\n");
    try writer.print("            if (!@hasDecl(T, \"{s}_VALUE\")) {{\n", .{discriminator});
    try writer.print("                @compileError(\"Cannot cast to \" ++ @typeName(T) ++ \": type must declare 'pub const {s}_VALUE'\");\n", .{discriminator});
    try writer.writeAll("            }\n");
    try writer.writeAll("        }\n");
    try writer.print("        return if (self.{s} == T.{s}_VALUE)\n", .{ discriminator, discriminator });
    try writer.writeAll("            @ptrCast(@alignCast(self))\n");
    try writer.writeAll("        else\n");
    try writer.writeAll("            null;\n");
    try writer.writeAll("    }\n\n");

    _ = registry; // TODO: Use registry to generate NODE_TYPE constants in children
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
            if (pti.type_name != null) {
                // Rewrite body to use self_parent for field access, self for method calls
                const rewritten_body = try rewriteSelfReferences(allocator, method.body, "self_parent");
                defer allocator.free(rewritten_body);

                // Check if self_parent is actually used in the rewritten body
                const needs_self_parent = std.mem.indexOf(u8, rewritten_body, "self_parent") != null;

                // Only declare self_parent if it's actually used (for field access)
                if (needs_self_parent) {
                    // Don't cast - just pass self directly
                    // Child structs have all parent fields duplicated, so they can be used directly
                    // Note: @ptrCast doesn't work due to Zig's field reordering optimization
                    try writer.print("        const self_parent = self;\n", .{});
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
