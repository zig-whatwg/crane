//! URLPattern Constructor Integration Tests
//!
//! Tests for URLPattern.create() with various inputs as defined in the
//! WHATWG URLPattern Standard: https://urlpattern.spec.whatwg.org/
//!
//! These tests verify:
//! - String input parsing ("https://example.com/:path")
//! - URLPatternInit dictionary with individual components
//! - Base URL application
//! - All 8 components properly compiled
//! - Error cases (invalid patterns)

const std = @import("std");
const testing = std.testing;
const urlpattern = @import("urlpattern");
const harness = @import("urlpattern_realm.zig");
const URLPattern = urlpattern.URLPattern;
const URLPatternInit = urlpattern.URLPatternInit;

// ============================================================================
// Basic String Input Tests
// ============================================================================

test "URLPattern.create - simple HTTPS URL" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://example.com/path",
    }, .{});
    defer pattern.deinit(allocator);

    // Verify protocol is "https"
    try testing.expectEqualStrings("https", pattern.protocol.pattern_string);
    // Verify hostname is "example.com"
    try testing.expectEqualStrings("example.com", pattern.hostname.pattern_string);
    // Verify pathname is "/path"
    try testing.expectEqualStrings("/path", pattern.pathname.pattern_string);
}

test "URLPattern.create - URL with named parameter" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://example.com/:id",
    }, .{});
    defer pattern.deinit(allocator);

    // Protocol should be "https"
    try testing.expectEqualStrings("https", pattern.protocol.pattern_string);
    // Pathname should contain the named parameter
    try testing.expect(std.mem.indexOf(u8, pattern.pathname.pattern_string, ":id") != null or
        std.mem.indexOf(u8, pattern.pathname.pattern_string, "id") != null);
    // Should have group names for the parameter
    try testing.expect(pattern.pathname.group_names.len > 0);
}

test "URLPattern.create - URL with port" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://example.com:8080/api",
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expectEqualStrings("https", pattern.protocol.pattern_string);
    try testing.expectEqualStrings("example.com", pattern.hostname.pattern_string);
    try testing.expectEqualStrings("8080", pattern.port.pattern_string);
    try testing.expectEqualStrings("/api", pattern.pathname.pattern_string);
}

test "URLPattern.create - URL with query and fragment" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://example.com/path?query#fragment",
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expectEqualStrings("/path", pattern.pathname.pattern_string);
    try testing.expectEqualStrings("query", pattern.search.pattern_string);
    try testing.expectEqualStrings("fragment", pattern.hash.pattern_string);
}

test "URLPattern.create - URL with username and named param (unescaped colon)" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    // Without escaping the colon, :pass is treated as a named parameter
    // So username becomes "user:pass" pattern and password is default wildcard
    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://user:pass@example.com/",
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expectEqualStrings("https", pattern.protocol.pattern_string);
    try testing.expectEqualStrings("user:pass", pattern.username.pattern_string);
    try testing.expectEqualStrings("*", pattern.password.pattern_string); // Default wildcard
    try testing.expectEqualStrings("example.com", pattern.hostname.pattern_string);
}

test "URLPattern.create - URL with username and password (escaped colon)" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    // With escaped colon, the colon is a literal separator between username and password
    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://user\\:pass@example.com/",
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expectEqualStrings("https", pattern.protocol.pattern_string);
    try testing.expectEqualStrings("user", pattern.username.pattern_string);
    try testing.expectEqualStrings("pass", pattern.password.pattern_string);
    try testing.expectEqualStrings("example.com", pattern.hostname.pattern_string);
}

// ============================================================================
// Wildcard Pattern Tests
// ============================================================================

test "URLPattern.create - wildcard protocol" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "*://example.com/path",
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expectEqualStrings("*", pattern.protocol.pattern_string);
    try testing.expectEqualStrings("example.com", pattern.hostname.pattern_string);
}

test "URLPattern.create - wildcard hostname" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://*.example.com/",
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expectEqualStrings("https", pattern.protocol.pattern_string);
    // Hostname pattern should contain wildcard
    try testing.expect(pattern.hostname.pattern_string.len > 0);
}

test "URLPattern.create - wildcard pathname" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://example.com/*",
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expectEqualStrings("https", pattern.protocol.pattern_string);
    try testing.expectEqualStrings("example.com", pattern.hostname.pattern_string);
    // Pathname should contain wildcard
    try testing.expect(std.mem.indexOf(u8, pattern.pathname.pattern_string, "*") != null);
}

test "URLPattern.create - all wildcards" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "*://*/*",
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expectEqualStrings("*", pattern.protocol.pattern_string);
    // All components should compile successfully
    try testing.expect(pattern.hostname.pattern_string.len > 0);
    try testing.expect(pattern.pathname.pattern_string.len > 0);
}

// ============================================================================
// URLPatternInit Dictionary Tests
// ============================================================================

test "URLPattern.create - from URLPatternInit with protocol" {
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
    // Other components should default to wildcard
    try testing.expectEqualStrings("*", pattern.username.pattern_string);
    try testing.expectEqualStrings("*", pattern.password.pattern_string);
    try testing.expectEqualStrings("*", pattern.hostname.pattern_string);
}

test "URLPattern.create - from URLPatternInit with hostname and pathname" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .hostname = "example.com",
            .pathname = "/api/:version/*",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expectEqualStrings("example.com", pattern.hostname.pattern_string);
    // Pathname should preserve the pattern structure
    try testing.expect(pattern.pathname.pattern_string.len > 0);
    try testing.expect(pattern.pathname.group_names.len > 0);
}

test "URLPattern.create - from URLPatternInit with all components" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .protocol = "https",
            .username = "user",
            .password = "pass",
            .hostname = "example.com",
            .port = "8080",
            .pathname = "/api",
            .search = "q=test",
            .hash = "section",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expectEqualStrings("https", pattern.protocol.pattern_string);
    try testing.expectEqualStrings("user", pattern.username.pattern_string);
    try testing.expectEqualStrings("pass", pattern.password.pattern_string);
    try testing.expectEqualStrings("example.com", pattern.hostname.pattern_string);
    try testing.expectEqualStrings("8080", pattern.port.pattern_string);
    try testing.expectEqualStrings("/api", pattern.pathname.pattern_string);
    try testing.expectEqualStrings("q=test", pattern.search.pattern_string);
    try testing.expectEqualStrings("section", pattern.hash.pattern_string);
}

test "URLPattern.create - from URLPatternInit with wildcard hostname" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .protocol = "https",
            .hostname = "*.example.com",
            .pathname = "/api/:version/*",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expectEqualStrings("https", pattern.protocol.pattern_string);
    try testing.expect(pattern.hostname.pattern_string.len > 0);
    try testing.expect(pattern.pathname.pattern_string.len > 0);
}

// ============================================================================
// Named Parameter Tests
// ============================================================================

test "URLPattern.create - multiple named parameters" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://example.com/:org/:repo/:branch/*",
    }, .{});
    defer pattern.deinit(allocator);

    // Should have multiple group names
    try testing.expect(pattern.pathname.group_names.len >= 3);
}

test "URLPattern.create - named parameter with regex constraint" {
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

    // Should indicate regexp groups
    try testing.expect(pattern.pathname.has_regexp_groups);
    try testing.expect(pattern.hasRegexpGroups());
}

test "URLPattern.create - named parameter without regex constraint" {
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

    // Should NOT indicate regexp groups (just segment wildcard)
    try testing.expect(!pattern.pathname.has_regexp_groups);
    try testing.expect(!pattern.hasRegexpGroups());
}

// ============================================================================
// Relative Pathname Tests
// ============================================================================

test "URLPattern.create - relative pathname only" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    // Create step 2.2: relative strings require a base (WPT vectors 216-217).
    try testing.expectError(error.InvalidPattern, URLPattern.create(testing.allocator, realm, .{
        .string = "/users/:id/posts/:postId",
    }, .{}));
}

test "URLPattern.create - pathname starting with /" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .pathname = "/api/v1/users",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expectEqualStrings("/api/v1/users", pattern.pathname.pattern_string);
}

// ============================================================================
// Options Tests
// ============================================================================

test "URLPattern.create - ignore_case option" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://example.com/path",
    }, .{ .ignore_case = true });
    defer pattern.deinit(allocator);

    try testing.expect(pattern.ignore_case);
}

test "URLPattern.create - default ignore_case is false" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://example.com/path",
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(!pattern.ignore_case);
}

// ============================================================================
// Component Regex Compilation Tests
// ============================================================================

test "URLPattern.create - all components get compiled regex" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://user:pass@example.com:8080/path?query#hash",
    }, .{});
    defer pattern.deinit(allocator);

    // All 8 components should have regex strings
    try testing.expect(pattern.protocol.regex_string.len > 0);
    try testing.expect(pattern.username.regex_string.len > 0);
    try testing.expect(pattern.password.regex_string.len > 0);
    try testing.expect(pattern.hostname.regex_string.len > 0);
    try testing.expect(pattern.port.regex_string.len > 0);
    try testing.expect(pattern.pathname.regex_string.len > 0);
    try testing.expect(pattern.search.regex_string.len > 0);
    try testing.expect(pattern.hash.regex_string.len > 0);
}

test "URLPattern.create - components with patterns have compiled regex" {
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

    // Pathname's regular expression: the generated string, positional
    try testing.expectEqualStrings("^(?:\\/([^\\/]+?))$", pattern.pathname.regex_string);
    try testing.expectEqualStrings(pattern.pathname.regex_string, pattern.pathname.regexp.source);
    try testing.expect(!pattern.pathname.regexp.ignore_case);
}

// ============================================================================
// hasRegexpGroups Tests
// ============================================================================

test "URLPattern.hasRegexpGroups - returns true for custom regexp" {
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

test "URLPattern.hasRegexpGroups - returns false for standard patterns" {
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

test "URLPattern.hasRegexpGroups - returns true if any component has regexp" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .search = ":query([a-z]+)",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expect(pattern.hasRegexpGroups());
    try testing.expect(pattern.search.has_regexp_groups);
    try testing.expect(!pattern.protocol.has_regexp_groups);
}

// ============================================================================
// Special Scheme Handling Tests
// ============================================================================

test "URLPattern.create - http scheme (special)" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "http://example.com/",
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expectEqualStrings("http", pattern.protocol.pattern_string);
    // Special schemes get "/" default pathname
    try testing.expectEqualStrings("/", pattern.pathname.pattern_string);
}

test "URLPattern.create - custom scheme (non-special)" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "custom://example.com/",
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expectEqualStrings("custom", pattern.protocol.pattern_string);
}

test "URLPattern.create - file scheme (special)" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .protocol = "file",
            .pathname = "/path/to/file",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expectEqualStrings("file", pattern.protocol.pattern_string);
    try testing.expectEqualStrings("/path/to/file", pattern.pathname.pattern_string);
}

// ============================================================================
// Component Group Names Tests
// ============================================================================

test "URLPattern.create - group names extracted from pathname" {
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

    try testing.expect(pattern.pathname.group_names.len >= 2);
}

test "URLPattern.create - group names for wildcard" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .pathname = "/api/*",
        },
    }, .{});
    defer pattern.deinit(allocator);

    // Wildcard should create a numbered group
    try testing.expect(pattern.pathname.group_names.len > 0);
}

// ============================================================================
// Memory Management Tests
// ============================================================================

test "URLPattern.create - no memory leaks on successful creation" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://user:pass@example.com:8080/path?query#hash",
    }, .{});
    pattern.deinit(allocator);
    // testing.allocator will detect leaks
}

test "URLPattern.create - no memory leaks with complex pattern" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .protocol = "https",
            .hostname = "*.example.com",
            .pathname = "/api/:version/:resource/:id(\\d+)/*",
            .search = ":query",
            .hash = ":section",
        },
    }, .{});
    pattern.deinit(allocator);
    // testing.allocator will detect leaks
}

// ============================================================================
// Edge Cases
// ============================================================================

test "URLPattern.create - empty pathname" {
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

    // Create step 5 defaults an absent init component to a wildcard.
    try testing.expectEqualStrings("*", pattern.pathname.pattern_string);
}

test "URLPattern.create - IPv6 hostname (escaped colons)" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    // IPv6 addresses need escaped colons in URLPattern strings
    // because unescaped colons start named parameters
    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://[\\:\\:1]:8080/",
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expectEqualStrings("https", pattern.protocol.pattern_string);
    // IPv6 hostname pattern preserves escapes
    try testing.expectEqualStrings("[\\:\\:1]", pattern.hostname.pattern_string);
    try testing.expectEqualStrings("8080", pattern.port.pattern_string);
}

test "URLPattern.create - search prefix without value" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .pathname = "/path",
            .search = "",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expectEqualStrings("/path", pattern.pathname.pattern_string);
}

test "URLPattern.create - hash prefix without value" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .pathname = "/path",
            .hash = "",
        },
    }, .{});
    defer pattern.deinit(allocator);

    try testing.expectEqualStrings("/path", pattern.pathname.pattern_string);
}
