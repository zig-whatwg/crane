//! W3C File API - Blob URL Store
//!
//! This module implements the blob URL store for URL.createObjectURL()
//! and URL.revokeObjectURL() operations.
//!
//! Spec: https://www.w3.org/TR/FileAPI/#url
//!
//! ## Blob URL Format
//!
//! Blob URLs have the format: blob:<origin>/<uuid>
//! Example: blob:https://example.com/550e8400-e29b-41d4-a716-446655440000
//!
//! ## Store Semantics
//!
//! Per spec §8:
//! - Each origin has its own blob URL store
//! - URLs are valid only within the creating origin
//! - URLs are revoked when their entry is removed
//! - URLs can be revoked manually or when document unloads
//!
//! ## Thread Safety
//!
//! The store is designed for single-threaded access within an origin.
//! Cross-origin access is blocked by URL resolution.

const std = @import("std");
const BlobData = @import("blob_internals.zig").BlobData;

/// Entry in the blob URL store.
pub const BlobURLEntry = struct {
    /// The blob data (owned reference)
    blob: *BlobData,

    /// The origin that created this URL
    origin: []const u8,

    /// Whether this entry is still valid
    valid: bool,
};

/// Global blob URL store.
///
/// Maps blob URLs to their associated Blob objects.
/// Per spec, each origin should have its own store, but for simplicity
/// we use a single store with origin validation.
pub const BlobURLStore = struct {
    /// Map from UUID string to blob entry
    entries: std.StringHashMap(BlobURLEntry),

    /// Memory allocator
    allocator: std.mem.Allocator,

    /// Random number generator for UUID generation
    random: std.Random,

    /// Initialize a new blob URL store.
    pub fn init(allocator: std.mem.Allocator) BlobURLStore {
        var prng = std.Random.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            std.posix.getrandom(std.mem.asBytes(&seed)) catch {
                seed = @intCast(std.time.milliTimestamp());
            };
            break :blk seed;
        });

        return .{
            .entries = std.StringHashMap(BlobURLEntry).init(allocator),
            .allocator = allocator,
            .random = prng.random(),
        };
    }

    /// Clean up all resources.
    pub fn deinit(self: *BlobURLStore) void {
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            // Free the UUID key
            self.allocator.free(entry.key_ptr.*);
            // Free the origin
            if (entry.value_ptr.origin.len > 0) {
                self.allocator.free(@constCast(entry.value_ptr.origin));
            }
            // Note: We don't deinit the blob here as it may be referenced elsewhere
        }
        self.entries.deinit();
    }

    /// Create a new blob URL for the given blob.
    ///
    /// Per spec §8.3.1 (createObjectURL):
    /// 1. Generate a new UUID
    /// 2. Create blob URL: "blob:" + origin + "/" + uuid
    /// 3. Add entry to store
    /// 4. Return the URL
    ///
    /// Returns the full blob URL string (caller owns memory).
    pub fn createObjectURL(self: *BlobURLStore, blob: *BlobData, origin: []const u8) ![]const u8 {
        // Generate UUID
        const uuid = try self.generateUUID();
        errdefer self.allocator.free(uuid);

        // Create the full URL
        const url = try std.fmt.allocPrint(self.allocator, "blob:{s}/{s}", .{ origin, uuid });
        errdefer self.allocator.free(url);

        // Copy origin for storage
        const owned_origin = try self.allocator.dupe(u8, origin);
        errdefer self.allocator.free(owned_origin);

        // Store the entry
        try self.entries.put(uuid, .{
            .blob = blob,
            .origin = owned_origin,
            .valid = true,
        });

        return url;
    }

    /// Revoke a blob URL.
    ///
    /// Per spec §8.3.2 (revokeObjectURL):
    /// 1. Parse the URL to extract UUID
    /// 2. If entry exists, mark it as invalid
    /// 3. Remove entry from store
    pub fn revokeObjectURL(self: *BlobURLStore, url: []const u8) void {
        // Extract UUID from URL (after last '/')
        const uuid = self.extractUUID(url) orelse return;

        if (self.entries.fetchRemove(uuid)) |kv| {
            // Free the stored UUID key
            self.allocator.free(kv.key);
            // Free the origin
            if (kv.value.origin.len > 0) {
                self.allocator.free(@constCast(kv.value.origin));
            }
        }
    }

    /// Resolve a blob URL to its associated blob.
    ///
    /// Per spec §8.4:
    /// 1. Parse URL to extract UUID
    /// 2. Look up in store
    /// 3. Verify origin matches
    /// 4. Return blob if valid
    pub fn resolve(self: *BlobURLStore, url: []const u8, requesting_origin: []const u8) ?*BlobData {
        const uuid = self.extractUUID(url) orelse return null;

        const entry = self.entries.get(uuid) orelse return null;

        // Verify origin matches (same-origin policy)
        if (!std.mem.eql(u8, entry.origin, requesting_origin)) {
            return null;
        }

        if (!entry.valid) {
            return null;
        }

        return entry.blob;
    }

    /// Generate a random UUID v4.
    fn generateUUID(self: *BlobURLStore) ![]const u8 {
        var uuid_bytes: [16]u8 = undefined;
        self.random.bytes(&uuid_bytes);

        // Set version (4) and variant (RFC 4122)
        uuid_bytes[6] = (uuid_bytes[6] & 0x0F) | 0x40;
        uuid_bytes[8] = (uuid_bytes[8] & 0x3F) | 0x80;

        // Format as string
        return std.fmt.allocPrint(
            self.allocator,
            "{x:0>2}{x:0>2}{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}",
            .{
                uuid_bytes[0],  uuid_bytes[1],  uuid_bytes[2],  uuid_bytes[3],
                uuid_bytes[4],  uuid_bytes[5],  uuid_bytes[6],  uuid_bytes[7],
                uuid_bytes[8],  uuid_bytes[9],  uuid_bytes[10], uuid_bytes[11],
                uuid_bytes[12], uuid_bytes[13], uuid_bytes[14], uuid_bytes[15],
            },
        );
    }

    /// Extract the UUID from a blob URL.
    fn extractUUID(self: *BlobURLStore, url: []const u8) ?[]const u8 {
        _ = self;

        // URL format: blob:<origin>/<uuid>
        if (!std.mem.startsWith(u8, url, "blob:")) {
            return null;
        }

        // Find the last '/'
        const last_slash = std.mem.lastIndexOf(u8, url, "/") orelse return null;

        if (last_slash + 1 >= url.len) {
            return null;
        }

        return url[last_slash + 1 ..];
    }
};

test "BlobURLStore - createObjectURL and resolve" {
    const allocator = std.testing.allocator;

    var store = BlobURLStore.init(allocator);
    defer store.deinit();

    const blob = try BlobData.init(allocator, "Hello", "text/plain");
    defer blob.deinit();

    const url = try store.createObjectURL(blob, "https://example.com");
    defer allocator.free(url);

    try std.testing.expect(std.mem.startsWith(u8, url, "blob:https://example.com/"));

    // Should resolve from same origin
    const resolved = store.resolve(url, "https://example.com");
    try std.testing.expect(resolved != null);
    try std.testing.expectEqualStrings("Hello", resolved.?.bytes);

    // Should not resolve from different origin
    const cross_origin = store.resolve(url, "https://other.com");
    try std.testing.expect(cross_origin == null);
}

test "BlobURLStore - revokeObjectURL" {
    const allocator = std.testing.allocator;

    var store = BlobURLStore.init(allocator);
    defer store.deinit();

    const blob = try BlobData.init(allocator, "Hello", "text/plain");
    defer blob.deinit();

    const url = try store.createObjectURL(blob, "https://example.com");
    defer allocator.free(url);

    // Should resolve before revocation
    try std.testing.expect(store.resolve(url, "https://example.com") != null);

    // Revoke
    store.revokeObjectURL(url);

    // Should not resolve after revocation
    try std.testing.expect(store.resolve(url, "https://example.com") == null);
}

test "BlobURLStore - invalid URL" {
    const allocator = std.testing.allocator;

    var store = BlobURLStore.init(allocator);
    defer store.deinit();

    // Should return null for invalid URLs
    try std.testing.expect(store.resolve("not-a-blob-url", "https://example.com") == null);
    try std.testing.expect(store.resolve("blob:", "https://example.com") == null);
    try std.testing.expect(store.resolve("blob:https://example.com/", "https://example.com") == null);
}
