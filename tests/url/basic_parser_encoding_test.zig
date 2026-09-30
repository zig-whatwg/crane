//! The basic URL parser given an encoding (URL § 4.4, the query state): the
//! query is percent-encoded after encoding with it, an unmappable code point
//! becomes "%26%23<decimal>%3B", and a URL that is not special - or whose
//! scheme is ws or wss - keeps UTF-8. Nothing but the query changes. This is
//! what HTML's "encoding-parse a URL" does with a document's encoding, which
//! the WPT encoding/legacy-*-encode-href files check through `a.search`.

const std = @import("std");
const url_mod = @import("url");
const encoding = @import("encoding");
const parser = url_mod.parser.basic_url_parser;

/// `input` parsed given the encoding `label` names has the query `expected`.
fn expectQuery(input: []const u8, label: []const u8, expected: []const u8) !void {
    var url = try parser.parseWithEncoding(std.testing.allocator, input, null, encoding.getEncoding(label).?);
    defer url.deinit();
    try std.testing.expectEqualStrings(expected, url.query().?);
}

test "the query is encoded with the given encoding" {
    try expectQuery("http://example.com/?\u{00E9}", "windows-1252", "%E9");
    try expectQuery("http://example.com/?\u{3042}", "shift_jis", "%82%A0");
    try expectQuery("http://example.com/?\u{00A7}", "big5", "%A1%B1");
}

test "an unmappable code point becomes a percent-encoded numeric reference" {
    try expectQuery("http://example.com/?\u{3042}", "windows-1252", "%26%2312354%3B");
}

test "only the query: the fragment stays UTF-8" {
    try expectQuery("http://example.com/\u{00E9}?\u{00E9}#\u{00E9}", "windows-1252", "%E9");
    var url = try parser.parseWithEncoding(std.testing.allocator, "http://example.com/?\u{00E9}#\u{00E9}", null, encoding.getEncoding("windows-1252").?);
    defer url.deinit();
    try std.testing.expectEqualStrings("%C3%A9", url.fragment().?);
}

test "a URL that is not special, or ws/wss, keeps UTF-8" {
    try expectQuery("foo://example.com/?\u{00E9}", "windows-1252", "%C3%A9");
    try expectQuery("ws://example.com/?\u{00E9}", "windows-1252", "%C3%A9");
    try expectQuery("wss://example.com/?\u{00E9}", "windows-1252", "%C3%A9");
}

test "UTF-16 and replacement are not output encodings: UTF-8" {
    try expectQuery("http://example.com/?\u{00E9}", "utf-16le", "%C3%A9");
    try expectQuery("http://example.com/?\u{00E9}", "iso-2022-kr", "%C3%A9");
}

test "the special-query set still applies" {
    try expectQuery("http://example.com/?a'b c", "windows-1252", "a%27b%20c");
    try expectQuery("foo://example.com/?a'b", "windows-1252", "a'b");
}

test "ISO-2022-JP's encoder keeps its state across the query and ends in ASCII" {
    // U+3042 is ESC $ B 0x24 0x22 (the quote is in the query set), and the encoder returns to ASCII with ESC ( B.
    try expectQuery("http://example.com/?\u{3042}a", "iso-2022-jp", "%1B$B$%22%1B(Ba");
}
