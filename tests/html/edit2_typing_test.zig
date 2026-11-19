//! Lane edit2, group 5: the typing style a deletion leaves, as Chrome 157
//! makes it (src/html/execcommand/delete.zig steps 18-19 and 41,
//! overrides.restoreTypingStyle): the style of the deleted text's first
//! character, minus what is still in effect at the caret's downstream
//! point. The cases are editing/run/inserttext.html and multitest.html rows
//! (PPP unless the comment says otherwise, wpt.fyi 2358bd4835).
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

const typing_cases = [_]harness.Case{
    // Every character of the inline content deleted: the next text takes
    // its style.
    .{ .input = "<div>abc[<b><i>def]</i></b>ghi</div>", .commands = &.{ .{ "inserttext", "d" }, .{ "inserttext", "e" }, .{ "inserttext", "f" } }, .expected = "<div>abc<b><i>def</i></b>ghi</div>" },
    .{ .input = "<div>abc{<b><i>def</i></b>}ghi</div>", .commands = &.{ .{ "inserttext", "d" }, .{ "inserttext", "e" }, .{ "inserttext", "f" } }, .expected = "<div>abc<b><i>def</i></b>ghi</div>" },
    .{ .input = "<div>abc[<b><i>def]</i></b>ghi</div>", .commands = &.{ .{ "delete", "" }, .{ "inserttext", "d" }, .{ "inserttext", "e" }, .{ "inserttext", "f" } }, .expected = "<div>abc<b><i>def</i></b>ghi</div>" },
    .{ .input = "<div>abc[<b><i>def</i></b>g]hi</div>", .commands = &.{ .{ "forwarddelete", "" }, .{ "inserttext", "d" }, .{ "inserttext", "e" }, .{ "inserttext", "f" }, .{ "inserttext", "g" } }, .expected = "<div>abc<b><i>defg</i></b>hi</div>" },
    // Part of it deleted: the rest keeps the style where it is (Chrome and
    // Safari).
    .{ .input = "<div>abc[<b><i>de]f</i></b>ghi</div>", .commands = &.{ .{ "delete", "" }, .{ "inserttext", "d" }, .{ "inserttext", "e" } }, .expected = "<div>abcde<b><i>f</i></b>ghi</div>" },
    // An img first in the deleted content: no style (Chrome and Firefox).
    .{ .input = "<div>abc[<b><i><img src=\"/img/lion.svg\">def]</i></b>ghi</div>", .commands = &.{ .{ "inserttext", "d" }, .{ "inserttext", "e" }, .{ "inserttext", "f" } }, .expected = "<div>abcdefghi</div>" },
};

/// The overrides come back fonts first: one <font> outermost, a background
/// span and the b inside it (multitest.html; all three).
const order_cases = [_]harness.Case{
    .{ .input = "a[]c", .commands = &.{ .{ "styleWithCSS", "false" }, .{ "foreColor", "#ff0000" }, .{ "bold", "" }, .{ "insertText", "b" } }, .expected = "a<font color=\"#ff0000\"><b>b</b></font>c" },
    .{ .input = "a[]c", .commands = &.{ .{ "styleWithCSS", "false" }, .{ "bold", "" }, .{ "fontSize", "5" }, .{ "insertText", "b" } }, .expected = "a<font size=\"5\"><b>b</b></font>c" },
    .{ .input = "abc[]ef", .commands = &.{ .{ "styleWithCSS", "false" }, .{ "fontName", "monospace" }, .{ "foreColor", "#ff0000" }, .{ "fontSize", "7" }, .{ "backColor", "#00dddd" }, .{ "insertText", "d" } }, .expected = "abc<font face=\"monospace\" size=\"7\" color=\"#ff0000\"><span style=\"background-color: rgb(0, 221, 221);\">d</span></font>ef" },
};

/// Typed text fills an empty line's padding br and replaces an extraneous
/// one before the caret (inserttext.html; all three).
const br_cases = [_]harness.Case{
    .{ .input = "abc<br>{}<br>", .commands = &.{.{ "inserttext", "d" }}, .expected = "abc<br>d" },
    .{ .input = "<span contenteditable=false>abc</span><br>{}", .commands = &.{.{ "inserttext", "d" }}, .expected = "<span contenteditable=\"false\">abc</span>d" },
    .{ .input = "<p>{}<br>", .commands = &.{.{ "inserttext", "a" }}, .expected = "<p>a</p>" },
    .{ .input = "<br>{}", .commands = &.{.{ "inserttext", "a" }}, .expected = "a" },
    // A br before inline content after the caret stays (Firefox; the data).
    .{ .input = "<p style=\"white-space:pre-wrap\">a<br>{}<span style=\"padding:1px\"></span></p>", .commands = &.{.{ "inserttext", "b" }}, .expected = "<p style=\"white-space:pre-wrap\">a<br>b<span style=\"padding:1px\"></span></p>" },
};

/// insertText on a selection types into the text that follows the
/// deletion, and never into an emptied link (inserttext.html; PPP).
const insertion_cases = [_]harness.Case{
    .{ .input = "<div>abc[<b><i>de]f</i></b>ghi</div>", .commands = &.{ .{ "inserttext", "d" }, .{ "inserttext", "e" } }, .expected = "<div>abc<b><i>def</i></b>ghi</div>" },
    .{ .input = "<div>abc{<b><i>de]f</i></b>ghi</div>", .commands = &.{ .{ "inserttext", "d" }, .{ "inserttext", "e" } }, .expected = "<div>abc<b><i>def</i></b>ghi</div>" },
    .{ .input = "foo<a href=http://www.google.com>[bar</a>baz]", .commands = &.{.{ "inserttext", "a" }}, .expected = "fooa" },
    // A selection inside the link types into it (PPP).
    .{ .input = "foo<a href=http://www.google.com>[bar]</a>baz", .commands = &.{.{ "inserttext", "a" }}, .expected = "foo<a href=\"http://www.google.com\">a</a>baz" },
};

fn typingCases() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try harness.runCases(page, &typing_cases);
    try harness.runCases(page, &order_cases);
    try harness.runCases(page, &br_cases);
    try harness.runCases(page, &insertion_cases);
}

test "a deletion leaves the deleted text's style for typing, as Chrome does" {
    try helpers.onFreshThread(typingCases);
}
