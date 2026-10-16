//! URLPattern matching (src/urlpattern/matcher.zig): these tests were the
//! module's own; matching runs each component's regexp in an engine, so they
//! run here, in a realm (urlpattern_realm.zig).

const std = @import("std");
const urlpattern = @import("urlpattern");
const harness = @import("urlpattern_realm.zig");
const URLPattern = urlpattern.URLPattern;
const URLPatternComponentResult = urlpattern.URLPatternComponentResult;
const testMatch = urlpattern.testMatch;
const testMatchInput = urlpattern.testMatchInput;
const exec = urlpattern.exec;
const execInput = urlpattern.execInput;

test "testMatch - simple URL" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://example.com/path",
    }, .{});
    defer pattern.deinit(allocator);

    // Should match exact URL
    try std.testing.expect(try testMatch(allocator, realm, &pattern, "https://example.com/path", null));
}

test "testMatch - non-matching URL" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://example.com/path",
    }, .{});
    defer pattern.deinit(allocator);

    // Different path should not match
    try std.testing.expect(!try testMatch(allocator, realm, &pattern, "https://example.com/other", null));
}

test "testMatch - wildcard protocol" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .protocol = "*",
            .hostname = "example.com",
            .pathname = "/path",
        },
    }, .{});
    defer pattern.deinit(allocator);

    // Both http and https should match
    try std.testing.expect(try testMatch(allocator, realm, &pattern, "https://example.com/path", null));
    try std.testing.expect(try testMatch(allocator, realm, &pattern, "http://example.com/path", null));
}

test "exec - basic result" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://example.com/path",
    }, .{});
    defer pattern.deinit(allocator);

    if (try exec(allocator, realm, &pattern, "https://example.com/path", null)) |r| {
        var result = r;
        defer result.deinit();

        // Check that input is captured
        try std.testing.expect(result.inputs.len == 1);
        try std.testing.expectEqualStrings("https://example.com/path", result.inputs[0]);

        // Check component inputs
        try std.testing.expectEqualStrings("https", result.protocol.input);
        try std.testing.expectEqualStrings("example.com", result.hostname.input);
        try std.testing.expectEqualStrings("/path", result.pathname.input);
    } else {
        return error.TestUnexpectedResult;
    }
}

test "exec - with named parameter" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/:id",
        },
    }, .{});
    defer pattern.deinit(allocator);

    if (try exec(allocator, realm, &pattern, "https://example.com/123", null)) |r| {
        var result = r;
        defer result.deinit();

        // Should capture the id parameter
        if (result.pathname.value("id")) |id| {
            try std.testing.expectEqualStrings("123", id);
        }
    } else {
        return error.TestUnexpectedResult;
    }
}

test "exec - no match returns null" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/specific",
        },
    }, .{});
    defer pattern.deinit(allocator);

    const result = try exec(allocator, realm, &pattern, "https://other.com/path", null);
    try std.testing.expect(result == null);
}

test "exec - with base URL" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/api/users",
        },
    }, .{});
    defer pattern.deinit(allocator);

    // Relative URL with base
    if (try exec(allocator, realm, &pattern, "/api/users", "https://example.com")) |r| {
        var result = r;
        defer result.deinit();
        try std.testing.expectEqualStrings("/api/users", result.pathname.input);
    } else {
        return error.TestUnexpectedResult;
    }
}

test "testMatchInput - with init input" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .protocol = "https",
            .hostname = "*.example.com",
        },
    }, .{});
    defer pattern.deinit(allocator);

    // Test with init input
    const matches = try testMatchInput(allocator, realm, &pattern, .{
        .init = .{
            .protocol = "https",
            .hostname = "api.example.com",
        },
    }, null);

    try std.testing.expect(matches);
}

// URLPatternComponentResult's groups access: urlpattern_api_test.zig.

test "testMatchInput - pathname only pattern matches pathname only input" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    // Create pattern with just pathname (like {pathname: "/foo/bar"})
    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .pathname = "/foo/bar",
        },
    }, .{});
    defer pattern.deinit(allocator);

    // Test with init input having just pathname
    const matches = try testMatchInput(allocator, realm, &pattern, .{
        .init = .{
            .pathname = "/foo/bar",
        },
    }, null);

    try std.testing.expect(matches);
}

test "exec - pathname only pattern matches pathname only input and returns result" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    // Create pattern with just pathname (like {pathname: "/foo/bar"})
    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .pathname = "/foo/bar",
        },
    }, .{});
    defer pattern.deinit(allocator);

    // Call exec with init input having just pathname
    if (try execInput(allocator, realm, &pattern, .{
        .init = .{
            .pathname = "/foo/bar",
        },
    }, null)) |r| {
        var result = r;
        defer result.deinit();

        // Verify the result
        try std.testing.expectEqualStrings("/foo/bar", result.pathname.input);
    } else {
        return error.TestUnexpectedResult;
    }
}
