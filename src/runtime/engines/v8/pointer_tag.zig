//! Pointer Tagging for Anyopaque Type Discrimination
//!
//! This module provides utilities for encoding type information in the low bits
//! of pointers. Since all allocations are at least 4-byte aligned, the low 2 bits
//! are always zero and can be used to store a type tag.
//!
//! ## Problem Solved
//!
//! After V8 type conversions, `*const anyopaque` values can be either:
//! - Global handles (for JS functions/plain objects)
//! - `*runtime.Instance` (for wrapped Zig interfaces)
//! - Local values (for primitives that don't need persistence)
//!
//! Without type information, code receiving these pointers can't safely dispatch
//! to the correct handler and may crash by treating one type as another.
//!
//! ## Solution
//!
//! Use the low 2 bits of pointers to encode the type:
//!
//! ```
//! ┌──────────────────────────────────────────────────────┐
//! │ Pointer address (62 bits)                        │Tag│
//! │ xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxx │XX │
//! └──────────────────────────────────────────────────────┘
//!                                                      ↑
//!                                              2-bit type tag
//! ```
//!
//! ## Usage
//!
//! ```zig
//! // When creating anyopaque from Global handle:
//! const tagged = tagPointer(@ptrCast(global.rawPtr()), .global_handle);
//!
//! // When creating anyopaque from runtime.Instance:
//! const tagged = tagPointer(@ptrCast(instance), .runtime_instance);
//!
//! // When consuming the tagged pointer:
//! const untagged = untagPointer(tagged_ptr);
//! switch (untagged.tag) {
//!     .global_handle => {
//!         const global_ptr: *v8.Value = @ptrCast(@alignCast(untagged.ptr));
//!         // Use as Global handle...
//!     },
//!     .runtime_instance => {
//!         const instance: *runtime.Instance = @ptrCast(@alignCast(untagged.ptr));
//!         // Use as Instance...
//!     },
//!     .local_value, .untagged => {
//!         // Handle legacy/primitive cases...
//!     },
//! }
//! ```

const std = @import("std");

/// Type tag for anyopaque pointers
///
/// Encoded in the low 2 bits of the pointer address.
pub const AnyopaqueTag = enum(u2) {
    /// Untagged pointer (legacy compatibility)
    /// Assume it's a raw V8 Local value pointer
    untagged = 0,

    /// V8 Global handle - persists beyond HandleScope
    /// Created from functions and objects that need to survive
    global_handle = 1,

    /// Zig runtime.Instance pointer
    /// Extracted from V8 objects with internal fields
    runtime_instance = 2,

    /// V8 Local value pointer (primitives, strings)
    /// Safe to use within current HandleScope
    local_value = 3,
};

/// Result of untagging a pointer
pub const UntaggedPointer = struct {
    /// The original pointer with tag bits cleared
    ptr: *anyopaque,

    /// The type tag that was encoded
    tag: AnyopaqueTag,
};

/// Tag a pointer with type information.
///
/// The low 2 bits of the pointer are set to the tag value.
/// The pointer MUST be at least 4-byte aligned (standard for all allocations).
///
/// Parameters:
///   ptr: The pointer to tag (will be cast to usize for bit manipulation)
///   tag: The type tag to encode
///
/// Returns:
///   A tagged pointer that can be cast to *const anyopaque
pub fn tagPointer(ptr: *anyopaque, tag: AnyopaqueTag) *const anyopaque {
    const addr = @intFromPtr(ptr);

    // Safety check: pointer must be aligned (low bits should be 0)
    // In debug builds, assert this. In release, we'll just overwrite the bits.
    if (std.debug.runtime_safety) {
        std.debug.assert(addr & 0x3 == 0);
    }

    const tagged_addr = addr | @intFromEnum(tag);
    return @ptrFromInt(tagged_addr);
}

/// Tag a const pointer with type information.
///
/// Same as tagPointer but accepts *const anyopaque input.
pub fn tagConstPointer(ptr: *const anyopaque, tag: AnyopaqueTag) *const anyopaque {
    const addr = @intFromPtr(ptr);

    if (std.debug.runtime_safety) {
        std.debug.assert(addr & 0x3 == 0);
    }

    const tagged_addr = addr | @intFromEnum(tag);
    return @ptrFromInt(tagged_addr);
}

/// Untag a pointer and extract type information.
///
/// Extracts the type tag from the low 2 bits and returns the
/// original pointer with those bits cleared.
///
/// Parameters:
///   tagged: A potentially tagged pointer
///
/// Returns:
///   UntaggedPointer with the original pointer and type tag
pub fn untagPointer(tagged: *const anyopaque) UntaggedPointer {
    const addr = @intFromPtr(tagged);

    // Extract tag from low 2 bits
    const tag: AnyopaqueTag = @enumFromInt(addr & 0x3);

    // Clear low 2 bits to get original pointer
    const untagged_addr = addr & ~@as(usize, 0x3);
    const ptr: *anyopaque = @ptrFromInt(untagged_addr);

    return .{
        .ptr = ptr,
        .tag = tag,
    };
}

/// Check if a pointer is tagged (has non-zero low bits)
pub fn isTagged(ptr: *const anyopaque) bool {
    const addr = @intFromPtr(ptr);
    return (addr & 0x3) != 0;
}

/// Get the tag from a pointer without clearing the bits
pub fn getTag(ptr: *const anyopaque) AnyopaqueTag {
    const addr = @intFromPtr(ptr);
    return @enumFromInt(addr & 0x3);
}

// ============================================================================
// Tests
// ============================================================================

test "tagPointer and untagPointer roundtrip" {
    // Create a properly aligned pointer for testing
    var dummy_value: u64 align(8) = 0x12345678;
    const original_ptr: *anyopaque = @ptrCast(&dummy_value);

    // Test global_handle tag
    {
        const tagged = tagPointer(original_ptr, .global_handle);
        const untagged = untagPointer(tagged);

        try std.testing.expectEqual(AnyopaqueTag.global_handle, untagged.tag);
        try std.testing.expectEqual(original_ptr, untagged.ptr);
    }

    // Test runtime_instance tag
    {
        const tagged = tagPointer(original_ptr, .runtime_instance);
        const untagged = untagPointer(tagged);

        try std.testing.expectEqual(AnyopaqueTag.runtime_instance, untagged.tag);
        try std.testing.expectEqual(original_ptr, untagged.ptr);
    }

    // Test local_value tag
    {
        const tagged = tagPointer(original_ptr, .local_value);
        const untagged = untagPointer(tagged);

        try std.testing.expectEqual(AnyopaqueTag.local_value, untagged.tag);
        try std.testing.expectEqual(original_ptr, untagged.ptr);
    }

    // Test untagged (0 tag)
    {
        const tagged = tagPointer(original_ptr, .untagged);
        const untagged = untagPointer(tagged);

        try std.testing.expectEqual(AnyopaqueTag.untagged, untagged.tag);
        try std.testing.expectEqual(original_ptr, untagged.ptr);
    }
}

test "isTagged detects tags" {
    var dummy_value: u64 align(8) = 0;
    const original_ptr: *anyopaque = @ptrCast(&dummy_value);

    // Untagged pointer should return false
    try std.testing.expect(!isTagged(@ptrCast(original_ptr)));

    // Tagged pointers should return true
    try std.testing.expect(isTagged(tagPointer(original_ptr, .global_handle)));
    try std.testing.expect(isTagged(tagPointer(original_ptr, .runtime_instance)));
    try std.testing.expect(isTagged(tagPointer(original_ptr, .local_value)));

    // Zero tag is still "untagged"
    try std.testing.expect(!isTagged(tagPointer(original_ptr, .untagged)));
}

test "getTag extracts tag without modifying pointer" {
    var dummy_value: u64 align(8) = 0;
    const original_ptr: *anyopaque = @ptrCast(&dummy_value);

    const tagged = tagPointer(original_ptr, .runtime_instance);

    try std.testing.expectEqual(AnyopaqueTag.runtime_instance, getTag(tagged));
}
