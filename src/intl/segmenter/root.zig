//! Intl.Segmenter Module (ECMA-402 §17)
//!
//! Locale-sensitive text segmentation for grapheme clusters, words, and sentences.
//! Implements Unicode Text Segmentation (UAX #29).
//!
//! ## Features
//!
//! - **Grapheme segmentation**: Extended grapheme cluster boundaries
//! - **Word segmentation**: Word boundaries with is_word_like property
//! - **Sentence segmentation**: Sentence boundaries
//!
//! ## Example
//!
//! ```zig
//! const segmenter = @import("intl").segmenter;
//!
//! var seg = try segmenter.Segmenter.init(allocator, &.{"en"}, .{ .granularity = .word });
//! defer seg.deinit();
//!
//! var segments = seg.segment("Hello, world!");
//! while (segments.next()) |s| {
//!     std.debug.print("'{s}' word-like={?}\n", .{s.segment, s.is_word_like});
//! }
//! // Output:
//! // 'Hello' word-like=true
//! // ',' word-like=false
//! // ' ' word-like=false
//! // 'world' word-like=true
//! // '!' word-like=false
//! ```

const std = @import("std");

// Core types
pub const segmenter = @import("segmenter.zig");
pub const Segmenter = segmenter.Segmenter;
pub const Segments = segmenter.Segments;
pub const SegmentIterator = segmenter.SegmentIterator;
pub const Segment = segmenter.Segment;
pub const Granularity = segmenter.Granularity;
pub const Options = segmenter.Options;
pub const ResolvedOptions = segmenter.ResolvedOptions;

// Break algorithms (for advanced usage)
pub const grapheme = @import("grapheme.zig");
pub const word = @import("word.zig");
pub const sentence = @import("sentence.zig");

// Re-export iterator types for direct usage
pub const GraphemeIterator = grapheme.GraphemeIterator;
pub const WordIterator = word.WordIterator;
pub const SentenceIterator = sentence.SentenceIterator;

// Re-export property functions for advanced usage
pub const getGraphemeBreakProperty = grapheme.getGraphemeBreakProperty;
pub const getWordBreakProperty = word.getWordBreakProperty;
pub const getSentenceBreakProperty = sentence.getSentenceBreakProperty;
pub const isWordLike = word.isWordLike;

// Property enums
pub const GraphemeBreakProperty = grapheme.GraphemeBreakProperty;
pub const WordBreakProperty = word.WordBreakProperty;
pub const SentenceBreakProperty = sentence.SentenceBreakProperty;

test {
    // Run all module tests
    _ = segmenter;
    _ = grapheme;
    _ = word;
    _ = sentence;
}
