//! list_network_requests and get_network_request - chrome-devtools-mcp's
//! src/tools/network.ts (chrome-devtools-mcp-v1.13.0), with McpResponse's
//! network sections (#handleNetworkRequestList,
//! #handleAttachedNetworkRequest, format's "## Network requests") and
//! NetworkFormatter's concise and detailed forms: request and response
//! bodies by Network.getRequestPostData and Network.getResponseBody once the
//! response has finished loading (5 s at most), UTF-8 text cut at 10,000
//! code units, the redirect chain newest first. Translated from the
//! TypeScript (Copyright 2025 Google LLC, Apache-2.0;
//! THIRD_PARTY_NOTICES.md). No DevTools window exists to select a request
//! in (getDevToolsData answers nothing), so a request is named by its reqid.
//!
//! requestFilePath and responseFilePath (batch 3): checked by the path
//! policy (paths.zig) before the page is resolved; the raw bodies written
//! there as .network-request and .network-response, each section saying
//! "Saved to <file>." in the body's place.

const std = @import("std");
const Allocator = std.mem.Allocator;
const fetch = @import("fetch");
const url_mod = @import("url");
const registry = @import("../tools.zig");
const Context = registry.Context;
const Tool = registry.Tool;
const session_mod = @import("../session.zig");
const Session = session_mod.Session;
const Page = session_mod.Page;
const NetworkMock = session_mod.NetworkMock;
const Response = @import("../response.zig").Response;
const network = @import("../network.zig");
const paths_mod = @import("../paths.zig");
const console_tools = @import("console.zig");
const text_util = @import("../text.zig");

pub const list = [_]Tool{
    .{ .name = "get_network_request", .page_tool = true, .blocked_by_dialog = true, .files = &.{ .{ .name = "requestFilePath" }, .{ .name = "responseFilePath" } }, .run = getNetworkRequest },
    .{ .name = "list_network_requests", .page_tool = true, .run = listNetworkRequests },
    .{ .name = "mock_network", .page_tool = true, .blocked_by_dialog = false, .files = &.{.{ .name = "body" }}, .category_network_mocks = true, .run = mockNetwork },
    .{ .name = "remove_network_mock", .page_tool = true, .blocked_by_dialog = false, .category_network_mocks = true, .run = removeNetworkMock },
};

/// RESPONSE_BODY_TIMEOUT_MS.
const response_body_timeout_ms = 5000;

fn listNetworkRequests(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const include_preserved = registry.boolArg(args, "includePreservedRequests") orelse false;
    var requests = try target.network.requests.data(ctx.arena, include_preserved);
    if (args.get("resourceTypes")) |types| if (types == .array and types.array.items.len > 0) {
        var kept: std.ArrayList(*network.Request) = .empty;
        for (requests) |r| {
            const kind = r.filterableType();
            for (types.array.items) |t| if (t == .string and std.mem.eql(u8, t.string, kind)) {
                try kept.append(ctx.arena, r);
                break;
            };
        }
        requests = kept.items;
    };
    var lines: std.ArrayList([]const u8) = .empty;
    try lines.append(ctx.arena, "## Network requests");
    if (requests.len == 0) {
        try lines.append(ctx.arena, "No requests found.");
        response.network_list = lines.items;
        return;
    }
    const shown = try console_tools.paginate(ctx.arena, requests.len, console_tools.pageSize(args), console_tools.pageIdx(args), &lines);
    for (requests[shown.start..shown.end]) |r| {
        try lines.append(ctx.arena, try network.concise(ctx.arena, r.id, r.method, r.url, try r.statusText(ctx.arena)));
    }
    response.network_list = lines.items;
}

fn getNetworkRequest(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const reqid = registry.numberArg(args, "reqid") orelse 0;
    // A falsy reqid: the request selected in the DevTools window - there is
    // none.
    if (reqid == 0) {
        try response.line("Nothing is currently selected in the DevTools Network panel.", .{});
        return;
    }
    // Looked up in McpResponse.handle: its failure is the message alone.
    if (reqid < 0 or reqid != @floor(reqid) or reqid > std.math.maxInt(u32)) return ctx.failPlain("Request not found for selected page", .{});
    const request = target.network.requests.byId(@intFromFloat(reqid)) orelse return ctx.failPlain("Request not found for selected page", .{});
    response.detailed_network = try detailed(ctx, target, request, .{
        .request = registry.stringArg(args, "requestFilePath"),
        .response = registry.stringArg(args, "responseFilePath"),
    });
}

/// Where the bodies go instead of the answer (checked paths).
const BodyFiles = struct {
    request: ?[]const u8 = null,
    response: ?[]const u8 = null,
};

/// NetworkFormatter.from(request, {fetchData: true, requestFilePath,
/// responseFilePath}).toStringDetailed().
fn detailed(ctx: *Context, page: *Page, request: *network.Request, files: BodyFiles) ![]const u8 {
    const arena = ctx.arena;
    var lines: std.ArrayList([]const u8) = .empty;
    try lines.append(arena, try std.fmt.allocPrint(arena, "## Request {s}", .{request.url}));
    try lines.append(arena, try std.fmt.allocPrint(arena, "Status: {s}", .{try request.statusText(arena)}));
    try lines.append(arena, "### Request Headers");
    try network.headerLines(arena, &request.headers, &lines);
    if (request.has_post_data) {
        const body = if (files.request) |path| try requestBodyToFile(ctx, page, request, path) else try postData(ctx, page, request);
        try lines.append(arena, "### Request Body");
        try lines.append(arena, body);
    }
    if (request.hasResponse()) {
        try lines.append(arena, "### Response Headers");
        try network.headerLines(arena, request.responseHeaders(), &lines);
        const body = if (files.response) |path| try responseBodyToFile(ctx, page, request, path) else try responseBody(ctx, page, request);
        if (body.len != 0) {
            try lines.append(arena, "### Response Body");
            try lines.append(arena, body);
        }
    }
    if (request.failure) |f| if (f.len != 0) {
        try lines.append(arena, "### Request failed with");
        try lines.append(arena, f);
    };
    if (request.chain.len > 0) {
        try lines.append(arena, "### Redirect chain");
        var indent: usize = 0;
        var i = request.chain.len;
        while (i > 0) : (indent += 1) {
            i -= 1;
            const hop = request.chain[i];
            const pad = try arena.alloc(u8, indent * 2);
            @memset(pad, ' ');
            try lines.append(arena, try std.fmt.allocPrint(arena, "{s}{s}", .{ pad, try network.concise(arena, hop.id, hop.method, hop.url, hop.status) }));
        }
    }
    return std.mem.join(arena, "\n", lines.items);
}

/// The request body: postData, else Network.getRequestPostData.
fn postData(ctx: *Context, page: *Page, request: *network.Request) ![]const u8 {
    const not_available = "<Request body not available anymore>";
    if (request.post_data) |d| if (d.len != 0) return network.sizeLimited(ctx.arena, d);
    const params = try std.fmt.allocPrint(ctx.arena, "{{\"requestId\":{f}}}", .{std.json.fmt(request.request_id, .{})});
    var r = ctx.session.client.call("Network.getRequestPostData", params, page.session_id, session_mod.command_timeout_ms) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return not_available,
    };
    defer r.deinit();
    const result = r.result() orelse return not_available;
    const data = session_mod.str(result.object.get("postData"));
    if (data.len == 0) return not_available;
    // Out of the answer, which is freed on return.
    return network.sizeLimited(ctx.arena, try ctx.arena.dupe(u8, data));
}

/// The request body saved to `path` (NetworkFormatter with requestFilePath):
/// the raw bytes (HTTPRequest.content(): Network.getRequestPostData), else
/// the decoded text, else none - "Saved to <file>." or why not.
fn requestBodyToFile(ctx: *Context, page: *Page, request: *network.Request, path: []const u8) ![]const u8 {
    const params = try std.fmt.allocPrint(ctx.arena, "{{\"requestId\":{f}}}", .{std.json.fmt(request.request_id, .{})});
    var fetched: []const u8 = "";
    if (ctx.session.client.call("Network.getRequestPostData", params, page.session_id, session_mod.command_timeout_ms)) |answer| {
        var r = answer;
        defer r.deinit();
        if (r.result()) |result| {
            const data = session_mod.str(result.object.get("postData"));
            const base64 = if (result.object.get("base64Encoded")) |b| (b == .bool and b.bool) else false;
            fetched = (try decodeBody(ctx.arena, data, base64)) orelse "";
        }
    } else |err| if (err == error.OutOfMemory) return err;
    // postData() ?? fetchPostData(): the event's text, else the fetched one.
    const text: []const u8 = request.post_data orelse fetched;
    const body = if (fetched.len != 0) fetched else text;
    if (body.len == 0) return "<Request body not available anymore>";
    return try saveBody(ctx, body, path, ".network-request");
}

/// The response body saved to `path` (NetworkFormatter with
/// responseFilePath): the bytes whatever they are, an empty body included,
/// or why there are none.
fn responseBodyToFile(ctx: *Context, page: *Page, request: *network.Request, path: []const u8) ![]const u8 {
    return switch (try readResponseBody(ctx, page, request)) {
        .bytes => |bytes| try saveBody(ctx, bytes, path, ".network-response"),
        .timed_out => try timeoutMessage(ctx),
        .unavailable => "<Response body not available anymore>",
    };
}

/// saveFile from McpResponse.handle: a failure is the message alone.
fn saveBody(ctx: *Context, body: []const u8, path: []const u8, extension: []const u8) ![]const u8 {
    const saved = ctx.session.paths.saveFile(ctx.arena, body, path, extension) catch |err| switch (err) {
        error.Denied => return ctx.failPlain("{s}", .{ctx.session.paths.message}),
        error.OutOfMemory => return error.OutOfMemory,
    };
    return std.fmt.allocPrint(ctx.arena, "Saved to {s}.", .{saved});
}

/// responseBodyTimeoutMessage.
fn timeoutMessage(ctx: *Context) ![]const u8 {
    return std.fmt.allocPrint(ctx.arena, "<Response body not available: the response did not finish loading within {d} ms>", .{response_body_timeout_ms});
}

/// #getFormattedResponseBody: after the load finished (5 s at most), the
/// body as UTF-8 text, "<empty response>", "<binary data>", or why not.
fn responseBody(ctx: *Context, page: *Page, request: *network.Request) ![]const u8 {
    const bytes = switch (try readResponseBody(ctx, page, request)) {
        .bytes => |b| b,
        .timed_out => return timeoutMessage(ctx),
        .unavailable => return "<not available anymore>",
    };
    if (!std.unicode.utf8ValidateSlice(bytes)) return "<binary data>";
    if (bytes.len == 0) return "<empty response>";
    return network.sizeLimited(ctx.arena, bytes);
}

const BodyRead = union(enum) {
    /// In `ctx.arena`.
    bytes: []const u8,
    /// ResponseBodyTimeoutError.
    timed_out,
    /// HTTPResponse.buffer() threw.
    unavailable,
};

/// #readResponseBody: HTTPResponse.buffer() raced with the timeout - the
/// body once the load finished (Network.getResponseBody, base64 decoded).
fn readResponseBody(ctx: *Context, page: *Page, request: *network.Request) !BodyRead {
    // A redirect's response has no body; a failed load's either.
    if (request.redirected or request.failure != null) return .unavailable;
    const Finished = struct {
        r: *network.Request,
        fn done(self: @This()) bool {
            return self.r.finished;
        }
    };
    if (!try ctx.session.waitUntil(response_body_timeout_ms, Finished{ .r = request }, Finished.done)) return .timed_out;
    if (request.failure != null) return .unavailable;
    const params = try std.fmt.allocPrint(ctx.arena, "{{\"requestId\":{f}}}", .{std.json.fmt(request.request_id, .{})});
    var r = ctx.session.client.call("Network.getResponseBody", params, page.session_id, session_mod.command_timeout_ms) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return .unavailable,
    };
    defer r.deinit();
    const result = r.result() orelse return .unavailable;
    const body = session_mod.str(result.object.get("body"));
    const base64 = if (result.object.get("base64Encoded")) |b| (b == .bool and b.bool) else false;
    return .{ .bytes = (try decodeBody(ctx.arena, body, base64)) orelse return .unavailable };
}

/// A CDP body's bytes, copied out of its answer (which is freed on return);
/// null when its base64 does not decode.
fn decodeBody(arena: Allocator, body: []const u8, base64: bool) !?[]const u8 {
    if (!base64) return try arena.dupe(u8, body);
    const decoder = std.base64.standard.Decoder;
    const size = decoder.calcSizeForSlice(body) catch return null;
    const decoded = try arena.alloc(u8, size);
    decoder.decode(decoded, body) catch return null;
    return decoded;
}

// ============================================================================
// mock_network & remove_network_mock (--categoryNetworkMocks)
// Translated from chrome-devtools-mcp v1.13.0 src/tools/network.ts,
// src/NetworkOverrideManager.ts, src/formatters/NetworkOverridesFormatter.ts,
// src/utils/network.ts, src/utils/url.ts (Copyright 2026 Google LLC,
// Apache-2.0; THIRD_PARTY_NOTICES.md).
// ============================================================================

const default_url_pattern = "*://*:*/*";

const measurement_warning =
    "Network mocks disable the page HTTP cache and intercept every request. " ++
    "Replacement resources use altered delivery paths; these timings do not " ++
    "represent normal production loading. Compare baseline and candidate using " ++
    "the same mock mechanism, cache policy, and throttling.";

fn inferContentType(file_path: []const u8) []const u8 {
    const ext = paths_mod.extname(file_path);
    const map = [_]struct { []const u8, []const u8 }{
        .{ ".css", "text/css; charset=utf-8" },
        .{ ".gif", "image/gif" },
        .{ ".htm", "text/html; charset=utf-8" },
        .{ ".html", "text/html; charset=utf-8" },
        .{ ".ico", "image/x-icon" },
        .{ ".jpeg", "image/jpeg" },
        .{ ".jpg", "image/jpeg" },
        .{ ".js", "application/javascript; charset=utf-8" },
        .{ ".json", "application/json; charset=utf-8" },
        .{ ".mjs", "application/javascript; charset=utf-8" },
        .{ ".png", "image/png" },
        .{ ".svg", "image/svg+xml" },
        .{ ".txt", "text/plain; charset=utf-8" },
        .{ ".wasm", "application/wasm" },
        .{ ".webp", "image/webp" },
        .{ ".xml", "application/xml; charset=utf-8" },
    };
    for (map) |entry| {
        if (std.ascii.eqlIgnoreCase(ext, entry[0])) return entry[1];
    }
    return "application/octet-stream";
}

fn mockNetwork(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const route = registry.stringArg(args, "route");
    const resource_type = registry.stringArg(args, "resourceType");
    // checkFiles turns whitespace-only `body` into `.null`.
    if (args.get("body")) |b| if (b == .null) {
        return ctx.failPlain("Input validation error: Invalid arguments for tool mock_network: body: Too small: expected string to have >=1 characters", .{});
    };
    const body_path = registry.stringArg(args, "body");
    const upstream = registry.stringArg(args, "upstream");

    if (route) |r| {
        if (try validateRoute(ctx.arena, r)) |err_msg| return ctx.fail("{s}", .{err_msg});
    }
    if (body_path != null and upstream != null) {
        return ctx.fail("body and upstream are mutually exclusive.", .{});
    }

    if (upstream) |up_url| {
        if (!isHttpOrHttpsUrl(ctx.arena, up_url)) {
            return ctx.fail("Unsupported URL protocol: {s}", .{up_url});
        }
        const mock_ptr = try upsertMock(ctx, target, route orelse default_url_pattern, resource_type, .upstream, up_url, "");
        try response.line("Network mock configured. Reload or navigate the page to apply it.", .{});
        try response.line("{s}", .{try formatMocks(ctx.arena, &.{mock_ptr.*})});
        return;
    }

    if (body_path) |path| {
        // Validate & read eagerly, matching NetworkOverrideManager.#createOverride.
        _ = ctx.session.paths.readFile(ctx.arena, path) catch |err| switch (err) {
            error.Denied => return ctx.fail("{s}", .{ctx.session.paths.message}),
            error.OutOfMemory => return error.OutOfMemory,
        };
        const content_type = inferContentType(path);
        const mock_ptr = try upsertMock(ctx, target, route orelse default_url_pattern, resource_type, .file, path, content_type);
        try response.line("Network mock configured. Reload or navigate the page to apply it.", .{});
        try response.line("{s}", .{try formatMocks(ctx.arena, &.{mock_ptr.*})});
        return;
    }

    // Inspection mode: list mocks matching exact route/resourceType filters.
    var matched: std.ArrayList(NetworkMock) = .empty;
    for (target.network_mocks.overrides.items) |m| {
        if (matchesFilter(&m, route, resource_type)) {
            try matched.append(ctx.arena, m);
        }
    }
    if (matched.items.len == 0) {
        try response.line("No network mocks match these filters.", .{});
        return;
    }
    try response.line("{s}", .{try formatMocks(ctx.arena, matched.items)});
}

fn removeNetworkMock(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const route = registry.stringArg(args, "route");
    const resource_type = registry.stringArg(args, "resourceType");
    if (route) |r| {
        if (try validateRoute(ctx.arena, r)) |err_msg| return ctx.fail("{s}", .{err_msg});
    }

    const allocator = ctx.session.allocator;
    var removed: usize = 0;
    var i: usize = 0;
    while (i < target.network_mocks.overrides.items.len) {
        if (matchesFilter(&target.network_mocks.overrides.items[i], route, resource_type)) {
            var item = target.network_mocks.overrides.orderedRemove(i);
            item.deinit(allocator);
            removed += 1;
            continue;
        }
        i += 1;
    }

    if (removed > 0 and target.network_mocks.overrides.items.len == 0) {
        try deactivateMocks(ctx, target);
    }

    try response.line("Removed {d} network {s}.", .{ removed, if (removed == 1) "mock" else "mocks" });
}

fn matchesFilter(m: *const NetworkMock, route: ?[]const u8, resource_type: ?[]const u8) bool {
    if (route) |r| if (!std.mem.eql(u8, m.url_pattern, r)) return false;
    if (resource_type) |rt| {
        const stored = m.resource_type orelse return false;
        if (!std.mem.eql(u8, stored, rt)) return false;
    }
    return true;
}

fn upsertMock(
    ctx: *Context,
    page: *Page,
    url_pattern: []const u8,
    resource_type: ?[]const u8,
    kind: NetworkMock.Kind,
    target_val: []const u8,
    content_type: []const u8,
) !*NetworkMock {
    const allocator = ctx.session.allocator;
    const state = &page.network_mocks;

    var existing_idx: ?usize = null;
    for (state.overrides.items, 0..) |m, idx| {
        const rt_match = if (m.resource_type == null and resource_type == null)
            true
        else if (m.resource_type != null and resource_type != null)
            std.mem.eql(u8, m.resource_type.?, resource_type.?)
        else
            false;
        if (std.mem.eql(u8, m.url_pattern, url_pattern) and rt_match) {
            existing_idx = idx;
            break;
        }
    }

    const id: u32 = if (existing_idx) |idx| state.overrides.items[idx].id else state.next_id;
    const pat_copy = try allocator.dupe(u8, url_pattern);
    errdefer allocator.free(pat_copy);
    const rt_copy: ?[]u8 = if (resource_type) |rt| try allocator.dupe(u8, rt) else null;
    errdefer if (rt_copy) |rt| allocator.free(rt);
    const target_copy = try allocator.dupe(u8, target_val);
    errdefer allocator.free(target_copy);
    const ct_copy = try allocator.dupe(u8, content_type);
    errdefer allocator.free(ct_copy);

    try activateMocks(ctx, page);

    if (existing_idx) |idx| {
        var old = state.overrides.orderedRemove(idx);
        old.deinit(allocator);
    } else {
        state.next_id += 1;
    }

    try state.overrides.append(allocator, .{
        .id = id,
        .url_pattern = pat_copy,
        .resource_type = rt_copy,
        .kind = kind,
        .target = target_copy,
        .content_type = ct_copy,
    });
    return &state.overrides.items[state.overrides.items.len - 1];
}

fn activateMocks(ctx: *Context, page: *Page) !void {
    const state = &page.network_mocks;
    if (!state.cache_disabled) {
        var r = try ctx.session.client.call("Network.setCacheDisabled", "{\"cacheDisabled\":true}", page.session_id, session_mod.command_timeout_ms);
        defer r.deinit();
        if (r.errorMessage()) |msg| return ctx.fail("Protocol error (Network.setCacheDisabled): {s}", .{msg});
        state.cache_disabled = true;
    }
    if (!state.active) {
        var r = try ctx.session.client.call("Fetch.enable", "{\"patterns\":[{\"urlPattern\":\"*\"}]}", page.session_id, session_mod.command_timeout_ms);
        defer r.deinit();
        if (r.errorMessage()) |msg| return ctx.fail("Protocol error (Fetch.enable): {s}", .{msg});
        state.active = true;
    }
}

fn deactivateMocks(ctx: *Context, page: *Page) !void {
    const state = &page.network_mocks;
    if (state.active) {
        var r = try ctx.session.client.call("Fetch.disable", "{}", page.session_id, session_mod.command_timeout_ms);
        defer r.deinit();
        state.active = false;
    }
    if (state.cache_disabled) {
        var r = try ctx.session.client.call("Network.setCacheDisabled", "{\"cacheDisabled\":false}", page.session_id, session_mod.command_timeout_ms);
        defer r.deinit();
        state.cache_disabled = false;
    }
}

fn formatMocks(arena: Allocator, mocks: []const NetworkMock) ![]const u8 {
    if (mocks.len == 0) return "";
    var lines: std.ArrayList([]const u8) = .empty;
    try lines.append(arena, measurement_warning);
    for (mocks) |m| {
        const source = switch (m.kind) {
            .file => try std.fmt.allocPrint(arena, "{s} ({s})", .{ m.target, m.content_type }),
            .upstream => m.target,
        };
        const rt = if (m.resource_type) |t| try std.fmt.allocPrint(arena, " [{s}]", .{t}) else "";
        try lines.append(arena, try std.fmt.allocPrint(arena, "{s}{s} -> {s}", .{ m.url_pattern, rt, source }));
        try lines.append(arena, try std.fmt.allocPrint(arena, "  Since configured: {d} hits, {d} errors.", .{ m.hits, m.errors }));
        if (m.last_error) |e| {
            try lines.append(arena, try std.fmt.allocPrint(arena, "  Last error: {s}", .{e}));
        }
        if (m.hits == 0) {
            try lines.append(arena, if (m.navigations > 0)
                "  Warning: no requests matched after navigation. Check the full-URL pattern, resource type, and service worker."
            else
                "  No matches yet. Navigate or reload to verify this rule.");
        }
    }
    return std.mem.join(arena, "\n", lines.items);
}

/// Handle `Fetch.requestPaused` for active network mocks on `page`.
/// Uses `session.client.post` (non-blocking) so it is safe inside `onEvent`.
pub fn handleRequestPaused(session: *Session, page: *Page, params: std.json.ObjectMap) !void {
    const request_id = session_mod.str(params.get("requestId"));
    if (request_id.len == 0) return;

    var scratch = std.heap.ArenaAllocator.init(session.allocator);
    defer scratch.deinit();
    const arena = scratch.allocator();

    const frame_id = session_mod.str(params.get("frameId"));
    const resource_type = mapCdpResourceType(session_mod.str(params.get("resourceType")));
    const req_val = params.get("request") orelse {
        try postContinue(session, arena, page.session_id, request_id);
        return;
    };
    if (req_val != .object) {
        try postContinue(session, arena, page.session_id, request_id);
        return;
    }
    const req_url = session_mod.str(req_val.object.get("url"));
    const req_method = session_mod.str(req_val.object.get("method"));

    if (std.mem.eql(u8, resource_type, "document") and std.mem.eql(u8, frame_id, page.mainFrameId())) {
        for (page.network_mocks.overrides.items) |*m| {
            m.navigations += 1;
        }
    }

    // Most recently updated matching mock wins.
    var matched: ?*NetworkMock = null;
    var i = page.network_mocks.overrides.items.len;
    while (i > 0) {
        i -= 1;
        const m = &page.network_mocks.overrides.items[i];
        if (!matchUrlPattern(m.url_pattern, req_url)) continue;
        if (m.resource_type) |rt| if (!std.mem.eql(u8, rt, resource_type)) continue;
        matched = m;
        break;
    }

    const mock = matched orelse {
        try postContinue(session, arena, page.session_id, request_id);
        return;
    };

    mock.hits += 1;
    switch (mock.kind) {
        .file => {
            const bytes = session.paths.readFile(arena, mock.target) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.Denied => {
                    try recordMockError(session.allocator, mock, session.paths.message);
                    try postFail(session, arena, page.session_id, request_id);
                    return;
                },
            };
            const headers = [_]FulfillHeader{
                .{ .name = "Content-Type", .value = mock.content_type },
                .{ .name = "Cache-Control", .value = "no-store" },
            };
            try postFulfill(session, arena, page.session_id, request_id, 200, &headers, bytes);
        },
        .upstream => {
            if (!std.mem.eql(u8, req_method, "GET") and !std.mem.eql(u8, req_method, "HEAD")) {
                try recordMockError(session.allocator, mock, "Upstream mocks only support GET and HEAD requests.");
                try postFail(session, arena, page.session_id, request_id);
                return;
            }
            fulfillUpstream(session, arena, page.session_id, request_id, req_url, req_method, req_val.object.get("headers"), mock) catch |err| {
                if (err == error.OutOfMemory) return error.OutOfMemory;
                const msg = std.fmt.allocPrint(arena, "{t}", .{err}) catch "upstream fetch failed";
                try recordMockError(session.allocator, mock, msg);
                try postFail(session, arena, page.session_id, request_id);
            };
        },
    }
}

const FulfillHeader = struct { name: []const u8, value: []const u8 };

fn recordMockError(allocator: Allocator, mock: *NetworkMock, detail: []const u8) !void {
    mock.errors += 1;
    const msg = try std.fmt.allocPrint(allocator, "Failed to load {s}: {s}", .{ mock.target, detail });
    if (mock.last_error) |old| allocator.free(old);
    mock.last_error = msg;
}

fn postContinue(session: *Session, arena: Allocator, session_id: []const u8, request_id: []const u8) !void {
    const body = try std.fmt.allocPrint(arena, "{{\"requestId\":{f}}}", .{std.json.fmt(request_id, .{})});
    try session.client.post("Fetch.continueRequest", body, session_id);
}

fn postFail(session: *Session, arena: Allocator, session_id: []const u8, request_id: []const u8) !void {
    const body = try std.fmt.allocPrint(arena, "{{\"requestId\":{f},\"errorReason\":\"Failed\"}}", .{std.json.fmt(request_id, .{})});
    try session.client.post("Fetch.failRequest", body, session_id);
}

fn postFulfill(
    session: *Session,
    arena: Allocator,
    session_id: []const u8,
    request_id: []const u8,
    status: u16,
    headers: []const FulfillHeader,
    body_bytes: []const u8,
) !void {
    const b64_len = std.base64.standard.Encoder.calcSize(body_bytes.len);
    const b64 = try arena.alloc(u8, b64_len);
    _ = std.base64.standard.Encoder.encode(b64, body_bytes);

    var out: std.Io.Writer.Allocating = .init(arena);
    const w = &out.writer;
    try w.print("{{\"requestId\":{f},\"responseCode\":{d},\"responseHeaders\":[", .{ std.json.fmt(request_id, .{}), status });
    for (headers, 0..) |h, idx| {
        if (idx != 0) try w.writeAll(",");
        try w.print("{{\"name\":{f},\"value\":{f}}}", .{ std.json.fmt(h.name, .{}), std.json.fmt(h.value, .{}) });
    }
    try w.print("],\"body\":{f}}}", .{std.json.fmt(b64, .{})});
    try session.client.post("Fetch.fulfillRequest", out.written(), session_id);
}

fn fulfillUpstream(
    session: *Session,
    arena: Allocator,
    session_id: []const u8,
    request_id: []const u8,
    req_url: []const u8,
    method: []const u8,
    req_headers_val: ?std.json.Value,
    mock: *const NetworkMock,
) !void {
    const same_origin = sameOrigin(arena, req_url, mock.target);
    var forward_headers: std.ArrayList(fetch.network.NetworkRequest.Header) = .empty;
    if (req_headers_val) |hv| if (hv == .object) {
        var it = hv.object.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.* != .string) continue;
            const name = entry.key_ptr.*;
            if (std.ascii.eqlIgnoreCase(name, "accept-encoding")) continue;
            if (same_origin or isCrossOriginRedirectHeader(name)) {
                try forward_headers.append(arena, .{ .name = name, .value = entry.value_ptr.string });
            }
        }
    };

    const backend = try fetch.network.LibcurlBackend.init(session.allocator);
    defer backend.deinit();
    const request: fetch.NetworkRequest = .{
        .url = mock.target,
        .method = method,
        .headers = forward_headers.items,
        .body = null,
        .connect_timeout_ms = 5_000,
        .timeout_ms = 30_000,
        .follow_redirects = true,
        .max_redirects = 20,
    };
    var resp = try backend.getBackend().send(session.allocator, &request);
    defer resp.deinit();

    var resp_headers: std.ArrayList(FulfillHeader) = .empty;
    for (resp.headers) |h| {
        if (std.ascii.eqlIgnoreCase(h.name, "content-encoding")) continue;
        if (std.ascii.eqlIgnoreCase(h.name, "content-length")) continue;
        try resp_headers.append(arena, .{ .name = h.name, .value = h.value });
    }
    try postFulfill(session, arena, session_id, request_id, resp.status, resp_headers.items, resp.body orelse "");
}

fn isCrossOriginRedirectHeader(name: []const u8) bool {
    const allowed = [_][]const u8{ "accept", "accept-language", "cache-control", "origin", "pragma", "range", "user-agent" };
    for (allowed) |a| if (std.ascii.eqlIgnoreCase(name, a)) return true;
    return false;
}

fn sameOrigin(arena: Allocator, a: []const u8, b: []const u8) bool {
    const ua = url_mod.parser.basic_url_parser.parse(arena, a, null) catch return false;
    const ub = url_mod.parser.basic_url_parser.parse(arena, b, null) catch return false;
    if (!std.mem.eql(u8, ua.scheme(), ub.scheme())) return false;
    if (ua.port != ub.port) return false;
    const ha = if (ua.host) |h| (url_mod.host_serializer.serializeHost(arena, h) catch return false) else "";
    const hb = if (ub.host) |h| (url_mod.host_serializer.serializeHost(arena, h) catch return false) else "";
    return std.mem.eql(u8, ha, hb);
}

fn isHttpOrHttpsUrl(arena: Allocator, raw: []const u8) bool {
    const parsed = url_mod.parser.basic_url_parser.parse(arena, raw, null) catch return false;
    const scheme = parsed.scheme();
    return std.mem.eql(u8, scheme, "http") or std.mem.eql(u8, scheme, "https");
}

fn mapCdpResourceType(cdp: []const u8) []const u8 {
    const map = [_]struct { []const u8, []const u8 }{
        .{ "Document", "document" },
        .{ "Stylesheet", "stylesheet" },
        .{ "Image", "image" },
        .{ "Media", "media" },
        .{ "Font", "font" },
        .{ "Script", "script" },
        .{ "TextTrack", "texttrack" },
        .{ "XHR", "xhr" },
        .{ "Fetch", "fetch" },
        .{ "Prefetch", "prefetch" },
        .{ "EventSource", "eventsource" },
        .{ "Manifest", "manifest" },
        .{ "SignedExchange", "signedexchange" },
        .{ "Ping", "ping" },
        .{ "CSPViolationReport", "cspviolationreport" },
        .{ "Preflight", "preflight" },
        .{ "FedCM", "fedcm" },
    };
    for (map) |entry| {
        if (std.ascii.eqlIgnoreCase(cdp, entry[0])) return entry[1];
    }
    return "other";
}

// ----------------------------------------------------------------------------
// URLPattern validation & wildcard matching (src/utils/url.ts validateUrlPatterns)
// ----------------------------------------------------------------------------

const ParsedPattern = struct {
    scheme: []const u8,
    host: []const u8,
    port: ?[]const u8,
    pathname: []const u8,
    search: ?[]const u8,
    hash: ?[]const u8,
};

fn parsePattern(raw: []const u8) ?ParsedPattern {
    if (raw.len == 0 or raw[0] == '/') return null;
    const sep = std.mem.indexOf(u8, raw, "://") orelse return null;
    const scheme = raw[0..sep];
    if (scheme.len == 0) return null;
    var rest = raw[sep + 3 ..];

    var hash: ?[]const u8 = null;
    if (std.mem.indexOfScalar(u8, rest, '#')) |h_idx| {
        hash = rest[h_idx + 1 ..];
        rest = rest[0..h_idx];
    }
    var search: ?[]const u8 = null;
    if (std.mem.indexOfScalar(u8, rest, '?')) |q_idx| {
        search = rest[q_idx + 1 ..];
        rest = rest[0..q_idx];
    }
    var pathname: []const u8 = "/";
    if (std.mem.indexOfScalar(u8, rest, '/')) |p_idx| {
        pathname = rest[p_idx..];
        rest = rest[0..p_idx];
    }
    // Strip optional userinfo (`user:pass@`) if present.
    if (std.mem.lastIndexOfScalar(u8, rest, '@')) |at_idx| {
        rest = rest[at_idx + 1 ..];
    }
    if (rest.len == 0) return null;

    var host = rest;
    var port: ?[]const u8 = null;
    if (rest[0] == '[') {
        // IPv6 literal `[...]` optionally followed by `:port`.
        const close = std.mem.indexOfScalar(u8, rest, ']') orelse return null;
        host = rest[0 .. close + 1];
        if (close + 1 < rest.len) {
            if (rest[close + 1] != ':') return null;
            port = rest[close + 2 ..];
        }
    } else if (std.mem.lastIndexOfScalar(u8, rest, ':')) |c_idx| {
        host = rest[0..c_idx];
        port = rest[c_idx + 1 ..];
    }
    if (host.len == 0) return null;
    return .{
        .scheme = scheme,
        .host = host,
        .port = port,
        .pathname = pathname,
        .search = search,
        .hash = hash,
    };
}

fn hasPartialIpv4Hostname(host: []const u8) bool {
    var parts: [5][]const u8 = undefined;
    var count: usize = 0;
    var it = std.mem.splitScalar(u8, host, '.');
    while (it.next()) |part| {
        if (count >= 5) return false;
        parts[count] = part;
        count += 1;
    }
    if (count != 4) return false;
    var has_wildcard = false;
    var has_numeric = false;
    for (parts[0..4]) |p| {
        if (p.len == 0) return false;
        var all_digits = true;
        for (p) |c| {
            if (c == '*') {
                has_wildcard = true;
                all_digits = false;
            } else if (!std.ascii.isDigit(c)) {
                return false;
            }
        }
        if (all_digits) has_numeric = true;
    }
    return has_wildcard and has_numeric;
}

fn hasNamedGroup(component: []const u8) bool {
    var i: usize = 0;
    while (i + 1 < component.len) : (i += 1) {
        if (component[i] == '\\') {
            i += 1;
            continue;
        }
        if (component[i] == ':') {
            const next = component[i + 1];
            if (std.ascii.isAlphabetic(next) or next == '_' or next == '$') return true;
        }
    }
    return false;
}

/// validateUrlPatterns for `route`: returns null when valid, else an error message.
pub fn validateRoute(arena: Allocator, raw: []const u8) Allocator.Error!?[]const u8 {
    if (std.mem.indexOfAny(u8, raw, "()") != null) {
        return try std.fmt.allocPrint(arena, "Invalid route \"{s}\": a regexp group is not enforced on redirects or subresources. Use an exact value or a \"*\" wildcard instead.", .{raw});
    }
    const parsed = parsePattern(raw) orelse {
        return try std.fmt.allocPrint(arena, "Invalid route \"{s}\": Invalid URLPattern.", .{raw});
    };
    if (hasPartialIpv4Hostname(parsed.host)) {
        return try std.fmt.allocPrint(arena, "Invalid route \"{s}\": a partial IPv4 wildcard is not enforced on redirects or subresources. Use an exact IPv4 address or a \"*\" wildcard instead.", .{raw});
    }
    if (parsed.port) |p| {
        if (p.len > 0 and !std.mem.eql(u8, p, "*")) {
            if (hasNamedGroup(p) or (p[0] == ':')) {
                return try std.fmt.allocPrint(arena, "Invalid route \"{s}\": a \":name\" named group is not enforced on redirects or subresources. Use an exact value or a \"*\" wildcard instead.", .{raw});
            }
            for (p) |c| if (!std.ascii.isDigit(c) and c != '*') {
                return try std.fmt.allocPrint(arena, "Invalid route \"{s}\": Invalid port.", .{raw});
            };
        }
    }
    const components = [_]?[]const u8{ parsed.scheme, parsed.host, parsed.pathname, parsed.search, parsed.hash };
    for (components) |comp| {
        if (comp) |c| if (hasNamedGroup(c)) {
            return try std.fmt.allocPrint(arena, "Invalid route \"{s}\": a \":name\" named group is not enforced on redirects or subresources. Use an exact value or a \"*\" wildcard instead.", .{raw});
        };
    }
    return null;
}

fn defaultPortFor(scheme: []const u8) []const u8 {
    if (std.ascii.eqlIgnoreCase(scheme, "http") or std.ascii.eqlIgnoreCase(scheme, "ws")) return "80";
    if (std.ascii.eqlIgnoreCase(scheme, "https") or std.ascii.eqlIgnoreCase(scheme, "wss")) return "443";
    return "";
}

fn effectivePort(scheme: []const u8, raw_port: ?[]const u8) []const u8 {
    const p = raw_port orelse return "";
    if (p.len == 0) return "";
    if (std.mem.eql(u8, p, defaultPortFor(scheme))) return "";
    return p;
}

pub fn matchUrlPattern(pattern: []const u8, target_url: []const u8) bool {
    const pat = parsePattern(pattern) orelse return false;
    const tgt = parsePattern(target_url) orelse return false;
    if (!wildcardMatch(pat.scheme, tgt.scheme, true)) return false;
    if (!wildcardMatch(pat.host, tgt.host, true)) return false;
    const pat_port: []const u8 = if (pat.port) |p|
        (if (std.mem.eql(u8, p, "*")) "*" else effectivePort(pat.scheme, p))
    else
        "";
    const tgt_port = effectivePort(tgt.scheme, tgt.port);
    if (!wildcardMatch(pat_port, tgt_port, false)) return false;
    if (!wildcardMatch(pat.pathname, tgt.pathname, false)) return false;
    if (pat.search) |ps| {
        const ts = tgt.search orelse "";
        if (!wildcardMatch(ps, ts, false)) return false;
    }
    if (pat.hash) |ph| {
        const th = tgt.hash orelse "";
        if (!wildcardMatch(ph, th, false)) return false;
    }
    return true;
}

fn wildcardMatch(pattern: []const u8, text: []const u8, ignore_case: bool) bool {
    var pi: usize = 0;
    var ti: usize = 0;
    var star_pi: ?usize = null;
    var star_ti: usize = 0;
    while (ti < text.len) {
        if (pi < pattern.len and pattern[pi] == '*') {
            star_pi = pi;
            star_ti = ti;
            pi += 1;
        } else if (pi < pattern.len and charEq(pattern[pi], text[ti], ignore_case)) {
            pi += 1;
            ti += 1;
        } else if (star_pi) |sp| {
            pi = sp + 1;
            star_ti += 1;
            ti = star_ti;
        } else {
            return false;
        }
    }
    while (pi < pattern.len and pattern[pi] == '*') pi += 1;
    return pi == pattern.len;
}

fn charEq(a: u8, b: u8, ignore_case: bool) bool {
    return if (ignore_case) std.ascii.toLower(a) == std.ascii.toLower(b) else a == b;
}

test "mock_network route validation and URLPattern matching" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    // Valid routes
    try std.testing.expectEqual(@as(?[]const u8, null), try validateRoute(arena, "*://*:*/*"));
    try std.testing.expectEqual(@as(?[]const u8, null), try validateRoute(arena, "https://example.com/app.js"));
    try std.testing.expectEqual(@as(?[]const u8, null), try validateRoute(arena, "http://127.0.0.1:8080/api/*"));

    // Invalid routes
    try std.testing.expect((try validateRoute(arena, "/relative/path.js")) != null);
    try std.testing.expect(std.mem.indexOf(u8, (try validateRoute(arena, "https://example.com/:id")).?, ":name") != null);
    try std.testing.expect(std.mem.indexOf(u8, (try validateRoute(arena, "https://example.com/(a|b)")).?, "regexp") != null);
    try std.testing.expect(std.mem.indexOf(u8, (try validateRoute(arena, "http://127.0.0.*/*")).?, "partial IPv4") != null);

    // Matching
    try std.testing.expect(matchUrlPattern("*://*:*/*", "http://127.0.0.1:12345/a/b?x=1#h"));
    try std.testing.expect(matchUrlPattern("*://*:*/app.js", "http://127.0.0.1:8080/app.js?v=2"));
    try std.testing.expect(!matchUrlPattern("*://*:*/app.js", "http://127.0.0.1:8080/other.js"));
    try std.testing.expect(matchUrlPattern("https://example.com/api/*", "https://example.com:443/api/users"));
    try std.testing.expect(!matchUrlPattern("https://example.com/api/*", "http://example.com/api/users"));
    try std.testing.expect(matchUrlPattern("http://127.0.0.1:8080/data.json?k=*", "http://127.0.0.1:8080/data.json?k=abc"));
    try std.testing.expect(!matchUrlPattern("http://127.0.0.1:8080/data.json?k=*", "http://127.0.0.1:8080/data.json?other=1"));
}
