//! libcurl Cookie Manager
//!
//! Provides unified cookie storage using libcurl's shared cookie engine.
//! This enables cookies to be shared between Fetch API, WebSocket, and CookieStore API.
//!
//! Reference: https://curl.se/libcurl/c/CURLOPT_SHARE.html
//! Reference: https://curl.se/libcurl/c/CURLOPT_COOKIELIST.html

const std = @import("std");
const Allocator = std.mem.Allocator;
const curl = @import("curl_ffi.zig");

/// Error types for cookie operations
pub const CookieError = error{
    ShareInitFailed,
    ShareSetoptFailed,
    EasyInitFailed,
    CookieNotFound,
    InvalidCookieFormat,
    OutOfMemory,
};

/// Represents a parsed HTTP cookie
/// Matches CookieListItem from CookieStore API spec
pub const Cookie = struct {
    /// Cookie name
    name: []const u8,

    /// Cookie value
    value: []const u8,

    /// Domain attribute (with leading dot for subdomain inclusion)
    domain: []const u8,

    /// Path attribute
    path: []const u8,

    /// Expiry time as Unix timestamp (null = session cookie)
    expires: ?i64,

    /// Secure attribute (HTTPS only)
    secure: bool,

    /// SameSite attribute
    same_site: SameSite,

    /// Whether cookie was set with HttpOnly
    /// Note: libcurl Netscape format doesn't include this, default to false
    http_only: bool,

    /// Allocator used for string storage
    allocator: Allocator,

    pub const SameSite = enum {
        strict,
        lax,
        none,
    };

    /// Free all allocated memory
    pub fn deinit(self: *Cookie) void {
        self.allocator.free(self.name);
        self.allocator.free(self.value);
        self.allocator.free(self.domain);
        self.allocator.free(self.path);
    }

    /// Create a deep copy of the cookie
    pub fn clone(self: Cookie, allocator: Allocator) !Cookie {
        return Cookie{
            .name = try allocator.dupe(u8, self.name),
            .value = try allocator.dupe(u8, self.value),
            .domain = try allocator.dupe(u8, self.domain),
            .path = try allocator.dupe(u8, self.path),
            .expires = self.expires,
            .secure = self.secure,
            .same_site = self.same_site,
            .http_only = self.http_only,
            .allocator = allocator,
        };
    }
};

/// Thread-safe cookie manager using libcurl's shared cookie engine.
/// Provides unified cookie storage for Fetch API, WebSocket, and CookieStore API.
pub const CurlCookieManager = struct {
    /// Shared handle for cookie storage across multiple CURL handles
    share_handle: *curl.CURLSH,

    /// Dedicated CURL handle for cookie manipulation (get/set/delete)
    /// This handle is never used for actual HTTP requests
    cookie_handle: *curl.CURL,

    /// Allocator for internal allocations
    allocator: Allocator,

    /// Mutex for thread-safe cookie operations
    mutex: std.Thread.Mutex,

    /// Whether to persist cookies to disk
    persist_path: ?[]const u8,

    /// Initialize a new CurlCookieManager
    /// @param allocator: Allocator for internal use
    /// @param persist_path: Optional file path to persist cookies (null = memory only)
    pub fn init(allocator: Allocator, persist_path: ?[]const u8) !*CurlCookieManager {
        const self = try allocator.create(CurlCookieManager);
        errdefer allocator.destroy(self);

        // Initialize share handle
        const share = curl.share_init() orelse return error.ShareInitFailed;
        errdefer _ = curl.share_cleanup(share);

        // Enable cookie sharing
        const result = curl.share_setopt(share, curl.CURLSHOPT_SHARE, curl.CURL_LOCK_DATA_COOKIE);
        if (result != curl.CURLSHE_OK) return error.ShareSetoptFailed;

        // Initialize dedicated cookie handle
        const cookie_handle = curl.easy_init() orelse return error.EasyInitFailed;
        errdefer curl.easy_cleanup(cookie_handle);

        // Attach share handle
        _ = curl.easy_setopt(cookie_handle, curl.CURLOPT_SHARE, share);

        // Enable cookie engine
        if (persist_path) |path| {
            // Need null-terminated string for C API
            const path_z = try allocator.dupeZ(u8, path);
            defer allocator.free(path_z);
            // Read from file on init, write on cleanup
            _ = curl.easy_setopt(cookie_handle, curl.CURLOPT_COOKIEFILE, path_z.ptr);
            _ = curl.easy_setopt(cookie_handle, curl.CURLOPT_COOKIEJAR, path_z.ptr);
        } else {
            // Memory-only mode (empty string enables engine)
            _ = curl.easy_setopt(cookie_handle, curl.CURLOPT_COOKIEFILE, "");
        }

        self.* = .{
            .share_handle = share,
            .cookie_handle = cookie_handle,
            .allocator = allocator,
            .mutex = .{},
            .persist_path = if (persist_path) |p| try allocator.dupe(u8, p) else null,
        };

        return self;
    }

    /// Clean up all resources
    pub fn deinit(self: *CurlCookieManager) void {
        // Flush cookies to file if persisting
        if (self.persist_path != null) {
            _ = curl.easy_setopt(self.cookie_handle, curl.CURLOPT_COOKIELIST, "FLUSH");
        }

        curl.easy_cleanup(self.cookie_handle);
        _ = curl.share_cleanup(self.share_handle);

        if (self.persist_path) |path| {
            self.allocator.free(path);
        }

        self.allocator.destroy(self);
    }

    /// Attach this cookie manager to a CURL easy handle
    /// Call this before performing HTTP requests to share cookies
    pub fn attachToHandle(self: *CurlCookieManager, handle: *curl.CURL) void {
        _ = curl.easy_setopt(handle, curl.CURLOPT_SHARE, self.share_handle);
        _ = curl.easy_setopt(handle, curl.CURLOPT_COOKIEFILE, "");
    }

    /// Flush cookies to disk (if persistence enabled)
    pub fn flush(self: *CurlCookieManager) void {
        if (self.persist_path != null) {
            self.mutex.lock();
            defer self.mutex.unlock();
            _ = curl.easy_setopt(self.cookie_handle, curl.CURLOPT_COOKIELIST, "FLUSH");
        }
    }

    /// Clear all session cookies (cookies without expiry)
    pub fn clearSessionCookies(self: *CurlCookieManager) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        _ = curl.easy_setopt(self.cookie_handle, curl.CURLOPT_COOKIELIST, "SESS");
    }

    /// Clear all cookies
    pub fn clearAll(self: *CurlCookieManager) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        _ = curl.easy_setopt(self.cookie_handle, curl.CURLOPT_COOKIELIST, "ALL");
    }

    /// Get a single cookie by name and optional URL context
    /// Returns null if cookie not found
    pub fn get(self: *CurlCookieManager, name: []const u8, url: ?[]const u8) !?Cookie {
        const cookies = try self.getAll(url);
        defer {
            for (cookies) |*cookie| {
                var c = cookie.*;
                c.deinit();
            }
            self.allocator.free(cookies);
        }

        for (cookies) |cookie| {
            if (std.mem.eql(u8, cookie.name, name)) {
                return try cookie.clone(self.allocator);
            }
        }
        return null;
    }

    /// Get all cookies, optionally filtered by URL
    /// Caller owns returned slice and must deinit each cookie
    pub fn getAll(self: *CurlCookieManager, url: ?[]const u8) ![]Cookie {
        _ = url; // TODO: Filter by URL domain/path matching

        self.mutex.lock();
        defer self.mutex.unlock();

        var cookie_list: ?*curl.curl_slist = null;
        const result = curl.easy_getinfo(self.cookie_handle, curl.CURLINFO_COOKIELIST, &cookie_list);
        if (result != curl.CURLE_OK) {
            return &[_]Cookie{};
        }
        defer curl.slist_free_all(cookie_list);

        // Count cookies
        const count = curl.slistCount(cookie_list);
        if (count == 0) {
            return &[_]Cookie{};
        }

        // Parse all cookies
        var cookies = try self.allocator.alloc(Cookie, count);
        errdefer self.allocator.free(cookies);

        var iter = curl.slistIterator(cookie_list);
        var i: usize = 0;
        while (iter.next()) |line| {
            cookies[i] = parseNetscapeCookie(self.allocator, line) catch continue;
            i += 1;
        }

        // Shrink if some failed to parse
        if (i < count) {
            cookies = try self.allocator.realloc(cookies, i);
        }

        return cookies;
    }

    /// Set a cookie
    pub fn set(self: *CurlCookieManager, cookie: Cookie) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const cookie_str = try formatSetCookieString(self.allocator, cookie);
        defer self.allocator.free(cookie_str);

        // Need null-terminated string
        const cookie_z = try self.allocator.dupeZ(u8, cookie_str);
        defer self.allocator.free(cookie_z);

        _ = curl.easy_setopt(self.cookie_handle, curl.CURLOPT_COOKIELIST, cookie_z.ptr);
    }

    /// Delete a cookie by name, domain, and path
    pub fn delete(self: *CurlCookieManager, name: []const u8, domain: ?[]const u8, path: ?[]const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const delete_str = try formatDeleteCookie(
            self.allocator,
            name,
            domain orelse "",
            path orelse "/",
        );
        defer self.allocator.free(delete_str);

        // Need null-terminated string
        const delete_z = try self.allocator.dupeZ(u8, delete_str);
        defer self.allocator.free(delete_z);

        _ = curl.easy_setopt(self.cookie_handle, curl.CURLOPT_COOKIELIST, delete_z.ptr);
    }
};

/// Parse a cookie from libcurl's Netscape format
/// Format: domain\tsubdomain_flag\tpath\tsecure\texpiry\tname\tvalue
///
/// Example: ".example.com\tTRUE\t/\tFALSE\t0\tsession_id\tabc123"
///
/// Fields:
/// 1. domain - Cookie domain (leading dot = include subdomains)
/// 2. subdomain_flag - "TRUE" if domain has leading dot
/// 3. path - Cookie path
/// 4. secure - "TRUE" if HTTPS only
/// 5. expiry - Unix timestamp (0 = session cookie)
/// 6. name - Cookie name
/// 7. value - Cookie value
pub fn parseNetscapeCookie(allocator: Allocator, line: []const u8) !Cookie {
    var fields: [7][]const u8 = undefined;
    var field_count: usize = 0;

    var iter = std.mem.splitScalar(u8, line, '\t');
    while (iter.next()) |field| {
        if (field_count >= 7) break;
        fields[field_count] = field;
        field_count += 1;
    }

    if (field_count < 7) {
        return error.InvalidCookieFormat;
    }

    const domain = fields[0];
    // fields[1] is subdomain flag, derived from domain leading dot
    const path_field = fields[2];
    const secure_str = fields[3];
    const expiry_str = fields[4];
    const name = fields[5];
    const value = fields[6];

    // Parse secure flag
    const secure = std.mem.eql(u8, secure_str, "TRUE");

    // Parse expiry (0 = session cookie)
    const expiry_int = std.fmt.parseInt(i64, expiry_str, 10) catch 0;
    const expires: ?i64 = if (expiry_int == 0) null else expiry_int;

    return Cookie{
        .name = try allocator.dupe(u8, name),
        .value = try allocator.dupe(u8, value),
        .domain = try allocator.dupe(u8, domain),
        .path = try allocator.dupe(u8, path_field),
        .expires = expires,
        .secure = secure,
        .same_site = .lax, // Default, not in Netscape format
        .http_only = false, // Not in Netscape format
        .allocator = allocator,
    };
}

/// Format a Cookie as Set-Cookie header string for CURLOPT_COOKIELIST
pub fn formatSetCookieString(allocator: Allocator, cookie: Cookie) ![]u8 {
    var buf = std.ArrayListUnmanaged(u8){};
    errdefer buf.deinit(allocator);

    const writer = buf.writer(allocator);

    try writer.print("Set-Cookie: {s}={s}", .{ cookie.name, cookie.value });

    if (cookie.domain.len > 0) {
        try writer.print("; Domain={s}", .{cookie.domain});
    }

    if (cookie.path.len > 0) {
        try writer.print("; Path={s}", .{cookie.path});
    }

    if (cookie.expires) |exp| {
        // Use Expires with HTTP date format
        try writer.print("; Expires={d}", .{exp});
    }

    if (cookie.secure) {
        try writer.writeAll("; Secure");
    }

    if (cookie.http_only) {
        try writer.writeAll("; HttpOnly");
    }

    switch (cookie.same_site) {
        .strict => try writer.writeAll("; SameSite=Strict"),
        .lax => try writer.writeAll("; SameSite=Lax"),
        .none => try writer.writeAll("; SameSite=None"),
    }

    return buf.toOwnedSlice(allocator);
}

/// Format a cookie for deletion via CURLOPT_COOKIELIST
/// Uses Netscape format with expiry in the past
pub fn formatDeleteCookie(allocator: Allocator, name: []const u8, domain: []const u8, path: []const u8) ![]u8 {
    // Netscape format: domain\tflag\tpath\tsecure\texpiry\tname\tvalue
    // Setting expiry to 1 (past) effectively deletes it
    var buf = std.ArrayListUnmanaged(u8){};
    errdefer buf.deinit(allocator);

    const writer = buf.writer(allocator);
    const flag = if (domain.len > 0 and domain[0] == '.') "TRUE" else "FALSE";

    try writer.print("{s}\t{s}\t{s}\tFALSE\t1\t{s}\t", .{ domain, flag, path, name });

    return buf.toOwnedSlice(allocator);
}

// =============================================================================
// Tests
// =============================================================================

test "Cookie - parse Netscape format" {
    const allocator = std.testing.allocator;
    const line = ".example.com\tTRUE\t/\tTRUE\t1735689600\tsession_id\tabc123";

    var cookie = try parseNetscapeCookie(allocator, line);
    defer cookie.deinit();

    try std.testing.expectEqualStrings(".example.com", cookie.domain);
    try std.testing.expectEqualStrings("/", cookie.path);
    try std.testing.expectEqualStrings("session_id", cookie.name);
    try std.testing.expectEqualStrings("abc123", cookie.value);
    try std.testing.expect(cookie.secure);
    try std.testing.expectEqual(@as(?i64, 1735689600), cookie.expires);
}

test "Cookie - parse session cookie (expiry 0)" {
    const allocator = std.testing.allocator;
    const line = "example.com\tFALSE\t/\tFALSE\t0\ttemp\tvalue";

    var cookie = try parseNetscapeCookie(allocator, line);
    defer cookie.deinit();

    try std.testing.expectEqual(@as(?i64, null), cookie.expires);
    try std.testing.expect(!cookie.secure);
}

test "Cookie - clone" {
    const allocator = std.testing.allocator;

    var original = Cookie{
        .name = try allocator.dupe(u8, "test"),
        .value = try allocator.dupe(u8, "value"),
        .domain = try allocator.dupe(u8, ".example.com"),
        .path = try allocator.dupe(u8, "/"),
        .expires = 1735689600,
        .secure = true,
        .same_site = .strict,
        .http_only = false,
        .allocator = allocator,
    };
    defer original.deinit();

    var cloned = try original.clone(allocator);
    defer cloned.deinit();

    try std.testing.expectEqualStrings(original.name, cloned.name);
    try std.testing.expectEqualStrings(original.value, cloned.value);
    try std.testing.expectEqual(original.expires, cloned.expires);
}

test "Cookie - format Set-Cookie string" {
    const allocator = std.testing.allocator;

    const cookie = Cookie{
        .name = "session",
        .value = "abc123",
        .domain = ".example.com",
        .path = "/app",
        .expires = null,
        .secure = true,
        .same_site = .strict,
        .http_only = true,
        .allocator = allocator,
    };

    const str = try formatSetCookieString(allocator, cookie);
    defer allocator.free(str);

    try std.testing.expect(std.mem.indexOf(u8, str, "Set-Cookie: session=abc123") != null);
    try std.testing.expect(std.mem.indexOf(u8, str, "Domain=.example.com") != null);
    try std.testing.expect(std.mem.indexOf(u8, str, "Path=/app") != null);
    try std.testing.expect(std.mem.indexOf(u8, str, "Secure") != null);
    try std.testing.expect(std.mem.indexOf(u8, str, "HttpOnly") != null);
    try std.testing.expect(std.mem.indexOf(u8, str, "SameSite=Strict") != null);
}

test "Cookie - format delete cookie" {
    const allocator = std.testing.allocator;

    const str = try formatDeleteCookie(allocator, "session", ".example.com", "/");
    defer allocator.free(str);

    try std.testing.expect(std.mem.indexOf(u8, str, ".example.com") != null);
    try std.testing.expect(std.mem.indexOf(u8, str, "TRUE") != null); // subdomain flag
    try std.testing.expect(std.mem.indexOf(u8, str, "\t1\t") != null); // expiry = 1
    try std.testing.expect(std.mem.indexOf(u8, str, "session") != null);
}

test "Cookie - invalid format returns error" {
    const allocator = std.testing.allocator;

    // Too few fields
    const result = parseNetscapeCookie(allocator, "domain\tpath");
    try std.testing.expectError(error.InvalidCookieFormat, result);
}

test "CurlCookieManager - lifecycle" {
    const allocator = std.testing.allocator;

    const manager = try CurlCookieManager.init(allocator, null);
    defer manager.deinit();

    // Basic operations should not crash
    manager.clearAll();
    manager.clearSessionCookies();
}

test "CurlCookieManager - set and get cookie" {
    const allocator = std.testing.allocator;

    const manager = try CurlCookieManager.init(allocator, null);
    defer manager.deinit();

    // Set a cookie
    const cookie = Cookie{
        .name = "test",
        .value = "value123",
        .domain = ".example.com",
        .path = "/",
        .expires = null,
        .secure = false,
        .same_site = .lax,
        .http_only = false,
        .allocator = allocator,
    };

    try manager.set(cookie);

    // Get it back
    const retrieved = try manager.get("test", null);
    if (retrieved) |*c| {
        var cookie_copy = c.*;
        defer cookie_copy.deinit();
        try std.testing.expectEqualStrings("test", cookie_copy.name);
        try std.testing.expectEqualStrings("value123", cookie_copy.value);
    }
}

test "CurlCookieManager - delete cookie" {
    const allocator = std.testing.allocator;

    const manager = try CurlCookieManager.init(allocator, null);
    defer manager.deinit();

    // Set a cookie
    const cookie = Cookie{
        .name = "to_delete",
        .value = "temp",
        .domain = ".example.com",
        .path = "/",
        .expires = null,
        .secure = false,
        .same_site = .lax,
        .http_only = false,
        .allocator = allocator,
    };

    try manager.set(cookie);
    try manager.delete("to_delete", ".example.com", "/");

    // Should be gone (or expired)
    const cookies = try manager.getAll(null);
    defer {
        for (cookies) |*c| {
            var cookie_copy = c.*;
            cookie_copy.deinit();
        }
        allocator.free(cookies);
    }

    // Cookie should be gone or have past expiry
    for (cookies) |c| {
        if (std.mem.eql(u8, c.name, "to_delete")) {
            // If still present, it should have expiry=1 (past)
            try std.testing.expect(c.expires != null and c.expires.? <= 1);
        }
    }
}
