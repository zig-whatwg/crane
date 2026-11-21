//! Lane edit4: the block formatting commands.
//!
//! A21 - formatBlock joins a line to a block it made for the line before,
//! never to a block that was already there: `[foo]<blockquote>bar
//! </blockquote>` + "blockquote" keeps two blockquotes (Chrome 157, Firefox
//! 160 and Safari 27.2; editing/run/formatblock.html PPP at wpt.fyi
//! 2358bd4835), where the spec's sibling criteria merge them.
//!
//! A27 - insertHTML after an empty line's placeholder br replaces it:
//! `<p><br>{}</p>` + "abc" gives `<p>abc</p>` (Chrome 157 and Firefox 160;
//! editing/run/inserthtml.html PPF). Only a sole line break goes:
//! `<p><span><!--foo--><br><!--bar--></span>{}</p>` + "<!--abc-->" keeps the
//! span and its br (Firefox 160; Crane at generation 235).
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

const sibling_cases = [_]harness.Case{
    .{ .input = "[foo]<blockquote>bar</blockquote><p>extra", .commands = &.{.{ "formatblock", "<blockquote>" }}, .expected = "<blockquote>foo</blockquote><blockquote>bar</blockquote><p>extra</p>" },
    // Lines the command wraps together still share one block (the data's
    // first form; Crane's before).
    .{ .input = "<p>[foo<p>bar]", .commands = &.{.{ "formatblock", "<blockquote>" }}, .expected = "<blockquote>foo<br>bar</blockquote>" },
};

fn siblings() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try page.run("document.getElementById('host').focus();");
    try harness.runCases(page, &sibling_cases);
}

test "formatBlock does not merge into a block that was already there" {
    try helpers.onFreshThread(siblings);
}

const placeholder_cases = [_]harness.Case{
    .{ .input = "<p><br>{}</p>", .commands = &.{.{ "inserthtml", "abc" }}, .expected = "<p>abc</p>" },
    .{ .input = "<p>{}<br></p>", .commands = &.{.{ "inserthtml", "abc" }}, .expected = "<p>abc</p>" },
    // Only the line break itself: an inline element holding it stays
    // before the caret (Crane before A27 and Firefox 160 pass this row;
    // the full A/B against generation 235 lost it).
    .{ .input = "<p><span><!--foo--><br><!--bar--></span>{}</p>", .commands = &.{.{ "inserthtml", "<!--abc-->" }}, .expected = "<p><span><!--foo--><br><!--bar--></span><!--abc--></p>" },
};

fn placeholder() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try page.run("document.getElementById('host').focus();");
    try harness.runCases(page, &placeholder_cases);
}

test "insertHTML after an empty line's placeholder br replaces it" {
    try helpers.onFreshThread(placeholder);
}
