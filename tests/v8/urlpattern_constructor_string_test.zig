//! URLPattern constructor string parsing
//! (src/urlpattern/constructor_string_parser.zig): these tests were the
//! module's own; the parser compiles the protocol component's regexp to learn
//! whether it matches a special scheme, in an engine, so they run here, in a
//! realm (urlpattern_realm.zig).

const std = @import("std");
const urlpattern = @import("urlpattern");
const harness = @import("urlpattern_realm.zig");
const parse = urlpattern.parseConstructorString;

test "parse - simple URL" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    const result = try parse(allocator, realm, "https://example.com/path");

    try std.testing.expectEqualStrings("https", result.protocol.?);
    try std.testing.expectEqualStrings("example.com", result.hostname.?);
    try std.testing.expectEqualStrings("/path", result.pathname.?);
    try std.testing.expectEqualStrings("", result.port.?);
}

test "parse - URL with port" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    const result = try parse(allocator, realm, "https://example.com:8080/path");

    try std.testing.expectEqualStrings("https", result.protocol.?);
    try std.testing.expectEqualStrings("example.com", result.hostname.?);
    try std.testing.expectEqualStrings("8080", result.port.?);
    try std.testing.expectEqualStrings("/path", result.pathname.?);
}

test "parse - URL with search and hash" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    const result = try parse(allocator, realm, "https://example.com/path?query=1#section");

    try std.testing.expectEqualStrings("https", result.protocol.?);
    try std.testing.expectEqualStrings("example.com", result.hostname.?);
    try std.testing.expectEqualStrings("/path", result.pathname.?);
    try std.testing.expectEqualStrings("query=1", result.search.?);
    try std.testing.expectEqualStrings("section", result.hash.?);
}

test "parse - relative pathname" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    const result = try parse(allocator, realm, "/api/:version/users/:id");

    try std.testing.expect(result.protocol == null);
    try std.testing.expect(result.hostname == null);
    try std.testing.expectEqualStrings("/api/:version/users/:id", result.pathname.?);
}

test "parse - URL with named parameter" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    const result = try parse(allocator, realm, "https://example.com/:path");

    try std.testing.expectEqualStrings("https", result.protocol.?);
    try std.testing.expectEqualStrings("example.com", result.hostname.?);
    try std.testing.expectEqualStrings("/:path", result.pathname.?);
}

test "parse - URL with username and named param (unescaped colon)" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    // When colon is NOT escaped, :pass is treated as a named parameter
    // The username pattern becomes "user:pass" (with :pass as named param)
    // Password is not set (defaults to wildcard)
    const result = try parse(allocator, realm, "https://user:pass@example.com/path");

    try std.testing.expectEqualStrings("https", result.protocol.?);
    try std.testing.expectEqualStrings("user:pass", result.username.?);
    try std.testing.expect(result.password == null);
    try std.testing.expectEqualStrings("example.com", result.hostname.?);
    try std.testing.expectEqualStrings("/path", result.pathname.?);
}

test "parse - URL with username and password (escaped colon)" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    // When colon IS escaped, it's treated as a literal separator
    // Username is "user", password is "pass"
    const result = try parse(allocator, realm, "https://user\\:pass@example.com/path");

    try std.testing.expectEqualStrings("https", result.protocol.?);
    try std.testing.expectEqualStrings("user", result.username.?);
    try std.testing.expectEqualStrings("pass", result.password.?);
    try std.testing.expectEqualStrings("example.com", result.hostname.?);
    try std.testing.expectEqualStrings("/path", result.pathname.?);
}

test "parse - URL with wildcard" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    const result = try parse(allocator, realm, "*://*/*.js");

    try std.testing.expectEqualStrings("*", result.protocol.?);
    try std.testing.expectEqualStrings("*", result.hostname.?);
    try std.testing.expectEqualStrings("/*.js", result.pathname.?);
}

test "parse - search only" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    const result = try parse(allocator, realm, "?foo=bar");

    try std.testing.expect(result.protocol == null);
    try std.testing.expectEqualStrings("foo=bar", result.search.?);
}

test "parse - hash only" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    const result = try parse(allocator, realm, "#section");

    try std.testing.expect(result.protocol == null);
    try std.testing.expectEqualStrings("section", result.hash.?);
}

test "parse - IPv6 hostname" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    const result = try parse(allocator, realm, "https://[::1]:8080/path");

    try std.testing.expectEqualStrings("https", result.protocol.?);
    try std.testing.expectEqualStrings("[::1]", result.hostname.?);
    try std.testing.expectEqualStrings("8080", result.port.?);
    try std.testing.expectEqualStrings("/path", result.pathname.?);
}

test "parse - non-special scheme (opaque URL)" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = std.testing.allocator;

    // A delimiter must be literal: WPT 234-235 and parser step 2.5.
    const result = try parse(allocator, realm, "data\\:text/plain,hello");
    const unescaped = try parse(allocator, realm, "data:text/plain,hello");
    try std.testing.expect(unescaped.protocol == null);

    try std.testing.expectEqualStrings("data", result.protocol.?);
    // Non-special schemes go directly to pathname
    try std.testing.expectEqualStrings("text/plain,hello", result.pathname.?);
}
