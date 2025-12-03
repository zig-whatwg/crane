//! NavigatorPlugins Mixin
//!
//! HTML Standard § 8.8.1.7 - NavigatorPlugins
//! https://html.spec.whatwg.org/#navigatorplugins
//!
//! This mixin provides plugin information (legacy API, mostly deprecated).
//! Modern browsers return minimal/fake data for compatibility.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Plugin information
/// Spec: HTML Standard § 8.8.1.7.4 Plugin
pub const Plugin = struct {
    name: []const u8,
    description: []const u8,
    filename: []const u8,
    mime_types: []const MimeType,

    /// Get number of supported MIME types
    pub fn getLength(self: *const Plugin) usize {
        return self.mime_types.len;
    }

    /// Get MIME type by index
    pub fn item(self: *const Plugin, index: usize) ?MimeType {
        if (index < self.mime_types.len) {
            return self.mime_types[index];
        }
        return null;
    }

    /// Get MIME type by name
    pub fn namedItem(self: *const Plugin, name: []const u8) ?MimeType {
        for (self.mime_types) |mime| {
            if (std.mem.eql(u8, mime.type, name)) {
                return mime;
            }
        }
        return null;
    }
};

/// MIME type information
/// Spec: HTML Standard § 8.8.1.7.5 MimeType
pub const MimeType = struct {
    type: []const u8,
    description: []const u8,
    suffixes: []const u8,
    enabled_plugin: *const Plugin,
};

/// PluginArray interface
/// Spec: HTML Standard § 8.8.1.7.2 PluginArray
pub const PluginArray = struct {
    plugins: []const Plugin,

    const Self = @This();

    /// Refresh the plugin list (no-op in modern browsers)
    pub fn refresh(_: *Self) void {
        // No-op - plugins are no longer dynamically loaded
    }

    /// Get number of plugins
    pub fn getLength(self: *const Self) usize {
        return self.plugins.len;
    }

    /// Get plugin by index
    pub fn item(self: *const Self, index: usize) ?Plugin {
        if (index < self.plugins.len) {
            return self.plugins[index];
        }
        return null;
    }

    /// Get plugin by name
    pub fn namedItem(self: *const Self, name: []const u8) ?Plugin {
        for (self.plugins) |plugin| {
            if (std.mem.eql(u8, plugin.name, name)) {
                return plugin;
            }
        }
        return null;
    }
};

/// MimeTypeArray interface
/// Spec: HTML Standard § 8.8.1.7.3 MimeTypeArray
pub const MimeTypeArray = struct {
    mime_types: []const MimeType,

    const Self = @This();

    /// Get number of MIME types
    pub fn getLength(self: *const Self) usize {
        return self.mime_types.len;
    }

    /// Get MIME type by index
    pub fn item(self: *const Self, index: usize) ?MimeType {
        if (index < self.mime_types.len) {
            return self.mime_types[index];
        }
        return null;
    }

    /// Get MIME type by name
    pub fn namedItem(self: *const Self, name: []const u8) ?MimeType {
        for (self.mime_types) |mime| {
            if (std.mem.eql(u8, mime.type, name)) {
                return mime;
            }
        }
        return null;
    }
};

/// NavigatorPlugins mixin implementation
/// Spec: HTML Standard § 8.8.1.7
///
/// Note: This is only exposed in Window context, not workers.
/// Most plugin-related features are deprecated in modern browsers.
pub const NavigatorPlugins = struct {
    /// Plugin array (empty in modern browsers)
    plugins: PluginArray,

    /// MIME type array (empty in modern browsers)
    mime_types: MimeTypeArray,

    /// Whether PDF viewer is enabled
    pdf_viewer_enabled: bool,

    const Self = @This();

    /// Initialize with default values
    /// Modern browsers typically have no plugins (except PDF viewer)
    pub fn init() Self {
        return .{
            .plugins = .{ .plugins = &[_]Plugin{} },
            .mime_types = .{ .mime_types = &[_]MimeType{} },
            .pdf_viewer_enabled = true, // Most browsers support PDF
        };
    }

    // ========================================================================
    // NavigatorPlugins Properties
    // ========================================================================

    /// Get the plugins array.
    /// Spec: Returns a PluginArray object.
    pub fn getPlugins(self: *const Self) *const PluginArray {
        return &self.plugins;
    }

    /// Get the MIME types array.
    /// Spec: Returns a MimeTypeArray object.
    pub fn getMimeTypes(self: *const Self) *const MimeTypeArray {
        return &self.mime_types;
    }

    /// Check if Java is enabled.
    /// Spec: Always returns false in modern browsers.
    pub fn javaEnabled(_: *const Self) bool {
        return false;
    }

    /// Check if PDF viewer is enabled.
    /// Spec: Returns true if inline PDF viewing is supported.
    pub fn isPdfViewerEnabled(self: *const Self) bool {
        return self.pdf_viewer_enabled;
    }

    /// Set PDF viewer enabled status (for testing)
    pub fn setPdfViewerEnabled(self: *Self, enabled: bool) void {
        self.pdf_viewer_enabled = enabled;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "NavigatorPlugins - default state" {
    const plugins = NavigatorPlugins.init();

    // No plugins in modern browsers
    try std.testing.expectEqual(@as(usize, 0), plugins.getPlugins().getLength());
    try std.testing.expectEqual(@as(usize, 0), plugins.getMimeTypes().getLength());

    // Java is never enabled
    try std.testing.expect(!plugins.javaEnabled());

    // PDF viewer is typically enabled
    try std.testing.expect(plugins.isPdfViewerEnabled());
}

test "NavigatorPlugins - PDF viewer toggle" {
    var plugins = NavigatorPlugins.init();

    try std.testing.expect(plugins.isPdfViewerEnabled());

    plugins.setPdfViewerEnabled(false);
    try std.testing.expect(!plugins.isPdfViewerEnabled());
}

test "PluginArray - item and namedItem" {
    const plugin_array = PluginArray{ .plugins = &[_]Plugin{} };

    try std.testing.expect(plugin_array.item(0) == null);
    try std.testing.expect(plugin_array.namedItem("nonexistent") == null);
}

test "MimeTypeArray - item and namedItem" {
    const mime_array = MimeTypeArray{ .mime_types = &[_]MimeType{} };

    try std.testing.expect(mime_array.item(0) == null);
    try std.testing.expect(mime_array.namedItem("nonexistent") == null);
}
