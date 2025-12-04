//! Platform Clipboard Backend Abstraction
//!
//! Spec: https://w3c.github.io/clipboard-apis/
//! Clipboard API and events
//!
//! Provides a pluggable interface for clipboard operations, allowing the editing
//! commands to work with different clipboard implementations (real OS clipboard,
//! mock clipboard for testing, etc.).
//!
//! The clipboard backend is responsible for:
//! - Reading text and HTML from the clipboard
//! - Writing text and HTML to the clipboard
//! - Checking clipboard permissions
//!
//! ## Usage
//!
//! ```zig
//! const clipboard_backend = @import("platform/clipboard_backend.zig");
//!
//! // Create a stub backend for testing (in-memory clipboard)
//! const stub = try StubClipboardBackend.init(allocator);
//! defer stub.deinit();
//!
//! // Get clipboard interface
//! const clipboard = stub.backend();
//!
//! // Use clipboard methods
//! try clipboard.writeText("Hello, world!");
//! const text = try clipboard.readText(allocator);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Clipboard data format
pub const ClipboardFormat = enum {
    text_plain,
    text_html,
    text_rtf,
    image_png,
    image_jpeg,
    image_gif,
    image_bmp,
};

/// Clipboard item containing data in one or more formats
pub const ClipboardItem = struct {
    /// Available formats and their data
    items: []const FormatData,
    allocator: Allocator,

    pub const FormatData = struct {
        format: ClipboardFormat,
        data: []const u8,
    };

    pub fn init(allocator: Allocator, items: []const FormatData) ClipboardItem {
        return .{
            .items = items,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ClipboardItem) void {
        for (self.items) |item| {
            self.allocator.free(item.data);
        }
        self.allocator.free(self.items);
    }

    /// Get data for a specific format, or null if not available
    pub fn getData(self: ClipboardItem, format: ClipboardFormat) ?[]const u8 {
        for (self.items) |item| {
            if (item.format == format) {
                return item.data;
            }
        }
        return null;
    }

    /// Check if a format is available
    pub fn hasFormat(self: ClipboardItem, format: ClipboardFormat) bool {
        return self.getData(format) != null;
    }
};

/// Result of a clipboard operation
pub const ClipboardResult = enum {
    success,
    permission_denied,
    not_available,
    empty,
    error_unknown,
};

/// Abstract clipboard backend interface.
///
/// This uses a vtable pattern to allow different implementations
/// (real OS clipboard, mock clipboard) to be swapped at runtime.
pub const ClipboardBackend = struct {
    /// Implementation pointer.
    ptr: *anyopaque,

    /// Virtual function table.
    vtable: *const VTable,

    pub const VTable = struct {
        // === Text Operations ===

        /// Read plain text from clipboard
        /// Returns null if clipboard is empty or doesn't contain text
        /// Spec: https://w3c.github.io/clipboard-apis/#dom-clipboard-readtext
        readText: *const fn (ptr: *anyopaque, allocator: Allocator) ?[]const u8,

        /// Write plain text to clipboard
        /// Spec: https://w3c.github.io/clipboard-apis/#dom-clipboard-writetext
        writeText: *const fn (ptr: *anyopaque, text: []const u8) ClipboardResult,

        // === HTML Operations ===

        /// Read HTML from clipboard
        /// Returns null if clipboard doesn't contain HTML
        readHtml: *const fn (ptr: *anyopaque, allocator: Allocator) ?[]const u8,

        /// Write HTML to clipboard (also writes plain text fallback)
        writeHtml: *const fn (ptr: *anyopaque, html: []const u8, plain_text: ?[]const u8) ClipboardResult,

        // === Multi-format Operations ===

        /// Read clipboard contents in all available formats
        /// Spec: https://w3c.github.io/clipboard-apis/#dom-clipboard-read
        read: *const fn (ptr: *anyopaque, allocator: Allocator) ?ClipboardItem,

        /// Write multiple formats to clipboard
        /// Spec: https://w3c.github.io/clipboard-apis/#dom-clipboard-write
        write: *const fn (ptr: *anyopaque, items: []const ClipboardItem.FormatData) ClipboardResult,

        // === Permission & State ===

        /// Check if clipboard read is permitted
        /// May depend on user gesture, permissions, etc.
        canRead: *const fn (ptr: *anyopaque) bool,

        /// Check if clipboard write is permitted
        canWrite: *const fn (ptr: *anyopaque) bool,

        /// Check if clipboard has any content
        hasContent: *const fn (ptr: *anyopaque) bool,

        /// Clear clipboard contents
        clear: *const fn (ptr: *anyopaque) ClipboardResult,

        // === Lifecycle ===

        /// Free backend resources
        deinit: *const fn (ptr: *anyopaque) void,
    };

    // === Convenience Methods ===

    /// Read plain text from clipboard
    pub fn readText(self: ClipboardBackend, allocator: Allocator) ?[]const u8 {
        return self.vtable.readText(self.ptr, allocator);
    }

    /// Write plain text to clipboard
    pub fn writeText(self: ClipboardBackend, text: []const u8) ClipboardResult {
        return self.vtable.writeText(self.ptr, text);
    }

    /// Read HTML from clipboard
    pub fn readHtml(self: ClipboardBackend, allocator: Allocator) ?[]const u8 {
        return self.vtable.readHtml(self.ptr, allocator);
    }

    /// Write HTML to clipboard
    pub fn writeHtml(self: ClipboardBackend, html: []const u8, plain_text: ?[]const u8) ClipboardResult {
        return self.vtable.writeHtml(self.ptr, html, plain_text);
    }

    /// Read all clipboard formats
    pub fn read(self: ClipboardBackend, allocator: Allocator) ?ClipboardItem {
        return self.vtable.read(self.ptr, allocator);
    }

    /// Write multiple formats to clipboard
    pub fn write(self: ClipboardBackend, items: []const ClipboardItem.FormatData) ClipboardResult {
        return self.vtable.write(self.ptr, items);
    }

    /// Check if read is permitted
    pub fn canRead(self: ClipboardBackend) bool {
        return self.vtable.canRead(self.ptr);
    }

    /// Check if write is permitted
    pub fn canWrite(self: ClipboardBackend) bool {
        return self.vtable.canWrite(self.ptr);
    }

    /// Check if clipboard has content
    pub fn hasContent(self: ClipboardBackend) bool {
        return self.vtable.hasContent(self.ptr);
    }

    /// Clear clipboard
    pub fn clear(self: ClipboardBackend) ClipboardResult {
        return self.vtable.clear(self.ptr);
    }

    /// Free resources
    pub fn deinit(self: ClipboardBackend) void {
        self.vtable.deinit(self.ptr);
    }
};

/// Stub clipboard backend for testing and headless environments.
///
/// Provides an in-memory clipboard that:
/// - Always permits read/write operations
/// - Stores text and HTML in memory
/// - Useful for testing without OS clipboard access
pub const StubClipboardBackend = struct {
    allocator: Allocator,

    /// Stored plain text content
    text_content: ?[]u8,

    /// Stored HTML content
    html_content: ?[]u8,

    /// Initialize a new stub clipboard backend.
    pub fn init(allocator: Allocator) !*StubClipboardBackend {
        const self = try allocator.create(StubClipboardBackend);
        self.* = StubClipboardBackend{
            .allocator = allocator,
            .text_content = null,
            .html_content = null,
        };
        return self;
    }

    /// Create a ClipboardBackend interface for this stub.
    pub fn backend(self: *StubClipboardBackend) ClipboardBackend {
        return ClipboardBackend{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    /// Free the stub backend and its contents.
    pub fn deinit(self: *StubClipboardBackend) void {
        if (self.text_content) |text| {
            self.allocator.free(text);
        }
        if (self.html_content) |html| {
            self.allocator.free(html);
        }
        self.allocator.destroy(self);
    }

    const vtable = ClipboardBackend.VTable{
        .readText = readTextImpl,
        .writeText = writeTextImpl,
        .readHtml = readHtmlImpl,
        .writeHtml = writeHtmlImpl,
        .read = readImpl,
        .write = writeImpl,
        .canRead = canReadImpl,
        .canWrite = canWriteImpl,
        .hasContent = hasContentImpl,
        .clear = clearImpl,
        .deinit = deinitImpl,
    };

    fn readTextImpl(ptr: *anyopaque, allocator: Allocator) ?[]const u8 {
        const self: *StubClipboardBackend = @ptrCast(@alignCast(ptr));
        if (self.text_content) |text| {
            // Return a copy so caller owns it
            return allocator.dupe(u8, text) catch null;
        }
        return null;
    }

    fn writeTextImpl(ptr: *anyopaque, text: []const u8) ClipboardResult {
        const self: *StubClipboardBackend = @ptrCast(@alignCast(ptr));

        // Free existing content
        if (self.text_content) |old| {
            self.allocator.free(old);
        }

        // Store new content
        self.text_content = self.allocator.dupe(u8, text) catch return .error_unknown;
        return .success;
    }

    fn readHtmlImpl(ptr: *anyopaque, allocator: Allocator) ?[]const u8 {
        const self: *StubClipboardBackend = @ptrCast(@alignCast(ptr));
        if (self.html_content) |html| {
            return allocator.dupe(u8, html) catch null;
        }
        return null;
    }

    fn writeHtmlImpl(ptr: *anyopaque, html: []const u8, plain_text: ?[]const u8) ClipboardResult {
        const self: *StubClipboardBackend = @ptrCast(@alignCast(ptr));

        // Free existing content
        if (self.html_content) |old| {
            self.allocator.free(old);
        }
        if (self.text_content) |old| {
            self.allocator.free(old);
        }

        // Store HTML
        self.html_content = self.allocator.dupe(u8, html) catch return .error_unknown;

        // Store plain text if provided
        if (plain_text) |text| {
            self.text_content = self.allocator.dupe(u8, text) catch return .error_unknown;
        } else {
            self.text_content = null;
        }

        return .success;
    }

    fn readImpl(ptr: *anyopaque, allocator: Allocator) ?ClipboardItem {
        const self: *StubClipboardBackend = @ptrCast(@alignCast(ptr));

        // Count available formats
        var count: usize = 0;
        if (self.text_content != null) count += 1;
        if (self.html_content != null) count += 1;

        if (count == 0) return null;

        // Build format data array
        var items = allocator.alloc(ClipboardItem.FormatData, count) catch return null;
        var idx: usize = 0;

        if (self.text_content) |text| {
            items[idx] = .{
                .format = .text_plain,
                .data = allocator.dupe(u8, text) catch {
                    allocator.free(items);
                    return null;
                },
            };
            idx += 1;
        }

        if (self.html_content) |html| {
            items[idx] = .{
                .format = .text_html,
                .data = allocator.dupe(u8, html) catch {
                    // Clean up already allocated items
                    for (items[0..idx]) |item| {
                        allocator.free(item.data);
                    }
                    allocator.free(items);
                    return null;
                },
            };
            idx += 1;
        }

        return ClipboardItem.init(allocator, items);
    }

    fn writeImpl(ptr: *anyopaque, items: []const ClipboardItem.FormatData) ClipboardResult {
        const self: *StubClipboardBackend = @ptrCast(@alignCast(ptr));

        // Clear existing content
        if (self.text_content) |old| {
            self.allocator.free(old);
            self.text_content = null;
        }
        if (self.html_content) |old| {
            self.allocator.free(old);
            self.html_content = null;
        }

        // Store each format
        for (items) |item| {
            switch (item.format) {
                .text_plain => {
                    self.text_content = self.allocator.dupe(u8, item.data) catch return .error_unknown;
                },
                .text_html => {
                    self.html_content = self.allocator.dupe(u8, item.data) catch return .error_unknown;
                },
                else => {
                    // Stub doesn't support image formats
                },
            }
        }

        return .success;
    }

    fn canReadImpl(_: *anyopaque) bool {
        // Stub always permits reading
        return true;
    }

    fn canWriteImpl(_: *anyopaque) bool {
        // Stub always permits writing
        return true;
    }

    fn hasContentImpl(ptr: *anyopaque) bool {
        const self: *StubClipboardBackend = @ptrCast(@alignCast(ptr));
        return self.text_content != null or self.html_content != null;
    }

    fn clearImpl(ptr: *anyopaque) ClipboardResult {
        const self: *StubClipboardBackend = @ptrCast(@alignCast(ptr));

        if (self.text_content) |text| {
            self.allocator.free(text);
            self.text_content = null;
        }
        if (self.html_content) |html| {
            self.allocator.free(html);
            self.html_content = null;
        }

        return .success;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *StubClipboardBackend = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

/// Permission-denied clipboard backend.
///
/// A clipboard backend that always denies permission.
/// Useful for testing permission error handling.
pub const DeniedClipboardBackend = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) !*DeniedClipboardBackend {
        const self = try allocator.create(DeniedClipboardBackend);
        self.* = DeniedClipboardBackend{
            .allocator = allocator,
        };
        return self;
    }

    pub fn backend(self: *DeniedClipboardBackend) ClipboardBackend {
        return ClipboardBackend{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    const vtable = ClipboardBackend.VTable{
        .readText = readTextImpl,
        .writeText = writeTextImpl,
        .readHtml = readHtmlImpl,
        .writeHtml = writeHtmlImpl,
        .read = readImpl,
        .write = writeImpl,
        .canRead = canReadImpl,
        .canWrite = canWriteImpl,
        .hasContent = hasContentImpl,
        .clear = clearImpl,
        .deinit = deinitImpl,
    };

    fn readTextImpl(_: *anyopaque, _: Allocator) ?[]const u8 {
        return null;
    }

    fn writeTextImpl(_: *anyopaque, _: []const u8) ClipboardResult {
        return .permission_denied;
    }

    fn readHtmlImpl(_: *anyopaque, _: Allocator) ?[]const u8 {
        return null;
    }

    fn writeHtmlImpl(_: *anyopaque, _: []const u8, _: ?[]const u8) ClipboardResult {
        return .permission_denied;
    }

    fn readImpl(_: *anyopaque, _: Allocator) ?ClipboardItem {
        return null;
    }

    fn writeImpl(_: *anyopaque, _: []const ClipboardItem.FormatData) ClipboardResult {
        return .permission_denied;
    }

    fn canReadImpl(_: *anyopaque) bool {
        return false;
    }

    fn canWriteImpl(_: *anyopaque) bool {
        return false;
    }

    fn hasContentImpl(_: *anyopaque) bool {
        return false;
    }

    fn clearImpl(_: *anyopaque) ClipboardResult {
        return .permission_denied;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *DeniedClipboardBackend = @ptrCast(@alignCast(ptr));
        self.allocator.destroy(self);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "StubClipboardBackend - basic text operations" {
    const allocator = std.testing.allocator;

    const stub = try StubClipboardBackend.init(allocator);
    const clipboard = stub.backend();
    defer clipboard.deinit();

    // Initially empty
    try std.testing.expect(!clipboard.hasContent());
    try std.testing.expectEqual(@as(?[]const u8, null), clipboard.readText(allocator));

    // Write text
    try std.testing.expectEqual(ClipboardResult.success, clipboard.writeText("Hello, world!"));
    try std.testing.expect(clipboard.hasContent());

    // Read text back
    const text = clipboard.readText(allocator);
    try std.testing.expect(text != null);
    defer allocator.free(text.?);
    try std.testing.expectEqualStrings("Hello, world!", text.?);
}

test "StubClipboardBackend - HTML operations" {
    const allocator = std.testing.allocator;

    const stub = try StubClipboardBackend.init(allocator);
    const clipboard = stub.backend();
    defer clipboard.deinit();

    // Write HTML with plain text fallback
    const html = "<p>Hello, <strong>world</strong>!</p>";
    const plain = "Hello, world!";
    try std.testing.expectEqual(ClipboardResult.success, clipboard.writeHtml(html, plain));

    // Read HTML
    const read_html = clipboard.readHtml(allocator);
    try std.testing.expect(read_html != null);
    defer allocator.free(read_html.?);
    try std.testing.expectEqualStrings(html, read_html.?);

    // Read plain text fallback
    const read_text = clipboard.readText(allocator);
    try std.testing.expect(read_text != null);
    defer allocator.free(read_text.?);
    try std.testing.expectEqualStrings(plain, read_text.?);
}

test "StubClipboardBackend - clear" {
    const allocator = std.testing.allocator;

    const stub = try StubClipboardBackend.init(allocator);
    const clipboard = stub.backend();
    defer clipboard.deinit();

    // Write some content
    _ = clipboard.writeText("test");
    try std.testing.expect(clipboard.hasContent());

    // Clear
    try std.testing.expectEqual(ClipboardResult.success, clipboard.clear());
    try std.testing.expect(!clipboard.hasContent());
}

test "StubClipboardBackend - permissions always granted" {
    const allocator = std.testing.allocator;

    const stub = try StubClipboardBackend.init(allocator);
    const clipboard = stub.backend();
    defer clipboard.deinit();

    try std.testing.expect(clipboard.canRead());
    try std.testing.expect(clipboard.canWrite());
}

test "DeniedClipboardBackend - permissions denied" {
    const allocator = std.testing.allocator;

    const denied = try DeniedClipboardBackend.init(allocator);
    const clipboard = denied.backend();
    defer clipboard.deinit();

    // Permissions denied
    try std.testing.expect(!clipboard.canRead());
    try std.testing.expect(!clipboard.canWrite());

    // Operations fail
    try std.testing.expectEqual(ClipboardResult.permission_denied, clipboard.writeText("test"));
    try std.testing.expectEqual(@as(?[]const u8, null), clipboard.readText(allocator));
}

test "StubClipboardBackend - multi-format read" {
    const allocator = std.testing.allocator;

    const stub = try StubClipboardBackend.init(allocator);
    const clipboard = stub.backend();
    defer clipboard.deinit();

    // Write HTML with text fallback
    _ = clipboard.writeHtml("<b>test</b>", "test");

    // Read all formats
    var item = clipboard.read(allocator);
    try std.testing.expect(item != null);
    defer item.?.deinit();

    // Should have both formats
    try std.testing.expect(item.?.hasFormat(.text_plain));
    try std.testing.expect(item.?.hasFormat(.text_html));
    try std.testing.expect(!item.?.hasFormat(.image_png));

    // Verify content
    try std.testing.expectEqualStrings("test", item.?.getData(.text_plain).?);
    try std.testing.expectEqualStrings("<b>test</b>", item.?.getData(.text_html).?);
}

test "ClipboardItem - getData" {
    const allocator = std.testing.allocator;

    const items = try allocator.alloc(ClipboardItem.FormatData, 2);
    items[0] = .{ .format = .text_plain, .data = try allocator.dupe(u8, "plain") };
    items[1] = .{ .format = .text_html, .data = try allocator.dupe(u8, "<b>html</b>") };

    var clipboard_item = ClipboardItem.init(allocator, items);
    defer clipboard_item.deinit();

    try std.testing.expectEqualStrings("plain", clipboard_item.getData(.text_plain).?);
    try std.testing.expectEqualStrings("<b>html</b>", clipboard_item.getData(.text_html).?);
    try std.testing.expectEqual(@as(?[]const u8, null), clipboard_item.getData(.image_png));
}
