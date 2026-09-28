//! What a traversable's session history records about a document: its URL
//! and its origin, both serialized (html_core JointHistory). Read through the
//! interfaces, for every navigable - History, Location, the navigation API
//! and the navigable containers all record entries.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const html_core = @import("html_core");

/// `document`'s URL, serialized, owned by `allocator`; "about:blank" when it
/// has none or cannot be read.
pub fn urlOf(document: *runtime.Instance, allocator: std.mem.Allocator) ![]u8 {
    const url = interfaces.Document.get_URL(document) catch return allocator.dupe(u8, "about:blank");
    defer document.ctx.allocator.free(url);
    return allocator.dupe(u8, if (url.len == 0) "about:blank" else url);
}

/// `document`'s origin, serialized, owned by `allocator`: its window's
/// (`self.origin`), or "null" for a document with no window.
pub fn originOf(document: *runtime.Instance, allocator: std.mem.Allocator) ![]u8 {
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return allocator.dupe(u8, "null");
    const origin = interfaces.Window.get_origin(window) catch return allocator.dupe(u8, "null");
    defer window.ctx.allocator.free(origin);
    return allocator.dupe(u8, origin);
}

/// BrowsingContext.ensureHistoryEntries's `info_of`.
pub fn infoOf(document: *anyopaque, allocator: std.mem.Allocator) anyerror!html_core.navigation.joint_history.DocumentInfo {
    const doc: *runtime.Instance = @ptrCast(@alignCast(document));
    const url = try urlOf(doc, allocator);
    errdefer allocator.free(url);
    return .{ .url = url, .origin = try originOf(doc, allocator) };
}
