//! What lane cdpr's replay tests share (cdpr_*_replay_test.zig): a recorder
//! that sends a runner's commands pipelined, as the runner sends them, and
//! keeps every message that comes back in arrival order; a Browser with the
//! remote end on it and a client of its browser target; and a loopback site
//! to navigate to (a data: URL is no network request: HTML's navigate
//! handles it without Fetch, so it has no Network events).
//!
//! The reference is Chrome for Testing 157's traffic with the punted suites'
//! own runners (tmp/plans/cdp1-evidence/), walked through Crane in
//! tmp/plans/cdp-conformance-trace.md. No tests of its own.

const std = @import("std");
const Allocator = std.mem.Allocator;
const browser_mod = @import("browser");
const devtools = @import("devtools");
const cdp = @import("cdp_client.zig");
const LoopbackListener = @import("loopback_listener").LoopbackListener;

pub const BrowserHost = browser_mod.BrowserHost;
pub const LeakChecked = std.heap.DebugAllocator(.{ .thread_safe = true });
pub const Message = std.json.Parsed(std.json.Value);

/// A field of a message and the text its value must print as (a string's
/// own text, "true"/"false", an integer in decimal).
pub const Check = struct {
    path: []const u8,
    equals: []const u8,
};

/// Whether `value` passes every check.
pub fn matches(value: std.json.Value, checks: []const Check) bool {
    for (checks) |check| {
        const field = cdp.at(value, check.path) orelse return false;
        if (!valueIs(field, check.equals)) return false;
    }
    return true;
}

fn valueIs(value: std.json.Value, text: []const u8) bool {
    var buffer: [32]u8 = undefined;
    const printed: []const u8 = switch (value) {
        .string => |s| s,
        .bool => |b| if (b) "true" else "false",
        .integer => |n| std.fmt.bufPrint(&buffer, "{d}", .{n}) catch return false,
        .null => "null",
        else => return false,
    };
    return std.mem.eql(u8, printed, text);
}

/// Sends commands without waiting and records every message the server
/// sends, in the order it arrives (what Puppeteer's Connection and
/// Playwright's CRConnection see).
pub const Recorder = struct {
    allocator: Allocator,
    client: *cdp.Client,
    /// Ids of its own: the client's `call` counts from 1.
    next_id: i64 = 10_000,
    /// Every message received, parsed, in arrival order. OWNED.
    log: std.ArrayList(Message) = .empty,

    pub fn init(allocator: Allocator, client: *cdp.Client) Recorder {
        return .{ .allocator = allocator, .client = client };
    }

    pub fn deinit(self: *Recorder) void {
        for (self.log.items) |*m| m.deinit();
        self.log.deinit(self.allocator);
    }

    /// Send `method` with `params` (a JSON object's text) on `session` (""
    /// for the connection's browser session); its id.
    pub fn send(self: *Recorder, method: []const u8, params: []const u8, session: []const u8) !i64 {
        const id = self.next_id;
        self.next_id += 1;
        var message: std.ArrayList(u8) = .empty;
        defer message.deinit(self.allocator);
        try message.print(self.allocator, "{{\"id\":{d},\"method\":\"{s}\",\"params\":{s}", .{ id, method, params });
        if (session.len > 0) try message.print(self.allocator, ",\"sessionId\":\"{s}\"", .{session});
        try message.appendSlice(self.allocator, "}");
        try self.client.sendText(message.items);
        return id;
    }

    /// Send `text` as it is: a message a runner sends in a shape `send`
    /// does not make ("params": null). Its id is the caller's.
    pub fn sendText(self: *Recorder, text: []const u8) !void {
        try self.client.sendText(text);
    }

    /// A fresh id for `sendText`.
    pub fn takeId(self: *Recorder) i64 {
        defer self.next_id += 1;
        return self.next_id;
    }

    fn readOne(self: *Recorder) !void {
        const text = (try self.client.receive()) orelse return error.ConnectionClosed;
        defer self.allocator.free(text);
        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, text, .{});
        errdefer parsed.deinit();
        try self.log.append(self.allocator, parsed);
    }

    pub fn at(self: *const Recorder, index: usize) std.json.Value {
        return self.log.items[index].value;
    }

    /// The index of the response to `id`, if it came.
    pub fn responseIndex(self: *const Recorder, id: i64) ?usize {
        for (self.log.items, 0..) |m, i| {
            const object = switch (m.value) {
                .object => |o| o,
                else => continue,
            };
            const got = object.get("id") orelse continue;
            if (got == .integer and got.integer == id and object.get("method") == null) return i;
        }
        return null;
    }

    /// Read until the response to `id` came; its index.
    pub fn awaitResponse(self: *Recorder, id: i64) !usize {
        while (true) {
            if (self.responseIndex(id)) |i| return i;
            try self.readOne();
        }
    }

    pub fn awaitAll(self: *Recorder, ids: []const i64) !void {
        for (ids) |id| _ = try self.awaitResponse(id);
    }

    /// The response to `id`'s "result"; error.CommandFailed when it is an
    /// error.
    pub fn result(self: *Recorder, id: i64) !std.json.Value {
        const value = self.at(try self.awaitResponse(id));
        if (cdp.at(value, "error") != null) return error.CommandFailed;
        return cdp.at(value, "result") orelse error.NoResult;
    }

    /// The response to `id`'s error code; null when it succeeded.
    pub fn errorCode(self: *Recorder, id: i64) !?i64 {
        const value = self.at(try self.awaitResponse(id));
        const code = cdp.at(value, "error.code") orelse return null;
        return code.integer;
    }

    /// The first event `method` on `session` ("" for the connection's own
    /// session) at or after `from` whose message passes `checks`.
    pub fn eventIndex(self: *const Recorder, method: []const u8, session: []const u8, from: usize, checks: []const Check) ?usize {
        var i = from;
        while (i < self.log.items.len) : (i += 1) {
            const value = self.log.items[i].value;
            const name = cdp.stringAt(value, "method") orelse continue;
            if (!std.mem.eql(u8, name, method)) continue;
            const on = cdp.stringAt(value, "sessionId") orelse "";
            if (!std.mem.eql(u8, on, session)) continue;
            if (!matches(value, checks)) continue;
            return i;
        }
        return null;
    }

    /// `eventIndex`, reading until it comes.
    pub fn awaitEvent(self: *Recorder, method: []const u8, session: []const u8, from: usize, checks: []const Check) !usize {
        while (true) {
            if (self.eventIndex(method, session, from, checks)) |i| return i;
            try self.readOne();
        }
    }

    /// How many events `method` on `session` at or after `from` pass `checks`.
    pub fn countEvents(self: *const Recorder, method: []const u8, session: []const u8, from: usize, checks: []const Check) usize {
        var n: usize = 0;
        var i = from;
        while (self.eventIndex(method, session, i, checks)) |at_index| {
            n += 1;
            i = at_index + 1;
        }
        return n;
    }
};

/// A Browser on its own thread with one tab (the console's first tab, which
/// a client finds as an existing target), the remote end on it, and a
/// client of the browser target.
pub const Fixture = struct {
    allocator: Allocator,
    host: *BrowserHost,
    server: *devtools.Server,
    client: *cdp.Client,
    rec: Recorder,

    pub fn start(allocator: Allocator) !*Fixture {
        const self = try allocator.create(Fixture);
        errdefer allocator.destroy(self);
        const host = try BrowserHost.start(allocator, .{});
        errdefer host.stop();
        _ = try host.createTab(.{});
        const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
        errdefer server.stop();
        var path_buffer: [96]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buffer, "/devtools/browser/{s}", .{server.browser_id.slice()});
        const client = try cdp.Client.openWebSocket(allocator, server.port, path, null);
        errdefer client.close();
        if (client.upgrade_status != 101) return error.UpgradeRefused;
        self.* = .{ .allocator = allocator, .host = host, .server = server, .client = client, .rec = .init(allocator, client) };
        return self;
    }

    pub fn stop(self: *Fixture) void {
        self.rec.deinit();
        self.client.close();
        self.server.stop();
        self.host.stop();
        self.allocator.destroy(self);
    }
};

/// A copy of a string field of a recorded message, OWNED by `allocator`
/// (the log's messages outlive no `deinit`).
pub fn dupeAt(allocator: Allocator, value: std.json.Value, path: []const u8) ![]u8 {
    const text = cdp.stringAt(value, path) orelse return error.MissingField;
    return allocator.dupe(u8, text);
}

// ============================================================================
// The loopback site
// ============================================================================

/// The pages the replay tests navigate to: a document with a subresource
/// script and a named frame (Vitest's "vitest-iframe"), the frame's document,
/// and JSON for fetch(). A loopback HTTP server answering each request on a
/// thread of its own with `Connection: close` - the shape of
/// tests/repl/site.zig, over tests/support/loopback_listener.zig.
pub const Site = struct {
    allocator: Allocator,
    listener: LoopbackListener,
    thread: ?std.Thread = null,
    active: std.atomic.Value(u32) = .init(0),

    pub const index_html =
        \\<!doctype html><title>replay</title><p id=x>hello</p><iframe name="vitest-iframe" src="/frame.html"></iframe><script src="/app.js"></script>
    ;

    pub fn start(allocator: Allocator) !*Site {
        const self = try allocator.create(Site);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .listener = try LoopbackListener.open(.{}) };
        errdefer self.listener.close();
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
        return self;
    }

    /// Stop accepting, join, close - in that order - then wait out the
    /// requests being answered.
    pub fn stop(self: *Site) void {
        self.listener.stop();
        self.thread.?.join();
        self.listener.close();
        while (self.active.load(.acquire) != 0) std.Thread.yield() catch {};
        self.allocator.destroy(self);
    }

    /// `http://127.0.0.1:<port><path>`, into `buffer`.
    pub fn url(self: *const Site, buffer: []u8, path: []const u8) ![]const u8 {
        return std.fmt.bufPrint(buffer, "http://127.0.0.1:{d}{s}", .{ self.listener.port(), path });
    }

    fn serve(self: *Site) void {
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

    fn answerAndClose(self: *Site, stream: std.Io.net.Stream) void {
        defer _ = self.active.fetchSub(1, .acq_rel);
        defer stream.close(std.testing.io);
        answer(stream) catch {};
    }

    fn answer(stream: std.Io.net.Stream) !void {
        var input: [16384]u8 = undefined;
        var reader = stream.reader(std.testing.io, &input);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) try reader.interface.fillMore();
        const head = reader.interface.buffered();
        const line_end = std.mem.indexOf(u8, head, "\r\n") orelse return;
        var parts = std.mem.tokenizeScalar(u8, head[0..line_end], ' ');
        _ = parts.next() orelse return;
        const target = parts.next() orelse return;
        const path = if (std.mem.indexOfScalar(u8, target, '?')) |q| target[0..q] else target;
        const page: struct { status: u16 = 200, content_type: []const u8 = "text/html", body: []const u8 } =
            if (std.mem.eql(u8, path, "/"))
                .{ .body = index_html }
            else if (std.mem.eql(u8, path, "/app.js"))
                .{ .content_type = "text/javascript", .body = "window.appRan = true;" }
            else if (std.mem.eql(u8, path, "/frame.html"))
                .{ .body = "<!doctype html><p>frame</p>" }
            else if (std.mem.eql(u8, path, "/data.json"))
                .{ .content_type = "application/json", .body = "{\"from\":\"network\"}" }
            else
                .{ .status = 404, .content_type = "text/plain", .body = "not found" };
        var output: [4096]u8 = undefined;
        var writer = stream.writer(std.testing.io, &output);
        const out = &writer.interface;
        try out.print("HTTP/1.1 {d} {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n", .{
            page.status, if (page.status == 200) "OK" else "Not Found", page.content_type, page.body.len,
        });
        try out.writeAll(page.body);
        try out.flush();
    }
};
