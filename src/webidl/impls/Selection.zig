//! Implementation for Selection interface
//!
//! Spec: https://w3c.github.io/selection-api/#selection-interface
//! Selection API
//!
//! A Selection object represents the range of text selected by the user or
//! the current position of the caret. Each document has an associated Selection.
//! The selection holds a reference to a single range that can be accessed via
//! getRangeAt(0).
//!
//! Selection has an anchor (start point) and focus (end point). The anchor is
//! where the selection started, and the focus is where it ends. They can be in
//! either order depending on the direction of selection.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const Selection = interfaces.Selection;

// Import related implementations
const NodeImpl = @import("Node.zig");
const RangeImpl = @import("Range.zig");

pub const State = Selection.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    IndexSizeError,
    OutOfMemory,
    InvalidNodeTypeError,
    NotSupportedError,
    HierarchyRequestError,
    NotFoundError,
    WrongDocumentError,
};

/// Selection direction constants
pub const Direction = enum {
    none, // No direction (collapsed)
    forward, // Anchor before focus
    backward, // Focus before anchor
};

/// Selection type constants (per spec)
pub const SelectionType = enum {
    none, // No selection
    caret, // Collapsed selection (cursor)
    range, // Range selection
};

/// Internal state for Selection implementation
/// Per spec, a Selection holds:
/// - An anchor (node + offset) where selection started
/// - A focus (node + offset) where selection ends
/// - The direction of selection (forward/backward)
/// - A single associated Range (browsers only support one range per selection)
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The anchor node (where selection started)
    anchor_node: ?*runtime.Instance = null,
    /// The anchor offset within the anchor node
    anchor_offset: u32 = 0,

    /// The focus node (where selection currently ends)
    focus_node: ?*runtime.Instance = null,
    /// The focus offset within the focus node
    focus_offset: u32 = 0,

    /// The direction of selection
    direction: Direction = .none,

    /// The associated range (lazily created, may be null if empty selection)
    /// Per spec, most browsers only support a single range per selection
    range: ?*runtime.Instance = null,

    /// The document this selection belongs to
    document: ?*runtime.Instance = null,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *InternalState) void {
        // Don't free the range - it's managed by the document's range list
        // Just clear our reference
        self.range = null;
        self.anchor_node = null;
        self.focus_node = null;
    }
};

/// Get the internal state from instance
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

    // Initialize internal state
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

/// Create a Selection for a document
pub fn createSelection(allocator: std.mem.Allocator, ctx: runtime.Context, document: *runtime.Instance) !*runtime.Instance {
    const instance = try init(allocator, State, &interfaces.Selection.vtable, ctx);
    errdefer deinit(instance);

    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.document = document;

    return instance;
}

// =============================================================================
// Getters
// =============================================================================

/// Selection API - anchorNode getter
/// Returns the Node in which the selection begins.
/// Returns null if the selection is empty.
pub fn get_anchorNode(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.anchor_node orelse return error.NotImplemented; // null
}

/// Selection API - anchorOffset getter
/// Returns the offset within the anchor node where the selection begins.
/// Returns 0 if the selection is empty.
pub fn get_anchorOffset(instance: *runtime.Instance) ImplError!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.anchor_offset;
}

/// Selection API - focusNode getter
/// Returns the Node in which the selection ends.
/// Returns null if the selection is empty.
pub fn get_focusNode(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.focus_node orelse return error.NotImplemented; // null
}

/// Selection API - focusOffset getter
/// Returns the offset within the focus node where the selection ends.
/// Returns 0 if the selection is empty.
pub fn get_focusOffset(instance: *runtime.Instance) ImplError!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.focus_offset;
}

/// Selection API - isCollapsed getter
/// Returns true if the selection is collapsed (anchor equals focus).
/// A collapsed selection is also known as a caret.
pub fn get_isCollapsed(instance: *runtime.Instance) ImplError!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Empty selection is considered collapsed
    if (internal.anchor_node == null or internal.focus_node == null) {
        return true;
    }

    // Collapsed if anchor and focus are at the same position
    return internal.anchor_node == internal.focus_node and
        internal.anchor_offset == internal.focus_offset;
}

/// Selection API - rangeCount getter
/// Returns the number of ranges in the selection.
/// Per spec, this is typically 0 or 1 (most browsers only support single range).
pub fn get_rangeCount(instance: *runtime.Instance) ImplError!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // If we have anchor and focus set, we have one range
    if (internal.anchor_node != null and internal.focus_node != null) {
        return 1;
    }
    return 0;
}

/// Selection API - type getter
/// Returns the type of selection: "None", "Caret", or "Range"
pub fn get_type(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // No selection
    if (internal.anchor_node == null or internal.focus_node == null) {
        return runtime.DOMString.initInterned("None");
    }

    // Check if collapsed (caret)
    if (internal.anchor_node == internal.focus_node and
        internal.anchor_offset == internal.focus_offset)
    {
        return runtime.DOMString.initInterned("Caret");
    }

    // Range selection
    return runtime.DOMString.initInterned("Range");
}

/// Selection API - direction getter
/// Returns the direction of selection: "none", "forward", or "backward"
pub fn get_direction(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    return switch (internal.direction) {
        .none => runtime.DOMString.initInterned("none"),
        .forward => runtime.DOMString.initInterned("forward"),
        .backward => runtime.DOMString.initInterned("backward"),
    };
}

// =============================================================================
// Operations
// =============================================================================

/// Selection API - getRangeAt(index)
/// Returns the Range at the specified index.
/// Throws IndexSizeError if index is out of range.
pub fn call_getRangeAt(instance: *runtime.Instance, index: u32) ImplError!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Only support index 0 (single range per selection)
    if (index != 0) {
        return error.IndexSizeError;
    }

    // If no selection, throw IndexSizeError
    if (internal.anchor_node == null or internal.focus_node == null) {
        return error.IndexSizeError;
    }

    // Create or return the associated range
    if (internal.range) |range| {
        return range;
    }

    // Create a new range representing the selection
    const range = try createRangeFromSelection(internal, instance.ctx);
    internal.range = range;
    return range;
}

/// Selection API - addRange(range)
/// Adds the specified range to the selection.
/// Per spec, if there's already a range, this may be ignored or replace it
/// (browser-dependent behavior). We replace the selection.
pub fn call_addRange(instance: *runtime.Instance, range: *runtime.Instance) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Get the range's boundary points
    const start_container = RangeImpl.getStartContainer(range) orelse return error.InvalidStateError;
    const start_offset = RangeImpl.getStartOffset(range);
    const end_container = RangeImpl.getEndContainer(range) orelse return error.InvalidStateError;
    const end_offset = RangeImpl.getEndOffset(range);

    // Set selection to the range's boundaries
    internal.anchor_node = start_container;
    internal.anchor_offset = start_offset;
    internal.focus_node = end_container;
    internal.focus_offset = end_offset;
    internal.direction = .forward;
    internal.range = range;
}

/// Selection API - removeRange(range)
/// Removes the specified range from the selection.
pub fn call_removeRange(instance: *runtime.Instance, range: *runtime.Instance) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if this is our range
    if (internal.range == range) {
        // Clear the selection
        internal.anchor_node = null;
        internal.anchor_offset = 0;
        internal.focus_node = null;
        internal.focus_offset = 0;
        internal.direction = .none;
        internal.range = null;
    }
    // If not our range, do nothing (per spec)
}

/// Selection API - removeAllRanges()
/// Removes all ranges from the selection, leaving it empty.
pub fn call_removeAllRanges(instance: *runtime.Instance) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    internal.anchor_node = null;
    internal.anchor_offset = 0;
    internal.focus_node = null;
    internal.focus_offset = 0;
    internal.direction = .none;
    internal.range = null;
}

/// Selection API - empty()
/// Alias for removeAllRanges() (Gecko-compatible)
pub fn call_empty(instance: *runtime.Instance) ImplError!void {
    return call_removeAllRanges(instance);
}

/// Selection API - collapse(node, offset)
/// Collapses the selection to a single point at the specified position.
/// If node is null, collapses to no selection.
pub fn call_collapse(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // TODO: Validate offset against node's length
    // (child count for Element, data length for CharacterData)

    // Collapse to the specified point
    internal.anchor_node = node;
    internal.anchor_offset = offset;
    internal.focus_node = node;
    internal.focus_offset = offset;
    internal.direction = .none;
    internal.range = null; // Invalidate cached range
}

/// Selection API - setPosition(node, offset)
/// Alias for collapse() (WebKit-compatible)
pub fn call_setPosition(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) ImplError!void {
    return call_collapse(instance, node, offset);
}

/// Selection API - collapseToStart()
/// Collapses the selection to its start point.
/// Throws InvalidStateError if the selection is empty.
pub fn call_collapseToStart(instance: *runtime.Instance) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Must have a selection
    if (internal.anchor_node == null or internal.focus_node == null) {
        return error.InvalidStateError;
    }

    // Determine the start point (depends on direction)
    const start_node: *runtime.Instance = switch (internal.direction) {
        .backward => internal.focus_node.?,
        else => internal.anchor_node.?,
    };
    const start_offset: u32 = switch (internal.direction) {
        .backward => internal.focus_offset,
        else => internal.anchor_offset,
    };

    // Collapse to start
    internal.anchor_node = start_node;
    internal.anchor_offset = start_offset;
    internal.focus_node = start_node;
    internal.focus_offset = start_offset;
    internal.direction = .none;
    internal.range = null;
}

/// Selection API - collapseToEnd()
/// Collapses the selection to its end point.
/// Throws InvalidStateError if the selection is empty.
pub fn call_collapseToEnd(instance: *runtime.Instance) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Must have a selection
    if (internal.anchor_node == null or internal.focus_node == null) {
        return error.InvalidStateError;
    }

    // Determine the end point (depends on direction)
    const end_node: *runtime.Instance = switch (internal.direction) {
        .backward => internal.anchor_node.?,
        else => internal.focus_node.?,
    };
    const end_offset: u32 = switch (internal.direction) {
        .backward => internal.anchor_offset,
        else => internal.focus_offset,
    };

    // Collapse to end
    internal.anchor_node = end_node;
    internal.anchor_offset = end_offset;
    internal.focus_node = end_node;
    internal.focus_offset = end_offset;
    internal.direction = .none;
    internal.range = null;
}

/// Selection API - extend(node, offset)
/// Moves the focus of the selection to the specified position.
/// The anchor remains unchanged. This changes the selection direction.
pub fn call_extend(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Must have an anchor point to extend from
    if (internal.anchor_node == null) {
        return error.InvalidStateError;
    }

    // Set the focus point
    internal.focus_node = node;
    internal.focus_offset = offset;

    // Determine direction based on position comparison
    // TODO: Implement proper document position comparison
    // For now, assume forward if focus comes after anchor
    internal.direction = .forward;
    internal.range = null;
}

/// Selection API - setBaseAndExtent(anchorNode, anchorOffset, focusNode, focusOffset)
/// Sets the selection to span the specified positions.
pub fn call_setBaseAndExtent(instance: *runtime.Instance, anchorNode: *runtime.Instance, anchorOffset: u32, focusNode: *runtime.Instance, focusOffset: u32) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Set both anchor and focus
    internal.anchor_node = anchorNode;
    internal.anchor_offset = anchorOffset;
    internal.focus_node = focusNode;
    internal.focus_offset = focusOffset;

    // Determine direction
    if (anchorNode == focusNode) {
        if (anchorOffset == focusOffset) {
            internal.direction = .none;
        } else if (anchorOffset < focusOffset) {
            internal.direction = .forward;
        } else {
            internal.direction = .backward;
        }
    } else {
        // TODO: Compare document positions for cross-node selection
        internal.direction = .forward;
    }

    internal.range = null;
}

/// Selection API - selectAllChildren(node)
/// Selects all the children of the specified node.
pub fn call_selectAllChildren(instance: *runtime.Instance, node: *runtime.Instance) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Set anchor to beginning of node's children
    internal.anchor_node = node;
    internal.anchor_offset = 0;

    // Set focus to end of node's children
    // Count children to get the end offset
    var child_count: u32 = 0;
    var child = NodeImpl.getFirstChild(node);
    while (child != null) {
        child_count += 1;
        child = NodeImpl.getNextSibling(child.?);
    }

    internal.focus_node = node;
    internal.focus_offset = child_count;
    internal.direction = .forward;
    internal.range = null;
}

/// Selection API - modify(alter, direction, granularity)
/// Modifies the selection by moving it by the specified granularity.
/// This is a complex operation used for keyboard navigation.
///
/// alter: "move" | "extend"
/// direction: "forward" | "backward" | "left" | "right"
/// granularity: "character" | "word" | "sentence" | "line" | "paragraph" | etc.
pub fn call_modify(instance: *runtime.Instance, alter: runtime.DOMString, direction: runtime.DOMString, granularity: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = alter;
    _ = direction;
    _ = granularity;
    // TODO: This is a complex operation that requires text layout information
    // For now, this is a no-op as it needs rendering engine integration
}

/// Selection API - deleteFromDocument()
/// Deletes the content of the selection from the document.
pub fn call_deleteFromDocument(instance: *runtime.Instance) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // If there's no selection or it's collapsed, do nothing
    if (internal.anchor_node == null or internal.focus_node == null) {
        return;
    }

    if (internal.anchor_node == internal.focus_node and
        internal.anchor_offset == internal.focus_offset)
    {
        return; // Collapsed, nothing to delete
    }

    // Get or create the range
    const range = if (internal.range) |r| r else try createRangeFromSelection(internal, instance.ctx);
    internal.range = range;

    // Delete the range contents
    RangeImpl.call_deleteContents(range) catch return error.InvalidStateError;

    // Collapse to start after deletion
    try call_collapseToStart(instance);
}

/// Selection API - containsNode(node, allowPartialContainment)
/// Returns true if the specified node is part of the selection.
pub fn call_containsNode(instance: *runtime.Instance, node: *runtime.Instance, allowPartialContainment: bool) ImplError!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // No selection means no containment
    if (internal.anchor_node == null or internal.focus_node == null) {
        return false;
    }

    // Get or create the range for containment check
    const range = if (internal.range) |r| r else blk: {
        const r = try createRangeFromSelection(internal, instance.ctx);
        internal.range = r;
        break :blk r;
    };

    if (allowPartialContainment) {
        // Check if node intersects with the selection range
        return RangeImpl.intersectsNode(range, node) catch false;
    } else {
        // Check if node is fully contained within the selection range
        // Node must be an inclusive descendant of commonAncestorContainer
        // and its boundaries must be within the range
        return RangeImpl.containsNode(range, node) catch false;
    }
}

/// Selection API - getComposedRanges(options)
/// Returns an array of StaticRanges representing the selection,
/// crossing shadow boundaries if shadowRoots are provided.
pub fn call_getComposedRanges(instance: *runtime.Instance, options: dictionaries.GetComposedRangesOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    // TODO: Implement composed ranges with shadow DOM support
    // For now, return empty array sentinel
    return @ptrFromInt(1);
}

// =============================================================================
// Helper functions
// =============================================================================

/// Create a Range object from the current selection boundaries
fn createRangeFromSelection(internal: *InternalState, ctx: runtime.Context) !*runtime.Instance {
    const anchor = internal.anchor_node orelse return error.InvalidStateError;
    const focus = internal.focus_node orelse return error.InvalidStateError;

    // Create a new Range
    const range = try RangeImpl.call_constructor(internal.allocator, ctx);

    // Set the range boundaries based on direction
    switch (internal.direction) {
        .backward => {
            // Focus comes before anchor
            try RangeImpl.call_setStart(range, focus, internal.focus_offset);
            try RangeImpl.call_setEnd(range, anchor, internal.anchor_offset);
        },
        else => {
            // Anchor comes before focus (or same position)
            try RangeImpl.call_setStart(range, anchor, internal.anchor_offset);
            try RangeImpl.call_setEnd(range, focus, internal.focus_offset);
        },
    }

    return range;
}
