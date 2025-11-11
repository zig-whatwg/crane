// DOM Standard: Interface Mixin NonDocumentTypeChildNode (§4.3.3)
// https://dom.spec.whatwg.org/#interface-nondocumenttypechildnode

const std = @import("std");
const webidl = @import("../../root.zig");

// Forward declaration
const Element = @import("Element.zig").Element;

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
        _ = self;
        // TODO: Implement DOM §4.3.3 previousElementSibling getter
        // 1. Get this node's previous sibling
        // 2. While sibling exists:
        //    - If sibling is an Element, return it
        //    - Move to previous sibling
        // 3. Return null if no element sibling found
        @panic("NonDocumentTypeChildNode.previousElementSibling() not yet implemented");
    }

    /// DOM §4.3.3 - NonDocumentTypeChildNode.nextElementSibling
    /// Returns the first following sibling that is an element; otherwise null.
    ///
    /// The nextElementSibling getter steps are to return the first following
    /// sibling that is an element; otherwise null.
    pub fn nextElementSibling(self: anytype) ?*Element {
        _ = self;
        // TODO: Implement DOM §4.3.3 nextElementSibling getter
        // 1. Get this node's next sibling
        // 2. While sibling exists:
        //    - If sibling is an Element, return it
        //    - Move to next sibling
        // 3. Return null if no element sibling found
        @panic("NonDocumentTypeChildNode.nextElementSibling() not yet implemented");
    }
});

test "NonDocumentTypeChildNode mixin compiles" {
    // Just verify the mixin structure compiles
    const T = @TypeOf(NonDocumentTypeChildNode);
    try std.testing.expect(T != void);
}
