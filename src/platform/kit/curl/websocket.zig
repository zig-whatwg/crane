//! Owned, nonblocking WebSocket transport. curl's CONNECT_ONLY easy handle
//! must remain attached to its multi handle until release (CURLOPT_CONNECT_ONLY).
//! No callbacks into Crane: the existing WebSocket owned timer polls this object.
//! Cookie and subprotocol policy stay above the platform.
const std = @import("std");
const platform = @import("platform");
const options = @import("kit_curl_share").options;
// curl/curl.h, websockets.h and header.h, translated by build.zig (addCImport).
const c = @import("curl_c");

const Socket = struct {
    allocator: std.mem.Allocator,
    easy: *c.CURL,
    multi: *c.CURLM,
    headers: ?*c.curl_slist,
    response_headers: std.ArrayList(platform.Header) = .empty,
    handshake: ?platform.WebSocketHandshake = null,

    fn of(handle: *platform.WebSocket) *Socket {
        return @ptrCast(@alignCast(handle));
    }
};

fn optional(value: platform.Str) ?[]const u8 {
    return if (value.len == 0) null else value.slice();
}

pub fn open(allocator: std.mem.Allocator, request: *const platform.WebSocketRequest) platform.HttpError!*platform.WebSocket {
    const easy = c.curl_easy_init() orelse return error.NetworkError;
    errdefer c.curl_easy_cleanup(easy);
    const multi = c.curl_multi_init() orelse return error.NetworkError;
    errdefer _ = c.curl_multi_cleanup(multi);
    const url = try allocator.dupeSentinel(u8, request.url.slice(), 0);
    defer allocator.free(url);
    if (c.curl_easy_setopt(easy, c.CURLOPT_URL, url.ptr) != c.CURLE_OK or
        c.curl_easy_setopt(easy, c.CURLOPT_CONNECT_ONLY, @as(c_long, 2)) != c.CURLE_OK)
        return error.NetworkError;

    const network = request.network;
    try options.apply(easy, allocator, .{
        .user_agent = optional(network.user_agent),
        .verify_peer = network.verify_peer,
        .verify_host = network.verify_host,
        .ca_bundle_path = if (network.has_ca_bundle) network.ca_bundle_path.slice() else null,
        .proxy = if (network.has_proxy) .{
            .url = network.proxy_url.slice(),
            .username = if (network.proxy_has_credentials) network.proxy_username.slice() else null,
            .password = if (network.proxy_has_credentials) network.proxy_password.slice() else null,
            .no_proxy = if (network.has_no_proxy) network.no_proxy.slice() else null,
        } else null,
    });

    var headers: ?*c.curl_slist = null;
    errdefer if (headers) |list| c.curl_slist_free_all(list);
    for (request.headers.slice()) |header| {
        const name = header.name.slice();
        const value = header.value.slice();
        // A transport API must not allow a caller to inject another field.
        if (name.len == 0 or std.mem.indexOfAny(u8, name, "\r\n:") != null or
            std.mem.indexOfAny(u8, value, "\r\n") != null) return error.InvalidRequest;
        const line = try std.fmt.allocPrintSentinel(allocator, "{s}: {s}", .{ name, value }, 0);
        defer allocator.free(line);
        headers = c.curl_slist_append(headers, line.ptr) orelse return error.OutOfMemory;
    }
    if (headers) |list| if (c.curl_easy_setopt(easy, c.CURLOPT_HTTPHEADER, list) != c.CURLE_OK) return error.NetworkError;

    const socket = try allocator.create(Socket);
    errdefer allocator.destroy(socket);
    if (c.curl_multi_add_handle(multi, easy) != c.CURLM_OK) return error.NetworkError;
    socket.* = .{ .allocator = allocator, .easy = easy, .multi = multi, .headers = headers };
    // Ownership passes here. A failed first poll is released by the caller,
    // never both an errdefer and the owner (the former double-free regression).
    return @ptrCast(socket);
}

pub fn pollHandshake(handle: *platform.WebSocket) platform.HttpError!?platform.WebSocketHandshake {
    const socket = Socket.of(handle);
    if (socket.handshake) |result| return result;
    var running: c_int = 0;
    if (c.curl_multi_perform(socket.multi, &running) != c.CURLM_OK) return error.NetworkError;
    var queued: c_int = 0;
    while (c.curl_multi_info_read(socket.multi, &queued)) |message| {
        if (message.*.msg != c.CURLMSG_DONE) continue;
        var status: c_long = 0;
        if (c.curl_easy_getinfo(socket.easy, c.CURLINFO_RESPONSE_CODE, &status) != c.CURLE_OK) return error.NetworkError;
        // curl owns these strings until easy_cleanup. Include 101's fields
        // (CURLH_1XX), and failed responses, for Fetch's Set-Cookie processing.
        var previous: ?*c.struct_curl_header = null;
        while (true) {
            const header = c.curl_easy_nextheader(socket.easy, c.CURLH_HEADER | c.CURLH_1XX, -1, previous);
            if (header == null) break;
            try socket.response_headers.append(socket.allocator, .{
                .name = .from(std.mem.span(header.*.name)),
                .value = .from(std.mem.span(header.*.value)),
            });
            previous = header;
        }
        socket.handshake = .{
            .head = .{ .status = @intCast(@max(status, 0)), .version = .http1_1, .headers = .from(socket.response_headers.items) },
            .verified = message.*.data.result == c.CURLE_OK and status == 101,
        };
        return socket.handshake;
    }
    return null;
}

fn connected(socket: *const Socket) bool {
    return if (socket.handshake) |result| result.verified else false;
}

pub fn send(handle: *platform.WebSocket, kind: platform.WebSocketFrameKind, bytes: platform.Bytes) platform.WebSocketError!usize {
    const socket = Socket.of(handle);
    if (!connected(socket)) return error.NetworkError;
    const flags: c_uint = switch (kind) {
        .text => c.CURLWS_TEXT,
        .binary => c.CURLWS_BINARY,
        .close => c.CURLWS_CLOSE,
        .ping => c.CURLWS_PING,
        .pong => c.CURLWS_PONG,
    };
    var sent: usize = 0;
    const result = c.curl_ws_send(socket.easy, bytes.ptr, bytes.len, &sent, 0, flags);
    if (result == c.CURLE_AGAIN) return error.WouldBlock;
    if (result != c.CURLE_OK) return error.NetworkError;
    return sent;
}

pub fn receive(handle: *platform.WebSocket, buffer: []u8) platform.WebSocketError!platform.WebSocketChunk {
    const socket = Socket.of(handle);
    if (!connected(socket)) return error.NetworkError;
    var count: usize = 0;
    var meta: ?*const c.struct_curl_ws_frame = null;
    const result = c.curl_ws_recv(socket.easy, buffer.ptr, buffer.len, &count, &meta);
    if (result == c.CURLE_AGAIN) return error.WouldBlock;
    if (result == c.CURLE_GOT_NOTHING) return error.ConnectionLost;
    if (result != c.CURLE_OK) return error.NetworkError;
    const frame = meta orelse return error.NetworkError;
    return .{
        .bytes = .from(buffer[0..count]),
        .kind = if (frame.flags & c.CURLWS_CLOSE != 0) .close else if (frame.flags & c.CURLWS_PING != 0) .ping else if (frame.flags & c.CURLWS_PONG != 0) .pong else if (frame.flags & c.CURLWS_TEXT != 0) .text else .binary,
        .bytes_left = @intCast(@max(frame.bytesleft, 0)),
        .more_fragments = frame.flags & c.CURLWS_CONT != 0,
    };
}

pub fn close(handle: *platform.WebSocket, code: u16, reason: platform.Str) void {
    // RFC6455 5.5: a control frame payload is at most 125 bytes.
    if (reason.len > 123) return;
    var payload: [125]u8 = undefined;
    std.mem.writeInt(u16, payload[0..2], code, .big);
    @memcpy(payload[2..][0..reason.len], reason.slice());
    _ = send(handle, .close, .from(payload[0 .. 2 + reason.len])) catch {};
}

pub fn release(handle: *platform.WebSocket) void {
    const socket = Socket.of(handle);
    _ = c.curl_multi_remove_handle(socket.multi, socket.easy);
    c.curl_easy_cleanup(socket.easy);
    _ = c.curl_multi_cleanup(socket.multi);
    if (socket.headers) |list| c.curl_slist_free_all(list);
    socket.response_headers.deinit(socket.allocator);
    socket.allocator.destroy(socket);
}
