//! WebIDL Lexer (Tokenizer)
//!
//! Converts WebIDL source code into a stream of tokens for parsing.
//!
//! ## Example
//!
//! ```zig
//! const source = "[Exposed=*]\ninterface Event { constructor(); };";
//! var lexer = Lexer.init(source);
//!
//! while (true) {
//!     const token = try lexer.nextToken();
//!     if (token.type == .eof) break;
//!     std.debug.print("{s} ", .{token.lexeme});
//! }
//! ```

const std = @import("std");

/// Token type enumeration
pub const TokenType = enum {
    // Keywords
    keyword_interface,
    keyword_namespace,
    keyword_partial,
    keyword_mixin,
    keyword_callback,
    keyword_dictionary,
    keyword_enum,
    keyword_typedef,
    keyword_includes,
    keyword_const,
    keyword_attribute,
    keyword_readonly,
    keyword_static,
    keyword_constructor,
    keyword_undefined,
    keyword_optional,
    keyword_sequence,
    keyword_record,
    keyword_true,
    keyword_false,
    keyword_null,
    keyword_or,
    keyword_any,
    keyword_getter,
    keyword_setter,
    keyword_deleter,
    keyword_stringifier,
    keyword_iterable,
    keyword_async_iterable,
    keyword_maplike,
    keyword_setlike,
    keyword_inherit,

    // Identifiers and types
    identifier,

    // Symbols
    left_brace, // {
    right_brace, // }
    left_bracket, // [
    right_bracket, // ]
    left_paren, // (
    right_paren, // (
    semicolon, // ;
    comma, // ,
    equals, // =
    colon, // :
    question, // ?
    ellipsis, // ...
    left_angle, // <
    right_angle, // >
    pipe, // |

    // Literals
    integer_literal,
    float_literal,
    string_literal,

    // Special
    eof,
};

/// Token with location information
pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: usize,
    column: usize,
};

/// WebIDL Lexer
pub const Lexer = struct {
    source: []const u8,
    current: usize = 0,
    line: usize = 1,
    column: usize = 1,

    pub fn init(source: []const u8) Lexer {
        return .{ .source = source };
    }

    /// Get the next token from the source
    pub fn nextToken(self: *Lexer) !Token {
        self.skipWhitespaceAndComments();

        if (self.isAtEnd()) {
            return Token{
                .type = .eof,
                .lexeme = "",
                .line = self.line,
                .column = self.column,
            };
        }

        const start = self.current;
        const start_line = self.line;
        const start_column = self.column;
        const c = self.advance();

        // Identifiers and keywords
        if (isIdentifierStart(c)) {
            while (!self.isAtEnd() and isIdentifierChar(self.peek())) {
                _ = self.advance();
            }
            const lexeme = self.source[start..self.current];
            const token_type = getKeyword(lexeme) orelse .identifier;
            return Token{
                .type = token_type,
                .lexeme = lexeme,
                .line = start_line,
                .column = start_column,
            };
        }

        // Numbers (decimal, hexadecimal, and floating point)
        // Handle negative numbers: '-' followed by digit
        const is_negative = c == '-' and !self.isAtEnd() and std.ascii.isDigit(self.peek());
        if (std.ascii.isDigit(c) or is_negative) {
            var is_float = false;
            var first_digit = c;

            if (is_negative) {
                first_digit = self.advance(); // consume digit after '-'
            }

            // Check for hexadecimal (0x...)
            if (first_digit == '0' and !self.isAtEnd() and (self.peek() == 'x' or self.peek() == 'X')) {
                _ = self.advance(); // consume 'x'
                // Consume hex digits
                while (!self.isAtEnd() and std.ascii.isHex(self.peek())) {
                    _ = self.advance();
                }
            } else {
                // Decimal number
                while (!self.isAtEnd() and std.ascii.isDigit(self.peek())) {
                    _ = self.advance();
                }

                // Check for decimal point (float)
                if (!self.isAtEnd() and self.peek() == '.' and
                    self.current + 1 < self.source.len and std.ascii.isDigit(self.source[self.current + 1]))
                {
                    is_float = true;
                    _ = self.advance(); // consume '.'
                    while (!self.isAtEnd() and std.ascii.isDigit(self.peek())) {
                        _ = self.advance();
                    }
                }

                // Check for exponent (e or E)
                if (!self.isAtEnd() and (self.peek() == 'e' or self.peek() == 'E')) {
                    is_float = true;
                    _ = self.advance(); // consume 'e'/'E'
                    if (!self.isAtEnd() and (self.peek() == '+' or self.peek() == '-')) {
                        _ = self.advance(); // consume sign
                    }
                    while (!self.isAtEnd() and std.ascii.isDigit(self.peek())) {
                        _ = self.advance();
                    }
                }
            }

            return Token{
                .type = if (is_float) .float_literal else .integer_literal,
                .lexeme = self.source[start..self.current],
                .line = start_line,
                .column = start_column,
            };
        }

        // String literals
        if (c == '"' or c == '\'') {
            const quote = c;
            while (!self.isAtEnd() and self.peek() != quote) {
                if (self.peek() == '\n') {
                    self.line += 1;
                    self.column = 0;
                }
                _ = self.advance();
            }

            if (self.isAtEnd()) {
                return error.UnterminatedString;
            }

            _ = self.advance(); // Closing quote
            return Token{
                .type = .string_literal,
                .lexeme = self.source[start..self.current],
                .line = start_line,
                .column = start_column,
            };
        }

        // Multi-character symbols
        if (c == '.') {
            if (!self.isAtEnd() and self.peek() == '.') {
                _ = self.advance();
                if (!self.isAtEnd() and self.peek() == '.') {
                    _ = self.advance();
                    return Token{
                        .type = .ellipsis,
                        .lexeme = self.source[start..self.current],
                        .line = start_line,
                        .column = start_column,
                    };
                }
            }
            return error.InvalidCharacter;
        }

        // Single-character symbols
        const token_type: TokenType = switch (c) {
            '{' => .left_brace,
            '}' => .right_brace,
            '[' => .left_bracket,
            ']' => .right_bracket,
            '(' => .left_paren,
            ')' => .right_paren,
            ';' => .semicolon,
            ',' => .comma,
            '=' => .equals,
            ':' => .colon,
            '?' => .question,
            '<' => .left_angle,
            '>' => .right_angle,
            '|' => .pipe,
            else => return error.InvalidCharacter,
        };

        return Token{
            .type = token_type,
            .lexeme = self.source[start..self.current],
            .line = start_line,
            .column = start_column,
        };
    }

    /// Peek at the next token without consuming it
    pub fn peekToken(self: *Lexer) !Token {
        const saved_current = self.current;
        const saved_line = self.line;
        const saved_column = self.column;

        const token = try self.nextToken();

        self.current = saved_current;
        self.line = saved_line;
        self.column = saved_column;

        return token;
    }

    /// Skip whitespace and comments
    fn skipWhitespaceAndComments(self: *Lexer) void {
        while (!self.isAtEnd()) {
            const c = self.peek();

            switch (c) {
                ' ', '\r', '\t' => {
                    _ = self.advance();
                },
                '\n' => {
                    _ = self.advance();
                    self.line += 1;
                    self.column = 1;
                },
                '/' => {
                    if (self.current + 1 < self.source.len) {
                        if (self.source[self.current + 1] == '/') {
                            // Line comment: // ...
                            while (!self.isAtEnd() and self.peek() != '\n') {
                                _ = self.advance();
                            }
                        } else if (self.source[self.current + 1] == '*') {
                            // Block comment: /* ... */
                            _ = self.advance(); // Skip '/'
                            _ = self.advance(); // Skip '*'

                            while (!self.isAtEnd()) {
                                if (self.peek() == '\n') {
                                    _ = self.advance();
                                    self.line += 1;
                                    self.column = 1;
                                } else if (self.peek() == '*' and
                                    self.current + 1 < self.source.len and
                                    self.source[self.current + 1] == '/')
                                {
                                    _ = self.advance(); // Skip '*'
                                    _ = self.advance(); // Skip '/'
                                    break;
                                } else {
                                    _ = self.advance();
                                }
                            }
                        } else {
                            break;
                        }
                    } else {
                        break;
                    }
                },
                '#' => {
                    // Preprocessor directive (legacy C-style): #ifndef, #define, #endif, etc.
                    // Skip the entire line
                    while (!self.isAtEnd() and self.peek() != '\n') {
                        _ = self.advance();
                    }
                },
                else => break,
            }
        }
    }

    /// Check if we've reached the end of source
    fn isAtEnd(self: *Lexer) bool {
        return self.current >= self.source.len;
    }

    /// Peek at current character without advancing
    fn peek(self: *Lexer) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.current];
    }

    /// Advance to next character
    fn advance(self: *Lexer) u8 {
        const c = self.source[self.current];
        self.current += 1;
        self.column += 1;
        return c;
    }
};

/// Check if character is valid identifier start
fn isIdentifierStart(c: u8) bool {
    return (c >= 'a' and c <= 'z') or
        (c >= 'A' and c <= 'Z') or
        c == '_' or
        c == '*'; // WebIDL allows * in extended attributes (e.g., Exposed=*)
}

/// Check if character is valid identifier continuation
fn isIdentifierChar(c: u8) bool {
    return isIdentifierStart(c) or (c >= '0' and c <= '9') or c == '-'; // Allow hyphens in type names
}

/// Check if identifier is a keyword
fn getKeyword(lexeme: []const u8) ?TokenType {
    const keywords = std.StaticStringMap(TokenType).initComptime(.{
        .{ "interface", .keyword_interface },
        .{ "namespace", .keyword_namespace },
        .{ "partial", .keyword_partial },
        .{ "mixin", .keyword_mixin },
        .{ "callback", .keyword_callback },
        .{ "dictionary", .keyword_dictionary },
        .{ "enum", .keyword_enum },
        .{ "typedef", .keyword_typedef },
        .{ "includes", .keyword_includes },
        .{ "const", .keyword_const },
        .{ "attribute", .keyword_attribute },
        .{ "readonly", .keyword_readonly },
        .{ "static", .keyword_static },
        .{ "constructor", .keyword_constructor },
        .{ "undefined", .keyword_undefined },
        .{ "optional", .keyword_optional },
        .{ "sequence", .keyword_sequence },
        .{ "record", .keyword_record },
        .{ "true", .keyword_true },
        .{ "false", .keyword_false },
        .{ "null", .keyword_null },
        .{ "or", .keyword_or },
        .{ "any", .keyword_any },
        .{ "getter", .keyword_getter },
        .{ "setter", .keyword_setter },
        .{ "deleter", .keyword_deleter },
        .{ "stringifier", .keyword_stringifier },
        .{ "iterable", .keyword_iterable },
        .{ "async_iterable", .keyword_async_iterable },
        .{ "maplike", .keyword_maplike },
        .{ "setlike", .keyword_setlike },
        .{ "inherit", .keyword_inherit },
    });

    return keywords.get(lexeme);
}

// Tests
const testing = std.testing;

test "lexer: keywords" {
    const source = "interface partial mixin callback dictionary";
    var lexer = Lexer.init(source);

    const token1 = try lexer.nextToken();
    try testing.expectEqual(TokenType.keyword_interface, token1.type);
    try testing.expectEqualStrings("interface", token1.lexeme);

    const token2 = try lexer.nextToken();
    try testing.expectEqual(TokenType.keyword_partial, token2.type);

    const token3 = try lexer.nextToken();
    try testing.expectEqual(TokenType.keyword_mixin, token3.type);

    const token4 = try lexer.nextToken();
    try testing.expectEqual(TokenType.keyword_callback, token4.type);

    const token5 = try lexer.nextToken();
    try testing.expectEqual(TokenType.keyword_dictionary, token5.type);

    const token6 = try lexer.nextToken();
    try testing.expectEqual(TokenType.eof, token6.type);
}

test "lexer: identifiers" {
    const source = "EventTarget DOMString foo_bar";
    var lexer = Lexer.init(source);

    const token1 = try lexer.nextToken();
    try testing.expectEqual(TokenType.identifier, token1.type);
    try testing.expectEqualStrings("EventTarget", token1.lexeme);

    const token2 = try lexer.nextToken();
    try testing.expectEqual(TokenType.identifier, token2.type);
    try testing.expectEqualStrings("DOMString", token2.lexeme);

    const token3 = try lexer.nextToken();
    try testing.expectEqual(TokenType.identifier, token3.type);
    try testing.expectEqualStrings("foo_bar", token3.lexeme);
}

test "lexer: symbols" {
    const source = "{ } [ ] ( ) ; , = : ? < > | ...";
    var lexer = Lexer.init(source);

    const expected = [_]TokenType{
        .left_brace,
        .right_brace,
        .left_bracket,
        .right_bracket,
        .left_paren,
        .right_paren,
        .semicolon,
        .comma,
        .equals,
        .colon,
        .question,
        .left_angle,
        .right_angle,
        .pipe,
        .ellipsis,
    };

    for (expected) |expected_type| {
        const token = try lexer.nextToken();
        try testing.expectEqual(expected_type, token.type);
    }
}

test "lexer: numbers" {
    const source = "0 1 42 9999";
    var lexer = Lexer.init(source);

    const token1 = try lexer.nextToken();
    try testing.expectEqual(TokenType.integer_literal, token1.type);
    try testing.expectEqualStrings("0", token1.lexeme);

    const token2 = try lexer.nextToken();
    try testing.expectEqual(TokenType.integer_literal, token2.type);
    try testing.expectEqualStrings("1", token2.lexeme);

    const token3 = try lexer.nextToken();
    try testing.expectEqual(TokenType.integer_literal, token3.type);
    try testing.expectEqualStrings("42", token3.lexeme);

    const token4 = try lexer.nextToken();
    try testing.expectEqual(TokenType.integer_literal, token4.type);
    try testing.expectEqualStrings("9999", token4.lexeme);
}

test "lexer: strings" {
    const source =
        \\"hello" 'world'
    ;
    var lexer = Lexer.init(source);

    const token1 = try lexer.nextToken();
    try testing.expectEqual(TokenType.string_literal, token1.type);
    try testing.expectEqualStrings("\"hello\"", token1.lexeme);

    const token2 = try lexer.nextToken();
    try testing.expectEqual(TokenType.string_literal, token2.type);
    try testing.expectEqualStrings("'world'", token2.lexeme);
}

test "lexer: comments" {
    const source =
        \\// This is a comment
        \\interface Event {
        \\  // Another comment
        \\  constructor();
        \\};
    ;
    var lexer = Lexer.init(source);

    const token1 = try lexer.nextToken();
    try testing.expectEqual(TokenType.keyword_interface, token1.type);

    const token2 = try lexer.nextToken();
    try testing.expectEqual(TokenType.identifier, token2.type);
    try testing.expectEqualStrings("Event", token2.lexeme);

    const token3 = try lexer.nextToken();
    try testing.expectEqual(TokenType.left_brace, token3.type);

    const token4 = try lexer.nextToken();
    try testing.expectEqual(TokenType.keyword_constructor, token4.type);

    const token5 = try lexer.nextToken();
    try testing.expectEqual(TokenType.left_paren, token5.type);

    const token6 = try lexer.nextToken();
    try testing.expectEqual(TokenType.right_paren, token6.type);

    const token7 = try lexer.nextToken();
    try testing.expectEqual(TokenType.semicolon, token7.type);

    const token8 = try lexer.nextToken();
    try testing.expectEqual(TokenType.right_brace, token8.type);

    const token9 = try lexer.nextToken();
    try testing.expectEqual(TokenType.semicolon, token9.type);
}

test "lexer: simple interface" {
    const source =
        \\[Exposed=*]
        \\interface EventTarget {
        \\  constructor();
        \\  readonly attribute unsigned short eventPhase;
        \\};
    ;
    var lexer = Lexer.init(source);

    const expected = [_]TokenType{
        .left_bracket,
        .identifier, // Exposed
        .equals,
        .identifier, // *
        .right_bracket,
        .keyword_interface,
        .identifier, // EventTarget
        .left_brace,
        .keyword_constructor,
        .left_paren,
        .right_paren,
        .semicolon,
        .keyword_readonly,
        .keyword_attribute,
        .identifier, // unsigned
        .identifier, // short
        .identifier, // eventPhase
        .semicolon,
        .right_brace,
        .semicolon,
        .eof,
    };

    for (expected) |expected_type| {
        const token = try lexer.nextToken();
        try testing.expectEqual(expected_type, token.type);
    }
}

test "lexer: line and column tracking" {
    const source =
        \\interface Event {
        \\  constructor();
        \\};
    ;
    var lexer = Lexer.init(source);

    const token1 = try lexer.nextToken();
    try testing.expectEqual(@as(usize, 1), token1.line);
    try testing.expectEqual(@as(usize, 1), token1.column);

    const token2 = try lexer.nextToken();
    try testing.expectEqual(@as(usize, 1), token2.line);
    try testing.expectEqual(@as(usize, 11), token2.column);

    const token3 = try lexer.nextToken();
    try testing.expectEqual(@as(usize, 1), token3.line);

    const token4 = try lexer.nextToken();
    try testing.expectEqual(@as(usize, 2), token4.line);
    try testing.expectEqual(@as(usize, 3), token4.column);
}
