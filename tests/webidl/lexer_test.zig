//! Tests migrated from src/webidl/parser/lexer.zig
//! Per WHATWG specifications

const std = @import("std");

const webidl = @import("webidl");
const source = @import("../../src/webidl/parser/lexer.zig");

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