//! Tokenizer Tests (Selectors Level 4)
//!
//! Comprehensive test suite for CSS Selector tokenizer.
//! Tests all token types, edge cases, and error handling.

const std = @import("std");
const testing = std.testing;
const tok_mod = @import("../../src/selector/tokenizer.zig");
const Tokenizer = tok_mod.Tokenizer;
const Token = tok_mod.Token;

// ============================================================================
// Basic Token Tests
// ============================================================================

test "Tokenizer: ident token" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "div");

    const tok1 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.ident, tok1.tag);
    try testing.expectEqualStrings("div", tok1.value);

    const tok2 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.eof, tok2.tag);
}

test "Tokenizer: hash token (#id)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "#myId");

    const tok = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.hash, tok.tag);
    try testing.expectEqualStrings("myId", tok.value);
}

test "Tokenizer: dot token" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, ".");

    const tok = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.dot, tok.tag);
}

test "Tokenizer: asterisk token (*)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "*");

    const tok = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.asterisk, tok.tag);
}

test "Tokenizer: string token (double quotes)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "\"hello world\"");

    const tok = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.string, tok.tag);
    try testing.expectEqualStrings("hello world", tok.value);
}

test "Tokenizer: string token (single quotes)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "'hello world'");

    const tok = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.string, tok.tag);
    try testing.expectEqualStrings("hello world", tok.value);
}

test "Tokenizer: whitespace token" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "   ");

    const tok = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.whitespace, tok.tag);
    try testing.expectEqualStrings("   ", tok.value);
}

// ============================================================================
// Combinator Tokens
// ============================================================================

test "Tokenizer: child combinator (>)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, ">");

    const tok = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.gt, tok.tag);
}

test "Tokenizer: next-sibling combinator (+)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "+");

    const tok = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.plus, tok.tag);
}

test "Tokenizer: subsequent-sibling combinator (~)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "~");

    const tok = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.tilde, tok.tag);
}

// ============================================================================
// Attribute Matcher Tokens
// ============================================================================

test "Tokenizer: prefix match (^=)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "^=");

    const tok = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.prefix_match, tok.tag);
}

test "Tokenizer: suffix match ($=)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "$=");

    const tok = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.suffix_match, tok.tag);
}

test "Tokenizer: substring match (*=)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "*=");

    const tok = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.substring_match, tok.tag);
}

test "Tokenizer: includes match (~=)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "~=");

    const tok = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.includes_match, tok.tag);
}

test "Tokenizer: dash match (|=)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "|=");

    const tok = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.dash_match, tok.tag);
}

// ============================================================================
// Delimiter Tokens
// ============================================================================

test "Tokenizer: comma" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, ",");

    const tok = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.comma, tok.tag);
}

test "Tokenizer: parentheses" {
    const allocator = testing.allocator;
    var tokenizer1 = Tokenizer.init(allocator, "(");
    var tokenizer2 = Tokenizer.init(allocator, ")");

    const tok1 = try tokenizer1.nextToken();
    try testing.expectEqual(Token.Tag.lparen, tok1.tag);

    const tok2 = try tokenizer2.nextToken();
    try testing.expectEqual(Token.Tag.rparen, tok2.tag);
}

test "Tokenizer: brackets" {
    const allocator = testing.allocator;
    var tokenizer1 = Tokenizer.init(allocator, "[");
    var tokenizer2 = Tokenizer.init(allocator, "]");

    const tok1 = try tokenizer1.nextToken();
    try testing.expectEqual(Token.Tag.lbracket, tok1.tag);

    const tok2 = try tokenizer2.nextToken();
    try testing.expectEqual(Token.Tag.rbracket, tok2.tag);
}

test "Tokenizer: colon" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, ":");

    const tok = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.colon, tok.tag);
}

test "Tokenizer: equals" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "=");

    const tok = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.equals, tok.tag);
}

// ============================================================================
// Complex Selector Tests
// ============================================================================

test "Tokenizer: simple selector (div.container)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "div.container");

    const tok1 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.ident, tok1.tag);
    try testing.expectEqualStrings("div", tok1.value);

    const tok2 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.dot, tok2.tag);

    const tok3 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.ident, tok3.tag);
    try testing.expectEqualStrings("container", tok3.value);

    const tok4 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.eof, tok4.tag);
}

test "Tokenizer: combinator selector (div > p)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "div > p");

    const tok1 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.ident, tok1.tag);
    try testing.expectEqualStrings("div", tok1.value);

    const tok2 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.whitespace, tok2.tag);

    const tok3 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.gt, tok3.tag);

    const tok4 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.whitespace, tok4.tag);

    const tok5 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.ident, tok5.tag);
    try testing.expectEqualStrings("p", tok5.value);
}

test "Tokenizer: attribute selector ([href^='https'])" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "[href^='https']");

    const tok1 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.lbracket, tok1.tag);

    const tok2 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.ident, tok2.tag);
    try testing.expectEqualStrings("href", tok2.value);

    const tok3 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.prefix_match, tok3.tag);

    const tok4 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.string, tok4.tag);
    try testing.expectEqualStrings("https", tok4.value);

    const tok5 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.rbracket, tok5.tag);
}

test "Tokenizer: pseudo-class selector (:first-child)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, ":first-child");

    const tok1 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.colon, tok1.tag);

    const tok2 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.ident, tok2.tag);
    try testing.expectEqualStrings("first-child", tok2.value);
}

test "Tokenizer: nth-child selector (:nth-child(2n+1))" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, ":nth-child(2n+1)");

    const tok1 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.colon, tok1.tag);

    const tok2 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.ident, tok2.tag);
    try testing.expectEqualStrings("nth-child", tok2.value);

    const tok3 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.lparen, tok3.tag);

    const tok4 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.ident, tok4.tag);
    try testing.expectEqualStrings("2n", tok4.value);

    const tok5 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.plus, tok5.tag);

    const tok6 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.ident, tok6.tag);
    try testing.expectEqualStrings("1", tok6.value);

    const tok7 = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.rparen, tok7.tag);
}

// ============================================================================
// Edge Cases
// ============================================================================

test "Tokenizer: identifier with hyphen (custom-element)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "custom-element");

    const tok = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.ident, tok.tag);
    try testing.expectEqualStrings("custom-element", tok.value);
}

test "Tokenizer: identifier with underscore (my_class)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "my_class");

    const tok = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.ident, tok.tag);
    try testing.expectEqualStrings("my_class", tok.value);
}

test "Tokenizer: identifier starting with hyphen (-webkit-transform)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "-webkit-transform");

    const tok = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.ident, tok.tag);
    try testing.expectEqualStrings("-webkit-transform", tok.value);
}

test "Tokenizer: string with escaped quote" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "\"hello \\\" world\"");

    const tok = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.string, tok.tag);
    // Note: tokenizer doesn't process escapes, just skips them
    try testing.expectEqualStrings("hello \\\" world", tok.value);
}

test "Tokenizer: multiple whitespace types" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, " \t\n\r");

    const tok = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.whitespace, tok.tag);
    try testing.expectEqualStrings(" \t\n\r", tok.value);
}

test "Tokenizer: empty input" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "");

    const tok = try tokenizer.nextToken();
    try testing.expectEqual(Token.Tag.eof, tok.tag);
}

// ============================================================================
// Error Cases
// ============================================================================

test "Tokenizer: unclosed string (double quote)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "\"unclosed");

    try testing.expectError(error.UnexpectedEOF, tokenizer.nextToken());
}

test "Tokenizer: unclosed string (single quote)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "'unclosed");

    try testing.expectError(error.UnexpectedEOF, tokenizer.nextToken());
}

test "Tokenizer: hash without identifier" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "#");

    try testing.expectError(error.UnexpectedToken, tokenizer.nextToken());
}

test "Tokenizer: invalid character" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "@");

    try testing.expectError(error.UnexpectedToken, tokenizer.nextToken());
}

test "Tokenizer: string with unescaped newline" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "\"hello\nworld\"");

    try testing.expectError(error.UnexpectedToken, tokenizer.nextToken());
}

// ============================================================================
// Tokenize Full Selector Tests
// ============================================================================

test "Tokenizer: tokenize() - simple selector" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "div");

    const tokens = try tokenizer.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 2), tokens.len); // ident + eof
    try testing.expectEqual(Token.Tag.ident, tokens[0].tag);
    try testing.expectEqual(Token.Tag.eof, tokens[1].tag);
}

test "Tokenizer: tokenize() - complex selector" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "div.class#id");

    const tokens = try tokenizer.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 6), tokens.len); // div . class # id eof
}

// ============================================================================
// Zero-Copy Verification
// ============================================================================

test "Tokenizer: zero-copy token values" {
    const allocator = testing.allocator;
    const input = "div.container";
    var tokenizer = Tokenizer.init(allocator, input);

    const tok1 = try tokenizer.nextToken();
    // Token value should be a slice into input
    try testing.expect(@intFromPtr(tok1.value.ptr) >= @intFromPtr(input.ptr));
    try testing.expect(@intFromPtr(tok1.value.ptr) < @intFromPtr(input.ptr) + input.len);
}

// ============================================================================
// Position Tracking
// ============================================================================

test "Tokenizer: token position tracking" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "div.container");

    const tok1 = try tokenizer.nextToken();
    try testing.expectEqual(@as(usize, 0), tok1.start);
    try testing.expectEqual(@as(usize, 3), tok1.end);

    const tok2 = try tokenizer.nextToken();
    try testing.expectEqual(@as(usize, 3), tok2.start);
    try testing.expectEqual(@as(usize, 4), tok2.end);

    const tok3 = try tokenizer.nextToken();
    try testing.expectEqual(@as(usize, 4), tok3.start);
    try testing.expectEqual(@as(usize, 13), tok3.end);
}
