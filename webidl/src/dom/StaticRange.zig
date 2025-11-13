//! StaticRange interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-staticrange
//!
//! A StaticRange is a range that does not update when the node tree mutates.

const std = @import("std");
const webidl = @import("webidl");
const AbstractRange = @import("abstract_range").AbstractRange;
const Node = @import("node").Node;

/// StaticRangeInit dictionary
pub const StaticRangeInit = struct {
    startContainer: *Node,
    startOffset: u32,
    endContainer: *Node,
    endOffset: u32,
};

/// DOM §5 - interface StaticRange : AbstractRange
///
/// A StaticRange is a range object that does not update when the node tree mutates.
/// This makes it more efficient for one-time range operations.
pub const StaticRange = webidl.interface(struct {
    pub const extends = AbstractRange;

    /// DOM §5 - new StaticRange(init) constructor
    ///
    /// Steps:
    /// 1. If init["startContainer"] or init["endContainer"] is a DocumentType or Attr node,
    ///    then throw an "InvalidNodeTypeError" DOMException.
    /// 2. Set this's start to (init["startContainer"], init["startOffset"])
    ///    and end to (init["endContainer"], init["endOffset"]).
    pub fn init(options: StaticRangeInit) !StaticRange {
        const NodeType = @import("node").Node;

        // Step 1: Check for invalid node types
        if (options.startContainer.node_type == NodeType.DOCUMENT_TYPE_NODE or
            options.startContainer.node_type == NodeType.ATTRIBUTE_NODE)
        {
            return error.InvalidNodeTypeError;
        }

        if (options.endContainer.node_type == NodeType.DOCUMENT_TYPE_NODE or
            options.endContainer.node_type == NodeType.ATTRIBUTE_NODE)
        {
            return error.InvalidNodeTypeError;
        }

        // Step 2: Set start and end boundary points
        return .{
            .start_container = options.startContainer,
            .start_offset = options.startOffset,
            .end_container = options.endContainer,
            .end_offset = options.endOffset,
        };
    }

    pub fn deinit(self: *StaticRange) void {
        _ = self;
        // No cleanup needed - we don't own the nodes
    }

    /// Check if this StaticRange is valid per the DOM spec
    ///
    /// A StaticRange is valid if all of the following are true:
    /// - Its start and end are in the same node tree.
    /// - Its start offset is between 0 and its start node's length, inclusive.
    /// - Its end offset is between 0 and its end node's length, inclusive.
    /// - Its start is before or equal to its end.
    pub fn isValid(self: *const StaticRange) bool {
        const dom = @import("dom");

        // Check if start and end are in the same node tree
        const start_root = dom.tree.getRoot(self.start_container);
        const end_root = dom.tree.getRoot(self.end_container);
        if (start_root != end_root) return false;

        // Check start offset bounds
        const start_length = dom.tree.getNodeLength(self.start_container);
        if (self.start_offset > start_length) return false;

        // Check end offset bounds
        const end_length = dom.tree.getNodeLength(self.end_container);
        if (self.end_offset > end_length) return false;

        // Check that start is before or equal to end
        const position = dom.tree.getRelativePosition(
            self.start_container,
            self.start_offset,
            self.end_container,
            self.end_offset,
        );
        if (position == .after) return false;

        return true;
    }
}, .{
    .exposed = &.{.Window},
});
