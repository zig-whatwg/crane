//! Tests migrated from src/dom/xpath/tokenizer.zig
//! Per WHATWG specifications

const std = @import("std");

const dom = @import("dom");
const source = @import("../../src/dom/xpath/tokenizer.zig");

test "tokenizer - single characters" {
    const test_cases = .{
        .{ "(", Token.Tag.lparen },
        .{ ")", Token.Tag.rparen },
        .{ "[", Token.Tag.lbracket },
        .{ "]", Token.Tag.rbracket },
        .{ "@", Token.Tag.at_sign },
        .{ ",", Token.Tag.comma },
        .{ "/", Token.Tag.slash },
        .{ "|", Token.Tag.pipe },
        .{ "+", Token.Tag.plus },
        .{ "-", Token.Tag.minus },
        .{ "=", Token.Tag.equals },
        .{ "<", Token.Tag.less_than },
        .{ ">", Token.Tag.greater_than },
    };

    inline for (test_cases) |tc| {
        var tokenizer = Tokenizer.init(tc[0]);
        const token = (try tokenizer.next()).?;
        try std.testing.expectEqual(tc[1], token.tag);
        try std.testing.expectEqualStrings(tc[0], token.value);
    }
}
test "tokenizer - multi-character operators" {
    const test_cases = .{
        .{ "..", Token.Tag.dot_dot },
        .{ "::", Token.Tag.double_colon },
        .{ "//", Token.Tag.slash_slash },
        .{ "!=", Token.Tag.not_equals },
        .{ "<=", Token.Tag.less_than_or_equal },
        .{ ">=", Token.Tag.greater_than_or_equal },
    };

    inline for (test_cases) |tc| {
        var tokenizer = Tokenizer.init(tc[0]);
        const token = (try tokenizer.next()).?;
        try std.testing.expectEqual(tc[1], token.tag);
        try std.testing.expectEqualStrings(tc[0], token.value);
    }
}
test "tokenizer - operator keywords" {
    const test_cases = .{
        .{ "and", Token.Tag.operator_and },
        .{ "or", Token.Tag.operator_or },
        .{ "mod", Token.Tag.operator_mod },
        .{ "div", Token.Tag.operator_div },
    };

    inline for (test_cases) |tc| {
        var tokenizer = Tokenizer.init(tc[0]);
        const token = (try tokenizer.next()).?;
        try std.testing.expectEqual(tc[1], token.tag);
        try std.testing.expectEqualStrings(tc[0], token.value);
    }
}
test "tokenizer - literals" {
    var tokenizer = Tokenizer.init("\"hello world\"");
    const tok1 = (try tokenizer.next()).?;
    try std.testing.expectEqual(Token.Tag.literal, tok1.tag);
    try std.testing.expectEqualStrings("hello world", tok1.value);

    tokenizer = Tokenizer.init("'single quotes'");
    const tok2 = (try tokenizer.next()).?;
    try std.testing.expectEqual(Token.Tag.literal, tok2.tag);
    try std.testing.expectEqualStrings("single quotes", tok2.value);
}
test "tokenizer - numbers" {
    const test_cases = .{
        "123",
        "123.45",
        ".5",
        "0.001",
    };

    inline for (test_cases) |input| {
        var tokenizer = Tokenizer.init(input);
        const token = (try tokenizer.next()).?;
        try std.testing.expectEqual(Token.Tag.number, token.tag);
        try std.testing.expectEqualStrings(input, token.value);
    }
}
test "tokenizer - variable reference" {
    var tokenizer = Tokenizer.init("$myVar");
    const token = (try tokenizer.next()).?;
    try std.testing.expectEqual(Token.Tag.variable_reference, token.tag);
    try std.testing.expectEqualStrings("$myVar", token.value);
}
test "tokenizer - axis names" {
    var tokenizer = Tokenizer.init("child::para");

    const tok1 = (try tokenizer.next()).?;
    try std.testing.expectEqual(Token.Tag.axis_child, tok1.tag);

    const tok2 = (try tokenizer.next()).?;
    try std.testing.expectEqual(Token.Tag.double_colon, tok2.tag);

    const tok3 = (try tokenizer.next()).?;
    try std.testing.expectEqual(Token.Tag.name_test, tok3.tag);
    try std.testing.expectEqualStrings("para", tok3.value);
}
test "tokenizer - node types" {
    const test_cases = .{
        .{ "text()", Token.Tag.node_type_text },
        .{ "comment()", Token.Tag.node_type_comment },
        .{ "node()", Token.Tag.node_type_node },
    };

    inline for (test_cases) |tc| {
        var tokenizer = Tokenizer.init(tc[0]);
        const token = (try tokenizer.next()).?;
        try std.testing.expectEqual(tc[1], token.tag);
    }
}
test "tokenizer - function calls" {
    var tokenizer = Tokenizer.init("position()");
    const tok1 = (try tokenizer.next()).?;
    try std.testing.expectEqual(Token.Tag.function_name, tok1.tag);
    try std.testing.expectEqualStrings("position", tok1.value);
}
test "tokenizer - asterisk disambiguation" {
    // After operator - should be name test
    var tokenizer1 = Tokenizer.init("/ *");
    _ = try tokenizer1.next(); // /
    const tok1 = (try tokenizer1.next()).?;
    try std.testing.expectEqual(Token.Tag.name_test, tok1.tag);

    // After name - should be multiply
    var tokenizer2 = Tokenizer.init("5 * 3");
    _ = try tokenizer2.next(); // 5
    const tok2 = (try tokenizer2.next()).?;
    try std.testing.expectEqual(Token.Tag.multiply, tok2.tag);
}
test "tokenizer - complex expression" {
    const input = "child::para[position()=1]";
    var tokenizer = Tokenizer.init(input);

    const expected = [_]Token.Tag{
        .axis_child,
        .double_colon,
        .name_test,
        .lbracket,
        .function_name,
        .lparen,
        .rparen,
        .equals,
        .number,
        .rbracket,
        .eof,
    };

    for (expected) |expected_tag| {
        const token = (try tokenizer.next()).?;
        try std.testing.expectEqual(expected_tag, token.tag);
    }
}