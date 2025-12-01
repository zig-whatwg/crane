//! RFC 6455 WebSocket Close Status Codes
//!
//! Defines the standard close status codes as specified in RFC 6455 Section 7.4.1:
//! https://datatracker.ietf.org/doc/html/rfc6455#section-7.4.1
//!
//! Close codes indicate the reason for closing the WebSocket connection.
//! They are sent in the Close frame and made available via CloseEvent.code.
//!
//! ## Code Ranges
//!
//! - 0-999: Not used (reserved)
//! - 1000-2999: Protocol-defined codes (RFC 6455 and extensions)
//! - 3000-3999: Registered for use by libraries/frameworks/applications
//! - 4000-4999: Reserved for private use (application-specific)
//!
//! ## References
//!
//! - RFC 6455 Section 7.4.1: https://datatracker.ietf.org/doc/html/rfc6455#section-7.4.1
//! - IANA WebSocket Close Code Registry: https://www.iana.org/assignments/websocket/websocket.xml

const std = @import("std");

/// Standard WebSocket close status codes as defined in RFC 6455.
pub const CloseCodes = struct {
    /// 1000 - Normal closure; the connection successfully completed.
    /// This is the "clean" close code indicating the purpose of the connection was fulfilled.
    pub const NORMAL_CLOSURE: u16 = 1000;

    /// 1001 - Going away; the endpoint is going away (e.g., server shutting down,
    /// browser navigating away from page).
    pub const GOING_AWAY: u16 = 1001;

    /// 1002 - Protocol error; the endpoint received a frame that violates the protocol.
    pub const PROTOCOL_ERROR: u16 = 1002;

    /// 1003 - Unsupported data; the endpoint received data it cannot accept
    /// (e.g., text-only endpoint received binary).
    pub const UNSUPPORTED_DATA: u16 = 1003;

    /// 1004 - Reserved. A meaning might be defined in the future.
    pub const RESERVED: u16 = 1004;

    /// 1005 - No status received. Reserved value; MUST NOT be set in a Close frame.
    /// Used internally when no close code was provided.
    pub const NO_STATUS_RECEIVED: u16 = 1005;

    /// 1006 - Abnormal closure. Reserved value; MUST NOT be set in a Close frame.
    /// Used when the connection was closed abnormally (without a Close frame).
    pub const ABNORMAL_CLOSURE: u16 = 1006;

    /// 1007 - Invalid frame payload data; the endpoint received data that was
    /// not consistent with the message type (e.g., non-UTF-8 in a text message).
    pub const INVALID_FRAME_PAYLOAD_DATA: u16 = 1007;

    /// 1008 - Policy violation; the endpoint received a message that violates its policy.
    /// Generic status code when 1003 or 1009 are not suitable.
    pub const POLICY_VIOLATION: u16 = 1008;

    /// 1009 - Message too big; the endpoint received a message too large to process.
    pub const MESSAGE_TOO_BIG: u16 = 1009;

    /// 1010 - Mandatory extension. Client expected the server to negotiate an extension,
    /// but the server didn't include it in the response.
    pub const MANDATORY_EXTENSION: u16 = 1010;

    /// 1011 - Internal server error. Server encountered an unexpected condition
    /// that prevented it from fulfilling the request.
    pub const INTERNAL_ERROR: u16 = 1011;

    /// 1012 - Service restart. Server is restarting. (Not in original RFC 6455,
    /// registered later via IANA)
    pub const SERVICE_RESTART: u16 = 1012;

    /// 1013 - Try again later. Server is overloaded or doing maintenance,
    /// client should try again later. (Not in original RFC 6455, registered later via IANA)
    pub const TRY_AGAIN_LATER: u16 = 1013;

    /// 1014 - Bad gateway. Server acting as gateway/proxy received invalid response.
    /// (Not in original RFC 6455, registered later via IANA)
    pub const BAD_GATEWAY: u16 = 1014;

    /// 1015 - TLS handshake failed. Reserved value; MUST NOT be set in a Close frame.
    /// Used when TLS handshake fails (e.g., server certificate can't be verified).
    pub const TLS_HANDSHAKE: u16 = 1015;

    /// Check if a close code is valid for use in a Close frame.
    /// Per RFC 6455, codes 1005, 1006, and 1015 must not be set in Close frames.
    pub fn isValidForCloseFrame(code: u16) bool {
        return switch (code) {
            NO_STATUS_RECEIVED, ABNORMAL_CLOSURE, TLS_HANDSHAKE => false,
            else => isValidCode(code),
        };
    }

    /// Check if a close code is in a valid range.
    /// Valid ranges: 1000-2999 (protocol), 3000-3999 (registered), 4000-4999 (private)
    pub fn isValidCode(code: u16) bool {
        return code >= 1000 and code <= 4999;
    }

    /// Check if a close code is in the private use range (4000-4999).
    pub fn isPrivateUse(code: u16) bool {
        return code >= 4000 and code <= 4999;
    }

    /// Check if a close code is in the registered range (3000-3999).
    pub fn isRegistered(code: u16) bool {
        return code >= 3000 and code <= 3999;
    }

    /// Check if a close code is a protocol-defined code (1000-2999).
    pub fn isProtocolDefined(code: u16) bool {
        return code >= 1000 and code <= 2999;
    }

    /// Get a human-readable description for a close code.
    pub fn getDescription(code: u16) []const u8 {
        return switch (code) {
            NORMAL_CLOSURE => "Normal Closure",
            GOING_AWAY => "Going Away",
            PROTOCOL_ERROR => "Protocol Error",
            UNSUPPORTED_DATA => "Unsupported Data",
            RESERVED => "Reserved",
            NO_STATUS_RECEIVED => "No Status Received",
            ABNORMAL_CLOSURE => "Abnormal Closure",
            INVALID_FRAME_PAYLOAD_DATA => "Invalid Frame Payload Data",
            POLICY_VIOLATION => "Policy Violation",
            MESSAGE_TOO_BIG => "Message Too Big",
            MANDATORY_EXTENSION => "Mandatory Extension",
            INTERNAL_ERROR => "Internal Error",
            SERVICE_RESTART => "Service Restart",
            TRY_AGAIN_LATER => "Try Again Later",
            BAD_GATEWAY => "Bad Gateway",
            TLS_HANDSHAKE => "TLS Handshake Failure",
            else => if (isPrivateUse(code))
                "Private Use"
            else if (isRegistered(code))
                "Registered"
            else
                "Unknown",
        };
    }
};

// =============================================================================
// Tests
// =============================================================================

test "close_codes - standard codes" {
    try std.testing.expectEqual(@as(u16, 1000), CloseCodes.NORMAL_CLOSURE);
    try std.testing.expectEqual(@as(u16, 1001), CloseCodes.GOING_AWAY);
    try std.testing.expectEqual(@as(u16, 1002), CloseCodes.PROTOCOL_ERROR);
    try std.testing.expectEqual(@as(u16, 1011), CloseCodes.INTERNAL_ERROR);
}

test "close_codes - isValidForCloseFrame" {
    // Valid codes
    try std.testing.expect(CloseCodes.isValidForCloseFrame(1000));
    try std.testing.expect(CloseCodes.isValidForCloseFrame(1001));
    try std.testing.expect(CloseCodes.isValidForCloseFrame(1002));
    try std.testing.expect(CloseCodes.isValidForCloseFrame(3000));
    try std.testing.expect(CloseCodes.isValidForCloseFrame(4000));

    // Invalid codes (reserved, must not be sent)
    try std.testing.expect(!CloseCodes.isValidForCloseFrame(1005));
    try std.testing.expect(!CloseCodes.isValidForCloseFrame(1006));
    try std.testing.expect(!CloseCodes.isValidForCloseFrame(1015));

    // Out of range
    try std.testing.expect(!CloseCodes.isValidForCloseFrame(999));
    try std.testing.expect(!CloseCodes.isValidForCloseFrame(5000));
}

test "close_codes - isValidCode" {
    try std.testing.expect(CloseCodes.isValidCode(1000));
    try std.testing.expect(CloseCodes.isValidCode(4999));
    try std.testing.expect(!CloseCodes.isValidCode(999));
    try std.testing.expect(!CloseCodes.isValidCode(5000));
    try std.testing.expect(!CloseCodes.isValidCode(0));
}

test "close_codes - ranges" {
    // Protocol defined
    try std.testing.expect(CloseCodes.isProtocolDefined(1000));
    try std.testing.expect(CloseCodes.isProtocolDefined(2999));
    try std.testing.expect(!CloseCodes.isProtocolDefined(3000));

    // Registered
    try std.testing.expect(CloseCodes.isRegistered(3000));
    try std.testing.expect(CloseCodes.isRegistered(3999));
    try std.testing.expect(!CloseCodes.isRegistered(2999));
    try std.testing.expect(!CloseCodes.isRegistered(4000));

    // Private use
    try std.testing.expect(CloseCodes.isPrivateUse(4000));
    try std.testing.expect(CloseCodes.isPrivateUse(4999));
    try std.testing.expect(!CloseCodes.isPrivateUse(3999));
    try std.testing.expect(!CloseCodes.isPrivateUse(5000));
}

test "close_codes - getDescription" {
    try std.testing.expectEqualStrings("Normal Closure", CloseCodes.getDescription(1000));
    try std.testing.expectEqualStrings("Protocol Error", CloseCodes.getDescription(1002));
    try std.testing.expectEqualStrings("Abnormal Closure", CloseCodes.getDescription(1006));
    try std.testing.expectEqualStrings("Private Use", CloseCodes.getDescription(4001));
    try std.testing.expectEqualStrings("Registered", CloseCodes.getDescription(3500));
}
