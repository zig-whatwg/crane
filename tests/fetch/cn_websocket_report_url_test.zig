//! WebSocket matching uses HTTP(S); violations retain the constructor's WS(S) URL.
const std = @import("std");
const fetch = @import("fetch");
const check = fetch.algorithms.csp_check;
const a = std.testing.allocator;

const Capture = struct {
    count: usize = 0,
    url: []const u8 = "",
    report_only: bool = false,

    fn report(context: *anyopaque, violation: *const fetch.internal.CspViolation) void {
        const self: *Capture = @ptrCast(@alignCast(context));
        self.count += 1;
        self.url = violation.resource.url;
        self.report_only = violation.policy.disposition == .report;
    }
};

test "request reporters default to the request URL and accept an explicit WebSocket report URL" {
    if (comptime !@hasDecl(check, "shouldRequestBeBlockedWithOptions")) return error.TestUnexpectedResult;
    const request = try fetch.internal.InternalRequest.init(a, "https://socket.test/echo");
    defer request.deinit();
    request.mode = .websocket;
    request.setPolicyContainer(try fetch.internal.PolicyContainer.fromResponseHeaders(a, .{
        .url = "https://page.test/",
        .csp = "connect-src 'none'",
    }));
    var capture = Capture{};
    request.csp_violation_reporter = .{ .context = &capture, .report = &Capture.report };
    try std.testing.expect(check.shouldRequestBeBlocked(request));
    try std.testing.expectEqualStrings("https://socket.test/echo", capture.url);
    try std.testing.expect(check.shouldRequestBeBlockedWithOptions(request, .{ .report_url = "wss://socket.test/echo" }));
    try std.testing.expectEqualStrings("wss://socket.test/echo", capture.url);
    try std.testing.expectEqual(@as(usize, 2), capture.count);
    try std.testing.expect(!capture.report_only);
    try std.testing.expectEqualStrings("https://socket.test/echo", request.currentUrl());
    request.setPolicyContainer(try fetch.internal.PolicyContainer.fromResponseHeaders(a, .{
        .url = "https://page.test/",
        .csp = "connect-src https://socket.test",
    }));
    // Matching must still allow the HTTP request, even when the reporting
    // spelling would not match this policy's host or scheme.
    try std.testing.expect(!check.shouldRequestBeBlockedWithOptions(request, .{ .report_url = "ws://different.test/echo" }));
    try std.testing.expectEqual(@as(usize, 2), capture.count);
}

test "report-only request reporters use the explicit WebSocket URL without blocking" {
    if (comptime !@hasDecl(check, "reportViolationsForRequestWithOptions")) return error.TestUnexpectedResult;
    const request = try fetch.internal.InternalRequest.init(a, "http://socket.test/echo");
    defer request.deinit();
    request.mode = .websocket;
    request.setPolicyContainer(try fetch.internal.PolicyContainer.fromResponseHeaders(a, .{
        .url = "http://page.test/",
        .csp_report_only = "connect-src 'none'",
    }));
    var capture = Capture{};
    request.csp_violation_reporter = .{ .context = &capture, .report = &Capture.report };
    check.reportViolationsForRequest(request);
    try std.testing.expectEqualStrings("http://socket.test/echo", capture.url);
    check.reportViolationsForRequestWithOptions(request, .{ .report_url = "ws://socket.test/echo" });
    try std.testing.expectEqualStrings("ws://socket.test/echo", capture.url);
    try std.testing.expectEqual(@as(usize, 2), capture.count);
    try std.testing.expect(capture.report_only);
    try std.testing.expect(!check.shouldRequestBeBlocked(request));
}
