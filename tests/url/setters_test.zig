//! URL Setters Test Suite
//!
//! Comprehensive tests for all URL setter methods following the WHATWG URL Standard.
//! Tests cover:
//! - setProtocol() - scheme changes with validation
//! - setUsername() - userinfo component modification
//! - setPassword() - password component modification
//! - setHost() - host and port modification
//! - setHostname() - host-only modification
//! - setPort() - port modification
//! - setPathname() - path modification
//! - setHash() - fragment modification
//!
//! Each setter is tested for:
//! - Basic functionality
//! - Edge cases
//! - Spec-compliant validation rules
//! - Error handling

const std = @import("std");
const url_mod = @import("url");
const URL = @import("url0").URL;
const helpers = @import("url").test_helpers;

test "setProtocol - basic HTTP to HTTPS" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/path", null);
    defer url.deinit();

    try helpers.setProtocol(&url, allocator, "https");

    const href = try helpers.getHref(&url, allocator);
    defer allocator.free(href);

    try std.testing.expectEqualStrings("https://example.com/path", href);
}

test "setProtocol - remove colon if provided" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/", null);
    defer url.deinit();

    // Spec: input is "https:", parser removes trailing ":"
    try helpers.setProtocol(&url, allocator, "https:");

    const protocol = try helpers.getProtocol(&url, allocator);
    defer allocator.free(protocol);

    try std.testing.expectEqualStrings("https:", protocol);
}

test "setProtocol - reject invalid characters" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/", null);
    defer url.deinit();

    const old_href = try helpers.getHref(&url, allocator);
    defer allocator.free(old_href);

    // Invalid scheme (contains space) - should not change
    try helpers.setProtocol(&url, allocator, "ht tp");

    const new_href = try helpers.getHref(&url, allocator);
    defer allocator.free(new_href);

    try std.testing.expectEqualStrings(old_href, new_href);
}

test "setProtocol - disallow special to non-special transition" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/", null);
    defer url.deinit();

    // Try to change from special (http) to non-special (mailto)
    try helpers.setProtocol(&url, allocator, "mailto");

    const protocol = try helpers.getProtocol(&url, allocator);
    defer allocator.free(protocol);

    // Should remain http (transition disallowed)
    try std.testing.expectEqualStrings("http:", protocol);
}

test "setProtocol - disallow non-special to special transition" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "mailto:user@example.com", null);
    defer url.deinit();

    // Try to change from non-special (mailto) to special (http)
    try helpers.setProtocol(&url, allocator, "http");

    const protocol = try helpers.getProtocol(&url, allocator);
    defer allocator.free(protocol);

    // Should remain mailto (transition disallowed)
    try std.testing.expectEqualStrings("mailto:", protocol);
}

test "setProtocol - reset default port" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com:80/", null);
    defer url.deinit();

    // Port 80 is default for http, so it's normalized to null during parsing
    try helpers.setProtocol(&url, allocator, "https");

    // Per WHATWG spec, default ports are normalized to null during parsing.
    // Since http://example.com:80/ has port=null after parsing (80 is default),
    // changing to https keeps port=null. The explicit :80 cannot be recovered.
    const port = try helpers.getPort(&url, allocator);
    defer allocator.free(port);

    // Port stays empty because it was normalized to null during initial parse
    try std.testing.expectEqualStrings("", port);
}

test "setUsername - basic" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/", null);
    defer url.deinit();

    try helpers.setUsername(&url, allocator, "user");

    const username = try helpers.getUsername(&url, allocator);
    defer allocator.free(username);
    try std.testing.expectEqualStrings("user", username);

    const href = try helpers.getHref(&url, allocator);
    defer allocator.free(href);
    try std.testing.expectEqualStrings("http://user@example.com/", href);
}

test "setUsername - with existing password" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://olduser:pass@example.com/", null);
    defer url.deinit();

    try helpers.setUsername(&url, allocator, "newuser");

    const href = try helpers.getHref(&url, allocator);
    defer allocator.free(href);
    try std.testing.expectEqualStrings("http://newuser:pass@example.com/", href);
}

test "setUsername - percent encode special characters" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/", null);
    defer url.deinit();

    try helpers.setUsername(&url, allocator, "user@host");

    const username = try helpers.getUsername(&url, allocator);
    defer allocator.free(username);
    // @ should be percent-encoded in username
    try std.testing.expect(std.mem.indexOf(u8, username, "%40") != null);
}

test "setUsername - cannot set on file URL without host" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "file:///path/to/file", null);
    defer url.deinit();

    const old_href = try helpers.getHref(&url, allocator);
    defer allocator.free(old_href);

    // Should not change (file: without host cannot have username)
    try helpers.setUsername(&url, allocator, "user");

    const new_href = try helpers.getHref(&url, allocator);
    defer allocator.free(new_href);

    try std.testing.expectEqualStrings(old_href, new_href);
}

test "setPassword - basic" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://user@example.com/", null);
    defer url.deinit();

    try helpers.setPassword(&url, allocator, "secret");

    const password = try helpers.getPassword(&url, allocator);
    defer allocator.free(password);
    try std.testing.expectEqualStrings("secret", password);

    const href = try helpers.getHref(&url, allocator);
    defer allocator.free(href);
    try std.testing.expectEqualStrings("http://user:secret@example.com/", href);
}

test "setPassword - without username creates empty username" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/", null);
    defer url.deinit();

    try helpers.setPassword(&url, allocator, "secret");

    const href = try helpers.getHref(&url, allocator);
    defer allocator.free(href);

    // Empty username with password: ":/secret@"
    try std.testing.expect(std.mem.indexOf(u8, href, ":secret@") != null);
}

test "setPassword - percent encode special characters" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://user@example.com/", null);
    defer url.deinit();

    try helpers.setPassword(&url, allocator, "p@ss");

    const password = try helpers.getPassword(&url, allocator);
    defer allocator.free(password);
    // @ should be percent-encoded
    try std.testing.expect(std.mem.indexOf(u8, password, "%40") != null);
}

test "setHost - basic" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/path", null);
    defer url.deinit();

    try helpers.setHost(&url, allocator, "newhost.com");

    const href = try helpers.getHref(&url, allocator);
    defer allocator.free(href);
    try std.testing.expectEqualStrings("http://newhost.com/path", href);
}

test "setHost - with port" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/", null);
    defer url.deinit();

    try helpers.setHost(&url, allocator, "newhost.com:8080");

    const href = try helpers.getHref(&url, allocator);
    defer allocator.free(href);
    try std.testing.expectEqualStrings("http://newhost.com:8080/", href);
}

test "setHost - cannot set on URL with opaque path" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "mailto:user@example.com", null);
    defer url.deinit();

    const old_href = try helpers.getHref(&url, allocator);
    defer allocator.free(old_href);

    // Should not change (opaque path)
    try helpers.setHost(&url, allocator, "newhost.com");

    const new_href = try helpers.getHref(&url, allocator);
    defer allocator.free(new_href);

    try std.testing.expectEqualStrings(old_href, new_href);
}

test "setHostname - basic" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com:8080/", null);
    defer url.deinit();

    try helpers.setHostname(&url, allocator, "newhost.com");

    const href = try helpers.getHref(&url, allocator);
    defer allocator.free(href);

    // Port should be preserved
    try std.testing.expectEqualStrings("http://newhost.com:8080/", href);
}

test "setHostname - preserves existing port" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com:9000/", null);
    defer url.deinit();

    try helpers.setHostname(&url, allocator, "another.com");

    const port = try helpers.getPort(&url, allocator);
    defer allocator.free(port);

    try std.testing.expectEqualStrings("9000", port);
}

test "setPort - basic" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/", null);
    defer url.deinit();

    try helpers.setPort(&url, allocator, "8080");

    const port = try helpers.getPort(&url, allocator);
    defer allocator.free(port);
    try std.testing.expectEqualStrings("8080", port);

    const href = try helpers.getHref(&url, allocator);
    defer allocator.free(href);
    try std.testing.expectEqualStrings("http://example.com:8080/", href);
}

test "setPort - empty string removes port" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com:8080/", null);
    defer url.deinit();

    try helpers.setPort(&url, allocator, "");

    const port = try helpers.getPort(&url, allocator);
    defer allocator.free(port);
    try std.testing.expectEqualStrings("", port);
}

test "setPort - reject invalid port" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com:8080/", null);
    defer url.deinit();

    const old_port = try helpers.getPort(&url, allocator);
    defer allocator.free(old_port);

    // Invalid port (contains letter)
    try helpers.setPort(&url, allocator, "80abc");

    const new_port = try helpers.getPort(&url, allocator);
    defer allocator.free(new_port);

    // Should remain unchanged
    try std.testing.expectEqualStrings(old_port, new_port);
}

test "setPort - reject out of range port" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com:8080/", null);
    defer url.deinit();

    const old_port = try helpers.getPort(&url, allocator);
    defer allocator.free(old_port);

    // Port > 65535
    try helpers.setPort(&url, allocator, "99999");

    const new_port = try helpers.getPort(&url, allocator);
    defer allocator.free(new_port);

    // Should remain unchanged
    try std.testing.expectEqualStrings(old_port, new_port);
}

test "setPort - cannot set on file URL" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "file:///path/to/file", null);
    defer url.deinit();

    const old_href = try helpers.getHref(&url, allocator);
    defer allocator.free(old_href);

    try helpers.setPort(&url, allocator, "8080");

    const new_href = try helpers.getHref(&url, allocator);
    defer allocator.free(new_href);

    // Should not change
    try std.testing.expectEqualStrings(old_href, new_href);
}

test "setPathname - basic" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/old/path", null);
    defer url.deinit();

    try helpers.setPathname(&url, allocator, "/new/path");

    const href = try helpers.getHref(&url, allocator);
    defer allocator.free(href);
    try std.testing.expectEqualStrings("http://example.com/new/path", href);
}

test "setPathname - adds leading slash for special schemes" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/old", null);
    defer url.deinit();

    try helpers.setPathname(&url, allocator, "new/path");

    const pathname = try helpers.getPathname(&url, allocator);
    defer allocator.free(pathname);

    // Should have leading /
    try std.testing.expect(std.mem.startsWith(u8, pathname, "/"));
}

test "setPathname - preserves query and fragment" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/old?query=1#frag", null);
    defer url.deinit();

    try helpers.setPathname(&url, allocator, "/new");

    const href = try helpers.getHref(&url, allocator);
    defer allocator.free(href);
    try std.testing.expectEqualStrings("http://example.com/new?query=1#frag", href);
}

test "setPathname - cannot set on URL with opaque path" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "mailto:user@example.com", null);
    defer url.deinit();

    const old_href = try helpers.getHref(&url, allocator);
    defer allocator.free(old_href);

    try helpers.setPathname(&url, allocator, "/new");

    const new_href = try helpers.getHref(&url, allocator);
    defer allocator.free(new_href);

    // Should not change
    try std.testing.expectEqualStrings(old_href, new_href);
}

test "setHash - basic" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/path", null);
    defer url.deinit();

    try helpers.setHash(&url, allocator, "section");

    const hash = try helpers.getHash(&url, allocator);
    defer allocator.free(hash);
    try std.testing.expectEqualStrings("#section", hash);

    const href = try helpers.getHref(&url, allocator);
    defer allocator.free(href);
    try std.testing.expectEqualStrings("http://example.com/path#section", href);
}

test "setHash - removes leading # if provided" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/", null);
    defer url.deinit();

    try helpers.setHash(&url, allocator, "#section");

    const hash = try helpers.getHash(&url, allocator);
    defer allocator.free(hash);
    try std.testing.expectEqualStrings("#section", hash);
}

test "setHash - empty string removes fragment" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/path#old", null);
    defer url.deinit();

    try helpers.setHash(&url, allocator, "");

    const hash = try helpers.getHash(&url, allocator);
    defer allocator.free(hash);
    try std.testing.expectEqualStrings("", hash);

    const href = try helpers.getHref(&url, allocator);
    defer allocator.free(href);
    try std.testing.expectEqualStrings("http://example.com/path", href);
}

test "setHash - preserves query" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/path?query=1", null);
    defer url.deinit();

    try helpers.setHash(&url, allocator, "frag");

    const href = try helpers.getHref(&url, allocator);
    defer allocator.free(href);
    try std.testing.expectEqualStrings("http://example.com/path?query=1#frag", href);
}

test "setHash - replaces existing fragment" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/#old", null);
    defer url.deinit();

    try helpers.setHash(&url, allocator, "new");

    const hash = try helpers.getHash(&url, allocator);
    defer allocator.free(hash);
    try std.testing.expectEqualStrings("#new", hash);
}
