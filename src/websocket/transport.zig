//! WebSocket policy over the platform transport. Native handles, framing and
//! TLS live only in src/platform/kit/curl.
//! The WebSocket owned timer drives startConnect/pollConnect/sendPart/receive.

const std = @import("std");
const fetch = @import("fetch");
const platform = @import("platform");
const cookiestore = @import("cookiestore");
const log = std.log.scoped(.websocket);

pub fn acceptsHandshake(http2: bool, status: u16) bool {
    // RFC8441 replaces HTTP/1.1 Upgrade with extended CONNECT (RFC9113 8.5).
    return if (http2) status >= 200 and status < 300 else status == 101;
}

/// Which subprotocol a handshake response selects, or whether it fails the
/// connection.
///
/// `requested` is the client's Sec-WebSocket-Protocol list as sent - comma
/// joined, null when none was sent - and `response` the server's header value,
/// null when absent.
///
/// Two rules, from two documents:
///
/// - WebSockets § 2.2 step 11.2: if `protocols` is not empty and the response's
///   Sec-WebSocket-Protocol is null, failure or empty, fail the connection. A
///   subprotocol the client asked for and the server did not acknowledge.
/// - RFC 6455 § 4.1, the client's step 6: a Sec-WebSocket-Protocol naming a
///   subprotocol the client did not request fails the connection. That covers
///   a server answering a request that named none.
///
/// Subprotocol names are compared exactly: they are tokens, and the constructor
/// already rejected a list repeating one ASCII case-insensitively.
pub fn selectSubprotocol(requested: ?[]const u8, response: ?[]const u8) error{HandshakeFailed}!?[]const u8 {
    const asked = if (requested) |r| r.len > 0 else false;
    const value = std.mem.trim(u8, response orelse "", " \t");

    if (!asked) {
        // RFC 6455 § 4.1 step 6: nothing was offered, so nothing may be chosen.
        if (response != null and value.len > 0) return error.HandshakeFailed;
        return null;
    }

    // WebSockets § 2.2 step 11.2: offered, so one must be acknowledged.
    if (value.len == 0) return error.HandshakeFailed;

    // RFC 6455 § 4.1 step 6: and it must be one of those offered.
    var offered = std.mem.splitScalar(u8, requested.?, ',');
    while (offered.next()) |candidate| {
        if (std.mem.eql(u8, candidate, value)) return candidate;
    }
    return error.HandshakeFailed;
}

pub const FrameKind = platform.WebSocketFrameKind;

/// The API policy owner. The platform transport is owned from startConnect
/// until deinit; it has no callbacks and cannot survive cancellation.
pub const WebSocketTransport = struct {
    allocator: std.mem.Allocator,

    handle: ?*platform.WebSocket = null,

    /// URL of the WebSocket server.
    url: []const u8,

    /// Subprotocols to request (comma-separated).
    protocols: ?[]const u8,

    /// Whether the connection is established.
    connected: bool = false,

    /// Negotiated protocol from server.
    negotiated_protocol: ?[]const u8 = null,

    /// The user agent's cookie jar (BORROWED): the handshake is a request
    /// whose credentials mode is "include", so it sends the jar's cookies
    /// for the URL and stores its response's `Set-Cookie`. Null: none.
    cookie_jar: ?*cookiestore.CookieJar,

    /// TLS trust for a wss:// handshake.
    ///
    /// The handshake is a fetch (WebSockets § 2.2 step 11), so it trusts what
    /// every other fetch trusts: the embedder's defaults, which is where the
    /// WPT runner registers the WPT certificate authority. Any paths are
    /// borrowed from whoever registered them.
    cert_options: fetch.network.CertVerifyOptions,

    /// The value of the handshake's `Origin` header, if one is to be sent.
    origin: ?[]const u8 = null,

    /// The handshake's `User-Agent`: the client's Browser's user agent
    /// string (its network context's, BORROWED for the connection's life).
    /// HTTP-network-or-cache fetch step 8.15 appends it to the request the
    /// handshake sends. Null: none (a backend no Browser made).
    user_agent: ?[]const u8 = null,

    /// The proxy the handshake goes through: the client's Browser's for the
    /// URL (BORROWED, as the user agent). Null: the system's.
    proxy: ?fetch.network.ProxyConfig = null,

    const Self = @This();

    /// Options for WebSocket initialization.
    pub const Options = struct {
        /// Subprotocols to request
        protocols: ?[]const []const u8 = null,

        /// The user agent's cookie jar, borrowed for the connection's life.
        cookie_jar: ?*cookiestore.CookieJar = null,

        /// TLS trust; null means the network context's (below), or the
        /// system's with none.
        cert_options: ?fetch.network.CertVerifyOptions = null,

        /// The network context of the client's Browser (borrowed for the
        /// connection's life): what its handshake trusts.
        network: ?*fetch.network.NetworkContext = null,

        /// The serialized origin of the client, sent as `Origin`. Fetch
        /// appends it to every request whose mode is "websocket" (Fetch,
        /// "append a request Origin header").
        origin: ?[]const u8 = null,
    };

    /// Initialize a new WebSocket backend.
    ///
    /// Parameters:
    /// - allocator: Memory allocator
    /// - url: WebSocket URL (ws:// or wss://)
    /// - protocols: Optional list of subprotocols to request
    pub fn init(allocator: std.mem.Allocator, url: []const u8, protocols: ?[]const []const u8) !*Self {
        return initWithOptions(allocator, url, .{ .protocols = protocols });
    }

    /// Initialize with full options including cookie manager.
    pub fn initWithOptions(allocator: std.mem.Allocator, url: []const u8, options: Options) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        // Copy URL
        const url_copy = try allocator.dupe(u8, url);
        errdefer allocator.free(url_copy);

        // Build comma-separated protocol list if provided.
        //
        // Must be joined into an *exactly* sized allocation. The previous version
        // reserved `p.len + 1` per protocol - one separator too many, since N
        // protocols need N-1 commas - and then handed `buf[0..offset]` to
        // `deinit`, so the free length never matched the alloc length. That is an
        // allocator contract violation, not a leak: `std.testing.allocator`
        // reports "Allocation size 10 bytes does not match free size 9".
        var protocols_copy: ?[]const u8 = null;
        if (options.protocols) |protos| {
            if (protos.len > 0) {
                protocols_copy = try std.mem.join(allocator, ",", protos);
            }
        }
        errdefer if (protocols_copy) |p| allocator.free(p);

        const origin_copy: ?[]const u8 = if (options.origin) |o| try allocator.dupe(u8, o) else null;
        errdefer if (origin_copy) |o| allocator.free(o);

        self.* = .{
            .allocator = allocator,
            .url = url_copy,
            .protocols = protocols_copy,
            .cookie_jar = options.cookie_jar,
            .cert_options = options.cert_options orelse if (options.network) |network| network.certOptions() else .{},
            .origin = origin_copy,
            .user_agent = if (options.network) |network| network.userAgent() else null,
            .proxy = if (options.network) |network| network.proxyFor(url) else null,
        };

        return self;
    }

    /// Clean up the backend and free resources. Closes the socket, if any.
    pub fn deinit(self: *Self) void {
        if (self.handle) |h| platform.releaseWebSocket(h);
        self.handle = null;

        if (self.negotiated_protocol) |p| {
            self.allocator.free(p);
        }

        if (self.protocols) |p| {
            self.allocator.free(p);
        }

        if (self.origin) |o| {
            self.allocator.free(o);
        }

        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }

    /// Blocking helper for native callers; the script API uses the owned timer.
    pub fn connect(self: *Self) !void {
        try self.startConnect();
        while (!try self.pollConnect()) platform.sleepThread(std.time.ns_per_ms);
    }

    pub fn startConnect(self: *Self) !void {
        if (self.handle != null) return error.AlreadyConnected;
        var headers: [3]platform.Header = undefined;
        var count: usize = 0;
        if (self.origin) |origin| {
            headers[count] = .{ .name = .from("Origin"), .value = .from(origin) };
            count += 1;
        }
        const combined = if (self.protocols) |protos| try std.mem.replaceOwned(u8, self.allocator, protos, ",", ", ") else null;
        defer if (combined) |value| self.allocator.free(value);
        if (combined) |value| {
            headers[count] = .{ .name = .from("Sec-WebSocket-Protocol"), .value = .from(value) };
            count += 1;
        }
        // Credentials include; generate at handshake time, including Lax-by-default.
        const cookies = try self.requestCookieHeader();
        defer if (cookies) |value| self.allocator.free(value);
        if (cookies) |value| {
            headers[count] = .{ .name = .from("Cookie"), .value = .from(value) };
            count += 1;
        }
        const proxy = self.proxy;
        self.handle = try platform.openWebSocket(self.allocator, &.{
            .url = .from(self.url),
            .headers = .from(headers[0..count]),
            .network = .{
                .user_agent = .from(self.user_agent orelse ""),
                .verify_peer = self.cert_options.verify_peer,
                .verify_host = self.cert_options.verify_host,
                .ca_bundle_path = .from(self.cert_options.ca_bundle_path orelse ""),
                .has_ca_bundle = self.cert_options.ca_bundle_path != null,
                .proxy_has_credentials = if (proxy) |p| p.username != null and p.password != null else false,
                .has_no_proxy = if (proxy) |p| p.no_proxy != null else false,
                .has_proxy = proxy != null,
                .proxy_url = .from(if (proxy) |p| p.url else ""),
                .proxy_username = .from(if (proxy) |p| p.username orelse "" else ""),
                .proxy_password = .from(if (proxy) |p| p.password orelse "" else ""),
                .no_proxy = .from(if (proxy) |p| p.no_proxy orelse "" else ""),
            },
        });
        // Ownership already passed: only deinit frees a failed first poll.
        _ = try self.pollConnect();
    }

    pub fn pollConnect(self: *Self) !bool {
        if (self.connected) return true;
        const handle = self.handle orelse return error.NotConnected;
        const result = (try platform.pollWebSocketHandshake(handle)) orelse return false;
        self.storeResponseCookies(result.head.headers.slice());
        if (!result.verified or !acceptsHandshake(result.head.version == .http2, result.head.status)) return error.HandshakeFailed;
        const selected = try selectSubprotocol(self.protocols, responseHeader(result.head.headers.slice(), "Sec-WebSocket-Protocol"));
        if (selected) |value| self.negotiated_protocol = try self.allocator.dupe(u8, value);
        self.connected = true;
        return true;
    }

    /// Fetch "append a request `Cookie` header" for the handshake: the
    /// value, or null when there is none to send. OWNED.
    fn requestCookieHeader(self: *Self) !?[]u8 {
        const jar = self.cookie_jar orelse return null;
        const url = cookiestore.RequestUrl.of(self.url) orelse return null;
        if (!cookiestore.http_integration.hasCookiesForHost(jar, url.host)) return null;
        const same_site = try cookiestore.websocketSameSite(self.allocator, self.origin, self.url);
        const value = try cookiestore.http_integration.generateCookieHeader(self.allocator, jar, .{
            .host = url.host,
            .path = url.path,
            .is_http = true,
            .is_secure = url.secure,
            // A handshake is a subresource, never a top-level navigation.
            // A cross-site handshake sends only SameSite=None cookies: a cookie
            // without SameSite is Lax (Lax-by-default, the user's ruling 2026-10-20).
            .same_site = if (same_site) .strict_or_less else .none,
        });
        if (value.len == 0) {
            self.allocator.free(value);
            return null;
        }
        return value;
    }

    /// Fetch stores Set-Cookie even when the opening handshake fails.
    fn storeResponseCookies(self: *Self, headers: []const platform.Header) void {
        const jar = self.cookie_jar orelse return;
        const url = cookiestore.RequestUrl.of(self.url) orelse return;
        const same_site = cookiestore.websocketSameSite(self.allocator, self.origin, self.url) catch return;
        for (headers) |header| {
            if (!std.ascii.eqlIgnoreCase(header.name.slice(), "Set-Cookie")) continue;
            _ = cookiestore.http_integration.parseAndStoreCookie(self.allocator, jar, header.value.slice(), url.path, .{
                .is_secure = url.secure,
                .host = url.host,
                .http_only_allowed = true,
                .same_site_strict_or_lax_allowed = same_site,
            }) catch |err| {
                log.warn("handshake Set-Cookie not stored: {s}", .{@errorName(err)});
            };
        }
    }

    /// A repeated protocol field is a list, never the one offered token.
    fn responseHeader(headers: []const platform.Header, name: []const u8) ?[]const u8 {
        var found: ?[]const u8 = null;
        for (headers) |header| {
            if (!std.ascii.eqlIgnoreCase(header.name.slice(), name)) continue;
            if (found != null) return ",";
            found = header.value.slice();
        }
        return found;
    }

    /// Hand the socket as much of one frame as it will take, without waiting.
    ///
    /// `remaining` is the part of the frame's payload not yet accepted.
    /// Returns how many bytes were accepted, which may be fewer than all - or
    /// `error.WouldBlock` when none were. The caller calls again with what is
    /// left and the same `kind` until the frame is done; the platform keeps
    /// the frame open in between (curl_ws_send: a frame "ongoing" continues
    /// with the next call's buffer), so nothing else may be sent until then.
    ///
    /// This used to report any short write as `error.PartialSend` and move on,
    /// abandoning a frame whose header had already gone out - every byte sent
    /// after that was read by the peer as the rest of the abandoned frame.
    pub fn sendPart(self: *Self, remaining: []const u8, kind: FrameKind) !usize {
        const handle = self.handle orelse return error.NotConnected;
        if (!self.connected) return error.NotConnected;

        return platform.sendWebSocketFrame(handle, kind, .from(remaining));
    }

    /// One chunk of one received frame.
    ///
    /// libcurl hands a frame over in as many chunks as the buffer and the
    /// network make it: `bytes_left` says how much of THIS frame is still to
    /// come, and `more_fragments` whether further frames of the same message
    /// follow (a fragmented message, RFC 6455 § 5.4). A message is complete
    /// only when both say no. A zero-length chunk with `bytes_left == 0` is a
    /// whole, empty frame - an empty message is still a message.
    pub const ReceivedChunk = struct {
        data: []const u8,
        kind: FrameKind,
        bytes_left: u64,
        more_fragments: bool,
    };

    /// Receive the next chunk the socket has, without waiting.
    ///
    /// Returns `error.WouldBlock` when nothing has arrived, and
    /// `error.ConnectionLost` when the peer closed the TCP connection (with or
    /// without a Close frame first - the caller knows which).
    pub fn receive(self: *Self, buffer: []u8) !ReceivedChunk {
        const handle = self.handle orelse return error.NotConnected;
        if (!self.connected) return error.NotConnected;

        const chunk = try platform.receiveWebSocketFrame(handle, buffer);
        return .{
            .data = chunk.bytes.slice(),
            .kind = chunk.kind,
            .bytes_left = chunk.bytes_left,
            .more_fragments = chunk.more_fragments,
        };
    }

    /// Get the negotiated protocol (if any).
    pub fn getProtocol(self: *const Self) ?[]const u8 {
        return self.negotiated_protocol;
    }

    /// Check if the connection is established.
    pub fn isConnected(self: *const Self) bool {
        return self.connected and self.handle != null;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "WebSocketTransport - initialization" {
    const allocator = std.testing.allocator;

    // Test basic initialization
    var ws = try WebSocketTransport.init(allocator, "wss://example.com/socket", null);
    defer ws.deinit();

    try std.testing.expectEqualStrings("wss://example.com/socket", ws.url);
    try std.testing.expect(!ws.connected);
    try std.testing.expect(ws.handle == null);
}

test "WebSocketTransport - initialization with protocols" {
    const allocator = std.testing.allocator;

    const protocols = [_][]const u8{ "chat", "json" };
    var ws = try WebSocketTransport.init(allocator, "wss://example.com/socket", &protocols);
    defer ws.deinit();

    try std.testing.expect(ws.protocols != null);
    try std.testing.expectEqualStrings("chat,json", ws.protocols.?);
}

test "WebSocketTransport - protocol list is exactly sized" {
    const allocator = std.testing.allocator;

    // Regression: the join over-reserved one separator per protocol and then
    // freed a shorter slice than it allocated. std.testing.allocator fails the
    // test on the size mismatch, so every arity has to be exercised - a single
    // protocol needs zero commas, three need two.
    {
        const protocols = [_][]const u8{"chat"};
        var ws = try WebSocketTransport.init(allocator, "wss://example.com/socket", &protocols);
        defer ws.deinit();
        try std.testing.expectEqualStrings("chat", ws.protocols.?);
    }
    {
        const protocols = [_][]const u8{ "chat", "json", "graphql-ws" };
        var ws = try WebSocketTransport.init(allocator, "wss://example.com/socket", &protocols);
        defer ws.deinit();
        try std.testing.expectEqualStrings("chat,json,graphql-ws", ws.protocols.?);
    }
    {
        // An empty protocol list must stay null, not become an empty allocation.
        const protocols = [_][]const u8{};
        var ws = try WebSocketTransport.init(allocator, "wss://example.com/socket", &protocols);
        defer ws.deinit();
        try std.testing.expect(ws.protocols == null);
    }
}

test "selectSubprotocol - nothing offered, nothing chosen" {
    try std.testing.expectEqual(@as(?[]const u8, null), try selectSubprotocol(null, null));
    // An empty header is no subprotocol, not an unrequested one.
    try std.testing.expectEqual(@as(?[]const u8, null), try selectSubprotocol(null, ""));
}

test "selectSubprotocol - a server may not choose what was not offered" {
    // RFC 6455 § 4.1, the client's step 6.
    try std.testing.expectError(error.HandshakeFailed, selectSubprotocol(null, "echo"));
    try std.testing.expectError(error.HandshakeFailed, selectSubprotocol("echo,chat", "graphql"));
    // Matching is exact; the constructor has already folded case for duplicates.
    try std.testing.expectError(error.HandshakeFailed, selectSubprotocol("echo", "Echo"));
    // Two protocols at once is not one of the offered ones.
    try std.testing.expectError(error.HandshakeFailed, selectSubprotocol("echo,chat", "echo, chat"));
    try std.testing.expectError(error.HandshakeFailed, selectSubprotocol("echo,chat", ","));
}

test "selectSubprotocol - what was offered must be acknowledged" {
    // WebSockets § 2.2 step 11.2: null, or the empty byte sequence, fails.
    try std.testing.expectError(error.HandshakeFailed, selectSubprotocol("echo", null));
    try std.testing.expectError(error.HandshakeFailed, selectSubprotocol("echo,chat", ""));
}

test "selectSubprotocol - the server's choice is the subprotocol in use" {
    try std.testing.expectEqualStrings("echo", (try selectSubprotocol("echo", "echo")).?);
    try std.testing.expectEqualStrings("chat", (try selectSubprotocol("echo,chat", "chat")).?);
    // Optional whitespace around a header value is not part of it.
    try std.testing.expectEqualStrings("chat", (try selectSubprotocol("echo,chat", " chat ")).?);
}

test "WebSocketTransport - a wss handshake trusts what its Browser trusts" {
    // The embedder gives a Browser the certificate authorities it trusts -
    // the WPT runner adds the WPT CA that way - and a WebSocket handshake is
    // a fetch (WebSockets § 2.2 step 11), made with its client's Browser's
    // network context. A backend that set no TLS options at all verified
    // wss:// against the system store only, so every `?wss` variant failed
    // to open.
    const allocator = std.testing.allocator;

    var network = fetch.network.NetworkContext.init(allocator);
    defer network.deinit();
    try network.configure(.{ .ca_bundle_path = "/wpt/tools/certs/cacert.pem" });

    var ws = try WebSocketTransport.initWithOptions(allocator, "wss://web-platform.test:8666/echo", .{ .network = &network });
    defer ws.deinit();

    try std.testing.expectEqualStrings("/wpt/tools/certs/cacert.pem", ws.cert_options.ca_bundle_path.?);
    try std.testing.expect(ws.cert_options.verify_peer);
    try std.testing.expect(ws.cert_options.verify_host);
}

test "WebSocketTransport - not connected errors" {
    const allocator = std.testing.allocator;

    var ws = try WebSocketTransport.init(allocator, "wss://example.com/socket", null);
    defer ws.deinit();

    // Should fail since not connected
    try std.testing.expectError(error.NotConnected, ws.sendPart("hello", .text));
    try std.testing.expectError(error.NotConnected, ws.sendPart("hello", .binary));

    var buffer: [100]u8 = undefined;
    try std.testing.expectError(error.NotConnected, ws.receive(&buffer));
}
