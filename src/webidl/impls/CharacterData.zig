//! Implementation for CharacterData interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-characterdata
//! WHATWG DOM Standard §4.10
//!
//! CharacterData is an abstract interface that Text, Comment, CDATASection,
//! and ProcessingInstruction all inherit. It provides access to the textual
//! content through the `data` attribute and string manipulation methods.
//!
//! Migrated from: webidl/src/dom/CharacterData.zig

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const infra = @import("infra");
const CharacterData = interfaces.CharacterData;

// Import DOM algorithms from src/dom/
const dom = @import("dom");

// Import mixins for shared interface methods
const mixins = @import("mixins");
const NonDocumentTypeChildNode = mixins.NonDocumentTypeChildNode;

pub const State = CharacterData.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    IndexSizeError,
    OutOfMemory,
};

/// Internal state for CharacterData implementation
/// Stores the mutable string data associated with this node
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The mutable string data associated with this node
    /// This is the primary storage for Text, Comment, CDATA, PI content
    data: []u8,

    pub fn init(allocator: std.mem.Allocator) !InternalState {
        return .{
            .allocator = allocator,
            .data = try allocator.dupe(u8, ""),
        };
    }

    pub fn deinit(self: *InternalState) void {
        self.allocator.free(self.data);
    }
};

/// Get the internal state from an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
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

    // Initialize CharacterData internal state
    const state = instance.getState(StateType);
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = try InternalState.init(allocator);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    runtime.Instance.deinit(instance);
}

// =============================================================================
// Getters - DOM §4.11
// =============================================================================

/// Getter for data
/// DOM §4.11 - Returns this's data.
pub fn get_data(instance: *runtime.Instance) !runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return runtime.DOMString.initInterned(internal.data);
}

/// Getter for length
/// DOM §4.11 - Returns this's length (number of code units).
pub fn get_length(instance: *runtime.Instance) !u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return @intCast(internal.data.len);
}

/// Getter for previousElementSibling (from NonDocumentTypeChildNode mixin)
/// Spec: https://dom.spec.whatwg.org/#dom-nondocumenttypechildnode-previouselementsibling
pub fn get_previousElementSibling(instance: *runtime.Instance) ImplError!*runtime.Instance {
    return NonDocumentTypeChildNode.previousElementSibling(instance) orelse error.NotImplemented;
}

/// Getter for nextElementSibling (from NonDocumentTypeChildNode mixin)
/// Spec: https://dom.spec.whatwg.org/#dom-nondocumenttypechildnode-nextelementsibling
pub fn get_nextElementSibling(instance: *runtime.Instance) ImplError!*runtime.Instance {
    return NonDocumentTypeChildNode.nextElementSibling(instance) orelse error.NotImplemented;
}

// =============================================================================
// Setters - DOM §4.11
// =============================================================================

/// Setter for data
/// DOM §4.11 - Replace data with node this, offset 0, count this's length, and data new value.
pub fn set_data(instance: *runtime.Instance, value: runtime.DOMString) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const new_value = value.asSlice();
    try replaceDataInternal(instance, internal, 0, @intCast(internal.data.len), new_value);
}

// =============================================================================
// Operations - DOM §4.11
// =============================================================================

/// Operation: substringData(offset, count)
/// DOM §4.11 - Returns a substring of this's data.
///
/// Steps:
/// 1. Let length be node's length.
/// 2. If offset is greater than length, then throw an "IndexSizeError" DOMException.
/// 3. If offset plus count is greater than length, return code units from offset to end.
/// 4. Return code units from offset to offset+count.
pub fn call_substringData(instance: *runtime.Instance, offset: u32, count: u32) !runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const length: u32 = @intCast(internal.data.len);

    // Step 2: Check bounds
    if (offset > length) {
        return error.IndexSizeError;
    }

    // Step 3: Handle overflow - return from offset to end
    if (offset + count > length) {
        return runtime.DOMString.initDupe(internal.allocator, internal.data[offset..]);
    }

    // Step 4: Return substring
    return runtime.DOMString.initDupe(internal.allocator, internal.data[offset .. offset + count]);
}

/// Operation: appendData(data)
/// DOM §4.11 - Appends data to this's data.
///
/// Steps: Replace data with node this, offset this's length, count 0, and data.
pub fn call_appendData(instance: *runtime.Instance, data: runtime.DOMString) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try replaceDataInternal(instance, internal, @intCast(internal.data.len), 0, data.asSlice());
}

/// Operation: insertData(offset, data)
/// DOM §4.11 - Inserts data at the given offset.
///
/// Steps: Replace data with node this, offset, count 0, and data.
pub fn call_insertData(instance: *runtime.Instance, offset: u32, data: runtime.DOMString) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try replaceDataInternal(instance, internal, offset, 0, data.asSlice());
}

/// Operation: deleteData(offset, count)
/// DOM §4.11 - Deletes count code units starting at offset.
///
/// Steps: Replace data with node this, offset, count, and empty string.
pub fn call_deleteData(instance: *runtime.Instance, offset: u32, count: u32) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try replaceDataInternal(instance, internal, offset, count, "");
}

/// Operation: replaceData(offset, count, data)
/// DOM §4.11 - Replaces count code units at offset with data.
pub fn call_replaceData(instance: *runtime.Instance, offset: u32, count: u32, data: runtime.DOMString) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try replaceDataInternal(instance, internal, offset, count, data.asSlice());
}

// =============================================================================
// ChildNode Mixin Operations
// =============================================================================

/// Operation: remove (from ChildNode mixin)
/// https://dom.spec.whatwg.org/#dom-childnode-remove
pub fn call_remove(instance: *runtime.Instance) !void {
    _ = instance;
    // TODO: Remove this node from its parent using dom.mutation algorithms
    return error.NotImplemented;
}

/// Operation: before (from ChildNode mixin)
/// https://dom.spec.whatwg.org/#dom-childnode-before
pub fn call_before(instance: *runtime.Instance, nodes: *const anyopaque) !void {
    _ = instance;
    _ = nodes;
    // TODO: Insert nodes before this node
    return error.NotImplemented;
}

/// Operation: after (from ChildNode mixin)
/// https://dom.spec.whatwg.org/#dom-childnode-after
pub fn call_after(instance: *runtime.Instance, nodes: *const anyopaque) !void {
    _ = instance;
    _ = nodes;
    // TODO: Insert nodes after this node
    return error.NotImplemented;
}

/// Operation: replaceWith (from ChildNode mixin)
/// https://dom.spec.whatwg.org/#dom-childnode-replacewith
pub fn call_replaceWith(instance: *runtime.Instance, nodes: *const anyopaque) !void {
    _ = instance;
    _ = nodes;
    // TODO: Replace this node with nodes
    return error.NotImplemented;
}

// =============================================================================
// Internal Implementation - DOM §4.11 Replace Data Algorithm
// =============================================================================

/// Internal replace data implementation
/// DOM §4.11 - To replace data of node with offset, count, and data:
///
/// 1. Let length be node's length.
/// 2. If offset is greater than length, then throw an "IndexSizeError" DOMException.
/// 3. If offset plus count is greater than length, set count to length − offset.
/// 4. Queue a mutation record of "characterData" for node with null, null, node's data, « », « », null, and null.
/// 5. Insert data into node's data after offset code units.
/// 6. Let delete offset be offset + data's length.
/// 7. Remove count code units from node's data, starting at delete offset.
/// 8-11. For each live range whose start/end node is node, update start/end offset.
/// 12. If node's parent is non-null, then run the children changed steps for node's parent.
fn replaceDataInternal(instance: *runtime.Instance, internal: *InternalState, offset: u32, count_param: u32, data: []const u8) !void {
    const length: u32 = @intCast(internal.data.len);
    var count = count_param;

    // Step 2: Check bounds
    if (offset > length) {
        return error.IndexSizeError;
    }

    // Step 3: Clamp count
    if (offset + count > length) {
        count = length - offset;
    }

    // Step 4: Queue mutation record
    // TODO: Call dom.mutation_observer_algorithms.queueMutationRecord
    // This requires converting runtime.Instance to the Node type expected by the algorithm
    // For now, skip mutation observer notification until type bridge is established

    // Steps 5-7: Build new data string
    const new_len = length - count + @as(u32, @intCast(data.len));
    const new_data = try internal.allocator.alloc(u8, new_len);
    errdefer internal.allocator.free(new_data);

    // Copy before offset
    @memcpy(new_data[0..offset], internal.data[0..offset]);

    // Copy new data
    @memcpy(new_data[offset .. offset + data.len], data);

    // Copy after deleted region
    const after_start = offset + count;
    if (after_start < length) {
        @memcpy(new_data[offset + data.len ..], internal.data[after_start..]);
    }

    // Replace old data
    internal.allocator.free(internal.data);
    internal.data = new_data;

    // Steps 8-11: Update live ranges
    // TODO: Call dom.range_tracking.updateRangesAfterReplace
    // This requires access to owner_document from Node's inherited state
    _ = instance;

    // Step 12: Run children changed steps for parent
    // TODO: Call dom.mutation.runChildrenChangedSteps
    // This requires access to parent_node from Node's inherited state
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Set the data directly (used by Text, Comment constructors)
pub fn setData(instance: *runtime.Instance, data: []const u8) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Free old data
    internal.allocator.free(internal.data);

    // Allocate and copy new data
    internal.data = try internal.allocator.dupe(u8, data);
}

/// Get the data directly as a slice
/// Returns null if instance has no internal state
pub fn getData(instance: *runtime.Instance) ?[]const u8 {
    const internal = getInternal(instance) orelse return null;
    return internal.data;
}

/// Get the length of the data (number of code units)
pub fn getDataLength(instance: *runtime.Instance) u32 {
    const internal = getInternal(instance) orelse return 0;
    return @intCast(internal.data.len);
}

/// Delete a range of data (used by Range.deleteContents)
pub fn deleteDataRange(instance: *runtime.Instance, offset: u32, count: u32) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try replaceDataInternal(instance, internal, offset, count, "");
}
