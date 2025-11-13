//! AST Parser for WebIDL Codegen
//!
//! Parses Zig source files into IR structures for analysis and transformation.
//!
//! ## Parsing Strategy
//!
//! We use a hybrid approach:
//! 1. **String scanning** for high-level structure (fast, simple)
//! 2. **Zig AST parser** for complex expressions (accurate, robust)
//!
//! This gives us the best of both worlds: performance where we need it,
//! correctness where it matters.

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");
const ir = @import("ir.zig");

/// Parse a source file into IR
pub fn parseFile(allocator: Allocator, source: []const u8, file_path: []const u8) !ir.FileIR {
    var file_ir = ir.FileIR{
        .path = try allocator.dupe(u8, file_path),
        .module_imports = &.{},
        .classes = &.{},
        .module_constants = &.{},
        .module_definitions = &.{},
    };
    errdefer file_ir.deinit(allocator);

    // Extract module-level imports (before any class definitions)
    file_ir.module_imports = try parseModuleImports(allocator, source);
    errdefer {
        for (file_ir.module_imports) |*import| {
            import.deinit(allocator);
        }
        allocator.free(file_ir.module_imports);
    }

    // Extract module-level definitions (const, type, fn before first class)
    file_ir.module_definitions = try parseModuleDefinitions(allocator, source);
    errdefer allocator.free(file_ir.module_definitions);

    // Extract class definitions
    file_ir.classes = try parseClasses(allocator, source, file_path);
    errdefer {
        for (file_ir.classes) |*class| {
            class.deinit(allocator);
        }
        allocator.free(file_ir.classes);
    }

    return file_ir;
}

/// Parse all imports before the first class definition
fn parseModuleImports(allocator: Allocator, source: []const u8) ![]ir.Import {
    var imports = infra.List(ir.Import).init(allocator);
    errdefer {
        for (imports.toSliceMut()) |*import| {
            import.deinit(allocator);
        }
        imports.deinit();
    }

    // Find the first webidl.interface/namespace/mixin - everything before is module-level
    const first_class = blk: {
        const interface_pos = std.mem.indexOf(u8, source, "webidl.interface(");
        const namespace_pos = std.mem.indexOf(u8, source, "webidl.namespace(");
        const mixin_pos = std.mem.indexOf(u8, source, "webidl.mixin(");

        var min_pos: ?usize = null;
        if (interface_pos) |pos| min_pos = pos;
        if (namespace_pos) |pos| {
            if (min_pos) |m| {
                min_pos = @min(m, pos);
            } else {
                min_pos = pos;
            }
        }
        if (mixin_pos) |pos| {
            if (min_pos) |m| {
                min_pos = @min(m, pos);
            } else {
                min_pos = pos;
            }
        }
        break :blk min_pos;
    };

    const module_section = if (first_class) |pos| source[0..pos] else source;

    // Scan for import statements: const Name = @import("module");
    var pos: usize = 0;
    var line_num: usize = 1;

    while (pos < module_section.len) {
        // Track line numbers
        if (module_section[pos] == '\n') {
            line_num += 1;
            pos += 1;
            continue;
        }

        // Skip whitespace
        if (module_section[pos] == ' ' or module_section[pos] == '\t' or module_section[pos] == '\r') {
            pos += 1;
            continue;
        }

        // Skip comment lines (both // and //! and ///)
        if (pos + 1 < module_section.len and module_section[pos] == '/' and module_section[pos + 1] == '/') {
            // Skip to end of line
            while (pos < module_section.len and module_section[pos] != '\n') {
                pos += 1;
            }
            continue;
        }

        // Look for const declarations
        if (std.mem.startsWith(u8, module_section[pos..], "const ") or
            std.mem.startsWith(u8, module_section[pos..], "pub const "))
        {
            const is_public = std.mem.startsWith(u8, module_section[pos..], "pub const ");
            const const_start = if (is_public) pos + "pub const ".len else pos + "const ".len;

            // Extract name
            const name_end = std.mem.indexOfScalarPos(u8, module_section, const_start, '=') orelse {
                pos += 1;
                continue;
            };
            const name = std.mem.trim(u8, module_section[const_start..name_end], " \t\r\n");

            // Check if this is an import
            const after_eq = std.mem.trim(u8, module_section[name_end + 1 ..], " \t\r\n");
            if (std.mem.startsWith(u8, after_eq, "@import(")) {
                if (try parseImportStatement(allocator, name, after_eq, is_public, line_num)) |import| {
                    try imports.append(import);
                }
            }
        }

        pos += 1;
    }

    return imports.toOwnedSlice();
}

/// Parse module-level definitions (const, type, fn) that appear after imports
/// but before the first class definition. These are helpers, type aliases, etc.
fn parseModuleDefinitions(allocator: Allocator, source: []const u8) ![]const u8 {
    // Find the extent of the module section
    // Start: after the last import statement
    // End: before the first class definition (including the "pub const Name =" line)

    // Find the first class definition
    const first_class_pos = blk: {
        const interface_pos = std.mem.indexOf(u8, source, "webidl.interface(");
        const namespace_pos = std.mem.indexOf(u8, source, "webidl.namespace(");
        const mixin_pos = std.mem.indexOf(u8, source, "webidl.mixin(");

        var min_pos: ?usize = null;
        if (interface_pos) |pos| min_pos = pos;
        if (namespace_pos) |pos| {
            if (min_pos) |m| {
                min_pos = @min(m, pos);
            } else {
                min_pos = pos;
            }
        }
        if (mixin_pos) |pos| {
            if (min_pos) |m| {
                min_pos = @min(m, pos);
            } else {
                min_pos = pos;
            }
        }
        break :blk min_pos;
    };

    // If no class found, everything is module definitions
    var end_pos = first_class_pos orelse source.len;

    // If we found a class, go back to the start of that line
    // to exclude the "pub const Name = webidl.xxx" declaration
    if (first_class_pos) |pos| {
        // Search backwards to find the start of the line
        var line_start = pos;
        while (line_start > 0 and source[line_start - 1] != '\n') {
            line_start -= 1;
        }
        end_pos = line_start;
    }

    // Find the last import statement
    // Scan backwards from first_class_pos to find last line with @import
    var last_import_end: usize = 0;
    var pos: usize = 0;
    while (pos < end_pos) {
        if (std.mem.startsWith(u8, source[pos..], "@import(")) {
            // Found an import, find the end of this line
            const line_end = std.mem.indexOfScalarPos(u8, source, pos, '\n') orelse end_pos;
            last_import_end = line_end + 1;
        }
        pos += 1;
    }

    // Extract the section between last import and first class
    if (last_import_end >= end_pos) {
        return try allocator.dupe(u8, "");
    }

    const definitions_section = source[last_import_end..end_pos];

    // Parse module definitions and filter out struct/enum/union type definitions
    // Keep: type aliases, helper functions, constants
    // Skip: pub const Name = struct/enum/union { ... }
    var filtered: std.ArrayList(u8) = .empty;
    defer filtered.deinit(allocator);

    var filter_pos: usize = 0;
    while (filter_pos < definitions_section.len) {
        // Skip to next non-whitespace
        while (filter_pos < definitions_section.len and
            (definitions_section[filter_pos] == ' ' or
                definitions_section[filter_pos] == '\t' or
                definitions_section[filter_pos] == '\r'))
        {
            filter_pos += 1;
        }

        if (filter_pos >= definitions_section.len) break;

        // Check if this is a newline (empty line)
        if (definitions_section[filter_pos] == '\n') {
            filter_pos += 1;
            continue;
        }

        const decl_start = filter_pos;

        // Find end of current line to check what kind of declaration this is
        var line_end = filter_pos;
        while (line_end < definitions_section.len and definitions_section[line_end] != '\n') {
            line_end += 1;
        }
        const first_line = definitions_section[decl_start..line_end];
        const trimmed = std.mem.trim(u8, first_line, " \t\r");

        // Skip default import redefinitions
        if (std.mem.startsWith(u8, trimmed, "const Allocator =") or
            std.mem.startsWith(u8, trimmed, "const std =") or
            std.mem.startsWith(u8, trimmed, "const webidl =") or
            std.mem.startsWith(u8, trimmed, "pub const Allocator =") or
            std.mem.startsWith(u8, trimmed, "pub const std =") or
            std.mem.startsWith(u8, trimmed, "pub const webidl ="))
        {
            filter_pos = line_end + 1;
            continue;
        }

        // Check if this is a struct/enum/union type definition
        const is_struct_def = std.mem.indexOf(u8, first_line, "pub const ") != null and
            (std.mem.indexOf(u8, first_line, " = struct {") != null or
                std.mem.indexOf(u8, first_line, " = enum {") != null or
                std.mem.indexOf(u8, first_line, " = union(") != null);

        if (is_struct_def) {
            // Skip this entire struct/enum/union definition
            var brace_depth: i32 = 0;
            var found_opening = false;
            while (filter_pos < definitions_section.len) {
                if (definitions_section[filter_pos] == '{') {
                    brace_depth += 1;
                    found_opening = true;
                } else if (definitions_section[filter_pos] == '}') {
                    brace_depth -= 1;
                    if (found_opening and brace_depth == 0) {
                        // Found closing brace, skip to next line
                        while (filter_pos < definitions_section.len and definitions_section[filter_pos] != '\n') {
                            filter_pos += 1;
                        }
                        if (filter_pos < definitions_section.len) filter_pos += 1;
                        break;
                    }
                }
                filter_pos += 1;
            }
            continue;
        }

        // This is something we want to keep (function, type alias, const)
        // Find the end of this declaration
        var decl_end = decl_start;

        // Check if it's a function (has "fn")
        if (std.mem.indexOf(u8, first_line, " fn ") != null or std.mem.indexOf(u8, first_line, "pub fn ") != null) {
            // Find the function body end
            var brace_depth: i32 = 0;
            var found_opening = false;
            while (decl_end < definitions_section.len) {
                if (definitions_section[decl_end] == '{') {
                    brace_depth += 1;
                    found_opening = true;
                } else if (definitions_section[decl_end] == '}') {
                    brace_depth -= 1;
                    if (found_opening and brace_depth == 0) {
                        decl_end += 1;
                        break;
                    }
                }
                decl_end += 1;
            }
        } else {
            // It's a const/type alias - find the semicolon or newline
            while (decl_end < definitions_section.len and definitions_section[decl_end] != ';' and definitions_section[decl_end] != '\n') {
                decl_end += 1;
            }
            if (decl_end < definitions_section.len) decl_end += 1; // include semicolon or newline
        }

        // Append this declaration
        try filtered.appendSlice(allocator, definitions_section[decl_start..decl_end]);
        if (decl_end > 0 and definitions_section[decl_end - 1] != '\n') {
            try filtered.append(allocator, '\n');
        }

        filter_pos = decl_end;
    }

    const result = try filtered.toOwnedSlice(allocator);
    const trimmed = std.mem.trim(u8, result, " \t\r\n");
    const final = try allocator.dupe(u8, trimmed);
    allocator.free(result);

    return final;
}

/// Parse a single import statement
/// Pattern: @import("module_path") or @import("module_path").TypeName
fn parseImportStatement(
    allocator: Allocator,
    name: []const u8,
    statement: []const u8,
    is_public: bool,
    line_num: usize,
) !?ir.Import {
    // Find the module path: @import("...")
    const module_start = std.mem.indexOf(u8, statement, "@import(\"") orelse return null;
    const path_start = module_start + "@import(\"".len;
    const path_end = std.mem.indexOfScalarPos(u8, statement, path_start, '"') orelse return null;
    const module_path = statement[path_start..path_end];

    // Check if this is a type import: @import("...").TypeName
    const after_import = statement[path_end + 1 ..];
    const is_type = std.mem.indexOf(u8, after_import, ").") != null;

    return ir.Import{
        .name = try allocator.dupe(u8, name),
        .module = try allocator.dupe(u8, module_path),
        .is_type = is_type,
        .visibility = if (is_public) .public else .private,
        .source_line = line_num,
    };
}

/// Parse all class definitions in source
fn parseClasses(allocator: Allocator, source: []const u8, file_path: []const u8) ![]ir.ClassDef {
    var classes = infra.List(ir.ClassDef).init(allocator);
    errdefer {
        for (classes.toSliceMut()) |*class| {
            class.deinit(allocator);
        }
        classes.deinit();
    }

    var pos: usize = 0;

    while (pos < source.len) {
        // Find next class definition
        const class_start = findNextClassDefinition(source, pos) orelse break;

        // Parse the class
        const class_def = try parseClassDefinition(allocator, source, class_start, file_path);
        try classes.append(class_def);

        pos = class_start + 1;
    }

    return classes.toOwnedSlice();
}

/// Find the next webidl.interface/namespace/mixin call
fn findNextClassDefinition(source: []const u8, start: usize) ?usize {
    const interface_pos = std.mem.indexOfPos(u8, source, start, "webidl.interface(");
    const namespace_pos = std.mem.indexOfPos(u8, source, start, "webidl.namespace(");
    const mixin_pos = std.mem.indexOfPos(u8, source, start, "webidl.mixin(");

    var min_pos: ?usize = null;
    if (interface_pos) |pos| min_pos = pos;
    if (namespace_pos) |pos| {
        if (min_pos) |m| {
            min_pos = @min(m, pos);
        } else {
            min_pos = pos;
        }
    }
    if (mixin_pos) |pos| {
        if (min_pos) |m| {
            min_pos = @min(m, pos);
        } else {
            min_pos = pos;
        }
    }
    return min_pos;
}

/// Parse a single class definition
fn parseClassDefinition(
    allocator: Allocator,
    source: []const u8,
    class_start: usize,
    file_path: []const u8,
) !ir.ClassDef {
    // Determine class kind
    const kind: ir.ClassDef.Kind = blk: {
        if (std.mem.startsWith(u8, source[class_start..], "webidl.interface(")) break :blk .interface;
        if (std.mem.startsWith(u8, source[class_start..], "webidl.namespace(")) break :blk .namespace;
        if (std.mem.startsWith(u8, source[class_start..], "webidl.mixin(")) break :blk .mixin;
        return error.InvalidClassDefinition;
    };

    // Find class name (go backwards from webidl.interface to find "const Name =")
    const name = try extractClassName(allocator, source, class_start);
    errdefer allocator.free(name);

    // Find the struct body: webidl.interface(struct { ... })
    const struct_start = std.mem.indexOfPos(u8, source, class_start, "struct {") orelse
        return error.MissingStructBody;
    const struct_body_start = struct_start + "struct {".len;

    // Find matching closing brace
    const struct_end = findMatchingBrace(source, struct_start + "struct ".len) orelse
        return error.UnmatchedBrace;

    const struct_body = source[struct_body_start..struct_end];

    // Parse parent class
    const parent = try extractParentClass(allocator, struct_body);
    errdefer if (parent) |p| allocator.free(p);

    // Parse mixins
    const mixins = try extractMixins(allocator, struct_body);
    errdefer {
        for (mixins) |mixin| allocator.free(mixin);
        allocator.free(mixins);
    }

    // Parse fields
    const fields = try parseFields(allocator, struct_body);
    errdefer {
        for (fields) |*field| field.deinit(allocator);
        allocator.free(fields);
    }

    // Parse methods
    const methods = try parseMethods(allocator, struct_body);
    errdefer {
        for (methods) |*method| method.deinit(allocator);
        allocator.free(methods);
    }

    // Parse properties (extract from method names like get_xxx, set_xxx)
    const properties = try parseProperties(allocator, struct_body);
    errdefer {
        for (properties) |*prop| prop.deinit(allocator);
        allocator.free(properties);
    }

    // Parse constants
    const constants = try parseConstants(allocator, struct_body);
    errdefer {
        for (constants) |*constant| constant.deinit(allocator);
        allocator.free(constants);
    }

    // Extract type references from methods and fields
    const required_imports = try extractRequiredImports(allocator, fields, methods, properties);
    errdefer {
        for (required_imports) |*import| import.deinit(allocator);
        allocator.free(required_imports);
    }

    return ir.ClassDef{
        .name = name,
        .parent = parent,
        .mixins = mixins,
        .own_fields = fields,
        .own_methods = methods,
        .own_properties = properties,
        .own_constants = constants,
        .required_imports = required_imports,
        .doc_comment = null, // TODO: extract doc comments
        .source_file = try allocator.dupe(u8, file_path),
        .kind = kind,
    };
}

/// Extract class name from: const ClassName = webidl.interface(...)
fn extractClassName(allocator: Allocator, source: []const u8, class_start: usize) ![]const u8 {
    // Go backwards to find "const Name ="
    var pos = class_start;
    while (pos > 0) : (pos -= 1) {
        if (source[pos] == '\n') {
            const line_start = pos + 1;
            const line = source[line_start..class_start];

            if (std.mem.indexOf(u8, line, "pub const ")) |const_pos| {
                const name_start = const_pos + "pub const ".len;
                const eq_pos = std.mem.indexOfPos(u8, line, name_start, "=") orelse continue;
                const name = std.mem.trim(u8, line[name_start..eq_pos], " \t\r");
                return try allocator.dupe(u8, name);
            } else if (std.mem.indexOf(u8, line, "const ")) |const_pos| {
                const name_start = const_pos + "const ".len;
                const eq_pos = std.mem.indexOfPos(u8, line, name_start, "=") orelse continue;
                const name = std.mem.trim(u8, line[name_start..eq_pos], " \t\r");
                return try allocator.dupe(u8, name);
            }
        }
    }
    return error.ClassNameNotFound;
}

/// Extract parent class from: pub const extends = ParentClass;
fn extractParentClass(allocator: Allocator, struct_body: []const u8) !?[]const u8 {
    const extends_decl = std.mem.indexOf(u8, struct_body, "pub const extends") orelse
        return null;

    const eq_pos = std.mem.indexOfScalarPos(u8, struct_body, extends_decl, '=') orelse
        return null;
    const semicolon = std.mem.indexOfScalarPos(u8, struct_body, eq_pos, ';') orelse
        return null;

    const parent_name = std.mem.trim(u8, struct_body[eq_pos + 1 .. semicolon], " \t\r\n");

    // Handle "base.Type" format - extract just "Type"
    if (std.mem.indexOfScalar(u8, parent_name, '.')) |dot| {
        return try allocator.dupe(u8, parent_name[dot + 1 ..]);
    }

    return try allocator.dupe(u8, parent_name);
}

/// Extract mixin names from: pub const includes = .{ Mixin1, Mixin2 };
fn extractMixins(allocator: Allocator, struct_body: []const u8) ![][]const u8 {
    const includes_decl = std.mem.indexOf(u8, struct_body, "pub const includes") orelse
        return &.{};

    const tuple_start = std.mem.indexOfPos(u8, struct_body, includes_decl, ".{") orelse
        return &.{};
    const tuple_end = std.mem.indexOfScalarPos(u8, struct_body, tuple_start, '}') orelse
        return &.{};

    const tuple_content = struct_body[tuple_start + 2 .. tuple_end];

    var mixins = infra.List([]const u8).init(allocator);
    errdefer {
        for (mixins.toSliceMut()) |mixin| allocator.free(mixin);
        mixins.deinit();
    }

    // Split by comma
    var iter = std.mem.tokenizeAny(u8, tuple_content, ",\t\r\n ");
    while (iter.next()) |mixin_name| {
        try mixins.append(try allocator.dupe(u8, mixin_name));
    }

    return mixins.toOwnedSlice();
}

/// Parse field declarations
fn parseFields(allocator: Allocator, struct_body: []const u8) ![]ir.Field {
    var fields = infra.List(ir.Field).init(allocator);
    errdefer {
        for (fields.toSliceMut()) |*field| field.deinit(allocator);
        fields.deinit();
    }

    // Fields are at the top of the struct, before any "pub const" or "pub fn"
    var pos: usize = 0;
    var line_num: usize = 1;

    while (pos < struct_body.len) {
        const line_start = pos;
        const line_end = std.mem.indexOfScalarPos(u8, struct_body, pos, '\n') orelse struct_body.len;
        const line = std.mem.trim(u8, struct_body[line_start..line_end], " \t\r");

        // Stop at first pub const or pub fn
        if (std.mem.startsWith(u8, line, "pub const") or
            std.mem.startsWith(u8, line, "pub fn") or
            std.mem.startsWith(u8, line, "pub inline fn"))
        {
            break;
        }

        // Parse field: name: Type,
        if (std.mem.indexOf(u8, line, ":")) |colon_pos_in_line| {
            if (!std.mem.startsWith(u8, line, "//")) { // Skip comments
                const name = std.mem.trim(u8, line[0..colon_pos_in_line], " \t");

                // For multi-line types, find colon in struct_body and search from there
                // The colon is at line_start + the position in the untrimmed line
                const untrimmed_line = struct_body[line_start..line_end];
                const colon_in_untrimmed = std.mem.indexOf(u8, untrimmed_line, ":") orelse continue;
                const field_start = line_start + colon_in_untrimmed + 1;

                // Find the end of the type, accounting for nested parentheses in generics
                var paren_depth: i32 = 0;
                var type_end_pos: usize = field_start;
                while (type_end_pos < struct_body.len) : (type_end_pos += 1) {
                    const c = struct_body[type_end_pos];
                    if (c == '(') {
                        paren_depth += 1;
                    } else if (c == ')') {
                        paren_depth -= 1;
                    } else if (c == ',' and paren_depth == 0) {
                        break;
                    } else if (c == '=' and paren_depth == 0) {
                        break;
                    }
                }
                const type_end = type_end_pos;
                const type_text = struct_body[field_start..type_end];

                // Normalize whitespace: collapse newlines/multiple spaces to single space
                var type_name_buf: std.ArrayList(u8) = .empty;
                defer type_name_buf.deinit(allocator);
                var last_was_space = false;
                for (type_text) |c| {
                    if (c == ' ' or c == '\t' or c == '\n' or c == '\r') {
                        if (!last_was_space) {
                            try type_name_buf.append(allocator, ' ');
                            last_was_space = true;
                        }
                    } else {
                        try type_name_buf.append(allocator, c);
                        last_was_space = false;
                    }
                }
                const type_name_raw = try type_name_buf.toOwnedSlice(allocator);
                const type_name_trimmed = std.mem.trim(u8, type_name_raw, " \t");
                const type_name = try allocator.dupe(u8, type_name_trimmed);
                allocator.free(type_name_raw);
                errdefer allocator.free(type_name);

                if (name.len > 0 and type_name.len > 0) {
                    try fields.append(ir.Field{
                        .name = try allocator.dupe(u8, name),
                        .type_name = type_name,
                        .doc_comment = null,
                        .source_line = line_num,
                    });
                }
            }
        }

        pos = line_end + 1;
        line_num += 1;
    }

    return fields.toOwnedSlice();
}

/// Parse method declarations
fn parseMethods(allocator: Allocator, struct_body: []const u8) ![]ir.Method {
    var methods = infra.List(ir.Method).init(allocator);
    errdefer {
        for (methods.toSliceMut()) |*method| method.deinit(allocator);
        methods.deinit();
    }

    var pos: usize = 0;
    var line_num: usize = 1;

    while (pos < struct_body.len) {
        // Look for function declarations (both public and private)
        const pub_fn_pos = std.mem.indexOfPos(u8, struct_body, pos, "pub fn ");
        const pub_inline_fn_pos = std.mem.indexOfPos(u8, struct_body, pos, "pub inline fn ");

        // For private functions, need to skip "const fn" patterns (function pointer types)
        var priv_fn_pos: ?usize = null;
        var search_pos = pos;
        while (search_pos < struct_body.len) {
            const candidate = std.mem.indexOfPos(u8, struct_body, search_pos, "fn ") orelse break;

            // Check if it's "const fn" (function pointer type)
            if (candidate >= 6) {
                const before = struct_body[candidate - 6 .. candidate];
                if (std.mem.eql(u8, before, "const ")) {
                    search_pos = candidate + 1;
                    continue;
                }
            }

            // Valid fn declaration
            priv_fn_pos = candidate;
            break;
        }

        const priv_inline_fn_pos = std.mem.indexOfPos(u8, struct_body, pos, "inline fn ");

        // Find the earliest function declaration
        var fn_pos: ?usize = null;
        var is_public = false;
        var is_inline = false;
        var prefix_len: usize = 0;

        if (pub_inline_fn_pos) |pos_val| {
            fn_pos = pos_val;
            is_public = true;
            is_inline = true;
            prefix_len = "pub inline fn ".len;
        }
        if (pub_fn_pos) |pos_val| {
            if (fn_pos == null or pos_val < fn_pos.?) {
                fn_pos = pos_val;
                is_public = true;
                is_inline = false;
                prefix_len = "pub fn ".len;
            }
        }
        if (priv_inline_fn_pos) |pos_val| {
            if (fn_pos == null or pos_val < fn_pos.?) {
                // Check it's a real function declaration, not inside a type
                // Function declarations have pattern: (whitespace|newline)inline fn name(
                // Field types have pattern: name: type with fn(
                if (pos_val > 0) {
                    const char_before = struct_body[pos_val - 1];
                    // Must be preceded by whitespace or newline
                    if (char_before == '\n' or char_before == ' ' or char_before == '\t') {
                        fn_pos = pos_val;
                        is_public = false;
                        is_inline = true;
                        prefix_len = "inline fn ".len;
                    }
                } else {
                    fn_pos = pos_val;
                    is_public = false;
                    is_inline = true;
                    prefix_len = "inline fn ".len;
                }
            }
        }
        if (priv_fn_pos) |pos_val| {
            if (fn_pos == null or pos_val < fn_pos.?) {
                fn_pos = pos_val;
                is_public = false;
                is_inline = false;
                prefix_len = "fn ".len;
            }
        }

        if (fn_pos) |fn_start| {
            const name_start = fn_start + prefix_len;

            // Extract method name
            const paren_pos = std.mem.indexOfScalarPos(u8, struct_body, name_start, '(') orelse {
                pos = fn_start + 1;
                continue;
            };
            const method_name = std.mem.trim(u8, struct_body[name_start..paren_pos], " \t\r\n");

            // Find method signature (up to opening brace)
            const sig_end = findMethodSignatureEnd(struct_body, paren_pos) orelse {
                pos = paren_pos + 1;
                continue;
            };
            const signature = std.mem.trim(u8, struct_body[paren_pos..sig_end], " \t\r\n");

            // Find method body
            const body_start = std.mem.indexOfScalarPos(u8, struct_body, sig_end, '{') orelse {
                pos = sig_end + 1;
                continue;
            };
            const body_end = findMatchingBrace(struct_body, body_start) orelse {
                pos = body_start + 1;
                continue;
            };
            const body = struct_body[body_start + 1 .. body_end];

            // Extract referenced types
            const referenced_types = try extractTypesFromCode(allocator, signature, body);

            try methods.append(ir.Method{
                .name = try allocator.dupe(u8, method_name),
                .signature = try allocator.dupe(u8, signature),
                .body = try allocator.dupe(u8, body),
                .referenced_types = referenced_types,
                .doc_comment = null,
                .source_line = line_num,
                .modifiers = .{
                    .is_public = is_public,
                    .is_inline = is_inline,
                },
            });

            pos = body_end + 1;
        } else {
            break;
        }

        line_num += 1;
    }

    return methods.toOwnedSlice();
}

/// Find the opening brace of the method body
/// Handles anonymous struct return types: fn foo() struct { ... } { body }
/// Returns the position of the '{' that starts the method body
fn findMethodSignatureEnd(source: []const u8, start: usize) ?usize {
    var pos = start;
    var paren_depth: i32 = 0;

    // First, find the closing paren of the parameter list
    while (pos < source.len) : (pos += 1) {
        const c = source[pos];
        if (c == '(') {
            paren_depth += 1;
        } else if (c == ')') {
            paren_depth -= 1;
            if (paren_depth == 0) {
                break;
            }
        }
    }

    if (paren_depth != 0) return null;

    // Now search for the opening brace of the method body
    // Need to track braces to handle anonymous struct return types
    var search = pos + 1;
    var brace_depth: i32 = 0;

    while (search < source.len) : (search += 1) {
        const c = source[search];

        if (c == '{') {
            if (brace_depth == 0) {
                // This is the method body opening brace (or first struct brace)
                // Check if there's a matching closing brace before another opening brace
                // to distinguish struct return type from method body
                const next_open = std.mem.indexOfScalarPos(u8, source, search + 1, '{');
                const next_close = std.mem.indexOfScalarPos(u8, source, search + 1, '}');

                if (next_close) |close_pos| {
                    if (next_open == null or close_pos < next_open.?) {
                        // Found closing brace before next opening - this is a struct return type
                        // Continue past it to find the real method body
                        brace_depth += 1;
                        continue;
                    }
                }
                // This is the method body
                return search;
            } else {
                brace_depth += 1;
            }
        } else if (c == '}') {
            brace_depth -= 1;
        }
    }

    return null;
}

/// Find matching closing brace for an opening brace
fn findMatchingBrace(source: []const u8, open_pos: usize) ?usize {
    var depth: i32 = 1;
    var pos = open_pos + 1;

    while (pos < source.len) : (pos += 1) {
        const c = source[pos];
        if (c == '{') {
            depth += 1;
        } else if (c == '}') {
            depth -= 1;
            if (depth == 0) {
                return pos;
            }
        }
    }
    return null;
}

/// Extract type names referenced in code
/// Automatically detects any capitalized identifier (type names in Zig)
/// Only looks at actual code, not comments or strings
fn extractTypesFromCode(allocator: Allocator, signature: []const u8, body: []const u8) ![][]const u8 {
    var types = std.StringHashMap(void).init(allocator);
    defer types.deinit();

    // Extract types from BOTH signature and body
    // Signature contains parameter types and return types
    // Body contains type usage in the implementation

    // Combine signature and body for unified scanning
    const combined_len = signature.len + body.len + 1;
    var combined = try allocator.alloc(u8, combined_len);
    defer allocator.free(combined);

    @memcpy(combined[0..signature.len], signature);
    combined[signature.len] = ' ';
    @memcpy(combined[signature.len + 1 ..], body);

    // Simple heuristic: look for patterns like "*TypeName" or "?TypeName" or ": TypeName"
    // These indicate actual type usage, not random capitalized words
    var pos: usize = 0;

    while (pos < combined.len) {
        const c = combined[pos];

        // Skip comment lines entirely
        if (c == '/' and pos + 1 < combined.len and combined[pos + 1] == '/') {
            // Skip to end of line
            while (pos < combined.len and combined[pos] != '\n') {
                pos += 1;
            }
            continue;
        }

        // Skip string literals
        if (c == '"') {
            pos += 1;
            while (pos < combined.len) {
                if (combined[pos] == '"' and combined[pos - 1] != '\\') break;
                pos += 1;
            }
            pos += 1;
            continue;
        }

        // Look for type indicators: *, ?, :, @as(
        const is_type_context = (c == '*' or c == '?' or c == ':' or
            (c == '@' and pos + 3 < combined.len and
                std.mem.startsWith(u8, combined[pos..], "@as")));

        if (is_type_context) {
            // Skip past the indicator and whitespace
            pos += 1;
            while (pos < combined.len and (combined[pos] == ' ' or combined[pos] == '\t')) {
                pos += 1;
            }

            // Check if next character is uppercase (start of type name)
            if (pos < combined.len and combined[pos] >= 'A' and combined[pos] <= 'Z') {
                const start = pos;

                // Extract the identifier
                while (pos < combined.len) {
                    const ch = combined[pos];
                    if ((ch >= 'a' and ch <= 'z') or
                        (ch >= 'A' and ch <= 'Z') or
                        (ch >= '0' and ch <= '9') or
                        ch == '_')
                    {
                        pos += 1;
                    } else {
                        break;
                    }
                }

                const type_name = combined[start..pos];

                // Filter out built-in types
                if (!isBuiltinType(type_name)) {
                    try types.put(type_name, {});
                }
            }
        } else {
            pos += 1;
        }
    }

    // Convert to array
    var result = infra.List([]const u8).init(allocator);
    errdefer {
        for (result.toSliceMut()) |t| allocator.free(t);
        result.deinit();
    }

    var iter = types.keyIterator();
    while (iter.next()) |key| {
        try result.append(try allocator.dupe(u8, key.*));
    }

    return result.toOwnedSlice();
}

/// Parse properties (stub for now - will extract from getters/setters)
fn parseProperties(allocator: Allocator, struct_body: []const u8) ![]ir.Property {
    _ = struct_body;
    return allocator.alloc(ir.Property, 0);
}

/// Parse constants
fn parseConstants(allocator: Allocator, struct_body: []const u8) ![]ir.Constant {
    var constants = infra.List(ir.Constant).init(allocator);
    errdefer {
        for (constants.toSliceMut()) |*constant| constant.deinit(allocator);
        constants.deinit();
    }

    // Look for: pub const NAME: Type = value;
    var pos: usize = 0;
    var line_num: usize = 1;

    while (pos < struct_body.len) {
        if (std.mem.indexOfPos(u8, struct_body, pos, "pub const ")) |const_pos| {
            const name_start = const_pos + "pub const ".len;
            const colon_pos = std.mem.indexOfScalarPos(u8, struct_body, name_start, ':');
            const eq_pos = std.mem.indexOfScalarPos(u8, struct_body, name_start, '=') orelse {
                pos = const_pos + 1;
                continue;
            };

            const name_end = if (colon_pos) |c| @min(c, eq_pos) else eq_pos;
            const name = std.mem.trim(u8, struct_body[name_start..name_end], " \t\r\n");

            // Skip if this is "extends" or "includes"
            if (std.mem.eql(u8, name, "extends") or std.mem.eql(u8, name, "includes")) {
                pos = eq_pos + 1;
                continue;
            }

            const semicolon = std.mem.indexOfScalarPos(u8, struct_body, eq_pos, ';') orelse {
                pos = eq_pos + 1;
                continue;
            };

            const value = std.mem.trim(u8, struct_body[eq_pos + 1 .. semicolon], " \t\r\n");

            var type_name: ?[]const u8 = null;
            if (colon_pos) |c| {
                if (c < eq_pos) {
                    type_name = try allocator.dupe(
                        u8,
                        std.mem.trim(u8, struct_body[c + 1 .. eq_pos], " \t\r\n"),
                    );
                }
            }

            try constants.append(ir.Constant{
                .name = try allocator.dupe(u8, name),
                .type_name = type_name,
                .value = try allocator.dupe(u8, value),
                .visibility = .public,
                .source_line = line_num,
            });

            pos = semicolon + 1;
        } else {
            break;
        }
        line_num += 1;
    }

    return constants.toOwnedSlice();
}

/// Extract required imports from fields, methods, and properties
fn extractRequiredImports(
    allocator: Allocator,
    fields: []ir.Field,
    methods: []ir.Method,
    properties: []ir.Property,
) ![]ir.Import {
    var imports = infra.List(ir.Import).init(allocator);
    errdefer {
        for (imports.toSliceMut()) |*import| import.deinit(allocator);
        imports.deinit();
    }

    var seen_types = std.StringHashMap(void).init(allocator);
    defer seen_types.deinit();

    // Collect unique type names
    for (fields) |field| {
        try addTypeToSet(&seen_types, field.type_name);
    }

    for (methods) |method| {
        for (method.referenced_types) |type_name| {
            try addTypeToSet(&seen_types, type_name);
        }
    }

    for (properties) |prop| {
        try addTypeToSet(&seen_types, prop.type_name);
    }

    // Convert to imports (simplified - map type names to module names)
    var iter = seen_types.keyIterator();
    while (iter.next()) |type_name| {
        const module_name = typeToModule(type_name.*);
        if (module_name.len > 0) {
            try imports.append(ir.Import{
                .name = try allocator.dupe(u8, type_name.*),
                .module = try allocator.dupe(u8, module_name),
                .is_type = true,
                .visibility = .private,
                .source_line = 0,
            });
        }
    }

    return imports.toOwnedSlice();
}

fn addTypeToSet(set: *std.StringHashMap(void), type_name: []const u8) !void {
    // Extract base type from pointers, optionals, etc.
    var base_type = type_name;

    // Strip *, ?, []
    while (base_type.len > 0 and (base_type[0] == '*' or base_type[0] == '?' or base_type[0] == '[')) {
        base_type = base_type[1..];
    }

    // Strip "const "
    if (std.mem.startsWith(u8, base_type, "const ")) {
        base_type = base_type["const ".len..];
    }

    // Strip trailing "u8" from "[]const u8"
    if (std.mem.endsWith(u8, base_type, "u8")) {
        return;
    }

    if (base_type.len > 0 and !isPrimitiveType(base_type)) {
        try set.put(base_type, {});
    }
}

fn isPrimitiveType(type_name: []const u8) bool {
    const primitives = [_][]const u8{
        "u8",    "u16",   "u32",       "u64",
        "i8",    "i16",   "i32",       "i64",
        "f32",   "f64",   "bool",      "void",
        "usize", "isize", "Allocator",
    };

    for (primitives) |prim| {
        if (std.mem.eql(u8, type_name, prim)) return true;
    }
    return false;
}

/// Check if a type name is a built-in type that shouldn't be imported
fn isBuiltinType(type_name: []const u8) bool {
    // Common Zig built-ins and keywords
    const builtins = [_][]const u8{
        "ArrayList", "HashMap",  "StringHashMap",
        "Allocator", "Error",    "Result",
        "Type",      "TypeInfo", "Self",
        "String",    "Iterator",
    };

    for (builtins) |builtin| {
        if (std.mem.eql(u8, type_name, builtin)) return true;
    }

    return false;
}

fn typeToModule(type_name: []const u8) []const u8 {
    // Simple mapping (will need expansion)
    if (std.mem.eql(u8, type_name, "ShadowRoot")) return "shadow_root";
    if (std.mem.eql(u8, type_name, "Node")) return "node";
    if (std.mem.eql(u8, type_name, "Element")) return "element";
    if (std.mem.eql(u8, type_name, "Document")) return "document";
    if (std.mem.eql(u8, type_name, "CharacterData")) return "character_data";
    if (std.mem.eql(u8, type_name, "Text")) return "text";
    if (std.mem.eql(u8, type_name, "Attr")) return "attr";
    if (std.mem.eql(u8, type_name, "NodeList")) return "node_list";
    if (std.mem.eql(u8, type_name, "RegisteredObserver")) return "registered_observer";
    if (std.mem.eql(u8, type_name, "Event")) return "event";
    if (std.mem.eql(u8, type_name, "EventListener")) return "event_target";
    if (std.mem.eql(u8, type_name, "AbortSignal")) return "abort_signal";
    return "";
}
