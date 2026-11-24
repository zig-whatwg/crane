//! Lane mcp1, batch 1: press_key and type_text as chrome-devtools-mcp
//! v1.13.0 answers them (src/tools/input.ts), the keys sent as Puppeteer's
//! keyboard sends them: typed text reaches the focused input, a key
//! combination's modifiers are held around its key, a submit key follows the
//! text, and an unknown key is refused by the schema's parseKey.

const std = @import("std");
const testing = std.testing;
const Harness = @import("mcp1_harness.zig").Harness;

test "type_text and press_key: the focused input's value, the keys' events, and refused keys" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    var r = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"data:text/html,<input id=i><script>window.keys = []; document.addEventListener('keydown', (e) => keys.push(e.key + (e.ctrlKey ? '+ctrl' : '') + (e.shiftKey ? '+shift' : '')));</script>\"}");
    try testing.expect(!r.is_error);
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => { document.getElementById('i').focus(); }\"}");
    try testing.expect(!r.is_error);

    r = try h.tool("type_text", "{\"pageId\":1,\"text\":\"Hi é\",\"submitKey\":\"Tab\"}");
    try testing.expectEqualStrings("Typed text \"Hi \u{e9} + Tab\"", r.text);
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => [document.getElementById('i').value, keys.join(',')]\"}");
    // "H" is the layout's own key (no Shift held, as Puppeteer types it); é
    // has no key in the US layout: it is inserted, with no keydown.
    try testing.expectEqualStrings("Script ran on page and returned:\n```json\n[\"Hi \u{e9}\",\"H,i, ,Tab\"]\n```", r.text);

    r = try h.tool("press_key", "{\"pageId\":1,\"key\":\"Control+Shift+K\"}");
    try testing.expectEqualStrings("Successfully pressed key: Control+Shift+K", r.text);
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => keys.slice(4).join(',')\"}");
    try testing.expectEqualStrings("Script ran on page and returned:\n```json\n\"Control+ctrl,Shift+ctrl+shift,K+ctrl+shift\"\n```", r.text);

    r = try h.tool("press_key", "{\"pageId\":1,\"key\":\"Ctrl+A\"}");
    try testing.expect(r.is_error);
    try testing.expect(std.mem.startsWith(u8, r.text, "Input validation error: Invalid arguments for tool press_key: key: Ctrl is invalid. Valid keys are: 0,1,2,"));
}
