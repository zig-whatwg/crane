//! URLPattern API Integration Tests
//!
//! Tests for the high-level URLPattern API including:
//! - URLPattern.test() method
//! - URLPattern.exec() method
//! - Property getters (protocol, hostname, etc.)
//! - hasRegExpGroups property
//! - Memory management (no leaks)
//!
//! Spec Reference: https://urlpattern.spec.whatwg.org/

const std = @import("std");
const testing = std.testing;
const urlpattern = @import("urlpattern");
const URLPattern = urlpattern.URLPattern;
const URLPatternInput = urlpattern.URLPatternInput;

// ============================================================================
// testMatch() Method Tests
// ============================================================================

test "testMatch - exact URL match" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .string = "https://example.com/path",
    }, .{});
    defer pattern.deinit(allocator);

    // Should match exact URL
    try testing.expect(urlpattern.testMatch(allocator, &pattern, "https://example.com/path", null));
}

test "testMatch - non-matching URL" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .string = "https://example.com/path",
    }, .{});
    defer pattern.deinit(allocator);

    // Different path should not match
    try testing.expect(!urlpattern.testMatch(allocator, &pattern, "https://example.com/other", null));
    // Different hostname should not match
    try testing.expect(!urlpattern.testMatch(allocator, &pattern, "https://other.com/path", null));
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

    // Both http and https should match
    try testing.expect(urlpattern.testMatch(allocator, &pattern, "https://example.com/path", null));
    try testing.expect(urlpattern.testMatch(allocator, &pattern, "http://example.com/path", null));
}

test "testMatch - named parameter matches segment" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/:id",
        },
    }, .{});
    defer pattern.deinit(allocator);

    // Any single segment should match
    try testing.expect(urlpattern.testMatch(allocator, &pattern, "https://example.com/123", null));
    try testing.expect(urlpattern.testMatch(allocator, &pattern, "https://example.com/abc", null));
    try testing.expect(urlpattern.testMatch(allocator, &pattern, "https://example.com/user-name", null));
}

test "testMatch - multiple named parameters" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .pathname = "/:org/:repo",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(urlpattern.testMatchInput(allocator, &pattern, .{
        .init = .{
            .pathname = "/github/whatwg",
        },
    }, null));
}

test "testMatch - wildcard pathname matches any path" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/*",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(urlpattern.testMatch(allocator, &pattern, "https://example.com/anything", null));
    try testing.expect(urlpattern.testMatch(allocator, &pattern, "https://example.com/deep/nested/path", null));
}

// ============================================================================
// testMatchInput() Method Tests with URLPatternInput
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

    // Test with init input (explicit components)
    const matches = urlpattern.testMatchInput(allocator, &pattern, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
        },
    }, null);

    try testing.expect(matches);
}

test "testMatchInput - init input with different hostname" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
        },
    }, .{});
    defer pattern.deinit(allocator);

    const matches = urlpattern.testMatchInput(allocator, &pattern, .{
        .init = .{
            .protocol = "https",
            .hostname = "other.com",
        },
    }, null);

    try testing.expect(!matches);
}

// ============================================================================
// exec() Method Tests
// ============================================================================

test "exec - returns result on match" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .string = "https://example.com/path",
    }, .{});
    defer pattern.deinit(allocator);

    var result_opt = try urlpattern.exec(allocator, &pattern, "https://example.com/path", null);
    if (result_opt) |*result| {
        defer result.deinit();

        // Check inputs
        try testing.expect(result.inputs.len == 1);
        try testing.expectEqualStrings("https://example.com/path", result.inputs[0]);

        // Check component inputs
        try testing.expectEqualStrings("https", result.protocol.input);
        try testing.expectEqualStrings("example.com", result.hostname.input);
        try testing.expectEqualStrings("/path", result.pathname.input);
    } else {
        return error.TestUnexpectedResult;
    }
}

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

    const result = try urlpattern.exec(allocator, &pattern, "https://other.com/path", null);
    try testing.expect(result == null);
}

test "exec - captures named parameter value" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/:id",
        },
    }, .{});
    defer pattern.deinit(allocator);

    var result_opt = try urlpattern.exec(allocator, &pattern, "https://example.com/123", null);
    if (result_opt) |*result| {
        defer result.deinit();

        // Check captured group
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
            .pathname = "/:org/:repo",
        },
    }, .{});
    defer pattern.deinit(allocator);

    var result_opt = try urlpattern.execInput(allocator, &pattern, .{
        .init = .{
            .pathname = "/github/zig",
        },
    }, null);
    if (result_opt) |*result| {
        defer result.deinit();

        if (result.pathname.groups.get("org")) |org| {
            try testing.expectEqualStrings("github", org);
        }
        if (result.pathname.groups.get("repo")) |repo| {
            try testing.expectEqualStrings("zig", repo);
        }
    } else {
        return error.TestUnexpectedResult;
    }
}

test "exec - with base URL" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/api/users",
        },
    }, .{});
    defer pattern.deinit(allocator);

    // Relative URL with base
    var result_opt = try urlpattern.exec(allocator, &pattern, "/api/users", "https://example.com");
    if (result_opt) |*result| {
        defer result.deinit();
        try testing.expectEqualStrings("/api/users", result.pathname.input);
    } else {
        return error.TestUnexpectedResult;
    }
}

// ============================================================================
// execInput() Method Tests with URLPatternInput
// ============================================================================

test "execInput - with init input" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .pathname = "/:section",
        },
    }, .{});
    defer pattern.deinit(allocator);

    var result_opt = try urlpattern.execInput(allocator, &pattern, .{
        .init = .{
            .pathname = "/docs",
        },
    }, null);
    if (result_opt) |*result| {
        defer result.deinit();

        if (result.pathname.groups.get("section")) |section| {
            try testing.expectEqualStrings("docs", section);
        }
    } else {
        return error.TestUnexpectedResult;
    }
}

// ============================================================================
// URLPatternComponentResult Tests
// ============================================================================

test "URLPatternComponentResult - groups access" {
    const allocator = testing.allocator;

    var result = urlpattern.URLPatternComponentResult.init(allocator);
    defer result.deinit();

    // Add a group manually for testing
    const value = try allocator.dupe(u8, "test_value");
    try result._owned_group_values.append(allocator, value);
    try result.groups.put(allocator, "name", value);

    // Should be retrievable
    try testing.expectEqualStrings("test_value", result.get("name").?);

    // Non-existent should be null
    try testing.expect(result.get("nonexistent") == null);
}

test "URLPatternComponentResult - input field" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .pathname = "/test",
        },
    }, .{});
    defer pattern.deinit(allocator);

    var result_opt = try urlpattern.execInput(allocator, &pattern, .{
        .init = .{
            .pathname = "/test",
        },
    }, null);
    if (result_opt) |*result| {
        defer result.deinit();

        // Component input should be the matched value
        try testing.expectEqualStrings("/test", result.pathname.input);
    } else {
        return error.TestUnexpectedResult;
    }
}

// ============================================================================
// Property Getters Tests (via pattern_string)
// ============================================================================

test "Component pattern_string - protocol" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expectEqualStrings("https", pattern.protocol.pattern_string);
}

test "Component pattern_string - hostname with wildcard" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .hostname = "*.example.com",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(pattern.hostname.pattern_string.len > 0);
}

test "Component pattern_string - pathname with params" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .pathname = "/api/:version",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(pattern.pathname.pattern_string.len > 0);
}

// ============================================================================
// hasRegExpGroups Property Tests
// ============================================================================

test "hasRegExpGroups - true for custom regexp in pathname" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .pathname = "/users/:id(\\d+)",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(pattern.hasRegexpGroups());
}

test "hasRegExpGroups - false for standard wildcards" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .string = "https://example.com/*",
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(!pattern.hasRegexpGroups());
}

test "hasRegExpGroups - false for named params without custom regexp" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .pathname = "/:id",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(!pattern.hasRegexpGroups());
}

// ============================================================================
// Memory Management Tests
// ============================================================================

test "exec - no memory leaks on match" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .pathname = "/:id",
        },
    }, .{});
    defer pattern.deinit(allocator);

    var result_opt = try urlpattern.execInput(allocator, &pattern, .{
        .init = .{
            .pathname = "/123",
        },
    }, null);
    if (result_opt) |*result| {
        result.deinit();
        // testing.allocator will detect leaks
    }
}

test "exec - no memory leaks on no match" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .pathname = "/specific",
        },
    }, .{});
    defer pattern.deinit(allocator);

    const result = try urlpattern.execInput(allocator, &pattern, .{
        .init = .{
            .pathname = "/different",
        },
    }, null);
    try testing.expect(result == null);
    // testing.allocator will detect leaks
}

test "testMatch - no memory leaks" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .string = "https://example.com/:id",
    }, .{});
    defer pattern.deinit(allocator);

    _ = urlpattern.testMatch(allocator, &pattern, "https://example.com/123", null);
    _ = urlpattern.testMatch(allocator, &pattern, "https://other.com/456", null);
    // testing.allocator will detect leaks
}

// ============================================================================
// Edge Cases
// ============================================================================

test "exec - empty pathname match" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .pathname = "",
        },
    }, .{});
    defer pattern.deinit(allocator);

    var result_opt = try urlpattern.execInput(allocator, &pattern, .{
        .init = .{
            .pathname = "",
        },
    }, null);
    if (result_opt) |*result| {
        defer result.deinit();
        try testing.expectEqualStrings("", result.pathname.input);
    }
}

test "exec - URL with all components" {
    const allocator = testing.allocator;

    // Use escaped colon to treat credentials as literal username:password
    var pattern = try URLPattern.create(allocator, .{
        .string = "https://user\\:pass@example.com:8080/path?query#hash",
    }, .{});
    defer pattern.deinit(allocator);

    var result_opt = try urlpattern.exec(allocator, &pattern, "https://user:pass@example.com:8080/path?query#hash", null);
    if (result_opt) |*result| {
        defer result.deinit();

        try testing.expectEqualStrings("https", result.protocol.input);
        try testing.expectEqualStrings("user", result.username.input);
        try testing.expectEqualStrings("pass", result.password.input);
        try testing.expectEqualStrings("example.com", result.hostname.input);
        try testing.expectEqualStrings("8080", result.port.input);
        try testing.expectEqualStrings("/path", result.pathname.input);
        try testing.expectEqualStrings("query", result.search.input);
        try testing.expectEqualStrings("hash", result.hash.input);
    } else {
        return error.TestUnexpectedResult;
    }
}

// ============================================================================
// Spec Example Tests
// ============================================================================

test "spec example - basic pathname matching" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .pathname = "/users/:id",
        },
    }, .{});
    defer pattern.deinit(allocator);

    // Should match /users/123
    try testing.expect(urlpattern.testMatchInput(allocator, &pattern, .{
        .init = .{
            .pathname = "/users/123",
        },
    }, null));

    // Should not match /users (missing id)
    try testing.expect(!urlpattern.testMatchInput(allocator, &pattern, .{
        .init = .{
            .pathname = "/users",
        },
    }, null));
}

test "spec example - exec captures groups" {
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .pathname = "/users/:id",
        },
    }, .{});
    defer pattern.deinit(allocator);

    var result_opt = try urlpattern.execInput(allocator, &pattern, .{
        .init = .{
            .pathname = "/users/456",
        },
    }, null);
    if (result_opt) |*result| {
        defer result.deinit();

        // Should capture the id parameter
        if (result.pathname.groups.get("id")) |id| {
            try testing.expectEqualStrings("456", id);
        }
    } else {
        return error.TestUnexpectedResult;
    }
}
