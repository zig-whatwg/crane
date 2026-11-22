//! The Emulation domain on page sessions: per-tab overrides of what the
//! platform answers (lane cdph, P4; design 3.8) - the viewport (life1's
//! browser/viewport.zig override, which innerWidth/innerHeight and the
//! media queries read, a change running the resize steps at the next
//! rendering opportunity), the media type and media features, touch points
//! and the user agent (html.window.host_overrides, read by the media
//! queries and the navigator). Chrome's EmulationHandler and Blink's
//! InspectorEmulationAgent keep them per page and clear a session's own
//! when it detaches (content/browser/devtools/protocol/emulation_handler.cc;
//! third_party/blink/renderer/core/inspector/inspector_emulation_agent.cc;
//! reproduced, not copied): each override here records the session that set
//! it, and `sessionEnded` clears only those.

const std = @import("std");
const dom = @import("dom");
const browser_mod = @import("browser");
const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");
const frames = @import("../frames.zig");
const E = protocol.Emulation;

const host_overrides = @import("html").window.host_overrides;

/// Per-session state of the domain.
pub const State = struct {
    /// This session set the tab's viewport override (the viewport keeps one,
    /// with no owner: the session that set it last clears it).
    viewport_set: bool = false,
};

/// The owner token of the session's overrides.
fn owner(session: *PageSession) host_overrides.Owner {
    return @intFromPtr(session);
}

fn tabOf(session: *PageSession) ?*frames.BrowsingContext {
    return frames.navigable(session, session.tab);
}

pub fn sessionEnded(session: *PageSession) void {
    const browser = session.browser orelse return;
    if (session.states.Emulation.viewport_set) {
        _ = browser_mod.viewport.setOverride(browser.scope, session.tab, null);
        session.states.Emulation.viewport_set = false;
    }
    const bc = tabOf(session) orelse return;
    const had_media = bc.host_overrides.media_owner == owner(session);
    const had_screen = bc.host_overrides.screen_owner == owner(session);
    bc.host_overrides.clearOwnedBy(bc.allocator, owner(session));
    if (had_media) mediaChanged(bc);
    if (had_screen) @import("html").screen_info.changed(bc.getTop());
}

/// The viewport and the screen as the client's device: width and height 0
/// give that dimension back to the platform's window (Chrome: "0 disables
/// the override"); the device's screen (html_core host_overrides Screen,
/// read through html.screen_info) is its scale - devicePixelRatio and the
/// resolution media feature, 0 the platform's - its size - screenWidth and
/// screenHeight, else for a mobile device the view's size, while a desktop
/// one keeps the real screen - and its orientation (screenOrientation, which
/// screen.orientation reports and fires `change` for). Blink's
/// ScreenMetricsEmulator::Apply and Chrome's EmulationHandler::
/// SetDeviceMetricsOverride (its checks and messages), reproduced.
pub fn setDeviceMetricsOverride(session: *PageSession, params: E.setDeviceMetricsOverride.Params) !E.setDeviceMetricsOverride.Result {
    const browser = session.browser orelse return session.fail("Target is not a page");
    const bc = tabOf(session) orelse return session.fail("Target is not a page");
    const max_size = 10_000_000;
    if (params.width < 0 or params.height < 0 or params.width > max_size or params.height > max_size) return session.failWithCode(.invalid_params, "Width and height values must be positive, not greater than 10000000");
    const screen_width = params.screenWidth orelse 0;
    const screen_height = params.screenHeight orelse 0;
    if (screen_width < 0 or screen_height < 0 or screen_width > max_size or screen_height > max_size) return session.failWithCode(.invalid_params, "Screen width and height values must be positive, not greater than 10000000");
    if (params.deviceScaleFactor < 0) return session.failWithCode(.invalid_params, "deviceScaleFactor must be non-negative");
    var orientation: ?host_overrides.Screen.Orientation = null;
    if (params.screenOrientation) |given| {
        if (given.angle < 0 or given.angle >= 360) return session.failWithCode(.invalid_params, "Screen orientation angle must be non-negative, less than 360");
        orientation = .{ .type = switch (given.type) {
            .portraitPrimary => .portrait_primary,
            .portraitSecondary => .portrait_secondary,
            .landscapePrimary => .landscape_primary,
            .landscapeSecondary => .landscape_secondary,
        }, .angle = @intCast(given.angle) };
    }
    const size: ?frames.ViewportSize = if (params.width == 0 and params.height == 0) null else blk: {
        const window = bc.viewport;
        const width: i32 = if (params.width > 0) @intCast(@min(params.width, std.math.maxInt(i32))) else if (window) |w| w.width else 0;
        const height: i32 = if (params.height > 0) @intCast(@min(params.height, std.math.maxInt(i32))) else if (window) |w| w.height else 0;
        break :blk .{ .width = width, .height = height };
    };
    if (!browser_mod.viewport.setOverride(browser.scope, session.tab, size)) return session.fail("Target is not a page");
    session.states.Emulation.viewport_set = size != null;
    var screen: host_overrides.Screen = .{ .orientation = orientation };
    if (params.deviceScaleFactor > 0) screen.device_pixel_ratio = params.deviceScaleFactor;
    if (screen_width > 0 and screen_height > 0) {
        screen.width = @intCast(screen_width);
        screen.height = @intCast(screen_height);
    } else if (params.mobile) if (size) |view| {
        screen.width = view.width;
        screen.height = view.height;
    };
    const any = screen.width != null or screen.device_pixel_ratio != null or screen.orientation != null;
    setScreen(session, bc, if (any) screen else null);
    // Chrome tells the page's sessions its frame was resized.
    if (session.states.Page.enabled) session.emit(protocol.Page.frameResized, .{});
    return .{};
}

pub fn clearDeviceMetricsOverride(session: *PageSession, params: E.clearDeviceMetricsOverride.Params) !E.clearDeviceMetricsOverride.Result {
    _ = params;
    const browser = session.browser orelse return .{};
    _ = browser_mod.viewport.setOverride(browser.scope, session.tab, null);
    session.states.Emulation.viewport_set = false;
    if (tabOf(session)) |bc| setScreen(session, bc, null);
    return .{};
}

/// The tab's emulated screen is `screen` (null: the platform's again); a
/// change reaches the media queries and screen.orientation
/// (html.screen_info.changed).
fn setScreen(session: *PageSession, bc: *frames.BrowsingContext, screen: ?host_overrides.Screen) void {
    const top = bc.getTop();
    const before = top.host_overrides.screen;
    top.host_overrides.setScreen(owner(session), screen);
    if (before == null and screen == null) return;
    if (before) |b| if (screen) |a| if (std.meta.eql(a, b)) return;
    @import("html").screen_info.changed(top);
}

/// The media type and the media features the tab's media queries see
/// (InspectorEmulationAgent::setEmulatedMedia). An empty media string, or a
/// feature with an empty value, gives it back to the platform; features
/// Crane's media queries do not read are accepted and change nothing.
pub fn setEmulatedMedia(session: *PageSession, params: E.setEmulatedMedia.Params) !E.setEmulatedMedia.Result {
    const bc = tabOf(session) orelse return session.fail("Target is not a page");
    var media: host_overrides.Media = .{};
    if (params.media) |name| {
        if (std.mem.eql(u8, name, "screen")) media.media_type = .screen else if (std.mem.eql(u8, name, "print")) media.media_type = .print;
    }
    for (params.features orelse &.{}) |feature| {
        const value = feature.value;
        if (std.mem.eql(u8, feature.name, "prefers-color-scheme")) {
            media.color_scheme = if (std.mem.eql(u8, value, "dark")) .dark else if (std.mem.eql(u8, value, "light")) .light else null;
        } else if (std.mem.eql(u8, feature.name, "prefers-reduced-motion")) {
            media.reduced_motion = if (std.mem.eql(u8, value, "reduce")) .reduce else if (std.mem.eql(u8, value, "no-preference")) .no_preference else null;
        } else if (std.mem.eql(u8, feature.name, "prefers-contrast")) {
            media.contrast = if (std.mem.eql(u8, value, "more")) .more else if (std.mem.eql(u8, value, "less")) .less else if (std.mem.eql(u8, value, "custom")) .custom else if (std.mem.eql(u8, value, "no-preference")) .no_preference else null;
        } else if (std.mem.eql(u8, feature.name, "forced-colors")) {
            media.forced_colors = if (std.mem.eql(u8, value, "active")) true else if (std.mem.eql(u8, value, "none")) false else null;
        }
    }
    const any = media.media_type != null or media.color_scheme != null or media.reduced_motion != null or media.contrast != null or media.forced_colors != null;
    bc.host_overrides.setMedia(owner(session), if (any) media else null);
    mediaChanged(bc);
    return .{};
}

/// The tab's media changed: its document asks for a rendering opportunity,
/// whose step evaluating media queries reports the changes (HTML "update the
/// rendering" step 10), as a viewport change does.
fn mediaChanged(bc: *frames.BrowsingContext) void {
    const document = frames.documentOf(bc) orelse return;
    dom.update_the_rendering.requestFrame(document);
}

/// Every headless tab is focused already (the tab-focus ruling,
/// 2026-11-19): nothing to emulate (design 1.4 "A").
pub fn setFocusEmulationEnabled(session: *PageSession, params: E.setFocusEmulationEnabled.Params) !E.setFocusEmulationEnabled.Result {
    _ = session;
    _ = params;
    return .{};
}

/// Touch: navigator.maxTouchPoints as the client says (1 when it names no
/// count), or the device's again when disabled.
pub fn setTouchEmulationEnabled(session: *PageSession, params: E.setTouchEmulationEnabled.Params) !E.setTouchEmulationEnabled.Result {
    const bc = tabOf(session) orelse return session.fail("Target is not a page");
    if (params.enabled) {
        const points = params.maxTouchPoints orelse 1;
        if (points < 1 or points > 16) return session.failWithCode(.invalid_params, "Touch points must be between 1 and 16");
        bc.host_overrides.setMaxTouchPoints(owner(session), @intCast(points));
    } else if (bc.host_overrides.touch_owner == owner(session)) {
        bc.host_overrides.setMaxTouchPoints(0, null);
    }
    return .{};
}

/// The tab's user agent: navigator.userAgent, navigator.platform and its
/// languages (from acceptLanguage). Its fetches' User-Agent and
/// Accept-Language headers are lane cdpt's (Network, P5).
pub fn setUserAgentOverride(session: *PageSession, params: E.setUserAgentOverride.Params) !E.setUserAgentOverride.Result {
    const bc = tabOf(session) orelse return session.fail("Target is not a page");
    // Each field applies only when non-empty (EmulationHandler::
    // ApplyOverrides): `userAgent: ""` with an acceptLanguage - Playwright's
    // call for every locale - overrides the languages and leaves the user
    // agent the Browser's. All empty clears this session's override.
    const no_language = if (params.acceptLanguage) |given| given.len == 0 else true;
    const no_platform = if (params.platform) |given| given.len == 0 else true;
    const all_empty = params.userAgent.len == 0 and no_language and no_platform;
    if (all_empty) {
        if (bc.host_overrides.user_agent_owner == owner(session)) try bc.host_overrides.setUserAgent(bc.allocator, 0, null, null, null);
        return .{};
    }
    try bc.host_overrides.setUserAgent(bc.allocator, owner(session), params.userAgent, params.platform, params.acceptLanguage);
    return .{};
}

/// The default locale of the tab's Intl. V8's Intl reads it from ICU's
/// process-wide default (V8 15.7 Isolate::DefaultLocale fills its per-isolate
/// cache only from there; the public API can clear that cache, never set it),
/// and the V8 adapter sets that default once, from the platform's preferred
/// language, when V8 starts (snapshot_loader.icuDefaultLocale). Chrome
/// overrides it per renderer process (Blink LocaleController: ICU's default,
/// then every isolate notified), which is one browsing context group there;
/// in Crane one process holds several isolated Browsers, so changing the
/// process default for one tab would change Intl in every other Browser (the
/// user's ruling, 2026-11-22 10:43 AM ET: no process-wide setter). Until V8
/// has a per-isolate setter - the feature request drafted in
/// tmp/plans/v8-feature-request-isolate-default-locale.md, for
/// issues.chromium.org - a locale other than the default is refused with
/// Chrome's own message for a second override (design risk R13), which
/// Playwright tolerates; the navigator's languages follow
/// setUserAgentOverride's acceptLanguage.
pub fn setLocaleOverride(session: *PageSession, params: E.setLocaleOverride.Params) !E.setLocaleOverride.Result {
    const locale = params.locale orelse return .{};
    if (locale.len == 0 or std.ascii.eqlIgnoreCase(locale, "en-US") or std.ascii.eqlIgnoreCase(locale, "en")) return .{};
    return session.fail("Another locale override is already in effect");
}
