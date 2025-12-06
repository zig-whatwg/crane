//! Cookie Store Algorithms
//!
//! WHATWG Cookie Store Standard: https://cookiestore.spec.whatwg.org/
//! RFC 6265bis: https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis
//!
//! This module implements the spec algorithms for cookie operations:
//! - query cookies
//! - set a cookie
//! - delete a cookie
//! - create a CookieListItem

const std = @import("std");
const Cookie = @import("cookie.zig").Cookie;
const SameSite = @import("cookie.zig").SameSite;
const PartitionKey = @import("cookie.zig").PartitionKey;
const CookieListItem = @import("cookie.zig").CookieListItem;
const CookieJar = @import("jar.zig").CookieJar;
const RetrieveOptions = @import("jar.zig").RetrieveOptions;
const SameSiteContext = @import("jar.zig").SameSiteContext;
const validation = @import("validation.zig");
const domain_matching = @import("domain_matching.zig");

/// Error types for cookie operations
pub const CookieError = error{
    /// Validation failed (invalid characters, prefix rules, etc.)
    ValidationError,
    /// Domain is not valid for the request
    DomainError,
    /// Path is not valid
    PathError,
    /// Security constraint violated
    SecurityError,
    /// Memory allocation failed
    OutOfMemory,
};

/// Options for setting a cookie
/// https://cookiestore.spec.whatwg.org/#set-a-cookie
pub const SetCookieOptions = struct {
    /// Cookie name (required)
    name: []const u8,
    /// Cookie value (required)
    value: []const u8,
    /// Expiration time as milliseconds timestamp (null = session cookie)
    expires: ?i64 = null,
    /// Domain attribute (null = host-only cookie)
    domain: ?[]const u8 = null,
    /// Path attribute (default = "/")
    path: []const u8 = "/",
    /// SameSite attribute (default = strict)
    same_site: SameSite = .strict,
    /// Whether this is a partitioned cookie
    partitioned: bool = false,
    /// Partition key for partitioned cookies
    partition_key: ?PartitionKey = null,
};

/// Options for deleting a cookie
/// https://cookiestore.spec.whatwg.org/#delete-a-cookie
pub const DeleteCookieOptions = struct {
    /// Cookie name (required)
    name: []const u8,
    /// Domain attribute (null = match any)
    domain: ?[]const u8 = null,
    /// Path attribute (default = "/")
    path: []const u8 = "/",
    /// Whether this is a partitioned cookie
    partitioned: bool = false,
};

/// Query cookies algorithm
/// https://cookiestore.spec.whatwg.org/#query-cookies
///
/// Returns a list of CookieListItems matching the criteria.
/// HttpOnly cookies are automatically filtered out (non-HTTP API).
pub fn queryCookies(
    allocator: std.mem.Allocator,
    jar: *CookieJar,
    url_host: []const u8,
    url_path: []const u8,
    name: ?[]const u8,
) !std.ArrayListUnmanaged(CookieListItem) {
    var result = std.ArrayListUnmanaged(CookieListItem){};
    errdefer {
        for (result.items) |*item| item.deinit();
        result.deinit(allocator);
    }

    // Normalize name if provided
    const normalized_name = if (name) |n| normalizeCookieNameOrValue(n) else null;

    // Retrieve cookies from jar (non-HTTP API, so HttpOnly filtered out)
    var cookies = try jar.retrieve(.{
        .host = url_host,
        .path = url_path,
        .is_http = false, // CookieStore API is non-HTTP
        .is_secure = true, // Assume secure context (required by spec)
        .same_site_context = .same_site,
        .name = normalized_name,
    });
    defer {
        for (cookies.items) |*c| c.deinit();
        cookies.deinit(allocator);
    }

    // Convert to CookieListItems
    for (cookies.items) |cookie| {
        // Filter by name if specified
        if (normalized_name) |n| {
            const cookie_name = normalizeCookieNameOrValue(cookie.name);
            if (!std.mem.eql(u8, cookie_name, n)) {
                continue;
            }
        }

        const item = try createCookieListItem(allocator, cookie);
        try result.append(allocator, item);
    }

    return result;
}

/// Set a cookie algorithm
/// https://cookiestore.spec.whatwg.org/#set-a-cookie
///
/// Creates and stores a cookie with all validation steps.
pub fn setCookie(
    allocator: std.mem.Allocator,
    jar: *CookieJar,
    url_host: []const u8,
    options: SetCookieOptions,
) !void {
    // Step 1-2: Normalize name and value
    const name = normalizeCookieNameOrValue(options.name);
    const value = normalizeCookieNameOrValue(options.value);

    // Step 3: Validate name and value characters
    validation.validateNameValue(name, value) catch {
        return CookieError.ValidationError;
    };

    // Step 6: Check reserved prefixes in name
    validation.validateReservedPrefix(name) catch {
        return CookieError.ValidationError;
    };

    // Steps 7-9: Size validation is in validateNameValue

    // Step 10: Get host
    const host = url_host;

    // Step 11: Domain validation
    var cookie_domain: ?[]const u8 = null;
    var host_only = true;

    if (options.domain) |domain| {
        // Domain must not start with dot
        validation.validateDomain(domain) catch {
            return CookieError.DomainError;
        };

        // Check __Host- prefix - cannot have domain
        if (validation.hasHostPrefix(name)) {
            return CookieError.ValidationError;
        }

        // Validate domain is a registrable domain suffix
        if (!try domain_matching.isRegistrableDomainSuffixOrEqual(allocator, host, domain)) {
            return CookieError.DomainError;
        }

        cookie_domain = domain;
        host_only = false;
    }

    // Step 12: Expires handling (already passed in options)

    // Step 13-16: Path validation
    var path = options.path;
    if (path.len == 0) {
        path = domain_matching.getDefaultPath(url_host);
    }

    validation.validatePath(path) catch {
        return CookieError.PathError;
    };

    // Check __Host- prefix - path must be "/"
    if (validation.hasHostPrefix(name) and !std.mem.eql(u8, path, "/")) {
        return CookieError.ValidationError;
    }

    // Step 17: Always Secure (CookieStore requires SecureContext)
    const secure = true;

    // Step 18: SameSite handling
    const same_site = options.same_site;

    // SameSite=None requires Secure
    if (same_site == .none and !secure) {
        return CookieError.SecurityError;
    }

    // Step 19: Partitioned handling
    const partitioned = options.partitioned;

    // Create the cookie
    var cookie = try Cookie.init(allocator, name, value);
    errdefer cookie.deinit();

    cookie.secure = secure;
    cookie.same_site = same_site;
    cookie.host_only = host_only;
    cookie.expiry_time = options.expires;

    if (cookie_domain) |d| {
        try cookie.setDomain(d);
    }

    if (!std.mem.eql(u8, path, "/")) {
        try cookie.setPath(path);
    }

    if (partitioned) {
        if (options.partition_key) |pk| {
            try cookie.setPartitionKey(pk);
        }
    }

    // Store the cookie
    try jar.store(cookie);

    // Clean up our temporary cookie (jar clones it)
    cookie.deinit();
}

/// Delete a cookie algorithm
/// https://cookiestore.spec.whatwg.org/#delete-a-cookie
///
/// Deletes a cookie by setting it with an expired date.
pub fn deleteCookie(
    allocator: std.mem.Allocator,
    jar: *CookieJar,
    url_host: []const u8,
    options: DeleteCookieOptions,
) !void {
    // Step 1: Get earliest representable date (epoch - 1 year for safety)
    const expires: i64 = 0; // Unix epoch = Jan 1, 1970 = definitely expired

    // Step 2: Normalize name
    const name = normalizeCookieNameOrValue(options.name);

    // Step 3: Value is empty for deletion
    var value: []const u8 = "";

    // Step 4: If name is empty, value must be non-empty
    if (name.len == 0) {
        value = "deleted";
    }

    // Step 5: Set cookie with expired date (this will cause deletion)
    try setCookie(allocator, jar, url_host, .{
        .name = name,
        .value = value,
        .expires = expires,
        .domain = options.domain,
        .path = options.path,
        .same_site = .strict,
        .partitioned = options.partitioned,
    });
}

/// Create a CookieListItem from a Cookie
/// https://cookiestore.spec.whatwg.org/#create-a-cookielistitem
pub fn createCookieListItem(allocator: std.mem.Allocator, cookie: Cookie) !CookieListItem {
    // Step 1: UTF-8 decode name (already UTF-8 in Zig)
    // Step 2: UTF-8 decode value (already UTF-8 in Zig)
    // Step 3: Return the item
    return CookieListItem.init(allocator, cookie.name, cookie.value);
}

/// Normalize a cookie name or value
/// https://cookiestore.spec.whatwg.org/#normalize-a-cookie-name-or-value
///
/// Per the spec, this is currently the identity function (no transformation).
pub fn normalizeCookieNameOrValue(input: []const u8) []const u8 {
    return input;
}

// ============================================================================
// Tests
// ============================================================================

test "queryCookies - basic" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    // Add a cookie directly
    var cookie = try Cookie.init(allocator, "session", "abc123");
    defer cookie.deinit();
    try cookie.setDomain("example.com");
    try jar.store(cookie);

    // Query
    var items = try queryCookies(allocator, &jar, "example.com", "/", null);
    defer {
        for (items.items) |*item| item.deinit();
        items.deinit(allocator);
    }

    try std.testing.expectEqual(@as(usize, 1), items.items.len);
    try std.testing.expectEqualStrings("session", items.items[0].name);
    try std.testing.expectEqualStrings("abc123", items.items[0].value);
}

test "queryCookies - with name filter" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    // Add cookies
    var cookie1 = try Cookie.init(allocator, "a", "1");
    defer cookie1.deinit();
    try cookie1.setDomain("example.com");
    try jar.store(cookie1);

    var cookie2 = try Cookie.init(allocator, "b", "2");
    defer cookie2.deinit();
    try cookie2.setDomain("example.com");
    try jar.store(cookie2);

    // Query with name filter
    var items = try queryCookies(allocator, &jar, "example.com", "/", "a");
    defer {
        for (items.items) |*item| item.deinit();
        items.deinit(allocator);
    }

    try std.testing.expectEqual(@as(usize, 1), items.items.len);
    try std.testing.expectEqualStrings("a", items.items[0].name);
}

test "setCookie - basic" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    try setCookie(allocator, &jar, "example.com", .{
        .name = "test",
        .value = "value",
    });

    try std.testing.expectEqual(@as(usize, 1), jar.count());
}

test "setCookie - with domain" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    try setCookie(allocator, &jar, "www.example.com", .{
        .name = "test",
        .value = "value",
        .domain = "example.com",
    });

    // Should match subdomain
    var items = try queryCookies(allocator, &jar, "sub.example.com", "/", null);
    defer {
        for (items.items) |*item| item.deinit();
        items.deinit(allocator);
    }

    try std.testing.expectEqual(@as(usize, 1), items.items.len);
}

test "setCookie - __Host- prefix validation" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    // __Host- with domain should fail
    const result1 = setCookie(allocator, &jar, "example.com", .{
        .name = "__Host-token",
        .value = "abc",
        .domain = "example.com",
    });
    try std.testing.expectError(CookieError.ValidationError, result1);

    // __Host- with non-root path should fail
    const result2 = setCookie(allocator, &jar, "example.com", .{
        .name = "__Host-token",
        .value = "abc",
        .path = "/app",
    });
    try std.testing.expectError(CookieError.ValidationError, result2);

    // __Host- with correct settings should work
    try setCookie(allocator, &jar, "example.com", .{
        .name = "__Host-token",
        .value = "abc",
        .path = "/",
    });

    try std.testing.expectEqual(@as(usize, 1), jar.count());
}

test "setCookie - invalid characters" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    // Semicolon in name
    const result1 = setCookie(allocator, &jar, "example.com", .{
        .name = "bad;name",
        .value = "value",
    });
    try std.testing.expectError(CookieError.ValidationError, result1);

    // Semicolon in value
    const result2 = setCookie(allocator, &jar, "example.com", .{
        .name = "name",
        .value = "bad;value",
    });
    try std.testing.expectError(CookieError.ValidationError, result2);
}

test "deleteCookie - basic" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    // Add a cookie
    try setCookie(allocator, &jar, "example.com", .{
        .name = "session",
        .value = "abc",
    });
    try std.testing.expectEqual(@as(usize, 1), jar.count());

    // Delete it
    try deleteCookie(allocator, &jar, "example.com", .{
        .name = "session",
    });

    // Should be gone (expired cookies are not stored)
    try std.testing.expectEqual(@as(usize, 0), jar.count());
}

test "createCookieListItem" {
    const allocator = std.testing.allocator;

    var cookie = try Cookie.init(allocator, "name", "value");
    defer cookie.deinit();

    var item = try createCookieListItem(allocator, cookie);
    defer item.deinit();

    try std.testing.expectEqualStrings("name", item.name);
    try std.testing.expectEqualStrings("value", item.value);
}

test "normalizeCookieNameOrValue" {
    // Currently identity function
    try std.testing.expectEqualStrings("test", normalizeCookieNameOrValue("test"));
    try std.testing.expectEqualStrings("", normalizeCookieNameOrValue(""));
}
