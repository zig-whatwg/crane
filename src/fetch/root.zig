//! WHATWG Fetch Standard Implementation
//!
//! This module implements the WHATWG Fetch Standard in Zig.
//! Spec: https://fetch.spec.whatwg.org/
//!
//! ## Modules
//!
//! - `internal`: Internal data structures (header list, request/response internals)
//! - `referrer_policy`: W3C Referrer Policy implementation
//!
//! ## Usage
//!
//! ```zig
//! const fetch = @import("fetch");
//!
//! // Create a header list
//! var headers = fetch.internal.HeaderList.init(allocator);
//! defer headers.deinit();
//!
//! try headers.append("Content-Type", "application/json");
//! try headers.append("Accept", "application/json");
//!
//! // Use referrer policy
//! const policy = fetch.referrer_policy.ReferrerPolicy.parse("strict-origin");
//! ```

pub const internal = @import("internal/root.zig");
pub const referrer_policy = @import("referrer_policy/root.zig");

// Re-export commonly used types
pub const HeaderList = internal.HeaderList;
pub const Header = internal.Header;

// Re-export referrer policy types
pub const ReferrerPolicy = referrer_policy.ReferrerPolicy;

test {
    _ = internal;
    _ = referrer_policy;
}
