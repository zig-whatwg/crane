const std = @import("std");
const fetch = @import("fetch");

const Report = struct {
    count: usize = 0,
    status: u16 = 0,

    fn receive(context: *anyopaque, timing: *const fetch.internal.TimingReport) void {
        const self: *@This() = @ptrCast(@alignCast(context));
        self.count += 1;
        self.status = timing.response_status;
    }
};

fn answer(status: u16, location: ?[]const u8, tao: bool) !fetch.network.NetworkResponse {
    const allocator = std.testing.allocator;
    var headers: std.ArrayList(fetch.network.NetworkResponse.Header) = .empty;
    errdefer {
        for (headers.items) |header| {
            allocator.free(header.name);
            allocator.free(header.value);
        }
        headers.deinit(allocator);
    }
    if (location) |url| try addHeader(&headers, "Location", url);
    if (tao) try addHeader(&headers, "Timing-Allow-Origin", "*");
    return .{
        .allocator = allocator,
        .status = status,
        .http_version = .http_1_1,
        .headers = try headers.toOwnedSlice(allocator),
        .body = null,
        .final_url = null,
        .total_time_ms = 0,
        .time_to_first_byte_ms = 0,
        .redirect_count = 0,
        .remote_ip = null,
        .remote_port = null,
    };
}

fn addHeader(headers: *std.ArrayList(fetch.network.NetworkResponse.Header), name: []const u8, value: []const u8) !void {
    const allocator = std.testing.allocator;
    const name_copy = try allocator.dupe(u8, name);
    errdefer allocator.free(name_copy);
    const value_copy = try allocator.dupe(u8, value);
    errdefer allocator.free(value_copy);
    try headers.append(allocator, .{ .name = name_copy, .value = value_copy });
}

fn navigationStatus(urls: []const []const u8, manual: bool, tao: bool, status: u16) !u16 {
    const allocator = std.testing.allocator;
    const request = try fetch.internal.InternalRequest.init(allocator, urls[0]);
    defer request.deinit();
    try request.setOrigin("http://a.test");
    request.mode = .navigate;
    request.destination = .iframe;
    request.redirect_mode = if (manual) .manual else .follow;
    request.initiator_type = .iframe;
    var report: Report = .{};
    request.timing_reporter = .{ .context = &report, .report = &Report.receive };
    const job = try fetch.algorithms.FetchJob.create(allocator, request, false, .{ .follows_manual_redirects = manual });
    defer job.destroy();
    try std.testing.expect(try job.start() == .network);
    for (urls[1..]) |url| {
        var step = try job.resumeNetwork(try answer(302, url, tao));
        if (manual) {
            try std.testing.expect(step == .done);
            var result = job.takeResult();
            result.deinit();
            step = try job.processNextManualRedirect();
        }
        try std.testing.expect(step == .network);
        try std.testing.expectEqual(@as(usize, 0), report.count);
    }
    try std.testing.expect(try job.resumeNetwork(try answer(status, null, tao)) == .done);
    try std.testing.expectEqual(@as(usize, 1), report.count);
    return report.status;
}

test "resource timing hides a navigation to another origin with or without TAO" {
    for ([_]bool{ false, true }) |manual| {
        for ([_]bool{ false, true }) |tao| {
            for ([_]u16{ 200, 203, 404, 503 }) |status| {
                try std.testing.expectEqual(@as(u16, 0), try navigationStatus(&.{"http://b.test/final"}, manual, tao, status));
            }
        }
    }
}

test "resource timing hides a navigation that returns through a cross-origin redirect" {
    for ([_]bool{ false, true }) |manual| {
        for ([_]bool{ false, true }) |tao| {
            try std.testing.expectEqual(@as(u16, 0), try navigationStatus(&.{
                "http://a.test/first", "http://b.test/second", "http://a.test/third", "http://a.test/final",
            }, manual, tao, 203));
        }
    }
}

test "resource timing preserves same-origin navigation status including HTTP errors" {
    for ([_]bool{ false, true }) |manual| {
        for ([_]bool{ false, true }) |tao| {
            for ([_]u16{ 200, 203, 404, 503 }) |status| {
                try std.testing.expectEqual(status, try navigationStatus(&.{"http://a.test/final"}, manual, tao, status));
                try std.testing.expectEqual(status, try navigationStatus(&.{ "http://a.test/first", "http://a.test/final" }, manual, tao, status));
            }
        }
    }
}
