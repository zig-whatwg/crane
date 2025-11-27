//! WHATWG File System Standard Algorithms
//!
//! Spec: https://fs.spec.whatwg.org/#algorithms
//!
//! This module implements the core algorithms defined in the File System Standard:
//! - Path resolution and normalization
//! - Entry location and traversal
//! - Validation routines
//! - Utility functions for file system operations

const std = @import("std");
const locator_mod = @import("locator.zig");
const entry_mod = @import("entry.zig");
const context_mod = @import("context.zig");
const errors = @import("errors.zig");

const FileSystemLocator = locator_mod.FileSystemLocator;
const FileSystemPath = locator_mod.FileSystemPath;
const FileSystemHandleKind = locator_mod.FileSystemHandleKind;
const DirectoryEntry = entry_mod.DirectoryEntry;
const FileEntry = entry_mod.FileEntry;
const Entry = entry_mod.Entry;
const FileSystemError = errors.FileSystemError;

// ============================================================================
// Path Validation
// ============================================================================

/// Check if a string is a valid file name per the spec.
/// https://fs.spec.whatwg.org/#valid-file-name
///
/// A valid file name is a string that:
/// - Is not empty
/// - Does not contain '/' or '\'
/// - Is not "." or ".."
pub fn isValidFileName(name: []const u8) bool {
    return context_mod.isValidFileName(name);
}

/// Check if a path contains only valid components.
/// Each component must be a valid file name.
pub fn isValidPath(path: []const []const u8) bool {
    for (path) |component| {
        if (!isValidFileName(component)) {
            return false;
        }
    }
    return true;
}

/// Normalize a path by removing empty components and resolving . and ..
/// Returns null if the path would escape the root.
pub fn normalizePath(allocator: std.mem.Allocator, components: []const []const u8) !?[][]const u8 {
    var result = std.ArrayListUnmanaged([]const u8){};
    errdefer {
        for (result.items) |item| {
            allocator.free(item);
        }
        result.deinit(allocator);
    }

    for (components) |component| {
        if (component.len == 0) {
            // Skip empty components
            continue;
        } else if (std.mem.eql(u8, component, ".")) {
            // Current directory - skip
            continue;
        } else if (std.mem.eql(u8, component, "..")) {
            // Parent directory
            if (result.items.len == 0) {
                // Would escape root - clean up allocated capacity and return null
                result.deinit(allocator);
                return null;
            }
            const popped = result.pop().?;
            allocator.free(popped);
        } else {
            // Regular component - add it
            const copied = try allocator.dupe(u8, component);
            try result.append(allocator, copied);
        }
    }

    return try result.toOwnedSlice(allocator);
}

/// Free a normalized path returned by normalizePath.
pub fn freeNormalizedPath(allocator: std.mem.Allocator, path: [][]const u8) void {
    for (path) |component| {
        allocator.free(component);
    }
    allocator.free(path);
}

// ============================================================================
// Path Resolution
// ============================================================================

/// Resolve a relative path against a base locator.
/// Returns a new locator pointing to the resolved location.
pub fn resolvePath(
    allocator: std.mem.Allocator,
    base: *const FileSystemLocator,
    relative_components: []const []const u8,
) !FileSystemLocator {
    // Combine base path with relative path
    const total_len = base.path.components.items.len + relative_components.len;
    var combined = try std.ArrayListUnmanaged([]const u8).initCapacity(allocator, total_len);
    defer combined.deinit(allocator);

    // Add base components
    for (base.path.components.items) |component| {
        try combined.append(allocator, component);
    }

    // Add relative components
    for (relative_components) |component| {
        try combined.append(allocator, component);
    }

    // Normalize the combined path
    const normalized = try normalizePath(allocator, combined.items) orelse {
        return FileSystemError.InvalidName;
    };
    defer freeNormalizedPath(allocator, normalized);

    // Create new locator with normalized path
    return FileSystemLocator.directory(allocator, base.root.value, normalized);
}

/// Get the relative path from ancestor to descendant.
/// Returns null if descendant is not under ancestor.
pub fn relativePath(
    allocator: std.mem.Allocator,
    ancestor: *const FileSystemLocator,
    descendant: *const FileSystemLocator,
) !?[][]const u8 {
    // Must be same root
    if (!std.mem.eql(u8, ancestor.root.value, descendant.root.value)) {
        return null;
    }

    const ancestor_path = ancestor.path.components.items;
    const descendant_path = descendant.path.components.items;

    // Descendant must have at least as many components
    if (descendant_path.len < ancestor_path.len) {
        return null;
    }

    // Check that ancestor is a prefix of descendant
    for (ancestor_path, 0..) |component, i| {
        if (!std.mem.eql(u8, component, descendant_path[i])) {
            return null;
        }
    }

    // Return the remaining path components
    const remaining = descendant_path[ancestor_path.len..];
    var result = try allocator.alloc([]const u8, remaining.len);
    errdefer allocator.free(result);

    for (remaining, 0..) |component, i| {
        result[i] = try allocator.dupe(u8, component);
    }

    return result;
}

// ============================================================================
// Entry Location
// ============================================================================

/// Locate an entry from a directory given a path.
/// Returns the entry if found, null otherwise.
/// Note: For empty path, returns null since we can't return the root
/// as an Entry* (it's not stored in an Entry union).
pub fn locateEntry(
    root: *DirectoryEntry,
    path: []const []const u8,
) ?*Entry {
    if (path.len == 0) {
        return null;
    }

    // First component must be resolved from the root directory
    var current = root.getChild(path[0]) orelse return null;

    // Remaining components traverse the tree
    for (path[1..]) |component| {
        switch (current.*) {
            .directory => |*dir| {
                current = dir.getChild(component) orelse return null;
            },
            .file => return null, // Can't traverse into a file
        }
    }

    return current;
}

/// Locate a file entry from a directory given a path.
/// Returns the file entry if found and is a file, null otherwise.
pub fn locateFile(
    root: *DirectoryEntry,
    path: []const []const u8,
) ?*FileEntry {
    if (path.len == 0) {
        return null; // Root is a directory, not a file
    }
    const entry = locateEntry(root, path) orelse return null;
    return switch (entry.*) {
        .file => |*file| file,
        .directory => null,
    };
}

/// Locate a directory entry from a root given a path.
/// Returns the directory entry if found and is a directory, null otherwise.
pub fn locateDirectory(
    root: *DirectoryEntry,
    path: []const []const u8,
) ?*DirectoryEntry {
    if (path.len == 0) {
        return root; // Empty path means the root itself
    }
    const entry = locateEntry(root, path) orelse return null;
    return switch (entry.*) {
        .directory => |*dir| dir,
        .file => null,
    };
}

/// Get the parent directory of an entry given its path.
/// Returns null if at root.
pub fn getParentPath(
    allocator: std.mem.Allocator,
    path: []const []const u8,
) !?[][]const u8 {
    if (path.len == 0) {
        return null;
    }

    const parent_len = path.len - 1;
    var parent_path = try allocator.alloc([]const u8, parent_len);
    errdefer allocator.free(parent_path);

    for (path[0..parent_len], 0..) |component, i| {
        parent_path[i] = try allocator.dupe(u8, component);
    }

    return parent_path;
}

// ============================================================================
// Entry Creation
// ============================================================================

/// Create a file at the given path, creating intermediate directories if needed.
/// Returns the created file entry.
pub fn createFileAtPath(
    root: *DirectoryEntry,
    path: []const []const u8,
    create_intermediates: bool,
) !*FileEntry {
    if (path.len == 0) {
        return FileSystemError.InvalidName;
    }

    const parent_path = path[0 .. path.len - 1];
    const file_name = path[path.len - 1];

    // Validate file name
    if (!isValidFileName(file_name)) {
        return FileSystemError.InvalidName;
    }

    // Get or create parent directory
    var parent = root;
    for (parent_path) |component| {
        if (!isValidFileName(component)) {
            return FileSystemError.InvalidName;
        }

        if (parent.getChild(component)) |child| {
            switch (child.*) {
                .directory => |*dir| {
                    parent = dir;
                },
                .file => return FileSystemError.TypeMismatch,
            }
        } else if (create_intermediates) {
            parent = try parent.addDirectory(component);
        } else {
            return FileSystemError.NotFound;
        }
    }

    // Create the file
    return parent.addFile(file_name);
}

/// Create a directory at the given path, creating intermediate directories if needed.
/// Returns the created directory entry.
pub fn createDirectoryAtPath(
    root: *DirectoryEntry,
    path: []const []const u8,
    create_intermediates: bool,
) !*DirectoryEntry {
    if (path.len == 0) {
        return root;
    }

    var current = root;
    for (path, 0..) |component, i| {
        if (!isValidFileName(component)) {
            return FileSystemError.InvalidName;
        }

        if (current.getChild(component)) |child| {
            switch (child.*) {
                .directory => |*dir| {
                    current = dir;
                },
                .file => return FileSystemError.TypeMismatch,
            }
        } else if (create_intermediates or i == path.len - 1) {
            current = try current.addDirectory(component);
        } else {
            return FileSystemError.NotFound;
        }
    }

    return current;
}

// ============================================================================
// Entry Removal
// ============================================================================

/// Remove an entry at the given path.
/// If recursive is true, removes directories with contents.
pub fn removeAtPath(
    root: *DirectoryEntry,
    path: []const []const u8,
    recursive: bool,
) !void {
    if (path.len == 0) {
        return FileSystemError.InvalidModification;
    }

    const parent_path = path[0 .. path.len - 1];
    const entry_name = path[path.len - 1];

    // Find parent directory - if path has one component, parent is root
    const parent = if (parent_path.len == 0)
        root
    else
        locateDirectory(root, parent_path) orelse {
            return FileSystemError.NotFound;
        };

    // Remove the entry
    try parent.removeChild(entry_name, recursive);
}

// ============================================================================
// Utility Functions
// ============================================================================

/// Join path components with the platform separator.
pub fn joinPath(allocator: std.mem.Allocator, components: []const []const u8) ![]u8 {
    if (components.len == 0) {
        return try allocator.dupe(u8, "");
    }

    // Calculate total length
    var total_len: usize = 0;
    for (components, 0..) |component, i| {
        total_len += component.len;
        if (i < components.len - 1) {
            total_len += 1; // separator
        }
    }

    // Build result
    var result = try allocator.alloc(u8, total_len);
    var offset: usize = 0;

    for (components, 0..) |component, i| {
        @memcpy(result[offset..][0..component.len], component);
        offset += component.len;
        if (i < components.len - 1) {
            result[offset] = context_mod.path_separator;
            offset += 1;
        }
    }

    return result;
}

/// Split a path string into components.
pub fn splitPath(allocator: std.mem.Allocator, path: []const u8) ![][]const u8 {
    if (path.len == 0) {
        return try allocator.alloc([]const u8, 0);
    }

    // Count components
    var count: usize = 1;
    for (path) |c| {
        if (c == context_mod.path_separator or c == '/' or c == '\\') {
            count += 1;
        }
    }

    // Split
    var result = try allocator.alloc([]const u8, count);
    var idx: usize = 0;
    var start: usize = 0;

    for (path, 0..) |c, i| {
        if (c == context_mod.path_separator or c == '/' or c == '\\') {
            result[idx] = try allocator.dupe(u8, path[start..i]);
            idx += 1;
            start = i + 1;
        }
    }
    // Last component
    result[idx] = try allocator.dupe(u8, path[start..]);

    return result;
}

/// Free a split path returned by splitPath.
pub fn freeSplitPath(allocator: std.mem.Allocator, components: [][]const u8) void {
    for (components) |component| {
        allocator.free(component);
    }
    allocator.free(components);
}

/// Get the base name (last component) of a path.
pub fn baseName(path: []const []const u8) ?[]const u8 {
    if (path.len == 0) {
        return null;
    }
    return path[path.len - 1];
}

/// Get the directory name (all but last component) of a path.
pub fn dirName(path: []const []const u8) []const []const u8 {
    if (path.len == 0) {
        return path;
    }
    return path[0 .. path.len - 1];
}

// ============================================================================
// Tests
// ============================================================================

test "isValidFileName - valid names" {
    try std.testing.expect(isValidFileName("file.txt"));
    try std.testing.expect(isValidFileName("my-file"));
    try std.testing.expect(isValidFileName("My File"));
    try std.testing.expect(isValidFileName("123"));
    try std.testing.expect(isValidFileName(".hidden"));
}

test "isValidFileName - invalid names" {
    try std.testing.expect(!isValidFileName(""));
    try std.testing.expect(!isValidFileName("."));
    try std.testing.expect(!isValidFileName(".."));
    try std.testing.expect(!isValidFileName("path/to"));
    // Backslash only invalid on Windows
    if (@import("builtin").os.tag == .windows) {
        try std.testing.expect(!isValidFileName("path\\to"));
    }
}

test "normalizePath - simple path" {
    const allocator = std.testing.allocator;

    const components = [_][]const u8{ "a", "b", "c" };
    const normalized = try normalizePath(allocator, &components) orelse {
        return error.UnexpectedNull;
    };
    defer freeNormalizedPath(allocator, normalized);

    try std.testing.expectEqual(@as(usize, 3), normalized.len);
    try std.testing.expectEqualStrings("a", normalized[0]);
    try std.testing.expectEqualStrings("b", normalized[1]);
    try std.testing.expectEqualStrings("c", normalized[2]);
}

test "normalizePath - with dots" {
    const allocator = std.testing.allocator;

    const components = [_][]const u8{ "a", ".", "b", "..", "c" };
    const normalized = try normalizePath(allocator, &components) orelse {
        return error.UnexpectedNull;
    };
    defer freeNormalizedPath(allocator, normalized);

    try std.testing.expectEqual(@as(usize, 2), normalized.len);
    try std.testing.expectEqualStrings("a", normalized[0]);
    try std.testing.expectEqualStrings("c", normalized[1]);
}

test "normalizePath - escape root returns null" {
    const allocator = std.testing.allocator;

    const components = [_][]const u8{ "a", "..", ".." };
    const result = try normalizePath(allocator, &components);

    try std.testing.expect(result == null);
}

test "normalizePath - empty components" {
    const allocator = std.testing.allocator;

    const components = [_][]const u8{ "a", "", "b", "" };
    const normalized = try normalizePath(allocator, &components) orelse {
        return error.UnexpectedNull;
    };
    defer freeNormalizedPath(allocator, normalized);

    try std.testing.expectEqual(@as(usize, 2), normalized.len);
    try std.testing.expectEqualStrings("a", normalized[0]);
    try std.testing.expectEqualStrings("b", normalized[1]);
}

test "locateEntry - find file" {
    const allocator = std.testing.allocator;

    var root = try DirectoryEntry.init(allocator, "root");
    defer root.deinit();

    const sub = try root.addDirectory("sub");
    _ = try sub.addFile("file.txt");

    const path = [_][]const u8{ "sub", "file.txt" };
    const entry = locateEntry(&root, &path);

    try std.testing.expect(entry != null);
    try std.testing.expect(entry.?.isFile());
}

test "locateEntry - find directory" {
    const allocator = std.testing.allocator;

    var root = try DirectoryEntry.init(allocator, "root");
    defer root.deinit();

    _ = try root.addDirectory("sub");

    const path = [_][]const u8{"sub"};
    const entry = locateEntry(&root, &path);

    try std.testing.expect(entry != null);
    try std.testing.expect(entry.?.isDirectory());
}

test "locateEntry - not found" {
    const allocator = std.testing.allocator;

    var root = try DirectoryEntry.init(allocator, "root");
    defer root.deinit();

    const path = [_][]const u8{ "nonexistent", "file.txt" };
    const entry = locateEntry(&root, &path);

    try std.testing.expect(entry == null);
}

test "createFileAtPath - simple" {
    const allocator = std.testing.allocator;

    var root = try DirectoryEntry.init(allocator, "root");
    defer root.deinit();

    const path = [_][]const u8{"file.txt"};
    const file = try createFileAtPath(&root, &path, false);

    try std.testing.expectEqualStrings("file.txt", file.name());
}

test "createFileAtPath - with intermediate directories" {
    const allocator = std.testing.allocator;

    var root = try DirectoryEntry.init(allocator, "root");
    defer root.deinit();

    const path = [_][]const u8{ "a", "b", "file.txt" };
    const file = try createFileAtPath(&root, &path, true);

    try std.testing.expectEqualStrings("file.txt", file.name());

    // Verify intermediate directories were created
    const dir_path = [_][]const u8{ "a", "b" };
    const dir = locateDirectory(&root, &dir_path);
    try std.testing.expect(dir != null);
}

test "createDirectoryAtPath - simple" {
    const allocator = std.testing.allocator;

    var root = try DirectoryEntry.init(allocator, "root");
    defer root.deinit();

    const path = [_][]const u8{"subdir"};
    const dir = try createDirectoryAtPath(&root, &path, false);

    try std.testing.expectEqualStrings("subdir", dir.name());
}

test "removeAtPath - remove file" {
    const allocator = std.testing.allocator;

    var root = try DirectoryEntry.init(allocator, "root");
    defer root.deinit();

    _ = try root.addFile("file.txt");

    const path = [_][]const u8{"file.txt"};
    try removeAtPath(&root, &path, false);

    try std.testing.expect(root.getChild("file.txt") == null);
}

test "joinPath - simple" {
    const allocator = std.testing.allocator;

    const components = [_][]const u8{ "a", "b", "c" };
    const joined = try joinPath(allocator, &components);
    defer allocator.free(joined);

    try std.testing.expectEqualStrings("a/b/c", joined);
}

test "splitPath - simple" {
    const allocator = std.testing.allocator;

    const components = try splitPath(allocator, "a/b/c");
    defer freeSplitPath(allocator, components);

    try std.testing.expectEqual(@as(usize, 3), components.len);
    try std.testing.expectEqualStrings("a", components[0]);
    try std.testing.expectEqualStrings("b", components[1]);
    try std.testing.expectEqualStrings("c", components[2]);
}

test "baseName and dirName" {
    const path = [_][]const u8{ "a", "b", "c.txt" };

    const base = baseName(&path);
    try std.testing.expect(base != null);
    try std.testing.expectEqualStrings("c.txt", base.?);

    const dir = dirName(&path);
    try std.testing.expectEqual(@as(usize, 2), dir.len);
    try std.testing.expectEqualStrings("a", dir[0]);
    try std.testing.expectEqualStrings("b", dir[1]);
}
