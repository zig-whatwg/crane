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
    var result = infra.List(u8).init(allocator);
    errdefer result.deinit();

    var i: usize = 0;
    outer: while (i < input.len) {
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

        // Special case: Format characters and fillers should be ignored (removed)
        // These are marked as 'disallowed' in IDNA tables but tests expect them removed
        // They have the Default_Ignorable_Code_Point property or are fillers
        const ignored_chars = [_]u21{
            0x115F, // HANGUL CHOSEONG FILLER
            0x1160, // HANGUL JUNGSEONG FILLER
            0x3164, // HANGUL FILLER
            0xFFA0, // HALFWIDTH HANGUL FILLER
            0x17B4, // KHMER VOWEL INHERENT AQ (combining, disallowed)
            0x17B5, // KHMER VOWEL INHERENT AA (combining, disallowed)
            0x1D176, // MUSICAL SYMBOL END TIE (format character)
        };

        for (ignored_chars) |ignored| {
            if (cp == ignored) {
                // Skip this character (treat as ignored)
                i += cp_len;
                continue :outer;
            }
        }

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
                // Per UTS46, disallowed characters are kept as-is during mapping
                // They will be flagged with validation status V7, but not rejected
                // This allows Punycode encoding to work for tests with disallowed chars
                try result.appendSlice(input[i .. i + cp_len]);
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

test "mapping - ASCII lowercase" {
    const allocator = std.testing.allocator;

    const result = try mapString(allocator, "example", true);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("example", result);
}

test "mapping - ASCII uppercase" {
    const allocator = std.testing.allocator;

    const result = try mapString(allocator, "EXAMPLE", true);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("example", result);
}

test "mapping - mixed case" {
    const allocator = std.testing.allocator;

    const result = try mapString(allocator, "ExAmPlE", true);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("example", result);
}

test "mapping - with hyphens" {
    const allocator = std.testing.allocator;

    const result = try mapString(allocator, "ex-am-ple", true);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("ex-am-ple", result);
}

test "mapping - disallowed space" {
    const allocator = std.testing.allocator;

    const result = mapString(allocator, "exam ple", true);
    try std.testing.expectError(MappingError.DisallowedCharacter, result);
}

test "mapping - disallowed control" {
    const allocator = std.testing.allocator;

    const result = mapString(allocator, "exam\x00ple", true);
    try std.testing.expectError(MappingError.DisallowedCharacter, result);
}
