//! The remote end's fetch observer: Network events, kept bodies, and the
//! hooks of Fetch interception, for a Browser's page sessions
//! (tmp/plans/cdp-part1-design.md 3.9-3.10).
//!
//! Installed on the Browser's network context (fetch.network.observer, the
//! generic slot) while the remote end is on the Browser (BrowserSide), it
//! turns Fetch's steps into Network.requestWillBeSent, responseReceived,
//! dataReceived, loadingFinished, loadingFailed and requestServedFromCache
//! for every page session of the request's tab with Network enabled -
//! Blink's InspectorNetworkAgent at its probe points (third_party/blink/
//! renderer/core/inspector/inspector_network_agent.cc WillSendRequest,
//! DidReceiveResourceResponse, DidReceiveData, DidFinishLoading,
//! DidFailLoading) - and Network.requestWillBeSentExtraInfo /
//! responseReceivedExtraInfo with what went over the network, as Chrome's
//! network service reports them below the page (services/network/
//! url_loader.cc -> DevToolsObserver OnRawRequest / OnRawResponse: the
//! headers HTTP-network-or-cache fetch adds are THERE, not in
//! requestWillBeSent - Chrome's split, lane cdpr's G16). Each session with
//! Network enabled keeps the bodies (network_resources.zig). Holding
//! requests is fetch_interception.zig's.
//!
//! Only the window agent's fetches are reported: a worker's go to its worker
//! target in Chrome, and part 1 reports no worker targets (decision D10). Its
//! observer calls come on the worker's thread and are ignored here.
//!
//! Ids: a navigation's request is named by its navigation id, printed as
//! its loaderId (frames.loaderToken: Chrome's loaderId IS the navigation
//! request's requestId); any other request by a counter of the Browser's,
//! printed as Chrome prints a renderer's request ids ("<n>.<counter>"). A
//! request's loaderId is its document's, read from the ONE record the Page
//! domain reads too (frames.zig Frames: the navigation that committed the
//! document, or the id an initial about:blank was given) - never a copy of
//! it here (lane cdpr's G3: two loaderIds for one navigation, and
//! Playwright's goto answered null).

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
const frames = @import("frames.zig");
const fetch_interception = @import("fetch_interception.zig");
const network_resources = @import("network_resources.zig");
const BrowserSide = @import("browser_side.zig").BrowserSide;
const PageSession = @import("page_session.zig").PageSession;

const observer = fetch.network.observer;
const InternalRequest = fetch.internal.InternalRequest;
const InternalResponse = fetch.internal.InternalResponse;
const N = protocol.Network;

const log = std.log.scoped(.devtools);
const TombstoneGuard = @import("infra").tombstones.TombstoneGuard;

/// The high bit marks a request id that is a counter, not a navigation id.
const counter_bit: u64 = 1 << 63;

/// What the observer keeps of one request while it is in flight.
pub const RequestInfo = struct {
    /// Its interception job (fetch_interception.zig), 0 until first held.
    job: u64 = 0,
    /// Redirects followed so far (the interception id's second number).
    hop: u32 = 0,
    /// A redirect's response, from redirect_received to the next
    /// will_send_request.
    redirect: ?Head = null,
    /// Whether the redirect's response came over the network (an
    /// ExtraInfo was reported for it: requestWillBeSent's
    /// redirectHasExtraInfo).
    redirect_extra_info: bool = false,
    /// The current hop's response came over the network
    /// (responseReceivedExtraInfo went: responseReceived's hasExtraInfo).
    extra_info: bool = false,
    /// responseReceived went; bytes that came before it (main fetch step
    /// 23's whole body) are announced with it.
    response_seen: bool = false,
    pending_data: u64 = 0,
    /// The navigable whose in-flight count this request is in.
    counted_frame: ?u64 = null,

    fn deinit(self: *RequestInfo, allocator: Allocator) void {
        if (self.redirect) |*r| r.deinit(allocator);
        self.redirect = null;
    }
};

/// What the observer keeps of a Browser, on its window thread.
pub const State = struct {
    next_request: u64 = 1,
    next_job: u64 = 1,
    /// Navigation id -> the navigable it navigates (`started` milestones):
    /// which frame a navigation request is for.
    navigations: std.AutoHashMapUnmanaged(u64, u64) = .empty,
    /// Requests in flight, by id.
    requests: std.AutoHashMapUnmanaged(u64, RequestInfo) = .empty,
    /// Each navigable's subresource fetches in flight (Page.lifecycleEvent's
    /// networkAlmostIdle / networkIdle: Blink's IdlenessDetector counts a
    /// frame's active requests).
    in_flight: std.AutoHashMapUnmanaged(u64, u32) = .empty,
    /// Each map's tombstones, bounded: their keys - navigations, requests,
    /// frames - come and go for as long as the remote end is on the Browser
    /// (infra.tombstones.TombstoneGuard; tools/lint_tombstones.zig).
    navigations_guard: TombstoneGuard = .{},
    requests_guard: TombstoneGuard = .{},
    in_flight_guard: TombstoneGuard = .{},

    pub fn deinit(self: *State, allocator: Allocator) void {
        self.navigations.deinit(allocator);
        var it = self.requests.valueIterator();
        while (it.next()) |r| r.deinit(allocator);
        self.requests.deinit(allocator);
        self.in_flight.deinit(allocator);
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
    state.in_flight_guard.beforeInsert(&state.in_flight);
    const entry = state.in_flight.getOrPut(side.allocator, navigable) catch return;
    if (!entry.found_existing) entry.value_ptr.* = 0;
    if (delta > 0) entry.value_ptr.* += 1 else entry.value_ptr.* -|= 1;
    const now = entry.value_ptr.*;
    if (now == 0 and state.in_flight.remove(navigable)) state.in_flight_guard.noteRemoval(&state.in_flight);
    // The frame's idleness detector hears it whether or not a session
    // listens (Blink's IdlenessDetector, per frame: domains/page.zig).
    @import("domains/page.zig").onBrowserNetworkActivity(side, navigable, now);
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

/// The request's record, while it is in flight.
pub fn requestInfo(side: *BrowserSide, request_id: u64) ?*RequestInfo {
    return side.fetch_state.requests.getPtr(request_id);
}

/// The request is over: its record goes, and its in-flight count.
fn endRequest(side: *BrowserSide, request_id: u64, tab: ?u64) void {
    const state = &side.fetch_state;
    fetch_interception.forget(side, request_id);
    var removed = state.requests.fetchRemove(request_id) orelse return;
    state.requests_guard.noteRemoval(&state.requests);
    removed.value.deinit(side.allocator);
    if (removed.value.counted_frame) |frame| if (tab) |t| countInFlight(side, t, frame, -1);
    // A navigation's request (its id is the navigation's): nothing of it
    // is looked up again, whether its document committed already (a body
    // that outlived the commit, `settleNavigation`) or will.
    if (request_id & counter_bit == 0) forgetNavigation(state, request_id);
}

/// A response's head, OWNED copies.
const Head = struct {
    url: []u8,
    status: u16,
    status_text: []u8,
    headers: std.json.ObjectMap,
    mime_type: []u8,
    charset: []u8,
    /// The HTTP version it came over; null for a response that did not.
    http_version: ?fetch.network.HttpVersion = null,

    fn of(allocator: Allocator, response: *const InternalResponse) !Head {
        var headers: std.json.ObjectMap = .empty;
        errdefer freeHeaders(allocator, &headers);
        for (response.header_list.entries.items) |h| try putHeader(allocator, &headers, h.name, h.value);
        sortHeaders(&headers);
        const url = try allocator.dupe(u8, if (response.url_list.items.len > 0) response.url_list.items[response.url_list.items.len - 1] else "");
        errdefer allocator.free(url);
        const status_text = try allocator.dupe(u8, response.status_message);
        errdefer allocator.free(status_text);
        const content_type = headerOf(&headers, "content-type");
        const mime = try allocator.dupe(u8, if (content_type) |v| essence(v) else "");
        errdefer allocator.free(mime);
        const charset = try allocator.dupe(u8, if (content_type) |v| charsetOf(v) else "");
        return .{ .url = url, .status = response.status, .status_text = status_text, .headers = headers, .mime_type = mime, .charset = charset, .http_version = response.http_version };
    }

    fn deinit(self: *Head, allocator: Allocator) void {
        allocator.free(self.url);
        allocator.free(self.status_text);
        allocator.free(self.mime_type);
        allocator.free(self.charset);
        freeHeaders(allocator, &self.headers);
    }

    fn toResponse(self: *const Head, encoded_length: f64) N.Response {
        return .{
            .url = self.url,
            .status = self.status,
            .statusText = self.status_text,
            .headers = .{ .object = self.headers },
            .mimeType = self.mime_type,
            .charset = self.charset,
            .connectionReused = false,
            .connectionId = 0,
            .encodedDataLength = encoded_length,
            .securityState = securityStateOf(self.url),
            .protocol = protocolOf(self.url, self.http_version),
        };
    }
};

/// Network.Response.protocol. A response that came over HTTP names the
/// version it came over - its ALPN protocol or its connection's version
/// (net::HttpConnectionInfoToString: "http/1.0", "http/1.1", "h2", "h3";
/// Chrome 157 says "http/1.0" for an HTTP/1.0 server, lane tpw's probe,
/// tmp/plans/tpw-evidence/netprobe-chrome157.txt). One that did not names
/// its URL's scheme: Blink's InspectorNetworkAgent (BuildObjectForResource
/// Response) takes response.CurrentRequestUrl().Protocol() when there is no
/// ALPN protocol and the response is not HTTP - Chrome 157 (CDP probe, lane
/// tpg): "data" for a data: document, script, image, fetch() and XHR,
/// "file" for a file: document and its subresources, "blob" for a blob:
/// fetch.
fn protocolOf(url: []const u8, http_version: ?fetch.network.HttpVersion) []const u8 {
    if (http_version) |version| return switch (version) {
        .http_1_0 => "http/1.0",
        .http_1_1 => "http/1.1",
        .http_2 => "h2",
        .http_3 => "h3",
    };
    const colon = std.mem.indexOfScalar(u8, url, ':') orelse return "http/1.1";
    const scheme = url[0..colon];
    // An HTTP(S) response with no version told (made here: the HTTP cache's,
    // a fulfilled one) keeps HTTP/1.1.
    if (std.ascii.eqlIgnoreCase(scheme, "http") or std.ascii.eqlIgnoreCase(scheme, "https")) return "http/1.1";
    return scheme;
}

/// Whether Blink would serve `request` as static data from its memory
/// cache: a data: URL of a resource its ResourceFetcher loads - a script, a
/// stylesheet, an image, a font - never a raw one (fetch(), XHR) or a
/// navigation. ResourceFetcher::ResourceForStaticData makes the resource
/// from the URL itself and the load reports probe::MarkResourceAsCached, so
/// DevTools hears Network.requestServedFromCache before responseReceived,
/// and loadingFinished's encodedDataLength is 0 (Chrome 157, CDP probe, lane
/// tpg: a data: script, stylesheet and image - parser-inserted or not - do;
/// fetch() and XHR of a data: URL, and a data: document, do not).
fn isStaticData(request: *const InternalRequest) bool {
    if (request.mode == .navigate) return false;
    if (!std.ascii.startsWithIgnoreCase(request.currentUrl(), "data:")) return false;
    return switch (request.destination) {
        .script, .style, .image, .font => true,
        else => false,
    };
}

fn freeHeaders(allocator: Allocator, headers: *std.json.ObjectMap) void {
    var it = headers.iterator();
    while (it.next()) |e| {
        allocator.free(e.key_ptr.*);
        allocator.free(e.value_ptr.string);
    }
    headers.deinit(allocator);
}

/// A header of a Network.Headers object, by name in any case.
fn headerOf(headers: *const std.json.ObjectMap, name: []const u8) ?[]const u8 {
    var it = headers.iterator();
    while (it.next()) |e| if (std.ascii.eqlIgnoreCase(e.key_ptr.*, name)) return e.value_ptr.string;
    return null;
}

/// A response's (and an ExtraInfo event's) Headers object in Chrome's
/// order: by name, byte by byte - Chrome builds them as a base::Value::Dict,
/// a flat_map sorted by key (content/browser/devtools/protocol/
/// network_handler.cc BuildResponseHeaders / GetRawHeaders; BSD-3 -
/// reproduced, not copied). requestWillBeSent's request headers keep their
/// order (Blink's HTTPHeaderMap, which no client can rely on either).
fn sortHeaders(headers: *std.json.ObjectMap) void {
    const ByName = struct {
        keys: []const []const u8,
        pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
            return std.mem.lessThan(u8, ctx.keys[a], ctx.keys[b]);
        }
    };
    headers.sort(ByName{ .keys = headers.keys() });
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

/// A Content-Type's charset parameter, unquoted ("" for none).
fn charsetOf(content_type: []const u8) []const u8 {
    var it = std.mem.splitScalar(u8, content_type, ';');
    _ = it.next();
    while (it.next()) |param| {
        const p = std.mem.trim(u8, param, " \t");
        const eq = std.mem.indexOfScalar(u8, p, '=') orelse continue;
        if (!std.ascii.eqlIgnoreCase(std.mem.trim(u8, p[0..eq], " \t"), "charset")) continue;
        return std.mem.trim(u8, p[eq + 1 ..], " \t\"");
    }
    return "";
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
        .request_sent = requestSent,
        .response_head_received = responseHeadReceived,
        .response_received = responseReceived,
        .data_received = dataReceived,
        .loading_finished = loadingFinished,
        .loading_failed = loadingFailed,
        .intercept_request = fetch_interception.interceptRequest,
        .intercept_response = fetch_interception.interceptResponse,
        .intercept_auth = fetch_interception.interceptAuth,
        .interception_dropped = fetch_interception.interceptionDropped,
        .bypass_cache = bypassCache,
    };
}

/// The side an observer call is for, on the window agent's thread only
/// (decision D10).
pub fn sideOf(context: *anyopaque) ?*BrowserSide {
    const side: *BrowserSide = @ptrCast(@alignCast(context));
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
            state.navigations_guard.beforeInsert(&state.navigations);
            state.navigations.put(side.allocator, milestone.navigation_id, milestone.navigable_id) catch {};
        },
        .committed => |c| {
            // The document's loader id, in the record the Page domain reads
            // (frames.zig): noted here first, as this hears the milestone
            // before any handler, so a subresource fetch of the new
            // document finds it whether or not a session has Page on.
            if (side.browser) |b| if (frames.of(b)) |f| f.noteCommitted(milestone.navigable_id, c.document.document, c.document.generation, milestone.navigation_id);
            settleNavigation(state, milestone.navigation_id);
        },
        .aborted => settleNavigation(state, milestone.navigation_id),
        else => {},
    }
}

/// The navigation committed or was aborted: its navigable stops being
/// looked up - unless its request is still in flight. A document commits
/// at its response's head, so a streamed document's body (React's SSR,
/// Next.js) still arrives after the commit, and its dataReceived and
/// loadingFinished find their frame through this entry (`attribute`): it
/// goes with the request then (`endRequest`). It went at the commit, so
/// a document whose body outlived the commit never reported its end -
/// Playwright's page.goto(waitUntil: 'networkidle') waited on it forever
/// (lane tpf, React's compiler playground; Chrome reports the document's
/// loadingFinished when its body ends).
fn settleNavigation(state: *State, navigation_id: u64) void {
    if (state.requests.contains(navigation_id)) return;
    forgetNavigation(state, navigation_id);
}

fn forgetNavigation(state: *State, navigation_id: u64) void {
    if (state.navigations.remove(navigation_id)) state.navigations_guard.noteRemoval(&state.navigations);
}

/// Whom a request is for: its tab, frame and document's loader, and the
/// document whose fetch it is (null for a navigation request, whose
/// documentURL is its own URL).
pub const Attribution = struct {
    tab: u64,
    frame: u64,
    loader: u64,
    document: ?*runtime.Instance,
};

pub fn attribute(side: *BrowserSide, request: *const InternalRequest) ?Attribution {
    const navigables = dom.browser_state.existingNavigablesIn(side.browser.?.scope) orelse return null;
    if (request.navigation_id != 0) {
        const navigable_id = side.fetch_state.navigations.get(request.navigation_id) orelse return null;
        const bc = navigables.byId(navigable_id) orelse return null;
        return .{ .tab = bc.getTop().id, .frame = bc.id, .loader = request.navigation_id, .document = null };
    }
    const window_ptr = switch (request.traversable_for_user_prompts) {
        .traversable => |t| t,
        else => return null,
    };
    const window: *runtime.Instance = @ptrCast(@alignCast(window_ptr));
    const bc = dom.browser_state.browsingContextOf(window) orelse return null;
    // The document's loader id: the Page domain's record (Frames.loaderOf -
    // an initial about:blank's own id included), the one source.
    const loader: u64 = if (frames.of(side.browser.?)) |f| f.loaderOf(bc) else 0;
    return .{ .tab = bc.getTop().id, .frame = bc.id, .loader = loader, .document = frames.documentOf(bc) };
}

/// The request's documentURL (Network.requestWillBeSent): a navigation
/// request's own URL, else its document's.
fn documentUrlOf(arena: Allocator, who: Attribution, request: *const InternalRequest) []const u8 {
    const document = who.document orelse return request.currentUrl();
    return frames.documentUrl(arena, document) catch "";
}

/// The Network.RequestId text of `id`, as `session` (any session of the
/// Browser) prints it: a navigation request's is its loaderId
/// (frames.loaderToken - Chrome's loaderId IS the navigation request's
/// requestId), any other a counter in Chrome's "<n>.<counter>" form.
pub fn requestIdText(session: *const PageSession, id: u64, buffer: *[48]u8) []const u8 {
    return requestIdTextFor(session.side.?.token, id, buffer);
}

/// requestIdText from the Browser's devtools token alone (the Log entries'
/// call sites hold the BrowserSide, not a session).
pub fn requestIdTextFor(browser_token: u64, id: u64, buffer: *[48]u8) []const u8 {
    if (id & counter_bit != 0) {
        return std.fmt.bufPrint(buffer, "{d}.{d}", .{ browser_token % 100000, id & ~counter_bit }) catch "";
    }
    const token = frames.loaderTokenOf(browser_token, id);
    @memcpy(buffer[0..32], token.slice());
    return buffer[0..32];
}

/// The request id a Network.RequestId names for `session`, if it is one
/// `requestIdText` could have printed.
pub fn parseRequestId(session: *const PageSession, text: []const u8) ?u64 {
    const side = session.side orelse return null;
    if (std.mem.indexOfScalar(u8, text, '.')) |dot| {
        const prefix = std.fmt.parseInt(u64, text[0..dot], 10) catch return null;
        if (prefix != side.token % 100000) return null;
        const counter = std.fmt.parseInt(u64, text[dot + 1 ..], 10) catch return null;
        if (counter & counter_bit != 0) return null;
        return counter | counter_bit;
    }
    const ref = ids.parseFrameId(text) orelse return null;
    if (ref.browser_token != side.token) return null;
    // A loader token is frames.loaderToken's, its flag bit set: the id is
    // the one whose token this is.
    const candidate = ref.navigable_id & ~counter_bit;
    if (!frames.loaderToken(session, candidate).eql(text)) return null;
    return candidate;
}

fn loaderText(session: *const PageSession, loader: u64, buffer: *[32]u8) []const u8 {
    buffer.* = frames.loaderToken(session, loader).text;
    return buffer;
}

pub fn resourceTypeOf(request: *const InternalRequest) N.ResourceType {
    if (request.mode == .navigate) return .Document;
    // Chrome 157 reports both <link rel="icon"> and default /favicon.ico as
    // ResourceType "Other" (Blink RequestContextType::FAVICON -> InspectorPageAgent).
    if (request.is_favicon) return .Other;
    if (request.initiator_type) |t| switch (t) {
        .xmlhttprequest => return .XHR,
        // fetch() of a data: URL is "Other" in Chrome 157, an XHR of one
        // "XHR" (lane tpw's CDP probe, tmp/plans/tpw-evidence/
        // netprobe-chrome157.txt: requestWillBeSent and responseReceived
        // both).
        .fetch => return if (isDataUrl(request)) .Other else .Fetch,
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

fn isDataUrl(request: *const InternalRequest) bool {
    const url = request.getUrl();
    return url.len >= 5 and std.ascii.eqlIgnoreCase(url[0..5], "data:");
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

/// The bytes of the request's body, when it has them (a stream body has
/// none to report).
fn postBytesOf(request: *const InternalRequest) ?[]const u8 {
    const body = request.body orelse return null;
    return switch (body) {
        .body => |b| b.getBytes(),
        else => null,
    };
}

/// The Network.Request of `request`, its strings in `arena`. Its post data
/// as Blink's BuildObjectForResourceRequest gives it: hasPostData for any
/// body, postData (UTF-8, Latin-1 fallback) and postDataEntries for a body
/// of bytes no longer than `max_post_data` (0: any).
pub fn requestOf(arena: Allocator, request: *const InternalRequest, max_post_data: u64) !N.Request {
    var headers: std.json.ObjectMap = .empty;
    for (request.header_list.entries.items) |h| try putHeader(arena, &headers, h.name, h.value);
    const url = request.currentUrl();
    const hash = std.mem.indexOfScalar(u8, url, '#');
    var result: N.Request = .{
        .url = if (hash) |at| url[0..at] else url,
        .urlFragment = if (hash) |at| url[at..] else null,
        .method = request.method,
        .headers = .{ .object = headers },
        .initialPriority = if (request.mode == .navigate or request.destination == .style) .VeryHigh else if (request.destination == .script) .High else .Low,
        .referrerPolicy = referrerPolicyOf(request),
        .hasPostData = if (request.body != null) true else null,
    };
    if (postBytesOf(request)) |bytes| if (bytes.len > 0 and (max_post_data == 0 or bytes.len <= max_post_data)) {
        const text = try network_resources.reportedBody(arena, bytes, "text/plain", "");
        result.postData = text.text;
        const entries = try arena.alloc(N.PostDataEntry, 1);
        entries[0] = .{ .bytes = try network_resources.base64(arena, bytes) };
        result.postDataEntries = entries;
    };
    return result;
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
    const state = &side.fetch_state;
    const id = if (request.request_id != 0)
        request.request_id
    else if (request.navigation_id != 0)
        request.navigation_id
    else blk: {
        const n = state.next_request;
        state.next_request += 1;
        break :blk n | counter_bit;
    };
    const who = attribute(side, request) orelse return id;
    state.requests_guard.beforeInsert(&state.requests);
    const entry = state.requests.getOrPut(side.allocator, id) catch return id;
    if (!entry.found_existing) {
        entry.value_ptr.* = .{};
        // A subresource fetch's first hop: one more in flight for its frame.
        if (request.request_id == 0 and request.navigation_id == 0) {
            entry.value_ptr.counted_frame = who.frame;
            countInFlight(side, who.tab, who.frame, 1);
        }
    }
    const info = entry.value_ptr;
    // A redirect's next hop: its response goes with this event.
    var redirect = info.redirect;
    info.redirect = null;
    defer if (redirect) |*r| r.deinit(side.allocator);
    const redirect_extra_info = info.redirect_extra_info;
    info.redirect_extra_info = false;
    info.extra_info = false;
    info.response_seen = false;
    info.pending_data = 0;

    var buffer: [16]*PageSession = undefined;
    const sessions = sessionsWith(side, who.tab, "Network", &buffer);
    if (sessions.len == 0) return id;

    var arena_state = std.heap.ArenaAllocator.init(side.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const post_bytes = postBytesOf(request);
    var id_buffer: [48]u8 = undefined;
    var loader_buffer: [32]u8 = undefined;
    var frame_buffer: [32]u8 = ids.frameId(side.token, who.frame).text;
    const document_url = documentUrlOf(arena, who, request);
    for (sessions) |s| {
        // The session keeps the request's record (its post data) for
        // getRequestPostData and its body to come.
        if (s.states.Network.resources) |*res| res.requestWillBeSent(id, who.loader, post_bytes) catch {};
        const n_request = requestOf(arena, request, s.states.Network.max_post_data_size) catch continue;
        s.emit(N.requestWillBeSent, .{
            .requestId = requestIdText(s, id, &id_buffer),
            .loaderId = loaderText(s, who.loader, &loader_buffer),
            .documentURL = document_url,
            .request = n_request,
            .timestamp = monotonicSeconds(),
            .wallTime = wallSeconds(),
            .initiator = .{ .type = if (request.mode == .navigate or request.is_favicon) .other else if (request.parser_metadata == .parser_inserted) .parser else .script },
            .redirectHasExtraInfo = redirect_extra_info,
            .redirectResponse = if (redirect) |*r| r.toResponse(0) else null,
            .type = resourceTypeOf(request),
            .frameId = &frame_buffer,
            .hasUserGesture = request.user_activation,
        });
    }
    return id;
}

fn redirectReceived(context: *anyopaque, request: *const InternalRequest, response: *const InternalResponse) void {
    const side = sideOf(context) orelse return;
    const info = requestInfo(side, request.request_id) orelse return;
    const head = Head.of(side.allocator, response) catch return;
    if (info.redirect) |*old| old.deinit(side.allocator);
    info.redirect = head;
    info.redirect_extra_info = info.extra_info;
    // The next hop is a new interception id's ("interception-job-<n>.<hop>").
    info.hop += 1;
}

fn servedFromCache(context: *anyopaque, request: *const InternalRequest) void {
    const side = sideOf(context) orelse return;
    const who = attribute(side, request) orelse return;
    var buffer: [16]*PageSession = undefined;
    var id_buffer: [48]u8 = undefined;
    for (sessionsWith(side, who.tab, "Network", &buffer)) |s| {
        s.emit(N.requestServedFromCache, .{ .requestId = requestIdText(s, request.request_id, &id_buffer) });
    }
}

/// Network.requestWillBeSentExtraInfo: the headers as they go over the
/// network - what HTTP-network-or-cache fetch added (User-Agent,
/// Accept-Encoding, Accept-Language, Referer, Origin, Sec-Fetch-*, Cookie)
/// and the Host the transfer sends - as Chrome's network service reports
/// them (DevToolsObserver::OnRawRequest; associatedCookies empty: the
/// Cookie header carries them).
fn requestSent(context: *anyopaque, request: *const InternalRequest, network_request: *const fetch.network.NetworkRequest) void {
    const side = sideOf(context) orelse return;
    const who = attribute(side, request) orelse return;
    var buffer: [16]*PageSession = undefined;
    const sessions = sessionsWith(side, who.tab, "Network", &buffer);
    if (sessions.len == 0) return;
    var arena_state = std.heap.ArenaAllocator.init(side.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var headers: std.json.ObjectMap = .empty;
    for (network_request.headers) |h| putHeader(arena, &headers, h.name, h.value) catch return;
    if (headerOf(&headers, "host") == null) if (hostOf(network_request.url)) |host| putHeader(arena, &headers, "Host", host) catch return;
    sortHeaders(&headers);
    var id_buffer: [48]u8 = undefined;
    for (sessions) |s| {
        s.emit(N.requestWillBeSentExtraInfo, .{
            .requestId = requestIdText(s, request.request_id, &id_buffer),
            .associatedCookies = &.{},
            .headers = .{ .object = headers },
            .connectTiming = .{ .requestTime = monotonicSeconds() },
        });
    }
}

/// A URL's host and port, as the Host header names them (RFC 9110 7.2).
fn hostOf(url: []const u8) ?[]const u8 {
    const scheme_end = std.mem.indexOf(u8, url, "://") orelse return null;
    const rest = url[scheme_end + 3 ..];
    const end = std.mem.indexOfAny(u8, rest, "/?#") orelse rest.len;
    const authority = rest[0..end];
    const at = std.mem.lastIndexOfScalar(u8, authority, '@');
    const host = if (at) |i| authority[i + 1 ..] else authority;
    return if (host.len > 0) host else null;
}

/// Network.responseReceivedExtraInfo: the network's head as it came
/// (DevToolsObserver::OnRawResponse).
fn responseHeadReceived(context: *anyopaque, request: *const InternalRequest, network_response: *const fetch.network.NetworkResponse) void {
    const side = sideOf(context) orelse return;
    const who = attribute(side, request) orelse return;
    if (requestInfo(side, request.request_id)) |info| info.extra_info = true;
    var buffer: [16]*PageSession = undefined;
    const sessions = sessionsWith(side, who.tab, "Network", &buffer);
    if (sessions.len == 0) return;
    var arena_state = std.heap.ArenaAllocator.init(side.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var headers: std.json.ObjectMap = .empty;
    for (network_response.headers) |h| putHeader(arena, &headers, h.name, h.value) catch return;
    sortHeaders(&headers);
    var id_buffer: [48]u8 = undefined;
    for (sessions) |s| {
        s.emit(N.responseReceivedExtraInfo, .{
            .requestId = requestIdText(s, request.request_id, &id_buffer),
            .blockedCookies = &.{},
            .headers = .{ .object = headers },
            .resourceIPAddressSpace = addressSpaceOf(network_response.remote_ip),
            .statusCode = network_response.status,
        });
    }
}

/// The IP address space of the server's address (Private Network Access:
/// loopback, private ranges, the rest public).
fn addressSpaceOf(ip: ?[]const u8) N.IPAddressSpace {
    const address = ip orelse return .Unknown;
    if (std.mem.startsWith(u8, address, "127.") or std.mem.eql(u8, address, "::1")) return .Loopback;
    if (std.mem.startsWith(u8, address, "10.") or std.mem.startsWith(u8, address, "192.168.") or std.mem.startsWith(u8, address, "169.254.") or
        std.mem.startsWith(u8, address, "fc") or std.mem.startsWith(u8, address, "fd") or std.mem.startsWith(u8, address, "fe80:"))
    {
        return .Local;
    }
    if (std.mem.startsWith(u8, address, "172.")) {
        const second = std.fmt.parseInt(u8, std.mem.sliceTo(address[4..], '.'), 10) catch return .Public;
        if (second >= 16 and second <= 31) return .Local;
    }
    return .Public;
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
        @import("domains/log.zig").errorResponse(side, who.tab, request.getUrl(), requestIdTextFor(side.token, request.request_id, &log_id_buffer), response.status, response.status_message);
    }
    const info = requestInfo(side, request.request_id);
    var buffer: [16]*PageSession = undefined;
    const sessions = sessionsWith(side, who.tab, "Network", &buffer);
    if (info) |i| i.response_seen = true;
    if (sessions.len == 0) return;
    var head = Head.of(side.allocator, response) catch return;
    defer head.deinit(side.allocator);
    var id_buffer: [48]u8 = undefined;
    var loader_buffer: [32]u8 = undefined;
    var frame_buffer: [32]u8 = ids.frameId(side.token, who.frame).text;
    const has_extra_info = if (info) |i| i.extra_info else false;
    const pending = if (info) |i| i.pending_data else 0;
    if (info) |i| i.pending_data = 0;
    const static_data = isStaticData(request);
    for (sessions) |s| {
        if (s.states.Network.resources) |*res| res.responseReceived(request.request_id, head.mime_type, head.charset) catch {};
        const request_id = requestIdText(s, request.request_id, &id_buffer);
        if (static_data) s.emit(N.requestServedFromCache, .{ .requestId = request_id });
        s.emit(N.responseReceived, .{
            .requestId = request_id,
            .loaderId = loaderText(s, who.loader, &loader_buffer),
            .timestamp = monotonicSeconds(),
            .type = resourceTypeOf(request),
            .response = head.toResponse(0),
            .hasExtraInfo = has_extra_info,
            .frameId = &frame_buffer,
        });
        // Bytes that came before it (a body fetch waited for whole).
        if (pending > 0) s.emit(N.dataReceived, .{ .requestId = request_id, .timestamp = monotonicSeconds(), .dataLength = @intCast(pending), .encodedDataLength = 0 });
    }
}

/// More of a response's body: every Network session keeps it (within its
/// limits) and hears Network.dataReceived - Blink's DidReceiveData (its
/// encodedDataLength is 0 there: the encoded size comes with
/// loadingFinished).
fn dataReceived(context: *anyopaque, request: *const InternalRequest, bytes: []const u8) void {
    const side = sideOf(context) orelse return;
    const who = attribute(side, request) orelse return;
    const info = requestInfo(side, request.request_id);
    const announce = if (info) |i| i.response_seen else true;
    if (!announce) info.?.pending_data += bytes.len;
    var buffer: [16]*PageSession = undefined;
    var id_buffer: [48]u8 = undefined;
    for (sessionsWith(side, who.tab, "Network", &buffer)) |s| {
        if (s.states.Network.resources) |*res| res.addData(request.request_id, bytes);
        if (announce) s.emit(N.dataReceived, .{
            .requestId = requestIdText(s, request.request_id, &id_buffer),
            .timestamp = monotonicSeconds(),
            .dataLength = @intCast(bytes.len),
            .encodedDataLength = 0,
        });
    }
}

fn loadingFinished(context: *anyopaque, request: *const InternalRequest, encoded_length: u64) void {
    const side = sideOf(context) orelse return;
    const who = attribute(side, request) orelse return;
    endRequest(side, request.request_id, who.tab);
    var buffer: [16]*PageSession = undefined;
    var id_buffer: [48]u8 = undefined;
    // Served from Blink's memory cache: nothing came over any wire.
    const reported_length: u64 = if (isStaticData(request)) 0 else encoded_length;
    for (sessionsWith(side, who.tab, "Network", &buffer)) |s| {
        if (s.states.Network.resources) |*res| res.finished(request.request_id);
        s.emit(N.loadingFinished, .{
            .requestId = requestIdText(s, request.request_id, &id_buffer),
            .timestamp = monotonicSeconds(),
            .encodedDataLength = @floatFromInt(reported_length),
        });
    }
}

fn loadingFailed(context: *anyopaque, request: *const InternalRequest, error_text: []const u8, canceled: bool) void {
    const side = sideOf(context) orelse return;
    const who = attribute(side, request) orelse {
        // Its frame went: the count goes with the frame.
        endRequest(side, request.request_id, null);
        return;
    };
    endRequest(side, request.request_id, who.tab);
    var buffer: [16]*PageSession = undefined;
    var id_buffer: [48]u8 = undefined;
    for (sessionsWith(side, who.tab, "Network", &buffer)) |s| {
        s.emit(N.loadingFailed, .{
            .requestId = requestIdText(s, request.request_id, &id_buffer),
            .timestamp = monotonicSeconds(),
            .type = resourceTypeOf(request),
            .errorText = if (canceled) "net::ERR_ABORTED" else error_text,
            .canceled = if (canceled) true else null,
        });
    }
    // Log.entryAdded "Failed to load resource: ..." for the tab's Log
    // sessions - not for a cancellation (lane cdph's domains/log.zig;
    // Blink's FrameConsole::DidFailLoading).
    if (!canceled) @import("domains/log.zig").loadingFailed(side, who.tab, request.getUrl(), requestIdTextFor(side.token, request.request_id, &id_buffer), error_text);
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

test "charsetOf reads a Content-Type's charset parameter" {
    try std.testing.expectEqualStrings("utf-8", charsetOf("text/html; charset=utf-8"));
    try std.testing.expectEqualStrings("ISO-8859-1", charsetOf("text/plain;charset=\"ISO-8859-1\""));
    try std.testing.expectEqualStrings("", charsetOf("image/png"));
}

test "hostOf is a URL's host and port" {
    try std.testing.expectEqualStrings("localhost:8004", hostOf("http://localhost:8004/x?y").?);
    try std.testing.expectEqualStrings("a.test", hostOf("https://u:p@a.test#f").?);
    try std.testing.expect(hostOf("about:blank") == null);
}

test "addressSpaceOf: loopback, private ranges, public" {
    try std.testing.expectEqual(N.IPAddressSpace.Loopback, addressSpaceOf("127.0.0.1"));
    try std.testing.expectEqual(N.IPAddressSpace.Local, addressSpaceOf("192.168.1.2"));
    try std.testing.expectEqual(N.IPAddressSpace.Local, addressSpaceOf("172.20.0.1"));
    try std.testing.expectEqual(N.IPAddressSpace.Public, addressSpaceOf("172.32.0.1"));
    try std.testing.expectEqual(N.IPAddressSpace.Unknown, addressSpaceOf(null));
}
