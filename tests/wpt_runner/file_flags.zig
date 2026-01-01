//! WPT File Name Flag Parser
//!
//! WPT uses file name conventions to indicate test requirements:
//! - `.https.` - Test requires HTTPS (port 8443)
//! - `.h2.` - Test requires HTTP/2 over HTTPS (port 9000)
//! - `.www.` - Test requires www subdomain
//! - `.sub.` - Test uses server-side substitution
//!
//! Example filenames:
//!   test.https.html          → Served over HTTPS on port 8443
//!   test.h2.html             → Served over HTTP/2 on port 9000
//!   test.www.html            → Served from www.web-platform.test
//!   test.https.www.html      → HTTPS + www subdomain

const std = @import("std");

/// Flags parsed from WPT test file names
pub const FileFlags = struct {
    /// Test requires HTTPS (port 8443)
    https: bool = false,
    /// Test requires HTTP/2 over HTTPS (port 9000)
    h2: bool = false,
    /// Test requires www subdomain
    www: bool = false,
    /// Test uses server-side substitution
    sub: bool = false,

    /// Parse flags from a test file path or name
    pub fn parse(path: []const u8) FileFlags {
        var flags = FileFlags{};

        // Check for .https. in path
        if (std.mem.indexOf(u8, path, ".https.") != null) {
            flags.https = true;
        }

        // Check for .h2. in path (implies https)
        if (std.mem.indexOf(u8, path, ".h2.") != null) {
            flags.h2 = true;
            flags.https = true; // h2 always uses HTTPS
        }

        // Check for .www. in path
        if (std.mem.indexOf(u8, path, ".www.") != null) {
            flags.www = true;
        }

        // Check for .sub. in path
        if (std.mem.indexOf(u8, path, ".sub.") != null) {
            flags.sub = true;
        }

        return flags;
    }

    /// Get the URL scheme based on flags
    pub fn getScheme(self: FileFlags) []const u8 {
        return if (self.https or self.h2) "https" else "http";
    }

    /// Get the port number based on flags
    pub fn getPort(self: FileFlags) u16 {
        if (self.h2) return 9000;
        if (self.https) return 8443;
        return 8000;
    }

    /// Get the host based on flags
    pub fn getHost(self: FileFlags) []const u8 {
        return if (self.www) "www.web-platform.test" else "web-platform.test";
    }
};

// Tests
test "parse - no flags" {
    const flags = FileFlags.parse("infrastructure/server/test.html");
    try std.testing.expect(!flags.https);
    try std.testing.expect(!flags.h2);
    try std.testing.expect(!flags.www);
    try std.testing.expect(!flags.sub);
    try std.testing.expectEqualStrings("http", flags.getScheme());
    try std.testing.expectEqual(@as(u16, 8000), flags.getPort());
    try std.testing.expectEqualStrings("web-platform.test", flags.getHost());
}

test "parse - https flag" {
    const flags = FileFlags.parse("infrastructure/server/test.https.html");
    try std.testing.expect(flags.https);
    try std.testing.expect(!flags.h2);
    try std.testing.expectEqualStrings("https", flags.getScheme());
    try std.testing.expectEqual(@as(u16, 8443), flags.getPort());
}

test "parse - h2 flag implies https" {
    const flags = FileFlags.parse("infrastructure/server/test.h2.html");
    try std.testing.expect(flags.https); // h2 implies https
    try std.testing.expect(flags.h2);
    try std.testing.expectEqualStrings("https", flags.getScheme());
    try std.testing.expectEqual(@as(u16, 9000), flags.getPort());
}

test "parse - www flag" {
    const flags = FileFlags.parse("infrastructure/server/test.www.html");
    try std.testing.expect(flags.www);
    try std.testing.expectEqualStrings("www.web-platform.test", flags.getHost());
}

test "parse - combined flags" {
    const flags = FileFlags.parse("infrastructure/server/test.https.www.html");
    try std.testing.expect(flags.https);
    try std.testing.expect(flags.www);
    try std.testing.expectEqualStrings("https", flags.getScheme());
    try std.testing.expectEqual(@as(u16, 8443), flags.getPort());
    try std.testing.expectEqualStrings("www.web-platform.test", flags.getHost());
}

test "parse - sub flag" {
    const flags = FileFlags.parse("infrastructure/server/test.sub.html");
    try std.testing.expect(flags.sub);
}
