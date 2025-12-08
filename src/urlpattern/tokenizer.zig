//! URLPattern Tokenizer
//!
//! Implements the tokenization algorithm from the URLPattern specification.
//! See: https://urlpattern.spec.whatwg.org/#tokenizing
//!
//! A pattern string is tokenized into a sequence of tokens that are then
//! parsed into parts. Tokens represent the lexical structure of the pattern.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Token types as defined in the URLPattern spec
pub const TokenType = enum {
    /// U+007B ({) code point
    open,
    /// U+007D (}) code point
    close,
    /// String of form "(<regular expression>)"
    regexp,
    /// String of form ":<name>"
    name,
    /// Valid pattern code point without special meaning
    char,
    /// Code point escaped with backslash "\<char>"
    escaped_char,
    /// Modifier ? or +
    other_modifier,
    /// U+002A (*) - can be wildcard or modifier
    asterisk,
    /// End of pattern string
    end,
    /// Invalid code point
    invalid_char,
};

/// A token representing a lexical unit in a pattern string
pub const Token = struct {
    /// The type of this token
    type: TokenType,
    /// Position of first code point in pattern string
    index: usize,
    /// The code points from the pattern string
    value: []const u8,
};

/// Tokenize policy
pub const TokenizePolicy = enum {
    /// Throw on invalid characters
    strict,
    /// Accept invalid characters as invalid_char tokens
    lenient,
};

/// Tokenizer state machine
pub const Tokenizer = struct {
    /// Input pattern string
    input: []const u8,
    /// Tokenize policy
    policy: TokenizePolicy,
    /// Result token list
    token_list: std.ArrayListUnmanaged(Token),
    /// Current position in input
    index: usize,
    /// Position after current code point
    next_index: usize,
    /// Current code point (as byte for ASCII)
    code_point: u8,
    /// Allocator for token list
    allocator: Allocator,

    const Self = @This();

    /// Initialize a new tokenizer
    pub fn init(allocator: Allocator, input: []const u8, policy: TokenizePolicy) Self {
        return Self{
            .input = input,
            .policy = policy,
            .token_list = .{},
            .index = 0,
            .next_index = 0,
            .code_point = 0,
            .allocator = allocator,
        };
    }

    /// Free resources
    pub fn deinit(self: *Self) void {
        self.token_list.deinit(self.allocator);
    }

    /// Get the next code point from input
    fn getNextCodePoint(self: *Self) void {
        if (self.next_index < self.input.len) {
            self.code_point = self.input[self.next_index];
            self.next_index += 1;
        }
    }

    /// Seek to position and get the next code point
    fn seekAndGetNextCodePoint(self: *Self, position: usize) void {
        self.next_index = position;
        self.getNextCodePoint();
    }

    /// Add a token with explicit parameters
    fn addToken(self: *Self, token_type: TokenType, next_position: usize, value_position: usize, value_length: usize) !void {
        const token = Token{
            .type = token_type,
            .index = self.index,
            .value = self.input[value_position..][0..value_length],
        };
        try self.token_list.append(self.allocator, token);
        self.index = next_position;
    }

    /// Add a token with computed length
    fn addTokenWithDefaultLength(self: *Self, token_type: TokenType, next_position: usize, value_position: usize) !void {
        const computed_length = next_position - value_position;
        try self.addToken(token_type, next_position, value_position, computed_length);
    }

    /// Add a token with default position and length
    fn addTokenWithDefaultPositionAndLength(self: *Self, token_type: TokenType) !void {
        try self.addTokenWithDefaultLength(token_type, self.next_index, self.index);
    }

    /// Process a tokenizing error
    fn processTokenizingError(self: *Self, next_position: usize, value_position: usize) !void {
        if (self.policy == .strict) {
            return error.InvalidPattern;
        }
        // Lenient mode: add as invalid_char token
        try self.addTokenWithDefaultLength(.invalid_char, next_position, value_position);
    }

    /// Check if code point is valid for identifier (per ECMAScript IdentifierStart/IdentifierPart)
    fn isValidNameCodePoint(code_point: u8, first: bool) bool {
        // Simplified: allow ASCII letters, digits (not first), underscore, dollar
        if (code_point == '_' or code_point == '$') return true;
        if (code_point >= 'a' and code_point <= 'z') return true;
        if (code_point >= 'A' and code_point <= 'Z') return true;
        if (!first and code_point >= '0' and code_point <= '9') return true;
        return false;
    }

    /// Run the tokenization algorithm
    pub fn tokenize(self: *Self) !void {
        while (self.index < self.input.len) {
            self.seekAndGetNextCodePoint(self.index);

            // Asterisk (*)
            if (self.code_point == '*') {
                try self.addTokenWithDefaultPositionAndLength(.asterisk);
                continue;
            }

            // Other modifier (+ or ?)
            if (self.code_point == '+' or self.code_point == '?') {
                try self.addTokenWithDefaultPositionAndLength(.other_modifier);
                continue;
            }

            // Escaped character (\)
            if (self.code_point == '\\') {
                if (self.index == self.input.len - 1) {
                    try self.processTokenizingError(self.next_index, self.index);
                    continue;
                }
                const escaped_index = self.next_index;
                self.getNextCodePoint();
                try self.addTokenWithDefaultLength(.escaped_char, self.next_index, escaped_index);
                continue;
            }

            // Open brace ({)
            if (self.code_point == '{') {
                try self.addTokenWithDefaultPositionAndLength(.open);
                continue;
            }

            // Close brace (})
            if (self.code_point == '}') {
                try self.addTokenWithDefaultPositionAndLength(.close);
                continue;
            }

            // Name token (:name)
            if (self.code_point == ':') {
                var name_position = self.next_index;
                const name_start = name_position;

                while (name_position < self.input.len) {
                    self.seekAndGetNextCodePoint(name_position);
                    const first_code_point = (name_position == name_start);
                    const valid_code_point = isValidNameCodePoint(self.code_point, first_code_point);

                    if (!valid_code_point) break;
                    name_position = self.next_index;
                }

                if (name_position <= name_start) {
                    try self.processTokenizingError(name_start, self.index);
                    continue;
                }

                try self.addTokenWithDefaultLength(.name, name_position, name_start);
                continue;
            }

            // Regexp token ((regexp))
            if (self.code_point == '(') {
                var depth: usize = 1;
                var regexp_position = self.next_index;
                const regexp_start = regexp_position;
                var has_error = false;

                while (regexp_position < self.input.len) {
                    self.seekAndGetNextCodePoint(regexp_position);

                    // Regexp must be ASCII
                    if (self.code_point > 127) {
                        try self.processTokenizingError(regexp_start, self.index);
                        has_error = true;
                        break;
                    }

                    // Can't start with ?
                    if (regexp_position == regexp_start and self.code_point == '?') {
                        try self.processTokenizingError(regexp_start, self.index);
                        has_error = true;
                        break;
                    }

                    // Handle escape
                    if (self.code_point == '\\') {
                        if (regexp_position == self.input.len - 1) {
                            try self.processTokenizingError(regexp_start, self.index);
                            has_error = true;
                            break;
                        }
                        self.getNextCodePoint();
                        if (self.code_point > 127) {
                            try self.processTokenizingError(regexp_start, self.index);
                            has_error = true;
                            break;
                        }
                        regexp_position = self.next_index;
                        continue;
                    }

                    // Closing paren
                    if (self.code_point == ')') {
                        depth -= 1;
                        if (depth == 0) {
                            regexp_position = self.next_index;
                            break;
                        }
                    }
                    // Opening paren (nested groups)
                    else if (self.code_point == '(') {
                        depth += 1;
                        if (regexp_position == self.input.len - 1) {
                            try self.processTokenizingError(regexp_start, self.index);
                            has_error = true;
                            break;
                        }
                        const temporary_position = self.next_index;
                        self.getNextCodePoint();
                        // Must be followed by ? for non-capturing group
                        if (self.code_point != '?') {
                            try self.processTokenizingError(regexp_start, self.index);
                            has_error = true;
                            break;
                        }
                        self.next_index = temporary_position;
                    }

                    regexp_position = self.next_index;
                }

                if (has_error) continue;

                if (depth != 0) {
                    try self.processTokenizingError(regexp_start, self.index);
                    continue;
                }

                const regexp_length = regexp_position - regexp_start - 1;
                if (regexp_length == 0) {
                    try self.processTokenizingError(regexp_start, self.index);
                    continue;
                }

                try self.addToken(.regexp, regexp_position, regexp_start, regexp_length);
                continue;
            }

            // Regular character
            try self.addTokenWithDefaultPositionAndLength(.char);
        }

        // Add end token
        try self.addTokenWithDefaultLength(.end, self.index, self.index);
    }

    /// Get tokens as owned slice (transfers ownership)
    pub fn toOwnedSlice(self: *Self) ![]Token {
        return self.token_list.toOwnedSlice(self.allocator);
    }
};

/// Result of tokenization - owns the token list
pub const TokenizeResult = struct {
    tokens: []Token,
    allocator: Allocator,

    pub fn deinit(self: *TokenizeResult) void {
        self.allocator.free(self.tokens);
    }

    /// Get the items as a slice
    pub fn items(self: *const TokenizeResult) []const Token {
        return self.tokens;
    }
};

/// Tokenize a pattern string
pub fn tokenize(allocator: Allocator, input: []const u8, policy: TokenizePolicy) !TokenizeResult {
    var tok = Tokenizer.init(allocator, input, policy);
    errdefer tok.deinit();

    try tok.tokenize();

    // Transfer ownership of the underlying slice
    const tokens = try tok.token_list.toOwnedSlice(allocator);
    tok.token_list = .{}; // Reset to empty so deinit doesn't double-free

    return TokenizeResult{
        .tokens = tokens,
        .allocator = allocator,
    };
}

// Tests

test "tokenize - simple string" {
    const allocator = std.testing.allocator;
    var tokens = try tokenize(allocator, "hello", .strict);
    defer tokens.deinit();

    try std.testing.expectEqual(@as(usize, 6), tokens.tokens.len);
    try std.testing.expectEqual(TokenType.char, tokens.tokens[0].type);
    try std.testing.expectEqualStrings("h", tokens.tokens[0].value);
    try std.testing.expectEqual(TokenType.end, tokens.tokens[5].type);
}

test "tokenize - name token" {
    const allocator = std.testing.allocator;
    var tokens = try tokenize(allocator, ":foo", .strict);
    defer tokens.deinit();

    try std.testing.expectEqual(@as(usize, 2), tokens.tokens.len);
    try std.testing.expectEqual(TokenType.name, tokens.tokens[0].type);
    try std.testing.expectEqualStrings("foo", tokens.tokens[0].value);
}

test "tokenize - regexp token" {
    const allocator = std.testing.allocator;
    var tokens = try tokenize(allocator, "(\\d+)", .strict);
    defer tokens.deinit();

    try std.testing.expectEqual(@as(usize, 2), tokens.tokens.len);
    try std.testing.expectEqual(TokenType.regexp, tokens.tokens[0].type);
    try std.testing.expectEqualStrings("\\d+", tokens.tokens[0].value);
}

test "tokenize - escaped char" {
    const allocator = std.testing.allocator;
    var tokens = try tokenize(allocator, "\\:", .strict);
    defer tokens.deinit();

    try std.testing.expectEqual(@as(usize, 2), tokens.tokens.len);
    try std.testing.expectEqual(TokenType.escaped_char, tokens.tokens[0].type);
    try std.testing.expectEqualStrings(":", tokens.tokens[0].value);
}

test "tokenize - modifiers" {
    const allocator = std.testing.allocator;
    var tokens = try tokenize(allocator, ":foo?*+", .strict);
    defer tokens.deinit();

    try std.testing.expectEqual(@as(usize, 5), tokens.tokens.len);
    try std.testing.expectEqual(TokenType.name, tokens.tokens[0].type);
    try std.testing.expectEqual(TokenType.other_modifier, tokens.tokens[1].type);
    try std.testing.expectEqualStrings("?", tokens.tokens[1].value);
    try std.testing.expectEqual(TokenType.asterisk, tokens.tokens[2].type);
    try std.testing.expectEqual(TokenType.other_modifier, tokens.tokens[3].type);
    try std.testing.expectEqualStrings("+", tokens.tokens[3].value);
}

test "tokenize - grouping braces" {
    const allocator = std.testing.allocator;
    var tokens = try tokenize(allocator, "{:foo}", .strict);
    defer tokens.deinit();

    try std.testing.expectEqual(@as(usize, 4), tokens.tokens.len);
    try std.testing.expectEqual(TokenType.open, tokens.tokens[0].type);
    try std.testing.expectEqual(TokenType.name, tokens.tokens[1].type);
    try std.testing.expectEqual(TokenType.close, tokens.tokens[2].type);
}

test "tokenize - asterisk wildcard" {
    const allocator = std.testing.allocator;
    var tokens = try tokenize(allocator, "*", .strict);
    defer tokens.deinit();

    try std.testing.expectEqual(@as(usize, 2), tokens.tokens.len);
    try std.testing.expectEqual(TokenType.asterisk, tokens.tokens[0].type);
}

test "tokenize - path pattern" {
    const allocator = std.testing.allocator;
    var tokens = try tokenize(allocator, "/:category/*", .strict);
    defer tokens.deinit();

    // / : category / *
    try std.testing.expectEqual(@as(usize, 5), tokens.tokens.len);
    try std.testing.expectEqual(TokenType.char, tokens.tokens[0].type);
    try std.testing.expectEqual(TokenType.name, tokens.tokens[1].type);
    try std.testing.expectEqualStrings("category", tokens.tokens[1].value);
    try std.testing.expectEqual(TokenType.char, tokens.tokens[2].type);
    try std.testing.expectEqual(TokenType.asterisk, tokens.tokens[3].type);
}

test "tokenize - lenient mode invalid char" {
    const allocator = std.testing.allocator;
    // Invalid: colon with no name following
    var tokens = try tokenize(allocator, ":", .lenient);
    defer tokens.deinit();

    try std.testing.expectEqual(@as(usize, 2), tokens.tokens.len);
    try std.testing.expectEqual(TokenType.invalid_char, tokens.tokens[0].type);
}

test "tokenize - strict mode invalid char" {
    const allocator = std.testing.allocator;
    // Invalid: colon with no name following
    try std.testing.expectError(error.InvalidPattern, tokenize(allocator, ":", .strict));
}

test "tokenize - complex pattern" {
    const allocator = std.testing.allocator;
    var tokens = try tokenize(allocator, "/products/:id(\\d+)?", .strict);
    defer tokens.deinit();

    // / p r o d u c t s / : id (\\d+) ?
    try std.testing.expect(tokens.tokens.len > 0);
    try std.testing.expectEqual(TokenType.char, tokens.tokens[0].type);
    try std.testing.expectEqual(TokenType.end, tokens.tokens[tokens.tokens.len - 1].type);
}
