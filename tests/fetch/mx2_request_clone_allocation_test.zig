//! Every allocation failure in request cloning releases the completed copy.
const std = @import("std");
const fetch = @import("fetch");

fn sourceRequest(allocator: std.mem.Allocator) !*fetch.internal.InternalRequest {
    const request = try fetch.internal.InternalRequest.init(allocator, "https://example.test/start");
    errdefer request.deinit();
    request.network_partition_key = try allocator.dupe(u8, "https://top.test|https://example.test");
    try request.setMethod("POST");
    try request.header_list.append("Content-Type", "text/plain");
    try request.header_list.append("X-Clone", "owned header");
    try request.setReferrerUrl("https://example.test/referrer");
    try request.setOrigin("https://example.test");
    request.setPolicyContainer(try fetch.internal.PolicyContainer.fromResponseHeaders(allocator, .{
        .url = "https://example.test/",
        .csp = "upgrade-insecure-requests; default-src 'self'",
    }));
    var parent = try fetch.internal.PolicyContainer.fromResponseHeaders(allocator, .{
        .url = "https://parent.test:8443/",
        .csp = "upgrade-insecure-requests",
    });
    defer parent.deinit();
    try request.policy_container.container.inheritUpgradeInsecureNavigations(&parent);
    try request.setCryptographicNonceMetadata("owned-nonce");
    request.integrity_metadata = try allocator.dupe(u8, "sha256-owned-integrity");
    try request.addUrl("https://example.test/redirect");
    request.body = .{ .body = try fetch.internal.Body.fromBytes(allocator, "owned body") };
    return request;
}

test "request clone: each allocation failure frees every already-owned part" {
    var index: usize = 0;
    while (index < 1024) : (index += 1) {
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
        const source = try sourceRequest(failing.allocator());
        defer source.deinit();
        // Build without injected failure: this test measures clone's unwind,
        // independently of the setters' own allocation-error behaviour.
        // Both the policy-container union and optional body union must stay
        // unpublished until their owned payloads are completely cloned.
        failing.fail_index = failing.alloc_index + index;
        const copy = source.clone() catch continue;
        defer copy.deinit();
        try std.testing.expect(!failing.has_induced_failure);
        try std.testing.expectEqualStrings(source.network_partition_key.?, copy.network_partition_key.?);
        try std.testing.expectEqualStrings(source.referrer.url, copy.referrer.url);
        try std.testing.expectEqualStrings(source.origin.origin, copy.origin.origin);
        try std.testing.expect(copy.policy_container.container.upgradesInsecureRequests());
        try std.testing.expect(copy.policy_container.container.upgradesNavigationTo("http://parent.test:8443/next"));
        try std.testing.expectEqualStrings(source.cryptographic_nonce_metadata, copy.cryptographic_nonce_metadata);
        try std.testing.expectEqualStrings(source.integrity_metadata, copy.integrity_metadata);
        try std.testing.expectEqual(@as(usize, 2), copy.url_list.items.len);
        try std.testing.expectEqualStrings("owned body", copy.body.?.body.getBytes());
        return;
    }
    return error.CloneNeverSucceeded;
}
