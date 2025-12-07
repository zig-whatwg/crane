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
const builtin = @import("builtin");

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

/// Assert that a pointer is untagged (has zero low bits).
///
/// This is a debug-mode assertion to catch cases where tagged pointers
/// are accidentally passed to FFI boundaries. In release builds, this
/// function does nothing to avoid runtime overhead.
///
/// Panics in Debug/ReleaseSafe if the pointer has non-zero tag bits.
///
/// Usage:
/// ```zig
/// fn v8IsString(js_value: *const anyopaque) bool {
///     assertUntagged(js_value);  // Catches bugs in debug builds
///     const value: *ffi.Value = @ptrCast(js_value);
///     return ffi.v8_Value_IsString(value);
/// }
/// ```
pub fn assertUntagged(ptr: *const anyopaque) void {
    if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
        if (isTagged(ptr)) {
            @panic("Tagged pointer passed to FFI boundary - call untagPointer() first");
        }
    }
}

/// Assert that a pointer is untagged, or untag it and return the untagged pointer.
///
/// This is a convenience function that:
/// - In Debug/ReleaseSafe: panics if pointer is tagged (catches bugs early)
/// - In ReleaseFast/ReleaseSmall: returns the untagged pointer silently
///
/// This is useful for FFI boundaries where you want to catch bugs in development
/// but also want automatic untagging in production for resilience.
pub fn assertUntaggedOrUntag(ptr: *const anyopaque) *anyopaque {
    if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
        if (isTagged(ptr)) {
            @panic("Tagged pointer passed to FFI boundary - call untagPointer() first");
        }
        // In debug mode, we've verified it's untagged, return as-is
        return @constCast(ptr);
    } else {
        // In release mode, silently untag for resilience
        return untagPointer(ptr).ptr;
    }
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

// ============================================================================
// Comprehensive Tests for Pointer Tagging Round-Trips
// ============================================================================

test "round-trip all tag types with loop" {
    // Test all tag values in a single loop for comprehensive coverage
    var dummy_value: u64 align(8) = 0xDEADBEEF12345678;
    const original_ptr: *anyopaque = @ptrCast(&dummy_value);

    const tags = [_]AnyopaqueTag{ .untagged, .global_handle, .runtime_instance, .local_value };

    for (tags) |tag| {
        const tagged = tagPointer(original_ptr, tag);
        const untagged = untagPointer(tagged);

        try std.testing.expectEqual(original_ptr, untagged.ptr);
        try std.testing.expectEqual(tag, untagged.tag);
    }
}

test "tagConstPointer and untagPointer round-trip" {
    var dummy_value: u64 align(8) = 0xCAFEBABE;
    const original_ptr: *const anyopaque = @ptrCast(&dummy_value);

    const tags = [_]AnyopaqueTag{ .untagged, .global_handle, .runtime_instance, .local_value };

    for (tags) |tag| {
        const tagged = tagConstPointer(original_ptr, tag);
        const untagged = untagPointer(tagged);

        // The untagged ptr should match the original (cast away const for comparison)
        try std.testing.expectEqual(@intFromPtr(original_ptr), @intFromPtr(untagged.ptr));
        try std.testing.expectEqual(tag, untagged.tag);
    }
}

test "alignment preservation - untagged pointer is properly aligned" {
    // Create pointers with different alignments to verify the tagging
    // preserves the base alignment (after untagging)
    var value_4: u32 align(4) = 0x12345678;
    var value_8: u64 align(8) = 0x12345678DEADBEEF;
    var value_16: u128 align(16) = 0x12345678DEADBEEFCAFEBABE00000000;

    // Test 4-byte aligned pointer
    {
        const ptr: *anyopaque = @ptrCast(&value_4);
        const original_addr = @intFromPtr(ptr);

        const tagged = tagPointer(ptr, .global_handle);
        const untagged = untagPointer(tagged);

        // Verify the untagged address matches the original
        try std.testing.expectEqual(original_addr, @intFromPtr(untagged.ptr));
        // Verify it's still 4-byte aligned
        try std.testing.expectEqual(@as(usize, 0), @intFromPtr(untagged.ptr) & 0x3);
    }

    // Test 8-byte aligned pointer
    {
        const ptr: *anyopaque = @ptrCast(&value_8);
        const original_addr = @intFromPtr(ptr);

        const tagged = tagPointer(ptr, .runtime_instance);
        const untagged = untagPointer(tagged);

        try std.testing.expectEqual(original_addr, @intFromPtr(untagged.ptr));
        try std.testing.expectEqual(@as(usize, 0), @intFromPtr(untagged.ptr) & 0x7);
    }

    // Test 16-byte aligned pointer
    {
        const ptr: *anyopaque = @ptrCast(&value_16);
        const original_addr = @intFromPtr(ptr);

        const tagged = tagPointer(ptr, .local_value);
        const untagged = untagPointer(tagged);

        try std.testing.expectEqual(original_addr, @intFromPtr(untagged.ptr));
        try std.testing.expectEqual(@as(usize, 0), @intFromPtr(untagged.ptr) & 0xF);
    }
}

test "tag detection - verify correct tag is extracted" {
    var dummy: u64 align(8) = 0;
    const ptr: *anyopaque = @ptrCast(&dummy);

    // Test each tag value explicitly
    try std.testing.expectEqual(AnyopaqueTag.untagged, getTag(tagPointer(ptr, .untagged)));
    try std.testing.expectEqual(AnyopaqueTag.global_handle, getTag(tagPointer(ptr, .global_handle)));
    try std.testing.expectEqual(AnyopaqueTag.runtime_instance, getTag(tagPointer(ptr, .runtime_instance)));
    try std.testing.expectEqual(AnyopaqueTag.local_value, getTag(tagPointer(ptr, .local_value)));
}

test "edge case - maximum address values" {
    // Test with addresses that have high bits set (simulating high memory addresses)
    // We can't actually use arbitrary addresses, but we can test the math

    // Simulate a high address by using a stack variable and checking the math
    var dummy: u64 align(8) = 0;
    const ptr: *anyopaque = @ptrCast(&dummy);
    const base_addr = @intFromPtr(ptr);

    // Verify tagging math: tagged = base | tag, untagged = tagged & ~0x3
    for ([_]AnyopaqueTag{ .untagged, .global_handle, .runtime_instance, .local_value }) |tag| {
        const tag_val = @intFromEnum(tag);
        const expected_tagged = base_addr | tag_val;
        const expected_untagged = expected_tagged & ~@as(usize, 0x3);

        const tagged = tagPointer(ptr, tag);
        const untagged = untagPointer(tagged);

        try std.testing.expectEqual(expected_tagged, @intFromPtr(tagged));
        try std.testing.expectEqual(expected_untagged, @intFromPtr(untagged.ptr));
        try std.testing.expectEqual(base_addr, @intFromPtr(untagged.ptr));
    }
}

test "edge case - repeatedly tag and untag same pointer" {
    var dummy: u64 align(8) = 0xABCDEF0123456789;
    const ptr: *anyopaque = @ptrCast(&dummy);

    // Tag, untag, re-tag with different tag, untag again
    const tagged1 = tagPointer(ptr, .global_handle);
    const untagged1 = untagPointer(tagged1);
    try std.testing.expectEqual(ptr, untagged1.ptr);

    const tagged2 = tagPointer(untagged1.ptr, .runtime_instance);
    const untagged2 = untagPointer(tagged2);
    try std.testing.expectEqual(ptr, untagged2.ptr);

    const tagged3 = tagPointer(untagged2.ptr, .local_value);
    const untagged3 = untagPointer(tagged3);
    try std.testing.expectEqual(ptr, untagged3.ptr);
}

test "isTagged with all tag types" {
    var dummy: u64 align(8) = 0;
    const ptr: *anyopaque = @ptrCast(&dummy);

    // .untagged (0) should return false (it has no tag bits set)
    try std.testing.expect(!isTagged(tagPointer(ptr, .untagged)));

    // All other tags should return true
    try std.testing.expect(isTagged(tagPointer(ptr, .global_handle)));
    try std.testing.expect(isTagged(tagPointer(ptr, .runtime_instance)));
    try std.testing.expect(isTagged(tagPointer(ptr, .local_value)));

    // Raw pointer (not tagged via tagPointer) should return false
    try std.testing.expect(!isTagged(@ptrCast(ptr)));
}

test "assertUntagged does not panic for untagged pointers" {
    var dummy: u64 align(8) = 0;
    const ptr: *const anyopaque = @ptrCast(&dummy);

    // This should not panic - pointer is naturally untagged
    assertUntagged(ptr);

    // Pointer tagged with .untagged (tag value 0) should also not panic
    const tagged_untagged = tagPointer(@constCast(ptr), .untagged);
    assertUntagged(tagged_untagged);
}

test "assertUntaggedOrUntag returns correct pointer for untagged input" {
    var dummy: u64 align(8) = 0xDEADBEEF;
    const ptr: *const anyopaque = @ptrCast(&dummy);

    // For untagged pointer, should return the same address
    const result = assertUntaggedOrUntag(ptr);
    try std.testing.expectEqual(@intFromPtr(ptr), @intFromPtr(result));
}

test "multiple pointers maintain independence" {
    // Ensure tagging one pointer doesn't affect another
    var value1: u64 align(8) = 0x1111111111111111;
    var value2: u64 align(8) = 0x2222222222222222;

    const ptr1: *anyopaque = @ptrCast(&value1);
    const ptr2: *anyopaque = @ptrCast(&value2);

    const tagged1 = tagPointer(ptr1, .global_handle);
    const tagged2 = tagPointer(ptr2, .runtime_instance);

    const untagged1 = untagPointer(tagged1);
    const untagged2 = untagPointer(tagged2);

    // Each pointer should untag to its original value
    try std.testing.expectEqual(ptr1, untagged1.ptr);
    try std.testing.expectEqual(ptr2, untagged2.ptr);
    try std.testing.expectEqual(AnyopaqueTag.global_handle, untagged1.tag);
    try std.testing.expectEqual(AnyopaqueTag.runtime_instance, untagged2.tag);

    // Values should be unchanged
    try std.testing.expectEqual(@as(u64, 0x1111111111111111), value1);
    try std.testing.expectEqual(@as(u64, 0x2222222222222222), value2);
}
