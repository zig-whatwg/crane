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
    // The registry owns this block, so `Registry.remove` returns it to the
    // arena. With `set` it was dropped from the map and held to process
    // exit - 904 bytes per discarded element, measured.
    const internal = try Registry.createIn(instance, ArenaAllocator.get());
    internal.* = InternalState.init(allocator);

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
pub fn call_constructor(ctx: runtime.Context, data: webidl.Opt(runtime.DOMString)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &Text.vtable, ctx);
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
/// DOM §4.12 - "The splitText(offset) method steps are to split this with offset."
///
/// To split a Text node `node` with integer `offset`:
///  1. Let length be node's length.
///  2. If offset is greater than length, then throw an "IndexSizeError".
///  3. Let count be length − offset.
///  4. Let newData be the result of substringing data of node with offset and count.
///  5. Let newNode be a new Text node whose node document is node's node document
///     and data is newData.
///  6. Let parent be node's parent.
///  7. If parent is non-null:
///     1. Insert newNode into parent before node's next sibling.
///     2-5. Update live ranges.
///  8. Replace data of node with offset, count, and the empty string.
///  9. Return newNode.
///
/// https://dom.spec.whatwg.org/#concept-text-split
pub fn call_splitText(instance: *runtime.Instance, offset: u32) anyerror!*runtime.Instance {
    _ = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: Get length from CharacterData (use interface per Golden Rule #13)
    const length = try interfaces.CharacterData.get_length(instance);

    // Step 2: If offset > length, throw IndexSizeError
    if (offset > length) {
        return error.IndexSizeError;
    }

    // Step 3: count = length - offset
    const count = length - offset;

    // Step 4: Get substring (the data for new node).
    // `substringData` allocates out of `instance.ctx.allocator`, so the
    // matching free is against that allocator, not the Text state's.
    var new_data = try interfaces.CharacterData.call_substringData(instance, offset, count);
    defer new_data.deinit(instance.ctx.allocator);

    // Step 5: New Text node in the same node document.
    //
    // The context must be this node's: `init(..., undefined)` left
    // `new_node.ctx.allocator` pointing at stack garbage, and the first
    // `.data` read on the returned node segfaulted inside the allocator
    // vtable. Everything a Text node does later - `get_data`, `substringData`,
    // `wholeText` - allocates through `ctx.allocator`.
    const new_node = try call_constructor(
        instance.ctx,
        webidl.Opt(runtime.DOMString).passed(new_data),
    );
    errdefer deinit(new_node);

    if (NodeImpl.getOwnerDocument(instance)) |doc| {
        try NodeImpl.setOwnerDocument(new_node, doc);
    }

    // Step 6: parent
    const parent = try interfaces.Node.get_parentNode(instance);

    // Step 7
    if (parent) |p| {
        // Step 7.1: Insert newNode into parent before node's next sibling.
        const next_sibling = try interfaces.Node.get_nextSibling(instance);
        _ = try interfaces.Node.call_insertBefore(p, new_node, next_sibling);

        // Steps 7.2-7.5
        dom.mutation.runLiveRangeSplitSteps(instance, new_node, p, offset);
    }

    // Step 8: Replace data with the empty string (not deleteData - same effect,
    // but this is the algorithm the spec names, and it is the one that runs the
    // live-range steps for a replacement).
    try interfaces.CharacterData.call_replaceData(
        instance,
        offset,
        count,
        runtime.DOMString.initEmpty(),
    );

    // Step 9: Return new node
    return new_node;
}

// =============================================================================
// Geometry Mixin Operations (stubs - require CSSOM integration)
// =============================================================================

/// Operation: getBoxQuads (from GeometryUtils mixin)
/// Spec: https://drafts.csswg.org/cssom-view/#dom-geometryutils-getboxquads
///
/// Returns a sequence of DOMQuads representing the CSS boxes for this element.
/// Note: Returns empty array stub - requires CSSOM/layout integration
pub fn call_getBoxQuads(instance: *runtime.Instance, options: webidl.Opt(dictionaries.BoxQuadOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    // Return undefined for now - layout engine required for actual box computation
    // TODO: Return proper empty array when V8 array creation is available
    return runtime.JSValue.jsUndefined;
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

/// Clean up ALL remaining internal states.
pub fn cleanupAllRemainingInternal() void {
    Registry.deinitAllAndClear();
}
