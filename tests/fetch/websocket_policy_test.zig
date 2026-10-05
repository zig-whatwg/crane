//! A WebSocket handshake uses the same UIR operation as main fetch step 5.
const std = @import("std");
const fetch = @import("fetch");

test "WebSocket policy upgrades before CSP and Mixed Content checks" {
    const request = try fetch.internal.InternalRequest.init(std.testing.allocator, "http://example.test:8443/echo");
    defer request.deinit();
    request.mode = .websocket;
    request.prohibits_mixed_security_contexts = true;
    // No policy: main fetch step 5 leaves the URL alone, and step 7 blocks.
    try fetch.algorithms.main_fetch.upgradeRequestToPotentiallyTrustworthyUrl(request);
    try std.testing.expectEqualStrings("http://example.test:8443/echo", request.currentUrl());
    try std.testing.expect(try fetch.mixed_content.shouldBlockRequest(request));

    request.setPolicyContainer(try fetch.internal.PolicyContainer.fromResponseHeaders(std.testing.allocator, .{
        .url = "https://example.test/",
        .csp = "upgrade-insecure-requests; connect-src https:",
    }));
    // WebSockets 2.2 step 11 fetches; main fetch steps 5, 6, then 7.
    try fetch.algorithms.main_fetch.upgradeRequestToPotentiallyTrustworthyUrl(request);
    try fetch.mixed_content.upgradeRequest(request);
    try std.testing.expectEqualStrings("https://example.test:8443/echo", request.currentUrl());
    try std.testing.expect(!fetch.algorithms.csp_check.shouldRequestBeBlocked(request));
    try std.testing.expect(!try fetch.mixed_content.shouldBlockRequest(request));
}
