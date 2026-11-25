//! Lane mcp1, batch 4: navigate_page back and forward as
//! chrome-devtools-mcp v1.13.0 answers them (src/tools/pages.ts over
//! Puppeteer's goBack/goForward: Page.getNavigationHistory, then
//! Page.navigateToHistoryEntry and waitForNavigation - a new document's
//! load, or a same-document navigation).

const std = @import("std");
const testing = std.testing;
const Harness = @import("mcp1_harness.zig").Harness;

fn expectFirstLine(text: []const u8, want: []const u8) !void {
    const end = std.mem.indexOfScalar(u8, text, '\n') orelse text.len;
    try testing.expectEqualStrings(want, text[0..end]);
}

const a = "data:text/html,<title>A</title>a";
const b = "data:text/html,<title>B</title>b";

test "navigate_page back and forward: between documents, across a pushState, and with no entry there" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();

    // The first navigation replaces the initial about:blank (Firefox and
    // Safari as HTML; Chrome navigates its startup URL first): no entry back.
    var r = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"" ++ a ++ "\"}");
    try testing.expect(!r.is_error);
    r = try h.tool("navigate_page", "{\"pageId\":1,\"type\":\"back\"}");
    try expectFirstLine(r.text, "Unable to navigate back in the selected page: History entry to navigate to not found..");

    r = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"" ++ b ++ "\"}");
    try testing.expect(!r.is_error);
    r = try h.tool("navigate_page", "{\"pageId\":1,\"type\":\"back\"}");
    try expectFirstLine(r.text, "Successfully navigated back to " ++ a ++ ".");
    r = try h.tool("navigate_page", "{\"pageId\":1,\"type\":\"forward\"}");
    try expectFirstLine(r.text, "Successfully navigated forward to " ++ b ++ ".");
    r = try h.tool("navigate_page", "{\"pageId\":1,\"type\":\"forward\"}");
    try expectFirstLine(r.text, "Unable to navigate forward in the selected page: History entry to navigate to not found..");

    // A same-document entry: back answers at its navigatedWithinDocument,
    // with no load to wait for.
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => { history.pushState(null, '', '#pushed'); return location.href; }\"}");
    try testing.expect(!r.is_error);
    r = try h.tool("navigate_page", "{\"pageId\":1,\"type\":\"back\"}");
    try expectFirstLine(r.text, "Successfully navigated back to " ++ b ++ ".");
    r = try h.tool("navigate_page", "{\"pageId\":1,\"type\":\"forward\"}");
    try expectFirstLine(r.text, "Successfully navigated forward to " ++ b ++ "#pushed.");
}
