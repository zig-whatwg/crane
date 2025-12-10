//! Tests for CharacterData Small String Optimization (SSO)
//!
//! Spec: https://dom.spec.whatwg.org/#interface-characterdata
//!
//! These tests verify the small string optimization implementation
//! that stores text up to 31 bytes inline (without heap allocation)
//! to reduce memory allocations for typical short text nodes.

const std = @import("std");
const testing = std.testing;

// Import the CharacterData implementation directly for unit testing
const impls = @import("impls");
const CharacterDataImpl = impls.CharacterData;
const InternalState = CharacterDataImpl.InternalState;
const INLINE_TEXT_CAPACITY = CharacterDataImpl.INLINE_TEXT_CAPACITY;

// =============================================================================
// InternalState Unit Tests - Direct SSO Implementation Testing
// =============================================================================

test "SSO - inline capacity is 31 bytes" {
    // Verify the inline capacity constant is set correctly
    // 31 bytes chosen to fit in 32-byte cache line with 1 byte for length
    try testing.expectEqual(@as(usize, 31), INLINE_TEXT_CAPACITY);
}

test "SSO - empty string uses inline storage" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    try testing.expect(state.isInline());
    try testing.expectEqual(@as(u32, 0), state.getLength());
    try testing.expectEqualStrings("", state.getData());
}

test "SSO - short text uses inline storage" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    try state.setData("Hello");

    try testing.expect(state.isInline());
    try testing.expectEqual(@as(u32, 5), state.getLength());
    try testing.expectEqualStrings("Hello", state.getData());
}

test "SSO - maximum inline size (31 bytes)" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    // Exactly 31 bytes should use inline storage
    const max_inline = "1234567890123456789012345678901"; // 31 chars
    try testing.expectEqual(@as(usize, 31), max_inline.len);

    try state.setData(max_inline);

    try testing.expect(state.isInline());
    try testing.expectEqual(@as(u32, 31), state.getLength());
    try testing.expectEqualStrings(max_inline, state.getData());
}

test "SSO - exceeding inline size uses heap storage" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    // 32 bytes should trigger heap allocation
    const heap_data = "12345678901234567890123456789012"; // 32 chars
    try testing.expectEqual(@as(usize, 32), heap_data.len);

    try state.setData(heap_data);

    try testing.expect(!state.isInline());
    try testing.expectEqual(@as(u32, 32), state.getLength());
    try testing.expectEqualStrings(heap_data, state.getData());
}

test "SSO - transition from inline to heap" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    // Start with inline data
    try state.setData("short");
    try testing.expect(state.isInline());

    // Transition to heap
    const long_data = "This is a much longer string that exceeds 31 bytes";
    try state.setData(long_data);

    try testing.expect(!state.isInline());
    try testing.expectEqualStrings(long_data, state.getData());
}

test "SSO - transition from heap back to inline" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    // Start with heap data
    const long_data = "This is a much longer string that exceeds 31 bytes";
    try state.setData(long_data);
    try testing.expect(!state.isInline());

    // Transition back to inline
    try state.setData("short");

    try testing.expect(state.isInline());
    try testing.expectEqualStrings("short", state.getData());
}

test "SSO - replaceData within inline capacity" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    try state.setData("Hello, World!");

    // Replace "World" with "Zig"
    try state.replaceData(7, 5, "Zig");

    try testing.expect(state.isInline());
    try testing.expectEqualStrings("Hello, Zig!", state.getData());
}

test "SSO - replaceData grows from inline to heap" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    try state.setData("Hello");

    // Insert a long string that exceeds inline capacity
    const long_insert = "This is a very long replacement string";
    try state.replaceData(5, 0, long_insert);

    try testing.expect(!state.isInline());
    try testing.expectEqualStrings("Hello" ++ long_insert, state.getData());
}

test "SSO - replaceData shrinks from heap to inline" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    // Start with heap data
    const long_data = "This is a long string that definitely exceeds 31 bytes";
    try state.setData(long_data);
    try testing.expect(!state.isInline());

    // Replace most of it with short text
    try state.replaceData(0, long_data.len, "Hi");

    try testing.expect(state.isInline());
    try testing.expectEqualStrings("Hi", state.getData());
}

test "SSO - appendData (replaceData at end with count 0)" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    try state.setData("Hello");
    try state.replaceData(5, 0, ", World!");

    try testing.expect(state.isInline());
    try testing.expectEqualStrings("Hello, World!", state.getData());
}

test "SSO - insertData (replaceData with count 0)" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    try state.setData("Hello World!");
    try state.replaceData(5, 0, " Beautiful");

    try testing.expect(state.isInline());
    try testing.expectEqualStrings("Hello Beautiful World!", state.getData());
}

test "SSO - deleteData (replaceData with empty string)" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    try state.setData("Hello World!");
    try state.replaceData(5, 6, "");

    try testing.expect(state.isInline());
    try testing.expectEqualStrings("Hello!", state.getData());
}

test "SSO - replaceData clamps count to available length" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    try state.setData("Hello");

    // Count exceeds available length - should be clamped
    try state.replaceData(2, 100, "y");

    try testing.expect(state.isInline());
    try testing.expectEqualStrings("Hey", state.getData());
}

test "SSO - boundary case: exactly 31 bytes after replaceData" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    try state.setData("12345678901234567890"); // 20 bytes

    // Add 11 more bytes to reach exactly 31
    try state.replaceData(20, 0, "12345678901");

    try testing.expect(state.isInline());
    try testing.expectEqual(@as(u32, 31), state.getLength());
}

test "SSO - boundary case: exactly 32 bytes after replaceData" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    try state.setData("12345678901234567890"); // 20 bytes

    // Add 12 more bytes to reach 32 (heap threshold)
    try state.replaceData(20, 0, "123456789012");

    try testing.expect(!state.isInline());
    try testing.expectEqual(@as(u32, 32), state.getLength());
}

test "SSO - typical HTML whitespace (single space)" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    // Most common text node content in HTML
    try state.setData(" ");

    try testing.expect(state.isInline());
    try testing.expectEqual(@as(u32, 1), state.getLength());
}

test "SSO - typical HTML whitespace (newline with indent)" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    // Common whitespace text node in formatted HTML
    try state.setData("\n    ");

    try testing.expect(state.isInline());
    try testing.expectEqual(@as(u32, 5), state.getLength());
}

test "SSO - typical short word" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    // Common short text content
    try state.setData("Click here");

    try testing.expect(state.isInline());
    try testing.expectEqual(@as(u32, 10), state.getLength());
}

test "SSO - special characters within inline" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    // UTF-8 encoded characters (checkmark is 3 bytes)
    const utf8_text = "OK ✓"; // 5 bytes total (O, K, space, checkmark as 3 bytes)
    try state.setData(utf8_text);

    try testing.expect(state.isInline());
    try testing.expectEqualStrings(utf8_text, state.getData());
}

test "SSO - multiple setData calls don't leak memory" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    // Multiple transitions between inline and heap
    try state.setData("short");
    try testing.expect(state.isInline());

    try state.setData("This is a much longer string that definitely exceeds 31 bytes");
    try testing.expect(!state.isInline());

    try state.setData("back to short");
    try testing.expect(state.isInline());

    try state.setData("Another long string that needs heap allocation to store properly");
    try testing.expect(!state.isInline());

    try state.setData("");
    try testing.expect(state.isInline());

    // If we get here without memory leaks, the test passes
    // (testing.allocator will detect leaks automatically)
}

test "SSO - multiple replaceData calls don't leak memory" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    try state.setData("Hello");

    // Multiple modifications
    try state.replaceData(5, 0, " World"); // append
    try state.replaceData(0, 0, "Say: "); // prepend
    try state.replaceData(5, 1, ", beautiful"); // replace and grow

    // Result: "Say: , beautiful World"
    try testing.expect(state.isInline());

    // Now grow to heap
    try state.replaceData(0, 0, "This is a prefix that makes it long: ");
    try testing.expect(!state.isInline());

    // Shrink back to inline
    try state.replaceData(0, state.getLength() - 2, "");
    try testing.expect(state.isInline());

    // testing.allocator will detect any leaks
}

// =============================================================================
// Edge Cases and Error Conditions
// =============================================================================

test "SSO - setData with empty string after heap data" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    // Start with heap
    try state.setData("This is a very long string that needs heap storage");
    try testing.expect(!state.isInline());

    // Clear to empty
    try state.setData("");

    try testing.expect(state.isInline());
    try testing.expectEqual(@as(u32, 0), state.getLength());
    try testing.expectEqualStrings("", state.getData());
}

test "SSO - replaceData preserves data before offset" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    try state.setData("ABCDEFGHIJ");
    try state.replaceData(5, 2, "XYZ");

    // "ABCDE" + "XYZ" + "HIJ" = "ABCDEXYZ HIJ"
    try testing.expectEqualStrings("ABCDEXYZ" ++ "HIJ", state.getData());
}

test "SSO - replaceData at offset 0" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    try state.setData("World");
    try state.replaceData(0, 0, "Hello ");

    try testing.expectEqualStrings("Hello World", state.getData());
}

test "SSO - replaceData deletes entire content" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    try state.setData("Delete me");
    try state.replaceData(0, 9, "");

    try testing.expect(state.isInline());
    try testing.expectEqual(@as(u32, 0), state.getLength());
    try testing.expectEqualStrings("", state.getData());
}

test "SSO - replaceData replaces entire content" {
    var state = try InternalState.init(testing.allocator);
    defer state.deinit();

    try state.setData("Old content");
    try state.replaceData(0, 11, "New");

    try testing.expectEqualStrings("New", state.getData());
}
