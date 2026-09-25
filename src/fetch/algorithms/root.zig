//! Fetch Algorithms Module - WHATWG Fetch Specification
//!
//! This module contains the core fetch algorithms per the WHATWG Fetch spec.
//!
//! ## Components
//!
//! - `data_url.zig` - data: URL processor
//! - `scheme_fetch.zig` - Scheme fetch dispatcher
//! - `main_fetch.zig` - Main fetch orchestration algorithm
//! - `fetch_job.zig` - the fetch algorithm as a job that can wait for the network
//! - `fetch.zig` - fetch, waiting for the network (navigation, synchronous XHR)
//! - `async_fetch.zig` - fetch on the event loop (`fetch()`, the method)
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
//!
//! // Fetch, waiting for the response
//! var result = try algorithms.fetch(allocator, request, .{});
//! defer result.deinit();
//! ```

const std = @import("std");

pub const data_url = @import("data_url.zig");
pub const scheme_fetch = @import("scheme_fetch.zig");
pub const main_fetch = @import("main_fetch.zig");
pub const http_fetch = @import("http_fetch.zig");
pub const fetch_algorithm = @import("fetch.zig");
pub const fetch_job = @import("fetch_job.zig");
pub const async_fetch = @import("async_fetch.zig");

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

pub const MainFetchError = main_fetch.MainFetchError;
pub const MainFetchResult = main_fetch.MainFetchResult;

pub const HttpFetchError = http_fetch.HttpFetchError;
pub const HttpFetchOptions = http_fetch.HttpFetchOptions;
pub const corsCheck = http_fetch.corsCheck;

pub const FetchJob = fetch_job.FetchJob;
pub const AsyncFetch = async_fetch.AsyncFetch;

pub const FetchError = fetch_algorithm.FetchError;
pub const FetchResult = fetch_algorithm.FetchResult;
pub const FetchOptions = fetch_algorithm.FetchOptions;
pub const fetch = fetch_algorithm.fetch;
pub const fetchSimple = fetch_algorithm.fetchSimple;
pub const fetchWithAbort = fetch_algorithm.fetchWithAbort;

test {
    std.testing.refAllDecls(@This());
}
