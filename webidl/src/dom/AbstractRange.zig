//! AbstractRange interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-abstractrange
//!
//! AbstractRange is a base interface for Range and StaticRange.
//! It provides readonly access to boundary points.

const std = @import("std");
const webidl = @import("webidl");
const Node = @import("node").Node;

/// DOM §5 - interface AbstractRange
///
/// Objects implementing AbstractRange are known as ranges.
/// A range has two associated boundary points - a start and end.
pub const AbstractRange = webidl.interface(struct {
    /// Start boundary point - node
    start_container: *Node,

    /// Start boundary point - offset
    start_offset: u32,

    /// End boundary point - node
    end_container: *Node,

    /// End boundary point - offset
    end_offset: u32,

    /// DOM §5 - AbstractRange.startContainer
    /// Returns the node at the start of the range
    pub fn get_startContainer(self: *const AbstractRange) *Node {
        return self.start_container;
    }

    /// DOM §5 - AbstractRange.startOffset
    /// Returns the offset within the start node
    pub fn get_startOffset(self: *const AbstractRange) u32 {
        return self.start_offset;
    }

    /// DOM §5 - AbstractRange.endContainer
    /// Returns the node at the end of the range
    pub fn get_endContainer(self: *const AbstractRange) *Node {
        return self.end_container;
    }

    /// DOM §5 - AbstractRange.endOffset
    /// Returns the offset within the end node
    pub fn get_endOffset(self: *const AbstractRange) u32 {
        return self.end_offset;
    }

    /// DOM §5 - AbstractRange.collapsed
    /// Returns true if the range's start and end are the same position
    pub fn get_collapsed(self: *const AbstractRange) bool {
        return self.start_container == self.end_container and
            self.start_offset == self.end_offset;
    }
}, .{
    .exposed = &.{.Window},
});
