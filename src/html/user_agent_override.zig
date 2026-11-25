//! The user agent override a request sends: the reader fetch's
//! http_fetch.userAgentOverrideOf asks (lane cdpt's hook; fetch sits below
//! HTML and cannot read a tab), installed once at process start. A Window
//! client's tab's override is read live from its top-level traversable
//! (html_core.window.host_overrides, which CDP's Emulation and Network
//! setUserAgentOverride and WebDriver BiDi's emulation set) - Chrome applies
//! the tab's override to each request the page makes
//! (content/browser/devtools/protocol/emulation_handler.cc ApplyOverrides,
//! Blink's InspectorEmulationAgent::PrepareRequest). A dedicated worker's
//! requests send the copy it took as it was made (html.worker_host:
//! DedicatedWorker::CreateGlobalScopeCreationParams copies the owner's user
//! agent, WorkerFetchContext::PrepareRequest sends it). Lane cdph.

const std = @import("std");
const runtime = @import("runtime");
const http_fetch = @import("fetch").algorithms.http_fetch;
const worker_host = @import("worker_host.zig");

/// Install the reader, once, at process start (src/browser/process.zig).
pub fn installHooks() void {
    http_fetch.installUserAgentOverrideReader(&read);
}

/// The override for a request whose client is `client`: a Window (its
/// traversable for user prompts stands in for it) or a worker global (the
/// request's user agent client). On the client's thread; the strings are
/// BORROWED for the request's step.
fn read(client: *anyopaque) http_fetch.UserAgentOverride {
    const global: *runtime.Instance = @ptrCast(@alignCast(client));
    if (std.mem.eql(u8, global.vtable.name, "Window")) {
        const bc = @import("dom").browser_state.browsingContextOf(global) orelse return .{};
        const overrides = &bc.getTop().host_overrides;
        return .{ .user_agent = overrides.user_agent, .accept_language = overrides.accept_language, .extra_headers = overrides.extra_headers };
    }
    const snapshot = worker_host.userAgentOverrideOfRealm(global.ctx) orelse return .{};
    return .{ .user_agent = snapshot.user_agent, .accept_language = snapshot.accept_language };
}

/// The override of the tab `navigable` is in - its top-level traversable's
/// - for a navigation's request to copy as it is made
/// (InternalRequest.setOverrideSnapshot; Chrome applies DevTools overrides
/// to a navigation once, at its start, keyed by its frame:
/// devtools_instrumentation.cc ApplyNetworkRequestOverrides). BORROWED
/// until the tab's overrides next change; on the navigable's thread.
pub fn ofNavigable(navigable: *@import("dom").browser_state.BrowsingContext) http_fetch.UserAgentOverride {
    const overrides = &navigable.getTop().host_overrides;
    return .{ .user_agent = overrides.user_agent, .accept_language = overrides.accept_language, .extra_headers = overrides.extra_headers };
}

/// The override a request whose client is `realm`'s global sends, for a
/// request made now and fetched elsewhere to copy (a dedicated or shared
/// worker's script request, made on its creator's thread): a Window's
/// tab's, or a worker's copy of its tab's user agent (no extra headers - a
/// worker's own requests carry none of the page session's). BORROWED, as
/// `ofNavigable`; on `realm`'s thread.
pub fn ofRealm(realm: runtime.Context) http_fetch.UserAgentOverride {
    const record = realm.getRealm() orelse return .{};
    return read(record.global_object orelse return .{});
}
