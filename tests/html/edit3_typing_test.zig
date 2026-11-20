//! Lane edit3: typed text and the line break that held its empty line open
//! (src/html/execcommand/insert_text.zig paddingLineBreakAt): once the text
//! is in, a br or preserved line feed that only kept the caret's empty line
//! at its block's end goes - Blink's InsertTextCommand placeholder removal.
//! Rows of editing/plaintext-only/insertText.html, editing/run/
//! inserttext.html and editing/other/inserttext-before-unnecessary-
//! linebreak.html that Chrome 157, Firefox 160 and Safari 27.2 all pass
//! (wpt.fyi 2358bd4835).
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

const Row = struct { white_space: []const u8, markup: []const u8, commands: []const u8, expected: []const u8 };

const rows = [_]Row{
    // A preserved line feed alone in its block.
    .{ .white_space = "pre", .markup = "[]\\n", .commands = "[['inserttext','a']]", .expected = "a" },
    .{ .white_space = "pre-line", .markup = "[]\\n", .commands = "[['inserttext','a']]", .expected = "a" },
    .{ .white_space = "pre-wrap", .markup = "<p>{}\\n</p>", .commands = "[['inserttext','x']]", .expected = "<p>x</p>" },
    // One after another line: it made the empty last line.
    .{ .white_space = "pre-wrap", .markup = "<p>abc\\n[]\\n</p>", .commands = "[['inserttext','x']]", .expected = "<p>abc\\nx</p>" },
    // The empty line insertLineBreak made in a pre block: its padding goes.
    .{ .white_space = "pre", .markup = "<p><b>AB[]</b></p>", .commands = "[['insertlinebreak',''],['inserttext','a']]", .expected = "<p><b>AB\\na</b></p>" },
    // A line break after text on the caret's line stays.
    .{ .white_space = "pre-wrap", .markup = "<p>abc[]\\n</p>", .commands = "[['inserttext','x']]", .expected = "<p>abcx\\n</p>" },
    .{ .white_space = "normal", .markup = "<p>abc[]<br></p>", .commands = "[['inserttext','x']]", .expected = "<p>abcx<br></p>" },
    .{ .white_space = "normal", .markup = "<p>{}<br></p>", .commands = "[['inserttext','x']]", .expected = "<p>x</p>" },
};

fn paddingCases() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    var failures: usize = 0;
    for (rows) |row| {
        const source = try std.fmt.allocPrint(std.testing.allocator, "host.style.whiteSpace = '{s}'; runCommands('{s}', {s}); JSON.stringify(hostHTML())", .{ row.white_space, row.markup, row.commands });
        defer std.testing.allocator.free(source);
        const actual = try page.evaluate(source);
        defer std.testing.allocator.free(actual);
        const expected = try std.fmt.allocPrint(std.testing.allocator, "\"{s}\"", .{row.expected});
        defer std.testing.allocator.free(expected);
        if (!std.mem.eql(u8, actual, expected)) {
            std.debug.print("{s} {s} {s}: expected {s}, got {s}\n", .{ row.white_space, row.markup, row.commands, expected, actual });
            failures += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

test "typed text removes the line break that only held its empty line open" {
    try helpers.onFreshThread(paddingCases);
}

fn insertionPastEmptyInline() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    // editing/run/inserttext.html: typed over `abc[<s></s><b><i>de]f</i></b>
    // ghi`, the text goes into the i, past the empty s (all three; the data
    // accepts the s kept or gone).
    for ([_][]const u8{ "abc[<s></s><b><i>de]f</i></b>ghi", "abc{<s></s><b><i>de]f</i></b>ghi" }) |markup| {
        const source = try std.fmt.allocPrint(std.testing.allocator, "runCommands('{s}', [['inserttext','d'],['inserttext','e']]); const h = hostHTML(); String(h === 'abc<b><i>def</i></b>ghi' || h === 'abc<s></s><b><i>def</i></b>ghi') + ' ' + h", .{markup});
        defer std.testing.allocator.free(source);
        const actual = try page.evaluate(source);
        defer std.testing.allocator.free(actual);
        if (!std.mem.startsWith(u8, actual, "true")) {
            std.debug.print("{s}: got {s}\n", .{ markup, actual });
            return error.TestUnexpectedResult;
        }
    }
}

test "typed text goes past an empty inline element the deletion left" {
    try helpers.onFreshThread(insertionPastEmptyInline);
}
