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
