//! Lane icon1: HTML §4.6.8.9 link rel="icon" selection (sizes, type, media,
//! tree-order tie-break, fallback on failure), default /favicon.ico after load
//! for top-level HTTP(S) documents, dynamic updates, non-applicable documents
//! (data:, about:blank, iframes, srcdoc), CSP img-src (silent for default
//! /favicon.ico, reported for <link rel="icon">), no link load/error events,
//! no document load delay, no PerformanceResourceTiming pollution for default
//! /favicon.ico, and 0 leaks on mid-fetch teardown.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const LoopbackListener = @import("loopback_listener").LoopbackListener;

const Header = struct {
    name: []const u8,
    value: []const u8,
};

const Route = struct {
    path: []const u8,
    status: u16 = 200,
    content_type: []const u8 = "text/html",
    headers: []const Header = &.{},
    body: []const u8 = "",
    /// Hold response until `Server.release_slow` becomes true.
    hold: bool = false,
};

const RecordedRequest = struct {
    path: []u8,
    accept: []u8,
    cookie: []u8,
    referer: []u8,
    sec_fetch_dest: []u8,
    sec_fetch_mode: []u8,
    sec_fetch_site: []u8,

    fn deinit(self: *RecordedRequest, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        allocator.free(self.accept);
        allocator.free(self.cookie);
        allocator.free(self.referer);
        allocator.free(self.sec_fetch_dest);
        allocator.free(self.sec_fetch_mode);
        allocator.free(self.sec_fetch_site);
    }
};

const Server = struct {
    allocator: std.mem.Allocator,
    listener: LoopbackListener,
    thread: ?std.Thread = null,
    active: std.atomic.Value(u32) = .init(0),
    release_slow: std.atomic.Value(bool) = .init(false),
    routes: []const Route,
    mutex: std.Io.Mutex = .init,
    requests: std.ArrayListUnmanaged(RecordedRequest) = .empty,

    fn start(allocator: std.mem.Allocator, routes: []const Route) !*Server {
        const self = try allocator.create(Server);
        errdefer allocator.destroy(self);
        self.* = .{
            .allocator = allocator,
            .listener = try LoopbackListener.open(.{}),
            .routes = routes,
        };
        errdefer self.listener.close();
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
        return self;
    }

    fn stop(self: *Server) void {
        self.release_slow.store(true, .release);
        self.listener.stop();
        self.thread.?.join();
        self.listener.close();
        while (self.active.load(.acquire) != 0) std.Thread.yield() catch {};
        for (self.requests.items) |*req| req.deinit(self.allocator);
        self.requests.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    fn url(self: *const Server, buf: []u8, path: []const u8) ![]const u8 {
        return std.fmt.bufPrint(buf, "http://127.0.0.1:{d}{s}", .{ self.listener.port(), path });
    }

    fn hasPath(self: *Server, path: []const u8) bool {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        for (self.requests.items) |req| {
            if (std.mem.eql(u8, req.path, path)) return true;
        }
        return false;
    }

    fn countPath(self: *Server, path: []const u8) usize {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        var n: usize = 0;
        for (self.requests.items) |req| {
            if (std.mem.eql(u8, req.path, path)) n += 1;
        }
        return n;
    }

    fn indexOfPath(self: *Server, path: []const u8) ?usize {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        for (self.requests.items, 0..) |req, i| {
            if (std.mem.eql(u8, req.path, path)) return i;
        }
        return null;
    }

    fn findRequest(self: *Server, allocator: std.mem.Allocator, path: []const u8) !?RecordedRequest {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        for (self.requests.items) |req| {
            if (std.mem.eql(u8, req.path, path)) {
                return .{
                    .path = try allocator.dupe(u8, req.path),
                    .accept = try allocator.dupe(u8, req.accept),
                    .cookie = try allocator.dupe(u8, req.cookie),
                    .referer = try allocator.dupe(u8, req.referer),
                    .sec_fetch_dest = try allocator.dupe(u8, req.sec_fetch_dest),
                    .sec_fetch_mode = try allocator.dupe(u8, req.sec_fetch_mode),
                    .sec_fetch_site = try allocator.dupe(u8, req.sec_fetch_site),
                };
            }
        }
        return null;
    }

    fn serve(self: *Server) void {
        while (self.listener.accept()) |stream| {
            _ = self.active.fetchAdd(1, .acq_rel);
            const thread = std.Thread.spawn(.{}, answerAndClose, .{ self, stream }) catch {
                _ = self.active.fetchSub(1, .acq_rel);
                stream.close(std.testing.io);
                continue;
            };
            thread.detach();
        }
    }

    fn answerAndClose(self: *Server, stream: std.Io.net.Stream) void {
        defer _ = self.active.fetchSub(1, .acq_rel);
        defer stream.close(std.testing.io);
        self.answer(stream) catch {};
    }

    fn headerValue(head: []const u8, name: []const u8) []const u8 {
        var lines = std.mem.splitSequence(u8, head, "\r\n");
        _ = lines.next();
        while (lines.next()) |line| {
            const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
            if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, line[0..colon], " "), name)) {
                return std.mem.trim(u8, line[colon + 1 ..], " ");
            }
        }
        return "";
    }

    fn answer(self: *Server, stream: std.Io.net.Stream) !void {
        var input: [8192]u8 = undefined;
        var reader = stream.reader(std.testing.io, &input);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) {
            try reader.interface.fillMore();
        }
        const head = reader.interface.buffered();
        const line_end = std.mem.indexOf(u8, head, "\r\n") orelse return;
        var parts = std.mem.tokenizeScalar(u8, head[0..line_end], ' ');
        _ = parts.next() orelse return;
        const target = parts.next() orelse return;

        {
            var rec: RecordedRequest = .{
                .path = try self.allocator.dupe(u8, target),
                .accept = try self.allocator.dupe(u8, headerValue(head, "accept")),
                .cookie = try self.allocator.dupe(u8, headerValue(head, "cookie")),
                .referer = try self.allocator.dupe(u8, headerValue(head, "referer")),
                .sec_fetch_dest = try self.allocator.dupe(u8, headerValue(head, "sec-fetch-dest")),
                .sec_fetch_mode = try self.allocator.dupe(u8, headerValue(head, "sec-fetch-mode")),
                .sec_fetch_site = try self.allocator.dupe(u8, headerValue(head, "sec-fetch-site")),
            };
            errdefer rec.deinit(self.allocator);
            std.Io.Threaded.mutexLockUncancelable(&self.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.mutex);
            try self.requests.append(self.allocator, rec);
        }

        const matched: Route = blk: {
            for (self.routes) |route| {
                if (std.mem.eql(u8, route.path, target)) break :blk route;
            }
            break :blk .{
                .path = "",
                .status = 404,
                .content_type = "text/plain",
                .body = "not found",
            };
        };

        if (matched.hold) {
            while (!self.release_slow.load(.acquire)) {
                std.Io.sleep(std.testing.io, .fromMilliseconds(5), .awake) catch {};
            }
        }

        var output: [0]u8 = .{};
        var writer = stream.writer(std.testing.io, &output);
        const reason = switch (matched.status) {
            200 => "OK",
            else => "Not Found",
        };
        try writer.interface.print(
            "HTTP/1.1 {d} {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n",
            .{ matched.status, reason, matched.content_type, matched.body.len },
        );
        for (matched.headers) |h| {
            try writer.interface.print("{s}: {s}\r\n", .{ h.name, h.value });
        }
        try writer.interface.writeAll("\r\n");
        try writer.interface.writeAll(matched.body);
        try writer.interface.flush();
    }
};

fn onFreshThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            body() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

fn waitForServerPath(browser: *browser_mod.Browser, server: *Server, path: []const u8) !void {
    for (0..400) |_| {
        if (server.hasPath(path)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOutWaitingForIconRequest;
}

fn waitForJsTrue(browser: *browser_mod.Browser, ctx: *browser_mod.Context, expr: []const u8) !void {
    for (0..400) |_| {
        const res = try ctx.evaluateScriptToString(expr, testing.allocator);
        defer testing.allocator.free(res);
        if (std.mem.eql(u8, res, "true")) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOutWaitingForJs;
}

fn pumpAfterDone(browser: *browser_mod.Browser) !void {
    for (0..10) |_| {
        _ = try browser.runEventLoopBlocking(10);
    }
}

const png_bytes =
    "\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01" ++
    "\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01" ++
    "\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82";

test "default /favicon.ico fetched after load with credentials, image headers, ignores <base>, no ResourceTiming" {
    try onFreshThread(struct {
        fn run() !void {
            const routes = [_]Route{
                .{
                    .path = "/plain.html",
                    .headers = &.{.{ .name = "Set-Cookie", .value = "sid=icon1; Path=/" }},
                    .body =
                    \\<!doctype html>
                    \\<base href="http://other.invalid/sub/">
                    \\<title>Plain</title>
                    \\<script>
                    \\globalThis.__loaded = false;
                    \\window.addEventListener('load', () => { globalThis.__loaded = true; });
                    \\</script>
                    \\<p>plain</p>
                    ,
                },
                .{
                    .path = "/favicon.ico",
                    .content_type = "image/x-icon",
                    .body = png_bytes,
                },
            };
            const server = try Server.start(testing.allocator, &routes);
            defer server.stop();

            const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
            defer browser.deinit();

            var url_buf: [128]u8 = undefined;
            const page_url = try server.url(&url_buf, "/plain.html");
            try browser.navigate(page_url, .window);
            const ctx = browser.current_context orelse return error.NoPage;

            try waitForJsTrue(browser, ctx, "Boolean(globalThis.__loaded)");
            try waitForServerPath(browser, server, "/favicon.ico");
            // Pump until the response settles so ResourceTiming would be populated if wrongly reported.
            try pumpAfterDone(browser);

            var req = (try server.findRequest(testing.allocator, "/favicon.ico")) orelse return error.MissingFaviconRequest;
            defer req.deinit(testing.allocator);

            try testing.expectEqualStrings("image", req.sec_fetch_dest);
            try testing.expectEqualStrings("no-cors", req.sec_fetch_mode);
            try testing.expectEqualStrings("same-origin", req.sec_fetch_site);
            try testing.expect(std.mem.indexOf(u8, req.cookie, "sid=icon1") != null);
            try testing.expectEqualStrings(page_url, req.referer);
            try testing.expect(std.mem.indexOf(u8, req.accept, "image/") != null);

            // HTML §4.6.8.9 + Fetch §2.2.5: default /favicon.ico has initiatorType = null
            // and MUST NOT pollute performance.getEntriesByType("resource").
            const rt_has_favicon = try ctx.evaluateScriptToString(
                "String(performance.getEntriesByType('resource').some(e => e.name.endsWith('/favicon.ico')))",
                testing.allocator,
            );
            defer testing.allocator.free(rt_has_favicon);
            try testing.expectEqualStrings("false", rt_has_favicon);
        }
    }.run);
}

test "link rel=icon selection: filters media/type, prefers sizes=any, last in tree order on tie, falls back on 404" {
    try onFreshThread(struct {
        fn run() !void {
            const routes = [_]Route{
                .{
                    .path = "/multi.html",
                    .body =
                    \\<!doctype html>
                    \\<head>
                    \\  <link rel="icon" href="/badmedia.png" media="(max-width: 1px)">
                    \\  <link rel="icon" href="/badtype.txt" type="text/plain">
                    \\  <link rel="icon" href="/i16.png" sizes="16x16" type="image/png">
                    \\  <link rel="icon" href="/iany.svg" sizes="any" type="image/svg+xml">
                    \\</head><body>multi</body>
                    ,
                },
                .{
                    .path = "/tie.html",
                    .body =
                    \\<!doctype html>
                    \\<head>
                    \\  <link rel="icon" href="/first.png" sizes="32x32" type="image/png">
                    \\  <link rel="icon" href="/second.png" sizes="32x32" type="image/png">
                    \\</head><body>tie</body>
                    ,
                },
                .{
                    .path = "/fallback.html",
                    .body =
                    \\<!doctype html>
                    \\<head>
                    \\  <link rel="icon" href="/good.png" sizes="16x16" type="image/png">
                    \\  <link rel="icon" href="/missing.svg" sizes="any" type="image/svg+xml">
                    \\</head><body>fallback</body>
                    ,
                },
                .{ .path = "/iany.svg", .content_type = "image/svg+xml", .body = "<svg/>" },
                .{ .path = "/second.png", .content_type = "image/png", .body = png_bytes },
                .{ .path = "/first.png", .content_type = "image/png", .body = png_bytes },
                .{ .path = "/good.png", .content_type = "image/png", .body = png_bytes },
                .{ .path = "/missing.svg", .status = 404, .content_type = "text/plain", .body = "nope" },
            };
            const server = try Server.start(testing.allocator, &routes);
            defer server.stop();

            const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
            defer browser.deinit();

            var url_buf: [128]u8 = undefined;

            // 1. Multi-candidate selection: only /iany.svg should be fetched.
            try browser.navigate(try server.url(&url_buf, "/multi.html"), .window);
            try waitForServerPath(browser, server, "/iany.svg");
            try pumpAfterDone(browser);
            try testing.expect(!server.hasPath("/favicon.ico"));
            try testing.expect(!server.hasPath("/badmedia.png"));
            try testing.expect(!server.hasPath("/badtype.txt"));
            try testing.expect(!server.hasPath("/i16.png"));

            // 2. Tree-order tie-break: HTML §4.6.8.9 picks the LAST equally appropriate icon.
            try browser.navigate(try server.url(&url_buf, "/tie.html"), .window);
            try waitForServerPath(browser, server, "/second.png");
            try pumpAfterDone(browser);
            try testing.expect(!server.hasPath("/first.png"));
            try testing.expect(!server.hasPath("/favicon.ico"));

            // 3. Fallback on 404: tries /missing.svg first, then falls back to /good.png.
            try browser.navigate(try server.url(&url_buf, "/fallback.html"), .window);
            try waitForServerPath(browser, server, "/missing.svg");
            try waitForServerPath(browser, server, "/good.png");
            try pumpAfterDone(browser);
            try testing.expect(!server.hasPath("/favicon.ico"));
        }
    }.run);
}

test "link rel=icon does not fire load/error events and does not delay document load" {
    try onFreshThread(struct {
        fn run() !void {
            const routes = [_]Route{
                .{
                    .path = "/slow-icon-page.html",
                    .body =
                    \\<!doctype html>
                    \\<head>
                    \\  <script>
                    \\    globalThis.__linkEvents = [];
                    \\    globalThis.__docLoaded = false;
                    \\    window.addEventListener('load', () => { globalThis.__docLoaded = true; });
                    \\  </script>
                    \\  <link rel="icon" href="/slow.png"
                    \\        onload="globalThis.__linkEvents.push('load')"
                    \\        onerror="globalThis.__linkEvents.push('error')">
                    \\</head><body>ok</body>
                    ,
                },
                .{ .path = "/slow.png", .content_type = "image/png", .body = png_bytes, .hold = true },
            };
            const server = try Server.start(testing.allocator, &routes);
            defer server.stop();

            const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
            defer browser.deinit();

            var url_buf: [128]u8 = undefined;
            try browser.navigate(try server.url(&url_buf, "/slow-icon-page.html"), .window);
            const ctx = browser.current_context orelse return error.NoPage;

            // Document load MUST complete while /slow.png is still held!
            try waitForJsTrue(browser, ctx, "Boolean(globalThis.__docLoaded)");
            try waitForServerPath(browser, server, "/slow.png");

            server.release_slow.store(true, .release);
            try pumpAfterDone(browser);

            const events = try ctx.evaluateScriptToString("globalThis.__linkEvents.join(',')", testing.allocator);
            defer testing.allocator.free(events);
            try testing.expectEqualStrings("", events);
        }
    }.run);
}

test "dynamic link rel=icon insertion and href update after load; removal does not re-fetch /favicon.ico" {
    try onFreshThread(struct {
        fn run() !void {
            const routes = [_]Route{
                .{ .path = "/dyn.html", .body = "<!doctype html><head><title>dyn</title></head><body>ok</body>" },
                .{ .path = "/favicon.ico", .content_type = "image/x-icon", .body = png_bytes },
                .{ .path = "/dyn1.png", .content_type = "image/png", .body = png_bytes },
                .{ .path = "/dyn2.png", .content_type = "image/png", .body = png_bytes },
            };
            const server = try Server.start(testing.allocator, &routes);
            defer server.stop();

            const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
            defer browser.deinit();

            var url_buf: [128]u8 = undefined;
            try browser.navigate(try server.url(&url_buf, "/dyn.html"), .window);
            const ctx = browser.current_context orelse return error.NoPage;
            try waitForServerPath(browser, server, "/favicon.ico");
            try testing.expectEqual(@as(usize, 1), server.countPath("/favicon.ico"));

            try ctx.runScript(
                \\const l = document.createElement('link');
                \\l.id = 'ic';
                \\l.rel = 'icon';
                \\l.href = '/dyn1.png';
                \\document.head.appendChild(l);
            );
            try waitForServerPath(browser, server, "/dyn1.png");

            try ctx.runScript("document.getElementById('ic').href = '/dyn2.png';");
            try waitForServerPath(browser, server, "/dyn2.png");

            try ctx.runScript("document.getElementById('ic').remove();");
            try pumpAfterDone(browser);
            try testing.expectEqual(@as(usize, 1), server.countPath("/favicon.ico"));
        }
    }.run);
}

test "no icon fetch on data:, about:blank, iframes, or srcdoc" {
    try onFreshThread(struct {
        fn run() !void {
            const routes = [_]Route{
                .{
                    .path = "/host.html",
                    .body =
                    \\<!doctype html>
                    \\<head><link rel="icon" href="data:,"></head>
                    \\<body>
                    \\  <script>
                    \\    globalThis.__framesDone = 0;
                    \\    globalThis.markFrame = () => { globalThis.__framesDone++; };
                    \\  </script>
                    \\  <iframe src="/child-plain.html" onload="markFrame()"></iframe>
                    \\  <iframe src="/child-link.html" onload="markFrame()"></iframe>
                    \\  <iframe srcdoc="<link rel='icon' href='/srcdoc-icon.png'><p>sd</p>" onload="markFrame()"></iframe>
                    \\</body>
                    ,
                },
                .{ .path = "/child-plain.html", .body = "<!doctype html><p>plain child</p>" },
                .{ .path = "/child-link.html", .body = "<!doctype html><link rel='icon' href='/child-icon.png'><p>link child</p>" },
                .{ .path = "/favicon.ico", .content_type = "image/x-icon", .body = png_bytes },
                .{ .path = "/child-icon.png", .content_type = "image/png", .body = png_bytes },
                .{ .path = "/srcdoc-icon.png", .content_type = "image/png", .body = png_bytes },
            };
            const server = try Server.start(testing.allocator, &routes);
            defer server.stop();

            const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
            defer browser.deinit();

            // 1. data: and about:blank
            try browser.navigate("about:blank", .window);
            try pumpAfterDone(browser);
            try browser.navigate("data:text/html,<p>hello</p>", .window);
            try pumpAfterDone(browser);

            // 2. Top-level with data:, icon + 3 iframes
            var url_buf: [128]u8 = undefined;
            try browser.navigate(try server.url(&url_buf, "/host.html"), .window);
            const ctx = browser.current_context orelse return error.NoPage;
            try waitForJsTrue(browser, ctx, "globalThis.__framesDone === 3");
            try pumpAfterDone(browser);

            try testing.expect(!server.hasPath("/favicon.ico"));
            try testing.expect(!server.hasPath("/child-icon.png"));
            try testing.expect(!server.hasPath("/srcdoc-icon.png"));
        }
    }.run);
}

test "CSP img-src none: silent skip for default /favicon.ico, reported violation for link rel=icon" {
    try onFreshThread(struct {
        fn run() !void {
            const routes = [_]Route{
                .{
                    .path = "/csp-plain.html",
                    .body =
                    \\<!doctype html>
                    \\<meta http-equiv="Content-Security-Policy" content="img-src 'none'">
                    \\<script>
                    \\  globalThis.__spv = [];
                    \\  globalThis.__loaded = false;
                    \\  document.addEventListener('securitypolicyviolation', e => globalThis.__spv.push(e.effectiveDirective + ':' + e.blockedURI));
                    \\  window.addEventListener('load', () => { globalThis.__loaded = true; });
                    \\</script>
                    \\<p>csp plain</p>
                    ,
                },
                .{
                    .path = "/csp-link.html",
                    .body =
                    \\<!doctype html>
                    \\<meta http-equiv="Content-Security-Policy" content="img-src 'none'">
                    \\<link rel="icon" href="/blocked.png">
                    \\<script>
                    \\  globalThis.__spv = [];
                    \\  document.addEventListener('securitypolicyviolation', e => globalThis.__spv.push(e.effectiveDirective + ':' + e.blockedURI));
                    \\</script>
                    \\<p>csp link</p>
                    ,
                },
                .{ .path = "/favicon.ico", .content_type = "image/x-icon", .body = png_bytes },
                .{ .path = "/blocked.png", .content_type = "image/png", .body = png_bytes },
            };
            const server = try Server.start(testing.allocator, &routes);
            defer server.stop();

            const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
            defer browser.deinit();

            var url_buf: [128]u8 = undefined;

            // 1. Default /favicon.ico blocked silently by CSP (no HTTP request, no spv event).
            try browser.navigate(try server.url(&url_buf, "/csp-plain.html"), .window);
            var ctx = browser.current_context orelse return error.NoPage;
            try waitForJsTrue(browser, ctx, "Boolean(globalThis.__loaded)");
            try pumpAfterDone(browser);
            try testing.expect(!server.hasPath("/favicon.ico"));
            const plain_spv = try ctx.evaluateScriptToString("String(globalThis.__spv.length)", testing.allocator);
            defer testing.allocator.free(plain_spv);
            try testing.expectEqualStrings("0", plain_spv);

            // 2. Explicit <link rel="icon"> blocked WITH securitypolicyviolation.
            try browser.navigate(try server.url(&url_buf, "/csp-link.html"), .window);
            ctx = browser.current_context orelse return error.NoPage;
            try waitForJsTrue(browser, ctx, "globalThis.__spv.length >= 1");
            try pumpAfterDone(browser);
            try testing.expect(!server.hasPath("/blocked.png"));
            const link_spv = try ctx.evaluateScriptToString("globalThis.__spv[0]", testing.allocator);
            defer testing.allocator.free(link_spv);
            try testing.expect(std.mem.startsWith(u8, link_spv, "img-src:"));
            try testing.expect(std.mem.endsWith(u8, link_spv, "/blocked.png"));
        }
    }.run);
}

test "zero leaks when document tears down or navigates away mid-icon-fetch" {
    try onFreshThread(struct {
        fn run() !void {
            const routes = [_]Route{
                .{ .path = "/slow-default.html", .body = "<!doctype html><p>slow default</p>" },
                .{ .path = "/slow-link.html", .body = "<!doctype html><link rel='icon' href='/slow-link.png'><p>slow link</p>" },
                .{ .path = "/favicon.ico", .content_type = "image/x-icon", .body = png_bytes, .hold = true },
                .{ .path = "/slow-link.png", .content_type = "image/png", .body = png_bytes, .hold = true },
            };
            const server = try Server.start(testing.allocator, &routes);
            defer server.stop();

            // Case A: navigate away while default /favicon.ico is in flight.
            {
                const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
                defer browser.deinit();
                var url_buf: [128]u8 = undefined;
                try browser.navigate(try server.url(&url_buf, "/slow-default.html"), .window);
                try waitForServerPath(browser, server, "/favicon.ico");
                try browser.navigate("about:blank", .window);
                try pumpAfterDone(browser);
            }

            // Case B: destroy Browser while <link rel="icon"> fetch is in flight.
            {
                const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
                defer browser.deinit();
                var url_buf: [128]u8 = undefined;
                try browser.navigate(try server.url(&url_buf, "/slow-link.html"), .window);
                try waitForServerPath(browser, server, "/slow-link.png");
                // Browser.deinit() runs while /slow-link.png is still held open on the server.
            }

            server.release_slow.store(true, .release);
        }
    }.run);
}

test "post-load icon fetch runs in a queued task after tasks already queued during parse" {
    try onFreshThread(struct {
        fn run() !void {
            const routes = [_]Route{
                .{
                    .path = "/order.html",
                    .body =
                    \\<!doctype html>
                    \\<head>
                    \\  <script>
                    \\    const ch = new MessageChannel();
                    \\    ch.port1.onmessage = () => {
                    \\      const xhr = new XMLHttpRequest();
                    \\      xhr.open('GET', '/queued-during-parse', false);
                    \\      xhr.send();
                    \\      globalThis.__taskRan = true;
                    \\    };
                    \\    ch.port2.postMessage('go');
                    \\  </script>
                    \\</head><body>ok</body>
                    ,
                },
                .{ .path = "/queued-during-parse", .content_type = "text/plain", .body = "ok" },
                .{ .path = "/favicon.ico", .content_type = "image/x-icon", .body = png_bytes },
            };
            const server = try Server.start(testing.allocator, &routes);
            defer server.stop();

            const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
            defer browser.deinit();

            var url_buf: [128]u8 = undefined;
            try browser.navigate(try server.url(&url_buf, "/order.html"), .window);
            const ctx = browser.current_context orelse return error.NoPage;
            try waitForJsTrue(browser, ctx, "Boolean(globalThis.__taskRan)");
            try waitForServerPath(browser, server, "/favicon.ico");

            const task_idx = server.indexOfPath("/queued-during-parse") orelse return error.MissingTaskRequest;
            const icon_idx = server.indexOfPath("/favicon.ico") orelse return error.MissingFaviconRequest;
            try testing.expect(task_idx < icon_idx);
        }
    }.run);
}
