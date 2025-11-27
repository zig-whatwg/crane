//! WHATWG Fetch Standard Implementation
//!
//! This module implements the WHATWG Fetch Standard in Zig.
//! Spec: https://fetch.spec.whatwg.org/
//!
//! ## Modules
//!
//! - `internal`: Internal data structures (header list, request/response internals)
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
//! ```

pub const internal = @import("internal/root.zig");

// Re-export commonly used types
pub const HeaderList = internal.HeaderList;
pub const Header = internal.Header;

test {
    _ = internal;
}
