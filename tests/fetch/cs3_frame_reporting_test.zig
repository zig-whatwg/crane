const std = @import("std");
const fetch = @import("fetch");
const testing = std.testing;
const check = fetch.algorithms.csp_check;

const Reports = struct {
    count: usize = 0,
    url: []const u8 = "",

    fn reporter(self: *Reports) fetch.internal.CspViolationReporter {
        return .{ .context = self, .report = record };
    }

    fn record(context: *anyopaque, violation: *const fetch.internal.CspViolation) void {
        const self: *Reports = @ptrCast(@alignCast(context));
        self.count += 1;
        self.url = violation.resource.url;
    }
};

test "frame redirects report the blocked target for enforced and monitored policies" {
    const original = "https://source.test/redirect";
    const target = "https://target.test/blocked";
    const destinations = [_]fetch.internal.Destination{ .iframe, .frame };
    for (destinations) |destination| {
        const request = try fetch.internal.InternalRequest.init(testing.allocator, original);
        defer request.deinit();
        request.destination = destination;
        request.mode = .navigate;
        request.setPolicyContainer(try fetch.internal.PolicyContainer.fromResponseHeaders(testing.allocator, .{
            .url = "https://source.test/",
            .csp = "frame-src 'self'",
            .csp_report_only = "frame-src 'none'",
        }));
        try request.addUrl(target);
        request.redirect_count = 1;
        var reports: Reports = .{};
        request.csp_violation_reporter = reports.reporter();

        check.reportViolationsForRequest(request);
        try testing.expectEqual(@as(usize, 1), reports.count);
        try testing.expectEqualStrings(target, reports.url);
        try testing.expect(check.shouldRequestBeBlocked(request));
        try testing.expectEqual(@as(usize, 2), reports.count);
        try testing.expectEqualStrings(target, reports.url);
    }
}

test "subresource redirects keep the original reporting URL and explicit overrides" {
    const original = "https://source.test/redirect";
    const target = "https://target.test/blocked";
    const destinations = [_]fetch.internal.Destination{ .image, .script, .worker, .empty };
    for (destinations) |destination| {
        const request = try fetch.internal.InternalRequest.init(testing.allocator, original);
        defer request.deinit();
        request.destination = destination;
        request.setPolicyContainer(try fetch.internal.PolicyContainer.fromResponseHeaders(testing.allocator, .{
            .url = "https://source.test/",
            .csp = "default-src 'none'",
            .csp_report_only = "default-src 'none'",
        }));
        try request.addUrl(target);
        request.redirect_count = 1;
        var reports: Reports = .{};
        request.csp_violation_reporter = reports.reporter();

        check.reportViolationsForRequest(request);
        try testing.expectEqualStrings(original, reports.url);
        try testing.expect(check.shouldRequestBeBlocked(request));
        try testing.expectEqualStrings(original, reports.url);
        try testing.expect(check.shouldRequestBeBlockedWithOptions(request, .{ .report_url = "wss://source.test/" }));
        try testing.expectEqualStrings("wss://source.test/", reports.url);
    }
}

// CSP 4.1.1/4.1.2 and Fetch main fetch steps 4/7. The local-navigation
// patch runs these same checks before its direct data:/file: loader; this
// pins their policy/reporting semantics independently of that host seam.
test "a data frame reports a monitored policy and still returns its body" {
    const url = "data:text/html,frame-body";
    const request = try fetch.internal.InternalRequest.init(testing.allocator, url);
    defer request.deinit();
    request.destination = .iframe;
    request.mode = .navigate;
    request.setPolicyContainer(try fetch.internal.PolicyContainer.fromResponseHeaders(testing.allocator, .{
        .url = "https://source.test/",
        .csp_report_only = "frame-src 'none'",
    }));
    var reports: Reports = .{};
    request.csp_violation_reporter = reports.reporter();
    var result = try fetch.algorithms.fetch(testing.allocator, request, .{});
    defer result.deinit();
    try testing.expectEqual(@as(usize, 1), reports.count);
    try testing.expectEqualStrings(url, reports.url);
    try testing.expectEqual(@as(u16, 200), result.response.status);
    try testing.expectEqualStrings("frame-body", result.response.body.?.getBytes());
}

test "a data frame reports an enforced policy and returns a network error" {
    const url = "data:text/html,frame-body";
    const request = try fetch.internal.InternalRequest.init(testing.allocator, url);
    defer request.deinit();
    request.destination = .iframe;
    request.mode = .navigate;
    request.setPolicyContainer(try fetch.internal.PolicyContainer.fromResponseHeaders(testing.allocator, .{
        .url = "https://source.test/",
        .csp = "frame-src 'none'",
    }));
    var reports: Reports = .{};
    request.csp_violation_reporter = reports.reporter();
    var result = try fetch.algorithms.fetch(testing.allocator, request, .{});
    defer result.deinit();
    try testing.expectEqual(@as(usize, 1), reports.count);
    try testing.expectEqualStrings(url, reports.url);
    try testing.expectEqual(fetch.internal.ResponseType.@"error", result.response.response_type);
    try testing.expect(result.response.body == null);
}
