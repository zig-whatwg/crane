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
const Range = interfaces.Range;

// Import related impls
const NodeImpl = @import("Node.zig");
const AbstractRangeImpl = @import("AbstractRange.zig");

pub const State = Range.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    InvalidNodeTypeError,
    IndexSizeError,
    WrongDocumentError,
    NotSupportedError,
    HierarchyRequestError,
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

/// Get the internal state from state.own._internal
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

    // Initialize Range internal state
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
        // TODO: Unregister from document's range list
        // internal.owner_document.?.unregisterRange(instance);
        _ = internal;
    }
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
/// DOM §5 - Range constructor
/// The new Range() constructor steps are to set this's start and end to
/// (current global object's associated Document, 0).
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(allocator, State, &Range.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Get document from current global object
    // For now, leave boundary points as null (will need document to set)
    // const internal = getInternal(instance) orelse return error.InvalidStateError;
    // internal.start_container = document_node;
    // internal.start_offset = 0;
    // internal.end_container = document_node;
    // internal.end_offset = 0;
    // internal.owner_document = document;

    return instance;
}

// =============================================================================
// Range Attributes
// =============================================================================

/// DOM §5 - Range.commonAncestorContainer
/// Returns the node, furthest away from the document, that is an ancestor
/// of both range's start node and end node.
pub fn get_commonAncestorContainer(instance: *runtime.Instance) ImplError!*runtime.Instance {
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
// AbstractRange Getters (inherited)
// =============================================================================

/// Getter for startContainer
pub fn get_startContainer(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.start_container orelse return error.InvalidStateError;
}

/// Getter for startOffset
pub fn get_startOffset(instance: *runtime.Instance) ImplError!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.start_offset;
}

/// Getter for endContainer
pub fn get_endContainer(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.end_container orelse return error.InvalidStateError;
}

/// Getter for endOffset
pub fn get_endOffset(instance: *runtime.Instance) ImplError!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.end_offset;
}

/// Getter for collapsed
pub fn get_collapsed(instance: *runtime.Instance) ImplError!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.start_container == internal.end_container and
        internal.start_offset == internal.end_offset;
}

// =============================================================================
// Range Mutation Methods
// =============================================================================

/// Helper: Get the length of a node per DOM spec
/// Per DOM §5.2: The length of a node is:
/// - 0 for DocumentType or Attr nodes
/// - data's length for CharacterData nodes
/// - number of children for other nodes
fn getNodeLength(node: *runtime.Instance) u32 {
    const node_type = NodeImpl.getNodeType(node) orelse return 0;

    if (node_type == NodeImpl.NodeType.DOCUMENT_TYPE_NODE or node_type == NodeImpl.NodeType.ATTRIBUTE_NODE) {
        return 0;
    }

    if (node_type == NodeImpl.NodeType.TEXT_NODE or
        node_type == NodeImpl.NodeType.PROCESSING_INSTRUCTION_NODE or
        node_type == NodeImpl.NodeType.COMMENT_NODE)
    {
        // CharacterData nodes - get data length
        // TODO: Cast to CharacterData and get data.len
        return 0; // Placeholder
    }

    // Element, Document, DocumentFragment, etc. - return number of children
    // TODO: return node.child_nodes.size()
    return 0; // Placeholder
}

/// Helper: Check if nodeA is an inclusive ancestor of nodeB
fn isInclusiveAncestor(nodeA: *runtime.Instance, nodeB: *runtime.Instance) bool {
    if (nodeA == nodeB) return true;

    var current: ?*runtime.Instance = nodeB;
    while (current) |node| {
        if (node == nodeA) return true;
        current = NodeImpl.getParent(node);
    }
    return false;
}

/// Helper: Check if nodeA follows nodeB in tree order
fn isFollowing(nodeA: *runtime.Instance, nodeB: *runtime.Instance) bool {
    // TODO: Implement proper tree order comparison
    // For now, return false as placeholder
    _ = nodeA;
    _ = nodeB;
    return false;
}

/// Helper: Check if boundary point A is after boundary point B
fn isAfter(nodeA: *runtime.Instance, offsetA: u32, nodeB: *runtime.Instance, offsetB: u32) bool {
    // Same node: compare offsets
    if (nodeA == nodeB) {
        return offsetA > offsetB;
    }

    // Different nodes: use tree order
    return isFollowing(nodeA, nodeB);
}

/// Helper: Get tree root of a node
fn getRoot(node: *runtime.Instance) *runtime.Instance {
    var current = node;
    while (NodeImpl.getParent(current)) |parent| {
        current = parent;
    }
    return current;
}

/// Boundary point position comparison result
const BoundaryPointPosition = enum { before, equal, after };

/// Helper: Compare position of boundary point (node, offset) relative to (otherNode, otherOffset)
fn compareBoundaryPoints(
    node: *runtime.Instance,
    offset: u32,
    otherNode: *runtime.Instance,
    otherOffset: u32,
) BoundaryPointPosition {
    // Step 2: If node is otherNode, compare offsets
    if (node == otherNode) {
        if (offset == otherOffset) return .equal;
        if (offset < otherOffset) return .before;
        return .after;
    }

    // Step 3: If otherNode is following node
    if (isFollowing(otherNode, node)) {
        // Recursively compare in reverse
        const reversed = compareBoundaryPoints(otherNode, otherOffset, node, offset);
        return switch (reversed) {
            .before => .after,
            .after => .before,
            .equal => .equal,
        };
    }

    // TODO: Steps 4-7 require child index lookup
    // For now, return .equal as placeholder
    return .equal;
}

/// DOM §5.3 - Range.setStart(node, offset)
/// Sets the start of the range to the given boundary point
pub fn call_setStart(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) ImplError!void {
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
pub fn call_setEnd(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) ImplError!void {
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
pub fn call_setStartBefore(instance: *runtime.Instance, node: *runtime.Instance) ImplError!void {
    const parent = NodeImpl.getParent(node) orelse return error.InvalidNodeTypeError;
    // TODO: Get child index
    // const index = getChildIndex(parent, node) orelse return error.InvalidStateError;
    _ = parent;
    _ = instance;
    return error.NotImplemented;
}

/// DOM §5.3 - Range.setStartAfter(node)
pub fn call_setStartAfter(instance: *runtime.Instance, node: *runtime.Instance) ImplError!void {
    const parent = NodeImpl.getParent(node) orelse return error.InvalidNodeTypeError;
    _ = parent;
    _ = instance;
    return error.NotImplemented;
}

/// DOM §5.3 - Range.setEndBefore(node)
pub fn call_setEndBefore(instance: *runtime.Instance, node: *runtime.Instance) ImplError!void {
    const parent = NodeImpl.getParent(node) orelse return error.InvalidNodeTypeError;
    _ = parent;
    _ = instance;
    return error.NotImplemented;
}

/// DOM §5.3 - Range.setEndAfter(node)
pub fn call_setEndAfter(instance: *runtime.Instance, node: *runtime.Instance) ImplError!void {
    const parent = NodeImpl.getParent(node) orelse return error.InvalidNodeTypeError;
    _ = parent;
    _ = instance;
    return error.NotImplemented;
}

/// DOM §5.3 - Range.collapse(toStart)
pub fn call_collapse(instance: *runtime.Instance, toStart: bool) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    if (toStart) {
        internal.end_container = internal.start_container;
        internal.end_offset = internal.start_offset;
    } else {
        internal.start_container = internal.end_container;
        internal.start_offset = internal.end_offset;
    }
}

/// DOM §5.3 - Range.selectNode(node)
pub fn call_selectNode(instance: *runtime.Instance, node: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = node;
    return error.NotImplemented;
}

/// DOM §5.3 - Range.selectNodeContents(node)
pub fn call_selectNodeContents(instance: *runtime.Instance, node: *runtime.Instance) ImplError!void {
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
pub fn call_compareBoundaryPoints(instance: *runtime.Instance, how: u16, sourceRange: *runtime.Instance) ImplError!i16 {
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

/// DOM §5.4 - Range.deleteContents()
pub fn call_deleteContents(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement - requires DOM mutation algorithms
    return error.NotImplemented;
}

/// DOM §5.6 - Range.extractContents()
pub fn call_extractContents(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    // TODO: Implement - requires DocumentFragment creation and DOM mutation
    return error.NotImplemented;
}

/// DOM §5.6 - Range.cloneContents()
pub fn call_cloneContents(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    // TODO: Implement - requires node cloning and DocumentFragment
    return error.NotImplemented;
}

/// DOM §5.4 - Range.insertNode(node)
pub fn call_insertNode(instance: *runtime.Instance, node: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = node;
    // TODO: Implement - requires DOM insertion algorithms
    return error.NotImplemented;
}

/// DOM §5.4 - Range.surroundContents(newParent)
pub fn call_surroundContents(instance: *runtime.Instance, newParent: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = newParent;
    // TODO: Implement - requires extractContents, insertNode
    return error.NotImplemented;
}

/// DOM §5 - Range.cloneRange()
pub fn call_cloneRange(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Create new range with same boundary points
    const newRange = init(internal.allocator, State, &Range.vtable, instance.ctx) catch return error.OutOfMemory;
    errdefer deinit(newRange);

    const newInternal = getInternal(newRange) orelse return error.InvalidStateError;
    newInternal.start_container = internal.start_container;
    newInternal.start_offset = internal.start_offset;
    newInternal.end_container = internal.end_container;
    newInternal.end_offset = internal.end_offset;
    newInternal.owner_document = internal.owner_document;

    // TODO: Register with document

    return newRange;
}

/// DOM §5 - Range.detach()
/// Does nothing. Kept for compatibility.
pub fn call_detach(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // Historical artifact - does nothing per spec
}

// =============================================================================
// Range Point Methods
// =============================================================================

/// DOM §5 - Range.isPointInRange(node, offset)
pub fn call_isPointInRange(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) ImplError!bool {
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
pub fn call_comparePoint(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) ImplError!i16 {
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
pub fn call_intersectsNode(instance: *runtime.Instance, node: *runtime.Instance) ImplError!bool {
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

    // TODO: Steps 4-6 require child index lookup
    _ = parent;
    return error.NotImplemented;
}

// =============================================================================
// CSSOM View Methods (layout-related)
// =============================================================================

/// CSSOM View - Range.getClientRects()
pub fn call_getClientRects(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    // TODO: Requires layout engine integration
    return error.NotImplemented;
}

/// CSSOM View - Range.getBoundingClientRect()
pub fn call_getBoundingClientRect(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    // TODO: Requires layout engine integration
    return error.NotImplemented;
}

/// DOM Parsing - Range.createContextualFragment(string)
pub fn call_createContextualFragment(instance: *runtime.Instance, string: *const anyopaque) ImplError!*runtime.Instance {
    _ = instance;
    _ = string;
    // TODO: Requires HTML parser integration
    return error.NotImplemented;
}
