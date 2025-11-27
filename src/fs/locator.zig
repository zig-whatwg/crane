//! File System Locator
//!
//! Spec: https://fs.spec.whatwg.org/#file-system-locator
//!
//! A file system locator represents a potential location of a file system entry.
//! It consists of a path, kind, and root.

const std = @import("std");

/// The kind of file system handle.
/// https://fs.spec.whatwg.org/#enumdef-filesystemhandlekind
pub const FileSystemHandleKind = enum {
    file,
    directory,

    pub fn toString(self: FileSystemHandleKind) []const u8 {
        return switch (self) {
            .file => "file",
            .directory => "directory",
        };
    }
};

/// A file system path is a list of one or more strings.
/// https://fs.spec.whatwg.org/#file-system-path
///
/// This may be a virtual path mapped to a real location, correspond directly
/// to a path on the local file system, or not correspond to any file on disk.
pub const FileSystemPath = struct {
    /// Path components (always at least one)
    components: std.ArrayListUnmanaged([]const u8),
    /// Allocator used for this path
    allocator: std.mem.Allocator,
    /// Whether we own the component strings
    owns_strings: bool,

    const Self = @This();

    /// Create a new empty path (with root component)
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .components = .{},
            .allocator = allocator,
            .owns_strings = true,
        };
    }

    /// Create a path from a single component
    pub fn fromComponent(allocator: std.mem.Allocator, component: []const u8) !Self {
        var path = Self.init(allocator);
        errdefer path.deinit();
        const owned = try allocator.dupe(u8, component);
        try path.components.append(allocator, owned);
        return path;
    }

    /// Create a path from multiple components
    pub fn fromComponents(allocator: std.mem.Allocator, components: []const []const u8) !Self {
        var path = Self.init(allocator);
        errdefer path.deinit();
        for (components) |component| {
            const owned = try allocator.dupe(u8, component);
            try path.components.append(allocator, owned);
        }
        return path;
    }

    /// Create a bucket file system root path (path = [""])
    /// https://fs.spec.whatwg.org/#bucket-file-system
    pub fn bucketRoot(allocator: std.mem.Allocator) !Self {
        return fromComponent(allocator, "");
    }

    /// Clone this path
    pub fn clone(self: *const Self, allocator: std.mem.Allocator) !Self {
        var new_path = Self.init(allocator);
        errdefer new_path.deinit();
        for (self.components.items) |component| {
            const owned = try allocator.dupe(u8, component);
            try new_path.components.append(allocator, owned);
        }
        return new_path;
    }

    /// Append a component to this path
    pub fn append(self: *Self, component: []const u8) !void {
        const owned = try self.allocator.dupe(u8, component);
        try self.components.append(self.allocator, owned);
    }

    /// Clone this path and append a component
    pub fn cloneAndAppend(self: *const Self, allocator: std.mem.Allocator, component: []const u8) !Self {
        var new_path = try self.clone(allocator);
        errdefer new_path.deinit();
        try new_path.append(component);
        return new_path;
    }

    /// Get the last component (the entry name)
    pub fn lastName(self: *const Self) ?[]const u8 {
        if (self.components.items.len == 0) return null;
        return self.components.items[self.components.items.len - 1];
    }

    /// Get the number of components
    pub fn len(self: *const Self) usize {
        return self.components.items.len;
    }

    /// Check if this path is the same as another path.
    /// https://fs.spec.whatwg.org/#the-same-path-as
    pub fn isSamePath(self: *const Self, other: *const Self) bool {
        if (self.components.items.len != other.components.items.len) {
            return false;
        }
        for (self.components.items, other.components.items) |a, b| {
            if (!std.mem.eql(u8, a, b)) {
                return false;
            }
        }
        return true;
    }

    /// Check if this path starts with another path
    pub fn startsWith(self: *const Self, prefix: *const Self) bool {
        if (prefix.components.items.len > self.components.items.len) {
            return false;
        }
        for (prefix.components.items, 0..) |component, i| {
            if (!std.mem.eql(u8, component, self.components.items[i])) {
                return false;
            }
        }
        return true;
    }

    /// Get the relative path from a prefix
    pub fn relativeTo(self: *const Self, allocator: std.mem.Allocator, prefix: *const Self) !?Self {
        if (!self.startsWith(prefix)) {
            return null;
        }
        var relative = Self.init(allocator);
        errdefer relative.deinit();
        for (self.components.items[prefix.components.items.len..]) |component| {
            const owned = try allocator.dupe(u8, component);
            try relative.components.append(allocator, owned);
        }
        return relative;
    }

    /// Free this path's resources
    pub fn deinit(self: *Self) void {
        if (self.owns_strings) {
            for (self.components.items) |component| {
                self.allocator.free(component);
            }
        }
        self.components.deinit(self.allocator);
    }
};

/// A file system root is an opaque string whose value is implementation-defined.
/// https://fs.spec.whatwg.org/#file-system-root
///
/// For a bucket file system, the root might include information such as
/// the storage bucket and disk drive.
pub const FileSystemRoot = struct {
    /// The opaque root identifier
    value: []const u8,
    /// Allocator used for this root
    allocator: std.mem.Allocator,
    /// Whether we own the value string
    owns_string: bool,

    const Self = @This();

    /// Create a new root with the given value
    pub fn init(allocator: std.mem.Allocator, value: []const u8) !Self {
        const owned = try allocator.dupe(u8, value);
        return .{
            .value = owned,
            .allocator = allocator,
            .owns_string = true,
        };
    }

    /// Create a root without copying (borrowed reference)
    pub fn initBorrowed(value: []const u8) Self {
        return .{
            .value = value,
            .allocator = undefined,
            .owns_string = false,
        };
    }

    /// Clone this root
    pub fn clone(self: *const Self, allocator: std.mem.Allocator) !Self {
        return Self.init(allocator, self.value);
    }

    /// Check if two roots are equal
    pub fn equals(self: *const Self, other: *const Self) bool {
        return std.mem.eql(u8, self.value, other.value);
    }

    /// Free this root's resources
    pub fn deinit(self: *Self) void {
        if (self.owns_string) {
            self.allocator.free(self.value);
        }
    }
};

/// A file system locator represents a potential location of a file system entry.
/// https://fs.spec.whatwg.org/#file-system-locator
///
/// A file system locator is either a file locator or a directory locator.
pub const FileSystemLocator = struct {
    /// The kind (file or directory)
    kind: FileSystemHandleKind,
    /// The path to the entry
    path: FileSystemPath,
    /// The root of the file system
    root: FileSystemRoot,
    /// Allocator for this locator
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Create a new file locator
    pub fn file(allocator: std.mem.Allocator, root: []const u8, path_components: []const []const u8) !Self {
        var path = try FileSystemPath.fromComponents(allocator, path_components);
        errdefer path.deinit();
        var root_obj = try FileSystemRoot.init(allocator, root);
        errdefer root_obj.deinit();
        return .{
            .kind = .file,
            .path = path,
            .root = root_obj,
            .allocator = allocator,
        };
    }

    /// Create a new directory locator
    pub fn directory(allocator: std.mem.Allocator, root: []const u8, path_components: []const []const u8) !Self {
        var path = try FileSystemPath.fromComponents(allocator, path_components);
        errdefer path.deinit();
        var root_obj = try FileSystemRoot.init(allocator, root);
        errdefer root_obj.deinit();
        return .{
            .kind = .directory,
            .path = path,
            .root = root_obj,
            .allocator = allocator,
        };
    }

    /// Create a bucket file system root directory locator
    /// https://fs.spec.whatwg.org/#bucket-file-system
    pub fn bucketRoot(allocator: std.mem.Allocator, root_id: []const u8) !Self {
        var path = try FileSystemPath.bucketRoot(allocator);
        errdefer path.deinit();
        var root_obj = try FileSystemRoot.init(allocator, root_id);
        errdefer root_obj.deinit();
        return .{
            .kind = .directory,
            .path = path,
            .root = root_obj,
            .allocator = allocator,
        };
    }

    /// Clone this locator
    pub fn clone(self: *const Self, allocator: std.mem.Allocator) !Self {
        var path = try self.path.clone(allocator);
        errdefer path.deinit();
        var root_obj = try self.root.clone(allocator);
        errdefer root_obj.deinit();
        return .{
            .kind = self.kind,
            .path = path,
            .root = root_obj,
            .allocator = allocator,
        };
    }

    /// Create a child file locator
    /// https://fs.spec.whatwg.org/#create-a-child-filesystemfilehandle
    pub fn createChildFile(self: *const Self, allocator: std.mem.Allocator, child_name: []const u8) !Self {
        var path = try self.path.cloneAndAppend(allocator, child_name);
        errdefer path.deinit();
        var root_obj = try self.root.clone(allocator);
        errdefer root_obj.deinit();
        return .{
            .kind = .file,
            .path = path,
            .root = root_obj,
            .allocator = allocator,
        };
    }

    /// Create a child directory locator
    /// https://fs.spec.whatwg.org/#create-a-child-filesystemdirectoryhandle
    pub fn createChildDirectory(self: *const Self, allocator: std.mem.Allocator, child_name: []const u8) !Self {
        var path = try self.path.cloneAndAppend(allocator, child_name);
        errdefer path.deinit();
        var root_obj = try self.root.clone(allocator);
        errdefer root_obj.deinit();
        return .{
            .kind = .directory,
            .path = path,
            .root = root_obj,
            .allocator = allocator,
        };
    }

    /// Get the entry name (last path component)
    pub fn name(self: *const Self) ?[]const u8 {
        return self.path.lastName();
    }

    /// Check if this handle is in a bucket file system.
    /// https://fs.spec.whatwg.org/#is-in-a-bucket-file-system
    ///
    /// A FileSystemHandle is in a bucket file system if the first item
    /// of its locator's path is the empty string.
    pub fn isInBucketFileSystem(self: *const Self) bool {
        if (self.path.components.items.len == 0) return false;
        return self.path.components.items[0].len == 0;
    }

    /// Check if this locator is the same as another locator.
    /// https://fs.spec.whatwg.org/#the-same-locator-as
    ///
    /// A file system locator a is the same locator as b if:
    /// - a's kind is b's kind
    /// - a's root is b's root
    /// - a's path is the same path as b's path
    pub fn isSameLocator(self: *const Self, other: *const Self) bool {
        if (self.kind != other.kind) return false;
        if (!self.root.equals(&other.root)) return false;
        return self.path.isSamePath(&other.path);
    }

    /// Free this locator's resources
    pub fn deinit(self: *Self) void {
        self.path.deinit();
        self.root.deinit();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "FileSystemHandleKind - toString" {
    try std.testing.expectEqualStrings("file", FileSystemHandleKind.file.toString());
    try std.testing.expectEqualStrings("directory", FileSystemHandleKind.directory.toString());
}

test "FileSystemPath - fromComponent" {
    const allocator = std.testing.allocator;
    var path = try FileSystemPath.fromComponent(allocator, "example.txt");
    defer path.deinit();

    try std.testing.expectEqual(@as(usize, 1), path.len());
    try std.testing.expectEqualStrings("example.txt", path.lastName().?);
}

test "FileSystemPath - fromComponents" {
    const allocator = std.testing.allocator;
    const components = [_][]const u8{ "data", "drafts", "example.txt" };
    var path = try FileSystemPath.fromComponents(allocator, &components);
    defer path.deinit();

    try std.testing.expectEqual(@as(usize, 3), path.len());
    try std.testing.expectEqualStrings("example.txt", path.lastName().?);
}

test "FileSystemPath - bucketRoot" {
    const allocator = std.testing.allocator;
    var path = try FileSystemPath.bucketRoot(allocator);
    defer path.deinit();

    try std.testing.expectEqual(@as(usize, 1), path.len());
    try std.testing.expectEqualStrings("", path.lastName().?);
}

test "FileSystemPath - clone and append" {
    const allocator = std.testing.allocator;
    const components = [_][]const u8{ "data", "drafts" };
    var path = try FileSystemPath.fromComponents(allocator, &components);
    defer path.deinit();

    var extended = try path.cloneAndAppend(allocator, "example.txt");
    defer extended.deinit();

    try std.testing.expectEqual(@as(usize, 3), extended.len());
    try std.testing.expectEqualStrings("example.txt", extended.lastName().?);
}

test "FileSystemPath - isSamePath" {
    const allocator = std.testing.allocator;
    const components1 = [_][]const u8{ "data", "example.txt" };
    const components2 = [_][]const u8{ "data", "example.txt" };
    const components3 = [_][]const u8{ "data", "other.txt" };

    var path1 = try FileSystemPath.fromComponents(allocator, &components1);
    defer path1.deinit();
    var path2 = try FileSystemPath.fromComponents(allocator, &components2);
    defer path2.deinit();
    var path3 = try FileSystemPath.fromComponents(allocator, &components3);
    defer path3.deinit();

    try std.testing.expect(path1.isSamePath(&path2));
    try std.testing.expect(!path1.isSamePath(&path3));
}

test "FileSystemPath - startsWith and relativeTo" {
    const allocator = std.testing.allocator;
    const components1 = [_][]const u8{ "data", "drafts", "example.txt" };
    const components2 = [_][]const u8{ "data", "drafts" };

    var path1 = try FileSystemPath.fromComponents(allocator, &components1);
    defer path1.deinit();
    var path2 = try FileSystemPath.fromComponents(allocator, &components2);
    defer path2.deinit();

    try std.testing.expect(path1.startsWith(&path2));
    try std.testing.expect(!path2.startsWith(&path1));

    var relative = (try path1.relativeTo(allocator, &path2)).?;
    defer relative.deinit();

    try std.testing.expectEqual(@as(usize, 1), relative.len());
    try std.testing.expectEqualStrings("example.txt", relative.lastName().?);
}

test "FileSystemRoot - equals" {
    const allocator = std.testing.allocator;
    var root1 = try FileSystemRoot.init(allocator, "bucket:origin1");
    defer root1.deinit();
    var root2 = try FileSystemRoot.init(allocator, "bucket:origin1");
    defer root2.deinit();
    var root3 = try FileSystemRoot.init(allocator, "bucket:origin2");
    defer root3.deinit();

    try std.testing.expect(root1.equals(&root2));
    try std.testing.expect(!root1.equals(&root3));
}

test "FileSystemLocator - file" {
    const allocator = std.testing.allocator;
    const components = [_][]const u8{ "data", "example.txt" };
    var locator = try FileSystemLocator.file(allocator, "bucket:test", &components);
    defer locator.deinit();

    try std.testing.expectEqual(FileSystemHandleKind.file, locator.kind);
    try std.testing.expectEqualStrings("example.txt", locator.name().?);
    try std.testing.expect(!locator.isInBucketFileSystem());
}

test "FileSystemLocator - bucketRoot" {
    const allocator = std.testing.allocator;
    var locator = try FileSystemLocator.bucketRoot(allocator, "bucket:origin");
    defer locator.deinit();

    try std.testing.expectEqual(FileSystemHandleKind.directory, locator.kind);
    try std.testing.expectEqualStrings("", locator.name().?);
    try std.testing.expect(locator.isInBucketFileSystem());
}

test "FileSystemLocator - createChildFile" {
    const allocator = std.testing.allocator;
    var parent = try FileSystemLocator.bucketRoot(allocator, "bucket:origin");
    defer parent.deinit();

    var child = try parent.createChildFile(allocator, "document.txt");
    defer child.deinit();

    try std.testing.expectEqual(FileSystemHandleKind.file, child.kind);
    try std.testing.expectEqualStrings("document.txt", child.name().?);
    try std.testing.expect(child.isInBucketFileSystem());
}

test "FileSystemLocator - isSameLocator" {
    const allocator = std.testing.allocator;
    const components = [_][]const u8{ "data", "example.txt" };

    var loc1 = try FileSystemLocator.file(allocator, "bucket:test", &components);
    defer loc1.deinit();
    var loc2 = try FileSystemLocator.file(allocator, "bucket:test", &components);
    defer loc2.deinit();
    var loc3 = try FileSystemLocator.directory(allocator, "bucket:test", &components);
    defer loc3.deinit();

    try std.testing.expect(loc1.isSameLocator(&loc2));
    try std.testing.expect(!loc1.isSameLocator(&loc3)); // Different kind
}
