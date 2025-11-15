//! Range interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-range

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");

const Allocator = std.mem.Allocator;
const AbstractRange = @import("abstract_range").AbstractRange;
const Node = @import("node").Node;
const DocumentFragment = @import("document_fragment").DocumentFragment;
const Document = @import("document").Document;
const CharacterData = @import("character_data").CharacterData;
const Text = @import("text").Text;

/// DOM Spec: interface Range : AbstractRange
///
/// A Range object represents a sequence of content within the node tree.
/// Each range has a start and an end which are boundary points.
/// A boundary point is a tuple consisting of a node and an offset.
///
/// Unlike StaticRange, Range objects are "live" - they update when the DOM mutates.
pub const Range = webidl.interface(struct {
    pub const extends = AbstractRange;

    allocator: Allocator,
    /// Owner document - needed for per-document range tracking
    owner_document: *Document,

    /// DOM §5 - Range constructor
    /// The new Range() constructor steps are to set this's start and end to
    /// (current global object's associated Document, 0).
    pub fn init(allocator: Allocator, document_node: *Node) !Range {
        // Get Document from node - check if it's a Document node
        if (document_node.node_type != 9) { // DOCUMENT_NODE = 9
            return error.InvalidNodeTypeError;
        }
        const doc: *Document = @ptrCast(document_node);

        const range = Range{
            .allocator = allocator,
            .owner_document = doc,
            .start_container = document_node,
            .start_offset = 0,
            .end_container = document_node,
            .end_offset = 0,
        };

        // Note: Cannot auto-register here since we're in init
        // Caller must call registerWithDocument after heap allocation
        return range;
    }

    /// Register this range with its owner document for live tracking
    /// Must be called after init and heap allocation
    pub fn registerWithDocument(self: *Range) !void {
        try self.owner_document.registerRange(self);
    }

    pub fn deinit(self: *Range) void {
        // Unregister from document
        self.owner_document.unregisterRange(self);
        // No other cleanup needed - we don't own the nodes
    }

    // ========================================================================
    // Range-specific attributes (AbstractRange attributes inherited via extends)
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

    /// Helper: Get the length of a node per DOM spec
    /// Per DOM §5.2: The length of a node is:
    /// - 0 for DocumentType or Attr nodes
    /// - data's length for CharacterData nodes
    /// - number of children for other nodes
    fn getNodeLength(node: *Node) u32 {
        switch (node.node_type) {
            Node.DOCUMENT_TYPE_NODE, Node.ATTRIBUTE_NODE => return 0,
            Node.TEXT_NODE, Node.PROCESSING_INSTRUCTION_NODE, Node.COMMENT_NODE => {
                // CharacterData nodes - get data length
                // Safe cast: we've verified node_type above
                const charData: *CharacterData = @ptrCast(@alignCast(node));
                return charData.get_length();
            },
            else => {
                // Element, Document, DocumentFragment, etc. - return number of children
                return @intCast(node.child_nodes.size());
            },
        }
    }

    /// DOM §5.3 - Range.setStart(node, offset)
    /// Sets the start of the range to the given boundary point
    pub fn call_setStart(self: *Range, node: *Node, offset: u32) !void {
        // Step 1: If node is a doctype, throw InvalidNodeTypeError
        if (node.node_type == Node.DOCUMENT_TYPE_NODE) {
            return error.InvalidNodeTypeError;
        }

        // Step 2: If offset > node's length, throw IndexSizeError
        const nodeLength = getNodeLength(node);
        if (offset > nodeLength) {
            return error.IndexSizeError;
        }

        // Step 3: Let bp be boundary point (node, offset)
        // Step 4: Set the start
        const dom = @import("dom");
        const nodeRoot = dom.tree.root(node);
        const rangeRoot = dom.tree.root(self.start_container);

        // Step 4.1: If range's root is not equal to node's root, or if bp is after range's end
        if (nodeRoot != rangeRoot or self.isAfter(node, offset, self.end_container, self.end_offset)) {
            // Set range's end to bp
            self.end_container = node;
            self.end_offset = offset;
        }

        // Step 4.2: Set range's start to bp
        self.start_container = node;
        self.start_offset = offset;
    }

    /// DOM §5.3 - Range.setEnd(node, offset)
    /// Sets the end of the range to the given boundary point
    pub fn call_setEnd(self: *Range, node: *Node, offset: u32) !void {
        // Step 1: If node is a doctype, throw InvalidNodeTypeError
        if (node.node_type == Node.DOCUMENT_TYPE_NODE) {
            return error.InvalidNodeTypeError;
        }

        // Step 2: If offset > node's length, throw IndexSizeError
        const nodeLength = getNodeLength(node);
        if (offset > nodeLength) {
            return error.IndexSizeError;
        }

        // Step 3: Let bp be boundary point (node, offset)
        // Step 5: Set the end
        const dom = @import("dom");
        const nodeRoot = dom.tree.root(node);
        const rangeRoot = dom.tree.root(self.start_container);

        // Step 5.1: If range's root is not equal to node's root, or if bp is before range's start
        if (nodeRoot != rangeRoot or self.isAfter(self.start_container, self.start_offset, node, offset)) {
            // Set range's start to bp
            self.start_container = node;
            self.start_offset = offset;
        }

        // Step 5.2: Set range's end to bp
        self.end_container = node;
        self.end_offset = offset;
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

    /// Helper: Check if a node is contained in this range
    /// Per DOM spec: A node is contained if:
    /// - node's root is range's root
    /// - (node, 0) is after range's start
    /// - (node, node's length) is before range's end
    fn isNodeContained(self: *const Range, node: *Node) bool {
        const dom = @import("dom");

        // Check same root
        const nodeRoot = dom.tree.root(node);
        const rangeRoot = dom.tree.root(self.start_container);
        if (nodeRoot != rangeRoot) return false;

        // Check (node, 0) is after start
        const afterStart = compareBoundaryPointsHelper(node, 0, self.start_container, self.start_offset);
        if (afterStart != .after) return false;

        // Check (node, node's length) is before end
        const nodeLength = node.child_nodes.size();
        const beforeEnd = compareBoundaryPointsHelper(node, @intCast(nodeLength), self.end_container, self.end_offset);
        if (beforeEnd != .before) return false;

        return true;
    }

    /// Helper: Check if a node is partially contained in this range
    /// Per DOM spec: A node is partially contained if it's an inclusive ancestor
    /// of the start node but not the end node, or vice versa
    fn isNodePartiallyContained(self: *const Range, node: *Node) bool {
        const dom = @import("dom");

        const isAncestorOfStart = dom.tree_helpers.isInclusiveAncestor(node, self.start_container);
        const isAncestorOfEnd = dom.tree_helpers.isInclusiveAncestor(node, self.end_container);

        // Partially contained if ancestor of one but not both
        return (isAncestorOfStart and !isAncestorOfEnd) or (!isAncestorOfStart and isAncestorOfEnd);
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
        const thisRoot = dom.tree.root(self.start_container);
        const sourceRoot = dom.tree.root(sourceRange.start_container);
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
    /// Removes the contents of the range from the range's context tree
    pub fn call_deleteContents(self: *Range) !void {
        // Spec: Remove all contained children within this from their parents
        // First, collect all contained children
        var containedChildren = infra.List(*Node).init(self.allocator);
        defer containedChildren.deinit();

        // Find common ancestor
        const commonAncestor = self.get_commonAncestorContainer();

        // Collect all children of common ancestor that are contained
        for (commonAncestor.child_nodes.items()) |child| {
            if (self.isNodeContained(child)) {
                try containedChildren.append(child);
            }
        }

        // Remove all contained children
        for (0..containedChildren.len) |i| {
            const child = containedChildren.get(i) orelse continue;
            if (child.parent_node) |parent| {
                _ = try parent.call_removeChild(child);
            }
        }

        // Spec: Delete data within this
        // If start and end are in same CharacterData node, delete the range of data
        if (self.start_container == self.end_container) {
            if (self.start_container.node_type == Node.TEXT_NODE or
                self.start_container.node_type == Node.PROCESSING_INSTRUCTION_NODE or
                self.start_container.node_type == Node.COMMENT_NODE)
            {
                // This is CharacterData - call deleteData to remove the range
                // Safe cast: we've verified node_type above
                const charData: *CharacterData = @ptrCast(@alignCast(self.start_container));
                const count = self.end_offset - self.start_offset;
                try charData.call_deleteData(self.start_offset, count);
            }
        }
    }

    /// DOM §5.6 - Range.extractContents()
    /// Moves the contents of the range into a DocumentFragment
    /// Note: Simplified implementation covering common cases
    pub fn call_extractContents(self: *Range) !*DocumentFragment {
        // Step 1: Create fragment
        const fragment = try self.allocator.create(DocumentFragment);
        fragment.* = try DocumentFragment.init(self.allocator);

        // Step 2: If collapsed, return empty fragment
        if (self.get_collapsed()) {
            return fragment;
        }

        // Step 3: Store original boundary points for resetting range
        const originalStartNode = self.start_container;
        const originalStartOffset = self.start_offset;

        // Step 4: Special case - same CharacterData node
        if (self.start_container == self.end_container and
            (self.start_container.node_type == Node.TEXT_NODE or
                self.start_container.node_type == Node.PROCESSING_INSTRUCTION_NODE or
                self.start_container.node_type == Node.COMMENT_NODE))
        {
            // Step 4.1: Let clone be a clone of original start node
            const clone = try self.start_container.call_cloneNode(false); // Shallow clone

            // Step 4.2: Set the data of clone to substring
            const originalCharData: *CharacterData = @ptrCast(@alignCast(self.start_container));
            const cloneCharData: *CharacterData = @ptrCast(@alignCast(clone));

            // Substring from original start offset to original end offset
            const count = self.end_offset - self.start_offset;
            const originalData = originalCharData.get_data();
            if (self.start_offset < originalData.len and self.end_offset <= originalData.len) {
                const substring = originalData[self.start_offset..self.end_offset];
                try cloneCharData.set_data(substring);
            }

            // Step 4.3: Append clone to fragment
            _ = try fragment.call_appendChild(clone);

            // Step 4.4: Replace data in original node (remove extracted text)
            try originalCharData.call_deleteData(self.start_offset, count);

            // Step 4.5: Return fragment
            return fragment;
        }

        // Steps 5-12: Find common ancestor and contained children
        const commonAncestor = self.get_commonAncestorContainer();

        // Collect contained children
        var containedChildren = infra.List(*Node).init(self.allocator);
        defer containedChildren.deinit();

        for (commonAncestor.child_nodes.items()) |child| {
            // Check if doctype
            if (child.node_type == Node.DOCUMENT_TYPE_NODE) {
                return error.HierarchyRequestError;
            }
            // Collect contained children
            if (self.isNodeContained(child)) {
                try containedChildren.append(child);
            }
        }

        // Step 17: Move contained children to fragment
        for (0..containedChildren.len) |i| {
            const child = containedChildren.get(i) orelse continue;
            if (child.parent_node) |parent| {
                _ = try parent.call_removeChild(child);
            }
            _ = try fragment.call_appendChild(child);
        }

        // Step 20: Set range to collapsed at new position
        self.end_container = originalStartNode;
        self.end_offset = originalStartOffset;

        // Step 21: Return fragment
        return fragment;
    }

    /// DOM §5.6 - Range.cloneContents()
    /// Returns a DocumentFragment that is a copy of the contents
    /// Note: Simplified implementation covering common cases
    pub fn call_cloneContents(self: *Range) !*DocumentFragment {
        // Step 1: Create fragment
        const fragment = try self.allocator.create(DocumentFragment);
        fragment.* = try DocumentFragment.init(self.allocator);

        // Step 2: If collapsed, return empty fragment
        if (self.get_collapsed()) {
            return fragment;
        }

        // Step 4: Special case - same CharacterData node
        if (self.start_container == self.end_container and
            (self.start_container.node_type == Node.TEXT_NODE or
                self.start_container.node_type == Node.PROCESSING_INSTRUCTION_NODE or
                self.start_container.node_type == Node.COMMENT_NODE))
        {
            // Step 4.1: Let clone be a clone of start node
            const clone = try self.start_container.call_cloneNode(false); // Shallow clone

            // Step 4.2: Set the data of clone to substring
            const originalCharData: *CharacterData = @ptrCast(@alignCast(self.start_container));
            const cloneCharData: *CharacterData = @ptrCast(@alignCast(clone));

            // Substring from start offset to end offset
            const originalData = originalCharData.get_data();
            if (self.start_offset < originalData.len and self.end_offset <= originalData.len) {
                const substring = originalData[self.start_offset..self.end_offset];
                try cloneCharData.set_data(substring);
            }

            // Step 4.3: Append clone to fragment
            _ = try fragment.call_appendChild(clone);

            // Step 4.4: Return fragment (note: cloneContents doesn't modify original)
            return fragment;
        }

        // Steps 5-12: Find common ancestor and contained children
        const commonAncestor = self.get_commonAncestorContainer();

        // Collect contained children
        var containedChildren = infra.List(*Node).init(self.allocator);
        defer containedChildren.deinit();

        for (commonAncestor.child_nodes.items()) |child| {
            // Check if doctype
            if (child.node_type == Node.DOCUMENT_TYPE_NODE) {
                return error.HierarchyRequestError;
            }
            // Collect contained children
            if (self.isNodeContained(child)) {
                try containedChildren.append(child);
            }
        }

        // Step 15: Clone contained children (with children flag set)
        for (0..containedChildren.len) |i| {
            const child = containedChildren.get(i) orelse continue;
            const clone = try child.call_cloneNode(true); // Deep clone
            _ = try fragment.call_appendChild(clone);
        }

        // Step 18: Return fragment
        return fragment;
    }

    /// DOM §5.4 - Range.insertNode(node)
    /// Inserts node into the range's context tree
    pub fn call_insertNode(self: *Range, node: *Node) !void {
        // Step 1: Validate start node
        if (self.start_container.node_type == Node.PROCESSING_INSTRUCTION_NODE or
            self.start_container.node_type == Node.COMMENT_NODE or
            (self.start_container.node_type == Node.TEXT_NODE and self.start_container.parent_node == null) or
            self.start_container == node)
        {
            return error.HierarchyRequestError;
        }

        // Step 2-4: Determine reference node
        var referenceNode: ?*Node = null;
        if (self.start_container.node_type == Node.TEXT_NODE) {
            // Step 3: Start node is Text node
            referenceNode = self.start_container;
        } else {
            // Step 4: Get child at start offset
            const items = self.start_container.child_nodes.items();
            if (self.start_offset < items.len) {
                referenceNode = items[@intCast(self.start_offset)];
            }
        }

        // Step 5: Determine parent
        const parent = if (referenceNode != null)
            referenceNode.?.parent_node orelse self.start_container
        else
            self.start_container;

        // Step 6: Ensure pre-insertion validity
        const mutation = @import("dom").mutation;
        try mutation.ensurePreInsertValidity(node, parent, referenceNode);

        // Step 7: If start node is Text, split it
        if (self.start_container.node_type == Node.TEXT_NODE) {
            const textNode = self.start_container.as(Text) orelse return error.InvalidNodeTypeError;
            const newText = try textNode.call_splitText(self.start_offset);
            referenceNode = @ptrCast(newText);
        }

        // Step 8: If node is referenceNode, use its next sibling
        if (referenceNode != null and node == referenceNode.?) {
            const dom = @import("dom");
            referenceNode = dom.tree_helpers.getNextSibling(referenceNode.?);
        }

        // Step 9: If node has parent, remove it
        if (node.parent_node) |oldParent| {
            _ = try oldParent.call_removeChild(node);
        }

        // Step 10-11: Calculate new offset
        var newOffset: u32 = 0;
        if (referenceNode) |refNode| {
            const dom = @import("dom");
            newOffset = @intCast(dom.tree_helpers.getChildIndex(parent, refNode) orelse 0);
        } else {
            newOffset = @intCast(parent.child_nodes.size());
        }

        // Increase newOffset by node's length
        if (node.node_type == Node.DOCUMENT_FRAGMENT_NODE) {
            newOffset += @intCast(node.child_nodes.size());
        } else {
            newOffset += 1;
        }

        // Step 12: Pre-insert node
        _ = try parent.call_insertBefore(node, referenceNode);

        // Step 13: If range is collapsed, update end
        if (self.get_collapsed()) {
            self.end_container = parent;
            self.end_offset = newOffset;
        }
    }

    /// DOM §5.4 - Range.surroundContents(newParent)
    /// Moves the contents of the range into newParent, then inserts newParent at range's start
    pub fn call_surroundContents(self: *Range, newParent: *Node) !void {
        // Step 1: Check for partially contained non-Text nodes
        const commonAncestor = self.get_commonAncestorContainer();
        for (commonAncestor.child_nodes.items()) |child| {
            if (self.isNodePartiallyContained(child)) {
                if (child.node_type != Node.TEXT_NODE) {
                    return error.InvalidStateError;
                }
            }
        }

        // Step 2: Validate newParent type
        if (newParent.node_type == Node.DOCUMENT_NODE or
            newParent.node_type == Node.DOCUMENT_TYPE_NODE or
            newParent.node_type == Node.DOCUMENT_FRAGMENT_NODE)
        {
            return error.InvalidNodeTypeError;
        }

        // Step 3: Extract range contents into a fragment
        const fragment = try self.call_extractContents();
        defer {
            fragment.deinit();
            self.allocator.destroy(fragment);
        }

        // Step 4: If newParent has children, replace all with null
        while (newParent.child_nodes.size() > 0) {
            const items = newParent.child_nodes.items();
            if (items.len > 0) {
                _ = try newParent.call_removeChild(items[0]);
            }
        }

        // Step 5: Insert newParent into range
        try self.call_insertNode(newParent);

        // Step 6: Append fragment to newParent
        _ = try newParent.call_appendChild(@ptrCast(&fragment));

        // Step 7: Select newParent within range
        try self.call_selectNode(newParent);
    }

    /// DOM §5 - Range.cloneRange()
    pub fn call_cloneRange(self: *Range) !*Range {
        const range = try self.allocator.create(Range);
        range.* = try Range.init(self.allocator, self.start_container);
        range.start_container = self.start_container;
        range.start_offset = self.start_offset;
        range.end_container = self.end_container;
        range.end_offset = self.end_offset;

        // Register the cloned range with the document
        try range.registerWithDocument();

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
        const nodeRoot = dom.tree.root(node);
        const thisRoot = dom.tree.root(self.start_container);
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
        const nodeRoot = dom.tree.root(node);
        const thisRoot = dom.tree.root(self.start_container);
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
        const nodeRoot = dom.tree.root(node);
        const thisRoot = dom.tree.root(self.start_container);
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
    /// Returns the text content of the range per spec §5.7
    pub fn toString(self: *Range, allocator: Allocator) ![]const u8 {
        var result = infra.List(u8).init(allocator);
        errdefer result.deinit();

        // Step 2: If start node == end node and it's a Text node
        if (self.start_container == self.end_container and
            self.start_container.node_type == Node.TEXT_NODE)
        {
            const textNode = self.start_container.as(Text) orelse return error.InvalidNodeTypeError;
            const data = textNode.get_data();

            // Return substring from start offset to end offset
            if (self.end_offset >= self.start_offset and self.end_offset <= data.len) {
                const substring = data[self.start_offset..self.end_offset];
                try result.appendSlice(substring);
                return result.toOwnedSlice();
            }
        }

        // Step 3: If start node is a Text node, append from start offset to end
        if (self.start_container.node_type == Node.TEXT_NODE) {
            const textNode = self.start_container.as(Text) orelse return error.InvalidNodeTypeError;
            const data = textNode.get_data();
            if (self.start_offset <= data.len) {
                const substring = data[self.start_offset..];
                try result.appendSlice(substring);
            }
        }

        // Step 4: Append concatenation of all contained Text nodes in tree order
        const commonAncestor = self.get_commonAncestorContainer();
        try self.appendContainedTextNodes(commonAncestor, &result);

        // Step 5: If end node is a Text node, append from start to end offset
        if (self.end_container.node_type == Node.TEXT_NODE and
            self.end_container != self.start_container)
        {
            const textNode = self.end_container.as(Text) orelse return error.InvalidNodeTypeError;
            const data = textNode.get_data();
            if (self.end_offset <= data.len) {
                const substring = data[0..self.end_offset];
                try result.appendSlice(substring);
            }
        }

        // Step 6: Return s
        return result.toOwnedSlice();
    }

    /// Helper for toString: Recursively append contained Text node data
    fn appendContainedTextNodes(self: *const Range, node: *Node, result: *infra.List(u8)) !void {
        // If this node is contained and is a Text node, append its data
        if (self.isNodeContained(node) and node.node_type == Node.TEXT_NODE) {
            const textNode = node.as(Text) orelse return error.InvalidNodeTypeError;
            const data = textNode.get_data();
            try result.appendSlice(data);
            return;
        }

        // Recursively process children in tree order
        for (node.child_nodes.items()) |child| {
            try self.appendContainedTextNodes(child, result);
        }
    }
}, .{
    .exposed = &.{.Window},
});
