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
const Site = @import("cdpr_replay.zig").Site;
const devtools = @import("devtools");
const mcp = devtools.mcp;
const browser_mod = @import("browser");
const platform = @import("platform");

/// Configure an existing Harness with custom `tools.ListOptions` and optional
/// filesystem roots without modifying `server.zig`.
fn configureOptions(h: *Harness, opts: mcp.tools.ListOptions, roots: ?[]const []const u8) !void {
    const alloc = h.gpa.allocator();
    const new_json = try mcp.tools.listJsonWithOptions(alloc, opts);
    alloc.free(h.mcp_server.tools_json);
    h.mcp_server.tools_json = new_json;
    h.mcp_server.protocol.handler.tools_json = new_json;
    if (h.mcp_server.session.schemas) |*old| old.deinit();
    h.mcp_server.session.schemas = try std.json.parseFromSlice(std.json.Value, alloc, new_json, .{});
    h.mcp_server.session.memory_debugging = opts.memory_debugging;
    h.mcp_server.session.category_network_mocks = opts.category_network_mocks;
    h.mcp_server.session.category_experimental_third_party = opts.category_experimental_third_party;
    h.mcp_server.session.experimental_vision = opts.experimental_vision;
    h.mcp_server.session.slim = opts.slim;
    if (roots) |r| h.mcp_server.session.paths.configured = r;
}

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

test "needs-renderer tools and click_at return a clear missing-renderer MCP tool error" {
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

    // Enable --experimentalVision: click_at appears in tools/list (33 tools) and returns missing-renderer error.
    try configureOptions(&h, .{ .experimental_vision = true }, null);
    const list_resp = try h.send("tools/list", "{}");
    try testing.expectEqual(@as(usize, 33), list_resp.object.get("result").?.object.get("tools").?.array.items.len);
    const click_at = try h.tool("click_at", "{\"pageId\":1,\"x\":10,\"y\":20}");
    try testing.expect(click_at.is_error);
    try testing.expect(std.mem.indexOf(u8, click_at.text, "renderer") != null);
    try testing.expect(std.mem.indexOf(u8, click_at.text, "click_at") != null);
}

test "slim mode lists only navigate, evaluate, screenshot and runs without pageId" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    try configureOptions(&h, .{ .slim = true }, null);

    const list_resp = try h.send("tools/list", "{}");
    const tools_arr = list_resp.object.get("result").?.object.get("tools").?.array.items;
    try testing.expectEqual(@as(usize, 3), tools_arr.len);
    try testing.expectEqualStrings("evaluate", tools_arr[0].object.get("name").?.string);
    try testing.expectEqualStrings("navigate", tools_arr[1].object.get("name").?.string);
    try testing.expectEqualStrings("screenshot", tools_arr[2].object.get("name").?.string);

    // Non-slim tool rejected in slim mode.
    const lp = try h.send("tools/call", "{\"name\":\"list_pages\",\"arguments\":{}}");
    try testing.expect(lp.object.get("error") != null);

    // navigate without pageId.
    const nav = try h.tool("navigate", "{\"url\":\"data:text/html,<title>Slim</title><p id=x>hi</p>\"}");
    try testing.expect(!nav.is_error);
    try testing.expect(std.mem.startsWith(u8, nav.text, "Navigated to data:text/html,"));

    // evaluate without pageId returns JSON.stringify(result).
    const ev = try h.tool("evaluate", "{\"script\":\"({ title: document.title, n: 6 * 7 })\"}");
    try testing.expect(!ev.is_error);
    try testing.expectEqualStrings("{\"title\":\"Slim\",\"n\":42}", ev.text);

    // screenshot returns clean missing-renderer error.
    const ss = try h.tool("screenshot", "{}");
    try testing.expect(ss.is_error);
    try testing.expect(std.mem.indexOf(u8, ss.text, "renderer") != null);
    try testing.expect(std.mem.indexOf(u8, ss.text, "screenshot") != null);
}

test "mock_network and remove_network_mock: file body, upstream URL, diagnostics, validation, and deactivation" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();

    const site = try Site.start(h.gpa.allocator());
    defer site.stop();
    const a = h.arena.allocator();
    var url_buf: [128]u8 = undefined;
    const root = try a.dupe(u8, try site.url(&url_buf, "/"));

    // Temp workspace directory for local mock files.
    const tmp_base = try platform.tempDirectory(a);
    const work_dir = try std.fmt.allocPrint(a, "{s}/crane-mcp-mock-test-{d}", .{ tmp_base, platform.monotonicMillis() });
    try platform.makeDirectoryPath(platform.Str.from(work_dir));
    const roots = [_][]const u8{work_dir};
    try configureOptions(&h, .{ .category_network_mocks = true }, &roots);

    // tools/list includes mock_network and remove_network_mock.
    const list_resp = try h.send("tools/list", "{}");
    const tools_arr = list_resp.object.get("result").?.object.get("tools").?.array.items;
    try testing.expectEqual(@as(usize, 34), tools_arr.len);

    // Inspect when none configured.
    const empty = try h.tool("mock_network", "{\"pageId\":1}");
    try testing.expect(!empty.is_error);
    try testing.expectEqualStrings("No network mocks match these filters.", empty.text);

    // Write local mock JSON body file.
    const mock_file = try std.fmt.allocPrint(a, "{s}/mock.json", .{work_dir});
    try platform.writeFilePrivate(platform.Str.from(mock_file), platform.Bytes.from("{\"mocked\":true,\"v\":1}"));

    // Mutual exclusion rejected.
    const both = try h.tool("mock_network", try std.fmt.allocPrint(
        a,
        "{{\"pageId\":1,\"route\":\"*://*:*/data.json\",\"body\":{f},\"upstream\":\"{s}data.json\"}}",
        .{ std.json.fmt(mock_file, .{}), root },
    ));
    try testing.expect(both.is_error);
    try testing.expect(std.mem.indexOf(u8, both.text, "mutually exclusive") != null);

    // Invalid route rejected.
    const bad_route = try h.tool("mock_network", try std.fmt.allocPrint(
        a,
        "{{\"pageId\":1,\"route\":\"/relative.json\",\"body\":{f}}}",
        .{std.json.fmt(mock_file, .{})},
    ));
    try testing.expect(bad_route.is_error);
    try testing.expect(std.mem.indexOf(u8, bad_route.text, "Invalid route") != null);

    // Configure file mock for data.json.
    const cfg = try h.tool("mock_network", try std.fmt.allocPrint(
        a,
        "{{\"pageId\":1,\"route\":\"*://*:*/data.json\",\"body\":{f}}}",
        .{std.json.fmt(mock_file, .{})},
    ));
    try testing.expect(!cfg.is_error);
    try testing.expect(std.mem.indexOf(u8, cfg.text, "Network mock configured. Reload or navigate the page to apply it.") != null);
    try testing.expect(std.mem.indexOf(u8, cfg.text, "application/json; charset=utf-8") != null);
    try testing.expect(std.mem.indexOf(u8, cfg.text, "Since configured: 0 hits, 0 errors.") != null);

    // Navigate to site root and fetch /data.json: receives mocked file content!
    const nav = try h.tool("navigate_page", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"url\":\"{s}\"}}", .{root}));
    try testing.expect(!nav.is_error);
    const f1 = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"async () => await (await fetch('/data.json')).json()\"}");
    try testing.expect(!f1.is_error);
    try testing.expect(std.mem.indexOf(u8, f1.text, "\"mocked\":true") != null);
    try testing.expect(std.mem.indexOf(u8, f1.text, "\"v\":1") != null);

    // Re-read on every request: update file to v=2 and fetch again.
    try platform.writeFilePrivate(platform.Str.from(mock_file), platform.Bytes.from("{\"mocked\":true,\"v\":2}"));
    const f2 = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"async () => await (await fetch('/data.json')).json()\"}");
    try testing.expect(!f2.is_error);
    try testing.expect(std.mem.indexOf(u8, f2.text, "\"v\":2") != null);

    // Inspect diagnostics: 2 hits, 0 errors.
    const insp = try h.tool("mock_network", "{\"pageId\":1,\"route\":\"*://*:*/data.json\"}");
    try testing.expect(!insp.is_error);
    try testing.expect(std.mem.indexOf(u8, insp.text, "Since configured: 2 hits, 0 errors.") != null);

    // Configure an upstream mock redirecting /missing to /data.json (real server).
    const up_cfg = try h.tool("mock_network", try std.fmt.allocPrint(
        a,
        "{{\"pageId\":1,\"route\":\"*://*:*/missing\",\"upstream\":\"{s}data.json\"}}",
        .{root},
    ));
    try testing.expect(!up_cfg.is_error);
    const f3 = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"async () => ({ status: (await fetch('/missing')).status, body: await (await fetch('/missing')).text() })\"}");
    try testing.expect(!f3.is_error);
    try testing.expect(std.mem.indexOf(u8, f3.text, "\"status\":200") != null);

    // Remove one mock by exact route, then remove remaining all mocks.
    const rem1 = try h.tool("remove_network_mock", "{\"pageId\":1,\"route\":\"*://*:*/data.json\"}");
    try testing.expect(!rem1.is_error);
    try testing.expectEqualStrings("Removed 1 network mock.", rem1.text);
    const rem_rest = try h.tool("remove_network_mock", "{\"pageId\":1}");
    try testing.expect(!rem_rest.is_error);
    try testing.expectEqualStrings("Removed 1 network mock.", rem_rest.text);
    try testing.expect(!h.mcp_server.session.pages.items[0].network_mocks.active);
    try testing.expect(!h.mcp_server.session.pages.items[0].network_mocks.cache_disabled);

    // After removal, /missing returns real 404 again.
    const f4 = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"async () => (await fetch('/missing')).status\"}");
    try testing.expect(!f4.is_error);
    try testing.expect(std.mem.indexOf(u8, f4.text, "404") != null);
}

test "list_3p_developer_tools and execute_3p_developer_tool: discovery, HTMLElement uid in/out, validation, edge values" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const a = h.arena.allocator();
    try configureOptions(&h, .{ .category_experimental_third_party = true }, null);

    // Page without devtoolstooldiscovery listener.
    const nav0 = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"data:text/html,<button id=b>ClickMe</button>\"}");
    try testing.expect(!nav0.is_error);
    const empty_list = try h.tool("list_3p_developer_tools", "{\"pageId\":1}");
    try testing.expect(!empty_list.is_error);
    try testing.expectEqualStrings("## Third-party developer tools\nNo third-party developer tools available.", empty_list.text);

    // Register a devtoolstooldiscovery listener via evaluate_script.
    const reg = try h.tool("evaluate_script",
        \\{"pageId":1,"function":"() => { window.addEventListener('devtoolstooldiscovery', (e) => { e.respondWith({ name: 'DemoFramework', description: 'Demo tools', tools: [{ name: 'inspect_el', description: 'Inspect an element', inputSchema: { type: 'object', properties: { target: { type: 'object', 'x-mcp-type': 'HTMLElement' } }, required: ['target'] }, execute: (args) => ({ tag: args.target.tagName, self: args.target, fn: () => {}, sym: Symbol('s'), big: 9n }) }, { name: 'noop', description: 'Returns nothing', inputSchema: { type: 'object', properties: {} }, execute: () => undefined }] }); }); return 'registered'; }"}
    );
    try testing.expect(!reg.is_error);

    const listed = try h.tool("list_3p_developer_tools", "{\"pageId\":1}");
    try testing.expect(!listed.is_error);
    try testing.expect(std.mem.indexOf(u8, listed.text, "## Third-party developer tools") != null);
    try testing.expect(std.mem.indexOf(u8, listed.text, "DemoFramework: Demo tools") != null);
    try testing.expect(std.mem.indexOf(u8, listed.text, "name=\"inspect_el\"") != null);
    // x-mcp-type: HTMLElement schema rewritten to require { uid: string }.
    try testing.expect(std.mem.indexOf(u8, listed.text, "\"uid\":{\"type\":\"string\"}") != null);

    // Take snapshot to get button uid.
    const snap = try h.tool("take_snapshot", "{\"pageId\":1}");
    try testing.expect(!snap.is_error);
    const btn_uid = blk: {
        var lines = std.mem.splitScalar(u8, snap.text, '\n');
        while (lines.next()) |line| {
            if (std.mem.indexOf(u8, line, "button \"ClickMe\"") != null) {
                const start = std.mem.indexOf(u8, line, "uid=").? + 4;
                const end = std.mem.indexOfScalarPos(u8, line, start, ' ').?;
                break :blk line[start..end];
            }
        }
        return error.ButtonUidNotFound;
    };

    // Execute inspect_el passing { target: { uid } } -> receives DOM element, returns stashed element as { uid } + refreshed snapshot!
    const exec_params = try std.fmt.allocPrint(a, "{{\"target\":{{\"uid\":\"{s}\"}}}}", .{btn_uid});
    const exec = try h.tool("execute_3p_developer_tool", try std.fmt.allocPrint(
        a,
        "{{\"pageId\":1,\"toolName\":\"inspect_el\",\"params\":{f}}}",
        .{std.json.fmt(exec_params, .{})},
    ));
    try testing.expect(!exec.is_error);
    try testing.expect(std.mem.indexOf(u8, exec.text, "\"tag\": \"BUTTON\"") != null);
    try testing.expect(std.mem.indexOf(u8, exec.text, "\"uid\":") != null);
    try testing.expect(std.mem.indexOf(u8, exec.text, "\"<Function object>\"") != null);
    try testing.expect(std.mem.indexOf(u8, exec.text, "\"Symbol(s)\"") != null);
    try testing.expect(std.mem.indexOf(u8, exec.text, "\"9n\"") != null);
    try testing.expect(std.mem.indexOf(u8, exec.text, "## Latest page snapshot") != null);

    // Void tool returns "Tool returned no result."
    const noop = try h.tool("execute_3p_developer_tool", "{\"pageId\":1,\"toolName\":\"noop\"}");
    try testing.expect(!noop.is_error);
    try testing.expectEqualStrings("Tool returned no result.", noop.text);

    // Unknown tool fails cleanly.
    const missing = try h.tool("execute_3p_developer_tool", "{\"pageId\":1,\"toolName\":\"does_not_exist\"}");
    try testing.expect(missing.is_error);
    try testing.expect(std.mem.indexOf(u8, missing.text, "Tool does_not_exist not found") != null);

    // Invalid params fail schema validation.
    const invalid = try h.tool("execute_3p_developer_tool", "{\"pageId\":1,\"toolName\":\"inspect_el\",\"params\":\"{}\"}");
    try testing.expect(invalid.is_error);
    try testing.expect(std.mem.indexOf(u8, invalid.text, "Invalid parameters for tool inspect_el") != null);
}

test "console stack trace resolves Source Map V3 locations and skips ignoreList frames" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const a = h.arena.allocator();

    // Source map mapping:
    // gen line 0 -> vendor.js (ignoreList: [0]) line 9 col 0 (1-based 10:1)
    // gen line 1 -> src/app.ts line 41 col 4 (1-based 42:5)
    // gen line 2 -> src/app.ts line 99 col 0 (1-based 100:1)
    const map_json =
        \\{"version":3,"sources":["vendor.js","src/app.ts"],"ignoreList":[0],"names":[],"mappings":"AASA;ACgCI;AA0DJ"}
    ;
    const b64_len = std.base64.standard.Encoder.calcSize(map_json.len);
    const b64 = try a.alloc(u8, b64_len);
    _ = std.base64.standard.Encoder.encode(b64, map_json);

    // Percent-encode `#` as `%23` so data: URL does not treat `//#` as a fragment.
    const js = try std.fmt.allocPrint(
        a,
        "function lib(){{ console.error('mapped-err'); }}\nfunction app(){{ lib(); }}\napp();\n//%23 sourceURL=http://example.test/bundle.js\n//%23 sourceMappingURL=data:application/json;base64,{s}\n",
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
