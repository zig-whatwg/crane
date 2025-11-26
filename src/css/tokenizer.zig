//! CSS Syntax Module Level 3 Tokenizer
//!
//! Implements tokenization for CSS property values per CSS Syntax Module Level 3.
//! This is a minimal tokenizer focused on property value parsing, not full CSS.
//!
//! ## W3C Specification
//!
//! - CSS Syntax Module Level 3 §4: https://drafts.csswg.org/css-syntax-3/#tokenization
//!
//! ## Token Types
//!
//! This tokenizer produces tokens needed for property value parsing:
//! - `ident` - Identifiers (red, auto, inherit)
//! - `function` - Function names (rgb, url)
//! - `hash` - Hash tokens (#fff, #selector)
//! - `string` - Quoted strings ("hello", 'world')
//! - `number` - Numbers (42, 3.14, -1)
//! - `dimension` - Number with unit (10px, 1.5em)
//! - `percentage` - Percentage (50%)
//! - `delim` - Single character delimiters (+, -, /)
//! - `whitespace` - Whitespace sequences
//! - `eof` - End of input
//!
//! ## Design
//!
//! - Zero-copy: Tokens are slices into the original input
//! - Stateless: Tokenizer can be reset and reused
//! - Position tracking: Line/column for error messages

const std = @import("std");

/// CSS token types per CSS Syntax Module Level 3.
pub const TokenType = enum {
    /// Identifier: color names, keywords (red, auto, inherit)
    ident,

    /// Function: identifier followed by '(' (rgb, url)
    function,

    /// Hash: '#' followed by name (#fff, #id)
    hash,

    /// String: quoted text ("hello", 'world')
    string,

    /// Number: integer or decimal (42, 3.14, -1)
    number,

    /// Dimension: number with unit (10px, 1.5em)
    dimension,

    /// Percentage: number with '%' (50%)
    percentage,

    /// Single character delimiter (+, -, /, etc.)
    delim,

    /// Whitespace sequence (space, tab, newline)
    whitespace,

    /// Comma separator
    comma,

    /// Left parenthesis
    left_paren,

    /// Right parenthesis
    right_paren,

    /// End of input
    eof,
};

/// CSS token with type and value.
pub const Token = struct {
    /// Token type.
    token_type: TokenType,

    /// Token value (slice into original input).
    value: []const u8,

    /// Numeric value for number/dimension/percentage tokens.
    numeric_value: ?f64 = null,

    /// Unit string for dimension tokens (e.g., "px", "em").
    unit: ?[]const u8 = null,

    /// For hash tokens: is this an ID type hash (valid identifier)?
    is_id: bool = false,

    /// Line number (1-based).
    line: usize = 1,

    /// Column number (1-based).
    column: usize = 1,

    /// Check if this is a specific identifier.
    pub fn isIdent(self: *const Token, name: []const u8) bool {
        return self.token_type == .ident and
            std.ascii.eqlIgnoreCase(self.value, name);
    }

    /// Check if this is a specific function.
    pub fn isFunction(self: *const Token, name: []const u8) bool {
        return self.token_type == .function and
            std.ascii.eqlIgnoreCase(self.value, name);
    }

    /// Check if this is whitespace.
    pub fn isWhitespace(self: *const Token) bool {
        return self.token_type == .whitespace;
    }

    /// Check if this is end of input.
    pub fn isEof(self: *const Token) bool {
        return self.token_type == .eof;
    }
};

/// CSS tokenizer for property values.
pub const Tokenizer = struct {
    /// Input CSS text.
    input: []const u8,

    /// Current position in input.
    pos: usize = 0,

    /// Current line number (1-based).
    line: usize = 1,

    /// Current column number (1-based).
    column: usize = 1,

    const Self = @This();

    /// Create a new tokenizer.
    pub fn init(input: []const u8) Self {
        return .{
            .input = input,
        };
    }

    /// Reset tokenizer to beginning.
    pub fn reset(self: *Self) void {
        self.pos = 0;
        self.line = 1;
        self.column = 1;
    }

    /// Get the next token.
    pub fn next(self: *Self) Token {
        // Skip any leading whitespace and return whitespace token if found
        const ws_start = self.pos;
        while (self.pos < self.input.len and isWhitespace(self.input[self.pos])) {
            self.advance();
        }
        if (self.pos > ws_start) {
            return Token{
                .token_type = .whitespace,
                .value = self.input[ws_start..self.pos],
                .line = self.line,
                .column = self.column,
            };
        }

        // Check for EOF
        if (self.pos >= self.input.len) {
            return Token{
                .token_type = .eof,
                .value = "",
                .line = self.line,
                .column = self.column,
            };
        }

        const start_line = self.line;
        const start_column = self.column;
        const c = self.input[self.pos];

        // Hash token
        if (c == '#') {
            return self.consumeHash(start_line, start_column);
        }

        // String token
        if (c == '"' or c == '\'') {
            return self.consumeString(c, start_line, start_column);
        }

        // Number, dimension, or percentage
        if (isDigit(c) or (c == '.' and self.pos + 1 < self.input.len and isDigit(self.input[self.pos + 1])) or
            ((c == '+' or c == '-') and self.pos + 1 < self.input.len and
                (isDigit(self.input[self.pos + 1]) or
                    (self.input[self.pos + 1] == '.' and self.pos + 2 < self.input.len and isDigit(self.input[self.pos + 2])))))
        {
            return self.consumeNumeric(start_line, start_column);
        }

        // Parentheses
        if (c == '(') {
            self.advance();
            return Token{
                .token_type = .left_paren,
                .value = self.input[self.pos - 1 .. self.pos],
                .line = start_line,
                .column = start_column,
            };
        }
        if (c == ')') {
            self.advance();
            return Token{
                .token_type = .right_paren,
                .value = self.input[self.pos - 1 .. self.pos],
                .line = start_line,
                .column = start_column,
            };
        }

        // Comma
        if (c == ',') {
            self.advance();
            return Token{
                .token_type = .comma,
                .value = self.input[self.pos - 1 .. self.pos],
                .line = start_line,
                .column = start_column,
            };
        }

        // Identifier or function
        if (isIdentStart(c) or c == '-' or c == '_') {
            return self.consumeIdentLike(start_line, start_column);
        }

        // Single character delimiter
        self.advance();
        return Token{
            .token_type = .delim,
            .value = self.input[self.pos - 1 .. self.pos],
            .line = start_line,
            .column = start_column,
        };
    }

    /// Peek at the next token without consuming it.
    pub fn peek(self: *Self) Token {
        const saved_pos = self.pos;
        const saved_line = self.line;
        const saved_column = self.column;

        const token = self.next();

        self.pos = saved_pos;
        self.line = saved_line;
        self.column = saved_column;

        return token;
    }

    /// Skip whitespace tokens.
    pub fn skipWhitespace(self: *Self) void {
        while (self.pos < self.input.len and isWhitespace(self.input[self.pos])) {
            self.advance();
        }
    }

    // ========================================================================
    // Private Helpers
    // ========================================================================

    fn advance(self: *Self) void {
        if (self.pos < self.input.len) {
            if (self.input[self.pos] == '\n') {
                self.line += 1;
                self.column = 1;
            } else {
                self.column += 1;
            }
            self.pos += 1;
        }
    }

    fn consumeHash(self: *Self, start_line: usize, start_column: usize) Token {
        const start = self.pos;
        self.advance(); // Skip '#'

        const name_start = self.pos;
        while (self.pos < self.input.len and isNameChar(self.input[self.pos])) {
            self.advance();
        }

        const is_id = self.pos > name_start and isIdentStart(self.input[name_start]);

        return Token{
            .token_type = .hash,
            .value = self.input[start..self.pos],
            .is_id = is_id,
            .line = start_line,
            .column = start_column,
        };
    }

    fn consumeString(self: *Self, quote: u8, start_line: usize, start_column: usize) Token {
        const start = self.pos;
        self.advance(); // Skip opening quote

        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (c == quote) {
                self.advance(); // Skip closing quote
                break;
            }
            if (c == '\\' and self.pos + 1 < self.input.len) {
                self.advance(); // Skip backslash
                self.advance(); // Skip escaped char
            } else {
                self.advance();
            }
        }

        return Token{
            .token_type = .string,
            .value = self.input[start..self.pos],
            .line = start_line,
            .column = start_column,
        };
    }

    fn consumeNumeric(self: *Self, start_line: usize, start_column: usize) Token {
        const start = self.pos;

        // Optional sign
        if (self.pos < self.input.len and (self.input[self.pos] == '+' or self.input[self.pos] == '-')) {
            self.advance();
        }

        // Integer part
        while (self.pos < self.input.len and isDigit(self.input[self.pos])) {
            self.advance();
        }

        // Decimal part
        if (self.pos < self.input.len and self.input[self.pos] == '.' and
            self.pos + 1 < self.input.len and isDigit(self.input[self.pos + 1]))
        {
            self.advance(); // Skip '.'
            while (self.pos < self.input.len and isDigit(self.input[self.pos])) {
                self.advance();
            }
        }

        // Exponent part
        if (self.pos < self.input.len and (self.input[self.pos] == 'e' or self.input[self.pos] == 'E')) {
            const exp_start = self.pos;
            self.advance();
            if (self.pos < self.input.len and (self.input[self.pos] == '+' or self.input[self.pos] == '-')) {
                self.advance();
            }
            if (self.pos < self.input.len and isDigit(self.input[self.pos])) {
                while (self.pos < self.input.len and isDigit(self.input[self.pos])) {
                    self.advance();
                }
            } else {
                // Invalid exponent, backtrack
                self.pos = exp_start;
            }
        }

        const num_str = self.input[start..self.pos];
        const numeric_value = std.fmt.parseFloat(f64, num_str) catch 0.0;

        // Check for percentage
        if (self.pos < self.input.len and self.input[self.pos] == '%') {
            self.advance();
            return Token{
                .token_type = .percentage,
                .value = self.input[start..self.pos],
                .numeric_value = numeric_value,
                .line = start_line,
                .column = start_column,
            };
        }

        // Check for dimension (unit)
        if (self.pos < self.input.len and (isIdentStart(self.input[self.pos]) or self.input[self.pos] == '-')) {
            const unit_start = self.pos;
            while (self.pos < self.input.len and isNameChar(self.input[self.pos])) {
                self.advance();
            }
            return Token{
                .token_type = .dimension,
                .value = self.input[start..self.pos],
                .numeric_value = numeric_value,
                .unit = self.input[unit_start..self.pos],
                .line = start_line,
                .column = start_column,
            };
        }

        return Token{
            .token_type = .number,
            .value = num_str,
            .numeric_value = numeric_value,
            .line = start_line,
            .column = start_column,
        };
    }

    fn consumeIdentLike(self: *Self, start_line: usize, start_column: usize) Token {
        const start = self.pos;

        // Consume identifier
        while (self.pos < self.input.len and isNameChar(self.input[self.pos])) {
            self.advance();
        }

        const name = self.input[start..self.pos];

        // Check if it's a function (followed by '(')
        if (self.pos < self.input.len and self.input[self.pos] == '(') {
            return Token{
                .token_type = .function,
                .value = name,
                .line = start_line,
                .column = start_column,
            };
        }

        return Token{
            .token_type = .ident,
            .value = name,
            .line = start_line,
            .column = start_column,
        };
    }
};

// ============================================================================
// Character Classification
// ============================================================================

fn isWhitespace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == '\x0C';
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isHexDigit(c: u8) bool {
    return isDigit(c) or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F');
}

fn isLetter(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
}

fn isIdentStart(c: u8) bool {
    return isLetter(c) or c == '_' or c >= 0x80;
}

fn isNameChar(c: u8) bool {
    return isIdentStart(c) or isDigit(c) or c == '-';
}

/// Check if a string is a valid hex color (3 or 6 hex digits).
pub fn isHexColor(s: []const u8) bool {
    if (s.len != 3 and s.len != 6) return false;
    for (s) |c| {
        if (!isHexDigit(c)) return false;
    }
    return true;
}

// ============================================================================
// Tests
// ============================================================================

test "Tokenizer - whitespace" {
    var tokenizer_inst = Tokenizer.init("  \t\n  ");
    const token = tokenizer_inst.next();
    try std.testing.expectEqual(TokenType.whitespace, token.token_type);
    try std.testing.expectEqual(TokenType.eof, tokenizer_inst.next().token_type);
}

test "Tokenizer - identifiers" {
    var tokenizer_inst = Tokenizer.init("red auto inherit");

    var token = tokenizer_inst.next();
    try std.testing.expectEqual(TokenType.ident, token.token_type);
    try std.testing.expectEqualStrings("red", token.value);

    _ = tokenizer_inst.next(); // whitespace

    token = tokenizer_inst.next();
    try std.testing.expectEqual(TokenType.ident, token.token_type);
    try std.testing.expectEqualStrings("auto", token.value);
}

test "Tokenizer - hash" {
    var tokenizer_inst = Tokenizer.init("#fff #123456");

    var token = tokenizer_inst.next();
    try std.testing.expectEqual(TokenType.hash, token.token_type);
    try std.testing.expectEqualStrings("#fff", token.value);

    _ = tokenizer_inst.next(); // whitespace

    token = tokenizer_inst.next();
    try std.testing.expectEqual(TokenType.hash, token.token_type);
    try std.testing.expectEqualStrings("#123456", token.value);
}

test "Tokenizer - numbers" {
    var tokenizer_inst = Tokenizer.init("42 3.14 -1");

    var token = tokenizer_inst.next();
    try std.testing.expectEqual(TokenType.number, token.token_type);
    try std.testing.expectEqual(@as(f64, 42), token.numeric_value.?);

    _ = tokenizer_inst.next(); // whitespace

    token = tokenizer_inst.next();
    try std.testing.expectEqual(TokenType.number, token.token_type);
    try std.testing.expectApproxEqAbs(@as(f64, 3.14), token.numeric_value.?, 0.001);

    _ = tokenizer_inst.next(); // whitespace

    token = tokenizer_inst.next();
    try std.testing.expectEqual(TokenType.number, token.token_type);
    try std.testing.expectEqual(@as(f64, -1), token.numeric_value.?);
}

test "Tokenizer - dimensions" {
    var tokenizer_inst = Tokenizer.init("10px 1.5em");

    var token = tokenizer_inst.next();
    try std.testing.expectEqual(TokenType.dimension, token.token_type);
    try std.testing.expectEqual(@as(f64, 10), token.numeric_value.?);
    try std.testing.expectEqualStrings("px", token.unit.?);

    _ = tokenizer_inst.next(); // whitespace

    token = tokenizer_inst.next();
    try std.testing.expectEqual(TokenType.dimension, token.token_type);
    try std.testing.expectApproxEqAbs(@as(f64, 1.5), token.numeric_value.?, 0.001);
    try std.testing.expectEqualStrings("em", token.unit.?);
}

test "Tokenizer - percentage" {
    var tokenizer_inst = Tokenizer.init("50% 100%");

    var token = tokenizer_inst.next();
    try std.testing.expectEqual(TokenType.percentage, token.token_type);
    try std.testing.expectEqual(@as(f64, 50), token.numeric_value.?);

    _ = tokenizer_inst.next(); // whitespace

    token = tokenizer_inst.next();
    try std.testing.expectEqual(TokenType.percentage, token.token_type);
    try std.testing.expectEqual(@as(f64, 100), token.numeric_value.?);
}

test "Tokenizer - function" {
    var tokenizer_inst = Tokenizer.init("rgb(255, 0, 0)");

    var token = tokenizer_inst.next();
    try std.testing.expectEqual(TokenType.function, token.token_type);
    try std.testing.expectEqualStrings("rgb", token.value);

    token = tokenizer_inst.next();
    try std.testing.expectEqual(TokenType.left_paren, token.token_type);

    token = tokenizer_inst.next();
    try std.testing.expectEqual(TokenType.number, token.token_type);
    try std.testing.expectEqual(@as(f64, 255), token.numeric_value.?);
}

test "Tokenizer - string" {
    var tokenizer_inst = Tokenizer.init("\"hello\" 'world'");

    var token = tokenizer_inst.next();
    try std.testing.expectEqual(TokenType.string, token.token_type);
    try std.testing.expectEqualStrings("\"hello\"", token.value);

    _ = tokenizer_inst.next(); // whitespace

    token = tokenizer_inst.next();
    try std.testing.expectEqual(TokenType.string, token.token_type);
    try std.testing.expectEqualStrings("'world'", token.value);
}

test "isHexColor" {
    try std.testing.expect(isHexColor("fff"));
    try std.testing.expect(isHexColor("FFF"));
    try std.testing.expect(isHexColor("123456"));
    try std.testing.expect(isHexColor("abcdef"));
    try std.testing.expect(!isHexColor("ff"));
    try std.testing.expect(!isHexColor("ffff"));
    try std.testing.expect(!isHexColor("gggggg"));
}
