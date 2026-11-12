//! A request carries the location of the script that started it, for the
//! CSP violations main fetch finds when no script runs (CSP 2.4.1 step 2;
//! fetch.internal.InternalRequest.csp_violation_location): HTML "update the
//! image data" fetches after its microtask. Firefox and Safari report that
//! location (Gecko's ImageLoadTask + JSCallingLocation::AutoFallback); only
//! the checks before any redirect carry it. The request owns it: a clone
//! copies it, and a terminated fetch frees it (std.testing.allocator).

const std = @import("std");
const testing = std.testing;
const clock = @import("clock");
const fetch = @import("fetch");
const check = fetch.algorithms.csp_check;
const network = fetch.network;
const AsyncFetch = fetch.algorithms.AsyncFetch;
const AgentFetches = fetch.algorithms.AgentFetches;
const InternalRequest = fetch.internal.InternalRequest;
const TestServer = @import("test_server.zig").TestServer;

const a = testing.allocator;

/// What a client's reporter heard: the location of each violation.
const Capture = struct {
    count: usize = 0,
    located: bool = false,
    url: [128]u8 = undefined,
    url_len: usize = 0,
    line: u32 = 0,
    column: u32 = 0,

    fn report(context: *anyopaque, violation: *const fetch.internal.CspViolation) void {
        const self: *Capture = @ptrCast(@alignCast(context));
        self.count += 1;
        self.located = violation.location != null;
        const location = violation.location orelse return;
        @memcpy(self.url[0..location.url.len], location.url);
        self.url_len = location.url.len;
        self.line = location.line;
        self.column = location.column;
    }

    fn locationUrl(self: *const Capture) []const u8 {
        return self.url[0..self.url_len];
    }
};

const script_url = "https://page.test/inject-image.js";

fn imageRequest(url: []const u8, policy: fetch.internal.policy_container.ResponseHeaders, capture: *Capture) !*InternalRequest {
    const request = try InternalRequest.init(a, url);
    errdefer request.deinit();
    request.destination = .image;
    request.setPolicyContainer(try fetch.internal.PolicyContainer.fromResponseHeaders(a, policy));
    request.csp_violation_reporter = .{ .context = capture, .report = &Capture.report };
    try request.setCspViolationLocation(.{ .url = script_url, .line = 2, .column = 7 });
    return request;
}

test "main fetch step 7: a blocked request's violation carries the location of the script that started it" {
    var capture: Capture = .{};
    const request = try imageRequest("https://page.test/fail.png", .{ .url = "https://page.test/", .csp = "img-src 'none'" }, &capture);
    defer request.deinit();
    try testing.expect(check.shouldRequestBeBlocked(request));
    try testing.expectEqual(@as(usize, 1), capture.count);
    try testing.expect(capture.located);
    try testing.expectEqualStrings(script_url, capture.locationUrl());
    try testing.expectEqual(@as(u32, 2), capture.line);
    try testing.expectEqual(@as(u32, 7), capture.column);
}

test "main fetch step 4: a report-only policy's violation carries it too" {
    var capture: Capture = .{};
    const request = try imageRequest("https://page.test/fail.png", .{ .url = "https://page.test/", .csp_report_only = "img-src 'none'" }, &capture);
    defer request.deinit();
    check.reportViolationsForRequest(request);
    try testing.expectEqual(@as(usize, 1), capture.count);
    try testing.expect(capture.located);
    try testing.expectEqual(@as(u32, 2), capture.line);
}

test "a redirect's check and the response's carry no location: no script stands behind them in any browser" {
    var capture: Capture = .{};
    const request = try imageRequest("https://page.test/redirect.png", .{ .url = "https://page.test/", .csp = "img-src https://page.test" }, &capture);
    defer request.deinit();
    // The redirect: HTTP-redirect fetch counts it, then runs main fetch again.
    try request.addUrl("https://elsewhere.test/fail.png");
    request.redirect_count = 1;
    try testing.expect(check.shouldRequestBeBlocked(request));
    try testing.expectEqual(@as(usize, 1), capture.count);
    try testing.expect(!capture.located);
    // Main fetch step 20, for a response from elsewhere.
    request.redirect_count = 0;
    try testing.expect(check.shouldResponseBeBlocked(request, "https://elsewhere.test/fail.png"));
    try testing.expectEqual(@as(usize, 2), capture.count);
    try testing.expect(!capture.located);
}

test "a clone owns its CSP violation location, so both requests can be freed" {
    var capture: Capture = .{};
    const original = try imageRequest("https://page.test/a.png", .{ .url = "https://page.test/", .csp = "img-src 'none'" }, &capture);
    const copy = try original.clone();
    try testing.expectEqualStrings(script_url, copy.csp_violation_location.?.url);
    try testing.expect(copy.csp_violation_location.?.url.ptr != original.csp_violation_location.?.url.ptr);
    try testing.expectEqual(@as(u32, 7), copy.csp_violation_location.?.column);
    // Replacing and clearing release the URL they replace.
    try copy.setCspViolationLocation(.{ .url = "https://page.test/other.js", .line = 9, .column = 1 });
    try copy.setCspViolationLocation(null);
    try testing.expect(copy.csp_violation_location == null);
    original.deinit();
    copy.deinit();
}

/// A client that records whether it heard; never gone.
const Recorder = struct {
    done_calls: usize = 0,

    fn client(self: *Recorder) AsyncFetch.Client {
        return .{ .context = self, .done = done, .alive = alive, .gone = gone };
    }

    fn done(context: *anyopaque, result: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
        const self: *Recorder = @ptrCast(@alignCast(context));
        self.done_calls += 1;
        var r = result catch return;
        r.deinit();
    }

    fn alive(_: *anyopaque) bool {
        return true;
    }

    fn gone(_: *anyopaque) void {}
};

test "the fetch of a blocked request reports the carried location, and a terminated one frees it" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(a);
    defer server.stop();
    var fetches = AgentFetches.init(a);
    defer fetches.deinit();
    var base_buf: [128]u8 = undefined;
    var url_buf: [256]u8 = undefined;
    const base = server.getBaseUrl(&base_buf);

    // Blocked at main fetch step 7, from the fetch itself.
    var blocked_capture: Capture = .{};
    var blocked_recorder: Recorder = .{};
    const blocked_url = try std.fmt.bufPrint(&url_buf, "{s}/fail.png", .{base});
    _ = try AsyncFetch.start(a, try imageRequest(blocked_url, .{ .url = "https://page.test/", .csp = "img-src 'none'" }, &blocked_capture), .{}, &fetches, blocked_recorder.client());
    var deadline = clock.monotonicMillis() + 2_000;
    while (blocked_recorder.done_calls == 0 and clock.monotonicMillis() < deadline) {
        _ = fetches.pump();
        clock.sleep(std.time.ns_per_ms);
    }
    try testing.expectEqual(@as(usize, 1), blocked_recorder.done_calls);
    try testing.expectEqual(@as(usize, 1), blocked_capture.count);
    try testing.expect(blocked_capture.located);
    try testing.expectEqual(@as(u32, 2), blocked_capture.line);

    // Allowed and in flight, then terminated: the request and its location go
    // with the fetch.
    var capture: Capture = .{};
    var recorder: Recorder = .{};
    const delayed_url = try std.fmt.bufPrint(&url_buf, "{s}/delay/1", .{base});
    const delayed = try AsyncFetch.start(a, try imageRequest(delayed_url, .{ .url = "https://page.test/", .csp = "script-src 'none'" }, &capture), .{}, &fetches, recorder.client());
    _ = fetches.pump();
    delayed.terminate();
    deadline = clock.monotonicMillis() + 1_500;
    while (clock.monotonicMillis() < deadline) {
        _ = fetches.pump();
        clock.sleep(5 * std.time.ns_per_ms);
    }
    try testing.expectEqual(@as(usize, 0), recorder.done_calls);
    try testing.expectEqual(@as(usize, 0), capture.count);
    try testing.expectEqual(@as(usize, 0), fetches.inFlight());
}
