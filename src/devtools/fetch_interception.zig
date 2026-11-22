//! Fetch interception for a Browser's page sessions (CDP part 1 gap 1 and
//! lane cdpr's G17; tmp/plans/cdp-part1-design.md 3.10): Fetch.requestPaused
//! at the REQUEST stage (before HTTP-network fetch hands the request to the
//! network) and the RESPONSE stage (the network's answer, before Fetch reads
//! it), Fetch.authRequired at HTTP-network-or-cache fetch's prompt, for
//! EVERY fetch of the window agent - the event loop's (AsyncFetch) and the
//! blocking one's (a synchronous XMLHttpRequest, a classic script's
//! synchronous fetch) alike.
//!
//! Chrome's model, reproduced (content/browser/devtools/protocol/
//! fetch_handler.cc and devtools_url_loader_interceptor.cc, BSD-3): the
//! FetchHandler and its interceptor live in the BROWSER process, below the
//! page, so a renderer blocked in a synchronous XHR is still answered. Here
//! the holds are in one table per Browser (`Table`, locked), written by the
//! Browser thread when a fetch is held and read by the DEVTOOLS thread,
//! which answers Fetch.continueRequest, fulfillRequest, failRequest,
//! continueResponse, continueWithAuth and getResponseBody itself
//! (server.zig): a blocking fetch's hold is decided there and then - its
//! thread waits for it (observer.Interception.any_thread) - an event loop
//! fetch's decision is posted to the Browser thread as a task, where the
//! hold is looked up again (the fetch may have gone meanwhile: dropped, as
//! one waiting for its transfer is).
//!
//! Ids are Chrome's: "interception-job-<job>.<hop>", one job per request (the
//! same id at its request, response and auth stages), its hop counting the
//! redirects it followed (InterceptionJob's id_seq_ and redirect_count_).
//! Holders chain as Chrome's per-session interceptors do: each session whose
//! patterns take a request holds it in turn, at the request stage.

const std = @import("std");
const Allocator = std.mem.Allocator;
const fetch = @import("fetch");
const protocol = @import("protocol/root.zig");
const ids = @import("ids.zig");
const dispatch = @import("dispatch.zig");
const host_bridge = @import("host_bridge.zig");
const browser_side = @import("browser_side.zig");
const fetch_observer = @import("fetch_observer.zig");
const PageSession = @import("page_session.zig").PageSession;
const fetch_domain = @import("domains/fetch.zig");
const TombstoneGuard = @import("infra").tombstones.TombstoneGuard;

const BrowserSide = browser_side.BrowserSide;
const observer = fetch.network.observer;
const InternalRequest = fetch.internal.InternalRequest;
const N = protocol.Network;
const F = protocol.Fetch;

const log = std.log.scoped(.devtools);

/// One held request.
pub const Paused = struct {
    interception: observer.Interception,
    /// Its holder (compared, never dereferenced, off the Browser thread).
    session: *PageSession,
    /// The redirects its fetch followed before this hold.
    hop: u32,
    /// The holder's patterns asked for its response stage
    /// (getResponseBody's first refusal).
    response_stage_requested: bool,
    /// An event loop fetch's decision is on its way to the Browser thread.
    deciding: bool = false,
};

/// A Browser's held requests, by job. Any thread: every access holds the
/// mutex, never across a call into a fetch or a reply.
pub const Table = struct {
    mutex: std.Io.Mutex = .init,
    paused: std.AutoHashMapUnmanaged(u64, Paused) = .empty,
    /// continueRequest's interceptResponse, by request id: whether the
    /// deciding session holds that request's response whatever its
    /// patterns say (written by the devtools thread, read at the response
    /// stage on the Browser thread).
    response_overrides: std.AutoHashMapUnmanaged(u64, ResponseOverride) = .empty,
    /// Jobs and requests come and go for the remote end's life on the
    /// Browser.
    paused_guard: TombstoneGuard = .{},
    response_overrides_guard: TombstoneGuard = .{},

    fn lock(self: *Table) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
    }

    fn unlock(self: *Table) void {
        std.Io.Threaded.mutexUnlock(&self.mutex);
    }

    fn put(self: *Table, allocator: Allocator, job: u64, paused: Paused) bool {
        self.lock();
        defer self.unlock();
        self.paused_guard.beforeInsert(&self.paused);
        self.paused.put(allocator, job, paused) catch return false;
        return true;
    }

    /// Remove and return the hold of `job` (locked by the caller).
    fn takeLocked(self: *Table, job: u64) ?Paused {
        const removed = self.paused.fetchRemove(job) orelse return null;
        self.paused_guard.noteRemoval(&self.paused);
        return removed.value;
    }

    pub fn deinit(self: *Table, allocator: Allocator) void {
        self.paused.deinit(allocator);
        self.response_overrides.deinit(allocator);
        self.* = .{};
    }
};

pub const ResponseOverride = struct {
    /// Compared only.
    session: *PageSession,
    intercept: bool,
};

/// The request ended: what was kept for it goes (Browser thread).
pub fn forget(side: *BrowserSide, request_id: u64) void {
    const table = &side.interceptions;
    table.lock();
    defer table.unlock();
    if (table.response_overrides.remove(request_id)) table.response_overrides_guard.noteRemoval(&table.response_overrides);
}

/// continueRequest's interceptResponse for `request_id`, taken (Browser
/// thread, at the response stage).
fn takeResponseOverride(side: *BrowserSide, request_id: u64) ?ResponseOverride {
    const table = &side.interceptions;
    table.lock();
    defer table.unlock();
    const removed = table.response_overrides.fetchRemove(request_id) orelse return null;
    table.response_overrides_guard.noteRemoval(&table.response_overrides);
    return removed.value;
}

// ============================================================================
// Ids
// ============================================================================

pub const Id = struct { job: u64, hop: u32 };

/// Chrome's interception ids: "interception-job-<n>.<redirects>".
pub fn idText(id: Id, buffer: *[48]u8) []const u8 {
    return std.fmt.bufPrint(buffer, "interception-job-{d}.{d}", .{ id.job, id.hop }) catch "";
}

pub fn parseId(text: []const u8) ?Id {
    const prefix = "interception-job-";
    if (!std.mem.startsWith(u8, text, prefix)) return null;
    const rest = text[prefix.len..];
    const dot = std.mem.indexOfScalar(u8, rest, '.') orelse return null;
    const job = std.fmt.parseInt(u64, rest[0..dot], 10) catch return null;
    const hop = std.fmt.parseInt(u32, rest[dot + 1 ..], 10) catch return null;
    return .{ .job = job, .hop = hop };
}

// ============================================================================
// Holding (the Browser thread: the observer's calls)
// ============================================================================

fn patternTakes(pattern: fetch_domain.Pattern, url: []const u8, resource_type: N.ResourceType) bool {
    if (pattern.resource_type) |t| if (t != resource_type) return false;
    return wildcardMatch(pattern.url_pattern, url);
}

/// Whether `session`'s patterns take `url` at `stage`.
fn sessionTakes(session: *PageSession, url: []const u8, resource_type: N.ResourceType, stage: fetch_domain.PatternStage) bool {
    const state = &session.states.Fetch;
    if (!state.enabled) return false;
    for (state.patterns.items) |pattern| {
        if (pattern.stage == stage and patternTakes(pattern, url, resource_type)) return true;
    }
    return false;
}

/// Chrome matches the URL without its fragment
/// (NetworkHandler::ExtractFragment before base::MatchPattern).
fn matchedUrl(request: *const InternalRequest) []const u8 {
    const url = request.currentUrl();
    return if (std.mem.indexOfScalar(u8, url, '#')) |at| url[0..at] else url;
}

/// The request's job (assigned at its first hold) and hop.
fn jobOf(side: *BrowserSide, request: *const InternalRequest) ?Id {
    const info = fetch_observer.requestInfo(side, request.request_id) orelse return null;
    if (info.job == 0) {
        info.job = side.fetch_state.next_job;
        side.fetch_state.next_job += 1;
    }
    return .{ .job = info.job, .hop = info.hop };
}

pub fn interceptRequest(context: *anyopaque, request: *const InternalRequest, network_request: *const fetch.network.NetworkRequest, interception: observer.Interception) bool {
    const side = fetch_observer.sideOf(context) orelse return false;
    const who = fetch_observer.attribute(side, request) orelse return false;
    const resource_type = fetch_observer.resourceTypeOf(request);
    const url = matchedUrl(request);
    // The `chain`-th session whose request-stage patterns take it: the ones
    // before let it go already.
    var skip = interception.chain;
    const holder = for (side.sessions.items) |s| {
        if (s.tab != who.tab or !sessionTakes(s, url, resource_type, .request)) continue;
        if (skip > 0) {
            skip -= 1;
            continue;
        }
        break s;
    } else return false;
    const id = jobOf(side, request) orelse return false;
    if (!side.interceptions.put(side.allocator, id.job, .{
        .interception = interception,
        .session = holder,
        .hop = id.hop,
        .response_stage_requested = sessionTakes(holder, url, resource_type, .response),
    })) return false;
    emitPaused(side, holder, who, request, network_request, id, null);
    return true;
}

pub fn interceptResponse(context: *anyopaque, request: *const InternalRequest, network_request: *const fetch.network.NetworkRequest, answer: observer.NetworkAnswer, interception: observer.Interception) bool {
    const side = fetch_observer.sideOf(context) orelse return false;
    const who = fetch_observer.attribute(side, request) orelse return false;
    const resource_type = fetch_observer.resourceTypeOf(request);
    const url = matchedUrl(request);
    // The session whose response-stage patterns take it - or whose
    // continueRequest said interceptResponse true; one that said false lets
    // it go (FetchHandler ContinueRequest's interceptResponse override).
    const override = takeResponseOverride(side, request.request_id);
    const holder = for (side.sessions.items) |s| {
        if (s.tab != who.tab or !s.states.Fetch.enabled) continue;
        if (override) |o| if (o.session == s) {
            if (o.intercept) break s;
            continue;
        };
        if (sessionTakes(s, url, resource_type, .response)) break s;
    } else return false;
    const id = jobOf(side, request) orelse return false;
    if (!side.interceptions.put(side.allocator, id.job, .{
        .interception = interception,
        .session = holder,
        .hop = id.hop,
        .response_stage_requested = true,
    })) return false;
    emitPaused(side, holder, who, request, network_request, id, answer);
    return true;
}

pub fn interceptAuth(context: *anyopaque, request: *const InternalRequest, challenge: *const observer.AuthChallenge, interception: observer.Interception) bool {
    const side = fetch_observer.sideOf(context) orelse return false;
    const who = fetch_observer.attribute(side, request) orelse return false;
    const resource_type = fetch_observer.resourceTypeOf(request);
    const url = matchedUrl(request);
    // A session handling auth whose patterns take the request at any stage
    // (Chrome raises authRequired for a job its interceptor made).
    const holder = for (side.sessions.items) |s| {
        if (s.tab != who.tab or !s.states.Fetch.enabled or !s.states.Fetch.handle_auth) continue;
        if (sessionTakes(s, url, resource_type, .request) or sessionTakes(s, url, resource_type, .response)) break s;
    } else return false;
    const id = jobOf(side, request) orelse return false;
    if (!side.interceptions.put(side.allocator, id.job, .{
        .interception = interception,
        .session = holder,
        .hop = id.hop,
        .response_stage_requested = false,
    })) return false;
    var arena_state = std.heap.ArenaAllocator.init(side.allocator);
    defer arena_state.deinit();
    const n_request = fetch_observer.requestOf(arena_state.allocator(), request, 0) catch return true;
    var id_buffer: [48]u8 = undefined;
    var frame_buffer: [32]u8 = ids.frameId(side.token, who.frame).text;
    holder.emit(F.authRequired, .{
        .requestId = idText(id, &id_buffer),
        .request = n_request,
        .frameId = &frame_buffer,
        .resourceType = resource_type,
        .authChallenge = .{
            .source = switch (challenge.source) {
                .server => .Server,
                .proxy => .Proxy,
            },
            .origin = challenge.origin,
            .scheme = challenge.scheme,
            .realm = challenge.realm,
        },
    });
    return true;
}

/// Fetch.requestPaused (request stage: `answer` null; response stage: its
/// status, text and headers, or its error).
fn emitPaused(side: *BrowserSide, holder: *PageSession, who: fetch_observer.Attribution, request: *const InternalRequest, network_request: *const fetch.network.NetworkRequest, id: Id, answer: ?observer.NetworkAnswer) void {
    var arena_state = std.heap.ArenaAllocator.init(side.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var n_request = fetch_observer.requestOf(arena, request, 0) catch return;
    // What a holder before this one changed (chained sessions) is the
    // request this one sees.
    const sent_url = network_request.url;
    const hash = std.mem.indexOfScalar(u8, sent_url, '#');
    n_request.url = if (hash) |at| sent_url[0..at] else sent_url;
    n_request.method = network_request.method;
    var id_buffer: [48]u8 = undefined;
    var network_buffer: [48]u8 = undefined;
    var frame_buffer: [32]u8 = ids.frameId(side.token, who.frame).text;
    var params: F.requestPaused.Params = .{
        .requestId = idText(id, &id_buffer),
        .request = n_request,
        .frameId = &frame_buffer,
        .resourceType = fetch_observer.resourceTypeOf(request),
        .networkId = fetch_observer.requestIdText(holder, request.request_id, &network_buffer),
    };
    if (answer) |a| switch (a) {
        .response => |response| {
            params.responseStatusCode = response.status;
            params.responseStatusText = if (response.status_message.len > 0) response.status_message else reasonPhrase(response.status);
            const entries = arena.alloc(F.HeaderEntry, response.headers.len) catch return;
            for (response.headers, 0..) |h, i| entries[i] = .{ .name = h.name, .value = h.value };
            params.responseHeaders = entries;
        },
        .failed => |err| params.responseErrorReason = errorReasonOf(err),
    };
    holder.emit(F.requestPaused, params);
}

pub fn interceptionDropped(context: *anyopaque, request_id: u64) void {
    const side = fetch_observer.sideOf(context) orelse return;
    const table = &side.interceptions;
    table.lock();
    defer table.unlock();
    var it = table.paused.iterator();
    while (it.next()) |e| {
        if (e.value_ptr.interception.request_id != request_id) continue;
        _ = table.takeLocked(e.key_ptr.*);
        return;
    }
}

/// Every hold `holder` has (any holder: null) that `which` admits, taken off
/// the table and let go as if never held - Chrome's interceptor Detach: a
/// paused request is continued unchanged, a paused auth challenge gets the
/// default. `which`: .any (the Browser thread: Fetch.disable, a session's
/// end), .blocking (the devtools thread, for holds whose fetch's thread
/// waits: a detach or a stop while the Browser thread is blocked).
pub fn release(side: *BrowserSide, holder: ?*PageSession, which: enum { any, blocking }) void {
    const table = &side.interceptions;
    while (true) {
        table.lock();
        var found: ?Paused = null;
        var it = table.paused.iterator();
        while (it.next()) |e| {
            if (holder) |h| if (e.value_ptr.session != h) continue;
            if (which == .blocking and !e.value_ptr.interception.any_thread) continue;
            if (e.value_ptr.deciding) continue;
            found = table.takeLocked(e.key_ptr.*);
            break;
        }
        table.unlock();
        const paused = found orelse return;
        paused.interception.decide(.{ .@"continue" = .{} });
    }
}

// ============================================================================
// Deciding (the devtools thread: server.zig hands these commands here)
// ============================================================================

const invalid_id = "Invalid InterceptionId.";

/// The Fetch commands the devtools thread answers (Chrome's browser-side
/// FetchHandler): never queued behind the page, which a synchronous fetch
/// may hold.
pub fn isDevtoolsThreadCommand(method: []const u8) bool {
    const names = [_][]const u8{
        F.continueRequest.method,  F.fulfillRequest.method,   F.failRequest.method,
        F.continueResponse.method, F.continueWithAuth.method, F.getResponseBody.method,
    };
    for (names) |n| if (std.mem.eql(u8, n, method)) return true;
    return false;
}

/// What deciding found.
pub const Outcome = union(enum) {
    ok,
    /// The command's error: its code and Chrome's message.
    failed: struct { code: dispatch.Code, message: []const u8 },
};

fn fail(code: dispatch.Code, message: []const u8) Outcome {
    return .{ .failed = .{ .code = code, .message = message } };
}

/// Decide `id_text`'s hold for `holder` with `decision` (BORROWED; copied
/// for an event loop fetch's task).
pub fn decide(side: *BrowserSide, holder: *PageSession, id_text: []const u8, decision: observer.Decision, intercept_response: ?bool) Outcome {
    if (!holder.fetch_enabled.load(.acquire)) return fail(.server_error, "Fetch domain is not enabled");
    const id = parseId(id_text) orelse return fail(.invalid_params, invalid_id);
    const table = &side.interceptions;
    table.lock();
    const entry = table.paused.getPtr(id.job) orelse {
        table.unlock();
        return fail(.invalid_params, invalid_id);
    };
    if (entry.session != holder or entry.hop != id.hop or entry.deciding) {
        table.unlock();
        return fail(.invalid_params, invalid_id);
    }
    // InterceptionJob::InnerContinueRequest's stage checks.
    const at_auth = entry.interception.stage == .auth;
    if (at_auth and decision != .auth) {
        table.unlock();
        return fail(.invalid_params, "authChallengeResponse required.");
    }
    if (!at_auth and decision == .auth) {
        table.unlock();
        return fail(.invalid_params, "authChallengeResponse not expected.");
    }
    // continueRequest's interceptResponse, for this request's response.
    if (intercept_response) |intercept| {
        table.response_overrides_guard.beforeInsert(&table.response_overrides);
        table.response_overrides.put(side.allocator, entry.interception.request_id, .{ .session = holder, .intercept = intercept }) catch {
            table.unlock();
            return fail(.internal_error, "Out of memory");
        };
    }
    if (entry.interception.any_thread) {
        // The fetch's thread waits for this: decided here, its data copied
        // before decide returns.
        const paused = table.takeLocked(id.job).?;
        table.unlock();
        paused.interception.decide(decision);
        return .ok;
    }
    const task = DecisionTask.make(side, id.job, decision) catch {
        table.unlock();
        return fail(.internal_error, "Out of memory");
    };
    entry.deciding = true;
    table.unlock();
    task.post();
    return .ok;
}

/// An event loop fetch's decision, carried to the Browser thread.
const DecisionTask = struct {
    side: *BrowserSide,
    job: u64,
    arena: std.heap.ArenaAllocator,
    decision: observer.Decision,

    fn make(side: *BrowserSide, job: u64, decision: observer.Decision) Allocator.Error!*DecisionTask {
        const task = try side.allocator.create(DecisionTask);
        errdefer side.allocator.destroy(task);
        task.* = .{ .side = side, .job = job, .arena = std.heap.ArenaAllocator.init(side.allocator), .decision = undefined };
        errdefer task.arena.deinit();
        task.decision = try observer.copyDecision(task.arena.allocator(), decision);
        return task;
    }

    fn post(self: *DecisionTask) void {
        _ = self.side.host.post(self, run, drop);
    }

    fn run(context: ?*anyopaque, _: *host_bridge.Browser) void {
        const self: *DecisionTask = @ptrCast(@alignCast(context.?));
        defer self.free();
        const table = &self.side.interceptions;
        table.lock();
        // Gone meanwhile (its fetch dropped): nothing to decide.
        const paused: ?Paused = if (table.paused.get(self.job)) |p| (if (p.deciding) table.takeLocked(self.job) else null) else null;
        table.unlock();
        if (paused) |p| p.interception.decide(self.decision);
    }

    fn drop(context: ?*anyopaque) void {
        const self: *DecisionTask = @ptrCast(@alignCast(context.?));
        self.free();
    }

    fn free(self: *DecisionTask) void {
        self.arena.deinit();
        self.side.allocator.destroy(self);
    }
};

/// Fetch.getResponseBody: the held response's whole body, always base64
/// (InterceptionJob's BodyReader: "encoded_body_ = base::Base64Encode(...);
/// cb->sendSuccess(encoded_body_, true)"), answered through `reply` - now
/// for a blocking fetch's (its body is here), from the Browser thread once
/// the body has arrived for an event loop fetch's.
pub fn getResponseBody(side: *BrowserSide, holder: *PageSession, id_text: []const u8, reply: dispatch.Reply(F.getResponseBody)) void {
    if (!holder.fetch_enabled.load(.acquire)) return reply.fail(.server_error, "Fetch domain is not enabled");
    const id = parseId(id_text) orelse return reply.fail(.invalid_params, invalid_id);
    const table = &side.interceptions;
    table.lock();
    const entry = table.paused.getPtr(id.job) orelse {
        table.unlock();
        return reply.fail(.invalid_params, invalid_id);
    };
    if (entry.session != holder or entry.hop != id.hop) {
        table.unlock();
        return reply.fail(.invalid_params, invalid_id);
    }
    if (!entry.response_stage_requested) {
        table.unlock();
        return reply.fail(.server_error, "Can only get response body on HeadersReceived pattern matched requests.");
    }
    if (entry.interception.stage != .response or entry.deciding) {
        table.unlock();
        return reply.fail(.server_error, "Can only get response body on requests captured after headers received.");
    }
    const task = BodyTask.make(side, id.job, reply) catch {
        table.unlock();
        return reply.fail(.internal_error, "Out of memory");
    };
    if (entry.interception.any_thread) {
        // Under the lock: the waiting fetch cannot be decided meanwhile, and
        // its body is all here (the reader is called at once).
        _ = entry.interception.readBody(task.reader());
        table.unlock();
        return;
    }
    table.unlock();
    _ = side.host.post(task, BodyTask.run, BodyTask.drop);
}

const BodyTask = struct {
    side: *BrowserSide,
    job: u64,
    reply: dispatch.Reply(F.getResponseBody),
    answered: bool = false,

    fn make(side: *BrowserSide, job: u64, reply: dispatch.Reply(F.getResponseBody)) Allocator.Error!*BodyTask {
        const task = try side.allocator.create(BodyTask);
        task.* = .{ .side = side, .job = job, .reply = reply };
        return task;
    }

    fn reader(self: *BodyTask) observer.BodyReader {
        return .{ .context = self, .done = done };
    }

    /// Browser thread: the hold read, if it is still there.
    fn run(context: ?*anyopaque, _: *host_bridge.Browser) void {
        const self: *BodyTask = @ptrCast(@alignCast(context.?));
        const table = &self.side.interceptions;
        table.lock();
        const interception: ?observer.Interception = if (table.paused.get(self.job)) |p| (if (!p.deciding and p.interception.stage == .response) p.interception else null) else null;
        table.unlock();
        const held = interception orelse {
            self.reply.fail(.invalid_params, invalid_id);
            return self.side.allocator.destroy(self);
        };
        if (!held.readBody(self.reader())) {
            self.reply.fail(.server_error, "Can only get response body on requests captured after headers received.");
            self.side.allocator.destroy(self);
        }
    }

    fn drop(context: ?*anyopaque) void {
        const self: *BodyTask = @ptrCast(@alignCast(context.?));
        self.reply.drop();
        self.side.allocator.destroy(self);
    }

    fn done(context: *anyopaque, body: ?[]const u8) void {
        const self: *BodyTask = @ptrCast(@alignCast(context));
        defer self.side.allocator.destroy(self);
        const bytes = body orelse return self.reply.fail(.server_error, "Failed to read response body");
        const encoded = @import("network_resources.zig").base64(self.side.allocator, bytes) catch return self.reply.fail(.internal_error, "Out of memory");
        defer self.side.allocator.free(encoded);
        self.reply.ok(.{ .body = encoded, .base64Encoded = true });
    }
};

// ============================================================================
// Helpers
// ============================================================================

/// Fetch's urlPattern (FetchHandler: base::MatchPattern): `*` any run of
/// characters, `?` one, `\` escaping either.
pub fn wildcardMatch(pattern: []const u8, text: []const u8) bool {
    var p: usize = 0;
    var t: usize = 0;
    var star: ?usize = null;
    var star_t: usize = 0;
    while (t < text.len) {
        if (p < pattern.len and pattern[p] == '\\' and p + 1 < pattern.len) {
            if (pattern[p + 1] == text[t]) {
                p += 2;
                t += 1;
                continue;
            }
        } else if (p < pattern.len and (pattern[p] == '?' or pattern[p] == text[t]) and pattern[p] != '*') {
            p += 1;
            t += 1;
            continue;
        } else if (p < pattern.len and pattern[p] == '*') {
            star = p;
            star_t = t;
            p += 1;
            continue;
        }
        const s = star orelse return false;
        p = s + 1;
        star_t += 1;
        t = star_t;
    }
    while (p < pattern.len and pattern[p] == '*') p += 1;
    return p == pattern.len;
}

/// The standard reason phrase of `status` (net's GetHttpReasonPhrase), for
/// requestPaused's responseStatusText of an HTTP/2 response, which has none.
pub fn reasonPhrase(status: u16) []const u8 {
    return switch (status) {
        100 => "Continue",
        101 => "Switching Protocols",
        103 => "Early Hints",
        200 => "OK",
        201 => "Created",
        202 => "Accepted",
        203 => "Non-Authoritative Information",
        204 => "No Content",
        205 => "Reset Content",
        206 => "Partial Content",
        300 => "Multiple Choices",
        301 => "Moved Permanently",
        302 => "Found",
        303 => "See Other",
        304 => "Not Modified",
        305 => "Use Proxy",
        307 => "Temporary Redirect",
        308 => "Permanent Redirect",
        400 => "Bad Request",
        401 => "Unauthorized",
        402 => "Payment Required",
        403 => "Forbidden",
        404 => "Not Found",
        405 => "Method Not Allowed",
        406 => "Not Acceptable",
        407 => "Proxy Authentication Required",
        408 => "Request Timeout",
        409 => "Conflict",
        410 => "Gone",
        411 => "Length Required",
        412 => "Precondition Failed",
        413 => "Request Entity Too Large",
        414 => "Request-URI Too Long",
        415 => "Unsupported Media Type",
        416 => "Requested Range Not Satisfiable",
        417 => "Expectation Failed",
        418 => "I'm a teapot",
        421 => "Misdirected Request",
        425 => "Too Early",
        426 => "Upgrade Required",
        428 => "Precondition Required",
        429 => "Too Many Requests",
        431 => "Request Header Fields Too Large",
        451 => "Unavailable For Legal Reasons",
        500 => "Internal Server Error",
        501 => "Not Implemented",
        502 => "Bad Gateway",
        503 => "Service Unavailable",
        504 => "Gateway Timeout",
        505 => "HTTP Version Not Supported",
        else => "",
    };
}

/// CDP's Network.ErrorReason of a network error.
fn errorReasonOf(err: fetch.network.NetworkError) N.ErrorReason {
    return switch (err) {
        error.DnsResolutionFailed => .NameNotResolved,
        error.ConnectionRefused => .ConnectionRefused,
        error.ConnectionTimeout, error.RequestTimeout => .TimedOut,
        error.ConnectionReset => .ConnectionReset,
        error.NetworkUnreachable => .InternetDisconnected,
        error.HostUnreachable => .AddressUnreachable,
        error.Aborted => .Aborted,
        else => .Failed,
    };
}

test "wildcardMatch: Fetch's urlPattern" {
    try std.testing.expect(wildcardMatch("*", "https://a.test/x"));
    try std.testing.expect(wildcardMatch("https://a.test/*", "https://a.test/x/y"));
    try std.testing.expect(!wildcardMatch("https://b.test/*", "https://a.test/x"));
    try std.testing.expect(wildcardMatch("*.js", "https://a.test/app.js"));
    try std.testing.expect(wildcardMatch("https://a.test/?", "https://a.test/x"));
    try std.testing.expect(wildcardMatch("https://a.test/\\*", "https://a.test/*"));
    try std.testing.expect(!wildcardMatch("https://a.test/\\*", "https://a.test/x"));
}

test "interception ids round-trip in Chrome's form, with the redirect count" {
    var buffer: [48]u8 = undefined;
    const text = idText(.{ .job = 42, .hop = 0 }, &buffer);
    try std.testing.expectEqualStrings("interception-job-42.0", text);
    try std.testing.expectEqual(Id{ .job = 42, .hop = 0 }, parseId(text).?);
    try std.testing.expectEqual(Id{ .job = 7, .hop = 2 }, parseId("interception-job-7.2").?);
    try std.testing.expect(parseId("nope") == null);
    try std.testing.expect(parseId("interception-job-1") == null);
}

test "the Fetch commands the devtools thread answers" {
    try std.testing.expect(isDevtoolsThreadCommand("Fetch.continueRequest"));
    try std.testing.expect(isDevtoolsThreadCommand("Fetch.getResponseBody"));
    try std.testing.expect(!isDevtoolsThreadCommand("Fetch.enable"));
    try std.testing.expect(!isDevtoolsThreadCommand("Fetch.disable"));
}
