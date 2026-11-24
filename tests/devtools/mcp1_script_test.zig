//! Lane mcp1, batch 1: evaluate_script and handle_dialog as
//! chrome-devtools-mcp v1.13.0 answers them (src/tools/script.ts,
//! src/tools/pages.ts handleDialog, src/utils/WaitForHelper.ts): the
//! function's JSON-stringified result, an error as McpResponse prints it
//! ("Error: <message>"; a non-Error throw made an Error), format "script",
//! dialogs answered as dialogAction says while the script runs, a navigation
//! it causes reported, and a dialog left open shown and handled.

const std = @import("std");
const testing = std.testing;
const Harness = @import("mcp1_harness.zig").Harness;

fn expectResult(text: []const u8, json: []const u8) !void {
    var buffer: [512]u8 = undefined;
    const want = try std.fmt.bufPrint(&buffer, "Script ran on page and returned:\n```json\n{s}\n```", .{json});
    try testing.expectEqualStrings(want, text);
}

test "evaluate_script: results by JSON, errors by message, format script" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    var r = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"data:text/html,<title>T</title><p>x</p>\"}");
    try testing.expect(!r.is_error);

    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => document.title\"}");
    try expectResult(r.text, "\"T\"");
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"async () => ({a: [1, 2], b: null});\"}");
    try expectResult(r.text, "{\"a\":[1,2],\"b\":null}");
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => undefined\"}");
    try expectResult(r.text, "undefined");
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"1 + 2\",\"format\":\"script\"}");
    try expectResult(r.text, "3");

    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"async () => { throw new TypeError('bad thing'); }\"}");
    try testing.expect(r.is_error);
    try testing.expectEqualStrings("Error: bad thing", r.text);
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => { throw {code: 7}; }\"}");
    try testing.expect(r.is_error);
    try testing.expectEqualStrings("Error: {\"code\":7}", r.text);
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => 1\",\"format\":\"script\",\"args\":[\"1_1\"]}");
    try testing.expectEqualStrings("Error: args cannot be used when format is \"script\".", r.text);
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"(el) => el.id\",\"args\":[\"1_1\"]}");
    try testing.expectEqualStrings("Error: No snapshot found for page 1. Use take_snapshot to capture one.", r.text);
}

test "evaluate_script: dialogs answered as dialogAction says, and a navigation reported" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    var r = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"data:text/html,<title>D</title>d\"}");
    try testing.expect(!r.is_error);
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => confirm('sure?')\"}");
    try expectResult(r.text, "true");
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => confirm('sure?')\",\"dialogAction\":\"dismiss\"}");
    try expectResult(r.text, "false");
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => prompt('name?')\",\"dialogAction\":\"typed\"}");
    try expectResult(r.text, "\"typed\"");

    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => { location.reload(); }\"}");
    try testing.expectEqualStrings("Script ran on page and returned:\n```json\nundefined\n```\nPage navigated to data:text/html,<title>D</title>d.", r.text);
}

test "a dialog left open: shown with the pages, refused by evaluate_script, handled by handle_dialog" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    var r = try h.tool("handle_dialog", "{\"pageId\":1,\"action\":\"accept\"}");
    try testing.expect(r.is_error);
    try testing.expectEqualStrings("Error: No open dialog found", r.text);

    // An alert after the script's wait has ended stays open.
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => { setTimeout(() => alert('later'), 400); }\"}");
    try testing.expect(!r.is_error);
    var tries: u32 = 0;
    while (tries < 100) : (tries += 1) {
        try h.settle(50);
        r = try h.tool("list_pages", "{}");
        if (std.mem.startsWith(u8, r.text, "# Open dialog")) break;
    }
    try testing.expectEqualStrings("# Open dialog\nalert: later.\nCall handle_dialog to handle it before continuing.\n## Pages\n1: about:blank [selected]", r.text);

    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => 1\"}");
    try testing.expect(r.is_error);
    try testing.expectEqualStrings("Error: A dialog is open (alert: later).", r.text);

    r = try h.tool("handle_dialog", "{\"pageId\":1,\"action\":\"accept\"}");
    try testing.expectEqualStrings("Successfully accepted the dialog\n## Pages\n1: about:blank [selected]", r.text);
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => 1\"}");
    try expectResult(r.text, "1");
}
