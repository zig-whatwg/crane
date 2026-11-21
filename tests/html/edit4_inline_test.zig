//! Lane edit4: the inline formatting commands.
//!
//! A32 - subscript and superscript take vertical-align out of the style
//! attributes of the inline elements holding the selection, unwrapping a
//! span left with no attributes, then make their <sub>/<sup>
//! (editing/run/subscript.html and superscript.html outside CSS mode: PPP,
//! and PPF where only part of the span is selected; wpt.fyi 2358bd4835;
//! Blink ApplyStyleCommand pushes the conflicting vertical-align off the
//! node). Expected values are the data files' (tests/wpt/editing/data).
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

const no_css = [2][]const u8{ "stylewithcss", "false" };

const vertical_align_cases = [_]harness.Case{
    // PPP.
    .{ .input = "foo<span style=vertical-align:super>[bar]</span>baz", .commands = &.{ no_css, .{ "subscript", "" } }, .expected = "foo<sub>bar</sub>baz" },
    .{ .input = "foo<span style=vertical-align:top>[bar]</span>baz", .commands = &.{ no_css, .{ "subscript", "" } }, .expected = "foo<sub>bar</sub>baz" },
    .{ .input = "foo<span style=vertical-align:sub>[bar]</span>baz", .commands = &.{ no_css, .{ "superscript", "" } }, .expected = "foo<sup>bar</sup>baz" },
    .{ .input = "foo<span style=vertical-align:bottom>[bar]</span>baz", .commands = &.{ no_css, .{ "superscript", "" } }, .expected = "foo<sup>bar</sup>baz" },
    // PPF (Chrome and Firefox): part of the span; the new <sub> joins the
    // one before it.
    .{ .input = "<sub>fo[o</sub><span style=vertical-align:top>b]ar</span>", .commands = &.{ no_css, .{ "subscript", "" } }, .expected = "<sub>foob</sub><span style=\"vertical-align:top\">ar</span>" },
    .{ .input = "<sup>fo[o</sup><span style=vertical-align:bottom>b]ar</span>", .commands = &.{ no_css, .{ "superscript", "" } }, .expected = "<sup>foob</sup><span style=\"vertical-align:bottom\">ar</span>" },
    // Unchanged: plain text, and a <sub> already there toggles off.
    .{ .input = "foo[bar]baz", .commands = &.{ no_css, .{ "subscript", "" } }, .expected = "foo<sub>bar</sub>baz" },
    .{ .input = "foo<sub>[bar]</sub>baz", .commands = &.{ no_css, .{ "subscript", "" } }, .expected = "foobarbaz" },
};

fn verticalAlign() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try page.run("document.getElementById('host').focus();");
    try harness.runCases(page, &vertical_align_cases);
}

test "subscript and superscript take vertical-align off the spans they cover" {
    try helpers.onFreshThread(verticalAlign);
}
