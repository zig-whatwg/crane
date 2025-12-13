//! Grapheme Cluster Break Algorithm (UAX #29)
//!
//! Implements Unicode Text Segmentation for Extended Grapheme Clusters.
//! Reference: https://www.unicode.org/reports/tr29/
//!
//! ## Grapheme Break Property Categories
//!
//! - CR, LF, Control: Line endings and control characters
//! - Extend, ZWJ: Combining marks and zero-width joiner
//! - Regional_Indicator: Flag emoji sequences
//! - Prepend: Characters that prepend to following characters
//! - SpacingMark: Spacing combining marks
//! - L, V, T, LV, LVT: Hangul syllable components
//!
//! ## Break Rules
//!
//! The algorithm processes text left-to-right, determining whether to break
//! between each pair of adjacent characters based on their Grapheme_Break properties.

const std = @import("std");

/// Grapheme Break Property from UAX #29
pub const GraphemeBreakProperty = enum {
    Other,
    CR,
    LF,
    Control,
    Extend,
    ZWJ,
    Regional_Indicator,
    Prepend,
    SpacingMark,
    L, // Hangul Jamo Leading
    V, // Hangul Jamo Vowel
    T, // Hangul Jamo Trailing
    LV, // Hangul Syllable LV
    LVT, // Hangul Syllable LVT
};

/// Get the Grapheme Break Property for a Unicode code point
pub fn getGraphemeBreakProperty(cp: u21) GraphemeBreakProperty {
    // CR
    if (cp == 0x000D) return .CR;

    // LF
    if (cp == 0x000A) return .LF;

    // Control (Cc, Cf categories - subset)
    // Cc: C0, C1 controls
    if (cp <= 0x001F and cp != 0x000A and cp != 0x000D) return .Control;
    if (cp >= 0x007F and cp <= 0x009F) return .Control;
    // Common format characters
    if (cp == 0x00AD) return .Control; // SOFT HYPHEN
    if (cp == 0x061C) return .Control; // ARABIC LETTER MARK
    if (cp >= 0x180E and cp <= 0x180E) return .Control; // MONGOLIAN VOWEL SEPARATOR
    if (cp >= 0x200B and cp <= 0x200D) {
        if (cp == 0x200D) return .ZWJ; // ZERO WIDTH JOINER
        return .Control; // ZERO WIDTH SPACE, ZERO WIDTH NON-JOINER
    }
    if (cp >= 0x2060 and cp <= 0x206F) return .Control; // Word joiner, invisible times, etc.
    if (cp >= 0xFE00 and cp <= 0xFE0F) return .Extend; // Variation Selectors
    if (cp >= 0xFEFF and cp <= 0xFEFF) return .Control; // BOM
    if (cp >= 0xFFF0 and cp <= 0xFFF8) return .Control; // Specials

    // ZWJ
    if (cp == 0x200D) return .ZWJ;

    // Regional Indicator (U+1F1E6..U+1F1FF)
    if (cp >= 0x1F1E6 and cp <= 0x1F1FF) return .Regional_Indicator;

    // Extend: Combining marks (Mn, Mc subset, Me)
    // Combining Diacritical Marks
    if (cp >= 0x0300 and cp <= 0x036F) return .Extend;
    // Combining Diacritical Marks Extended
    if (cp >= 0x1AB0 and cp <= 0x1AFF) return .Extend;
    // Combining Diacritical Marks Supplement
    if (cp >= 0x1DC0 and cp <= 0x1DFF) return .Extend;
    // Combining Diacritical Marks for Symbols
    if (cp >= 0x20D0 and cp <= 0x20FF) return .Extend;
    // Combining Half Marks
    if (cp >= 0xFE20 and cp <= 0xFE2F) return .Extend;

    // Arabic marks
    if (cp >= 0x0610 and cp <= 0x061A) return .Extend;
    if (cp >= 0x064B and cp <= 0x065F) return .Extend;
    if (cp == 0x0670) return .Extend;
    if (cp >= 0x06D6 and cp <= 0x06DC) return .Extend;
    if (cp >= 0x06DF and cp <= 0x06E4) return .Extend;
    if (cp >= 0x06E7 and cp <= 0x06E8) return .Extend;
    if (cp >= 0x06EA and cp <= 0x06ED) return .Extend;

    // Hebrew marks
    if (cp >= 0x0591 and cp <= 0x05BD) return .Extend;
    if (cp == 0x05BF) return .Extend;
    if (cp >= 0x05C1 and cp <= 0x05C2) return .Extend;
    if (cp >= 0x05C4 and cp <= 0x05C5) return .Extend;
    if (cp == 0x05C7) return .Extend;

    // Devanagari signs
    if (cp >= 0x0900 and cp <= 0x0903) return if (cp == 0x0903) .SpacingMark else .Extend;
    if (cp >= 0x093A and cp <= 0x094F) {
        // Some are spacing marks, most are extends
        if (cp == 0x093B or cp == 0x093E or cp == 0x093F or cp == 0x0940 or
            cp == 0x0949 or cp == 0x094A or cp == 0x094B or cp == 0x094C)
            return .SpacingMark;
        return .Extend;
    }

    // Bengali, Tamil, Telugu, etc. - simplified
    if (cp >= 0x0981 and cp <= 0x0983) return if (cp == 0x0981) .Extend else .SpacingMark;
    if (cp >= 0x09BC and cp <= 0x09C4) return .Extend;
    if (cp >= 0x09C7 and cp <= 0x09C8) return .SpacingMark;
    if (cp >= 0x09CB and cp <= 0x09CC) return .SpacingMark;
    if (cp == 0x09CD) return .Extend;
    if (cp >= 0x09E2 and cp <= 0x09E3) return .Extend;

    // Thai marks
    if (cp >= 0x0E31 and cp <= 0x0E31) return .Extend;
    if (cp >= 0x0E34 and cp <= 0x0E3A) return .Extend;
    if (cp >= 0x0E47 and cp <= 0x0E4E) return .Extend;

    // Hangul Jamo
    // Leading consonants (L): U+1100..U+115F, U+A960..U+A97C
    if ((cp >= 0x1100 and cp <= 0x115F) or (cp >= 0xA960 and cp <= 0xA97C)) return .L;
    // Vowels (V): U+1160..U+11A7, U+D7B0..U+D7C6
    if ((cp >= 0x1160 and cp <= 0x11A7) or (cp >= 0xD7B0 and cp <= 0xD7C6)) return .V;
    // Trailing consonants (T): U+11A8..U+11FF, U+D7CB..U+D7FB
    if ((cp >= 0x11A8 and cp <= 0x11FF) or (cp >= 0xD7CB and cp <= 0xD7FB)) return .T;

    // Hangul Syllables
    if (cp >= 0xAC00 and cp <= 0xD7A3) {
        // Check if LV or LVT
        const syllable_base = cp - 0xAC00;
        const t_count = 28;
        if (syllable_base % t_count == 0) {
            return .LV;
        } else {
            return .LVT;
        }
    }

    // Prepend characters (rare - Brahmic script signs)
    if (cp == 0x0600 or cp == 0x0601 or cp == 0x0602 or cp == 0x0603 or
        cp == 0x0604 or cp == 0x0605 or cp == 0x06DD or cp == 0x070F or
        cp == 0x0890 or cp == 0x0891 or cp == 0x08E2)
    {
        return .Prepend;
    }

    // Emoji Modifier (skin tones) - Extend
    if (cp >= 0x1F3FB and cp <= 0x1F3FF) return .Extend;

    // Emoji Component - Extend (hair styles, etc.)
    if (cp >= 0x1F9B0 and cp <= 0x1F9B3) return .Extend;

    // Variation selectors supplement
    if (cp >= 0xE0100 and cp <= 0xE01EF) return .Extend;

    // Default
    return .Other;
}

/// State machine for grapheme cluster breaking
pub const GraphemeBreakState = struct {
    prev_prop: GraphemeBreakProperty,
    ri_count: u32, // Count of consecutive Regional Indicator characters
    in_extended_pictographic: bool,

    pub fn init() GraphemeBreakState {
        return .{
            .prev_prop = .Other,
            .ri_count = 0,
            .in_extended_pictographic = false,
        };
    }

    /// Returns true if there should be a break BEFORE this code point
    pub fn shouldBreak(self: *GraphemeBreakState, curr_prop: GraphemeBreakProperty) bool {
        const prev = self.prev_prop;
        const result = shouldBreakBetween(prev, curr_prop, self);

        // Update state
        self.prev_prop = curr_prop;
        if (curr_prop == .Regional_Indicator) {
            self.ri_count += 1;
        } else {
            self.ri_count = 0;
        }

        return result;
    }
};

/// Determine if there should be a break between two grapheme break properties
/// Implements UAX #29 Grapheme Cluster Break Rules
fn shouldBreakBetween(prev: GraphemeBreakProperty, curr: GraphemeBreakProperty, state: *GraphemeBreakState) bool {
    // GB1: Break at start of text (handled by iterator)
    // GB2: Break at end of text (handled by iterator)

    // GB3: Do not break between CR and LF
    if (prev == .CR and curr == .LF) return false;

    // GB4: Break after Control, CR, LF
    if (prev == .Control or prev == .CR or prev == .LF) return true;

    // GB5: Break before Control, CR, LF
    if (curr == .Control or curr == .CR or curr == .LF) return true;

    // GB6: Do not break Hangul syllable sequences (L)
    // L × (L | V | LV | LVT)
    if (prev == .L and (curr == .L or curr == .V or curr == .LV or curr == .LVT)) return false;

    // GB7: Do not break Hangul syllable sequences (LV, V)
    // (LV | V) × (V | T)
    if ((prev == .LV or prev == .V) and (curr == .V or curr == .T)) return false;

    // GB8: Do not break Hangul syllable sequences (LVT, T)
    // (LVT | T) × T
    if ((prev == .LVT or prev == .T) and curr == .T) return false;

    // GB9: Do not break before Extend or ZWJ
    // × (Extend | ZWJ)
    if (curr == .Extend or curr == .ZWJ) return false;

    // GB9a: Do not break before SpacingMark
    // × SpacingMark
    if (curr == .SpacingMark) return false;

    // GB9b: Do not break after Prepend
    // Prepend ×
    if (prev == .Prepend) return false;

    // GB11: Do not break within emoji modifier sequences or emoji ZWJ sequences
    // Extended_Pictographic Extend* ZWJ × Extended_Pictographic
    // (Simplified: ZWJ followed by emoji-like keeps sequence together)
    if (prev == .ZWJ and state.in_extended_pictographic) {
        // Check if current is an extended pictographic (simplified check)
        // In a full implementation, we'd need the Extended_Pictographic property
        return false;
    }

    // GB12, GB13: Do not break within Regional Indicator pairs
    // Regional_Indicator × Regional_Indicator (only first pair)
    if (prev == .Regional_Indicator and curr == .Regional_Indicator) {
        // Only allow pairs: odd count means we're at second of pair
        return (state.ri_count % 2) == 0;
    }

    // GB999: Otherwise, break everywhere
    return true;
}

/// Iterator over grapheme clusters in a string
pub const GraphemeIterator = struct {
    text: []const u8,
    pos: usize,
    state: GraphemeBreakState,

    pub fn init(text: []const u8) GraphemeIterator {
        return .{
            .text = text,
            .pos = 0,
            .state = GraphemeBreakState.init(),
        };
    }

    /// Returns the next grapheme cluster, or null if at end
    pub fn next(self: *GraphemeIterator) ?[]const u8 {
        if (self.pos >= self.text.len) return null;

        const start = self.pos;

        // Decode first code point
        const first_len = std.unicode.utf8ByteSequenceLength(self.text[self.pos]) catch 1;
        if (self.pos + first_len > self.text.len) {
            // Invalid UTF-8, treat as single byte
            self.pos += 1;
            return self.text[start..self.pos];
        }

        const first_cp = std.unicode.utf8Decode(self.text[self.pos..][0..first_len]) catch {
            self.pos += 1;
            return self.text[start..self.pos];
        };

        self.pos += first_len;
        var prev_prop = getGraphemeBreakProperty(first_cp);
        self.state.prev_prop = prev_prop;
        if (prev_prop == .Regional_Indicator) {
            self.state.ri_count = 1;
        }

        // Continue until we find a break
        while (self.pos < self.text.len) {
            const next_len = std.unicode.utf8ByteSequenceLength(self.text[self.pos]) catch break;
            if (self.pos + next_len > self.text.len) break;

            const next_cp = std.unicode.utf8Decode(self.text[self.pos..][0..next_len]) catch break;
            const next_prop = getGraphemeBreakProperty(next_cp);

            if (self.state.shouldBreak(next_prop)) {
                break;
            }

            self.pos += next_len;
            prev_prop = next_prop;
        }

        return self.text[start..self.pos];
    }

    /// Reset iterator to beginning
    pub fn reset(self: *GraphemeIterator) void {
        self.pos = 0;
        self.state = GraphemeBreakState.init();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "grapheme iterator: ASCII text" {
    var iter = GraphemeIterator.init("Hello");
    try std.testing.expectEqualStrings("H", iter.next().?);
    try std.testing.expectEqualStrings("e", iter.next().?);
    try std.testing.expectEqualStrings("l", iter.next().?);
    try std.testing.expectEqualStrings("l", iter.next().?);
    try std.testing.expectEqualStrings("o", iter.next().?);
    try std.testing.expect(iter.next() == null);
}

test "grapheme iterator: combining characters" {
    // e + combining acute accent = one grapheme
    var iter = GraphemeIterator.init("e\u{0301}");
    const cluster = iter.next().?;
    try std.testing.expectEqualStrings("e\u{0301}", cluster);
    try std.testing.expect(iter.next() == null);
}

test "grapheme iterator: CRLF" {
    var iter = GraphemeIterator.init("\r\n");
    // CR + LF should be one grapheme (GB3)
    try std.testing.expectEqualStrings("\r\n", iter.next().?);
    try std.testing.expect(iter.next() == null);
}

test "grapheme iterator: emoji with modifier" {
    // Thumbs up + skin tone modifier
    var iter = GraphemeIterator.init("\u{1F44D}\u{1F3FB}");
    const cluster = iter.next().?;
    try std.testing.expectEqualStrings("\u{1F44D}\u{1F3FB}", cluster);
    try std.testing.expect(iter.next() == null);
}

test "grapheme iterator: flag emoji pair" {
    // US flag = U+1F1FA U+1F1F8 (Regional Indicator pair)
    var iter = GraphemeIterator.init("\u{1F1FA}\u{1F1F8}");
    const cluster = iter.next().?;
    try std.testing.expectEqualStrings("\u{1F1FA}\u{1F1F8}", cluster);
    try std.testing.expect(iter.next() == null);
}

test "grapheme iterator: Hangul syllable" {
    // 한 (composed) - single grapheme
    var iter = GraphemeIterator.init("한");
    const cluster = iter.next().?;
    try std.testing.expectEqualStrings("한", cluster);
    try std.testing.expect(iter.next() == null);
}

test "grapheme property: basic categories" {
    try std.testing.expectEqual(GraphemeBreakProperty.CR, getGraphemeBreakProperty('\r'));
    try std.testing.expectEqual(GraphemeBreakProperty.LF, getGraphemeBreakProperty('\n'));
    try std.testing.expectEqual(GraphemeBreakProperty.Control, getGraphemeBreakProperty(0x00));
    try std.testing.expectEqual(GraphemeBreakProperty.ZWJ, getGraphemeBreakProperty(0x200D));
    try std.testing.expectEqual(GraphemeBreakProperty.Regional_Indicator, getGraphemeBreakProperty(0x1F1E6));
    try std.testing.expectEqual(GraphemeBreakProperty.Extend, getGraphemeBreakProperty(0x0300));
    try std.testing.expectEqual(GraphemeBreakProperty.L, getGraphemeBreakProperty(0x1100));
    try std.testing.expectEqual(GraphemeBreakProperty.V, getGraphemeBreakProperty(0x1160));
    try std.testing.expectEqual(GraphemeBreakProperty.T, getGraphemeBreakProperty(0x11A8));
}
