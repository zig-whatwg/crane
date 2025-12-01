//! Implementation for NonDocumentTypeChildNode mixin
//!
//! Spec: https://dom.spec.whatwg.org/#interface-nondocumenttypechildnode
//!
//! This impl contains the actual logic for NonDocumentTypeChildNode methods.
//! The mixin file delegates to these functions.
//!
//! The NonDocumentTypeChildNode mixin defines:
//! - previousElementSibling - Returns the previous sibling that is an element
//! - nextElementSibling - Returns the next sibling that is an element

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");

// Import impl modules for accessing internal state
const NodeImpl = @import("Node.zig");

pub const State = interfaces.NonDocumentTypeChildNode.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
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
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

// =============================================================================
// NonDocumentTypeChildNode Attributes
// =============================================================================

/// previousElementSibling - Returns the previous sibling that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-nondocumenttypechildnode-previouselementsibling
///
/// Returns the first preceding sibling that is an element, or null if none exists.
pub fn get_previousElementSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    var sibling = NodeImpl.getPreviousSibling(instance);
    while (sibling) |s| {
        const node_type = NodeImpl.getNodeType(s) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            return s;
        }
        sibling = NodeImpl.getPreviousSibling(s);
    }
    return null;
}

/// nextElementSibling - Returns the next sibling that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-nondocumenttypechildnode-nextelementsibling
///
/// Returns the first following sibling that is an element, or null if none exists.
pub fn get_nextElementSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    var sibling = NodeImpl.getNextSibling(instance);
    while (sibling) |s| {
        const node_type = NodeImpl.getNodeType(s) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            return s;
        }
        sibling = NodeImpl.getNextSibling(s);
    }
    return null;
}
