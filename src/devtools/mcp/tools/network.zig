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
//! Not yet: requestFilePath and responseFilePath (the server's file access,
//! batch 3).

const std = @import("std");
const Allocator = std.mem.Allocator;
const registry = @import("../tools.zig");
const Context = registry.Context;
const Tool = registry.Tool;
const session_mod = @import("../session.zig");
const Page = session_mod.Page;
const Response = @import("../response.zig").Response;
const network = @import("../network.zig");
const console_tools = @import("console.zig");
const text_util = @import("../text.zig");

pub const list = [_]Tool{
    .{ .name = "get_network_request", .page_tool = true, .blocked_by_dialog = true, .run = getNetworkRequest },
    .{ .name = "list_network_requests", .page_tool = true, .run = listNetworkRequests },
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
    if (registry.stringArg(args, "requestFilePath") != null or registry.stringArg(args, "responseFilePath") != null) {
        return ctx.fail("requestFilePath and responseFilePath are not supported by Crane's MCP server yet.", .{});
    }
    const reqid = registry.numberArg(args, "reqid") orelse 0;
    // A falsy reqid: the request selected in the DevTools window - there is
    // none.
    if (reqid == 0) {
        try response.line("Nothing is currently selected in the DevTools Network panel.", .{});
        return;
    }
    if (reqid < 0 or reqid != @floor(reqid) or reqid > std.math.maxInt(u32)) return ctx.fail("Request not found for selected page", .{});
    const request = target.network.requests.byId(@intFromFloat(reqid)) orelse return ctx.fail("Request not found for selected page", .{});
    response.detailed_network = try detailed(ctx, target, request);
}

/// NetworkFormatter.from(request, {fetchData: true}).toStringDetailed().
fn detailed(ctx: *Context, page: *Page, request: *network.Request) ![]const u8 {
    const arena = ctx.arena;
    var lines: std.ArrayList([]const u8) = .empty;
    try lines.append(arena, try std.fmt.allocPrint(arena, "## Request {s}", .{request.url}));
    try lines.append(arena, try std.fmt.allocPrint(arena, "Status: {s}", .{try request.statusText(arena)}));
    try lines.append(arena, "### Request Headers");
    try network.headerLines(arena, &request.headers, &lines);
    if (request.has_post_data) {
        const body = try postData(ctx, page, request);
        try lines.append(arena, "### Request Body");
        try lines.append(arena, body);
    }
    if (request.hasResponse()) {
        try lines.append(arena, "### Response Headers");
        try network.headerLines(arena, request.responseHeaders(), &lines);
        const body = try responseBody(ctx, page, request);
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

/// #getFormattedResponseBody: after the load finished (5 s at most), the
/// body as UTF-8 text, "<empty response>", "<binary data>", or why not.
fn responseBody(ctx: *Context, page: *Page, request: *network.Request) ![]const u8 {
    const not_available = "<not available anymore>";
    // A redirect's response has no body; a failed load's either.
    if (request.redirected or request.failure != null) return not_available;
    const Finished = struct {
        r: *network.Request,
        fn done(self: @This()) bool {
            return self.r.finished;
        }
    };
    if (!try ctx.session.waitUntil(response_body_timeout_ms, Finished{ .r = request }, Finished.done)) {
        return std.fmt.allocPrint(ctx.arena, "<Response body not available: the response did not finish loading within {d} ms>", .{response_body_timeout_ms});
    }
    if (request.failure != null) return not_available;
    const params = try std.fmt.allocPrint(ctx.arena, "{{\"requestId\":{f}}}", .{std.json.fmt(request.request_id, .{})});
    var r = ctx.session.client.call("Network.getResponseBody", params, page.session_id, session_mod.command_timeout_ms) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return not_available,
    };
    defer r.deinit();
    const result = r.result() orelse return not_available;
    const body = session_mod.str(result.object.get("body"));
    const base64 = if (result.object.get("base64Encoded")) |b| (b == .bool and b.bool) else false;
    // Out of the answer, which is freed on return.
    var bytes: []const u8 = try ctx.arena.dupe(u8, body);
    if (base64) {
        const decoder = std.base64.standard.Decoder;
        const size = decoder.calcSizeForSlice(body) catch return not_available;
        const decoded = try ctx.arena.alloc(u8, size);
        decoder.decode(decoded, body) catch return not_available;
        bytes = decoded;
    }
    if (!std.unicode.utf8ValidateSlice(bytes)) return "<binary data>";
    if (bytes.len == 0) return "<empty response>";
    return network.sizeLimited(ctx.arena, bytes);
}

test {
    _ = text_util;
}
