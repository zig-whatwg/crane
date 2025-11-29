//! Implementation for NonElementParentNode mixin
//!
//! Spec: https://dom.spec.whatwg.org/#interface-nonelementparentnode
//!
//! This impl contains the actual logic for NonElementParentNode methods.
//! The mixin file delegates to these functions.
//!
//! The NonElementParentNode mixin defines:
//! - getElementById(elementId) - Returns the first element with matching ID

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");

// Import impl modules for accessing internal state
const NodeImpl = @import("Node.zig");
const ElementImpl = @import("Element.zig");

pub const State = interfaces.NonElementParentNode.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

/// Internal state for implementation-specific data
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    runtime.Instance.deinit(instance);
}

// =============================================================================
// NonElementParentNode Methods
// =============================================================================

/// getElementById - Returns the first element with matching ID
/// Spec: https://dom.spec.whatwg.org/#dom-nonelementparentnode-getelementbyid
///
/// Steps:
/// 1. Return the first element, in tree order, within this's descendants,
///    that has an ID equal to elementId; otherwise null
pub fn call_getElementById(instance: *runtime.Instance, element_id: runtime.DOMString) anyerror!?*runtime.Instance {
    const id_slice = element_id.asSlice();

    // Empty ID never matches
    if (id_slice.len == 0) {
        return null;
    }

    // Traverse tree in tree order (preorder depth-first)
    return findElementById(instance, id_slice);
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
