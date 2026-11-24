//! A page's network requests as chrome-devtools-mcp keeps and prints them
//! (chrome-devtools-mcp-v1.13.0: src/collectors/PageCollector.ts
//! NetworkCollector, src/formatters/NetworkFormatter.ts,
//! src/utils/resourceType.ts), with Puppeteer's HTTPRequest and HTTPResponse
//! built from the Network events it reads (puppeteer-core 25.17.0
//! src/cdp/NetworkManager.ts, src/cdp/HTTPRequest.ts, src/cdp/HTTPResponse.ts,
//! src/util/httpUtils.ts):
//!
//! - requestWillBeSent makes a request: the URL with its fragment, the method,
//!   the headers by lower-cased name, the resource type lower-cased ("other"
//!   when none), whether it is the navigation's own (its id is its loader's
//!   and it is a Document); with a redirectResponse, the request it continues
//!   gets that response and joins the redirect chain the new one carries;
//! - requestWillBeSentExtraInfo merges its headers into the request's;
//! - responseReceived gives the response - its ExtraInfo's status and
//!   headers when it has one (Puppeteer waits for it) - each header's lines
//!   joined (", ", Set-Cookie's "\n ");
//! - loadingFailed gives the failure's errorText; loadingFinished ends it.
//!
//! Translated from the TypeScript (Copyright 2025 Google LLC and Copyright
//! 2017 Google Inc., Apache-2.0; THIRD_PARTY_NOTICES.md).

const std = @import("std");
const Allocator = std.mem.Allocator;
const collectors = @import("collectors.zig");
const text_util = @import("text.zig");

/// NetworkCollector.MAX_REQUESTS_PER_NAVIGATION.
pub const max_per_navigation: usize = 1_000;

pub const Header = struct { name: []u8, value: []u8 };

/// Headers by lower-cased name, in the order first seen.
pub const Headers = struct {
    list: std.ArrayList(Header) = .empty,

    pub fn deinit(self: *Headers, allocator: Allocator) void {
        for (self.list.items) |h| {
            allocator.free(h.name);
            allocator.free(h.value);
        }
        self.list.deinit(allocator);
    }

    /// updateHeaders / the response's header loop: each entry of the
    /// protocol's Headers object, its name lower-cased; with `normalize`,
    /// normalizeHeaderValue.
    pub fn update(self: *Headers, allocator: Allocator, object: std.json.ObjectMap, normalize: bool) !void {
        var it = object.iterator();
        while (it.next()) |entry| {
            const raw = if (entry.value_ptr.* == .string) entry.value_ptr.string else "";
            const name = try std.ascii.allocLowerString(allocator, entry.key_ptr.*);
            errdefer allocator.free(name);
            const value = if (normalize) try normalizeHeaderValue(allocator, name, raw) else try allocator.dupe(u8, raw);
            errdefer allocator.free(value);
            const existing: ?*Header = for (self.list.items) |*h| {
                if (std.mem.eql(u8, h.name, name)) break h;
            } else null;
            if (existing) |h| {
                allocator.free(h.value);
                allocator.free(name);
                h.value = value;
            } else try self.list.append(allocator, .{ .name = name, .value = value });
        }
    }

    pub fn get(self: *const Headers, name: []const u8) ?[]const u8 {
        for (self.list.items) |h| if (std.mem.eql(u8, h.name, name)) return h.value;
        return null;
    }
};

/// normalizeHeaderValue: a multi-line value's trimmed, non-empty lines,
/// joined by ", " (Set-Cookie: "\n ").
fn normalizeHeaderValue(allocator: Allocator, name: []const u8, value: []const u8) ![]u8 {
    if (std.mem.indexOfScalar(u8, value, '\n') == null) return allocator.dupe(u8, value);
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var lines = std.mem.splitScalar(u8, value, '\n');
    var first = true;
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r\x0b\x0c");
        if (trimmed.len == 0) continue;
        if (!first) try out.appendSlice(allocator, if (std.mem.eql(u8, name, "set-cookie")) "\n " else ", ");
        first = false;
        try out.appendSlice(allocator, trimmed);
    }
    return out.toOwnedSlice(allocator);
}

/// A request that redirected, as the chain shows it (toJSON).
pub const Hop = struct {
    id: u32,
    method: []u8,
    url: []u8,
    status: []u8,
};

pub const Response = struct {
    status: i64 = 0,
    headers: Headers = .{},
    /// responseReceived's hasExtraInfo: the response is its ExtraInfo's.
    has_extra_info: bool = false,
    received: bool = false,
};

pub const ExtraInfo = struct {
    status: i64 = 0,
    headers: Headers = .{},
};

pub const Request = struct {
    id: u32 = 0,
    request_id: []u8,
    url: []u8,
    method: []u8,
    headers: Headers = .{},
    has_post_data: bool = false,
    post_data: ?[]u8 = null,
    resource_type: []u8,
    frame_id: []u8,
    is_navigation: bool,
    /// The hops before this request, oldest first.
    chain: []Hop = &.{},
    response: Response = .{},
    extra: ?ExtraInfo = null,
    /// A redirect's hop: its response is the redirectResponse.
    redirected: bool = false,
    failure: ?[]u8 = null,
    finished: bool = false,

    pub fn deinit(self: *Request, allocator: Allocator) void {
        allocator.free(self.request_id);
        allocator.free(self.url);
        allocator.free(self.method);
        self.headers.deinit(allocator);
        if (self.post_data) |d| allocator.free(d);
        allocator.free(self.resource_type);
        allocator.free(self.frame_id);
        for (self.chain) |hop| {
            allocator.free(hop.method);
            allocator.free(hop.url);
            allocator.free(hop.status);
        }
        allocator.free(self.chain);
        self.response.headers.deinit(allocator);
        if (self.extra) |*e| e.headers.deinit(allocator);
        if (self.failure) |f| allocator.free(f);
    }

    /// Puppeteer has the response: it came, and its ExtraInfo too when it
    /// has one.
    pub fn hasResponse(self: *const Request) bool {
        return self.response.received and (!self.response.has_extra_info or self.extra != null);
    }

    pub fn status(self: *const Request) i64 {
        if (self.response.has_extra_info) if (self.extra) |e| return e.status;
        return self.response.status;
    }

    pub fn responseHeaders(self: *const Request) *const Headers {
        if (self.response.has_extra_info) if (self.extra) |*e| return &e.headers;
        return &self.response.headers;
    }

    /// #getStatusFromRequest: the status, the failure, or "pending".
    pub fn statusText(self: *const Request, arena: Allocator) ![]const u8 {
        if (self.hasResponse()) return std.fmt.allocPrint(arena, "{d}", .{self.status()});
        if (self.failure) |f| return f;
        return "pending";
    }

    /// getFilterableResourceType.
    pub fn filterableType(self: *const Request) []const u8 {
        if (!std.mem.eql(u8, self.resource_type, "other")) return self.resource_type;
        if (std.mem.eql(u8, self.method, "OPTIONS") and self.headers.get("access-control-request-method") != null) return "preflight";
        if (self.headers.get("sec-purpose")) |purpose| {
            // /^prefetch\b/i
            if (purpose.len >= 8 and std.ascii.eqlIgnoreCase(purpose[0..8], "prefetch")) {
                if (purpose.len == 8 or !(std.ascii.isAlphanumeric(purpose[8]) or purpose[8] == '_')) return "prefetch";
            }
        }
        return self.resource_type;
    }
};

fn str(value: ?std.json.Value) []const u8 {
    const v = value orelse return "";
    return if (v == .string) v.string else "";
}

fn int(value: ?std.json.Value) i64 {
    const v = value orelse return 0;
    return switch (v) {
        .integer => |i| i,
        .float => |f| @intFromFloat(f),
        else => 0,
    };
}

/// A page's NetworkCollector.
pub const Collector = struct {
    requests: collectors.Collector(Request) = .{ .max_per_navigation = max_per_navigation },
    /// The stable id of the request that started the current navigation.
    navigation_request: ?u32 = null,

    pub fn deinit(self: *Collector, allocator: Allocator) void {
        self.requests.deinit(allocator);
    }

    /// The live request for a CDP request id: the newest that has not
    /// redirected.
    pub fn byRequestId(self: *Collector, request_id: []const u8) ?*Request {
        for (self.requests.navigations.items) |navigation| {
            var i = navigation.items.len;
            while (i > 0) {
                i -= 1;
                const r = navigation.items[i];
                if (!r.redirected and std.mem.eql(u8, r.request_id, request_id)) return r;
            }
        }
        return null;
    }

    /// NetworkCollector.splitAfterNavigation: the main frame's last
    /// navigation request (not the current navigation's) and what came after
    /// it start the new navigation.
    pub fn split(self: *Collector, allocator: Allocator, main_frame_id: []const u8) !void {
        const items = self.requests.currentItems();
        var i = items.len;
        var found: ?usize = null;
        while (i > 0) {
            i -= 1;
            const r = items[i];
            if ((self.navigation_request == null or r.id != self.navigation_request.?) and r.is_navigation and std.mem.eql(u8, r.frame_id, main_frame_id)) {
                found = i;
                break;
            }
        }
        if (found) |at| {
            self.navigation_request = items[at].id;
            try self.requests.split(allocator, at);
        } else {
            self.navigation_request = null;
            try self.requests.split(allocator, null);
        }
    }

    /// Network.requestWillBeSent.
    pub fn requestWillBeSent(self: *Collector, allocator: Allocator, params: std.json.ObjectMap) !void {
        const request_id = str(params.get("requestId"));
        const request_value = params.get("request") orelse return;
        if (request_value != .object) return;
        const payload = request_value.object;
        var chain: std.ArrayList(Hop) = .empty;
        defer chain.deinit(allocator);
        errdefer for (chain.items) |hop| {
            allocator.free(hop.method);
            allocator.free(hop.url);
            allocator.free(hop.status);
        };
        if (params.get("redirectResponse")) |redirect| if (redirect == .object) {
            if (self.byRequestId(request_id)) |previous| {
                // #handleRequestRedirect: the hop's response, its body
                // unavailable, then the chain the new request carries.
                try setResponse(allocator, previous, redirect.object);
                previous.redirected = true;
                previous.finished = true;
                for (previous.chain) |hop| try chain.append(allocator, try copyHop(allocator, hop));
                const status_text = try std.fmt.allocPrint(allocator, "{d}", .{previous.status()});
                errdefer allocator.free(status_text);
                const method = try allocator.dupe(u8, previous.method);
                errdefer allocator.free(method);
                const url = try allocator.dupe(u8, previous.url);
                try chain.append(allocator, .{ .id = previous.id, .method = method, .url = url, .status = status_text });
            }
        };
        const r = try newRequest(allocator, params, payload, &chain);
        // The collector owns it from here (and frees it if it cannot).
        try self.requests.add(allocator, r);
    }

    /// The request requestWillBeSent describes, OWNED; `chain`'s hops move
    /// into it.
    fn newRequest(allocator: Allocator, params: std.json.ObjectMap, payload: std.json.ObjectMap, chain: *std.ArrayList(Hop)) !*Request {
        const request_id = str(params.get("requestId"));
        const kind = str(params.get("type"));
        var headers: Headers = .{};
        errdefer headers.deinit(allocator);
        if (payload.get("headers")) |h| if (h == .object) try headers.update(allocator, h.object, false);
        const r = try allocator.create(Request);
        errdefer allocator.destroy(r);
        const resource_type = try std.ascii.allocLowerString(allocator, if (kind.len != 0) kind else "other");
        errdefer allocator.free(resource_type);
        const id_copy = try allocator.dupe(u8, request_id);
        errdefer allocator.free(id_copy);
        const url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ str(payload.get("url")), str(payload.get("urlFragment")) });
        errdefer allocator.free(url);
        const method = try allocator.dupe(u8, str(payload.get("method")));
        errdefer allocator.free(method);
        const frame_id = try allocator.dupe(u8, str(params.get("frameId")));
        errdefer allocator.free(frame_id);
        const post_data: ?[]u8 = if (payload.get("postData")) |d| (if (d == .string) try allocator.dupe(u8, d.string) else null) else null;
        errdefer if (post_data) |d| allocator.free(d);
        const owned_chain = try chain.toOwnedSlice(allocator);
        r.* = .{
            .request_id = id_copy,
            .url = url,
            .method = method,
            .headers = headers,
            .resource_type = resource_type,
            .frame_id = frame_id,
            .is_navigation = std.mem.eql(u8, request_id, str(params.get("loaderId"))) and std.mem.eql(u8, kind, "Document"),
            .has_post_data = if (payload.get("hasPostData")) |h| (h == .bool and h.bool) else false,
            .post_data = post_data,
            .chain = owned_chain,
        };
        return r;
    }

    pub fn requestWillBeSentExtraInfo(self: *Collector, allocator: Allocator, params: std.json.ObjectMap) !void {
        const r = self.byRequestId(str(params.get("requestId"))) orelse return;
        if (params.get("headers")) |h| if (h == .object) try r.headers.update(allocator, h.object, false);
    }

    pub fn responseReceived(self: *Collector, allocator: Allocator, params: std.json.ObjectMap) !void {
        const r = self.byRequestId(str(params.get("requestId"))) orelse return;
        const response = params.get("response") orelse return;
        if (response != .object) return;
        try setResponse(allocator, r, response.object);
        r.response.has_extra_info = if (params.get("hasExtraInfo")) |h| (h == .bool and h.bool) else false;
    }

    pub fn responseReceivedExtraInfo(self: *Collector, allocator: Allocator, params: std.json.ObjectMap) !void {
        const r = self.byRequestId(str(params.get("requestId"))) orelse return;
        var extra: ExtraInfo = .{ .status = int(params.get("statusCode")) };
        errdefer extra.headers.deinit(allocator);
        if (params.get("headers")) |h| if (h == .object) try extra.headers.update(allocator, h.object, true);
        if (r.extra) |*old| old.headers.deinit(allocator);
        r.extra = extra;
    }

    pub fn loadingFinished(self: *Collector, params: std.json.ObjectMap) void {
        const r = self.byRequestId(str(params.get("requestId"))) orelse return;
        r.finished = true;
    }

    pub fn loadingFailed(self: *Collector, allocator: Allocator, params: std.json.ObjectMap) !void {
        const r = self.byRequestId(str(params.get("requestId"))) orelse return;
        const copy = try allocator.dupe(u8, str(params.get("errorText")));
        if (r.failure) |f| allocator.free(f);
        r.failure = copy;
        r.finished = true;
    }
};

fn copyHop(allocator: Allocator, hop: Hop) !Hop {
    const method = try allocator.dupe(u8, hop.method);
    errdefer allocator.free(method);
    const url = try allocator.dupe(u8, hop.url);
    errdefer allocator.free(url);
    return .{ .id = hop.id, .method = method, .url = url, .status = try allocator.dupe(u8, hop.status) };
}

fn setResponse(allocator: Allocator, r: *Request, response: std.json.ObjectMap) !void {
    r.response.headers.deinit(allocator);
    r.response.headers = .{};
    r.response.status = int(response.get("status"));
    if (response.get("headers")) |h| if (h == .object) try r.response.headers.update(allocator, h.object, true);
    r.response.received = true;
}

// ----------------------------------------------------------------------
// NetworkFormatter
// ----------------------------------------------------------------------

/// BODY_CONTEXT_SIZE_LIMIT.
pub const body_size_limit = 10_000;

/// convertNetworkRequestConciseToString.
pub fn concise(arena: Allocator, id: u32, method: []const u8, url: []const u8, status: []const u8) ![]const u8 {
    return std.fmt.allocPrint(arena, "reqid={d} {s} {s} [{s}]", .{ id, method, try text_util.truncateUrl(arena, url), status });
}

/// getSizeLimitedString.
pub fn sizeLimited(arena: Allocator, text: []const u8) ![]const u8 {
    return text_util.truncateText(arena, text, body_size_limit, .{ .ellipsis = "... <truncated>" });
}

/// formatHeaders' lines.
pub fn headerLines(arena: Allocator, headers: *const Headers, out: *std.ArrayList([]const u8)) !void {
    for (headers.list.items) |h| try out.append(arena, try std.fmt.allocPrint(arena, "- {s}:{s}", .{ h.name, h.value }));
}

test "headers: lower-cased names, merged in place, multi-line values joined" {
    const allocator = std.testing.allocator;
    var headers: Headers = .{};
    defer headers.deinit(allocator);
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator,
        \\{"Content-Type":"text/html","Set-Cookie":"a=1\nb=2","X-Two":"p\n q"}
    , .{});
    defer parsed.deinit();
    try headers.update(allocator, parsed.value.object, true);
    try std.testing.expectEqualStrings("text/html", headers.get("content-type").?);
    try std.testing.expectEqualStrings("a=1\n b=2", headers.get("set-cookie").?);
    try std.testing.expectEqualStrings("p, q", headers.get("x-two").?);
}
