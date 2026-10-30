//! Shared word movement over borrowed WTF-8 text and UTF-16 offsets.
//! Segmentation comes from the Unicode/ICU-tailored WordIterator. Movement
//! keeps Crane's next-word-start platform convention (row129 Q15/Q16).
const std = @import("std");
const infra = @import("infra");
const word = @import("intl").segmenter.word;

const SegmentKind = enum { word, separator, space, symbols };

/// Q15's next-start convention uses the same stops in both directions.
/// Q32/Q33 (Chrome/Firefox, 2026-10-27): only the FIRST character decides
/// whether a whitespace segment's start is a stop. A WB3d group beginning
/// with ASCII space is skipped even if it contains EM SPACE; never split
/// it internally. NNBSP stays in a word through the shared iterator.
fn segmentKind(segment: []const u8) SegmentKind {
    if (word.isWordLike(segment)) return .word;
    const len = std.unicode.utf8ByteSequenceLength(segment[0]) catch return .symbols;
    if (len > segment.len) return .symbols;
    const cp = std.unicode.utf8Decode(segment[0..len]) catch return .symbols;
    // Figure space is Zs but Word_Break=Other because it is Glue. Q32's
    // browser probe makes it a stop, while NBSP is skipped.
    if ((word.getWordBreakProperty(cp) == .WSegSpace and cp != ' ') or cp == 0x2007) return .space;
    // Keep the existing ASCII punctuation and line-break movement policy.
    if (cp == 0x00A0 or (cp < 0x80 and (std.ascii.isWhitespace(@intCast(cp)) or
        std.mem.indexOfScalar(u8, ".,!?;:\"'()[]{}-/", @intCast(cp)) != null))) return .separator;
    return .symbols;
}

pub fn move(text: []const u8, offset: u32, forward: bool) u32 {
    const at = infra.wtf8.positionOfCodeUnit(text, offset);
    var iterator = word.WordIterator.init(text);
    if (forward) {
        // Consume the current word (or contiguous symbol run), then the
        // separators up to the next word's start. A symbol run can itself
        // be the next word; e.g. "ab 😀😀 end" from zero advances to three.
        var phase: enum { initial, symbols, after_word } = .initial;
        while (iterator.next()) |segment| {
            const end = iterator.pos;
            const start = end - segment.len;
            if (end <= at.byte) continue;
            const kind = segmentKind(segment);
            if (phase == .initial) {
                phase = if (kind == .symbols) .symbols else .after_word;
                continue;
            }
            if (phase == .symbols and kind == .symbols) continue;
            phase = .after_word;
            if (kind != .separator) return @as(u32, @intCast(infra.wtf8.codeUnitLength(text[0..start])));
        }
        return @as(u32, @intCast(infra.wtf8.codeUnitLength(text)));
    }
    var preceding: usize = 0;
    var symbols: ?usize = null;
    while (iterator.next()) |segment| {
        const end = iterator.pos;
        const start = end - segment.len;
        // Include the code point containing the high half before a
        // mid-surrogate offset. Its byte position is at.byte, not past it.
        if (start > at.byte or (start == at.byte and !at.mid_pair)) break;
        const kind = segmentKind(segment);
        if (kind == .word or kind == .space) {
            preceding = start;
            symbols = null;
        } else if (kind == .separator) {
            symbols = null;
        } else {
            if (symbols == null) symbols = start;
            preceding = symbols.?;
        }
    }
    return @as(u32, @intCast(infra.wtf8.codeUnitLength(text[0..preceding])));
}
