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
        // The window's rect too (screenX/screenY, outerWidth/outerHeight).
        traversable.window_rect = .{ .x = cssPosition(rect.x), .y = cssPosition(rect.y), .width = size.width, .height = size.height };
        changed(traversable, before);
    }
}

pub const WindowRect = html.window.browsing_context.WindowRect;
pub const WindowState = html.window.browsing_context.WindowState;

/// A tab's window: its rect and state (CDP Browser.Bounds).
pub const WindowBounds = struct { rect: WindowRect, state: WindowState };

/// The headless platform's window when nothing has said otherwise
/// (kit/headless windowRect: the default viewport at the origin).
const default_window: WindowRect = .{ .width = 1024, .height = 768 };

/// Tab `tab`'s window (CDP Browser.getWindowForTarget / getWindowBounds):
/// the rect the platform, a host or the page set, else the window its
/// viewport is; null when no open top-level traversable has that id.
pub fn windowBounds(scope: *runtime.BrowserScope, tab: u64) ?WindowBounds {
    const traversable = topLevel(scope, tab) orelse return null;
    return .{ .rect = currentRect(traversable), .state = traversable.window_state };
}

fn currentRect(traversable: *BrowsingContext) WindowRect {
    if (traversable.window_rect) |rect| return rect;
    const size = traversable.viewport orelse return default_window;
    return .{ .width = size.width, .height = size.height };
}

fn topLevel(scope: *runtime.BrowserScope, tab: u64) ?*BrowsingContext {
    const navigables = dom.browser_state.existingNavigablesIn(scope) orelse return null;
    for (navigables.contexts()) |traversable| {
        if (traversable.parent != null or traversable.is_closed or traversable.id != tab) continue;
        return traversable;
    }
    return null;
}

/// What a host asks of a tab's window (CDP Browser.setWindowBounds): new
/// edges, each that is given, and/or a state.
pub const WindowChange = struct {
    x: ?i32 = null,
    y: ?i32 = null,
    width: ?i32 = null,
    height: ?i32 = null,
    state: ?WindowState = null,
};

pub const WindowChangeError = error{
    NoSuchTab,
    /// New edges for a window that is not normal: Chrome's "To resize
    /// minimized/maximized/fullscreen window, restore it to normal state
    /// first."
    NotNormal,
};

/// Change tab `tab`'s window as Chrome's BrowserHandler::SetWindowBounds
/// does (chrome/browser/devtools/protocol/browser_handler.cc; reproduced):
/// "normal" first restores a minimized, maximized or fullscreen window to
/// the rect it had; new edges then move or resize a normal window (refused
/// for any other); "minimized" keeps the rect, "maximized" takes the
/// screen's available area and "fullscreen" the whole screen, each keeping
/// the normal rect to restore. The viewport follows the rect's size (a
/// headless window's rect IS its viewport) and the resize steps run at the
/// next rendering opportunity.
pub fn setWindowBounds(scope: *runtime.BrowserScope, tab: u64, change: WindowChange) WindowChangeError!void {
    const traversable = topLevel(scope, tab) orelse return error.NoSuchTab;
    var rect = currentRect(traversable);
    if (change.state) |state| if (state == .normal and traversable.window_state != .normal) {
        rect = traversable.restore_rect orelse rect;
        traversable.restore_rect = null;
        traversable.window_state = .normal;
    };
    if (change.x != null or change.y != null or change.width != null or change.height != null) {
        if (traversable.window_state != .normal) return error.NotNormal;
        if (change.x) |v| rect.x = v;
        if (change.y) |v| rect.y = v;
        if (change.width) |v| rect.width = @max(v, 0);
        if (change.height) |v| rect.height = @max(v, 0);
    }
    if (change.state) |state| switch (state) {
        .normal => {},
        .minimized, .maximized, .fullscreen => {
            if (traversable.window_state == .normal) traversable.restore_rect = rect;
            traversable.window_state = state;
            if (state != .minimized) rect = screenRect(traversable, state == .fullscreen);
        },
    };
    const before = traversable.traversableViewport();
    traversable.window_rect = rect;
    traversable.viewport = .{ .width = rect.width, .height = rect.height };
    changed(traversable, before);
}

/// The screen the tab's window is on - the tab's (html.screen_info: an
/// emulated device's, else the platform's) - its whole area, or its
/// available area, at the origin.
fn screenRect(traversable: *BrowsingContext, whole: bool) WindowRect {
    const window: *runtime.Instance = @ptrCast(@alignCast(traversable.getActiveWindow() orelse return default_window));
    const screen = html.screen_info.ofTraversable(window.ctx, traversable);
    return if (whole)
        .{ .width = screen.width, .height = screen.height }
    else
        .{ .width = screen.avail_width, .height = screen.avail_height };
}

/// A platform coordinate (f64) as a whole CSS pixel, either sign.
fn cssPosition(value: f64) i32 {
    if (!std.math.isFinite(value)) return 0;
    return @intFromFloat(std.math.clamp(@floor(value), @as(f64, std.math.minInt(i32)), @as(f64, std.math.maxInt(i32))));
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
