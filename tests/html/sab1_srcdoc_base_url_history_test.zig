//! Lane sab1: HTML "document state"'s `about base URL` is stored on the
//! session history entry and restored on back/forward traversal to an
//! `about:srcdoc` document (HTML "navigate" step 22.3 / "create navigation
//! params from a srcdoc resource"; whatwg/html#9506).
//!
//! When a parent document has a non-default `<base href>` while a `srcdoc`
//! iframe is loaded, navigates the iframe away, removes `<base>`, and traverses
//! back (`history.back()`), the restored `srcdoc` document must keep its
//! snapshotted `about base URL` rather than re-reading the parent's current
//! `document.baseURI` (both non-sandboxed and sandboxed `allow-scripts`).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const LoopbackListener = @import("loopback_listener").LoopbackListener;

const Route = struct {
    path: []const u8,
    content_type: []const u8,
    body: []const u8,
};

const Server = struct {
    allocator: std.mem.Allocator,
    listener: LoopbackListener,
    thread: ?std.Thread = null,
    active: std.atomic.Value(u32) = .init(0),
    routes: []const Route,

    fn start(allocator: std.mem.Allocator, route_list: []const Route) !*Server {
        const self = try allocator.create(Server);
        errdefer allocator.destroy(self);
        self.* = .{
            .allocator = allocator,
            .listener = try LoopbackListener.open(.{}),
            .routes = route_list,
        };
        errdefer self.listener.close();
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
        return self;
    }

    fn stop(self: *Server) void {
        self.listener.stop();
        self.thread.?.join();
        self.listener.close();
        while (self.active.load(.acquire) != 0) std.Thread.yield() catch {};
        self.allocator.destroy(self);
    }

    fn proxyUrl(self: *const Server, buffer: []u8) ![]const u8 {
        return std.fmt.bufPrint(buffer, "http://127.0.0.1:{d}", .{self.listener.port()});
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
        const full_path = if (std.mem.indexOf(u8, target, "://")) |scheme_end| blk: {
            const after = target[scheme_end + 3 ..];
            const slash = std.mem.indexOfScalar(u8, after, '/') orelse break :blk "/";
            break :blk after[slash..];
        } else target;
        const path = if (std.mem.indexOfScalar(u8, full_path, '?')) |q| full_path[0..q] else full_path;

        var output: [0]u8 = .{};
        var writer = stream.writer(std.testing.io, &output);
        for (self.routes) |route| {
            if (!std.mem.eql(u8, route.path, path)) continue;
            try writer.interface.print(
                "HTTP/1.1 200 OK\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n",
                .{ route.content_type, route.body.len },
            );
            try writer.interface.writeAll(route.body);
            try writer.interface.flush();
            return;
        }
        try writer.interface.writeAll("HTTP/1.1 404 Not Found\r\nContent-Length: 9\r\nConnection: close\r\n\r\nnot found");
        try writer.interface.flush();
    }
};

const target_html =
    \\<!doctype html>
    \\<script>
    \\addEventListener('message', e => {
    \\  if (e.data === 'report') e.source.postMessage(document.baseURI, '*');
    \\});
    \\parent.postMessage('target-loaded', '*');
    \\</script>
;

const test_routes = [_]Route{
    .{ .path = "/parent.html", .content_type = "text/html", .body = "<!doctype html><head></head><body></body>" },
    .{ .path = "/target.html", .content_type = "text/html", .body = target_html },
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
    if (run.failure) |err| {
        std.debug.print("failed with {s}\n", .{@errorName(err)});
        return err;
    }
}

fn expectEval(page: *browser_mod.Context, source: []const u8, expected: []const u8) !void {
    const got = try page.evaluateScriptToString(source, testing.allocator);
    defer testing.allocator.free(got);
    if (!std.mem.eql(u8, got, expected)) {
        std.debug.print("{s}\n  expected: {s}\n  got:      {s}\n", .{ source, expected, got });
    }
    try testing.expectEqualStrings(expected, got);
}

fn runUntil(browser: *browser_mod.Browser, page: *browser_mod.Context, condition: []const u8) !void {
    var waited: usize = 0;
    while (waited < 5_000) : (waited += 10) {
        const value = try page.evaluateScriptToString(condition, testing.allocator);
        defer testing.allocator.free(value);
        if (std.mem.eql(u8, value, "true")) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    std.debug.print("never true: {s}\n", .{condition});
    return error.ConditionNeverMet;
}

fn srcdocHistoryPreservesAboutBaseUrl(sandbox_attr: ?[]const u8) !void {
    const server = try Server.start(testing.allocator, &test_routes);
    defer server.stop();
    var proxy_buf: [64]u8 = undefined;
    const proxy = try server.proxyUrl(&proxy_buf);

    const browser = try browser_mod.Browser.init(testing.allocator, .{
        .snapshot_path = "",
        .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
    });
    defer browser.deinit();

    try browser.navigate("http://localhost/parent.html", .window);
    const page = browser.current_context orelse return error.NoPage;
    try runUntil(browser, page, "document.readyState === 'complete'");

    const sandbox_js = if (sandbox_attr) |s| s else "";
    var script_buf: [2048]u8 = undefined;
    const script = try std.fmt.bufPrint(&script_buf,
        \\globalThis.events = [];
        \\globalThis.lastBase = null;
        \\addEventListener('message', e => {{
        \\  if (e.data === 'srcdoc-loaded' || e.data === 'target-loaded') {{
        \\    events.push(e.data);
        \\  }} else {{
        \\    lastBase = e.data;
        \\  }}
        \\}});
        \\globalThis.baseEl = document.createElement('base');
        \\baseEl.href = 'http://custom.base.test/';
        \\document.head.appendChild(baseEl);
        \\const iframe = document.createElement('iframe');
        \\if ('{s}') iframe.sandbox = '{s}';
        \\iframe.srcdoc = "<script>addEventListener('message', e => {{ if (e.data === 'report') e.source.postMessage(document.baseURI, '*'); if (e.data === 'go') document.getElementById('a').click(); }}); parent.postMessage('srcdoc-loaded', '*');<\/script><a id='a' href='http://localhost/target.html'>go</a>";
        \\document.body.appendChild(iframe);
    , .{ sandbox_js, sandbox_js });
    try page.runScript(script);

    try runUntil(browser, page, "events.length === 1 && events[0] === 'srcdoc-loaded'");
    try page.runScript("frames[0].postMessage('report', '*');");
    try runUntil(browser, page, "lastBase !== null");
    try expectEval(page, "lastBase", "http://custom.base.test/");

    // Navigate iframe to target.html.
    try page.runScript("lastBase = null; frames[0].postMessage('go', '*');");
    try runUntil(browser, page, "events.length === 2 && events[1] === 'target-loaded'");

    // Parent removes <base>, resetting parent's document.baseURI.
    try page.runScript("baseEl.remove();");
    try expectEval(page, "document.baseURI", "http://localhost/parent.html");

    // History back restores srcdoc: its document.baseURI must still be the
    // snapshotted about base URL, not the parent's current baseURI.
    try page.runScript("history.back();");
    try runUntil(browser, page, "events.length === 3 && events[2] === 'srcdoc-loaded'");
    try page.runScript("lastBase = null; frames[0].postMessage('report', '*');");
    try runUntil(browser, page, "lastBase !== null");
    try expectEval(page, "lastBase", "http://custom.base.test/");
}

fn nonSandboxedBody() !void {
    try srcdocHistoryPreservesAboutBaseUrl(null);
}

fn sandboxedBody() !void {
    try srcdocHistoryPreservesAboutBaseUrl("allow-scripts");
}

test "history.back() to a non-sandboxed srcdoc iframe preserves its snapshotted about base URL" {
    try onFreshThread(nonSandboxedBody);
}

test "history.back() to a sandboxed srcdoc iframe preserves its snapshotted about base URL" {
    try onFreshThread(sandboxedBody);
}
