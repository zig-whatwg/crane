//! Host Serializer
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#host-serializing
//! Spec Reference: Lines 656-662
//!
//! The host serializer converts a host to its string representation.
//!
//! ## Usage
//!
//! ```zig
//! const host_serializer = @import("host_serializer");
//!
//! // Domain
//! const h1 = Host{ .domain = "example.com" };
//! const s1 = try host_serializer.serializeHost(allocator, h1);
//! defer allocator.free(s1);
//! // Result: "example.com"
//!
//! // IPv4
//! const h2 = Host{ .ipv4 = 0xC0A80101 };
//! const s2 = try host_serializer.serializeHost(allocator, h2);
//! defer allocator.free(s2);
//! // Result: "192.168.1.1"
//!
//! // IPv6
//! const h3 = Host{ .ipv6 = .{ 0, 0, 0, 0, 0, 0, 0, 1 } };
//! const s3 = try host_serializer.serializeHost(allocator, h3);
//! defer allocator.free(s3);
//! // Result: "[::1]"
//! ```

const std = @import("std");
const infra = @import("infra");
const host = @import("host");
const ipv4_serializer = @import("ipv4_serializer");
const ipv6_serializer = @import("ipv6_serializer");

/// Serialize host to string (spec lines 656-662)
///
/// Dispatches to the appropriate serializer based on host type.
pub fn serializeHost(allocator: std.mem.Allocator, h: host.Host) ![]u8 {
    return switch (h) {
        // Step 1: If host is an IPv4 address, return the result of running the IPv4 serializer
        .ipv4 => |addr| try ipv4_serializer.serializeIPv4(allocator, addr),

        // Step 2: If host is an IPv6 address, return "[" + IPv6 serializer + "]"
        .ipv6 => |addr| {
            const ipv6_str = try ipv6_serializer.serializeIPv6(allocator, addr);
            defer allocator.free(ipv6_str);

            // Prepend "[" and append "]"
            var result = infra.List(u8).init(allocator);
            errdefer result.deinit();

            try result.append('[');
            try result.appendSlice(ipv6_str);
            try result.append(']');

            return result.toOwnedSlice();
        },

        // Step 3: Otherwise, host is a domain, opaque host, or empty host, return host
        .domain => |d| try allocator.dupe(u8, d),
        .opaque_host => |o| try allocator.dupe(u8, o),
        .empty => try allocator.dupe(u8, ""),
    };
}

test "host serializer - domain" {
    const allocator = std.testing.allocator;

    const h = host.Host{ .domain = "example.com" };
    const result = try serializeHost(allocator, h);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("example.com", result);
}

test "host serializer - ipv4" {
    const allocator = std.testing.allocator;

    const h = host.Host{ .ipv4 = 0xC0A80101 };
    const result = try serializeHost(allocator, h);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("192.168.1.1", result);
}

test "host serializer - ipv6 loopback" {
    const allocator = std.testing.allocator;

    const h = host.Host{ .ipv6 = .{ 0, 0, 0, 0, 0, 0, 0, 1 } };
    const result = try serializeHost(allocator, h);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("[::1]", result);
}

test "host serializer - ipv6 all zeros" {
    const allocator = std.testing.allocator;

    const h = host.Host{ .ipv6 = .{ 0, 0, 0, 0, 0, 0, 0, 0 } };
    const result = try serializeHost(allocator, h);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("[::]", result);
}

test "host serializer - ipv6 no compression" {
    const allocator = std.testing.allocator;

    const h = host.Host{ .ipv6 = .{ 0x2001, 0xdb8, 0x1234, 0x5678, 0x9abc, 0xdef0, 0x1234, 0x5678 } };
    const result = try serializeHost(allocator, h);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("[2001:db8:1234:5678:9abc:def0:1234:5678]", result);
}

test "host serializer - opaque host" {
    const allocator = std.testing.allocator;

    const h = host.Host{ .opaque_host = "opaque.example" };
    const result = try serializeHost(allocator, h);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("opaque.example", result);
}

test "host serializer - empty host" {
    const allocator = std.testing.allocator;

    const h = host.Host{ .empty = {} };
    const result = try serializeHost(allocator, h);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("", result);
}

test "host serializer - roundtrip domain" {
    const allocator = std.testing.allocator;
    const host_parser = @import("host_parser");

    const original = "example.com";
    const parsed = try host_parser.parseHost(allocator, original, false, null);
    defer parsed.deinit(allocator);

    const serialized = try serializeHost(allocator, parsed);
    defer allocator.free(serialized);

    try std.testing.expectEqualStrings(original, serialized);
}

test "host serializer - roundtrip ipv4" {
    const allocator = std.testing.allocator;
    const host_parser = @import("host_parser");

    const original = "192.168.1.1";
    const parsed = try host_parser.parseHost(allocator, original, false, null);
    defer parsed.deinit(allocator);

    const serialized = try serializeHost(allocator, parsed);
    defer allocator.free(serialized);

    try std.testing.expectEqualStrings(original, serialized);
}

test "host serializer - roundtrip ipv6 loopback" {
    const allocator = std.testing.allocator;
    const host_parser = @import("host_parser");

    const original = "[::1]";
    const parsed = try host_parser.parseHost(allocator, original, false, null);
    defer parsed.deinit(allocator);

    const serialized = try serializeHost(allocator, parsed);
    defer allocator.free(serialized);

    try std.testing.expectEqualStrings(original, serialized);
}

test "host serializer - roundtrip ipv6 full" {
    const allocator = std.testing.allocator;
    const host_parser = @import("host_parser");

    // Parse a compressed form
    const original = "[2001:db8::1234:5678]";
    const parsed = try host_parser.parseHost(allocator, original, false, null);
    defer parsed.deinit(allocator);

    const serialized = try serializeHost(allocator, parsed);
    defer allocator.free(serialized);

    // Should serialize to the same compressed form
    try std.testing.expectEqualStrings(original, serialized);
}
