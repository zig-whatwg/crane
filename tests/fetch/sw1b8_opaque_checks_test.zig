//! Main fetch step 20 runs its response checks on internalResponse (step
//! 15): an opaque filtered response a service worker answered with keeps its
//! status, URL and headers in its internal response, so the Mixed Content
//! check ("should internalResponse to request be blocked as mixed content")
//! and the MIME checks ("... due to its MIME type", "... due to nosniff")
//! read them there - as the CSP check does (sw1b7_csp_response_test.zig).
//! Before, both started with `isNetworkError(response)`, which reads the
//! opaque response's status 0 as a network error and skipped it (lesson
//! debugging-main-fetch-is-network-error-reads-an-opaque-response-as-one).

const std = @import("std");
const testing = std.testing;
const fetch = @import("fetch");
const FetchJob = fetch.algorithms.FetchJob;
const InternalRequest = fetch.internal.InternalRequest;
const InternalResponse = fetch.internal.InternalResponse;
const service_worker_fetch = fetch.internal.service_worker_fetch;

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

const Headers = []const [2][]const u8;

/// A worker's response from `url` with `headers`, filtered as `kind`: an
/// opaque one keeps its status, URL and headers in its internal response,
/// as respondWith() hands it on.
fn workerResponse(url: []const u8, headers: Headers, kind: fetch.internal.ResponseType) !*InternalResponse {
    const response = try InternalResponse.init(testing.allocator);
    errdefer response.deinit();
    response.status = 200;
    try response.addUrl(url);
    for (headers) |header| try response.header_list.append(header[0], header[1]);
    response.response_type = kind;
    if (kind == .@"opaque") try response.filter();
    return response;
}

fn request(url: []const u8, destination: fetch.internal.Destination) !*InternalRequest {
    const made = try InternalRequest.init(testing.allocator, url);
    errdefer made.deinit();
    try made.setOrigin("https://a.test");
    made.destination = destination;
    made.mode = .no_cors;
    return made;
}

/// Fetch `req` with the worker answering `response`; the response type
/// fetch hands back.
fn typeThroughWorker(req: *InternalRequest, response: *InternalResponse) !fetch.internal.ResponseType {
    var workers: Workers = .{};
    req.service_worker = workers.route();
    const job = try FetchJob.create(testing.allocator, req, false, .{});
    defer job.destroy();
    const step = try job.start();
    try testing.expect(step == .service_worker);
    workers.answer(response);
    const answer = step.service_worker.take().?;
    try testing.expect(try job.resumeServiceWorker(.{ .response = answer.response.response }) == .done);
    var result = job.takeResult();
    defer result.deinit();
    return result.response.response_type;
}

test "main fetch step 20: a worker's opaque script response with a nosniff non-JavaScript type, or an image type, is blocked" {
    const nosniff_text: Headers = &.{ .{ "Content-Type", "text/plain" }, .{ "X-Content-Type-Options", "nosniff" } };
    const image: Headers = &.{.{ "Content-Type", "image/png" }};
    const script: Headers = &.{ .{ "Content-Type", "text/javascript" }, .{ "X-Content-Type-Options", "nosniff" } };
    for ([_]fetch.internal.ResponseType{ .default, .@"opaque" }) |kind| {
        {
            const req = try request("https://a.test/s.js", .script);
            defer req.deinit();
            try testing.expectEqual(fetch.internal.ResponseType.@"error", try typeThroughWorker(req, try workerResponse("https://b.test/s.txt", nosniff_text, kind)));
        }
        {
            const req = try request("https://a.test/s.js", .script);
            defer req.deinit();
            try testing.expectEqual(fetch.internal.ResponseType.@"error", try typeThroughWorker(req, try workerResponse("https://b.test/s.png", image, kind)));
        }
        {
            const req = try request("https://a.test/s.js", .script);
            defer req.deinit();
            try testing.expect(try typeThroughWorker(req, try workerResponse("https://b.test/s.js", script, kind)) != .@"error");
        }
    }
}

test "main fetch step 20: a worker's opaque response from a URL that is not a priori authenticated is blocked as mixed content" {
    for ([_]fetch.internal.ResponseType{ .default, .@"opaque" }) |kind| {
        const req = try request("https://a.test/i.png", .image);
        defer req.deinit();
        req.prohibits_mixed_security_contexts = true;
        try testing.expectEqual(fetch.internal.ResponseType.@"error", try typeThroughWorker(req, try workerResponse("http://b.test/i.png", &.{}, kind)));
    }
    // An https response is allowed, opaque or not.
    for ([_]fetch.internal.ResponseType{ .default, .@"opaque" }) |kind| {
        const req = try request("https://a.test/i.png", .image);
        defer req.deinit();
        req.prohibits_mixed_security_contexts = true;
        try testing.expect(try typeThroughWorker(req, try workerResponse("https://b.test/i.png", &.{}, kind)) != .@"error");
    }
}
