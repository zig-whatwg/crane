const std = @import("std");
const fetch = @import("fetch");
const Cache = fetch.cors.PreflightCache;
const Key = fetch.cors.CacheKey;
const a = std.testing.allocator;
const key: Key = .{ .network_partition_key = "https://top.test", .origin = "https://frame.test", .url = "https://api.test/data" };

test "preflight store matches exact methods, independent expiry and credentials" {
    if (!@hasDecl(Cache, "allows")) return error.TestUnexpectedResult;
    var cache = Cache.init(a);
    defer cache.deinit();
    try cache.store(key, 100, 5, &.{"custom"}, &.{"X-Test"}, false);
    try std.testing.expect(cache.allows(key, 101, false, "custom", &.{"x-test"}));
    try std.testing.expect(!cache.allows(key, 101, false, "CUSTOM", &.{}));
    try std.testing.expect(!cache.allows(key, 101, true, "custom", &.{}));
    var other = key;
    other.network_partition_key = "https://other.test";
    try std.testing.expect(!cache.allows(other, 101, false, "custom", &.{}));
    try cache.store(key, 200, 20, &.{"PUT"}, &.{}, true);
    try std.testing.expect(!cache.allows(key, 5100, false, "custom", &.{}));
    try std.testing.expect(cache.allows(key, 5100, true, "PUT", &.{}));
    try std.testing.expect(!cache.allows(key, 20200, false, "PUT", &.{}));
    try cache.store(key, 21000, 0, &.{"POST"}, &.{}, false);
    try std.testing.expect(!cache.allows(key, 21000, false, "POST", &.{}));
}

test "preflight wildcard never covers Authorization or credentialed requests" {
    if (!@hasDecl(Cache, "allows")) return error.TestUnexpectedResult;
    var cache = Cache.init(a);
    defer cache.deinit();
    try cache.store(key, 0, null, &.{"*"}, &.{"*"}, true);
    try std.testing.expect(cache.allows(key, 1, false, "PATCH", &.{"x-long"}));
    try std.testing.expect(!cache.allows(key, 1, true, "PATCH", &.{}));
    try std.testing.expect(!cache.allows(key, 1, false, "PATCH", &.{"Authorization"}));
    try std.testing.expect(!cache.allows(key, 5000, false, "PATCH", &.{}));
}

test "preflight bound evicts expired keys then oldest and full deinit owns every value" {
    if (!@hasDecl(Cache, "allows")) return error.TestUnexpectedResult;
    var cache = Cache.init(a);
    defer cache.deinit();
    cache.max_entries = 2;
    var second = key;
    second.url = "https://api.test/second";
    var third = key;
    third.url = "https://api.test/third";
    try cache.store(key, 0, 20, &.{"PUT"}, &.{}, false);
    try cache.store(second, 1, 1, &.{"PUT"}, &.{}, false);
    try cache.store(third, 2000, 20, &.{"PUT"}, &.{}, false);
    try std.testing.expect(cache.allows(key, 2000, false, "PUT", &.{}));
    try std.testing.expect(!cache.allows(second, 2000, false, "PUT", &.{}));
    try cache.store(second, 2001, 20, &.{"PUT"}, &.{}, false);
    try std.testing.expect(!cache.allows(key, 2001, false, "PUT", &.{}));
    try std.testing.expectEqual(@as(usize, 2), cache.count());
    cache.clear(second);
    try std.testing.expect(!cache.allows(second, 2001, false, "PUT", &.{}));
    cache.clearAll();
    try std.testing.expectEqual(@as(usize, 0), cache.count());
}

test "two Browser network contexts never share preflight entries" {
    if (!@hasField(fetch.network.NetworkContext, "preflight_cache")) return error.TestUnexpectedResult;
    var first = fetch.network.NetworkContext.init(a);
    defer first.deinit();
    var second = fetch.network.NetworkContext.init(a);
    defer second.deinit();
    try first.preflight_cache.store(key, 0, 20, &.{"PUT"}, &.{}, false);
    try std.testing.expect(!second.preflight_cache.allows(key, 1, false, "PUT", &.{}));
}

test "preflight store tolerates simultaneous native clients" {
    if (!@hasDecl(Cache, "allows")) return error.TestUnexpectedResult;
    var gpa: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("store leaked");
    var cache = Cache.init(gpa.allocator());
    defer cache.deinit();
    const Hammer = struct {
        fn run(c: *Cache) void {
            for (0..500) |i| {
                c.store(key, @intCast(i), 20, &.{"PUT"}, &.{"x-test"}, false) catch @panic("allocation");
                std.debug.assert(c.allows(key, @intCast(i), false, "PUT", &.{"X-Test"}));
            }
        }
    };
    const first = try std.Thread.spawn(.{}, Hammer.run, .{&cache});
    const second = std.Thread.spawn(.{}, Hammer.run, .{&cache}) catch |err| {
        first.join();
        return err;
    };
    first.join();
    second.join();
}

fn allocationTrial(allocator: std.mem.Allocator) !void {
    if (!@hasDecl(Cache, "allows")) return error.TestUnexpectedResult;
    var cache = Cache.init(allocator);
    defer cache.deinit();
    try cache.store(key, 0, 5, &.{ "PUT", "PATCH" }, &.{ "X-One", "X-Two" }, false);
    try std.testing.expect(cache.allows(key, 1, false, "PUT", &.{"x-two"}));
}
test "preflight insertion releases every partial allocation on OOM" {
    try std.testing.checkAllAllocationFailures(a, allocationTrial, .{});
}

test "a failed preflight insertion preserves the count and the entry it would evict" {
    for (0..14) |offset| {
        var failing = std.testing.FailingAllocator.init(a, .{});
        var cache = Cache.init(failing.allocator());
        defer cache.deinit();
        cache.max_entries = 1;
        try cache.store(key, 0, 60, &.{"PUT"}, &.{}, false);
        var next = key;
        next.url = "https://api.test/next";
        failing.fail_index = failing.alloc_index + offset;
        cache.store(next, 1, 60, &.{"PATCH"}, &.{"x-new"}, false) catch |err| {
            try std.testing.expectEqual(error.OutOfMemory, err);
            try std.testing.expectEqual(@as(usize, 1), cache.count());
            try std.testing.expect(cache.allows(key, 2, false, "PUT", &.{}));
            continue;
        };
        try std.testing.expectEqual(@as(usize, 1), cache.count());
        try std.testing.expect(!cache.allows(key, 2, false, "PUT", &.{}));
        try std.testing.expect(cache.allows(next, 2, false, "PATCH", &.{"x-new"}));
    }
}

test "preflight matches can race with insertion and clearing without lost counts" {
    var gpa: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("store leaked");
    var cache = Cache.init(gpa.allocator());
    defer cache.deinit();
    const Concurrent = struct {
        fn write(c: *Cache) void {
            for (0..500) |_| {
                c.store(key, 0, 60, &.{"PUT"}, &.{"x-one"}, false) catch @panic("allocation");
                c.clear(key);
            }
        }
        fn read(c: *Cache) void {
            for (0..1000) |_| _ = c.allows(key, 1, false, "PUT", &.{"x-one"});
        }
    };
    const writer = try std.Thread.spawn(.{}, Concurrent.write, .{&cache});
    const reader = std.Thread.spawn(.{}, Concurrent.read, .{&cache}) catch |err| {
        writer.join();
        return err;
    };
    writer.join();
    reader.join();
    try std.testing.expectEqual(@as(usize, 0), cache.count());
    try cache.store(key, 0, 60, &.{"PUT"}, &.{}, false);
    try std.testing.expectEqual(@as(usize, 1), cache.count());
    cache.clearAll();
    try std.testing.expectEqual(@as(usize, 0), cache.count());
}

fn reply(allocator: std.mem.Allocator) !fetch.network.NetworkResponse {
    const headers = try allocator.alloc(fetch.network.NetworkResponse.Header, 3);
    headers[0] = .{ .name = try allocator.dupe(u8, "Access-Control-Allow-Origin"), .value = try allocator.dupe(u8, "https://frame.test") };
    headers[1] = .{ .name = try allocator.dupe(u8, "Access-Control-Allow-Methods"), .value = try allocator.dupe(u8, "PUT") };
    headers[2] = .{ .name = try allocator.dupe(u8, "Access-Control-Allow-Headers"), .value = try allocator.dupe(u8, "x-new") };
    return .{ .allocator = allocator, .status = 200, .http_version = .http_1_1, .total_time_ms = 0, .time_to_first_byte_ms = 0, .redirect_count = 0, .remote_ip = null, .remote_port = null, .headers = headers, .body = null, .final_url = try allocator.dupe(u8, key.url) };
}

test "CORS preflight and actual transport failures clear matching permissions" {
    if (!@hasField(fetch.network.NetworkContext, "preflight_cache")) return error.TestUnexpectedResult;
    for ([_]bool{ false, true }) |actual_failure| {
        var context = fetch.network.NetworkContext.init(a);
        defer context.deinit();
        const request = try fetch.internal.InternalRequest.init(a, key.url);
        defer request.deinit();
        try request.setOrigin(key.origin);
        try request.setMethod("PUT");
        request.network = &context;
        request.network_partition_key = try a.dupe(u8, key.network_partition_key);
        request.mode = .cors;
        request.unsafe_request = true;
        try request.header_list.append("X-New", "value");
        const job = try fetch.algorithms.FetchJob.create(a, request, false, .{});
        defer job.destroy();
        const start = try job.start();
        try std.testing.expect(start == .network);
        try std.testing.expectEqualStrings("OPTIONS", start.network.request.method);
        // Use a large injected deadline; no dependency on the process clock.
        try context.preflight_cache.store(key, std.math.maxInt(i64) - 1000, 20, &.{"PATCH"}, &.{}, false);
        if (actual_failure) {
            const actual = try job.resumeNetwork(try reply(a));
            try std.testing.expect(actual == .network);
            try std.testing.expectEqualStrings("PUT", actual.network.request.method);
        }
        try std.testing.expect(try job.resumeNetwork(error.ConnectionRefused) == .done);
        var result = job.takeResult();
        defer result.deinit();
        try std.testing.expectEqual(@as(u16, 0), result.response.status);
        try std.testing.expect(!context.preflight_cache.allows(key, 1, false, "PATCH", &.{}));
    }
}

test "preflight max-age follows browser signed parsing and invalid fallback" {
    if (!@hasField(fetch.network.NetworkContext, "preflight_cache")) return error.TestUnexpectedResult;
    const http = fetch.algorithms.http_fetch;
    const cases = [_]struct { age: []const u8, immediate: bool, six_seconds: bool }{
        .{ .age = "-1", .immediate = false, .six_seconds = false },
        .{ .age = "+60", .immediate = true, .six_seconds = true },
        .{ .age = "184467440737095516160", .immediate = true, .six_seconds = false },
        .{ .age = "invalid", .immediate = true, .six_seconds = false },
        .{ .age = "60", .immediate = true, .six_seconds = true },
    };
    for (cases) |case| {
        var context = fetch.network.NetworkContext.init(a);
        defer context.deinit();
        const request = try fetch.internal.InternalRequest.init(a, key.url);
        defer request.deinit();
        try request.setOrigin(key.origin);
        try request.setMethod("PUT");
        request.network = &context;
        request.network_partition_key = try a.dupe(u8, key.network_partition_key);
        var headers = [_]fetch.network.NetworkResponse.Header{
            .{ .name = "Access-Control-Allow-Origin", .value = key.origin },
            .{ .name = "Access-Control-Allow-Methods", .value = "PUT" },
            .{ .name = "Access-Control-Max-Age", .value = case.age },
        };
        const response: fetch.network.NetworkResponse = .{ .allocator = a, .status = 200, .http_version = .http_1_1, .total_time_ms = 0, .time_to_first_byte_ms = 0, .redirect_count = 0, .remote_ip = null, .remote_port = null, .headers = &headers, .body = null, .final_url = key.url };
        try std.testing.expect(try http.corsPreflightFetchFinish(a, request, &response));
        const now: i64 = @intFromFloat(http.getCurrentTimeMs());
        try std.testing.expectEqual(case.immediate, context.preflight_cache.allows(key, now + 1, false, "PUT", &.{}));
        try std.testing.expectEqual(case.six_seconds, context.preflight_cache.allows(key, now + 6000, false, "PUT", &.{}));
    }
}
