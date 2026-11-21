//! Lane edit4: the inline formatting commands.
//!
//! A32 - subscript and superscript take vertical-align out of the style
//! attributes of the inline elements holding the selection, unwrapping a
//! span left with no attributes, then make their <sub>/<sup>
//! (editing/run/subscript.html and superscript.html outside CSS mode: PPP,
//! and PPF where only part of the span is selected; wpt.fyi 2358bd4835;
//! Blink ApplyStyleCommand pushes the conflicting vertical-align off the
//! node). Expected values are the data files' (tests/wpt/editing/data).
//!
//! A22 - hiliteColor on an author's <font> that wraps exactly the run puts
//! the background on that font (all three; editing/run/hilitecolor.html PPP),
//! while the typing style's own <font> keeps a background span inside it
//! (editing/run/multitest.html PPP).
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

const normalize = "hostHTML().replace(/: /g, ':').replace(/;\"/g, '\"')";

fn fontWrapper() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try page.run("document.getElementById('host').focus();");
    // The author's font takes the background, in and out of CSS mode.
    try harness.expectEval(page, "runCommands('<font size=6>[foo]</font>', [['stylewithcss','true'],['hilitecolor','#00FFFF']]); " ++ normalize, "<font size=\"6\" style=\"background-color:rgb(0, 255, 255)\">foo</font>");
    try harness.expectEval(page, "runCommands('<font size=6>[foo]</font>', [['stylewithcss','false'],['hilitecolor','#00FFFF']]); " ++ normalize, "<font size=\"6\" style=\"background-color:rgb(0, 255, 255)\">foo</font>");
    // Typed text: the typing style's font keeps a background span inside
    // it (multitest.html ?9001-last, its first accepted form).
    try harness.expectEval(page, "runCommands('abc[]ef', [['stylewithcss','false'],['fontSize','4'],['backColor','#00dddd'],['insertText','d']]); " ++ normalize, "abc<font size=\"4\"><span style=\"background-color:rgb(0, 221, 221)\">d</span></font>ef");
}

test "hiliteColor on an author's font wrapping the run styles that font" {
    try helpers.onFreshThread(fontWrapper);
}
