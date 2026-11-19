//! Lane edit2, group 3: Backspace and Delete (execCommand "delete" and
//! "forwardDelete") remove whole what the browsers' caret cannot enter
//! (src/html/execcommand/delete.zig):
//!
//! - a non-editable node beside the caret, inline or block;
//! - a non-editable block between two lines, which then join;
//! - an element whose contents editing ignores (object, iframe, meter,
//!   progress, video, a controls audio), instead of a character of its
//!   fallback content.
//!
//! The cases are the WPT editing data (tests/wpt/editing/data/delete.js and
//! forwarddelete.js); each passes in Chrome 157, Firefox 160 and Safari 27.2
//! (wpt.fyi aligned runs at 2358bd4835) unless its comment names the two
//! that do.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

const atom_cases = [_]harness.Case{
    .{ .input = "foo<span contenteditable=false>bar</span>[]baz", .commands = &.{.{ "delete", "" }}, .expected = "foobaz" },
    .{ .input = "foo[]<span contenteditable=false>bar</span>baz", .commands = &.{.{ "forwarddelete", "" }}, .expected = "foobaz" },
    .{ .input = "foo<div contenteditable=false>bar</div>[]baz", .commands = &.{.{ "delete", "" }}, .expected = "foobaz" },
    .{ .input = "foo<span>bar<span contenteditable=false>baz</span></span>[]qux", .commands = &.{.{ "delete", "" }}, .expected = "foo<span>bar</span>qux" },
    // Chrome and Safari: one atom per keypress.
    .{ .input = "foo<span contenteditable=false>bar</span><span contenteditable=false>baz</span>[]qux", .commands = &.{.{ "delete", "" }}, .expected = "foo<span contenteditable=\"false\">bar</span>qux" },
    .{ .input = "foo[]<span contenteditable=false>bar</span><span contenteditable=false>baz</span>qux", .commands = &.{.{ "forwarddelete", "" }}, .expected = "foo<span contenteditable=\"false\">baz</span>qux" },
    // Chrome and Firefox.
    .{ .input = "foo<img contenteditable=false src=/img/lion.svg>[]bar", .commands = &.{.{ "delete", "" }}, .expected = "foobar" },
    // A non-editable block between two lines goes, and the lines join
    // (Backspace: Chrome and Safari).
    .{ .input = "<p>abc</p><ul contenteditable=\"false\"><li>def</li></ul><p>[]ghi</p>", .commands = &.{.{ "delete", "" }}, .expected = "<p>abcghi</p>" },
    .{ .input = "<p>abc[]</p><ul contenteditable=\"false\"><li>def</li></ul><p>ghi</p>", .commands = &.{.{ "forwarddelete", "" }}, .expected = "<p>abcghi</p>" },
    .{ .input = "<p>abc[]</p><ul><li contenteditable=\"false\">def</li></ul><p>ghi</p>", .commands = &.{.{ "forwarddelete", "" }}, .expected = "<p>abcghi</p>" },
    .{ .input = "<ul><li>abc[]</li><li contenteditable=\"false\">def</li><li>ghi</li></ul>", .commands = &.{.{ "forwarddelete", "" }}, .expected = "<ul><li>abcghi</li></ul>" },
    .{ .input = "<ul><li>abc[]</li><li contenteditable=\"false\">def</li></ul><p>ghi</p>", .commands = &.{.{ "forwarddelete", "" }}, .expected = "<ul><li>abcghi</li></ul>" },
    .{ .input = "<ul><li>abc</li><li contenteditable=\"false\">def</li><li>[]ghi</li></ul>", .commands = &.{.{ "delete", "" }}, .expected = "<ul><li>abcghi</li></ul>" },
    // An inline atom ending the previous line (or starting the next) stays:
    // the lines join (Chrome 157, probed headless; no WPT row).
    .{ .input = "<p>abc<span contenteditable=false>x</span></p><p>[]ghi</p>", .commands = &.{.{ "delete", "" }}, .expected = "<p>abc<span contenteditable=\"false\">x</span>ghi</p>" },
    .{ .input = "<p>abc[]</p><p><span contenteditable=false>x</span>ghi</p>", .commands = &.{.{ "forwarddelete", "" }}, .expected = "<p>abc<span contenteditable=\"false\">x</span>ghi</p>" },
};

const ignored_content_cases = [_]harness.Case{
    .{ .input = "abc<object data=\"about:blank\">def</object>[]ghi", .commands = &.{.{ "delete", "" }}, .expected = "abcghi" },
    .{ .input = "abc<iframe>def</iframe>[]ghi", .commands = &.{.{ "delete", "" }}, .expected = "abcghi" },
    .{ .input = "abc<meter>def</meter>[]ghi", .commands = &.{.{ "delete", "" }}, .expected = "abcghi" },
    .{ .input = "abc<progress>def</progress>[]ghi", .commands = &.{.{ "delete", "" }}, .expected = "abcghi" },
    .{ .input = "abc<video>def</video>[]ghi", .commands = &.{.{ "delete", "" }}, .expected = "abcghi" },
    .{ .input = "abc[]<object data=\"about:blank\">def</object>ghi", .commands = &.{.{ "forwarddelete", "" }}, .expected = "abcghi" },
    .{ .input = "abc[]<iframe>def</iframe>ghi", .commands = &.{.{ "forwarddelete", "" }}, .expected = "abcghi" },
    .{ .input = "abc[]<meter>def</meter>ghi", .commands = &.{.{ "forwarddelete", "" }}, .expected = "abcghi" },
    // Chrome and Firefox.
    .{ .input = "abc[]<audio controls>def</audio>ghi", .commands = &.{.{ "forwarddelete", "" }}, .expected = "abcghi" },
};

fn atomCases() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try harness.runCases(page, &atom_cases);
}

test "Backspace and Delete remove a non-editable node whole, as the browsers do" {
    try helpers.onFreshThread(atomCases);
}

fn ignoredContentCases() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try harness.runCases(page, &ignored_content_cases);
}

test "Backspace and Delete remove an element whose contents editing ignores whole" {
    try helpers.onFreshThread(ignoredContentCases);
}

/// After a block join the caret is at the end of the start line's last
/// inline content: the next text goes into its span and the queries read
/// its style (delete.html, forwarddelete.html, multitest.html; all three).
const caret_cases = [_]harness.Case{
    .{ .input = "<p><span style=\"color:rgb(0, 0, 255)\">foo</span></p><p><span style=\"color:rgb(255, 0, 0)\">[]bar</span></p>", .commands = &.{ .{ "styleWithCSS", "false" }, .{ "delete", "" }, .{ "insertText", "A" } }, .expected = "<p><span style=\"color:rgb(0, 0, 255)\">fooA</span><span style=\"color:rgb(255, 0, 0)\">bar</span></p>" },
    .{ .input = "<p><span style=\"color:rgb(0, 0, 255)\">foo[]</span></p><p><span style=\"color:rgb(255, 0, 0)\">bar</span></p>", .commands = &.{ .{ "styleWithCSS", "false" }, .{ "forwarddelete", "" }, .{ "insertText", "A" } }, .expected = "<p><span style=\"color:rgb(0, 0, 255)\">fooA</span><span style=\"color:rgb(255, 0, 0)\">bar</span></p>" },
    .{ .input = "<span style=\"color:rgb(0, 0, 255)\">foo<br></span><p><span style=\"color:rgb(255, 0, 0)\">[]bar</span></p>", .commands = &.{ .{ "styleWithCSS", "false" }, .{ "delete", "" }, .{ "insertText", "A" } }, .expected = "<span style=\"color:rgb(0, 0, 255)\">fooA</span><span style=\"color:rgb(255, 0, 0)\">bar</span>" },
};

fn caretCases() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try harness.runCases(page, &caret_cases);
    // The queries read the start line's font.
    try page.run("setupHost('<p><font color=blue>foo</font><p><font color=brown>[]bar</font>'); document.execCommand('styleWithCSS', false, 'false'); document.execCommand('delete');");
    try harness.expectEval(page, "document.queryCommandValue('foreColor')", "rgb(0, 0, 255)");
    try page.run("setupHost('<p><font size=4>foo[]</font><p><font size=5>bar</font>'); document.execCommand('forwarddelete');");
    try harness.expectEval(page, "document.queryCommandValue('fontSize')", "4");
}

test "after a block join the caret ends the start line, inside its inline style" {
    try helpers.onFreshThread(caretCases);
}

/// A joining line keeps what its block gave it (delete step 34.3 records
/// the moved children's values; the CSS rows pass in Chrome and Safari, the
/// non-CSS ones are the data's spec <font>).
const values_cases = [_]harness.Case{
    .{ .input = "<p style=color:blue>foo<p style=color:brown>[]bar", .commands = &.{ .{ "stylewithcss", "true" }, .{ "delete", "" } }, .expected = "<p style=\"color:blue\">foo<span style=\"color: rgb(165, 42, 42);\">bar</span></p>" },
    .{ .input = "<p>foo<p style=color:brown>[]bar", .commands = &.{ .{ "stylewithcss", "false" }, .{ "delete", "" } }, .expected = "<p>foo<font color=\"#a52a2a\">bar</font></p>" },
    .{ .input = "<p>foo[]<p style=color:brown>bar", .commands = &.{ .{ "stylewithcss", "true" }, .{ "forwarddelete", "" } }, .expected = "<p>foo<span style=\"color: rgb(165, 42, 42);\">bar</span></p>" },
};

fn valuesCases() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try harness.runCases(page, &values_cases);
}

test "a line joining another block keeps the values its own block gave it" {
    try helpers.onFreshThread(valuesCases);
}
