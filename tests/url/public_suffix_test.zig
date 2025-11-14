//! Tests migrated from src/url/public_suffix.zig
//! Per WHATWG specifications

const std = @import("std");

const url = @import("url");
const Host = url.Host;

test "public suffix - basic TLDs" {
    const allocator = std.testing.allocator;

    const host = Host{ .domain = "example.com" };
    const ps = try url.getPublicSuffix(allocator, host);
    defer if (ps) |p| allocator.free(p);

    try std.testing.expect(ps != null);
    try std.testing.expectEqualStrings("com", ps.?);
}
test "public suffix - multi-level TLD" {
    const allocator = std.testing.allocator;

    const host = Host{ .domain = "example.co.uk" };
    const ps = try url.getPublicSuffix(allocator, host);
    defer if (ps) |p| allocator.free(p);

    try std.testing.expect(ps != null);
    try std.testing.expectEqualStrings("co.uk", ps.?);
}
test "public suffix - TLD only" {
    const allocator = std.testing.allocator;

    const host = Host{ .domain = "com" };
    const ps = try url.getPublicSuffix(allocator, host);
    defer if (ps) |p| allocator.free(p);

    try std.testing.expect(ps != null);
    try std.testing.expectEqualStrings("com", ps.?);
}
test "public suffix - IPv4 returns null" {
    const allocator = std.testing.allocator;

    const host = Host{ .ipv4 = 0x7F000001 }; // 127.0.0.1
    const ps = try url.getPublicSuffix(allocator, host);
    defer if (ps) |p| allocator.free(p);

    try std.testing.expect(ps == null);
}
test "public suffix - trailing dot preserved" {
    const allocator = std.testing.allocator;

    const host = Host{ .domain = "example.com." };
    const ps = try url.getPublicSuffix(allocator, host);
    defer if (ps) |p| allocator.free(p);

    try std.testing.expect(ps != null);
    try std.testing.expectEqualStrings("com.", ps.?);
}
test "registrable domain - basic" {
    const allocator = std.testing.allocator;

    const host = Host{ .domain = "www.example.com" };
    const rd = try url.getRegistrableDomain(allocator, host);
    defer if (rd) |r| allocator.free(r);

    try std.testing.expect(rd != null);
    try std.testing.expectEqualStrings("example.com", rd.?);
}
test "registrable domain - subdomain" {
    const allocator = std.testing.allocator;

    const host = Host{ .domain = "sub.www.example.com" };
    const rd = try url.getRegistrableDomain(allocator, host);
    defer if (rd) |r| allocator.free(r);

    try std.testing.expect(rd != null);
    try std.testing.expectEqualStrings("example.com", rd.?);
}
test "registrable domain - TLD returns null" {
    const allocator = std.testing.allocator;

    const host = Host{ .domain = "com" };
    const rd = try url.getRegistrableDomain(allocator, host);
    defer if (rd) |r| allocator.free(r);

    try std.testing.expect(rd == null);
}
test "registrable domain - github.io" {
    const allocator = std.testing.allocator;

    const host = Host{ .domain = "whatwg.github.io" };
    const rd = try url.getRegistrableDomain(allocator, host);
    defer if (rd) |r| allocator.free(r);

    try std.testing.expect(rd != null);
    try std.testing.expectEqualStrings("whatwg.github.io", rd.?);
}
test "registrable domain - trailing dot preserved" {
    const allocator = std.testing.allocator;

    const host = Host{ .domain = "www.example.com." };
    const rd = try url.getRegistrableDomain(allocator, host);
    defer if (rd) |r| allocator.free(r);

    try std.testing.expect(rd != null);
    try std.testing.expectEqualStrings("example.com.", rd.?);
}