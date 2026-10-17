//! Fetch's integrity-only full-body continuation and cancellation.
const std = @import("std");
const fetch = @import("fetch");
const clock = @import("clock");
const TestServer = @import("test_server.zig").TestServer;
const Job = fetch.algorithms.FetchJob;
const Source = fetch.internal.body_pipe.PipeSource;
const good = "sha256-ungWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0=";

fn head(status: u16, location: ?[]const u8) !fetch.network.NetworkResponse {
    const a = std.testing.allocator;
    const headers = try a.alloc(fetch.network.NetworkResponse.Header, if (location != null) 1 else 0);
    if (location) |url| headers[0] = .{ .name = try a.dupe(u8, "Location"), .value = try a.dupe(u8, url) };
    return .{ .allocator = a, .status = status, .http_version = .http_1_1, .headers = headers, .body = null, .final_url = null, .total_time_ms = 0, .time_to_first_byte_ms = 0, .redirect_count = 0, .remote_ip = null, .remote_port = null };
}

fn request(metadata: []const u8) !*fetch.internal.InternalRequest {
    const r = try fetch.internal.InternalRequest.init(std.testing.allocator, "http://a.test/start");
    errdefer r.deinit();
    r.mode = .same_origin;
    try r.setOrigin("http://a.test");
    try r.setIntegrityMetadata(metadata);
    return r;
}

// During the red run the continuation does not exist yet. This keeps the
// failure on the observed early handoff, rather than a compilation error.
fn resumeIntegrity(job: *Job) !Job.Step {
    if (comptime @hasDecl(Job, "resumeBody")) return job.resumeBody();
    return error.TestUnexpectedResult;
}

const Reporter = struct {
    calls: usize = 0,
    fn report(context: *anyopaque, _: *const fetch.internal.request.TimingReport) void {
        const self: *@This() = @ptrCast(@alignCast(context));
        self.calls += 1;
    }
};

test "sri body handoff waits for completion and rejects a partial or mismatched body" {
    for ([_]enum { match, mismatch, failed }{ .match, .mismatch, .failed }) |kind| {
        const r = try request(if (kind == .mismatch) "sha512-AAAA" else good);
        defer r.deinit();
        var reporter: Reporter = .{};
        r.initiator_type = .fetch;
        r.timing_reporter = .{ .context = &reporter, .report = Reporter.report };
        const job = try Job.create(std.testing.allocator, r, false, .{});
        defer job.destroy();
        try std.testing.expect(try job.start() == .network);
        const source = try Source.create(std.testing.allocator);
        const step = try job.resumeNetworkHead(try head(200, null), try source.branch());
        source.push("a");
        // End before asserting so the baseline failure also cleans up.
        if (kind == .failed) source.fail(.{ .kind = .network }) else {
            source.push("bc");
            source.finish();
        }
        try std.testing.expectEqualStrings("body", @tagName(step));
        try std.testing.expectEqual(@as(usize, 0), reporter.calls);
        try std.testing.expect(try resumeIntegrity(job) == .done);
        try std.testing.expectEqual(@as(usize, 1), reporter.calls);
        var result = job.takeResult();
        defer result.deinit();
        if (kind == .match) {
            try std.testing.expectEqual(fetch.internal.ResponseType.basic, result.response.response_type);
            try std.testing.expect(result.response.body.?.pipe == null);
            try std.testing.expectEqualStrings("abc", result.response.body.?.getBytes());
        } else {
            try std.testing.expectEqual(fetch.internal.ResponseType.@"error", result.response.response_type);
            try std.testing.expect(result.response.body == null);
        }
    }
}

test "sri redirects wait only for the final response and verify its bytes" {
    const r = try request(good);
    defer r.deinit();
    const job = try Job.create(std.testing.allocator, r, false, .{});
    defer job.destroy();
    try std.testing.expect(try job.start() == .network);
    try std.testing.expect(try job.resumeNetwork(try head(302, "http://a.test/final")) == .network);
    const source = try Source.create(std.testing.allocator);
    const step = try job.resumeNetworkHead(try head(200, null), try source.branch());
    source.push("abc");
    source.finish();
    try std.testing.expectEqualStrings("body", @tagName(step));
    try std.testing.expect(try resumeIntegrity(job) == .done);
    var result = job.takeResult();
    defer result.deinit();
    try std.testing.expectEqualStrings("abc", result.response.body.?.getBytes());
    try std.testing.expectEqual(@as(usize, 2), result.response.url_list.items.len);
}

test "sri empty metadata preserves network then done without waiting for its pipe" {
    const r = try request("");
    defer r.deinit();
    const job = try Job.create(std.testing.allocator, r, false, .{});
    defer job.destroy();
    try std.testing.expect(try job.start() == .network);
    const source = try Source.create(std.testing.allocator);
    const step = try job.resumeNetworkHead(try head(200, null), try source.branch());
    source.finish();
    try std.testing.expect(step == .done);
}

test "sri rejects opaque and opaque-redirect filtered bodies" {
    for ([_]bool{ false, true }) |manual| {
        const r = try request(good);
        defer r.deinit();
        if (manual) r.redirect_mode = .manual else try r.setOrigin("http://b.test");
        if (!manual) r.mode = .no_cors;
        const job = try Job.create(std.testing.allocator, r, false, .{});
        defer job.destroy();
        try std.testing.expect(try job.start() == .network);
        var answer = try head(if (manual) 302 else 200, if (manual) "http://a.test/target" else null);
        answer.body = try std.testing.allocator.dupe(u8, "abc");
        const step = try job.resumeNetwork(answer);
        if (std.mem.eql(u8, @tagName(step), "body")) _ = try resumeIntegrity(job);
        var result = job.takeResult();
        defer result.deinit();
        try std.testing.expectEqual(fetch.internal.ResponseType.@"error", result.response.response_type);
    }
}

const Client = struct {
    living: bool = true,
    dones: usize = 0,
    gones: usize = 0,
    result: ?fetch.FetchResult = null,
    fn done(context: *anyopaque, result: fetch.algorithms.FetchError!fetch.FetchResult) void {
        const self: *@This() = @ptrCast(@alignCast(context));
        self.dones += 1;
        self.result = result catch return;
    }
    fn alive(context: *anyopaque) bool {
        const self: *@This() = @ptrCast(@alignCast(context));
        return self.living;
    }
    fn gone(context: *anyopaque) void {
        const self: *@This() = @ptrCast(@alignCast(context));
        self.gones += 1;
    }
};

test "sri a client that disappears while awaiting its body releases it without handoff" {
    const a = std.testing.allocator;
    try fetch.network.globalInit();
    defer fetch.network.globalCleanup();
    const server = try TestServer.start(a);
    defer server.stop();
    var base_buf: [128]u8 = undefined;
    const url = try std.fmt.allocPrint(a, "{s}/trickle/10", .{server.getBaseUrl(&base_buf)});
    defer a.free(url);
    const r = try fetch.internal.InternalRequest.init(a, url);
    try r.setIntegrityMetadata(good);
    var fetches = fetch.algorithms.AgentFetches.init(a);
    defer fetches.deinit();
    var client: Client = .{};
    defer if (client.result) |*result| result.deinit();
    _ = try fetch.algorithms.AsyncFetch.startStreaming(a, r, .{}, &fetches, .{
        .context = &client,
        .done = Client.done,
        .alive = Client.alive,
        .gone = Client.gone,
    });
    const deadline = clock.monotonicMillis() + 3000;
    while (fetches.live.items.len > 0 and fetches.live.items[0].source == null and clock.monotonicMillis() < deadline) {
        _ = fetches.pump();
        clock.sleep(std.time.ns_per_ms);
    }
    const received_head = fetches.live.items.len > 0 and fetches.live.items[0].source != null;
    const early_handoffs = client.dones;
    client.living = false;
    _ = fetches.sweep();
    _ = fetches.pump();
    try std.testing.expect(received_head);
    try std.testing.expectEqual(@as(usize, 0), early_handoffs);
    try std.testing.expectEqual(@as(usize, 0), client.dones);
    try std.testing.expectEqual(@as(usize, 1), client.gones);
    try std.testing.expectEqual(@as(usize, 0), fetches.inFlight());
    try std.testing.expectEqual(@as(usize, 0), fetches.scheduler.inFlight());
}

const Producer = struct {
    cancels: usize = 0,
    fn cancel(context: *anyopaque) void {
        const self: *@This() = @ptrCast(@alignCast(context));
        self.cancels += 1;
    }
};

test "sri opaque pipe is cancelled at headers without waiting for any bytes" {
    const r = try request(good);
    defer r.deinit();
    try r.setOrigin("http://b.test");
    r.mode = .no_cors;
    const job = try Job.create(std.testing.allocator, r, false, .{});
    defer job.destroy();
    try std.testing.expect(try job.start() == .network);
    var producer: Producer = .{};
    const source = try Source.create(std.testing.allocator);
    source.producer = .{ .context = &producer, .cancel = Producer.cancel };
    const step = try job.resumeNetworkHead(try head(200, null), try source.branch());
    // Do not touch source here: the fixed path has already released it.
    try std.testing.expect(step == .done);
    try std.testing.expectEqual(@as(usize, 1), producer.cancels);
    var result = job.takeResult();
    defer result.deinit();
    try std.testing.expectEqual(fetch.internal.ResponseType.@"error", result.response.response_type);
    try std.testing.expectEqual(@as(u16, 0), result.response.status);
    try std.testing.expectEqual(@as(usize, 0), result.response.header_list.entries.items.len);
    try std.testing.expect(result.response.body == null);
    try std.testing.expectEqualDeep(@as(@TypeOf(result.response.body_info), .{}), result.response.body_info);
    try std.testing.expectEqual(.empty, result.response.cache_state);
}

test "sri data URL resumes immediately but only pump hands its checked response to the client" {
    for ([_]bool{ true, false }) |match| {
        const a = std.testing.allocator;
        const r = try fetch.internal.InternalRequest.init(a, "data:text/plain,abc");
        try r.setIntegrityMetadata(if (match) good else "sha256-AAAA");
        var fetches = fetch.algorithms.AgentFetches.init(a);
        defer fetches.deinit();
        var client: Client = .{};
        defer if (client.result) |*result| result.deinit();
        const active = try fetch.algorithms.AsyncFetch.startStreaming(a, r, .{}, &fetches, .{
            .context = &client,
            .done = Client.done,
            .alive = Client.alive,
            .gone = Client.gone,
        });
        try std.testing.expect(active.source == null);
        try std.testing.expectEqual(@as(usize, 0), client.dones);
        _ = fetches.pump();
        try std.testing.expectEqual(@as(usize, 1), client.dones);
        const result = client.result orelse return error.MissingResult;
        if (match) {
            try std.testing.expectEqualStrings("abc", result.response.body.?.getBytes());
        } else {
            try std.testing.expectEqual(fetch.internal.ResponseType.@"error", result.response.response_type);
        }
        try std.testing.expectEqual(@as(usize, 0), fetches.inFlight());
    }
}
