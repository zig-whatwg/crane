//! A body cut short or a chunked body that does not parse is the network
//! error Chromium names it (lane fw2; net_error_list.h), not a reset or a
//! plain failure: ERR_CONTENT_LENGTH_MISMATCH, ERR_INCOMPLETE_CHUNKED_ENCODING,
//! ERR_INVALID_CHUNKED_ENCODING - DevTools' errorText, and what a client
//! matches. Each response goes through the vendored curl over loopback, by
//! the scheduler's two paths: a whole response (Transfer.finish) and a
//! streamed one (Transfer.outcome).
//!
//! curl reports a chunked body that does not parse with CURLE_RECV_ERROR,
//! the code of a reset; only its message tells them apart
//! (curl_backend.zig refineTransferError, lib/http_chunks.c, sendf.c and transfer.c at curl 8.18.0). A
//! curl update that rewords the message fails the invalid-chunk cases here.

const std = @import("std");
const testing = std.testing;
const clock = @import("clock");
const fetch = @import("fetch");
const network = fetch.network;
const NetworkScheduler = network.NetworkScheduler;
const NetworkRequest = network.NetworkRequest;
const NetworkResponse = network.NetworkResponse;
const NetworkError = network.NetworkError;
const NetError = fetch.internal.response.NetError;
const LoopbackListener = @import("loopback_listener").LoopbackListener;

/// A loopback server answering each path with fixed bytes, then closing.
const RawSite = struct {
    listener: LoopbackListener,
    thread: ?std.Thread = null,
    active: std.atomic.Value(u32) = .init(0),

    const Answer = struct { path: []const u8, bytes: []const u8 };
    const answers = [_]Answer{
        // A chunk length that is not hex: curl's "chunk hex-length char not
        // a hex digit".
        .{ .path = "/bad-hex", .bytes = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\nzz\r\nhello\r\n0\r\n\r\n" },
        // A chunk's data not followed by CRLF: "Malformed encoding found in
        // chunked-encoding".
        .{ .path = "/bad-crlf", .bytes = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n5\r\nhelloXX\r\n0\r\n\r\n" },
        // Fewer bytes than the Content-Length.
        .{ .path = "/short-length", .bytes = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 100\r\nConnection: close\r\n\r\nshort" },
        // A chunked body that ends before its last chunk.
        .{ .path = "/short-chunked", .bytes = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n5\r\nhello\r\n" },
        // Well-formed, for contrast.
        .{ .path = "/good-chunked", .bytes = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n5\r\nhello\r\n0\r\n\r\n" },
    };

    fn start(self: *RawSite) !void {
        self.* = .{ .listener = try LoopbackListener.open(.{}) };
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
    }

    fn stop(self: *RawSite) void {
        self.listener.stop();
        self.thread.?.join();
        self.listener.close();
        while (self.active.load(.acquire) != 0) std.Thread.yield() catch {};
    }

    fn url(self: *const RawSite, buffer: []u8, path: []const u8) ![]const u8 {
        return std.fmt.bufPrint(buffer, "http://127.0.0.1:{d}{s}", .{ self.listener.port(), path });
    }

    fn serve(self: *RawSite) void {
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

    fn answerAndClose(self: *RawSite, stream: std.Io.net.Stream) void {
        defer _ = self.active.fetchSub(1, .acq_rel);
        defer stream.close(std.testing.io);
        answer(stream) catch {};
    }

    fn answer(stream: std.Io.net.Stream) !void {
        var input: [4096]u8 = undefined;
        var reader = stream.reader(std.testing.io, &input);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) try reader.interface.fillMore();
        const head = reader.interface.buffered();
        const line_end = std.mem.indexOf(u8, head, "\r\n") orelse return;
        var parts = std.mem.tokenizeScalar(u8, head[0..line_end], ' ');
        _ = parts.next() orelse return;
        const path = parts.next() orelse return;
        var output: [512]u8 = undefined;
        var writer = stream.writer(std.testing.io, &output);
        for (answers) |a| if (std.mem.eql(u8, a.path, path)) {
            try writer.interface.writeAll(a.bytes);
            try writer.interface.flush();
            return;
        };
        try writer.interface.writeAll("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
        try writer.interface.flush();
    }
};

const Whole = struct {
    calls: usize = 0,
    err: ?NetworkError = null,
    status: u16 = 0,

    fn record(context: ?*anyopaque, result: NetworkError!NetworkResponse) void {
        const self: *Whole = @ptrCast(@alignCast(context.?));
        self.calls += 1;
        var response = result catch |err| {
            self.err = err;
            return;
        };
        defer response.deinit();
        self.status = response.status;
    }
};

const Streamed = struct {
    ended: bool = false,
    err: ?NetworkError = null,
    status: u16 = 0,

    fn client(self: *Streamed) network.scheduler.StreamClient {
        return .{ .context = self, .head = head, .data = data, .end = end };
    }

    fn head(context: ?*anyopaque, response: NetworkResponse) void {
        const self: *Streamed = @ptrCast(@alignCast(context.?));
        var r = response;
        defer r.deinit();
        self.status = r.status;
    }

    fn data(_: ?*anyopaque, _: []const u8) void {}

    fn end(context: ?*anyopaque, result: NetworkError!void) void {
        const self: *Streamed = @ptrCast(@alignCast(context.?));
        self.ended = true;
        result catch |err| {
            self.err = err;
        };
    }
};

/// The error each path reports for `path`, pumping as an event loop would
/// (10 s at most).
fn errorsOf(site: *const RawSite, path: []const u8) !struct { whole: ?NetworkError, streamed: ?NetworkError } {
    var scheduler = NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();
    var url_buffer: [96]u8 = undefined;
    const request: NetworkRequest = .{ .url = try site.url(&url_buffer, path), .method = "GET", .headers = &.{}, .body = null };
    var whole: Whole = .{};
    var streamed: Streamed = .{};
    _ = try scheduler.start(testing.allocator, &request, Whole.record, &whole);
    _ = try scheduler.startStreaming(testing.allocator, &request, streamed.client());
    const deadline = clock.monotonicMillis() + 10_000;
    while ((whole.calls == 0 or !streamed.ended) and clock.monotonicMillis() < deadline) {
        _ = scheduler.pump();
        clock.sleep(std.time.ns_per_ms);
    }
    if (whole.calls == 0 or !streamed.ended) return error.Timeout;
    return .{ .whole = whole.err, .streamed = streamed.err };
}

/// Both paths fail `path` with Chromium's `text` (DevTools' errorText).
fn expectChrome(site: *const RawSite, path: []const u8, text: []const u8) !void {
    const got = try errorsOf(site, path);
    for ([_]?NetworkError{ got.whole, got.streamed }, [_][]const u8{ "whole", "streamed" }) |maybe, how| {
        const err = maybe orelse {
            std.debug.print("{s} ({s}): no error, expected {s}\n", .{ path, how, text });
            return error.NoError;
        };
        const got_text = NetError.fromNetwork(err).text();
        if (!std.mem.eql(u8, got_text, text)) std.debug.print("{s} ({s}): {s}, expected {s}\n", .{ path, how, got_text, text });
        try testing.expectEqualStrings(text, got_text);
    }
}

test "a chunk length that is not hex is ERR_INVALID_CHUNKED_ENCODING, through the vendored curl's own message" {
    try network.globalInit();
    defer network.globalCleanup();
    var site: RawSite = undefined;
    try site.start();
    defer site.stop();
    try expectChrome(&site, "/bad-hex", "net::ERR_INVALID_CHUNKED_ENCODING");
}

test "a chunk whose data is not followed by CRLF is ERR_INVALID_CHUNKED_ENCODING" {
    try network.globalInit();
    defer network.globalCleanup();
    var site: RawSite = undefined;
    try site.start();
    defer site.stop();
    try expectChrome(&site, "/bad-crlf", "net::ERR_INVALID_CHUNKED_ENCODING");
}

test "a body short of its Content-Length is ERR_CONTENT_LENGTH_MISMATCH" {
    try network.globalInit();
    defer network.globalCleanup();
    var site: RawSite = undefined;
    try site.start();
    defer site.stop();
    try expectChrome(&site, "/short-length", "net::ERR_CONTENT_LENGTH_MISMATCH");
}

test "a chunked body that ends before its last chunk is ERR_INCOMPLETE_CHUNKED_ENCODING" {
    try network.globalInit();
    defer network.globalCleanup();
    var site: RawSite = undefined;
    try site.start();
    defer site.stop();
    try expectChrome(&site, "/short-chunked", "net::ERR_INCOMPLETE_CHUNKED_ENCODING");
}

test "a well-formed chunked body is no error" {
    try network.globalInit();
    defer network.globalCleanup();
    var site: RawSite = undefined;
    try site.start();
    defer site.stop();
    const got = try errorsOf(&site, "/good-chunked");
    try testing.expectEqual(@as(?NetworkError, null), got.whole);
    try testing.expectEqual(@as(?NetworkError, null), got.streamed);
}
