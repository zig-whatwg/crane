//! Interface Catalog - Comptime enumeration of all WebIDL interfaces
//!
//! This module provides a centralized, comptime-generated catalog of all
//! WebIDL interfaces exported from src/webidl/interfaces/root.zig.
//!
//! Features:
//! - Enumerates all interfaces at comptime using @typeInfo
//! - Exposes name, parent, is_mixin, and traits for each interface
//! - Centralizes skip list for non-instantiable/problematic types
//! - Excludes mixins (is_mixin = true)
//! - Provides comptime iteration over all valid interfaces

const std = @import("std");
const interfaces = @import("interfaces");

/// Entry describing a single WebIDL interface
pub const InterfaceEntry = struct {
    /// The interface name (e.g., "EventTarget", "Node", "Element")
    name: []const u8,
    /// Parent interface name, if any (null for root interfaces)
    parent_name: ?[]const u8,
    /// Whether this is a mixin (mixins are excluded from valid interfaces)
    is_mixin: bool,
    /// Whether this is a callback interface
    is_callback_interface: bool,
    /// Whether the interface has a constructor
    has_constructor: bool,
    /// Property count (own properties only)
    property_count: usize,
    /// Method count (own methods only)
    method_count: usize,
};

/// Skip list for interfaces that should not be instantiated or registered.
/// These are types that are problematic, abstract, or non-instantiable.
pub const skip_list = [_][]const u8{
    // Add any problematic interfaces here as they are discovered
};

/// Check if an interface name is in the skip list
pub fn isSkipped(name: []const u8) bool {
    inline for (skip_list) |skipped| {
        if (std.mem.eql(u8, name, skipped)) {
            return true;
        }
    }
    return false;
}

/// Get all valid (non-mixin, non-skipped) interfaces at comptime
pub fn getValidInterfaces() []const InterfaceEntry {
    @setEvalBranchQuota(100000);
    comptime {
        const decls = @typeInfo(interfaces).@"struct".decls;
        var count: usize = 0;

        // First pass: count valid entries
        for (decls) |decl| {
            const T = @field(interfaces, decl.name);
            if (@typeInfo(@TypeOf(T)) == .type) {
                if (@hasDecl(T, "Meta")) {
                    const meta = T.Meta;
                    if (@hasDecl(meta, "is_mixin") and !meta.is_mixin) {
                        if (!isSkipped(meta.name)) {
                            count += 1;
                        }
                    }
                }
            }
        }

        // Second pass: build array
        var entries: [count]InterfaceEntry = undefined;
        var idx: usize = 0;

        for (decls) |decl| {
            const T = @field(interfaces, decl.name);
            if (@typeInfo(@TypeOf(T)) == .type) {
                if (@hasDecl(T, "Meta")) {
                    const meta = T.Meta;
                    if (@hasDecl(meta, "is_mixin") and !meta.is_mixin) {
                        if (!isSkipped(meta.name)) {
                            entries[idx] = .{
                                .name = meta.name,
                                .parent_name = getParentName(meta),
                                .is_mixin = false,
                                .is_callback_interface = if (@hasDecl(meta, "is_callback_interface")) meta.is_callback_interface else false,
                                .has_constructor = if (@hasDecl(meta, "has_constructor")) meta.has_constructor else false,
                                .property_count = if (@hasDecl(meta, "properties")) meta.properties.len else 0,
                                .method_count = if (@hasDecl(meta, "methods")) meta.methods.len else 0,
                            };
                            idx += 1;
                        }
                    }
                }
            }
        }

        return &entries;
    }
}

/// Get all mixin interfaces at comptime
pub fn getMixinInterfaces() []const InterfaceEntry {
    @setEvalBranchQuota(100000);
    comptime {
        const decls = @typeInfo(interfaces).@"struct".decls;
        var count: usize = 0;

        // First pass: count mixins
        for (decls) |decl| {
            const T = @field(interfaces, decl.name);
            if (@typeInfo(@TypeOf(T)) == .type) {
                if (@hasDecl(T, "Meta")) {
                    const meta = T.Meta;
                    if (@hasDecl(meta, "is_mixin") and meta.is_mixin) {
                        count += 1;
                    }
                }
            }
        }

        // Second pass: build array
        var entries: [count]InterfaceEntry = undefined;
        var idx: usize = 0;

        for (decls) |decl| {
            const T = @field(interfaces, decl.name);
            if (@typeInfo(@TypeOf(T)) == .type) {
                if (@hasDecl(T, "Meta")) {
                    const meta = T.Meta;
                    if (@hasDecl(meta, "is_mixin") and meta.is_mixin) {
                        entries[idx] = .{
                            .name = meta.name,
                            .parent_name = null, // Mixins don't have parents
                            .is_mixin = true,
                            .is_callback_interface = if (@hasDecl(meta, "is_callback_interface")) meta.is_callback_interface else false,
                            .has_constructor = false, // Mixins never have constructors
                            .property_count = if (@hasDecl(meta, "properties")) meta.properties.len else 0,
                            .method_count = if (@hasDecl(meta, "methods")) meta.methods.len else 0,
                        };
                        idx += 1;
                    }
                }
            }
        }

        return &entries;
    }
}

/// Get all interfaces (including mixins) at comptime
pub fn getAllInterfaces() []const InterfaceEntry {
    @setEvalBranchQuota(100000);
    comptime {
        const decls = @typeInfo(interfaces).@"struct".decls;
        var count: usize = 0;

        // First pass: count all entries with Meta
        for (decls) |decl| {
            const T = @field(interfaces, decl.name);
            if (@typeInfo(@TypeOf(T)) == .type) {
                if (@hasDecl(T, "Meta")) {
                    count += 1;
                }
            }
        }

        // Second pass: build array
        var entries: [count]InterfaceEntry = undefined;
        var idx: usize = 0;

        for (decls) |decl| {
            const T = @field(interfaces, decl.name);
            if (@typeInfo(@TypeOf(T)) == .type) {
                if (@hasDecl(T, "Meta")) {
                    const meta = T.Meta;
                    const is_mixin = if (@hasDecl(meta, "is_mixin")) meta.is_mixin else false;
                    entries[idx] = .{
                        .name = meta.name,
                        .parent_name = if (is_mixin) null else getParentName(meta),
                        .is_mixin = is_mixin,
                        .is_callback_interface = if (@hasDecl(meta, "is_callback_interface")) meta.is_callback_interface else false,
                        .has_constructor = if (@hasDecl(meta, "has_constructor")) meta.has_constructor else false,
                        .property_count = if (@hasDecl(meta, "properties")) meta.properties.len else 0,
                        .method_count = if (@hasDecl(meta, "methods")) meta.methods.len else 0,
                    };
                    idx += 1;
                }
            }
        }

        return &entries;
    }
}

/// Helper to extract parent name from Meta at comptime
fn getParentName(comptime meta: anytype) ?[]const u8 {
    if (@hasDecl(meta, "ParentInterface")) {
        const parent = meta.ParentInterface;
        if (@TypeOf(parent) != @TypeOf(null)) {
            if (@hasDecl(parent, "Meta")) {
                return parent.Meta.name;
            }
        }
    }
    return null;
}

/// Count of all valid (non-mixin, non-skipped) interfaces
pub const valid_interface_count: usize = getValidInterfaces().len;

/// Count of all mixin interfaces
pub const mixin_count: usize = getMixinInterfaces().len;

/// Total count of all interfaces (including mixins)
pub const total_interface_count: usize = getAllInterfaces().len;

/// Find an interface entry by name at comptime
pub fn findInterface(comptime name: []const u8) ?InterfaceEntry {
    @setEvalBranchQuota(100000);
    comptime {
        const all = getAllInterfaces();
        for (all) |entry| {
            if (std.mem.eql(u8, entry.name, name)) {
                return entry;
            }
        }
        return null;
    }
}

/// Check if an interface exists (by name) at comptime
pub fn hasInterface(comptime name: []const u8) bool {
    return findInterface(name) != null;
}

/// Get interfaces that have a specific parent
pub fn getChildInterfaces(comptime parent_name: []const u8) []const InterfaceEntry {
    @setEvalBranchQuota(100000);
    comptime {
        const all = getValidInterfaces();
        var count: usize = 0;

        // First pass: count children
        for (all) |entry| {
            if (entry.parent_name) |p| {
                if (std.mem.eql(u8, p, parent_name)) {
                    count += 1;
                }
            }
        }

        // Second pass: build array
        var children: [count]InterfaceEntry = undefined;
        var idx: usize = 0;

        for (all) |entry| {
            if (entry.parent_name) |p| {
                if (std.mem.eql(u8, p, parent_name)) {
                    children[idx] = entry;
                    idx += 1;
                }
            }
        }

        return &children;
    }
}

/// Get root interfaces (interfaces without a parent)
pub fn getRootInterfaces() []const InterfaceEntry {
    @setEvalBranchQuota(100000);
    comptime {
        const all = getValidInterfaces();
        var count: usize = 0;

        // First pass: count roots
        for (all) |entry| {
            if (entry.parent_name == null) {
                count += 1;
            }
        }

        // Second pass: build array
        var roots: [count]InterfaceEntry = undefined;
        var idx: usize = 0;

        for (all) |entry| {
            if (entry.parent_name == null) {
                roots[idx] = entry;
                idx += 1;
            }
        }

        return &roots;
    }
}

/// Get interfaces with constructors
pub fn getConstructibleInterfaces() []const InterfaceEntry {
    @setEvalBranchQuota(100000);
    comptime {
        const all = getValidInterfaces();
        var count: usize = 0;

        // First pass: count constructible
        for (all) |entry| {
            if (entry.has_constructor) {
                count += 1;
            }
        }

        // Second pass: build array
        var constructible: [count]InterfaceEntry = undefined;
        var idx: usize = 0;

        for (all) |entry| {
            if (entry.has_constructor) {
                constructible[idx] = entry;
                idx += 1;
            }
        }

        return &constructible;
    }
}

// ============================================================================
// Tests
// ============================================================================

test "catalog contains known interfaces" {
    const valid = comptime getValidInterfaces();

    // Check that we have a reasonable number of interfaces
    try std.testing.expect(valid.len > 100);

    // Check for specific known interfaces
    var found_event_target = false;
    var found_node = false;
    var found_element = false;
    var found_document = false;

    for (valid) |entry| {
        if (std.mem.eql(u8, entry.name, "EventTarget")) {
            found_event_target = true;
            try std.testing.expect(entry.parent_name == null);
            try std.testing.expect(!entry.is_mixin);
        }
        if (std.mem.eql(u8, entry.name, "Node")) {
            found_node = true;
            try std.testing.expectEqualStrings("EventTarget", entry.parent_name.?);
            try std.testing.expect(!entry.is_mixin);
        }
        if (std.mem.eql(u8, entry.name, "Element")) {
            found_element = true;
            try std.testing.expectEqualStrings("Node", entry.parent_name.?);
            try std.testing.expect(!entry.is_mixin);
        }
        if (std.mem.eql(u8, entry.name, "Document")) {
            found_document = true;
            try std.testing.expectEqualStrings("Node", entry.parent_name.?);
            try std.testing.expect(!entry.is_mixin);
        }
    }

    try std.testing.expect(found_event_target);
    try std.testing.expect(found_node);
    try std.testing.expect(found_element);
    try std.testing.expect(found_document);
}

test "catalog excludes mixins" {
    const valid = comptime getValidInterfaces();
    const mixins_list = comptime getMixinInterfaces();

    // Ensure no mixins in valid interfaces
    for (valid) |entry| {
        try std.testing.expect(!entry.is_mixin);
    }

    // Ensure mixins list contains only mixins
    for (mixins_list) |entry| {
        try std.testing.expect(entry.is_mixin);
    }

    // Check for known mixins
    var found_aria_mixin = false;
    for (mixins_list) |entry| {
        if (std.mem.eql(u8, entry.name, "ARIAMixin")) {
            found_aria_mixin = true;
        }
    }
    try std.testing.expect(found_aria_mixin);
}

test "findInterface works correctly" {
    const event_target = comptime findInterface("EventTarget");
    try std.testing.expect(event_target != null);
    try std.testing.expectEqualStrings("EventTarget", event_target.?.name);

    const nonexistent = comptime findInterface("NonExistentInterface12345");
    try std.testing.expect(nonexistent == null);
}

test "hasInterface works correctly" {
    try std.testing.expect(comptime hasInterface("EventTarget"));
    try std.testing.expect(comptime hasInterface("Node"));
    try std.testing.expect(comptime hasInterface("Element"));
    try std.testing.expect(!comptime hasInterface("NonExistentInterface12345"));
}

test "getChildInterfaces returns correct children" {
    const node_children = comptime getChildInterfaces("Node");

    // Node should have children (Element, Document, etc.)
    try std.testing.expect(node_children.len > 0);

    // Check that Element is a child of Node
    var found_element = false;
    for (node_children) |child| {
        if (std.mem.eql(u8, child.name, "Element")) {
            found_element = true;
        }
    }
    try std.testing.expect(found_element);
}

test "getRootInterfaces returns interfaces without parents" {
    const roots = comptime getRootInterfaces();

    // Should have some root interfaces
    try std.testing.expect(roots.len > 0);

    // All roots should have null parent
    for (roots) |root| {
        try std.testing.expect(root.parent_name == null);
    }

    // EventTarget should be a root
    var found_event_target = false;
    for (roots) |root| {
        if (std.mem.eql(u8, root.name, "EventTarget")) {
            found_event_target = true;
        }
    }
    try std.testing.expect(found_event_target);
}

test "getConstructibleInterfaces returns constructible interfaces" {
    const constructible = comptime getConstructibleInterfaces();

    // Should have some constructible interfaces
    try std.testing.expect(constructible.len > 0);

    // All should have constructors
    for (constructible) |entry| {
        try std.testing.expect(entry.has_constructor);
    }
}

test "valid_interface_count is correct" {
    try std.testing.expect(valid_interface_count > 100);
    try std.testing.expect(valid_interface_count == getValidInterfaces().len);
}

test "total_interface_count includes mixins" {
    try std.testing.expect(total_interface_count >= valid_interface_count);
    try std.testing.expect(total_interface_count == valid_interface_count + mixin_count);
}
