// DOM Standard: Common DOM types and unions
// https://dom.spec.whatwg.org/

const std = @import("std");

// Forward declarations - will be resolved at runtime
const Node = @import("Node.zig").Node;

/// WebIDL Union: (Node or DOMString)
/// Used by ChildNode and ParentNode mixin methods.
///
/// This union represents a value that can be either:
/// - A Node reference (for inserting existing nodes)
/// - A DOMString (automatically converted to Text nodes)
pub const NodeOrDOMString = union(enum) {
    node: *Node,
    string: []const u8,
};

/// WebIDL Dictionary: GetRootNodeOptions
/// Used by Node.getRootNode()
pub const GetRootNodeOptions = struct {
    composed: bool = false,
};

test "NodeOrDOMString compiles" {
    const T = @TypeOf(NodeOrDOMString);
    try std.testing.expect(T != void);
}
