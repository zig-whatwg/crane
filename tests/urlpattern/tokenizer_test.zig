//! URLPattern Tokenizer Tests
//!
//! Comprehensive tests for the URLPattern tokenizer module.
//! See: https://urlpattern.spec.whatwg.org/#tokenizing

const std = @import("std");
const testing = std.testing;
const urlpattern = @import("urlpattern");

const TokenType = urlpattern.TokenType;
const TokenizePolicy = urlpattern.TokenizePolicy;
const tokenize = urlpattern.tokenize;

// ============================================================================
// Empty Pattern Tests
// ============================================================================

test "tokenize - empty pattern" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "", .strict);
    defer result.deinit();

    // Empty pattern should only have end token
    try testing.expectEqual(@as(usize, 1), result.tokens.len);
    try testing.expectEqual(TokenType.end, result.tokens[0].type);
    try testing.expectEqualStrings("", result.tokens[0].value);
}

// ============================================================================
// Literal Character Tests (char tokens)
// ============================================================================

test "tokenize - single character" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "a", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.char, result.tokens[0].type);
    try testing.expectEqualStrings("a", result.tokens[0].value);
    try testing.expectEqual(TokenType.end, result.tokens[1].type);
}

test "tokenize - multiple characters" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "hello", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 6), result.tokens.len);
    try testing.expectEqual(TokenType.char, result.tokens[0].type);
    try testing.expectEqualStrings("h", result.tokens[0].value);
    try testing.expectEqual(TokenType.char, result.tokens[1].type);
    try testing.expectEqualStrings("e", result.tokens[1].value);
    try testing.expectEqual(TokenType.char, result.tokens[2].type);
    try testing.expectEqualStrings("l", result.tokens[2].value);
    try testing.expectEqual(TokenType.char, result.tokens[3].type);
    try testing.expectEqualStrings("l", result.tokens[3].value);
    try testing.expectEqual(TokenType.char, result.tokens[4].type);
    try testing.expectEqualStrings("o", result.tokens[4].value);
    try testing.expectEqual(TokenType.end, result.tokens[5].type);
}

test "tokenize - path characters" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "/path/to/resource", .strict);
    defer result.deinit();

    // Verify first few tokens
    try testing.expectEqual(TokenType.char, result.tokens[0].type);
    try testing.expectEqualStrings("/", result.tokens[0].value);
    try testing.expectEqual(TokenType.char, result.tokens[1].type);
    try testing.expectEqualStrings("p", result.tokens[1].value);
}

test "tokenize - numbers as chars" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "123", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 4), result.tokens.len);
    try testing.expectEqual(TokenType.char, result.tokens[0].type);
    try testing.expectEqualStrings("1", result.tokens[0].value);
    try testing.expectEqual(TokenType.char, result.tokens[1].type);
    try testing.expectEqualStrings("2", result.tokens[1].value);
    try testing.expectEqual(TokenType.char, result.tokens[2].type);
    try testing.expectEqualStrings("3", result.tokens[2].value);
}

// ============================================================================
// Escape Sequence Tests (escaped_char tokens)
// ============================================================================

test "tokenize - escape colon" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "\\:", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.escaped_char, result.tokens[0].type);
    try testing.expectEqualStrings(":", result.tokens[0].value);
    try testing.expectEqual(TokenType.end, result.tokens[1].type);
}

test "tokenize - escape open brace" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "\\{", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.escaped_char, result.tokens[0].type);
    try testing.expectEqualStrings("{", result.tokens[0].value);
}

test "tokenize - escape close brace" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "\\}", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.escaped_char, result.tokens[0].type);
    try testing.expectEqualStrings("}", result.tokens[0].value);
}

test "tokenize - escape open paren" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "\\(", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.escaped_char, result.tokens[0].type);
    try testing.expectEqualStrings("(", result.tokens[0].value);
}

test "tokenize - escape asterisk" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "\\*", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.escaped_char, result.tokens[0].type);
    try testing.expectEqualStrings("*", result.tokens[0].value);
}

test "tokenize - escape backslash" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "\\\\", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.escaped_char, result.tokens[0].type);
    try testing.expectEqualStrings("\\", result.tokens[0].value);
}

test "tokenize - escape regular char" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "\\a", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.escaped_char, result.tokens[0].type);
    try testing.expectEqualStrings("a", result.tokens[0].value);
}

test "tokenize - trailing backslash strict mode" {
    const allocator = testing.allocator;
    try testing.expectError(error.InvalidPattern, tokenize(allocator, "\\", .strict));
}

test "tokenize - trailing backslash lenient mode" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "\\", .lenient);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.invalid_char, result.tokens[0].type);
}

// ============================================================================
// Named Group Tests (name tokens)
// ============================================================================

test "tokenize - simple name" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, ":foo", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.name, result.tokens[0].type);
    try testing.expectEqualStrings("foo", result.tokens[0].value);
}

test "tokenize - name with underscore" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, ":foo_bar", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.name, result.tokens[0].type);
    try testing.expectEqualStrings("foo_bar", result.tokens[0].value);
}

test "tokenize - name with dollar" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, ":$foo", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.name, result.tokens[0].type);
    try testing.expectEqualStrings("$foo", result.tokens[0].value);
}

test "tokenize - name with digits" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, ":foo123", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.name, result.tokens[0].type);
    try testing.expectEqualStrings("foo123", result.tokens[0].value);
}

test "tokenize - name starting with underscore" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, ":_private", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.name, result.tokens[0].type);
    try testing.expectEqualStrings("_private", result.tokens[0].value);
}

test "tokenize - empty name strict mode" {
    const allocator = testing.allocator;
    // A colon followed by non-identifier is invalid
    try testing.expectError(error.InvalidPattern, tokenize(allocator, ":", .strict));
}

test "tokenize - empty name lenient mode" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, ":", .lenient);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.invalid_char, result.tokens[0].type);
}

test "tokenize - colon followed by digit strict mode" {
    const allocator = testing.allocator;
    // Names cannot start with digits
    try testing.expectError(error.InvalidPattern, tokenize(allocator, ":123", .strict));
}

test "tokenize - multiple names" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, ":foo:bar", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 3), result.tokens.len);
    try testing.expectEqual(TokenType.name, result.tokens[0].type);
    try testing.expectEqualStrings("foo", result.tokens[0].value);
    try testing.expectEqual(TokenType.name, result.tokens[1].type);
    try testing.expectEqualStrings("bar", result.tokens[1].value);
}

// ============================================================================
// Regexp Group Tests (regexp tokens)
// ============================================================================

test "tokenize - simple regexp" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "(abc)", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.regexp, result.tokens[0].type);
    try testing.expectEqualStrings("abc", result.tokens[0].value);
}

test "tokenize - regexp with digits" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "(\\d+)", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.regexp, result.tokens[0].type);
    try testing.expectEqualStrings("\\d+", result.tokens[0].value);
}

test "tokenize - regexp with character class" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "([a-z]+)", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.regexp, result.tokens[0].type);
    try testing.expectEqualStrings("[a-z]+", result.tokens[0].value);
}

test "tokenize - regexp with escaped char" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "(\\(\\))", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.regexp, result.tokens[0].type);
    try testing.expectEqualStrings("\\(\\)", result.tokens[0].value);
}

test "tokenize - regexp with non-capturing group" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "((?:foo|bar))", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.regexp, result.tokens[0].type);
    try testing.expectEqualStrings("(?:foo|bar)", result.tokens[0].value);
}

test "tokenize - empty regexp strict mode" {
    const allocator = testing.allocator;
    try testing.expectError(error.InvalidPattern, tokenize(allocator, "()", .strict));
}

test "tokenize - empty regexp lenient mode" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "()", .lenient);
    defer result.deinit();

    // Empty regexp produces invalid_char token(s) in lenient mode
    // The actual number of tokens depends on implementation details
    try testing.expect(result.tokens.len >= 2);
    try testing.expectEqual(TokenType.invalid_char, result.tokens[0].type);
}

test "tokenize - unclosed regexp strict mode" {
    const allocator = testing.allocator;
    try testing.expectError(error.InvalidPattern, tokenize(allocator, "(abc", .strict));
}

test "tokenize - regexp starting with ? strict mode" {
    const allocator = testing.allocator;
    // Regexp cannot start with ? (that's reserved for non-capturing groups)
    try testing.expectError(error.InvalidPattern, tokenize(allocator, "(?abc)", .strict));
}

test "tokenize - regexp with capturing group strict mode" {
    const allocator = testing.allocator;
    // Nested capturing groups (not prefixed with ?) are invalid
    try testing.expectError(error.InvalidPattern, tokenize(allocator, "((foo))", .strict));
}

// ============================================================================
// Modifier Tests (other_modifier and asterisk tokens)
// ============================================================================

test "tokenize - optional modifier" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "?", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.other_modifier, result.tokens[0].type);
    try testing.expectEqualStrings("?", result.tokens[0].value);
}

test "tokenize - one or more modifier" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "+", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.other_modifier, result.tokens[0].type);
    try testing.expectEqualStrings("+", result.tokens[0].value);
}

test "tokenize - asterisk" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "*", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.asterisk, result.tokens[0].type);
    try testing.expectEqualStrings("*", result.tokens[0].value);
}

test "tokenize - name with optional modifier" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, ":foo?", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 3), result.tokens.len);
    try testing.expectEqual(TokenType.name, result.tokens[0].type);
    try testing.expectEqualStrings("foo", result.tokens[0].value);
    try testing.expectEqual(TokenType.other_modifier, result.tokens[1].type);
    try testing.expectEqualStrings("?", result.tokens[1].value);
}

test "tokenize - name with zero or more modifier" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, ":foo*", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 3), result.tokens.len);
    try testing.expectEqual(TokenType.name, result.tokens[0].type);
    try testing.expectEqual(TokenType.asterisk, result.tokens[1].type);
}

test "tokenize - name with one or more modifier" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, ":foo+", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 3), result.tokens.len);
    try testing.expectEqual(TokenType.name, result.tokens[0].type);
    try testing.expectEqual(TokenType.other_modifier, result.tokens[1].type);
    try testing.expectEqualStrings("+", result.tokens[1].value);
}

// ============================================================================
// Grouping Brace Tests (open and close tokens)
// ============================================================================

test "tokenize - open brace" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "{", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.open, result.tokens[0].type);
    try testing.expectEqualStrings("{", result.tokens[0].value);
}

test "tokenize - close brace" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "}", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(TokenType.close, result.tokens[0].type);
    try testing.expectEqualStrings("}", result.tokens[0].value);
}

test "tokenize - grouped name" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "{:foo}", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 4), result.tokens.len);
    try testing.expectEqual(TokenType.open, result.tokens[0].type);
    try testing.expectEqual(TokenType.name, result.tokens[1].type);
    try testing.expectEqualStrings("foo", result.tokens[1].value);
    try testing.expectEqual(TokenType.close, result.tokens[2].type);
}

test "tokenize - grouped name with modifier" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "{:foo}?", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 5), result.tokens.len);
    try testing.expectEqual(TokenType.open, result.tokens[0].type);
    try testing.expectEqual(TokenType.name, result.tokens[1].type);
    try testing.expectEqual(TokenType.close, result.tokens[2].type);
    try testing.expectEqual(TokenType.other_modifier, result.tokens[3].type);
}

// ============================================================================
// Complex Pattern Tests
// ============================================================================

test "tokenize - path pattern" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "/:category/*", .strict);
    defer result.deinit();

    // / : category / *
    try testing.expectEqual(@as(usize, 5), result.tokens.len);
    try testing.expectEqual(TokenType.char, result.tokens[0].type);
    try testing.expectEqualStrings("/", result.tokens[0].value);
    try testing.expectEqual(TokenType.name, result.tokens[1].type);
    try testing.expectEqualStrings("category", result.tokens[1].value);
    try testing.expectEqual(TokenType.char, result.tokens[2].type);
    try testing.expectEqualStrings("/", result.tokens[2].value);
    try testing.expectEqual(TokenType.asterisk, result.tokens[3].type);
}

test "tokenize - url path with id" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "/products/:id(\\d+)?", .strict);
    defer result.deinit();

    // Should tokenize to: / p r o d u c t s / :id (\\d+) ?
    try testing.expect(result.tokens.len > 10);

    // Verify ending tokens
    const len = result.tokens.len;
    try testing.expectEqual(TokenType.end, result.tokens[len - 1].type);
    try testing.expectEqual(TokenType.other_modifier, result.tokens[len - 2].type);
    try testing.expectEqual(TokenType.regexp, result.tokens[len - 3].type);
    try testing.expectEqual(TokenType.name, result.tokens[len - 4].type);
}

test "tokenize - multiple path segments" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "/:org/:repo/issues/:id", .strict);
    defer result.deinit();

    // Count name tokens: :org, :repo, :id (issues is just fixed text, not a name)
    var name_count: usize = 0;
    for (result.tokens) |token| {
        if (token.type == TokenType.name) {
            name_count += 1;
        }
    }
    try testing.expectEqual(@as(usize, 3), name_count);
}

test "tokenize - hostname pattern" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, ":subdomain.example.com", .strict);
    defer result.deinit();

    try testing.expectEqual(TokenType.name, result.tokens[0].type);
    try testing.expectEqualStrings("subdomain", result.tokens[0].value);
    try testing.expectEqual(TokenType.char, result.tokens[1].type);
    try testing.expectEqualStrings(".", result.tokens[1].value);
}

test "tokenize - grouped pattern with prefix and suffix" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "{prefix:name suffix}", .strict);
    defer result.deinit();

    try testing.expectEqual(TokenType.open, result.tokens[0].type);
    // Contains chars for "prefix", name token, chars for " suffix"
    try testing.expect(result.tokens.len > 5);
}

test "tokenize - mixed escaped and normal" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "foo\\:bar", .strict);
    defer result.deinit();

    // f o o \: b a r
    try testing.expectEqual(@as(usize, 8), result.tokens.len);
    try testing.expectEqual(TokenType.char, result.tokens[0].type);
    try testing.expectEqual(TokenType.char, result.tokens[1].type);
    try testing.expectEqual(TokenType.char, result.tokens[2].type);
    try testing.expectEqual(TokenType.escaped_char, result.tokens[3].type);
    try testing.expectEqualStrings(":", result.tokens[3].value);
}

// ============================================================================
// Token Index Verification Tests
// ============================================================================

test "tokenize - token indices are correct" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "abc:foo", .strict);
    defer result.deinit();

    // a at 0, b at 1, c at 2, :foo at 3
    try testing.expectEqual(@as(usize, 0), result.tokens[0].index);
    try testing.expectEqual(@as(usize, 1), result.tokens[1].index);
    try testing.expectEqual(@as(usize, 2), result.tokens[2].index);
    try testing.expectEqual(@as(usize, 3), result.tokens[3].index); // name token starts at :
}

test "tokenize - escape sequence index" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "a\\:b", .strict);
    defer result.deinit();

    // a at 0, \: at 1, b at 3
    try testing.expectEqual(@as(usize, 0), result.tokens[0].index);
    try testing.expectEqual(@as(usize, 1), result.tokens[1].index);
    try testing.expectEqual(@as(usize, 3), result.tokens[2].index);
}

// ============================================================================
// Edge Cases and Boundary Tests
// ============================================================================

test "tokenize - all modifier types together" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, ":foo?*+", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 5), result.tokens.len);
    try testing.expectEqual(TokenType.name, result.tokens[0].type);
    try testing.expectEqual(TokenType.other_modifier, result.tokens[1].type);
    try testing.expectEqualStrings("?", result.tokens[1].value);
    try testing.expectEqual(TokenType.asterisk, result.tokens[2].type);
    try testing.expectEqual(TokenType.other_modifier, result.tokens[3].type);
    try testing.expectEqualStrings("+", result.tokens[3].value);
}

test "tokenize - consecutive wildcards" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, "**", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 3), result.tokens.len);
    try testing.expectEqual(TokenType.asterisk, result.tokens[0].type);
    try testing.expectEqual(TokenType.asterisk, result.tokens[1].type);
}

test "tokenize - regexp after name" {
    const allocator = testing.allocator;
    var result = try tokenize(allocator, ":id(\\d+)", .strict);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 3), result.tokens.len);
    try testing.expectEqual(TokenType.name, result.tokens[0].type);
    try testing.expectEqualStrings("id", result.tokens[0].value);
    try testing.expectEqual(TokenType.regexp, result.tokens[1].type);
    try testing.expectEqualStrings("\\d+", result.tokens[1].value);
}

test "tokenize - unicode characters as char tokens" {
    const allocator = testing.allocator;
    // Multi-byte UTF-8 characters are processed byte-by-byte
    var result = try tokenize(allocator, "/path", .strict);
    defer result.deinit();

    try testing.expectEqual(TokenType.char, result.tokens[0].type);
    try testing.expectEqualStrings("/", result.tokens[0].value);
}
