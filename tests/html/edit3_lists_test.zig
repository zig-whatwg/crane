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
