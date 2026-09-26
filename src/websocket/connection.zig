//! WebSocket Connection State Machine
//!
//! The protocol half of a WebSocket: RFC 6455's connection, its closing
//! handshake, and the queue `bufferedAmount` measures. The WebSocket interface
//! (src/webidl/impls/WebSocket.zig) drives it one event-loop turn at a time and
//! fires the events it reports; nothing here reaches JavaScript.
//!
//! ## States
//!
//! `state` is the WebSocket object's ready state as the protocol moves it:
//!
//! ```
//! CONNECTING --(handshake done)--> OPEN --(close() / peer's Close)--> CLOSING
//!     |                                                                 |
//!     +--(close(): fail the connection)--> CLOSING                      |
//!                                                                       v
//!                          CLOSED  <--  the close task (the interface's pump)
//! ```
//!
//! CLOSED is set by the task that fires the close event, never here: WebSockets
//! § 4 changes the ready state to CLOSED in that task, after the connection has
//! closed. `closed` is RFC 6455's "_The WebSocket Connection is Closed_"
//! (§ 7.1.4), which is what queues that task.
//!
//! ## References
//!
//! - WHATWG WebSockets: https://websockets.spec.whatwg.org/
//! - RFC 6455 § 5.5.1 (Close), § 7 (closing the connection)

const std = @import("std");
const close_codes = @import("close_codes.zig");
const curl_backend = @import("curl_backend.zig");
const utf8 = @import("utf8.zig");

const CloseCodes = close_codes.CloseCodes;
const FrameKind = curl_backend.FrameKind;

/// WebSocket ready state values matching the WHATWG spec.
/// https://websockets.spec.whatwg.org/#dom-websocket-readystate
pub const ConnectionState = enum(u16) {
    /// The connection has not yet been established.
    CONNECTING = 0,

    /// The WebSocket connection is established and communication is possible.
    OPEN = 1,

    /// The connection is going through the closing handshake,
    /// or the close() method has been invoked.
    CLOSING = 2,

    /// The connection has been closed or could not be opened.
    CLOSED = 3,

    /// Convert to the numeric ready state value for the WebSocket API.
    pub fn toReadyState(self: ConnectionState) u16 {
        return @intFromEnum(self);
    }

    /// Check if the connection can send messages.
    pub fn canSend(self: ConnectionState) bool {
        return self == .OPEN;
    }

    /// Check if the connection is terminal (won't change further).
    pub fn isTerminal(self: ConnectionState) bool {
        return self == .CLOSED;
    }
};

/// WebSocket binary data type preference.
/// https://websockets.spec.whatwg.org/#dom-websocket-binarytype
pub const BinaryType = enum {
    /// Binary data is returned as Blob objects.
    blob,
    /// Binary data is returned as ArrayBuffer objects.
    arraybuffer,
};

/// The largest Close frame payload: a control frame carries at most 125 bytes
/// (RFC 6455 § 5.5), two of them the status code.
pub const max_close_payload = 125;

/// The body of a Close frame for `code` and `reason`.
///
/// WebSockets § 3.1, close() step 3: "If neither code nor reason is present,
/// the WebSocket Close message must not have a body" - RFC 6455 wrongly calls
/// the status code required. A reason is only ever sent after a code, and
/// close() has already checked it fits.
pub fn buildClosePayload(buffer: *[max_close_payload]u8, code: ?u16, reason: ?[]const u8) []const u8 {
    const c = code orelse return buffer[0..0];
    std.mem.writeInt(u16, buffer[0..2], c, .big);
    const r = reason orelse "";
    const n = @min(r.len, max_close_payload - 2);
    @memcpy(buffer[2..][0..n], r[0..n]);
    return buffer[0 .. 2 + n];
}

/// What a received Close frame says: its status code, if it has one, and its
/// reason.
pub const ClosePayload = struct {
    code: ?u16,
    reason: []const u8,
};

/// Read a Close frame's body (RFC 6455 § 5.5.1).
///
/// An empty body is a close with no status code - reported as 1005 (§ 7.1.5).
/// A one-byte body cannot hold a status code, and is a protocol error.
pub fn parseClosePayload(payload: []const u8) error{ProtocolError}!ClosePayload {
    if (payload.len == 0) return .{ .code = null, .reason = "" };
    if (payload.len == 1) return error.ProtocolError;
    return .{
        .code = std.mem.readInt(u16, payload[0..2], .big),
        .reason = payload[2..],
    };
}

/// A frame queued for the socket.
const OutgoingFrame = struct {
    kind: FrameKind,
    /// Owned copy of the payload.
    payload: []u8,
    /// How much of `payload` the socket has taken.
    sent: usize = 0,

    fn isData(self: OutgoingFrame) bool {
        return self.kind == .text or self.kind == .binary;
    }
};

/// Frames waiting for the socket, oldest first, and the bytes of application
/// data among them the socket has not taken - which is what `bufferedAmount`
/// counts. The head frame may be part-sent: libcurl keeps a frame open until
/// it has had all of it, so the head goes out before anything behind it.
pub const OutgoingQueue = struct {
    frames: std.ArrayListUnmanaged(OutgoingFrame) = .empty,
    /// Application bytes (text and binary payloads) not yet taken.
    untransmitted: u64 = 0,

    /// Drop every frame. The queue is empty afterwards, not undefined: the
    /// connection drops it when its transport goes AND when it is freed, and
    /// `ArrayListUnmanaged.deinit` alone leaves the list `undefined`, which
    /// the second drop would free as if it were memory.
    pub fn deinit(self: *OutgoingQueue, allocator: std.mem.Allocator) void {
        for (self.frames.items) |f| allocator.free(f.payload);
        self.frames.deinit(allocator);
        self.* = .{};
    }

    pub fn push(self: *OutgoingQueue, allocator: std.mem.Allocator, kind: FrameKind, payload: []const u8) !void {
        const copy = try allocator.dupe(u8, payload);
        errdefer allocator.free(copy);
        try self.frames.append(allocator, .{ .kind = kind, .payload = copy });
        if (self.frames.items[self.frames.items.len - 1].isData()) self.untransmitted += payload.len;
    }

    /// The head frame's kind and the part of it not yet taken, if any.
    pub fn head(self: *const OutgoingQueue) ?struct { kind: FrameKind, remaining: []const u8 } {
        if (self.frames.items.len == 0) return null;
        const f = self.frames.items[0];
        return .{ .kind = f.kind, .remaining = f.payload[f.sent..] };
    }

    /// The socket took `accepted` more bytes of the head frame. Returns the
    /// head's kind if that finished it (and it has left the queue).
    pub fn advance(self: *OutgoingQueue, allocator: std.mem.Allocator, accepted: usize) ?FrameKind {
        const f = &self.frames.items[0];
        std.debug.assert(accepted <= f.payload.len - f.sent);
        f.sent += accepted;
        if (f.isData()) self.untransmitted -= accepted;
        if (f.sent < f.payload.len) return null;
        const done = self.frames.orderedRemove(0);
        allocator.free(done.payload);
        return done.kind;
    }
};

/// WebSocket connection abstraction.
/// Manages the connection lifecycle and wraps the underlying transport (libcurl).
pub const WebSocketConnection = struct {
    allocator: std.mem.Allocator,

    /// The WebSocket object's ready state, as far as the protocol moves it.
    /// See the module comment: CLOSED is the close task's to set.
    state: ConnectionState,

    /// The URL of the WebSocket server.
    url: []const u8,

    /// The negotiated subprotocol (if any).
    protocol: ?[]const u8,

    /// Extensions negotiated with the server.
    extensions: ?[]const u8,

    /// Binary type preference (blob or arraybuffer).
    binary_type: BinaryType,

    /// Underlying curl backend connection. Released once the connection is
    /// closed, which is what closes the TCP connection.
    backend: ?*curl_backend.CurlWebSocket,

    /// The WebSocket connection close code (RFC 6455 § 7.1.5): the status code
    /// of the first Close frame received, 1005 if it had none, 1006 if the
    /// connection closed without one. Null until `closed`.
    close_code: ?u16,

    /// The WebSocket connection close reason (§ 7.1.6): the received Close
    /// frame's reason, owned. Null when there was none.
    close_reason: ?[]const u8,

    /// Whether the connection closed cleanly (§ 7.1.4): both Close frames
    /// exchanged before the TCP connection went.
    close_was_clean: bool,

    /// "_The WebSocket Connection is Closed_" (§ 7.1.4). The interface's cue to
    /// run the close task.
    closed: bool = false,

    /// Set when the connection had to be failed (§ 7.1.7): the close task then
    /// fires `error` before `close` (WebSockets § 4, "the WebSocket connection
    /// is closed" step 2).
    failed: bool = false,

    /// Frames `send` and the closing handshake queued. See `OutgoingQueue`.
    outgoing: OutgoingQueue = .{},

    /// Application bytes `send` was given once the closing handshake had
    /// started. They are discarded - and still counted: WebSockets § 3.1, "If
    /// the WebSocket connection is closed, this attribute's value will only
    /// increase with each call to the send() method."
    discarded: u64 = 0,

    /// Whether our Close frame is queued - the closing handshake is started,
    /// by close() or in answer to the peer's (§ 7.1.3).
    close_queued: bool = false,

    /// Whether our Close frame has been handed to the socket in full.
    close_sent: bool = false,

    /// Whether the peer's Close frame has arrived.
    close_received: bool = false,

    /// The message being assembled across frames and receive calls.
    incoming: std.ArrayListUnmanaged(u8) = .empty,
    /// Whether `incoming` holds the message `receive` last returned, to be
    /// dropped when it is next called.
    incoming_delivered: bool = false,
    /// A Close frame's body, assembled across receive calls.
    incoming_close: std.ArrayListUnmanaged(u8) = .empty,

    const Self = @This();

    /// Initialize a new WebSocket connection.
    ///
    /// This creates the connection object in CONNECTING state.
    /// The actual connection is established by `startConnect`/`pollConnect`.
    pub fn init(allocator: std.mem.Allocator, url: []const u8) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        // Copy the URL for ownership
        const url_copy = try allocator.dupe(u8, url);
        errdefer allocator.free(url_copy);

        self.* = .{
            .allocator = allocator,
            .state = .CONNECTING,
            .url = url_copy,
            .protocol = null,
            .extensions = null,
            .binary_type = .blob,
            .backend = null,
            .close_code = null,
            .close_reason = null,
            .close_was_clean = false,
        };

        return self;
    }

    /// Clean up the connection and free all resources.
    ///
    /// A connection still OPEN here is being made to disappear: the WebSocket
    /// interface keeps its object alive until the close event has fired, so
    /// only its realm ending - the document going away, the worker closing -
    /// frees an open one. WebSockets § 7 then starts the closing handshake with
    /// 1001, so a Close frame is offered to the socket once, without waiting,
    /// before the TCP connection goes. Not behind a part-sent frame: that would
    /// land inside it.
    pub fn deinit(self: *Self) void {
        if (self.state == .OPEN and !self.close_queued) {
            if (self.backend) |backend| {
                if (self.outgoing.head() == null) {
                    var buffer: [max_close_payload]u8 = undefined;
                    _ = backend.sendPart(buildClosePayload(&buffer, CloseCodes.GOING_AWAY, null), .close) catch 0;
                }
            }
        }
        self.releaseTransport();
        self.outgoing.deinit(self.allocator);
        self.incoming.deinit(self.allocator);
        self.incoming_close.deinit(self.allocator);

        // Free allocated strings
        if (self.protocol) |p| {
            self.allocator.free(p);
        }
        if (self.extensions) |e| {
            self.allocator.free(e);
        }
        if (self.close_reason) |r| {
            self.allocator.free(r);
        }

        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }

    /// What the opening handshake sends besides the URL.
    pub const ConnectOptions = struct {
        protocols: ?[]const []const u8 = null,
        /// The client's serialized origin, for the `Origin` header.
        origin: ?[]const u8 = null,
    };

    /// Establish the WebSocket connection, waiting for it. For callers with
    /// nothing else to do; see `startConnect`.
    pub fn connect(self: *Self, protocols: ?[]const []const u8) !void {
        try self.startConnect(.{ .protocols = protocols });
        while (!try self.pollConnect()) {
            const backend = self.backend orelse return error.HandshakeFailed;
            var numfds: c_int = 0;
            if (backend.multi) |multi| _ = @import("fetch").network.curl_ffi.multi_poll(multi, 100, &numfds);
        }
    }

    /// Begin the opening handshake (WebSockets § 2.2). `pollConnect` finishes
    /// it, one event-loop turn at a time.
    pub fn startConnect(self: *Self, options: ConnectOptions) !void {
        if (self.state != .CONNECTING or self.backend != null or self.closed) {
            return error.InvalidState;
        }

        const backend = try curl_backend.CurlWebSocket.initWithOptions(self.allocator, self.url, .{
            .protocols = options.protocols,
            .origin = options.origin,
        });
        self.backend = backend;

        backend.startConnect() catch |err| {
            self.fail();
            return err;
        };
    }

    /// Advance the opening handshake. True once the connection is established
    /// (and `state` is OPEN); false while it is in flight. An error means the
    /// connection was failed, which `closed` and `failed` now say.
    pub fn pollConnect(self: *Self) !bool {
        if (self.state == .OPEN) return true;
        if (self.state != .CONNECTING or self.closed) return error.InvalidState;
        const backend = self.backend orelse return error.NotConnected;

        const established = backend.pollConnect() catch |err| {
            // WebSockets § 2.2 step 11: any failure of the handshake fails the
            // WebSocket connection.
            self.fail();
            return err;
        };
        if (!established) return false;

        if (backend.getProtocol()) |proto| {
            self.protocol = try self.allocator.dupe(u8, proto);
        }
        self.state = .OPEN;
        return true;
    }

    /// Queue a message (WebSockets § 3.1, send() step 2) and push what the
    /// socket will take now.
    ///
    /// Only an OPEN connection whose closing handshake has not started sends;
    /// anything else discards the data, and `bufferedAmount` still counts it.
    pub fn send(self: *Self, kind: FrameKind, data: []const u8) !void {
        if (self.state != .OPEN or self.close_queued or self.closed) {
            self.discarded += data.len;
            return;
        }
        try self.outgoing.push(self.allocator, kind, data);
        self.flush();
    }

    /// Send a text message.
    pub fn sendText(self: *Self, data: []const u8) !void {
        if (!self.state.canSend()) return error.InvalidState;
        try self.send(.text, data);
    }

    /// Send a binary message.
    pub fn sendBinary(self: *Self, data: []const u8) !void {
        if (!self.state.canSend()) return error.InvalidState;
        try self.send(.binary, data);
    }

    /// The bytes `bufferedAmount` reports as of now: application data queued
    /// and not yet taken by the socket, plus everything discarded after the
    /// closing handshake started.
    pub fn bufferedAmount(self: *const Self) u64 {
        return self.outgoing.untransmitted + self.discarded;
    }

    /// Hand the socket as much of the queue as it takes without waiting.
    ///
    /// A transport error closes the connection (abnormally, unless both Close
    /// frames were already exchanged).
    pub fn flush(self: *Self) void {
        const backend = self.backend orelse return;
        // Nothing goes out before the handshake is done.
        if (!backend.connected) return;
        while (self.outgoing.head()) |h| {
            const accepted = backend.sendPart(h.remaining, h.kind) catch |err| switch (err) {
                error.WouldBlock => return,
                else => return self.transportClosed(),
            };
            const finished = self.outgoing.advance(self.allocator, accepted) orelse return;
            if (finished == .close) {
                self.close_sent = true;
                self.maybeClosedCleanly();
                if (self.closed) return;
            }
        }
    }

    /// Receive a message (non-blocking).
    ///
    /// Returns the message data and type, or null if no message is available.
    pub const ReceivedMessage = struct {
        data: []const u8,
        is_text: bool,
    };

    /// The next whole message, if one has arrived; null when none has yet or
    /// the connection is closing or closed. `scratch` is where libcurl writes
    /// each chunk; the returned data lives in the connection and is valid until
    /// the next call.
    ///
    /// A Close frame is handled here - it moves the closing handshake on and
    /// may close the connection - and so is a transport that goes away.
    pub fn receive(self: *Self, scratch: []u8) !?ReceivedMessage {
        if (self.incoming_delivered) {
            self.incoming.clearRetainingCapacity();
            self.incoming_delivered = false;
        }
        if (self.closed) return null;
        const backend = self.backend orelse return null;
        if (!backend.connected) return null;

        while (true) {
            const chunk = backend.receive(scratch) catch |err| switch (err) {
                error.WouldBlock => return null,
                else => {
                    self.transportClosed();
                    return null;
                },
            };

            switch (chunk.kind) {
                // libcurl answers a Ping with a Pong itself, and a Pong
                // answers nothing we asked.
                .ping, .pong => continue,
                .close => {
                    // Only the first Close frame counts (§ 7.1.5).
                    if (self.close_received) continue;
                    if (self.incoming_close.items.len + chunk.data.len > max_close_payload) {
                        self.failWith(CloseCodes.PROTOCOL_ERROR);
                        return null;
                    }
                    try self.incoming_close.appendSlice(self.allocator, chunk.data);
                    if (chunk.bytes_left > 0) continue;
                    self.handleCloseFrame(self.incoming_close.items);
                    return null;
                },
                .text, .binary => {
                    // RFC 6455 § 5.5.1: nothing follows a Close frame.
                    if (self.close_received) continue;
                    try self.incoming.appendSlice(self.allocator, chunk.data);
                    if (chunk.bytes_left > 0 or chunk.more_fragments) continue;

                    self.incoming_delivered = true;
                    // RFC 6455 § 8.1: text that is not UTF-8 fails the
                    // connection, with 1007 for the peer.
                    if (chunk.kind == .text and !utf8.isValidUtf8(self.incoming.items)) {
                        self.failWith(CloseCodes.INVALID_FRAME_PAYLOAD_DATA);
                        return null;
                    }
                    return .{ .data = self.incoming.items, .is_text = chunk.kind == .text };
                },
            }
        }
    }

    /// close() step 3 (WebSockets § 3.1), from "not yet established" on. The
    /// first case - CLOSING or CLOSED, do nothing - is here too.
    ///
    /// `code` and `reason` have been validated by the caller.
    pub fn close(self: *Self, code: ?u16, reason: ?[]const u8) !void {
        if (self.state == .CLOSING or self.state == .CLOSED or self.closed) return;

        if (self.state == .CONNECTING) {
            // "Fail the WebSocket connection and set this's ready state to
            // CLOSING."
            self.fail();
            self.state = .CLOSING;
            return;
        }

        // "Start the WebSocket closing handshake and set this's ready state
        // to CLOSING." Behind whatever send() queued: close() "does not
        // discard previously sent messages".
        try self.queueClose(code, reason);
        self.state = .CLOSING;
        self.flush();
    }

    /// Start the closing handshake from this side (RFC 6455 § 7.1.2).
    fn queueClose(self: *Self, code: ?u16, reason: ?[]const u8) !void {
        if (self.close_queued) return;
        var buffer: [max_close_payload]u8 = undefined;
        try self.outgoing.push(self.allocator, .close, buildClosePayload(&buffer, code, reason));
        self.close_queued = true;
    }

    /// The peer's Close frame has arrived (RFC 6455 § 5.5.1).
    pub fn handleCloseFrame(self: *Self, payload: []const u8) void {
        const parsed = parseClosePayload(payload) catch {
            self.failWith(CloseCodes.PROTOCOL_ERROR);
            return;
        };
        self.close_received = true;

        // § 7.1.5, 7.1.6: the code and reason of the FIRST Close frame
        // received are the connection's - not what close() asked for.
        self.close_code = parsed.code orelse CloseCodes.NO_STATUS_RECEIVED;
        if (self.close_reason) |r| self.allocator.free(r);
        self.close_reason = if (parsed.reason.len > 0)
            self.allocator.dupe(u8, parsed.reason) catch null
        else
            null;

        if (!self.close_queued) {
            // The peer started the closing handshake. § 5.5.1: answer with a
            // Close frame, "typically echoing the status code it received".
            // WebSockets § 4 then moves the ready state to CLOSING.
            self.queueClose(parsed.code, null) catch {
                self.transportClosed();
                return;
            };
            if (self.state == .OPEN) self.state = .CLOSING;
            self.flush();
            return;
        }
        self.maybeClosedCleanly();
    }

    /// Both Close frames are through: the connection is closed, cleanly
    /// (§ 7.1.4). The client may close the TCP connection now (§ 7.1.1).
    fn maybeClosedCleanly(self: *Self) void {
        if (!(self.close_sent and self.close_received) or self.closed) return;
        self.close_was_clean = true;
        self.markClosed();
    }

    /// The TCP connection went - by error, or the peer closing it. Clean only
    /// if the closing handshake had finished; the code is 1006 unless a Close
    /// frame arrived first (§ 7.1.5).
    fn transportClosed(self: *Self) void {
        if (self.closed) return;
        self.close_was_clean = self.close_sent and self.close_received;
        if (!self.close_received) self.close_code = CloseCodes.ABNORMAL_CLOSURE;
        self.markClosed();
    }

    /// "_Fail the WebSocket Connection_" (RFC 6455 § 7.1.7), telling the peer
    /// why when there is a connection to tell.
    fn failWith(self: *Self, code: u16) void {
        if (self.backend) |backend| {
            if (backend.connected and !self.close_queued) {
                var buffer: [max_close_payload]u8 = undefined;
                _ = backend.sendPart(buildClosePayload(&buffer, code, null), .close) catch 0;
            }
        }
        self.fail();
    }

    /// "_Fail the WebSocket Connection_": the connection is closed, not
    /// cleanly, with code 1006 whatever was asked for - and the close task
    /// fires `error` first. The reason is empty.
    pub fn fail(self: *Self) void {
        if (self.closed) return;
        self.failed = true;
        self.close_was_clean = false;
        self.close_code = CloseCodes.ABNORMAL_CLOSURE;
        if (self.close_reason) |r| self.allocator.free(r);
        self.close_reason = null;
        self.markClosed();
    }

    fn markClosed(self: *Self) void {
        if (self.close_code == null) self.close_code = CloseCodes.ABNORMAL_CLOSURE;
        self.closed = true;
        self.releaseTransport();
    }

    /// Close the TCP connection and drop what was waiting to go out on it.
    fn releaseTransport(self: *Self) void {
        if (self.backend) |backend| {
            backend.deinit();
            self.backend = null;
        }
        self.outgoing.deinit(self.allocator);
    }

    /// Get the current ready state as a number (for WebSocket API).
    pub fn getReadyState(self: *const Self) u16 {
        return self.state.toReadyState();
    }

    /// Check if the connection was closed cleanly.
    pub fn wasClean(self: *const Self) bool {
        return self.close_was_clean;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "ConnectionState - values match spec" {
    try std.testing.expectEqual(@as(u16, 0), ConnectionState.CONNECTING.toReadyState());
    try std.testing.expectEqual(@as(u16, 1), ConnectionState.OPEN.toReadyState());
    try std.testing.expectEqual(@as(u16, 2), ConnectionState.CLOSING.toReadyState());
    try std.testing.expectEqual(@as(u16, 3), ConnectionState.CLOSED.toReadyState());
}

test "ConnectionState - canSend" {
    try std.testing.expect(!ConnectionState.CONNECTING.canSend());
    try std.testing.expect(ConnectionState.OPEN.canSend());
    try std.testing.expect(!ConnectionState.CLOSING.canSend());
    try std.testing.expect(!ConnectionState.CLOSED.canSend());
}

test "ConnectionState - isTerminal" {
    try std.testing.expect(!ConnectionState.CONNECTING.isTerminal());
    try std.testing.expect(!ConnectionState.OPEN.isTerminal());
    try std.testing.expect(!ConnectionState.CLOSING.isTerminal());
    try std.testing.expect(ConnectionState.CLOSED.isTerminal());
}

test "BinaryType - values" {
    const bt1: BinaryType = .blob;
    const bt2: BinaryType = .arraybuffer;
    try std.testing.expect(bt1 != bt2);
}
