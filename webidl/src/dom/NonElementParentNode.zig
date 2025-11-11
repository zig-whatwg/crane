// DOM Standard: Interface Mixin NonElementParentNode (§4.3.1)
// https://dom.spec.whatwg.org/#interface-nonelementparentnode

const std = @import("std");
const webidl = @import("../../root.zig");

// Forward declaration
const Element = @import("element").Element;

/// NonElementParentNode mixin provides getElementById for Document and DocumentFragment.
/// Included by: Document, DocumentFragment
///
/// WebIDL Definition:
/// ```
/// interface mixin NonElementParentNode {
///   Element? getElementById(DOMString elementId);
/// };
/// ```
pub const NonElementParentNode = webidl.mixin(struct {
    // NOTE: This is a mixin - no fields, only methods to be included in other interfaces

    /// DOM §4.3.1 - NonElementParentNode.getElementById()
    /// Returns the first element within this node's descendants whose ID is elementId.
    ///
    /// The getElementById(elementId) method steps are:
    /// 1. If this is not a Document or DocumentFragment, return null
    /// 2. Return the first element, in tree order, within this's descendants,
    ///    that has an ID equal to elementId; otherwise null
    ///
    /// TODO: Implement tree traversal and ID matching
    pub fn call_getElementById(self: anytype, allocator: std.mem.Allocator, element_id: []const u8) !?*Element {
        _ = self;
        _ = allocator;
        _ = element_id;
        return error.NotImplemented;
    }
});

test "NonElementParentNode mixin compiles" {
    // Just verify the mixin structure compiles
    const T = @TypeOf(NonElementParentNode);
    try std.testing.expect(T != void);
}
