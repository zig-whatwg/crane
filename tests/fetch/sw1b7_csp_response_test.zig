//! Main fetch step 20's "should internalResponse to request be blocked by
//! Content Security Policy?" (CSP 4.1.3): the client's policy is checked
//! against the URL of the response a service worker answered with, so a
//! worker cannot substitute a resource the page's CSP refuses
//! (service-workers/service-worker/fetch-csp.https.html).
//!
//! - a worker's response from an origin img-src does not allow - CORS-able or
//!   opaque (its internal response's URL) - is a network error, its
//!   violation reported to the client;
//! - a report-only policy's is reported and blocks nothing;
//! - its URL is matched as a redirected one: the path is ignored, as Chrome
//!   and Safari do;
//! - a network response needs no second check: its URL is a hop main fetch
//!   step 7 checked ("should request be blocked by Content Security
//!   Policy?"), and a redirect to a refused URL is blocked there, before the
//!   hop is fetched; a worker's response whose URL is the request's current
//!   URL is not checked again either (no second report).
const std = @import("std");
const testing = std.testing;
const fetch = @import("fetch");
const FetchJob = fetch.algorithms.FetchJob;
const InternalRequest = fetch.internal.InternalRequest;
const InternalResponse = fetch.internal.InternalResponse;
const PolicyContainer = fetch.internal.PolicyContainer;
const service_worker_fetch = fetch.internal.service_worker_fetch;
const NetworkResponse = fetch.network.NetworkResponse;

/// Every request goes to the "service worker", which the test plays.
const Workers = struct {
    call: ?*service_worker_fetch.Call = null,

    fn route(self: *Workers) fetch.internal.ServiceWorkerRoute {
        return .{ .context = self, .client = 3, .handle = handle };
    }

    fn handle(context: *anyopaque, _: *const InternalRequest, _: u64) std.mem.Allocator.Error!service_worker_fetch.Route.Start {
        const self: *Workers = @ptrCast(@alignCast(context));
        const call = try service_worker_fetch.Call.create(testing.allocator);
        self.call = call;
        return .{ .call = call };
    }

    fn answer(self: *Workers, response: *InternalResponse) void {
        const call = self.call.?;
        self.call = null;
        call.answer(.{ .response = .{ .response = response } });
        call.release();
    }
};

/// The violations the client hears.
const Reports = struct {
    count: usize = 0,
    /// The last violation's policy was report-only.
    report_only: bool = false,
    directive: [32]u8 = undefined,
    directive_len: usize = 0,

    fn reporter(self: *Reports) fetch.internal.CspViolationReporter {
        return .{ .context = self, .report = &report };
    }

    fn report(context: *anyopaque, violation: *const fetch.internal.CspViolation) void {
        const self: *Reports = @ptrCast(@alignCast(context));
        self.count += 1;
        self.report_only = violation.policy.disposition == .report;
        @memcpy(self.directive[0..violation.effective_directive.len], violation.effective_directive);
        self.directive_len = violation.effective_directive.len;
    }
};

const Policy = struct { csp: ?[]const u8 = null, report_only: ?[]const u8 = null };

fn imageRequest(url: []const u8, policy: Policy, reports: *Reports) !*InternalRequest {
    const request = try InternalRequest.init(testing.allocator, url);
    errdefer request.deinit();
    try request.setOrigin("https://a.test");
    request.destination = .image;
    request.mode = .no_cors;
    request.csp_violation_reporter = reports.reporter();
    request.setPolicyContainer(try PolicyContainer.fromResponseHeaders(testing.allocator, .{
        .url = "https://a.test/page.html",
        .csp = policy.csp,
        .csp_report_only = policy.report_only,
    }));
    return request;
}

/// A worker's response with `url` its URL list, filtered as `kind` - an
/// opaque one keeps its URL in its internal response, as respondWith()
/// hands it on.
fn workerResponse(url: []const u8, kind: fetch.internal.ResponseType) !*InternalResponse {
    const response = try InternalResponse.init(testing.allocator);
    errdefer response.deinit();
    response.status = 200;
    try response.addUrl(url);
    response.response_type = kind;
    if (kind == .@"opaque") try response.filter();
    return response;
}

/// Fetch `request` with the worker answering `response`; the response
/// fetch hands back.
fn fetchThroughWorker(request: *InternalRequest, response: *InternalResponse) !fetch.algorithms.FetchResult {
    var workers: Workers = .{};
    request.service_worker = workers.route();
    const job = try FetchJob.create(testing.allocator, request, false, .{});
    defer job.destroy();
    const step = try job.start();
    try testing.expect(step == .service_worker);
    workers.answer(response);
    const answer = step.service_worker.take().?;
    try testing.expect(try job.resumeServiceWorker(.{ .response = answer.response.response }) == .done);
    return job.takeResult();
}

test "CSP 4.1.3: a worker's response from an origin img-src refuses is a network error, its violation reported" {
    for ([_]fetch.internal.ResponseType{ .default, .cors, .@"opaque" }) |kind| {
        var reports: Reports = .{};
        const request = try imageRequest("https://a.test/sample?url=b", .{ .csp = "img-src https://a.test" }, &reports);
        defer request.deinit();
        var result = try fetchThroughWorker(request, try workerResponse("https://b.test/image.png", kind));
        defer result.deinit();
        try testing.expectEqual(fetch.internal.ResponseType.@"error", result.response.response_type);
        try testing.expectEqual(@as(usize, 1), reports.count);
        try testing.expectEqualStrings("img-src", reports.directive[0..reports.directive_len]);
    }
}

test "CSP 4.1.3: a worker's response from an origin img-src allows loads" {
    var reports: Reports = .{};
    const request = try imageRequest("https://a.test/sample?url=a", .{ .csp = "img-src https://a.test" }, &reports);
    defer request.deinit();
    var result = try fetchThroughWorker(request, try workerResponse("https://a.test/image.png", .basic));
    defer result.deinit();
    try testing.expectEqual(@as(u16, 200), result.response.status);
    try testing.expectEqual(@as(usize, 0), reports.count);
}

test "CSP 4.1.3: a worker's response URL is matched as a redirected one - its path is ignored (Chrome, Safari)" {
    var reports: Reports = .{};
    const request = try imageRequest("https://a.test/redirect.py?url=x", .{ .csp = "img-src https://a.test/redirect.py" }, &reports);
    defer request.deinit();
    var result = try fetchThroughWorker(request, try workerResponse("https://a.test/image.png", .basic));
    defer result.deinit();
    try testing.expectEqual(@as(u16, 200), result.response.status);
    try testing.expectEqual(@as(usize, 0), reports.count);
}

test "CSP 4.1.3: a report-only policy's violation by a worker's response is reported and blocks nothing" {
    var reports: Reports = .{};
    const request = try imageRequest("https://a.test/sample?url=b", .{ .report_only = "img-src https://a.test" }, &reports);
    defer request.deinit();
    var result = try fetchThroughWorker(request, try workerResponse("https://b.test/image.png", .default));
    defer result.deinit();
    try testing.expectEqual(@as(u16, 200), result.response.status);
    try testing.expectEqual(@as(usize, 1), reports.count);
    try testing.expect(reports.report_only);
}

test "a worker's response whose URL is the request's current URL is not checked twice: one report-only report" {
    var reports: Reports = .{};
    const request = try imageRequest("https://b.test/image.png", .{ .report_only = "img-src https://a.test" }, &reports);
    defer request.deinit();
    var result = try fetchThroughWorker(request, try workerResponse("https://b.test/image.png", .default));
    defer result.deinit();
    try testing.expectEqual(@as(u16, 200), result.response.status);
    // Main fetch step 4 reported it; step 20 did not again.
    try testing.expectEqual(@as(usize, 1), reports.count);
}

fn redirectTo(location: []const u8) !NetworkResponse {
    const headers = try testing.allocator.alloc(NetworkResponse.Header, 1);
    headers[0] = .{ .name = try testing.allocator.dupe(u8, "Location"), .value = try testing.allocator.dupe(u8, location) };
    return .{
        .allocator = testing.allocator,
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
    };
}

test "a network redirect to a URL img-src refuses is blocked by the hop's main fetch step 7, before it is fetched" {
    var reports: Reports = .{};
    const request = try imageRequest("https://a.test/redirect", .{ .csp = "img-src https://a.test" }, &reports);
    defer request.deinit();
    const job = try FetchJob.create(testing.allocator, request, false, .{});
    defer job.destroy();
    try testing.expect(try job.start() == .network);
    // The redirect's main fetch (HTTP-redirect fetch, recursive) checks the
    // hop: no request for it goes out, a network error is the answer.
    try testing.expect(try job.resumeNetwork(redirectTo("https://b.test/image.png")) == .done);
    var result = job.takeResult();
    defer result.deinit();
    try testing.expectEqual(fetch.internal.ResponseType.@"error", result.response.response_type);
    try testing.expectEqual(@as(usize, 1), reports.count);
}
