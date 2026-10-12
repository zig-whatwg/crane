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
    var sibling = interfaces.Node.get_previousSibling(instance) catch null;
    while (sibling) |s| {
        const node_type = interfaces.Node.get_nodeType(s) catch 0;
        if (node_type == interfaces.Node.get_ELEMENT_NODE()) {
            return s;
        }
        sibling = interfaces.Node.get_previousSibling(s) catch null;
    }
    return null;
}

/// nextElementSibling - Returns the next sibling that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-nondocumenttypechildnode-nextelementsibling
///
/// Returns the first following sibling that is an element, or null if none exists.
pub fn get_nextElementSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    var sibling = interfaces.Node.get_nextSibling(instance) catch null;
    while (sibling) |s| {
        const node_type = interfaces.Node.get_nodeType(s) catch 0;
        if (node_type == interfaces.Node.get_ELEMENT_NODE()) {
            return s;
        }
        sibling = interfaces.Node.get_nextSibling(s) catch null;
    }
    return null;
}
