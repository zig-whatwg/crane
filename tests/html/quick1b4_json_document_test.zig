//! A JSON document - a navigation response whose computed MIME type is a
//! JSON MIME type, loaded as a text document - is decoded as UTF-8 whatever
//! its charset parameter, its parent's encoding or a UTF-16 byte order mark
//! says. HTML "load a text document" leaves the conversion to "the
//! specifications for the computed MIME type of the resource"; RFC 8259 8.1:
//! JSON text exchanged between systems "MUST be encoded using UTF-8", 11: no
//! charset parameter is defined for application/json, "adding one really has
//! no effect on compliant recipients". Encoding "UTF-8 decode" is the
//! decode: a UTF-8 byte order mark is dropped, nothing else changes the
//! encoding. WPT encoding/json-document-utf8.html; Firefox 5/5 (bug 1266023,
//! since Firefox 53), WebKit 324849@main (wpt#64300).
const std = @import("std");
const testing = std.testing;
const sniffing = @import("html_core").parser.encoding_sniffing;

test "UTF-8 decode: the bytes as UTF-8, a UTF-8 byte order mark dropped" {
    const text = "{\"text\":\"\u{2603}\u{e9}\"}";
    const plain = try sniffing.utf8Decode(testing.allocator, text);
    defer testing.allocator.free(plain);
    try testing.expectEqualStrings(text, plain);
    const with_bom = try sniffing.utf8Decode(testing.allocator, "\xEF\xBB\xBF" ++ text);
    defer testing.allocator.free(with_bom);
    try testing.expectEqualStrings(text, with_bom);
}

test "UTF-8 decode: a UTF-16 byte order mark does not change the encoding" {
    // FF FE is no UTF-8: two U+FFFD, then the rest as UTF-8.
    const got = try sniffing.utf8Decode(testing.allocator, "\xFF\xFE{}");
    defer testing.allocator.free(got);
    try testing.expectEqualStrings("\u{FFFD}\u{FFFD}{}", got);
}

test "UTF-8 decode: invalid bytes become U+FFFD, a BOM only at the start is dropped" {
    const got = try sniffing.utf8Decode(testing.allocator, "a\xC3(\xEF\xBB\xBFb");
    defer testing.allocator.free(got);
    try testing.expectEqualStrings("a\u{FFFD}(\u{FEFF}b", got);
}
