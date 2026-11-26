//! Lane mcp2, batch 4b item 6: CDP Emulation.setCPUThrottlingRate and MCP
//! `emulate { cpuThrottlingRate }` (Chrome 157 / chrome-devtools-mcp v1.13.0).

const std = @import("std");
const testing = std.testing;
const Harness = @import("mcp1_harness.zig").Harness;
const replay = @import("cdpr_replay.zig");
const cdp = @import("cdp_client.zig");
const browser_mod = @import("browser");
const devtools = @import("devtools");

const BrowserHost = browser_mod.BrowserHost;
const Browser = browser_mod.Browser;
const LeakChecked = replay.LeakChecked;

const CdpPage = struct {
    host: *BrowserHost,
    tab: Browser.TabId,
    server: *devtools.Server,
    client: *cdp.Client,
    target_id: []u8,
    session: []u8,
    allocator: std.mem.Allocator,

    fn open(allocator: std.mem.Allocator, url: []const u8) !CdpPage {
        const host = try BrowserHost.start(allocator, .{});
        errdefer host.stop();
        const tab = try host.createTab(.{});
        const loaded = try host.navigate(allocator, tab, url, .{ .wait = .complete, .timeout_ms = 10_000 });
        allocator.free(loaded);
        const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
        errdefer server.stop();
        var path_buf: [96]u8 = undefined;
        const client = try cdp.Client.openWebSocket(allocator, server.port, try std.fmt.bufPrint(&path_buf, "/devtools/browser/{s}", .{server.browser_id.slice()}), null);
        errdefer client.close();
        var targets = try client.call("Target.getTargets", "{}", "");
        defer targets.deinit();
        const infos = cdp.at(targets.value, "result.targetInfos").?.array.items;
        if (infos.len == 0) return error.NoTarget;
        const target_id = try allocator.dupe(u8, cdp.stringAt(infos[infos.len - 1], "targetId").?);
        errdefer allocator.free(target_id);
        var params_buf: [128]u8 = undefined;
        var attached = try client.call("Target.attachToTarget", try std.fmt.bufPrint(&params_buf, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{target_id}), "");
        defer attached.deinit();
        const session = try allocator.dupe(u8, cdp.stringAt(attached.value, "result.sessionId").?);
        return .{ .host = host, .tab = tab, .server = server, .client = client, .target_id = target_id, .session = session, .allocator = allocator };
    }

    fn close(self: *CdpPage) void {
        self.allocator.free(self.session);
        self.allocator.free(self.target_id);
        self.client.close();
        self.server.stop();
        self.host.stop();
    }

    fn evalNumber(self: *CdpPage, expr: []const u8) !f64 {
        const params = try std.fmt.allocPrint(self.allocator, "{{\"expression\":{f},\"awaitPromise\":true,\"returnByValue\":true}}", .{std.json.fmt(expr, .{})});
        defer self.allocator.free(params);
        var resp = try self.client.call("Runtime.evaluate", params, self.session);
        defer resp.deinit();
        if (cdp.at(resp.value, "error") != null) return error.EvalError;
        if (cdp.at(resp.value, "result.exceptionDetails") != null) return error.EvalException;
        const val = cdp.at(resp.value, "result.result.value") orelse return error.NoValue;
        return switch (val) {
            .float => |f| f,
            .integer => |i| @floatFromInt(i),
            else => error.UnexpectedType,
        };
    }
};

/// Async JS workload: 5 sequential macrotasks each burning 6 ms of CPU
/// (~30 ms total work). At 4x slowdown wall time is ~120 ms; at 1x ~30 ms.
const busy_tasks_expr =
    \\(async () => {
    \\  const start = performance.now();
    \\  for (let i = 0; i < 5; i++) {
    \\    await new Promise(resolve => setTimeout(() => {
    \\      const t = performance.now();
    \\      while (performance.now() - t < 6) {}
    \\      resolve();
    \\    }, 0));
    \\  }
    \\  return performance.now() - start;
    \\})()
;

fn parseScriptNumber(text: []const u8) !f64 {
    const start_marker = "```json\n";
    const start = (std.mem.indexOf(u8, text, start_marker) orelse return error.InvalidFormat) + start_marker.len;
    const rest = text[start..];
    const end = std.mem.indexOf(u8, rest, "\n```") orelse return error.InvalidFormat;
    return std.fmt.parseFloat(f64, std.mem.trim(u8, rest[0..end], " \t\r\n"));
}

test "CDP Emulation.setCPUThrottlingRate throttles tasks, persists across navigation, handles rate<=1, and cleans up on detach" {
    var gpa = LeakChecked.init;
    defer testing.expectEqual(.ok, gpa.deinit()) catch {};
    const allocator = gpa.allocator();

    var page = try CdpPage.open(allocator, "data:text/html,<title>CPU1</title>");
    defer page.close();

    var r = try page.client.call("Runtime.enable", "{}", page.session);
    r.deinit();

    // Baseline unthrottled (rate 1): ~30 ms of work.
    const base_ms = try page.evalNumber(busy_tasks_expr);
    try testing.expect(base_ms >= 20.0);

    // Rate <= 1 (0, -2, 0.5, 1) succeeds and disables throttling (matching Blink).
    for ([_][]const u8{ "{\"rate\":0}", "{\"rate\":-2}", "{\"rate\":0.5}", "{\"rate\":1}" }) |p| {
        var resp = try page.client.call("Emulation.setCPUThrottlingRate", p, page.session);
        defer resp.deinit();
        try testing.expect(cdp.at(resp.value, "error") == null);
    }

    // Enable 4x CPU throttling: ~30 ms work -> ~120 ms wall time.
    var set4 = try page.client.call("Emulation.setCPUThrottlingRate", "{\"rate\":4}", page.session);
    defer set4.deinit();
    try testing.expect(cdp.at(set4.value, "error") == null);

    const throttled_ms = try page.evalNumber(busy_tasks_expr);
    try testing.expect(throttled_ms >= 95.0);
    try testing.expect(throttled_ms >= base_ms * 2.0);

    // Persists across navigation within the same session.
    const loaded2 = try page.host.navigate(allocator, page.tab, "data:text/html,<title>CPU2</title>", .{ .wait = .complete, .timeout_ms = 10_000 });
    allocator.free(loaded2);
    const after_nav_ms = try page.evalNumber(busy_tasks_expr);
    try testing.expect(after_nav_ms >= 95.0);

    // Attach a second untouched session and detach it: must NOT clear session 1's throttle.
    var params_buf: [128]u8 = undefined;
    var attached2 = try page.client.call("Target.attachToTarget", try std.fmt.bufPrint(&params_buf, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{page.target_id}), "");
    defer attached2.deinit();
    const session2 = cdp.stringAt(attached2.value, "result.sessionId").?;
    var detached2 = try page.client.call("Target.detachFromTarget", try std.fmt.bufPrint(&params_buf, "{{\"sessionId\":\"{s}\"}}", .{session2}), "");
    defer detached2.deinit();

    const after_sibling_detach_ms = try page.evalNumber(busy_tasks_expr);
    try testing.expect(after_sibling_detach_ms >= 95.0);

    // Disable with rate 1: back to unthrottled.
    var set1 = try page.client.call("Emulation.setCPUThrottlingRate", "{\"rate\":1}", page.session);
    defer set1.deinit();
    try testing.expect(cdp.at(set1.value, "error") == null);

    const restored_ms = try page.evalNumber(busy_tasks_expr);
    try testing.expect(restored_ms < throttled_ms * 0.75);

    // Detaching the throttling session restores rate to 1.0 on a new session.
    var set4_again = try page.client.call("Emulation.setCPUThrottlingRate", "{\"rate\":4}", page.session);
    set4_again.deinit();
    var detached1 = try page.client.call("Target.detachFromTarget", try std.fmt.bufPrint(&params_buf, "{{\"sessionId\":\"{s}\"}}", .{page.session}), "");
    detached1.deinit();
    var attached3 = try page.client.call("Target.attachToTarget", try std.fmt.bufPrint(&params_buf, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{page.target_id}), "");
    defer attached3.deinit();
    allocator.free(page.session);
    page.session = try allocator.dupe(u8, cdp.stringAt(attached3.value, "result.sessionId").?);
    var re_enable = try page.client.call("Runtime.enable", "{}", page.session);
    re_enable.deinit();

    const after_owner_detach_ms = try page.evalNumber(busy_tasks_expr);
    try testing.expect(after_owner_detach_ms < throttled_ms * 0.75);
}

test "MCP emulate cpuThrottlingRate formats output, scales timeout, persists across navigation, and resets on 1 or omission" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();

    var r = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"data:text/html,<title>MCPCPU</title>\"}");
    try testing.expect(!r.is_error);

    // Validation bounds from chrome-devtools-mcp schema (1..20).
    r = try h.tool("emulate", "{\"pageId\":1,\"cpuThrottlingRate\":0.5}");
    try testing.expect(r.is_error);
    try testing.expectEqualStrings("Input validation error: Invalid arguments for tool emulate: cpuThrottlingRate: Too small: expected number to be >=1", r.text);

    r = try h.tool("emulate", "{\"pageId\":1,\"cpuThrottlingRate\":21}");
    try testing.expect(r.is_error);
    try testing.expectEqualStrings("Input validation error: Invalid arguments for tool emulate: cpuThrottlingRate: Too big: expected number to be <=20", r.text);

    // Set 4x throttling.
    r = try h.tool("emulate", "{\"pageId\":1,\"cpuThrottlingRate\":4}");
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings("Emulation configured successfully\nEmulating CPU throttling: 4x slowdown", r.text);

    // Page tool carries the emulation line.
    r = try h.tool("list_console_messages", "{\"pageId\":1}");
    try testing.expect(!r.is_error);
    try testing.expect(std.mem.indexOf(u8, r.text, "Emulating CPU throttling: 4x slowdown") != null);

    // Fractional rate formatting.
    r = try h.tool("emulate", "{\"pageId\":1,\"cpuThrottlingRate\":2.5}");
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings("Emulation configured successfully\nEmulating CPU throttling: 2.5x slowdown", r.text);

    // Combined with networkConditions + userAgent + colorScheme: exact order and timeout scaling.
    r = try h.tool("emulate", "{\"pageId\":1,\"networkConditions\":\"Slow 3G\",\"userAgent\":\"Agent/2\",\"cpuThrottlingRate\":4,\"colorScheme\":\"dark\"}");
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings(
        \\Emulation configured successfully
        \\Emulating network conditions: Slow 3G
        \\Default navigation timeout set to 400000 ms
        \\Emulating user agent: Agent/2
        \\Emulating CPU throttling: 4x slowdown
        \\Emulating color scheme: dark
    , r.text);

    // Persists across navigation and actually throttles JS tasks.
    r = try h.tool("emulate", "{\"pageId\":1,\"cpuThrottlingRate\":4}");
    try testing.expect(!r.is_error);
    r = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"data:text/html,<title>MCPCPU2</title>\"}");
    try testing.expect(!r.is_error);
    try testing.expect(std.mem.indexOf(u8, r.text, "Emulating CPU throttling: 4x slowdown") != null);

    const throttled_resp = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"async () => { const s = performance.now(); for (let i = 0; i < 5; i++) { await new Promise(r => setTimeout(() => { const t = performance.now(); while (performance.now() - t < 6) {} r(); }, 0)); } return performance.now() - s; }\"}");
    try testing.expect(!throttled_resp.is_error);
    const throttled_ms = try parseScriptNumber(throttled_resp.text);
    try testing.expect(throttled_ms >= 95.0);

    // Reset with rate 1 clears line and restores speed.
    r = try h.tool("emulate", "{\"pageId\":1,\"cpuThrottlingRate\":1}");
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings("Emulation configured successfully", r.text);

    const fast_resp = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"async () => { const s = performance.now(); for (let i = 0; i < 5; i++) { await new Promise(r => setTimeout(() => { const t = performance.now(); while (performance.now() - t < 6) {} r(); }, 0)); } return performance.now() - s; }\"}");
    try testing.expect(!fast_resp.is_error);
    const fast_ms = try parseScriptNumber(fast_resp.text);
    try testing.expect(fast_ms < throttled_ms * 0.75);

    // Set 4 again, then omit cpuThrottlingRate -> cleared.
    r = try h.tool("emulate", "{\"pageId\":1,\"cpuThrottlingRate\":4}");
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings("Emulation configured successfully\nEmulating CPU throttling: 4x slowdown", r.text);
    r = try h.tool("emulate", "{\"pageId\":1}");
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings("Emulation configured successfully", r.text);
}
