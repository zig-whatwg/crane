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
const document_internals = @import("dom").document_internals;

// Import related impls
const NodeImpl = @import("Node.zig");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;

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

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    range_boundaries.install(&boundariesOf);
    range_boundaries.installLiveRange(.{ .collapse = &collapseLive, .update_owner_document = &updateOwnerDocument });
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
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
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
        const Arena = @import("runtime").ArenaAllocator;
        if (Arena.tryGet() catch null) |arena| arena.destroy(InternalState, internal);
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

    // Let container be start node
    var container = start;

    // While container is not an inclusive ancestor of end node,
    // let container be container's parent
    while (!isInclusiveAncestor(container, end)) {
        container = NodeImpl.getParent(container) orelse {
            // If we reach root without finding common ancestor, return start container
            return start;
        };
    }

    return container;
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
    var current = NodeImpl.getFirstChild(parent);
    var index: u32 = 0;

    while (current) |node| {
        if (node == child) return index;
        index += 1;
        current = NodeImpl.getNextSibling(node);
    }

    return null;
}

/// Helper: Check if nodeA is an inclusive ancestor of nodeB
fn isInclusiveAncestor(nodeA: *runtime.Instance, nodeB: *runtime.Instance) bool {
    return nodeA == nodeB or boundary_points.isAncestor(DomTree, nodeA, nodeB);
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

    // Step 1: If node is a doctype, throw InvalidNodeTypeError
    if (NodeImpl.getNodeType(node)) |nt| {
        if (nt == NodeImpl.NodeType.DOCUMENT_TYPE_NODE) {
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
}

/// DOM §5.3 - Range.setEnd(node, offset)
/// Sets the end of the range to the given boundary point
pub fn call_setEnd(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: If node is a doctype, throw InvalidNodeTypeError
    if (NodeImpl.getNodeType(node)) |nt| {
        if (nt == NodeImpl.NodeType.DOCUMENT_TYPE_NODE) {
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
}

/// DOM §5.3 - Range.setStartBefore(node)
/// Sets the start to immediately before the given node
pub fn call_setStartBefore(instance: *runtime.Instance, node: *runtime.Instance) anyerror!void {
    // Step 1: Let parent be node's parent
    const parent = NodeImpl.getParent(node) orelse return error.InvalidNodeTypeError;

    // Step 2: If parent is null, throw InvalidNodeTypeError (already checked)

    // Step 3: Set start to boundary point (parent, node's index)
    const index = getChildIndex(parent, node) orelse return error.InvalidStateError;
    try call_setStart(instance, parent, index);
}

/// DOM §5.3 - Range.setStartAfter(node)
/// Sets the start to immediately after the given node
pub fn call_setStartAfter(instance: *runtime.Instance, node: *runtime.Instance) anyerror!void {
    // Step 1: Let parent be node's parent
    const parent = NodeImpl.getParent(node) orelse return error.InvalidNodeTypeError;

    // Step 2: If parent is null, throw InvalidNodeTypeError (already checked)

    // Step 3: Set start to boundary point (parent, node's index + 1)
    const index = getChildIndex(parent, node) orelse return error.InvalidStateError;
    try call_setStart(instance, parent, index + 1);
}

/// DOM §5.3 - Range.setEndBefore(node)
/// Sets the end to immediately before the given node
pub fn call_setEndBefore(instance: *runtime.Instance, node: *runtime.Instance) anyerror!void {
    // Step 1: Let parent be node's parent
    const parent = NodeImpl.getParent(node) orelse return error.InvalidNodeTypeError;

    // Step 2: If parent is null, throw InvalidNodeTypeError (already checked)

    // Step 3: Set end to boundary point (parent, node's index)
    const index = getChildIndex(parent, node) orelse return error.InvalidStateError;
    try call_setEnd(instance, parent, index);
}

/// DOM §5.3 - Range.setEndAfter(node)
/// Sets the end to immediately after the given node
pub fn call_setEndAfter(instance: *runtime.Instance, node: *runtime.Instance) anyerror!void {
    // Step 1: Let parent be node's parent
    const parent = NodeImpl.getParent(node) orelse return error.InvalidNodeTypeError;

    // Step 2: If parent is null, throw InvalidNodeTypeError (already checked)

    // Step 3: Set end to boundary point (parent, node's index + 1)
    const index = getChildIndex(parent, node) orelse return error.InvalidStateError;
    try call_setEnd(instance, parent, index + 1);
}

/// DOM §5.3 - Range.collapse(toStart)
pub fn call_collapse(instance: *runtime.Instance, toStart: webidl.Opt(bool)) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

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
    const parent = NodeImpl.getParent(node) orelse return error.InvalidNodeTypeError;

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

    // If node is a doctype, throw InvalidNodeTypeError
    if (NodeImpl.getNodeType(node)) |nt| {
        if (nt == NodeImpl.NodeType.DOCUMENT_TYPE_NODE) {
            return error.InvalidNodeTypeError;
        }
    }

    const length = getNodeLength(node);
    internal.start_container = node;
    internal.start_offset = 0;
    internal.end_container = node;
    internal.end_offset = length;
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
/// "original" start and end before they mutate anything, and recurse over
/// sub-ranges that need no Range object of their own.
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

    /// "A node node is contained in a live range range if node's root is
    /// range's root, and (node, 0) is after range's start, and (node, node's
    /// length) is before range's end."
    fn contains(self: Bounds, node: *runtime.Instance) bool {
        if (getRoot(node) != getRoot(self.start_node)) return false;
        if (compareBoundaryPoints(node, 0, self.start_node, self.start_offset) != .after) return false;
        return compareBoundaryPoints(node, getNodeLength(node), self.end_node, self.end_offset) == .before;
    }

    /// "A node is partially contained in a live range if it's an inclusive
    /// ancestor of the live range's start node but not its end node, or vice
    /// versa."
    fn partiallyContains(self: Bounds, node: *runtime.Instance) bool {
        const of_start = isInclusiveAncestor(node, self.start_node);
        const of_end = isInclusiveAncestor(node, self.end_node);
        return of_start != of_end;
    }
};

/// Helper: Check if a node is contained in this range
fn isNodeContained(internal: *InternalState, node: *runtime.Instance) bool {
    const bounds = Bounds.of(internal) orelse return false;
    return bounds.contains(node);
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

/// Steps shared by "extract" and "clone the contents" (5-11): the common
/// ancestor, the first and last partially contained children, and the
/// contained children.
const Split = struct {
    common_ancestor: *runtime.Instance,
    first_partially_contained: ?*runtime.Instance,
    last_partially_contained: ?*runtime.Instance,
    contained_children: std.ArrayListUnmanaged(*runtime.Instance),

    fn of(allocator: std.mem.Allocator, bounds: Bounds) !Split {
        // Steps 5-6: "Let commonAncestor be originalStartNode. While
        // commonAncestor is not an inclusive ancestor of originalEndNode:
        // set commonAncestor to its own parent."
        var common = bounds.start_node;
        while (!isInclusiveAncestor(common, bounds.end_node)) {
            common = DomTree.parent(common) orelse return error.InvalidStateError;
        }

        // Steps 7-8: "If originalStartNode is not an inclusive ancestor of
        // originalEndNode, then set firstPartiallyContainedChild to the first
        // child of commonAncestor that is partially contained in range."
        var first: ?*runtime.Instance = null;
        if (!isInclusiveAncestor(bounds.start_node, bounds.end_node)) {
            var child = interfaces.Node.get_firstChild(common) catch null;
            while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) {
                if (bounds.partiallyContains(c)) {
                    first = c;
                    break;
                }
            }
        }

        // Steps 9-10: "If originalEndNode is not an inclusive ancestor of
        // originalStartNode, then set lastPartiallyContainedChild to the last
        // child of commonAncestor that is partially contained in range."
        var last: ?*runtime.Instance = null;
        if (!isInclusiveAncestor(bounds.end_node, bounds.start_node)) {
            var child = interfaces.Node.get_lastChild(common) catch null;
            while (child) |c| : (child = interfaces.Node.get_previousSibling(c) catch null) {
                if (bounds.partiallyContains(c)) {
                    last = c;
                    break;
                }
            }
        }

        // Step 11: "Let containedChildren be a list of all children of
        // commonAncestor that are contained in range, in tree order."
        var contained: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
        errdefer contained.deinit(allocator);
        var child = interfaces.Node.get_firstChild(common) catch null;
        while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) {
            if (bounds.contains(c)) try contained.append(allocator, c);
        }

        // Step 12: "If any member of containedChildren is a doctype, then
        // throw a "HierarchyRequestError" DOMException."
        for (contained.items) |c| {
            if ((interfaces.Node.get_nodeType(c) catch 0) == interfaces.Node.get_DOCUMENT_TYPE_NODE()) {
                return error.HierarchyRequestError;
            }
        }

        return .{
            .common_ancestor = common,
            .first_partially_contained = first,
            .last_partially_contained = last,
            .contained_children = contained,
        };
    }

    fn deinit(self: *Split, allocator: std.mem.Allocator) void {
        self.contained_children.deinit(allocator);
    }
};

/// Where "deleteContents" (steps 5-7) and "extract" (steps 13-15) collapse
/// the range afterwards: originalStart itself when it is an inclusive
/// ancestor of originalEndNode, else just after its ancestor that is a child
/// of the common ancestor.
fn collapsePoint(bounds: Bounds) struct { node: *runtime.Instance, offset: u32 } {
    // "If originalStartNode is an inclusive ancestor of originalEndNode, then
    // set newNode to originalStartNode and newOffset to originalStartOffset."
    if (isInclusiveAncestor(bounds.start_node, bounds.end_node)) {
        return .{ .node = bounds.start_node, .offset = bounds.start_offset };
    }
    // "Otherwise: let referenceNode be originalStartNode. While
    // referenceNode's parent is non-null and is not an inclusive ancestor of
    // originalEndNode: set referenceNode to its parent. Set newNode to the
    // parent of referenceNode, and newOffset to referenceNode's index + 1."
    var reference = bounds.start_node;
    while (DomTree.parent(reference)) |parent| {
        if (isInclusiveAncestor(parent, bounds.end_node)) break;
        reference = parent;
    }
    // referenceNode's parent is not null: were it, referenceNode would be the
    // range's root, an inclusive ancestor of originalEndNode.
    return .{ .node = DomTree.parent(reference) orelse reference, .offset = DomTree.index(reference) + 1 };
}

/// DOM 5.5 "The deleteContents() method steps".
pub fn call_deleteContents(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
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
    // also contained in this." Every contained node is a descendant of the
    // common ancestor of the start and end nodes, and a contained node's
    // descendants are all contained: the walk takes a contained node and
    // skips its subtree, and descends only into partially contained ones.
    const allocator = instance.ctx.allocator;
    var nodes_to_remove: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer nodes_to_remove.deinit(allocator);
    {
        var root = bounds.start_node;
        while (!isInclusiveAncestor(root, bounds.end_node)) {
            root = DomTree.parent(root) orelse return error.InvalidStateError;
        }
        var node: ?*runtime.Instance = interfaces.Node.get_firstChild(root) catch null;
        while (node) |n| {
            if (bounds.contains(n)) {
                try nodes_to_remove.append(allocator, n);
                node = nextSkippingChildren(n, root);
            } else if (bounds.partiallyContains(n)) {
                node = (interfaces.Node.get_firstChild(n) catch null) orelse nextSkippingChildren(n, root);
            } else {
                node = nextSkippingChildren(n, root);
            }
        }
    }

    // Steps 5-7: newNode and newOffset.
    const collapse_to = collapsePoint(bounds);

    // Step 8: "If originalStartNode is a CharacterData node, then replace data
    // of originalStartNode with originalStartOffset, originalStartNode's
    // length - originalStartOffset, and the empty string."
    if (isCharacterData(bounds.start_node)) {
        try deleteData(bounds.start_node, bounds.start_offset, getNodeLength(bounds.start_node) - bounds.start_offset);
    }

    // Step 9: "For each node of nodesToRemove, in tree order: remove node."
    for (nodes_to_remove.items) |node| {
        const parent = DomTree.parent(node) orelse continue;
        _ = try interfaces.Node.call_removeChild(parent, node);
    }

    // Step 10: "If originalEndNode is a CharacterData node, then replace data
    // of originalEndNode with 0, originalEndOffset, and the empty string."
    if (isCharacterData(bounds.end_node)) {
        try deleteData(bounds.end_node, 0, bounds.end_offset);
    }

    // Step 11: "Set start and end to (newNode, newOffset)."
    internal.start_container = collapse_to.node;
    internal.start_offset = collapse_to.offset;
    internal.end_container = collapse_to.node;
    internal.end_offset = collapse_to.offset;
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

/// What "extract" hands back: the fragment, and - except when it returned
/// early - the point step 21 sets the range's start and end to.
const Extracted = struct {
    fragment: *runtime.Instance,
    collapse_to: ?struct { node: *runtime.Instance, offset: u32 } = null,
};

/// DOM 5.5 "extract" a live range, given by its boundary points. The caller
/// performs step 21 ("set range's start and end to (newNode, newOffset)")
/// with what comes back; a sub-range's is dropped with the sub-range.
fn extract(allocator: std.mem.Allocator, bounds: Bounds) anyerror!Extracted {
    // Step 1: "Let fragment be a new DocumentFragment node whose node
    // document is range's start node's node document."
    const fragment = try fragmentFor(bounds.start_node);

    // Step 2: "If range is collapsed, then return fragment."
    if (bounds.collapsed()) return .{ .fragment = fragment };

    // Step 3: originalStartNode, originalStartOffset, originalEndNode and
    // originalEndOffset are `bounds`.

    // Step 4: "If originalStartNode is originalEndNode and it is a
    // CharacterData node:"
    if (bounds.start_node == bounds.end_node and isCharacterData(bounds.start_node)) {
        const count = bounds.end_offset - bounds.start_offset;
        // Steps 4.1-4.3: a clone holding the substring, appended to fragment.
        const clone = try cloneWithSubstring(bounds.start_node, bounds.start_offset, count);
        _ = try interfaces.Node.call_appendChild(fragment, clone);
        // Step 4.4: "Replace data of originalStartNode with
        // originalStartOffset, originalEndOffset - originalStartOffset, and
        // the empty string." Its live-range steps collapse range.
        try deleteData(bounds.start_node, bounds.start_offset, count);
        // Step 4.5
        return .{ .fragment = fragment };
    }

    // Steps 5-12.
    var split = try Split.of(allocator, bounds);
    defer split.deinit(allocator);

    // Steps 13-15: newNode and newOffset.
    const collapse_to = collapsePoint(bounds);

    if (split.first_partially_contained) |first| {
        if (isCharacterData(first)) {
            // Step 16: firstPartiallyContainedChild is originalStartNode.
            // "Let clone be a clone of originalStartNode", holding the data
            // from originalStartOffset to its end; append it to fragment,
            // then replace that data with the empty string.
            const count = getNodeLength(bounds.start_node) - bounds.start_offset;
            const clone = try cloneWithSubstring(bounds.start_node, bounds.start_offset, count);
            _ = try interfaces.Node.call_appendChild(fragment, clone);
            try deleteData(bounds.start_node, bounds.start_offset, count);
        } else {
            // Step 17.1-17.2: "Let clone be a clone of
            // firstPartiallyContainedChild. Append clone to fragment."
            const clone = try interfaces.Node.call_cloneNode(first, webidl.Opt(bool).passed(false));
            _ = try interfaces.Node.call_appendChild(fragment, clone);
            // Steps 17.3-17.5: extract the subrange from (originalStartNode,
            // originalStartOffset) to (firstPartiallyContainedChild, its
            // length), and append that subfragment to clone.
            const sub = try extract(allocator, .{
                .start_node = bounds.start_node,
                .start_offset = bounds.start_offset,
                .end_node = first,
                .end_offset = getNodeLength(first),
            });
            _ = try interfaces.Node.call_appendChild(clone, sub.fragment);
        }
    }

    // Step 18: "For each contained child of containedChildren: append
    // contained child to fragment."
    for (split.contained_children.items) |child| {
        _ = try interfaces.Node.call_appendChild(fragment, child);
    }

    if (split.last_partially_contained) |last| {
        if (isCharacterData(last)) {
            // Step 19: lastPartiallyContainedChild is originalEndNode. A clone
            // holding its data up to originalEndOffset, appended to fragment;
            // then that data replaced with the empty string.
            const clone = try cloneWithSubstring(bounds.end_node, 0, bounds.end_offset);
            _ = try interfaces.Node.call_appendChild(fragment, clone);
            try deleteData(bounds.end_node, 0, bounds.end_offset);
        } else {
            // Steps 20.1-20.2
            const clone = try interfaces.Node.call_cloneNode(last, webidl.Opt(bool).passed(false));
            _ = try interfaces.Node.call_appendChild(fragment, clone);
            // Steps 20.3-20.5: the subrange from (lastPartiallyContainedChild,
            // 0) to (originalEndNode, originalEndOffset), extracted into
            // clone.
            const sub = try extract(allocator, .{
                .start_node = last,
                .start_offset = 0,
                .end_node = bounds.end_node,
                .end_offset = bounds.end_offset,
            });
            _ = try interfaces.Node.call_appendChild(clone, sub.fragment);
        }
    }

    // Steps 21-22: the caller sets range's start and end; return fragment.
    return .{ .fragment = fragment, .collapse_to = .{ .node = collapse_to.node, .offset = collapse_to.offset } };
}

/// Extract `instance` and perform extract's step 21 on it.
fn extractThis(instance: *runtime.Instance, internal: *InternalState) anyerror!*runtime.Instance {
    const bounds = Bounds.of(internal) orelse return error.InvalidStateError;
    const extracted = try extract(instance.ctx.allocator, bounds);
    // Step 21: "Set range's start and end to (newNode, newOffset)."
    if (extracted.collapse_to) |point| {
        internal.start_container = point.node;
        internal.start_offset = point.offset;
        internal.end_container = point.node;
        internal.end_offset = point.offset;
    }
    return extracted.fragment;
}

/// DOM 5.5: "The extractContents() method steps are to return the result of
/// extracting this."
pub fn call_extractContents(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return extractThis(instance, internal);
}

/// DOM 5.5 "clone the contents" of a live range, given by its boundary
/// points.
fn cloneTheContents(allocator: std.mem.Allocator, bounds: Bounds) anyerror!*runtime.Instance {
    // Step 1: "Let fragment be a new DocumentFragment node whose node
    // document is range's start node's node document."
    const fragment = try fragmentFor(bounds.start_node);

    // Step 2: "If range is collapsed, then return fragment."
    if (bounds.collapsed()) return fragment;

    // Step 4: "If originalStartNode is originalEndNode and it is a
    // CharacterData node": a clone holding the substring between the offsets,
    // appended to fragment.
    if (bounds.start_node == bounds.end_node and isCharacterData(bounds.start_node)) {
        const clone = try cloneWithSubstring(bounds.start_node, bounds.start_offset, bounds.end_offset - bounds.start_offset);
        _ = try interfaces.Node.call_appendChild(fragment, clone);
        return fragment;
    }

    // Steps 5-12.
    var split = try Split.of(allocator, bounds);
    defer split.deinit(allocator);

    if (split.first_partially_contained) |first| {
        if (isCharacterData(first)) {
            // Step 13: a clone of originalStartNode holding its data from
            // originalStartOffset to its end.
            const clone = try cloneWithSubstring(bounds.start_node, bounds.start_offset, getNodeLength(bounds.start_node) - bounds.start_offset);
            _ = try interfaces.Node.call_appendChild(fragment, clone);
        } else {
            // Step 14: a clone of firstPartiallyContainedChild, holding the
            // cloned contents of the subrange from the start to its end.
            const clone = try interfaces.Node.call_cloneNode(first, webidl.Opt(bool).passed(false));
            _ = try interfaces.Node.call_appendChild(fragment, clone);
            const sub = try cloneTheContents(allocator, .{
                .start_node = bounds.start_node,
                .start_offset = bounds.start_offset,
                .end_node = first,
                .end_offset = getNodeLength(first),
            });
            _ = try interfaces.Node.call_appendChild(clone, sub);
        }
    }

    // Step 15: "For each contained child of containedChildren: let clone be a
    // clone of contained child with subtree set to true; append clone to
    // fragment."
    for (split.contained_children.items) |child| {
        const clone = try interfaces.Node.call_cloneNode(child, webidl.Opt(bool).passed(true));
        _ = try interfaces.Node.call_appendChild(fragment, clone);
    }

    if (split.last_partially_contained) |last| {
        if (isCharacterData(last)) {
            // Step 16: a clone of originalEndNode holding its data up to
            // originalEndOffset.
            const clone = try cloneWithSubstring(bounds.end_node, 0, bounds.end_offset);
            _ = try interfaces.Node.call_appendChild(fragment, clone);
        } else {
            // Step 17: a clone of lastPartiallyContainedChild, holding the
            // cloned contents of the subrange from its start to the end.
            const clone = try interfaces.Node.call_cloneNode(last, webidl.Opt(bool).passed(false));
            _ = try interfaces.Node.call_appendChild(fragment, clone);
            const sub = try cloneTheContents(allocator, .{
                .start_node = last,
                .start_offset = 0,
                .end_node = bounds.end_node,
                .end_offset = bounds.end_offset,
            });
            _ = try interfaces.Node.call_appendChild(clone, sub);
        }
    }

    // Step 18: "Return fragment."
    return fragment;
}

/// DOM 5.5: "The cloneContents() method steps are to return the result of
/// cloning the contents of this."
pub fn call_cloneContents(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const bounds = Bounds.of(internal) orelse return error.InvalidStateError;
    return cloneTheContents(instance.ctx.allocator, bounds);
}

/// DOM 5.5 "insert" a node into a live range; insertNode(node)'s steps.
pub fn call_insertNode(instance: *runtime.Instance, node: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
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
    // inclusive ancestors of the other.
    for ([_][2]*runtime.Instance{ .{ bounds.start_node, bounds.end_node }, .{ bounds.end_node, bounds.start_node } }) |pair| {
        var node: ?*runtime.Instance = pair[0];
        while (node) |n| : (node = DomTree.parent(n)) {
            if (isInclusiveAncestor(n, pair[1])) break;
            if ((interfaces.Node.get_nodeType(n) catch 0) != interfaces.Node.get_TEXT_NODE()) return error.InvalidStateError;
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
    if (NodeImpl.getNodeType(node)) |nt| {
        if (nt == NodeImpl.NodeType.DOCUMENT_TYPE_NODE) {
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
    if (NodeImpl.getNodeType(node)) |nt| {
        if (nt == NodeImpl.NodeType.DOCUMENT_TYPE_NODE) {
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
    const parent = NodeImpl.getParent(node) orelse {
        // Step 3: If parent is null, return true
        return true;
    };

    // Step 4: Let offset be node's index
    const offset = getChildIndex(parent, node) orelse return false;

    // Step 5: Check if (parent, offset) is before end AND (parent, offset+1) is after start
    const end = internal.end_container orelse return error.InvalidStateError;

    const beforeEnd = compareBoundaryPoints(parent, offset, end, internal.end_offset);
    const afterStart = compareBoundaryPoints(parent, offset + 1, start, internal.start_offset);

    // Step 6: Return true if (parent, offset) is before end and (parent, offset+1) is after start
    if (beforeEnd != .after and afterStart != .before) {
        return true;
    }

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

/// DOM Parsing - Range.createContextualFragment(string)
/// Parses the given string as HTML and returns a DocumentFragment
/// Note: Requires HTML parser integration
pub fn call_createContextualFragment(instance: *runtime.Instance, string: runtime.DOMString) anyerror!*runtime.Instance {
    _ = getInternal(instance) orelse return error.InvalidStateError;
    _ = string;

    // NOTE: Full implementation requires HTML parser
    // For now, return an empty DocumentFragment (use interface per Golden Rule #13)
    return interfaces.DocumentFragment.call_constructor(instance.ctx) catch return error.OutOfMemory;
}

/// DOM §5.7 - Range stringifier (toString)
/// Returns the text content of the range
pub fn toString(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]const u8 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    const start = internal.start_container orelse return error.InvalidStateError;
    const end = internal.end_container orelse return error.InvalidStateError;

    var result: std.ArrayListUnmanaged(u8) = .empty;
    errdefer result.deinit(allocator);

    const start_type = NodeImpl.getNodeType(start) orelse return error.InvalidStateError;

    // Step 2: If start node == end node and it's a Text node
    if (start == end and start_type == NodeImpl.NodeType.TEXT_NODE) {
        const CharacterDataImpl = @import("CharacterData.zig");
        const data = CharacterDataImpl.getData(start) orelse "";

        // Return substring from start offset to end offset
        if (internal.end_offset >= internal.start_offset and internal.end_offset <= data.len) {
            const substring = data[internal.start_offset..internal.end_offset];
            try result.appendSlice(allocator, substring);
            return result.toOwnedSlice(allocator);
        }
    }

    // Step 3: If start node is a Text node, append from start offset to end
    if (start_type == NodeImpl.NodeType.TEXT_NODE) {
        const CharacterDataImpl = @import("CharacterData.zig");
        const data = CharacterDataImpl.getData(start) orelse "";
        if (internal.start_offset <= data.len) {
            const substring = data[internal.start_offset..];
            try result.appendSlice(allocator, substring);
        }
    }

    // Step 4: Append text content of all contained Text nodes
    const commonAncestor = (try get_commonAncestorContainer(instance));
    try appendContainedTextNodes(allocator, internal, commonAncestor, &result);

    // Step 5: If end node is a Text node, append from start to end offset
    const end_type = NodeImpl.getNodeType(end) orelse return error.InvalidStateError;
    if (end_type == NodeImpl.NodeType.TEXT_NODE and end != start) {
        const CharacterDataImpl = @import("CharacterData.zig");
        const data = CharacterDataImpl.getData(end) orelse "";
        if (internal.end_offset <= data.len) {
            const substring = data[0..internal.end_offset];
            try result.appendSlice(allocator, substring);
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Helper for toString: Recursively append contained Text node data
fn appendContainedTextNodes(allocator: std.mem.Allocator, internal: *InternalState, node: *runtime.Instance, result: *std.ArrayListUnmanaged(u8)) !void {
    // If this node is contained and is a Text node, append its data
    const node_type = NodeImpl.getNodeType(node) orelse return;
    if (isNodeContained(internal, node) and node_type == NodeImpl.NodeType.TEXT_NODE) {
        const CharacterDataImpl = @import("CharacterData.zig");
        const data = CharacterDataImpl.getData(node) orelse "";
        try result.appendSlice(allocator, data);
        return;
    }

    // Recursively process children in tree order
    var child = NodeImpl.getFirstChild(node);
    while (child) |c| {
        try appendContainedTextNodes(allocator, internal, c, result);
        child = NodeImpl.getNextSibling(c);
    }
}

// =============================================================================
// Stringifier (serialize -> toString mapping)
// =============================================================================

/// Stringifier - called by interface as "serialize" (mapped from toString in WebIDL)
pub fn serialize(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try toString(instance, instance.ctx.allocator);
}

// =============================================================================
// Helper functions for Selection and other impls
// =============================================================================

/// Get start container (nullable, non-throwing helper for Selection)
pub fn getStartContainer(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    return internal.start_container;
}

/// Get start offset (non-throwing helper for Selection)
pub fn getStartOffset(instance: *runtime.Instance) u32 {
    const internal = getInternal(instance) orelse return 0;
    return internal.start_offset;
}

/// Get end container (nullable, non-throwing helper for Selection)
pub fn getEndContainer(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    return internal.end_container;
}

/// Get end offset (non-throwing helper for Selection)
pub fn getEndOffset(instance: *runtime.Instance) u32 {
    const internal = getInternal(instance) orelse return 0;
    return internal.end_offset;
}

/// Set start boundary point (for live range updates during mutations)
/// Spec: https://dom.spec.whatwg.org/#concept-range-start
pub fn setStartBoundary(instance: *runtime.Instance, container: *runtime.Instance, offset: u32) void {
    const internal = getInternal(instance) orelse return;
    internal.start_container = container;
    internal.start_offset = offset;
}

/// Set end boundary point (for live range updates during mutations)
/// Spec: https://dom.spec.whatwg.org/#concept-range-end
pub fn setEndBoundary(instance: *runtime.Instance, container: *runtime.Instance, offset: u32) void {
    const internal = getInternal(instance) orelse return;
    internal.end_container = container;
    internal.end_offset = offset;
}

/// Update start offset (for live range updates during mutations)
pub fn setStartOffset(instance: *runtime.Instance, offset: u32) void {
    const internal = getInternal(instance) orelse return;
    internal.start_offset = offset;
}

/// Update end offset (for live range updates during mutations)
pub fn setEndOffset(instance: *runtime.Instance, offset: u32) void {
    const internal = getInternal(instance) orelse return;
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
    const parent = NodeImpl.getParent(node) orelse return false;
    _ = parent;
    _ = end;

    // TODO: Implement proper boundary comparison
    return false;
}
