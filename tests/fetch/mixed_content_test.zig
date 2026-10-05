//! Mixed Content Level 2 sections 2, 3.1, and 4.1–4.5.
//! These tests precede the engine-free module and its request snapshot field.
const std = @import("std");
const fetch = @import("fetch");
const mixed = fetch.mixed_content;
const Request = fetch.internal.InternalRequest;

test "mixed content: URL authentication is not a scheme prefix test" {
    const cases = .{
        .{ "https://example.test/a", true },
        .{ "wss://example.test/", true },
        .{ "http://example.test/", false },
        .{ "ws://example.test/", false },
        .{ "http://127.0.0.2/", true },
        .{ "http://127.1/", true },
        .{ "http://[::1]/", true },
        .{ "http://[::ffff:127.0.0.1]/", false },
        .{ "http://localhost/", true },
        .{ "http://a.localhost./", true },
        .{ "http://localhost.example.test/", false },
        .{ "http://localhost@evil.test/", false },
        .{ "data:text/plain,hello", true },
        .{ "about:blank", true },
        .{ "about:srcdoc", true },
        .{ "about:untrusted", false },
        .{ "blob:https://example.test/id", true },
        .{ "blob:http://example.test/id", false },
        .{ "blob:null/id", false },
        .{ "null", false },
    };
    inline for (cases) |case| {
        try std.testing.expectEqual(case[1], try mixed.isAPrioriAuthenticated(std.testing.allocator, case[0]));
    }
}

test "mixed content: any authenticated ancestor prohibits mixed security contexts" {
    const allocator = std.testing.allocator;
    try std.testing.expect(try mixed.doesSettingsProhibitMixedSecurityContexts(allocator, "https://child.test", &.{"http://parent.test"}));
    try std.testing.expect(try mixed.doesSettingsProhibitMixedSecurityContexts(allocator, "null", &.{ "null", "https://parent.test" }));
    try std.testing.expect(try mixed.doesSettingsProhibitMixedSecurityContexts(allocator, "http://127.0.0.1", &.{}));
    try std.testing.expect(!try mixed.doesSettingsProhibitMixedSecurityContexts(allocator, "null", &.{}));
    try std.testing.expect(!try mixed.doesSettingsProhibitMixedSecurityContexts(allocator, "http://child.test", &.{ "null", "http://parent.test" }));
}

test "mixed content: upgradeable destinations preserve URL components and normalized ports" {
    const allocator = std.testing.allocator;
    const cases = [_][2][]const u8{
        .{ "http://example.test/a?b#c", "https://example.test/a?b#c" },
        .{ "http://example.test:80/a", "https://example.test/a" },
        .{ "http://example.test:8443/a", "https://example.test:8443/a" },
        .{ "http://user:pass@example.test:443/a", "https://user:pass@example.test:443/a" },
    };
    for ([_]fetch.internal.Destination{ .image, .audio, .video }) |destination| {
        for (cases) |case| {
            const request = try Request.init(allocator, case[0]);
            defer request.deinit();
            request.destination = destination;
            request.mode = .no_cors;
            request.prohibits_mixed_security_contexts = true;
            try mixed.upgradeRequest(request);
            try std.testing.expectEqualStrings(case[1], request.currentUrl());
            try std.testing.expect(!try mixed.shouldBlockRequest(request));
        }
    }
}

test "mixed content: CORS media is autoupgraded" {
    const allocator = std.testing.allocator;
    for ([_]fetch.internal.Destination{ .image, .audio, .video }) |destination| {
        const request = try Request.init(allocator, "http://example.test/resource");
        defer request.deinit();
        request.destination = destination;
        request.mode = .cors;
        request.prohibits_mixed_security_contexts = true;
        try mixed.upgradeRequest(request);
        // Editor's Draft 4.1 has no CORS exclusion (corrected Q12).
        try std.testing.expectEqualStrings("https://example.test/resource", request.currentUrl());
        try std.testing.expect(!try mixed.shouldBlockRequest(request));
    }
}

test "mixed content: IP-address hosts are not autoupgraded" {
    const allocator = std.testing.allocator;
    const urls = [_][]const u8{ "http://192.0.2.1/image", "http://0xc0000201/image", "http://[2001:db8::1]/image" };
    for (urls) |url| {
        const request = try Request.init(allocator, url);
        defer request.deinit();
        request.destination = .image;
        request.mode = .no_cors;
        request.prohibits_mixed_security_contexts = true;
        // Editor's Draft 4.1 step 1.2 checks the parsed host's type.
        try mixed.upgradeRequest(request);
        try std.testing.expectEqualStrings(url, request.currentUrl());
        try std.testing.expect(try mixed.shouldBlockRequest(request));
    }
}

test "mixed content: imageset requests are not autoupgraded" {
    const allocator = std.testing.allocator;
    const image = try Request.init(allocator, "http://example.test/image");
    defer image.deinit();
    image.destination = .image;
    image.mode = .no_cors;
    image.initiator = .imageset;
    image.prohibits_mixed_security_contexts = true;
    try mixed.upgradeRequest(image);
    try std.testing.expectEqualStrings("http://example.test/image", image.currentUrl());
    try std.testing.expect(try mixed.shouldBlockRequest(image));
}

test "mixed content: null clients and top-level navigations are allowed, nested navigations block" {
    const allocator = std.testing.allocator;
    const request = try Request.init(allocator, "http://example.test/resource");
    defer request.deinit();
    try std.testing.expect(!try mixed.shouldBlockRequest(request));
    request.prohibits_mixed_security_contexts = true;
    for ([_]fetch.internal.Destination{ .empty, .script, .style, .worker, .sharedworker, .iframe, .frame, .object, .embed }) |destination| {
        request.destination = destination;
        try mixed.upgradeRequest(request);
        try std.testing.expectEqualStrings("http://example.test/resource", request.currentUrl());
        try std.testing.expect(try mixed.shouldBlockRequest(request));
    }
    request.destination = .document;
    request.mode = .navigate;
    try std.testing.expect(!try mixed.shouldBlockRequest(request));
}

test "mixed content: response authentication uses the response URL" {
    const allocator = std.testing.allocator;
    const request = try Request.init(allocator, "https://example.test/request");
    defer request.deinit();
    request.prohibits_mixed_security_contexts = true;
    try std.testing.expect(try mixed.shouldBlockResponse(request, "http://example.test/response"));
    try std.testing.expect(!try mixed.shouldBlockResponse(request, "https://example.test/response"));
    try std.testing.expect(!try mixed.shouldBlockResponse(request, "data:text/plain,hello"));
    request.destination = .document;
    try std.testing.expect(!try mixed.shouldBlockResponse(request, "http://example.test/response"));
    request.destination = .empty;
    request.prohibits_mixed_security_contexts = false;
    try std.testing.expect(!try mixed.shouldBlockResponse(request, "http://example.test/response"));
}

test "mixed content: a cloned request preserves the captured client restriction" {
    const allocator = std.testing.allocator;
    const request = try Request.init(allocator, "http://example.test/resource");
    defer request.deinit();
    try fetch.internal.populateRequestFromClient(request, .{ .prohibits_mixed_security_contexts = true });
    const clone = try request.clone();
    defer clone.deinit();
    request.prohibits_mixed_security_contexts = false;
    try std.testing.expect(try mixed.shouldBlockRequest(clone));
    try std.testing.expect(!try mixed.shouldBlockRequest(request));
}
