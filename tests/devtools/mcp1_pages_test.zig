//! Lane mcp1, batch 1: Crane's MCP server's navigation tools, driven as an
//! MCP client drives them (initialize, tools/list, tools/call), against a
//! Browser on its own thread - list_pages, new_page, select_page,
//! navigate_page, close_page, answering as chrome-devtools-mcp v1.13.0 does
//! (src/tools/pages.ts; src/McpResponse.ts's "## Pages" section; a title
//! that only repeats the URL is no title, McpPage.getTitle).

const std = @import("std");
const testing = std.testing;

const Harness = @import("mcp1_harness.zig").Harness;

test "tools/list names the navigation tools with chrome-devtools-mcp's own definitions" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const list = try h.send("tools/list", "{}");
    var names: std.ArrayList([]const u8) = .empty;
    for (list.object.get("result").?.object.get("tools").?.array.items) |t| try names.append(h.arena.allocator(), t.object.get("name").?.string);
    for ([_][]const u8{ "close_page", "list_pages", "navigate_page", "new_page", "select_page" }) |want| {
        var found = false;
        for (names.items) |n| if (std.mem.eql(u8, n, want)) {
            found = true;
        };
        try testing.expect(found);
    }
    // The copied schema: navigate_page takes pageId (pageIdRouting) and
    // rejects unknown properties.
    for (list.object.get("result").?.object.get("tools").?.array.items) |t| {
        if (!std.mem.eql(u8, t.object.get("name").?.string, "navigate_page")) continue;
        const schema = t.object.get("inputSchema").?.object;
        try testing.expect(schema.get("properties").?.object.get("pageId") != null);
    }
}

test "list_pages, new_page, select_page, navigate_page and close_page answer as chrome-devtools-mcp's" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    var r = try h.tool("list_pages", "{}");
    try testing.expectEqualStrings("## Pages\n1: about:blank [selected]", r.text);

    r = try h.tool("new_page", "{\"url\":\"data:text/html,<title>Two</title>two\"}");
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings("## Pages\n1: about:blank\n2: Two (data:text/html,<title>Two</title>two) [selected]", r.text);

    r = try h.tool("select_page", "{\"pageId\":1}");
    try testing.expectEqualStrings("## Pages\n1: about:blank [selected]\n2: Two (data:text/html,<title>Two</title>two)", r.text);

    r = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"data:text/html,<title>One</title>one\"}");
    try testing.expectEqualStrings("Successfully navigated to data:text/html,<title>One</title>one.\n## Pages\n1: One (data:text/html,<title>One</title>one) [selected]\n2: Two (data:text/html,<title>Two</title>two)", r.text);

    // validateUrl refuses before any navigation.
    r = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"chrome://settings\"}");
    try testing.expect(r.is_error);
    try testing.expectEqualStrings("Navigating to chrome: URLs is not allowed.", r.text);

    r = try h.tool("navigate_page", "{\"pageId\":7,\"type\":\"reload\"}");
    try testing.expect(r.is_error);
    try testing.expectEqualStrings("No page found", r.text);

    r = try h.tool("close_page", "{\"pageId\":2}");
    try testing.expectEqualStrings("## Pages\n1: One (data:text/html,<title>One</title>one) [selected]", r.text);

    r = try h.tool("close_page", "{\"pageId\":1}");
    try testing.expectEqualStrings("The last open page cannot be closed. It is fine to keep it open.\n## Pages\n1: One (data:text/html,<title>One</title>one) [selected]", r.text);
}
