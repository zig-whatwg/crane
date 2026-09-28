//! WebIDL 3.2.11 USVString: a value converts to DOMString, and then every
//! lone surrogate becomes U+FFFD. V8 writes a lone surrogate into UTF-8 as
//! the three bytes ED A0..BF xx (a surrogate PAIR becomes one four-byte
//! sequence), so the conversion replaces each such sequence in place with
//! EF BF BD. Before, USVString kept them, so `new URL`, fetch and WebSocket
//! saw WTF-8 bytes where the spec gives U+FFFD.

const std = @import("std");
const v8 = @import("v8");
const conv = v8.conversions;

test "a lone high surrogate becomes U+FFFD" {
    var bytes = [_]u8{ 'a', 0xED, 0xA0, 0x80, 'b' }; // "a\uD800b"
    conv.replaceLoneSurrogates(&bytes);
    try std.testing.expectEqualSlices(u8, "a\u{FFFD}b", &bytes);
}

test "a lone low surrogate at the end becomes U+FFFD" {
    var bytes = [_]u8{ 'x', 0xED, 0xBF, 0xBF }; // "x\uDFFF"
    conv.replaceLoneSurrogates(&bytes);
    try std.testing.expectEqualSlices(u8, "x\u{FFFD}", &bytes);
}

test "valid UTF-8 is left alone, including U+D7FF and astral characters" {
    const text = "\u{D7FF}\u{E000}\u{1F600}ok"; // ED 9F BF is U+D7FF: not a surrogate
    var bytes = text.*;
    conv.replaceLoneSurrogates(&bytes);
    try std.testing.expectEqualSlices(u8, text, &bytes);
}
