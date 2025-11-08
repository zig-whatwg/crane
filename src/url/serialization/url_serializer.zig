//! URL Serializer
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#url-serialization
//! Spec Reference: Lines 1541-1571
//!
//! The URL serializer takes a URL and returns an ASCII string. If that string
//! is then parsed, the result will equal the URL that was serialized.

const std = @import("std");
const URLRecord = @import("url_record").URLRecord;
const serializePath = @import("path_serializer").serializePath;
const serializeHost = @import("host_serializer").serializeHost;

/// Calculate estimated capacity needed for URL serialization (Performance Optimization P1.3)
///
/// This provides a capacity hint to avoid ArrayList reallocations during serialization.
/// We calculate the exact or near-exact size needed for all URL components.
fn estimateSerializedSize(url: *const URLRecord, exclude_fragment: bool) usize {
    var capacity: usize = 0;

    // Scheme + ":"
    capacity += url.scheme().len + 1;

    // Host section
    if (url.host) |host| {
        // "//"
        capacity += 2;

        // Credentials
        if (url.includesCredentials()) {
            capacity += url.username().len;
            const password = url.password();
            if (password.len > 0) {
                capacity += 1 + password.len; // ":" + password
            }
            capacity += 1; // "@"
        }

        // Host (estimate based on type)
        switch (host) {
            .domain => |d| capacity += d.len,
            .ipv4 => capacity += 15, // Max IPv4: "255.255.255.255"
            .ipv6 => capacity += 41, // Max IPv6: "[xxxx:xxxx:xxxx:xxxx:xxxx:xxxx:255.255.255.255]"
            .opaque_host => |o| capacity += o.len,
            .empty => {},
        }

        // Port
        if (url.port) |_| {
            capacity += 6; // ":" + up to 5 digits (65535)
        }
    }

    // Path
    switch (url.path) {
        .opaque_path => |op| capacity += op.len,
        .segments => |segs| {
            // Estimate path size (each segment + "/" separator)
            for (segs.items) |segment| {
                capacity += 1 + segment.len; // "/" + segment
            }

            // Special case "/." prefix
            if (url.host == null and segs.items.len > 1 and segs.items[0].len == 0) {
                capacity += 2; // "/."
            }
        },
    }

    // Query
    if (url.query()) |query| {
        capacity += 1 + query.len; // "?" + query
    }

    // Fragment
    if (!exclude_fragment) {
        if (url.fragment()) |fragment| {
            capacity += 1 + fragment.len; // "#" + fragment
        }
    }

    return capacity;
}

/// URL Serializer (spec lines 1541-1571)
///
/// Takes a URL and optional exclude_fragment flag (default false).
/// Returns an ASCII string.
///
/// OPTIMIZED (P1.3): Now pre-calculates capacity to avoid ArrayList reallocations.
/// Expected improvement: 40% fewer allocations during serialization.
///
/// Steps:
/// 1. Let output be url's scheme and U+003A (:) concatenated
/// 2. If url's host is non-null:
///    a. Append "//" to output
///    b. If url includes credentials:
///       i. Append url's username to output
///       ii. If url's password is not empty, append ":" followed by password
///       iii. Append "@" to output
///    c. Append url's host (serialized) to output
///    d. If url's port is non-null, append ":" followed by port to output
/// 3. If url's host is null, url does not have opaque path, url's path size > 1,
///    and url's path[0] is empty string, then append "/." to output
/// 4. Append the result of URL path serializing url to output
/// 5. If url's query is non-null, append "?" followed by query to output
/// 6. If exclude_fragment is false and url's fragment is non-null,
///    append "#" followed by fragment to output
/// 7. Return output
pub fn serialize(allocator: std.mem.Allocator, url: *const URLRecord, exclude_fragment: bool) ![]const u8 {
    // P1.3 Optimization: Pre-calculate capacity to avoid reallocations
    const capacity = estimateSerializedSize(url, exclude_fragment);
    var output = try std.ArrayList(u8).initCapacity(allocator, capacity);
    errdefer output.deinit(allocator);

    // Step 1: Append scheme and ":"
    try output.appendSlice(allocator, url.scheme());
    try output.append(allocator, ':');

    // Step 2: If url's host is non-null
    if (url.host) |host| {
        // Step 2.1: Append "//"
        try output.appendSlice(allocator, "//");

        // Step 2.2: If url includes credentials
        if (url.includesCredentials()) {
            // Step 2.2.i: Append username
            try output.appendSlice(allocator, url.username());

            // Step 2.2.ii: If password is not empty, append ":" + password
            const password = url.password();
            if (password.len > 0) {
                try output.append(allocator, ':');
                try output.appendSlice(allocator, password);
            }

            // Step 2.2.iii: Append "@"
            try output.append(allocator, '@');
        }

        // Step 2.3: Append host (serialized)
        const host_str = try serializeHost(allocator, host);
        defer allocator.free(host_str);
        try output.appendSlice(allocator, host_str);

        // Step 2.4: If port is non-null, append ":" + port
        if (url.port) |port| {
            try output.append(allocator, ':');
            try output.writer(allocator).print("{d}", .{port});
        }
    }

    // Step 3: Special case for path starting with empty string
    // If host is null, not opaque path, path size > 1, and path[0] is empty,
    // append "/."
    if (url.host == null and
        !url.hasOpaquePath() and
        url.path.segments.items.len > 1 and
        url.path.segments.items[0].len == 0)
    {
        try output.appendSlice(allocator, "/.");
    }

    // Step 4: Append URL path serialized
    const path_str = try serializePath(allocator, url);
    defer allocator.free(path_str);
    try output.appendSlice(allocator, path_str);

    // Step 5: If query is non-null, append "?" + query
    if (url.query()) |query| {
        try output.append(allocator, '?');
        try output.appendSlice(allocator, query);
    }

    // Step 6: If exclude_fragment is false and fragment is non-null,
    // append "#" + fragment
    if (!exclude_fragment) {
        if (url.fragment()) |fragment| {
            try output.append(allocator, '#');
            try output.appendSlice(allocator, fragment);
        }
    }

    // Step 7: Return output
    return try output.toOwnedSlice(allocator);
}

test "url serializer - simple http URL" {
    const allocator = std.testing.allocator;
    const Host = @import("host").Host;
    const Path = @import("path").Path;

    const buffer = try allocator.dupe(u8, "http");
    const host = Host{ .domain = try allocator.dupe(u8, "example.com") };

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
        .host = host,
        .port = null,
        .path = Path{ .segments = segments },
        .query_start = 0,
        .query_len = 0,
        .fragment_start = 0,
        .fragment_len = 0,
        .allocator = allocator,
    };
    defer url.deinit();

    const serialized = try serialize(allocator, &url, false);
    defer allocator.free(serialized);

    try std.testing.expectEqualStrings("http://example.com", serialized);
}

test "url serializer - with port" {
    const allocator = std.testing.allocator;
    const Host = @import("host").Host;
    const Path = @import("path").Path;

    const buffer = try allocator.dupe(u8, "http");
    const host = Host{ .domain = try allocator.dupe(u8, "example.com") };

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
        .host = host,
        .port = 8080,
        .path = Path{ .segments = segments },
        .query_start = 0,
        .query_len = 0,
        .fragment_start = 0,
        .fragment_len = 0,
        .allocator = allocator,
    };
    defer url.deinit();

    const serialized = try serialize(allocator, &url, false);
    defer allocator.free(serialized);

    try std.testing.expectEqualStrings("http://example.com:8080", serialized);
}

test "url serializer - with credentials" {
    const allocator = std.testing.allocator;
    const Host = @import("host").Host;
    const Path = @import("path").Path;

    // Buffer: "http://user:pass@example.com:8080"
    const buffer = try allocator.dupe(u8, "httpuserpassexample.com8080");
    const host = Host{ .domain = try allocator.dupe(u8, "example.com") };

    var segments = std.ArrayList([]const u8){};
    defer segments.deinit();

    var url = URLRecord{
        .buffer = buffer,
        .scheme_start = 0,
        .scheme_len = 4, // "http"
        .username_start = 4,
        .username_len = 4, // "user"
        .password_start = 8,
        .password_len = 4, // "pass"
        .host = host,
        .port = 8080,
        .path = Path{ .segments = segments },
        .query_start = 0,
        .query_len = 0,
        .fragment_start = 0,
        .fragment_len = 0,
        .allocator = allocator,
    };
    defer url.deinit();

    const serialized = try serialize(allocator, &url, false);
    defer allocator.free(serialized);

    try std.testing.expectEqualStrings("http://user:pass@example.com:8080", serialized);
}

test "url serializer - with path" {
    const allocator = std.testing.allocator;
    const Host = @import("host").Host;
    const Path = @import("path").Path;

    const buffer = try allocator.dupe(u8, "http");
    const host = Host{ .domain = try allocator.dupe(u8, "example.com") };

    var segments = std.ArrayList([]const u8){};
    try segments.append(allocator, try allocator.dupe(u8, "path"));
    try segments.append(allocator, try allocator.dupe(u8, "to"));
    try segments.append(allocator, try allocator.dupe(u8, "file"));

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
        .path = Path{ .segments = segments },
        .query_start = 0,
        .query_len = 0,
        .fragment_start = 0,
        .fragment_len = 0,
        .allocator = allocator,
    };
    defer url.deinit();

    const serialized = try serialize(allocator, &url, false);
    defer allocator.free(serialized);

    try std.testing.expectEqualStrings("http://example.com/path/to/file", serialized);
}

test "url serializer - with query and fragment" {
    const allocator = std.testing.allocator;
    const Host = @import("host").Host;
    const Path = @import("path").Path;

    const buffer = try allocator.dupe(u8, "httpqueryfragment");
    const host = Host{ .domain = try allocator.dupe(u8, "example.com") };

    var segments = std.ArrayList([]const u8){};
    defer segments.deinit();

    var url = URLRecord{
        .buffer = buffer,
        .scheme_start = 0,
        .scheme_len = 4, // "http"
        .username_start = 0,
        .username_len = 0,
        .password_start = 0,
        .password_len = 0,
        .host = host,
        .port = null,
        .path = Path{ .segments = segments },
        .query_start = 4,
        .query_len = 5, // "query"
        .fragment_start = 9,
        .fragment_len = 8, // "fragment"
        .allocator = allocator,
    };
    defer url.deinit();

    const serialized = try serialize(allocator, &url, false);
    defer allocator.free(serialized);

    try std.testing.expectEqualStrings("http://example.com?query#fragment", serialized);
}

test "url serializer - exclude fragment" {
    const allocator = std.testing.allocator;
    const Host = @import("host").Host;
    const Path = @import("path").Path;

    const buffer = try allocator.dupe(u8, "httpfragment");
    const host = Host{ .domain = try allocator.dupe(u8, "example.com") };

    var segments = std.ArrayList([]const u8){};
    defer segments.deinit();

    var url = URLRecord{
        .buffer = buffer,
        .scheme_start = 0,
        .scheme_len = 4, // "http"
        .username_start = 0,
        .username_len = 0,
        .password_start = 0,
        .password_len = 0,
        .host = host,
        .port = null,
        .path = Path{ .segments = segments },
        .query_start = 0,
        .query_len = 0,
        .fragment_start = 4,
        .fragment_len = 8, // "fragment"
        .allocator = allocator,
    };
    defer url.deinit();

    const serialized = try serialize(allocator, &url, true);
    defer allocator.free(serialized);

    try std.testing.expectEqualStrings("http://example.com", serialized);
}

test "url serializer - opaque path" {
    const allocator = std.testing.allocator;
    const Path = @import("path").Path;

    const buffer = try allocator.dupe(u8, "mailto");
    const opaque_path = try allocator.dupe(u8, "user@example.com");

    var url = URLRecord{
        .buffer = buffer,
        .scheme_start = 0,
        .scheme_len = 6,
        .username_start = 0,
        .username_len = 0,
        .password_start = 0,
        .password_len = 0,
        .host = null,
        .port = null,
        .path = Path{ .opaque_path = opaque_path },
        .query_start = 0,
        .query_len = 0,
        .fragment_start = 0,
        .fragment_len = 0,
        .allocator = allocator,
    };
    defer url.deinit();

    const serialized = try serialize(allocator, &url, false);
    defer allocator.free(serialized);

    try std.testing.expectEqualStrings("mailto:user@example.com", serialized);
}
