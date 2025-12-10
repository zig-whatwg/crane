//! DOM Handle Types
//!
//! This module provides opaque handle types for breaking circular imports
//! in the DOM layer. These handles allow type-safe references between
//! DOM types that would otherwise create circular dependencies.
//!
//! ## Problem Solved
//!
//! DOM types often reference each other:
//! - Element references Document (owner document)
//! - Attr references Element (owner element)
//! - ShadowRoot references Element (host)
//! - MutationObserver is referenced by RegisteredObserver
//!
//! Without opaque handles, importing these types creates circular imports.
//!
//! ## Usage
//!
//! Instead of:
//! ```zig
//! const Element = @import("Element.zig"); // Circular import!
//! owner_element: ?*Element,
//! ```
//!
//! Use:
//! ```zig
//! const handles = @import("handles.zig");
//! owner_element: ?*handles.ElementHandle,
//!
//! // Convert when you have the concrete type
//! const element = handles.elementFromHandle(self.owner_element);
//! ```

const std = @import("std");

// ============================================================================
// Opaque Handle Types
// ============================================================================

/// Opaque handle for Element references
/// Use when you need to reference an Element without importing the full type
pub const ElementHandle = opaque {};

/// Opaque handle for Document references
pub const DocumentHandle = opaque {};

/// Opaque handle for ShadowRoot references
pub const ShadowRootHandle = opaque {};

/// Opaque handle for HTMLSlotElement references
pub const SlotHandle = opaque {};

/// Opaque handle for MutationObserver references
pub const MutationObserverHandle = opaque {};

/// Opaque handle for CustomElementRegistry references
pub const CustomElementRegistryHandle = opaque {};

/// Opaque handle for Node references (base type)
pub const NodeHandle = opaque {};

// ============================================================================
// Conversion Functions - Element
// ============================================================================

/// Convert an ElementHandle to an anyopaque pointer
/// Use for interop with legacy code that expects *anyopaque
pub fn elementToAnyopaque(handle: ?*ElementHandle) ?*anyopaque {
    if (handle) |h| {
        return @ptrCast(h);
    }
    return null;
}

/// Convert an anyopaque pointer to an ElementHandle
/// Use when receiving from legacy code
pub fn anyopaqueToElement(ptr: ?*anyopaque) ?*ElementHandle {
    if (ptr) |p| {
        return @ptrCast(@alignCast(p));
    }
    return null;
}

// ============================================================================
// Conversion Functions - Document
// ============================================================================

/// Convert a DocumentHandle to an anyopaque pointer
pub fn documentToAnyopaque(handle: ?*DocumentHandle) ?*anyopaque {
    if (handle) |h| {
        return @ptrCast(h);
    }
    return null;
}

/// Convert an anyopaque pointer to a DocumentHandle
pub fn anyopaqueToDocument(ptr: ?*anyopaque) ?*DocumentHandle {
    if (ptr) |p| {
        return @ptrCast(@alignCast(p));
    }
    return null;
}

// ============================================================================
// Conversion Functions - ShadowRoot
// ============================================================================

/// Convert a ShadowRootHandle to an anyopaque pointer
pub fn shadowRootToAnyopaque(handle: ?*ShadowRootHandle) ?*anyopaque {
    if (handle) |h| {
        return @ptrCast(h);
    }
    return null;
}

/// Convert an anyopaque pointer to a ShadowRootHandle
pub fn anyopaqueToShadowRoot(ptr: ?*anyopaque) ?*ShadowRootHandle {
    if (ptr) |p| {
        return @ptrCast(@alignCast(p));
    }
    return null;
}

// ============================================================================
// Conversion Functions - Slot
// ============================================================================

/// Convert a SlotHandle to an anyopaque pointer
pub fn slotToAnyopaque(handle: ?*SlotHandle) ?*anyopaque {
    if (handle) |h| {
        return @ptrCast(h);
    }
    return null;
}

/// Convert an anyopaque pointer to a SlotHandle
pub fn anyopaqueToSlot(ptr: ?*anyopaque) ?*SlotHandle {
    if (ptr) |p| {
        return @ptrCast(@alignCast(p));
    }
    return null;
}

// ============================================================================
// Conversion Functions - MutationObserver
// ============================================================================

/// Convert a MutationObserverHandle to an anyopaque pointer
pub fn mutationObserverToAnyopaque(handle: ?*MutationObserverHandle) ?*anyopaque {
    if (handle) |h| {
        return @ptrCast(h);
    }
    return null;
}

/// Convert an anyopaque pointer to a MutationObserverHandle
pub fn anyopaqueToMutationObserver(ptr: ?*anyopaque) ?*MutationObserverHandle {
    if (ptr) |p| {
        return @ptrCast(@alignCast(p));
    }
    return null;
}

// ============================================================================
// Conversion Functions - CustomElementRegistry
// ============================================================================

/// Convert a CustomElementRegistryHandle to an anyopaque pointer
pub fn registryToAnyopaque(handle: ?*CustomElementRegistryHandle) ?*anyopaque {
    if (handle) |h| {
        return @ptrCast(h);
    }
    return null;
}

/// Convert an anyopaque pointer to a CustomElementRegistryHandle
pub fn anyopaqueToRegistry(ptr: ?*anyopaque) ?*CustomElementRegistryHandle {
    if (ptr) |p| {
        return @ptrCast(@alignCast(p));
    }
    return null;
}

// ============================================================================
// Conversion Functions - Node
// ============================================================================

/// Convert a NodeHandle to an anyopaque pointer
pub fn nodeToAnyopaque(handle: ?*NodeHandle) ?*anyopaque {
    if (handle) |h| {
        return @ptrCast(h);
    }
    return null;
}

/// Convert an anyopaque pointer to a NodeHandle
pub fn anyopaqueToNode(ptr: ?*anyopaque) ?*NodeHandle {
    if (ptr) |p| {
        return @ptrCast(@alignCast(p));
    }
    return null;
}

// ============================================================================
// Tests
// ============================================================================

test "handles: round-trip conversion" {
    var dummy: u8 = 42;
    const ptr: *anyopaque = &dummy;

    // Test Element round-trip
    const element_handle = anyopaqueToElement(ptr);
    try std.testing.expect(element_handle != null);
    const back = elementToAnyopaque(element_handle);
    try std.testing.expectEqual(ptr, back.?);
}

test "handles: null handling" {
    const result = anyopaqueToElement(null);
    try std.testing.expectEqual(@as(?*ElementHandle, null), result);

    const back = elementToAnyopaque(null);
    try std.testing.expectEqual(@as(?*anyopaque, null), back);
}
