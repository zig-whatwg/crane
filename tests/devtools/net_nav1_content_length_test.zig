//! Lane net-nav1: CDP Network Content-Length on POST, navigation 401 auth
//! prompts, and nested worker ancestor-frame UA/extra-header overrides.

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const browser_mod = @import("browser");
const devtools = @import("devtools");
const cdp = @import("cdp_client.zig");
const LoopbackListener = @import("loopback_listener").LoopbackListener;

const BrowserHost = browser_mod.BrowserHost;
const Browser = browser_mod.Browser;
const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });

const Site = struct {
    allocator: Allocator,
    listener: LoopbackListener,
    thread: ?std.Thread = null,
    active: std.atomic.Value(u32) = .init(0),
    mutex: std.Io.Mutex = .init,
    records: std.ArrayList([]u8) = .empty,

    fn start(allocator: Allocator) !*Site {
        const self = try allocator.create(Site);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .listener = try LoopbackListener.open(.{}) };
        errdefer self.listener.close();
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
        return self;
    }

    fn stop(self: *Site) void {
        self.listener.stop();
        self.thread.?.join();
        self.listener.close();
        while (self.active.load(.acquire) != 0) std.Thread.yield() catch {};
        for (self.records.items) |r| self.allocator.free(r);
        self.records.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    fn url(self: *const Site, buf: []u8, path: []const u8) ![]const u8 {
        return std.fmt.bufPrint(buf, "http://127.0.0.1:{d}{s}", .{ self.listener.port(), path });
    }

    fn record(self: *Site, line: []u8) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        self.records.append(self.allocator, line) catch self.allocator.free(line);
    }

    fn findRecord(self: *Site, prefix: []const u8) ?[]const u8 {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        var i = self.records.items.len;
        while (i > 0) {
            i -= 1;
            if (std.mem.startsWith(u8, self.records.items[i], prefix)) return self.records.items[i];
        }
        return null;
    }

    fn serve(self: *Site) void {
        while (self.listener.accept()) |stream| {
            _ = self.active.fetchAdd(1, .acq_rel);
            const thread = std.Thread.spawn(.{}, handleAndClose, .{ self, stream }) catch {
                _ = self.active.fetchSub(1, .acq_rel);
                stream.close(std.testing.io);
                continue;
            };
            thread.detach();
        }
    }

    fn handleAndClose(self: *Site, stream: std.Io.net.Stream) void {
        defer _ = self.active.fetchSub(1, .acq_rel);
        defer stream.close(std.testing.io);
        self.handle(stream) catch {};
    }

    fn headerValue(head: []const u8, name: []const u8) ?[]const u8 {
        var lines = std.mem.splitSequence(u8, head, "\r\n");
        _ = lines.next();
        while (lines.next()) |line| {
            const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
            if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, line[0..colon], " "), name)) {
                return std.mem.trim(u8, line[colon + 1 ..], " ");
            }
        }
        return null;
    }

    fn countHeader(head: []const u8, name: []const u8) usize {
        var n: usize = 0;
        var lines = std.mem.splitSequence(u8, head, "\r\n");
        _ = lines.next();
        while (lines.next()) |line| {
            const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
            if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, line[0..colon], " "), name)) n += 1;
        }
        return n;
    }

    fn handle(self: *Site, stream: std.Io.net.Stream) !void {
        var in_buf: [16384]u8 = undefined;
        var reader = stream.reader(std.testing.io, &in_buf);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) {
            try reader.interface.fillMore();
        }
        const buffered = reader.interface.buffered();
        const head_end = std.mem.indexOf(u8, buffered, "\r\n\r\n").?;
        const head = buffered[0..head_end];
        const line_end = std.mem.indexOf(u8, head, "\r\n") orelse return;
        var parts = std.mem.tokenizeScalar(u8, head[0..line_end], ' ');
        const method = parts.next() orelse return;
        const target = parts.next() orelse return;
        const path = if (std.mem.indexOfScalar(u8, target, '?')) |q| target[0..q] else target;

        if (headerValue(head, "content-length")) |cl_str| {
            const cl = std.fmt.parseInt(usize, cl_str, 10) catch 0;
            while (reader.interface.buffered().len < head_end + 4 + cl) {
                try reader.interface.fillMore();
            }
        }

        const cl_count = countHeader(head, "content-length");
        const cl_val = headerValue(head, "content-length") orelse "-";
        const ua_val = headerValue(head, "user-agent") orelse "-";
        const lang_val = headerValue(head, "accept-language") orelse "-";
        const extra_val = headerValue(head, "x-nested-hdr") orelse "-";
        const rec = try std.fmt.allocPrint(self.allocator, "{s} {s} cl_count={d} cl={s} ua={s} lang={s} extra={s}", .{
            method, path, cl_count, cl_val, ua_val, lang_val, extra_val,
        });
        self.record(rec);

        var out_buf: [4096]u8 = undefined;
        var writer = stream.writer(std.testing.io, &out_buf);
        const out = &writer.interface;

        if (std.mem.eql(u8, path, "/auth")) {
            const auth = headerValue(head, "authorization") orelse "";
            // "u:p" base64 is "dTpw"
            if (std.mem.eql(u8, auth, "Basic dTpw")) {
                const body = "<!doctype html><title>authed</title><p>welcome</p>";
                try out.print("HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n{s}", .{ body.len, body });
            } else {
                const body = "<!doctype html><title>denied</title><p>denied</p>";
                try out.print("HTTP/1.1 401 Unauthorized\r\nWWW-Authenticate: Basic realm=\"nav-realm\"\r\nContent-Type: text/html\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n{s}", .{ body.len, body });
            }
            return out.flush();
        }

        if (std.mem.eql(u8, path, "/outer-worker.js")) {
            const body =
                \\onmessage = (e) => {
                \\  const nested = new Worker(e.data);
                \\  nested.onmessage = (m) => postMessage(m.data);
                \\  nested.onerror = () => postMessage('nested-error');
                \\};
            ;
            try out.print("HTTP/1.1 200 OK\r\nContent-Type: text/javascript\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n{s}", .{ body.len, body });
            return out.flush();
        }

        if (std.mem.eql(u8, path, "/nested-worker-1.js") or std.mem.eql(u8, path, "/nested-worker-2.js")) {
            const body = "fetch('/from-nested-worker').then(() => postMessage('nested-ok'), () => postMessage('nested-fetch-err'));";
            try out.print("HTTP/1.1 200 OK\r\nContent-Type: text/javascript\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n{s}", .{ body.len, body });
            return out.flush();
        }

        const body = if (std.mem.eql(u8, path, "/page.html")) "<!doctype html><title>page</title>" else "ok";
        const ct = if (std.mem.eql(u8, path, "/page.html")) "text/html" else "text/plain";
        try out.print("HTTP/1.1 200 OK\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n{s}", .{ ct, body.len, body });
        try out.flush();
    }
};

const Page = struct {
    host: *BrowserHost,
    tab: Browser.TabId,
    server: *devtools.Server,
    client: *cdp.Client,
    session: []u8,
    site: *Site,
    allocator: Allocator,

    fn open(allocator: Allocator) !Page {
        const site = try Site.start(allocator);
        errdefer site.stop();
        const host = try BrowserHost.start(allocator, .{});
        errdefer host.stop();
        const tab = try host.createTab(.{});
        var url_buf: [96]u8 = undefined;
        const loaded = try host.navigate(allocator, tab, try site.url(&url_buf, "/page.html"), .{ .wait = .complete, .timeout_ms = 10_000 });
        allocator.free(loaded);
        const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
        errdefer server.stop();
        var path_buf: [96]u8 = undefined;
        const client = try cdp.Client.openWebSocket(allocator, server.port, try std.fmt.bufPrint(&path_buf, "/devtools/browser/{s}", .{server.browser_id.slice()}), null);
        errdefer client.close();
        const targets = try client.call("Target.getTargets", "{}", "");
        defer targets.deinit();
        const infos = cdp.at(targets.value, "result.targetInfos").?.array.items;
        var params_buf: [128]u8 = undefined;
        const attached = try client.call("Target.attachToTarget", try std.fmt.bufPrint(&params_buf, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{cdp.stringAt(infos[infos.len - 1], "targetId").?}), "");
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

    fn ok(self: *Page, method: []const u8, params: []const u8) !void {
        const r = try self.client.call(method, params, self.session);
        defer r.deinit();
        try testing.expect(cdp.at(r.value, "error") == null);
    }

    fn evaluate(self: *Page, source: []const u8) ![]u8 {
        const result = try self.host.evaluate(self.allocator, self.tab, source, .{ .await_promise = true }, 10_000);
        defer result.deinit(self.allocator);
        return self.allocator.dupe(u8, result.json);
    }
};

fn headerInJson(headers: std.json.ObjectMap, name: []const u8) ?[]const u8 {
    var it = headers.iterator();
    while (it.next()) |e| {
        if (std.ascii.eqlIgnoreCase(e.key_ptr.*, name)) return e.value_ptr.string;
    }
    return null;
}

test "Item 1: CDP Network.requestWillBeSentExtraInfo includes Content-Length: 3 for fetch POST 'abc' and single wire header" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator());
    defer page.close();

    try page.ok("Network.enable", "{}");

    var url_buf: [96]u8 = undefined;
    var src_buf: [256]u8 = undefined;
    const post_url = try page.site.url(&url_buf, "/submit");
    gpa.allocator().free(try page.evaluate(try std.fmt.bufPrint(&src_buf, "fetch('{s}', {{ method: 'POST', body: 'abc' }}).then(r => r.text())", .{post_url})));

    const sent = try page.client.waitEvent("Network.requestWillBeSent");
    defer sent.deinit();
    const req_id = cdp.stringAt(sent.value, "params.requestId").?;

    const extra = try page.client.waitEvent("Network.requestWillBeSentExtraInfo");
    defer extra.deinit();
    try testing.expectEqualStrings(req_id, cdp.stringAt(extra.value, "params.requestId").?);
    const headers = cdp.at(extra.value, "params.headers").?.object;
    const cl = headerInJson(headers, "content-length") orelse return error.MissingContentLength;
    try testing.expectEqualStrings("3", cl);

    // Wire check: server must receive exactly ONE Content-Length: 3 header (not duplicated by curl).
    const wire = page.site.findRecord("POST /submit ") orelse return error.MissingWireRecord;
    try testing.expect(std.mem.indexOf(u8, wire, "cl_count=1 cl=3 ") != null);
}

test "Item 2: navigation to 401 Basic challenge raises CDP Fetch.authRequired and commits 200 on ProvideCredentials, headless delivers 401, URL credentials authenticate" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator());
    defer page.close();

    // 1. Headless default (no auth prompt handler): 401 response is delivered as-is.
    var url_buf: [96]u8 = undefined;
    const auth_url = try page.site.url(&url_buf, "/auth");
    {
        const loaded = try page.host.navigate(gpa.allocator(), page.tab, auth_url, .{ .wait = .complete, .timeout_ms = 10_000 });
        gpa.allocator().free(loaded);
        const title = try page.evaluate("document.title");
        defer gpa.allocator().free(title);
        try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"denied\"}", title);
    }

    // 2. Navigation URL with embedded credentials (http://u:p@127.0.0.1:PORT/auth):
    //    HTML "create navigation params by fetching" step 3 sets use-URL-credentials
    //    and traversable_for_user_prompts -> retries with Basic auth and commits 200.
    {
        var cred_url_buf: [128]u8 = undefined;
        const cred_url = try std.fmt.bufPrint(&cred_url_buf, "http://u:p@127.0.0.1:{d}/auth", .{page.site.listener.port()});
        const loaded = try page.host.navigate(gpa.allocator(), page.tab, cred_url, .{ .wait = .complete, .timeout_ms = 10_000 });
        gpa.allocator().free(loaded);
        const title = try page.evaluate("document.title");
        defer gpa.allocator().free(title);
        try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"authed\"}", title);
    }

    // 3. CDP Fetch.enable(handleAuthRequests: true): 401 on navigation raises
    //    Fetch.authRequired and ProvideCredentials commits the 200 page.
    //    First return to /page.html and clear auth cache by navigating to a
    //    distinct realm path or fresh Page.
    var page2 = try Page.open(gpa.allocator());
    defer page2.close();
    try page2.ok("Page.enable", "{}");
    try page2.ok("Fetch.enable", "{\"handleAuthRequests\":true,\"patterns\":[{\"urlPattern\":\"*\"}]}");
    var url_buf2: [96]u8 = undefined;
    var src_buf: [192]u8 = undefined;
    const auth_url2 = try page2.site.url(&url_buf2, "/auth");
    gpa.allocator().free(try page2.evaluate(try std.fmt.bufPrint(&src_buf, "location.href = '{s}'; 0", .{auth_url2})));

    const paused = try page2.client.waitEvent("Fetch.requestPaused");
    defer paused.deinit();
    const id = cdp.stringAt(paused.value, "params.requestId").?;
    var continue_params: [256]u8 = undefined;
    try page2.ok("Fetch.continueRequest", try std.fmt.bufPrint(&continue_params, "{{\"requestId\":\"{s}\"}}", .{id}));

    const auth = try page2.client.waitEvent("Fetch.authRequired");
    defer auth.deinit();
    try testing.expectEqualStrings("Server", cdp.stringAt(auth.value, "params.authChallenge.source").?);
    try testing.expectEqualStrings("basic", cdp.stringAt(auth.value, "params.authChallenge.scheme").?);
    try testing.expectEqualStrings("nav-realm", cdp.stringAt(auth.value, "params.authChallenge.realm").?);

    try page2.ok("Fetch.continueWithAuth", try std.fmt.bufPrint(&continue_params, "{{\"requestId\":\"{s}\",\"authChallengeResponse\":{{\"response\":\"ProvideCredentials\",\"username\":\"u\",\"password\":\"p\"}}}}", .{id}));

    const loaded = try page2.client.waitEvent("Page.loadEventFired");
    defer loaded.deinit();
    const title = try page2.evaluate("document.title");
    defer gpa.allocator().free(title);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"authed\"}", title);
}

test "Item 6: nested worker script request inherits ancestor frame's current UA, Accept-Language, and extra headers" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator());
    defer page.close();

    try page.ok("Network.enable", "{}");
    try page.ok("Network.setExtraHTTPHeaders", "{\"headers\":{\"X-Nested-Hdr\":\"from-tab-1\"}}");
    try page.ok("Emulation.setUserAgentOverride", "{\"userAgent\":\"NestedUA/1.0\",\"acceptLanguage\":\"fr-FR\"}");

    // Start outer worker while tab has UA=NestedUA/1.0, lang=fr-FR, extra=from-tab-1.
    const r1 = try page.evaluate(
        \\new Promise((resolve) => {
        \\  window.__w = new Worker('/outer-worker.js');
        \\  window.__w.onmessage = (e) => resolve(e.data);
        \\  window.__w.postMessage('/nested-worker-1.js');
        \\})
    );
    defer gpa.allocator().free(r1);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"nested-ok\"}", r1);

    const w1 = page.site.findRecord("GET /nested-worker-1.js ") orelse return error.MissingNested1;
    try testing.expect(std.mem.indexOf(u8, w1, "ua=NestedUA/1.0 ") != null);
    try testing.expect(std.mem.indexOf(u8, w1, "lang=fr-FR ") != null);
    try testing.expect(std.mem.indexOf(u8, w1, "extra=from-tab-1") != null);

    // Nested worker's OWN fetch carries NO page extra headers (matching Blink).
    const wf = page.site.findRecord("GET /from-nested-worker ") orelse return error.MissingNestedFetch;
    try testing.expect(std.mem.indexOf(u8, wf, "extra=-") != null);

    // Update the tab's overrides AFTER outer worker was already running, then spawn a second nested worker.
    try page.ok("Network.setExtraHTTPHeaders", "{\"headers\":{\"X-Nested-Hdr\":\"from-tab-2\"}}");
    try page.ok("Network.setUserAgentOverride", "{\"userAgent\":\"NestedUA/2.0\",\"acceptLanguage\":\"de-DE\"}");

    const r2 = try page.evaluate(
        \\new Promise((resolve) => {
        \\  window.__w.onmessage = (e) => resolve(e.data);
        \\  window.__w.postMessage('/nested-worker-2.js');
        \\})
    );
    defer gpa.allocator().free(r2);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"nested-ok\"}", r2);

    const w2 = page.site.findRecord("GET /nested-worker-2.js ") orelse return error.MissingNested2;
    try testing.expect(std.mem.indexOf(u8, w2, "ua=NestedUA/2.0 ") != null);
    try testing.expect(std.mem.indexOf(u8, w2, "lang=de-DE ") != null);
    try testing.expect(std.mem.indexOf(u8, w2, "extra=from-tab-2") != null);
}
