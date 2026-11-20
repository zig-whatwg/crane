//! A WebSocket over HTTP/2 (RFC 8441) as kit/curl's transport opens one
//! (lane net3): its client session against an nghttp2 SERVER session, the
//! two joined in memory - the server's SETTINGS decide whether the client
//! may use the extended CONNECT (section 3), the CONNECT carries :protocol
//! "websocket" and no Upgrade/Connection/Host/Sec-WebSocket-Key (section 5),
//! a 2xx opens the tunnel, DATA frames carry the WebSocket bytes both ways,
//! and END_STREAM is the orderly close.
const std = @import("std");
const testing = std.testing;
const fetch = @import("fetch");
const kit = @import("kit_curl_share");
const ng = kit.nghttp2;
const h2 = kit.websocket_h2;

/// Whether this build's libcurl carries nghttp2 (-Dhttp2, the default).
const http2 = fetch.network.curl_backend.http2_enabled;

/// The server end: an nghttp2 server session that records the request and
/// answers it from the test.
const Server = struct {
    session: *ng.Session = undefined,
    stream_id: i32 = 0,
    request: std.ArrayList([2][]u8) = .empty,
    received: std.ArrayList(u8) = .empty,
    to_send: std.ArrayList(u8) = .empty,
    sent: usize = 0,
    ending: bool = false,
    deferred: bool = false,
    request_done: bool = false,
    client_ended: bool = false,

    fn init(self: *Server, connect_protocol: bool) !void {
        var callbacks: ?*ng.Callbacks = null;
        try testing.expectEqual(@as(c_int, 0), ng.nghttp2_session_callbacks_new(&callbacks));
        defer ng.nghttp2_session_callbacks_del(callbacks.?);
        ng.nghttp2_session_callbacks_set_on_header_callback(callbacks.?, onHeader);
        ng.nghttp2_session_callbacks_set_on_frame_recv_callback(callbacks.?, onFrameRecv);
        ng.nghttp2_session_callbacks_set_on_data_chunk_recv_callback(callbacks.?, onData);
        var session: ?*ng.Session = null;
        try testing.expectEqual(@as(c_int, 0), ng.nghttp2_session_server_new(&session, callbacks.?, self));
        self.session = session.?;
        const settings = [_]ng.SettingsEntry{.{ .settings_id = ng.SETTINGS_ENABLE_CONNECT_PROTOCOL, .value = if (connect_protocol) 1 else 0 }};
        try testing.expectEqual(@as(c_int, 0), ng.nghttp2_submit_settings(self.session, ng.FLAG_NONE, &settings, 1));
    }

    fn deinit(self: *Server) void {
        ng.nghttp2_session_del(self.session);
        for (self.request.items) |field| {
            testing.allocator.free(field[0]);
            testing.allocator.free(field[1]);
        }
        self.request.deinit(testing.allocator);
        self.received.deinit(testing.allocator);
        self.to_send.deinit(testing.allocator);
    }

    fn field(self: *const Server, name: []const u8) ?[]const u8 {
        for (self.request.items) |f| if (std.mem.eql(u8, f[0], name)) return f[1];
        return null;
    }

    fn respond(self: *Server, status: []const u8) !void {
        const nva = [_]ng.Nv{ .of(":status", status), .of("sec-websocket-protocol", "chat") };
        const provider: ng.DataProvider = .{ .source = .{ .ptr = self }, .read_callback = read };
        try testing.expectEqual(@as(c_int, 0), ng.nghttp2_submit_response2(self.session, self.stream_id, &nva, nva.len, &provider));
    }

    fn send(self: *Server, bytes: []const u8) !void {
        try self.to_send.appendSlice(testing.allocator, bytes);
        if (self.deferred) {
            self.deferred = false;
            _ = ng.nghttp2_session_resume_data(self.session, self.stream_id);
        }
    }

    fn end(self: *Server) void {
        self.ending = true;
        if (self.deferred) {
            self.deferred = false;
            _ = ng.nghttp2_session_resume_data(self.session, self.stream_id);
        }
    }

    fn of(user_data: ?*anyopaque) *Server {
        return @ptrCast(@alignCast(user_data.?));
    }

    fn onHeader(_: *ng.Session, frame: *const ng.FrameHd, name: [*]const u8, namelen: usize, value: [*]const u8, valuelen: usize, _: u8, user_data: ?*anyopaque) callconv(.c) c_int {
        const self = of(user_data);
        self.stream_id = frame.stream_id;
        const n = testing.allocator.dupe(u8, name[0..namelen]) catch return ng.ERR_CALLBACK_FAILURE;
        const v = testing.allocator.dupe(u8, value[0..valuelen]) catch return ng.ERR_CALLBACK_FAILURE;
        self.request.append(testing.allocator, .{ n, v }) catch return ng.ERR_CALLBACK_FAILURE;
        return 0;
    }

    fn onFrameRecv(_: *ng.Session, frame: *const ng.FrameHd, user_data: ?*anyopaque) callconv(.c) c_int {
        const self = of(user_data);
        if (frame.type == ng.HEADERS) self.request_done = true;
        if ((frame.type == ng.DATA or frame.type == ng.HEADERS) and frame.flags & ng.FLAG_END_STREAM != 0) self.client_ended = true;
        return 0;
    }

    fn onData(_: *ng.Session, _: u8, _: i32, data: [*]const u8, len: usize, user_data: ?*anyopaque) callconv(.c) c_int {
        of(user_data).received.appendSlice(testing.allocator, data[0..len]) catch return ng.ERR_CALLBACK_FAILURE;
        return 0;
    }

    fn read(_: *ng.Session, _: i32, buf: [*]u8, length: usize, flags: *u32, source: *ng.DataSource, _: ?*anyopaque) callconv(.c) isize {
        const self: *Server = @ptrCast(@alignCast(source.ptr.?));
        const available = self.to_send.items.len - self.sent;
        if (available == 0) {
            if (self.ending) {
                flags.* |= ng.DATA_FLAG_EOF;
                return 0;
            }
            self.deferred = true;
            return ng.ERR_DEFERRED;
        }
        const n = @min(available, length);
        @memcpy(buf[0..n], self.to_send.items[self.sent..][0..n]);
        self.sent += n;
        return @intCast(n);
    }
};

/// Move bytes both ways until neither side has anything to say.
fn pump(client: *h2.Session, server: *Server) !void {
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(testing.allocator);
    for (0..64) |_| {
        wire.clearRetainingCapacity();
        try client.output(&wire, 1 << 20);
        var moved = wire.items.len > 0;
        if (wire.items.len > 0) try testing.expectEqual(@as(isize, @intCast(wire.items.len)), ng.nghttp2_session_mem_recv2(server.session, wire.items.ptr, wire.items.len));
        while (true) {
            var data: [*]const u8 = undefined;
            const n = ng.nghttp2_session_mem_send2(server.session, &data);
            try testing.expect(n >= 0);
            if (n == 0) break;
            moved = true;
            try client.receive(data[0..@intCast(n)]);
        }
        if (!moved) return;
    }
    return error.TestUnexpectedResult;
}

test "an extended CONNECT opens a WebSocket tunnel on an HTTP/2 stream" {
    if (comptime !http2) return error.SkipZigTest;
    var server: Server = .{};
    try server.init(true);
    defer server.deinit();
    const client = try h2.Session.init(testing.allocator);
    defer client.deinit();

    try pump(client, &server);
    try testing.expect(client.settings_seen);
    try testing.expect(client.extendedConnectAllowed());

    try client.connect(.{ .scheme = "https", .authority = "web-platform.test:9000", .path = "/echo?x=1" }, &.{
        .{ .name = "Origin", .value = "https://web-platform.test:9000" },
        .{ .name = "Sec-WebSocket-Protocol", .value = "echo, chat" },
    });
    try pump(client, &server);
    try testing.expect(server.request_done);
    try testing.expectEqualStrings("CONNECT", server.field(":method").?);
    try testing.expectEqualStrings("websocket", server.field(":protocol").?);
    try testing.expectEqualStrings("https", server.field(":scheme").?);
    try testing.expectEqualStrings("/echo?x=1", server.field(":path").?);
    try testing.expectEqualStrings("web-platform.test:9000", server.field(":authority").?);
    try testing.expectEqualStrings("13", server.field("sec-websocket-version").?);
    try testing.expectEqualStrings("https://web-platform.test:9000", server.field("origin").?);
    try testing.expectEqualStrings("echo, chat", server.field("sec-websocket-protocol").?);
    for ([_][]const u8{ "upgrade", "connection", "host", "sec-websocket-key" }) |absent| try testing.expect(server.field(absent) == null);

    try server.respond("200");
    try pump(client, &server);
    try testing.expect(client.response_done);
    try testing.expectEqual(@as(u16, 200), client.status);
    try testing.expectEqual(@as(usize, 1), client.fields.items.len);
    try testing.expectEqualStrings("sec-websocket-protocol", client.fields.items[0].name);
    try testing.expectEqualStrings("chat", client.fields.items[0].value);

    // WebSocket bytes both ways, as DATA frames on the stream.
    try client.queue(&.{ 0x81, 0x85, 0x37, 0xfa, 0x21, 0x3d, 0x7f, 0x9f, 0x4d, 0x51, 0x58 });
    try server.send(&.{ 0x81, 0x02, 'h', 'i' });
    try pump(client, &server);
    try testing.expectEqualSlices(u8, &.{ 0x81, 0x85, 0x37, 0xfa, 0x21, 0x3d, 0x7f, 0x9f, 0x4d, 0x51, 0x58 }, server.received.items);
    try testing.expectEqualSlices(u8, &.{ 0x81, 0x02, 'h', 'i' }, client.pending());
    client.consumed(4);
    try testing.expectEqual(@as(usize, 0), client.pending().len);
    try testing.expectEqual(@as(usize, 0), client.unsent());

    // The orderly close: each side's END_STREAM.
    try testing.expect(!client.remote_ended);
    server.end();
    client.end();
    try pump(client, &server);
    try testing.expect(client.remote_ended);
    try testing.expect(server.client_ended);
    try testing.expect(client.closed);
    try testing.expectEqual(ng.NO_ERROR, client.close_code);
}

test "a server that did not enable the extended CONNECT is not sent one" {
    if (comptime !http2) return error.SkipZigTest;
    var server: Server = .{};
    try server.init(false);
    defer server.deinit();
    const client = try h2.Session.init(testing.allocator);
    defer client.deinit();
    try pump(client, &server);
    try testing.expect(client.settings_seen);
    try testing.expect(!client.extendedConnectAllowed());
}

test "a refused CONNECT ends with its status and no tunnel" {
    if (comptime !http2) return error.SkipZigTest;
    var server: Server = .{};
    try server.init(true);
    defer server.deinit();
    const client = try h2.Session.init(testing.allocator);
    defer client.deinit();
    try pump(client, &server);
    try client.connect(.{ .scheme = "https", .authority = "a.test", .path = "/" }, &.{});
    try pump(client, &server);
    server.ending = true;
    try server.respond("403");
    try pump(client, &server);
    try testing.expect(client.response_done);
    try testing.expectEqual(@as(u16, 403), client.status);
    try testing.expect(client.remote_ended);
    client.cancel();
    try pump(client, &server);
    try testing.expect(client.closed);
}

test "garbage from the server is a protocol error" {
    if (comptime !http2) return error.SkipZigTest;
    const client = try h2.Session.init(testing.allocator);
    defer client.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(testing.allocator);
    try client.output(&wire, 1 << 20);
    try testing.expect(std.mem.startsWith(u8, wire.items, "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"));
    try testing.expectError(error.ProtocolError, client.receive("HTTP/1.1 200 OK\r\n\r\n"));
}

test "a session that runs out of memory part-way frees what it made" {
    if (comptime !http2) return error.SkipZigTest;
    const Attempt = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const client = try h2.Session.init(allocator);
            defer client.deinit();
            try client.connect(.{ .scheme = "https", .authority = "a.test", .path = "/" }, &.{.{ .name = "Origin", .value = "https://a.test" }});
            try client.queue("abc");
        }
    };
    try testing.checkAllAllocationFailures(testing.allocator, Attempt.run, .{});
}
