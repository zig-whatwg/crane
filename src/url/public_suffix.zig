//! Public Suffix List Support
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#host-public-suffix
//! Spec Reference: Lines 311-350
//!
//! The Public Suffix List (PSL) is used to determine domain boundaries for
//! security purposes. This is used in origin calculations, cookie scoping,
//! and URL rendering.
//!
//! Reference: https://publicsuffix.org/

const std = @import("std");
const Host = @import("host").Host;
const psl_data = @import("public_suffix_data.zig");

/// Get the public suffix of a host (spec lines 311-322)
///
/// Returns null if:
/// - host is not a domain (IPv4, IPv6, opaque, or empty)
/// - host is on the PSL but has no public suffix
///
/// The public suffix is the portion of the domain that appears on the
/// Public Suffix List. For example:
/// - "example.com" → "com"
/// - "github.io" → "github.io"
/// - "whatwg.github.io" → "github.io"
pub fn getPublicSuffix(allocator: std.mem.Allocator, host: Host) !?[]const u8 {
    // 1. If host is not a domain, return null
    switch (host) {
        .domain => |domain| {
            // 2. Check if host ends with trailing dot
            const trailing_dot = if (std.mem.endsWith(u8, domain, ".")) "." else "";

            // 3. Run PSL algorithm to get public suffix
            const public_suffix = lookupPublicSuffix(domain) orelse return null;

            // 4. Assert: publicSuffix is ASCII and doesn't end with "."
            std.debug.assert(!std.mem.endsWith(u8, public_suffix, "."));

            // 5. Return publicSuffix + trailingDot
            if (trailing_dot.len > 0) {
                return try std.fmt.allocPrint(allocator, "{s}.", .{public_suffix});
            } else {
                return try allocator.dupe(u8, public_suffix);
            }
        },
        else => return null,
    }
}

/// Get the registrable domain of a host (spec lines 323-333)
///
/// Returns null if:
/// - host is not a domain
/// - host's public suffix is null
/// - host's public suffix equals host (TLD with no subdomain)
///
/// The registrable domain is the public suffix plus one additional label.
/// For example:
/// - "www.example.com" → "example.com"
/// - "sub.www.example.com" → "example.com"
/// - "whatwg.github.io" → "whatwg.github.io"
pub fn getRegistrableDomain(allocator: std.mem.Allocator, host: Host) !?[]const u8 {
    // 1. Get public suffix
    const public_suffix = try getPublicSuffix(allocator, host);
    defer if (public_suffix) |ps| allocator.free(ps);

    if (public_suffix == null) return null;

    const ps = public_suffix.?;

    switch (host) {
        .domain => |domain| {
            // Remove trailing dot for comparison
            const domain_no_dot = if (std.mem.endsWith(u8, domain, "."))
                domain[0 .. domain.len - 1]
            else
                domain;

            const ps_no_dot = if (std.mem.endsWith(u8, ps, "."))
                ps[0 .. ps.len - 1]
            else
                ps;

            // If public suffix equals host, return null
            if (std.mem.eql(u8, domain_no_dot, ps_no_dot)) return null;

            // 2. Check trailing dot
            const trailing_dot = if (std.mem.endsWith(u8, domain, ".")) "." else "";

            // 3. Run PSL algorithm to get registrable domain
            const registrable = lookupRegistrableDomain(domain) orelse return null;

            // 4. Assert: registrableDomain is ASCII and doesn't end with "."
            std.debug.assert(!std.mem.endsWith(u8, registrable, "."));

            // 5. Return registrableDomain + trailingDot
            if (trailing_dot.len > 0) {
                return try std.fmt.allocPrint(allocator, "{s}.", .{registrable});
            } else {
                return try allocator.dupe(u8, registrable);
            }
        },
        else => return null,
    }
}

/// Look up a public suffix with the PSL formal algorithm. Walk labels from
/// the right, retaining the longest exact/wildcard rule; an exception wins.
/// The result borrows `domain` (without its final dot). No label count or
/// serialized-host buffer bounds the lookup. Chromium's
/// GetRegistryInTrimmedHost likewise returns a slice of the original host.
fn lookupPublicSuffix(domain: []const u8) ?[]const u8 {
    const host = if (std.mem.endsWith(u8, domain, ".")) domain[0 .. domain.len - 1] else domain;
    if (host.len == 0) return null;

    // No matching rule means the implicit `*`: the rightmost label.
    var start = if (std.mem.lastIndexOfScalar(u8, host, '.')) |dot| dot + 1 else 0;
    var best = host[start..];
    // Prefixing a rule with ! or *. needs space only for a TABLE entry,
    // not for the input host. Oversized candidates cannot be in the map.
    var rule: [psl_data.PSL_RULES.max_len]u8 = undefined;
    while (true) {
        const suffix = host[start..];
        // PSL exception: remove the exception's leftmost label.
        if (suffix.len < rule.len) {
            rule[0] = '!';
            @memcpy(rule[1 .. suffix.len + 1], suffix);
            if (psl_data.PSL_RULES.has(rule[0 .. suffix.len + 1])) {
                const dot = std.mem.indexOfScalar(u8, suffix, '.') orelse return null;
                return suffix[dot + 1 ..];
            }
        }
        if (psl_data.PSL_RULES.has(suffix) and suffix.len > best.len) best = suffix;
        if (start == 0) break;

        const before_dot = start - 1;
        const previous = if (std.mem.lastIndexOfScalar(u8, host[0..before_dot], '.')) |dot| dot + 1 else 0;
        // `*.suffix` consumes exactly the preceding label, however long it
        // is. The match is an input slice, never a reconstructed string.
        if (suffix.len + 2 <= rule.len) {
            rule[0] = '*';
            rule[1] = '.';
            @memcpy(rule[2 .. suffix.len + 2], suffix);
            if (psl_data.PSL_RULES.has(rule[0 .. suffix.len + 2])) best = host[previous..];
        }
        start = previous;
    }
    return best;
}

/// Lookup registrable domain in PSL
///
/// Returns the public suffix plus one additional label
fn lookupRegistrableDomain(domain: []const u8) ?[]const u8 {
    // Remove trailing dot for lookup
    const domain_no_dot = if (std.mem.endsWith(u8, domain, "."))
        domain[0 .. domain.len - 1]
    else
        domain;

    // Get public suffix
    const ps = lookupPublicSuffix(domain_no_dot) orelse return null;

    // If domain equals public suffix, no registrable domain
    if (std.mem.eql(u8, domain_no_dot, ps)) return null;

    // Find the label before the public suffix
    const ps_len = ps.len;
    if (domain_no_dot.len <= ps_len) return null;

    // Should have a dot before the suffix
    const before_suffix = domain_no_dot[0 .. domain_no_dot.len - ps_len];
    if (before_suffix.len == 0 or before_suffix[before_suffix.len - 1] != '.') {
        return null;
    }

    // Find the last dot before the public suffix
    const without_dot = before_suffix[0 .. before_suffix.len - 1];
    if (std.mem.lastIndexOfScalar(u8, without_dot, '.')) |last_dot| {
        // Return from after that dot to end (including public suffix)
        return domain_no_dot[last_dot + 1 ..];
    } else {
        // No more dots, so the whole domain is the registrable domain
        return domain_no_dot;
    }
}

// Tests
