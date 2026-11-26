//! Lane sab1: SharedArrayBuffer agent-cluster boundaries for:
//! 1. Same-origin `window.open(..., "noopener")` vs same-origin opener popup
//!    (HTML "obtain a similar-origin window agent": agent clusters are keyed
//!    per browsing context group, so a noopener popup in its own group cannot
//!    deserialize a SharedArrayBuffer from its opener, whereas an auxiliary
//!    popup with an opener shares the group and agent cluster).
//! 2. SharedWorker with COEP compatible with cross-origin isolation vs without
//!    (HTML "run a worker" onComplete steps 5-7, "create a new realm" step 5,
//!    and Safari 27.2 under golden rule 2: a COEP SharedWorker's agent cluster
//!    is cross-origin isolated, so it exposes SharedArrayBuffer and rejects
//!    cross-cluster SharedArrayBuffer messages with `messageerror` in both
//!    directions; a SharedWorker without COEP does not expose SharedArrayBuffer).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const LoopbackListener = @import("loopback_listener").LoopbackListener;

const Route = struct {
    path: []const u8,
    content_type: []const u8,
    extra_headers: []const u8 = "",
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
                "HTTP/1.1 200 OK\r\nContent-Type: {s}\r\n{s}Content-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n",
                .{ route.content_type, route.extra_headers, route.body.len },
            );
            try writer.interface.writeAll(route.body);
            try writer.interface.flush();
            return;
        }
        try writer.interface.writeAll("HTTP/1.1 404 Not Found\r\nContent-Length: 9\r\nConnection: close\r\n\r\nnot found");
        try writer.interface.flush();
    }
};

const coi_headers =
    "Cross-Origin-Opener-Policy: same-origin\r\n" ++
    "Cross-Origin-Embedder-Policy: require-corp\r\n";

const coep_header =
    "Cross-Origin-Embedder-Policy: require-corp\r\n";

const popup_html =
    \\<!doctype html>
    \\<script>
    \\const ch = new URLSearchParams(location.search).get('ch');
    \\const bc = new BroadcastChannel(ch);
    \\bc.onmessage = e => {
    \\  if (e.data === 'reported') { bc.close(); window.close(); return; }
    \\  if (e.data instanceof SharedArrayBuffer) bc.postMessage('message');
    \\};
    \\bc.onmessageerror = () => bc.postMessage('messageerror');
    \\bc.postMessage('ready');
    \\</script>
;

const sw_coep_js =
    \\let state = 'init';
    \\onconnect = initEv => {
    \\  const port = initEv.source;
    \\  port.postMessage('caps:' + typeof SharedArrayBuffer + ',' + self.crossOriginIsolated);
    \\  port.onmessage = e => {
    \\    if (e.data === 'send-from-sw') {
    \\      port.postMessage(new SharedArrayBuffer(8));
    \\    } else {
    \\      port.postMessage('unexpected:' + String(e.data));
    \\    }
    \\  };
    \\  port.onmessageerror = () => {
    \\    if (state === 'init') {
    \\      state = 'rejected';
    \\      port.postMessage('sw-rejected');
    \\    }
    \\  };
    \\};
;

const sw_none_js =
    \\onconnect = initEv => {
    \\  const port = initEv.source;
    \\  port.postMessage('caps:' + typeof SharedArrayBuffer + ',' + self.crossOriginIsolated);
    \\};
;

const routes = [_]Route{
    .{
        .path = "/opener.html",
        .content_type = "text/html",
        .extra_headers = coi_headers,
        .body = "<!doctype html><title>opener</title>",
    },
    .{
        .path = "/popup.html",
        .content_type = "text/html",
        .extra_headers = coi_headers,
        .body = popup_html,
    },
    .{
        .path = "/sw-coep.js",
        .content_type = "text/javascript",
        .extra_headers = coep_header,
        .body = sw_coep_js,
    },
    .{
        .path = "/sw-none.js",
        .content_type = "text/javascript",
        .body = sw_none_js,
    },
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

fn noopenerPopupRejectsSabBody() !void {
    const server = try Server.start(testing.allocator, &routes);
    defer server.stop();
    var proxy_buf: [64]u8 = undefined;
    const proxy = try server.proxyUrl(&proxy_buf);

    const browser = try browser_mod.Browser.init(testing.allocator, .{
        .snapshot_path = "",
        .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
    });
    defer browser.deinit();

    try browser.navigate("http://localhost/opener.html", .window);
    const page = browser.current_context orelse return error.NoPage;
    try runUntil(browser, page, "document.readyState === 'complete'");
    try expectEval(page, "String(self.crossOriginIsolated) + ',' + typeof SharedArrayBuffer", "true,function");

    // 1. noopener popup: new browsing context group -> distinct agent cluster -> messageerror.
    try page.runScript(
        \\globalThis.noopenerOutcome = null;
        \\globalThis.bcNo = new BroadcastChannel('no');
        \\bcNo.onmessage = e => {
        \\  if (e.data === 'ready') {
        \\    bcNo.postMessage(new SharedArrayBuffer(8));
        \\  } else {
        \\    globalThis.noopenerOutcome = e.data;
        \\    bcNo.postMessage('reported');
        \\    bcNo.close();
        \\  }
        \\};
        \\window.open('/popup.html?ch=no', '', 'noopener');
    );
    try runUntil(browser, page, "globalThis.noopenerOutcome !== null");
    try expectEval(page, "globalThis.noopenerOutcome", "messageerror");

    // 2. Control: auxiliary popup with opener -> same browsing context group -> message.
    try page.runScript(
        \\globalThis.openerOutcome = null;
        \\globalThis.bcOp = new BroadcastChannel('op');
        \\bcOp.onmessage = e => {
        \\  if (e.data === 'ready') {
        \\    bcOp.postMessage(new SharedArrayBuffer(8));
        \\  } else {
        \\    globalThis.openerOutcome = e.data;
        \\    bcOp.postMessage('reported');
        \\    bcOp.close();
        \\  }
        \\};
        \\globalThis.openedPopup = window.open('/popup.html?ch=op');
    );
    try runUntil(browser, page, "globalThis.openerOutcome !== null");
    try expectEval(page, "globalThis.openerOutcome", "message");
    try page.runScript("if (globalThis.openedPopup) globalThis.openedPopup.close();");
}

test "a same-origin noopener popup is in another agent cluster and cannot deserialize a SharedArrayBuffer" {
    try onFreshThread(noopenerPopupRejectsSabBody);
}

fn coepSharedWorkerSabBody() !void {
    const server = try Server.start(testing.allocator, &routes);
    defer server.stop();
    var proxy_buf: [64]u8 = undefined;
    const proxy = try server.proxyUrl(&proxy_buf);

    const browser = try browser_mod.Browser.init(testing.allocator, .{
        .snapshot_path = "",
        .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
    });
    defer browser.deinit();

    try browser.navigate("http://localhost/opener.html", .window);
    const page = browser.current_context orelse return error.NoPage;
    try runUntil(browser, page, "document.readyState === 'complete'");

    // 1. COEP SharedWorker: exposes SharedArrayBuffer, crossOriginIsolated=true,
    //    and cross-cluster SAB delivery triggers messageerror in both directions.
    try page.runScript(
        \\globalThis.coepCaps = null;
        \\globalThis.swRoundtrip = null;
        \\globalThis.swCoep = new SharedWorker('/sw-coep.js');
        \\let state = '';
        \\swCoep.port.onmessage = e => {
        \\  if (typeof e.data === 'string' && e.data.startsWith('caps:')) {
        \\    globalThis.coepCaps = e.data.slice(5);
        \\    swCoep.port.postMessage(new SharedArrayBuffer(8));
        \\  } else if (e.data === 'sw-rejected') {
        \\    state = 'expect-win-error';
        \\    swCoep.port.postMessage('send-from-sw');
        \\  } else {
        \\    globalThis.swRoundtrip = 'unexpected:' + String(e.data);
        \\  }
        \\};
        \\swCoep.port.onmessageerror = e => {
        \\  if (state === 'expect-win-error' && e.data === null && e.origin === '' && e.source === null && e.ports.length === 0) {
        \\    globalThis.swRoundtrip = 'ok';
        \\  } else {
        \\    globalThis.swRoundtrip = 'bad-error';
        \\  }
        \\};
    );
    try runUntil(browser, page, "globalThis.coepCaps !== null");
    try expectEval(page, "globalThis.coepCaps", "function,true");
    try runUntil(browser, page, "globalThis.swRoundtrip !== null");
    try expectEval(page, "globalThis.swRoundtrip", "ok");

    // 2. Control: non-COEP SharedWorker does not expose SharedArrayBuffer.
    try page.runScript(
        \\globalThis.noneCaps = null;
        \\globalThis.swNone = new SharedWorker('/sw-none.js');
        \\swNone.port.onmessage = e => {
        \\  if (typeof e.data === 'string' && e.data.startsWith('caps:')) {
        \\    globalThis.noneCaps = e.data.slice(5);
        \\  }
        \\};
    );
    try runUntil(browser, page, "globalThis.noneCaps !== null");
    try expectEval(page, "globalThis.noneCaps", "undefined,false");
}

test "a SharedWorker with COEP exposes SharedArrayBuffer and rejects cross-cluster delivery with messageerror" {
    try onFreshThread(coepSharedWorkerSabBody);
}
