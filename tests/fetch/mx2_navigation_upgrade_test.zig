//! Upgrade Insecure Requests 4.1 step 2: top-level navigations use the
//! client's opt-in set. The port edge follows Gecko/WebKit and the spec.
const std = @import("std");
const fetch = @import("fetch");
const main = fetch.algorithms.main_fetch;

test "UIR navigation: an enforced policy upgrades its own host and port only" {
    const allocator = std.testing.allocator;
    inline for (.{
        .{ "http://example.test:8443/next", true },
        .{ "http://other.test:8443/next", false },
        .{ "http://example.test:8000/next", false },
    }) |case| {
        const request = try fetch.internal.InternalRequest.init(allocator, case[0]);
        defer request.deinit();
        request.destination = .document;
        request.mode = .navigate;
        request.setPolicyContainer(try fetch.internal.PolicyContainer.fromResponseHeaders(allocator, .{
            .url = "https://example.test:8443/start",
            .csp = "upgrade-insecure-requests",
        }));
        try std.testing.expectEqual(case[1], main.wouldUpgradeToPotentiallyTrustworthyUrl(request));
        // The predicate used by Beacon must not mutate the request.
        try std.testing.expectEqualStrings(case[0], request.currentUrl());
        try std.testing.expect(!request.header_list.contains("Upgrade-Insecure-Requests"));
    }
}

test "UIR navigation: report-only policy never opts a host in" {
    const allocator = std.testing.allocator;
    const request = try fetch.internal.InternalRequest.init(allocator, "http://example.test/next");
    defer request.deinit();
    request.destination = .document;
    request.mode = .navigate;
    request.setPolicyContainer(try fetch.internal.PolicyContainer.fromResponseHeaders(allocator, .{
        .url = "https://example.test/start",
        .csp_report_only = "upgrade-insecure-requests",
    }));
    try std.testing.expect(!main.wouldUpgradeToPotentiallyTrustworthyUrl(request));
}

test "UIR navigation: nested frames need no navigation host match" {
    const allocator = std.testing.allocator;
    const request = try fetch.internal.InternalRequest.init(allocator, "http://other.test:8000/frame");
    defer request.deinit();
    request.mode = .navigate;
    request.setPolicyContainer(try fetch.internal.PolicyContainer.fromResponseHeaders(allocator, .{
        .url = "https://example.test:8443/start",
        .csp = "upgrade-insecure-requests",
    }));
    for ([_]fetch.internal.Destination{ .iframe, .frame, .object, .embed }) |destination| {
        request.destination = destination;
        try std.testing.expect(main.wouldUpgradeToPotentiallyTrustworthyUrl(request));
    }
}
