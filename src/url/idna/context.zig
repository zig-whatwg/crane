//! Contextual Rules for IDNA
//!
//! Implements CONTEXTO and CONTEXTJ rules per RFC 5892.
//! CONTEXTJ: Zero Width Joiner (ZWJ) and Zero Width Non-Joiner (ZWNJ)
//! CONTEXTO: Middle Dot, Greek Numeral Sign, Hebrew Punctuation, etc.

const std = @import("std");
const infra = @import("infra");
const unicode_data = @import("unicode_data.zig");

pub const ContextError = error{
    InvalidContext,
};

/// Characters that require contextual rules
const MIDDLE_DOT: u21 = 0x00B7; // · (Catalan)
const ZERO_WIDTH_NON_JOINER: u21 = 0x200C; // ZWNJ
const ZERO_WIDTH_JOINER: u21 = 0x200D; // ZWJ
const GREEK_LOWER_NUMERAL_SIGN: u21 = 0x0375; // ʹ
const HEBREW_PUNCTUATION_GERESH: u21 = 0x05F3; // ׳
const HEBREW_PUNCTUATION_GERSHAYIM: u21 = 0x05F4; // ״
const KATAKANA_MIDDLE_DOT: u21 = 0x30FB; // ・
const ARABIC_INDIC_DIGIT_ZERO: u21 = 0x0660;
const EXTENDED_ARABIC_INDIC_DIGIT_ZERO: u21 = 0x06F0;

/// Virama combining class (Unicode Canonical_Combining_Class = 9)
const VIRAMA_COMBINING_CLASS: u8 = 9;

/// Check if a code point is in Arabic/Indic digit range
fn isArabicIndicDigit(cp: u21) bool {
    return (cp >= 0x0660 and cp <= 0x0669); // Arabic-Indic digits
}

fn isExtendedArabicIndicDigit(cp: u21) bool {
    return (cp >= 0x06F0 and cp <= 0x06F9); // Extended Arabic-Indic digits
}

/// Check if code point is a virama (combining class 9)
/// Virama characters are consonant killers/halants in Indic scripts
fn isVirama(cp: u21) bool {
    return unicode_data.lookupCombiningClass(cp) == VIRAMA_COMBINING_CLASS;
}

/// Check if code point is in Greek script (U+0370-U+03FF, U+1F00-U+1FFF)
fn isGreekScript(cp: u21) bool {
    return (cp >= 0x0370 and cp <= 0x03FF) or (cp >= 0x1F00 and cp <= 0x1FFF);
}

/// Check if code point is in Hebrew script (U+0590-U+05FF)
fn isHebrewScript(cp: u21) bool {
    return cp >= 0x0590 and cp <= 0x05FF;
}

/// Check if code point is Hiragana (U+3040-U+309F)
fn isHiragana(cp: u21) bool {
    return cp >= 0x3040 and cp <= 0x309F;
}

/// Check if code point is Katakana (U+30A0-U+30FF, U+31F0-U+31FF)
fn isKatakana(cp: u21) bool {
    return (cp >= 0x30A0 and cp <= 0x30FF) or (cp >= 0x31F0 and cp <= 0x31FF);
}

/// Check if code point is Han/CJK (major ranges)
fn isHan(cp: u21) bool {
    // CJK Unified Ideographs and extensions
    return (cp >= 0x4E00 and cp <= 0x9FFF) or // CJK Unified
        (cp >= 0x3400 and cp <= 0x4DBF) or // CJK Extension A
        (cp >= 0x20000 and cp <= 0x2A6DF) or // CJK Extension B
        (cp >= 0x2A700 and cp <= 0x2B73F) or // CJK Extension C
        (cp >= 0x2B740 and cp <= 0x2B81F) or // CJK Extension D
        (cp >= 0xF900 and cp <= 0xFAFF); // CJK Compatibility Ideographs
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
    // Bengali: U+0980-U+09FF
    if (cp >= 0x0980 and cp <= 0x09FF) return true;
    // Other Indic scripts with viramas
    if (cp >= 0x0A00 and cp <= 0x0A7F) return true; // Gurmukhi
    if (cp >= 0x0A80 and cp <= 0x0AFF) return true; // Gujarati
    if (cp >= 0x0B00 and cp <= 0x0B7F) return true; // Oriya
    if (cp >= 0x0B80 and cp <= 0x0BFF) return true; // Tamil
    if (cp >= 0x0C00 and cp <= 0x0C7F) return true; // Telugu
    if (cp >= 0x0C80 and cp <= 0x0CFF) return true; // Kannada
    if (cp >= 0x0D00 and cp <= 0x0D7F) return true; // Malayalam
    if (cp >= 0x0D80 and cp <= 0x0DFF) return true; // Sinhala
    return false;
}

/// Validate contextual rules for a label
pub fn validateContext(label: []const u8) !void {
    var codepoints = infra.List(u21).init(std.heap.page_allocator);
    defer codepoints.deinit();

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

        codepoints.append(cp) catch return;
        i += cp_len;
    }

    // Check context rules for each codepoint
    for (0..codepoints.len) |idx| {
        const cp = codepoints.get(idx).?;
        switch (cp) {
            // CONTEXTJ: Zero Width Non-Joiner (RFC 5892 Appendix A.1)
            // Rule: If Canonical_Combining_Class(Before(cp)) .eq. Virama Then True;
            // If RegExpMatch((Joining_Type:{L,D})(Joining_Type:T)*\u200C(Joining_Type:T)*(Joining_Type:{R,D})) Then True;
            ZERO_WIDTH_NON_JOINER => {
                if (idx == 0) return ContextError.InvalidContext;

                // Check if preceded by virama
                const prev_cp = codepoints.get(idx - 1).?;
                if (isVirama(prev_cp)) {
                    // Valid - virama before ZWNJ
                    continue;
                }

                // Otherwise, must be in joining context:
                // Look for joining character before (L or D type)
                var has_joiner_before = false;
                if (idx > 0) {
                    var j: usize = idx - 1;
                    while (true) {
                        const check_cp = codepoints.get(j).?;
                        if (isJoiningScript(check_cp)) {
                            has_joiner_before = true;
                            break;
                        }
                        if (j == 0) break;
                        j -= 1;
                    }
                }

                if (!has_joiner_before) return ContextError.InvalidContext;
            },

            // CONTEXTJ: Zero Width Joiner (RFC 5892 Appendix A.2)
            // Rule: If Canonical_Combining_Class(Before(cp)) .eq. Virama Then True;
            ZERO_WIDTH_JOINER => {
                if (idx == 0) return ContextError.InvalidContext;

                // ZWJ is valid ONLY if preceded by virama
                const prev_cp = codepoints.get(idx - 1).?;
                if (!isVirama(prev_cp)) {
                    return ContextError.InvalidContext;
                }
            },

            // CONTEXTO: Middle Dot (RFC 5892 Appendix A.3)
            // Rule: If Before(cp) .eq. U+006C And After(cp) .eq. U+006C Then True;
            MIDDLE_DOT => {
                if (idx == 0 or idx + 1 >= codepoints.len) {
                    return ContextError.InvalidContext;
                }
                // Must be strictly between 'l' (LATIN SMALL LETTER L)
                if (codepoints.get(idx - 1).? != 'l' or codepoints.get(idx + 1).? != 'l') {
                    return ContextError.InvalidContext;
                }
            },

            // CONTEXTO: Greek Lower Numeral Sign (RFC 5892 Appendix A.4)
            // Rule: If Script(After(cp)) .eq. Greek Then True;
            GREEK_LOWER_NUMERAL_SIGN => {
                if (idx + 1 >= codepoints.len) {
                    return ContextError.InvalidContext;
                }
                const next_cp = codepoints.get(idx + 1).?;
                if (!isGreekScript(next_cp)) {
                    return ContextError.InvalidContext;
                }
            },

            // CONTEXTO: Hebrew Punctuation Geresh (RFC 5892 Appendix A.5)
            // Rule: If Script(Before(cp)) .eq. Hebrew Then True;
            HEBREW_PUNCTUATION_GERESH => {
                if (idx == 0) return ContextError.InvalidContext;
                const prev_cp = codepoints.get(idx - 1).?;
                if (!isHebrewScript(prev_cp)) {
                    return ContextError.InvalidContext;
                }
            },

            // CONTEXTO: Hebrew Punctuation Gershayim (RFC 5892 Appendix A.6)
            // Rule: If Script(Before(cp)) .eq. Hebrew Then True;
            HEBREW_PUNCTUATION_GERSHAYIM => {
                if (idx == 0) return ContextError.InvalidContext;
                const prev_cp = codepoints.get(idx - 1).?;
                if (!isHebrewScript(prev_cp)) {
                    return ContextError.InvalidContext;
                }
            },

            // CONTEXTO: Katakana Middle Dot (RFC 5892 Appendix A.7)
            // Rule: For All Characters: If Script(cp) .in. {Hiragana, Katakana, Han} Then True;
            KATAKANA_MIDDLE_DOT => {
                // Label must contain at least one Hiragana, Katakana, or Han character
                var has_japanese = false;
                for (0..codepoints.len) |k| {
                    const check_cp = codepoints.get(k).?;
                    if (check_cp == KATAKANA_MIDDLE_DOT) continue;
                    if (isHiragana(check_cp) or isKatakana(check_cp) or isHan(check_cp)) {
                        has_japanese = true;
                        break;
                    }
                }
                if (!has_japanese) {
                    return ContextError.InvalidContext;
                }
            },

            // CONTEXTO: Arabic-Indic Digits (RFC 5892 Appendix A.8)
            // Rule: For All Characters: If cp .in. 06F0..06F9 Then False;
            ARABIC_INDIC_DIGIT_ZERO...0x0669 => {
                // Arabic-Indic digits cannot mix with Extended Arabic-Indic
                for (0..codepoints.len) |k| {
                    const other_cp = codepoints.get(k).?;
                    if (isExtendedArabicIndicDigit(other_cp)) {
                        return ContextError.InvalidContext;
                    }
                }
            },

            // CONTEXTO: Extended Arabic-Indic Digits (RFC 5892 Appendix A.9)
            // Rule: For All Characters: If cp .in. 0660..0669 Then False;
            EXTENDED_ARABIC_INDIC_DIGIT_ZERO...0x06F9 => {
                // Extended Arabic-Indic digits cannot mix with Arabic-Indic
                for (0..codepoints.len) |k| {
                    const other_cp = codepoints.get(k).?;
                    if (isArabicIndicDigit(other_cp)) {
                        return ContextError.InvalidContext;
                    }
                }
            },
            else => {},
        }
    }
}
