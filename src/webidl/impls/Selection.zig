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
const webidl = @import("webidl");
const Selection = interfaces.Selection;

// Import related implementations
const NodeImpl = @import("Node.zig");

// Import interfaces for calling spec methods (per Golden Rule #13: impls call interfaces, not other impls)
const Range = interfaces.Range;
const AbstractRange = interfaces.AbstractRange;

pub const State = Selection.State;

/// Static sentinel value for empty array - avoids using @ptrFromInt
var empty_array_sentinel: u8 = 0;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    IndexSizeError,
    OutOfMemory,
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

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
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
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
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
pub fn get_anchorNode(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.anchor_node orelse return error.NotImplemented; // null
}

/// Selection API - anchorOffset getter
/// Returns the offset within the anchor node where the selection begins.
/// Returns 0 if the selection is empty.
pub fn get_anchorOffset(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.anchor_offset;
}

/// Selection API - focusNode getter
/// Returns the Node in which the selection ends.
/// Returns null if the selection is empty.
pub fn get_focusNode(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.focus_node orelse return error.NotImplemented; // null
}

/// Selection API - focusOffset getter
/// Returns the offset within the focus node where the selection ends.
/// Returns 0 if the selection is empty.
pub fn get_focusOffset(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.focus_offset;
}

/// Selection API - isCollapsed getter
/// Returns true if the selection is collapsed (anchor equals focus).
/// A collapsed selection is also known as a caret.
pub fn get_isCollapsed(instance: *runtime.Instance) anyerror!bool {
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
pub fn get_rangeCount(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // If we have anchor and focus set, we have one range
    if (internal.anchor_node != null and internal.focus_node != null) {
        return 1;
    }
    return 0;
}

/// Selection API - type getter
/// Returns the type of selection: "None", "Caret", or "Range"
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
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
pub fn get_direction(instance: *runtime.Instance) anyerror!runtime.DOMString {
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
pub fn call_getRangeAt(instance: *runtime.Instance, index: u32) anyerror!*runtime.Instance {
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
    const range = try createRangeFromSelection(internal);
    internal.range = range;
    return range;
}

/// Selection API - addRange(range)
/// Adds the specified range to the selection.
/// Per spec, if there's already a range, this may be ignored or replace it
/// (browser-dependent behavior). We replace the selection.
pub fn call_addRange(instance: *runtime.Instance, range: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Get the range's boundary points via AbstractRange interface (per Golden Rule #13)
    const start_container = try AbstractRange.get_startContainer(range);
    const start_offset = try AbstractRange.get_startOffset(range);
    const end_container = try AbstractRange.get_endContainer(range);
    const end_offset = try AbstractRange.get_endOffset(range);

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
pub fn call_removeRange(instance: *runtime.Instance, range: *runtime.Instance) anyerror!void {
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
pub fn call_removeAllRanges(instance: *runtime.Instance) anyerror!void {
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
pub fn call_empty(instance: *runtime.Instance) anyerror!void {
    return call_removeAllRanges(instance);
}

/// Selection API - collapse(node, offset)
/// Collapses the selection to a single point at the specified position.
/// If node is null, collapses to no selection.
pub fn call_collapse(instance: *runtime.Instance, node: ?*runtime.Instance, offset: webidl.Opt(u32)) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // TODO: Validate offset against node's length
    // (child count for Element, data length for CharacterData)

    // Collapse to the specified point
    internal.anchor_node = node;
    internal.anchor_offset = if (offset.was_passed) offset.value else 0;
    internal.focus_node = node;
    internal.focus_offset = if (offset.was_passed) offset.value else 0;
    internal.direction = .none;
    internal.range = null; // Invalidate cached range
}

/// Selection API - setPosition(node, offset)
/// Alias for collapse() (WebKit-compatible)
pub fn call_setPosition(instance: *runtime.Instance, node: ?*runtime.Instance, offset: webidl.Opt(u32)) anyerror!void {
    return call_collapse(instance, node, offset);
}

/// Selection API - collapseToStart()
/// Collapses the selection to its start point.
/// Throws InvalidStateError if the selection is empty.
pub fn call_collapseToStart(instance: *runtime.Instance) anyerror!void {
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
pub fn call_collapseToEnd(instance: *runtime.Instance) anyerror!void {
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
pub fn call_extend(instance: *runtime.Instance, node: *runtime.Instance, offset: webidl.Opt(u32)) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Must have an anchor point to extend from
    if (internal.anchor_node == null) {
        return error.InvalidStateError;
    }

    // Set the focus point
    internal.focus_node = node;
    internal.focus_offset = if (offset.was_passed) offset.value else 0;

    // Determine direction based on position comparison
    // TODO: Implement proper document position comparison
    // For now, assume forward if focus comes after anchor
    internal.direction = .forward;
    internal.range = null;
}

/// Selection API - setBaseAndExtent(anchorNode, anchorOffset, focusNode, focusOffset)
/// Sets the selection to span the specified positions.
pub fn call_setBaseAndExtent(instance: *runtime.Instance, anchorNode: *runtime.Instance, anchorOffset: u32, focusNode: *runtime.Instance, focusOffset: u32) anyerror!void {
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
pub fn call_selectAllChildren(instance: *runtime.Instance, node: *runtime.Instance) anyerror!void {
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
/// Spec: https://w3c.github.io/selection-api/#dom-selection-modify
///
/// alter: "move" | "extend"
///   - "move": Collapses the selection to the new position
///   - "extend": Extends the selection to the new position
///
/// direction: "forward" | "backward" | "left" | "right"
///   - In LTR text, "forward"/"right" and "backward"/"left" are equivalent
///   - In RTL text, they differ (not yet supported)
///
/// granularity: "character" | "word" | "sentence" | "line" | "paragraph" |
///              "lineboundary" | "sentenceboundary" | "paragraphboundary" | "documentboundary"
///
/// Note: Layout-dependent granularities (line, lineboundary) require a LayoutBackend.
/// This implementation supports character and word granularity without layout.
pub fn call_modify(instance: *runtime.Instance, alter: webidl.Opt(runtime.DOMString), direction: webidl.Opt(runtime.DOMString), granularity: webidl.Opt(runtime.DOMString)) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Must have a selection to modify
    if (internal.focus_node == null) {
        return; // No selection, nothing to modify
    }

    // Parse alter parameter (default: "move")
    const alter_slice = if (alter.was_passed) alter.value.asSlice() else "move";
    const is_extend = std.mem.eql(u8, alter_slice, "extend");

    // Parse direction parameter (default: "forward")
    const direction_slice = if (direction.was_passed) direction.value.asSlice() else "forward";
    const is_forward = std.mem.eql(u8, direction_slice, "forward") or std.mem.eql(u8, direction_slice, "right");

    // Parse granularity parameter (default: "character")
    const granularity_slice = if (granularity.was_passed) granularity.value.asSlice() else "character";

    // Get the current focus position
    const focus_node = internal.focus_node.?;
    const focus_offset = internal.focus_offset;

    // Determine new position based on granularity
    var new_node = focus_node;
    var new_offset: u32 = 0;

    if (std.mem.eql(u8, granularity_slice, "character")) {
        // Move by one character
        const result = try moveByCharacter(focus_node, focus_offset, is_forward);
        new_node = result.node;
        new_offset = result.offset;
    } else if (std.mem.eql(u8, granularity_slice, "word")) {
        // Move by one word
        const result = try moveByWord(focus_node, focus_offset, is_forward);
        new_node = result.node;
        new_offset = result.offset;
    } else if (std.mem.eql(u8, granularity_slice, "documentboundary")) {
        // Move to document boundary
        const result = try moveToDocumentBoundary(focus_node, is_forward);
        new_node = result.node;
        new_offset = result.offset;
    } else {
        // Layout-dependent granularities: sentence, line, paragraph, lineboundary, etc.
        // These require LayoutBackend integration - return without modification
        // TODO: Integrate with LayoutBackend when available
        return;
    }

    // Apply the modification based on alter mode
    if (is_extend) {
        // Extend: only move focus, keep anchor
        internal.focus_node = new_node;
        internal.focus_offset = new_offset;

        // Update direction based on positions
        if (internal.anchor_node == new_node) {
            if (internal.anchor_offset == new_offset) {
                internal.direction = .none;
            } else if (internal.anchor_offset < new_offset) {
                internal.direction = .forward;
            } else {
                internal.direction = .backward;
            }
        } else {
            // Cross-node: determine direction by document order
            // For simplicity, use existing direction or default to forward
            if (internal.direction == .none) {
                internal.direction = if (is_forward) .forward else .backward;
            }
        }
    } else {
        // Move: collapse selection to new position
        internal.anchor_node = new_node;
        internal.anchor_offset = new_offset;
        internal.focus_node = new_node;
        internal.focus_offset = new_offset;
        internal.direction = .none;
    }

    // Invalidate cached range
    internal.range = null;
}

/// Result of a position calculation
const PositionResult = struct {
    node: *runtime.Instance,
    offset: u32,
};

/// Move position by one character
fn moveByCharacter(node: *runtime.Instance, offset: u32, forward: bool) !PositionResult {
    const CharacterDataImpl = @import("CharacterData.zig");
    const node_type = NodeImpl.getNodeType(node) orelse 0;

    // For text nodes, we can move within the text content
    if (node_type == NodeImpl.NodeType.TEXT_NODE or
        node_type == NodeImpl.NodeType.COMMENT_NODE or
        node_type == NodeImpl.NodeType.CDATA_SECTION_NODE)
    {
        if (CharacterDataImpl.getInternalState(node)) |char_internal| {
            const data_len = char_internal.getLength();

            if (forward) {
                if (offset < data_len) {
                    // Move forward within same node
                    return .{ .node = node, .offset = offset + 1 };
                } else {
                    // At end of text node, try to move to next node
                    if (try getNextTextPosition(node)) |next| {
                        return next;
                    }
                    // Can't move further, stay at end
                    return .{ .node = node, .offset = offset };
                }
            } else {
                if (offset > 0) {
                    // Move backward within same node
                    return .{ .node = node, .offset = offset - 1 };
                } else {
                    // At start of text node, try to move to previous node
                    if (try getPreviousTextPosition(node)) |prev| {
                        return prev;
                    }
                    // Can't move further, stay at start
                    return .{ .node = node, .offset = 0 };
                }
            }
        }
    }

    // For element nodes, offset refers to child index
    const child_count = countChildren(node);
    if (forward) {
        if (offset < child_count) {
            return .{ .node = node, .offset = offset + 1 };
        }
    } else {
        if (offset > 0) {
            return .{ .node = node, .offset = offset - 1 };
        }
    }

    // Can't move within this node
    return .{ .node = node, .offset = offset };
}

/// Move position by one word
fn moveByWord(node: *runtime.Instance, offset: u32, forward: bool) !PositionResult {
    const CharacterDataImpl = @import("CharacterData.zig");
    const node_type = NodeImpl.getNodeType(node) orelse 0;

    // Only works for text nodes
    if (node_type != NodeImpl.NodeType.TEXT_NODE and
        node_type != NodeImpl.NodeType.COMMENT_NODE and
        node_type != NodeImpl.NodeType.CDATA_SECTION_NODE)
    {
        // For non-text nodes, fall back to character movement
        return moveByCharacter(node, offset, forward);
    }

    const char_internal = CharacterDataImpl.getInternalState(node) orelse {
        return .{ .node = node, .offset = offset };
    };

    const data = char_internal.getData();
    const data_len = char_internal.getLength();

    if (forward) {
        // Find end of current word, then start of next word
        var pos = offset;

        // Skip current word (non-whitespace)
        while (pos < data_len and !isWordBoundary(data[pos])) : (pos += 1) {}

        // Skip whitespace between words
        while (pos < data_len and isWordBoundary(data[pos])) : (pos += 1) {}

        if (pos >= data_len) {
            // Reached end of this text node, try next
            if (try getNextTextPosition(node)) |next| {
                return next;
            }
        }

        return .{ .node = node, .offset = pos };
    } else {
        // Find start of current/previous word
        var pos = offset;

        // Skip whitespace going backward
        while (pos > 0 and isWordBoundary(data[pos - 1])) : (pos -= 1) {}

        // Skip word going backward
        while (pos > 0 and !isWordBoundary(data[pos - 1])) : (pos -= 1) {}

        if (pos == 0 and offset == 0) {
            // Already at start, try previous text node
            if (try getPreviousTextPosition(node)) |prev| {
                return prev;
            }
        }

        return .{ .node = node, .offset = pos };
    }
}

/// Move to document boundary
fn moveToDocumentBoundary(node: *runtime.Instance, forward: bool) !PositionResult {
    var current = node;

    // Find the root (document or fragment)
    while (NodeImpl.getParent(current)) |parent| {
        current = parent;
    }

    if (forward) {
        // Move to end of document
        // Find last descendant text node, position at end
        if (try findLastTextNode(current)) |last_text| {
            const CharacterDataImpl = @import("CharacterData.zig");
            if (CharacterDataImpl.getInternalState(last_text)) |char_internal| {
                return .{ .node = last_text, .offset = char_internal.getLength() };
            }
        }
        // No text nodes, position at end of root's children
        return .{ .node = current, .offset = countChildren(current) };
    } else {
        // Move to start of document
        // Find first descendant text node, position at start
        if (try findFirstTextNode(current)) |first_text| {
            return .{ .node = first_text, .offset = 0 };
        }
        // No text nodes, position at start of root
        return .{ .node = current, .offset = 0 };
    }
}

/// Check if character is a word boundary (whitespace or punctuation)
fn isWordBoundary(c: u8) bool {
    return std.ascii.isWhitespace(c) or
        c == '.' or c == ',' or c == '!' or c == '?' or
        c == ';' or c == ':' or c == '"' or c == '\'' or
        c == '(' or c == ')' or c == '[' or c == ']' or
        c == '{' or c == '}' or c == '-' or c == '/';
}

/// Count children of a node
fn countChildren(node: *runtime.Instance) u32 {
    var count: u32 = 0;
    var child = NodeImpl.getFirstChild(node);
    while (child != null) {
        count += 1;
        child = NodeImpl.getNextSibling(child.?);
    }
    return count;
}

/// Get next text position (first position in next text node)
fn getNextTextPosition(node: *runtime.Instance) !?PositionResult {
    var current = node;

    // Try next sibling first
    while (true) {
        if (NodeImpl.getNextSibling(current)) |sibling| {
            // Check if sibling is a text node
            if (isTextNode(sibling)) {
                return .{ .node = sibling, .offset = 0 };
            }
            // Check sibling's descendants
            if (try findFirstTextNode(sibling)) |text| {
                return .{ .node = text, .offset = 0 };
            }
            current = sibling;
        } else {
            // No more siblings, go up to parent
            if (NodeImpl.getParent(current)) |parent| {
                current = parent;
            } else {
                return null; // Reached root
            }
        }
    }
}

/// Get previous text position (last position in previous text node)
fn getPreviousTextPosition(node: *runtime.Instance) !?PositionResult {
    var current = node;

    // Try previous sibling first
    while (true) {
        if (NodeImpl.getPreviousSibling(current)) |sibling| {
            // Check sibling's descendants (rightmost text)
            if (try findLastTextNode(sibling)) |text| {
                const CharacterDataImpl = @import("CharacterData.zig");
                if (CharacterDataImpl.getInternalState(text)) |char_internal| {
                    return .{ .node = text, .offset = char_internal.getLength() };
                }
            }
            // Check if sibling itself is a text node
            if (isTextNode(sibling)) {
                const CharacterDataImpl = @import("CharacterData.zig");
                if (CharacterDataImpl.getInternalState(sibling)) |char_internal| {
                    return .{ .node = sibling, .offset = char_internal.getLength() };
                }
            }
            current = sibling;
        } else {
            // No more siblings, go up to parent
            if (NodeImpl.getParent(current)) |parent| {
                current = parent;
            } else {
                return null; // Reached root
            }
        }
    }
}

/// Find first text node in subtree (depth-first)
fn findFirstTextNode(root: *runtime.Instance) !?*runtime.Instance {
    if (isTextNode(root)) {
        return root;
    }

    var child = NodeImpl.getFirstChild(root);
    while (child) |c| {
        if (try findFirstTextNode(c)) |text| {
            return text;
        }
        child = NodeImpl.getNextSibling(c);
    }
    return null;
}

/// Find last text node in subtree (depth-first, rightmost)
fn findLastTextNode(root: *runtime.Instance) !?*runtime.Instance {
    if (isTextNode(root)) {
        return root;
    }

    // Start from last child
    var last_child: ?*runtime.Instance = null;
    var child = NodeImpl.getFirstChild(root);
    while (child) |c| {
        last_child = c;
        child = NodeImpl.getNextSibling(c);
    }

    if (last_child) |lc| {
        if (try findLastTextNode(lc)) |text| {
            return text;
        }
    }

    return null;
}

/// Check if node is a text-type node
fn isTextNode(node: *runtime.Instance) bool {
    const node_type = NodeImpl.getNodeType(node) orelse 0;
    return node_type == NodeImpl.NodeType.TEXT_NODE or
        node_type == NodeImpl.NodeType.COMMENT_NODE or
        node_type == NodeImpl.NodeType.CDATA_SECTION_NODE;
}

/// Selection API - deleteFromDocument()
/// Deletes the content of the selection from the document.
pub fn call_deleteFromDocument(instance: *runtime.Instance) anyerror!void {
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
    const range = if (internal.range) |r| r else try createRangeFromSelection(internal);
    internal.range = range;

    // Delete the range contents (use interface per Golden Rule #13)
    interfaces.Range.call_deleteContents(range) catch return error.InvalidStateError;

    // Collapse to start after deletion
    try call_collapseToStart(instance);
}

/// Selection API - containsNode(node, allowPartialContainment)
/// Returns true if the specified node is part of the selection.
pub fn call_containsNode(instance: *runtime.Instance, node: *runtime.Instance, allowPartialContainment: webidl.Opt(bool)) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // No selection means no containment
    if (internal.anchor_node == null or internal.focus_node == null) {
        return false;
    }

    // Get or create the range for containment check
    const range = if (internal.range) |r| r else blk: {
        const r = try createRangeFromSelection(internal);
        internal.range = r;
        break :blk r;
    };

    const allow_partial = if (allowPartialContainment.was_passed) allowPartialContainment.value else false;
    if (allow_partial) {
        // Check if node intersects with the selection range (via Range interface per Golden Rule #13)
        return Range.call_intersectsNode(range, node) catch false;
    } else {
        // Check if node is fully contained within the selection range
        // Node must be an inclusive descendant of commonAncestorContainer
        // and its boundaries must be within the range
        // NOTE: containsNode is an internal helper, not a spec method.
        // TODO: Consider adding containsNode to Range interface or inlining logic here
        const RangeImpl = @import("Range.zig");
        return RangeImpl.containsNode(range, node) catch false;
    }
}

/// Selection API - getComposedRanges(options)
/// Returns an array of StaticRanges representing the selection,
/// crossing shadow boundaries if shadowRoots are provided.
///
/// Spec: https://w3c.github.io/selection-api/#dom-selection-getcomposedranges
///
/// This method returns the selection's range, potentially adjusted to cross
/// shadow boundaries. If the selection starts or ends inside a shadow tree
/// that is not in the provided shadowRoots array, the range is adjusted to
/// be at the shadow host instead.
///
/// Steps:
/// 1. If this is empty, return an empty array.
/// 2. Get start node/offset and adjust for shadow boundaries
/// 3. Get end node/offset and adjust for shadow boundaries
/// 4. Return array with a single StaticRange
pub fn call_getComposedRanges(instance: *runtime.Instance, options: webidl.Opt(dictionaries.GetComposedRangesOptions)) anyerror!*const anyopaque {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Step 1: If this is empty, return empty array
    if (internal.anchor_node == null or internal.focus_node == null) {
        // Return pointer to static empty array
        return @ptrCast(&empty_array_sentinel);
    }

    // Get allowed shadow roots from options
    const allowed_shadow_roots: ?[]const *runtime.Instance = if (options.was_passed)
        options.value.shadowRoots
    else
        null;

    // Determine start and end based on direction
    var start_node: *runtime.Instance = undefined;
    var start_offset: u32 = undefined;
    var end_node: *runtime.Instance = undefined;
    var end_offset: u32 = undefined;

    switch (internal.direction) {
        .backward => {
            // Focus comes before anchor
            start_node = internal.focus_node.?;
            start_offset = internal.focus_offset;
            end_node = internal.anchor_node.?;
            end_offset = internal.anchor_offset;
        },
        else => {
            // Anchor comes before focus (or same position)
            start_node = internal.anchor_node.?;
            start_offset = internal.anchor_offset;
            end_node = internal.focus_node.?;
            end_offset = internal.focus_offset;
        },
    }

    // Step 2-3: Adjust start for shadow boundaries
    // While startNode's root is a shadow root not in the allowed list,
    // move to the shadow host's parent
    const adjusted_start = try adjustForShadowBoundary(start_node, start_offset, allowed_shadow_roots, false);
    const adjusted_end = try adjustForShadowBoundary(end_node, end_offset, allowed_shadow_roots, true);

    // Step 4: Create a StaticRange with the adjusted boundaries
    // For now, we return a single StaticRange wrapped in an array
    // TODO: Proper array allocation and StaticRange creation
    // The StaticRange interface expects:
    //   - startContainer, startOffset, endContainer, endOffset
    const static_range = try interfaces.StaticRange.init(internal.allocator, instance.ctx);
    errdefer interfaces.StaticRange.deinit(static_range);

    // Set the StaticRange boundaries via its implementation
    const StaticRangeImpl = @import("StaticRange.zig");
    try StaticRangeImpl.setStart(static_range, adjusted_start.node, adjusted_start.offset);
    try StaticRangeImpl.setEnd(static_range, adjusted_end.node, adjusted_end.offset);

    // Return pointer to the StaticRange
    // Note: In a full implementation, this would be a proper sequence/array
    return @ptrCast(static_range);
}

/// Adjust a boundary point for shadow boundaries
/// If the node is in a shadow tree not in the allowed list, move to the host
fn adjustForShadowBoundary(
    node: *runtime.Instance,
    offset: u32,
    allowed_shadow_roots: ?[]const *runtime.Instance,
    is_end: bool,
) !PositionResult {
    const ShadowRootImpl = @import("ShadowRoot.zig");
    var current_node = node;
    var current_offset = offset;

    // Loop while node's root is a shadow root not in allowed list
    while (true) {
        // Get node's root
        const root = getRoot(current_node);

        // Check if root is a shadow root
        const shadow_internal = ShadowRootImpl.getInternalState(root);
        if (shadow_internal == null) {
            // Not a shadow root, we're done
            break;
        }

        // Check if this shadow root is in the allowed list
        if (isShadowRootAllowed(root, allowed_shadow_roots)) {
            break;
        }

        // Get the shadow root's host
        const host = shadow_internal.?.host orelse break;

        // Get parent of host
        const parent = NodeImpl.getParent(host) orelse break;

        // Calculate index of host in parent
        const host_index = getChildIndex(parent, host);

        // Adjust offset based on whether this is start or end
        if (is_end) {
            // For end, offset is index + 1
            current_offset = host_index + 1;
        } else {
            // For start, offset is index
            current_offset = host_index;
        }

        current_node = parent;
    }

    return .{ .node = current_node, .offset = current_offset };
}

/// Get the root node of a node
fn getRoot(node: *runtime.Instance) *runtime.Instance {
    var current = node;
    while (NodeImpl.getParent(current)) |parent| {
        current = parent;
    }
    return current;
}

/// Check if a shadow root is in the allowed list
fn isShadowRootAllowed(shadow_root: *runtime.Instance, allowed_list: ?[]const *runtime.Instance) bool {
    const list = allowed_list orelse return false;

    // Check if shadow_root matches any in the list
    for (list) |allowed| {
        if (allowed == shadow_root) {
            return true;
        }
    }
    return false;
}

/// Get the index of a child in its parent
fn getChildIndex(parent: *runtime.Instance, child: *runtime.Instance) u32 {
    var index: u32 = 0;
    var current = NodeImpl.getFirstChild(parent);
    while (current) |c| {
        if (c == child) {
            return index;
        }
        index += 1;
        current = NodeImpl.getNextSibling(c);
    }
    return index;
}

// =============================================================================
// Helper functions
// =============================================================================

/// Create a Range object from the current selection boundaries
fn createRangeFromSelection(internal: *InternalState) !*runtime.Instance {
    const anchor = internal.anchor_node orelse return error.InvalidStateError;
    const focus = internal.focus_node orelse return error.InvalidStateError;

    // Create a new Range (use interface per Golden Rule #13)
    // Note: We need a context here - get it from anchor node
    const range = try interfaces.Range.call_constructor(internal.allocator, anchor.ctx);

    // Set the range boundaries based on direction
    switch (internal.direction) {
        .backward => {
            // Focus comes before anchor
            try interfaces.Range.call_setStart(range, focus, internal.focus_offset);
            try interfaces.Range.call_setEnd(range, anchor, internal.anchor_offset);
        },
        else => {
            // Anchor comes before focus (or same position)
            try interfaces.Range.call_setStart(range, anchor, internal.anchor_offset);
            try interfaces.Range.call_setEnd(range, focus, internal.focus_offset);
        },
    }

    return range;
}
