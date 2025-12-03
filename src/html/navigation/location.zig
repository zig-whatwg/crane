//! Location API - HTML Standard §7.2.5
//!
//! The Location interface provides access to the URL of the document and methods
//! for navigation. It is a unique instance per Window object.
//!
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-location-interface
//!
//! ## Key Features
//!
//! - **href**: Get/set the entire URL (stringifier)
//! - **origin**: Get the URL's origin (read-only)
//! - **protocol**, **host**, **hostname**, **port**, **pathname**, **search**, **hash**:
//!   URL component accessors with setters that trigger navigation
//! - **assign(url)**: Navigate to the given URL
//! - **replace(url)**: Replace current entry and navigate
//! - **reload()**: Reload the current page
//! - **ancestorOrigins**: List of ancestor document origins
//!
//! ## Security
//!
//! Location is subject to cross-origin security checks. Only href setter and
//! replace() are allowed cross-origin.

const std = @import("std");
const Allocator = std.mem.Allocator;

const history = @import("history.zig");
const HistoryHandlingBehavior = history.HistoryHandlingBehavior;
const canRewriteUrl = history.canRewriteUrl;

// ============================================================================
// Location Error
// ============================================================================

/// Errors that can occur during Location operations
pub const LocationError = error{
    /// Cross-origin security violation
    SecurityError,
    /// Invalid URL syntax
    SyntaxError,
    /// Document is null
    InvalidDocument,
    /// Out of memory
    OutOfMemory,
};

// ============================================================================
// URL Components
// ============================================================================

/// Parsed URL components for Location
pub const UrlComponents = struct {
    /// Full URL
    href: []const u8,
    /// Origin (scheme + host + port)
    origin: []const u8,
    /// Scheme with trailing colon (e.g., "https:")
    protocol: []const u8,
    /// Host and port (e.g., "example.com:8080")
    host: []const u8,
    /// Host only (e.g., "example.com")
    hostname: []const u8,
    /// Port only (e.g., "8080")
    port: []const u8,
    /// Path (e.g., "/path/to/page")
    pathname: []const u8,
    /// Query string with leading ? (e.g., "?key=value")
    search: []const u8,
    /// Fragment with leading # (e.g., "#section")
    hash: []const u8,

    allocator: Allocator,

    /// Parse a URL into components
    pub fn parse(allocator: Allocator, url: []const u8) !UrlComponents {
        var components = UrlComponents{
            .allocator = allocator,
            .href = try allocator.dupe(u8, url),
            .origin = &[_]u8{},
            .protocol = &[_]u8{},
            .host = &[_]u8{},
            .hostname = &[_]u8{},
            .port = &[_]u8{},
            .pathname = &[_]u8{},
            .search = &[_]u8{},
            .hash = &[_]u8{},
        };
        errdefer components.deinit();

        // Parse the URL
        var remaining = url;

        // Extract protocol (scheme)
        if (std.mem.indexOf(u8, remaining, "://")) |scheme_end| {
            components.protocol = try allocator.dupe(u8, remaining[0 .. scheme_end + 1]); // Include :
            remaining = remaining[scheme_end + 3 ..];
        }

        // Extract hash (fragment)
        if (std.mem.indexOf(u8, remaining, "#")) |hash_idx| {
            components.hash = try allocator.dupe(u8, remaining[hash_idx..]);
            remaining = remaining[0..hash_idx];
        }

        // Extract search (query)
        if (std.mem.indexOf(u8, remaining, "?")) |query_idx| {
            components.search = try allocator.dupe(u8, remaining[query_idx..]);
            remaining = remaining[0..query_idx];
        }

        // Extract path
        if (std.mem.indexOf(u8, remaining, "/")) |path_idx| {
            components.pathname = try allocator.dupe(u8, remaining[path_idx..]);
            remaining = remaining[0..path_idx];
        } else {
            components.pathname = try allocator.dupe(u8, "/");
        }

        // Remaining is host:port
        components.host = try allocator.dupe(u8, remaining);

        // Split host and port
        if (std.mem.indexOf(u8, remaining, ":")) |port_idx| {
            components.hostname = try allocator.dupe(u8, remaining[0..port_idx]);
            components.port = try allocator.dupe(u8, remaining[port_idx + 1 ..]);
        } else {
            components.hostname = try allocator.dupe(u8, remaining);
        }

        // Build origin (protocol + // + host)
        var origin_buf = std.ArrayList(u8).init(allocator);
        defer origin_buf.deinit();

        if (components.protocol.len > 0) {
            try origin_buf.appendSlice(components.protocol);
            try origin_buf.appendSlice("//");
        }
        try origin_buf.appendSlice(components.host);

        components.origin = try allocator.dupe(u8, origin_buf.items);

        return components;
    }

    /// Free all allocated memory
    pub fn deinit(self: *UrlComponents) void {
        if (self.href.len > 0) self.allocator.free(self.href);
        if (self.origin.len > 0) self.allocator.free(self.origin);
        if (self.protocol.len > 0) self.allocator.free(self.protocol);
        if (self.host.len > 0) self.allocator.free(self.host);
        if (self.hostname.len > 0) self.allocator.free(self.hostname);
        if (self.port.len > 0) self.allocator.free(self.port);
        if (self.pathname.len > 0) self.allocator.free(self.pathname);
        if (self.search.len > 0) self.allocator.free(self.search);
        if (self.hash.len > 0) self.allocator.free(self.hash);
    }

    /// Clone this URL components
    pub fn clone(self: *const UrlComponents, allocator: Allocator) !UrlComponents {
        return .{
            .allocator = allocator,
            .href = try allocator.dupe(u8, self.href),
            .origin = try allocator.dupe(u8, self.origin),
            .protocol = try allocator.dupe(u8, self.protocol),
            .host = try allocator.dupe(u8, self.host),
            .hostname = try allocator.dupe(u8, self.hostname),
            .port = try allocator.dupe(u8, self.port),
            .pathname = try allocator.dupe(u8, self.pathname),
            .search = try allocator.dupe(u8, self.search),
            .hash = try allocator.dupe(u8, self.hash),
        };
    }

    /// Rebuild href from components
    pub fn rebuildHref(self: *UrlComponents) !void {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();

        try buf.appendSlice(self.protocol);
        try buf.appendSlice("//");
        try buf.appendSlice(self.host);
        try buf.appendSlice(self.pathname);
        try buf.appendSlice(self.search);
        try buf.appendSlice(self.hash);

        self.allocator.free(self.href);
        self.href = try self.allocator.dupe(u8, buf.items);
    }
};

// ============================================================================
// Location Interface - HTML Standard §7.2.5
// ============================================================================

/// The Location interface
///
/// HTML Standard §7.2.5:
/// "Location objects provide a representation of the URL of their associated
/// Document, as well as methods for navigating and reloading the associated navigable."
pub const Location = struct {
    allocator: Allocator,

    /// Current URL components
    url: UrlComponents,

    /// Ancestor origins list
    ancestor_origins: std.ArrayList([]const u8),

    /// Associated Window (opaque pointer)
    window: ?*anyopaque,

    /// Callback for navigation
    on_navigate: ?*const fn (
        location: *Location,
        url: []const u8,
        history_handling: HistoryHandlingBehavior,
    ) LocationError!void,

    /// Callback for reload
    on_reload: ?*const fn (location: *Location) void,

    /// Context for callbacks
    context: ?*anyopaque,

    /// Create a new Location instance
    pub fn init(allocator: Allocator, initial_url: []const u8) !*Location {
        const location = try allocator.create(Location);
        errdefer allocator.destroy(location);

        location.* = .{
            .allocator = allocator,
            .url = try UrlComponents.parse(allocator, initial_url),
            .ancestor_origins = std.ArrayList([]const u8).init(allocator),
            .window = null,
            .on_navigate = null,
            .on_reload = null,
            .context = null,
        };

        return location;
    }

    /// Free resources
    pub fn deinit(self: *Location) void {
        self.url.deinit();

        for (self.ancestor_origins.items) |origin| {
            self.allocator.free(origin);
        }
        self.ancestor_origins.deinit();

        self.allocator.destroy(self);
    }

    /// Set the associated window
    pub fn setWindow(self: *Location, window: *anyopaque) void {
        self.window = window;
    }

    /// Set callbacks
    pub fn setCallbacks(
        self: *Location,
        on_navigate: ?*const fn (location: *Location, url: []const u8, history_handling: HistoryHandlingBehavior) LocationError!void,
        on_reload: ?*const fn (location: *Location) void,
        context: ?*anyopaque,
    ) void {
        self.on_navigate = on_navigate;
        self.on_reload = on_reload;
        self.context = context;
    }

    /// Add an ancestor origin
    pub fn addAncestorOrigin(self: *Location, ancestor_origin: []const u8) !void {
        const duped = try self.allocator.dupe(u8, ancestor_origin);
        try self.ancestor_origins.append(duped);
    }

    // ========================================================================
    // URL Getters - HTML Standard §7.2.5
    // ========================================================================

    /// Get the full URL (href getter, stringifier)
    ///
    /// HTML Standard:
    /// "The href getter steps are:
    /// 1. If this's relevant Document is non-null and its origin is not same
    ///    origin-domain with the entry settings object's origin, then throw
    ///    a 'SecurityError' DOMException.
    /// 2. Return this's url, serialized."
    pub fn href(self: *const Location) []const u8 {
        return self.url.href;
    }

    /// Get the origin
    ///
    /// HTML Standard:
    /// "The origin getter steps are:
    /// 1. If this's relevant Document is non-null and its origin is not same
    ///    origin-domain with the entry settings object's origin, then throw
    ///    a 'SecurityError' DOMException.
    /// 2. Return the serialization of this's url's origin."
    pub fn getOrigin(self: *const Location) []const u8 {
        return self.url.origin;
    }

    /// Get the protocol (scheme with colon)
    pub fn protocol(self: *const Location) []const u8 {
        return self.url.protocol;
    }

    /// Get the host (hostname:port)
    pub fn host(self: *const Location) []const u8 {
        return self.url.host;
    }

    /// Get the hostname
    pub fn hostname(self: *const Location) []const u8 {
        return self.url.hostname;
    }

    /// Get the port
    pub fn port(self: *const Location) []const u8 {
        return self.url.port;
    }

    /// Get the pathname
    pub fn pathname(self: *const Location) []const u8 {
        return self.url.pathname;
    }

    /// Get the search (query string with ?)
    pub fn search(self: *const Location) []const u8 {
        return self.url.search;
    }

    /// Get the hash (fragment with #)
    pub fn hash(self: *const Location) []const u8 {
        return self.url.hash;
    }

    /// Get ancestor origins
    pub fn ancestorOrigins(self: *const Location) []const []const u8 {
        return self.ancestor_origins.items;
    }

    // ========================================================================
    // URL Setters - HTML Standard §7.2.5
    // ========================================================================

    /// Set the href (navigate to new URL)
    ///
    /// HTML Standard:
    /// "The href setter steps are:
    /// 1. If this's relevant Document is null, then return.
    /// 2. Let url be the result of encoding-parsing a URL given the given value,
    ///    relative to the entry settings object.
    /// 3. If url is failure, then throw a 'SyntaxError' DOMException.
    /// 4. Location-object navigate this to url."
    pub fn setHref(self: *Location, new_href: []const u8) LocationError!void {
        try self.navigate(new_href, .auto);
    }

    /// Set the protocol
    ///
    /// Only allows HTTP(S) scheme changes per spec.
    pub fn setProtocol(self: *Location, new_protocol: []const u8) LocationError!void {
        // Validate that it's HTTP(S)
        if (!std.mem.eql(u8, new_protocol, "http:") and
            !std.mem.eql(u8, new_protocol, "https:") and
            !std.mem.eql(u8, new_protocol, "http") and
            !std.mem.eql(u8, new_protocol, "https"))
        {
            return; // Silently fail for non-HTTP(S) schemes
        }

        var new_url = try self.url.clone(self.allocator);
        defer new_url.deinit();

        self.allocator.free(new_url.protocol);
        if (std.mem.endsWith(u8, new_protocol, ":")) {
            new_url.protocol = try self.allocator.dupe(u8, new_protocol);
        } else {
            var buf: [16]u8 = undefined;
            const len = std.fmt.bufPrint(&buf, "{s}:", .{new_protocol}) catch return;
            new_url.protocol = try self.allocator.dupe(u8, len);
        }

        try new_url.rebuildHref();
        try self.navigate(new_url.href, .auto);
    }

    /// Set the host
    pub fn setHost(self: *Location, new_host: []const u8) LocationError!void {
        var new_url = try self.url.clone(self.allocator);
        defer new_url.deinit();

        self.allocator.free(new_url.host);
        new_url.host = try self.allocator.dupe(u8, new_host);

        // Update hostname and port
        if (std.mem.indexOf(u8, new_host, ":")) |colon_idx| {
            self.allocator.free(new_url.hostname);
            self.allocator.free(new_url.port);
            new_url.hostname = try self.allocator.dupe(u8, new_host[0..colon_idx]);
            new_url.port = try self.allocator.dupe(u8, new_host[colon_idx + 1 ..]);
        } else {
            self.allocator.free(new_url.hostname);
            self.allocator.free(new_url.port);
            new_url.hostname = try self.allocator.dupe(u8, new_host);
            new_url.port = try self.allocator.dupe(u8, "");
        }

        try new_url.rebuildHref();
        try self.navigate(new_url.href, .auto);
    }

    /// Set the hostname
    pub fn setHostname(self: *Location, new_hostname: []const u8) LocationError!void {
        var new_url = try self.url.clone(self.allocator);
        defer new_url.deinit();

        self.allocator.free(new_url.hostname);
        new_url.hostname = try self.allocator.dupe(u8, new_hostname);

        // Rebuild host
        self.allocator.free(new_url.host);
        if (new_url.port.len > 0) {
            var buf = std.ArrayList(u8).init(self.allocator);
            defer buf.deinit();
            try buf.appendSlice(new_hostname);
            try buf.append(':');
            try buf.appendSlice(new_url.port);
            new_url.host = try self.allocator.dupe(u8, buf.items);
        } else {
            new_url.host = try self.allocator.dupe(u8, new_hostname);
        }

        try new_url.rebuildHref();
        try self.navigate(new_url.href, .auto);
    }

    /// Set the port
    pub fn setPort(self: *Location, new_port: []const u8) LocationError!void {
        var new_url = try self.url.clone(self.allocator);
        defer new_url.deinit();

        self.allocator.free(new_url.port);
        new_url.port = try self.allocator.dupe(u8, new_port);

        // Rebuild host
        self.allocator.free(new_url.host);
        if (new_port.len > 0) {
            var buf = std.ArrayList(u8).init(self.allocator);
            defer buf.deinit();
            try buf.appendSlice(new_url.hostname);
            try buf.append(':');
            try buf.appendSlice(new_port);
            new_url.host = try self.allocator.dupe(u8, buf.items);
        } else {
            new_url.host = try self.allocator.dupe(u8, new_url.hostname);
        }

        try new_url.rebuildHref();
        try self.navigate(new_url.href, .auto);
    }

    /// Set the pathname
    pub fn setPathname(self: *Location, new_pathname: []const u8) LocationError!void {
        var new_url = try self.url.clone(self.allocator);
        defer new_url.deinit();

        self.allocator.free(new_url.pathname);
        new_url.pathname = try self.allocator.dupe(u8, new_pathname);

        try new_url.rebuildHref();
        try self.navigate(new_url.href, .auto);
    }

    /// Set the search (query string)
    pub fn setSearch(self: *Location, new_search: []const u8) LocationError!void {
        var new_url = try self.url.clone(self.allocator);
        defer new_url.deinit();

        self.allocator.free(new_url.search);

        // Handle leading ?
        if (new_search.len == 0) {
            new_url.search = try self.allocator.dupe(u8, "");
        } else if (std.mem.startsWith(u8, new_search, "?")) {
            new_url.search = try self.allocator.dupe(u8, new_search);
        } else {
            var buf = std.ArrayList(u8).init(self.allocator);
            defer buf.deinit();
            try buf.append('?');
            try buf.appendSlice(new_search);
            new_url.search = try self.allocator.dupe(u8, buf.items);
        }

        try new_url.rebuildHref();
        try self.navigate(new_url.href, .auto);
    }

    /// Set the hash (fragment)
    ///
    /// HTML Standard:
    /// "The hash setter steps are:
    /// ...
    /// 8. If copyURL's fragment is thisURLFragment, then return.
    ///    (This bailout is necessary for compatibility with deployed content)"
    pub fn setHash(self: *Location, new_hash: []const u8) LocationError!void {
        // Check if the new hash is the same as current (bailout per spec)
        const current_hash = if (self.url.hash.len > 1)
            self.url.hash[1..]
        else
            "";

        const incoming_hash = if (std.mem.startsWith(u8, new_hash, "#"))
            new_hash[1..]
        else
            new_hash;

        if (std.mem.eql(u8, current_hash, incoming_hash)) {
            return; // Bailout - same fragment
        }

        var new_url = try self.url.clone(self.allocator);
        defer new_url.deinit();

        self.allocator.free(new_url.hash);

        // Handle leading #
        if (new_hash.len == 0) {
            new_url.hash = try self.allocator.dupe(u8, "");
        } else if (std.mem.startsWith(u8, new_hash, "#")) {
            new_url.hash = try self.allocator.dupe(u8, new_hash);
        } else {
            var buf = std.ArrayList(u8).init(self.allocator);
            defer buf.deinit();
            try buf.append('#');
            try buf.appendSlice(new_hash);
            new_url.hash = try self.allocator.dupe(u8, buf.items);
        }

        try new_url.rebuildHref();
        try self.navigate(new_url.href, .auto);
    }

    // ========================================================================
    // Navigation Methods - HTML Standard §7.2.5
    // ========================================================================

    /// Navigate to a URL (internal method)
    fn navigate(self: *Location, url: []const u8, history_handling: HistoryHandlingBehavior) LocationError!void {
        if (self.on_navigate) |callback| {
            try callback(self, url, history_handling);
        }

        // Update our local URL
        self.url.deinit();
        self.url = try UrlComponents.parse(self.allocator, url);
    }

    /// Assign a new URL (navigate with normal history handling)
    ///
    /// HTML Standard:
    /// "The assign(url) method steps are:
    /// 1. If this's relevant Document is null, then return.
    /// 2. If this's relevant Document's origin is not same origin-domain with
    ///    the entry settings object's origin, then throw a 'SecurityError' DOMException.
    /// 3. Let urlRecord be the result of encoding-parsing a URL given url,
    ///    relative to the entry settings object.
    /// 4. If urlRecord is failure, then throw a 'SyntaxError' DOMException.
    /// 5. Location-object navigate this to urlRecord."
    pub fn assign(self: *Location, url: []const u8) LocationError!void {
        try self.navigate(url, .push);
    }

    /// Replace current entry and navigate
    ///
    /// HTML Standard:
    /// "The replace(url) method steps are:
    /// 1. If this's relevant Document is null, then return.
    /// 2. Let urlRecord be the result of encoding-parsing a URL given url,
    ///    relative to the entry settings object.
    /// 3. If urlRecord is failure, then throw a 'SyntaxError' DOMException.
    /// 4. Location-object navigate this to urlRecord given 'replace'.
    ///
    /// The replace() method intentionally has no security check."
    pub fn replace(self: *Location, url: []const u8) LocationError!void {
        try self.navigate(url, .replace);
    }

    /// Reload the current page
    ///
    /// HTML Standard:
    /// "The reload() method steps are:
    /// 1. Let document be this's relevant Document.
    /// 2. If document is null, then return.
    /// 3. If document's origin is not same origin-domain with the entry settings
    ///    object's origin, then throw a 'SecurityError' DOMException.
    /// 4. Reload document's node navigable."
    pub fn reload(self: *Location) void {
        if (self.on_reload) |callback| {
            callback(self);
        }
    }

    /// Update the URL without triggering navigation (for internal use)
    pub fn updateUrl(self: *Location, new_url: []const u8) !void {
        self.url.deinit();
        self.url = try UrlComponents.parse(self.allocator, new_url);
    }

    /// Get string representation (toString() / href)
    pub fn toString(self: *const Location) []const u8 {
        return self.href();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "UrlComponents - parse" {
    const allocator = std.testing.allocator;

    var components = try UrlComponents.parse(allocator, "https://example.com:8080/path/to/page?query=value#section");
    defer components.deinit();

    try std.testing.expectEqualStrings("https:", components.protocol);
    try std.testing.expectEqualStrings("example.com:8080", components.host);
    try std.testing.expectEqualStrings("example.com", components.hostname);
    try std.testing.expectEqualStrings("8080", components.port);
    try std.testing.expectEqualStrings("/path/to/page", components.pathname);
    try std.testing.expectEqualStrings("?query=value", components.search);
    try std.testing.expectEqualStrings("#section", components.hash);
}

test "Location - init and deinit" {
    const allocator = std.testing.allocator;

    const location = try Location.init(allocator, "https://example.com/page");
    defer location.deinit();

    try std.testing.expectEqualStrings("https://example.com/page", location.href());
    try std.testing.expectEqualStrings("https:", location.protocol());
    try std.testing.expectEqualStrings("example.com", location.host());
    try std.testing.expectEqualStrings("/page", location.pathname());
}

test "Location - getters" {
    const allocator = std.testing.allocator;

    const location = try Location.init(allocator, "https://user:pass@example.com:8080/path?query#hash");
    defer location.deinit();

    try std.testing.expectEqualStrings("https:", location.protocol());
    try std.testing.expectEqualStrings("example.com:8080", location.host());
    try std.testing.expectEqualStrings("example.com", location.hostname());
    try std.testing.expectEqualStrings("8080", location.port());
    try std.testing.expectEqualStrings("/path", location.pathname());
    try std.testing.expectEqualStrings("?query", location.search());
    try std.testing.expectEqualStrings("#hash", location.hash());
}

test "Location - ancestor origins" {
    const allocator = std.testing.allocator;

    const location = try Location.init(allocator, "https://example.com/");
    defer location.deinit();

    try location.addAncestorOrigin("https://parent.com");
    try location.addAncestorOrigin("https://grandparent.com");

    const origins = location.ancestorOrigins();
    try std.testing.expectEqual(@as(usize, 2), origins.len);
    try std.testing.expectEqualStrings("https://parent.com", origins[0]);
    try std.testing.expectEqualStrings("https://grandparent.com", origins[1]);
}
