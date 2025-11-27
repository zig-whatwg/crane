//! File System Entry Types
//!
//! Spec: https://fs.spec.whatwg.org/#concepts
//!
//! A file system entry is either a file entry or a directory entry.
//! These are internal types used by the backend implementations.

const std = @import("std");
const errors = @import("errors.zig");
const locator = @import("locator.zig");

const FileSystemAccessResult = errors.FileSystemAccessResult;
const FileSystemLocator = locator.FileSystemLocator;

/// The lock state of a file entry.
/// https://fs.spec.whatwg.org/#file-entry-lock
pub const LockState = enum {
    /// No lock is held
    open,
    /// An exclusive lock is held (by FileSystemSyncAccessHandle)
    taken_exclusive,
    /// One or more shared locks are held (by FileSystemWritableFileStream)
    taken_shared,
};

/// Result of attempting to take a lock.
pub const LockResult = enum {
    success,
    failure,
};

/// Access mode for permission checks.
pub const AccessMode = enum {
    read,
    readwrite,

    pub fn toString(self: AccessMode) []const u8 {
        return switch (self) {
            .read => "read",
            .readwrite => "readwrite",
        };
    }
};

/// Function type for query/request access algorithms.
/// These are provided by the backend and called to check permissions.
pub const AccessAlgorithm = *const fn (mode: AccessMode) FileSystemAccessResult;

/// A file entry represents a file in the file system.
/// https://fs.spec.whatwg.org/#file-entry
pub const FileEntry = struct {
    /// The name of this entry
    entry_name: []const u8,
    /// Binary data (the file contents)
    binary_data: std.ArrayListUnmanaged(u8),
    /// Modification timestamp (milliseconds since Unix epoch)
    modification_timestamp: i64,
    /// Lock state
    lock: LockState,
    /// Number of shared locks held
    shared_lock_count: usize,
    /// Query access algorithm (provided by backend)
    query_access: ?AccessAlgorithm,
    /// Request access algorithm (provided by backend)
    request_access: ?AccessAlgorithm,
    /// Allocator for this entry
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Create a new file entry
    pub fn init(allocator: std.mem.Allocator, entry_name: []const u8) !Self {
        const owned_name = try allocator.dupe(u8, entry_name);
        return .{
            .entry_name = owned_name,
            .binary_data = .{},
            .modification_timestamp = std.time.milliTimestamp(),
            .lock = .open,
            .shared_lock_count = 0,
            .query_access = null,
            .request_access = null,
            .allocator = allocator,
        };
    }

    /// Create a new file entry with access algorithms
    pub fn initWithAccess(
        allocator: std.mem.Allocator,
        entry_name: []const u8,
        query: ?AccessAlgorithm,
        request: ?AccessAlgorithm,
    ) !Self {
        var entry = try Self.init(allocator, entry_name);
        entry.query_access = query;
        entry.request_access = request;
        return entry;
    }

    /// Get the entry name
    pub fn name(self: *const Self) []const u8 {
        return self.entry_name;
    }

    /// Get the binary data
    pub fn data(self: *const Self) []const u8 {
        return self.binary_data.items;
    }

    /// Set the binary data
    pub fn setData(self: *Self, new_data: []const u8) !void {
        self.binary_data.clearRetainingCapacity();
        try self.binary_data.appendSlice(self.allocator, new_data);
        self.modification_timestamp = std.time.milliTimestamp();
    }

    /// Get the size in bytes
    pub fn size(self: *const Self) u64 {
        return self.binary_data.items.len;
    }

    /// Run the query access algorithm.
    /// https://fs.spec.whatwg.org/#file-entry-query-access
    pub fn queryAccess(self: *const Self, mode: AccessMode) FileSystemAccessResult {
        if (self.query_access) |algo| {
            return algo(mode);
        }
        // Default: return denied per spec
        return FileSystemAccessResult.denied(.NotAllowedError);
    }

    /// Run the request access algorithm.
    /// https://fs.spec.whatwg.org/#file-entry-request-access
    pub fn requestAccess(self: *const Self, mode: AccessMode) FileSystemAccessResult {
        if (self.request_access) |algo| {
            return algo(mode);
        }
        // Default: return denied per spec
        return FileSystemAccessResult.denied(.NotAllowedError);
    }

    /// Take a lock on this file entry.
    /// https://fs.spec.whatwg.org/#take-a-lock
    pub fn takeLock(self: *Self, value: enum { exclusive, shared }) LockResult {
        switch (value) {
            .exclusive => {
                if (self.lock == .open) {
                    self.lock = .taken_exclusive;
                    return .success;
                }
                return .failure;
            },
            .shared => {
                if (self.lock == .open) {
                    self.lock = .taken_shared;
                    self.shared_lock_count = 1;
                    return .success;
                } else if (self.lock == .taken_shared) {
                    self.shared_lock_count += 1;
                    return .success;
                }
                return .failure;
            },
        }
    }

    /// Release a lock on this file entry.
    /// https://fs.spec.whatwg.org/#release-a-lock
    pub fn releaseLock(self: *Self) void {
        if (self.lock == .taken_shared) {
            self.shared_lock_count -= 1;
            if (self.shared_lock_count == 0) {
                self.lock = .open;
            }
        } else {
            self.lock = .open;
        }
    }

    /// Check if the file is locked
    pub fn isLocked(self: *const Self) bool {
        return self.lock != .open;
    }

    /// Free this entry's resources
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.entry_name);
        self.binary_data.deinit(self.allocator);
    }
};

/// A directory entry represents a directory in the file system.
/// https://fs.spec.whatwg.org/#directory-entry
pub const DirectoryEntry = struct {
    /// The name of this entry
    entry_name: []const u8,
    /// Children entries (files and directories)
    children: std.StringHashMap(Entry),
    /// Query access algorithm (provided by backend)
    query_access: ?AccessAlgorithm,
    /// Request access algorithm (provided by backend)
    request_access: ?AccessAlgorithm,
    /// Allocator for this entry
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Create a new directory entry
    pub fn init(allocator: std.mem.Allocator, entry_name: []const u8) !Self {
        const owned_name = try allocator.dupe(u8, entry_name);
        return .{
            .entry_name = owned_name,
            .children = std.StringHashMap(Entry).init(allocator),
            .query_access = null,
            .request_access = null,
            .allocator = allocator,
        };
    }

    /// Create a new directory entry with access algorithms
    pub fn initWithAccess(
        allocator: std.mem.Allocator,
        entry_name: []const u8,
        query: ?AccessAlgorithm,
        request: ?AccessAlgorithm,
    ) !Self {
        var entry = try Self.init(allocator, entry_name);
        entry.query_access = query;
        entry.request_access = request;
        return entry;
    }

    /// Get the entry name
    pub fn name(self: *const Self) []const u8 {
        return self.entry_name;
    }

    /// Run the query access algorithm.
    pub fn queryAccess(self: *const Self, mode: AccessMode) FileSystemAccessResult {
        if (self.query_access) |algo| {
            return algo(mode);
        }
        // Default: return denied per spec
        return FileSystemAccessResult.denied(.NotAllowedError);
    }

    /// Run the request access algorithm.
    pub fn requestAccess(self: *const Self, mode: AccessMode) FileSystemAccessResult {
        if (self.request_access) |algo| {
            return algo(mode);
        }
        // Default: return denied per spec
        return FileSystemAccessResult.denied(.NotAllowedError);
    }

    /// Get a child entry by name
    pub fn getChild(self: *Self, child_name: []const u8) ?*Entry {
        return self.children.getPtr(child_name);
    }

    /// Check if a child exists
    pub fn hasChild(self: *const Self, child_name: []const u8) bool {
        return self.children.contains(child_name);
    }

    /// Add a child file entry
    pub fn addFile(self: *Self, child_name: []const u8) !*FileEntry {
        const owned_name = try self.allocator.dupe(u8, child_name);
        errdefer self.allocator.free(owned_name);

        var file = try FileEntry.initWithAccess(
            self.allocator,
            child_name,
            self.query_access,
            self.request_access,
        );
        errdefer file.deinit();

        try self.children.put(owned_name, .{ .file = file });
        const entry = self.children.getPtr(owned_name).?;
        return &entry.file;
    }

    /// Add a child directory entry
    pub fn addDirectory(self: *Self, child_name: []const u8) !*DirectoryEntry {
        const owned_name = try self.allocator.dupe(u8, child_name);
        errdefer self.allocator.free(owned_name);

        var dir = try DirectoryEntry.initWithAccess(
            self.allocator,
            child_name,
            self.query_access,
            self.request_access,
        );
        errdefer dir.deinit();

        try self.children.put(owned_name, .{ .directory = dir });
        const entry = self.children.getPtr(owned_name).?;
        return &entry.directory;
    }

    /// Remove a child entry
    pub fn removeChild(self: *Self, child_name: []const u8, recursive: bool) !void {
        const entry = self.children.getPtr(child_name) orelse return;

        switch (entry.*) {
            .directory => |*dir| {
                if (dir.children.count() > 0 and !recursive) {
                    return errors.FileSystemError.InvalidModification;
                }
                dir.deinit();
            },
            .file => |*file| {
                file.deinit();
            },
        }

        // Free the key and remove from map
        if (self.children.fetchRemove(child_name)) |kv| {
            self.allocator.free(kv.key);
        }
    }

    /// Get the number of children
    pub fn childCount(self: *const Self) usize {
        return self.children.count();
    }

    /// Check if the directory is empty
    pub fn isEmpty(self: *const Self) bool {
        return self.children.count() == 0;
    }

    /// Iterator for children
    pub fn childIterator(self: *Self) std.StringHashMap(Entry).Iterator {
        return self.children.iterator();
    }

    /// Free this entry's resources
    pub fn deinit(self: *Self) void {
        var it = self.children.iterator();
        while (it.next()) |kv| {
            self.allocator.free(kv.key_ptr.*);
            switch (kv.value_ptr.*) {
                .file => |*f| f.deinit(),
                .directory => |*d| d.deinit(),
            }
        }
        self.children.deinit();
        self.allocator.free(self.entry_name);
    }
};

/// A file system entry is either a file entry or a directory entry.
/// https://fs.spec.whatwg.org/#file-system-entry
pub const Entry = union(enum) {
    file: FileEntry,
    directory: DirectoryEntry,

    /// Get the name of this entry
    pub fn name(self: *const Entry) []const u8 {
        return switch (self.*) {
            .file => |*f| f.name(),
            .directory => |*d| d.name(),
        };
    }

    /// Check if this is a file entry
    pub fn isFile(self: *const Entry) bool {
        return self.* == .file;
    }

    /// Check if this is a directory entry
    pub fn isDirectory(self: *const Entry) bool {
        return self.* == .directory;
    }

    /// Run the query access algorithm
    pub fn queryAccess(self: *const Entry, mode: AccessMode) FileSystemAccessResult {
        return switch (self.*) {
            .file => |*f| f.queryAccess(mode),
            .directory => |*d| d.queryAccess(mode),
        };
    }

    /// Run the request access algorithm
    pub fn requestAccess(self: *const Entry, mode: AccessMode) FileSystemAccessResult {
        return switch (self.*) {
            .file => |*f| f.requestAccess(mode),
            .directory => |*d| d.requestAccess(mode),
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "FileEntry - basic operations" {
    const allocator = std.testing.allocator;
    var entry = try FileEntry.init(allocator, "test.txt");
    defer entry.deinit();

    try std.testing.expectEqualStrings("test.txt", entry.name());
    try std.testing.expectEqual(@as(u64, 0), entry.size());
    try std.testing.expect(!entry.isLocked());

    try entry.setData("Hello, World!");
    try std.testing.expectEqual(@as(u64, 13), entry.size());
    try std.testing.expectEqualStrings("Hello, World!", entry.data());
}

test "FileEntry - lock exclusive" {
    const allocator = std.testing.allocator;
    var entry = try FileEntry.init(allocator, "test.txt");
    defer entry.deinit();

    // Take exclusive lock
    try std.testing.expectEqual(LockResult.success, entry.takeLock(.exclusive));
    try std.testing.expect(entry.isLocked());
    try std.testing.expectEqual(LockState.taken_exclusive, entry.lock);

    // Can't take another exclusive lock
    try std.testing.expectEqual(LockResult.failure, entry.takeLock(.exclusive));

    // Can't take shared lock while exclusive is held
    try std.testing.expectEqual(LockResult.failure, entry.takeLock(.shared));

    // Release lock
    entry.releaseLock();
    try std.testing.expect(!entry.isLocked());
}

test "FileEntry - lock shared" {
    const allocator = std.testing.allocator;
    var entry = try FileEntry.init(allocator, "test.txt");
    defer entry.deinit();

    // Take shared lock
    try std.testing.expectEqual(LockResult.success, entry.takeLock(.shared));
    try std.testing.expect(entry.isLocked());
    try std.testing.expectEqual(LockState.taken_shared, entry.lock);
    try std.testing.expectEqual(@as(usize, 1), entry.shared_lock_count);

    // Can take another shared lock
    try std.testing.expectEqual(LockResult.success, entry.takeLock(.shared));
    try std.testing.expectEqual(@as(usize, 2), entry.shared_lock_count);

    // Can't take exclusive while shared is held
    try std.testing.expectEqual(LockResult.failure, entry.takeLock(.exclusive));

    // Release one shared lock
    entry.releaseLock();
    try std.testing.expect(entry.isLocked());
    try std.testing.expectEqual(@as(usize, 1), entry.shared_lock_count);

    // Release last shared lock
    entry.releaseLock();
    try std.testing.expect(!entry.isLocked());
}

test "DirectoryEntry - basic operations" {
    const allocator = std.testing.allocator;
    var dir = try DirectoryEntry.init(allocator, "mydir");
    defer dir.deinit();

    try std.testing.expectEqualStrings("mydir", dir.name());
    try std.testing.expect(dir.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), dir.childCount());
}

test "DirectoryEntry - add children" {
    const allocator = std.testing.allocator;
    var dir = try DirectoryEntry.init(allocator, "mydir");
    defer dir.deinit();

    // Add a file
    const file = try dir.addFile("document.txt");
    try std.testing.expectEqualStrings("document.txt", file.name());
    try std.testing.expectEqual(@as(usize, 1), dir.childCount());

    // Add a subdirectory
    const subdir = try dir.addDirectory("subdir");
    try std.testing.expectEqualStrings("subdir", subdir.name());
    try std.testing.expectEqual(@as(usize, 2), dir.childCount());

    // Check children exist
    try std.testing.expect(dir.hasChild("document.txt"));
    try std.testing.expect(dir.hasChild("subdir"));
    try std.testing.expect(!dir.hasChild("nonexistent"));
}

test "DirectoryEntry - remove children" {
    const allocator = std.testing.allocator;
    var dir = try DirectoryEntry.init(allocator, "mydir");
    defer dir.deinit();

    // Add files
    _ = try dir.addFile("file1.txt");
    _ = try dir.addFile("file2.txt");
    try std.testing.expectEqual(@as(usize, 2), dir.childCount());

    // Remove a file
    try dir.removeChild("file1.txt", false);
    try std.testing.expectEqual(@as(usize, 1), dir.childCount());
    try std.testing.expect(!dir.hasChild("file1.txt"));
    try std.testing.expect(dir.hasChild("file2.txt"));
}

test "DirectoryEntry - non-empty directory removal" {
    const allocator = std.testing.allocator;
    var dir = try DirectoryEntry.init(allocator, "mydir");
    defer dir.deinit();

    // Add subdirectory with a file
    const subdir = try dir.addDirectory("subdir");
    _ = try subdir.addFile("nested.txt");

    // Should fail without recursive flag
    try std.testing.expectError(errors.FileSystemError.InvalidModification, dir.removeChild("subdir", false));

    // Should succeed with recursive flag
    try dir.removeChild("subdir", true);
    try std.testing.expect(!dir.hasChild("subdir"));
}

test "Entry - union operations" {
    const allocator = std.testing.allocator;
    var file = try FileEntry.init(allocator, "test.txt");
    defer file.deinit();

    var entry = Entry{ .file = file };
    // Note: entry doesn't own file, so we don't deinit entry

    try std.testing.expect(entry.isFile());
    try std.testing.expect(!entry.isDirectory());
    try std.testing.expectEqualStrings("test.txt", entry.name());
}
