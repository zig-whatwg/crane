//! Lane cdpd1's harness for the live-DOM tests (tests/devtools/cdpd1_*_test.zig):
//! page sessions attached to a Browser on its own thread with no transport
//! (the cdph harness's shape), and each DOM-domain message as one line of
//! text, so a test states the messages it expects in Chrome's order.

const std = @import("std");
const testing = std.testing;
const devtools = @import("devtools");
const browser_mod = @import("browser");
const BrowserHost = browser_mod.BrowserHost;
const outbound = devtools.outbound;

pub const page = "data:text/html,<body><div id=a><span>x</span></div><p id=b></p></body>";

/// A Browser on its own thread with page sessions on one tab, and the
/// messages they send.
pub const Harness = struct {
    allocator: std.mem.Allocator,
    host: *BrowserHost,
    queue: *outbound.Outbound,
    side: *devtools.BrowserSide,
    links: [2]?*outbound.SessionLink = .{ null, null },
    sessions: [2]?*devtools.PageSession = .{ null, null },
    tab: u64,
    next_id: i64 = 1,
    /// Messages read so far, parsed, OWNED.
    seen: std.ArrayList(std.json.Parsed(std.json.Value)) = .empty,

    const session_names = [2][]const u8{ "SESSION1", "SESSION2" };

    pub fn init(self: *Harness, allocator: std.mem.Allocator) !void {
        self.* = .{ .allocator = allocator, .host = undefined, .queue = undefined, .side = undefined, .tab = 0 };
        self.host = try BrowserHost.start(allocator, .{});
        self.queue = try outbound.Outbound.create(allocator);
        var context_id: [32]u8 = undefined;
        @memset(&context_id, 'C');
        var sink_context: u8 = 0;
        self.side = try devtools.BrowserSide.create(allocator, self.host, 0xC0FFEE, context_id, .{ .context = &sink_context, .post = sinkPost });
        try devtools.browser_side.InstallTask.post(self.side);
        self.tab = try self.host.createTab(.{});
        try self.attach(0);
    }

    /// Attach session `index` (0 or 1) to the tab.
    pub fn attach(self: *Harness, index: usize) !void {
        const link = try outbound.SessionLink.create(self.allocator, self.queue, session_names[index]);
        self.links[index] = link;
        const session = try devtools.PageSession.allocate(self.allocator, link, self.tab, devtools.ids.frameId(0xC0FFEE, self.tab));
        self.sessions[index] = session;
        try devtools.browser_side.AttachTask.post(self.side, session);
    }

    /// Detach session `index`.
    pub fn detach(self: *Harness, index: usize) void {
        const session = self.sessions[index] orelse return;
        devtools.browser_side.DetachTask.post(self.side, session);
        self.sessions[index] = null;
    }

    fn sinkPost(context: *anyopaque, side: *devtools.BrowserSide, event: devtools.browser_side.TargetEvent) void {
        _ = context;
        switch (event) {
            .navigated => |navigated| side.allocator.free(navigated.url),
            .title_changed => |changed| side.allocator.free(changed.title),
            else => {},
        }
    }

    pub fn deinit(self: *Harness) void {
        for (0..2) |i| self.detach(i);
        devtools.browser_side.uninstallAndWait(self.side);
        self.host.stop();
        self.side.destroy();
        for (self.links) |link| if (link) |l| l.release();
        self.drain();
        self.queue.release();
        for (self.seen.items) |*parsed| parsed.deinit();
        self.seen.deinit(self.allocator);
    }

    pub fn sendOn(self: *Harness, index: usize, method: []const u8, params_json: []const u8) !i64 {
        const id = self.next_id;
        self.next_id += 1;
        const message = try std.fmt.allocPrint(self.allocator, "{{\"id\":{d},\"method\":\"{s}\",\"params\":{s},\"sessionId\":\"{s}\"}}", .{ id, method, params_json, session_names[index] });
        defer self.allocator.free(message);
        try devtools.browser_side.MessageTask.post(self.side, self.sessions[index].?, message);
        return id;
    }

    pub fn drain(self: *Harness) void {
        var items: std.ArrayList(outbound.Item) = .empty;
        defer items.deinit(self.allocator);
        _ = self.queue.takeAll(&items) catch return;
        for (items.items) |item| {
            defer self.allocator.free(item.bytes);
            const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, item.bytes, .{}) catch continue;
            self.seen.append(self.allocator, parsed) catch {};
        }
    }

    /// The response to `id` (10 s): its result, or error.CommandFailed.
    pub fn result(self: *Harness, id: i64) !std.json.Value {
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

    /// The error message the response to `id` carries.
    pub fn errorMessage(self: *Harness, id: i64) ![]const u8 {
        var waited: u32 = 0;
        while (waited < 10_000) : (waited += 10) {
            self.drain();
            for (self.seen.items) |parsed| {
                const object = parsed.value.object;
                const got = object.get("id") orelse continue;
                if (got != .integer or got.integer != id) continue;
                const err = object.get("error") orelse return error.NoError;
                return err.object.get("message").?.string;
            }
            self.queue.wait(10 * std.time.ns_per_ms);
        }
        return error.Timeout;
    }

    pub fn call(self: *Harness, method: []const u8, params_json: []const u8) !std.json.Value {
        return self.result(try self.sendOn(0, method, params_json));
    }

    pub fn callOn(self: *Harness, index: usize, method: []const u8, params_json: []const u8) !std.json.Value {
        return self.result(try self.sendOn(index, method, params_json));
    }

    /// Wait (10 s) for an event `method` at or after index `from` of `seen`.
    pub fn waitEvent(self: *Harness, method: []const u8, from: usize) !usize {
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

    /// Navigate the tab to `url` and wait for its load event.
    pub fn load(self: *Harness, url: []const u8) !void {
        _ = try self.call("Page.enable", "{}");
        const from = self.seen.items.len;
        const params = try std.fmt.allocPrint(self.allocator, "{{\"url\":\"{s}\"}}", .{url});
        defer self.allocator.free(params);
        _ = try self.call("Page.navigate", params);
        _ = try self.waitEvent("Page.loadEventFired", from);
    }

    /// Run `source` in the page's main world.
    pub fn run(self: *Harness, source: []const u8) !void {
        const done = try self.host.evaluate(self.allocator, self.tab, source, .{}, 5_000);
        done.deinit(self.allocator);
    }

    /// Session `index`'s DOM.* events from index `from` of `seen`, one line
    /// each (`line`).
    pub fn domEvents(self: *Harness, index: usize, from: usize, out: *std.ArrayList(u8)) !void {
        self.drain();
        for (self.seen.items[from..]) |parsed| {
            const object = parsed.value.object;
            const method = object.get("method") orelse continue;
            if (!std.mem.startsWith(u8, method.string, "DOM.")) continue;
            const session = object.get("sessionId") orelse continue;
            if (!std.mem.eql(u8, session.string, session_names[index])) continue;
            try line(self.allocator, method.string["DOM.".len..], object.get("params"), out);
            try out.append(self.allocator, '\n');
        }
    }
};

/// One event as a line: its name, then its parameters in the protocol's
/// order, nodes as `describe` writes them.
pub fn line(allocator: std.mem.Allocator, name: []const u8, params_value: ?std.json.Value, out: *std.ArrayList(u8)) !void {
    try out.appendSlice(allocator, name);
    const params = (params_value orelse return).object;
    if (std.mem.eql(u8, name, "childNodeInserted")) {
        try out.print(allocator, " {d} {d} ", .{ params.get("parentNodeId").?.integer, params.get("previousNodeId").?.integer });
        try describe(allocator, params.get("node").?, out);
    } else if (std.mem.eql(u8, name, "childNodeRemoved")) {
        try out.print(allocator, " {d} {d}", .{ params.get("parentNodeId").?.integer, params.get("nodeId").?.integer });
    } else if (std.mem.eql(u8, name, "childNodeCountUpdated")) {
        try out.print(allocator, " {d} {d}", .{ params.get("nodeId").?.integer, params.get("childNodeCount").?.integer });
    } else if (std.mem.eql(u8, name, "attributeModified")) {
        try out.print(allocator, " {d} {s}={s}", .{ params.get("nodeId").?.integer, params.get("name").?.string, params.get("value").?.string });
    } else if (std.mem.eql(u8, name, "attributeRemoved")) {
        try out.print(allocator, " {d} {s}", .{ params.get("nodeId").?.integer, params.get("name").?.string });
    } else if (std.mem.eql(u8, name, "characterDataModified")) {
        try out.print(allocator, " {d} {s}", .{ params.get("nodeId").?.integer, params.get("characterData").?.string });
    } else if (std.mem.eql(u8, name, "inlineStyleInvalidated")) {
        // Blink sends the ids in its HeapHashSet's order: compared sorted.
        const ids = params.get("nodeIds").?.array.items;
        const sorted = try allocator.alloc(i64, ids.len);
        defer allocator.free(sorted);
        for (ids, sorted) |id, *s| s.* = id.integer;
        std.mem.sort(i64, sorted, {}, std.sort.asc(i64));
        try out.appendSlice(allocator, " [");
        for (sorted, 0..) |id, i| try out.print(allocator, "{s}{d}", .{ if (i == 0) "" else ",", id });
        try out.append(allocator, ']');
    } else if (std.mem.eql(u8, name, "shadowRootPushed")) {
        try out.print(allocator, " {d} ", .{params.get("hostId").?.integer});
        try describe(allocator, params.get("root").?, out);
    } else if (std.mem.eql(u8, name, "setChildNodes")) {
        try out.print(allocator, " {d} [", .{params.get("parentId").?.integer});
        for (params.get("nodes").?.array.items, 0..) |node, i| {
            if (i != 0) try out.append(allocator, ',');
            try describe(allocator, node, out);
        }
        try out.append(allocator, ']');
    }
}

/// A node: nodeName#nodeId, a text-like node's value in quotes, a
/// container's /childNodeCount, its attributes in {}, a shadow root's type,
/// a frame owner's content document in (), and its children in [].
pub fn describe(allocator: std.mem.Allocator, value: std.json.Value, out: *std.ArrayList(u8)) error{OutOfMemory}!void {
    const node = value.object;
    try out.print(allocator, "{s}#{d}", .{ node.get("nodeName").?.string, node.get("nodeId").?.integer });
    const node_type = node.get("nodeType").?.integer;
    if (node_type == 3 or node_type == 8) try out.print(allocator, "'{s}'", .{node.get("nodeValue").?.string});
    if (node.get("childNodeCount")) |count| try out.print(allocator, "/{d}", .{count.integer});
    if (node.get("attributes")) |attributes| if (attributes.array.items.len != 0) {
        try out.append(allocator, '{');
        var i: usize = 0;
        while (i + 1 < attributes.array.items.len) : (i += 2) {
            if (i != 0) try out.append(allocator, ',');
            try out.print(allocator, "{s}={s}", .{ attributes.array.items[i].string, attributes.array.items[i + 1].string });
        }
        try out.append(allocator, '}');
    };
    if (node.get("shadowRootType")) |t| try out.print(allocator, " {s}", .{t.string});
    if (node.get("contentDocument")) |document| {
        try out.append(allocator, '(');
        try describe(allocator, document, out);
        try out.append(allocator, ')');
    }
    if (node.get("children")) |children| {
        try out.append(allocator, '[');
        for (children.array.items, 0..) |child, i| {
            if (i != 0) try out.append(allocator, ',');
            try describe(allocator, child, out);
        }
        try out.append(allocator, ']');
    }
}

/// Load `url`, enable DOM and take the whole document (depth -1, or `depth`).
pub fn setUp(h: *Harness, url: []const u8, depth: ?i64) !void {
    try h.load(url);
    _ = try h.call("DOM.enable", "{}");
    const params = if (depth) |d| try std.fmt.allocPrint(h.allocator, "{{\"depth\":{d}}}", .{d}) else try h.allocator.dupe(u8, "{\"depth\":-1}");
    defer h.allocator.free(params);
    _ = try h.call("DOM.getDocument", params);
}

/// Run `source`, then check session 0's DOM events since `from` against
/// `expected`.
pub fn expectEvents(h: *Harness, from: usize, expected: []const u8) !void {
    var lines: std.ArrayList(u8) = .empty;
    defer lines.deinit(h.allocator);
    try h.domEvents(0, from, &lines);
    try testing.expectEqualStrings(expected, lines.items);
}
