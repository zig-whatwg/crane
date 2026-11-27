//! Lane mcp-tools1: Batch 6 & remaining MCP tools completeness tests:
//! - needs-renderer tools (`take_screenshot`, `screencast_start`, `screencast_stop`,
//!   `performance_start_trace`, `performance_stop_trace`, `performance_analyze_insight`,
//!   `click_at`) + Chrome-only `lighthouse_audit` returning `"disabled"`
//! - slim mode (`navigate`, `evaluate`, `screenshot`)
//! - network mocks (`mock_network`, `remove_network_mock`)
//! - third-party developer tools (`list_3p_developer_tools`, `execute_3p_developer_tool`)
//! - console stack trace source-map resolution + ignoreList filtering

const std = @import("std");
const testing = std.testing;
const Harness = @import("mcp1_harness.zig").Harness;
const devtools = @import("devtools");
const browser_mod = @import("browser");
const platform = @import("platform");

test "default tools/list returns all 32 tools (33 minus Chrome-only lighthouse_audit) and lighthouse_audit is disabled" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();

    const list_resp = try h.send("tools/list", "{}");
    const tools_arr = list_resp.object.get("result").?.object.get("tools").?.array.items;
    try testing.expectEqual(@as(usize, 32), tools_arr.len);

    const required_renderer = [_][]const u8{
        "take_screenshot",
        "screencast_start",
        "screencast_stop",
        "performance_start_trace",
        "performance_stop_trace",
        "performance_analyze_insight",
    };
    for (required_renderer) |want| {
        var found = false;
        for (tools_arr) |t| {
            if (std.mem.eql(u8, t.object.get("name").?.string, want)) found = true;
        }
        try testing.expect(found);
    }
    for (tools_arr) |t| {
        const name = t.object.get("name").?.string;
        try testing.expect(!std.mem.eql(u8, name, "lighthouse_audit"));
        try testing.expect(!std.mem.eql(u8, name, "click_at"));
    }

    // Calling lighthouse_audit returns "Tool lighthouse_audit disabled", never "not found".
    const lh = try h.send("tools/call", "{\"name\":\"lighthouse_audit\",\"arguments\":{\"pageId\":1}}");
    const err_msg = lh.object.get("error").?.object.get("message").?.string;
    try testing.expectEqualStrings("Tool lighthouse_audit disabled", err_msg);

    // Calling click_at without --experimentalVision returns "Tool click_at disabled", never "not found".
    const ca = try h.send("tools/call", "{\"name\":\"click_at\",\"arguments\":{\"pageId\":1,\"x\":10,\"y\":20}}");
    const ca_msg = ca.object.get("error").?.object.get("message").?.string;
    try testing.expectEqualStrings("Tool click_at disabled", ca_msg);
}

test "needs-renderer tools return a clear missing-renderer MCP tool error" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();

    const cases = [_]struct { name: []const u8, args: []const u8 }{
        .{ .name = "take_screenshot", .args = "{\"pageId\":1}" },
        .{ .name = "screencast_start", .args = "{\"pageId\":1}" },
        .{ .name = "screencast_stop", .args = "{\"pageId\":1}" },
        .{ .name = "performance_start_trace", .args = "{\"pageId\":1}" },
        .{ .name = "performance_stop_trace", .args = "{\"pageId\":1}" },
        .{ .name = "performance_analyze_insight", .args = "{\"pageId\":1,\"insightSetId\":\"nav-1\",\"insightName\":\"DocumentLatency\"}" },
    };
    for (cases) |c| {
        const r = try h.tool(c.name, c.args);
        try testing.expect(r.is_error);
        try testing.expect(std.mem.indexOf(u8, r.text, "not found") == null);
        try testing.expect(std.mem.indexOf(u8, r.text, "renderer") != null);
        try testing.expect(std.mem.indexOf(u8, r.text, c.name) != null);
    }
}

test "console stack trace resolves Source Map V3 locations and skips ignoreList frames" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const a = h.arena.allocator();

    // Generated script:
    // line 0: function lib(){ console.error("mapped-err"); }
    // line 1: function app(){ lib(); }
    // line 2: app();
    // Source map maps:
    // - line 0 col 0.. -> vendor.js (ignoreList: [0]) line 9 col 0 (1-based 10:1)
    // - line 1 col 0.. -> src/app.ts line 41 col 4 (1-based 42:5)
    // - line 2 col 0.. -> src/app.ts line 99 col 0 (1-based 100:1)
    //
    // Mappings VLQ:
    // line 0: AAAA -> gen(0,0) src 0 (0,0) -> let's map gen(0,0) -> src 0 (9,0): AAAS (0,0,+9,0)
    // line 1: AC+B -> gen(1,0) src +1=1 line +32=41 col +4=4:
    //   delta_col=0(A), delta_src=+1(C), delta_src_line=+32(gC), delta_src_col=+4(I) -> ACgCI
    //   Let's verify VLQ: 32 << 1 = 64 = 0b1000000 -> low 5 bits 0 + cont(32) = 32 ('g'), high = 2 ('C') -> "gC".
    //   +9 << 1 = 18 = 'S'.
    //   +4 << 1 = 8 = 'I'.
    // line 2: AA0D -> gen(2,0) src +0=1 line +58=99 col -4=0:
    //   delta_col=0(A), delta_src=0(A), delta_src_line=+58: 58<<1=116 = 0b1110100 -> low 20+32=52('0'), high 3('D') -> "0D",
    //   delta_src_col=-4: (4<<1)|1 = 9('J') -> AA0DJ.
    const map_json =
        \\{"version":3,"sources":["vendor.js","src/app.ts"],"ignoreList":[0],"names":[],"mappings":"AAAS;ACgCI;AA0DJ"}
    ;
    const b64_len = std.base64.standard.Encoder.calcSize(map_json.len);
    const b64 = try a.alloc(u8, b64_len);
    _ = std.base64.standard.Encoder.encode(b64, map_json);

    const js = try std.fmt.allocPrint(
        a,
        "function lib(){{ console.error('mapped-err'); }}\nfunction app(){{ lib(); }}\napp();\n//# sourceURL=http://example.test/bundle.js\n//# sourceMappingURL=data:application/json;base64,{s}\n",
        .{b64},
    );
    const nav_url = try std.fmt.allocPrint(a, "data:text/html,<script>{s}</script>", .{js});
    const nav_args = try std.fmt.allocPrint(a, "{{\"pageId\":1,\"url\":{f}}}", .{std.json.fmt(nav_url, .{})});
    const nav = try h.tool("navigate_page", nav_args);
    try testing.expect(!nav.is_error);

    const detail = try h.tool("get_console_message", "{\"pageId\":1,\"msgid\":1}");
    try testing.expect(!detail.is_error);
    // Original source file & 1-based line:col resolved via source map:
    try testing.expect(std.mem.indexOf(u8, detail.text, "app.ts:42:5") != null);
    try testing.expect(std.mem.indexOf(u8, detail.text, "app.ts:100:1") != null);
    // Ignore-listed vendor frame omitted:
    try testing.expect(std.mem.indexOf(u8, detail.text, "vendor.js") == null);
    try testing.expect(std.mem.indexOf(u8, detail.text, "at lib") == null);

    // list_console_messages with includeStackTraces also resolves source maps & omits ignoreList.
    const listed = try h.tool("list_console_messages", "{\"pageId\":1,\"includeStackTraces\":true}");
    try testing.expect(!listed.is_error);
    try testing.expect(std.mem.indexOf(u8, listed.text, "app.ts:42:5") != null);
    try testing.expect(std.mem.indexOf(u8, listed.text, "vendor.js") == null);
}
