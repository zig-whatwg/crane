//! WHATWG MIME Sniffing - Pattern Matching
//!
//! Spec: https://mimesniff.spec.whatwg.org/#matching-a-mime-type-pattern
//!
//! This module implements byte pattern matching algorithms for content sniffing,
//! including comptime pattern tables and SIMD-optimized matching.

const std = @import("std");
const mime_type_mod = @import("mime_type.zig");
const MimeType = mime_type_mod.MimeType;
const mime_constants = @import("mime_constants.zig");

/// Pattern definition (comptime-known)
pub const Pattern = struct {
    pattern: []const u8,
    mask: []const u8,
    ignored: []const u8,
    mime_type: *const MimeType,
};

/// Pattern matching algorithm (WHATWG MIME Sniffing §4)
///
/// To determine whether a byte sequence matches a particular byte pattern,
/// use this algorithm. It is given:
/// - input: byte sequence to match
/// - pattern: byte pattern (template)
/// - mask: pattern mask (0xFF = exact, 0xDF = case-insensitive, 0x00 = wildcard)
/// - ignored: set of bytes to skip at start of input
///
/// Returns true if input matches pattern.
///
/// Spec: https://mimesniff.spec.whatwg.org/#pattern-matching-algorithm
pub fn patternMatching(
    input: []const u8,
    pattern: []const u8,
    mask: []const u8,
    ignored: []const u8,
) bool {
    // 1. Assert: pattern's length is equal to mask's length
    std.debug.assert(pattern.len == mask.len);

    // 2. If input's length is less than pattern's length, return false
    if (input.len < pattern.len)
        return false;

    // 3. Let s be 0
    var s: usize = 0;

    // 4. While s < input's length
    while (s < input.len) {
        // 4.1. If ignored does not contain input[s], break
        if (!std.mem.containsAtLeast(u8, ignored, 1, &[_]u8{input[s]}))
            break;

        // 4.2. Set s to s + 1
        s += 1;
    }

    // 5. Let p be 0
    var p: usize = 0;

    // 6. While p < pattern's length
    while (p < pattern.len) {
        // Check bounds
        if (s >= input.len)
            return false;

        // 6.1. Let maskedData be the result of applying bitwise AND to input[s] and mask[p]
        const masked_data = input[s] & mask[p];

        // 6.2. If maskedData is not equal to pattern[p], return false
        if (masked_data != pattern[p])
            return false;

        // 6.3. Set s to s + 1
        s += 1;

        // 6.4. Set p to p + 1
        p += 1;
    }

    // 7. Return true
    return true;
}

/// SIMD-optimized pattern matching for long patterns (16+ bytes)
///
/// Uses @Vector for portable SIMD acceleration.
/// Falls back to scalar matching for patterns < 16 bytes.
pub fn patternMatchingSIMD(
    input: []const u8,
    pattern: []const u8,
    mask: []const u8,
    ignored: []const u8,
) bool {
    // For short patterns, use scalar version
    if (pattern.len < 16) {
        return patternMatching(input, pattern, mask, ignored);
    }

    // Skip ignored bytes
    var s: usize = 0;
    while (s < input.len and std.mem.containsAtLeast(u8, ignored, 1, &[_]u8{input[s]})) {
        s += 1;
    }

    // Check if we have enough input left
    if (input.len - s < pattern.len)
        return false;

    // Match first 16 bytes with SIMD
    const Vec16 = @Vector(16, u8);

    const in: Vec16 = input[s..][0..16].*;
    const pat: Vec16 = pattern[0..16].*;
    const msk: Vec16 = mask[0..16].*;

    // Apply mask: (input & mask) == (pattern & mask)
    const in_masked = in & msk;
    const pat_masked = pat & msk;
    const cmp = in_masked == pat_masked;

    // All 16 bytes must match
    if (!@reduce(.And, cmp))
        return false;

    // Match remaining bytes with scalar
    s += 16;
    var p: usize = 16;
    while (p < pattern.len) {
        if (s >= input.len)
            return false;

        const masked_data = input[s] & mask[p];
        if (masked_data != pattern[p])
            return false;

        s += 1;
        p += 1;
    }

    return true;
}

// ============================================================================
// Image Patterns (WHATWG MIME Sniffing §4.1)
// ============================================================================

/// Image patterns (comptime constant)
///
/// Spec: https://mimesniff.spec.whatwg.org/#matching-an-image-type-pattern
pub const IMAGE_PATTERNS = [_]Pattern{
    // Windows Icon: 00 00 01 00
    .{
        .pattern = &[_]u8{ 0x00, 0x00, 0x01, 0x00 },
        .mask = &[_]u8{ 0xFF, 0xFF, 0xFF, 0xFF },
        .ignored = &[_]u8{},
        .mime_type = &mime_constants.IMAGE_ICON,
    },

    // Windows Cursor: 00 00 02 00
    .{
        .pattern = &[_]u8{ 0x00, 0x00, 0x02, 0x00 },
        .mask = &[_]u8{ 0xFF, 0xFF, 0xFF, 0xFF },
        .ignored = &[_]u8{},
        .mime_type = &mime_constants.IMAGE_ICON,
    },

    // BMP: "BM"
    .{
        .pattern = "BM",
        .mask = &[_]u8{ 0xFF, 0xFF },
        .ignored = &[_]u8{},
        .mime_type = &mime_constants.IMAGE_BMP,
    },

    // GIF87a
    .{
        .pattern = "GIF87a",
        .mask = &[_]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
        .ignored = &[_]u8{},
        .mime_type = &mime_constants.IMAGE_GIF,
    },

    // GIF89a
    .{
        .pattern = "GIF89a",
        .mask = &[_]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
        .ignored = &[_]u8{},
        .mime_type = &mime_constants.IMAGE_GIF,
    },

    // WebP: RIFF????WEBPVP
    .{
        .pattern = "RIFF\x00\x00\x00\x00WEBPVP",
        .mask = &[_]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
        .ignored = &[_]u8{},
        .mime_type = &mime_constants.IMAGE_WEBP,
    },

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    .{
        .pattern = &[_]u8{ 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A },
        .mask = &[_]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
        .ignored = &[_]u8{},
        .mime_type = &mime_constants.IMAGE_PNG,
    },

    // JPEG: FF D8 FF
    .{
        .pattern = &[_]u8{ 0xFF, 0xD8, 0xFF },
        .mask = &[_]u8{ 0xFF, 0xFF, 0xFF },
        .ignored = &[_]u8{},
        .mime_type = &mime_constants.IMAGE_JPEG,
    },
};

/// Dispatch entry: stores indices of patterns with same first byte
pub const DispatchEntry = struct {
    indices: [8]usize = [_]usize{0xFF} ** 8, // Max 8 patterns per byte, 0xFF = unused
    count: usize = 0,
};

/// First-byte dispatch table for images (comptime-generated)
///
/// Maps first byte → indices into IMAGE_PATTERNS array.
/// Enables O(1) rejection of impossible patterns (Chromium-style).
pub const IMAGE_FIRST_BYTE_DISPATCH = buildImageDispatchTable();

fn buildImageDispatchTable() [256]DispatchEntry {
    @setEvalBranchQuota(10000);

    var table = [_]DispatchEntry{.{}} ** 256;

    // Build dispatch table
    for (IMAGE_PATTERNS, 0..) |pattern, idx| {
        const first_byte = pattern.pattern[0];
        const entry = &table[first_byte];

        // Add index to entry
        entry.indices[entry.count] = idx;
        entry.count += 1;
    }

    return table;
}

/// Match image type pattern (with first-byte dispatch)
///
/// Returns MimeType constant if matched, null otherwise.
///
/// Spec: https://mimesniff.spec.whatwg.org/#matching-an-image-type-pattern
pub fn matchImageTypePattern(input: []const u8) ?MimeType {
    if (input.len == 0)
        return null;

    // O(1) first-byte dispatch
    const first_byte = input[0];
    const entry = IMAGE_FIRST_BYTE_DISPATCH[first_byte];

    // Test each candidate pattern
    var i: usize = 0;
    while (i < entry.count) : (i += 1) {
        const idx = entry.indices[i];
        const pattern = IMAGE_PATTERNS[idx];

        if (patternMatching(input, pattern.pattern, pattern.mask, pattern.ignored)) {
            return pattern.mime_type.*;
        }
    }

    return null;
}

// ============================================================================
// Audio/Video Patterns (WHATWG MIME Sniffing §4.2)
// ============================================================================

/// Audio/video patterns (comptime constant)
///
/// Spec: https://mimesniff.spec.whatwg.org/#matching-an-audio-or-video-type-pattern
pub const AUDIO_VIDEO_PATTERNS = [_]Pattern{
    // AIFF: FORM????AIFF
    .{
        .pattern = "FORM\x00\x00\x00\x00AIFF",
        .mask = &[_]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF },
        .ignored = &[_]u8{},
        .mime_type = &mime_constants.AUDIO_AIFF,
    },

    // MP3 with ID3: "ID3"
    .{
        .pattern = "ID3",
        .mask = &[_]u8{ 0xFF, 0xFF, 0xFF },
        .ignored = &[_]u8{},
        .mime_type = &mime_constants.AUDIO_MPEG,
    },

    // Ogg: OggS\x00
    .{
        .pattern = "OggS\x00",
        .mask = &[_]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
        .ignored = &[_]u8{},
        .mime_type = &mime_constants.APPLICATION_OGG,
    },

    // MIDI: MThd\x00\x00\x00\x06
    .{
        .pattern = "MThd\x00\x00\x00\x06",
        .mask = &[_]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
        .ignored = &[_]u8{},
        .mime_type = &mime_constants.AUDIO_MIDI,
    },

    // AVI: RIFF????AVI
    .{
        .pattern = "RIFF\x00\x00\x00\x00AVI ",
        .mask = &[_]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF },
        .ignored = &[_]u8{},
        .mime_type = &mime_constants.VIDEO_AVI,
    },

    // WAVE: RIFF????WAVE
    .{
        .pattern = "RIFF\x00\x00\x00\x00WAVE",
        .mask = &[_]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF },
        .ignored = &[_]u8{},
        .mime_type = &mime_constants.AUDIO_WAVE,
    },
};

/// Match audio or video type pattern
///
/// Note: MP4, WebM, and MP3 (without ID3) require special algorithms
/// and are not included in this simple pattern table.
///
/// Spec: https://mimesniff.spec.whatwg.org/#matching-an-audio-or-video-type-pattern
pub fn matchAudioOrVideoTypePattern(input: []const u8) ?MimeType {
    // Try simple patterns first
    for (AUDIO_VIDEO_PATTERNS) |pattern| {
        if (patternMatching(input, pattern.pattern, pattern.mask, pattern.ignored)) {
            return pattern.mime_type.*;
        }
    }

    // Check complex signatures (per spec §4.2)
    if (matchesMp4Signature(input)) return mime_constants.VIDEO_MP4;
    if (matchesWebmSignature(input)) return mime_constants.VIDEO_WEBM;
    if (matchesMp3Signature(input)) return mime_constants.AUDIO_MPEG;

    return null;
}

// ============================================================================
// Complex Signatures (WHATWG MIME Sniffing §4.2.1, §4.2.2, §4.2.3)
// ============================================================================

/// Matches the signature for MP4 (WHATWG MIME Sniffing §4.2.1)
///
/// MP4 files have an ftyp box at the start with a "major brand" and
/// "compatible brands" list. We check if "mp4" appears in either.
///
/// Spec: https://mimesniff.spec.whatwg.org/#signature-for-mp4
fn matchesMp4Signature(sequence: []const u8) bool {
    // 1. Let sequence be the byte sequence to be matched
    // 2. Let length be the number of bytes in sequence
    const length = sequence.len;

    // 3. If length is less than 12, return false
    if (length < 12)
        return false;

    // 4. Let box-size be the four bytes from sequence[0] to sequence[3],
    //    interpreted as a 32-bit unsigned big-endian integer
    const box_size = std.mem.readInt(u32, sequence[0..4], .big);

    // 5. If length is less than box-size or if box-size modulo 4 is not equal to 0, return false
    if (length < box_size or box_size % 4 != 0)
        return false;

    // 6. If the four bytes from sequence[4] to sequence[7] are not equal to
    //    0x66 0x74 0x79 0x70 ("ftyp"), return false
    if (!std.mem.eql(u8, sequence[4..8], "ftyp"))
        return false;

    // 7. If the three bytes from sequence[8] to sequence[10] are equal to
    //    0x6D 0x70 0x34 ("mp4"), return true
    if (std.mem.eql(u8, sequence[8..11], "mp4"))
        return true;

    // 8. Let bytes-read be 16
    //    (This ignores the four bytes that correspond to the version number of the "major brand")
    var bytes_read: usize = 16;

    // 9. While bytes-read is less than box-size
    while (bytes_read < box_size) {
        // 9.1. If the three bytes from sequence[bytes-read] to sequence[bytes-read + 2]
        //      are equal to 0x6D 0x70 0x34 ("mp4"), return true
        if (bytes_read + 3 <= sequence.len and std.mem.eql(u8, sequence[bytes_read..][0..3], "mp4"))
            return true;

        // 9.2. Increment bytes-read by 4
        bytes_read += 4;
    }

    // 10. Return false
    return false;
}

/// Matches the signature for WebM (WHATWG MIME Sniffing §4.2.2)
///
/// WebM files start with an EBML header, then have a DocType element
/// that should contain "webm".
///
/// Spec: https://mimesniff.spec.whatwg.org/#signature-for-webm
fn matchesWebmSignature(sequence: []const u8) bool {
    // 1. Let sequence be the byte sequence to be matched
    // 2. Let length be the number of bytes in sequence
    const length = sequence.len;

    // 3. If length is less than 4, return false
    if (length < 4)
        return false;

    // 4. If the four bytes from sequence[0] to sequence[3] are not equal to
    //    0x1A 0x45 0xDF 0xA3, return false
    const ebml_header = [_]u8{ 0x1A, 0x45, 0xDF, 0xA3 };
    if (!std.mem.eql(u8, sequence[0..4], &ebml_header))
        return false;

    // 5. Let iter be 4
    var iter: usize = 4;

    // 6. While iter is less than length and iter is less than 38
    while (iter < length and iter < 38) {
        // 6.1. If the two bytes from sequence[iter] to sequence[iter + 1] are equal to 0x42 0x82
        if (iter + 1 < length and sequence[iter] == 0x42 and sequence[iter + 1] == 0x82) {
            // 6.1.1. Increment iter by 2
            iter += 2;

            // 6.1.2. If iter is greater or equal than length, abort these steps
            if (iter >= length)
                break;

            // 6.1.3. Let number_size be the result of parsing a vint starting at sequence[iter]
            const vint_result = parseVint(sequence, length, iter);
            const number_size = vint_result.size;

            // 6.1.4. Increment iter by number_size
            iter += number_size;

            // 6.1.5. If iter is greater than or equal to length - 4, abort these steps
            if (iter >= length - 4)
                break;

            // 6.1.6. Let matched be the result of matching a padded sequence
            //        0x77 0x65 0x62 0x6D ("webm") on sequence at offset iter
            const webm_pattern = [_]u8{ 0x77, 0x65, 0x62, 0x6D };
            const matched = matchPaddedSequence(sequence, &webm_pattern, iter, iter + 4);

            // 6.1.7. If matched is true, abort these steps and return true
            if (matched)
                return true;
        }

        // 6.2. Increment iter by 1
        iter += 1;
    }

    // 7. Return false
    return false;
}

/// Vint parsing result
const VintResult = struct {
    value: u64,
    size: usize,
};

/// Parse a vint (variable-length integer used in EBML/WebM)
///
/// Spec: https://mimesniff.spec.whatwg.org/#parse-a-vint
fn parseVint(sequence: []const u8, length: usize, iter: usize) VintResult {
    // 1. Let mask be 128
    var mask: u8 = 128;

    // 2. Let max_vint_length be 8
    const max_vint_length: usize = 8;

    // 3. Let number_size be 1
    var number_size: usize = 1;

    // 4. Let index be 0
    var index: usize = 0;

    // 5. While number_size is less than max_vint_length, and less than length
    while (number_size < max_vint_length and iter + index < length) {
        // 5.1. If the sequence[iter + index] & mask is not zero, abort these steps
        if ((sequence[iter + index] & mask) != 0)
            break;

        // 5.2. Let mask be the value of mask >> 1
        mask >>= 1;

        // 5.3. Increment number_size by one
        number_size += 1;
    }

    // 6. Let parsed_number be sequence[iter + index] & ~mask
    var parsed_number: u64 = @as(u64, sequence[iter + index] & ~mask);

    // 7. Increment index by one
    index += 1;

    // 8. Let bytes_remaining be the value of number_size - 1
    var bytes_remaining: usize = number_size - 1;

    // 9. While bytes_remaining is not zero
    while (bytes_remaining != 0) {
        // 9.1. Let parsed_number be parsed_number << 8
        parsed_number <<= 8;

        // 9.2. Let parsed_number be parsed_number | sequence[iter + index]
        if (iter + index < length) {
            parsed_number |= @as(u64, sequence[iter + index]);
        }

        // 9.3. Increment index by one
        index += 1;

        // 9.4. If index is greater or equal than length, abort these steps
        if (iter + index >= length)
            break;

        // 9.5. Decrement bytes_remaining by one
        bytes_remaining -= 1;
    }

    // 10. Return parsed_number and number_size
    return .{ .value = parsed_number, .size = number_size };
}

/// Match a padded sequence
///
/// Returns true if sequence has a length greater than end, and contains exactly,
/// in the range [offset, end], the bytes in pattern, in the same order,
/// eventually preceded by bytes with a value of 0x00.
///
/// Spec: https://mimesniff.spec.whatwg.org/#matching-a-padded-sequence
fn matchPaddedSequence(
    sequence: []const u8,
    pattern: []const u8,
    offset: usize,
    end: usize,
) bool {
    // If sequence has a length greater than end
    if (sequence.len <= end)
        return false;

    // Find the start of the pattern (skip leading 0x00 bytes)
    var pos = offset;
    while (pos < end and sequence[pos] == 0x00) : (pos += 1) {}

    // Check if we have enough space for the pattern
    if (end - pos < pattern.len)
        return false;

    // Match the pattern
    return std.mem.eql(u8, sequence[pos..][0..pattern.len], pattern);
}

/// Matches the signature for MP3 without ID3 (WHATWG MIME Sniffing §4.2.3)
///
/// MP3 files have a sync word (0xFF followed by 0xE*) and specific header structure.
/// We validate two consecutive frames to avoid false positives.
///
/// Spec: https://mimesniff.spec.whatwg.org/#signature-for-mp3-without-id3
fn matchesMp3Signature(sequence: []const u8) bool {
    // 1. Let sequence be the byte sequence to be matched
    // 2. Let length be the number of bytes in sequence
    const length = sequence.len;

    // 3. Initialize s to 0
    var s: usize = 0;

    // 4. If the result of the operation match mp3 header is false, return false
    if (!matchMp3Header(sequence, length, s))
        return false;

    // 5. Parse an mp3 frame on sequence at offset s
    const frame = parseMp3Frame(sequence, s);

    // 6. Let skipped-bytes be the return value of the execution of mp3 framesize computation
    const skipped_bytes = computeMp3FrameSize(frame);

    // 7. If skipped-bytes is less than 4, or skipped-bytes is greater than length - s, return false
    if (skipped_bytes < 4 or skipped_bytes > length - s)
        return false;

    // 8. Increment s by skipped-bytes
    s += skipped_bytes;

    // 9. If the result of the operation match mp3 header is false, return false, else return true
    return matchMp3Header(sequence, length, s);
}

/// MP3 frame information
const Mp3Frame = struct {
    version: u8,
    bitrate_index: u8,
    samplerate_index: u8,
    pad: u8,
};

/// Match MP3 header
///
/// Spec: https://mimesniff.spec.whatwg.org/#match-an-mp3-header
fn matchMp3Header(sequence: []const u8, length: usize, s: usize) bool {
    // 1. If length is less than 4, return false
    if (length < 4)
        return false;

    // 2. If sequence[s] is not equal to 0xff and sequence[s + 1] & 0xe0 is not equal to 0xe0, return false
    if (s + 1 >= length or sequence[s] != 0xFF or (sequence[s + 1] & 0xE0) != 0xE0)
        return false;

    // 3. Let layer be the result of sequence[s + 1] & 0x06 >> 1
    const layer = (sequence[s + 1] & 0x06) >> 1;

    // 4. If layer is 0, return false
    if (layer == 0)
        return false;

    // 5. Let bit-rate be sequence[s + 2] & 0xf0 >> 4
    const bit_rate = (sequence[s + 2] & 0xF0) >> 4;

    // 6. If bit-rate is 15, return false
    if (bit_rate == 15)
        return false;

    // 7. Let sample-rate be sequence[s + 2] & 0x0c >> 2
    const sample_rate = (sequence[s + 2] & 0x0C) >> 2;

    // 8. If sample-rate is 3, return false
    if (sample_rate == 3)
        return false;

    // 9. Let freq be the value given by sample-rate in the table sample-rate
    // (This is actually used in computeMp3FrameSize, not here)

    // 10-11. Final-layer validation SKIPPED due to spec error
    //
    // Spec says: "Let final-layer be the result of 4 - (sequence[s + 1])"
    //            "If final-layer & 0x06 >> 1 is not 3, return false"
    //
    // PROBLEM: This is a known error in the WHATWG spec. The calculation
    // "4 - (sequence[s + 1])" causes integer overflow since sequence[s+1]
    // can be 0xFF (255). Even if we interpret it as "4 - layer", the check
    // "(final-layer & 0x06) >> 1 == 3" is mathematically impossible to satisfy
    // for any valid layer value (1, 2, or 3):
    //   - layer=1 → final=3 → (3 & 0x06)>>1 = 1 ≠ 3
    //   - layer=2 → final=2 → (2 & 0x06)>>1 = 1 ≠ 3
    //   - layer=3 → final=1 → (1 & 0x06)>>1 = 0 ≠ 3
    //
    // REFERENCE: WHATWG issue #70 (https://github.com/whatwg/mimesniff/issues/70)
    // documents multiple problems with the MP3 algorithm. Chrome uses a much
    // simpler approach: just check for "ID3" or FF Ex patterns.
    //
    // CONCLUSION: This validation step appears to be a spec error and is skipped.
    // All other validations (sync word, layer, bitrate, sample rate) are correctly
    // implemented and sufficient for MP3 detection.

    return true;
}

/// Parse MP3 frame
///
/// Spec: https://mimesniff.spec.whatwg.org/#parse-an-mp3-frame
fn parseMp3Frame(sequence: []const u8, s: usize) Mp3Frame {
    // 1. Let version be sequence[s + 1] & 0x18 >> 3
    const version = (sequence[s + 1] & 0x18) >> 3;

    // 2. Let bitrate-index be sequence[s + 2] & 0xf0 >> 4
    const bitrate_index = (sequence[s + 2] & 0xF0) >> 4;

    // 5. Let samplerate-index be sequence[s + 2] & 0x0c >> 2
    const samplerate_index = (sequence[s + 2] & 0x0C) >> 2;

    // 7. Let pad be sequence[s + 2] & 0x02 >> 1
    const pad = (sequence[s + 2] & 0x02) >> 1;

    return .{
        .version = version,
        .bitrate_index = bitrate_index,
        .samplerate_index = samplerate_index,
        .pad = pad,
    };
}

/// MP3 bitrate tables (from spec)
const MP3_RATES = [_]u32{ 0, 32000, 40000, 48000, 56000, 64000, 80000, 96000, 112000, 128000, 160000, 192000, 224000, 256000, 320000 };
const MP2_5_RATES = [_]u32{ 0, 8000, 16000, 24000, 32000, 40000, 48000, 56000, 64000, 80000, 96000, 112000, 128000, 144000, 160000 };
const SAMPLE_RATES = [_]u32{ 44100, 48000, 32000 };

/// Compute MP3 frame size
///
/// Spec: https://mimesniff.spec.whatwg.org/#compute-an-mp3-frame-size
fn computeMp3FrameSize(frame: Mp3Frame) usize {
    // 3-4. Get bitrate from table
    const bitrate = if ((frame.version & 0x01) != 0)
        MP2_5_RATES[frame.bitrate_index]
    else
        MP3_RATES[frame.bitrate_index];

    // 6. Get samplerate from table
    const samplerate = SAMPLE_RATES[frame.samplerate_index];

    // 1. If version is 1, let scale be 72, else let scale be 144
    const scale: u32 = if (frame.version == 1) 72 else 144;

    // 2. Let size be bitrate * scale / freq
    var size: usize = @intCast((bitrate * scale) / samplerate);

    // 3. If pad is not zero, increment size by 1
    if (frame.pad != 0)
        size += 1;

    // 4. Return size
    return size;
}

// ============================================================================
// Font Patterns (WHATWG MIME Sniffing §4.4)
// ============================================================================

/// Font patterns (comptime constant)
///
/// Spec: https://mimesniff.spec.whatwg.org/#matching-a-font-type-pattern
pub const FONT_PATTERNS = [_]Pattern{
    // Embedded OpenType: 34 bytes of 0x00 followed by "LP"
    .{
        .pattern = &[_]u8{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4C, 0x50 },
        .mask = &[_]u8{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF },
        .ignored = &[_]u8{},
        .mime_type = &mime_constants.APPLICATION_VND_MS_FONTOBJECT,
    },

    // TrueType: 00 01 00 00
    .{
        .pattern = &[_]u8{ 0x00, 0x01, 0x00, 0x00 },
        .mask = &[_]u8{ 0xFF, 0xFF, 0xFF, 0xFF },
        .ignored = &[_]u8{},
        .mime_type = &mime_constants.FONT_TTF,
    },

    // OpenType: "OTTO"
    .{
        .pattern = "OTTO",
        .mask = &[_]u8{ 0xFF, 0xFF, 0xFF, 0xFF },
        .ignored = &[_]u8{},
        .mime_type = &mime_constants.FONT_OTF,
    },

    // TrueType Collection: "ttcf"
    .{
        .pattern = "ttcf",
        .mask = &[_]u8{ 0xFF, 0xFF, 0xFF, 0xFF },
        .ignored = &[_]u8{},
        .mime_type = &mime_constants.FONT_COLLECTION,
    },

    // WOFF: "wOFF"
    .{
        .pattern = "wOFF",
        .mask = &[_]u8{ 0xFF, 0xFF, 0xFF, 0xFF },
        .ignored = &[_]u8{},
        .mime_type = &mime_constants.FONT_WOFF,
    },

    // WOFF2: "wOF2"
    .{
        .pattern = "wOF2",
        .mask = &[_]u8{ 0xFF, 0xFF, 0xFF, 0xFF },
        .ignored = &[_]u8{},
        .mime_type = &mime_constants.FONT_WOFF2,
    },
};

/// Match font type pattern
///
/// Spec: https://mimesniff.spec.whatwg.org/#matching-a-font-type-pattern
pub fn matchFontTypePattern(input: []const u8) ?MimeType {
    for (FONT_PATTERNS) |pattern| {
        if (patternMatching(input, pattern.pattern, pattern.mask, pattern.ignored)) {
            return pattern.mime_type.*;
        }
    }

    return null;
}

// ============================================================================
// Archive Patterns (WHATWG MIME Sniffing §4.5)
// ============================================================================

/// Archive patterns (comptime constant)
///
/// Spec: https://mimesniff.spec.whatwg.org/#matching-an-archive-type-pattern
pub const ARCHIVE_PATTERNS = [_]Pattern{
    // GZIP: 1F 8B 08
    .{
        .pattern = &[_]u8{ 0x1F, 0x8B, 0x08 },
        .mask = &[_]u8{ 0xFF, 0xFF, 0xFF },
        .ignored = &[_]u8{},
        .mime_type = &mime_constants.APPLICATION_GZIP,
    },

    // ZIP: "PK" 03 04
    .{
        .pattern = "PK\x03\x04",
        .mask = &[_]u8{ 0xFF, 0xFF, 0xFF, 0xFF },
        .ignored = &[_]u8{},
        .mime_type = &mime_constants.APPLICATION_ZIP,
    },

    // RAR: "Rar!" 1A 07 00
    .{
        .pattern = "Rar!\x1A\x07\x00",
        .mask = &[_]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
        .ignored = &[_]u8{},
        .mime_type = &mime_constants.APPLICATION_X_RAR_COMPRESSED,
    },
};

/// Match archive type pattern
///
/// Spec: https://mimesniff.spec.whatwg.org/#matching-an-archive-type-pattern
pub fn matchArchiveTypePattern(input: []const u8) ?MimeType {
    for (ARCHIVE_PATTERNS) |pattern| {
        if (patternMatching(input, pattern.pattern, pattern.mask, pattern.ignored)) {
            return pattern.mime_type.*;
        }
    }

    return null;
}

// ============================================================================
// Test Helpers
// ============================================================================

/// Helper to check MimeType essence matches expected type/subtype (for tests)
fn expectEssence(mime: MimeType, expected_type: []const u8, expected_subtype: []const u8) !void {
    // Compare type
    try std.testing.expectEqual(expected_type.len, mime.type.len);
    for (mime.type, 0..) |c, i| {
        try std.testing.expectEqual(@as(u16, expected_type[i]), c);
    }

    // Compare subtype
    try std.testing.expectEqual(expected_subtype.len, mime.subtype.len);
    for (mime.subtype, 0..) |c, i| {
        try std.testing.expectEqual(@as(u16, expected_subtype[i]), c);
    }
}

// ============================================================================
// Tests
// ============================================================================

test "matchImageTypePattern - PNG" {
    const png_signature = [_]u8{ 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };
    const result = matchImageTypePattern(&png_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "image", "png");
}

test "matchImageTypePattern - JPEG" {
    const jpeg_signature = [_]u8{ 0xFF, 0xD8, 0xFF, 0xE0 };
    const result = matchImageTypePattern(&jpeg_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "image", "jpeg");
}

test "matchImageTypePattern - GIF87a" {
    const gif_signature = "GIF87a";
    const result = matchImageTypePattern(gif_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "image", "gif");
}

test "matchImageTypePattern - GIF89a" {
    const gif_signature = "GIF89a";
    const result = matchImageTypePattern(gif_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "image", "gif");
}

test "matchImageTypePattern - WebP" {
    const webp_signature = "RIFF\x00\x00\x00\x00WEBPVP";
    const result = matchImageTypePattern(webp_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "image", "webp");
}

test "matchImageTypePattern - no match" {
    const random_data = "Not an image!";
    const result = matchImageTypePattern(random_data);
    try std.testing.expect(result == null);
}

test "matchFontTypePattern - WOFF" {
    const woff_signature = "wOFF";
    const result = matchFontTypePattern(woff_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "font", "woff");
}

test "matchFontTypePattern - WOFF2" {
    const woff2_signature = "wOF2";
    const result = matchFontTypePattern(woff2_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "font", "woff2");
}

test "matchArchiveTypePattern - GZIP" {
    const gzip_signature = [_]u8{ 0x1F, 0x8B, 0x08 };
    const result = matchArchiveTypePattern(&gzip_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "application", "x-gzip");
}

test "matchArchiveTypePattern - ZIP" {
    const zip_signature = "PK\x03\x04";
    const result = matchArchiveTypePattern(zip_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "application", "zip");
}

test "patternMatchingSIMD - long pattern" {
    const input = "0123456789ABCDEF_Hello_World_Test";
    const pattern = "0123456789ABCDEF";
    const mask = &[_]u8{0xFF} ** 16;
    const ignored = &[_]u8{};

    try std.testing.expect(patternMatchingSIMD(input, pattern, mask, ignored));
}

test "matchesMp4Signature - valid ftyp box" {
    const mp4_signature = [_]u8{
        0x00, 0x00, 0x00, 0x18, // box size = 24 bytes
        'f', 't', 'y', 'p', // box type = ftyp
        'm', 'p', '4', '2', // brand = mp42
        0x00, 0x00, 0x00, 0x00, // version
        'm', 'p', '4', '1', // compatible brand
        'm', 'p', '4', '2', // compatible brand
    };
    try std.testing.expect(matchesMp4Signature(&mp4_signature));
}

test "matchesMp4Signature - iso5 brand with mp4 in compatible brands" {
    const mp4_signature = [_]u8{
        0x00, 0x00, 0x00, 0x14, // box size = 20 bytes
        'f', 't', 'y', 'p', // box type = ftyp
        'i', 's', 'o', '5', // brand = iso5
        0x00, 0x00, 0x00, 0x00, // version
        'm', 'p', '4', '2', // compatible brand starting with "mp4"
    };
    try std.testing.expect(matchesMp4Signature(&mp4_signature));
}

test "matchesMp4Signature - invalid box type" {
    const not_ftyp = [_]u8{
        0x00, 0x00, 0x00, 0x18,
        'w',  'r',  'o',  'n', // wrong box type
        'm',  'p',  '4',  '2',
        0x00, 0x00, 0x00, 0x00,
    };
    try std.testing.expect(!matchesMp4Signature(&not_ftyp));
}

test "matchesWebmSignature - valid EBML with DocType webm" {
    const webm_signature = [_]u8{
        0x1A, 0x45, 0xDF, 0xA3, // EBML header (bytes 0-3)
        0x42, 0x82, // DocType element ID (bytes 4-5)
        0x84, // vint length = 4 (byte 6, high bit set, so size=1)
        'w', 'e', 'b', 'm', // DocType = "webm" (bytes 7-10)
        0x00, // extra byte to satisfy "length greater than end" requirement
    };
    try std.testing.expect(matchesWebmSignature(&webm_signature));
}

test "matchesWebmSignature - matroska does not match" {
    // WebM signature only matches "webm" DocType, not "matroska"
    const matroska_signature = [_]u8{
        0x1A, 0x45, 0xDF, 0xA3, // EBML header
        0x42, 0x82, // DocType element ID
        0x88, // vint length = 8
        'm',  'a', 't', 'r', 'o', 's', 'k', 'a', // DocType = "matroska"
        0x00,
    };
    try std.testing.expect(!matchesWebmSignature(&matroska_signature));
}

test "matchesWebmSignature - invalid DocType" {
    const invalid_signature = [_]u8{
        0x1A, 0x45, 0xDF, 0xA3,
        0x42, 0x82, 0x84,
        'f',  'a', 'k', 'e', // wrong DocType
        0x00,
    };
    try std.testing.expect(!matchesWebmSignature(&invalid_signature));
}

test "matchesMp3Signature - valid MP3 with ID3" {
    // Note: This test is for MP3 WITHOUT ID3, so ID3 signatures should fail
    // The function name is misleading - it only matches raw MP3 frames
    const mp3_with_id3 = [_]u8{
        'I',  'D',  '3', // ID3 tag - this will cause matchMp3Header to fail
        0x03, 0x00, 0x00,
        0x00, 0x00, 0x00,
        0x10,
    };
    try std.testing.expect(!matchesMp3Signature(&mp3_with_id3));
}

test "matchesMp3Signature - valid MP3 without ID3" {
    const allocator = std.testing.allocator;

    // Create valid MP3 frame data
    // Header: 0xFF 0xFB
    //   Byte 1: 0xFB = 0b11111011
    //   - Sync (11 bits): 0xFFE (all 1s)
    //   - Version: (0xFB & 0x18) >> 3 = 0x18 >> 3 = 3
    //   - Layer: (0xFB & 0x06) >> 1 = 0x02 >> 1 = 1 (Layer III)
    //   - CRC: 1 (no CRC)
    // Byte 2: 0x90
    //   - Bitrate index: (0x90 & 0xF0) >> 4 = 9
    //   - Sample rate index: (0x90 & 0x0C) >> 2 = 0
    //   - Padding: 0
    // Byte 3: 0x00
    //   - Mode, etc.
    //
    // Frame size calculation (per spec algorithm):
    //   version = 3, version & 0x01 = 1, so use MP2_5_RATES
    //   bitrate = MP2_5_RATES[9] = 80000
    //   samplerate = SAMPLE_RATES[0] = 44100
    //   scale = (version == 1) ? 72 : 144 = 144
    //   frame_size = 80000 * 144 / 44100 = 261 bytes

    var mp3_data = try std.ArrayList(u8).initCapacity(allocator, 530);
    defer mp3_data.deinit(allocator);

    // First MP3 frame: 261 bytes
    try mp3_data.appendSlice(allocator, &[_]u8{ 0xFF, 0xFB, 0x90, 0x00 });
    try mp3_data.appendSlice(allocator, &([_]u8{0x00} ** 257)); // 4 + 257 = 261

    // Second MP3 frame: 261 bytes
    try mp3_data.appendSlice(allocator, &[_]u8{ 0xFF, 0xFB, 0x90, 0x00 });
    try mp3_data.appendSlice(allocator, &([_]u8{0x00} ** 257)); // 4 + 257 = 261

    try std.testing.expect(matchesMp3Signature(mp3_data.items));
}

test "matchesMp3Signature - invalid MP3 header (bad bitrate)" {
    const invalid_mp3 = [_]u8{
        0xFF, 0xFB,
        0xF0, 0x00, // bitrate = 15 (invalid)
    };
    try std.testing.expect(!matchesMp3Signature(&invalid_mp3));
}

test "matchesMp3Signature - invalid MP3 header (bad sample rate)" {
    const invalid_mp3 = [_]u8{
        0xFF, 0xFB,
        0x9C, 0x00, // sample rate = 3 (invalid)
    };
    try std.testing.expect(!matchesMp3Signature(&invalid_mp3));
}

test "matchesMp3Signature - invalid MP3 header (layer 0)" {
    const invalid_mp3 = [_]u8{
        0xFF, 0xF9, // layer = 0 (invalid)
        0x90, 0x00,
    };
    try std.testing.expect(!matchesMp3Signature(&invalid_mp3));
}

test "matchesMp3Signature - too short" {
    const short_mp3 = [_]u8{ 0xFF, 0xFB };
    try std.testing.expect(!matchesMp3Signature(&short_mp3));
}
