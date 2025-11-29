//! WHATWG Fetch Standard - Internal Request Struct
//!
//! This module implements the internal request representation per Fetch spec.
//! This is distinct from the Request WebIDL interface (which wraps this).
//!
//! Spec: https://fetch.spec.whatwg.org/#requests

const std = @import("std");
const Allocator = std.mem.Allocator;
const header_list = @import("header_list.zig");
const HeaderList = header_list.HeaderList;
const body_mod = @import("body.zig");
const Body = body_mod.Body;

// =============================================================================
// Enums per WHATWG Fetch Spec
// =============================================================================

/// Service workers mode for request.
/// Spec: https://fetch.spec.whatwg.org/#concept-request-service-workers-mode
pub const ServiceWorkersMode = enum {
    /// Relevant service workers will get a fetch event.
    all,
    /// No service workers will get events for this fetch.
    none,
};

/// Request initiator.
/// Spec: https://fetch.spec.whatwg.org/#concept-request-initiator
pub const Initiator = enum {
    empty,
    download,
    imageset,
    manifest,
    prefetch,
    prerender,
    xslt,
};

/// Request destination.
/// Spec: https://fetch.spec.whatwg.org/#concept-request-destination
pub const Destination = enum {
    empty,
    audio,
    audioworklet,
    document,
    embed,
    font,
    frame,
    iframe,
    image,
    json,
    manifest,
    object,
    paintworklet,
    report,
    script,
    serviceworker,
    sharedworker,
    style,
    track,
    video,
    webidentity,
    worker,
    xslt,

    /// Check if destination is script-like.
    /// Spec: "A request's destination is script-like if it is audioworklet,
    /// paintworklet, script, serviceworker, sharedworker, or worker."
    pub fn isScriptLike(self: Destination) bool {
        return switch (self) {
            .audioworklet, .paintworklet, .script, .serviceworker, .sharedworker, .worker => true,
            else => false,
        };
    }
};

/// Request priority.
/// Spec: https://fetch.spec.whatwg.org/#concept-request-priority
pub const Priority = enum {
    high,
    low,
    auto,
};

/// Request mode.
/// Spec: https://fetch.spec.whatwg.org/#concept-request-mode
pub const RequestMode = enum {
    same_origin,
    cors,
    no_cors,
    navigate,
    websocket,
};

/// Credentials mode.
/// Spec: https://fetch.spec.whatwg.org/#concept-request-credentials-mode
pub const CredentialsMode = enum {
    omit,
    same_origin,
    include,
};

/// Cache mode.
/// Spec: https://fetch.spec.whatwg.org/#concept-request-cache-mode
pub const CacheMode = enum {
    default,
    no_store,
    reload,
    no_cache,
    force_cache,
    only_if_cached,
};

/// Redirect mode.
/// Spec: https://fetch.spec.whatwg.org/#concept-request-redirect-mode
pub const RedirectMode = enum {
    follow,
    @"error",
    manual,
};

/// Response tainting.
/// Spec: https://fetch.spec.whatwg.org/#concept-request-response-tainting
pub const ResponseTainting = enum {
    basic,
    cors,
    @"opaque",
};

/// Parser metadata.
/// Spec: https://fetch.spec.whatwg.org/#concept-request-parser-metadata
pub const ParserMetadata = enum {
    empty,
    parser_inserted,
    not_parser_inserted,
};

/// Initiator type for Resource Timing.
/// Spec: https://fetch.spec.whatwg.org/#concept-request-initiator-type
pub const InitiatorType = enum {
    audio,
    beacon,
    body,
    css,
    early_hints,
    embed,
    fetch,
    font,
    frame,
    iframe,
    image,
    img,
    input,
    link,
    object,
    ping,
    script,
    track,
    video,
    xmlhttprequest,
    other,
};

/// Referrer policy values.
/// Spec: https://w3c.github.io/webappsec-referrer-policy/#referrer-policy
pub const ReferrerPolicy = enum {
    empty,
    no_referrer,
    no_referrer_when_downgrade,
    same_origin,
    origin,
    strict_origin,
    origin_when_cross_origin,
    strict_origin_when_cross_origin,
    unsafe_url,
};

/// Request origin - either "client" sentinel or actual origin string.
pub const RequestOrigin = union(enum) {
    /// "client" - will be resolved during fetch
    client,
    /// Actual origin (scheme://host:port or "null")
    origin: []const u8,
};

/// Policy container - either "client" sentinel or actual container.
pub const RequestPolicyContainer = union(enum) {
    /// "client" - will be resolved during fetch
    client,
    /// Actual policy container (opaque for now)
    container: *anyopaque,
};

/// Referrer - either special value or URL string.
pub const Referrer = union(enum) {
    no_referrer,
    client,
    url: []const u8,
};

/// Traversable for user prompts.
pub const TraversableForUserPrompts = union(enum) {
    no_traversable,
    client,
    traversable: *anyopaque,
};

/// Redirect taint result.
pub const RedirectTaint = enum {
    same_origin,
    same_site,
    cross_site,
};

/// Request body - either bytes or Body object.
pub const RequestBody = union(enum) {
    bytes: []const u8,
    body: *Body,
};

// =============================================================================
// Internal Request Struct
// =============================================================================

/// Internal request representation per Fetch spec.
///
/// This is the internal representation used by fetch algorithms.
/// The Request WebIDL interface wraps this struct.
///
/// Spec: https://fetch.spec.whatwg.org/#concept-request
pub const InternalRequest = struct {
    allocator: Allocator,

    // === Core Fields ===

    /// HTTP method (default: "GET")
    method: []const u8,

    /// Header list
    header_list: HeaderList,

    /// Request body (null, byte sequence, or Body)
    body: ?RequestBody = null,

    // === Client/Context Fields ===

    /// Client environment settings object (opaque for now)
    client: ?*anyopaque = null,

    /// Reserved client for navigation/worker requests
    reserved_client: ?*anyopaque = null,

    /// ID of client being replaced (for navigations)
    replaces_client_id: []const u8 = "",

    /// Traversable for user prompts
    traversable_for_user_prompts: TraversableForUserPrompts = .client,

    // === Request Metadata ===

    /// Keep request alive after environment terminates
    keepalive: bool = false,

    /// Initiator type for Resource Timing
    initiator_type: ?InitiatorType = null,

    /// Service workers mode
    service_workers_mode: ServiceWorkersMode = .all,

    /// Initiator
    initiator: Initiator = .empty,

    /// Destination type
    destination: Destination = .empty,

    /// Priority
    priority: Priority = .auto,

    /// Internal priority (implementation-defined)
    internal_priority: ?*anyopaque = null,

    // === Origin/Policy Fields ===

    /// Origin ("client" or actual origin)
    origin: RequestOrigin = .client,

    /// Top-level navigation initiator origin
    top_level_navigation_initiator_origin: ?[]const u8 = null,

    /// Policy container ("client" or actual)
    policy_container: RequestPolicyContainer = .client,

    /// Referrer
    referrer: Referrer = .client,

    /// Referrer policy
    referrer_policy: ReferrerPolicy = .empty,

    // === Mode Fields ===

    /// Request mode
    mode: RequestMode = .no_cors,

    /// Use CORS preflight flag
    use_cors_preflight: bool = false,

    /// Credentials mode
    credentials_mode: CredentialsMode = .same_origin,

    /// Use URL credentials flag
    use_url_credentials: bool = false,

    /// Cache mode
    cache_mode: CacheMode = .default,

    /// Redirect mode
    redirect_mode: RedirectMode = .follow,

    // === Integrity/Security Fields ===

    /// Subresource integrity metadata
    integrity_metadata: []const u8 = "",

    /// Cryptographic nonce for CSP
    cryptographic_nonce_metadata: []const u8 = "",

    /// Parser metadata
    parser_metadata: ParserMetadata = .empty,

    // === Navigation Flags ===

    /// Reload navigation flag
    reload_navigation: bool = false,

    /// History navigation flag
    history_navigation: bool = false,

    /// User activation flag
    user_activation: bool = false,

    /// Render blocking flag
    render_blocking: bool = false,

    // === Internal Bookkeeping ===

    /// Local URLs only flag
    local_urls_only: bool = false,

    /// Unsafe request flag (set by fetch()/XHR)
    unsafe_request: bool = false,

    /// URL list (first is original, last is current after redirects)
    url_list: std.ArrayListUnmanaged([]const u8),

    /// Redirect count
    redirect_count: u32 = 0,

    /// Response tainting
    response_tainting: ResponseTainting = .basic,

    /// Prevent no-cache cache-control header modification flag
    prevent_no_cache_cache_control_header_modification: bool = false,

    /// Done flag
    done: bool = false,

    /// Timing allow failed flag
    timing_allow_failed: bool = false,

    const Self = @This();

    /// Initialize a new request with a URL.
    pub fn init(allocator: Allocator, url: []const u8) !*Self {
        const request = try allocator.create(Self);
        errdefer allocator.destroy(request);

        const owned_method = try allocator.dupe(u8, "GET");
        errdefer allocator.free(owned_method);

        const owned_url = try allocator.dupe(u8, url);
        errdefer allocator.free(owned_url);

        request.* = .{
            .allocator = allocator,
            .method = owned_method,
            .header_list = HeaderList.init(allocator),
            .url_list = .{},
        };

        try request.url_list.append(allocator, owned_url);

        return request;
    }

    /// Deinitialize the request.
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.method);
        self.header_list.deinit();

        // Free URL list entries
        for (self.url_list.items) |url| {
            self.allocator.free(url);
        }
        self.url_list.deinit(self.allocator);

        // Free integrity_metadata if it was allocated (non-empty means it was set)
        if (self.integrity_metadata.len > 0) {
            self.allocator.free(self.integrity_metadata);
        }

        // Free body if it's a Body object we own
        if (self.body) |b| {
            switch (b) {
                .body => |body| body.deinit(),
                .bytes => {}, // bytes not owned
            }
        }

        self.allocator.destroy(self);
    }

    // === URL Accessors ===

    /// Get the request's URL (first URL in list).
    /// Spec: "A request has an associated URL (a URL)."
    pub fn getUrl(self: *const Self) []const u8 {
        return self.url_list.items[0];
    }

    /// Get the request's current URL (last URL in list).
    /// Spec: "A request has an associated current URL."
    pub fn currentUrl(self: *const Self) []const u8 {
        return self.url_list.items[self.url_list.items.len - 1];
    }

    /// Add a URL to the URL list (for redirects).
    pub fn addUrl(self: *Self, url: []const u8) !void {
        const owned = try self.allocator.dupe(u8, url);
        try self.url_list.append(self.allocator, owned);
    }

    // === Method ===

    /// Set the request method.
    pub fn setMethod(self: *Self, method: []const u8) !void {
        self.allocator.free(self.method);
        self.method = try self.allocator.dupe(u8, method);
    }

    // === Predicates ===

    /// Is this a subresource request?
    /// Spec: destination is audio, audioworklet, font, image, json, manifest,
    /// paintworklet, script, style, track, video, xslt, or empty.
    pub fn isSubresourceRequest(self: *const Self) bool {
        return switch (self.destination) {
            .audio, .audioworklet, .font, .image, .json, .manifest, .paintworklet, .script, .style, .track, .video, .xslt, .empty => true,
            else => false,
        };
    }

    /// Is this a non-subresource request?
    /// Spec: destination is document, embed, frame, iframe, object, report,
    /// serviceworker, sharedworker, or worker.
    pub fn isNonSubresourceRequest(self: *const Self) bool {
        return switch (self.destination) {
            .document, .embed, .frame, .iframe, .object, .report, .serviceworker, .sharedworker, .worker => true,
            else => false,
        };
    }

    /// Is this a navigation request?
    /// Spec: destination is document, embed, frame, iframe, or object.
    pub fn isNavigationRequest(self: *const Self) bool {
        return switch (self.destination) {
            .document, .embed, .frame, .iframe, .object => true,
            else => false,
        };
    }

    /// Is destination script-like?
    pub fn isDestinationScriptLike(self: *const Self) bool {
        return self.destination.isScriptLike();
    }

    // === Clone ===

    /// Clone a request.
    /// Spec: https://fetch.spec.whatwg.org/#concept-request-clone
    ///
    /// 1. Let newRequest be a copy of request, except for its body.
    /// 2. If request's body is non-null, set newRequest's body to the result
    ///    of cloning request's body.
    /// 3. Return newRequest.
    pub fn clone(self: *Self) !*Self {
        const new_request = try self.allocator.create(Self);
        errdefer self.allocator.destroy(new_request);

        // Copy all fields
        new_request.* = .{
            .allocator = self.allocator,
            .method = try self.allocator.dupe(u8, self.method),
            .header_list = try self.header_list.clone(self.allocator),
            .body = null, // Handle body separately
            .client = self.client,
            .reserved_client = self.reserved_client,
            .replaces_client_id = self.replaces_client_id,
            .traversable_for_user_prompts = self.traversable_for_user_prompts,
            .keepalive = self.keepalive,
            .initiator_type = self.initiator_type,
            .service_workers_mode = self.service_workers_mode,
            .initiator = self.initiator,
            .destination = self.destination,
            .priority = self.priority,
            .internal_priority = self.internal_priority,
            .origin = self.origin,
            .top_level_navigation_initiator_origin = self.top_level_navigation_initiator_origin,
            .policy_container = self.policy_container,
            .referrer = self.referrer,
            .referrer_policy = self.referrer_policy,
            .mode = self.mode,
            .use_cors_preflight = self.use_cors_preflight,
            .credentials_mode = self.credentials_mode,
            .use_url_credentials = self.use_url_credentials,
            .cache_mode = self.cache_mode,
            .redirect_mode = self.redirect_mode,
            .integrity_metadata = self.integrity_metadata,
            .cryptographic_nonce_metadata = self.cryptographic_nonce_metadata,
            .parser_metadata = self.parser_metadata,
            .reload_navigation = self.reload_navigation,
            .history_navigation = self.history_navigation,
            .user_activation = self.user_activation,
            .render_blocking = self.render_blocking,
            .local_urls_only = self.local_urls_only,
            .unsafe_request = self.unsafe_request,
            .url_list = .{},
            .redirect_count = self.redirect_count,
            .response_tainting = self.response_tainting,
            .prevent_no_cache_cache_control_header_modification = self.prevent_no_cache_cache_control_header_modification,
            .done = self.done,
            .timing_allow_failed = self.timing_allow_failed,
        };

        // Clone URL list
        for (self.url_list.items) |url| {
            const owned = try self.allocator.dupe(u8, url);
            try new_request.url_list.append(self.allocator, owned);
        }

        // Clone body if present
        if (self.body) |b| {
            new_request.body = switch (b) {
                .bytes => |bytes| .{ .bytes = bytes },
                .body => |body| .{ .body = try body.clone(self.allocator) },
            };
        }

        return new_request;
    }

    // === Range Header ===

    /// Add a Range header to the request.
    /// Spec: https://fetch.spec.whatwg.org/#add-range-header
    ///
    /// Parameters:
    /// - first: start of range (inclusive)
    /// - last: end of range (inclusive), null for open-ended
    pub fn addRangeHeader(self: *Self, first: u64, last: ?u64) !void {
        var buf: [64]u8 = undefined;
        const range_value = if (last) |l|
            try std.fmt.bufPrint(&buf, "bytes={d}-{d}", .{ first, l })
        else
            try std.fmt.bufPrint(&buf, "bytes={d}-", .{first});

        try self.header_list.append("Range", range_value);
    }
};

// =============================================================================
// Tests
// =============================================================================

test "InternalRequest.init creates request with URL" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com/path");
    defer request.deinit();

    try std.testing.expectEqualStrings("GET", request.method);
    try std.testing.expectEqualStrings("https://example.com/path", request.getUrl());
    try std.testing.expectEqualStrings("https://example.com/path", request.currentUrl());
    try std.testing.expectEqual(@as(usize, 1), request.url_list.items.len);
}

test "InternalRequest default values" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();

    try std.testing.expectEqual(RequestMode.no_cors, request.mode);
    try std.testing.expectEqual(CredentialsMode.same_origin, request.credentials_mode);
    try std.testing.expectEqual(CacheMode.default, request.cache_mode);
    try std.testing.expectEqual(RedirectMode.follow, request.redirect_mode);
    try std.testing.expectEqual(ServiceWorkersMode.all, request.service_workers_mode);
    try std.testing.expectEqual(Destination.empty, request.destination);
    try std.testing.expectEqual(false, request.keepalive);
    try std.testing.expectEqual(false, request.done);
    try std.testing.expectEqual(@as(u32, 0), request.redirect_count);
}

test "InternalRequest.setMethod" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();

    try request.setMethod("POST");
    try std.testing.expectEqualStrings("POST", request.method);
}

test "InternalRequest.addUrl for redirects" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com/original");
    defer request.deinit();

    try request.addUrl("https://example.com/redirected");

    try std.testing.expectEqual(@as(usize, 2), request.url_list.items.len);
    try std.testing.expectEqualStrings("https://example.com/original", request.getUrl());
    try std.testing.expectEqualStrings("https://example.com/redirected", request.currentUrl());
}

test "InternalRequest.isSubresourceRequest" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();

    // Empty destination is subresource
    try std.testing.expect(request.isSubresourceRequest());

    request.destination = .script;
    try std.testing.expect(request.isSubresourceRequest());

    request.destination = .document;
    try std.testing.expect(!request.isSubresourceRequest());
}

test "InternalRequest.isNavigationRequest" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();

    try std.testing.expect(!request.isNavigationRequest());

    request.destination = .document;
    try std.testing.expect(request.isNavigationRequest());

    request.destination = .iframe;
    try std.testing.expect(request.isNavigationRequest());

    request.destination = .worker;
    try std.testing.expect(!request.isNavigationRequest());
}

test "InternalRequest.isDestinationScriptLike" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();

    try std.testing.expect(!request.isDestinationScriptLike());

    request.destination = .script;
    try std.testing.expect(request.isDestinationScriptLike());

    request.destination = .worker;
    try std.testing.expect(request.isDestinationScriptLike());

    request.destination = .image;
    try std.testing.expect(!request.isDestinationScriptLike());
}

test "InternalRequest.clone" {
    const allocator = std.testing.allocator;

    const original = try InternalRequest.init(allocator, "https://example.com");
    defer original.deinit();

    try original.setMethod("POST");
    original.mode = .cors;
    original.credentials_mode = .include;
    try original.header_list.append("Content-Type", "application/json");

    const cloned = try original.clone();
    defer cloned.deinit();

    try std.testing.expectEqualStrings("POST", cloned.method);
    try std.testing.expectEqualStrings("https://example.com", cloned.getUrl());
    try std.testing.expectEqual(RequestMode.cors, cloned.mode);
    try std.testing.expectEqual(CredentialsMode.include, cloned.credentials_mode);
    try std.testing.expect(cloned.header_list.contains("Content-Type"));
}

test "InternalRequest.addRangeHeader" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();

    try request.addRangeHeader(0, 499);
    const range = try request.header_list.get(allocator, "Range");
    defer if (range) |r| allocator.free(r);
    try std.testing.expectEqualStrings("bytes=0-499", range.?);
}

test "InternalRequest.addRangeHeader open-ended" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();

    try request.addRangeHeader(500, null);
    const range = try request.header_list.get(allocator, "Range");
    defer if (range) |r| allocator.free(r);
    try std.testing.expectEqualStrings("bytes=500-", range.?);
}

test "Destination.isScriptLike" {
    try std.testing.expect(Destination.script.isScriptLike());
    try std.testing.expect(Destination.worker.isScriptLike());
    try std.testing.expect(Destination.serviceworker.isScriptLike());
    try std.testing.expect(!Destination.image.isScriptLike());
    try std.testing.expect(!Destination.document.isScriptLike());
}
