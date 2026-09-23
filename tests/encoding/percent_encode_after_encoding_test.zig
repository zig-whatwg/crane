//! URL § 1.3 "percent-encode after encoding", which HTML form submission and
//! the URL parser's query state both run with a document's encoding.
//!
//! The encoder is the Encoding Standard's, driven in "encode or fail" mode:
//! an unmappable code point ends one run, is written as "%26%23" + decimal +
//! "%3B", and the SAME encoder carries on - so a stateful encoder's state
//! survives the error. ISO-2022-JP is the case that shows it: its encoder
//! switches back to ASCII before reporting an error (step 11.1), and the
//! escape sequence it emits for that is part of the output.

const std = @import("std");
const encoding = @import("encoding");

const pe = encoding.percent_encode;

/// URL's application/x-www-form-urlencoded percent-encode set: everything
/// but ASCII alphanumerics, "*", "-", "." and "_".
fn formSet(byte: u8) bool {
    return !(std.ascii.isAlphanumeric(byte) or byte == '*' or byte == '-' or byte == '.' or byte == '_');
}

fn run(label: []const u8, input: []const u8) ![]u8 {
    const enc = encoding.getEncoding(label) orelse return error.UnknownEncoding;
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(std.testing.allocator);
    try pe.percentEncodeAfterEncoding(std.testing.allocator, &out, enc, input, formSet, true);
    return out.toOwnedSlice(std.testing.allocator);
}

fn expectEncoded(label: []const u8, input: []const u8, expected: []const u8) !void {
    const got = try run(label, input);
    defer std.testing.allocator.free(got);
    try std.testing.expectEqualStrings(expected, got);
}

test "UTF-8: bytes of the scalar value string, space as plus" {
    try expectEncoded("utf-8", "a b", "a+b");
    try expectEncoded("utf-8", "\u{e9}", "%C3%A9");
    try expectEncoded("utf-8", "a*-._~", "a*-._%7E");
}

test "a lone surrogate is U+FFFD before it is encoded" {
    // WTF-8 for U+D800 on its own.
    try expectEncoded("utf-8", "x\xED\xA0\x80y", "x%EF%BF%BDy");
}

test "Shift_JIS: mapped code points are the encoder's bytes" {
    // U+2605 BLACK STAR is 0x81 0x9A in Shift_JIS.
    try expectEncoded("shift_jis", "\u{2605}", "%81%9A");
}

test "an unmappable code point is a percent-encoded numeric character reference" {
    try expectEncoded("windows-1252", "a\u{2603}b", "a%26%239731%3Bb");
    // Outside the BMP: the code point, not its surrogates.
    try expectEncoded("shift_jis", "\u{1F31F}", "%26%23127775%3B");
}

test "ISO-2022-JP: one escape into JIS X 0208 for a run, one out at the end" {
    // \u{2605}\u{661F} (BLACK STAR, the star kanji) is ESC $ B, 0x21 0x7A,
    // 0x40 0x31, then ESC ( B when the input ends.
    try expectEncoded("iso-2022-jp", "\u{2605}\u{661F}", "%1B%24B%21z%401%1B%28B");
}

test "ISO-2022-JP: an unmappable code point in JIS X 0208 state leaves it first" {
    // Step 11.1: restore the code point, switch to ASCII, emit ESC ( B - and
    // only then report the error, so the reference is written in ASCII.
    try expectEncoded("iso-2022-jp", "\u{661F}\u{1F31F}", "%1B%24B%401%1B%28B%26%23127775%3B");
}

test "ISO-2022-JP: the form test's string, byte for byte" {
    // encoding/legacy-mb-japanese/iso-2022-jp/iso2022jp-encode-form-errors-stateful.html
    // expects, after unescape(): ABC~&#164;&#8226;ESC$B!z@1ESC(B&#127775;ESC$B@1!zESC(B&#8226;&#164;~XYZ
    try expectEncoded(
        "iso-2022-jp",
        "ABC~\u{a4}\u{2022}\u{2605}\u{661F}\u{1F31F}\u{661F}\u{2605}\u{2022}\u{a4}~XYZ",
        "ABC%7E%26%23164%3B%26%238226%3B%1B%24B%21z%401%1B%28B%26%23127775%3B%1B%24B%401%21z%1B%28B%26%238226%3B%26%23164%3B%7EXYZ",
    );
}

test "ISO-2022-JP: U+000E, U+000F and U+001B are errors reported as U+FFFD" {
    // Step 3 returns "error with U+FFFD", not the code point, to prevent
    // attacks that smuggle an escape sequence through.
    try expectEncoded("iso-2022-jp", "a\x1Bb", "a%26%2365533%3Bb");
}
