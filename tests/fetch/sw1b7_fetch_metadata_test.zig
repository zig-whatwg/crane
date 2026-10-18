//! Fetch HTTP-network-or-cache fetch step 8.13, "append the Fetch metadata
//! headers for httpRequest" (Fetch Metadata Request Headers 3): every request
//! to a potentially trustworthy URL goes out with `Sec-Fetch-Dest`,
//! `Sec-Fetch-Mode` and `Sec-Fetch-Site`, and a user-activated navigation
//! with `Sec-Fetch-User: ?1`. They are the request sent's, recomputed at
//! every hop - never the request's own header list, so a service worker's
//! event.request and a CORS preflight's Access-Control-Request-Headers never
//! see them - and a CORS preflight, itself an HTTP-network-or-cache fetch,
//! sends them too, in mode "cors".
//!
//! The requests are handed to the network as FetchJob steps; nothing goes
//! out.
const std = @import("std");
const testing = std.testing;
const fetch = @import("fetch");
const FetchJob = fetch.algorithms.FetchJob;
const InternalRequest = fetch.internal.InternalRequest;
const NetworkRequest = fetch.network.NetworkRequest;
const NetworkResponse = fetch.network.NetworkResponse;

fn header(request: *const NetworkRequest, name: []const u8) ?[]const u8 {
    for (request.headers) |h| if (std.ascii.eqlIgnoreCase(h.name, name)) return h.value;
    return null;
}

fn expectHeader(request: *const NetworkRequest, name: []const u8, want: ?[]const u8) !void {
    const got = header(request, name);
    if (want) |w| {
        if (got == null) {
            std.debug.print("{s}: missing, want {s}\n", .{ name, w });
            return error.TestExpectedEqual;
        }
        try testing.expectEqualStrings(w, got.?);
    } else if (got) |g| {
        std.debug.print("{s}: {s}, want none\n", .{ name, g });
        return error.TestExpectedEqual;
    }
}

fn redirectTo(location: []const u8) !NetworkResponse {
    const headers = try testing.allocator.alloc(NetworkResponse.Header, 1);
    headers[0] = .{ .name = try testing.allocator.dupe(u8, "Location"), .value = try testing.allocator.dupe(u8, location) };
    return .{
        .allocator = testing.allocator,
        .status = 307,
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

test "a fetch() to an https URL: Sec-Fetch-Dest empty, Sec-Fetch-Mode its mode, Sec-Fetch-Site same-origin" {
    const request = try InternalRequest.init(testing.allocator, "https://web-platform.test:8443/data.json");
    defer request.deinit();
    try request.setOrigin("https://web-platform.test:8443");
    request.mode = .cors;
    const job = try FetchJob.create(testing.allocator, request, false, .{});
    defer job.destroy();
    const step = try job.start();
    try testing.expect(step == .network);
    const sent = step.network.request;
    try expectHeader(sent, "Sec-Fetch-Dest", "empty");
    try expectHeader(sent, "Sec-Fetch-Mode", "cors");
    try expectHeader(sent, "Sec-Fetch-Site", "same-origin");
    try expectHeader(sent, "Sec-Fetch-User", null);
    // Not the request's header list.
    try testing.expect(!request.header_list.contains("Sec-Fetch-Mode"));
}

test "an image from a same-site origin, and a script from a cross-site one" {
    inline for (.{
        .{ "https://www1.web-platform.test:8443/i.png", .image, .no_cors, "image", "no-cors", "same-site" },
        .{ "https://not-web-platform.test:8443/s.js", .script, .no_cors, "script", "no-cors", "cross-site" },
        .{ "https://web-platform.test:8443/frame.html", .iframe, .navigate, "iframe", "navigate", "same-origin" },
    }) |case| {
        const request = try InternalRequest.init(testing.allocator, case[0]);
        defer request.deinit();
        try request.setOrigin("https://web-platform.test:8443");
        request.destination = case[1];
        request.mode = case[2];
        const job = try FetchJob.create(testing.allocator, request, false, .{});
        defer job.destroy();
        const step = try job.start();
        const sent = step.network.request;
        try expectHeader(sent, "Sec-Fetch-Dest", case[3]);
        try expectHeader(sent, "Sec-Fetch-Mode", case[4]);
        try expectHeader(sent, "Sec-Fetch-Site", case[5]);
    }
}

test "a URL that is not potentially trustworthy gets no metadata headers" {
    const request = try InternalRequest.init(testing.allocator, "http://web-platform.test:8000/data.json");
    defer request.deinit();
    try request.setOrigin("http://web-platform.test:8000");
    const job = try FetchJob.create(testing.allocator, request, false, .{});
    defer job.destroy();
    const step = try job.start();
    try expectHeader(step.network.request, "Sec-Fetch-Dest", null);
    try expectHeader(step.network.request, "Sec-Fetch-Mode", null);
    try expectHeader(step.network.request, "Sec-Fetch-Site", null);
}

test "each hop recomputes them: a cross-site hop makes the chain cross-site, and an http hop sends none" {
    const request = try InternalRequest.init(testing.allocator, "https://web-platform.test:8443/redirect");
    defer request.deinit();
    try request.setOrigin("https://web-platform.test:8443");
    request.mode = .no_cors;
    request.destination = .image;
    const job = try FetchJob.create(testing.allocator, request, false, .{});
    defer job.destroy();
    var step = try job.start();
    try expectHeader(step.network.request, "Sec-Fetch-Site", "same-origin");
    step = try job.resumeNetwork(redirectTo("https://not-web-platform.test:8443/redirect"));
    try expectHeader(step.network.request, "Sec-Fetch-Site", "cross-site");
    // Back to the request's own origin: the chain stays cross-site.
    step = try job.resumeNetwork(redirectTo("https://web-platform.test:8443/back"));
    try expectHeader(step.network.request, "Sec-Fetch-Site", "cross-site");
    try expectHeader(step.network.request, "Sec-Fetch-Dest", "image");
    // A hop that is not potentially trustworthy sends none of them.
    step = try job.resumeNetwork(redirectTo("http://web-platform.test:8000/plain"));
    try expectHeader(step.network.request, "Sec-Fetch-Site", null);
    try expectHeader(step.network.request, "Sec-Fetch-Mode", null);
}

test "a CORS preflight sends them in mode cors, with the request's destination" {
    const request = try InternalRequest.init(testing.allocator, "https://not-web-platform.test:8443/api");
    defer request.deinit();
    try request.setOrigin("https://web-platform.test:8443");
    request.mode = .cors;
    request.unsafe_request = true;
    try request.setMethod("PUT");
    const job = try FetchJob.create(testing.allocator, request, false, .{});
    defer job.destroy();
    const step = try job.start();
    const sent = step.network.request;
    try testing.expectEqualStrings("OPTIONS", sent.method);
    try expectHeader(sent, "Sec-Fetch-Mode", "cors");
    try expectHeader(sent, "Sec-Fetch-Dest", "empty");
    try expectHeader(sent, "Sec-Fetch-Site", "cross-site");
}

test "a navigation request with user activation sends Sec-Fetch-User; a subresource never does" {
    inline for (.{ .{ .iframe, true, "?1" }, .{ .iframe, false, null }, .{ .image, true, null } }) |case| {
        const request = try InternalRequest.init(testing.allocator, "https://web-platform.test:8443/x");
        defer request.deinit();
        try request.setOrigin("https://web-platform.test:8443");
        request.destination = case[0];
        request.mode = if (case[0] == .iframe) .navigate else .no_cors;
        request.user_activation = case[1];
        const job = try FetchJob.create(testing.allocator, request, false, .{});
        defer job.destroy();
        const step = try job.start();
        try expectHeader(step.network.request, "Sec-Fetch-User", case[2]);
    }
}

test "a request no client gave an origin (the embedder's own navigation) is Sec-Fetch-Site none" {
    const request = try InternalRequest.init(testing.allocator, "https://web-platform.test:8443/");
    defer request.deinit();
    const job = try FetchJob.create(testing.allocator, request, false, .{});
    defer job.destroy();
    const step = try job.start();
    try expectHeader(step.network.request, "Sec-Fetch-Site", "none");
}

/// One thread's requests: `rounds` fetches, alternately to its own origin
/// and to a same-site and a cross-site one, each answered by its own job.
/// Each thread allocates from a DebugAllocator of its own, which fails the
/// test on a leak (the shared testing allocator would make the threads take
/// turns: docs/lessons/testing-a-shared-test-allocator-makes-two-browsers-take-turns.md).
const Side = struct {
    origin: []const u8,
    same_site: []const u8,
    cross_site: []const u8,
    failed: bool = false,

    const rounds = 300;

    fn run(self: *Side) void {
        var debug: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
        defer if (debug.deinit() == .leak) {
            self.failed = true;
        };
        self.steps(debug.allocator()) catch {
            self.failed = true;
        };
    }

    fn steps(self: *Side, allocator: std.mem.Allocator) !void {
        for (0..rounds) |i| {
            const target, const want = switch (i % 3) {
                0 => .{ self.origin, "same-origin" },
                1 => .{ self.same_site, "same-site" },
                else => .{ self.cross_site, "cross-site" },
            };
            var url_buf: [128]u8 = undefined;
            const url = try std.fmt.bufPrint(&url_buf, "{s}/r?{d}", .{ target, i });
            const request = try InternalRequest.init(allocator, url);
            defer request.deinit();
            try request.setOrigin(self.origin);
            request.mode = .no_cors;
            request.destination = .image;
            const job = try FetchJob.create(allocator, request, false, .{});
            defer job.destroy();
            const step = try job.start();
            const got = header(step.network.request, "Sec-Fetch-Site") orelse return error.Missing;
            if (!std.mem.eql(u8, got, want)) return error.WrongSite;
        }
    }
};

test "two threads compute their requests' metadata headers at once, each from its own requests" {
    var sides = [_]Side{
        .{ .origin = "https://a.web-platform.test:8443", .same_site = "https://b.web-platform.test:8443", .cross_site = "https://not-web-platform.test:8443" },
        .{ .origin = "https://x.example.com", .same_site = "https://y.example.com", .cross_site = "https://example.org" },
    };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{}, Side.run, .{side});
    for (threads) |thread| thread.join();
    for (sides) |side| try testing.expect(!side.failed);
}
