//! Fetch WebIDL Interfaces
//!
//! This module exports the WebIDL interfaces for the Fetch API.
//!
//! Interfaces:
//! - Headers - HTTP header manipulation
//! - Request - Request configuration
//! - Response - Response data and metadata
//!
//! Global functions:
//! - fetch() - Initiate a fetch operation

const std = @import("std");

pub const headers = @import("headers.zig");
pub const request = @import("request.zig");
pub const response = @import("response.zig");
pub const global_fetch = @import("global_fetch.zig");
pub const body_mixin = @import("body_mixin.zig");

// Re-export main types
pub const Headers = headers.Headers;
pub const HeadersInit = headers.HeadersInit;
pub const Request = request.Request;
pub const RequestInit = request.RequestInit;
pub const Response = response.Response;
pub const ResponseInit = response.ResponseInit;

// Re-export global fetch
pub const globalFetch = global_fetch.globalFetch;
pub const fetchUrl = global_fetch.fetchUrl;
pub const FetchInput = global_fetch.FetchInput;
pub const FetchResult = global_fetch.FetchResult;
pub const FetchError = global_fetch.FetchError;

// Re-export Body mixin
pub const BodyMixin = body_mixin.BodyMixin;
pub const BlobResult = body_mixin.BlobResult;
pub const FormDataResult = body_mixin.FormDataResult;

test {
    std.testing.refAllDecls(@This());
}
