//! Bucket File System Implementation
//!
//! Spec: https://fs.spec.whatwg.org/#bucket-file-system
//!
//! A bucket file system is an origin-private file system that is associated
//! with a storage bucket. Each bucket file system provides isolated storage
//! for a single origin.
//!
//! ## Features
//!
//! - Per-origin isolation
//! - Automatic permission granting (no user prompts needed)
//! - Integration with Storage Standard quota management
//! - Accessible via StorageManager.getDirectory()
//!
//! ## Architecture
//!
//! The bucket file system integrates with the Storage Standard:
//!
//! ```
//! StorageShed
//!   └── StorageKey (origin)
//!       └── StorageShelf
//!           └── StorageBucket
//!               └── BucketFileSystem (this module)
//!                   └── DirectoryEntry (root)
//!                       └── children...
//! ```

const std = @import("std");
const entry_mod = @import("entry.zig");
const locator_mod = @import("locator.zig");
const directory_handle_mod = @import("directory_handle.zig");
const backend_mod = @import("backend.zig");
const errors = @import("errors.zig");

const DirectoryEntry = entry_mod.DirectoryEntry;
const FileEntry = entry_mod.FileEntry;
const Entry = entry_mod.Entry;
const AccessMode = entry_mod.AccessMode;
const FileSystemLocator = locator_mod.FileSystemLocator;
const FileSystemDirectoryHandle = directory_handle_mod.FileSystemDirectoryHandle;
const FileSystemBackend = backend_mod.FileSystemBackend;
const StorageKey = backend_mod.StorageKey;
const FileSystemAccessResult = errors.FileSystemAccessResult;

/// Bucket file system provides per-origin file storage.
/// https://fs.spec.whatwg.org/#bucket-file-system
///
/// Each origin gets its own isolated file system that:
/// - Has no user-visible path on the local file system
/// - Automatically grants permissions (no prompts)
/// - Is subject to storage quota
pub const BucketFileSystem = struct {
    /// The origin this bucket belongs to
    origin: []const u8,
    /// The root directory entry
    root: DirectoryEntry,
    /// Allocator for operations
    allocator: std.mem.Allocator,
    /// Whether we own the origin string
    owns_origin: bool,

    const Self = @This();

    /// Create a new bucket file system for the given origin.
    pub fn init(allocator: std.mem.Allocator, origin: []const u8) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        const owned_origin = try allocator.dupe(u8, origin);
        errdefer allocator.free(owned_origin);

        // Create root directory with bucket access algorithms (always granted)
        var root = try DirectoryEntry.initWithAccess(
            allocator,
            "", // Root has empty name per spec
            bucketQueryAccess,
            bucketRequestAccess,
        );
        errdefer root.deinit();

        self.* = .{
            .origin = owned_origin,
            .root = root,
            .allocator = allocator,
            .owns_origin = true,
        };

        return self;
    }

    /// Get the root directory handle.
    /// https://fs.spec.whatwg.org/#dom-storagemanager-getdirectory
    ///
    /// Returns a FileSystemDirectoryHandle for the bucket's root directory.
    pub fn getDirectory(self: *Self) !FileSystemDirectoryHandle {
        // Create a locator for the bucket root
        const root_locator = try FileSystemLocator.bucketRoot(
            self.allocator,
            self.origin,
        );

        // Create the backend for this bucket
        const fs_backend = self.createBackend();

        // Create the directory handle
        return FileSystemDirectoryHandle.init(
            self.allocator,
            root_locator,
            fs_backend,
        );
    }

    /// Get the root directory entry (for internal use).
    pub fn getRootEntry(self: *Self) *DirectoryEntry {
        return &self.root;
    }

    /// Get the origin for this bucket.
    pub fn getOrigin(self: *const Self) []const u8 {
        return self.origin;
    }

    /// Check if a locator points to an entry in this bucket.
    pub fn containsLocator(self: *const Self, file_locator: *const FileSystemLocator) bool {
        return std.mem.eql(u8, file_locator.root.value, self.origin);
    }

    /// Create a FileSystemBackend instance for this bucket.
    /// This is used by handles to perform operations.
    fn createBackend(self: *Self) FileSystemBackend {
        return .{
            .context = @ptrCast(self),
            .vtable = &bucket_vtable,
        };
    }

    /// Free the bucket file system and all its contents.
    pub fn deinit(self: *Self) void {
        self.root.deinit();
        if (self.owns_origin) {
            self.allocator.free(self.origin);
        }
        self.allocator.destroy(self);
    }
};

// ============================================================================
// Bucket Access Algorithms
// ============================================================================

/// Query access algorithm for bucket file systems.
/// Bucket file systems always grant access - no permission prompts needed.
fn bucketQueryAccess(_: AccessMode) FileSystemAccessResult {
    return FileSystemAccessResult.granted();
}

/// Request access algorithm for bucket file systems.
/// Bucket file systems always grant access - no permission prompts needed.
fn bucketRequestAccess(_: AccessMode) FileSystemAccessResult {
    return FileSystemAccessResult.granted();
}

// ============================================================================
// Backend VTable Implementation
// ============================================================================

const bucket_vtable = FileSystemBackend.VTable{
    .locateEntry = bucketLocateEntry,
    .getLocator = bucketGetLocator,
    .readFile = bucketReadFile,
    .writeFile = bucketWriteFile,
    .getModificationTime = bucketGetModificationTime,
    .createFile = bucketCreateFile,
    .createDirectory = bucketCreateDirectory,
    .removeEntry = bucketRemoveEntry,
    .listChildren = bucketListChildren,
    .queryAccess = bucketBackendQueryAccess,
    .requestAccess = bucketBackendRequestAccess,
    .getBucketRoot = bucketGetBucketRoot,
    .serializeHandle = bucketSerializeHandle,
    .deserializeHandle = bucketDeserializeHandle,
    .deinit = bucketDeinit,
};

fn getBucket(ctx: *anyopaque) *BucketFileSystem {
    return @ptrCast(@alignCast(ctx));
}

fn bucketLocateEntry(ctx: *anyopaque, file_locator: *const FileSystemLocator) ?*Entry {
    const bucket = getBucket(ctx);

    // Check if this locator is for this bucket
    if (!bucket.containsLocator(file_locator)) {
        return null;
    }

    // Navigate from root following path components
    var current: *Entry = @ptrCast(&bucket.root);
    const path = &file_locator.path;

    // Skip the first component if it's empty (bucket root marker)
    var start_idx: usize = 0;
    if (path.components.items.len > 0 and path.components.items[0].len == 0) {
        start_idx = 1;
    }

    for (path.components.items[start_idx..]) |component| {
        if (component.len == 0) continue; // Skip empty components

        switch (current.*) {
            .directory => |*dir| {
                current = dir.getChild(component) orelse return null;
            },
            .file => return null, // Can't traverse into a file
        }
    }

    return current;
}

fn bucketGetLocator(ctx: *anyopaque, allocator: std.mem.Allocator, file_entry: *const Entry) backend_mod.BackendResult(FileSystemLocator) {
    const bucket = getBucket(ctx);
    _ = file_entry;

    // Build path by finding entry in tree
    // For simplicity, create a root locator - full path tracking would need parent pointers
    return FileSystemLocator.bucketRoot(allocator, bucket.origin);
}

fn bucketReadFile(_: *anyopaque, allocator: std.mem.Allocator, file_entry: *const FileEntry) backend_mod.BackendResult([]u8) {
    const data = file_entry.data();
    return allocator.dupe(u8, data);
}

fn bucketWriteFile(_: *anyopaque, file_entry: *FileEntry, data: []const u8) backend_mod.BackendError!void {
    try file_entry.setData(data);
}

fn bucketGetModificationTime(_: *anyopaque, file_entry: *const FileEntry) i64 {
    return file_entry.modification_timestamp;
}

fn bucketCreateFile(_: *anyopaque, parent: *DirectoryEntry, name: []const u8) backend_mod.BackendResult(*FileEntry) {
    return parent.addFile(name);
}

fn bucketCreateDirectory(_: *anyopaque, parent: *DirectoryEntry, name: []const u8) backend_mod.BackendResult(*DirectoryEntry) {
    return parent.addDirectory(name);
}

fn bucketRemoveEntry(_: *anyopaque, parent: *DirectoryEntry, name: []const u8, recursive: bool) backend_mod.BackendError!void {
    try parent.removeChild(name, recursive);
}

fn bucketListChildren(ctx: *anyopaque, parent: *const DirectoryEntry) backend_mod.ChildIterator {
    _ = ctx;

    // Create an iterator wrapper
    const IterContext = struct {
        iter: std.StringHashMap(Entry).Iterator,

        fn next(self_ctx: *anyopaque) ?backend_mod.ChildEntry {
            const self: *@This() = @ptrCast(@alignCast(self_ctx));
            if (self.iter.next()) |kv| {
                return .{
                    .name = kv.key_ptr.*,
                    .kind = switch (kv.value_ptr.*) {
                        .file => .file,
                        .directory => .directory,
                    },
                };
            }
            return null;
        }

        fn deinitIter(_: *anyopaque) void {
            // Nothing to clean up - iterator doesn't own anything
        }
    };

    // We need to store the iterator context somewhere
    // For now, use a simple approach - caller manages iteration
    var iter_ctx: IterContext = undefined;
    iter_ctx.iter = @constCast(parent).children.iterator();

    return .{
        .context = @ptrCast(&iter_ctx),
        .nextFn = IterContext.next,
        .deinitFn = IterContext.deinitIter,
    };
}

fn bucketBackendQueryAccess(_: *anyopaque, _: *const Entry, _: AccessMode) FileSystemAccessResult {
    // Bucket file systems always grant access
    return FileSystemAccessResult.granted();
}

fn bucketBackendRequestAccess(_: *anyopaque, _: *const Entry, _: AccessMode) FileSystemAccessResult {
    // Bucket file systems always grant access
    return FileSystemAccessResult.granted();
}

fn bucketGetBucketRoot(ctx: *anyopaque, storage_key: StorageKey) backend_mod.BackendResult(*DirectoryEntry) {
    const bucket = getBucket(ctx);

    // Verify the storage key matches
    if (!std.mem.eql(u8, storage_key.origin, bucket.origin)) {
        return error.NotFound;
    }

    return &bucket.root;
}

fn bucketSerializeHandle(ctx: *anyopaque, allocator: std.mem.Allocator, file_locator: *const FileSystemLocator, origin: []const u8) backend_mod.BackendResult(backend_mod.SerializedHandle) {
    const bucket = getBucket(ctx);
    _ = bucket;

    // Serialize the locator path
    var path_str = std.ArrayList(u8).init(allocator);
    errdefer path_str.deinit();

    for (file_locator.path.components.items, 0..) |component, i| {
        if (i > 0) {
            try path_str.append('/');
        }
        try path_str.appendSlice(component);
    }

    const origin_copy = try allocator.dupe(u8, origin);

    return .{
        .data = try path_str.toOwnedSlice(),
        .origin = origin_copy,
        .allocator = allocator,
    };
}

fn bucketDeserializeHandle(ctx: *anyopaque, allocator: std.mem.Allocator, serialized: *const backend_mod.SerializedHandle, expected_origin: []const u8) backend_mod.BackendResult(FileSystemLocator) {
    const bucket = getBucket(ctx);

    // Verify origin matches
    if (!std.mem.eql(u8, serialized.origin, expected_origin)) {
        return error.NotAllowed;
    }

    // Parse the path
    var components = std.ArrayList([]const u8).init(allocator);
    defer components.deinit();

    var iter = std.mem.splitScalar(u8, serialized.data, '/');
    while (iter.next()) |component| {
        try components.append(component);
    }

    // Determine if it's a file or directory by locating
    const file_locator = try FileSystemLocator.file(allocator, bucket.origin, components.items);
    errdefer {
        var loc = file_locator;
        loc.deinit();
    }

    // Try to locate and check kind
    if (bucketLocateEntry(ctx, &file_locator)) |entry| {
        if (entry.isDirectory()) {
            var loc = file_locator;
            loc.deinit();
            return FileSystemLocator.directory(allocator, bucket.origin, components.items);
        }
    }

    return file_locator;
}

fn bucketDeinit(ctx: *anyopaque) void {
    const bucket = getBucket(ctx);
    bucket.deinit();
}

// ============================================================================
// Bucket Manager
// ============================================================================

/// Manages bucket file systems for multiple origins.
/// This is typically owned by the storage system.
pub const BucketManager = struct {
    /// Map from origin to bucket file system
    buckets: std.StringHashMap(*BucketFileSystem),
    /// Allocator for creating buckets
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Create a new bucket manager.
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .buckets = std.StringHashMap(*BucketFileSystem).init(allocator),
            .allocator = allocator,
        };
    }

    /// Get or create a bucket file system for the given origin.
    pub fn getOrCreate(self: *Self, origin: []const u8) !*BucketFileSystem {
        if (self.buckets.get(origin)) |bucket| {
            return bucket;
        }

        // Create new bucket
        const bucket = try BucketFileSystem.init(self.allocator, origin);
        errdefer bucket.deinit();

        // Store with owned key
        const key = try self.allocator.dupe(u8, origin);
        errdefer self.allocator.free(key);

        try self.buckets.put(key, bucket);
        return bucket;
    }

    /// Get a bucket for the given origin if it exists.
    pub fn get(self: *Self, origin: []const u8) ?*BucketFileSystem {
        return self.buckets.get(origin);
    }

    /// Remove a bucket for the given origin.
    pub fn remove(self: *Self, origin: []const u8) void {
        if (self.buckets.fetchRemove(origin)) |kv| {
            self.allocator.free(kv.key);
            kv.value.deinit();
        }
    }

    /// Free all buckets.
    pub fn deinit(self: *Self) void {
        var iter = self.buckets.iterator();
        while (iter.next()) |kv| {
            self.allocator.free(kv.key_ptr.*);
            kv.value_ptr.*.deinit();
        }
        self.buckets.deinit();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "BucketFileSystem - init and deinit" {
    const allocator = std.testing.allocator;

    const bucket = try BucketFileSystem.init(allocator, "https://example.com");
    defer bucket.deinit();

    try std.testing.expectEqualStrings("https://example.com", bucket.getOrigin());
}

test "BucketFileSystem - root entry" {
    const allocator = std.testing.allocator;

    const bucket = try BucketFileSystem.init(allocator, "https://example.com");
    defer bucket.deinit();

    const root = bucket.getRootEntry();
    try std.testing.expectEqualStrings("", root.name());
    try std.testing.expect(root.isEmpty());
}

test "BucketFileSystem - auto grant permissions" {
    const allocator = std.testing.allocator;

    const bucket = try BucketFileSystem.init(allocator, "https://example.com");
    defer bucket.deinit();

    const root = bucket.getRootEntry();

    // Query and request should both be granted
    const query_result = root.queryAccess(.readwrite);
    try std.testing.expect(query_result.isGranted());

    const request_result = root.requestAccess(.readwrite);
    try std.testing.expect(request_result.isGranted());
}

test "BucketManager - getOrCreate" {
    const allocator = std.testing.allocator;

    var manager = BucketManager.init(allocator);
    defer manager.deinit();

    const bucket1 = try manager.getOrCreate("https://example.com");
    const bucket2 = try manager.getOrCreate("https://example.com");

    // Should return same bucket
    try std.testing.expectEqual(bucket1, bucket2);

    // Different origin gets different bucket
    const bucket3 = try manager.getOrCreate("https://other.com");
    try std.testing.expect(bucket1 != bucket3);
}

test "BucketManager - remove" {
    const allocator = std.testing.allocator;

    var manager = BucketManager.init(allocator);
    defer manager.deinit();

    _ = try manager.getOrCreate("https://example.com");
    try std.testing.expect(manager.get("https://example.com") != null);

    manager.remove("https://example.com");
    try std.testing.expect(manager.get("https://example.com") == null);
}
