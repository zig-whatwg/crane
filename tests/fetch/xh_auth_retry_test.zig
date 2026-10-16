const std = @import("std");
const fetch = @import("fetch");
const a = std.testing.allocator;
const Job = fetch.algorithms.FetchJob;

fn answer(status: u16) !fetch.network.NetworkResponse {
    const headers = try a.alloc(fetch.network.NetworkResponse.Header, 1);
    errdefer a.free(headers);
    headers[0] = .{ .name = try a.dupe(u8, "WWW-Authenticate"), .value = try a.dupe(u8, "Basic realm=\"protected\"") };
    return .{ .allocator = a, .status = status, .http_version = .http_1_1, .total_time_ms = 0, .time_to_first_byte_ms = 0, .redirect_count = 0, .remote_ip = null, .remote_port = null, .headers = headers, .body = null, .final_url = try a.dupe(u8, "https://u:p@server.test/a/file") };
}
fn header(network: *const fetch.network.NetworkRequest, name: []const u8) ?[]const u8 {
    for (network.headers) |h| if (std.ascii.eqlIgnoreCase(h.name, name)) return h.value;
    return null;
}

test "authentication challenge retries once on the shared sync and async job path" {
    for ([_]u16{ 200, 401 }) |final_status| {
        const request = try fetch.internal.InternalRequest.init(a, "https://u:p@server.test/a/file");
        defer request.deinit();
        try request.setOrigin("https://server.test");
        request.use_url_credentials = true;
        request.credentials_mode = .include;
        var traversable: u8 = 0;
        request.traversable_for_user_prompts = .{ .traversable = &traversable };
        const job = try Job.create(a, request, false, .{});
        defer job.destroy();
        const start = try job.start();
        try std.testing.expect(start == .network);
        try std.testing.expect(header(start.network.request, "Authorization") == null);
        const retry = try job.resumeNetwork(try answer(401));
        try std.testing.expect(retry == .network);
        try std.testing.expectEqualStrings("Basic dTpw", header(retry.network.request, "Authorization").?);
        try std.testing.expect(std.mem.indexOf(u8, retry.network.request.url, "@") == null);
        try std.testing.expect(try job.resumeNetwork(try answer(final_status)) == .done);
        var result = job.takeResult();
        defer result.deinit();
        try std.testing.expectEqual(final_status, result.response.status);
    }
}

test "canceled authentication challenge returns a network error instead of retrying" {
    const request = try fetch.internal.InternalRequest.init(a, "https://u:p@server.test/a/file");
    defer request.deinit();
    try request.setOrigin("https://server.test");
    request.use_url_credentials = true;
    request.credentials_mode = .include;
    var traversable: u8 = 0;
    request.traversable_for_user_prompts = .{ .traversable = &traversable };
    const job = try Job.create(a, request, false, .{});
    defer job.destroy();
    _ = try job.start();
    try job.controller.abort(null);
    try std.testing.expect(try job.resumeNetwork(try answer(401)) == .done);
    var result = job.takeResult();
    defer result.deinit();
    try std.testing.expectEqual(@as(u16, 0), result.response.status);
}

test "a source-less upload cannot be retried after an authentication challenge" {
    const request = try fetch.internal.InternalRequest.init(a, "https://u:p@server.test/a/file");
    defer request.deinit();
    try request.setOrigin("https://server.test");
    request.use_url_credentials = true;
    request.credentials_mode = .include;
    var traversable: u8 = 0;
    request.traversable_for_user_prompts = .{ .traversable = &traversable };
    const body = try fetch.internal.Body.fromBytes(a, "body");
    body.source = .none;
    request.body = .{ .body = body };
    const job = try Job.create(a, request, false, .{});
    defer job.destroy();
    _ = try job.start();
    try std.testing.expect(try job.resumeNetwork(try answer(401)) == .done);
    var result = job.takeResult();
    defer result.deinit();
    try std.testing.expectEqual(@as(u16, 0), result.response.status);
}

test "a captured partition reuses challenged credentials only within its protection space" {
    if (!@hasField(fetch.network.NetworkContext, "auth_entries")) return error.TestUnexpectedResult;
    var context = fetch.network.NetworkContext.init(a);
    defer context.deinit();
    const request = try fetch.internal.InternalRequest.init(a, "https://u:p@server.test/a/file");
    defer request.deinit();
    try request.setOrigin("https://server.test");
    request.network = &context;
    request.network_partition_key = try a.dupe(u8, "https://top.test");
    request.use_url_credentials = true;
    request.credentials_mode = .include;
    var traversable: u8 = 0;
    request.traversable_for_user_prompts = .{ .traversable = &traversable };
    request.body = .{ .body = try fetch.internal.Body.fromBytes(a, "repeatable") };
    const job = try Job.create(a, request, false, .{});
    defer job.destroy();
    _ = try job.start();
    const retry = try job.resumeNetwork(try answer(401));
    try std.testing.expect(retry == .network);
    try std.testing.expectEqualStrings("repeatable", retry.network.request.body.?);
    try std.testing.expectEqualStrings("repeatable", request.body.?.body.source.bytes);
    _ = try job.resumeNetwork(try answer(200));
    for ([_][]const u8{ "https://top.test", "https://other.test" }, 0..) |partition, i| {
        const next = try fetch.internal.InternalRequest.init(a, "https://server.test/a/deeper/file");
        defer next.deinit();
        try next.setOrigin("https://server.test");
        next.network = &context;
        next.network_partition_key = try a.dupe(u8, partition);
        next.credentials_mode = .include;
        const next_job = try Job.create(a, next, false, .{});
        defer next_job.destroy();
        const start = try next_job.start();
        try std.testing.expect(start == .network);
        if (i == 0) try std.testing.expectEqualStrings("Basic dTpw", header(start.network.request, "Authorization").?) else try std.testing.expect(header(start.network.request, "Authorization") == null);
    }
}

test "Basic challenge lists respect quoted commas, escapes and realm requirements" {
    const cases = [_]struct { value: []const u8, retry: bool }{
        .{ .value = "Digest realm=\"other,Basic\", Basic realm=\"quoted,\\\"realm\"", .retry = true },
        .{ .value = "Bearer abcdef, bAsIc realm=token, charset=\"UTF-8\"", .retry = true },
        .{ .value = "Digest realm=\"Basic realm=anything\"", .retry = false },
        .{ .value = "Basic realm=\"unfinished", .retry = false },
        .{ .value = "Basic realm=\"one\", realm=\"two\"", .retry = false },
        .{ .value = "Basic charset=\"UTF-8\"", .retry = false },
    };
    for (cases) |case| {
        const request = try fetch.internal.InternalRequest.init(a, "https://u:p@server.test/a/file");
        defer request.deinit();
        try request.setOrigin("https://server.test");
        request.use_url_credentials = true;
        request.credentials_mode = .include;
        var traversable: u8 = 0;
        request.traversable_for_user_prompts = .{ .traversable = &traversable };
        const job = try Job.create(a, request, false, .{});
        defer job.destroy();
        _ = try job.start();
        var response = try answer(401);
        a.free(response.headers[0].value);
        response.headers[0].value = try a.dupe(u8, case.value);
        const next = try job.resumeNetwork(response);
        try std.testing.expectEqual(case.retry, next == .network);
    }
}

test "preflight and credentials-omit transport URLs never contain userinfo" {
    for ([_]bool{ false, true }) |preflight| {
        const request = try fetch.internal.InternalRequest.init(a, "https://u:p@server.test/a/file");
        defer request.deinit();
        try request.setOrigin(if (preflight) "https://frame.test" else "https://server.test");
        request.mode = .cors;
        request.use_url_credentials = true;
        request.credentials_mode = if (preflight) .include else .omit;
        request.use_cors_preflight = preflight;
        const job = try Job.create(a, request, false, .{});
        defer job.destroy();
        const start = try job.start();
        try std.testing.expect(start == .network);
        try std.testing.expectEqualStrings(if (preflight) "OPTIONS" else "GET", start.network.request.method);
        try std.testing.expectEqualStrings("https://server.test/a/file", start.network.request.url);
        try std.testing.expect(header(start.network.request, "Authorization") == null);
    }
}
