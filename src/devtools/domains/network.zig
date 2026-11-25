//! The Network domain on page sessions (tmp/plans/cdp-part1-design.md 3.9):
//! the session's switches and its kept bodies. The events come from the
//! Browser's fetch observer (src/devtools/fetch_observer.zig), which reports a
//! request to every session of its tab with Network enabled - Blink's
//! InspectorNetworkAgent, enabled per session (third_party/blink/renderer/
//! core/inspector/inspector_network_agent.cc) - and keeps each request's
//! bodies in the session's NetworkResources (network_resources.zig: Blink's
//! NetworkResourcesData) for getResponseBody and getRequestPostData.

const std = @import("std");
const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");
const network_resources = @import("../network_resources.zig");
const fetch_observer = @import("../fetch_observer.zig");
const frames = @import("../frames.zig");

const N = protocol.Network;
const NetworkResources = network_resources.NetworkResources;

/// Per-session state of the domain.
pub const State = struct {
    enabled: bool = false,
    /// Network.setCacheDisabled: the tab's requests go past the HTTP cache.
    cache_disabled: bool = false,
    /// Network.enable's maxPostDataSize: requestWillBeSent's postData only
    /// for a body no longer than it (0: any - Blink's max_post_data_size_
    /// default).
    max_post_data_size: u64 = 0,
    /// The kept bodies, while Network is enabled; null before.
    resources: ?NetworkResources = null,
    /// Network.setExtraHTTPHeaders' set (Chrome's NetworkHandler
    /// extra_headers_), kept while Network is disabled too: the tab's
    /// requests carry it only while Network is enabled (`applyHeaders`).
    /// OWNED (session.allocator).
    extra_headers: []host_overrides.ExtraHeader = &.{},
};

fn clear(session: *PageSession) void {
    const state = &session.states.Network;
    if (state.resources) |*r| r.deinit();
    dropHeaders(session);
    freeHeaders(session);
    state.* = .{};
}

/// The session's extra headers onto its tab, which every request of its
/// documents then carries: Chrome applies a session's headers only while
/// its Network domain is enabled (devtools_instrumentation.cc
/// ApplyNetworkRequestOverrides skips a NetworkHandler that is not
/// enabled; Blink's InspectorNetworkAgent::PrepareRequest is reached only
/// through an enabled agent).
fn applyHeaders(session: *PageSession) !void {
    const bc = frames.navigable(session, session.tab) orelse return;
    try bc.host_overrides.setExtraHeaders(bc.allocator, @intFromPtr(session), session.states.Network.extra_headers);
}

/// The tab's extra headers, when they are this session's, off it.
fn dropHeaders(session: *PageSession) void {
    const bc = frames.navigable(session, session.tab) orelse return;
    if (bc.host_overrides.extra_headers_owner != @intFromPtr(session)) return;
    // An empty set allocates nothing: it cannot fail.
    bc.host_overrides.setExtraHeaders(bc.allocator, @intFromPtr(session), &.{}) catch {};
}

fn freeHeaders(session: *PageSession) void {
    const state = &session.states.Network;
    for (state.extra_headers) |header| {
        session.allocator.free(header.name);
        session.allocator.free(header.value);
    }
    if (state.extra_headers.len > 0) session.allocator.free(state.extra_headers);
    state.extra_headers = &.{};
}

/// Blink's InspectorNetworkAgent::enable: the buffer limits (defaults
/// kDefaultTotalBufferSize / kDefaultResourceBufferSize) and the post data
/// limit, then the agent on.
pub fn enable(session: *PageSession, params: N.enable.Params) !N.enable.Result {
    const state = &session.states.Network;
    const total: u64 = if (params.maxTotalBufferSize) |v| @intCast(@max(v, 0)) else network_resources.default_total_buffer_size;
    const one: u64 = if (params.maxResourceBufferSize) |v| @intCast(@max(v, 0)) else network_resources.default_resource_buffer_size;
    if (state.resources == null) state.resources = NetworkResources.init(session.allocator);
    state.resources.?.setLimits(total, one);
    state.max_post_data_size = if (params.maxPostDataSize) |v| @intCast(@max(v, 0)) else 0;
    state.enabled = true;
    // Headers set while disabled apply from now on.
    if (state.extra_headers.len > 0) try applyHeaders(session);
    return .{};
}

/// Chrome's NetworkHandler::Disable: the agent off and its extra headers
/// cleared (`extra_headers_.clear()`).
pub fn disable(session: *PageSession, _: N.disable.Params) !N.disable.Result {
    clear(session);
    return .{};
}

pub fn sessionEnded(session: *PageSession) void {
    clear(session);
}

pub fn setCacheDisabled(session: *PageSession, params: N.setCacheDisabled.Params) !N.setCacheDisabled.Result {
    session.states.Network.cache_disabled = params.cacheDisabled;
    return .{};
}

/// A main-frame commit of the session's tab: every kept record goes but
/// the committing navigation's (InspectorNetworkAgent::DidCommitLoad ->
/// NetworkResourcesData::Clear(loader id)).
pub fn onNavigation(session: *PageSession, milestone: *const frames.Milestone) void {
    if (milestone.navigable_id != session.tab) return;
    switch (milestone.event) {
        .committed => if (session.states.Network.resources) |*r| r.clearExcept(milestone.navigation_id),
        else => {},
    }
}

/// Blink's InspectorNetworkAgent::GetResponseBody, its messages.
pub fn getResponseBody(session: *PageSession, params: N.getResponseBody.Params) !N.getResponseBody.Result {
    const resources = if (session.states.Network.resources) |*r| r else return session.fail("No resource with given identifier found");
    const id = fetch_observer.parseRequestId(session, params.requestId) orelse return session.fail("No resource with given identifier found");
    switch (resources.body(id)) {
        .unknown => return session.fail("No resource with given identifier found"),
        .evicted => return session.fail("Request content was evicted from inspector cache"),
        .none => return session.fail("No data found for resource with given identifier"),
        .content => |c| {
            const reported = try network_resources.reportedBody(session.arena.?, c.bytes, c.resource.mime_type, c.resource.charset);
            return .{ .body = reported.text, .base64Encoded = reported.base64 };
        },
    }
}

/// Blink's InspectorNetworkAgent::getRequestPostData, its messages: the
/// body as sent, UTF-8 text or base64.
pub fn getRequestPostData(session: *PageSession, params: N.getRequestPostData.Params) !N.getRequestPostData.Result {
    const resources = if (session.states.Network.resources) |*r| r else return session.fail("No resource with given id was found");
    const id = fetch_observer.parseRequestId(session, params.requestId) orelse return session.fail("No resource with given id was found");
    var known = false;
    const data = resources.postData(id, &known);
    if (!known) return session.fail("No resource with given id was found");
    const bytes = data orelse return session.fail("No post data available for the request");
    if (bytes.len == 0) return session.fail("No post data available for the request");
    const reported = try network_resources.reportedPostData(session.arena.?, bytes);
    return .{ .postData = reported.text, .base64Encoded = reported.base64 };
}

/// Chrome's NetworkHandler::SetUserAgentOverride: the tab's user agent, as
/// Emulation.setUserAgentOverride sets it (the same host override: Chrome
/// applies both to the tab's requests and navigator).
pub fn setUserAgentOverride(session: *PageSession, params: N.setUserAgentOverride.Params) !N.setUserAgentOverride.Result {
    const bc = frames.navigable(session, session.tab) orelse return session.fail("Target is not a page");
    try bc.host_overrides.setUserAgent(bc.allocator, @intFromPtr(session), params.userAgent, params.platform, params.acceptLanguage);
    return .{};
}

/// Blink's InspectorNetworkAgent::overrideNetworkState: the network state
/// the page sees - navigator.onLine, and navigator.connection, which Crane
/// does not have (Chrome alone ships the Network Information API). Online is
/// what every Crane tab is; offline needs lane mcp1 batch 4b item 7 and is
/// refused until it lands.
pub fn overrideNetworkState(session: *PageSession, params: N.overrideNetworkState.Params) !N.overrideNetworkState.Result {
    if (params.offline) return session.fail("Network emulation is not supported by Crane yet");
    return .{};
}

/// Chrome's NetworkHandler::EmulateNetworkConditionsByRule
/// (content/browser/devtools/protocol/network_handler.cc): a rule id per
/// condition (base::UnguessableToken, 32 uppercase hex digits). Conditions
/// that throttle nothing - online, no latency, no throughput limit (a
/// throughput of 0 or less is none) - are what every Crane tab has;
/// Puppeteer sends them on every emulate. Any other needs lane mcp1 batch 4b
/// item 7 and is refused until it lands.
pub fn emulateNetworkConditionsByRule(session: *PageSession, params: N.emulateNetworkConditionsByRule.Params) !N.emulateNetworkConditionsByRule.Result {
    if (params.offline orelse false) return session.fail("Network emulation is not supported by Crane yet");
    for (params.matchedNetworkConditions) |c| {
        const throttles = (c.offline orelse false) or c.latency > 0 or c.downloadThroughput > 0 or c.uploadThroughput > 0 or (c.packetLoss orelse 0) > 0;
        if (throttles) return session.fail("Network emulation is not supported by Crane yet");
    }
    const arena = session.arena.?;
    const ids = try arena.alloc([]const u8, params.matchedNetworkConditions.len);
    for (ids) |*id| {
        var bytes: [16]u8 = undefined;
        @import("platform").fillRandom(&bytes);
        const hex = std.fmt.bytesToHex(bytes, .upper);
        id.* = try arena.dupe(u8, &hex);
    }
    return .{ .ruleIds = ids };
}

/// Chrome's NetworkHandler::SetExtraHTTPHeaders (network_handler.cc;
/// reproduced, BSD - algorithm only): each value a string ("Invalid header
/// value, string expected"), each name a token (net::HttpUtil::
/// IsValidHeaderName: "Invalid header name"), each value free of NUL, CR
/// and LF (IsValidHeaderValue: "Invalid header value"); then they replace
/// the session's set - none clears it - which, while Network is enabled,
/// every request of its tab's documents carries (fetch_job's start, before
/// CORS; Blink's InspectorNetworkAgent::PrepareRequest).
pub fn setExtraHTTPHeaders(session: *PageSession, params: N.setExtraHTTPHeaders.Params) !N.setExtraHTTPHeaders.Result {
    if (frames.navigable(session, session.tab) == null) return session.fail("Target is not a page");
    if (params.headers != .object) return session.failWithCode(.invalid_params, "Invalid parameters");
    const arena = session.arena.?;
    var list: std.ArrayList(host_overrides.ExtraHeader) = .empty;
    var it = params.headers.object.iterator();
    while (it.next()) |entry| {
        const value = entry.value_ptr.*;
        if (value != .string) return session.failWithCode(.invalid_params, "Invalid header value, string expected");
        if (!validHeaderName(entry.key_ptr.*)) return session.failWithCode(.invalid_params, "Invalid header name");
        if (!validHeaderValue(value.string)) return session.failWithCode(.invalid_params, "Invalid header value");
        try list.append(arena, .{ .name = entry.key_ptr.*, .value = value.string });
    }
    // The session's copy, replacing the one it had.
    const allocator = session.allocator;
    const copy = try allocator.alloc(host_overrides.ExtraHeader, list.items.len);
    @memset(copy, .{ .name = "", .value = "" });
    errdefer {
        for (copy) |header| {
            allocator.free(header.name);
            allocator.free(header.value);
        }
        allocator.free(copy);
    }
    for (list.items, copy) |from, *to| {
        to.name = try allocator.dupe(u8, from.name);
        to.value = try allocator.dupe(u8, from.value);
    }
    freeHeaders(session);
    session.states.Network.extra_headers = copy;
    if (session.states.Network.enabled) try applyHeaders(session);
    return .{};
}

const host_overrides = @import("html").window.host_overrides;

/// net::HttpUtil::IsValidHeaderName: a non-empty RFC 7230 token.
fn validHeaderName(name: []const u8) bool {
    if (name.len == 0) return false;
    for (name) |c| switch (c) {
        '!', '#', '$', '%', '&', '\'', '*', '+', '-', '.', '^', '_', '`', '|', '~' => {},
        else => if (!std.ascii.isAlphanumeric(c)) return false,
    };
    return true;
}

/// net::HttpUtil::IsValidHeaderValue: no NUL, CR or LF.
fn validHeaderValue(value: []const u8) bool {
    for (value) |c| if (c == 0 or c == '\r' or c == '\n') return false;
    return true;
}
