//! Lane mcp1, batch 4b item 1: resize_page as chrome-devtools-mcp v1.13.0
//! does it (src/tools/pages.ts resizePage: the window restored to normal
//! with Browser.setWindowBounds when it is not, then Puppeteer's
//! page.resize - Browser.setContentsSize), and Browser.setContentsSize as
//! Chrome answers it (chrome/browser/devtools/protocol/browser_handler.cc
//! BrowserHandler::SetContentsSize: the window's bounds grown by the
//! difference to the asked contents size; its errors in Chrome's order).

const std = @import("std");
const testing = std.testing;
const Harness = @import("mcp1_harness.zig").Harness;
const session_mod = @import("devtools").mcp.session;

/// A browser-level command's answer: its result, or its error's code and
/// message as "<code> <message>".
fn browserCall(h: *Harness, method: []const u8, params: []const u8) ![]const u8 {
    const a = h.arena.allocator();
    var r = try h.mcp_server.session.client.call(method, params, "", session_mod.command_timeout_ms);
    defer r.deinit();
    if (r.errorMessage()) |message| {
        const code = r.parsed.value.object.get("error").?.object.get("code").?.integer;
        return std.fmt.allocPrint(a, "{d} {s}", .{ code, message });
    }
    return std.json.Stringify.valueAlloc(a, r.result().?, .{});
}

fn windowId(h: *Harness) !i64 {
    const a = h.arena.allocator();
    const page = h.mcp_server.session.pageById(1) orelse return error.NoPage;
    const params = try std.fmt.allocPrint(a, "{{\"targetId\":{f}}}", .{std.json.fmt(page.target_id, .{})});
    const text = try browserCall(h, "Browser.getWindowForTarget", params);
    const parsed = try std.json.parseFromSliceLeaky(std.json.Value, a, text, .{});
    return parsed.object.get("windowId").?.integer;
}

test "resize_page: the page's contents take the size, the answer is the pages" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    var r = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"data:text/html,<title>R</title>\"}");
    try testing.expect(!r.is_error);
    r = try h.tool("resize_page", "{\"pageId\":1,\"width\":800,\"height\":600}");
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings("## Pages\n1: R (data:text/html,<title>R</title>) [selected]", r.text);
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => [innerWidth, innerHeight]\"}");
    try testing.expectEqualStrings("Script ran on page and returned:\n```json\n[800,600]\n```", r.text);
    // A minimized window is restored first.
    const id = try windowId(&h);
    const a = h.arena.allocator();
    _ = try browserCall(&h, "Browser.setWindowBounds", try std.fmt.allocPrint(a, "{{\"windowId\":{d},\"bounds\":{{\"windowState\":\"minimized\"}}}}", .{id}));
    r = try h.tool("resize_page", "{\"pageId\":1,\"width\":640,\"height\":480}");
    try testing.expect(!r.is_error);
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => [innerWidth, innerHeight]\"}");
    try testing.expectEqualStrings("Script ran on page and returned:\n```json\n[640,480]\n```", r.text);
}

test "Browser.setContentsSize: Chrome's errors, in Chrome's order; one side alone keeps the other" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const a = h.arena.allocator();
    const id = try windowId(&h);
    try testing.expectEqualStrings("-32000 Browser window not found", try browserCall(&h, "Browser.setContentsSize", "{\"windowId\":987654,\"width\":10}"));
    try testing.expectEqualStrings("-32602 At least one of 'width' or 'height' must be specified", try browserCall(&h, "Browser.setContentsSize", try std.fmt.allocPrint(a, "{{\"windowId\":{d}}}", .{id})));
    try testing.expectEqualStrings("-32602 Contents 'width' must be a positive value", try browserCall(&h, "Browser.setContentsSize", try std.fmt.allocPrint(a, "{{\"windowId\":{d},\"width\":0}}", .{id})));
    try testing.expectEqualStrings("-32602 Contents 'height' must be a positive value", try browserCall(&h, "Browser.setContentsSize", try std.fmt.allocPrint(a, "{{\"windowId\":{d},\"width\":10,\"height\":-1}}", .{id})));
    try testing.expectEqualStrings("{}", try browserCall(&h, "Browser.setContentsSize", try std.fmt.allocPrint(a, "{{\"windowId\":{d},\"width\":1000,\"height\":700}}", .{id})));
    try testing.expectEqualStrings("{}", try browserCall(&h, "Browser.setContentsSize", try std.fmt.allocPrint(a, "{{\"windowId\":{d},\"height\":500}}", .{id})));
    const r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => [innerWidth, innerHeight]\"}");
    try testing.expectEqualStrings("Script ran on page and returned:\n```json\n[1000,500]\n```", r.text);
    // Not a normal window: restored first, or refused - before the
    // arguments are looked at.
    _ = try browserCall(&h, "Browser.setWindowBounds", try std.fmt.allocPrint(a, "{{\"windowId\":{d},\"bounds\":{{\"windowState\":\"maximized\"}}}}", .{id}));
    try testing.expectEqualStrings("-32000 Restore window to normal state before setting content size", try browserCall(&h, "Browser.setContentsSize", try std.fmt.allocPrint(a, "{{\"windowId\":{d}}}", .{id})));
}
