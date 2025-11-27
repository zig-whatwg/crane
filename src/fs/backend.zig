//! File System Backend Trait
//!
//! Spec: https://fs.spec.whatwg.org/
//!
//! Defines the backend trait interface that must be implemented by
//! embedders for their specific platform. This library provides only
//! the interface - no pre-built backends are shipped.

const std = @import("std");
const errors = @import("errors.zig");
const locator = @import("locator.zig");
const entry = @import("entry.zig");

const FileSystemError = errors.FileSystemError;
const FileSystemAccessResult = errors.FileSystemAccessResult;
const FileSystemLocator = locator.FileSystemLocator;
const FileSystemPath = locator.FileSystemPath;
const FileSystemRoot = locator.FileSystemRoot;
const FileSystemHandleKind = locator.FileSystemHandleKind;
const FileEntry = entry.FileEntry;
const DirectoryEntry = entry.DirectoryEntry;
const Entry = entry.Entry;
const AccessMode = entry.AccessMode;

/// Backend error type combining file system errors with I/O errors.
pub const BackendError = FileSystemError || error{
    /// I/O error from underlying system
    IoError,
    /// Backend is not initialized
    NotInitialized,
    /// Operation not supported by this backend
    NotSupported,
    /// Backend-specific error
    BackendSpecific,
};

/// Result type for backend operations.
pub fn BackendResult(comptime T: type) type {
    return BackendError!T;
}

/// Iterator for directory children.
/// Backends implement this to provide directory iteration.
pub const ChildIterator = struct {
    /// Context pointer for the backend
    context: *anyopaque,
    /// Get the next child entry
    /// Returns null when iteration is complete
    nextFn: *const fn (context: *anyopaque) ?ChildEntry,
    /// Clean up iterator resources
    deinitFn: *const fn (context: *anyopaque) void,

    const Self = @This();

    /// Get the next child entry
    pub fn next(self: *Self) ?ChildEntry {
        return self.nextFn(self.context);
    }

    /// Clean up iterator resources
    pub fn deinit(self: *Self) void {
        self.deinitFn(self.context);
    }
};

/// A child entry returned during directory iteration.
pub const ChildEntry = struct {
    /// Name of the child
    name: []const u8,
    /// Kind of the child (file or directory)
    kind: FileSystemHandleKind,
};

/// Handle serialization data.
/// Used for structured clone serialization of handles.
pub const SerializedHandle = struct {
    /// The serialized locator data
    data: []const u8,
    /// Origin that created this handle
    origin: []const u8,
    /// Allocator used for the data
    allocator: std.mem.Allocator,

    pub fn deinit(self: *SerializedHandle) void {
        self.allocator.free(self.data);
        self.allocator.free(self.origin);
    }
};

/// Storage key for bucket file system operations.
/// Typically derived from origin.
pub const StorageKey = struct {
    /// The origin string
    origin: []const u8,
};

/// File System Backend Trait
///
/// This trait defines the interface that backends must implement to provide
/// file system operations. Backends are responsible for:
/// - Entry location and retrieval
/// - File read/write operations
/// - Directory operations (create, remove, list)
/// - Permission checking (delegated to OS)
/// - Bucket file system support
/// - Handle serialization
///
/// Embedders implement this trait for their platform:
/// - macOS: POSIX + Security framework for sandboxed access
/// - Linux: POSIX
/// - Windows: Win32 API
/// - iOS/Android: Platform-specific sandboxed storage
pub const FileSystemBackend = struct {
    /// Opaque pointer to backend-specific context
    context: *anyopaque,

    /// Vtable for backend operations
    vtable: *const VTable,

    const Self = @This();

    pub const VTable = struct {
        // ====================================================================
        // Entry Location
        // ====================================================================

        /// Locate an entry given a locator.
        /// https://fs.spec.whatwg.org/#locate-an-entry
        ///
        /// Returns the entry at the locator's path, or null if not found.
        /// The entry remains owned by the backend.
        locateEntry: *const fn (context: *anyopaque, file_locator: *const FileSystemLocator) ?*Entry,

        /// Get the locator for an entry.
        /// https://fs.spec.whatwg.org/#get-the-locator
        ///
        /// Returns a new locator that points to the given entry.
        /// Caller owns the returned locator.
        getLocator: *const fn (context: *anyopaque, allocator: std.mem.Allocator, file_entry: *const Entry) BackendResult(FileSystemLocator),

        // ====================================================================
        // File Operations
        // ====================================================================

        /// Read the binary data from a file entry.
        ///
        /// Returns a copy of the file's contents.
        /// Caller owns the returned slice.
        readFile: *const fn (context: *anyopaque, allocator: std.mem.Allocator, file_entry: *const FileEntry) BackendResult([]u8),

        /// Write binary data to a file entry.
        ///
        /// Replaces the file's contents with the given data.
        writeFile: *const fn (context: *anyopaque, file_entry: *FileEntry, data: []const u8) BackendError!void,

        /// Get the modification timestamp of a file.
        ///
        /// Returns milliseconds since Unix epoch.
        getModificationTime: *const fn (context: *anyopaque, file_entry: *const FileEntry) i64,

        // ====================================================================
        // Directory Operations
        // ====================================================================

        /// Create a new file in a directory.
        ///
        /// Returns a pointer to the newly created file entry.
        /// The entry is owned by the backend/parent directory.
        createFile: *const fn (context: *anyopaque, parent: *DirectoryEntry, name: []const u8) BackendResult(*FileEntry),

        /// Create a new directory in a directory.
        ///
        /// Returns a pointer to the newly created directory entry.
        /// The entry is owned by the backend/parent directory.
        createDirectory: *const fn (context: *anyopaque, parent: *DirectoryEntry, name: []const u8) BackendResult(*DirectoryEntry),

        /// Remove an entry from a directory.
        ///
        /// If recursive is false and the entry is a non-empty directory,
        /// returns InvalidModification error.
        removeEntry: *const fn (context: *anyopaque, parent: *DirectoryEntry, name: []const u8, recursive: bool) BackendError!void,

        /// List children of a directory.
        ///
        /// Returns an iterator over the directory's children.
        /// Caller must call deinit() on the iterator when done.
        listChildren: *const fn (context: *anyopaque, parent: *const DirectoryEntry) ChildIterator,

        // ====================================================================
        // Permissions (delegated to OS)
        // ====================================================================

        /// Query access permission for an entry.
        /// https://fs.spec.whatwg.org/#file-entry-query-access
        ///
        /// Checks if the current context has the requested access level
        /// without prompting the user.
        queryAccess: *const fn (context: *anyopaque, file_entry: *const Entry, mode: AccessMode) FileSystemAccessResult,

        /// Request access permission for an entry.
        /// https://fs.spec.whatwg.org/#file-entry-request-access
        ///
        /// May prompt the user for permission if needed.
        /// For bucket file systems, always returns granted.
        requestAccess: *const fn (context: *anyopaque, file_entry: *const Entry, mode: AccessMode) FileSystemAccessResult,

        // ====================================================================
        // Bucket File System
        // ====================================================================

        /// Get the root directory of a bucket file system.
        /// https://fs.spec.whatwg.org/#bucket-file-system
        ///
        /// Creates the bucket root if it doesn't exist.
        /// The root directory is owned by the backend.
        getBucketRoot: *const fn (context: *anyopaque, storage_key: StorageKey) BackendResult(*DirectoryEntry),

        // ====================================================================
        // Serialization
        // ====================================================================

        /// Serialize a handle for structured clone.
        /// https://fs.spec.whatwg.org/#filesystemhandle-serialization-steps
        ///
        /// Returns serialized data that can be deserialized later.
        /// Caller owns the returned SerializedHandle.
        serializeHandle: *const fn (context: *anyopaque, allocator: std.mem.Allocator, file_locator: *const FileSystemLocator, origin: []const u8) BackendResult(SerializedHandle),

        /// Deserialize a handle from structured clone data.
        /// https://fs.spec.whatwg.org/#filesystemhandle-deserialization-steps
        ///
        /// Returns a new locator from the serialized data.
        /// Caller owns the returned locator.
        deserializeHandle: *const fn (context: *anyopaque, allocator: std.mem.Allocator, serialized: *const SerializedHandle, expected_origin: []const u8) BackendResult(FileSystemLocator),

        // ====================================================================
        // Lifecycle
        // ====================================================================

        /// Clean up backend resources.
        deinit: *const fn (context: *anyopaque) void,
    };

    // ========================================================================
    // Public API (delegates to vtable)
    // ========================================================================

    /// Locate an entry given a locator.
    pub fn locateEntry(self: Self, file_locator: *const FileSystemLocator) ?*Entry {
        return self.vtable.locateEntry(self.context, file_locator);
    }

    /// Get the locator for an entry.
    pub fn getLocator(self: Self, allocator: std.mem.Allocator, file_entry: *const Entry) BackendResult(FileSystemLocator) {
        return self.vtable.getLocator(self.context, allocator, file_entry);
    }

    /// Read the binary data from a file entry.
    pub fn readFile(self: Self, allocator: std.mem.Allocator, file_entry: *const FileEntry) BackendResult([]u8) {
        return self.vtable.readFile(self.context, allocator, file_entry);
    }

    /// Write binary data to a file entry.
    pub fn writeFile(self: Self, file_entry: *FileEntry, data: []const u8) BackendError!void {
        return self.vtable.writeFile(self.context, file_entry, data);
    }

    /// Get the modification timestamp of a file.
    pub fn getModificationTime(self: Self, file_entry: *const FileEntry) i64 {
        return self.vtable.getModificationTime(self.context, file_entry);
    }

    /// Create a new file in a directory.
    pub fn createFile(self: Self, parent: *DirectoryEntry, name: []const u8) BackendResult(*FileEntry) {
        return self.vtable.createFile(self.context, parent, name);
    }

    /// Create a new directory in a directory.
    pub fn createDirectory(self: Self, parent: *DirectoryEntry, name: []const u8) BackendResult(*DirectoryEntry) {
        return self.vtable.createDirectory(self.context, parent, name);
    }

    /// Remove an entry from a directory.
    pub fn removeEntry(self: Self, parent: *DirectoryEntry, name: []const u8, recursive: bool) BackendError!void {
        return self.vtable.removeEntry(self.context, parent, name, recursive);
    }

    /// List children of a directory.
    pub fn listChildren(self: Self, parent: *const DirectoryEntry) ChildIterator {
        return self.vtable.listChildren(self.context, parent);
    }

    /// Query access permission for an entry.
    pub fn queryAccess(self: Self, file_entry: *const Entry, mode: AccessMode) FileSystemAccessResult {
        return self.vtable.queryAccess(self.context, file_entry, mode);
    }

    /// Request access permission for an entry.
    pub fn requestAccess(self: Self, file_entry: *const Entry, mode: AccessMode) FileSystemAccessResult {
        return self.vtable.requestAccess(self.context, file_entry, mode);
    }

    /// Get the root directory of a bucket file system.
    pub fn getBucketRoot(self: Self, storage_key: StorageKey) BackendResult(*DirectoryEntry) {
        return self.vtable.getBucketRoot(self.context, storage_key);
    }

    /// Serialize a handle for structured clone.
    pub fn serializeHandle(self: Self, allocator: std.mem.Allocator, file_locator: *const FileSystemLocator, origin: []const u8) BackendResult(SerializedHandle) {
        return self.vtable.serializeHandle(self.context, allocator, file_locator, origin);
    }

    /// Deserialize a handle from structured clone data.
    pub fn deserializeHandle(self: Self, allocator: std.mem.Allocator, serialized: *const SerializedHandle, expected_origin: []const u8) BackendResult(FileSystemLocator) {
        return self.vtable.deserializeHandle(self.context, allocator, serialized, expected_origin);
    }

    /// Clean up backend resources.
    pub fn deinit(self: Self) void {
        self.vtable.deinit(self.context);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "BackendError - error set" {
    // Just verify the error set compiles correctly
    const err: BackendError = error.NotFound;
    try std.testing.expect(err == error.NotFound);
}

test "ChildEntry - structure" {
    const child = ChildEntry{
        .name = "test.txt",
        .kind = .file,
    };
    try std.testing.expectEqualStrings("test.txt", child.name);
    try std.testing.expectEqual(FileSystemHandleKind.file, child.kind);
}

test "StorageKey - structure" {
    const key = StorageKey{
        .origin = "https://example.com",
    };
    try std.testing.expectEqualStrings("https://example.com", key.origin);
}
