//! Lane editing5 batch 3: insertHTML puts inline content outside the
//! styled inline elements at the insertion point (Blink
//! ReplaceSelectionCommand, Gecko InlineStylesAtInsertionPoint::Clear;
//! src/html/execcommand/insert_content.zig). Expected results are
//! editing/other/inserthtml-do-not-preserve-inline-styles.html's.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

const insert_cases = [_]harness.Case{
    // Before, after and between the styled inline elements.
    .{ .input = "<b>[]def</b>", .commands = &.{.{ "inserthtml", "<i>abc</i>" }}, .expected = "<i>abc</i><b>def</b>" },
    .{ .input = "<b>abc[]</b>", .commands = &.{.{ "inserthtml", "<i>def</i>" }}, .expected = "<b>abc</b><i>def</i>" },
    .{ .input = "<b>a[]c</b>", .commands = &.{.{ "inserthtml", "<i>b</i>" }}, .expected = "<b>a</b><i>b</i><b>c</b>" },
    .{ .input = "<i><b>a[]c</b></i>", .commands = &.{.{ "inserthtml", "<u><s>b</s></u>" }}, .expected = "<i><b>a</b></i><u><s>b</s></u><i><b>c</b></i>" },
    .{ .input = "<font color=\"#0000FF\">a[]c</font>", .commands = &.{.{ "inserthtml", "<b>b</b>" }}, .expected = "<font color=\"#0000FF\">a</font><b>b</b><font color=\"#0000FF\">c</font>" },
    // An element that is not only style keeps the insertion inside.
    .{ .input = "<span id=\"x\">a[]c</span>", .commands = &.{.{ "inserthtml", "<b>b</b>" }}, .expected = "<span id=\"x\">a<b>b</b>c</span>" },
};

fn insertOutsideStyles() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try harness.runCases(page, &insert_cases);
    // The caret ends inside the inserted content: its style is the caret's.
    try harness.expectEval(page, "runCommands('<b>a[]c</b>', [['inserthtml', '<i>b</i>']]); [document.queryCommandState('italic'), document.queryCommandState('bold')].join()", "true,false");
    try harness.expectEval(page, "runCommands('<b>[]c</b>', [['inserthtml', '<font size=5>b</font>']]); document.queryCommandValue('fontsize')", "5");
}

test "insertHTML puts inline content outside the styled inline elements at the caret" {
    try helpers.onFreshThread(insertOutsideStyles);
}
