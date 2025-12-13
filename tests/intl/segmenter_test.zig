//! Intl.Segmenter Tests
//!
//! Comprehensive tests for text segmentation following ECMA-402 §17
//! and Unicode Text Segmentation (UAX #29).
//!
//! ## Test Categories
//!
//! 1. Grapheme cluster tests - Extended grapheme clusters (UAX #29)
//! 2. Word segmentation tests - Word boundaries with is_word_like
//! 3. Sentence segmentation tests - Sentence boundaries
//! 4. API conformance tests - ECMA-402 Segmenter API

const std = @import("std");
const intl = @import("intl");
const Segmenter = intl.Segmenter;
const Granularity = intl.SegmenterGranularity;

// ============================================================================
// Grapheme Cluster Tests (UAX #29)
// ============================================================================

test "Segmenter grapheme: ASCII characters" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .grapheme });
    defer segmenter.deinit();

    var segments = segmenter.segment("abc");

    try std.testing.expectEqualStrings("a", segments.next().?.segment);
    try std.testing.expectEqualStrings("b", segments.next().?.segment);
    try std.testing.expectEqualStrings("c", segments.next().?.segment);
    try std.testing.expect(segments.next() == null);
}

test "Segmenter grapheme: combining characters (e + acute)" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .grapheme });
    defer segmenter.deinit();

    // e followed by combining acute accent = one grapheme cluster
    var segments = segmenter.segment("e\u{0301}");

    const cluster = segments.next().?;
    try std.testing.expectEqualStrings("e\u{0301}", cluster.segment);
    try std.testing.expect(segments.next() == null);
}

test "Segmenter grapheme: CRLF sequence" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .grapheme });
    defer segmenter.deinit();

    // CR + LF should be treated as single grapheme cluster (GB3)
    var segments = segmenter.segment("\r\n");

    try std.testing.expectEqualStrings("\r\n", segments.next().?.segment);
    try std.testing.expect(segments.next() == null);
}

test "Segmenter grapheme: emoji with skin tone modifier" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .grapheme });
    defer segmenter.deinit();

    // Thumbs up + light skin tone = one grapheme
    var segments = segmenter.segment("\u{1F44D}\u{1F3FB}");

    const cluster = segments.next().?;
    try std.testing.expectEqualStrings("\u{1F44D}\u{1F3FB}", cluster.segment);
    try std.testing.expect(segments.next() == null);
}

test "Segmenter grapheme: flag emoji (Regional Indicator pair)" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .grapheme });
    defer segmenter.deinit();

    // US flag = U+1F1FA (Regional Indicator U) + U+1F1F8 (Regional Indicator S)
    var segments = segmenter.segment("\u{1F1FA}\u{1F1F8}");

    const cluster = segments.next().?;
    try std.testing.expectEqualStrings("\u{1F1FA}\u{1F1F8}", cluster.segment);
    try std.testing.expect(segments.next() == null);
}

test "Segmenter grapheme: Hangul syllable" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"ko"}, .{ .granularity = .grapheme });
    defer segmenter.deinit();

    // 한 = single precomposed Hangul syllable
    var segments = segmenter.segment("한");

    try std.testing.expectEqualStrings("한", segments.next().?.segment);
    try std.testing.expect(segments.next() == null);
}

test "Segmenter grapheme: is_word_like is null for grapheme granularity" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .grapheme });
    defer segmenter.deinit();

    var segments = segmenter.segment("a");
    const seg = segments.next().?;

    try std.testing.expect(seg.is_word_like == null);
}

// ============================================================================
// Word Segmentation Tests (UAX #29)
// ============================================================================

test "Segmenter word: simple words with space" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .word });
    defer segmenter.deinit();

    var segments = segmenter.segment("Hello World");

    const hello = segments.next().?;
    try std.testing.expectEqualStrings("Hello", hello.segment);
    try std.testing.expect(hello.is_word_like.? == true);

    const space = segments.next().?;
    try std.testing.expectEqualStrings(" ", space.segment);
    try std.testing.expect(space.is_word_like.? == false);

    const world = segments.next().?;
    try std.testing.expectEqualStrings("World", world.segment);
    try std.testing.expect(world.is_word_like.? == true);

    try std.testing.expect(segments.next() == null);
}

test "Segmenter word: punctuation separation" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .word });
    defer segmenter.deinit();

    var segments = segmenter.segment("Hello, world!");

    // "Hello"
    const hello = segments.next().?;
    try std.testing.expectEqualStrings("Hello", hello.segment);
    try std.testing.expect(hello.is_word_like.? == true);

    // ","
    const comma = segments.next().?;
    try std.testing.expectEqualStrings(",", comma.segment);
    try std.testing.expect(comma.is_word_like.? == false);

    // " "
    const space = segments.next().?;
    try std.testing.expectEqualStrings(" ", space.segment);
    try std.testing.expect(space.is_word_like.? == false);

    // "world"
    const world = segments.next().?;
    try std.testing.expectEqualStrings("world", world.segment);
    try std.testing.expect(world.is_word_like.? == true);

    // "!"
    const exclaim = segments.next().?;
    try std.testing.expectEqualStrings("!", exclaim.segment);
    try std.testing.expect(exclaim.is_word_like.? == false);
}

test "Segmenter word: alphanumeric" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .word });
    defer segmenter.deinit();

    var segments = segmenter.segment("test123");

    // Letters followed by numbers should stay together (WB9, WB10)
    const word = segments.next().?;
    try std.testing.expectEqualStrings("test123", word.segment);
    try std.testing.expect(word.is_word_like.? == true);
}

test "Segmenter word: numbers only" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .word });
    defer segmenter.deinit();

    var segments = segmenter.segment("12345");

    const num = segments.next().?;
    try std.testing.expectEqualStrings("12345", num.segment);
    try std.testing.expect(num.is_word_like.? == true); // Numbers are word-like
}

test "Segmenter word: CJK characters" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"zh"}, .{ .granularity = .word });
    defer segmenter.deinit();

    // CJK characters - each character may be its own word
    // (Without dictionary-based segmentation, we rely on UAX #29)
    var segments = segmenter.segment("日本語");

    const seg = segments.next();
    try std.testing.expect(seg != null);
    try std.testing.expect(seg.?.is_word_like.? == true);
}

test "Segmenter word: index tracking" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .word });
    defer segmenter.deinit();

    const text = "Hello World";
    var segments = segmenter.segment(text);

    const hello = segments.next().?;
    try std.testing.expectEqual(@as(usize, 0), hello.index);
    try std.testing.expect(std.mem.eql(u8, hello.input, text));

    const space = segments.next().?;
    try std.testing.expectEqual(@as(usize, 5), space.index);

    const world = segments.next().?;
    try std.testing.expectEqual(@as(usize, 6), world.index);
}

// ============================================================================
// Sentence Segmentation Tests (UAX #29)
// ============================================================================

test "Segmenter sentence: simple sentences" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .sentence });
    defer segmenter.deinit();

    var segments = segmenter.segment("Hello. World!");

    // First sentence including terminator
    const first = segments.next().?;
    try std.testing.expect(std.mem.indexOf(u8, first.segment, "Hello") != null);
    try std.testing.expect(first.is_word_like == null); // Not applicable for sentences
}

test "Segmenter sentence: question and exclamation" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .sentence });
    defer segmenter.deinit();

    var segments = segmenter.segment("What? Really!");

    var count: usize = 0;
    while (segments.next()) |seg| {
        count += 1;
        try std.testing.expect(seg.segment.len > 0);
    }

    // Should have at least 1 segment
    try std.testing.expect(count >= 1);
}

test "Segmenter sentence: is_word_like is null for sentence granularity" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .sentence });
    defer segmenter.deinit();

    var segments = segmenter.segment("Hello.");
    const seg = segments.next().?;

    try std.testing.expect(seg.is_word_like == null);
}

// ============================================================================
// API Conformance Tests (ECMA-402 §17)
// ============================================================================

test "Segmenter: default granularity is grapheme" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, null, null);
    defer segmenter.deinit();

    const opts = segmenter.resolvedOptions();
    try std.testing.expectEqual(Granularity.grapheme, opts.granularity);
}

test "Segmenter: default locale is 'en'" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, null, null);
    defer segmenter.deinit();

    const opts = segmenter.resolvedOptions();
    try std.testing.expectEqualStrings("en", opts.locale);
}

test "Segmenter: resolvedOptions reflects constructor options" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"de-DE"}, .{ .granularity = .word });
    defer segmenter.deinit();

    const opts = segmenter.resolvedOptions();
    try std.testing.expectEqualStrings("de-DE", opts.locale);
    try std.testing.expectEqual(Granularity.word, opts.granularity);
}

test "Segmenter: containing() finds segment at index" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .word });
    defer segmenter.deinit();

    const text = "Hello World";
    var segments = segmenter.segment(text);

    // Index 0 is in "Hello"
    const at_0 = segments.containing(0);
    try std.testing.expect(at_0 != null);
    try std.testing.expectEqualStrings("Hello", at_0.?.segment);

    // Index 7 is in "World"
    var segments2 = segmenter.segment(text);
    const at_7 = segments2.containing(7);
    try std.testing.expect(at_7 != null);
    try std.testing.expectEqualStrings("World", at_7.?.segment);
}

test "Segmenter: segment.input references original text" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .word });
    defer segmenter.deinit();

    const original = "Test input";
    var segments = segmenter.segment(original);

    const seg = segments.next().?;
    try std.testing.expect(seg.input.ptr == original.ptr);
    try std.testing.expect(seg.input.len == original.len);
}

// ============================================================================
// Memory Safety Tests
// ============================================================================

test "Segmenter: no memory leaks in repeated usage" {
    const allocator = std.testing.allocator;

    for (0..100) |_| {
        var segmenter = try Segmenter.init(allocator, &.{"en-US"}, .{ .granularity = .word });

        const text = "The quick brown fox jumps over the lazy dog.";
        var segments = segmenter.segment(text);

        while (segments.next()) |_| {}

        segmenter.deinit();
    }
    // If test passes with testing.allocator, no leaks
}

test "Segmenter: multiple segmenters don't interfere" {
    const allocator = std.testing.allocator;

    var grapheme_seg = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .grapheme });
    defer grapheme_seg.deinit();

    var word_seg = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .word });
    defer word_seg.deinit();

    var sentence_seg = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .sentence });
    defer sentence_seg.deinit();

    const text = "Hello World. Goodbye!";

    // Count graphemes
    var g_segments = grapheme_seg.segment(text);
    var grapheme_count: usize = 0;
    while (g_segments.next()) |_| grapheme_count += 1;

    // Count words
    var w_segments = word_seg.segment(text);
    var word_count: usize = 0;
    while (w_segments.next()) |_| word_count += 1;

    // Count sentences
    var s_segments = sentence_seg.segment(text);
    var sentence_count: usize = 0;
    while (s_segments.next()) |_| sentence_count += 1;

    // Grapheme count >= word count >= sentence count
    try std.testing.expect(grapheme_count >= word_count);
}

// ============================================================================
// Edge Cases
// ============================================================================

test "Segmenter: empty string" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .word });
    defer segmenter.deinit();

    var segments = segmenter.segment("");
    try std.testing.expect(segments.next() == null);
}

test "Segmenter: single character" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .grapheme });
    defer segmenter.deinit();

    var segments = segmenter.segment("X");
    try std.testing.expectEqualStrings("X", segments.next().?.segment);
    try std.testing.expect(segments.next() == null);
}

test "Segmenter: all spaces" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .word });
    defer segmenter.deinit();

    var segments = segmenter.segment("   ");
    var count: usize = 0;
    while (segments.next()) |seg| {
        count += 1;
        try std.testing.expect(seg.is_word_like.? == false);
    }
    // Should have some segments (spaces may be grouped)
    try std.testing.expect(count >= 1);
}
