//! Range interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-range

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");

const Allocator = std.mem.Allocator;
const Node = @import("node").Node;
const DocumentFragment = @import("document_fragment").DocumentFragment;

/// DOM Spec: interface Range : AbstractRange
///
/// A Range object represents a sequence of content within the node tree.
/// Each range has a start and an end which are boundary points.
/// A boundary point is a tuple consisting of a node and an offset.
pub const Range = webidl.interface(struct {
    // AbstractRange fields (will be flattened by codegen)
    // We implement AbstractRange inline since it's just readonly attributes

    allocator: Allocator,

    /// Start boundary point - node
    start_container: *Node,

    /// Start boundary point - offset
    start_offset: u32,

    /// End boundary point - node
    end_container: *Node,

    /// End boundary point - offset
    end_offset: u32,

    /// DOM §5 - Range constructor
    /// The new Range() constructor steps are to set this's start and end to
    /// (current global object's associated Document, 0).
    pub fn init(allocator: Allocator, document: *Node) !Range {
        return .{
            .allocator = allocator,
            .start_container = document,
            .start_offset = 0,
            .end_container = document,
            .end_offset = 0,
        };
    }

    pub fn deinit(self: *Range) void {
        _ = self;
        // No cleanup needed - we don't own the nodes
    }

    // ========================================================================
    // AbstractRange attributes
    // ========================================================================

    /// DOM §5 - AbstractRange.startContainer
    /// Returns the node at the start of the range
    pub fn get_startContainer(self: *const Range) *Node {
        return self.start_container;
    }

    /// DOM §5 - AbstractRange.startOffset
    /// Returns the offset within the start node
    pub fn get_startOffset(self: *const Range) u32 {
        return self.start_offset;
    }

    /// DOM §5 - AbstractRange.endContainer
    /// Returns the node at the end of the range
    pub fn get_endContainer(self: *const Range) *Node {
        return self.end_container;
    }

    /// DOM §5 - AbstractRange.endOffset
    /// Returns the offset within the end node
    pub fn get_endOffset(self: *const Range) u32 {
        return self.end_offset;
    }

    /// DOM §5 - AbstractRange.collapsed
    /// Returns true if the range's start and end are the same position
    pub fn get_collapsed(self: *const Range) bool {
        return self.start_container == self.end_container and
            self.start_offset == self.end_offset;
    }

    // ========================================================================
    // Range attributes
    // ========================================================================

    /// DOM §5 - Range.commonAncestorContainer
    /// Returns the node, furthest away from the document, that is an ancestor
    /// of both range's start node and end node.
    pub fn get_commonAncestorContainer(self: *const Range) *Node {
        const dom = @import("dom");

        // Let container be start node
        var container = self.start_container;

        // While container is not an inclusive ancestor of end node,
        // let container be container's parent
        while (!dom.tree_helpers.isInclusiveAncestor(container, self.end_container)) {
            container = dom.tree_helpers.getParentNode(container) orelse {
                // If we reach root without finding common ancestor, return start container
                return self.start_container;
            };
        }

        return container;
    }

    // ========================================================================
    // Range mutation methods - setStart/setEnd
    // ========================================================================

    /// DOM §5.3 - Range.setStart(node, offset)
    /// Sets the start of the range to the given boundary point
    pub fn call_setStart(self: *Range, node: *Node, offset: u32) !void {
        // TODO: Implement validation and set the boundary point
        // Per spec: If node is a doctype, throw InvalidNodeTypeError
        // Set start to boundary point (node, offset)
        self.start_container = node;
        self.start_offset = offset;

        // If start is after end, set end to start
        if (self.isAfter(self.start_container, self.start_offset, self.end_container, self.end_offset)) {
            self.end_container = self.start_container;
            self.end_offset = self.start_offset;
        }
    }

    /// DOM §5.3 - Range.setEnd(node, offset)
    /// Sets the end of the range to the given boundary point
    pub fn call_setEnd(self: *Range, node: *Node, offset: u32) !void {
        // TODO: Implement validation and set the boundary point
        // Per spec: If node is a doctype, throw InvalidNodeTypeError
        // Set end to boundary point (node, offset)
        self.end_container = node;
        self.end_offset = offset;

        // If end is before start, set start to end
        if (self.isAfter(self.end_container, self.end_offset, self.start_container, self.start_offset)) {
            self.start_container = self.end_container;
            self.start_offset = self.end_offset;
        }
    }

    /// Helper: Check if boundary point A is after boundary point B
    /// Per DOM spec: A boundary point (nodeA, offsetA) is after another
    /// boundary point (nodeB, offsetB) if:
    /// - nodeA is after nodeB in tree order, or
    /// - nodeA is nodeB and offsetA is greater than offsetB
    fn isAfter(self: *const Range, nodeA: *Node, offsetA: u32, nodeB: *Node, offsetB: u32) bool {
        _ = self;

        // Same node: compare offsets
        if (nodeA == nodeB) {
            return offsetA > offsetB;
        }

        // Different nodes: use tree order
        const dom = @import("dom");
        return dom.tree_helpers.isFollowing(nodeA, nodeB);
    }

    /// Helper: Compare position of boundary point (node, offset) relative to (otherNode, otherOffset)
    /// Returns: .before, .equal, or .after
    /// Per DOM §5.5 boundary point position algorithm
    fn compareBoundaryPointsHelper(
        node: *Node,
        offset: u32,
        otherNode: *Node,
        otherOffset: u32,
    ) enum { before, equal, after } {
        // Step 1: Assert nodes have same root (caller's responsibility)

        // Step 2: If node is otherNode, compare offsets
        if (node == otherNode) {
            if (offset == otherOffset) return .equal;
            if (offset < otherOffset) return .before;
            return .after;
        }

        const dom = @import("dom");

        // Step 3: If otherNode is following node
        if (dom.tree_helpers.isFollowing(otherNode, node)) {
            // Recursively compare in reverse
            const reversed = compareBoundaryPointsHelper(otherNode, otherOffset, node, offset);
            return switch (reversed) {
                .before => .after,
                .after => .before,
                .equal => .equal,
            };
        }

        // Step 4 & 5: Determine child of otherNode to compare
        var child: *Node = undefined;
        if (dom.tree_helpers.isAncestor(otherNode, node)) {
            // Step 4: otherNode is ancestor of node
            child = node;
        } else {
            // Step 5: Find ancestor of node whose parent is otherNode
            var current = node;
            while (current.parent_node) |parent| {
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
        const childIndex = dom.tree_helpers.getChildIndex(otherNode, child) orelse return .equal;
        if (childIndex < otherOffset) {
            return .after;
        }

        // Step 7: Return before
        return .before;
    }

    /// DOM §5.3 - Range.setStartBefore(node)
    /// Sets the start to immediately before the given node
    pub fn call_setStartBefore(self: *Range, node: *Node) !void {
        const dom = @import("dom");
        const parent = dom.tree_helpers.getParentNode(node) orelse return error.InvalidNodeTypeError;
        const index = dom.tree_helpers.getChildIndex(parent, node) orelse return error.InvalidStateError;

        try self.call_setStart(parent, @intCast(index));
    }

    /// DOM §5.3 - Range.setStartAfter(node)
    /// Sets the start to immediately after the given node
    pub fn call_setStartAfter(self: *Range, node: *Node) !void {
        const dom = @import("dom");
        const parent = dom.tree_helpers.getParentNode(node) orelse return error.InvalidNodeTypeError;
        const index = dom.tree_helpers.getChildIndex(parent, node) orelse return error.InvalidStateError;

        try self.call_setStart(parent, @intCast(index + 1));
    }

    /// DOM §5.3 - Range.setEndBefore(node)
    /// Sets the end to immediately before the given node
    pub fn call_setEndBefore(self: *Range, node: *Node) !void {
        const dom = @import("dom");
        const parent = dom.tree_helpers.getParentNode(node) orelse return error.InvalidNodeTypeError;
        const index = dom.tree_helpers.getChildIndex(parent, node) orelse return error.InvalidStateError;

        try self.call_setEnd(parent, @intCast(index));
    }

    /// DOM §5.3 - Range.setEndAfter(node)
    /// Sets the end to immediately after the given node
    pub fn call_setEndAfter(self: *Range, node: *Node) !void {
        const dom = @import("dom");
        const parent = dom.tree_helpers.getParentNode(node) orelse return error.InvalidNodeTypeError;
        const index = dom.tree_helpers.getChildIndex(parent, node) orelse return error.InvalidStateError;

        try self.call_setEnd(parent, @intCast(index + 1));
    }

    /// DOM §5.3 - Range.collapse(toStart)
    /// Collapses the range to one of its boundary points
    pub fn call_collapse(self: *Range, toStart: bool) void {
        if (toStart) {
            // Collapse to start
            self.end_container = self.start_container;
            self.end_offset = self.start_offset;
        } else {
            // Collapse to end
            self.start_container = self.end_container;
            self.start_offset = self.end_offset;
        }
    }

    /// DOM §5.3 - Range.selectNode(node)
    /// Selects the entire node and its contents
    pub fn call_selectNode(self: *Range, node: *Node) !void {
        const dom = @import("dom");
        const parent = dom.tree_helpers.getParentNode(node) orelse return error.InvalidNodeTypeError;
        const index = dom.tree_helpers.getChildIndex(parent, node) orelse return error.InvalidStateError;

        try self.call_setStart(parent, @intCast(index));
        try self.call_setEnd(parent, @intCast(index + 1));
    }

    /// DOM §5.3 - Range.selectNodeContents(node)
    /// Selects the contents of the node
    pub fn call_selectNodeContents(self: *Range, node: *Node) !void {
        // If node is a doctype, throw InvalidNodeTypeError
        if (node.node_type == Node.DOCUMENT_TYPE_NODE) {
            return error.InvalidNodeTypeError;
        }

        const length = node.child_nodes.size();
        try self.call_setStart(node, 0);
        try self.call_setEnd(node, @intCast(length));
    }

    // ========================================================================
    // Range comparison constants
    // ========================================================================

    pub const START_TO_START: u16 = 0;
    pub const START_TO_END: u16 = 1;
    pub const END_TO_END: u16 = 2;
    pub const END_TO_START: u16 = 3;

    // ========================================================================
    // Placeholder methods (to be implemented in separate tasks)
    // ========================================================================

    /// DOM §5.5 - Range.compareBoundaryPoints(how, sourceRange)
    /// Compares boundary points between two ranges
    /// Returns -1 if this's point is before sourceRange's point, 0 if equal, 1 if after
    pub fn call_compareBoundaryPoints(self: *Range, how: u16, sourceRange: *Range) !i16 {
        // Step 1: Validate 'how' parameter
        if (how != START_TO_START and how != START_TO_END and how != END_TO_END and how != END_TO_START) {
            return error.NotSupportedError;
        }

        // Step 2: Check same root
        const dom = @import("dom");
        const thisRoot = dom.tree.getRoot(self.start_container);
        const sourceRoot = dom.tree.getRoot(sourceRange.start_container);
        if (thisRoot != sourceRoot) {
            return error.WrongDocumentError;
        }

        // Step 3: Determine boundary points based on 'how'
        var thisPoint: struct { node: *Node, offset: u32 } = undefined;
        var otherPoint: struct { node: *Node, offset: u32 } = undefined;

        switch (how) {
            START_TO_START => {
                thisPoint = .{ .node = self.start_container, .offset = self.start_offset };
                otherPoint = .{ .node = sourceRange.start_container, .offset = sourceRange.start_offset };
            },
            START_TO_END => {
                thisPoint = .{ .node = self.end_container, .offset = self.end_offset };
                otherPoint = .{ .node = sourceRange.start_container, .offset = sourceRange.start_offset };
            },
            END_TO_END => {
                thisPoint = .{ .node = self.end_container, .offset = self.end_offset };
                otherPoint = .{ .node = sourceRange.end_container, .offset = sourceRange.end_offset };
            },
            END_TO_START => {
                thisPoint = .{ .node = self.start_container, .offset = self.start_offset };
                otherPoint = .{ .node = sourceRange.end_container, .offset = sourceRange.end_offset };
            },
            else => return error.NotSupportedError,
        }

        // Step 4: Compare positions and return result
        const position = compareBoundaryPointsHelper(
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

    /// DOM §5.4 - Range.deleteContents()
    /// TODO: Implement in whatwg-qx0
    pub fn call_deleteContents(self: *Range) !void {
        _ = self;
        return error.NotImplemented;
    }

    /// DOM §5.6 - Range.extractContents()
    /// TODO: Implement in whatwg-boy
    pub fn call_extractContents(self: *Range) !*DocumentFragment {
        _ = self;
        return error.NotImplemented;
    }

    /// DOM §5.6 - Range.cloneContents()
    /// TODO: Implement in whatwg-boy
    pub fn call_cloneContents(self: *Range) !*DocumentFragment {
        _ = self;
        return error.NotImplemented;
    }

    /// DOM §5.4 - Range.insertNode(node)
    /// TODO: Implement in whatwg-qx0
    pub fn call_insertNode(self: *Range, node: *Node) !void {
        _ = self;
        _ = node;
        return error.NotImplemented;
    }

    /// DOM §5.4 - Range.surroundContents(newParent)
    /// TODO: Implement in whatwg-qx0
    pub fn call_surroundContents(self: *Range, newParent: *Node) !void {
        _ = self;
        _ = newParent;
        return error.NotImplemented;
    }

    /// DOM §5 - Range.cloneRange()
    pub fn call_cloneRange(self: *Range) !*Range {
        const range = try self.allocator.create(Range);
        range.* = try Range.init(self.allocator, self.start_container);
        range.start_container = self.start_container;
        range.start_offset = self.start_offset;
        range.end_container = self.end_container;
        range.end_offset = self.end_offset;
        return range;
    }

    /// DOM §5 - Range.detach()
    /// Does nothing. Kept for compatibility.
    pub fn call_detach(self: *Range) void {
        _ = self;
        // Historical artifact - does nothing per spec
    }

    /// DOM §5 - Range.isPointInRange(node, offset)
    /// Returns true if the point (node, offset) is within the range
    pub fn call_isPointInRange(self: *Range, node: *Node, offset: u32) !bool {
        const dom = @import("dom");

        // Step 1: Check if node's root is different from this's root
        const nodeRoot = dom.tree.getRoot(node);
        const thisRoot = dom.tree.getRoot(self.start_container);
        if (nodeRoot != thisRoot) {
            return false;
        }

        // Step 2: If node is a doctype, throw error
        if (node.node_type == Node.DOCUMENT_TYPE_NODE) {
            return error.InvalidNodeTypeError;
        }

        // Step 3: If offset is greater than node's length, throw error
        const nodeLength = node.child_nodes.size();
        if (offset > nodeLength) {
            return error.IndexSizeError;
        }

        // Step 4: Check if (node, offset) is before start or after end
        const positionVsStart = compareBoundaryPointsHelper(node, offset, self.start_container, self.start_offset);
        const positionVsEnd = compareBoundaryPointsHelper(node, offset, self.end_container, self.end_offset);

        if (positionVsStart == .before or positionVsEnd == .after) {
            return false;
        }

        // Step 5: Return true
        return true;
    }

    /// DOM §5 - Range.comparePoint(node, offset)
    /// Compares the point (node, offset) to the range
    /// Returns -1 if before, 0 if in range, 1 if after
    pub fn call_comparePoint(self: *Range, node: *Node, offset: u32) !i16 {
        const dom = @import("dom");

        // Step 1: Check if node's root is different from this's root
        const nodeRoot = dom.tree.getRoot(node);
        const thisRoot = dom.tree.getRoot(self.start_container);
        if (nodeRoot != thisRoot) {
            return error.WrongDocumentError;
        }

        // Step 2: If node is a doctype, throw error
        if (node.node_type == Node.DOCUMENT_TYPE_NODE) {
            return error.InvalidNodeTypeError;
        }

        // Step 3: If offset is greater than node's length, throw error
        const nodeLength = node.child_nodes.size();
        if (offset > nodeLength) {
            return error.IndexSizeError;
        }

        // Step 4: If (node, offset) is before start, return -1
        const positionVsStart = compareBoundaryPointsHelper(node, offset, self.start_container, self.start_offset);
        if (positionVsStart == .before) {
            return -1;
        }

        // Step 5: If (node, offset) is after end, return 1
        const positionVsEnd = compareBoundaryPointsHelper(node, offset, self.end_container, self.end_offset);
        if (positionVsEnd == .after) {
            return 1;
        }

        // Step 6: Return 0
        return 0;
    }

    /// DOM §5 - Range.intersectsNode(node)
    /// Returns true if the node intersects with the range
    pub fn call_intersectsNode(self: *Range, node: *Node) bool {
        const dom = @import("dom");

        // Step 1: Check if node's root is different from this's root
        const nodeRoot = dom.tree.getRoot(node);
        const thisRoot = dom.tree.getRoot(self.start_container);
        if (nodeRoot != thisRoot) {
            return false;
        }

        // Step 2: Let parent be node's parent
        const parent = dom.tree_helpers.getParentNode(node) orelse {
            // Step 3: If parent is null, return true
            return true;
        };

        // Step 4: Let offset be node's index
        const offset = dom.tree_helpers.getChildIndex(parent, node) orelse return false;

        // Step 5: Check if (parent, offset) is before end and (parent, offset+1) is after start
        const beforeEnd = compareBoundaryPointsHelper(parent, @intCast(offset), self.end_container, self.end_offset);
        const afterStart = compareBoundaryPointsHelper(parent, @intCast(offset + 1), self.start_container, self.start_offset);

        if (beforeEnd != .after and afterStart != .before) {
            return true;
        }

        // Step 6: Return false
        return false;
    }

    /// DOM §5 - Range stringifier
    /// Returns the text content of the range
    pub fn toString(self: *Range, allocator: Allocator) ![]const u8 {
        // TODO: Implement per spec §5.7
        _ = self;
        _ = allocator;
        return error.NotImplemented;
    }
}, .{
    .exposed = &.{.Window},
});
