//! URL Equivalence
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#url-equivalence
//! Spec Reference: Lines 743-747 (host equivalence), 1586-1593 (URL equivalence)
//!
//! This module provides functions to determine if two URLs or hosts are equivalent.

const std = @import("std");
const infra = @import("infra");
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









