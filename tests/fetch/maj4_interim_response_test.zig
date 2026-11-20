//! Fetch's first interim network-response start time (HTTP-network fetch's
//! response loop, "While true" step 5.1): when a 1xx interim response - 100
//! Continue, 103 Early Hints - arrives before the final one, the network
//! times both, and Resource Timing's firstInterimResponseStart and
//! finalResponseHeadersStart read them (resource-timing/
//! interim-response-times.html: Chrome, Firefox and Safari pass at wpt.fyi
//! 2358bd4835). Before, the final start was curl's time to the first byte -
//! one time for both - and the interim one stayed 0.
//!
//! The network reports the interim start as a u32 of microseconds, so the
//! response is no bigger, and keeps its timing in a record made only when a
//! 1xx arrives (lane maj4's cost window: a ?f64 in the response and 40 bytes
//! more per transfer cost a fetch-heavy page ~1 MB).
//!
//! A test also pins the size: NetworkResponse is exactly as big as it would
//! be without the field.
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
    if (response.first_interim_response_us == 0) return error.NoInterimTime;
    const interim = @as(f64, @floatFromInt(response.first_interim_response_us)) / std.time.us_per_ms;
    // The final status line came two pauses (120 ms) after the 100's.
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
    if (response.first_interim_response_us == 0) return error.NoInterimTime;
    const interim = @as(f64, @floatFromInt(response.first_interim_response_us)) / std.time.us_per_ms;
    try testing.expect(response.time_to_first_byte_ms - interim >= 50);
}

test "no interim response: no first interim time" {
    var server: Paced = .{ .parts = &.{final_response}, .pause_ms = 0 };
    var response = try send(&server);
    defer response.deinit();
    try testing.expectEqual(@as(u16, 200), response.status);
    try testing.expectEqual(@as(u32, 0), response.first_interim_response_us);
}

fn timingFor(first_interim_response_us: u32) !fetch.internal.FetchTimingInfo {
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
        .first_interim_response_us = first_interim_response_us,
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
    var with = try timingFor(12_500);
    defer with.deinit();
    try testing.expectEqual(@as(f64, 112.5), with.first_interim_network_response_start_time);
    try testing.expectEqual(@as(f64, 130), with.final_network_response_start_time);
    var without = try timingFor(0);
    defer without.deinit();
    try testing.expectEqual(@as(f64, 0), without.first_interim_network_response_start_time);
    try testing.expectEqual(@as(f64, 130), without.final_network_response_start_time);
}

test "the first interim response start costs NetworkResponse no size" {
    const R = network.NetworkResponse;
    // The same struct without the field, laid out by Zig the same way: the
    // u32 sits in what was padding.
    const Without = comptime blk: {
        const info = @typeInfo(R).@"struct";
        const count = info.field_names.len - 1;
        var names: [count][:0]const u8 = undefined;
        var types: [count]type = undefined;
        var attrs: [count]std.builtin.Type.Struct.FieldAttributes = undefined;
        var at: usize = 0;
        for (info.field_names, info.field_types, info.field_attrs) |name, field_type, field_attrs| {
            if (std.mem.eql(u8, name, "first_interim_response_us")) continue;
            names[at] = name;
            types[at] = field_type;
            attrs[at] = field_attrs;
            at += 1;
        }
        break :blk @Struct(.auto, null, &names, &types, &attrs);
    };
    try testing.expectEqual(@sizeOf(Without), @sizeOf(R));
}
