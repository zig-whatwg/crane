//! libcurl WebSocket Backend
//!
//! Provides low-level WebSocket operations using libcurl's WebSocket API (7.86.0+).
//! This backend handles the RFC 6455 protocol details:
//! - HTTP/1.1 Upgrade handshake
//! - Frame parsing and serialization
//! - Payload masking (automatic for client-to-server)
//! - Sec-WebSocket-Key/Accept validation
//! - TLS for wss:// URLs
//! - Automatic Ping/Pong handling
//!
//! ## Usage
//!
//! ```zig
//! var backend = try CurlWebSocket.init(allocator, "wss://example.com/socket", null);
//! defer backend.deinit();
//!
//! try backend.startConnect();
//! while (!try backend.pollConnect()) {} // one poll per event-loop turn
//!
//! // Frames go out in parts: call again with what is left.
//! const accepted = try backend.sendPart("Hello!", .text);
//!
//! var buffer: [4096]u8 = undefined;
//! const chunk = try backend.receive(&buffer); // error.WouldBlock: nothing yet
//! ```
//!
//! ## References
//!
//! - libcurl WebSocket: https://curl.se/libcurl/c/libcurl-ws.html
//! - curl_ws_send: https://curl.se/libcurl/c/curl_ws_send.html
//! - curl_ws_recv: https://curl.se/libcurl/c/curl_ws_recv.html

const std = @import("std");
const fetch = @import("fetch");
const curl = fetch.network.curl_ffi;
const CurlCookieManager = fetch.network.CurlCookieManager;

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

/// What kind of frame a chunk belongs to, or is to be sent as.
pub const FrameKind = enum { text, binary, close, ping, pong };

// libcurl's CURLWS_* flags, typed once: translate-c makes them `c_int`, while
// curl_ws_send takes, and our frame metadata reads, `c_uint`.
const ws_text: c_uint = curl.CURLWS_TEXT;
const ws_binary: c_uint = curl.CURLWS_BINARY;
const ws_cont: c_uint = curl.CURLWS_CONT;
const ws_close: c_uint = curl.CURLWS_CLOSE;
const ws_ping: c_uint = curl.CURLWS_PING;
const ws_pong: c_uint = curl.CURLWS_PONG;

/// WebSocket backend using libcurl.
///
/// ## The handshake runs on its own multi handle
///
/// The WebSocket constructor establishes the connection "in parallel"
/// (WebSockets § 3.1 step 12): script keeps running while the handshake is in
/// flight. `curl_easy_perform` cannot do that - it blocks until the server has
/// answered, and a server that stalls (websockets/handlers/sleep_10_v13 sleeps
/// ten seconds) stalls the whole event loop with it, so a test that calls
/// close() from a one-second timer while CONNECTING never gets to.
///
/// So the transfer is driven by a multi handle of its own: `startConnect`
/// adds it, and each `pollConnect` - one per pump turn - advances it without
/// waiting. libcurl requires a CONNECT_ONLY handle driven that way to stay
/// added to its multi handle for as long as the connection is used
/// (CURLOPT_CONNECT_ONLY: "Once it has been removed with
/// curl_multi_remove_handle(3), curl_easy_send(3) and curl_easy_recv(3) do not
/// function"), so the multi handle lives exactly as long as the easy one.
pub const CurlWebSocket = struct {
    allocator: std.mem.Allocator,

    /// libcurl easy handle, from `startConnect` until `deinit`.
    handle: ?*curl.CURL = null,

    /// The multi handle driving `handle`. See the type's doc comment.
    multi: ?*curl.CURLM = null,

    /// Request headers. libcurl reads CURLOPT_HTTPHEADER while the transfer
    /// runs, not when it is set, so the list lives until `deinit`.
    headers: ?*curl.curl_slist = null,

    /// URL of the WebSocket server.
    url: []const u8,

    /// Subprotocols to request (comma-separated).
    protocols: ?[]const u8,

    /// Whether the connection is established.
    connected: bool = false,

    /// Negotiated protocol from server.
    negotiated_protocol: ?[]const u8 = null,

    /// Cookie manager for handshake cookies (shared with Fetch API)
    cookie_manager: ?*CurlCookieManager,

    /// TLS trust for a wss:// handshake.
    ///
    /// The handshake is a fetch (WebSockets § 2.2 step 11), so it trusts what
    /// every other fetch trusts: the embedder's defaults, which is where the
    /// WPT runner registers the WPT certificate authority. Any paths are
    /// borrowed from whoever registered them.
    cert_options: fetch.network.CertVerifyOptions,

    /// The value of the handshake's `Origin` header, if one is to be sent.
    origin: ?[]const u8 = null,

    const Self = @This();

    /// Options for WebSocket initialization.
    pub const Options = struct {
        /// Subprotocols to request
        protocols: ?[]const []const u8 = null,

        /// Cookie manager for handshake (shared with Fetch API)
        cookie_manager: ?*CurlCookieManager = null,

        /// TLS trust; null means fetch's defaults.
        cert_options: ?fetch.network.CertVerifyOptions = null,

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
            .cookie_manager = options.cookie_manager,
            .cert_options = options.cert_options orelse fetch.network.defaultCertOptions(),
            .origin = origin_copy,
        };

        return self;
    }

    /// Clean up the backend and free resources. Closes the socket, if any.
    pub fn deinit(self: *Self) void {
        if (self.handle) |h| {
            if (self.multi) |m| _ = curl.multi_remove_handle(m, h);
            curl.easy_cleanup(h);
            self.handle = null;
        }
        if (self.multi) |m| {
            _ = curl.multi_cleanup(m);
            self.multi = null;
        }
        if (self.headers) |h| {
            curl.slist_free_all(h);
            self.headers = null;
        }

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

    /// Establish the WebSocket connection, waiting for it.
    ///
    /// `startConnect` and `pollConnect` with a wait between polls. For callers
    /// with nothing else to do; the WebSocket interface polls from its pump
    /// instead, so that script runs while the handshake is in flight.
    pub fn connect(self: *Self) !void {
        try self.startConnect();
        while (!try self.pollConnect()) {
            var numfds: c_int = 0;
            _ = curl.multi_poll(self.multi.?, 100, &numfds);
        }
    }

    /// Begin the opening handshake. Returns at once; `pollConnect` finishes it.
    pub fn startConnect(self: *Self) !void {
        try self.setUpTransfer();
        // Send the request now rather than on the next turn - "in parallel"
        // means the network makes progress while script runs. A failure here
        // is the handshake's, and the backend now owns everything it set up:
        // `deinit` releases it, once.
        _ = try self.pollConnect();
    }

    /// Make the transfer and hand it to the backend.
    ///
    /// Its own function so that its errdefers end where ownership passes to
    /// `self`. `startConnect` used to go on to its first poll with them still
    /// armed: a connection refused on the spot freed the handles and the
    /// header list there, and failing the connection freed them again in
    /// `deinit` - "pointer being freed was not allocated".
    fn setUpTransfer(self: *Self) !void {
        if (self.handle != null) {
            return error.AlreadyConnected;
        }

        // Initialize curl handle
        const handle = curl.easy_init() orelse return error.CurlInitFailed;
        errdefer curl.easy_cleanup(handle);

        // Set URL (need null-terminated string)
        const url_z = try self.allocator.dupeZ(u8, self.url);
        defer self.allocator.free(url_z);

        var result = curl.easy_setopt(handle, curl.CURLOPT_URL, url_z.ptr);
        if (result != curl.CURLE_OK) {
            return error.CurlSetoptFailed;
        }

        // Set WebSocket connect-only mode (2 = WebSocket upgrade, return after handshake)
        result = curl.easy_setopt(handle, curl.CURLOPT_CONNECT_ONLY, curl.CURL_CONNECT_ONLY_WEBSOCKET);
        if (result != curl.CURLE_OK) {
            return error.CurlSetoptFailed;
        }

        // TLS trust, as fetch applies it (network/curl_backend.zig).
        try self.applyCertOptions(handle);

        // Attach cookie manager for handshake cookies
        if (self.cookie_manager) |cm| {
            cm.attachToHandle(handle);
        }

        // Request headers: the ones WebSockets § 2.2 adds that libcurl does
        // not. Upgrade, Connection, Sec-WebSocket-Key and
        // Sec-WebSocket-Version are libcurl's own.
        var headers: ?*curl.curl_slist = null;
        errdefer if (headers) |h| curl.slist_free_all(h);

        if (self.origin) |origin| {
            headers = try appendHeader(self.allocator, headers, "Origin: {s}", origin);
        }

        if (self.protocols) |protos| {
            // Step 8: each protocol, combined into one header - joined with
            // ", " (Fetch, "combine").
            const combined = try std.mem.replaceOwned(u8, self.allocator, protos, ",", ", ");
            defer self.allocator.free(combined);
            headers = try appendHeader(self.allocator, headers, "Sec-WebSocket-Protocol: {s}", combined);
        }

        if (headers) |h| {
            result = curl.easy_setopt(handle, curl.CURLOPT_HTTPHEADER, h);
            if (result != curl.CURLE_OK) {
                return error.CurlSetoptFailed;
            }
        }

        const multi = curl.multi_init() orelse return error.CurlInitFailed;
        errdefer _ = curl.multi_cleanup(multi);
        if (curl.multi_add_handle(multi, handle) != curl.CURLM_OK) return error.CurlInitFailed;

        self.handle = handle;
        self.multi = multi;
        self.headers = headers;
    }

    /// Advance the opening handshake without waiting.
    ///
    /// Returns true once the connection is established, false while the
    /// handshake is still in flight, and an error if it failed - which is the
    /// caller's cue to fail the WebSocket connection.
    pub fn pollConnect(self: *Self) !bool {
        if (self.connected) return true;
        const multi = self.multi orelse return error.NotConnected;
        const handle = self.handle orelse return error.NotConnected;

        var running: c_int = 0;
        if (curl.multi_perform(multi, &running) != curl.CURLM_OK) return error.HandshakeFailed;

        // Wait for the transfer's DONE message; `running` alone cannot tell a
        // finished handshake from a failed one.
        var queued: c_int = 0;
        while (curl.multi_info_read(multi, &queued)) |msg| {
            if (msg.msg != curl.CURLMSG_DONE) continue;
            if (msg.data.result != curl.CURLE_OK) return error.HandshakeFailed;
            try self.finishHandshake(handle);
            return true;
        }
        return false;
    }

    /// WebSockets § 2.2 step 11, on a response libcurl has already accepted as
    /// an upgrade (it checks the status and Sec-WebSocket-Accept itself).
    fn finishHandshake(self: *Self, handle: *curl.CURL) !void {
        // Step 11.1: a status other than 101 fails the connection.
        var response_code: c_long = 0;
        if (curl.easy_getinfo(handle, curl.CURLINFO_RESPONSE_CODE, &response_code) != curl.CURLE_OK) {
            return error.CurlGetinfoFailed;
        }
        if (response_code != 101) {
            return error.HandshakeFailed;
        }

        // Step 11.2, and RFC 6455 § 4.1: the subprotocol in use, if the
        // handshake allows the connection at all. libcurl does not look at
        // Sec-WebSocket-Protocol.
        const selected = try selectSubprotocol(self.protocols, responseHeader(handle, "Sec-WebSocket-Protocol"));
        if (selected) |p| self.negotiated_protocol = try self.allocator.dupe(u8, p);

        self.connected = true;
    }

    fn appendHeader(
        allocator: std.mem.Allocator,
        list: ?*curl.curl_slist,
        comptime fmt: []const u8,
        value: []const u8,
    ) !?*curl.curl_slist {
        const line = try std.fmt.allocPrintSentinel(allocator, fmt, .{value}, 0);
        defer allocator.free(line);
        // slist_append copies the string.
        return curl.slist_append(list, line.ptr) orelse error.OutOfMemory;
    }

    /// A header of the handshake response (request -1: the last request on
    /// the handle), or null when it is absent. A header sent more than once
    /// comes back as a bare ",": extracting its values yields a list, and a
    /// list of subprotocols is never the ONE the server must select.
    fn responseHeader(handle: *curl.CURL, name: [:0]const u8) ?[]const u8 {
        // The 101 that completes the handshake is an informational response,
        // and libcurl files its headers under CURLH_1XX, not CURLH_HEADER.
        const origin: c_uint = curl.c.CURLH_HEADER | curl.c.CURLH_1XX;
        var header: ?*curl.c.struct_curl_header = null;
        const rc = curl.c.curl_easy_header(handle, name.ptr, 0, origin, -1, &header);
        if (rc != curl.c.CURLHE_OK) return null;
        const h = header orelse return null;
        // Two or more instances cannot all be the one subprotocol requested.
        if (h.amount > 1) return ",";
        return std.mem.span(h.value);
    }

    /// Verify the peer and its host name, against the configured CA bundle
    /// when there is one and the system's store otherwise.
    fn applyCertOptions(self: *Self, handle: *curl.CURL) !void {
        const options = self.cert_options;
        _ = curl.easy_setopt(handle, curl.CURLOPT_SSL_VERIFYPEER, @as(c_long, if (options.verify_peer) 1 else 0));
        _ = curl.easy_setopt(handle, curl.CURLOPT_SSL_VERIFYHOST, @as(c_long, if (options.verify_host) 2 else 0));
        if (options.ca_bundle_path) |ca_path| {
            const ca_z = try self.allocator.dupeZ(u8, ca_path);
            defer self.allocator.free(ca_z);
            // libcurl copies string options, so the copy can go at once.
            _ = curl.easy_setopt(handle, curl.CURLOPT_CAINFO, ca_z.ptr);
        }
    }

    /// Hand the socket as much of one frame as it will take, without waiting.
    ///
    /// `remaining` is the part of the frame's payload not yet accepted, and
    /// `total` the whole payload's length. Returns how many bytes of
    /// `remaining` were accepted, which may be fewer than all of them - or
    /// `error.WouldBlock` when none were. The caller calls again with what is
    /// left, the same `kind` and `total`, until the frame is done; libcurl keeps
    /// the frame open in between (curl_ws_send: a frame "ongoing" continues
    /// with the next call's buffer), so nothing else may be sent until then.
    ///
    /// This used to report any short write as `error.PartialSend` and move on,
    /// abandoning a frame whose header had already gone out - every byte sent
    /// after that was read by the peer as the rest of the abandoned frame.
    pub fn sendPart(self: *Self, remaining: []const u8, kind: FrameKind) !usize {
        const handle = self.handle orelse return error.NotConnected;
        if (!self.connected) return error.NotConnected;

        var sent: usize = 0;
        const result = curl.ws_send(handle, remaining.ptr, remaining.len, &sent, 0, flagsOf(kind));
        if (result == curl.c.CURLE_AGAIN) return error.WouldBlock;
        if (result != curl.CURLE_OK) return error.SendFailed;
        return sent;
    }

    fn flagsOf(kind: FrameKind) c_uint {
        return switch (kind) {
            .text => ws_text,
            .binary => ws_binary,
            .close => ws_close,
            .ping => ws_ping,
            .pong => ws_pong,
        };
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

        var recv_count: usize = 0;
        var meta: ?*const curl.curl_ws_frame = null;

        const result = curl.ws_recv(handle, buffer.ptr, buffer.len, &recv_count, &meta);
        if (result == curl.c.CURLE_AGAIN) return error.WouldBlock;
        if (result == curl.CURLE_GOT_NOTHING) return error.ConnectionLost;
        if (result != curl.CURLE_OK) return error.ReceiveFailed;

        const frame = meta orelse return error.NoMetadata;
        const flags: c_uint = @bitCast(frame.flags);

        const kind: FrameKind = if (flags & ws_close != 0)
            .close
        else if (flags & ws_ping != 0)
            .ping
        else if (flags & ws_pong != 0)
            .pong
        else if (flags & ws_text != 0)
            .text
        else
            .binary;

        return .{
            .data = buffer[0..recv_count],
            .kind = kind,
            .bytes_left = @intCast(@max(frame.bytesleft, 0)),
            .more_fragments = flags & ws_cont != 0,
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

test "CurlWebSocket - initialization" {
    const allocator = std.testing.allocator;

    // Test basic initialization
    var ws = try CurlWebSocket.init(allocator, "wss://example.com/socket", null);
    defer ws.deinit();

    try std.testing.expectEqualStrings("wss://example.com/socket", ws.url);
    try std.testing.expect(!ws.connected);
    try std.testing.expect(ws.handle == null);
}

test "CurlWebSocket - initialization with protocols" {
    const allocator = std.testing.allocator;

    const protocols = [_][]const u8{ "chat", "json" };
    var ws = try CurlWebSocket.init(allocator, "wss://example.com/socket", &protocols);
    defer ws.deinit();

    try std.testing.expect(ws.protocols != null);
    try std.testing.expectEqualStrings("chat,json", ws.protocols.?);
}

test "CurlWebSocket - protocol list is exactly sized" {
    const allocator = std.testing.allocator;

    // Regression: the join over-reserved one separator per protocol and then
    // freed a shorter slice than it allocated. std.testing.allocator fails the
    // test on the size mismatch, so every arity has to be exercised - a single
    // protocol needs zero commas, three need two.
    {
        const protocols = [_][]const u8{"chat"};
        var ws = try CurlWebSocket.init(allocator, "wss://example.com/socket", &protocols);
        defer ws.deinit();
        try std.testing.expectEqualStrings("chat", ws.protocols.?);
    }
    {
        const protocols = [_][]const u8{ "chat", "json", "graphql-ws" };
        var ws = try CurlWebSocket.init(allocator, "wss://example.com/socket", &protocols);
        defer ws.deinit();
        try std.testing.expectEqualStrings("chat,json,graphql-ws", ws.protocols.?);
    }
    {
        // An empty protocol list must stay null, not become an empty allocation.
        const protocols = [_][]const u8{};
        var ws = try CurlWebSocket.init(allocator, "wss://example.com/socket", &protocols);
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

test "CurlWebSocket - a wss handshake trusts what fetch trusts" {
    // The embedder registers the certificate authorities it trusts through
    // fetch's default cert options - the WPT runner adds the WPT CA that way -
    // and a WebSocket handshake is a fetch (WebSockets § 2.2 step 11). A
    // backend that set no TLS options at all verified wss:// against the
    // system store only, so every `?wss` variant failed to open.
    const allocator = std.testing.allocator;

    const saved = fetch.network.defaultCertOptions();
    defer fetch.network.setDefaultCertOptions(saved);
    fetch.network.setDefaultCertOptions(.{ .ca_bundle_path = "/wpt/tools/certs/cacert.pem" });

    var ws = try CurlWebSocket.init(allocator, "wss://web-platform.test:8666/echo", null);
    defer ws.deinit();

    try std.testing.expectEqualStrings("/wpt/tools/certs/cacert.pem", ws.cert_options.ca_bundle_path.?);
    try std.testing.expect(ws.cert_options.verify_peer);
    try std.testing.expect(ws.cert_options.verify_host);
}

test "CurlWebSocket - not connected errors" {
    const allocator = std.testing.allocator;

    var ws = try CurlWebSocket.init(allocator, "wss://example.com/socket", null);
    defer ws.deinit();

    // Should fail since not connected
    try std.testing.expectError(error.NotConnected, ws.sendPart("hello", .text));
    try std.testing.expectError(error.NotConnected, ws.sendPart("hello", .binary));

    var buffer: [100]u8 = undefined;
    try std.testing.expectError(error.NotConnected, ws.receive(&buffer));
}
