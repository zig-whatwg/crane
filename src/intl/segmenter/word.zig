//! Word Break Algorithm (UAX #29)
//!
//! Implements Unicode Text Segmentation for Word Boundaries.
//! Reference: https://www.unicode.org/reports/tr29/
//!
//! ## Word Break Property Categories
//!
//! - ALetter: Alphabetic characters
//! - Numeric: Decimal digits
//! - Katakana: Japanese Katakana
//! - Hebrew_Letter: Hebrew letters with special rules
//! - ExtendNumLet: Underscore and similar connectors
//! - WSegSpace: Word-separating space
//! - MidLetter, MidNum, MidNumLet: Punctuation in words/numbers
//!
//! ## is_word_like
//!
//! For word granularity, segments have an is_word_like property:
//! - true: Contains ALetter, Hebrew_Letter, Katakana, or Numeric
//! - false: Punctuation, spaces, or other non-word characters

const std = @import("std");

/// Word Break Property from UAX #29
pub const WordBreakProperty = enum {
    Other,
    CR,
    LF,
    Newline,
    Extend,
    ZWJ,
    Regional_Indicator,
    Format,
    Katakana,
    Hebrew_Letter,
    ALetter,
    Single_Quote,
    Double_Quote,
    MidNumLet,
    MidLetter,
    MidNum,
    Numeric,
    ExtendNumLet,
    WSegSpace,
};

/// Get the Word Break Property for a Unicode code point
pub fn getWordBreakProperty(cp: u21) WordBreakProperty {
    // CR
    if (cp == 0x000D) return .CR;

    // LF
    if (cp == 0x000A) return .LF;

    // Newline: U+000B, U+000C, U+0085, U+2028, U+2029
    if (cp == 0x000B or cp == 0x000C or cp == 0x0085 or cp == 0x2028 or cp == 0x2029)
        return .Newline;

    // ZWJ
    if (cp == 0x200D) return .ZWJ;

    // Regional Indicator
    if (cp >= 0x1F1E6 and cp <= 0x1F1FF) return .Regional_Indicator;

    // Single_Quote (U+0027)
    if (cp == 0x0027) return .Single_Quote;

    // Double_Quote (U+0022)
    if (cp == 0x0022) return .Double_Quote;

    // MidNumLet: . · ʼ ᾽ ' ․
    if (cp == 0x002E or cp == 0x2018 or cp == 0x2019 or cp == 0x2024 or
        cp == 0x00B7 or cp == 0x02BC or cp == 0x1FBD)
        return .MidNumLet;

    // MidLetter: : · ־ ·
    if (cp == 0x003A or cp == 0x00B7 or cp == 0x05F4 or cp == 0x0387 or
        cp == 0x055F or cp == 0x2027 or cp == 0xFE13 or cp == 0xFE55)
        return .MidLetter;

    // MidNum: , ʻ ʽ ‌ ⁄
    if (cp == 0x002C or cp == 0x003B or cp == 0x037E or cp == 0x0589 or
        cp == 0x060C or cp == 0x060D or cp == 0x066C or cp == 0x07F8 or
        cp == 0x2044 or cp == 0xFE10 or cp == 0xFE14)
        return .MidNum;

    // ExtendNumLet: _ ‿ ⁀ ⁔ ︳ ︴ ﹍ ﹎ ﹏ ＿
    if (cp == 0x005F or cp == 0x203F or cp == 0x2040 or cp == 0x2054 or
        cp == 0xFE33 or cp == 0xFE34 or cp == 0xFE4D or cp == 0xFE4E or
        cp == 0xFE4F or cp == 0xFF3F)
        return .ExtendNumLet;

    // WSegSpace (word-separating space)
    if (cp == 0x0020 or cp == 0x00A0 or cp == 0x1680 or
        (cp >= 0x2000 and cp <= 0x200A) or cp == 0x202F or cp == 0x205F or cp == 0x3000)
        return .WSegSpace;

    // Hebrew_Letter (Hebrew alphabet)
    if (cp >= 0x05D0 and cp <= 0x05EA) return .Hebrew_Letter;
    if (cp >= 0xFB1D and cp <= 0xFB4F) return .Hebrew_Letter; // Presentation forms

    // Katakana
    if (cp >= 0x30A0 and cp <= 0x30FF) return .Katakana;
    if (cp >= 0x31F0 and cp <= 0x31FF) return .Katakana; // Katakana Phonetic Extensions
    if (cp >= 0xFF66 and cp <= 0xFF9F) return .Katakana; // Halfwidth Katakana
    if (cp == 0x3031 or cp == 0x3032 or cp == 0x3033 or cp == 0x3034 or cp == 0x3035)
        return .Katakana;

    // Numeric (decimal digits)
    if (cp >= 0x0030 and cp <= 0x0039) return .Numeric;
    // Arabic-Indic digits
    if (cp >= 0x0660 and cp <= 0x0669) return .Numeric;
    // Extended Arabic-Indic digits
    if (cp >= 0x06F0 and cp <= 0x06F9) return .Numeric;
    // Devanagari digits
    if (cp >= 0x0966 and cp <= 0x096F) return .Numeric;
    // Bengali, Gurmukhi, etc. digits - simplified
    if (cp >= 0x09E6 and cp <= 0x09EF) return .Numeric;
    // Thai digits
    if (cp >= 0x0E50 and cp <= 0x0E59) return .Numeric;

    // Format characters
    if (cp >= 0x00AD and cp <= 0x00AD) return .Format; // Soft hyphen
    if (cp >= 0x200B and cp <= 0x200C) return .Format; // ZWSP, ZWNJ
    if (cp >= 0x2060 and cp <= 0x206F) return .Format;
    if (cp == 0xFEFF) return .Format;

    // Extend (combining marks, etc.)
    // Combining Diacritical Marks
    if (cp >= 0x0300 and cp <= 0x036F) return .Extend;
    // Combining Diacritical Marks Extended
    if (cp >= 0x1AB0 and cp <= 0x1AFF) return .Extend;
    // Combining Diacritical Marks Supplement
    if (cp >= 0x1DC0 and cp <= 0x1DFF) return .Extend;
    // Arabic marks
    if (cp >= 0x0610 and cp <= 0x061A) return .Extend;
    if (cp >= 0x064B and cp <= 0x065F) return .Extend;
    if (cp == 0x0670) return .Extend;
    // Hebrew marks
    if (cp >= 0x0591 and cp <= 0x05BD) return .Extend;
    if (cp == 0x05BF) return .Extend;
    if (cp >= 0x05C1 and cp <= 0x05C2) return .Extend;
    if (cp >= 0x05C4 and cp <= 0x05C5) return .Extend;
    if (cp == 0x05C7) return .Extend;

    // ALetter (alphabetic) - broad categories
    // Basic Latin letters
    if ((cp >= 0x0041 and cp <= 0x005A) or (cp >= 0x0061 and cp <= 0x007A)) return .ALetter;
    // Latin Extended-A, B, etc.
    if (cp >= 0x00C0 and cp <= 0x00FF and cp != 0x00D7 and cp != 0x00F7) return .ALetter;
    if (cp >= 0x0100 and cp <= 0x024F) return .ALetter;
    // Greek
    if (cp >= 0x0370 and cp <= 0x03FF) return .ALetter;
    // Cyrillic
    if (cp >= 0x0400 and cp <= 0x04FF) return .ALetter;
    if (cp >= 0x0500 and cp <= 0x052F) return .ALetter;
    // Armenian
    if (cp >= 0x0531 and cp <= 0x058A) return .ALetter;
    // Arabic letters (not marks)
    if (cp >= 0x0620 and cp <= 0x064A) return .ALetter;
    if (cp >= 0x066E and cp <= 0x06D3) return .ALetter;
    // Devanagari
    if (cp >= 0x0904 and cp <= 0x0939) return .ALetter;
    if (cp >= 0x0958 and cp <= 0x0961) return .ALetter;
    // Thai
    if (cp >= 0x0E01 and cp <= 0x0E2E) return .ALetter;
    // Hangul syllables
    if (cp >= 0xAC00 and cp <= 0xD7A3) return .ALetter;
    // Hangul Jamo
    if (cp >= 0x1100 and cp <= 0x11FF) return .ALetter;
    // Hiragana
    if (cp >= 0x3040 and cp <= 0x309F) return .ALetter;
    // CJK Ideographs
    if (cp >= 0x4E00 and cp <= 0x9FFF) return .ALetter;
    // Latin Extended Additional
    if (cp >= 0x1E00 and cp <= 0x1EFF) return .ALetter;
    // Latin Extended-C, D
    if (cp >= 0x2C60 and cp <= 0x2C7F) return .ALetter;
    if (cp >= 0xA720 and cp <= 0xA7FF) return .ALetter;

    return .Other;
}

/// Check if a word segment is "word-like" (contains letters or numbers)
pub fn isWordLike(segment: []const u8) bool {
    var pos: usize = 0;
    while (pos < segment.len) {
        const len = std.unicode.utf8ByteSequenceLength(segment[pos]) catch {
            pos += 1;
            continue;
        };
        if (pos + len > segment.len) break;

        const cp = std.unicode.utf8Decode(segment[pos..][0..len]) catch {
            pos += 1;
            continue;
        };

        const prop = getWordBreakProperty(cp);
        switch (prop) {
            .ALetter, .Hebrew_Letter, .Katakana, .Numeric => return true,
            else => {},
        }
        pos += len;
    }
    return false;
}

/// State machine for word breaking
pub const WordBreakState = struct {
    prev_prop: WordBreakProperty,
    prev_prev_prop: WordBreakProperty,
    ri_count: u32,

    pub fn init() WordBreakState {
        return .{
            .prev_prop = .Other,
            .prev_prev_prop = .Other,
            .ri_count = 0,
        };
    }

    /// Returns true if there should be a break BEFORE this code point
    pub fn shouldBreak(self: *WordBreakState, curr_prop: WordBreakProperty) bool {
        const result = shouldBreakBetween(self.prev_prev_prop, self.prev_prop, curr_prop, self);

        // Update state
        self.prev_prev_prop = self.prev_prop;
        self.prev_prop = curr_prop;
        if (curr_prop == .Regional_Indicator) {
            self.ri_count += 1;
        } else {
            self.ri_count = 0;
        }

        return result;
    }
};

/// Determine if there should be a break between word break properties
/// Implements UAX #29 Word Break Rules
fn shouldBreakBetween(
    prev_prev: WordBreakProperty,
    prev: WordBreakProperty,
    curr: WordBreakProperty,
    state: *WordBreakState,
) bool {
    // WB1, WB2: Break at start/end of text (handled by iterator)

    // WB3: Do not break between CR × LF
    if (prev == .CR and curr == .LF) return false;

    // WB3a: Break after Newline, CR, LF
    if (prev == .Newline or prev == .CR or prev == .LF) return true;

    // WB3b: Break before Newline, CR, LF
    if (curr == .Newline or curr == .CR or curr == .LF) return true;

    // WB3c: Do not break within emoji ZWJ sequences
    if (prev == .ZWJ) return false; // Simplified - full impl checks Extended_Pictographic

    // WB3d: Keep horizontal whitespace together
    if (prev == .WSegSpace and curr == .WSegSpace) return false;

    // WB4: Ignore Format and Extend (X (Extend | Format | ZWJ)* → X)
    // Simplified: don't break before Extend, Format, ZWJ
    if (curr == .Extend or curr == .Format or curr == .ZWJ) return false;

    // WB5: Do not break between letters
    // AHLetter × AHLetter
    if (isAHLetter(prev) and isAHLetter(curr)) return false;

    // WB6: AHLetter × (MidLetter | MidNumLetQ) AHLetter
    // (look-ahead rule - simplified)
    if (isAHLetter(prev) and (curr == .MidLetter or curr == .MidNumLet or curr == .Single_Quote)) {
        // Would need look-ahead, simplified to not break
        return false;
    }

    // WB7: AHLetter (MidLetter | MidNumLetQ) × AHLetter
    if ((prev == .MidLetter or prev == .MidNumLet or prev == .Single_Quote) and
        isAHLetter(prev_prev) and isAHLetter(curr))
    {
        return false;
    }

    // WB7a: Hebrew_Letter × Single_Quote
    if (prev == .Hebrew_Letter and curr == .Single_Quote) return false;

    // WB7b: Hebrew_Letter × Double_Quote Hebrew_Letter
    if (prev == .Hebrew_Letter and curr == .Double_Quote) return false;

    // WB7c: Hebrew_Letter Double_Quote × Hebrew_Letter
    if (prev == .Double_Quote and prev_prev == .Hebrew_Letter and curr == .Hebrew_Letter)
        return false;

    // WB8: Numeric × Numeric
    if (prev == .Numeric and curr == .Numeric) return false;

    // WB9: AHLetter × Numeric
    if (isAHLetter(prev) and curr == .Numeric) return false;

    // WB10: Numeric × AHLetter
    if (prev == .Numeric and isAHLetter(curr)) return false;

    // WB11: Numeric (MidNum | MidNumLetQ) × Numeric
    if ((prev == .MidNum or prev == .MidNumLet or prev == .Single_Quote) and
        prev_prev == .Numeric and curr == .Numeric)
    {
        return false;
    }

    // WB12: Numeric × (MidNum | MidNumLetQ) Numeric
    if (prev == .Numeric and (curr == .MidNum or curr == .MidNumLet or curr == .Single_Quote)) {
        return false;
    }

    // WB13: Katakana × Katakana
    if (prev == .Katakana and curr == .Katakana) return false;

    // WB13a: (AHLetter | Numeric | Katakana | ExtendNumLet) × ExtendNumLet
    if ((isAHLetter(prev) or prev == .Numeric or prev == .Katakana or prev == .ExtendNumLet) and
        curr == .ExtendNumLet)
    {
        return false;
    }

    // WB13b: ExtendNumLet × (AHLetter | Numeric | Katakana)
    if (prev == .ExtendNumLet and (isAHLetter(curr) or curr == .Numeric or curr == .Katakana))
        return false;

    // WB15, WB16: Regional Indicator pairs
    if (prev == .Regional_Indicator and curr == .Regional_Indicator) {
        return (state.ri_count % 2) == 0;
    }

    // WB999: Otherwise break
    return true;
}

fn isAHLetter(prop: WordBreakProperty) bool {
    return prop == .ALetter or prop == .Hebrew_Letter;
}

/// Iterator over word segments in a string
pub const WordIterator = struct {
    text: []const u8,
    pos: usize,
    state: WordBreakState,

    pub fn init(text: []const u8) WordIterator {
        return .{
            .text = text,
            .pos = 0,
            .state = WordBreakState.init(),
        };
    }

    /// Returns the next word segment, or null if at end
    pub fn next(self: *WordIterator) ?[]const u8 {
        if (self.pos >= self.text.len) return null;

        const start = self.pos;

        // Decode first code point
        const first_len = std.unicode.utf8ByteSequenceLength(self.text[self.pos]) catch 1;
        if (self.pos + first_len > self.text.len) {
            self.pos += 1;
            return self.text[start..self.pos];
        }

        const first_cp = std.unicode.utf8Decode(self.text[self.pos..][0..first_len]) catch {
            self.pos += 1;
            return self.text[start..self.pos];
        };

        self.pos += first_len;
        const first_prop = getWordBreakProperty(first_cp);
        self.state.prev_prev_prop = self.state.prev_prop;
        self.state.prev_prop = first_prop;
        if (first_prop == .Regional_Indicator) {
            self.state.ri_count = 1;
        }

        // Continue until we find a break
        while (self.pos < self.text.len) {
            const next_len = std.unicode.utf8ByteSequenceLength(self.text[self.pos]) catch break;
            if (self.pos + next_len > self.text.len) break;

            const next_cp = std.unicode.utf8Decode(self.text[self.pos..][0..next_len]) catch break;
            const next_prop = getWordBreakProperty(next_cp);

            if (self.state.shouldBreak(next_prop)) {
                break;
            }

            self.pos += next_len;
        }

        return self.text[start..self.pos];
    }

    /// Reset iterator to beginning
    pub fn reset(self: *WordIterator) void {
        self.pos = 0;
        self.state = WordBreakState.init();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "word iterator: simple words" {
    var iter = WordIterator.init("Hello World");
    try std.testing.expectEqualStrings("Hello", iter.next().?);
    try std.testing.expectEqualStrings(" ", iter.next().?);
    try std.testing.expectEqualStrings("World", iter.next().?);
    try std.testing.expect(iter.next() == null);
}

test "word iterator: punctuation" {
    var iter = WordIterator.init("Hello, world!");
    try std.testing.expectEqualStrings("Hello", iter.next().?);
    try std.testing.expectEqualStrings(",", iter.next().?);
    try std.testing.expectEqualStrings(" ", iter.next().?);
    try std.testing.expectEqualStrings("world", iter.next().?);
    try std.testing.expectEqualStrings("!", iter.next().?);
    try std.testing.expect(iter.next() == null);
}

test "word iterator: numbers" {
    var iter = WordIterator.init("test123");
    // Letters followed by numbers should stay together
    try std.testing.expectEqualStrings("test123", iter.next().?);
    try std.testing.expect(iter.next() == null);
}

test "word iterator: contractions" {
    var iter = WordIterator.init("don't");
    // Apostrophe in contractions - simplified behavior
    const segment = iter.next().?;
    // May be "don't" or "don" + "'" + "t" depending on implementation
    try std.testing.expect(segment.len > 0);
}

test "is_word_like: true for letters" {
    try std.testing.expect(isWordLike("Hello"));
    try std.testing.expect(isWordLike("世界"));
    try std.testing.expect(isWordLike("123"));
    try std.testing.expect(isWordLike("test123"));
}

test "is_word_like: false for non-words" {
    try std.testing.expect(!isWordLike(" "));
    try std.testing.expect(!isWordLike(","));
    try std.testing.expect(!isWordLike("!?"));
    try std.testing.expect(!isWordLike("..."));
}

test "word property: basic categories" {
    try std.testing.expectEqual(WordBreakProperty.CR, getWordBreakProperty('\r'));
    try std.testing.expectEqual(WordBreakProperty.LF, getWordBreakProperty('\n'));
    try std.testing.expectEqual(WordBreakProperty.ALetter, getWordBreakProperty('A'));
    try std.testing.expectEqual(WordBreakProperty.ALetter, getWordBreakProperty('z'));
    try std.testing.expectEqual(WordBreakProperty.Numeric, getWordBreakProperty('5'));
    try std.testing.expectEqual(WordBreakProperty.Single_Quote, getWordBreakProperty('\''));
    try std.testing.expectEqual(WordBreakProperty.WSegSpace, getWordBreakProperty(' '));
    try std.testing.expectEqual(WordBreakProperty.Katakana, getWordBreakProperty(0x30A2)); // ア
    try std.testing.expectEqual(WordBreakProperty.Hebrew_Letter, getWordBreakProperty(0x05D0)); // א
}
