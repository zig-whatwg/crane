//! W3C Referrer Policy Module
//!
//! Spec: https://w3c.github.io/webappsec-referrer-policy/
//!
//! This module provides:
//! - ReferrerPolicy enum with all policy values
//! - Parsing of Referrer-Policy header
//! - "Determine request's referrer" algorithm
//! - URL stripping for referrer use
//!
//! ## Usage
//!
//! ```zig
//! const referrer_policy = @import("fetch").referrer_policy;
//!
//! // Parse a policy from header
//! const policy = referrer_policy.parseReferrerPolicyHeader("strict-origin-when-cross-origin");
//!
//! // Determine referrer for a request
//! const referrer = try referrer_policy.determineReferrer(
//!     allocator,
//!     policy.?,
//!     source_info,
//!     target_info,
//!     is_same_origin,
//! );
//! defer referrer.deinit(allocator);
//!
//! switch (referrer) {
//!     .no_referrer => {}, // Don't send Referer header
//!     .url => |url| {}, // Send this URL as Referer
//! }
//! ```

const std = @import("std");

pub const policy = @import("policy.zig");
pub const determine_referrer = @import("determine_referrer.zig");

// Re-export main types and functions
pub const ReferrerPolicy = policy.ReferrerPolicy;
pub const parseReferrerPolicyHeader = policy.parseReferrerPolicyHeader;

pub const Referrer = determine_referrer.Referrer;
pub const ReferrerSource = determine_referrer.ReferrerSource;
pub const TargetInfo = determine_referrer.TargetInfo;
pub const determineReferrer = determine_referrer.determineReferrer;
pub const stripUrlForReferrer = determine_referrer.stripUrlForReferrer;

test {
    std.testing.refAllDecls(@This());
}
