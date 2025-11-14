//! Host Parser
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#host-parsing
//! Spec Reference: Lines 415-437
//!
//! The host parser determines whether input is an IPv6 address, IPv4 address,
//! opaque host, or domain, and invokes the appropriate parser.
//!
//! ## Usage
//!
//! ```zig
//! const host_parser = @import("host_parser");
//!
//! // Parse domain
//! const h = try host_parser.parseHost(allocator, "example.com", false, null);
//! defer h.deinit(allocator);
//!
//! // Parse IPv4
//! const h2 = try host_parser.parseHost(allocator, "192.168.1.1", false, null);
//! defer h2.deinit(allocator);
//!
//! // Parse IPv6
//! const h3 = try host_parser.parseHost(allocator, "[::1]", false, null);
//! defer h3.deinit(allocator);
//! ```

const std = @import("std");
const infra = @import("infra");
const host = @import("host");
const host_cache = @import("host_cache.zig");
const ipv4_parser = @import("ipv4_parser");
const ipv6_parser = @import("ipv6_parser");
const percent_encoding = @import("percent_encoding");
const encode_sets = @import("encode_sets");
const idna = @import("../idna/root.zig");
const validation = @import("validation");

pub const HostParseError = error{
    IPv6Unclosed,
    InvalidHost,
    OutOfMemory,
};

/// Check if domain ends in a number (spec lines 439-459)
///
/// Used to determine if a domain should be parsed as IPv4.
fn endsInNumber(input: []const u8) bool {
    // Step 1: Split on '.' - collect parts into a fixed buffer
    var parts_buf: [16][]const u8 = undefined;
    var parts_count: usize = 0;

    var it = std.mem.splitScalar(u8, input, '.');
    while (it.next()) |part| {
        if (parts_count >= parts_buf.len) break;
        parts_buf[parts_count] = part;
        parts_count += 1;
    }

    if (parts_count == 0) return false;

    // Step 2: If last is empty
    if (parts_buf[parts_count - 1].len == 0) {
        // Step 2.1: If only one part, return false
        if (parts_count == 1) return false;
        // Step 2.2: Remove last
        parts_count -= 1;
    }

    // Step 3: Get last part
    if (parts_count == 0) return false;
    const last = parts_buf[parts_count - 1];

    // Step 4: If last contains only ASCII digits, return true
    if (last.len > 0) {
        var all_digits = true;
        for (last) |ch| {
            if (!std.ascii.isDigit(ch)) {
                all_digits = false;
                break;
            }
        }
        if (all_digits) return true;
    }

    // Step 5: Try parsing as IPv4 number (0x or 0X prefix)
    // "0X" or "0x" followed by zero or more ASCII hex digits
    if (last.len >= 2) {
        if ((last[0] == '0' and (last[1] == 'x' or last[1] == 'X'))) {
            // Check rest are hex digits (zero or more)
            var valid_hex = true;
            for (last[2..]) |ch| {
                if (!std.ascii.isHex(ch)) {
                    valid_hex = false;
                    break;
                }
            }
            if (valid_hex) return true;
        }
    }

    // Step 6: Return false
    return false;
}

/// Parse host (spec lines 415-437)
///
/// Determines host type and invokes appropriate parser.
pub fn parseHost(
    allocator: std.mem.Allocator,
    input: []const u8,
    is_opaque: bool,
    errors: ?*infra.List(validation.ValidationError),
) !host.Host {
    // P10 Optimization: Check cache for common hosts first
    // Avoids parsing overhead for localhost, 127.0.0.1, ::1, etc.
    // Clone the cached host so it can be safely freed by caller
    if (!is_opaque) {
        if (host_cache.getCachedHost(input)) |cached| {
            return try cached.clone(allocator);
        }
    }

    // Step 1: IPv6 address
    if (input.len > 0 and input[0] == '[') {
        // Step 1.1: Must end with ]
        if (input.len == 0 or input[input.len - 1] != ']') {
            if (errors) |errs| {
                try errs.append(allocator, .{ .type = .ipv6_unclosed });
            }
            return HostParseError.IPv6Unclosed;
        }

        // Step 1.2: Parse IPv6 (remove [ and ])
        const ipv6_input = input[1 .. input.len - 1];
        const ipv6_addr = try ipv6_parser.parseIPv6(allocator, ipv6_input, errors);
        return host.Host{ .ipv6 = ipv6_addr };
    }

    // Step 2: Opaque host
    if (is_opaque) {
        // Opaque-host parsing (spec lines 643-651)
        // Check for forbidden host code points
        for (input) |byte| {
            if (host.isForbiddenHostCodePoint(byte)) {
                if (errors) |errs| {
                    try errs.append(allocator, .{ .type = .host_invalid_code_point });
                }
                return HostParseError.InvalidHost;
            }
        }

        // Percent-encode with C0 control set
        const encoded = try percent_encoding.utf8PercentEncode(
            allocator,
            input,
            encode_sets.EncodeSet.c0_control,
        );
        return host.Host{ .opaque_host = encoded };
    }

    // Step 3: Assert non-empty (caller's responsibility)

    // Step 4: Percent-decode and UTF-8 decode
    const decoded = try percent_encoding.percentDecodeString(allocator, input);
    defer allocator.free(decoded);

    // Step 4.5: Check for forbidden host code points
    for (decoded) |byte| {
        if (host.isForbiddenHostCodePoint(byte)) {
            if (errors) |errs| {
                try errs.append(allocator, .{ .type = .host_invalid_code_point });
            }
            return HostParseError.InvalidHost;
        }
    }

    // Step 5: Domain to ASCII
    const ascii_domain = idna.domainToASCII(allocator, decoded, false) catch {
        return HostParseError.InvalidHost;
    };
    defer allocator.free(ascii_domain);

    // Step 7: Check if ends in number (IPv4)
    if (endsInNumber(ascii_domain)) {
        const ipv4_addr = ipv4_parser.parseIPv4(allocator, ascii_domain, errors) catch {
            return HostParseError.InvalidHost;
        };
        return host.Host{ .ipv4 = ipv4_addr };
    }

    // Step 8: Return domain
    const domain_copy = try allocator.dupe(u8, ascii_domain);
    return host.Host{ .domain = domain_copy };
}

test "host parser - domain" {
    const allocator = std.testing.allocator;

    const h = try parseHost(allocator, "example.com", false, null);
    defer h.deinit(allocator);

    try std.testing.expect(h.isDomain());
    try std.testing.expectEqualStrings("example.com", h.domain);
}

test "host parser - domain uppercase" {
    const allocator = std.testing.allocator;

    const h = try parseHost(allocator, "EXAMPLE.COM", false, null);
    defer h.deinit(allocator);

    try std.testing.expect(h.isDomain());
    try std.testing.expectEqualStrings("example.com", h.domain);
}

test "host parser - ipv4" {
    const allocator = std.testing.allocator;

    const h = try parseHost(allocator, "192.168.1.1", false, null);
    defer h.deinit(allocator);

    try std.testing.expect(h.isIpAddress());
    try std.testing.expectEqual(@as(u32, 0xC0A80101), h.ipv4);
}

test "host parser - ipv6 loopback" {
    const allocator = std.testing.allocator;

    const h = try parseHost(allocator, "[::1]", false, null);
    defer h.deinit(allocator);

    try std.testing.expect(h.isIpAddress());
    try std.testing.expectEqual(@as(u16, 1), h.ipv6[7]);
}

test "host parser - ipv6 without brackets fails" {
    const allocator = std.testing.allocator;

    // IPv6 without brackets should fail (: is forbidden in domains)
    const result = parseHost(allocator, "::1", false, null);
    try std.testing.expectError(HostParseError.InvalidHost, result);
}

test "host parser - opaque host" {
    const allocator = std.testing.allocator;

    const h = try parseHost(allocator, "example.com", true, null);
    defer h.deinit(allocator);

    try std.testing.expectEqualStrings("example.com", h.opaque_host);
}

test "host parser - ends in number" {
    try std.testing.expect(endsInNumber("192.168.1.1"));
    try std.testing.expect(endsInNumber("example.42"));
    try std.testing.expect(endsInNumber("test.0x10"));
    try std.testing.expect(!endsInNumber("example.com"));
    try std.testing.expect(!endsInNumber("test.abc"));
}
