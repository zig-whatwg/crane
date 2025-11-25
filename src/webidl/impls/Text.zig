//! Implementation for Text interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-text
//! WHATWG DOM Standard §4.12
//!
//! Text represents textual content in the document tree.
//! It extends CharacterData and adds splitText and wholeText.
//!
//! Migrated from: webidl/src/dom/Text.zig

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const infra = @import("infra");
const Text = interfaces.Text;

// Import related impls
const CharacterDataImpl = @import("CharacterData.zig");
const NodeImpl = @import("Node.zig");

// Import DOM algorithms
const dom = @import("dom");

pub const State = Text.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    IndexSizeError,
    OutOfMemory,
};

/// Internal state for Text implementation
/// Text primarily uses CharacterData's data storage via inheritance
/// Additional Text-specific state can be added here
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    // Slottable mixin fields (from DOM spec)
    slottable_name: []const u8,
    assigned_slot: ?*runtime.Instance,
    manual_slot_assignment: ?*runtime.Instance,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .slottable_name = "",
            .assigned_slot = null,
            .manual_slot_assignment = null,
        };
    }

    pub fn deinit(self: *InternalState) void {
        _ = self;
        // slottable_name is usually interned, not owned
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

    // Initialize Text internal state
    const state = instance.getState(StateType);
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
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

/// Constructor implementation
/// DOM §4.12 - Text(data)
/// Creates a new Text node with the given data
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, data: runtime.DOMString) !*runtime.Instance {
    const instance = try init(allocator, State, &Text.vtable, ctx);
    errdefer deinit(instance);

    // Set node type to TEXT_NODE (3)
    try NodeImpl.setNodeType(instance, NodeImpl.NodeType.TEXT_NODE);

    // Set the text data via CharacterData
    try CharacterDataImpl.setData(instance, data.asSlice());

    return instance;
}

// =============================================================================
// Getters - DOM §4.12
// =============================================================================

/// Getter for wholeText
/// DOM §4.12 - Returns the concatenation of the data of all contiguous Text nodes.
///
/// Steps: Return the concatenation of the data of the contiguous Text nodes of this, in tree order.
pub fn get_wholeText(instance: *runtime.Instance) !runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    var result = infra.List(u8).init(internal.allocator);
    errdefer result.deinit();

    // Get our own data first
    if (CharacterDataImpl.getData(instance)) |data| {
        try result.appendSlice(data);
    }

    // TODO: Walk backwards to find first contiguous Text node
    // TODO: Walk forwards collecting all contiguous Text node data
    // This requires access to Node's sibling pointers via inheritance
    // For now, just return our own data

    const owned = try result.toOwnedSlice();
    return runtime.DOMString.initOwned(owned);
}

/// Getter for assignedSlot (from Slottable mixin)
/// https://dom.spec.whatwg.org/#dom-slottable-assignedslot
pub fn get_assignedSlot(instance: *runtime.Instance) !*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.assigned_slot) |slot| {
        return slot;
    }
    return error.NotImplemented; // null
}

// =============================================================================
// Operations - DOM §4.12
// =============================================================================

/// Operation: splitText(offset)
/// DOM §4.12 - Splits this text node at the given offset and returns the remainder as a new Text node.
///
/// Spec: To split a Text node with offset:
/// 1. Let length be node's length.
/// 2. If offset is greater than length, throw "IndexSizeError".
/// 3. Let count be length minus offset.
/// 4. Let new data be the result of substringing data with node, offset, and count.
/// 5. Let new node be a new Text node with same node document. Set new node's data to new data.
/// 6. If parent is not null:
///    6.1. Insert new node into parent before node's next sibling
///    6.2-6.5. Update live ranges
/// 7. Replace data with node, offset, count, and empty string.
/// 8. Return new node.
pub fn call_splitText(instance: *runtime.Instance, offset: u32) !*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: Get length from CharacterData
    const length = try CharacterDataImpl.get_length(instance);

    // Step 2: If offset > length, throw IndexSizeError
    if (offset > length) {
        return error.IndexSizeError;
    }

    // Step 3: count = length - offset
    const count = length - offset;

    // Step 4: Get substring (the data for new node)
    const new_data = try CharacterDataImpl.call_substringData(instance, offset, count);
    defer {
        var nd = new_data;
        nd.deinit(internal.allocator);
    }

    // Step 5: Create new Text node
    // TODO: Get proper context from instance. For now, create minimal instance
    // using init() directly rather than call_constructor
    const new_node = try init(internal.allocator, State, &Text.vtable, undefined);
    errdefer deinit(new_node);

    // Set node type and data on the new node
    try NodeImpl.setNodeType(new_node, NodeImpl.NodeType.TEXT_NODE);
    try CharacterDataImpl.setData(new_node, new_data.asSlice());

    // TODO: Set owner_document from this node

    // Step 6: If parent is not null, insert new node
    // TODO: Access Node's parent via inheritance and call dom.mutation.insert

    // Step 7: Delete the split-off data from this node
    try CharacterDataImpl.call_deleteData(instance, offset, count);

    // Step 8: Return new node
    return new_node;
}

// =============================================================================
// Geometry Mixin Operations (stubs - require CSSOM integration)
// =============================================================================

/// Operation: getBoxQuads (from GeometryUtils mixin)
pub fn call_getBoxQuads(instance: *runtime.Instance, options: dictionaries.BoxQuadOptions) !*const anyopaque {
    _ = instance;
    _ = options;
    // Requires CSSOM/layout integration
    return error.NotImplemented;
}

/// Operation: convertQuadFromNode (from GeometryUtils mixin)
pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: dictionaries.DOMQuadInit, from: typedefs.GeometryNode, options: dictionaries.ConvertCoordinateOptions) !*runtime.Instance {
    _ = instance;
    _ = quad;
    _ = from;
    _ = options;
    return error.NotImplemented;
}

/// Operation: convertRectFromNode (from GeometryUtils mixin)
pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: *runtime.Instance, from: typedefs.GeometryNode, options: dictionaries.ConvertCoordinateOptions) !*runtime.Instance {
    _ = instance;
    _ = rect;
    _ = from;
    _ = options;
    return error.NotImplemented;
}

/// Operation: convertPointFromNode (from GeometryUtils mixin)
pub fn call_convertPointFromNode(instance: *runtime.Instance, point: dictionaries.DOMPointInit, from: typedefs.GeometryNode, options: dictionaries.ConvertCoordinateOptions) !*runtime.Instance {
    _ = instance;
    _ = point;
    _ = from;
    _ = options;
    return error.NotImplemented;
}
