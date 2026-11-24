//! Lane mcp1, batch 1: list_network_requests and get_network_request as
//! chrome-devtools-mcp v1.13.0 answers them (src/tools/network.ts,
//! src/formatters/NetworkFormatter.ts): a page's requests since its last
//! navigation with their reqids and statuses, the resource-type filter, and
//! one request's headers and body - against a loopback site (lane cdpr's).

const std = @import("std");
const testing = std.testing;
const Harness = @import("mcp1_harness.zig").Harness;
const Site = @import("cdpr_replay.zig").Site;

test "list_network_requests and get_network_request: a document, its subresources, a fetch, a 404" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const site = try Site.start(h.gpa.allocator());
    defer site.stop();
    const a = h.arena.allocator();
    var buffer: [128]u8 = undefined;
    const root = try a.dupe(u8, try site.url(&buffer, "/"));

    var r = try h.tool("list_network_requests", "{\"pageId\":1}");
    try testing.expectEqualStrings("## Network requests\nNo requests found.", r.text);

    r = try h.tool("navigate_page", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"url\":\"{s}\"}}", .{root}));
    try testing.expect(!r.is_error);
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"async () => (await fetch('/missing')).status\"}");
    try testing.expectEqualStrings("Script ran on page and returned:\n```json\n404\n```", r.text);

    r = try h.tool("list_network_requests", "{\"pageId\":1}");
    var lines = std.mem.splitScalar(u8, r.text, '\n');
    try testing.expectEqualStrings("## Network requests", lines.next().?);
    try testing.expectEqualStrings("Showing 1-4 of 4 (Page 1 of 1).", lines.next().?);
    try testing.expectEqualStrings(try std.fmt.allocPrint(a, "reqid=1 GET {s} [200]", .{root}), lines.next().?);
    // The frame and the script, in the order they were asked for.
    var seen_frame = false;
    var seen_script = false;
    for (0..2) |_| {
        const line = lines.next().?;
        if (std.mem.endsWith(u8, line, try std.fmt.allocPrint(a, " GET {s}frame.html [200]", .{root}))) seen_frame = true;
        if (std.mem.endsWith(u8, line, try std.fmt.allocPrint(a, " GET {s}app.js [200]", .{root}))) seen_script = true;
    }
    try testing.expect(seen_frame and seen_script);
    try testing.expectEqualStrings(try std.fmt.allocPrint(a, "reqid=4 GET {s}missing [404]", .{root}), lines.next().?);

    r = try h.tool("list_network_requests", "{\"pageId\":1,\"resourceTypes\":[\"script\"]}");
    try testing.expect(std.mem.startsWith(u8, r.text, "## Network requests\nShowing 1-1 of 1 (Page 1 of 1).\nreqid="));
    try testing.expect(std.mem.endsWith(u8, r.text, "app.js [200]"));

    r = try h.tool("get_network_request", "{\"pageId\":1,\"reqid\":1}");
    try testing.expect(!r.is_error);
    try testing.expect(std.mem.startsWith(u8, r.text, try std.fmt.allocPrint(a, "## Request {s}\nStatus: 200\n### Request Headers\n", .{root})));
    // The response's headers by name, as Chrome's CDP gives them (its
    // Network.Headers are a base::Value::Dict, sorted): the site sends
    // Content-Type, Content-Length, Cache-Control, Connection.
    const sorted = try std.fmt.allocPrint(a, "\n### Response Headers\n- cache-control:no-store\n- connection:close\n- content-length:{d}\n- content-type:text/html\n### Response Body\n", .{Site.index_html.len});
    if (std.mem.indexOf(u8, r.text, sorted) == null) {
        std.log.err("got: {s}", .{r.text});
        return error.TestUnexpectedResult;
    }
    try testing.expect(std.mem.endsWith(u8, r.text, "\n### Response Body\n" ++ Site.index_html));

    r = try h.tool("get_network_request", "{\"pageId\":1,\"reqid\":99}");
    try testing.expect(r.is_error);
    try testing.expectEqualStrings("Request not found for selected page", r.text);
    r = try h.tool("get_network_request", "{\"pageId\":1}");
    try testing.expectEqualStrings("Nothing is currently selected in the DevTools Network panel.", r.text);

    // A new document: the list starts again, the ids go on.
    r = try h.tool("navigate_page", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"url\":\"{s}data.json\"}}", .{root}));
    try testing.expect(!r.is_error);
    r = try h.tool("list_network_requests", "{\"pageId\":1}");
    try testing.expectEqualStrings(try std.fmt.allocPrint(a, "## Network requests\nShowing 1-1 of 1 (Page 1 of 1).\nreqid=5 GET {s}data.json [200]", .{root}), r.text);
}
