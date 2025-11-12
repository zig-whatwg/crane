// DOM Standard: Interface Mixin NonDocumentTypeChildNode (§4.3.3)
// https://dom.spec.whatwg.org/#interface-nondocumenttypechildnode

const std = @import("std");
const webidl = @import("../../root.zig");

// Forward declaration
const Element = @import("element").Element;

/// NonDocumentTypeChildNode mixin provides element sibling navigation.
/// Included by: Element, CharacterData
///
/// Web compatibility prevents these attributes from being exposed on DocumentType.
///
/// WebIDL Definition:
/// ```
/// interface mixin NonDocumentTypeChildNode {
///   readonly attribute Element? previousElementSibling;
///   readonly attribute Element? nextElementSibling;
/// };
/// ```
pub const NonDocumentTypeChildNode = webidl.mixin(struct {
    // NOTE: This is a mixin - no fields, only attributes to be included in other interfaces

    /// DOM §4.3.3 - NonDocumentTypeChildNode.previousElementSibling
    /// Returns the first preceding sibling that is an element; otherwise null.
    ///
    /// The previousElementSibling getter steps are to return the first preceding
    /// sibling that is an element; otherwise null.
    pub fn previousElementSibling(self: anytype) ?*Element {
        const Node = @import("node").Node;
        const parent = self.parent_node orelse return null;

        // Find our index in parent's children
        var found_self = false;
        var i: usize = parent.child_nodes.items.len;
        while (i > 0) {
            i -= 1;
            const sibling = parent.child_nodes.items[i];

            if (sibling == @as(*Node, @ptrCast(self))) {
                found_self = true;
                continue;
            }

            // Only look at siblings before us
            if (found_self and sibling.node_type == Node.ELEMENT_NODE) {
                return @ptrCast(sibling);
            }
        }

        return null;
    }

    /// DOM §4.3.3 - NonDocumentTypeChildNode.nextElementSibling
    /// Returns the first following sibling that is an element; otherwise null.
    ///
    /// The nextElementSibling getter steps are to return the first following
    /// sibling that is an element; otherwise null.
    pub fn nextElementSibling(self: anytype) ?*Element {
        const Node = @import("node").Node;
        const parent = self.parent_node orelse return null;

        // Find our index in parent's children
        var found_self = false;
        for (parent.child_nodes.items) |sibling| {
            if (sibling == @as(*Node, @ptrCast(self))) {
                found_self = true;
                continue;
            }

            // Only look at siblings after us
            if (found_self and sibling.node_type == Node.ELEMENT_NODE) {
                return @ptrCast(sibling);
            }
        }

        return null;
    }
});

test "NonDocumentTypeChildNode mixin compiles" {
    // Just verify the mixin structure compiles
    const T = @TypeOf(NonDocumentTypeChildNode);
    try std.testing.expect(T != void);
}
