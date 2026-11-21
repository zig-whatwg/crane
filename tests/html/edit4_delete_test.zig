//! Lane edit4: delete and forwardDelete.
//!
//! A13 - Backspace at the start of a block right after a block whose last
//! line is a br after a block child removes just that br (Chrome 157,
//! Firefox 160 and Safari 27.2; editing/run/delete.html PPP at wpt.fyi
//! 2358bd4835), where the spec joins the next block's line into the inner
//! block.
//!
//! A12 - a br beside the caret goes even when an inline element holds the
//! caret (all three; editing/run/delete.html and forwarddelete.html PPP),
//! where the spec's delete and forwardDelete stop at an inline node.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

const empty_line_cases = [_]harness.Case{
    .{ .input = "<div><div>abc</div><br></div><div>[]def</div>", .commands = &.{.{ "delete", "" }}, .expected = "<div><div>abc</div></div><div>def</div>" },
    .{ .input = "<div><font><table><td>a</table><br>{}<br><table><td>b</table></font></div>", .commands = &.{.{ "delete", "" }}, .expected = "<div><font><table><tbody><tr><td>a</td></tr></tbody></table><br><table><tbody><tr><td>b</td></tr></tbody></table></font></div>" },
    .{ .input = "<div><font><table><td>a</table>{}<br><br><table><td>b</table></font></div>", .commands = &.{.{ "forwarddelete", "" }}, .expected = "<div><font><table><tbody><tr><td>a</td></tr></tbody></table><br><table><tbody><tr><td>b</td></tr></tbody></table></font></div>" },
};

fn emptyLineAfterBlock() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try page.run("document.getElementById('host').focus();");
    try harness.runCases(page, &empty_line_cases);
}

test "Backspace after a block ending in a br after a block child removes just the br" {
    try helpers.onFreshThread(emptyLineAfterBlock);
}
