//! Upgrade Insecure Requests 4.1 step 1: a navigation request gets
//! `Upgrade-Insecure-Requests: 1` when its URL is not potentially
//! trustworthy OR its host is not a preloadable HSTS host - so an https
//! navigation gets it too. Crane knows no preloadable HSTS host, so every
//! navigation request carries the header; a subresource request never does.
const std = @import("std");
const fetch = @import("fetch");
const main = fetch.algorithms.main_fetch;

test "UIR step 1: every navigation request carries the header, https included" {
    const allocator = std.testing.allocator;
    inline for (.{
        .{ .document, "https://web-platform.test:8443/page", true },
        .{ .iframe, "https://web-platform.test:8443/frame", true },
        .{ .frame, "https://127.0.0.1/frame", true },
        .{ .object, "https://example.test/object", true },
        .{ .embed, "http://example.test/embed", true },
        .{ .document, "http://example.test/page", true },
        .{ .script, "https://example.test/script.js", false },
        .{ .empty, "http://example.test/fetch", false },
    }) |case| {
        const request = try fetch.internal.InternalRequest.init(allocator, case[1]);
        defer request.deinit();
        request.destination = case[0];
        try main.upgradeRequestToPotentiallyTrustworthyUrl(request);
        try std.testing.expectEqual(case[2], request.header_list.contains("Upgrade-Insecure-Requests"));
        // A request with no upgrade policy keeps its URL.
        try std.testing.expectEqualStrings(case[1], request.currentUrl());
        // Main fetch again (a redirect's): still one value, "1".
        try main.upgradeRequestToPotentiallyTrustworthyUrl(request);
        if (case[2]) {
            const value = (try request.header_list.get(allocator, "Upgrade-Insecure-Requests")).?;
            defer allocator.free(value);
            try std.testing.expectEqualStrings("1", value);
        }
    }
}
