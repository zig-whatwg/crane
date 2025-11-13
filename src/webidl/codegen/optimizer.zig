//! IR Optimization Pass
//!
//! Analyzes and transforms IR to:
//! 1. Resolve inheritance (flatten parent fields/methods into child)
//! 2. Detect required imports from type references
//! 3. Resolve import conflicts (deduplicate, remove shadowing)
//! 4. Add missing imports
//! 5. Remove unused imports

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");
const ir = @import("ir.zig");

/// Registry of all classes for cross-file resolution
pub const ClassRegistry = struct {
    allocator: Allocator,
    classes: std.StringHashMap(*ir.ClassDef),

    pub fn init(allocator: Allocator) ClassRegistry {
        return .{
            .allocator = allocator,
            .classes = std.StringHashMap(*ir.ClassDef).init(allocator),
        };
    }

    pub fn deinit(self: *ClassRegistry) void {
        self.classes.deinit();
    }

    pub fn register(self: *ClassRegistry, class: *ir.ClassDef) !void {
        try self.classes.put(class.name, class);
    }

    pub fn get(self: *ClassRegistry, name: []const u8) ?*ir.ClassDef {
        return self.classes.get(name);
    }
};

/// Enhance a class with inherited members and resolved imports
pub fn enhanceClass(
    allocator: Allocator,
    class: *ir.ClassDef,
    registry: *ClassRegistry,
    module_imports: []const ir.Import,
) !ir.EnhancedClassIR {
    var enhanced = ir.EnhancedClassIR{
        .class = class.*,
        .all_fields = &.{},
        .all_methods = &.{},
        .all_properties = &.{},
        .all_imports = &.{},
    };

    // Collect all fields (own + inherited)
    enhanced.all_fields = try collectAllFields(allocator, class, registry);
    errdefer {
        for (enhanced.all_fields) |*field| field.deinit(allocator);
        allocator.free(enhanced.all_fields);
    }

    // Collect all methods (own + inherited, resolve overrides)
    enhanced.all_methods = try collectAllMethods(allocator, class, registry);
    errdefer {
        for (enhanced.all_methods) |*method| method.deinit(allocator);
        allocator.free(enhanced.all_methods);
    }

    // Collect all properties (own + inherited)
    enhanced.all_properties = try collectAllProperties(allocator, class, registry);
    errdefer {
        for (enhanced.all_properties) |*prop| prop.deinit(allocator);
        allocator.free(enhanced.all_properties);
    }

    // Resolve imports: detect all required imports and deduplicate
    enhanced.all_imports = try resolveImports(
        allocator,
        class,
        enhanced.all_fields,
        enhanced.all_methods,
        enhanced.all_properties,
        module_imports,
        registry,
    );

    return enhanced;
}

/// Collect all fields (own + inherited)
fn collectAllFields(
    allocator: Allocator,
    class: *ir.ClassDef,
    registry: *ClassRegistry,
) ![]ir.Field {
    var fields = infra.List(ir.Field).init(allocator);
    errdefer {
        for (fields.toSliceMut()) |*field| field.deinit(allocator);
        fields.deinit();
    }

    // Add inherited fields first (bottom-up)
    if (class.parent) |parent_name| {
        if (registry.get(parent_name)) |parent| {
            const parent_fields = try collectAllFields(allocator, parent, registry);
            defer {
                for (parent_fields) |*field| field.deinit(allocator);
                allocator.free(parent_fields);
            }
            for (parent_fields) |field| {
                try fields.append(try cloneField(allocator, field));
            }
        }
    }

    // Add mixin fields (before own fields)
    for (class.mixins) |mixin_name| {
        if (registry.get(mixin_name)) |mixin| {
            for (mixin.own_fields) |field| {
                try fields.append(try cloneField(allocator, field));
            }
        }
    }

    // Add own fields
    for (class.own_fields) |field| {
        try fields.append(try cloneField(allocator, field));
    }

    return fields.toOwnedSlice();
}

/// Collect all methods (own + inherited)
fn collectAllMethods(
    allocator: Allocator,
    class: *ir.ClassDef,
    registry: *ClassRegistry,
) ![]ir.Method {
    var methods = infra.List(ir.Method).init(allocator);
    errdefer {
        for (methods.toSliceMut()) |*method| method.deinit(allocator);
        methods.deinit();
    }

    var seen_methods = std.StringHashMap(void).init(allocator);
    defer seen_methods.deinit();

    // Add own methods first (for override detection)
    for (class.own_methods) |method| {
        try methods.append(try cloneMethod(allocator, method));
        try seen_methods.put(method.name, {});
    }

    // Add mixin methods (skip if overridden by own methods)
    for (class.mixins) |mixin_name| {
        if (registry.get(mixin_name)) |mixin| {
            for (mixin.own_methods) |method| {
                if (!seen_methods.contains(method.name)) {
                    try methods.append(try cloneMethod(allocator, method));
                    try seen_methods.put(method.name, {});
                }
            }
        }
    }

    // Add inherited methods (skip if overridden)
    if (class.parent) |parent_name| {
        if (registry.get(parent_name)) |parent| {
            const parent_methods = try collectAllMethods(allocator, parent, registry);
            defer {
                for (parent_methods) |*method| method.deinit(allocator);
                allocator.free(parent_methods);
            }
            for (parent_methods) |method| {
                if (!seen_methods.contains(method.name)) {
                    try methods.append(try cloneMethod(allocator, method));
                    try seen_methods.put(method.name, {});
                }
            }
        }
    }

    return methods.toOwnedSlice();
}

/// Collect all properties (own + inherited)
fn collectAllProperties(
    allocator: Allocator,
    class: *ir.ClassDef,
    registry: *ClassRegistry,
) ![]ir.Property {
    var properties = infra.List(ir.Property).init(allocator);
    errdefer {
        for (properties.toSliceMut()) |*prop| prop.deinit(allocator);
        properties.deinit();
    }

    // Add inherited properties first
    if (class.parent) |parent_name| {
        if (registry.get(parent_name)) |parent| {
            const parent_props = try collectAllProperties(allocator, parent, registry);
            defer {
                for (parent_props) |*prop| prop.deinit(allocator);
                allocator.free(parent_props);
            }
            for (parent_props) |prop| {
                try properties.append(try cloneProperty(allocator, prop));
            }
        }
    }

    // Add mixin properties (before own properties)
    for (class.mixins) |mixin_name| {
        if (registry.get(mixin_name)) |mixin| {
            for (mixin.own_properties) |prop| {
                try properties.append(try cloneProperty(allocator, prop));
            }
        }
    }

    // Add own properties
    for (class.own_properties) |prop| {
        try properties.append(try cloneProperty(allocator, prop));
    }

    return properties.toOwnedSlice();
}

/// Resolve all imports needed for this class
fn resolveImports(
    allocator: Allocator,
    class: *ir.ClassDef,
    all_fields: []ir.Field,
    all_methods: []ir.Method,
    all_properties: []ir.Property,
    module_imports: []const ir.Import,
    registry: *ClassRegistry,
) ![]ir.Import {
    var imports = std.StringHashMap(ir.Import).init(allocator);
    defer {
        // Clean up all Import contents before freeing HashMap
        var iter = imports.valueIterator();
        while (iter.next()) |import| {
            allocator.free(import.name);
            allocator.free(import.module);
        }
        imports.deinit();
    }

    // Add default imports that all classes need
    try imports.put("std", ir.Import{
        .name = try allocator.dupe(u8, "std"),
        .module = try allocator.dupe(u8, "std"),
        .is_type = false,
        .visibility = .private,
        .source_line = 0,
    });
    try imports.put("Allocator", ir.Import{
        .name = try allocator.dupe(u8, "Allocator"),
        .module = try allocator.dupe(u8, "std.mem"),
        .is_type = true,
        .visibility = .private,
        .source_line = 0,
    });
    try imports.put("webidl", ir.Import{
        .name = try allocator.dupe(u8, "webidl"),
        .module = try allocator.dupe(u8, "webidl"),
        .is_type = false,
        .visibility = .private,
        .source_line = 0,
    });

    // Add module-level imports from the source file
    // These include custom types, helper modules, etc. that the class needs
    for (module_imports) |module_import| {
        // Skip if already present (e.g., std, webidl already added above)
        if (imports.contains(module_import.name)) continue;

        try imports.put(module_import.name, ir.Import{
            .name = try allocator.dupe(u8, module_import.name),
            .module = try allocator.dupe(u8, module_import.module),
            .is_type = module_import.is_type,
            .visibility = module_import.visibility,
            .source_line = module_import.source_line,
        });
    }

    // Collect type references from fields
    for (all_fields) |field| {
        try addImportForType(allocator, &imports, field.type_name, class.name);
    }

    // Collect type references from methods
    for (all_methods) |method| {
        for (method.referenced_types) |type_name| {
            try addImportForType(allocator, &imports, type_name, class.name);
        }
    }

    // Collect type references from properties
    for (all_properties) |prop| {
        try addImportForType(allocator, &imports, prop.type_name, class.name);
    }

    // Note: No hardcoded inheritance-based imports
    // All types are detected automatically from method bodies via extractTypesFromCode
    _ = registry;

    // Convert to array
    var result = infra.List(ir.Import).init(allocator);
    errdefer {
        for (result.toSliceMut()) |*import| import.deinit(allocator);
        result.deinit();
    }

    var iter = imports.valueIterator();
    while (iter.next()) |import| {
        try result.append(try cloneImport(allocator, import.*));
    }

    return result.toOwnedSlice();
}

/// Add import for a type name (with deduplication)
fn addImportForType(
    allocator: Allocator,
    imports: *std.StringHashMap(ir.Import),
    type_name: []const u8,
    current_class: []const u8,
) !void {
    // Extract base type name
    var base_type = type_name;

    // Strip *, ?, []
    while (base_type.len > 0 and (base_type[0] == '*' or base_type[0] == '?' or base_type[0] == '[')) {
        base_type = base_type[1..];
    }

    // Strip "const "
    if (std.mem.startsWith(u8, base_type, "const ")) {
        base_type = base_type["const ".len..];
    }

    // If contains '(' (generic like std.ArrayList(EventListener)), extract inner types
    if (std.mem.indexOfScalar(u8, base_type, '(')) |paren_idx| {
        // Find matching closing paren
        var depth: usize = 0;
        var start_idx: ?usize = null;
        for (base_type[paren_idx..], 0..) |c, i| {
            if (c == '(') {
                depth += 1;
                if (depth == 1) start_idx = paren_idx + i + 1;
            } else if (c == ')') {
                depth -= 1;
                if (depth == 0 and start_idx != null) {
                    const inner = base_type[start_idx.? .. paren_idx + i];
                    // Recursively extract types from inner content
                    try addImportForType(allocator, imports, inner, current_class);
                    break;
                }
            }
        }
        return;
    }

    // Skip if contains '.' (already qualified like infra.List)
    if (std.mem.indexOfScalar(u8, base_type, '.') != null) {
        return;
    }

    // Skip if primitive or self-reference
    if (isPrimitiveType(base_type) or std.mem.eql(u8, base_type, current_class)) {
        return;
    }

    // Map type to module
    const special_case = typeToModule(base_type);

    // Track whether we need to free the module string
    var module_allocated = false;
    const module: []const u8 = if (special_case.len > 0 and !std.mem.eql(u8, special_case, base_type))
        special_case
    else blk: {
        // Convert PascalCase to snake_case
        // E.g., "EventTarget" -> "event_target", "HTMLCollection" -> "html_collection"
        var module_name_buf: std.ArrayList(u8) = .empty;
        defer module_name_buf.deinit(allocator);

        for (base_type, 0..) |c, i| {
            if (c >= 'A' and c <= 'Z') {
                // Uppercase letter
                if (i > 0) {
                    // Add underscore before uppercase (except first letter)
                    try module_name_buf.append(allocator, '_');
                }
                // Convert to lowercase
                try module_name_buf.append(allocator, c + 32);
            } else {
                // Lowercase or other character
                try module_name_buf.append(allocator, c);
            }
        }
        module_allocated = true;
        break :blk try module_name_buf.toOwnedSlice(allocator);
    };
    defer if (module_allocated) allocator.free(module);

    if (module.len == 0) return;

    // Add to imports (deduplicated by map)
    if (!imports.contains(base_type)) {
        try imports.put(base_type, ir.Import{
            .name = try allocator.dupe(u8, base_type),
            .module = try allocator.dupe(u8, module),
            .is_type = true,
            .visibility = .private,
            .source_line = 0,
        });
    }
}

// Helper functions

fn cloneField(allocator: Allocator, field: ir.Field) !ir.Field {
    return ir.Field{
        .name = try allocator.dupe(u8, field.name),
        .type_name = try allocator.dupe(u8, field.type_name),
        .doc_comment = if (field.doc_comment) |doc| try allocator.dupe(u8, doc) else null,
        .source_line = field.source_line,
    };
}

fn cloneMethod(allocator: Allocator, method: ir.Method) !ir.Method {
    var referenced_types = infra.List([]const u8).init(allocator);
    defer referenced_types.deinit();

    for (method.referenced_types) |type_name| {
        try referenced_types.append(try allocator.dupe(u8, type_name));
    }

    return ir.Method{
        .name = try allocator.dupe(u8, method.name),
        .signature = try allocator.dupe(u8, method.signature),
        .body = try allocator.dupe(u8, method.body),
        .referenced_types = try referenced_types.toOwnedSlice(),
        .doc_comment = if (method.doc_comment) |doc| try allocator.dupe(u8, doc) else null,
        .source_line = method.source_line,
        .modifiers = method.modifiers,
    };
}

fn cloneProperty(allocator: Allocator, prop: ir.Property) !ir.Property {
    return ir.Property{
        .name = try allocator.dupe(u8, prop.name),
        .type_name = try allocator.dupe(u8, prop.type_name),
        .access = prop.access,
        .doc_comment = if (prop.doc_comment) |doc| try allocator.dupe(u8, doc) else null,
        .source_line = prop.source_line,
    };
}

fn cloneImport(allocator: Allocator, import: ir.Import) !ir.Import {
    return ir.Import{
        .name = try allocator.dupe(u8, import.name),
        .module = try allocator.dupe(u8, import.module),
        .is_type = import.is_type,
        .visibility = import.visibility,
        .source_line = import.source_line,
    };
}

fn isPrimitiveType(type_name: []const u8) bool {
    const primitives = [_][]const u8{
        "u8",    "u16",   "u32",       "u64",
        "i8",    "i16",   "i32",       "i64",
        "f32",   "f64",   "bool",      "void",
        "usize", "isize", "Allocator", "anyerror",
    };

    for (primitives) |prim| {
        if (std.mem.eql(u8, type_name, prim)) return true;
    }
    return false;
}

/// Convert PascalCase type name to snake_case module name
/// Returns empty string if type should not be imported (not a real module)
fn typeToModule(type_name: []const u8) []const u8 {
    // Special cases where type name != module name
    if (std.mem.eql(u8, type_name, "EventListener")) return "event_target";

    // Skip types that aren't real modules (dictionaries, options, etc.)
    // These end with common suffixes
    if (std.mem.endsWith(u8, type_name, "Options") or
        std.mem.endsWith(u8, type_name, "Init") or
        std.mem.endsWith(u8, type_name, "Dict"))
    {
        return "";
    }

    // For most types, the module name is the snake_case version of the type
    // But since we can't allocate here, we'll use a heuristic:
    // The module is likely the lowercase version with underscores
    // However, we can't transform it here without allocation

    // Instead, return the type name itself and let the caller handle it
    // The caller (addImportForType) will need to do the conversion
    return type_name;
}
