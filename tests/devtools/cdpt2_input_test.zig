//! Input.dispatchMouseEvent's clickCount and mouseWheel (lane cdpt2; CDP
//! part 1 gap 3), as Chrome's InputHandler makes them (content/browser/
//! devtools/protocol/input_handler.cc): a press's clickCount is the events'
//! detail, 2 adds a dblclick, 0 (the default) makes no click; mouseWheel is
//! one wheel event with CDP's deltas in DOM_DELTA_PIXEL, and needs both
//! deltas. Decision D7: with no renderer nothing is at any point, so only
//! the testing platform's stand-in (the root element) receives events.
//!
//! Written in the CDP phase (user directive 2026-11-21 5:48 PM ET: implement
//! now, run every test in one later pass).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const devtools = @import("devtools");
const platform = @import("platform");
const cdp = @import("cdp_client.zig");

const BrowserHost = browser_mod.BrowserHost;
const Browser = browser_mod.Browser;
const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });

const on_testing_platform = std.mem.eql(u8, platform.name, "testing");

const Page = struct {
    host: *BrowserHost,
    tab: Browser.TabId,
    server: *devtools.Server,
    client: *cdp.Client,
    session: []u8,
    allocator: std.mem.Allocator,

    fn open(allocator: std.mem.Allocator, url: []const u8) !Page {
        const host = try BrowserHost.start(allocator, .{});
        errdefer host.stop();
        const tab = try host.createTab(.{});
        const loaded = try host.navigate(allocator, tab, url, .{ .wait = .complete, .timeout_ms = 10_000 });
        allocator.free(loaded);
        const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
        errdefer server.stop();
        var path_buffer: [96]u8 = undefined;
        const client = try cdp.Client.openWebSocket(allocator, server.port, try std.fmt.bufPrint(&path_buffer, "/devtools/browser/{s}", .{server.browser_id.slice()}), null);
        errdefer client.close();
        const targets = try client.call("Target.getTargets", "{}", "");
        defer targets.deinit();
        const infos = cdp.at(targets.value, "result.targetInfos").?.array.items;
        if (infos.len == 0) return error.NoTarget;
        var params_buffer: [128]u8 = undefined;
        const attached = try client.call("Target.attachToTarget", try std.fmt.bufPrint(&params_buffer, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{cdp.stringAt(infos[infos.len - 1], "targetId").?}), "");
        defer attached.deinit();
        const session = try allocator.dupe(u8, cdp.stringAt(attached.value, "result.sessionId").?);
        return .{ .host = host, .tab = tab, .server = server, .client = client, .session = session, .allocator = allocator };
    }

    fn close(self: *Page) void {
        self.allocator.free(self.session);
        self.client.close();
        self.server.stop();
        self.host.stop();
    }

    fn evaluate(self: *Page, source: []const u8) ![]u8 {
        const result = try self.host.evaluate(self.allocator, self.tab, source, .{ .await_promise = true }, 10_000);
        defer result.deinit(self.allocator);
        return self.allocator.dupe(u8, result.json);
    }

    fn mouse(self: *Page, params: []const u8) !void {
        const r = try self.client.call("Input.dispatchMouseEvent", params, self.session);
        defer r.deinit();
        if (cdp.at(r.value, "result") == null) return error.CommandFailed;
    }
};

const log_page = "data:text/html,<script>window.seen=[];for(const t of ['mousedown','mouseup','click','dblclick','wheel'])document.addEventListener(t,e=>seen.push(t+':'+e.detail+(t==='wheel'?':'+e.deltaX+':'+e.deltaY+':'+e.deltaMode:'')))</script>";

test "Input.dispatchMouseEvent: clickCount is the detail; a second press of count 2 adds a dblclick (Puppeteer's click({count: 2}))" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator(), log_page);
    defer page.close();
    try page.mouse("{\"type\":\"mouseMoved\",\"x\":5,\"y\":5}");
    for ([_][]const u8{ "1", "2" }) |count| {
        var buffer: [160]u8 = undefined;
        try page.mouse(try std.fmt.bufPrint(&buffer, "{{\"type\":\"mousePressed\",\"x\":5,\"y\":5,\"button\":\"left\",\"buttons\":1,\"clickCount\":{s}}}", .{count}));
        try page.mouse(try std.fmt.bufPrint(&buffer, "{{\"type\":\"mouseReleased\",\"x\":5,\"y\":5,\"button\":\"left\",\"clickCount\":{s}}}", .{count}));
    }
    const seen = try page.evaluate("seen.join(',')");
    defer gpa.allocator().free(seen);
    const expected = if (on_testing_platform)
        "{\"type\":\"string\",\"value\":\"mousedown:1,mouseup:1,click:1,mousedown:2,mouseup:2,click:2,dblclick:2\"}"
    else
        "{\"type\":\"string\",\"value\":\"\"}";
    try testing.expectEqualStrings(expected, seen);
}

test "Input.dispatchMouseEvent: a press without clickCount (0) makes no click" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator(), log_page);
    defer page.close();
    try page.mouse("{\"type\":\"mousePressed\",\"x\":5,\"y\":5,\"button\":\"left\"}");
    try page.mouse("{\"type\":\"mouseReleased\",\"x\":5,\"y\":5,\"button\":\"left\"}");
    const seen = try page.evaluate("seen.join(',')");
    defer gpa.allocator().free(seen);
    const expected = if (on_testing_platform) "{\"type\":\"string\",\"value\":\"mousedown:0,mouseup:0\"}" else "{\"type\":\"string\",\"value\":\"\"}";
    try testing.expectEqualStrings(expected, seen);
}

test "Input.dispatchMouseEvent mouseWheel: one wheel event with CDP's deltas, DOM_DELTA_PIXEL" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator(), log_page);
    defer page.close();
    try page.mouse("{\"type\":\"mouseWheel\",\"x\":5,\"y\":5,\"deltaX\":0,\"deltaY\":100}");
    const seen = try page.evaluate("seen.join(',')");
    defer gpa.allocator().free(seen);
    const expected = if (on_testing_platform) "{\"type\":\"string\",\"value\":\"wheel:0:0:100:0\"}" else "{\"type\":\"string\",\"value\":\"\"}";
    try testing.expectEqualStrings(expected, seen);
}

test "Input.dispatchMouseEvent: Chrome's parameter errors - a wheel without both deltas, a force out of range" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator(), "data:text/html,<p>x");
    defer page.close();
    const no_delta = try page.client.call("Input.dispatchMouseEvent", "{\"type\":\"mouseWheel\",\"x\":5,\"y\":5,\"deltaY\":3}", page.session);
    defer no_delta.deinit();
    try testing.expectEqualStrings("'deltaX' and 'deltaY' are expected for mouseWheel event", cdp.stringAt(no_delta.value, "error.message").?);
    try testing.expectEqual(@as(i64, -32602), cdp.at(no_delta.value, "error.code").?.integer);
    const force = try page.client.call("Input.dispatchMouseEvent", "{\"type\":\"mouseMoved\",\"x\":5,\"y\":5,\"force\":2}", page.session);
    defer force.deinit();
    try testing.expectEqualStrings("'force' should be in the range of [0,1]", cdp.stringAt(force.value, "error.message").?);
}
