//! WrapperTypeInfo Registry - Comptime-generated WrapperTypeInfo for ALL WebIDL interfaces
//!
//! This module generates WrapperTypeInfo for every WebIDL interface at comptime
//! using the InterfaceCatalog. This replaces the manual definitions in dom_type_info.zig
//! with a fully automated, catalog-driven approach.
//!
//! ## Key Features
//!
//! 1. **Comptime Generation**: All WrapperTypeInfo structs are generated at compile time
//! 2. **Catalog-Driven**: Uses InterfaceCatalog to enumerate all interfaces
//! 3. **Stable IDs**: Uses TypeId (FNV-1a hash) for snapshot-stable identification
//! 4. **Parent Chain**: Correctly links parent WrapperTypeInfo pointers
//! 5. **O(1) Lookup**: StaticStringMap for runtime name-based lookup
//!
//! ## Usage
//!
//! ```zig
//! const registry = @import("wrapper_type_info_registry.zig");
//!
//! // Comptime lookup by type
//! const element_info = comptime registry.getWrapperTypeInfo(interfaces.Element);
//!
//! // Runtime lookup by name
//! const doc_info = registry.getWrapperTypeInfoByName("Document");
//! ```

const std = @import("std");
const interface_catalog = @import("interface_catalog.zig");
const type_id = @import("type_id.zig");
const wrapper_type_info = @import("wrapper_type_info.zig");
const WrapperTypeInfo = wrapper_type_info.WrapperTypeInfo;
const TypeTag = wrapper_type_info.TypeTag;
const WrapperClassId = wrapper_type_info.WrapperClassId;
const IdlDefinitionKind = wrapper_type_info.IdlDefinitionKind;
const TypeId = type_id.TypeId;
const interfaces = @import("interfaces");
const v8 = @import("ffi.zig");

// ============================================================================
// Placeholder install function (will be connected later in Phase 3)
// ============================================================================

/// Placeholder install function for interfaces that haven't had their
/// template installation function connected yet.
///
/// This panic is intentional - it will be replaced with real implementations
/// as part of Phase 3 (comptime template registry).
fn placeholderInstallTemplate(_: *v8.Isolate) *v8.FunctionTemplate {
    @panic("WrapperTypeInfo.install_template_fn called but not connected - complete Phase 3 to connect implementations");
}

// ============================================================================
// Extended WrapperTypeInfo with TypeId
// ============================================================================

/// Extended WrapperTypeInfo that includes the snapshot-stable TypeId
pub const WrapperTypeInfoExt = struct {
    /// The base WrapperTypeInfo (for compatibility with existing code)
    info: WrapperTypeInfo,
    /// Snapshot-stable TypeId (FNV-1a hash of interface name)
    stable_id: TypeId,

    /// Get the base WrapperTypeInfo
    pub fn getInfo(self: *const WrapperTypeInfoExt) *const WrapperTypeInfo {
        return &self.info;
    }

    /// Get the interface name
    pub fn getName(self: *const WrapperTypeInfoExt) []const u8 {
        return self.info.getName();
    }
};

// ============================================================================
// Comptime WrapperTypeInfo Generation
// ============================================================================

/// Number of valid (non-mixin, non-skipped) interfaces
pub const valid_interface_count = interface_catalog.valid_interface_count;

/// Check if child_name is a descendant of parent_name using catalog entries.
/// Uses only parent_name field lookups, avoiding full interface list scans.
fn isDescendantOfUsingEntries(
    comptime child_name: []const u8,
    comptime parent_name: []const u8,
    comptime entries: []const interface_catalog.InterfaceEntry,
) bool {
    if (std.mem.eql(u8, child_name, parent_name)) {
        return false; // Not a descendant of itself
    }

    // Walk up the parent chain
    var current_name = child_name;
    var iterations: usize = 0;
    const max_iterations = 20; // Max depth of inheritance chain

    while (iterations < max_iterations) : (iterations += 1) {
        // Find current interface entry
        var found_parent_name: ?[]const u8 = null;
        for (entries) |entry| {
            if (std.mem.eql(u8, entry.name, current_name)) {
                found_parent_name = entry.parent_name;
                break;
            }
        }

        if (found_parent_name) |pn| {
            if (std.mem.eql(u8, pn, parent_name)) {
                return true;
            }
            current_name = pn;
        } else {
            break; // No parent, stop searching
        }
    }

    return false;
}

/// Pre-computed mapping from interface index to whether it's a Node descendant.
/// This is computed once at comptime to avoid repeated O(n*depth) lookups.
fn computeNodeDescendants() [valid_interface_count]bool {
    @setEvalBranchQuota(10000000);
    comptime {
        const entries = interface_catalog.getValidInterfaces();
        var results: [valid_interface_count]bool = undefined;

        for (entries, 0..) |entry, i| {
            // Is Node or descendant of Node
            if (std.mem.eql(u8, entry.name, "Node")) {
                results[i] = true;
            } else {
                results[i] = isDescendantOfUsingEntries(entry.name, "Node", entries);
            }
        }

        return results;
    }
}

/// Pre-computed Node descendant flags
const node_descendants = computeNodeDescendants();

/// Get the WrapperClassId for an interface based on its index
fn getWrapperClassIdByIndex(comptime idx: usize) WrapperClassId {
    // Node and all its descendants get special GC treatment
    if (node_descendants[idx]) {
        return .node;
    }
    return .object;
}

/// Tag assignment entry
const TagAssignment = struct {
    name: []const u8,
    tag: TypeTag,
    max_tag: TypeTag,
};

/// Assign type tags to all interfaces
/// Tags are assigned as index * 10 + 100 to leave room for future additions
///
/// NOTE: We use a simple O(n) algorithm here. Each interface gets a unique tag,
/// and max_tag is set to a large constant (65535). Subclass checking is done
/// via isSubclassOf() which walks the parent chain - this is authoritative
/// and doesn't rely on tag ranges. The tag ranges are only used for fast
/// preliminary checks; the parent chain walk is the definitive check.
fn computeTagAssignments() [valid_interface_count]TagAssignment {
    @setEvalBranchQuota(200000);
    comptime {
        const valid_interfaces = interface_catalog.getValidInterfaces();
        var assignments: [valid_interface_count]TagAssignment = undefined;

        // Simple O(n) assignment: each interface gets a unique tag
        // max_tag is set to maximum possible value since subclass checking
        // uses parent chain walking (isSubclassOf) not tag range comparison
        for (valid_interfaces, 0..) |entry, i| {
            const tag: TypeTag = @intCast(i * 10 + 100);
            assignments[i] = .{
                .name = entry.name,
                .tag = tag,
                .max_tag = 65535, // Max value - subclass check uses parent chain
            };
        }

        return assignments;
    }
}

/// Tag assignments computed at comptime
const tag_assignments = computeTagAssignments();

/// Get tag assignment for an interface name
fn getTagAssignment(comptime name: []const u8) ?TagAssignment {
    @setEvalBranchQuota(500000);
    comptime {
        for (tag_assignments) |assignment| {
            if (std.mem.eql(u8, assignment.name, name)) {
                return assignment;
            }
        }
        return null;
    }
}

/// Get index of an interface in the valid_interfaces array
fn getInterfaceIndex(comptime name: []const u8) ?usize {
    @setEvalBranchQuota(500000);
    const valid_interfaces = interface_catalog.getValidInterfaces();
    for (valid_interfaces, 0..) |entry, i| {
        if (std.mem.eql(u8, entry.name, name)) {
            return i;
        }
    }
    return null;
}

/// Pre-compute parent indices for all interfaces.
/// Returns an array where result[i] is the index of interface i's parent,
/// or null if it has no parent.
fn computeParentIndices() [valid_interface_count]?usize {
    @setEvalBranchQuota(10000000);
    comptime {
        const entries = interface_catalog.getValidInterfaces();
        var result: [valid_interface_count]?usize = undefined;

        for (entries, 0..) |entry, i| {
            if (entry.parent_name) |parent_name| {
                // Find parent index - O(n) but only done once per interface
                var found: ?usize = null;
                for (entries, 0..) |other, j| {
                    if (std.mem.eql(u8, other.name, parent_name)) {
                        found = j;
                        break;
                    }
                }
                result[i] = found;
            } else {
                result[i] = null;
            }
        }

        return result;
    }
}

/// Pre-computed parent indices
const parent_indices = computeParentIndices();

/// Generate WrapperTypeInfoExt array for all valid interfaces (without parent links)
fn generateWrapperTypeInfosBase() [valid_interface_count]WrapperTypeInfoExt {
    @setEvalBranchQuota(10000000);
    comptime {
        const valid_interfaces = interface_catalog.getValidInterfaces();
        var infos: [valid_interface_count]WrapperTypeInfoExt = undefined;

        // Create all entries without parent links
        // Uses index-based lookups - O(1) access to parallel arrays
        for (valid_interfaces, 0..) |entry, i| {
            // tag_assignments is parallel to valid_interfaces, so use index directly
            const assignment = tag_assignments[i];

            infos[i] = .{
                .info = .{
                    .interface_name = @ptrCast(entry.name.ptr),
                    .parent = null, // Parent links are set up via getParent()
                    .this_tag = assignment.tag,
                    .max_subclass_tag = assignment.max_tag,
                    .wrapper_class_id = getWrapperClassIdByIndex(i),
                    .idl_definition_kind = .interface,
                    .install_template_fn = placeholderInstallTemplate,
                },
                .stable_id = type_id.computeStableHash(entry.name),
            };
        }

        return infos;
    }
}

/// Array of WrapperTypeInfoExt for all valid interfaces, generated at comptime
/// Note: parent pointers are NOT set in this array. Use getParentInfo() instead.
pub const wrapper_type_infos: [valid_interface_count]WrapperTypeInfoExt = generateWrapperTypeInfosBase();

/// Get the parent WrapperTypeInfo for an entry by index
/// This is the O(1) way to traverse the inheritance chain.
pub fn getParentInfo(index: usize) ?*const WrapperTypeInfo {
    if (parent_indices[index]) |parent_idx| {
        return &wrapper_type_infos[parent_idx].info;
    }
    return null;
}

/// Get the parent WrapperTypeInfo for a WrapperTypeInfo pointer
/// Walks the registry to find the parent.
pub fn getParentInfoByPtr(info: *const WrapperTypeInfo) ?*const WrapperTypeInfo {
    // Find the index of this info in the array
    for (&wrapper_type_infos, 0..) |*entry, i| {
        if (&entry.info == info) {
            return getParentInfo(i);
        }
    }
    return null;
}

// ============================================================================
// Lookup Functions
// ============================================================================

/// Get WrapperTypeInfo for an interface type at comptime
///
/// This is the primary way to get type info when you know the type at compile time.
///
/// Example:
/// ```zig
/// const element_info = comptime getWrapperTypeInfo(interfaces.Element);
/// ```
pub fn getWrapperTypeInfo(comptime InterfaceType: type) *const WrapperTypeInfo {
    comptime {
        if (!@hasDecl(InterfaceType, "Meta")) {
            @compileError("Interface type must have a Meta declaration");
        }
        const meta = InterfaceType.Meta;
        if (!@hasDecl(meta, "name")) {
            @compileError("Interface Meta must have a name field");
        }
        const name = meta.name;

        // Find in generated array
        for (&wrapper_type_infos) |*info| {
            if (std.mem.eql(u8, info.info.getName(), name)) {
                return &info.info;
            }
        }

        @compileError("Interface not found in catalog: " ++ name);
    }
}

/// Get WrapperTypeInfoExt for an interface type at comptime
///
/// Use this when you also need the stable_id.
pub fn getWrapperTypeInfoExt(comptime InterfaceType: type) *const WrapperTypeInfoExt {
    comptime {
        if (!@hasDecl(InterfaceType, "Meta")) {
            @compileError("Interface type must have a Meta declaration");
        }
        const meta = InterfaceType.Meta;
        if (!@hasDecl(meta, "name")) {
            @compileError("Interface Meta must have a name field");
        }
        const name = meta.name;

        // Find in generated array
        for (&wrapper_type_infos) |*info| {
            if (std.mem.eql(u8, info.info.getName(), name)) {
                return info;
            }
        }

        @compileError("Interface not found in catalog: " ++ name);
    }
}

/// Generate lookup table keys for StaticStringMap
fn generateLookupKeys() [valid_interface_count]struct { []const u8, *const WrapperTypeInfo } {
    @setEvalBranchQuota(100000);
    comptime {
        var keys: [valid_interface_count]struct { []const u8, *const WrapperTypeInfo } = undefined;
        for (&wrapper_type_infos, 0..) |*info, i| {
            keys[i] = .{ info.info.getName(), &info.info };
        }
        return keys;
    }
}

/// Lookup table for O(1) name-based lookup
const lookup_keys = generateLookupKeys();

/// StaticStringMap for O(1) runtime lookup by name
const LookupMap = std.StaticStringMap(*const WrapperTypeInfo);
const lookup_map = blk: {
    @setEvalBranchQuota(200000);
    break :blk LookupMap.initComptime(lookup_keys);
};

/// Get WrapperTypeInfo by interface name at runtime - O(1) lookup
///
/// This provides O(1) lookup by name, suitable for runtime dispatch.
///
/// Example:
/// ```zig
/// const doc_info = getWrapperTypeInfoByName("Document");
/// ```
pub fn getWrapperTypeInfoByName(name: []const u8) ?*const WrapperTypeInfo {
    return lookup_map.get(name);
}

/// Check if a WrapperTypeInfo exists for the given interface name - O(1)
pub fn hasWrapperTypeInfo(name: []const u8) bool {
    return lookup_map.has(name);
}

/// Generate extended lookup table keys for StaticStringMap
fn generateExtLookupKeys() [valid_interface_count]struct { []const u8, *const WrapperTypeInfoExt } {
    @setEvalBranchQuota(100000);
    comptime {
        var keys: [valid_interface_count]struct { []const u8, *const WrapperTypeInfoExt } = undefined;
        for (&wrapper_type_infos, 0..) |*info, i| {
            keys[i] = .{ info.info.getName(), info };
        }
        return keys;
    }
}

/// Lookup table for O(1) name-based lookup of extended info
const ext_lookup_keys = generateExtLookupKeys();

/// StaticStringMap for O(1) runtime lookup by name (extended info)
const ExtLookupMap = std.StaticStringMap(*const WrapperTypeInfoExt);
const ext_lookup_map = blk: {
    @setEvalBranchQuota(200000);
    break :blk ExtLookupMap.initComptime(ext_lookup_keys);
};

/// Get WrapperTypeInfoExt by interface name at runtime
///
/// Use this when you also need the stable_id at runtime.
pub fn getWrapperTypeInfoExtByName(name: []const u8) ?*const WrapperTypeInfoExt {
    return ext_lookup_map.get(name);
}

/// Get all registered WrapperTypeInfo entries
/// Useful for iteration and debugging
pub fn getAllWrapperTypeInfos() []const WrapperTypeInfoExt {
    return &wrapper_type_infos;
}

// ============================================================================
// Iterator
// ============================================================================

/// Iterator over all WrapperTypeInfo entries
pub const WrapperTypeInfoIterator = struct {
    index: usize,

    pub fn next(self: *WrapperTypeInfoIterator) ?*const WrapperTypeInfo {
        if (self.index >= valid_interface_count) return null;
        const result = &wrapper_type_infos[self.index].info;
        self.index += 1;
        return result;
    }

    pub fn reset(self: *WrapperTypeInfoIterator) void {
        self.index = 0;
    }
};

/// Get an iterator over all WrapperTypeInfo entries
pub fn iterator() WrapperTypeInfoIterator {
    return .{ .index = 0 };
}

// ============================================================================
// Tests
// ============================================================================

test "wrapper_type_infos generated for known interfaces" {
    // Check that we have the expected number of interfaces
    try std.testing.expect(valid_interface_count > 100);

    // Check that known interfaces exist and have correct parents
    var found_event_target = false;
    var found_node = false;
    var found_element = false;
    var found_document = false;

    for (&wrapper_type_infos, 0..) |*info, i| {
        const name = info.info.getName();
        if (std.mem.eql(u8, name, "EventTarget")) {
            found_event_target = true;
            // EventTarget has no parent
            try std.testing.expect(getParentInfo(i) == null);
        }
        if (std.mem.eql(u8, name, "Node")) {
            found_node = true;
            const parent = getParentInfo(i);
            try std.testing.expect(parent != null);
            try std.testing.expectEqualStrings("EventTarget", parent.?.getName());
        }
        if (std.mem.eql(u8, name, "Element")) {
            found_element = true;
            const parent = getParentInfo(i);
            try std.testing.expect(parent != null);
            try std.testing.expectEqualStrings("Node", parent.?.getName());
        }
        if (std.mem.eql(u8, name, "Document")) {
            found_document = true;
            const parent = getParentInfo(i);
            try std.testing.expect(parent != null);
            try std.testing.expectEqualStrings("Node", parent.?.getName());
        }
    }

    try std.testing.expect(found_event_target);
    try std.testing.expect(found_node);
    try std.testing.expect(found_element);
    try std.testing.expect(found_document);
}

test "parent chain is correct for Element hierarchy" {
    // Find Element's index
    var element_idx: ?usize = null;
    for (&wrapper_type_infos, 0..) |*info, i| {
        if (std.mem.eql(u8, info.info.getName(), "Element")) {
            element_idx = i;
            break;
        }
    }
    try std.testing.expect(element_idx != null);

    // Element -> Node -> EventTarget -> null
    const node_info = getParentInfo(element_idx.?);
    try std.testing.expect(node_info != null);
    try std.testing.expectEqualStrings("Node", node_info.?.getName());

    const event_target_info = getParentInfoByPtr(node_info.?);
    try std.testing.expect(event_target_info != null);
    try std.testing.expectEqualStrings("EventTarget", event_target_info.?.getName());

    const null_parent = getParentInfoByPtr(event_target_info.?);
    try std.testing.expect(null_parent == null);
}

test "stable_id matches typeIdFor output" {
    const EventTarget = interfaces.EventTarget;
    const Node = interfaces.Node;
    const Element = interfaces.Element;
    const Document = interfaces.Document;

    const event_target_ext = comptime getWrapperTypeInfoExt(EventTarget);
    const node_ext = comptime getWrapperTypeInfoExt(Node);
    const element_ext = comptime getWrapperTypeInfoExt(Element);
    const document_ext = comptime getWrapperTypeInfoExt(Document);

    // Verify stable_ids match typeIdFor output
    try std.testing.expectEqual(type_id.typeIdFor(EventTarget), event_target_ext.stable_id);
    try std.testing.expectEqual(type_id.typeIdFor(Node), node_ext.stable_id);
    try std.testing.expectEqual(type_id.typeIdFor(Element), element_ext.stable_id);
    try std.testing.expectEqual(type_id.typeIdFor(Document), document_ext.stable_id);
}

test "getWrapperTypeInfoByName returns correct info" {
    const element_info = getWrapperTypeInfoByName("Element");
    try std.testing.expect(element_info != null);
    try std.testing.expectEqualStrings("Element", element_info.?.getName());

    const document_info = getWrapperTypeInfoByName("Document");
    try std.testing.expect(document_info != null);
    try std.testing.expectEqualStrings("Document", document_info.?.getName());

    const unknown_info = getWrapperTypeInfoByName("NonExistentInterface12345");
    try std.testing.expect(unknown_info == null);
}

test "Node and descendants have node wrapper_class_id" {
    const node_info = getWrapperTypeInfoByName("Node");
    try std.testing.expect(node_info != null);
    try std.testing.expectEqual(WrapperClassId.node, node_info.?.wrapper_class_id);

    const element_info = getWrapperTypeInfoByName("Element");
    try std.testing.expect(element_info != null);
    try std.testing.expectEqual(WrapperClassId.node, element_info.?.wrapper_class_id);

    const document_info = getWrapperTypeInfoByName("Document");
    try std.testing.expect(document_info != null);
    try std.testing.expectEqual(WrapperClassId.node, document_info.?.wrapper_class_id);
}

test "EventTarget has object wrapper_class_id" {
    const event_target_info = getWrapperTypeInfoByName("EventTarget");
    try std.testing.expect(event_target_info != null);
    // EventTarget itself is not a Node descendant
    try std.testing.expectEqual(WrapperClassId.object, event_target_info.?.wrapper_class_id);
}

test "iterator returns all interfaces" {
    var iter = iterator();
    var count: usize = 0;
    while (iter.next()) |_| {
        count += 1;
    }
    try std.testing.expectEqual(valid_interface_count, count);
}

test "all interfaces have unique tags" {
    var seen_tags = std.AutoHashMap(TypeTag, []const u8).init(std.testing.allocator);
    defer seen_tags.deinit();

    for (&wrapper_type_infos) |*info| {
        const tag = info.info.this_tag;
        const name = info.info.getName();

        if (seen_tags.get(tag)) |existing_name| {
            std.debug.print("Duplicate tag {d} for '{s}' and '{s}'\n", .{ tag, name, existing_name });
            try std.testing.expect(false);
        }

        try seen_tags.put(tag, name);
    }
}

test "all interfaces have unique stable_ids" {
    var seen_ids = std.AutoHashMap(TypeId, []const u8).init(std.testing.allocator);
    defer seen_ids.deinit();

    for (&wrapper_type_infos) |*info| {
        const id = info.stable_id;
        const name = info.info.getName();

        if (seen_ids.get(id)) |existing_name| {
            std.debug.print("Duplicate stable_id {x} for '{s}' and '{s}'\n", .{ id, name, existing_name });
            try std.testing.expect(false);
        }

        try seen_ids.put(id, name);
    }
}
