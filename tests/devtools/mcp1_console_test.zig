//! Lane mcp1, batch 1: list_console_messages and get_console_message as
//! chrome-devtools-mcp v1.13.0 answers them (src/tools/console.ts,
//! src/formatters/ConsoleFormatter.ts; its own expectations in
//! tests/tools/console.test.ts and its snapshot): Puppeteer's text for each
//! message (an Error argument as its description's first line), msgids per
//! page from 1, the current navigation's messages unless preserved ones are
//! asked for, consecutive repeats grouped, the type filter, pagination, and
//! the detailed view with each argument resolved.

const std = @import("std");
const testing = std.testing;
const Harness = @import("mcp1_harness.zig").Harness;

test "list_console_messages: Puppeteer's text, ids from 1, grouping, types and pages" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    var r = try h.tool("list_console_messages", "{\"pageId\":1}");
    try testing.expectEqualStrings("## Console messages\n<no console messages found>", r.text);

    r = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"data:text/html,<script>console.log('hello', 1); console.warn('w'); console.error(new Error('boom')); for (let i = 0; i < 3; i++) console.log('x');</script>\"}");
    try testing.expect(!r.is_error);
    r = try h.tool("list_console_messages", "{\"pageId\":1}");
    try testing.expectEqualStrings(
        \\## Console messages
        \\Showing 1-4 of 4 (Page 1 of 1).
        \\msgid=1 [log] hello 1 (2 args)
        \\msgid=2 [warn] w (1 args)
        \\msgid=3 [error] Error: boom (1 args)
        \\msgid=4 [log] x (1 args) [3 times]
    , r.text);

    r = try h.tool("list_console_messages", "{\"pageId\":1,\"types\":[\"warn\"]}");
    try testing.expectEqualStrings("## Console messages\nShowing 1-1 of 1 (Page 1 of 1).\nmsgid=2 [warn] w (1 args)", r.text);

    r = try h.tool("list_console_messages", "{\"pageId\":1,\"pageSize\":3,\"pageIdx\":1}");
    try testing.expectEqualStrings("## Console messages\nShowing 4-4 of 4 (Page 2 of 2).\nPrevious page: 0\nmsgid=4 [log] x (1 args) [3 times]", r.text);

    // A new document starts a navigation: only its messages are listed,
    // unless the preserved ones are asked for; ids go on.
    r = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"data:text/html,<script>throw new TypeError('bad')</script>\"}");
    try testing.expect(!r.is_error);
    r = try h.tool("list_console_messages", "{\"pageId\":1}");
    try testing.expectEqualStrings("## Console messages\nShowing 1-1 of 1 (Page 1 of 1).\nmsgid=7 [error] Uncaught TypeError: bad (0 args)", r.text);
    r = try h.tool("list_console_messages", "{\"pageId\":1,\"includePreservedMessages\":true}");
    try testing.expect(std.mem.startsWith(u8, r.text, "## Console messages\nShowing 1-5 of 5 (Page 1 of 1).\nmsgid=1 [log] hello 1 (2 args)\n"));
}

test "get_console_message: the detailed view, each argument resolved, and an unknown msgid" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    var r = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"data:text/html,<script>function logIt() { console.log('obj', {a: 1, b: [2, 'c']}, null, new Map([['k', 1]])); } logIt();</script>\"}");
    try testing.expect(!r.is_error);
    r = try h.tool("get_console_message", "{\"pageId\":1,\"msgid\":1}");
    try testing.expect(!r.is_error);
    const expected_head =
        \\ID: 1
        \\Message: log> obj [object Object] null [map Map]
        \\### Arguments
        \\Arg #0: obj
        \\Arg #1: {"a":1,"b":[2,"c"]}
        \\Arg #2: null
        \\Arg #3: Map(1) {'k' => 1}
        \\### Stack trace
        \\at logIt (
    ;
    if (!std.mem.startsWith(u8, r.text, expected_head)) {
        std.log.err("got: {s}", .{r.text});
        return error.TestUnexpectedResult;
    }
    try testing.expect(std.mem.endsWith(u8, r.text, "\nNote: line and column numbers use 1-based indexing"));

    r = try h.tool("get_console_message", "{\"pageId\":1,\"msgid\":99}");
    try testing.expect(r.is_error);
    try testing.expectEqualStrings("Request not found for selected page", r.text);
}
