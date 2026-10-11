//! HTML's agent clusters (8.1.2.1 "Integration with the JavaScript agent
//! cluster formalism"), as the engine reads them: engine.HostHooks.agentClusterOf,
//! the key a value bound to its agent cluster - a WebAssembly.Module
//! (WebAssembly Web API section 3) - is serialized with and checked against
//! when it is deserialized.
//!
//! Crane runs every Window realm of a Browser in one engine agent and each
//! worker in an agent of its own, so a cluster is a property of the realm:
//!
//! - A Window realm: "obtain a similar-origin window agent" keys its cluster
//!   by the site of its document's origin ("obtain a site": the origin itself
//!   when it is opaque, else its scheme and its host's registrable domain, or
//!   the host when it has none), and by its origin when the browsing context
//!   group is cross-origin isolated. Same-site documents share a cluster, so
//!   document.domain - which never moves a document to another cluster -
//!   plays no part, and a same-site cross-origin frame can receive a module.
//! - A shared worker's (and a service worker's) realm: "obtain a
//!   worker/worklet agent" with isTopLevel true makes a new cluster - its
//!   agent's own.
//! - A dedicated worker's realm: its owner's cluster, which the worker host
//!   records on the worker agent's AgentHost when it obtains the agent; 0
//!   (no cluster known: nothing is checked) until it does.
//!
//! Stated gaps: Crane implements neither the `Origin-Agent-Cluster` header
//! (requestsOAC is always false; Window.originAgentCluster is false) nor the
//! browsing context group's historical agent cluster key map, so the key is
//! the site whatever a previous document of the origin asked for; and the
//! browsing context group is not part of the key, so same-site documents in
//! two groups of one Browser (two tabs) count as one cluster. An opaque
//! origin's cluster is its global's own, so two documents sharing one opaque
//! origin count as two.
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#obtain-similar-origin-window-agent
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#obtain-a-worker/worklet-agent
//! Spec: https://html.spec.whatwg.org/multipage/browsers.html#obtain-a-site

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const dom = @import("dom");
const url = @import("url");

const AgentHost = @import("html_core").agent_host.AgentHost;

/// engine.HostHooks.agentClusterOf for the agents Crane makes - the window
/// agent's (its `host` the Browser's AgentHost) and every worker agent's (its
/// worker host's AgentHost): `realm`'s agent cluster key, never 0 when one is
/// known.
pub fn agentClusterOf(host: ?*anyopaque, realm: runtime.Context) u64 {
    const record = realm.getRealm() orelse return 0;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return 0));
    const kind = global.vtable.name;
    if (std.mem.eql(u8, kind, "Window")) return windowAgentCluster(global);
    // isTopLevel: a new agent cluster, the worker agent's own.
    if (std.mem.eql(u8, kind, "SharedWorkerGlobalScope") or std.mem.eql(u8, kind, "ServiceWorkerGlobalScope")) {
        const agent: usize = @intFromPtr(realm.agent orelse return 0);
        return keyOf("agent", std.mem.asBytes(&agent));
    }
    // A dedicated worker: its owner's, as the worker host recorded it.
    if (std.mem.eql(u8, kind, "DedicatedWorkerGlobalScope")) {
        const agent_host: *const AgentHost = @ptrCast(@alignCast(host orelse return 0));
        return agent_host.agent_cluster;
    }
    return 0;
}

/// `realm`'s agent cluster key, as its agent's hook answers it - what the
/// worker host records for a dedicated worker it makes on its owner's thread
/// ("obtain a worker/worklet agent" step 3: the owner's agent cluster). 0
/// when none is known.
pub fn ofRealm(realm: runtime.Context) u64 {
    const agent = realm.agent orelse return 0;
    return agentClusterOf(engine.agentHost(agent), realm);
}

/// A Window's agent cluster: its document's origin's site, or the origin when
/// the realm is cross-origin isolated (its group's cross-origin isolation
/// mode is not "none": "obtain a similar-origin window agent" step 3).
fn windowAgentCluster(global: *runtime.Instance) u64 {
    const settings = dom.global_settings.of(global) orelse return 0;
    const allocator = global.ctx.allocator;
    const origin = settings.origin(global) catch return 0;
    defer allocator.free(origin);
    // An opaque origin is its own site ("obtain a site" step 1): no other
    // origin is equal to it.
    if (origin.len == 0 or std.mem.eql(u8, origin, "null")) {
        const id: usize = @intFromPtr(global);
        return keyOf("opaque", std.mem.asBytes(&id));
    }
    if (settings.cross_origin_isolated(global)) return keyOf("origin", origin);
    const site = siteOf(allocator, origin) catch return keyOf("origin", origin);
    defer allocator.free(site);
    return keyOf("site", site);
}

/// HTML "obtain a site" for a tuple origin, serialized as `origin`
/// ("scheme://host[:port]"): "scheme://registrable-domain", or
/// "scheme://host" when the host has no registrable domain (an IP address,
/// `localhost`, a public suffix). OWNED.
pub fn siteOf(allocator: std.mem.Allocator, origin: []const u8) ![]u8 {
    const separator = std.mem.indexOf(u8, origin, "://") orelse return error.InvalidOrigin;
    const scheme = origin[0..separator];
    const authority = origin[separator + 3 ..];
    // The port is not part of a site. An IPv6 host is bracketed, and its
    // colons are its own.
    const host_end = if (authority.len > 0 and authority[0] == '[')
        (std.mem.indexOfScalar(u8, authority, ']') orelse return error.InvalidOrigin) + 1
    else
        std.mem.indexOfScalar(u8, authority, ':') orelse authority.len;
    const host_string = authority[0..host_end];
    // 2-3. The host's registrable domain, else the host.
    const host = url.host_parser.parseHost(allocator, host_string, false, null) catch return error.InvalidOrigin;
    defer host.deinit(allocator);
    const registrable = try url.public_suffix.getRegistrableDomain(allocator, host);
    defer if (registrable) |r| allocator.free(r);
    return std.fmt.allocPrint(allocator, "{s}://{s}", .{ scheme, registrable orelse host_string });
}

/// A key for the agent cluster named by `kind` and `name`: equal names of one
/// kind are one cluster. Never 0, which means "no cluster known".
fn keyOf(comptime kind: []const u8, name: []const u8) u64 {
    var hasher = std.hash.Wyhash.init(0);
    hasher.update(kind);
    hasher.update(&.{0});
    hasher.update(name);
    const key = hasher.final();
    return if (key == 0) 1 else key;
}

/// The key a site's agent cluster has - what two same-site Window realms
/// share. For tests.
pub fn siteKey(site: []const u8) u64 {
    return keyOf("site", site);
}
