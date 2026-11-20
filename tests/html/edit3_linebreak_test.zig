//! Lane edit3: insertLineBreak in richly editable content where the style
//! keeps newlines inserts a line feed, and a br inside a <pre> - Blink's
//! InsertLineBreakCommand::ShouldUseBreakElement, as Safari does
//! (src/html/execcommand/paragraph.zig prefersLinefeed; editing/run/
//! insertlinebreak.html: Chrome 157 and Safari 27.2 pass the flex and grid
//! rows and the <pre> rows, wpt.fyi 2358bd4835).
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

fn linefeeds() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    const Case = harness.Case;
    const br = [_][2][]const u8{.{ "insertlinebreak", "" }};
    try harness.runCases(page, &[_]Case{
        .{ .input = "<div style=display:flex;white-space:pre><span>[]abc</span></div>", .commands = &br, .expected = "<div style=\"display:flex;white-space:pre\"><span>\nabc</span></div>" },
        .{ .input = "<div style=display:grid;white-space:pre><span>a[]bc</span></div>", .commands = &br, .expected = "<div style=\"display:grid;white-space:pre\"><span>a\nbc</span></div>" },
        .{ .input = "<div style=display:inline-flex;white-space:pre><span>abc[]</span></div>", .commands = &br, .expected = "<div style=\"display:inline-flex;white-space:pre\"><span>abc\n<br></span></div>" },
        // A <pre> keeps the br (all three), and so does collapsing white-space.
        .{ .input = "<pre>foo[]bar</pre>", .commands = &br, .expected = "<pre>foo<br>bar</pre>" },
        .{ .input = "<div>foo[]bar</div>", .commands = &br, .expected = "<div>foo<br>bar</div>" },
    });
}

test "insertLineBreak takes a line feed where the style keeps newlines, a br in a pre" {
    try helpers.onFreshThread(linefeeds);
}
