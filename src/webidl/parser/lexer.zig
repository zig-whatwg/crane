const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");

pub const TokenType = enum {
    interface,
    partial,
    dictionary,
    @"enum",
    callback,
    typedef,
    const_kw,
    attribute,
    readonly,
    inherit,
    static,
    getter,
    setter,
    deleter,
    stringifier,
    constructor,
    optional,
    required,
    sequence,
    record,
    promise,
    includes,
    mixin,
    namespace,
    iterable,
    async_iterable,
    maplike,
    setlike,
    async,
    frozen_array,
    observable_array,

    // Legacy keywords
    in,
    raises,
    pragma,
    module,

    any,
    undefined,
    boolean,
    byte,
    octet,
    short,
    unsigned,
    long,
    float,
    double,
    unrestricted,
    bigint,
    dom_string,
    byte_string,
    usv_string,
    object,
    symbol,

    lparen,
    rparen,
    lbrace,
    rbrace,
    lbracket,
    rbracket,
    lt,
    gt,
    equals,
    colon,
    double_colon,
    semicolon,
    comma,
    question,
    ellipsis,
    asterisk,
    or_kw,
    minus,

    identifier,
    string_literal,
    integer_literal,
    float_literal,
    true_kw,
    false_kw,
    null_kw,
    infinity_kw,
    negative_infinity_kw,
    nan_kw,

    eof,
    invalid,
};

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: usize,
    column: usize,

    pub fn format(
        self: Token,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s}('{s}') at {}:{}", .{
            @tagName(self.type),
            self.lexeme,
            self.line,
            self.column,
        });
    }
};

inline fn isAsciiDigit(c: u8) bool {
    return infra.code_point.isAsciiDigit(c);
}

inline fn isAsciiHexDigit(c: u8) bool {
    return infra.code_point.isAsciiHexDigit(c);
}

inline fn isAsciiAlphanumeric(c: u8) bool {
    return infra.code_point.isAsciiAlphanumeric(c);
}

pub const Lexer = struct {
    source: []const u8,
    current: usize,
    line: usize,
    column: usize,
    allocator: Allocator,

    pub fn init(allocator: Allocator, source: []const u8) Lexer {
        return .{
            .source = source,
            .current = 0,
            .line = 1,
            .column = 1,
            .allocator = allocator,
        };
    }

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

        const token_type: TokenType = switch (c) {
            '(' => .lparen,
            ')' => .rparen,
            '{' => .lbrace,
            '}' => .rbrace,
            '[' => .lbracket,
            ']' => .rbracket,
            '<' => .lt,
            '>' => .gt,
            '=' => .equals,
            ':' => blk: {
                if (self.peek() == ':') {
                    _ = self.advance();
                    break :blk .double_colon;
                }
                break :blk .colon;
            },
            ';' => .semicolon,
            ',' => .comma,
            '?' => .question,
            '*' => .asterisk,
            '-' => blk: {
                // Only treat '-' as part of a number for hexadecimal literals like -0xFF
                if (self.peek() == '0' and (self.peekNext() == 'x' or self.peekNext() == 'X')) {
                    return try self.scanNumber(start, start_line, start_column);
                }
                break :blk .minus;
            },

            '.' => blk: {
                if (self.peek() == '.' and self.peekNext() == '.') {
                    _ = self.advance();
                    _ = self.advance();
                    break :blk .ellipsis;
                }
                break :blk .invalid;
            },

            '"' => return try self.scanString(start_line, start_column),

            '0'...'9' => return try self.scanNumber(start, start_line, start_column),

            'a'...'z', 'A'...'Z', '_' => {
                return try self.scanIdentifierOrKeyword(start, start_line, start_column);
            },

            else => .invalid,
        };

        return Token{
            .type = token_type,
            .lexeme = self.source[start..self.current],
            .line = start_line,
            .column = start_column,
        };
    }

    fn skipWhitespaceAndComments(self: *Lexer) void {
        while (!self.isAtEnd()) {
            const c = self.peek();
            switch (c) {
                ' ', '\t', '\r' => {
                    _ = self.advance();
                },
                '\n' => {
                    self.line += 1;
                    self.column = 0;
                    _ = self.advance();
                },
                '/' => {
                    if (self.peekNext() == '/') {
                        while (self.peek() != '\n' and !self.isAtEnd()) {
                            _ = self.advance();
                        }
                    } else if (self.peekNext() == '*') {
                        _ = self.advance();
                        _ = self.advance();
                        while (!self.isAtEnd()) {
                            if (self.peek() == '*' and self.peekNext() == '/') {
                                _ = self.advance();
                                _ = self.advance();
                                break;
                            }
                            if (self.peek() == '\n') {
                                self.line += 1;
                                self.column = 0;
                            }
                            _ = self.advance();
                        }
                    } else {
                        return;
                    }
                },
                '#' => {
                    // Skip preprocessor directives (legacy CORBA IDL)
                    while (self.peek() != '\n' and !self.isAtEnd()) {
                        _ = self.advance();
                    }
                },
                else => return,
            }
        }
    }

    fn scanString(self: *Lexer, start_line: usize, start_column: usize) !Token {
        const start = self.current;

        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') {
                self.line += 1;
                self.column = 0;
            }
            if (self.peek() == '\\') {
                _ = self.advance();
            }
            _ = self.advance();
        }

        if (self.isAtEnd()) {
            return Token{
                .type = .invalid,
                .lexeme = self.source[start - 1 .. self.current],
                .line = start_line,
                .column = start_column,
            };
        }

        _ = self.advance();

        return Token{
            .type = .string_literal,
            .lexeme = self.source[start - 1 .. self.current],
            .line = start_line,
            .column = start_column,
        };
    }

    fn scanNumber(self: *Lexer, start: usize, start_line: usize, start_column: usize) !Token {
        // Check what character we just consumed (before entering this function)
        // If start points to '-', we consumed '-' and current points to first digit
        // If start points to digit, we consumed that digit and current points to next char
        const first_char = self.source[start];

        // Check for hexadecimal (0x or 0X)
        if (first_char == '0' and (self.peek() == 'x' or self.peek() == 'X')) {
            // Case: 0xFF - we already consumed '0', current points to 'x'
            _ = self.advance(); // consume 'x' or 'X'

            // Scan hexadecimal digits
            while (isAsciiHexDigit(self.peek())) {
                _ = self.advance();
            }

            return Token{
                .type = .integer_literal,
                .lexeme = self.source[start..self.current],
                .line = start_line,
                .column = start_column,
            };
        } else if (first_char == '-' and self.peek() == '0' and (self.peekNext() == 'x' or self.peekNext() == 'X')) {
            // Case: -0xFF - we consumed '-', current points to '0'
            _ = self.advance(); // consume '0'
            _ = self.advance(); // consume 'x' or 'X'

            // Scan hexadecimal digits
            while (isAsciiHexDigit(self.peek())) {
                _ = self.advance();
            }

            return Token{
                .type = .integer_literal,
                .lexeme = self.source[start..self.current],
                .line = start_line,
                .column = start_column,
            };
        }

        // Decimal number
        while (isAsciiDigit(self.peek())) {
            _ = self.advance();
        }

        var is_float = false;

        if (self.peek() == '.' and isAsciiDigit(self.peekNext())) {
            is_float = true;
            _ = self.advance();

            while (isAsciiDigit(self.peek())) {
                _ = self.advance();
            }
        }

        if (self.peek() == 'e' or self.peek() == 'E') {
            is_float = true;
            _ = self.advance();

            if (self.peek() == '+' or self.peek() == '-') {
                _ = self.advance();
            }

            while (isAsciiDigit(self.peek())) {
                _ = self.advance();
            }
        }

        return Token{
            .type = if (is_float) .float_literal else .integer_literal,
            .lexeme = self.source[start..self.current],
            .line = start_line,
            .column = start_column,
        };
    }

    fn scanIdentifierOrKeyword(self: *Lexer, start: usize, start_line: usize, start_column: usize) !Token {
        // WebIDL identifiers can contain letters, digits, underscores, and hyphens
        while (isAsciiAlphanumeric(self.peek()) or self.peek() == '_' or self.peek() == '-') {
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

    fn getKeyword(text: []const u8) ?TokenType {
        const keywords = std.StaticStringMap(TokenType).initComptime(.{
            .{ "interface", .interface },
            .{ "partial", .partial },
            .{ "dictionary", .dictionary },
            .{ "enum", .@"enum" },
            .{ "callback", .callback },
            .{ "typedef", .typedef },
            .{ "const", .const_kw },
            .{ "attribute", .attribute },
            .{ "readonly", .readonly },
            .{ "inherit", .inherit },
            .{ "static", .static },
            .{ "getter", .getter },
            .{ "setter", .setter },
            .{ "deleter", .deleter },
            .{ "stringifier", .stringifier },
            .{ "constructor", .constructor },
            .{ "optional", .optional },
            .{ "required", .required },
            .{ "in", .in },
            .{ "raises", .raises },
            .{ "pragma", .pragma },
            .{ "module", .module },
            .{ "sequence", .sequence },
            .{ "record", .record },
            .{ "Promise", .promise },
            .{ "includes", .includes },
            .{ "mixin", .mixin },
            .{ "namespace", .namespace },
            .{ "iterable", .iterable },
            .{ "async", .async },
            .{ "async_iterable", .async_iterable },
            .{ "maplike", .maplike },
            .{ "setlike", .setlike },
            .{ "FrozenArray", .frozen_array },
            .{ "ObservableArray", .observable_array },

            .{ "any", .any },
            .{ "undefined", .undefined },
            .{ "boolean", .boolean },
            .{ "byte", .byte },
            .{ "octet", .octet },
            .{ "short", .short },
            .{ "unsigned", .unsigned },
            .{ "long", .long },
            .{ "float", .float },
            .{ "double", .double },
            .{ "unrestricted", .unrestricted },
            .{ "bigint", .bigint },
            .{ "DOMString", .dom_string },
            .{ "ByteString", .byte_string },
            .{ "USVString", .usv_string },
            .{ "object", .object },
            .{ "symbol", .symbol },

            .{ "or", .or_kw },
            .{ "true", .true_kw },
            .{ "false", .false_kw },
            .{ "null", .null_kw },
            .{ "Infinity", .infinity_kw },
            .{ "-Infinity", .negative_infinity_kw },
            .{ "NaN", .nan_kw },
        });

        return keywords.get(text);
    }

    fn advance(self: *Lexer) u8 {
        const c = self.source[self.current];
        self.current += 1;
        self.column += 1;
        return c;
    }

    fn peek(self: *Lexer) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.current];
    }

    fn peekNext(self: *Lexer) u8 {
        if (self.current + 1 >= self.source.len) return 0;
        return self.source[self.current + 1];
    }

    fn isAtEnd(self: *Lexer) bool {
        return self.current >= self.source.len;
    }
};

test "lexer - basic tokens" {
    const allocator = std.testing.allocator;
    const source = "interface Foo { };";

    var lexer = Lexer.init(allocator, source);

    const t1 = try lexer.nextToken();
    try std.testing.expectEqual(TokenType.interface, t1.type);

    const t2 = try lexer.nextToken();
    try std.testing.expectEqual(TokenType.identifier, t2.type);
    try std.testing.expectEqualStrings("Foo", t2.lexeme);

    const t3 = try lexer.nextToken();
    try std.testing.expectEqual(TokenType.lbrace, t3.type);

    const t4 = try lexer.nextToken();
    try std.testing.expectEqual(TokenType.rbrace, t4.type);

    const t5 = try lexer.nextToken();
    try std.testing.expectEqual(TokenType.semicolon, t5.type);

    const t6 = try lexer.nextToken();
    try std.testing.expectEqual(TokenType.eof, t6.type);
}

test "lexer - comments" {
    const allocator = std.testing.allocator;
    const source =
        \\// Single line comment
        \\/* Multi-line
        \\   comment */
        \\interface Test
    ;

    var lexer = Lexer.init(allocator, source);

    const t1 = try lexer.nextToken();
    try std.testing.expectEqual(TokenType.interface, t1.type);

    const t2 = try lexer.nextToken();
    try std.testing.expectEqual(TokenType.identifier, t2.type);
    try std.testing.expectEqualStrings("Test", t2.lexeme);
}

test "lexer - string literals" {
    const allocator = std.testing.allocator;
    const source = "\"hello world\"";

    var lexer = Lexer.init(allocator, source);

    const t1 = try lexer.nextToken();
    try std.testing.expectEqual(TokenType.string_literal, t1.type);
    try std.testing.expectEqualStrings("\"hello world\"", t1.lexeme);
}

test "lexer - numbers" {
    const allocator = std.testing.allocator;
    const source = "42 3.14 -5 1.5e10";

    var lexer = Lexer.init(allocator, source);

    const t1 = try lexer.nextToken();
    try std.testing.expectEqual(TokenType.integer_literal, t1.type);
    try std.testing.expectEqualStrings("42", t1.lexeme);

    const t2 = try lexer.nextToken();
    try std.testing.expectEqual(TokenType.float_literal, t2.type);
    try std.testing.expectEqualStrings("3.14", t2.lexeme);

    const t3 = try lexer.nextToken();
    try std.testing.expectEqual(TokenType.minus, t3.type);

    const t4 = try lexer.nextToken();
    try std.testing.expectEqual(TokenType.integer_literal, t4.type);
    try std.testing.expectEqualStrings("5", t4.lexeme);

    const t5 = try lexer.nextToken();
    try std.testing.expectEqual(TokenType.float_literal, t5.type);
    try std.testing.expectEqualStrings("1.5e10", t5.lexeme);
}
