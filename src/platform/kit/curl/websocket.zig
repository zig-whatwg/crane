//! Owned, nonblocking WebSocket transport (the platform protocol's
//! openWebSocket .. releaseWebSocket). No callbacks into Crane: the
//! WebSocket's owned timer polls it. Cookie, Origin and subprotocol policy
//! stay above the platform (src/websocket/transport.zig).
//!
//! curl makes the connection - DNS, the proxy tunnel, TLS with the Browser's
//! trust store - and hands it over raw (CURLOPT_CONNECT_ONLY 1); the
//! transport speaks the WebSocket Protocol on it itself, as every browser
//! does: the opening handshake (websocket_handshake.zig) and the framing
//! (websocket_frames.zig). A wss: connection offers h2 in ALPN when the
//! platform has HTTP/2; when the server chooses it and its SETTINGS enable
//! the extended CONNECT, the WebSocket runs on an HTTP/2 stream (RFC 8441,
//! websocket_h2.zig), and when they do not, on a fresh HTTP/1.1 connection -
//! Firefox's model (websocket_h2.zig says more). libcurl's own WebSocket
//! (curl_ws_*) is HTTP/1.1 only (lib/ws.c), which is why it is not used.
//!
//! The easy handle stays attached to its multi handle until release
//! (CURLOPT_CONNECT_ONLY: curl_easy_send/curl_easy_recv need it).

const std = @import("std");
const platform = @import("platform");
const platform_options = @import("platform_options");
const share = @import("kit_curl_share");
const options = share.options;
const frames = share.websocket_frames;
const handshake = share.websocket_handshake;
// curl/curl.h, websockets.h and header.h, translated by build.zig (addCImport).
const c = @import("curl_c");

/// Whether a WebSocket may run over HTTP/2: the platform was built with it
/// (its nghttp2 is the one libcurl links).
const http2 = platform_options.http2;
const h2 = if (http2) share.websocket_h2 else struct {
    pub const Session = void;
};

/// How many bytes the transport holds for the network before a send stops
/// taking more (the platform's send: "accept part of a frame without
/// waiting"); bufferedAmount counts the rest. libcurl's WebSocket kept a
/// send buffer of the same order (lib/ws.c, WS_CHUNK_SIZE x WS_CHUNK_COUNT).
const max_buffered = 64 * 1024;

/// One read from the connection.
const read_size = 16 * 1024;

const Phase = enum {
    /// curl is connecting (and, for wss:, handshaking TLS).
    connecting,
    /// HTTP/1.1: the opening handshake's request is going out and its
    /// response coming in.
    h1_handshake,
    /// HTTP/2: the connection preface is out; waiting for the server's
    /// SETTINGS.
    h2_settings,
    /// HTTP/2: the extended CONNECT is out; waiting for its response.
    h2_handshake,
    /// The handshake is done (`result` says how).
    done,
};

const Socket = struct {
    allocator: std.mem.Allocator,
    multi: *c.CURLM,
    easy: ?*c.CURL = null,
    phase: Phase = .connecting,
    /// The request, copied: openWebSocket only borrows it.
    secure: bool,
    host: []u8,
    port: ?u16,
    resource: []u8,
    connect_url: [:0]u8,
    authorization: ?[]u8,
    fields: []handshake.Field,
    network: Network,
    /// ALPN may offer h2 (a wss: URL, a platform with HTTP/2, and no
    /// fallback to HTTP/1.1 yet).
    offer_h2: bool,
    key: handshake.Key,
    /// Bytes for the connection, from `out_start` on.
    out: std.ArrayList(u8) = .empty,
    out_start: usize = 0,
    /// HTTP/1.1: bytes from the connection, from `in_start` on (the
    /// response head, then frames).
    in: std.ArrayList(u8) = .empty,
    in_start: usize = 0,
    /// HTTP/2: the session, once ALPN chose h2.
    session: if (http2) ?*h2.Session else void = if (http2) null else {},
    /// The response head's bytes and what parseHead folded (HTTP/1.1).
    head_bytes: std.ArrayList(u8) = .empty,
    folded: std.ArrayList(u8) = .empty,
    response_headers: std.ArrayList(platform.Header) = .empty,
    result: ?platform.WebSocketHandshake = null,
    encoder: frames.Encoder = .{},
    decoder: frames.Decoder = .{},
    /// A Ping to answer once the frame being sent is done (5.5.2: "an
    /// endpoint MUST send a Pong frame in response"), whole.
    pong: ?Control = null,
    /// The connection ended (curl_easy_recv read 0 bytes, or the HTTP/2
    /// stream ended).
    eof: bool = false,

    const Control = struct {
        bytes: [frames.max_control_payload]u8 = undefined,
        len: usize = 0,
    };

    fn of(handle: *platform.WebSocket) *Socket {
        return @ptrCast(@alignCast(handle));
    }
};

/// The network options a connection is made with, copied (a fallback to
/// HTTP/1.1 makes a second connection after openWebSocket returned).
const Network = struct {
    user_agent: ?[]u8,
    verify_peer: bool,
    verify_host: bool,
    ca_bundle_path: ?[]u8,
    trust_store: ?*anyopaque,
    proxy_url: ?[]u8,
    proxy_username: ?[]u8,
    proxy_password: ?[]u8,
    no_proxy: ?[]u8,

    fn copy(allocator: std.mem.Allocator, from: *const platform.WebSocketNetworkOptions) !Network {
        var self: Network = .{
            .user_agent = null,
            .verify_peer = from.verify_peer,
            .verify_host = from.verify_host,
            .ca_bundle_path = null,
            .trust_store = from.trust_store,
            .proxy_url = null,
            .proxy_username = null,
            .proxy_password = null,
            .no_proxy = null,
        };
        errdefer self.deinit(allocator);
        if (from.user_agent.len > 0) self.user_agent = try allocator.dupe(u8, from.user_agent.slice());
        if (from.has_ca_bundle) self.ca_bundle_path = try allocator.dupe(u8, from.ca_bundle_path.slice());
        if (from.has_proxy) {
            self.proxy_url = try allocator.dupe(u8, from.proxy_url.slice());
            if (from.proxy_has_credentials) {
                self.proxy_username = try allocator.dupe(u8, from.proxy_username.slice());
                self.proxy_password = try allocator.dupe(u8, from.proxy_password.slice());
            }
            if (from.has_no_proxy) self.no_proxy = try allocator.dupe(u8, from.no_proxy.slice());
        }
        return self;
    }

    fn deinit(self: *Network, allocator: std.mem.Allocator) void {
        inline for (.{ "user_agent", "ca_bundle_path", "proxy_url", "proxy_username", "proxy_password", "no_proxy" }) |name| {
            if (@field(self, name)) |value| allocator.free(value);
        }
    }

    fn handleOptions(self: *const Network) options.HandleOptions {
        return .{
            .user_agent = self.user_agent,
            .verify_peer = self.verify_peer,
            .verify_host = self.verify_host,
            .ca_bundle_path = self.ca_bundle_path,
            .trust = if (self.trust_store) |store| @ptrCast(@alignCast(store)) else null,
            .proxy = if (self.proxy_url) |url| .{
                .url = url,
                .username = self.proxy_username,
                .password = self.proxy_password,
                .no_proxy = self.no_proxy,
            } else null,
        };
    }
};

// frames.Kind is platform.WebSocketFrameKind, value for value: chunks and
// sends convert between them with @enumFromInt.
comptime {
    for (@typeInfo(platform.WebSocketFrameKind).@"enum".fields, @typeInfo(frames.Kind).@"enum".fields) |a, b| {
        if (!std.mem.eql(u8, a.name, b.name) or a.value != b.value) @compileError("frames.Kind and platform.WebSocketFrameKind differ");
    }
}

fn randomKey(key: *[4]u8) void {
    platform.fillRandom(key);
}

pub fn open(allocator: std.mem.Allocator, request: *const platform.WebSocketRequest) platform.HttpError!*platform.WebSocket {
    for (request.headers.slice()) |header| {
        const name = header.name.slice();
        const value = header.value.slice();
        // A transport API must not allow a caller to inject another field.
        if (name.len == 0 or std.mem.indexOfAny(u8, name, "\r\n:") != null or
            std.mem.indexOfAny(u8, value, "\r\n") != null) return error.InvalidRequest;
    }
    const uri = std.Uri.parse(request.url.slice()) catch return error.InvalidRequest;
    const secure = if (std.ascii.eqlIgnoreCase(uri.scheme, "wss")) true else if (std.ascii.eqlIgnoreCase(uri.scheme, "ws")) false else return error.InvalidRequest;
    const host_component = uri.host orelse return error.InvalidRequest;
    const host_text = switch (host_component) {
        .raw => |text| text,
        .percent_encoded => |text| text,
    };
    if (host_text.len == 0) return error.InvalidRequest;

    const multi = c.curl_multi_init() orelse return error.NetworkError;
    errdefer _ = c.curl_multi_cleanup(multi);
    const socket = try allocator.create(Socket);
    errdefer allocator.destroy(socket);

    const host = try allocator.dupe(u8, host_text);
    errdefer allocator.free(host);
    const resource = try resourceOf(allocator, uri);
    errdefer allocator.free(resource);
    const default_port: u16 = if (secure) 443 else 80;
    const port: ?u16 = if (uri.port) |p| (if (p == default_port) null else p) else null;
    const connect_url = try std.fmt.allocPrintSentinel(allocator, "{s}://{s}:{d}/", .{ if (secure) "https" else "http", host, port orelse default_port }, 0);
    errdefer allocator.free(connect_url);
    const authorization = try basicAuthorization(allocator, uri);
    errdefer if (authorization) |value| allocator.free(value);
    const fields = try copyFields(allocator, request.headers.slice());
    errdefer freeFields(allocator, fields);
    var network = try Network.copy(allocator, &request.network);
    errdefer network.deinit(allocator);

    var random: [16]u8 = undefined;
    platform.fillRandom(&random);
    socket.* = .{
        .allocator = allocator,
        .multi = multi,
        .secure = secure,
        .host = host,
        .port = port,
        .resource = resource,
        .connect_url = connect_url,
        .authorization = authorization,
        .fields = fields,
        .network = network,
        .offer_h2 = http2 and secure,
        .key = handshake.keyFrom(random),
    };
    try startConnection(socket);
    // Ownership passes here. A failed first poll is released by the caller,
    // never both an errdefer and the owner (the former double-free regression).
    return @ptrCast(socket);
}

/// "/" path ["?" query]: WebSockets' resource name (obtain a WebSocket
/// connection, steps 3-4).
fn resourceOf(allocator: std.mem.Allocator, uri: std.Uri) ![]u8 {
    const path = switch (uri.path) {
        .raw => |text| text,
        .percent_encoded => |text| text,
    };
    const query: ?[]const u8 = if (uri.query) |q| switch (q) {
        .raw => |text| text,
        .percent_encoded => |text| text,
    } else null;
    return std.fmt.allocPrint(allocator, "{s}{s}{s}{s}", .{
        if (path.len == 0) "/" else "",
        path,
        if (query != null) "?" else "",
        query orelse "",
    });
}

/// `Basic` credentials from the URL's userinfo, percent-decoded, as libcurl
/// sent them for the upgrade it made (and Fetch's HTTP-network-or-cache
/// fetch step 13.2 for a URL that includes credentials). OWNED; null without.
fn basicAuthorization(allocator: std.mem.Allocator, uri: std.Uri) !?[]u8 {
    const user = uri.user orelse return null;
    const user_raw = try user.toRawMaybeAlloc(allocator);
    defer if (user_raw.ptr != componentText(user).ptr) allocator.free(user_raw);
    const password_raw: []const u8 = if (uri.password) |password| try password.toRawMaybeAlloc(allocator) else "";
    defer if (uri.password) |password| if (password_raw.ptr != componentText(password).ptr) allocator.free(password_raw);
    if (user_raw.len == 0 and password_raw.len == 0) return null;
    const plain = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ user_raw, password_raw });
    defer allocator.free(plain);
    const encoder = std.base64.standard.Encoder;
    const value = try allocator.alloc(u8, "Basic ".len + encoder.calcSize(plain.len));
    @memcpy(value[0.."Basic ".len], "Basic ");
    _ = encoder.encode(value["Basic ".len..], plain);
    return value;
}

fn componentText(component: std.Uri.Component) []const u8 {
    return switch (component) {
        .raw => |text| text,
        .percent_encoded => |text| text,
    };
}

fn copyFields(allocator: std.mem.Allocator, headers: []const platform.Header) ![]handshake.Field {
    const fields = try allocator.alloc(handshake.Field, headers.len);
    var made: usize = 0;
    errdefer {
        for (fields[0..made]) |field| {
            allocator.free(field.name);
            allocator.free(field.value);
        }
        allocator.free(fields);
    }
    for (headers) |header| {
        const name = try allocator.dupe(u8, header.name.slice());
        const value = allocator.dupe(u8, header.value.slice()) catch |err| {
            allocator.free(name);
            return err;
        };
        fields[made] = .{ .name = name, .value = value };
        made += 1;
    }
    return fields;
}

fn freeFields(allocator: std.mem.Allocator, fields: []handshake.Field) void {
    for (fields) |field| {
        allocator.free(field.name);
        allocator.free(field.value);
    }
    allocator.free(fields);
}

/// A curl handle that connects - and nothing more (CURLOPT_CONNECT_ONLY 1) -
/// with the Browser's network options, through an HTTP proxy as a CONNECT
/// tunnel (CURLOPT_HTTPPROXYTUNNEL: a browser tunnels its WebSockets), and,
/// for wss:, ALPN offering h2 and http/1.1 (CURL_HTTP_VERSION_2TLS) or
/// http/1.1 alone.
fn startConnection(socket: *Socket) platform.HttpError!void {
    std.debug.assert(socket.easy == null);
    const easy = c.curl_easy_init() orelse return error.NetworkError;
    errdefer c.curl_easy_cleanup(easy);
    const version: c_long = if (socket.offer_h2) c.CURL_HTTP_VERSION_2TLS else c.CURL_HTTP_VERSION_1_1;
    if (c.curl_easy_setopt(easy, c.CURLOPT_URL, socket.connect_url.ptr) != c.CURLE_OK or
        c.curl_easy_setopt(easy, c.CURLOPT_CONNECT_ONLY, @as(c_long, 1)) != c.CURLE_OK or
        c.curl_easy_setopt(easy, c.CURLOPT_HTTP_VERSION, version) != c.CURLE_OK or
        c.curl_easy_setopt(easy, c.CURLOPT_HTTPPROXYTUNNEL, @as(c_long, 1)) != c.CURLE_OK)
        return error.NetworkError;
    try options.apply(easy, socket.allocator, socket.network.handleOptions());
    if (c.curl_multi_add_handle(socket.multi, easy) != c.CURLM_OK) return error.NetworkError;
    socket.easy = easy;
    socket.phase = .connecting;
}

fn dropConnection(socket: *Socket) void {
    if (http2) if (socket.session) |session| {
        session.deinit();
        socket.session = null;
    };
    if (socket.easy) |easy| {
        _ = c.curl_multi_remove_handle(socket.multi, easy);
        c.curl_easy_cleanup(easy);
        socket.easy = null;
    }
    socket.out.clearRetainingCapacity();
    socket.out_start = 0;
    socket.in.clearRetainingCapacity();
    socket.in_start = 0;
    socket.eof = false;
}

/// The handshake failed before any response: status 0, unverified.
fn failHandshake(socket: *Socket) ?platform.WebSocketHandshake {
    socket.phase = .done;
    socket.result = .{ .head = .{ .status = 0, .version = .http1_1 }, .verified = false };
    return socket.result;
}

pub fn pollHandshake(handle: *platform.WebSocket) platform.HttpError!?platform.WebSocketHandshake {
    const socket = Socket.of(handle);
    if (socket.result) |result| return result;
    if (socket.phase == .connecting) {
        var running: c_int = 0;
        if (c.curl_multi_perform(socket.multi, &running) != c.CURLM_OK) return error.NetworkError;
        var queued: c_int = 0;
        const done = while (c.curl_multi_info_read(socket.multi, &queued)) |message| {
            if (message.*.msg == c.CURLMSG_DONE) break message.*.data.result;
        } else return null;
        if (done != c.CURLE_OK) return failHandshake(socket);
        try connected(socket);
    }
    pump(socket) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.ConnectionLost, error.NetworkError, error.ProtocolError => return failHandshake(socket),
    };
    switch (socket.phase) {
        .connecting, .done => {},
        .h1_handshake => try readH1Response(socket),
        .h2_settings, .h2_handshake => if (http2) try h2Handshake(socket),
    }
    return socket.result;
}

/// The connection is up: start the handshake ALPN chose.
fn connected(socket: *Socket) platform.HttpError!void {
    if (http2 and socket.offer_h2 and negotiatedH2(socket.easy.?)) {
        socket.session = h2.Session.init(socket.allocator) catch |err| return mapH2(err);
        socket.phase = .h2_settings;
        return;
    }
    handshake.writeRequest(socket.allocator, &socket.out, .{ .host = socket.host, .port = socket.port, .resource = socket.resource }, &socket.key, socket.network.user_agent, socket.authorization, socket.fields) catch return error.OutOfMemory;
    socket.phase = .h1_handshake;
}

fn mapH2(err: anyerror) platform.HttpError {
    return if (err == error.OutOfMemory) error.OutOfMemory else error.NetworkError;
}

/// Whether ALPN chose "h2" (curl's own answer is its HTTP/2 layer, which a
/// CONNECT_ONLY connection does not get: the TLS library is asked, through
/// CURLINFO_TLS_SSL_PTR, as fetch's curl_backend negotiatedHttp2 does).
fn negotiatedH2(easy: *c.CURL) bool {
    if (comptime !share.trust.enabled) return false;
    var info: [*c]c.struct_curl_tlssessioninfo = null;
    if (c.curl_easy_getinfo(easy, c.CURLINFO_TLS_SSL_PTR, &info) != c.CURLE_OK or info == null) return false;
    if (info.*.backend != c.CURLSSLBACKEND_MBEDTLS) return false;
    const session = info.*.internals orelse return false;
    const alpn = mbedtls.mbedtls_ssl_get_alpn_protocol(session) orelse return false;
    return std.mem.eql(u8, std.mem.span(alpn), "h2");
}

const mbedtls = struct {
    extern fn mbedtls_ssl_get_alpn_protocol(ssl: *const anyopaque) ?[*:0]const u8;
};

const PumpError = error{ OutOfMemory, ConnectionLost, NetworkError, ProtocolError };

/// Move bytes without waiting: what is queued goes out, what has arrived
/// comes in (into `in`, or through the HTTP/2 session).
fn pump(socket: *Socket) PumpError!void {
    const easy = socket.easy orelse return;
    if (socket.phase == .connecting) return;
    if (http2) if (socket.session) |session| try session.output(&socket.out, max_buffered);
    // Write.
    while (socket.out_start < socket.out.items.len) {
        var sent: usize = 0;
        const rest = socket.out.items[socket.out_start..];
        const code = c.curl_easy_send(easy, rest.ptr, rest.len, &sent);
        if (code == c.CURLE_AGAIN) break;
        if (code != c.CURLE_OK) return error.NetworkError;
        socket.out_start += sent;
        if (sent == 0) break;
    }
    if (socket.out_start == socket.out.items.len) {
        socket.out.clearRetainingCapacity();
        socket.out_start = 0;
    }
    // Read.
    var buffer: [read_size]u8 = undefined;
    while (!socket.eof) {
        var got: usize = 0;
        const code = c.curl_easy_recv(easy, &buffer, buffer.len, &got);
        if (code == c.CURLE_AGAIN) break;
        if (code != c.CURLE_OK) return error.ConnectionLost;
        if (got == 0) {
            socket.eof = true;
            break;
        }
        if (http2) if (socket.session) |session| {
            session.receive(buffer[0..got]) catch |err| return err;
            continue;
        };
        if (socket.in_start > 0 and socket.in_start == socket.in.items.len) {
            socket.in.clearRetainingCapacity();
            socket.in_start = 0;
        }
        try socket.in.appendSlice(socket.allocator, buffer[0..got]);
        if (socket.in.items.len - socket.in_start >= max_buffered) break;
    }
    if (http2) if (socket.session) |session| {
        // What reading made the session say (SETTINGS ACK, WINDOW_UPDATE).
        try session.output(&socket.out, max_buffered);
        if (socket.out.items.len > socket.out_start) {
            var sent: usize = 0;
            const rest = socket.out.items[socket.out_start..];
            const code = c.curl_easy_send(easy, rest.ptr, rest.len, &sent);
            if (code != c.CURLE_OK and code != c.CURLE_AGAIN) return error.NetworkError;
            if (code == c.CURLE_OK) socket.out_start += sent;
        }
        if (session.remote_ended or session.closed) socket.eof = true;
    };
}

fn readH1Response(socket: *Socket) platform.HttpError!void {
    const available = socket.in.items[socket.in_start..];
    const end = handshake.headEnd(available) orelse {
        if (socket.eof) _ = failHandshake(socket);
        return;
    };
    try socket.head_bytes.appendSlice(socket.allocator, available[0..end]);
    socket.in_start += end;
    var head = handshake.parseHead(socket.allocator, socket.head_bytes.items, &socket.folded) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.InvalidResponse => {
            _ = failHandshake(socket);
            return;
        },
    };
    defer head.deinit(socket.allocator);
    try socket.response_headers.ensureTotalCapacity(socket.allocator, head.fields.items.len);
    for (head.fields.items) |field| socket.response_headers.appendAssumeCapacity(.{ .name = .from(field.name), .value = .from(field.value) });
    socket.phase = .done;
    socket.result = .{
        .head = .{ .status = head.status, .version = .http1_1, .headers = .from(socket.response_headers.items) },
        .verified = handshake.accepts(&head, &socket.key),
    };
}

fn h2Handshake(socket: *Socket) platform.HttpError!void {
    if (comptime !http2) unreachable;
    const session = socket.session.?;
    if (socket.phase == .h2_settings) {
        if (!session.settings_seen) {
            if (socket.eof) _ = failHandshake(socket);
            return;
        }
        if (!session.extendedConnectAllowed()) {
            // RFC 8441 section 3: no SETTINGS_ENABLE_CONNECT_PROTOCOL, no
            // extended CONNECT. Firefox then retries the WebSocket on a
            // fresh HTTP/1.1 connection (nsHttpConnectionMgr.cpp
            // TryDispatchExtendedCONNECTransaction, DisableSpdy).
            dropConnection(socket);
            socket.offer_h2 = false;
            try startConnection(socket);
            return;
        }
        var authority_buffer: [512]u8 = undefined;
        const authority = (if (socket.port) |port|
            std.fmt.bufPrint(&authority_buffer, "{s}:{d}", .{ socket.host, port })
        else
            std.fmt.bufPrint(&authority_buffer, "{s}", .{socket.host})) catch return error.InvalidRequest;
        var fields: std.ArrayList(h2.Field) = .empty;
        defer fields.deinit(socket.allocator);
        try fields.ensureTotalCapacity(socket.allocator, socket.fields.len + 2);
        if (socket.network.user_agent) |value| fields.appendAssumeCapacity(.{ .name = "user-agent", .value = value });
        var has_authorization = false;
        for (socket.fields) |field| {
            if (std.ascii.eqlIgnoreCase(field.name, "Authorization")) has_authorization = true;
            fields.appendAssumeCapacity(.{ .name = field.name, .value = field.value });
        }
        if (socket.authorization) |value| if (!has_authorization) fields.appendAssumeCapacity(.{ .name = "authorization", .value = value });
        session.connect(.{ .scheme = "https", .authority = authority, .path = socket.resource }, fields.items) catch |err| return mapH2(err);
        socket.phase = .h2_handshake;
        pump(socket) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => {
                _ = failHandshake(socket);
                return;
            },
        };
    }
    if (!session.response_done) {
        if (socket.eof) _ = failHandshake(socket);
        return;
    }
    try socket.response_headers.ensureTotalCapacity(socket.allocator, session.fields.items.len);
    for (session.fields.items) |field| socket.response_headers.appendAssumeCapacity(.{ .name = .from(field.name), .value = .from(field.value) });
    socket.phase = .done;
    // RFC 8441 section 5: a 2xx response opens the tunnel; there is no
    // Sec-WebSocket-Accept to check. An extension the server names was not
    // offered (RFC 6455 4.1 step 5).
    var extension = false;
    for (session.fields.items) |field| {
        if (std.ascii.eqlIgnoreCase(field.name, "sec-websocket-extensions") and field.value.len > 0) extension = true;
    }
    socket.result = .{
        .head = .{ .status = session.status, .version = .http2, .headers = .from(socket.response_headers.items) },
        .verified = session.status >= 200 and session.status < 300 and !extension,
    };
}

fn connectedOpen(socket: *const Socket) bool {
    return if (socket.result) |result| result.verified else false;
}

/// How many bytes wait for the network.
fn buffered(socket: *const Socket) usize {
    var n = socket.out.items.len - socket.out_start;
    if (http2) if (socket.session) |session| {
        n += session.unsent();
    };
    return n;
}

/// Append a frame's bytes for the network: into `out` on HTTP/1.1, into
/// the stream's queue on HTTP/2.
fn writeFrame(socket: *Socket, kind: frames.Kind, payload: []const u8, budget: usize) !usize {
    if (http2) if (socket.session) |session| {
        var scratch: std.ArrayList(u8) = .empty;
        defer scratch.deinit(socket.allocator);
        const taken = try socket.encoder.write(socket.allocator, &scratch, kind, payload, budget, randomKey);
        try session.queue(scratch.items);
        return taken;
    };
    return socket.encoder.write(socket.allocator, &socket.out, kind, payload, budget, randomKey);
}

/// A Ping waiting for its Pong goes out once no frame is part-way.
fn answerPing(socket: *Socket) !void {
    const pong = socket.pong orelse return;
    if (socket.encoder.busy()) return;
    socket.pong = null;
    _ = try writeFrame(socket, .pong, pong.bytes[0..pong.len], frames.max_control_payload);
}

pub fn send(handle: *platform.WebSocket, kind: platform.WebSocketFrameKind, bytes: platform.Bytes) platform.WebSocketError!usize {
    const socket = Socket.of(handle);
    if (!connectedOpen(socket)) return error.NetworkError;
    const payload = bytes.slice();
    var budget = max_buffered -| buffered(socket);
    if (budget == 0 and payload.len > 0) {
        pump(socket) catch |err| return mapPump(err);
        budget = max_buffered -| buffered(socket);
        if (budget == 0) return error.WouldBlock;
    }
    const taken = writeFrame(socket, @fromBackingInt(@intCast(@backingInt(kind))), payload, budget) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        // The caller changed kind part-way through a frame.
        error.FrameKindChanged => return error.InvalidRequest,
        else => return error.NetworkError,
    };
    answerPing(socket) catch return error.OutOfMemory;
    pump(socket) catch |err| return mapPump(err);
    return taken;
}

fn mapPump(err: PumpError) platform.WebSocketError {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.ConnectionLost => error.ConnectionLost,
        error.NetworkError, error.ProtocolError => error.NetworkError,
    };
}

pub fn receive(handle: *platform.WebSocket, buffer: []u8) platform.WebSocketError!platform.WebSocketChunk {
    const socket = Socket.of(handle);
    if (!connectedOpen(socket)) return error.NetworkError;
    std.debug.assert(buffer.len >= frames.max_control_payload);
    while (true) {
        const input = pendingInput(socket);
        if (input.len > 0 or socket.decoder.frame != null) {
            const result = socket.decoder.decode(input, buffer) catch return error.NetworkError;
            consumeInput(socket, result.consumed);
            if (result.chunk) |chunk| {
                if (chunk.kind == .ping) {
                    var pong: Socket.Control = .{ .len = chunk.len };
                    @memcpy(pong.bytes[0..chunk.len], buffer[0..chunk.len]);
                    socket.pong = pong;
                    answerPing(socket) catch return error.OutOfMemory;
                    pump(socket) catch {};
                }
                return .{
                    .bytes = .from(buffer[0..chunk.len]),
                    .kind = @fromBackingInt(@intCast(@backingInt(chunk.kind))),
                    .bytes_left = chunk.bytes_left,
                    .more_fragments = chunk.more_fragments,
                };
            }
            if (result.consumed > 0) continue;
        }
        if (socket.eof) return error.ConnectionLost;
        const before = pendingInput(socket).len;
        pump(socket) catch |err| switch (err) {
            // What arrived before the connection went is still read first.
            error.ConnectionLost => socket.eof = true,
            else => return mapPump(err),
        };
        if (pendingInput(socket).len == before and !socket.eof) return error.WouldBlock;
    }
}

fn pendingInput(socket: *const Socket) []const u8 {
    if (http2) if (socket.session) |session| return session.pending();
    return socket.in.items[socket.in_start..];
}

fn consumeInput(socket: *Socket, n: usize) void {
    if (http2) if (socket.session) |session| return session.consumed(n);
    socket.in_start += n;
    if (socket.in_start == socket.in.items.len) {
        socket.in.clearRetainingCapacity();
        socket.in_start = 0;
    }
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
    const allocator = socket.allocator;
    if (http2) if (socket.session) |session| {
        // RFC 8441 section 5: an abrupt close is a RST_STREAM (CANCEL),
        // sent if the connection takes it now.
        if (!session.closed and !session.remote_ended) {
            session.cancel();
            pump(socket) catch {};
        }
    };
    dropConnection(socket);
    _ = c.curl_multi_cleanup(socket.multi);
    socket.out.deinit(allocator);
    socket.in.deinit(allocator);
    socket.head_bytes.deinit(allocator);
    socket.folded.deinit(allocator);
    socket.response_headers.deinit(allocator);
    allocator.free(socket.host);
    allocator.free(socket.resource);
    allocator.free(socket.connect_url);
    if (socket.authorization) |value| allocator.free(value);
    freeFields(allocator, socket.fields);
    socket.network.deinit(allocator);
    allocator.destroy(socket);
}
