//! Lane editing5 batch 3: a block merge moves a line out of a span, as
//! Chrome and Safari do (Blink MoveParagraphs; src/html/execcommand/
//! delete.zig rewrapMovedLine). Expected results are editing/other/
//! merge-span-with-style-* and delete-at-end-boundary-of-div-followed-by-
//! inline-element-containing-hidden-select-element-with-non-editable-
//! node.html's.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

const move_cases = [_]harness.Case{
    // The span holding the moved line is not moved: its style comes along
    // on a fresh span; its id stays behind with it.
    .{ .input = "<h1><span style=\"background-color:red;\">Back</span></h1><h1><span style=\"background-color: red;\" id=\"space\">[]space</span></h1>", .commands = &.{.{ "delete", "" }}, .expected = "<h1><span style=\"background-color:red;\">Back</span><span style=\"background-color: red;\">space</span></h1>" },
    // A span with no style adds nothing; hidden content at its end stays.
    .{ .input = "<div id=\"first\">First block[]</div><span id=\"second\">Second block<select style=\"visibility:hidden\"></select></span>", .commands = &.{.{ "forwarddelete", "" }}, .expected = "<div id=\"first\">First blockSecond block</div><span id=\"second\"><select style=\"visibility:hidden\"></select></span>" },
    // Presentational elements move as they are.
    .{ .input = "<p>foo</p><p><b id=\"b\">[]bar</b></p>", .commands = &.{.{ "delete", "" }}, .expected = "<p>foo<b id=\"b\">bar</b></p>" },
};

fn mergedLineLeavesItsSpan() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try harness.runCases(page, &move_cases);
}

test "a block merge moves a line out of its span, as Chrome and Safari do" {
    try helpers.onFreshThread(mergedLineLeavesItsSpan);
}
