//! Lane icon1: CDP Network visibility for default /favicon.ico and
//! <link rel="icon"> fetches, matching Chrome for Testing 157:
//! - Network.requestWillBeSent emitted AFTER Page.loadEventFired
//! - type = "Other", initiator.type = "other"
//! - Network.responseReceived (type = "Other") and Network.loadingFinished
//!   paired with the same requestId.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const devtools = @import("devtools");
const cdp = @import("cdp_client.zig");
const replay = @import("cdpr_replay.zig");
const LoopbackListener = @import("loopback_listener").LoopbackListener;

const BrowserHost = browser_mod.BrowserHost;
const LeakChecked = replay.LeakChecked;
const Recorder = replay.Recorder;

const png_bytes =
    "\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01" ++
    "\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01" ++
    "\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82";

const Site = struct {
    allocator: std.mem.Allocator,
    listener: LoopbackListener,
    thread: ?std.Thread = null,
    active: std.atomic.Value(u32) = .init(0),

    fn start(allocator: std.mem.Allocator) !*Site {
        const self = try allocator.create(Site);
        errdefer allocator.destroy(self);
        self.* = .{
            .allocator = allocator,
            .listener = try LoopbackListener.open(.{}),
        };
        errdefer self.listener.close();
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
        return self;
    }

    fn stop(self: *Site) void {
        self.listener.stop();
        self.thread.?.join();
        self.listener.close();
        while (self.active.load(.acquire) != 0) std.Thread.yield() catch {};
        self.allocator.destroy(self);
    }

    fn url(self: *const Site, buf: []u8, path: []const u8) ![]const u8 {
        return std.fmt.bufPrint(buf, "http://127.0.0.1:{d}{s}", .{ self.listener.port(), path });
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
        self.answer(stream) catch {};
    }

    fn answer(self: *Site, stream: std.Io.net.Stream) !void {
        _ = self;
        var input: [4096]u8 = undefined;
        var reader = stream.reader(std.testing.io, &input);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) {
            try reader.interface.fillMore();
        }
        const head = reader.interface.buffered();
        const line_end = std.mem.indexOf(u8, head, "\r\n") orelse return;
        var parts = std.mem.tokenizeScalar(u8, head[0..line_end], ' ');
        _ = parts.next() orelse return;
        const path = parts.next() orelse return;

        var status: u16 = 404;
        var ct: []const u8 = "text/plain";
        var body: []const u8 = "not found";
        if (std.mem.eql(u8, path, "/network.html")) {
            status = 200;
            ct = "text/html";
            body = "<!doctype html><title>Network</title><script src=\"/app.js\"></script><p>ok</p>";
        } else if (std.mem.eql(u8, path, "/app.js")) {
            status = 200;
            ct = "text/javascript";
            body = "window.__ok = 1;";
        } else if (std.mem.eql(u8, path, "/with-link.html")) {
            status = 200;
            ct = "text/html";
            body = "<!doctype html><head><link rel=\"icon\" href=\"/custom.png\"></head><body>ok</body>";
        } else if (std.mem.eql(u8, path, "/custom.png")) {
            status = 200;
            ct = "image/png";
            body = png_bytes;
        }
        var output: [0]u8 = .{};
        var writer = stream.writer(std.testing.io, &output);
        const reason = if (status == 200) "OK" else "Not Found";
        try writer.interface.print(
            "HTTP/1.1 {d} {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n",
            .{ status, reason, ct, body.len },
        );
        try writer.interface.writeAll(body);
        try writer.interface.flush();
    }
};

fn attachFirstPage(allocator: std.mem.Allocator, rec: *Recorder) ![]u8 {
    const targets_id = try rec.send("Target.getTargets", "{}", "");
    const targets_idx = try rec.awaitResponse(targets_id);
    const infos = cdp.at(rec.log.items[targets_idx].value, "result.targetInfos").?.array.items;
    if (infos.len == 0) return error.NoTarget;
    var buf: [160]u8 = undefined;
    const attach_id = try rec.send(
        "Target.attachToTarget",
        try std.fmt.bufPrint(&buf, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{cdp.stringAt(infos[infos.len - 1], "targetId").?}),
        "",
    );
    const attached_idx = try rec.awaitResponse(attach_id);
    return allocator.dupe(u8, cdp.stringAt(rec.log.items[attached_idx].value, "result.sessionId").?);
}

test "CDP Network reports default /favicon.ico after Page.loadEventFired with type=Other and initiator=other" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    const site = try Site.start(allocator);
    defer site.stop();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    _ = try host.createTab(.{});
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer server.stop();

    var path_buf: [128]u8 = undefined;
    const client = try cdp.Client.openWebSocket(
        allocator,
        server.port,
        try std.fmt.bufPrint(&path_buf, "/devtools/browser/{s}", .{server.browser_id.slice()}),
        null,
    );
    defer client.close();
    var rec = Recorder.init(allocator, client);
    defer rec.deinit();

    const session = try attachFirstPage(allocator, &rec);
    defer allocator.free(session);

    _ = try rec.awaitResponse(try rec.send("Page.enable", "{}", session));
    _ = try rec.awaitResponse(try rec.send("Network.enable", "{}", session));

    const start_idx = rec.log.items.len;
    var url_buf: [128]u8 = undefined;
    var fav_buf: [128]u8 = undefined;
    var params_buf: [192]u8 = undefined;
    const page_url = try site.url(&url_buf, "/network.html");
    const favicon_url = try site.url(&fav_buf, "/favicon.ico");

    _ = try rec.awaitResponse(try rec.send(
        "Page.navigate",
        try std.fmt.bufPrint(&params_buf, "{{\"url\":\"{s}\"}}", .{page_url}),
        session,
    ));

    const load_idx = try rec.awaitEvent("Page.loadEventFired", session, start_idx, &.{});
    const sent_idx = try rec.awaitEvent("Network.requestWillBeSent", session, start_idx, &.{
        .{ .path = "params.request.url", .equals = favicon_url },
    });
    // Chrome 157: default /favicon.ico is requested AFTER Page.loadEventFired.
    try testing.expect(sent_idx > load_idx);

    const sent_val = rec.log.items[sent_idx].value;
    try testing.expectEqualStrings("Other", cdp.stringAt(sent_val, "params.type").?);
    try testing.expectEqualStrings("other", cdp.stringAt(sent_val, "params.initiator.type").?);
    const req_id = try allocator.dupe(u8, cdp.stringAt(sent_val, "params.requestId").?);
    defer allocator.free(req_id);

    const recv_idx = try rec.awaitEvent("Network.responseReceived", session, sent_idx, &.{
        .{ .path = "params.requestId", .equals = req_id },
    });
    const recv_val = rec.log.items[recv_idx].value;
    try testing.expectEqualStrings("Other", cdp.stringAt(recv_val, "params.type").?);
    try testing.expectEqual(@as(i64, 404), cdp.at(recv_val, "params.response.status").?.integer);

    _ = try rec.awaitEvent("Network.loadingFinished", session, recv_idx, &.{
        .{ .path = "params.requestId", .equals = req_id },
    });
}

test "CDP Network reports link rel=icon with type=Other, initiator=other, and suppresses /favicon.ico" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    const site = try Site.start(allocator);
    defer site.stop();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    _ = try host.createTab(.{});
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer server.stop();

    var path_buf: [128]u8 = undefined;
    const client = try cdp.Client.openWebSocket(
        allocator,
        server.port,
        try std.fmt.bufPrint(&path_buf, "/devtools/browser/{s}", .{server.browser_id.slice()}),
        null,
    );
    defer client.close();
    var rec = Recorder.init(allocator, client);
    defer rec.deinit();

    const session = try attachFirstPage(allocator, &rec);
    defer allocator.free(session);

    _ = try rec.awaitResponse(try rec.send("Page.enable", "{}", session));
    _ = try rec.awaitResponse(try rec.send("Network.enable", "{}", session));

    const start_idx = rec.log.items.len;
    var url_buf: [128]u8 = undefined;
    var custom_buf: [128]u8 = undefined;
    var fav_buf: [128]u8 = undefined;
    var params_buf: [192]u8 = undefined;
    const page_url = try site.url(&url_buf, "/with-link.html");
    const custom_url = try site.url(&custom_buf, "/custom.png");
    const favicon_url = try site.url(&fav_buf, "/favicon.ico");

    _ = try rec.awaitResponse(try rec.send(
        "Page.navigate",
        try std.fmt.bufPrint(&params_buf, "{{\"url\":\"{s}\"}}", .{page_url}),
        session,
    ));

    const load_idx = try rec.awaitEvent("Page.loadEventFired", session, start_idx, &.{});
    const sent_idx = try rec.awaitEvent("Network.requestWillBeSent", session, start_idx, &.{
        .{ .path = "params.request.url", .equals = custom_url },
    });
    try testing.expect(sent_idx > load_idx);

    const sent_val = rec.log.items[sent_idx].value;
    try testing.expectEqualStrings("Other", cdp.stringAt(sent_val, "params.type").?);
    try testing.expectEqualStrings("other", cdp.stringAt(sent_val, "params.initiator.type").?);
    const req_id = try allocator.dupe(u8, cdp.stringAt(sent_val, "params.requestId").?);
    defer allocator.free(req_id);

    const recv_idx = try rec.awaitEvent("Network.responseReceived", session, sent_idx, &.{
        .{ .path = "params.requestId", .equals = req_id },
    });
    const recv_val = rec.log.items[recv_idx].value;
    try testing.expectEqualStrings("Other", cdp.stringAt(recv_val, "params.type").?);
    try testing.expectEqual(@as(i64, 200), cdp.at(recv_val, "params.response.status").?.integer);

    _ = try rec.awaitEvent("Network.loadingFinished", session, recv_idx, &.{
        .{ .path = "params.requestId", .equals = req_id },
    });

    // No default /favicon.ico was requested.
    try testing.expect(rec.eventIndex("Network.requestWillBeSent", session, start_idx, &.{
        .{ .path = "params.request.url", .equals = favicon_url },
    }) == null);
}
