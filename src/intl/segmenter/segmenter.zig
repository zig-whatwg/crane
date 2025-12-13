//! Intl.Segmenter Implementation (ECMA-402 §17)
//!
//! Provides locale-sensitive text segmentation for grapheme clusters,
//! words, and sentences using Unicode Text Segmentation (UAX #29).
//!
//! ## Usage
//!
//! ```zig
//! const allocator = std.heap.page_allocator;
//!
//! // Create a word segmenter
//! var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .word });
//! defer segmenter.deinit();
//!
//! // Segment text
//! var segments = segmenter.segment("Hello, world!");
//! while (segments.next()) |seg| {
//!     std.debug.print("{s} (word-like: {})\n", .{seg.segment, seg.is_word_like});
//! }
//! ```
//!
//! ## References
//!
//! - ECMA-402 §17: Segmenter Objects
//! - UAX #29: Unicode Text Segmentation

const std = @import("std");
const Allocator = std.mem.Allocator;

const grapheme = @import("grapheme.zig");
const word = @import("word.zig");
const sentence = @import("sentence.zig");

/// Segmentation granularity
pub const Granularity = enum {
    grapheme,
    word,
    sentence,
};

/// Options for Segmenter initialization
pub const Options = struct {
    granularity: Granularity = .grapheme,
};

/// Resolved options (returned by resolvedOptions())
pub const ResolvedOptions = struct {
    locale: []const u8,
    granularity: Granularity,
};

/// A single segment from segmentation
pub const Segment = struct {
    /// The text content of this segment
    segment: []const u8,
    /// The byte index where this segment starts in the input
    index: usize,
    /// Reference to the original input text
    input: []const u8,
    /// Whether this segment is "word-like" (only set for word granularity)
    /// True if the segment contains letters or numbers
    is_word_like: ?bool,
};

/// Iterator over segments in text
pub const Segments = struct {
    text: []const u8,
    granularity: Granularity,
    pos: usize,

    // Internal iterators - only one is active based on granularity
    grapheme_iter: ?grapheme.GraphemeIterator,
    word_iter: ?word.WordIterator,
    sentence_iter: ?sentence.SentenceIterator,

    pub fn init(text: []const u8, granularity: Granularity) Segments {
        var self = Segments{
            .text = text,
            .granularity = granularity,
            .pos = 0,
            .grapheme_iter = null,
            .word_iter = null,
            .sentence_iter = null,
        };

        switch (granularity) {
            .grapheme => self.grapheme_iter = grapheme.GraphemeIterator.init(text),
            .word => self.word_iter = word.WordIterator.init(text),
            .sentence => self.sentence_iter = sentence.SentenceIterator.init(text),
        }

        return self;
    }

    /// Get the next segment
    pub fn next(self: *Segments) ?Segment {
        const start = self.pos;

        const seg_text: ?[]const u8 = switch (self.granularity) {
            .grapheme => if (self.grapheme_iter) |*iter| iter.next() else null,
            .word => if (self.word_iter) |*iter| iter.next() else null,
            .sentence => if (self.sentence_iter) |*iter| iter.next() else null,
        };

        if (seg_text) |text| {
            self.pos += text.len;
            return Segment{
                .segment = text,
                .index = start,
                .input = self.text,
                .is_word_like = if (self.granularity == .word)
                    word.isWordLike(text)
                else
                    null,
            };
        }

        return null;
    }

    /// Find the segment containing a given byte index
    pub fn containing(self: *Segments, index: usize) ?Segment {
        // Reset to beginning
        self.pos = 0;
        switch (self.granularity) {
            .grapheme => if (self.grapheme_iter) |*iter| iter.reset(),
            .word => if (self.word_iter) |*iter| iter.reset(),
            .sentence => if (self.sentence_iter) |*iter| iter.reset(),
        }

        // Find segment containing the index
        while (self.next()) |seg| {
            if (seg.index <= index and index < seg.index + seg.segment.len) {
                return seg;
            }
            if (seg.index > index) break;
        }

        return null;
    }

    /// Create a SegmentIterator for for-loop iteration
    pub fn iterator(self: *Segments) SegmentIterator {
        return SegmentIterator{ .segments = self };
    }
};

/// Standard iterator interface for use in for loops
pub const SegmentIterator = struct {
    segments: *Segments,

    pub fn next(self: *SegmentIterator) ?Segment {
        return self.segments.next();
    }
};

/// Intl.Segmenter - ECMA-402 §17
///
/// Provides locale-sensitive text segmentation.
pub const Segmenter = struct {
    allocator: Allocator,
    locale: []const u8,
    granularity: Granularity,

    /// Initialize a new Segmenter
    ///
    /// Parameters:
    /// - allocator: Memory allocator
    /// - locales: Array of BCP 47 locale tags (first valid one is used)
    /// - options: Segmentation options
    ///
    /// Returns: A new Segmenter instance
    pub fn init(
        allocator: Allocator,
        locales: ?[]const []const u8,
        options: ?Options,
    ) !Segmenter {
        const opts = options orelse Options{};

        // Resolve locale - use first valid locale or default to "en"
        var resolved_locale: []const u8 = "en";
        if (locales) |locs| {
            if (locs.len > 0) {
                // Validate and use first locale
                // For now, accept any locale - full implementation would validate
                resolved_locale = locs[0];
            }
        }

        // Copy locale string
        const locale_copy = try allocator.dupe(u8, resolved_locale);

        return Segmenter{
            .allocator = allocator,
            .locale = locale_copy,
            .granularity = opts.granularity,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Segmenter) void {
        self.allocator.free(self.locale);
    }

    /// Segment text and return a Segments iterator
    ///
    /// Parameters:
    /// - text: The text to segment
    ///
    /// Returns: A Segments object that iterates over segments
    pub fn segment(self: *const Segmenter, text: []const u8) Segments {
        return Segments.init(text, self.granularity);
    }

    /// Get resolved options
    pub fn resolvedOptions(self: *const Segmenter) ResolvedOptions {
        return ResolvedOptions{
            .locale = self.locale,
            .granularity = self.granularity,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Segmenter: grapheme granularity" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .grapheme });
    defer segmenter.deinit();

    var segments = segmenter.segment("Hello");
    var count: usize = 0;

    while (segments.next()) |seg| {
        count += 1;
        try std.testing.expect(seg.is_word_like == null);
    }

    try std.testing.expectEqual(@as(usize, 5), count);
}

test "Segmenter: word granularity" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .word });
    defer segmenter.deinit();

    var segments = segmenter.segment("Hello, world!");

    // First segment should be "Hello" and word-like
    const first = segments.next().?;
    try std.testing.expectEqualStrings("Hello", first.segment);
    try std.testing.expect(first.is_word_like.? == true);

    // Second should be "," and not word-like
    const second = segments.next().?;
    try std.testing.expectEqualStrings(",", second.segment);
    try std.testing.expect(second.is_word_like.? == false);
}

test "Segmenter: sentence granularity" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .sentence });
    defer segmenter.deinit();

    var segments = segmenter.segment("Hello. World!");

    // Should have at least one segment
    const first = segments.next();
    try std.testing.expect(first != null);
    try std.testing.expect(first.?.is_word_like == null);
}

test "Segmenter: default granularity is grapheme" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, null, null);
    defer segmenter.deinit();

    const opts = segmenter.resolvedOptions();
    try std.testing.expectEqual(Granularity.grapheme, opts.granularity);
}

test "Segmenter: resolvedOptions returns locale" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"de-DE"}, .{ .granularity = .word });
    defer segmenter.deinit();

    const opts = segmenter.resolvedOptions();
    try std.testing.expectEqualStrings("de-DE", opts.locale);
    try std.testing.expectEqual(Granularity.word, opts.granularity);
}

test "Segmenter: segment index tracking" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .word });
    defer segmenter.deinit();

    const text = "Hello World";
    var segments = segmenter.segment(text);

    const hello = segments.next().?;
    try std.testing.expectEqual(@as(usize, 0), hello.index);

    const space = segments.next().?;
    try std.testing.expectEqual(@as(usize, 5), space.index);

    const world_seg = segments.next().?;
    try std.testing.expectEqual(@as(usize, 6), world_seg.index);
}

test "Segmenter: containing method" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .word });
    defer segmenter.deinit();

    const text = "Hello World";
    var segments = segmenter.segment(text);

    // Index 7 is in "World"
    const seg = segments.containing(7);
    try std.testing.expect(seg != null);
    try std.testing.expectEqualStrings("World", seg.?.segment);
}

test "Segmenter: emoji handling" {
    const allocator = std.testing.allocator;

    var segmenter = try Segmenter.init(allocator, &.{"en"}, .{ .granularity = .grapheme });
    defer segmenter.deinit();

    // Thumbs up with skin tone modifier - should be one grapheme
    var segments = segmenter.segment("\u{1F44D}\u{1F3FB}");

    const emoji = segments.next();
    try std.testing.expect(emoji != null);
    // The entire emoji sequence should be one segment
    try std.testing.expectEqualStrings("\u{1F44D}\u{1F3FB}", emoji.?.segment);

    // No more segments
    try std.testing.expect(segments.next() == null);
}

test "Segmenter: memory safety - no leaks" {
    const allocator = std.testing.allocator;

    for (0..100) |_| {
        var segmenter = try Segmenter.init(allocator, &.{"en-US"}, .{ .granularity = .word });
        var segments = segmenter.segment("The quick brown fox jumps over the lazy dog.");

        while (segments.next()) |_| {}

        segmenter.deinit();
    }
    // If test passes with testing.allocator, no leaks
}
