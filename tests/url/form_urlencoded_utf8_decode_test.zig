//! The application/x-www-form-urlencoded parser's step 3.5 (URL § 5.1):
//! "Let nameString and valueString be the result of running UTF-8 decode
//! without BOM on the percent-decoding of name and value, respectively."
//!
//! UTF-8 decode without BOM is the Encoding Standard's UTF-8 decoder in
//! replacement mode: a byte sequence that is not UTF-8 decodes to U+FFFD,
//! one per maximal subpart - it never fails. A strict validation here made
//! `new URL("http://h/?a=%ff")`, `URL.parse` and `new URLSearchParams("a=%ff")`
//! throw, and an iframe whose src had `%ff` in its query resolved to
//! about:blank and never navigated (mimesniff charset-parameter.window.js).
//! The cases are url/urlencoded-parser.any.js's.

const std = @import("std");
const url_mod = @import("url");
const URLSearchParamsImpl = url_mod.internal.url_search_params_impl.URLSearchParamsImpl;

fn expectFirst(input: []const u8, name: []const u8, value: []const u8) !void {
    var params = try URLSearchParamsImpl.initFromString(std.testing.allocator, input);
    defer params.deinit();
    try std.testing.expect(params.size() >= 1);
    try std.testing.expectEqualStrings(value, params.get(name) orelse return error.NameNotFound);
}

test "bytes that are not UTF-8 decode to U+FFFD, one per maximal subpart" {
    try expectFirst("%FE%FF", "\u{FFFD}\u{FFFD}", "");
    try expectFirst("%FF%FE", "\u{FFFD}\u{FFFD}", "");
    try expectFirst("%C2", "\u{FFFD}", "");
    try expectFirst("%C2x", "\u{FFFD}x", "");
    try expectFirst("_charset_=windows-1252&test=%C2x", "test", "\u{FFFD}x");
    try expectFirst("a=%ff", "a", "\u{FFFD}");
}

test "a truncated or out-of-range sequence replaces what it covers and keeps the byte after it" {
    // E0 needs A0..BF next: 80 is not, so E0 alone is one U+FFFD and 80 another.
    try expectFirst("a=%E0%80x", "a", "\u{FFFD}\u{FFFD}x");
    // ED A0 would start a surrogate: ED is replaced, A0 and 80 each too.
    try expectFirst("a=%ED%A0%80", "a", "\u{FFFD}\u{FFFD}\u{FFFD}");
    // F0 90 80 then the end: one U+FFFD for the maximal subpart.
    try expectFirst("a=%F0%90%80", "a", "\u{FFFD}");
    // F4 90 is past U+10FFFF: F4 is replaced, 90 too.
    try expectFirst("a=%F4%90%80%80", "a", "\u{FFFD}\u{FFFD}\u{FFFD}\u{FFFD}");
}

test "UTF-8 decodes as itself, and a BOM is kept" {
    try expectFirst("a=%C3%A9%E2%82%AC%F0%9F%92%A9", "a", "é€💩");
    try expectFirst("%EF%BB%BFtest=%EF%BB%BF", "\u{FEFF}test", "\u{FEFF}");
}
