//! Special Schemes and Default Ports
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#special-scheme
//! Spec Reference: Lines 845-856
//!
//! A special scheme is one of a fixed set of schemes that have special parsing rules
//! and default ports defined by the URL Standard.
//!
//! ## Special Schemes
//!
//! 1. `ftp` - File Transfer Protocol (port 21)
//! 2. `file` - Local file system (no default port)
//! 3. `http` - Hypertext Transfer Protocol (port 80)
//! 4. `https` - HTTP Secure (port 443)
//! 5. `ws` - WebSocket (port 80)
//! 6. `wss` - WebSocket Secure (port 443)
//!
//! ## Usage
//!
//! ```zig
//! const special_schemes = @import("internal/special_schemes.zig");
//!
//! if (special_schemes.isSpecialScheme("https")) {
//!     const port = special_schemes.defaultPort("https"); // 443
//! }
//! ```

const std = @import("std");

/// Special scheme entry (spec lines 847-854)
pub const SpecialScheme = struct {
    name: []const u8,
    default_port: ?u16,
};

/// All special schemes from spec (lines 847-854)
///
/// Decision 8: Use comptime hash map for O(1) lookup with zero runtime cost
pub const special_schemes = [_]SpecialScheme{
    .{ .name = "ftp", .default_port = 21 },
    .{ .name = "file", .default_port = null },
    .{ .name = "http", .default_port = 80 },
    .{ .name = "https", .default_port = 443 },
    .{ .name = "ws", .default_port = 80 },
    .{ .name = "wss", .default_port = 443 },
};

/// Comptime hash map for O(1) special scheme lookup
/// Decision 8: Zero runtime cost, compile-time generation
const special_scheme_map = std.StaticStringMap(void).initComptime(.{
    .{"ftp"},
    .{"file"},
    .{"http"},
    .{"https"},
    .{"ws"},
    .{"wss"},
});

/// Comptime hash map for default port lookup
/// Decision 8: O(1) lookup for default ports
const default_port_map = std.StaticStringMap(?u16).initComptime(.{
    .{ "ftp", 21 },
    .{ "file", null },
    .{ "http", 80 },
    .{ "https", 443 },
    .{ "ws", 80 },
    .{ "wss", 443 },
});

/// Check if a scheme is a special scheme (spec line 856)
///
/// A URL is special if its scheme is a special scheme.
///
/// Time complexity: O(1) via comptime hash map
pub fn isSpecialScheme(scheme: []const u8) bool {
    return special_scheme_map.has(scheme);
}

/// Get default port for a scheme (spec lines 845-854)
///
/// Returns the default port for special schemes, or null for non-special schemes
/// or schemes without a default port (e.g., "file").
///
/// Time complexity: O(1) via comptime hash map
pub fn defaultPort(scheme: []const u8) ?u16 {
    return default_port_map.get(scheme) orelse null;
}

/// Check if a URL port should be excluded from serialization (spec line 1544)
///
/// A URL's port should be excluded from serialization if:
/// 1. It is null, OR
/// 2. It equals the default port for the URL's scheme
///
/// This is used during URL serialization to omit redundant ports.
pub fn shouldExcludePort(scheme: []const u8, port: ?u16) bool {
    if (port == null) return true;
    const default = defaultPort(scheme);
    return if (default) |d| port.? == d else false;
}

test "special schemes - is special" {
    // All 6 special schemes
    try std.testing.expect(isSpecialScheme("ftp"));
    try std.testing.expect(isSpecialScheme("file"));
    try std.testing.expect(isSpecialScheme("http"));
    try std.testing.expect(isSpecialScheme("https"));
    try std.testing.expect(isSpecialScheme("ws"));
    try std.testing.expect(isSpecialScheme("wss"));

    // Non-special schemes
    try std.testing.expect(!isSpecialScheme("mailto"));
    try std.testing.expect(!isSpecialScheme("data"));
    try std.testing.expect(!isSpecialScheme("ssh"));
    try std.testing.expect(!isSpecialScheme(""));
}

test "special schemes - default ports" {
    // Schemes with ports
    try std.testing.expectEqual(@as(?u16, 21), defaultPort("ftp"));
    try std.testing.expectEqual(@as(?u16, 80), defaultPort("http"));
    try std.testing.expectEqual(@as(?u16, 443), defaultPort("https"));
    try std.testing.expectEqual(@as(?u16, 80), defaultPort("ws"));
    try std.testing.expectEqual(@as(?u16, 443), defaultPort("wss"));

    // file has no default port
    try std.testing.expectEqual(@as(?u16, null), defaultPort("file"));

    // Non-special schemes return null
    try std.testing.expectEqual(@as(?u16, null), defaultPort("mailto"));
    try std.testing.expectEqual(@as(?u16, null), defaultPort("data"));
}

test "special schemes - should exclude port" {
    // Null ports are always excluded
    try std.testing.expect(shouldExcludePort("http", null));
    try std.testing.expect(shouldExcludePort("mailto", null));

    // Default ports are excluded
    try std.testing.expect(shouldExcludePort("http", 80));
    try std.testing.expect(shouldExcludePort("https", 443));
    try std.testing.expect(shouldExcludePort("ftp", 21));

    // Non-default ports are NOT excluded
    try std.testing.expect(!shouldExcludePort("http", 8080));
    try std.testing.expect(!shouldExcludePort("https", 8443));
    try std.testing.expect(!shouldExcludePort("ftp", 2121));

    // file has no default port, so any explicit port is not excluded
    try std.testing.expect(!shouldExcludePort("file", 80));

    // Non-special schemes with explicit ports are not excluded
    try std.testing.expect(!shouldExcludePort("mailto", 25));
}

test "special schemes - array contents" {
    // Verify all 6 schemes are present
    try std.testing.expectEqual(@as(usize, 6), special_schemes.len);

    // Verify names and ports match spec
    for (special_schemes) |scheme| {
        const is_special = isSpecialScheme(scheme.name);
        try std.testing.expect(is_special);

        const port = defaultPort(scheme.name);
        try std.testing.expectEqual(scheme.default_port, port);
    }
}
