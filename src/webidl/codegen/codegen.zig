//! # Code Generation Engine for WebIDL
//!
//! This module implements the core code generation logic for WebIDL. It scans
//! Zig source files, parses class definitions, resolves cross-file inheritance,
//! and generates enhanced code with method wrappers and property accessors.
//!
//! ## Architecture
//!
//! The code generator operates in two passes:
//!
//! ### Pass 1: Scan and Build Registry
//!
//! 1. Walk all `.zig` files in source directory
//! 2. Parse each file to find `webidl.interface()` calls
//! 3. Extract class definitions, parent classes, and imports
//! 4. Build a global registry of all classes and their relationships
//! 5. Detect circular inheritance
//!
//! ### Pass 2: Generate Code
//!
//! 1. For each file with classes:
//!    - Generate enhanced struct definitions
//!    - Flatten parent and mixin fields directly into child struct (no `.super` field)
//!    - Generate property getter/setter methods
//!    - Copy inherited method implementations with type rewriting (unless overridden)
//! 2. Write generated files to output directory (preserving structure)
//!
//! ## Cross-File Inheritance
//!
//! When a child class extends a parent from another file:
//!
//! ```zig
//! // file1.zig
//! const base = @import("base.zig");
//! const Child = webidl.interface(struct {
//!     pub const extends = base.Parent,
//! });
//! ```
//!
//! The generator:
//! 1. Parses the `@import("base.zig")` statement
//! 2. Resolves the relative path to find `base.zig`
//! 3. Looks up `Parent` class in the global registry
//! 4. Generates wrappers for `Parent`'s methods in `Child`
//!
//! ## Security
//!
//! - Path validation prevents traversal attacks (`..` blocked)
//! - Memory-safe: all allocations properly freed, `errdefer` on error paths
//! - No unsafe pointer casts
//!
//! ## Public API
//!
//! - `generateAllClasses()` - Main entry point for code generation
//! - `ClassConfig` - Configuration for method/property prefixes
//!
//! ## Implementation Details
//!
//! See IMPLEMENTATION.md for detailed architecture documentation.

const std = @import("std");
const parser = @import("parser.zig");
const optimizer = @import("optimizer.zig");
const generator = @import("generator.zig");
const ir = @import("ir.zig");

/// Maximum file size to prevent DoS attacks (5MB)
const MAX_FILE_SIZE = 5 * 1024 * 1024;

/// Maximum inheritance depth to prevent stack overflow
const MAX_INHERITANCE_DEPTH = 256;

/// Maximum type signature length to prevent DoS via complex signatures
const MAX_SIGNATURE_LENGTH = 1024;

/// Maximum type name length for validation
const MAX_TYPE_NAME_LENGTH = 256;

// Keyword and prefix length constants (replaces magic numbers throughout code)
const CONST_KEYWORD_LEN = "const ".len; // = 6
const EXTENDS_KEYWORD_LEN = "extends:".len; // = 8
const PUB_CONST_EXTENDS_LEN = "pub const extends".len; // = 17
const PTR_CONST_PREFIX_LEN = "*const ".len; // = 7
const PTR_PREFIX_LEN = "*".len; // = 1
const WEBIDL_INTERFACE_PREFIX_LEN = "webidl.interface(".len; // = 18
const WEBIDL_NAMESPACE_PREFIX_LEN = "webidl.namespace(".len; // = 18
const PUB_CONST_INCLUDES_LEN = "pub const includes".len; // = 18

/// Configuration for generated class method prefixes.
///
/// Controls the naming of generated wrapper methods and property accessors.
/// These settings are typically passed via command-line arguments to webidl-codegen.
///
/// See src/root.zig or src/class.zig for detailed documentation on usage.
pub const ClassConfig = struct {
    getter_prefix: []const u8 = "get_",
    setter_prefix: []const u8 = "set_",
};

/// Import Set - Manages deduplication of import declarations
///
/// This solves the root cause of duplicate declaration bugs by treating imports
/// as a set (no duplicates allowed) and coordinating between all code paths that
/// need to generate imports.
///
/// Usage:
/// ```zig
/// var imports = ImportSet.init(allocator);
/// defer imports.deinit();
///
/// try imports.addStdType("Allocator");
/// try imports.addPackageType("Node", "node");
/// try imports.addPackageConst("ELEMENT_NODE", "node");
///
/// try imports.emit(writer);
/// ```
const ImportSet = struct {
    allocator: std.mem.Allocator,
    /// Map from declaration name to its full code string
    /// Using StringArrayHashMap maintains insertion order for deterministic output
    declarations: std.StringArrayHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) ImportSet {
        return .{
            .allocator = allocator,
            .declarations = std.StringArrayHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *ImportSet) void {
        // Free all generated code strings
        // Note: StringArrayHashMap doesn't own its keys, so we must manage them
        var it = self.declarations.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.declarations.deinit();
    }

    /// Add a type from std library (e.g., "Allocator" -> "const Allocator = std.mem.Allocator;")
    pub fn addStdType(self: *ImportSet, name: []const u8) !void {
        if (self.declarations.contains(name)) return; // Already added

        const code = try std.fmt.allocPrint(self.allocator, "const {s} = std.mem.{s};\n", .{ name, name });
        try self.declarations.put(name, code);
    }

    /// Add a module import (e.g., "infra" -> "const infra = @import("infra");")
    pub fn addModule(self: *ImportSet, name: []const u8) !void {
        if (self.declarations.contains(name)) return;

        const code = try std.fmt.allocPrint(self.allocator, "const {s} = @import(\"{s}\");\n", .{ name, name });
        try self.declarations.put(name, code);
    }

    /// Add a type from a package (e.g., "Node", "node" -> "const Node = @import("node").Node;")
    pub fn addPackageType(self: *ImportSet, type_name: []const u8, package: []const u8) !void {
        if (self.declarations.contains(type_name)) return;

        const code = try std.fmt.allocPrint(self.allocator, "const {s} = @import(\"{s}\").{s};\n", .{ type_name, package, type_name });
        try self.declarations.put(type_name, code);
    }

    /// Add a constant from a package (e.g., "ELEMENT_NODE", "node" -> "const ELEMENT_NODE = @import("node").ELEMENT_NODE;")
    pub fn addPackageConst(self: *ImportSet, const_name: []const u8, package: []const u8) !void {
        if (self.declarations.contains(const_name)) return;

        const code = try std.fmt.allocPrint(self.allocator, "const {s} = @import(\"{s}\").{s};\n", .{ const_name, package, const_name });
        try self.declarations.put(const_name, code);
    }

    /// Add a raw declaration (for special cases)
    /// Takes ownership of the code string (does NOT duplicate it).
    pub fn addRawOwned(self: *ImportSet, name: []const u8, owned_code: []const u8) !void {
        if (self.declarations.contains(name)) {
            // Already exists, free the passed-in code to prevent leak
            self.allocator.free(owned_code);
            return;
        }

        try self.declarations.put(name, owned_code);
    }

    /// Add a raw declaration (duplicates the code string)
    pub fn addRaw(self: *ImportSet, name: []const u8, code: []const u8) !void {
        if (self.declarations.contains(name)) return;

        const owned_code = try self.allocator.dupe(u8, code);
        try self.declarations.put(name, owned_code);
    }

    /// Emit all imports to the writer in insertion order
    pub fn emit(self: *const ImportSet, writer: anytype) !void {
        var it = self.declarations.iterator();
        while (it.next()) |entry| {
            try writer.writeAll(entry.value_ptr.*);
        }
    }

    /// Add all imports needed for Node inheritance
    pub fn addNodeInheritanceImports(self: *ImportSet, class_name: []const u8) !void {
        try self.addPackageType("Node", "node");
        try self.addStdType("Allocator");
        try self.addModule("infra");
        try self.addPackageType("RegisteredObserver", "registered_observer");
        try self.addPackageType("GetRootNodeOptions", "node");

        // Don't import Document/Element/Attr/CharacterData if this IS one of them
        if (!std.mem.eql(u8, class_name, "Document")) {
            try self.addPackageType("Document", "document");
        }
        if (!std.mem.eql(u8, class_name, "Element")) {
            try self.addPackageType("Element", "element");
        }
        if (!std.mem.eql(u8, class_name, "Attr")) {
            try self.addPackageType("Attr", "attr");
        }
        if (!std.mem.eql(u8, class_name, "CharacterData")) {
            try self.addPackageType("CharacterData", "character_data");
        }

        // Add ShadowRoot (used by Node.getRootNode method)
        if (!std.mem.eql(u8, class_name, "ShadowRoot")) {
            try self.addPackageType("ShadowRoot", "shadow_root");
        }

        // Add NodeList (used by Node.childNodes getter)
        try self.addPackageType("NodeList", "node_list");

        // Add all Node type constants
        try self.addPackageConst("ELEMENT_NODE", "node");
        try self.addPackageConst("ATTRIBUTE_NODE", "node");
        try self.addPackageConst("TEXT_NODE", "node");
        try self.addPackageConst("CDATA_SECTION_NODE", "node");
        try self.addPackageConst("ENTITY_REFERENCE_NODE", "node");
        try self.addPackageConst("ENTITY_NODE", "node");
        try self.addPackageConst("PROCESSING_INSTRUCTION_NODE", "node");
        try self.addPackageConst("COMMENT_NODE", "node");
        try self.addPackageConst("DOCUMENT_NODE", "node");
        try self.addPackageConst("DOCUMENT_TYPE_NODE", "node");
        try self.addPackageConst("DOCUMENT_FRAGMENT_NODE", "node");
        try self.addPackageConst("NOTATION_NODE", "node");
        try self.addPackageConst("DOCUMENT_POSITION_DISCONNECTED", "node");
    }

    /// Add all imports needed for EventTarget inheritance
    pub fn addEventTargetInheritanceImports(self: *ImportSet) !void {
        try self.addPackageType("EventListener", "event_target");
        try self.addPackageType("Event", "event");

        // Helper functions from EventTarget
        const helpers = [_][]const u8{
            "flattenOptions",
            "flattenMoreOptions",
            "defaultPassiveValue",
            "callbackEquals",
        };
        for (helpers) |helper| {
            try self.addPackageConst(helper, "event_target");
        }
    }
};

/// Class generation specification
pub const ClassSpec = struct {
    name: []const u8,
    parent: ?type = null,
    definition: type,
    config: ClassConfig = .{},
};

/// Validate that a file path doesn't contain path traversal attempts.
/// Enhanced to prevent URL encoding and other bypass techniques.
fn isPathSafe(path: []const u8) bool {
    // Check for absolute paths
    if (path.len > 0 and path[0] == '/') return false;

    // Check for Windows absolute paths (C:, D:, etc.)
    if (path.len >= 2 and path[1] == ':') return false;

    // Check for parent directory references
    if (std.mem.indexOf(u8, path, "..") != null) return false;

    // Check for backslashes (Windows path separator, could be used for traversal)
    if (std.mem.indexOf(u8, path, "\\") != null) return false;

    // Check for null bytes (path truncation attack)
    if (std.mem.indexOfScalar(u8, path, 0) != null) return false;

    // Check for URL-encoded path traversal attempts
    if (std.mem.indexOf(u8, path, "%2e") != null or std.mem.indexOf(u8, path, "%2E") != null) return false;

    // Check for double-encoded attempts
    if (std.mem.indexOf(u8, path, "%252e") != null or std.mem.indexOf(u8, path, "%252E") != null) return false;

    // Check for control characters that could interfere with terminals or parsers
    for (path) |c| {
        if (c < 32 and c != '\n' and c != '\r' and c != '\t') return false;
    }

    return true;
}

/// Validate that a type name is safe (alphanumeric + underscore, not starting with digit).
/// Prevents injection attacks by ensuring type names follow Zig identifier rules.
fn isValidTypeName(name: []const u8) bool {
    if (name.len == 0 or name.len > MAX_TYPE_NAME_LENGTH) return false;

    // First character must be letter or underscore
    if (!std.ascii.isAlphabetic(name[0]) and name[0] != '_') return false;

    // Remaining characters: alphanumeric, underscore, or dot (for namespaced types like base.Type)
    for (name[1..]) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '.') return false;
    }

    return true;
}

/// Main entry point: Generate all classes in source directory.
///
/// ## Thread Safety
///
/// **WARNING: This function is NOT thread-safe.**
///
/// Do not call this function concurrently from multiple threads. The GlobalRegistry
/// uses non-atomic HashMap operations that will cause data races if accessed in parallel.
///
/// This limitation exists because:
/// - GlobalRegistry.files is a HashMap without synchronization
/// - File I/O operations share mutable state
/// - ArrayListUnmanaged operations are not thread-safe
///
/// If parallel code generation is needed in the future, consider:
/// - Adding a mutex around GlobalRegistry operations
/// - Using thread-local registries and merging results
/// - Implementing a concurrent-safe registry with std.Thread.Mutex
///
/// ## Parameters
///
/// - `allocator` - Memory allocator for temporary allocations during generation
/// - `source_dir` - Directory to scan for `.zig` files containing `webidl.interface()` calls
/// - `output_dir` - Directory where generated code will be written
/// - `config` - Configuration for method/property prefix naming
///
/// ## Example
///
/// ```zig
/// const allocator = std.heap.page_allocator;
/// try generateAllClasses(
///     allocator,
///     "src",
///     ".zig-cache/zoop-generated",
///     .{
///         .method_prefix = "call_",
///         .getter_prefix = "get_",
///         .setter_prefix = "set_",
///     },
/// );
/// ```
pub fn generateAllClasses(
    allocator: std.mem.Allocator,
    source_dir: []const u8,
    output_dir: []const u8,
    config: ClassConfig,
) !void {
    _ = config; // TODO: Use config for property prefixes in generator

    // Create output directory
    std.fs.cwd().makePath(output_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    // Initialize AST/IR class registry
    var ast_registry = optimizer.ClassRegistry.init(allocator);
    defer ast_registry.deinit();

    // Track files with classes (path -> FileIR)
    var file_irs = std.StringHashMap(ir.FileIR).init(allocator);
    defer {
        var it = file_irs.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            var file_ir = entry.value_ptr.*;
            file_ir.deinit(allocator);
        }
        file_irs.deinit();
    }

    // PASS 1: Scan all files and parse into IR
    var source_dir_handle = try std.fs.cwd().openDir(source_dir, .{ .iterate = true });
    defer source_dir_handle.close();

    var walker = try source_dir_handle.walk(allocator);
    defer walker.deinit();

    var files_processed: usize = 0;

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, ".zig")) continue;

        // Validate path for security
        if (!isPathSafe(entry.path)) {
            std.debug.print("Warning: Skipping file with unsafe path: {s}\n", .{entry.path});
            continue;
        }

        files_processed += 1;

        const source_path = try std.fs.path.join(allocator, &.{ source_dir, entry.path });
        defer allocator.free(source_path);

        const source_content = try std.fs.cwd().readFileAlloc(
            allocator,
            source_path,
            10 * 1024 * 1024,
        );
        defer allocator.free(source_content);

        // Check if file contains WebIDL declarations
        if (std.mem.indexOf(u8, source_content, "webidl.interface(") != null or
            std.mem.indexOf(u8, source_content, "webidl.namespace(") != null or
            std.mem.indexOf(u8, source_content, "webidl.mixin(") != null)
        {
            // Parse file into IR
            var file_ir = try parser.parseFile(allocator, source_content, entry.path);
            errdefer file_ir.deinit(allocator);

            // Skip files with no classes
            if (file_ir.classes.len == 0) {
                file_ir.deinit(allocator);
                continue;
            }

            // Register all classes in this file
            for (file_ir.classes) |*class| {
                try ast_registry.register(class);
            }

            // Store FileIR for Pass 2
            const path_owned = try allocator.dupe(u8, entry.path);
            try file_irs.put(path_owned, file_ir);
        }
    }

    // PASS 2: Enhance and generate code for each file
    var classes_generated: usize = 0;
    var file_it = file_irs.iterator();

    while (file_it.next()) |entry| {
        const file_path = entry.key_ptr.*;
        const file_ir = entry.value_ptr.*;

        // Validate path again before writing (defense in depth)
        if (!isPathSafe(file_path)) {
            std.debug.print("Error: Refusing to write file with unsafe path: {s}\n", .{file_path});
            return error.UnsafePath;
        }

        // Generate code using AST/IR pipeline
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(allocator);

        const writer = output.writer(allocator);

        // Process each class in the file
        for (file_ir.classes, 0..) |*class, idx| {
            var enhanced = try optimizer.enhanceClass(allocator, class, &ast_registry, file_ir.module_imports, file_ir.module_definitions, file_ir.module_constants, file_ir.post_class_definitions);
            defer enhanced.deinit(allocator);

            // All classes get module definitions (helper functions need to be accessible)
            // Post-class definitions only for the last class
            const post_class_defs = if (idx == file_ir.classes.len - 1) file_ir.post_class_definitions else null;
            const class_code = try generator.generateCode(allocator, enhanced, file_ir.module_definitions, post_class_defs);
            defer allocator.free(class_code);

            try writer.writeAll(class_code);
            try writer.writeAll("\n\n");
        }

        // Write to output file
        const output_path = try std.fs.path.join(allocator, &.{ output_dir, file_path });
        defer allocator.free(output_path);

        if (std.fs.path.dirname(output_path)) |parent_dir| {
            std.fs.cwd().makePath(parent_dir) catch |err| switch (err) {
                error.PathAlreadyExists => {},
                else => return err,
            };
        }

        const output_file = try std.fs.cwd().createFile(output_path, .{});
        defer output_file.close();

        try output_file.writeAll(output.items);

        classes_generated += 1;
        std.debug.print("  Generated: {s}\n", .{file_path});
    }

    std.debug.print("\nProcessed {} files, generated {} class files\n", .{ files_processed, classes_generated });
}

/// Parsed method definition
pub const MethodDef = struct {
    name: []const u8,
    source: []const u8,
    signature: []const u8,
    return_type: []const u8,
    is_static: bool = false,
    doc_comment: ?[]const u8 = null,
};

/// Parsed field definition
pub const FieldDef = struct {
    name: []const u8,
    type_name: []const u8,
    default_value: ?[]const u8,
    estimated_size: usize = 0,
    doc_comment: ?[]const u8 = null,
};

/// Property access mode
const PropertyAccess = enum {
    read_only,
    read_write,
};

/// Parsed property definition
pub const PropertyDef = struct {
    name: []const u8,
    type_name: []const u8,
    access: PropertyAccess,
    default_value: ?[]const u8,
    doc_comment: ?[]const u8 = null,
};

/// Parsed class definition
const ParsedClass = struct {
    name: []const u8,
    parent_name: ?[]const u8,
    mixin_names: [][]const u8,
    fields: []FieldDef,
    methods: []MethodDef,
    properties: []PropertyDef,
    constants: [][]const u8, // Raw constant declarations like "pub const NONE: u16 = 0;"
    allocator: std.mem.Allocator,
    file_doc: ?[]const u8 = null,
    class_doc: ?[]const u8 = null,
    has_self_type: bool = false,

    fn deinit(self: *ParsedClass) void {
        for (self.mixin_names) |mixin_name| {
            self.allocator.free(mixin_name);
        }
        self.allocator.free(self.mixin_names);

        // Free doc comments in fields
        for (self.fields) |field| {
            if (field.doc_comment) |doc| {
                self.allocator.free(doc);
            }
        }
        self.allocator.free(self.fields);

        // Free doc comments in methods
        for (self.methods) |method| {
            if (method.doc_comment) |doc| {
                self.allocator.free(doc);
            }
        }
        self.allocator.free(self.methods);

        // Free doc comments in properties
        for (self.properties) |prop| {
            if (prop.doc_comment) |doc| {
                self.allocator.free(doc);
            }
        }
        self.allocator.free(self.properties);

        // Free constants
        for (self.constants) |constant| {
            self.allocator.free(constant);
        }
        self.allocator.free(self.constants);

        if (self.file_doc) |doc| {
            self.allocator.free(doc);
        }
        if (self.class_doc) |doc| {
            self.allocator.free(doc);
        }
    }
};

/// WebIDL exposure scope for [Exposed] attribute
const ExposureScope = enum {
    global, // [Exposed=*] - Global/everywhere
    Window,
    Worker,
    DedicatedWorker,
    SharedWorker,
    ServiceWorker,
};

/// WebIDL extended attributes (parsed from interface options)
const WebIDLOptions = struct {
    exposed: ?[]ExposureScope = null,
    transferable: bool = false,
    serializable: bool = false,
    secure_context: bool = false,
    cross_origin_isolated: bool = false,
    // Legacy attributes (not commonly used, so we'll parse them later if needed)
    // global, legacy_factory_function, etc.
};

const ClassInfo = struct {
    name: []const u8,
    parent_name: ?[]const u8,
    mixin_names: [][]const u8, // List of mixin class references
    fields: []FieldDef,
    methods: []MethodDef,
    properties: []PropertyDef,
    constants: [][]const u8, // Raw constant declarations
    source_start: usize,
    source_end: usize,
    file_path: []const u8,
    has_self_type: bool = false,

    // WebIDL extended attributes
    webidl_options: WebIDLOptions = .{},
    class_kind: ClassKind = .interface, // interface, namespace, or mixin
};

const ClassKind = enum {
    interface,
    namespace,
    mixin,
};

/// Information about a base type (interface with no parent but has children)
/// Used to generate XxxBase structs for polymorphism support
const BaseTypeInfo = struct {
    /// Name of the base type (e.g., "Node")
    name: []const u8,
    /// List of direct and indirect children (e.g., ["Element", "Text", "Comment"])
    children: std.ArrayList([]const u8),
    /// File path where the base type is defined
    file_path: []const u8,
    /// Original ClassInfo for the base type
    class_info: ClassInfo,
};

const FileInfo = struct {
    path: []const u8,
    imports: std.StringHashMap([]const u8),
    classes: std.ArrayListUnmanaged(ClassInfo),
    source_content: []const u8,
};

/// Cache entry for a single zoop source file
const CacheEntry = struct {
    /// Path to the source file (relative to source directory)
    source_path: []const u8,
    /// SHA-256 hash of source file content
    content_hash: [32]u8,
    /// Modification timestamp (nanoseconds since epoch)
    mtime_ns: i128,
    /// List of class names defined in this file
    class_names: [][]const u8,
    /// List of parent class names (for dependency tracking)
    parent_names: [][]const u8,
};

/// Cache manifest containing all file cache entries
const CacheManifest = struct {
    /// Version of the cache format (for future compatibility)
    version: u32 = 1,
    /// Map of source file path -> cache entry
    entries: std.StringHashMap(CacheEntry),

    fn init(allocator: std.mem.Allocator) CacheManifest {
        return .{
            .entries = std.StringHashMap(CacheEntry).init(allocator),
        };
    }

    fn deinit(self: *CacheManifest, allocator: std.mem.Allocator) void {
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.source_path);
            for (entry.value_ptr.class_names) |name| {
                allocator.free(name);
            }
            allocator.free(entry.value_ptr.class_names);
            for (entry.value_ptr.parent_names) |name| {
                allocator.free(name);
            }
            allocator.free(entry.value_ptr.parent_names);
        }
        self.entries.deinit();
    }

    /// Load cache manifest from file
    fn load(allocator: std.mem.Allocator, cache_path: []const u8) !CacheManifest {
        const file = std.fs.cwd().openFile(cache_path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                // No cache exists yet, return empty manifest
                return CacheManifest.init(allocator);
            }
            return err;
        };
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024); // 10MB max
        defer allocator.free(content);

        return try parseManifest(allocator, content);
    }

    /// Save cache manifest to file
    fn save(self: *const CacheManifest, allocator: std.mem.Allocator, cache_path: []const u8) !void {
        const json_str = try serializeManifest(allocator, self);
        defer allocator.free(json_str);

        // Ensure .zig-cache directory exists
        const dir_path = std.fs.path.dirname(cache_path) orelse ".zig-cache";
        try std.fs.cwd().makePath(dir_path);

        const file = try std.fs.cwd().createFile(cache_path, .{});
        defer file.close();

        try file.writeAll(json_str);
    }
};

/// Parse JSON cache manifest
fn parseManifest(allocator: std.mem.Allocator, json_str: []const u8) !CacheManifest {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    var manifest = CacheManifest.init(allocator);
    errdefer manifest.deinit(allocator);

    const root = parsed.value.object;
    const version = @as(u32, @intCast(root.get("version").?.integer));
    manifest.version = version;

    const entries_obj = root.get("entries").?.object;
    var entries_it = entries_obj.iterator();
    while (entries_it.next()) |kv| {
        const entry_obj = kv.value_ptr.object;

        const source_path = try allocator.dupe(u8, entry_obj.get("source_path").?.string);
        errdefer allocator.free(source_path);

        const hash_hex = entry_obj.get("content_hash").?.string;
        var content_hash: [32]u8 = undefined;
        _ = try std.fmt.hexToBytes(&content_hash, hash_hex);

        const mtime_ns = entry_obj.get("mtime_ns").?.integer;

        const class_names_arr = entry_obj.get("class_names").?.array;
        const class_names = try allocator.alloc([]const u8, class_names_arr.items.len);
        errdefer allocator.free(class_names);
        for (class_names_arr.items, 0..) |item, i| {
            class_names[i] = try allocator.dupe(u8, item.string);
        }

        const parent_names_arr = entry_obj.get("parent_names").?.array;
        const parent_names = try allocator.alloc([]const u8, parent_names_arr.items.len);
        errdefer allocator.free(parent_names);
        for (parent_names_arr.items, 0..) |item, i| {
            parent_names[i] = try allocator.dupe(u8, item.string);
        }

        const entry = CacheEntry{
            .source_path = source_path,
            .content_hash = content_hash,
            .mtime_ns = mtime_ns,
            .class_names = class_names,
            .parent_names = parent_names,
        };

        const key = try allocator.dupe(u8, kv.key_ptr.*);
        try manifest.entries.put(key, entry);
    }

    return manifest;
}

/// Write a JSON-escaped string
fn writeJsonString(writer: anytype, str: []const u8) !void {
    try writer.writeByte('"');
    for (str) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => try writer.writeByte(c),
        }
    }
    try writer.writeByte('"');
}

/// Serialize cache manifest to JSON
fn serializeManifest(allocator: std.mem.Allocator, manifest: *const CacheManifest) ![]const u8 {
    var json_buf = std.ArrayList(u8){};
    errdefer json_buf.deinit(allocator);

    var writer = json_buf.writer(allocator);

    try writer.writeAll("{\"version\":");
    try writer.print("{d}", .{manifest.version});
    try writer.writeAll(",\"entries\":{");

    var first = true;
    var it = manifest.entries.iterator();
    while (it.next()) |kv| {
        if (!first) try writer.writeAll(",");
        first = false;

        try writeJsonString(writer, kv.key_ptr.*);
        try writer.writeAll(":{");

        try writer.writeAll("\"source_path\":");
        try writeJsonString(writer, kv.value_ptr.source_path);

        try writer.writeAll(",\"content_hash\":\"");
        for (kv.value_ptr.content_hash) |byte| {
            try writer.print("{x:0>2}", .{byte});
        }
        try writer.writeAll("\"");

        try writer.writeAll(",\"mtime_ns\":");
        try writer.print("{d}", .{kv.value_ptr.mtime_ns});

        try writer.writeAll(",\"class_names\":[");
        for (kv.value_ptr.class_names, 0..) |name, i| {
            if (i > 0) try writer.writeAll(",");
            try writeJsonString(writer, name);
        }
        try writer.writeAll("]");

        try writer.writeAll(",\"parent_names\":[");
        for (kv.value_ptr.parent_names, 0..) |name, i| {
            if (i > 0) try writer.writeAll(",");
            try writeJsonString(writer, name);
        }
        try writer.writeAll("]");

        try writer.writeAll("}");
    }

    try writer.writeAll("}}");

    return json_buf.toOwnedSlice(allocator);
}

/// Compute SHA-256 hash of file content
fn computeContentHash(content: []const u8) [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(content);
    var hash: [32]u8 = undefined;
    hasher.final(&hash);
    return hash;
}

/// Get file modification time in nanoseconds
fn getFileMtime(file_path: []const u8) !i128 {
    const stat = try std.fs.cwd().statFile(file_path);
    return stat.mtime;
}

/// Check if a file needs regeneration based on cache
fn needsRegeneration(
    allocator: std.mem.Allocator,
    source_path: []const u8,
    source_content: []const u8,
    cache_entry: ?CacheEntry,
) !bool {
    // If no cache entry exists, definitely need to regenerate
    if (cache_entry == null) return true;

    const entry = cache_entry.?;

    // Check timestamp first (fast check)
    const current_mtime = try getFileMtime(source_path);
    if (current_mtime != entry.mtime_ns) {
        // Timestamp changed, check content hash
        const current_hash = computeContentHash(source_content);
        if (!std.mem.eql(u8, &current_hash, &entry.content_hash)) {
            // Content actually changed
            return true;
        }
        // Timestamp changed but content is same (e.g., git checkout)
        // Still regenerate to update timestamp in cache
        return true;
    }

    // Timestamp unchanged, assume file is unchanged
    _ = allocator;
    return false;
}

/// Global registry of all classes found during code generation.
///
/// **THREAD SAFETY: NOT THREAD-SAFE**
///
/// This structure is NOT safe for concurrent access. All operations on the
/// registry use non-atomic HashMap operations. Concurrent access will cause
/// data races and undefined behavior.
///
/// ## Internal State
///
/// - `files`: HashMap mapping file paths to FileInfo (NOT thread-safe)
/// - `classes`: ArrayListUnmanaged (NOT thread-safe)
/// - `string_pool`: String interning pool for class/type names (NOT thread-safe)
/// - All operations assume single-threaded access
///
/// ## String Interning
///
/// The registry maintains a string pool to deduplicate class names and type
/// references. This reduces memory usage on large projects where the same
/// class names appear multiple times (in parent references, imports, etc.).
///
/// ## Usage
///
/// Always use within a single thread or protect with external synchronization.
const GlobalRegistry = struct {
    allocator: std.mem.Allocator,
    files: std.StringHashMap(FileInfo),
    string_pool: std.StringHashMap(void), // Interned strings
    mixins: std.StringHashMap(ClassInfo), // Map of mixin name -> ClassInfo

    fn init(allocator: std.mem.Allocator) GlobalRegistry {
        return .{
            .allocator = allocator,
            .files = std.StringHashMap(FileInfo).init(allocator),
            .string_pool = std.StringHashMap(void).init(allocator),
            .mixins = std.StringHashMap(ClassInfo).init(allocator),
        };
    }

    /// Intern a string in the pool. Returns a reference to the pooled string.
    /// If the string already exists in the pool, returns the existing reference.
    /// This reduces memory usage by deduplicating strings.
    fn internString(self: *GlobalRegistry, str: []const u8) ![]const u8 {
        const gop = try self.string_pool.getOrPut(str);
        if (!gop.found_existing) {
            // Allocate and store the string
            const owned = try self.allocator.dupe(u8, str);
            gop.key_ptr.* = owned;
        }
        return gop.key_ptr.*;
    }

    fn deinit(self: *GlobalRegistry) void {
        var it = self.files.iterator();
        while (it.next()) |entry| {
            var import_it = entry.value_ptr.imports.iterator();
            while (import_it.next()) |import_entry| {
                self.allocator.free(import_entry.key_ptr.*);
                self.allocator.free(import_entry.value_ptr.*);
            }
            entry.value_ptr.imports.deinit();

            for (entry.value_ptr.classes.items) |class_info| {
                // Note: class_info.name, parent_name, and mixin_names elements
                // are interned strings freed from the string pool, not here
                self.allocator.free(class_info.mixin_names); // Free the array, not the strings

                // Free doc comments in fields
                for (class_info.fields) |field| {
                    if (field.doc_comment) |doc| {
                        self.allocator.free(doc);
                    }
                }
                self.allocator.free(class_info.fields);

                // Free doc comments in methods
                for (class_info.methods) |method| {
                    if (method.doc_comment) |doc| {
                        self.allocator.free(doc);
                    }
                }
                self.allocator.free(class_info.methods);

                // Free doc comments in properties
                for (class_info.properties) |prop| {
                    if (prop.doc_comment) |doc| {
                        self.allocator.free(doc);
                    }
                }
                self.allocator.free(class_info.properties);

                // Free constants (both individual strings and array)
                for (class_info.constants) |constant| {
                    self.allocator.free(constant);
                }
                self.allocator.free(class_info.constants);

                // Free WebIDL options (exposed scopes)
                if (class_info.webidl_options.exposed) |exposed| {
                    self.allocator.free(exposed);
                }
            }
            entry.value_ptr.classes.deinit(self.allocator);
            self.allocator.free(entry.value_ptr.source_content);
            self.allocator.free(entry.value_ptr.path);
        }
        self.files.deinit();

        // Free all interned strings from the pool
        var pool_it = self.string_pool.iterator();
        while (pool_it.next()) |pool_entry| {
            self.allocator.free(pool_entry.key_ptr.*);
        }
        self.string_pool.deinit();

        // Free mixins registry (mixin ClassInfo data is already freed from files)
        self.mixins.deinit();
    }

    fn addClass(self: *GlobalRegistry, file_path: []const u8, class_info: ClassInfo) !void {
        const file_info = self.files.getPtr(file_path) orelse return error.FileNotFound;
        try file_info.classes.append(class_info);
    }

    fn getClass(self: *GlobalRegistry, file_path: []const u8, class_name: []const u8) ?ClassInfo {
        const file_info = self.files.get(file_path) orelse return null;
        for (file_info.classes.items) |class_info| {
            if (std.mem.eql(u8, class_info.name, class_name)) {
                return class_info;
            }
        }
        return null;
    }

    /// Register a mixin in the global registry
    fn addMixin(self: *GlobalRegistry, mixin_name: []const u8, mixin_info: ClassInfo) !void {
        try self.mixins.put(mixin_name, mixin_info);
    }

    /// Get a mixin by name from the global registry
    fn getMixin(self: *GlobalRegistry, mixin_name: []const u8) ?ClassInfo {
        return self.mixins.get(mixin_name);
    }

    /// Build a map of class name -> list of descendant class names
    /// This includes both direct children and all transitive descendants
    fn buildDescendantMap(self: *GlobalRegistry) !std.StringHashMap(std.ArrayList([]const u8)) {
        var descendant_map = std.StringHashMap(std.ArrayList([]const u8)).init(self.allocator);
        errdefer {
            var it = descendant_map.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.deinit(self.allocator);
            }
            descendant_map.deinit();
        }

        // First pass: collect direct children
        var file_it = self.files.iterator();
        while (file_it.next()) |file_entry| {
            for (file_entry.value_ptr.classes.items) |class_info| {
                if (class_info.parent_name) |parent_name| {
                    const gop = try descendant_map.getOrPut(parent_name);
                    if (!gop.found_existing) {
                        gop.value_ptr.* = .{};
                    }
                    try gop.value_ptr.append(self.allocator, class_info.name);
                }
            }
        }

        // Second pass: add transitive descendants
        // For each class, recursively add descendants of its children
        var class_names = std.ArrayList([]const u8){};
        defer class_names.deinit(self.allocator);

        var keys_it = descendant_map.keyIterator();
        while (keys_it.next()) |key| {
            try class_names.append(self.allocator, key.*);
        }

        for (class_names.items) |class_name| {
            var all_descendants = std.ArrayList([]const u8){};
            defer all_descendants.deinit(self.allocator);

            try collectAllDescendants(self.allocator, class_name, &descendant_map, &all_descendants);

            // Update the map with all descendants
            const existing = descendant_map.getPtr(class_name).?;
            existing.deinit(self.allocator);
            existing.* = try all_descendants.clone(self.allocator);
        }

        return descendant_map;
    }

    /// Helper to recursively collect all descendants of a class
    fn collectAllDescendants(
        allocator: std.mem.Allocator,
        class_name: []const u8,
        descendant_map: *std.StringHashMap(std.ArrayList([]const u8)),
        result: *std.ArrayList([]const u8),
    ) !void {
        const direct_children = descendant_map.get(class_name) orelse return;

        for (direct_children.items) |child| {
            // Add this child if not already in result
            var already_added = false;
            for (result.items) |existing| {
                if (std.mem.eql(u8, existing, child)) {
                    already_added = true;
                    break;
                }
            }
            if (!already_added) {
                try result.append(allocator, child);
                // Recursively add descendants of this child
                try collectAllDescendants(allocator, child, descendant_map, result);
            }
        }
    }

    fn resolveParentReference(
        self: *GlobalRegistry,
        parent_ref: []const u8,
        current_file: []const u8,
    ) !?ClassInfo {
        const dot_pos = std.mem.indexOfScalar(u8, parent_ref, '.');

        if (dot_pos) |pos| {
            const import_alias = parent_ref[0..pos];
            const class_name = parent_ref[pos + 1 ..];

            const file_info = self.files.get(current_file) orelse {
                return error.FileNotFound;
            };
            const imported_file = file_info.imports.get(import_alias) orelse {
                return null;
            };

            return self.getClass(imported_file, class_name);
        } else {
            const file_info = self.files.get(current_file) orelse {
                return error.FileNotFound;
            };

            const import_ref = file_info.imports.get(parent_ref);
            if (import_ref) |ref| {
                const ref_dot_pos = std.mem.lastIndexOfScalar(u8, ref, '.');
                if (ref_dot_pos) |ref_pos| {
                    const file_path = ref[0..ref_pos];
                    const class_name = ref[ref_pos + 1 ..];

                    // Try exact match first
                    if (self.getClass(file_path, class_name)) |class_info| {
                        return class_info;
                    }

                    // Try with .zig extension (handles dom/event_target vs dom/EventTarget.zig)
                    const with_ext = try std.fmt.allocPrint(self.allocator, "{s}.zig", .{file_path});
                    defer self.allocator.free(with_ext);
                    if (self.getClass(with_ext, class_name)) |class_info| {
                        return class_info;
                    }

                    // Try PascalCase filename with .zig (event_target → EventTarget.zig)
                    if (std.fs.path.dirname(file_path)) |dir| {
                        const basename = std.fs.path.basename(file_path);
                        // Convert snake_case to PascalCase
                        var pascal_name: std.ArrayList(u8) = .empty;
                        defer pascal_name.deinit(self.allocator);

                        var capitalize_next = true;
                        for (basename) |c| {
                            if (c == '_') {
                                capitalize_next = true;
                            } else if (capitalize_next) {
                                const upper = if (c >= 'a' and c <= 'z') c - 32 else c;
                                try pascal_name.append(self.allocator, upper);
                                capitalize_next = false;
                            } else {
                                try pascal_name.append(self.allocator, c);
                            }
                        }

                        const pascal_path = try std.fs.path.join(self.allocator, &.{ dir, pascal_name.items });
                        defer self.allocator.free(pascal_path);
                        const pascal_with_ext = try std.fmt.allocPrint(self.allocator, "{s}.zig", .{pascal_path});
                        defer self.allocator.free(pascal_with_ext);
                        if (self.getClass(pascal_with_ext, class_name)) |class_info| {
                            return class_info;
                        }
                    }

                    return null;
                } else {
                    return self.getClass(ref, parent_ref);
                }
            } else {
                return self.getClass(current_file, parent_ref);
            }
        }
    }
};

/// Flatten all mixin fields into ClassInfo.fields for all classes in the registry.
///
/// This function implements PASS 1.5 of the code generation pipeline:
/// After all files are parsed (PASS 1), this walks through all ClassInfo entries
/// and flattens mixin fields directly into ClassInfo.fields. This ensures that
/// when children inherit from parents, they automatically get the parent's mixin
/// fields through normal inheritance collection.
///
/// **Architecture:**
/// - PASS 1: Parse all files → Store ClassInfo with raw fields + mixin_names
/// - PASS 1.5: Flatten mixins → ClassInfo.fields = [mixin_fields..., own_fields...]
/// - PASS 2: Generate code → Child inheritance reads flattened Parent.fields
///
/// **Memory Management:**
/// - Deep copies mixin fields (allocates new FieldDef/PropertyDef)
/// - Frees old ClassInfo.fields/properties arrays
/// - Replaces with new flattened arrays
///
/// **Error Handling:**
/// - Missing mixin: Prints warning, continues (graceful degradation)
/// - No infinite loops (shouldn't happen with mixins, but safe)
fn flattenAllMixinsIntoRegistry(registry: *GlobalRegistry) !void {
    // Iterate all classes in registry and flatten their mixins
    var file_it = registry.files.iterator();
    while (file_it.next()) |file_entry| {
        for (file_entry.value_ptr.classes.items) |*class_info| {
            // Only process classes that have mixins
            if (class_info.mixin_names.len > 0) {
                try flattenMixinsForClass(registry, class_info);
            }
        }
    }
}

/// Flatten mixin fields into a single ClassInfo's fields/properties.
///
/// For each mixin referenced in class_info.mixin_names:
/// 1. Lookup mixin in registry
/// 2. Deep copy mixin's fields and properties
/// 3. Prepend to class_info.fields/properties (mixin fields come first)
/// 4. Replace class_info.fields/properties with flattened version
///
/// **Field Ordering:**
/// Result: [mixin1_fields..., mixin2_fields..., own_fields...]
///
/// **Example:**
/// ```
/// TestMixin.fields = [mixin_field]
/// Parent.mixin_names = [TestMixin]
/// Parent.fields = [parent_field]
///
/// After flattening:
/// Parent.fields = [mixin_field, parent_field]
/// ```
fn flattenMixinsForClass(
    registry: *GlobalRegistry,
    class_info: *ClassInfo,
) !void {
    const allocator = registry.allocator;

    // Build new flattened fields/properties lists
    var new_fields: std.ArrayList(FieldDef) = .empty;
    errdefer new_fields.deinit(allocator);

    var new_properties: std.ArrayList(PropertyDef) = .empty;
    errdefer new_properties.deinit(allocator);

    // Step 1: Collect mixin fields FIRST (so they appear before own fields)
    for (class_info.mixin_names) |mixin_name| {
        const mixin_info = registry.getMixin(mixin_name) orelse {
            std.debug.print("Warning: Mixin {s} not found for {s}\n", .{ mixin_name, class_info.name });
            continue;
        };

        // Deep copy mixin fields (duplicate FieldDef structs)
        for (mixin_info.fields) |field| {
            try new_fields.append(allocator, FieldDef{
                .name = field.name,
                .type_name = field.type_name,
                .default_value = field.default_value,
                .estimated_size = field.estimated_size,
                .doc_comment = if (field.doc_comment) |doc|
                    try allocator.dupe(u8, doc)
                else
                    null,
            });
        }

        // Deep copy mixin properties
        for (mixin_info.properties) |prop| {
            try new_properties.append(allocator, PropertyDef{
                .name = prop.name,
                .type_name = prop.type_name,
                .access = prop.access,
                .default_value = prop.default_value,
                .doc_comment = if (prop.doc_comment) |doc|
                    try allocator.dupe(u8, doc)
                else
                    null,
            });
        }
    }

    // Step 2: Append own fields AFTER mixin fields
    for (class_info.fields) |field| {
        try new_fields.append(allocator, field);
    }

    for (class_info.properties) |prop| {
        try new_properties.append(allocator, prop);
    }

    // Step 3: Replace class_info fields with flattened fields
    // Free old arrays (but not the doc_comments, they're still referenced)
    allocator.free(class_info.fields);
    class_info.fields = try new_fields.toOwnedSlice(allocator);

    allocator.free(class_info.properties);
    class_info.properties = try new_properties.toOwnedSlice(allocator);
}

/// Detect base types (interfaces with no parent but have children)
/// and build a map of base type name -> BaseTypeInfo.
///
/// A base type is an interface that:
/// - Has no parent (`parent_name == null`)
/// - Has at least one child class that extends it
/// - Is an interface (not a namespace or mixin)
///
/// Example: Node has no parent, but Element/Text/Comment extend it → Node is a base type
///
/// This information is used to generate XxxBase structs for polymorphism support.
fn detectBaseTypes(registry: *GlobalRegistry) !std.StringHashMap(BaseTypeInfo) {
    const allocator = registry.allocator;
    var base_types = std.StringHashMap(BaseTypeInfo).init(allocator);
    errdefer {
        var it = base_types.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.children.deinit(allocator);
        }
        base_types.deinit();
    }

    // First pass: Find all interfaces (regardless of parent)
    // We'll check for children in second pass
    var potential_bases = std.StringHashMap(struct {
        file_path: []const u8,
        class_info: ClassInfo,
    }).init(allocator);
    defer potential_bases.deinit();

    var file_it = registry.files.iterator();
    while (file_it.next()) |file_entry| {
        const file_path = file_entry.key_ptr.*;
        for (file_entry.value_ptr.classes.items) |class_info| {
            // Consider all interfaces (not namespaces or mixins)
            // Even if they have a parent - if they have children, they need a Base struct
            if (class_info.class_kind == .interface) {
                try potential_bases.put(class_info.name, .{
                    .file_path = file_path,
                    .class_info = class_info,
                });
            }
        }
    }

    // Second pass: For each potential base, find all children (direct and transitive)
    var base_it = potential_bases.iterator();
    while (base_it.next()) |base_entry| {
        const base_name = base_entry.key_ptr.*;
        const base_data = base_entry.value_ptr.*;

        var children: std.ArrayList([]const u8) = .empty;
        errdefer children.deinit(allocator);

        // Find all classes that extend this base (directly or indirectly)
        var file_it2 = registry.files.iterator();
        while (file_it2.next()) |file_entry| {
            for (file_entry.value_ptr.classes.items) |class_info| {
                if (try extendsBase(allocator, registry, &class_info, base_name, file_entry.key_ptr.*)) {
                    try children.append(allocator, class_info.name);
                }
            }
        }

        // Only add as base type if it has at least one child
        if (children.items.len > 0) {
            try base_types.put(base_name, .{
                .name = base_name,
                .children = children,
                .file_path = base_data.file_path,
                .class_info = base_data.class_info,
            });
        } else {
            children.deinit(allocator);
        }
    }

    return base_types;
}

/// Check if a class extends a given base type (directly or transitively)
fn extendsBase(
    allocator: std.mem.Allocator,
    registry: *GlobalRegistry,
    class_info: *const ClassInfo,
    base_name: []const u8,
    current_file: []const u8,
) !bool {
    var current_parent = class_info.parent_name;
    var current_file_path = current_file;
    var visited = std.StringHashMap(void).init(allocator);
    defer visited.deinit();

    while (current_parent) |parent_ref| {
        // Avoid infinite loops
        if (visited.contains(parent_ref)) break;
        try visited.put(parent_ref, {});

        // Extract just the class name (handle "base.Type" format)
        const parent_class_name = if (std.mem.indexOfScalar(u8, parent_ref, '.')) |dot_pos|
            parent_ref[dot_pos + 1 ..]
        else
            parent_ref;

        // Check if this parent is our target base
        if (std.mem.eql(u8, parent_class_name, base_name)) {
            return true;
        }

        // Walk up the hierarchy
        const parent_info = (try registry.resolveParentReference(parent_ref, current_file_path)) orelse break;
        current_parent = parent_info.parent_name;
        current_file_path = parent_info.file_path;
    }

    return false;
}

/// Convert PascalCase to snake_case for module names
/// Example: "ReadableStreamGenericReader" -> "readable_stream_generic_reader"
fn pascalToSnakeCase(allocator: std.mem.Allocator, pascal: []const u8) ![]const u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    var prev_was_upper = false;
    for (pascal, 0..) |c, i| {
        if (std.ascii.isUpper(c)) {
            // Add underscore before uppercase if previous wasn't uppercase (except at start)
            if (i > 0 and result.items.len > 0 and !prev_was_upper) {
                try result.append(allocator, '_');
            }
            try result.append(allocator, std.ascii.toLower(c));
            prev_was_upper = true;
        } else {
            try result.append(allocator, c);
            prev_was_upper = false;
        }
    }

    return result.toOwnedSlice(allocator);
}

fn parseImports(
    allocator: std.mem.Allocator,
    source: []const u8,
    current_file: []const u8,
    imports: *std.StringHashMap([]const u8),
) !void {
    var pos: usize = 0;

    while (pos < source.len) {
        const import_pos = std.mem.indexOfPos(u8, source, pos, "@import(") orelse break;

        const quote_start = std.mem.indexOfPos(u8, source, import_pos, "\"") orelse {
            pos = import_pos + 1;
            continue;
        };

        const quote_end = std.mem.indexOfPos(u8, source, quote_start + 1, "\"") orelse {
            pos = quote_start + 1;
            continue;
        };

        const import_path = source[quote_start + 1 .. quote_end];

        if (std.mem.eql(u8, import_path, "std") or std.mem.eql(u8, import_path, "zoop")) {
            pos = quote_end + 1;
            continue;
        }

        const line_start = blk: {
            var i = import_pos;
            while (i > 0) : (i -= 1) {
                if (source[i] == '\n') break :blk i + 1;
            }
            break :blk 0;
        };

        const line_end = std.mem.indexOfScalarPos(u8, source, quote_end, ';') orelse {
            pos = quote_end + 1;
            continue;
        };

        const full_line = source[line_start..line_end];

        if (std.mem.indexOf(u8, full_line, "const")) |const_pos| {
            const after_const = std.mem.trim(u8, full_line[const_pos + 5 ..], " \t");
            if (std.mem.indexOfScalar(u8, after_const, '=')) |eq_pos| {
                const alias = std.mem.trim(u8, after_const[0..eq_pos], " \t");
                const alias_owned = try allocator.dupe(u8, alias);
                errdefer allocator.free(alias_owned);

                const after_eq = std.mem.trim(u8, after_const[eq_pos + 1 ..], " \t");

                const resolved_ref = blk: {
                    if (std.mem.indexOf(u8, after_eq, ").")) |close_paren_dot| {
                        const class_name = std.mem.trim(u8, after_eq[close_paren_dot + 2 ..], " \t;");

                        const resolved_path: []const u8 = if (std.fs.path.dirname(current_file)) |dir|
                            try std.fs.path.join(allocator, &.{ dir, import_path })
                        else
                            try allocator.dupe(u8, import_path);
                        defer allocator.free(resolved_path);

                        break :blk try std.fmt.allocPrint(allocator, "{s}.{s}", .{ resolved_path, class_name });
                    } else {
                        if (std.fs.path.dirname(current_file)) |dir| {
                            break :blk try std.fs.path.join(allocator, &.{ dir, import_path });
                        } else {
                            break :blk try allocator.dupe(u8, import_path);
                        }
                    }
                };
                errdefer allocator.free(resolved_ref);

                const gop = try imports.getOrPut(alias_owned);
                if (gop.found_existing) {
                    // Duplicate alias - this shouldn't happen in valid Zig code,
                    // but if it does, we free the new allocations and keep existing
                    allocator.free(alias_owned);
                    allocator.free(resolved_ref);
                } else {
                    // New entry - store the value (key already set by getOrPut)
                    gop.value_ptr.* = resolved_ref;
                }
            }
        }

        pos = quote_end + 1;
    }
}

fn scanFileForClasses(
    allocator: std.mem.Allocator,
    source: []const u8,
    file_path: []const u8,
    classes: *std.ArrayListUnmanaged(ClassInfo),
    registry: *GlobalRegistry,
) !void {
    var pos: usize = 0;

    while (pos < source.len) {
        // Find next webidl.interface( or webidl.namespace( or webidl.mixin(
        const class_start = std.mem.indexOfPos(u8, source, pos, "webidl.interface(");
        const namespace_start = std.mem.indexOfPos(u8, source, pos, "webidl.namespace(");
        const mixin_start = std.mem.indexOfPos(u8, source, pos, "webidl.mixin(");

        const next_start = blk: {
            if (class_start) |c| {
                if (namespace_start) |n| {
                    if (mixin_start) |m| {
                        break :blk @min(@min(c, n), m);
                    }
                    break :blk @min(c, n);
                }
                if (mixin_start) |m| {
                    break :blk @min(c, m);
                }
                break :blk c;
            } else if (namespace_start) |n| {
                if (mixin_start) |m| {
                    break :blk @min(n, m);
                }
                break :blk n;
            } else if (mixin_start) |m| {
                break :blk m;
            } else {
                break;
            }
        };

        // Determine if this is a mixin or interface
        const is_mixin = if (mixin_start) |m| m == next_start else false;

        if (try parseClassDefinition(allocator, source, next_start)) |parsed| {
            defer {
                var mutable = parsed;
                mutable.deinit();
            }

            // Duplicate mixin names array
            var mixin_names_copy = try allocator.alloc([]const u8, parsed.mixin_names.len);
            for (parsed.mixin_names, 0..) |mixin_name, i| {
                mixin_names_copy[i] = try allocator.dupe(u8, mixin_name);
            }

            // Intern strings to reduce memory usage
            const interned_name = try registry.internString(parsed.name);
            const interned_parent = if (parsed.parent_name) |p| try registry.internString(p) else null;

            // Intern mixin names
            var interned_mixins = try allocator.alloc([]const u8, mixin_names_copy.len);
            for (mixin_names_copy, 0..) |mixin, i| {
                interned_mixins[i] = try registry.internString(mixin);
                allocator.free(mixin); // Free the original copy
            }
            allocator.free(mixin_names_copy); // Free the original array

            // Deep copy methods with their doc comments
            const methods_copy = try allocator.alloc(MethodDef, parsed.methods.len);
            for (parsed.methods, 0..) |method, i| {
                methods_copy[i] = MethodDef{
                    .name = method.name,
                    .source = method.source,
                    .signature = method.signature,
                    .return_type = method.return_type,
                    .is_static = method.is_static,
                    .doc_comment = if (method.doc_comment) |doc| try allocator.dupe(u8, doc) else null,
                };
            }

            // Deep copy fields with their doc comments
            const fields_copy = try allocator.alloc(FieldDef, parsed.fields.len);
            for (parsed.fields, 0..) |field, i| {
                fields_copy[i] = FieldDef{
                    .name = field.name,
                    .type_name = field.type_name,
                    .default_value = field.default_value,
                    .estimated_size = field.estimated_size,
                    .doc_comment = if (field.doc_comment) |doc| try allocator.dupe(u8, doc) else null,
                };
            }

            // Deep copy properties with their doc comments
            const properties_copy = try allocator.alloc(PropertyDef, parsed.properties.len);
            for (parsed.properties, 0..) |prop, i| {
                properties_copy[i] = PropertyDef{
                    .name = prop.name,
                    .type_name = prop.type_name,
                    .access = prop.access,
                    .default_value = prop.default_value,
                    .doc_comment = if (prop.doc_comment) |doc| try allocator.dupe(u8, doc) else null,
                };
            }

            // Deep copy constants
            const constants_copy = try allocator.alloc([]const u8, parsed.constants.len);
            for (parsed.constants, 0..) |constant, i| {
                constants_copy[i] = try allocator.dupe(u8, constant);
            }

            // Deep copy WebIDL options (exposed scopes need duplication)
            var webidl_options_copy = parsed.webidl_options;
            if (parsed.webidl_options.exposed) |exposed| {
                webidl_options_copy.exposed = try allocator.dupe(ExposureScope, exposed);
            }

            const class_info = ClassInfo{
                .name = interned_name,
                .parent_name = interned_parent,
                .mixin_names = interned_mixins,
                .fields = fields_copy,
                .methods = methods_copy,
                .properties = properties_copy,
                .constants = constants_copy,
                .source_start = parsed.source_start,
                .source_end = parsed.source_end,
                .file_path = file_path,
                .has_self_type = parsed.has_self_type,
                .webidl_options = webidl_options_copy,
                .class_kind = parsed.class_kind,
            };

            if (is_mixin) {
                // Register this as a mixin in the global registry
                try registry.addMixin(interned_name, class_info);
            }

            // Always add to classes list (mixins can also be processed as classes for generation)
            try classes.append(allocator, class_info);
            pos = parsed.source_end;
        } else {
            pos = next_start + 1;
        }
    }
}

/// Strip trailing doc comments (///) from the end of source text.
/// This is used to avoid duplicating class-level doc comments.
fn stripTrailingDocComments(source: []const u8) []const u8 {
    if (source.len == 0) return source;

    var end = source.len;

    // Walk backwards through lines
    while (end > 0) {
        // Skip trailing newline if present
        var line_end = end;
        if (line_end > 0 and source[line_end - 1] == '\n') {
            line_end -= 1;
        }
        if (line_end > 0 and source[line_end - 1] == '\r') {
            line_end -= 1;
        }

        // Find start of current line
        var line_start = line_end;
        while (line_start > 0 and source[line_start - 1] != '\n' and source[line_start - 1] != '\r') {
            line_start -= 1;
        }

        // Prevent infinite loop - ensure we're making progress
        if (line_end <= 0 or line_start >= end) break;

        const line = std.mem.trim(u8, source[line_start..line_end], " \t");

        if (std.mem.startsWith(u8, line, "///")) {
            // This is a doc comment, remove it (including its newline)
            end = line_start;
        } else if (line.len == 0) {
            // Empty line, remove it and continue
            end = line_start;
        } else {
            // Non-doc-comment, non-empty line - stop
            break;
        }
    }

    return source[0..end];
}

fn filterWebIDLImport(allocator: std.mem.Allocator, source: []const u8, mixin_names: []const []const u8) ![]const u8 {
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    var pos: usize = 0;
    var line_start: usize = 0;

    while (pos < source.len) {
        const line_end = std.mem.indexOfScalarPos(u8, source, pos, '\n') orelse source.len;
        const line = source[line_start..line_end];

        const should_filter = blk: {
            const trimmed = std.mem.trim(u8, line, " \t\r");

            // Filter out webidl/zoop imports
            if (std.mem.indexOf(u8, line, "@import(\"zoop\")")) |_| {
                if (std.mem.startsWith(u8, trimmed, "const ")) {
                    if (std.mem.indexOf(u8, trimmed, "=")) |_| {
                        break :blk true;
                    }
                }
            }

            // Filter out imports that will be generated by ImportSet
            // These are always added by the codegen based on inheritance
            const imports_to_filter = [_][]const u8{
                "const Node = @import(\"node\").Node;",
                "const Allocator = std.mem.Allocator;",
                "const infra = @import(\"infra\");",
                "const RegisteredObserver = @import(\"registered_observer\").RegisteredObserver;",
                "const GetRootNodeOptions = @import(\"node\").GetRootNodeOptions;",
                "const Document = @import(\"document\").Document;",
                "const Element = @import(\"element\").Element;",
                "const AbortSignal = @import(\"abort_signal\").AbortSignal;",
                "const CharacterData = @import(\"character_data\").CharacterData;",
                "const Text = @import(\"text\").Text;",
                "const ShadowRoot = @import(\"shadow_root\").ShadowRoot;",
                "const ELEMENT_NODE = @import(\"node\").ELEMENT_NODE;",
                "const DOCUMENT_NODE = @import(\"node\").DOCUMENT_NODE;",
                "const DOCUMENT_POSITION_DISCONNECTED = @import(\"node\").DOCUMENT_POSITION_DISCONNECTED;",
                "const EventListener = @import(\"event_target\").EventListener;",
                "const Event = @import(\"event\").Event;",
                "const flattenOptions = @import(\"event_target\").flattenOptions;",
                "const flattenMoreOptions = @import(\"event_target\").flattenMoreOptions;",
                "const defaultPassiveValue = @import(\"event_target\").defaultPassiveValue;",
                "const callbackEquals = @import(\"event_target\").callbackEquals;",
            };

            for (imports_to_filter) |import_to_filter| {
                if (std.mem.eql(u8, trimmed, import_to_filter)) {
                    break :blk true;
                }
            }

            // Filter out mixin imports (they're now flattened, so import is unused)
            for (mixin_names) |mixin_name| {
                // Check if this line imports the mixin type
                // Pattern: const MixinName = @import("...").MixinName;
                const import_pattern = try std.fmt.allocPrint(allocator, "const {s} = @import", .{mixin_name});
                defer allocator.free(import_pattern);

                if (std.mem.indexOf(u8, line, import_pattern)) |_| {
                    break :blk true;
                }
            }

            break :blk false;
        };

        if (!should_filter) {
            // Make const @import declarations public so dictionaries/helpers can be re-exported
            // Example: "const TextEncoderEncodeIntoResult = @import(...)" -> "pub const TextEncoderEncodeIntoResult = @import(...)"
            // BUT: Don't add pub to local const inside functions (indentation > 8 spaces)
            const trimmed_line = std.mem.trim(u8, line, " \t\r");
            if (std.mem.startsWith(u8, trimmed_line, "const ") and
                !std.mem.startsWith(u8, trimmed_line, "const std") and
                !std.mem.startsWith(u8, trimmed_line, "const webidl") and
                !std.mem.startsWith(u8, trimmed_line, "const infra") and
                std.mem.indexOf(u8, trimmed_line, "@import") != null)
            {
                const leading_whitespace = line[0..std.mem.indexOf(u8, line, "const").?];
                // Only add pub if indentation suggests struct-level (not inside function)
                // Struct-level consts have 0-4 spaces, function-level have 8+ spaces
                if (leading_whitespace.len <= 4) {
                    // Struct-level import - make it public
                    try result.appendSlice(allocator, leading_whitespace);
                    try result.appendSlice(allocator, "pub ");
                    try result.appendSlice(allocator, trimmed_line);
                    if (line_end < source.len) try result.append(allocator, '\n');
                } else {
                    // Function-level import - keep as-is
                    try result.appendSlice(allocator, source[line_start..if (line_end < source.len) line_end + 1 else line_end]);
                }
            } else {
                try result.appendSlice(allocator, source[line_start..if (line_end < source.len) line_end + 1 else line_end]);
            }
        }

        if (line_end >= source.len) break;
        pos = line_end + 1;
        line_start = pos;
    }

    return try result.toOwnedSlice(allocator);
}

fn processSourceFileWithRegistry(
    allocator: std.mem.Allocator,
    source: []const u8,
    file_path: []const u8,
    registry: *GlobalRegistry,
    config: ClassConfig,
    base_types: *const std.StringHashMap(BaseTypeInfo),
) ![]const u8 {
    const file_info = registry.files.get(file_path) orelse return error.FileNotFound;

    var class_registry = std.StringHashMap(ClassInfo).init(allocator);
    defer class_registry.deinit();

    for (file_info.classes.items) |class_info| {
        try class_registry.put(class_info.name, class_info);
    }

    var it = class_registry.iterator();
    while (it.next()) |entry| {
        var visited = std.StringHashMap(void).init(allocator);
        defer visited.deinit();

        try detectCircularInheritance(
            entry.value_ptr.name,
            entry.value_ptr.parent_name,
            &class_registry,
            &visited,
        );
    }

    // Collect all mixin names from all classes in this file
    var all_mixin_names: std.ArrayList([]const u8) = .empty;
    defer all_mixin_names.deinit(allocator);

    for (file_info.classes.items) |class_info| {
        for (class_info.mixin_names) |mixin_name| {
            // Avoid duplicates
            var found = false;
            for (all_mixin_names.items) |existing| {
                if (std.mem.eql(u8, existing, mixin_name)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                try all_mixin_names.append(allocator, mixin_name);
            }
        }
    }

    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);

    try output.appendSlice(allocator,
        \\// Auto-generated by webidl-codegen
        \\// DO NOT EDIT - changes will be overwritten
        \\//
        \\// This file was generated from the source file with the same name.
        \\// Class definitions have been enhanced with:
        \\//   - Inherited methods from parent classes
        \\//   - Property getters and setters
        \\//   - Optimized field layouts
        \\
        \\
    );

    var pos: usize = 0;
    var last_class_end: usize = 0;

    while (pos < source.len) {
        // Find next webidl.interface( or webidl.namespace( or webidl.mixin(
        const class_start = std.mem.indexOfPos(u8, source, pos, "webidl.interface(");
        const namespace_start = std.mem.indexOfPos(u8, source, pos, "webidl.namespace(");
        const mixin_start = std.mem.indexOfPos(u8, source, pos, "webidl.mixin(");

        const next_start = blk: {
            if (class_start) |c| {
                if (namespace_start) |n| {
                    if (mixin_start) |m| {
                        break :blk @min(@min(c, n), m);
                    }
                    break :blk @min(c, n);
                }
                if (mixin_start) |m| {
                    break :blk @min(c, m);
                }
                break :blk c;
            } else if (namespace_start) |n| {
                if (mixin_start) |m| {
                    break :blk @min(n, m);
                }
                break :blk n;
            } else if (mixin_start) |m| {
                break :blk m;
            } else {
                break;
            }
        };

        const class_keyword_start = blk: {
            var i = next_start;
            while (i > last_class_end) : (i -= 1) {
                if (source[i] == '\n' or i == last_class_end) {
                    const line_start = if (source[i] == '\n') i + 1 else i;
                    const line = std.mem.trim(u8, source[line_start..next_start], " \t");
                    if (std.mem.startsWith(u8, line, "pub const") or std.mem.startsWith(u8, line, "const")) {
                        break :blk line_start;
                    }
                }
            }
            break :blk next_start;
        };

        // Ensure we don't go backwards
        const safe_start = @max(last_class_end, class_keyword_start);
        const raw_segment = source[last_class_end..safe_start];
        // Strip trailing doc comments to avoid duplication (we emit them separately)
        const segment_no_docs = stripTrailingDocComments(raw_segment);
        const segment = try filterWebIDLImport(allocator, segment_no_docs, all_mixin_names.items);
        defer allocator.free(segment);
        try output.appendSlice(allocator, segment);

        if (try parseClassDefinition(allocator, source, next_start)) |parsed| {
            defer {
                var mutable = parsed;
                mutable.deinit();
            }

            const enhanced = try generateEnhancedClassWithRegistry(allocator, parsed, config, file_path, registry, base_types);
            defer allocator.free(enhanced);

            try output.appendSlice(allocator, enhanced);

            last_class_end = parsed.source_end;
            pos = parsed.source_end;
        } else {
            pos = next_start + 1;
        }
    }

    const final_segment = try filterWebIDLImport(allocator, source[last_class_end..], all_mixin_names.items);
    defer allocator.free(final_segment);
    try output.appendSlice(allocator, final_segment);

    return try output.toOwnedSlice(allocator);
}

/// Detect circular inheritance with O(n) complexity and depth tracking.
///
/// This optimized version:
/// - Uses a visited set for O(1) lookup (not O(n²))
/// - Tracks depth to enforce MAX_INHERITANCE_DEPTH
/// - Single pass through the inheritance chain
///
/// Time complexity: O(n) where n is the inheritance chain length
/// Space complexity: O(n) for the visited set
fn detectCircularInheritanceGlobal(
    class_name: []const u8,
    parent_ref: ?[]const u8,
    current_file: []const u8,
    registry: *GlobalRegistry,
    visited: *std.StringHashMap(void),
) !void {
    if (parent_ref == null) return;

    try visited.put(class_name, {});

    var current_parent = parent_ref;
    var current_file_path = current_file;
    var depth: usize = 0;

    while (current_parent) |parent| {
        // Check for circular reference (O(1) lookup)
        if (visited.contains(parent)) {
            std.debug.print("ERROR: Circular inheritance detected: {s} -> {s}\n", .{ class_name, parent });
            return error.CircularInheritance;
        }

        // Check depth limit
        depth += 1;
        if (depth > MAX_INHERITANCE_DEPTH) {
            std.debug.print("ERROR: Maximum inheritance depth ({d}) exceeded starting from {s}\n", .{ MAX_INHERITANCE_DEPTH, class_name });
            return error.MaxDepthExceeded;
        }

        try visited.put(parent, {});

        const parent_class = try registry.resolveParentReference(parent, current_file_path) orelse break;
        current_parent = parent_class.parent_name;
        current_file_path = parent_class.file_path;
    }
}

/// Detect circular inheritance (legacy single-file version).
///
/// Optimized with O(n) complexity and depth tracking.
fn detectCircularInheritance(
    class_name: []const u8,
    parent_name: ?[]const u8,
    class_registry: *std.StringHashMap(ClassInfo),
    visited: *std.StringHashMap(void),
) !void {
    if (parent_name == null) return;

    try visited.put(class_name, {});

    var current_parent = parent_name;
    var depth: usize = 0;

    while (current_parent) |parent| {
        // Check for circular reference (O(1) lookup)
        if (visited.contains(parent)) {
            std.debug.print("ERROR: Circular inheritance detected: {s} -> {s}\n", .{ class_name, parent });
            return error.CircularInheritance;
        }

        // Check depth limit
        depth += 1;
        if (depth > MAX_INHERITANCE_DEPTH) {
            std.debug.print("ERROR: Maximum inheritance depth ({d}) exceeded starting from {s}\n", .{ MAX_INHERITANCE_DEPTH, class_name });
            return error.MaxDepthExceeded;
        }

        try visited.put(parent, {});

        if (class_registry.get(parent)) |parent_info| {
            current_parent = parent_info.parent_name;
        } else {
            break;
        }
    }
}

/// Extract doc comment (///) before a declaration at the given position.
/// Searches backward from pos to find contiguous /// lines.
/// Returns the doc comment text without the /// prefix, or null if none found.
fn extractDocComment(source: []const u8, pos: usize, allocator: std.mem.Allocator) !?[]const u8 {
    if (pos == 0) return null;

    // Find the start of the line containing pos
    var line_start = pos;
    while (line_start > 0 and source[line_start - 1] != '\n') {
        line_start -= 1;
    }

    // Collect doc comment lines going backwards
    var doc_lines: std.ArrayList([]const u8) = .empty;
    defer doc_lines.deinit(allocator);

    var search_pos = line_start;
    while (search_pos > 0) {
        // Find previous line start
        const prev_line_end = search_pos - 1;
        if (prev_line_end == 0 or source[prev_line_end] != '\n') break;

        var prev_line_start = prev_line_end;
        while (prev_line_start > 0 and source[prev_line_start - 1] != '\n') {
            prev_line_start -= 1;
        }

        const prev_line = std.mem.trim(u8, source[prev_line_start..prev_line_end], " \t\r");

        // Check if it's a doc comment line
        if (std.mem.startsWith(u8, prev_line, "///")) {
            const comment_text = std.mem.trimLeft(u8, prev_line[3..], " \t");
            try doc_lines.insert(allocator, 0, comment_text);
            search_pos = prev_line_start;
        } else if (prev_line.len == 0) {
            // Empty line - continue looking
            search_pos = prev_line_start;
        } else {
            // Non-doc-comment, non-empty line - stop
            break;
        }
    }

    if (doc_lines.items.len == 0) return null;

    // Join lines with newlines
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    for (doc_lines.items, 0..) |line, i| {
        if (i > 0) try result.append(allocator, '\n');
        try result.appendSlice(allocator, line);
    }

    return try result.toOwnedSlice(allocator);
}

/// Extract file-level doc comment (//!) at the start of the file.
/// Returns the doc comment text without the //! prefix, or null if none found.
fn extractFileDocComment(source: []const u8, allocator: std.mem.Allocator) !?[]const u8 {
    var doc_lines: std.ArrayList([]const u8) = .empty;
    defer doc_lines.deinit(allocator);

    var pos: usize = 0;
    while (pos < source.len) {
        // Find line end
        const line_end = std.mem.indexOfScalarPos(u8, source, pos, '\n') orelse source.len;
        const line = std.mem.trim(u8, source[pos..line_end], " \t\r");

        if (std.mem.startsWith(u8, line, "//!")) {
            const comment_text = std.mem.trimLeft(u8, line[3..], " \t");
            try doc_lines.append(allocator, comment_text);
        } else if (line.len > 0) {
            // Non-doc-comment, non-empty line - stop
            break;
        }

        pos = if (line_end < source.len) line_end + 1 else source.len;
    }

    if (doc_lines.items.len == 0) return null;

    // Join lines with newlines
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    for (doc_lines.items, 0..) |line, i| {
        if (i > 0) try result.append(allocator, '\n');
        try result.appendSlice(allocator, line);
    }

    return try result.toOwnedSlice(allocator);
}

/// Parse WebIDL extended attributes from options block (}, .{ ... });
fn parseWebIDLOptions(allocator: std.mem.Allocator, options_area: []const u8) !WebIDLOptions {
    var result = WebIDLOptions{};

    // Look for }, .{ pattern
    const options_start_pattern = std.mem.indexOf(u8, options_area, "}, .{") orelse return result;
    const options_start = options_start_pattern + 5; // Skip "}, .{"
    const options_end = std.mem.indexOf(u8, options_area[options_start..], "})") orelse return result;
    const options_content = std.mem.trim(u8, options_area[options_start .. options_start + options_end], " \t\r\n");

    if (options_content.len == 0) return result;

    // Parse .exposed = &.{.all} or .exposed = &.{.Window}
    if (std.mem.indexOf(u8, options_content, ".exposed")) |exposed_pos| {
        if (std.mem.indexOfPos(u8, options_content, exposed_pos, "&.{")) |amp_start| {
            if (std.mem.indexOfPos(u8, options_content, amp_start, "}")) |scope_end| {
                const scopes_text = options_content[amp_start + 3 .. scope_end];

                // Parse exposure scopes
                var scopes: std.ArrayList(ExposureScope) = .empty;
                defer scopes.deinit(allocator);

                var scope_it = std.mem.splitSequence(u8, scopes_text, ",");
                while (scope_it.next()) |scope_part| {
                    const trimmed = std.mem.trim(u8, scope_part, " \t\r\n.");
                    if (std.mem.eql(u8, trimmed, "global")) {
                        try scopes.append(allocator, .global);
                    } else if (std.mem.eql(u8, trimmed, "Window")) {
                        try scopes.append(allocator, .Window);
                    } else if (std.mem.eql(u8, trimmed, "Worker")) {
                        try scopes.append(allocator, .Worker);
                    } else if (std.mem.eql(u8, trimmed, "DedicatedWorker")) {
                        try scopes.append(allocator, .DedicatedWorker);
                    } else if (std.mem.eql(u8, trimmed, "SharedWorker")) {
                        try scopes.append(allocator, .SharedWorker);
                    } else if (std.mem.eql(u8, trimmed, "ServiceWorker")) {
                        try scopes.append(allocator, .ServiceWorker);
                    }
                }

                if (scopes.items.len > 0) {
                    result.exposed = try scopes.toOwnedSlice(allocator);
                }
            }
        }
    }

    // Parse .transferable = true
    if (std.mem.indexOf(u8, options_content, ".transferable")) |trans_pos| {
        if (std.mem.indexOfPos(u8, options_content, trans_pos, "true")) |_| {
            result.transferable = true;
        }
    }

    // Parse .serializable = true
    if (std.mem.indexOf(u8, options_content, ".serializable")) |ser_pos| {
        if (std.mem.indexOfPos(u8, options_content, ser_pos, "true")) |_| {
            result.serializable = true;
        }
    }

    // Parse .secure_context = true
    if (std.mem.indexOf(u8, options_content, ".secure_context")) |sec_pos| {
        if (std.mem.indexOfPos(u8, options_content, sec_pos, "true")) |_| {
            result.secure_context = true;
        }
    }

    // Parse .cross_origin_isolated = true
    if (std.mem.indexOf(u8, options_content, ".cross_origin_isolated")) |cross_pos| {
        if (std.mem.indexOfPos(u8, options_content, cross_pos, "true")) |_| {
            result.cross_origin_isolated = true;
        }
    }

    return result;
}

/// Parse a single class definition starting at the given position
fn parseClassDefinition(
    allocator: std.mem.Allocator,
    source: []const u8,
    start_pos: usize,
) !?struct {
    name: []const u8,
    parent_name: ?[]const u8,
    mixin_names: [][]const u8,
    fields: []FieldDef,
    methods: []MethodDef,
    properties: []PropertyDef,
    constants: [][]const u8,
    source_start: usize,
    source_end: usize,
    allocator: std.mem.Allocator,
    class_doc: ?[]const u8,
    has_self_type: bool,
    webidl_options: WebIDLOptions,
    class_kind: ClassKind,

    fn deinit(self: *@This()) void {
        // Free exposure scopes if allocated
        if (self.webidl_options.exposed) |scopes| {
            self.allocator.free(scopes);
        }
        for (self.mixin_names) |mixin| {
            self.allocator.free(mixin);
        }
        self.allocator.free(self.mixin_names);

        // Free doc comments in fields
        for (self.fields) |field| {
            if (field.doc_comment) |doc| {
                self.allocator.free(doc);
            }
        }
        self.allocator.free(self.fields);

        // Free doc comments in methods
        for (self.methods) |method| {
            if (method.doc_comment) |doc| {
                self.allocator.free(doc);
            }
        }
        self.allocator.free(self.methods);

        // Free doc comments in properties
        for (self.properties) |prop| {
            if (prop.doc_comment) |doc| {
                self.allocator.free(doc);
            }
        }
        self.allocator.free(self.properties);

        // Free constants
        for (self.constants) |constant| {
            self.allocator.free(constant);
        }
        self.allocator.free(self.constants);

        if (self.class_doc) |doc| {
            self.allocator.free(doc);
        }
    }
} {
    const struct_start = std.mem.indexOfPos(u8, source, start_pos, "struct") orelse return null;

    const open_brace = std.mem.indexOfPos(u8, source, struct_start, "{") orelse return null;

    const close_brace = findMatchingBrace(source, open_brace) orelse return null;

    const closing_paren = std.mem.indexOfPos(u8, source, close_brace, ");") orelse return null;

    const class_body = source[open_brace + 1 .. close_brace];

    // Determine class kind (interface, namespace, or mixin)
    // start_pos points to where we found "webidl.interface(" or "webidl.namespace(" or "webidl.mixin("
    const class_kind: ClassKind = blk: {
        // Check what's at start_pos
        if (std.mem.startsWith(u8, source[start_pos..], "webidl.mixin(")) {
            break :blk .mixin;
        } else if (std.mem.startsWith(u8, source[start_pos..], "webidl.namespace(")) {
            break :blk .namespace;
        } else {
            break :blk .interface;
        }
    };

    // Parse WebIDL options from }, .{ ... }); pattern
    const webidl_options = try parseWebIDLOptions(allocator, source[close_brace .. closing_paren + 2]);

    var name_start = std.mem.lastIndexOfScalar(u8, source[0..start_pos], '\n') orelse 0;
    if (name_start > 0) name_start += 1;
    const name_section = source[name_start..start_pos];

    // Extract class-level doc comment (before the class declaration)
    const class_doc = try extractDocComment(source, name_start, allocator);

    var class_name: []const u8 = "";
    if (std.mem.indexOf(u8, name_section, "const ")) |const_pos| {
        const name_offset = const_pos + CONST_KEYWORD_LEN;
        const eq_pos = std.mem.indexOfPos(u8, name_section, name_offset, "=") orelse return null;
        class_name = std.mem.trim(u8, name_section[name_offset..eq_pos], " \t\r\n");
    }

    if (class_name.len == 0) return null;

    var parent_name: ?[]const u8 = null;
    if (std.mem.indexOf(u8, class_body, "pub const extends")) |pub_extends_pos| {
        const eq_pos = std.mem.indexOfPos(u8, class_body, pub_extends_pos, "=") orelse {
            return null;
        };
        const semicolon_pos = std.mem.indexOfPos(u8, class_body, eq_pos, ";") orelse {
            return null;
        };
        parent_name = std.mem.trim(u8, class_body[eq_pos + 1 .. semicolon_pos], " \t\r\n");
    } else if (std.mem.indexOf(u8, class_body, "extends:")) |extends_pos| {
        const type_start = extends_pos + EXTENDS_KEYWORD_LEN;
        var type_end = type_start;
        while (type_end < class_body.len) : (type_end += 1) {
            const c = class_body[type_end];
            if (c == ',' or c == '\n' or c == '}') break;
        }
        parent_name = std.mem.trim(u8, class_body[type_start..type_end], " \t\r\n");
    }

    // Parse includes: pub const includes = .{ Mixin1, Mixin2 };
    var mixin_names: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (mixin_names.items) |mixin| {
            allocator.free(mixin);
        }
        mixin_names.deinit(allocator);
    }

    if (std.mem.indexOf(u8, class_body, "pub const includes")) |includes_pos| {
        if (std.mem.indexOfPos(u8, class_body, includes_pos, "=")) |eq_pos| {
            if (std.mem.indexOfPos(u8, class_body, eq_pos, ".{")) |dot_brace| {
                if (std.mem.indexOfPos(u8, class_body, dot_brace, "}")) |includes_close| {
                    const includes_content = std.mem.trim(u8, class_body[dot_brace + 2 .. includes_close], " \t\r\n");

                    // Parse comma-separated mixin names
                    var it = std.mem.splitSequence(u8, includes_content, ",");
                    while (it.next()) |mixin_part| {
                        const mixin_name = std.mem.trim(u8, mixin_part, " \t\r\n");
                        if (mixin_name.len > 0) {
                            try mixin_names.append(allocator, try allocator.dupe(u8, mixin_name));
                        }
                    }
                }
            }
        }
    }

    var fields: std.ArrayList(FieldDef) = .empty;
    errdefer fields.deinit(allocator);

    var methods: std.ArrayList(MethodDef) = .empty;
    errdefer methods.deinit(allocator);

    var properties: std.ArrayList(PropertyDef) = .empty;
    errdefer properties.deinit(allocator);

    var constants: std.ArrayList([]const u8) = .empty;
    errdefer constants.deinit(allocator);

    const has_self_type = try parseStructBody(allocator, class_body, &fields, &methods, &properties, &constants);

    // Convert to owned slices with proper error handling to prevent leaks
    const mixin_names_slice = try mixin_names.toOwnedSlice(allocator);
    errdefer {
        for (mixin_names_slice) |mixin| {
            allocator.free(mixin);
        }
        allocator.free(mixin_names_slice);
    }

    const fields_slice = try fields.toOwnedSlice(allocator);
    errdefer allocator.free(fields_slice);

    const methods_slice = try methods.toOwnedSlice(allocator);
    errdefer allocator.free(methods_slice);

    const properties_slice = try properties.toOwnedSlice(allocator);
    errdefer allocator.free(properties_slice);

    const constants_slice = try constants.toOwnedSlice(allocator);
    errdefer allocator.free(constants_slice);

    return .{
        .name = class_name,
        .parent_name = parent_name,
        .mixin_names = mixin_names_slice,
        .fields = fields_slice,
        .methods = methods_slice,
        .properties = properties_slice,
        .constants = constants_slice,
        .source_start = name_start,
        .source_end = closing_paren + 2,
        .allocator = allocator,
        .class_doc = class_doc,
        .has_self_type = has_self_type,
        .webidl_options = webidl_options,
        .class_kind = class_kind,
    };
}

fn findMatchingBrace(source: []const u8, open_pos: usize) ?usize {
    var depth: i32 = 1;
    var pos = open_pos + 1;

    while (pos < source.len) : (pos += 1) {
        switch (source[pos]) {
            '{' => depth += 1,
            '}' => {
                depth -= 1;
                if (depth == 0) return pos;
            },
            else => {},
        }
    }

    return null;
}

fn findMatchingParen(source: []const u8, open_pos: usize) ?usize {
    var depth: i32 = 1;
    var pos = open_pos + 1;

    while (pos < source.len) : (pos += 1) {
        switch (source[pos]) {
            '(' => depth += 1,
            ')' => {
                depth -= 1;
                if (depth == 0) return pos;
            },
            else => {},
        }
    }

    return null;
}

fn replaceFirstSelfType(
    allocator: std.mem.Allocator,
    signature: []const u8,
    new_type: []const u8,
) ![]const u8 {
    if (signature.len < 2) return try allocator.dupe(u8, signature);
    if (signature.len > MAX_SIGNATURE_LENGTH) return error.SignatureTooLong;

    const inner = signature[1 .. signature.len - 1];

    if (std.mem.indexOf(u8, inner, "*const ")) |const_pos| {
        const type_start = const_pos + PTR_CONST_PREFIX_LEN;
        var type_end = type_start;
        while (type_end < inner.len) : (type_end += 1) {
            const c = inner[type_end];
            if (c == ',' or c == ')' or c == ' ') break;
        }

        return try std.fmt.allocPrint(allocator, "({s}*const {s}{s})", .{
            inner[0..const_pos],
            new_type,
            inner[type_end..],
        });
    } else if (std.mem.indexOf(u8, inner, "*")) |ptr_pos| {
        const type_start = ptr_pos + PTR_PREFIX_LEN;
        var type_end = type_start;
        while (type_end < inner.len) : (type_end += 1) {
            const c = inner[type_end];
            if (c == ',' or c == ')' or c == ' ') break;
        }

        return try std.fmt.allocPrint(allocator, "({s}*{s}{s})", .{
            inner[0..ptr_pos],
            new_type,
            inner[type_end..],
        });
    }

    return try allocator.dupe(u8, signature);
}

fn extractParamNames(allocator: std.mem.Allocator, signature: []const u8) ![]const u8 {
    if (signature.len < 2) return "";
    if (signature.len > MAX_SIGNATURE_LENGTH) return error.SignatureTooLong;

    const inner = signature[1 .. signature.len - 1];

    const first_comma = std.mem.indexOf(u8, inner, ",") orelse return "";

    const params_section = std.mem.trim(u8, inner[first_comma + 1 ..], " \t");

    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    var it = std.mem.splitSequence(u8, params_section, ",");
    var first = true;
    while (it.next()) |param| {
        const trimmed = std.mem.trim(u8, param, " \t");
        if (trimmed.len == 0) continue;

        const colon_pos = std.mem.indexOf(u8, trimmed, ":") orelse continue;
        const param_name = std.mem.trim(u8, trimmed[0..colon_pos], " \t");

        if (!first) {
            try result.appendSlice(allocator, ", ");
        }
        try result.appendSlice(allocator, param_name);
        first = false;
    }

    return result.toOwnedSlice(allocator);
}

/// Substitute all occurrences of old_type_name with new_type_name in source code
/// This is used when flattening mixin methods into an interface - we need to replace
/// the mixin type name with the interface type name throughout the method.
fn substituteTypeName(
    allocator: std.mem.Allocator,
    source: []const u8,
    old_type_name: []const u8,
    new_type_name: []const u8,
) ![]const u8 {
    // Simple but safe approach: use mem.replace
    // This handles all occurrences in signatures and method bodies
    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    var pos: usize = 0;
    while (pos < source.len) {
        if (std.mem.indexOfPos(u8, source, pos, old_type_name)) |found_pos| {
            // Check if this is a whole-word match (not part of another identifier)
            const is_start_ok = found_pos == 0 or !std.ascii.isAlphanumeric(source[found_pos - 1]) and source[found_pos - 1] != '_';
            const is_end_ok = found_pos + old_type_name.len >= source.len or
                !std.ascii.isAlphanumeric(source[found_pos + old_type_name.len]) and
                    source[found_pos + old_type_name.len] != '_';

            if (is_start_ok and is_end_ok) {
                // This is a complete match - replace it
                try result.appendSlice(source[pos..found_pos]);
                try result.appendSlice(new_type_name);
                pos = found_pos + old_type_name.len;
            } else {
                // Not a complete match - skip this character and continue
                try result.append(source[found_pos]);
                pos = found_pos + 1;
            }
        } else {
            // No more matches - append the rest
            try result.appendSlice(source[pos..]);
            break;
        }
    }

    return result.toOwnedSlice();
}

/// Detect conflicts between mixin members and interface members
/// Returns an error with a helpful message if conflicts are found
fn detectMixinConflicts(
    allocator: std.mem.Allocator,
    interface_name: []const u8,
    mixin_infos: []const ClassInfo,
    interface_fields: []const FieldDef,
    _: []const MethodDef, // interface_methods - not needed (overriding is allowed)
) !void {
    // Track all field names across mixins
    var field_names = std.StringHashMap(struct { mixin_name: []const u8, file_path: []const u8 }).init(allocator);
    defer field_names.deinit();

    // Track all method names across mixins
    var method_names = std.StringHashMap(struct { mixin_name: []const u8, file_path: []const u8 }).init(allocator);
    defer method_names.deinit();

    // Check for conflicts between mixins
    for (mixin_infos) |mixin_info| {
        // Check mixin fields
        for (mixin_info.fields) |field| {
            const gop = try field_names.getOrPut(field.name);
            if (gop.found_existing) {
                // Field conflict between mixins
                std.debug.print("error: Field name conflict in interface '{s}'\n", .{interface_name});
                std.debug.print("  Field '{s}' is defined in multiple mixins:\n", .{field.name});
                std.debug.print("    - {s} ({s})\n", .{ gop.value_ptr.mixin_name, gop.value_ptr.file_path });
                std.debug.print("    - {s} ({s})\n", .{ mixin_info.name, mixin_info.file_path });
                std.debug.print("\n  To fix: Remove duplicate field from one of the mixins\n", .{});
                return error.MixinFieldConflict;
            }
            gop.value_ptr.* = .{ .mixin_name = mixin_info.name, .file_path = mixin_info.file_path };
        }

        // Check mixin methods
        for (mixin_info.methods) |method| {
            const gop = try method_names.getOrPut(method.name);
            if (gop.found_existing) {
                // Method conflict between mixins
                std.debug.print("error: Method name conflict in interface '{s}'\n", .{interface_name});
                std.debug.print("  Method '{s}' is defined in multiple mixins:\n", .{method.name});
                std.debug.print("    - {s} ({s})\n", .{ gop.value_ptr.mixin_name, gop.value_ptr.file_path });
                std.debug.print("    - {s} ({s})\n", .{ mixin_info.name, mixin_info.file_path });
                std.debug.print("\n  To fix: Either:\n", .{});
                std.debug.print("    1. Remove duplicate method from one mixin, OR\n", .{});
                std.debug.print("    2. Override the method in the interface itself\n", .{});
                return error.MixinMethodConflict;
            }
            gop.value_ptr.* = .{ .mixin_name = mixin_info.name, .file_path = mixin_info.file_path };
        }
    }

    // Check for conflicts between mixins and interface
    for (interface_fields) |field| {
        if (field_names.get(field.name)) |mixin_source| {
            std.debug.print("error: Field name conflict in interface '{s}'\n", .{interface_name});
            std.debug.print("  Field '{s}' is defined in both:\n", .{field.name});
            std.debug.print("    - Mixin: {s} ({s})\n", .{ mixin_source.mixin_name, mixin_source.file_path });
            std.debug.print("    - Interface: {s}\n", .{interface_name});
            std.debug.print("\n  To fix: Remove field from interface (it's inherited from mixin)\n", .{});
            return error.InterfaceFieldConflict;
        }
    }

    // Note: Interface methods CAN override mixin methods, so we don't check for method conflicts here
}

fn isStaticMethod(signature: []const u8) bool {
    // A method is static if it doesn't have a 'self' parameter
    // Signature format: (self: *Type, ...) or (self: *const Type, ...)

    if (signature.len < 3) return true; // Empty or invalid signature

    // Skip opening paren
    const inner = std.mem.trim(u8, signature[1 .. signature.len - 1], " \t\r\n");
    if (inner.len == 0) return true; // No parameters

    // Check if first parameter is named 'self'
    // Look for 'self:' or 'self :' at the start
    if (std.mem.startsWith(u8, inner, "self:") or std.mem.startsWith(u8, inner, "self :")) {
        return false; // Has self parameter - not static
    }

    return true; // No self parameter - is static
}

/// Parse a struct body and extract fields, methods, and properties.
/// Exposed for testing purposes.
pub fn parseStructBody(
    allocator: std.mem.Allocator,
    body: []const u8,
    fields: *std.ArrayList(FieldDef),
    methods: *std.ArrayList(MethodDef),
    properties: *std.ArrayList(PropertyDef),
    constants: *std.ArrayList([]const u8),
) !bool {
    var pos: usize = 0;
    var has_self_type = false;

    while (pos < body.len) {
        while (pos < body.len and (body[pos] == ' ' or body[pos] == '\t' or body[pos] == '\n' or body[pos] == '\r')) {
            pos += 1;
        }

        if (pos >= body.len) break;

        if (std.mem.startsWith(u8, body[pos..], "pub inline fn ") or
            std.mem.startsWith(u8, body[pos..], "pub fn ") or
            std.mem.startsWith(u8, body[pos..], "inline fn ") or
            std.mem.startsWith(u8, body[pos..], "fn "))
        {
            const fn_start = pos;
            const fn_keyword = if (std.mem.startsWith(u8, body[pos..], "pub inline fn "))
                "pub inline fn "
            else if (std.mem.startsWith(u8, body[pos..], "pub fn "))
                "pub fn "
            else if (std.mem.startsWith(u8, body[pos..], "inline fn "))
                "inline fn "
            else
                "fn ";
            const name_start = pos + fn_keyword.len;

            const paren_pos = std.mem.indexOfPos(u8, body, name_start, "(") orelse {
                pos += 1;
                continue;
            };

            const method_name = std.mem.trim(u8, body[name_start..paren_pos], " \t\r\n");

            const closing_paren = findMatchingParen(body, paren_pos) orelse {
                pos = paren_pos + 1;
                continue;
            };

            const signature = std.mem.trim(u8, body[paren_pos .. closing_paren + 1], " \t\r\n");

            // Find the opening brace of the method body
            // Skip over any braces in the return type (e.g., "!struct { fields }", "enum { a, b }" return types)
            const open_brace_pos = blk: {
                var search_pos = closing_paren + 1;
                var in_braced_type = false;
                var brace_depth: i32 = 0;

                while (search_pos < body.len) : (search_pos += 1) {
                    const c = body[search_pos];

                    // Track if we're inside any braced type declaration in the return type
                    // Check for: struct, enum, union, error, opaque
                    if (!in_braced_type) {
                        const remaining = body[search_pos..];

                        // Check for "struct" (6 chars)
                        if (remaining.len >= 6 and std.mem.eql(u8, remaining[0..6], "struct")) {
                            in_braced_type = true;
                            search_pos += 5; // Will be incremented by loop
                            continue;
                        }
                        // Check for "enum" (4 chars)
                        else if (remaining.len >= 4 and std.mem.eql(u8, remaining[0..4], "enum")) {
                            in_braced_type = true;
                            search_pos += 3; // Will be incremented by loop
                            continue;
                        }
                        // Check for "union" (5 chars)
                        else if (remaining.len >= 5 and std.mem.eql(u8, remaining[0..5], "union")) {
                            in_braced_type = true;
                            search_pos += 4; // Will be incremented by loop
                            continue;
                        }
                        // Check for "error" (5 chars)
                        else if (remaining.len >= 5 and std.mem.eql(u8, remaining[0..5], "error")) {
                            in_braced_type = true;
                            search_pos += 4; // Will be incremented by loop
                            continue;
                        }
                        // Check for "opaque" (6 chars)
                        else if (remaining.len >= 6 and std.mem.eql(u8, remaining[0..6], "opaque")) {
                            in_braced_type = true;
                            search_pos += 5; // Will be incremented by loop
                            continue;
                        }
                    }

                    if (in_braced_type) {
                        if (c == '{') {
                            brace_depth += 1;
                        } else if (c == '}') {
                            brace_depth -= 1;
                            if (brace_depth == 0) {
                                in_braced_type = false;
                            }
                        }
                    } else if (c == '{') {
                        // This is the method body opening brace
                        break :blk search_pos;
                    }
                }

                // Couldn't find method body brace
                pos = closing_paren + 1;
                continue;
            };

            const return_type_section = std.mem.trim(u8, body[closing_paren + 1 .. open_brace_pos], " \t\r\n");

            const close_brace_pos = findMatchingBrace(body, open_brace_pos) orelse {
                pos = open_brace_pos + 1;
                continue;
            };

            const method_source = body[fn_start .. close_brace_pos + 1];

            const is_static = isStaticMethod(signature);

            // Extract doc comment before the method
            const doc_comment = try extractDocComment(body, fn_start, allocator);

            try methods.append(allocator, .{
                .name = method_name,
                .source = method_source,
                .signature = signature,
                .return_type = return_type_section,
                .doc_comment = doc_comment,
                .is_static = is_static,
            });

            pos = close_brace_pos + 1;
        } else if (std.mem.startsWith(u8, body[pos..], "pub const properties")) {
            // Parse property block: pub const properties = .{ ... };
            const eq_pos = std.mem.indexOfPos(u8, body, pos, "=") orelse {
                pos += 1;
                continue;
            };

            const open_brace = std.mem.indexOfPos(u8, body, eq_pos, "{") orelse {
                pos = eq_pos + 1;
                continue;
            };

            const close_brace = findMatchingBrace(body, open_brace) orelse {
                pos = open_brace + 1;
                continue;
            };

            const props_body = body[open_brace + 1 .. close_brace];
            try parsePropertyBlock(allocator, props_body, properties);

            pos = close_brace + 1;
        } else {
            const line_end = std.mem.indexOfScalarPos(u8, body, pos, '\n') orelse body.len;
            const line = std.mem.trim(u8, body[pos..line_end], " \t\r\n");

            // Check for "const Self = @This();"
            if (std.mem.indexOf(u8, line, "const Self") != null and
                std.mem.indexOf(u8, line, "=") != null and
                std.mem.indexOf(u8, line, "@This()") != null)
            {
                has_self_type = true;
                pos = line_end + 1;
                continue;
            }

            // Check for pub const declarations (constants or type aliases)
            if (std.mem.startsWith(u8, line, "pub const ") and
                !std.mem.startsWith(u8, line, "pub const extends") and
                !std.mem.startsWith(u8, line, "pub const mixins") and
                !std.mem.startsWith(u8, line, "pub const properties"))
            {
                // Check if this is a nested struct type declaration (pub const X = struct {)
                // Look ahead from current position to see if there's a "struct {" pattern
                const remaining = body[pos..];
                const eq_pos = std.mem.indexOf(u8, remaining, "=") orelse {
                    // No equals sign found, treat as constant
                    try constants.append(allocator, try allocator.dupe(u8, line));
                    pos = line_end + 1;
                    continue;
                };

                // Look for "struct" after the equals sign
                const after_eq = remaining[eq_pos + 1 ..];
                var search_pos: usize = 0;

                // Skip whitespace after equals
                while (search_pos < after_eq.len and
                    (after_eq[search_pos] == ' ' or after_eq[search_pos] == '\t' or
                        after_eq[search_pos] == '\n' or after_eq[search_pos] == '\r'))
                {
                    search_pos += 1;
                }

                // Check if next non-whitespace is "struct"
                if (search_pos + 6 <= after_eq.len and
                    std.mem.eql(u8, after_eq[search_pos .. search_pos + 6], "struct"))
                {
                    // This is a nested struct declaration - preserve it in output but don't parse its fields
                    const struct_open_brace = std.mem.indexOfPos(u8, body, pos, "{") orelse {
                        pos = line_end + 1;
                        continue;
                    };

                    // Find the matching closing brace
                    const struct_close_brace = findMatchingBrace(body, struct_open_brace) orelse {
                        pos = line_end + 1;
                        continue;
                    };

                    // Look for semicolon after the closing brace (struct declarations end with };)
                    var end_pos = struct_close_brace + 1;
                    while (end_pos < body.len and (body[end_pos] == ' ' or body[end_pos] == '\t' or
                        body[end_pos] == '\n' or body[end_pos] == '\r'))
                    {
                        end_pos += 1;
                    }
                    if (end_pos < body.len and body[end_pos] == ';') {
                        end_pos += 1; // Include the semicolon
                    }

                    // Extract the entire struct declaration and add it to constants
                    // This preserves the nested type in the generated output
                    const struct_decl = body[pos..end_pos];
                    try constants.append(allocator, try allocator.dupe(u8, struct_decl));

                    // Skip past this struct
                    pos = end_pos;
                    continue;
                }

                // This is a constant declaration like "pub const NONE: u16 = 0;"
                try constants.append(allocator, try allocator.dupe(u8, line));
                pos = line_end + 1;
                continue;
            }

            // Check for const type aliases (they contain @import)
            if (std.mem.startsWith(u8, line, "const ") and
                !std.mem.startsWith(u8, line, "const Self") and
                std.mem.indexOf(u8, line, "@import") != null)
            {
                // This is a type alias like "const EventTarget = @import("event_target").EventTarget;"
                try constants.append(allocator, try allocator.dupe(u8, line));
                pos = line_end + 1;
                continue;
            }

            if (line.len > 0 and !std.mem.startsWith(u8, line, "//") and
                !std.mem.startsWith(u8, line, "extends:") and
                !std.mem.startsWith(u8, line, "mixins:") and
                !std.mem.startsWith(u8, line, "pub const extends") and
                !std.mem.startsWith(u8, line, "pub const mixins"))
            {
                if (std.mem.indexOf(u8, line, ":")) |colon_pos| {
                    const field_name = std.mem.trim(u8, line[0..colon_pos], " \t");

                    const after_colon = line[colon_pos + 1 ..];
                    var type_end = after_colon.len;
                    var default_value: ?[]const u8 = null;

                    // Find the end of the type, respecting parenthesis depth for generic types
                    // e.g., "HashMap(K, V), next_field" should stop at the comma after V)
                    var depth: i32 = 0;
                    var i: usize = 0;
                    var found_end = false;

                    while (i < after_colon.len) : (i += 1) {
                        const c = after_colon[i];
                        if (c == '(') {
                            depth += 1;
                        } else if (c == ')') {
                            depth -= 1;
                        } else if (c == '=' and depth == 0) {
                            // Default value assignment
                            type_end = i;
                            found_end = true;
                            // Extract default value (everything after '=' until ',' or end)
                            const after_equals = after_colon[i + 1 ..];
                            var value_end = after_equals.len;
                            for (after_equals, 0..) |ch, idx| {
                                if (ch == ',') {
                                    value_end = idx;
                                    break;
                                }
                            }
                            default_value = std.mem.trim(u8, after_equals[0..value_end], " \t,");
                            break;
                        } else if (c == ',' and depth == 0) {
                            // End of field (comma separating fields, not generic params)
                            type_end = i;
                            found_end = true;
                            break;
                        }
                    }

                    if (!found_end) {
                        type_end = after_colon.len;
                    }

                    const field_type = std.mem.trim(u8, after_colon[0..type_end], " \t,");

                    // Extract doc comment before the field
                    const field_doc = try extractDocComment(body, pos, allocator);

                    try fields.append(allocator, .{
                        .name = field_name,
                        .type_name = field_type,
                        .default_value = default_value,
                        .doc_comment = field_doc,
                    });
                }
            }

            pos = line_end + 1;
        }
    }

    return has_self_type;
}

fn parsePropertyBlock(
    allocator: std.mem.Allocator,
    props_body: []const u8,
    properties: *std.ArrayList(PropertyDef),
) !void {
    var pos: usize = 0;

    while (pos < props_body.len) {
        // Skip whitespace
        while (pos < props_body.len and (props_body[pos] == ' ' or props_body[pos] == '\t' or
            props_body[pos] == '\n' or props_body[pos] == '\r'))
        {
            pos += 1;
        }

        if (pos >= props_body.len) break;

        // Look for property: .propName = .{
        if (props_body[pos] != '.') {
            pos += 1;
            continue;
        }

        pos += 1; // Skip '.'

        // Find property name (until '=')
        const eq_pos = std.mem.indexOfPos(u8, props_body, pos, "=") orelse {
            pos += 1;
            continue;
        };

        const prop_name = std.mem.trim(u8, props_body[pos..eq_pos], " \t\r\n");

        // Find opening brace of property definition
        const open_brace = std.mem.indexOfPos(u8, props_body, eq_pos, "{") orelse {
            pos = eq_pos + 1;
            continue;
        };

        const close_brace = findMatchingBrace(props_body, open_brace) orelse {
            pos = open_brace + 1;
            continue;
        };

        const prop_def = props_body[open_brace + 1 .. close_brace];

        // Parse property attributes
        var prop_type: []const u8 = "";
        var prop_access: PropertyAccess = .read_write;

        // Look for .type =
        if (std.mem.indexOf(u8, prop_def, ".type")) |type_pos| {
            const type_eq = std.mem.indexOfPos(u8, prop_def, type_pos, "=") orelse {
                pos = close_brace + 1;
                continue;
            };

            const after_eq = prop_def[type_eq + 1 ..];
            var type_end: usize = 0;
            while (type_end < after_eq.len) : (type_end += 1) {
                const c = after_eq[type_end];
                if (c == ',' or c == '}') break;
            }

            prop_type = std.mem.trim(u8, after_eq[0..type_end], " \t\r\n");
        }

        // Look for .access =
        if (std.mem.indexOf(u8, prop_def, ".access")) |access_pos| {
            if (std.mem.indexOf(u8, prop_def[access_pos..], ".read_only")) |_| {
                prop_access = .read_only;
            }
        }

        if (prop_name.len > 0 and prop_type.len > 0) {
            try properties.append(allocator, .{
                .name = prop_name,
                .type_name = prop_type,
                .access = prop_access,
                .default_value = null,
            });
        }

        pos = close_brace + 1;
    }
}

fn collectAllParentFields(
    allocator: std.mem.Allocator,
    parent_name: ?[]const u8,
    class_registry: *std.StringHashMap(ClassInfo),
    fields_out: *std.ArrayList(FieldDef),
) !void {
    if (parent_name == null) return;

    var hierarchy: std.ArrayList(ClassInfo) = .empty;
    defer hierarchy.deinit(allocator);

    var current_parent = parent_name;
    while (current_parent) |parent| {
        if (class_registry.get(parent)) |parent_info| {
            try hierarchy.append(allocator, parent_info);
            current_parent = parent_info.parent_name;
        } else {
            break;
        }
    }

    var i = hierarchy.items.len;
    while (i > 0) {
        i -= 1;
        const parent_info = hierarchy.items[i];
        for (parent_info.fields) |field| {
            try fields_out.append(allocator, field);
        }
    }
}

fn adaptInitDeinit(
    allocator: std.mem.Allocator,
    source: []const u8,
    child_type: []const u8,
) ![]const u8 {
    // Validate type name to prevent injection
    if (!isValidTypeName(child_type)) return error.InvalidTypeName;

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    var pos: usize = 0;
    var in_signature = true;
    var found_parent_type: ?[]const u8 = null;

    while (pos < source.len) {
        if (in_signature) {
            if (std.mem.indexOfPos(u8, source, pos, "self: *")) |self_pos| {
                try writer.writeAll(source[pos .. self_pos + 7]);

                const type_start = self_pos + 7;
                var type_end = type_start;
                while (type_end < source.len) : (type_end += 1) {
                    const c = source[type_end];
                    if (!std.ascii.isAlphanumeric(c) and c != '_') break;
                }

                if (found_parent_type == null) {
                    found_parent_type = source[type_start..type_end];
                }

                try writer.writeAll(child_type);
                pos = type_end;
            } else if (std.mem.indexOfPos(u8, source, pos, ") ")) |paren_pos| {
                try writer.writeAll(source[pos .. paren_pos + 2]);

                const type_start = paren_pos + 2;
                var type_end = type_start;
                while (type_end < source.len and source[type_end] != '{') : (type_end += 1) {}

                const return_section = std.mem.trim(u8, source[type_start..type_end], " \t\r\n");

                if (return_section.len > 0) {
                    if (!std.mem.eql(u8, return_section, "void")) {
                        if (found_parent_type == null) {
                            found_parent_type = return_section;
                        }
                        try writer.writeAll(child_type);
                    } else {
                        try writer.writeAll("void");
                    }
                    try writer.writeAll(" ");
                }

                pos = type_end;
                in_signature = false;
            } else {
                try writer.writeByte(source[pos]);
                pos += 1;
            }
        } else {
            // With flattened fields, we no longer need to rewrite self.field to self.super.field
            // Just handle type name replacement
            if (found_parent_type) |parent_type| {
                if (std.mem.indexOfPos(u8, source, pos, parent_type)) |match_pos| {
                    try writer.writeAll(source[pos..match_pos]);
                    try writer.writeAll(child_type);
                    pos = match_pos + parent_type.len;
                } else {
                    try writer.writeAll(source[pos..]);
                    break;
                }
            } else {
                try writer.writeAll(source[pos..]);
                break;
            }
        }
    }

    return try buf.toOwnedSlice(allocator);
}

/// Generate a smart init function that takes parent args + child fields
fn generateSmartInit(
    allocator: std.mem.Allocator,
    class_name: []const u8,
    parent_init_source: []const u8,
    parent_type: []const u8,
    param_fields: []const FieldDef,
    param_properties: []const PropertyDef,
    all_fields: []const FieldDef,
    all_properties: []const PropertyDef,
) ![]const u8 {
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    const writer = result.writer(allocator);

    // Parse parent init signature
    // Example: "pub fn init(allocator: std.mem.Allocator, name_val: []const u8) !Parent {"
    const params_start = std.mem.indexOf(u8, parent_init_source, "(") orelse return error.InvalidInitSignature;
    const params_end = std.mem.indexOf(u8, parent_init_source, ")") orelse return error.InvalidInitSignature;
    const parent_params = parent_init_source[params_start + 1 .. params_end];

    // Extract return type (handle error unions like "!Parent")
    // Find the closing paren, then look for the return type before "{"
    const return_type_start = params_end + 1;
    const brace_pos = std.mem.indexOf(u8, parent_init_source[return_type_start..], "{") orelse return error.InvalidInitSignature;
    const return_type_section = std.mem.trim(u8, parent_init_source[return_type_start .. return_type_start + brace_pos], " \t\r\n");

    // Extract error union prefix (! or !!) if present
    var error_prefix: []const u8 = "";
    if (std.mem.startsWith(u8, return_type_section, "!!")) {
        error_prefix = "!!";
    } else if (std.mem.startsWith(u8, return_type_section, "!")) {
        error_prefix = "!";
    }

    // Build a map from field/prop name to parameter name
    // Parse parent params to extract "name: type" pairs
    var param_name_map = std.StringHashMap([]const u8).init(allocator);
    defer param_name_map.deinit();

    // Parse params string to find matching field types
    // This is a simplified parser - looks for "name: Type" patterns
    var param_iter = std.mem.tokenizeAny(u8, parent_params, ",");
    while (param_iter.next()) |param_decl| {
        const trimmed = std.mem.trim(u8, param_decl, " \t\r\n");
        if (std.mem.indexOf(u8, trimmed, ":")) |colon_pos| {
            const param_name = std.mem.trim(u8, trimmed[0..colon_pos], " \t\r\n");
            const param_type = std.mem.trim(u8, trimmed[colon_pos + 1 ..], " \t\r\n");

            // Try to match against fields
            for (all_fields) |field| {
                if (std.mem.eql(u8, field.type_name, param_type)) {
                    // Heuristic: if param ends with "_val" and field name matches prefix, map them
                    // e.g., "name_val" → "name"
                    if (std.mem.endsWith(u8, param_name, "_val")) {
                        const field_prefix = param_name[0 .. param_name.len - 4];
                        if (std.mem.eql(u8, field.name, field_prefix)) {
                            try param_name_map.put(field.name, param_name);
                            continue;
                        }
                    }
                    // Otherwise, if types match and names are similar, map directly
                    if (std.mem.eql(u8, field.name, param_name)) {
                        try param_name_map.put(field.name, param_name);
                    }
                }
            }
        }
    }

    // Generate signature: pub fn init(allocator, parent_params, field1: Type1, ...) !ClassName {
    try writer.writeAll("pub fn init(");

    // Always include allocator as first parameter
    try writer.writeAll("allocator: std.mem.Allocator");

    // Add parent params (skip allocator if it's already in parent params)
    if (parent_params.len > 0) {
        // Check if parent_params starts with "allocator:"
        if (!std.mem.startsWith(u8, std.mem.trim(u8, parent_params, " \t"), "allocator:")) {
            try writer.writeAll(", ");
            try writer.writeAll(parent_params);
        } else {
            // Parent already has allocator, skip it
            const comma_pos = std.mem.indexOf(u8, parent_params, ",");
            if (comma_pos) |pos| {
                try writer.writeAll(parent_params[pos..]);
            }
        }
    }

    // Add parameters for fields that need to be passed
    for (param_fields) |field| {
        try writer.writeAll(", ");
        try writer.print("{s}: {s}", .{ field.name, field.type_name });
    }

    // Add parameters for properties
    for (param_properties) |prop| {
        try writer.writeAll(", ");
        try writer.print("{s}: {s}", .{ prop.name, prop.type_name });
    }

    // Always return error union (for dynamic allocations)
    try writer.print(") !{s} {{\n", .{class_name});

    // Check if parent's init uses initFields pattern: "return try Parent.initFields("
    const body_start = std.mem.indexOf(u8, parent_init_source, "{") orelse return error.InvalidInitSignature;
    const body_end = std.mem.lastIndexOf(u8, parent_init_source, "}") orelse return error.InvalidInitSignature;
    const parent_body = parent_init_source[body_start + 1 .. body_end];

    const initfields_pattern = try std.fmt.allocPrint(allocator, "{s}.initFields(", .{parent_type});
    defer allocator.free(initfields_pattern);

    if (std.mem.indexOf(u8, parent_body, initfields_pattern)) |_| {
        // Parent uses initFields pattern
        // We need to:
        // 1. Copy everything before the initFields struct literal
        // 2. Extend the struct literal with child's additional fields
        // 3. Copy everything after

        // First, rewrite type names in the entire body
        const rewritten_body = try rewriteMixinMethod(allocator, parent_body, parent_type, class_name);
        defer allocator.free(rewritten_body);

        // Find the struct literal in the initFields call: .{
        const rewritten_initfields_pattern = try std.fmt.allocPrint(allocator, "{s}.initFields(", .{class_name});
        defer allocator.free(rewritten_initfields_pattern);

        const rewritten_call_pos = std.mem.indexOf(u8, rewritten_body, rewritten_initfields_pattern) orelse {
            // Fallback if we can't find it
            try writer.writeAll(rewritten_body);
            try writer.writeAll("    }\n\n");

            // Still generate initFields for child - inline generation
            try writer.writeAll("    fn initFields(allocator: std.mem.Allocator, fields: *const struct {");
            for (all_fields) |field| {
                try writer.print(" {s}: {s},", .{ field.name, field.type_name });
            }
            for (all_properties) |prop| {
                try writer.print(" {s}: {s},", .{ prop.name, prop.type_name });
            }
            try writer.print(" }}) !{s} {{\n", .{class_name});
            try writer.print("        return {s}{{\n", .{class_name});
            try writer.writeAll("            .allocator = allocator,\n");
            for (all_fields) |field| {
                const needs_alloc = std.mem.eql(u8, field.type_name, "[]const u8") or std.mem.eql(u8, field.type_name, "[]u8");
                if (needs_alloc) {
                    try writer.print("            .{s} = try allocator.dupe(u8, fields.{s}),\n", .{ field.name, field.name });
                } else {
                    try writer.print("            .{s} = fields.{s},\n", .{ field.name, field.name });
                }
            }
            for (all_properties) |prop| {
                const needs_alloc = std.mem.eql(u8, prop.type_name, "[]const u8") or std.mem.eql(u8, prop.type_name, "[]u8");
                if (needs_alloc) {
                    try writer.print("            .{s} = try allocator.dupe(u8, fields.{s}),\n", .{ prop.name, prop.name });
                } else {
                    try writer.print("            .{s} = fields.{s},\n", .{ prop.name, prop.name });
                }
            }
            try writer.writeAll("        };\n");
            try writer.writeAll("    }");
            return try result.toOwnedSlice(allocator);
        };

        // Find the .{ after initFields(allocator,
        const after_call = rewritten_body[rewritten_call_pos + rewritten_initfields_pattern.len ..];
        const struct_lit_start = std.mem.indexOf(u8, after_call, ".{") orelse {
            // No struct literal found, just copy as-is
            try writer.writeAll(rewritten_body);
            try writer.writeAll("    }\n\n");

            // Generate initFields for child - inline
            try writer.writeAll("    fn initFields(allocator: std.mem.Allocator, fields: *const struct {");
            for (all_fields) |field| {
                try writer.print(" {s}: {s},", .{ field.name, field.type_name });
            }
            for (all_properties) |prop| {
                try writer.print(" {s}: {s},", .{ prop.name, prop.type_name });
            }
            try writer.print(" }}) !{s} {{\n", .{class_name});
            try writer.print("        return {s}{{\n", .{class_name});
            try writer.writeAll("            .allocator = allocator,\n");
            for (all_fields) |field| {
                const needs_alloc = std.mem.eql(u8, field.type_name, "[]const u8") or std.mem.eql(u8, field.type_name, "[]u8");
                if (needs_alloc) {
                    try writer.print("            .{s} = try allocator.dupe(u8, fields.{s}),\n", .{ field.name, field.name });
                } else {
                    try writer.print("            .{s} = fields.{s},\n", .{ field.name, field.name });
                }
            }
            for (all_properties) |prop| {
                const needs_alloc = std.mem.eql(u8, prop.type_name, "[]const u8") or std.mem.eql(u8, prop.type_name, "[]u8");
                if (needs_alloc) {
                    try writer.print("            .{s} = try allocator.dupe(u8, fields.{s}),\n", .{ prop.name, prop.name });
                } else {
                    try writer.print("            .{s} = fields.{s},\n", .{ prop.name, prop.name });
                }
            }
            try writer.writeAll("        };\n");
            try writer.writeAll("    }");
            return try result.toOwnedSlice(allocator);
        };

        // Find the closing } of the struct literal (before the );)
        var brace_count: i32 = 1;
        var search_pos = struct_lit_start + 2; // Start after ".{"
        const struct_lit_end = blk: {
            while (search_pos < after_call.len) : (search_pos += 1) {
                if (after_call[search_pos] == '{') {
                    brace_count += 1;
                } else if (after_call[search_pos] == '}') {
                    brace_count -= 1;
                    if (brace_count == 0) break :blk search_pos;
                }
            }
            // Couldn't find closing brace
            try writer.writeAll(rewritten_body);
            try writer.writeAll("    }\n\n");

            // Generate initFields for child - inline
            try writer.writeAll("    fn initFields(allocator: std.mem.Allocator, fields: *const struct {");
            for (all_fields) |field| {
                try writer.print(" {s}: {s},", .{ field.name, field.type_name });
            }
            for (all_properties) |prop| {
                try writer.print(" {s}: {s},", .{ prop.name, prop.type_name });
            }
            try writer.print(" }}) !{s} {{\n", .{class_name});
            try writer.print("        return {s}{{\n", .{class_name});
            try writer.writeAll("            .allocator = allocator,\n");
            for (all_fields) |field| {
                const needs_alloc = std.mem.eql(u8, field.type_name, "[]const u8") or std.mem.eql(u8, field.type_name, "[]u8");
                if (needs_alloc) {
                    try writer.print("            .{s} = try allocator.dupe(u8, fields.{s}),\n", .{ field.name, field.name });
                } else {
                    try writer.print("            .{s} = fields.{s},\n", .{ field.name, field.name });
                }
            }
            for (all_properties) |prop| {
                const needs_alloc = std.mem.eql(u8, prop.type_name, "[]const u8") or std.mem.eql(u8, prop.type_name, "[]u8");
                if (needs_alloc) {
                    try writer.print("            .{s} = try allocator.dupe(u8, fields.{s}),\n", .{ prop.name, prop.name });
                } else {
                    try writer.print("            .{s} = fields.{s},\n", .{ prop.name, prop.name });
                }
            }
            try writer.writeAll("        };\n");
            try writer.writeAll("    }");
            return try result.toOwnedSlice(allocator);
        };

        // Copy everything up to (but not including) the struct literal closing }
        var content_before_close = rewritten_call_pos + rewritten_initfields_pattern.len + struct_lit_end;

        // Trim trailing comma and whitespace before the closing }
        while (content_before_close > 0) {
            const idx = content_before_close - 1;
            const c = rewritten_body[idx];
            if (c == ',' or c == ' ' or c == '\t' or c == '\n' or c == '\r') {
                content_before_close -= 1;
            } else {
                break;
            }
        }

        // Copy everything before the struct literal, ensuring we have &.{ syntax
        const before_struct_lit = rewritten_call_pos + rewritten_initfields_pattern.len + struct_lit_start;

        // Check if there's already a & before the .{
        const has_ampersand = before_struct_lit > 0 and rewritten_body[before_struct_lit - 1] == '&';

        if (has_ampersand) {
            // Already has &, just copy everything including &.{
            try writer.writeAll(rewritten_body[0 .. before_struct_lit + 2]); // Include "&.{"
        } else {
            // No &, add it
            try writer.writeAll(rewritten_body[0..before_struct_lit]);
            try writer.writeAll("&.{");
        }

        // Copy from after .{ (or &.{) to before closing }
        const after_struct_lit_open = before_struct_lit + 2; // Skip past ".{"
        try writer.writeAll(rewritten_body[after_struct_lit_open..content_before_close]);

        // Add child's additional fields to the struct literal
        if (param_fields.len > 0 or param_properties.len > 0) {
            for (param_fields) |field| {
                try writer.print(",\n            .{s} = {s}", .{ field.name, field.name });
            }
            for (param_properties) |prop| {
                try writer.print(",\n            .{s} = {s}", .{ prop.name, prop.name });
            }
        }

        // Copy the rest (starting from the closing } of the struct literal)
        const copy_end = rewritten_call_pos + rewritten_initfields_pattern.len + struct_lit_end;
        try writer.writeAll(rewritten_body[copy_end..]);
        try writer.writeAll("    }\n\n");

        // Generate child's initFields with struct parameter for all fields
        try writer.writeAll("    fn initFields(allocator: std.mem.Allocator, fields: *const struct {");

        // Add all fields to struct type
        for (all_fields) |field| {
            try writer.print(" {s}: {s},", .{ field.name, field.type_name });
        }
        for (all_properties) |prop| {
            try writer.print(" {s}: {s},", .{ prop.name, prop.type_name });
        }

        try writer.print(" }}) !{s} {{\n", .{class_name});

        // Check if allocator is actually used
        var allocator_used = false;
        for (all_fields) |field| {
            const needs_alloc = std.mem.eql(u8, field.type_name, "[]const u8") or
                std.mem.eql(u8, field.type_name, "[]u8");
            if (needs_alloc) {
                allocator_used = true;
                break;
            }
        }
        if (!allocator_used) {
            for (all_properties) |prop| {
                const needs_alloc = std.mem.eql(u8, prop.type_name, "[]const u8") or
                    std.mem.eql(u8, prop.type_name, "[]u8");
                if (needs_alloc) {
                    allocator_used = true;
                    break;
                }
            }
        }

        // If allocator not used, silence the warning
        if (!allocator_used) {
            try writer.writeAll("        _ = allocator;\n");
        }

        try writer.print("        return {s}{{\n", .{class_name});
        try writer.writeAll("            .allocator = allocator,\n");

        // Initialize all fields from the struct parameter
        for (all_fields) |field| {
            const needs_alloc = std.mem.eql(u8, field.type_name, "[]const u8") or
                std.mem.eql(u8, field.type_name, "[]u8");

            if (needs_alloc) {
                try writer.print("            .{s} = try allocator.dupe(u8, fields.{s}),\n", .{ field.name, field.name });
            } else {
                try writer.print("            .{s} = fields.{s},\n", .{ field.name, field.name });
            }
        }

        for (all_properties) |prop| {
            const needs_alloc = std.mem.eql(u8, prop.type_name, "[]const u8") or
                std.mem.eql(u8, prop.type_name, "[]u8");

            if (needs_alloc) {
                try writer.print("            .{s} = try allocator.dupe(u8, fields.{s}),\n", .{ prop.name, prop.name });
            } else {
                try writer.print("            .{s} = fields.{s},\n", .{ prop.name, prop.name });
            }
        }

        try writer.writeAll("        };\n");
        try writer.writeAll("    }");

        return try result.toOwnedSlice(allocator);
    }

    // Parent doesn't use initFields - fall back to old behavior (extend struct literal)

    // Find the return statement in parent's body
    const return_pos = std.mem.lastIndexOf(u8, parent_body, "return") orelse {
        // No return statement found - just copy body and add return at end
        try writer.writeAll(parent_body);
        try writer.print("        return {s}{{\n", .{class_name});
        try writer.writeAll("            .allocator = allocator,\n");
        for (all_fields) |field| {
            try writer.print("            .{s} = {s},\n", .{ field.name, field.name });
        }
        for (all_properties) |prop| {
            try writer.print("            .{s} = {s},\n", .{ prop.name, prop.name });
        }
        try writer.writeAll("        };\n");
        try writer.writeAll("    }");
        return try result.toOwnedSlice(allocator);
    };

    // Find the struct literal in the return statement: return .{ or return Parent{
    const return_section = parent_body[return_pos..];
    const struct_init_start = blk: {
        if (std.mem.indexOf(u8, return_section, ".{")) |pos| {
            break :blk return_pos + pos + 2; // Position after ".{"
        } else if (std.mem.indexOf(u8, return_section, parent_type)) |type_pos| {
            if (std.mem.indexOf(u8, return_section[type_pos..], "{")) |open_brace| {
                break :blk return_pos + type_pos + open_brace + 1; // Position after "Parent{"
            }
        }
        // Couldn't find struct literal, fall back to simple generation
        try writer.writeAll(parent_body);
        try writer.writeAll("    }");
        return try result.toOwnedSlice(allocator);
    };

    // Find the closing brace of the struct literal
    var brace_count: i32 = 1;
    var pos = struct_init_start;
    const struct_init_end = blk: {
        while (pos < parent_body.len) : (pos += 1) {
            if (parent_body[pos] == '{') {
                brace_count += 1;
            } else if (parent_body[pos] == '}') {
                brace_count -= 1;
                if (brace_count == 0) break :blk pos;
            }
        }
        // Couldn't find closing brace
        try writer.writeAll(parent_body);
        try writer.writeAll("    }");
        return try result.toOwnedSlice(allocator);
    };

    // Copy everything before the struct literal's closing brace
    // But trim trailing comma/whitespace
    var content_end = struct_init_end;
    while (content_end > 0) : (content_end -= 1) {
        const c = parent_body[content_end - 1];
        if (c == ',' or c == ' ' or c == '\t' or c == '\n' or c == '\r') {
            continue;
        }
        break;
    }

    try writer.writeAll(parent_body[0..content_end]);

    // Add child's additional fields/properties
    for (param_fields) |field| {
        // Check if this is a string type that needs allocation
        const needs_alloc = std.mem.eql(u8, field.type_name, "[]const u8") or
            std.mem.eql(u8, field.type_name, "[]u8");

        if (needs_alloc) {
            try writer.print(",\n            .{s} = try allocator.dupe(u8, {s})", .{ field.name, field.name });
        } else {
            try writer.print(",\n            .{s} = {s}", .{ field.name, field.name });
        }
    }

    for (param_properties) |prop| {
        try writer.writeAll(",");

        // Check if this is a string type that needs allocation
        const needs_alloc = std.mem.eql(u8, prop.type_name, "[]const u8") or
            std.mem.eql(u8, prop.type_name, "[]u8");

        if (needs_alloc) {
            try writer.print("\n            .{s} = try allocator.dupe(u8, {s})", .{ prop.name, prop.name });
        } else {
            try writer.print("\n            .{s} = {s}", .{ prop.name, prop.name });
        }
    }

    // Copy the rest of the parent body after the struct literal
    try writer.writeAll(parent_body[struct_init_end..]);
    try writer.writeAll("    }");

    return try result.toOwnedSlice(allocator);
}

/// Generate asXxx() casting methods for safe downcasting.
/// Each method checks runtime type and returns null if cast is invalid.
fn generateCastingMethods(
    _: std.mem.Allocator,
    writer: anytype,
    base_name: []const u8,
    children: [][]const u8,
) !void {
    if (children.len == 0) return;

    try writer.writeAll("\n    // ========================================================================\n");
    try writer.writeAll("    // Type-safe downcasting helpers\n");
    try writer.writeAll("    // ========================================================================\n");
    try writer.writeAll("    //\n");
    try writer.writeAll("    // Generic downcast function that checks type tag before casting.\n");
    try writer.writeAll("    // Use this for safe runtime downcasting:\n");
    try writer.writeAll("    //\n");
    try writer.print("    //   const base: *{s}Base = ...;\n", .{base_name});
    try writer.print("    //   if (base.tryCast(Element)) |elem| {{\n", .{});
    try writer.writeAll("    //       // elem is *Element\n");
    try writer.writeAll("    //   }\n");
    try writer.writeAll("    //\n");

    try writer.print(
        \\
        \\    /// Type-safe downcast to any derived type.
        \\    /// Returns null if type_tag doesn't match the requested type.
        \\    /// 
        \\    /// Example:
        \\    ///   if (base.tryCast(Element)) |elem| {{
        \\    ///       // elem is *Element
        \\    ///   }}
        \\    pub fn tryCast(self: *{s}Base, comptime T: type) ?*T {{
        \\        const type_name = @typeName(T);
        \\        const tag = comptime blk: {{
        \\            // Extract just the type name from the full path
        \\            var iter = std.mem.splitScalar(u8, type_name, '.');
        \\            var last: []const u8 = "";
        \\            while (iter.next()) |part| {{
        \\                last = part;
        \\            }}
        \\            break :blk std.meta.stringToEnum({s}TypeTag, last) orelse return null;
        \\        }};
        \\        if (self.type_tag != tag) return null;
        \\        return @ptrCast(@alignCast(self));
        \\    }}
        \\
        \\    /// Type-safe downcast to any derived type (const version).
        \\    pub fn tryCastConst(self: *const {s}Base, comptime T: type) ?*const T {{
        \\        const type_name = @typeName(T);
        \\        const tag = comptime blk: {{
        \\            var iter = std.mem.splitScalar(u8, type_name, '.');
        \\            var last: []const u8 = "";
        \\            while (iter.next()) |part| {{
        \\                last = part;
        \\            }}
        \\            break :blk std.meta.stringToEnum({s}TypeTag, last) orelse return null;
        \\        }};
        \\        if (self.type_tag != tag) return null;
        \\        return @ptrCast(@alignCast(self));
        \\    }}
        \\
    , .{ base_name, base_name, base_name, base_name });

    // Add documentation about available types
    try writer.writeAll("    //\n");
    try writer.print("    // Available types for tryCast() in {s} hierarchy:\n", .{base_name});
    for (children) |child_name| {
        try writer.print("    //   - {s}\n", .{child_name});
    }
    try writer.writeAll("    //\n\n");
}

/// Inject base field initialization into init() method return statement.
/// Uses the initForXxx() helper to properly initialize the base field.
fn injectBaseFieldInit(allocator: std.mem.Allocator, method_source: []const u8, class_name: []const u8, base_type_name: []const u8) ![]const u8 {
    // Find "return .{" in the method source
    const return_start = std.mem.indexOf(u8, method_source, "return .{") orelse {
        // No return .{ found - return unchanged
        return try allocator.dupe(u8, method_source);
    };

    const after_return_brace = return_start + "return .{".len;

    // Add .base = BaseTypeName.initForClassName(allocator) in the struct literal
    // Passes allocator to properly initialize collections (except for AbstractRange which has no allocator)
    const base_init = if (std.mem.eql(u8, base_type_name, "AbstractRange"))
        try std.fmt.allocPrint(allocator, "\n            .base = {s}Base.initFor{s}(),", .{ base_type_name, class_name })
    else
        try std.fmt.allocPrint(allocator, "\n            .base = {s}Base.initFor{s}(allocator),", .{ base_type_name, class_name });
    defer allocator.free(base_init);

    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    try result.appendSlice(allocator, method_source[0..after_return_brace]);
    try result.appendSlice(allocator, base_init);
    try result.appendSlice(allocator, method_source[after_return_brace..]);

    return result.toOwnedSlice(allocator);
}

/// Inject base field cleanup into deinit() methods for classes with inheritance.
/// Adds cleanup code for base fields that were properly initialized by initForXxx().
fn injectBaseFieldDeinit(
    allocator: std.mem.Allocator,
    method_source: []const u8,
    class_name: []const u8,
    base_type_name: []const u8,
    registry: *GlobalRegistry,
    current_file: []const u8,
) ![]const u8 {
    _ = class_name;

    // Find the closing brace of the deinit function
    const last_brace_pos = std.mem.lastIndexOfScalar(u8, method_source, '}') orelse {
        return try allocator.dupe(u8, method_source);
    };

    // Check if this class directly extends a base type with collections
    const parent_info = (registry.resolveParentReference(base_type_name, current_file) catch null) orelse {
        return try allocator.dupe(u8, method_source);
    };

    var cleanup_code: std.ArrayList(u8) = .empty;
    errdefer cleanup_code.deinit(allocator);

    try cleanup_code.appendSlice(allocator, "\n        \n");
    try cleanup_code.appendSlice(allocator, "        // Clean up base fields\n");

    var needs_cleanup = false;

    if (std.mem.eql(u8, parent_info.name, "Node")) {
        // Node classes have event_listener_list, child_nodes, and registered_observers
        try cleanup_code.appendSlice(allocator,
            \\        if (self.base.event_listener_list) |list| {
            \\            list.deinit(self.allocator);
            \\            self.allocator.destroy(list);
            \\        }
            \\        self.base.child_nodes.deinit();
            \\        self.base.registered_observers.deinit();
            \\
        );
        needs_cleanup = true;
    } else if (std.mem.eql(u8, parent_info.name, "EventTarget")) {
        // EventTarget classes only have event_listener_list
        try cleanup_code.appendSlice(allocator,
            \\        if (self.base.event_listener_list) |list| {
            \\            list.deinit(self.allocator);
            \\            self.allocator.destroy(list);
            \\        }
            \\
        );
        needs_cleanup = true;
    }

    if (!needs_cleanup) {
        cleanup_code.deinit(allocator);
        return try allocator.dupe(u8, method_source);
    }

    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    try result.appendSlice(allocator, method_source[0..last_brace_pos]);
    const cleanup_slice = try cleanup_code.toOwnedSlice(allocator);
    defer allocator.free(cleanup_slice);
    try result.appendSlice(allocator, cleanup_slice);
    try result.appendSlice(allocator, method_source[last_brace_pos..]);

    return result.toOwnedSlice(allocator);
}

/// Generate XxxBase struct for polymorphism support.
/// Helper to qualify type names to avoid conflicts with nested declarations.
/// Replaces simple type names with fully qualified imports for known conflicting types.
fn qualifyTypeForBaseStruct(allocator: std.mem.Allocator, type_name: []const u8, current_class: []const u8) ![]const u8 {
    // Map of type names to their defining class (to avoid self-imports)
    const class_map = std.StaticStringMap([]const u8).initComptime(.{
        .{ "Document", "Document" },
        .{ "RegisteredObserver", "RegisteredObserver" },
        .{ "EventListener", "EventTarget" }, // EventListener is defined in EventTarget module
        .{ "Event", "Event" },
    });

    // Map of type names to their module paths
    const module_map = std.StaticStringMap([]const u8).initComptime(.{
        .{ "Document", "document" },
        .{ "RegisteredObserver", "registered_observer" },
        .{ "EventListener", "event_target" },
        .{ "Event", "event" },
    });

    // Check if this is a simple type name that needs qualification
    if (class_map.get(type_name)) |defining_class| {
        // Don't qualify if this type is defined in the current class's module
        if (std.mem.eql(u8, defining_class, current_class)) {
            // Type is local to this module, don't qualify
            return try allocator.dupe(u8, type_name);
        }
        // Qualify with full import path
        const module = module_map.get(type_name).?; // Must exist if class_map has it
        const qualified = try std.fmt.allocPrint(allocator, "@import(\"{s}\").{s}", .{ module, type_name });
        return qualified;
    }

    // Check for pointer types like "?*Document" or "*Document"
    var is_optional = false;
    var is_pointer = false;
    var base_type_start: usize = 0;

    if (std.mem.startsWith(u8, type_name, "?*")) {
        is_optional = true;
        is_pointer = true;
        base_type_start = 2;
    } else if (std.mem.startsWith(u8, type_name, "*")) {
        is_pointer = true;
        base_type_start = 1;
    }

    if (is_pointer) {
        const base_type = type_name[base_type_start..];
        if (class_map.get(base_type)) |defining_class| {
            // Don't qualify if type is local
            if (std.mem.eql(u8, defining_class, current_class)) {
                return try allocator.dupe(u8, type_name);
            }
            const module = module_map.get(base_type).?;
            const qualified = try std.fmt.allocPrint(allocator, "@import(\"{s}\").{s}", .{ module, base_type });
            defer allocator.free(qualified);
            if (is_optional) {
                return try std.fmt.allocPrint(allocator, "?*{s}", .{qualified});
            } else {
                return try std.fmt.allocPrint(allocator, "*{s}", .{qualified});
            }
        }
    }

    // Check for generic types like "std.ArrayList(RegisteredObserver)"
    if (std.mem.indexOf(u8, type_name, "ArrayList(")) |start| {
        const inner_start = start + "ArrayList(".len;
        if (std.mem.indexOfScalar(u8, type_name[inner_start..], ')')) |inner_len| {
            const inner_type = type_name[inner_start..][0..inner_len];
            if (class_map.get(inner_type)) |defining_class| {
                // Don't qualify if type is local
                if (std.mem.eql(u8, defining_class, current_class)) {
                    return try allocator.dupe(u8, type_name);
                }
                const module = module_map.get(inner_type).?;
                const qualified = try std.fmt.allocPrint(allocator, "@import(\"{s}\").{s}", .{ module, inner_type });
                defer allocator.free(qualified);
                const prefix = type_name[0..inner_start];
                const suffix = type_name[inner_start + inner_len ..];
                return try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ prefix, qualified, suffix });
            }
        }
    }

    // No qualification needed, return as-is
    return try allocator.dupe(u8, type_name);
}

/// Map child type name to NODE_TYPE constant for proper initialization
fn getNodeTypeConstant(child_name: []const u8) []const u8 {
    if (std.mem.eql(u8, child_name, "Element")) return "Node.ELEMENT_NODE";
    if (std.mem.eql(u8, child_name, "Attr")) return "Node.ATTRIBUTE_NODE";
    if (std.mem.eql(u8, child_name, "Text")) return "Node.TEXT_NODE";
    if (std.mem.eql(u8, child_name, "CDATASection")) return "Node.CDATA_SECTION_NODE";
    if (std.mem.eql(u8, child_name, "ProcessingInstruction")) return "Node.PROCESSING_INSTRUCTION_NODE";
    if (std.mem.eql(u8, child_name, "Comment")) return "Node.COMMENT_NODE";
    if (std.mem.eql(u8, child_name, "Document")) return "Node.DOCUMENT_NODE";
    if (std.mem.eql(u8, child_name, "DocumentType")) return "Node.DOCUMENT_TYPE_NODE";
    if (std.mem.eql(u8, child_name, "DocumentFragment")) return "Node.DOCUMENT_FRAGMENT_NODE";
    if (std.mem.eql(u8, child_name, "CharacterData")) return "Node.TEXT_NODE";
    if (std.mem.eql(u8, child_name, "ShadowRoot")) return "Node.DOCUMENT_FRAGMENT_NODE";
    return "1"; // ELEMENT_NODE as fallback
}

/// Generate init helper for a base struct child type
fn generateBaseInitHelper(
    allocator: std.mem.Allocator,
    writer: anytype,
    base_type_name: []const u8,
    child_name: []const u8,
) !void {
    _ = allocator; // Future use for dynamic allocations
    if (std.mem.eql(u8, base_type_name, "Node")) {
        // Node base includes EventTarget fields + Node fields
        const node_type = getNodeTypeConstant(child_name);
        try writer.print(
            \\    /// Create a base struct initialized for {s}.
            \\    /// Use this in {s}.init() to properly initialize the base field.
            \\    /// All collection fields are properly initialized with the provided allocator.
            \\    pub fn initFor{s}(allocator: std.mem.Allocator) NodeBase {{
            \\        return .{{
            \\            .type_tag = .{s},
            \\            .event_listener_list = null,
            \\            .allocator = allocator,
            \\            .node_type = {s},
            \\            .node_name = "",
            \\            .parent_node = null,
            \\            .child_nodes = infra.List(*Node).init(allocator),
            \\            .owner_document = null,
            \\            .registered_observers = infra.List(@import("registered_observer").RegisteredObserver).init(allocator),
            \\        }};
            \\    }}
            \\
            \\
        , .{ child_name, child_name, child_name, child_name, node_type });
    } else if (std.mem.eql(u8, base_type_name, "EventTarget")) {
        // EventTarget base only has event_listener_list and allocator
        try writer.print(
            \\    /// Create a base struct initialized for {s}.
            \\    /// Use this in {s}.init() to properly initialize the base field.
            \\    pub fn initFor{s}(allocator: std.mem.Allocator) EventTargetBase {{
            \\        return .{{
            \\            .type_tag = .{s},
            \\            .event_listener_list = null,
            \\            .allocator = allocator,
            \\        }};
            \\    }}
            \\
            \\
        , .{ child_name, child_name, child_name, child_name });
    } else if (std.mem.eql(u8, base_type_name, "AbstractRange")) {
        // AbstractRange base only has type_tag and boundary points (no allocator)
        try writer.print(
            \\    /// Create a base struct initialized for {s}.
            \\    /// Use this in {s}.init() to properly initialize the base field.
            \\    pub fn initFor{s}() {s}Base {{
            \\        return .{{
            \\            .type_tag = .{s},
            \\        }};
            \\    }}
            \\
            \\
        , .{ child_name, child_name, child_name, base_type_name, child_name });
    } else {
        // Other base types (e.g., DocumentFragment which extends Node)
        try writer.print(
            \\    /// Create a base struct initialized for {s}.
            \\    /// Use this in {s}.init() to properly initialize the base field.
            \\    pub fn initFor{s}(allocator: std.mem.Allocator) {s}Base {{
            \\        return .{{
            \\            .type_tag = .{s},
            \\            .allocator = allocator,
            \\        }};
            \\    }}
            \\
            \\
        , .{ child_name, child_name, child_name, base_type_name, child_name });
    }
}

/// This struct contains all fields from the base interface (including inherited fields).
/// Derived classes will have `base: XxxBase` as their first field.
fn generateBaseStruct(
    allocator: std.mem.Allocator,
    writer: anytype,
    parsed: anytype,
    registry: *GlobalRegistry,
    current_file: []const u8,
    base_info: *const BaseTypeInfo,
    imports: *ImportSet, // Shared ImportSet for the entire file
) !void {
    // Debug: print what we're generating
    std.debug.print("Generating {s}Base (parent: {s})\n", .{ parsed.name, if (parsed.parent_name) |p| p else "none" });

    // For base structs that inherit from Node, add necessary imports to the shared ImportSet
    // These are needed by fields like infra.List(*Node), owner_document: ?*Document, etc.
    if (parsed.parent_name) |parent_ref| {
        // Check if this inherits from Node
        var check_parent: ?[]const u8 = parent_ref;
        var check_file = current_file;
        var inherits_from_node_for_base = false;

        while (check_parent) |p| {
            const p_name = if (std.mem.indexOfScalar(u8, p, '.')) |dot_pos|
                p[dot_pos + 1 ..]
            else
                p;

            if (std.mem.eql(u8, p_name, "Node")) {
                inherits_from_node_for_base = true;
                break;
            }

            if (try registry.resolveParentReference(p, check_file)) |parent_info| {
                check_parent = parent_info.parent_name;
                check_file = parent_info.file_path;
            } else {
                break;
            }
        }

        // If this base struct inherits from Node, add necessary type aliases to shared ImportSet
        if (inherits_from_node_for_base) {
            try imports.addPackageType("Node", "node");
            try imports.addStdType("Allocator");
            try imports.addModule("infra");
        }
    }

    // NOTE: Imports are NOT emitted here - they'll be emitted once by the caller

    // Generate TypeTag enum for runtime type checking
    try writer.print(
        \\/// Runtime type tag for {s} hierarchy.
        \\/// Used for safe downcasting from {s}Base to derived types.
        \\pub const {s}TypeTag = enum {{
        \\
    , .{ parsed.name, parsed.name, parsed.name });

    // Add enum values for base type and all children
    try writer.print("    {s},\n", .{parsed.name});
    for (base_info.children.items) |child_name| {
        try writer.print("    {s},\n", .{child_name});
    }

    try writer.writeAll("};\n\n");

    // Generate doc comment
    try writer.print(
        \\/// Base struct for {s} hierarchy polymorphism.
        \\/// All {s}-derived types have `base: {s}Base` as their first field.
        \\/// This enables safe downcasting via @ptrCast.
        \\pub const {s}Base = struct {{
        \\
    , .{ parsed.name, parsed.name, parsed.name, parsed.name });

    // Add runtime type tag as first field
    try writer.print("    /// Runtime type tag for safe downcasting.\n", .{});
    try writer.print("    type_tag: {s}TypeTag,\n\n", .{parsed.name});

    // Check if class already has allocator field
    const has_allocator_field = blk: {
        for (parsed.fields) |field| {
            if (std.mem.eql(u8, field.name, "allocator")) break :blk true;
        }
        break :blk false;
    };

    // Check if class needs an allocator
    const needs_allocator = blk: {
        for (parsed.fields) |field| {
            if (std.mem.eql(u8, field.type_name, "[]const u8") or std.mem.eql(u8, field.type_name, "[]u8")) {
                break :blk true;
            }
        }
        for (parsed.properties) |prop| {
            const is_string_type = std.mem.eql(u8, prop.type_name, "[]const u8") or std.mem.eql(u8, prop.type_name, "[]u8");
            if (is_string_type and prop.access == .read_write) {
                break :blk true;
            }
        }
        break :blk false;
    };

    // Collect parent fields (if any)
    var all_parent_fields: std.ArrayList(FieldDef) = .empty;
    defer all_parent_fields.deinit(allocator);
    var all_parent_properties: std.ArrayList(PropertyDef) = .empty;
    defer all_parent_properties.deinit(allocator);
    var has_parent_allocator = false;

    if (parsed.parent_name) |parent_ref| {
        // Track field names to avoid duplicates
        var seen_field_names = std.StringHashMap(void).init(allocator);
        defer seen_field_names.deinit();
        var seen_property_names = std.StringHashMap(void).init(allocator);
        defer seen_property_names.deinit();

        var current_parent: ?[]const u8 = parent_ref;
        var current_file_path = current_file;

        while (current_parent) |parent| {
            std.debug.print("  {s}Base: resolving parent '{s}' from file '{s}'\n", .{ parsed.name, parent, current_file_path });

            // Debug: Check what imports exist
            if (registry.files.get(current_file_path)) |file_info| {
                var import_it = file_info.imports.iterator();
                var count: usize = 0;
                while (import_it.next()) |entry| {
                    std.debug.print("    Import: '{s}' -> '{s}'\n", .{ entry.key_ptr.*, entry.value_ptr.* });
                    count += 1;
                }
                if (count == 0) {
                    std.debug.print("    No imports found in file info!\n", .{});
                }
            }

            const parent_info = (try registry.resolveParentReference(parent, current_file_path)) orelse {
                std.debug.print("  {s}Base: WARNING - could not resolve parent '{s}'\n", .{ parsed.name, parent });

                // Debug: Check specific expected paths
                const expected_paths = [_][]const u8{
                    "dom/event_target",
                    "dom/event_target.zig",
                    "dom/EventTarget.zig",
                };
                for (expected_paths) |path| {
                    if (registry.files.contains(path)) {
                        std.debug.print("    Found file: '{s}'\n", .{path});
                    } else {
                        std.debug.print("    Missing file: '{s}'\n", .{path});
                    }
                }
                break;
            };

            // Debug: Print parent info
            std.debug.print("  {s}Base: collecting from parent {s} ({d} fields, {d} props)\n", .{ parsed.name, parent_info.name, parent_info.fields.len, parent_info.properties.len });

            for (parent_info.fields) |field| {
                // Track if parent has allocator
                if (std.mem.eql(u8, field.name, "allocator")) {
                    has_parent_allocator = true;
                }

                // Skip if we've already seen this field name
                const gop = try seen_field_names.getOrPut(field.name);
                if (!gop.found_existing) {
                    try all_parent_fields.append(allocator, field);
                } else {
                    std.debug.print("    Skipping duplicate field: {s}\n", .{field.name});
                }
            }
            for (parent_info.properties) |prop| {
                // Skip if we've already seen this property name
                const gop = try seen_property_names.getOrPut(prop.name);
                if (!gop.found_existing) {
                    try all_parent_properties.append(allocator, prop);
                } else {
                    std.debug.print("    Skipping duplicate property: {s}\n", .{prop.name});
                }
            }

            current_parent = parent_info.parent_name;
            current_file_path = parent_info.file_path;
        }

        // Reverse to get correct order (grandparent first)
        std.mem.reverse(FieldDef, all_parent_fields.items);
        std.mem.reverse(PropertyDef, all_parent_properties.items);

        // Write parent fields (with qualified type names to avoid conflicts)
        for (all_parent_fields.items) |field| {
            const qualified_type = try qualifyTypeForBaseStruct(allocator, field.type_name, parsed.name);
            defer allocator.free(qualified_type);

            if (field.default_value) |default| {
                try writer.print("    {s}: {s} = {s},\n", .{ field.name, qualified_type, default });
            } else {
                try writer.print("    {s}: {s},\n", .{ field.name, qualified_type });
            }
        }
        for (all_parent_properties.items) |prop| {
            const qualified_type = try qualifyTypeForBaseStruct(allocator, prop.type_name, parsed.name);
            defer allocator.free(qualified_type);

            if (prop.default_value) |default| {
                try writer.print("    {s}: {s} = {s},\n", .{ prop.name, qualified_type, default });
            } else {
                try writer.print("    {s}: {s},\n", .{ prop.name, qualified_type });
            }
        }

        if (all_parent_fields.items.len > 0 or all_parent_properties.items.len > 0) {
            try writer.writeAll("\n");
        }
    }

    // Add allocator if needed and not from parent
    std.debug.print("  {s}Base: has_allocator_field={}, has_parent_allocator={}, needs_allocator={}\n", .{ parsed.name, has_allocator_field, has_parent_allocator, needs_allocator });
    if (!has_allocator_field and !has_parent_allocator and needs_allocator) {
        try writer.writeAll("    allocator: std.mem.Allocator,\n\n");
    }

    // Write own properties (with qualified type names to avoid conflicts)
    for (parsed.properties) |prop| {
        if (prop.doc_comment) |doc| {
            var doc_lines = std.mem.splitScalar(u8, doc, '\n');
            while (doc_lines.next()) |line| {
                try writer.print("    /// {s}\n", .{line});
            }
        }

        const qualified_type = try qualifyTypeForBaseStruct(allocator, prop.type_name, parsed.name);
        defer allocator.free(qualified_type);

        if (prop.default_value) |default| {
            try writer.print("    {s}: {s} = {s},\n", .{ prop.name, qualified_type, default });
        } else {
            try writer.print("    {s}: {s},\n", .{ prop.name, qualified_type });
        }
    }

    // Write own fields (with qualified type names to avoid conflicts)
    for (parsed.fields) |field| {
        // Skip allocator if parent already has it
        if (has_parent_allocator and std.mem.eql(u8, field.name, "allocator")) {
            std.debug.print("  {s}Base: Skipping own allocator field (parent has it)\n", .{parsed.name});
            continue;
        }

        if (field.doc_comment) |doc| {
            var doc_lines = std.mem.splitScalar(u8, doc, '\n');
            while (doc_lines.next()) |line| {
                try writer.print("    /// {s}\n", .{line});
            }
        }

        const qualified_type = try qualifyTypeForBaseStruct(allocator, field.type_name, parsed.name);
        defer allocator.free(qualified_type);

        if (field.default_value) |default| {
            try writer.print("    {s}: {s} = {s},\n", .{ field.name, qualified_type, default });
        } else {
            try writer.print("    {s}: {s},\n", .{ field.name, qualified_type });
        }
    }

    // Generate initialization helper for each derived type
    try writer.writeAll("\n    // ========================================================================\n");
    try writer.writeAll("    // Base struct initialization helpers\n");
    try writer.writeAll("    // ========================================================================\n");
    try writer.writeAll("    //\n");
    try writer.writeAll("    // Helper functions to create properly initialized base structs.\n");
    try writer.writeAll("    // Each derived type gets its own initialization helper.\n");
    try writer.writeAll("    // All collection fields (lists) are properly initialized with allocator.\n");
    try writer.writeAll("    //\n\n");

    for (base_info.children.items) |child_name| {
        try generateBaseInitHelper(allocator, writer, parsed.name, child_name);
    }

    // Generate casting methods for all children
    try generateCastingMethods(allocator, writer, parsed.name, base_info.children.items);

    // Close the struct
    try writer.writeAll("};\n\n");
}

fn generateEnhancedClassWithRegistry(
    allocator: std.mem.Allocator,
    parsed: anytype,
    config: ClassConfig,
    current_file: []const u8,
    registry: *GlobalRegistry,
    base_types: *const std.StringHashMap(BaseTypeInfo),
) ![]const u8 {
    // Validate class name to prevent injection attacks
    if (!isValidTypeName(parsed.name)) return error.InvalidClassName;

    // Check if this class is a base type (interface with no parent but has children)
    const is_base_type = base_types.contains(parsed.name);

    // Resolve all mixins and detect conflicts early
    var mixin_infos: std.ArrayList(ClassInfo) = .empty;
    defer mixin_infos.deinit(allocator);

    for (parsed.mixin_names) |mixin_ref| {
        // First try to get from mixins registry
        if (registry.getMixin(mixin_ref)) |mixin_info| {
            try mixin_infos.append(allocator, mixin_info);
        } else if (try registry.resolveParentReference(mixin_ref, current_file)) |mixin_info| {
            // Fallback to resolveParentReference for cross-file mixin references
            try mixin_infos.append(allocator, mixin_info);
        } else {
            // Mixin not found
            std.debug.print("error: Cannot resolve mixin '{s}' in interface '{s}'\n", .{ mixin_ref, parsed.name });
            std.debug.print("  Mixin not found in registry.\n", .{});
            std.debug.print("\n  Make sure:\n", .{});
            std.debug.print("    1. The mixin is defined with webidl.mixin()\n", .{});
            std.debug.print("    2. The mixin file is in the source directory\n", .{});
            std.debug.print("    3. The mixin name matches exactly\n", .{});
            return error.MixinNotFound;
        }
    }

    // Detect conflicts between mixins and interface members
    try detectMixinConflicts(
        allocator,
        parsed.name,
        mixin_infos.items,
        parsed.fields,
        parsed.methods,
    );

    var code: std.ArrayList(u8) = .empty;
    defer code.deinit(allocator);

    const writer = code.writer(allocator);

    // ========================================================================
    // DECLARATIVE IMPORT COLLECTION
    // Create ONE ImportSet for the entire generated file (base struct + class).
    // All imports are collected into a set first, then emitted once.
    // This prevents duplicate declarations regardless of code path.
    // ========================================================================

    var imports = ImportSet.init(allocator);
    defer imports.deinit();

    // Generate XxxBase struct if this is a base type
    // (Collects its imports into the shared ImportSet, but doesn't emit yet)
    if (is_base_type) {
        const base_info = base_types.get(parsed.name).?; // Safe unwrap - we checked is_base_type
        try generateBaseStruct(allocator, writer, parsed, registry, current_file, &base_info, &imports);
    }

    // Emit class-level doc comment if present
    if (parsed.class_doc) |doc| {
        var doc_lines = std.mem.splitScalar(u8, doc, '\n');
        while (doc_lines.next()) |line| {
            try writer.print("/// {s}\n", .{line});
        }
    }

    // Track inheritance relationships for import decisions
    var parent_base_type_name: ?[]const u8 = null;
    var inherits_from_event_target = false;
    var inherits_from_node = false;

    if (parsed.parent_name) |parent_ref| {
        // Extract parent class name (handle "base.Type" format)
        const parent_class_name = if (std.mem.indexOfScalar(u8, parent_ref, '.')) |dot_pos|
            parent_ref[dot_pos + 1 ..]
        else
            parent_ref;

        // Check if parent is a base type
        if (base_types.contains(parent_class_name)) {
            parent_base_type_name = parent_class_name;
            // Import the base type
            const base_module = try pascalToSnakeCase(allocator, parent_class_name);
            defer allocator.free(base_module);
            const base_import = try std.fmt.allocPrint(allocator, "const {s}Base = @import(\"{s}\").{s}Base;\n", .{ parent_class_name, base_module, parent_class_name });
            const base_name = try std.fmt.allocPrint(allocator, "{s}Base", .{parent_class_name});
            defer allocator.free(base_name);
            // addRawOwned takes ownership of base_import
            try imports.addRawOwned(base_name, base_import);
        }

        // Check inheritance chain for EventTarget and Node
        var check_parent: ?[]const u8 = parent_ref;
        var check_file = current_file;
        while (check_parent) |p| {
            const p_name = if (std.mem.indexOfScalar(u8, p, '.')) |dot_pos|
                p[dot_pos + 1 ..]
            else
                p;

            if (std.mem.eql(u8, p_name, "EventTarget")) {
                inherits_from_event_target = true;
            }

            if (std.mem.eql(u8, p_name, "Node")) {
                inherits_from_node = true;
            }

            // Try to resolve parent to check its parent
            if (try registry.resolveParentReference(p, check_file)) |parent_info| {
                check_parent = parent_info.parent_name;
                check_file = parent_info.file_path;
            } else {
                break;
            }
        }
    }

    // Add imports based on inheritance (using ImportSet methods for deduplication)
    if (inherits_from_event_target) {
        try imports.addEventTargetInheritanceImports();
    }

    if (inherits_from_node and !std.mem.eql(u8, parsed.name, "Node")) {
        try imports.addNodeInheritanceImports(parsed.name);
    }

    // Add mixin imports (if any)
    if (parsed.mixin_names.len > 0) {
        for (parsed.mixin_names) |mixin_name| {
            // Convert PascalCase to snake_case for module name
            const module_name = try pascalToSnakeCase(allocator, mixin_name);
            defer allocator.free(module_name);
            try imports.addPackageType(mixin_name, module_name);
        }
    }

    // Add common imports based on field and method usage
    // Collect all type references from fields AND methods
    var type_references: std.ArrayList([]const u8) = .empty;
    defer type_references.deinit(allocator);

    // Collect from fields
    for (parsed.fields) |field| {
        try type_references.append(allocator, field.type_name);
    }

    // Collect from methods (source code contains parameter and return types)
    for (parsed.methods) |method| {
        // Method source contains type names - just add it to search
        try type_references.append(allocator, method.source);
    }

    // Now analyze all collected type references
    for (type_references.items) |type_code| {
        // Check if Allocator is referenced
        if (std.mem.indexOf(u8, type_code, "Allocator") != null) {
            try imports.addStdType("Allocator");
        }
        // If any type reference uses infra.* types, add infra module
        if (std.mem.indexOf(u8, type_code, "infra.")) |_| {
            try imports.addModule("infra");
        }

        // Note: webidl is NOT added here because it's preserved from source
        // (webidl is used so universally that we let source files keep their import)

        // Extract all referenced type names from type code
        // Handles simple types (*Node), qualified types (infra.List), and generic types (infra.List(*Node))
        // Strategy: Search for known type names anywhere in the type string

        // Check for common DOM types (these can appear as base types or generic parameters)
        if (std.mem.indexOf(u8, type_code, "Element") != null and !std.mem.startsWith(u8, parsed.name, "Element")) {
            // Contains "Element" and this class is not Element itself
            try imports.addPackageType("Element", "element");
        }
        if (std.mem.indexOf(u8, type_code, "Node") != null and !std.mem.eql(u8, parsed.name, "Node")) {
            // Contains "Node" and this class is not Node itself
            try imports.addPackageType("Node", "node");
        }
        if (std.mem.indexOf(u8, type_code, "Document") != null and !std.mem.eql(u8, parsed.name, "Document")) {
            try imports.addPackageType("Document", "document");
        }
        if (std.mem.indexOf(u8, type_code, "Event") != null and !std.mem.eql(u8, parsed.name, "Event")) {
            try imports.addPackageType("Event", "event");
        }
        if (std.mem.indexOf(u8, type_code, "CharacterData") != null and !std.mem.eql(u8, parsed.name, "CharacterData")) {
            try imports.addPackageType("CharacterData", "character_data");
        }
        if (std.mem.indexOf(u8, type_code, "Text") != null and !std.mem.eql(u8, parsed.name, "Text")) {
            try imports.addPackageType("Text", "text");
        }
        if (std.mem.indexOf(u8, type_code, "RegisteredObserver") != null) {
            try imports.addPackageType("RegisteredObserver", "registered_observer");
        }
        if (std.mem.indexOf(u8, type_code, "ShadowRoot") != null and !std.mem.eql(u8, parsed.name, "ShadowRoot")) {
            try imports.addPackageType("ShadowRoot", "shadow_root");
        }
        if (std.mem.indexOf(u8, type_code, "AbortSignal") != null and !std.mem.eql(u8, parsed.name, "AbortSignal")) {
            try imports.addPackageType("AbortSignal", "abort_signal");
        }
    }

    // ========================================================================
    // EMIT ALL IMPORTS (deduplicated)
    // ========================================================================
    try imports.emit(writer);

    try writer.print("pub const {s} = struct {{\n", .{parsed.name});

    // Emit "const Self = @This();" if the source class had it
    if (parsed.has_self_type) {
        try writer.writeAll("    const Self = @This();\n\n");
    }

    // Check if class already has allocator field
    const has_allocator_field = blk: {
        for (parsed.fields) |field| {
            if (std.mem.eql(u8, field.name, "allocator")) break :blk true;
        }
        break :blk false;
    };

    // Check if class needs an allocator (has string fields or read-write string properties)
    const needs_allocator = blk: {
        // Check own fields for strings
        for (parsed.fields) |field| {
            if (std.mem.eql(u8, field.type_name, "[]const u8") or std.mem.eql(u8, field.type_name, "[]u8")) {
                break :blk true;
            }
        }
        // Check properties - only read-write ones need allocation
        for (parsed.properties) |prop| {
            const is_string_type = std.mem.eql(u8, prop.type_name, "[]const u8") or std.mem.eql(u8, prop.type_name, "[]u8");
            if (is_string_type and prop.access == .read_write) {
                break :blk true;
            }
        }
        break :blk false;
    };

    // Only add allocator if not already present AND class needs one
    if (!has_allocator_field and needs_allocator) {
        try writer.writeAll("    allocator: std.mem.Allocator,\n");

        // Separator if there are other fields
        if ((parsed.parent_name != null) or parsed.mixin_names.len > 0 or parsed.properties.len > 0 or parsed.fields.len > 0) {
            try writer.writeAll("\n");
        }
    }

    // Generate parent fields (flattened - copy fields directly from parent classes)
    if (parsed.parent_name) |parent_ref| {
        if (parent_base_type_name) |base_name| {
            // Use base field instead of flattening (import already added above)
            try writer.print("    base: {s}Base,\n\n", .{base_name});
        } else {
            // Flatten parent fields (existing logic)
            var current_parent: ?[]const u8 = parent_ref;
            var current_file_path = current_file;

            // Collect all parent fields by walking up the hierarchy
            var all_parent_fields: std.ArrayList(FieldDef) = .empty;
            defer all_parent_fields.deinit(allocator);
            var all_parent_properties: std.ArrayList(PropertyDef) = .empty;
            defer all_parent_properties.deinit(allocator);

            while (current_parent) |parent| {
                const parent_info = (try registry.resolveParentReference(parent, current_file_path)) orelse break;

                // Add parent fields (in reverse order, will reverse later)
                for (parent_info.fields) |field| {
                    try all_parent_fields.append(allocator, field);
                }
                for (parent_info.properties) |prop| {
                    try all_parent_properties.append(allocator, prop);
                }

                current_parent = parent_info.parent_name;
                current_file_path = parent_info.file_path;
            }

            // Reverse to get correct inheritance order (grandparent first)
            std.mem.reverse(FieldDef, all_parent_fields.items);
            std.mem.reverse(PropertyDef, all_parent_properties.items);

            // Write parent fields
            for (all_parent_fields.items) |field| {
                if (field.default_value) |default| {
                    try writer.print("    {s}: {s} = {s},\n", .{ field.name, field.type_name, default });
                } else {
                    try writer.print("    {s}: {s},\n", .{ field.name, field.type_name });
                }
            }
            for (all_parent_properties.items) |prop| {
                if (prop.default_value) |default| {
                    try writer.print("    {s}: {s} = {s},\n", .{ prop.name, prop.type_name, default });
                } else {
                    try writer.print("    {s}: {s},\n", .{ prop.name, prop.type_name });
                }
            }

            if (all_parent_fields.items.len > 0 or all_parent_properties.items.len > 0) {
                if (parsed.mixin_names.len > 0 or parsed.properties.len > 0 or parsed.fields.len > 0) {
                    try writer.writeAll("\n");
                }
            }
        } // end else (not a base type - flatten fields)
    } // end if (has parent)

    // Generate mixin fields (flattened - copy fields directly from mixin classes)
    for (mixin_infos.items) |mixin_info| {
        // Add section header for mixin fields
        if (mixin_info.fields.len > 0 or mixin_info.properties.len > 0) {
            try writer.print("    // ========================================================================\n", .{});
            try writer.print("    // Fields from {s} mixin\n", .{mixin_info.name});
            try writer.print("    // ========================================================================\n", .{});
        }

        // Copy all fields from mixin
        for (mixin_info.fields) |field| {
            if (field.doc_comment) |doc| {
                var doc_lines = std.mem.splitScalar(u8, doc, '\n');
                while (doc_lines.next()) |line| {
                    try writer.print("    /// {s}\n", .{line});
                }
            }
            if (field.default_value) |default| {
                try writer.print("    {s}: {s} = {s},\n", .{ field.name, field.type_name, default });
            } else {
                try writer.print("    {s}: {s},\n", .{ field.name, field.type_name });
            }
        }

        // Copy all property fields from mixin
        for (mixin_info.properties) |prop| {
            if (prop.doc_comment) |doc| {
                var doc_lines = std.mem.splitScalar(u8, doc, '\n');
                while (doc_lines.next()) |line| {
                    try writer.print("    /// {s}\n", .{line});
                }
            }
            if (prop.default_value) |default| {
                try writer.print("    {s}: {s} = {s},\n", .{ prop.name, prop.type_name, default });
            } else {
                try writer.print("    {s}: {s},\n", .{ prop.name, prop.type_name });
            }
        }

        if (mixin_info.fields.len > 0 or mixin_info.properties.len > 0) {
            try writer.writeAll("\n");
        }
    }

    // Add section header for interface's own fields
    if (parsed.properties.len > 0 or parsed.fields.len > 0) {
        try writer.print("    // ========================================================================\n", .{});
        try writer.print("    // {s} fields\n", .{parsed.name});
        try writer.print("    // ========================================================================\n", .{});
    }

    for (parsed.properties) |prop| {
        if (prop.doc_comment) |doc| {
            var doc_lines = std.mem.splitScalar(u8, doc, '\n');
            while (doc_lines.next()) |line| {
                try writer.print("    /// {s}\n", .{line});
            }
        }
        if (prop.default_value) |default| {
            try writer.print("    {s}: {s} = {s},\n", .{ prop.name, prop.type_name, default });
        } else {
            try writer.print("    {s}: {s},\n", .{ prop.name, prop.type_name });
        }
    }

    for (parsed.fields) |field| {
        if (field.doc_comment) |doc| {
            var doc_lines = std.mem.splitScalar(u8, doc, '\n');
            while (doc_lines.next()) |line| {
                try writer.print("    /// {s}\n", .{line});
            }
        }
        if (field.default_value) |default| {
            try writer.print("    {s}: {s} = {s},\n", .{ field.name, field.type_name, default });
        } else {
            try writer.print("    {s}: {s},\n", .{ field.name, field.type_name });
        }
    }

    // Emit constants (pub const declarations with types)
    if (parsed.constants.len > 0) {
        try writer.writeAll("\n");
        for (parsed.constants) |constant| {
            // Make const @import declarations public so they can be re-exported
            // Example: "const TextEncoderEncodeIntoResult = @import(...)" -> "pub const TextEncoderEncodeIntoResult = @import(...)"
            if (std.mem.startsWith(u8, constant, "const ") and std.mem.indexOf(u8, constant, "@import") != null) {
                try writer.print("    pub {s}\n", .{constant});
            } else {
                try writer.print("    {s}\n", .{constant});
            }
        }
    }

    if ((parsed.fields.len > 0 or parsed.constants.len > 0) and parsed.methods.len > 0) {
        try writer.writeAll("\n");
    }

    // First, emit init and deinit if user defined them
    for (parsed.methods) |method| {
        if (std.mem.eql(u8, method.name, "init") or std.mem.eql(u8, method.name, "deinit")) {
            // Emit doc comment if present
            if (method.doc_comment) |doc| {
                var doc_lines = std.mem.splitScalar(u8, doc, '\n');
                while (doc_lines.next()) |line| {
                    try writer.print("    /// {s}\n", .{line});
                }
            }
            // Rename reserved parameters to avoid shadowing
            const renamed_source = try renameReservedParams(allocator, method.source);
            defer allocator.free(renamed_source);

            // If this is init() and class has a base field, inject base initialization
            // If this is deinit() and class has a base field, inject base cleanup
            const final_source = blk: {
                if (std.mem.eql(u8, method.name, "init") and parent_base_type_name != null) {
                    break :blk try injectBaseFieldInit(allocator, renamed_source, parsed.name, parent_base_type_name.?);
                } else if (std.mem.eql(u8, method.name, "deinit") and parent_base_type_name != null) {
                    break :blk try injectBaseFieldDeinit(allocator, renamed_source, parsed.name, parent_base_type_name.?, registry, current_file);
                }
                break :blk renamed_source;
            };
            defer if (parent_base_type_name != null and
                (std.mem.eql(u8, method.name, "init") or std.mem.eql(u8, method.name, "deinit")))
            {
                allocator.free(final_source);
            };

            try writer.print("    {s}\n", .{final_source});
        }
    }

    // Generate toBase() helper method if this class has a base field
    if (parent_base_type_name) |base_name| {
        try writer.writeAll("\n");
        try writer.print(
            \\    /// Helper to get base struct for polymorphic operations.
            \\    /// This enables safe upcasting to {s}Base for type-generic code.
            \\    pub fn toBase(self: *{s}) *{s}Base {{
            \\        return &self.base;
            \\    }}
            \\
        , .{ base_name, parsed.name, base_name });
    }

    // Track child method names for override detection (used by both parent and mixin generation)
    var child_method_names = std.StringHashMap(void).init(allocator);
    defer child_method_names.deinit();
    for (parsed.methods) |method| {
        try child_method_names.put(method.name, {});
    }

    if (parsed.parent_name) |parent_ref| {
        if (parsed.methods.len > 0) try writer.writeAll("\n");

        var parent_field_names = std.StringHashMap(void).init(allocator);
        defer parent_field_names.deinit();

        const ParentMethod = struct {
            method: MethodDef,
            parent_type: []const u8,
        };

        var parent_methods: std.ArrayList(ParentMethod) = .empty;
        defer parent_methods.deinit(allocator);

        var current_parent: ?[]const u8 = parent_ref;
        var current_file_path = current_file;

        while (current_parent) |parent| {
            const parent_info = (try registry.resolveParentReference(parent, current_file_path)) orelse {
                break;
            };

            for (parent_info.fields) |field| {
                try parent_field_names.put(field.name, {});
            }

            for (parent_info.properties) |prop| {
                try parent_field_names.put(prop.name, {});
            }

            for (parent_info.methods) |method| {
                // Skip methods that child has already defined (override detection)
                if (child_method_names.contains(method.name)) continue;

                // Skip static methods EXCEPT init and deinit
                const is_init_or_deinit = std.mem.eql(u8, method.name, "init") or std.mem.eql(u8, method.name, "deinit");
                if (method.is_static and !is_init_or_deinit) continue;

                // Copy all methods including init and deinit
                try parent_methods.append(allocator, .{
                    .method = method,
                    .parent_type = parent_info.name,
                });
            }

            current_parent = parent_info.parent_name;
            current_file_path = parent_info.file_path;
        }

        // Check if parent has init and capture it
        var parent_init_method: ?MethodDef = null;
        var parent_init_type: ?[]const u8 = null;
        for (parent_methods.items) |parent_method| {
            if (std.mem.eql(u8, parent_method.method.name, "init")) {
                parent_init_method = parent_method.method;
                parent_init_type = parent_method.parent_type;
                break;
            }
        }

        // If parent has init and child has fields/properties, generate smart init
        const need_smart_init = parent_init_method != null and (parsed.fields.len > 0 or parsed.properties.len > 0);

        // First emit init/deinit from parent if not generating smart init
        for (parent_methods.items) |parent_method| {
            const method = parent_method.method;
            const parent_type = parent_method.parent_type;

            // Skip parent's init if we're generating a smart init
            if (need_smart_init and std.mem.eql(u8, method.name, "init")) {
                continue;
            }

            // Only emit init/deinit in this pass
            if (std.mem.eql(u8, method.name, "init") or std.mem.eql(u8, method.name, "deinit")) {
                // Emit doc comment if present
                if (method.doc_comment) |doc| {
                    var doc_lines = std.mem.splitScalar(u8, doc, '\n');
                    while (doc_lines.next()) |line| {
                        try writer.print("    /// {s}\n", .{line});
                    }
                }
                // Copy and rewrite parent method
                const rewritten_method = try rewriteMixinMethod(allocator, method.source, parent_type, parsed.name);
                defer allocator.free(rewritten_method);

                try writer.print("    {s}\n", .{rewritten_method});
            }
        }

        // Generate smart init if needed
        if (need_smart_init) {
            // Find the topmost ancestor with init
            var topmost_init: ?MethodDef = null;
            var topmost_init_type: ?[]const u8 = null;
            var curr_parent: ?[]const u8 = parent_ref;
            var curr_file = current_file;

            while (curr_parent) |parent| {
                const parent_info = (try registry.resolveParentReference(parent, curr_file)) orelse break;

                // Check if this parent has init
                for (parent_info.methods) |method| {
                    if (std.mem.eql(u8, method.name, "init")) {
                        topmost_init = method;
                        topmost_init_type = parent_info.name;
                    }
                }

                curr_parent = parent_info.parent_name;
                curr_file = parent_info.file_path;
            }

            // Collect fields that need to be in init params
            // These are fields from ancestors without init + current class fields
            var init_param_fields: std.ArrayList(FieldDef) = .empty;
            defer init_param_fields.deinit(allocator);
            var init_param_props: std.ArrayList(PropertyDef) = .empty;
            defer init_param_props.deinit(allocator);

            // Walk hierarchy and collect fields from classes that don't have init
            curr_parent = parent_ref;
            curr_file = current_file;
            while (curr_parent) |parent| {
                const parent_info = (try registry.resolveParentReference(parent, curr_file)) orelse break;

                // Check if this parent has its own init
                var has_own_init = false;
                for (parent_info.methods) |method| {
                    if (std.mem.eql(u8, method.name, "init")) {
                        has_own_init = true;
                        break;
                    }
                }

                // If no init, need params for these fields
                if (!has_own_init) {
                    for (parent_info.fields) |field| {
                        try init_param_fields.append(allocator, field);
                    }
                    for (parent_info.properties) |prop| {
                        try init_param_props.append(allocator, prop);
                    }
                } else {
                    // Found parent with init, stop here
                    break;
                }

                curr_parent = parent_info.parent_name;
                curr_file = parent_info.file_path;
            }

            // Reverse to get correct order (ancestors first)
            std.mem.reverse(FieldDef, init_param_fields.items);
            std.mem.reverse(PropertyDef, init_param_props.items);

            // Add current class fields to params
            for (parsed.fields) |field| {
                try init_param_fields.append(allocator, field);
            }
            for (parsed.properties) |prop| {
                try init_param_props.append(allocator, prop);
            }

            // For initialization body, we need ALL fields (parent + current)
            // Collect all parent fields again
            var all_init_fields: std.ArrayList(FieldDef) = .empty;
            defer all_init_fields.deinit(allocator);
            var all_init_props: std.ArrayList(PropertyDef) = .empty;
            defer all_init_props.deinit(allocator);

            // Walk up entire parent hierarchy to collect all fields
            curr_parent = parent_ref;
            curr_file = current_file;
            while (curr_parent) |parent| {
                const parent_info = (try registry.resolveParentReference(parent, curr_file)) orelse break;

                for (parent_info.fields) |field| {
                    try all_init_fields.append(allocator, field);
                }
                for (parent_info.properties) |prop| {
                    try all_init_props.append(allocator, prop);
                }

                curr_parent = parent_info.parent_name;
                curr_file = parent_info.file_path;
            }

            // Reverse to get correct order (grandparent first)
            std.mem.reverse(FieldDef, all_init_fields.items);
            std.mem.reverse(PropertyDef, all_init_props.items);

            // Add current class fields
            for (parsed.fields) |field| {
                try all_init_fields.append(allocator, field);
            }
            for (parsed.properties) |prop| {
                try all_init_props.append(allocator, prop);
            }

            const smart_init = try generateSmartInit(
                allocator,
                parsed.name,
                topmost_init.?.source,
                topmost_init_type.?,
                init_param_fields.items,
                init_param_props.items,
                all_init_fields.items,
                all_init_props.items,
            );
            defer allocator.free(smart_init);
            try writer.print("    {s}\n", .{smart_init});
        }
    }

    // Generate default init if no init exists and class has fields
    {
        const has_init = blk: {
            for (parsed.methods) |method| {
                if (std.mem.eql(u8, method.name, "init")) break :blk true;
            }
            break :blk false;
        };

        const has_parent_init = parsed.parent_name != null and blk: {
            var curr_parent: ?[]const u8 = parsed.parent_name;
            var curr_file = current_file;
            while (curr_parent) |parent| {
                const parent_info = (try registry.resolveParentReference(parent, curr_file)) orelse break;
                for (parent_info.methods) |method| {
                    if (std.mem.eql(u8, method.name, "init")) break :blk true;
                }
                curr_parent = parent_info.parent_name;
                curr_file = parent_info.file_path;
            }
            break :blk false;
        };

        // Generate default init if no init exists (neither in this class nor inherited)
        // Skip generating init for mixins - they're meant to be included, not instantiated
        if (!has_init and !has_parent_init and parsed.class_kind != .mixin) {
            // Collect ALL fields (parent + own) for init parameters
            var all_fields_for_init: std.ArrayList(FieldDef) = .empty;
            defer all_fields_for_init.deinit(allocator);
            var all_props_for_init: std.ArrayList(PropertyDef) = .empty;
            defer all_props_for_init.deinit(allocator);

            // Collect parent fields
            if (parsed.parent_name) |parent_ref| {
                var curr_parent: ?[]const u8 = parent_ref;
                var curr_file = current_file;
                while (curr_parent) |parent| {
                    const parent_info = (try registry.resolveParentReference(parent, curr_file)) orelse break;
                    for (parent_info.fields) |field| {
                        try all_fields_for_init.append(allocator, field);
                    }
                    for (parent_info.properties) |prop| {
                        try all_props_for_init.append(allocator, prop);
                    }
                    curr_parent = parent_info.parent_name;
                    curr_file = parent_info.file_path;
                }
                // Reverse to get correct order (grandparent first)
                std.mem.reverse(FieldDef, all_fields_for_init.items);
                std.mem.reverse(PropertyDef, all_props_for_init.items);
            }

            // Collect mixin fields
            for (parsed.mixin_names) |mixin_ref| {
                const mixin_info = (try registry.resolveParentReference(mixin_ref, current_file)) orelse continue;
                for (mixin_info.fields) |field| {
                    try all_fields_for_init.append(allocator, field);
                }
                for (mixin_info.properties) |prop| {
                    try all_props_for_init.append(allocator, prop);
                }
            }

            // Add own fields
            try all_fields_for_init.appendSlice(allocator, parsed.fields);
            try all_props_for_init.appendSlice(allocator, parsed.properties);

            // Check if we actually need init - only if there are fields or writable properties
            // Read-only properties alone don't need initialization
            const has_writable_props = blk: {
                for (all_props_for_init.items) |prop| {
                    if (prop.access == .read_write) break :blk true;
                }
                break :blk false;
            };

            const needs_init = all_fields_for_init.items.len > 0 or has_writable_props;

            // Only generate init if needed
            if (needs_init) {
                if (parsed.methods.len > 0) try writer.writeAll("\n");

                // Generate init that calls initFields
                try writer.writeAll("    pub fn init(allocator: std.mem.Allocator");

                // Add parameters for all fields
                for (all_fields_for_init.items) |field| {
                    try writer.print(", {s}: {s}", .{ field.name, field.type_name });
                }
                for (all_props_for_init.items) |prop| {
                    try writer.print(", {s}: {s}", .{ prop.name, prop.type_name });
                }

                try writer.print(") !{s} {{\n", .{parsed.name});
                try writer.print("        return try {s}.initFields(allocator, &.{{\n", .{parsed.name});

                // Pass all parameters to initFields
                var first = true;
                for (all_fields_for_init.items) |field| {
                    if (!first) try writer.writeAll(",\n");
                    try writer.print("            .{s} = {s}", .{ field.name, field.name });
                    first = false;
                }
                for (all_props_for_init.items) |prop| {
                    if (!first) try writer.writeAll(",\n");
                    try writer.print("            .{s} = {s}", .{ prop.name, prop.name });
                    first = false;
                }

                // Only add trailing comma if there are fields
                if (!first) {
                    try writer.writeAll(",\n        });\n");
                } else {
                    try writer.writeAll("\n        });\n");
                }
                try writer.writeAll("    }\n");

                // Generate initFields helper
                try writer.writeAll("    fn initFields(allocator: std.mem.Allocator, fields: *const struct {");

                // Add all fields to struct type
                for (all_fields_for_init.items) |field| {
                    try writer.print(" {s}: {s},", .{ field.name, field.type_name });
                }
                for (all_props_for_init.items) |prop| {
                    try writer.print(" {s}: {s},", .{ prop.name, prop.type_name });
                }

                try writer.print(" }}) !{s} {{\n", .{parsed.name});

                // Check if allocator is actually used
                var allocator_used = false;
                if (!has_allocator_field and needs_allocator) {
                    allocator_used = true; // Will be used for allocator field
                } else {
                    // Check if any field/property needs allocation
                    for (all_fields_for_init.items) |field| {
                        const needs_alloc = std.mem.eql(u8, field.type_name, "[]const u8") or
                            std.mem.eql(u8, field.type_name, "[]u8");
                        if (needs_alloc) {
                            allocator_used = true;
                            break;
                        }
                    }
                    if (!allocator_used) {
                        for (all_props_for_init.items) |prop| {
                            const is_string_type = std.mem.eql(u8, prop.type_name, "[]const u8") or
                                std.mem.eql(u8, prop.type_name, "[]u8");
                            const needs_alloc = is_string_type and prop.access == .read_write;
                            if (needs_alloc) {
                                allocator_used = true;
                                break;
                            }
                        }
                    }
                }

                // Suppress unused parameter warnings
                if (!allocator_used) {
                    try writer.writeAll("        _ = allocator;\n");
                }
                if (all_fields_for_init.items.len == 0 and all_props_for_init.items.len == 0) {
                    try writer.writeAll("        _ = fields;\n");
                }

                try writer.print("        return .{{\n", .{});

                // Only add allocator field if struct actually has one
                if (!has_allocator_field and needs_allocator) {
                    try writer.writeAll("            .allocator = allocator,\n");
                }

                // Initialize all fields (allocate strings only for non-borrowed data)
                for (all_fields_for_init.items) |field| {
                    // Fields always get allocated if they're string types (no read-only distinction for fields)
                    const needs_alloc = std.mem.eql(u8, field.type_name, "[]const u8") or
                        std.mem.eql(u8, field.type_name, "[]u8");
                    if (needs_alloc) {
                        try writer.print("            .{s} = try allocator.dupe(u8, fields.{s}),\n", .{ field.name, field.name });
                    } else {
                        try writer.print("            .{s} = fields.{s},\n", .{ field.name, field.name });
                    }
                }

                // Initialize properties (read-only properties are NOT allocated)
                for (all_props_for_init.items) |prop| {
                    // Read-only properties are borrowed, not owned - no allocation needed
                    const is_string_type = std.mem.eql(u8, prop.type_name, "[]const u8") or
                        std.mem.eql(u8, prop.type_name, "[]u8");
                    const needs_alloc = is_string_type and prop.access == .read_write;

                    if (needs_alloc) {
                        try writer.print("            .{s} = try allocator.dupe(u8, fields.{s}),\n", .{ prop.name, prop.name });
                    } else {
                        try writer.print("            .{s} = fields.{s},\n", .{ prop.name, prop.name });
                    }
                }

                try writer.writeAll("        };\n");
                try writer.writeAll("    }\n");
            } // end if (needs_init)
        }
    }

    // Generate deinit method to free dynamic fields (including inherited ones)
    // Track if deinit exists (user-written or generated)
    var has_deinit = false;
    for (parsed.methods) |method| {
        if (std.mem.eql(u8, method.name, "deinit")) {
            has_deinit = true;
            break;
        }
    }

    {
        // Collect all string fields that need freeing (from entire hierarchy)
        var string_fields: std.ArrayList([]const u8) = .empty;
        defer string_fields.deinit(allocator);

        // Collect parent string fields
        if (parsed.parent_name) |parent_ref| {
            var curr_parent: ?[]const u8 = parent_ref;
            var curr_file = current_file;

            // Walk up hierarchy to collect all string fields
            var all_parent_string_fields: std.ArrayList([]const u8) = .empty;
            defer all_parent_string_fields.deinit(allocator);

            while (curr_parent) |parent| {
                const parent_info = (try registry.resolveParentReference(parent, curr_file)) orelse break;

                for (parent_info.fields) |field| {
                    if (std.mem.eql(u8, field.type_name, "[]const u8") or std.mem.eql(u8, field.type_name, "[]u8")) {
                        try all_parent_string_fields.append(allocator, field.name);
                    }
                }
                for (parent_info.properties) |prop| {
                    // Only free read-write properties (read-only are borrowed, not owned)
                    const is_string_type = std.mem.eql(u8, prop.type_name, "[]const u8") or std.mem.eql(u8, prop.type_name, "[]u8");
                    if (is_string_type and prop.access == .read_write) {
                        try all_parent_string_fields.append(allocator, prop.name);
                    }
                }

                curr_parent = parent_info.parent_name;
                curr_file = parent_info.file_path;
            }

            // Reverse to get correct order
            std.mem.reverse([]const u8, all_parent_string_fields.items);
            try string_fields.appendSlice(allocator, all_parent_string_fields.items);
        }

        // Collect mixin string fields
        for (parsed.mixin_names) |mixin_ref| {
            const mixin_info = (try registry.resolveParentReference(mixin_ref, current_file)) orelse continue;
            for (mixin_info.fields) |field| {
                if (std.mem.eql(u8, field.type_name, "[]const u8") or std.mem.eql(u8, field.type_name, "[]u8")) {
                    try string_fields.append(allocator, field.name);
                }
            }
            for (mixin_info.properties) |prop| {
                // Only free read-write properties (read-only are borrowed, not owned)
                const is_string_type = std.mem.eql(u8, prop.type_name, "[]const u8") or std.mem.eql(u8, prop.type_name, "[]u8");
                if (is_string_type and prop.access == .read_write) {
                    try string_fields.append(allocator, prop.name);
                }
            }
        }

        // Add own string fields
        for (parsed.fields) |field| {
            if (std.mem.eql(u8, field.type_name, "[]const u8") or std.mem.eql(u8, field.type_name, "[]u8")) {
                try string_fields.append(allocator, field.name);
            }
        }
        for (parsed.properties) |prop| {
            // Only free read-write properties (read-only are borrowed, not owned)
            const is_string_type = std.mem.eql(u8, prop.type_name, "[]const u8") or std.mem.eql(u8, prop.type_name, "[]u8");
            if (is_string_type and prop.access == .read_write) {
                try string_fields.append(allocator, prop.name);
            }
        }

        if (string_fields.items.len > 0 and !has_deinit) {
            try writer.writeAll("    pub fn deinit(self: *");
            try writer.print("{s}) void {{\n", .{parsed.name});

            for (string_fields.items) |field_name| {
                try writer.print("        self.allocator.free(self.{s});\n", .{field_name});
            }

            try writer.writeAll("    }\n");
        }
    }

    // Generate mixin methods (flattened - copy method source directly into child)
    if (mixin_infos.items.len > 0) {
        if (parsed.methods.len > 0 or parsed.parent_name != null) try writer.writeAll("\n");

        for (mixin_infos.items) |mixin_info| {
            // Check if this mixin has any methods to generate
            var has_methods_to_generate = false;
            for (mixin_info.methods) |method| {
                if (child_method_names.contains(method.name)) continue;
                const is_init_or_deinit = std.mem.eql(u8, method.name, "init") or std.mem.eql(u8, method.name, "deinit");
                if (method.is_static and !is_init_or_deinit) continue;
                has_methods_to_generate = true;
                break;
            }

            if (has_methods_to_generate) {
                try writer.print("    // ========================================================================\n", .{});
                try writer.print("    // Methods from {s} mixin\n", .{mixin_info.name});
                try writer.print("    // ========================================================================\n", .{});
                try writer.writeAll("\n");
            }

            for (mixin_info.methods) |method| {
                // Skip if child already has this method (child overrides mixin)
                if (child_method_names.contains(method.name)) continue;

                // Skip static methods EXCEPT init and deinit
                const is_init_or_deinit = std.mem.eql(u8, method.name, "init") or std.mem.eql(u8, method.name, "deinit");
                if (method.is_static and !is_init_or_deinit) continue;

                // Emit doc comment if present
                if (method.doc_comment) |doc| {
                    var doc_lines = std.mem.splitScalar(u8, doc, '\n');
                    while (doc_lines.next()) |line| {
                        try writer.print("    /// {s}\n", .{line});
                    }
                }
                // Add annotation that this method is included from a mixin
                try writer.print("    /// (Included from {s} mixin)\n", .{mixin_info.name});

                // Copy all methods including init/deinit (with type rewriting)
                const rewritten_method = try rewriteMixinMethod(allocator, method.source, mixin_info.name, parsed.name);
                defer allocator.free(rewritten_method);

                try writer.print("    {s}\n", .{rewritten_method});
            }
        }
    }

    // Add section header for interface's own methods
    const has_own_methods = blk: {
        for (parsed.methods) |method| {
            if (!std.mem.eql(u8, method.name, "init") and !std.mem.eql(u8, method.name, "deinit")) {
                break :blk true;
            }
        }
        break :blk false;
    };

    if (has_own_methods) {
        try writer.print("    // ========================================================================\n", .{});
        try writer.print("    // {s} methods\n", .{parsed.name});
        try writer.print("    // ========================================================================\n", .{});
        try writer.writeAll("\n");
    }

    // Emit other user methods (excluding init/deinit which were emitted earlier)
    for (parsed.methods) |method| {
        if (!std.mem.eql(u8, method.name, "init") and !std.mem.eql(u8, method.name, "deinit")) {
            // Emit doc comment if present
            if (method.doc_comment) |doc| {
                var doc_lines = std.mem.splitScalar(u8, doc, '\n');
                while (doc_lines.next()) |line| {
                    try writer.print("    /// {s}\n", .{line});
                }
            }
            // Rename reserved parameters to avoid shadowing
            const renamed_source = try renameReservedParams(allocator, method.source);
            defer allocator.free(renamed_source);
            try writer.print("    {s}\n", .{renamed_source});
        }
    }

    // Emit other parent methods (excluding init/deinit which were emitted earlier)
    if (parsed.parent_name) |parent_ref| {
        var parent_field_names_for_other_methods = std.StringHashMap(void).init(allocator);
        defer parent_field_names_for_other_methods.deinit();

        const ParentMethodForOther = struct {
            method: MethodDef,
            parent_type: []const u8,
        };

        var parent_methods_for_other: std.ArrayList(ParentMethodForOther) = .empty;
        defer parent_methods_for_other.deinit(allocator);

        var curr_parent: ?[]const u8 = parent_ref;
        var curr_file = current_file;

        while (curr_parent) |parent| {
            const parent_info = (try registry.resolveParentReference(parent, curr_file)) orelse break;

            for (parent_info.methods) |method| {
                // Skip if child already has this method
                if (child_method_names.contains(method.name)) continue;

                // Skip static methods EXCEPT init and deinit (but we already emitted those)
                const is_init_or_deinit = std.mem.eql(u8, method.name, "init") or std.mem.eql(u8, method.name, "deinit");
                if (method.is_static and !is_init_or_deinit) continue;
                if (is_init_or_deinit) continue; // Already emitted

                try parent_methods_for_other.append(allocator, .{
                    .method = method,
                    .parent_type = parent_info.name,
                });
            }

            curr_parent = parent_info.parent_name;
            curr_file = parent_info.file_path;
        }

        // Emit other parent methods
        for (parent_methods_for_other.items) |parent_method| {
            const method = parent_method.method;
            const parent_type = parent_method.parent_type;

            // Emit doc comment if present
            if (method.doc_comment) |doc| {
                var doc_lines = std.mem.splitScalar(u8, doc, '\n');
                while (doc_lines.next()) |line| {
                    try writer.print("    /// {s}\n", .{line});
                }
            }
            const rewritten_method = try rewriteMixinMethod(allocator, method.source, parent_type, parsed.name);
            defer allocator.free(rewritten_method);

            try writer.print("    {s}\n", .{rewritten_method});
        }
    }

    if (parsed.properties.len > 0) {
        if (parsed.methods.len > 0 or parsed.parent_name != null) try writer.writeAll("\n");

        for (parsed.properties) |prop| {
            try writer.print("    pub inline fn {s}{s}(self: *const @This()) {s} {{\n", .{
                config.getter_prefix,
                prop.name,
                prop.type_name,
            });
            try writer.print("        return self.{s};\n", .{prop.name});
            try writer.writeAll("    }\n");

            if (prop.access == .read_write) {
                try writer.print("    pub inline fn {s}{s}(self: *@This(), value: {s}) void {{\n", .{
                    config.setter_prefix,
                    prop.name,
                    prop.type_name,
                });
                try writer.print("        self.{s} = value;\n", .{prop.name});
                try writer.writeAll("    }\n");
            }
        }
    }

    // ============================================================================
    // WebIDL Metadata
    // ============================================================================

    try writer.writeAll("\n    // WebIDL extended attributes metadata\n");
    try writer.writeAll("    pub const __webidl__ = .{\n");
    try writer.print("        .name = \"{s}\",\n", .{parsed.name});

    // Emit class kind
    const kind_str = switch (parsed.class_kind) {
        .interface => "interface",
        .namespace => "namespace",
        .mixin => "mixin",
    };
    try writer.print("        .kind = .{s},\n", .{kind_str});

    // Emit exposed scopes
    if (parsed.webidl_options.exposed) |exposed_scopes| {
        try writer.writeAll("        .exposed = &.{");
        for (exposed_scopes, 0..) |scope, i| {
            if (i > 0) try writer.writeAll(", ");
            const scope_str = switch (scope) {
                .global => ".global",
                .Window => ".Window",
                .Worker => ".Worker",
                .DedicatedWorker => ".DedicatedWorker",
                .SharedWorker => ".SharedWorker",
                .ServiceWorker => ".ServiceWorker",
            };
            try writer.writeAll(scope_str);
        }
        try writer.writeAll("},\n");
    } else {
        try writer.writeAll("        .exposed = null,\n");
    }

    // Emit boolean attributes
    try writer.print("        .transferable = {},\n", .{parsed.webidl_options.transferable});
    try writer.print("        .serializable = {},\n", .{parsed.webidl_options.serializable});
    try writer.print("        .secure_context = {},\n", .{parsed.webidl_options.secure_context});
    try writer.print("        .cross_origin_isolated = {},\n", .{parsed.webidl_options.cross_origin_isolated});

    try writer.writeAll("    };\n");

    try writer.writeAll("};\n");

    return try code.toOwnedSlice(allocator);
}
// ============================================================================
// DEAD CODE REMOVED (~220 lines)
// ============================================================================
// Removed unused comptime-reflection functions: generateClassCode,
// generateFields, generateParentMethods, generatePropertyMethods,
// generateChildMethods, isSpecialField, isSpecialDecl, sortFieldsByAlignment.
// These are replaced by generateEnhancedClassWithRegistry().
// See git history for removed implementation.
// ============================================================================

/// Rewrite a mixin method to replace the mixin type name with the child type name.
/// E.g., "self: *Timestamped" -> "self: *User"
/// Uses context-aware replacement to avoid changing string literals or comments.
fn rewriteMixinMethod(
    allocator: std.mem.Allocator,
    method_source: []const u8,
    mixin_type_name: []const u8,
    child_type_name: []const u8,
) ![]const u8 {
    // Validate type names to prevent injection
    if (!isValidTypeName(mixin_type_name)) return error.InvalidTypeName;
    if (!isValidTypeName(child_type_name)) return error.InvalidTypeName;

    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    var pos: usize = 0;
    var in_string: bool = false;
    var in_comment: bool = false;

    while (pos < method_source.len) {
        if (in_string) {
            if (method_source[pos] == '"' and (pos == 0 or method_source[pos - 1] != '\\')) {
                in_string = false;
            }
            try result.append(allocator, method_source[pos]);
            pos += 1;
            continue;
        }

        if (in_comment) {
            if (method_source[pos] == '\n') {
                in_comment = false;
            }
            try result.append(allocator, method_source[pos]);
            pos += 1;
            continue;
        }

        if (method_source[pos] == '"') {
            in_string = true;
            try result.append(allocator, method_source[pos]);
            pos += 1;
            continue;
        }

        if (pos + 1 < method_source.len and method_source[pos] == '/' and method_source[pos + 1] == '/') {
            in_comment = true;
            try result.append(allocator, method_source[pos]);
            pos += 1;
            continue;
        }

        if (std.mem.startsWith(u8, method_source[pos..], mixin_type_name)) {
            const before_ok = pos == 0 or !isIdentifierChar(method_source[pos - 1]);
            const after_pos = pos + mixin_type_name.len;
            const after_ok = after_pos >= method_source.len or !isIdentifierChar(method_source[after_pos]);

            if (before_ok and after_ok) {
                try result.appendSlice(allocator, child_type_name);
                pos += mixin_type_name.len;
                continue;
            }
        }

        try result.append(allocator, method_source[pos]);
        pos += 1;
    }

    return result.toOwnedSlice(allocator);
}

/// Rename reserved parameter names (init, deinit) to avoid shadowing conflicts
/// E.g., "fn foo(init: Bar)" -> "fn foo(init_: Bar)" and renames all usages in body
fn renameReservedParams(
    allocator: std.mem.Allocator,
    method_source: []const u8,
) ![]u8 {
    const reserved_params = [_][]const u8{ "init", "deinit" };

    var result: []u8 = try allocator.dupe(u8, method_source);

    for (reserved_params) |param_name| {
        const new_result = try renameParameter(allocator, result, param_name);
        allocator.free(result);
        result = new_result;
    }

    return result;
}

/// Rename a specific parameter throughout a method
fn renameParameter(
    allocator: std.mem.Allocator,
    method_source: []const u8,
    param_name: []const u8,
) ![]u8 {
    const new_name = try std.fmt.allocPrint(allocator, "{s}_", .{param_name});
    defer allocator.free(new_name);

    // Find parameter list
    const fn_pos = std.mem.indexOf(u8, method_source, "fn ") orelse return try allocator.dupe(u8, method_source);
    const paren_start = std.mem.indexOfPos(u8, method_source, fn_pos, "(") orelse return try allocator.dupe(u8, method_source);
    const paren_end = findMatchingParen(method_source, paren_start) orelse return try allocator.dupe(u8, method_source);

    const param_list = method_source[paren_start .. paren_end + 1];

    // Check if parameter exists in param list with proper boundaries
    const search_pattern = try std.fmt.allocPrint(allocator, "{s}:", .{param_name});
    defer allocator.free(search_pattern);

    var param_found = false;
    var search_pos: usize = 0;
    while (std.mem.indexOfPos(u8, param_list, search_pos, search_pattern)) |found_pos| {
        // Check if it's a full identifier match
        const before_ok = found_pos == 0 or !isIdentifierChar(param_list[found_pos - 1]);
        if (before_ok) {
            param_found = true;
            break;
        }
        search_pos = found_pos + 1;
    }

    if (!param_found) {
        return try allocator.dupe(u8, method_source);
    }

    // Replace all occurrences of the parameter name throughout the method
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    var pos: usize = 0;
    var in_string = false;
    var in_comment = false;

    while (pos < method_source.len) {
        // Handle string literals
        if (in_string) {
            if (method_source[pos] == '"' and (pos == 0 or method_source[pos - 1] != '\\')) {
                in_string = false;
            }
            try result.append(allocator, method_source[pos]);
            pos += 1;
            continue;
        }

        // Handle comments
        if (in_comment) {
            if (method_source[pos] == '\n') {
                in_comment = false;
            }
            try result.append(allocator, method_source[pos]);
            pos += 1;
            continue;
        }

        if (method_source[pos] == '"') {
            in_string = true;
            try result.append(allocator, method_source[pos]);
            pos += 1;
            continue;
        }

        if (pos + 1 < method_source.len and method_source[pos] == '/' and method_source[pos + 1] == '/') {
            in_comment = true;
            try result.append(allocator, method_source[pos]);
            pos += 1;
            continue;
        }

        // Check for parameter name with proper word boundaries
        if (std.mem.startsWith(u8, method_source[pos..], param_name)) {
            const before_ok = pos == 0 or !isIdentifierChar(method_source[pos - 1]);
            const after_pos = pos + param_name.len;
            const after_ok = after_pos >= method_source.len or !isIdentifierChar(method_source[after_pos]);

            if (before_ok and after_ok) {
                try result.appendSlice(allocator, new_name);
                pos += param_name.len;
                continue;
            }
        }

        try result.append(allocator, method_source[pos]);
        pos += 1;
    }

    return result.toOwnedSlice(allocator);
}

fn isIdentifierChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

fn isSpecialField(name: []const u8) bool {
    return std.mem.eql(u8, name, "extends") or
        std.mem.eql(u8, name, "mixins") or
        std.mem.eql(u8, name, "properties");
}

fn isSpecialDecl(name: []const u8) bool {
    return std.mem.eql(u8, name, "extends") or
        std.mem.eql(u8, name, "mixins") or
        std.mem.eql(u8, name, "properties");
}

fn sortFieldsByAlignment(fields: []const std.builtin.Type.StructField) ![]std.builtin.Type.StructField {
    const sorted = try std.heap.page_allocator.dupe(std.builtin.Type.StructField, fields);

    // Sort by alignment descending, then by size descending
    std.mem.sort(std.builtin.Type.StructField, sorted, {}, struct {
        fn lessThan(_: void, a: std.builtin.Type.StructField, b: std.builtin.Type.StructField) bool {
            const a_align = a.alignment;
            const b_align = b.alignment;

            if (a_align != b_align) {
                return a_align > b_align;
            }

            // Same alignment, sort by size (can't get size from StructField directly)
            return false;
        }
    }.lessThan);

    return sorted;
}
