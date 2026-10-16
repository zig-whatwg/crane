//! CSS Syntax Level 3 tokenizer for selectors.
//!
//! Selectors are "parsed according to a CSS grammar" (Selectors 4 16, DOM
//! "scope-match a selectors string"), so a selector string is first turned
//! into CSS tokens exactly as CSS Syntax 3 section 4 does, and the parser
//! (parser.zig) matches the grammar against those tokens.
//!
//! Spec: https://drafts.csswg.org/css-syntax-3/#tokenization (cached in
//! specs/w3c/css-syntax-3.md, Editor's Draft of 12 October 2026).
//!
//! ## Shape
//!
//! - Allocation-free and zero-copy: a token's `value` is a slice of the input
//!   as written. A value written with an escape, a NUL or an encoded
//!   surrogate has `needs_decode` set, and `decode` gives the value the spec
//!   defines (the parser decodes those, once, into memory its result owns).
//! - Preprocessing (section 3.3) happens as the input is read, not as a copy:
//!   CR, CRLF and FF are newlines, and NUL - and a surrogate, which a
//!   DOMString can carry as WTF-8 - decodes as U+FFFD.
//! - The input is UTF-8. Every code point at or above U+0080 is an ident code
//!   point. Deviation from the current text, which lists only some
//!   non-ASCII ranges as "non-ASCII ident code points": Chrome, Firefox and
//!   Safari all treat every non-ASCII code point as one (Blink
//!   css_tokenizer_input_stream `IsNameStartCodePoint`, cssparser's
//!   `b'\x80'..=b'\xFF'`), and WPT dom/nodes/ParentNode-querySelector-escapes
//!   (`#\u{A0}`, `#\u{2003}` match) passes in all three at wpt.fyi cc74d2669f.
//! - A tokenizer never fails: anything the grammar cannot use is a delim, a
//!   bad-string or a bad-url token, and the parser rejects it.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// A CSS token (CSS Syntax 3 section 4).
pub const Token = struct {
    tag: Tag,
    /// The token's value as written:
    /// - ident: the whole token; function: its name, without "(";
    ///   at-keyword: the name after "@"; hash: the name after "#"
    /// - string / bad-string: the text between the quotes (a string cut off
    ///   by the end of the input has no closing quote)
    /// - url: the argument, without the whitespace around it
    /// - number / percentage: the number as written (no "%");
    ///   dimension: its unit (the number is `number`)
    /// - delim: its one code point; whitespace and the rest: the text
    value: []const u8,
    /// Byte offsets of the whole token in the input.
    start: usize,
    end: usize,
    /// `value` holds an escape, a NUL or an encoded surrogate: `decode` it.
    needs_decode: bool = false,
    /// hash: its type flag is "id" (the name would start an ident sequence).
    hash_is_id: bool = false,
    /// number, percentage, dimension: the numeric value, its type flag
    /// ("integer" or "number") and its sign character.
    number: f64 = 0,
    is_integer: bool = true,
    sign: Sign = .none,
    /// delim: its code point.
    delim: u21 = 0,

    pub const Sign = enum { none, plus, minus };

    pub const Tag = enum {
        ident,
        function,
        at_keyword,
        hash,
        string,
        bad_string,
        url,
        bad_url,
        delim,
        number,
        percentage,
        dimension,
        whitespace,
        cdo,
        cdc,
        colon,
        semicolon,
        comma,
        lbracket,
        rbracket,
        lparen,
        rparen,
        lbrace,
        rbrace,
        eof,
    };

    /// Whether this is a delim token with code point `c`.
    pub fn isDelim(self: Token, c: u21) bool {
        return self.tag == .delim and self.delim == c;
    }
};

/// Tokenizer state: a position in the input.
pub const Tokenizer = struct {
    input: []const u8,
    pos: usize = 0,
    /// Used only by `tokenize`; `nextToken` never allocates.
    allocator: Allocator,

    pub fn init(allocator: Allocator, input: []const u8) Tokenizer {
        return .{ .input = input, .allocator = allocator };
    }

    /// CSS Syntax 3 section 4: "tokenize": every token up to and including
    /// the EOF token. Caller owns the slice.
    pub fn tokenize(self: *Tokenizer) Allocator.Error![]Token {
        var tokens: std.ArrayList(Token) = .empty;
        errdefer tokens.deinit(self.allocator);
        while (true) {
            const token = self.nextToken() catch unreachable;
            try tokens.append(self.allocator, token);
            if (token.tag == .eof) break;
        }
        return try tokens.toOwnedSlice(self.allocator);
    }

    /// CSS Syntax 3 4.3.1 "consume a token" (unicode ranges not allowed).
    pub fn nextToken(self: *Tokenizer) error{}!Token {
        // "Consume comments."
        self.consumeComments();

        const start = self.pos;
        // "Consume the next input code point."
        if (self.pos >= self.input.len) return .{ .tag = .eof, .value = "", .start = start, .end = start };
        const c = self.input[self.pos];
        switch (c) {
            // whitespace: "Consume as much whitespace as possible. Return a
            // <whitespace-token>."
            ' ', '\t', '\n', '\r', 0x0C => {
                while (self.pos < self.input.len and isWhitespace(self.input[self.pos])) self.pos += 1;
                return self.simple(.whitespace, start);
            },
            // U+0022 QUOTATION MARK, U+0027 APOSTROPHE: "Consume a string
            // token and return it."
            '"', '\'' => {
                self.pos += 1;
                return self.consumeString(start, c);
            },
            '#' => {
                self.pos += 1;
                // "If the next input code point is an ident code point or the
                // next two input code points are a valid escape, then:"
                if (self.pos < self.input.len and (isIdentCodePoint(self.input[self.pos]) or self.validEscapeAt(self.pos))) {
                    // "2. If the next 3 input code points would start an
                    // ident sequence, set the type flag to "id"."
                    const is_id = self.wouldStartIdentAt(self.pos);
                    // "3. Consume an ident sequence, and set the value."
                    const name_start = self.pos;
                    const escaped = self.consumeIdentSequence();
                    return .{ .tag = .hash, .value = self.input[name_start..self.pos], .start = start, .end = self.pos, .needs_decode = escaped, .hash_is_id = is_id };
                }
                return self.delimToken(start, '#');
            },
            '(' => return self.single(.lparen, start),
            ')' => return self.single(.rparen, start),
            '+' => {
                // "If the input stream starts with a number, reconsume the
                // current input code point, consume a numeric token."
                if (self.wouldStartNumberAt(self.pos)) return self.consumeNumeric(start);
                return self.delimToken(start, '+');
            },
            ',' => return self.single(.comma, start),
            '-' => {
                if (self.wouldStartNumberAt(self.pos)) return self.consumeNumeric(start);
                // "Otherwise, if the next 2 input code points are U+002D
                // HYPHEN-MINUS U+003E GREATER-THAN SIGN (->), consume them and
                // return a <CDC-token>."
                if (self.pos + 2 < self.input.len and self.input[self.pos + 1] == '-' and self.input[self.pos + 2] == '>') {
                    self.pos += 3;
                    return self.simple(.cdc, start);
                }
                if (self.wouldStartIdentAt(self.pos)) return self.consumeIdentLike(start);
                return self.delimToken(start, '-');
            },
            '.' => {
                if (self.wouldStartNumberAt(self.pos)) return self.consumeNumeric(start);
                return self.delimToken(start, '.');
            },
            ':' => return self.single(.colon, start),
            ';' => return self.single(.semicolon, start),
            '<' => {
                // "If the next 3 input code points are !--, consume them and
                // return a <CDO-token>."
                if (std.mem.startsWith(u8, self.input[self.pos + 1 ..], "!--")) {
                    self.pos += 4;
                    return self.simple(.cdo, start);
                }
                return self.delimToken(start, '<');
            },
            '@' => {
                self.pos += 1;
                if (self.wouldStartIdentAt(self.pos)) {
                    const name_start = self.pos;
                    const escaped = self.consumeIdentSequence();
                    return .{ .tag = .at_keyword, .value = self.input[name_start..self.pos], .start = start, .end = self.pos, .needs_decode = escaped };
                }
                self.pos = start;
                return self.delimToken(start, '@');
            },
            '[' => return self.single(.lbracket, start),
            '\\' => {
                // "If the input stream starts with a valid escape, reconsume
                // the current input code point, consume an ident-like token."
                if (self.validEscapeAt(self.pos)) return self.consumeIdentLike(start);
                // "Otherwise, this is a parse error. Return a <delim-token>."
                return self.delimToken(start, '\\');
            },
            ']' => return self.single(.rbracket, start),
            '{' => return self.single(.lbrace, start),
            '}' => return self.single(.rbrace, start),
            '0'...'9' => return self.consumeNumeric(start),
            else => {
                // "ident-start code point: reconsume, consume an ident-like
                // token." (U+0055/U+0075 too: unicode ranges are not allowed.)
                if (isIdentStart(c)) return self.consumeIdentLike(start);
                // "anything else: Return a <delim-token>."
                return self.delimToken(start, c);
            },
        }
    }

    fn simple(self: *Tokenizer, tag: Token.Tag, start: usize) Token {
        return .{ .tag = tag, .value = self.input[start..self.pos], .start = start, .end = self.pos };
    }

    fn single(self: *Tokenizer, tag: Token.Tag, start: usize) Token {
        self.pos = start + 1;
        return self.simple(tag, start);
    }

    /// A <delim-token> for the ASCII code point at `start`.
    fn delimToken(self: *Tokenizer, start: usize, c: u8) Token {
        self.pos = start + 1;
        return .{ .tag = .delim, .value = self.input[start..self.pos], .start = start, .end = self.pos, .delim = c };
    }

    /// 4.3.2 "Consume comments".
    fn consumeComments(self: *Tokenizer) void {
        while (self.pos + 1 < self.input.len and self.input[self.pos] == '/' and self.input[self.pos + 1] == '*') {
            if (std.mem.indexOfPos(u8, self.input, self.pos + 2, "*/")) |end| {
                self.pos = end + 2;
            } else {
                // "or up to an EOF code point" (a parse error).
                self.pos = self.input.len;
            }
        }
    }

    /// 4.3.3 "Consume a numeric token". The stream starts with a number.
    fn consumeNumeric(self: *Tokenizer, start: usize) Token {
        // "Consume a number and let number be the result."
        var token = self.consumeNumber(start);
        // "If the next 3 input code points would start an ident sequence":
        // a <dimension-token> whose unit is the ident sequence.
        if (self.wouldStartIdentAt(self.pos)) {
            const unit_start = self.pos;
            token.needs_decode = self.consumeIdentSequence();
            token.tag = .dimension;
            token.value = self.input[unit_start..self.pos];
            token.end = self.pos;
            return token;
        }
        // "Otherwise, if the next input code point is U+0025 PERCENTAGE SIGN
        // (%), consume it": a <percentage-token>.
        if (self.pos < self.input.len and self.input[self.pos] == '%') {
            self.pos += 1;
            token.tag = .percentage;
            token.end = self.pos;
            return token;
        }
        return token;
    }

    /// 4.3.13 "Consume a number": a <number-token> carrying the value, its
    /// type flag and its sign character; `value` is the number as written.
    fn consumeNumber(self: *Tokenizer, start: usize) Token {
        var token = Token{ .tag = .number, .value = "", .start = start, .end = start };
        // "2. If the next input code point is + or -, consume it ... set sign
        // character to it."
        if (self.pos < self.input.len and (self.input[self.pos] == '+' or self.input[self.pos] == '-')) {
            token.sign = if (self.input[self.pos] == '+') .plus else .minus;
            self.pos += 1;
        }
        // "3. While the next input code point is a digit, consume it."
        while (self.pos < self.input.len and std.ascii.isDigit(self.input[self.pos])) self.pos += 1;
        // "4. If the next 2 input code points are . followed by a digit":
        if (self.pos + 1 < self.input.len and self.input[self.pos] == '.' and std.ascii.isDigit(self.input[self.pos + 1])) {
            self.pos += 2;
            while (self.pos < self.input.len and std.ascii.isDigit(self.input[self.pos])) self.pos += 1;
            token.is_integer = false;
        }
        // "5. If the next 2 or 3 input code points are E or e, optionally
        // followed by - or +, followed by a digit":
        if (self.pos < self.input.len and (self.input[self.pos] == 'e' or self.input[self.pos] == 'E')) {
            var next = self.pos + 1;
            if (next < self.input.len and (self.input[next] == '+' or self.input[next] == '-')) next += 1;
            if (next < self.input.len and std.ascii.isDigit(self.input[next])) {
                self.pos = next;
                while (self.pos < self.input.len and std.ascii.isDigit(self.input[self.pos])) self.pos += 1;
                token.is_integer = false;
            }
        }
        token.value = self.input[start..self.pos];
        token.end = self.pos;
        // "6. Let value be the result of interpreting number part as a
        // base-10 number", scaled by the exponent.
        token.number = std.fmt.parseFloat(f64, token.value) catch 0;
        return token;
    }

    /// 4.3.4 "Consume an ident-like token". The stream starts with an ident
    /// sequence.
    fn consumeIdentLike(self: *Tokenizer, start: usize) Token {
        // "Consume an ident sequence, and let string be the result."
        const escaped = self.consumeIdentSequence();
        const name = self.input[start..self.pos];
        const next_is_paren = self.pos < self.input.len and self.input[self.pos] == '(';
        // "If string's value is an ASCII case-insensitive match for "url",
        // and the next input code point is (, consume it."
        if (next_is_paren and !escaped and std.ascii.eqlIgnoreCase(name, "url")) {
            self.pos += 1;
            // "While the next two input code points are whitespace, consume
            // the next input code point."
            while (self.pos + 1 < self.input.len and isWhitespace(self.input[self.pos]) and isWhitespace(self.input[self.pos + 1])) self.pos += 1;
            // "If the next one or two input code points are " ', or
            // whitespace followed by " or ', create a <function-token>."
            var look = self.pos;
            if (look < self.input.len and isWhitespace(self.input[look])) look += 1;
            if (look < self.input.len and (self.input[look] == '"' or self.input[look] == '\'')) {
                return .{ .tag = .function, .value = name, .start = start, .end = self.pos };
            }
            // "Otherwise, consume a url token, and return it."
            return self.consumeUrl(start);
        }
        // "Otherwise, if the next input code point is (, consume it": a
        // <function-token>.
        if (next_is_paren) {
            self.pos += 1;
            return .{ .tag = .function, .value = name, .start = start, .end = self.pos, .needs_decode = escaped };
        }
        return .{ .tag = .ident, .value = name, .start = start, .end = self.pos, .needs_decode = escaped };
    }

    /// 4.3.5 "Consume a string token" ending at `quote` (already consumed).
    fn consumeString(self: *Tokenizer, start: usize, quote: u8) Token {
        const value_start = self.pos;
        var escaped = false;
        while (true) {
            // "Repeatedly consume the next input code point":
            if (self.pos >= self.input.len) {
                // "EOF: This is a parse error. Return the <string-token>."
                return .{ .tag = .string, .value = self.input[value_start..self.pos], .start = start, .end = self.pos, .needs_decode = escaped };
            }
            const c = self.input[self.pos];
            if (c == quote) {
                // "ending code point: Return the <string-token>."
                const value = self.input[value_start..self.pos];
                self.pos += 1;
                return .{ .tag = .string, .value = value, .start = start, .end = self.pos, .needs_decode = escaped };
            }
            if (isNewline(c)) {
                // "newline: This is a parse error. Reconsume the current input
                // code point, create a <bad-string-token>, and return it."
                return .{ .tag = .bad_string, .value = self.input[value_start..self.pos], .start = start, .end = self.pos };
            }
            if (c == '\\') {
                escaped = true;
                // "If the next input code point is EOF, do nothing.
                // Otherwise, if the next input code point is a newline,
                // consume it. Otherwise, consume an escaped code point."
                self.pos += 1;
                if (self.pos >= self.input.len) continue;
                if (isNewline(self.input[self.pos])) {
                    self.pos += newlineLength(self.input, self.pos);
                    continue;
                }
                self.consumeEscapedCodePoint();
                continue;
            }
            if (c == 0 or isEncodedSurrogate(self.input, self.pos)) escaped = true;
            // "anything else: Append the current input code point."
            self.pos += 1;
        }
    }

    /// 4.3.6 "Consume a url token": "url(" already consumed.
    fn consumeUrl(self: *Tokenizer, start: usize) Token {
        // "2. Consume as much whitespace as possible."
        while (self.pos < self.input.len and isWhitespace(self.input[self.pos])) self.pos += 1;
        const value_start = self.pos;
        var escaped = false;
        while (true) {
            if (self.pos >= self.input.len) {
                // "EOF: This is a parse error. Return the <url-token>."
                return .{ .tag = .url, .value = self.input[value_start..self.pos], .start = start, .end = self.pos, .needs_decode = escaped };
            }
            const c = self.input[self.pos];
            switch (c) {
                ')' => {
                    const value = self.input[value_start..self.pos];
                    self.pos += 1;
                    return .{ .tag = .url, .value = value, .start = start, .end = self.pos, .needs_decode = escaped };
                },
                ' ', '\t', '\n', '\r', 0x0C => {
                    // "Consume as much whitespace as possible. If the next
                    // input code point is ) or EOF, consume it and return the
                    // <url-token>; otherwise, consume the remnants of a bad
                    // url, create a <bad-url-token>."
                    const value = self.input[value_start..self.pos];
                    while (self.pos < self.input.len and isWhitespace(self.input[self.pos])) self.pos += 1;
                    if (self.pos >= self.input.len) return .{ .tag = .url, .value = value, .start = start, .end = self.pos, .needs_decode = escaped };
                    if (self.input[self.pos] == ')') {
                        self.pos += 1;
                        return .{ .tag = .url, .value = value, .start = start, .end = self.pos, .needs_decode = escaped };
                    }
                    return self.consumeBadUrl(start);
                },
                '"', '\'', '(' => return self.consumeBadUrl(start),
                '\\' => {
                    // "If the stream starts with a valid escape, consume an
                    // escaped code point. Otherwise ... bad url."
                    if (!self.validEscapeAt(self.pos)) return self.consumeBadUrl(start);
                    escaped = true;
                    self.pos += 1;
                    self.consumeEscapedCodePoint();
                },
                else => {
                    if (isNonPrintable(c)) return self.consumeBadUrl(start);
                    if (c == 0 or isEncodedSurrogate(self.input, self.pos)) escaped = true;
                    self.pos += 1;
                },
            }
        }
    }

    /// 4.3.15 "Consume the remnants of a bad url", returning the
    /// <bad-url-token>.
    fn consumeBadUrl(self: *Tokenizer, start: usize) Token {
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (c == ')') {
                self.pos += 1;
                break;
            }
            if (self.validEscapeAt(self.pos)) {
                self.pos += 1;
                self.consumeEscapedCodePoint();
                continue;
            }
            self.pos += 1;
        }
        return self.simple(.bad_url, start);
    }

    /// 4.3.7 "Consume an escaped code point": the "\" is consumed and the
    /// escape is valid. Advances past it; `decode` computes the code point.
    fn consumeEscapedCodePoint(self: *Tokenizer) void {
        // "EOF: return U+FFFD" - nothing to consume.
        if (self.pos >= self.input.len) return;
        const c = self.input[self.pos];
        if (std.ascii.isHex(c)) {
            // "Consume as many hex digits as possible, but no more than 5"
            // after the first, then one whitespace.
            var n: usize = 0;
            while (n < 6 and self.pos < self.input.len and std.ascii.isHex(self.input[self.pos])) : (n += 1) self.pos += 1;
            if (self.pos < self.input.len and isWhitespace(self.input[self.pos])) self.pos += newlineLength(self.input, self.pos);
            return;
        }
        // "anything else: Return the current input code point."
        self.pos += codePointLength(self.input, self.pos);
    }

    /// 4.3.12 "Consume an ident sequence". Returns whether the sequence needs
    /// decoding (it holds an escape, a NUL or an encoded surrogate).
    fn consumeIdentSequence(self: *Tokenizer) bool {
        var escaped = false;
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (isIdentCodePoint(c)) {
                if (c == 0 or isEncodedSurrogate(self.input, self.pos)) escaped = true;
                self.pos += if (c < 0x80) 1 else codePointLength(self.input, self.pos);
            } else if (self.validEscapeAt(self.pos)) {
                escaped = true;
                self.pos += 1;
                self.consumeEscapedCodePoint();
            } else break;
        }
        return escaped;
    }

    /// 4.3.8 "Check if two code points are a valid escape", for the code
    /// points at `at` and `at + 1`. EOF is no newline, so "\" at the end of
    /// the input is a valid escape (it decodes as U+FFFD).
    fn validEscapeAt(self: *const Tokenizer, at: usize) bool {
        if (at >= self.input.len or self.input[at] != '\\') return false;
        if (at + 1 >= self.input.len) return true;
        return !isNewline(self.input[at + 1]);
    }

    /// 4.3.9 "Check if three code points would start an ident sequence",
    /// starting at `at`.
    fn wouldStartIdentAt(self: *const Tokenizer, at: usize) bool {
        if (at >= self.input.len) return false;
        const c = self.input[at];
        if (c == '-') {
            // "If the second code point is an ident-start code point or a
            // U+002D HYPHEN-MINUS, or the second and third code points are a
            // valid escape, return true."
            if (at + 1 >= self.input.len) return false;
            const second = self.input[at + 1];
            return isIdentStart(second) or second == '-' or self.validEscapeAt(at + 1);
        }
        if (isIdentStart(c)) return true;
        if (c == '\\') return self.validEscapeAt(at);
        return false;
    }

    /// 4.3.10 "Check if three code points would start a number", at `at`.
    fn wouldStartNumberAt(self: *const Tokenizer, at: usize) bool {
        if (at >= self.input.len) return false;
        const c = self.input[at];
        const second: u8 = if (at + 1 < self.input.len) self.input[at + 1] else 0;
        const third: u8 = if (at + 2 < self.input.len) self.input[at + 2] else 0;
        return switch (c) {
            '+', '-' => std.ascii.isDigit(second) or (second == '.' and std.ascii.isDigit(third)),
            '.' => std.ascii.isDigit(second),
            '0'...'9' => true,
            else => false,
        };
    }
};

// ============================================================================
// Code point classes (CSS Syntax 3 4.2), over UTF-8 bytes
// ============================================================================

/// "whitespace": a newline, U+0009 or U+0020 (CR and FF are newlines after
/// preprocessing).
pub fn isWhitespace(c: u8) bool {
    return c == ' ' or c == '\t' or isNewline(c);
}

/// "newline": U+000A, and U+000D and U+000C, which preprocessing turns
/// into U+000A.
fn isNewline(c: u8) bool {
    return c == '\n' or c == '\r' or c == 0x0C;
}

/// "ident-start code point": a letter, "_", a non-ASCII code point, or NUL
/// (U+FFFD after preprocessing). `c` is a code point's first byte.
fn isIdentStart(c: u8) bool {
    return std.ascii.isAlphabetic(c) or c == '_' or c >= 0x80 or c == 0;
}

/// "ident code point": an ident-start code point, a digit or "-".
fn isIdentCodePoint(c: u8) bool {
    return isIdentStart(c) or std.ascii.isDigit(c) or c == '-';
}

/// "non-printable code point".
fn isNonPrintable(c: u8) bool {
    return (c <= 0x08) or c == 0x0B or (c >= 0x0E and c <= 0x1F) or c == 0x7F;
}

/// The length of the newline (or whitespace) at `at`: CRLF is one.
fn newlineLength(input: []const u8, at: usize) usize {
    if (input[at] == '\r' and at + 1 < input.len and input[at + 1] == '\n') return 2;
    return 1;
}

/// The byte length of the UTF-8 sequence starting at `at` (1 for a stray
/// continuation byte), never past the end of the input.
fn codePointLength(input: []const u8, at: usize) usize {
    const len: usize = std.unicode.utf8ByteSequenceLength(input[at]) catch 1;
    return @min(len, input.len - at);
}

/// Whether the bytes at `at` are a surrogate encoded as WTF-8 (ED A0..BF xx),
/// which preprocessing replaces with U+FFFD.
fn isEncodedSurrogate(input: []const u8, at: usize) bool {
    return input[at] == 0xED and at + 1 < input.len and input[at + 1] >= 0xA0 and input[at + 1] <= 0xBF;
}

// ============================================================================
// Decoding
// ============================================================================

/// A token's value as the spec defines it, decoded from `token.value`:
/// escapes consumed (4.3.7), NUL and surrogates as U+FFFD, and in a string a
/// "\" before a newline or the end of the input dropped. Caller owns it.
pub fn decode(allocator: Allocator, token: Token) Allocator.Error![]u8 {
    const raw = token.value;
    const is_string = token.tag == .string or token.tag == .bad_string;
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.ensureTotalCapacity(allocator, raw.len);
    var i: usize = 0;
    while (i < raw.len) {
        const c = raw[i];
        if (c == '\\') {
            i += 1;
            if (i >= raw.len) {
                // A string: "If the next input code point is EOF, do
                // nothing." Elsewhere 4.3.7 "EOF: return U+FFFD".
                if (!is_string) try appendCodePoint(allocator, &out, 0xFFFD);
                continue;
            }
            if (is_string and isNewline(raw[i])) {
                // "Otherwise, if the next input code point is a newline,
                // consume it."
                i += newlineLength(raw, i);
                continue;
            }
            if (std.ascii.isHex(raw[i])) {
                // "Interpret the hex digits as a hexadecimal number. If this
                // number is zero, or is for a surrogate, or is greater than
                // the maximum allowed code point, return U+FFFD."
                var value: u32 = 0;
                var n: usize = 0;
                while (n < 6 and i < raw.len and std.ascii.isHex(raw[i])) : (n += 1) {
                    value = value * 16 + (std.fmt.charToDigit(raw[i], 16) catch 0);
                    i += 1;
                }
                if (i < raw.len and isWhitespace(raw[i])) i += newlineLength(raw, i);
                const cp: u21 = if (value == 0 or (value >= 0xD800 and value <= 0xDFFF) or value > 0x10FFFF) 0xFFFD else @intCast(value);
                try appendCodePoint(allocator, &out, cp);
                continue;
            }
            // "anything else: Return the current input code point."
            i += try appendRawCodePoint(allocator, &out, raw, i);
            continue;
        }
        i += try appendRawCodePoint(allocator, &out, raw, i);
    }
    return try out.toOwnedSlice(allocator);
}

/// Append the code point at `raw[at]`, with NUL and an encoded surrogate as
/// U+FFFD. Returns its byte length.
fn appendRawCodePoint(allocator: Allocator, out: *std.ArrayList(u8), raw: []const u8, at: usize) Allocator.Error!usize {
    if (raw[at] == 0) {
        try appendCodePoint(allocator, out, 0xFFFD);
        return 1;
    }
    const len = codePointLength(raw, at);
    if (isEncodedSurrogate(raw, at)) {
        try appendCodePoint(allocator, out, 0xFFFD);
        return len;
    }
    try out.appendSlice(allocator, raw[at .. at + len]);
    return len;
}

fn appendCodePoint(allocator: Allocator, out: *std.ArrayList(u8), cp: u21) Allocator.Error!void {
    var buf: [4]u8 = undefined;
    const len = std.unicode.utf8Encode(cp, &buf) catch return out.appendSlice(allocator, "\u{FFFD}");
    try out.appendSlice(allocator, buf[0..len]);
}
