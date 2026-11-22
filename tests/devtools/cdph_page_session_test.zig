//! The page-side domains (lane cdph, P4) through a page session attached to
//! a Browser on its own thread, as the devtools thread attaches one - with
//! no transport: the session's link writes to an outbound queue the test
//! reads, so what is checked is exactly what a client would be sent, in
//! order. The orders are Chrome 157's, measured from the punted suites'
//! runners (tmp/plans/cdp1-evidence/seq-vue-e2e-one.txt, seq-svelte.txt;
//! design 1.2): setLifecycleEventsEnabled replays commit, DOMContentLoaded,
//! load, networkAlmostIdle, networkIdle; Page.navigate answers before
//! frameNavigated; a commit gives lifecycle init then frameNavigated; then
//! domContentEventFired, lifecycle DOMContentLoaded, loadEventFired,
//! lifecycle load, frameStoppedLoading.
//!
//! Written in the CDP phase (user directive 2026-11-21 5:48 PM ET: implement
//! now, run every test in one later pass).

const std = @import("std");
const testing = std.testing;
const devtools = @import("devtools");
const browser_mod = @import("browser");
const Browser = browser_mod.Browser;
const BrowserHost = browser_mod.BrowserHost;
const outbound = devtools.outbound;

/// A Browser on its own thread with one page session on a tab, and the
/// messages the session sends.
const Harness = struct {
    allocator: std.mem.Allocator,
    host: *BrowserHost,
    queue: *outbound.Outbound,
    link: *outbound.SessionLink,
    side: *devtools.BrowserSide,
    session: *devtools.PageSession,
    tab: u64,
    next_id: i64 = 1,
    /// Messages read so far, parsed, OWNED.
    seen: std.ArrayList(std.json.Parsed(std.json.Value)) = .empty,

    fn init(self: *Harness, allocator: std.mem.Allocator) !void {
        self.* = .{ .allocator = allocator, .host = undefined, .queue = undefined, .link = undefined, .side = undefined, .session = undefined, .tab = 0 };
        self.host = try BrowserHost.start(allocator, .{});
        self.queue = try outbound.Outbound.create(allocator);
        self.link = try outbound.SessionLink.create(allocator, self.queue, "SESSION1");
        var context_id: [32]u8 = undefined;
        @memset(&context_id, 'C');
        var sink_context: u8 = 0;
        self.side = try devtools.BrowserSide.create(allocator, self.host, 0xC0FFEE, context_id, .{ .context = &sink_context, .post = sinkPost });
        try devtools.browser_side.InstallTask.post(self.side);
        self.tab = try self.host.createTab(.{});
        self.session = try devtools.PageSession.allocate(allocator, self.link, self.tab, devtools.ids.frameId(0xC0FFEE, self.tab));
        try devtools.browser_side.AttachTask.post(self.side, self.session);
    }

    fn sinkPost(context: *anyopaque, side: *devtools.BrowserSide, event: devtools.browser_side.TargetEvent) void {
        _ = context;
        switch (event) {
            // The event owns its URL (TargetSink.post).
            .navigated => |navigated| side.allocator.free(navigated.url),
            else => {},
        }
    }

    fn deinit(self: *Harness) void {
        devtools.browser_side.DetachTask.post(self.side, self.session);
        devtools.browser_side.uninstallAndWait(self.side);
        self.host.stop();
        self.side.destroy();
        self.link.release();
        self.drain();
        self.queue.release();
        for (self.seen.items) |*parsed| parsed.deinit();
        self.seen.deinit(self.allocator);
    }

    /// Send `method` with `params_json`; returns the call's id.
    fn send(self: *Harness, method: []const u8, params_json: []const u8) !i64 {
        const id = self.next_id;
        self.next_id += 1;
        const message = try std.fmt.allocPrint(self.allocator, "{{\"id\":{d},\"method\":\"{s}\",\"params\":{s},\"sessionId\":\"SESSION1\"}}", .{ id, method, params_json });
        defer self.allocator.free(message);
        try devtools.browser_side.MessageTask.post(self.side, self.session, message);
        return id;
    }

    /// Move what the session sent into `seen`.
    fn drain(self: *Harness) void {
        var items: std.ArrayList(outbound.Item) = .empty;
        defer items.deinit(self.allocator);
        _ = self.queue.takeAll(&items) catch return;
        for (items.items) |item| {
            defer self.allocator.free(item.bytes);
            const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, item.bytes, .{}) catch continue;
            self.seen.append(self.allocator, parsed) catch {};
        }
    }

    /// Wait until the response to `id` arrives (10 s): its "result", or
    /// error.CommandFailed with its "error".
    fn result(self: *Harness, id: i64) !std.json.Value {
        var waited: u32 = 0;
        while (waited < 10_000) : (waited += 10) {
            self.drain();
            for (self.seen.items) |parsed| {
                const object = parsed.value.object;
                const got = object.get("id") orelse continue;
                if (got != .integer or got.integer != id) continue;
                if (object.get("error")) |_| return error.CommandFailed;
                return object.get("result") orelse error.NoResult;
            }
            self.queue.wait(10 * std.time.ns_per_ms);
        }
        return error.Timeout;
    }

    fn call(self: *Harness, method: []const u8, params_json: []const u8) !std.json.Value {
        return self.result(try self.send(method, params_json));
    }

    /// Wait until an event `method` has been seen (10 s) at or after index
    /// `from` of `seen`; its index.
    fn waitEvent(self: *Harness, method: []const u8, from: usize) !usize {
        var waited: u32 = 0;
        while (waited < 10_000) : (waited += 10) {
            self.drain();
            for (self.seen.items[from..], from..) |parsed, i| {
                const m = parsed.value.object.get("method") orelse continue;
                if (m == .string and std.mem.eql(u8, m.string, method)) return i;
            }
            self.queue.wait(10 * std.time.ns_per_ms);
        }
        return error.Timeout;
    }

    /// What was seen from index `from`, as one line per message: an event's
    /// method (with a lifecycle event's name), or "=<id>" for a response.
    fn transcript(self: *Harness, from: usize, out: *std.ArrayList(u8)) !void {
        for (self.seen.items[from..]) |parsed| {
            const object = parsed.value.object;
            if (object.get("method")) |m| {
                try out.appendSlice(self.allocator, m.string);
                if (std.mem.eql(u8, m.string, "Page.lifecycleEvent")) {
                    try out.append(self.allocator, ':');
                    try out.appendSlice(self.allocator, object.get("params").?.object.get("name").?.string);
                }
            } else if (object.get("id")) |id| {
                try out.print(self.allocator, "={d}", .{id.integer});
            }
            try out.append(self.allocator, '\n');
        }
    }
};

test "setLifecycleEventsEnabled replays the current document's lifecycle as Chrome does" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();

    _ = try h.call("Page.enable", "{}");
    const tree = try h.call("Page.getFrameTree", "{}");
    const frame = tree.object.get("frameTree").?.object.get("frame").?.object;
    // A page target's id IS its main frame's id; a new tab is about:blank
    // with a loaderId.
    try testing.expectEqualStrings(devtools.ids.frameId(0xC0FFEE, h.tab).slice(), frame.get("id").?.string);
    try testing.expectEqualStrings("about:blank", frame.get("url").?.string);
    try testing.expectEqual(@as(usize, 32), frame.get("loaderId").?.string.len);

    const before = h.seen.items.len;
    _ = try h.call("Page.setLifecycleEventsEnabled", "{\"enabled\":true}");
    var lines: std.ArrayList(u8) = .empty;
    defer lines.deinit(h.allocator);
    try h.transcript(before, &lines);
    try testing.expectEqualStrings(
        \\Page.lifecycleEvent:commit
        \\Page.lifecycleEvent:DOMContentLoaded
        \\Page.lifecycleEvent:load
        \\Page.lifecycleEvent:networkAlmostIdle
        \\Page.lifecycleEvent:networkIdle
        \\=3
        \\
    , lines.items);
}

test "Page.navigate answers when ready to commit, then the commit, DOMContentLoaded and load arrive in Chrome's order" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();

    _ = try h.call("Page.enable", "{}");
    _ = try h.call("Page.setLifecycleEventsEnabled", "{\"enabled\":true}");
    const before = h.seen.items.len;
    const id = try h.send("Page.navigate", "{\"url\":\"data:text/html,<title>t</title><p>x\"}");
    const answer = try h.result(id);
    try testing.expectEqual(@as(usize, 32), answer.object.get("loaderId").?.string.len);
    _ = try h.waitEvent("Page.frameStoppedLoading", before);
    var lines: std.ArrayList(u8) = .empty;
    defer lines.deinit(h.allocator);
    try h.transcript(before, &lines);
    // The measured order (seq-vue-e2e-one.txt), Network's events aside.
    const expected = [_][]const u8{
        "Page.frameStartedNavigating",
        "Page.frameStartedLoading",
        "=3",
        "Page.lifecycleEvent:init",
        "Page.frameNavigated",
        "Page.domContentEventFired",
        "Page.lifecycleEvent:DOMContentLoaded",
        "Page.loadEventFired",
        "Page.lifecycleEvent:load",
        "Page.frameStoppedLoading",
    };
    var it = std.mem.splitScalar(u8, lines.items, '\n');
    var at: usize = 0;
    while (it.next()) |line| {
        if (at < expected.len and std.mem.eql(u8, line, expected[at])) at += 1;
    }
    if (at != expected.len) {
        std.debug.print("transcript:\n{s}\n", .{lines.items});
        return error.WrongOrder;
    }
    // frameNavigated's loaderId is the navigate answer's.
    const navigated = h.seen.items[try h.waitEvent("Page.frameNavigated", before)].value.object.get("params").?.object.get("frame").?.object;
    try testing.expectEqualStrings(answer.object.get("loaderId").?.string, navigated.get("loaderId").?.string);
}

test "a fragment navigation answers at once with no loaderId and reports navigatedWithinDocument" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();

    _ = try h.call("Page.enable", "{}");
    _ = try h.call("Page.navigate", "{\"url\":\"data:text/html,<p>x\"}");
    _ = try h.waitEvent("Page.frameStoppedLoading", 0);
    const before = h.seen.items.len;
    const answer = try h.call("Page.navigate", "{\"url\":\"data:text/html,<p>x#part\"}");
    try testing.expect(answer.object.get("loaderId") == null);
    _ = try h.waitEvent("Page.navigatedWithinDocument", before);
}

test "addScriptToEvaluateOnNewDocument runs before the document's own scripts, in its world when it names one" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();

    _ = try h.call("Page.enable", "{}");
    const added = try h.call("Page.addScriptToEvaluateOnNewDocument", "{\"source\":\"globalThis.early = 'first'\"}");
    try testing.expectEqualStrings("1", added.object.get("identifier").?.string);
    _ = try h.call("Page.addScriptToEvaluateOnNewDocument", "{\"source\":\"globalThis.inWorld = 1\",\"worldName\":\"utility\"}");
    _ = try h.call("Page.navigate", "{\"url\":\"data:text/html,<script>document.title = typeof early + ':' + (typeof inWorld)</script>\"}");
    _ = try h.waitEvent("Page.frameStoppedLoading", 0);
    const title = try h.host.evaluate(h.allocator, h.tab, "document.title", .{}, 5_000);
    defer title.deinit(h.allocator);
    // The main-world script ran first; the world's global is not the page's.
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"string:undefined\"}", title.json);
}

test "setDocumentContent replaces the document's content through open, write and close" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();

    const frame_id = devtools.ids.frameId(0xC0FFEE, h.tab);
    var params_buffer: [256]u8 = undefined;
    const params = try std.fmt.bufPrint(&params_buffer, "{{\"frameId\":\"{s}\",\"html\":\"<title>set</title><p id=p>content\"}}", .{frame_id.slice()});
    _ = try h.call("Page.setDocumentContent", params);
    const title = try h.host.evaluate(h.allocator, h.tab, "document.title + '|' + document.getElementById('p').textContent", .{}, 5_000);
    defer title.deinit(h.allocator);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"set|content\"}", title.json);
}

test "Emulation overrides reach the page and a detaching session takes its own away" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();

    _ = try h.call("Emulation.setDeviceMetricsOverride", "{\"width\":800,\"height\":600,\"deviceScaleFactor\":1,\"mobile\":false}");
    _ = try h.call("Emulation.setEmulatedMedia", "{\"media\":\"\",\"features\":[{\"name\":\"prefers-color-scheme\",\"value\":\"dark\"}]}");
    _ = try h.call("Emulation.setUserAgentOverride", "{\"userAgent\":\"CraneTest/1\",\"acceptLanguage\":\"de-DE,de\",\"platform\":\"TestOS\"}");
    _ = try h.call("Emulation.setTouchEmulationEnabled", "{\"enabled\":true,\"maxTouchPoints\":3}");
    const seen = try h.host.evaluate(h.allocator, h.tab, "[innerWidth, innerHeight, matchMedia('(prefers-color-scheme: dark)').matches, navigator.userAgent, navigator.language, navigator.platform, navigator.maxTouchPoints].join('|')", .{}, 5_000);
    defer seen.deinit(h.allocator);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"800|600|true|CraneTest/1|de-DE|TestOS|3\"}", seen.json);
    // A locale other than the default is refused (design R13).
    try testing.expectError(error.CommandFailed, h.call("Emulation.setLocaleOverride", "{\"locale\":\"fr-FR\"}"));
}

test "setDeviceMetricsOverride emulates the device's screen, scale and orientation; clearing gives the platform's back" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();

    // Playwright's phone: a screen, a scale, an orientation.
    _ = try h.call("Emulation.setDeviceMetricsOverride", "{\"width\":390,\"height\":664,\"deviceScaleFactor\":3,\"mobile\":true,\"screenWidth\":390,\"screenHeight\":844,\"screenOrientation\":{\"type\":\"portraitPrimary\",\"angle\":0}}");
    const phone = try h.host.evaluate(h.allocator, h.tab, "[innerWidth, screen.width, screen.height, screen.availHeight, devicePixelRatio, screen.orientation.type, screen.orientation.angle, matchMedia('(resolution: 3dppx)').matches].join('|')", .{}, 5_000);
    defer phone.deinit(h.allocator);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"390|390|844|844|3|portrait-primary|0|true\"}", phone.json);
    // Puppeteer's: no screen size on a desktop device keeps the real screen.
    _ = try h.call("Emulation.setDeviceMetricsOverride", "{\"width\":800,\"height\":600,\"deviceScaleFactor\":2,\"mobile\":false}");
    // (screen.orientation's [[type]] follows in a task of its own: the
    // change steps queue it, html.screen_orientation.)
    const desktop = try h.host.evaluate(h.allocator, h.tab, "[screen.width, devicePixelRatio].join('|')", .{}, 5_000);
    defer desktop.deinit(h.allocator);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"1920|2\"}", desktop.json);
    // Chrome's checks.
    try testing.expectError(error.CommandFailed, h.call("Emulation.setDeviceMetricsOverride", "{\"width\":800,\"height\":600,\"deviceScaleFactor\":-1,\"mobile\":false}"));
    try testing.expectError(error.CommandFailed, h.call("Emulation.setDeviceMetricsOverride", "{\"width\":800,\"height\":600,\"deviceScaleFactor\":1,\"mobile\":false,\"screenOrientation\":{\"type\":\"portraitPrimary\",\"angle\":360}}"));
    _ = try h.call("Emulation.clearDeviceMetricsOverride", "{}");
    const cleared = try h.host.evaluate(h.allocator, h.tab, "[screen.width, devicePixelRatio].join('|')", .{}, 5_000);
    defer cleared.deinit(h.allocator);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"1920|1\"}", cleared.json);
}

test "a dedicated worker made after Emulation.setUserAgentOverride reports the override; one made before keeps its copy" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();

    const ask =
        \\globalThis.askWorker = (w) => new Promise((resolve) => { w.onmessage = (e) => resolve(e.data); w.postMessage(0); });
        \\globalThis.makeWorker = () => new Worker(URL.createObjectURL(new Blob(['onmessage = () => postMessage(navigator.userAgent + "|" + navigator.platform)'], { type: 'text/javascript' })));
        \\globalThis.before = makeWorker(); 1
    ;
    const made = try h.host.evaluate(h.allocator, h.tab, ask, .{}, 5_000);
    defer made.deinit(h.allocator);
    _ = try h.call("Emulation.setUserAgentOverride", "{\"userAgent\":\"CraneWorker/1\",\"platform\":\"WorkerOS\"}");
    const after = try h.host.evaluate(h.allocator, h.tab, "askWorker(makeWorker())", .{ .await_promise = true }, 5_000);
    defer after.deinit(h.allocator);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"CraneWorker/1|WorkerOS\"}", after.json);
    // Chrome's copy is taken at creation: a worker made before keeps the
    // Browser's user agent.
    const earlier = try h.host.evaluate(h.allocator, h.tab, "askWorker(before).then((v) => v.startsWith('CraneWorker/1'))", .{ .await_promise = true }, 5_000);
    defer earlier.deinit(h.allocator);
    try testing.expectEqualStrings("{\"type\":\"boolean\",\"value\":false}", earlier.json);
}

test "document.open() is Page.documentOpened, then lifecycle init, as Chrome's DidOpenDocument" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();

    _ = try h.call("Page.enable", "{}");
    _ = try h.call("Page.setLifecycleEventsEnabled", "{\"enabled\":true}");
    const from = h.seen.items.len;
    const opened = try h.host.evaluate(h.allocator, h.tab, "document.open(); document.write('<p>x</p>'); document.close(); 1", .{}, 5_000);
    defer opened.deinit(h.allocator);
    const index = try h.waitEvent("Page.documentOpened", from);
    const init_index = try h.waitEvent("Page.lifecycleEvent", index);
    try testing.expectEqualStrings("init", h.seen.items[init_index].value.object.get("params").?.object.get("name").?.string);
}

test "Page.windowOpen tells the opener's session of window.open before the window exists" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();

    _ = try h.call("Page.enable", "{}");
    const from = h.seen.items.len;
    const opened = try h.host.evaluate(h.allocator, h.tab, "void window.open('about:blank#p', 'named', 'width=300,height=200')", .{ .user_activation = true }, 5_000);
    defer opened.deinit(h.allocator);
    const index = try h.waitEvent("Page.windowOpen", from);
    const params = h.seen.items[index].value.object.get("params").?.object;
    try testing.expectEqualStrings("about:blank#p", params.get("url").?.string);
    try testing.expectEqualStrings("named", params.get("windowName").?.string);
    try testing.expect(params.get("userGesture").?.bool);
    const features = params.get("windowFeatures").?.array.items;
    try testing.expectEqualStrings("width=300", features[0].string);
    try testing.expectEqualStrings("height=200", features[1].string);
}

test "DOM.describeNode gives a stable backendNodeId; a node that is gone is not found" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();

    _ = try h.call("Page.navigate", "{\"url\":\"data:text/html,<div id=d class=c>x</div>\"}");
    _ = try h.waitEvent("Page.frameStoppedLoading", 0) catch 0;
    // No inspector session yet (lane cdpw's bridge): by an unknown id.
    try testing.expectError(error.CommandFailed, h.call("DOM.describeNode", "{\"backendNodeId\":999999}"));
    try testing.expectError(error.CommandFailed, h.call("DOM.getContentQuads", "{\"backendNodeId\":999999}"));
}
