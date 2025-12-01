//! WebSocket Connection State Machine
//!
//! Implements the WebSocket connection lifecycle as defined in WHATWG WebSockets spec.
//! The connection progresses through states: CONNECTING → OPEN → CLOSING → CLOSED
//!
//! ## State Transitions
//!
//! ```
//!     ┌──────────────────────────────────────────────────┐
//!     │                                                  │
//!     ▼                                                  │
//! CONNECTING ──(handshake success)──► OPEN              │
//!     │                                 │                │
//!     │                                 ▼                │
//!     │                          (send close or         │
//!     │                           receive close)        │
//!     │                                 │                │
//!     │                                 ▼                │
//!     ├──(handshake fail)────────► CLOSING             │
//!     │                                 │                │
//!     │                                 ▼                │
//!     └────────────────────────────► CLOSED ◄───────────┘
//! ```
//!
//! ## References
//!
//! - WHATWG WebSockets: https://websockets.spec.whatwg.org/#dom-websocket-readystate

const std = @import("std");
const close_codes = @import("close_codes.zig");
const curl_backend = @import("curl_backend.zig");

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

/// WebSocket connection abstraction.
/// Manages the connection lifecycle and wraps the underlying transport (libcurl).
pub const WebSocketConnection = struct {
    allocator: std.mem.Allocator,

    /// Current connection state.
    state: ConnectionState,

    /// The URL of the WebSocket server.
    url: []const u8,

    /// The negotiated subprotocol (if any).
    protocol: ?[]const u8,

    /// Extensions negotiated with the server.
    extensions: ?[]const u8,

    /// Binary type preference (blob or arraybuffer).
    binary_type: BinaryType,

    /// Amount of data queued for transmission (in bytes).
    buffered_amount: u64,

    /// Underlying curl backend connection.
    backend: ?*curl_backend.CurlWebSocket,

    /// Close code received or sent (1000-4999).
    close_code: ?u16,

    /// Close reason text.
    close_reason: ?[]const u8,

    /// Whether this side initiated the close.
    close_was_clean: bool,

    const Self = @This();

    /// Initialize a new WebSocket connection.
    ///
    /// This creates the connection object in CONNECTING state.
    /// The actual connection is established by calling `connect()`.
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
            .buffered_amount = 0,
            .backend = null,
            .close_code = null,
            .close_reason = null,
            .close_was_clean = false,
        };

        return self;
    }

    /// Clean up the connection and free all resources.
    pub fn deinit(self: *Self) void {
        // Close backend if still open
        if (self.backend) |backend| {
            backend.deinit();
            self.backend = null;
        }

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

    /// Establish the WebSocket connection.
    ///
    /// Performs the WebSocket handshake via libcurl.
    /// On success, transitions to OPEN state.
    /// On failure, transitions to CLOSED state.
    pub fn connect(self: *Self, protocols: ?[]const []const u8) !void {
        if (self.state != .CONNECTING) {
            return error.InvalidState;
        }

        // Create the curl backend
        var backend = try curl_backend.CurlWebSocket.init(self.allocator, self.url, protocols);
        errdefer backend.deinit();

        // Perform the handshake
        backend.connect() catch |err| {
            self.state = .CLOSED;
            self.close_code = close_codes.CloseCodes.ABNORMAL_CLOSURE;
            backend.deinit();
            return err;
        };

        // Store the backend and transition to OPEN
        self.backend = backend;
        self.state = .OPEN;

        // Get negotiated protocol if any
        if (backend.getProtocol()) |proto| {
            self.protocol = try self.allocator.dupe(u8, proto);
        }
    }

    /// Send a text message.
    pub fn sendText(self: *Self, data: []const u8) !void {
        if (!self.state.canSend()) {
            return error.InvalidState;
        }

        const backend = self.backend orelse return error.NotConnected;
        try backend.sendText(data);
    }

    /// Send a binary message.
    pub fn sendBinary(self: *Self, data: []const u8) !void {
        if (!self.state.canSend()) {
            return error.InvalidState;
        }

        const backend = self.backend orelse return error.NotConnected;
        try backend.sendBinary(data);
    }

    /// Receive a message (non-blocking).
    ///
    /// Returns the message data and type, or null if no message is available.
    pub const ReceivedMessage = struct {
        data: []const u8,
        is_text: bool,
    };

    pub fn receive(self: *Self, buffer: []u8) !?ReceivedMessage {
        if (self.state == .CLOSED) {
            return error.ConnectionClosed;
        }

        const backend = self.backend orelse return error.NotConnected;

        const result = backend.receive(buffer) catch |err| {
            if (err == error.WouldBlock) {
                return null;
            }
            return err;
        };

        if (result) |msg| {
            // Check for close frame
            if (msg.is_close) {
                self.handleCloseFrame(msg.close_code, msg.data);
                return null;
            }

            return .{
                .data = msg.data,
                .is_text = msg.is_text,
            };
        }

        return null;
    }

    /// Start the closing handshake.
    ///
    /// Sends a Close frame and transitions to CLOSING state.
    pub fn close(self: *Self, code: ?u16, reason: ?[]const u8) !void {
        switch (self.state) {
            .CONNECTING => {
                // Fail the connection immediately
                self.state = .CLOSED;
                self.close_code = code orelse close_codes.CloseCodes.ABNORMAL_CLOSURE;
                if (reason) |r| {
                    self.close_reason = try self.allocator.dupe(u8, r);
                }
            },
            .OPEN => {
                // Validate close code if provided
                if (code) |c| {
                    if (!close_codes.CloseCodes.isValidForCloseFrame(c)) {
                        return error.InvalidCloseCode;
                    }
                }

                // Send close frame
                const backend = self.backend orelse return error.NotConnected;
                try backend.sendClose(code orelse close_codes.CloseCodes.NORMAL_CLOSURE, reason);

                self.state = .CLOSING;
                self.close_code = code;
                if (reason) |r| {
                    self.close_reason = try self.allocator.dupe(u8, r);
                }
            },
            .CLOSING => {
                // Already closing, ignore
            },
            .CLOSED => {
                // Already closed, ignore
            },
        }
    }

    /// Handle a received Close frame.
    fn handleCloseFrame(self: *Self, code: ?u16, reason: ?[]const u8) void {
        // If we're already closing, this completes the handshake
        if (self.state == .CLOSING) {
            self.state = .CLOSED;
            self.close_was_clean = true;
            return;
        }

        // Otherwise, we need to send a close frame back
        if (self.state == .OPEN) {
            self.close_code = code orelse close_codes.CloseCodes.NO_STATUS_RECEIVED;
            if (reason) |r| {
                self.close_reason = self.allocator.dupe(u8, r) catch null;
            }

            // Send close frame response
            if (self.backend) |backend| {
                backend.sendClose(
                    code orelse close_codes.CloseCodes.NORMAL_CLOSURE,
                    null,
                ) catch {};
            }

            self.state = .CLOSED;
            self.close_was_clean = true;
        }
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
