//! Fetch interception everywhere, kept bodies, ExtraInfo and auth (lane
//! cdpt2: CDP part 1 gaps 1 and 2, lane cdpr's G16 and G17), as Chrome's
//! DevToolsURLLoaderInterceptor, FetchHandler and Blink's NetworkResourcesData
//! give them:
//! - a synchronous XMLHttpRequest is held at the request stage, its page's
//!   thread waiting, and the devtools thread answers it;
//! - the response stage holds the network's answer: getResponseBody reads
//!   it (base64), continueResponse hands it on - with a new head, the body
//!   as it came - and fulfillRequest replaces it;
//! - Network.getResponseBody / getRequestPostData read what the session
//!   kept; requestWillBeSentExtraInfo carries the headers that went over the
//!   network, responseReceived says hasExtraInfo;
//! - handleAuthRequests: a 401's challenge is Fetch.authRequired, and
//!   continueWithAuth provides, cancels or defers.
//!
//! Written in the CDP phase (user directive 2026-11-21 5:48 PM ET: implement
//! now, run every test in one later pass).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const devtools = @import("devtools");
const cdp = @import("cdp_client.zig");
const site_mod = @import("cdpt2_site.zig");

const BrowserHost = browser_mod.BrowserHost;
const Browser = browser_mod.Browser;
const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });

const Page = struct {
    host: *BrowserHost,
    tab: Browser.TabId,
    server: *devtools.Server,
    client: *cdp.Client,
    session: []u8,
    site: *site_mod.Site,
    allocator: std.mem.Allocator,

    /// A tab on the site's page, a CDP session attached to it.
    fn open(allocator: std.mem.Allocator) !Page {
        const site = try site_mod.Site.start(allocator);
        errdefer site.stop();
        const host = try BrowserHost.start(allocator, .{});
        errdefer host.stop();
        const tab = try host.createTab(.{});
        var url_buffer: [96]u8 = undefined;
        const loaded = try host.navigate(allocator, tab, try site.url(&url_buffer, "/echo"), .{ .wait = .complete, .timeout_ms = 10_000 });
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
        return .{ .host = host, .tab = tab, .server = server, .client = client, .session = session, .site = site, .allocator = allocator };
    }

    fn close(self: *Page) void {
        self.allocator.free(self.session);
        self.client.close();
        self.server.stop();
        self.host.stop();
        self.site.stop();
    }

    fn url(self: *Page, buffer: []u8, path: []const u8) ![]const u8 {
        return self.site.url(buffer, path);
    }

    fn evaluate(self: *Page, source: []const u8) ![]u8 {
        const result = try self.host.evaluate(self.allocator, self.tab, source, .{ .await_promise = true }, 10_000);
        defer result.deinit(self.allocator);
        return self.allocator.dupe(u8, result.json);
    }

    fn call(self: *Page, method: []const u8, params: []const u8) !std.json.Parsed(std.json.Value) {
        return self.client.call(method, params, self.session);
    }

    fn ok(self: *Page, method: []const u8, params: []const u8) !void {
        const r = try self.call(method, params);
        defer r.deinit();
        if (cdp.at(r.value, "result") == null) {
            std.debug.print("{s} failed: {s}\n", .{ method, cdp.stringAt(r.value, "error.message") orelse "?" });
            return error.CommandFailed;
        }
    }
};

/// host.evaluate on a thread of its own: a synchronous XHR blocks the
/// Browser thread, and with it the evaluation, until the client answers.
const Evaluation = struct {
    page: *Page,
    source: []const u8,
    result: ?[]u8 = null,
    thread: ?std.Thread = null,

    fn start(self: *Evaluation) !void {
        self.thread = try std.Thread.spawn(.{}, run, .{self});
    }

    fn run(self: *Evaluation) void {
        self.result = self.page.evaluate(self.source) catch null;
    }

    fn join(self: *Evaluation) ?[]u8 {
        self.thread.?.join();
        return self.result;
    }
};

test "gap 1: a synchronous XMLHttpRequest is held at the request stage while its page waits, and fulfillRequest answers it from the devtools thread" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator());
    defer page.close();
    try page.ok("Fetch.enable", "{\"patterns\":[{\"urlPattern\":\"*data.json\"}]}");
    var url_buffer: [96]u8 = undefined;
    var source_buffer: [256]u8 = undefined;
    const source = try std.fmt.bufPrint(&source_buffer, "(() => {{ const x = new XMLHttpRequest(); x.open('GET', '{s}', false); x.send(); return x.status + ':' + x.responseText; }})()", .{try page.url(&url_buffer, "/data.json")});
    var evaluation: Evaluation = .{ .page = &page, .source = source };
    try evaluation.start();
    const paused = try page.client.waitEvent("Fetch.requestPaused");
    defer paused.deinit();
    try testing.expectEqualStrings("XHR", cdp.stringAt(paused.value, "params.resourceType").?);
    var params_buffer: [256]u8 = undefined;
    // body: base64("held")
    try page.ok("Fetch.fulfillRequest", try std.fmt.bufPrint(&params_buffer, "{{\"requestId\":\"{s}\",\"responseCode\":200,\"responseHeaders\":[{{\"name\":\"Content-Type\",\"value\":\"text/plain\"}}],\"body\":\"aGVsZA==\"}}", .{cdp.stringAt(paused.value, "params.requestId").?}));
    const result = evaluation.join() orelse return error.EvaluationFailed;
    defer gpa.allocator().free(result);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"200:held\"}", result);
}

test "gap 1: the response stage holds the network's answer; getResponseBody reads it (base64) and continueResponse hands it on" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator());
    defer page.close();
    try page.ok("Fetch.enable", "{\"patterns\":[{\"urlPattern\":\"*data.json\",\"requestStage\":\"Response\"}]}");
    var url_buffer: [96]u8 = undefined;
    var source_buffer: [256]u8 = undefined;
    gpa.allocator().free(try page.evaluate(try std.fmt.bufPrint(&source_buffer, "window.answer = fetch('{s}').then(r => r.status + ':' + r.headers.get('x-site') + ':' + r.headers.get('x-added')).then(async s => s); 0", .{try page.url(&url_buffer, "/data.json")})));
    const paused = try page.client.waitEvent("Fetch.requestPaused");
    defer paused.deinit();
    try testing.expectEqual(@as(i64, 200), cdp.at(paused.value, "params.responseStatusCode").?.integer);
    try testing.expectEqualStrings("OK", cdp.stringAt(paused.value, "params.responseStatusText").?);
    const id = cdp.stringAt(paused.value, "params.requestId").?;
    var params_buffer: [512]u8 = undefined;
    const body = try page.call("Fetch.getResponseBody", try std.fmt.bufPrint(&params_buffer, "{{\"requestId\":\"{s}\"}}", .{id}));
    defer body.deinit();
    try testing.expect(cdp.at(body.value, "result.base64Encoded").?.bool);
    var decoded: [64]u8 = undefined;
    const encoded = cdp.stringAt(body.value, "result.body").?;
    const size = try std.base64.standard.Decoder.calcSizeForSlice(encoded);
    try std.base64.standard.Decoder.decode(decoded[0..size], encoded);
    try testing.expectEqualStrings(site_mod.json_body, decoded[0..size]);
    // A new head, the original body (continueResponse with code + headers).
    try page.ok("Fetch.continueResponse", try std.fmt.bufPrint(&params_buffer, "{{\"requestId\":\"{s}\",\"responseCode\":203,\"responseHeaders\":[{{\"name\":\"X-Added\",\"value\":\"1\"}},{{\"name\":\"Content-Type\",\"value\":\"application/json\"}}]}}", .{id}));
    const answer = try page.evaluate("window.answer");
    defer gpa.allocator().free(answer);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"203:null:1\"}", answer);
}

test "gap 1: at the response stage fulfillRequest with a body replaces the answer, and continueResponse with only a code is refused" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator());
    defer page.close();
    try page.ok("Fetch.enable", "{\"patterns\":[{\"urlPattern\":\"*data.json\",\"requestStage\":\"Response\"}]}");
    var url_buffer: [96]u8 = undefined;
    var source_buffer: [256]u8 = undefined;
    gpa.allocator().free(try page.evaluate(try std.fmt.bufPrint(&source_buffer, "window.answer = fetch('{s}').then(r => r.text()); 0", .{try page.url(&url_buffer, "/data.json")})));
    const paused = try page.client.waitEvent("Fetch.requestPaused");
    defer paused.deinit();
    const id = cdp.stringAt(paused.value, "params.requestId").?;
    var params_buffer: [512]u8 = undefined;
    const refused = try page.call("Fetch.continueResponse", try std.fmt.bufPrint(&params_buffer, "{{\"requestId\":\"{s}\",\"responseCode\":201}}", .{id}));
    defer refused.deinit();
    try testing.expectEqualStrings("Cannot override only status or headers, both should be provided", cdp.stringAt(refused.value, "error.message").?);
    // body: base64("mocked")
    try page.ok("Fetch.fulfillRequest", try std.fmt.bufPrint(&params_buffer, "{{\"requestId\":\"{s}\",\"responseCode\":200,\"body\":\"bW9ja2Vk\"}}", .{id}));
    const answer = try page.evaluate("window.answer");
    defer gpa.allocator().free(answer);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"mocked\"}", answer);
}

test "gap 1: a synchronous XMLHttpRequest's response stage: getResponseBody reads the whole answer while the page waits" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator());
    defer page.close();
    try page.ok("Fetch.enable", "{\"patterns\":[{\"urlPattern\":\"*data.json\",\"requestStage\":\"Response\"}]}");
    var url_buffer: [96]u8 = undefined;
    var source_buffer: [256]u8 = undefined;
    const source = try std.fmt.bufPrint(&source_buffer, "(() => {{ const x = new XMLHttpRequest(); x.open('GET', '{s}', false); x.send(); return x.responseText; }})()", .{try page.url(&url_buffer, "/data.json")});
    var evaluation: Evaluation = .{ .page = &page, .source = source };
    try evaluation.start();
    const paused = try page.client.waitEvent("Fetch.requestPaused");
    defer paused.deinit();
    const id = cdp.stringAt(paused.value, "params.requestId").?;
    var params_buffer: [128]u8 = undefined;
    const body = try page.call("Fetch.getResponseBody", try std.fmt.bufPrint(&params_buffer, "{{\"requestId\":\"{s}\"}}", .{id}));
    defer body.deinit();
    try testing.expect(cdp.at(body.value, "result.body") != null);
    try page.ok("Fetch.continueRequest", try std.fmt.bufPrint(&params_buffer, "{{\"requestId\":\"{s}\"}}", .{id}));
    const result = evaluation.join() orelse return error.EvaluationFailed;
    defer gpa.allocator().free(result);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"{\\\"from\\\":\\\"network\\\"}\"}", result);
}

test "gap 1: detaching the session that holds a synchronous XMLHttpRequest lets it go (Chrome's interceptor Detach)" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator());
    defer page.close();
    try page.ok("Fetch.enable", "{\"patterns\":[{\"urlPattern\":\"*data.json\"}]}");
    var url_buffer: [96]u8 = undefined;
    var source_buffer: [256]u8 = undefined;
    const source = try std.fmt.bufPrint(&source_buffer, "(() => {{ const x = new XMLHttpRequest(); x.open('GET', '{s}', false); x.send(); return x.status; }})()", .{try page.url(&url_buffer, "/data.json")});
    var evaluation: Evaluation = .{ .page = &page, .source = source };
    try evaluation.start();
    const paused = try page.client.waitEvent("Fetch.requestPaused");
    paused.deinit();
    var params_buffer: [96]u8 = undefined;
    const detach = try page.client.call("Target.detachFromTarget", try std.fmt.bufPrint(&params_buffer, "{{\"sessionId\":\"{s}\"}}", .{page.session}), "");
    detach.deinit();
    const result = evaluation.join() orelse return error.EvaluationFailed;
    defer gpa.allocator().free(result);
    try testing.expectEqualStrings("{\"type\":\"number\",\"value\":200}", result);
}

test "gap 2: Network.getResponseBody reads the kept body - text for JSON, base64 for an image; getRequestPostData the POST's body" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator());
    defer page.close();
    try page.ok("Network.enable", "{}");
    var url_buffer: [96]u8 = undefined;
    var source_buffer: [256]u8 = undefined;
    const Case = struct { path: []const u8, base64: bool };
    for ([_]Case{ .{ .path = "/data.json", .base64 = false }, .{ .path = "/image.png", .base64 = true } }) |case| {
        gpa.allocator().free(try page.evaluate(try std.fmt.bufPrint(&source_buffer, "fetch('{s}').then(r => r.arrayBuffer()).then(b => b.byteLength)", .{try page.url(&url_buffer, case.path)})));
        const finished = try page.client.waitEvent("Network.loadingFinished");
        defer finished.deinit();
        var params_buffer: [128]u8 = undefined;
        const body = try page.call("Network.getResponseBody", try std.fmt.bufPrint(&params_buffer, "{{\"requestId\":\"{s}\"}}", .{cdp.stringAt(finished.value, "params.requestId").?}));
        defer body.deinit();
        try testing.expectEqual(case.base64, cdp.at(body.value, "result.base64Encoded").?.bool);
        if (!case.base64) try testing.expectEqualStrings(site_mod.json_body, cdp.stringAt(body.value, "result.body").?);
    }
    // A POST: its body as sent.
    gpa.allocator().free(try page.evaluate(try std.fmt.bufPrint(&source_buffer, "fetch('{s}', {{method: 'POST', body: 'a=1&b=2'}}).then(r => r.text())", .{try page.url(&url_buffer, "/echo")})));
    while (true) {
        const sent = try page.client.waitEvent("Network.requestWillBeSent");
        defer sent.deinit();
        if (!std.mem.eql(u8, cdp.stringAt(sent.value, "params.request.method").?, "POST")) continue;
        try testing.expect(cdp.at(sent.value, "params.request.hasPostData").?.bool);
        try testing.expectEqualStrings("a=1&b=2", cdp.stringAt(sent.value, "params.request.postData").?);
        var params_buffer: [128]u8 = undefined;
        const post = try page.call("Network.getRequestPostData", try std.fmt.bufPrint(&params_buffer, "{{\"requestId\":\"{s}\"}}", .{cdp.stringAt(sent.value, "params.requestId").?}));
        defer post.deinit();
        try testing.expectEqualStrings("a=1&b=2", cdp.stringAt(post.value, "result.postData").?);
        break;
    }
    // An id nothing kept: Blink's message.
    const unknown = try page.call("Network.getResponseBody", "{\"requestId\":\"1.999\"}");
    defer unknown.deinit();
    try testing.expectEqualStrings("No resource with given identifier found", cdp.stringAt(unknown.value, "error.message").?);
}

test "gap 2: past maxResourceBufferSize a body is evicted from the session's cache" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator());
    defer page.close();
    try page.ok("Network.enable", "{\"maxResourceBufferSize\":4}");
    var url_buffer: [96]u8 = undefined;
    var source_buffer: [256]u8 = undefined;
    gpa.allocator().free(try page.evaluate(try std.fmt.bufPrint(&source_buffer, "fetch('{s}').then(r => r.text())", .{try page.url(&url_buffer, "/data.json")})));
    const finished = try page.client.waitEvent("Network.loadingFinished");
    defer finished.deinit();
    var params_buffer: [128]u8 = undefined;
    const body = try page.call("Network.getResponseBody", try std.fmt.bufPrint(&params_buffer, "{{\"requestId\":\"{s}\"}}", .{cdp.stringAt(finished.value, "params.requestId").?}));
    defer body.deinit();
    try testing.expectEqualStrings("Request content was evicted from inspector cache", cdp.stringAt(body.value, "error.message").?);
}

test "G16: requestWillBeSentExtraInfo carries the headers that went over the network (User-Agent, Host); responseReceived says hasExtraInfo" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator());
    defer page.close();
    try page.ok("Network.enable", "{}");
    var url_buffer: [96]u8 = undefined;
    var source_buffer: [256]u8 = undefined;
    gpa.allocator().free(try page.evaluate(try std.fmt.bufPrint(&source_buffer, "fetch('{s}').then(r => r.text())", .{try page.url(&url_buffer, "/data.json")})));
    const extra = try page.client.waitEvent("Network.requestWillBeSentExtraInfo");
    defer extra.deinit();
    const headers = cdp.at(extra.value, "params.headers").?.object;
    var saw_user_agent = false;
    var saw_host = false;
    var it = headers.iterator();
    while (it.next()) |e| {
        if (std.ascii.eqlIgnoreCase(e.key_ptr.*, "user-agent")) saw_user_agent = true;
        if (std.ascii.eqlIgnoreCase(e.key_ptr.*, "host")) saw_host = true;
    }
    try testing.expect(saw_user_agent and saw_host);
    const response_extra = try page.client.waitEvent("Network.responseReceivedExtraInfo");
    defer response_extra.deinit();
    try testing.expectEqual(@as(i64, 200), cdp.at(response_extra.value, "params.statusCode").?.integer);
    try testing.expectEqualStrings("Loopback", cdp.stringAt(response_extra.value, "params.resourceIPAddressSpace").?);
    const received = try page.client.waitEvent("Network.responseReceived");
    defer received.deinit();
    try testing.expect(cdp.at(received.value, "params.hasExtraInfo").?.bool);
}

test "G17: with handleAuthRequests a 401's challenge is Fetch.authRequired; ProvideCredentials sends them, and the page gets the page" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator());
    defer page.close();
    // Puppeteer's: every request, auth handled.
    try page.ok("Fetch.enable", "{\"handleAuthRequests\":true,\"patterns\":[{\"urlPattern\":\"*\"}]}");
    var url_buffer: [96]u8 = undefined;
    var source_buffer: [256]u8 = undefined;
    gpa.allocator().free(try page.evaluate(try std.fmt.bufPrint(&source_buffer, "window.answer = fetch('{s}').then(async r => r.status + ':' + await r.text()); 0", .{try page.url(&url_buffer, "/auth")})));
    const paused = try page.client.waitEvent("Fetch.requestPaused");
    defer paused.deinit();
    const id = cdp.stringAt(paused.value, "params.requestId").?;
    var params_buffer: [256]u8 = undefined;
    try page.ok("Fetch.continueRequest", try std.fmt.bufPrint(&params_buffer, "{{\"requestId\":\"{s}\"}}", .{id}));
    const auth = try page.client.waitEvent("Fetch.authRequired");
    defer auth.deinit();
    // The same job's id (Chrome's interception-job-N.0 for the request).
    try testing.expectEqualStrings(id, cdp.stringAt(auth.value, "params.requestId").?);
    try testing.expectEqualStrings("Server", cdp.stringAt(auth.value, "params.authChallenge.source").?);
    try testing.expectEqualStrings("basic", cdp.stringAt(auth.value, "params.authChallenge.scheme").?);
    try testing.expectEqualStrings("crane", cdp.stringAt(auth.value, "params.authChallenge.realm").?);
    // A plain continue at the auth stage is refused.
    const refused = try page.call("Fetch.continueRequest", try std.fmt.bufPrint(&params_buffer, "{{\"requestId\":\"{s}\"}}", .{id}));
    defer refused.deinit();
    try testing.expectEqualStrings("authChallengeResponse required.", cdp.stringAt(refused.value, "error.message").?);
    try page.ok("Fetch.continueWithAuth", try std.fmt.bufPrint(&params_buffer, "{{\"requestId\":\"{s}\",\"authChallengeResponse\":{{\"response\":\"ProvideCredentials\",\"username\":\"u\",\"password\":\"p\"}}}}", .{id}));
    const answer = try page.evaluate("window.answer");
    defer gpa.allocator().free(answer);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"200:welcome\"}", answer);
}

test "G17: CancelAuth hands the 401 on to the page" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator());
    defer page.close();
    try page.ok("Fetch.enable", "{\"handleAuthRequests\":true,\"patterns\":[{\"urlPattern\":\"*auth\"}]}");
    var url_buffer: [96]u8 = undefined;
    var source_buffer: [256]u8 = undefined;
    gpa.allocator().free(try page.evaluate(try std.fmt.bufPrint(&source_buffer, "window.answer = fetch('{s}').then(r => r.status); 0", .{try page.url(&url_buffer, "/auth")})));
    const paused = try page.client.waitEvent("Fetch.requestPaused");
    defer paused.deinit();
    var params_buffer: [256]u8 = undefined;
    try page.ok("Fetch.continueRequest", try std.fmt.bufPrint(&params_buffer, "{{\"requestId\":\"{s}\"}}", .{cdp.stringAt(paused.value, "params.requestId").?}));
    const auth = try page.client.waitEvent("Fetch.authRequired");
    defer auth.deinit();
    try page.ok("Fetch.continueWithAuth", try std.fmt.bufPrint(&params_buffer, "{{\"requestId\":\"{s}\",\"authChallengeResponse\":{{\"response\":\"CancelAuth\"}}}}", .{cdp.stringAt(auth.value, "params.requestId").?}));
    const answer = try page.evaluate("window.answer");
    defer gpa.allocator().free(answer);
    try testing.expectEqualStrings("{\"type\":\"number\",\"value\":401}", answer);
}

test "Fetch commands of a session that never enabled the domain: Chrome's message" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator());
    defer page.close();
    const r = try page.call("Fetch.continueRequest", "{\"requestId\":\"interception-job-1.0\"}");
    defer r.deinit();
    try testing.expectEqualStrings("Fetch domain is not enabled", cdp.stringAt(r.value, "error.message").?);
}
