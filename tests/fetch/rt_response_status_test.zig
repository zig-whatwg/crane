const std = @import("std");
const fetch = @import("fetch");

const Report = struct {
    count: usize = 0,
    status: u16 = 999,
    encoded_size: u64 = 0,
    decoded_size: u64 = 0,
    content_type_empty: bool = true,
    content_encoding_empty: bool = true,
    content_encoding_gzip: bool = false,

    fn receive(context: *anyopaque, timing: *const fetch.internal.request.TimingReport) void {
        const self: *@This() = @ptrCast(@alignCast(context));
        self.count += 1;
        self.status = timing.response_status;
        self.encoded_size = timing.body_info.encoded_size;
        self.decoded_size = timing.body_info.decoded_size;
        // The report borrows strings only for this call; retain predicates,
        // not references into the response or the temporary MIME allocation.
        self.content_type_empty = timing.body_info.content_type.len == 0;
        self.content_encoding_empty = timing.body_info.content_encoding.len == 0;
        self.content_encoding_gzip = std.mem.eql(u8, timing.body_info.content_encoding, "gzip");
    }
};

test "resource timing reports filtered status without exposing an opaque response" {
    const allocator = std.testing.allocator;
    for ([_]bool{ false, true }) |tao| {
        for ([_]fetch.internal.request.RequestMode{ .no_cors, .cors, .same_origin }) |mode| {
            const same_origin = mode == .same_origin;
            const request = try fetch.internal.InternalRequest.init(allocator, if (same_origin) "http://a.test/resource" else "http://b.test/resource");
            defer request.deinit();
            try request.setOrigin("http://a.test");
            request.mode = mode;
            request.initiator_type = .fetch;
            var report: Report = .{};
            request.timing_reporter = .{ .context = &report, .report = &Report.receive };
            const job = try fetch.algorithms.FetchJob.create(allocator, request, false, .{});
            defer job.destroy();
            try std.testing.expect(try job.start() == .network);
            const headers = try allocator.alloc(fetch.network.NetworkResponse.Header, if (tao) 2 else 1);
            headers[0] = .{ .name = try allocator.dupe(u8, "Access-Control-Allow-Origin"), .value = try allocator.dupe(u8, "*") };
            if (tao) headers[1] = .{ .name = try allocator.dupe(u8, "Timing-Allow-Origin"), .value = try allocator.dupe(u8, "*") };
            // resumeNetwork owns the response and its header storage.
            const done = try job.resumeNetwork(.{
                .allocator = allocator,
                .status = 203,
                .http_version = .http_1_1,
                .headers = headers,
                .body = null,
                .final_url = null,
                .total_time_ms = 0,
                .time_to_first_byte_ms = 0,
                .redirect_count = 0,
                .remote_ip = null,
                .remote_port = null,
            });
            try std.testing.expect(done == .done);
            try std.testing.expectEqual(@as(usize, 1), report.count);
            try std.testing.expectEqual(@as(u16, if (mode == .no_cors) 0 else 203), report.status);
        }
    }
}

test "resource timing hides the status of a same-origin manual redirect" {
    const allocator = std.testing.allocator;
    const request = try fetch.internal.InternalRequest.init(allocator, "http://a.test/redirect");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    request.mode = .same_origin;
    request.redirect_mode = .manual;
    request.initiator_type = .fetch;
    var report: Report = .{};
    request.timing_reporter = .{ .context = &report, .report = &Report.receive };
    const job = try fetch.algorithms.FetchJob.create(allocator, request, false, .{});
    defer job.destroy();
    try std.testing.expect(try job.start() == .network);
    const headers = try allocator.alloc(fetch.network.NetworkResponse.Header, 1);
    headers[0] = .{ .name = try allocator.dupe(u8, "Location"), .value = try allocator.dupe(u8, "http://a.test/target") };
    const done = try job.resumeNetwork(.{
        .allocator = allocator,
        .status = 302,
        .http_version = .http_1_1,
        .headers = headers,
        .body = null,
        .final_url = null,
        .total_time_ms = 0,
        .time_to_first_byte_ms = 0,
        .redirect_count = 0,
        .remote_ip = null,
        .remote_port = null,
    });
    try std.testing.expect(done == .done);
    try std.testing.expectEqual(@as(usize, 1), report.count);
    try std.testing.expectEqual(@as(u16, 0), report.status);
}

fn bodyReport(manual: bool, tao: bool) !Report {
    const allocator = std.testing.allocator;
    const request = try fetch.internal.InternalRequest.init(allocator, if (manual) "http://a.test/redirect" else "http://b.test/encoded");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    request.mode = if (manual) .same_origin else .cors;
    request.redirect_mode = if (manual) .manual else .follow;
    request.initiator_type = .fetch;
    var report: Report = .{};
    request.timing_reporter = .{ .context = &report, .report = &Report.receive };
    const job = try fetch.algorithms.FetchJob.create(allocator, request, false, .{});
    defer job.destroy();
    try std.testing.expect(try job.start() == .network);
    const headers = try allocator.alloc(fetch.network.NetworkResponse.Header, if (tao) 4 else 3);
    headers[0] = .{ .name = try allocator.dupe(u8, if (manual) "Location" else "Access-Control-Allow-Origin"), .value = try allocator.dupe(u8, if (manual) "http://a.test/target" else "*") };
    headers[1] = .{ .name = try allocator.dupe(u8, "Content-Type"), .value = try allocator.dupe(u8, "text/plain") };
    headers[2] = .{ .name = try allocator.dupe(u8, "Content-Encoding"), .value = try allocator.dupe(u8, "gzip") };
    if (tao) headers[3] = .{ .name = try allocator.dupe(u8, "Timing-Allow-Origin"), .value = try allocator.dupe(u8, "*") };
    const done = try job.resumeNetwork(.{
        .allocator = allocator,
        .status = if (manual) 302 else 200,
        .http_version = .http_1_1,
        .headers = headers,
        // NetworkResponse's body is already decoded, as the real backend's is.
        .body = try allocator.dupe(u8, "decoded"),
        .final_url = null,
        .total_time_ms = 0,
        .time_to_first_byte_ms = 0,
        .redirect_count = 0,
        .remote_ip = null,
        .remote_port = null,
    });
    try std.testing.expect(done == .done);
    try std.testing.expectEqual(@as(usize, 1), report.count);
    return report;
}

test "opaque redirect timing hides internal body metadata" {
    const report = try bodyReport(true, false);
    try std.testing.expect(report.content_type_empty);
    try std.testing.expect(report.content_encoding_empty);
    try std.testing.expectEqual(@as(u64, 0), report.encoded_size);
    try std.testing.expectEqual(@as(u64, 0), report.decoded_size);
}

test "CORS timing without TAO exposes body sizes: they are CORS-protected, not TAO-protected" {
    // whatwg/fetch PR #1556 (2023-01-25), which Firefox 157 ships: a CORS
    // response's body info reaches resource timing whatever its
    // Timing-Allow-Origin; only an opaque response's is hidden.
    const report = try bodyReport(false, false);
    try std.testing.expect(report.content_encoding_gzip);
    try std.testing.expect(!report.content_type_empty);
    try std.testing.expectEqual(@as(u16, 200), report.status);
    try std.testing.expectEqual(@as(u64, "decoded".len), report.decoded_size);
    const with_tao = try bodyReport(false, true);
    try std.testing.expectEqual(with_tao.encoded_size, report.encoded_size);
    try std.testing.expectEqual(with_tao.decoded_size, report.decoded_size);
}
