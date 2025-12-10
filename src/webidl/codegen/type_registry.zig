//! Type Registry for WebIDL Code Generation
//!
//! This module provides a comprehensive type registry that tracks all types
//! defined across all WebIDL files. It enables proper resolution of cross-file
//! references during code generation.
//!
//! ## Features
//!
//! - Registers all WebIDL type kinds (interfaces, dictionaries, typedefs, enums, callbacks, namespaces)
//! - Tracks source file for each type
//! - Resolves type references to their proper module
//! - Handles union type resolution
//! - Detects circular dependencies
//! - Supports forward declaration generation
//!
//! ## Usage
//!
//! ```zig
//! var registry = TypeRegistry.init(allocator);
//! defer registry.deinit();
//!
//! // Register types from parsed IDL files
//! try registry.registerInterface("Blob", "FileAPI.idl", null);
//! try registry.registerTypedef("BufferSource", "streams.idl");
//!
//! // Resolve a type reference
//! if (registry.resolve("Blob")) |info| {
//!     // info.kind == .interface
//!     // info.source_file == "FileAPI.idl"
//! }
//!
//! // Resolve union types
//! const union_members = &[_][]const u8{ "Blob", "BufferSource", "DOMString" };
//! const union_info = try registry.resolveUnion(union_members);
//! ```

const std = @import("std");
const types = @import("types.zig");

/// Kind of WebIDL type
pub const TypeKind = enum {
    interface,
    callback_interface,
    typedef,
    dictionary,
    enum_type,
    callback,
    namespace,
    mixin,
    primitive,
};

/// Detailed information about a registered type
pub const TypeInfo = struct {
    /// The kind of WebIDL construct
    kind: TypeKind,

    /// Source file where the type is defined (primary definition)
    source_file: []const u8,

    /// For interfaces: parent interface name (if any)
    inheritance: ?[]const u8 = null,

    /// For interfaces: list of mixin names included
    mixins: []const []const u8 = &.{},

    /// Whether this type is a callback interface (can be used as callback)
    is_callback: bool = false,

    /// For typedefs: the underlying type definition
    underlying_type: ?types.IDLType = null,

    /// For dictionaries: the parent dictionary name (if any)
    dict_inheritance: ?[]const u8 = null,

    /// Module path to import this type from
    /// e.g., "interfaces", "typedefs", "dictionaries"
    module: []const u8 = "interfaces",
};

/// Information about a resolved union type
pub const UnionInfo = struct {
    /// All member types in the union
    member_types: []const UnionMember,

    /// Whether the union contains any primitive types
    has_primitives: bool,

    /// Whether the union contains any interface types
    has_interfaces: bool,

    /// Whether the union contains any string types (DOMString, USVString, etc.)
    has_strings: bool,

    /// Whether the union contains any dictionary types
    has_dictionaries: bool,

    /// Whether all types in the union are known/registered
    all_types_known: bool,
};

/// Information about a single union member
pub const UnionMember = struct {
    /// The type name
    name: []const u8,

    /// Kind of this member (if known)
    kind: ?TypeKind,

    /// Module to import from (if known)
    module: ?[]const u8,

    /// Whether this is a nullable member
    nullable: bool,
};

/// Registry of all defined types across all WebIDL files
pub const TypeRegistry = struct {
    /// Map from type name to type info
    types: std.StringHashMap(TypeInfo),

    /// Map from type name to list of source files that define/extend it
    source_files: std.StringHashMap(std.ArrayList([]const u8)),

    /// Set of primitive type names for quick lookup
    primitives: std.StringHashMap(void),

    /// Allocator for internal allocations
    allocator: std.mem.Allocator,

    /// Initialize a new type registry
    pub fn init(allocator: std.mem.Allocator) TypeRegistry {
        var reg = TypeRegistry{
            .types = std.StringHashMap(TypeInfo).init(allocator),
            .source_files = std.StringHashMap(std.ArrayList([]const u8)).init(allocator),
            .primitives = std.StringHashMap(void).init(allocator),
            .allocator = allocator,
        };

        // Register primitives synchronously (can't fail with these known strings)
        reg.registerPrimitivesSync();

        return reg;
    }

    /// Deinitialize and free all resources
    pub fn deinit(self: *TypeRegistry) void {
        // Free type info values (they reference allocated strings)
        var type_iter = self.types.iterator();
        while (type_iter.next()) |entry| {
            // Keys are owned elsewhere (source_files or original IDL data)
            // Just clear the hashmap
            _ = entry;
        }
        self.types.deinit();

        // Free source file lists
        var source_iter = self.source_files.iterator();
        while (source_iter.next()) |entry| {
            for (entry.value_ptr.items) |source| {
                self.allocator.free(source);
            }
            entry.value_ptr.deinit(self.allocator);
            self.allocator.free(entry.key_ptr.*);
        }
        self.source_files.deinit();

        self.primitives.deinit();
    }

    /// Register WebIDL primitive types synchronously (no allocation, can't fail)
    fn registerPrimitivesSync(self: *TypeRegistry) void {
        const primitive_names = [_][]const u8{
            "void",
            "undefined",
            "boolean",
            "byte",
            "octet",
            "short",
            "unsigned short",
            "long",
            "unsigned long",
            "long long",
            "unsigned long long",
            "float",
            "unrestricted float",
            "double",
            "unrestricted double",
            "DOMString",
            "ByteString",
            "USVString",
            "object",
            "symbol",
            "any",
            // JavaScript built-in types (not IDL primitives but handled specially)
            "ArrayBuffer",
            "SharedArrayBuffer",
            "DataView",
            "Int8Array",
            "Int16Array",
            "Int32Array",
            "Uint8Array",
            "Uint8ClampedArray",
            "Uint16Array",
            "Uint32Array",
            "Float32Array",
            "Float64Array",
            "BigInt64Array",
            "BigUint64Array",
        };

        for (primitive_names) |name| {
            self.primitives.put(name, {}) catch {};
        }
    }

    /// Register all WebIDL primitive types (async version with allocation)
    pub fn registerPrimitives(self: *TypeRegistry) !void {
        const primitive_names = [_][]const u8{
            "void",
            "undefined",
            "boolean",
            "byte",
            "octet",
            "short",
            "unsigned short",
            "long",
            "unsigned long",
            "long long",
            "unsigned long long",
            "float",
            "unrestricted float",
            "double",
            "unrestricted double",
            "DOMString",
            "ByteString",
            "USVString",
            "object",
            "symbol",
            "any",
        };

        for (primitive_names) |name| {
            try self.register(name, .primitive);
        }
    }

    /// Register a type with just kind (backward compatible)
    pub fn register(self: *TypeRegistry, name: []const u8, kind: TypeKind) !void {
        try self.types.put(name, TypeInfo{
            .kind = kind,
            .source_file = "",
            .module = kindToModule(kind),
        });
    }

    /// Register an interface type with full details
    pub fn registerInterface(
        self: *TypeRegistry,
        name: []const u8,
        source_file: []const u8,
        inheritance: ?[]const u8,
    ) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        const source_copy = try self.allocator.dupe(u8, source_file);
        errdefer self.allocator.free(source_copy);

        try self.types.put(name_copy, TypeInfo{
            .kind = .interface,
            .source_file = source_copy,
            .inheritance = if (inheritance) |inh| try self.allocator.dupe(u8, inh) else null,
            .module = "interfaces",
        });

        try self.trackSourceFile(name_copy, source_copy);
    }

    /// Register a callback interface type
    pub fn registerCallbackInterface(
        self: *TypeRegistry,
        name: []const u8,
        source_file: []const u8,
    ) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        const source_copy = try self.allocator.dupe(u8, source_file);
        errdefer self.allocator.free(source_copy);

        try self.types.put(name_copy, TypeInfo{
            .kind = .callback_interface,
            .source_file = source_copy,
            .is_callback = true,
            .module = "interfaces",
        });

        try self.trackSourceFile(name_copy, source_copy);
    }

    /// Register a typedef with its underlying type
    pub fn registerTypedef(
        self: *TypeRegistry,
        name: []const u8,
        source_file: []const u8,
        underlying_type: ?types.IDLType,
    ) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        const source_copy = try self.allocator.dupe(u8, source_file);
        errdefer self.allocator.free(source_copy);

        try self.types.put(name_copy, TypeInfo{
            .kind = .typedef,
            .source_file = source_copy,
            .underlying_type = underlying_type,
            .module = "typedefs",
        });

        try self.trackSourceFile(name_copy, source_copy);
    }

    /// Register a dictionary type
    pub fn registerDictionary(
        self: *TypeRegistry,
        name: []const u8,
        source_file: []const u8,
        inheritance: ?[]const u8,
    ) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        const source_copy = try self.allocator.dupe(u8, source_file);
        errdefer self.allocator.free(source_copy);

        try self.types.put(name_copy, TypeInfo{
            .kind = .dictionary,
            .source_file = source_copy,
            .dict_inheritance = if (inheritance) |inh| try self.allocator.dupe(u8, inh) else null,
            .module = "dictionaries",
        });

        try self.trackSourceFile(name_copy, source_copy);
    }

    /// Register an enum type
    pub fn registerEnum(
        self: *TypeRegistry,
        name: []const u8,
        source_file: []const u8,
    ) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        const source_copy = try self.allocator.dupe(u8, source_file);
        errdefer self.allocator.free(source_copy);

        try self.types.put(name_copy, TypeInfo{
            .kind = .enum_type,
            .source_file = source_copy,
            .module = "enums",
        });

        try self.trackSourceFile(name_copy, source_copy);
    }

    /// Register a callback function type
    pub fn registerCallback(
        self: *TypeRegistry,
        name: []const u8,
        source_file: []const u8,
    ) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        const source_copy = try self.allocator.dupe(u8, source_file);
        errdefer self.allocator.free(source_copy);

        try self.types.put(name_copy, TypeInfo{
            .kind = .callback,
            .source_file = source_copy,
            .module = "callbacks",
        });

        try self.trackSourceFile(name_copy, source_copy);
    }

    /// Register a namespace type
    pub fn registerNamespace(
        self: *TypeRegistry,
        name: []const u8,
        source_file: []const u8,
    ) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        const source_copy = try self.allocator.dupe(u8, source_file);
        errdefer self.allocator.free(source_copy);

        try self.types.put(name_copy, TypeInfo{
            .kind = .namespace,
            .source_file = source_copy,
            .module = "namespaces",
        });

        try self.trackSourceFile(name_copy, source_copy);
    }

    /// Register a mixin type
    pub fn registerMixin(
        self: *TypeRegistry,
        name: []const u8,
        source_file: []const u8,
    ) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        const source_copy = try self.allocator.dupe(u8, source_file);
        errdefer self.allocator.free(source_copy);

        try self.types.put(name_copy, TypeInfo{
            .kind = .mixin,
            .source_file = source_copy,
            .module = "mixins",
        });

        try self.trackSourceFile(name_copy, source_copy);
    }

    /// Track that a type is defined/extended in a source file
    fn trackSourceFile(self: *TypeRegistry, name: []const u8, source: []const u8) !void {
        const gop = try self.source_files.getOrPut(name);
        if (!gop.found_existing) {
            gop.value_ptr.* = std.ArrayList([]const u8).empty;
        }
        try gop.value_ptr.append(self.allocator, source);
    }

    /// Look up a type in the registry (backward compatible)
    pub fn lookup(self: *const TypeRegistry, name: []const u8) ?TypeKind {
        if (self.types.get(name)) |info| {
            return info.kind;
        }
        return null;
    }

    /// Check if a type is registered
    pub fn contains(self: *const TypeRegistry, name: []const u8) bool {
        return self.types.contains(name);
    }

    /// Resolve a type reference to full type information
    pub fn resolve(self: *const TypeRegistry, type_name: []const u8) ?TypeInfo {
        // First check if it's a registered type
        if (self.types.get(type_name)) |info| {
            return info;
        }

        // Check if it's a primitive
        if (self.primitives.contains(type_name)) {
            return TypeInfo{
                .kind = .primitive,
                .source_file = "",
                .module = "runtime", // Primitives come from runtime module
            };
        }

        return null;
    }

    /// Check if a type is a primitive
    pub fn isPrimitive(self: *const TypeRegistry, type_name: []const u8) bool {
        return self.primitives.contains(type_name);
    }

    /// Check if a type is a string type (DOMString, USVString, ByteString)
    pub fn isStringType(self: *const TypeRegistry, type_name: []const u8) bool {
        _ = self;
        return std.mem.eql(u8, type_name, "DOMString") or
            std.mem.eql(u8, type_name, "USVString") or
            std.mem.eql(u8, type_name, "ByteString");
    }

    /// Resolve a union type to information about its members
    pub fn resolveUnion(self: *const TypeRegistry, union_types: []const []const u8) UnionInfo {
        var members = std.ArrayList(UnionMember).init(self.allocator);

        var has_primitives = false;
        var has_interfaces = false;
        var has_strings = false;
        var has_dictionaries = false;
        var all_known = true;

        for (union_types) |type_name| {
            var member = UnionMember{
                .name = type_name,
                .kind = null,
                .module = null,
                .nullable = false,
            };

            // Check for nullable marker
            var clean_name = type_name;
            if (std.mem.endsWith(u8, type_name, "?")) {
                clean_name = type_name[0 .. type_name.len - 1];
                member.nullable = true;
            }

            // Resolve the type
            if (self.resolve(clean_name)) |info| {
                member.kind = info.kind;
                member.module = info.module;

                switch (info.kind) {
                    .primitive => has_primitives = true,
                    .interface, .callback_interface => has_interfaces = true,
                    .dictionary => has_dictionaries = true,
                    else => {},
                }

                if (self.isStringType(clean_name)) {
                    has_strings = true;
                }
            } else {
                all_known = false;
            }

            members.append(self.allocator, member) catch {};
        }

        return UnionInfo{
            .member_types = members.toOwnedSlice(self.allocator) catch &.{},
            .has_primitives = has_primitives,
            .has_interfaces = has_interfaces,
            .has_strings = has_strings,
            .has_dictionaries = has_dictionaries,
            .all_types_known = all_known,
        };
    }

    /// Resolve a union type from IDLType union members
    pub fn resolveUnionFromIDLTypes(self: *const TypeRegistry, union_types: []const types.IDLType) UnionInfo {
        var type_names = std.ArrayList([]const u8).init(self.allocator);
        defer type_names.deinit(self.allocator);

        for (union_types) |ut| {
            type_names.append(self.allocator, ut.type) catch {};
        }

        return self.resolveUnion(type_names.items);
    }

    /// Get the module name to import a type from
    pub fn getModule(self: *const TypeRegistry, type_name: []const u8) []const u8 {
        if (self.resolve(type_name)) |info| {
            return info.module;
        }
        return "interfaces"; // Default fallback
    }

    /// Get all source files that define or extend a type
    pub fn getSourceFiles(self: *const TypeRegistry, type_name: []const u8) ?[]const []const u8 {
        if (self.source_files.get(type_name)) |list| {
            return list.items;
        }
        return null;
    }

    /// Check if two types have a circular dependency
    pub fn hasCircularDependency(
        self: *const TypeRegistry,
        type_a: []const u8,
        type_b: []const u8,
    ) bool {
        // Check if type_a's inheritance chain includes type_b
        var current = type_a;
        var depth: usize = 0;
        const max_depth = 100; // Prevent infinite loops

        while (depth < max_depth) {
            if (std.mem.eql(u8, current, type_b)) {
                return true;
            }

            if (self.types.get(current)) |info| {
                if (info.inheritance) |parent| {
                    current = parent;
                    depth += 1;
                } else {
                    break;
                }
            } else {
                break;
            }
        }

        // Check if type_b's inheritance chain includes type_a
        current = type_b;
        depth = 0;

        while (depth < max_depth) {
            if (std.mem.eql(u8, current, type_a)) {
                return true;
            }

            if (self.types.get(current)) |info| {
                if (info.inheritance) |parent| {
                    current = parent;
                    depth += 1;
                } else {
                    break;
                }
            } else {
                break;
            }
        }

        return false;
    }

    /// Get statistics about registered types
    pub fn getStats(self: *const TypeRegistry) TypeRegistryStats {
        var stats = TypeRegistryStats{};

        var iter = self.types.iterator();
        while (iter.next()) |entry| {
            switch (entry.value_ptr.kind) {
                .interface => stats.interfaces += 1,
                .callback_interface => stats.callback_interfaces += 1,
                .typedef => stats.typedefs += 1,
                .dictionary => stats.dictionaries += 1,
                .enum_type => stats.enums += 1,
                .callback => stats.callbacks += 1,
                .namespace => stats.namespaces += 1,
                .mixin => stats.mixins += 1,
                .primitive => stats.primitives += 1,
            }
            stats.total += 1;
        }

        return stats;
    }

    /// Convert TypeKind to module name
    fn kindToModule(kind: TypeKind) []const u8 {
        return switch (kind) {
            .interface, .callback_interface => "interfaces",
            .typedef => "typedefs",
            .dictionary => "dictionaries",
            .enum_type => "enums",
            .callback => "callbacks",
            .namespace => "namespaces",
            .mixin => "mixins",
            .primitive => "runtime",
        };
    }
};

/// Statistics about registered types
pub const TypeRegistryStats = struct {
    total: usize = 0,
    interfaces: usize = 0,
    callback_interfaces: usize = 0,
    typedefs: usize = 0,
    dictionaries: usize = 0,
    enums: usize = 0,
    callbacks: usize = 0,
    namespaces: usize = 0,
    mixins: usize = 0,
    primitives: usize = 0,
};

// Unit tests
const testing = std.testing;

test "TypeRegistry - basic registration and lookup" {
    const allocator = testing.allocator;
    var reg = TypeRegistry.init(allocator);
    defer reg.deinit();

    try reg.register("Blob", .interface);
    try reg.register("BlobPropertyBag", .dictionary);
    try reg.register("EndingType", .enum_type);

    try testing.expect(reg.lookup("Blob") == .interface);
    try testing.expect(reg.lookup("BlobPropertyBag") == .dictionary);
    try testing.expect(reg.lookup("EndingType") == .enum_type);
    try testing.expect(reg.lookup("Unknown") == null);
}

test "TypeRegistry - primitives are registered" {
    const allocator = testing.allocator;
    var reg = TypeRegistry.init(allocator);
    defer reg.deinit();

    try testing.expect(reg.isPrimitive("boolean"));
    try testing.expect(reg.isPrimitive("DOMString"));
    try testing.expect(reg.isPrimitive("unsigned long"));
    try testing.expect(!reg.isPrimitive("Blob"));
}

test "TypeRegistry - resolve returns full info" {
    const allocator = testing.allocator;
    var reg = TypeRegistry.init(allocator);
    defer reg.deinit();

    try reg.register("Request", .interface);

    if (reg.resolve("Request")) |info| {
        try testing.expect(info.kind == .interface);
        try testing.expectEqualStrings("interfaces", info.module);
    } else {
        try testing.expect(false);
    }
}

test "TypeRegistry - contains check" {
    const allocator = testing.allocator;
    var reg = TypeRegistry.init(allocator);
    defer reg.deinit();

    try reg.register("Event", .interface);

    try testing.expect(reg.contains("Event"));
    try testing.expect(!reg.contains("Unknown"));
}

test "TypeRegistry - string type detection" {
    const allocator = testing.allocator;
    var reg = TypeRegistry.init(allocator);
    defer reg.deinit();

    try testing.expect(reg.isStringType("DOMString"));
    try testing.expect(reg.isStringType("USVString"));
    try testing.expect(reg.isStringType("ByteString"));
    try testing.expect(!reg.isStringType("boolean"));
    try testing.expect(!reg.isStringType("long"));
}

test "TypeRegistry - getModule" {
    const allocator = testing.allocator;
    var reg = TypeRegistry.init(allocator);
    defer reg.deinit();

    try reg.register("Blob", .interface);
    try reg.register("BlobPropertyBag", .dictionary);
    try reg.register("EndingType", .enum_type);
    try reg.register("VoidFunction", .callback);

    try testing.expectEqualStrings("interfaces", reg.getModule("Blob"));
    try testing.expectEqualStrings("dictionaries", reg.getModule("BlobPropertyBag"));
    try testing.expectEqualStrings("enums", reg.getModule("EndingType"));
    try testing.expectEqualStrings("callbacks", reg.getModule("VoidFunction"));
}

test "TypeRegistry - getStats" {
    const allocator = testing.allocator;
    var reg = TypeRegistry.init(allocator);
    defer reg.deinit();

    try reg.register("Blob", .interface);
    try reg.register("File", .interface);
    try reg.register("BlobPropertyBag", .dictionary);
    try reg.register("EndingType", .enum_type);

    const stats = reg.getStats();
    try testing.expectEqual(@as(usize, 2), stats.interfaces);
    try testing.expectEqual(@as(usize, 1), stats.dictionaries);
    try testing.expectEqual(@as(usize, 1), stats.enums);
}
