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

// Re-export main types
pub const Headers = headers.Headers;
pub const HeadersInit = headers.HeadersInit;
pub const Request = request.Request;
pub const RequestInit = request.RequestInit;
pub const Response = response.Response;
pub const ResponseInit = response.ResponseInit;

test {
    std.testing.refAllDecls(@This());
}
