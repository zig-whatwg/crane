//! URL Equivalence
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#url-equivalence
//! Spec Reference: Lines 743-747 (host equivalence), 1586-1593 (URL equivalence)
//!
//! This module provides functions to determine if two URLs or hosts are equivalent.

const std = @import("std");
const URLRecord = @import("url_record").URLRecord;
const Host = @import("host").Host;
const serialize = @import("url_serializer").serialize;

/// Determine whether URL A equals URL B (spec lines 1586-1593)
///
/// The algorithm:
/// 1. Serialize both URLs (with or without fragment)
/// 2. Compare serialized strings
///
/// The `exclude_fragments` parameter controls whether fragments are included
/// in the comparison. When true, URLs that differ only in fragment are
/// considered equal.
///
/// Examples:
/// - equals("http://example.com/", "http://example.com/") → true
/// - equals("http://example.com/#foo", "http://example.com/#bar", false) → false
/// - equals("http://example.com/#foo", "http://example.com/#bar", true) → true
pub fn equals(allocator: std.mem.Allocator, a: *const URLRecord, b: *const URLRecord, exclude_fragments: bool) !bool {
    // 1. Serialize A with exclude_fragment option
    const serialized_a = try serialize(allocator, a, exclude_fragments);
    defer allocator.free(serialized_a);

    // 2. Serialize B with exclude_fragment option
    const serialized_b = try serialize(allocator, b, exclude_fragments);
    defer allocator.free(serialized_b);

    // 3. Return true if serializedA == serializedB
    return std.mem.eql(u8, serialized_a, serialized_b);
}

/// Determine whether host A equals host B (spec line 745)
///
/// This is a simple identity check: two hosts are equal if they are the same.
///
/// Note: The spec mentions that certificate comparison requires a host
/// equivalence check that ignores trailing dots, but this function follows
/// the URL spec's definition which does NOT ignore trailing dots.
///
/// Examples:
/// - hostsEqual("example.com", "example.com") → true
/// - hostsEqual("example.com", "example.com.") → false (trailing dot matters)
/// - hostsEqual("192.168.1.1", "192.168.1.1") → true
pub fn hostsEqual(a: Host, b: Host) bool {
    // Check if same type
    const tag_a = @as(std.meta.Tag(Host), a);
    const tag_b = @as(std.meta.Tag(Host), b);
    if (tag_a != tag_b) return false;

    // Compare based on type
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

// Tests

test "URL equals - identical URLs" {
    const allocator = std.testing.allocator;

    // Create two identical URLs
    const buffer1 = try allocator.dupe(u8, "https");
    var segments1 = std.ArrayList([]const u8){};
    defer segments1.deinit();
    try segments1.append(allocator, try allocator.dupe(u8, ""));

    const host1 = @import("host").Host{ .domain = try allocator.dupe(u8, "example.com") };

    var url1 = URLRecord{
        .buffer = buffer1,
        .scheme_start = 0,
        .scheme_len = 5,
        .username_start = 0,
        .username_len = 0,
        .password_start = 0,
        .password_len = 0,
        .host = host1,
        .port = null,
        .path = @import("path").Path{ .segments = segments1 },
        .query_start = 0,
        .query_len = 0,
        .fragment_start = 0,
        .fragment_len = 0,
        .blob_url_entry = null,
        .allocator = allocator,
    };
    defer url1.deinit();

    const buffer2 = try allocator.dupe(u8, "https");
    var segments2 = std.ArrayList([]const u8){};
    defer segments2.deinit();
    try segments2.append(allocator, try allocator.dupe(u8, ""));

    const host2 = @import("host").Host{ .domain = try allocator.dupe(u8, "example.com") };

    var url2 = URLRecord{
        .buffer = buffer2,
        .scheme_start = 0,
        .scheme_len = 5,
        .username_start = 0,
        .username_len = 0,
        .password_start = 0,
        .password_len = 0,
        .host = host2,
        .port = null,
        .path = @import("path").Path{ .segments = segments2 },
        .query_start = 0,
        .query_len = 0,
        .fragment_start = 0,
        .fragment_len = 0,
        .blob_url_entry = null,
        .allocator = allocator,
    };
    defer url2.deinit();

    const result = try equals(allocator, &url1, &url2, false);
    try std.testing.expect(result);
}

test "URL equals - different schemes" {
    const allocator = std.testing.allocator;

    const buffer1 = try allocator.dupe(u8, "https");
    var segments1 = std.ArrayList([]const u8){};
    defer segments1.deinit();

    const host1 = @import("host").Host{ .domain = try allocator.dupe(u8, "example.com") };

    var url1 = URLRecord{
        .buffer = buffer1,
        .scheme_start = 0,
        .scheme_len = 5,
        .username_start = 0,
        .username_len = 0,
        .password_start = 0,
        .password_len = 0,
        .host = host1,
        .port = null,
        .path = @import("path").Path{ .segments = segments1 },
        .query_start = 0,
        .query_len = 0,
        .fragment_start = 0,
        .fragment_len = 0,
        .blob_url_entry = null,
        .allocator = allocator,
    };
    defer url1.deinit();

    const buffer2 = try allocator.dupe(u8, "http");
    var segments2 = std.ArrayList([]const u8){};
    defer segments2.deinit();

    const host2 = @import("host").Host{ .domain = try allocator.dupe(u8, "example.com") };

    var url2 = URLRecord{
        .buffer = buffer2,
        .scheme_start = 0,
        .scheme_len = 4,
        .username_start = 0,
        .username_len = 0,
        .password_start = 0,
        .password_len = 0,
        .host = host2,
        .port = null,
        .path = @import("path").Path{ .segments = segments2 },
        .query_start = 0,
        .query_len = 0,
        .fragment_start = 0,
        .fragment_len = 0,
        .blob_url_entry = null,
        .allocator = allocator,
    };
    defer url2.deinit();

    const result = try equals(allocator, &url1, &url2, false);
    try std.testing.expect(!result);
}

test "host equals - same domain" {
    const host_a = Host{ .domain = "example.com" };
    const host_b = Host{ .domain = "example.com" };

    try std.testing.expect(hostsEqual(host_a, host_b));
}

test "host equals - different domains" {
    const host_a = Host{ .domain = "example.com" };
    const host_b = Host{ .domain = "example.org" };

    try std.testing.expect(!hostsEqual(host_a, host_b));
}

test "host equals - trailing dot matters" {
    const host_a = Host{ .domain = "example.com" };
    const host_b = Host{ .domain = "example.com." };

    // Per spec, trailing dots are significant
    try std.testing.expect(!hostsEqual(host_a, host_b));
}

test "host equals - IPv4" {
    const host_a = Host{ .ipv4 = 0x7F000001 }; // 127.0.0.1
    const host_b = Host{ .ipv4 = 0x7F000001 };

    try std.testing.expect(hostsEqual(host_a, host_b));
}

test "host equals - different types" {
    const host_a = Host{ .domain = "127.0.0.1" };
    const host_b = Host{ .ipv4 = 0x7F000001 };

    try std.testing.expect(!hostsEqual(host_a, host_b));
}

test "host equals - IPv6" {
    const host_a = Host{ .ipv6 = [8]u16{ 0, 0, 0, 0, 0, 0, 0, 1 } }; // ::1
    const host_b = Host{ .ipv6 = [8]u16{ 0, 0, 0, 0, 0, 0, 0, 1 } };

    try std.testing.expect(hostsEqual(host_a, host_b));
}

test "host equals - empty hosts" {
    const host_a = Host{ .empty = {} };
    const host_b = Host{ .empty = {} };

    try std.testing.expect(hostsEqual(host_a, host_b));
}
