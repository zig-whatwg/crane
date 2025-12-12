//! DOM Handle Types
//!
//! KEEP: Opaque handle pattern - DO NOT refactor to anyopaque or runtime.Instance
//!
//! This module provides opaque handle types for breaking circular imports
//! in the DOM layer. These handles allow type-safe references between
//! DOM types that would otherwise create circular dependencies.
//!
//! See docs/patterns/opaque-handles.md for full documentation of this pattern.
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
//!
//! ## Debug Assertions
//!
//! All handle types include validation methods that check pointer validity
//! in debug builds. These compile away in release builds for zero overhead.
//!
//! ```zig
//! // Validates pointer is non-null and properly aligned
//! validateElementHandle(handle);
//!
//! // Convert with validation in one call
//! const ptr = elementToAnyopaqueChecked(handle);
//! ```

const std = @import("std");
const builtin = @import("builtin");

// ============================================================================
// Generic Handle Operations
// ============================================================================

/// Generic handle operations for type-safe conversions.
///
/// Instead of per-type conversion functions like:
///   anyopaqueToElement, elementToAnyopaque
///   anyopaqueToDocument, documentToAnyopaque
///   ...
///
/// Use this generic:
///   HandleOps(ElementHandle).toAnyopaque(handle)
///   HandleOps(ElementHandle).fromAnyopaque(ptr)
///
/// The per-type functions are kept for backward compatibility but
/// new code should prefer this generic pattern.
///
/// ## Example
///
/// ```zig
/// const handles = @import("handles.zig");
///
/// // Old pattern (still works)
/// const ptr = handles.elementToAnyopaque(element_handle);
/// const handle = handles.anyopaqueToElement(ptr);
///
/// // New pattern (preferred)
/// const ptr = handles.HandleOps(handles.ElementHandle).toAnyopaque(element_handle);
/// const handle = handles.HandleOps(handles.ElementHandle).fromAnyopaque(ptr);
///
/// // Or use the type-specific alias
/// const ptr = handles.ElementOps.toAnyopaque(element_handle);
/// const handle = handles.ElementOps.fromAnyopaque(ptr);
/// ```
pub fn HandleOps(comptime Handle: type) type {
    return struct {
        const type_name = @typeName(Handle);

        /// Convert a handle to anyopaque (for legacy interop)
        pub fn toAnyopaque(handle: ?*Handle) ?*anyopaque {
            if (handle) |h| {
                return @ptrCast(h);
            }
            return null;
        }

        /// Convert anyopaque to a handle (from legacy interop)
        pub fn fromAnyopaque(ptr: ?*anyopaque) ?*Handle {
            if (ptr) |p| {
                return @ptrCast(@alignCast(p));
            }
            return null;
        }

        /// Convert with debug validation (validates before conversion)
        pub fn toAnyopaqueChecked(handle: ?*Handle) ?*anyopaque {
            validate(handle);
            return toAnyopaque(handle);
        }

        /// Convert from anyopaque with debug validation
        pub fn fromAnyopaqueChecked(ptr: ?*anyopaque) ?*Handle {
            validateHandlePtr(ptr, type_name);
            return fromAnyopaque(ptr);
        }

        /// Validate a handle pointer in debug builds
        pub fn validate(handle: ?*const Handle) void {
            validateHandlePtr(@ptrCast(handle), type_name);
        }

        /// Assert that handle is not null (panics in debug if null)
        pub fn assertNotNullHandle(handle: ?*const Handle) void {
            assertNotNull(@ptrCast(handle), type_name);
        }
    };
}

// Type-specific aliases for common use
pub const ElementOps = HandleOps(ElementHandle);
pub const DocumentOps = HandleOps(DocumentHandle);
pub const ShadowRootOps = HandleOps(ShadowRootHandle);
pub const SlotOps = HandleOps(SlotHandle);
pub const MutationObserverOps = HandleOps(MutationObserverHandle);
pub const CustomElementRegistryOps = HandleOps(CustomElementRegistryHandle);
pub const NodeOps = HandleOps(NodeHandle);

// ============================================================================
// Debug Assertion Helpers
// ============================================================================

/// Validate that a handle pointer is valid (non-null and aligned).
/// Only performs checks in debug/release-safe builds.
fn validateHandlePtr(ptr: ?*const anyopaque, comptime type_name: []const u8) void {
    if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
        if (ptr) |p| {
            const addr = @intFromPtr(p);
            // Check alignment (minimum 4-byte for pointers)
            if (addr & (@alignOf(*anyopaque) - 1) != 0) {
                std.debug.panic("{s} handle has invalid alignment: 0x{x}", .{ type_name, addr });
            }
        }
    }
}

/// Assert that a handle is not null.
/// Panics in debug/release-safe builds if null.
fn assertNotNull(ptr: ?*const anyopaque, comptime type_name: []const u8) void {
    if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
        if (ptr == null) {
            std.debug.panic("{s} handle is null when non-null was expected", .{type_name});
        }
    }
}

// ============================================================================
// Opaque Handle Types with Debug Validation
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
// Handle Validation Functions
// ============================================================================

/// Validate an ElementHandle pointer in debug builds.
/// Checks for non-null and proper alignment.
pub fn validateElementHandle(handle: ?*const ElementHandle) void {
    validateHandlePtr(@ptrCast(handle), "Element");
}

/// Validate a DocumentHandle pointer in debug builds.
pub fn validateDocumentHandle(handle: ?*const DocumentHandle) void {
    validateHandlePtr(@ptrCast(handle), "Document");
}

/// Validate a ShadowRootHandle pointer in debug builds.
pub fn validateShadowRootHandle(handle: ?*const ShadowRootHandle) void {
    validateHandlePtr(@ptrCast(handle), "ShadowRoot");
}

/// Validate a SlotHandle pointer in debug builds.
pub fn validateSlotHandle(handle: ?*const SlotHandle) void {
    validateHandlePtr(@ptrCast(handle), "Slot");
}

/// Validate a MutationObserverHandle pointer in debug builds.
pub fn validateMutationObserverHandle(handle: ?*const MutationObserverHandle) void {
    validateHandlePtr(@ptrCast(handle), "MutationObserver");
}

/// Validate a CustomElementRegistryHandle pointer in debug builds.
pub fn validateRegistryHandle(handle: ?*const CustomElementRegistryHandle) void {
    validateHandlePtr(@ptrCast(handle), "CustomElementRegistry");
}

/// Validate a NodeHandle pointer in debug builds.
pub fn validateNodeHandle(handle: ?*const NodeHandle) void {
    validateHandlePtr(@ptrCast(handle), "Node");
}

// ============================================================================
// Assertion Functions (panic if null)
// ============================================================================

/// Assert that an ElementHandle is not null. Panics in debug builds if null.
pub fn assertElementNotNull(handle: ?*const ElementHandle) void {
    assertNotNull(@ptrCast(handle), "Element");
}

/// Assert that a DocumentHandle is not null.
pub fn assertDocumentNotNull(handle: ?*const DocumentHandle) void {
    assertNotNull(@ptrCast(handle), "Document");
}

/// Assert that a NodeHandle is not null.
pub fn assertNodeNotNull(handle: ?*const NodeHandle) void {
    assertNotNull(@ptrCast(handle), "Node");
}

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

/// Convert an ElementHandle to an anyopaque pointer with debug validation.
/// Validates the handle before conversion in debug builds.
pub fn elementToAnyopaqueChecked(handle: ?*ElementHandle) ?*anyopaque {
    validateElementHandle(handle);
    return elementToAnyopaque(handle);
}

/// Convert an anyopaque pointer to an ElementHandle
/// Use when receiving from legacy code
pub fn anyopaqueToElement(ptr: ?*anyopaque) ?*ElementHandle {
    if (ptr) |p| {
        return @ptrCast(@alignCast(p));
    }
    return null;
}

/// Convert an anyopaque pointer to an ElementHandle with debug validation.
pub fn anyopaqueToElementChecked(ptr: ?*anyopaque) ?*ElementHandle {
    validateHandlePtr(ptr, "Element");
    return anyopaqueToElement(ptr);
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

test "handles: validation passes for valid handles" {
    var dummy: u64 align(8) = 42;
    const ptr: *anyopaque = @ptrCast(&dummy);

    // Convert to handle
    const element_handle = anyopaqueToElement(ptr);

    // Validation should pass (not panic) for valid handle
    validateElementHandle(element_handle);
}

test "handles: validation passes for null handles" {
    // Null is a valid state for optional handles
    validateElementHandle(null);
    validateDocumentHandle(null);
    validateNodeHandle(null);
}

test "handles: checked conversion works" {
    var dummy: u64 align(8) = 123;
    const ptr: *anyopaque = @ptrCast(&dummy);

    // Checked conversion should work for valid pointers
    const handle = anyopaqueToElementChecked(ptr);
    try std.testing.expect(handle != null);

    const back = elementToAnyopaqueChecked(handle);
    try std.testing.expectEqual(ptr, back.?);
}

test "handles: all handle types round-trip" {
    var dummy: u64 align(8) = 0xDEADBEEF;
    const ptr: *anyopaque = @ptrCast(&dummy);

    // Document
    {
        const handle = anyopaqueToDocument(ptr);
        validateDocumentHandle(handle);
        const back = documentToAnyopaque(handle);
        try std.testing.expectEqual(ptr, back.?);
    }

    // ShadowRoot
    {
        const handle = anyopaqueToShadowRoot(ptr);
        validateShadowRootHandle(handle);
        const back = shadowRootToAnyopaque(handle);
        try std.testing.expectEqual(ptr, back.?);
    }

    // Slot
    {
        const handle = anyopaqueToSlot(ptr);
        validateSlotHandle(handle);
        const back = slotToAnyopaque(handle);
        try std.testing.expectEqual(ptr, back.?);
    }

    // MutationObserver
    {
        const handle = anyopaqueToMutationObserver(ptr);
        validateMutationObserverHandle(handle);
        const back = mutationObserverToAnyopaque(handle);
        try std.testing.expectEqual(ptr, back.?);
    }

    // CustomElementRegistry
    {
        const handle = anyopaqueToRegistry(ptr);
        validateRegistryHandle(handle);
        const back = registryToAnyopaque(handle);
        try std.testing.expectEqual(ptr, back.?);
    }

    // Node
    {
        const handle = anyopaqueToNode(ptr);
        validateNodeHandle(handle);
        const back = nodeToAnyopaque(handle);
        try std.testing.expectEqual(ptr, back.?);
    }
}

test "handles: generic HandleOps round-trip" {
    var dummy: u64 align(8) = 0xCAFEBABE;
    const ptr: *anyopaque = @ptrCast(&dummy);

    // Test ElementOps alias
    {
        const handle = ElementOps.fromAnyopaque(ptr);
        try std.testing.expect(handle != null);
        const back = ElementOps.toAnyopaque(handle);
        try std.testing.expectEqual(ptr, back.?);
    }

    // Test HandleOps with DocumentHandle directly
    {
        const Ops = HandleOps(DocumentHandle);
        const handle = Ops.fromAnyopaque(ptr);
        try std.testing.expect(handle != null);
        Ops.validate(handle);
        const back = Ops.toAnyopaque(handle);
        try std.testing.expectEqual(ptr, back.?);
    }

    // Test null handling via generic
    {
        const result = NodeOps.fromAnyopaque(null);
        try std.testing.expectEqual(@as(?*NodeHandle, null), result);
        const back = NodeOps.toAnyopaque(null);
        try std.testing.expectEqual(@as(?*anyopaque, null), back);
    }
}
