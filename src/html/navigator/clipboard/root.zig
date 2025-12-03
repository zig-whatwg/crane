//! Clipboard API
//!
//! Spec: Clipboard API and events
//! https://w3c.github.io/clipboard-apis/
//!
//! This module implements the Clipboard interface which provides
//! access to system clipboard through a pluggable backend.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Presentation style for clipboard items
pub const PresentationStyle = enum {
    unspecified,
    @"inline",
    attachment,
};

/// Clipboard item
pub const ClipboardItem = struct {
    allocator: Allocator,
    presentation_style: PresentationStyle,
    types: []const []const u8,
    data: std.StringHashMap([]const u8),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .presentation_style = .unspecified,
            .types = &[_][]const u8{},
            .data = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.data.deinit();
    }

    pub fn getType(self: *Self, mime_type: []const u8) ?[]const u8 {
        return self.data.get(mime_type);
    }
};

/// Error types for clipboard operations
pub const ClipboardError = error{
    /// User denied clipboard access
    NotAllowedError,
    /// Clipboard data not available
    DataError,
    /// Out of memory
    OutOfMemory,
};

/// Backend interface for clipboard
pub const ClipboardBackend = struct {
    context: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        read: *const fn (context: *anyopaque, allocator: Allocator) ClipboardError![]ClipboardItem,
        readText: *const fn (context: *anyopaque, allocator: Allocator) ClipboardError![]const u8,
        write: *const fn (context: *anyopaque, items: []const ClipboardItem) ClipboardError!void,
        writeText: *const fn (context: *anyopaque, text: []const u8) ClipboardError!void,
    };

    pub fn read(self: *const ClipboardBackend, allocator: Allocator) ClipboardError![]ClipboardItem {
        return self.vtable.read(self.context, allocator);
    }

    pub fn readText(self: *const ClipboardBackend, allocator: Allocator) ClipboardError![]const u8 {
        return self.vtable.readText(self.context, allocator);
    }

    pub fn write(self: *const ClipboardBackend, items: []const ClipboardItem) ClipboardError!void {
        return self.vtable.write(self.context, items);
    }

    pub fn writeText(self: *const ClipboardBackend, text: []const u8) ClipboardError!void {
        return self.vtable.writeText(self.context, text);
    }
};

/// Clipboard interface implementation
/// Spec: Clipboard interface
/// [SecureContext] required
pub const Clipboard = struct {
    allocator: Allocator,
    backend: ?*ClipboardBackend,

    const Self = @This();

    pub fn init(allocator: Allocator, backend: ?*ClipboardBackend) Self {
        return .{
            .allocator = allocator,
            .backend = backend,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Read clipboard contents
    /// Spec: read()
    pub fn read(self: *Self) ClipboardError![]ClipboardItem {
        if (self.backend) |backend| {
            return backend.read(self.allocator);
        }
        return ClipboardError.NotAllowedError;
    }

    /// Read clipboard as text
    /// Spec: readText()
    pub fn readText(self: *Self) ClipboardError![]const u8 {
        if (self.backend) |backend| {
            return backend.readText(self.allocator);
        }
        return ClipboardError.NotAllowedError;
    }

    /// Write to clipboard
    /// Spec: write(data)
    pub fn write(self: *Self, items: []const ClipboardItem) ClipboardError!void {
        if (self.backend) |backend| {
            return backend.write(items);
        }
        return ClipboardError.NotAllowedError;
    }

    /// Write text to clipboard
    /// Spec: writeText(text)
    pub fn writeText(self: *Self, text: []const u8) ClipboardError!void {
        if (self.backend) |backend| {
            return backend.writeText(text);
        }
        return ClipboardError.NotAllowedError;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Clipboard - init without backend" {
    const allocator = std.testing.allocator;

    var clipboard = Clipboard.init(allocator, null);
    defer clipboard.deinit();

    // Should return permission denied
    const result = clipboard.readText();
    try std.testing.expectError(ClipboardError.NotAllowedError, result);

    const write_result = clipboard.writeText("test");
    try std.testing.expectError(ClipboardError.NotAllowedError, write_result);
}

test "ClipboardItem - init and deinit" {
    const allocator = std.testing.allocator;

    var item = ClipboardItem.init(allocator);
    defer item.deinit();

    try std.testing.expectEqual(PresentationStyle.unspecified, item.presentation_style);
}
