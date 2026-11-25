//! Lane mcp1, batch 4b item 2: emulate as chrome-devtools-mcp v1.13.0 does
//! it (src/tools/emulation.ts, McpPage.emulate over Puppeteer's managers):
//! every call applies every setting - the user agent, the media features,
//! the viewport - and clears what it leaves out; the settings whose CDP
//! Crane cannot apply yet (network conditions, CPU throttling above 1,
//! geolocation) answer that the server does not support them; the CDP
//! "off" values Puppeteer sends on every call are answered.

const std = @import("std");
const testing = std.testing;
const Harness = @import("mcp1_harness.zig").Harness;

fn expectResult(h: *Harness, function: []const u8, json: []const u8) !void {
    const a = h.arena.allocator();
    const r = try h.tool("evaluate_script", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"function\":{f}}}", .{std.json.fmt(function, .{})}));
    try testing.expectEqualStrings(try std.fmt.allocPrint(a, "Script ran on page and returned:\n```json\n{s}\n```", .{json}), r.text);
}

const media = "() => ['(prefers-color-scheme: dark)', '(prefers-reduced-motion: reduce)', '(prefers-contrast: more)', '(forced-colors: active)'].map(q => matchMedia(q).matches)";

test "emulate: a user agent, the media features and a viewport, each cleared by a call that leaves it out" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    var r = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"data:text/html,<title>E</title>\"}");
    try testing.expect(!r.is_error);
    const own = try h.arena.allocator().dupe(u8, (try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => navigator.userAgent\"}")).text);

    r = try h.tool("emulate", "{\"pageId\":1,\"userAgent\":\"Agent/1\",\"colorScheme\":\"dark\",\"prefersReducedMotion\":\"reduce\",\"prefersContrast\":\"more\",\"forcedColors\":\"active\",\"viewport\":\"400x300x2\"}");
    try testing.expect(!r.is_error);
    // McpResponse prints the page's emulation for a page tool's answer.
    const emulating =
        \\Emulating viewport: {"deviceScaleFactor":2,"isMobile":false,"hasTouch":false,"isLandscape":false,"width":400,"height":300}
        \\Emulating user agent: Agent/1
        \\Emulating color scheme: dark
        \\Emulating forced-colors: active
        \\Emulating prefers-contrast: more
        \\Emulating prefers-reduced-motion: reduce
    ;
    try testing.expectEqualStrings("Emulation configured successfully\n" ++ emulating, r.text);
    // evaluate_script is not a page tool (it resolves its page itself):
    // its answers below carry none.
    try expectResult(&h, "() => navigator.userAgent", "\"Agent/1\"");
    try expectResult(&h, media, "[true,true,true,true]");
    try expectResult(&h, "() => [innerWidth, innerHeight, devicePixelRatio]", "[400,300,2]");
    // Another page tool's answer carries them, after its own lines.
    r = try h.tool("list_console_messages", "{\"pageId\":1}");
    try testing.expect(std.mem.indexOf(u8, r.text, emulating) != null);
    // A viewport with no scale: the undefined key JSON drops.
    r = try h.tool("emulate", "{\"pageId\":1,\"viewport\":\"500x400\"}");
    try testing.expectEqualStrings("Emulation configured successfully\nEmulating viewport: {\"isMobile\":false,\"hasTouch\":false,\"isLandscape\":false,\"width\":500,\"height\":400}", r.text);
    try expectResult(&h, "() => [innerWidth, innerHeight, devicePixelRatio]", "[500,400,1]");

    // A call with none of them: each is cleared.
    r = try h.tool("emulate", "{\"pageId\":1}");
    try testing.expectEqualStrings("Emulation configured successfully", r.text);
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => navigator.userAgent\"}");
    try testing.expectEqualStrings(own, r.text);
    try expectResult(&h, media, "[false,false,false,false]");
    // "auto" is none too.
    r = try h.tool("emulate", "{\"pageId\":1,\"colorScheme\":\"auto\"}");
    try expectResult(&h, media, "[false,false,false,false]");
}

test "emulate: mobile and touch reload the page, as Puppeteer's setViewport does" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    var r = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"data:text/html,<title>M</title>\"}");
    try testing.expect(!r.is_error);
    try expectResult(&h, "() => { window.marker = 1; return window.marker; }", "1");
    r = try h.tool("emulate", "{\"pageId\":1,\"viewport\":\"390x844x3,mobile,touch\"}");
    try testing.expectEqualStrings("Emulation configured successfully\nEmulating viewport: {\"deviceScaleFactor\":3,\"isMobile\":true,\"hasTouch\":true,\"isLandscape\":false,\"width\":390,\"height\":844}", r.text);
    // A new document: the marker is gone.
    try expectResult(&h, "() => [window.marker === undefined, innerWidth, navigator.maxTouchPoints > 0]", "[true,390,true]");
}

test "emulate: the settings Crane cannot apply yet say so; an invalid viewport is the schema's error" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    var r = try h.tool("emulate", "{\"pageId\":1,\"networkConditions\":\"Slow 3G\"}");
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings("Emulation configured successfully\nEmulating network conditions: Slow 3G\nDefault navigation timeout set to 100000 ms", r.text);
    r = try h.tool("emulate", "{\"pageId\":1,\"cpuThrottlingRate\":4}");
    try testing.expectEqualStrings("Error: cpuThrottlingRate is not supported by Crane's MCP server yet.", r.text);
    r = try h.tool("emulate", "{\"pageId\":1,\"geolocation\":\"52.5,13.4\"}");
    try testing.expectEqualStrings("Error: geolocation is not supported by Crane's MCP server yet.", r.text);
    // A rate of 1 is none (and clears networkConditions left out of the call).
    r = try h.tool("emulate", "{\"pageId\":1,\"cpuThrottlingRate\":1}");
    try testing.expectEqualStrings("Emulation configured successfully", r.text);
    r = try h.tool("emulate", "{\"pageId\":1,\"viewport\":\"400x300,wide\"}");
    try testing.expect(r.is_error);
    try testing.expectEqualStrings("Input validation error: Invalid arguments for tool emulate: viewport: Invalid viewport option \"wide\". Expected \"mobile\", \"touch\", or \"landscape\" in '<width>x<height>x<devicePixelRatio>[,mobile][,touch][,landscape]'.", r.text);
}
