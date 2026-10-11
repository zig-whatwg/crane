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
const dom = @import("dom");
const boundary_points = dom.boundary_points;
const Link = @import("same_object.zig").Link;

// Import related implementations
const NodeImpl = @import("Node.zig");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const engine = @import("engine");

// Import interfaces for calling spec methods (per Golden Rule #13: impls call interfaces, not other impls)
const Range = interfaces.Range;
const AbstractRange = interfaces.AbstractRange;

pub const State = Selection.State;

/// Static sentinel value for empty array - avoids using @ptrFromInt
var empty_array_sentinel: u8 = 0;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    InvalidNodeTypeError,
    NotFoundError,
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

/// A Selection's live Range is the source of its boundary points. Keeping
/// separate anchor/focus copies loses Range setters and DOM mutation updates.
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The direction of selection
    direction: Direction = .none,

    /// The associated live range (null only for an empty selection)
    /// Per spec, most browsers only support a single range per selection
    /// Written only through `setRange`, which keeps it.
    ///
    /// Kept while it is this selection's range by an edge from the
    /// selection's wrapper (engine.traceChild, member "range"). addRange()
    /// step 3: "Set this's range to range by a strong reference (not by making
    /// a copy)" - script need not keep it (`getSelection().addRange(
    /// document.createRange())`), and getRangeAt(0) must still return that
    /// object after a collection. A bare pointer let the collector free the
    /// Range under the selection. Blink: SelectionEditor::Trace visits
    /// cached_range_. The selection's own wrapper lives as long as the
    /// selection: its document keeps it (Document's `selection_kept`).
    range: ?*runtime.Instance = null,

    /// The document this selection belongs to, retained by a traced edge.
    /// Its generation is only the teardown safety net.
    document: ?Link = null,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *InternalState) void {
        // Don't free the range - its wrapper owns it. The edge to it goes
        // with this selection's wrapper; nothing to end here, which may run
        // while the collector does (engine.forgetTracedChild must not).
        self.range = null;
        self.document = null;
    }

    /// Make `range` the range of `selection` (whose state this is), or clear
    /// it, keeping the range while it is one (see `range`).
    fn setRange(self: *InternalState, selection: *runtime.Instance, range: ?*runtime.Instance, direction: Direction) void {
        if (self.range != range) {
            self.range = range;
            if (range) |r|
                engine.traceChild(selection, r, range_slot)
            else
                engine.forgetTracedChild(selection, range_slot);
        }
        self.direction = direction;
    }
};

/// The member a selection keeps its range in (engine.traceChild).
const range_slot: engine.TracedSlot = .{ .name = "range" };

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

        // Return the block itself, not just what it points to.
        // `internal.deinit()` releases the strings and lists the state
        // OWNS; without this the state struct stays allocated for the
        // life of the process - measured at 208 bytes per discarded
        // element across the impls still doing it this way.
        const Arena = @import("runtime").ArenaAllocator;
        if (Arena.tryGet() catch null) |arena| arena.destroy(InternalState, internal);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Install the association hook once, at process startup.
pub fn installHooks() void {
    dom.selection.install(.{ .bind_document = &bindDocument });
}

fn bindDocument(selection: *runtime.Instance, document: *runtime.Instance) void {
    const internal = getInternal(selection) orelse return;
    if (internal.document) |link| if (link.isLive() and link.instance == document) return;
    // Document has wrapped the Selection through KeptChild.handOut first.
    // Two traced edges permit the document/selection cycle to collect.
    engine.traceChild(selection, document, .{ .name = "document" });
    internal.document = Link.to(document);
}

fn associatedDocument(internal: *const InternalState) ?*runtime.Instance {
    const link = internal.document orelse return null;
    return if (link.isLive()) link.instance else null;
}

/// Read the live range instead of a second copy of its boundary points.
fn boundaries(internal: *const InternalState) ?dom.range_boundaries.Boundaries {
    return dom.range_boundaries.of(internal.range orelse return null);
}

fn visibleBoundaries(internal: *const InternalState) ?dom.range_boundaries.Boundaries {
    const b = boundaries(internal) orelse return null;
    // Browser rule: expose same-root shadow endpoints. The cached spec says
    // null outside the document tree, but Chrome/Firefox pass 24/24 cases in
    // selection-at-nodes-not-part-of-flattened-tree.html (Safari 13/24),
    // WPT cc74d2669f, runs 6218298311311360/4877098740350976/5164107446878208.
    // Blink core/editing/dom_selection.cc anchorNode reads the cached Range.
    if (!isInDocument(internal, b.start_container) or !isInDocument(internal, b.end_container)) return null;
    return b;
}

// =============================================================================
// Getters
// =============================================================================

/// Selection API - anchorNode getter
/// Returns the Node in which the selection begins.
/// Returns null if the selection is empty.
pub fn get_anchorNode(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const b = visibleBoundaries(internal) orelse return null;
    return if (internal.direction == .backward) b.end_container else b.start_container;
}

/// Selection API - anchorOffset getter
/// Returns the offset within the anchor node where the selection begins.
/// Returns 0 if the selection is empty.
pub fn get_anchorOffset(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const b = visibleBoundaries(internal) orelse return 0;
    return if (internal.direction == .backward) b.end_offset else b.start_offset;
}

/// Selection API - focusNode getter
/// Returns the Node in which the selection ends.
/// Returns null if the selection is empty.
pub fn get_focusNode(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const b = visibleBoundaries(internal) orelse return null;
    return if (internal.direction == .backward) b.start_container else b.end_container;
}

/// Selection API - focusOffset getter
/// Returns the offset within the focus node where the selection ends.
/// Returns 0 if the selection is empty.
pub fn get_focusOffset(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const b = visibleBoundaries(internal) orelse return 0;
    return if (internal.direction == .backward) b.start_offset else b.end_offset;
}

/// Selection API - isCollapsed getter
/// Returns true if the selection is collapsed (anchor equals focus).
/// A collapsed selection is also known as a caret.
pub fn get_isCollapsed(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const b = boundaries(internal) orelse return true;
    return b.start_container == b.end_container and b.start_offset == b.end_offset;
}

/// Selection API - rangeCount getter
/// Returns the number of ranges in the selection.
/// Per spec, this is typically 0 or 1 (most browsers only support single range).
pub fn get_rangeCount(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return if (visibleBoundaries(internal) != null) 1 else 0;
}

/// Selection API - type getter
/// Returns the type of selection: "None", "Caret", or "Range"
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    if (try get_rangeCount(instance) == 0) return .initInterned("None");
    return .initInterned(if (try get_isCollapsed(instance)) "Caret" else "Range");
}

/// Selection API - direction getter
/// Returns the direction of selection: "none", "forward", or "backward"
pub fn get_direction(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.range == null) return .initInterned("none");
    return .initInterned(switch (internal.direction) {
        .none => "none",
        .forward => "forward",
        .backward => "backward",
    });
}

// =============================================================================
// Operations
// =============================================================================

/// Selection API - getRangeAt(index)
/// Returns the Range at the specified index.
/// Throws IndexSizeError if index is out of range.
pub fn call_getRangeAt(instance: *runtime.Instance, index: u32) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (index != 0 or visibleBoundaries(internal) == null) return error.IndexSizeError;
    return internal.range.?;
}

/// Selection API - addRange(range)
/// Adds the specified range to the selection.
/// An existing range is preserved (Chrome/Safari and the Selection spec).
pub fn call_addRange(instance: *runtime.Instance, range: *runtime.Instance) anyerror!void {
    // WebIDL interface conversion, pending shared binding brand checks (CE2-M1).
    if (range.stateAs(interfaces.Range.State) == null) return error.TypeError;
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Steps 1-2: require this document and an empty exposed selection.
    // Browser deviation: connected shadow ranges are accepted. Chrome and
    // Firefox pass "adding to selection sets the selection" in tentative/
    // Selection-getComposedRanges-range-update.html; Safari fails (file
    // totals 8/9, 5/9, 2/9 at WPT cc74d2669f). Blink DomSelection::addRange
    // checks OwnerDocument and IsConnected, not the ordinary root:
    // https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/editing/dom_selection.cc
    const start = try AbstractRange.get_startContainer(range);
    const end = try AbstractRange.get_endContainer(range);
    if (!isInDocument(internal, start) or !isInDocument(internal, end)) return;
    if (try get_rangeCount(instance) != 0) return;
    // Step 3: associate the supplied object by strong reference, never a copy.
    internal.setRange(instance, range, .forward);
}

/// Selection API - removeRange(range)
/// Removes the specified range from the selection.
pub fn call_removeRange(instance: *runtime.Instance, range: *runtime.Instance) anyerror!void {
    if (range.stateAs(interfaces.Range.State) == null) return error.TypeError;
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.range != range) return error.NotFoundError;
    try call_removeAllRanges(instance);
}

/// Selection API - removeAllRanges()
/// Removes all ranges from the selection, leaving it empty.
pub fn call_removeAllRanges(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.setRange(instance, null, .none);
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
    // Steps 1-3: null clears; doctype and length errors precede the document check.
    const target = node orelse return call_removeAllRanges(instance);
    const off = if (offset.was_passed) offset.value else 0;
    try validateBoundary(target, off);
    // Step 4: the associated document must be a shadow-including ancestor.
    if (!isInDocument(internal, target)) return;
    // Steps 5-7: make and associate a live Range now, before any DOM mutation.
    const range = try newRange(instance, target, off, target, off);
    internal.setRange(instance, range, .none);
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
    const b = boundaries(internal) orelse return error.InvalidStateError;
    // Replace the range, preserving the old Range object and its boundaries.
    const range = try newRange(instance, b.start_container, b.start_offset, b.start_container, b.start_offset);
    internal.setRange(instance, range, .none);
}

/// Selection API - collapseToEnd()
/// Collapses the selection to its end point.
/// Throws InvalidStateError if the selection is empty.
pub fn call_collapseToEnd(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const b = boundaries(internal) orelse return error.InvalidStateError;
    // Replace the range, preserving the old Range object and its boundaries.
    const range = try newRange(instance, b.end_container, b.end_offset, b.end_container, b.end_offset);
    internal.setRange(instance, range, .none);
}

/// Selection API - extend(node, offset)
/// Moves the focus of the selection to the specified position.
/// The anchor remains unchanged. This changes the selection direction.
pub fn call_extend(instance: *runtime.Instance, node: *runtime.Instance, offset: webidl.Opt(u32)) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Steps 1-2: the document check precedes empty-selection and offset errors.
    if (!isInDocument(internal, node)) return;
    const b = boundaries(internal) orelse return error.InvalidStateError;
    const off = if (offset.was_passed) offset.value else 0;
    try validateBoundary(node, off);
    // Steps 3-7: compare the old anchor with the new focus in their common tree.
    const anchor = if (internal.direction == .backward) b.end_container else b.start_container;
    const anchor_offset = if (internal.direction == .backward) b.end_offset else b.start_offset;
    const same_root = getRoot(anchor) == getRoot(node);
    const backward = same_root and boundary_points.position(DomTree, node, off, anchor, anchor_offset) == .before;
    const range = if (!same_root)
        try newRange(instance, node, off, node, off)
    else if (backward)
        try newRange(instance, node, off, anchor, anchor_offset)
    else
        try newRange(instance, anchor, anchor_offset, node, off);
    // Steps 8-9: replace only after successful validation and construction.
    internal.setRange(instance, range, if (backward) .backward else .forward);
}

/// Selection API - setBaseAndExtent(anchorNode, anchorOffset, focusNode, focusOffset)
/// Sets the selection to span the specified positions.
pub fn call_setBaseAndExtent(instance: *runtime.Instance, anchorNode: *runtime.Instance, anchorOffset: u32, focusNode: *runtime.Instance, focusOffset: u32) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Steps 1-2: offset validation precedes the associated-document check.
    if (anchorOffset > try nodeLength(anchorNode) or focusOffset > try nodeLength(focusNode)) return error.IndexSizeError;
    if (!isInDocument(internal, anchorNode) or !isInDocument(internal, focusNode)) return;
    try validateBoundary(anchorNode, anchorOffset);
    try validateBoundary(focusNode, focusOffset);
    // Steps 3-5: compare boundary points, including ancestor/descendant positions.
    const same_root = getRoot(anchorNode) == getRoot(focusNode);
    const backward = same_root and boundary_points.position(DomTree, focusNode, focusOffset, anchorNode, anchorOffset) == .before;
    const range = if (backward)
        try newRange(instance, focusNode, focusOffset, anchorNode, anchorOffset)
    else
        try newRange(instance, anchorNode, anchorOffset, focusNode, focusOffset);
    // Steps 6-7.
    internal.setRange(instance, range, if (backward) .backward else .forward);
}

/// Selection API - selectAllChildren(node)
/// Selects all the children of the specified node.
pub fn call_selectAllChildren(instance: *runtime.Instance, node: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Reject doctypes, then require this document (including its shadow trees).
    // Browser deviation from the cached ordinary-root check: Chrome/Firefox
    // selection-at-nodes-not-part-of-flattened-tree.html 24/24, Safari 13/24
    // at cc74d2669f. Blink DomSelection::selectAllChildren calls setBaseAndExtent.
    if (try interfaces.Node.get_nodeType(node) == interfaces.Node.get_DOCUMENT_TYPE_NODE()) return error.InvalidNodeTypeError;
    if (!isInDocument(internal, node)) return;
    // Steps 3-7: child count, including zero for CharacterData, not node length.
    const range = try newRange(instance, node, 0, node, countChildren(node));
    internal.setRange(instance, range, .forward);
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
    // Must have a selection to modify
    if (try get_focusNode(instance) == null) {
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
    const focus_node = (try get_focusNode(instance)).?;
    const focus_offset = try get_focusOffset(instance);

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

    if (is_extend) {
        try call_extend(instance, new_node, .passed(new_offset));
    } else {
        try call_collapse(instance, new_node, .passed(new_offset));
    }
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
    while (interfaces.Node.get_parentNode(current) catch null) |parent| {
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
    var child = firstChild(node);
    while (child != null) {
        count += 1;
        child = nextSibling(child.?);
    }
    return count;
}

/// Get next text position (first position in next text node)
fn getNextTextPosition(node: *runtime.Instance) !?PositionResult {
    var current = node;

    // Try next sibling first
    while (true) {
        if (nextSibling(current)) |sibling| {
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
            if (parentNode(current)) |parent| {
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
        if (previousSibling(current)) |sibling| {
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
            if (parentNode(current)) |parent| {
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

    var child = firstChild(root);
    while (child) |c| {
        if (try findFirstTextNode(c)) |text| {
            return text;
        }
        child = nextSibling(c);
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
    var child = firstChild(root);
    while (child) |c| {
        last_child = c;
        child = nextSibling(c);
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
    if (visibleBoundaries(internal) == null) return;
    // Delete through the associated live Range; preserve its object identity.
    try Range.call_deleteContents(internal.range.?);
}

/// Selection API - containsNode(node, allowPartialContainment)
/// Returns true if the specified node is part of the selection.
pub fn call_containsNode(instance: *runtime.Instance, node: *runtime.Instance, allowPartialContainment: webidl.Opt(bool)) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const b = boundaries(internal) orelse return false;
    if (!isInDocument(internal, node) or getRoot(node) != getRoot(b.start_container)) return false;
    const partial = allowPartialContainment.was_passed and allowPartialContainment.value;
    const length = try nodeLength(node);
    return boundary_points.position(DomTree, b.start_container, b.start_offset, node, if (partial) length else 0) != .after and
        boundary_points.position(DomTree, b.end_container, b.end_offset, node, if (partial) 0 else length) != .before;
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
pub fn call_getComposedRanges(instance: *runtime.Instance, options: webidl.Opt(dictionaries.GetComposedRangesOptions)) anyerror!runtime.JSValue {
    const allowed = if (options.was_passed) options.value.shadowRoots else null;
    // WebIDL sequence<ShadowRoot> conversion precedes the method's steps.
    // Local brand checks until the shared binding fix (CE2-M1 point 3).
    if (allowed) |roots| for (roots) |root| {
        if (root.stateAs(interfaces.ShadowRoot.State) == null) return error.TypeError;
    };
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const realm = engine.currentRealm() orelse instance.ctx;
    // Step 1: an empty Selection returns an empty sequence.
    const b = boundaries(internal) orelse return (try engine.createSequenceOfPlatformObjects(realm, &.{})).take();
    // Steps 2-5: rescope each boundary independently through undisclosed roots.
    const start = try adjustForShadowBoundary(b.start_container, b.start_offset, allowed, false);
    const end = try adjustForShadowBoundary(b.end_container, b.end_offset, allowed, true);
    // Step 6: return a new StaticRange in a sequence, using its IDL constructor.
    const range = try interfaces.StaticRange.call_constructor(realm, .{
        .startContainer = start.node,
        .startOffset = start.offset,
        .endContainer = end.node,
        .endOffset = end.offset,
    });
    const generation = runtime.SlabAllocator.generationOf(range);
    errdefer range.releaseIfUnwrapped(generation);
    return (try engine.createSequenceOfPlatformObjects(realm, &.{range})).take();
}

/// Adjust a boundary point for shadow boundaries
/// If the node is in a shadow tree not in the allowed list, move to the host
fn adjustForShadowBoundary(
    node: *runtime.Instance,
    offset: u32,
    allowed_shadow_roots: ?[]const *runtime.Instance,
    is_end: bool,
) !PositionResult {
    var current_node = node;
    var current_offset = offset;

    // Loop while node's root is a shadow root not in allowed list
    while (true) {
        // Get node's root
        const root = getRoot(current_node);

        // Check if root is a shadow root
        if (root.stateAs(interfaces.ShadowRoot.State) == null) {
            // Not a shadow root, we're done
            break;
        }

        // Check if this shadow root is in the allowed list
        if (isShadowRootAllowed(root, allowed_shadow_roots)) {
            break;
        }

        // Get the shadow root's host
        const host = try interfaces.ShadowRoot.get_host(root);

        // Get parent of host
        const parent = (try interfaces.Node.get_parentNode(host)) orelse break;

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
    while (interfaces.Node.get_parentNode(current) catch null) |parent| {
        current = parent;
    }
    return current;
}

/// Check if a shadow root is in the allowed list
fn isShadowRootAllowed(shadow_root: *runtime.Instance, allowed_list: ?[]const *runtime.Instance) bool {
    const list = allowed_list orelse return false;

    // The root may be an ancestor of an explicitly disclosed nested root.
    for (list) |allowed| {
        var current = allowed;
        while (true) {
            if (current == shadow_root) return true;
            if (parentNode(current)) |parent| {
                current = parent;
            } else if (current.stateAs(interfaces.ShadowRoot.State) != null) {
                current = interfaces.ShadowRoot.get_host(current) catch break;
            } else break;
        }
    }
    return false;
}

/// Get the index of a child in its parent
fn getChildIndex(parent: *runtime.Instance, child: *runtime.Instance) u32 {
    var index: u32 = 0;
    var current = firstChild(parent);
    while (current) |c| {
        if (c == child) {
            return index;
        }
        index += 1;
        current = nextSibling(c);
    }
    return index;
}

// =============================================================================
// Helper functions
// =============================================================================

/// Construct and validate both boundaries before publishing a new range.
fn newRange(instance: *runtime.Instance, start: *runtime.Instance, start_offset: u32, end: *runtime.Instance, end_offset: u32) !*runtime.Instance {
    const range = try Range.call_constructor(instance.ctx);
    const generation = runtime.SlabAllocator.generationOf(range);
    errdefer range.releaseIfUnwrapped(generation);
    try Range.call_setStart(range, start, start_offset);
    try Range.call_setEnd(range, end, end_offset);
    return range;
}

fn isInDocument(internal: *const InternalState, node: *runtime.Instance) bool {
    const document = associatedDocument(internal) orelse return false;
    const root = interfaces.Node.call_getRootNode(node, .passed(.{ .composed = true })) catch return false;
    return root == document;
}

/// DOM boundary-point tree adapter; all node reads use the generated interface.
const DomTree = struct {
    pub const Node = *runtime.Instance;
    pub fn parent(node: Node) ?Node {
        return interfaces.Node.get_parentNode(node) catch null;
    }
    pub fn index(node: Node) u32 {
        var result: u32 = 0;
        var sibling = interfaces.Node.get_previousSibling(node) catch null;
        while (sibling) |sibling_node| : (sibling = interfaces.Node.get_previousSibling(sibling_node) catch null) result += 1;
        return result;
    }
};

/// Stringifier - serialize method for toString
/// Spec: https://w3c.github.io/selection-api/#dom-selection-stringifier
///
/// "The stringification must return the string, which is the concatenation
/// of the rendered text if there is a range associated with this." Crane has
/// no layout, so the range's own stringification stands in for its rendered
/// text (a stated deviation: Blink and Gecko serialize what is rendered);
/// with no range, the empty string. The selected substring of a textarea or
/// input value is not done (TODO). The result is the binding's to free - toString() is
/// bound as an operation - so it is a copy in this selection's allocator. It
/// returned the literal "[object]", and `String(getSelection())` died in
/// Allocator.free's memset on the literal's read-only page.
pub fn serialize(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return "";
    const range = internal.range orelse return "";
    const text = try Range.serialize(range);
    defer if (text.len > 0) range.ctx.allocator.free(text);
    if (text.len == 0) return "";
    return instance.ctx.allocator.dupe(u8, text);
}

/// DOM node length through the owning interfaces: CharacterData length,
/// child count otherwise, and zero for attributes and doctypes.
/// TODO(CharacterData length: UTF-16 units, see codex-selection Q7): the
/// shared getter currently counts bytes; keep Selection and Range in the
/// same units until the DOM-core fix lands.
fn nodeLength(node: *runtime.Instance) !u32 {
    return switch (try interfaces.Node.get_nodeType(node)) {
        2, 10 => 0,
        3, 4, 7, 8 => try interfaces.CharacterData.get_length(node),
        else => blk: {
            var length: u32 = 0;
            var child = try interfaces.Node.get_firstChild(node);
            while (child) |current| : (child = try interfaces.Node.get_nextSibling(current)) length += 1;
            break :blk length;
        },
    };
}

/// DOM set-the-start-or-end steps 1-2, in their exception order.
fn validateBoundary(node: *runtime.Instance, offset: u32) !void {
    if (try interfaces.Node.get_nodeType(node) == interfaces.Node.get_DOCUMENT_TYPE_NODE())
        return error.InvalidNodeTypeError;
    if (offset > try nodeLength(node)) return error.IndexSizeError;
}

fn firstChild(node: *runtime.Instance) ?*runtime.Instance {
    return interfaces.Node.get_firstChild(node) catch null;
}
fn nextSibling(node: *runtime.Instance) ?*runtime.Instance {
    return interfaces.Node.get_nextSibling(node) catch null;
}
fn previousSibling(node: *runtime.Instance) ?*runtime.Instance {
    return interfaces.Node.get_previousSibling(node) catch null;
}
fn parentNode(node: *runtime.Instance) ?*runtime.Instance {
    return interfaces.Node.get_parentNode(node) catch null;
}
