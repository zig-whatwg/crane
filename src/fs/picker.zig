//! File Picker Provider Trait
//!
//! Spec: https://wicg.github.io/file-system-access/
//!
//! Defines the picker provider trait interface for file picker UI.
//! This is separate from the storage backend to allow different
//! UI implementations (native dialogs, web-based, etc.).

const std = @import("std");
const locator = @import("locator.zig");
const errors = @import("errors.zig");

const FileSystemLocator = locator.FileSystemLocator;
const FileSystemError = errors.FileSystemError;

/// Well-known directory identifiers for picker start locations.
/// https://wicg.github.io/file-system-access/#enumdef-wellknowndirectory
pub const WellKnownDirectory = enum {
    desktop,
    documents,
    downloads,
    music,
    pictures,
    videos,

    pub fn toString(self: WellKnownDirectory) []const u8 {
        return switch (self) {
            .desktop => "desktop",
            .documents => "documents",
            .downloads => "downloads",
            .music => "music",
            .pictures => "pictures",
            .videos => "videos",
        };
    }
};

/// Starting directory for a file picker.
/// Can be either a well-known directory or an existing handle.
pub const StartInDirectory = union(enum) {
    /// A well-known directory
    well_known: WellKnownDirectory,
    /// An existing file system handle (as a locator)
    handle: FileSystemLocator,
};

/// A single file type filter for the picker.
/// https://wicg.github.io/file-system-access/#dictdef-filepickeraccepttype
pub const FilePickerAcceptType = struct {
    /// Human-readable description of the file type
    description: []const u8,
    /// Map of MIME types to extensions
    /// Key: MIME type (e.g., "image/png")
    /// Value: Extensions (e.g., ".png" or [".png", ".PNG"])
    accept: std.StringHashMap([]const []const u8),
    /// Allocator for the accept map
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, description: []const u8) Self {
        return .{
            .description = description,
            .accept = std.StringHashMap([]const []const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn addAccept(self: *Self, mime_type: []const u8, extensions: []const []const u8) !void {
        try self.accept.put(mime_type, extensions);
    }

    pub fn deinit(self: *Self) void {
        self.accept.deinit();
    }
};

/// Base options for file picker dialogs.
/// https://wicg.github.io/file-system-access/#dictdef-filepickeroptions
pub const FilePickerOptions = struct {
    /// Acceptable file types
    types: ?[]const FilePickerAcceptType = null,
    /// Whether to exclude the "All files (*.*)" option
    exclude_accept_all_option: bool = false,
    /// Picker instance ID (for remembering last directory)
    id: ?[]const u8 = null,
    /// Starting directory
    start_in: ?StartInDirectory = null,
};

/// Options for the open file picker.
/// https://wicg.github.io/file-system-access/#dictdef-openfilepickeroptions
pub const OpenFilePickerOptions = struct {
    /// Base file picker options
    base: FilePickerOptions = .{},
    /// Whether to allow multiple file selection
    multiple: bool = false,
};

/// Options for the save file picker.
/// https://wicg.github.io/file-system-access/#dictdef-savefilepickeroptions
pub const SaveFilePickerOptions = struct {
    /// Base file picker options
    base: FilePickerOptions = .{},
    /// Suggested file name
    suggested_name: ?[]const u8 = null,
};

/// Options for the directory picker.
/// https://wicg.github.io/file-system-access/#dictdef-directorypickeroptions
pub const DirectoryPickerOptions = struct {
    /// Picker instance ID (for remembering last directory)
    id: ?[]const u8 = null,
    /// Starting directory
    start_in: ?StartInDirectory = null,
    /// Permission mode to request
    mode: PermissionMode = .read,
};

/// Permission mode for file system access.
/// https://wicg.github.io/file-system-access/#enumdef-filesystempermissionmode
pub const PermissionMode = enum {
    read,
    readwrite,

    pub fn toString(self: PermissionMode) []const u8 {
        return switch (self) {
            .read => "read",
            .readwrite => "readwrite",
        };
    }
};

/// Result of a picker operation.
pub const PickerResult = struct {
    /// Selected file locators (empty if cancelled)
    locators: []FileSystemLocator,
    /// Whether the user cancelled the picker
    cancelled: bool,
    /// Allocator for the locators array
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) PickerResult {
        return .{
            .locators = &[_]FileSystemLocator{},
            .cancelled = false,
            .allocator = allocator,
        };
    }

    pub fn cancelled_result() PickerResult {
        return .{
            .locators = &[_]FileSystemLocator{},
            .cancelled = true,
            .allocator = undefined,
        };
    }

    pub fn deinit(self: *PickerResult) void {
        for (self.locators) |*loc| {
            loc.deinit();
        }
        if (self.locators.len > 0) {
            self.allocator.free(self.locators);
        }
    }
};

/// Picker error type.
pub const PickerError = FileSystemError || error{
    /// User cancelled the picker
    Cancelled,
    /// Picker UI not available
    NotAvailable,
    /// Invalid options provided
    InvalidOptions,
};

/// File Picker Provider Trait
///
/// This trait defines the interface for file picker UI operations.
/// Embedders implement this for their platform:
/// - macOS: NSOpenPanel, NSSavePanel
/// - Linux: GTK file chooser, Qt file dialog
/// - Windows: IFileDialog
/// - Web: Custom HTML/CSS picker
///
/// The picker provider is separate from the storage backend because:
/// 1. UI is platform-specific and may have different implementations
/// 2. The same backend could be used with different picker UIs
/// 3. Some contexts (workers) don't have picker access
pub const PickerProvider = struct {
    /// Opaque pointer to provider-specific context
    context: *anyopaque,

    /// Vtable for picker operations
    vtable: *const VTable,

    const Self = @This();

    pub const VTable = struct {
        /// Show the open file picker dialog.
        /// https://wicg.github.io/file-system-access/#api-showopenfilepicker
        ///
        /// Returns selected file locators, or empty if cancelled.
        showOpenFilePicker: *const fn (
            context: *anyopaque,
            allocator: std.mem.Allocator,
            options: OpenFilePickerOptions,
        ) PickerError!PickerResult,

        /// Show the save file picker dialog.
        /// https://wicg.github.io/file-system-access/#api-showsavefilepicker
        ///
        /// Returns the selected file locator, or empty if cancelled.
        showSaveFilePicker: *const fn (
            context: *anyopaque,
            allocator: std.mem.Allocator,
            options: SaveFilePickerOptions,
        ) PickerError!PickerResult,

        /// Show the directory picker dialog.
        /// https://wicg.github.io/file-system-access/#api-showdirectorypicker
        ///
        /// Returns the selected directory locator, or empty if cancelled.
        showDirectoryPicker: *const fn (
            context: *anyopaque,
            allocator: std.mem.Allocator,
            options: DirectoryPickerOptions,
        ) PickerError!PickerResult,

        /// Check if picker UI is available in the current context.
        ///
        /// Returns false for workers and other contexts without UI access.
        isAvailable: *const fn (context: *anyopaque) bool,

        /// Clean up provider resources.
        deinit: *const fn (context: *anyopaque) void,
    };

    // ========================================================================
    // Public API (delegates to vtable)
    // ========================================================================

    /// Show the open file picker dialog.
    pub fn showOpenFilePicker(
        self: Self,
        allocator: std.mem.Allocator,
        options: OpenFilePickerOptions,
    ) PickerError!PickerResult {
        return self.vtable.showOpenFilePicker(self.context, allocator, options);
    }

    /// Show the save file picker dialog.
    pub fn showSaveFilePicker(
        self: Self,
        allocator: std.mem.Allocator,
        options: SaveFilePickerOptions,
    ) PickerError!PickerResult {
        return self.vtable.showSaveFilePicker(self.context, allocator, options);
    }

    /// Show the directory picker dialog.
    pub fn showDirectoryPicker(
        self: Self,
        allocator: std.mem.Allocator,
        options: DirectoryPickerOptions,
    ) PickerError!PickerResult {
        return self.vtable.showDirectoryPicker(self.context, allocator, options);
    }

    /// Check if picker UI is available in the current context.
    pub fn isAvailable(self: Self) bool {
        return self.vtable.isAvailable(self.context);
    }

    /// Clean up provider resources.
    pub fn deinit(self: Self) void {
        self.vtable.deinit(self.context);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "WellKnownDirectory - toString" {
    try std.testing.expectEqualStrings("desktop", WellKnownDirectory.desktop.toString());
    try std.testing.expectEqualStrings("documents", WellKnownDirectory.documents.toString());
    try std.testing.expectEqualStrings("downloads", WellKnownDirectory.downloads.toString());
    try std.testing.expectEqualStrings("music", WellKnownDirectory.music.toString());
    try std.testing.expectEqualStrings("pictures", WellKnownDirectory.pictures.toString());
    try std.testing.expectEqualStrings("videos", WellKnownDirectory.videos.toString());
}

test "PermissionMode - toString" {
    try std.testing.expectEqualStrings("read", PermissionMode.read.toString());
    try std.testing.expectEqualStrings("readwrite", PermissionMode.readwrite.toString());
}

test "FilePickerOptions - defaults" {
    const options = FilePickerOptions{};
    try std.testing.expect(options.types == null);
    try std.testing.expect(!options.exclude_accept_all_option);
    try std.testing.expect(options.id == null);
    try std.testing.expect(options.start_in == null);
}

test "OpenFilePickerOptions - defaults" {
    const options = OpenFilePickerOptions{};
    try std.testing.expect(!options.multiple);
}

test "SaveFilePickerOptions - defaults" {
    const options = SaveFilePickerOptions{};
    try std.testing.expect(options.suggested_name == null);
}

test "DirectoryPickerOptions - defaults" {
    const options = DirectoryPickerOptions{};
    try std.testing.expect(options.id == null);
    try std.testing.expect(options.start_in == null);
    try std.testing.expectEqual(PermissionMode.read, options.mode);
}

test "PickerResult - cancelled" {
    const result = PickerResult.cancelled_result();
    try std.testing.expect(result.cancelled);
    try std.testing.expectEqual(@as(usize, 0), result.locators.len);
}
