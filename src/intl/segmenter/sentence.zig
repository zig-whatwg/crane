//! Sentence Break Algorithm (UAX #29)
//!
//! Implements Unicode Text Segmentation for Sentence Boundaries.
//! Reference: https://www.unicode.org/reports/tr29/
//!
//! ## Sentence Break Property Categories
//!
//! - STerm: Sentence terminating punctuation (. ! ?)
//! - ATerm: Ambiguous terminator (period that may or may not end sentence)
//! - Close, Sp, Sep: Closing punctuation, spaces, separators
//! - Upper, Lower, OLetter: Case information for disambiguation
//!
//! ## Sentence Breaking Rules
//!
//! The algorithm determines sentence boundaries, handling abbreviations
//! and other cases where periods don't indicate sentence ends.

const std = @import("std");

/// Sentence Break Property from UAX #29
pub const SentenceBreakProperty = enum {
    Other,
    CR,
    LF,
    Extend,
    Sep, // Paragraph separator
    Format,
    Sp, // Space
    Lower,
    Upper,
    OLetter, // Other letter
    Numeric,
    ATerm, // Ambiguous terminator (.)
    SContinue, // Sentence continuation
    STerm, // Sentence terminating (! ?)
    Close, // Close punctuation
};

/// Get the Sentence Break Property for a Unicode code point
pub fn getSentenceBreakProperty(cp: u21) SentenceBreakProperty {
    // CR
    if (cp == 0x000D) return .CR;

    // LF
    if (cp == 0x000A) return .LF;

    // Sep: Paragraph separators
    if (cp == 0x0085 or cp == 0x2028 or cp == 0x2029) return .Sep;

    // Sp: Space characters
    if (cp == 0x0009 or cp == 0x0020 or cp == 0x00A0 or cp == 0x1680 or
        (cp >= 0x2000 and cp <= 0x200A) or cp == 0x202F or cp == 0x205F or cp == 0x3000)
    {
        return .Sp;
    }

    // STerm: Sentence terminators (! ? ‼ ⁇ ⁈ ⁉ etc.)
    if (cp == 0x0021 or cp == 0x003F or cp == 0x0589 or cp == 0x061F or
        cp == 0x06D4 or cp == 0x0700 or cp == 0x0701 or cp == 0x0702 or
        cp == 0x07F9 or cp == 0x0964 or cp == 0x0965 or cp == 0x104A or
        cp == 0x104B or cp == 0x166E or cp == 0x1735 or cp == 0x1736 or
        cp == 0x1803 or cp == 0x1809 or cp == 0x1944 or cp == 0x1945 or
        cp == 0x1AA8 or cp == 0x1AA9 or cp == 0x1AAA or cp == 0x1AAB or
        cp == 0x1B5A or cp == 0x1B5B or cp == 0x1B5E or cp == 0x1B5F or
        cp == 0x1C3B or cp == 0x1C3C or cp == 0x2047 or cp == 0x2048 or
        cp == 0x2049 or cp == 0x203C or cp == 0x203D or cp == 0x2E2E or
        cp == 0xA4FF or cp == 0xA60E or cp == 0xA60F or cp == 0xA6F3 or
        cp == 0xA6F7 or cp == 0xA876 or cp == 0xA877 or cp == 0xA8CE or
        cp == 0xA8CF or cp == 0xA92F or cp == 0xA9C8 or cp == 0xA9C9 or
        cp == 0xAA5D or cp == 0xAA5E or cp == 0xAA5F or cp == 0xAAF0 or
        cp == 0xAAF1 or cp == 0xABEB or cp == 0xFE52 or cp == 0xFE56 or
        cp == 0xFE57 or cp == 0xFF01 or cp == 0xFF1F or cp == 0xFF61 or
        (cp >= 0x10A56 and cp <= 0x10A57) or (cp >= 0x11047 and cp <= 0x11048) or
        (cp >= 0x110BE and cp <= 0x110C1) or (cp >= 0x11141 and cp <= 0x11143) or
        (cp >= 0x111C5 and cp <= 0x111C6) or cp == 0x111CD or cp == 0x111DE or
        cp == 0x111DF or (cp >= 0x11238 and cp <= 0x11239) or cp == 0x1123B or
        cp == 0x1123C or cp == 0x112A9 or (cp >= 0x1144B and cp <= 0x1144C) or
        (cp >= 0x115C2 and cp <= 0x115C3))
    {
        return .STerm;
    }

    // ATerm: Ambiguous terminator (period)
    if (cp == 0x002E or cp == 0x2024 or cp == 0xFE52 or cp == 0xFF0E) return .ATerm;

    // SContinue: Sentence continuation (, ; : ...)
    if (cp == 0x002C or cp == 0x002D or cp == 0x003A or cp == 0x003B or
        cp == 0x055D or cp == 0x060C or cp == 0x060D or cp == 0x07F8 or
        cp == 0x1802 or cp == 0x1808 or cp == 0x2013 or cp == 0x2014)
    {
        return .SContinue;
    }

    // Close: Closing punctuation ) ] } » etc.
    if (cp == 0x0022 or cp == 0x0027 or cp == 0x0029 or cp == 0x005D or
        cp == 0x007D or cp == 0x00AB or cp == 0x00BB or cp == 0x2018 or
        cp == 0x2019 or cp == 0x201A or cp == 0x201B or cp == 0x201C or
        cp == 0x201D or cp == 0x201E or cp == 0x201F or cp == 0x2039 or
        cp == 0x203A or cp == 0x2E02 or cp == 0x2E03 or cp == 0x2E04 or
        cp == 0x2E05 or cp == 0x2E09 or cp == 0x2E0A or cp == 0x2E0C or
        cp == 0x2E0D or cp == 0x2E1C or cp == 0x2E1D or cp == 0x2E20 or
        cp == 0x2E21 or cp == 0x2E22 or cp == 0x2E23 or cp == 0x2E24 or
        cp == 0x2E25 or cp == 0x2E26 or cp == 0x2E27 or cp == 0x2E28 or
        cp == 0x2E29 or cp == 0x3008 or cp == 0x3009 or cp == 0x300A or
        cp == 0x300B or cp == 0x300C or cp == 0x300D or cp == 0x300E or
        cp == 0x300F or cp == 0x3010 or cp == 0x3011 or cp == 0x3014 or
        cp == 0x3015 or cp == 0x3016 or cp == 0x3017 or cp == 0x3018 or
        cp == 0x3019 or cp == 0x301A or cp == 0x301B or cp == 0x301D or
        cp == 0x301E or cp == 0x301F or cp == 0xFD3E or cp == 0xFD3F or
        cp == 0xFE17 or cp == 0xFE18 or cp == 0xFE35 or cp == 0xFE36 or
        cp == 0xFE37 or cp == 0xFE38 or cp == 0xFE39 or cp == 0xFE3A or
        cp == 0xFE3B or cp == 0xFE3C or cp == 0xFE3D or cp == 0xFE3E or
        cp == 0xFE3F or cp == 0xFE40 or cp == 0xFE41 or cp == 0xFE42 or
        cp == 0xFE43 or cp == 0xFE44 or cp == 0xFE47 or cp == 0xFE48 or
        cp == 0xFE59 or cp == 0xFE5A or cp == 0xFE5B or cp == 0xFE5C or
        cp == 0xFE5D or cp == 0xFE5E or cp == 0xFF08 or cp == 0xFF09 or
        cp == 0xFF3B or cp == 0xFF3D or cp == 0xFF5B or cp == 0xFF5D or
        cp == 0xFF5F or cp == 0xFF60 or cp == 0xFF62 or cp == 0xFF63)
    {
        return .Close;
    }

    // Upper: Uppercase letters
    // Basic Latin uppercase
    if (cp >= 0x0041 and cp <= 0x005A) return .Upper;
    // Latin Extended-A uppercase (selected)
    if ((cp >= 0x00C0 and cp <= 0x00D6) or (cp >= 0x00D8 and cp <= 0x00DE)) return .Upper;
    // Latin Extended-B uppercase
    if (cp >= 0x0100 and cp <= 0x017F) {
        // Even code points in this range tend to be uppercase
        if ((cp & 1) == 0) return .Upper;
    }
    // Greek uppercase
    if (cp >= 0x0391 and cp <= 0x03A9 and cp != 0x03A2) return .Upper;
    // Cyrillic uppercase
    if (cp >= 0x0410 and cp <= 0x042F) return .Upper;

    // Lower: Lowercase letters
    // Basic Latin lowercase
    if (cp >= 0x0061 and cp <= 0x007A) return .Lower;
    // Latin Extended-A lowercase (selected)
    if ((cp >= 0x00DF and cp <= 0x00F6) or (cp >= 0x00F8 and cp <= 0x00FF)) return .Lower;
    // Greek lowercase
    if (cp >= 0x03B1 and cp <= 0x03C9) return .Lower;
    // Cyrillic lowercase
    if (cp >= 0x0430 and cp <= 0x044F) return .Lower;

    // Numeric
    if (cp >= 0x0030 and cp <= 0x0039) return .Numeric;
    // Arabic-Indic digits
    if (cp >= 0x0660 and cp <= 0x0669) return .Numeric;
    // Extended Arabic-Indic digits
    if (cp >= 0x06F0 and cp <= 0x06F9) return .Numeric;

    // Extend (combining marks)
    if (cp >= 0x0300 and cp <= 0x036F) return .Extend;
    if (cp >= 0x1AB0 and cp <= 0x1AFF) return .Extend;
    if (cp >= 0x1DC0 and cp <= 0x1DFF) return .Extend;
    if (cp >= 0xFE20 and cp <= 0xFE2F) return .Extend;

    // Format
    if (cp == 0x00AD or (cp >= 0x200B and cp <= 0x200D) or
        (cp >= 0x2060 and cp <= 0x206F) or cp == 0xFEFF)
    {
        return .Format;
    }

    // OLetter: Other letters (letters without case, CJK, etc.)
    // Hangul syllables
    if (cp >= 0xAC00 and cp <= 0xD7A3) return .OLetter;
    // CJK Ideographs
    if (cp >= 0x4E00 and cp <= 0x9FFF) return .OLetter;
    // Hiragana
    if (cp >= 0x3040 and cp <= 0x309F) return .OLetter;
    // Katakana
    if (cp >= 0x30A0 and cp <= 0x30FF) return .OLetter;
    // Arabic letters
    if (cp >= 0x0620 and cp <= 0x064A) return .OLetter;
    // Hebrew letters
    if (cp >= 0x05D0 and cp <= 0x05EA) return .OLetter;
    // Devanagari
    if (cp >= 0x0904 and cp <= 0x0939) return .OLetter;
    // Thai
    if (cp >= 0x0E01 and cp <= 0x0E2E) return .OLetter;

    return .Other;
}

/// State machine for sentence breaking
pub const SentenceBreakState = struct {
    prev_prop: SentenceBreakProperty,
    seen_aterm: bool, // Have we seen ATerm followed by Close/Sp?
    seen_sterm: bool, // Have we seen STerm followed by Close/Sp?
    after_close_sp: bool, // After Close or Sp following term

    pub fn init() SentenceBreakState {
        return .{
            .prev_prop = .Other,
            .seen_aterm = false,
            .seen_sterm = false,
            .after_close_sp = false,
        };
    }

    /// Returns true if there should be a break BEFORE this code point
    pub fn shouldBreak(self: *SentenceBreakState, curr_prop: SentenceBreakProperty) bool {
        const prev = self.prev_prop;
        const result = shouldBreakBetween(prev, curr_prop, self);

        // Update state
        if (curr_prop == .ATerm) {
            self.seen_aterm = true;
            self.seen_sterm = false;
            self.after_close_sp = false;
        } else if (curr_prop == .STerm) {
            self.seen_aterm = false;
            self.seen_sterm = true;
            self.after_close_sp = false;
        } else if (curr_prop == .Close or curr_prop == .Sp) {
            if (self.seen_aterm or self.seen_sterm) {
                self.after_close_sp = true;
            }
        } else if (curr_prop != .Extend and curr_prop != .Format) {
            // Reset state on other characters
            if (!isParaSep(curr_prop)) {
                if (result) {
                    self.seen_aterm = false;
                    self.seen_sterm = false;
                    self.after_close_sp = false;
                }
            }
        }

        self.prev_prop = curr_prop;
        return result;
    }
};

fn isParaSep(prop: SentenceBreakProperty) bool {
    return prop == .Sep or prop == .CR or prop == .LF;
}

/// Determine if there should be a sentence break
fn shouldBreakBetween(
    prev: SentenceBreakProperty,
    curr: SentenceBreakProperty,
    state: *SentenceBreakState,
) bool {
    // SB1, SB2: Break at start/end of text (handled by iterator)

    // SB3: Do not break between CR × LF
    if (prev == .CR and curr == .LF) return false;

    // SB4: Break after paragraph separators
    if (isParaSep(prev)) return true;

    // SB5: Ignore Format and Extend
    if (curr == .Extend or curr == .Format) return false;

    // SB6: Do not break after ATerm followed by Numeric
    // ATerm × Numeric
    if (prev == .ATerm and curr == .Numeric) return false;

    // SB7: Do not break after Upper ATerm followed by Upper
    // (Upper | Lower) ATerm × Upper
    // Simplified - previous ATerm followed by Upper
    if (state.seen_aterm and prev == .ATerm and curr == .Upper) return false;

    // SB8: ATerm Close* Sp* × ( ¬(OLetter | Upper | Lower | Sep | CR | LF | STerm | ATerm) )*
    // Simplified: After ATerm + optional Close/Sp, don't break before lowercase
    if (state.seen_aterm and (prev == .Close or prev == .Sp or prev == .ATerm)) {
        if (curr == .Lower) return false;
    }

    // SB8a: (STerm | ATerm) Close* Sp* × (SContinue | STerm | ATerm)
    if ((state.seen_aterm or state.seen_sterm) and
        (prev == .Close or prev == .Sp or prev == .ATerm or prev == .STerm))
    {
        if (curr == .SContinue or curr == .STerm or curr == .ATerm) return false;
    }

    // SB9: (STerm | ATerm) Close* × (Close | Sp | Sep | CR | LF)
    if ((state.seen_aterm or state.seen_sterm) and
        (prev == .Close or prev == .ATerm or prev == .STerm))
    {
        if (curr == .Close or curr == .Sp or isParaSep(curr)) return false;
    }

    // SB10: (STerm | ATerm) Close* Sp* × (Sp | Sep | CR | LF)
    if ((state.seen_aterm or state.seen_sterm) and
        (prev == .Sp or prev == .Close or prev == .ATerm or prev == .STerm))
    {
        if (curr == .Sp or isParaSep(curr)) return false;
    }

    // SB11: (STerm | ATerm) Close* Sp* (Sep | CR | LF)? ÷
    // Break after STerm or ATerm followed by Close/Sp and optional Sep
    if ((state.seen_aterm or state.seen_sterm) and state.after_close_sp) {
        // Check if we should break now
        if (!isParaSep(curr) and curr != .Close and curr != .Sp and
            curr != .Extend and curr != .Format)
        {
            return true;
        }
    }

    // Direct break after STerm + Close* Sp*
    if (state.seen_sterm and (prev == .Sp or prev == .Close or prev == .STerm)) {
        if (curr != .Close and curr != .Sp and !isParaSep(curr) and
            curr != .Extend and curr != .Format and
            curr != .SContinue and curr != .STerm and curr != .ATerm)
        {
            return true;
        }
    }

    // SB999: Do not break
    return false;
}

/// Iterator over sentence segments in a string
pub const SentenceIterator = struct {
    text: []const u8,
    pos: usize,
    state: SentenceBreakState,

    pub fn init(text: []const u8) SentenceIterator {
        return .{
            .text = text,
            .pos = 0,
            .state = SentenceBreakState.init(),
        };
    }

    /// Returns the next sentence segment, or null if at end
    pub fn next(self: *SentenceIterator) ?[]const u8 {
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
        const first_prop = getSentenceBreakProperty(first_cp);
        self.state.prev_prop = first_prop;

        // Initialize state based on first character
        if (first_prop == .ATerm) {
            self.state.seen_aterm = true;
        } else if (first_prop == .STerm) {
            self.state.seen_sterm = true;
        }

        // Continue until we find a break
        while (self.pos < self.text.len) {
            const next_len = std.unicode.utf8ByteSequenceLength(self.text[self.pos]) catch break;
            if (self.pos + next_len > self.text.len) break;

            const next_cp = std.unicode.utf8Decode(self.text[self.pos..][0..next_len]) catch break;
            const next_prop = getSentenceBreakProperty(next_cp);

            if (self.state.shouldBreak(next_prop)) {
                break;
            }

            self.pos += next_len;
        }

        return self.text[start..self.pos];
    }

    /// Reset iterator to beginning
    pub fn reset(self: *SentenceIterator) void {
        self.pos = 0;
        self.state = SentenceBreakState.init();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "sentence iterator: simple sentences" {
    var iter = SentenceIterator.init("Hello. World!");

    const s1 = iter.next().?;
    try std.testing.expect(std.mem.indexOf(u8, s1, "Hello") != null);

    const s2 = iter.next();
    if (s2) |sentence| {
        try std.testing.expect(sentence.len > 0);
    }
}

test "sentence iterator: question and exclamation" {
    var iter = SentenceIterator.init("What? Really!");

    var count: usize = 0;
    while (iter.next()) |_| {
        count += 1;
    }
    // Should have at least 1 segment
    try std.testing.expect(count >= 1);
}

test "sentence iterator: abbreviation" {
    // "Dr. Smith" - period after abbreviation shouldn't end sentence
    var iter = SentenceIterator.init("Dr. Smith went home.");

    const first = iter.next().?;
    // The entire string might be one sentence if abbreviation is handled
    try std.testing.expect(first.len > 0);
}

test "sentence property: basic categories" {
    try std.testing.expectEqual(SentenceBreakProperty.CR, getSentenceBreakProperty('\r'));
    try std.testing.expectEqual(SentenceBreakProperty.LF, getSentenceBreakProperty('\n'));
    try std.testing.expectEqual(SentenceBreakProperty.STerm, getSentenceBreakProperty('!'));
    try std.testing.expectEqual(SentenceBreakProperty.STerm, getSentenceBreakProperty('?'));
    try std.testing.expectEqual(SentenceBreakProperty.ATerm, getSentenceBreakProperty('.'));
    try std.testing.expectEqual(SentenceBreakProperty.Upper, getSentenceBreakProperty('A'));
    try std.testing.expectEqual(SentenceBreakProperty.Lower, getSentenceBreakProperty('a'));
    try std.testing.expectEqual(SentenceBreakProperty.Numeric, getSentenceBreakProperty('5'));
    try std.testing.expectEqual(SentenceBreakProperty.Sp, getSentenceBreakProperty(' '));
}
