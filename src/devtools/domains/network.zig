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
};

fn clear(session: *PageSession) void {
    const state = &session.states.Network;
    if (state.resources) |*r| r.deinit();
    state.* = .{};
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
    return .{};
}

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
