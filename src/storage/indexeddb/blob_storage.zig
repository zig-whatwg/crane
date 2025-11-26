//! Blob Storage for IndexedDB
//!
//! Stores large binary objects (Blobs, Files, ArrayBuffers) in external files
//! instead of inline in SQLite. This improves performance for large values
//! and reduces database bloat.
//!
//! ## Architecture
//!
//! ```
//! IndexedDB Value
//!     └── If size > threshold:
//!         └── Store in external file: <storage_dir>/<db>/<store>/<blob_id>.blob
//!         └── Store reference in SQLite: {type: "blob_ref", id: <blob_id>, size: <size>}
//!     └── If size <= threshold:
//!         └── Store inline in SQLite
//! ```
//!
//! ## Blob File Organization
//!
//! ```
//! <storage_root>/
//!     └── blobs/
//!         └── <database_id>/
//!             └── <object_store_id>/
//!                 └── <blob_id>.blob
//! ```
//!
//! ## Threshold Configuration
//!
//! Default: 64KB - values larger than this are stored externally
//! This can be configured per-database or globally.
//!
//! ## Spec References
//!
//! - File API: https://w3c.github.io/FileAPI/
//! - IndexedDB Structured Clone: https://html.spec.whatwg.org/multipage/structured-data.html

const std = @import("std");

// ============================================================================
// Blob Reference
// ============================================================================

/// Reference to an externally stored blob
pub const BlobReference = struct {
    /// Unique blob ID
    id: u64,
    /// Blob size in bytes
    size: u64,
    /// MIME type (if known)
    mime_type: ?[]const u8,
    /// Original filename (for File objects)
    filename: ?[]const u8,
    /// Last modified timestamp (for File objects)
    last_modified: ?i64,
    /// Hash for integrity verification (optional)
    hash: ?[32]u8,
    /// Allocator (for owned strings)
    allocator: ?std.mem.Allocator,

    const Self = @This();

    /// Create a new blob reference
    pub fn init(id: u64, size: u64) Self {
        return Self{
            .id = id,
            .size = size,
            .mime_type = null,
            .filename = null,
            .last_modified = null,
            .hash = null,
            .allocator = null,
        };
    }

    /// Create with allocator for owned strings
    pub fn initOwned(allocator: std.mem.Allocator, id: u64, size: u64) Self {
        var ref = init(id, size);
        ref.allocator = allocator;
        return ref;
    }

    pub fn deinit(self: *Self) void {
        if (self.allocator) |alloc| {
            if (self.mime_type) |mt| alloc.free(mt);
            if (self.filename) |fn_| alloc.free(fn_);
        }
        self.* = undefined;
    }

    /// Set MIME type
    pub fn setMimeType(self: *Self, mime: []const u8) !void {
        if (self.allocator) |alloc| {
            if (self.mime_type) |old| alloc.free(old);
            self.mime_type = try alloc.dupe(u8, mime);
        } else {
            self.mime_type = mime;
        }
    }

    /// Set filename
    pub fn setFilename(self: *Self, name: []const u8) !void {
        if (self.allocator) |alloc| {
            if (self.filename) |old| alloc.free(old);
            self.filename = try alloc.dupe(u8, name);
        } else {
            self.filename = name;
        }
    }

    /// Encode to bytes for storage in SQLite
    pub fn encode(self: Self, allocator: std.mem.Allocator) ![]u8 {
        // Format: [magic:4][id:8][size:8][mime_len:2][mime:?][name_len:2][name:?][last_mod:8?][hash:32?][flags:1]
        const magic = [4]u8{ 'B', 'R', 'E', 'F' };
        const mime_len: u16 = if (self.mime_type) |mt| @intCast(mt.len) else 0;
        const name_len: u16 = if (self.filename) |fn_| @intCast(fn_.len) else 0;

        var flags: u8 = 0;
        if (self.last_modified != null) flags |= 0x01;
        if (self.hash != null) flags |= 0x02;

        var total_size: usize = 4 + 8 + 8 + 2 + mime_len + 2 + name_len + 1;
        if (self.last_modified != null) total_size += 8;
        if (self.hash != null) total_size += 32;

        var result = try allocator.alloc(u8, total_size);
        var pos: usize = 0;

        // Magic
        @memcpy(result[pos .. pos + 4], &magic);
        pos += 4;

        // ID (big-endian)
        std.mem.writeInt(u64, result[pos..][0..8], self.id, .big);
        pos += 8;

        // Size (big-endian)
        std.mem.writeInt(u64, result[pos..][0..8], self.size, .big);
        pos += 8;

        // MIME type
        std.mem.writeInt(u16, result[pos..][0..2], mime_len, .big);
        pos += 2;
        if (self.mime_type) |mt| {
            @memcpy(result[pos .. pos + mt.len], mt);
            pos += mt.len;
        }

        // Filename
        std.mem.writeInt(u16, result[pos..][0..2], name_len, .big);
        pos += 2;
        if (self.filename) |fn_| {
            @memcpy(result[pos .. pos + fn_.len], fn_);
            pos += fn_.len;
        }

        // Flags
        result[pos] = flags;
        pos += 1;

        // Optional fields
        if (self.last_modified) |lm| {
            std.mem.writeInt(i64, result[pos..][0..8], lm, .big);
            pos += 8;
        }
        if (self.hash) |h| {
            @memcpy(result[pos .. pos + 32], &h);
        }

        return result;
    }

    /// Decode from bytes
    pub fn decode(allocator: std.mem.Allocator, data: []const u8) !Self {
        if (data.len < 23) return error.InvalidBlobReference;

        // Check magic
        if (!std.mem.eql(u8, data[0..4], &[_]u8{ 'B', 'R', 'E', 'F' })) {
            return error.InvalidBlobReference;
        }

        var pos: usize = 4;

        const id = std.mem.readInt(u64, data[pos..][0..8], .big);
        pos += 8;

        const size = std.mem.readInt(u64, data[pos..][0..8], .big);
        pos += 8;

        var ref = BlobReference.initOwned(allocator, id, size);
        errdefer ref.deinit();

        // MIME type
        const mime_len = std.mem.readInt(u16, data[pos..][0..2], .big);
        pos += 2;
        if (mime_len > 0) {
            if (pos + mime_len > data.len) return error.InvalidBlobReference;
            try ref.setMimeType(data[pos .. pos + mime_len]);
            pos += mime_len;
        }

        // Filename
        const name_len = std.mem.readInt(u16, data[pos..][0..2], .big);
        pos += 2;
        if (name_len > 0) {
            if (pos + name_len > data.len) return error.InvalidBlobReference;
            try ref.setFilename(data[pos .. pos + name_len]);
            pos += name_len;
        }

        // Flags
        if (pos >= data.len) return error.InvalidBlobReference;
        const flags = data[pos];
        pos += 1;

        // Optional fields
        if (flags & 0x01 != 0) {
            if (pos + 8 > data.len) return error.InvalidBlobReference;
            ref.last_modified = std.mem.readInt(i64, data[pos..][0..8], .big);
            pos += 8;
        }
        if (flags & 0x02 != 0) {
            if (pos + 32 > data.len) return error.InvalidBlobReference;
            ref.hash = data[pos..][0..32].*;
        }

        return ref;
    }
};

// ============================================================================
// Blob Storage Manager
// ============================================================================

/// Manages external blob storage
pub const BlobStorageManager = struct {
    /// Storage root directory
    storage_root: []const u8,
    /// Threshold for external storage (bytes)
    size_threshold: u64,
    /// Next blob ID
    next_blob_id: u64,
    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Default size threshold: 64KB
    pub const DEFAULT_THRESHOLD: u64 = 64 * 1024;

    pub fn init(allocator: std.mem.Allocator, storage_root: []const u8) !Self {
        const root_copy = try allocator.dupe(u8, storage_root);
        return Self{
            .storage_root = root_copy,
            .size_threshold = DEFAULT_THRESHOLD,
            .next_blob_id = 1,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.storage_root);
        self.* = undefined;
    }

    /// Check if a value should be stored externally
    pub fn shouldStoreExternally(self: Self, size: u64) bool {
        return size > self.size_threshold;
    }

    /// Generate path for a blob file
    pub fn getBlobPath(
        self: Self,
        allocator: std.mem.Allocator,
        database_id: i64,
        store_id: i64,
        blob_id: u64,
    ) ![]u8 {
        return std.fmt.allocPrint(
            allocator,
            "{s}/blobs/{d}/{d}/{d}.blob",
            .{ self.storage_root, database_id, store_id, blob_id },
        );
    }

    /// Generate blob directory path
    pub fn getBlobDir(
        self: Self,
        allocator: std.mem.Allocator,
        database_id: i64,
        store_id: i64,
    ) ![]u8 {
        return std.fmt.allocPrint(
            allocator,
            "{s}/blobs/{d}/{d}",
            .{ self.storage_root, database_id, store_id },
        );
    }

    /// Store a blob and return its reference
    pub fn storeBlob(
        self: *Self,
        database_id: i64,
        store_id: i64,
        data: []const u8,
        mime_type: ?[]const u8,
        filename: ?[]const u8,
    ) !BlobReference {
        const blob_id = self.next_blob_id;
        self.next_blob_id += 1;

        // Get blob path
        const path = try self.getBlobPath(self.allocator, database_id, store_id, blob_id);
        defer self.allocator.free(path);

        // Ensure directory exists
        const dir_path = try self.getBlobDir(self.allocator, database_id, store_id);
        defer self.allocator.free(dir_path);

        std.fs.cwd().makePath(dir_path) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        // Write blob file
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        try file.writeAll(data);

        // Create reference
        var ref = BlobReference.initOwned(self.allocator, blob_id, data.len);
        if (mime_type) |mt| try ref.setMimeType(mt);
        if (filename) |fn_| try ref.setFilename(fn_);

        return ref;
    }

    /// Read a blob by reference
    pub fn readBlob(
        self: Self,
        allocator: std.mem.Allocator,
        database_id: i64,
        store_id: i64,
        ref: BlobReference,
    ) ![]u8 {
        const path = try self.getBlobPath(allocator, database_id, store_id, ref.id);
        defer allocator.free(path);

        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const data = try allocator.alloc(u8, ref.size);
        errdefer allocator.free(data);

        const bytes_read = try file.readAll(data);
        if (bytes_read != ref.size) {
            return error.BlobSizeMismatch;
        }

        return data;
    }

    /// Delete a blob
    pub fn deleteBlob(
        self: Self,
        database_id: i64,
        store_id: i64,
        blob_id: u64,
    ) !void {
        const path = try self.getBlobPath(self.allocator, database_id, store_id, blob_id);
        defer self.allocator.free(path);

        std.fs.cwd().deleteFile(path) catch |err| {
            if (err != error.FileNotFound) return err;
        };
    }

    /// Delete all blobs for an object store
    pub fn deleteAllBlobs(
        self: Self,
        database_id: i64,
        store_id: i64,
    ) !void {
        const dir_path = try self.getBlobDir(self.allocator, database_id, store_id);
        defer self.allocator.free(dir_path);

        std.fs.cwd().deleteTree(dir_path) catch |err| {
            if (err != error.FileNotFound) return err;
        };
    }

    /// Delete all blobs for a database
    pub fn deleteDatabase(
        self: Self,
        database_id: i64,
    ) !void {
        const dir_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/blobs/{d}",
            .{ self.storage_root, database_id },
        );
        defer self.allocator.free(dir_path);

        std.fs.cwd().deleteTree(dir_path) catch |err| {
            if (err != error.FileNotFound) return err;
        };
    }

    /// Get total blob storage size for a database
    pub fn getDatabaseBlobSize(self: Self, database_id: i64) !u64 {
        const dir_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/blobs/{d}",
            .{ self.storage_root, database_id },
        );
        defer self.allocator.free(dir_path);

        var total_size: u64 = 0;

        var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch |err| {
            if (err == error.FileNotFound) return 0;
            return err;
        };
        defer dir.close();

        var walker = dir.walk(self.allocator) catch return 0;
        defer walker.deinit();

        while (walker.next() catch null) |entry| {
            if (entry.kind == .file) {
                const stat = entry.dir.statFile(entry.basename) catch continue;
                total_size += stat.size;
            }
        }

        return total_size;
    }
};

// ============================================================================
// Value Wrapper
// ============================================================================

/// Wraps a value that may be stored inline or as blob reference
pub const StoredValue = union(enum) {
    /// Value stored inline in SQLite
    inline_value: []const u8,
    /// Value stored in external blob file
    blob_reference: BlobReference,

    const Self = @This();

    /// Check if value is stored externally
    pub fn isExternal(self: Self) bool {
        return self == .blob_reference;
    }

    /// Get size of stored value
    pub fn size(self: Self) u64 {
        return switch (self) {
            .inline_value => |v| v.len,
            .blob_reference => |ref| ref.size,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "BlobReference - init and encode/decode" {
    const allocator = std.testing.allocator;

    var ref = BlobReference.initOwned(allocator, 42, 1024);
    defer ref.deinit();

    try ref.setMimeType("application/octet-stream");
    try ref.setFilename("test.bin");
    ref.last_modified = 1700000000000;

    const encoded = try ref.encode(allocator);
    defer allocator.free(encoded);

    var decoded = try BlobReference.decode(allocator, encoded);
    defer decoded.deinit();

    try std.testing.expectEqual(@as(u64, 42), decoded.id);
    try std.testing.expectEqual(@as(u64, 1024), decoded.size);
    try std.testing.expectEqualStrings("application/octet-stream", decoded.mime_type.?);
    try std.testing.expectEqualStrings("test.bin", decoded.filename.?);
    try std.testing.expectEqual(@as(i64, 1700000000000), decoded.last_modified.?);
}

test "BlobReference - minimal encode/decode" {
    const allocator = std.testing.allocator;

    var ref = BlobReference.init(1, 500);

    const encoded = try ref.encode(allocator);
    defer allocator.free(encoded);

    var decoded = try BlobReference.decode(allocator, encoded);
    defer decoded.deinit();

    try std.testing.expectEqual(@as(u64, 1), decoded.id);
    try std.testing.expectEqual(@as(u64, 500), decoded.size);
    try std.testing.expect(decoded.mime_type == null);
    try std.testing.expect(decoded.filename == null);
}

test "BlobStorageManager - shouldStoreExternally" {
    const allocator = std.testing.allocator;

    var mgr = try BlobStorageManager.init(allocator, "/tmp/test_blobs");
    defer mgr.deinit();

    // Under threshold
    try std.testing.expect(!mgr.shouldStoreExternally(1000));
    try std.testing.expect(!mgr.shouldStoreExternally(64 * 1024)); // Exactly at threshold

    // Over threshold
    try std.testing.expect(mgr.shouldStoreExternally(64 * 1024 + 1));
    try std.testing.expect(mgr.shouldStoreExternally(1_000_000));
}

test "BlobStorageManager - getBlobPath" {
    const allocator = std.testing.allocator;

    var mgr = try BlobStorageManager.init(allocator, "/data/storage");
    defer mgr.deinit();

    const path = try mgr.getBlobPath(allocator, 1, 2, 3);
    defer allocator.free(path);

    try std.testing.expectEqualStrings("/data/storage/blobs/1/2/3.blob", path);
}

test "StoredValue - isExternal" {
    const inline_val = StoredValue{ .inline_value = "hello" };
    try std.testing.expect(!inline_val.isExternal());

    const blob_val = StoredValue{ .blob_reference = BlobReference.init(1, 1000) };
    try std.testing.expect(blob_val.isExternal());
}
