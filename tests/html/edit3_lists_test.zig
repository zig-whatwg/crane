//! Lane edit3: toggling a list on an empty line makes a list with one empty
//! item in the line's container (src/html/execcommand/lists.zig
//! emptyLineContainer): editing/run/insertorderedlist.html and
//! insertunorderedlist.html rows Chrome 157, Firefox 160 and Safari 27.2 all
//! pass (wpt.fyi 2358bd4835).
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

fn emptyLines() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    const Case = harness.Case;
    try harness.runCases(page, &[_]Case{
        .{ .input = "{}", .commands = &.{ .{ "insertorderedlist", "" }, .{ "inserttext", "abc" } }, .expected = "<ol><li>abc</li></ol>" },
        .{ .input = "{}", .commands = &.{ .{ "insertunorderedlist", "" }, .{ "inserttext", "abc" } }, .expected = "<ul><li>abc</li></ul>" },
        .{ .input = "<div>{}<br></div>", .commands = &.{ .{ "insertorderedlist", "" }, .{ "inserttext", "abc" } }, .expected = "<div><ol><li>abc</li></ol></div>" },
        .{ .input = "<div>{}<br></div>", .commands = &.{ .{ "insertunorderedlist", "" }, .{ "inserttext", "abc" } }, .expected = "<div><ul><li>abc</li></ul></div>" },
        // A p keeps the spec's replacement (Firefox and the data).
        .{ .input = "<p>{}<br></p>", .commands = &.{ .{ "insertorderedlist", "" }, .{ "inserttext", "abc" } }, .expected = "<ol><li>abc</li></ol>" },
    });
}

test "a list toggled on an empty line goes into the line's container" {
    try helpers.onFreshThread(emptyLines);
}

/// The list a caret's queries answer: the list of the list item that holds
/// it, though a wrapper block's edges meet the list's (the spec's block-
/// extension would take the div in and answer "mixed"). Chrome 157, Firefox
/// 160 and Safari 27.2 answer queryCommandState true and
/// queryCommandIndeterm false (editing/run/insertorderedlist.html,
/// `<div>{}<br></div>` + insertorderedlist + inserttext, wpt.fyi 2358bd4835).
fn caretListState() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    const cases = [_]struct { command: []const u8, expected: []const u8 }{
        .{ .command = "insertorderedlist", .expected = "[true,false,\"<div><ol><li>abc</li></ol></div>\"]" },
        .{ .command = "insertunorderedlist", .expected = "[true,false,\"<div><ul><li>abc</li></ul></div>\"]" },
    };
    for (cases) |case| {
        const source = try std.fmt.allocPrint(std.testing.allocator, "runCommands('<div>{{}}<br></div>', [['{s}',''],['inserttext','abc']]); JSON.stringify([document.queryCommandState('{s}'), document.queryCommandIndeterm('{s}'), hostHTML()])", .{ case.command, case.command, case.command });
        defer std.testing.allocator.free(source);
        const actual = try page.evaluate(source);
        defer std.testing.allocator.free(actual);
        try std.testing.expectEqualStrings(case.expected, actual);
    }
}

test "a caret's list queries answer the list of the item that holds it" {
    try helpers.onFreshThread(caretListState);
}
