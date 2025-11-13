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
        for (fields.items) |*field| field.deinit(allocator);
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
        for (methods.items) |*method| method.deinit(allocator);
        methods.deinit();
    }

    var seen_methods = std.StringHashMap(void).init(allocator);
    defer seen_methods.deinit();

    // Add own methods first (for override detection)
    for (class.own_methods) |method| {
        try methods.append(try cloneMethod(allocator, method));
        try seen_methods.put(method.name, {});
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
        for (properties.items) |*prop| prop.deinit(allocator);
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
    registry: *ClassRegistry,
) ![]ir.Import {
    var imports = std.StringHashMap(ir.Import).init(allocator);
    defer imports.deinit();

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

    // Add inheritance-based imports
    if (inheritsFromNode(class, registry)) {
        try addNodeInheritanceImports(allocator, &imports, class.name);
    }

    if (inheritsFromEventTarget(class, registry)) {
        try addEventTargetInheritanceImports(allocator, &imports, class.name);
    }

    // Convert to array
    var result = infra.List(ir.Import).init(allocator);
    errdefer {
        for (result.items) |*import| import.deinit(allocator);
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

    // Skip if primitive or self-reference
    if (isPrimitiveType(base_type) or std.mem.eql(u8, base_type, current_class)) {
        return;
    }

    // Map type to module
    const module = typeToModule(base_type);
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

/// Add imports needed for Node inheritance
fn addNodeInheritanceImports(
    allocator: Allocator,
    imports: *std.StringHashMap(ir.Import),
    class_name: []const u8,
) !void {
    const node_types = [_]struct { name: []const u8, module: []const u8 }{
        .{ .name = "Node", .module = "node" },
        .{ .name = "ShadowRoot", .module = "shadow_root" },
        .{ .name = "Document", .module = "document" },
        .{ .name = "Element", .module = "element" },
        .{ .name = "Attr", .module = "attr" },
        .{ .name = "CharacterData", .module = "character_data" },
        .{ .name = "NodeList", .module = "node_list" },
        .{ .name = "RegisteredObserver", .module = "registered_observer" },
    };

    for (node_types) |type_info| {
        // Don't import if this IS that type
        if (std.mem.eql(u8, class_name, type_info.name)) continue;

        if (!imports.contains(type_info.name)) {
            try imports.put(type_info.name, ir.Import{
                .name = try allocator.dupe(u8, type_info.name),
                .module = try allocator.dupe(u8, type_info.module),
                .is_type = true,
                .visibility = .private,
                .source_line = 0,
            });
        }
    }
}

/// Add imports needed for EventTarget inheritance
fn addEventTargetInheritanceImports(
    allocator: Allocator,
    imports: *std.StringHashMap(ir.Import),
    class_name: []const u8,
) !void {
    _ = class_name;

    const event_types = [_]struct { name: []const u8, module: []const u8 }{
        .{ .name = "Event", .module = "event" },
        .{ .name = "EventListener", .module = "event_target" },
    };

    for (event_types) |type_info| {
        if (!imports.contains(type_info.name)) {
            try imports.put(type_info.name, ir.Import{
                .name = try allocator.dupe(u8, type_info.name),
                .module = try allocator.dupe(u8, type_info.module),
                .is_type = true,
                .visibility = .private,
                .source_line = 0,
            });
        }
    }
}

/// Check if class inherits from Node
fn inheritsFromNode(class: *ir.ClassDef, registry: *ClassRegistry) bool {
    var current: ?*ir.ClassDef = class;

    while (current) |c| {
        if (std.mem.eql(u8, c.name, "Node")) return true;

        if (c.parent) |parent_name| {
            current = registry.get(parent_name);
        } else {
            break;
        }
    }

    return false;
}

/// Check if class inherits from EventTarget
fn inheritsFromEventTarget(class: *ir.ClassDef, registry: *ClassRegistry) bool {
    var current: ?*ir.ClassDef = class;

    while (current) |c| {
        if (std.mem.eql(u8, c.name, "EventTarget")) return true;

        if (c.parent) |parent_name| {
            current = registry.get(parent_name);
        } else {
            break;
        }
    }

    return false;
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

fn typeToModule(type_name: []const u8) []const u8 {
    // Comprehensive type-to-module mapping
    const mapping = std.StaticStringMap([]const u8).initComptime(.{
        .{ "ShadowRoot", "shadow_root" },
        .{ "Node", "node" },
        .{ "Element", "element" },
        .{ "Document", "document" },
        .{ "CharacterData", "character_data" },
        .{ "Text", "text" },
        .{ "Comment", "comment" },
        .{ "CDATASection", "cdata_section" },
        .{ "ProcessingInstruction", "processing_instruction" },
        .{ "DocumentType", "document_type" },
        .{ "DocumentFragment", "document_fragment" },
        .{ "Attr", "attr" },
        .{ "NodeList", "node_list" },
        .{ "RegisteredObserver", "registered_observer" },
        .{ "Event", "event" },
        .{ "EventTarget", "event_target" },
        .{ "EventListener", "event_target" },
        .{ "AbortSignal", "abort_signal" },
        .{ "AbortController", "abort_controller" },
    });

    return mapping.get(type_name) orelse "";
}
