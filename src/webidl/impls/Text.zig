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
const webidl = @import("webidl");
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

/// Static sentinel for representing "undefined" return values.
/// Used instead of null to provide a valid pointer that represents
/// undefined/empty results from operations that return *const anyopaque.
var undefined_sentinel: u8 = 0;

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

// Use shared InstanceRegistry utility for internal state management
const utils = @import("webidl").utils;
const Registry = utils.InstanceRegistry(InternalState);

/// Get the internal state from an instance
/// Made public for use by HTMLParser and other modules that need text content
pub fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// Initialize instance (creates the instance)
/// Chains to parent class initialization: CharacterData -> Node -> EventTarget
///
/// IMPORTANT: Due to state hierarchy complexity, internal state is stored
/// in a global registry rather than in the State struct.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain to parent class (CharacterData) which chains to Node -> EventTarget
    const instance = try CharacterDataImpl.init(allocator, StateType, vtable, ctx);
    errdefer CharacterDataImpl.deinit(instance);

    // Initialize Text internal state in global registry
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    try Registry.set(instance, internal);

    return instance;
}

/// Get Text's internal state from the registry
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up from registry
    if (Registry.get(instance)) |internal| {
        internal.deinit();
    }
    Registry.remove(instance);
    // CharacterData cleanup happens via inheritance chain
    CharacterDataImpl.deinit(instance);
}

/// Constructor implementation
/// DOM §4.12 - Text(data)
/// Creates a new Text node with the given data
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, data: webidl.Opt(runtime.DOMString)) !*runtime.Instance {
    const instance = try init(allocator, State, &Text.vtable, ctx);
    errdefer deinit(instance);

    // Set node type to TEXT_NODE (3)
    try NodeImpl.setNodeType(instance, NodeImpl.NodeType.TEXT_NODE);

    // Set the text data via CharacterData
    const data_slice = if (data.was_passed) data.value.asSlice() else "";
    try CharacterDataImpl.setData(instance, data_slice);

    return instance;
}

// =============================================================================
// Getters - DOM §4.12
// =============================================================================

/// Getter for wholeText
/// DOM §4.12 - Returns the concatenation of the data of all contiguous Text nodes.
///
/// Steps: Return the concatenation of the data of the contiguous Text nodes of this, in tree order.
///
/// A contiguous Text node is a Text node whose previous sibling is also a Text node,
/// and the chain continues until we find a non-Text node or the start of the parent.
pub fn get_wholeText(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = getInternal(instance) orelse return error.InvalidStateError;

    // IMPORTANT: Use instance.ctx.allocator for returned DOMStrings
    // The V8 property getter callback will free returned strings using instance.ctx.allocator
    var result = infra.List(u8).init(instance.ctx.allocator);
    errdefer result.deinit();

    // Step 1: Walk backwards to find the first contiguous Text node
    var first: *runtime.Instance = instance;
    while (NodeImpl.getPreviousSibling(first)) |prev| {
        const prev_type = NodeImpl.getNodeType(prev) orelse break;
        if (prev_type != NodeImpl.NodeType.TEXT_NODE) break;
        first = prev;
    }

    // Step 2: Walk forward from first, collecting all contiguous Text node data
    var current: ?*runtime.Instance = first;
    while (current) |node| {
        const node_type = NodeImpl.getNodeType(node) orelse break;
        if (node_type != NodeImpl.NodeType.TEXT_NODE) break;

        // Get this Text node's data
        if (CharacterDataImpl.getData(node)) |data| {
            try result.appendSlice(data);
        }

        // Move to next sibling
        current = NodeImpl.getNextSibling(node);
    }

    const owned = try result.toOwnedSlice();
    return runtime.DOMString.initOwned(owned);
}

/// Getter for assignedSlot (from Slottable mixin)
/// Returns the slot this node is assigned to, or null if not assigned.
/// https://dom.spec.whatwg.org/#dom-slottable-assignedslot
pub fn get_assignedSlot(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.assigned_slot;
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
pub fn call_splitText(instance: *runtime.Instance, offset: u32) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: Get length from CharacterData (use interface per Golden Rule #13)
    const length = try interfaces.CharacterData.get_length(instance);

    // Step 2: If offset > length, throw IndexSizeError
    if (offset > length) {
        return error.IndexSizeError;
    }

    // Step 3: count = length - offset
    const count = length - offset;

    // Step 4: Get substring (the data for new node)
    const new_data = try interfaces.CharacterData.call_substringData(instance, offset, count);
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

    // Step 7: Delete the split-off data from this node (use interface per Golden Rule #13)
    try interfaces.CharacterData.call_deleteData(instance, offset, count);

    // Step 8: Return new node
    return new_node;
}

// =============================================================================
// Geometry Mixin Operations (stubs - require CSSOM integration)
// =============================================================================

/// Operation: getBoxQuads (from GeometryUtils mixin)
/// Spec: https://drafts.csswg.org/cssom-view/#dom-geometryutils-getboxquads
///
/// Returns a sequence of DOMQuads representing the CSS boxes for this element.
/// Note: Returns sentinel for empty array - requires CSSOM/layout integration
pub fn call_getBoxQuads(instance: *runtime.Instance, options: webidl.Opt(dictionaries.BoxQuadOptions)) anyerror!*const anyopaque {
    _ = instance;
    _ = options;
    // Return sentinel for empty array - layout engine required for actual box computation
    return &undefined_sentinel;
}

/// Operation: convertQuadFromNode (from GeometryUtils mixin)
/// Spec: https://drafts.csswg.org/cssom-view/#dom-geometryutils-convertquadfromnode
///
/// Converts a DOMQuadInit from another node's coordinate system to this node's.
/// Note: Returns null - requires CSSOM/layout integration for coordinate transforms
pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: dictionaries.DOMQuadInit, from: typedefs.GeometryNode, options: webidl.Opt(dictionaries.ConvertCoordinateOptions)) anyerror!*runtime.Instance {
    _ = instance;
    _ = quad;
    _ = from;
    _ = options;
    // Return null - coordinate transforms require layout engine
    return error.NotImplemented;
}

/// Operation: convertRectFromNode (from GeometryUtils mixin)
/// Spec: https://drafts.csswg.org/cssom-view/#dom-geometryutils-convertrectfromnode
///
/// Converts a DOMRectReadOnly from another node's coordinate system to this node's.
/// Note: Returns null - requires CSSOM/layout integration for coordinate transforms
pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: *runtime.Instance, from: typedefs.GeometryNode, options: webidl.Opt(dictionaries.ConvertCoordinateOptions)) anyerror!*runtime.Instance {
    _ = instance;
    _ = rect;
    _ = from;
    _ = options;
    // Return null - coordinate transforms require layout engine
    return error.NotImplemented;
}

/// Operation: convertPointFromNode (from GeometryUtils mixin)
/// Spec: https://drafts.csswg.org/cssom-view/#dom-geometryutils-convertpointfromnode
///
/// Converts a DOMPointInit from another node's coordinate system to this node's.
/// Note: Returns null - requires CSSOM/layout integration for coordinate transforms
pub fn call_convertPointFromNode(instance: *runtime.Instance, point: dictionaries.DOMPointInit, from: typedefs.GeometryNode, options: webidl.Opt(dictionaries.ConvertCoordinateOptions)) anyerror!*runtime.Instance {
    _ = instance;
    _ = point;
    _ = from;
    _ = options;
    // Return null - coordinate transforms require layout engine
    return error.NotImplemented;
}
