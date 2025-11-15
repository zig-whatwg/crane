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
        .post_class_definitions = &.{},
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

    // Extract module-level constants (all const/pub const before first class)
    file_ir.module_constants = try parseModuleConstants(allocator, source);
    errdefer {
        for (file_ir.module_constants) |*constant| constant.deinit(allocator);
        allocator.free(file_ir.module_constants);
    }

    // Extract module-level definitions (const, type, fn before first class)
    file_ir.module_definitions = try parseModuleDefinitions(allocator, source);
    errdefer allocator.free(file_ir.module_definitions);

    // Extract class definitions
    file_ir.classes = try parseClasses(allocator, source, file_path, file_ir.module_imports);
    errdefer {
        for (file_ir.classes) |*class| {
            class.deinit(allocator);
        }
        allocator.free(file_ir.classes);
    }

    // Extract post-class definitions (types defined after the class)
    file_ir.post_class_definitions = try parsePostClassDefinitions(allocator, source);
    errdefer allocator.free(file_ir.post_class_definitions);

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

        // Look for const declarations (only at line start, not in the middle of expressions)
        // Check if we're at the start of a line (pos == 0 or previous char is newline)
        const is_line_start = (pos == 0 or module_section[pos - 1] == '\n');

        if (is_line_start and (std.mem.startsWith(u8, module_section[pos..], "const ") or
            std.mem.startsWith(u8, module_section[pos..], "pub const ")))
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

/// Parse all module-level constants (const/pub const) before the first class
/// This captures ALL constants including those between imports (like MutationCallback)
fn parseModuleConstants(allocator: Allocator, source: []const u8) ![]ir.Constant {
    var constants = infra.List(ir.Constant).init(allocator);
    errdefer {
        for (constants.toSliceMut()) |*constant| constant.deinit(allocator);
        constants.deinit();
    }

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

    const module_section = if (first_class_pos) |pos| source[0..pos] else source;

    // Scan for all const declarations: (pub) const Name = value;
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

        // Look for const declarations (only at line start, not in the middle of expressions)
        // Check if we're at the start of a line (pos == 0 or previous char is newline)
        const is_line_start = (pos == 0 or module_section[pos - 1] == '\n');

        if (is_line_start and (std.mem.startsWith(u8, module_section[pos..], "const ") or
            std.mem.startsWith(u8, module_section[pos..], "pub const ")))
        {
            const is_public = std.mem.startsWith(u8, module_section[pos..], "pub const ");
            const const_start = if (is_public) pos + "pub const ".len else pos + "const ".len;

            // Extract name (before = or :)
            const name_end_eq = std.mem.indexOfScalarPos(u8, module_section, const_start, '=');
            const name_end_colon = std.mem.indexOfScalarPos(u8, module_section, const_start, ':');

            var name_end: ?usize = null;
            if (name_end_eq) |eq| {
                if (name_end_colon) |col| {
                    name_end = @min(eq, col);
                } else {
                    name_end = eq;
                }
            } else if (name_end_colon) |col| {
                name_end = col;
            }

            if (name_end) |end| {
                const name = std.mem.trim(u8, module_section[const_start..end], " \t\r\n");

                // Find the semicolon to get the full declaration
                const semicolon = std.mem.indexOfScalarPos(u8, module_section, pos, ';');

                if (name.len > 0 and semicolon != null) {
                    // Store just the name (we don't need the value for filtering)
                    try constants.append(ir.Constant{
                        .name = try allocator.dupe(u8, name),
                        .type_name = null,
                        .value = try allocator.dupe(u8, ""), // Empty value - we only need the name
                        .visibility = if (is_public) .public else .private,
                        .source_line = line_num,
                    });
                }
            }
        }

        pos += 1;
    }

    return constants.toOwnedSlice();
}

/// Parse module-level definitions (const, type, fn) that appear after imports
/// but before the first class definition. These are helpers, type aliases, etc.
fn parseModuleDefinitions(allocator: Allocator, source: []const u8) ![]const u8 {
    // Find the extent of the module section
    // Start: after the INITIAL consecutive import block (not including inline imports later)
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

    // Find the end of the INITIAL consecutive import block
    // Stop when we hit a non-import, non-comment, non-empty line
    var initial_imports_end: usize = 0;
    var pos: usize = 0;
    var found_first_import = false;
    var consecutive_imports = true;

    while (pos < end_pos and consecutive_imports) {
        // Check if this is start of a line (or start of file)
        if (pos == 0 or source[pos - 1] == '\n') {
            // Skip whitespace
            var line_start = pos;
            while (line_start < end_pos and (source[line_start] == ' ' or source[line_start] == '\t')) {
                line_start += 1;
            }

            const rest = source[line_start..end_pos];

            // Check if empty line
            if (rest.len == 0 or rest[0] == '\n') {
                pos += 1;
                continue;
            }

            // Check if comment line
            if (rest.len >= 2 and rest[0] == '/' and rest[1] == '/') {
                pos += 1;
                continue;
            }

            // Check if this line is an import: (pub) const NAME = @import
            const is_const_import = blk: {
                if (std.mem.startsWith(u8, rest, "const ")) {
                    // Find the = sign
                    if (std.mem.indexOfScalarPos(u8, rest, 6, '=')) |eq_pos| {
                        // Check if what follows is @import(
                        const after_eq = std.mem.trim(u8, rest[eq_pos + 1 ..], " \t");
                        if (std.mem.startsWith(u8, after_eq, "@import(")) {
                            break :blk true;
                        }
                    }
                } else if (std.mem.startsWith(u8, rest, "pub const ")) {
                    // Find the = sign
                    if (std.mem.indexOfScalarPos(u8, rest, 10, '=')) |eq_pos| {
                        // Check if what follows is @import(
                        const after_eq = std.mem.trim(u8, rest[eq_pos + 1 ..], " \t");
                        if (std.mem.startsWith(u8, after_eq, "@import(")) {
                            break :blk true;
                        }
                    }
                }
                break :blk false;
            };

            if (is_const_import) {
                found_first_import = true;
                // Find the end of this line
                const line_end = std.mem.indexOfScalarPos(u8, source, pos, '\n') orelse end_pos;
                initial_imports_end = line_end + 1;
            } else if (found_first_import) {
                // We hit a non-import line after seeing imports - end of initial import block
                consecutive_imports = false;
            }
        }
        pos += 1;
    }

    // Extract the section between initial imports and first class
    // This includes: module constants, inline imports (will be filtered), and re-exports
    if (initial_imports_end >= end_pos) {
        return try allocator.dupe(u8, "");
    }

    const definitions_section = source[initial_imports_end..end_pos];
    const trimmed_section = std.mem.trim(u8, definitions_section, " \t\r\n");
    return try allocator.dupe(u8, trimmed_section);
}

/// Parse post-class definitions (types defined after the main class)
/// These are helper types like TeeState, AbortRequest, ReadableStreamIterator
fn parsePostClassDefinitions(allocator: Allocator, source: []const u8) ![]const u8 {
    // Find the end of the main class definition
    // Look for the closing of webidl.interface(), webidl.namespace(), or webidl.mixin()

    // Find first class
    const interface_pos = std.mem.indexOf(u8, source, "webidl.interface(");
    const namespace_pos = std.mem.indexOf(u8, source, "webidl.namespace(");
    const mixin_pos = std.mem.indexOf(u8, source, "webidl.mixin(");

    var class_start: ?usize = null;
    if (interface_pos) |pos| class_start = pos;
    if (namespace_pos) |pos| {
        if (class_start) |cs| {
            class_start = @min(cs, pos);
        } else {
            class_start = pos;
        }
    }
    if (mixin_pos) |pos| {
        if (class_start) |cs| {
            class_start = @min(cs, pos);
        } else {
            class_start = pos;
        }
    }

    // If no class found, no post-class definitions
    if (class_start == null) {
        return try allocator.dupe(u8, "");
    }

    // Find the opening paren of the webidl call
    const paren_pos = std.mem.indexOfScalarPos(u8, source, class_start.?, '(') orelse {
        return try allocator.dupe(u8, "");
    };

    // Find the matching closing paren
    var depth: i32 = 1;
    var pos: usize = paren_pos + 1;
    while (pos < source.len and depth > 0) : (pos += 1) {
        if (source[pos] == '(') {
            depth += 1;
        } else if (source[pos] == ')') {
            depth -= 1;
        }
    }

    if (depth != 0) {
        // Couldn't find matching paren
        return try allocator.dupe(u8, "");
    }

    // pos is now after the closing paren
    // Look for the semicolon that ends the class definition
    const semicolon_pos = std.mem.indexOfScalarPos(u8, source, pos, ';') orelse {
        return try allocator.dupe(u8, "");
    };

    // Everything after the semicolon is post-class definitions
    if (semicolon_pos + 1 >= source.len) {
        return try allocator.dupe(u8, "");
    }

    const post_class = source[semicolon_pos + 1 ..];
    const trimmed = std.mem.trim(u8, post_class, " \t\r\n");
    return try allocator.dupe(u8, trimmed);
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
    // Pattern: after closing quote should be ")." followed by an identifier
    const after_import = statement[path_end + 1 ..];
    var is_type = false;
    if (after_import.len >= 2 and after_import[0] == ')' and after_import[1] == '.') {
        // Check if there's an identifier after the dot (not just whitespace/semicolon)
        if (after_import.len > 2) {
            const after_dot = after_import[2..];
            // Must have at least one alphanumeric character for it to be a type access
            for (after_dot) |c| {
                if ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_') {
                    is_type = true;
                    break;
                }
                // Stop at whitespace/semicolon - no identifier found
                if (c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == ';') {
                    break;
                }
            }
        }
    }

    return ir.Import{
        .name = try allocator.dupe(u8, name),
        .module = try allocator.dupe(u8, module_path),
        .is_type = is_type,
        .visibility = if (is_public) .public else .private,
        .source_line = line_num,
    };
}

/// Parse all class definitions in source
fn parseClasses(allocator: Allocator, source: []const u8, file_path: []const u8, module_imports: []const ir.Import) ![]ir.ClassDef {
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
        const class_def = try parseClassDefinition(allocator, source, class_start, file_path, module_imports);
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
    module_imports: []const ir.Import,
) !ir.ClassDef {
    // Determine class kind
    const kind: ir.ClassDef.Kind = blk: {
        if (std.mem.startsWith(u8, source[class_start..], "webidl.interface(")) break :blk .interface;
        if (std.mem.startsWith(u8, source[class_start..], "webidl.namespace(")) break :blk .namespace;
        if (std.mem.startsWith(u8, source[class_start..], "webidl.mixin(")) break :blk .mixin;
        return error.InvalidClassDefinition;
    };

    // Find class name and position (go backwards from webidl.interface to find "const Name =")
    const class_info = try extractClassNameAndPos(allocator, source, class_start);
    const name = class_info.name;
    errdefer allocator.free(name);

    // Extract doc comment for the class
    const class_doc_comment = try extractDocComment(allocator, source, class_info.line_start);
    errdefer if (class_doc_comment) |doc| allocator.free(doc);

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

    // Parse extended attributes (from second argument to webidl.interface/namespace/mixin)
    const extended_attrs = try extractExtendedAttributes(allocator, source, struct_end);
    errdefer allocator.free(extended_attrs);

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

    // Extract init expressions from init methods and apply to fields
    try applyInitExpressionsToFields(allocator, fields, methods);

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

    // Copy module imports from the source file
    // (these are the ACTUAL imports, not inferred from types)
    const required_imports = try allocator.alloc(ir.Import, module_imports.len);
    errdefer allocator.free(required_imports);
    for (module_imports, 0..) |import, i| {
        required_imports[i] = try import.duplicate(allocator);
    }
    errdefer {
        for (required_imports) |*import| import.deinit(allocator);
    }

    return ir.ClassDef{
        .name = name,
        .parent = parent,
        .mixins = mixins,
        .extended_attrs = extended_attrs,
        .own_fields = fields,
        .own_methods = methods,
        .own_properties = properties,
        .own_constants = constants,
        .required_imports = required_imports,
        .doc_comment = class_doc_comment,
        .source_file = try allocator.dupe(u8, file_path),
        .kind = kind,
    };
}

/// Extract class name from: const ClassName = webidl.interface(...)
/// Also returns the line start position for doc comment extraction
fn extractClassNameAndPos(allocator: Allocator, source: []const u8, class_start: usize) !struct { name: []const u8, line_start: usize } {
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
                return .{
                    .name = try allocator.dupe(u8, name),
                    .line_start = line_start,
                };
            } else if (std.mem.indexOf(u8, line, "const ")) |const_pos| {
                const name_start = const_pos + "const ".len;
                const eq_pos = std.mem.indexOfPos(u8, line, name_start, "=") orelse continue;
                const name = std.mem.trim(u8, line[name_start..eq_pos], " \t\r");
                return .{
                    .name = try allocator.dupe(u8, name),
                    .line_start = line_start,
                };
            }
        }
    }
    return error.ClassNameNotFound;
}

/// Extract class name from: const ClassName = webidl.interface(...)
fn extractClassName(allocator: Allocator, source: []const u8, class_start: usize) ![]const u8 {
    const result = try extractClassNameAndPos(allocator, source, class_start);
    return result.name;
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

/// Extract extended attributes from: webidl.interface(struct { ... }, &.{ exposed("*"), ... });
/// Returns the attributes list after the struct closing brace
fn extractExtendedAttributes(allocator: Allocator, source: []const u8, struct_end: usize) ![]ir.ExtendedAttribute {
    _ = allocator;
    _ = source;
    _ = struct_end;

    // For now, return empty slice
    // Will parse in next task (whatwg-79zr)
    return &.{};
}

/// Extract doc comment from lines immediately preceding the target line.
/// Doc comments are lines starting with "///" (after trimming whitespace).
/// Returns null if no doc comment found, or allocated string with the comment.
fn extractDocComment(allocator: Allocator, source: []const u8, target_line_start: usize) !?[]const u8 {
    if (target_line_start == 0) return null;

    // Walk backwards to collect all consecutive /// lines
    var doc_lines = infra.List([]const u8).init(allocator);
    defer doc_lines.deinit();

    var line_end = target_line_start;
    while (line_end > 0) {
        // Find start of previous line
        var line_start = line_end -| 1;
        while (line_start > 0 and source[line_start - 1] != '\n') : (line_start -= 1) {}

        const line = std.mem.trim(u8, source[line_start..line_end], " \t\r\n");

        // Check if this is a doc comment line
        if (std.mem.startsWith(u8, line, "///")) {
            const comment_content = std.mem.trimLeft(u8, line[3..], " \t");
            try doc_lines.append(comment_content);
            line_end = line_start;
        } else if (line.len == 0) {
            // Empty line - keep going (doc comments can have blank lines)
            line_end = line_start;
        } else {
            // Hit a non-doc-comment line, stop
            break;
        }
    }

    if (doc_lines.len == 0) return null;

    // Reverse the lines (we collected them backwards) and join with newlines
    const lines = doc_lines.toSlice();
    var result = infra.List(u8).init(allocator);
    errdefer result.deinit();

    var i: usize = lines.len;
    while (i > 0) {
        i -= 1;
        try result.appendSlice(lines[i]);
        if (i > 0) try result.append('\n');
    }

    return try result.toOwnedSlice();
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

        // Stop at first pub const or pub fn (except extends/includes which are metadata)
        if (std.mem.startsWith(u8, line, "pub fn") or
            std.mem.startsWith(u8, line, "pub inline fn"))
        {
            break;
        }
        if (std.mem.startsWith(u8, line, "pub const")) {
            // Skip extends and includes - these are WebIDL metadata, not stopping points
            if (!std.mem.startsWith(u8, line, "pub const extends") and
                !std.mem.startsWith(u8, line, "pub const includes"))
            {
                break;
            }
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
                var type_name_buf = infra.List(u8).init(allocator);
                defer type_name_buf.deinit();
                var last_was_space = false;
                for (type_text) |c| {
                    if (c == ' ' or c == '\t' or c == '\n' or c == '\r') {
                        if (!last_was_space) {
                            try type_name_buf.append(' ');
                            last_was_space = true;
                        }
                    } else {
                        try type_name_buf.append(c);
                        last_was_space = false;
                    }
                }
                const type_name_raw = try type_name_buf.toOwnedSlice();
                const type_name_trimmed = std.mem.trim(u8, type_name_raw, " \t");
                const type_name = try allocator.dupe(u8, type_name_trimmed);
                allocator.free(type_name_raw);
                errdefer allocator.free(type_name);

                if (name.len > 0 and type_name.len > 0) {
                    // Extract doc comment for this field
                    const doc_comment = try extractDocComment(allocator, struct_body, line_start);
                    errdefer if (doc_comment) |doc| allocator.free(doc);

                    try fields.append(ir.Field{
                        .name = try allocator.dupe(u8, name),
                        .type_name = type_name,
                        .doc_comment = doc_comment,
                        .source_line = line_num,
                        .init_expr = null, // Will be populated later by extractInitExpressions()
                    });
                }
            }
        }

        pos = line_end + 1;
        line_num += 1;
    }

    return fields.toOwnedSlice();
}

/// A range representing a nested type definition
const NestedTypeRange = struct {
    start: usize,
    end: usize,
};

/// Find all nested type definition ranges (struct, enum, union)
fn findNestedTypeRanges(allocator: Allocator, struct_body: []const u8) ![]NestedTypeRange {
    var ranges = infra.List(NestedTypeRange).init(allocator);
    errdefer ranges.deinit();

    var pos: usize = 0;
    while (pos < struct_body.len) {
        // Look for "pub const Name = struct {" or "pub const Name = enum {" or "pub const Name = union {"
        const pub_const_pos = std.mem.indexOfPos(u8, struct_body, pos, "pub const ") orelse break;

        // Find the equals sign
        const eq_pos = std.mem.indexOfScalarPos(u8, struct_body, pub_const_pos, '=') orelse {
            pos = pub_const_pos + 1;
            continue;
        };

        // Check if it's followed by struct, enum, or union
        const after_eq = std.mem.trimLeft(u8, struct_body[eq_pos + 1 ..], " \t\r\n");
        const is_struct = std.mem.startsWith(u8, after_eq, "struct {") or std.mem.startsWith(u8, after_eq, "struct{");
        const is_enum = std.mem.startsWith(u8, after_eq, "enum {") or std.mem.startsWith(u8, after_eq, "enum{");
        const is_union = std.mem.startsWith(u8, after_eq, "union {") or std.mem.startsWith(u8, after_eq, "union{") or std.mem.startsWith(u8, after_eq, "union(");

        if (is_struct or is_enum or is_union) {
            // Find the opening brace
            const open_brace_pos = std.mem.indexOfScalarPos(u8, struct_body, eq_pos, '{') orelse {
                pos = eq_pos + 1;
                continue;
            };

            // Find matching closing brace
            const close_brace_pos = findMatchingBrace(struct_body, open_brace_pos) orelse {
                pos = open_brace_pos + 1;
                continue;
            };

            // Store the range (from pub const to closing brace + semicolon if present)
            var end_pos = close_brace_pos + 1;
            if (end_pos < struct_body.len and struct_body[end_pos] == ';') {
                end_pos += 1;
            }

            try ranges.append(.{ .start = pub_const_pos, .end = end_pos });
            pos = end_pos;
        } else {
            pos = pub_const_pos + 1;
        }
    }

    return ranges.toOwnedSlice();
}

/// Check if a position is inside any nested type range
fn isInsideNestedType(pos: usize, nested_ranges: []const NestedTypeRange) bool {
    for (nested_ranges) |range| {
        if (pos >= range.start and pos < range.end) {
            return true;
        }
    }
    return false;
}

/// Parse method declarations
fn parseMethods(allocator: Allocator, struct_body: []const u8) ![]ir.Method {
    var methods = infra.List(ir.Method).init(allocator);
    errdefer {
        for (methods.toSliceMut()) |*method| method.deinit(allocator);
        methods.deinit();
    }

    // Find all nested type definitions first
    const nested_ranges = try findNestedTypeRanges(allocator, struct_body);
    defer allocator.free(nested_ranges);

    var pos: usize = 0;
    var line_num: usize = 1;
    const is_node_iterator = false; // Debug flag

    while (pos < struct_body.len) {
        // Look for function declarations (both public and private)
        const pub_fn_pos = std.mem.indexOfPos(u8, struct_body, pos, "pub fn ");
        const pub_inline_fn_pos = std.mem.indexOfPos(u8, struct_body, pos, "pub inline fn ");

        if (is_node_iterator and pub_fn_pos != null) {
            std.debug.print("\n  [Loop iteration] pos={d}, pub_fn_pos={d}\n", .{ pos, pub_fn_pos.? });
        }

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
            // Skip if this function is inside a nested type definition
            if (isInsideNestedType(fn_start, nested_ranges)) {
                pos = fn_start + 1;
                continue;
            }

            if (is_node_iterator) {
                std.debug.print(">>> Found fn at position {d}\n", .{fn_start});
                // Show 60 chars context
                const ctx_start = if (fn_start >= 30) fn_start - 30 else 0;
                const ctx_end = @min(fn_start + 60, struct_body.len);
                std.debug.print("    Context: [{s}]\n", .{struct_body[ctx_start..ctx_end]});
            }
            const name_start = fn_start + prefix_len;

            // Extract method name
            const paren_pos = std.mem.indexOfScalarPos(u8, struct_body, name_start, '(') orelse {
                if (is_node_iterator) std.debug.print("  No paren found\n", .{});
                pos = fn_start + 1;
                continue;
            };
            const method_name = std.mem.trim(u8, struct_body[name_start..paren_pos], " \t\r\n");
            if (is_node_iterator) std.debug.print("  Method name: {s}\n", .{method_name});

            // Find method signature (up to opening brace)
            const sig_end = findMethodSignatureEnd(struct_body, paren_pos) orelse {
                pos = paren_pos + 1;
                continue;
            };
            const signature = std.mem.trim(u8, struct_body[paren_pos..sig_end], " \t\r\n");

            if (is_node_iterator) {
                std.debug.print("  sig_end={d}, char at sig_end='{c}'\n", .{ sig_end, struct_body[sig_end] });
            }

            // Find method body
            const body_start = std.mem.indexOfScalarPos(u8, struct_body, sig_end, '{') orelse {
                pos = sig_end + 1;
                continue;
            };

            if (is_node_iterator) {
                std.debug.print("  After search: body_start={d}\n", .{body_start});
            }
            const body_end = findMatchingBrace(struct_body, body_start) orelse {
                pos = body_start + 1;
                continue;
            };
            const body = struct_body[body_start + 1 .. body_end];

            if (is_node_iterator) {
                std.debug.print("  body_start={d}, body_end={d}, body length={d}\n", .{ body_start, body_end, body.len });
            }

            // Extract referenced types
            const referenced_types = try extractTypesFromCode(allocator, signature, body);

            // Debug: Check if detach or traverse method
            if (std.mem.eql(u8, method_name, "detach")) {
                std.debug.print("\n=== DETACH METHOD ===\n", .{});
                std.debug.print("Body length: {d}\n", .{body.len});
                std.debug.print("Body:\n[{s}]\n", .{body});
                std.debug.print("Body ends at position in struct_body: {d}\n", .{body_end});
                // Check what comes after
                const after_end = body_end + 1;
                if (after_end + 200 < struct_body.len) {
                    std.debug.print("200 chars after body_end:\n[{s}]\n", .{struct_body[after_end .. after_end + 200]});
                }
            }

            // Extract doc comment for this method
            const doc_comment = try extractDocComment(allocator, struct_body, fn_start);
            errdefer if (doc_comment) |doc| allocator.free(doc);

            try methods.append(ir.Method{
                .name = try allocator.dupe(u8, method_name),
                .signature = try allocator.dupe(u8, signature),
                .body = try allocator.dupe(u8, body),
                .referenced_types = referenced_types,
                .doc_comment = doc_comment,
                .source_line = line_num,
                .modifiers = .{
                    .is_public = is_public,
                    .is_inline = is_inline,
                },
            });

            pos = body_end + 1;
            if (is_node_iterator) {
                std.debug.print("  Advancing pos to {d}\n", .{pos});
            }
        } else {
            break;
        }

        line_num += 1;
    }

    return methods.toOwnedSlice();
}

/// Find a keyword as a standalone word (not substring of another identifier)
/// Returns the position of the keyword if found, or null
fn findKeyword(text: []const u8, keyword: []const u8) ?usize {
    var pos: usize = 0;
    while (pos < text.len) {
        const found_pos = std.mem.indexOfPos(u8, text, pos, keyword) orelse return null;

        // Check character before keyword (must be non-identifier character or start of string)
        const has_valid_prefix = if (found_pos == 0)
            true
        else blk: {
            const char_before = text[found_pos - 1];
            const is_ident_char = (char_before >= 'a' and char_before <= 'z') or
                (char_before >= 'A' and char_before <= 'Z') or
                (char_before >= '0' and char_before <= '9') or
                char_before == '_';
            break :blk !is_ident_char;
        };

        // Check character after keyword (must be non-identifier character or end of string)
        const after_pos = found_pos + keyword.len;
        const has_valid_suffix = if (after_pos >= text.len)
            true
        else blk: {
            const char_after = text[after_pos];
            const is_ident_char = (char_after >= 'a' and char_after <= 'z') or
                (char_after >= 'A' and char_after <= 'Z') or
                (char_after >= '0' and char_after <= '9') or
                char_after == '_';
            break :blk !is_ident_char;
        };

        if (has_valid_prefix and has_valid_suffix) {
            return found_pos;
        }

        // Continue searching after this match
        pos = found_pos + 1;
    }

    return null;
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
    // Need to track braces to handle anonymous struct/enum return types like:
    // - fn foo() struct { x: i32 } { body }
    // - fn foo() enum { a, b, c } { body }
    var search = pos + 1;

    // Check if there's an anonymous struct or enum return type
    const text_between = source[pos + 1 .. @min(pos + 200, source.len)];

    // Look for "struct" or "enum" as STANDALONE words (not substrings of other identifiers)
    // This prevents matching "struct" in "ProcessingInstruction" or other type names
    const has_struct_keyword = findKeyword(text_between, "struct");
    const has_enum_keyword = findKeyword(text_between, "enum");

    // Check for struct keyword
    if (has_struct_keyword) |struct_pos| {
        // Find the opening brace of the struct
        const struct_brace = std.mem.indexOfScalarPos(u8, source, pos + 1 + struct_pos, '{');
        if (struct_brace) |sb| {
            // Find the matching closing brace of the struct
            const struct_close = findMatchingBrace(source, sb);
            if (struct_close) |sc| {
                // Now find the opening brace of the method body (after the struct)
                const body_brace = std.mem.indexOfScalarPos(u8, source, sc + 1, '{');
                if (body_brace) |bb| {
                    return bb;
                }
            }
        }
    }

    // Check for enum keyword
    if (has_enum_keyword) |enum_pos| {
        // Find the opening brace of the enum
        const enum_brace = std.mem.indexOfScalarPos(u8, source, pos + 1 + enum_pos, '{');
        if (enum_brace) |eb| {
            // Find the matching closing brace of the enum
            const enum_close = findMatchingBrace(source, eb);
            if (enum_close) |ec| {
                // Now find the opening brace of the method body (after the enum)
                const body_brace = std.mem.indexOfScalarPos(u8, source, ec + 1, '{');
                if (body_brace) |bb| {
                    return bb;
                }
            }
        }
    }

    // No struct return type - just find the first opening brace
    while (search < source.len) : (search += 1) {
        if (source[search] == '{') {
            return search;
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

    // Track local type aliases to avoid importing them
    // Pattern: const TypeName = ...
    var local_aliases = std.StringHashMap(void).init(allocator);
    defer local_aliases.deinit();

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

    // First pass: identify local type aliases (const TypeName = ...)
    var scan_pos: usize = 0;
    while (scan_pos < combined.len) {
        if (scan_pos + 6 < combined.len and std.mem.startsWith(u8, combined[scan_pos..], "const ")) {
            scan_pos += 6; // Skip "const "
            // Skip whitespace
            while (scan_pos < combined.len and (combined[scan_pos] == ' ' or combined[scan_pos] == '\t')) {
                scan_pos += 1;
            }
            // Check for uppercase identifier
            if (scan_pos < combined.len and combined[scan_pos] >= 'A' and combined[scan_pos] <= 'Z') {
                const alias_start = scan_pos;
                while (scan_pos < combined.len) {
                    const ch = combined[scan_pos];
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
                const alias_name = combined[alias_start..scan_pos];
                // Skip whitespace
                while (scan_pos < combined.len and (combined[scan_pos] == ' ' or combined[scan_pos] == '\t')) {
                    scan_pos += 1;
                }
                // Check if followed by '='
                if (scan_pos < combined.len and combined[scan_pos] == '=') {
                    try local_aliases.put(alias_name, {});
                }
            }
        }
        scan_pos += 1;
    }

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

                // Filter out built-in types and local aliases
                if (!isBuiltinType(type_name) and !local_aliases.contains(type_name)) {
                    try types.put(type_name, {});
                }
            }
        } else {
            pos += 1;
        }
    }

    // Additional pass: look for type names used as values
    // Pattern: create(Type) or allocator.create(Type) - common allocation pattern
    pos = 0;
    while (pos < combined.len) {
        const c = combined[pos];

        // Skip comments and strings (same as before)
        if (c == '/' and pos + 1 < combined.len and combined[pos + 1] == '/') {
            while (pos < combined.len and combined[pos] != '\n') pos += 1;
            continue;
        }
        if (c == '"') {
            pos += 1;
            while (pos < combined.len) {
                if (combined[pos] == '"' and combined[pos - 1] != '\\') break;
                pos += 1;
            }
            pos += 1;
            continue;
        }

        // Look for pattern: create(Type) or cast(Type)
        if (c == 'c' and pos + 6 < combined.len) {
            if (std.mem.startsWith(u8, combined[pos..], "create(") or
                std.mem.startsWith(u8, combined[pos..], "cast("))
            {
                // Find the opening paren
                var paren_pos = pos;
                while (paren_pos < combined.len and combined[paren_pos] != '(') paren_pos += 1;
                paren_pos += 1; // Skip '('

                // Skip whitespace
                while (paren_pos < combined.len and (combined[paren_pos] == ' ' or combined[paren_pos] == '\t')) {
                    paren_pos += 1;
                }

                // Check for uppercase letter (type name)
                if (paren_pos < combined.len and combined[paren_pos] >= 'A' and combined[paren_pos] <= 'Z') {
                    const start = paren_pos;
                    while (paren_pos < combined.len) {
                        const ch = combined[paren_pos];
                        if ((ch >= 'a' and ch <= 'z') or
                            (ch >= 'A' and ch <= 'Z') or
                            (ch >= '0' and ch <= '9') or
                            ch == '_')
                        {
                            paren_pos += 1;
                        } else {
                            break;
                        }
                    }

                    const type_name = combined[start..paren_pos];
                    if (!isBuiltinType(type_name) and !local_aliases.contains(type_name)) {
                        try types.put(type_name, {});
                    }
                    pos = paren_pos;
                    continue;
                }
            }
        }

        // Look for pattern: Type.method() - static method calls or Type.init()
        // This catches patterns like Text.init(), Node.create(), etc.
        if (c >= 'A' and c <= 'Z') {
            const type_start = pos;
            var scan = pos;

            // Extract the type name
            while (scan < combined.len) {
                const ch = combined[scan];
                if ((ch >= 'a' and ch <= 'z') or
                    (ch >= 'A' and ch <= 'Z') or
                    (ch >= '0' and ch <= '9') or
                    ch == '_')
                {
                    scan += 1;
                } else {
                    break;
                }
            }

            // Check if followed by '.' (static method call)
            if (scan < combined.len and combined[scan] == '.') {
                const type_name = combined[type_start..scan];
                if (!isBuiltinType(type_name) and !local_aliases.contains(type_name)) {
                    try types.put(type_name, {});
                }
                pos = scan;
                continue;
            }
        }

        pos += 1;
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

            // Check if this is a nested type definition (struct, enum, union)
            const after_eq = std.mem.trimLeft(u8, struct_body[eq_pos + 1 ..], " \t\r\n");
            const is_struct = std.mem.startsWith(u8, after_eq, "struct {") or std.mem.startsWith(u8, after_eq, "struct{");
            const is_enum = std.mem.startsWith(u8, after_eq, "enum {") or std.mem.startsWith(u8, after_eq, "enum{");
            const is_union = std.mem.startsWith(u8, after_eq, "union {") or std.mem.startsWith(u8, after_eq, "union{") or std.mem.startsWith(u8, after_eq, "union(");

            var semicolon: usize = undefined;
            if (is_struct or is_enum or is_union) {
                // Find the opening brace
                const open_brace_pos = std.mem.indexOfScalarPos(u8, struct_body, eq_pos, '{') orelse {
                    pos = eq_pos + 1;
                    continue;
                };

                // Find matching closing brace
                const close_brace_pos = findMatchingBrace(struct_body, open_brace_pos) orelse {
                    pos = open_brace_pos + 1;
                    continue;
                };

                // Now find semicolon after the closing brace
                semicolon = std.mem.indexOfScalarPos(u8, struct_body, close_brace_pos, ';') orelse {
                    pos = close_brace_pos + 1;
                    continue;
                };
            } else {
                // Regular constant - find first semicolon
                semicolon = std.mem.indexOfScalarPos(u8, struct_body, eq_pos, ';') orelse {
                    pos = eq_pos + 1;
                    continue;
                };
            }

            const value = std.mem.trim(u8, struct_body[eq_pos + 1 .. semicolon], " \t\r\n");

            // Debug: Check if Direction
            if (std.mem.eql(u8, name, "Direction")) {
                std.debug.print("\n=== Direction Constant ===\n", .{});
                std.debug.print("name=[{s}]\n", .{name});
                std.debug.print("value=[{s}]\n", .{value});
                std.debug.print("value.len={d}\n", .{value.len});
            }

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

/// Apply init expressions from init methods to fields
/// Looks for methods named "init" and extracts field initializations
fn applyInitExpressionsToFields(
    allocator: Allocator,
    fields: []ir.Field,
    methods: []ir.Method,
) !void {
    // Find init method(s)
    for (methods) |method| {
        if (!std.mem.eql(u8, method.name, "init")) continue;

        // Extract init expressions from this init method
        var init_map = try extractInitExpressions(allocator, method.body);
        defer {
            var it = init_map.iterator();
            while (it.next()) |entry| {
                allocator.free(entry.key_ptr.*);
                var expr = entry.value_ptr.*;
                expr.deinit(allocator);
            }
            init_map.deinit();
        }

        // Apply to fields
        for (fields) |*field| {
            if (init_map.get(field.name)) |init_expr| {
                // Clone the expression to the field
                field.init_expr = try init_expr.clone(allocator);
            }
        }
    }
}

/// Extract initialization expressions from an init method
/// This parses the `return .{ .field = value, ... }` pattern
pub fn extractInitExpressions(
    allocator: Allocator,
    method_body: []const u8,
) !std.StringHashMap(ir.Field.InitExpression) {
    var init_map = std.StringHashMap(ir.Field.InitExpression).init(allocator);
    errdefer {
        var it = init_map.iterator();
        while (it.next()) |entry| {
            var expr = entry.value_ptr.*;
            expr.deinit(allocator);
        }
        init_map.deinit();
    }

    // Find the return statement: "return .{"
    const return_start = std.mem.indexOf(u8, method_body, "return .{") orelse return init_map;
    const struct_init_start = return_start + "return .{".len;

    // Find the closing "};" of the return statement
    var brace_depth: i32 = 1;
    var pos: usize = struct_init_start;
    while (pos < method_body.len and brace_depth > 0) : (pos += 1) {
        if (method_body[pos] == '{') {
            brace_depth += 1;
        } else if (method_body[pos] == '}') {
            brace_depth -= 1;
        }
    }

    if (brace_depth != 0) {
        // Malformed return statement
        return init_map;
    }

    const struct_init_end = pos - 1; // Back up to the last '}'
    const struct_init_body = method_body[struct_init_start..struct_init_end];

    // Parse each field initialization: .field_name = value,
    var field_pos: usize = 0;
    while (field_pos < struct_init_body.len) {
        // Skip whitespace and comments
        while (field_pos < struct_init_body.len and
            (struct_init_body[field_pos] == ' ' or
                struct_init_body[field_pos] == '\t' or
                struct_init_body[field_pos] == '\n' or
                struct_init_body[field_pos] == '\r')) : (field_pos += 1)
        {}

        if (field_pos >= struct_init_body.len) break;

        // Skip line comments
        if (field_pos + 1 < struct_init_body.len and
            struct_init_body[field_pos] == '/' and
            struct_init_body[field_pos + 1] == '/')
        {
            // Skip to end of line
            while (field_pos < struct_init_body.len and struct_init_body[field_pos] != '\n') : (field_pos += 1) {}
            continue;
        }

        // Look for ".field_name"
        if (struct_init_body[field_pos] != '.') {
            field_pos += 1;
            continue;
        }

        const field_name_start = field_pos + 1;
        var field_name_end = field_name_start;
        while (field_name_end < struct_init_body.len and
            (std.ascii.isAlphanumeric(struct_init_body[field_name_end]) or
                struct_init_body[field_name_end] == '_')) : (field_name_end += 1)
        {}

        const field_name = struct_init_body[field_name_start..field_name_end];

        // Find the "=" sign
        var eq_pos = field_name_end;
        while (eq_pos < struct_init_body.len and
            (struct_init_body[eq_pos] == ' ' or struct_init_body[eq_pos] == '\t')) : (eq_pos += 1)
        {}

        if (eq_pos >= struct_init_body.len or struct_init_body[eq_pos] != '=') {
            field_pos = field_name_end;
            continue;
        }

        // Find the value (until comma or closing brace, accounting for nesting)
        const value_start = eq_pos + 1;
        var value_end = value_start;
        var paren_depth_inner: i32 = 0;
        var brace_depth_inner: i32 = 0;
        var in_string = false;
        var escape_next = false;

        while (value_end < struct_init_body.len) : (value_end += 1) {
            const c = struct_init_body[value_end];

            if (escape_next) {
                escape_next = false;
                continue;
            }

            if (c == '\\') {
                escape_next = true;
                continue;
            }

            if (c == '"') {
                in_string = !in_string;
                continue;
            }

            if (in_string) continue;

            if (c == '(') paren_depth_inner += 1;
            if (c == ')') paren_depth_inner -= 1;
            if (c == '{') brace_depth_inner += 1;
            if (c == '}') brace_depth_inner -= 1;

            if (paren_depth_inner == 0 and brace_depth_inner == 0 and c == ',') {
                break;
            }
        }

        const value_raw = struct_init_body[value_start..value_end];
        const value_trimmed = std.mem.trim(u8, value_raw, " \t\n\r");

        // Parse the value into an InitExpression
        const init_expr = try parseInitExpression(allocator, value_trimmed);
        try init_map.put(try allocator.dupe(u8, field_name), init_expr);

        field_pos = value_end + 1;
    }

    return init_map;
}

/// Parse a single initialization expression
fn parseInitExpression(allocator: Allocator, value: []const u8) !ir.Field.InitExpression {
    // Null literal
    if (std.mem.eql(u8, value, "null")) {
        return .{ .literal = try allocator.dupe(u8, "null") };
    }

    // Boolean literals
    if (std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "false")) {
        return .{ .literal = try allocator.dupe(u8, value) };
    }

    // Numeric literals (simple check)
    if (value.len > 0 and (std.ascii.isDigit(value[0]) or value[0] == '-')) {
        // Could be a number
        var is_number = true;
        for (value) |c| {
            if (!std.ascii.isDigit(c) and c != '-' and c != '.') {
                is_number = false;
                break;
            }
        }
        if (is_number) {
            return .{ .literal = try allocator.dupe(u8, value) };
        }
    }

    // String literals
    if (value.len >= 2 and value[0] == '"' and value[value.len - 1] == '"') {
        return .{ .literal = try allocator.dupe(u8, value) };
    }

    // Empty struct literals
    if (std.mem.eql(u8, value, "{}") or std.mem.eql(u8, value, ".{}")) {
        return .{ .literal = try allocator.dupe(u8, value) };
    }

    // Function call: SomeType.init(...) or infra.List(...).init(...)
    if (std.mem.indexOf(u8, value, ".init(") != null or
        std.mem.indexOf(u8, value, ".{") != null)
    {
        // Extract function and arguments
        const fc = try parseFunctionCall(allocator, value);
        return .{ .function_call = .{ .function = fc.function, .args = fc.args } };
    }

    // Constant reference: Node.DOCUMENT_NODE, std.Thread.Mutex{}
    if (std.mem.indexOf(u8, value, "::") != null or
        std.mem.indexOf(u8, value, ".") != null)
    {
        // Check if it looks like a constant (starts with uppercase or module path)
        const first_part_end = std.mem.indexOf(u8, value, ".") orelse value.len;
        const first_part = value[0..first_part_end];

        if (first_part.len > 0 and std.ascii.isUpper(first_part[0])) {
            return .{ .constant_ref = try allocator.dupe(u8, value) };
        }
    }

    // Parameter reference (simple identifier)
    if (value.len > 0 and (std.ascii.isAlphabetic(value[0]) or value[0] == '_')) {
        var is_identifier = true;
        for (value) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '_') {
                is_identifier = false;
                break;
            }
        }
        if (is_identifier) {
            return .{ .parameter = try allocator.dupe(u8, value) };
        }
    }

    // Fallback: complex expression
    return .{ .complex = try allocator.dupe(u8, value) };
}

/// Parse a function call into function name and arguments
fn parseFunctionCall(
    allocator: Allocator,
    value: []const u8,
) !struct { function: []const u8, args: [][]const u8 } {
    // Find the opening paren
    const paren_pos = std.mem.lastIndexOf(u8, value, "(") orelse {
        return .{ .function = try allocator.dupe(u8, value), .args = &[_][]const u8{} };
    };

    const function_name = std.mem.trim(u8, value[0..paren_pos], " \t");

    // Find the closing paren
    const close_paren = std.mem.lastIndexOf(u8, value, ")") orelse paren_pos + 1;

    const args_str = value[paren_pos + 1 .. close_paren];

    // Split arguments by comma (accounting for nesting)
    var args_list = infra.List([]const u8).init(allocator);
    defer args_list.deinit();

    if (args_str.len == 0) {
        return .{
            .function = try allocator.dupe(u8, function_name),
            .args = &[_][]const u8{},
        };
    }

    var arg_start: usize = 0;
    var paren_depth: i32 = 0;
    var pos: usize = 0;

    while (pos < args_str.len) : (pos += 1) {
        if (args_str[pos] == '(') paren_depth += 1;
        if (args_str[pos] == ')') paren_depth -= 1;

        if (args_str[pos] == ',' and paren_depth == 0) {
            const arg = std.mem.trim(u8, args_str[arg_start..pos], " \t");
            if (arg.len > 0) {
                try args_list.append(try allocator.dupe(u8, arg));
            }
            arg_start = pos + 1;
        }
    }

    // Add last argument
    const last_arg = std.mem.trim(u8, args_str[arg_start..], " \t");
    if (last_arg.len > 0) {
        try args_list.append(try allocator.dupe(u8, last_arg));
    }

    return .{
        .function = try allocator.dupe(u8, function_name),
        .args = try args_list.toOwnedSlice(),
    };
}
