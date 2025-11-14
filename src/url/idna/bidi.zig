//! Bidirectional Text Rules for IDNA
//!
//! Implements bidi checks for domain labels using Unicode bidi data.

const std = @import("std");
const unicode_data = @import("unicode_data.zig");

pub const BidiError = error{
    InvalidBidi,
};

/// Validate bidirectional text rules for a label
///
/// Basic rule: A label should not mix RTL and LTR characters
pub fn validateBidi(label: []const u8) !void {
    var has_rtl = false;
    var has_ltr = false;

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

        // Look up bidi class
        const bidi_class = unicode_data.lookupBidiClass(cp);

        switch (bidi_class) {
            .R, .AL => has_rtl = true, // Right-to-Left
            .L => has_ltr = true, // Left-to-Right
            else => {}, // Neutral characters don't affect directionality
        }

        i += cp_len;
    }

    // Mixed directionality is not allowed
    if (has_rtl and has_ltr) {
        return BidiError.InvalidBidi;
    }
}




