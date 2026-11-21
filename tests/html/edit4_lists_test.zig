//! Lane edit4: insertOrderedList / insertUnorderedList.
//!
//! A36 - an empty `<div></div>` or `<p></p>` (no br) holding the caret gets a
//! list whose one item takes the typed text: the div keeps the list inside
//! it, the p is replaced (editing/run/insertorderedlist.html and
//! insertunorderedlist.html data, Firefox 160; Chrome 157 and Safari 27.2
//! differ from each other, so the spec and its data decide - golden rule 2,
//! mechanisms without a majority). Crane left the text beside the item
//! (`<ol><li></li>abc</ol>`).
//!
//! A25 - blocks with a dir attribute that become list items give the new list
//! the first one's direction: `<ol dir="rtl"><li>abc</li><li>def</li></ol>`
//! (Firefox 160; Chrome 157 keeps the first div around the list; both are in
//! the data, Safari 27.2 fails - PPF at wpt.fyi 2358bd4835).
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

const empty_block_cases = [_]harness.Case{
    .{ .input = "<div>{}</div>", .commands = &.{ .{ "insertorderedlist", "" }, .{ "inserttext", "abc" } }, .expected = "<div><ol><li>abc</li></ol></div>" },
    .{ .input = "<div>{}</div>", .commands = &.{ .{ "insertunorderedlist", "" }, .{ "inserttext", "abc" } }, .expected = "<div><ul><li>abc</li></ul></div>" },
    .{ .input = "<p>{}</p>", .commands = &.{ .{ "insertorderedlist", "" }, .{ "inserttext", "abc" } }, .expected = "<ol><li>abc</li></ol>" },
    .{ .input = "<p>{}</p>", .commands = &.{ .{ "insertunorderedlist", "" }, .{ "inserttext", "abc" } }, .expected = "<ul><li>abc</li></ul>" },
    // Unchanged: the padding-br forms (lane edit3) and the empty host.
    .{ .input = "<div>{}<br></div>", .commands = &.{ .{ "insertorderedlist", "" }, .{ "inserttext", "abc" } }, .expected = "<div><ol><li>abc</li></ol></div>" },
    .{ .input = "<p>{}<br></p>", .commands = &.{ .{ "insertorderedlist", "" }, .{ "inserttext", "abc" } }, .expected = "<ol><li>abc</li></ol>" },
    .{ .input = "{}", .commands = &.{ .{ "insertorderedlist", "" }, .{ "inserttext", "abc" } }, .expected = "<ol><li>abc</li></ol>" },
};

fn emptyBlocks() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try page.run("document.getElementById('host').focus();");
    try harness.runCases(page, &empty_block_cases);
}

test "insert*list on an empty div or p without a br puts the typed text in the new item" {
    try helpers.onFreshThread(emptyBlocks);
}

const dir_cases = [_]harness.Case{
    .{ .input = "<div dir=\"rtl\">a[]bc</div><div dir=\"rtl\">def</div>", .commands = &.{.{ "insertorderedlist", "" }}, .expected = "<ol dir=\"rtl\"><li>abc</li></ol><div dir=\"rtl\">def</div>" },
    .{ .input = "<div dir=\"rtl\">a[bc</div><div dir=\"rtl\">de]f</div>", .commands = &.{.{ "insertorderedlist", "" }}, .expected = "<ol dir=\"rtl\"><li>abc</li><li>def</li></ol>" },
    .{ .input = "<div dir=\"rtl\">a[bc</div><div dir=\"ltr\">de]f</div>", .commands = &.{.{ "insertunorderedlist", "" }}, .expected = "<ul dir=\"rtl\"><li>abc</li><li>def</li></ul>" },
    // No dir: unchanged.
    .{ .input = "<div>a[bc</div><div>de]f</div>", .commands = &.{.{ "insertorderedlist", "" }}, .expected = "<ol><li>abc</li><li>def</li></ol>" },
};

fn directions() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try page.run("document.getElementById('host').focus();");
    try harness.runCases(page, &dir_cases);
}

test "insert*list gives the new list the first converted block's dir" {
    try helpers.onFreshThread(directions);
}
