//! A served Browser keeps its tabs' contexts known to the inspector with no
//! session attached, as Chrome's does (src/devtools/contexts.zig
//! onServedCommit; Blink's MainThreadDebugger::ContextCreated for every
//! context, DidClearContextsForFrame -> resetContextGroup at a main frame's
//! new document): a client that attaches after the page logged gets the
//! message from V8's console message storage on Runtime.enable
//! (Runtime.consoleAPICalled), and a top-level navigation before it attached
//! dropped the earlier document's messages.
//!
//! Lane tpc (the test pass's cost lane; main 2026-11-22 12:47 AM ET: the
//! console forwarding guard (a) with Chrome's registration (b)).

const std = @import("std");
const testing = std.testing;
const devtools = @import("devtools");
const browser_mod = @import("browser");
const BrowserHost = browser_mod.BrowserHost;
const outbound = devtools.outbound;

/// A Browser on its own thread that a devtools server serves (its
/// BrowserSide installed), one tab, and up to two page sessions (SESSION1,
/// SESSION2), each attached only when the test says so.
const Harness = struct {
    allocator: std.mem.Allocator,
    host: *BrowserHost,
    queue: *outbound.Outbound,
    links: [2]?*outbound.SessionLink = .{ null, null },
    side: *devtools.BrowserSide,
    sessions: [2]?*devtools.PageSession = .{ null, null },
    tab: u64,
    next_id: i64 = 1,
    /// Messages read so far, parsed, OWNED.
    seen: std.ArrayList(std.json.Parsed(std.json.Value)) = .empty,

    fn init(self: *Harness, allocator: std.mem.Allocator) !void {
        self.* = .{ .allocator = allocator, .host = undefined, .queue = undefined, .side = undefined, .tab = 0 };
        self.host = try BrowserHost.start(allocator, .{});
        self.queue = try outbound.Outbound.create(allocator);
        var context_id: [32]u8 = undefined;
        @memset(&context_id, 'C');
        var sink_context: u8 = 0;
        self.side = try devtools.BrowserSide.create(allocator, self.host, 0xC0FFEE, context_id, .{ .context = &sink_context, .post = sinkPost });
        try devtools.browser_side.InstallTask.post(self.side);
        self.tab = try self.host.createTab(.{});
    }

    fn sinkPost(context: *anyopaque, side: *devtools.BrowserSide, event: devtools.browser_side.TargetEvent) void {
        _ = context;
        switch (event) {
            // The event owns its URL and its title (TargetSink.post).
            .navigated => |navigated| side.allocator.free(navigated.url),
            .title_changed => |changed| side.allocator.free(changed.title),
            else => {},
        }
    }

    /// Navigate the tab as the browser UI does, until its document loaded.
    fn load(self: *Harness, url: []const u8) !void {
        const at = try self.host.navigate(self.allocator, self.tab, url, .{ .wait = .complete, .timeout_ms = 10_000 });
        self.allocator.free(at);
    }

    const session_names = [2][]const u8{ "SESSION1", "SESSION2" };

    /// Attach page session `which` (0: SESSION1, 1: SESSION2) to the tab now.
    fn attach(self: *Harness, which: usize) !void {
        const link = try outbound.SessionLink.create(self.allocator, self.queue, session_names[which]);
        self.links[which] = link;
        const session = try devtools.PageSession.allocate(self.allocator, link, self.tab, devtools.ids.frameId(0xC0FFEE, self.tab));
        try devtools.browser_side.AttachTask.post(self.side, session);
        self.sessions[which] = session;
    }

    fn deinit(self: *Harness) void {
        for (self.sessions) |maybe| if (maybe) |session| devtools.browser_side.DetachTask.post(self.side, session);
        devtools.browser_side.uninstallAndWait(self.side);
        self.host.stop();
        self.side.destroy();
        for (self.links) |maybe| if (maybe) |link| link.release();
        self.drain();
        self.queue.release();
        for (self.seen.items) |*parsed| parsed.deinit();
        self.seen.deinit(self.allocator);
    }

    /// Send `method` with `params_json` on session `which`; returns the
    /// call's id (unique across both sessions).
    fn send(self: *Harness, which: usize, method: []const u8, params_json: []const u8) !i64 {
        const id = self.next_id;
        self.next_id += 1;
        const message = try std.fmt.allocPrint(self.allocator, "{{\"id\":{d},\"method\":\"{s}\",\"params\":{s},\"sessionId\":\"{s}\"}}", .{ id, method, params_json, session_names[which] });
        defer self.allocator.free(message);
        try devtools.browser_side.MessageTask.post(self.side, self.sessions[which].?, message);
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

    /// Wait until the response to `id` arrives (10 s); its index in `seen`.
    fn responseIndex(self: *Harness, id: i64) !usize {
        var waited: u32 = 0;
        while (waited < 10_000) : (waited += 10) {
            self.drain();
            for (self.seen.items, 0..) |parsed, i| {
                const object = parsed.value.object;
                const got = object.get("id") orelse continue;
                if (got != .integer or got.integer != id) continue;
                if (object.get("error")) |_| return error.CommandFailed;
                return i;
            }
            self.queue.wait(10 * std.time.ns_per_ms);
        }
        return error.Timeout;
    }

    /// Each Runtime.consoleAPICalled session `which` was sent in
    /// `seen[from..to]`, one line each: its type, its first argument's string
    /// value, and the context it was logged in as the session's
    /// Runtime.executionContextCreated in the same range describes it - its
    /// auxData type, and its name for a world ("log tpc default",
    /// "log tpc isolated tpc-utility frame=tab").
    fn logged(self: *Harness, which: usize, from: usize, to: usize, out: *std.ArrayList(u8)) !void {
        const frame_id = devtools.ids.frameId(0xC0FFEE, self.tab);
        for (self.seen.items[from..to]) |parsed| {
            const object = parsed.value.object;
            if (!fromSession(object, which)) continue;
            const m = object.get("method") orelse continue;
            if (m != .string or !std.mem.eql(u8, m.string, "Runtime.consoleAPICalled")) continue;
            const params = object.get("params").?.object;
            const args = params.get("args").?.array.items;
            if (args.len == 0) continue;
            const value = args[0].object.get("value") orelse continue;
            if (value != .string) continue;
            try out.print(self.allocator, "{s} {s}", .{ params.get("type").?.string, value.string });
            const context_id = params.get("executionContextId").?.integer;
            const context = self.contextIn(which, from, to, context_id) orelse {
                try out.appendSlice(self.allocator, " unknown-context\n");
                continue;
            };
            const aux = context.get("auxData").?.object;
            try out.print(self.allocator, " {s}", .{aux.get("type").?.string});
            const name = context.get("name").?.string;
            if (name.len > 0) try out.print(self.allocator, " {s}", .{name});
            const frame_matches = std.mem.eql(u8, aux.get("frameId").?.string, frame_id.slice());
            try out.print(self.allocator, " frame={s}\n", .{if (frame_matches) "tab" else aux.get("frameId").?.string});
        }
    }

    /// The `context` of the Runtime.executionContextCreated session `which`
    /// was sent in `seen[from..to]` for execution context `id`.
    fn contextIn(self: *Harness, which: usize, from: usize, to: usize, id: i64) ?std.json.ObjectMap {
        for (self.seen.items[from..to]) |parsed| {
            const object = parsed.value.object;
            if (!fromSession(object, which)) continue;
            const m = object.get("method") orelse continue;
            if (m != .string or !std.mem.eql(u8, m.string, "Runtime.executionContextCreated")) continue;
            const context = object.get("params").?.object.get("context").?.object;
            if (context.get("id").?.integer == id) return context;
        }
        return null;
    }

    fn fromSession(object: std.json.ObjectMap, which: usize) bool {
        const sid = object.get("sessionId") orelse return false;
        return sid == .string and std.mem.eql(u8, sid.string, session_names[which]);
    }

    /// The response to `id`'s "result".
    fn resultOf(self: *Harness, index: usize) std.json.ObjectMap {
        return self.seen.items[index].value.object.get("result").?.object;
    }
};

test "a session that attaches after the page logged gets the message on Runtime.enable (a served Browser knows its contexts with no session, as Chrome's inspector does)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();

    // Logged while the Browser is served and nothing is attached.
    try h.load("data:text/html,<script>console.log('tpc-before-attach',7)</script>");
    try h.attach(0);
    const from = h.seen.items.len;
    const enabled = try h.responseIndex(try h.send(0, "Runtime.enable", "{}"));
    // V8 replays the contexts and the stored messages before it answers
    // Runtime.enable.
    var lines: std.ArrayList(u8) = .empty;
    defer lines.deinit(h.allocator);
    try h.logged(0, from, enabled, &lines);
    try testing.expectEqualStrings("log tpc-before-attach default frame=tab\n", lines.items);
}

test "a top-level navigation with no session attached drops the earlier document's messages (Blink resets the context group: DidClearContextsForFrame)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();

    try h.load("data:text/html,<script>console.log('tpc-first-document')</script>");
    try h.load("data:text/html,<script>console.info('tpc-second-document')</script>");
    try h.attach(0);
    const from = h.seen.items.len;
    const enabled = try h.responseIndex(try h.send(0, "Runtime.enable", "{}"));
    var lines: std.ArrayList(u8) = .empty;
    defer lines.deinit(h.allocator);
    try h.logged(0, from, enabled, &lines);
    try testing.expectEqualStrings("info tpc-second-document default frame=tab\n", lines.items);
}

test "an isolated world's console call before a session attaches replays in the world's own context (auxData type isolated, its name and frame)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();

    // The page logs with nothing attached.
    try h.load("data:text/html,<script>console.log('tpc-main-world')</script>");
    // A first client makes a utility world (Playwright's, Puppeteer's) and
    // logs in it, without Runtime.enable.
    try h.attach(0);
    const frame_id = devtools.ids.frameId(0xC0FFEE, h.tab);
    const world_params = try std.fmt.allocPrint(h.allocator, "{{\"frameId\":\"{s}\",\"worldName\":\"tpc-utility\"}}", .{frame_id.slice()});
    defer h.allocator.free(world_params);
    const made = try h.responseIndex(try h.send(0, "Page.createIsolatedWorld", world_params));
    const world_context = h.resultOf(made).get("executionContextId").?.integer;
    const evaluate_params = try std.fmt.allocPrint(h.allocator, "{{\"expression\":\"console.log('tpc-world')\",\"contextId\":{d}}}", .{world_context});
    defer h.allocator.free(evaluate_params);
    _ = try h.responseIndex(try h.send(0, "Runtime.evaluate", evaluate_params));
    // A second client attaches after both calls: its Runtime.enable replays
    // each message in the context it was logged in.
    try h.attach(1);
    const from = h.seen.items.len;
    const enabled = try h.responseIndex(try h.send(1, "Runtime.enable", "{}"));
    var lines: std.ArrayList(u8) = .empty;
    defer lines.deinit(h.allocator);
    try h.logged(1, from, enabled, &lines);
    try testing.expectEqualStrings(
        \\log tpc-main-world default frame=tab
        \\log tpc-world isolated tpc-utility frame=tab
        \\
    , lines.items);
    // The world's message is the world's context, the one createIsolatedWorld named.
    try testing.expect(h.contextIn(1, from, enabled, world_context) != null);
}
