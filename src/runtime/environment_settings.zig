//! runtime.Origin: a tuple or opaque origin, without a domain.
//!
//! An environment settings object's state is kept by its global
//! (dom.global_settings); its policy container is fetch.internal.PolicyContainer.
//!
//! ## Specification References
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
///
/// It has no domain: HTML's origin with its domain - the one a document
/// shares, which document.domain changes - is dom.origin_record's record,
/// and "same origin-domain" is decided there (dom.global_settings).
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
