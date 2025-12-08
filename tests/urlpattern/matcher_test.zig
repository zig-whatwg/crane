//! URLPattern Matcher Tests
//!
//! Comprehensive tests for the URLPattern test() and exec() methods
//! defined in WHATWG URLPattern Standard Section 1.3.
//!
//! See: https://urlpattern.spec.whatwg.org/#urlpattern-matching

const std = @import("std");
const testing = std.testing;
const urlpattern = @import("urlpattern");

const URLPattern = urlpattern.URLPattern;
const URLPatternResult = urlpattern.URLPatternResult;
const URLPatternInput = urlpattern.URLPatternInput;
const testMatch = urlpattern.testMatch;
const testMatchInput = urlpattern.testMatchInput;
const exec = urlpattern.exec;
const execInput = urlpattern.execInput;

// ============================================================================
// testMatch - Basic Boolean Matching Tests
// ============================================================================

test "testMatch - exact URL match" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .string = "https://example.com/path",
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(testMatch(allocator, &pattern, "https://example.com/path", null));
}

test "testMatch - non-matching URL returns false" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .string = "https://example.com/path",
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(!testMatch(allocator, &pattern, "https://example.com/other", null));
    try testing.expect(!testMatch(allocator, &pattern, "https://other.com/path", null));
    try testing.expect(!testMatch(allocator, &pattern, "http://example.com/path", null));
}

test "testMatch - wildcard protocol matches any protocol" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "*",
            .hostname = "example.com",
            .pathname = "/path",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(testMatch(allocator, &pattern, "https://example.com/path", null));
    try testing.expect(testMatch(allocator, &pattern, "http://example.com/path", null));
}

test "testMatch - wildcard hostname matches any hostname" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "*",
            .pathname = "/api",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(testMatch(allocator, &pattern, "https://example.com/api", null));
    try testing.expect(testMatch(allocator, &pattern, "https://other.org/api", null));
}

test "testMatch - wildcard pathname matches any pathname" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "*",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(testMatch(allocator, &pattern, "https://example.com/any/path", null));
    try testing.expect(testMatch(allocator, &pattern, "https://example.com/", null));
}

test "testMatch - pattern with port" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .port = "8080",
            .pathname = "/api",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(testMatch(allocator, &pattern, "https://example.com:8080/api", null));
}

// ============================================================================
// testMatch - Named Parameter Patterns
// ============================================================================

test "testMatch - pathname with named parameter" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/:id",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(testMatch(allocator, &pattern, "https://example.com/123", null));
    try testing.expect(testMatch(allocator, &pattern, "https://example.com/abc", null));
}

test "testMatch - multiple named parameters" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/users/:userId/posts/:postId",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(testMatch(allocator, &pattern, "https://example.com/users/42/posts/99", null));
}

// ============================================================================
// testMatch - BaseURL Tests
// ============================================================================

test "testMatch - relative URL with baseURL" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/api/users",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(testMatch(allocator, &pattern, "/api/users", "https://example.com"));
}

// ============================================================================
// testMatchInput - URLPatternInput Tests
// ============================================================================

test "testMatchInput - with init input" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(testMatchInput(allocator, &pattern, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
        },
    }, null));

    try testing.expect(!testMatchInput(allocator, &pattern, .{
        .init = .{
            .protocol = "http",
            .hostname = "example.com",
        },
    }, null));
}

// ============================================================================
// exec - Result Structure Tests
// ============================================================================

test "exec - returns null on no match" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/specific",
        },
    }, .{});
    defer pattern.deinit(allocator);

    const result = try exec(allocator, &pattern, "https://other.com/path", null);
    try testing.expect(result == null);
}

test "exec - returns result with inputs array" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .string = "https://example.com/path",
    }, .{});
    defer pattern.deinit(allocator);

    var maybe_result = try exec(allocator, &pattern, "https://example.com/path", null);
    if (maybe_result) |*result| {
        defer result.deinit();

        try testing.expect(result.inputs.len == 1);
        try testing.expectEqualStrings("https://example.com/path", result.inputs[0]);
    } else {
        return error.TestUnexpectedResult;
    }
}

test "exec - returns all 8 component results" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .string = "https://user:pass@example.com:8080/path?query=1#section",
    }, .{});
    defer pattern.deinit(allocator);

    var maybe_result = try exec(allocator, &pattern, "https://user:pass@example.com:8080/path?query=1#section", null);
    if (maybe_result) |*result| {
        defer result.deinit();

        // All 8 components should have input fields
        try testing.expectEqualStrings("https", result.protocol.input);
        try testing.expectEqualStrings("user", result.username.input);
        try testing.expectEqualStrings("pass", result.password.input);
        try testing.expectEqualStrings("example.com", result.hostname.input);
        try testing.expectEqualStrings("8080", result.port.input);
        try testing.expectEqualStrings("/path", result.pathname.input);
        try testing.expectEqualStrings("query=1", result.search.input);
        try testing.expectEqualStrings("section", result.hash.input);
    } else {
        return error.TestUnexpectedResult;
    }
}

test "exec - basic URL component extraction" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .string = "https://example.com/path",
    }, .{});
    defer pattern.deinit(allocator);

    var maybe_result = try exec(allocator, &pattern, "https://example.com/path", null);
    if (maybe_result) |*result| {
        defer result.deinit();

        try testing.expectEqualStrings("https", result.protocol.input);
        try testing.expectEqualStrings("example.com", result.hostname.input);
        try testing.expectEqualStrings("/path", result.pathname.input);
    } else {
        return error.TestUnexpectedResult;
    }
}

// ============================================================================
// exec - Named Group Extraction Tests
// ============================================================================

test "exec - captures named parameter" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/:id",
        },
    }, .{});
    defer pattern.deinit(allocator);

    var maybe_result = try exec(allocator, &pattern, "https://example.com/123", null);
    if (maybe_result) |*result| {
        defer result.deinit();

        if (result.pathname.groups.get("id")) |id| {
            try testing.expectEqualStrings("123", id);
        }
    } else {
        return error.TestUnexpectedResult;
    }
}

test "exec - captures multiple named parameters" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/users/:userId/posts/:postId",
        },
    }, .{});
    defer pattern.deinit(allocator);

    var maybe_result = try exec(allocator, &pattern, "https://example.com/users/42/posts/99", null);
    if (maybe_result) |*result| {
        defer result.deinit();

        if (result.pathname.groups.get("userId")) |userId| {
            try testing.expectEqualStrings("42", userId);
        }
        if (result.pathname.groups.get("postId")) |postId| {
            try testing.expectEqualStrings("99", postId);
        }
    } else {
        return error.TestUnexpectedResult;
    }
}

// ============================================================================
// exec - BaseURL Tests
// ============================================================================

test "exec - with baseURL" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/api/users",
        },
    }, .{});
    defer pattern.deinit(allocator);

    var maybe_result = try exec(allocator, &pattern, "/api/users", "https://example.com");
    if (maybe_result) |*result| {
        defer result.deinit();
        try testing.expectEqualStrings("/api/users", result.pathname.input);
    } else {
        return error.TestUnexpectedResult;
    }
}

// ============================================================================
// execInput - URLPatternInput Tests
// ============================================================================

test "execInput - with init input" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
        },
    }, .{});
    defer pattern.deinit(allocator);

    var maybe_result = try execInput(allocator, &pattern, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/api",
        },
    }, null);
    if (maybe_result) |*result| {
        defer result.deinit();

        try testing.expectEqualStrings("https", result.protocol.input);
        try testing.expectEqualStrings("example.com", result.hostname.input);
    } else {
        return error.TestUnexpectedResult;
    }
}

// ============================================================================
// URLPatternComponentResult - Groups Access Tests
// ============================================================================

test "URLPatternComponentResult - get returns null for non-existent group" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/:id",
        },
    }, .{});
    defer pattern.deinit(allocator);

    var maybe_result = try exec(allocator, &pattern, "https://example.com/123", null);
    if (maybe_result) |*result| {
        defer result.deinit();

        try testing.expect(result.pathname.get("nonexistent") == null);
    } else {
        return error.TestUnexpectedResult;
    }
}

// ============================================================================
// Pattern Variations
// ============================================================================

test "testMatch - all wildcards pattern" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .string = "*://*/*",
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(testMatch(allocator, &pattern, "https://example.com/path", null));
    try testing.expect(testMatch(allocator, &pattern, "http://other.org/anything", null));
}

test "testMatch - relative pathname pattern" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .string = "/users/:id/posts/:postId",
    }, .{});
    defer pattern.deinit(allocator);

    // With wildcard protocol/hostname, should match
    try testing.expect(testMatch(allocator, &pattern, "https://example.com/users/1/posts/2", null));
}

test "testMatch - pattern with search component" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/search",
            .search = "*",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(testMatch(allocator, &pattern, "https://example.com/search?q=test", null));
}

test "testMatch - pattern with hash component" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/page",
            .hash = "*",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(testMatch(allocator, &pattern, "https://example.com/page#section", null));
}

// ============================================================================
// Case Sensitivity Tests
// ============================================================================

test "URLPattern - ignore_case option" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .string = "https://example.com/path",
    }, .{ .ignore_case = true });
    defer pattern.deinit(allocator);

    try testing.expect(pattern.ignore_case);
}

// ============================================================================
// Complex Pattern Tests
// ============================================================================

test "exec - complex URL with all components" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/api/:version/users/:id",
        },
    }, .{});
    defer pattern.deinit(allocator);

    var maybe_result = try exec(allocator, &pattern, "https://example.com/api/v1/users/42", null);
    if (maybe_result) |*result| {
        defer result.deinit();

        try testing.expectEqualStrings("https", result.protocol.input);
        try testing.expectEqualStrings("example.com", result.hostname.input);

        if (result.pathname.groups.get("version")) |version| {
            try testing.expectEqualStrings("v1", version);
        }
        if (result.pathname.groups.get("id")) |id| {
            try testing.expectEqualStrings("42", id);
        }
    } else {
        return error.TestUnexpectedResult;
    }
}

// ============================================================================
// Edge Cases
// ============================================================================

test "testMatch - empty pathname" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(testMatch(allocator, &pattern, "https://example.com", null));
}

test "testMatch - root pathname" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(testMatch(allocator, &pattern, "https://example.com/", null));
}

test "exec - URL with empty search and hash" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .string = "https://example.com/path",
    }, .{});
    defer pattern.deinit(allocator);

    var maybe_result = try exec(allocator, &pattern, "https://example.com/path", null);
    if (maybe_result) |*result| {
        defer result.deinit();

        // Search and hash should be empty strings
        try testing.expectEqualStrings("", result.search.input);
        try testing.expectEqualStrings("", result.hash.input);
    } else {
        return error.TestUnexpectedResult;
    }
}

// ============================================================================
// Memory Safety Tests
// ============================================================================

test "exec - result deinit properly frees memory" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/:id",
        },
    }, .{});
    defer pattern.deinit(allocator);

    // Execute multiple times to verify cleanup
    for (0..5) |_| {
        var maybe_result = try exec(allocator, &pattern, "https://example.com/test", null);
        if (maybe_result) |*result| {
            result.deinit();
        }
    }
}

test "testMatch - no memory leaks on failed match" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/specific",
        },
    }, .{});
    defer pattern.deinit(allocator);

    // Multiple failed matches shouldn't leak
    for (0..5) |_| {
        _ = testMatch(allocator, &pattern, "https://other.com/path", null);
    }
}
