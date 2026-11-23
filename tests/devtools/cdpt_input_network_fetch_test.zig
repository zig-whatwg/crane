//! Input, Network and Fetch on page sessions (CDP part 1 phase P5; lane
//! cdpt): trusted key events and text insertion through user_input; mouse
//! events per decision D7; Network events from the Browser's fetch
//! observer; Fetch interception's pause, fulfil, continue and fail.
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
        var params_buffer: [128]u8 = undefined;
        // The tab's page target, from the registry.
        const targets = try client.call("Target.getTargets", "{}", "");
        defer targets.deinit();
        const infos = cdp.at(targets.value, "result.targetInfos").?.array.items;
        if (infos.len == 0) return error.NoTarget;
        const page_id = cdp.stringAt(infos[infos.len - 1], "targetId").?;
        const attached = try client.call("Target.attachToTarget", try std.fmt.bufPrint(&params_buffer, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{page_id}), "");
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

    fn call(self: *Page, method: []const u8, params: []const u8) !std.json.Parsed(std.json.Value) {
        return self.client.call(method, params, self.session);
    }
};

test "Input.insertText puts text into the focused text control with beforeinput and input" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator(), "data:text/html,<input id=i><script>window.seen=[];i.addEventListener('beforeinput',e=>seen.push(e.inputType+':'+e.isTrusted));i.addEventListener('input',e=>seen.push('input'))</script>");
    defer page.close();
    gpa.allocator().free(try page.evaluate("i.focus()"));
    const inserted = try page.call("Input.insertText", "{\"text\":\"hello\"}");
    inserted.deinit();
    const value = try page.evaluate("i.value + '|' + seen.join(',')");
    defer gpa.allocator().free(value);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"hello|insertText:true,input\"}", value);
}

test "Input.dispatchKeyEvent: a trusted keydown with its text types it; keyUp follows" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator(), "data:text/html,<input id=i><script>window.keys=[];for(const t of ['keydown','keypress','keyup'])i.addEventListener(t,e=>keys.push(t+':'+e.key+':'+e.isTrusted))</script>");
    defer page.close();
    gpa.allocator().free(try page.evaluate("i.focus()"));
    const down = try page.call("Input.dispatchKeyEvent", "{\"type\":\"keyDown\",\"key\":\"a\",\"code\":\"KeyA\",\"text\":\"a\",\"windowsVirtualKeyCode\":65}");
    down.deinit();
    const up = try page.call("Input.dispatchKeyEvent", "{\"type\":\"keyUp\",\"key\":\"a\",\"code\":\"KeyA\",\"windowsVirtualKeyCode\":65}");
    up.deinit();
    const result = try page.evaluate("i.value + '|' + keys.join(',')");
    defer gpa.allocator().free(result);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"a|keydown:a:true,keypress:a:true,keyup:a:true\"}", result);
}

test "Input.dispatchMouseEvent: with no renderer nothing is hit (decision D7) - the testing platform's stand-in is the root element" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator(), "data:text/html,<script>window.clicks=0;document.addEventListener('click',e=>{if(e.isTrusted)clicks++})</script>");
    defer page.close();
    for ([_][]const u8{ "mouseMoved", "mousePressed", "mouseReleased" }) |kind| {
        var buffer: [128]u8 = undefined;
        const r = try page.call("Input.dispatchMouseEvent", try std.fmt.bufPrint(&buffer, "{{\"type\":\"{s}\",\"x\":10,\"y\":10,\"button\":\"left\",\"clickCount\":1}}", .{kind}));
        defer r.deinit();
        try testing.expect(cdp.at(r.value, "result") != null);
    }
    const clicks = try page.evaluate("clicks");
    defer gpa.allocator().free(clicks);
    const expected = if (comptime std.mem.eql(u8, platform.name, "testing")) "{\"type\":\"number\",\"value\":1}" else "{\"type\":\"number\",\"value\":0}";
    try testing.expectEqualStrings(expected, clicks);
}

test "Network: a page's fetch reports requestWillBeSent, responseReceived and loadingFinished with one requestId" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator(), "data:text/html,<p>x");
    defer page.close();
    const enabled = try page.call("Network.enable", "{}");
    enabled.deinit();
    gpa.allocator().free(try page.evaluate("fetch('data:text/plain,hello').then(r => r.text())"));
    const sent = try page.client.waitEvent("Network.requestWillBeSent");
    defer sent.deinit();
    try testing.expectEqualStrings("data:text/plain,hello", cdp.stringAt(sent.value, "params.request.url").?);
    // Chrome 157 types a fetch() of a data: URL "Other" (lane tpw's CDP
    // probe, tmp/plans/tpw-evidence/netprobe-chrome157.txt).
    try testing.expectEqualStrings("Other", cdp.stringAt(sent.value, "params.type").?);
    const id = cdp.stringAt(sent.value, "params.requestId").?;
    const received = try page.client.waitEvent("Network.responseReceived");
    defer received.deinit();
    try testing.expectEqualStrings(id, cdp.stringAt(received.value, "params.requestId").?);
    try testing.expectEqual(@as(i64, 200), cdp.at(received.value, "params.response.status").?.integer);
    const finished = try page.client.waitEvent("Network.loadingFinished");
    defer finished.deinit();
    try testing.expectEqualStrings(id, cdp.stringAt(finished.value, "params.requestId").?);
}

test "Fetch: a request the patterns match pauses before the network; fulfillRequest answers it" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator(), "data:text/html,<p>x");
    defer page.close();
    const enabled = try page.call("Fetch.enable", "{\"patterns\":[{\"urlPattern\":\"http://127.0.0.1:39/*\"}]}");
    enabled.deinit();
    // Port 39 answers nothing here: only the interception can. (Not port 9:
    // a bad port - Fetch 2.10 "port blocking", main fetch step 7 - is a
    // network error before any interception, as in Chrome: the request never
    // paused, and the test waited for good.)
    gpa.allocator().free(try page.evaluate("window.answer = fetch('http://127.0.0.1:39/x').then(r => r.status + ':' + r.headers.get('x-crane') + ':' + r.text()); 0"));
    const paused = try page.client.waitEvent("Fetch.requestPaused");
    defer paused.deinit();
    try testing.expectEqualStrings("http://127.0.0.1:39/x", cdp.stringAt(paused.value, "params.request.url").?);
    const id = cdp.stringAt(paused.value, "params.requestId").?;
    try testing.expect(std.mem.startsWith(u8, id, "interception-job-"));
    var params_buffer: [256]u8 = undefined;
    // body: base64("hi"). The page is a data: document - an opaque origin -
    // so its fetch is cross-origin, and a fulfilled response is held to CORS
    // as any other (Chrome too: the renderer checks what the interceptor
    // answered): without Access-Control-Allow-Origin the fetch failed, and
    // x-crane is read only when exposed.
    const fulfilled = try page.call("Fetch.fulfillRequest", try std.fmt.bufPrint(&params_buffer, "{{\"requestId\":\"{s}\",\"responseCode\":201,\"responseHeaders\":[{{\"name\":\"x-crane\",\"value\":\"yes\"}},{{\"name\":\"Access-Control-Allow-Origin\",\"value\":\"*\"}},{{\"name\":\"Access-Control-Expose-Headers\",\"value\":\"x-crane\"}}],\"body\":\"aGk=\"}}", .{id}));
    defer fulfilled.deinit();
    try testing.expect(cdp.at(fulfilled.value, "result") != null);
    const answer = try page.evaluate("window.answer.then(async s => s)");
    defer gpa.allocator().free(answer);
    try testing.expect(std.mem.indexOf(u8, answer, "201:yes") != null);

    // An id nothing holds: Chrome's message.
    const again = try page.call("Fetch.failRequest", try std.fmt.bufPrint(&params_buffer, "{{\"requestId\":\"{s}\",\"errorReason\":\"Failed\"}}", .{id}));
    defer again.deinit();
    try testing.expectEqualStrings("Invalid InterceptionId.", cdp.stringAt(again.value, "error.message").?);
}

test "Fetch.failRequest makes the page's fetch reject with a network error" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator(), "data:text/html,<p>x");
    defer page.close();
    const enabled = try page.call("Fetch.enable", "{}");
    enabled.deinit();
    gpa.allocator().free(try page.evaluate("window.answer = fetch('http://127.0.0.1:39/y').then(() => 'resolved', e => e.name); 0"));
    const paused = try page.client.waitEvent("Fetch.requestPaused");
    defer paused.deinit();
    var params_buffer: [160]u8 = undefined;
    const failed = try page.call("Fetch.failRequest", try std.fmt.bufPrint(&params_buffer, "{{\"requestId\":\"{s}\",\"errorReason\":\"ConnectionRefused\"}}", .{cdp.stringAt(paused.value, "params.requestId").?}));
    failed.deinit();
    const answer = try page.evaluate("window.answer");
    defer gpa.allocator().free(answer);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"TypeError\"}", answer);
}
