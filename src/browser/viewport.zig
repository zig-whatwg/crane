//! A top-level traversable's viewport: what the platform's window reports,
//! and a host's override of it.
//!
//! Crane draws nothing, so a viewport's size is the host's to say. For a
//! headless window - no chrome - the platform's window rect IS the viewport
//! (`window_rect_changed(tab, rect)`, docs/platform-protocol.md section 7;
//! the integrator's ruling C, 2026-11-21: no viewport operation of its own).
//! An automation client can override it for a tab, as CDP's
//! Emulation.setDeviceMetricsOverride does - Chrome keeps that override per
//! page (content/browser/devtools/protocol/emulation_handler.cc, Blink's
//! InspectorEmulationAgent) and it wins over the window while set.
//!
//! CSSOM View's innerWidth/innerHeight read the result
//! (BrowsingContext.traversableViewport), and so do the media queries that
//! read them. A change asks the traversable's active document for a
//! rendering opportunity, where HTML "update the rendering" step 8 runs the
//! resize steps (the Window's: a `resize` event when the size moved since
//! the last run) and step 10 evaluates the media queries and reports their
//! changes. Everything here runs on the Browser's window thread.
const std = @import("std");
const runtime = @import("runtime");
const platform = @import("platform");
const dom = @import("dom");
const html = @import("html");

pub const ViewportSize = html.window.browsing_context.ViewportSize;
const BrowsingContext = html.window.browsing_context.BrowsingContext;

/// The platform's `window_rect_changed(tab, rect)`: the viewport of the
/// tab's top-level traversable - or of every top-level traversable for tab 0
/// - is the rect's size, in CSS pixels (a fraction rounds down, as a
/// viewport's integer innerWidth does).
pub fn windowRectChanged(scope: *runtime.BrowserScope, tab: platform.TabId, rect: platform.Rect) void {
    const navigables = dom.browser_state.existingNavigablesIn(scope) orelse return;
    const size: ViewportSize = .{ .width = cssPixels(rect.width), .height = cssPixels(rect.height) };
    for (navigables.contexts()) |traversable| {
        if (traversable.parent != null or traversable.is_closed) continue;
        if (tab != 0 and traversable.id != tab) continue;
        const before = traversable.traversableViewport();
        traversable.viewport = size;
        changed(traversable, before);
    }
}

/// A host's viewport override for the top-level traversable whose browsing
/// context id is `traversable_id` - null takes it away, and the platform's
/// window decides again. False when no open top-level traversable of this
/// Browser has that id.
pub fn setOverride(scope: *runtime.BrowserScope, traversable_id: u64, size: ?ViewportSize) bool {
    const navigables = dom.browser_state.existingNavigablesIn(scope) orelse return false;
    for (navigables.contexts()) |traversable| {
        if (traversable.parent != null or traversable.is_closed or traversable.id != traversable_id) continue;
        const before = traversable.traversableViewport();
        traversable.viewport_override = size;
        changed(traversable, before);
        return true;
    }
    return false;
}

/// The traversable's viewport may have moved from `before`: when it did, its
/// active document asks for a rendering opportunity, whose resize and media
/// query steps tell its script.
fn changed(traversable: *BrowsingContext, before: ?ViewportSize) void {
    const after = traversable.traversableViewport();
    if (before) |b| if (after) |a| {
        if (a.width == b.width and a.height == b.height) return;
    };
    if (before == null and after == null) return;
    const document: *runtime.Instance = @ptrCast(@alignCast(traversable.getActiveDocument() orelse return));
    dom.update_the_rendering.requestFrame(document);
}

/// A platform length (f64) as a whole number of CSS pixels, never negative.
fn cssPixels(length: f64) i32 {
    if (!(length > 0)) return 0;
    if (length >= @as(f64, @floatFromInt(std.math.maxInt(i32)))) return std.math.maxInt(i32);
    return @intFromFloat(@floor(length));
}

test "a platform length is whole CSS pixels, clamped" {
    try std.testing.expectEqual(@as(i32, 1280), cssPixels(1280.9));
    try std.testing.expectEqual(@as(i32, 0), cssPixels(-5));
    try std.testing.expectEqual(@as(i32, 0), cssPixels(std.math.nan(f64)));
    try std.testing.expectEqual(@as(i32, std.math.maxInt(i32)), cssPixels(1e12));
}
