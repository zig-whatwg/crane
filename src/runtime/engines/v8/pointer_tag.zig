//! # Pointer Tagging for V8 FFI
//!
//! This module implements pointer tagging to distinguish between different
//! pointer types at the V8/Zig boundary. Tags are encoded in the low 2 bits
//! of pointers, which are always zero due to alignment requirements.
//!
//! ## Why Tagging?
//!
//! When JavaScript calls Zig code with a value, the `fromV8Value` function in
//! conversions.zig may return a `*const anyopaque` that represents one of:
//! - A V8 Local handle to a primitive (string, number, etc.)
//! - A V8 Global handle to a persistent object (function, callback)
//! - A Zig runtime instance wrapped in a V8 object
//!
//! Without type information encoded in the pointer, consumers cannot safely
//! determine how to use the pointer, leading to crashes from:
//! - Passing Zig instance pointers to V8 FFI functions
//! - Casting V8 handles to Zig types
//! - Alignment violations (tagged pointers are misaligned)
//!
//! ## Tag Values
//!
//! | Tag | Value | Meaning |
//! |-----|-------|---------|
//! | `.untagged` | 0 | Legacy untagged pointer (assume V8 Local) |
//! | `.global_handle` | 1 | V8 Global<Value>* - persists beyond HandleScope |
//! | `.runtime_instance` | 2 | Zig *runtime.Instance - NOT a V8 pointer! |
//! | `.local_value` | 3 | V8 Local<Value>* - temporary, current scope only |
//!
//! ## Tagging Contract
//!
//! **PRODUCER** (conversions.zig `fromV8Value` for `*const anyopaque`):
//! - Tags all returned pointers with appropriate tag
//! - Determines tag by checking if V8 object wraps a Zig instance
//!
//! **CONSUMERS** (engine.zig, binding.zig, impl code):
//! - MUST call `untagPointer()` before ANY use of the pointer
//! - MUST NOT pass tagged pointers to V8 FFI functions (will crash!)
//! - Use the returned tag to determine correct handling
//!
//! ## Implementation Details
//!
//! Pointer tagging exploits the fact that all allocations are at least 4-byte
//! aligned, meaning the low 2 bits of any valid pointer are always zero:
//!
//! ```
//! ┌──────────────────────────────────────────────────────┐
//! │ Pointer address (62 bits on 64-bit)              │Tag│
//! │ xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxx │XX │
//! └──────────────────────────────────────────────────────┘
//!                                                      ↑
//!                                              2-bit type tag
//! ```
//!
//! - `tagPointer()`: ORs the tag into the low 2 bits
//! - `untagPointer()`: ANDs out the tag, returns both pointer and tag
//!
//! ## Usage Examples
//!
//! ### Consuming a Potentially Tagged Pointer
//!
//! ```zig
//! fn v8IsString(js_value: *const anyopaque) bool {
//!     const pointer_tag = @import("pointer_tag.zig");
//!     const untagged = pointer_tag.untagPointer(js_value);
//!
//!     // SAFETY: Must check tag - runtime_instance is NOT a V8 value!
//!     if (untagged.tag == .runtime_instance) {
//!         return false; // Zig instances are not V8 strings
//!     }
//!
//!     // Safe to use as V8 value now
//!     const value: *ffi.Value = @ptrCast(untagged.ptr);
//!     return ffi.v8_Value_IsString(value);
//! }
//! ```
//!
//! ### Dispatching Based on Tag
//!
//! ```zig
//! fn processAnyValue(tagged_ptr: *const anyopaque) void {
//!     const untagged = pointer_tag.untagPointer(tagged_ptr);
//!     switch (untagged.tag) {
//!         .runtime_instance => {
//!             // Zig instance - use directly
//!             const instance: *runtime.Instance = @ptrCast(@alignCast(untagged.ptr));
//!             instance.doSomething();
//!         },
//!         .global_handle => {
//!             // V8 Global - survives HandleScope, remember to dispose
//!             const global: *v8.Value = @ptrCast(untagged.ptr);
//!             defer v8.v8_Value_Dispose(global);
//!             // Use V8 value...
//!         },
//!         .local_value, .untagged => {
//!             // V8 Local - only valid in current HandleScope
//!             const local: *v8.Value = @ptrCast(untagged.ptr);
//!             // Use V8 value...
//!         },
//!     }
//! }
//! ```
//!
//! ## Debugging Tips
//!
//! - **Alignment panic at 0x...3**: Pointer is tagged with .local_value (tag=3)
//! - **Alignment panic at 0x...2**: Pointer is tagged with .runtime_instance (tag=2)
//! - **Alignment panic at 0x...1**: Pointer is tagged with .global_handle (tag=1)
//! - **SIGSEGV in V8 code**: Probably passed a .runtime_instance to V8 FFI
//!
//! Read a pointer's tag with `untagPointer(ptr).tag`.

const std = @import("std");

// ============================================================================
// TaggedPointer - Type-safe wrapper for tagged pointers
// ============================================================================

/// Type-safe wrapper for tagged pointers at V8 FFI boundaries.
///
/// This struct encapsulates a tagged pointer, providing a clear type that
/// indicates the pointer contains type information in its low 2 bits.
/// It cannot be accidentally used as a raw pointer without explicit conversion.
///
/// ## Benefits over raw `*anyopaque`
///
/// 1. **Type safety**: Can't accidentally use raw pointer as tagged or vice versa
/// 2. **Clear intent**: Type name documents the pointer is tagged
/// 3. **Method chaining**: Cleaner API (`ptr.untagAs(V8Value)`)
///
/// ## Usage
///
/// ```zig
/// // Create a tagged pointer
/// const tagged = TaggedPointer.init(raw_ptr, .global_handle);
///
/// // Check the tag
/// if (tagged.getTag() == .global_handle) {
///     const v8_ptr = tagged.untagAs(*v8.Value);
///     // Use v8_ptr...
/// }
///
/// // Get tag without untagging
/// const tag = tagged.getTag();
///
/// // Hand the tagged pointer on, tag bits kept
/// const raw = tagged.toConstPtr();
/// ```
pub const TaggedPointer = struct {
    /// The raw tagged address (pointer + tag in low 2 bits)
    raw: usize,

    /// Tag type - same as AnyopaqueTag for compatibility
    pub const Tag = AnyopaqueTag;

    /// Create a tagged pointer from a raw pointer and tag.
    ///
    /// The pointer MUST be at least 4-byte aligned (standard for all allocations).
    /// In debug builds, asserts alignment.
    pub fn init(ptr: *anyopaque, tag: Tag) TaggedPointer {
        const addr = @intFromPtr(ptr);

        // Safety check: pointer must be aligned (low bits should be 0)
        if (std.debug.runtime_safety) {
            std.debug.assert(addr & 0x3 == 0);
        }

        return .{ .raw = addr | @backingInt(tag) };
    }

    /// Create from a raw usize value (for interop with existing code)
    pub fn fromRaw(raw_addr: usize) TaggedPointer {
        return .{ .raw = raw_addr };
    }

    /// Get the tag without untagging
    pub fn getTag(self: TaggedPointer) Tag {
        return @fromBackingInt(@intCast(self.raw & 0x3));
    }

    /// Untag and return the pointer as *anyopaque
    pub fn untag(self: TaggedPointer) *anyopaque {
        return @ptrFromInt(self.raw & ~@as(usize, 0x3));
    }

    /// Untag and cast to a specific pointer type
    pub fn untagAs(self: TaggedPointer, comptime T: type) T {
        const ptr = self.untag();
        return @ptrCast(@alignCast(ptr));
    }

    /// Convert to *const anyopaque (preserves tag bits)
    /// Use this when you need to pass the tagged pointer to existing code.
    pub fn toConstPtr(self: TaggedPointer) *const anyopaque {
        return @ptrFromInt(self.raw);
    }
};

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

    const tagged_addr = addr | @backingInt(tag);
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
    const tag: AnyopaqueTag = @fromBackingInt(@intCast(addr & 0x3));

    // Clear low 2 bits to get original pointer
    const untagged_addr = addr & ~@as(usize, 0x3);
    const ptr: *anyopaque = @ptrFromInt(untagged_addr);

    return .{
        .ptr = ptr,
        .tag = tag,
    };
}

// ============================================================================
// Debug tracing hooks
// ============================================================================

/// Tracing hooks at the tagging boundaries (conversions.zig, engine.zig),
/// disabled: each compiles to nothing.
pub const DebugAssertions = struct {
    const debug_log = std.log.scoped(.pointer_tag);

    /// Log creation of tagged pointer (debug only, not panic).
    ///
    /// Use this at conversion boundaries to trace pointer creation
    /// when debugging complex tagging issues.
    ///
    /// Disabled by default to avoid noisy output.
    pub fn logTaggedPointerCreation(ptr: *const anyopaque, tag: AnyopaqueTag) void {
        // Disabled to avoid noisy debug output
        _ = ptr;
        _ = tag;
    }

    /// Log untagging of pointer (debug only, not panic).
    ///
    /// Use this when untagging to trace pointer flow when debugging.
    ///
    /// Disabled by default to avoid noisy output.
    pub fn logPointerUntagging(tagged_addr: usize, result_ptr: *anyopaque, tag: AnyopaqueTag) void {
        // Disabled to avoid noisy debug output
        _ = tagged_addr;
        _ = result_ptr;
        _ = tag;
    }
};

// ============================================================================
// Tests
// ============================================================================

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

test "edge case - maximum address values" {
    // Test with addresses that have high bits set (simulating high memory addresses)
    // We can't actually use arbitrary addresses, but we can test the math

    // Simulate a high address by using a stack variable and checking the math
    var dummy: u64 align(8) = 0;
    const ptr: *anyopaque = @ptrCast(&dummy);
    const base_addr = @intFromPtr(ptr);

    // Verify tagging math: tagged = base | tag, untagged = tagged & ~0x3
    for ([_]AnyopaqueTag{ .untagged, .global_handle, .runtime_instance, .local_value }) |tag| {
        const tag_val = @backingInt(tag);
        const expected_tagged = base_addr | tag_val;
        const expected_untagged = expected_tagged & ~@as(usize, 0x3);

        const tagged = tagPointer(ptr, tag);
        const untagged = untagPointer(tagged);

        try std.testing.expectEqual(expected_tagged, @intFromPtr(tagged));
        try std.testing.expectEqual(expected_untagged, @intFromPtr(untagged.ptr));
        try std.testing.expectEqual(base_addr, @intFromPtr(untagged.ptr));
    }
}

// ============================================================================
// TaggedPointer Struct Tests
// ============================================================================

test "TaggedPointer: init and untag roundtrip" {
    var dummy: u64 align(8) = 0xDEADBEEF;
    const ptr: *anyopaque = @ptrCast(&dummy);

    // Test all tag values
    const tags = [_]TaggedPointer.Tag{ .untagged, .global_handle, .runtime_instance, .local_value };

    for (tags) |tag| {
        const tagged = TaggedPointer.init(ptr, tag);
        const untagged = tagged.untag();

        try std.testing.expectEqual(ptr, untagged);
        try std.testing.expectEqual(tag, tagged.getTag());
    }
}

test "TaggedPointer: fromRaw interop" {
    var dummy: u64 align(8) = 0;
    const ptr: *anyopaque = @ptrCast(&dummy);
    const base_addr = @intFromPtr(ptr);

    // Create tagged using init
    const tagged1 = TaggedPointer.init(ptr, .runtime_instance);

    // Create using fromRaw with same value
    const tagged2 = TaggedPointer.fromRaw(base_addr | 2); // .runtime_instance = 2

    try std.testing.expectEqual(tagged1.raw, tagged2.raw);
    try std.testing.expectEqual(tagged1.getTag(), tagged2.getTag());
}

test "TaggedPointer: toConstPtr preserves tag" {
    var dummy: u64 align(8) = 0;
    const ptr: *anyopaque = @ptrCast(&dummy);

    const tagged = TaggedPointer.init(ptr, .local_value);
    const const_ptr = tagged.toConstPtr();

    // The const ptr should still have tag bits set
    try std.testing.expectEqual(tagged.raw, @intFromPtr(const_ptr));
}
