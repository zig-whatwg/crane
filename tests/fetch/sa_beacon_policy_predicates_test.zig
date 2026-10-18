//! Main-fetch policy decisions and Beacon's non-mutating probe agree.
const std = @import("std");
const fetch = @import("fetch");
const testing = std.testing;

test "UIR preserves navigation headers, destination exemptions and explicit ports" {
    const cases = .{
        .{ .empty, "http://example.test:8443/beacon", true, false, "https://example.test:8443/beacon" },
        .{ .empty, "http://example.test/beacon", false, false, "http://example.test/beacon" },
        .{ .document, "http://example.test/page", true, true, "https://example.test/page" },
        .{ .iframe, "http://example.test:80/page", true, true, "https://example.test:80/page" },
        .{ .frame, "http://example.test/page", true, true, "https://example.test/page" },
        .{ .object, "https://example.test/page", true, true, "https://example.test/page" },
        .{ .empty, "wss://example.test/socket", true, false, "wss://example.test/socket" },
    };
    inline for (cases) |case| {
        const request = try fetch.internal.InternalRequest.init(testing.allocator, case[1]);
        defer request.deinit();
        request.destination = case[0];
        if (case[2]) request.setPolicyContainer(try fetch.internal.PolicyContainer.fromResponseHeaders(testing.allocator, .{
            .url = "https://example.test/start",
            .csp = "upgrade-insecure-requests",
        }));
        const should_upgrade = !std.mem.eql(u8, case[1], case[4]);
        try testing.expectEqual(should_upgrade, fetch.algorithms.main_fetch.wouldUpgradeToPotentiallyTrustworthyUrl(request));
        try testing.expectEqualStrings(case[1], request.currentUrl());
        try testing.expect(!request.header_list.contains("Upgrade-Insecure-Requests"));
        try fetch.algorithms.main_fetch.upgradeRequestToPotentiallyTrustworthyUrl(request);
        try testing.expectEqualStrings(case[4], request.currentUrl());
        try testing.expectEqual(case[3], request.header_list.contains("Upgrade-Insecure-Requests"));
        if (case[3]) {
            const value = (try request.header_list.get(testing.allocator, "Upgrade-Insecure-Requests")).?;
            defer testing.allocator.free(value);
            try testing.expectEqualStrings("1", value);
        }
        // Repeated main-fetch entries (including redirects) must not append
        // a second Upgrade-Insecure-Requests value.
        try fetch.algorithms.main_fetch.upgradeRequestToPotentiallyTrustworthyUrl(request);
        if (case[3]) {
            const value = (try request.header_list.get(testing.allocator, "Upgrade-Insecure-Requests")).?;
            defer testing.allocator.free(value);
            try testing.expectEqualStrings("1", value);
        }
    }
}

test "mixed-content blocking preserves client and navigation exemptions" {
    const cases = .{
        .{ "http://example.test/beacon", true, .empty, true },
        .{ "http://example.test/beacon", false, .empty, false },
        .{ "http://example.test/page", true, .document, false },
        .{ "http://example.test/frame", true, .iframe, true },
        .{ "https://example.test/beacon", true, .empty, false },
        .{ "http://127.0.0.1/beacon", true, .empty, false },
        .{ "data:text/plain,body", true, .empty, false },
    };
    inline for (cases) |case| {
        const request = try fetch.internal.InternalRequest.init(testing.allocator, case[0]);
        defer request.deinit();
        request.prohibits_mixed_security_contexts = case[1];
        request.destination = case[2];
        try testing.expectEqual(case[3], try fetch.mixed_content.shouldBlockRequestAt(request, request.currentUrl()));
        try testing.expect(!try fetch.mixed_content.shouldBlockRequestAt(request, "https://example.test/beacon"));
        try testing.expectEqualStrings(case[0], request.currentUrl());
        try testing.expectEqual(case[3], try fetch.mixed_content.shouldBlockRequest(request));
        try testing.expectEqualStrings(case[0], request.currentUrl());
    }
}
