//! ⚠️ DEPRECATED: Temporary mock - will be removed when real impl exists
//!
//! Mock HTML Environment Settings Object for Fetch
//!
//! This mock will be removed when the real EnvironmentSettingsObject
//! is implemented. Do not add new dependencies on this mock.
//!
//! TODO(html-spec): Replace this mock with real HTML environment settings object
//! when the HTML specification is implemented.
//! Spec: https://html.spec.whatwg.org/#environment-settings-object
//!
//! This mock provides the minimum interface needed by the Fetch specification:
//! - Origin (for CORS, same-origin checks)
//! - Base URL (for relative URL resolution)
//! - Policy container (for referrer policy, CSP)
//! - Global object (for task queuing)
//! - API base URL
//! - Cross-origin isolated capability
//!
//! The real implementation will:
//! - Be associated with actual Window/Worker/Worklet global objects
//! - Properly inherit from environment base class
//! - Support the full HTML environment lifecycle
//! - Integrate with document/worker creation and destruction

const std = @import("std");
const Allocator = std.mem.Allocator;
const origin_mod = @import("../url/origin.zig");
const Origin = origin_mod.Origin;
const TupleOrigin = origin_mod.TupleOrigin;
const Host = @import("../url/host.zig").Host;

// =============================================================================
// Policy Container Mock
// =============================================================================

/// Mock referrer policy.
/// TODO(referrer-spec): Replace with full implementation from Phase 3.4.
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

    /// Get the default referrer policy.
    pub fn default() ReferrerPolicy {
        return .strict_origin_when_cross_origin;
    }
};

/// Mock embedder policy.
pub const EmbedderPolicy = struct {
    value: Value = .unsafe_none,
    reporting_endpoint: ?[]const u8 = null,

    pub const Value = enum {
        unsafe_none,
        require_corp,
        credentialless,
    };
};

/// Mock policy container.
///
/// TODO(html-spec): Replace with full implementation when HTML/CSP specs
/// are implemented.
///
/// Spec: https://html.spec.whatwg.org/#policy-container
pub const PolicyContainer = struct {
    allocator: Allocator,

    /// CSP list (simplified - just tracks if present).
    /// TODO(csp-spec): Replace with actual CSP list.
    csp_list: std.ArrayListUnmanaged([]const u8),

    /// Embedder policy.
    embedder_policy: EmbedderPolicy = .{},

    /// Referrer policy.
    referrer_policy: ReferrerPolicy = .strict_origin_when_cross_origin,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .csp_list = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.csp_list.items) |csp| {
            self.allocator.free(csp);
        }
        self.csp_list.deinit(self.allocator);
    }

    /// Clone the policy container.
    pub fn clone(self: *const Self, allocator: Allocator) !Self {
        var new_csp_list: std.ArrayListUnmanaged([]const u8) = .{};
        errdefer {
            for (new_csp_list.items) |csp| {
                allocator.free(csp);
            }
            new_csp_list.deinit(allocator);
        }

        for (self.csp_list.items) |csp| {
            const copy = try allocator.dupe(u8, csp);
            try new_csp_list.append(allocator, copy);
        }

        return .{
            .allocator = allocator,
            .csp_list = new_csp_list,
            .embedder_policy = self.embedder_policy,
            .referrer_policy = self.referrer_policy,
        };
    }
};

// =============================================================================
// Environment Settings Object Mock
// =============================================================================

/// Mock environment settings object.
///
/// In real HTML spec implementation, this would be associated with:
/// - Window (for document contexts)
/// - WorkerGlobalScope (for worker contexts)
/// - WorkletGlobalScope (for worklet contexts)
///
/// TODO(html-spec): Replace with full implementation from HTML spec.
pub const EnvironmentSettingsObject = struct {
    allocator: Allocator,

    /// The origin of the environment.
    /// Used for same-origin checks, CORS, etc.
    origin: Origin,
    owns_origin: bool = true,

    /// Base URL string for resolving relative URLs.
    /// In documents, this is typically document.baseURI.
    base_url: []const u8,
    owns_base_url: bool = true,

    /// API base URL (may differ from base_url in some contexts).
    api_base_url: []const u8,
    owns_api_base_url: bool = false, // Usually same as base_url

    /// Policy container holding security policies.
    policy_container: PolicyContainer,

    /// Reference to the global object (Window, WorkerGlobalScope, etc.)
    /// Currently typed as anyopaque since we don't have real HTML globals.
    global_object: *anyopaque,

    /// Whether this environment has cross-origin isolated capability.
    /// Affects timing precision and SharedArrayBuffer availability.
    cross_origin_isolated_capability: bool = false,

    /// Unique ID for this environment (for replaces_client_id, etc.)
    id: []const u8,

    const Self = @This();

    // === Creation ===

    /// Create a new mock environment settings object.
    pub fn init(
        allocator: Allocator,
        origin: Origin,
        base_url: []const u8,
        global_object: *anyopaque,
    ) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        const id = try generateId(allocator);
        errdefer allocator.free(id);

        const owned_base_url = try allocator.dupe(u8, base_url);
        errdefer allocator.free(owned_base_url);

        self.* = .{
            .allocator = allocator,
            .origin = origin,
            .base_url = owned_base_url,
            .api_base_url = owned_base_url, // Same by default
            .policy_container = PolicyContainer.init(allocator),
            .global_object = global_object,
            .id = id,
        };
        return self;
    }

    /// Create from a URL string.
    /// Creates a tuple origin from the URL.
    pub fn initFromUrl(
        allocator: Allocator,
        url: []const u8,
        global_object: *anyopaque,
    ) !*Self {
        // Parse scheme, host, port from URL for origin.
        // Simplified parsing - assumes well-formed URL.
        const origin = try parseOriginFromUrl(allocator, url);
        errdefer origin.deinit(allocator);

        return try init(allocator, origin, url, global_object);
    }

    pub fn deinit(self: *Self) void {
        if (self.owns_origin) {
            self.origin.deinit(self.allocator);
        }
        if (self.owns_base_url) {
            self.allocator.free(self.base_url);
        }
        if (self.owns_api_base_url and !std.mem.eql(u8, self.api_base_url, self.base_url)) {
            self.allocator.free(self.api_base_url);
        }
        self.policy_container.deinit();
        self.allocator.free(self.id);
        self.allocator.destroy(self);
    }

    // === Getters (per HTML spec) ===

    /// Get the origin.
    /// HTML spec: "An environment settings object's origin is..."
    pub fn getOrigin(self: *const Self) Origin {
        return self.origin;
    }

    /// Get the base URL.
    pub fn getBaseUrl(self: *const Self) []const u8 {
        return self.base_url;
    }

    /// Get the API base URL.
    pub fn getApiBaseUrl(self: *const Self) []const u8 {
        return self.api_base_url;
    }

    /// Get the policy container.
    pub fn getPolicyContainer(self: *Self) *PolicyContainer {
        return &self.policy_container;
    }

    /// Get the global object.
    pub fn getGlobalObject(self: *const Self) *anyopaque {
        return self.global_object;
    }

    /// Get cross-origin isolated capability.
    pub fn getCrossOriginIsolatedCapability(self: *const Self) bool {
        return self.cross_origin_isolated_capability;
    }

    /// Get environment ID.
    pub fn getId(self: *const Self) []const u8 {
        return self.id;
    }

    // === Helpers ===

    /// Check if origin is same-origin with a URL string.
    pub fn isSameOriginWithUrl(self: *const Self, url: []const u8) !bool {
        const url_origin = try parseOriginFromUrl(self.allocator, url);
        defer url_origin.deinit(self.allocator);
        return self.isSameOrigin(url_origin);
    }

    /// Check if two origins are same-origin.
    pub fn isSameOrigin(self: *const Self, other: Origin) bool {
        return sameOrigin(self.origin, other);
    }

    /// Check if same-origin-domain with another environment.
    /// TODO(html-spec): Implement document.domain handling.
    pub fn isSameOriginDomain(self: *const Self, other: *const Self) bool {
        return sameOrigin(self.origin, other.origin);
    }
};

// =============================================================================
// Helper Functions
// =============================================================================

/// Generate a unique environment ID.
fn generateId(allocator: Allocator) ![]const u8 {
    // Use random bytes for unique ID.
    var buf: [16]u8 = undefined;
    std.crypto.random.bytes(&buf);
    return try std.fmt.allocPrint(allocator, "{}", .{std.fmt.fmtSliceHexLower(&buf)});
}

/// Parse origin from a URL string.
/// Simplified implementation - assumes well-formed URL.
fn parseOriginFromUrl(allocator: Allocator, url: []const u8) !Origin {
    // Find scheme.
    const scheme_end = std.mem.indexOf(u8, url, "://") orelse {
        return Origin{ .opaque_origin = {} };
    };
    const scheme = url[0..scheme_end];

    // Check for opaque schemes.
    if (std.mem.eql(u8, scheme, "data") or
        std.mem.eql(u8, scheme, "javascript") or
        std.mem.eql(u8, scheme, "about"))
    {
        return Origin{ .opaque_origin = {} };
    }

    // Parse host and port.
    const after_scheme = url[scheme_end + 3 ..];

    // Find end of authority (path starts with /).
    const path_start = std.mem.indexOf(u8, after_scheme, "/") orelse after_scheme.len;
    const authority = after_scheme[0..path_start];

    // Check for port.
    var host_str: []const u8 = undefined;
    var port: ?u16 = null;

    if (std.mem.lastIndexOf(u8, authority, ":")) |colon_pos| {
        // Could be port or IPv6.
        const after_colon = authority[colon_pos + 1 ..];
        if (std.fmt.parseInt(u16, after_colon, 10)) |p| {
            host_str = authority[0..colon_pos];
            port = p;
        } else |_| {
            host_str = authority;
        }
    } else {
        host_str = authority;
    }

    // Create owned copies.
    const owned_scheme = try allocator.dupe(u8, scheme);
    errdefer allocator.free(owned_scheme);

    const owned_host = try allocator.dupe(u8, host_str);

    return Origin{
        .tuple = TupleOrigin{
            .scheme = owned_scheme,
            .host = Host{ .domain = owned_host },
            .port = port,
        },
    };
}

/// Check if two origins are same-origin.
///
/// Spec: https://html.spec.whatwg.org/#same-origin
pub fn sameOrigin(a: Origin, b: Origin) bool {
    switch (a) {
        .opaque_origin => {
            // Opaque origins are only same-origin with themselves (by reference).
            // Since we can't check reference equality here, opaque != opaque.
            return false;
        },
        .tuple => |ta| {
            switch (b) {
                .opaque_origin => return false,
                .tuple => |tb| {
                    // Same scheme, host, and port.
                    if (!std.mem.eql(u8, ta.scheme, tb.scheme)) return false;
                    if (!hostsEqual(ta.host, tb.host)) return false;
                    if (ta.port != tb.port) return false;
                    return true;
                },
            }
        },
    }
}

/// Check if two hosts are equal.
fn hostsEqual(a: Host, b: Host) bool {
    switch (a) {
        .domain => |da| {
            switch (b) {
                .domain => |db| return std.mem.eql(u8, da, db),
                else => return false,
            }
        },
        .ipv4 => |ia| {
            switch (b) {
                .ipv4 => |ib| return ia == ib,
                else => return false,
            }
        },
        .ipv6 => |ia| {
            switch (b) {
                .ipv6 => |ib| return std.mem.eql(u16, &ia, &ib),
                else => return false,
            }
        },
        .empty => {
            switch (b) {
                .empty => return true,
                else => return false,
            }
        },
    }
}

/// Create a mock global object (for testing).
pub fn createMockGlobal(allocator: Allocator) !*anyopaque {
    const mock = try allocator.create(u8);
    mock.* = 0;
    return @ptrCast(mock);
}

/// Destroy a mock global object.
pub fn destroyMockGlobal(allocator: Allocator, global: *anyopaque) void {
    const ptr: *u8 = @ptrCast(@alignCast(global));
    allocator.destroy(ptr);
}

// =============================================================================
// Tests
// =============================================================================

test "EnvironmentSettingsObject.init creates environment" {
    const allocator = std.testing.allocator;

    const global = try createMockGlobal(allocator);
    defer destroyMockGlobal(allocator, global);

    const origin = try parseOriginFromUrl(allocator, "https://example.com");

    const env = try EnvironmentSettingsObject.init(
        allocator,
        origin,
        "https://example.com/",
        global,
    );
    defer env.deinit();

    try std.testing.expectEqualStrings("https://example.com/", env.getBaseUrl());
    try std.testing.expect(!env.getCrossOriginIsolatedCapability());
}

test "EnvironmentSettingsObject.initFromUrl parses URL" {
    const allocator = std.testing.allocator;

    const global = try createMockGlobal(allocator);
    defer destroyMockGlobal(allocator, global);

    const env = try EnvironmentSettingsObject.initFromUrl(
        allocator,
        "https://example.com:8080/path",
        global,
    );
    defer env.deinit();

    try std.testing.expectEqualStrings("https://example.com:8080/path", env.getBaseUrl());

    // Check origin components.
    switch (env.getOrigin()) {
        .tuple => |t| {
            try std.testing.expectEqualStrings("https", t.scheme);
            try std.testing.expectEqual(@as(?u16, 8080), t.port);
        },
        .opaque_origin => return error.UnexpectedOpaqueOrigin,
    }
}

test "EnvironmentSettingsObject.isSameOrigin" {
    const allocator = std.testing.allocator;

    const global = try createMockGlobal(allocator);
    defer destroyMockGlobal(allocator, global);

    const env = try EnvironmentSettingsObject.initFromUrl(
        allocator,
        "https://example.com/",
        global,
    );
    defer env.deinit();

    const same_origin = try parseOriginFromUrl(allocator, "https://example.com/other");
    defer same_origin.deinit(allocator);

    const diff_scheme = try parseOriginFromUrl(allocator, "http://example.com/");
    defer diff_scheme.deinit(allocator);

    const diff_host = try parseOriginFromUrl(allocator, "https://other.com/");
    defer diff_host.deinit(allocator);

    try std.testing.expect(env.isSameOrigin(same_origin));
    try std.testing.expect(!env.isSameOrigin(diff_scheme));
    try std.testing.expect(!env.isSameOrigin(diff_host));
}

test "EnvironmentSettingsObject.isSameOriginWithUrl" {
    const allocator = std.testing.allocator;

    const global = try createMockGlobal(allocator);
    defer destroyMockGlobal(allocator, global);

    const env = try EnvironmentSettingsObject.initFromUrl(
        allocator,
        "https://example.com/",
        global,
    );
    defer env.deinit();

    try std.testing.expect(try env.isSameOriginWithUrl("https://example.com/other/path"));
    try std.testing.expect(!try env.isSameOriginWithUrl("http://example.com/"));
    try std.testing.expect(!try env.isSameOriginWithUrl("https://other.com/"));
}

test "PolicyContainer.init and deinit" {
    const allocator = std.testing.allocator;

    var policy = PolicyContainer.init(allocator);
    defer policy.deinit();

    try std.testing.expectEqual(ReferrerPolicy.strict_origin_when_cross_origin, policy.referrer_policy);
}

test "PolicyContainer.clone" {
    const allocator = std.testing.allocator;

    var original = PolicyContainer.init(allocator);
    defer original.deinit();

    original.referrer_policy = .no_referrer;

    var cloned = try original.clone(allocator);
    defer cloned.deinit();

    try std.testing.expectEqual(ReferrerPolicy.no_referrer, cloned.referrer_policy);
}

test "parseOriginFromUrl with port" {
    const allocator = std.testing.allocator;

    const origin = try parseOriginFromUrl(allocator, "https://example.com:8080/path");
    defer origin.deinit(allocator);

    switch (origin) {
        .tuple => |t| {
            try std.testing.expectEqualStrings("https", t.scheme);
            try std.testing.expectEqual(@as(?u16, 8080), t.port);
            switch (t.host) {
                .domain => |d| try std.testing.expectEqualStrings("example.com", d),
                else => return error.UnexpectedHostType,
            }
        },
        .opaque_origin => return error.UnexpectedOpaqueOrigin,
    }
}

test "parseOriginFromUrl data URL returns opaque" {
    const allocator = std.testing.allocator;

    const origin = try parseOriginFromUrl(allocator, "data:text/html,<h1>Hello</h1>");
    defer origin.deinit(allocator);

    switch (origin) {
        .opaque_origin => {},
        .tuple => return error.ExpectedOpaqueOrigin,
    }
}

test "sameOrigin tuple origins" {
    const allocator = std.testing.allocator;

    const a = try parseOriginFromUrl(allocator, "https://example.com/");
    defer a.deinit(allocator);

    const b = try parseOriginFromUrl(allocator, "https://example.com/other");
    defer b.deinit(allocator);

    const c = try parseOriginFromUrl(allocator, "https://example.com:443/");
    defer c.deinit(allocator);

    try std.testing.expect(sameOrigin(a, b));
    try std.testing.expect(!sameOrigin(a, c)); // Different port (null vs 443)
}

test "sameOrigin opaque origins" {
    const a = Origin{ .opaque_origin = {} };
    const b = Origin{ .opaque_origin = {} };

    // Opaque origins are never same-origin (except with themselves by identity).
    try std.testing.expect(!sameOrigin(a, b));
}

test "generateId creates unique IDs" {
    const allocator = std.testing.allocator;

    const id1 = try generateId(allocator);
    defer allocator.free(id1);

    const id2 = try generateId(allocator);
    defer allocator.free(id2);

    try std.testing.expect(!std.mem.eql(u8, id1, id2));
    try std.testing.expectEqual(@as(usize, 32), id1.len); // 16 bytes hex = 32 chars
}
