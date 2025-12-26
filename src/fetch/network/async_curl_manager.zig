//! Async Curl Manager - Non-blocking HTTP requests using libcurl multi interface
//!
//! This module provides async HTTP request support for the WHATWG Fetch API.
//! Instead of blocking on curl_easy_perform(), it uses the curl multi interface
//! which allows multiple concurrent requests to make progress via polling.
//!
//! Usage:
//! ```zig
//! const mgr = try AsyncCurlManager.init(allocator);
//! defer mgr.deinit();
//!
//! // Add a request with completion callback
//! const handle = try mgr.addRequest(&request, myCallback, &myContext);
//!
//! // Poll in your event loop
//! while (mgr.hasPendingRequests()) {
//!     const did_work = mgr.poll();
//!     if (!did_work) {
//!         // No progress, can sleep or do other work
//!     }
//! }
//! ```
//!
//! Spec: https://fetch.spec.whatwg.org/#http-network-fetch

const std = @import("std");
const Allocator = std.mem.Allocator;
const curl = @import("curl_ffi.zig");
const curl_error = @import("curl_error.zig");
const backend = @import("backend.zig");
const CurlCookieManager = @import("curl_cookies.zig").CurlCookieManager;
const NetworkRequest = backend.NetworkRequest;
const NetworkResponse = backend.NetworkResponse;
const NetworkError = backend.NetworkError;
const HttpVersion = backend.HttpVersion;

/// Unique identifier for an async request
pub const RequestHandle = u64;

/// Result of a completed async request
pub const AsyncResult = union(enum) {
    /// Request completed successfully with response
    success: NetworkResponse,
    /// Request failed with error
    failure: NetworkError,
};

/// Callback invoked when a request completes
/// The callback receives ownership of the response (must call deinit) or error info.
pub const CompletionCallback = *const fn (result: AsyncResult, user_data: ?*anyopaque) void;

/// Context for an in-flight request
const RequestContext = struct {
    /// Unique ID for this request
    handle: RequestHandle,
    /// The curl easy handle for this request
    easy_handle: *curl.CURL,
    /// Allocator for response data
    allocator: Allocator,
    /// Completion callback
    callback: CompletionCallback,
    /// User data for callback
    user_data: ?*anyopaque,
    /// Accumulated response body
    response_body: std.ArrayList(u8),
    /// Raw headers for parsing
    raw_headers: std.ArrayList(u8),
    /// Whether this request was cancelled
    cancelled: bool,
    /// Abort flag for progress callback
    aborted: std.atomic.Value(bool),
    /// Back-reference to manager for cleanup
    manager: *AsyncCurlManager,
    /// Null-terminated URL string that must remain valid for the duration of the request.
    /// Curl's CURLOPT_URL requires the string to stay valid until the request completes.
    url_z: ?[:0]u8,

    fn init(
        allocator: Allocator,
        handle: RequestHandle,
        easy_handle: *curl.CURL,
        callback: CompletionCallback,
        user_data: ?*anyopaque,
        manager: *AsyncCurlManager,
    ) RequestContext {
        return .{
            .handle = handle,
            .easy_handle = easy_handle,
            .allocator = allocator,
            .callback = callback,
            .user_data = user_data,
            .response_body = .empty,
            .raw_headers = .empty,
            .cancelled = false,
            .aborted = std.atomic.Value(bool).init(false),
            .manager = manager,
            .url_z = null,
        };
    }

    fn deinit(self: *RequestContext) void {
        self.response_body.deinit(self.allocator);
        self.raw_headers.deinit(self.allocator);
        // Free the URL string that was kept alive for the request duration
        if (self.url_z) |url| {
            self.allocator.free(url);
        }
    }
};

/// Async HTTP request manager using curl multi interface.
///
/// Manages multiple concurrent HTTP requests without blocking.
/// Call poll() regularly to make progress on all pending requests.
pub const AsyncCurlManager = struct {
    allocator: Allocator,
    /// The curl multi handle
    multi_handle: *curl.CURLM,
    /// Next request handle to assign
    next_handle: RequestHandle,
    /// Active requests indexed by their easy handle pointer value
    requests: std.AutoHashMap(usize, *RequestContext),
    /// Whether this manager has been initialized
    initialized: bool,
    /// Shared cookie manager (null = cookies disabled)
    cookie_manager: ?*CurlCookieManager,

    const Self = @This();

    /// Initialize a new async curl manager without cookie support.
    /// Requires curl globalInit() to have been called.
    pub fn init(allocator: Allocator) !*Self {
        return initWithCookies(allocator, null);
    }

    /// Initialize a new async curl manager with optional cookie support.
    /// If cookie_manager is provided, cookies will be sent/received for all requests.
    /// Requires curl globalInit() to have been called.
    pub fn initWithCookies(allocator: Allocator, cookie_manager: ?*CurlCookieManager) !*Self {
        const multi = curl.multi_init() orelse return error.OutOfMemory;
        errdefer _ = curl.multi_cleanup(multi);

        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        self.* = .{
            .allocator = allocator,
            .multi_handle = multi,
            .next_handle = 1,
            .requests = std.AutoHashMap(usize, *RequestContext).init(allocator),
            .initialized = true,
            .cookie_manager = cookie_manager,
        };

        return self;
    }

    /// Clean up the manager and all pending requests.
    /// Pending requests will have their callbacks invoked with an Aborted error.
    pub fn deinit(self: *Self) void {
        if (!self.initialized) return;

        // Cancel all pending requests
        var it = self.requests.iterator();
        while (it.next()) |entry| {
            const ctx = entry.value_ptr.*;
            // Remove from multi handle
            _ = curl.multi_remove_handle(self.multi_handle, ctx.easy_handle);
            // Clean up easy handle
            curl.easy_cleanup(ctx.easy_handle);
            // Invoke callback with abort error
            if (!ctx.cancelled) {
                ctx.callback(.{ .failure = NetworkError.Aborted }, ctx.user_data);
            }
            ctx.deinit();
            self.allocator.destroy(ctx);
        }
        self.requests.deinit();

        _ = curl.multi_cleanup(self.multi_handle);
        self.allocator.destroy(self);
    }

    /// Add an async request.
    /// Returns a handle that can be used to cancel the request.
    /// The callback will be invoked when the request completes or fails.
    pub fn addRequest(
        self: *Self,
        request: *const NetworkRequest,
        callback: CompletionCallback,
        user_data: ?*anyopaque,
    ) !RequestHandle {
        // Create a new easy handle for this request
        const easy = curl.easy_init() orelse return error.OutOfMemory;
        errdefer curl.easy_cleanup(easy);

        // Assign handle ID
        const handle = self.next_handle;
        self.next_handle += 1;

        // Create request context
        const ctx = try self.allocator.create(RequestContext);
        errdefer self.allocator.destroy(ctx);

        ctx.* = RequestContext.init(
            self.allocator,
            handle,
            easy,
            callback,
            user_data,
            self,
        );

        // Configure the request
        try self.configureRequest(easy, request, ctx);

        // Add to multi handle
        const add_result = curl.multi_add_handle(self.multi_handle, easy);
        if (add_result != curl.CURLM_OK) {
            ctx.deinit();
            self.allocator.destroy(ctx);
            return error.CurlMultiError;
        }

        // Track the request
        try self.requests.put(@intFromPtr(easy), ctx);

        return handle;
    }

    /// Cancel a pending request.
    /// The callback will NOT be invoked for cancelled requests.
    pub fn cancelRequest(self: *Self, handle: RequestHandle) void {
        // Find the request by handle ID
        var to_remove: ?usize = null;
        var it = self.requests.iterator();
        while (it.next()) |entry| {
            const ctx = entry.value_ptr.*;
            if (ctx.handle == handle) {
                to_remove = entry.key_ptr.*;
                ctx.cancelled = true;
                ctx.aborted.store(true, .seq_cst);
                break;
            }
        }

        if (to_remove) |easy_ptr| {
            if (self.requests.get(easy_ptr)) |ctx| {
                _ = curl.multi_remove_handle(self.multi_handle, ctx.easy_handle);
                curl.easy_cleanup(ctx.easy_handle);
                ctx.deinit();
                self.allocator.destroy(ctx);
            }
            _ = self.requests.remove(easy_ptr);
        }
    }

    /// Poll for completed requests.
    /// Returns true if any progress was made or callbacks were invoked.
    /// This is non-blocking - returns immediately if no work is ready.
    pub fn poll(self: *Self) bool {
        if (!self.initialized) return false;
        if (self.requests.count() == 0) return false;

        var still_running: c_int = 0;
        var did_work = false;

        // Perform transfers
        const perform_result = curl.multi_perform(self.multi_handle, &still_running);
        if (perform_result != curl.CURLM_OK) {
            return false;
        }

        // Check for completed transfers
        var msgs_left: c_int = 0;
        while (curl.multi_info_read(self.multi_handle, &msgs_left)) |msg| {
            if (msg.msg == curl.CURLMSG_DONE) {
                const easy_handle = msg.easy_handle orelse continue;
                const easy_ptr = @intFromPtr(easy_handle);

                if (self.requests.get(easy_ptr)) |ctx| {
                    did_work = true;

                    // Remove from multi handle first
                    _ = curl.multi_remove_handle(self.multi_handle, easy_handle);
                    _ = self.requests.remove(easy_ptr);

                    // Build result and invoke callback
                    if (ctx.cancelled) {
                        // Don't invoke callback for cancelled requests
                        curl.easy_cleanup(easy_handle);
                        ctx.deinit();
                        self.allocator.destroy(ctx);
                    } else if (msg.data.result != curl.CURLE_OK) {
                        // Request failed - map curl error to network error
                        const net_error = curl_error.mapCurlError(msg.data.result);

                        ctx.callback(.{ .failure = net_error }, ctx.user_data);
                        curl.easy_cleanup(easy_handle);
                        ctx.deinit();
                        self.allocator.destroy(ctx);
                    } else {
                        // Request succeeded - build response
                        const response = self.buildResponse(easy_handle, ctx) catch |err| {
                            const net_error: NetworkError = switch (err) {
                                error.OutOfMemory => error.OutOfMemory,
                            };
                            ctx.callback(.{ .failure = net_error }, ctx.user_data);
                            curl.easy_cleanup(easy_handle);
                            ctx.deinit();
                            self.allocator.destroy(ctx);
                            continue;
                        };
                        ctx.callback(.{ .success = response }, ctx.user_data);
                        curl.easy_cleanup(easy_handle);
                        ctx.deinit();
                        self.allocator.destroy(ctx);
                    }
                }
            }
        }

        return did_work or still_running > 0;
    }

    /// Check if there are pending requests.
    pub fn hasPendingRequests(self: *Self) bool {
        return self.requests.count() > 0;
    }

    /// Get the number of pending requests.
    pub fn pendingCount(self: *Self) usize {
        return self.requests.count();
    }

    /// Get a Pollable interface for use with V8EventLoop.
    /// This allows the event loop to poll without importing the fetch module.
    ///
    /// Example:
    /// ```zig
    /// const mgr = try AsyncCurlManager.init(allocator);
    /// v8_loop.setExternalPollable(mgr.pollable());
    /// ```
    pub fn pollable(self: *Self) Pollable {
        return .{
            .ptr = self,
            .poll_fn = pollWrapper,
        };
    }

    /// Type-erased poll wrapper for Pollable interface
    fn pollWrapper(ptr: *anyopaque) bool {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.poll();
    }

    /// Pollable interface - generic poll interface for event loop integration.
    /// Matches V8EventLoop.Pollable exactly.
    pub const Pollable = struct {
        ptr: *anyopaque,
        poll_fn: *const fn (ptr: *anyopaque) bool,

        pub fn poll(p: Pollable) bool {
            return p.poll_fn(p.ptr);
        }
    };

    // =========================================================================
    // Private Implementation
    // =========================================================================

    fn configureRequest(self: *Self, handle: *curl.CURL, request: *const NetworkRequest, ctx: *RequestContext) !void {
        // Attach cookie manager if available (enables cookie sending/receiving)
        if (self.cookie_manager) |cm| {
            cm.attachToHandle(handle);
        }

        // URL (must be null-terminated and remain valid for the entire request duration)
        // Store in context so it's freed in deinit() after the request completes.
        // Per curl documentation: "The string pointed to in the CURLOPT_URL argument
        // must remain VALID until the transfer finishes."
        const url_z = try ctx.allocator.dupeZ(u8, request.url);
        ctx.url_z = url_z;

        _ = curl.easy_setopt(handle, curl.CURLOPT_URL, url_z.ptr);

        // Method
        if (!std.mem.eql(u8, request.method, "GET")) {
            const method_z = try ctx.allocator.dupeZ(u8, request.method);
            defer ctx.allocator.free(method_z);
            _ = curl.easy_setopt(handle, curl.CURLOPT_CUSTOMREQUEST, method_z.ptr);
        }

        // Request body
        if (request.body) |body| {
            _ = curl.easy_setopt(handle, curl.CURLOPT_POSTFIELDS, body.ptr);
            _ = curl.easy_setopt(handle, curl.CURLOPT_POSTFIELDSIZE, @as(c_long, @intCast(body.len)));
        }

        // Headers
        var header_list: ?*curl.curl_slist = null;
        for (request.headers) |header| {
            const header_str = try std.fmt.allocPrint(ctx.allocator, "{s}: {s}", .{ header.name, header.value });
            defer ctx.allocator.free(header_str);
            const header_z = try ctx.allocator.dupeZ(u8, header_str);
            defer ctx.allocator.free(header_z);
            header_list = curl.slist_append(header_list, header_z.ptr);
        }
        if (header_list != null) {
            _ = curl.easy_setopt(handle, curl.CURLOPT_HTTPHEADER, header_list);
        }

        // HTTP version
        const curl_http_version: c_long = switch (request.http_version) {
            .http_1_0 => curl.CURL_HTTP_VERSION_1_0,
            .http_1_1 => curl.CURL_HTTP_VERSION_1_1,
            .http_2 => curl.CURL_HTTP_VERSION_2_0,
            .http_3 => curl.CURL_HTTP_VERSION_3,
        };
        _ = curl.easy_setopt(handle, curl.CURLOPT_HTTP_VERSION, curl_http_version);

        // Timeouts
        if (request.connect_timeout_ms > 0) {
            _ = curl.easy_setopt(handle, curl.CURLOPT_CONNECTTIMEOUT_MS, @as(c_long, @intCast(request.connect_timeout_ms)));
        }
        if (request.timeout_ms > 0) {
            _ = curl.easy_setopt(handle, curl.CURLOPT_TIMEOUT_MS, @as(c_long, @intCast(request.timeout_ms)));
        }

        // Redirects
        _ = curl.easy_setopt(handle, curl.CURLOPT_FOLLOWLOCATION, @as(c_long, if (request.follow_redirects) 1 else 0));
        if (request.follow_redirects) {
            _ = curl.easy_setopt(handle, curl.CURLOPT_MAXREDIRS, @as(c_long, @intCast(request.max_redirects)));
        }

        // TLS options - disable verification to allow self-signed certs for WPT testing
        // WPT server uses self-signed certificates on ports 8445 and 8446
        _ = curl.easy_setopt(handle, curl.CURLOPT_SSL_VERIFYPEER, @as(c_long, 0));
        _ = curl.easy_setopt(handle, curl.CURLOPT_SSL_VERIFYHOST, @as(c_long, 0));

        // Accept compression
        _ = curl.easy_setopt(handle, curl.CURLOPT_ACCEPT_ENCODING, "");

        // Callbacks
        _ = curl.easy_setopt(handle, curl.CURLOPT_WRITEFUNCTION, writeCallback);
        _ = curl.easy_setopt(handle, curl.CURLOPT_WRITEDATA, @as(*anyopaque, ctx));
        _ = curl.easy_setopt(handle, curl.CURLOPT_HEADERFUNCTION, headerCallback);
        _ = curl.easy_setopt(handle, curl.CURLOPT_HEADERDATA, @as(*anyopaque, ctx));

        // Progress callback for abort support
        _ = curl.easy_setopt(handle, curl.CURLOPT_NOPROGRESS, @as(c_long, 0));
        _ = curl.easy_setopt(handle, curl.CURLOPT_XFERINFOFUNCTION, progressCallback);
        _ = curl.easy_setopt(handle, curl.CURLOPT_XFERINFODATA, @as(*anyopaque, ctx));
    }

    fn buildResponse(self: *Self, easy: *curl.CURL, ctx: *RequestContext) !NetworkResponse {
        _ = self;

        // Parse headers
        var headers = std.ArrayList(NetworkResponse.Header){};
        const raw = ctx.raw_headers.items;
        var lines = std.mem.splitSequence(u8, raw, "\r\n");

        while (lines.next()) |line| {
            if (line.len == 0) continue;
            if (std.mem.startsWith(u8, line, "HTTP/")) continue;

            if (std.mem.indexOf(u8, line, ":")) |colon_pos| {
                const name = std.mem.trim(u8, line[0..colon_pos], " \t");
                const value = std.mem.trim(u8, line[colon_pos + 1 ..], " \t");

                if (name.len > 0) {
                    const header = NetworkResponse.Header{
                        .name = try ctx.allocator.dupe(u8, name),
                        .value = try ctx.allocator.dupe(u8, value),
                    };
                    try headers.append(ctx.allocator, header);
                }
            }
        }

        // Extract response info
        var status_code: c_long = 0;
        _ = curl.easy_getinfo(easy, curl.CURLINFO_RESPONSE_CODE, &status_code);

        var http_version_raw: c_long = 0;
        _ = curl.easy_getinfo(easy, curl.CURLINFO_HTTP_VERSION, &http_version_raw);

        var total_time: f64 = 0;
        _ = curl.easy_getinfo(easy, curl.CURLINFO_TOTAL_TIME, &total_time);

        var starttransfer_time: f64 = 0;
        _ = curl.easy_getinfo(easy, curl.CURLINFO_STARTTRANSFER_TIME, &starttransfer_time);

        // Build response
        const http_version: HttpVersion = switch (http_version_raw) {
            curl.CURL_HTTP_VERSION_1_0 => .http_1_0,
            curl.CURL_HTTP_VERSION_1_1 => .http_1_1,
            curl.CURL_HTTP_VERSION_2_0 => .http_2,
            curl.CURL_HTTP_VERSION_3 => .http_3,
            else => .http_1_1,
        };

        const owned_headers = try headers.toOwnedSlice(ctx.allocator);
        const body = if (ctx.response_body.items.len > 0)
            try ctx.response_body.toOwnedSlice(ctx.allocator)
        else
            null;

        return NetworkResponse{
            .allocator = ctx.allocator,
            .status = @intCast(status_code),
            .http_version = http_version,
            .headers = owned_headers,
            .body = body,
            .final_url = null,
            .total_time_ms = @intFromFloat(total_time * 1000),
            .time_to_first_byte_ms = @intFromFloat(starttransfer_time * 1000),
            .redirect_count = 0,
            .remote_ip = null,
            .remote_port = null,
            .dns_lookup_time_ms = 0,
            .connect_time_ms = 0,
            .app_connect_time_ms = 0,
            .pretransfer_time_ms = 0,
            .redirect_time_ms = 0,
            .connection_reused = false,
        };
    }
};

// =============================================================================
// Curl Callbacks
// =============================================================================

fn writeCallback(data: [*]u8, size: usize, nmemb: usize, userdata: *anyopaque) callconv(.c) usize {
    const ctx: *RequestContext = @ptrCast(@alignCast(userdata));

    if (ctx.aborted.load(.seq_cst)) {
        return 0; // Signal abort
    }

    const total_size = size * nmemb;
    ctx.response_body.appendSlice(ctx.allocator, data[0..total_size]) catch {
        return 0;
    };
    return total_size;
}

fn headerCallback(data: [*]u8, size: usize, nmemb: usize, userdata: *anyopaque) callconv(.c) usize {
    const ctx: *RequestContext = @ptrCast(@alignCast(userdata));

    if (ctx.aborted.load(.seq_cst)) {
        return 0;
    }

    const total_size = size * nmemb;
    ctx.raw_headers.appendSlice(ctx.allocator, data[0..total_size]) catch {
        return 0;
    };
    return total_size;
}

fn progressCallback(
    userdata: *anyopaque,
    _: c_longlong,
    _: c_longlong,
    _: c_longlong,
    _: c_longlong,
) callconv(.c) c_int {
    const ctx: *RequestContext = @ptrCast(@alignCast(userdata));

    if (ctx.aborted.load(.seq_cst)) {
        return 1; // Abort transfer
    }
    return 0;
}

// =============================================================================
// Tests
// =============================================================================

const testing = std.testing;

test "AsyncCurlManager - init and deinit" {
    const allocator = testing.allocator;

    // Requires global init
    const curl_backend = @import("curl_backend.zig");
    try curl_backend.globalInit();
    defer curl_backend.globalCleanup();

    const mgr = try AsyncCurlManager.init(allocator);
    defer mgr.deinit();

    try testing.expect(mgr.initialized);
    try testing.expect(mgr.hasPendingRequests() == false);
}

test "AsyncCurlManager - poll with no requests" {
    const allocator = testing.allocator;

    const curl_backend = @import("curl_backend.zig");
    try curl_backend.globalInit();
    defer curl_backend.globalCleanup();

    const mgr = try AsyncCurlManager.init(allocator);
    defer mgr.deinit();

    // Should return false when no requests
    const did_work = mgr.poll();
    try testing.expect(!did_work);
}
