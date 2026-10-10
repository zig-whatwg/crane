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
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const MutationRecord = interfaces.MutationRecord;
const dom = @import("dom");
const node_holds = dom.node_holds;

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
///
/// The record HOLDS every node it names - its target, its two siblings, its
/// added and removed nodes - for as long as it lives: queued in an
/// observer's record queue, delivered, or taken. Blink's MutationRecord
/// holds them natively (core/dom/mutation_record.cc: ChildListRecord traces
/// target_, added_nodes_, removed_nodes_, previous_sibling_, next_sibling_)
/// and makes no wrapper until script reads one; so does this one
/// (src/dom/node_holds.zig): a hold per node, and one rescued wrapper - an
/// edge from the record's - for the root of a tree that is not a document
/// with a window. A record is unwrapped while it waits in a record queue, so
/// such an edge waits, holding its root strongly, in its realm's wrapper
/// cache until the record is wrapped (delivery, takeRecords()), or until the
/// record is freed unwrapped (disconnect(), the observer's teardown).
/// Held as bare pointers, a removed node script let go was freed by the next
/// collection and the record answered from its freed or reissued slot
/// (crane/ed-mutation-record-nodes-gc.html).
///
/// Its NodeLists are made when script first reads one - Blink's
/// RecordWithEmptyNodeLists makes its empty ones lazily; here every record
/// does - each a static list of the nodes the record holds, which holds them
/// too and belongs to its wrapper from then on. A record script never reads
/// makes none.
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// Type of mutation: "attributes", "characterData", or "childList"
    mutation_type: []const u8,

    /// The held nodes: target, previousSibling, nextSibling (null holds
    /// nothing), then the added nodes, then the removed nodes.
    held: node_holds.Holder,
    added_count: usize = 0,
    removed_count: usize = 0,

    /// Name of changed attribute (for attribute mutations)
    attribute_name: ?[]const u8,

    /// Namespace of changed attribute (for attribute mutations)
    attribute_namespace: ?[]const u8,

    /// Old value (for attribute or characterData mutations, if requested)
    old_value: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator, record: *runtime.Instance) InternalState {
        return .{
            .allocator = allocator,
            .mutation_type = "",
            .held = node_holds.Holder.init(allocator, record),
            .attribute_name = null,
            .attribute_namespace = null,
            .old_value = null,
        };
    }

    pub fn deinit(self: *InternalState) void {
        // The nodes go with the holds; a NodeList script read is its
        // wrapper's. `mutation_type` is a literal. The attribute strings are
        // this record's own copies: `create` took them.
        self.held.release();
        if (self.attribute_name) |name| self.allocator.free(name);
        if (self.attribute_namespace) |ns| self.allocator.free(ns);
        if (self.old_value) |value| self.allocator.free(value);
    }

    const target_index = 0;
    const previous_index = 1;
    const next_index = 2;
    const nodes_from = 3;
};

/// A record holds its nodes; the removing steps rescue a held tree. Installed
/// once, at process start (docs/instances.md "Hooks").
pub fn installHooks() void {
    node_holds.installHooks();
}

/// Helper to access internal state from instance
/// Get internal state from instance using shared accessor (pointer cast variant)
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) *InternalState {
    return Accessor.getCast(instance);
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
    internal.* = InternalState.init(allocator, instance);

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
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

// ============================================================================
// Factory function for creating MutationRecords
// ============================================================================

/// Create a new MutationRecord with all fields set, holding every node it
/// names. Used by mutation observation algorithms ("queue a mutation record"
/// step 4.1).
pub fn create(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    mutation_type: []const u8,
    target: *runtime.Instance,
    added_nodes: []const *runtime.Instance,
    removed_nodes: []const *runtime.Instance,
    previous_sibling: ?*runtime.Instance,
    next_sibling: ?*runtime.Instance,
    attribute_name: ?[]const u8,
    attribute_namespace: ?[]const u8,
    old_value: ?[]const u8,
) !*runtime.Instance {
    const instance = try init(allocator, State, &MutationRecord.vtable, ctx);
    errdefer deinit(instance);

    // The strings are copied: an attribute's name and old value belong to
    // its element, which frees them as soon as the change that queued this
    // record is done - long before an observer reads them.
    const name_copy: ?[]const u8 = if (attribute_name) |n| try allocator.dupe(u8, n) else null;
    errdefer if (name_copy) |n| allocator.free(n);
    const namespace_copy: ?[]const u8 = if (attribute_namespace) |ns| try allocator.dupe(u8, ns) else null;
    errdefer if (namespace_copy) |ns| allocator.free(ns);
    const old_value_copy: ?[]const u8 = if (old_value) |v| try allocator.dupe(u8, v) else null;

    errdefer if (old_value_copy) |v| allocator.free(v);

    const internal = getInternal(instance);
    internal.mutation_type = mutation_type;

    // Everything it names is held from now: the record is queued
    // unwrapped, and script may let every node in it go before it is
    // delivered.
    const count = InternalState.nodes_from + added_nodes.len + removed_nodes.len;
    var fixed: [16]?*runtime.Instance = undefined;
    const nodes = if (count <= fixed.len) fixed[0..count] else try allocator.alloc(?*runtime.Instance, count);
    defer if (count > fixed.len) allocator.free(nodes);
    nodes[InternalState.target_index] = target;
    nodes[InternalState.previous_index] = previous_sibling;
    nodes[InternalState.next_index] = next_sibling;
    for (added_nodes, 0..) |node, i| nodes[InternalState.nodes_from + i] = node;
    for (removed_nodes, 0..) |node, i| nodes[InternalState.nodes_from + added_nodes.len + i] = node;
    try internal.held.hold(?*runtime.Instance, nodes, null);
    internal.added_count = added_nodes.len;
    internal.removed_count = removed_nodes.len;

    internal.attribute_name = name_copy;
    internal.attribute_namespace = namespace_copy;
    internal.old_value = old_value_copy;

    return instance;
}

// ============================================================================
// Getters
// ============================================================================

/// DOM §7.2 - MutationRecord.type
/// Returns "attributes", "characterData", or "childList"
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance);
    return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.mutation_type);
}

/// DOM §7.2 - MutationRecord.target
/// Returns the node that was mutated
pub fn get_target(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance);
    // Null only once a realm's end freed the node: a teardown net.
    return internal.held.get(InternalState.target_index) orelse error.InvalidStateError;
}

/// DOM §7.2 - MutationRecord.addedNodes
/// Returns the list of added nodes: made on this first read ([SameObject]:
/// the generated interface caches it) from the nodes the record holds.
pub fn get_addedNodes(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance);
    return makeList(instance, InternalState.nodes_from, internal.added_count);
}

/// DOM §7.2 - MutationRecord.removedNodes
/// Returns the list of removed nodes, made as `addedNodes` is.
pub fn get_removedNodes(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance);
    return makeList(instance, InternalState.nodes_from + internal.added_count, internal.removed_count);
}

/// A static NodeList of the `count` held nodes from hold `from`, which
/// holds them itself: the binding wraps it at once and ties it to this
/// record both ways ([SameObject]), and it belongs to its wrapper from then
/// on.
fn makeList(record: *runtime.Instance, from: usize, count: usize) !*runtime.Instance {
    const internal = getInternal(record);
    const allocator = internal.allocator;
    var fixed: [8]*runtime.Instance = undefined;
    const buffer = if (count <= fixed.len) fixed[0..count] else try allocator.alloc(*runtime.Instance, count);
    defer if (count > fixed.len) allocator.free(buffer);
    var len: usize = 0;
    for (from..from + count) |index| {
        // A node a realm's end freed is left out (a teardown net).
        buffer[len] = internal.held.get(index) orelse continue;
        len += 1;
    }
    const list = try interfaces.NodeList.init(record.ctx.allocator, record.ctx);
    errdefer runtime.Instance.deinit(list);
    try dom.node_lists.setStatic(list, buffer[0..len]);
    return list;
}

/// DOM §7.2 - MutationRecord.previousSibling
/// Returns the previous sibling of added/removed nodes
/// Note: Generated interface expects non-nullable but WebIDL says nullable
pub fn get_previousSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance);
    return internal.held.get(InternalState.previous_index);
}

/// DOM §7.2 - MutationRecord.nextSibling
/// Returns the next sibling of added/removed nodes
/// Note: Generated interface expects non-nullable but WebIDL says nullable
pub fn get_nextSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance);
    return internal.held.get(InternalState.next_index);
}

/// DOM §7.2 - MutationRecord.attributeName
/// Returns the name of the changed attribute (null if not attribute mutation)
/// Note: Generated interface expects non-nullable but WebIDL says nullable
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_attributeName(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const internal = getInternal(instance);
    if (internal.attribute_name) |name| {
        return try runtime.DOMString.initDupe(instance.ctx.allocator, name);
    }
    return null;
}

/// DOM §7.2 - MutationRecord.attributeNamespace
/// Returns the namespace of the changed attribute (null if not attribute mutation)
/// Note: Generated interface expects non-nullable but WebIDL says nullable
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_attributeNamespace(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const internal = getInternal(instance);
    if (internal.attribute_namespace) |ns| {
        return try runtime.DOMString.initDupe(instance.ctx.allocator, ns);
    }
    return null;
}

/// DOM §7.2 - MutationRecord.oldValue
/// Returns the old value (for attributes/characterData, null otherwise)
/// Note: Generated interface expects non-nullable but WebIDL says nullable
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_oldValue(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const internal = getInternal(instance);
    if (internal.old_value) |value| {
        return try runtime.DOMString.initDupe(instance.ctx.allocator, value);
    }
    return null;
}
