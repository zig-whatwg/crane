//! Implementation for Range interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-range
//! WHATWG DOM Standard §5
//!
//! A Range object represents a sequence of content within the node tree.
//! Each range has a start and an end which are boundary points.
//! A boundary point is a tuple consisting of a node and an offset.
//!
//! Unlike StaticRange, Range objects are "live" - they update when the DOM mutates.
//!
//! Migrated from: webidl/src/dom/Range.zig

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const Range = interfaces.Range;
const range_boundaries = @import("dom").range_boundaries;
const boundary_points = @import("dom").boundary_points;
const dom = @import("dom");
const Link = @import("same_object.zig").Link;
const document_internals = @import("dom").document_internals;

pub const State = Range.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    InvalidNodeTypeError,
    IndexSizeError,
    WrongDocumentError,
    NotSupportedError,
    HierarchyRequestError,
    NotFoundError,
    OutOfMemory,
};

/// Range comparison constants
pub const START_TO_START: u16 = 0;
pub const START_TO_END: u16 = 1;
pub const END_TO_END: u16 = 2;
pub const END_TO_START: u16 = 3;

/// Internal state for Range implementation
/// Stores boundary points that update when the tree mutates
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// Start boundary point - node
    start_container: ?*runtime.Instance,
    /// Start boundary point - offset
    start_offset: u32,
    /// End boundary point - node
    end_container: ?*runtime.Instance,
    /// End boundary point - offset
    end_offset: u32,

    /// Owner document - needed for per-document range tracking
    owner_document: ?*runtime.Instance,
    /// The owner document's slab generation when this range registered with
    /// it. The document keeps a plain list of its live ranges and walks it on
    /// every mutation, so a range must leave the list when it is freed - but
    /// only if the document it joined is still the object at that address.
    owner_generation: u64 = 0,

    /// The nodes the boundary edges hold (`keepContainers`): the start
    /// container, and the end container while it is another node.
    traced_start: ?*runtime.Instance = null,
    traced_end: ?*runtime.Instance = null,

    /// One counted reference on each boundary point's container (refcount
    /// step 5f): WebKit's RangeBoundaryPoint holds `Ref<Node> m_container`
    /// (Source/WebCore/dom/RangeBoundaryPoint.h), so a collapsed range
    /// holds its node twice. Redrawn with the edges (`keepContainers`).
    /// SHADOW MODE: the edges above are what keep the nodes until refcount
    /// step 9b; these decide nothing yet.
    start_hold: dom.node_holds.RefHold = .{},
    end_hold: dom.node_holds.RefHold = .{},

    /// Deliberately weak: Selection already traces this Range, and an otherwise
    /// unreferenced Selection must not be rooted by a script-held Range. The
    /// generation check is the weak-link behavior, not a substitute for a hold.
    selection: ?Link = null,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .start_container = null,
            .start_offset = 0,
            .end_container = null,
            .end_offset = 0,
            .owner_document = null,
        };
    }
};

/// The members a live range keeps its boundary nodes in (engine.traceChild).
/// A range script holds keeps its start and end nodes - and through them
/// their trees and their document - for as long as it lives. Blink:
/// Range::Trace visits start_ and end_, and RangeBoundaryPoint::Trace their
/// containers (core/dom/range.cc); StaticRange here keeps its containers the
/// same way. They were bare pointers, so a range whose nodes' tree was
/// collected answered from freed nodes, or crashed (lane ownerdoc,
/// crane/od-range-keeps-its-containers.html).
///
/// Redrawn whenever a boundary moves: by the range's own methods and by the
/// live-range steps of the mutation algorithms (`setStartBoundary`,
/// `setEndBoundary`, the replace-data steps through setStart/setEnd). A range
/// made by native code - Selection's, cloneRange's, createRange's before the
/// binding wraps it - holds its nodes strongly through traceChild until its
/// wrapper is made, and `deinit` lets that hold go if it is freed unwrapped.
const start_slot: engine.TracedSlot = .{ .name = "startContainer" };
const end_slot: engine.TracedSlot = .{ .name = "endContainer" };

/// Make the boundary edges hold `range`'s current boundary nodes.
fn keepContainers(range: *runtime.Instance, internal: *InternalState) void {
    internal.start_hold.set(internal.start_container);
    internal.end_hold.set(internal.end_container);
    const start = internal.start_container;
    if (start != internal.traced_start) {
        internal.traced_start = start;
        if (start) |node| engine.traceChild(range, node, start_slot) else engine.forgetTracedChild(range, start_slot);
    }
    // A collapsed range - the common case - keeps its one node once.
    const end: ?*runtime.Instance = if (internal.end_container == start) null else internal.end_container;
    if (end != internal.traced_end) {
        internal.traced_end = end;
        if (end) |node| engine.traceChild(range, node, end_slot) else engine.forgetTracedChild(range, end_slot);
    }
}

/// This Range's state, or null when `instance` is not a Range: the brand check,
/// as ProcessingInstruction's and HTMLLinkElement's (lane crash1 b2, the SAFETY
/// item of perf3 D1). dom.range_boundaries promises null "for an object with no
/// Range state" (`points`): a document's live-range walks (dom.mutation,
/// execCommand) hand it each listed entry, and boundariesOf answers for every
/// AbstractRange. The unchecked cast this replaces (InternalStateAccessor:
/// `instance.getState(State)`) read another type's State at this one's
/// `own._internal` offset as a pointer.
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    range_boundaries.install(&boundariesOf);
    range_boundaries.installLiveRange(.{
        .collapse = &collapseLive,
        .update_owner_document = &updateOwnerDocument,
        .points = &livePoints,
        .set_start = &setStartBoundary,
        .set_end = &setEndBoundary,
        .set_start_offset = &setStartOffset,
        .set_end_offset = &setEndOffset,
    });
    dom.selection.install(.{ .associate_range = &associateSelection });
}

fn associateSelection(range: *runtime.Instance, selection: *runtime.Instance, associated: bool) void {
    const internal = getInternal(range) orelse return;
    if (associated) {
        internal.selection = Link.to(selection);
    } else if (internal.selection) |link| {
        if (link.instance == selection) internal.selection = null;
    }
}

/// No boundary reads on unselected ranges. A selected range's pre/post points
/// suppress setter no-ops; DOM mutation setters take the same path.
fn selectedBoundaries(internal: *const InternalState) ?range_boundaries.Boundaries {
    if (internal.selection == null) return null;
    return .{
        .start_container = internal.start_container orelse return null,
        .start_offset = internal.start_offset,
        .end_container = internal.end_container orelse return null,
        .end_offset = internal.end_offset,
    };
}

fn notifySelection(range: *runtime.Instance, internal: *InternalState, before: ?range_boundaries.Boundaries) void {
    const old = before orelse return;
    const link = internal.selection orelse return;
    if (!link.isLive()) {
        internal.selection = null;
        return;
    }
    const after = selectedBoundaries(internal);
    if (!std.meta.eql(before, after)) {
        const containers_changed = if (after) |points|
            old.start_container != points.start_container or old.end_container != points.end_container
        else
            true;
        // Selection API selectionchange: a selected Range boundary changed.
        // Blink RangeUpdateScope updates the associated selection on exit;
        // our hook checks the association and queues without dispatching
        // inside a mutation. This notifier reads no Range state after handoff.
        dom.selection.rangeMutated(link.instance, range, containers_changed);
    }
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

    // Initialize Range internal state
    const state = instance.getState(StateType);
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = InternalState.init(allocator);
    state.own._internal = internal;

    return instance;
}

/// This kind of range's answer to AbstractRange's boundary-point getters.
fn boundariesOf(range: *runtime.Instance) ?range_boundaries.Boundaries {
    if (range.stateAs(State) == null) return null;
    const internal = getInternal(range) orelse return null;
    return .{
        .start_container = internal.start_container orelse return null,
        .start_offset = internal.start_offset,
        .end_container = internal.end_container orelse return null,
        .end_offset = internal.end_offset,
    };
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        // A range its wrapper's collection frees has no edges left to end;
        // one freed unwrapped lets go of what waits for its wrapper.
        if (internal.traced_start != null) engine.forgetTracedChild(instance, start_slot);
        if (internal.traced_end != null) engine.forgetTracedChild(instance, end_slot);
        internal.start_hold.release();
        internal.end_hold.release();
        // Leave the document's live-range list, which mutation.zig walks on
        // every insert and remove. Blink holds that list weakly
        // (HeapHashSet<WeakMember<Range>>); here the range removes itself.
        // Teardown can free the document first, and the slab reissues its
        // address, so check it is still the document the range joined.
        if (internal.owner_document) |doc| {
            if (internal.owner_generation != 0 and
                runtime.SlabAllocator.generationOf(doc) == internal.owner_generation)
            {
                document_internals.unregisterRange(doc, instance);
            }
        }
        runtime.arenaOf(instance).destroy(InternalState, internal);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
/// DOM §5 - Range constructor
/// The new Range() constructor steps are to set this's start and end to
/// (current global object's associated Document, 0).
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // "the current global object's associated Document"
    const document = currentDocument(ctx) orelse return error.InvalidStateError;

    const instance = try init(ctx.allocator, State, &Range.vtable, ctx);
    errdefer deinit(instance);

    // Set this's start and end to (document, 0), and make it live.
    try collapseLive(instance, document, 0);

    return instance;
}

/// Set `range`'s start and end to (node, offset) and make it a live range of
/// node's node document. `dom.range_boundaries.collapseLive` is how Document's
/// createRange() reaches this; the constructor uses it directly.
fn collapseLive(range: *runtime.Instance, node: *runtime.Instance, offset: u32) anyerror!void {
    const internal = getInternal(range) orelse return error.InvalidStateError;
    const before = selectedBoundaries(internal);
    defer notifySelection(range, internal, before);
    defer keepContainers(range, internal);
    internal.start_container = node;
    internal.start_offset = offset;
    internal.end_container = node;
    internal.end_offset = offset;
    // A live range is registered with its node document so mutations move it.
    // A document is its own node document.
    const node_type = interfaces.Node.get_nodeType(node) catch return error.InvalidStateError;
    const document = if (node_type == interfaces.Node.get_DOCUMENT_NODE())
        node
    else
        (interfaces.Node.get_ownerDocument(node) catch null) orelse return;
    try joinDocument(internal, range, document);
}

/// Blink's Range::UpdateOwnerDocumentIfNeeded. A live range is kept in the
/// live-range list of its start node's node document, and a mutation walks
/// only the list of the document it happens in. When adoption moves the
/// range's boundary nodes to another document, the range moves lists with
/// them - or removing a node there would pass it by and leave it pointing at
/// a child that is gone.
fn updateOwnerDocument(range: *runtime.Instance) anyerror!void {
    const internal = getInternal(range) orelse return;
    const start = internal.start_container orelse return;
    const node_type = interfaces.Node.get_nodeType(start) catch return;
    const document = if (node_type == interfaces.Node.get_DOCUMENT_NODE())
        start
    else
        (interfaces.Node.get_ownerDocument(start) catch null) orelse return;

    const joined_live = if (internal.owner_document) |old|
        internal.owner_generation != 0 and runtime.SlabAllocator.generationOf(old) == internal.owner_generation
    else
        false;
    if (joined_live and internal.owner_document.? == document) return;
    if (joined_live) document_internals.unregisterRange(internal.owner_document.?, range);
    try joinDocument(internal, range, document);
}

/// Register `range` as one of `document`'s live ranges, remembering which
/// document it joined so `deinit` can leave again.
fn joinDocument(internal: *InternalState, range: *runtime.Instance, document: *runtime.Instance) !void {
    try document_internals.registerRange(document, range);
    internal.owner_document = document;
    internal.owner_generation = runtime.SlabAllocator.generationOf(document);
}

/// The current global object's associated Document: the realm's Window's
/// document.
fn currentDocument(ctx: runtime.Context) ?*runtime.Instance {
    const realm = ctx.realm orelse return null;
    const window_ptr = realm.global_object orelse return null;
    const window: *runtime.Instance = @ptrCast(@alignCast(window_ptr));
    return interfaces.Window.get_document(window) catch null;
}

// =============================================================================
// Range Attributes
// =============================================================================

/// DOM §5 - Range.commonAncestorContainer
/// Returns the node, furthest away from the document, that is an ancestor
/// of both range's start node and end node.
pub fn get_commonAncestorContainer(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    const start = internal.start_container orelse return error.InvalidStateError;
    const end = internal.end_container orelse return error.InvalidStateError;

    // "Let container be start node. While container is not an inclusive
    // ancestor of end node, let container be container's parent. Return
    // container." The same node in O(depth) (Meeting.of); a range's two
    // nodes share a root, so it is found.
    const meeting = Meeting.of(start, end) orelse return start;
    return meeting.ancestor;
}

// =============================================================================
// Range Mutation Methods
// =============================================================================

/// A node's length (DOM 4.2): 0 for a DocumentType or Attr node, the number
/// of code units of a CharacterData node's data, and otherwise the number of
/// its children.
fn getNodeLength(node: *runtime.Instance) u32 {
    const node_type = interfaces.Node.get_nodeType(node) catch return 0;
    if (node_type == interfaces.Node.get_DOCUMENT_TYPE_NODE() or node_type == interfaces.Node.get_ATTRIBUTE_NODE()) return 0;
    if (isCharacterData(node)) return interfaces.CharacterData.get_length(node) catch 0;
    var count: u32 = 0;
    var child = interfaces.Node.get_firstChild(node) catch null;
    while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) count += 1;
    return count;
}

/// Is `node` a CharacterData node: Text, CDATASection, ProcessingInstruction
/// or Comment?
fn isCharacterData(node: *runtime.Instance) bool {
    const node_type = interfaces.Node.get_nodeType(node) catch return false;
    return node_type == interfaces.Node.get_TEXT_NODE() or
        node_type == interfaces.Node.get_CDATA_SECTION_NODE() or
        node_type == interfaces.Node.get_PROCESSING_INSTRUCTION_NODE() or
        node_type == interfaces.Node.get_COMMENT_NODE();
}

/// The tree the boundary point algorithms walk (`dom.boundary_points`): a
/// node's parent and its index, read through the Node interface. "The index
/// of an object is its number of preceding siblings."
const DomTree = struct {
    pub const Node = *runtime.Instance;
    pub fn parent(node: Node) ?Node {
        return interfaces.Node.get_parentNode(node) catch null;
    }
    pub fn index(node: Node) u32 {
        var i: u32 = 0;
        var sibling = interfaces.Node.get_previousSibling(node) catch null;
        while (sibling) |s| : (sibling = interfaces.Node.get_previousSibling(s) catch null) i += 1;
        return i;
    }
};

/// Helper: Get the index of a child node within its parent
fn getChildIndex(parent: *runtime.Instance, child: *runtime.Instance) ?u32 {
    var current = interfaces.Node.get_firstChild(parent) catch null;
    var index: u32 = 0;

    while (current) |node| {
        if (node == child) return index;
        index += 1;
        current = interfaces.Node.get_nextSibling(node) catch null;
    }

    return null;
}

/// "A boundary point is after another boundary point, if its position
/// relative to it is after." Both nodes have the same root.
fn isAfter(nodeA: *runtime.Instance, offsetA: u32, nodeB: *runtime.Instance, offsetB: u32) bool {
    return compareBoundaryPoints(nodeA, offsetA, nodeB, offsetB) == .after;
}

/// A node's root: "the object's parent's root if it has a parent, and the
/// object itself otherwise."
fn getRoot(node: *runtime.Instance) *runtime.Instance {
    var current = node;
    while (DomTree.parent(current)) |parent| current = parent;
    return current;
}

/// Boundary point position comparison result
const BoundaryPointPosition = boundary_points.Position;

/// DOM 5.2: the position of the boundary point (node, offset) relative to
/// (otherNode, otherOffset). The nodes have the same root.
fn compareBoundaryPoints(
    node: *runtime.Instance,
    offset: u32,
    otherNode: *runtime.Instance,
    otherOffset: u32,
) BoundaryPointPosition {
    return boundary_points.position(DomTree, node, offset, otherNode, otherOffset);
}

/// DOM §5.3 - Range.setStart(node, offset)
/// Sets the start of the range to the given boundary point
pub fn call_setStart(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const previous_start = internal.start_container;
    const before = selectedBoundaries(internal);
    defer notifySelection(instance, internal, before);
    defer keepContainers(instance, internal);

    // Step 1: If node is a doctype, throw InvalidNodeTypeError
    if (interfaces.Node.get_nodeType(node) catch null) |nt| {
        if (nt == interfaces.Node.get_DOCUMENT_TYPE_NODE()) {
            return error.InvalidNodeTypeError;
        }
    }

    // Step 2: If offset > node's length, throw IndexSizeError
    const nodeLength = getNodeLength(node);
    if (offset > nodeLength) {
        return error.IndexSizeError;
    }

    // Step 4.1: If range's root is not equal to node's root, or if bp is after range's end
    const nodeRoot = getRoot(node);
    const end_container = internal.end_container orelse {
        // No end container yet, just set start
        internal.start_container = node;
        internal.start_offset = offset;
        if (internal.start_container != previous_start) try updateOwnerDocument(instance);
        return;
    };
    const rangeRoot = getRoot(end_container);

    if (nodeRoot != rangeRoot or isAfter(node, offset, end_container, internal.end_offset)) {
        // Set range's end to bp
        internal.end_container = node;
        internal.end_offset = offset;
    }

    // Step 4.2: Set range's start to bp
    internal.start_container = node;
    internal.start_offset = offset;
    // Only a changed container can change the node document during this
    // synchronous setter. Adoption already calls updateOwnerDocument through
    // range_boundaries. Avoid its lookup on offset-only changes (Q19).
    // A moved boundary must join the new live-range list so removals find it.
    // Blink Range::setStart/SetDocument:
    // https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/dom/range.cc
    if (internal.start_container != previous_start) try updateOwnerDocument(instance);
}

/// DOM §5.3 - Range.setEnd(node, offset)
/// Sets the end of the range to the given boundary point
pub fn call_setEnd(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const previous_start = internal.start_container;
    const before = selectedBoundaries(internal);
    defer notifySelection(instance, internal, before);
    defer keepContainers(instance, internal);

    // Step 1: If node is a doctype, throw InvalidNodeTypeError
    if (interfaces.Node.get_nodeType(node) catch null) |nt| {
        if (nt == interfaces.Node.get_DOCUMENT_TYPE_NODE()) {
            return error.InvalidNodeTypeError;
        }
    }

    // Step 2: If offset > node's length, throw IndexSizeError
    const nodeLength = getNodeLength(node);
    if (offset > nodeLength) {
        return error.IndexSizeError;
    }

    // Step 5.1: If range's root is not equal to node's root, or if bp is before range's start
    const nodeRoot = getRoot(node);
    const start_container = internal.start_container orelse {
        // No start container yet, just set end
        internal.end_container = node;
        internal.end_offset = offset;
        if (internal.start_container != previous_start) try updateOwnerDocument(instance);
        return;
    };
    const rangeRoot = getRoot(start_container);

    if (nodeRoot != rangeRoot or isAfter(start_container, internal.start_offset, node, offset)) {
        // Set range's start to bp
        internal.start_container = node;
        internal.start_offset = offset;
    }

    // Step 5.2: Set range's end to bp
    internal.end_container = node;
    internal.end_offset = offset;
    if (internal.start_container != previous_start) try updateOwnerDocument(instance);
}

/// DOM §5.3 - Range.setStartBefore(node)
/// Sets the start to immediately before the given node
pub fn call_setStartBefore(instance: *runtime.Instance, node: *runtime.Instance) anyerror!void {
    // Step 1: Let parent be node's parent
    const parent = (interfaces.Node.get_parentNode(node) catch null) orelse return error.InvalidNodeTypeError;

    // Step 2: If parent is null, throw InvalidNodeTypeError (already checked)

    // Step 3: Set start to boundary point (parent, node's index)
    const index = getChildIndex(parent, node) orelse return error.InvalidStateError;
    try call_setStart(instance, parent, index);
}

/// DOM §5.3 - Range.setStartAfter(node)
/// Sets the start to immediately after the given node
pub fn call_setStartAfter(instance: *runtime.Instance, node: *runtime.Instance) anyerror!void {
    // Step 1: Let parent be node's parent
    const parent = (interfaces.Node.get_parentNode(node) catch null) orelse return error.InvalidNodeTypeError;

    // Step 2: If parent is null, throw InvalidNodeTypeError (already checked)

    // Step 3: Set start to boundary point (parent, node's index + 1)
    const index = getChildIndex(parent, node) orelse return error.InvalidStateError;
    try call_setStart(instance, parent, index + 1);
}

/// DOM §5.3 - Range.setEndBefore(node)
/// Sets the end to immediately before the given node
pub fn call_setEndBefore(instance: *runtime.Instance, node: *runtime.Instance) anyerror!void {
    // Step 1: Let parent be node's parent
    const parent = (interfaces.Node.get_parentNode(node) catch null) orelse return error.InvalidNodeTypeError;

    // Step 2: If parent is null, throw InvalidNodeTypeError (already checked)

    // Step 3: Set end to boundary point (parent, node's index)
    const index = getChildIndex(parent, node) orelse return error.InvalidStateError;
    try call_setEnd(instance, parent, index);
}

/// DOM §5.3 - Range.setEndAfter(node)
/// Sets the end to immediately after the given node
pub fn call_setEndAfter(instance: *runtime.Instance, node: *runtime.Instance) anyerror!void {
    // Step 1: Let parent be node's parent
    const parent = (interfaces.Node.get_parentNode(node) catch null) orelse return error.InvalidNodeTypeError;

    // Step 2: If parent is null, throw InvalidNodeTypeError (already checked)

    // Step 3: Set end to boundary point (parent, node's index + 1)
    const index = getChildIndex(parent, node) orelse return error.InvalidStateError;
    try call_setEnd(instance, parent, index + 1);
}

/// DOM §5.3 - Range.collapse(toStart)
pub fn call_collapse(instance: *runtime.Instance, toStart: webidl.Opt(bool)) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const before = selectedBoundaries(internal);
    defer notifySelection(instance, internal, before);
    defer keepContainers(instance, internal);

    const collapse_to_start = if (toStart.was_passed) toStart.value else false;
    if (collapse_to_start) {
        internal.end_container = internal.start_container;
        internal.end_offset = internal.start_offset;
    } else {
        internal.start_container = internal.end_container;
        internal.start_offset = internal.end_offset;
    }
}

/// DOM §5.3 - Range.selectNode(node)
/// Selects the entire node and its contents
pub fn call_selectNode(instance: *runtime.Instance, node: *runtime.Instance) anyerror!void {
    // Step 1: Let parent be node's parent
    const parent = (interfaces.Node.get_parentNode(node) catch null) orelse return error.InvalidNodeTypeError;

    // Step 2: If parent is null, throw InvalidNodeTypeError (already checked)

    // Step 3: Let index be node's index
    const index = getChildIndex(parent, node) orelse return error.InvalidStateError;

    // Step 4: Set start to boundary point (parent, index)
    try call_setStart(instance, parent, index);

    // Step 5: Set end to boundary point (parent, index + 1)
    try call_setEnd(instance, parent, index + 1);
}

/// DOM §5.3 - Range.selectNodeContents(node)
pub fn call_selectNodeContents(instance: *runtime.Instance, node: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const previous_start = internal.start_container;
    const before = selectedBoundaries(internal);
    defer notifySelection(instance, internal, before);
    defer keepContainers(instance, internal);

    // If node is a doctype, throw InvalidNodeTypeError
    if (interfaces.Node.get_nodeType(node) catch null) |nt| {
        if (nt == interfaces.Node.get_DOCUMENT_TYPE_NODE()) {
            return error.InvalidNodeTypeError;
        }
    }

    const length = getNodeLength(node);
    internal.start_container = node;
    internal.start_offset = 0;
    internal.end_container = node;
    internal.end_offset = length;
    if (internal.start_container != previous_start) try updateOwnerDocument(instance);
}

/// DOM §5.5 - Range.compareBoundaryPoints(how, sourceRange)
pub fn call_compareBoundaryPoints(instance: *runtime.Instance, how: u16, sourceRange: *runtime.Instance) anyerror!i16 {
    // Step 1: Validate 'how' parameter
    if (how != START_TO_START and how != START_TO_END and how != END_TO_END and how != END_TO_START) {
        return error.NotSupportedError;
    }

    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const sourceInternal = getInternal(sourceRange) orelse return error.InvalidStateError;

    // Step 2: Check same root
    const start = internal.start_container orelse return error.InvalidStateError;
    const sourceStart = sourceInternal.start_container orelse return error.InvalidStateError;
    const thisRoot = getRoot(start);
    const sourceRoot = getRoot(sourceStart);

    if (thisRoot != sourceRoot) {
        return error.WrongDocumentError;
    }

    // Step 3: Determine boundary points based on 'how'
    const end = internal.end_container orelse return error.InvalidStateError;
    const sourceEnd = sourceInternal.end_container orelse return error.InvalidStateError;

    const thisPoint: struct { node: *runtime.Instance, offset: u32 } = switch (how) {
        START_TO_START => .{ .node = start, .offset = internal.start_offset },
        START_TO_END => .{ .node = end, .offset = internal.end_offset },
        END_TO_END => .{ .node = end, .offset = internal.end_offset },
        END_TO_START => .{ .node = start, .offset = internal.start_offset },
        else => return error.NotSupportedError,
    };

    const otherPoint: struct { node: *runtime.Instance, offset: u32 } = switch (how) {
        START_TO_START => .{ .node = sourceStart, .offset = sourceInternal.start_offset },
        START_TO_END => .{ .node = sourceStart, .offset = sourceInternal.start_offset },
        END_TO_END => .{ .node = sourceEnd, .offset = sourceInternal.end_offset },
        END_TO_START => .{ .node = sourceEnd, .offset = sourceInternal.end_offset },
        else => return error.NotSupportedError,
    };

    // Step 4: Compare positions
    const position = compareBoundaryPoints(
        thisPoint.node,
        thisPoint.offset,
        otherPoint.node,
        otherPoint.offset,
    );

    return switch (position) {
        .before => -1,
        .equal => 0,
        .after => 1,
    };
}

// =============================================================================
// Range Content Methods (DOM manipulation)
// =============================================================================

/// A range's boundary points, read once: the algorithms below take their
/// "original" start and end before they mutate anything, and walk subranges
/// that need no Range object of their own.
const Bounds = struct {
    start_node: *runtime.Instance,
    start_offset: u32,
    end_node: *runtime.Instance,
    end_offset: u32,

    fn of(internal: *const InternalState) ?Bounds {
        return .{
            .start_node = internal.start_container orelse return null,
            .start_offset = internal.start_offset,
            .end_node = internal.end_container orelse return null,
            .end_offset = internal.end_offset,
        };
    }

    /// "A range is collapsed if its start node is its end node and its start
    /// offset is its end offset."
    fn collapsed(self: Bounds) bool {
        return self.start_node == self.end_node and self.start_offset == self.end_offset;
    }
};

/// Where a range's start node and end node meet (DOM 5.5 "get the common
/// ancestor"): `ancestor` is the deepest inclusive ancestor of the start
/// node that is an inclusive ancestor of the end node; `start_child` is the
/// child of `ancestor` that is an inclusive ancestor of the start node (null
/// when the start node is `ancestor`), and `end_child` the same for the end
/// node.
///
/// Every question the contents algorithms ask of the tree follows from it in
/// O(1) - "is originalStartNode an inclusive ancestor of originalEndNode"
/// is `ancestor == start node`, the partially contained children of the
/// common ancestor are `start_child` and `end_child`, and a child of the
/// common ancestor is contained exactly when it lies strictly between them
/// (or past the start offset / before the end offset where a boundary node
/// is the common ancestor itself) - where the steps as written ask an
/// O(depth) ancestor question at each of up to depth parents, per child, per
/// level. Blink walks the same two paths (Range::ProcessContents:
/// HighestAncestorUnderCommonRoot, ChildOfCommonRootBeforeOffset).
const Meeting = struct {
    ancestor: *runtime.Instance,
    start_child: ?*runtime.Instance,
    end_child: ?*runtime.Instance,

    /// Both nodes' depths, then a climb in step: O(depth). Null for nodes in
    /// different trees.
    fn of(start: *runtime.Instance, end: *runtime.Instance) ?Meeting {
        var a = start;
        var b = end;
        var below_a: ?*runtime.Instance = null;
        var below_b: ?*runtime.Instance = null;
        var depth_a = depthOf(start);
        var depth_b = depthOf(end);
        while (depth_a > depth_b) : (depth_a -= 1) {
            below_a = a;
            a = DomTree.parent(a) orelse return null;
        }
        while (depth_b > depth_a) : (depth_b -= 1) {
            below_b = b;
            b = DomTree.parent(b) orelse return null;
        }
        while (a != b) {
            below_a = a;
            below_b = b;
            a = DomTree.parent(a) orelse return null;
            b = DomTree.parent(b) orelse return null;
        }
        return .{ .ancestor = a, .start_child = below_a, .end_child = below_b };
    }

    /// A subrange of a partially contained child: one of its boundary nodes
    /// (`outer`) is that child, an inclusive ancestor of the other - it was
    /// when the level above chose it. Found by climbing from the other node
    /// to it: O(the levels between), so a chain of subranges costs its
    /// depth once per level, not a depth walk per parent. Null when `outer`
    /// is no longer an inclusive ancestor of the other node: script ran
    /// between the levels (an iframe's unload as a node moved, a custom
    /// element reaction) and moved a node off the path.
    fn nested(bounds: Bounds, comptime outer: enum { start, end }) ?Meeting {
        const top = if (outer == .start) bounds.start_node else bounds.end_node;
        var at = if (outer == .start) bounds.end_node else bounds.start_node;
        var below: ?*runtime.Instance = null;
        while (at != top) {
            below = at;
            at = DomTree.parent(at) orelse return null;
        }
        return if (outer == .start)
            .{ .ancestor = top, .start_child = null, .end_child = below }
        else
            .{ .ancestor = top, .start_child = below, .end_child = null };
    }
};

/// The number of ancestors `node` has.
fn depthOf(node: *runtime.Instance) usize {
    var depth: usize = 0;
    var current = DomTree.parent(node);
    while (current) |c| : (current = DomTree.parent(c)) depth += 1;
    return depth;
}

/// A new DocumentFragment "whose node document is range's start node's node
/// document" - a document is its own node document.
fn fragmentFor(start_node: *runtime.Instance) !*runtime.Instance {
    const node_type = try interfaces.Node.get_nodeType(start_node);
    const document = if (node_type == interfaces.Node.get_DOCUMENT_NODE())
        start_node
    else
        (try interfaces.Node.get_ownerDocument(start_node)) orelse return error.InvalidStateError;
    return interfaces.Document.call_createDocumentFragment(document);
}

/// "Replace data of node with offset, count, and the empty string."
fn deleteData(node: *runtime.Instance, offset: u32, count: u32) !void {
    try interfaces.CharacterData.call_replaceData(node, offset, count, runtime.DOMString.initEmpty());
}

/// A clone of the CharacterData node `node` whose data is "the result of
/// substringing data of node with offset and count".
fn cloneWithSubstring(node: *runtime.Instance, offset: u32, count: u32) !*runtime.Instance {
    const clone = try interfaces.Node.call_cloneNode(node, webidl.Opt(bool).passed(false));
    var substring = try interfaces.CharacterData.call_substringData(node, offset, count);
    defer substring.deinit(node.ctx.allocator);
    try interfaces.CharacterData.set_data(clone, substring);
    return clone;
}

/// Append to `list` the children of `parent` from `first` (null: none) up to,
/// not including, `stop` (null: to its last child). An error when `stop` is
/// not among them - only possible were the range's start after its end.
fn appendChildrenBetween(allocator: std.mem.Allocator, list: *std.ArrayListUnmanaged(*runtime.Instance), first: ?*runtime.Instance, stop: ?*runtime.Instance) !void {
    var child = first;
    while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) {
        if (c == stop) return;
        try list.append(allocator, c);
    }
    if (stop != null) return error.InvalidStateError;
}

/// Steps shared by "extract" and "clone the contents" (5-11): the common
/// ancestor, the first and last partially contained children, and the
/// contained children.
const Split = struct {
    first_partially_contained: ?*runtime.Instance,
    last_partially_contained: ?*runtime.Instance,
    contained_children: std.ArrayListUnmanaged(*runtime.Instance),

    fn of(allocator: std.mem.Allocator, bounds: Bounds, meeting: Meeting) !Split {
        // Step 5: "Let commonAncestor be the result of getting the common
        // ancestor of range" - meeting.ancestor.
        const common = meeting.ancestor;

        // Steps 6-7: "If originalStartNode is not an inclusive ancestor of
        // originalEndNode, then set firstPartiallyContainedChild to the first
        // child of commonAncestor that is partially contained in range." A
        // child of commonAncestor is partially contained exactly when it is
        // an inclusive ancestor of one boundary node and not the other:
        // start_child or end_child, the start's first, as a range's start is
        // not after its end.
        const first: ?*runtime.Instance = if (common != bounds.start_node) meeting.start_child else null;

        // Steps 8-9: "If originalEndNode is not an inclusive ancestor of
        // originalStartNode, then set lastPartiallyContainedChild to the last
        // child of commonAncestor that is partially contained in range."
        const last: ?*runtime.Instance = if (common != bounds.end_node) meeting.end_child else null;

        // Step 10: "Let containedChildren be a list of all children of
        // commonAncestor that are contained in range, in tree order." A child
        // c is contained when (c, 0) is after the start - c follows
        // start_child, or, when the start node is commonAncestor, c's index
        // is at least the start offset - and (c, c's length) is before the
        // end: c precedes end_child, or its index is less than the end
        // offset. That is one run of children.
        var contained: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
        errdefer contained.deinit(allocator);
        const from = if (first) |f| interfaces.Node.get_nextSibling(f) catch null else childAt(common, bounds.start_offset);
        const stop = last orelse childAt(common, bounds.end_offset);
        try appendChildrenBetween(allocator, &contained, from, stop);

        // Step 11: "If any member of containedChildren is a doctype, then
        // throw a "HierarchyRequestError" DOMException."
        for (contained.items) |c| {
            if ((interfaces.Node.get_nodeType(c) catch 0) == interfaces.Node.get_DOCUMENT_TYPE_NODE()) {
                return error.HierarchyRequestError;
            }
        }

        return .{
            .first_partially_contained = first,
            .last_partially_contained = last,
            .contained_children = contained,
        };
    }

    fn deinit(self: *Split, allocator: std.mem.Allocator) void {
        self.contained_children.deinit(allocator);
    }
};

/// Where "deleteContents" (steps 5-7) and "extract" (steps 12-14) collapse
/// the range: originalStartNode itself when it is an inclusive ancestor of
/// originalEndNode, else just after its ancestor that is a child of the
/// common ancestor.
fn collapsePoint(bounds: Bounds, meeting: Meeting) struct { node: *runtime.Instance, offset: u32 } {
    // "If originalStartNode is an inclusive ancestor of originalEndNode, then
    // set newNode to originalStartNode and newOffset to originalStartOffset."
    const reference = meeting.start_child orelse return .{ .node = bounds.start_node, .offset = bounds.start_offset };
    // "Otherwise: let referenceNode be originalStartNode. While
    // referenceNode's parent is non-null and is not an inclusive ancestor of
    // originalEndNode: set referenceNode to its parent. Set newNode to the
    // parent of referenceNode, and newOffset to referenceNode's index + 1."
    // The first inclusive ancestor of originalStartNode whose parent is an
    // inclusive ancestor of originalEndNode is the common ancestor's child
    // on its path: start_child.
    return .{ .node = meeting.ancestor, .offset = DomTree.index(reference) + 1 };
}

/// "The nodes that are contained in" the range, "in tree order, omitting any
/// node whose parent is also contained" (deleteContents step 4; the roots of
/// what toString's step 4 reads). A contained node's descendants are all
/// contained, and the nodes partially contained are the ancestors of the
/// boundary nodes below the common ancestor, so the contained nodes whose
/// parent is not contained are children of a partially contained node or of
/// the common ancestor: on the start's side the children after the path to
/// the start (the start node's own from its offset), deepest level first; the
/// common ancestor's contained children (Split's run); on the end's side the
/// children before the path to the end (the end node's own up to its
/// offset), top level first. O(depth + the nodes listed), where a walk
/// asking "contained?" and "partially contained?" of each node pays a depth
/// walk per node.
fn containedRoots(allocator: std.mem.Allocator, bounds: Bounds, meeting: Meeting) !std.ArrayListUnmanaged(*runtime.Instance) {
    var list: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    errdefer list.deinit(allocator);

    // The start's side, when the start node is below the common ancestor.
    if (meeting.start_child) |top| {
        try appendChildrenBetween(allocator, &list, childAt(bounds.start_node, bounds.start_offset), null);
        var at = bounds.start_node;
        while (at != top) : (at = DomTree.parent(at) orelse return error.InvalidStateError) {
            try appendChildrenBetween(allocator, &list, interfaces.Node.get_nextSibling(at) catch null, null);
        }
    }

    // The common ancestor's children.
    const from = if (meeting.start_child) |f| interfaces.Node.get_nextSibling(f) catch null else childAt(meeting.ancestor, bounds.start_offset);
    const stop = meeting.end_child orelse childAt(meeting.ancestor, bounds.end_offset);
    try appendChildrenBetween(allocator, &list, from, stop);

    // The end's side, top level first: the path from end_child down to the
    // end node, read bottom-up into `path`.
    if (meeting.end_child) |top| {
        var path: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
        defer path.deinit(allocator);
        var at = bounds.end_node;
        while (true) : (at = DomTree.parent(at) orelse return error.InvalidStateError) {
            try path.append(allocator, at);
            if (at == top) break;
        }
        var level = path.items.len;
        while (level > 1) {
            level -= 1;
            const parent = path.items[level];
            try appendChildrenBetween(allocator, &list, interfaces.Node.get_firstChild(parent) catch null, path.items[level - 1]);
        }
        try appendChildrenBetween(allocator, &list, interfaces.Node.get_firstChild(bounds.end_node) catch null, childAt(bounds.end_node, bounds.end_offset));
    }
    return list;
}

/// DOM 5.5 "The deleteContents() method steps".
pub fn call_deleteContents(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const before = selectedBoundaries(internal);
    defer notifySelection(instance, internal, before);
    defer keepContainers(instance, internal);
    // Step 2: "Let originalStartNode, originalStartOffset, originalEndNode,
    // and originalEndOffset be this's start node, start offset, end node, and
    // end offset, respectively."
    const bounds = Bounds.of(internal) orelse return error.InvalidStateError;

    // Step 1: "If this is collapsed, then return."
    if (bounds.collapsed()) return;

    // Step 3: "If originalStartNode is originalEndNode and it is a
    // CharacterData node: replace data of originalStartNode with
    // originalStartOffset, originalEndOffset - originalStartOffset, and the
    // empty string; return."
    if (bounds.start_node == bounds.end_node and isCharacterData(bounds.start_node)) {
        return deleteData(bounds.start_node, bounds.start_offset, bounds.end_offset - bounds.start_offset);
    }

    // Step 4: "Let nodesToRemove be a list of all the nodes that are
    // contained in this, in tree order, omitting any node whose parent is
    // also contained in this."
    const allocator = instance.ctx.allocator;
    const meeting = Meeting.of(bounds.start_node, bounds.end_node) orelse return error.InvalidStateError;
    var nodes_to_remove = try containedRoots(allocator, bounds, meeting);
    defer nodes_to_remove.deinit(allocator);

    // Steps 5-7: newNode and newOffset.
    const collapse_to = collapsePoint(bounds, meeting);

    // Step 8: "Set this's start and end to (newNode, newOffset)." Before the
    // removals, as the steps order it: the removals that follow never move
    // that point (it is the common ancestor, past every boundary path, or
    // the start node with every removed child at or after its offset), but
    // script they run (an iframe's unload) sees the range already collapsed.
    internal.start_container = collapse_to.node;
    internal.start_offset = collapse_to.offset;
    internal.end_container = collapse_to.node;
    internal.end_offset = collapse_to.offset;

    // Step 9: "If originalStartNode is a CharacterData node, then replace data
    // of originalStartNode with originalStartOffset, originalStartNode's
    // length - originalStartOffset, and the empty string."
    if (isCharacterData(bounds.start_node)) {
        try deleteData(bounds.start_node, bounds.start_offset, getNodeLength(bounds.start_node) - bounds.start_offset);
    }

    // Step 10: "For each node of nodesToRemove, in tree order: remove node."
    for (nodes_to_remove.items) |node| {
        const parent = DomTree.parent(node) orelse continue;
        _ = try interfaces.Node.call_removeChild(parent, node);
    }

    // Step 11: "If originalEndNode is a CharacterData node, then replace data
    // of originalEndNode with 0, originalEndOffset, and the empty string."
    if (isCharacterData(bounds.end_node)) {
        try deleteData(bounds.end_node, 0, bounds.end_offset);
    }
}

/// The node after `node` in tree order, below `root`, that is not one of its
/// descendants.
fn nextSkippingChildren(node: *runtime.Instance, root: *runtime.Instance) ?*runtime.Instance {
    var current = node;
    while (current != root) {
        if (interfaces.Node.get_nextSibling(current) catch null) |next| return next;
        current = DomTree.parent(current) orelse return null;
    }
    return null;
}

/// What a contents algorithm does with the nodes it reaches: DOM 5.5
/// "extract" (move them out, cutting the boundary data) or "clone the
/// contents" (copy them) - Blink's Range::ActionType.
const ContentsAction = enum { extract, clone };

/// How a level finds its common ancestor: the range itself from both
/// boundary nodes; a subrange from the partially contained child that is
/// one of its boundary nodes.
const Nesting = enum { range, first_child, last_child };

/// One level of "extract" or "clone the contents": the range itself, or the
/// subrange of a partially contained child, whose own subrange is the next
/// level. The spec's algorithms recurse here (extract steps 17.3-17.4 and
/// 20.3-20.4; clone the contents steps 14.3-14.4 and 17.3-17.4), once per
/// level between a boundary node and the common ancestor, so they hand the
/// page the native stack's depth; the levels live on the heap instead
/// (`processContents`), each doing its steps in the order the recursion
/// does.
const ContentsLevel = struct {
    bounds: Bounds,
    /// Step 1's fragment: what the level hands back.
    fragment: *runtime.Instance,
    split: Split,
    /// The clone of the partially contained child whose subrange the level
    /// below is processing: that level's fragment is appended to it (steps
    /// 17.5 / 20.5; 14.4 / 17.4) when it returns.
    clone: ?*runtime.Instance = null,
    /// Where the level resumes: its first partially contained child (steps
    /// 16-17 / 12-14), its contained children and last partially contained
    /// child (18-20 / 15-17), or the return (21 / 18).
    step: enum { first_child, contained, done } = .first_child,
};

/// DOM 5.5 "extract" a live range (`action` .extract) or "clone the
/// contents" of one (.clone), given by its boundary points. `range` is the
/// live range itself, whose start and end extract's step 15 sets; null for
/// a clone.
///
/// The spec's recursion over subranges, run over a heap stack of levels:
/// a partially contained child's subrange is a level pushed where the steps
/// recurse, and the level below it resumes, with that subrange's fragment,
/// where the recursive call returns. Every DOM operation happens in the
/// order the recursion performs it, and each level reads the tree where the
/// recursion does, so the result is the steps' result. Blink's
/// Range::ProcessContents keeps the ancestors of each boundary node in a
/// vector instead of recursing (ProcessAncestorsAndTheirSiblings), and
/// Gecko's nsRange::CutContents / CloneContents walk a RangeSubtreeIterator,
/// rebuilding the clone ancestors from an explicit parent stack
/// (CloneParentsBetween); both visit the levels bottom-up, while these are
/// the spec's own steps.
fn processContents(comptime action: ContentsAction, allocator: std.mem.Allocator, bounds: Bounds, range: ?*InternalState) anyerror!*runtime.Instance {
    var levels: std.ArrayListUnmanaged(ContentsLevel) = .empty;
    defer {
        for (levels.items) |*level| level.split.deinit(allocator);
        levels.deinit(allocator);
    }
    if (try enterContentsLevel(action, allocator, &levels, bounds, .range, range)) |fragment| return fragment;

    while (true) {
        const level = &levels.items[levels.items.len - 1];
        switch (level.step) {
            .first_child => {
                level.step = .contained;
                const first = level.split.first_partially_contained orelse continue;
                const start_node = level.bounds.start_node;
                const start_offset = level.bounds.start_offset;
                if (isCharacterData(first)) {
                    // Extract step 16 / clone step 12: firstPartiallyContainedChild
                    // is originalStartNode. "Let clone be a clone of
                    // originalStartNode", holding its data from
                    // originalStartOffset to its end; append it to fragment
                    // (and, extracting, replace that data with the empty
                    // string).
                    // Saturating: script an earlier level ran (a reaction
                    // to a clone) may have shortened the data; replace data
                    // then throws IndexSizeError, as the steps would.
                    const count = getNodeLength(start_node) -| start_offset;
                    const clone = try cloneWithSubstring(start_node, start_offset, count);
                    _ = try interfaces.Node.call_appendChild(level.fragment, clone);
                    if (action == .extract) try deleteData(start_node, start_offset, count);
                    continue;
                }
                // Steps 17.1-17.2 / 14.1-14.2: "Let clone be a clone of
                // firstPartiallyContainedChild. Append clone to fragment."
                const clone = try interfaces.Node.call_cloneNode(first, webidl.Opt(bool).passed(false));
                _ = try interfaces.Node.call_appendChild(level.fragment, clone);
                level.clone = clone;
                // Steps 17.3-17.4 / 14.3: the subrange from
                // (originalStartNode, originalStartOffset) to
                // (firstPartiallyContainedChild, its length), processed into
                // a subfragment.
                const sub: Bounds = .{ .start_node = start_node, .start_offset = start_offset, .end_node = first, .end_offset = getNodeLength(first) };
                if (try enterContentsLevel(action, allocator, &levels, sub, .first_child, null)) |subfragment| {
                    // Step 17.5 / 14.4: "Append subfragment to clone."
                    _ = try interfaces.Node.call_appendChild(clone, subfragment);
                }
            },
            .contained => {
                level.step = .done;
                const fragment = level.fragment;
                // Extract step 18: "For each contained child of
                // containedChildren: append contained child to fragment."
                // Clone step 15: "let clone be a clone of contained child
                // with subtree set to true; append clone to fragment."
                for (level.split.contained_children.items) |child| {
                    const node = if (action == .extract) child else try interfaces.Node.call_cloneNode(child, webidl.Opt(bool).passed(true));
                    _ = try interfaces.Node.call_appendChild(fragment, node);
                }
                const last = level.split.last_partially_contained orelse continue;
                const end_node = level.bounds.end_node;
                const end_offset = level.bounds.end_offset;
                if (isCharacterData(last)) {
                    // Extract step 19 / clone step 16: lastPartiallyContainedChild
                    // is originalEndNode. A clone holding its data up to
                    // originalEndOffset, appended to fragment (and, extracting,
                    // that data replaced with the empty string).
                    const clone = try cloneWithSubstring(end_node, 0, end_offset);
                    _ = try interfaces.Node.call_appendChild(fragment, clone);
                    if (action == .extract) try deleteData(end_node, 0, end_offset);
                    continue;
                }
                // Steps 20.1-20.2 / 17.1-17.2.
                const clone = try interfaces.Node.call_cloneNode(last, webidl.Opt(bool).passed(false));
                _ = try interfaces.Node.call_appendChild(fragment, clone);
                level.clone = clone;
                // Steps 20.3-20.4 / 17.3: the subrange from
                // (lastPartiallyContainedChild, 0) to (originalEndNode,
                // originalEndOffset).
                const sub: Bounds = .{ .start_node = last, .start_offset = 0, .end_node = end_node, .end_offset = end_offset };
                if (try enterContentsLevel(action, allocator, &levels, sub, .last_child, null)) |subfragment| {
                    // Step 20.5 / 17.4.
                    _ = try interfaces.Node.call_appendChild(clone, subfragment);
                }
            },
            .done => {
                // Step 21 / 18: "Return fragment" - to the level above, whose
                // clone takes it (17.5 / 20.5; 14.4 / 17.4).
                const fragment = level.fragment;
                level.split.deinit(allocator);
                levels.items.len -= 1;
                if (levels.items.len == 0) return fragment;
                const parent = &levels.items[levels.items.len - 1];
                const clone = parent.clone orelse return error.InvalidStateError;
                parent.clone = null;
                _ = try interfaces.Node.call_appendChild(clone, fragment);
            },
        }
    }
}

/// Steps 1-15 of "extract" (1-11 of "clone the contents") for one level.
/// Answers the fragment when the steps return it early (steps 2 and 4);
/// otherwise pushes the level onto `levels`, to resume at its first
/// partially contained child.
fn enterContentsLevel(
    comptime action: ContentsAction,
    allocator: std.mem.Allocator,
    levels: *std.ArrayListUnmanaged(ContentsLevel),
    bounds: Bounds,
    comptime nesting: Nesting,
    range: ?*InternalState,
) anyerror!?*runtime.Instance {
    // Step 1: "Let fragment be the result of creating a document fragment
    // given range's start node's node document."
    const fragment = try fragmentFor(bounds.start_node);

    // Step 2: "If range is collapsed, then return fragment."
    if (bounds.collapsed()) return fragment;

    // Step 3: originalStartNode, originalStartOffset, originalEndNode and
    // originalEndOffset are `bounds`.

    // Step 4: "If originalStartNode is originalEndNode and it is a
    // CharacterData node:"
    if (bounds.start_node == bounds.end_node and isCharacterData(bounds.start_node)) {
        const count = bounds.end_offset - bounds.start_offset;
        // Steps 4.1-4.3: a clone holding the substring, appended to fragment.
        const clone = try cloneWithSubstring(bounds.start_node, bounds.start_offset, count);
        _ = try interfaces.Node.call_appendChild(fragment, clone);
        // Extract step 4.4: "Replace data of originalStartNode with
        // originalStartOffset, originalEndOffset - originalStartOffset, and
        // the empty string." Its live-range steps collapse range.
        if (action == .extract) try deleteData(bounds.start_node, bounds.start_offset, count);
        // Step 4.5 / 4.4: "Return fragment."
        return fragment;
    }

    // Step 5: the common ancestor. A subrange's is the partially contained
    // child it was made for, unless script has moved the path since; then
    // there is no such subrange to process, and the steps' "get the common
    // ancestor" would walk off a root (Gecko's CutContents throws when a
    // mutation invalidates its iterator, ValidateCurrentNode).
    const meeting = switch (nesting) {
        .range => Meeting.of(bounds.start_node, bounds.end_node),
        .first_child => Meeting.nested(bounds, .end),
        .last_child => Meeting.nested(bounds, .start),
    } orelse return error.InvalidStateError;

    // Steps 6-11.
    var split = try Split.of(allocator, bounds, meeting);
    errdefer split.deinit(allocator);

    // Extract steps 12-15: "Set range's start and end to (newNode,
    // newOffset)", before anything moves. Only the range itself: a
    // subrange is a range nothing else can reach, and its own steps read its
    // boundary points (step 3) before they set them.
    if (action == .extract) {
        if (range) |internal| {
            const point = collapsePoint(bounds, meeting);
            internal.start_container = point.node;
            internal.start_offset = point.offset;
            internal.end_container = point.node;
            internal.end_offset = point.offset;
        }
    }

    try levels.append(allocator, .{ .bounds = bounds, .fragment = fragment, .split = split });
    return null;
}

/// Extract `instance`: DOM 5.5 "extract" a live range.
fn extractThis(instance: *runtime.Instance, internal: *InternalState) anyerror!*runtime.Instance {
    const before = selectedBoundaries(internal);
    defer notifySelection(instance, internal, before);
    defer keepContainers(instance, internal);
    const bounds = Bounds.of(internal) orelse return error.InvalidStateError;
    return processContents(.extract, instance.ctx.allocator, bounds, internal);
}

/// DOM 5.5: "The extractContents() method steps are to return the result of
/// extracting this."
pub fn call_extractContents(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return extractThis(instance, internal);
}

/// DOM 5.5: "The cloneContents() method steps are to return the result of
/// cloning the contents of this."
pub fn call_cloneContents(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const bounds = Bounds.of(internal) orelse return error.InvalidStateError;
    return processContents(.clone, instance.ctx.allocator, bounds, null);
}

/// DOM 5.5 "insert" a node into a live range; insertNode(node)'s steps.
pub fn call_insertNode(instance: *runtime.Instance, node: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const before = selectedBoundaries(internal);
    defer notifySelection(instance, internal, before);
    defer keepContainers(instance, internal);
    const start = internal.start_container orelse return error.InvalidStateError;
    const start_offset = internal.start_offset;
    const start_type = try interfaces.Node.get_nodeType(start);
    // A CDATASection is a Text node too.
    const start_is_text = start_type == interfaces.Node.get_TEXT_NODE() or start_type == interfaces.Node.get_CDATA_SECTION_NODE();

    // Step 1: "If range's start node is a ProcessingInstruction or Comment
    // node, is a Text node whose parent is null, or is node, then throw a
    // "HierarchyRequestError" DOMException."
    if (start_type == interfaces.Node.get_PROCESSING_INSTRUCTION_NODE() or
        start_type == interfaces.Node.get_COMMENT_NODE() or
        (start_is_text and DomTree.parent(start) == null) or
        start == node)
    {
        return error.HierarchyRequestError;
    }

    // Steps 2-4: referenceNode is the start node if it is a Text node,
    // otherwise its child at the start offset, or null.
    var reference: ?*runtime.Instance = if (start_is_text) start else childAt(start, start_offset);

    // Step 5: "Let parent be range's start node if referenceNode is null;
    // otherwise referenceNode's parent."
    const parent = if (reference) |r| DomTree.parent(r) orelse return error.HierarchyRequestError else start;

    // Step 6: "Ensure pre-insert validity of node into parent before
    // referenceNode" - before step 7 splits anything.
    {
        const node_base = dom.instance_bridge.getNodeBase(@ptrCast(node)) orelse return error.InvalidStateError;
        const parent_base = dom.instance_bridge.getNodeBase(@ptrCast(parent)) orelse return error.InvalidStateError;
        const reference_base: ?*dom.NodeBase = if (reference) |r| dom.instance_bridge.getNodeBase(@ptrCast(r)) else null;
        try dom.mutation.ensurePreInsertValidity(node_base, parent_base, reference_base);
    }

    // Step 7: "If range's start node is a Text node, set referenceNode to
    // the result of splitting it with offset range's start offset" - at
    // offset 0 too, which leaves an empty Text node before the insertion.
    if (start_is_text) reference = try interfaces.Text.call_splitText(start, start_offset);

    // Step 8: "If node is referenceNode, set referenceNode to its next
    // sibling."
    if (reference == node) reference = interfaces.Node.get_nextSibling(node) catch null;

    // Step 9: "If node's parent is non-null, then remove node."
    if (DomTree.parent(node)) |old_parent| _ = try interfaces.Node.call_removeChild(old_parent, node);

    // Step 10: "Let newOffset be parent's length if referenceNode is null;
    // otherwise referenceNode's index."
    var new_offset: u32 = if (reference) |r| DomTree.index(r) else getNodeLength(parent);

    // Step 11: "Increase newOffset by node's length if node is a
    // DocumentFragment node; otherwise 1."
    new_offset += if ((try interfaces.Node.get_nodeType(node)) == interfaces.Node.get_DOCUMENT_FRAGMENT_NODE()) getNodeLength(node) else 1;

    // Step 12: "Pre-insert node into parent before referenceNode."
    _ = try interfaces.Node.call_insertBefore(parent, node, reference);

    // Step 13: "If range is collapsed, then set range's end to (parent,
    // newOffset)."
    if (internal.start_container == internal.end_container and internal.start_offset == internal.end_offset) {
        internal.end_container = parent;
        internal.end_offset = new_offset;
    }
}

/// `node`'s child at `index`, or null.
fn childAt(node: *runtime.Instance, index: u32) ?*runtime.Instance {
    var i: u32 = 0;
    var child = interfaces.Node.get_firstChild(node) catch null;
    while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) {
        if (i == index) return c;
        i += 1;
    }
    return null;
}

/// DOM 5.5 "The surroundContents(newParent) method steps".
pub fn call_surroundContents(instance: *runtime.Instance, newParent: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const bounds = Bounds.of(internal) orelse return error.InvalidStateError;

    // Step 1: "If a non-Text node is partially contained in this, then throw
    // an "InvalidStateError" DOMException." The partially contained nodes
    // are the inclusive ancestors of either boundary node that are not
    // inclusive ancestors of the other: each boundary node's path up to, and
    // including, the common ancestor's child on it.
    const meeting = Meeting.of(bounds.start_node, bounds.end_node) orelse return error.InvalidStateError;
    for ([_]struct { *runtime.Instance, ?*runtime.Instance }{ .{ bounds.start_node, meeting.start_child }, .{ bounds.end_node, meeting.end_child } }) |side| {
        const top = side[1] orelse continue;
        var node = side[0];
        while (true) : (node = DomTree.parent(node) orelse return error.InvalidStateError) {
            // CDATASection implements Text too (the interface, not just type 3).
            if (!isText(node)) return error.InvalidStateError;
            if (node == top) break;
        }
    }

    // Step 2: "If newParent is a Document, DocumentType, or DocumentFragment
    // node, then throw an "InvalidNodeTypeError" DOMException."
    const new_parent_type = try interfaces.Node.get_nodeType(newParent);
    if (new_parent_type == interfaces.Node.get_DOCUMENT_NODE() or
        new_parent_type == interfaces.Node.get_DOCUMENT_TYPE_NODE() or
        new_parent_type == interfaces.Node.get_DOCUMENT_FRAGMENT_NODE())
    {
        return error.InvalidNodeTypeError;
    }

    // Step 3: "Let fragment be the result of extracting this."
    const fragment = try extractThis(instance, internal);

    // Step 4: "If newParent has children, then replace all with null within
    // newParent." One tree mutation record for all of them.
    if (interfaces.Node.get_firstChild(newParent) catch null) |_| {
        const new_parent_base = dom.instance_bridge.getNodeBase(@ptrCast(newParent)) orelse return error.InvalidStateError;
        try dom.mutation.replaceAll(@as(?*dom.NodeBase, null), new_parent_base);
    }

    // Step 5: "Insert newParent into this."
    try call_insertNode(instance, newParent);

    // Step 6: "Append fragment to newParent."
    _ = try interfaces.Node.call_appendChild(newParent, fragment);

    // Step 7: "Select newParent within this."
    try call_selectNode(instance, newParent);
}

/// DOM §5 - Range.cloneRange()
pub fn call_cloneRange(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Create new range with same boundary points
    const newRange = init(internal.allocator, State, &Range.vtable, instance.ctx) catch return error.OutOfMemory;
    errdefer deinit(newRange);

    const newInternal = getInternal(newRange) orelse return error.InvalidStateError;
    newInternal.start_container = internal.start_container;
    newInternal.start_offset = internal.start_offset;
    newInternal.end_container = internal.end_container;
    newInternal.end_offset = internal.end_offset;
    keepContainers(newRange, newInternal);

    // The clone is a live range too, in the same document.
    if (internal.owner_document) |doc| {
        if (runtime.SlabAllocator.generationOf(doc) == internal.owner_generation) {
            try joinDocument(newInternal, newRange, doc);
        }
    }

    return newRange;
}

/// DOM §5 - Range.detach()
/// Does nothing. Kept for compatibility.
pub fn call_detach(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    // Historical artifact - does nothing per spec
}

// =============================================================================
// Range Point Methods
// =============================================================================

/// DOM §5 - Range.isPointInRange(node, offset)
pub fn call_isPointInRange(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: Check if node's root is different from this's root
    const start = internal.start_container orelse return error.InvalidStateError;
    const nodeRoot = getRoot(node);
    const thisRoot = getRoot(start);
    if (nodeRoot != thisRoot) {
        return false;
    }

    // Step 2: If node is a doctype, throw error
    if (interfaces.Node.get_nodeType(node) catch null) |nt| {
        if (nt == interfaces.Node.get_DOCUMENT_TYPE_NODE()) {
            return error.InvalidNodeTypeError;
        }
    }

    // Step 3: If offset is greater than node's length, throw error
    const nodeLength = getNodeLength(node);
    if (offset > nodeLength) {
        return error.IndexSizeError;
    }

    // Step 4: Check if (node, offset) is before start or after end
    const end = internal.end_container orelse return error.InvalidStateError;
    const positionVsStart = compareBoundaryPoints(node, offset, start, internal.start_offset);
    const positionVsEnd = compareBoundaryPoints(node, offset, end, internal.end_offset);

    if (positionVsStart == .before or positionVsEnd == .after) {
        return false;
    }

    return true;
}

/// DOM §5 - Range.comparePoint(node, offset)
pub fn call_comparePoint(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) anyerror!i16 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: Check if node's root is different from this's root
    const start = internal.start_container orelse return error.InvalidStateError;
    const nodeRoot = getRoot(node);
    const thisRoot = getRoot(start);
    if (nodeRoot != thisRoot) {
        return error.WrongDocumentError;
    }

    // Step 2: If node is a doctype, throw error
    if (interfaces.Node.get_nodeType(node) catch null) |nt| {
        if (nt == interfaces.Node.get_DOCUMENT_TYPE_NODE()) {
            return error.InvalidNodeTypeError;
        }
    }

    // Step 3: If offset is greater than node's length, throw error
    const nodeLength = getNodeLength(node);
    if (offset > nodeLength) {
        return error.IndexSizeError;
    }

    // Step 4: If (node, offset) is before start, return -1
    const positionVsStart = compareBoundaryPoints(node, offset, start, internal.start_offset);
    if (positionVsStart == .before) {
        return -1;
    }

    // Step 5: If (node, offset) is after end, return 1
    const end = internal.end_container orelse return error.InvalidStateError;
    const positionVsEnd = compareBoundaryPoints(node, offset, end, internal.end_offset);
    if (positionVsEnd == .after) {
        return 1;
    }

    return 0;
}

/// DOM §5 - Range.intersectsNode(node)
/// Returns true if the node intersects with the range
pub fn call_intersectsNode(instance: *runtime.Instance, node: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: Check if node's root is different from this's root
    const start = internal.start_container orelse return error.InvalidStateError;
    const nodeRoot = getRoot(node);
    const thisRoot = getRoot(start);
    if (nodeRoot != thisRoot) {
        return false;
    }

    // Step 2: Let parent be node's parent
    const parent = (interfaces.Node.get_parentNode(node) catch null) orelse {
        // Step 3: If parent is null, return true
        return true;
    };

    // Step 4: Let offset be node's index
    const offset = getChildIndex(parent, node) orelse return false;

    // Step 5: Check if (parent, offset) is before end AND (parent, offset+1) is after start
    const end = internal.end_container orelse return error.InvalidStateError;

    const beforeEnd = compareBoundaryPoints(parent, offset, end, internal.end_offset);
    const afterStart = compareBoundaryPoints(parent, offset + 1, start, internal.start_offset);

    // Step 5: If (parent, offset) is before end and (parent, offset + 1)
    // is after start, then return true. Both comparisons are strict.
    if (beforeEnd == .before and afterStart == .after) {
        return true;
    }

    // Step 6: Return false.
    return false;
}

// =============================================================================
// CSSOM View Methods (layout-related)
// =============================================================================

/// CSSOM View - Range.getClientRects()
/// Returns a DOMRectList representing the area of the screen occupied by the range
/// Note: Requires layout engine integration
pub fn call_getClientRects(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    // NOTE: Full implementation requires layout engine
    // DOMRectList is a sequence of DOMRect objects representing client rectangles
    return error.NotImplemented;
}

/// CSSOM View - Range.getBoundingClientRect()
/// Returns a DOMRect representing the bounding rectangle of the range
/// Note: Requires layout engine integration
pub fn call_getBoundingClientRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    // NOTE: Full implementation requires layout engine
    // Would return a DOMRect with x, y, width, height of the bounding box
    return error.NotImplemented;
}

/// HTML 8.5.7 - Range.createContextualFragment(string): `string` parsed as a
/// fragment in the context of this range's start node, with the Fragment
/// scripting mode - its scripts run when the fragment is inserted.
///
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-range-createcontextualfragment
pub fn call_createContextualFragment(instance: *runtime.Instance, string: typedefs.TrustedHTMLOrDOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Step 1: "Let compliantString be the result of invoking the get trusted
    // type compliant string algorithm with TrustedHTML, this's relevant
    // global object, string, "Range createContextualFragment", and
    // "script"."
    const allocator = instance.ctx.allocator;
    const compliant = try dom.trusted_types.compliantStringFor(allocator, .html, instance, string, "Range createContextualFragment");
    defer allocator.free(compliant);

    // Step 2: "Let node be this's start node."
    const node = internal.start_container orelse return error.InvalidStateError;

    // Steps 3-5: "Let element be null. If node implements Element, set
    // element to node. Otherwise, if node implements Text or Comment, set
    // element to node's parent element."
    var element: ?*runtime.Instance = null;
    if (node.stateAs(interfaces.Element.State) != null) {
        element = node;
    } else if (node.stateAs(interfaces.Text.State) != null or node.stateAs(interfaces.Comment.State) != null) {
        element = try interfaces.Node.get_parentElement(node);
    }

    // Step 6: "If element is null or all of the following are true -
    // element's node document is an HTML document, element's local name is
    // "html", and element's namespace is the HTML namespace - then set
    // element to the result of creating an element given this's node
    // document, "body", and the HTML namespace." A range has no node
    // document of its own: its start node's is the one it lives in (Blink's
    // Range::owner_document_).
    const html_namespace = "http://www.w3.org/1999/xhtml";
    const replace = if (element) |value| blk: {
        const document = (try interfaces.Node.get_ownerDocument(value)) orelse break :blk false;
        if (document_internals.getDocumentType(document) != .html) break :blk false;
        const names = dom.node_creation.elementNames(value) orelse break :blk false;
        const namespace = names.namespace orelse break :blk false;
        break :blk std.mem.eql(u8, names.local_name, "html") and std.mem.eql(u8, namespace, html_namespace);
    } else true;
    var created: ?*runtime.Instance = null;
    defer if (created) |body| dom.node_creation.destroyUninserted(body);
    if (replace) {
        const document = if (node.stateAs(interfaces.Document.State) != null)
            node
        else
            (try interfaces.Node.get_ownerDocument(node)) orelse return error.InvalidStateError;
        created = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned(html_namespace), runtime.DOMString.initInterned("body"), .notPassed());
        element = created;
    }

    // Step 7: "Return the result of invoking the fragment parsing algorithm
    // steps with element, compliantString, and Fragment." The body made in
    // step 6 is only the context: nothing keeps it.
    const fragment = try @import("html").dom_parser.parseFragmentIn(allocator, instance.ctx, compliant, element.?, .fragment);
    errdefer dom.node_creation.destroyUninserted(fragment);
    try unwrapContextualFragment(fragment);
    return fragment;
}

/// Browser compatibility beyond HTML 8.5.7's fragment-parsing return step.
/// Aligned stable WPT 5d23b743bb: Chrome 4/4 strips nested html/head/body,
/// Firefox 1/4 keeps them, Safari 27 2/4 strips only the outer wrappers.
/// Aligned experimental 64f13635ce: Chrome 158 and Safari 254 preview 4/4,
/// Firefox 160 1/4. Safari ships WebKit 317962@main (bug 320228), joining
/// Blink's recursive stripping. No newer specification changes this rule.
/// https://commits.webkit.org/317962@main
///
/// Remove wrappers at the fragment frontier, revisiting their promoted
/// children. Ordinary elements and foreign namespaces retain their trees;
/// this iterative walk also avoids a stack limit on nested XML wrappers.
fn unwrapContextualFragment(fragment: *runtime.Instance) !void {
    // The HTML tree builder already discards these wrapper tokens. Only
    // XML fragments can reach this compatibility step with them intact.
    const document = (try interfaces.Node.get_ownerDocument(fragment)) orelse return;
    if (document_internals.getDocumentType(document) == .html) return;
    var next = try interfaces.Node.get_firstChild(fragment);
    while (next) |child| {
        const following = try interfaces.Node.get_nextSibling(child);
        const names = dom.node_creation.elementNames(child);
        const unwrap = if (names) |name|
            std.mem.eql(u8, name.namespace orelse "", "http://www.w3.org/1999/xhtml") and
                (std.mem.eql(u8, name.local_name, "html") or std.mem.eql(u8, name.local_name, "head") or std.mem.eql(u8, name.local_name, "body"))
        else
            false;
        if (!unwrap) {
            next = following;
            continue;
        }
        const first = try interfaces.Node.get_firstChild(child);
        while (try interfaces.Node.get_firstChild(child)) |promoted| {
            _ = try interfaces.Node.call_insertBefore(fragment, promoted, child);
        }
        _ = try interfaces.Node.call_removeChild(fragment, child);
        next = first orelse following;
    }
}

/// DOM 5.5 - the stringifier steps (Range.toString())
/// Returns the data of the range's Text nodes.
///
/// Offsets are code units (DOM 4.10): the boundary pieces are CharacterData's
/// substring data, and every piece is concatenated as code units - a pair
/// split across two Text nodes is one pair in the result (infra.wtf8).
///
/// "A Text node" includes a CDATASection, which inherits Text - as Blink's
/// Range::toString (kTextNode or kCdataSectionNode), Gecko's
/// nsRange::ToString (GetAsText) and WebKit's Range::toString read it.
pub fn toString(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]const u8 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const bounds = Bounds.of(internal) orelse return error.InvalidStateError;
    const start = bounds.start_node;
    const end = bounds.end_node;

    // Step 1: "Let s be the empty string."
    var result: std.ArrayListUnmanaged(u8) = .empty;
    errdefer result.deinit(allocator);

    const Pieces = struct {
        /// Append `count` code units of `node`'s data from `offset`.
        fn appendSubstring(gpa: std.mem.Allocator, list: *std.ArrayListUnmanaged(u8), node: *runtime.Instance, offset: u32, count: u32) !void {
            var piece = try interfaces.CharacterData.call_substringData(node, offset, count);
            defer piece.deinit(node.ctx.allocator);
            try @import("infra").wtf8.appendJoined(gpa, list, piece.asSlice());
        }

        fn appendData(gpa: std.mem.Allocator, list: *std.ArrayListUnmanaged(u8), node: *runtime.Instance) !void {
            var data = try interfaces.CharacterData.get_data(node);
            defer data.deinit(node.ctx.allocator);
            try @import("infra").wtf8.appendJoined(gpa, list, data.asSlice());
        }
    };

    // Step 2: "If this's start node is this's end node and it is a Text
    // node, then return the substring of that Text node's data beginning at
    // this's start offset and ending at this's end offset."
    if (start == end and isText(start)) {
        try Pieces.appendSubstring(allocator, &result, start, bounds.start_offset, bounds.end_offset -| bounds.start_offset);
        return result.toOwnedSlice(allocator);
    }

    // Step 3: "If this's start node is a Text node, then append the
    // substring of that node's data from this's start offset until the end
    // to s."
    if (isText(start)) {
        const length = try interfaces.CharacterData.get_length(start);
        try Pieces.appendSubstring(allocator, &result, start, bounds.start_offset, length -| bounds.start_offset);
    }

    // Step 4: "Append the concatenation of the data of all Text nodes that
    // are contained in this, in tree order, to s." They are the Text
    // inclusive descendants of the contained nodes whose parent is not
    // contained, each subtree walked in tree order on the heap's terms - a
    // loop over parents and siblings, no native frame per level.
    const meeting = Meeting.of(start, end) orelse return error.InvalidStateError;
    var roots = try containedRoots(allocator, bounds, meeting);
    defer roots.deinit(allocator);
    for (roots.items) |root| {
        var node: ?*runtime.Instance = root;
        while (node) |n| {
            if (isText(n)) try Pieces.appendData(allocator, &result, n);
            node = (interfaces.Node.get_firstChild(n) catch null) orelse nextSkippingChildren(n, root);
        }
    }

    // Step 5: "If this's end node is a Text node, then append the substring
    // of that node's data from its start until this's end offset to s."
    if (isText(end)) {
        try Pieces.appendSubstring(allocator, &result, end, 0, bounds.end_offset);
    }

    // Step 6: "Return s."
    return result.toOwnedSlice(allocator);
}

/// Is `node` a Text node - an exclusive Text node or a CDATASection?
fn isText(node: *runtime.Instance) bool {
    const node_type = interfaces.Node.get_nodeType(node) catch return false;
    return node_type == interfaces.Node.get_TEXT_NODE() or node_type == interfaces.Node.get_CDATA_SECTION_NODE();
}

// =============================================================================
// Stringifier (serialize -> toString mapping)
// =============================================================================

/// Stringifier - called by interface as "serialize" (mapped from toString in WebIDL)
pub fn serialize(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try toString(instance, instance.ctx.allocator);
}

// =============================================================================
// The live-range steps of the mutation algorithms (dom.range_boundaries)
// =============================================================================

/// dom.range_boundaries: this range's boundary points, as they are.
fn livePoints(instance: *runtime.Instance) ?range_boundaries.LivePoints {
    const internal = getInternal(instance) orelse return null;
    return .{
        .start_container = internal.start_container,
        .start_offset = internal.start_offset,
        .end_container = internal.end_container,
        .end_offset = internal.end_offset,
    };
}

/// dom.range_boundaries: set the start boundary point (a live-range step).
/// Spec: https://dom.spec.whatwg.org/#concept-range-start
fn setStartBoundary(instance: *runtime.Instance, container: *runtime.Instance, offset: u32) void {
    const internal = getInternal(instance) orelse return;
    const before = selectedBoundaries(internal);
    defer notifySelection(instance, internal, before);
    internal.start_container = container;
    internal.start_offset = offset;
    keepContainers(instance, internal);
}

/// dom.range_boundaries: set the end boundary point (a live-range step).
/// Spec: https://dom.spec.whatwg.org/#concept-range-end
fn setEndBoundary(instance: *runtime.Instance, container: *runtime.Instance, offset: u32) void {
    const internal = getInternal(instance) orelse return;
    const before = selectedBoundaries(internal);
    defer notifySelection(instance, internal, before);
    internal.end_container = container;
    internal.end_offset = offset;
    keepContainers(instance, internal);
}

/// dom.range_boundaries: update the start offset (a live-range step).
fn setStartOffset(instance: *runtime.Instance, offset: u32) void {
    const internal = getInternal(instance) orelse return;
    const before = selectedBoundaries(internal);
    defer notifySelection(instance, internal, before);
    internal.start_offset = offset;
}

/// dom.range_boundaries: update the end offset (a live-range step).
fn setEndOffset(instance: *runtime.Instance, offset: u32) void {
    const internal = getInternal(instance) orelse return;
    const before = selectedBoundaries(internal);
    defer notifySelection(instance, internal, before);
    internal.end_offset = offset;
}

/// Check if range intersects with node (non-throwing helper)
pub fn intersectsNode(instance: *runtime.Instance, node: *runtime.Instance) !bool {
    return try call_intersectsNode(instance, node);
}

/// Check if range fully contains node
pub fn containsNode(instance: *runtime.Instance, node: *runtime.Instance) !bool {
    const internal = getInternal(instance) orelse return false;

    const start = internal.start_container orelse return false;
    const end = internal.end_container orelse return false;

    // Check if node's root is the same as range's root
    const nodeRoot = getRoot(node);
    const thisRoot = getRoot(start);
    if (nodeRoot != thisRoot) {
        return false;
    }

    // Node must be a descendant of or equal to both start and end containers
    // For a node to be fully contained:
    // 1. Its start boundary must be at or after range start
    // 2. Its end boundary must be at or before range end

    // Simplified: check if node is between start and end
    const parent = (interfaces.Node.get_parentNode(node) catch null) orelse return false;
    _ = parent;
    _ = end;

    // TODO: Implement proper boundary comparison
    return false;
}
