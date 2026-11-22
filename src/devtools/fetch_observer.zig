//! The remote end's fetch observer: Network events and Fetch interception
//! for a Browser's page sessions (tmp/plans/cdp-part1-design.md 3.9-3.10).
//!
//! Installed on the Browser's network context (fetch.network.observer, the
//! generic slot) while the remote end is on the Browser (BrowserSide), it
//! turns Fetch's steps into Network.requestWillBeSent, responseReceived,
//! loadingFinished, loadingFailed and requestServedFromCache for every page
//! session of the request's tab with Network enabled - Blink's
//! InspectorNetworkAgent at its probe points (third_party/blink/renderer/
//! core/inspector/inspector_network_agent.cc WillSendRequest,
//! DidReceiveResourceResponse, DidFinishLoading, DidFailLoading) - and holds
//! a request a session's Fetch patterns match (Fetch.requestPaused) until
//! the session continues, fulfills or fails it, as Chrome's
//! DevToolsURLLoaderInterceptor does in the network service.
//!
//! Only the window agent's fetches are reported: a worker's go to its worker
//! target in Chrome, and part 1 reports no worker targets (decision D10). Its
//! observer calls come on the worker's thread and are ignored here.
//!
//! Ids: a navigation's request is named by its navigation id (its loaderId
//! too, both as the 32-hex token Chrome prints); any other request by a
//! counter of the Browser's, printed as Chrome prints a renderer's request
//! ids ("<n>.<counter>"). A request's loaderId is its document's: the
//! navigation id that committed it (lane life1's N4, kept here from the
//! `committed` milestones).

const std = @import("std");
const Allocator = std.mem.Allocator;
const fetch = @import("fetch");
const dom = @import("dom");
const html = @import("html");
const platform = @import("platform");
const runtime = @import("runtime");
const protocol = @import("protocol/root.zig");
const ids = @import("ids.zig");
const host_bridge = @import("host_bridge.zig");
const BrowserSide = @import("browser_side.zig").BrowserSide;
const PageSession = @import("page_session.zig").PageSession;

const observer = fetch.network.observer;
const InternalRequest = fetch.internal.InternalRequest;
const InternalResponse = fetch.internal.InternalResponse;
const N = protocol.Network;
const F = protocol.Fetch;

const log = std.log.scoped(.devtools);

/// The high bit marks a request id that is a counter, not a navigation id.
const counter_bit: u64 = 1 << 63;

/// What the observer keeps of a Browser, on its window thread.
pub const State = struct {
    next_request: u64 = 1,
    next_interception: u64 = 1,
    /// Navigation id -> the navigable it navigates (`started` milestones).
    navigations: std.AutoHashMapUnmanaged(u64, u64) = .empty,
    /// A committed document (by address) -> its loader.
    documents: std.AutoHashMapUnmanaged(usize, DocumentLoader) = .empty,
    /// A redirect's response, kept from redirect_received to the next
    /// will_send_request of the same fetch.
    redirects: std.AutoHashMapUnmanaged(u64, Head) = .empty,
    /// Requests a session holds (Fetch.requestPaused), by interception id.
    paused: std.AutoHashMapUnmanaged(u64, Paused) = .empty,
    /// Each navigable's subresource fetches in flight (Page.lifecycleEvent's
    /// networkAlmostIdle / networkIdle: Blink's IdlenessDetector counts a
    /// frame's active requests), and which navigable each counted request is
    /// a fetch of.
    in_flight: std.AutoHashMapUnmanaged(u64, u32) = .empty,
    counted: std.AutoHashMapUnmanaged(u64, u64) = .empty,

    pub fn deinit(self: *State, allocator: Allocator) void {
        self.navigations.deinit(allocator);
        var docs = self.documents.valueIterator();
        while (docs.next()) |d| allocator.free(d.url);
        self.documents.deinit(allocator);
        var heads = self.redirects.valueIterator();
        while (heads.next()) |h| h.deinit(allocator);
        self.redirects.deinit(allocator);
        // A held request whose session went: it is sent as it was.
        var held = self.paused.valueIterator();
        while (held.next()) |p| p.interception.decide(.{ .@"continue" = .{} });
        self.paused.deinit(allocator);
        self.in_flight.deinit(allocator);
        self.counted.deinit(allocator);
    }
};

/// `navigable`'s subresource fetches in flight now.
pub fn inFlight(side: *BrowserSide, navigable: u64) u32 {
    return side.fetch_state.in_flight.get(navigable) orelse 0;
}

/// A navigable's in-flight count moved: every page session of its tab hears
/// it (`onNetworkActivity(session, navigable_id, in_flight)` in a handler
/// module - Page's lifecycle events networkAlmostIdle at 2 or fewer and
/// networkIdle at 0, each after its quiet period, as Blink's
/// IdlenessDetector).
fn countInFlight(side: *BrowserSide, tab: u64, navigable: u64, delta: i32) void {
    const state = &side.fetch_state;
    const entry = state.in_flight.getOrPut(side.allocator, navigable) catch return;
    if (!entry.found_existing) entry.value_ptr.* = 0;
    if (delta > 0) entry.value_ptr.* += 1 else entry.value_ptr.* -|= 1;
    const now = entry.value_ptr.*;
    if (now == 0) _ = state.in_flight.remove(navigable);
    const page_domains = @import("domains/page_domains.zig");
    var buffer: [16]*PageSession = undefined;
    var n: usize = 0;
    for (side.sessions.items) |s| {
        if (s.tab != tab or n == buffer.len) continue;
        buffer[n] = s;
        n += 1;
    }
    for (buffer[0..n]) |s| {
        inline for (@typeInfo(page_domains.Handlers).@"struct".decl_names) |name| {
            const H = @field(page_domains.Handlers, name);
            if (comptime @hasDecl(H, "onNetworkActivity")) H.onNetworkActivity(s, navigable, now);
        }
    }
}

const DocumentLoader = struct {
    generation: u64,
    navigation_id: u64,
    /// OWNED.
    url: []u8,
};

/// A response's head, OWNED copies.
const Head = struct {
    url: []u8,
    status: u16,
    status_text: []u8,
    headers: std.json.ObjectMap,
    mime_type: []u8,

    fn of(allocator: Allocator, response: *const InternalResponse) !Head {
        var headers: std.json.ObjectMap = .empty;
        errdefer freeHeaders(allocator, &headers);
        for (response.header_list.entries.items) |h| try putHeader(allocator, &headers, h.name, h.value);
        const url = try allocator.dupe(u8, if (response.url_list.items.len > 0) response.url_list.items[response.url_list.items.len - 1] else "");
        errdefer allocator.free(url);
        const status_text = try allocator.dupe(u8, response.status_message);
        errdefer allocator.free(status_text);
        const content_type = headers.get("content-type") orelse headers.get("Content-Type");
        const mime = if (content_type) |v| essence(v.string) else "";
        return .{ .url = url, .status = response.status, .status_text = status_text, .headers = headers, .mime_type = try allocator.dupe(u8, mime) };
    }

    fn deinit(self: *Head, allocator: Allocator) void {
        allocator.free(self.url);
        allocator.free(self.status_text);
        allocator.free(self.mime_type);
        freeHeaders(allocator, &self.headers);
    }

    fn toResponse(self: *const Head, encoded_length: f64) N.Response {
        return .{
            .url = self.url,
            .status = self.status,
            .statusText = self.status_text,
            .headers = .{ .object = self.headers },
            .mimeType = self.mime_type,
            .charset = "",
            .connectionReused = false,
            .connectionId = 0,
            .encodedDataLength = encoded_length,
            .securityState = securityStateOf(self.url),
            .protocol = "http/1.1",
        };
    }
};

const Paused = struct {
    interception: observer.Interception,
    /// The session that holds it (BORROWED: cleared when it detaches).
    session: *PageSession,
};

fn freeHeaders(allocator: Allocator, headers: *std.json.ObjectMap) void {
    var it = headers.iterator();
    while (it.next()) |e| {
        allocator.free(e.key_ptr.*);
        allocator.free(e.value_ptr.string);
    }
    headers.deinit(allocator);
}

/// Headers as CDP's Network.Headers object: a name seen twice is joined
/// with "\n", as Chrome's HeadersToDictionary joins them.
fn putHeader(allocator: Allocator, headers: *std.json.ObjectMap, name: []const u8, value: []const u8) !void {
    if (headers.getPtr(name)) |existing| {
        const joined = try std.mem.concat(allocator, u8, &.{ existing.string, "\n", value });
        allocator.free(existing.string);
        existing.* = .{ .string = joined };
        return;
    }
    const key = try allocator.dupe(u8, name);
    errdefer allocator.free(key);
    const copy = try allocator.dupe(u8, value);
    errdefer allocator.free(copy);
    try headers.put(allocator, key, .{ .string = copy });
}

fn essence(content_type: []const u8) []const u8 {
    const end = std.mem.indexOfScalar(u8, content_type, ';') orelse content_type.len;
    return std.mem.trim(u8, content_type[0..end], " \t");
}

fn securityStateOf(url: []const u8) protocol.Security.SecurityState {
    if (std.mem.startsWith(u8, url, "https:") or std.mem.startsWith(u8, url, "wss:")) return .secure;
    if (std.mem.startsWith(u8, url, "http:") or std.mem.startsWith(u8, url, "ws:")) return .insecure;
    return .neutral;
}

fn monotonicSeconds() f64 {
    return @as(f64, @floatFromInt(platform.monotonicNow().ns)) / std.time.ns_per_s;
}

fn wallSeconds() f64 {
    return @as(f64, @floatFromInt(platform.wallNow().ns_since_epoch)) / std.time.ns_per_s;
}

/// The Observer for `side`'s network context.
pub fn observerFor(side: *BrowserSide) observer.Observer {
    return .{
        .context = side,
        .will_send_request = willSendRequest,
        .redirect_received = redirectReceived,
        .served_from_cache = servedFromCache,
        .response_received = responseReceived,
        .loading_finished = loadingFinished,
        .loading_failed = loadingFailed,
        .intercept_request = interceptRequest,
        .interception_dropped = interceptionDropped,
        .bypass_cache = bypassCache,
    };
}

fn sideOf(context: *anyopaque) ?*BrowserSide {
    const side: *BrowserSide = @ptrCast(@alignCast(context));
    // Only the window agent's fetches (decision D10).
    if (!side.host.isBrowserThread()) return null;
    return side;
}

// ----------------------------------------------------------------------------
// Milestones: which navigable a navigation is, which navigation a document's
// ----------------------------------------------------------------------------

/// BrowserSide's fan-out hands every milestone here first.
pub fn onMilestone(side: *BrowserSide, milestone: *const host_bridge.Milestone) void {
    const state = &side.fetch_state;
    switch (milestone.event) {
        .started => if (milestone.navigation_id != 0) {
            state.navigations.put(side.allocator, milestone.navigation_id, milestone.navigable_id) catch {};
        },
        .committed => |c| {
            const url = side.allocator.dupe(u8, c.url) catch return;
            const key = @intFromPtr(c.document.document);
            const entry = state.documents.getOrPut(side.allocator, key) catch {
                side.allocator.free(url);
                return;
            };
            if (entry.found_existing) side.allocator.free(entry.value_ptr.url);
            entry.value_ptr.* = .{ .generation = c.document.generation, .navigation_id = milestone.navigation_id, .url = url };
            _ = state.navigations.remove(milestone.navigation_id);
        },
        .aborted => _ = state.navigations.remove(milestone.navigation_id),
        else => {},
    }
}

/// Whom a request is for: its tab, frame, document's loader and URL.
const Attribution = struct {
    tab: u64,
    frame: u64,
    loader: u64,
    document_url: []const u8,
};

fn attribute(side: *BrowserSide, request: *const InternalRequest) ?Attribution {
    const navigables = dom.browser_state.existingNavigablesIn(side.browser.?.scope) orelse return null;
    if (request.navigation_id != 0) {
        const navigable_id = side.fetch_state.navigations.get(request.navigation_id) orelse return null;
        const bc = navigables.byId(navigable_id) orelse return null;
        return .{ .tab = bc.getTop().id, .frame = bc.id, .loader = request.navigation_id, .document_url = request.currentUrl() };
    }
    const window_ptr = switch (request.traversable_for_user_prompts) {
        .traversable => |t| t,
        else => return null,
    };
    const window: *runtime.Instance = @ptrCast(@alignCast(window_ptr));
    const bc = dom.browser_state.browsingContextOf(window) orelse return null;
    var loader: u64 = 0;
    var document_url: []const u8 = "";
    if (bc.getActiveDocument()) |document| {
        if (side.fetch_state.documents.get(@intFromPtr(document))) |d| {
            if (d.generation == runtime.SlabAllocator.generationOf(@ptrCast(@alignCast(document)))) {
                loader = d.navigation_id;
                document_url = d.url;
            }
        }
    }
    return .{ .tab = bc.getTop().id, .frame = bc.id, .loader = loader, .document_url = document_url };
}

/// The Network.RequestId text of `id`.
fn requestIdText(side: *const BrowserSide, id: u64, buffer: *[48]u8) []const u8 {
    if (id & counter_bit != 0) {
        return std.fmt.bufPrint(buffer, "{d}.{d}", .{ side.token % 100000, id & ~counter_bit }) catch "";
    }
    const token = ids.Token.of(side.token, id);
    @memcpy(buffer[0..32], token.slice());
    return buffer[0..32];
}

fn loaderText(side: *const BrowserSide, loader: u64, buffer: *[32]u8) []const u8 {
    const token = ids.Token.of(side.token, loader);
    buffer.* = token.text;
    return buffer;
}

fn resourceTypeOf(request: *const InternalRequest) N.ResourceType {
    if (request.mode == .navigate) return .Document;
    if (request.initiator_type) |t| switch (t) {
        .xmlhttprequest => return .XHR,
        .fetch => return .Fetch,
        .beacon, .ping => return .Ping,
        else => {},
    };
    return switch (request.destination) {
        .document, .iframe, .frame => .Document,
        .style => .Stylesheet,
        .image => .Image,
        .audio, .video => .Media,
        .font => .Font,
        .script, .worker, .sharedworker, .serviceworker, .audioworklet, .paintworklet => .Script,
        .track => .TextTrack,
        .manifest => .Manifest,
        .report => .CSPViolationReport,
        .empty => .Fetch,
        else => .Other,
    };
}

fn referrerPolicyOf(request: *const InternalRequest) @FieldType(N.Request, "referrerPolicy") {
    return switch (request.referrer_policy) {
        .no_referrer => .@"no-referrer",
        .no_referrer_when_downgrade => .@"no-referrer-when-downgrade",
        .same_origin => .@"same-origin",
        .origin => .origin,
        .strict_origin => .@"strict-origin",
        .origin_when_cross_origin => .@"origin-when-cross-origin",
        .unsafe_url => .@"unsafe-url",
        // The empty policy is the default: strict-origin-when-cross-origin.
        .empty, .strict_origin_when_cross_origin => .@"strict-origin-when-cross-origin",
    };
}

/// The Network.Request of `request`, its headers in `arena`.
fn requestOf(arena: Allocator, request: *const InternalRequest) !N.Request {
    var headers: std.json.ObjectMap = .empty;
    for (request.header_list.entries.items) |h| try putHeader(arena, &headers, h.name, h.value);
    const url = request.currentUrl();
    const hash = std.mem.indexOfScalar(u8, url, '#');
    return .{
        .url = if (hash) |at| url[0..at] else url,
        .urlFragment = if (hash) |at| url[at..] else null,
        .method = request.method,
        .headers = .{ .object = headers },
        .initialPriority = if (request.mode == .navigate or request.destination == .style) .VeryHigh else if (request.destination == .script) .High else .Low,
        .referrerPolicy = referrerPolicyOf(request),
        .hasPostData = if (request.body != null) true else null,
    };
}

/// Every attached page session of `tab` with `enabled(session)`, into
/// `out`.
fn sessionsWith(side: *BrowserSide, tab: u64, comptime field: []const u8, out: []*PageSession) []*PageSession {
    var n: usize = 0;
    for (side.sessions.items) |s| {
        if (s.tab != tab) continue;
        if (!@field(s.states, field).enabled) continue;
        if (n == out.len) break;
        out[n] = s;
        n += 1;
    }
    return out[0..n];
}

// ----------------------------------------------------------------------------
// The observer's calls
// ----------------------------------------------------------------------------

fn willSendRequest(context: *anyopaque, request: *const InternalRequest) u64 {
    const side = sideOf(context) orelse return 0;
    const id = if (request.request_id != 0)
        request.request_id
    else if (request.navigation_id != 0)
        request.navigation_id
    else blk: {
        const n = side.fetch_state.next_request;
        side.fetch_state.next_request += 1;
        break :blk n | counter_bit;
    };
    const who = attribute(side, request) orelse return id;
    // A subresource fetch's first hop: one more in flight for its frame.
    if (request.request_id == 0 and request.navigation_id == 0) {
        if (side.fetch_state.counted.put(side.allocator, id, who.frame)) |_| {
            countInFlight(side, who.tab, who.frame, 1);
        } else |_| {}
    }
    var buffer: [16]*PageSession = undefined;
    const sessions = sessionsWith(side, who.tab, "Network", &buffer);
    var redirect = side.fetch_state.redirects.fetchRemove(id);
    defer if (redirect) |*r| r.value.deinit(side.allocator);
    if (sessions.len == 0) return id;

    var arena_state = std.heap.ArenaAllocator.init(side.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const n_request = requestOf(arena, request) catch return id;
    var id_buffer: [48]u8 = undefined;
    var loader_buffer: [32]u8 = undefined;
    var frame_buffer: [32]u8 = undefined;
    const frame = ids.frameId(side.token, who.frame);
    frame_buffer = frame.text;
    const params: N.requestWillBeSent.Params = .{
        .requestId = requestIdText(side, id, &id_buffer),
        .loaderId = loaderText(side, who.loader, &loader_buffer),
        .documentURL = who.document_url,
        .request = n_request,
        .timestamp = monotonicSeconds(),
        .wallTime = wallSeconds(),
        .initiator = .{ .type = if (request.mode == .navigate) .other else if (request.parser_metadata == .parser_inserted) .parser else .script },
        .redirectHasExtraInfo = false,
        .redirectResponse = if (redirect) |*r| r.value.toResponse(0) else null,
        .type = resourceTypeOf(request),
        .frameId = &frame_buffer,
        .hasUserGesture = request.user_activation,
    };
    for (sessions) |s| s.emit(N.requestWillBeSent, params);
    return id;
}

fn redirectReceived(context: *anyopaque, request: *const InternalRequest, response: *const InternalResponse) void {
    const side = sideOf(context) orelse return;
    if (request.request_id == 0) return;
    const head = Head.of(side.allocator, response) catch return;
    const entry = side.fetch_state.redirects.getOrPut(side.allocator, request.request_id) catch {
        var h = head;
        h.deinit(side.allocator);
        return;
    };
    if (entry.found_existing) entry.value_ptr.deinit(side.allocator);
    entry.value_ptr.* = head;
}

fn servedFromCache(context: *anyopaque, request: *const InternalRequest) void {
    const side = sideOf(context) orelse return;
    const who = attribute(side, request) orelse return;
    var buffer: [16]*PageSession = undefined;
    var id_buffer: [48]u8 = undefined;
    for (sessionsWith(side, who.tab, "Network", &buffer)) |s| {
        s.emit(N.requestServedFromCache, .{ .requestId = requestIdText(side, request.request_id, &id_buffer) });
    }
}

fn responseReceived(context: *anyopaque, request: *const InternalRequest, response: *const InternalResponse) void {
    const side = sideOf(context) orelse return;
    const who = attribute(side, request) orelse return;
    // Log.entryAdded "Failed to load resource: the server responded with a
    // status of N (text)" for the tab's Log sessions (lane cdph's
    // domains/log.zig; Blink's ResourceLoadObserverForFrame::
    // DidReceiveResponse, status >= 400) - whether or not Network is on.
    if (response.status >= 400) {
        var log_id_buffer: [48]u8 = undefined;
        @import("domains/log.zig").errorResponse(side, who.tab, request.getUrl(), requestIdText(side, request.request_id, &log_id_buffer), response.status, response.status_message);
    }
    var buffer: [16]*PageSession = undefined;
    const sessions = sessionsWith(side, who.tab, "Network", &buffer);
    if (sessions.len == 0) return;
    var head = Head.of(side.allocator, response) catch return;
    defer head.deinit(side.allocator);
    var id_buffer: [48]u8 = undefined;
    var loader_buffer: [32]u8 = undefined;
    var frame_buffer: [32]u8 = ids.frameId(side.token, who.frame).text;
    const params: N.responseReceived.Params = .{
        .requestId = requestIdText(side, request.request_id, &id_buffer),
        .loaderId = loaderText(side, who.loader, &loader_buffer),
        .timestamp = monotonicSeconds(),
        .type = resourceTypeOf(request),
        .response = head.toResponse(0),
        .hasExtraInfo = false,
        .frameId = &frame_buffer,
    };
    for (sessions) |s| s.emit(N.responseReceived, params);
}

/// A counted fetch ended: one fewer in flight for its frame.
fn uncount(side: *BrowserSide, request: *const InternalRequest, tab: u64) void {
    const removed = side.fetch_state.counted.fetchRemove(request.request_id) orelse return;
    countInFlight(side, tab, removed.value, -1);
}

fn loadingFinished(context: *anyopaque, request: *const InternalRequest, encoded_length: u64) void {
    const side = sideOf(context) orelse return;
    const who = attribute(side, request) orelse return;
    uncount(side, request, who.tab);
    var buffer: [16]*PageSession = undefined;
    var id_buffer: [48]u8 = undefined;
    for (sessionsWith(side, who.tab, "Network", &buffer)) |s| {
        s.emit(N.loadingFinished, .{
            .requestId = requestIdText(side, request.request_id, &id_buffer),
            .timestamp = monotonicSeconds(),
            .encodedDataLength = @floatFromInt(encoded_length),
        });
    }
}

fn loadingFailed(context: *anyopaque, request: *const InternalRequest, error_text: []const u8, canceled: bool) void {
    const side = sideOf(context) orelse return;
    const who = attribute(side, request) orelse {
        // Its frame went: the count goes with the frame.
        _ = side.fetch_state.counted.remove(request.request_id);
        return;
    };
    uncount(side, request, who.tab);
    var buffer: [16]*PageSession = undefined;
    var id_buffer: [48]u8 = undefined;
    for (sessionsWith(side, who.tab, "Network", &buffer)) |s| {
        s.emit(N.loadingFailed, .{
            .requestId = requestIdText(side, request.request_id, &id_buffer),
            .timestamp = monotonicSeconds(),
            .type = resourceTypeOf(request),
            .errorText = if (canceled) "net::ERR_ABORTED" else error_text,
            .canceled = if (canceled) true else null,
        });
    }
    // Log.entryAdded "Failed to load resource: ..." for the tab's Log
    // sessions - not for a cancellation (lane cdph's domains/log.zig;
    // Blink's FrameConsole::DidFailLoading).
    if (!canceled) @import("domains/log.zig").loadingFailed(side, who.tab, request.getUrl(), requestIdText(side, request.request_id, &id_buffer), error_text);
}

/// Network.setCacheDisabled: a tab whose session disabled the cache sends
/// its requests past the HTTP cache.
fn bypassCache(context: *anyopaque, request: *const InternalRequest) bool {
    const side = sideOf(context) orelse return false;
    const who = attribute(side, request) orelse return false;
    for (side.sessions.items) |s| {
        if (s.tab == who.tab and s.states.Network.enabled and s.states.Network.cache_disabled) return true;
    }
    return false;
}

// ----------------------------------------------------------------------------
// Fetch interception
// ----------------------------------------------------------------------------

/// Fetch.enable's pattern match (Fetch RequestPattern: urlPattern with `*`
/// for any run of characters, `?` for one, `\` escaping either; resourceType;
/// requestStage "Request" - the default - only: part 1 holds no response).
pub fn patternMatches(pattern: @import("domains/fetch.zig").Pattern, url: []const u8, resource_type: N.ResourceType) bool {
    if (pattern.request_stage) |stage| if (stage == .Response) return false;
    if (pattern.resource_type) |t| if (t != resource_type) return false;
    return wildcardMatch(pattern.url_pattern, url);
}

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

fn interceptRequest(context: *anyopaque, request: *const InternalRequest, network_request: *const fetch.network.NetworkRequest, interception: observer.Interception) bool {
    _ = network_request;
    const side = sideOf(context) orelse return false;
    const who = attribute(side, request) orelse return false;
    const resource_type = resourceTypeOf(request);
    const url = request.currentUrl();
    // The first session of the tab whose patterns take it holds it.
    var found: ?*PageSession = null;
    search: for (side.sessions.items) |s| {
        if (s.tab != who.tab or !s.states.Fetch.enabled) continue;
        for (s.states.Fetch.patterns.items) |pattern| {
            if (patternMatches(pattern, url, resource_type)) {
                found = s;
                break :search;
            }
        }
    }
    const holder = found orelse return false;

    const interception_id = side.fetch_state.next_interception;
    side.fetch_state.next_interception += 1;
    side.fetch_state.paused.put(side.allocator, interception_id, .{ .interception = interception, .session = holder }) catch return false;

    var arena_state = std.heap.ArenaAllocator.init(side.allocator);
    defer arena_state.deinit();
    const n_request = requestOf(arena_state.allocator(), request) catch {
        _ = side.fetch_state.paused.remove(interception_id);
        return false;
    };
    var paused_buffer: [48]u8 = undefined;
    var network_buffer: [48]u8 = undefined;
    var frame_buffer: [32]u8 = ids.frameId(side.token, who.frame).text;
    holder.emit(F.requestPaused, .{
        .requestId = interceptionIdText(interception_id, &paused_buffer),
        .request = n_request,
        .frameId = &frame_buffer,
        .resourceType = resource_type,
        .networkId = requestIdText(side, request.request_id, &network_buffer),
    });
    return true;
}

fn interceptionDropped(context: *anyopaque, request_id: u64) void {
    const side = sideOf(context) orelse return;
    var it = side.fetch_state.paused.iterator();
    while (it.next()) |e| {
        if (e.value_ptr.interception.request_id == request_id) {
            _ = side.fetch_state.paused.remove(e.key_ptr.*);
            return;
        }
    }
}

/// Chrome's interception ids: "interception-job-<n>.0".
pub fn interceptionIdText(id: u64, buffer: *[48]u8) []const u8 {
    return std.fmt.bufPrint(buffer, "interception-job-{d}.0", .{id}) catch "";
}

pub fn parseInterceptionId(text: []const u8) ?u64 {
    const prefix = "interception-job-";
    if (!std.mem.startsWith(u8, text, prefix)) return null;
    const rest = text[prefix.len..];
    const dot = std.mem.indexOfScalar(u8, rest, '.') orelse rest.len;
    return std.fmt.parseInt(u64, rest[0..dot], 10) catch null;
}

/// Fetch.continueRequest / fulfillRequest / failRequest: the decision for a
/// held request `session` holds. False: no such request.
pub fn decide(session: *PageSession, interception_text: []const u8, decision: observer.Decision) bool {
    const side = session.side orelse return false;
    const id = parseInterceptionId(interception_text) orelse return false;
    const held = side.fetch_state.paused.get(id) orelse return false;
    if (held.session != session) return false;
    _ = side.fetch_state.paused.remove(id);
    held.interception.decide(decision);
    return true;
}

/// A session's end (or Fetch.disable): what it holds is sent as it was.
pub fn releaseHeldBy(session: *PageSession) void {
    const side = session.side orelse return;
    while (true) {
        var it = side.fetch_state.paused.iterator();
        const found = while (it.next()) |e| {
            if (e.value_ptr.session == session) break e.key_ptr.*;
        } else break;
        const held = side.fetch_state.paused.fetchRemove(found).?.value;
        held.interception.decide(.{ .@"continue" = .{} });
    }
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

test "interception ids round-trip in Chrome's form" {
    var buffer: [48]u8 = undefined;
    const text = interceptionIdText(42, &buffer);
    try std.testing.expectEqualStrings("interception-job-42.0", text);
    try std.testing.expectEqual(@as(?u64, 42), parseInterceptionId(text));
    try std.testing.expect(parseInterceptionId("nope") == null);
}
