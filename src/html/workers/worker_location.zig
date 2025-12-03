//! Worker Location
//!
//! Spec: HTML Standard § 10.1.2 The WorkerLocation interface
//! https://html.spec.whatwg.org/#workerlocation
//!
//! The WorkerLocation interface provides URL information about the worker's
//! script location, similar to the Location object for windows.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Worker Location implementation.
///
/// Spec: HTML Standard § 10.1.2
/// "The WorkerLocation interface represents the absolute URL of the script
/// executed by the Worker."
///
/// Unlike the window's Location object, WorkerLocation is read-only and
/// does not support navigation methods like assign(), replace(), or reload().
pub const WorkerLocation = struct {
    /// The full URL string
    href: []const u8,

    /// The protocol scheme (e.g., "https:")
    protocol: []const u8,

    /// The host (hostname:port or just hostname)
    host: []const u8,

    /// The hostname part
    hostname: []const u8,

    /// The port (empty string if default)
    port: []const u8,

    /// The pathname (e.g., "/path/to/worker.js")
    pathname: []const u8,

    /// The search/query string (includes "?")
    search: []const u8,

    /// The hash/fragment (includes "#")
    hash: []const u8,

    /// The origin
    origin: []const u8,

    /// Allocator
    allocator: Allocator,

    /// Create a WorkerLocation from a URL string.
    ///
    /// Spec: HTML Standard § 10.1.2
    /// "The href attribute must return the WorkerLocation object's
    /// associated WorkerGlobalScope object's url, serialized."
    pub fn init(allocator: Allocator, url: []const u8) !*WorkerLocation {
        const location = try allocator.create(WorkerLocation);
        errdefer allocator.destroy(location);

        // Parse the URL to extract components
        // For now, do a simple parse - production code should use proper URL parser
        const parsed = try parseUrl(allocator, url);

        location.* = .{
            .href = parsed.href,
            .protocol = parsed.protocol,
            .host = parsed.host,
            .hostname = parsed.hostname,
            .port = parsed.port,
            .pathname = parsed.pathname,
            .search = parsed.search,
            .hash = parsed.hash,
            .origin = parsed.origin,
            .allocator = allocator,
        };

        return location;
    }

    /// Clean up resources.
    pub fn deinit(self: *WorkerLocation) void {
        self.allocator.free(self.href);
        self.allocator.free(self.protocol);
        self.allocator.free(self.host);
        self.allocator.free(self.hostname);
        self.allocator.free(self.port);
        self.allocator.free(self.pathname);
        self.allocator.free(self.search);
        self.allocator.free(self.hash);
        self.allocator.free(self.origin);
        self.allocator.destroy(self);
    }

    /// Get the full URL.
    ///
    /// Spec: "The href attribute must return the WorkerLocation object's
    /// associated WorkerGlobalScope object's url, serialized."
    pub fn getHref(self: *const WorkerLocation) []const u8 {
        return self.href;
    }

    /// Get the protocol.
    ///
    /// Spec: "The protocol attribute must return the WorkerLocation object's
    /// url's scheme, followed by ":"."
    pub fn getProtocol(self: *const WorkerLocation) []const u8 {
        return self.protocol;
    }

    /// Get the host.
    ///
    /// Spec: "The host attribute must run these steps..."
    pub fn getHost(self: *const WorkerLocation) []const u8 {
        return self.host;
    }

    /// Get the hostname.
    ///
    /// Spec: "The hostname attribute must run these steps..."
    pub fn getHostname(self: *const WorkerLocation) []const u8 {
        return self.hostname;
    }

    /// Get the port.
    ///
    /// Spec: "The port attribute must run these steps..."
    pub fn getPort(self: *const WorkerLocation) []const u8 {
        return self.port;
    }

    /// Get the pathname.
    ///
    /// Spec: "The pathname attribute must return the result of URL
    /// path serializing the WorkerLocation object's url."
    pub fn getPathname(self: *const WorkerLocation) []const u8 {
        return self.pathname;
    }

    /// Get the search string.
    ///
    /// Spec: "The search attribute must run these steps..."
    pub fn getSearch(self: *const WorkerLocation) []const u8 {
        return self.search;
    }

    /// Get the hash.
    ///
    /// Spec: "The hash attribute must run these steps..."
    pub fn getHash(self: *const WorkerLocation) []const u8 {
        return self.hash;
    }

    /// Get the origin.
    ///
    /// Spec: "The origin attribute must return the serialization of the
    /// WorkerLocation object's url's origin."
    pub fn getOrigin(self: *const WorkerLocation) []const u8 {
        return self.origin;
    }

    /// Convert to string (returns href).
    pub fn toString(self: *const WorkerLocation) []const u8 {
        return self.href;
    }
};

/// Parsed URL components.
const ParsedUrl = struct {
    href: []const u8,
    protocol: []const u8,
    host: []const u8,
    hostname: []const u8,
    port: []const u8,
    pathname: []const u8,
    search: []const u8,
    hash: []const u8,
    origin: []const u8,
};

/// Parse a URL string into components.
/// This is a simplified parser - production should use src/url/.
fn parseUrl(allocator: Allocator, url: []const u8) !ParsedUrl {
    // Copy the full href
    const href = try allocator.dupe(u8, url);
    errdefer allocator.free(href);

    // Find protocol
    var protocol_end: usize = 0;
    if (std.mem.indexOf(u8, url, "://")) |idx| {
        protocol_end = idx + 1; // Include the ":"
    }
    const protocol = try allocator.dupe(u8, if (protocol_end > 0) url[0..protocol_end] else "");
    errdefer allocator.free(protocol);

    // Skip past "://"
    const after_protocol = if (std.mem.indexOf(u8, url, "://")) |idx| idx + 3 else 0;

    // Find path start
    const path_start = if (after_protocol > 0)
        (std.mem.indexOfPos(u8, url, after_protocol, "/") orelse url.len)
    else
        0;

    // Extract authority (host:port)
    const authority = if (after_protocol > 0 and path_start > after_protocol)
        url[after_protocol..path_start]
    else
        "";

    // Split authority into hostname and port
    var hostname_str: []const u8 = authority;
    var port_str: []const u8 = "";
    if (std.mem.lastIndexOf(u8, authority, ":")) |colon_idx| {
        // Make sure this isn't an IPv6 address
        if (std.mem.indexOf(u8, authority, "]") == null or std.mem.lastIndexOf(u8, authority, "]").? < colon_idx) {
            hostname_str = authority[0..colon_idx];
            port_str = authority[colon_idx + 1 ..];
        }
    }

    const hostname = try allocator.dupe(u8, hostname_str);
    errdefer allocator.free(hostname);

    const port = try allocator.dupe(u8, port_str);
    errdefer allocator.free(port);

    const host = try allocator.dupe(u8, authority);
    errdefer allocator.free(host);

    // Find search and hash
    var pathname_end = url.len;
    var search_start: ?usize = null;
    var hash_start: ?usize = null;

    if (std.mem.indexOf(u8, url[path_start..], "#")) |idx| {
        hash_start = path_start + idx;
        pathname_end = @min(pathname_end, hash_start.?);
    }
    if (std.mem.indexOf(u8, url[path_start..], "?")) |idx| {
        search_start = path_start + idx;
        pathname_end = @min(pathname_end, search_start.?);
    }

    // Extract pathname
    const pathname_slice = if (path_start < url.len) url[path_start..pathname_end] else "/";
    const pathname = try allocator.dupe(u8, if (pathname_slice.len > 0) pathname_slice else "/");
    errdefer allocator.free(pathname);

    // Extract search
    const search_slice = if (search_start) |s|
        (if (hash_start) |h| url[s..h] else url[s..])
    else
        "";
    const search = try allocator.dupe(u8, search_slice);
    errdefer allocator.free(search);

    // Extract hash
    const hash_slice = if (hash_start) |h| url[h..] else "";
    const hash = try allocator.dupe(u8, hash_slice);
    errdefer allocator.free(hash);

    // Build origin (protocol + "//" + host)
    const origin = if (protocol_end > 0) blk: {
        const origin_str = try std.fmt.allocPrint(allocator, "{s}//{s}", .{
            url[0..protocol_end],
            authority,
        });
        break :blk origin_str;
    } else try allocator.dupe(u8, "null");
    errdefer allocator.free(origin);

    return .{
        .href = href,
        .protocol = protocol,
        .host = host,
        .hostname = hostname,
        .port = port,
        .pathname = pathname,
        .search = search,
        .hash = hash,
        .origin = origin,
    };
}

test "WorkerLocation - basic URL parsing" {
    const allocator = std.testing.allocator;

    const location = try WorkerLocation.init(
        allocator,
        "https://example.com:8080/path/to/worker.js?query=value#fragment",
    );
    defer location.deinit();

    try std.testing.expectEqualStrings(
        "https://example.com:8080/path/to/worker.js?query=value#fragment",
        location.getHref(),
    );
    try std.testing.expectEqualStrings("https:", location.getProtocol());
    try std.testing.expectEqualStrings("example.com:8080", location.getHost());
    try std.testing.expectEqualStrings("example.com", location.getHostname());
    try std.testing.expectEqualStrings("8080", location.getPort());
    try std.testing.expectEqualStrings("/path/to/worker.js", location.getPathname());
    try std.testing.expectEqualStrings("?query=value", location.getSearch());
    try std.testing.expectEqualStrings("#fragment", location.getHash());
    try std.testing.expectEqualStrings("https://example.com:8080", location.getOrigin());
}

test "WorkerLocation - simple URL" {
    const allocator = std.testing.allocator;

    const location = try WorkerLocation.init(
        allocator,
        "https://example.com/worker.js",
    );
    defer location.deinit();

    try std.testing.expectEqualStrings("https://example.com/worker.js", location.getHref());
    try std.testing.expectEqualStrings("https:", location.getProtocol());
    try std.testing.expectEqualStrings("example.com", location.getHost());
    try std.testing.expectEqualStrings("example.com", location.getHostname());
    try std.testing.expectEqualStrings("", location.getPort());
    try std.testing.expectEqualStrings("/worker.js", location.getPathname());
    try std.testing.expectEqualStrings("", location.getSearch());
    try std.testing.expectEqualStrings("", location.getHash());
}

test "WorkerLocation - URL with query only" {
    const allocator = std.testing.allocator;

    const location = try WorkerLocation.init(
        allocator,
        "https://example.com/worker.js?name=test",
    );
    defer location.deinit();

    try std.testing.expectEqualStrings("/worker.js", location.getPathname());
    try std.testing.expectEqualStrings("?name=test", location.getSearch());
    try std.testing.expectEqualStrings("", location.getHash());
}

test "WorkerLocation - URL with hash only" {
    const allocator = std.testing.allocator;

    const location = try WorkerLocation.init(
        allocator,
        "https://example.com/worker.js#section",
    );
    defer location.deinit();

    try std.testing.expectEqualStrings("/worker.js", location.getPathname());
    try std.testing.expectEqualStrings("", location.getSearch());
    try std.testing.expectEqualStrings("#section", location.getHash());
}

test "WorkerLocation - toString" {
    const allocator = std.testing.allocator;

    const location = try WorkerLocation.init(
        allocator,
        "https://example.com/worker.js",
    );
    defer location.deinit();

    try std.testing.expectEqualStrings(
        "https://example.com/worker.js",
        location.toString(),
    );
}
