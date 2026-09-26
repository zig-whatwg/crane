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
//! try backend.connect();
//! try backend.sendText("Hello!");
//!
//! var buffer: [4096]u8 = undefined;
//! if (try backend.receive(&buffer)) |msg| {
//!     // Process message
//! }
//!
//! try backend.sendClose(1000, "Goodbye");
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
const close_codes = @import("close_codes.zig");

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

/// WebSocket backend using libcurl.
pub const CurlWebSocket = struct {
    allocator: std.mem.Allocator,

    /// libcurl easy handle.
    handle: ?*curl.CURL,

    /// URL of the WebSocket server.
    url: []const u8,

    /// Subprotocols to request (comma-separated).
    protocols: ?[]const u8,

    /// Whether the connection is established.
    connected: bool,

    /// Negotiated protocol from server.
    negotiated_protocol: ?[]const u8,

    /// Cookie manager for handshake cookies (shared with Fetch API)
    cookie_manager: ?*CurlCookieManager,

    /// TLS trust for a wss:// handshake.
    ///
    /// The handshake is a fetch (WebSockets § 2.2 step 11), so it trusts what
    /// every other fetch trusts: the embedder's defaults, which is where the
    /// WPT runner registers the WPT certificate authority. Any paths are
    /// borrowed from whoever registered them.
    cert_options: fetch.network.CertVerifyOptions,

    const Self = @This();

    /// Options for WebSocket initialization.
    pub const Options = struct {
        /// Subprotocols to request
        protocols: ?[]const []const u8 = null,

        /// Cookie manager for handshake (shared with Fetch API)
        cookie_manager: ?*CurlCookieManager = null,

        /// TLS trust; null means fetch's defaults.
        cert_options: ?fetch.network.CertVerifyOptions = null,
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

        self.* = .{
            .allocator = allocator,
            .handle = null,
            .url = url_copy,
            .protocols = protocols_copy,
            .connected = false,
            .negotiated_protocol = null,
            .cookie_manager = options.cookie_manager,
            .cert_options = options.cert_options orelse fetch.network.defaultCertOptions(),
        };

        return self;
    }

    /// Clean up the backend and free resources.
    pub fn deinit(self: *Self) void {
        if (self.handle) |h| {
            curl.easy_cleanup(h);
            self.handle = null;
        }

        if (self.negotiated_protocol) |p| {
            self.allocator.free(p);
        }

        if (self.protocols) |p| {
            self.allocator.free(p);
        }

        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }

    /// Establish the WebSocket connection.
    ///
    /// Performs the HTTP Upgrade handshake and establishes the WebSocket connection.
    pub fn connect(self: *Self) !void {
        if (self.connected) {
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

        // Add Sec-WebSocket-Protocol header if protocols specified
        var headers: ?*curl.curl_slist = null;
        defer if (headers) |h| curl.slist_free_all(h);

        if (self.protocols) |protos| {
            // `allocPrintZ` is gone in Zig 0.16. This line had never been
            // compiled: nothing reached `connect` with a protocol list until
            // the WebSocket impl started passing one, so the branch sat
            // unanalysed exactly as AGENTS.md describes for `src/websocket/`.
            const header = try std.fmt.allocPrintSentinel(
                self.allocator,
                "Sec-WebSocket-Protocol: {s}",
                .{protos},
                0,
            );
            defer self.allocator.free(header);

            headers = curl.slist_append(headers, header.ptr);
            if (headers == null) {
                return error.OutOfMemory;
            }

            result = curl.easy_setopt(handle, curl.CURLOPT_HTTPHEADER, headers);
            if (result != curl.CURLE_OK) {
                return error.CurlSetoptFailed;
            }
        }

        // Perform the handshake
        result = curl.easy_perform(handle);
        if (result != curl.CURLE_OK) {
            return error.HandshakeFailed;
        }

        // Check response code
        var response_code: c_long = 0;
        result = curl.easy_getinfo(handle, curl.CURLINFO_RESPONSE_CODE, &response_code);
        if (result != curl.CURLE_OK) {
            return error.CurlGetinfoFailed;
        }

        // WebSocket upgrade should return 101 Switching Protocols
        if (response_code != 101 and response_code != 0) {
            return error.HandshakeFailed;
        }

        // The subprotocol in use, if the handshake allows the connection at
        // all. libcurl validates Sec-WebSocket-Accept; it does not look at
        // Sec-WebSocket-Protocol.
        const selected = try selectSubprotocol(self.protocols, responseHeader(handle, "Sec-WebSocket-Protocol"));
        if (selected) |p| self.negotiated_protocol = try self.allocator.dupe(u8, p);

        self.handle = handle;
        self.connected = true;
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

    /// Send a text frame.
    pub fn sendText(self: *Self, data: []const u8) !void {
        try self.sendFrame(data, curl.CURLWS_TEXT);
    }

    /// Send a binary frame.
    pub fn sendBinary(self: *Self, data: []const u8) !void {
        try self.sendFrame(data, curl.CURLWS_BINARY);
    }

    /// Send a close frame.
    pub fn sendClose(self: *Self, code: u16, reason: ?[]const u8) !void {
        // Build close frame payload: 2-byte code + optional reason
        var payload: [125]u8 = undefined; // Max close reason is 123 bytes + 2 byte code
        payload[0] = @intCast((code >> 8) & 0xFF);
        payload[1] = @intCast(code & 0xFF);

        var len: usize = 2;
        if (reason) |r| {
            const reason_len = @min(r.len, 123);
            @memcpy(payload[2..][0..reason_len], r[0..reason_len]);
            len += reason_len;
        }

        try self.sendFrame(payload[0..len], curl.CURLWS_CLOSE);
    }

    /// Send a ping frame.
    pub fn sendPing(self: *Self, data: ?[]const u8) !void {
        try self.sendFrame(data orelse "", curl.CURLWS_PING);
    }

    /// Send a pong frame.
    pub fn sendPong(self: *Self, data: ?[]const u8) !void {
        try self.sendFrame(data orelse "", curl.CURLWS_PONG);
    }

    /// Send a frame with the specified flags.
    fn sendFrame(self: *Self, data: []const u8, flags: c_uint) !void {
        const handle = self.handle orelse return error.NotConnected;

        var sent: usize = 0;
        const result = curl.ws_send(
            handle,
            data.ptr,
            data.len,
            &sent,
            0, // fragsize = 0 means send as single frame
            flags,
        );

        if (result != curl.CURLE_OK) {
            return error.SendFailed;
        }

        if (sent != data.len) {
            return error.PartialSend;
        }
    }

    /// Received frame information.
    pub const ReceivedFrame = struct {
        data: []const u8,
        is_text: bool,
        is_close: bool,
        close_code: ?u16,
    };

    /// Receive a frame (non-blocking).
    ///
    /// Returns the received frame data, or null if no data is available.
    /// Returns error.WouldBlock if the operation would block.
    pub fn receive(self: *Self, buffer: []u8) !?ReceivedFrame {
        const handle = self.handle orelse return error.NotConnected;

        var recv_count: usize = 0;
        var meta: ?*const curl.curl_ws_frame = null;

        const result = curl.ws_recv(handle, buffer.ptr, buffer.len, &recv_count, &meta);

        if (result == curl.c.CURLE_AGAIN) {
            return error.WouldBlock;
        }

        if (result != curl.CURLE_OK) {
            return error.ReceiveFailed;
        }

        if (recv_count == 0) {
            return null;
        }

        // Get frame metadata
        const frame_meta = meta orelse curl.ws_meta(handle) orelse return error.NoMetadata;

        const is_text = (frame_meta.flags & @as(c_int, @intCast(curl.CURLWS_TEXT))) != 0;
        const is_close = (frame_meta.flags & @as(c_int, @intCast(curl.CURLWS_CLOSE))) != 0;

        var close_code: ?u16 = null;
        if (is_close and recv_count >= 2) {
            close_code = (@as(u16, buffer[0]) << 8) | @as(u16, buffer[1]);
        }

        return .{
            .data = buffer[0..recv_count],
            .is_text = is_text,
            .is_close = is_close,
            .close_code = close_code,
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
    try std.testing.expectError(error.NotConnected, ws.sendText("hello"));
    try std.testing.expectError(error.NotConnected, ws.sendBinary("hello"));

    var buffer: [100]u8 = undefined;
    try std.testing.expectError(error.NotConnected, ws.receive(&buffer));
}
