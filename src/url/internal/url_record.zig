//! URL Record - In-Memory URL Representation
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#url-representation
//! Spec Reference: Lines 791-817
//!
//! A URL is a struct that represents a universal identifier. This is the
//! in-memory representation of a parsed URL, also called a URL record.
//!
//! Memory Design:
//! - Uses offset-based storage to avoid multiple allocations
//! - All string components are stored in a single buffer
//! - Offsets point into the buffer for each component
//! - Reduces allocations and improves cache locality

const std = @import("std");
const infra = @import("infra");
const Host = @import("host").Host;
const Path = @import("path").Path;
const BlobURLEntry = @import("blob_url").BlobURLEntry;

/// URL Record - In-memory representation of a parsed URL
///
/// Spec: https://url.spec.whatwg.org/#url-representation (lines 791-817)
///
/// Components (spec lines 793-819):
/// - scheme: ASCII string identifying URL type (initially empty)
/// - username: ASCII string for authentication (initially empty)
/// - password: ASCII string for authentication (initially empty)
/// - host: null or a host (initially null)
/// - port: null or 16-bit unsigned integer (initially null)
/// - path: URL path (initially « » empty list)
/// - query: null or ASCII string (initially null)
/// - fragment: null or ASCII string (initially null)
///
/// Memory layout:
/// - Single buffer holds all string components
/// - Offsets/lengths point into buffer for each component
/// - Host is stored separately (can be domain, IPv4, IPv6, opaque)
/// - Path is stored separately (can be opaque or segments)
pub const URLRecord = struct {
    /// Memory buffer holding all string components
    buffer: []const u8,

    /// Scheme offset/length (spec line 793)
    scheme_start: u32,
    scheme_len: u32,

    /// Username offset/length (spec line 795)
    username_start: u32,
    username_len: u32,

    /// Password offset/length (spec line 797)
    password_start: u32,
    password_len: u32,

    /// Host (spec line 799) - null or domain/IPv4/IPv6/opaque/empty
    host: ?Host,

    /// Port (spec line 809) - null or 16-bit unsigned integer
    port: ?u16,

    /// Path (spec line 811) - URL path (opaque or segments)
    path: Path,

    /// Query offset/length (spec line 815) - null if query_len == 0
    query_start: u32,
    query_len: u32,

    /// Fragment offset/length (spec line 817) - null if fragment_len == 0
    fragment_start: u32,
    fragment_len: u32,

    /// Blob URL entry (spec line 819) - null or a blob URL entry
    /// Used for blob: URLs to cache the object and origin
    blob_url_entry: ?*BlobURLEntry,

    allocator: std.mem.Allocator,

    /// Get scheme string (spec line 793)
    pub fn scheme(self: *const URLRecord) []const u8 {
        return self.buffer[self.scheme_start .. self.scheme_start + self.scheme_len];
    }

    /// Get username string (spec line 795)
    pub fn username(self: *const URLRecord) []const u8 {
        return self.buffer[self.username_start .. self.username_start + self.username_len];
    }

    /// Get password string (spec line 797)
    pub fn password(self: *const URLRecord) []const u8 {
        return self.buffer[self.password_start .. self.password_start + self.password_len];
    }

    /// Get query string (spec line 815) - null if no query
    pub fn query(self: *const URLRecord) ?[]const u8 {
        if (self.query_len == 0) return null;
        return self.buffer[self.query_start .. self.query_start + self.query_len];
    }

    /// Get fragment string (spec line 817) - null if no fragment
    pub fn fragment(self: *const URLRecord) ?[]const u8 {
        if (self.fragment_len == 0) return null;
        return self.buffer[self.fragment_start .. self.fragment_start + self.fragment_len];
    }

    /// Check if URL is special (spec line 856)
    /// A URL is special if its scheme is a special scheme (ftp, file, http, https, ws, wss)
    pub fn isSpecial(self: *const URLRecord) bool {
        const s = self.scheme();
        return std.mem.eql(u8, s, "ftp") or
            std.mem.eql(u8, s, "file") or
            std.mem.eql(u8, s, "http") or
            std.mem.eql(u8, s, "https") or
            std.mem.eql(u8, s, "ws") or
            std.mem.eql(u8, s, "wss");
    }

    /// Check if URL includes credentials (spec line 858)
    /// A URL includes credentials if its username or password is not empty
    pub fn includesCredentials(self: *const URLRecord) bool {
        return self.username_len > 0 or self.password_len > 0;
    }

    /// Check if URL has opaque path (spec line 860)
    /// A URL has an opaque path if its path is a URL path segment (not a list)
    pub fn hasOpaquePath(self: *const URLRecord) bool {
        return self.path == .opaque_path;
    }

    /// Check if URL cannot have username/password/port (spec line 862)
    /// Returns true if:
    /// - host is null
    /// - host is empty string
    /// - scheme is "file"
    pub fn cannotHaveUsernamePasswordPort(self: *const URLRecord) bool {
        if (self.host == null) return true;
        if (self.host.? == .empty) return true;
        const s = self.scheme();
        if (std.mem.eql(u8, s, "file")) return true;
        return false;
    }

    /// Free URL record resources
    pub fn deinit(self: *URLRecord) void {
        self.allocator.free(self.buffer);
        if (self.host) |*h| {
            h.deinit(self.allocator);
        }
        @import("path").deinitPath(&self.path, self.allocator);
    }
};





