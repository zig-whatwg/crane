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
/// Until lane cdpt's hook (943c446da) is on this tree there is nothing to
/// install into.
pub fn installHooks() void {
    if (comptime @hasDecl(http_fetch, "installUserAgentOverrideReader")) http_fetch.installUserAgentOverrideReader(&read);
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
        return .{ .user_agent = overrides.user_agent, .accept_language = overrides.accept_language };
    }
    const snapshot = worker_host.userAgentOverrideOfRealm(global.ctx) orelse return .{};
    return .{ .user_agent = snapshot.user_agent, .accept_language = snapshot.accept_language };
}
