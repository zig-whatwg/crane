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

// Import parent class impl for initialization chain

// Import DOM algorithms from src/dom/
const dom = @import("dom");

// Import mixins for shared interface methods
const mixins = @import("mixins");

pub const State = CharacterData.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    IndexSizeError,
    OutOfMemory,
};

/// Internal state for CharacterData implementation: the node's data. Its
/// type is src/dom's (`dom.character_data.Data`, the small-string storage
/// and the code-unit splice); the state is this node's.
pub const InternalState = dom.character_data.Data;

// Use shared InstanceRegistry utility for internal state management
const webidl = @import("webidl");
const Registry = runtime.InstanceRegistry(.character_data, InternalState);

/// Get the internal state from an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// What a CharacterData node is given at construction (`initWith`): its
/// data. Text(data), Comment(data), document.createTextNode and
/// createProcessingInstruction make a node with its data, as WebKit's
/// `Text::create(document, data)` passes it to CharacterData's constructor;
/// none runs "replace data" on a node no one can observe yet. Made with no
/// arguments, a node's data is the empty string.
pub const construction_args = .{"data"};

/// CharacterData's own construction steps: the generated chain runs Node's first.
///
/// IMPORTANT: Due to state hierarchy complexity, internal state is stored
/// in a global registry rather than in the State struct.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    // Initialize CharacterData internal state in global registry
    // The registry owns this block, so `Registry.remove` returns it to the
    // arena. With `set` it was dropped from the map and held to process
    // exit - 904 bytes per discarded element, measured.
    const internal = try Registry.createIn(instance, runtime.arenaOf(instance));
    internal.* = try InternalState.init(allocator);
    if (@hasField(@TypeOf(args), "data")) {
        errdefer deinitOwn(instance);
        try internal.setData(args.data);
    }
}

/// Get CharacterData's internal state from the registry
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// CharacterData's own teardown: the generated chain runs Node's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    // Clean up from registry
    if (Registry.get(instance)) |internal| {
        internal.deinit();
    }
    Registry.remove(instance);
}

// =============================================================================
// Getters - DOM §4.11
// =============================================================================

/// Getter for data
/// DOM §4.11 - Returns this's data.
pub fn get_data(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clone data to transfer ownership to caller (interface layer will free)
    return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.getData());
}

/// Getter for length
/// DOM §4.11 - Returns this's length (number of code units).
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.getLength();
}

// =============================================================================
// Setters - DOM §4.11
// =============================================================================

/// Setter for data
/// DOM §4.11 - Replace data with node this, offset 0, count this's length, and data new value.
pub fn set_data(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const new_value = value.asSlice();
    try replaceDataInternal(instance, internal, 0, internal.getLength(), new_value);
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
pub fn call_substringData(instance: *runtime.Instance, offset: u32, count: u32) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Step 1: "Let length be node's length" - code units.
    const length = internal.getLength();

    // Step 2: Check bounds
    if (offset > length) {
        return error.IndexSizeError;
    }

    // IMPORTANT: Use instance.ctx.allocator for returned DOMStrings
    // The V8 callback will free returned strings using instance.ctx.allocator
    const allocator = instance.ctx.allocator;

    // Step 3: "If offset plus count is greater than length, return a string
    // whose value is the code units from the offsetth code unit to the end."
    // Compared as a difference: offset plus a count near 2^32 wraps.
    // Step 4: otherwise the code units from offset to offset + count. A pair
    // cut at either end leaves its surrogate (infra.wtf8).
    const clamped = @min(count, length - offset);
    if (clamped == 0) return runtime.DOMString.initEmpty();
    return runtime.DOMString.initOwned(try internal.substring(allocator, offset, clamped));
}

/// Operation: appendData(data)
/// DOM §4.11 - Appends data to this's data.
///
/// Steps: Replace data with node this, offset this's length, count 0, and data.
pub fn call_appendData(instance: *runtime.Instance, data: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try replaceDataInternal(instance, internal, internal.getLength(), 0, data.asSlice());
}

/// Operation: insertData(offset, data)
/// DOM §4.11 - Inserts data at the given offset.
///
/// Steps: Replace data with node this, offset, count 0, and data.
pub fn call_insertData(instance: *runtime.Instance, offset: u32, data: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try replaceDataInternal(instance, internal, offset, 0, data.asSlice());
}

/// Operation: deleteData(offset, count)
/// DOM §4.11 - Deletes count code units starting at offset.
///
/// Steps: Replace data with node this, offset, count, and empty string.
pub fn call_deleteData(instance: *runtime.Instance, offset: u32, count: u32) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try replaceDataInternal(instance, internal, offset, count, "");
}

/// Operation: replaceData(offset, count, data)
/// DOM §4.11 - Replaces count code units at offset with data.
pub fn call_replaceData(instance: *runtime.Instance, offset: u32, count: u32, data: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try replaceDataInternal(instance, internal, offset, count, data.asSlice());
}

// =============================================================================
// ChildNode Mixin Operations
// =============================================================================

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
/// 12. Update a ProcessingInstruction's attributes unless already updated.
/// 13. If node's parent is non-null, run its parent's children changed steps.
fn replaceDataInternal(instance: *runtime.Instance, internal: *InternalState, offset: u32, count_param: u32, data: []const u8) !void {
    const length = internal.getLength();

    // Step 2: Check bounds
    if (offset > length) {
        return error.IndexSizeError;
    }

    // Step 3: "If offset + count is greater than length, then set count to
    // length - offset." Compared as a difference: offset plus a count near
    // 2^32 wraps.
    const count = @min(count_param, length - offset);

    // Step 4: "Queue a mutation record of "characterData" for node with
    // null, null, node's data, « », « », null, and null." Before step 5
    // changes the data: the record copies it.
    try dom.mutation_observer_algorithms.queueCharacterDataMutationRecord(instance, internal.getData());

    // Steps 5-7: insert data after offset code units, then remove count
    // code units from offset + data's length - one splice, which handles
    // inline vs heap storage, and a pair cut or completed at either seam.
    if (data.len > std.math.maxInt(u32)) return error.OutOfMemory;
    const data_units: u32 = @intCast(infra.wtf8.codeUnitLength(data));
    try internal.replaceDataUnits(offset, count, data, data_units);
    // The node document's DOM tree version moves with the data, parent or
    // none (Blink CharacterData::SetDataAndUpdate, WebKit
    // CharacterData::notifyParentAfterChange): an XPath iterator over the
    // document is invalid from here on, as DOM Level 3 XPath says of any
    // mutation of the document.
    dom.refcount.characterDataChanged(instance);

    // Steps 8-11: the live ranges whose boundary points are in node, moved
    // by data's length in code units.
    dom.mutation.runLiveRangeReplaceDataSteps(instance, offset, count, data_units);

    // Step 12: only a PI updates attributes from data. A brand check leaves
    // ordinary Text/Comment mutation without parsing or map allocation.
    if (instance.stateAs(interfaces.ProcessingInstruction.State) != null)
        dom.character_data.processingInstructionDataChanged(instance);

    // Step 13: "If node's parent is non-null, then run the children changed
    // steps for node's parent."
    if (interfaces.Node.get_parentNode(instance) catch null) |parent| {
        if (dom.instance_bridge.getNodeBase(@ptrCast(parent))) |parent_base| {
            dom.mutation.runChildrenChangedSteps(parent_base);
        }
    }
}

// =============================================================================
// Helper Functions
// =============================================================================

/// dom.character_data: `node`'s data, borrowed until it next changes, or
/// null when `node` has no CharacterData state.
fn dataOf(node: *runtime.Instance) ?[]const u8 {
    const internal = getInternal(node) orelse return null;
    return internal.getData();
}

/// Get the length of the data (number of code units)
pub fn getDataLength(instance: *runtime.Instance) u32 {
    const internal = getInternal(instance) orelse return 0;
    return internal.getLength();
}

/// Delete a range of data (used by Range.deleteContents)
pub fn deleteDataRange(instance: *runtime.Instance, offset: u32, count: u32) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try replaceDataInternal(instance, internal, offset, count, "");
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // Its states left at its Browser's end (Browser.deinit).
    @import("dom").teardown_sweeps.install(.character_data, &sweepRemaining);
    // Its data, read in place by the tree's own algorithms (textContent,
    // nodeValue, isEqualNode, an option's text).
    @import("dom").character_data.install(.{ .data_of = &dataOf });
}

/// dom.teardown_sweeps: at its Browser's end, every CharacterData state still in
/// `scope`'s table - an orphan's no teardown reached - frees what it owns.
fn sweepRemaining(scope: *runtime.BrowserScope) void {
    Registry.deinitAllAndClear(scope);
}
