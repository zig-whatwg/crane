//! Lane mcp1, batch 4b item 2: Network.setExtraHTTPHeaders as Chrome 157
//! applies it - where in a request's life the headers join it (before CORS:
//! a cross-origin fetch's preflight names them), which requests get them (a
//! navigation, a frame's, the document's fetches, a dedicated worker's
//! script and not the worker's own fetch), a redirected, a failed and a
//! cancelled navigation, the Referer entry, the validation errors, and the
//! clear - then Network.setUserAgentOverride's User-Agent on the same
//! requests - recorded by a server that notes each request it is sent.
//!
//! COMPARING with Chrome: run Chrome for Testing 157 with
//! `--headless=new --remote-debugging-port=<port> --user-data-dir=<empty dir> about:blank`
//! and this test with CRANE_CDP_TRACE_CHROME_PORT=<port>: it drives that
//! Chrome instead. CRANE_CDP_TRACE_VERBOSE prints the record.

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const browser_mod = @import("browser");
const devtools = @import("devtools");
const cdp = @import("cdp_client.zig");
const replay = @import("cdpr_replay.zig");
const LoopbackListener = @import("loopback_listener").LoopbackListener;

const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });

fn verbose() bool {
    return std.c.getenv("CRANE_CDP_TRACE_VERBOSE") != null;
}

/// A server that answers a few paths and notes each request: its method,
/// path, and the headers this test asks about.
const Recorder = struct {
    allocator: Allocator,
    listener: LoopbackListener,
    thread: ?std.Thread = null,
    active: std.atomic.Value(u32) = .init(0),
    mutex: std.Io.Mutex = .init,
    lines: std.ArrayList([]u8) = .empty,
    /// Lets /slow's connection go: it is held until the test has cancelled
    /// the navigation that asked for it (bounded, so `stop` never waits on
    /// a test that failed first).
    release: std.atomic.Value(bool) = .init(false),

    const page =
        \\<!doctype html><title>headers</title>
    ;
    const worker = "fetch('/from-worker').then(() => postMessage('done'), () => postMessage('failed'));";
    const shared_worker = "onconnect = e => e.ports[0].postMessage('done');";

    fn start(allocator: Allocator) !*Recorder {
        const self = try allocator.create(Recorder);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .listener = try LoopbackListener.open(.{}) };
        errdefer self.listener.close();
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
        return self;
    }

    fn stop(self: *Recorder) void {
        self.release.store(true, .release);
        self.listener.stop();
        self.thread.?.join();
        self.listener.close();
        while (self.active.load(.acquire) != 0) std.Thread.yield() catch {};
        for (self.lines.items) |l| self.allocator.free(l);
        self.lines.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    fn port(self: *const Recorder) u16 {
        return self.listener.port();
    }

    /// The lines noted since `from`, joined, and how many there are now.
    fn since(self: *Recorder, arena: Allocator, from: usize) !struct { text: []const u8, count: usize } {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const got = self.lines.items[@min(from, self.lines.items.len)..];
        var copy: std.ArrayList([]const u8) = .empty;
        for (got) |l| try copy.append(arena, try arena.dupe(u8, l));
        // Order across connections is the server's: sorted for the record.
        std.mem.sort([]const u8, copy.items, {}, struct {
            fn less(_: void, x: []const u8, y: []const u8) bool {
                return std.mem.lessThan(u8, x, y);
            }
        }.less);
        return .{ .text = try std.mem.join(arena, " | ", copy.items), .count = self.lines.items.len };
    }

    fn count(self: *Recorder) usize {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        return self.lines.items.len;
    }

    fn serve(self: *Recorder) void {
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

    fn answerAndClose(self: *Recorder, stream: std.Io.net.Stream) void {
        defer _ = self.active.fetchSub(1, .acq_rel);
        defer stream.close(std.testing.io);
        self.answer(stream) catch {};
    }

    fn header(head: []const u8, name: []const u8) []const u8 {
        var lines = std.mem.splitSequence(u8, head, "\r\n");
        _ = lines.next();
        while (lines.next()) |line| {
            const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
            if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, line[0..colon], " "), name)) return std.mem.trim(u8, line[colon + 1 ..], " ");
        }
        return "-";
    }

    fn answer(self: *Recorder, stream: std.Io.net.Stream) !void {
        var input: [16384]u8 = undefined;
        var reader = stream.reader(std.testing.io, &input);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) try reader.interface.fillMore();
        const head = reader.interface.buffered();
        const line_end = std.mem.indexOf(u8, head, "\r\n") orelse return;
        var parts = std.mem.tokenizeScalar(u8, head[0..line_end], ' ');
        const method = parts.next() orelse return;
        const target = parts.next() orelse return;
        const path = if (std.mem.indexOfScalar(u8, target, '?')) |q| target[0..q] else target;
        if (!std.mem.eql(u8, path, "/favicon.ico")) {
            const host = header(head, "host");
            const host_name = if (std.mem.indexOfScalar(u8, host, ':')) |c| host[0..c] else host;
            // The User-Agent only when it is the test's override (each
            // browser's own differs).
            const user_agent = header(head, "user-agent");
            const line = try std.fmt.allocPrint(self.allocator, "{s} {s}{s} x-test={s} acrh={s} referer={s}{s}{s}", .{
                method,                                         host_name,                            path,                                                             header(head, "x-test"),
                header(head, "access-control-request-headers"), refererPath(header(head, "referer")), if (std.mem.startsWith(u8, user_agent, "Probe/")) " ua=" else "", if (std.mem.startsWith(u8, user_agent, "Probe/")) user_agent else "",
            });
            std.Io.Threaded.mutexLockUncancelable(&self.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.mutex);
            self.lines.append(self.allocator, line) catch self.allocator.free(line);
        }
        // An answer that is not HTTP: the navigation fails (Chrome resends
        // a request whose connection closed with no answer; this it does not).
        if (std.mem.eql(u8, path, "/invalid")) {
            var raw: [64]u8 = undefined;
            var bad = stream.writer(std.testing.io, &raw);
            try bad.interface.writeAll("nonsense\r\n\r\n");
            return bad.interface.flush();
        }
        // Held until the navigation that asked is cancelled (10 s at most).
        if (std.mem.eql(u8, path, "/slow")) {
            var waited: u32 = 0;
            while (!self.release.load(.acquire) and waited < 1000) : (waited += 1) {
                std.Io.sleep(std.testing.io, .fromMilliseconds(10), .awake) catch {};
            }
            return;
        }
        const origin = header(head, "origin");
        var output: [4096]u8 = undefined;
        var writer = stream.writer(std.testing.io, &output);
        const out = &writer.interface;
        if (std.mem.eql(u8, path, "/redirect")) {
            try out.writeAll("HTTP/1.1 302 Found\r\nLocation: /page.html\r\nContent-Length: 0\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n");
            return out.flush();
        }
        const is_page = std.mem.eql(u8, path, "/page.html");
        const is_worker = std.mem.eql(u8, path, "/worker.js");
        const is_shared = std.mem.eql(u8, path, "/shared.js");
        const body: []const u8 = if (is_page) page else if (is_worker) worker else if (is_shared) shared_worker else "ok";
        const content_type: []const u8 = if (is_page) "text/html" else if (is_worker or is_shared) "text/javascript" else "text/plain";
        // CORS open to the asking origin, x-test allowed: what reaches the
        // server is then decided by the browser alone.
        try out.print("HTTP/1.1 200 OK\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nAccess-Control-Allow-Origin: {s}\r\nAccess-Control-Allow-Headers: x-test\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n", .{ content_type, body.len, if (std.mem.eql(u8, origin, "-")) "*" else origin });
        if (!std.mem.eql(u8, method, "OPTIONS")) try out.writeAll(body);
        try out.flush();
    }

    /// A Referer's path ("-" for none): the port differs per run.
    fn refererPath(referer: []const u8) []const u8 {
        if (std.mem.eql(u8, referer, "-")) return referer;
        const scheme_end = std.mem.indexOf(u8, referer, "://") orelse return referer;
        const rest = referer[scheme_end + 3 ..];
        return if (std.mem.indexOfScalar(u8, rest, '/')) |slash| rest[slash..] else "/";
    }
};

/// The browser target's WebSocket path on `port` (/json/version).
fn browserPath(allocator: Allocator, port: u16) ![]u8 {
    var version = try cdp.httpGet(allocator, port, "/json/version", &.{"Host: 127.0.0.1"});
    defer version.deinit();
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, version.body, .{});
    defer parsed.deinit();
    const ws = parsed.value.object.get("webSocketDebuggerUrl").?.string;
    return allocator.dupe(u8, ws[std.mem.indexOf(u8, ws, "/devtools/").?..]);
}

const Probe = struct {
    arena: Allocator,
    rec: replay.Recorder,
    server: *Recorder,
    session: []const u8 = "",

    fn attach(self: *Probe) !void {
        const targets = try self.rec.result(try self.rec.send("Target.getTargets", "{}", ""));
        var target_id: []const u8 = "";
        for (targets.object.get("targetInfos").?.array.items) |info| {
            if (std.mem.eql(u8, info.object.get("type").?.string, "page")) target_id = try self.arena.dupe(u8, info.object.get("targetId").?.string);
        }
        if (target_id.len == 0) return error.NoPage;
        const params = try std.fmt.allocPrint(self.arena, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{target_id});
        const attached = try self.rec.result(try self.rec.send("Target.attachToTarget", params, ""));
        self.session = try self.arena.dupe(u8, attached.object.get("sessionId").?.string);
        _ = try self.rec.awaitResponse(try self.rec.send("Page.enable", "{}", self.session));
        _ = try self.rec.awaitResponse(try self.rec.send("Network.enable", "{}", self.session));
    }

    /// Network.setExtraHTTPHeaders: "" on success, else "<code> <message>".
    fn setHeaders(self: *Probe, headers_json: []const u8) ![]const u8 {
        const params = try std.fmt.allocPrint(self.arena, "{{\"headers\":{s}}}", .{headers_json});
        const answer = self.rec.at(try self.rec.awaitResponse(try self.rec.send("Network.setExtraHTTPHeaders", params, self.session)));
        const e = cdp.at(answer, "error") orelse return "";
        return std.fmt.allocPrint(self.arena, "{d} {s}", .{ (cdp.at(e, "code") orelse std.json.Value{ .integer = 0 }).integer, cdp.stringAt(e, "message") orelse "" });
    }

    /// Run `expression` (awaited); then the requests the server saw.
    fn requests(self: *Probe, name: []const u8, expression: []const u8) ![]const u8 {
        const from = self.server.count();
        const params = try std.fmt.allocPrint(self.arena, "{{\"expression\":{f},\"awaitPromise\":true,\"returnByValue\":true}}", .{std.json.fmt(expression, .{})});
        _ = try self.rec.awaitResponse(try self.rec.send("Runtime.evaluate", params, self.session));
        const seen = try self.server.since(self.arena, from);
        if (verbose()) std.debug.print("mcp1_extra_headers: {s}: {s}\n", .{ name, seen.text });
        return std.fmt.allocPrint(self.arena, "{s}: {s}", .{ name, seen.text });
    }

    /// Network.setUserAgentOverride: "" on success, else "<code> <message>".
    fn setUserAgent(self: *Probe, user_agent: []const u8) ![]const u8 {
        return self.command("Network.setUserAgentOverride", try std.fmt.allocPrint(self.arena, "{{\"userAgent\":{f}}}", .{std.json.fmt(user_agent, .{})}));
    }

    /// Any command on the page session: "<method>" on success, else
    /// "<method>: <code> <message>".
    fn command(self: *Probe, method: []const u8, params: []const u8) ![]const u8 {
        const answer = self.rec.at(try self.rec.awaitResponse(try self.rec.send(method, params, self.session)));
        const e = cdp.at(answer, "error") orelse return "";
        return std.fmt.allocPrint(self.arena, "{s}: {d} {s}", .{ method, (cdp.at(e, "code") orelse std.json.Value{ .integer = 0 }).integer, cdp.stringAt(e, "message") orelse "" });
    }

    fn navigate(self: *Probe, name: []const u8, url: []const u8) ![]const u8 {
        const from = self.server.count();
        const params = try std.fmt.allocPrint(self.arena, "{{\"url\":{f}}}", .{std.json.fmt(url, .{})});
        // The load after this navigation's answer: one from an error page
        // a failed navigation left could come later than its answer.
        const answered = try self.rec.awaitResponse(try self.rec.send("Page.navigate", params, self.session));
        _ = try self.rec.awaitEvent("Page.loadEventFired", self.session, answered, &.{});
        const seen = try self.server.since(self.arena, from);
        if (verbose()) std.debug.print("mcp1_extra_headers: {s}: {s}\n", .{ name, seen.text });
        return std.fmt.allocPrint(self.arena, "{s}: {s}", .{ name, seen.text });
    }

    /// A navigation that fails: Page.navigate's answer (its errorText said
    /// only as whether there is one), and what the server saw.
    fn navigateFailing(self: *Probe, name: []const u8, url: []const u8) ![]const u8 {
        const from = self.server.count();
        const params = try std.fmt.allocPrint(self.arena, "{{\"url\":{f}}}", .{std.json.fmt(url, .{})});
        const answer = self.rec.at(try self.rec.awaitResponse(try self.rec.send("Page.navigate", params, self.session)));
        const failed = if (cdp.at(answer, "result")) |r| cdp.at(r, "errorText") != null else false;
        try self.awaitSeen(from);
        const seen = try self.server.since(self.arena, from);
        if (verbose()) std.debug.print("mcp1_extra_headers: {s}: {s} failed={}\n", .{ name, seen.text, failed });
        return std.fmt.allocPrint(self.arena, "{s}: {s} failed={}", .{ name, seen.text, failed });
    }

    /// A frame's navigation cancelled in flight: the frame is made, the
    /// server holds its request, and the frame is removed once the request
    /// is in.
    fn cancelledFrame(self: *Probe, name: []const u8) ![]const u8 {
        const from = self.server.count();
        const add = "(() => { const f = document.createElement('iframe'); f.id = 'slow'; f.src = '/slow'; document.body.appendChild(f); return 1; })()";
        const remove = "(() => { document.getElementById('slow').remove(); return 1; })()";
        _ = try self.rec.awaitResponse(try self.rec.send("Runtime.evaluate", try std.fmt.allocPrint(self.arena, "{{\"expression\":{f},\"returnByValue\":true}}", .{std.json.fmt(add, .{})}), self.session));
        try self.awaitSeen(from);
        _ = try self.rec.awaitResponse(try self.rec.send("Runtime.evaluate", try std.fmt.allocPrint(self.arena, "{{\"expression\":{f},\"returnByValue\":true}}", .{std.json.fmt(remove, .{})}), self.session));
        self.server.release.store(true, .release);
        const seen = try self.server.since(self.arena, from);
        if (verbose()) std.debug.print("mcp1_extra_headers: {s}: {s}\n", .{ name, seen.text });
        return std.fmt.allocPrint(self.arena, "{s}: {s}", .{ name, seen.text });
    }

    /// Until the server has seen a request since `from` (10 s at most).
    fn awaitSeen(self: *Probe, from: usize) !void {
        var waited: u32 = 0;
        while (self.server.count() <= from) : (waited += 1) {
            if (waited >= 1000) return error.NoRequest;
            std.Io.sleep(std.testing.io, .fromMilliseconds(10), .awake) catch {};
        }
    }
};

fn check(allocator: Allocator, arena: Allocator, client: *cdp.Client, server: *Recorder) !void {
    var probe: Probe = .{ .arena = arena, .rec = replay.Recorder.init(allocator, client), .server = server };
    defer probe.rec.deinit();
    try probe.attach();
    const p = server.port();
    var record: std.ArrayList([]const u8) = .empty;

    const page_url = try std.fmt.allocPrint(arena, "http://127.0.0.1:{d}/page.html", .{p});
    const worker = "new Promise(r => { const w = new Worker('/worker.js'); w.onmessage = e => r(e.data); })";
    const frame = "new Promise(r => { const f = document.createElement('iframe'); f.onload = () => r(1); f.src = '/frame.html'; document.body.appendChild(f); })";
    // A shared worker of its own name each time, so its script is fetched.
    const shared = "new Promise(r => {{ const w = new SharedWorker('/shared.js', '{s}'); w.port.onmessage = e => r(e.data); }})";
    try record.append(arena, try probe.setHeaders("{\"X-Test\":\"one\"}"));
    try record.append(arena, try probe.navigate("navigate", page_url));
    try record.append(arena, try probe.requests("same-origin", "fetch('/same').then(r => r.status)"));
    try record.append(arena, try probe.requests("cross-origin", try std.fmt.allocPrint(arena, "fetch('http://localhost:{d}/cross').then(r => r.status, e => 'failed')", .{p})));
    try record.append(arena, try probe.requests("worker", worker));
    try record.append(arena, try probe.requests("frame", frame));
    try record.append(arena, try probe.requests("shared worker", try std.fmt.allocPrint(arena, shared, .{"headers"})));
    try record.append(arena, try probe.cancelledFrame("cancelled frame"));
    try record.append(arena, try probe.navigateFailing("invalid response", try std.fmt.allocPrint(arena, "http://127.0.0.1:{d}/invalid", .{p})));
    try record.append(arena, try probe.navigate("redirect", try std.fmt.allocPrint(arena, "http://127.0.0.1:{d}/redirect", .{p})));
    try record.append(arena, try probe.setHeaders("{\"Referer\":\"http://example.com/ref\"}"));
    try record.append(arena, try probe.requests("referer", "fetch('/ref').then(r => r.status)"));
    try record.append(arena, try probe.setHeaders("{\"Bad Name\":\"x\"}"));
    try record.append(arena, try probe.setHeaders("{\"X-Test\":\"a\\nb\"}"));
    try record.append(arena, try probe.setHeaders("{\"X-Test\":1}"));
    try record.append(arena, try probe.setHeaders("{}"));
    try record.append(arena, try probe.requests("cleared", "fetch('/cleared').then(r => r.status)"));
    // The tab's User-Agent override reaches the same requests.
    try record.append(arena, try probe.setUserAgent("Probe/1"));
    try record.append(arena, try probe.navigate("ua navigate", page_url));
    try record.append(arena, try probe.requests("ua worker", worker));
    try record.append(arena, try probe.requests("ua frame", frame));
    try record.append(arena, try probe.requests("ua shared worker", try std.fmt.allocPrint(arena, shared, .{"ua"})));
    // The headers apply while the session's Network domain is enabled;
    // Network.disable drops them, and a set while disabled waits for enable.
    try record.append(arena, try probe.setHeaders("{\"X-Test\":\"two\"}"));
    try record.append(arena, try probe.requests("enabled", "fetch('/enabled').then(r => r.status)"));
    try record.append(arena, try probe.command("Network.disable", "{}"));
    try record.append(arena, try probe.requests("disabled", "fetch('/disabled').then(r => r.status)"));
    try record.append(arena, try probe.setHeaders("{\"X-Test\":\"three\"}"));
    try record.append(arena, try probe.requests("set while disabled", "fetch('/while-disabled').then(r => r.status)"));
    try record.append(arena, try probe.command("Network.enable", "{}"));
    try record.append(arena, try probe.requests("enabled again", "fetch('/enabled-again').then(r => r.status)"));

    const all = try std.mem.join(arena, "\n", record.items);
    if (verbose()) std.debug.print("mcp1_extra_headers: ALL\n{s}\n", .{all});
    try testing.expectEqualStrings(try std.mem.join(arena, "\n", &chrome_157), all);
}

/// What Chrome for Testing 157.0.8103.78 answered (recorded on chat.local
/// with CRANE_CDP_TRACE_CHROME_PORT, 2026-11-24), one line each: "" for a
/// command that succeeded. The headers join a request before CORS (the
/// cross-origin fetch's preflight names x-test). A navigation, a frame's,
/// a redirected, a failed and a cancelled one carry them, and so does a
/// worker's script request (the ancestor frame's overrides: Chrome's
/// devtools_instrumentation OnWorkerMainScriptRequestWillBeSent). A
/// dedicated worker's own fetch does not. The User-Agent override reaches
/// the same requests. The headers apply only while Network is enabled;
/// Network.disable clears them.
const chrome_157 = [_][]const u8{
    "",
    "navigate: GET 127.0.0.1/page.html x-test=one acrh=- referer=-",
    "same-origin: GET 127.0.0.1/same x-test=one acrh=- referer=/page.html",
    "cross-origin: GET localhost/cross x-test=one acrh=- referer=/ | OPTIONS localhost/cross x-test=- acrh=x-test referer=/",
    "worker: GET 127.0.0.1/from-worker x-test=- acrh=- referer=/worker.js | GET 127.0.0.1/worker.js x-test=one acrh=- referer=/page.html",
    "frame: GET 127.0.0.1/frame.html x-test=one acrh=- referer=/page.html",
    "shared worker: GET 127.0.0.1/shared.js x-test=one acrh=- referer=/page.html",
    "cancelled frame: GET 127.0.0.1/slow x-test=one acrh=- referer=/page.html",
    "invalid response: GET 127.0.0.1/invalid x-test=one acrh=- referer=- failed=true",
    "redirect: GET 127.0.0.1/page.html x-test=one acrh=- referer=- | GET 127.0.0.1/redirect x-test=one acrh=- referer=-",
    "",
    "referer: GET 127.0.0.1/ref x-test=- acrh=- referer=/ref",
    "-32602 Invalid header name",
    "-32602 Invalid header value",
    "-32602 Invalid header value, string expected",
    "",
    "cleared: GET 127.0.0.1/cleared x-test=- acrh=- referer=/page.html",
    "",
    "ua navigate: GET 127.0.0.1/page.html x-test=- acrh=- referer=- ua=Probe/1",
    "ua worker: GET 127.0.0.1/from-worker x-test=- acrh=- referer=/worker.js ua=Probe/1 | GET 127.0.0.1/worker.js x-test=- acrh=- referer=/page.html ua=Probe/1",
    "ua frame: GET 127.0.0.1/frame.html x-test=- acrh=- referer=/page.html ua=Probe/1",
    "ua shared worker: GET 127.0.0.1/shared.js x-test=- acrh=- referer=/page.html ua=Probe/1",
    "",
    "enabled: GET 127.0.0.1/enabled x-test=two acrh=- referer=/page.html ua=Probe/1",
    "",
    "disabled: GET 127.0.0.1/disabled x-test=- acrh=- referer=/page.html ua=Probe/1",
    "",
    "set while disabled: GET 127.0.0.1/while-disabled x-test=- acrh=- referer=/page.html ua=Probe/1",
    "",
    "enabled again: GET 127.0.0.1/enabled-again x-test=three acrh=- referer=/page.html ua=Probe/1",
};

test "Network.setExtraHTTPHeaders: which requests carry the headers and where - before CORS, as Chrome's" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const server = try Recorder.start(allocator);
    defer server.stop();

    if (std.c.getenv("CRANE_CDP_TRACE_CHROME_PORT")) |port_text| {
        const port = try std.fmt.parseInt(u16, std.mem.span(port_text), 10);
        const path = try browserPath(allocator, port);
        defer allocator.free(path);
        const client = try cdp.Client.openWebSocket(allocator, port, path, null);
        defer client.close();
        if (client.upgrade_status != 101) return error.UpgradeRefused;
        return check(allocator, arena_state.allocator(), client, server);
    }

    const host = try browser_mod.BrowserHost.start(allocator, .{});
    defer host.stop();
    const devtools_server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer devtools_server.stop();
    const path = try browserPath(allocator, devtools_server.port);
    defer allocator.free(path);
    const client = try cdp.Client.openWebSocket(allocator, devtools_server.port, path, null);
    defer client.close();
    try check(allocator, arena_state.allocator(), client, server);
}
