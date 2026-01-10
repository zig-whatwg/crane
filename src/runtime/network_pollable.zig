//! Network Pollable Interface
//!
//! This module defines an abstract interface for polling async network resources.
//! Used to integrate AsyncCurlManager with the event loop without creating
//! circular dependencies between runtime -> fetch modules.
//!
//! The interface is used by:
//! - V8EventLoop: to poll for completed HTTP requests during runOnce()
//! - runtime.Context: to provide network polling to call_fetch implementations
//!
//! ## Usage
//!
//! ```zig
//! const mgr = try AsyncCurlManager.init(allocator);
//!
//! // Register with event loop
//! v8_loop.setExternalPollable(mgr.pollable());
//!
//! // Register with runtime context
//! ctx.setNetworkPollable(mgr.pollable());
//! ```

const std = @import("std");

/// Generic interface for any pollable network resource.
///
/// This abstraction allows the event loop to poll external managers
/// (like AsyncCurlManager for HTTP) without importing the fetch module.
pub const NetworkPollable = struct {
    /// Opaque pointer to the concrete implementation
    ptr: *anyopaque,

    /// Function to poll for work
    poll_fn: *const fn (ptr: *anyopaque) bool,

    /// Function to add an async request
    /// Returns a handle that can be used to cancel the request
    add_request_fn: ?*const fn (
        ptr: *anyopaque,
        url: []const u8,
        method: []const u8,
        headers: []const Header,
        body: ?[]const u8,
        callback: RequestCallback,
        user_data: ?*anyopaque,
    ) anyerror!u64,

    /// Poll the resource for completed work.
    /// Returns true if any work was done (callbacks invoked).
    pub fn poll(self: NetworkPollable) bool {
        return self.poll_fn(self.ptr);
    }

    /// Add an async request. Returns a handle that can be used to cancel.
    pub fn addRequest(
        self: NetworkPollable,
        url: []const u8,
        method: []const u8,
        headers: []const Header,
        body: ?[]const u8,
        callback: RequestCallback,
        user_data: ?*anyopaque,
    ) !u64 {
        const add_fn = self.add_request_fn orelse return error.NotSupported;
        return add_fn(self.ptr, url, method, headers, body, callback, user_data);
    }
};

/// HTTP request header
pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

/// Result of a completed async request
pub const RequestResult = union(enum) {
    /// Request completed successfully
    success: ResponseData,
    /// Request failed
    failure: RequestError,
};

/// Response data from a successful request
pub const ResponseData = struct {
    status: u16,
    headers: []const Header,
    body: ?[]const u8,
    /// Allocator used for the response data - caller must use this to free
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ResponseData) void {
        for (self.headers) |header| {
            self.allocator.free(header.name);
            self.allocator.free(header.value);
        }
        self.allocator.free(self.headers);
        if (self.body) |body| {
            self.allocator.free(body);
        }
    }
};

/// Request error types
pub const RequestError = enum {
    NetworkError,
    Timeout,
    Aborted,
    TlsError,
    DnsError,
    ConnectionRefused,
    OutOfMemory,
    InternalError,
};

/// Callback invoked when a request completes
pub const RequestCallback = *const fn (result: RequestResult, user_data: ?*anyopaque) void;
