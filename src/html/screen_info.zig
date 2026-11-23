//! A window's screen, as script and the media queries see it: CSSOM View's
//! Screen (width, height, availWidth, availHeight, colorDepth, pixelDepth)
//! and devicePixelRatio, the device-width/device-height/resolution media
//! features, and Screen Orientation's "current orientation type" and
//! "current orientation angle" (specs/w3c/screen-orientation.md, "The
//! current screen orientation type and angle").
//!
//! The screen is the tab's - its top-level traversable's - and comes from,
//! in order: a host's emulated device (html_core.window.host_overrides
//! Screen: CDP Emulation.setDeviceMetricsOverride, as Blink's
//! ScreenMetricsEmulator overrides the page's screen info while emulation is
//! on), the platform's last report for the tab (`screen_changed(tab,
//! screen)`, docs/platform-protocol.md section 7, kept as the traversable's
//! `reported_screen` - the way `window_rect_changed` reaches its viewport,
//! src/browser/viewport.zig), and else the platform's `screenInfo` answer.
//! A change asks the tab's active document for a rendering opportunity -
//! where the media queries are evaluated again (HTML "update the rendering"
//! step 10) - and runs the screen orientation change steps
//! (html.screen_orientation). The Browser's window thread. Lane cdph.

const std = @import("std");
const runtime = @import("runtime");
const platform = @import("platform");
const dom = @import("dom");
const html_core = @import("html_core");
const platform_state = @import("platform_state.zig");
const screen_orientation = @import("screen_orientation.zig");

const BrowsingContext = html_core.window.browsing_context.BrowsingContext;
const ScreenOverride = html_core.window.host_overrides.Screen;

pub const Screen = platform.ScreenInfo;

/// A realm no Browser platform serves (an engine-less test's): the headless
/// platform's screen (src/platform/kit/headless/root.zig default_screen),
/// which Screen answered before it asked the platform.
const no_platform: Screen = .{
    .width = 1920,
    .height = 1080,
    .avail_width = 1920,
    .avail_height = 1040,
    .color_depth = 24,
    .pixel_depth = 24,
    .device_pixel_ratio = 1.0,
    .orientation = .landscape_primary,
    .orientation_angle = 0,
};

/// The screen of `window`'s tab.
pub fn ofWindow(window: *runtime.Instance) Screen {
    const bc = dom.browser_state.browsingContextOf(window) orelse return platformScreen(window.ctx);
    return ofTraversable(window.ctx, bc.getTop());
}

/// The screen of the top-level traversable `top`, asked in `realm`.
pub fn ofTraversable(realm: runtime.Context, top: *BrowsingContext) Screen {
    var screen = top.reported_screen orelse platformScreen(realm);
    if (top.host_overrides.screen) |emulated| apply(&screen, emulated);
    return screen;
}

/// The screen a realm with no window's tab sees: the platform's.
pub fn ofRealm(realm: runtime.Context) Screen {
    return platformScreen(realm);
}

fn platformScreen(realm: runtime.Context) Screen {
    const browser = platform_state.of(realm) orelse return no_platform;
    return platform.screenInfo(browser);
}

/// An emulated device over the platform's screen: its size is the screen's
/// and the available area's (ScreenMetricsEmulator sets both rects to the
/// emulated one), its scale the device pixel ratio, its orientation the
/// current type and angle. What it leaves null stays the platform's.
fn apply(screen: *Screen, emulated: ScreenOverride) void {
    if (emulated.width) |width| {
        screen.width = width;
        screen.avail_width = width;
    }
    if (emulated.height) |height| {
        screen.height = height;
        screen.avail_height = height;
    }
    if (emulated.device_pixel_ratio) |ratio| screen.device_pixel_ratio = ratio;
    if (emulated.orientation) |orientation| {
        screen.orientation = orientation.type;
        screen.orientation_angle = orientation.angle;
    }
}

/// The platform's `screen_changed(tab, screen)`: the tab's top-level
/// traversable - every one of the Browser's for tab 0 - reports `screen`
/// from now on. The window's loop.
pub fn screenChanged(scope: *runtime.BrowserScope, tab: platform.TabId, screen: Screen) void {
    const navigables = dom.browser_state.existingNavigablesIn(scope) orelse return;
    for (navigables.contexts()) |traversable| {
        if (traversable.parent != null or traversable.is_closed) continue;
        if (tab != 0 and traversable.id != tab) continue;
        const realm = realmOf(traversable) orelse {
            traversable.reported_screen = screen;
            continue;
        };
        const before = ofTraversable(realm, traversable);
        traversable.reported_screen = screen;
        if (!std.meta.eql(before, ofTraversable(realm, traversable))) changed(traversable);
    }
}

/// The screen of top-level traversable `traversable` may have changed -
/// the platform reported, or a host's emulation was set or cleared: its
/// active document asks for a rendering opportunity (the media queries),
/// and the screen orientation change steps run with it ("when a user-agent
/// determines that the screen's orientation has changed for a top-level
/// traversable": they compare each document's last known type and angle,
/// so a change of size alone fires nothing).
pub fn changed(traversable: *BrowsingContext) void {
    const document: *runtime.Instance = @ptrCast(@alignCast(traversable.getActiveDocument() orelse return));
    dom.update_the_rendering.requestFrame(document);
    screen_orientation.changeSteps(document);
}

fn realmOf(traversable: *BrowsingContext) ?runtime.Context {
    const document: *runtime.Instance = @ptrCast(@alignCast(traversable.getActiveDocument() orelse return null));
    return document.ctx;
}

test "an emulated device's screen wins field by field over the platform's" {
    var screen = no_platform;
    apply(&screen, .{ .width = 390, .device_pixel_ratio = 3, .orientation = .{ .type = .portrait_primary, .angle = 0 } });
    try std.testing.expectEqual(@as(i32, 390), screen.width);
    try std.testing.expectEqual(@as(i32, 390), screen.avail_width);
    try std.testing.expectEqual(@as(i32, 1080), screen.height);
    try std.testing.expectEqual(@as(i32, 1040), screen.avail_height);
    try std.testing.expectEqual(@as(f64, 3), screen.device_pixel_ratio);
    try std.testing.expectEqual(platform.OrientationType.portrait_primary, screen.orientation);
}
