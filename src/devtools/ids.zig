//! The ids CDP names things by.
//!
//! Chrome's are 32 uppercase hex digits for targets, frames and browser
//! contexts (base::UnguessableToken::ToString, used by
//! render_frame_devtools_agent_host.cc for a frame's devtools frame token -
//! which IS the page target's id - and by DevToolsSession for session ids).
//! Crane's frame ids carry what they name, so the devtools thread can route
//! by them without a table: the first 16 digits are the Browser's (one random
//! token per Browser, made when the remote end first sees it), the last 16
//! the navigable's BrowsingContext id. A page target's id is its top-level
//! traversable's frame id (tmp/plans/cdp-part1-design.md 1.2: "A page
//! target's id IS its main frame's id").

const std = @import("std");

/// A 32-hex-digit token, as Chrome prints an UnguessableToken.
pub const Token = struct {
    text: [32]u8,

    pub fn slice(self: *const Token) []const u8 {
        return &self.text;
    }

    pub fn eql(self: Token, other: []const u8) bool {
        return std.mem.eql(u8, &self.text, other);
    }

    /// The token of two 64-bit halves.
    pub fn of(high_half: u64, low_half: u64) Token {
        var token: Token = undefined;
        _ = std.fmt.bufPrint(&token.text, "{X:0>16}{X:0>16}", .{ high_half, low_half }) catch unreachable;
        return token;
    }

    /// Parse a token; null when `text` is not 32 hex digits.
    pub fn parse(text: []const u8) ?Token {
        if (text.len != 32) return null;
        for (text) |ch| if (!std.ascii.isHex(ch)) return null;
        var token: Token = undefined;
        for (text, 0..) |ch, i| token.text[i] = std.ascii.toUpper(ch);
        return token;
    }

    pub fn high(self: Token) u64 {
        return std.fmt.parseInt(u64, self.text[0..16], 16) catch unreachable;
    }

    pub fn low(self: Token) u64 {
        return std.fmt.parseInt(u64, self.text[16..32], 16) catch unreachable;
    }
};

/// A frame id (and a page target's id): the Browser's token and the
/// navigable's BrowsingContext id.
pub fn frameId(browser_token: u64, navigable_id: u64) Token {
    return Token.of(browser_token, navigable_id);
}

/// What a frame id names: its Browser's token and navigable id.
pub const FrameRef = struct {
    browser_token: u64,
    navigable_id: u64,
};

pub fn parseFrameId(text: []const u8) ?FrameRef {
    const token = Token.parse(text) orelse return null;
    return .{ .browser_token = token.high(), .navigable_id = token.low() };
}

/// A token from `random` (64 random bits) and a counter, so two ids made in
/// one process never collide: sessions, tab targets, browser contexts.
pub fn fresh(random_high: u64, counter: u64) Token {
    return Token.of(random_high, counter);
}

test "a frame id carries its Browser's token and navigable id" {
    const id = frameId(0xDEADBEEF, 42);
    try std.testing.expectEqualStrings("00000000DEADBEEF000000000000002A", id.slice());
    const ref = parseFrameId(id.slice()).?;
    try std.testing.expectEqual(@as(u64, 0xDEADBEEF), ref.browser_token);
    try std.testing.expectEqual(@as(u64, 42), ref.navigable_id);
}

test "parse accepts lowercase and refuses anything but 32 hex digits" {
    try std.testing.expect(Token.parse("00000000deadbeef000000000000002a") != null);
    try std.testing.expect(Token.parse("short") == null);
    try std.testing.expect(Token.parse("Z0000000DEADBEEF000000000000002A") == null);
}
