//! Schemeful sites for cookie requests (HTML "obtain a site", RFC 6265bis 5.2).
//! Inputs are serialized URLs/origins, already canonicalized by their owner.
const std = @import("std");
const public_suffix = @import("public_suffix");
const RequestUrl = @import("http_integration.zig").RequestUrl;
const domain_matching = @import("domain_matching.zig");

/// HTML "same site": equal schemes and equal registrable domains, falling
/// back to the host for an IP address or a host without a registrable domain.
/// Opaque origins (serialized as "null") are never same-site with a URL.
pub fn sameSite(allocator: std.mem.Allocator, a: []const u8, b: []const u8) !bool {
    const a_url = RequestUrl.of(a) orelse return false;
    const b_url = RequestUrl.of(b) orelse return false;
    const a_scheme = a[0..std.mem.indexOfScalar(u8, a, ':').?];
    const b_scheme = b[0..std.mem.indexOfScalar(u8, b, ':').?];
    if (!std.ascii.eqlIgnoreCase(a_scheme, b_scheme)) return false;
    if (a_url.host.len == 0 or b_url.host.len == 0) return false;
    // The common same-host case needs neither PSL lookups nor allocations.
    if (std.ascii.eqlIgnoreCase(a_url.host, b_url.host)) return true;
    if (domain_matching.isIpAddress(a_url.host) or domain_matching.isIpAddress(b_url.host)) return false;

    const a_domain = try public_suffix.getRegistrableDomain(allocator, .{ .domain = a_url.host });
    defer if (a_domain) |domain| allocator.free(domain);
    const b_domain = try public_suffix.getRegistrableDomain(allocator, .{ .domain = b_url.host });
    defer if (b_domain) |domain| allocator.free(domain);
    return std.ascii.eqlIgnoreCase(a_domain orelse a_url.host, b_domain orelse b_url.host);
}
