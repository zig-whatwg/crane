//! Fetch through the HTTP cache, end to end in the fetch job (lane
//! httpcache1): a job asks the network only when the cache cannot answer,
//! sends the stored response's validators when revalidating, hands on the
//! stored response after a 304, reports the right cache state to Resource
//! Timing, and only-if-cached fails without a stored response. The network
//! is the test's: each `.network` step is answered by hand.
const std = @import("std");
const fetch = @import("fetch");
const FetchJob = fetch.algorithms.FetchJob;
const InternalRequest = fetch.internal.InternalRequest;
const NetworkContext = fetch.network.NetworkContext;
const NetworkResponse = fetch.network.NetworkResponse;

const allocator = std.testing.allocator;

const Field = struct { []const u8, []const u8 };

fn answer(status: u16, fields: []const Field, body: ?[]const u8) !NetworkResponse {
    const headers = try allocator.alloc(NetworkResponse.Header, fields.len);
    for (fields, 0..) |f, i| headers[i] = .{ .name = try allocator.dupe(u8, f[0]), .value = try allocator.dupe(u8, f[1]) };
    return .{
        .allocator = allocator,
        .status = status,
        .http_version = .http_1_1,
        .headers = headers,
        .body = if (body) |b| try allocator.dupe(u8, b) else null,
        .final_url = null,
        .total_time_ms = 0,
        .time_to_first_byte_ms = 0,
        .redirect_count = 0,
        .remote_ip = null,
        .remote_port = null,
    };
}

const Reports = struct {
    count: usize = 0,
    cache_state: [16]u8 = undefined,
    cache_state_len: usize = 0,
    encoded: u64 = 0,

    fn report(context: *anyopaque, timing: *const fetch.internal.request.TimingReport) void {
        const self: *Reports = @ptrCast(@alignCast(context));
        self.count += 1;
        @memcpy(self.cache_state[0..timing.cache_state.len], timing.cache_state);
        self.cache_state_len = timing.cache_state.len;
        self.encoded = timing.body_info.encoded_size;
    }

    fn cacheState(self: *const Reports) []const u8 {
        return self.cache_state[0..self.cache_state_len];
    }
};

fn request(network: *NetworkContext, url: []const u8, reports: ?*Reports) !*InternalRequest {
    const r = try InternalRequest.init(allocator, url);
    errdefer r.deinit();
    try r.setOrigin("http://a.test");
    r.network = network;
    r.network_partition_key = try allocator.dupe(u8, "http://a.test");
    if (reports) |rep| {
        r.initiator_type = .fetch;
        r.timing_reporter = .{ .context = rep, .report = &Reports.report };
    }
    return r;
}

/// The header the network was asked to send, if any.
fn sent(step: FetchJob.Step, name: []const u8) ?[]const u8 {
    const needed = switch (step) {
        .network => |n| n,
        else => return null,
    };
    for (needed.request.headers) |h| {
        if (std.ascii.eqlIgnoreCase(h.name, name)) return h.value;
    }
    return null;
}

fn bodyOf(job: *FetchJob) ![]u8 {
    var result = job.takeResult();
    defer result.deinit();
    const b = result.response.body orelse return allocator.dupe(u8, "");
    return allocator.dupe(u8, b.getBytes());
}

test "hc1 fetch job: a fresh stored response answers the second fetch without the network" {
    var network = NetworkContext.init(allocator);
    defer network.deinit();
    try network.configure(.{});
    var reports: Reports = .{};
    {
        const r = try request(&network, "http://a.test/fresh", &reports);
        defer r.deinit();
        const job = try FetchJob.create(allocator, r, false, .{});
        defer job.destroy();
        try std.testing.expect(try job.start() == .network);
        try std.testing.expect(try job.resumeNetwork(try answer(200, &.{ .{ "Cache-Control", "max-age=600" }, .{ "Content-Type", "text/plain" } }, "hello")) == .done);
        try std.testing.expectEqualStrings("", reports.cacheState());
    }
    {
        const r = try request(&network, "http://a.test/fresh", &reports);
        defer r.deinit();
        const job = try FetchJob.create(allocator, r, false, .{});
        defer job.destroy();
        // HTTP-network-or-cache fetch step 26.2.2.3: no network at all.
        try std.testing.expect(try job.start() == .done);
        const text = try bodyOf(job);
        defer allocator.free(text);
        try std.testing.expectEqualStrings("hello", text);
        // Resource Timing: cacheMode "local", the stored body's sizes.
        try std.testing.expectEqualStrings("local", reports.cacheState());
        try std.testing.expectEqual(@as(u64, 5), reports.encoded);
    }
}

test "hc1 fetch job: a stale response is revalidated and a 304 hands on the stored body, validated" {
    var network = NetworkContext.init(allocator);
    defer network.deinit();
    try network.configure(.{});
    var reports: Reports = .{};
    {
        const r = try request(&network, "http://a.test/etag", null);
        defer r.deinit();
        const job = try FetchJob.create(allocator, r, false, .{});
        defer job.destroy();
        const step = try job.start();
        try std.testing.expect(sent(step, "If-None-Match") == null);
        // conditional-get.any.js's server: an ETag and nothing else.
        _ = try job.resumeNetwork(try answer(200, &.{.{ "ETag", "\"123abc\"" }}, "lorem"));
    }
    {
        const r = try request(&network, "http://a.test/etag", &reports);
        defer r.deinit();
        const job = try FetchJob.create(allocator, r, false, .{});
        defer job.destroy();
        const step = try job.start();
        try std.testing.expectEqualStrings("\"123abc\"", sent(step, "If-None-Match") orelse return error.TestNoValidator);
        try std.testing.expect(try job.resumeNetwork(try answer(304, &.{.{ "X-HTTP-STATUS", "304" }}, null)) == .done);
        var result = job.takeResult();
        defer result.deinit();
        try std.testing.expectEqual(@as(u16, 200), result.response.status);
        try std.testing.expectEqualStrings("304", result.response.header_list.getFirstValue("X-HTTP-STATUS").?);
        try std.testing.expectEqualStrings("lorem", result.response.body.?.getBytes());
        try std.testing.expectEqualStrings("validated", reports.cacheState());
    }
    {
        // An author If-None-Match makes a "default" request "no-store"
        // (8.16): the 304 is the response.
        const r = try request(&network, "http://a.test/etag", null);
        defer r.deinit();
        try r.header_list.append("If-None-Match", "\"123abc\"");
        const job = try FetchJob.create(allocator, r, false, .{});
        defer job.destroy();
        try std.testing.expect(try job.start() == .network);
        _ = try job.resumeNetwork(try answer(304, &.{}, null));
        var result = job.takeResult();
        defer result.deinit();
        try std.testing.expectEqual(@as(u16, 304), result.response.status);
    }
}

test "hc1 fetch job: only-if-cached fails without a stored response, and is answered with one" {
    var network = NetworkContext.init(allocator);
    defer network.deinit();
    try network.configure(.{});
    {
        const r = try request(&network, "http://a.test/oic", null);
        defer r.deinit();
        r.mode = .same_origin;
        r.cache_mode = .only_if_cached;
        const job = try FetchJob.create(allocator, r, false, .{});
        defer job.destroy();
        try std.testing.expect(try job.start() == .done);
        var result = job.takeResult();
        defer result.deinit();
        try std.testing.expect(result.response.response_type == .@"error");
    }
    {
        const r = try request(&network, "http://a.test/oic", null);
        defer r.deinit();
        const job = try FetchJob.create(allocator, r, false, .{});
        defer job.destroy();
        _ = try job.start();
        _ = try job.resumeNetwork(try answer(200, &.{ .{ "Expires", "Thu, 01 Jan 1970 00:00:00 GMT" }, .{ "ETag", "\"o\"" } }, "kept"));
    }
    {
        const r = try request(&network, "http://a.test/oic", null);
        defer r.deinit();
        r.mode = .same_origin;
        r.cache_mode = .only_if_cached;
        const job = try FetchJob.create(allocator, r, false, .{});
        defer job.destroy();
        try std.testing.expect(try job.start() == .done);
        const text = try bodyOf(job);
        defer allocator.free(text);
        try std.testing.expectEqualStrings("kept", text);
    }
}

test "hc1 fetch job: a cached redirect is followed from the cache too" {
    var network = NetworkContext.init(allocator);
    defer network.deinit();
    try network.configure(.{});
    {
        const r = try request(&network, "http://a.test/from", null);
        defer r.deinit();
        const job = try FetchJob.create(allocator, r, false, .{});
        defer job.destroy();
        try std.testing.expect(try job.start() == .network);
        const hop = try job.resumeNetwork(try answer(302, &.{ .{ "Location", "/to" }, .{ "Cache-Control", "max-age=600" } }, ""));
        try std.testing.expect(hop == .network);
        try std.testing.expect(try job.resumeNetwork(try answer(200, &.{.{ "Cache-Control", "max-age=600" }}, "target")) == .done);
    }
    {
        const r = try request(&network, "http://a.test/from", null);
        defer r.deinit();
        r.mode = .same_origin;
        r.cache_mode = .only_if_cached;
        const job = try FetchJob.create(allocator, r, false, .{});
        defer job.destroy();
        try std.testing.expect(try job.start() == .done);
        const text = try bodyOf(job);
        defer allocator.free(text);
        try std.testing.expectEqualStrings("target", text);
    }
}

test "hc1 fetch job: no network partition key, no cache" {
    var network = NetworkContext.init(allocator);
    defer network.deinit();
    try network.configure(.{});
    for (0..2) |_| {
        const r = try request(&network, "http://a.test/nokey", null);
        defer r.deinit();
        allocator.free(r.network_partition_key.?);
        r.network_partition_key = null;
        const job = try FetchJob.create(allocator, r, false, .{});
        defer job.destroy();
        try std.testing.expect(try job.start() == .network);
        _ = try job.resumeNetwork(try answer(200, &.{.{ "Cache-Control", "max-age=600" }}, "x"));
    }
    try std.testing.expectEqual(@as(usize, 0), network.http_cache.?.entryCount());
}
