//! CORS (Cross-Origin Resource Sharing) Module
//!
//! Spec: https://fetch.spec.whatwg.org/#cors-protocol
//!
//! This module implements CORS-related algorithms from the Fetch specification:
//! - CORS check (validates Access-Control-Allow-Origin header)
//! - TAO check (validates Timing-Allow-Origin header)
//! - CORS-safelisted methods and headers
//! - Forbidden headers and methods
//!
//! ## Usage
//!
//! ```zig
//! const cors = @import("fetch").cors;
//!
//! // Check if CORS allows the response
//! const result = cors.corsCheck(
//!     "https://example.com",
//!     .include,
//!     response_headers,
//! );
//!
//! if (result == .success) {
//!     // Response is allowed
//! }
//!
//! // Check if a header is forbidden
//! if (cors.isForbiddenHeaderName("Cookie")) {
//!     // Can't set this header
//! }
//! ```

const std = @import("std");

pub const check = @import("check.zig");

// Re-export main types and functions
pub const CredentialsMode = check.CredentialsMode;
pub const CorsCheckResult = check.CorsCheckResult;
pub const TaoCheckResult = check.TaoCheckResult;

pub const corsCheck = check.corsCheck;
pub const taoCheck = check.taoCheck;
pub const isCorseSafelistedMethod = check.isCorseSafelistedMethod;
pub const isCorseSafelistedRequestHeader = check.isCorseSafelistedRequestHeader;
pub const isForbiddenHeaderName = check.isForbiddenHeaderName;
pub const isForbiddenResponseHeaderName = check.isForbiddenResponseHeaderName;
pub const isForbiddenMethod = check.isForbiddenMethod;

test {
    std.testing.refAllDecls(@This());
}
