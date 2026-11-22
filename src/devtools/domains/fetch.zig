//! The Fetch domain (tmp/plans/cdp-part1-design.md 3.10): request
//! interception at the request stage, the response stage and the auth
//! challenge (fetch_interception.zig holds the requests).
//!
//! Chrome's FetchHandler is the model (content/browser/devtools/protocol/
//! fetch_handler.cc, BSD-3; its messages): it lives in the browser process,
//! below the page. Here Fetch.enable and Fetch.disable run on the page
//! session (the Browser thread: they set the patterns its fetches are
//! matched against), and the commands that answer a held request -
//! continueRequest, fulfillRequest, failRequest, continueResponse,
//! continueWithAuth, getResponseBody - run on the DEVTOOLS thread
//! (`DevtoolsThread`, dispatched by server.zig), so a page blocked in a
//! synchronous fetch is still answered, as Chrome answers one while its
//! renderer waits.

const std = @import("std");
const fetch = @import("fetch");
const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");
const fetch_interception = @import("../fetch_interception.zig");
const targets = @import("../targets.zig");
const dispatch = @import("../dispatch.zig");
const Reply = dispatch.Reply;

const F = protocol.Fetch;
const N = protocol.Network;
const observer = fetch.network.observer;

pub const PatternStage = enum { request, response };

/// A RequestPattern, OWNED.
pub const Pattern = struct {
    url_pattern: []u8,
    resource_type: ?N.ResourceType,
    stage: PatternStage,
};

/// Per-session state of the domain (the Browser thread's; the devtools
/// thread reads only `PageSession.fetch_enabled`).
pub const State = struct {
    enabled: bool = false,
    /// Fetch.enable's handleAuthRequests: Fetch.authRequired is raised.
    handle_auth: bool = false,
    patterns: std.ArrayList(Pattern) = .empty,
};

fn clearPatterns(session: *PageSession) void {
    const state = &session.states.Fetch;
    for (state.patterns.items) |p| session.allocator.free(p.url_pattern);
    state.patterns.deinit(session.allocator);
    state.* = .{};
    session.fetch_enabled.store(false, .release);
}

/// FetchHandler::Enable (ToInterceptionPatterns): no patterns is "*" at
/// the request stage; an empty list with handleAuthRequests is refused.
pub fn enable(session: *PageSession, params: F.enable.Params) !F.enable.Result {
    const handle_auth = params.handleAuthRequests orelse false;
    if (params.patterns) |given| if (given.len == 0 and handle_auth) {
        return session.failWithCode(.invalid_params, "Can't specify empty patterns with handleAuth set");
    };
    clearPatterns(session);
    const state = &session.states.Fetch;
    const given = params.patterns orelse &[_]F.RequestPattern{.{}};
    errdefer clearPatterns(session);
    for (given) |p| {
        const url = try session.allocator.dupe(u8, p.urlPattern orelse "*");
        errdefer session.allocator.free(url);
        const stage: PatternStage = if (p.requestStage) |s| switch (s) {
            .Request => .request,
            .Response => .response,
        } else .request;
        try state.patterns.append(session.allocator, .{ .url_pattern = url, .resource_type = p.resourceType, .stage = stage });
    }
    state.enabled = true;
    state.handle_auth = handle_auth;
    session.fetch_enabled.store(true, .release);
    return .{};
}

/// Fetch.disable: what the session holds goes on as it was (the
/// interceptor's Detach: continued unchanged, an auth challenge defaulted).
pub fn disable(session: *PageSession, _: F.disable.Params) !F.disable.Result {
    if (session.side) |side| fetch_interception.release(side, session, .any);
    clearPatterns(session);
    return .{};
}

pub fn sessionEnded(session: *PageSession) void {
    if (session.side) |side| fetch_interception.release(side, session, .any);
    clearPatterns(session);
}

/// The commands the devtools thread answers, on the target's session
/// (targets.Session: its `page` is the holder the table names).
pub const DevtoolsThread = struct {
    fn sideAndPage(session: *targets.Session) ?struct { side: *@import("../browser_side.zig").BrowserSide, page: *PageSession } {
        const page = session.page orelse return null;
        const target = session.target orelse return null;
        return .{ .side = target.context.side, .page = page };
    }

    fn answer(session: *targets.Session, outcome: fetch_interception.Outcome) !void {
        switch (outcome) {
            .ok => {},
            .failed => |f| return session.failWithCode(f.code, f.message),
        }
    }

    /// A base64 field's bytes, in the command's arena (Fetch's postData and
    /// body are protocol `binary`).
    fn decodeBase64(session: *targets.Session, text: []const u8) ![]const u8 {
        const arena = session.arena.?;
        const decoder = std.base64.standard.Decoder;
        const size = decoder.calcSizeForSlice(text) catch return session.failWithCode(.invalid_params, "Invalid base64 data");
        const out = try arena.alloc(u8, size);
        decoder.decode(out, text) catch return session.failWithCode(.invalid_params, "Invalid base64 data");
        return out;
    }

    /// FetchHandler's ValidateHeaders: a header's name is an HTTP token, its
    /// value has no CR, LF or NUL ("Invalid header: <name>").
    fn validHeader(name: []const u8, value: []const u8) bool {
        if (name.len == 0) return false;
        for (name) |c| switch (c) {
            '!', '#', '$', '%', '&', '\'', '*', '+', '-', '.', '^', '_', '`', '|', '~', '0'...'9', 'a'...'z', 'A'...'Z' => {},
            else => return false,
        };
        for (value) |c| if (c == '\r' or c == '\n' or c == 0) return false;
        return true;
    }

    fn invalidHeader(session: *targets.Session, name: []const u8) error{Protocol} {
        var buffer: [256]u8 = undefined;
        const message = std.fmt.bufPrint(&buffer, "Invalid header: {s}", .{name}) catch "Invalid header";
        return session.failWithCode(.invalid_params, message);
    }

    pub fn continueRequest(session: *targets.Session, params: F.continueRequest.Params) !F.continueRequest.Result {
        const held = sideAndPage(session) orelse return session.fail("Fetch domain is not enabled");
        const arena = session.arena.?;
        var overrides: observer.Overrides = .{ .url = params.url, .method = params.method };
        if (params.postData) |data| overrides.body = try decodeBase64(session, data);
        if (params.headers) |headers| {
            const list = try arena.alloc(fetch.network.NetworkRequest.Header, headers.len);
            for (headers, 0..) |h, i| {
                if (!validHeader(h.name, h.value)) return invalidHeader(session, h.name);
                list[i] = .{ .name = h.name, .value = h.value };
            }
            overrides.headers = list;
        }
        try answer(session, fetch_interception.decide(held.side, held.page, params.requestId, .{ .@"continue" = overrides }, params.interceptResponse));
        return .{};
    }

    /// FetchHandler::FulfillRequest: the phrase given or the code's
    /// standard one; one of responseHeaders and binaryResponseHeaders.
    pub fn fulfillRequest(session: *targets.Session, params: F.fulfillRequest.Params) !F.fulfillRequest.Result {
        const held = sideAndPage(session) orelse return session.fail("Fetch domain is not enabled");
        const fulfillment = try fulfillmentOf(session, params.responseCode, params.responsePhrase, params.responseHeaders, params.binaryResponseHeaders);
        var with_body = fulfillment;
        with_body.body = if (params.body) |b| try decodeBase64(session, b) else null;
        try answer(session, fetch_interception.decide(held.side, held.page, params.requestId, .{ .fulfill = with_body }, null));
        return .{};
    }

    fn fulfillmentOf(session: *targets.Session, code: i64, phrase: ?[]const u8, response_headers: ?[]const F.HeaderEntry, binary: ?[]const u8) !observer.Fulfillment {
        const arena = session.arena.?;
        const status_phrase = phrase orelse (if (code >= 0 and code <= 999) fetch_interception.reasonPhrase(@intCast(code)) else "");
        if (status_phrase.len == 0 or code < 0 or code > 999) return session.failWithCode(.invalid_params, "Invalid http status code or phrase");
        var headers: std.ArrayList(fetch.network.NetworkResponse.Header) = .empty;
        if (response_headers) |given| {
            if (binary != null) return session.failWithCode(.invalid_params, "Only one of responseHeaders or binaryHeaders may be present");
            for (given) |h| {
                if (!validHeader(h.name, h.value)) return invalidHeader(session, h.name);
                try headers.append(arena, .{ .name = h.name, .value = h.value });
            }
        } else if (binary) |encoded| {
            // NUL-separated "name: value" lines.
            const raw = try decodeBase64(session, encoded);
            var it = std.mem.splitScalar(u8, raw, 0);
            while (it.next()) |line| {
                const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
                try headers.append(arena, .{ .name = std.mem.trim(u8, line[0..colon], " "), .value = std.mem.trim(u8, line[colon + 1 ..], " ") });
            }
        }
        return .{ .status = @intCast(code), .status_message = status_phrase, .headers = headers.items, .body = null };
    }

    pub fn failRequest(session: *targets.Session, params: F.failRequest.Params) !F.failRequest.Result {
        const held = sideAndPage(session) orelse return session.fail("Fetch domain is not enabled");
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
        try answer(session, fetch_interception.decide(held.side, held.page, params.requestId, .{ .fail = reason }, null));
        return .{};
    }

    /// FetchHandler::ContinueResponse: a code with headers is a fulfill
    /// keeping the original body; nothing changed is a plain continue;
    /// anything else is refused.
    pub fn continueResponse(session: *targets.Session, params: F.continueResponse.Params) !F.continueResponse.Result {
        const held = sideAndPage(session) orelse return session.fail("Fetch domain is not enabled");
        const has_headers = params.responseHeaders != null or params.binaryResponseHeaders != null;
        if (params.responseCode != null and has_headers) {
            const fulfillment = try fulfillmentOf(session, params.responseCode.?, params.responsePhrase, params.responseHeaders, params.binaryResponseHeaders);
            try answer(session, fetch_interception.decide(held.side, held.page, params.requestId, .{ .fulfill = fulfillment }, null));
            return .{};
        }
        if (params.responseCode == null and params.responsePhrase == null and !has_headers) {
            try answer(session, fetch_interception.decide(held.side, held.page, params.requestId, .{ .@"continue" = .{} }, null));
            return .{};
        }
        return session.fail("Cannot override only status or headers, both should be provided");
    }

    /// The answer to a Fetch.authRequired.
    pub fn continueWithAuth(session: *targets.Session, params: F.continueWithAuth.Params) !F.continueWithAuth.Result {
        const held = sideAndPage(session) orelse return session.fail("Fetch domain is not enabled");
        const response = params.authChallengeResponse;
        const auth: observer.AuthAnswer = switch (response.response) {
            .Default => .default,
            .CancelAuth => .cancel,
            .ProvideCredentials => .{ .provide = .{ .username = response.username orelse "", .password = response.password orelse "" } },
        };
        try answer(session, fetch_interception.decide(held.side, held.page, params.requestId, .{ .auth = auth }, null));
        return .{};
    }

    pub fn getResponseBody(session: *targets.Session, params: F.getResponseBody.Params, reply: Reply(F.getResponseBody)) !void {
        const held = sideAndPage(session) orelse return session.fail("Fetch domain is not enabled");
        fetch_interception.getResponseBody(held.side, held.page, params.requestId, reply);
    }
};

test "a header's name is a token and its value has no CR, LF or NUL" {
    try std.testing.expect(DevtoolsThread.validHeader("x-crane", "yes"));
    try std.testing.expect(!DevtoolsThread.validHeader("bad name", "v"));
    try std.testing.expect(!DevtoolsThread.validHeader("x", "a\r\nb"));
    try std.testing.expect(!DevtoolsThread.validHeader("", "v"));
}
