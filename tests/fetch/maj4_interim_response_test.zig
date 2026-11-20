//! Fetch's first interim network-response start time (HTTP-network fetch's
//! response loop, "While true" step 5.1): when a 1xx interim response - 100
//! Continue, 103 Early Hints - arrives before the final one, the network
//! times both, and Resource Timing's firstInterimResponseStart and
//! finalResponseHeadersStart read them (resource-timing/
//! interim-response-times.html: Chrome, Firefox and Safari pass at wpt.fyi
//! 2358bd4835). Before, the final start was curl's time to the first byte -
//! one time for both - and the interim one stayed 0.
const std = @import("std");
const testing = std.testing;
const clock = @import("clock");
const fetch = @import("fetch");
const network = fetch.network;
const NetworkRequest = network.NetworkRequest;

/// A loopback server that answers one request with `parts`, sleeping
/// `pause_ms` before each part after the first.
const Paced = struct {
    listener: @import("loopback_listener").LoopbackListener = undefined,
    thread: std.Thread = undefined,
    parts: []const []const u8,
    pause_ms: u64,

    fn start(self: *Paced) !void {
        self.listener = try .open(.{});
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
    }

    fn stop(self: *Paced) void {
        self.listener.stop();
        self.thread.join();
        self.listener.close();
    }

    fn url(self: *const Paced, buf: []u8) ![]const u8 {
        return std.fmt.bufPrint(buf, "http://127.0.0.1:{d}/", .{self.listener.port()});
    }

    fn serve(self: *Paced) void {
        while (self.listener.accept()) |stream| {
            self.answer(stream);
            stream.close(std.testing.io);
        }
    }

    fn answer(self: *Paced, stream: std.Io.net.Stream) void {
        var buf: [8192]u8 = undefined;
        var reader = stream.reader(std.testing.io, &buf);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) {
            reader.interface.fillMore() catch return;
        }
        var no_buffer: [0]u8 = .{};
        var writer = stream.writer(std.testing.io, &no_buffer);
        for (self.parts, 0..) |part, i| {
            if (i != 0) clock.sleep(self.pause_ms * std.time.ns_per_ms);
            writer.interface.writeAll(part) catch return;
            writer.interface.flush() catch return;
        }
    }
};

const final_response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok";

fn send(server: *Paced) !network.NetworkResponse {
    try server.start();
    defer server.stop();
    var url_buf: [64]u8 = undefined;
    const request: NetworkRequest = .{ .url = try server.url(&url_buf), .method = "GET", .headers = &.{}, .body = null };
    const backend = try network.LibcurlBackend.init(testing.allocator);
    defer backend.deinit();
    return backend.getBackend().send(testing.allocator, &request);
}

test "a 100 and a 103 before the final response: the first interim and the final start are both timed" {
    var server: Paced = .{
        .parts = &.{
            "HTTP/1.1 100 Continue\r\n\r\n",
            "HTTP/1.1 103 Early Hints\r\nLink: </empty.js>; rel=preload; as=script\r\n\r\n",
            final_response,
        },
        .pause_ms = 60,
    };
    var response = try send(&server);
    defer response.deinit();
    try testing.expectEqual(@as(u16, 200), response.status);
    const interim = response.first_interim_response_ms orelse return error.NoInterimTime;
    // The final status line came two pauses (120 ms) after the 100's.
    try testing.expect(interim >= 0);
    try testing.expect(response.time_to_first_byte_ms - interim >= 100);
}

test "a 103 alone is the first interim response" {
    var server: Paced = .{
        .parts = &.{
            "HTTP/1.1 103 Early Hints\r\nLink: </empty.js>; rel=preload; as=script\r\n\r\n",
            final_response,
        },
        .pause_ms = 60,
    };
    var response = try send(&server);
    defer response.deinit();
    const interim = response.first_interim_response_ms orelse return error.NoInterimTime;
    try testing.expect(response.time_to_first_byte_ms - interim >= 50);
}

test "no interim response: no first interim time" {
    var server: Paced = .{ .parts = &.{final_response}, .pause_ms = 0 };
    var response = try send(&server);
    defer response.deinit();
    try testing.expectEqual(@as(u16, 200), response.status);
    try testing.expectEqual(@as(?f64, null), response.first_interim_response_ms);
}

fn timingFor(first_interim_response_ms: ?f64) !fetch.internal.FetchTimingInfo {
    const allocator = testing.allocator;
    const request = try fetch.internal.InternalRequest.init(allocator, "https://example.test/resource");
    defer request.deinit();
    const controller = try fetch.internal.FetchController.init(allocator);
    defer controller.deinit();
    var timing = fetch.internal.FetchTimingInfo.init(allocator);
    errdefer timing.deinit();
    timing.start_time = 10;
    timing.post_redirect_start_time = 10;
    const params = try fetch.internal.FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();
    const answer = network.NetworkResponse{
        .allocator = allocator,
        .status = 200,
        .http_version = .http_1_1,
        .headers = &.{},
        .body = null,
        .final_url = null,
        .total_time_ms = 40,
        .time_to_first_byte_ms = 30,
        .first_interim_response_ms = first_interim_response_ms,
        .redirect_count = 0,
        .remote_ip = null,
        .remote_port = null,
        .pretransfer_time_ms = 5,
    };
    const response = try fetch.algorithms.http_fetch.httpNetworkFetchFinish(allocator, params, &answer, 100, null);
    defer response.deinit();
    return timing;
}

test "HTTP-network fetch records the first interim network-response start time" {
    var with = try timingFor(12.5);
    defer with.deinit();
    try testing.expectEqual(@as(f64, 112.5), with.first_interim_network_response_start_time);
    try testing.expectEqual(@as(f64, 130), with.final_network_response_start_time);
    var without = try timingFor(null);
    defer without.deinit();
    try testing.expectEqual(@as(f64, 0), without.first_interim_network_response_start_time);
    try testing.expectEqual(@as(f64, 130), without.final_network_response_start_time);
}
