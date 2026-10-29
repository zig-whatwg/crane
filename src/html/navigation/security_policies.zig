//! X-Frame-Options as a value and a framing decision (HTML 7.1.8).
//!
//! The cross-origin opener and embedder policies are fetch's data
//! (fetch.internal.cross_origin_policies) and html's decisions
//! (opener_policy.zig); the cross-origin resource policy check is Fetch's.
//! Sandboxing flag sets are dom.sandboxing; "allowed by sandboxing to
//! navigate" is html.navigation.sandbox_navigation.
//!
//! Spec: https://html.spec.whatwg.org/multipage/document-lifecycle.html#the-x-frame-options-header

const std = @import("std");

// ============================================================================
// X-Frame-Options Check
// ============================================================================

/// X-Frame-Options value
pub const XFrameOptions = enum {
    /// No X-Frame-Options header
    none,
    /// DENY - never allow framing
    deny,
    /// SAMEORIGIN - only same-origin framing
    sameorigin,

    pub fn parse(value: ?[]const u8) XFrameOptions {
        if (value == null) return .none;

        const trimmed = std.mem.trim(u8, value.?, " \t");

        if (std.ascii.eqlIgnoreCase(trimmed, "deny")) {
            return .deny;
        }
        if (std.ascii.eqlIgnoreCase(trimmed, "sameorigin")) {
            return .sameorigin;
        }

        return .none;
    }
};

/// Check if framing is allowed by X-Frame-Options
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#the-x-frame-options-header
pub fn isFramingAllowed(
    x_frame_options: XFrameOptions,
    is_same_origin: bool,
) bool {
    return switch (x_frame_options) {
        .none => true,
        .deny => false,
        .sameorigin => is_same_origin,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "XFrameOptions - parse" {
    try std.testing.expectEqual(XFrameOptions.deny, XFrameOptions.parse("DENY"));
    try std.testing.expectEqual(XFrameOptions.sameorigin, XFrameOptions.parse("SAMEORIGIN"));
    try std.testing.expectEqual(XFrameOptions.none, XFrameOptions.parse(null));
}

test "isFramingAllowed" {
    try std.testing.expect(isFramingAllowed(.none, false));
    try std.testing.expect(!isFramingAllowed(.deny, true));
    try std.testing.expect(!isFramingAllowed(.deny, false));
    try std.testing.expect(isFramingAllowed(.sameorigin, true));
    try std.testing.expect(!isFramingAllowed(.sameorigin, false));
}
