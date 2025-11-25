//! NonElementParentNode Mixin Implementation
//!
//! Spec: https://dom.spec.whatwg.org/#interface-nonelementparentnode
//!
//! This mixin provides getElementById for Document and DocumentFragment.
//!
//! The NonElementParentNode mixin defines:
//! - getElementById(elementId) - Returns the first element with matching ID

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

// Import impl modules for accessing internal state
const impls = @import("impls");
const NodeImpl = impls.Node;
const ElementImpl = impls.Element;

pub const MixinError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

// =============================================================================
// NonElementParentNode Methods
// =============================================================================

/// getElementById - Returns the first element with matching ID
/// Spec: https://dom.spec.whatwg.org/#dom-nonelementparentnode-getelementbyid
///
/// Steps:
/// 1. Return the first element, in tree order, within this's descendants,
///    that has an ID equal to elementId; otherwise null
pub fn getElementById(
    root: *runtime.Instance,
    element_id: []const u8,
) ?*runtime.Instance {
    // Empty ID never matches
    if (element_id.len == 0) {
        return null;
    }

    // Traverse tree in tree order (preorder depth-first)
    return findElementById(root, element_id);
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Recursively search for element by ID in tree order
fn findElementById(node: *runtime.Instance, target_id: []const u8) ?*runtime.Instance {
    // Check children in tree order
    var child = NodeImpl.getFirstChild(node);
    while (child) |c| {
        // Check if this child is an element with matching ID
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            // Get element's id
            if (ElementImpl.getInternal(c)) |elem_internal| {
                const elem_id = elem_internal.id.asSlice();
                if (std.mem.eql(u8, elem_id, target_id)) {
                    return c;
                }
            }
        }

        // Recursively search descendants (depth-first, tree order)
        if (findElementById(c, target_id)) |found| {
            return found;
        }

        child = NodeImpl.getNextSibling(c);
    }

    return null;
}

// =============================================================================
// Tests
// =============================================================================

test "NonElementParentNode mixin - getElementById" {
    // Test would require setting up runtime instances
    // Placeholder for now
}
