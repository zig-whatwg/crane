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

/// Static buffer for PSL lookup results
/// Safe because lookupPublicSuffix() callers immediately copy the result
threadlocal var psl_result_buf: [256]u8 = undefined;

/// Lookup public suffix in PSL using the full algorithm
///
/// Implements the PSL matching algorithm:
/// https://publicsuffix.org/list/
///
/// Rules:
/// 1. Exception rules (!): Highest priority - domain is NOT a public suffix
/// 2. Wildcard rules (*): Match any label at that position
/// 3. Exact match: Domain is a public suffix
/// 4. Default: Last label (TLD)
///
/// Returns a slice into the thread-local static buffer.
/// Callers MUST copy the result before calling this function again.
fn lookupPublicSuffix(domain: []const u8) ?[]const u8 {
    // Remove trailing dot for lookup
    const domain_no_dot = if (std.mem.endsWith(u8, domain, "."))
        domain[0 .. domain.len - 1]
    else
        domain;

    if (domain_no_dot.len == 0) return null;

    // Split domain into labels (from right to left)
    // e.g., "www.example.com" → ["www", "example", "com"]
    var labels: [64][]const u8 = undefined;
    var label_count: usize = 0;

    var it = std.mem.splitScalar(u8, domain_no_dot, '.');
    while (it.next()) |label| : (label_count += 1) {
        if (label_count >= labels.len) break;
        labels[label_count] = label;
    }

    if (label_count == 0) return null;

    // Try all possible suffixes from longest to shortest
    // We need to find the longest matching rule in PSL
    var best_match_len: usize = 0;
    var found_match = false;

    // Start with longest suffix (full domain) and work down to single label (TLD)
    var suffix_len: usize = label_count;
    while (suffix_len > 0) : (suffix_len -= 1) {
        // Build suffix string: join labels[label_count - suffix_len..]
        const start_idx = label_count - suffix_len;

        var suffix_buf: [256]u8 = undefined;
        var pos: usize = 0;
        for (labels[start_idx..label_count], 0..) |label, i| {
            if (i > 0) {
                suffix_buf[pos] = '.';
                pos += 1;
            }
            if (pos + label.len >= suffix_buf.len) break;
            @memcpy(suffix_buf[pos..][0..label.len], label);
            pos += label.len;
        }
        const suffix = suffix_buf[0..pos];

        // 1. Check for exception rule (!suffix)
        var exception_buf: [257]u8 = undefined;
        exception_buf[0] = '!';
        if (suffix.len + 1 < exception_buf.len) {
            @memcpy(exception_buf[1..][0..suffix.len], suffix);
            const exception_rule = exception_buf[0 .. suffix.len + 1];

            if (psl_data.PSL_RULES.has(exception_rule)) {
                // Exception rule: the domain WITHOUT the first label is the public suffix
                // e.g., if "!www.ck" is in PSL and we're checking "www.ck",
                // then "ck" is the public suffix
                if (suffix_len > 1) {
                    const ps_start = label_count - (suffix_len - 1);
                    var ps_pos: usize = 0;
                    for (labels[ps_start..label_count], 0..) |label, i| {
                        if (i > 0) {
                            psl_result_buf[ps_pos] = '.';
                            ps_pos += 1;
                        }
                        @memcpy(psl_result_buf[ps_pos..][0..label.len], label);
                        ps_pos += label.len;
                    }
                    return psl_result_buf[0..ps_pos];
                }
            }
        }

        // 2. Check for exact match
        if (psl_data.PSL_RULES.has(suffix)) {
            if (suffix.len > best_match_len) {
                @memcpy(psl_result_buf[0..suffix.len], suffix);
                best_match_len = suffix.len;
                found_match = true;
            }
        }

        // 3. Check for wildcard rule (*.suffix)
        // For wildcard, we need to match one more label
        if (suffix_len > 1) {
            const wildcard_start = label_count - suffix_len + 1;
            var wc_buf: [256]u8 = undefined;
            var wc_pos: usize = 0;
            wc_buf[0] = '*';
            wc_pos = 1;

            for (labels[wildcard_start..label_count]) |label| {
                if (wc_pos + 1 + label.len >= wc_buf.len) break;
                wc_buf[wc_pos] = '.';
                wc_pos += 1;
                @memcpy(wc_buf[wc_pos..][0..label.len], label);
                wc_pos += label.len;
            }
            const wildcard_rule = wc_buf[0..wc_pos];

            if (psl_data.PSL_RULES.has(wildcard_rule)) {
                // Wildcard matches: the full suffix is the public suffix
                if (suffix.len > best_match_len) {
                    @memcpy(psl_result_buf[0..suffix.len], suffix);
                    best_match_len = suffix.len;
                    found_match = true;
                }
            }
        }
    }

    // Return best match or default (last label)
    if (found_match) {
        return psl_result_buf[0..best_match_len];
    }

    // Default: last label (TLD)
    return labels[label_count - 1];
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










