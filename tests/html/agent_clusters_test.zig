//! HTML "obtain a site", as html.agent_clusters keys a Window realm's agent
//! cluster by it ("obtain a similar-origin window agent" step 2): same-site
//! origins - a www1 subdomain and its parent, any port - share a cluster,
//! where another scheme or another registrable domain does not. A
//! WebAssembly.Module crosses between Window realms only inside one.

const std = @import("std");
const html = @import("html");

const agent_clusters = html.agent_clusters;

fn expectSite(origin: []const u8, expected: []const u8) !void {
    const site = try agent_clusters.siteOf(std.testing.allocator, origin);
    defer std.testing.allocator.free(site);
    try std.testing.expectEqualStrings(expected, site);
}

test "a site is the scheme and the registrable domain, without the port" {
    try expectSite("https://www1.web-platform.test:8443", "https://web-platform.test");
    try expectSite("https://web-platform.test:8443", "https://web-platform.test");
    try expectSite("http://www.example.com", "http://example.com");
    try expectSite("https://a.b.whatwg.github.io", "https://whatwg.github.io");
}

test "a host with no registrable domain is its own site" {
    try expectSite("http://127.0.0.1:8000", "http://127.0.0.1");
    try expectSite("http://[::1]:8000", "http://[::1]");
    try expectSite("http://localhost:8000", "http://localhost");
}

test "same-site origins share a key; another scheme or registrable domain does not" {
    const a = try agent_clusters.siteOf(std.testing.allocator, "http://www1.web-platform.test:8000");
    defer std.testing.allocator.free(a);
    const b = try agent_clusters.siteOf(std.testing.allocator, "http://web-platform.test:8001");
    defer std.testing.allocator.free(b);
    const secure = try agent_clusters.siteOf(std.testing.allocator, "https://web-platform.test:8443");
    defer std.testing.allocator.free(secure);
    const other = try agent_clusters.siteOf(std.testing.allocator, "http://not-web-platform.test:8000");
    defer std.testing.allocator.free(other);

    try std.testing.expectEqual(agent_clusters.siteKey(a), agent_clusters.siteKey(b));
    try std.testing.expect(agent_clusters.siteKey(a) != agent_clusters.siteKey(secure));
    try std.testing.expect(agent_clusters.siteKey(a) != agent_clusters.siteKey(other));
    try std.testing.expect(agent_clusters.siteKey(a) != 0);
}

test "a serialized origin that is not a tuple origin has no site" {
    try std.testing.expectError(error.InvalidOrigin, agent_clusters.siteOf(std.testing.allocator, "null"));
}
