//! Fetch undoes a response's content codings itself (lane quick1 b3): the
//! network hands it the body decoded through ONE table, which is also what
//! HTTP-network-or-cache fetch step 8.20 advertises in `Accept-Encoding`
//! (docs/lessons/architecture-a-content-coding-fetch-reports-is-not-one-
//! curl-decodes.md). Before, libcurl decoded (CURLOPT_ACCEPT_ENCODING "")
//! and was built without zstd, so `Content-Encoding: zstd` was a network
//! error (fetch/content-encoding/zstd/*: Chrome, Firefox and Safari pass),
//! and curl, not Fetch, chose what to advertise.
const std = @import("std");
const testing = std.testing;
const clock = @import("clock");
const fetch = @import("fetch");
const network = fetch.network;
const NetworkRequest = network.NetworkRequest;
const NetworkResponse = network.NetworkResponse;
const NetworkError = network.NetworkError;
const FetchJob = fetch.algorithms.FetchJob;
const InternalRequest = fetch.internal.InternalRequest;
const fixtures = @import("quick1b3_coding_fixtures.zig");

fn get(url: []const u8) NetworkRequest {
    return .{ .url = url, .method = "GET", .headers = &.{}, .body = null };
}

test "a zstd body reaches Fetch decoded, as Chrome, Firefox and Safari decode it" {
    const text = try fixtures.small(testing.allocator);
    defer testing.allocator.free(text);
    const response_bytes = try fixtures.httpResponse(testing.allocator, "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Encoding: zstd\r\n", fixtures.small_zst);
    defer testing.allocator.free(response_bytes);
    var server: fixtures.Canned = .{ .response = response_bytes };
    try server.start();
    defer server.stop();

    var url_buf: [64]u8 = undefined;
    const request = get(try server.url(&url_buf, "/foo.text.zst"));
    const backend = try network.LibcurlBackend.init(testing.allocator);
    defer backend.deinit();
    var response = try backend.getBackend().send(testing.allocator, &request);
    defer response.deinit();
    try testing.expectEqual(@as(u16, 200), response.status);
    try testing.expectEqualStrings(text, response.body orelse "");
}

test "a streamed zstd body arrives decoded, in pieces, as it comes" {
    try network.globalInit();
    defer network.globalCleanup();
    const text = try fixtures.big(testing.allocator);
    defer testing.allocator.free(text);
    const response_bytes = try fixtures.httpResponse(testing.allocator, "HTTP/1.1 200 OK\r\nContent-Encoding: zstd\r\n", fixtures.big_check_zst);
    defer testing.allocator.free(response_bytes);
    var server: fixtures.Canned = .{ .response = response_bytes };
    try server.start();
    defer server.stop();

    var scheduler = network.NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();
    var url_buf: [64]u8 = undefined;
    const request = get(try server.url(&url_buf, "/big.text.zst"));
    var record: Record = .{};
    defer record.bytes.deinit(testing.allocator);
    _ = try scheduler.startStreaming(testing.allocator, &request, .{ .context = &record, .head = Record.head, .data = Record.data, .end = Record.end });
    const deadline = clock.monotonicMillis() + 10_000;
    while (!record.ended and clock.monotonicMillis() < deadline) {
        _ = scheduler.pump();
        clock.sleep(std.time.ns_per_ms);
    }
    try testing.expect(record.ended);
    try testing.expectEqual(@as(?NetworkError, null), record.end_error);
    try testing.expectEqual(@as(u16, 200), record.status);
    try testing.expectEqual(text.len, record.bytes.items.len);
    try testing.expect(std.mem.eql(u8, text, record.bytes.items));
}

const Record = struct {
    status: u16 = 0,
    bytes: std.ArrayListUnmanaged(u8) = .empty,
    ended: bool = false,
    end_error: ?NetworkError = null,

    fn head(context: ?*anyopaque, response: NetworkResponse) void {
        const self: *Record = @ptrCast(@alignCast(context.?));
        var r = response;
        defer r.deinit();
        self.status = r.status;
    }

    fn data(context: ?*anyopaque, bytes: []const u8) void {
        const self: *Record = @ptrCast(@alignCast(context.?));
        self.bytes.appendSlice(testing.allocator, bytes) catch {};
    }

    fn end(context: ?*anyopaque, result: NetworkError!void) void {
        const self: *Record = @ptrCast(@alignCast(context.?));
        self.ended = true;
        result catch |err| {
            self.end_error = err;
        };
    }
};

test "the network sends no Accept-Encoding of its own: Fetch's header list says what is accepted" {
    var server: fixtures.Canned = .{ .response = "HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n" };
    try server.start();
    defer server.stop();
    var url_buf: [64]u8 = undefined;
    const request = get(try server.url(&url_buf, "/"));
    const backend = try network.LibcurlBackend.init(testing.allocator);
    defer backend.deinit();
    var response = try backend.getBackend().send(testing.allocator, &request);
    defer response.deinit();
    try testing.expectEqual(@as(u16, 204), response.status);
    try testing.expect(std.ascii.findIgnoreCase(server.request(), "accept-encoding") == null);
}

/// The `Accept-Encoding` HTTP-network-or-cache fetch asks the network to
/// send for a GET of `url` (with `range`, a `Range` header), or null.
fn acceptEncodingFor(url: []const u8, range: ?[]const u8, preset: ?[]const u8) !?[]u8 {
    const request = try InternalRequest.init(testing.allocator, url);
    defer request.deinit();
    try request.setOrigin("http://a.test");
    if (range) |value| try request.header_list.set("Range", value);
    if (preset) |value| try request.header_list.set("Accept-Encoding", value);
    const job = try FetchJob.create(testing.allocator, request, false, .{});
    defer job.destroy();
    const step = try job.start();
    const needed = switch (step) {
        .network => |n| n,
        else => return error.TestExpectedNetworkStep,
    };
    var found: ?[]u8 = null;
    for (needed.request.headers) |h| {
        if (!std.ascii.eqlIgnoreCase(h.name, "Accept-Encoding")) continue;
        if (found != null) return error.TestTwoAcceptEncodings;
        found = try testing.allocator.dupe(u8, h.value);
    }
    return found;
}

fn expectAcceptEncoding(expected: ?[]const u8, url: []const u8, range: ?[]const u8, preset: ?[]const u8) !void {
    const value = try acceptEncodingFor(url, range, preset);
    defer if (value) |v| testing.allocator.free(v);
    if (expected) |e| {
        try testing.expect(value != null);
        try testing.expectEqualStrings(e, value.?);
    } else try testing.expect(value == null);
}

test "HTTP-network-or-cache fetch 8.20 advertises the table's codings, br and zstd only to a trustworthy URL" {
    // Chromium's SetAcceptEncodingIfMissing and Firefox's
    // network.http.accept-encoding(.secure): "gzip, deflate" in the clear,
    // "gzip, deflate, br, zstd" over TLS or to localhost.
    try expectAcceptEncoding("gzip, deflate", "http://a.test/x", null, null);
    try expectAcceptEncoding("gzip, deflate, br, zstd", "https://a.test/x", null, null);
    try expectAcceptEncoding("gzip, deflate, br, zstd", "http://localhost:8000/x", null, null);
    try expectAcceptEncoding("gzip, deflate, br, zstd", "http://127.0.0.1:8000/x", null, null);
}

test "HTTP-network-or-cache fetch 8.19-8.20: a Range request accepts identity alone, and a preset value stays" {
    try expectAcceptEncoding("identity", "https://a.test/x", "bytes=0-10", null);
    try expectAcceptEncoding("gzip", "https://a.test/x", null, "gzip");
}

test "a transfer scans its header blocks for the final one once: the codings, the fields and the status line share it" {
    // Main (4b4765bd6ee) scanned them twice per transfer (parseHeaders and
    // the status line); the content-coding plan and the end's check read
    // the same block. The perf pair's fetch.loopback-br profile found the
    // extra scans (2026-11-14).
    const text = try fixtures.small(testing.allocator);
    defer testing.allocator.free(text);
    const response_bytes = try fixtures.httpResponse(testing.allocator, "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Encoding: gzip\r\n", fixtures.small_gz);
    defer testing.allocator.free(response_bytes);
    var server: fixtures.Canned = .{ .response = response_bytes };
    try server.start();
    defer server.stop();
    var url_buf: [64]u8 = undefined;
    const request = get(try server.url(&url_buf, "/small.gz"));
    const transfer = try network.Transfer.create(testing.allocator, &request, .{});
    defer transfer.destroy();
    transfer.prepareAttempt();
    const result = network.curl_ffi.easy_perform(transfer.handle);
    var response = try transfer.finish(result);
    defer response.deinit();
    try testing.expectEqual(@as(u16, 200), response.status);
    try testing.expectEqualStrings(text, response.body orelse "");
    try testing.expectEqualStrings("OK", response.status_message);
    try testing.expectEqual(@as(u32, 1), transfer.headerBlockScans());
}
