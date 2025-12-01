//! Mock WorkerLocation for Service Workers
//!
//! TODO(html-spec): Replace this mock with real HTML WorkerLocation
//! when the HTML specification workers section is implemented.
//! See: https://html.spec.whatwg.org/multipage/workers.html#workerlocation
//!
//! WorkerLocation provides URL information for the worker's script.
//! This mock implements the readonly URL-like properties per the HTML spec.
//!
//! WebIDL:
//! ```idl
//! [Exposed=Worker]
//! interface WorkerLocation {
//!   stringifier readonly attribute USVString href;
//!   readonly attribute USVString origin;
//!   readonly attribute USVString protocol;
//!   readonly attribute USVString host;
//!   readonly attribute USVString hostname;
//!   readonly attribute USVString port;
//!   readonly attribute USVString pathname;
//!   readonly attribute USVString search;
//!   readonly attribute USVString hash;
//! };
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Mock WorkerLocation interface.
///
/// Provides URL components for the worker's script URL.
/// All properties are readonly and derived from the script URL.
pub const WorkerLocation = struct {
    allocator: Allocator,

    /// The complete URL (href).
    href: []const u8,

    /// The origin (scheme + host + port).
    origin: []const u8,

    /// The protocol/scheme with trailing colon (e.g., "https:").
    protocol: []const u8,

    /// The host (hostname + port if non-default).
    host: []const u8,

    /// The hostname only.
    hostname: []const u8,

    /// The port as string (empty if default).
    port: []const u8,

    /// The pathname starting with /.
    pathname: []const u8,

    /// The query string including ? (empty if none).
    search: []const u8,

    /// The fragment including # (empty if none).
    hash: []const u8,

    const Self = @This();

    /// Create a WorkerLocation from a URL string.
    ///
    /// Parses the URL and extracts all components.
    /// This is a simplified parser - assumes well-formed URLs.
    pub fn init(allocator: Allocator, url: []const u8) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        // Store full href
        const href = try allocator.dupe(u8, url);
        errdefer allocator.free(href);

        // Parse scheme
        const scheme_end = std.mem.indexOf(u8, url, "://") orelse {
            allocator.free(href);
            allocator.destroy(self);
            return error.InvalidUrl;
        };
        const scheme = url[0..scheme_end];

        // Protocol includes the colon
        const protocol = try std.fmt.allocPrint(allocator, "{s}:", .{scheme});
        errdefer allocator.free(protocol);

        // Parse authority (between :// and first / or end)
        const after_scheme = url[scheme_end + 3 ..];
        const path_start = std.mem.indexOfAny(u8, after_scheme, "/?#") orelse after_scheme.len;
        const authority = after_scheme[0..path_start];

        // Parse hostname and port from authority
        var hostname_str: []const u8 = undefined;
        var port_str: []const u8 = "";

        if (std.mem.lastIndexOf(u8, authority, ":")) |colon_pos| {
            const after_colon = authority[colon_pos + 1 ..];
            // Check if it looks like a port number
            if (std.fmt.parseInt(u16, after_colon, 10)) |_| {
                hostname_str = authority[0..colon_pos];
                port_str = after_colon;
            } else |_| {
                // Not a port, probably IPv6
                hostname_str = authority;
            }
        } else {
            hostname_str = authority;
        }

        const hostname = try allocator.dupe(u8, hostname_str);
        errdefer allocator.free(hostname);

        const port = try allocator.dupe(u8, port_str);
        errdefer allocator.free(port);

        // Host is hostname:port or just hostname
        const host = if (port_str.len > 0)
            try std.fmt.allocPrint(allocator, "{s}:{s}", .{ hostname_str, port_str })
        else
            try allocator.dupe(u8, hostname_str);
        errdefer allocator.free(host);

        // Origin is scheme://host
        const origin = try std.fmt.allocPrint(allocator, "{s}://{s}", .{ scheme, host });
        errdefer allocator.free(origin);

        // Parse pathname, search, hash
        const rest = after_scheme[path_start..];

        var pathname_end = rest.len;
        var search_start = rest.len;
        var search_end = rest.len;
        var hash_start = rest.len;

        if (std.mem.indexOf(u8, rest, "#")) |hash_pos| {
            hash_start = hash_pos;
            pathname_end = @min(pathname_end, hash_pos);
            search_end = @min(search_end, hash_pos);
        }

        if (std.mem.indexOf(u8, rest, "?")) |query_pos| {
            if (query_pos < hash_start) {
                search_start = query_pos;
                pathname_end = @min(pathname_end, query_pos);
            }
        }

        const pathname_raw = rest[0..pathname_end];
        const pathname = if (pathname_raw.len == 0)
            try allocator.dupe(u8, "/")
        else
            try allocator.dupe(u8, pathname_raw);
        errdefer allocator.free(pathname);

        const search = if (search_start < search_end)
            try allocator.dupe(u8, rest[search_start..search_end])
        else
            try allocator.dupe(u8, "");
        errdefer allocator.free(search);

        const hash = if (hash_start < rest.len)
            try allocator.dupe(u8, rest[hash_start..])
        else
            try allocator.dupe(u8, "");

        self.* = .{
            .allocator = allocator,
            .href = href,
            .origin = origin,
            .protocol = protocol,
            .host = host,
            .hostname = hostname,
            .port = port,
            .pathname = pathname,
            .search = search,
            .hash = hash,
        };

        return self;
    }

    /// Create with explicit components (for testing).
    pub fn initWithComponents(
        allocator: Allocator,
        scheme: []const u8,
        hostname: []const u8,
        port_num: ?u16,
        pathname: []const u8,
        search: []const u8,
        hash: []const u8,
    ) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        const protocol = try std.fmt.allocPrint(allocator, "{s}:", .{scheme});
        errdefer allocator.free(protocol);

        const hostname_owned = try allocator.dupe(u8, hostname);
        errdefer allocator.free(hostname_owned);

        const port = if (port_num) |p|
            try std.fmt.allocPrint(allocator, "{d}", .{p})
        else
            try allocator.dupe(u8, "");
        errdefer allocator.free(port);

        const host = if (port_num) |p|
            try std.fmt.allocPrint(allocator, "{s}:{d}", .{ hostname, p })
        else
            try allocator.dupe(u8, hostname);
        errdefer allocator.free(host);

        const origin = try std.fmt.allocPrint(allocator, "{s}://{s}", .{ scheme, host });
        errdefer allocator.free(origin);

        const pathname_owned = try allocator.dupe(u8, pathname);
        errdefer allocator.free(pathname_owned);

        const search_owned = try allocator.dupe(u8, search);
        errdefer allocator.free(search_owned);

        const hash_owned = try allocator.dupe(u8, hash);
        errdefer allocator.free(hash_owned);

        // Build href
        const href = try std.fmt.allocPrint(allocator, "{s}{s}{s}{s}", .{
            origin,
            pathname_owned,
            search_owned,
            hash_owned,
        });

        self.* = .{
            .allocator = allocator,
            .href = href,
            .origin = origin,
            .protocol = protocol,
            .host = host,
            .hostname = hostname_owned,
            .port = port,
            .pathname = pathname_owned,
            .search = search_owned,
            .hash = hash_owned,
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.href);
        self.allocator.free(self.origin);
        self.allocator.free(self.protocol);
        self.allocator.free(self.host);
        self.allocator.free(self.hostname);
        self.allocator.free(self.port);
        self.allocator.free(self.pathname);
        self.allocator.free(self.search);
        self.allocator.free(self.hash);
        self.allocator.destroy(self);
    }

    /// Stringifier - returns href.
    pub fn toString(self: *const Self) []const u8 {
        return self.href;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "WorkerLocation.init parses simple URL" {
    const allocator = std.testing.allocator;

    const loc = try WorkerLocation.init(allocator, "https://example.com/sw.js");
    defer loc.deinit();

    try std.testing.expectEqualStrings("https://example.com/sw.js", loc.href);
    try std.testing.expectEqualStrings("https://example.com", loc.origin);
    try std.testing.expectEqualStrings("https:", loc.protocol);
    try std.testing.expectEqualStrings("example.com", loc.host);
    try std.testing.expectEqualStrings("example.com", loc.hostname);
    try std.testing.expectEqualStrings("", loc.port);
    try std.testing.expectEqualStrings("/sw.js", loc.pathname);
    try std.testing.expectEqualStrings("", loc.search);
    try std.testing.expectEqualStrings("", loc.hash);
}

test "WorkerLocation.init parses URL with port" {
    const allocator = std.testing.allocator;

    const loc = try WorkerLocation.init(allocator, "https://example.com:8080/worker/sw.js");
    defer loc.deinit();

    try std.testing.expectEqualStrings("https://example.com:8080", loc.origin);
    try std.testing.expectEqualStrings("example.com:8080", loc.host);
    try std.testing.expectEqualStrings("example.com", loc.hostname);
    try std.testing.expectEqualStrings("8080", loc.port);
    try std.testing.expectEqualStrings("/worker/sw.js", loc.pathname);
}

test "WorkerLocation.init parses URL with query and hash" {
    const allocator = std.testing.allocator;

    const loc = try WorkerLocation.init(allocator, "https://example.com/sw.js?version=1#section");
    defer loc.deinit();

    try std.testing.expectEqualStrings("/sw.js", loc.pathname);
    try std.testing.expectEqualStrings("?version=1", loc.search);
    try std.testing.expectEqualStrings("#section", loc.hash);
}

test "WorkerLocation.init handles root path" {
    const allocator = std.testing.allocator;

    const loc = try WorkerLocation.init(allocator, "https://example.com");
    defer loc.deinit();

    try std.testing.expectEqualStrings("/", loc.pathname);
}

test "WorkerLocation.initWithComponents" {
    const allocator = std.testing.allocator;

    const loc = try WorkerLocation.initWithComponents(
        allocator,
        "https",
        "example.com",
        8080,
        "/sw.js",
        "?v=1",
        "#top",
    );
    defer loc.deinit();

    try std.testing.expectEqualStrings("https://example.com:8080/sw.js?v=1#top", loc.href);
    try std.testing.expectEqualStrings("https://example.com:8080", loc.origin);
    try std.testing.expectEqualStrings("8080", loc.port);
}

test "WorkerLocation.toString returns href" {
    const allocator = std.testing.allocator;

    const loc = try WorkerLocation.init(allocator, "https://example.com/sw.js");
    defer loc.deinit();

    try std.testing.expectEqualStrings(loc.href, loc.toString());
}
