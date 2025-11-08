//! Host Parsing Cache
//!
//! P10 Optimization: Cache parsed hosts for common hostnames
//!
//! Common hosts like "localhost", "127.0.0.1", "example.com" are parsed
//! frequently. Caching them avoids redundant parsing overhead.

const std = @import("std");
const Host = @import("host").Host;

/// P10: Pre-parsed common hosts (compile-time constants)
pub const LOCALHOST = Host{ .domain = "localhost" };
pub const LOCALHOST_IPV4 = Host{ .ipv4 = 0x7F000001 }; // 127.0.0.1
pub const EXAMPLE_COM = Host{ .domain = "example.com" };

/// Check if host string matches a cached common host
/// Returns cached host if match, null otherwise
///
/// Note: Does NOT cache IPv6 addresses because they need bracket validation
/// in the host parser. Only caches domains and IPv4 addresses.
pub inline fn getCachedHost(host_str: []const u8) ?Host {
    // Fast path: Check length first
    switch (host_str.len) {
        9 => {
            // "localhost" (9 chars) or "127.0.0.1" (9 chars)
            if (std.mem.eql(u8, host_str, "localhost")) {
                return LOCALHOST;
            }
            if (std.mem.eql(u8, host_str, "127.0.0.1")) {
                return LOCALHOST_IPV4;
            }
        },
        11 => {
            // "example.com" (11 chars)
            if (std.mem.eql(u8, host_str, "example.com")) {
                return EXAMPLE_COM;
            }
        },
        else => {},
    }

    return null;
}

test "host cache - localhost" {
    const cached = getCachedHost("localhost");
    try std.testing.expect(cached != null);
    try std.testing.expect(cached.?.isDomain());
    try std.testing.expectEqualStrings("localhost", cached.?.domain);
}

test "host cache - 127.0.0.1" {
    const cached = getCachedHost("127.0.0.1");
    try std.testing.expect(cached != null);
    try std.testing.expectEqual(@as(u32, 0x7F000001), cached.?.ipv4);
}

test "host cache - miss" {
    const cached = getCachedHost("google.com");
    try std.testing.expect(cached == null);
}
