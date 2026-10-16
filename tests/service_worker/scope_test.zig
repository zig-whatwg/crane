//! Service Workers' URL steps: Start Register's checks, registration
//! matching, and the Update algorithm's maximum scope.

const std = @import("std");
const testing = std.testing;
const scope = @import("service_worker").scope;

test "Start Register: the scope defaults to the script's directory, fragments go" {
    var urls = try scope.startRegister(testing.allocator, "https://example.com/a/b/sw.js#frag", null, false);
    defer urls.deinit(testing.allocator);
    try testing.expectEqualStrings("https://example.com/a/b/sw.js", urls.script_url);
    try testing.expectEqualStrings("https://example.com/a/b/", urls.scope_url);

    var given = try scope.startRegister(testing.allocator, "https://example.com/sw.js", "https://example.com/x/#y", false);
    defer given.deinit(testing.allocator);
    try testing.expectEqualStrings("https://example.com/x/", given.scope_url);
}

test "Start Register rejects a failed URL, a non-HTTP(S) scheme and an escaped slash" {
    // Step 1: scriptURL failure.
    try testing.expectError(error.TypeError, scope.startRegister(testing.allocator, null, null, false));
    // Step 3: scheme.
    try testing.expectError(error.TypeError, scope.startRegister(testing.allocator, "data:text/javascript,", null, false));
    try testing.expectError(error.TypeError, scope.startRegister(testing.allocator, "ftp://example.com/sw.js", null, false));
    // Step 4: %2f or %5c in the script's path, either case.
    try testing.expectError(error.TypeError, scope.startRegister(testing.allocator, "https://example.com/a%2Fb/sw.js", null, false));
    try testing.expectError(error.TypeError, scope.startRegister(testing.allocator, "https://example.com/a%5cb/sw.js", null, false));
    // Step 6: a scope that failed to parse.
    try testing.expectError(error.TypeError, scope.startRegister(testing.allocator, "https://example.com/sw.js", null, true));
    // Step 8: the scope's scheme.
    try testing.expectError(error.TypeError, scope.startRegister(testing.allocator, "https://example.com/sw.js", "blob:https://example.com/x", false));
    // Step 9: an escaped slash in the scope's path.
    try testing.expectError(error.TypeError, scope.startRegister(testing.allocator, "https://example.com/sw.js", "https://example.com/a%2f/", false));
}

test "Match Service Worker Registration takes the longest prefix, not a path match" {
    const scopes = [_][]const u8{
        "https://example.com/",
        "https://example.com/prefix",
        "https://example.com/prefix/deeper/",
    };
    try testing.expectEqual(@as(?usize, 1), scope.longestMatchingScope(&scopes, "https://example.com/prefix-of/resource.html"));
    try testing.expectEqual(@as(?usize, 2), scope.longestMatchingScope(&scopes, "https://example.com/prefix/deeper/x"));
    try testing.expectEqual(@as(?usize, 0), scope.longestMatchingScope(&scopes, "https://example.com/other"));
    try testing.expectEqual(@as(?usize, null), scope.longestMatchingScope(&scopes, "https://other.com/"));
}

test "the maximum scope: the script's directory, or Service-Worker-Allowed of the same origin" {
    const a = testing.allocator;
    // Steps 13 and 16: no header - the scope must be under the script's
    // directory.
    try testing.expect(try scope.scopeIsAllowed(a, "https://e.com/js/sw.js", "https://e.com/js/", null));
    try testing.expect(try scope.scopeIsAllowed(a, "https://e.com/js/sw.js", "https://e.com/js/deeper/", null));
    try testing.expect(!try scope.scopeIsAllowed(a, "https://e.com/js/sw.js", "https://e.com/", null));
    // Step 14: the header widens it, relative to the script.
    try testing.expect(try scope.scopeIsAllowed(a, "https://e.com/js/sw.js", "https://e.com/", "/"));
    try testing.expect(!try scope.scopeIsAllowed(a, "https://e.com/foo/bar/sw.js", "https://e.com/", "/foo"));
    // 14.3: a header naming another origin leaves no maximum: refused.
    try testing.expect(!try scope.scopeIsAllowed(a, "https://e.com/js/sw.js", "https://e.com/js/", "https://other.com/"));
    // 14.2: a header that does not parse is a network error.
    try testing.expectError(error.NetworkError, scope.scopeIsAllowed(a, "https://e.com/js/sw.js", "https://e.com/js/", "http://[bad"));
}

test "origins: same-origin URLs, and an opaque origin is the same as nothing" {
    const a = testing.allocator;
    try testing.expect(try scope.sameOriginUrls(a, "https://e.com/a", "https://e.com:443/b"));
    try testing.expect(!try scope.sameOriginUrls(a, "https://e.com/a", "http://e.com/a"));
    try testing.expect(!try scope.sameOriginUrls(a, "data:,x", "data:,x"));
    const origin = try scope.originOf(a, "https://e.com:8443/path?q");
    defer a.free(origin);
    try testing.expectEqualStrings("https://e.com:8443", origin);
}
