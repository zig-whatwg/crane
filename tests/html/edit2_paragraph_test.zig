//! Lane edit2, group 4: insertParagraph splits a flex or grid item, not
//! its container, as Chrome 157 and Safari 27.2 do (src/html/execcommand/
//! paragraph.zig, steps 8-9; editing/run/insertparagraph.html, PFP at
//! wpt.fyi 2358bd4835, Firefox 160 splits the container). The paragraph
//! change landed in 83befc45b84 with the delete caret change; this pins it.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

const flex_cases = [_]harness.Case{
    .{ .input = "<div style=display:flex><span>a[]bc</span></div>", .commands = &.{.{ "insertparagraph", "" }}, .expected = "<div style=\"display:flex\"><span>a</span><span>bc</span></div>" },
    .{ .input = "<div style=display:flex><span>[]abc</span></div>", .commands = &.{.{ "insertparagraph", "" }}, .expected = "<div style=\"display:flex\"><span><br></span><span>abc</span></div>" },
    .{ .input = "<div style=display:grid><span>abc[]</span></div>", .commands = &.{.{ "insertparagraph", "" }}, .expected = "<div style=\"display:grid\"><span>abc</span><span><br></span></div>" },
    .{ .input = "<div style=display:inline-flex><span>a[]bc</span></div>", .commands = &.{.{ "insertparagraph", "" }}, .expected = "<div style=\"display:inline-flex\"><span>a</span><span>bc</span></div>" },
    // A block that is the item splits as before.
    .{ .input = "<div style=display:flex><div>a[]bc</div></div>", .commands = &.{.{ "insertparagraph", "" }}, .expected = "<div style=\"display:flex\"><div>a</div><div>bc</div></div>" },
};

fn flexCases() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try harness.runCases(page, &flex_cases);
}

test "insertParagraph splits a flex or grid item, as Chrome and Safari do" {
    try helpers.onFreshThread(flexCases);
}

/// insertParagraph wrapping a line of inline content keeps the line break
/// that ended the line before it (Chrome and Safari).
const line_cases = [_]harness.Case{
    .{ .input = "foo<br>bar[]<br><span>baz</span>", .commands = &.{ .{ "defaultparagraphseparator", "div" }, .{ "insertparagraph", "" } }, .expected = "foo<br><div>bar</div><div><br><span>baz</span></div>" },
    .{ .input = "foo<br>[]bar<span>baz</span><br>qux", .commands = &.{ .{ "defaultparagraphseparator", "p" }, .{ "insertparagraph", "" } }, .expected = "foo<br><p><br></p><p>bar<span>baz</span><br>qux</p>" },
};

fn lineCases() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try harness.runCases(page, &line_cases);
}

test "insertParagraph keeps the line break before the line it wraps, as Chrome and Safari do" {
    try helpers.onFreshThread(lineCases);
}

/// indent in CSS mode makes Chrome's start-side blockquote (indent.html;
/// the data accepts it and Firefox's margin-left; all three pass).
const indent_cases = [_]harness.Case{
    .{ .input = "<p>[abc]</p>", .commands = &.{ .{ "stylewithcss", "true" }, .{ "indent", "" } }, .expected = "<blockquote style=\"margin: 0 0 0 40px; border: none; padding: 0px;\"><p>abc</p></blockquote>" },
    .{ .input = "<p>[abc]</p>", .commands = &.{ .{ "stylewithcss", "false" }, .{ "indent", "" } }, .expected = "<blockquote><p>abc</p></blockquote>" },
};

fn indentCases() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try harness.runCases(page, &indent_cases);
}

test "indent in CSS mode makes a start-side blockquote" {
    try helpers.onFreshThread(indentCases);
}
