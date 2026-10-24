//! CSS Fonts 4 §5.1: full Unicode Default Caseless Matching, without normalization.
const std = @import("std");
const casing = @import("infra").unicode_case;

test "full default folding expands sharp-s, apostrophe-n and ffi" {
    try std.testing.expect(casing.eqlFold("Straße", "STRASSE"));
    try std.testing.expect(casing.eqlFold("ŉ", "ʼn"));
    try std.testing.expect(casing.eqlFold("ﬃ", "FFI"));
    try std.testing.expect(casing.eqlFold("Σσς", "σσσ"));
}

test "default folding excludes Turkic tailoring and never normalizes" {
    try std.testing.expect(casing.eqlFold("I", "i"));
    try std.testing.expect(!casing.eqlFold("I", "ı"));
    try std.testing.expect(!casing.eqlFold("İ", "i"));
    try std.testing.expect(casing.eqlFold("İ", "i\u{307}"));
    try std.testing.expect(!casing.eqlFold("Å", "A\u{30a}"));
    try std.testing.expect(casing.eqlFold("Å Font", "å FONT"));
    try std.testing.expect(!casing.eqlFold("font", "font "));
}
