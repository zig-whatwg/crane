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
    /// A device metrics override is in force, set by this session's
    /// setDeviceMetricsOverride with these params (EmulationHandler's
    /// device_emulation_enabled_ and device_emulation_params_): the same
    /// params again change nothing, nor does a clear with none set
    /// (`changesNothing`).
    device_emulation_enabled: bool = false,
    device_emulation_params: ?E.setDeviceMetricsOverride.Params = null,
    /// This session emulates focus for its tab (setFocusEmulationEnabled):
    /// counted once on the tab, and given back when it stops or detaches.
    focus_emulated: bool = false,
    /// This session's CPU throttling rate (Emulation.setCPUThrottlingRate):
    /// 1.0 is unthrottled; cleared when the session detaches.
    cpu_throttling_rate: f64 = 1.0,
};

/// The params that make a device metrics override, as EmulationHandler
/// compares them (blink::DeviceEmulationParams: view and screen size and
/// position, scale factor, mobile, scale, viewport, orientation, display
/// feature, posture) - not dontSetVisibleSize or the scrollbar type, which
/// it keeps out of them.
fn emulationParamsOf(params: E.setDeviceMetricsOverride.Params) E.setDeviceMetricsOverride.Params {
    var p = params;
    p.dontSetVisibleSize = null;
    p.scrollbarType = null;
    return p;
}

/// Whether `method` with `params` would change nothing - what Chrome's
/// browser answers itself, at once, even while the page's commands are held
/// for a navigation (EmulationHandler::SetDeviceMetricsOverride returns
/// Success for `device_emulation_enabled_ && params ==
/// device_emulation_params_`; ClearDeviceMetricsOverride for
/// `!device_emulation_enabled_`; content/browser/devtools/protocol/
/// emulation_handler.cc, chromium/src 65b1b80ff52b). `arena` holds the
/// params' decode. PageSession.holds asks it.
pub fn changesNothing(session: *const PageSession, method: []const u8, params: std.json.Value, arena: std.mem.Allocator) bool {
    const s = &session.states.Emulation;
    if (std.mem.eql(u8, method, "Emulation.clearDeviceMetricsOverride")) return !s.device_emulation_enabled;
    if (!std.mem.eql(u8, method, "Emulation.setDeviceMetricsOverride")) return false;
    if (!s.device_emulation_enabled) return false;
    const stored = s.device_emulation_params orelse return false;
    const given = std.json.parseFromValueLeaky(E.setDeviceMetricsOverride.Params, arena, params, .{ .ignore_unknown_fields = true }) catch return false;
    return std.meta.eql(emulationParamsOf(given), stored);
}

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
    session.states.Emulation.device_emulation_enabled = false;
    session.states.Emulation.device_emulation_params = null;
    // Blink InspectorEmulationAgent::disable resets CPU throttling when the
    // session ends; recompute from any remaining sessions on this Browser so
    // an untouched sibling detaching never clobbers an active session's rate.
    if (session.states.Emulation.cpu_throttling_rate > 1.0) {
        session.states.Emulation.cpu_throttling_rate = 1.0;
        if (browser.event_loop) |loop| {
            var remaining: f64 = 1.0;
            if (session.side) |side| {
                for (side.sessions.items) |other| {
                    if (other == session) continue;
                    if (other.states.Emulation.cpu_throttling_rate > remaining) {
                        remaining = other.states.Emulation.cpu_throttling_rate;
                    }
                }
            }
            loop.setCpuThrottlingRate(remaining);
        }
    }
    const bc = tabOf(session) orelse return;
    // Its focus emulation ends with it, as Chrome's EmulationHandler::Disable
    // turns SetFocusEmulationEnabled off.
    if (session.states.Emulation.focus_emulated) {
        session.states.Emulation.focus_emulated = false;
        @import("html").focus.setFocusEmulation(bc, false);
    }
    const had_media = bc.host_overrides.media_owner == owner(session);
    const had_screen = bc.host_overrides.screen_owner == owner(session);
    bc.host_overrides.clearOwnedBy(bc.allocator, owner(session));
    if (session.browser) |b| dom.browser_state.TabOverrideStore.publish(b.scope, bc.getTop().id, &bc.getTop().host_overrides);
    if (bc.getTop().host_overrides.geolocation_owner == owner(session)) {
        @import("html").geolocation.setEmulatedPositionData(bc, 0, null);
    }
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
    // The same params again: nothing to change (EmulationHandler answers
    // Success then, without applying anything).
    const state = &session.states.Emulation;
    if (state.device_emulation_enabled) if (state.device_emulation_params) |stored| {
        if (std.meta.eql(emulationParamsOf(params), stored)) return .{};
    };
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
    state.device_emulation_enabled = true;
    state.device_emulation_params = emulationParamsOf(params);
    // Chrome tells the page's sessions its frame was resized.
    if (session.states.Page.enabled) session.emit(protocol.Page.frameResized, .{});
    return .{};
}

pub fn clearDeviceMetricsOverride(session: *PageSession, params: E.clearDeviceMetricsOverride.Params) !E.clearDeviceMetricsOverride.Result {
    _ = params;
    // None set: nothing to clear (EmulationHandler answers Success).
    if (!session.states.Emulation.device_emulation_enabled) return .{};
    session.states.Emulation.device_emulation_enabled = false;
    session.states.Emulation.device_emulation_params = null;
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
        } else if (std.mem.eql(u8, feature.name, "prefers-reduced-transparency")) {
            media.reduced_transparency = if (std.mem.eql(u8, value, "reduce")) .reduce else if (std.mem.eql(u8, value, "no-preference")) .no_preference else null;
        } else if (std.mem.eql(u8, feature.name, "inverted-colors")) {
            media.inverted_colors = if (std.mem.eql(u8, value, "inverted")) .inverted else if (std.mem.eql(u8, value, "none")) .none else null;
        } else if (std.mem.eql(u8, feature.name, "color-gamut")) {
            media.color_gamut = if (std.mem.eql(u8, value, "srgb")) .srgb else if (std.mem.eql(u8, value, "p3")) .p3 else if (std.mem.eql(u8, value, "rec2020")) .rec2020 else null;
        } else if (std.mem.eql(u8, feature.name, "dynamic-range")) {
            media.dynamic_range = if (std.mem.eql(u8, value, "standard")) .standard else if (std.mem.eql(u8, value, "high")) .high else null;
        } else if (std.mem.eql(u8, feature.name, "prefers-reduced-data")) {
            media.reduced_data = if (std.mem.eql(u8, value, "reduce")) .reduce else if (std.mem.eql(u8, value, "no-preference")) .no_preference else null;
        }
    }
    const any = media.media_type != null or media.color_scheme != null or media.reduced_motion != null or media.contrast != null or media.forced_colors != null or media.reduced_transparency != null or media.inverted_colors != null or media.color_gamut != null or media.dynamic_range != null or media.reduced_data != null;
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

/// The tab answers as focused while the client emulates focus, whatever its
/// system focus (Blink's FocusController::SetFocusEmulationEnabled:
/// IsFocused() is `is_focused_ || is_emulating_focus_`; Playwright enables it
/// on every page). Every tab has system focus until its host narrows focus to
/// its active tab (the tab-focus ruling, 2026-11-19), so it changes nothing
/// then; in a narrowed Browser a tab in the background answers as focused
/// (html.focus.setFocusEmulation, counted once per session).
pub fn setFocusEmulationEnabled(session: *PageSession, params: E.setFocusEmulationEnabled.Params) !E.setFocusEmulationEnabled.Result {
    // A session whose tab is not there (yet) has nothing to emulate for: it
    // succeeds, as the command always did - Playwright awaits it on every
    // page it attaches to.
    const bc = tabOf(session) orelse return .{};
    if (params.enabled == session.states.Emulation.focus_emulated) return .{};
    session.states.Emulation.focus_emulated = params.enabled;
    @import("html").focus.setFocusEmulation(bc, params.enabled);
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
        if (bc.host_overrides.user_agent_owner == owner(session)) {
            try bc.host_overrides.setUserAgent(bc.allocator, 0, null, null, null);
            if (session.browser) |b| dom.browser_state.TabOverrideStore.publish(b.scope, bc.getTop().id, &bc.getTop().host_overrides);
        }
        return .{};
    }
    try bc.host_overrides.setUserAgent(bc.allocator, owner(session), params.userAgent, params.platform, params.acceptLanguage);
    if (session.browser) |b| dom.browser_state.TabOverrideStore.publish(b.scope, bc.getTop().id, &bc.getTop().host_overrides);
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
/// has a per-isolate setter - requested in
/// https://issues.chromium.org/issues/589285004 (filed 2026-11-22) - a
/// locale other than the default is refused with
/// Chrome's own message for a second override (design risk R13), which
/// Playwright tolerates; the navigator's languages follow
/// setUserAgentOverride's acceptLanguage.
pub fn setLocaleOverride(session: *PageSession, params: E.setLocaleOverride.Params) !E.setLocaleOverride.Result {
    const locale = params.locale orelse return .{};
    if (locale.len == 0 or std.ascii.eqlIgnoreCase(locale, "en-US") or std.ascii.eqlIgnoreCase(locale, "en")) return .{};
    return session.fail("Another locale override is already in effect");
}

/// Blink's InspectorEmulationAgent::setCPUThrottlingRate
/// (third_party/blink/renderer/core/inspector/inspector_emulation_agent.cc)
/// and ThreadCPUThrottler::SetThrottlingRate
/// (third_party/blink/renderer/platform/scheduler/common/thread_cpu_throttler.cc):
/// page targets only (AssertPage); rate <= 1 (or NaN) disables throttling and
/// succeeds; rate > 1 slows the Browser's event loop by `rate`. Persists
/// across navigations within the session and clears on detach.
pub fn setCPUThrottlingRate(session: *PageSession, params: E.setCPUThrottlingRate.Params) !E.setCPUThrottlingRate.Result {
    const browser = session.browser orelse return session.fail("Target is not a page");
    _ = tabOf(session) orelse return session.fail("Target is not a page");
    const rate: f64 = if (params.rate > 1.0) params.rate else 1.0;
    session.states.Emulation.cpu_throttling_rate = rate;
    if (browser.event_loop) |loop| loop.setCpuThrottlingRate(rate);
    return .{};
}

/// Chrome's EmulationHandler::ClearGeolocationOverride
/// (content/browser/devtools/protocol/emulation_handler.cc): clears the tab's
/// geolocation override so the Geolocation API uses the platform source again.
pub fn clearGeolocationOverride(session: *PageSession, params: E.clearGeolocationOverride.Params) !E.clearGeolocationOverride.Result {
    _ = params;
    const bc = tabOf(session) orelse return session.fail("Target is not a page");
    @import("html").geolocation.setEmulatedPositionData(bc, 0, null);
    return .{};
}

/// Chrome's EmulationHandler::SetGeolocationOverride
/// (content/browser/devtools/protocol/emulation_handler.cc): sets the tab's
/// W3C Geolocation §12 emulated position data (winning over the platform source
/// and notifying active watches). Omitting latitude, longitude or accuracy
/// (e.g. `{}`) emulates POSITION_UNAVAILABLE.
pub fn setGeolocationOverride(session: *PageSession, params: E.setGeolocationOverride.Params) !E.setGeolocationOverride.Result {
    const bc = tabOf(session) orelse return session.fail("Target is not a page");
    const override: host_overrides.GeolocationOverride = if (params.latitude != null and params.longitude != null and params.accuracy != null) blk: {
        const lat = params.latitude.?;
        const lon = params.longitude.?;
        const acc = params.accuracy.?;
        if (std.math.isNan(lat) or std.math.isNan(lon) or std.math.isNan(acc) or
            lat < -90.0 or lat > 90.0 or lon < -180.0 or lon > 180.0 or acc < 0.0)
        {
            break :blk .position_unavailable;
        }
        break :blk .{ .coordinates = .{
            .latitude = lat,
            .longitude = lon,
            .accuracy = acc,
            .altitude = params.altitude,
            .altitude_accuracy = params.altitudeAccuracy,
            .heading = params.heading,
            .speed = params.speed,
        } };
    } else .position_unavailable;
    @import("html").geolocation.setEmulatedPositionData(bc, owner(session), override);
    return .{};
}
