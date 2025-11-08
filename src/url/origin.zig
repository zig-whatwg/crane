//! URL Origin Calculation
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#origin
//! Spec Reference: Lines 1595-1628
//!
//! An origin is an important security primitive used to determine whether
//! two URLs are "same origin" for security purposes.

const std = @import("std");
const URLRecord = @import("url_record").URLRecord;
const Host = @import("host").Host;

/// Tuple origin components
pub const TupleOrigin = struct {
    scheme: []const u8,
    host: Host,
    port: ?u16,

    pub fn deinit(self: TupleOrigin, allocator: std.mem.Allocator) void {
        allocator.free(self.scheme);
        self.host.deinit(allocator);
    }
};

/// Origin type (matches HTML spec)
/// Note: 'opaque' is a reserved word in Zig, so we use 'opaque_origin'
pub const Origin = union(enum) {
    tuple: TupleOrigin,
    opaque_origin: void,

    pub fn deinit(self: Origin, allocator: std.mem.Allocator) void {
        switch (self) {
            .tuple => |t| t.deinit(allocator),
            .opaque_origin => {},
        }
    }

    /// Serialize origin to string
    pub fn serialize(self: Origin, allocator: std.mem.Allocator) ![]u8 {
        switch (self) {
            .tuple => |t| {
                const host_str = try @import("host_serializer").serializeHost(allocator, t.host);
                defer allocator.free(host_str);

                if (t.port) |port| {
                    return try std.fmt.allocPrint(allocator, "{s}://{s}:{d}", .{ t.scheme, host_str, port });
                } else {
                    return try std.fmt.allocPrint(allocator, "{s}://{s}", .{ t.scheme, host_str });
                }
            },
            .opaque_origin => {
                return try allocator.dupe(u8, "null");
            },
        }
    }
};

/// Get origin of URL (spec lines 1595-1628)
pub fn getOrigin(allocator: std.mem.Allocator, url: *const URLRecord) !Origin {
    const scheme = url.scheme();

    // Special handling for blob URLs (spec line 1602)
    // If blob URL entry is non-null, return its environment's origin
    if (std.mem.eql(u8, scheme, "blob")) {
        if (url.blob_url_entry) |entry| {
            return try entry.getOrigin(allocator);
        }
        return Origin{ .opaque_origin = {} };
    }

    // file, data, and other schemes return opaque origin
    if (std.mem.eql(u8, scheme, "file") or
        std.mem.eql(u8, scheme, "data"))
    {
        return Origin{ .opaque_origin = {} };
    }

    // ftp, http, https, ws, wss return tuple origin
    if (std.mem.eql(u8, scheme, "ftp") or
        std.mem.eql(u8, scheme, "http") or
        std.mem.eql(u8, scheme, "https") or
        std.mem.eql(u8, scheme, "ws") or
        std.mem.eql(u8, scheme, "wss"))
    {
        const scheme_copy = try allocator.dupe(u8, scheme);
        errdefer allocator.free(scheme_copy);

        const host = if (url.host) |h|
            try h.clone(allocator)
        else
            return error.InvalidOrigin;

        return Origin{ .tuple = .{
            .scheme = scheme_copy,
            .host = host,
            .port = url.port,
        } };
    }

    // All other schemes return opaque origin
    return Origin{ .opaque_origin = {} };
}

/// Check if two origins are same origin
pub fn isSameOrigin(a: Origin, b: Origin) bool {
    if (a == .opaque_origin or b == .opaque_origin) return false;

    const tuple_a = a.tuple;
    const tuple_b = b.tuple;

    if (!std.mem.eql(u8, tuple_a.scheme, tuple_b.scheme)) return false;
    if (tuple_a.port != tuple_b.port) return false;

    // Simplified host comparison
    return hostsEqual(tuple_a.host, tuple_b.host);
}

fn hostsEqual(a: Host, b: Host) bool {
    // Check if same type
    const tag_a = @as(std.meta.Tag(Host), a);
    const tag_b = @as(std.meta.Tag(Host), b);
    if (tag_a != tag_b) return false;

    // Now we know they're the same type
    switch (a) {
        .domain => |d_a| {
            const d_b = b.domain;
            return std.mem.eql(u8, d_a, d_b);
        },
        .ipv4 => |ip_a| {
            const ip_b = b.ipv4;
            return ip_a == ip_b;
        },
        .ipv6 => |ip_a| {
            const ip_b = b.ipv6;
            return std.mem.eql(u16, &ip_a, &ip_b);
        },
        .opaque_host => |o_a| {
            const o_b = b.opaque_host;
            return std.mem.eql(u8, o_a, o_b);
        },
        .empty => return true,
    }
}

test "origin - http URL" {
    const allocator = std.testing.allocator;

    const buffer = try allocator.dupe(u8, "http");
    var segments = std.ArrayList([]const u8){};
    defer segments.deinit();

    const host = Host{ .domain = try allocator.dupe(u8, "example.com") };

    var url = URLRecord{
        .buffer = buffer,
        .scheme_start = 0,
        .scheme_len = 4,
        .username_start = 0,
        .username_len = 0,
        .password_start = 0,
        .password_len = 0,
        .host = host,
        .port = null,
        .path = @import("path").Path{ .segments = segments },
        .query_start = 0,
        .query_len = 0,
        .fragment_start = 0,
        .fragment_len = 0,
        .allocator = allocator,
    };
    defer url.deinit();

    const origin = try getOrigin(allocator, &url);
    defer origin.deinit(allocator);

    try std.testing.expect(origin == .tuple);
    try std.testing.expectEqualStrings("http", origin.tuple.scheme);
}

test "origin - file returns opaque" {
    const allocator = std.testing.allocator;

    const buffer = try allocator.dupe(u8, "file");
    var segments = std.ArrayList([]const u8){};
    defer segments.deinit();

    var url = URLRecord{
        .buffer = buffer,
        .scheme_start = 0,
        .scheme_len = 4,
        .username_start = 0,
        .username_len = 0,
        .password_start = 0,
        .password_len = 0,
        .host = null,
        .port = null,
        .path = @import("path").Path{ .segments = segments },
        .query_start = 0,
        .query_len = 0,
        .fragment_start = 0,
        .fragment_len = 0,
        .allocator = allocator,
    };
    defer url.deinit();

    const origin = try getOrigin(allocator, &url);
    defer origin.deinit(allocator);

    try std.testing.expect(origin == .opaque_origin);
}
