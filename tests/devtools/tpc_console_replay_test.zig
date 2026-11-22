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
/// BrowserSide installed), one tab, and a page session attached only when
/// the test says so.
const Harness = struct {
    allocator: std.mem.Allocator,
    host: *BrowserHost,
    queue: *outbound.Outbound,
    link: *outbound.SessionLink,
    side: *devtools.BrowserSide,
    session: ?*devtools.PageSession = null,
    tab: u64,
    next_id: i64 = 1,
    /// Messages read so far, parsed, OWNED.
    seen: std.ArrayList(std.json.Parsed(std.json.Value)) = .empty,

    fn init(self: *Harness, allocator: std.mem.Allocator) !void {
        self.* = .{ .allocator = allocator, .host = undefined, .queue = undefined, .link = undefined, .side = undefined, .tab = 0 };
        self.host = try BrowserHost.start(allocator, .{});
        self.queue = try outbound.Outbound.create(allocator);
        self.link = try outbound.SessionLink.create(allocator, self.queue, "SESSION1");
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

    /// Attach the page session to the tab now.
    fn attach(self: *Harness) !void {
        const session = try devtools.PageSession.allocate(self.allocator, self.link, self.tab, devtools.ids.frameId(0xC0FFEE, self.tab));
        try devtools.browser_side.AttachTask.post(self.side, session);
        self.session = session;
    }

    fn deinit(self: *Harness) void {
        if (self.session) |session| devtools.browser_side.DetachTask.post(self.side, session);
        devtools.browser_side.uninstallAndWait(self.side);
        self.host.stop();
        self.side.destroy();
        self.link.release();
        self.drain();
        self.queue.release();
        for (self.seen.items) |*parsed| parsed.deinit();
        self.seen.deinit(self.allocator);
    }

    /// Send `method` with `params_json` on the session; returns the call's id.
    fn send(self: *Harness, method: []const u8, params_json: []const u8) !i64 {
        const id = self.next_id;
        self.next_id += 1;
        const message = try std.fmt.allocPrint(self.allocator, "{{\"id\":{d},\"method\":\"{s}\",\"params\":{s},\"sessionId\":\"SESSION1\"}}", .{ id, method, params_json });
        defer self.allocator.free(message);
        try devtools.browser_side.MessageTask.post(self.side, self.session.?, message);
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

    /// The first argument's string value of each Runtime.consoleAPICalled in
    /// `seen[from..to]`, joined by '\n'.
    fn loggedStrings(self: *Harness, from: usize, to: usize, out: *std.ArrayList(u8)) !void {
        for (self.seen.items[from..to]) |parsed| {
            const object = parsed.value.object;
            const m = object.get("method") orelse continue;
            if (m != .string or !std.mem.eql(u8, m.string, "Runtime.consoleAPICalled")) continue;
            const params = object.get("params").?.object;
            const args = params.get("args").?.array.items;
            if (args.len == 0) continue;
            const value = args[0].object.get("value") orelse continue;
            if (value != .string) continue;
            try out.appendSlice(self.allocator, params.get("type").?.string);
            try out.append(self.allocator, ' ');
            try out.appendSlice(self.allocator, value.string);
            try out.append(self.allocator, '\n');
        }
    }
};

test "a session that attaches after the page logged gets the message on Runtime.enable (a served Browser knows its contexts with no session, as Chrome's inspector does)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();

    // Logged while the Browser is served and nothing is attached.
    try h.load("data:text/html,<script>console.log('tpc-before-attach',7)</script>");
    try h.attach();
    const from = h.seen.items.len;
    const enabled = try h.responseIndex(try h.send("Runtime.enable", "{}"));
    // V8 replays the stored messages before it answers Runtime.enable.
    var lines: std.ArrayList(u8) = .empty;
    defer lines.deinit(h.allocator);
    try h.loggedStrings(from, enabled, &lines);
    try testing.expectEqualStrings("log tpc-before-attach\n", lines.items);
}

test "a top-level navigation with no session attached drops the earlier document's messages (Blink resets the context group: DidClearContextsForFrame)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();

    try h.load("data:text/html,<script>console.log('tpc-first-document')</script>");
    try h.load("data:text/html,<script>console.info('tpc-second-document')</script>");
    try h.attach();
    const from = h.seen.items.len;
    const enabled = try h.responseIndex(try h.send("Runtime.enable", "{}"));
    var lines: std.ArrayList(u8) = .empty;
    defer lines.deinit(h.allocator);
    try h.loggedStrings(from, enabled, &lines);
    try testing.expectEqualStrings("info tpc-second-document\n", lines.items);
}
