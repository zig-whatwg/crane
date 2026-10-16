const std = @import("std");
const fetch = @import("fetch");

test "Server-Timing header storage owns the header text" {
    const allocator = std.testing.allocator;
    var timing = fetch.internal.fetch_timing.FetchTimingInfo.init(allocator);
    defer timing.deinit();
    var header = [_]u8{ 'd', 'b', ';', 'd', 'u', 'r', '=', '7' };
    try timing.addServerTimingHeader(&header);
    header[0] = 'x';
    try std.testing.expectEqualStrings("db;dur=7", timing.server_timing_headers.items[0]);
}

const Report = struct {
    calls: usize = 0,
    count: usize = 0,
    has_db: bool = false,
    has_cache: bool = false,

    fn receive(context: *anyopaque, report: *const fetch.internal.request.TimingReport) void {
        const self: *@This() = @ptrCast(@alignCast(context));
        self.calls += 1;
        self.count = report.timing_info.server_timing_headers.items.len;
        for (report.timing_info.server_timing_headers.items) |header| {
            self.has_db = self.has_db or std.mem.indexOf(u8, header, "db;dur=7") != null;
            self.has_cache = self.has_cache or std.mem.indexOf(u8, header, "cache;desc=hit") != null;
        }
    }
};

test "Server-Timing reaches resource reports only when timing allow passes" {
    for ([_]bool{ false, true }) |same_origin| {
        for ([_]bool{ false, true }) |tao| {
            try checkResponse(same_origin, tao, false);
        }
    }
}

test "Server-Timing is kept in navigation fetch timing without a resource reporter" {
    try checkResponse(true, false, true);
}

fn checkResponse(same_origin: bool, tao: bool, navigation: bool) !void {
    const allocator = std.testing.allocator;
    const request = try fetch.internal.InternalRequest.init(allocator, if (same_origin) "http://a.test/resource" else "http://b.test/resource");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    request.mode = if (navigation) .navigate else if (same_origin) .same_origin else .no_cors;
    var report: Report = .{};
    if (!navigation) {
        request.initiator_type = .fetch;
        request.timing_reporter = .{ .context = &report, .report = &Report.receive };
    }
    const job = try fetch.algorithms.FetchJob.create(allocator, request, false, .{});
    defer job.destroy();
    try std.testing.expect(try job.start() == .network);
    const headers = try allocator.alloc(fetch.network.NetworkResponse.Header, if (tao) 3 else 2);
    headers[0] = .{ .name = try allocator.dupe(u8, "Server-Timing"), .value = try allocator.dupe(u8, "db;dur=7") };
    headers[1] = .{ .name = try allocator.dupe(u8, "server-timing"), .value = try allocator.dupe(u8, "cache;desc=hit") };
    if (tao) headers[2] = .{ .name = try allocator.dupe(u8, "Timing-Allow-Origin"), .value = try allocator.dupe(u8, "*") };
    // resumeNetwork takes the headers. The retained timing must outlive them.
    try std.testing.expect(try job.resumeNetwork(.{
        .allocator = allocator,
        .status = 200,
        .http_version = .http_1_1,
        .headers = headers,
        .body = null,
        .final_url = null,
        .total_time_ms = 0,
        .time_to_first_byte_ms = 0,
        .redirect_count = 0,
        .remote_ip = null,
        .remote_port = null,
    }) == .done);
    if (!navigation) {
        try std.testing.expectEqual(@as(usize, 1), report.calls);
        if (same_origin or tao) {
            try std.testing.expect(report.count > 0);
            try std.testing.expect(report.has_db and report.has_cache);
        } else {
            try std.testing.expectEqual(@as(usize, 0), report.count);
        }
    }
    var result = job.takeResult();
    defer result.deinit();
    try std.testing.expect(result.timing_info.server_timing_headers.items.len > 0);
}
