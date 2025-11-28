//! Fetch Algorithms Module - WHATWG Fetch Specification
//!
//! This module contains the core fetch algorithms per the WHATWG Fetch spec.
//!
//! ## Components
//!
//! - `data_url.zig` - data: URL processor
//! - `scheme_fetch.zig` - Scheme fetch dispatcher
//!
//! ## Usage
//!
//! ```zig
//! const algorithms = @import("fetch").algorithms;
//!
//! // Process a data: URL
//! var result = try algorithms.processDataUrl(allocator, "data:text/plain,Hello");
//! defer result.deinit();
//!
//! // Execute scheme fetch
//! const fetch_result = try algorithms.schemeFetch(allocator, "data", url);
//! ```

const std = @import("std");

pub const data_url = @import("data_url.zig");
pub const scheme_fetch = @import("scheme_fetch.zig");

// Re-export main types and functions
pub const DataUrlResult = data_url.DataUrlResult;
pub const DataUrlError = data_url.DataUrlError;
pub const processDataUrl = data_url.processDataUrl;

pub const SchemeFetchResult = scheme_fetch.SchemeFetchResult;
pub const SchemeFetchError = scheme_fetch.SchemeFetchError;
pub const schemeFetch = scheme_fetch.schemeFetch;
pub const isSupportedScheme = scheme_fetch.isSupportedScheme;
pub const isLocalScheme = scheme_fetch.isLocalScheme;
pub const isHttpScheme = scheme_fetch.isHttpScheme;
pub const isFetchScheme = scheme_fetch.isFetchScheme;

test {
    std.testing.refAllDecls(@This());
}
