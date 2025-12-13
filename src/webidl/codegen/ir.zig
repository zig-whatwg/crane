//! Intermediate Representation (IR) for WebIDL
//!
//! This module provides an IR that represents the complete WebIDL specification
//! after parsing all files and merging partial interfaces.

const std = @import("std");
const types = @import("types.zig");
const spec_priority_mod = @import("spec_priority.zig");
const type_registry_mod = @import("type_registry.zig");

// Re-export TypeRegistry and TypeKind from type_registry module for backward compatibility
pub const TypeRegistry = type_registry_mod.TypeRegistry;
pub const TypeKind = type_registry_mod.TypeKind;
pub const TypeInfo = type_registry_mod.TypeInfo;
pub const UnionInfo = type_registry_mod.UnionInfo;
pub const UnionMember = type_registry_mod.UnionMember;
pub const TypeRegistryStats = type_registry_mod.TypeRegistryStats;

/// Complete IR for all parsed WebIDL specifications
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

    /// Source file mapping (which spec defines/extends each interface)
    source_map: std.StringHashMap(std.ArrayList([]const u8)),

    /// Spec priority resolver for handling duplicates
    spec_priority: spec_priority_mod.SpecPriority,

    /// Allocated dictionary member slices (need to be freed)
    merged_dict_members: std.ArrayList([]types.DictionaryMember),

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
            .spec_priority = try spec_priority_mod.SpecPriority.initDefault(allocator),
            .merged_dict_members = std.ArrayList([]types.DictionaryMember).empty,
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

        // Free dictionaries (keys are owned by source_map, so don't free them)
        self.dictionaries.deinit();

        // Free allocated dictionary member slices (from partial merging)
        for (self.merged_dict_members.items) |members| {
            self.allocator.free(members);
        }
        self.merged_dict_members.deinit(self.allocator);

        // Free typedefs (keys are owned by source_map, so don't free them)
        self.typedefs.deinit();

        // Free enums (keys are owned by source_map, so don't free them)
        self.enums.deinit();

        // Free callbacks (keys are owned by source_map, so don't free them)
        self.callbacks.deinit();

        // Free namespaces (keys are owned by source_map, so don't free them)
        self.namespaces.deinit();

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

        // Free spec priority
        self.spec_priority.deinit();
    }

    /// Add an interface from a parsed IDL file
    pub fn addInterface(self: *IR, iface: types.Interface, source_file: []const u8) !void {
        // Get or create source_map entry first (this owns the name key)
        const source_gop = try self.source_map.getOrPut(iface.name);
        if (!source_gop.found_existing) {
            // First time seeing this name - allocate the key
            const name_copy = try self.allocator.dupe(u8, iface.name);
            source_gop.key_ptr.* = name_copy;
            source_gop.value_ptr.* = std.ArrayList([]const u8).empty;
        }

        // Track source file - once appended, ArrayList owns it (no errdefer after append)
        const source_copy = try self.allocator.dupe(u8, source_file);
        const source_index = source_gop.value_ptr.items.len; // Index before appending
        source_gop.value_ptr.append(self.allocator, source_copy) catch |err| {
            // If append fails, we still own source_copy, so free it
            self.allocator.free(source_copy);
            return err;
        };

        // Add or merge interface (use the key from source_map)
        const shared_key = source_gop.key_ptr.*;
        const iface_gop = try self.interfaces.getOrPut(shared_key);
        if (!iface_gop.found_existing) {
            // First time seeing this interface - add it (partial or not)
            iface_gop.value_ptr.* = try Interface.fromTypes(self.allocator, iface, shared_key, source_index);
            // Register interface type - distinguish callback interfaces
            const type_kind: TypeKind = if (iface.callback) .callback_interface else .interface;
            try self.type_registry.register(shared_key, type_kind);
        } else if (iface.partial) {
            // Partial interface - merge with existing (which might also be partial-only so far)
            try iface_gop.value_ptr.mergePartial(self.allocator, iface);
        } else {
            // Non-partial interface
            if (iface_gop.value_ptr.has_base) {
                // Already have a non-partial base - check priority
                const existing_source = source_gop.value_ptr.items[iface_gop.value_ptr.base_source_index];

                // Only print warnings if files are different (skip same-file duplicates from module blocks)
                const same_file = std.mem.eql(u8, source_file, existing_source);

                if (self.spec_priority.shouldPrefer(iface.name, source_file, existing_source)) {
                    // New spec has higher priority - replace existing
                    if (!same_file) {
                        std.debug.print("  ⚠️  Duplicate '{s}': preferring {s} over {s}\n", .{ iface.name, source_file, existing_source });
                    }

                    // Replace the base definition
                    try iface_gop.value_ptr.mergeBase(self.allocator, iface);
                    iface_gop.value_ptr.base_source_index = source_index;
                } else {
                    // Existing spec has higher priority - skip new one
                    if (!same_file) {
                        std.debug.print("  ⚠️  Duplicate '{s}': keeping {s}, skipping {s}\n", .{ iface.name, existing_source, source_file });
                    }
                    // Skip this duplicate (don't return error)
                }
            } else {
                // Existing interface only has partials - this is the base, merge existing partials into it
                try iface_gop.value_ptr.mergeBase(self.allocator, iface);
                // Update base_source_index to point to the file with the non-partial definition
                iface_gop.value_ptr.base_source_index = source_index;
            }
        }
    }

    /// Process includes statements to merge mixin members into target interfaces
    pub fn processIncludes(self: *IR, includes_list: []const types.Includes) !void {
        for (includes_list) |inc| {
            // Find the target interface
            const target_iface = self.interfaces.getPtr(inc.target);
            if (target_iface == null) {
                std.debug.print("  ⚠️  Warning: Interface '{s}' not found for includes statement\n", .{inc.target});
                continue;
            }

            // Find the mixin interface
            const mixin_iface = self.interfaces.get(inc.mixin);
            if (mixin_iface == null) {
                std.debug.print("  ⚠️  Warning: Mixin '{s}' not found for includes statement\n", .{inc.mixin});
                continue;
            }

            // Merge mixin members into target interface
            try target_iface.?.members.appendSlice(self.allocator, mixin_iface.?.members.items);

            // Track which mixin was included
            const mixin_name = try self.allocator.dupe(u8, inc.mixin);
            try target_iface.?.mixins.append(self.allocator, mixin_name);
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

    /// Add a dictionary from a parsed IDL file
    /// Handles partial dictionaries by merging members into existing dictionaries
    pub fn addDictionary(self: *IR, dict: types.Dictionary, source_file: []const u8) !void {
        // Get or create source_map entry first (this owns the name key)
        const source_gop = try self.source_map.getOrPut(dict.name);
        if (!source_gop.found_existing) {
            // First time seeing this name - allocate the key
            const name_copy = try self.allocator.dupe(u8, dict.name);
            source_gop.key_ptr.* = name_copy;
            source_gop.value_ptr.* = std.ArrayList([]const u8).empty;
        }

        // Track source file - once appended, ArrayList owns it (no errdefer after append)
        const source_copy = try self.allocator.dupe(u8, source_file);
        source_gop.value_ptr.append(self.allocator, source_copy) catch |err| {
            // If append fails, we still own source_copy, so free it
            self.allocator.free(source_copy);
            return err;
        };

        const shared_key = source_gop.key_ptr.*;

        // Check if dictionary already exists
        if (self.dictionaries.getPtr(shared_key)) |existing| {
            if (dict.partial) {
                // Partial dictionary - merge members into existing
                // Partial members OVERRIDE existing members with the same name
                // This is how WebIDL partial dictionaries work (e.g., web-animations-2.idl
                // redefines members from web-animations.idl with different types)

                // Build a set of member names from the partial
                var partial_member_names = std.StringHashMap(void).init(self.allocator);
                defer partial_member_names.deinit();
                for (dict.members) |member| {
                    try partial_member_names.put(member.name, {});
                }

                // Count how many existing members are NOT overridden by partial
                var non_overridden_count: usize = 0;
                for (existing.members) |member| {
                    if (!partial_member_names.contains(member.name)) {
                        non_overridden_count += 1;
                    }
                }

                // Create new members slice: non-overridden existing + all partial members
                const new_members = try self.allocator.alloc(types.DictionaryMember, non_overridden_count + dict.members.len);

                // Copy non-overridden existing members first
                var idx: usize = 0;
                for (existing.members) |member| {
                    if (!partial_member_names.contains(member.name)) {
                        new_members[idx] = member;
                        idx += 1;
                    }
                }

                // Then copy all partial members (these override or add)
                @memcpy(new_members[idx..], dict.members);

                existing.members = new_members;
                // Track allocation for cleanup
                try self.merged_dict_members.append(self.allocator, new_members);
            } else if (!existing.partial) {
                // Both are non-partial - check priority
                const existing_source = source_gop.value_ptr.items[0];
                const same_file = std.mem.eql(u8, source_file, existing_source);

                if (self.spec_priority.shouldPrefer(dict.name, source_file, existing_source)) {
                    // New spec has higher priority - replace existing
                    if (!same_file) {
                        std.debug.print("  ⚠️  Duplicate dictionary '{s}': preferring {s} over {s}\n", .{ dict.name, source_file, existing_source });
                    }
                    existing.* = dict;
                } else {
                    // Existing spec has higher priority - skip new one
                    if (!same_file) {
                        std.debug.print("  ⚠️  Duplicate dictionary '{s}': keeping {s}, skipping {s}\n", .{ dict.name, existing_source, source_file });
                    }
                }
            } else {
                // Existing is partial-only, this is the base - merge existing partials into base
                // Partial members OVERRIDE base members with the same name
                const old_partial_members = existing.members;

                // Build a set of member names from the partial
                var partial_member_names = std.StringHashMap(void).init(self.allocator);
                defer partial_member_names.deinit();
                for (old_partial_members) |member| {
                    try partial_member_names.put(member.name, {});
                }

                // Count how many base members are NOT overridden by partial
                var non_overridden_count: usize = 0;
                for (dict.members) |member| {
                    if (!partial_member_names.contains(member.name)) {
                        non_overridden_count += 1;
                    }
                }

                // Create new members slice: non-overridden base + all partial members
                const new_members = try self.allocator.alloc(types.DictionaryMember, non_overridden_count + old_partial_members.len);

                // Copy non-overridden base members first
                var idx: usize = 0;
                for (dict.members) |member| {
                    if (!partial_member_names.contains(member.name)) {
                        new_members[idx] = member;
                        idx += 1;
                    }
                }

                // Then copy all partial members (these override or add)
                @memcpy(new_members[idx..], old_partial_members);

                var merged = dict;
                merged.members = new_members;
                merged.partial = false;
                existing.* = merged;
                // Track allocation for cleanup
                try self.merged_dict_members.append(self.allocator, new_members);
            }
        } else {
            // First time seeing this dictionary - add it
            try self.dictionaries.put(shared_key, dict);
            // Register dictionary type
            try self.type_registry.register(shared_key, .dictionary);
        }
    }

    /// Add a typedef from a parsed IDL file
    pub fn addTypedef(self: *IR, typedef: types.Typedef, source_file: []const u8) !void {
        // Get or create source_map entry first (this owns the name key)
        const source_gop = try self.source_map.getOrPut(typedef.name);
        if (!source_gop.found_existing) {
            // First time seeing this name - allocate the key
            const name_copy = try self.allocator.dupe(u8, typedef.name);
            source_gop.key_ptr.* = name_copy;
            source_gop.value_ptr.* = std.ArrayList([]const u8).empty;
        }

        // Track source file - once appended, ArrayList owns it (no errdefer after append)
        const source_copy = try self.allocator.dupe(u8, source_file);
        source_gop.value_ptr.append(self.allocator, source_copy) catch |err| {
            // If append fails, we still own source_copy, so free it
            self.allocator.free(source_copy);
            return err;
        };

        // Typedefs don't have partials, so just add (use the key from source_map)
        const shared_key = source_gop.key_ptr.*;
        try self.typedefs.put(shared_key, typedef);
        // Register typedef type
        try self.type_registry.register(shared_key, .typedef);
    }

    pub fn addEnum(self: *IR, enum_type: types.Enum, source_file: []const u8) !void {
        // Get or create source_map entry first (this owns the name key)
        const source_gop = try self.source_map.getOrPut(enum_type.name);
        if (!source_gop.found_existing) {
            // First time seeing this name - allocate the key
            const name_copy = try self.allocator.dupe(u8, enum_type.name);
            source_gop.key_ptr.* = name_copy;
            source_gop.value_ptr.* = std.ArrayList([]const u8).empty;
        }

        // Track source file
        const source_copy = try self.allocator.dupe(u8, source_file);
        source_gop.value_ptr.append(self.allocator, source_copy) catch |err| {
            self.allocator.free(source_copy);
            return err;
        };

        // Enums don't have partials, so just add
        const shared_key = source_gop.key_ptr.*;
        try self.enums.put(shared_key, enum_type);
        // Register enum type
        try self.type_registry.register(shared_key, .enum_type);
    }

    pub fn addCallback(self: *IR, callback: types.Callback, source_file: []const u8) !void {
        // Get or create source_map entry first (this owns the name key)
        const source_gop = try self.source_map.getOrPut(callback.name);
        if (!source_gop.found_existing) {
            // First time seeing this name - allocate the key
            const name_copy = try self.allocator.dupe(u8, callback.name);
            source_gop.key_ptr.* = name_copy;
            source_gop.value_ptr.* = std.ArrayList([]const u8).empty;
        }

        // Track source file
        const source_copy = try self.allocator.dupe(u8, source_file);
        source_gop.value_ptr.append(self.allocator, source_copy) catch |err| {
            self.allocator.free(source_copy);
            return err;
        };

        // Callbacks don't have partials, so just add
        const shared_key = source_gop.key_ptr.*;
        try self.callbacks.put(shared_key, callback);
        // Register callback type
        try self.type_registry.register(shared_key, .callback);
    }

    pub fn addNamespace(self: *IR, namespace: types.Namespace, source_file: []const u8) !void {
        // Get or create source_map entry first (this owns the name key)
        const source_gop = try self.source_map.getOrPut(namespace.name);
        if (!source_gop.found_existing) {
            // First time seeing this name - allocate the key
            const name_copy = try self.allocator.dupe(u8, namespace.name);
            source_gop.key_ptr.* = name_copy;
            source_gop.value_ptr.* = std.ArrayList([]const u8).empty;
        }

        // Track source file
        const source_copy = try self.allocator.dupe(u8, source_file);
        source_gop.value_ptr.append(self.allocator, source_copy) catch |err| {
            self.allocator.free(source_copy);
            return err;
        };

        // Namespaces don't have partials, so just add
        const shared_key = source_gop.key_ptr.*;
        try self.namespaces.put(shared_key, namespace);
        // Register namespace type
        try self.type_registry.register(shared_key, .namespace);
    }
};

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
    var attrs: std.ArrayList(ToJSONAttribute) = .{};
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
