//! CSS Syntax Module Level 3 Tokenizer
//!
//! Implements tokenization per CSS Syntax Module Level 3 section 4.3: every
//! token type, for property values (color, length, property_parser) and for
//! a style sheet's rules (import_rules).
//!
//! ## W3C Specification
//!
//! - CSS Syntax Module Level 3 §4: https://drafts.csswg.org/css-syntax-3/#tokenization
//!
//! ## Token Types
//!
//! - `ident` - Identifiers (red, auto, inherit)
//! - `function` - Function names (rgb, url)
//! - `at_keyword` - `@` and a name (@import, @media)
//! - `hash` - Hash tokens (#fff, #selector)
//! - `string`, `bad_string` - Quoted strings ("hello", 'world')
//! - `url`, `bad_url` - Unquoted url(...) arguments
//! - `number` - Numbers (42, 3.14, -1)
//! - `dimension` - Number with unit (10px, 1.5em)
//! - `percentage` - Percentage (50%)
//! - `delim` - Any other single code point (+, -, /, !)
//! - `whitespace` - Whitespace sequences
//! - `cdo`, `cdc` - `<!--` and `-->`
//! - `colon`, `semicolon`, `comma`, `left_bracket`, `right_bracket`,
//!   `left_paren`, `right_paren`, `left_brace`, `right_brace`
//! - `eof` - End of input
//!
//! ## Design
//!
//! - Zero-copy: Tokens are slices into the original input, escapes as
//!   written; `decode` gives a token's value as the spec defines it.
//! - Preprocessing (section 3.3) happens as the input is read, not as a
//!   copy: CR, CRLF and FF each count as one newline, and NUL - and a
//!   surrogate, which UTF-8 cannot encode anyway - is U+FFFD, an ident code
//!   point, and decodes as U+FFFD.
//! - Two shapes differ from the spec's tokens, kept for this module's value
//!   parsers: a `function` token does not consume its `(` - the next token
//!   is `left_paren` - and a `string` token's value keeps its quotes
//!   (`stringContents` is the text between them).
//! - The input is UTF-8 bytes; a byte at or above 0x80 is part of a
//!   non-ASCII code point, which CSS treats as an ident code point.
//! - Position tracking: Line/column for error messages

const std = @import("std");

/// CSS token types per CSS Syntax Module Level 3.
pub const TokenType = enum {
    /// Identifier: color names, keywords (red, auto, inherit)
    ident,

    /// Function: identifier followed by '(' (rgb, url). The '(' is the next
    /// token.
    function,

    /// At-keyword: '@' followed by a name (@import). The value is the name.
    at_keyword,

    /// Hash: '#' followed by name (#fff, #id)
    hash,

    /// String: quoted text ("hello", 'world')
    string,

    /// A string cut off by a newline.
    bad_string,

    /// An unquoted url(...) argument. The value is the URL as written,
    /// without the whitespace around it.
    url,

    /// A url(...) with a quote, '(' , whitespace or a non-printable code
    /// point inside its unquoted argument.
    bad_url,

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

    /// `<!--`
    cdo,

    /// `-->`
    cdc,

    /// Colon
    colon,

    /// Semicolon
    semicolon,

    /// Comma separator
    comma,

    /// Left square bracket
    left_bracket,

    /// Right square bracket
    right_bracket,

    /// Left parenthesis
    left_paren,

    /// Right parenthesis
    right_paren,

    /// Left curly bracket
    left_brace,

    /// Right curly bracket
    right_brace,

    /// End of input
    eof,
};

/// CSS token with type and value.
pub const Token = struct {
    /// Token type.
    token_type: TokenType,

    /// Token value (slice into original input): the name of an ident,
    /// function or at-keyword; '#' and the name of a hash; a string with its
    /// quotes; a url's argument; a number, percentage or dimension as
    /// written; the code point of a delim. Escapes are as written.
    value: []const u8,

    /// Numeric value for number/dimension/percentage tokens.
    numeric_value: ?f64 = null,

    /// For number/dimension/percentage tokens: the number has the type flag
    /// "integer" (no fraction, no exponent).
    is_integer: bool = false,

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

    /// A string token's text between its quotes, escapes as written. A
    /// string that ran to EOF has no closing quote.
    pub fn stringContents(self: *const Token) []const u8 {
        if (self.value.len == 0) return self.value;
        const quote = self.value[0];
        const end = if (self.value.len >= 2 and self.value[self.value.len - 1] == quote and !endsInEscape(self.value[1 .. self.value.len - 1]))
            self.value.len - 1
        else
            self.value.len;
        return self.value[1..end];
    }
};

/// Whether `text` ends in a backslash that escapes whatever follows it: an
/// odd run of trailing backslashes.
fn endsInEscape(text: []const u8) bool {
    var n: usize = 0;
    while (n < text.len and text[text.len - 1 - n] == '\\') n += 1;
    return n % 2 == 1;
}

/// CSS tokenizer.
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

    /// "Consume a token".
    pub fn next(self: *Self) Token {
        // "Consume comments."
        self.consumeComments();
        const start_line = self.line;
        const start_column = self.column;
        var token = self.consumeToken();
        token.line = start_line;
        token.column = start_column;
        return token;
    }

    /// "Consume a token", after the comments.
    fn consumeToken(self: *Self) Token {
        const start = self.pos;
        if (self.atEnd(0)) return .{ .token_type = .eof, .value = "" };
        switch (self.input[self.pos]) {
            ' ', '\t', '\n', '\r', 0x0C => {
                while (!self.atEnd(0) and isWhitespace(self.input[self.pos])) self.advance();
                return self.spanned(start, .whitespace);
            },
            '"', '\'' => return self.consumeString(),
            '#' => {
                // "If the next input code point is an ident code point or
                // the next two input code points are a valid escape": a hash
                // token, of type "id" if the next three would start an ident
                // sequence.
                if ((isNameChar(self.peekByte(1)) and !self.atEnd(1)) or self.validEscape(1)) {
                    const is_id = self.startsIdent(1);
                    self.advance();
                    self.consumeName();
                    var token = self.spanned(start, .hash);
                    token.is_id = is_id;
                    return token;
                }
                return self.single(.delim);
            },
            '(' => return self.single(.left_paren),
            ')' => return self.single(.right_paren),
            '+', '.' => return if (self.startsNumber(0)) self.consumeNumeric() else self.single(.delim),
            ',' => return self.single(.comma),
            '-' => {
                if (self.startsNumber(0)) return self.consumeNumeric();
                if (self.peekByte(1) == '-' and self.peekByte(2) == '>' and !self.atEnd(2)) {
                    self.advanceBy(3);
                    return self.spanned(start, .cdc);
                }
                if (self.startsIdent(0)) return self.consumeIdentLike();
                return self.single(.delim);
            },
            ':' => return self.single(.colon),
            ';' => return self.single(.semicolon),
            '<' => {
                if (self.peekByte(1) == '!' and self.peekByte(2) == '-' and self.peekByte(3) == '-' and !self.atEnd(3)) {
                    self.advanceBy(4);
                    return self.spanned(start, .cdo);
                }
                return self.single(.delim);
            },
            '@' => {
                if (self.startsIdent(1)) {
                    self.advance();
                    const name_start = self.pos;
                    self.consumeName();
                    return .{ .token_type = .at_keyword, .value = self.input[name_start..self.pos] };
                }
                return self.single(.delim);
            },
            '[' => return self.single(.left_bracket),
            '\\' => return if (self.validEscape(0)) self.consumeIdentLike() else self.single(.delim),
            ']' => return self.single(.right_bracket),
            '{' => return self.single(.left_brace),
            '}' => return self.single(.right_brace),
            '0'...'9' => return self.consumeNumeric(),
            else => |c| return if (isIdentStart(c)) self.consumeIdentLike() else self.single(.delim),
        }
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

    /// Skip whitespace, and the comments between it.
    pub fn skipWhitespace(self: *Self) void {
        while (true) {
            self.consumeComments();
            if (self.atEnd(0) or !isWhitespace(self.input[self.pos])) return;
            while (!self.atEnd(0) and isWhitespace(self.input[self.pos])) self.advance();
        }
    }

    // ========================================================================
    // Private Helpers
    // ========================================================================

    fn atEnd(self: *const Self, offset: usize) bool {
        return self.pos + offset >= self.input.len;
    }

    /// The byte `offset` past the current position; 0 past the end (check
    /// `atEnd`: a NUL in the input is U+FFFD, not EOF).
    fn peekByte(self: *const Self, offset: usize) u8 {
        const i = self.pos + offset;
        return if (i < self.input.len) self.input[i] else 0;
    }

    /// Consume one byte. A newline - LF, CR not followed by LF, FF - moves to
    /// the next line; a CR followed by LF waits for its LF.
    fn advance(self: *Self) void {
        if (self.pos >= self.input.len) return;
        const c = self.input[self.pos];
        const newline = c == '\n' or c == 0x0C or (c == '\r' and self.peekByte(1) != '\n');
        if (newline) {
            self.line += 1;
            self.column = 1;
        } else if (c != '\r') {
            self.column += 1;
        }
        self.pos += 1;
    }

    fn advanceBy(self: *Self, n: usize) void {
        for (0..n) |_| self.advance();
    }

    /// Consume one code point: a UTF-8 sequence, or one byte that starts
    /// none.
    fn advanceCodePoint(self: *Self) void {
        const len = std.unicode.utf8ByteSequenceLength(self.input[self.pos]) catch 1;
        self.advanceBy(@min(len, self.input.len - self.pos));
    }

    /// A token of the one ASCII code point at the current position.
    fn single(self: *Self, token_type: TokenType) Token {
        const start = self.pos;
        self.advance();
        return self.spanned(start, token_type);
    }

    /// A token whose value is the input from `start` to here.
    fn spanned(self: *const Self, start: usize, token_type: TokenType) Token {
        return .{ .token_type = token_type, .value = self.input[start..self.pos] };
    }

    /// "Consume comments": each `/*` through the next `*/`, or to EOF.
    fn consumeComments(self: *Self) void {
        while (self.peekByte(0) == '/' and self.peekByte(1) == '*' and !self.atEnd(1)) {
            self.advanceBy(2);
            while (!self.atEnd(0)) {
                if (self.input[self.pos] == '*' and self.peekByte(1) == '/' and !self.atEnd(1)) {
                    self.advanceBy(2);
                    break;
                }
                self.advance();
            }
        }
    }

    /// "Consume a string token", its opening quote the current code point.
    /// The value keeps the quotes.
    fn consumeString(self: *Self) Token {
        const start = self.pos;
        const quote = self.input[self.pos];
        self.advance();
        while (!self.atEnd(0)) {
            const c = self.input[self.pos];
            if (c == quote) {
                self.advance();
                return self.spanned(start, .string);
            }
            // A newline: a parse error; reconsume it, and the string is bad.
            if (isNewline(c)) return self.spanned(start, .bad_string);
            if (c == '\\') {
                self.advance();
                if (self.atEnd(0)) break;
                // An escaped newline is consumed; anything else is an
                // escaped code point.
                if (self.input[self.pos] == '\r' and self.peekByte(1) == '\n') self.advance();
                if (isNewline(self.input[self.pos])) {
                    self.advance();
                } else {
                    self.consumeEscapedCodePoint();
                }
                continue;
            }
            self.advanceCodePoint();
        }
        // EOF: a parse error; the string as it stands.
        return self.spanned(start, .string);
    }

    /// "Consume a numeric token".
    fn consumeNumeric(self: *Self) Token {
        const start = self.pos;
        const is_integer = self.consumeNumber();
        const number_text = self.input[start..self.pos];
        const numeric_value = std.fmt.parseFloat(f64, number_text) catch 0.0;

        // "If the next 3 input code points would start an ident sequence":
        // a dimension, its unit the ident sequence.
        if (self.startsIdent(0)) {
            const unit_start = self.pos;
            self.consumeName();
            return .{
                .token_type = .dimension,
                .value = self.input[start..self.pos],
                .numeric_value = numeric_value,
                .is_integer = is_integer,
                .unit = self.input[unit_start..self.pos],
            };
        }
        if (self.peekByte(0) == '%' and !self.atEnd(0)) {
            self.advance();
            return .{
                .token_type = .percentage,
                .value = self.input[start..self.pos],
                .numeric_value = numeric_value,
                .is_integer = is_integer,
            };
        }
        return .{
            .token_type = .number,
            .value = number_text,
            .numeric_value = numeric_value,
            .is_integer = is_integer,
        };
    }

    /// "Consume a number". Returns whether its type is "integer".
    fn consumeNumber(self: *Self) bool {
        var is_integer = true;
        if (self.peekByte(0) == '+' or self.peekByte(0) == '-') self.advance();
        while (self.digitAt(0)) self.advance();
        if (self.peekByte(0) == '.' and self.digitAt(1)) {
            self.advance();
            is_integer = false;
            while (self.digitAt(0)) self.advance();
        }
        const e = self.peekByte(0);
        if ((e == 'e' or e == 'E') and !self.atEnd(0)) {
            const sign: usize = if (self.peekByte(1) == '+' or self.peekByte(1) == '-') 1 else 0;
            if (self.digitAt(1 + sign)) {
                self.advanceBy(1 + sign);
                is_integer = false;
                while (self.digitAt(0)) self.advance();
            }
        }
        return is_integer;
    }

    fn digitAt(self: *const Self, offset: usize) bool {
        return !self.atEnd(offset) and isDigit(self.peekByte(offset));
    }

    /// "Consume an ident-like token": an ident, a function, or a url.
    fn consumeIdentLike(self: *Self) Token {
        const start = self.pos;
        self.consumeName();
        const name = self.input[start..self.pos];
        if (self.peekByte(0) != '(' or self.atEnd(0)) return .{ .token_type = .ident, .value = name };

        if (nameEql(name, "url")) {
            // "While the next two input code points are whitespace, consume
            // the next input code point. If the next one or two input code
            // points are a quote, or whitespace followed by a quote": a
            // function token. Otherwise a url token.
            var i: usize = 1;
            while (isWhitespace(self.peekByte(i)) and isWhitespace(self.peekByte(i + 1)) and !self.atEnd(i + 1)) i += 1;
            const first = self.peekByte(i);
            const quoted = !self.atEnd(i) and (first == '"' or first == '\'' or
                (isWhitespace(first) and !self.atEnd(i + 1) and (self.peekByte(i + 1) == '"' or self.peekByte(i + 1) == '\'')));
            if (!quoted) {
                // Consume the "(" and the url.
                self.advance();
                return self.consumeUrl(start);
            }
        }
        // A function token: the "(" is left for the next token.
        return .{ .token_type = .function, .value = name };
    }

    /// "Consume a url token", after `url(`; `token_start` is where `url`
    /// began. A bad url's value is all of it.
    fn consumeUrl(self: *Self, token_start: usize) Token {
        while (!self.atEnd(0) and isWhitespace(self.input[self.pos])) self.advance();
        const start = self.pos;
        while (!self.atEnd(0)) {
            const c = self.input[self.pos];
            switch (c) {
                ')' => {
                    const end = self.pos;
                    self.advance();
                    return .{ .token_type = .url, .value = self.input[start..end] };
                },
                ' ', '\t', '\n', '\r', 0x0C => {
                    const end = self.pos;
                    while (!self.atEnd(0) and isWhitespace(self.input[self.pos])) self.advance();
                    if (self.atEnd(0)) return .{ .token_type = .url, .value = self.input[start..end] };
                    if (self.input[self.pos] == ')') {
                        self.advance();
                        return .{ .token_type = .url, .value = self.input[start..end] };
                    }
                    self.consumeBadUrlRemnants();
                    return self.spanned(token_start, .bad_url);
                },
                '"', '\'', '(' => {
                    self.consumeBadUrlRemnants();
                    return self.spanned(token_start, .bad_url);
                },
                '\\' => {
                    if (!self.validEscape(0)) {
                        self.consumeBadUrlRemnants();
                        return self.spanned(token_start, .bad_url);
                    }
                    self.advance();
                    self.consumeEscapedCodePoint();
                },
                else => {
                    if (isNonPrintable(c)) {
                        self.consumeBadUrlRemnants();
                        return self.spanned(token_start, .bad_url);
                    }
                    self.advanceCodePoint();
                },
            }
        }
        // EOF: a parse error; the url as it stands.
        return .{ .token_type = .url, .value = self.input[start..self.pos] };
    }

    /// "Consume the remnants of a bad url": through the next ")" that is not
    /// escaped, or to EOF.
    fn consumeBadUrlRemnants(self: *Self) void {
        while (!self.atEnd(0)) {
            if (self.input[self.pos] == ')') {
                self.advance();
                return;
            }
            if (self.validEscape(0)) {
                self.advance();
                self.consumeEscapedCodePoint();
                continue;
            }
            self.advanceCodePoint();
        }
    }

    /// "Consume an ident sequence".
    fn consumeName(self: *Self) void {
        while (!self.atEnd(0)) {
            if (isNameChar(self.input[self.pos])) {
                self.advance();
            } else if (self.validEscape(0)) {
                self.advance();
                self.consumeEscapedCodePoint();
            } else break;
        }
    }

    /// "Consume an escaped code point", after its backslash: up to six hex
    /// digits and one whitespace after them, or one code point; nothing at
    /// EOF.
    fn consumeEscapedCodePoint(self: *Self) void {
        if (self.atEnd(0)) return;
        if (isHexDigit(self.input[self.pos])) {
            var n: usize = 0;
            while (n < 6 and !self.atEnd(0) and isHexDigit(self.input[self.pos])) : (n += 1) self.advance();
            if (!self.atEnd(0) and isWhitespace(self.input[self.pos])) {
                if (self.input[self.pos] == '\r' and self.peekByte(1) == '\n') self.advance();
                self.advance();
            }
            return;
        }
        self.advanceCodePoint();
    }

    /// "Check if two code points are a valid escape", starting `offset` past
    /// the current position.
    fn validEscape(self: *const Self, offset: usize) bool {
        if (self.atEnd(offset) or self.peekByte(offset) != '\\') return false;
        if (self.atEnd(offset + 1)) return true;
        return !isNewline(self.peekByte(offset + 1));
    }

    /// "Check if three code points would start an ident sequence", starting
    /// `offset` past the current position.
    fn startsIdent(self: *const Self, offset: usize) bool {
        if (self.atEnd(offset)) return false;
        const c = self.peekByte(offset);
        if (c == '-') {
            if (self.atEnd(offset + 1)) return false;
            const d = self.peekByte(offset + 1);
            return isIdentStart(d) or d == '-' or self.validEscape(offset + 1);
        }
        if (isIdentStart(c)) return true;
        return self.validEscape(offset);
    }

    /// "Check if three code points would start a number", starting `offset`
    /// past the current position.
    fn startsNumber(self: *const Self, offset: usize) bool {
        if (self.atEnd(offset)) return false;
        const c = self.peekByte(offset);
        if (c == '+' or c == '-') {
            if (self.digitAt(offset + 1)) return true;
            return self.peekByte(offset + 1) == '.' and self.digitAt(offset + 2);
        }
        if (c == '.') return self.digitAt(offset + 1);
        return isDigit(c);
    }
};

// ============================================================================
// Token values, as the spec defines them
// ============================================================================

/// `raw` - a name, a string's contents or a url, as written - as the spec's
/// token value: escapes decoded (`\` and up to six hex digits and one
/// whitespace is that code point, U+FFFD for zero, a surrogate or one past
/// U+10FFFF; `\` and a newline is nothing; `\` and anything else is that
/// code point; `\` at EOF is U+FFFD), and NUL - and an encoded surrogate -
/// U+FFFD. Owned by the caller.
pub fn decode(allocator: std.mem.Allocator, raw: []const u8) std.mem.Allocator.Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    // No input byte decodes to more than three output bytes (NUL, an
    // escape at EOF), so this never grows.
    try out.ensureTotalCapacityPrecise(allocator, raw.len * 3 + 3);
    var i: usize = 0;
    while (i < raw.len) {
        const c = raw[i];
        if (c == 0) {
            try out.appendSlice(allocator, "\u{FFFD}");
            i += 1;
            continue;
        }
        if (c == 0xED and i + 2 < raw.len and raw[i + 1] >= 0xA0 and raw[i + 1] <= 0xBF) {
            // A surrogate, encoded as if it were a code point.
            try out.appendSlice(allocator, "\u{FFFD}");
            i += 3;
            continue;
        }
        if (c != '\\') {
            try out.append(allocator, c);
            i += 1;
            continue;
        }
        i += 1;
        if (i >= raw.len) {
            try out.appendSlice(allocator, "\u{FFFD}");
            break;
        }
        if (isNewline(raw[i])) {
            if (raw[i] == '\r' and i + 1 < raw.len and raw[i + 1] == '\n') i += 1;
            i += 1;
            continue;
        }
        if (isHexDigit(raw[i])) {
            var value: u32 = 0;
            var n: usize = 0;
            while (n < 6 and i < raw.len and isHexDigit(raw[i])) : (n += 1) {
                value = value * 16 + (std.fmt.charToDigit(raw[i], 16) catch 0);
                i += 1;
            }
            if (i < raw.len and isWhitespace(raw[i])) {
                if (raw[i] == '\r' and i + 1 < raw.len and raw[i + 1] == '\n') i += 1;
                i += 1;
            }
            const code_point: u21 = if (value == 0 or value > 0x10FFFF or (value >= 0xD800 and value <= 0xDFFF))
                0xFFFD
            else
                @intCast(value);
            var buffer: [4]u8 = undefined;
            const len = std.unicode.utf8Encode(code_point, &buffer) catch unreachable;
            try out.appendSlice(allocator, buffer[0..len]);
            continue;
        }
        const len = @min(std.unicode.utf8ByteSequenceLength(raw[i]) catch 1, raw.len - i);
        try out.appendSlice(allocator, raw[i .. i + len]);
        i += len;
    }
    return out.toOwnedSlice(allocator);
}

/// Whether the name `raw` (an ident, function or at-keyword value, escapes
/// as written) is `name`, ASCII case-insensitively: `@\69mport` is
/// `@import`.
pub fn nameEql(raw: []const u8, name: []const u8) bool {
    if (std.mem.indexOfScalar(u8, raw, '\\') == null and std.mem.indexOfScalar(u8, raw, 0) == null) {
        return std.ascii.eqlIgnoreCase(raw, name);
    }
    // Names compared this way are keywords, a few bytes long.
    if (raw.len > 64) return false;
    var buffer: [64 * 3 + 3]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const decoded = decode(fba.allocator(), raw) catch return false;
    return std.ascii.eqlIgnoreCase(decoded, name);
}

// ============================================================================
// Character Classification
// ============================================================================

fn isWhitespace(c: u8) bool {
    return c == ' ' or c == '\t' or isNewline(c);
}

/// A newline after preprocessing: LF, and the CR and FF that become one.
fn isNewline(c: u8) bool {
    return c == '\n' or c == '\r' or c == 0x0C;
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

/// "Ident-start code point": a letter, a non-ASCII code point, or '_'. NUL
/// is U+FFFD after preprocessing, a non-ASCII code point.
fn isIdentStart(c: u8) bool {
    return isLetter(c) or c == '_' or c >= 0x80 or c == 0;
}

/// "Ident code point".
fn isNameChar(c: u8) bool {
    return isIdentStart(c) or isDigit(c) or c == '-';
}

/// "Non-printable code point". NUL is U+FFFD after preprocessing, which is
/// printable.
fn isNonPrintable(c: u8) bool {
    return (c >= 0x01 and c <= 0x08) or c == 0x0B or (c >= 0x0E and c <= 0x1F) or c == 0x7F;
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

// ============================================================================
// CSS Syntax 4.3: every token type, from the spec's definitions
// ============================================================================

fn expectTokens(input: []const u8, expected: []const TokenType) !void {
    var t = Tokenizer.init(input);
    for (expected) |want| {
        const got = t.next();
        std.testing.expectEqual(want, got.token_type) catch |err| {
            std.debug.print("input {s}: got {s} \"{s}\"\n", .{ input, @tagName(got.token_type), got.value });
            return err;
        };
    }
    try std.testing.expectEqual(TokenType.eof, t.next().token_type);
}

test "comments are consumed before every token, an unterminated one to EOF" {
    try expectTokens("/* a 'quote */red", &.{.ident});
    try expectTokens("red/**/ /* x */blue", &.{ .ident, .whitespace, .ident });
    try expectTokens("red /* unterminated 'x", &.{ .ident, .whitespace });
    var t = Tokenizer.init("/*x*/ /*y*/ 10px");
    t.skipWhitespace();
    try std.testing.expectEqual(TokenType.dimension, t.next().token_type);
}

test "the single-code-point tokens" {
    try expectTokens(":;,()[]{}", &.{ .colon, .semicolon, .comma, .left_paren, .right_paren, .left_bracket, .right_bracket, .left_brace, .right_brace });
}

test "at-keyword: @ followed by an ident sequence, else a delim" {
    var t = Tokenizer.init("@import @-x @\\69mport @ @1");
    var token = t.next();
    try std.testing.expectEqual(TokenType.at_keyword, token.token_type);
    try std.testing.expectEqualStrings("import", token.value);
    _ = t.next();
    token = t.next();
    try std.testing.expectEqual(TokenType.at_keyword, token.token_type);
    try std.testing.expectEqualStrings("-x", token.value);
    _ = t.next();
    token = t.next();
    try std.testing.expectEqual(TokenType.at_keyword, token.token_type);
    try std.testing.expect(nameEql(token.value, "import"));
    _ = t.next();
    try std.testing.expectEqual(TokenType.delim, t.next().token_type);
    _ = t.next();
    try std.testing.expectEqual(TokenType.delim, t.next().token_type);
    try std.testing.expectEqual(TokenType.number, t.next().token_type);
}

test "CDO and CDC" {
    try expectTokens("<!-- -->", &.{ .cdo, .whitespace, .cdc });
    try expectTokens("<!-", &.{ .delim, .delim, .delim });
    try expectTokens("-->x", &.{ .cdc, .ident });
}

test "url token: unquoted url( is one token, quoted url( a function" {
    var t = Tokenizer.init("url(  a.css  )");
    var token = t.next();
    try std.testing.expectEqual(TokenType.url, token.token_type);
    try std.testing.expectEqualStrings("a.css", token.value);
    try std.testing.expectEqual(TokenType.eof, t.next().token_type);

    t = Tokenizer.init("URL(a\\)b)");
    token = t.next();
    try std.testing.expectEqual(TokenType.url, token.token_type);
    const decoded = try decode(std.testing.allocator, token.value);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualStrings("a)b", decoded);

    // A quoted argument keeps the function shape: the name, then "(".
    try expectTokens("url( \"a.css\" )", &.{ .function, .left_paren, .whitespace, .string, .whitespace, .right_paren });
    try expectTokens("url('a')", &.{ .function, .left_paren, .string, .right_paren });
    // Unterminated at EOF is still a url token.
    try expectTokens("url(a.css", &.{.url});
}

test "bad url: a quote, paren, non-printable or inner whitespace" {
    try expectTokens("url(a b) x", &.{ .bad_url, .whitespace, .ident });
    try expectTokens("url(a\"b) x", &.{ .bad_url, .whitespace, .ident });
    try expectTokens("url(a(b) x", &.{ .bad_url, .whitespace, .ident });
    try expectTokens("url(a\x01b) x", &.{ .bad_url, .whitespace, .ident });
    // The remnants run to ")" past escapes, or to EOF.
    try expectTokens("url(a b\\)c) x", &.{ .bad_url, .whitespace, .ident });
    try expectTokens("url(a b", &.{.bad_url});
}

test "strings: a newline makes a bad string, an escaped newline does not" {
    try expectTokens("'a\nb'", &.{ .bad_string, .whitespace, .ident, .string });
    try expectTokens("\"a\\\nb\"", &.{.string});
    try expectTokens("'unterminated", &.{.string});
    var t = Tokenizer.init("'a\\'b'");
    const token = t.next();
    try std.testing.expectEqualStrings("'a\\'b'", token.value);
    try std.testing.expectEqualStrings("a\\'b", token.stringContents());
}

test "escapes start and continue ident-like tokens" {
    var t = Tokenizer.init("\\31 a b\\{c");
    var token = t.next();
    try std.testing.expectEqual(TokenType.ident, token.token_type);
    const first = try decode(std.testing.allocator, token.value);
    defer std.testing.allocator.free(first);
    try std.testing.expectEqualStrings("1a", first);
    _ = t.next();
    token = t.next();
    try std.testing.expectEqual(TokenType.ident, token.token_type);
    try std.testing.expectEqualStrings("b\\{c", token.value);
    // A backslash before a newline is not an escape: a delim.
    try expectTokens("\\\n", &.{ .delim, .whitespace });
}

test "hash: # with a name, else a delim; the id flag" {
    var t = Tokenizer.init("#fff #1a # x");
    var token = t.next();
    try std.testing.expectEqual(TokenType.hash, token.token_type);
    try std.testing.expect(token.is_id);
    _ = t.next();
    token = t.next();
    try std.testing.expectEqual(TokenType.hash, token.token_type);
    try std.testing.expect(!token.is_id);
    _ = t.next();
    try std.testing.expectEqual(TokenType.delim, t.next().token_type);
}

test "minus: a number, CDC, an ident, or a delim" {
    try expectTokens("-1 -x -- - ", &.{ .number, .whitespace, .ident, .whitespace, .ident, .whitespace, .delim, .whitespace });
    // A unit must start an ident sequence: "10-" is a number and a delim.
    try expectTokens("10- 10-x", &.{ .number, .delim, .whitespace, .dimension });
}

test "numbers: the integer flag, exponents, and units" {
    var t = Tokenizer.init("12 1.5 1e3 1e+ .5%");
    var token = t.next();
    try std.testing.expect(token.is_integer);
    _ = t.next();
    token = t.next();
    try std.testing.expect(!token.is_integer);
    _ = t.next();
    token = t.next();
    try std.testing.expectEqual(@as(f64, 1000), token.numeric_value.?);
    _ = t.next();
    // "1e+" has no exponent (no digit follows the sign): "e" starts an
    // ident sequence, so it is the dimension "1e", then the delim "+".
    token = t.next();
    try std.testing.expectEqual(TokenType.dimension, token.token_type);
    try std.testing.expectEqualStrings("e", token.unit.?);
    try std.testing.expectEqual(TokenType.delim, t.next().token_type);
    _ = t.next();
    token = t.next();
    try std.testing.expectEqual(TokenType.percentage, token.token_type);
}

test "preprocessing: CR, CRLF and FF are one newline each; NUL decodes to U+FFFD" {
    var t = Tokenizer.init("a\r\nb\rc\x0Cd");
    _ = t.next();
    _ = t.next();
    const b = t.next();
    try std.testing.expectEqual(@as(usize, 2), b.line);
    _ = t.next();
    const c = t.next();
    try std.testing.expectEqual(@as(usize, 3), c.line);
    _ = t.next();
    const d = t.next();
    try std.testing.expectEqual(@as(usize, 4), d.line);
    // NUL is U+FFFD, an ident code point.
    t = Tokenizer.init("a\x00b");
    const token = t.next();
    try std.testing.expectEqual(TokenType.ident, token.token_type);
    const decoded = try decode(std.testing.allocator, token.value);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualStrings("a\u{FFFD}b", decoded);
    // A string with a CRLF is a bad string ended at the CR.
    try expectTokens("'a\r\nb", &.{ .bad_string, .whitespace, .ident });
}

test "decode: escaped code points, their limits, and escaped newlines" {
    const cases = [_]struct { raw: []const u8, want: []const u8 }{
        .{ .raw = "\\41", .want = "A" },
        .{ .raw = "\\000041x", .want = "Ax" },
        .{ .raw = "\\41 B", .want = "AB" },
        .{ .raw = "\\0", .want = "\u{FFFD}" },
        .{ .raw = "\\D800", .want = "\u{FFFD}" },
        .{ .raw = "\\110000", .want = "\u{FFFD}" },
        .{ .raw = "a\\\nb", .want = "ab" },
        .{ .raw = "\\", .want = "\u{FFFD}" },
        .{ .raw = "\\é", .want = "é" },
    };
    for (cases) |case| {
        const got = try decode(std.testing.allocator, case.raw);
        defer std.testing.allocator.free(got);
        try std.testing.expectEqualStrings(case.want, got);
    }
}
