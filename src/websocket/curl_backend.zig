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
const close_codes = @import("close_codes.zig");

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

    const Self = @This();

    /// Initialize a new WebSocket backend.
    ///
    /// Parameters:
    /// - allocator: Memory allocator
    /// - url: WebSocket URL (ws:// or wss://)
    /// - protocols: Optional list of subprotocols to request
    pub fn init(allocator: std.mem.Allocator, url: []const u8, protocols: ?[]const []const u8) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        // Copy URL
        const url_copy = try allocator.dupe(u8, url);
        errdefer allocator.free(url_copy);

        // Build comma-separated protocol list if provided
        var protocols_copy: ?[]const u8 = null;
        if (protocols) |protos| {
            if (protos.len > 0) {
                var total_len: usize = 0;
                for (protos) |p| {
                    total_len += p.len + 1; // +1 for comma or null
                }

                const buf = try allocator.alloc(u8, total_len);
                errdefer allocator.free(buf);

                var offset: usize = 0;
                for (protos, 0..) |p, i| {
                    @memcpy(buf[offset..][0..p.len], p);
                    offset += p.len;
                    if (i < protos.len - 1) {
                        buf[offset] = ',';
                        offset += 1;
                    }
                }

                protocols_copy = buf[0..offset];
            }
        }

        self.* = .{
            .allocator = allocator,
            .handle = null,
            .url = url_copy,
            .protocols = protocols_copy,
            .connected = false,
            .negotiated_protocol = null,
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

        // Add Sec-WebSocket-Protocol header if protocols specified
        var headers: ?*curl.curl_slist = null;
        defer if (headers) |h| curl.slist_free_all(h);

        if (self.protocols) |protos| {
            const header = try std.fmt.allocPrintZ(self.allocator, "Sec-WebSocket-Protocol: {s}", .{protos});
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

        self.handle = handle;
        self.connected = true;
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
