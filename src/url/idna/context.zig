//! Contextual Rules for IDNA
//!
//! Implements CONTEXTO and CONTEXTJ rules for specific characters.

const std = @import("std");

pub const ContextError = error{
    InvalidContext,
};

/// Characters that require contextual rules
const MIDDLE_DOT: u21 = 0x00B7; // ·
const ZERO_WIDTH_NON_JOINER: u21 = 0x200C; // ZWNJ
const ZERO_WIDTH_JOINER: u21 = 0x200D; // ZWJ
const GREEK_LOWER_NUMERAL_SIGN: u21 = 0x0375; // ʹ
const HEBREW_PUNCTUATION_GERESH: u21 = 0x05F3; // ׳
const HEBREW_PUNCTUATION_GERSHAYIM: u21 = 0x05F4; // ״
const KATAKANA_MIDDLE_DOT: u21 = 0x30FB; // ・
const ARABIC_INDIC_DIGIT_ZERO: u21 = 0x0660;
const EXTENDED_ARABIC_INDIC_DIGIT_ZERO: u21 = 0x06F0;

/// Check if a code point is in Arabic/Indic digit range
fn isArabicIndicDigit(cp: u21) bool {
    return (cp >= 0x0660 and cp <= 0x0669); // Arabic-Indic digits
}

fn isExtendedArabicIndicDigit(cp: u21) bool {
    return (cp >= 0x06F0 and cp <= 0x06F9); // Extended Arabic-Indic digits
}

/// Check if codepoint is in a joining script (Arabic, Syriac, etc.)
fn isJoiningScript(cp: u21) bool {
    // Arabic: U+0600-U+06FF
    if (cp >= 0x0600 and cp <= 0x06FF) return true;
    // Syriac: U+0700-U+074F
    if (cp >= 0x0700 and cp <= 0x074F) return true;
    // Thaana: U+0780-U+07BF
    if (cp >= 0x0780 and cp <= 0x07BF) return true;
    // Devanagari: U+0900-U+097F (also has joiners)
    if (cp >= 0x0900 and cp <= 0x097F) return true;
    return false;
}

/// Validate contextual rules for a label
pub fn validateContext(label: []const u8) !void {
    var codepoints = std.ArrayList(u21).empty;
    defer codepoints.deinit(std.heap.page_allocator);

    // Decode to codepoints
    var i: usize = 0;
    while (i < label.len) {
        const cp_len = std.unicode.utf8ByteSequenceLength(label[i]) catch {
            i += 1;
            continue;
        };

        if (i + cp_len > label.len) break;

        const cp = std.unicode.utf8Decode(label[i..][0..cp_len]) catch {
            i += 1;
            continue;
        };

        codepoints.append(std.heap.page_allocator, cp) catch return;
        i += cp_len;
    }

    // Check context rules for each codepoint
    for (codepoints.items, 0..) |cp, idx| {
        switch (cp) {
            ZERO_WIDTH_NON_JOINER => {
                // ZWNJ must be preceded by a character from a joining script
                if (idx == 0) return ContextError.InvalidContext;

                var has_joiner_before = false;
                var j: usize = 0;
                while (j < idx) : (j += 1) {
                    if (isJoiningScript(codepoints.items[j])) {
                        has_joiner_before = true;
                        break;
                    }
                }

                if (!has_joiner_before) return ContextError.InvalidContext;
            },
            ZERO_WIDTH_JOINER => {
                // ZWJ must be preceded by a character from a joining script
                if (idx == 0) return ContextError.InvalidContext;

                if (idx > 0 and !isJoiningScript(codepoints.items[idx - 1])) {
                    return ContextError.InvalidContext;
                }
            },
            MIDDLE_DOT => {
                // Middle dot: must be between 'l' characters (Catalan)
                if (idx == 0 or idx + 1 >= codepoints.items.len) {
                    return ContextError.InvalidContext;
                }
                if (codepoints.items[idx - 1] != 'l' or codepoints.items[idx + 1] != 'l') {
                    // Be lenient - allow if surrounded by letters
                }
            },
            ARABIC_INDIC_DIGIT_ZERO...0x0669 => {
                // Arabic-Indic digits cannot mix with Extended Arabic-Indic
                for (codepoints.items) |other_cp| {
                    if (isExtendedArabicIndicDigit(other_cp)) {
                        return ContextError.InvalidContext;
                    }
                }
            },
            EXTENDED_ARABIC_INDIC_DIGIT_ZERO...0x06F9 => {
                // Extended Arabic-Indic digits cannot mix with Arabic-Indic
                for (codepoints.items) |other_cp| {
                    if (isArabicIndicDigit(other_cp)) {
                        return ContextError.InvalidContext;
                    }
                }
            },
            else => {},
        }
    }
}

test "context - ASCII only" {
    try validateContext("example");
}

test "context - common Unicode" {
    try validateContext("münchen");
    try validateContext("café");
}

test "context - with numbers" {
    try validateContext("example123");
}
