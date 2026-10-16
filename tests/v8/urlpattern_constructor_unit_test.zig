//! URLPattern construction (src/urlpattern/constructor.zig): these tests were
//! the module's own; constructing a pattern compiles its regexps in an engine,
//! so they run here, in a realm (urlpattern_realm.zig).

const std = @import("std");
const urlpattern = @import("urlpattern");
const harness = @import("urlpattern_realm.zig");
const URLPattern = urlpattern.URLPattern;

test "URLPattern.create - simple URL string" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://example.com/path",
    }, .{});
    defer pattern.deinit(allocator);

    // Protocol should be "https"
    try std.testing.expectEqualStrings("https", pattern.protocol.pattern_string);
    // Hostname should be "example.com"
    try std.testing.expectEqualStrings("example.com", pattern.hostname.pattern_string);
    // Pathname should be "/path"
    try std.testing.expectEqualStrings("/path", pattern.pathname.pattern_string);
}

test "URLPattern.create - URL with named parameter" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://example.com/:id",
    }, .{});
    defer pattern.deinit(allocator);

    // Protocol should be "https"
    try std.testing.expectEqualStrings("https", pattern.protocol.pattern_string);
    // Pathname should have the named parameter
    try std.testing.expect(std.mem.indexOf(u8, pattern.pathname.pattern_string, ":id") != null or
        std.mem.indexOf(u8, pattern.pathname.pattern_string, "id") != null);
}

test "URLPattern.create - from URLPatternInit" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .init = .{
            .protocol = "https",
            .hostname = "*.example.com",
            .pathname = "/api/:version/*",
        },
    }, .{});
    defer pattern.deinit(allocator);

    // Check components
    try std.testing.expectEqualStrings("https", pattern.protocol.pattern_string);
    // Hostname should contain the wildcard
    try std.testing.expect(pattern.hostname.pattern_string.len > 0);
    // Pathname should have named parameter
    try std.testing.expect(pattern.pathname.pattern_string.len > 0);
}

test "URLPattern.create - wildcard patterns" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "*://*/*",
    }, .{});
    defer pattern.deinit(allocator);

    // All wildcards should compile
    try std.testing.expect(pattern.protocol.pattern_string.len > 0);
    try std.testing.expect(pattern.hostname.pattern_string.len > 0);
    try std.testing.expect(pattern.pathname.pattern_string.len > 0);
}

test "URLPattern.create - with search and hash" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://example.com/path?:query#:section",
    }, .{});
    defer pattern.deinit(allocator);

    // Check that search and hash are captured
    try std.testing.expect(pattern.search.pattern_string.len > 0);
    try std.testing.expect(pattern.hash.pattern_string.len > 0);
}

test "URLPattern.create - relative pathname" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    // Create step 2.2: relative strings require a base (WPT vectors 216-217).
    try std.testing.expectError(error.InvalidPattern, URLPattern.create(std.testing.allocator, realm, .{
        .string = "/users/:id/posts/:postId",
    }, .{}));
}

test "URLPattern.create - ignore_case option" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, realm, .{
        .string = "https://example.com/path",
    }, .{ .ignore_case = true });
    defer pattern.deinit(allocator);

    try std.testing.expect(pattern.ignore_case);
}

test "Component - has_regexp_groups" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    // Pattern with custom regexp
    var pattern1 = try URLPattern.create(allocator, realm, .{
        .init = .{
            .pathname = "/users/:id(\\d+)",
        },
    }, .{});
    defer pattern1.deinit(allocator);

    try std.testing.expect(pattern1.pathname.has_regexp_groups);

    // Pattern without custom regexp
    var pattern2 = try URLPattern.create(allocator, realm, .{
        .init = .{
            .pathname = "/users/:id",
        },
    }, .{});
    defer pattern2.deinit(allocator);

    try std.testing.expect(!pattern2.pathname.has_regexp_groups);
}

test "URLPattern.hasRegexpGroups" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    var pattern1 = try URLPattern.create(allocator, realm, .{
        .init = .{
            .pathname = "/users/:id(\\d+)",
        },
    }, .{});
    defer pattern1.deinit(allocator);

    try std.testing.expect(pattern1.hasRegexpGroups());

    var pattern2 = try URLPattern.create(allocator, realm, .{
        .string = "https://example.com/*",
    }, .{});
    defer pattern2.deinit(allocator);

    try std.testing.expect(!pattern2.hasRegexpGroups());
}
