//! Lane editing4: the formatBlock command's action, value and
//! indeterminacy (specs/w3c/execCommand.md). Expected results are
//! tests/wpt/editing/data/formatblock.js cases that Chrome 156, Firefox 158
//! and Safari 27 all pass (wpt.fyi 5af3c135c9).
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

const Case = harness.Case;

fn format(comptime value: []const u8) []const [2][]const u8 {
    return &.{ .{ "defaultparagraphseparator", "div" }, .{ "formatblock", value } };
}

const cases = [_]Case{
    .{ .input = "foo[]bar<p>extra", .commands = format("<p>"), .expected = "<p>foobar</p><p>extra</p>" },
    .{ .input = "foo[]bar<p>extra", .commands = format("<div>"), .expected = "<div>foobar</div><p>extra</p>" },
    .{ .input = "<p>[foobar]</p>", .commands = format("<h2>"), .expected = "<h2>foobar</h2>" },
    .{ .input = "<h3>[foobar]</h3>", .commands = format("<div>"), .expected = "<div>foobar</div>" },
    .{ .input = "<pre>[foobar]</pre>", .commands = format("<div>"), .expected = "<div>foobar</div>" },
    .{ .input = "<p>[foobar]</p>", .commands = format("<address>"), .expected = "<address>foobar</address>" },
    // The browsers' extra names (Blink IsElementForFormatBlock, Gecko
    // IsFormatTagForFormatBlockCommand).
    .{ .input = "<p>[foobar]</p>", .commands = &.{.{ "formatblock", "<nav>" }}, .expected = "<nav>foobar</nav>" },
    .{ .input = "<p>[foobar]</p>", .commands = &.{.{ "formatblock", "<aside>" }}, .expected = "<aside>foobar</aside>" },
    .{ .input = "<section>[foo]</section>", .commands = &.{.{ "formatblock", "<blockquote>" }}, .expected = "<blockquote>foo</blockquote>" },
    // Not a block to format with: nothing changes.
    .{ .input = "<p>[foobar]</p>", .commands = &.{.{ "formatblock", "<ol>" }}, .expected = "<p>foobar</p>" },
};

fn actions() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try harness.runCases(page, &cases);
    // The return value: false for a name that is not a formattable block.
    try harness.expectEval(page, "setupHost('<p>[foo]</p>'); document.execCommand('formatblock', false, '<li>')", "false");
    try harness.expectEval(page, "setupHost('<p>[foo]</p>'); document.execCommand('formatblock', false, 'h1')", "true");
}

test "formatBlock: the editing spec's action, with the browsers' block names" {
    try helpers.onFreshThread(actions);
}

fn queries() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    // The value is the formattable block around the selection's first leaf.
    try harness.expectEval(page, "setupHost('<p>foo[]bar</p>'); document.queryCommandValue('formatblock')", "p");
    try harness.expectEval(page, "setupHost('<h1>foo[]bar</h1>'); document.queryCommandValue('formatblock')", "h1");
    try harness.expectEval(page, "setupHost('foo[]bar'); document.queryCommandValue('formatblock')", "");
    try harness.expectEval(page, "setupHost('<blockquote>[foo]</blockquote>'); document.queryCommandValue('formatblock')", "blockquote");
    // A div holding a p is not the block of the line.
    try harness.expectEval(page, "setupHost('<div><p>[foo]</p></div>'); document.queryCommandValue('formatblock')", "p");
    // Indeterminate across blocks of different names, not across one name.
    try harness.expectEval(page, "setupHost('<p>[foo</p><h1>bar]</h1>'); document.queryCommandIndeterm('formatblock')", "true");
    try harness.expectEval(page, "setupHost('<p>[foo</p><p>bar]</p>'); document.queryCommandIndeterm('formatblock')", "false");
    // No state.
    try harness.expectEval(page, "setupHost('<p>[foo]</p>'); document.queryCommandState('formatblock')", "false");
}

test "formatBlock: value and indeterminacy" {
    try helpers.onFreshThread(queries);
}
