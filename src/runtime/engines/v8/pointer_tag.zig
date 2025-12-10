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
//! Check for untagged pointer usage with: `isTagged(ptr)` or `getTag(ptr)`
//!
//! ## Assertion Helpers
//!
//! For catching bugs early:
//! - `assertUntagged(ptr)`: Panics in debug if pointer is tagged
//! - `assertUntaggedOrUntag(ptr)`: Debug panics, release untags silently

const std = @import("std");
const builtin = @import("builtin");

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
/// 3. **Debug assertions**: Built-in validation in debug builds
/// 4. **Method chaining**: Cleaner API (`ptr.untagAs(V8Value)`)
///
/// ## Usage
///
/// ```zig
/// // Create a tagged pointer
/// const tagged = TaggedPointer.init(raw_ptr, .global_handle);
///
/// // Check the tag
/// if (tagged.is(.global_handle)) {
///     const v8_ptr = tagged.untagAs(*v8.Value);
///     // Use v8_ptr...
/// }
///
/// // Get tag without untagging
/// const tag = tagged.getTag();
///
/// // Convert to raw for FFI (with debug assertion)
/// const raw = tagged.toRaw(); // asserts untagged in debug
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

        return .{ .raw = addr | @intFromEnum(tag) };
    }

    /// Create a tagged pointer from a const pointer and tag.
    pub fn initConst(ptr: *const anyopaque, tag: Tag) TaggedPointer {
        const addr = @intFromPtr(ptr);

        if (std.debug.runtime_safety) {
            std.debug.assert(addr & 0x3 == 0);
        }

        return .{ .raw = addr | @intFromEnum(tag) };
    }

    /// Create from a raw usize value (for interop with existing code)
    pub fn fromRaw(raw_addr: usize) TaggedPointer {
        return .{ .raw = raw_addr };
    }

    /// Get the tag without untagging
    pub fn getTag(self: TaggedPointer) Tag {
        return @enumFromInt(self.raw & 0x3);
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

    /// Check if this pointer has a specific tag
    pub fn is(self: TaggedPointer, tag: Tag) bool {
        return self.getTag() == tag;
    }

    /// Check if the pointer is tagged (has non-zero low bits)
    pub fn isTagged(self: TaggedPointer) bool {
        return (self.raw & 0x3) != 0;
    }

    /// Convert to *const anyopaque (preserves tag bits)
    /// Use this when you need to pass the tagged pointer to existing code.
    pub fn toConstPtr(self: TaggedPointer) *const anyopaque {
        return @ptrFromInt(self.raw);
    }

    /// Convert to *anyopaque (preserves tag bits)
    /// WARNING: This returns the tagged pointer, not the untagged one!
    pub fn toPtr(self: TaggedPointer) *anyopaque {
        return @ptrFromInt(self.raw);
    }

    /// Get the raw usize value
    pub fn toRawUsize(self: TaggedPointer) usize {
        return self.raw;
    }

    /// Debug assertion: panic if tag doesn't match expected
    pub fn assertTag(self: TaggedPointer, expected: Tag) void {
        if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
            if (self.getTag() != expected) {
                std.debug.panic(
                    "TaggedPointer tag mismatch: expected {}, got {}",
                    .{ expected, self.getTag() },
                );
            }
        }
    }

    /// Debug assertion: panic if pointer is tagged when untagged expected
    pub fn assertUntagged(self: TaggedPointer) void {
        if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
            if (self.isTagged()) {
                std.debug.panic(
                    "Expected untagged pointer, got tag: {}",
                    .{self.getTag()},
                );
            }
        }
    }

    /// Extract both pointer and tag in one operation
    pub fn extract(self: TaggedPointer) struct { ptr: *anyopaque, tag: Tag } {
        return .{
            .ptr = self.untag(),
            .tag = self.getTag(),
        };
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

/// Error type for pointer tag validation
pub const PointerTagError = error{
    /// A tagged pointer was passed where an untagged pointer was expected
    TaggedPointerAtFFIBoundary,
};

/// Assert that a pointer is untagged (has zero low bits).
///
/// This is a debug-mode assertion to catch cases where tagged pointers
/// are accidentally passed to FFI boundaries. In release builds, this
/// function does nothing to avoid runtime overhead.
///
/// INTENTIONAL PANIC: Passing tagged pointers to V8 FFI functions causes
/// undefined behavior or crashes. This panic is a fail-fast mechanism to
/// catch programming errors early in development.
///
/// For code that needs error handling instead of panic, use checkUntagged().
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

/// Check that a pointer is untagged, returning error if tagged.
///
/// This is the error-returning alternative to assertUntagged().
/// Use this when you need to handle tagged pointers gracefully
/// rather than panicking.
///
/// Returns the untagged pointer on success for convenience.
pub fn checkUntagged(ptr: *const anyopaque) PointerTagError!*anyopaque {
    if (isTagged(ptr)) {
        return PointerTagError.TaggedPointerAtFFIBoundary;
    }
    return @constCast(ptr);
}

/// Assert that a pointer is untagged, or untag it and return the untagged pointer.
///
/// This is a convenience function that:
/// - In Debug/ReleaseSafe: panics if pointer is tagged (catches bugs early)
/// - In ReleaseFast/ReleaseSmall: returns the untagged pointer silently
///
/// INTENTIONAL PANIC in debug mode: This is a fail-fast mechanism to catch
/// programming errors. Passing tagged pointers to V8 causes crashes or UB.
///
/// For code that needs error handling, use checkUntaggedOrUntag().
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

/// Check that a pointer is untagged, or untag it and return the result.
///
/// This is the error-returning alternative to assertUntaggedOrUntag().
/// In Debug/ReleaseSafe mode, returns error if tagged.
/// In ReleaseFast/ReleaseSmall mode, silently untags.
///
/// Use this when you need to handle tagged pointers gracefully.
pub fn checkUntaggedOrUntag(ptr: *const anyopaque) PointerTagError!*anyopaque {
    if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
        if (isTagged(ptr)) {
            return PointerTagError.TaggedPointerAtFFIBoundary;
        }
        return @constCast(ptr);
    } else {
        return untagPointer(ptr).ptr;
    }
}

// ============================================================================
// Debug Assertions for FFI Boundary Safety
// ============================================================================

/// Debug assertion helpers for catching pointer tagging bugs early.
///
/// These functions compile away in ReleaseFast and ReleaseSmall builds,
/// providing zero runtime overhead in production while catching bugs in
/// development.
///
/// ## Usage
///
/// ```zig
/// fn v8CallFunction(ptr: *anyopaque) void {
///     // Catch bugs: tagged pointers passed to V8 will crash
///     DebugAssertions.assertNotTagged(ptr);
///     ffi.v8_Function_Call(ptr);
/// }
///
/// fn processValue(ptr: *anyopaque, expected: TaggedPointer.Tag) void {
///     // Verify we got the expected tag
///     DebugAssertions.assertTagged(ptr, expected);
///     // ...
/// }
/// ```
pub const DebugAssertions = struct {
    const debug_log = std.log.scoped(.pointer_tag);

    /// Assert that a pointer is NOT tagged (low 2 bits are zero).
    ///
    /// Use this at FFI entry points before passing pointers to V8.
    /// Passing tagged pointers to V8 causes crashes or undefined behavior.
    ///
    /// In debug/safe builds: panics with detailed message
    /// In release builds: compiles away completely
    pub fn assertNotTagged(ptr: *const anyopaque) void {
        if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
            const addr = @intFromPtr(ptr);
            if (addr & 0x3 != 0) {
                std.debug.panic(
                    "Expected untagged pointer, got tagged: 0x{x} (tag bits: 0b{b:0>2}, tag: {})",
                    .{ addr, addr & 0x3, @as(AnyopaqueTag, @enumFromInt(addr & 0x3)) },
                );
            }
        }
    }

    /// Assert that a pointer has a specific tag.
    ///
    /// Use this to verify pointer type at boundaries where you expect
    /// a specific type of tagged pointer.
    ///
    /// In debug/safe builds: panics with detailed message if wrong tag
    /// In release builds: compiles away completely
    pub fn assertTagged(ptr: *const anyopaque, expected: AnyopaqueTag) void {
        if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
            const actual = getTag(ptr);
            if (actual != expected) {
                std.debug.panic(
                    "Pointer tag mismatch: expected {}, got {} (address: 0x{x})",
                    .{ expected, actual, @intFromPtr(ptr) },
                );
            }
        }
    }

    /// Assert that a raw address from V8 is aligned (not tagged).
    ///
    /// V8 should always return properly aligned pointers. If we get
    /// a misaligned one, something is very wrong.
    ///
    /// In debug/safe builds: panics with detailed message
    /// In release builds: compiles away completely
    pub fn assertV8ReturnedAligned(addr: usize) void {
        if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
            if (addr & 0x3 != 0) {
                std.debug.panic(
                    "V8 returned misaligned pointer: 0x{x} (low bits: 0b{b:0>2})",
                    .{ addr, addr & 0x3 },
                );
            }
        }
    }

    /// Log creation of tagged pointer (debug only, not panic).
    ///
    /// Use this at conversion boundaries to trace pointer creation
    /// when debugging complex tagging issues.
    ///
    /// Compiles away in all release builds.
    pub fn logTaggedPointerCreation(ptr: *const anyopaque, tag: AnyopaqueTag) void {
        if (builtin.mode == .Debug) {
            debug_log.debug("Creating tagged pointer: 0x{x} with tag={}", .{
                @intFromPtr(ptr),
                tag,
            });
        }
    }

    /// Log untagging of pointer (debug only, not panic).
    ///
    /// Use this when untagging to trace pointer flow when debugging.
    ///
    /// Compiles away in all release builds.
    pub fn logPointerUntagging(tagged_addr: usize, result_ptr: *anyopaque, tag: AnyopaqueTag) void {
        if (builtin.mode == .Debug) {
            debug_log.debug("Untagging pointer: 0x{x} -> 0x{x} (was tag={})", .{
                tagged_addr,
                @intFromPtr(result_ptr),
                tag,
            });
        }
    }
};

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

test "TaggedPointer: initConst roundtrip" {
    var dummy: u64 align(8) = 0xCAFEBABE;
    const ptr: *const anyopaque = @ptrCast(&dummy);

    const tags = [_]TaggedPointer.Tag{ .untagged, .global_handle, .runtime_instance, .local_value };

    for (tags) |tag| {
        const tagged = TaggedPointer.initConst(ptr, tag);
        try std.testing.expectEqual(@intFromPtr(ptr), @intFromPtr(tagged.untag()));
        try std.testing.expectEqual(tag, tagged.getTag());
    }
}

test "TaggedPointer: is() tag checking" {
    var dummy: u64 align(8) = 0;
    const ptr: *anyopaque = @ptrCast(&dummy);

    const tagged = TaggedPointer.init(ptr, .runtime_instance);

    try std.testing.expect(tagged.is(.runtime_instance));
    try std.testing.expect(!tagged.is(.global_handle));
    try std.testing.expect(!tagged.is(.local_value));
    try std.testing.expect(!tagged.is(.untagged));
}

test "TaggedPointer: isTagged()" {
    var dummy: u64 align(8) = 0;
    const ptr: *anyopaque = @ptrCast(&dummy);

    // .untagged (0) should return false
    try std.testing.expect(!TaggedPointer.init(ptr, .untagged).isTagged());

    // All other tags should return true
    try std.testing.expect(TaggedPointer.init(ptr, .global_handle).isTagged());
    try std.testing.expect(TaggedPointer.init(ptr, .runtime_instance).isTagged());
    try std.testing.expect(TaggedPointer.init(ptr, .local_value).isTagged());
}

test "TaggedPointer: untagAs specific type" {
    var value: u64 align(8) = 0x12345678;
    const ptr: *anyopaque = @ptrCast(&value);

    const tagged = TaggedPointer.init(ptr, .local_value);
    const typed_ptr: *u64 = tagged.untagAs(*u64);

    try std.testing.expectEqual(&value, typed_ptr);
    try std.testing.expectEqual(@as(u64, 0x12345678), typed_ptr.*);
}

test "TaggedPointer: extract() returns both ptr and tag" {
    var dummy: u64 align(8) = 0xABCD;
    const ptr: *anyopaque = @ptrCast(&dummy);

    const tagged = TaggedPointer.init(ptr, .global_handle);
    const result = tagged.extract();

    try std.testing.expectEqual(ptr, result.ptr);
    try std.testing.expectEqual(TaggedPointer.Tag.global_handle, result.tag);
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

test "TaggedPointer: assertUntagged does not panic for untagged" {
    var dummy: u64 align(8) = 0;
    const ptr: *anyopaque = @ptrCast(&dummy);

    const tagged = TaggedPointer.init(ptr, .untagged);
    tagged.assertUntagged(); // Should not panic

    // Also test assertTag
    tagged.assertTag(.untagged); // Should not panic
}

test "TaggedPointer: assertTag does not panic for matching tag" {
    var dummy: u64 align(8) = 0;
    const ptr: *anyopaque = @ptrCast(&dummy);

    const tagged = TaggedPointer.init(ptr, .global_handle);
    tagged.assertTag(.global_handle); // Should not panic
}

// ============================================================================
// DebugAssertions Tests
// ============================================================================

test "DebugAssertions: assertNotTagged does not panic for aligned pointers" {
    var dummy: u64 align(8) = 0;
    const ptr: *const anyopaque = @ptrCast(&dummy);

    // Should not panic - pointer is naturally aligned
    DebugAssertions.assertNotTagged(ptr);
}

test "DebugAssertions: assertTagged does not panic for matching tag" {
    var dummy: u64 align(8) = 0;
    const ptr: *anyopaque = @ptrCast(&dummy);

    const tagged = tagPointer(ptr, .global_handle);
    // Should not panic - tag matches
    DebugAssertions.assertTagged(tagged, .global_handle);
}

test "DebugAssertions: assertV8ReturnedAligned does not panic for aligned addresses" {
    var dummy: u64 align(8) = 0;
    const addr = @intFromPtr(&dummy);

    // Should not panic - address is aligned
    DebugAssertions.assertV8ReturnedAligned(addr);
}

test "DebugAssertions: logging functions compile without error" {
    var dummy: u64 align(8) = 0;
    const ptr: *const anyopaque = @ptrCast(&dummy);

    // These should compile and run without issues (no-op in non-debug)
    DebugAssertions.logTaggedPointerCreation(ptr, .local_value);
    DebugAssertions.logPointerUntagging(@intFromPtr(ptr), @constCast(ptr), .local_value);
}
