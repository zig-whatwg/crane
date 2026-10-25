//! Properties and Values API §5: syntax strings are code points, not CSS tokens.
const std = @import("std");
const syntax = @import("css").syntax_definitions;
const testing = std.testing;

test "pr1 universal syntax is the only component and trims Infra whitespace" {
    for ([_][]const u8{ "*", " * ", "\t\n\r\x0c*\r\n" }) |text| {
        var definition = try syntax.parse(testing.allocator, text);
        defer definition.deinit();
        try testing.expect(definition.universal);
        try testing.expectEqual(@as(usize, 0), definition.components.len);
    }
}

test "pr1 every supported data type includes string and transform-list" {
    const cases = .{
        .{ "<length>", .length },
        .{ "<number>", .number },
        .{ "<percentage>", .percentage },
        .{ "<length-percentage>", .length_percentage },
        .{ "<string>", .string },
        .{ "<color>", .color },
        .{ "<image>", .image },
        .{ "<url>", .url },
        .{ "<integer>", .integer },
        .{ "<angle>", .angle },
        .{ "<time>", .time },
        .{ "<resolution>", .resolution },
        .{ "<transform-function>", .transform_function },
        .{ "<custom-ident>", .custom_ident },
        .{ "<transform-list>", .transform_list },
    };
    inline for (cases) |case| {
        var definition = try syntax.parse(testing.allocator, case[0]);
        defer definition.deinit();
        try testing.expect(!definition.universal);
        try testing.expectEqual(@as(usize, 1), definition.components.len);
        try testing.expectEqual(@as(syntax.DataType, case[1]), definition.components[0].name.data_type);
        try testing.expectEqual(.single, definition.components[0].multiplier);
    }
}

test "pr1 alternatives retain source order case and list multipliers" {
    var definition = try syntax.parse(testing.allocator, " red | <color># | Red+ | <length>+ ");
    defer definition.deinit();
    try testing.expectEqual(@as(usize, 4), definition.components.len);
    try testing.expectEqualStrings("red", definition.components[0].name.ident);
    try testing.expectEqual(.single, definition.components[0].multiplier);
    try testing.expectEqual(.color, definition.components[1].name.data_type);
    try testing.expectEqual(.comma_list, definition.components[1].multiplier);
    try testing.expectEqualStrings("Red", definition.components[2].name.ident);
    try testing.expectEqual(.space_list, definition.components[2].multiplier);
    try testing.expectEqual(.length, definition.components[3].name.data_type);
    try testing.expectEqual(.space_list, definition.components[3].multiplier);
}

test "pr1 literal identifiers include dashed names and decoded escapes" {
    const cases = [_][2][]const u8{
        .{ "--foo", "--foo" },
        .{ "-foo", "-foo" },
        .{ "--", "--" },
        .{ "banan\\61", "banana" },
        .{ "\\1F914 hmm", "🤔hmm" },
        .{ "\\31 abc", "1abc" },
        .{ "\\+", "+" },
        .{ "\\0", "�" },
        .{ "\\D800", "�" },
        .{ "\\110000", "�" },
        .{ "\x00", "�" },
        .{ "\\", "�" },
    };
    for (cases) |case| {
        var definition = try syntax.parse(testing.allocator, case[0]);
        defer definition.deinit();
        try testing.expectEqual(@as(usize, 1), definition.components.len);
        try testing.expectEqualStrings(case[1], definition.components[0].name.ident);
    }
}

test "pr1 malformed syntax rejects every WPT syntax grammar error" {
    const invalid = [_][]const u8{
        "",                " ",            "\x0b*",      "*\x0b",          "*+",         "*#",                "*|banana",          "<length> | *",
        "|banana",         "|",            "||",         "foo|",           "foo||bar",   "foo bar",           "banana,nya",        "<\\6c ength>",
        "<banana>",        "<Number>",     "<LENGTH>",   "<length",        "<>",         "< length>",         "<length >",         "<length> +",
        "<length> #",      "<length>++",   "<length>##", "<length>+#",     "<length>#+", "<transform-list>+", "<transform-list>#", "<length> <number>",
        "foo § bar",
        "foo \\1F914 bar", "-",            "-1",         "1foo",           "foo()",      "[foo]",             "foo?",              "foo*",
        "foo{1,2}",        "foo || bar",   "foo && bar", "/*comment*/foo", "foo/**/",    "foo/**/|bar",       "<length/**/>",      "foo\\\nbar",
        "foo\\\rbar",      "foo\\\x0cbar", "\x0bfoo",    "foo\x0b",
    };
    for (invalid) |text| try testing.expectError(error.InvalidSyntax, syntax.parse(testing.allocator, text));
}

test "pr1 CSS-wide and default identifiers reject all case and escape forms" {
    for ([_][]const u8{
        "initial",          "inherit",     "unset",    "revert",   "revert-layer", "revert-rule", "default",
        "INITIAL",          "INHERIT",     "unSEt",    "reVERt",   "deFAUlt",      "\\69 nherit", "inher\\69t",
        "<length>|initial", "foo|INHERIT", "default+", "initial#",
    }) |text| try testing.expectError(error.InvalidSyntax, syntax.parse(testing.allocator, text));
}

fn ownedDefinition(allocator: std.mem.Allocator) !void {
    const input = try allocator.dupe(u8, "--foo | banan\\61# | <length>+ | <string> | <transform-list>");
    var definition = syntax.parse(allocator, input) catch |err| {
        allocator.free(input);
        return err;
    };
    allocator.free(input);
    defer definition.deinit();
    try testing.expectEqualStrings("--foo", definition.components[0].name.ident);
    try testing.expectEqualStrings("banana", definition.components[1].name.ident);
    try testing.expectEqual(@as(usize, 5), definition.components.len);
}

test "pr1 syntax owns its identifiers and unwinds every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, ownedDefinition, .{});
}

fn invalidDefinition(allocator: std.mem.Allocator) !void {
    try testing.expectError(error.InvalidSyntax, syntax.parse(allocator, "foo | bar# | <number> | default"));
}

test "pr1 partially parsed invalid syntax releases all identifiers" {
    // Error-path allocation failures propagate rather than masquerading as grammar errors.
    const Wrapper = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var result = syntax.parse(allocator, "foo | bar# | <number> | default") catch |err| {
                if (err == error.InvalidSyntax) return;
                return err;
            };
            defer result.deinit();
            return error.TestExpectedError;
        }
    };
    try invalidDefinition(testing.allocator);
    try testing.checkAllAllocationFailures(testing.allocator, Wrapper.run, .{});
}
