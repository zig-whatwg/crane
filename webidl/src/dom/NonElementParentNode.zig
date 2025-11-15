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
    pub fn call_getElementById(self: anytype, allocator: std.mem.Allocator, element_id: []const u8) !?*Element {
        _ = allocator; // Not needed for traversal

        // Node type will be available from module-level import in generated code
        const NodeType = @import("node").Node;

        // Inline recursive search to avoid private function copying issues with codegen
        const SearchHelper = struct {
            fn findById(nodes: anytype, target_id: []const u8) ?*Element {
                for (nodes) |node| {
                    // Check if this node is an element with matching ID
                    if (node.node_type == NodeType.ELEMENT_NODE) {
                        // Cast to Element to access ID
                        const element: *Element = @ptrCast(node);

                        // Check if id attribute matches
                        // Per spec: element's ID is the value of its "id" attribute
                        const attributes = element.get_attributes();
                        if (attributes.call_getNamedItem("id")) |id_attr| {
                            if (std.mem.eql(u8, id_attr.value, target_id)) {
                                return element;
                            }
                        }
                    }

                    // Recursively search descendants
                    if (findById(node.child_nodes.items(), target_id)) |found| {
                        return found;
                    }
                }

                return null;
            }
        };

        // Traverse descendants in tree order (preorder depth-first)
        return SearchHelper.findById(self.child_nodes.items(), element_id);
    }
});
