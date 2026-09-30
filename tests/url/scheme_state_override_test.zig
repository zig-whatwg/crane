//! The scheme state given a state override (URL § 4.4, scheme state step
//! 2.1): four cases "return" - leave the URL as it is, with no failure -
//! rather than set the scheme. A setter that reports failure (Location's
//! protocol setter throws a SyntaxError on it) must not see one for them.

const std = @import("std");
const url_mod = @import("url");
const parser = url_mod.parser.basic_url_parser;
const ParserState = url_mod.parser.parser_state.ParserState;

/// `input` parsed into `url_string` with the scheme start state as state
/// override: no failure, and the URL serializes as `expected`.
fn expectOverride(url_string: []const u8, input: []const u8, expected_scheme: []const u8) !void {
    const allocator = std.testing.allocator;
    var url = try parser.parse(allocator, url_string, null);
    defer url.deinit();
    _ = try parser.parseWithStateOverride(allocator, input, null, ParserState.scheme_start, &url);
    try std.testing.expectEqualStrings(expected_scheme, url.scheme());
}

test "2.1.1: a special URL keeps its scheme for a non-special one" {
    try expectOverride("http://example.com/", "x:", "http");
    try expectOverride("http://example.com/", "http+x:", "http");
    try expectOverride("http://example.com/", "data:", "http");
}

test "2.1.2: a non-special URL keeps its scheme for a special one" {
    try expectOverride("data:text/html,x", "http:", "data");
    try expectOverride("x:/path", "https:", "x");
}

test "2.1.3: a URL with credentials or a port does not become file" {
    try expectOverride("http://user@example.com/", "file:", "http");
    try expectOverride("http://example.com:8000/", "file:", "http");
}

test "2.1.4: a file URL with an empty host keeps its scheme" {
    try expectOverride("file:///tmp/x", "http:", "file");
}

test "a scheme the override may set is set" {
    try expectOverride("http://example.com/", "https:", "https");
    try expectOverride("http://example.com/", "file:", "file");
    try expectOverride("data:text/html,x", "x:", "x");
}

test "a scheme with a code point the scheme state rejects is failure" {
    const allocator = std.testing.allocator;
    var url = try parser.parse(allocator, "http://example.com/", null);
    defer url.deinit();
    try std.testing.expect(if (parser.parseWithStateOverride(allocator, "ht*tp:", null, ParserState.scheme_start, &url)) |_| false else |_| true);
    try std.testing.expectEqualStrings("http", url.scheme());
}
