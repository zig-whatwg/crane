//! FileSystem Backend Adapter
//!
//! Provides adapters between the old FileSystemBackend interface and the new
//! unified FileSystemVTable (C ABI compatible) interface.
//!
//! ## Migration Path
//!
//! 1. Existing code uses `FileSystemBackend` (Zig-native VTable) in src/fs/backend.zig
//! 2. New embedders implement `FileSystemVTable` (C ABI compatible)
//! 3. Adapters bridge between the two interfaces
//!
//! ## Design Notes
//!
//! The interfaces have different abstractions:
//! - FileSystemBackend uses Entry pointers and locators
//! - FileSystemVTable uses opaque u64 handles
//!
//! The adapter maintains a handle table to map between the two.

const std = @import("std");
const Allocator = std.mem.Allocator;

const vtables = @import("vtables.zig");
const FileSystemVTable = vtables.FileSystemVTable;
const FileSystemResult = vtables.FileSystemResult;
const FileHandle = vtables.FileHandle;
const DirectoryHandle = vtables.DirectoryHandle;
const FileMode = vtables.FileMode;
const OpaquePtr = vtables.OpaquePtr;

// =============================================================================
// FileSystemVTable -> FileSystemBackend Adapter
// =============================================================================

/// Adapter that wraps a FileSystemVTable and provides file system operations
/// through the unified C ABI interface.
///
/// Note: The full FileSystemBackend uses a complex Entry/Locator system that
/// doesn't map cleanly to the simpler handle-based C ABI. This adapter provides
/// the C ABI operations directly without mapping to the old interface.
pub const FileSystemBackendAdapter = struct {
    /// The wrapped VTable
    vtable: *const FileSystemVTable,
    /// User context passed to VTable functions
    user_context: OpaquePtr,
    /// Allocator for internal operations
    allocator: Allocator,

    const Self = @This();

    /// Create an adapter from a FileSystemVTable.
    pub fn init(
        allocator: Allocator,
        c_vtable: *const FileSystemVTable,
        user_context: OpaquePtr,
    ) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .vtable = c_vtable,
            .user_context = user_context,
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    // ========================================================================
    // File System Operations (using C ABI VTable)
    // ========================================================================

    /// Get the root directory handle
    pub fn getDirectory(self: *Self) DirectoryHandle {
        return self.vtable.call_getDirectory(self.user_context);
    }

    /// Get a file handle from a directory
    pub fn getFileHandle(self: *Self, dir: DirectoryHandle, name: []const u8, mode: FileMode, create: bool) FileHandle {
        return self.vtable.call_getFileHandle(self.user_context, dir, name.ptr, name.len, mode, create);
    }

    /// Get a subdirectory handle
    pub fn getDirectoryHandle(self: *Self, parent: DirectoryHandle, name: []const u8, create: bool) DirectoryHandle {
        return self.vtable.call_getDirectoryHandle(self.user_context, parent, name.ptr, name.len, create);
    }

    /// Read from a file
    pub fn read(self: *Self, handle: FileHandle, offset: u64, buffer: []u8) i64 {
        return self.vtable.call_read(self.user_context, handle, offset, buffer.ptr, buffer.len);
    }

    /// Write to a file
    pub fn write(self: *Self, handle: FileHandle, offset: u64, data: []const u8) i64 {
        return self.vtable.call_write(self.user_context, handle, offset, data.ptr, data.len);
    }

    /// Get file size
    pub fn getSize(self: *Self, handle: FileHandle) i64 {
        return self.vtable.call_getSize(self.user_context, handle);
    }

    /// Close a file handle
    pub fn closeFile(self: *Self, handle: FileHandle) void {
        self.vtable.call_closeFile(self.user_context, handle);
    }

    /// Close a directory handle
    pub fn closeDirectory(self: *Self, handle: DirectoryHandle) void {
        self.vtable.closeDirectory(self.user_context, handle);
    }

    /// Remove an entry from a directory
    pub fn removeEntry(self: *Self, parent: DirectoryHandle, name: []const u8, recursive: bool) FileSystemResult {
        return self.vtable.call_removeEntry(self.user_context, parent, name.ptr, name.len, recursive);
    }
};

// =============================================================================
// FileSystemVTableAdapter - Provides C ABI VTable for in-memory implementation
// =============================================================================

/// In-memory file system context for testing.
/// This implements the FileSystemVTable using in-memory storage.
pub const InMemoryFileSystem = struct {
    allocator: Allocator,
    /// Next handle ID
    next_handle: u64,
    /// File contents keyed by handle
    files: std.AutoHashMap(FileHandle, FileData),
    /// Directory entries keyed by handle
    directories: std.AutoHashMap(DirectoryHandle, DirData),
    /// Root directory handle
    root_handle: DirectoryHandle,

    const FileData = struct {
        name: []const u8,
        content: std.ArrayList(u8),
        parent: DirectoryHandle,
    };

    const DirData = struct {
        name: []const u8,
        parent: ?DirectoryHandle,
        children: std.ArrayList(ChildEntry),
    };

    const ChildEntry = struct {
        name: []const u8,
        handle: u64,
        is_dir: bool,
    };

    const Self = @This();

    /// Initialize an in-memory file system
    pub fn init(allocator: Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .allocator = allocator,
            .next_handle = 2, // 1 is reserved for root
            .files = std.AutoHashMap(FileHandle, FileData).init(allocator),
            .directories = std.AutoHashMap(DirectoryHandle, DirData).init(allocator),
            .root_handle = 1,
        };

        // Create root directory
        try self.directories.put(1, DirData{
            .name = try allocator.dupe(u8, "/"),
            .parent = null,
            .children = std.ArrayList(ChildEntry).init(allocator),
        });

        return self;
    }

    pub fn deinit(self: *Self) void {
        // Free file contents
        var file_iter = self.files.iterator();
        while (file_iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.name);
            entry.value_ptr.content.deinit();
        }
        self.files.deinit();

        // Free directory entries
        var dir_iter = self.directories.iterator();
        while (dir_iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.name);
            for (entry.value_ptr.children.items) |child| {
                self.allocator.free(child.name);
            }
            entry.value_ptr.children.deinit();
        }
        self.directories.deinit();

        self.allocator.destroy(self);
    }

    /// Get the VTable pointer
    pub fn getVTable() *const FileSystemVTable {
        return &vtable_impl;
    }

    /// Get the user context pointer
    pub fn getUserContext(self: *Self) OpaquePtr {
        return self;
    }

    // VTable implementation
    const vtable_impl = FileSystemVTable{
        .call_getDirectory = getDirectoryImpl,
        .call_getFileHandle = getFileHandleImpl,
        .call_getDirectoryHandle = getDirectoryHandleImpl,
        .call_read = readImpl,
        .call_write = writeImpl,
        .call_getSize = getSizeImpl,
        .call_closeFile = closeFileImpl,
        .closeDirectory = closeDirectoryImpl,
        .call_removeEntry = removeEntryImpl,
    };

    fn getDirectoryImpl(user_context: OpaquePtr) callconv(.c) DirectoryHandle {
        const self: *Self = @ptrCast(@alignCast(user_context));
        return self.root_handle;
    }

    fn getFileHandleImpl(
        user_context: OpaquePtr,
        dir: DirectoryHandle,
        name: [*]const u8,
        nameLen: usize,
        _: FileMode,
        create: bool,
    ) callconv(.c) FileHandle {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const file_name = name[0..nameLen];

        // Check if directory exists
        const dir_data = self.directories.getPtr(dir) orelse return 0;

        // Look for existing file
        for (dir_data.children.items) |child| {
            if (!child.is_dir and std.mem.eql(u8, child.name, file_name)) {
                return child.handle;
            }
        }

        // Create new file if requested
        if (create) {
            const handle = self.next_handle;
            self.next_handle += 1;

            const name_copy = self.allocator.dupe(u8, file_name) catch return 0;
            const name_copy2 = self.allocator.dupe(u8, file_name) catch {
                self.allocator.free(name_copy);
                return 0;
            };

            self.files.put(handle, FileData{
                .name = name_copy,
                .content = std.ArrayList(u8).init(self.allocator),
                .parent = dir,
            }) catch {
                self.allocator.free(name_copy);
                self.allocator.free(name_copy2);
                return 0;
            };

            dir_data.children.append(ChildEntry{
                .name = name_copy2,
                .handle = handle,
                .is_dir = false,
            }) catch {
                _ = self.files.remove(handle);
                self.allocator.free(name_copy);
                self.allocator.free(name_copy2);
                return 0;
            };

            return handle;
        }

        return 0;
    }

    fn getDirectoryHandleImpl(
        user_context: OpaquePtr,
        parent: DirectoryHandle,
        name: [*]const u8,
        nameLen: usize,
        create: bool,
    ) callconv(.c) DirectoryHandle {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const dir_name = name[0..nameLen];

        // Check if parent exists
        const parent_data = self.directories.getPtr(parent) orelse return 0;

        // Look for existing directory
        for (parent_data.children.items) |child| {
            if (child.is_dir and std.mem.eql(u8, child.name, dir_name)) {
                return child.handle;
            }
        }

        // Create new directory if requested
        if (create) {
            const handle = self.next_handle;
            self.next_handle += 1;

            const name_copy = self.allocator.dupe(u8, dir_name) catch return 0;
            const name_copy2 = self.allocator.dupe(u8, dir_name) catch {
                self.allocator.free(name_copy);
                return 0;
            };

            self.directories.put(handle, DirData{
                .name = name_copy,
                .parent = parent,
                .children = std.ArrayList(ChildEntry).init(self.allocator),
            }) catch {
                self.allocator.free(name_copy);
                self.allocator.free(name_copy2);
                return 0;
            };

            parent_data.children.append(ChildEntry{
                .name = name_copy2,
                .handle = handle,
                .is_dir = true,
            }) catch {
                _ = self.directories.remove(handle);
                self.allocator.free(name_copy);
                self.allocator.free(name_copy2);
                return 0;
            };

            return handle;
        }

        return 0;
    }

    fn readImpl(
        user_context: OpaquePtr,
        handle: FileHandle,
        offset: u64,
        buffer: [*]u8,
        bufferSize: usize,
    ) callconv(.c) i64 {
        const self: *Self = @ptrCast(@alignCast(user_context));

        const file_data = self.files.get(handle) orelse return -1;

        if (offset >= file_data.content.items.len) {
            return 0;
        }

        const start: usize = @intCast(offset);
        const available = file_data.content.items.len - start;
        const to_read = @min(bufferSize, available);

        @memcpy(buffer[0..to_read], file_data.content.items[start .. start + to_read]);
        return @intCast(to_read);
    }

    fn writeImpl(
        user_context: OpaquePtr,
        handle: FileHandle,
        offset: u64,
        data: [*]const u8,
        dataLen: usize,
    ) callconv(.c) i64 {
        const self: *Self = @ptrCast(@alignCast(user_context));

        const file_data = self.files.getPtr(handle) orelse return -1;

        const start: usize = @intCast(offset);
        const end = start + dataLen;

        // Extend file if needed
        if (end > file_data.content.items.len) {
            file_data.content.resize(end) catch return -1;
        }

        @memcpy(file_data.content.items[start..end], data[0..dataLen]);
        return @intCast(dataLen);
    }

    fn getSizeImpl(user_context: OpaquePtr, handle: FileHandle) callconv(.c) i64 {
        const self: *Self = @ptrCast(@alignCast(user_context));

        const file_data = self.files.get(handle) orelse return -1;
        return @intCast(file_data.content.items.len);
    }

    fn closeFileImpl(_: OpaquePtr, _: FileHandle) callconv(.c) void {
        // In-memory files don't need closing
    }

    fn closeDirectoryImpl(_: OpaquePtr, _: DirectoryHandle) callconv(.c) void {
        // In-memory directories don't need closing
    }

    fn removeEntryImpl(
        user_context: OpaquePtr,
        parent: DirectoryHandle,
        name: [*]const u8,
        nameLen: usize,
        recursive: bool,
    ) callconv(.c) FileSystemResult {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const entry_name = name[0..nameLen];

        const parent_data = self.directories.getPtr(parent) orelse return .not_found;

        // Find the entry
        var index: ?usize = null;
        for (parent_data.children.items, 0..) |child, i| {
            if (std.mem.eql(u8, child.name, entry_name)) {
                index = i;
                break;
            }
        }

        const idx = index orelse return .not_found;
        const child = parent_data.children.items[idx];

        if (child.is_dir) {
            const dir_data = self.directories.get(child.handle) orelse return .not_found;
            if (dir_data.children.items.len > 0 and !recursive) {
                return .not_empty;
            }
            // TODO: recursive deletion
            _ = self.directories.remove(child.handle);
        } else {
            if (self.files.fetchRemove(child.handle)) |entry| {
                self.allocator.free(entry.value.name);
                var content = entry.value.content;
                content.deinit();
            }
        }

        self.allocator.free(child.name);
        _ = parent_data.children.orderedRemove(idx);
        return .success;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "InMemoryFileSystem - basic operations" {
    const allocator = std.testing.allocator;

    const fs = try InMemoryFileSystem.init(allocator);
    defer fs.deinit();

    const c_vtable = InMemoryFileSystem.getVTable();
    const ctx = fs.getUserContext();

    // Get root directory
    const root = c_vtable.call_getDirectory(ctx);
    try std.testing.expect(root != 0);

    // Create a file
    const file = c_vtable.call_getFileHandle(ctx, root, "test.txt", 8, .write, true);
    try std.testing.expect(file != 0);

    // Write to file
    const data = "Hello, World!";
    const written = c_vtable.call_write(ctx, file, 0, data.ptr, data.len);
    try std.testing.expectEqual(@as(i64, 13), written);

    // Get file size
    const size = c_vtable.call_getSize(ctx, file);
    try std.testing.expectEqual(@as(i64, 13), size);

    // Read from file
    var buffer: [20]u8 = undefined;
    const read_bytes = c_vtable.call_read(ctx, file, 0, &buffer, 20);
    try std.testing.expectEqual(@as(i64, 13), read_bytes);
    try std.testing.expectEqualStrings("Hello, World!", buffer[0..13]);
}

test "InMemoryFileSystem - directory operations" {
    const allocator = std.testing.allocator;

    const fs = try InMemoryFileSystem.init(allocator);
    defer fs.deinit();

    const c_vtable = InMemoryFileSystem.getVTable();
    const ctx = fs.getUserContext();

    // Get root
    const root = c_vtable.call_getDirectory(ctx);

    // Create subdirectory
    const subdir = c_vtable.call_getDirectoryHandle(ctx, root, "subdir", 6, true);
    try std.testing.expect(subdir != 0);

    // Create file in subdirectory
    const file = c_vtable.call_getFileHandle(ctx, subdir, "file.txt", 8, .write, true);
    try std.testing.expect(file != 0);

    // Remove file
    const result1 = c_vtable.call_removeEntry(ctx, subdir, "file.txt", 8, false);
    try std.testing.expectEqual(FileSystemResult.success, result1);

    // Remove empty directory
    const result2 = c_vtable.call_removeEntry(ctx, root, "subdir", 6, false);
    try std.testing.expectEqual(FileSystemResult.success, result2);
}

test "FileSystemBackendAdapter - wraps VTable" {
    const allocator = std.testing.allocator;

    const fs = try InMemoryFileSystem.init(allocator);
    defer fs.deinit();

    const adapter = try FileSystemBackendAdapter.init(
        allocator,
        InMemoryFileSystem.getVTable(),
        fs.getUserContext(),
    );
    defer adapter.deinit();

    // Test through adapter
    const root = adapter.getDirectory();
    try std.testing.expect(root != 0);

    const file = adapter.getFileHandle(root, "test.txt", .write, true);
    try std.testing.expect(file != 0);

    const written = adapter.write(file, 0, "Hello");
    try std.testing.expectEqual(@as(i64, 5), written);

    const size = adapter.getSize(file);
    try std.testing.expectEqual(@as(i64, 5), size);
}
