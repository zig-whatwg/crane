//! Intermediate Representation (IR) for WebIDL Code Generation
//!
//! This module defines the IR data structures used by the AST-based codegen.
//!
//! ## Architecture
//!
//! Source File → Parser → IR → Optimizer → Generator → Output File
//!
//! The IR captures the semantic structure of Zig source files in a way that's
//! easy to analyze and transform, without requiring complex string manipulation.
//!
//! ## Key Design Principles
//!
//! 1. **Type-aware**: Distinguishes between type imports and module imports
//! 2. **Scope-aware**: Tracks module-level vs local declarations
//! 3. **Context-preserving**: Maintains enough information to generate correct code
//! 4. **Analyzable**: Easy to detect conflicts, missing imports, etc.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Visibility modifier for declarations
pub const Visibility = enum {
    public, // pub const
    private, // const

    pub fn toString(self: Visibility) []const u8 {
        return switch (self) {
            .public => "pub ",
            .private => "",
        };
    }
};

/// A single import statement
pub const Import = struct {
    /// Import name (e.g., "ShadowRoot", "std", "infra")
    name: []const u8,

    /// Module path (e.g., "shadow_root", "std.mem")
    module: []const u8,

    /// Whether this imports a type vs a module
    /// Type: const ShadowRoot = @import("shadow_root").ShadowRoot;
    /// Module: const std = @import("std");
    is_type: bool,

    /// Public or private
    visibility: Visibility,

    /// Source location for debugging
    source_line: usize,

    pub fn format(
        self: Import,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("{s}const {s} = @import(\"{s}\")", .{
            self.visibility.toString(),
            self.name,
            self.module,
        });
        if (self.is_type) {
            try writer.print(".{s}", .{self.name});
        }
        try writer.writeAll(";\n");
    }

    pub fn deinit(self: *Import, allocator: Allocator) void {
        allocator.free(self.name);
        allocator.free(self.module);
    }

    /// Create a deep copy of this import
    pub fn duplicate(self: Import, allocator: Allocator) !Import {
        return Import{
            .name = try allocator.dupe(u8, self.name),
            .module = try allocator.dupe(u8, self.module),
            .is_type = self.is_type,
            .visibility = self.visibility,
            .source_line = self.source_line,
        };
    }
};

/// A type reference found in code (fields, parameters, return types)
pub const TypeReference = struct {
    /// Type name (e.g., "ShadowRoot", "*Node", "[]const u8")
    type_name: []const u8,

    /// Source location
    source_line: usize,

    /// Context where this type is used
    context: Context,

    pub const Context = enum {
        field_type,
        parameter_type,
        return_type,
        local_variable,
    };

    pub fn deinit(self: *TypeReference, allocator: Allocator) void {
        allocator.free(self.type_name);
    }
};

/// A field declaration
pub const Field = struct {
    name: []const u8,
    type_name: []const u8,
    doc_comment: ?[]const u8,
    source_line: usize,

    pub fn deinit(self: *Field, allocator: Allocator) void {
        allocator.free(self.name);
        allocator.free(self.type_name);
        if (self.doc_comment) |doc| {
            allocator.free(doc);
        }
    }
};

/// A method declaration
pub const Method = struct {
    name: []const u8,

    /// Full signature: (self: *Type, param: Type) !ReturnType
    signature: []const u8,

    /// Method body (as source text for now - will parse deeper later)
    body: []const u8,

    /// Type names referenced in signature and body
    referenced_types: [][]const u8,

    /// Doc comment
    doc_comment: ?[]const u8,

    /// Source location
    source_line: usize,

    /// Whether this is pub, inline, etc.
    modifiers: Modifiers,

    pub const Modifiers = struct {
        is_public: bool = true,
        is_inline: bool = false,
    };

    pub fn deinit(self: *Method, allocator: Allocator) void {
        allocator.free(self.name);
        allocator.free(self.signature);
        allocator.free(self.body);
        for (self.referenced_types) |type_name| {
            allocator.free(type_name);
        }
        allocator.free(self.referenced_types);
        if (self.doc_comment) |doc| {
            allocator.free(doc);
        }
    }
};

/// A constant declaration
pub const Constant = struct {
    name: []const u8,
    type_name: ?[]const u8, // null if inferred
    value: []const u8,
    visibility: Visibility,
    source_line: usize,

    pub fn deinit(self: *Constant, allocator: Allocator) void {
        allocator.free(self.name);
        if (self.type_name) |t| {
            allocator.free(t);
        }
        allocator.free(self.value);
    }
};

/// A property (WebIDL attribute)
pub const Property = struct {
    name: []const u8,
    type_name: []const u8,
    access: Access,
    doc_comment: ?[]const u8,
    source_line: usize,

    pub const Access = enum {
        read_only,
        read_write,
    };

    pub fn deinit(self: *Property, allocator: Allocator) void {
        allocator.free(self.name);
        allocator.free(self.type_name);
        if (self.doc_comment) |doc| {
            allocator.free(doc);
        }
    }
};

/// A complete class definition
pub const ClassDef = struct {
    name: []const u8,

    /// Parent class name (if any)
    parent: ?[]const u8,

    /// Mixin names
    mixins: [][]const u8,

    /// Fields directly defined in this class
    own_fields: []Field,

    /// Methods directly defined in this class
    own_methods: []Method,

    /// Properties directly defined in this class
    own_properties: []Property,

    /// Constants defined in this class
    own_constants: []Constant,

    /// Imports this class's methods reference
    /// (Does NOT include inherited imports)
    required_imports: []Import,

    /// Doc comment for the class
    doc_comment: ?[]const u8,

    /// Source file path
    source_file: []const u8,

    /// Class kind
    kind: Kind,

    pub const Kind = enum {
        interface,
        namespace,
        mixin,
    };

    pub fn deinit(self: *ClassDef, allocator: Allocator) void {
        allocator.free(self.name);
        if (self.parent) |p| {
            allocator.free(p);
        }
        for (self.mixins) |mixin| {
            allocator.free(mixin);
        }
        allocator.free(self.mixins);

        for (self.own_fields) |*field| {
            field.deinit(allocator);
        }
        allocator.free(self.own_fields);

        for (self.own_methods) |*method| {
            method.deinit(allocator);
        }
        allocator.free(self.own_methods);

        for (self.own_properties) |*prop| {
            prop.deinit(allocator);
        }
        allocator.free(self.own_properties);

        for (self.own_constants) |*constant| {
            constant.deinit(allocator);
        }
        allocator.free(self.own_constants);

        for (self.required_imports) |*import| {
            import.deinit(allocator);
        }
        allocator.free(self.required_imports);

        if (self.doc_comment) |doc| {
            allocator.free(doc);
        }
        allocator.free(self.source_file);
    }
};

/// Complete IR for a source file
pub const FileIR = struct {
    /// File path
    path: []const u8,

    /// Module-level imports (before any class definitions)
    module_imports: []Import,

    /// Classes defined in this file
    classes: []ClassDef,

    /// Module-level constants and declarations
    module_constants: []Constant,

    /// Module-level definitions (const, type, fn) that aren't classes
    /// This is raw source text that will be copied to the generated file
    module_definitions: []const u8,

    pub fn deinit(self: *FileIR, allocator: Allocator) void {
        allocator.free(self.path);

        for (self.module_imports) |*import| {
            import.deinit(allocator);
        }
        allocator.free(self.module_imports);

        for (self.classes) |*class| {
            class.deinit(allocator);
        }
        allocator.free(self.classes);

        for (self.module_constants) |*constant| {
            constant.deinit(allocator);
        }
        allocator.free(self.module_constants);

        allocator.free(self.module_definitions);
    }
};

/// Enhanced class IR after inheritance resolution
pub const EnhancedClassIR = struct {
    /// Original class definition
    class: ClassDef,

    /// All fields (own + inherited, flattened)
    all_fields: []Field,

    /// All methods (own + inherited, with overrides resolved)
    all_methods: []Method,

    /// All properties (own + inherited)
    all_properties: []Property,

    /// All imports needed (own + inherited, deduplicated)
    all_imports: []Import,

    pub fn deinit(self: *EnhancedClassIR, allocator: Allocator) void {
        // NOTE: Don't deinit self.class - it's just a copy of the original ClassDef
        // which is owned by FileIR. Only deinit the enhanced slices we created.

        for (self.all_fields) |*field| {
            field.deinit(allocator);
        }
        allocator.free(self.all_fields);

        for (self.all_methods) |*method| {
            method.deinit(allocator);
        }
        allocator.free(self.all_methods);

        for (self.all_properties) |*prop| {
            prop.deinit(allocator);
        }
        allocator.free(self.all_properties);

        for (self.all_imports) |*import| {
            import.deinit(allocator);
        }
        allocator.free(self.all_imports);
    }
};
