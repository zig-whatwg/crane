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
    origin_nonce: ?u128 = null,
    /// BORROWED serialized top-level site, null for none or an opaque top-level origin.
    top_level_site: ?[]const u8 = null,
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
    /// The user agent's blob URL store (a `file.BlobURLStore`), as the
    /// settings object reaches it: its Browser's. BORROWED, as the jar is.
    blob_url_store: ?*anyopaque = null,
    /// Browser-local resolver. Returns an OWNED immutable entry; no global
    /// resolver or realm is retained by the entry or the request.
    capture_blob: ?*const fn (*anyopaque, []const u8) ?*request_mod.CapturedBlobEntry = null,
    /// The settings object's storage key for non-storage purposes,
    /// serialized (storage.StorageKey.serialize): what a blob: request
    /// obtains its blob for. BORROWED for the call.
    storage_key: ?[]const u8 = null,
    /// The settings object's creation URL when its global is a top-level
    /// Window (its navigable's parent is null): scheme fetch "blob" step 5's
    /// "top-level-self-fetch". BORROWED for the call; null otherwise.
    top_level_creation_url: ?[]const u8 = null,
    /// The network context of the settings object's Browser. BORROWED, as
    /// the jar is.
    network: ?*request_mod.NetworkContext = null,
    /// The settings object's policy container: a Window's associated
    /// Document's, a WorkerGlobalScope's own. BORROWED for the call; the
    /// request takes a clone. Null for a global that has none.
    policy_container: ?*const PolicyContainer = null,
    /// Mixed Content 4.3's answer for this settings object, captured by value.
    prohibits_mixed_security_contexts: bool = false,
    /// Where the settings object's global hears of CSP violations its
    /// requests cause (CSP §5.5). BORROWED: the request keeps it while its
    /// client is there. Null for a global that reports none.
    csp_violation_reporter: ?request_mod.CspViolationReporter = null,
    /// Where the settings object's global hears of its requests' timing
    /// (Resource Timing "mark resource timing"). BORROWED, as
    /// csp_violation_reporter is. Null for a global that reports none.
    timing_reporter: ?request_mod.TimingReporter = null,
    /// The service workers its requests go to (Service Workers "Handle
    /// Fetch" step 10): set only while a service worker controls the
    /// settings object. BORROWED: its Browser outlives every fetch.
    service_worker: ?request_mod.ServiceWorkerRoute = null,
    /// SRI §3.8.3. BORROWED with the CSP reporter's client lifetime.
    integrity_violation_reporter: ?request_mod.IntegrityViolationReporter = null,
};

/// Fetch "populate request from client", for a request whose client is the
/// settings object `client` describes. Also resolves a "client" referrer to
/// its source, and gives the request the client's cookie jar - neither is a
/// step of the algorithm, but both read the client, which only the caller
/// can reach.
fn isBlobUrl(url: []const u8) bool {
    return std.ascii.startsWithIgnoreCase(url, "blob:");
}

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
            if (origin.len > 0) {
                try request.setOrigin(origin);
                request.origin_nonce = client.origin_nonce;
            }
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

    // Mixed Content 4.3: take the client's answer now; redirects and clones
    // must not ask a later document or retain the settings object.
    request.prohibits_mixed_security_contexts = client.prohibits_mixed_security_contexts;

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

    // The blob URL store scheme fetch "blob" obtains a blob from: the
    // client's Browser's, never another Browser's.
    if (request.blob_url_store == null) request.blob_url_store = client.blob_url_store;

    // Scheme fetch "blob" steps 3-5, taken now - only a blob: request reads
    // them, so no other request copies anything: the environment's storage
    // key, and whether the client is a top-level Window fetching its own
    // creation URL (a blob URL never redirects).
    if (isBlobUrl(request.currentUrl())) {
        if (!request.blob_url_captured) if (client.capture_blob) |capture| {
            const entry = if (request.blob_url_store) |store| capture(store, request.currentUrl()) else null;
            defer if (entry) |e| e.release();
            request.setCapturedBlobEntry(entry);
        };
        if (request.blob_storage_key == null) {
            if (client.storage_key) |key| try request.setBlobStorageKey(key);
        }
        if (client.top_level_creation_url) |creation_url| {
            if (std.mem.eql(u8, creation_url, request.currentUrl())) request.blob_top_level_self_fetch = true;
        }
    }

    // Fetch determine the network partition key: (top-level site, null).
    if (request.network_partition_key == null) {
        if (client.top_level_site) |site| request.network_partition_key = try request.allocator.dupe(u8, site);
    }

    // The network the request goes out on: its client's Browser's
    // connections and TLS options, never another Browser's.
    if (request.network == null) request.network = client.network;

    // CSP §2.4.2: a violation the request causes is its client's global's.
    if (request.csp_violation_reporter == null) request.csp_violation_reporter = client.csp_violation_reporter;

    // Fetch "fetch response handover" step 4.3: the report timing steps run
    // given the request's client's global.
    if (request.timing_reporter == null) request.timing_reporter = client.timing_reporter;

    // Service Workers "Handle Fetch" step 10: a subresource request goes to
    // its client's active service worker - one the client has when it is
    // populated.
    if (request.service_worker == null) request.service_worker = client.service_worker;
    if (request.integrity_violation_reporter == null) request.integrity_violation_reporter = client.integrity_violation_reporter;
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

test "populate request from client: only a blob: request takes the storage key, and a top-level self-fetch is recognised" {
    const allocator = std.testing.allocator;
    const key = "https://a.test https://a.test 0";
    const client: RequestClient = .{ .origin = "https://a.test", .storage_key = key, .top_level_creation_url = "blob:https://a.test/1" };

    const other = try InternalRequest.init(allocator, "https://a.test/x");
    defer other.deinit();
    try populateRequestFromClient(other, client);
    try std.testing.expect(other.blob_storage_key == null);
    try std.testing.expect(!other.blob_top_level_self_fetch);

    const self_fetch = try InternalRequest.init(allocator, "blob:https://a.test/1");
    defer self_fetch.deinit();
    try populateRequestFromClient(self_fetch, client);
    try std.testing.expectEqualStrings(key, self_fetch.blob_storage_key.?);
    try std.testing.expect(self_fetch.blob_top_level_self_fetch);

    const another_blob = try InternalRequest.init(allocator, "blob:https://a.test/2");
    defer another_blob.deinit();
    try populateRequestFromClient(another_blob, client);
    try std.testing.expectEqualStrings(key, another_blob.blob_storage_key.?);
    try std.testing.expect(!another_blob.blob_top_level_self_fetch);

    // A clone carries both.
    const copy = try self_fetch.clone();
    defer copy.deinit();
    try std.testing.expectEqualStrings(key, copy.blob_storage_key.?);
    try std.testing.expect(copy.blob_storage_key.?.ptr != self_fetch.blob_storage_key.?.ptr);
    try std.testing.expect(copy.blob_top_level_self_fetch);
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
