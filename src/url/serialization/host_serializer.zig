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











