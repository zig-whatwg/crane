//! Implementation for MutationRecord interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-mutationrecord
//! WHATWG DOM Standard §7.2
//!
//! MutationRecord objects represent individual DOM mutations.
//! They are created by the MutationObserver API and contain information
//! about what changed in the tree.
//!
//! Migrated from: webidl/src/dom/MutationRecord.zig

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const MutationRecord = interfaces.MutationRecord;

pub const State = MutationRecord.State;

pub const ImplError = error{
    NotImplemented,
    OutOfMemory,
};

/// Mutation type constants
pub const TYPE_ATTRIBUTES: []const u8 = "attributes";
pub const TYPE_CHARACTER_DATA: []const u8 = "characterData";
pub const TYPE_CHILD_LIST: []const u8 = "childList";

/// Internal state for MutationRecord
/// Spec: https://dom.spec.whatwg.org/#mutationrecord
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// Type of mutation: "attributes", "characterData", or "childList"
    mutation_type: []const u8,

    /// The node that was mutated
    target: ?*runtime.Instance,

    /// Nodes added (for childList mutations)
    /// This is a NodeList instance
    added_nodes: ?*runtime.Instance,

    /// Nodes removed (for childList mutations)
    /// This is a NodeList instance
    removed_nodes: ?*runtime.Instance,

    /// Previous sibling of added/removed nodes
    previous_sibling: ?*runtime.Instance,

    /// Next sibling of added/removed nodes
    next_sibling: ?*runtime.Instance,

    /// Name of changed attribute (for attribute mutations)
    attribute_name: ?[]const u8,

    /// Namespace of changed attribute (for attribute mutations)
    attribute_namespace: ?[]const u8,

    /// Old value (for attribute or characterData mutations, if requested)
    old_value: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .mutation_type = "",
            .target = null,
            .added_nodes = null,
            .removed_nodes = null,
            .previous_sibling = null,
            .next_sibling = null,
            .attribute_name = null,
            .attribute_namespace = null,
            .old_value = null,
        };
    }

    pub fn deinit(self: *InternalState) void {
        // NodeLists and Nodes are owned elsewhere, we don't free them
        // Strings (mutation_type, attribute_name, etc.) may need freeing
        // depending on how they're allocated
        _ = self;
    }
};

/// Helper to access internal state from instance
fn getInternal(instance: *runtime.Instance) *InternalState {
    const state = instance.getState(State);
    return @ptrCast(@alignCast(state.own._internal));
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Initialize internal state
    const internal = try allocator.create(InternalState);
    internal.* = InternalState.init(allocator);

    // Store internal state in instance
    const state = instance.getState(State);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal_ptr| {
        const internal: *InternalState = @ptrCast(@alignCast(internal_ptr));
        internal.deinit();
        internal.allocator.destroy(internal);
    }
    runtime.Instance.deinit(instance);
}

// ============================================================================
// Factory function for creating MutationRecords
// ============================================================================

/// Create a new MutationRecord with all fields set
/// Used by mutation observation algorithms
pub fn create(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    mutation_type: []const u8,
    target: *runtime.Instance,
    added_nodes: ?*runtime.Instance,
    removed_nodes: ?*runtime.Instance,
    previous_sibling: ?*runtime.Instance,
    next_sibling: ?*runtime.Instance,
    attribute_name: ?[]const u8,
    attribute_namespace: ?[]const u8,
    old_value: ?[]const u8,
) !*runtime.Instance {
    const instance = try init(allocator, State, &MutationRecord.vtable, ctx);
    errdefer deinit(instance);

    const internal = getInternal(instance);
    internal.mutation_type = mutation_type;
    internal.target = target;
    internal.added_nodes = added_nodes;
    internal.removed_nodes = removed_nodes;
    internal.previous_sibling = previous_sibling;
    internal.next_sibling = next_sibling;
    internal.attribute_name = attribute_name;
    internal.attribute_namespace = attribute_namespace;
    internal.old_value = old_value;

    return instance;
}

// ============================================================================
// Getters
// ============================================================================

/// DOM §7.2 - MutationRecord.type
/// Returns "attributes", "characterData", or "childList"
pub fn get_type(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance);
    return runtime.DOMString.initInterned(internal.mutation_type);
}

/// DOM §7.2 - MutationRecord.target
/// Returns the node that was mutated
pub fn get_target(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const internal = getInternal(instance);
    return internal.target orelse return error.NotImplemented;
}

/// DOM §7.2 - MutationRecord.addedNodes
/// Returns the list of added nodes
pub fn get_addedNodes(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const internal = getInternal(instance);
    return internal.added_nodes orelse return error.NotImplemented;
}

/// DOM §7.2 - MutationRecord.removedNodes
/// Returns the list of removed nodes
pub fn get_removedNodes(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const internal = getInternal(instance);
    return internal.removed_nodes orelse return error.NotImplemented;
}

/// DOM §7.2 - MutationRecord.previousSibling
/// Returns the previous sibling of added/removed nodes
/// Note: Generated interface expects non-nullable but WebIDL says nullable
pub fn get_previousSibling(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const internal = getInternal(instance);
    return internal.previous_sibling orelse return error.NotImplemented;
}

/// DOM §7.2 - MutationRecord.nextSibling
/// Returns the next sibling of added/removed nodes
/// Note: Generated interface expects non-nullable but WebIDL says nullable
pub fn get_nextSibling(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const internal = getInternal(instance);
    return internal.next_sibling orelse return error.NotImplemented;
}

/// DOM §7.2 - MutationRecord.attributeName
/// Returns the name of the changed attribute (null if not attribute mutation)
/// Note: Generated interface expects non-nullable but WebIDL says nullable
pub fn get_attributeName(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance);
    if (internal.attribute_name) |name| {
        return runtime.DOMString.initInterned(name);
    }
    return runtime.DOMString.initEmpty();
}

/// DOM §7.2 - MutationRecord.attributeNamespace
/// Returns the namespace of the changed attribute (null if not attribute mutation)
/// Note: Generated interface expects non-nullable but WebIDL says nullable
pub fn get_attributeNamespace(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance);
    if (internal.attribute_namespace) |ns| {
        return runtime.DOMString.initInterned(ns);
    }
    return runtime.DOMString.initEmpty();
}

/// DOM §7.2 - MutationRecord.oldValue
/// Returns the old value (for attributes/characterData, null otherwise)
/// Note: Generated interface expects non-nullable but WebIDL says nullable
pub fn get_oldValue(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance);
    if (internal.old_value) |value| {
        return runtime.DOMString.initInterned(value);
    }
    return runtime.DOMString.initEmpty();
}
