//! Values 5 §3.3 token grammar; Chrome/Firefox agree in probe 1025o/RULINGS.md.
const std = @import("std");
const css = @import("css");
const syntax = css.syntax_definitions;
const testing = std.testing;

test "pr1 token syntax permits comments only between complete tokens" {
    for ([_][]const u8{ "<number>", "</**/number/**/>", "<n\\75 mber>", "/**/<number>/**/" }) |text| {
        var stream = css.tokenizer.Tokenizer.init(text);
        var definition = try syntax.parseTokens(testing.allocator, &stream);
        defer definition.deinit();
        try testing.expectEqual(@as(usize, 1), definition.components.len);
        try testing.expectEqual(.number, definition.components[0].name.data_type);
        try testing.expectEqual(.eof, stream.next().token_type);
    }
    for ([_][]const u8{ "<number>+", "<number>/**/+" }) |text| {
        var stream = css.tokenizer.Tokenizer.init(text);
        var definition = try syntax.parseTokens(testing.allocator, &stream);
        defer definition.deinit();
        try testing.expectEqual(.space_list, definition.components[0].multiplier);
    }
    var stream = css.tokenizer.Tokenizer.init("<number>/**/|/**/auto");
    var definition = try syntax.parseTokens(testing.allocator, &stream);
    defer definition.deinit();
    try testing.expectEqual(@as(usize, 2), definition.components.len);
    try testing.expectEqualStrings("auto", definition.components[1].name.ident);
}

test "pr1 token syntax rejects split names whitespace and extra grammar transactionally" {
    for ([_][]const u8{
        "<num/**/ber>",      "au/**/to",              "< number>",  "<number >", "<number> +", "<number> /**/+",
        "<transform-list>+", "<transform-list>/**/#", "",           "<number>|", "*|auto",     "\"<number>\"",
        "inherit",           "<NUMBER>",              "<number>++", "auto#x",
    }) |text| {
        var stream = css.tokenizer.Tokenizer.init(text);
        try testing.expectError(error.InvalidSyntax, syntax.parseTokens(testing.allocator, &stream));
        try testing.expectEqual(@as(usize, 0), stream.pos);
    }
}

test "pr1 token and string fronts retain their distinct syntax rules" {
    for ([_][]const u8{ "</**/number/**/>", "<number>/**/+", "<n\\75 mber>" }) |text|
        try testing.expectError(error.InvalidSyntax, syntax.parse(testing.allocator, text));
    for ([_][]const u8{ "*", " /**/*/**/ ", "<url>", "<transform-list>", "--keyword#" }) |text| {
        var stream = css.tokenizer.Tokenizer.init(text);
        var definition = try syntax.parseTokens(testing.allocator, &stream);
        defer definition.deinit();
    }
}

fn ownedTokens(allocator: std.mem.Allocator) !void {
    const text = try allocator.dupe(u8, "--first/**/# | <n\\75 mber>+ | au\\74 o");
    var stream = css.tokenizer.Tokenizer.init(text);
    var definition = syntax.parseTokens(allocator, &stream) catch |err| {
        allocator.free(text);
        try testing.expectEqual(@as(usize, 0), stream.pos);
        return err;
    };
    allocator.free(text);
    defer definition.deinit();
    try testing.expectEqualStrings("--first", definition.components[0].name.ident);
    try testing.expectEqual(.comma_list, definition.components[0].multiplier);
    try testing.expectEqual(.number, definition.components[1].name.data_type);
    try testing.expectEqualStrings("auto", definition.components[2].name.ident);
}

test "pr1 token syntax owns decoded names and unwinds allocation failures" {
    try ownedTokens(testing.allocator);
    try testing.checkAllAllocationFailures(testing.allocator, ownedTokens, .{});
}

test "pr1 token parser respects the caller cursor on success and failure" {
    var valid = css.tokenizer.Tokenizer.init("prefix\n <number>");
    _ = valid.next();
    var definition = try syntax.parseTokens(testing.allocator, &valid);
    defer definition.deinit();
    try testing.expectEqual(.number, definition.components[0].name.data_type);
    try testing.expectEqual(valid.input.len, valid.pos);
    try testing.expectEqual(@as(usize, 2), valid.line);

    var invalid = css.tokenizer.Tokenizer.init("prefix\n < number>");
    _ = invalid.next();
    const saved = invalid;
    try testing.expectError(error.InvalidSyntax, syntax.parseTokens(testing.allocator, &invalid));
    try testing.expectEqual(saved.pos, invalid.pos);
    try testing.expectEqual(saved.line, invalid.line);
    try testing.expectEqual(saved.column, invalid.column);
}
