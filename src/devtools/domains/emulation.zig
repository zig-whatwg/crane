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
    bc.host_overrides.clearOwnedBy(bc.allocator, owner(session));
    if (had_media) mediaChanged(bc);
}

/// The viewport (and the screen it implies) as the client's device: width
/// and height 0 give that dimension back to the platform's window (Chrome:
/// "0 disables the override"). Device scale and screen size are not yet
/// overridden: devicePixelRatio and screen.* keep the platform's answers.
pub fn setDeviceMetricsOverride(session: *PageSession, params: E.setDeviceMetricsOverride.Params) !E.setDeviceMetricsOverride.Result {
    const browser = session.browser orelse return session.fail("Target is not a page");
    const bc = tabOf(session) orelse return session.fail("Target is not a page");
    if (params.width < 0 or params.height < 0) return session.failWithCode(.invalid_params, "Width and height values must be positive, not greater than 10000000");
    const size: ?frames.ViewportSize = if (params.width == 0 and params.height == 0) null else blk: {
        const window = bc.viewport;
        const width: i32 = if (params.width > 0) @intCast(@min(params.width, std.math.maxInt(i32))) else if (window) |w| w.width else 0;
        const height: i32 = if (params.height > 0) @intCast(@min(params.height, std.math.maxInt(i32))) else if (window) |w| w.height else 0;
        break :blk .{ .width = width, .height = height };
    };
    if (!browser_mod.viewport.setOverride(browser.scope, session.tab, size)) return session.fail("Target is not a page");
    session.states.Emulation.viewport_set = size != null;
    // Chrome tells the page's sessions its frame was resized.
    if (session.states.Page.enabled) session.emit(protocol.Page.frameResized, .{});
    return .{};
}

pub fn clearDeviceMetricsOverride(session: *PageSession, params: E.clearDeviceMetricsOverride.Params) !E.clearDeviceMetricsOverride.Result {
    _ = params;
    const browser = session.browser orelse return .{};
    _ = browser_mod.viewport.setOverride(browser.scope, session.tab, null);
    session.states.Emulation.viewport_set = false;
    return .{};
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
    if (params.userAgent.len == 0 and params.acceptLanguage == null and params.platform == null) {
        if (bc.host_overrides.user_agent_owner == owner(session)) try bc.host_overrides.setUserAgent(bc.allocator, 0, null, null, null);
        return .{};
    }
    try bc.host_overrides.setUserAgent(bc.allocator, owner(session), params.userAgent, params.platform, params.acceptLanguage);
    return .{};
}

/// The default locale of the tab's Intl. Locale data is per process in
/// Crane, as ICU's default is in Chrome, so tabs cannot differ: a locale
/// other than the default is refused with Chrome's own message for a second
/// override (design risk R13), which Playwright tolerates; the navigator's
/// languages follow setUserAgentOverride's acceptLanguage.
pub fn setLocaleOverride(session: *PageSession, params: E.setLocaleOverride.Params) !E.setLocaleOverride.Result {
    const locale = params.locale orelse return .{};
    if (locale.len == 0 or std.ascii.eqlIgnoreCase(locale, "en-US") or std.ascii.eqlIgnoreCase(locale, "en")) return .{};
    return session.fail("Another locale override is already in effect");
}
