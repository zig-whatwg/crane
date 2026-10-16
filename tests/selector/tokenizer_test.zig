//! The selector tokenizer is CSS Syntax 3's (section 4): these pin each
//! token type and the escape, preprocessing and number rules the
//! querySelector WPT files exercise.

const std = @import("std");
const testing = std.testing;
const selector = @import("selector");
const Tokenizer = selector.Tokenizer;
const Token = selector.Token;
const Tag = Token.Tag;

fn expectTags(input: []const u8, tags: []const Tag) !void {
    var tokenizer = Tokenizer.init(testing.allocator, input);
    const tokens = try tokenizer.tokenize();
    defer testing.allocator.free(tokens);
    const got = try testing.allocator.alloc(Tag, tokens.len);
    defer testing.allocator.free(got);
    for (tokens, 0..) |token, i| got[i] = token.tag;
    try testing.expectEqualSlices(Tag, tags, got);
}

fn first(input: []const u8) Token {
    var tokenizer = Tokenizer.init(testing.allocator, input);
    return tokenizer.nextToken() catch unreachable;
}

/// The token's value as the spec defines it.
fn expectValue(token: Token, expected: []const u8) !void {
    if (!token.needs_decode) return testing.expectEqualStrings(expected, token.value);
    const decoded = try selector.tokenizer.decode(testing.allocator, token);
    defer testing.allocator.free(decoded);
    try testing.expectEqualStrings(expected, decoded);
}

test "idents, hashes, strings, delims and punctuation" {
    try expectTags("div.container", &.{ .ident, .delim, .ident, .eof });
    try expectTags("div > p", &.{ .ident, .whitespace, .delim, .whitespace, .ident, .eof });
    try expectTags("[href^='https']", &.{ .lbracket, .ident, .delim, .delim, .string, .rbracket, .eof });
    try expectTags("a, b", &.{ .ident, .comma, .whitespace, .ident, .eof });
    try expectTags(":first-child", &.{ .colon, .ident, .eof });
    try expectTags("{}();", &.{ .lbrace, .rbrace, .lparen, .rparen, .semicolon, .eof });
    try expectTags("<!-- -->", &.{ .cdo, .whitespace, .cdc, .eof });
    try expectTags("", &.{.eof});
    try expectValue(first("custom-element"), "custom-element");
    try expectValue(first("-webkit-transform"), "-webkit-transform");
    try expectValue(first("--green"), "--green");
    try expectValue(first("'hello world'"), "hello world");
    try testing.expect(first("*").isDelim('*'));
    try testing.expect(first("|").isDelim('|'));
}

test "a function token is its name and the open parenthesis" {
    const token = first("nth-child(2n+1)");
    try testing.expectEqual(Tag.function, token.tag);
    try expectValue(token, "nth-child");
    try expectTags(":not(a)", &.{ .colon, .function, .ident, .rparen, .eof });
    // A space before "(" makes an ident and a "(".
    try expectTags("not (a)", &.{ .ident, .whitespace, .lparen, .ident, .rparen, .eof });
}

test "a hash is an id hash only when its name would start an ident" {
    const id = first("#foo");
    try testing.expectEqual(Tag.hash, id.tag);
    try testing.expect(id.hash_is_id);
    try expectValue(id, "foo");
    try testing.expect(first("#--").hash_is_id);
    try testing.expect(!first("#5cm").hash_is_id);
    try testing.expect(!first("#-5").hash_is_id);
    // "#" with no name is a delim.
    try testing.expect(first("#").isDelim('#'));
    try testing.expect(first("# a").isDelim('#'));
}

test "numbers, percentages and dimensions carry value, type and sign" {
    const n = first("+5");
    try testing.expectEqual(Tag.number, n.tag);
    try testing.expectEqual(@as(f64, 5), n.number);
    try testing.expectEqual(Token.Sign.plus, n.sign);
    try testing.expect(n.is_integer);
    const d = first("2n-1");
    try testing.expectEqual(Tag.dimension, d.tag);
    try testing.expectEqual(@as(f64, 2), d.number);
    try expectValue(d, "n-1");
    const cm = first(".5cm");
    try testing.expectEqual(Tag.dimension, cm.tag);
    try testing.expect(!cm.is_integer);
    try testing.expectEqual(Tag.percentage, first("50%").tag);
    try testing.expect(!first("1e3").is_integer);
    // 2n+1: a dimension "2n" and a signed number "+1".
    try expectTags("2n+1", &.{ .dimension, .number, .eof });
    try expectTags("-n-1", &.{ .ident, .eof });
    try expectTags("+ 2", &.{ .delim, .whitespace, .number, .eof });
}

test "CSS escapes decode per consume an escaped code point" {
    try expectValue(first("\\30 x"), "0x");
    try expectValue(first("\\30x"), "0x");
    try expectValue(first("\\000030x"), "0x");
    try expectValue(first("hel\\6Co"), "hello");
    try expectValue(first("\\.comma"), ".comma");
    try expectValue(first("\\g"), "g");
    // Zero, a surrogate and a value past U+10FFFF are U+FFFD.
    try expectValue(first("zero\\0"), "zero\u{FFFD}");
    try expectValue(first("s\\d83d"), "s\u{FFFD}");
    try expectValue(first("big\\110000"), "big\u{FFFD}");
    try expectValue(first("\\10fFfF0"), "\u{10FFFF}0");
    // CRLF after a hex escape is one whitespace; FF and TAB are whitespace.
    try expectValue(first("spac\\65\r\ns"), "spaces");
    try expectValue(first("sp\\61\tc\\65\x0Cs"), "spaces");
    // "\" at the end of the input is a valid escape: U+FFFD.
    try expectValue(first("eof\\"), "eof\u{FFFD}");
    try expectValue(first("#eof\\"), "eof\u{FFFD}");
    // An escaped space keeps the ident going.
    try expectValue(first("spaces\\ in"), "spaces in");
    // "\" before a newline is no escape: a delim.
    try testing.expect(first("\\\nx").isDelim('\\'));
}

test "preprocessing: NUL and an encoded surrogate are U+FFFD ident code points" {
    try expectValue(first("ab\x00c"), "ab\u{FFFD}c");
    try expectValue(first("#\x00"), "\u{FFFD}");
    // A lone surrogate a DOMString carries as WTF-8.
    try expectValue(first("a\xED\xA0\xBDb"), "a\u{FFFD}b");
}

test "every non-ASCII code point is an ident code point, as in all three engines" {
    try expectValue(first("#\u{A0}"), "\u{A0}");
    try expectValue(first("#\u{2003}"), "\u{2003}");
    try expectValue(first("\u{1F511}x"), "\u{1F511}x");
}

test "strings: escapes, line continuations, EOF and newlines" {
    try expectValue(first("\"a\\\"b\""), "a\"b");
    try expectValue(first("\"\\e9\""), "\u{E9}");
    try expectValue(first("\"\\0000e9\""), "\u{E9}");
    try expectValue(first("\"a\\\nb\""), "ab");
    try expectValue(first("\"a\\\r\nb\""), "ab");
    // Cut off by the end of the input: still a string, and "\" at the end
    // is dropped.
    const unclosed = first("\"center");
    try testing.expectEqual(Tag.string, unclosed.tag);
    try expectValue(unclosed, "center");
    try expectValue(first("'a\\"), "a");
    // A raw newline makes a bad string.
    try expectTags("\"a\nb\"", &.{ .bad_string, .whitespace, .ident, .string, .eof });
}

test "comments produce no token" {
    try expectTags("a/* x */b", &.{ .ident, .ident, .eof });
    try expectTags("a /**/ b", &.{ .ident, .whitespace, .whitespace, .ident, .eof });
    try expectTags("a/* open", &.{ .ident, .eof });
}

test "url() makes a url token unless its argument is quoted" {
    const url = first("url( a.png )");
    try testing.expectEqual(Tag.url, url.tag);
    try expectValue(url, "a.png");
    try testing.expectEqual(Tag.function, first("url('a')").tag);
    try testing.expectEqual(Tag.bad_url, first("url(a b)").tag);
}

test "a delim is any other code point" {
    for ("!$%&*+-./<=>?^|~") |c| {
        const input = [_]u8{c};
        try testing.expect(first(&input).isDelim(c));
    }
    try testing.expect(first("@").isDelim('@'));
    try testing.expectEqual(Tag.at_keyword, first("@media").tag);
}

test "positions and zero-copy values" {
    const input = "div.container";
    var tokenizer = Tokenizer.init(testing.allocator, input);
    const a = try tokenizer.nextToken();
    try testing.expectEqual(@as(usize, 0), a.start);
    try testing.expectEqual(@as(usize, 3), a.end);
    try testing.expect(a.value.ptr == input.ptr);
    const b = try tokenizer.nextToken();
    try testing.expectEqual(@as(usize, 3), b.start);
    try testing.expectEqual(@as(usize, 4), b.end);
    const c = try tokenizer.nextToken();
    try testing.expectEqual(@as(usize, 13), c.end);
    try testing.expect(!c.needs_decode);
}
