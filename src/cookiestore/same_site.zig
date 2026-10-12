//! Schemeful sites for cookie requests (HTML "obtain a site", RFC 6265bis 5.2).
//! Inputs are serialized URLs/origins, already canonicalized by their owner.
const std = @import("std");
const public_suffix = @import("public_suffix");
const RequestUrl = @import("http_integration.zig").RequestUrl;
const domain_matching = @import("domain_matching.zig");

/// One request's site comparisons. URL/host slices are borrowed for this
/// call; registrable domains are owned until deinit. Repeated redirect
/// hosts share a PSL lookup, without retaining request or browser state.
pub const SiteComparison = struct {
    allocator: std.mem.Allocator,
    origin: ?SiteUrl,
    domains: std.StringHashMapUnmanaged(?[]const u8) = .empty,

    pub fn init(allocator: std.mem.Allocator, origin: []const u8) SiteComparison {
        return .{ .allocator = allocator, .origin = SiteUrl.of(origin) };
    }

    pub fn deinit(self: *SiteComparison) void {
        var values = self.domains.valueIterator();
        while (values.next()) |value| if (value.*) |domain| self.allocator.free(domain);
        self.domains.deinit(self.allocator);
    }

    pub fn matches(self: *SiteComparison, target: []const u8) !bool {
        const a = self.origin orelse return false;
        const b = SiteUrl.of(target) orelse return false;
        if (sameSiteWithoutPsl(a, b)) |answer| return answer;
        const a_domain = try self.registrableDomain(a.host);
        const b_domain = try self.registrableDomain(b.host);
        return std.ascii.eqlIgnoreCase(a_domain, b_domain);
    }

    fn registrableDomain(self: *SiteComparison, host: []const u8) ![]const u8 {
        if (self.domains.get(host)) |cached| return cached orelse host;
        const result = try public_suffix.getRegistrableDomain(self.allocator, .{ .domain = host });
        errdefer if (result) |owned| self.allocator.free(owned);
        try self.domains.put(self.allocator, host, result);
        return result orelse host;
    }
};

const SiteUrl = struct {
    scheme: []const u8,
    host: []const u8,

    fn of(serialized: []const u8) ?SiteUrl {
        const url = RequestUrl.of(serialized) orelse return null;
        return .{ .scheme = serialized[0..std.mem.indexOfScalar(u8, serialized, ':').?], .host = url.host };
    }
};

/// HTML "obtain a site" / "same site", before obtaining registrable domains.
fn sameSiteWithoutPsl(a: SiteUrl, b: SiteUrl) ?bool {
    if (!std.ascii.eqlIgnoreCase(a.scheme, b.scheme)) return false;
    if (a.host.len == 0 or b.host.len == 0) return false;
    if (std.ascii.eqlIgnoreCase(a.host, b.host)) return true;
    if (domain_matching.isIpAddress(a.host) or domain_matching.isIpAddress(b.host)) return false;
    return null;
}

/// HTML "same site": equal schemes and equal registrable domains, falling
/// back to the host for an IP address or a host without a registrable domain.
/// Opaque origins (serialized as "null") are never same-site with a URL.
pub fn sameSite(allocator: std.mem.Allocator, a: []const u8, b: []const u8) !bool {
    return sameSiteParsed(allocator, SiteUrl.of(a) orelse return false, SiteUrl.of(b) orelse return false);
}

/// WebSockets 2.2 step 1 changes ws/wss to http/https before Fetch handles
/// cookies. Both request retrieval and response storage use that same site.
/// A native request without a client starts at its own site, as in Fetch;
/// an explicitly opaque client ("null") is still cross-site.
pub fn websocketSameSite(allocator: std.mem.Allocator, origin: ?[]const u8, target: []const u8) !bool {
    var b = SiteUrl.of(target) orelse return false;
    if (std.ascii.eqlIgnoreCase(b.scheme, "ws")) b.scheme = "http";
    if (std.ascii.eqlIgnoreCase(b.scheme, "wss")) b.scheme = "https";
    const a = SiteUrl.of(origin orelse return true) orelse return false;
    return sameSiteParsed(allocator, a, b);
}

fn sameSiteParsed(allocator: std.mem.Allocator, a: SiteUrl, b: SiteUrl) !bool {
    if (sameSiteWithoutPsl(a, b)) |answer| return answer;
    const a_domain = try public_suffix.getRegistrableDomain(allocator, .{ .domain = a.host });
    defer if (a_domain) |domain| allocator.free(domain);
    const b_domain = try public_suffix.getRegistrableDomain(allocator, .{ .domain = b.host });
    defer if (b_domain) |domain| allocator.free(domain);
    return std.ascii.eqlIgnoreCase(a_domain orelse a.host, b_domain orelse b.host);
}
