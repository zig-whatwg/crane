//! W3C File API - Blob Internal Data Structure
//!
//! This module implements the internal storage structure for Blob objects.
//! A Blob represents immutable raw binary data, stored either directly in
//! memory (the fast path for in-memory Blobs) or as a list of parts that may
//! reference file-backed sources (Blink's BlobData / BlobDataHandle +
//! storage/browser/blob FileStreamReader model).
//!
//! Spec: https://www.w3.org/TR/FileAPI/#blob-section
//!
//! ## Blob Internal Slots
//!
//! Each Blob has these internal slots:
//! - [[BlobData]]: A byte sequence (in-memory or lazily read from file parts)
//! - [[Size]]: The size of the byte sequence (known up front from snapshot)
//! - [[Type]]: A MIME type string (constructor input is lowercased ASCII)
//!
//! ## Thread Safety
//!
//! Both `BlobData` and `FileBacking` use atomic reference counting: a BlobData
//! may be retained by a Blob URL entry or structured clone and dropped from
//! another thread (page thread, worker thread, or Browser teardown). When the
//! last reference to a `FileBacking` drops, its `release` operation releases
//! the underlying platform `FileToken`.

const std = @import("std");

/// Failure reading a file-backed Blob part.
///
/// File API §7.1:
/// - `NotFoundError`: the backing file could not be found on disk at read time.
/// - `NotReadableError`: the backing file's snapshot state (size or mtime)
///   changed since selection, or the file could not be read.
pub const FileReadError = error{
    NotFoundError,
    NotReadableError,
    OutOfMemory,
};

/// Platform-neutral operations for a file-backed Blob source, modeled on
/// `url.BlobURLEntry.Operations` so `file` stays independent of `platform`.
pub const FileSourceOps = struct {
    /// Read up to `length` bytes at `offset`, checking the file's snapshot
    /// (size + mtime). A `length` of 0 still validates existence and snapshot
    /// state and returns an empty slice on success. Caller owns the returned
    /// slice (freed with `allocator`).
    read: *const fn (ctx: *anyopaque, offset: u64, length: u32, allocator: std.mem.Allocator) FileReadError![]u8,
    /// Release the backing token / context when the last reference drops.
    /// Must be thread-safe (may run from any thread of the Browser).
    release: *const fn (ctx: *anyopaque) void,
};

/// A thread-safe, reference-counted handle to a file-backed source (a
/// `platform.FileToken` plus its snapshot metadata). Shared by the original
/// `File`, any `slice()` of it, any `new Blob([file, ...])` referencing it,
/// and any structured clone / Blob URL entry holding it.
pub const FileBacking = struct {
    allocator: std.mem.Allocator,
    ctx: *anyopaque,
    ops: *const FileSourceOps,
    snapshot_size: u64,
    snapshot_modified_ns: i64,
    ref_count: std.atomic.Value(u32) = .init(1),

    /// Create a new FileBacking with ref_count = 1. Takes ownership of `ctx`
    /// on success; on allocation failure the caller still owns `ctx`.
    pub fn init(
        allocator: std.mem.Allocator,
        ctx: *anyopaque,
        ops: *const FileSourceOps,
        snapshot_size: u64,
        snapshot_modified_ns: i64,
    ) error{OutOfMemory}!*FileBacking {
        const self = try allocator.create(FileBacking);
        self.* = .{
            .allocator = allocator,
            .ctx = ctx,
            .ops = ops,
            .snapshot_size = snapshot_size,
            .snapshot_modified_ns = snapshot_modified_ns,
        };
        return self;
    }

    pub fn retain(self: *FileBacking) *FileBacking {
        _ = self.ref_count.fetchAdd(1, .monotonic);
        return self;
    }

    pub fn release(self: *FileBacking) void {
        const previous = self.ref_count.fetchSub(1, .release);
        std.debug.assert(previous > 0);
        if (previous != 1) return;
        _ = self.ref_count.load(.acquire);
        const allocator = self.allocator;
        self.ops.release(self.ctx);
        allocator.destroy(self);
    }
};

/// A byte range within a `FileBacking`.
pub const FileSlice = struct {
    backing: *FileBacking,
    offset: u64,
    length: u64,
};

/// One piece of a composite or file-backed `BlobData`.
pub const Part = union(enum) {
    /// Owned by the enclosing `BlobData.allocator` when `len > 0`.
    bytes: []const u8,
    /// Retained `*FileBacking` plus range.
    file: FileSlice,
};

/// Bytes materialized from a `BlobData`: borrowed with zero copy for an
/// in-memory `BlobData`, or owned (freed on `deinit`) for a file-backed one.
pub const MaterializedBytes = struct {
    slice: []const u8,
    allocator: ?std.mem.Allocator = null,

    pub fn deinit(self: *MaterializedBytes) void {
        if (self.allocator) |allocator| {
            if (self.slice.len > 0) allocator.free(@constCast(self.slice));
        }
        self.* = .{ .slice = "" };
    }

    /// Return an owned copy in `allocator` (moves without copying when already
    /// owned by `allocator`, and clears `self`).
    pub fn intoOwned(self: *MaterializedBytes, allocator: std.mem.Allocator) error{OutOfMemory}![]u8 {
        if (self.allocator) |_| {
            const owned: []u8 = @constCast(self.slice);
            self.* = .{ .slice = "" };
            return owned;
        }
        const copy = try allocator.dupe(u8, self.slice);
        self.* = .{ .slice = "" };
        return copy;
    }
};

/// Chunk size per `FileSourceOps.read` call when materializing a file range.
const file_read_chunk: u32 = 1 << 20;

/// Internal data storage for a Blob object.
///
/// Per W3C File API spec, a Blob has:
/// - An associated byte sequence (immutable; in-memory or file-backed parts)
/// - A size (derived from byte sequence length or file snapshot)
/// - A type (constructors normalize it; other specifications may set it)
pub const BlobData = struct {
    pub const Storage = union(enum) {
        /// Fast path for in-memory Blobs: no parts array, zero extra indirection.
        memory: struct {
            bytes: []const u8,
            owns_bytes: bool,
        },
        /// Blink-style parts list for file-backed Files, their slices, and
        /// composite Blobs (`new Blob([file, "tail"])`).
        parts: struct {
            items: []Part,
            total_size: u64,
        },
    };

    /// Underlying byte storage (in-memory or lazy parts).
    storage: Storage,

    /// The MIME type as a UTF-8 DOMString. Constructors normalize it to
    /// lowercase ASCII or empty; specification-created types are preserved.
    mime_type: []const u8,

    /// Memory allocator for cleanup
    allocator: std.mem.Allocator,

    /// The references held on this data: the Blob object's (the one `init`
    /// makes), and one for each blob URL entry, composite Blob, or structured
    /// clone that names it. Atomic: holders may live on different threads
    /// (docs/instances.md).
    ref_count: std.atomic.Value(u32) = .init(1),

    /// Initialize a new in-memory BlobData with the given bytes and MIME type.
    ///
    /// The bytes are copied, and the MIME type is validated and normalized.
    /// Invalid MIME type characters result in an empty type string.
    pub fn init(allocator: std.mem.Allocator, bytes: []const u8, mime_type: []const u8) !*BlobData {
        const self = try allocator.create(BlobData);
        errdefer allocator.destroy(self);

        const owned_bytes = try allocator.dupe(u8, bytes);
        errdefer allocator.free(owned_bytes);

        const normalized_type = try normalizeMimeType(allocator, mime_type);

        self.* = .{
            .storage = .{ .memory = .{ .bytes = owned_bytes, .owns_bytes = true } },
            .mime_type = normalized_type,
            .allocator = allocator,
        };

        return self;
    }

    /// A specification-created in-memory Blob whose type is already serialized.
    /// Unlike the public constructor, this preserves the given DOMString
    /// (UTF-8), including MIME parameter-value case. The caller validates it.
    pub fn initWithType(allocator: std.mem.Allocator, bytes: []const u8, mime_type: []const u8) !*BlobData {
        const self = try allocator.create(BlobData);
        errdefer allocator.destroy(self);
        const owned_bytes = try allocator.dupe(u8, bytes);
        errdefer allocator.free(owned_bytes);
        const owned_type = if (mime_type.len > 0) try allocator.dupe(u8, mime_type) else "";
        self.* = .{
            .storage = .{ .memory = .{ .bytes = owned_bytes, .owns_bytes = true } },
            .mime_type = owned_type,
            .allocator = allocator,
        };
        return self;
    }

    /// Initialize a BlobData that borrows bytes from another source.
    pub fn initBorrowed(allocator: std.mem.Allocator, bytes: []const u8, mime_type: []const u8) !*BlobData {
        const self = try allocator.create(BlobData);
        errdefer allocator.destroy(self);

        const normalized_type = try normalizeMimeType(allocator, mime_type);

        self.* = .{
            .storage = .{ .memory = .{ .bytes = bytes, .owns_bytes = false } },
            .mime_type = normalized_type,
            .allocator = allocator,
        };

        return self;
    }

    /// Initialize a file-backed BlobData referencing the full snapshot of
    /// `backing` (retains `backing`). Does NOT read the file.
    pub fn initFile(allocator: std.mem.Allocator, backing: *FileBacking, mime_type: []const u8) !*BlobData {
        const self = try allocator.create(BlobData);
        errdefer allocator.destroy(self);

        const items = try allocator.alloc(Part, 1);
        errdefer allocator.free(items);

        const normalized_type = try normalizeMimeType(allocator, mime_type);

        items[0] = .{
            .file = .{
                .backing = backing.retain(),
                .offset = 0,
                .length = backing.snapshot_size,
            },
        };
        self.* = .{
            .storage = .{ .parts = .{ .items = items, .total_size = backing.snapshot_size } },
            .mime_type = normalized_type,
            .allocator = allocator,
        };
        return self;
    }

    /// Initialize a parts-backed BlobData from an owned `items` slice (in
    /// `allocator`, with each `.bytes` owned by `allocator` and each
    /// `.file.backing` already retained). Takes ownership of `items` ONLY on
    /// success.
    pub fn initParts(allocator: std.mem.Allocator, items: []Part, total_size: u64, mime_type: []const u8) !*BlobData {
        const self = try allocator.create(BlobData);
        errdefer allocator.destroy(self);

        const normalized_type = try normalizeMimeType(allocator, mime_type);

        self.* = .{
            .storage = .{ .parts = .{ .items = items, .total_size = total_size } },
            .mime_type = normalized_type,
            .allocator = allocator,
        };
        return self;
    }

    /// Take another reference: the data stays until each holder has called
    /// `deinit`. Returns `self`, for the holder to keep.
    pub fn retain(self: *BlobData) *BlobData {
        _ = self.ref_count.fetchAdd(1, .monotonic);
        return self;
    }

    /// Drop one reference; the last one frees the data and releases any
    /// retained `FileBacking` tokens.
    pub fn deinit(self: *BlobData) void {
        const previous = self.ref_count.fetchSub(1, .release);
        std.debug.assert(previous > 0);
        if (previous != 1) return;
        _ = self.ref_count.load(.acquire);
        switch (self.storage) {
            .memory => |mem| {
                if (mem.owns_bytes) {
                    self.allocator.free(@constCast(mem.bytes));
                }
            },
            .parts => |parts| {
                for (parts.items) |part| switch (part) {
                    .bytes => |b| if (b.len > 0) self.allocator.free(@constCast(b)),
                    .file => |f| f.backing.release(),
                };
                self.allocator.free(parts.items);
            },
        }
        if (self.mime_type.len > 0) {
            self.allocator.free(@constCast(self.mime_type));
        }
        self.allocator.destroy(self);
    }

    /// True if all bytes are already in memory (no file-backed parts).
    pub fn isMemoryOnly(self: *const BlobData) bool {
        return self.storage == .memory;
    }

    /// Borrowed in-memory bytes when `isMemoryOnly()`, or null when backed by
    /// file parts.
    pub fn memoryBytes(self: *const BlobData) ?[]const u8 {
        return switch (self.storage) {
            .memory => |mem| mem.bytes,
            .parts => null,
        };
    }

    /// Get the size of the blob in bytes without reading disk.
    /// Per spec: "The size attribute must return the total number of bytes"
    pub fn size(self: *const BlobData) u64 {
        return switch (self.storage) {
            .memory => |mem| mem.bytes.len,
            .parts => |parts| parts.total_size,
        };
    }

    /// Get the MIME type of the blob.
    /// Per spec: "The type attribute must return the MIME type of the Blob"
    /// Returns empty string if type is unknown or invalid.
    pub fn getType(self: *const BlobData) []const u8 {
        return self.mime_type;
    }

    /// Read all bytes of this BlobData. Borrows with zero allocation when
    /// memory-only; reads and verifies snapshots when file-backed.
    pub fn readBytes(self: *const BlobData, allocator: std.mem.Allocator) FileReadError!MaterializedBytes {
        switch (self.storage) {
            .memory => |mem| return .{ .slice = mem.bytes, .allocator = null },
            .parts => {
                const owned = try self.materialize(allocator);
                return .{ .slice = owned, .allocator = allocator };
            },
        }
    }

    /// Materialize the full byte sequence into a newly allocated buffer owned
    /// by `allocator`. Checks file existence and snapshot state for every file
    /// part (including 0-byte files).
    pub fn materialize(self: *const BlobData, allocator: std.mem.Allocator) FileReadError![]u8 {
        switch (self.storage) {
            .memory => |mem| return allocator.dupe(u8, mem.bytes),
            .parts => |parts| {
                const total = std.math.cast(usize, parts.total_size) orelse return error.OutOfMemory;
                const out = try allocator.alloc(u8, total);
                errdefer allocator.free(out);
                var cursor: usize = 0;
                for (parts.items) |part| switch (part) {
                    .bytes => |b| {
                        @memcpy(out[cursor..][0..b.len], b);
                        cursor += b.len;
                    },
                    .file => |f| {
                        try readFileSliceInto(allocator, f.backing, f.offset, f.length, out[cursor..][0..@intCast(f.length)]);
                        cursor += @intCast(f.length);
                    },
                };
                return out;
            },
        }
    }

    /// Read up to `max_len` bytes starting at `offset` (for streaming pulls).
    /// When `offset == 0` and `size() == 0` on a file-backed blob, still
    /// validates any 0-byte file part's snapshot so reading a deleted or
    /// modified 0-byte file fails with `NotFoundError` / `NotReadableError`.
    pub fn readRange(self: *const BlobData, allocator: std.mem.Allocator, offset: u64, max_len: usize) FileReadError![]u8 {
        switch (self.storage) {
            .memory => |mem| {
                if (offset >= mem.bytes.len or max_len == 0) return allocator.alloc(u8, 0);
                const start: usize = @intCast(offset);
                const take = @min(max_len, mem.bytes.len - start);
                return allocator.dupe(u8, mem.bytes[start..][0..take]);
            },
            .parts => |parts| {
                if (parts.total_size == 0) {
                    if (offset == 0) {
                        for (parts.items) |part| switch (part) {
                            .bytes => {},
                            .file => |f| {
                                const probe = try f.backing.ops.read(f.backing.ctx, f.offset, 0, allocator);
                                allocator.free(probe);
                            },
                        };
                    }
                    return allocator.alloc(u8, 0);
                }
                if (offset >= parts.total_size or max_len == 0) return allocator.alloc(u8, 0);
                const available = parts.total_size - offset;
                const want: usize = @intCast(@min(@as(u64, max_len), available));
                const out = try allocator.alloc(u8, want);
                errdefer allocator.free(out);

                var skip: u64 = offset;
                var written: usize = 0;
                for (parts.items) |part| {
                    if (written == want) break;
                    const part_len: u64 = switch (part) {
                        .bytes => |b| b.len,
                        .file => |f| f.length,
                    };
                    if (skip >= part_len) {
                        // Even if a zero-length file part sits at our exact
                        // position, probe it when starting at offset 0.
                        if (part_len == 0 and offset == 0 and written == 0) {
                            if (part == .file) {
                                const probe = try part.file.backing.ops.read(part.file.backing.ctx, part.file.offset, 0, allocator);
                                allocator.free(probe);
                            }
                        }
                        skip -= part_len;
                        continue;
                    }
                    const avail_in_part = part_len - skip;
                    const take: usize = @intCast(@min(avail_in_part, @as(u64, want - written)));
                    switch (part) {
                        .bytes => |b| {
                            const start: usize = @intCast(skip);
                            @memcpy(out[written..][0..take], b[start..][0..take]);
                        },
                        .file => |f| {
                            try readFileSliceInto(allocator, f.backing, f.offset + skip, take, out[written..][0..take]);
                        },
                    }
                    written += take;
                    skip = 0;
                }
                return out;
            },
        }
    }

    fn readFileSliceInto(
        allocator: std.mem.Allocator,
        backing: *FileBacking,
        start_offset: u64,
        length: u64,
        dest: []u8,
    ) FileReadError!void {
        if (length == 0) {
            // Still validate file existence and snapshot state for 0-byte files.
            const probe = try backing.ops.read(backing.ctx, start_offset, 0, allocator);
            allocator.free(probe);
            return;
        }
        var done: usize = 0;
        const total: usize = @intCast(length);
        while (done < total) {
            const want: u32 = @intCast(@min(total - done, file_read_chunk));
            const chunk = try backing.ops.read(backing.ctx, start_offset + done, want, allocator);
            defer allocator.free(chunk);
            if (chunk.len == 0) return error.NotReadableError;
            const copy_len = @min(chunk.len, total - done);
            @memcpy(dest[done..][0..copy_len], chunk[0..copy_len]);
            done += copy_len;
        }
    }

    /// Normalize a MIME type string per W3C File API spec.
    ///
    /// Per spec §3.1:
    /// - If type contains characters outside U+0020-U+007E, return empty string
    /// - Convert to ASCII lowercase
    fn normalizeMimeType(allocator: std.mem.Allocator, mime_type: []const u8) ![]const u8 {
        if (mime_type.len == 0) {
            return "";
        }

        for (mime_type) |c| {
            if (c < 0x20 or c > 0x7E) {
                return "";
            }
        }

        const normalized = try allocator.alloc(u8, mime_type.len);
        for (mime_type, 0..) |c, i| {
            normalized[i] = std.ascii.toLower(c);
        }

        return normalized;
    }
};

test "BlobData - basic initialization" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "Hello, World!", "text/plain");
    defer blob.deinit();

    try std.testing.expectEqualStrings("Hello, World!", blob.memoryBytes().?);
    try std.testing.expectEqual(@as(u64, 13), blob.size());
    try std.testing.expectEqualStrings("text/plain", blob.getType());
}

test "BlobData - MIME type normalization" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "test", "TEXT/PLAIN");
    defer blob.deinit();

    try std.testing.expectEqualStrings("text/plain", blob.getType());
}

test "BlobData - invalid MIME type characters" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "test", "text/plain\x00");
    defer blob.deinit();

    try std.testing.expectEqualStrings("", blob.getType());
}

test "BlobData - empty MIME type" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "test", "");
    defer blob.deinit();

    try std.testing.expectEqualStrings("", blob.getType());
}

test "BlobData - empty bytes" {
    const allocator = std.testing.allocator;

    const blob = try BlobData.init(allocator, "", "text/plain");
    defer blob.deinit();

    try std.testing.expectEqual(@as(u64, 0), blob.size());
}
