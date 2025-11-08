//! Public Suffix List Tests
//!
//! Tests the PSL integration with real-world domains and edge cases

const std = @import("std");
const url_mod = @import("url");
const public_suffix = url_mod.public_suffix;
const Host = url_mod.host.Host;

test "PSL - basic TLDs" {
    const allocator = std.testing.allocator;

    const cases = [_]struct { domain: []const u8, expected: []const u8 }{
        .{ .domain = "example.com", .expected = "com" },
        .{ .domain = "example.org", .expected = "org" },
        .{ .domain = "example.net", .expected = "net" },
        .{ .domain = "example.edu", .expected = "edu" },
    };

    for (cases) |case| {
        const host = Host{ .domain = case.domain };
        const ps = try public_suffix.getPublicSuffix(allocator, host);
        defer if (ps) |p| allocator.free(p);

        try std.testing.expect(ps != null);
        try std.testing.expectEqualStrings(case.expected, ps.?);
    }
}

test "PSL - multi-level TLDs" {
    const allocator = std.testing.allocator;

    const cases = [_]struct { domain: []const u8, expected: []const u8 }{
        .{ .domain = "example.co.uk", .expected = "co.uk" },
        .{ .domain = "example.ac.uk", .expected = "ac.uk" },
        .{ .domain = "example.gov.uk", .expected = "gov.uk" },
    };

    for (cases) |case| {
        const host = Host{ .domain = case.domain };
        const ps = try public_suffix.getPublicSuffix(allocator, host);
        defer if (ps) |p| allocator.free(p);

        try std.testing.expect(ps != null);
        try std.testing.expectEqualStrings(case.expected, ps.?);
    }
}

test "PSL - wildcard rules" {
    const allocator = std.testing.allocator;

    // *.ck is in the PSL, so any subdomain of .ck is a public suffix
    const host = Host{ .domain = "www.example.ck" };
    const ps = try public_suffix.getPublicSuffix(allocator, host);
    defer if (ps) |p| allocator.free(p);

    try std.testing.expect(ps != null);
    // Should match "example.ck" as public suffix due to *.ck rule
    try std.testing.expectEqualStrings("example.ck", ps.?);
}

test "PSL - exception rules" {
    const allocator = std.testing.allocator;

    // !www.ck is an exception, so www.ck is NOT a public suffix
    // but ck is
    const host = Host{ .domain = "www.ck" };
    const ps = try public_suffix.getPublicSuffix(allocator, host);
    defer if (ps) |p| allocator.free(p);

    try std.testing.expect(ps != null);
    try std.testing.expectEqualStrings("ck", ps.?);
}

test "PSL - registrable domain" {
    const allocator = std.testing.allocator;

    const cases = [_]struct { domain: []const u8, expected: []const u8 }{
        .{ .domain = "www.example.com", .expected = "example.com" },
        .{ .domain = "sub.example.com", .expected = "example.com" },
        .{ .domain = "deep.sub.example.com", .expected = "example.com" },
        .{ .domain = "example.co.uk", .expected = "example.co.uk" },
        .{ .domain = "www.example.co.uk", .expected = "example.co.uk" },
    };

    for (cases) |case| {
        const host = Host{ .domain = case.domain };
        const rd = try public_suffix.getRegistrableDomain(allocator, host);
        defer if (rd) |r| allocator.free(r);

        try std.testing.expect(rd != null);
        try std.testing.expectEqualStrings(case.expected, rd.?);
    }
}

test "PSL - TLD only has no registrable domain" {
    const allocator = std.testing.allocator;

    const host = Host{ .domain = "com" };
    const rd = try public_suffix.getRegistrableDomain(allocator, host);
    defer if (rd) |r| allocator.free(r);

    // TLD has no registrable domain
    try std.testing.expect(rd == null);
}

test "PSL - GitHub Pages" {
    const allocator = std.testing.allocator;

    // github.io is a public suffix
    const host1 = Host{ .domain = "example.github.io" };
    const ps1 = try public_suffix.getPublicSuffix(allocator, host1);
    defer if (ps1) |p| allocator.free(p);

    try std.testing.expect(ps1 != null);
    try std.testing.expectEqualStrings("github.io", ps1.?);

    // Registrable domain is the full subdomain
    const rd1 = try public_suffix.getRegistrableDomain(allocator, host1);
    defer if (rd1) |r| allocator.free(r);

    try std.testing.expect(rd1 != null);
    try std.testing.expectEqualStrings("example.github.io", rd1.?);
}

test "PSL - trailing dot" {
    const allocator = std.testing.allocator;

    const host = Host{ .domain = "example.com." };
    const ps = try public_suffix.getPublicSuffix(allocator, host);
    defer if (ps) |p| allocator.free(p);

    try std.testing.expect(ps != null);
    // Should preserve trailing dot
    try std.testing.expectEqualStrings("com.", ps.?);
}

test "PSL - non-domain hosts return null" {
    const allocator = std.testing.allocator;

    // IPv4
    const host1 = Host{ .ipv4 = 0x7F000001 };
    const ps1 = try public_suffix.getPublicSuffix(allocator, host1);
    try std.testing.expect(ps1 == null);

    // IPv6
    const host2 = Host{ .ipv6 = [_]u16{0} ** 8 };
    const ps2 = try public_suffix.getPublicSuffix(allocator, host2);
    try std.testing.expect(ps2 == null);

    // Empty
    const host3 = Host{ .empty = {} };
    const ps3 = try public_suffix.getPublicSuffix(allocator, host3);
    try std.testing.expect(ps3 == null);
}
