const std = @import("std");
const reporting = @import("dom").reporting;

test "CSP legacy request owns its bytes and preserves report fetch semantics" {
    const allocator = std.testing.allocator;
    var bytes = [_]u8{ '{', '}', '\n' };
    const request = try reporting.legacyRequest(allocator, "https://example.test/report", &bytes, .{
        .origin = "https://example.test",
        .referrer_source = "https://example.test/page",
    });
    defer request.deinit();
    bytes[0] = '[';
    try std.testing.expectEqualStrings("{}\n", request.body.?.body.getBytes());
    try std.testing.expectEqualStrings("{}\n", request.body.?.body.source.bytes);
    try std.testing.expectEqualStrings("POST", request.method);
    try std.testing.expectEqualStrings("https://example.test/report", request.getUrl());
    try std.testing.expectEqualStrings("application/csp-report", request.header_list.getFirstValue("Content-Type").?);
    try std.testing.expectEqualStrings("https://example.test", request.origin.origin);
    try std.testing.expect(request.destination == .report);
    try std.testing.expect(request.mode == .no_cors);
    try std.testing.expect(request.credentials_mode == .same_origin);
    try std.testing.expect(request.redirect_mode == .@"error");
    try std.testing.expect(request.traversable_for_user_prompts == .no_traversable);
    try std.testing.expect(request.keepalive);
    try std.testing.expect(request.initiator_type == null);
}

test "Reporting request is client-null CORS with report-origin credentials and an owned body" {
    const allocator = std.testing.allocator;
    var bytes = [_]u8{ '[', ']', '\n' };
    const request = try reporting.modernRequest(allocator, "https://endpoint.test/report", "https://page.test", &bytes);
    defer request.deinit();
    bytes[0] = '{';
    try std.testing.expectEqualStrings("[]\n", request.body.?.body.getBytes());
    try std.testing.expectEqualStrings("[]\n", request.body.?.body.source.bytes);
    try std.testing.expectEqualStrings("POST", request.method);
    try std.testing.expectEqualStrings("application/reports+json", request.header_list.getFirstValue("Content-Type").?);
    try std.testing.expectEqualStrings("https://page.test", request.origin.origin);
    try std.testing.expect(request.client == null);
    try std.testing.expect(request.policy_container == .client);
    try std.testing.expect(request.destination == .report);
    try std.testing.expect(request.mode == .cors);
    try std.testing.expect(request.credentials_mode == .same_origin);
    try std.testing.expect(request.service_workers_mode == .none);
    try std.testing.expect(request.unsafe_request);
    try std.testing.expect(request.traversable_for_user_prompts == .no_traversable);
    try std.testing.expect(request.initiator_type == null);
}
