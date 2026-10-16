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
const harness = @import("urlpattern_realm.zig");
const URLPattern = urlpattern.URLPattern;
const URLPatternInput = urlpattern.URLPatternInput;

// ============================================================================
// testMatch() Method Tests
// ============================================================================

test "testMatch - exact URL match" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://example.com/path",
    }, .{});
    defer pattern.deinit(allocator);

    // Should match exact URL
    try testing.expect(try urlpattern.testMatch(allocator, realm, &pattern, "https://example.com/path", null));
}

test "testMatch - non-matching URL" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://example.com/path",
    }, .{});
    defer pattern.deinit(allocator);

    // Different path should not match
    try testing.expect(!try urlpattern.testMatch(allocator, realm, &pattern, "https://example.com/other", null));
    // Different hostname should not match
    try testing.expect(!try urlpattern.testMatch(allocator, realm, &pattern, "https://other.com/path", null));
}

test "testMatch - wildcard protocol matches any protocol" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .protocol = "*",
            .hostname = "example.com",
            .pathname = "/path",
        },
    }, .{});
    defer pattern.deinit(allocator);

    // Both http and https should match
    try testing.expect(try urlpattern.testMatch(allocator, realm, &pattern, "https://example.com/path", null));
    try testing.expect(try urlpattern.testMatch(allocator, realm, &pattern, "http://example.com/path", null));
}

test "testMatch - named parameter matches segment" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/:id",
        },
    }, .{});
    defer pattern.deinit(allocator);

    // Any single segment should match
    try testing.expect(try urlpattern.testMatch(allocator, realm, &pattern, "https://example.com/123", null));
    try testing.expect(try urlpattern.testMatch(allocator, realm, &pattern, "https://example.com/abc", null));
    try testing.expect(try urlpattern.testMatch(allocator, realm, &pattern, "https://example.com/user-name", null));
}

test "testMatch - multiple named parameters" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .pathname = "/:org/:repo",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(try urlpattern.testMatchInput(allocator, realm, &pattern, .{
        .init = .{
            .pathname = "/github/whatwg",
        },
    }, null));
}

test "testMatch - wildcard pathname matches any path" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/*",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(try urlpattern.testMatch(allocator, realm, &pattern, "https://example.com/anything", null));
    try testing.expect(try urlpattern.testMatch(allocator, realm, &pattern, "https://example.com/deep/nested/path", null));
}

// ============================================================================
// testMatchInput() Method Tests with URLPatternInput
// ============================================================================

test "testMatchInput - with init input" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
        },
    }, .{});
    defer pattern.deinit(allocator);

    // Test with init input (explicit components)
    const matches = try urlpattern.testMatchInput(allocator, realm, &pattern, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
        },
    }, null);

    try testing.expect(matches);
}

test "testMatchInput - init input with different hostname" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
        },
    }, .{});
    defer pattern.deinit(allocator);

    const matches = try urlpattern.testMatchInput(allocator, realm, &pattern, .{
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
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://example.com/path",
    }, .{});
    defer pattern.deinit(allocator);

    var result_opt = try urlpattern.exec(allocator, realm, &pattern, "https://example.com/path", null);
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
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/specific",
        },
    }, .{});
    defer pattern.deinit(allocator);

    const result = try urlpattern.exec(allocator, realm, &pattern, "https://other.com/path", null);
    try testing.expect(result == null);
}

test "exec - captures named parameter value" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/:id",
        },
    }, .{});
    defer pattern.deinit(allocator);

    var result_opt = try urlpattern.exec(allocator, realm, &pattern, "https://example.com/123", null);
    if (result_opt) |*result| {
        defer result.deinit();

        // Check captured group
        if (result.pathname.value("id")) |id| {
            try testing.expectEqualStrings("123", id);
        }
    } else {
        return error.TestUnexpectedResult;
    }
}

test "exec - captures multiple named parameters" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .pathname = "/:org/:repo",
        },
    }, .{});
    defer pattern.deinit(allocator);

    var result_opt = try urlpattern.execInput(allocator, realm, &pattern, .{
        .init = .{
            .pathname = "/github/zig",
        },
    }, null);
    if (result_opt) |*result| {
        defer result.deinit();

        if (result.pathname.value("org")) |org| {
            try testing.expectEqualStrings("github", org);
        }
        if (result.pathname.value("repo")) |repo| {
            try testing.expectEqualStrings("zig", repo);
        }
    } else {
        return error.TestUnexpectedResult;
    }
}

test "exec - with base URL" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/api/users",
        },
    }, .{});
    defer pattern.deinit(allocator);

    // Relative URL with base
    var result_opt = try urlpattern.exec(allocator, realm, &pattern, "/api/users", "https://example.com");
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
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .pathname = "/:section",
        },
    }, .{});
    defer pattern.deinit(allocator);

    var result_opt = try urlpattern.execInput(allocator, realm, &pattern, .{
        .init = .{
            .pathname = "/docs",
        },
    }, null);
    if (result_opt) |*result| {
        defer result.deinit();

        if (result.pathname.value("section")) |section| {
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
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{ .init = .{ .pathname = "/:name/:rest?" } }, .{});
    defer pattern.deinit(allocator);
    var result = (try urlpattern.exec(allocator, realm, &pattern, "https://example.com/test_value", null)) orelse return error.TestUnexpectedResult;
    defer result.deinit();

    // Should be retrievable, in the group name list's order
    try testing.expectEqualStrings("test_value", result.pathname.value("name").?);
    try testing.expectEqual(@as(usize, 2), result.pathname.groups.len);
    try testing.expectEqualStrings("name", result.pathname.groups[0].name);
    try testing.expectEqualStrings("rest", result.pathname.groups[1].name);
    // An optional group that did not participate is there, undefined
    try testing.expect(result.pathname.get("rest") != null);
    try testing.expect(result.pathname.get("rest").?.value == null);

    // Non-existent should be null
    try testing.expect(result.pathname.get("nonexistent") == null);
}

test "URLPatternComponentResult - input field" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .pathname = "/test",
        },
    }, .{});
    defer pattern.deinit(allocator);

    var result_opt = try urlpattern.execInput(allocator, realm, &pattern, .{
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
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .protocol = "https",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expectEqualStrings("https", pattern.protocol.pattern_string);
}

test "Component pattern_string - hostname with wildcard" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .hostname = "*.example.com",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(pattern.hostname.pattern_string.len > 0);
}

test "Component pattern_string - pathname with params" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
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
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .pathname = "/users/:id(\\d+)",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(pattern.hasRegexpGroups());
}

test "hasRegExpGroups - false for standard wildcards" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://example.com/*",
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(!pattern.hasRegexpGroups());
}

test "hasRegExpGroups - false for named params without custom regexp" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
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
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .pathname = "/:id",
        },
    }, .{});
    defer pattern.deinit(allocator);

    var result_opt = try urlpattern.execInput(allocator, realm, &pattern, .{
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
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .pathname = "/specific",
        },
    }, .{});
    defer pattern.deinit(allocator);

    const result = try urlpattern.execInput(allocator, realm, &pattern, .{
        .init = .{
            .pathname = "/different",
        },
    }, null);
    try testing.expect(result == null);
    // testing.allocator will detect leaks
}

test "testMatch - no memory leaks" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://example.com/:id",
    }, .{});
    defer pattern.deinit(allocator);

    _ = try urlpattern.testMatch(allocator, realm, &pattern, "https://example.com/123", null);
    _ = try urlpattern.testMatch(allocator, realm, &pattern, "https://other.com/456", null);
    // testing.allocator will detect leaks
}

// ============================================================================
// Edge Cases
// ============================================================================

test "exec - empty pathname match" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .pathname = "",
        },
    }, .{});
    defer pattern.deinit(allocator);

    var result_opt = try urlpattern.execInput(allocator, realm, &pattern, .{
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
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    // Use escaped colon to treat credentials as literal username:password
    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://user\\:pass@example.com:8080/path?query#hash",
    }, .{});
    defer pattern.deinit(allocator);

    var result_opt = try urlpattern.exec(allocator, realm, &pattern, "https://user:pass@example.com:8080/path?query#hash", null);
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
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .pathname = "/users/:id",
        },
    }, .{});
    defer pattern.deinit(allocator);

    // Should match /users/123
    try testing.expect(try urlpattern.testMatchInput(allocator, realm, &pattern, .{
        .init = .{
            .pathname = "/users/123",
        },
    }, null));

    // Should not match /users (missing id)
    try testing.expect(!try urlpattern.testMatchInput(allocator, realm, &pattern, .{
        .init = .{
            .pathname = "/users",
        },
    }, null));
}

test "spec example - exec captures groups" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .pathname = "/users/:id",
        },
    }, .{});
    defer pattern.deinit(allocator);

    var result_opt = try urlpattern.execInput(allocator, realm, &pattern, .{
        .init = .{
            .pathname = "/users/456",
        },
    }, null);
    if (result_opt) |*result| {
        defer result.deinit();

        // Should capture the id parameter
        if (result.pathname.value("id")) |id| {
            try testing.expectEqualStrings("456", id);
        }
    } else {
        return error.TestUnexpectedResult;
    }
}
