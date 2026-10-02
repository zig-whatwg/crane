//! A request's client, as fetch reads it: what "populate request from
//! client" takes from an environment settings object, and the user agent's
//! cookie jar the settings object reaches.
//!
//! The settings object is HTML's, and fetch knows nothing of globals:
//! `dom.global_settings.requestClient` reads one out of a global into a
//! `RequestClient`, and `populateRequestFromClient` applies it to a request.
//! Every caller that fetches on a global's behalf - `fetch()`,
//! XMLHttpRequest, WebSocket, the script and worker loaders - uses the pair,
//! so "the client" means the same thing to all of them.
//!
//! Spec: https://fetch.spec.whatwg.org/#populate-request-from-client

const std = @import("std");
const request_mod = @import("request.zig");
const InternalRequest = request_mod.InternalRequest;
const CookieJar = request_mod.CookieJar;
const PolicyContainer = request_mod.PolicyContainer;

/// What a request takes from its client. Every slice is borrowed for the
/// call that applies it.
pub const RequestClient = struct {
    /// The settings object's origin, serialized - "null" for an opaque one.
    /// Null while the global does not know it yet: the request's origin
    /// then stays "client".
    origin: ?[]const u8 = null,
    /// What Referrer Policy's "determine request's referrer" takes as the
    /// referrer source of a "client" referrer: a Window's document's URL, a
    /// worker's creation URL. Null or empty for none.
    referrer_source: ?[]const u8 = null,
    /// A Window's navigable's traversable - the Window stands in for it, as
    /// only whether there is one is ever read (HTTP-network-or-cache fetch
    /// step 14). Null for any other global: "no-traversable".
    traversable: ?*anyopaque = null,
    /// The user agent's cookie jar, as the settings object reaches it.
    /// BORROWED: the Browser that owns it outlives every fetch.
    cookie_jar: ?*CookieJar = null,
    /// The settings object's policy container: a Window's associated
    /// Document's, a WorkerGlobalScope's own. BORROWED for the call; the
    /// request takes a clone. Null for a global that has none.
    policy_container: ?*const PolicyContainer = null,
};

/// Fetch "populate request from client", for a request whose client is the
/// settings object `client` describes. Also resolves a "client" referrer to
/// its source, and gives the request the client's cookie jar - neither is a
/// step of the algorithm, but both read the client, which only the caller
/// can reach.
pub fn populateRequestFromClient(request: *InternalRequest, client: RequestClient) !void {
    // 1. If request's traversable for user prompts is "client": set it to
    //    "no-traversable", then to the client's global's navigable's
    //    traversable navigable if the global is a Window with a navigable.
    if (request.traversable_for_user_prompts == .client) {
        request.traversable_for_user_prompts = if (client.traversable) |t| .{ .traversable = t } else .no_traversable;
    }
    // 2. If request's origin is "client": set it to request's client's
    //    origin. (One the global does not know yet leaves it "client".)
    if (request.origin == .client) {
        if (client.origin) |origin| {
            if (origin.len > 0) try request.setOrigin(origin);
        }
    }
    // 3. "If request's policy container is "client": if request's client is
    //    non-null, set request's policy container to a clone of request's
    //    client's policy container; otherwise set it to a new policy
    //    container." A client whose global keeps no container leaves it
    //    "client", which main fetch reads as the defaults.
    if (request.policy_container == .client) {
        if (client.policy_container) |container| {
            request.setPolicyContainer(try container.clone(request.allocator));
        }
    }

    // Referrer Policy "determine request's referrer", step 3's "client" case,
    // resolved here where the client is known; main fetch step 9 takes it
    // from there as a URL referrer, which is the same referrerSource. A
    // client with an opaque origin names no referrer.
    if (request.referrer == .client) {
        if (request.origin == .origin and std.mem.eql(u8, request.origin.origin, "null")) {
            request.setReferrer(.no_referrer);
        } else if (client.referrer_source) |source| {
            if (source.len > 0) try request.setReferrerUrl(source);
        }
    }

    // The jar HTTP-network-or-cache fetch sends cookies from, and
    // HTTP-network fetch stores a response's in, when the request includes
    // credentials.
    if (request.cookie_jar == null) request.cookie_jar = client.cookie_jar;
}

test "populate request from client: traversable, origin, referrer and jar" {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    var window: u8 = 0;

    const request = try InternalRequest.init(allocator, "https://example.com/a");
    defer request.deinit();
    try populateRequestFromClient(request, .{
        .origin = "https://example.com",
        .referrer_source = "https://example.com/page",
        .traversable = &window,
        .cookie_jar = &jar,
    });
    try std.testing.expect(request.traversable_for_user_prompts == .traversable);
    try std.testing.expectEqualStrings("https://example.com", request.origin.origin);
    try std.testing.expectEqualStrings("https://example.com/page", request.referrer.url);
    try std.testing.expect(request.cookie_jar == &jar);
}

test "populate request from client: a worker has no traversable, an opaque origin no referrer" {
    const allocator = std.testing.allocator;
    const request = try InternalRequest.init(allocator, "https://example.com/a");
    defer request.deinit();
    try populateRequestFromClient(request, .{ .origin = "null", .referrer_source = "https://example.com/page" });
    try std.testing.expect(request.traversable_for_user_prompts == .no_traversable);
    try std.testing.expectEqualStrings("null", request.origin.origin);
    try std.testing.expect(request.referrer == .no_referrer);
    try std.testing.expect(request.cookie_jar == null);
}

test "populate request from client: what the request already has stands" {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    var other = CookieJar.init(allocator);
    defer other.deinit();

    const request = try InternalRequest.init(allocator, "https://example.com/a");
    defer request.deinit();
    try request.setOrigin("https://other.example");
    request.setReferrer(.no_referrer);
    request.traversable_for_user_prompts = .no_traversable;
    request.cookie_jar = &other;
    var window: u8 = 0;
    try populateRequestFromClient(request, .{ .origin = "https://example.com", .referrer_source = "https://example.com/", .traversable = &window, .cookie_jar = &jar });
    try std.testing.expectEqualStrings("https://other.example", request.origin.origin);
    try std.testing.expect(request.referrer == .no_referrer);
    try std.testing.expect(request.traversable_for_user_prompts == .no_traversable);
    try std.testing.expect(request.cookie_jar == &other);
}

test "populate request from client: the request takes a clone of the client's policy container" {
    const allocator = std.testing.allocator;
    var container = try PolicyContainer.fromResponse(allocator, "no-referrer");
    defer container.deinit();

    const request = try InternalRequest.init(allocator, "https://example.com/a");
    defer request.deinit();
    try populateRequestFromClient(request, .{ .origin = "https://example.com", .policy_container = &container });
    try std.testing.expect(request.policy_container == .container);
    try std.testing.expectEqual(request_mod.ReferrerPolicy.no_referrer, request.policyContainerReferrerPolicy());
    // A clone: the client's later changes do not reach the request.
    container.referrer_policy = .unsafe_url;
    try std.testing.expectEqual(request_mod.ReferrerPolicy.no_referrer, request.policyContainerReferrerPolicy());
}

test "populate request from client: a request's own policy container stands" {
    const allocator = std.testing.allocator;
    var container = try PolicyContainer.fromResponse(allocator, "no-referrer");
    defer container.deinit();

    const request = try InternalRequest.init(allocator, "https://example.com/a");
    defer request.deinit();
    request.setPolicyContainer(try PolicyContainer.fromResponse(allocator, "origin"));
    try populateRequestFromClient(request, .{ .policy_container = &container });
    try std.testing.expectEqual(request_mod.ReferrerPolicy.origin, request.policyContainerReferrerPolicy());
}
