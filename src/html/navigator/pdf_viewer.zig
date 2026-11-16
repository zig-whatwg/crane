//! HTML 8.9.1.6 "PDF viewing support": the user agent's PDF viewer supported
//! boolean and the fixed lists navigator.plugins and navigator.mimeTypes
//! expose for it (whatwg/html#6738, the plugins' removal; #6947, a PDF in a
//! navigable).
//!
//! > Each user agent has a PDF viewer supported boolean, whose value is
//! > implementation-defined (and might vary according to user preferences).
//!
//! Crane's is its compiled-in platform's `pdf_viewer` capability (the user,
//! 2026-11-14: on in the default platforms, as in Chrome, Firefox and Safari;
//! an embedder without a viewer compiles it out, -Dplatform-without=pdf_viewer).
//! Supported, a PDF in a navigable becomes the inline PDF viewer document
//! (HTML 7.5.7) and its drawing is the renderer's; Crane never parses the PDF.
//!
//! Spec: https://html.spec.whatwg.org/multipage/system-state.html#pdf-viewing-support

const std = @import("std");
const platform = @import("platform");

/// The user agent's PDF viewer supported: its platform's capability.
pub fn supported() bool {
    return platform.capabilities.pdf_viewer != .unsupported;
}

/// "The PDF viewer plugin names": the names of a Window's five PDF viewer
/// plugin objects, in order. "PDF Viewer" first, so that a MimeType's
/// enabledPlugin can name a generic plugin; the rest alphabetically.
pub const plugin_names = [_][]const u8{
    "PDF Viewer",
    "Chrome PDF Viewer",
    "Chromium PDF Viewer",
    "Microsoft Edge PDF Viewer",
    "WebKit built-in PDF",
};

/// "The PDF viewer mime types": the types of a Window's two PDF viewer mime
/// type objects, in order.
pub const mime_types = [_][]const u8{
    "application/pdf",
    "text/pdf",
};

/// Plugin's and MimeType's description getters.
pub const description = "Portable Document Format";
/// Plugin's filename getter.
pub const filename = "internal-pdf-viewer";
/// MimeType's suffixes getter.
pub const suffixes = "pdf";

/// A Window's "PDF viewer plugin objects" list, by name: "If the user
/// agent's PDF viewer supported is false, then it is the empty list."
/// Also PluginArray's supported property names.
pub fn pluginNamesWhen(is_supported: bool) []const []const u8 {
    return if (is_supported) &plugin_names else &.{};
}

/// A Window's "PDF viewer mime type objects" list, by type - empty when the
/// viewer is not supported. Also MimeTypeArray's and Plugin's supported
/// property names.
pub fn mimeTypesWhen(is_supported: bool) []const []const u8 {
    return if (is_supported) &mime_types else &.{};
}

/// The index of the PDF viewer plugin named `name` in a list of
/// `pluginNamesWhen(is_supported)` - PluginArray's namedItem() step 1 - or
/// null (step 2).
pub fn pluginIndex(is_supported: bool, name: []const u8) ?usize {
    for (pluginNamesWhen(is_supported), 0..) |candidate, index| {
        if (std.mem.eql(u8, candidate, name)) return index;
    }
    return null;
}

/// The index of the PDF viewer mime type `name` in a list of
/// `mimeTypesWhen(is_supported)` - MimeTypeArray's and Plugin's namedItem()
/// step 1 - or null (step 2).
pub fn mimeTypeIndex(is_supported: bool, name: []const u8) ?usize {
    for (mimeTypesWhen(is_supported), 0..) |candidate, index| {
        if (std.mem.eql(u8, candidate, name)) return index;
    }
    return null;
}

test "supported: five plugins, two mime types, in the spec's order" {
    try std.testing.expectEqual(@as(usize, 5), pluginNamesWhen(true).len);
    try std.testing.expectEqualStrings("PDF Viewer", pluginNamesWhen(true)[0]);
    try std.testing.expectEqualStrings("WebKit built-in PDF", pluginNamesWhen(true)[4]);
    try std.testing.expectEqual(@as(usize, 2), mimeTypesWhen(true).len);
    try std.testing.expectEqualStrings("application/pdf", mimeTypesWhen(true)[0]);
    try std.testing.expectEqualStrings("text/pdf", mimeTypesWhen(true)[1]);
    try std.testing.expectEqual(@as(?usize, 3), pluginIndex(true, "Microsoft Edge PDF Viewer"));
    try std.testing.expectEqual(@as(?usize, 1), mimeTypeIndex(true, "text/pdf"));
}

test "not supported: both lists are empty and nothing is found by name" {
    try std.testing.expectEqual(@as(usize, 0), pluginNamesWhen(false).len);
    try std.testing.expectEqual(@as(usize, 0), mimeTypesWhen(false).len);
    try std.testing.expectEqual(@as(?usize, null), pluginIndex(false, "PDF Viewer"));
    try std.testing.expectEqual(@as(?usize, null), mimeTypeIndex(false, "application/pdf"));
}

test "names are matched exactly (case-sensitive), as namedItem() compares them" {
    try std.testing.expectEqual(@as(?usize, null), pluginIndex(true, "pdf viewer"));
    try std.testing.expectEqual(@as(?usize, null), mimeTypeIndex(true, "APPLICATION/PDF"));
}
