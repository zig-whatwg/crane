//! IDNA Character Mapping
//!
//! Maps characters according to UTS46 IDNA mapping tables.
//!
//! Uses generated Unicode data from unicode_data.zig

const std = @import("std");
const infra = @import("infra");
const unicode_data = @import("unicode_data.zig");

pub const MappingError = error{
    DisallowedCharacter,
    InvalidCodePoint,
    OutOfMemory,
};

/// Status of an IDNA code point
pub const Status = enum {
    valid, // Valid for IDNA
    ignored, // Ignored in IDNA processing
    mapped, // Mapped to other character(s)
    deviation, // Depends on processing type
    disallowed, // Not allowed in IDNA
    disallowed_std3_valid,
    disallowed_std3_mapped,
};

/// Apply IDNA mapping to an entire string
///
/// Parameters:
/// - `use_std3_ascii_rules`: If true, reject disallowed_std3_* characters
pub fn mapString(allocator: std.mem.Allocator, input: []const u8, use_std3_ascii_rules: bool) ![]u8 {
    return mapStringInternal(allocator, input, use_std3_ascii_rules, false);
}

/// Apply lenient IDNA mapping for toASCII
/// UTS #46 Processing step 1 leaves disallowed characters unchanged; step 4
/// validates the normalized result. A mapping result alone is not success.
pub fn mapStringLenient(allocator: std.mem.Allocator, input: []const u8, use_std3_ascii_rules: bool) ![]u8 {
    return mapStringInternal(allocator, input, use_std3_ascii_rules, true);
}

fn mapStringInternal(allocator: std.mem.Allocator, input: []const u8, use_std3_ascii_rules: bool, lenient: bool) ![]u8 {
    var result = infra.List(u8).init(allocator);
    errdefer result.deinit();

    var i: usize = 0;
    while (i < input.len) {
        // Decode UTF-8 code point
        const cp_len = std.unicode.utf8ByteSequenceLength(input[i]) catch {
            return MappingError.InvalidCodePoint;
        };

        if (i + cp_len > input.len) {
            return MappingError.InvalidCodePoint;
        }

        const cp = std.unicode.utf8Decode(input[i..][0..cp_len]) catch {
            return MappingError.InvalidCodePoint;
        };

        // Look up IDNA status
        const lookup = unicode_data.lookupIdnaStatus(cp);

        switch (lookup.status) {
            .valid => {
                // Copy original code point
                try result.appendSlice(input[i .. i + cp_len]);
            },
            .deviation => {
                // Transitional_Processing=false: treat as valid, don't map
                try result.appendSlice(input[i .. i + cp_len]);
            },
            .mapped => {
                // Use mapped character(s)
                if (lookup.mapping) |mapping| {
                    try result.appendSlice(mapping);
                } else {
                    // No mapping provided - copy original
                    try result.appendSlice(input[i .. i + cp_len]);
                }
            },
            .ignored => {
                // Skip this character
            },
            .disallowed => {
                if (lenient) {
                    // UTS #46 Processing step 1: validation occurs after NFC.
                    try result.appendSlice(input[i .. i + cp_len]);
                } else {
                    // Per UTS46/WHATWG URL, disallowed characters cause failure for toUnicode
                    return MappingError.DisallowedCharacter;
                }
            },
            .disallowed_std3_valid => {
                if (use_std3_ascii_rules) {
                    return MappingError.DisallowedCharacter;
                }
                // When not using STD3 rules, treat as valid - copy as-is
                try result.appendSlice(input[i .. i + cp_len]);
            },
            .disallowed_std3_mapped => {
                if (use_std3_ascii_rules) {
                    return MappingError.DisallowedCharacter;
                }
                // When not using STD3 rules, use the mapping
                if (lookup.mapping) |map| {
                    try result.appendSlice(map);
                } else {
                    try result.appendSlice(input[i .. i + cp_len]);
                }
            },
        }

        i += cp_len;
    }

    return result.toOwnedSlice();
}
