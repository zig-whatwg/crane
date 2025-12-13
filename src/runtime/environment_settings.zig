//! Environment Settings Object
//!
//! Per HTML Living Standard §8.1.5 "Environment settings objects":
//! An environment settings object specifies algorithms for:
//! - A realm execution context
//! - A module map
//! - A responsible document (for window environments)
//! - An API base URL
//! - An origin
//! - A policy container
//! - Cross-origin isolated capability
//! - A time origin
//!
//! ## Specification References
//! - HTML §8.1.5: https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-objects
//! - HTML §7.5: Origin - https://html.spec.whatwg.org/multipage/browsers.html#concept-origin

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Origin representation for security checks
///
/// Per URL Standard and HTML Standard, an origin is either:
/// - A tuple origin: (scheme, host, port)
/// - An opaque origin: unique, never same-origin with anything
///
/// This is a simplified version that works with the Environment Settings Object.
/// For full URL origin handling, see src/url/origin.zig
pub const Origin = struct {
    /// Tuple origin components
    scheme: []const u8,
    host: []const u8,
    port: ?u16,

    /// Opaque origin marker (unique, never same-origin with anything)
    is_opaque: bool = false,

    /// Allocator used for owned strings
    allocator: ?Allocator = null,

    const Self = @This();

    /// Create a tuple origin (does not take ownership of strings)
    pub fn init(scheme: []const u8, host: []const u8, port: ?u16) Self {
        return .{
            .scheme = scheme,
            .host = host,
            .port = port,
            .is_opaque = false,
            .allocator = null,
        };
    }

    /// Create a tuple origin that owns its strings
    pub fn initOwned(allocator: Allocator, scheme: []const u8, host: []const u8, port: ?u16) !Self {
        const owned_scheme = try allocator.dupe(u8, scheme);
        errdefer allocator.free(owned_scheme);

        const owned_host = try allocator.dupe(u8, host);
        errdefer allocator.free(owned_host);

        return .{
            .scheme = owned_scheme,
            .host = owned_host,
            .port = port,
            .is_opaque = false,
            .allocator = allocator,
        };
    }

    /// Create an opaque origin
    pub fn createOpaque() Self {
        return .{
            .scheme = "",
            .host = "",
            .port = null,
            .is_opaque = true,
            .allocator = null,
        };
    }

    /// Free owned strings if any
    pub fn deinit(self: *Self) void {
        if (self.allocator) |alloc| {
            if (self.scheme.len > 0) alloc.free(self.scheme);
            if (self.host.len > 0) alloc.free(self.host);
        }
        self.* = undefined;
    }

    /// Check if two origins are same-origin
    ///
    /// Per HTML Standard §7.5, two origins are same-origin if they are
    /// both tuple origins with the same scheme, host, and port.
    pub fn isSameOrigin(self: Self, other: Self) bool {
        // Opaque origins are never same-origin (even with themselves conceptually)
        if (self.is_opaque or other.is_opaque) {
            return false;
        }

        // Tuple origins: same if scheme, host, and port all match
        if (!std.mem.eql(u8, self.scheme, other.scheme)) {
            return false;
        }
        if (!std.mem.eql(u8, self.host, other.host)) {
            return false;
        }
        if (self.port != other.port) {
            return false;
        }

        return true;
    }

    /// Check if same-origin-domain (relaxed for document.domain)
    ///
    /// Per HTML Standard §7.5.2
    /// Note: document.domain is deprecated and this is a simplified implementation
    pub fn isSameOriginDomain(self: Self, other: Self) bool {
        // For now, same as same-origin (document.domain is deprecated)
        return self.isSameOrigin(other);
    }

    /// Serialize origin to string
    ///
    /// Returns "null" for opaque origins, otherwise "scheme://host[:port]"
    pub fn serialize(self: Self, allocator: Allocator) ![]u8 {
        if (self.is_opaque) {
            return try allocator.dupe(u8, "null");
        }

        if (self.port) |port| {
            return try std.fmt.allocPrint(allocator, "{s}://{s}:{d}", .{ self.scheme, self.host, port });
        } else {
            return try std.fmt.allocPrint(allocator, "{s}://{s}", .{ self.scheme, self.host });
        }
    }
};

/// Policy container per HTML Standard §7.6
///
/// A policy container contains the Content Security Policy and other
/// security policies for a document or worker.
///
/// This is a simplified version - full implementation would include
/// full CSP, permissions policy, etc.
pub const PolicyContainer = struct {
    /// Content Security Policy (simplified - just track if present)
    has_csp: bool = false,

    /// Embedder policy for cross-origin isolation
    embedder_policy: EmbedderPolicy = .unsafe_none,

    const Self = @This();

    /// Embedder policy values
    pub const EmbedderPolicy = enum {
        unsafe_none,
        require_corp,
        credentialless,
    };

    /// Create default (empty) policy container
    pub fn init() Self {
        return .{};
    }

    /// Clone the policy container
    pub fn clone(self: Self) Self {
        return .{
            .has_csp = self.has_csp,
            .embedder_policy = self.embedder_policy,
        };
    }
};

/// Environment Settings Object per HTML §8.1.5
///
/// Each realm has an associated environment settings object that provides:
/// - Origin for security checks
/// - API base URL for resolving relative URLs
/// - Policy container for security policies
/// - Cross-origin isolated capability
/// - Time origin for performance timing
///
/// The settings object is created when a realm is created and remains
/// associated with that realm for its lifetime.
pub const EnvironmentSettingsObject = struct {
    /// Memory allocator
    allocator: Allocator,

    /// The origin for security checks
    ///
    /// Determines what this environment can access (same-origin policy).
    origin: Origin,

    /// API base URL for resolving relative URLs
    ///
    /// For Window environments, this is typically the document URL.
    /// For Worker environments, this is the worker's script URL.
    /// Stored as an optional string - null means use a default or error.
    api_base_url: ?[]const u8,

    /// Whether the API base URL string is owned by this struct
    owns_api_base_url: bool,

    /// Policy container (CSP, permissions policy, etc.)
    policy_container: PolicyContainer,

    /// Whether cross-origin isolated
    ///
    /// Per HTML §7.2.5, determines if SharedArrayBuffer and high-resolution
    /// timing are available.
    cross_origin_isolated: bool,

    /// Time origin in milliseconds since Unix epoch
    ///
    /// Used by performance.now() to calculate relative timestamps.
    time_origin: i64,

    /// Back-reference to the associated realm (opaque pointer)
    ///
    /// This allows the settings object to access the realm's intrinsics
    /// and global object when needed.
    realm: ?*anyopaque,

    /// Responsible document (opaque pointer to Document)
    ///
    /// For Window environments, this is the active document.
    /// For Worker environments, this is null.
    responsible_document: ?*anyopaque,

    const Self = @This();

    /// Initialization options
    pub const InitOptions = struct {
        /// The origin for this environment
        origin: ?Origin = null,

        /// API base URL (if null, will need to be set later or resolved from document)
        api_base_url: ?[]const u8 = null,

        /// Whether to take ownership of the API base URL string
        owns_api_base_url: bool = false,

        /// Policy container (defaults to empty)
        policy_container: ?PolicyContainer = null,

        /// Cross-origin isolated capability
        cross_origin_isolated: bool = false,

        /// Time origin (defaults to current time)
        time_origin: ?i64 = null,

        /// Back-reference to realm
        realm: ?*anyopaque = null,

        /// Responsible document (for Window environments)
        responsible_document: ?*anyopaque = null,
    };

    /// Initialize a new Environment Settings Object
    pub fn init(allocator: Allocator, options: InitOptions) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        // Get current time for time_origin if not provided
        const time_origin = options.time_origin orelse blk: {
            const now = std.time.milliTimestamp();
            break :blk now;
        };

        self.* = .{
            .allocator = allocator,
            .origin = options.origin orelse Origin.createOpaque(),
            .api_base_url = options.api_base_url,
            .owns_api_base_url = options.owns_api_base_url,
            .policy_container = options.policy_container orelse PolicyContainer.init(),
            .cross_origin_isolated = options.cross_origin_isolated,
            .time_origin = time_origin,
            .realm = options.realm,
            .responsible_document = options.responsible_document,
        };

        return self;
    }

    /// Deinitialize and free resources
    pub fn deinit(self: *Self) void {
        // Free owned API base URL
        if (self.owns_api_base_url) {
            if (self.api_base_url) |url| {
                self.allocator.free(url);
            }
        }

        // Free origin if it owns its strings
        var origin = self.origin;
        origin.deinit();

        self.allocator.destroy(self);
    }

    // ========================================================================
    // Origin Access
    // ========================================================================

    /// Get the origin for security checks
    pub fn getOrigin(self: *const Self) Origin {
        return self.origin;
    }

    /// Check if same origin with another settings object
    pub fn isSameOrigin(self: *const Self, other: *const Self) bool {
        return self.origin.isSameOrigin(other.origin);
    }

    /// Check if same origin with a given origin
    pub fn isSameOriginWith(self: *const Self, other: Origin) bool {
        return self.origin.isSameOrigin(other);
    }

    // ========================================================================
    // API Base URL
    // ========================================================================

    /// Get the API base URL for resolving relative URLs
    ///
    /// For Window environments, this is typically the document URL.
    /// Returns null if not set (caller should handle appropriately).
    pub fn getApiBaseUrl(self: *const Self) ?[]const u8 {
        return self.api_base_url;
    }

    /// Set the API base URL
    ///
    /// If `owned` is true, this struct takes ownership of the string.
    pub fn setApiBaseUrl(self: *Self, url: []const u8, owned: bool) void {
        // Free existing if owned
        if (self.owns_api_base_url) {
            if (self.api_base_url) |old_url| {
                self.allocator.free(old_url);
            }
        }

        self.api_base_url = url;
        self.owns_api_base_url = owned;
    }

    // ========================================================================
    // Policy Container
    // ========================================================================

    /// Get the policy container
    pub fn getPolicyContainer(self: *const Self) PolicyContainer {
        return self.policy_container;
    }

    /// Set the policy container
    pub fn setPolicyContainer(self: *Self, container: PolicyContainer) void {
        self.policy_container = container;
    }

    // ========================================================================
    // Cross-Origin Isolation
    // ========================================================================

    /// Check if cross-origin isolated
    ///
    /// When true, enables SharedArrayBuffer and high-resolution timing.
    pub fn isCrossOriginIsolated(self: *const Self) bool {
        return self.cross_origin_isolated;
    }

    /// Set cross-origin isolated status
    pub fn setCrossOriginIsolated(self: *Self, isolated: bool) void {
        self.cross_origin_isolated = isolated;
    }

    // ========================================================================
    // Time Origin
    // ========================================================================

    /// Get the time origin in milliseconds since Unix epoch
    ///
    /// Used by performance.now() to calculate relative timestamps.
    pub fn getTimeOrigin(self: *const Self) i64 {
        return self.time_origin;
    }

    // ========================================================================
    // Associated Objects
    // ========================================================================

    /// Get the associated realm (opaque pointer)
    pub fn getRealm(self: *const Self) ?*anyopaque {
        return self.realm;
    }

    /// Set the associated realm
    pub fn setRealm(self: *Self, realm: *anyopaque) void {
        self.realm = realm;
    }

    /// Get the responsible document (opaque pointer)
    ///
    /// For Window environments, this is the active document.
    /// For Worker environments, this returns null.
    pub fn getResponsibleDocument(self: *const Self) ?*anyopaque {
        return self.responsible_document;
    }

    /// Set the responsible document
    pub fn setResponsibleDocument(self: *Self, document: ?*anyopaque) void {
        self.responsible_document = document;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Origin - tuple origin same-origin check" {
    const a = Origin.init("https", "example.com", 443);
    const b = Origin.init("https", "example.com", 443);
    const c = Origin.init("https", "example.com", 8080);
    const d = Origin.init("http", "example.com", 443);
    const e = Origin.init("https", "other.com", 443);

    try std.testing.expect(a.isSameOrigin(b));
    try std.testing.expect(!a.isSameOrigin(c)); // Different port
    try std.testing.expect(!a.isSameOrigin(d)); // Different scheme
    try std.testing.expect(!a.isSameOrigin(e)); // Different host
}

test "Origin - opaque origin never same-origin" {
    const opaque_origin1 = Origin.createOpaque();
    const opaque_origin2 = Origin.createOpaque();
    const tuple = Origin.init("https", "example.com", 443);

    try std.testing.expect(!opaque_origin1.isSameOrigin(opaque_origin2));
    try std.testing.expect(!opaque_origin1.isSameOrigin(tuple));
    try std.testing.expect(!tuple.isSameOrigin(opaque_origin1));
}

test "Origin - serialize tuple origin" {
    const allocator = std.testing.allocator;

    const origin1 = Origin.init("https", "example.com", null);
    const str1 = try origin1.serialize(allocator);
    defer allocator.free(str1);
    try std.testing.expectEqualStrings("https://example.com", str1);

    const origin2 = Origin.init("https", "example.com", 8080);
    const str2 = try origin2.serialize(allocator);
    defer allocator.free(str2);
    try std.testing.expectEqualStrings("https://example.com:8080", str2);
}

test "Origin - serialize opaque origin" {
    const allocator = std.testing.allocator;

    const opaque_origin = Origin.createOpaque();
    const str = try opaque_origin.serialize(allocator);
    defer allocator.free(str);
    try std.testing.expectEqualStrings("null", str);
}

test "EnvironmentSettingsObject - basic init" {
    const allocator = std.testing.allocator;

    const settings = try EnvironmentSettingsObject.init(allocator, .{});
    defer settings.deinit();

    // Default should have opaque origin
    try std.testing.expect(settings.origin.is_opaque);
    try std.testing.expect(!settings.cross_origin_isolated);
    try std.testing.expect(settings.api_base_url == null);
    try std.testing.expect(settings.responsible_document == null);
}

test "EnvironmentSettingsObject - with origin" {
    const allocator = std.testing.allocator;

    const settings = try EnvironmentSettingsObject.init(allocator, .{
        .origin = Origin.init("https", "example.com", 443),
        .cross_origin_isolated = true,
    });
    defer settings.deinit();

    try std.testing.expect(!settings.origin.is_opaque);
    try std.testing.expectEqualStrings("https", settings.origin.scheme);
    try std.testing.expectEqualStrings("example.com", settings.origin.host);
    try std.testing.expectEqual(@as(?u16, 443), settings.origin.port);
    try std.testing.expect(settings.cross_origin_isolated);
}

test "EnvironmentSettingsObject - same-origin check" {
    const allocator = std.testing.allocator;

    const settings1 = try EnvironmentSettingsObject.init(allocator, .{
        .origin = Origin.init("https", "example.com", 443),
    });
    defer settings1.deinit();

    const settings2 = try EnvironmentSettingsObject.init(allocator, .{
        .origin = Origin.init("https", "example.com", 443),
    });
    defer settings2.deinit();

    const settings3 = try EnvironmentSettingsObject.init(allocator, .{
        .origin = Origin.init("https", "other.com", 443),
    });
    defer settings3.deinit();

    try std.testing.expect(settings1.isSameOrigin(settings2));
    try std.testing.expect(!settings1.isSameOrigin(settings3));
}

test "EnvironmentSettingsObject - API base URL" {
    const allocator = std.testing.allocator;

    const settings = try EnvironmentSettingsObject.init(allocator, .{
        .api_base_url = "https://example.com/path/",
        .owns_api_base_url = false,
    });
    defer settings.deinit();

    try std.testing.expectEqualStrings("https://example.com/path/", settings.getApiBaseUrl().?);
}

test "EnvironmentSettingsObject - time origin is set" {
    const allocator = std.testing.allocator;

    const before = std.time.milliTimestamp();

    const settings = try EnvironmentSettingsObject.init(allocator, .{});
    defer settings.deinit();

    const after = std.time.milliTimestamp();

    try std.testing.expect(settings.time_origin >= before);
    try std.testing.expect(settings.time_origin <= after);
}

test "PolicyContainer - default init" {
    const policy = PolicyContainer.init();

    try std.testing.expect(!policy.has_csp);
    try std.testing.expectEqual(PolicyContainer.EmbedderPolicy.unsafe_none, policy.embedder_policy);
}

test "PolicyContainer - clone" {
    var original = PolicyContainer.init();
    original.has_csp = true;
    original.embedder_policy = .require_corp;

    const cloned = original.clone();

    try std.testing.expect(cloned.has_csp);
    try std.testing.expectEqual(PolicyContainer.EmbedderPolicy.require_corp, cloned.embedder_policy);
}
