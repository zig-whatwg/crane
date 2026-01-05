//! Host Types
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#host-representation
//! Spec Reference: Lines 280-302
//!
//! A host is one of:
//! - Domain (non-empty ASCII string identifying a realm)
//! - IPv4 address (32-bit unsigned integer)
//! - IPv6 address (128-bit integer, 8 pieces of 16-bit integers)
//! - Opaque host (non-empty ASCII string for further processing)
//! - Empty host (empty string)
//!
//! ## Usage
//!
//! ```zig
//! const host = @import("host");
//!
//! // Create domain
//! const domain = try host.Host.domain(allocator, "example.com");
//! defer domain.deinit(allocator);
//!
//! // Create IPv4
//! const ipv4 = host.Host{ .ipv4 = 0x7F000001 }; // 127.0.0.1
//!
//! // Create IPv6
//! const ipv6 = host.Host{ .ipv6 = [_]u16{0} ** 8 }; // ::
//! ```

const std = @import("std");

/// Host type (spec lines 280-302)
pub const Host = union(enum) {
    domain: []const u8,
    ipv4: u32,
    ipv6: [8]u16,
    opaque_host: []const u8,
    empty,

    pub fn deinit(self: Host, allocator: std.mem.Allocator) void {
        switch (self) {
            .domain => |d| allocator.free(d),
            .opaque_host => |o| allocator.free(o),
            .ipv4, .ipv6, .empty => {},
        }
    }

    pub fn clone(self: Host, allocator: std.mem.Allocator) !Host {
        return switch (self) {
            .domain => |d| Host{ .domain = try allocator.dupe(u8, d) },
            .opaque_host => |o| Host{ .opaque_host = try allocator.dupe(u8, o) },
            .ipv4 => |ip| Host{ .ipv4 = ip },
            .ipv6 => |ip| Host{ .ipv6 = ip },
            .empty => Host.empty,
        };
    }

    pub fn createDomain(allocator: std.mem.Allocator, name: []const u8) !Host {
        const owned = try allocator.dupe(u8, name);
        return Host{ .domain = owned };
    }

    pub fn createOpaqueHost(allocator: std.mem.Allocator, name: []const u8) !Host {
        const owned = try allocator.dupe(u8, name);
        return Host{ .opaque_host = owned };
    }

    pub fn isEmpty(self: Host) bool {
        return std.meta.activeTag(self) == .empty;
    }

    pub fn isDomain(self: Host) bool {
        return std.meta.activeTag(self) == .domain;
    }

    pub fn isIpAddress(self: Host) bool {
        const tag = std.meta.activeTag(self);
        return tag == .ipv4 or tag == .ipv6;
    }
};

/// Forbidden host code point (WHATWG URL spec)
/// U+0000 NULL, U+0009 TAB, U+000A LF, U+000D CR, U+0020 SPACE,
/// U+0023 (#), U+002F (/), U+003A (:), U+003C (<), U+003E (>),
/// U+003F (?), U+0040 (@), U+005B ([), U+005C (\), U+005D (]),
/// U+005E (^), U+007C (|)
pub fn isForbiddenHostCodePoint(cp: u21) bool {
    return switch (cp) {
        0x0000, 0x0009, 0x000A, 0x000D, 0x0020, '#', '/', ':', '<', '>', '?', '@', '[', '\\', ']', '^', '|' => true,
        else => false,
    };
}

/// Forbidden domain code point (WHATWG URL spec)
/// A forbidden host code point, a C0 control (U+0000-U+001F), U+0025 (%), or U+007F DELETE.
/// Used for validating domain hosts in special-scheme URLs (http, https, etc.)
pub fn isForbiddenDomainCodePoint(cp: u21) bool {
    // C0 control range (0x00-0x1F) - includes NULL, TAB, LF, CR already in forbidden host
    if (cp <= 0x001F) return true;
    // U+007F DELETE
    if (cp == 0x007F) return true;
    // U+0025 (%) - percent sign
    if (cp == '%') return true;
    // Check remaining forbidden host code points (SPACE and punctuation)
    return switch (cp) {
        0x0020, '#', '/', ':', '<', '>', '?', '@', '[', '\\', ']', '^', '|' => true,
        else => false,
    };
}
