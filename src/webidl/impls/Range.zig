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
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
/// DOM §5 - Range constructor
/// The new Range() constructor steps are to set this's start and end to
/// (current global object's associated Document, 0).
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &Range.vtable, ctx);
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
        // CharacterData nodes - get data length via CharacterData impl
        const CharacterDataImpl = @import("CharacterData.zig");
        return CharacterDataImpl.getDataLength(node);
    }

    // Element, Document, DocumentFragment, etc. - return number of children
    return NodeImpl.getChildCount(node);
}

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
    if (nodeA == nodeB) return true;

    var current: ?*runtime.Instance = nodeB;
    while (current) |node| {
        if (node == nodeA) return true;
        current = NodeImpl.getParent(node);
    }
    return false;
}

/// Helper: Check if nodeA follows nodeB in tree order
/// Per WHATWG DOM: A is following B if A comes after B in preorder depth-first traversal
fn isFollowing(nodeA: *runtime.Instance, nodeB: *runtime.Instance) bool {
    if (nodeA == nodeB) return false;

    // Check if B is an ancestor of A (A would be following B)
    if (isInclusiveAncestor(nodeB, nodeA)) return true;

    // Check if A is an ancestor of B (A would be preceding B)
    if (isInclusiveAncestor(nodeA, nodeB)) return false;

    // Find common ancestor and compare sibling order
    // Build ancestor chain for A
    var ancestorsA: [256]*runtime.Instance = undefined;
    var ancestorCountA: usize = 0;
    var currentA: ?*runtime.Instance = nodeA;
    while (currentA) |node| {
        if (ancestorCountA < 256) {
            ancestorsA[ancestorCountA] = node;
            ancestorCountA += 1;
        }
        currentA = NodeImpl.getParent(node);
    }

    // Walk up from B to find common ancestor
    var currentB: ?*runtime.Instance = nodeB;
    while (currentB) |ancestorB| {
        // Check if this B ancestor is in A's chain
        for (0..ancestorCountA) |i| {
            if (ancestorsA[i] == ancestorB) {
                // Found common ancestor
                // Now find which child branch of common ancestor each node is in
                if (i == 0) return false; // nodeA itself is ancestor

                const childOfCommonA = ancestorsA[i - 1];

                // Find B's child of common ancestor
                var childOfCommonB: *runtime.Instance = nodeB;
                var parentOfB = NodeImpl.getParent(nodeB);
                while (parentOfB != null and parentOfB != ancestorB) {
                    childOfCommonB = parentOfB.?;
                    parentOfB = NodeImpl.getParent(childOfCommonB);
                }

                // Compare child indices
                const indexA = getChildIndex(ancestorB, childOfCommonA);
                const indexB = getChildIndex(ancestorB, childOfCommonB);

                if (indexA != null and indexB != null) {
                    return indexA.? > indexB.?;
                }
                return false;
            }
        }
        currentB = NodeImpl.getParent(ancestorB);
    }

    // No common ancestor found (different trees)
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
/// Per DOM §5.5 boundary point position algorithm
fn compareBoundaryPoints(
    node: *runtime.Instance,
    offset: u32,
    otherNode: *runtime.Instance,
    otherOffset: u32,
) BoundaryPointPosition {
    // Step 1: Assert nodes have same root (caller's responsibility)

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

    // Step 4 & 5: Determine child of otherNode to compare
    var child: *runtime.Instance = undefined;
    if (isInclusiveAncestor(otherNode, node)) {
        // Step 4: otherNode is ancestor of node
        // Find ancestor of node whose parent is otherNode
        child = node;
        while (NodeImpl.getParent(child)) |parent| {
            if (parent == otherNode) break;
            child = parent;
        }
    } else {
        // Step 5: Find ancestor of node whose parent is otherNode
        var current = node;
        while (NodeImpl.getParent(current)) |parent| {
            if (parent == otherNode) {
                child = current;
                break;
            }
            current = parent;
        } else {
            // This shouldn't happen if nodes have same root
            return .equal;
        }
    }

    // Step 6: Compare child's index with otherOffset
    const childIndex = getChildIndex(otherNode, child) orelse return .equal;
    if (childIndex < otherOffset) {
        return .after;
    }

    // Step 7: Return before
    return .before;
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

/// Helper: Check if a node is contained in this range
/// Per DOM spec: A node is contained if:
/// - node's root is range's root
/// - (node, 0) is after range's start
/// - (node, node's length) is before range's end
fn isNodeContained(internal: *InternalState, node: *runtime.Instance) bool {
    const start = internal.start_container orelse return false;
    const end = internal.end_container orelse return false;

    // Check same root
    const nodeRoot = getRoot(node);
    const rangeRoot = getRoot(start);
    if (nodeRoot != rangeRoot) return false;

    // Check (node, 0) is after start
    const afterStart = compareBoundaryPoints(node, 0, start, internal.start_offset);
    if (afterStart != .after) return false;

    // Check (node, node's length) is before end
    const nodeLength = getNodeLength(node);
    const beforeEnd = compareBoundaryPoints(node, nodeLength, end, internal.end_offset);
    if (beforeEnd != .before) return false;

    return true;
}

/// Helper: Check if a node is partially contained in this range
/// Per DOM spec: A node is partially contained if it's an inclusive ancestor
/// of the start node but not the end node, or vice versa
fn isNodePartiallyContained(internal: *InternalState, node: *runtime.Instance) bool {
    const start = internal.start_container orelse return false;
    const end = internal.end_container orelse return false;

    const isAncestorOfStart = isInclusiveAncestor(node, start);
    const isAncestorOfEnd = isInclusiveAncestor(node, end);

    // Partially contained if ancestor of one but not both
    return (isAncestorOfStart and !isAncestorOfEnd) or (!isAncestorOfStart and isAncestorOfEnd);
}

/// DOM §5.4 - Range.deleteContents()
/// Removes the contents of the range from the range's context tree
pub fn call_deleteContents(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: If range is collapsed, return
    const start = internal.start_container orelse return error.InvalidStateError;
    const end = internal.end_container orelse return error.InvalidStateError;

    if (start == end and internal.start_offset == internal.end_offset) {
        return; // Collapsed, nothing to delete
    }

    // Step 2: Special case - same CharacterData node
    const start_type = NodeImpl.getNodeType(start) orelse return error.InvalidStateError;
    if (start == end and (start_type == NodeImpl.NodeType.TEXT_NODE or
        start_type == NodeImpl.NodeType.PROCESSING_INSTRUCTION_NODE or
        start_type == NodeImpl.NodeType.COMMENT_NODE))
    {
        // Delete data within this CharacterData node
        const CharacterDataImpl = @import("CharacterData.zig");
        const count = internal.end_offset - internal.start_offset;
        try CharacterDataImpl.deleteDataRange(start, internal.start_offset, count);
        return;
    }

    // Step 3: Find common ancestor and collect contained children
    const commonAncestor = (try get_commonAncestorContainer(instance));

    // Step 4: Remove contained children
    var child = NodeImpl.getFirstChild(commonAncestor);
    while (child) |c| {
        const next = NodeImpl.getNextSibling(c);
        if (isNodeContained(internal, c)) {
            // Remove this child from its parent
            try NodeImpl.removeNodeFromParent(c, commonAncestor);
        }
        child = next;
    }

    // Step 5: Collapse range to start
    internal.end_container = start;
    internal.end_offset = internal.start_offset;
}

/// DOM §5.6 - Range.extractContents()
/// Moves the contents of the range into a DocumentFragment
pub fn call_extractContents(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: Create fragment (use interface per Golden Rule #13)
    const fragment = interfaces.DocumentFragment.call_constructor(instance.ctx) catch return error.OutOfMemory;

    // Step 2: If collapsed, return empty fragment
    const start = internal.start_container orelse return error.InvalidStateError;
    const end = internal.end_container orelse return error.InvalidStateError;

    if (start == end and internal.start_offset == internal.end_offset) {
        return fragment;
    }

    // Step 3: Store original boundary for resetting range
    const originalStartNode = start;
    const originalStartOffset = internal.start_offset;

    // Step 4: Special case - same CharacterData node
    const start_type = NodeImpl.getNodeType(start) orelse return error.InvalidStateError;
    if (start == end and (start_type == NodeImpl.NodeType.TEXT_NODE or
        start_type == NodeImpl.NodeType.PROCESSING_INSTRUCTION_NODE or
        start_type == NodeImpl.NodeType.COMMENT_NODE))
    {
        // Clone the node, set its data to the substring, append to fragment (use interface per Golden Rule #13)
        const clone = interfaces.Node.call_cloneNode(start, webidl.Opt(bool).passed(false)) catch return error.OutOfMemory;
        const CharacterDataImpl = @import("CharacterData.zig");

        // Get substring and set on clone
        const data = CharacterDataImpl.getData(start) orelse "";
        if (internal.start_offset < data.len and internal.end_offset <= data.len) {
            const substring = data[internal.start_offset..internal.end_offset];
            CharacterDataImpl.setData(clone, substring) catch return error.OutOfMemory;
        }

        // Append clone to fragment
        _ = interfaces.Node.call_appendChild(fragment, clone) catch return error.HierarchyRequestError;

        // Delete data from original
        const count = internal.end_offset - internal.start_offset;
        CharacterDataImpl.deleteDataRange(start, internal.start_offset, count) catch return error.InvalidStateError;

        return fragment;
    }

    // Step 5: Find common ancestor and move contained children to fragment
    const commonAncestor = (try get_commonAncestorContainer(instance));

    var child = NodeImpl.getFirstChild(commonAncestor);
    while (child) |c| {
        const next = NodeImpl.getNextSibling(c);
        if (isNodeContained(internal, c)) {
            // Check if doctype - throw HierarchyRequestError
            const child_type = NodeImpl.getNodeType(c) orelse continue;
            if (child_type == NodeImpl.NodeType.DOCUMENT_TYPE_NODE) {
                return error.HierarchyRequestError;
            }

            // Remove from original parent and append to fragment (use interface per Golden Rule #13)
            try NodeImpl.removeNodeFromParent(c, commonAncestor);
            _ = try interfaces.Node.call_appendChild(fragment, c);
        }
        child = next;
    }

    // Step 6: Collapse range to original start
    internal.start_container = originalStartNode;
    internal.start_offset = originalStartOffset;
    internal.end_container = originalStartNode;
    internal.end_offset = originalStartOffset;

    return fragment;
}

/// DOM §5.6 - Range.cloneContents()
/// Returns a DocumentFragment that is a copy of the contents
pub fn call_cloneContents(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: Create fragment (use interface per Golden Rule #13)
    const fragment = interfaces.DocumentFragment.call_constructor(instance.ctx) catch return error.OutOfMemory;

    // Step 2: If collapsed, return empty fragment
    const start = internal.start_container orelse return error.InvalidStateError;
    const end = internal.end_container orelse return error.InvalidStateError;

    if (start == end and internal.start_offset == internal.end_offset) {
        return fragment;
    }

    // Step 4: Special case - same CharacterData node
    const start_type = NodeImpl.getNodeType(start) orelse return error.InvalidStateError;
    if (start == end and (start_type == NodeImpl.NodeType.TEXT_NODE or
        start_type == NodeImpl.NodeType.PROCESSING_INSTRUCTION_NODE or
        start_type == NodeImpl.NodeType.COMMENT_NODE))
    {
        // Clone the node, set its data to the substring, append to fragment (use interface per Golden Rule #13)
        const clone = interfaces.Node.call_cloneNode(start, webidl.Opt(bool).passed(false)) catch return error.OutOfMemory;
        const CharacterDataImpl = @import("CharacterData.zig");

        // Get substring and set on clone
        const data = CharacterDataImpl.getData(start) orelse "";
        if (internal.start_offset < data.len and internal.end_offset <= data.len) {
            const substring = data[internal.start_offset..internal.end_offset];
            CharacterDataImpl.setData(clone, substring) catch return error.OutOfMemory;
        }

        // Append clone to fragment
        _ = interfaces.Node.call_appendChild(fragment, clone) catch return error.HierarchyRequestError;

        return fragment;
    }

    // Step 5: Find common ancestor and clone contained children to fragment
    const commonAncestor = (try get_commonAncestorContainer(instance));

    var child = NodeImpl.getFirstChild(commonAncestor);
    while (child) |c| {
        const next = NodeImpl.getNextSibling(c);
        if (isNodeContained(internal, c)) {
            // Check if doctype - throw HierarchyRequestError
            const child_type = NodeImpl.getNodeType(c) orelse continue;
            if (child_type == NodeImpl.NodeType.DOCUMENT_TYPE_NODE) {
                return error.HierarchyRequestError;
            }

            // Deep clone and append to fragment (use interface per Golden Rule #13)
            const clone = try interfaces.Node.call_cloneNode(c, webidl.Opt(bool).passed(true));
            _ = try interfaces.Node.call_appendChild(fragment, clone);
        }
        child = next;
    }

    return fragment;
}

/// DOM §5.4 - Range.insertNode(node)
/// Inserts node into the range's context tree
pub fn call_insertNode(instance: *runtime.Instance, node: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    const start = internal.start_container orelse return error.InvalidStateError;
    const start_type = NodeImpl.getNodeType(start) orelse return error.InvalidStateError;

    // Step 1: Validate start node
    if (start_type == NodeImpl.NodeType.PROCESSING_INSTRUCTION_NODE or
        start_type == NodeImpl.NodeType.COMMENT_NODE or
        (start_type == NodeImpl.NodeType.TEXT_NODE and NodeImpl.getParent(start) == null) or
        start == node)
    {
        return error.HierarchyRequestError;
    }

    // Step 2-4: Determine reference node and parent
    var referenceNode: ?*runtime.Instance = null;
    var parent: *runtime.Instance = undefined;

    if (start_type == NodeImpl.NodeType.TEXT_NODE) {
        // Step 3: Start node is Text node - reference is start node
        referenceNode = start;
        parent = NodeImpl.getParent(start) orelse return error.HierarchyRequestError;
    } else {
        // Step 4: Get child at start offset
        var idx: u32 = 0;
        var child = NodeImpl.getFirstChild(start);
        while (child != null and idx < internal.start_offset) : (idx += 1) {
            child = NodeImpl.getNextSibling(child.?);
        }
        referenceNode = child;
        parent = start;
    }

    // Step 5-6: Validate pre-insertion
    // (simplified - full validation would need ensurePreInsertValidity)

    // Step 7: If start node is Text, split it (use interface per Golden Rule #13)
    if (start_type == NodeImpl.NodeType.TEXT_NODE and internal.start_offset > 0) {
        const newText = try interfaces.Text.call_splitText(start, internal.start_offset);
        referenceNode = newText;
    }

    // Step 8: If node is referenceNode, use its next sibling
    if (referenceNode != null and node == referenceNode.?) {
        referenceNode = NodeImpl.getNextSibling(referenceNode.?);
    }

    // Step 9: Remove node from its current parent if it has one
    if (NodeImpl.getParent(node)) |oldParent| {
        try NodeImpl.removeNodeFromParent(node, oldParent);
    }

    // Step 10-11: Calculate new offset
    var newOffset: u32 = 0;
    if (referenceNode) |refNode| {
        newOffset = getChildIndex(parent, refNode) orelse 0;
    } else {
        newOffset = NodeImpl.getChildCount(parent);
    }

    // Increase by node's length
    const node_type = NodeImpl.getNodeType(node) orelse return error.InvalidStateError;
    if (node_type == NodeImpl.NodeType.DOCUMENT_FRAGMENT_NODE) {
        newOffset += NodeImpl.getChildCount(node);
    } else {
        newOffset += 1;
    }

    // Step 12: Insert node before referenceNode (use interface per Golden Rule #13)
    if (referenceNode) |refNode| {
        _ = interfaces.Node.call_insertBefore(parent, node, refNode) catch return error.HierarchyRequestError;
    } else {
        _ = interfaces.Node.call_appendChild(parent, node) catch return error.HierarchyRequestError;
    }

    // Step 13: If range is collapsed, update end
    if (internal.start_container == internal.end_container and
        internal.start_offset == internal.end_offset)
    {
        internal.end_container = parent;
        internal.end_offset = newOffset;
    }
}

/// DOM §5.4 - Range.surroundContents(newParent)
/// Moves the contents of the range into newParent, then inserts newParent at range's start
pub fn call_surroundContents(instance: *runtime.Instance, newParent: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: Check for partially contained non-Text nodes
    const commonAncestor = (try get_commonAncestorContainer(instance));

    var child = NodeImpl.getFirstChild(commonAncestor);
    while (child) |c| {
        if (isNodePartiallyContained(internal, c)) {
            const child_type = NodeImpl.getNodeType(c) orelse continue;
            if (child_type != NodeImpl.NodeType.TEXT_NODE) {
                return error.InvalidStateError;
            }
        }
        child = NodeImpl.getNextSibling(c);
    }

    // Step 2: Validate newParent type
    const newParent_type = NodeImpl.getNodeType(newParent) orelse return error.InvalidStateError;
    if (newParent_type == NodeImpl.NodeType.DOCUMENT_NODE or
        newParent_type == NodeImpl.NodeType.DOCUMENT_TYPE_NODE or
        newParent_type == NodeImpl.NodeType.DOCUMENT_FRAGMENT_NODE)
    {
        return error.InvalidNodeTypeError;
    }

    // Step 3: Extract range contents into a fragment
    const fragment = try call_extractContents(instance);

    // Step 4: Remove all children from newParent
    var npChild = NodeImpl.getFirstChild(newParent);
    while (npChild) |c| {
        const next = NodeImpl.getNextSibling(c);
        try NodeImpl.removeNodeFromParent(c, newParent);
        npChild = next;
    }

    // Step 5: Insert newParent into range
    try call_insertNode(instance, newParent);

    // Step 6: Append fragment to newParent (use interface per Golden Rule #13)
    _ = interfaces.Node.call_appendChild(newParent, fragment) catch return error.HierarchyRequestError;

    // Step 7: Select newParent within range
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
    newInternal.owner_document = internal.owner_document;

    // TODO: Register with document

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
