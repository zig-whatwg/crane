//! Intermediate Representation (IR) for WebIDL
//!
//! This module provides an IR that represents the complete WebIDL specification
//! after parsing all files and merging partial interfaces.

const std = @import("std");
const log = std.log.scoped(.ir);
const types = @import("types.zig");
const duplicates = @import("duplicates.zig");
const type_registry_mod = @import("type_registry.zig");

// Re-export TypeRegistry and TypeKind from type_registry module for backward compatibility
pub const TypeRegistry = type_registry_mod.TypeRegistry;
pub const TypeKind = type_registry_mod.TypeKind;
pub const TypeInfo = type_registry_mod.TypeInfo;
pub const UnionInfo = type_registry_mod.UnionInfo;
pub const UnionMember = type_registry_mod.UnionMember;
pub const TypeRegistryStats = type_registry_mod.TypeRegistryStats;

/// One definition, or partial definition, of a name as it was added.
pub const Definition = union(enum) {
    interface: types.Interface,
    dictionary: types.Dictionary,
    typedef: types.Typedef,
    enum_type: types.Enum,
    callback: types.Callback,
    namespace: types.Namespace,

    pub fn isPartial(self: Definition) bool {
        return switch (self) {
            .interface => |d| d.partial,
            .dictionary => |d| d.partial,
            .namespace => |d| d.partial,
            .typedef, .enum_type, .callback => false,
        };
    }
};

/// A definition of a name and where it came from.
pub const Occurrence = struct {
    definition: Definition,
    /// The source file's name (owned by the name's source_map list).
    file: []const u8,
    /// Its position among the definitions added from that file.
    position: u32,
    /// Its index in the name's source_map list.
    source_index: usize,

    /// The stable key: (file name, position in the file).
    fn lessThan(_: void, a: Occurrence, b: Occurrence) bool {
        return switch (std.mem.order(u8, a.file, b.file)) {
            .lt => true,
            .gt => false,
            .eq => a.position < b.position,
        };
    }
};

/// Complete IR for all parsed WebIDL specifications
///
/// Merging. The IR does not depend on the order definitions are added in
/// (WebIDL: "the order of appearance of an interface definition and any of
/// its partial interface definitions does not matter"). Every add records an
/// Occurrence, and the name's merged definition is rebuilt from all of its
/// occurrences, sorted by (file name, position in the file):
///
/// 1. Every partial definition - interface, interface mixin, dictionary,
///    namespace - merges into its definition.
/// 2. Members: the definition's, in declaration order, then each partial's,
///    in declaration order, partials in the sorted order. A partial
///    dictionary member replaces a same-named member (web-animations-2
///    restates web-animations' members with new types). Extended
///    attributes: the definition's, then a partial's where the definition
///    has none of that name - so a partial's [Exposed] never widens the
///    interface's. (An includer's mixin members: see processIncludes.)
/// 3. Two or more non-partial definitions of a name resolve by
///    duplicates.zig, or fail with error.DuplicateDefinition - never by
///    order.
/// 4. So overloads, numbered by the generator in member order, are numbered
///    the same whatever order files were read in.
pub const IR = struct {
    /// All interfaces (merged from partials)
    interfaces: std.StringHashMap(Interface),

    /// All dictionaries
    dictionaries: std.StringHashMap(types.Dictionary),

    /// All typedefs
    typedefs: std.StringHashMap(types.Typedef),

    /// All enums
    enums: std.StringHashMap(types.Enum),

    /// All callbacks
    callbacks: std.StringHashMap(types.Callback),

    /// All namespaces
    namespaces: std.StringHashMap(types.Namespace),

    /// Type registry for resolving type references
    type_registry: TypeRegistry,

    /// Source file mapping (which spec defines/extends each name). The map
    /// owns the name keys every other map shares.
    source_map: std.StringHashMap(std.ArrayList([]const u8)),

    /// Every definition and partial definition of each name, as added.
    occurrences: std.StringHashMap(std.ArrayList(Occurrence)),

    /// How many definitions each source file has added (owns its keys).
    file_positions: std.StringHashMap(u32),

    /// Names whose duplicate definitions no rule resolves with the
    /// occurrences seen so far (the definer's file may come later); finish()
    /// resolves them or fails.
    unresolved: std.StringHashMap(void),

    /// Merged dictionary and namespace members and extended attributes.
    /// Rebuilt on every add; freed with the IR.
    merged: std.heap.ArenaAllocator,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !IR {
        var type_registry = TypeRegistry.init(allocator);
        // Register all WebIDL primitive types
        try type_registry.registerPrimitives();

        return .{
            .interfaces = std.StringHashMap(Interface).init(allocator),
            .dictionaries = std.StringHashMap(types.Dictionary).init(allocator),
            .typedefs = std.StringHashMap(types.Typedef).init(allocator),
            .enums = std.StringHashMap(types.Enum).init(allocator),
            .callbacks = std.StringHashMap(types.Callback).init(allocator),
            .namespaces = std.StringHashMap(types.Namespace).init(allocator),
            .type_registry = type_registry,
            .source_map = std.StringHashMap(std.ArrayList([]const u8)).init(allocator),
            .occurrences = std.StringHashMap(std.ArrayList(Occurrence)).init(allocator),
            .file_positions = std.StringHashMap(u32).init(allocator),
            .unresolved = std.StringHashMap(void).init(allocator),
            .merged = std.heap.ArenaAllocator.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *IR) void {
        // Free interfaces (keys are owned by source_map, so don't free them)
        var iface_iter = self.interfaces.iterator();
        while (iface_iter.next()) |entry| {
            var iface = entry.value_ptr;
            iface.deinit(self.allocator);
        }
        self.interfaces.deinit();

        // Keys are owned by source_map, so don't free them
        self.dictionaries.deinit();
        self.typedefs.deinit();
        self.enums.deinit();
        self.callbacks.deinit();
        self.namespaces.deinit();

        var occurrence_iter = self.occurrences.valueIterator();
        while (occurrence_iter.next()) |list| list.deinit(self.allocator);
        self.occurrences.deinit();

        var position_iter = self.file_positions.keyIterator();
        while (position_iter.next()) |key| self.allocator.free(key.*);
        self.file_positions.deinit();
        self.unresolved.deinit();

        self.merged.deinit();

        // Free type registry
        self.type_registry.deinit();

        // Free source map
        var source_iter = self.source_map.iterator();
        while (source_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            for (entry.value_ptr.items) |source| {
                self.allocator.free(source);
            }
            entry.value_ptr.deinit(self.allocator);
        }
        self.source_map.deinit();
    }

    /// Add an interface (or interface mixin, or callback interface), partial or not.
    pub fn addInterface(self: *IR, iface: types.Interface, source_file: []const u8) !void {
        return self.add(iface.name, .{ .interface = iface }, source_file);
    }

    /// Add a dictionary, partial or not.
    pub fn addDictionary(self: *IR, dict: types.Dictionary, source_file: []const u8) !void {
        return self.add(dict.name, .{ .dictionary = dict }, source_file);
    }

    pub fn addTypedef(self: *IR, typedef: types.Typedef, source_file: []const u8) !void {
        return self.add(typedef.name, .{ .typedef = typedef }, source_file);
    }

    pub fn addEnum(self: *IR, enum_type: types.Enum, source_file: []const u8) !void {
        return self.add(enum_type.name, .{ .enum_type = enum_type }, source_file);
    }

    pub fn addCallback(self: *IR, callback: types.Callback, source_file: []const u8) !void {
        return self.add(callback.name, .{ .callback = callback }, source_file);
    }

    /// Add a namespace, partial or not.
    pub fn addNamespace(self: *IR, namespace: types.Namespace, source_file: []const u8) !void {
        return self.add(namespace.name, .{ .namespace = namespace }, source_file);
    }

    /// Record one definition of `name` and rebuild the name's merged definition.
    fn add(self: *IR, name: []const u8, definition: Definition, source_file: []const u8) !void {
        // Get or create source_map entry first (this owns the name key)
        const source_gop = try self.source_map.getOrPut(name);
        if (!source_gop.found_existing) {
            source_gop.key_ptr.* = try self.allocator.dupe(u8, name);
            source_gop.value_ptr.* = std.ArrayList([]const u8).empty;
        }
        const key = source_gop.key_ptr.*;

        // Track source file - once appended, the list owns it
        const source_copy = try self.allocator.dupe(u8, source_file);
        const source_index = source_gop.value_ptr.items.len;
        source_gop.value_ptr.append(self.allocator, source_copy) catch |err| {
            self.allocator.free(source_copy);
            return err;
        };

        const position_gop = try self.file_positions.getOrPut(source_file);
        if (!position_gop.found_existing) {
            position_gop.key_ptr.* = try self.allocator.dupe(u8, source_file);
            position_gop.value_ptr.* = 0;
        }
        const position = position_gop.value_ptr.*;
        position_gop.value_ptr.* += 1;

        const occurrence_gop = try self.occurrences.getOrPut(key);
        if (!occurrence_gop.found_existing) occurrence_gop.value_ptr.* = .empty;
        try occurrence_gop.value_ptr.append(self.allocator, .{
            .definition = definition,
            .file = source_copy,
            .position = position,
            .source_index = source_index,
        });

        try self.rebuild(key, false);
    }

    /// After the last add: resolve every duplicate definition, or fail with
    /// error.DuplicateDefinition and a message for each one no rule covers.
    pub fn finish(self: *IR) !void {
        var keys = std.ArrayList([]const u8).empty;
        defer keys.deinit(self.allocator);
        var iter = self.unresolved.keyIterator();
        while (iter.next()) |key| try keys.append(self.allocator, key.*);
        std.mem.sort([]const u8, keys.items, {}, struct {
            fn lessThan(_: void, a: []const u8, b: []const u8) bool {
                return std.mem.lessThan(u8, a, b);
            }
        }.lessThan);

        var failed = false;
        for (keys.items) |key| {
            self.rebuild(key, true) catch |err| switch (err) {
                error.DuplicateDefinition => failed = true,
                else => return err,
            };
        }
        if (failed) return error.DuplicateDefinition;
    }

    /// Rebuild `key`'s merged definition from all of its occurrences (see
    /// "Merging" above).
    ///
    /// Until `strict` (finish()), a duplicate no rule resolves yet is
    /// provisionally its first definition and is remembered in `unresolved`.
    fn rebuild(self: *IR, key: []const u8, strict: bool) !void {
        const list = self.occurrences.getPtr(key).?;
        std.mem.sort(Occurrence, list.items, {}, Occurrence.lessThan);
        const occurrences = list.items;

        // The definition: the one non-partial occurrence, or the one
        // duplicates.zig names.
        var base: ?usize = null;
        var base_count: usize = 0;
        for (occurrences, 0..) |occurrence, i| {
            if (occurrence.definition.isPartial()) continue;
            base_count += 1;
            if (base == null) base = i;
        }
        if (base_count > 1) {
            var candidates = std.ArrayList(duplicates.Candidate).empty;
            defer candidates.deinit(self.allocator);
            var indexes = std.ArrayList(usize).empty;
            defer indexes.deinit(self.allocator);
            for (occurrences, 0..) |occurrence, i| {
                if (occurrence.definition.isPartial()) continue;
                try candidates.append(self.allocator, .{ .file = occurrence.file, .position = occurrence.position });
                try indexes.append(self.allocator, i);
            }
            if (duplicates.resolve(key, candidates.items, strict)) |chosen| {
                base = indexes.items[chosen];
                _ = self.unresolved.remove(key);
            } else |err| {
                if (strict) return err;
                return self.defer_(key);
            }
        } else {
            _ = self.unresolved.remove(key);
        }

        // What it is: the definition's kind, or with no definition yet, the
        // first partial's. Partials of another kind do not belong to it.
        const kind = std.meta.activeTag(occurrences[base orelse 0].definition);
        for (occurrences) |occurrence| {
            if (occurrence.definition.isPartial() and std.meta.activeTag(occurrence.definition) != kind) {
                if (!strict) return self.defer_(key);
                log.err("partial {s} {s} ({s}) is not a {s}", .{ @tagName(std.meta.activeTag(occurrence.definition)), key, occurrence.file, @tagName(kind) });
                return error.PartialOfAnotherKind;
            }
        }

        self.removeMerged(key);
        const arena = self.merged.allocator();

        switch (kind) {
            .interface => {
                const first = base orelse 0;
                var merged = try Interface.fromTypes(self.allocator, occurrences[first].definition.interface, key, occurrences[first].source_index);
                errdefer merged.deinit(self.allocator);
                for (occurrences, 0..) |occurrence, i| {
                    if (i == first or !occurrence.definition.isPartial()) continue;
                    try merged.mergePartial(self.allocator, occurrence.definition.interface);
                }
                const def = occurrences[first].definition.interface;
                const type_kind: TypeKind = if (def.callback) .callback_interface else if (def.mixin) .mixin else .interface;
                try self.interfaces.put(key, merged);
                try self.type_registry.register(key, type_kind);
            },
            .dictionary => {
                const first = base orelse 0;
                var merged = occurrences[first].definition.dictionary;
                var members = std.ArrayList(types.DictionaryMember).empty;
                try members.appendSlice(arena, merged.members);
                var ext_attrs = std.ArrayList(types.ExtendedAttribute).empty;
                try ext_attrs.appendSlice(arena, merged.extAttrs);
                for (occurrences, 0..) |occurrence, i| {
                    if (i == first or !occurrence.definition.isPartial()) continue;
                    const partial = occurrence.definition.dictionary;
                    // A partial member replaces a same-named member.
                    var kept: usize = 0;
                    for (members.items) |member| {
                        if (dictionaryMemberNamed(partial.members, member.name)) continue;
                        members.items[kept] = member;
                        kept += 1;
                    }
                    members.shrinkRetainingCapacity(kept);
                    try members.appendSlice(arena, partial.members);
                    try appendMissingExtAttrs(arena, &ext_attrs, partial.extAttrs);
                }
                merged.members = members.items;
                merged.extAttrs = ext_attrs.items;
                merged.partial = base == null;
                try self.dictionaries.put(key, merged);
                try self.type_registry.register(key, .dictionary);
            },
            .namespace => {
                const first = base orelse 0;
                var merged = occurrences[first].definition.namespace;
                var members = std.ArrayList(types.Member).empty;
                try members.appendSlice(arena, merged.members);
                var ext_attrs = std.ArrayList(types.ExtendedAttribute).empty;
                try ext_attrs.appendSlice(arena, merged.extAttrs);
                for (occurrences, 0..) |occurrence, i| {
                    if (i == first or !occurrence.definition.isPartial()) continue;
                    try members.appendSlice(arena, occurrence.definition.namespace.members);
                    try appendMissingExtAttrs(arena, &ext_attrs, occurrence.definition.namespace.extAttrs);
                }
                merged.members = members.items;
                merged.extAttrs = ext_attrs.items;
                merged.partial = base == null;
                try self.namespaces.put(key, merged);
                try self.type_registry.register(key, .namespace);
            },
            .typedef => {
                try self.typedefs.put(key, occurrences[base.?].definition.typedef);
                try self.type_registry.register(key, .typedef);
            },
            .enum_type => {
                try self.enums.put(key, occurrences[base.?].definition.enum_type);
                try self.type_registry.register(key, .enum_type);
            },
            .callback => {
                try self.callbacks.put(key, occurrences[base.?].definition.callback);
                try self.type_registry.register(key, .callback);
            },
        }
    }

    /// Leave `key` without a merged definition until a later add or
    /// finish() can resolve it.
    fn defer_(self: *IR, key: []const u8) !void {
        self.removeMerged(key);
        try self.unresolved.put(key, {});
    }

    /// Forget `key`'s merged definition, whatever kind it was.
    fn removeMerged(self: *IR, key: []const u8) void {
        if (self.interfaces.fetchRemove(key)) |entry| {
            var iface = entry.value;
            iface.deinit(self.allocator);
        }
        _ = self.dictionaries.remove(key);
        _ = self.typedefs.remove(key);
        _ = self.enums.remove(key);
        _ = self.callbacks.remove(key);
        _ = self.namespaces.remove(key);
    }

    /// Process includes statements to merge mixin members into target
    /// interfaces, in the order given (the pipeline orders them by file name,
    /// then position in the file). Call it after every definition is added:
    /// a later add rebuilds the name without its mixins.
    pub fn processIncludes(self: *IR, includes_list: []const types.Includes) !void {
        for (includes_list) |inc| {
            // Find the target interface
            const target_iface = self.interfaces.getPtr(inc.target);
            if (target_iface == null) {
                log.warn("  ⚠️  Warning: Interface '{s}' not found for includes statement", .{inc.target});
                continue;
            }

            // Find the mixin interface
            const mixin_iface = self.interfaces.get(inc.mixin);
            if (mixin_iface == null) {
                log.warn("  ⚠️  Warning: Mixin '{s}' not found for includes statement", .{inc.mixin});
                continue;
            }

            // Track which mixin was included
            const mixin_name = try self.allocator.dupe(u8, inc.mixin);
            try target_iface.?.mixins.append(self.allocator, mixin_name);

            // The mixin's members become the interface's own (WebIDL
            // `includes`), each remembering the mixin it was inherited from.
            for (mixin_iface.?.members.items) |member| {
                var inherited = member;
                if (inherited.attribute) |*attr| attr.mixin = mixin_name;
                if (inherited.operation) |*op| op.mixin = mixin_name;
                try target_iface.?.members.append(self.allocator, inherited);
            }
        }
    }

    /// Resolve all members for an interface including inherited members
    /// Returns a newly allocated slice that caller must free
    pub fn resolveAllMembers(self: *IR, interface_name: []const u8) ![]types.Member {
        var all_members = std.ArrayList(types.Member).empty;
        errdefer all_members.deinit(self.allocator);

        try self.collectMembersRecursive(interface_name, &all_members);

        return try all_members.toOwnedSlice(self.allocator);
    }

    /// Recursively collect members from inheritance chain (parent first, then child)
    fn collectMembersRecursive(self: *IR, interface_name: []const u8, members_list: *std.ArrayList(types.Member)) error{OutOfMemory}!void {
        const iface = self.interfaces.get(interface_name) orelse return;

        // First, collect parent members (if any)
        if (iface.inheritance) |parent_name| {
            try self.collectMembersRecursive(parent_name, members_list);
        }

        // Then add this interface's own members
        try members_list.appendSlice(self.allocator, iface.members.items);
    }
};

fn dictionaryMemberNamed(members: []const types.DictionaryMember, name: []const u8) bool {
    for (members) |member| if (std.mem.eql(u8, member.name, name)) return true;
    return false;
}

/// Append each of `partial`'s extended attributes `ext_attrs` has none of that name of.
fn appendMissingExtAttrs(allocator: std.mem.Allocator, ext_attrs: *std.ArrayList(types.ExtendedAttribute), partial: []const types.ExtendedAttribute) !void {
    for (partial) |ext_attr| {
        for (ext_attrs.items) |existing| {
            if (std.mem.eql(u8, existing.name, ext_attr.name)) break;
        } else try ext_attrs.append(allocator, ext_attr);
    }
}

/// IR representation of an interface (after merging partials)
pub const Interface = struct {
    name: []const u8,
    inheritance: ?[]const u8,
    members: std.ArrayList(types.Member),
    extAttrs: std.ArrayList(types.ExtendedAttribute),
    mixins: std.ArrayList([]const u8), // List of mixin names included
    mixin: bool,
    callback: bool, // Whether this is a callback interface (e.g., EventListener)
    has_base: bool, // true if we've seen a non-partial definition
    base_source_index: usize, // index in source_map list of the file containing the base definition

    /// Create IR interface from types.Interface
    /// Note: name is NOT duplicated - it references the key from source_map
    /// source_index: index in source_map list of the file being added
    pub fn fromTypes(allocator: std.mem.Allocator, iface: types.Interface, name_ref: []const u8, source_index: usize) !Interface {
        var members = std.ArrayList(types.Member).empty;
        try members.appendSlice(allocator, iface.members);

        var extAttrs = std.ArrayList(types.ExtendedAttribute).empty;
        try extAttrs.appendSlice(allocator, iface.extAttrs);

        const mixins = std.ArrayList([]const u8).empty;

        return Interface{
            .name = name_ref, // Use the key from source_map (not duplicated)
            .inheritance = if (iface.inheritance) |inh| try allocator.dupe(u8, inh) else null,
            .members = members,
            .extAttrs = extAttrs,
            .mixins = mixins,
            .mixin = iface.mixin,
            .callback = iface.callback,
            .has_base = !iface.partial, // has_base if this is not a partial
            .base_source_index = source_index, // Track which source has the base
        };
    }

    /// Merge a partial interface into this interface
    pub fn mergePartial(self: *Interface, allocator: std.mem.Allocator, partial: types.Interface) !void {
        // Append all members from partial
        try self.members.appendSlice(allocator, partial.members);

        // Merge extended attributes (avoiding duplicates)
        for (partial.extAttrs) |ext_attr| {
            var found = false;
            for (self.extAttrs.items) |existing| {
                if (std.mem.eql(u8, existing.name, ext_attr.name)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                try self.extAttrs.append(allocator, ext_attr);
            }
        }
    }

    /// Merge a base (non-partial) interface when we already have partials
    pub fn mergeBase(self: *Interface, allocator: std.mem.Allocator, base: types.Interface) !void {
        // Set inheritance from base (partials don't have inheritance)
        if (base.inheritance) |inh| {
            if (self.inheritance) |old_inh| allocator.free(old_inh);
            self.inheritance = try allocator.dupe(u8, inh);
        }

        // Prepend base members before partial members (base comes first)
        const old_members = try self.members.toOwnedSlice(allocator);
        defer allocator.free(old_members);

        try self.members.appendSlice(allocator, base.members);
        try self.members.appendSlice(allocator, old_members);

        // Merge extended attributes from base
        for (base.extAttrs) |ext_attr| {
            var found = false;
            for (self.extAttrs.items) |existing| {
                if (std.mem.eql(u8, existing.name, ext_attr.name)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                try self.extAttrs.append(allocator, ext_attr);
            }
        }

        // Mark that we now have a base
        self.has_base = true;
    }

    /// Convert back to types.Interface for code generation
    pub fn toTypes(self: Interface, allocator: std.mem.Allocator) !types.Interface {
        return types.Interface{
            .name = try allocator.dupe(u8, self.name),
            .inheritance = if (self.inheritance) |inh| try allocator.dupe(u8, inh) else null,
            .members = try allocator.dupe(types.Member, self.members.items),
            .extAttrs = try allocator.dupe(types.ExtendedAttribute, self.extAttrs.items),
            .includes = try allocator.dupe([]const u8, self.mixins.items),
            .partial = false, // After merging, it's no longer partial
            .mixin = self.mixin,
            .callback = self.callback,
        };
    }

    pub fn deinit(self: *Interface, allocator: std.mem.Allocator) void {
        // Note: self.name is owned by source_map, so don't free it here
        if (self.inheritance) |inh| allocator.free(inh);
        self.members.deinit(allocator);
        self.extAttrs.deinit(allocator);
        for (self.mixins.items) |mixin| {
            allocator.free(mixin);
        }
        self.mixins.deinit(allocator);
    }
};

/// Information about attributes to include in a ToJSON struct
pub const ToJSONAttribute = struct {
    name: []const u8,
    idl_type: types.IDLType,
};

/// Collect all attributes that should be serialized by [Default] toJSON
/// Per WebIDL spec, this includes all regular (non-static) attributes
/// from the interface AND its inherited interfaces.
///
/// Returns a list of ToJSONAttribute structs with attribute names and types.
/// Caller must free the returned slice.
pub fn collectToJSONAttributes(
    allocator: std.mem.Allocator,
    interface_name: []const u8,
    ir: *const IR,
) ![]ToJSONAttribute {
    var attrs: std.ArrayList(ToJSONAttribute) = .empty;
    errdefer attrs.deinit(allocator);

    // Track seen attribute names to handle overrides
    // Child attributes with same name replace parent attributes
    var seen_names = std.StringHashMap(usize).init(allocator);
    defer seen_names.deinit();

    // Walk the inheritance chain (parent first, then child)
    // This gives us attributes in the order they should appear
    try collectToJSONAttributesRecursive(allocator, interface_name, ir, &attrs, &seen_names);

    return try attrs.toOwnedSlice(allocator);
}

/// Recursively collect attributes from inheritance chain (parent first, then child)
/// Child attributes with the same name override parent attributes (per WebIDL spec)
fn collectToJSONAttributesRecursive(
    allocator: std.mem.Allocator,
    interface_name: []const u8,
    ir: *const IR,
    attrs: *std.ArrayList(ToJSONAttribute),
    seen_names: *std.StringHashMap(usize),
) !void {
    const iface = ir.interfaces.get(interface_name) orelse return;

    // First, collect parent attributes (if any)
    if (iface.inheritance) |parent_name| {
        try collectToJSONAttributesRecursive(allocator, parent_name, ir, attrs, seen_names);
    }

    // Then add this interface's own regular (non-static) attributes
    // Child attributes override parent attributes with the same name
    for (iface.members.items) |member| {
        if (member.asAttribute()) |attr| {
            // Skip static attributes - they're not serialized by toJSON
            if (attr.static) continue;

            const new_attr = ToJSONAttribute{
                .name = attr.name,
                .idl_type = attr.idlType,
            };

            if (seen_names.get(attr.name)) |existing_index| {
                // Replace parent's attribute with child's (child overrides)
                attrs.items[existing_index] = new_attr;
            } else {
                // New attribute - add it and track its index
                try seen_names.put(attr.name, attrs.items.len);
                try attrs.append(allocator, new_attr);
            }
        }
    }
}
