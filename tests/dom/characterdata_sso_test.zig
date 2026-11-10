//! Tests for CharacterData Small String Optimization (SSO)
//!
//! Spec: https://dom.spec.whatwg.org/#interface-characterdata
//!
//! These tests verify the small string optimization implementation
//! that stores text up to 8 bytes inline (without heap allocation)
//! to reduce memory allocations for typical short text nodes. The data is 16
//! bytes since lane nd1 batch 1 (31 bytes inline before); whitespace of the
//! shape Gecko shares is tested in nd1_text_data_storage_test.zig.

const std = @import("std");
const testing = std.testing;

// The data's type, which CharacterData keeps in its state
// (dom.character_data.Data), unit-tested on its own.
const character_data = @import("dom").character_data;
const InternalState = character_data.Data;
const INLINE_TEXT_CAPACITY = InternalState.inline_capacity;

/// The bytes are in the Data's own word (no block of their own).
fn isInline(state: *const InternalState) bool {
    return state.storage() == .in_word;
}

// =============================================================================
// InternalState Unit Tests - Direct SSO Implementation Testing
// =============================================================================

test "SSO - inline capacity is 8 bytes" {
    // One word beside the two u32 lengths: the data is 16 bytes (lane nd1
    // batch 1; Lightpanda's string, src/string.zig, has the same 16).
    try testing.expectEqual(@as(usize, 8), INLINE_TEXT_CAPACITY);
}

test "SSO - empty string uses inline storage" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    try testing.expect(isInline(&state));
    try testing.expectEqual(@as(u32, 0), state.getLength());
    try testing.expectEqualStrings("", state.getData());
}

test "SSO - short text uses inline storage" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    try state.setData(testing.allocator, "Hello");

    try testing.expect(isInline(&state));
    try testing.expectEqual(@as(u32, 5), state.getLength());
    try testing.expectEqualStrings("Hello", state.getData());
}

test "SSO - maximum inline size (8 bytes)" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    // Exactly 8 bytes should use inline storage
    const max_inline = "12345678"; // 8 chars
    try testing.expectEqual(@as(usize, 8), max_inline.len);

    try state.setData(testing.allocator, max_inline);

    try testing.expect(isInline(&state));
    try testing.expectEqual(@as(u32, 8), state.getLength());
    try testing.expectEqualStrings(max_inline, state.getData());
}

test "SSO - exceeding inline size uses heap storage" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    // 9 bytes should trigger heap allocation
    const heap_data = "123456789"; // 9 chars
    try testing.expectEqual(@as(usize, 9), heap_data.len);

    try state.setData(testing.allocator, heap_data);

    try testing.expect(!isInline(&state));
    try testing.expectEqual(@as(u32, 9), state.getLength());
    try testing.expectEqualStrings(heap_data, state.getData());
}

test "SSO - transition from inline to heap" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    // Start with inline data
    try state.setData(testing.allocator, "short");
    try testing.expect(isInline(&state));

    // Transition to heap
    const long_data = "This is a much longer string that exceeds 31 bytes";
    try state.setData(testing.allocator, long_data);

    try testing.expect(!isInline(&state));
    try testing.expectEqualStrings(long_data, state.getData());
}

test "SSO - transition from heap back to inline" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    // Start with heap data
    const long_data = "This is a much longer string that exceeds 31 bytes";
    try state.setData(testing.allocator, long_data);
    try testing.expect(!isInline(&state));

    // Transition back to inline
    try state.setData(testing.allocator, "short");

    try testing.expect(isInline(&state));
    try testing.expectEqualStrings("short", state.getData());
}

test "SSO - replaceData within inline capacity" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    try state.setData(testing.allocator, "Hi, Bob!");

    // Replace "Bob" with "Al"
    try state.replaceData(testing.allocator, 4, 3, "Al");

    try testing.expect(isInline(&state));
    try testing.expectEqualStrings("Hi, Al!", state.getData());
}

test "SSO - replaceData grows from inline to heap" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    try state.setData(testing.allocator, "Hello");

    // Insert a long string that exceeds inline capacity
    const long_insert = "This is a very long replacement string";
    try state.replaceData(testing.allocator, 5, 0, long_insert);

    try testing.expect(!isInline(&state));
    try testing.expectEqualStrings("Hello" ++ long_insert, state.getData());
}

test "SSO - replaceData shrinks from heap to inline" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    // Start with heap data
    const long_data = "This is a long string that definitely exceeds 31 bytes";
    try state.setData(testing.allocator, long_data);
    try testing.expect(!isInline(&state));

    // Replace most of it with short text
    try state.replaceData(testing.allocator, 0, long_data.len, "Hi");

    try testing.expect(isInline(&state));
    try testing.expectEqualStrings("Hi", state.getData());
}

test "SSO - appendData (replaceData at end with count 0)" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    try state.setData(testing.allocator, "Hello");
    try state.replaceData(testing.allocator, 5, 0, ", W");

    try testing.expect(isInline(&state));
    try testing.expectEqualStrings("Hello, W", state.getData());
}

test "SSO - insertData (replaceData with count 0)" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    try state.setData(testing.allocator, "Hi!");
    try state.replaceData(testing.allocator, 2, 0, " yo");

    try testing.expect(isInline(&state));
    try testing.expectEqualStrings("Hi yo!", state.getData());
}

test "SSO - deleteData (replaceData with empty string)" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    try state.setData(testing.allocator, "Hello World!");
    try state.replaceData(testing.allocator, 5, 6, "");

    try testing.expect(isInline(&state));
    try testing.expectEqualStrings("Hello!", state.getData());
}

test "SSO - replaceData clamps count to available length" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    try state.setData(testing.allocator, "Hello");

    // Count exceeds available length - should be clamped
    try state.replaceData(testing.allocator, 2, 100, "y");

    try testing.expect(isInline(&state));
    try testing.expectEqualStrings("Hey", state.getData());
}

test "SSO - boundary case: exactly 8 bytes after replaceData" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    try state.setData(testing.allocator, "12345"); // 5 bytes

    // Add 3 more bytes to reach exactly 8
    try state.replaceData(testing.allocator, 5, 0, "678");

    try testing.expect(isInline(&state));
    try testing.expectEqual(@as(u32, 8), state.getLength());
}

test "SSO - boundary case: exactly 9 bytes after replaceData" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    try state.setData(testing.allocator, "12345"); // 5 bytes

    // Add 4 more bytes to reach 9 (heap threshold)
    try state.replaceData(testing.allocator, 5, 0, "6789");

    try testing.expect(!isInline(&state));
    try testing.expectEqual(@as(u32, 9), state.getLength());
}

test "SSO - typical HTML whitespace (single space)" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    // Most common text node content in HTML
    try state.setData(testing.allocator, " ");

    try testing.expect(isInline(&state));
    try testing.expectEqual(@as(u32, 1), state.getLength());
}

test "SSO - typical HTML whitespace (newline with indent)" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    // Common whitespace text node in formatted HTML
    try state.setData(testing.allocator, "\n    ");

    try testing.expect(isInline(&state));
    try testing.expectEqual(@as(u32, 5), state.getLength());
}

test "SSO - typical short word" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    // Common short text content
    try state.setData(testing.allocator, "Home");

    try testing.expect(isInline(&state));
    try testing.expectEqual(@as(u32, 4), state.getLength());
}

test "SSO - special characters within inline" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    // UTF-8 encoded characters (checkmark is 3 bytes)
    const utf8_text = "OK ✓"; // 5 bytes total (O, K, space, checkmark as 3 bytes)
    try state.setData(testing.allocator, utf8_text);

    try testing.expect(isInline(&state));
    try testing.expectEqualStrings(utf8_text, state.getData());
}

test "SSO - multiple setData calls don't leak memory" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    // Multiple transitions between inline and heap
    try state.setData(testing.allocator, "short");
    try testing.expect(isInline(&state));

    try state.setData(testing.allocator, "This is a much longer string that definitely exceeds 31 bytes");
    try testing.expect(!isInline(&state));

    try state.setData(testing.allocator, "back");
    try testing.expect(isInline(&state));

    try state.setData(testing.allocator, "Another long string that needs heap allocation to store properly");
    try testing.expect(!isInline(&state));

    try state.setData(testing.allocator, "");
    try testing.expect(isInline(&state));

    // If we get here without memory leaks, the test passes
    // (testing.allocator will detect leaks automatically)
}

test "SSO - multiple replaceData calls don't leak memory" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    try state.setData(testing.allocator, "Hello");

    // Multiple modifications
    try state.replaceData(testing.allocator, 5, 0, " World"); // append
    try state.replaceData(testing.allocator, 0, 0, "Say: "); // prepend
    try state.replaceData(testing.allocator, 5, 1, ", beautiful"); // replace and grow

    // The last call replaced the "H" at offset 5: 26 bytes, past the word
    // (the old comment's "Say: , beautiful World" was never the result).
    try testing.expect(!isInline(&state));
    try testing.expectEqualStrings("Say: , beautifulello World", state.getData());

    // Now grow it
    try state.replaceData(testing.allocator, 0, 0, "This is a prefix that makes it long: ");
    try testing.expect(!isInline(&state));

    // Shrink back to inline
    try state.replaceData(testing.allocator, 0, state.getLength() - 2, "");
    try testing.expect(isInline(&state));

    // testing.allocator will detect any leaks
}

// =============================================================================
// Edge Cases and Error Conditions
// =============================================================================

test "SSO - setData with empty string after heap data" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    // Start with heap
    try state.setData(testing.allocator, "This is a very long string that needs heap storage");
    try testing.expect(!isInline(&state));

    // Clear to empty
    try state.setData(testing.allocator, "");

    try testing.expect(isInline(&state));
    try testing.expectEqual(@as(u32, 0), state.getLength());
    try testing.expectEqualStrings("", state.getData());
}

test "SSO - replaceData preserves data before offset" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    try state.setData(testing.allocator, "ABCDEFGHIJ");
    try state.replaceData(testing.allocator, 5, 2, "XYZ");

    // "ABCDE" + "XYZ" + "HIJ" = "ABCDEXYZ HIJ"
    try testing.expectEqualStrings("ABCDEXYZ" ++ "HIJ", state.getData());
}

test "SSO - replaceData at offset 0" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    try state.setData(testing.allocator, "World");
    try state.replaceData(testing.allocator, 0, 0, "Hello ");

    try testing.expectEqualStrings("Hello World", state.getData());
}

test "SSO - replaceData deletes entire content" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    try state.setData(testing.allocator, "Delete me");
    try state.replaceData(testing.allocator, 0, 9, "");

    try testing.expect(isInline(&state));
    try testing.expectEqual(@as(u32, 0), state.getLength());
    try testing.expectEqualStrings("", state.getData());
}

test "SSO - replaceData replaces entire content" {
    var state: InternalState = .empty;
    defer state.deinit(testing.allocator);

    try state.setData(testing.allocator, "Old content");
    try state.replaceData(testing.allocator, 0, 11, "New");

    try testing.expectEqualStrings("New", state.getData());
}
