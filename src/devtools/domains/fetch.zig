//! The Fetch domain on page sessions (tmp/plans/cdp-part1-design.md 3.10):
//! request interception. Fetch.enable's patterns decide which of the tab's
//! requests the Browser's fetch observer holds at HTTP-network fetch's hand
//! over to the network - where Chrome's DevToolsURLLoaderInterceptor holds
//! them (content/browser/devtools/devtools_url_loader_interceptor.cc), below
//! the page and its service worker - and Fetch.requestPaused announces each;
//! continueRequest, fulfillRequest and failRequest answer it
//! (fetch_observer.zig `decide`). Response-stage interception
//! (requestStage "Response") holds nothing in part 1.

const std = @import("std");
const fetch = @import("fetch");
const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");
const fetch_observer = @import("../fetch_observer.zig");

const F = protocol.Fetch;
const N = protocol.Network;
const observer = fetch.network.observer;

/// A RequestPattern, OWNED.
pub const Pattern = struct {
    url_pattern: []u8,
    resource_type: ?N.ResourceType,
    request_stage: ?F.RequestStage,
};

/// Per-session state of the domain.
pub const State = struct {
    enabled: bool = false,
    patterns: std.ArrayList(Pattern) = .empty,
};

fn clearPatterns(session: *PageSession) void {
    const state = &session.states.Fetch;
    for (state.patterns.items) |p| session.allocator.free(p.url_pattern);
    state.patterns.deinit(session.allocator);
    state.* = .{};
}

/// Fetch.enable: with no patterns, every request at the request stage
/// (protocol: "If not set, all requests will be affected").
pub fn enable(session: *PageSession, params: F.enable.Params) !F.enable.Result {
    clearPatterns(session);
    const state = &session.states.Fetch;
    const given = params.patterns orelse &[_]F.RequestPattern{.{}};
    for (given) |p| {
        const url = try session.allocator.dupe(u8, p.urlPattern orelse "*");
        errdefer session.allocator.free(url);
        try state.patterns.append(session.allocator, .{ .url_pattern = url, .resource_type = p.resourceType, .request_stage = p.requestStage });
    }
    state.enabled = true;
    return .{};
}

/// Fetch.disable: what the session holds goes on as it was.
pub fn disable(session: *PageSession, _: F.disable.Params) !F.disable.Result {
    fetch_observer.releaseHeldBy(session);
    clearPatterns(session);
    return .{};
}

pub fn sessionEnded(session: *PageSession) void {
    fetch_observer.releaseHeldBy(session);
    clearPatterns(session);
}

/// A base64 field's bytes, in the command's arena (Fetch's postData and
/// body are base64, as their protocol type `binary` says).
fn decodeBase64(session: *PageSession, text: []const u8) ![]const u8 {
    const arena = session.arena.?;
    const decoder = std.base64.standard.Decoder;
    const size = decoder.calcSizeForSlice(text) catch return session.failWithCode(.invalid_params, "Invalid base64 data");
    const out = try arena.alloc(u8, size);
    decoder.decode(out, text) catch return session.failWithCode(.invalid_params, "Invalid base64 data");
    return out;
}

const invalid_id = "Invalid InterceptionId.";

pub fn continueRequest(session: *PageSession, params: F.continueRequest.Params) !F.continueRequest.Result {
    const arena = session.arena.?;
    var overrides: observer.Overrides = .{ .url = params.url, .method = params.method };
    if (params.postData) |data| overrides.body = try decodeBase64(session, data);
    if (params.headers) |headers| {
        const list = try arena.alloc(fetch.network.NetworkRequest.Header, headers.len);
        for (headers, 0..) |h, i| list[i] = .{ .name = h.name, .value = h.value };
        overrides.headers = list;
    }
    if (!fetch_observer.decide(session, params.requestId, .{ .@"continue" = overrides })) return session.failWithCode(.invalid_params, invalid_id);
    return .{};
}

pub fn fulfillRequest(session: *PageSession, params: F.fulfillRequest.Params) !F.fulfillRequest.Result {
    const arena = session.arena.?;
    var headers: std.ArrayList(fetch.network.NetworkResponse.Header) = .empty;
    if (params.responseHeaders) |given| {
        for (given) |h| try headers.append(arena, .{ .name = h.name, .value = h.value });
    } else if (params.binaryResponseHeaders) |binary| {
        // NUL-separated "name: value" lines, base64.
        const raw = try decodeBase64(session, binary);
        var it = std.mem.splitScalar(u8, raw, 0);
        while (it.next()) |line| {
            const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
            try headers.append(arena, .{ .name = std.mem.trim(u8, line[0..colon], " "), .value = std.mem.trim(u8, line[colon + 1 ..], " ") });
        }
    }
    if (params.responseCode < 100 or params.responseCode > 999) return session.failWithCode(.invalid_params, "Invalid http status code or phrase");
    const body = if (params.body) |b| try decodeBase64(session, b) else "";
    const decision: observer.Decision = .{ .fulfill = .{
        .status = @intCast(params.responseCode),
        .status_message = params.responsePhrase orelse "",
        .headers = headers.items,
        .body = body,
    } };
    if (!fetch_observer.decide(session, params.requestId, decision)) return session.failWithCode(.invalid_params, invalid_id);
    return .{};
}

pub fn failRequest(session: *PageSession, params: F.failRequest.Params) !F.failRequest.Result {
    const reason: observer.FailReason = switch (params.errorReason) {
        .Failed => .failed,
        .Aborted => .aborted,
        .TimedOut => .timed_out,
        .AccessDenied => .access_denied,
        .ConnectionClosed => .connection_closed,
        .ConnectionReset => .connection_reset,
        .ConnectionRefused => .connection_refused,
        .ConnectionAborted => .connection_aborted,
        .ConnectionFailed => .connection_failed,
        .NameNotResolved => .name_not_resolved,
        .InternetDisconnected => .internet_disconnected,
        .AddressUnreachable => .address_unreachable,
        .BlockedByClient => .blocked_by_client,
        .BlockedByResponse => .blocked_by_response,
    };
    if (!fetch_observer.decide(session, params.requestId, .{ .fail = reason })) return session.failWithCode(.invalid_params, invalid_id);
    return .{};
}
